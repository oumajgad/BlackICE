"""Finds the code that touches a thing, by reading the executable rather than the
running game.

    python findRefs.py --vftable CCombatHistoryEntry
    python findRefs.py --address 0x015b68c0
    python findRefs.py --callers 0x0042f410

A constructor is the only code that writes a class's vftable into an object, so
searching the code for that address finds the constructors - and the caller of a
constructor is whatever decided the object should exist. For CCombatHistoryEntry that
caller is the game finishing a combat, which is the function worth hooking.

Addresses are as the executable sees them, based at 0x400000, the same as the RTTI
export. Nothing here needs the game to be running.
"""

import argparse

import capstone
import pefile

import hoi3

EXE = r"C:\Users\David\Hearts of Iron 3\hoi3_tfh.exe"


def textSection(pe):
    for section in pe.sections:
        if section.Name.startswith(b".text"):
            return section
    raise RuntimeError("no .text section")


def disassembleAround(code, base, offset, value, before=64, after=24):
    """
    Decodes so the instruction stream lines up with the bytes we care about.

    The value is an operand inside an instruction, not the start of one, so lining up
    means finding a decode where some instruction *contains* the offset and carries
    that value as an immediate. Anything else is the stream being read from the wrong
    place, which x86 will happily do and which produces confident nonsense.
    """
    engine = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    engine.detail = True

    for back in range(before, 3, -1):
        start = offset - back
        if start < 0:
            continue

        window = list(engine.disasm(code[start:offset + after], base + start))
        for index, instruction in enumerate(window):
            covers = instruction.address <= base + offset < instruction.address + instruction.size
            if not covers:
                continue
            carries = any(operand.type == capstone.x86.X86_OP_IMM and
                          (operand.imm & 0xFFFFFFFF) == value
                          for operand in instruction.operands)
            if carries:
                return window, index
            break
    return [], -1


def findFunctionStart(code, offset, limit=0x800):
    """
    Walks back to the top of the function an offset sits in.

    MSVC pads between functions with int3, so a run of them followed by something that
    looks like a prologue is a function boundary. Not infallible - a jump table or an
    inlined block can look the same - which is why the address it returns is worth
    checking against the disassembly before hooking anything at it.
    """
    at = offset
    while at > 0 and offset - at < limit:
        at -= 1
        if code[at] != 0xCC:
            continue

        # skip back over the whole run of padding, then take what follows
        end = at
        while end > 0 and code[end - 1] == 0xCC:
            end -= 1
        candidate = at + 1

        if code[candidate] in (0x55, 0x53, 0x56, 0x57, 0x8B, 0x83, 0x81, 0x6A, 0x68):
            return candidate
    return None


def findValue(pe, code, base, value):
    """every place in the code holding this exact four byte value"""
    needle = value.to_bytes(4, "little")
    out = []
    at = code.find(needle)
    while at != -1:
        out.append(at)
        at = code.find(needle, at + 1)
    return out


def findCallers(code, base, target):
    """direct calls to an address: e8 with a relative displacement landing on it"""
    out = []
    for offset in range(len(code) - 5):
        if code[offset] != 0xE8:
            continue
        displacement = int.from_bytes(code[offset + 1:offset + 5], "little", signed=True)
        if base + offset + 5 + displacement == target:
            out.append(offset)
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vftable", help="class name; finds where its vftable is written")
    parser.add_argument("--address", type=lambda v: int(v, 0), help="any value to search for")
    parser.add_argument("--callers", type=lambda v: int(v, 0), help="function address to find calls to")
    parser.add_argument("--context", type=int, default=6, help="instructions of context to show")
    args = parser.parse_args()

    pe = pefile.PE(EXE, fast_load=True)
    section = textSection(pe)
    code = section.get_data()
    base = pe.OPTIONAL_HEADER.ImageBase + section.VirtualAddress
    print("%s .text at 0x%08x, %d bytes" % (EXE.split("\\")[-1], base, len(code)))

    if args.callers is not None:
        sites = findCallers(code, base, args.callers)
        print("\n%d direct calls to 0x%08x" % (len(sites), args.callers))
        for offset in sites:
            print("   from 0x%08x" % (base + offset))
        return

    value = args.address
    if args.vftable:
        value = hoi3.vftableRva(args.vftable) + 0x400000
        print("%s vftable at 0x%08x" % (args.vftable, value))

    if value is None:
        parser.error("give --vftable, --address or --callers")

    sites = findValue(pe, code, base, value)
    print("\n%d references in code" % len(sites))

    for offset in sites:
        window, index = disassembleAround(code, base, offset, value)
        print("\n--- referenced at 0x%08x ---" % (base + offset))
        if index < 0:
            print("   (could not line up the instruction stream)")
            continue

        low = max(0, index - args.context)
        for i in range(low, min(len(window), index + 2)):
            instruction = window[i]
            marker = ">>" if instruction.address <= base + offset < instruction.address + instruction.size else "  "
            print("   %s 0x%08x  %-8s %s"
                  % (marker, instruction.address, instruction.mnemonic, instruction.op_str))

        start = findFunctionStart(code, offset)
        if start is None:
            print("   function start: not found within range")
        else:
            print("   function starts at 0x%08x   ->  python findRefs.py --callers 0x%08x"
                  % (base + start, base + start))


if __name__ == "__main__":
    main()
