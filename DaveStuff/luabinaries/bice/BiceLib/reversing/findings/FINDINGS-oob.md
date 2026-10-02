# The order of battle, key by key

All addresses are virtual, the way a disassembler prints them; the rva is what
`project.json` and BiceLib want. Only valid for this build.

## An OOB file is a piece of a country's save block

`CCountry::LoadOobFile` (rva `0xFFED0`) builds `<base>/units/<path>`, makes a
`CParseContext` over it, and calls **the country's own slot 3, `CPersistent::Load`**
(`0x5002EF` is the `call`). Load pulls one key at a time and hands each to slot 4,
`CCountry::LoadKey` (rva `0xCCDA0`) - the same loader a savegame goes through.

**So every key a country understands is legal in an OOB file, and nothing marks one as
save-only.** `CCountry::LoadKey` has 126 cases; seven of them make units:

| key | token | builds |
| --- | --- | --- |
| `army` | 592 | `CArmy` |
| `navy` | 593 | `CNavy` |
| `air` | 1088 | `CAir` |
| `theatre` | 1125 | `CArmy` |
| `armygroup` | 1126 | `CArmy` |
| `corps` | 1127 | `CArmy` |
| `division` | 1128 | `CArmy` |

The other 119 are the country's own - `capital`, `technology`, `politics`, every history
key - and an OOB file may carry any of them. That is not a permission the format grants
deliberately; it is what reading the file through the country's loader implies.

## The unit block

`CUnit::LoadKey` (rva `0x1B6E90`, VA `0x5B6E90`) is the whole of what a `division`,
`corps`, `army`, `navy`, `air` or `theatre` block accepts - 40 keys, 4658 bytes of switch,
and the largest loader in the game after `CTrigger` and `CEffect`:

| what it is | keys |
| --- | --- |
| a child unit | `theatre` `armygroup` `army` `corps` `division` `navy` `air` |
| what the unit is made of | `regiment` `ship` `wing` |
| identity | `id` `name` `location` `leader` |
| where it is going | `path` `track` `previous` `movement_progress` `retreat` `possible_retreat` `disengage` `arrow_state` `start_date` `end_date` `was_paradropped` |
| condition | `supplies` `fuel` `dig_in` `attack_delay` `combat_hours` `can_upgrade` `can_reinforce` `is_reserve` `is_prioritized` |
| battle plan | `plan` |
| lent out | `expeditionary_owner` `expeditionary_date` |
| stance | `aggression_enabled` `aggression_setting` |
| and | `country_intel` |

Only the first four rows are what a mod's OOB file writes. The rest is state a save
carries, and the loader cannot tell the two apart - the same switch reads both.

**The keyword does not pick the class; the parent does.** `CNavy::LoadKey` (rva
`0x1CF6A0`) and `CAir::LoadKey` (rva `0x1D0520`) both take `army`, `theatre`,
`armygroup`, `corps` and `division` back off `CUnit::LoadKey` and send all five to one
handler of their own - `cmp eax, 0x468 / jg` then `cmp eax, 0x465 / jge` then
`cmp eax, 0x250`, a run and a single, landing together. What the handler builds is still a
`CArmy`: `push 0x308` for 776 bytes and then the constructor at `0x4828C0`, which writes
both of `CArmy`'s vftables. What it does with it afterwards differs, and is not traced -
embarked land units is the obvious guess and no more than a guess.

Each derived class adds a few keys of its own and defers the rest:

| loader | rva | adds |
| --- | --- | --- |
| `CArmy::LoadKey` | `0x1CEC40` | `target` `parent` `staging_province` |
| `CNavy::LoadKey` | `0x1CF6A0` | `at_sea` `base` |
| `CAir::LoadKey` | `0x1D0520` | `base` |

## What a unit is made of

`regiment`, `wing` and `ship` all end at **one loader**, `CSubUnit::LoadKey` (rva
`0x1A8BF0`): RTTI gives `CSubUnit`, `CRegiment` and `CWing` the same slot 4, and
`CShip::LoadKey` (rva `0x1ADBF0`) is four instructions - it takes token `0x440` (`air`,
1088) and calls `0x5A8BF0` with everything else. Thirteen keys, and this is where a
brigade's line in an OOB file lands:

`type` `name` `home` `strength` `organisation` `experience` `historical_model` `builder`
`is_reserve` `current_distance` `sunk_by` `highest` `pride`

`plan` opens a `CUnitPlan::LoadKey` (rva `0x4DF720`), sixteen keys: `stance` `air_stance`
`naval_stance` `active` `path` `path2` `min` `our_power` `their_power` `embark` `debark`
`allow_hq_reorg` `objectives` `objective` `ops_area` `fallback_line`.

`CTheatre::LoadKey` (rva `0xB01F0`) is the savegame's theatre object and **not** the
`theatre` key above: `id` `key` `country` `unit` `hot` `provinces` `front`.

## `unit_deployment`: the pool of built-but-unplaced units

A country's deployment pool is a linked list - head `CCountry +0x688`, tail `+0x68C`, count
`+0x690` - of `CUnitDeployment`, 0x3C bytes each. `CCountry::LoadKey` token 1204 builds one,
calls `CPersistent::Load` on it, and appends it with `0xF56C0`.

**`CUnitDeployment::LoadKey` (rva `0x17E080`) knows eight keys:**

| key | token | body |
| --- | --- | --- |
| `id` | 11 | `ParseObjectId` into the deployment's own id |
| `army` `theatre` `armygroup` `corps` `division` | 592, 1125-1128 | one body: `new` 0x308, `CArmy` ctor (`0x4828C0`) |
| `navy` | 593 | `new` 0x2FC, ctor `0x5CEE20` |
| `air` | 1088 | `new` 0x2F4, ctor `0x5D0460` |

The four land keywords beside `army` reach that body through a range test -
`cmp eax, 0x465 / jl default / cmp eax, 0x468 / jg default` and fall through - so **as far
as this loader is concerned `division` and `army` are the same key.**

**A block holds exactly one unit.** All three bodies end in an unconditional
`mov [edi+0x38], eax`, so a second unit keyword in the same block overwrites the first and
leaks it. One `unit_deployment = { }` per unit, which is what the game's own saves write:
every one in a 1936 autosave is `id` then a single `air` (36 of them) or `navy` (1), with
the brigades as `wing`/`ship` inside that unit.

**No `location`, and none needed.** The country-level case for a unit (rva `0xCD959`) ends
by testing `CUnit::current_province_ptr` (`+0x130`) and calling the deleting destructor at
`0xCD9E2` when it is zero - a top-level `division` without a location is read in full and
then thrown away in silence. The deployment case has no such test: it stores the unit, sets
its tag from `CUnitDeployment +0x30`/`+0x34` and its `+0x1F4` from the parse context, loads
the block, and returns. A unit in the pool is not on the map, so it keeps no province.

### What `load_oob` changes, and what it does not

The effect is `CCountry::SetOobFile` then `CCountry::LoadOobFile` (`CLoadOOBEffect::Execute`,
rva `0x5BBD00`) - exactly what a country's `oob = "..."` reaches - so **the grammar is
identical either way**. What differs is only the state it lands in:

- **`0xF56C0` appends and never replaces.** At scenario start the list is empty; mid-game it
  is not, so firing the same `load_oob` twice puts every `unit_deployment` in twice. Nothing
  de-duplicates, and the ids in the file are not checked against anything - `id` is read
  straight into the object by `ParseObjectId` with no registry lookup, so a collision with a
  live object passes unnoticed.
- Everything else about the block is the same code on both paths.

### An unrecognised key does not skip its block

Worth knowing for any hand-written OOB, because it turns one wrong key into a wrecked file.
`ParseReadKeyValue` (`0x67ACB0`) reads the key, the `=` and **one** value token, so for
`foo = {` the value is the `{` itself. A loader that does not know the key tail-calls
`ReportUnknownKey` (`0x67A7B0`), which appends `"Unexpected foo"` to a list that nothing
reads for a data file **and consumes nothing**. `CPersistent::Load` then reads the next
token - the first key *inside* the block it just refused - and carries on there, so a
misspelled block's contents are read as keys of the enclosing object until the first `}`
reached in key position ends that object's `Load` early. Nothing warns:
`CParseContext::ReportMessages` (`0x67C050`) is the only thing that prints those messages,
and its seven callers are savegames and DLC paths, not this one.

## `status` in a construction block

The word means two different things, one per class.

### On any construction: the last day's funding

`CConstruction +0x3C`, thousandths. **Written in exactly one place**, the progress call at
rva `0x837D0` - `this` in ESI, one stack argument, the amount of a day's work to add:

    fraction = amount ? (duration ? amount * 1000 / duration : -1) : 0
    <virtual slot 20, [vftable+0x50], is called with that fraction>
    progress (+0x38) += amount
    status (+0x3C) = amount >= 1000            ? 1000
                   : amount > 0 && cost > 0    ? amount
                   :                             0

So `status` is **how much of a full day's work the item got the last time the queue was
advanced**, capped at one day. Its three callers say the same: the country's daily
production pass (rva `0x119D10`) calls it once with a literal `1000` - the item fully
funded - and once with a computed partial amount, and the two build commands
(`CConstructBuildingCommand`, `CConstructUnitCommand`) call it when an item is queued. Each
construction class's constructor initialises the field to 1000.

That matches what the field holds live: 1.0 on most items, 0 on the rest, a handful in
between - fully funded, unfunded, and part funded.

**Nothing reads it.** Two sweeps for a reader of `+0x3C` on a construction found none
outside the loader and the save writer: one over every named function from its own entry
point, so correctly aligned, and one linear over all of `.text`. The linear one can miss
misaligned code, so this is strong rather than proved. A `status` in an OOB file therefore
survives only until the item is next advanced, and changes nothing about cost, speed or what
is built.

### On a convoy construction: escorts or transports

`CConvoyConstruction::LoadKey` (rva `0x866B0`) takes the key **before the base sees it** and
compares the value token against 502, `yes`: on a match it sets a byte at
`CConvoyConstruction +0x58` and returns, and anything else - including `no` - falls through
to `CConstruction::LoadKey`, which parses it as the number above.

That byte decides where the finished build goes. At rva `0x86770`, on completion:

| `+0x58` | what the finished convoys add to |
| --- | --- |
| set | `CCountry +0xB4`, `escorts` |
| clear | `CCountry +0xB0`, transports |

Both arms are the same three instructions over the convoy definition's `+0x34` divided by
1000. So in a `convoy_construction` block **`status = yes` means "these are escorts"**, and
it is the one spelling of the key that carries meaning - the only load-bearing `status` in
an OOB file.

## `add_division`, and where ids come from

`CAddDivisionEffect` (vftable rva `0x11F547C`; `CEffect` numbers its slots 4 `LoadKey`,
9 `GetText`, 11 `Execute`) is the effect the mod's own docs list as unverified, and it is not
used anywhere in BlackICE. Its grammar is wider than its two named keys.

### The keys

`CAddDivisionEffect::LoadKey` (rva `0x5B5DF0`) handles two by token and the rest by name:

| key | what it does |
| --- | --- |
| `name` | a string into the effect's `+0x20` |
| `where` | `sscanf`'d into `+0x3C` as a province id; a value that is not a number reports a bad value |
| anything else | **looked up in `g_CSubUnitDataBase` by the key's own text** - so a brigade type is a key - and on a hit the pair {definition, the value's text} is appended to the vector at `+0x40`/`+0x44`, 0x20 bytes an entry |

A key the sub-unit database does not know is **dropped without a word** - not even into the
`Unexpected` list `ReportUnknownKey` keeps. So the shape is

    add_division = {
        name = "7. Panzerdivision"
        where = 3123
        light_armor_brigade = "1st Panzer"
        motorized_brigade = "2nd Motorized"
    }

and the value of a brigade key becomes **that brigade's name** (`Execute` assigns it into the
sub-unit's `+0x68`).

### What Execute builds

`CAddDivisionEffect::Execute` (rva `0x5B57F0`):

1. Takes the province from `+0x3C` through `g_CMap +0x2200`, and the owner from the scope's
   country - falling back to **the province's controller** (`+0x334`/`+0x338`) when the scope
   carries none.
2. Walks the entries. For the first one it also allocates the parent unit, and **the class
   comes from the brigade definition's own flags, not from the effect's name**:

   | definition flag | brigade | parent |
   | --- | --- | --- |
   | land (`+0x2D`) | `CRegiment`, 0xD8 | `CArmy`, 0x308 |
   | `is_air` (`+0x2C`) | `CWing`, 0xD8 | `CAir`, 0x2F4 |
   | otherwise | `CShip`, 0xF8 | `CNavy`, 0x2FC |

   So `add_division` will build a fleet or an air group perfectly happily; the name is the
   only thing that says division.
3. Per object: mints an id (below), `CSubUnit::SetType` from the definition, the name from
   the entry's string, organisation from `CSubUnit::GetMaxOrganisation`.
4. `CUnit::EnterProvince` (rva `0x1BEFD0`) - **the unit is put on the map**, not into the
   deployment pool - then registration with the game state and
   `AnnounceLoadedUnitsToScreen` (rva `0x48D560`) for the notification.

### The id generator

Both the effect and the loaders mint ids from one global counter, **`0x170AF78`**, stamping
id type **0x29 (41)**. `CUnit::AfterLoad` (slot 5, rva `0x1B80D0`) is where that happens for
a loaded unit:

    if (id_type != 0 || id != 0)          the file gave one: keep it, and then
        if (counter <= id + 1) counter = id + 1        push the generator past it
    else                                  mint: id = counter++, type = 0x29

`CSubUnit::AfterLoad` (rva `0x1A9130`) does the same for a brigade. So **an OOB file does not
need to carry ids at all** - leave the `id` block out and the game mints one. The mod already
relies on this: `history/units/Meme/flying_dutchman1.txt` has no ids, and every Flying
Dutchman in a save carries `type=41`. In a 1936 autosave, `type=41` is the second commonest
id type at 15751 against `4713`'s 19689 - the latter being ids that came out of files and
saves.

**What that does and does not protect.** Keeping the counter ahead of a file's id stops a
*future* runtime id colliding with it. It does not check whether the id is already in use by
something alive, so a hand-written id that duplicates a live object's is still a duplicate -
one more reason to leave ids out of a file loaded by `load_oob`.

## Why none of this was in FINDINGS-definitions.md

`definitions.py` walks every loader `progress.py` knows about, and `progress.py` read
slot 4 of `vftables[object_offset == 0][0]`. **A unit class does not keep `CPersistent`
as its primary base** - `CArmy`'s `CPersistent` vftable is at object offset 8 - so that
read landed on slot 4 of an unrelated table (`0x5C05F0` for `CArmy`, a per-unit update
with no key argument at all, which answers three keys if you ask it) and every unit class
came out with no grammar.

**`switchmap.py` had a blind spot of its own**, found the same week: MSVC spends a run of
adjacent tokens that share one body on a two-sided range test, and neither half is a `je` or
a jump table, so the tool read none of it. Three loaders were short of keys because of it -
`CUnitDeployment`, `CNavy` and `CAir`, each missing the same four land keywords - and for
`CUnitDeployment` that was half its grammar. Fixed; the shape is in the tool's docstring.

`progress.py` now picks the table by what `CPersistent` leaves in it: **slot 1 is
`CPersistent::Save` (`0x45BB10`) or slot 3 is `CPersistent::Load` (`0xA7C050`)**, which
are the framework and are hardly ever overridden, while slot 4 always is. That found five
loaders the file had been missing - `CUnit`, `CArmy`, `CNavy`, `CAir` and `CEU3Graphics` -
and took the count from 266 to 271.

## Not settled

- **What `CNavy` and `CAir` do with a child unit** after building it. The handler sets a
  byte at `+0x48`, writes `+0x1F4` from a call, and then calls two virtuals on the child.
- **Whether a top-level `theatre` also makes a `CTheatre`.** The key builds a `CArmy`;
  something has to make the theatre object that `CTheatre::LoadKey` reads, and it was not
  looked for.
- **Token 0** turns up as a case in `CUnit::LoadKey`. `switchmap.py` warns that a
  subtract-and-test chain can invent a low-numbered case, and this is one.
- The three keys `CArmy` adds are read but where they land on the object was not traced.
