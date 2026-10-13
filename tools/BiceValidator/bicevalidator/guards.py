"""Which provinces' controllers a condition makes sure of, and where an order of battle puts
its units - for BV217, a `load_oob` that places units where nothing checks who holds the
province.

`load_oob` puts each unit in the province its file names, whoever holds it - in enemy land,
where it starts in battle or cut off (the maintainer's account; the fact base has read how
a loaded unit enters the map, reversing/findings/FINDINGS-oob.md, not what follows in a
province somebody else holds). So the mod guards a load with conditions on the provinces'
controllers, and loads a fallback file where they fail.

A **guard** is a condition that holds only if a province's controller is as tested:
`controls = <id>`, or `<id> = { controller = { ... } }` / `<id> = { controlled_by = ... }`.
Conditions sit side by side as an AND, so their guards add up; under `or` only a province
every branch guards is guarded; under `not` nothing is - `not = { controls = 1690 }` says
the opposite. One `or` is read as a switch: `or = { not = { has_country_flag = F }
controls = <id> }` guards the province where F is set, which a load whose `limit` asks
for F is - how a decision says "in production mode, only while this province is held". A country scope - a tag, `this`, `from`, `owner`, `controller` - is looked
into, since a guard in it still tests a province; a set like `any_neighbor_country` is not,
since it is about some other country.
"""

import re

from . import parser

# Scopes looked into for guards: a country, by tag or by one of these words.
_COUNTRY_WORDS = {"this", "from", "owner", "controller", "and"}
_TAG = re.compile(r"^[A-Za-z]{3}$")
_CONTROLLER_TESTS = {"controller", "controlled_by"}
# The blocks of an order of battle that are units on the map, and their province keys.
UNIT_KEYS = {"theatre", "armygroup", "army", "corps", "division", "navy", "air"}
PLACE_KEYS = ("location", "base")


def guards_of(block):
    """The province ids \\p block's conditions guard, as an AND of its children."""
    out = set()
    for child in (block.children or ()) if block is not None else ():
        out |= _one(child)
    return frozenset(out)


def _one(node):
    low = node.lkey
    if low is None:
        return set()
    if low == "controls":
        return {node.value} if (node.value or "").isdigit() else set()
    if not node.is_block or low == "not":
        return set()
    if low == "or":
        return _either(node)
    if low.isdigit():
        return {low} if _tests_controller(node) else set()
    if low in _COUNTRY_WORDS or _TAG.match(low):
        return set(guards_of(node))
    return set()


def _either(node):
    """The guards of an `or`: what every branch guards. A branch that is only
    `not = { has_country_flag = F }` is a switch - "unless F is set" - so what the other
    branches guard is guarded **where F is set**: the item becomes (province, {F, ...}),
    which counts at a place that sets F itself (resolve)."""
    switches, branches = set(), []
    for child in node.children:
        if child.key is None:
            continue
        flag = _switch_flag(child)
        if flag is not None:
            switches.add(flag)
        else:
            branches.append(_one(child))
    if not branches:
        return set()
    common = set.intersection(*branches)
    if not switches:
        return common
    out = set()
    for item in common:
        province, needs = (item, frozenset()) if isinstance(item, str) else item
        out.add((province, needs | frozenset(switches)))
    return out


def _switch_flag(node):
    """F, if \\p node is `not = { has_country_flag = F }` and nothing else."""
    if node.lkey != "not" or not node.is_block:
        return None
    inner = [c for c in node.children if c.key is not None]
    if len(inner) == 1 and inner[0].lkey == "has_country_flag" and inner[0].value:
        return inner[0].value
    return None


def path_flags(node):
    """The country flags the `limit`s around \\p node require to be set - plainly, not
    under an `or` or a `not`."""
    out = set()
    parent = node.parent
    while parent is not None and parent.key is not None:
        for child in parent.children:
            if child.lkey == "limit" and child.is_block and child is not node:
                out |= _set_flags(child)
        parent = parent.parent
    return frozenset(out)


def _set_flags(block):
    out = set()
    for child in block.children:
        if child.lkey == "has_country_flag" and child.value:
            out.add(child.value)
        elif child.lkey == "and" and child.is_block:
            out |= _set_flags(child)
    return out


def resolve(guards, flags):
    """The provinces \\p guards guard where the country flags \\p flags are set: each plain
    province, and each (province, flags needed) whose flags are all among them."""
    out = set()
    for item in guards:
        if isinstance(item, str):
            out.add(item)
        elif item[1] <= flags:
            out.add(item[0])
    return out


def _tests_controller(province):
    for child in province.children:
        if child.lkey in _CONTROLLER_TESTS:
            return True
        if child.lkey == "and" and child.is_block and _tests_controller(child):
            return True
    return False


def path_guards(node):
    """The guards of every `limit` around \\p node: of each block it sits in, out to the
    event or decision - the conditions that hold wherever it runs."""
    out = set()
    parent = node.parent
    while parent is not None and parent.key is not None:
        for child in parent.children:
            if child.lkey == "limit" and child.is_block and child is not node:
                out |= guards_of(child)
        parent = parent.parent
    return frozenset(out)


def unit_places(root):
    """(province id, line) of every province an order of battle puts a unit in or bases one
    at, first place first, each once. Units in `unit_deployment` wait in the pool and are
    put nowhere."""
    seen = {}
    for node in parser.walk(root):
        if node.lkey not in PLACE_KEYS or not (node.value or "").isdigit():
            continue
        unit = node.parent
        if unit is None or unit.lkey not in UNIT_KEYS or _in_deployment(unit):
            continue
        seen.setdefault(node.value, node.line)
    return list(seen.items())


def _in_deployment(node):
    while node is not None:
        if node.lkey == "unit_deployment":
            return True
        node = node.parent
    return False
