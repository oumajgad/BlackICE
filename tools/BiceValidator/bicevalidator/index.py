"""Where things are in the mod, for an editor: each event and everything that fires it,
each decision, and every place a flag or a modifier is set, tested or cleared.

The index is kept per file, so an editor can replace one file's part from the unsaved
text in front of it while the rest stays as read from disk. What it merges from the parts
is built when first asked for and dropped whenever a part changes.

Flags are also set and tested outside events and decisions - in technologies, histories,
unit files and the Lua scripts - and those are searched as text the first time anyone
asks, as the reference checks do (checks/references.py).
"""

import bisect
import glob
import os
import re
import threading
from dataclasses import dataclass, field

from . import lexer, parser, schema as S
from .chains import Chains
from .checks.references import FLAG_KEY, LUA_MIDDLE, LUA_PREFIX, LUA_SUFFIX, MODIFIER_KEYS, \
    VARIABLE_KEYS, VARIABLE_TEXT, VARIABLE_WHICH

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
# Folders whose variables the index finds by searching text: the conditions and effects of
# the data files. common/ is parsed for the events it fires, but not for these.
_VARIABLE_FOLDERS = (("common", "**/*.txt"), ("technologies", "**/*.txt"),
                     ("history", "countries/*.txt"), ("units", "*.txt"))
_FLAG_LINE = re.compile(r"(set|clr|has)_(country|global|province)_flag(\s*=\s*\"?)([\w.\-]+)",
                        re.IGNORECASE)


@dataclass(frozen=True)
class Source:
    """What a place that fires an event sits in: an event, a decision, an entry of
    on_actions, or a block of another file of common/ - a casus belli, a covert operation."""
    kind: str               # "event", "decision", "on_action" or "block"
    name: str               # the event's id, the decision's or the block's key
    file: str
    line: int


@dataclass
class Site:
    """A place a name is written: its file, line and the columns of the name (1-based,
    end exclusive), and what the place does with it - "set", "has", "fire" and so on."""
    file: str
    line: int
    col: int
    end: int
    verb: str = ""
    source: Source = None   # for a fire, what fires it
    name: str = ""          # the name as written, where it is compared without case


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
    triggered_only: bool = False    # `is_triggered_only = yes`
    has_trigger: bool = False

    @property
    def fires_itself(self):
        """Whether the game fires it on its own when its trigger holds, rather than only
        when something fires it."""
        return self.has_trigger and not self.triggered_only


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
    variables: list = field(default_factory=list)   # (lower name, Site: set, change or check)


def indexes(rel):
    """Whether \\p rel is a file the index reads: events, decisions, and common/, whose
    files fire events too - on_actions, and the effects of a casus belli or a covert
    operation."""
    return rel is not None and rel.endswith(".txt") and \
        rel.startswith(("events/", "decisions/", "common/"))


def _value_site(rel, node, verb, source=None):
    token = node.value_tok
    width = len(token.text) + (2 if token.kind == lexer.STRING else 0)
    return Site(rel, token.line, token.col, token.col + width, verb, source)


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
                event = _event(rel, node)
                out.events.append(event)
                _names(out, rel, node, Source("event", event.id, rel, node.line))
            else:
                _names(out, rel, node, None)
    elif folder == "decisions":
        for category in root.children:
            if not (category.is_block and category.lkey in S.DECISION_CATEGORIES):
                _names(out, rel, category, None)
                continue
            for decision in category.children:
                if decision.is_block and decision.key:
                    out.decisions.append(Decision(decision.key, category.key, rel,
                                                  decision.line, decision.col,
                                                  _end_line(decision)))
                    _names(out, rel, decision, Source("decision", decision.key, rel,
                                                      decision.line))
    elif rel == ON_ACTIONS:
        for action in root.children:
            source = Source("on_action", action.key or "", rel, action.line)
            for node in parser.walk(action):
                if node.is_pair and node.value and node.value.isdigit() \
                        and node.parent is not None and node.parent.key is not None:
                    out.fires.append((node.value, _value_site(rel, node, "fire", source)))
    else:
        # Another file of common/: only the events it fires. Its flags are found by the
        # text search the other folders get (_FLAG_FOLDERS).
        for block in root.children:
            source = Source("block", block.key or "", rel, block.line)
            for node in parser.walk(block):
                _fire(out, rel, node, source)
    return out


def _fire(out, rel, node, source):
    """Whether \\p node fires an event - which it then adds to \\p out."""
    if node.lkey not in S.EVENT_TYPES or node.op is None or node.parent is None \
            or node.parent.key is None:
        return False
    if node.value and node.value.isdigit():
        out.fires.append((node.value, _value_site(rel, node, "fire", source)))
    elif node.is_block:
        ident = node.child("id")
        if ident is not None and ident.value and ident.value.isdigit():
            out.fires.append((ident.value, _value_site(rel, ident, "fire", source)))
    return True


def _names(out, rel, top, source):
    """The events fired, the flags and the modifiers named inside \\p top."""
    for node in parser.walk(top):
        low = node.lkey
        if low is None or node.op is None:
            continue
        if node is not top and _fire(out, rel, node, source):
            continue
        if low in VARIABLE_KEYS and node.is_block:
            which = node.child("which")
            if which is not None and which.value:
                site = _value_site(rel, which, VARIABLE_KEYS[low])
                site.name = which.value
                out.variables.append((which.value.lower(), site))
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
    only = node.child("is_triggered_only")
    event.triggered_only = only is not None and (only.value or "").lower() == "yes"
    trigger = node.child("trigger")
    event.has_trigger = trigger is not None and trigger.is_block
    return event


class ModIndex:
    def __init__(self, root):
        self.root = root
        self._lock = threading.Lock()
        self._files = {}            # rel -> FileFacts
        self._merged = None
        self._elsewhere = None      # flag sites outside events and decisions
        self._variables_other = None    # variable sites outside events and decisions
        self._lua_pieces = None     # the pieces the Lua scripts build names from
        self._lua = None            # (rel, text) of every Lua script
        self._provinces = None      # province id -> its history file
        rels = [os.path.relpath(p, root).replace("\\", "/")
                for folder in ("events", "decisions")
                for p in glob.glob(os.path.join(root, folder, "**", "*.txt"), recursive=True)]
        # Of common/, only the files that fire an event are worth parsing.
        for path in glob.glob(os.path.join(root, "common", "**", "*.txt"), recursive=True):
            rel = os.path.relpath(path, root).replace("\\", "/")
            if rel == ON_ACTIONS or "_event" in _read_text(path):
                rels.append(rel)
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
        if rel.startswith(tuple(folder + "/" for folder, _ in _VARIABLE_FOLDERS)):
            self._variables_other = None
        if rel.startswith("script/"):
            self._lua = None
            self._lua_pieces = None
        if rel.startswith("history/provinces/"):
            self._provinces = None

    def warm(self):
        """Build now what is otherwise built when first asked for: the merged tables, the
        flags outside events and decisions, the Lua scripts and the province histories -
        about a second, which a first "find all references" would otherwise wait for."""
        self._tables()
        self._flags_elsewhere()
        self._variables_elsewhere()
        self._lua_scripts()
        self.province_file("")

    # --- what it holds -----------------------------------------------------------------

    def _tables(self):
        with self._lock:
            if self._merged is None:
                events, fires, flags, modifiers, decisions = {}, {}, {}, {}, {}
                variables = {}
                for rel in sorted(self._files):
                    part = self._files[rel]
                    for name, site in part.variables:
                        variables.setdefault(name, []).append(site)
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
                                "modifiers": modifiers, "decisions": decisions,
                                "variables": variables}
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

    def chains(self):
        """Which event fires which, and which can ever happen (chains.Chains), made when
        first asked for after any change."""
        tables = self._tables()
        with self._lock:
            found = tables.get("chains")
            if found is None:
                found = tables["chains"] = Chains(tables["events"], tables["fires"])
            return found

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

    def variable_names(self):
        """Every variable written in an event or a decision, once each, as it is first
        written - the game compares the names without case."""
        return sorted((sites[0].name or low for low, sites in
                       self._tables()["variables"].items()), key=str.lower)

    def variable_spellings(self, name):
        """The ways variable \\p name is written in events, decisions and data files."""
        sites = self._tables()["variables"].get(name.lower(), []) + \
            self._variables_elsewhere().get(name.lower(), [])
        return {s.name for s in sites if s.name}

    def variable_sites(self, name):
        """Every place variable \\p name is set, changed or tested: events and decisions,
        then the data files, then the Lua scripts, where it is found only in quotes and the
        verb is "lua"."""
        low = name.lower()
        sites = list(self._tables()["variables"].get(low, []))
        sites += self._variables_elsewhere().get(low, [])
        quoted = re.compile(r"[\"']%s[\"']" % re.escape(name), re.IGNORECASE)
        for rel, text in self._lua_scripts():
            if low not in text.lower():
                continue
            for number, line in enumerate(text.split("\n"), 1):
                for match in quoted.finditer(line):
                    sites.append(Site(rel, number, match.start() + 2, match.end(), "lua"))
        return sites

    def lua_piece(self, name):
        """("starts", "ends" or "has", piece) if the Lua scripts build names out of a piece
        \\p name starts with, ends with or has in its middle - `kind .. "_count_TECH"` - so
        that they may name it though it is written nowhere; else None."""
        pieces = self._lua_pieces
        if pieces is None:
            pieces = {"starts": set(), "ends": set(), "has": set()}
            for _, text in self._lua_scripts():
                for pattern, where in ((LUA_PREFIX, "starts"), (LUA_SUFFIX, "ends"),
                                       (LUA_MIDDLE, "has")):
                    pieces[where].update(p for p in pattern.findall(text)
                                         if len(p) >= 3 and any(ch.isalpha() for ch in p))
            self._lua_pieces = pieces
        low = name.lower()
        for where, test in (("starts", low.startswith), ("ends", low.endswith),
                            ("has", low.__contains__)):
            for piece in sorted(pieces[where]):
                if test(piece.lower()):
                    return where, piece
        return None

    def _variables_elsewhere(self):
        table = self._variables_other
        if table is None:
            table = {}
            for folder, pattern in _VARIABLE_FOLDERS:
                for path in sorted(glob.glob(os.path.join(self.root, folder, pattern),
                                             recursive=True)):
                    text = _read_text(path)
                    if "_variable" not in text:
                        continue
                    rel = os.path.relpath(path, self.root).replace("\\", "/")
                    starts = [0] + [i + 1 for i, ch in enumerate(text) if ch == "\n"]
                    for block in VARIABLE_TEXT.finditer(text):
                        verb = block.group(1).lower()
                        for which in VARIABLE_WHICH.finditer(block.group(2)):
                            at = block.start(2) + which.start(1)
                            line = bisect.bisect_right(starts, at)
                            col = at - starts[line - 1] + 1
                            if "#" in text[starts[line - 1]:at]:
                                continue    # in a comment
                            table.setdefault(which.group(1).lower(), []).append(
                                Site(rel, line, col, col + len(which.group(1)), verb,
                                     name=which.group(1)))
            self._variables_other = table
        return table

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
