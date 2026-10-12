"""What is at a place in a script file, for an editor: hover text, where a name is
declared, where it is used, an outline, and what may be typed there.

Everything here is plain data with 1-based lines and columns, end columns exclusive; the
language server turns it into the protocol's types. A Navigator answers for one loaded
mod (session.Session), from its keyword lists, its declarations, its localisation and its
index (index.ModIndex).
"""

import bisect
import glob
import os
import re
from dataclasses import dataclass, field

from . import lexer, parser, schema as S
from .checks import script as C
from .checks.references import FLAG_KEY, NAMED_VALUES
from .declarations import Kinds
from .index import MODIFIER_USES

KEYWORD, BAD_KEY, DECLARED, EVENT, LOC, TAG, PROVINCE, FLAG, MODIFIER, OOB, DECISION = (
    "keyword", "bad key", "declared", "event", "localisation", "tag", "province", "flag",
    "modifier", "oob", "decision")

_KIND_NAMES = {"trigger": "condition", "effect": "effect", "scope": "scope",
               "header": "event header key", "option": "option key",
               "combat": "combat condition"}
# Keys whose number is a province outside the condition and effect lists: a country's
# capital in its history, a unit's place in an order of battle.
_PROVINCE_VALUES = {"capital", "location", "base"}
_COLOUR = re.compile(r"§.")
_TITLE_LENGTH = 60
_DESC_LENGTH = 700
_LIMIT = 200    # completions sent at once where the list could run to thousands


@dataclass
class Target:
    """A name the editor is pointing at."""
    what: str           # one of the constants above
    name: str           # as written
    token: object
    node: object
    kind: str = ""      # a declared name's kind, a flag's scope


@dataclass
class Place:
    file: str
    line: int
    col: int = 1
    end: int = 1


@dataclass
class Symbol:
    name: str
    detail: str
    kind: str           # "event", "option", "decision", "category", "block", "field"
    line: int
    col: int
    end_line: int
    end_col: int
    children: list = field(default_factory=list)
    file: str = ""


@dataclass
class Completion:
    label: str
    kind: str           # "keyword", "condition", "effect", "scope", "value", "event", ...
    detail: str = ""
    documentation: str = ""
    insert: str = ""    # a snippet; the label when empty
    filter: str = ""


def plain(text):
    """Localised text as it reads, without the game's colour codes."""
    return _COLOUR.sub("", text or "").replace("\\n", " ").strip()


def _short(text, length):
    return text if len(text) <= length else text[:length - 1].rstrip() + "…"


def _width(token):
    return len(token.text) + (2 if token.kind == lexer.STRING else 0)


def owners(parsed):
    """{id(token): (node, "key" or "value")} for every key and value token, kept on the
    parse so it is built once however many questions are asked of it."""
    found = getattr(parsed, "_owners", None)
    if found is None:
        found = {}
        for node in parser.walk(parsed.root):
            if node.key_tok is not None:
                found[id(node.key_tok)] = (node, "key")
            if node.value_tok is not None:
                found[id(node.value_tok)] = (node, "value")
        parsed._owners = found
        parsed._starts = [(t.line, t.col) for t in parsed.tokens]
    return found


def token_at(parsed, line, col):
    """The word or string token covering \\p line, \\p col, or None. A cursor just past
    the end of a word still counts as on it, as editors place it after a double click."""
    owners(parsed)
    index = bisect.bisect_right(parsed._starts, (line, col)) - 1
    for i in (index, index - 1):
        if 0 <= i < len(parsed.tokens):
            token = parsed.tokens[i]
            if token.line == line and token.col <= col <= token.col + _width(token) \
                    and token.kind in (lexer.WORD, lexer.STRING):
                return token
    return None


def _before(parsed, line, col):
    """Index of the last token starting before \\p line, \\p col."""
    owners(parsed)
    return bisect.bisect_left(parsed._starts, (line, col)) - 1


def _contains(node, line, col):
    if node.open_tok is None:
        return False
    if (node.open_tok.line, node.open_tok.col) >= (line, col):
        return False
    close = node.close_tok
    return close is None or (close.line, close.col) >= (line, col)


def block_chain(parsed, line, col):
    """The blocks around \\p line, \\p col, outermost first, the file itself included."""
    chain = [parsed.root]
    while True:
        inner = None
        for child in chain[-1].children:
            if child.is_block and _contains(child, line, col):
                inner = child
        if inner is None:
            return chain
        chain.append(inner)


# What a block is read as, from the block around it and its key. This follows
# ScriptChecker's walk (checks/script.py); "events" and "decisions" are the files'
# top levels and "category" a decision category.
def child_kind(kind, node):
    low = node.lkey
    if low is None:
        return None
    if kind == "events":
        return C.EVENT if low in S.EVENT_TYPES else None
    if kind == "decisions":
        return "category" if low in S.DECISION_CATEGORIES else None
    if kind == "category":
        return C.DECISION
    if kind == C.EVENT:
        return {"option": C.OPTION, "trigger": C.TRIGGER,
                "mean_time_to_happen": C.MTTH}.get(low)
    if kind == C.DECISION:
        return {"potential": C.TRIGGER, "allow": C.TRIGGER, "effect": C.EFFECT,
                "ai_will_do": C.CHANCE}.get(low)
    if kind in (C.MTTH, C.CHANCE):
        return C.MODIFIER if low == "modifier" else None
    if kind == C.RANDOM_LIST:
        return C.EFFECT
    if kind == C.OPTION:
        return C.CHANCE if low == "ai_chance" else child_kind(C.EFFECT, node)
    if kind in (C.MODIFIER, C.TRIGGER):
        if low in S.BLOCK_FIELDS:
            return C.FIELDS
        return C.TRIGGER
    if kind in (C.RANDOM, C.EFFECT):
        if low == "limit":
            return C.TRIGGER
        if low == "random":
            return C.RANDOM
        if low == "random_list":
            return C.RANDOM_LIST
        if low in S.BLOCK_FIELDS:
            return C.FIELDS
        return C.EFFECT
    return None


def block_kind(rel, chain):
    """What the innermost block of \\p chain is read as, or None outside events and
    decisions."""
    folder = rel.split("/", 1)[0]
    if folder not in ("events", "decisions"):
        return None
    kind = folder
    for node in chain[1:]:
        kind = child_kind(kind, node)
        if kind is None:
            return None
    return kind


class Navigator:
    def __init__(self, session):
        self.session = session
        self._doc_lines = None
        self._countries = None
        self._histories = None
        self._modifiers = None
        self._province_keywords = None

    @property
    def schema(self):
        return self.session.schema

    @property
    def decl(self):
        return self.session.declarations

    @property
    def index(self):
        return self.session.index

    @property
    def loc(self):
        return self.session.localisation

    # --- what is being pointed at ------------------------------------------------------

    def target(self, rel, parsed, line, col):
        token = token_at(parsed, line, col)
        if token is None:
            return None
        node, role = owners(parsed).get(id(token), (None, None))
        if node is None:
            return None
        if role == "value":
            return self._value_target(node, token)
        return self._key_target(rel, node, token)

    def _key_target(self, rel, node, token):
        name = node.key
        low = node.lkey
        parent = node.parent
        if node.op is None:
            # A bare item in a list: provinces in a region, tags in a list of countries.
            if name.isdigit():
                return Target(PROVINCE, name, token, node)
            if self.decl.has(Kinds.TAG, name):
                return Target(TAG, name, token, node, Kinds.TAG)
            return None
        if rel.startswith("decisions/") and parent is not None \
                and parent.lkey in S.DECISION_CATEGORIES and node.is_block:
            return Target(DECISION, name, token, node)
        if rel == "common/event_modifiers.txt" and parent is not None and parent.key is None:
            return Target(MODIFIER, name, token, node)
        if low.isdigit():
            if parent is not None and parent.lkey == "random_list":
                return None
            return Target(PROVINCE, name, token, node)
        if low in self.schema.keywords:
            return Target(KEYWORD, name, token, node)
        if low in self.session.checker.bad_keys:
            return Target(BAD_KEY, name, token, node)
        kind = self.decl.resolve_key(name)
        if kind == Kinds.TAG:
            return Target(TAG, name, token, node, kind)
        if kind is not None:
            return Target(DECLARED, name, token, node, kind)
        return None

    def _value_target(self, node, token):
        low, value = node.lkey, node.value
        if low is None or value is None:
            return None
        parent = node.parent
        if low in S.EVENT_TYPES and value.isdigit():
            return Target(EVENT, value, token, node)
        if low == "id" and parent is not None and parent.lkey in S.EVENT_TYPES:
            return Target(EVENT, value, token, node)
        if low in ("title", "desc", "name") and self.loc.has(value):
            return Target(LOC, value, token, node)
        if low == "load_oob":
            return Target(OOB, value, token, node)
        match = FLAG_KEY.match(low)
        if match:
            return Target(FLAG, value, token, node, match.group(2))
        if low in MODIFIER_USES or (low == "name" and parent is not None
                                    and parent.lkey in MODIFIER_USES):
            return Target(MODIFIER, value, token, node)
        if low in NAMED_VALUES:
            kinds = NAMED_VALUES[low]
            kind = next((k for k in kinds if self.decl.has(k, value)), kinds[0])
            return Target(DECLARED, value, token, node, kind)
        if value.isdigit():
            if low in _PROVINCE_VALUES or low in self._province_keys():
                return Target(PROVINCE, value, token, node)
            return None
        if self.decl.has(Kinds.TAG, value):
            return Target(TAG, value, token, node, Kinds.TAG)
        kind = self.decl.resolve_key(value)
        if kind is not None:
            return Target(DECLARED, value, token, node, kind)
        if self.loc.has(value):
            return Target(LOC, value, token, node)
        return None

    def _province_keys(self):
        if self._province_keywords is None:
            self._province_keywords = {
                k for k, entries in self.schema.keywords.items()
                if any(e.value in (S.PROVINCE, "province or tag") for e in entries)}
        return self._province_keywords

    # --- names as the player reads them ------------------------------------------------

    def text_of(self, value):
        """A title or a description as written: its localisation, or the text itself."""
        if not value:
            return ""
        found = self.loc.text(value)
        return plain(found if found is not None else value)

    def event_title(self, ident):
        events = self.index.events(ident)
        if not events:
            return None
        return self.text_of(events[0].title)

    def decision_title(self, name):
        for key in (name + "_title", name):
            found = self.loc.text(key)
            if found is not None:
                return plain(found)
        return ""

    def link(self, place):
        """A markdown link to \\p place that VS Code opens at its line."""
        path = os.path.join(self.session.root, place.file)
        uri = "file:///" + path.replace("\\", "/").lstrip("/").replace(" ", "%20")
        return "[%s:%d](%s#L%d)" % (place.file, place.line, uri, place.line)

    # --- hover -------------------------------------------------------------------------

    def hover(self, target):
        """Markdown about \\p target, or None."""
        method = getattr(self, "_hover_" + target.what.replace(" ", "_"))
        return method(target)

    def _hover_keyword(self, target):
        low = target.name.lower()
        parts = []
        for entry in self.schema.keywords[low]:
            text = "**`%s`** — %s" % (entry.name, _KIND_NAMES.get(entry.kind, entry.kind))
            text += "\n\n" + entry.description
            if entry.syntax:
                text += "\n\n```\n%s\n```" % entry.syntax
            place = self.keyword_place(entry)
            if place is not None:
                text += "\n\n" + self.link(place)
            parts.append(text)
        if low in C.DOES_NOTHING:
            parts.append("**Does nothing:** " + C.DOES_NOTHING[low])
        return "\n\n---\n\n".join(parts)

    def _hover_bad_key(self, target):
        bad = self.session.checker.bad_keys[target.name.lower()]
        return ("**`%s`** is not a keyword, and the engine drops it without a word.\n\n"
                "Write `%s` instead: %s" % (target.name, bad.instead, bad.why))

    def _hover_declared(self, target):
        where = self.decl.where(target.kind, target.name)
        name = self.loc.text(target.name)
        head = "**`%s`** — %s" % (target.name, target.kind)
        if name:
            head += ", *%s*" % plain(name)
        if where is None:
            return head + "\n\nNothing in the mod declares this %s." % target.kind
        return head + "\n\nDeclared in " + self.link(Place(where[1], where[2]))

    def _hover_tag(self, target):
        where = self.decl.where(Kinds.TAG, target.name)
        if where is None:
            return "**%s** is not a country: `common/countries.txt` does not list it." \
                % target.name
        text = "**%s** — %s" % (where[0], plain(self.loc.text(target.name)) or "country")
        text += "\n\nDeclared in " + self.link(Place(where[1], where[2]))
        for place in self._tag_files(target.name):
            text += "  \n" + self.link(place)
        return text

    def _hover_province(self, target):
        name = self.loc.text("PROV" + target.name)
        if not self.decl.has(Kinds.PROVINCE, target.name):
            return "**Province %s** does not exist: `map/definition.csv` has no such id." \
                % target.name
        text = "**Province %s** — %s" % (target.name, plain(name) or "no name")
        history = self.index.province_file(target.name)
        if history:
            text += "\n\nHistory in " + self.link(Place(history, 1))
        return text

    def _hover_event(self, target):
        events = self.index.events(target.name)
        if not events:
            return "**Event %s** does not exist." % target.name
        event = events[0]
        text = "**%s %s** — %s" % (event.type, event.id,
                                        self.text_of(event.title) or "no title")
        desc = self.text_of(event.desc)
        if desc:
            text += "\n\n" + _short(desc, _DESC_LENGTH)
        if event.options:
            names = [self.text_of(name) or "option" for name, _, _ in event.options]
            text += "\n\nOptions: " + " · ".join("*%s*" % n for n in names)
        text += "\n\nIn " + self.link(Place(event.file, event.line))
        fired = len(self.index.fires(target.name))
        text += ", fired from %d place%s." % (fired, "" if fired == 1 else "s") if fired \
            else ", fired from nowhere in the mod's script."
        if len(events) > 1:
            text += "\n\n**%d events have this id:** %s" % (
                len(events), ", ".join(self.link(Place(e.file, e.line)) for e in events))
        return text

    def _hover_localisation(self, target):
        entries = self.loc.entries(target.name)
        if not entries:
            return None
        first = entries[0]
        text = "**`%s`**\n\n%s\n\n%s" % (first.key, plain(first.text) or "*(empty)*",
                                         self.link(Place(first.file, first.line)))
        if len(entries) > 1:
            text += "\n\nWritten in %d places; which one the game shows is not " \
                    "established." % len(entries)
        return text

    def _hover_flag(self, target):
        counts = {}
        for site in self.index.flag_sites(target.kind, target.name):
            counts[site.verb] = counts.get(site.verb, 0) + 1
        parts = []
        for verb, word in (("set", "set"), ("has", "tested"), ("clr", "cleared"),
                           ("lua", "named in Lua")):
            if counts.get(verb):
                parts.append("%s %d time%s" % (word, counts[verb],
                                                 "" if counts[verb] == 1 else "s"))
        text = "**%s flag `%s`**\n\n" % (target.kind, target.name)
        if not parts:
            return text + "Written nowhere else in the mod."
        return text + _sentence(parts) + "."

    def _hover_modifier(self, target):
        where = self.decl.where(Kinds.MODIFIER, target.name)
        name = self.loc.text(target.name)
        text = "**modifier `%s`**" % target.name
        if name:
            text += " — *%s*" % plain(name)
        if where is None:
            return text + "\n\n`common/event_modifiers.txt` does not declare it."
        body = self._modifier_body(target.name)
        if body:
            text += "\n\n```\n%s\n```" % "\n".join(body)
        uses = len(self.index.modifier_uses(target.name))
        text += "\n\nDeclared in %s, used in %d place%s." % (
            self.link(Place(where[1], where[2])), uses, "" if uses == 1 else "s")
        return text

    def _hover_oob(self, target):
        rel = "history/units/" + target.name
        if not os.path.exists(os.path.join(self.session.root, rel)):
            return "**No file** `%s`" % rel
        return "Order of battle " + self.link(Place(rel, 1))

    def _hover_decision(self, target):
        title = self.decision_title(target.name)
        text = "**decision `%s`**" % target.name
        if title:
            text += " — *%s*" % title
        desc = self.loc.text(target.name + "_desc")
        if desc:
            text += "\n\n" + _short(plain(desc), _DESC_LENGTH)
        return text

    # --- where it is declared, and where it is used ------------------------------------

    def definitions(self, target):
        what = target.what
        if what == KEYWORD:
            places = [self.keyword_place(e) for e in self.schema.keywords[target.name.lower()]]
            return [p for p in places if p is not None]
        if what == EVENT:
            return [Place(e.file, e.id_site.line, e.id_site.col, e.id_site.end)
                    for e in self.index.events(target.name)]
        if what == LOC:
            return [Place(e.file, e.line, 1, len(e.key) + 1) for e in self.loc.entries(target.name)]
        if what == OOB:
            rel = "history/units/" + target.name
            return [Place(rel, 1)] if os.path.exists(os.path.join(self.session.root, rel)) else []
        if what == PROVINCE:
            places = []
            history = self.index.province_file(target.name)
            if history:
                places.append(Place(history, 1))
            where = self.decl.where(Kinds.PROVINCE, target.name)
            if where:
                places.append(Place(where[1], where[2]))
            return places
        if what == FLAG:
            sites = self.index.flag_sites(target.kind, target.name)
            setting = [s for s in sites if s.verb == "set"] or sites
            return [Place(s.file, s.line, s.col, s.end) for s in setting]
        if what == DECISION:
            return [Place(d.file, d.line, d.col, d.col + len(d.name))
                    for d in self.index.decisions(target.name)]
        kind = Kinds.MODIFIER if what == MODIFIER else target.kind
        where = self.decl.where(kind, target.name) if kind else None
        places = [Place(where[1], where[2])] if where else []
        if what == TAG:
            places += self._tag_files(target.name)
        return places

    def references(self, target, include_declaration=True):
        """Every place \\p target is named, or None where that is not kept."""
        if target.what == EVENT:
            sites = []
            if include_declaration:
                sites += [e.id_site for e in self.index.events(target.name)]
            sites += self.index.fires(target.name)
        elif target.what == FLAG:
            sites = self.index.flag_sites(target.kind, target.name)
        elif target.what == MODIFIER:
            sites = list(self.index.modifier_uses(target.name))
            where = self.decl.where(Kinds.MODIFIER, target.name)
            if include_declaration and where:
                sites.insert(0, Place(where[1], where[2], 1, len(where[0]) + 1))
        else:
            return None
        return [Place(s.file, s.line, s.col, s.end) for s in sites]

    def keyword_place(self, entry):
        """Where \\p entry's row is in the keyword pages."""
        if self._doc_lines is None:
            lines = {}
            for page in S.PAGES:
                path = os.path.join(self.schema.docs_dir, page + ".md")
                with open(path, encoding="utf-8") as handle:
                    for number, line in enumerate(handle, 1):
                        match = re.match(r"^\|\s*`([^`]+)`\s*\|", line)
                        if match:
                            lines.setdefault((page, match.group(1).lower()), number)
            self._doc_lines = lines
        number = self._doc_lines.get((entry.page, entry.name.lower()))
        if number is None:
            return None
        docs = os.path.relpath(self.schema.docs_dir, self.session.root).replace("\\", "/")
        if docs.startswith(".."):
            # The pages built into the exe: an absolute path still opens.
            docs = self.schema.docs_dir.replace("\\", "/")
        return Place("%s/%s.md" % (docs, entry.page), number)

    def _tag_files(self, tag):
        """The country's own file in common/ and its history, where they exist."""
        if self._countries is None:
            countries = {}
            path = os.path.join(self.session.root, "common", "countries.txt")
            if os.path.exists(path):
                for node in parser.parse(lexer.read(self.session.root,
                                                    "common/countries.txt").text).root.children:
                    if node.is_pair and node.key and node.value:
                        countries[node.key.lower()] = "common/" + node.value.replace("\\", "/")
            histories = {}
            for found in glob.glob(os.path.join(self.session.root, "history", "countries",
                                                "*.txt")):
                name = os.path.basename(found)
                histories.setdefault(name[:3].lower(), os.path.relpath(
                    found, self.session.root).replace("\\", "/"))
            self._countries, self._histories = countries, histories
        places = []
        for rel in (self._countries.get(tag.lower()), self._histories.get(tag.lower())):
            if rel and os.path.exists(os.path.join(self.session.root, rel)):
                places.append(Place(rel, 1))
        return places

    def _modifier_body(self, name):
        if self._modifiers is None:
            table = {}
            rel = "common/event_modifiers.txt"
            if os.path.exists(os.path.join(self.session.root, rel)):
                for node in parser.parse(lexer.read(self.session.root, rel).text).root.children:
                    if node.is_block and node.key:
                        table.setdefault(node.lkey, node)
            self._modifiers = table
        node = self._modifiers.get(name.lower())
        if node is None:
            return []
        return ["%s = %s" % (c.key, c.value) for c in node.children
                if c.is_pair and c.key][:12]

    # --- outline -----------------------------------------------------------------------

    def outline(self, rel, parsed):
        folder = rel.split("/", 1)[0]
        if folder == "events":
            return [self._event_symbol(n) for n in parsed.root.children
                    if n.is_block and n.lkey in S.EVENT_TYPES]
        if folder == "decisions":
            out = []
            for category in parsed.root.children:
                if not category.is_block or category.key is None:
                    continue
                symbol = _symbol(category, category.key, "", "category")
                for decision in category.children:
                    if decision.is_block and decision.key:
                        symbol.children.append(_symbol(decision, decision.key,
                                                       self.decision_title(decision.key),
                                                       "decision"))
                out.append(symbol)
            return out
        return _blocks(parsed.root, depth=2)

    def _event_symbol(self, node):
        ident = node.child("id")
        title = node.child("title")
        name = ident.value if ident is not None and ident.value else "(no id)"
        text = self.text_of(title.value) if title is not None else ""
        symbol = _symbol(node, "%s %s" % (name, text) if text else name, node.key, "event")
        for option in node.children:
            if option.is_block and option.lkey == "option":
                label = option.child("name")
                text = self.text_of(label.value) if label is not None else ""
                symbol.children.append(_symbol(option, text or "option", "", "option"))
        return symbol

    def symbols(self, query, limit=500):
        """Events and decisions anywhere in the mod whose id, name or title holds \\p query."""
        words = query.lower().split()
        out = []
        for event in self.index.events():
            title = self.text_of(event.title)
            label = "%s %s" % (event.id, title) if title else event.id
            if all(w in label.lower() for w in words):
                out.append(Symbol(label, event.type, "event", event.line, 1, event.line, 1,
                                  file=event.file))
                if len(out) >= limit:
                    return out
        for decision in self.index.decisions():
            title = self.decision_title(decision.name)
            label = "%s %s" % (decision.name, title) if title else decision.name
            if all(w in label.lower() for w in words):
                out.append(Symbol(label, decision.category, "decision", decision.line,
                                  decision.col, decision.line, decision.col,
                                  file=decision.file))
                if len(out) >= limit:
                    break
        return out

    # --- the title of each event fired -------------------------------------------------

    def event_titles(self, parsed, first, last):
        """(line, column after the id, title) for every event fired between lines
        \\p first and \\p last."""
        out = []
        for token, (node, role) in owners(parsed).items():
            del token
            if role != "value" or node.lkey not in S.EVENT_TYPES:
                continue
            value = node.value_tok
            if not (first <= value.line <= last) or not node.value.isdigit():
                continue
            title = self.event_title(node.value)
            if title:
                out.append((value.line, value.col + _width(value), _short(title, _TITLE_LENGTH)))
        return sorted(out)

    # --- folding -----------------------------------------------------------------------

    @staticmethod
    def folds(parsed, lines):
        """(first line, last line, is a comment) of everything that can be folded: each
        block over more than two lines, down to the line before its closing bracket, and
        each run of comment lines."""
        out = []
        for node in parser.walk(parsed.root):
            if node.is_block and node.open_tok is not None and node.close_tok is not None:
                start = node.line
                end = node.close_tok.line - 1
                if end > start:
                    out.append((start, end, False))
        run = None
        for number, line in enumerate(list(lines) + [""], 1):
            if line.lstrip().startswith("#"):
                run = run or number
                continue
            if run is not None and number - 1 > run:
                out.append((run, number - 1, True))
            run = None
        return out

    # --- quick fixes -------------------------------------------------------------------

    def replacement(self, rule, word):
        """What a finding of \\p rule on \\p word can be fixed to, or None."""
        if rule == "BV101":
            return self.session.checker.suggest(word) or None
        if rule == "BV102":
            bad = self.session.checker.bad_keys.get(word.lower())
            if bad is not None and re.fullmatch(r"\w+", bad.instead):
                return bad.instead
        return None

    # --- completion --------------------------------------------------------------------

    def completions(self, rel, parsed, line, col):
        """(completions, whether the list is cut short) at \\p line, \\p col. A cut-short
        list is asked for again as the word grows."""
        index = _before(parsed, line, col)
        tokens = parsed.tokens
        prefix = ""
        if index >= 0:
            token = tokens[index]
            if token.kind == lexer.WORD and token.line == line \
                    and token.col + len(token.text) >= col:
                prefix = token.text[:col - token.col]
                index -= 1
        previous = tokens[index] if index >= 0 else None
        chain = block_chain(parsed, line, col)
        kind = block_kind(rel, chain)
        if previous is not None and previous.kind == lexer.OP and index >= 1 \
                and tokens[index - 1].kind == lexer.WORD:
            key = tokens[index - 1].text.lower()
            return self._values(rel, kind, key, chain, prefix)
        return self._keys(rel, kind, prefix, line), kind in (C.TRIGGER, C.EFFECT, C.OPTION,
                                                        C.MODIFIER, C.RANDOM)

    def _keys(self, rel, kind, prefix, line):
        if kind is None:
            return []
        out = []
        if kind == "events":
            next_id = self.index.next_event_id(rel, line)
            for name in sorted(S.EVENT_TYPES):
                out.append(Completion(name, "snippet", "a new event", insert=(
                    "%s = {\n\tid = ${1:%d}\n\tis_triggered_only = yes\n\ttitle = \"$2\"\n"
                    "\tdesc = \"$3\"\n\tpicture = \"$4\"\n\n\toption = {\n\t\tname = \"$5\"\n"
                    "\t\t$0\n\t}\n}" % (name, next_id))))
            return out
        if kind == "decisions":
            return [Completion(name, "keyword", "decision category", insert=_block(name))
                    for name in sorted(S.DECISION_CATEGORIES)]
        if kind == "category":
            return []
        fields = {C.EVENT: S.EVENT_KEYS, C.DECISION: S.DECISION_KEYS, C.MTTH: S.MTTH_KEYS,
                  C.CHANCE: S.CHANCE_KEYS}.get(kind)
        if fields is not None:
            return [Completion(name, "keyword", "", insert=_shaped(name, shape))
                    for name, shape in sorted(fields.items())]
        if kind == C.FIELDS or kind == C.RANDOM_LIST:
            return []
        checker = self.session.checker
        if kind == C.TRIGGER or kind == C.MODIFIER:
            names, wanted = checker.trigger_keys, ("trigger", "combat")
        else:
            names, wanted = checker.effect_keys, ("effect",)
        for name in sorted(names):
            entry = next((self.schema.get(name, w) for w in wanted
                          if self.schema.get(name, w)), None)
            if entry is None:
                continue
            out.append(Completion(entry.name, _KIND_NAMES.get(entry.kind, entry.kind),
                                  _KIND_NAMES.get(entry.kind, entry.kind),
                                  "%s\n\n    %s" % (entry.description, entry.syntax),
                                  _shaped(entry.name, entry.value)))
        extra = {"limit": S.BLOCK} if kind != C.TRIGGER and kind != C.MODIFIER else {}
        if kind == C.OPTION:
            extra.update({"name": S.ANY, "ai_chance": S.BLOCK})
        elif kind == C.MODIFIER:
            extra["factor"] = S.NUMBER
        elif kind == C.RANDOM:
            extra["chance"] = S.NUMBER
        for name in sorted(S.GENERIC_SCOPES):
            extra.setdefault(name.upper() if name in ("this", "from") else name, S.BLOCK)
        for name, shape in extra.items():
            out.append(Completion(name, "keyword", "", insert=_shaped(name, shape)))
        if len(prefix) >= 2:
            out += self._declared_keys(prefix)
        return out

    def _declared_keys(self, prefix):
        """Declared names a key may be, holding \\p prefix: a technology to test, a
        building, a unit, a country or a region to open a scope on."""
        low = prefix.lower()
        out = []
        for kind in (Kinds.TECH, Kinds.BUILDING, Kinds.UNIT, Kinds.TAG, Kinds.REGION,
                     Kinds.IDEOLOGY):
            for name_low, (name, _, _) in self.decl.names[kind].items():
                if low in name_low:
                    shape = S.BLOCK if kind in (Kinds.TAG, Kinds.REGION) else S.NUMBER
                    out.append(Completion(name, "name", kind,
                                          plain(self.loc.text(name) or ""),
                                          _shaped(name, shape)))
                    if len(out) >= _LIMIT:
                        return out
        return out

    def _values(self, rel, kind, key, chain, prefix):
        low = prefix.lower()
        if key in S.EVENT_TYPES:
            return self._event_values(rel, low)
        match = FLAG_KEY.match(key)
        if match:
            return [Completion(n, "value", "%s flag" % match.group(2))
                    for n in self.index.flag_names(match.group(2))], False
        parent = chain[-1].lkey if chain else None
        if key in MODIFIER_USES or (key == "name" and parent in MODIFIER_USES):
            return self._names(Kinds.MODIFIER), False
        if key in NAMED_VALUES:
            out = []
            for kind_ in NAMED_VALUES[key]:
                out += self._names(kind_)
            return out, False
        if key == "load_oob":
            return self._oob_values(low)
        entry = None
        for wanted in ("trigger", "combat", "effect", "header", "option"):
            entry = entry or self.schema.get(key, wanted)
        shape = entry.value if entry is not None else \
            {**S.EVENT_KEYS, **S.DECISION_KEYS}.get(key)
        if shape == S.BOOL:
            return [Completion("yes", "value"), Completion("no", "value")], False
        if shape in (S.TAG, "province or tag", "number or tag"):
            out = self._names(Kinds.TAG)
            out += [Completion(w, "keyword", "scope") for w in ("THIS", "FROM")]
            return out, False
        return [], False

    def _names(self, kind):
        return [Completion(name, "value", kind, plain(self.loc.text(name) or ""))
                for (name, _, _) in self.decl.names[kind].values()]

    def _event_values(self, rel, prefix):
        part = self.index.file(rel)
        own = {e.id for e in part.events} if part else set()
        out = []
        events = sorted(self.index.events(), key=lambda e: (e.id not in own,
                                                            int(e.id) if e.id.isdigit() else 0))
        for event in events:
            title = self.text_of(event.title)
            if prefix and not (event.id.startswith(prefix) or prefix in title.lower()):
                continue
            out.append(Completion(event.id, "event", title, filter="%s %s" % (event.id, title)))
            if len(out) >= _LIMIT:
                return out, True
        return out, False

    def _oob_values(self, prefix):
        folder = os.path.join(self.session.root, "history", "units")
        out = []
        for path in sorted(glob.glob(os.path.join(folder, "**", "*.txt"), recursive=True)):
            rel = os.path.relpath(path, folder).replace("\\", "/")
            if prefix in rel.lower():
                out.append(Completion(rel, "file", "order of battle"))
                if len(out) >= _LIMIT:
                    return out, True
        return out, False


def _sentence(parts):
    if len(parts) == 1:
        return parts[0][0].upper() + parts[0][1:]
    text = ", ".join(parts[:-1]) + " and " + parts[-1]
    return text[0].upper() + text[1:]


def _block(name):
    return "%s = {\n\t$0\n}" % name


def _shaped(name, shape):
    """A snippet for \\p name taking a value of \\p shape."""
    if shape == S.BLOCK:
        return _block(name)
    if shape == S.BOOL:
        return "%s = ${1|yes,no|}" % name
    return "%s = $0" % name


def _end_col(node):
    token = node.close_tok or node.value_tok or node.key_tok
    return token.col + (_width(token) if token.kind in (lexer.WORD, lexer.STRING) else 1)


def _symbol(node, name, detail, kind):
    end = node.close_tok or node.value_tok or node.key_tok
    return Symbol(name, detail, kind, node.line, node.col,
                  end.line if end is not None else node.line, _end_col(node))


def _blocks(node, depth):
    """Every keyed entry of \\p node, and the blocks inside them to \\p depth levels."""
    out = []
    for child in node.children or ():
        if child.key is None or child.op is None:
            continue
        if child.is_block:
            symbol = _symbol(child, child.key, "", "block")
            if depth > 1:
                symbol.children = [s for s in _blocks(child, depth - 1) if s.kind == "block"]
            out.append(symbol)
        elif node.parent is None:
            out.append(_symbol(child, child.key, child.value or "", "field"))
    return out
