"""Top level keys a history file sets more than once, and which value the engine keeps.

    python dupekeys.py                       # province histories, the infra key
    python dupekeys.py --key manpower
    python dupekeys.py --countries --key capital
    python dupekeys.py --all                 # every repeated top level key, any name

**The engine keeps the last one.** That is not a guess: on 2026-10-02 the live
`CMapProvince +0x5C` was compared against every province history on disk, and it agreed with
`last_infra * 100` on **10,642 of 10,642** provinces, against 98.43% for the *first* key - the
1.57% gap being exactly the files that repeat it. So an earlier line is silently discarded.

Nothing here is broken in play, which is why it belongs in bugs.md as a data note rather than a
gameplay bug: the game does what the last line says. The problem is that the files read as though
the earlier lines did something, and in most cases the earlier value is the higher one.

A dated block (`1939.1.1 = { ... }`) is a different thing from a repeated top level key, so brace
depth is counted and only depth-zero keys are reported.
"""

import argparse
import collections
import glob
import os
import re

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "..", "..", "..", ".."))
PROVINCES = os.path.join(REPO, "history", "provinces")
COUNTRIES = os.path.join(REPO, "history", "countries")

KEY = re.compile(r"^\s*([A-Za-z_][A-Za-z_0-9]*)\s*=\s*([^\s#{]+)")


def topLevelKeys(path):
    """Every depth-zero `key = value` in the file, in order."""
    out = []
    depth = 0
    try:
        lines = open(path, encoding="latin-1").read().split("\n")
    except OSError:
        return out
    for line in lines:
        stripped = line.split("#", 1)[0]
        hit = KEY.match(stripped)
        if hit and depth == 0:
            out.append((hit.group(1), hit.group(2)))
        depth += stripped.count("{") - stripped.count("}")
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", default="infra")
    parser.add_argument("--countries", action="store_true")
    parser.add_argument("--all", action="store_true",
                        help="report every repeated key rather than one")
    args = parser.parse_args()

    root = COUNTRIES if args.countries else PROVINCES
    if not os.path.isdir(root):
        print("no such folder: %s" % root)
        return

    files = sorted(glob.glob(os.path.join(root, "*", "*.txt")))
    files += sorted(glob.glob(os.path.join(root, "*.txt")))
    print("%d history files under %s" % (len(files), os.path.relpath(root, REPO)))

    perKey = collections.Counter()
    rows = []
    for path in files:
        keys = topLevelKeys(path)
        counts = collections.Counter(name for name, _ in keys)
        for name, n in counts.items():
            if n < 2:
                continue
            if not args.all and name != args.key:
                continue
            perKey[name] += 1
            values = [value for key, value in keys if key == name]
            rows.append((os.path.basename(path), name, values))

    if args.all:
        print("\nrepeated top level keys, by how many files repeat them:")
        for name, n in perKey.most_common(40):
            print("   %-28s %d files" % (name, n))
        print("\n%d files repeat at least one top level key" % len({r[0] for r in rows}))
        return

    print("\nfiles repeating `%s`: %d" % (args.key, len(rows)))
    shape = collections.Counter(len(values) for _, _, values in rows)
    print("   how many times:", dict(sorted(shape.items())))

    def number(text):
        try:
            return float(text)
        except ValueError:
            return None

    down = up = flat = unknown = 0
    for _, _, values in rows:
        first, last = number(values[0]), number(values[-1])
        if first is None or last is None:
            unknown += 1
        elif last < first:
            down += 1
        elif last > first:
            up += 1
        else:
            flat += 1
    print("   the kept value is lower than the first:  %d" % down)
    print("   the kept value is higher than the first: %d" % up)
    print("   the same, so the duplicate is harmless:  %d" % flat)
    if unknown:
        print("   not numeric, not compared:               %d" % unknown)

    print("\n   id      file                                     keys -> kept")
    for name, _, values in sorted(rows):
        print("   %-40s %-26s -> %s" % (name[:40], ",".join(values), values[-1]))


if __name__ == "__main__":
    main()
