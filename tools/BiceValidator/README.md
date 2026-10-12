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
| **In VS Code** | run `dist/install-vscode-extension.ps1` once, see [below](#the-vs-code-extension) |
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

`dist/BiceValidator.exe` is the window as one 25 MB file, with Python, Qt and the keyword
lists inside, so it runs on a machine with nothing installed. **It is committed, and it is
what everyone without Python runs.** It can be copied anywhere. It checks any mod
folder - one with `events`, `decisions` and `common` in it, such as this checkout or an
installed copy under the game's `tfh/mod`:

- **Finding the mod.** The exe always opens on the checkout it sits in. *Browse...*
  switches to another folder for the session. A copy kept outside any checkout opens on
  the folder it was last pointed at.
- **Keyword lists.** If the mod has `docs/script`, the exe reads the lists from there, so
  an edit to the docs counts straight away. If not, it uses the copy built into it. The
  status bar and *Help > About* say which one a run used, and when the built-in copy was
  taken.
- **Hidden rules and known noise.** For this checkout they are the committed
  `validator.json` and `baseline.json`. For any other mod folder they are kept in
  `%APPDATA%\BICE Validator\mods\`, so the exe never writes into the game folder.

"Changed files only" asks git, so it works only on a checkout and only where git is
installed.

**After changing the tool or the keyword pages in `docs/script`, rebuild the exe and
commit it with the change.** Otherwise everyone else keeps running the old one, and an
installed copy is checked against the old keyword lists. Rebuilding needs Python:

    pip install -r requirements-build.txt
    python build.py

Each rebuild adds about 25 MB to the repository's history, so rebuild when a change is
worth handing out, not after every edit. The **Build BICE Validator** action
(`.github/workflows/build-validator.yml`) builds and tries the exe whenever this folder
or `docs/script` changes on master, and keeps the result as the run's artifact. That is a
check that the build still works, and it does not replace the committed exe.

`build.py` runs PyInstaller on `BiceValidator.spec` and writes `dist/BiceValidator.exe`.
It then tries the exe twice and fails if either run goes wrong:

- it validates this checkout through the exe's own worker processes;
- it validates a small mod with no `docs/`, which must fall back to the built-in keyword
  lists. That is what a bundle most often gets wrong: a worker started
from a frozen exe needs the `freeze_support()` call in `BiceValidator.pyw`, or it starts
another copy of the program instead of doing its share. `build/` holds PyInstaller's
scratch files and is git-ignored.

The spec drops the parts of Qt the window never uses (software OpenGL, translations,
image and SVG plugins), which halves the exe. If a later window needs one of them, take
it out of `DROP` there.

## The VS Code extension

**BlackICE Script** puts the validator into VS Code:

- **Findings while you type.** The code checks run on the open file about a third of a
  second after you stop typing, from the unsaved text.
- **References after every save.** The reference checks run over the whole mod in the
  background after each save, in about ten seconds.
- **Windows-1252 by default.** Script files open and save in Windows-1252, so the UTF-8
  problem behind BV007 can no longer happen in VS Code.
- **Colouring.** Keys, conditions, effects, scopes, tags, numbers, dates and comments
  are coloured.
- **Hover.** On a keyword, its description and syntax from `docs/script`. On a fired
  event, its title, description and options. On a localisation key, its English text.
  On a country, a province, a technology, a unit, a building or a modifier, its name and
  where it is declared. On a flag, how often it is set, tested and cleared.
- **Go to definition** (F12). Jumps from a fired event to the event, from `load_oob` to
  the file, from a name to its declaration, from a localisation key to its line in the
  table, from a keyword to its row in `docs/script`, and from a flag to where it is set.
- **Find all references** (Shift+F12). For an event, everything that fires it, including
  `common/on_actions.txt`. For a flag, everywhere it is set, tested or cleared, in the
  Lua scripts as well. For a modifier, everywhere it is added, tested or removed.
- **Outline and Go to Symbol.** The outline lists a file's events by id and title, with
  their options, or its decisions by category. Ctrl+T finds any event or decision in the
  mod by id, name or title.
- **Event titles.** `country_event = 14883` shows the event's title faintly at the end of
  the line. The `eventTitles` setting turns this off.
- **Quick fixes** (Ctrl+.). A misspelt key becomes the name it was meant to be,
  `brigade_exists` becomes `brigade_exist`, and `factor 100` gets its `=`.
- **Completion that knows its block.** Conditions inside `trigger` and `limit`, effects
  inside `option` and `effect`, an event's own keys inside an event. After the `=` it
  offers event ids with their titles, countries, flags, modifiers, order of battle files
  and yes or no, as the key takes.
- **Folding** by brackets rather than by indentation, and by runs of comment lines.
- **The next free event id.** *BlackICE: Insert the next free event id* puts in the first
  id no event uses, after the id of the event above the cursor.

**Installing.** From VS Code's terminal, at the repository root, run
`.\tools\BiceValidator\dist\install-vscode-extension.ps1`, then reload VS Code
(*Developer: Reload Window*). If Windows refuses to run scripts, use
`powershell -ExecutionPolicy Bypass -File` followed by the same path. Run it again after
`dist/blackice-script.vsix` changes. Without the script, *Extensions > ... > Install from
VSIX* does the same. The language server is inside the `.vsix`, so nothing else
needs installing.

**Settings.** The extension has its own settings, under `blackice.validator` in VS
Code's settings:

- `disabledRules` and `minimumSeverity`;
- `references` (`onSave` or `off`);
- `scope`: `workspace` puts every file's findings in the Problems panel, after a
  background run of about half a minute;
- `hideKnownNoise`, which hides what `baseline.json` lists;
- `eventTitles`, which shows the titles of fired events.

It does not read `validator.json`.

**What it keeps up to date.** The server reads the mod once when the first script file
opens, in about three seconds. After that, an open file counts as its unsaved text. A file
changed outside the editor, by a git pull for example, is read again within a second.

**How it is built.** The server is `bicevalidator_lsp/`, which uses pygls for the
protocol and this library for everything else. Hover, definitions, references,
completion and the outline are answered by `bicevalidator/navigate.py`, from an index of
the events, decisions, flags and modifiers (`index.py`) and the localisation
(`localisation.py`). It is bundled with PyInstaller into
`bicevalidator-lsp.exe`, a 10 MB console program with no Qt. The extension in `vscode/`
only starts that exe and connects it to VS Code. The colouring grammar is generated from
`docs/script`, and the rule list of the `disabledRules` setting from `rules.py`.

**Rebuilding.** This needs Python and Node.js
(`winget install OpenJS.NodeJS.LTS`):

    pip install -r requirements-build.txt
    cd vscode
    python build.py

`build.py` builds the server, makes the grammar, brings `package.json`'s rule list in step,
bundles the extension and then tries it: it starts the extension in a fresh copy of VS
Code against a small mod and checks the colouring language, the Windows-1252 reading and
saving, a finding appearing while typing and going when fixed, and a setting hiding a
rule. The first run downloads that copy of VS Code, about 350 MB, into
`vscode/.vscode-test` (git-ignored). Then it writes `dist/blackice-script.vsix`. Commit
that with the change, like the exe. `python -m unittest discover -s tests -t .` also
drives the server over the protocol (`tests/test_lsp.py`). Set `BICEVALIDATOR_LSP` to
the built exe to drive that instead.

To try a change to the server without rebuilding, set `blackice.validator.serverCommand`
to `["python", "<this folder>/BiceValidatorLsp.py"]` and run *BlackICE: Restart the BICE
Validator server*.

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
| `bicevalidator/session.py`, `bicevalidator_lsp/`, `BiceValidatorLsp.py`, `bicevalidator-lsp.spec` | the language server: a mod kept loaded, the protocol, its launcher and its exe |
| `bicevalidator/index.py`, `localisation.py`, `navigate.py` | what the editor asks about: where events, flags and modifiers are, what keys read as, what is at a place in a file |
| `vscode/` | the VS Code extension, its tests in VS Code, and `build.py` |
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
