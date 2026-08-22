"""Watches the battles that are running right now and reports what changes in them.

    python watchCombat.py                 # every live combat, polled every 5 seconds
    python watchCombat.py --interval 0    # step it by hand instead
    python watchCombat.py --length 0x140

Casualties are not in the history entry a finished combat leaves behind, so they are
almost certainly counted in the combatants while the fighting goes on. A field that
only ever climbs, in both combatants, while a battle is being fought is what a
casualty counter looks like from here.

Finds the combats through CCombatManager rather than by scanning, so it picks up
battles that start after it does, and drops them when they end.
"""

import argparse
import struct
import time

import hoi3


def listOf(pm, field):
    """the game's {first, last, count} list, returned as what the nodes hold"""
    raw = hoi3.readBytes(pm, field, 12)
    if raw is None:
        return []
    first, last, count = struct.unpack_from("<III", raw, 0)

    out = []
    node = first
    while node and len(out) < count + 3:
        block = hoi3.readBytes(pm, node, 12)
        if block is None:
            break
        data, previous, nxt = struct.unpack_from("<III", block, 0)
        out.append(data)
        if nxt == 0:
            break
        node = nxt
    return out


def combatants(pm, combat):
    raw = hoi3.readBytes(pm, combat + 0x10, 8)
    if raw is None:
        return []
    attacker, defender = struct.unpack_from("<II", raw, 0)
    return [("attacker", attacker), ("defender", defender)]


def className(pm, address):
    head = hoi3.readBytes(pm, address, 4)
    if head is None:
        return None
    return hoi3.classNameForVftable(pm, struct.unpack_from("<I", head, 0)[0])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--length", type=lambda v: int(v, 0), default=0xE4)
    parser.add_argument("--interval", type=float, default=5.0,
                        help="seconds between looks; 0 waits for enter instead")
    args = parser.parse_args()

    pm = hoi3.attach()
    managers = hoi3.instances(pm, "CCombatManager")
    if not managers:
        print("no CCombatManager - is a game loaded?")
        return
    manager = managers[0]
    print("manager 0x%08x" % manager)

    previous = {}
    while True:
        combats = listOf(pm, manager + 0x08)
        print("\n=== %d live combats ===" % len(combats))

        current = {}
        for combat in combats:
            for label, side in combatants(pm, combat):
                raw = hoi3.readBytes(pm, side, args.length)
                if raw is not None:
                    current[(combat, label, side)] = raw

        for key, raw in current.items():
            combat, label, side = key
            old = previous.get(key)
            print("\n  %s 0x%08x (%s) of 0x%08x %s"
                  % (label, side, className(pm, side), combat,
                     "" if old else "- first look"))
            if old is None:
                continue

            for offset in range(0, min(len(old), len(raw)) - 3, 4):
                was = struct.unpack_from("<i", old, offset)[0]
                now = struct.unpack_from("<i", raw, offset)[0]
                if was == now:
                    continue

                wasFloat = struct.unpack_from("<f", old, offset)[0]
                nowFloat = struct.unpack_from("<f", raw, offset)[0]
                asFloat = ""
                if 0.0001 < abs(nowFloat) < 100000.0:
                    asFloat = "  float %.4f -> %.4f" % (wasFloat, nowFloat)

                print("    +0x%03x  %11d -> %-11d (%+d)%s"
                      % (offset, was, now, now - was, asFloat))

        # Combats that have ended since the last look: their entry is now in the
        # history, and whatever they last held is the final tally.
        for key in previous:
            if key not in current:
                print("\n  %s 0x%08x of 0x%08x has ended" % (key[1], key[2], key[0]))

        previous = current

        if args.interval > 0:
            time.sleep(args.interval)
        else:
            input("\npress enter to look again... ")


if __name__ == "__main__":
    main()
