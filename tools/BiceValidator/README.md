# BICE Validator

Checks BlackICE's script files for the mistakes the game swallows without a word: a
bracket in the wrong place, a key the engine does not know, an effect written where only
conditions are read, an event fired that does not exist. It replaces the old Audax
Validator, whose source is lost and which reports a bracket error without saying where.

What it knows about the language comes from [`docs/script`](../../docs/script/README.md),
whose trigger and effect lists were read out of the game itself. The validator reads those
pages directly, so it can't drift from them.

## Running it

| | |
| --- | --- |
| **Without Python** | double-click `dist/BiceValidator.exe`, see [below](#the-exe) |
| **The window** | double-click `BiceValidator.pyw`, or `python -m bicevalidator_gui` from this folder |
| **The command line** | `python -m bicevalidator` from this folder |
| **A release build** | runs by itself, see [below](#in-the-release-build) |

The window needs PySide6 (`pip install PySide6`). The library and the command line need
nothing beyond Python 3.9.

A full run reads all 18,000 script files in about 8 seconds. The province histories are
checked in parallel processes, which is why both launchers sit behind an
`if __name__ == "__main__"` guard. A script of your own that calls `runner.run` needs one
too.

## The exe

`dist/BiceValidator.exe` is the window as one 25 MB file, with Python and Qt inside, so
it runs on a machine with nothing installed. **It is committed, and it is what everyone
without Python runs.** It still reads the keyword lists and the hidden rules from the
checkout it sits in, and it finds that checkout by itself. A copy kept somewhere else is
pointed at a checkout once with *Browse...* and remembers it.

**After changing the tool, rebuild the exe and commit it with the change.** Otherwise
everyone else keeps running the old one. It needs Python:

    pip install -r requirements-build.txt
    python build.py

Each rebuild adds about 25 MB to the repository's history, so rebuild when a change is
worth handing out, not after every edit. The **Build BICE Validator** action
(`.github/workflows/build-validator.yml`) builds and tries the exe whenever this folder
or `docs/script` changes on master, and keeps the result as the run's artifact. That is a
check that the build still works, and it does not replace the committed exe.

`build.py` runs PyInstaller on `BiceValidator.spec` and writes `dist/BiceValidator.exe`.
It then has the exe validate this checkout through its own worker processes, and fails if
the exe does not finish. That is what a bundle most often gets wrong: a worker started
from a frozen exe needs the `freeze_support()` call in `BiceValidator.pyw`, or it starts
another copy of the program instead of doing its share. `build/` holds PyInstaller's
scratch files and is git-ignored.

The spec drops the parts of Qt the window never uses (software OpenGL, translations,
image and SVG plugins), which halves the exe. If a later window needs one of them, take
it out of `DROP` there.

## Two modes

- **Code**: whether each file is valid script on its own. It checks brackets, quotes, `=`
  signs and encoding, whether every key is a keyword or a name the mod declares, and
  whether each keyword sits in a block that reads it.
- **References**: whether what a file names exists elsewhere in the mod. That covers
  events fired and event ids used twice, country tags, provinces, `load_oob` files,
  modifiers, localisation keys, flags that are tested but never set, and countries with no
  flag image.

Tick either or both in the window, or pass `--mode code|references|all`. "Changed files
only" (`--changed`) reports on the files git sees as modified or new. Declarations and
references are still read from the whole mod, since a reference means nothing against a
part of it.

`python -m bicevalidator --rules` lists every rule. Each one has an id that never changes,
a severity and a confidence:

- **confirmed** means the rule rests on the engine's own keyword switches.
- **inferred** means it rests on how the mod writes things, for example which keys sit
  directly inside an event.

The details pane shows both for every finding.

## Filtering

Both kinds of filtering are stored in this folder and committed, so the window, the
command line and the release build all agree on them.

- **Hiding a rule**: untick it in the window's rule list, or edit `hidden_rules` in
  `validator.json`.
- **Known noise**: mark a finding, or a whole selection with Ctrl+K, and it goes into
  `baseline.json`. Known findings are greyed out and hidden by default, and only new
  findings count.

  A finding is recognised by its rule, file, place in the file's structure and message.
  The place looks like `country_event 14883 > option "Give Permission"`, and there is no
  line number in it, so a finding stays known after lines are added above it.

After a full run with both modes, *Known noise > Drop entries that no longer match*
removes the entries for findings that have since been fixed.

## In the release build

`installer/buildInstaller.py` runs the code mode before it builds. A **new** finding of a
rule listed in `release_blocking` in `validator.json` stops the build. The list starts as
the faults that leave a file unreadable from that point on: the bracket, quote, missing
value and stray `=` rules, and a byte order mark. Every other finding is counted in the
build log but does not stop the build. Use `--skip-validation` to build anyway.

## Layout

| | |
| --- | --- |
| `bicevalidator/lexer.py`, `parser.py` | text to tokens to a tree that keeps going past a broken file |
| `bicevalidator/schema.py` | the keyword lists, read from `docs/script` |
| `bicevalidator/declarations.py` | every name the mod declares: tags, technologies, buildings, units, provinces, ... |
| `bicevalidator/checks/` | `syntax.py`, `script.py` (code mode), `references.py` |
| `bicevalidator/rules.py` | every rule, with the text the details pane shows |
| `bicevalidator/baseline.py`, `config.py`, `review.py` | known noise, hidden rules, and sorting findings into new, known and hidden |
| `bicevalidator/runner.py` | one run: which files, which checks, the process pool |
| `bicevalidator/release.py` | the release build's check |
| `bicevalidator_gui/` | the window |
| `BiceValidator.pyw`, `BiceValidator.spec`, `build.py` | the launcher, and building it into an exe |
| `tests/` | `python -m unittest discover -s tests -t .` |

## Adding a rule

Give it the next free id in `rules.py`, and never reuse a retired one, because the
baseline and `validator.json` store ids. Write its explanation for someone who has never
seen the rule. If the rule rests on how the mod writes things rather than on the engine,
mark it `inferred` and make it a warning.

BV109 is retired. It warned about `not` holding several conditions without an `and`,
following the docs' advice. But the engine's `not` is a NOR
([`FINDINGS-triggereval.md`](../../../hoi3-reversing/findings/FINDINGS-triggereval.md)), so
`not = { a b }` already means "neither", and adding the `and` changes it to "not both".
