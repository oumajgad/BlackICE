"""Who reads a field, found through the pointer that leads to it rather than by its
offset alone.

    python fieldchain.py --holder 0xDA8 --index 50 --stride 8
        every `mov reg, [x + 0xDA8]` followed by a read of entry 50 off that same reg -
        which is how `peacetime_manpower_rotation` was shown to have exactly one reader
        in the whole executable

    python fieldchain.py --holder 0xFC+0x18 --index 7 --stride 8
        the same for a province's own modifier, which is where attrition comes from

    python fieldchain.py --field 0xA9C            one level: every use of [reg + 0xA9C]
    python fieldchain.py --field 0xA9C --writes   only the stores

**A displacement on its own means almost nothing.** `+0x38` is one of the commonest
field and stack offsets in the image; scanning for it returns pages of unrelated hits,
which is exactly what happened when attrition was looked for that way. What makes a hit
evidence is the *chain*: the register was loaded from a known pointer a few instructions
earlier and has not been reloaded since. So prefer `--holder` whenever the field hangs
off something identifiable, and treat bare `--field` results as candidates.

Two things the single level scan used to miss, both of which cost time:

- **an immediate store does not end with the displacement.** `mov byte [esi+0xACC], 1`
  has the 1 after it, so a scan that insists the displacement is the last four bytes of
  the instruction finds every `mov [esi+0xACC], bl` and no `mov [esi+0xACC], 1`. This
  one accepts both.
- **the window has to stop at a call**, or the register is assumed to survive something
  that may well have clobbered it.
"""

import argparse

import capstone

import image

WINDOW = 0x40


# Below this x86 encodes a displacement in one byte, so searching .text for the four-byte
# value finds nothing real. At and above it the encoding is disp32 and the byte search is
# both correct and far quicker than a sweep.
DISP8_LIMIT = 0x80

_swept = None


def sweep():
    """every instruction in .text, decoded once and kept

    Only for displacements under DISP8_LIMIT, where there is nothing in the bytes to
    search for. It costs a pass over 9.6 MB, which is why it is not the default.
    """
    global _swept
    if _swept is not None:
        return _swept
    engine = image.engine()
    start, data = image.text()
    _swept = []
    at = start
    end = start + len(data)
    while at < end:
        window = list(engine.disasm(image.read(at, min(0x1000, end - at)), at))
        if not window:
            at += 1                     # data, or a byte that will not decode
            continue
        _swept.extend(window)
        at = window[-1].address + window[-1].size
    return _swept


def sites(displacement):
    """(address, isInstructionStart) worth examining for a use of [reg + displacement]

    **The two kinds of hit are not the same address**, and treating them alike is a bug
    this has already had: a swept hit *is* the instruction, while a byte-search hit is the
    displacement inside one, two or more bytes in. Searching back from a swept hit decodes
    from the middle of the instruction before it; decoding a search hit at zero offset
    decodes the displacement itself as though it were an opcode. Either way the scan gives
    up on the site and the answer comes back a confident zero.
    """
    if displacement >= DISP8_LIMIT:
        return [(at, False) for at in image.findValue(displacement)]
    return [(i.address, True) for i in sweep() if image.usesMemory(i, displacement)]


def window(starts):
    """how far back the instruction using a hit can begin"""
    return (0,) if starts else range(2, 12)


def offsetOf(text):
    """'0xFC+0x18' as 0x114, because that is how a nested field reads"""
    return sum(int(part, 0) for part in text.split("+"))


def chained(holder, displacement, window):
    """reads of [reg + displacement] where reg came from [something + holder]"""
    engine = image.engine()
    hits = {}
    for at, starts in sites(holder):
        for back in window(starts):
            window_bytes = image.read(at - back, back + 8)
            decoded = list(engine.disasm(window_bytes, at - back, count=1))
            if not decoded:
                continue
            load = decoded[0]
            if load.size != back + 4 or load.mnemonic != "mov":
                break
            operands = load.operands
            if len(operands) != 2 or operands[0].type != capstone.x86.X86_OP_REG:
                break
            if not image.usesMemory(load, holder):
                break
            register = operands[0].reg
            for following in image.decode(at - back + load.size, window):
                if image.usesMemory(following, displacement, base=register):
                    hits[following.address] = following
                if following.mnemonic in ("call", "ret", "jmp"):
                    break   # the register may not survive
            break
    return hits


def direct(displacement, writesOnly):
    """every instruction using [reg + displacement], immediate stores included"""
    engine = image.engine()
    hits = {}
    for at, starts in sites(displacement):
        for back in window(starts):
            decoded = list(engine.disasm(image.read(at - back, back + 10),
                                         at - back, count=1))
            if not decoded:
                continue
            instruction = decoded[0]
            # the displacement has to be inside this instruction, but need not end it:
            # an immediate store carries its value after it
            if instruction.address + instruction.size <= at + 3 and not starts:
                continue
            if not image.usesMemory(instruction, displacement):
                break
            if writesOnly and (not instruction.operands
                               or instruction.operands[0].type != capstone.x86.X86_OP_MEM):
                break
            hits[instruction.address] = instruction
            break
    return hits


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--holder", type=offsetOf,
                        help="offset of the pointer the field hangs off, e.g. 0xDA8")
    parser.add_argument("--field", type=offsetOf, help="the field's own offset")
    parser.add_argument("--index", type=lambda v: int(v, 0),
                        help="an array element instead of --field")
    parser.add_argument("--stride", type=lambda v: int(v, 0), default=8)
    parser.add_argument("--writes", action="store_true", help="stores only")
    parser.add_argument("--window", type=lambda v: int(v, 0), default=WINDOW)
    args = parser.parse_args()

    displacement = args.field
    if args.index is not None:
        displacement = args.index * args.stride
    if displacement is None:
        parser.error("give --field or --index")

    if args.holder is not None:
        hits = chained(args.holder, displacement, args.window)
        print("[[x + 0x%X] + 0x%X]: %d reader%s"
              % (args.holder, displacement, len(hits), "" if len(hits) == 1 else "s"))
    else:
        hits = direct(displacement, args.writes)
        print("[reg + 0x%X]%s: %d site%s - candidates, not evidence"
              % (displacement, " written" if args.writes else "",
                 len(hits), "" if len(hits) == 1 else "s"))

    for at in sorted(hits):
        instruction = hits[at]
        owner = image.functionStart(at)
        print("   %s  %-7s %-32s in %s"
              % (image.both(at), instruction.mnemonic, instruction.op_str,
                 image.both(owner) if owner else "?"))


if __name__ == "__main__":
    main()
