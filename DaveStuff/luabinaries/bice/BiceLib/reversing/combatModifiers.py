"""Every combat modifier the executable knows, by id, read out of its own jump table.

    python combatModifiers.py                 print them
    python combatModifiers.py --write         write ghidra/combatModifierIds.json

A combat modifier is the id at the start of each node of the list at `CUnit + 0xDC` - the
list the battle tooltip walks to print `Combined Arms: +22.50%` and the rest. Nothing in
the image holds a table of the names: they exist only as the string literal each arm of
`CombatModifierKey` (rva `0x164060`) builds.

**Read the jump table, not the decompilation.** The arms are a `jmp [eax*4 + 0x16429C]`
over ids 0 to `cmp eax, 0x1d`, and taking the names out of a decompiled switch instead is
how this was first got wrong twice over: a transcription lost `BM_NIGHT_MODIFIER` to the
wrong id and put `BM_SURPRISE_BONUS` at 0x1E, one past the end. The bound is the `cmp`'s
and the order is the table's, and neither is a judgement call.

`BM_HQ_NEARBY` is in the mod's localisation but not in this table, so it is a key the
engine never asks for - the same shape as the four unused defines in FINDINGS-supply.md.
"""

import argparse
import io
import json
import os
import re

import image

KEY_FUNCTION = 0x00564060   # CombatModifierKey
TABLE = 0x0056429C          # its jump table
LIMIT = 0x1D                # from `cmp eax, 0x1d`, so ids 0..0x1D inclusive

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ghidra", "combatModifierIds.json")


def bound():
    """the highest id the function accepts, read off its own compare"""
    for instruction in image.decode(KEY_FUNCTION, 0x30):
        if instruction.mnemonic == "cmp" and instruction.op_str.startswith("eax, "):
            return int(instruction.op_str.split(", ")[1], 16)
    return LIMIT


def modifiers():
    """{id: name} for every arm of the table"""
    found = {}
    highest = bound()
    for identity in range(highest + 1):
        target = int.from_bytes(image.read(TABLE + identity * 4, 4), "little")
        for instruction in image.decode(target, 0x20):
            # each arm is `mov edx, <literal>` and then the string is built from it
            if instruction.mnemonic == "mov" and instruction.op_str.startswith("edx, 0x"):
                text = image.asString(int(instruction.op_str.split(", ")[1], 16), limit=48)
                if text and re.match(r"^BM_[A-Z0-9_]+$", text):
                    found[identity] = text
                break
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true",
        help="write ghidra/combatModifierIds.json, which buildFindings turns into an enum")
    arguments = parser.parse_args()

    found = modifiers()
    highest = bound()
    print("%d combat modifiers, ids 0..%#x" % (len(found), highest))
    missing = [i for i in range(highest + 1) if i not in found]
    if missing:
        print("! no name for %d of them: %s" % (len(missing), [hex(m) for m in missing]))

    for identity in sorted(found):
        print("   0x%02X  %s" % (identity, found[identity]))

    if arguments.write:
        io.open(OUT, "w", encoding="utf-8", newline="\n").write(
            json.dumps({str(k): v for k, v in sorted(found.items())},
                       indent=1, ensure_ascii=True))
        print("")
        print("wrote %s" % OUT)


if __name__ == "__main__":
    main()
