"""Whether each key in an event or decision is one the engine will read, where it stands.

Every block is read by one loader: a condition block (`trigger`, `limit`, `allow`,
`potential`) by `CTrigger::LoadKey`, an effect block (`option`, `effect`) by
`CEffect::LoadKey`. A key either of them does not know falls through to the declared
names - provinces, ideologies, then the databases - and is dropped silently if it is none
of those (reversing/findings/FINDINGS-script.md). That silent drop is the main thing this
module looks for.
"""

import re

from ..diagnostic import Diagnostic, Related
from ..context import describe
from .. import schema as S
from ..declarations import Kinds

# Contexts a block can be read in.
TRIGGER, EFFECT, EVENT, OPTION, DECISION, MTTH, CHANCE, MODIFIER, RANDOM, RANDOM_LIST, \
    FIELDS, SKIP = ("trigger", "effect", "event", "option", "decision", "mtth", "chance",
                    "modifier", "random", "random_list", "fields", "skip")

# Keys the reversing found in the mod doing nothing, beyond the docs' table.
# reversing/findings/FINDINGS-script.md, "What the mod says that none of this is".
EXTRA_BAD_KEYS = {
    "change_owner": S.BadKey("change_owner", "secede_province",
                             "not an effect: the province changes controller but keeps "
                             "its owner", "FINDINGS-script.md"),
    "has_naval_base": S.BadKey("has_naval_base", "naval_base = <level>",
                               "not a trigger; a building is tested by its own name",
                               "FINDINGS-script.md"),
}

# Keywords the engine accepts and then does nothing with, from docs/script/effects.md.
DOES_NOTHING = {
    "fixed_ai_strategy": "sets a byte nothing in the game reads (docs/script/effects.md)",
    "modify_spies": "its block is never read, so it runs with no target "
                    "(docs/script/effects.md)",
}

# Block keywords that hold more script of the same kind, or a scope's script.
TRIGGER_GROUPS = {"and", "or", "not"}
SINGLE_KEYS = {
    EVENT: {"id", "title", "desc", "picture", "is_triggered_only", "fire_only_once", "major",
            "trigger", "mean_time_to_happen"},
    OPTION: {"name", "ai_chance"},
    DECISION: {"potential", "allow", "effect", "ai_will_do"},
}

_NUMBER = re.compile(r"^[+-]?(\d+(\.\d*)?|\.\d+)$")
_DATE = re.compile(r"^\d{1,4}\.\d{1,2}\.\d{1,2}(\.\d{1,2})?$")
_TAG_SHAPE = re.compile(r"^[A-Za-z0-9]{3}$")
_SCOPE_WORDS = {"this", "from", "root", "prev"}


def _is_tagish(value):
    return bool(_TAG_SHAPE.match(value)) or value.lower() in _SCOPE_WORDS


class ScriptChecker:
    def __init__(self, schema, declarations):
        self.schema = schema
        self.decl = declarations
        bad = dict(schema.bad_keys)
        bad.update(EXTRA_BAD_KEYS)
        self.bad_keys = bad
        self.trigger_keys = schema.names("trigger") | schema.names("combat")
        self.effect_keys = schema.names("effect")
        self.option_keys = schema.names("option")
        self.effect_scope_keys = {k for k in self.effect_keys
                                  if k.startswith(("any_", "random_")) and k != "random_list"}
        self.trigger_scope_keys = {k for k in self.trigger_keys if k.startswith("any_")}
        self._pool = None
        self._suggestions = {}

    # --- entry points ------------------------------------------------------------------

    def check_events(self, source, root):
        self.out = []
        self.path = source.path
        for node in root.children:
            if node.is_block and node.lkey in S.EVENT_TYPES:
                self._event(node)
            elif node.key is not None:
                self._report("BV112", node, "`%s` at the top of an event file is not an "
                             "event; only `country_event` and `province_event` are read"
                             % node.key)
        return self.out

    def check_decisions(self, source, root):
        self.out = []
        self.path = source.path
        for category in root.children:
            if not (category.is_block and category.lkey in S.DECISION_CATEGORIES):
                if category.key is not None:
                    self._report("BV112", category, "`%s` at the top of a decision file is "
                                 "not a decision category" % category.key)
                continue
            for decision in category.children:
                if decision.is_block:
                    self._decision(decision)
                elif decision.key is not None:
                    self._report("BV104", decision, "`%s` directly in `%s`: a category "
                                 "holds decisions, each a block" % (decision.key, category.key))
        return self.out

    # --- reporting ---------------------------------------------------------------------

    def _report(self, rule, node, message, hint="", related=None, at_value=False):
        token = node.value_tok if at_value and node.value_tok is not None else \
            (node.key_tok or node.open_tok)
        line, col = (token.line, token.col) if token is not None else (node.line, node.col)
        self.out.append(Diagnostic(rule, self.path, line, col, message,
                                   context=describe(node), hint=hint,
                                   related=related or []))

    def _duplicates(self, block, kind):
        seen = {}
        for child in block.children:
            low = child.lkey
            if low in SINGLE_KEYS[kind] and child.op is not None:
                if low in seen:
                    first = seen[low]
                    self._report("BV106", child, "`%s` given twice" % child.key,
                                 related=[Related("first one", self.path, first.line, first.col)])
                else:
                    seen[low] = child

    def _bare(self, block):
        """Report the bare words in a script block; the callers then skip them.

        Two bare words on one line are one fault - `factor 100` with its `=` left out -
        and are reported once, at the first.
        """
        children = block.children
        skip_next = False
        for index, child in enumerate(children):
            if child.op is not None or child.key is None:
                skip_next = False
                continue
            if skip_next:
                skip_next = False
                continue
            following = children[index + 1] if index + 1 < len(children) else None
            if following is not None and following.op is None and following.key is not None \
                    and following.line == child.line:
                self._report("BV113", child, "`%s %s` is missing its `=`"
                             % (child.key, following.key))
                skip_next = True
            else:
                self._report("BV113", child, "Bare `%s` in `%s`"
                             % (child.key, block.key or "{"))

    # --- the file structure ------------------------------------------------------------

    def _event(self, event):
        self._duplicates(event, EVENT)
        self._bare(event)
        options = 0
        triggered_only = False
        has_trigger = False
        for child in event.children:
            low = child.lkey
            if child.op is None and low is not None:
                continue
            if low is None:
                self._report("BV104", child, "A block with no key directly in an event")
                continue
            if low == "option":
                options += 1
                if self._expect_block(child):
                    self._option(child)
            elif low == "trigger":
                has_trigger = True
                if self._expect_block(child):
                    self._block(child, TRIGGER)
            elif low == "mean_time_to_happen":
                if self._expect_block(child):
                    self._block(child, MTTH)
            elif low in S.EVENT_KEYS:
                if low == "is_triggered_only" and (child.value or "").lower() == "yes":
                    triggered_only = True
                self._check_value(child, S.EVENT_KEYS[low])
            else:
                self._misplaced(child, "an event", EVENT)
        if options == 0:
            self._report("BV107", event, "Event has no `option`")
        if not triggered_only and not has_trigger:
            self._report("BV108", event, "Event is neither `is_triggered_only = yes` nor "
                         "has a `trigger` block")

    def _option(self, option):
        self._duplicates(option, OPTION)
        self._bare(option)
        for child in option.children:
            low = child.lkey
            if child.op is None and low is not None:
                continue
            if low == "name":
                self._check_value(child, S.ANY)
            elif low == "ai_chance":
                if self._expect_block(child):
                    self._block(child, CHANCE)
            else:
                self._key(child, EFFECT)

    def _decision(self, decision):
        self._duplicates(decision, DECISION)
        self._bare(decision)
        for child in decision.children:
            low = child.lkey
            if child.op is None and low is not None:
                continue
            if low in ("potential", "allow"):
                if self._expect_block(child):
                    self._block(child, TRIGGER)
            elif low == "effect":
                if self._expect_block(child):
                    self._block(child, EFFECT)
            elif low == "ai_will_do":
                if self._expect_block(child):
                    self._block(child, CHANCE)
            elif low in S.DECISION_KEYS:
                self._check_value(child, S.DECISION_KEYS[low])
            else:
                self._misplaced(child, "a decision", DECISION)

    def _misplaced(self, child, where, kind):
        if child.key is None:
            self._report("BV104", child, "A block with no key directly in %s" % where)
            return
        allowed = {EVENT: "id, title, desc, picture, is_triggered_only, fire_only_once, "
                          "major, trigger, mean_time_to_happen, option",
                   DECISION: "potential, allow, effect, ai_will_do, major"}[kind]
        what = self._what_is(child.key)
        hint = "Only %s belong here." % allowed
        if what:
            hint = "`%s` is %s, so it belongs inside a block. %s" % (child.key, what, hint)
        self._report("BV104", child, "`%s` directly in %s" % (child.key, where), hint=hint)

    def _what_is(self, key):
        kinds = self.schema.kinds(key)
        if "effect" in kinds and ("trigger" in kinds or "combat" in kinds):
            return "a condition and an effect"
        if "effect" in kinds:
            return "an effect"
        if "trigger" in kinds or "combat" in kinds:
            return "a condition"
        declared = self.decl.resolve_key(key)
        if declared:
            return "a %s" % declared
        return ""

    def _expect_block(self, node):
        if node.is_block:
            return True
        if node.op is not None and node.value is not None:
            self._report("BV105", node, "`%s` expects a block, not `%s`"
                         % (node.key, node.value), at_value=True)
        return False

    # --- script blocks -----------------------------------------------------------------

    def _block(self, block, kind):
        self._bare(block)
        for child in block.children:
            if child.op is None and child.key is not None:
                continue
            if child.key is None:
                if child.is_block:
                    self._report("BV104", child, "A block with no key inside `%s`"
                                 % (block.key or "{"))
                continue
            if kind in (TRIGGER, EFFECT):
                self._key(child, kind)
            elif kind == MTTH:
                self._fields(child, S.MTTH_KEYS, MODIFIER)
            elif kind == CHANCE:
                self._fields(child, S.CHANCE_KEYS, MODIFIER)
            elif kind == MODIFIER:
                if child.lkey == "factor":
                    self._check_value(child, S.NUMBER)
                else:
                    self._key(child, TRIGGER)
            elif kind == RANDOM:
                if child.lkey == "chance":
                    self._check_value(child, S.NUMBER)
                else:
                    self._key(child, EFFECT)
            elif kind == RANDOM_LIST:
                if not _NUMBER.match(child.key):
                    self._report("BV111", child, "`random_list` holds weighted blocks like "
                                 "`50 = { ... }`, not `%s`" % child.key)
                elif self._expect_block(child):
                    self._block(child, EFFECT)

    def _fields(self, child, fields, nested):
        low = child.lkey
        if low not in fields:
            self._report("BV111", child, "`%s` is not expected in `%s`"
                         % (child.key, child.parent.key))
            return
        if fields[low] == S.BLOCK:
            if self._expect_block(child):
                self._block(child, nested)
        else:
            self._check_value(child, fields[low])

    def _key(self, node, kind):
        """One key inside a condition or effect block."""
        low = node.lkey
        if node.op is None:
            # A bare word; the syntax check reports it if it sits among pairs.
            return
        keywords = self.trigger_keys if kind == TRIGGER else self.effect_keys
        other = self.effect_keys if kind == TRIGGER else self.trigger_keys

        if low in keywords:
            self._keyword(node, kind)
            return
        if low in S.GENERIC_SCOPES or low == "limit":
            if self._expect_block(node):
                self._block(node, TRIGGER if (kind == TRIGGER or low == "limit") else EFFECT)
            return
        bad = self.bad_keys.get(low)
        if bad is not None and not (kind == EFFECT and low in self.effect_keys):
            self._report("BV102", node, "`%s` is not %s: use `%s`"
                         % (node.key, "a condition" if kind == TRIGGER else "an effect",
                            bad.instead),
                         hint=bad.why)
            return
        declared = self.decl.resolve_key(node.key)
        if declared is not None:
            if node.is_block:
                # A province, a country or a region opens a scope; the block is script of
                # the same kind, with `limit` allowed in an effect.
                self._block(node, kind)
            return
        if low in other:
            where = "a condition block" if kind == TRIGGER else "an effect block"
            is_what = "an effect" if kind == TRIGGER else "a condition"
            self._report("BV103", node, "`%s` is %s, and this is %s"
                         % (node.key, is_what, where),
                         hint="The engine reads this block for %s only and drops the key."
                              % ("conditions" if kind == TRIGGER else "effects"))
            if node.is_block:
                self._block(node, kind)
            return
        if low in self.option_keys and node.parent is not None and node.parent.lkey == "option":
            return
        self._unknown(node, kind)

    def _unknown(self, node, kind):
        hint = ""
        close = self._closest(node.lkey)
        if close:
            hint = "Did you mean `%s`?" % close
        self._report("BV101", node, "`%s` is not %s keyword or a declared name"
                     % (node.key, "a condition" if kind == TRIGGER else "an effect"), hint=hint)

    def suggest(self, key):
        """The real name \\p key was most likely meant to be, or ""."""
        return self._closest(key.lower())

    def _closest(self, low):
        """The nearest real name to a key nothing declares, for a "did you mean" hint."""
        if low in self._suggestions:
            return self._suggestions[low]
        import difflib
        if self._pool is None:
            pool = set(self.trigger_keys) | set(self.effect_keys)
            for kind in (Kinds.TECH, Kinds.BUILDING, Kinds.UNIT):
                pool |= set(self.decl.names[kind])
            self._pool = sorted(pool)
        # A 0.85 ratio cannot be reached across a length difference of more than a fifth,
        # so the candidates can be cut down before difflib sees them.
        span = max(2, len(low) // 5)
        candidates = [n for n in self._pool if abs(len(n) - len(low)) <= span]
        match = difflib.get_close_matches(low, candidates, n=1, cutoff=0.85)
        self._suggestions[low] = match[0] if match else ""
        return self._suggestions[low]

    def _keyword(self, node, kind):
        low = node.lkey
        entry = self.schema.get(low, "trigger" if kind == TRIGGER else "effect") or \
            self.schema.get(low, "combat")
        if low in DOES_NOTHING:
            self._report("BV110", node, "`%s` does nothing" % node.key, hint=DOES_NOTHING[low])
        if kind == TRIGGER and low == "has_strategic_resource" \
                and (node.value or "").lower() == "no":
            self._report("BV110", node, "`has_strategic_resource = no` does not always work",
                         hint="Write `not = { has_strategic_resource = yes }` instead "
                              "(docs/script/triggers.md).")
        if node.is_block:
            if kind == TRIGGER and (low in TRIGGER_GROUPS or low in self.trigger_scope_keys):
                self._block(node, TRIGGER)
            elif kind == EFFECT and low in self.effect_scope_keys:
                self._block(node, EFFECT)
            elif kind == EFFECT and low == "random":
                self._block(node, RANDOM)
            elif kind == EFFECT and low == "random_list":
                self._block(node, RANDOM_LIST)
            elif low in S.BLOCK_FIELDS:
                fields = S.BLOCK_FIELDS[low]
                for child in node.children:
                    if child.key is not None and child.lkey not in fields:
                        self._report("BV111", child, "`%s` is not expected in `%s`"
                                     % (child.key, node.key))
            elif entry is not None and entry.value in (S.BOOL, S.NUMBER, S.PROVINCE, "date"):
                self._report("BV105", node, "`%s` expects %s, not a block"
                             % (node.key, _a(entry.value)))
            return
        self._check_value(node, entry.value if entry is not None else S.ANY)

    def _check_value(self, node, value_type):
        value = node.value
        if node.is_block:
            if value_type in (S.BOOL, S.NUMBER, S.PROVINCE):
                self._report("BV105", node, "`%s` expects %s, not a block"
                             % (node.key, _a(value_type)))
            return
        if value is None:
            return
        ok = True
        if value_type == S.BOOL:
            ok = value.lower() in ("yes", "no")
        elif value_type == S.NUMBER:
            ok = bool(_NUMBER.match(value))
        elif value_type == S.PROVINCE:
            ok = value.isdigit()
        elif value_type == "province or tag":
            ok = value.isdigit() or _is_tagish(value)
        elif value_type == "number or tag":
            ok = bool(_NUMBER.match(value)) or _is_tagish(value)
        elif value_type == "date":
            ok = bool(_DATE.match(value)) or bool(_NUMBER.match(value))
        elif value_type == S.BLOCK:
            ok = False
        if not ok:
            self._report("BV105", node, "`%s` expects %s, not `%s`"
                         % (node.key, _a(value_type), value), at_value=True)


def _a(value_type):
    return {S.BOOL: "yes or no", S.NUMBER: "a number", S.PROVINCE: "a province id",
            S.BLOCK: "a block", S.TAG: "a country tag", "date": "a date like 1939.5.1",
            "province or tag": "a province id or a country", "number or tag": "a number or a country"
            }.get(value_type, value_type)
