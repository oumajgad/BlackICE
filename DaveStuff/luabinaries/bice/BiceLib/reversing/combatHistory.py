"""Every finished combat the game is still holding, decoded as far as it is understood.

    python combatHistory.py
    python combatHistory.py --raw          # every field, not just the known ones

Run it after a few battles have resolved. One entry says very little; several entries
side by side is what shows which fields vary with what.
"""

import argparse
import struct

import hoi3

# What is believed to be where, from FINDINGS-combat.md. Anything still a guess is
# named as one, so a wrong reading here cannot quietly become a fact.
FIELDS = [
    (0x04, "meta", "base metadata, the same in every object - ignore"),
    (0x08, "tick", "game tick the combat ended"),
    (0x0c, "unknown0c", "guess: 1 in every entry seen so far"),
    (0x10, "tagA", "country, or --- ; exactly one of the two slots is ever filled"),
    (0x14, "idA", "the id for tagA"),
    (0x18, "tagB", "country, or ---"),
    (0x1c, "idB", "the id for tagB"),
    (0x20, "unknown20", "guess: 0 or 256, does not track the tag slot"),
    (0x24, "province", "the province fought over"),
    (0x28, "previous", "previous entry"),
    (0x2c, "next", "next entry"),
]

ENTRY_LENGTH = 0x30


def tagText(value):
    raw = struct.pack("<I", value)
    text = "".join(chr(b) for b in raw if 32 <= b < 127)
    return text if text else "(none)"


def isInstanceOf(pm, address, className):
    head = hoi3.readBytes(pm, address, 4)
    if head is None:
        return False
    return hoi3.classNameForVftable(pm, struct.unpack_from("<I", head, 0)[0]) == className


def listOf(pm, field, className):
    """
    The objects in one of the game's {first, last, count} lists.

    Two shapes turned up, so which one this is has to be worked out rather than
    assumed: the live combats hang off separate {data, previous, next} nodes, while the
    history holds its entries directly and links them through themselves.
    """
    raw = hoi3.readBytes(pm, field, 12)
    if raw is None:
        return []
    first, last, count = struct.unpack_from("<III", raw, 0)
    if first == 0 or count == 0:
        return []

    if not isInstanceOf(pm, first, className):
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

    if count == 1:
        return [first]

    # Linked through themselves, so one of the object's own fields holds the next.
    # Which one is only discoverable once there are two, so it is found rather than
    # hard coded: the field pointing at another object of the same class.
    body = hoi3.readBytes(pm, first, 0x40)
    linkOffset = None
    if body is not None:
        for offset in range(4, 0x40, 4):
            candidate = struct.unpack_from("<I", body, offset)[0]
            if candidate not in (0, first) and isInstanceOf(pm, candidate, className):
                linkOffset = offset
                break

    if linkOffset is None:
        print("  (%d entries, but no link between them found - showing the first only)"
              % count)
        return [first]

    print("  (entries link through +0x%02x)" % linkOffset)
    out = []
    at = first
    while at and len(out) < count + 3:
        out.append(at)
        nxt = hoi3.readBytes(pm, at + linkOffset, 4)
        if nxt is None:
            break
        at = struct.unpack_from("<I", nxt, 0)[0]
        if not isInstanceOf(pm, at, className):
            break
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", action="store_true", help="dump every field as well")
    args = parser.parse_args()

    pm = hoi3.attach()
    managers = hoi3.instances(pm, "CCombatManager")
    if not managers:
        print("no CCombatManager - is a game loaded?")
        return

    manager = managers[0]
    history = manager + 0x18
    print("manager 0x%08x, history 0x%08x" % (manager, history))

    live = listOf(pm, manager + 0x08, "CLandCombat")
    entries = listOf(pm, history + 0x08, "CCombatHistoryEntry")
    print("%d combats running, %d finished and kept" % (len(live), len(entries)))

    for index, address in enumerate(entries):
        raw = hoi3.readBytes(pm, address, ENTRY_LENGTH)
        if raw is None:
            print("\n[%d] 0x%08x unreadable" % (index, address))
            continue

        print("\n[%d] 0x%08x" % (index, address))
        for offset, name, note in FIELDS:
            value = struct.unpack_from("<I", raw, offset)[0]
            if name.startswith("tag"):
                shown = "'%s'" % tagText(value)
            elif name == "tick":
                shown = "%s (%d)" % (hoi3.tickToDate(value) or "not a tick", value)
            else:
                shown = str(struct.unpack_from("<i", raw, offset)[0])
            print("     +0x%02x  %-10s %-28s %s" % (offset, name, shown, note))

        if args.raw:
            print("     --- everything ---")
            for offset in range(0, ENTRY_LENGTH - 3, 4):
                value = struct.unpack_from("<I", raw, offset)[0]
                print("     +0x%02x  %08x  %11d  '%s'  %s"
                      % (offset, value, struct.unpack_from("<i", raw, offset)[0],
                         tagText(value), hoi3.describe(pm, value)))


if __name__ == "__main__":
    main()
