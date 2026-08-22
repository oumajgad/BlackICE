# Reversing scratchpad

Scripts for working out what the game keeps where, when nothing we already have
exposes it. Everything here reads the running game and writes nothing to it.

**What has been worked out is in `CLASSES.md`** - every class, its vftable, the fields
identified on it and how far each one can be trusted. This folder is the workings;
that file is the record. `FINDINGS-combat.md` is the long form for the combat classes,
which are the ones that have had the most attention.

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
