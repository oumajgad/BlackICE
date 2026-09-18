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
| **named** | The game's own name for it: a Lua accessor whose whole body reads this one field (`lea eax,[ecx+N]; ret` and the like), recovered by `ghidra/luabindExtract.py`. Certain about the offset and the game's name; says no more about the meaning than the name does. |

Addresses are relative to the module, the way BiceLib uses them. The RTTI export writes
them absolute against an image base of `0x400000`, so subtract that when copying one
across. `hoi3.py` does it for you.

## Anchors

Everything reachable starts from one global.

```
[MODULE + 0x1689790]  CCurrentGameState*        read, and it is what sessionActive() reads
```

**In code: `BiceLib/GameClasses/CCurrentGameState.hpp`**, which owns the anchor and the
offsets below and hands the pointer out through `current()`. Nothing else should spell
the global out.

**`CCurrentGameState`** - vftable `0x11CF674`, `0xda8` bytes, constructed at
`0x27D070` (**read**: both callers of the combat recorder allocate `0xda8`, call that
constructor and store the result in the global). It is created lazily, and **exists at
the main menu** - see `present-hook-must-not-call-game-lua` and `README-imgui.md`. Its
being non-null proves nothing about a game being loaded.

| Offset | Holds | |
| --- | --- | --- |
| +0xB3C | something with vftable `0x11C9BEC` | read |
| +0xB5C | **`CCombatManager`, embedded** | read |
| +0xB74 | the `CCombatHistory` inside it (`+0xB5C` + `0x18`); the constructor writes the two vftables at `+0xB5C` and `+0xB74` | read |
| +0xBDC | **the current tick** | read, and used |
| +0xBE8 | **the `CInGameIdler`** - the same address the vftable scan finds, and the object there carries its vftable | seen |
| +0xBCC | one entry per country id, non zero for one somebody is playing. From `../../../mem`, and the played country's entry reads 1 | mem, seen |
| +0xC30 | the player's tag: three characters and a NUL, then the id. **Not +0x18** - that is a tag field holding `---` in a running game, and the `../../../mem` note recording the player there reads its fields without dereferencing the global | seen |
| +0xD9D | checked before an autosave and has to be zero. It is zero in an ordinary running game, so it is not "a session is loaded" | read |

## Conventions the game keeps to

- **`std::string` is MSVC's**: sixteen bytes of buffer, or a pointer where the string is
  longer than fifteen; the length is at +0x10. `utils::getCString` handles both.
- **Text is Windows-1252**, not UTF-8. Run anything read out of the game through
  `Text::toUtf8` or umlauts come out as `?`.
- **A country tag is three characters, a NUL, then the country id** - eight bytes,
  wherever one appears.
- **Objects held by value.** Much of what a class holds is another object in place -
  a tag, a list, a goods pool, a modifier - and BiceLib writes that as two offsets: the
  object's in its owner (`CCountry::Offsets::tag`) and the field's in the object
  (`CCountryTag::Offsets::id`), each in its own header. Which classes, and how each was
  established, is under *Held by value* below.
- **Two list shapes.** Standalone nodes of `{ data +0x00, next +0x08 }`, and the
  game's `CList<T>` of `{ first, last, count }`, held by value (`HDS::ListOffsets`) -
  `CUnit` derives from one at +0x38, which is why its regiments are read from there.
- **Vector-ish triples** of `{ begin, end, capacity }` and often a byte after them.
  `CCombatant` has several in a row. An offset first read as a count may be the third
  pointer of one of these - and three words and a byte is also exactly a `CList`, which
  counts rather than ends, so look at what the third word holds.
- **Dates are ticks**: hours since `43800000`, years of 365 days with no leap day.
  `utils::gameTickToDate` and `utils::dateToGameTick`, `hoi3.tickToDate` here.
- **`+0x04` is `0x18d` (397) on nearly every object.** Metadata on a shared base. It is
  not a date and not a count; ignore it.

## Combat

The whole of how these were found, and what is still open, is in `FINDINGS-combat.md`.
**In code: `BiceLib/GameClasses/CCombat.hpp`** (the combats and combatants) and
`CCombatManager.hpp`, which are the authority for the offsets; `GameState/CombatLog.cpp`
reads them.

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
constructor at `0x2F340`. That is why BiceLib keeps its own record.

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
at `0x164550` which all of them run (**read**) - so they are at the same offsets
whatever the combatant is. A bombing raid bears that out: its bomber and target
combatants both gave up their country and their losses at these offsets (**seen**).

| Offset | Holds | |
| --- | --- | --- |
| +0x3c | back to the combat | mem |
| +0x28 | a `CList`, by the constructor's shape; what it holds is not known | read |
| +0x3c | back to the combat; the constructor stores ecx here | mem, seen |
| +0x40 | the units on this side, by `mem` - which took it for a vector, but the constructor sets it up as a `CList` | mem, read |
| +0x54 | the country list the game takes a tag from, a `CList` whose first node starts with a `CCountryTag` - **emptied on the beaten side** | read |
| +0x5c | its count: zero when the list is empty, which is how the game decides to write `---` | read |
| +0x64 | the side's own countries, a `CList` of the same kind, **kept** when +0x54 is emptied - where the loser's name comes from | read, seen |
| +0x74, +0x78 | **the men on this side, per subunit type** - summed over a thousand it is the "out of 25700 troops" the battle message prints, and the game builds it exactly that way at 0x1745F4. Only men in a land or naval fight: an air combat counts subunits here, a bombing raid leaves it empty | read, seen |
| +0x84 | **losses, in thousandths** - 21 losses read back as 21900, and the message prints this over a thousand as its casualties. A subunit destroyed outright adds exactly 1000 | seen, read |
| +0x88, +0x8c | **subunits destroyed, per type** - a vector with an entry per kind of brigade, ship or plane, each holding 1000 per one destroyed. Its sum over a thousand is how many were lost outright. Nothing in BiceLib reads it | read |
| +0x98 | damage short of destruction, per type, the same shape | read |

`CLandCombatant` is the outlier in behaviour, fifteen slots of its own against the
others' five; that is code, not layout. `CNavalCombatant` is at least `0x10b8` bytes -
its constructor writes +0x10b4 (**read**).

### Where it is recorded

`0x2F960` appends an entry, and **its second argument is the live `CCombat`** - which
is what BiceLib hooks. Called from `0x3170B` (the manager's own code) and
`0x1D2904` (among the `CArmy`, `CNavy` and `CAir` virtuals, so unit code). Both fetch
the game state and append to the same history at `gameState + 0xB74`. **read.**

`0x34140` builds an entry on the stack and goes through a virtual, and a second one the same way further in;
reached from `CCombatHistory`'s own, so almost certainly save and load rather than
gameplay.

## Units

BiceLib keeps these in `GameClasses/CUnit.hpp`, which is the authority for the offsets.
`GameState/OrderOfBattle.cpp` reads them but no longer holds a copy of its own.

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

### What a unit is, by vtable slot

Slots 15, 16 and 17 of `CArmy`, `CNavy` and `CAir` are `isLand`, `isNaval` and `isAir`
- three predicates where each class has the real one and stubs for the other two:

| | slot 15 (+0x3C) | slot 16 (+0x40) | slot 17 (+0x44) |
| --- | --- | --- | --- |
| `CArmy` | `mov al,1; ret` | `xor al,al; ret` | `xor al,al; ret` |
| `CNavy` | `xor al,al; ret` | `mov al,1; ret` | `xor al,al; ret` |
| `CAir` | `xor al,al; ret` | `xor al,al; ret` | `mov al,1; ret` |

Worth knowing when a breakpoint says the game is reading a unit's vftable: it is
usually one of these rather than anything interesting (**used**, disassembly).

### Strength, and the field that is not it

A regiment's strength is **+0x5C** (**read**, four ways): the unit's supply consumption
scales it against the definition's `max_strength` (`0x1BB6CB`), the builder fills it from
`max_strength` times a percentage when a regiment is made (`0x484F7B`), `CUnit`'s slot 21
averages it over the regiments, and the enemy strength counter (`0x1D67C0`) adds it up over
the enemy units in a province.

**+0x30 is a ceiling, not the strength**: the builder sets it to that same starting figure
and afterwards only ever raises it to the strength, never lowers it (`0x484F7E`), and
`CUnit`'s slot 24 totals it without averaging. BiceLib read +0x30 as the strength until
2026-09-16; at full strength the two are equal, which is why the OOB browser looked right.
**The scale is the same either way**, so the tens and thousandths `Oob::strengthOf` applies
still hold.

Three `CUnit` slots go with it, shared by all four unit classes and each answering a
CFixedPoint through a hidden return pointer (**read**): **slot 20** the average
organisation, **slot 21** the average strength, **slot 24** the total of the +0x30
ceilings. A regiment's own slot 12 answers its maximum strength: the definition's
`max_strength`, scaled by the owner's `RESERVES_PENALTY_SIZE` modifier where the regiment's
reserve byte at +0xA4 is set, floored at a global minimum.

### Supply and fuel consumption

`CSubUnitDefinition`'s `supply_consumption` (+0x110) and `fuel_consumption` (+0x114)
are **base figures for one sub unit**. What the game displays for a unit is a good deal
more, and BiceLib calls the game's own functions for it rather than reimplementing
(**used**, disassembly, and the OOB browser matches the game's tooltip):

| RVA | Takes | Gives |
| --- | --- | --- |
| `0x1BB560` | `(CUnit*, int* out, bool withoutLeaders)`, stdcall, `ret 0xC` | supply, in thousandths, through `out` |
| `0x1BB7A0` | unit in **eax**, `(int* out, bool withoutLeaders)` on the stack, `ret 8` | fuel, the same way |

Both return the `out` pointer in eax. The per regiment versions are `0x1AD0F0` (supply),
which takes the regiment in **esi**, and `0x1AD300` (fuel), which takes it in **eax**;
both take `int* out` on the stack and answer it in eax.

What the unit level pair does, which is why the figure differs from the sum of the base
values (**read**, all four functions):

- **A land unit on a strategic redeployment consumes nothing**: where the unit is land
  (slot 15) and its order's slot 16 answers `0x5A4` - the id `CStrategicRedeploymentOrder`
  carries, see below - it writes 0 and returns. Fuel only; supply is still consumed.
- starts a potency at **1000** and adds the country's global modifier
  `SUPPLY_CONSUMPTION` (entry 49, so `+0x188` of the modifier's values). Fuel uses the
  supply modifier too - there is no fuel one here.
- walks **up** the OOB by `higher_oob_unit_ptr` to the unit whose `oob_level` is 1 - the
  army group - and **subtracts** that leader's `skill` (`CLeader +0x70`) times `Define50`
  (`0x168879C`), times how much of that HQ's command reaches this unit (`0x1B6980`, below).
  A better army group commander lowers what everything under it consumes.
- **adds** the chain of command's own effect of type 2 (`0x1D1120`), which is the same
  reach maths over every HQ above the unit plus the unit's leader's traits, and floors the
  potency at 0.
- then, per regiment: `potency + regiment[+0xCC] x Define10` (`0x168873C`), times the
  definition's base figure, over 1000. `+0xCC` is a cached total the game recomputes at
  `0x1ABFC0` by summing the second dword of every element of the list at `+0x84`; each point
  is another 1% of consumption. **What that list holds has not been established.**

Both constants are **defines whose names are not known**. `Define10` is 10 and `Define50`
is 50, each the floor of a float - 10.5 and 50.5 - taken at startup, so thousandths: 0.010
and 0.050. Neither is only about consumption. Ten places read `Define10`, and where they
can be read at all it is a floor on a multiplier (`0x1C30B6` clamps `1000 + x` up to it
before scaling `max_strength`), a threshold, or an additive base. `Define50` is read in
five, and the three outside the consumption pair compare it against a unit's
`supply_received_percentage` (+0xFC) and `fuel_received_percentage` (+0x100) - a unit short
of either. `0x16886E8` is a third global holding 50 from the same float, read only by the
two per regiment functions. Naming them for their part in consumption would say more than
the code does, so they are named for what they hold.
- supply additionally scales each regiment by how much of its `max_strength` (+0xEC) is
  left, except for naval units (slot 16), which are not scaled that way. Fuel does not
  scale by strength at all.

`withoutLeaders` skips the potency work and leaves it at 1000, which gives the base figure
the unit inspector shows. It does **not** skip the redeployment check.

Two helpers the pair shares, both answering thousandths through an `out` pointer and both
named by BiceLib (**read**):

| RVA | Takes | Gives |
| --- | --- | --- |
| `0x1B67B0` | `(CUnit* unit, int* out, CUnit* hq)`, stdcall, `ret 0xC` | how much of that one HQ reaches the unit |
| `0x1B6980` | unit in **eax**, `(int* out, int hqLevel)`, `ret 8` | the same compounded over every HQ up to that level |
| `0x1D1120` | `this` unit, `(int* out, int effectType)`, `ret 8` | that effect from the HQs above it and its leader's traits |

The reach is a real command range, not a flat number: 1000 at the HQ itself, falling with
the square of the distance between the unit's province and the HQ's (province `+0x2C` and
`+0x30`, wrapped by `CMap + 0x2A74`) against a radius from the HQ's first regiment's
definition `+0x180` scaled by a define picked by the HQ's `oob_level` - `CDefines + 0xAC`
then `+0x21C`, `+0x218`, `+0x214`, `+0x210` for theatre, army group, army and corps. Those
four are `RADIO_THEATHRE_LEADER_DISTANCE`, `RADIO_ARMYGROUP_LEADER_DISTANCE`,
`RADIO_ARMY_LEADER_DISTANCE` and `RADIO_CORPS_LEADER_DISTANCE` in `defines.lua`: four
consecutive defines there, in that order, and the two after them are the pair this file
already records at `+0x220` and `+0x224` for the supply capacity
(`OWNED_AND_CONTROLLED_THROUGHPUT_CAP_BONUS` and `INFRA_THROUGHPUT_IMPACT`). The names
are **inferred** from that alignment and from what the code does with the values; the
block's offsets do not count out exactly against this mod's `defines.lua`, so no single
entry is proof on its own.

`CDefines` itself comes from `GetDefines` (`0x45D90`), which makes it on first use and
keeps it at `0x1686040`.

### Orders, and the id each kind answers

A unit's order is `CUnit +0xB0`, a `COrder*`. `COrder` leaves **slot 16** pure virtual and
every concrete order fills it with `mov eax, <id>; ret` - a constant that says which kind
of order it is. What `COrder`'s own table holds there is the CRT's `_purecall` (`0x7961D5`),
which calls the installed handler if there is one and otherwise ends the process with R6025,
"pure virtual function call". Nothing reaches it in a working game. That is how code that has only a `COrder*` tells them apart, and the
executable compares against `0x5A4` in nine places.

The ids, read straight out of each class's vftable (**read**):

| Id | Order | | Id | Order |
| --- | --- | --- | --- | --- |
| `0x18D` | `CNullOrder` | | `0x6DE` | `CRebaseOrder` |
| `0x255` | `CMoveOrder` | | `0x6E5` | `CJoinFleetOrder` |
| `0x398` | `CReserveOrder` | | `0x6E6` | `CNavalInterceptOrder` |
| `0x3A5` | `CNavalInvasionOrder` | | `0x6E7` | `CNavalSortieOrder` |
| `0x3A8` | `CNavalTransportOrder` | | `0x6E8` | `CConvoyEscortOrder` |
| `0x42E` | `CPatrolOrder` | | `0x6E9` | `CConvoyRaid` |
| `0x4E5` | `CSupportAttackOrder` | | `0x6F9` | `CStrategicBombOrder` |
| `0x56C` | `CCarrierProtection` | | `0x6FA` | `CAirPatrol` |
| `0x570` | `CParadropMission` | | `0x6FB` | `CGroundAttackOrder` |
| `0x573` | `CRebaseToCarrierMission` | | `0x6FC` | `CAirInterdictionOrder` |
| `0x574` | `CRebaseAirOrder` | | `0x6FD` | `CBombLogisiticsOrder` |
| `0x579` | `CNukeMission` | | `0x6FE` | `CBombRunwayOrder` |
| `0x57A` | `CTransportSuppliesOrder` | | `0x6FF` | `CBombInstallationOrder` |
| `0x592` | `CAirConvoyRaid` | | `0x700` | `CNavalStrikeOrder` |
| **`0x5A4`** | **`CStrategicRedeploymentOrder`** | | `0x701` | `CPortStrikeOrder` |
| | | | `0x716` | `CAirReserveOrder` |
| | | | `0x717` | `CJoinAirOrder` |
| | | | `0x718` | `CAirInterceptOrder` |

What the numbers themselves are is not established - they are not sequential, and the
same value turns up as an id stored at `+4` on other persistent objects, so they look like
one registry of class ids rather than an order enum. The findings name the slot `GetTypeId`
and that is BiceLib's name for it.

The sub units a unit holds are `CRegiment` (`GameClasses/CRegiment.hpp`): **strength at
+0x5C**, organisation at +0x60 and the name at +0x68, all **used** by the OOB browser.
Air and naval sub units are read through the same three and have never looked wrong,
but only the land case is known to be this class.

**What kind of regiment it is** is two hops, and neither of them is the name. The name
at +0x68 is historical and unique to the regiment - 10400 distinct across 10860
regiments of a running game, so counting them says nothing. Instead +0x58 is a
`CSubUnitDefinition*`, **used** by the OOB report, and the key string at +0x08 of that
is the type as the mod's files spell it: `artillery_brigade`, `interceptor`,
`destroyer_actual`.

The definition is per regiment, not per type - it holds that regiment's stats with its
own country's technology applied - so the *pointer* identifies a regiment and only the
key identifies a type. Found by taking every `CSubUnitDefinition` RTTI knows of and
looking for the offset in a regiment holding one: +0x58 did, 4005 of 4005 sampled.
Every branch carries a key: 7496 regiments across land, air and naval, none blank.
Not to be confused with `sprite` at +0x198, which is the picture and has four values
for the whole land branch.

Also in `GameClasses/`, all **mem** unless marked otherwise, and each header its own
authority: `CLeader.hpp`, `CMapProvince.hpp` (province id at +0xD0 is **used** by the
combat capture and the OOB browser), `CSubUnitDefinition.hpp`, `CTerrain.cpp` (vftable
`0x11C0764`, **used**).

`CSubUnitDefinition`'s kind flags are **named**, all bytes: `IsRegiment` +0x2D,
`IsShip` +0x2E (recorded as unknown until then), `IsCapitalShip` +0x2F, `IsTransport`
+0x30, `IsSub` +0x31, `IsCag` +0x32, `IsBuildable` +0x36, `IsBomber` +0x37,
`CanParadrop` +0x38; and `GetIndex` +0x24 is the type index the combat vectors are
indexed by.

**Most of a definition is read through accessors that answer a `CFixedPoint` by value**, and
those have a frame around them - `push ebp; mov ebp,esp; mov ecx,[ecx+N]; mov eax,[ebp+8];
mov [eax],ecx; pop ebp; ret 4` - so the two instruction accessor rule never saw them.
`luabindExtract.py` reads that shape too since 2026-09-18, which named **33 more fields** off
the game's own accessors, 9 of them here: `CompletionSize` +0xE4, `CombatWidth` +0xE8,
`DefaultStrength` +0xEC (the unit files' `max_strength`), `BuildCostIC` +0xF8, `BuildCostMP`
+0xFC, `BuildTime` +0x100, `Defensivness` +0x11C, `Toughness` +0x120, `Softness` +0x124. The
rest are on `CCountry` (`Dissent`, `NationalUnity`, `Manpower`, `TotalLeadership`,
`Neutrality`, `OfficerRatio` and four more), `CProvince` (`MaxInfrastructure`),
`CProvinceBuilding` (`Max`, `Current`), `CTheatre` (`Priority`), `CConstruction` (`Cost`, which
BiceLib had already) and five other classes.

**`IsCarrier` is not a flag**: `0x94650` is `cmp [ecx+0x190], 0; setg al`, and **+0x190 is
`carrier_size`** - how many air groups the ship carries, x1000 like every other figure on
the definition. **Read live**, and it is exact: of the 1643 keys in a running game only the
carriers have anything there, and each matches its unit file. `carrier`, `command_carrier`
and the fifteen `CV_*` uniques hold 2000 for `carrier_size = 2`; `light_carrier` 1000 for 1;
**`escort_carrier` 0**, because BlackICE gives it `carrier_size = 0` - so by the game's own
test an escort carrier is not a carrier. (The instances with `IsShip` clear are objects the
scan picks up that the game has not filled in; the figures above are the ones where it is
set.)

**`CMapProvince` has two vftables**: `0x11BEBF8` at +0x0 and `0x11BEC1C` at +0x8.
`CMapProvince::VFTable::CMapProvince` is the +0x8 one - what the selection holds a
pointer to - so a province pointer's first dword never matches it; that is `Primary`.
**RTTI**, and the primary checked **live** against both province arrays.

## Provinces, goods and supply

**In code: `BiceLib/GameClasses/CMapProvince.hpp` and `CGoodsPool.hpp`**, which are the
authority for the offsets. A good in a province is two offsets added: the pool's from
`CMapProvince::Offsets`, the good's from `CGoodsPool::Goods`. This is where they came from.

`CGoodsPool`, vftable `0x11C1BD4` (**RTTI**; `../../../mem` has `0x11C1BD0`, four bytes
short), `0x24` bytes: seven amounts in thousandths from +0x8, in the order supplies,
fuel, money, crude oil, metal, energy, rare materials. **Read** out of the pool's own
save reader (slot 4, `0x123A90`), which stores each key into its slot, with the keys'
token ids matched to their strings where the game registers them.

Every province embeds **nine** of them, at the same offsets in all 14,189 (**seen**).
The province writer (`0x95020`) saves seven and names them (**read**):

| Offset | Save key | Holds | |
| --- | --- | --- | --- |
| +0x15C | `pool` | what is in the province; **in the capital, the national stockpile** | read, seen |
| +0x180 | - | the pool as the last daily pass left it; caps the next day's outflow | read |
| +0x1A4 / +0x1A8 | `last_drawn` / `drawn` | **pointers**, into +0x1AC and +0x1D0 | read, seen |
| +0x1F4 / +0x1F8 | `last_throughput` / `throughput` | **pointers**, into +0x1FC and +0x220 | read, seen |
| +0x244 | - | what the units there need today, supplies and fuel | read; the name inferred |
| +0x268 | `current_producing` | resources it yields now - what the custom map mode shades by | read, seen |
| +0x28C | `max_producing` | resources it could yield | read, seen |

The two pointer pairs are **double buffers**: the daily supply pass (`0x2872D0`) swaps
each pair at the start of the day, then zeroes and refills today's. Read them through
the pointers; which buffer is today's depends on the day. **Seen** across a midnight,
snapshotting every province hour by hour: both pairs flipped everywhere at once, the old
today's buffer became `last_` unchanged, and between midnights neither buffer, `need`
nor `last_pool` moved. `current_producing` does move: resources step up towards
`max_producing` after midnight, and its supply and fuel slots hold something only
during the midnight processing.

**Networks cut off from their capital** (their depot is not the capital) were watched
for 21 game days (**seen**): no resources in any of their throughput, and their
production arriving in the capital's pool every midnight anyway. **Convoys carry it.**
The day's total is `CCountry + 0x74C`, a pool (**seen**, matched against three
capitals).

### Convoys

**In code: `BiceLib/GameClasses/CConvoy.hpp`**, and the list in `CCountry.hpp`.

`CConvoy`, vftable `0x11C0D44`, base `CReferenceObject` (**RTTI**). A country's convoys
are the list at `CCountry + 0xA0` / `+0xA4` / `+0xA8`, nodes `{ data, prev, next }`
(**seen**: all 108 lists together hold exactly the 339 instances a scan finds, each in
its owner's). The saved fields come out of the convoy's save writer, `0xC5600`
(**read**): `daily` (a pool, +0x38), `ship` (a seven-int goods mask, +0x5C), `convoys`
(transports assigned, +0x98), `escorts` (+0x9C), `trade` / `lend_lease` (bytes +0xA0 /
+0xA1), `path` (a list at +0xB0, province ids), `start` / `end` (+0xC0 / +0xC4),
`start_date` / `last_attack` (+0xC8 / +0xCC).

Two unsaved fields, **seen** over four and a half game days of hourly snapshots: +0x90
is the transports wanted (steady while +0x98 went up and down; the game's
`GetDesiredTransports`, **named**), and +0x6C is a pool of
what the loading end produces in a day - the loading network's `current_producing`
summed, exactly, on 322 of 361 convoys. It is not a second buffer of `daily`. Every
convoy field that changes does so in the hour after midnight. +0x94, which sits where
an escorts wanted would, is the game's `GetDesiredEscorts` (**named**), and the `trade`
byte at +0xA0 is its `IsForTradeRoute` (**named**).

The goods mask sorts them: 202 supply convoys, 58 resource convoys, 79 carrying money
and one good - trade, presumably. **A cut off network's production waits in the
loading port's pool for its convoy** (**seen**): in 53 of the 58 resource ports the
stock is exactly one day's load, and Holland's resource income is its resource
convoys' loads added up. A Danish convoy that wanted one transport and mostly had none
showed the pile up: its port's stock grew by a day's load a day, and the one day a
transport was assigned the convoy took the whole backlog - `daily` read five days'
worth - and the port dropped back to one day's.

`CCountry:GetPool()` (`0xF4DE0`) answers the capital's `pool` unless the byte at
`country + 0x95` is set (**read**) - which is the game's `IsGovernmentInExile`
(**named**), so an exiled government keeps its stockpile on the country at `+0x9F8`. All 100 capitals of a running game hold money and
resources there, and none of the country's own 23 pools holds anything like the
stockpile (**seen**). The capital is `country + 0xE24`, a province id (**read**, from
`0x2F100`).

The pass itself, **read**: it walks `CCurrentGameState + 0x54`, every province sorted by
distance from its depot, farthest first (**seen**). Each province tops its pool up
towards `SUPPLYPOOL_DAYS` (35) of its need, by taking from the neighbours one step closer
to its depot (`+0x48` the same depot, `+0x4C` a smaller distance); what it cannot get is
added to those neighbours' `drawn`, so they ask for it on their turn. A good taken counts
on the giver as both drawn and throughput. The per province figures come in as four arrays
the caller fills and discards (**read**): capacity from `0x9DD00`, supply need from
`0x9E020`, loss from `0x9DE80`, fuel need from the same loop. Only the capacity function
has been read through - the province's local modifiers, two defines and the controller's
modifiers, unlimited where the byte at `+0x2B0` is set - and BiceLib calls it for the
custom map mode's line load.

So **throughput ÷ drawn does not measure shortfall**: a province's own request is in its
`drawn`, but its `throughput` only counts what others take from it, so every line end reads
0 % (**seen**: 530 of 1,040 provinces with units, in peacetime).

Along the way: `+0x68` is a `CWeather`, saved as `weather` (**read**), and the
`+0xD4` path node is a `CProvinceTemplate` in every province (**RTTI**, **seen**).
`+0xFC` is the province's `CProvinceModifier` (**read**, see *Modifiers*), and `+0x32C` /
`+0x334` its owner and controller, `CCountryTag`s (**named**: `GetOwner`,
`GetController`).

`../../../mem`'s `CMapProvince.py` reads `required_supply` / `required_fuel` at +0x1B4 /
+0x1B8 and `yesterday_required_supply` / `_fuel` at +0x1D4 / +0x1DC. Those are the two
`drawn` buffers, read by offset, so which one is today's changes every day.
`yesterday_required_supply` is also four bytes short: +0x1D4 is the `0x18d`, and the
supplies are at +0x1D8.

## Held by value

The classes BiceLib reads inside other objects, each with its own header, so an owner
records only where the object starts.

| Class | Header | Held in | |
| --- | --- | --- | --- |
| `CCountryTag`, 8 bytes: letters +0x0, id +0x4 | `CCountryTag.hpp` | a country (twice), a province's owner and controller, a unit's and a convoy's owner, the player in the game state | named (`GetIndex` +0x4, `GetCountryTag`, `GetOwner`, `GetController`), used |
| `CList<T>`, 16 bytes: first, last, count and a byte | `HoiDataStructures.hpp`, `HDS::ListOffsets` | a country's convoys, units and leaders; a unit's regiments and children; a leader's traits; a convoy's path; the selection | named (`OwnedProvinces` +0xCF0 with `NumberOfOwnedProvinces` +0xCF8, `AirBases` +0xD70 with `NumOfAirfields` +0xD78, a province's `Units` +0x2B8 with `NumberOfUnits` +0x2C0), RTTI (the `__CList` bases), read (the country's constructor clears three dwords and a byte for each of its lists, 0x10 apart), seen |
| `CGoodsPool` | `CGoodsPool.hpp` | nine in a province, two in a convoy, 23 in a country | read, seen |
| `CModifier` | `CModifier.hpp` | a country's global modifier +0xD90, a province's modifier +0xFC | read, named |
| `CFlags`, `CVariables` | `CFlags.hpp` | a country, +0x180 and +0x1AC | named, used |
| `CCombatManager` and the `CCombatHistory` in it | `CCombatManager.hpp` | the game state, +0xB5C | read |

### Modifiers

`CModifier`, vftable `0x11BC4F8`, base `CPersistent` (**RTTI**), with laws, ministers,
ideologies, traits and the province's `CProvinceModifier` (`0x11BC530`) deriving from it.
It does not hold its values: **+0x18 points at an array of `{ CFixedPoint value,
CModifierDefinition* }` pairs, one per modifier type**. Read off the game's own
`CModifier::GetValue` (`0x179E0`), which is `[this+0x18][type*8]` and nothing more
(**read**). The type is the `ModifierType` enum the Lua API registers on `CModifier`, so
its values give each entry its game name (**named**): `+0x60` is 12,
`_MODIFIER_INFRASTRUCTURE_`; `+0x78` is 15, `_MODIFIER_IC_`; `+0x80` is 16,
`_MODIFIER_LOCAL_IC_`.

Where the two BiceLib reads are (**read**): `CCountry::GetGlobalModifier` (`0xDFAF0`) is
`lea eax,[ecx+0xD90]`, and the country's constructor calls `CModifier`'s constructor
(`0x593F0`) on `+0xD90`; the province's constructor does the same on `+0xFC` (at
`0x94848`), then writes the `CProvinceModifier` vftable and stores the province at
`+0x2C` of it. `CModifier`'s constructor zeroes `+0x8`..`+0x10` and `+0x18`..`+0x20`
and sets the `0x18d`.

That makes `[province+0x114]`, which the infrastructure map mode, the supply capacity
function and the offmap IC fix all read, the province modifier's values pointer, and
`CCountry +0xDA8` the country's. BiceLib used to spell both out as bare arrays - the
province one as `BuildingOffsets`, though it holds no buildings.

**Every entry is named now** (**read live**, 2026-09-18). Each entry's
`CModifierDefinition` carries the modifier's key at `+0x4`, so walking a country's array and
reading them gives the game's own name for all 143 - the sixty the Lua API never registered
included. Twelve countries agree entry for entry, and the array's length is confirmed the
same way: entry 143 has no definition and the next country's begins two entries later.

The Lua names and the definition keys disagree in five places. Four are the manpower group,
where the keys call 3 and 4 `MANPOWER` and use `LOCAL_MANPOWER` and `GLOBAL_MANPOWER` for 5
and 6, while Lua puts those two names on 3 and 4 and calls 5 and 6 the `_MODIFIER_`
variants; the fifth is 75, `LOCAL_ANTI_AIR` to Lua and `MODIFIER_LOCAL_AA` by its key.
`CModifier.hpp` keeps the Lua name where there is one and notes the key beside it.

What 83 up turned out to be: `NEUTRALITY`, the resource pair, **`REINFORCEMENT_BONUS` (86)**,
five build speeds, `FUEL_CONVERSION`, `TRICKLEBACK`, the attack pair, `NUKE_RESEARCH`, the
weather effects, `LEADER_DEFENCE`, the intel boosts, `STRATEGIC_RESOURCE_EFFICIENCY`,
`LOCAL_UNIT_SPEED` - and from 108 to 139 one `*_eff` per order type, in the same order as the
order classes, then three `suseptibility_*`.

**The findings type the array as a structure**, `CModifierValues`, 143 named
`CModifierEntry`s, so a read decompiles as a field rather than an index:
`country->GlobalModifier.values->REINFORCEMENT_BONUS.value` where it used to be
`values[0x56].value`.

## Movement and routing

Worked out for a strategic redeployment that preferred good infrastructure, which was
**abandoned**: replacing the route finder's step cost changed nothing about the route taken,
in two tests. The layout stands; the conclusions about what decides a route do not. All of
it, and what was tried, is in `FINDINGS-redeploy.md`. None of it is used.

| Class | vftable | |
| --- | --- | --- |
| `CPathFind` | `0x11BE414` | RTTI, 4 slots |
| `CSafePathFind` | `0x11C884C` | RTTI, overrides slot 2 |
| `CVerySafePathFind` | `0x11C5B6C` | RTTI, overrides slot 2 |
| `CPlannedPathFind` | `0x11C8860` | RTTI, overrides slots 1, 2 |
| `CSafeNavalPathFind` | `0x11C7304` | RTTI, overrides slot 0 |
| `CMoveCommand` | `0x11C8C1C` | RTTI; slot 6 routes the unit |
| `CStrategicRedeploymentOrder` | `0x11C5ADC` | RTTI, 35 slots |

Headers: `CPathFind.hpp`, `CMoveCommand.hpp`, `CStrategicRedeploymentOrder.hpp`. Two
province facts came out of it, both **live**: a province's path node, holding one edge per
neighbour, is at `CMapProvince + 0xD4`; and `CMap + 0x2200` is an array of every province
by id, the same pointers as the game state's.

## Country

`CCountry`, vftable `0x11C1BA8`, base `CPersistent` (**RTTI**). Read in
`GameClasses/CCountry.cpp` and `GameState/OrderOfBattle.cpp`.

| Offset | Holds | |
| --- | --- | --- |
| +0x180 | `CFlags`, held by value (`GetFlags`); a tree, its root at +0x4 of it | named, used |
| +0x1AC | `CVariables`, the same shape (`GetVariables`) | named, used |
| +0x1E4 | a `CCountryTag`, the one BiceLib reads the tag and id from | mem, used |
| +0x648 | static modifiers, a list | mem, used |
| +0x95 | `IsGovernmentInExile`, a bool; decides whose pool `GetPool` answers (see Provinces) | named, read |
| +0xA0 | its convoys, a `CList<CConvoy*>` (`GetConvoys`) | seen, named |
| +0x604 / +0x60C | `GetTotalIC` / `GetMaxIC`; the offmap IC fix writes the first | named, used |
| +0x74C | `TotalProduced`, a goods pool: a day's resource income | seen, named |
| +0x770 ... +0x890 | more goods pools: `HomeProduced` +0x770, `ConvoyedIn` +0x794, `ConvoyedOut` +0x7B8, `TradedAway` +0x7DC, `TradedAwaySansAlliedSupply` +0x800, `TradedFor` +0x86C, `TradedForSansAlliedSupply` +0x890 | named |
| +0xBAC | **its units** - and not only the top level ones, so the tree has to be walked. The start of the `CUnitList` `GetUnits` answers | used, named |
| +0xCA4 | a `CCountryTag`, the one `GetCountryTag` answers; the tag at +0x1E4 is a second copy, for a reason not established. The offmap IC hook reads its id half, +0xCA8 | named, used |
| +0xD90 | **the global modifier**, a `CModifier` held by value (`GetGlobalModifier`; the constructor builds it there). Its values pointer is `+0xDA8`, which is what `../../../mem` and BiceLib used to read as a bare array; the offmap IC fix writes entry `IC` of it | named, read, used |
| +0xE24 | the capital as a province id - by the game's name `GetActingCapital`, where the government sits now | read, named |
| +0xF40 | what it is building, a `CList<CConstruction*>` (`GetConstructions`). `GetUsedIC` (`0xF4B60`) walks it and adds up each construction's cost, which is `CConstruction +0x30` - the game's `GetCost` (`0x837C0`), a `CFixedPoint`. Its `GetSize` is `+0x40` | named, read |

### Is that country an enemy

`CCountry::IsEnemy` is **two overloads**, not one function built twice. The Lua API says so
itself: its `.def` casts the member pointer,
`(bool(CCountry::*)(const CCountryTag&) const)&CCountry::IsEnemy`, which is only needed
where the name is ambiguous - and nearly every other `.def` in that file is a bare
`&Class::Method`. Both are live, with 112 and 101 call sites (**read**).

The one the Lua API registers, `0x2F1B0`, takes a tag: it answers true when the diplomacy status for that country
(`CCountry +0xE28`, indexed by the country's id) has a flag set at `+0x20`, and always for
the rebels tag `REB`, on either side.

`0x2F210` is the same test with **a province as well**, and one further branch: where the
status alone says no, it reads `+0x24` of the status and asks the province about it. The
compiler gave it a register convention - **the country in `esi`, the tag in `edx`, the
province in `edi`** - so it cannot be called like an ordinary function and no signature is
recorded for it. Why only this one: the registered overload has its address taken, stored
into luabind's registration object at `0x4F8838`, so it had to keep a callable `__thiscall`
form; this one's address is taken nowhere in the image, which left the compiler free to
pass its arguments wherever it liked.

Both are used to decide who a unit may fight. `CUnit`'s vtable slot 19 asks it about the
province it is looking at, and the enemy strength counters ask it about every unit standing
there: `0x1D67C0` over the land units, `0x5D69C0` over the air ones (slots 16 and 17 tell
them apart). Each adds up the strength (`CRegiment +0x5C`) of every regiment of every enemy
unit in a province's `Units` list and answers it over a thousand. They take the list in
`eax` with the asking country's tag on the stack, and clean it themselves (`ret 8`).

**Written out with where each argument is passed** (`@ESI`, `@stack:4`), so the decompiler
shows a call to one with the right values in it. Without that it reads the call as an
ordinary one and prints whatever happens to be in the standard places - for `IsEnemy` that
came out as `IsEnemy(g_CCountryDataBase->countries_first, tag)`, which says the first
country in the array rather than the province's controller.

### The country database

**In code: `BiceLib/GameClasses/CCountryDataBase.hpp`**; nothing reads it yet.

`CCountryDataBase`, `0x57C` bytes, **no vftable** - so not in the RTTI export, and only a
`DAT_` in a disassembler. Its pointer is `module + 0x16855A4`, null until the first use
creates it (**read**: `new(0x57C)`, constructor `0x24D0`, store). The name comes from the
Lua API: `CCountryDataBase_GetTag` (`0x4EA930`), the wrapper registered as
`CCountryDataBase.GetTag`, fetches exactly this global and passes it to `0x118480`, which
does the lookup (**read**). About 2,460 places in the game read the global.

| Offset | Holds | |
| --- | --- | --- |
| +0x0 ... +0x167 | 45 pairs of dwords; the constructor zeroes the second of each. Not worked out | read |
| +0x16C / +0x170 / +0x174 | **every country by id**, a vector of `CCountry*` (first, last, end). `CCountryTag::GetCountry` (`0x2610`) is `countries[tag.id]` and nothing more | read |
| +0x17C | 64 hash buckets of 16 bytes, each a vector of `CCountryTag` (first +0, last +4). `GetTag` sums the three letters, takes it modulo 64, and searches that bucket; not found gives `---` with id 0 | read |

This is a second country array beside the game state's list at `+0xBBC` (which
`CCurrentGameState.GetCountries` hands out, and BiceLib walks). Whether the two hold the
same pointers has not been checked.

### The defines, and how a block is laid out

`GetDefines` (`0x45D90`) makes the object on first use and keeps it at `0x1686040`. It is
mostly pointers to blocks, one per block in `defines.lua`, and **a block is that block's
entries in file order, one dword each, x1000**.

That is **read live and exactly**, on the economy block at `+0x9C`: all 21 of its entries
matched BlackICE's own `defines.lua`, values and all - `IC_TO_MONEY` 0.09 as 90,
`MAX_PROVINCE_SELL_PRICE` 2000 as 2000000, and the four convoy figures at the mod's 3 / 40 /
3 / 90 rather than vanilla's 2 / 100 / 4 / 240. The block is in `GameClasses/CDefines.hpp`.

**It does not follow that every block counts out.** The military block at `+0xAC` does not -
`SUPPLYPOOL_DAYS` sits four bytes earlier than the file order would put it, and the leader
distance defines seven entries later. So check a block against a running game before trusting
a name in it; the `RADIO_*_LEADER_DISTANCE` names in `CDefinesSupply` remain inference.

`CCountry::GetConvoyBuildCost` (`0xFD590`) and its three siblings are one shape:
`define x (1000 + a technology figure) / 1000`, floored at 10.

| function | define | technology |
| --- | --- | --- |
| `0xFD590` GetConvoyBuildCost | `CONVOY_BUILD_COST` | `CTechnologyStatus +0x44` |
| `0xFD600` GetConvoyBuildTime | `CONVOY_BUILD_TIME` | `+0x48` |
| `0xFD670` GetEscortBuildCost | `ESCORT_BUILD_COST` | `+0x4C` |
| `0xFD6E0` GetEscortBuildTime | `ESCORT_BUILD_TIME` | `+0x50` |

### Save keys, and how to get one

**Save code never writes a key as a string.** It writes an id - `mov ecx, 0x5A6`, then a
call - and a table built at startup turns that into `usage`. `reversing/saveTokens.py`
rebuilds the table by walking the registrations (`mov edx, <the string>` ... `mov ecx, <the
id>`): **2056 ids** in this build, and it checks out against the one id that was already
known from another direction, `carrier_size` at `0x522`.

That is a way of naming a field the Lua API never exposes: find where the class's writer
saves it and read the id. The country's goods pools are the worked example.

### The country's goods pools, and which are which

Twenty-three `CGoodsPool` from `+0x74C`, `0x24` apart, each holding the seven goods from its
own `+0x8` - so one good is `pool + 8 + GoodsCategory * 4`. Eight were named by the game's
Lua accessors. The writer at `0xCFF20` saves **ten** of them, and the keys agree with every
name BiceLib already had - `convoyed_out`, `traded_away`, `traded_for`, both
`sans_allied` ones, `home` for `home_produced`, and just `pool` for the exile stockpile.

Three it names that nothing else did:

| offset | key | part it plays |
| --- | --- | --- |
| `+0x98C` | `usage` | an expense |
| `+0x9B0` | `to` | an expense |
| `+0x9D4` | `back` | an income |

**The other thirteen are not saved at all**, so this cannot name them. Chasing them through
the code and a running game got part of the way:

- **Four are never used in this build.** `+0x824`, `+0x848`, `+0x944` and `+0xA64` were zero
  in all 108 countries of two games, one of them the 1942 save watched for eleven days; the
  first three never moved once and are written nowhere but the constructor and the two daily
  resets (`0xD34xx` and `0x1033xx`, which write a constant over every pool). `+0xA64` moved
  twice in eleven days. So the terms `GetDailyNeed` and `GetDailyIncome` spend on `+0x824`,
  `+0x848` and `+0xA64` add next to nothing.
- **`+0xA1C` and `+0xA40` are the unit supply draw** (`0x1BB950`). When a unit takes supply
  from a country, `+0xA1C` is credited if the unit stands in that country's acting capital
  province, and `+0xA40` where the supplier is the unit's own country - the other branch
  credits `traded_away` and `traded_for`, which is where allied supply is recorded. Live,
  `+0xA1C` held supplies alone and `+0xA40` supplies and fuel.
- **Three more were told apart by watching a 1942 game run** - eleven snapshots over eleven
  game days, all 108 countries (`poolSnapshot.py`, `poolCompare.py`). Each moves in
  particular goods and nothing else, which is what gives them away:
  - **`+0x8D8` and `+0x8B4` are the conversion pair**, what it consumes and what it makes.
    49 countries were converting: England took 677 crude oil and made 1584 fuel, Japan 276
    for 609, and **Germany took 340 oil *and* 178 energy and made 781 fuel *and* 34 oil** -
    synthetic oil from coal. The rate differs by country, which is the `FUEL_CONVERSION`
    modifier (92) at work. It matches their part in the daily figures exactly: the input is
    an expense, the output an income.
  - **`+0x968` is what the country's industry needs** - metal, energy and rares in
    **1 : 2 : 0.5** for every country without exception (Germany 697/1394/348, the USA
    3186/6372/1593), and `usage` tracks it to within a fraction of a percent.
- **`+0x920` and `+0x8FC` are the puppet tribute** - the mechanic where a subject hands its
  overlord everything it holds over a threshold. `+0x920` is what the subject sends, held as
  a **negative**; `+0x8FC` is what the overlord receives. Only subjects have anything in the
  first and only overlords in the second, and the two match to the thousandth against the
  `overlord` tag (`+0xF38`) on each giver:

  | subject | overlord | sends | the overlord's `+0x8FC` |
  | --- | --- | --- | --- |
  | Burma | England | oil 7.54 | oil 7.54 |
  | Croatia | Italy | metal 2.69, rares 2.31 | metal 2.69, rares 2.31 |
  | Slovakia | Germany | money 8.98 | money 8.98 |
  | Mongolia + Tannu Tuva | USSR | money 11.52 + 6.25, energy 19.79 | money 17.77, energy 19.79 |

  It is **not** `traded_away` and `traded_for`, which are far larger for the same countries
  and cover ordinary trade. **One thing does not add up**: Manchukuo and Mengkukuo send Japan
  money, metal and energy and Japan's `+0x8FC` is empty - whether that is dropped, credited
  elsewhere, or only counted on arrival is not established.

Two things that looked like relationships did not survive checking: `+0x968` is not `usage`
times a constant (one ratio in 34 of 108 countries, several in the rest) and `+0xA1C` is not
`usage`'s supplies (equal in 29 of 79). Neither is recorded as a finding.

### The two capitals

`+0xE20` is **the capital** and `+0xE24` **where the government sits now**. BiceLib had the
name on `+0xE24` until 2026-09-19; the pair of accessors settles it, because
`CCountry::GetCapitalLocation` (`0x17AF0`) and `GetActingCapitalLocation` (`0x2F100`) are the
same function but for the offset they read - both index the game state's province vector at
`+0xB8C` - and `GetActingCapital` (`0x6C370`) answers `+0xE24` (**read**).

**The Lua API is a trap here**: it registers the C++ `GetActingCapital` under the name
`GetCapital`, so a script asking a country for its capital is told where the government sits.
That is one of only two places in the whole API where the Lua name and the C++ name disagree
by more than case - the other is `CDistributionSetting::GetBasePercentage`, registered as
`GetPercentage` - and `luabindExtract.py` now takes the C++ name for both.

The stockpile follows the **acting** capital: `CCountry:GetPool()` (`0xF4DE0`) calls
`GetActingCapitalLocation` and adds the province's pool offset, unless the country is a
government in exile, when it answers the pool the country holds itself at `+0x9F8`.

### Leadership, and the four sliders

`+0x5E4` is **the leadership distribution**: a vector - first element here, end at `+0x5E8`,
capacity at `+0x5EC`, all three zeroed together by the constructor - holding four
`CDistributionSetting*` in a fixed order (**read live**, every one of 108 countries, each
object identified by its vftable):

| | class | |
| --- | --- | --- |
| [0] | `CDistributeNCO` | officers |
| [1] | `CDistributeDiplomacy` | |
| [2] | `CDistributeEspionage` | |
| [3] | `CDistributeResearch` | |

The game names it itself: `CCountry::GetLeadershipDistributionAt` (`0xE06C0`) is nothing but
`[this + 0x5E4][i]`.

A setting is `0x28` bytes (`0xC9FA5` allocates it). `+0x8` is the share it is set to, the
game's `GetBasePercentage`, registered to Lua as `GetPercentage` (**named**); `+0x10` a
second figure the constructor sets to 1; `+0x18` the country. Both figures are eight bytes,
and the compiler's RTTI gives their type exactly - `fpml::fixed_point<__int64,48,15>`, so
**32768 is 1**. **Read live**: the four shares add to one in every country, and Luxembourg
was running 0.85 officers, 0.15 espionage, nothing on diplomacy or research.

That is the whole of `CCountry::GetAllowedResearchSlots` (`0xE0170`):
`round(base_percentage x factor x TotalLeadership)` off the fourth setting. The shifts by 15
and 30 and the `0x1F40000` in its decompile are only the fixed point arithmetic.
`GetNeeded` is virtual slot 3, and `CDistributeResearch`'s (`0x121450`) answers the country's
`GetNumberOfCurrentResearch` (`+0x640`) shifted into the same fixed point - so allowed
against used.

### Industrial capacity, and the six sliders

`+0x5F4` is the same shape again - first element, end at `+0x5F8`, capacity at `+0x5FC` -
holding six `CDistributionSetting*`. The game names the order itself: `ProductionCategory`,
which it registers to Lua on `CDistributionSetting` (**named**), and the vftables of a
running country's six objects are in exactly that order (**read live**):

| | class | |
| --- | --- | --- |
| [0] | `CDistributeLendLease` | `_PRODUCTION_LENDLEASE_` |
| [1] | `CDistributeConsumerGoods` | `_PRODUCTION_CONSUMER_` |
| [2] | `CDistributeProduction` | `_PRODUCTION_PRODUCTION_` |
| [3] | `CDistributeSupply` | `_PRODUCTION_SUPPLY_` |
| [4] | `CDistributeReinforcement` | `_PRODUCTION_REINFORCEMENT_` |
| [5] | `CDistributeUpgrade` | `_PRODUCTION_UPGRADE_` |

`LeadershipCategory` does the same for the four above - NCO, diplomacy, espionage, research -
and agrees with what was read off those objects.

**`CCountry::GetAvailableIC` (`0xF4D70`) is spare IC, not unallocated IC.** It calls one
helper (`0xF4B90`, named `GetSpareICIn` here) for the five categories from `_CONSUMER_` to
`_UPGRADE_` - **lend lease is left out** - adds the five up and divides by 1000. The helper
works out what the slider allocates, `percentage x factor x TotalIC` (`+0x604`), and takes
off what that category actually needs, never going below zero (a jump table at `0x0F4D54`):

| category | what is taken off |
| --- | --- |
| `_CONSUMER_` | nothing at all if the country has any dissent (`+0x10B4`); otherwise the setting's own `GetNeeded`, scaled by a define |
| `_PRODUCTION_` | the production queue - `GetUsedIC` (`0xF4B60`) |
| `_REINFORCEMENT_` | the country's `+0xA98` |
| `_UPGRADE_` | the country's `+0xAA4` |
| `_SUPPLY_` | nothing: supply falls through to the branch that answers zero, so it never counts as spare |

So a country with every slider matched to its need has no available IC however much industry
it has, and lend lease never shows up in the figure.

### What a building costs

`CCountry::GetBuildCost` (`0xDFDA0`) takes a `CBuilding*` and answers what this country pays.
The building's own cost is `+0x58`, x1000, and it is the `cost` key of
`common/buildings.txt` (**read live**, against the mod's file: `air_base` 2600 for `2.6`,
`naval_base` 4275 for `4.275`, the nuclear reactors 50000 for `50`). `+0x88` is a
`CTechnologyCategory*`, and the cost is scaled by what that category has earned:
`cost x (1000 - discount) / 1000`, with no discount at all unless slot 2 of the category
answers true.

Which category a building hangs off is sensible (**read live**): most of them
`construction_practical`, the two nuclear reactors `nuclear_bomb`, `smallarms_factory`
`infantry_theory`, `automotive_factory` `automotive_theory`, `radar_station`
`electronic_engineering_practical`.

The discount is `0xE1AC0` (`GetCategoryBuildDiscount` here, the name is BiceLib's):

- the country's **ability** in that category - the game's own word: `CCountry::GetAbility`
  (`0xE0290`, registered to Lua) answers its own level at `+0x698`, a pointer to thousandths
  indexed by the category's `+0x5C`, unless `+0x6A8` names a country sharing that category
  and theirs is higher. **Read live** against the game's own keys: Germany at
  `infantry_practical` 12.000, `construction_practical` 5.000. The discount does that lookup
  inline rather than calling `GetAbility`.
- floored at 0, then measured against **5.000**. Below it the result is negative and the cost
  **goes up**, at 100 per point; above it 50 per point, with everything past 1.000 halved
  first.
- plus the country's `INDUSTRIAL_EFFICIENCY` modifier (74) and `CTechnologyStatus +0x94`.
- capped at 990, so never more than 99% off.

So 5.0 in a category is the break even point, and a country that has neglected one pays a
premium for its buildings.

`CTechnologyCategory` (vftable `0x11C3510`) is the 48 theory and practical lines: `+0x8` the
key, `+0x24` the localised name, `+0x5C` the index everything above is by.

**The slot 2 call that guards the discount always says yes.** It is `0xA92590`, the folded
`mov al,1; ret` that 259 virtual tables share, and `CNullTechnologyCategory` - which derives
from the category and adds a fourth slot - does not override it either. (Its sibling
`CNullTechnologyFolder` does override slot 2, with `xor al,al; ret`, which is what makes the
slot look like an `IsValid`.) So no building escapes the calculation.

**Which bites one building.** Of the 59 in a running game, 58 point at a real category and
one - `nuclear_reactor` - points at the `nocategory` object, whose index is **0**, and slot 0
of the ability array is 0 for every country. An ability below 5.000 *raises* the cost, so by
the formula England pays **36850 for a building the file prices at 25000**, where its
`air_base` at `construction_practical` 5.000 pays 2532 against 2600. That is the formula as
read, arithmetic included, not a figure watched in the game - the building's own tooltip
would confirm it.

**`+0x6A8` is the game's technology sharing** - made to happen, then read back. Playing
England and sharing `artillery_theory` with France put **exactly one** non-empty tag in the
world: on **France**, against category 4, naming ENG. So the tag sits on the receiver rather
than the giver, one slot per category, and every other country's 48 entries stayed `---`.
France was on 7.500 artillery theory against England's 10.000, so `GetAbility` answers 10.000
for France while the sharing lasts - and its artillery buildings get the discount that goes
with it, since `0xE1AC0` reads the same pair.

### What a unit type costs

`CCountry::GetBuildCostIC` (`0xE18F0`) is the same shape as the building one, one term richer.
The base is the definition's `BuildCostIC` (`+0xF8`), and the multiplier over 1000 is:

- `+` `CTechnologyStatus +0x24C` indexed by the definition's own index - what technology has
  done to this type's cost;
- `+` the function's **third argument times 10**, so 1% a point. That argument is the caller's
  to work out, and the game does it at `0x63D40`: it walks the definition's own technology
  list (`+0x44` to `+0x48`, 45 to 56 `CTechnology*` on a loaded one) and adds up
  `CTechnologyStatus +0x218` indexed by each technology's `+0x244`;
- `-` the discount the definition's technology category earns - `+0x3C`, and **the same
  `0xE1AC0` buildings go through**. **Read live**: `infantry_brigade` points at
  `infantry_practical`, `carrier` at `carrier_practical`, `interceptor` at
  `single_engine_aircraft_practical`.

Then, where the **fourth argument** is set, the whole is multiplied by
`(1000 + RESERVES_PENALTY_SIZE)` over 1000 - modifier 77 - so that argument is "this is a
reserve".

So a unit type's price moves with three separate things: the technologies it is built from,
the practical or theory line it belongs to, and whether it is going to the reserves.

**The reserves part is `RESERVES_PENALTY_SIZE`, modifier 77, and it is a discount.** Live it
was -0.350 for England, France and the USA, -0.050 for Germany, -0.075 for the USSR. Nineteen
places read it, three of which are worth knowing:

- `CRegiment::GetMaxStrength` (`0x1AB680`) scales `max_strength` by `(1000 + it)` where the
  regiment's reserve byte is set - so an English reserve division is 35% weaker as well as 35%
  cheaper. That is the whole trade.
- `CCountry::GetBuildCostIC` and `GetBuildCostMP` apply the same where their last argument says
  reserve.
- **`CMilitaryConstruction` carries its own copy.** `+0x8C` is the reserve flag and `+0x9C` the
  factor, and two sites (`0x84A3A` in a virtual of that class, and `0x85211`) fill `+0x9C` with
  `1000 + it` when the flag is set. **Read live**: of 211 items in a running game, 169 had
  `+0x8C` clear and `+0x9C` exactly 1000, and the 42 flagged ones held 650, 725, 800, 825, 950
  or 1000 - `1000 +` each owner's modifier.

`GetTotalBuildCost` has no reserve step because it prices a *type*; the flag belongs to the
order, which is why the Lua entry points take it and the construction item keeps its own factor.
**That the factor is stored rather than looked up means an item priced before the modifier
changed keeps the old one** - read off the layout, not watched happening.

### How long a unit type takes

`CCountry::GetBuildTime` (`0xE19A0`) is the definition's `BuildTime` (`+0x100`) times two
factors over a million. The first is 1000, `+` `CTechnologyStatus +0x26C` for the type, `+` the
second argument times 10, `+` the country's `UNIT_RECRUITMENT_TIME` modifier (51), `-` the same
technology category discount the costs use, and it is floored at 50. The second is 1000 plus
**one** build speed modifier.

**Which one is chosen names three flags nobody had named.** The definition's kind bytes are
tested in a fixed order, and each picks the modifier of its own name:

| flag | modifier |
| --- | --- |
| `+0x33` | `ROCKET_BUILD_SPEED` (89) |
| `+0x34` | `TANK_BUILD_SPEED` (90) |
| `+0x2C` | `AIR_BUILD_SPEED` (87) |
| `+0x2E`, already `is_ship` | `NAVAL_BUILD_SPEED` (91) |
| none of them | `LAND_BUILD_SPEED` (88) |

So `+0x2C` is `is_air`, `+0x33` `is_rocket`, `+0x34` `is_tank`. **Read live** and the unit types
agree: `+0x2C` on `interceptor`, `cag`, `transport_plane` and both flying bombs; `+0x33` on the
two flying bombs alone; `+0x34` on `armor_brigade` alone. The order matters - a rocket is air as
well and is tested first, and a tank is a regiment that would otherwise fall through to land.

It is a check on the modifier names as well: those were read out of a running game's
`CModifierDefinition` keys, and here the code reaches for exactly the one whose name matches the
flag it has just tested.

**Only Lua calls that entry point.** The game's own is `0x63D40`, `GetTotalBuildCost` here -
`__cdecl` on (definition, country, `int64* ic`, `int64* manpower`), either pointer null to
skip that half, both answered as `fpml::fixed_point<__int64,48,15>`. It is **the whole of a
build, not a day of one**: it sums the definition's technologies itself, hands the total to
`CCountry::GetBuildTime` (`0xE19A0`) for the days, works the daily cost out inline with the
same terms as `GetBuildCostIC` - **without the reserves step, which it does not have** - and
multiplies the two. The manpower half repeats it from `build_cost_manpower` (`+0xFC`) with
`CTechnologyStatus +0x25C` and a floor from a global. Its three callers (`0x63A3E`, `0x64B07`,
`0x64BC3`) all add the two figures onto running totals with `add`/`adc`, so this is what a
production queue is priced with.

## The in game idler

`CInGameIdler`, vftable `0x11CEB54`, 111 slots (**RTTI**). One instance while a game
is running (**seen**), found by scanning for that vftable - `cacheIngameIdler` in
`bice.cpp` already does. It is the in game loop: the timers, the selection, and the
autosave request.

**The offsets are in `BiceLib/GameClasses/CInGameIdler.hpp`**, which is the authority
for them; how the autosave ones were found is in `FINDINGS-autosave.md`.

`+0xD34` was recorded here as a timer id at first. It is the map mode, and the numbers
the autosave dispatcher compares it against are Supply, Air and Naval - the correction
is written up in `FINDINGS-autosave.md`.

| Offset | Holds | |
| --- | --- | --- |
| +0x68 | 0 in single player; the branch that reads it looks like multiplayer | seen for the value, inferred for the meaning |
| +0xAB0 | **an autosave is wanted** - cleared at the top of every decision, and the only thing the writer reads | read |
| +0xAB1 | the writer has already spent its one frame of delay | read |
| +0xD34 | **the current map mode**, by the game's own numbering | read, and used |
| +0x1304 | the selected things, as a list start | mem, used |

The autosave settings live on the settings singleton, `module + 0x16863F8`, not here:
`+0x158` is `debug_saves` and `+0x15C` is the frequency (**seen**, both matched
against `settings.txt`). `+0xF4` on the same object is the map style
`FINDINGS-mapmode.md` writes. All three are in
`BiceLib/GameClasses/GameSettings.hpp` - named for what it holds, because the object
has no vftable in the RTTI export to name it after.

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
