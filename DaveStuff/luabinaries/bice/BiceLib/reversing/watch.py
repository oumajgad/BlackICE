"""Snapshots memory, waits for you to make something happen in game, then says what
changed.

    python watch.py CCombatHistory --length 0x80
    python watch.py 0x1a2b3c40 --length 0x200
    python watch.py CCombatHistoryEntry --instances     # watch the count, not the bytes

This is the one that actually finds a counter. Take a snapshot, fight a battle, press
enter: whatever counts combats will have gone up by one, and almost nothing else will
have moved. Repeat with a different kind of battle and the land, air and naval fields
separate themselves.

Nothing here writes to the game.
"""

import argparse
import struct
import time

import hoi3


def snapshot(pm, addresses, length):
    return {address: hoi3.readBytes(pm, address, length) for address in addresses}


def report(pm, before, after, length):
    changed = 0
    for address in sorted(before):
        old = before[address]
        new = after.get(address)
        if old is None or new is None or old == new:
            continue

        header = False
        for offset in range(0, min(len(old), len(new)) - 3, 4):
            was = struct.unpack_from("<I", old, offset)[0]
            now = struct.unpack_from("<I", new, offset)[0]
            if was == now:
                continue

            if not header:
                print("\n0x%08x" % address)
                header = True
            changed += 1

            wasSigned = struct.unpack_from("<i", old, offset)[0]
            nowSigned = struct.unpack_from("<i", new, offset)[0]
            delta = nowSigned - wasSigned
            print("  +0x%03x  %08x -> %08x   %d -> %d  (%+d)   %s"
                  % (offset, was, now, wasSigned, nowSigned, delta,
                     hoi3.describe(pm, now)))

    if changed == 0:
        print("\nnothing changed")
    else:
        print("\n%d fields changed" % changed)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="an address, or a class name to watch every instance of")
    parser.add_argument("--length", type=lambda v: int(v, 0), default=0x80)
    parser.add_argument("--instances", action="store_true",
                        help="watch how many instances exist rather than their contents")
    parser.add_argument("--interval", type=float, default=0.0,
                        help="poll every N seconds instead of waiting for enter")
    args = parser.parse_args()

    pm = hoi3.attach()

    className = None
    try:
        addresses = [int(args.target, 0)]
    except ValueError:
        className = args.target
        addresses = hoi3.instances(pm, className)
        print("%s: %d instances" % (className, len(addresses)))

    if not addresses and not className:
        print("nothing to watch")
        return

    if args.instances:
        if className is None:
            print("--instances needs a class name, not an address")
            return
        count = len(addresses)
        while True:
            wait(args.interval)
            now = hoi3.instances(pm, className)
            print("%s: %d instances (%+d)" % (className, len(now), len(now) - count))
            count = len(now)
        return

    before = snapshot(pm, addresses, args.length)
    print("snapshot of %d objects, %d bytes each" % (len(addresses), args.length))

    while True:
        wait(args.interval)
        after = snapshot(pm, addresses, args.length)
        report(pm, before, after, args.length)
        before = after


def wait(interval):
    if interval > 0:
        time.sleep(interval)
    else:
        input("\ndo the thing in game, then press enter... ")


if __name__ == "__main__":
    main()
