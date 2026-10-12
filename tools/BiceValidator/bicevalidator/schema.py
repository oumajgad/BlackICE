"""What the engine accepts, read from the mod's own reference pages.

The trigger and effect lists in docs/script were read out of the game - `CTrigger::LoadKey`
and `CEffect::LoadKey` are each one switch over a key's token (reversing/findings/
FINDINGS-script.md) - so they are complete and fixed. This module reads them from those
pages rather than keeping a copy, because a copy drifts from its original and the pages are
what a modder reads anyway. A test pins the counts, so a page edit that breaks the tables
is caught rather than quietly shrinking the schema.

The one copy there is lives inside the bundled exe, so that it can check a mod with no
docs/ folder - an installed copy under tfh/mod. It is taken from docs/script each time the
exe is built and used only when the mod has no pages of its own (locate_keyword_pages).

What the pages do not say - which keys go directly inside an event, an option or a decision
- is in STRUCTURE below, and is inferred from how the mod uses them. Findings that rest on
it say so.
"""

import os
import re
import sys
from dataclasses import dataclass

# How a value is checked. Taken from each keyword's Syntax column.
BOOL, NUMBER, TAG, PROVINCE, BLOCK, ANY = "yes/no", "number", "tag", "province id", "block", "any"

PAGES = ("triggers", "effects", "scopes")
# Where BiceValidator.spec puts the pages inside the exe.
BUNDLED_FOLDER = "keywords"


def _has_pages(folder):
    return all(os.path.isfile(os.path.join(folder, page + ".md")) for page in PAGES)


def locate_keyword_pages(root):
    """(folder, description) of the keyword pages to read for the mod at \\p root.

    The mod's own docs/script first, since that is the source. Then the copy built into
    the exe. Then, when run from source against a mod without docs, the pages of the
    checkout the tool itself sits in.
    """
    own = os.path.join(root, "docs", "script")
    if _has_pages(own):
        return own, "docs/script"
    bundle = getattr(sys, "_MEIPASS", None)
    if bundle is not None:
        folder = os.path.join(bundle, BUNDLED_FOLDER)
        if _has_pages(folder):
            stamp = os.path.join(folder, "BUILT.txt")
            when = open(stamp, encoding="utf-8").read().strip() if os.path.exists(stamp) else ""
            return folder, "built into the exe" + (" (%s)" % when if when else "")
    tool_mod = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    tool_mod = os.path.dirname(tool_mod)
    own = os.path.join(tool_mod, "docs", "script")
    if _has_pages(own):
        return own, "docs/script of %s" % tool_mod
    raise FileNotFoundError("No keyword pages: %s has no docs/script, and this is neither "
                            "the bundled exe nor a copy run from a BlackICE checkout." % root)


@dataclass
class Keyword:
    name: str
    kind: str          # "trigger", "effect", "scope", "header", "option", "combat"
    syntax: str
    value: str         # one of the value types above
    description: str
    unverified: bool
    page: str          # docs/script/<page>.md


@dataclass
class BadKey:
    """A key that reads right and is not a keyword, with what to write instead."""
    name: str
    instead: str
    why: str
    page: str


_ROW = re.compile(r"^\|\s*`([^`]+)`\s*\|(.*)\|\s*$")


def _value_type(syntax, key=""):
    s = syntax.split("#")[0].split("--")[0].lower()
    # Only what follows the keyword's own "=" says what it takes: the Syntax column often
    # shows the scope around it, as in `<province id> = { secede_province = tag }`.
    own = re.search(r"\b%s\s*=?\s*(.*)$" % re.escape(key.lower()), s) if key else None
    if own is not None:
        rhs = own.group(1).strip()
    else:
        rhs = s.split("=", 1)[1].strip() if "=" in s else ""
    if not rhs.startswith("{") and "}" in rhs:
        # The keyword sat inside an example scope: `tag = { end_war = tag2 }`.
        rhs = rhs[:rhs.find("}")].strip()
    if "yes / no" in rhs or "yes/no" in rhs:
        return BOOL
    if rhs.startswith("{"):
        return BLOCK
    if rhs.startswith("<province id>"):
        return PROVINCE
    # `tag2`, `<country tag>`, or a choice of scope words and a tag: `this / from / tag`.
    if re.match(r"tag\d?\b", rhs) or rhs.startswith("<country tag>") \
            or re.fullmatch(r"(this|from|random|tag)( / (this|from|random|tag))+", rhs):
        return TAG
    if re.fullmatch(r"x", rhs):
        return NUMBER
    return ANY


def _cells(rest):
    # Split the rest of a row on unescaped pipes; descriptions never contain a bare one.
    return [c.strip() for c in rest.split("|")]


def _read_tables(path):
    """(section heading, key, other cells) for every keyword row of a page."""
    section = ""
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("#"):
                section = line.lstrip("#").strip()
                continue
            match = _ROW.match(line.rstrip("\n"))
            if match:
                yield section, match.group(1), _cells(match.group(2))


_SECTION_KIND = {
    ("triggers", "Event header keys"): "header",
    ("triggers", "Conditions"): "trigger",
    ("triggers", "Combat scope conditions"): "combat",
    ("effects", "Effects"): "effect",
    ("effects", "Inside an option"): "option",
    ("scopes", "Scopes"): "scope",
}


class Schema:
    def __init__(self, docs_dir):
        self.docs_dir = docs_dir
        self.keywords = {}      # lower name -> list of Keyword (a name can be both kinds)
        self.bad_keys = {}      # lower name -> BadKey
        for page in ("triggers", "effects", "scopes"):
            path = os.path.join(docs_dir, page + ".md")
            for section, key, cells in _read_tables(path):
                if page == "triggers" and section == "Keys that do not work":
                    self.bad_keys[key.lower()] = BadKey(key, cells[0].strip("`"),
                                                        cells[1], page)
                    continue
                kind = _SECTION_KIND.get((page, section))
                if kind is None or " " in key:
                    # "country tag", "province id" and the like are placeholders in the
                    # scopes table, handled as declared names rather than keywords.
                    continue
                description, syntax = cells[0], cells[1] if len(cells) > 1 else ""
                syntax = syntax.strip("`")
                value = VALUE_OVERRIDES.get(key.lower(), _value_type(syntax, key))
                self.keywords.setdefault(key.lower(), []).append(Keyword(
                    key, kind, syntax, value, description,
                    "(unverified)" in description, page))

    def kinds(self, key):
        return {k.kind for k in self.keywords.get(key.lower(), ())}

    def get(self, key, kind):
        for k in self.keywords.get(key.lower(), ()):
            if k.kind == kind:
                return k
        return None

    def names(self, kind):
        return {k for k, entries in self.keywords.items() if any(e.kind == kind for e in entries)}


# Where a page's Syntax column is narrower than what the game takes. Each was checked
# against the mod's own use, and against the pages' own examples where they show one.
VALUE_OVERRIDES = {
    # A date, not a number: `date = 1939.5.1`.
    "date": "date",
    # In a province scope these take the country: `is_core = CHI` is the README's own
    # example, and the mod writes the tag form hundreds of times.
    "is_core": "province or tag",
    "add_core": "province or tag",
    "remove_core": "province or tag",
    # `country_units_in_province = THIS` in a province scope, 50 times in the mod.
    "country_units_in_province": "number or tag",
}

# Keys that need no keyword to be valid in a script block: they are scopes the event
# system handles before either switch is consulted. From docs/script/scopes.md, minus the
# ones that are also triggers or effects (those are keywords already).
GENERIC_SCOPES = {"this", "from", "owner", "controller", "capital_scope"}

# The structure of the files themselves, which the keyword pages do not cover. Inferred
# from how the mod writes them: every key here is used hundreds of times in files that work.
EVENT_TYPES = {"country_event", "province_event"}
EVENT_KEYS = {
    "id": NUMBER, "title": ANY, "desc": ANY, "picture": ANY, "is_triggered_only": BOOL,
    "fire_only_once": BOOL, "major": BOOL, "trigger": BLOCK, "mean_time_to_happen": BLOCK,
    "option": BLOCK,
}
DECISION_CATEGORIES = {"diplomatic_decisions", "political_decisions", "economic_decisions"}
DECISION_KEYS = {"potential": BLOCK, "allow": BLOCK, "effect": BLOCK, "ai_will_do": BLOCK,
                 "major": BOOL}
OPTION_KEYS = {"name": ANY, "ai_chance": BLOCK}
MTTH_KEYS = {"days": NUMBER, "months": NUMBER, "years": NUMBER, "modifier": BLOCK}
CHANCE_KEYS = {"factor": NUMBER, "modifier": BLOCK}

# Keyword blocks whose insides are named fields rather than script. Inner keys are inferred
# from use; an unknown one is a warning, not an error.
BLOCK_FIELDS = {
    "add_country_modifier": {"name", "duration"},
    "add_province_modifier": {"name", "duration"},
    "relation": {"who", "value"},
    "threat": {"who", "value"},
    "check_variable": {"which", "value"},
    "set_variable": {"which", "value"},
    "change_variable": {"which", "value"},
    "war": {"target", "attacker_goal", "defender_goal"},
    "add_wargoal": {"target", "war_goal", "type"},
    "has_cb": {"actor", "type"},
    "casus_belli": {"target", "type"},
}
