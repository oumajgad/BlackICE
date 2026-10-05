# Custom `CCommand`s - the framework, and what is left

**Written 2026-10-04 as a plan; rewritten 2026-10-05 twice, once after building the first
command and once after turning it into a framework.** Addresses are **rvas** against an image
base of `0x400000` unless a line says VA - trap 1, still the most frequent error here.

This file no longer carries the reference picture, because that material lives in two better
places and three copies of a fact is how they drift apart:

| where | what it holds |
| --- | --- |
| `BiceLib/Commands/CBiceCommands.hpp` | **the design.** Why a payload instead of more type ids, which slots are ours, the format, the lifetime, what is not established |
| `BiceLib/Commands/BiceCommandExample.hpp` | **what adding a command looks like**, in four steps, and the one rule a handler must obey |
| `findings/FINDINGS-commands.md` | **the reversing.** The round trip, the registry, the token arithmetic, and what the built DLL was checked for |
| here | status, what is left, and what the original plan got wrong |

---

## What exists

| | |
| --- | --- |
| the framework | `BiceLib/Commands/CBiceCommands.cpp` - one `CCommand` subclass, type id `0x13`, payload key `0x7`, format "B1". Any number of **kinds** ride on it, and a kind costs no token |
| the example | `BiceLib/Commands/BiceCommandExample.cpp` - the "ping" kind. This **is** the MVP that was tested in single player and multiplayer, moved onto the framework |
| the Lua API | namespace **`Commands`**, two functions: `registerBiceCommands()` and `postExampleCommand(args)`, which takes a table of numbers. A real command is a `registerKind` plus a handler in C++, not an export |
| wired in | `script/bicelib_lua.lua` calls `registerBiceCommands()` in its top-level block |
| built | yes, clean, deployed to the repository's `script/` folder |
| run | **the framework has not been run.** The payload-free predecessor was tested in SP and MP on 2026-10-05 and worked; nothing with a payload has executed yet |

## The next step is to run it

In a single player game - registration already happened at load:

    BiceLib.Commands.postExampleCommand()                      -- no arguments
    BiceLib.Commands.postExampleCommand({-1, 7, 2147483647})   -- and with them

What success looks like in the log: one `CBiceCommands: registered type id 0x13 in bucket 19,
payload token 0x7, object 332 bytes` at load, then per post a `post: ping (kind 1), 3 arg(s),
payload 'B10001...'` line **followed by** an `Execute: ping (kind 1), 3 arg(s), turn N,
serial M` line and the handler's own `BiceCommand ping: [-1, 7, 2147483647]`.

The second line is the proof, because the object it runs on is not the object that was posted -
it is the factory's clone of the registered prototype, rebuilt from the serialised bytes. The
third line is the new proof: that the **payload** survived that round trip.

Failure modes worth recognising rather than debugging blind:

- **a `post` line and no `Execute` line** - the prototype is not being found. The id, the
  bucket, or the prototype's `+0x30`.
- **an `Execute` line whose arguments are wrong** - the codec, or slot 2 and slot 4 around it.
  The codec is pure and its one silent failure mode, a payload longer than the field, is a
  `static_assert`; so suspect the serialisation either side of it first.
- **`payload '...' is not one this build understands`** - the payload did not survive. Slot 2
  writes it, slot 4 reads it, slot 13 copies it; the clone is the likeliest of the three,
  because it is the one that is not symmetric.
- **`kind N is not registered in this build`** - a peer is running a different BiceLib.
- **a crash inside the post** - first suspect is a slot's stack contract, though all five were
  fingerprinted in the built DLL (`ret` 0 / 4 / 8 / 0x1C and `mov eax, 0x13; ret`).

## Then, in order

**Multiplayer.** The same calls on two machines. The handler reads nothing but its arguments,
so both machines' logs should carry the **same** `Execute` and `ping` lines, serial for serial.
That is a sharper test than any counter. A `kind N is not registered in this build` line on
either machine means they are not running the same BiceLib.

**A real command.** The framework exists to carry one. The obvious first candidate is whatever
mod action currently cannot be made multiplayer-safe; `registerKind` plus a handler is the
whole of it, with no reversing and no token.

**Targets as id pairs.** The remaining reversing dependency, and the reason the exercise
started. A `CPersistent` reference is an id pair, so it is two `int32` arguments and the format
already carries it - what is needed is the conversion. Copy `CAssignLeaderCommand`: `0x42DD70`
turns an object pointer into a persistent reference and `FindPersistentById` (`0x69DA00`)
resolves it back. Worth a small helper on the framework once it is read, because every command
that names a unit, a leader or a province will want it.

## What the original plan got wrong

Three things, all confident, none a slip.

**It had the step order backwards.** It put "a payload-free command in single player" before
registering, believing single player did not serialise. It does: the mode 2 channel's post
round-trips every command through the serialiser **and the prototype registry**, so
registration is a prerequisite for single player too. The source was a summary table in
`FINDINGS-commands.md` whose first column was headed "loopback" - the name of a different
channel class - while `project.json`'s own entry for that function had said it serialises all
along. **The record was right and the summary of it was wrong**, which is the more dangerous
way round.

**It took the hard route to a type id.** Step 2 was "register a save token", with its unread
appender flagged as the one real unknown and a built-in gap dismissed as "a fallback, not the
plan". Backwards: a mod token is numbered in **load order**, so a peer with different content
gets a different id and silently drops the command. A built-in gap is the same number in every
process. The unread appender was never a blocker; it was a worse design.

**It planned one class per command, and there are only three ids to go round.** "Step 4 - one
field" would have spent a token per field as well. The framework spends two ids total, for
ever, and moves the extensibility inside a payload we own - which is the thing that makes
"add a command" a half-hour job instead of a reversing session.

## Rules that do not change

- **Deploy after every BiceLib source change, without being asked**: `.\Deploy.ps1`, which
  builds and copies the DLL to the repository's `script/` folder **and stops**. Moving it into
  the game is the maintainer's step, never ours.
- **Never commit unless asked.**
- Build through the solution, platform `win32`, output in `ReleaseDebug/`.
- `TODO.md`, `bugs.md` and `REPO-TODO.md` are the maintainer's. `script/bicelib_lua.lua` is
  theirs too - the registration line went in on their instruction, not on our initiative.
- **Before reading a function, grep its rva** - `project.json`, the `GameClasses` headers, *and
  the record's prose*.
- Scripts go in the scratchpad, written with the **`Write` tool**. A heredoc collapsed `\n`
  into real newlines inside three C string literals on 2026-10-05, in the same session that
  this rule was being re-read. It is not a stylistic preference.
- After any record edit: `python ghidra/buildFindings.py`, then `scripts/checkSignatures.py`
  and `scripts/checkrefs.py`, then the headless apply from `ghidra/README.md` against a
  **copy**.
