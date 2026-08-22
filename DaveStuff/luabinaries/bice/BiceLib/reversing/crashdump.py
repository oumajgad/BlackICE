"""Reads a Windows minidump without a debugger.

    python crashdump.py                     # the newest hoi3 dump
    python crashdump.py path\\to\\file.dmp    # a particular one
    python crashdump.py --all 5             # the newest five, one summary each

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
        out.append((base, size, os.path.basename(readString(data, nameRva))))
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
        stackStart, stackSize, stackRva = struct.unpack_from("<QII", data, at + 16)
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
        _, rva = found[STREAM_VM_COUNTERS]
        # PROCESS_VM_COUNTERS: Revision, PeakVirtualSize, VirtualSize, PageFaultCount,
        # PeakWorkingSetSize, WorkingSetSize, ... PagefileUsage, PeakPagefileUsage
        values = struct.unpack_from("<I10I", data, rva)
        print("    private bytes %.2f GB, peak %.2f GB" %
              (values[9] / 1073741824.0, values[10] / 1073741824.0))

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

    stackStart, stackSize, stackRva, contextSize, contextRva = stack
    if contextSize > CONTEXT_ESP:
        eip, esp = struct.unpack_from("<I", data, contextRva + CONTEXT_EIP)[0], \
                   struct.unpack_from("<I", data, contextRva + CONTEXT_ESP)[0]
        print("    thread %d, eip 0x%08x, esp 0x%08x" % (threadId, eip, esp))

    # Every stack word that lands inside a module, in order, deduplicated by module.
    # The dump can hold less of the stack than it claims, so trust the file.
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
