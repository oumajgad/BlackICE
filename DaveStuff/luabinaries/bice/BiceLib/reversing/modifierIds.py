"""Every modifier the executable knows, by id, read out of its global initialiser.

    python modifierIds.py                 print them
    python modifierIds.py --write         write ghidra/modifierIds.json

A modifier is a number everywhere in the game - `CModifier +0x24`, the index into a
country's or a province's modifier values, the thing `CBuildingDataBase`'s loader
compares against to decide which building is the naval base. Nothing in the image holds
a table of the names: they exist only as the string literal each one is constructed with.

So this reads the construction. The initialiser builds every modifier in a row, and each
one looks like:

    push 0x13                    the literal's length
    push 0x15bb708               'MINIMUM_REVOLT_RISK'
    call std::string::assign
    push 0x208                   the save token it loads and saves under
    push esi                     the CModifier being built
    xor edx, edx                 **the id**, in edx
    call CModifier::CModifier

The id is `xor edx,edx` for zero and `mov edx, imm` otherwise. Taking the last string
pushed before the call is what pairs the two.

**One trap worth naming.** `lea edi, [ebx + 0xF]` appears just before the first of these
and is *not* an id - it is the Hoi3CString's `_Myres`, which starts at 15 for the
small-string buffer. Reading it as a modifier id gives MODIFIER_IC's number to the first
modifier in the file.

**An id is not an array index, past 101.** This table maps the id at `CModifier +0x24`,
which is what every comparison in the game tests - `CBuildingDataBase`'s role ladder, and
anything else that asks "which modifier is this". A country's `CModifierValues` is a
*different* mapping: the initialiser fills it in construction order while stamping ids
that stop matching that order at entry 102, and it registers id 104 twice. Below 102 the
two agree, which is why most readings never notice.

So: a comparison against `CModifier +0x24` reads from here; an index into the values
array reads from here only while it is under 102, and from `CModifierValues` above that.
"""

import argparse
import io
import json
import os
import re

import capstone

import image

CONSTRUCTOR = 0x456D50          # CModifier::CModifier, the id in edx
ASSIGN = 0x40A160               # std::string::assign
FIRST = 0x456E10                # the initialiser's first modifier
LAST = 0x459340                 # just past its last

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ghidra", "modifierIds.json")


def modifiers():
    """{id: name} for every modifier the initialiser builds"""
    found = {}
    engine = image.engine()

    # Disassemble across the whole initialiser, resuming after anything that will not
    # decode. capstone stops at the first bad byte, and this range has alignment padding
    # in it - taking the first run alone reached modifier 24 of 108 and looked complete.
    instructions = []
    at = FIRST
    while at < LAST:
        window = list(engine.disasm(image.read(at, LAST - at), at))
        if not window:
            at += 1
            continue
        instructions.extend(window)
        at = window[-1].address + window[-1].size

    literal = None              # the last string pushed
    identity = None             # the last value put in edx
    constants = {}              # registers holding a constant, for `mov edx, <reg>`

    for instruction in instructions:
        text = "%s %s" % (instruction.mnemonic, instruction.op_str)

        # **Two shapes, and the same instruction serves both.** The first modifiers build
        # their name with `push <length>; push <literal>; call std::string::assign`; the
        # rest use the register convention, `mov edx, <literal>; call
        # std::string::fromCString`. So `mov edx, imm` is sometimes the name and
        # sometimes the id, and what tells them apart is whether the immediate resolves
        # to one. Taking `mov edx, imm` as the id unconditionally stops at modifier 24 of
        # 108 and looks like a complete answer.
        def asName(value):
            text = image.asString(value, limit=64)
            return text if text and re.match(r"^[A-Z][A-Z0-9_]+$", text) else None

        if instruction.mnemonic == "push" and instruction.op_str.startswith("0x"):
            name = asName(int(instruction.op_str, 16))
            if name:
                literal = name

        # Read the operands, not the text: `mov edx, 1` prints without a `0x`, and
        # matching on the string missed every id below 10.
        # Keep track of registers holding a constant. MODIFIER_IC takes its id as
        # `mov edx, edi`, where edi was set to 0xF by a `lea edi, [ebx + 0xF]` at the top
        # of the function and reused ever since - as the Hoi3CString's _Myres *and* as
        # this one modifier's id. Without this, id 15 is the single gap in 107.
        if instruction.mnemonic == "xor" and len(instruction.operands) == 2:
            a, b = instruction.operands
            if a.type == capstone.CS_OP_REG and b.type == capstone.CS_OP_REG \
                    and a.reg == b.reg:
                constants[instruction.reg_name(a.reg)] = 0
        elif instruction.mnemonic == "lea" and len(instruction.operands) == 2:
            destination, source = instruction.operands
            base = source.mem.base and instruction.reg_name(source.mem.base)
            if source.mem.index == 0 and constants.get(base) == 0:
                constants[instruction.reg_name(destination.reg)] = source.mem.disp

        if text == "xor edx, edx":
            identity = 0
        elif instruction.mnemonic == "mov" and len(instruction.operands) == 2:
            destination, source = instruction.operands
            isEdx = (destination.type == capstone.CS_OP_REG
                     and instruction.reg_name(destination.reg) == "edx")
            if source.type == capstone.CS_OP_IMM:
                name = asName(source.imm)
                if name and isEdx:
                    literal = name
                elif isEdx:
                    identity = source.imm
                if destination.type == capstone.CS_OP_REG and not name:
                    constants[instruction.reg_name(destination.reg)] = source.imm
            elif isEdx and source.type == capstone.CS_OP_REG:
                held = constants.get(instruction.reg_name(source.reg))
                if held is not None:
                    identity = held

        if instruction.mnemonic == "call" and instruction.op_str.startswith("0x"):
            target = int(instruction.op_str, 16)
            if target == CONSTRUCTOR and literal is not None and identity is not None:
                found[identity] = literal
                literal = None
                identity = None

    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true",
        help="write ghidra/modifierIds.json, which buildFindings turns into an enum")
    arguments = parser.parse_args()

    found = modifiers()
    print("%d modifiers, ids %d..%d" % (len(found), min(found), max(found)))
    missing = [i for i in range(max(found) + 1) if i not in found]
    if missing:
        print("no name for %d of them: %s" % (len(missing), missing))

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
