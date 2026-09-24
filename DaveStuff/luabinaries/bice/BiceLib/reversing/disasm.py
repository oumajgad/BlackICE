"""Disassemble a stretch of the executable, with anything that looks like a string named.

    python disasm.py 0x005BB146 0x60
    python disasm.py 0x1BB146 0x60 --bytes

Takes a virtual address or an rva and prints both for the range's start, because a
finding written from the wrong one is the mistake this folder makes most.

**Decode from a real instruction boundary.** x86 will happily decode from the middle of
one and produce confident nonsense - this has happened here, printing `fisttp` and
`fadd` out of a plain `mov`. Start from a function, or from an address another tool
printed, and not from a guess.
"""

import argparse

import image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("start", type=image.address)
    parser.add_argument("length", nargs="?", default="0x80", type=lambda v: int(v, 0))
    parser.add_argument("--bytes", action="store_true", help="show the encoding")
    args = parser.parse_args()

    print("from %s" % image.both(args.start))
    for instruction in image.decode(args.start, args.length):
        note = ""
        for operand in instruction.operands:
            text = None
            if operand.type == 2:                       # immediate
                text = image.asString(operand.imm & 0xFFFFFFFF)
            elif operand.type == 3 and operand.mem.base == 0 and operand.mem.index == 0:
                text = image.asString(operand.mem.disp & 0xFFFFFFFF)
            if text:
                note = "   ; %r" % text
        encoding = ""
        if args.bytes:
            encoding = " ".join("%02x" % b for b in instruction.bytes).ljust(26)
        print("0x%08X  %s%-7s %-38s%s"
              % (instruction.address, encoding, instruction.mnemonic,
                 instruction.op_str, note))


if __name__ == "__main__":
    main()
