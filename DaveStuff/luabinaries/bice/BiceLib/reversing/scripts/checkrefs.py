"""Every reference to a file in the reversing tree, checked against the tree.

    python scripts/checkrefs.py              # the whole repository
    python scripts/checkrefs.py --list       # every reference it resolved, with its target
    python scripts/checkrefs.py --tree       # the reversing folder only, which is quick

Exit code 1 if anything does not resolve, so it can gate a commit.

**Written because the folders were split on 2026-10-02** and about six hundred references had to
move with them. The split is the kind of change where a broken reference does not announce itself:
nothing imports a markdown link, so a wrong path sits there until somebody follows it and gives up.
This is the check that the split worked, and it is worth running after any later move.

## The rule it enforces, which is not "every name must be a path"

**A name without a folder is a name.** The prose cites documents and scripts the way someone
standing in `reversing/` would - `` `CLASSES.md` ``, `` `project.json` ``, `` `vtable.py` ``,
`` `FINDINGS-combat.md` `` - and `README.md`'s layout table is what resolves them. There are about
three hundred of those and prefixing them would make the writing worse to settle what one table
settles, so this script does not look at them. It checks what claims to be a path:

1. a `FINDINGS-x.md` reference **with a folder on it**, against the citing file's own folder
2. a `python <something>.py` command line **inside the reversing tree**, against `reversing/` -
   because that is where commands are documented to be run from
3. a backticked path naming one of the tree's folders, against the citing file's folder or the tree

## Two things that will otherwise look like failures

**`scratchpad/...` is meant to be absent.** Several findings files name scripts that were written
into a session scratchpad and never lived here - `scratchpad/power/annfp.py`,
`scratchpad/forceneeds/enrich.py`. The prose describes what each did precisely so the work does not
depend on them, and they are marked with that prefix for exactly this reason. Anything under
`scratchpad/` is skipped.

**A reference resolves against several roots.** `progress.py` holds the strings it writes into
`PROGRESS.md`, which sits in `reversing/`, so `findings/FINDINGS-script.md` in that script is
correct even though the script is in `scripts/`. A C++ header writes `reversing/findings/...` from
the solution directory. So a reference counts as resolved if it resolves from any of: the citing
file's folder, `reversing/`, the solution folder, or the repository root. That is looser than ideal
and still catches every real breakage, because a moved file resolves from *none* of them.
"""

import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)
BICE = os.path.dirname(REVERSING)
REPO = os.path.abspath(os.path.join(REVERSING, "..", "..", "..", "..", ".."))

# Only a reference carrying a folder is a path; see the rule above.
FINDING = re.compile(r"`?([\w./-]+/FINDINGS-[a-z0-9]+\.md)`?")
COMMAND = re.compile(r"python ([\w./-]+\.py)")
PATHISH = re.compile(r"`((?:findings|scripts|ghidra|fragments|probes|reversing)/[\w./-]+)`")

# Build output, dependencies and the mod's bulk - nothing in them cites the tree.
SKIP_DIRS = {".git", ".vs", "__pycache__", "venv", "ReleaseDebug", "x64", "Debug",
             "gfx", "history", "localisation", "map", "pyPdxParser", "old scripts",
             "node_modules"}
READ = (".md", ".py", ".hpp", ".cpp", ".h", ".java")

# Where a reference may resolve from. Loose on purpose - see the docstring.
ROOTS = [REVERSING, BICE, REPO]


def resolves(reference, folder):
    for root in [folder] + ROOTS:
        if os.path.exists(os.path.join(root, reference)):
            return True
    return False


def sources(root):
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in names:
            if name.endswith(READ):
                yield os.path.join(base, name)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true",
                        help="print every reference that resolved, and to what")
    parser.add_argument("--tree", action="store_true",
                        help="only the reversing folder, rather than the whole repository")
    args = parser.parse_args()

    root = REVERSING if args.tree else REPO
    inTree = os.path.abspath(REVERSING)

    broken = []
    skipped = set()
    checked = 0

    for path in sources(root):
        folder = os.path.dirname(path)
        try:
            text = io.open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue

        found = [(hit.group(1), "findings reference") for hit in FINDING.finditer(text)]
        found += [(hit.group(1), "path") for hit in PATHISH.finditer(text)]
        if os.path.abspath(path).startswith(inTree):
            found += [(hit.group(1), "command line") for hit in COMMAND.finditer(text)]

        # A backticked findings path matches both FINDING and PATHISH, so the same reference would
        # otherwise be counted and reported twice; the first pattern wins. Written without an
        # example on purpose - an illustrative path in a comment here is a reference this script
        # then reports against itself, which it did once.
        seen = set()
        for reference, kind in found:
            reference = reference.rstrip("/.")
            if reference.startswith("scratchpad/"):
                skipped.add(reference)
                continue
            if reference in seen:
                continue
            seen.add(reference)
            checked += 1
            # A command line is documented as run from reversing/, so that is its only root.
            ok = (os.path.exists(os.path.join(REVERSING, reference)) if kind == "command line"
                  else resolves(reference, folder))
            if ok:
                if args.list:
                    print("   ok   %-44s %s" % (reference, os.path.relpath(path, REPO)))
            else:
                broken.append((path, reference, kind))

    # Distinct per file, not total occurrences - the same reference repeated in one file gets one
    # verdict, so counting it twice would only inflate the number.
    print("%d distinct references checked under %s"
          % (checked, os.path.relpath(root, REPO) or "the repo"))
    if skipped:
        print("%d scratchpad references skipped, which is what that prefix is for"
              % len(skipped))

    if not broken:
        print("all resolve")
        return 0

    print("\n%d do not resolve:" % len(broken))
    for path, reference, kind in sorted(set(broken)):
        print("   %-44s %-16s %s" % (reference, kind, os.path.relpath(path, REPO)))
    print("\nA name without a folder is a name, not a path - this only reports things that claim")
    print("to be paths. See the layout table in reversing/README.md.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
