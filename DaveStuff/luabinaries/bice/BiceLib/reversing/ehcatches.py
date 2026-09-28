r"""What a function catches, out of its MSVC C++ exception tables.

    python ehcatches.py 0x0057B4D0
    python ehcatches.py 0x00431370 --callers 3

**A cleanup frame is not a catch.** Every function with a local that needs destroying gets
an SEH frame, so "it has an SEH frame" says nothing about whether an exception stops there.
The try block map does: a function that catches has one or more entries, each listing the
types it accepts, and `...` shows as a null type.

The chain is the one MSVC emits on x86: the prologue pushes a per-function thunk,
`mov eax, <FuncInfo>; jmp __CxxFrameHandler3`, and FuncInfo holds the try block map.

    FuncInfo      magic, maxState, unwindMap, nTryBlocks, tryBlockMap, ...
    TryBlockMap   tryLow, tryHigh, catchHigh, nCatches, handlerArray
    HandlerType   adjectives, typeDescriptor, dispCatchObj, handler
"""

import argparse

import image

MAGICS = (0x19930520, 0x19930521, 0x19930522)


def u32(address):
    raw = image.read(address, 4)
    return int.from_bytes(bytes(raw), "little") if raw else None


def typeName(descriptor):
    """The mangled name a TypeDescriptor carries, at +8."""
    if not descriptor:
        return "..."
    text = image.asString(descriptor + 8)
    return text or "<unreadable>"


def funcInfoOf(start):
    """The FuncInfo a function's EH prologue points at, or None."""
    for instruction in image.decode(start, 0x40):
        if instruction.mnemonic != "push":
            continue
        operand = instruction.operands[0]
        if operand.type != 2:
            continue
        thunk = operand.imm & 0xFFFFFFFF
        if thunk < 0x401000:
            continue
        # a handler thunk is exactly `mov eax, imm32` then `jmp`
        try:
            body = list(image.decode(thunk, 12))
        except Exception:
            continue
        if (len(body) >= 2 and body[0].mnemonic == "mov"
                and body[0].op_str.startswith("eax, ")
                and body[1].mnemonic == "jmp"):
            candidate = body[0].operands[1].imm & 0xFFFFFFFF
            if u32(candidate) in MAGICS:
                return candidate
    return None


def catches(start):
    """Every try block of the function at \\p start, as (nCatches, [type names])."""
    info = funcInfoOf(start)
    if info is None:
        return None
    count = u32(info + 12)
    table = u32(info + 16)
    out = []
    if not count or not table:
        return out
    for i in range(min(count, 64)):
        entry = table + i * 20
        nCatches = u32(entry + 12)
        handlers = u32(entry + 16)
        names = []
        for j in range(min(nCatches or 0, 16)):
            handler = handlers + j * 16
            names.append(typeName(u32(handler + 4)))
        out.append(names)
    return out


def sehFrame(start):
    """
    @brief the scope table of a `__try` frame, or None

    MSVC's x86 `__try` prologue pushes the scope table and then the handler, so the shape
    to look for is two `push imm32` in a row where the second is `_except_handler3` or
    `_except_handler4` - the same address in every function that uses one.
    """
    pushes = []
    for instruction in image.decode(start, 0x30):
        if instruction.mnemonic == "push" and instruction.operands[0].type == 2:
            pushes.append(instruction.operands[0].imm & 0xFFFFFFFF)
        elif instruction.mnemonic == "mov" and "fs:" in instruction.op_str:
            break
    # scope table then handler; the handler is code, the table is data
    for i in range(len(pushes) - 1):
        table, handler = pushes[i], pushes[i + 1]
        if handler < 0x401000 or table < 0x401000:
            continue
        body = list(image.decode(handler, 8))
        if body and body[0].mnemonic in ("mov", "push", "jmp", "sub"):
            # a C++ thunk is `mov eax, <FuncInfo>; jmp` - anything else here is the SEH
            # handler proper, shared by every __try in the image
            if not (body[0].mnemonic == "mov" and body[0].op_str.startswith("eax, ")
                    and len(body) > 1 and body[1].mnemonic == "jmp"):
                return table, handler
    return None


def sehExcepts(start):
    """How many `__except` (filtered) entries a `__try` frame's scope table holds."""
    frame = sehFrame(start)
    if frame is None:
        return None
    table, _ = frame
    filtered = 0
    for i in range(16):
        previous = u32(table + i * 12)
        filterFn = u32(table + i * 12 + 4)
        if previous is None or filterFn is None:
            break
        # the table ends when the entries stop looking like one
        if previous not in (0xFFFFFFFF,) and not (0 <= previous < 16):
            break
        if filterFn and 0x401000 <= filterFn < 0xD00000:
            filtered += 1
    return filtered


def report(start, label=""):
    found = catches(start)
    where = "%#010x (rva %#08x)" % (start, start - 0x400000)
    if found is None:
        excepts = sehExcepts(start)
        if excepts:
            print("   %s %-22s **__try/__except**, %d filtered entr%s"
                  % (where, label, excepts, "y" if excepts == 1 else "ies"))
            return True
        print("   %s %-22s no C++ EH frame at all" % (where, label))
        return False
    if not found:
        excepts = sehExcepts(start)
        if excepts:
            print("   %s %-22s cleanup only, but **__try/__except** with %d filtered"
                  % (where, label, excepts))
            return True
        print("   %s %-22s EH frame, but cleanup only - no try block" % (where, label))
        return False
    print("   %s %-22s **CATCHES**" % (where, label))
    for i, names in enumerate(found):
        print("        try %d: %s" % (i, ", ".join(names) or "(none)"))
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("start", type=image.address)
    args = parser.parse_args()
    print("from %s" % image.both(args.start))
    report(args.start, "the function")


if __name__ == "__main__":
    main()
