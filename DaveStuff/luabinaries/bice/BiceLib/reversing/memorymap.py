"""What the running game has done with its 4 GB of address space.

    python memorymap.py                 # the whole picture
    python memorymap.py --regions 20    # and the twenty biggest regions

The same walk the overlay's Memory page does, from outside, so it works while the
overlay is closed and after a crash has been survived. Nothing is written.
"""

import argparse
import ctypes
from ctypes import wintypes

import hoi3

MEM_COMMIT = 0x1000
MEM_RESERVE = 0x2000
MEM_FREE = 0x10000

TYPE_NAMES = {0x1000000: "image", 0x40000: "mapped", 0x20000: "private"}

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010


class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BaseAddress", ctypes.c_void_p),
        ("AllocationBase", ctypes.c_void_p),
        ("AllocationProtect", wintypes.DWORD),
        ("RegionSize", ctypes.c_size_t),
        ("State", wintypes.DWORD),
        ("Protect", wintypes.DWORD),
        ("Type", wintypes.DWORD),
    ]


class PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("PageFaultCount", wintypes.DWORD),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
        ("PrivateUsage", ctypes.c_size_t),
    ]


def megabytes(value):
    return value / 1048576.0


def show(value):
    if value >= 1073741824:
        return "%.2f GB" % (value / 1073741824.0)
    return "%.0f MB" % megabytes(value)


def walk(handle):
    """every region, as (base, size, state, type)"""
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    info = MEMORY_BASIC_INFORMATION()

    address = 0
    limit = 0xFFFF0000
    while address < limit:
        if kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address),
                                   ctypes.byref(info),
                                   ctypes.sizeof(info)) != ctypes.sizeof(info):
            break
        size = info.RegionSize
        if size == 0:
            break
        yield address, size, info.State, info.Type
        address += size


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--regions", type=int, default=0,
        help="also list the N biggest regions")
    args = parser.parse_args()

    pm = hoi3.attach()
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
                                  False, pm.process_id)
    if not handle:
        print("could not open the process")
        return

    counters = PROCESS_MEMORY_COUNTERS_EX()
    counters.cb = ctypes.sizeof(counters)
    psapi = ctypes.WinDLL("psapi")
    psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb)

    used = {"image": [0, 0, 0], "mapped": [0, 0, 0], "private": [0, 0, 0]}
    free = []
    regions = []
    largestPrivate = 0

    for base, size, state, kind in walk(handle):
        if state == MEM_FREE:
            free.append(size)
            continue

        name = TYPE_NAMES.get(kind)
        if name is None:
            continue

        group = used[name]
        group[2] += 1
        if state == MEM_COMMIT:
            group[0] += size
            if name == "private" and size > largestPrivate:
                largestPrivate = size
        else:
            group[1] += size

        regions.append((size, base, name, state))

    committed = sum(g[0] for g in used.values())
    reserved = sum(g[1] for g in used.values())
    free.sort(reverse=True)

    print("Private bytes (commit charge): %s" % show(counters.PrivateUsage))
    print("Working set:                   %s" % show(counters.WorkingSetSize))
    print("Peak pagefile usage:           %s" % show(counters.PeakPagefileUsage))
    print()
    print("Address space in use:          %s committed + %s reserved = %s of 4 GB"
          % (show(committed), show(reserved), show(committed + reserved)))
    print()
    print("%-10s %12s %12s %9s" % ("", "committed", "reserved", "regions"))
    for name in ("private", "mapped", "image"):
        group = used[name]
        print("%-10s %12s %12s %9d" % (name, show(group[0]), show(group[1]), group[2]))
    print()

    print("Largest free block:            %s" % show(free[0] if free else 0))
    print("Largest single private block:  %s" % show(largestPrivate))
    print("Free blocks: %d, of which %d over 64 MB and %d over 256 MB"
          % (len(free),
             sum(1 for size in free if size > 64 * 1048576),
             sum(1 for size in free if size > 256 * 1048576)))
    print("Ten biggest free blocks: %s"
          % ", ".join(show(size) for size in free[:10]))

    if args.regions:
        print()
        print("Biggest regions:")
        regions.sort(reverse=True)
        for size, base, name, state in regions[:args.regions]:
            print("    0x%08x  %9s  %-8s %s" % (
                base, show(size), name,
                "committed" if state == MEM_COMMIT else "reserved"))


if __name__ == "__main__":
    main()
