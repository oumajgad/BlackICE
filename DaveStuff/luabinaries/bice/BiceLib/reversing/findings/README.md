# The findings files

The long form. One file per piece of work, 67 of them, and between them they are the evidence for
everything in `../ghidra/project.json` and every offset in a `GameClasses` header.

**`../CANDIDATES.md` has the index** - all 67 grouped by domain, one line each, which is the quick
way to find which file settled a thing. `../CLASSES.md` is the per-class record and cites these
files; `../PROGRESS.md` is the generated scoreboard.

## Reading a reference in one of these files

They were written while they all sat in `reversing/` itself, and they name their neighbours the way
someone standing in that folder would. So, from here:

| what a file says | where it is |
| --- | --- |
| `FINDINGS-combat.md` | right here - a sibling, and these references are correct as written |
| `CLASSES.md`, `TRAPS.md`, `CANDIDATES.md`, `PROGRESS.md`, `README.md` | one level up, in `reversing/` |
| `project.json` | `../ghidra/project.json` |
| a bare script name, `fieldchain.py` or `vtable.py` | `../scripts/`, and commands are run from `reversing/`: `python scripts/fieldchain.py` |

Those bare names were left as names on purpose when the folders were split on 2026-10-02. Prefixing
300 mentions in the prose would have made the writing worse to resolve something this table
resolves once. **Command lines were rewritten**, because those are meant to be run.

One thing to watch: the prose also names scripts that never lived in `reversing/` - `whoslot.py`,
`dispscan.py`, `annfp.py`, `definecache.py`, `frame.py` and others were written into a scratchpad
for one session and are gone. If a script is named here and not in `../scripts/`, that is why, and
the file that names it says what it did.

## What these files are not

They are **not** `fragments/`. `../fragments/` is the staging area for parallel agents - JSON
fragments through `incoming/` and `merged/`, landed by `ghidra/mergeFindings.py`, with the contract
in its own README. That folder was called `findings/` until 2026-10-02, which is exactly the
confusion the split was meant to end.
