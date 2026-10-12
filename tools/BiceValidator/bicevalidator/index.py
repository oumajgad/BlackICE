"""Where things are in the mod, for an editor: each event and everything that fires it,
each decision, and every place a flag or a modifier is set, tested or cleared.

The index is kept per file, so an editor can replace one file's part from the unsaved
text in front of it while the rest stays as read from disk. What it merges from the parts
is built when first asked for and dropped whenever a part changes.

Flags are also set and tested outside events and decisions - in technologies, histories,
unit files and the Lua scripts - and those are searched as text the first time anyone
asks, as the reference checks do (checks/references.py).
"""

import glob
import os
import re
import threading
from dataclasses import dataclass, field

from . import lexer, parser, schema as S
from .checks.references import FLAG_KEY, MODIFIER_KEYS

# Which files the index reads: events, decisions, and the one file in common/ that fires
# events.
ON_ACTIONS = "common/on_actions.txt"
# Removing a modifier names it too, so it is a use for "find all references" even though
# the reference check leaves it alone.
MODIFIER_USES = MODIFIER_KEYS | {"remove_country_modifier", "remove_province_modifier"}
# Folders whose flags the index finds by searching text rather than by parsing.
_FLAG_FOLDERS = (("common", "**/*.txt"), ("technologies", "**/*.txt"),
                 ("history", "countries/*.txt"), ("history", "units/**/*.txt"),
                 ("units", "*.txt"))
_FLAG_LINE = re.compile(r"(set|clr|has)_(country|global|province)_flag(\s*=\s*\"?)([\w.\-]+)",
                        re.IGNORECASE)


@dataclass
class Site:
    """A place a name is written: its file, line and the columns of the name (1-based,
    end exclusive), and what the place does with it - "set", "has", "fire" and so on."""
    file: str
    line: int
    col: int
    end: int
    verb: str = ""


@dataclass
class Event:
    id: str
    type: str               # country_event or province_event
    file: str
    line: int               # of `country_event`
    end_line: int           # of its closing bracket, or of its last line if never closed
    id_site: Site
    title: str = None       # as written: a localisation key or the text itself
    desc: str = None
    options: list = field(default_factory=list)    # (name as written, line, col)


@dataclass
class Decision:
    name: str
    category: str
    file: str
    line: int
    col: int
    end_line: int


@dataclass
class FileFacts:
    events: list = field(default_factory=list)
    decisions: list = field(default_factory=list)
    fires: list = field(default_factory=list)       # (event id, Site)
    flags: list = field(default_factory=list)       # (scope, lower name, Site)
    modifiers: list = field(default_factory=list)   # (lower name, Site)


def indexes(rel):
    """Whether \\p rel is a file the index reads."""
    return rel is not None and rel.endswith(".txt") and \
        (rel.startswith(("events/", "decisions/")) or rel == ON_ACTIONS)


def _value_site(rel, node, verb):
    token = node.value_tok
    width = len(token.text) + (2 if token.kind == lexer.STRING else 0)
    return Site(rel, token.line, token.col, token.col + width, verb)


def _end_line(node):
    if node.close_tok is not None:
        return node.close_tok.line
    last = node
    while last.children:
        last = last.children[-1]
    token = last.value_tok or last.key_tok or last.open_tok
    return token.line if token is not None else node.line


def facts(rel, root):
    """What the parsed file \\p rel declares and names."""
    out = FileFacts()
    folder = rel.split("/", 1)[0]
    if folder == "events":
        for node in root.children:
            if node.is_block and node.lkey in S.EVENT_TYPES:
                out.events.append(_event(rel, node))
    elif folder == "decisions":
        for category in root.children:
            if category.is_block and category.lkey in S.DECISION_CATEGORIES:
                for decision in category.children:
                    if decision.is_block and decision.key:
                        out.decisions.append(Decision(decision.key, category.key, rel,
                                                      decision.line, decision.col,
                                                      _end_line(decision)))
    if rel == ON_ACTIONS:
        for node in parser.walk(root):
            if node.is_pair and node.value and node.value.isdigit() \
                    and node.parent is not None and node.parent.key is not None:
                out.fires.append((node.value, _value_site(rel, node, "fire")))
        return out
    for node in parser.walk(root):
        low = node.lkey
        if low is None or node.op is None:
            continue
        if low in S.EVENT_TYPES and node.parent is not None and node.parent.key is not None:
            if node.value and node.value.isdigit():
                out.fires.append((node.value, _value_site(rel, node, "fire")))
            elif node.is_block:
                ident = node.child("id")
                if ident is not None and ident.value and ident.value.isdigit():
                    out.fires.append((ident.value, _value_site(rel, ident, "fire")))
            continue
        if node.value is None:
            if low in MODIFIER_USES and node.is_block:
                name = node.child("name")
                if name is not None and name.value:
                    out.modifiers.append((name.value.lower(),
                                          _value_site(rel, name, low.split("_", 1)[0])))
            continue
        match = FLAG_KEY.match(low)
        if match:
            out.flags.append((match.group(2), node.value.lower(),
                              _value_site(rel, node, match.group(1))))
        elif low in MODIFIER_USES:
            out.modifiers.append((node.value.lower(),
                                  _value_site(rel, node, low.split("_", 1)[0])))
    return out


def _event(rel, node):
    ident = node.child("id")
    title, desc = node.child("title"), node.child("desc")
    event = Event(ident.value if ident is not None and ident.value else "", node.lkey, rel,
                  node.line, _end_line(node),
                  _value_site(rel, ident, "define") if ident is not None and ident.value_tok
                  else Site(rel, node.line, node.col, node.col + len(node.key), "define"),
                  title.value if title is not None else None,
                  desc.value if desc is not None else None)
    for option in node.children:
        if option.is_block and option.lkey == "option":
            name = option.child("name")
            event.options.append((name.value if name is not None and name.value else "",
                                  option.line, option.col))
    return event


class ModIndex:
    def __init__(self, root):
        self.root = root
        self._lock = threading.Lock()
        self._files = {}            # rel -> FileFacts
        self._merged = None
        self._elsewhere = None      # flag sites outside events and decisions
        self._lua = None            # (rel, text) of every Lua script
        self._provinces = None      # province id -> its history file
        rels = [os.path.relpath(p, root).replace("\\", "/")
                for folder in ("events", "decisions")
                for p in glob.glob(os.path.join(root, folder, "**", "*.txt"), recursive=True)]
        if os.path.exists(os.path.join(root, ON_ACTIONS)):
            rels.append(ON_ACTIONS)
        for rel in sorted(rels):
            self._files[rel] = self._from_disk(rel)

    def _from_disk(self, rel):
        source = lexer.read(self.root, rel)
        return facts(rel, parser.parse(source.text).root)

    # --- keeping it current ------------------------------------------------------------

    def update(self, rel, root):
        """Replace \\p rel's part with what the parsed \\p root says."""
        if not indexes(rel):
            return
        found = facts(rel, root)
        with self._lock:
            self._files[rel] = found
            self._merged = None

    def reload_file(self, rel):
        """Read \\p rel's part from disk again, or drop it if the file has gone."""
        if indexes(rel):
            exists = os.path.exists(os.path.join(self.root, rel))
            found = self._from_disk(rel) if exists else None
            with self._lock:
                if found is None:
                    self._files.pop(rel, None)
                else:
                    self._files[rel] = found
                self._merged = None
        if rel.startswith(tuple(folder + "/" for folder, _ in _FLAG_FOLDERS)):
            self._elsewhere = None
        if rel.startswith("script/"):
            self._lua = None
        if rel.startswith("history/provinces/"):
            self._provinces = None

    def warm(self):
        """Build now what is otherwise built when first asked for: the merged tables, the
        flags outside events and decisions, the Lua scripts and the province histories -
        about a second, which a first "find all references" would otherwise wait for."""
        self._tables()
        self._flags_elsewhere()
        self._lua_scripts()
        self.province_file("")

    # --- what it holds -----------------------------------------------------------------

    def _tables(self):
        with self._lock:
            if self._merged is None:
                events, fires, flags, modifiers, decisions = {}, {}, {}, {}, {}
                for rel in sorted(self._files):
                    part = self._files[rel]
                    for event in part.events:
                        events.setdefault(event.id, []).append(event)
                    for ident, site in part.fires:
                        fires.setdefault(ident, []).append(site)
                    for scope, name, site in part.flags:
                        flags.setdefault((scope, name), []).append(site)
                    for name, site in part.modifiers:
                        modifiers.setdefault(name, []).append(site)
                    for decision in part.decisions:
                        decisions.setdefault(decision.name.lower(), []).append(decision)
                self._merged = {"events": events, "fires": fires, "flags": flags,
                                "modifiers": modifiers, "decisions": decisions}
            return self._merged

    def file(self, rel):
        with self._lock:
            return self._files.get(rel)

    def events(self, ident=None):
        """The events with id \\p ident (two or more is a duplicate id), or every event."""
        table = self._tables()["events"]
        if ident is None:
            return [e for found in table.values() for e in found]
        return table.get(ident, [])

    def fires(self, ident):
        return self._tables()["fires"].get(ident, [])

    def decisions(self, name=None):
        table = self._tables()["decisions"]
        if name is None:
            return [d for found in table.values() for d in found]
        return table.get(name.lower(), [])

    def modifier_uses(self, name):
        return self._tables()["modifiers"].get(name.lower(), [])

    def flag_names(self, scope):
        """Every flag name of \\p scope written in an event or a decision."""
        return sorted({name for (s, name) in self._tables()["flags"] if s == scope})

    def flag_sites(self, scope, name):
        """Every place flag \\p name of \\p scope is set, cleared or tested: events and
        decisions first, then the other script folders, then the Lua scripts, where only
        the name in quotes can be found and the verb is "lua"."""
        low = name.lower()
        sites = list(self._tables()["flags"].get((scope, low), []))
        sites += self._flags_elsewhere().get((scope, low), [])
        quoted = re.compile(r"[\"']%s[\"']" % re.escape(name), re.IGNORECASE)
        for rel, text in self._lua_scripts():
            if low not in text.lower():
                continue
            for number, line in enumerate(text.split("\n"), 1):
                for match in quoted.finditer(line):
                    sites.append(Site(rel, number, match.start() + 2, match.end(), "lua"))
        return sites

    def _flags_elsewhere(self):
        table = self._elsewhere
        if table is None:
            table = {}
            for folder, pattern in _FLAG_FOLDERS:
                for path in sorted(glob.glob(os.path.join(self.root, folder, pattern),
                                             recursive=True)):
                    rel = os.path.relpath(path, self.root).replace("\\", "/")
                    text = _read_text(path)
                    if "_flag" not in text:
                        continue
                    for number, line in enumerate(text.split("\n"), 1):
                        line = line.split("#", 1)[0]
                        for match in _FLAG_LINE.finditer(line):
                            verb, scope, gap, name = match.groups()
                            start = match.start(4) + 1
                            table.setdefault((scope.lower(), name.lower()), []).append(
                                Site(rel, number, start, start + len(name), verb.lower()))
            self._elsewhere = table
        return table

    def _lua_scripts(self):
        scripts = self._lua
        if scripts is None:
            scripts = []
            for path in sorted(glob.glob(os.path.join(self.root, "script", "**", "*.lua"),
                                         recursive=True)):
                scripts.append((os.path.relpath(path, self.root).replace("\\", "/"),
                                _read_text(path)))
            self._lua = scripts
        return scripts

    def province_file(self, ident):
        """The history file of province \\p ident, named `<id> - <name>.txt`, or None."""
        table = self._provinces
        if table is None:
            table = {}
            for path in glob.glob(os.path.join(self.root, "history", "provinces", "**",
                                               "*.txt"), recursive=True):
                name = os.path.basename(path)
                number = re.match(r"\s*(\d+)", name)
                if number:
                    table.setdefault(number.group(1), os.path.relpath(
                        path, self.root).replace("\\", "/"))
            self._provinces = table
        return table.get(ident)

    def next_event_id(self, rel=None, line=None):
        """The first id no event uses, after the id of the last event in \\p rel that
        starts before \\p line - a chain of events usually takes ids from one range - or
        after the highest in the file, or in the mod."""
        table = self._tables()["events"]
        used = {int(i) for i in table if i.isdigit()}
        part = self.file(rel) if rel else None
        mine = [e for e in (part.events if part else ()) if e.id.isdigit()]
        above = [e for e in mine if line is not None and e.line <= line]
        if above:
            start = int(max(above, key=lambda e: e.line).id)
        elif mine:
            start = max(int(e.id) for e in mine)
        else:
            start = max(used, default=0)
        candidate = start + 1
        while candidate in used:
            candidate += 1
        return candidate


def _read_text(path):
    with open(path, "rb") as handle:
        return handle.read().decode("cp1252", errors="replace")
