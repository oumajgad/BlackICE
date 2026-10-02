"""Which modifier each call to an AddCombatModifier adds, and from where.

    python scripts/combatModifierSites.py              the census, both adders
    python scripts/combatModifierSites.py --by-id      one row per BM_* id instead

**There are two adders, not one**, and scanning only the first is what made
`FINDINGS-combat.md` say "nine ids have no call site at all" and "the modifier list is
land only":

    CUnit::AddCombatModifier     rva 0x1C3040   appends to CUnit    +0xDC   land only
    CSubUnit::AddCombatModifier  rva 0x1AC300   appends to CSubUnit +0x40   naval, air, bombing

Both take `(id, attack, defence)` on the stack with the combatant in ESI, so a call reads

    push <defence>       the first of the three pushed, so furthest from the call
    push <attack>
    push <id>            the last one pushed, nearest the call
    call <the adder>

and the **last push before the call is the modifier's id**. Resolving it against the names
in `ghidra/combatModifierIds.json` turns the sixty-nine call sites into a map of which rule
decides which modifier - one entry per line of a battle tooltip.

**The pushes do not carry the values.** Every site pushes a register, because the compiler
materialises each value into a one-dword stack slot and pushes the slot's address, then
overwrites the slot - see the worked trace in `FINDINGS-combatmods.md`. So this tool reports
the id and the enclosing function and nothing about the numbers; the numbers have to be read
out of the code before the push, and that is what the findings file is for.

**The enclosing function is resolved against a candidate table, not by walking back over
int3 padding.** `image.functionStart` reports `0x565579` for the `BM_TERRAIN` site - an
address four bytes before the call, inside the very function it was asked about - because
these bodies have no padding where it expects it. The table here is every direct `call`
target in `.text` plus every dword elsewhere in the image that points at a `.text` address
immediately after an `int3` or a `ret`, which is what finds a virtual-only function such as
`CCombatant::AddTerrainModifier` (no direct callers at all). Every `ret` between the
candidate and the call is counted and printed, so an abutting-function mistake shows up
rather than passing silently.
"""

import argparse
import bisect
import collections
import io
import json
import os

import image

ADDERS = collections.OrderedDict((
    (0x005C3040, ("CUnit::AddCombatModifier", "CUnit+0xDC")),
    (0x005AC300, ("CSubUnit::AddCombatModifier", "CSubUnit+0x40")),
))

NAMES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "ghidra", "combatModifierIds.json")

# The slot-19 overrides and the two land helpers, so the census says which combatant class
# pushes each id without anybody having to look the address up again.
OWNERS = {
    0x00565530: "CCombatant::AddTerrainModifier (slot 20, shared)",
    0x00569750: "CLandCombatant::AddAssaultModifiers (slot 27, land only)",
    0x00569B50: "CLandCombatant::ApplyCombatModifiers (slot 19)",
    0x00566480: "CNavalCombatant::ApplyCombatModifiers (slot 19)",
    0x0056C6F0: "CAirCombatant::ApplyCombatModifiers (slot 19)",
    0x00561680: "CBomberCombatant::ApplyCombatModifiers (slot 19)",
    0x005627D0: "CTargetCombatant::ApplyCombatModifiers (slot 19, all three)",
}

# How far back to look for the pushes. The three are usually within a dozen instructions,
# but a site that computes its values inline can spread them further; stopping at the
# previous call keeps the window from running into the site before it.
WINDOW = 0xC0

_starts = None


def names():
    if not os.path.exists(NAMES):
        return {}
    return {int(k): v for k, v in json.load(io.open(NAMES, encoding="utf-8")).items()}


def functionStarts():
    """every address in .text that is plausibly the top of a function

    Direct `call` targets, plus dwords elsewhere in the image pointing into `.text` just
    after an `int3`, a `ret` or a `ret imm16` - a vftable slot or a thunk. The predecessor
    test is what keeps a switch's jump table out: its arms point *inside* a function.
    """
    global _starts
    if _starts is not None:
        return _starts
    start, data = image.text()
    end = start + len(data)
    found = set()
    for i in range(len(data) - 5):
        if data[i] != 0xE8:
            continue
        rel = int.from_bytes(data[i + 1:i + 5], "little", signed=True)
        target = start + i + 5 + rel
        if start <= target < end:
            found.add(target)
    for sectionStart, sectionData, name in image.sections():
        if name.startswith(".text"):
            continue
        for offset in range(0, len(sectionData) - 3, 4):
            value = int.from_bytes(sectionData[offset:offset + 4], "little")
            if not start < value < end:
                continue
            at = value - start
            if data[at - 1] in (0xCC, 0xC3) or data[at - 3] == 0xC2:
                found.add(value)
    _starts = sorted(found)
    return _starts


def enclosing(address):
    """(the function the address is in, every `ret` between the two)"""
    table = functionStarts()
    index = bisect.bisect_right(table, address) - 1
    if index < 0:
        return None, []
    candidate = table[index]
    return candidate, image.retsBefore(candidate, address)


def callers(target):
    """every direct `call target`"""
    start, data = image.text()
    found = []
    for i in range(len(data) - 5):
        if data[i] != 0xE8:
            continue
        rel = int.from_bytes(data[i + 1:i + 5], "little", signed=True)
        if start + i + 5 + rel == target:
            found.append(start + i)
    return found


def idAt(call):
    """the value of the last push before `call`, or None if it is not an immediate"""
    for back in range(WINDOW, 8, -4):
        at = call - back
        window = list(image.decode(at, back + 8))
        if not window or not any(i.address == call for i in window):
            continue
        best = None
        for instruction in window:
            if instruction.address >= call:
                break
            if instruction.mnemonic == "call":
                best = None            # a call between resets the argument build-up
            elif instruction.mnemonic == "push":
                operand = instruction.op_str
                best = int(operand, 0) if operand.startswith("0x") or operand.isdigit() \
                    else None
        return best
    return None


def census():
    """[(adder, call, id)] over both adders"""
    rows = []
    for adder in ADDERS:
        for call in callers(adder):
            rows.append((adder, call, idAt(call)))
    return rows


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--by-id", action="store_true",
                        help="one row per BM_* id, saying which adders and classes push it")
    arguments = parser.parse_args()

    known = names()
    rows = census()

    if arguments.by_id:
        where = collections.defaultdict(set)
        for adder, call, identity in rows:
            where[identity].add(ADDERS[adder][1])
        print("%d ids in CombatModifierKey's table\n" % len(known))
        for identity in sorted(known):
            destinations = where.get(identity)
            print("  0x%02X  %-26s %s" % (
                identity, known[identity],
                " and ".join(sorted(destinations)) if destinations
                else "** NO CALL SITE ANYWHERE **"))
        return

    for adder, (name, destination) in ADDERS.items():
        mine = [r for r in rows if r[0] == adder]
        print("\n=== %s  %s  ->  %s   %d call sites"
              % (name, image.both(adder), destination, len(mine)))
        unresolved = 0
        for _, call, identity in sorted(mine, key=lambda r: r[1]):
            function, rets = enclosing(call)
            owner = OWNERS.get(function, "")
            if identity is None:
                unresolved += 1
                label = "(the id is in a register - decided at run time)"
            else:
                label = "0x%02X %s" % (identity, known.get(identity, "(no name for this id)"))
            print("  %s  in %-10s %-28s %s%s"
                  % (image.both(call), hex(function) if function else "?",
                     label, owner, "   ! %d ret(s) in between" % len(rets) if rets else ""))
        if unresolved:
            print("  %d of them push the id from a register, so the rule picks between "
                  "several modifiers; read those by hand." % unresolved)

    missing = sorted(set(known) - {r[2] for r in rows})
    print("\n%d of the %d ids have no call site at all: %s"
          % (len(missing), len(known),
             ", ".join("0x%02X %s" % (m, known[m]) for m in missing) or "none"))


if __name__ == "__main__":
    main()
