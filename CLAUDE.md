# Working in this repository

**BlackICE**, the mod for Hearts of Iron 3: Their Finest Hour. This is the content repository -
events, decisions, history, units, technologies, interface, localisation and gfx - plus the
injected DLL and the tooling that builds a release.

`README.md` points at `docs/`, which is the documentation for writing mod content and is far
better than anything this file would repeat. **Read `docs/script/README.md` before writing an
event or a decision**, for the reason its own front page gives: a key the engine does not
recognise is **silently dropped** - the condition never fires, nothing is logged, and nothing
looks broken.

## The three repositories

The mod is one of three that work together, normally checked out beside each other:

| | |
| --- | --- |
| this one | the mod's content, and `DaveStuff/luabinaries/bice/BiceLib`, the injected DLL |
| `GitHub/hoi3-reversing` | the reverse engineering of `hoi3_tfh.exe` - the fact base the DLL's offsets come from |
| `GitHub/OpenHOI3` | a separate rewrite, in the spirit of the original. Nothing here depends on it |

**The fact base used to live inside this repository**, at
`DaveStuff/luabinaries/bice/BiceLib/reversing`. It moved out on 2026-10-07, so a reference to
that path is stale. Several of this repository's own documents carried such references and were
repointed; `python scripts/checkrefs.py`, run from the fact base, checks this repository's
`docs/` as well as its own prose and exits 1 on a reference that no longer resolves.

Each of the other two has its own `CLAUDE.md`, and the DLL subproject has one too. They are not
interchangeable: the DLL's rules are about a running process, the fact base's are about reading
bytes out of an executable, and applying one set to the other has been the most reliable source
of mistakes across all three.

## The maintainer's own files

Do not pick work off these or edit them unless told to:

`bugs.md`, `REPO-TODO.md`, `DaveStuff/luabinaries/bice/BiceLib/TODO.md`, and
`script/bicelib_lua.lua`.

## Things that have cost a session

- **Game and mod text is Windows-1252**, not UTF-8. Writing UTF-8 into a mod file turns umlauts
  into mojibake in-game, and anything read out of the running game has to be converted or they
  become `?`.
- **The engine swallows its own parse errors.** Every channel reaches a file, so a bad name is
  not an error to the engine - it is simply not the name of anything. "It loaded" means nothing.
- **A country with no flag `.tga` kills startup** at "Processing Flags". Check
  case-insensitively when adding a tag.
- **`zDsafeMoveFiles.py` clears the destination before copying**, which is why it keeps a
  `PreserveInScript` list. Any new file shipped alongside the DLL has to be added to it.
- **Numbers in the game's data are thousandths** - `237964731` is `237964.731`.

## The DLL

`DaveStuff/luabinaries/bice/BiceLib` builds `BiceLib.dll` and has its own `CLAUDE.md` with the
rules that matter for it. The one thing worth knowing from out here: **deploying copies the DLL
into this repository's `script/` folder and stops.** Moving it into the game install is the
maintainer's step and is never done automatically.

## Always

- **Never commit unless asked.**
- Scripts go in the scratchpad, written with the `Write` tool. Bash heredocs here mangle
  apostrophes and collapse escape sequences into real bytes; both have corrupted a file.
- The game install is **reference data**. Read it; never write to it.
