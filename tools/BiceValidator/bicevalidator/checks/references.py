"""Whether what a file names exists somewhere else in the mod.

These checks need the whole mod read, so they run once after the per-file pass, over the
parsed events, decisions and `common/`, plus a plain text scan of the folders that only
need to be searched (Lua, histories, technologies).
"""

import glob
import os
import re
from collections import defaultdict

from ..diagnostic import Diagnostic, Related
from ..context import describe
from ..declarations import Kinds
from .. import parser, schema as S

_SCOPE_WORDS = {"this", "from", "root", "prev", "all", "random", "none"}
# `exists = yes` is written 157 times; whether the engine reads it as the scope's own
# existence or as a tag called "yes" is not read, so yes/no are left alone.
_NOT_TAGS = _SCOPE_WORDS | {"yes", "no"}

# Keywords whose value is a name of a kind the mod declares.
NAMED_VALUES = {
    "ideology": (Kinds.IDEOLOGY,),
    "ideology_group": (Kinds.IDEOLOGY_GROUP,),
    "government": (Kinds.GOVERNMENT,),
    "region": (Kinds.REGION,),
    "continent": (Kinds.CONTINENT,),
    "has_building": (Kinds.BUILDING,),
    "strategic_resource": (Kinds.RESOURCE,),
    "faction": (Kinds.FACTION,),
    "join_faction": (Kinds.FACTION,),
    "leave_faction": (Kinds.FACTION,),
}

# Adding or testing a modifier nobody declared is a fault; removing one is harmless, and
# the mod does it routinely to clear a set of alternatives, so `remove_*` is not checked.
MODIFIER_KEYS = {"add_country_modifier", "has_country_modifier",
                 "add_province_modifier", "has_province_modifier"}

FLAG_KEY = re.compile(r"^(set|clr|has)_(country|global|province)_flag$")
FLAG_TEXT = re.compile(r"(set|clr|has)_(country|global|province)_flag\s*=\s*\"?([\w.\-]+)",
                       re.IGNORECASE)
# Lua names a flag as a string; any quoted word there counts as a possible use.
LUA_STRING = re.compile(r"[\"']([\w.\-]+)[\"']")

LOC_KEY = re.compile(r"^[A-Za-z0-9_.\-]+$")


def _strip_comments(text):
    return re.sub(r"#[^\n]*", "", text)


def _read_text(path):
    with open(path, "rb") as handle:
        return handle.read().decode("cp1252", errors="replace")


def _localisation_keys(root):
    keys = set()
    for path in glob.glob(os.path.join(root, "localisation", "*.csv")):
        for line in _read_text(path).splitlines():
            if not line or line.startswith("#"):
                continue
            key = line.split(";", 1)[0].strip()
            if key:
                keys.add(key.lower())
    return keys


def _flags_elsewhere(root):
    """Flag names set and tested outside events and decisions, and every quoted word in
    the Lua scripts, which may set or test a flag in a way no pattern can follow."""
    set_, tested = defaultdict(set), defaultdict(set)
    for folder, pattern in (("common", "**/*.txt"), ("technologies", "**/*.txt"),
                            ("history", "countries/*.txt"), ("history", "units/**/*.txt"),
                            ("units", "*.txt")):
        for path in glob.glob(os.path.join(root, folder, pattern), recursive=True):
            for verb, scope, name in FLAG_TEXT.findall(_strip_comments(_read_text(path))):
                (tested if verb.lower() == "has" else set_)[scope.lower()].add(name.lower())
    lua = set()
    for path in glob.glob(os.path.join(root, "script", "**", "*.lua"), recursive=True):
        lua.update(w.lower() for w in LUA_STRING.findall(_read_text(path)))
    return set_, tested, lua


class _Collector:
    def __init__(self, decl):
        self.decl = decl
        self.out = []
        self.events = {}            # id -> (file, node)
        self.fires = []             # (file, node, id)
        self.flag_set = defaultdict(dict)     # scope -> name -> (file, node)
        self.flag_tested = defaultdict(dict)

    def report(self, rule, path, node, message, hint="", related=None, at_value=True):
        token = node.value_tok if at_value and node.value_tok is not None else \
            (node.key_tok or node.open_tok)
        self.out.append(Diagnostic(rule, path, token.line, token.col, message,
                                   context=describe(node), hint=hint, related=related or []))


def check(root, files, decl, schema):
    c = _Collector(decl)
    loc = _localisation_keys(root)
    tag_keys = {k for k, entries in schema.keywords.items()
                if any(e.value == S.TAG for e in entries)}
    province_keys = {k for k, entries in schema.keywords.items()
                     if any(e.value in (S.PROVINCE, "province or tag") for e in entries)}

    for rel in sorted(files):
        folder = rel.split("/", 1)[0]
        if folder not in ("events", "decisions"):
            continue
        root_node = files[rel].result.root
        if folder == "events":
            _event_definitions(c, rel, root_node, loc)
        else:
            _decision_definitions(c, rel, root_node, loc)
        for node in parser.walk(root_node):
            _node(c, rel, node, tag_keys, province_keys, root)

    on_actions = files.get("common/on_actions.txt")
    if on_actions is not None:
        for node in parser.walk(on_actions.result.root):
            if node.is_pair and node.value and node.value.isdigit() \
                    and node.parent is not None and node.parent.key is not None:
                c.fires.append(("common/on_actions.txt", node, node.value))

    for path, node, ident in c.fires:
        if ident not in c.events:
            c.report("BV201", path, node, "Event %s does not exist" % ident)

    _flags(c, root)
    _flag_images(c, root, decl)
    return c.out


def _event_definitions(c, rel, root_node, loc):
    for event in root_node.children:
        if not (event.is_block and event.lkey in S.EVENT_TYPES):
            continue
        ident = event.child("id")
        if ident is not None and ident.value:
            if ident.value in c.events:
                first_file, first = c.events[ident.value]
                c.report("BV202", rel, ident, "Event id %s is also used at %s:%d"
                         % (ident.value, first_file, first.line),
                         related=[Related("first event with this id", first_file,
                                          first.line, first.col)])
            else:
                c.events[ident.value] = (rel, ident)
        for key in ("title", "desc"):
            _loc_value(c, rel, event.child(key), loc)
        for option in event.children:
            if option.is_block and option.lkey == "option":
                _loc_value(c, rel, option.child("name"), loc)


def _decision_definitions(c, rel, root_node, loc):
    for category in root_node.children:
        if not (category.is_block and category.lkey in S.DECISION_CATEGORIES):
            continue
        for decision in category.children:
            # A decision's name is looked up as `<name>_title` (localisation/zDD-Decisions.csv
            # has AI_multiroleboost_title for decision AI_multiroleboost).
            if decision.is_block and decision.key \
                    and (decision.key + "_title").lower() not in loc \
                    and decision.key.lower() not in loc:
                c.report("BV206", rel, decision, "Decision `%s` has no `%s_title` localisation"
                         % (decision.key, decision.key), at_value=False)


def _loc_value(c, rel, node, loc):
    if node is None or not node.value:
        return
    value = node.value
    if LOC_KEY.match(value) and value.lower() not in loc and not value.isdigit():
        # A single word with no localisation could be inline text, so only keys that look
        # like keys - containing a digit or an underscore, or in capitals - are reported.
        if any(ch.isdigit() for ch in value) or "_" in value or value.isupper():
            c.report("BV206", rel, node, "No localisation for `%s`" % value)


def _node(c, rel, node, tag_keys, province_keys, root):
    low = node.lkey
    if low is None or node.op is None:
        return
    decl = c.decl

    if low in ("country_event", "province_event") and node.parent is not None \
            and node.parent.key is not None:
        if node.value and node.value.isdigit():
            c.fires.append((rel, node, node.value))
        elif node.is_block:
            ident = node.child("id")
            if ident is not None and ident.value and ident.value.isdigit():
                c.fires.append((rel, ident, ident.value))
        return

    if node.is_block and low.isdigit():
        # Inside random_list a number is a weight, `0 = { ... }` included, not a province.
        if node.parent is not None and node.parent.lkey == "random_list":
            return
        if not decl.has(Kinds.PROVINCE, low):
            c.report("BV205", rel, node, "Province %s does not exist" % low, at_value=False)
        return

    value = node.value
    if value is None:
        if low in MODIFIER_KEYS and node.is_block:
            name = node.child("name")
            if name is not None and name.value and not decl.has(Kinds.MODIFIER, name.value):
                c.report("BV207", rel, name, "Modifier `%s` is not declared" % name.value)
        return
    vlow = value.lower()

    if low == "load_oob":
        target = os.path.join(root, "history", "units", value)
        if not os.path.exists(target):
            c.report("BV203", rel, node, "No file history/units/%s" % value)
        return

    if low in MODIFIER_KEYS:
        if not decl.has(Kinds.MODIFIER, value):
            c.report("BV207", rel, node, "Modifier `%s` is not declared" % value)
        return

    match = FLAG_KEY.match(low)
    if match:
        verb, scope = match.group(1), match.group(2)
        table = c.flag_tested if verb == "has" else c.flag_set
        table[scope].setdefault(vlow, (rel, node))
        return

    if low in NAMED_VALUES and vlow not in _SCOPE_WORDS:
        kinds = NAMED_VALUES[low]
        if not any(decl.has(kind, value) for kind in kinds):
            c.report("BV211", rel, node, "`%s` is not a declared %s"
                     % (value, " or ".join(kinds)))
        return

    if low in tag_keys and vlow not in _NOT_TAGS and not vlow.isdigit():
        if not decl.has(Kinds.TAG, value):
            c.report("BV204", rel, node, "Country `%s` does not exist" % value)
        return

    if low in province_keys and value.isdigit():
        if not decl.has(Kinds.PROVINCE, value):
            c.report("BV205", rel, node, "Province %s does not exist" % value)


def _flags(c, root):
    set_elsewhere, tested_elsewhere, lua = _flags_elsewhere(root)
    for scope, names in c.flag_tested.items():
        for name, (rel, node) in names.items():
            if name in c.flag_set[scope] or name in set_elsewhere[scope] or name in lua:
                continue
            c.report("BV208", rel, node, "%s flag `%s` is tested but never set"
                     % (scope.capitalize(), node.value))
    for scope, names in c.flag_set.items():
        for name, (rel, node) in names.items():
            if node.lkey.startswith("clr"):
                continue
            if name in c.flag_tested[scope] or name in tested_elsewhere[scope] or name in lua:
                continue
            c.report("BV209", rel, node, "%s flag `%s` is set but never tested"
                     % (scope.capitalize(), node.value))


def _flag_images(c, root, decl):
    folder = os.path.join(root, "gfx", "flags")
    present = {f.lower() for f in os.listdir(folder)} if os.path.isdir(folder) else set()
    for low, (name, rel, line) in sorted(decl.names[Kinds.TAG].items()):
        if (low + ".tga") not in present:
            c.out.append(Diagnostic("BV210", rel, line, 1,
                                    "Country `%s` has no gfx/flags/%s.tga" % (name, name),
                                    context=name))
