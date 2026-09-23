"""Where a virtual table slot is called from.

    python slotcalls.py 32          every call through slot 32
    python slotcalls.py 32 --touches 0xBAC 0x1E4

**MSVC usually calls a virtual in two instructions**, `mov reg, [vftable + slot*4]` and
`call reg` a few later, not as one `call [reg + n]`. A scan that only looks for the
single instruction form finds nothing at all - which is what happened looking for
`CUnit`'s slot 32 and reported zero call sites for a function the game runs every day.

**Expect this to be unselective.** A slot number is a displacement like any other, and
`+0x80` is 150 sites across 119 functions, nearly all of them other classes' slot 32.
`--touches` narrows by what else the containing function does: give it offsets only the
class you care about would use, and the survivors are worth reading.
"""

import argparse

import capstone

import image


def callSites(displacement):
    """address -> the containing function, for calls through this slot"""
    engine = image.engine()
    start, data = image.text()
    sites = {}

    for offset in range(len(data) - 6):
        if data[offset] not in (0x8B, 0xFF):
            continue
        decoded = list(engine.disasm(data[offset:offset + 8], start + offset, count=1))
        if not decoded:
            continue
        instruction = decoded[0]
        operands = instruction.operands

        if instruction.mnemonic == "call" and image.usesMemory(instruction, displacement):
            sites[instruction.address] = image.functionStart(instruction.address)
            continue

        if (instruction.mnemonic != "mov" or len(operands) != 2
                or operands[0].type != capstone.x86.X86_OP_REG
                or not image.usesMemory(instruction, displacement)):
            continue
        register = operands[0].reg
        for following in image.decode(instruction.address + instruction.size, 0x20):
            if (following.mnemonic == "call" and following.operands
                    and following.operands[0].type == capstone.x86.X86_OP_REG
                    and following.operands[0].reg == register):
                sites[instruction.address] = image.functionStart(instruction.address)
                break
            if following.mnemonic in ("call", "jmp", "ret"):
                break
    return sites


def touches(function, offsets, span=0x1200):
    """which of these offsets the function uses at all"""
    found = set()
    for instruction in image.decode(function, span):
        for offset in offsets:
            if image.usesMemory(instruction, offset):
                found.add(offset)
        if instruction.mnemonic == "ret":
            break
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("slot", type=lambda v: int(v, 0))
    parser.add_argument("--touches", nargs="*", type=lambda v: int(v, 0), default=[],
                        help="keep only callers that also use these offsets")
    args = parser.parse_args()

    displacement = args.slot * 4
    sites = callSites(displacement)
    owners = {}
    for at, owner in sites.items():
        owners.setdefault(owner, []).append(at)

    print("slot %d (+0x%X): %d sites in %d functions"
          % (args.slot, displacement, len(sites), len(owners)))

    for owner in sorted(o for o in owners if o is not None):
        if args.touches:
            used = touches(owner, args.touches)
            if not used:
                continue
            print("   %s  uses %s   calls at %s"
                  % (image.both(owner), ", ".join("0x%X" % u for u in sorted(used)),
                     ", ".join("0x%08X" % a for a in owners[owner][:3])))
        else:
            print("   %s  calls at %s"
                  % (image.both(owner),
                     ", ".join("0x%08X" % a for a in owners[owner][:3])))


if __name__ == "__main__":
    main()
