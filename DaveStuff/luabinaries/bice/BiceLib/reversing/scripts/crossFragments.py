"""What two agents' fragments say about the same thing, before either one is merged.

    python scripts/crossFragments.py              every collision in fragments/incoming/
    python scripts/crossFragments.py --merged     the same over fragments/merged/, as a check on history
    python scripts/crossFragments.py --quiet      only the disagreements; exit 1 if there are any

`ghidra/mergeFindings.py --check` compares an incoming fragment against `project.json`,
and it compares **address** entries between fragments - `claimedName` / `claimedRva` in its
`trouble()`. What it did not compare was `struct_fields`, so two agents naming one offset
differently were neither refused nor reported and **both records landed for one field**.
That is worse than either being dropped: `buildFindings.py` then keeps whichever comes
first and demotes the other into its comment, and nothing complains, so the file holds two
answers and the decompilation silently takes one. project.json carries four such pairs from
before the check existed - `scripts/reconcileFacts.py` lists them.

The gap was found in wave 12 by an agent reading another agent's fragment by hand and
withdrawing three of its own entries. This is that reading, mechanised, and the same check
is now folded into `mergeFindings --check` so nobody has to remember to run it. This script
stays because it *reports* rather than refuses: an agreement between two agents is
corroboration and worth seeing, and `--check` can only say no.

Three things are reported:

  - the same (struct, offset) in two fragments, with whether the names agree
  - the same rva in two fragments, with whether the names agree
  - one name on two different rvas

An agreement is printed too. Two agents reaching the same answer independently is the
strongest evidence this process produces and hiding it would waste it.
"""

import argparse
import collections
import glob
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)
INCOMING = os.path.join(REVERSING, "fragments", "incoming")
MERGED = os.path.join(REVERSING, "fragments", "merged")


def collisions(paths):
    """(fields, byRva, byName) - each a dict from a key to the fragments that claim it"""
    fields = collections.defaultdict(list)
    byRva = collections.defaultdict(list)
    byName = collections.defaultdict(list)
    for path in paths:
        who = os.path.basename(path)
        fragment = json.load(io.open(path, encoding="utf-8"))
        # `struct_fields`, never `fields`: a fragment spelling it the other way passes
        # every check reporting zero fields and lands nothing, so read only the one key.
        for field in fragment.get("struct_fields", []):
            key = (field.get("struct"), str(field.get("offset", "")).lower())
            fields[key].append((who, field.get("name"), field.get("type"),
                                bool(field.get("revises"))))
        for entry in fragment.get("addresses", []):
            rva = str(entry.get("rva", "")).lower()
            byRva[rva].append((who, entry.get("name")))
            byName[entry.get("name")].append((who, rva))
    return fields, byRva, byName


def report(paths, quiet=False):
    """prints what collides; returns the number of disagreements"""
    fields, byRva, byName = collisions(paths)
    problems = 0

    if not quiet:
        print("%d fragment%s: %s\n"
              % (len(paths), "" if len(paths) == 1 else "s",
                 ", ".join(os.path.basename(p) for p in paths) or "none"))

    hits = {k: v for k, v in fields.items() if len(v) > 1}
    if not quiet:
        print("=== the same (struct, offset) in more than one fragment")
        if not hits:
            print("    none")
    for (struct, offset), rows in sorted(hits.items()):
        # A type that differs is a disagreement as much as a name that does: a field
        # keeping its name and changing its type landed as a second record once, which
        # is what added the type to mergeFindings' own comparison.
        answers = {(name, kind) for _, name, kind, _ in rows}
        agree = len(answers) == 1
        if not agree:
            problems += 1
        if not quiet or not agree:
            print("    %-20s %-8s %s" % (struct, offset,
                                         "AGREE" if agree else "*** DISAGREE ***"))
            for who, name, kind, revises in rows:
                print("        %-24s %-26s %-18s %s"
                      % (who, name, kind, "(revises)" if revises else ""))

    hits = {k: v for k, v in byRva.items() if len(v) > 1}
    if not quiet:
        print("\n=== the same rva in more than one fragment")
        if not hits:
            print("    none")
    for rva, rows in sorted(hits.items()):
        agree = len({name for _, name in rows}) == 1
        if not agree:
            problems += 1
        if not quiet or not agree:
            print("    %-12s %s" % (rva, "AGREE" if agree else "*** DISAGREE ***"))
            for who, name in rows:
                print("        %-24s %s" % (who, name))

    hits = {k: v for k, v in byName.items() if len({r for _, r in v}) > 1}
    if not quiet:
        print("\n=== one name on more than one rva")
        if not hits:
            print("    none")
    for name, rows in sorted(hits.items(), key=lambda kv: str(kv[0])):
        problems += 1
        print("    %-34s *** %s ***"
              % (name, ", ".join("%s %s" % (who, rva) for who, rva in rows)))

    if not quiet:
        print("\n%s" % ("no cross-fragment collisions" if not problems
                        else "%d collision%s - resolve before merging"
                             % (problems, "" if problems == 1 else "s")))
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--merged", action="store_true",
                        help="read fragments/merged/ instead - a check on what has landed")
    parser.add_argument("--quiet", action="store_true",
                        help="print only disagreements, and exit 1 if there are any")
    args = parser.parse_args()
    paths = sorted(glob.glob(os.path.join(MERGED if args.merged else INCOMING, "*.json")))
    sys.exit(1 if report(paths, args.quiet) and args.quiet else 0)


if __name__ == "__main__":
    main()
