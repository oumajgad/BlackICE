"""Counts the game's live objects, class by class, across its whole private memory.

    python census.py                # the fifty most numerous classes
    python census.py --top 200
    python census.py --like CUnit   # only classes whose name contains this

Every object of a class starts with that class's vftable, so counting how often each
vftable address appears in memory counts the objects. The RTTI export names 2,645
classes; this scans for all of them in one pass.

Read it as a strong hint rather than a headcount. A vftable value in memory usually
means an object, but freed memory that has not been reused still holds the old value,
and a pointer to a vftable is not always an object at its start.

The region histogram underneath says the other half: whether the memory is a few large
allocations or a great many small ones.
"""

import argparse
import ctypes
from ctypes import wintypes

import numpy

import hoi3

MEM_COMMIT = 0x1000
MEM_PRIVATE = 0x20000
PAGE_GUARD = 0x100
PAGE_NOACCESS = 0x01

CHUNK = 8 * 1024 * 1024


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


def privateRegions(handle):
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    info = MEMORY_BASIC_INFORMATION()

    address = 0
    while address < 0xFFFF0000:
        if kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address),
                                   ctypes.byref(info),
                                   ctypes.sizeof(info)) != ctypes.sizeof(info):
            break
        size = info.RegionSize
        if size == 0:
            break

        readable = (info.State == MEM_COMMIT and info.Type == MEM_PRIVATE
                    and not (info.Protect & (PAGE_GUARD | PAGE_NOACCESS)))
        if readable:
            yield address, size
        address += size


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--top", type=int, default=50)
    parser.add_argument("--like", default="", help="only classes containing this")
    parser.add_argument("--scales-with", type=int, default=0, metavar="N",
        help="list the classes whose count is a whole multiple of N - give it the "
             "number of countries to find everything built per country")
    args = parser.parse_args()

    pm = hoi3.attach()
    base = pm.base_address
    print("hoi3_tfh.exe at 0x%08x" % base)

    # vftable address -> class name, for every class the export knows.
    names = {}
    for name, record in hoi3.classes().items():
        for table in record.get("vftables") or []:
            names[int(table["address"], 16) - 0x400000 + base] = name

    addresses = numpy.array(sorted(names.keys()), dtype=numpy.uint32)
    labels = [names[int(a)] for a in addresses]
    counts = numpy.zeros(len(addresses), dtype=numpy.int64)
    print("looking for %d vftables" % len(addresses))

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    handle = kernel32.OpenProcess(0x0010 | 0x0400, False, pm.process_id)  # VM_READ|QUERY

    buffer = ctypes.create_string_buffer(CHUNK)
    read = ctypes.c_size_t(0)

    scanned = 0
    sizes = []
    for regionBase, regionSize in privateRegions(handle):
        sizes.append(regionSize)
        offset = 0
        while offset < regionSize:
            take = min(CHUNK, regionSize - offset)
            if not kernel32.ReadProcessMemory(handle,
                    ctypes.c_void_p(regionBase + offset), buffer, take,
                    ctypes.byref(read)) or read.value < 4:
                break

            words = numpy.frombuffer(buffer.raw, dtype=numpy.uint32,
                                     count=read.value // 4)
            scanned += read.value

            # Where each word would sit in the sorted vftable list, which is a hit
            # when the value there is the word itself.
            where = numpy.searchsorted(addresses, words)
            where[where >= len(addresses)] = 0
            hits = where[addresses[where] == words]
            if hits.size:
                counts += numpy.bincount(hits, minlength=len(addresses))

            offset += read.value

    print("scanned %.2f GB of private memory in %d regions\n"
          % (scanned / 1073741824.0, len(sizes)))

    order = numpy.argsort(-counts)
    shown = 0
    print("%-42s %12s" % ("class", "objects"))
    for index in order:
        if counts[index] == 0 or shown >= args.top:
            break
        if args.like and args.like.lower() not in labels[index].lower():
            continue
        print("%-42s %12d" % (labels[index], counts[index]))
        shown += 1

    total = int(counts.sum())
    print("\n%d objects of %d classes found" % (total, int((counts > 0).sum())))

    if args.scales_with:
        # A count that divides evenly is a class the game builds a fixed number of per
        # thing - per country, most usefully, since that says what removing one would
        # save. The historical models were found exactly this way: 5,323,320 turned out
        # to be 108 tags x 1,643 unit types x 30 levels.
        print("\nclasses whose count is a whole multiple of %d:" % args.scales_with)
        print("%-42s %12s %12s" % ("class", "objects", "each"))
        for index in numpy.argsort(-counts):
            value = int(counts[index])
            if value < args.scales_with:
                break
            share = value / float(args.scales_with)
            if abs(share - round(share)) < 0.005:
                print("%-42s %12d %12d" % (labels[index], value, round(share)))

    print("\nprivate regions by size:")
    sizes.sort(reverse=True)
    buckets = [(1 << 24, "16 MB+"), (1 << 22, "4 MB+"), (1 << 20, "1 MB+"),
               (1 << 16, "64 KB+"), (0, "under 64 KB")]
    for limit, label in buckets:
        chosen = [s for s in sizes if s >= limit]
        sizes = [s for s in sizes if s < limit]
        if chosen:
            print("    %-12s %6d regions, %8.0f MB"
                  % (label, len(chosen), sum(chosen) / 1048576.0))


if __name__ == "__main__":
    main()
