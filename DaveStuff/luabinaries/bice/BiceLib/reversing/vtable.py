"""Prints classes' vtables side by side, from the executable.

    python vtable.py CLandCombat CAirCombat CNavalCombat
    python vtable.py CCombatant CLandCombatant CAirCombatant CNavalCombatant

Slots that hold the same function in every class listed are what the base does for all
of them; slots that differ are where a subclass has its own behaviour. For siblings
like the three kinds of combat that is a map of what actually differs between them -
which is worth knowing before assuming a field read off one is in the same place on
another.

The first class given is the reference. A slot is marked "=" where a class matches it
and shows its own address where it does not.

Addresses are as the executable sees them, based at 0x400000, the same as the RTTI
export. Nothing here needs the game to be running.
"""

import argparse
import struct

import pefile

import hoi3

EXE = r"C:\Users\David\Hearts of Iron 3\hoi3_tfh.exe"

IMAGE_BASE = 0x400000


def readVtable(pe, data, rva, slots):
    """the function addresses in a vtable, read out of the image"""
    offset = pe.get_offset_from_rva(rva)
    raw = data[offset:offset + slots * 4]
    return list(struct.unpack("<%dI" % slots, raw))


def functionNames(pe, data):
    """address -> the class and slot that introduced it, for anything recognisable"""
    named = {}
    for name, record in hoi3.classes().items():
        for introduced in record.get("introduces") or []:
            named.setdefault(int(introduced["address"], 16), []).append(
                "%s slot %d" % (name, introduced["slot"]))
    return named


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("classes", nargs="+", help="the classes to compare")
    parser.add_argument("--index", type=int, default=0,
        help="which vftable, for classes with more than one base (default 0)")
    parser.add_argument("--all", action="store_true",
        help="show every slot, not only the ones that differ")
    args = parser.parse_args()

    pe = pefile.PE(EXE, fast_load=True)
    with open(EXE, "rb") as handle:
        data = handle.read()

    tables = []
    for name in args.classes:
        record = hoi3.classes()[name]
        entry = (record.get("vftables") or [])[args.index]
        rva = int(entry["address"], 16) - IMAGE_BASE
        tables.append((name, entry["slots"],
                       readVtable(pe, data, rva, entry["slots"])))

    named = functionNames(pe, data)

    width = max(len(name) for name, _, _ in tables)
    print("slot  " + "  ".join(name.ljust(10) for name, _, _ in tables))
    slots = max(count for _, count, _ in tables)

    for slot in range(slots):
        values = []
        for _, count, functions in tables:
            values.append(functions[slot] if slot < count else None)

        same = all(value == values[0] for value in values)
        if same and not args.all:
            continue

        cells = []
        for value in values:
            if value is None:
                cells.append("-".ljust(10))
            elif value == values[0] and len(cells) > 0:
                cells.append("=".ljust(10))
            else:
                cells.append(("0x%08x" % value).ljust(10))

        note = ""
        for value in values:
            if value in named:
                note = "  " + "; ".join(named[value])
                break
        print("%4d  %s%s" % (slot, "  ".join(cells), note))


if __name__ == "__main__":
    main()
