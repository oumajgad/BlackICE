# Working in this directory

This is **BiceLib**: the C++ module that loads into a running `hoi3_tfh.exe` and ships with the
BlackICE mod. The artefact is `BiceLib.dll`. The game **is running** - threads, lifetimes and
frame timing all matter - and a claim is checked by **provoking it in a session and watching**.

That is worth stating because the other half of this work is the opposite in every respect. The
static reverse engineering of the executable used to live here, in a `reversing/` subfolder, and
almost every mistake made across the two came from applying one half's rules to the other. **It
moved out on 2026-10-07** and is now its own repository, normally at `GitHub/hoi3-reversing`
beside the mod. Nothing here compiles against it, so the build does not need it - but developing
this DLL does, because that is where every offset's evidence lives. Keep both checked out.

## The seam

A fact found on the reversing side becomes code by being written **twice**: once into the
record's `project.json`, so the record and Ghidra agree, and once into a
`BiceLib/GameClasses/*.hpp` constant, so the DLL can use it. The headers cite the findings file
that established each offset, with the `reversing/` prefix on the front - that prefix is the fact
base's *logical* name and resolves wherever it is checked out. **Keep citing it**, because
it is the only link between a magic number and the evidence for it, and the record's
`checkrefs.py` verifies every one of those citations from the other side.

**This DLL is the fact base's strictest consumer**, not an incidental one. It is the only thing
that *executes* against those facts: a wrong offset here crashes a running game, while the same
error in a design document costs a paragraph. So offsets are a first-class part of that record,
kept for this, and new features that need new offsets are ordinary work rather than a detour.

It is also the only thing that can ask the **running** game a question, which no amount of
reading the bytes can answer. When a static reading has two possible meanings, a hook here
settles it.

## Which document to read

| | |
| --- | --- |
| `README.md` | the Lua API, function by function - what `script/bicelib_lua.lua` can call |
| `README-imgui.md` | the overlay: what it draws, how it is switched on, how it reaches the screen |
| the fact base's `CLAUDE.md` | everything about reading the executable: the pipeline, the traps, the record |

`TODO.md` is **the maintainer's own**. Do not pick items off it unless told to.

## Building and deploying

**Build through the solution, not the vcxproj.** `BiceLib.vcxproj` on its own writes the DLL to
the wrong folder. The platform is spelled `win32`, not `x86` - no configuration matches the
other name. Output lands in `ReleaseDebug/` whatever the configuration is called, which is the
solution's own naming and not a bug.

**Deploying means: build, copy the DLL into the mod's `script/` folder, and stop.** `Deploy.ps1`
does exactly that and deliberately does not touch the game directory. **The maintainer moves it
into the game** - that step is theirs, and the script that does it (`zDsafeMoveFiles.py` at the
mod's root) clears the destination first, which is why it keeps a `PreserveInScript` list that
any new file shipped alongside the DLL has to be added to.

**Always run it after changing BiceLib source - do not wait to be asked.** A build that stops at
`ReleaseDebug/` leaves the mod's `script/` folder holding a stale DLL, which is worse than
either building or not building, because the thing the maintainer copies across is then not the
thing that was just changed. The step that needs permission is the one into the game, and
`Deploy.ps1` already refuses to take it. So: source changed -> `.\Deploy.ps1` -> say where it
landed.

## Four things about running inside the process, each of which has cost a session

- **The render thread runs Lua.** `Present` and the game's Lua share a thread, so the overlay
  can call `lua_pcall` directly. But the `Present` hook also runs **at the main menu**, where
  there is no session, and **the state pointer is not a session guard** - `CCurrentGameState`
  exists from the main menu onward, so `current() != 0` answers "yes" in exactly the place the
  guard has to say "no". That was a real bug and it is fixed; both guards are now correct and
  they answer different questions:
  - `Gui::Lua::sessionActive()` reads the game's own `in_game` byte (`CCurrentGameState +0xDA4`).
    "Is a game on screen." This is what gates a Lua call.
  - `GameClock::movedInPlay()` is stricter: steady clock steps **and** `in_game`. "Is the clock
    running normally." This is what once-a-day work needs. Neither covers the other, which is
    why both exist: the step count alone cannot tell a paused game from the menu, and `in_game`
    alone is set a little too early.
    **`in_game` is *not* set during a load** - this file said it was until 2026-10-02 and that
    was wrong (`reversing/findings/FINDINGS-session.md`). The byte has six writers in the image,
    only one writes a one, and the savegame loader is reachable only from the pre-game lobby or
    the tutorial screen, neither of which is the in-game screen. The window `movedInPlay()`
    really excludes is the **tail of `CInGameIdler::Enter`**: the write that sets `in_game` lands
    0x4A92 bytes before the end of it, and everything after that builds the in-game interface -
    so there is a stretch where a session exists, `in_game` is 1, and the in-game GUI does not
    exist yet.
- **A message raised mid-frame comes up empty.** Raise it from a tick, not from inside `Present`.
- **A command's `Execute` runs on every peer, so it must not read anything local.**
  Multiplayer is synced by broadcasting `CCommand`s and draining them in one ordered loop, so a
  feature that decides what to do from the pressed key, from `CInGameIdler`'s selection or from
  `played_country_id` *inside* an `Execute` does something different on each machine - which is
  a desync, and no test inside that `Execute` can repair it. **A local input may choose which
  commands to post; it may never change what a command does when it runs.** So read the keyboard
  in the GUI handler that only the clicking player runs, and emit commands that name their own
  targets - `CAssignLeaderCommand` holds each end as a `CPersistent` id pair for exactly this
  reason. This cost a session and two rebuilds on the Ctrl-unassign feature;
  `reversing/findings/FINDINGS-commands.md` point 5 has the worked example.
- **Game text is Windows-1252.** Anything read out of the game goes through `Text::toUtf8` or
  umlauts become `?`.

Prefer **hooking the game's own function over polling** - the maintainer can provoke events on
demand, so a hook is both cheaper and more honest than a poll that infers.

## Always

- **Never commit unless asked.**
- Scripts go in the scratchpad, written with the `Write` tool. Bash heredocs here mangle
  apostrophes and collapse `\x00`-style escapes into real bytes; both have corrupted a file.
- **Only valid for this build of `hoi3_tfh.exe`.** Every offset, address and vftable index is
  build-specific.
- **OpenHOI3 must not read anything from here.** The rewrite is its own technology; a
  build-specific offset is meaningless to it and a header of ours is the wrong place for it to
  look. It reads the fact base's prose instead.
