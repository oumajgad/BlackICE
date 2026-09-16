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

### Supply and fuel consumption

`CSubUnitDefinition`'s `supply_consumption` (+0x110) and `fuel_consumption` (+0x114)
are **base figures for one sub unit**. What the game displays for a unit is a good deal
more, and BiceLib calls the game's own functions for it rather than reimplementing
(**used**, disassembly, and the OOB browser matches the game's tooltip):

| RVA | Takes | Gives |
| --- | --- | --- |
| `0x1BB560` | `(CUnit*, int* out, bool withoutLeaders)`, stdcall, `ret 0xC` | supply, in thousandths, through `out` |
| `0x1BB7A0` | unit in **eax**, `(int* out, bool withoutLeaders)` on the stack, `ret 8` | fuel, the same way |

Both return the `out` pointer in eax. The per regiment versions are `0x1AD0F0` (supply)
and `0x1AD300` (fuel), which take the regiment in eax.

What the unit level pair does, which is why the figure differs from the sum of the base
values:

- starts a potency at **1000**, and adds the country's general modifier at
  country's global modifier, `SUPPLY_CONSUMPTION` (entry 49, `+0x188` of its values);
- walks **up** the OOB by `higher_oob_unit_ptr` to the unit whose `oob_level` is 1 - the
  army group - and **subtracts** an amount worked out from that leader's `skill`
  (`CLeader +0x70`) and the level, so a better army group commander lowers what
  everything under it consumes;
- sums each regiment's base figure scaled by how much of its `max_strength` (+0xEC) is
  left, except for naval units, which are not scaled that way;
- for land units with a particular order type (the order's virtual at +0x40 returning
  `0x5A4`) scales the whole by a further modifier.

`withoutLeaders` skips the first two steps, which gives the base figure the unit
inspector shows.

The sub units a unit holds are `CRegiment` (`GameClasses/CRegiment.hpp`): strength at
+0x30, organisation at +0x60 and the name at +0x68, all **used** by the OOB browser.
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

Not registered to Lua, and so not named: type 57, and everything from 83 to the 142
`../../../mem` counts.

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
