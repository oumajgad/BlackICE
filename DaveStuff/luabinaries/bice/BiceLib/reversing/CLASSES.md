# The game's classes, as far as they are known

What each object is, where it sits, and which of its fields have been identified. This
is the reference; `FINDINGS-combat.md` is the story of how the combat ones were worked
out, and the scripts here are what to work the next ones out with.

**The code is the authority for the offsets it uses.** Where a class is read by BiceLib,
this file names the source file rather than copying its table, so the two cannot drift
apart. What is here that the code does not have is where a fact came from and how far it
can be trusted.

## How to read this

| Mark | Means |
| --- | --- |
| **RTTI** | From the OpenHOI3 export: the class's name, its bases, its vftables, how many slots. Reliable, and says nothing at all about fields. |
| **read** | Read out of the game's own code with the scripts here. As good as it gets without running anything. |
| **seen** | Watched in a running game and matched against a number the game itself displayed. |
| **used** | BiceLib reads it and has done for a while with nothing looking wrong, but it has never been checked against the game's own display. |
| **mem** | From `../../../../mem`, and nothing more. A lead, not a fact - it has been wrong before. |

Addresses are relative to the module, the way BiceLib uses them. The RTTI export writes
them absolute against an image base of `0x400000`, so subtract that when copying one
across. `hoi3.py` does it for you.

## Anchors

Everything reachable starts from one global.

```
[MODULE + 0x1689790]  CCurrentGameState*        read, and it is what sessionActive() reads
```

**`CCurrentGameState`** - vftable `0x11CF674`, `0xda8` bytes, constructed at
`0x0067D070` (**read**: both callers of the combat recorder allocate `0xda8`, call that
constructor and store the result in the global). It is created lazily, and **exists at
the main menu** - see `present-hook-must-not-call-game-lua` and `README-imgui.md`. Its
being non-null proves nothing about a game being loaded.

| Offset | Holds | |
| --- | --- | --- |
| +0xB3C | something with vftable `0x11C9BEC` | read |
| +0xB5C | **`CCombatManager`, embedded** | read |
| +0xB74 | the `CCombatHistory` inside it (`+0xB5C` + `0x18`) | read |
| +0xBDC | **the current tick** | read, and used |

## Conventions the game keeps to

- **`std::string` is MSVC's**: sixteen bytes of buffer, or a pointer where the string is
  longer than fifteen; the length is at +0x10. `utils::getCString` handles both.
- **Text is Windows-1252**, not UTF-8. Run anything read out of the game through
  `Text::toUtf8` or umlauts come out as `?`.
- **A country tag is three characters, a NUL, then the country id** - eight bytes,
  wherever one appears.
- **Two list shapes.** Standalone nodes of `{ data +0x00, next +0x08 }`, and embedded
  `__CList` bases of `{ first, last, count }` - `CUnit` has one of those at +0x38, which
  is why its regiments are read from there.
- **Vector-ish triples** of `{ begin, end, capacity }` and often a byte after them.
  `CCombatant` has several in a row. An offset first read as a count may be the third
  pointer of one of these.
- **Dates are ticks**: hours since `43800000`, years of 365 days with no leap day.
  `utils::gameTickToDate` and `utils::dateToGameTick`, `hoi3.tickToDate` here.
- **`+0x04` is `0x18d` (397) on nearly every object.** Metadata on a shared base. It is
  not a date and not a count; ignore it.

## Combat

The whole of how these were found, and what is still open, is in `FINDINGS-combat.md`.
BiceLib reads them in `Combat/CombatLog.cpp`.

### The manager and its history

| Class | vftable | |
| --- | --- | --- |
| `CCombatManager` | `0x11B68F8` | RTTI |
| `CCombatHistory` | `0x11B68DC` | RTTI |
| `CCombatHistoryEntry` | `0x11B68C0` | RTTI |

```
CCombatManager                 embedded in CCurrentGameState at +0xB5C
  +0x08  first node            live combats, {data, previous, next} nodes
  +0x0c  last node
  +0x10  count
  +0x18  CCombatHistory, embedded
         +0x08  first entry    finished combats, entries linked through themselves
         +0x0c  last entry
         +0x10  count
```

**The two lists are not the same shape** - live combats hang off nodes, finished ones
are the entries. **seen**, and it cost an hour.

`CCombatHistoryEntry` is `0x34` bytes and holds a tick, a province, one country tag and
the kind - no casualties, and the game prunes them after a few days. **read** off its
constructor at `0x0042F340`. That is why BiceLib keeps its own record.

### The combats

| Class | vftable | at +8 | builds | |
| --- | --- | --- | --- | --- |
| `CCombat` | `0x11C4D14` | `0x11C4D64` | - | RTTI |
| `CLandCombat` | `0x11C4EE4` | `0x11C4F34` | `CLandCombatant` | RTTI, seen |
| `CNavalCombat` | `0x11C4F5C` | `0x11C4FAC` | `CNavalCombatant` | RTTI, read |
| `CAirCombat` | `0x11C4FD4` | `0x11C5024` | `CAirCombatant` | RTTI, read |
| `CBombing` | abstract | - | - | RTTI |
| `CGroundBombing` | `0x11B6934` | `0x11B6984` | `CGroundTargetCombatant` | RTTI, read, seen |
| `CLandBombing` | `0x11B69AC` | `0x11B69FC` | `CLandTargetCombatant` | RTTI, read, seen |
| `CNavalBombing` | `0x11B6A24` | `0x11B6A74` | `CNavalTargetCombatant` | RTTI, read |

The second vftable is the `CSelectable` base at object offset 8. **Which combatant each
builds is read** off the combat's slot 6, where it makes its two of them.

**Slot 11 is the kind**: `mov eax, N; ret`, pure virtual on `CCombat` (**read**) - 1
land, 2 naval, 3 air, 4 ground bombing, 5 land bombing, 6 naval bombing. Comparing
vftables and calling it come to the same thing.

A bombing raid is a combat like any other and ends up in the same history, but
**nobody wins one** - neither side is emptied - and what its target loses has not
been checked against anything the game displays.

Fields, all on the `CCombat` base and so the same for every kind (**read**: the history
entry's constructor takes a plain `CCombat*` and dispatches on nothing):

| Offset | Holds | |
| --- | --- | --- |
| +0x10 | attacker, a `CCombatant*` | read |
| +0x14 | defender | read |
| +0x18 | the `CMapProvince` fought over | read |
| +0x2b | a flag the entry keeps at its +0x20 | read |
| +0x1c, +0x20 | 3 and 3 in one battle, 2 and 2 in another - not the day and duration `mem` calls them | seen, unexplained |
| +0x24 | `CTerrain` | mem |

### The combatants

| Class | vftable | slots | |
| --- | --- | --- | --- |
| `CCombatant` | `0x11C4CA4` | 26 | RTTI |
| `CLandCombatant` | `0x11C4DFC` | 28 | RTTI |
| `CNavalCombatant` | `0x11C4D8C` | 26 | RTTI |
| `CAirCombatant` | `0x11C4E74` | 26 | RTTI |
| `CBomberCombatant` | `0x11C45DC` | 26 | RTTI, not used by `CAirCombat` |
| `CGroundTargetCombatant` | `0x11C464C` | 26 | RTTI |
| `CLandTargetCombatant` | `0x11C472C` | 26 | RTTI |
| `CNavalTargetCombatant` | `0x11C46BC` | 26 | RTTI |

**Every field BiceLib reads is on the base**, initialised by `CCombatant`'s constructor
at `0x00564550` which all of them run (**read**) - so they are at the same offsets
whatever the combatant is. A bombing raid bears that out: its bomber and target
combatants both gave up their country and their losses at these offsets (**seen**).

| Offset | Holds | |
| --- | --- | --- |
| +0x3c | back to the combat | mem |
| +0x40, +0x44 | the units on this side, a vector of `CUnit*` | mem |
| +0x54 | the country list the game takes a tag from - **emptied on the beaten side** | read |
| +0x5c | zero when that list is empty, which is how the game decides to write `---` | read |
| +0x64 | the side's own countries, **kept** when +0x54 is emptied - where the loser's name comes from | read, seen |
| +0x74, +0x78 | **the men on this side, per subunit type** - summed over a thousand it is the "out of 25700 troops" the battle message prints, and the game builds it exactly that way at 0x005745f4. Only men in a land or naval fight: an air combat counts subunits here, a bombing raid leaves it empty | read, seen |
| +0x84 | **losses, in thousandths** - 21 losses read back as 21900, and the message prints this over a thousand as its casualties. A subunit destroyed outright adds exactly 1000 | seen, read |
| +0x88, +0x8c | **subunits destroyed, per type** - a vector with an entry per kind of brigade, ship or plane, each holding 1000 per one destroyed. Its sum over a thousand is how many were lost outright. Nothing in BiceLib reads it | read |
| +0x98 | damage short of destruction, per type, the same shape | read |

`CLandCombatant` is the outlier in behaviour, fifteen slots of its own against the
others' five; that is code, not layout. `CNavalCombatant` is at least `0x10b8` bytes -
its constructor writes +0x10b4 (**read**).

### Where it is recorded

`0x0042F960` appends an entry, and **its second argument is the live `CCombat`** - which
is what BiceLib hooks. Called from `0x0043170B` (the manager's own code) and
`0x005D2904` (among the `CArmy`, `CNavy` and `CAir` virtuals, so unit code). Both fetch
the game state and append to the same history at `gameState + 0xB74`. **read.**

`0x00434140` and `0x004341F0` build an entry on the stack and go through a virtual;
reached from `CCombatHistory`'s own, so almost certainly save and load rather than
gameplay.

## Units

BiceLib keeps these in `GameClasses/CUnit.hpp`, which is the authority for the offsets.
`Gui/OrderOfBattle.cpp` reads them but no longer holds a copy of its own.

| Class | vftable | at +8 | |
| --- | --- | --- | --- |
| `CUnit` | `0x11C85CC` | `0x11C8678` | RTTI |
| `CArmy` | `0x11BDE0C` | `0x11BDEB8` | RTTI, used |
| `CNavy` | `0x11C869C` | `0x11C8750` | RTTI, used |
| `CAir` | `0x11C8774` | `0x11C8828` | RTTI, used |
| `CRegiment` | `0x11BDD7C` | - | RTTI |
| `CLeader` | `0x11C5220` | - | RTTI |
| `CTheatre` | `0x11C0788` | - | RTTI |

`CUnit`'s bases are `PAVCSubUnit::__CList` **at +0x38**, `CReferenceObject` at +0x8 and
`CSelectable` - which is what the regiment list at +0x38 with its count at +0x40 is
(**RTTI**, and it agrees with what the OOB browser reads).

Two things worth knowing about the vftable check:

- The second vftable of each is the base it inherits **at object offset 8**, and never
  appears at the start of a unit, so only the first is worth comparing against.
  `OrderOfBattle` used to also accept `CArmy`'s second as an alternative kind of
  land unit, which could not match; it no longer does.
- Everything in the order of battle is a `CArmy`, `CNavy` or `CAir`, including the
  entries the level field calls theatres. **`CTheatre` is a different class** and what it
  is has not been looked at.

The unit's own fields - name, province, leader, supply, fuel, level, regiments and the
rest - are in `GameClasses/CUnit.hpp` (**mem** originally, **used** since, and the ones
the OOB browser shows have never looked wrong). There used to be a second copy of them
inside `OrderOfBattle.cpp`, identical offset for offset; the two are now one.

The sub units a unit holds are `CRegiment` (`GameClasses/CRegiment.hpp`): strength at
+0x30, organisation at +0x60 and the name at +0x68, all **used** by the OOB browser.
Air and naval sub units are read through the same three and have never looked wrong,
but only the land case is known to be this class.

Also in `GameClasses/`, all **mem** unless marked otherwise, and each header its own
authority: `CLeader.hpp`, `CMapProvince.hpp` (province id at +0xD0 is **used** by the
combat capture and the OOB browser), `CSubUnitDefinition.hpp`, `CTerrain.cpp` (vftable
`0x11C0764`, **used**).

## Country

`CCountry`, vftable `0x11C1BA8`, base `CPersistent` (**RTTI**). Read in
`GameClasses/CCountry.cpp` and `Gui/OrderOfBattle.cpp`.

| Offset | Holds | |
| --- | --- | --- |
| +0x180 | flags, a tree four bytes past the vftable | mem, used |
| +0x1AC | variables, the same shape | mem, used |
| +0x648 | static modifiers, a list | mem, used |
| +0xBAC | **its units** - and not only the top level ones, so the tree has to be walked | used |
| +0xDA8 | an array read for country statistics | mem, used |

## Tools

| Script | For |
| --- | --- |
| `vtable.py` | classes' vtables side by side, to see what a subclass actually changes |
| `findRefs.py` | the code that writes a vftable (its constructors), and who calls a function |
| `findInstances.py` | live objects of a class, by scanning for its vftable |
| `dumpStruct.py` | an object's fields with a guess at what each value is |
| `watch.py`, `watchCombat.py` | what changes in an object while the game runs |
| `combatHistory.py` | the game's own combat history, decoded |
| `hoi3.py` | the RTTI export, tick decoding, and the helpers the rest use |

The RTTI export itself is at `C:\Users\David\GitHub\OpenHOI3\OpenHOI3\docs` - a class
hierarchy as text, and the full records as JSON.
