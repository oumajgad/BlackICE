"""Which modifier each call to CUnit::AddCombatModifier adds, and from where.

    python combatModifierSites.py

`CUnit::AddCombatModifier` (rva `0x1C3040`) takes `(id, attack, defend)` on the stack with
the unit in ESI, so a call reads

    push <defend>
    push <attack>
    push <id>            the last one pushed, nearest the call
    call CUnit::AddCombatModifier

and the **last push before the call is the modifier's id**. Resolving it against the names
in `ghidra/combatModifierIds.json` turns the twenty-odd call sites into a map of which rule
decides which modifier - one entry per line of a battle tooltip.

An id pushed from a register cannot be read here and is reported as such rather than
guessed; those are the sites where the rule chooses between several modifiers at run time,
which is worth knowing on its own.
"""

import io
import json
import os

import image

ADD = 0x005C3040
NAMES = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "ghidra", "combatModifierIds.json")

# How far back to look for the pushes. The three are usually within a dozen instructions,
# but a site that computes its values inline can spread them further; stopping at the
# previous call keeps the window from running into the site before it.
WINDOW = 0x60


def names():
    if not os.path.exists(NAMES):
        return {}
    return {int(k): v for k, v in json.load(io.open(NAMES, encoding="utf-8")).items()}


def callers():
    """every direct `call ADD`"""
    start, data = image.text()
    found = []
    for i in range(len(data) - 5):
        if data[i] != 0xE8:
            continue
        rel = int.from_bytes(data[i + 1:i + 5], "little", signed=True)
        if start + i + 5 + rel == ADD:
            found.append(start + i)
    return found


def idAt(call):
    """the value of the last push before `call`, or None if it is not an immediate"""
    best = None
    for at in range(call - WINDOW, call):
        window = list(image.decode(at, (call - at) + 8))
        if not window or not any(i.address == call for i in window):
            continue
        # a clean decode that reaches the call: take the last push before it
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


def main():
    known = names()
    rows = []
    for call in callers():
        identity = idAt(call)
        rows.append((call, identity, known.get(identity)))

    print("%d calls to CUnit::AddCombatModifier\n" % len(rows))
    unresolved = 0
    for call, identity, name in sorted(rows):
        where = image.functionStart(call)
        if identity is None:
            unresolved += 1
            label = "(the id is in a register - decided at run time)"
        else:
            label = "%#04x  %s" % (identity, name or "(no name for this id)")
        print("  %s  in %-12s  %s" % (image.both(call),
                                      hex(where) if where else "?", label))

    if unresolved:
        print("\n%d of them push the id from a register, so the rule picks between "
              "several modifiers; read those by hand." % unresolved)


if __name__ == "__main__":
    main()
