"""Dumps an object field by field, with every reading of each four bytes side by side.

    python dumpStruct.py 0x1a2b3c40 --length 0x80
    python dumpStruct.py CCombatHistory            # dumps the first instance found

A field is only ever four bytes of nothing in particular until something makes one
reading of it obviously right - a pointer that lands on a known vftable, a float in a
plausible range, a small integer that counts something. Showing all of them at once is
what makes that jump out.
"""

import argparse
import struct

import hoi3


def dump(pm, address, length, stringify):
    raw = hoi3.readBytes(pm, address, length)
    if raw is None:
        print("cannot read 0x%x" % address)
        return

    print("  offset    hex        int          note")
    for offset in range(0, len(raw) - 3, 4):
        value = struct.unpack_from("<I", raw, offset)[0]
        signed = struct.unpack_from("<i", raw, offset)[0]

        note = hoi3.describe(pm, value)

        # A std::string is sixteen bytes and its length, so any offset can be the
        # start of one; worth testing when asked, noisy when not.
        if stringify:
            text = hoi3.readString(pm, address + offset)
            if text and text.isprintable():
                note = ('string "%s"' % text) + ((", " + note) if note else "")

        print("  +0x%03x    %08x   %11d  %s" % (offset, value, signed, note))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="an address, or a class name to take the first instance of")
    parser.add_argument("--length", type=lambda v: int(v, 0), default=0x60)
    parser.add_argument("--strings", action="store_true",
                        help="test every offset for a std::string as well")
    args = parser.parse_args()

    pm = hoi3.attach()

    try:
        address = int(args.target, 0)
    except ValueError:
        found = hoi3.instances(pm, args.target, limit=1)
        if not found:
            print("no live instance of %s" % args.target)
            return
        address = found[0]
        print("%s at 0x%08x" % (args.target, address))

    dump(pm, address, args.length, args.strings)


if __name__ == "__main__":
    main()
