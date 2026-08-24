"""Where a province lives in memory right now, and what is on it.

    python province.py 2613            # one province
    python province.py --victory 12    # the twelve highest victory point provinces

Addresses move every time the game is started, so this exists to hand a current one to
a debugger: pick a province, take the address of the field, and let Cheat Engine tell
you what reads it.

The victory point offset was found by comparing every province against the `points`
lines in history/provinces - 825 of them agreed on +0x34 and nothing else did.
"""

import argparse
import sys

import hoi3

GAME_STATE_POINTER = 0x1689790   # the global BiceLib's sessionActive() reads
PROVINCE_ARRAY = 0xB8C           # off the game state

FIELDS = [
    ("victory points", 0x34, "used by the VP mapmode"),
    ("id", 0xD0, ""),
    ("terrain", 0xD4, "a CTerrain pointer"),
    ("modifiers", 0x114, ""),
    ("supply pool", 0x164, ""),
    ("fuel pool", 0x168, ""),
    ("oil", 0x27C, ""),
    ("metal", 0x280, ""),
    ("energy", 0x284, ""),
    ("rares", 0x288, ""),
    ("buildings", 0x310, "a CProvinceBuilding array pointer"),
    ("manpower", 0x320, ""),
    ("leadership", 0x324, ""),
]

MAX_PROVINCE_ID = 20000


def provinceAddress(pm, array, provinceId):
    """0 when there is no such province, or the slot does not hold the one asked for"""
    try:
        address = pm.read_uint(array + provinceId * 4)
        if address == 0 or pm.read_int(address + 0xD0) != provinceId:
            return 0
        return address
    except Exception:
        return 0


def show(pm, address, provinceId):
    print("province %d at 0x%08X" % (provinceId, address))
    for name, offset, note in FIELDS:
        try:
            value = pm.read_int(address + offset)
        except Exception:
            continue
        print("   +%-5s %-16s 0x%08X  %-12s %s"
              % ("0x%X" % offset, name, address + offset, value, note))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("province", nargs="*", type=int)
    parser.add_argument("--victory", type=int, default=0, metavar="N",
                        help="show the N provinces with the most victory points")
    args = parser.parse_args()

    pm = hoi3.attach()
    base = pm.base_address
    state = pm.read_uint(base + GAME_STATE_POINTER)
    if state == 0:
        sys.exit("no session is running - load a save first")
    array = pm.read_uint(state + PROVINCE_ARRAY)
    print("hoi3_tfh.exe at 0x%08X, province array at 0x%08X\n" % (base, array))

    for provinceId in args.province:
        address = provinceAddress(pm, array, provinceId)
        if address == 0:
            print("province %d is not there" % provinceId)
        else:
            show(pm, address, provinceId)
            print()

    if args.victory:
        found = []
        for provinceId in range(1, MAX_PROVINCE_ID):
            address = provinceAddress(pm, array, provinceId)
            if address:
                points = pm.read_int(address + 0x34)
                if points > 0:
                    found.append((points, provinceId, address))
        found.sort(reverse=True)
        print("%d provinces have victory points; the top %d:"
              % (len(found), min(args.victory, len(found))))
        print("   %-7s %-4s %-12s %s" % ("points", "id", "province", "vp field"))
        for points, provinceId, address in found[:args.victory]:
            print("   %-7d %-4d 0x%08X   0x%08X" % (points, provinceId, address, address + 0x34))


if __name__ == "__main__":
    main()
