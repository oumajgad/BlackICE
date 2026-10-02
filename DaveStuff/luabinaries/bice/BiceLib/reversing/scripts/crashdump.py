"""Reads a Windows minidump without a debugger.

    python scripts/crashdump.py                     # the newest hoi3 dump
    python scripts/crashdump.py path\\to\\file.dmp    # a particular one
    python scripts/crashdump.py --all 5             # the newest five, one summary each

Says what the exception was, where it happened, which module owns that address, how
much memory the process had taken, and which modules appear on the faulting thread's
stack. That last one is a scan for anything that looks like a return address rather
than a real stack walk - there are no symbols here - so read it as "this code was
involved", not as a call order.

The dumps are written by Windows Error Reporting to %LOCALAPPDATA%\\CrashDumps.
"""

import argparse
import glob
import os
import struct

DUMPS = os.path.join(os.environ.get("LOCALAPPDATA", ""), "CrashDumps",
                     "hoi3_tfh.exe.*.dmp")

STREAM_THREAD_LIST = 3
STREAM_MODULE_LIST = 4
STREAM_EXCEPTION = 6
STREAM_MISC_INFO = 15
STREAM_VM_COUNTERS = 22

# x86 CONTEXT, as the memory note records it.
CONTEXT_EIP = 184
CONTEXT_ESP = 196
CONTEXT_EBP = 180
CONTEXT_EAX = 176

# MINIDUMP_EXCEPTION_STREAM: ULONG32 ThreadId, ULONG32 alignment, then the
# EXCEPTION_RECORD, then its own MINIDUMP_LOCATION_DESCRIPTOR ThreadContext.
EXCEPTION_CONTEXT_SIZE = 160
EXCEPTION_CONTEXT_RVA = 164


def low(address):
    """
    An address as the 32 bits it really is.

    The process is LargeAddressAware and runs on 64-bit Windows, so it has the whole 4 GB
    and anything allocated late sits above 0x80000000. WER writes those ULONG64 fields
    **sign extended** - a stack based at 0x92EB2174 is stored as 0xFFFFFFFF92EB2174 - so
    every comparison against a 32-bit register misses unless the high half is dropped.
    """
    return address & 0xFFFFFFFF

EXCEPTIONS = {
    0xC0000005: "access violation",
    0xC0000006: "in page error",
    0xC000001D: "illegal instruction",
    0xC0000025: "noncontinuable exception",
    0xC0000094: "integer divide by zero",
    0xC00000FD: "stack overflow",
    0xC0000374: "heap corruption",
    0x80000003: "breakpoint",
    0xE06D7363: "C++ exception",
}


def streams(data):
    """stream type -> (size, rva)"""
    if data[:4] != b"MDMP":
        raise RuntimeError("not a minidump")
    count, directory = struct.unpack_from("<II", data, 8)

    found = {}
    for i in range(count):
        kind, size, rva = struct.unpack_from("<III", data, directory + i * 12)
        found[kind] = (size, rva)
    return found


def readString(data, rva):
    length = struct.unpack_from("<I", data, rva)[0]
    return data[rva + 4:rva + 4 + length].decode("utf-16-le", "replace")


def modules(data, found):
    if STREAM_MODULE_LIST not in found:
        return []

    _, rva = found[STREAM_MODULE_LIST]
    count = struct.unpack_from("<I", data, rva)[0]

    out = []
    for i in range(count):
        at = rva + 4 + i * 108
        base, size, _, _, nameRva = struct.unpack_from("<QIIII", data, at)
        out.append((low(base), size, os.path.basename(readString(data, nameRva))))
    out.sort()
    return out


def moduleAt(loaded, address):
    for base, size, name in loaded:
        if base <= address < base + size:
            return name, address - base
    return None, 0


def threads(data, found):
    if STREAM_THREAD_LIST not in found:
        return {}

    _, rva = found[STREAM_THREAD_LIST]
    count = struct.unpack_from("<I", data, rva)[0]

    out = {}
    for i in range(count):
        at = rva + 4 + i * 48
        threadId = struct.unpack_from("<I", data, at)[0]
        # +16 is the Teb. The stack descriptor is at +24 - ULONG64 StartOfMemoryRange,
        # then DataSize and Rva - and the context at +40. Reading the stack from +16 takes
        # the Teb as the base and the base's two halves as size and rva.
        stackStart, stackSize, stackRva = struct.unpack_from("<QII", data, at + 24)
        contextSize, contextRva = struct.unpack_from("<II", data, at + 40)
        out[threadId] = (stackStart, stackSize, stackRva, contextSize, contextRva)
    return out


def describe(path):
    with open(path, "rb") as handle:
        data = handle.read()

    found = streams(data)
    loaded = modules(data, found)

    print("=== %s  (%.1f MB)" % (os.path.basename(path), len(data) / 1048576.0))

    if STREAM_VM_COUNTERS in found:
        size, rva = found[STREAM_VM_COUNTERS]
        # MINIDUMP_PROCESS_VM_COUNTERS_2: USHORT Revision, USHORT Flags,
        # ULONG PageFaultCount, then **ULONG64** for the rest - peak working set, working
        # set, four pool quotas, pagefile, peak pagefile, private, private working set,
        # shared commit. Reading these as 32-bit takes the high half of each and prints
        # zeros, which is what this did.
        revision = struct.unpack_from("<H", data, rva)[0]
        if revision >= 2 and size >= 80:
            def counter(index):
                return struct.unpack_from("<Q", data, rva + 8 + index * 8)[0]
            private = counter(8) if size >= 8 + 9 * 8 else counter(6)
            print("    private %.2f GB, peak pagefile %.2f GB, peak working set %.2f GB"
                  % (private / 1073741824.0, counter(7) / 1073741824.0,
                     counter(0) / 1073741824.0))
            # A 32-bit process has 4 GB at the very most, and less once images, stacks and
            # reserved-but-uncommitted ranges are out - so this close to it, an allocation
            # failing somewhere is the likeliest thing that went wrong.
            if private > 3 * 1073741824:
                print("    ** within a gigabyte of the 32-bit ceiling: suspect an"
                      " allocation failure **")
        else:
            print("    VM counters stream revision %d, %d bytes - not read" %
                  (revision, size))

    if STREAM_EXCEPTION not in found:
        print("    no exception stream - not a crash dump?")
        return

    _, rva = found[STREAM_EXCEPTION]
    threadId = struct.unpack_from("<I", data, rva)[0]
    code, flags = struct.unpack_from("<II", data, rva + 8)
    address = struct.unpack_from("<Q", data, rva + 24)[0]
    parameters = struct.unpack_from("<I", data, rva + 32)[0]
    info = struct.unpack_from("<2Q", data, rva + 40)

    name, offset = moduleAt(loaded, address)
    print("    %s (0x%08x) at 0x%08x  %s" % (
        EXCEPTIONS.get(code, "unknown"), code, address,
        ("in %s+0x%x" % (name, offset)) if name else "in no loaded module"))

    if code == 0xC0000005 and parameters >= 2:
        kind = {0: "reading", 1: "writing", 8: "executing"}.get(info[0], "accessing")
        print("    %s 0x%08x" % (kind, info[1]))

    stack = threads(data, found).get(threadId)
    if stack is None:
        print("    the faulting thread is not in the thread list")
        return

    stackStart, stackSize, stackRva, _listSize, _listRva = stack

    # **The exception stream's own context, not the thread list's.** The thread list holds
    # the thread as it was when the dump was written - parked in ntdll while WER worked -
    # and this holds it as it faulted.
    contextSize = struct.unpack_from("<I", data, rva + EXCEPTION_CONTEXT_SIZE)[0]
    contextRva = struct.unpack_from("<I", data, rva + EXCEPTION_CONTEXT_RVA)[0]
    if contextSize > CONTEXT_ESP:
        def reg(offset):
            return struct.unpack_from("<I", data, contextRva + offset)[0]
        eip, esp, ebp, eax = (reg(CONTEXT_EIP), reg(CONTEXT_ESP), reg(CONTEXT_EBP),
                              reg(CONTEXT_EAX))
        name, offset = moduleAt(loaded, eip)
        print("    thread %d, eip 0x%08x%s, esp 0x%08x, ebp 0x%08x, eax 0x%08x"
              % (threadId, eip, (" in %s+0x%x" % (name, offset)) if name else "",
                 esp, ebp, eax))
        # An address that is text rather than code is worth saying out loud: it means a
        # pointer was read out of something that holds a string, and the four bytes name
        # the string.
        if name is None:
            letters = struct.pack("<I", eip)
            if all(32 <= b < 127 for b in letters):
                print("    that address is the text %r - a pointer read out of string data"
                      % letters.decode("latin-1"))

    # Every stack word that lands inside a module, in order, deduplicated by module.
    # The dump can hold less of the stack than it claims, so trust the file.
    print("    stack 0x%08x, %d bytes of it in the dump" % (low(stackStart), stackSize))
    available = min(stackSize, len(data) - stackRva)

    seen = []
    counts = {}
    for at in range(0, max(0, available - 4), 4):
        value = struct.unpack_from("<I", data, stackRva + at)[0]
        name, offset = moduleAt(loaded, value)
        if name is None:
            continue
        counts[name] = counts.get(name, 0) + 1
        if not seen or seen[-1][0] != name:
            seen.append((name, offset))

    print("    stack touches: %s" % ", ".join(
        "%s x%d" % (n, c) for n, c in sorted(counts.items(), key=lambda kv: -kv[1])))
    print("    first frames:  %s" % " <- ".join(
        "%s+0x%x" % (n, o) for n, o in seen[:8]))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dump", nargs="?", help="a dump file; default is the newest")
    parser.add_argument("--all", type=int, default=0, metavar="N",
        help="summarise the newest N instead")
    args = parser.parse_args()

    if args.dump:
        describe(args.dump)
        return

    files = sorted(glob.glob(DUMPS), key=os.path.getmtime, reverse=True)
    if not files:
        print("no dumps in %s" % DUMPS)
        return

    for path in files[:max(1, args.all)]:
        describe(path)
        print()


if __name__ == "__main__":
    main()
