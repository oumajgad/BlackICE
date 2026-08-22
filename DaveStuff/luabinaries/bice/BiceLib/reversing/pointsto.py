"""Finds who is holding a pointer into a stretch of memory, and so who owns it.

    python pointsto.py 0xb9560000 0x1000000
    python pointsto.py 0xb9560000 0x1000000 --limit 40

Scans everything committed for a word that lands inside the range, then says where
that word is: inside a module (and which), or in the heap. A block nobody points at is
either reached by arithmetic from somewhere else or genuinely abandoned.
"""

import argparse
import ctypes
from ctypes import wintypes

import numpy

import hoi3

MEM_COMMIT = 0x1000
PAGE_GUARD = 0x100
PAGE_NOACCESS = 0x01
CHUNK = 8 * 1024 * 1024


class MBI(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p),
                ("AllocationProtect", wintypes.DWORD), ("RegionSize", ctypes.c_size_t),
                ("State", wintypes.DWORD), ("Protect", wintypes.DWORD),
                ("Type", wintypes.DWORD)]


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", help="start of the range, e.g. 0xb9560000")
    parser.add_argument("size", nargs="?", default="0x1000",
        help="how long it is (default one page)")
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--modules-only", action="store_true",
        help="only pointers held inside a loaded module, which name their owner")
    args = parser.parse_args()

    low = int(args.base, 16)
    high = low + int(args.size, 16)

    pm = hoi3.attach()
    modules = []
    for module in pm.list_modules():
        modules.append((module.lpBaseOfDll, module.lpBaseOfDll + module.SizeOfImage,
                        module.name))
    modules.sort()

    def owner(address):
        for start, end, name in modules:
            if start <= address < end:
                return "%s+0x%x" % (name, address - start)
        return None

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    handle = kernel32.OpenProcess(0x0010 | 0x0400, False, pm.process_id)
    buffer = ctypes.create_string_buffer(CHUNK)
    read = ctypes.c_size_t(0)
    info = MBI()

    print("looking for pointers into 0x%08x - 0x%08x\n" % (low, high))

    hits = 0
    address = 0
    while address < 0xFFFF0000 and hits < args.limit:
        if kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address), ctypes.byref(info),
                                   ctypes.sizeof(info)) != ctypes.sizeof(info):
            break
        size = info.RegionSize
        if size == 0:
            break

        readable = (info.State == MEM_COMMIT
                    and not (info.Protect & (PAGE_GUARD | PAGE_NOACCESS)))

        # The range itself is skipped: a pool pointing into itself says nothing.
        if readable and not (low <= address < high):
            offset = 0
            while offset < size and hits < args.limit:
                take = min(CHUNK, size - offset)
                if not kernel32.ReadProcessMemory(handle,
                        ctypes.c_void_p(address + offset), buffer, take,
                        ctypes.byref(read)) or read.value < 4:
                    break

                words = numpy.frombuffer(buffer.raw, dtype=numpy.uint32,
                                         count=read.value // 4)
                found = numpy.flatnonzero((words >= low) & (words < high))
                for index in found:
                    if hits >= args.limit:
                        break
                    at = address + offset + int(index) * 4
                    where = owner(at)
                    if args.modules_only and where is None:
                        continue
                    print("    0x%08x -> 0x%08x   %s" % (
                        at, int(words[index]),
                        where if where else "heap or stack"))
                    hits += 1
                offset += read.value
        address += size

    if hits == 0:
        print("    nothing points into it")


if __name__ == "__main__":
    main()
