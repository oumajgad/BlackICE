"""Finds every live object of a class, by the vftable RTTI says it has.

    python findInstances.py CCombatHistory
    python findInstances.py CCombatHistoryEntry --limit 20
    python findInstances.py CLandCombat --dump 0x40

The count on its own already answers questions: one CCombatHistory means it is global,
one per country means it is not, and a CCombatHistoryEntry count that climbs after a
battle means entries are what a report is made of.
"""

import argparse
import struct

import hoi3


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("className")
    parser.add_argument("--limit", type=int, default=40, help="stop listing after this many")
    parser.add_argument("--dump", type=lambda v: int(v, 0), default=0,
                        help="also dump this many bytes of the first few")
    args = parser.parse_args()

    pm = hoi3.attach()
    print("%s loaded at 0x%x" % (hoi3.PROCESS, pm.base_address))

    rva = hoi3.vftableRva(args.className)
    print("%s vftable at module+0x%x" % (args.className, rva))

    found = hoi3.instances(pm, args.className)
    print("%d instances" % len(found))

    for address in found[:args.limit]:
        print("  0x%08x" % address)

    if len(found) > args.limit:
        print("  ... %d more" % (len(found) - args.limit))

    for address in found[:3]:
        if args.dump <= 0:
            break
        print("\n--- 0x%08x ---" % address)
        raw = hoi3.readBytes(pm, address, args.dump)
        if raw is None:
            print("  unreadable")
            continue
        for offset in range(0, len(raw) - 3, 4):
            value = struct.unpack_from("<I", raw, offset)[0]
            print("  +0x%03x  %08x  %10d  %s"
                  % (offset, value, struct.unpack_from("<i", raw, offset)[0],
                     hoi3.describe(pm, value)))


if __name__ == "__main__":
    main()
