# Reversing scratchpad

Scripts for working out what the game keeps where, when nothing we already have
exposes it. Everything here reads the running game and writes nothing to it.

**What has been worked out is in `CLASSES.md`** - every class, its vftable, the fields
identified on it and how far each one can be trusted. This folder is the workings;
that file is the record. `FINDINGS-combat.md` is the long form for the combat classes,
which are the ones that have had the most attention.

**`ghidra/` puts all of it into a Ghidra program**, together with every C++ function
behind the Lua API and its signature, recovered from the executable. Its README says how
to run it and how to add to it.

The first job was the Combat Reports page: combats, wins, losses, kills and losses over
the last day, week, month, half year and year, split into land, air and naval.

## What is already known

The RTTI export in OpenHOI3's `docs` folder (`hoi3_tfh-classes.json`,
found next to this repository) names every class the game's own
compiler recorded, and gives each one its vftable address - which is the handle on
finding instances in memory. `hoi3.py` reads it, so a class name is all a script needs.

The classes that look like the answer:

| Class | Why it matters |
| --- | --- |
| `CCombatHistory` | derives from `CPersistent`, so it is written to the savegame - it holds something worth keeping |
| `CCombatHistoryEntry` | also persistent; almost certainly one past combat each |
| `CCombatManager` | the live side: combats happening now |
| `CCombat`, `CLandCombat`, `CAirCombat`, `CNavalCombat` | one combat, and the three kinds separated by class rather than by a field |
| `CCombatant` and its subclasses | the two sides of a combat |

`../../../../mem/classes/` already has partial notes on `CCombat`, `CCombatant`, `CCombatManager`
and `CCombatHistory` - useful starting points, but not to be trusted without checking.
`CCombatHistory.country_array_ptr = 0x48` in particular is a guess worth verifying
before anything is built on it.

### Two names in `../../../../mem` are wrong

Checking those notes against RTTI, before touching the game at all:

| `../../../../mem` says | RTTI says | |
| --- | --- | --- |
| `CCombat` vftable `0x11C4EE4` | **`CLandCombat`** | `CCombat`'s own are `0x11C4D14` and `0x11C4D64` |
| `CCombatant` vftable `0x11C4DFC` | **`CLandCombatant`** | |

So the offsets recorded under those names are land combat offsets, and may or may not
hold for air and naval. `CCombat` and `CCombatant` are the bases; a derived class has
its own vftable, so scanning for the base finds none of the derived objects. That is
also why `CCombat` shows two vftables - the second, at object offset 8, is the
`CSelectable` it also inherits.

## The tools

**`findInstances.py`** - every live object of a class.

```
python findInstances.py CCombatHistory
python findInstances.py CCombatHistoryEntry --limit 20
python findInstances.py CCombatHistory --dump 0x60
```

The count answers structural questions on its own. One `CCombatHistory` means it is
global; one per country means it is not.

**`dumpStruct.py`** - one object, field by field, every reading of each four bytes side
by side.

```
python dumpStruct.py CCombatHistory --length 0x80
python dumpStruct.py 0x1a2b3c40 --length 0x200 --strings
```

Pointers that land on a known vftable are named, which is usually what identifies a
field first.

**`poolSnapshot.py`**, **`poolCompare.py`** - every country's goods pools, and what moved
between two snapshots.

```
python poolSnapshot.py s1.json     # take several while the game runs
python poolCompare.py s*.json
```

Written to tell apart pools nothing names. A pool that only ever moves in crude oil and
another that only ever moves in fuel are the two sides of the same conversion; one that
never moves in any country over eleven game days is not used at all.

**`saveTokens.py`** - every id the save code uses and the key it stands for, out of the
running game.

```
python saveTokens.py tokens.json            # the running game if there is one
python saveTokens.py tokens.json --compiled # only the ids built into the executable
python saveTokens.py tokens.json --static   # the executable alone
```

Save code never writes a key as a string: it writes an id (`mov ecx, 0x5A6`, then a call)
and a table turns that into `usage`. **That is a way of naming a field the Lua API never
exposes** - find the key in the class's `SaveContents` or `LoadKey` and read the id beside
it. `CCountry`'s goods pools are the worked example, in CLASSES.md.

The game builds that table on first use and it is a `std::vector<std::string>` indexed by
the id, so the running game gives all **4134** of them. Without a game the script scans the
registrations instead, which finds 2056 and agreed with the live table on every one but a
single false positive.

**`--compiled` is the one to re-emit**, into `ghidra/saveTokens.json`: the executable's own
2149, without the resources, cultures and decorations the loaded mod registers on top, which
are numbered in load order and so mean nothing outside that mod. `buildFindings.py` turns
that file into the `SaveToken` enum, which is what makes a save writer decompile as
`SaveWriteKey(usage, writer)`.

**`vtable.py`** - classes' vtables side by side, out of the executable.

```
python vtable.py CCombat CLandCombat CAirCombat CNavalCombat --all
python vtable.py CCombatant CLandCombatant CAirCombatant CNavalCombatant
```

What a subclass overrides is what it does differently, and a slot every sibling shares
is the base's. It is also how a constant-returning virtual gives itself away: that is
how the kind of a combat was found.

**`watch.py`** - snapshot, do something in game, see what moved.

```
python watch.py CCombatHistory --length 0x80
python watch.py CCombatHistoryEntry --instances
```

This is the one that finds counters. Fight a battle, press enter, and whatever counts
combats will have gone up by one while almost nothing else moved.

## Where the memory goes

A second family of scripts, added while chasing a 4 GB address space that kept running
out. They read the running game from outside and write nothing.

**`memorymap.py`** - the overlay's Memory page, from outside: committed against
reserved, split by private/mapped/image, the largest free block and the largest single
allocation. The last two are the pair that matters - a crash is a request bigger than
anything left, not a percentage.

**`census.py`** - every class's live objects, by scanning for its vftable.

```
python census.py --top 40
python census.py --scales-with 108     # what is built per country
```

`--scales-with` is what found the historical models: 5,323,320 objects turned out to be
108 country tags x 1,643 unit types x 30 model levels, at 48 bytes each, and the 30 was
`HISTORICAL_MODEL_MAX` in `common/defines.lua`.

**`regionprofile.py`** - what memory is made of when it is not objects: zeroes,
pointers, text. Most of it is not objects.

```
python regionprofile.py --top 12
python regionprofile.py --save empty.json     # remember what is empty now
python regionprofile.py --compare empty.json  # what has been written since
```

The save/compare pair answers "is this pool ever used". It refuses to call a region
written if the allocator handed the address to something else meanwhile.

**`pointsto.py`** - who holds a pointer into a stretch of memory, and so who owns it.
Search for an exact base address, not a range: a range wide enough to be interesting
matches ordinary code bytes constantly.

**`crashdump.py`** - a minidump without a debugger: the exception, the faulting module
and offset, what address it touched, and which modules the faulting thread's stack
touches.

**`symbolize.py`** - `BiceLib.dll+0x6c2b` into `enableOverlay+0x3b, bice.cpp:1032`,
through dbghelp and the pdb beside the dll. Only works for BiceLib; the game has no
symbols.

## A workflow that works

1. `findInstances.py CCombatHistory` - how many, and where.
2. `dumpStruct.py CCombatHistory` - what it holds. Look for a count next to a pointer:
   that pair is a list, and the list is the entries.
3. `watch.py CCombatHistoryEntry --instances` while a battle finishes. If the count
   rises by one, an entry is a combat.
4. `dumpStruct.py` on a fresh entry, with a battle whose result you know. A date, two
   country tags or ids, a winner, and casualty counts should all be findable by
   matching them against what the battle actually did.
5. Fight a land, an air and a naval battle separately and compare entries. Whatever
   distinguishes them is how the page will split its three columns.
6. Confirm the meaning of every field twice, with different battles, before writing it
   down. A field that happens to match once is the usual way to get this wrong.

## Where findings go

**`CLASSES.md`**, in this folder - a class, its vftable, its known fields, and a mark on
each saying whether it was read out of the code, watched in a game, or only ever copied
from `../../../../mem`. Anything worked out here belongs there, with that mark;
a fact whose provenance is lost is a fact nobody can check later.

Where a class is read by the overlay, the code is the authority for the offsets and
`CLASSES.md` names the file rather than copying the table, so the two cannot drift.
That code goes in a module of its own in the style of `BiceLib/Oob/`, reading through
`Mem::tryRead` so a wrong guess fails instead of taking the game down.

## Notes

- Every address in the RTTI export is against an image base of `0x400000`; at runtime
  everything is relative to wherever the module actually loaded. `hoi3.py` handles it.
- Only matches above `DATA_SECTION_START` are instances. Below that are the vftables
  themselves and the odd static.
- A derived class carries its own vftable, so `CCombat` will not find `CLandCombat`.
  Look each up by its own name.
- Offsets are only good for this build of `hoi3_tfh.exe`, like everything else here.

## Where to look next

Classes whose save and load paths would name the most, counted by `CPersistent`'s slots 2 and
4: how many keys the class writes, and how many of the offsets those two paths touch have no
name yet. The offset count is rough - the register tracking behind it leaks on big loaders -
so read it as a guide, not a ranking. The ones marked done have been read since the list
was written; what is left below them is where to go next.

| class | keys | unnamed | why |
| --- | --- | --- | --- |
| `CGameState` | 33 | 36 | **done** - see CLASSES.md, *The game state, which is the save's root* |
| `CUnit` | - | 21 | **done** - seven fields named from its save path |
| `CAIStrategy` | 21 | 31 | **done** - the whole class, see CAIStrategy.hpp |
| `CSubUnit` | 10 | 21 | **done** - and with it CRegiment, CShip and CWing; see CLASSES.md, *What the save keys named on a sub unit* |
| `COrder` | 9 | 33 | **done** - and with it CAirOrder, CNavalOrder, CSupportAttackOrder and the three that add nothing; see CLASSES.md, *What the save keys named on an order* |
| `CRebelFaction` | 9 | 33 | **done** - and with it CRebelType and CGovernment; see CLASSES.md, *What the save keys named on a rebel faction* |
| `CWar`, `CWarGoal` | 9, 5 | 16, 37 | **done** - and with them CUndeclaredWar and CCasusBelliType; see CLASSES.md, *What the save keys named on a war* |
| `CMilitaryConstruction` | 6 | 18 | **done** - with CConstruction, the two other kinds and CBrigadeConstructionDefinition; the reserves rate is saved as `factor` |
| `CActiveMission` | 5 | 14 | **done** - though every mission in a running game is the null one; see CLASSES.md |
| `CTheatre` | 5 | 8 | **done** - and a `front=` block turned out to be a CAreaBorder |
| `CLeader` | 4 | 10 | **done** - and `experience`/`experience_2` turned out to be one 64-bit `current_experience` |
| `CFaction`, `CMinister` | few | 7-22 | **done** - see CLASSES.md, *The faction, and the minister* |
| `CLaw`, `CTechnology` | few | 7-22 | **left**: both are file parsers with no save path, and long enough that a quick pass would only guess |

**Worth skipping**: the hundred-odd `C*Command`, `CCgm*`, `C*Change`, `C*Effect` and
`C*Trigger` classes are multiplayer command plumbing and event scripting internals, and the
`C*Type` classes are interface definitions. They come top of a raw unnamed-offset count only
because the tracking leaks through their long loaders.
