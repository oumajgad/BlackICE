"""What the game's private memory is made of, by content rather than by class.

    python regionprofile.py              # the whole heap, then the biggest regions
    python regionprofile.py --top 20
    python regionprofile.py --strings 12 # more sample text per region

    python regionprofile.py --save empty.json     # remember what is empty now
    ... play, save the game, whatever is being tested ...
    python regionprofile.py --compare empty.json  # and see what has been written since

census.py counts objects, which only finds what has a vftable - and most memory does
not. This looks at the bytes instead and sorts them into the shapes memory comes in:
zeroes, pointers into the executable, pointers into the heap, text, and the rest.

The sample strings are usually what identifies an owner: a region full of province
names is the map, one full of Lua source is a script, one full of nothing is slack.
"""

import argparse
import ctypes
import json
import os
import re
from ctypes import wintypes

import numpy

import hoi3

MEM_COMMIT = 0x1000
MEM_PRIVATE = 0x20000
PAGE_GUARD = 0x100
PAGE_NOACCESS = 0x01
CHUNK = 4 * 1024 * 1024

TEXT = re.compile(rb"[ -~]{8,}")


class MBI(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p),
                ("AllocationProtect", wintypes.DWORD), ("RegionSize", ctypes.c_size_t),
                ("State", wintypes.DWORD), ("Protect", wintypes.DWORD),
                ("Type", wintypes.DWORD)]


class Shape:
    """how many bytes fell into each kind"""

    def __init__(self):
        self.total = 0
        self.zero = 0
        self.module = 0
        self.heap = 0
        self.text = 0
        self.small = 0

    def add(self, words, raw, moduleLow, moduleHigh):
        self.total += raw.size
        self.zero += int((words == 0).sum()) * 4
        self.module += int(((words >= moduleLow) & (words < moduleHigh)).sum()) * 4
        self.heap += int(((words >= 0x00100000) & (words < 0xFFF00000) &
                          ((words & 3) == 0) & ((words < moduleLow) |
                                                (words >= moduleHigh))).sum()) * 4
        self.small += int(((words > 0) & (words < 0x10000)).sum()) * 4
        printable = ((raw >= 0x20) & (raw < 0x7F)) | (raw == 0x0A) | (raw == 0x0D)
        self.text += int(printable.sum())

    def show(self, label):
        if self.total == 0:
            return
        def share(value):
            return 100.0 * value / self.total
        print("%-22s %8.0f MB   zero %4.1f%%  exe ptr %4.1f%%  heap ptr %4.1f%%  "
              "small int %4.1f%%  printable %4.1f%%" % (
                  label, self.total / 1048576.0, share(self.zero), share(self.module),
                  share(self.heap), share(self.small), share(self.text)))


def regions(handle):
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    info = MBI()
    address = 0
    while address < 0xFFFF0000:
        if kernel32.VirtualQueryEx(handle, ctypes.c_void_p(address), ctypes.byref(info),
                                   ctypes.sizeof(info)) != ctypes.sizeof(info):
            break
        size = info.RegionSize
        if size == 0:
            break
        if (info.State == MEM_COMMIT and info.Type == MEM_PRIVATE
                and not (info.Protect & (PAGE_GUARD | PAGE_NOACCESS))):
            yield address, size, (info.AllocationBase or 0)
        address += size


def compare(handle, profile, path):
    """re-reads the regions recorded earlier and says what has been written since"""
    with open(path) as source:
        recorded = json.load(source)["regions"]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    info = MBI()

    gone = 0
    untouched = 0
    untouchedBytes = 0
    written = 0
    writtenBytes = 0

    print("%-12s %9s %9s %9s   %s" % ("region", "size", "was zero", "now zero", "verdict"))
    for entry in recorded:
        base = entry["base"]
        if kernel32.VirtualQueryEx(handle, ctypes.c_void_p(base), ctypes.byref(info),
                                   ctypes.sizeof(info)) != ctypes.sizeof(info) \
                or info.State != MEM_COMMIT or info.Type != MEM_PRIVATE:
            gone += 1
            print("0x%08x %9.0f MB %8.1f%% %9s   freed or unmapped since"
                  % (base, entry["size"] / 1048576.0, entry["zero"], "-"))
            continue

        shape, _ = profile(base, min(entry["size"], info.RegionSize), 0)
        if shape.total == 0:
            continue
        now = 100.0 * shape.zero / shape.total

        # A region the allocator handed to something else is not the same region, and
        # its address says nothing about whether the old contents were ever used.
        moved = info.AllocationBase and entry["allocationBase"] \
            and info.AllocationBase != entry["allocationBase"]

        if moved:
            verdict = "reallocated - not the same memory"
        elif now >= entry["zero"] - 1.0:
            verdict = "still empty"
            untouched += 1
            untouchedBytes += shape.total
        else:
            verdict = "written: %.0f MB of it" % (
                (entry["zero"] - now) / 100.0 * shape.total / 1048576.0)
            written += 1
            writtenBytes += shape.total

        print("0x%08x %9.0f MB %8.1f%% %8.1f%%   %s"
              % (base, shape.total / 1048576.0, entry["zero"], now, verdict))

    print("\n%d regions still empty (%.0f MB), %d written into (%.0f MB), %d gone"
          % (untouched, untouchedBytes / 1048576.0, written,
             writtenBytes / 1048576.0, gone))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--top", type=int, default=12)
    parser.add_argument("--strings", type=int, default=6)
    parser.add_argument("--save", metavar="FILE",
        help="write the empty regions to a file, to be looked at again later")
    parser.add_argument("--compare", metavar="FILE",
        help="re-read the regions in a file and say what has been written since")
    parser.add_argument("--empty-at", type=float, default=90.0,
        help="how much of a region has to be zero to count as empty (default 90)")
    args = parser.parse_args()

    pm = hoi3.attach()
    moduleLow = pm.base_address
    moduleHigh = moduleLow + 0x1400000

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    handle = kernel32.OpenProcess(0x0010 | 0x0400, False, pm.process_id)
    buffer = ctypes.create_string_buffer(CHUNK)
    read = ctypes.c_size_t(0)

    def profile(base, size, want):
        """(Shape, sample strings) for one region"""
        shape = Shape()
        samples = []
        offset = 0
        while offset < size:
            take = min(CHUNK, size - offset)
            if not kernel32.ReadProcessMemory(handle, ctypes.c_void_p(base + offset),
                                              buffer, take, ctypes.byref(read)) \
                    or read.value < 4:
                break
            block = buffer.raw[:read.value]
            raw = numpy.frombuffer(block, dtype=numpy.uint8)
            words = numpy.frombuffer(block, dtype=numpy.uint32, count=read.value // 4)
            shape.add(words, raw, moduleLow, moduleHigh)

            if want and len(samples) < want:
                for match in TEXT.finditer(block):
                    text = match.group().decode("ascii", "replace")
                    if text not in samples:
                        samples.append(text)
                    if len(samples) >= want:
                        break
            offset += read.value
        return shape, samples

    everything = Shape()
    found = []
    allocationBases = {}
    for base, size, allocationBase in regions(handle):
        found.append((size, base))
        allocationBases[base] = allocationBase

    # Looking again at what was empty before, rather than profiling everything.
    if args.compare:
        compare(handle, profile, args.compare)
        return

    print("profiling %d private regions, %.2f GB\n"
          % (len(found), sum(s for s, _ in found) / 1073741824.0))

    # Each region is also sorted by whatever dominates it, so the total adds up to
    # something nameable rather than to five percentages.
    kinds = {}
    empty = []
    for size, base in found:
        shape, _ = profile(base, size, 0)
        everything.zero += shape.zero
        everything.module += shape.module
        everything.heap += shape.heap
        everything.text += shape.text
        everything.small += shape.small
        everything.total += shape.total

        if shape.total == 0:
            continue
        zero = 100.0 * shape.zero / shape.total
        text = 100.0 * shape.text / shape.total
        module = 100.0 * shape.module / shape.total
        heap = 100.0 * shape.heap / shape.total

        if zero >= 90:
            kind = "never written"
        elif zero >= 60:
            kind = "mostly empty"
        elif text >= 50:
            kind = "text"
        elif module >= 15:
            kind = "objects (vftables)"
        elif heap >= 20:
            kind = "structures (pointers)"
        else:
            kind = "other"

        entry = kinds.setdefault(kind, [0, 0])
        entry[0] += shape.total
        entry[1] += 1

        if args.save and zero >= args.empty_at:
            empty.append({
                "base": base,
                "size": shape.total,
                "allocationBase": allocationBases.get(base, 0),
                "zero": round(zero, 2),
            })

    everything.show("all private memory")

    print()
    for kind, (total, count) in sorted(kinds.items(), key=lambda kv: -kv[1][0]):
        print("    %-24s %8.0f MB in %5d regions" % (kind, total / 1048576.0, count))

    if args.save:
        with open(args.save, "w") as handle_out:
            json.dump({"regions": empty}, handle_out, indent=1)
        print("\nwrote %d empty regions (%.0f MB) to %s"
              % (len(empty), sum(r["size"] for r in empty) / 1048576.0, args.save))

    print("\nthe biggest regions, and what is in them:")
    found.sort(reverse=True)
    for size, base in found[:args.top]:
        shape, samples = profile(base, size, args.strings)
        shape.show("0x%08x" % base)
        for text in samples[:args.strings]:
            print("        %s" % text[:110])


if __name__ == "__main__":
    main()
