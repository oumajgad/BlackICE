"""Whether a data file - an order of battle, a history, a technology, a unit type, a file of
common/ or map/ - holds what its loader reads.

Each kind of file has a schema (schemas/). A key the schema does not list is reported,
because these loaders refuse a key they do not know just as the script loaders do - and in
an order of battle a refused block wrecks the rest of the file (docs/script/oob.md, "One
wrong key wrecks the rest of the file"). Values are checked for their kind, and names for
existing; conditions and effects inside these files go to the script checker.
"""

import difflib
import os
import re

from ..context import describe
from ..diagnostic import Diagnostic
from ..schemas import DECLARED, describe_value

_NUMBER = re.compile(r"^[+-]?(\d+(\.\d*)?|\.\d+)$")
_INTEGER = re.compile(r"^[+-]?\d+$")
_DATE = re.compile(r"^\d{1,4}\.\d{1,2}\.\d{1,2}(\.\d{1,2})?$")
_IDENTIFIER = re.compile(r"^[A-Za-z_][\w.\-]*$")
_UNIT_NUMBER = re.compile(r"^([A-Za-z_]\w*)\.(\d+)$")


class DataChecker:
    def __init__(self, registry, declarations, script_checker=None, root=None):
        self.registry = registry
        self.decl = declarations
        self.script = script_checker
        self.root = root

    def check(self, source, root_node):
        """Findings for the parsed file, or [] if no schema reads it."""
        schema = self.registry.for_file(source.path)
        if schema is None:
            return []
        self.out = []
        self.path = source.path
        self.schema = schema
        self._block(root_node, schema.root, "this file")
        return self.out

    # --- reporting ---------------------------------------------------------------------

    def _report(self, rule, node, message, hint="", at_value=False):
        token = node.value_tok if at_value and node.value_tok is not None else \
            (node.key_tok or node.open_tok)
        line, col = (token.line, token.col) if token is not None else (1, 1)
        self.out.append(Diagnostic(rule, self.path, line, col, message,
                                   context=describe(node), hint=hint))

    # --- blocks ------------------------------------------------------------------------

    def _block(self, node, block, where):
        seen = {}
        for child in node.children or ():
            if child.key is None:
                if child.is_block and not block.open:
                    self._report("BV303", child, "A block with no key in %s" % where)
                continue
            if child.op is None:
                # A bare word among keys is the syntax check's (BV010); in a list it is
                # one of the list's items.
                if block.list:
                    self._item(child, block.list, where)
                continue
            spec = block.find(child.key, self._takes)
            if spec is None:
                if not block.open:
                    self._unknown(child, block, where)
                continue
            low = child.lkey
            if not spec.repeat:
                first = seen.get(low)
                if first is not None:
                    self._report("BV305", child, "`%s` given twice in %s; only one of them "
                                 "takes effect" % (child.key, where))
                else:
                    seen[low] = child
            self._value(child, spec)
        for name, spec in block.keys.items():
            if spec.required and name not in seen:
                self._report("BV304", node, "%s has no `%s`" % (_cap(where), spec.name),
                             hint=spec.desc)

    def _unknown(self, child, block, where):
        if block.confidence != "confirmed":
            rule = "BV302"
        else:
            rule = "BV301" if child.is_block and not block.skips_unknown else "BV308"
        names = [p.match for p in block.patterns if p.match not in ("any", "date")]
        message = "`%s` is not a key of %s" % (child.key, where)
        if names:
            message = "`%s` is neither a key of %s nor %s" % (
                child.key, where, " nor ".join(_a(_pattern_word(n)) for n in names))
        hints = []
        close = difflib.get_close_matches(child.lkey, list(block.keys), n=1, cutoff=0.75)
        if close:
            hints.append("Did you mean `%s`?" % block.keys[close[0]].name)
        if child.is_block and block.skips_unknown and rule == "BV308":
            hints.append("This loader drops the whole block; nothing else is lost.")
        elif child.is_block and rule == "BV301":
            hints.append("The game refuses the key but not its block: what is inside is read "
                         "as keys of %s, and the block's own `}` ends %s early." % (where, where))
        elif rule == "BV308":
            hints.append("The game skips the key and its value; nothing else is lost.")
        self._report(rule, child, message, hint=" ".join(hints))

    def takes(self, match, key):
        return self._takes(match, key)

    def block_at(self, rel, chain):
        """(schema, Block) that the innermost block of \\p chain (the file's root first) is
        read as, or (schema, None) where the schema says nothing about it, or (None, None)
        for a file no schema reads."""
        schema = self.registry.for_file(rel)
        if schema is None:
            return None, None
        block = schema.root
        for node in chain[1:]:
            spec = block.find(node.key, self._takes) if node.key else None
            if spec is None or not spec.is_block:
                return schema, None
            block = spec.target
        return schema, block

    def _takes(self, match, key):
        """Whether a pattern's \\p match takes \\p key."""
        if match == "any":
            return True
        if match == "date":
            return bool(_DATE.match(key))
        if match == "integer":
            return bool(_INTEGER.match(key))
        if match == "number":
            return bool(_NUMBER.match(key))
        if match == "modifier name":
            return bool(_IDENTIFIER.match(key))
        if match == "unit type.number":
            found = _UNIT_NUMBER.match(key)
            return bool(found) and self.decl.has("unit type", found.group(1))
        if match.startswith("name:"):
            return self.decl.has(match[5:], key)
        kind = DECLARED.get(match)
        if kind == "province id":
            return key.isdigit()
        if kind is not None:
            return self.decl.has(kind, key)
        return False

    # --- values ------------------------------------------------------------------------

    def _value(self, node, spec):
        kind = spec.value
        where = "`%s`" % node.key
        if spec.is_block or spec.is_list or kind in ("triggers", "effects", "chance",
                                                     "modifiers", "model", "colour"):
            if not node.is_block:
                if node.value is not None:
                    self._report("BV303", node, "`%s` expects a block, not `%s`"
                                 % (node.key, node.value), at_value=True)
                return
            if spec.is_block:
                self._block(node, spec.target, where)
            elif spec.is_list:
                self._list(node, spec.value[5:], where)
            elif kind in ("triggers", "effects", "chance"):
                if self.script is not None:
                    self.out += self.script.check_block(self.path, node, kind)
            elif kind == "modifiers":
                for child in node.children:
                    if child.op is not None and not child.is_block and child.value is not None \
                            and not _NUMBER.match(child.value):
                        self._report("BV303", child, "`%s` expects a number, not `%s`"
                                     % (child.key, child.value), at_value=True)
            elif kind == "model":
                self._model(node)
            elif kind == "colour":
                self._list(node, "number", where)
                count = len([c for c in node.children if c.op is None and c.key is not None])
                if count not in (3, 4):
                    self._report("BV303", node, "`%s` expects three numbers, or four with "
                                 "alpha, not %d" % (node.key, count))
            return
        if node.is_block:
            if kind != "any":
                self._report("BV303", node, "`%s` expects %s, not a block"
                             % (node.key, spec.describe()))
            return
        if node.value is None:
            return      # `key =` with nothing after it is the syntax check's (BV004)
        self._scalar(node, kind, node.value, spec.describe())

    def _scalar(self, node, kind, value, described, at_value=True):
        """Check one value; False if its shape is wrong."""
        ok = True
        if kind in ("any", "text"):
            return True
        if kind.startswith("one of:"):
            allowed = [v.strip().lower() for v in kind[7:].split("|")]
            ok = value.lower() in allowed
        elif kind.startswith("exactly:"):
            ok = value in [v.strip() for v in kind[8:].split("|")]
        elif value == "" and (kind.startswith("name:") or kind in DECLARED):
            return True     # `buttonFont = ""`: no name at all, which the loaders take
        elif kind == "number":
            ok = bool(_NUMBER.match(value))
        elif kind == "integer":
            ok = bool(_INTEGER.match(value))
        elif kind == "yes/no":
            ok = value.lower() in ("yes", "no")
        elif kind == "date":
            ok = bool(_DATE.match(value))
        elif kind == "province":
            ok = value.isdigit()
        if not ok:
            self._report("BV303", node, "`%s` expects %s, not `%s`"
                         % (node.key or value, described, value), at_value=at_value)
            return False
        if kind == "oob file":
            if self.root and not os.path.exists(os.path.join(self.root, "history", "units",
                                                             value)):
                self._report("BV306", node, "No file history/units/%s" % value,
                             at_value=at_value)
            return True
        if kind.startswith("name:"):
            kind_name = kind[5:]
            # A kind no file declares here cannot be checked, rather than every name of it
            # being reported.
            if self.decl.knows(kind_name) and not self.decl.has(kind_name, value):
                self._report("BV306", node, "%s `%s` does not exist"
                             % (_cap(kind_name), value), at_value=at_value)
            return True
        if kind == "building" and value.isdigit():
            return True     # a savegame gives a building by its place in buildings.txt
        declared = DECLARED.get(kind)
        if declared is not None and not self.decl.has(declared, value):
            self._report("BV306", node, "%s `%s` does not exist"
                         % (_cap(declared), value), at_value=at_value)
        return True

    def _list(self, node, kind, where):
        for item in node.children:
            if item.op is None and item.key is not None:
                self._item(item, kind, where)
            elif item.key is not None:
                self._report("BV303", item, "`%s` in %s, which holds a list of %s"
                             % (item.key, where, kind))

    def _item(self, item, kind, where):
        if kind in ("any", "text"):
            return
        self._scalar(item, kind, item.key, describe_value(kind), at_value=False)

    # --- the model of a unit under construction ----------------------------------------

    def _model(self, node):
        items = [c for c in node.children if c.op is None and c.key is not None]
        for item in items:
            if not _INTEGER.match(item.key):
                self._report("BV303", item, "`%s` in a model, which holds technology "
                             "levels" % item.key)
        unit = node.parent.key if node.parent is not None else None
        techs = self.decl.unit_techs.get(unit.lower()) if unit else None
        if techs is None or len(items) == len(techs):
            return
        self._report(
            "BV307", node, "The model has %d levels; `%s` has %d technologies"
            % (len(items), unit, len(techs)),
            hint="A level goes to each of the type's technologies in turn, so a list made "
                 "for an older tech tree gives its levels to other technologies from the "
                 "first one added or removed. %s Hover the list to see which technology "
                 "each number sets now." % ("The last %d levels go to nothing." % (len(items) - len(techs))
                                            if len(items) > len(techs) else
                                            "The last %d technologies get level 0."
                                            % (len(techs) - len(items))))


def _pattern_word(match):
    if match.startswith("name:"):
        return match[5:]
    return {"integer": "number", "unit type.number": "unit type and model number",
            "modifier name": "modifier"}.get(match, match)


def _a(text):
    vowel = text[:1] in "aeiou" and not text.startswith(("uni", "use", "eu"))
    return ("an " if vowel else "a ") + text


def _cap(text):
    return text[:1].upper() + text[1:]
