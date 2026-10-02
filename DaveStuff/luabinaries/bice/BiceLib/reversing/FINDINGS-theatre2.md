# The six theatre sites, and `CAIInvasion`'s stage machine

`FINDINGS-aitheatre.md` closed with eight open items. This file settles its two biggest — the six `new CTheatre` sites in `CAIStrategy::BuildTheatres` and `CAIInvasion`'s three stage functions — and in doing so corrects that file on which of `CAIInvasion +0x84` and `+0x88` is the landing province. Read statically off `hoi3_tfh.exe` on 2026-10-01, game not running; addresses are **virtual** (base `0x400000`) unless marked rva, and nothing here was watched in a running game. The one non-executable source used is the game's own `map/definition.csv`, to turn four hardcoded province indices into names.

The `+0x84`/`+0x88` inversion in section 4 was re-checked independently before this file was accepted, because it overturns a `confirmed` entry: stage 2 does `mov edi, [edi+0x84]` at `0x8A0663` then `call 0x42F210` (`IsEnemy`) at `0x8A0671`, and `DoTick` does `mov eax, [esi+0x88]` then `call 0x4EF7C0` — which `project.json` itself names `CCountry::IsFriendly` — twice, calling the picker immediately after the first of those tests fails. The swap holds.

## 1. The six `new CTheatre` sites are one front rule, four hardcoded seats and one fallback

`CAIStrategy::BuildTheatres` (`0x8A9B10`, rva `0x4A9B10`) has one outer loop: for each `COwnerArea*` in `GetCountry(&strategy->tag)->+0xD30` (`0x8A9CAD`, skipping an area with `+0x2C == 0`). Everything below happens once per area, and the six sites are six arms inside that one iteration. Two per-area locals do the bookkeeping:

- **`leftover`** at `[ebp-0x44]/[ebp-0x40]/[ebp-0x3C]` — a `CList` seeded at `0x8A9CFA`–`0x8A9D11` with every province of the area (`COwnerArea +0x24`, next at `+0x8`) through `0x542F60`. Provinces are taken out of it as theatres claim them, by the inline unlink at `0x8AA24D`–`0x8AA27D` and by `0xA43FC0(list@EAX, &province@ECX)` elsewhere.
- **`made`** at `[ebp-0x54]/[ebp-0x50]/[ebp-0x4C]` — the theatres created *for this area*, zeroed at `0x8A9CDC` at the top of each iteration.

### Site 1 (`0x8AA0DE`) — one theatre per front of the area

At `0x8A9D2A` the function calls `0x47DA40(area, &fronts, tagChars, tagId)`, and the members of that list are **`CAreaBorder`**: the builder writes vftable `0x15BDB60` at `0x47DF92`, which the RTTI export names `CAreaBorder` (6 slots). Three independent confirmations that the object is read correctly, two of them from outside this function:

| field | what BuildTheatres does with it | corroboration |
| --- | --- | --- |
| `+0x8`/`+0xC` | `std::vector<CMapProvince*>`, sized `([+0xC]-[+0x8])>>2` at `0x8A9DB8` and walked | `CAreaBorder::LoadKey` (`0x47C630`) hands `&this[+8]` to the province-list reader for save token `0x1DC` `provinces` at `0x47C6D6` |
| `+0x1C`/`+0x20` | a `CCountryTag` tested against `REB` at `0x8A9D5A` and passed to `0x8A9390(strategy, chars, id)` | the same loader stores token `0x621` `local_enemy` here at `0x47C824`/`0x47C82A`; `fieldmap.py CAreaBorder` reports the same offsets |
| `+0x28` | copied straight into the new theatre's `+0x70` at `0x8AA209`–`0x8AA20C` | the loader does `ParseBool(&this[+0x28])` for token `0x396` `front` at `0x47C67C` |

So the first useful consequence is a one-liner: **a `CTheatre` is `hot` exactly when the `CAreaBorder` it was built from declared `front = yes`.** The four hardcoded theatres below set `+0x70 = 0` explicitly (`0x8AA4D5`, `0x8AA6C1`, `0x8AA899`, `0x8AAA7B`).

A front gets its own theatre on a **size** test, not a kind test. Over the front's provinces the function accumulates two sums of `area->+0x2C * 1000`, each over *distinct* areas:

- `home` (`[ebp-0x28]`, at `0x8A9E33`–`0x8A9E3C`) — the areas the front's own provinces lie in;
- `spill` (`[ebp-0x14]`, at `0x8A9FB0`–`0x8A9FB9`) — the areas reached by land adjacency from those provinces whose province is controlled by **the front's `local_enemy`** (`0x8A9F84` compares `neighbour->+0x338` against the saved tag id), and which pass the province's map-data `+0xD4 +0x13D` byte and the area's slot 0.

Then at `0x8AA040`–`0x8AA0BB`:

    if (home == 0) ratio = -1 else ratio = spill * 1000 / home
    if (spill >= 0x1F40)              make a theatre      ; 8 provinces x 1000
    else if (ratio >= [0x1B15028])    make a theatre
    else                              make none, and free the two area lists

`0x1B15028` (rva `0x1715028`) sits in the zero-initialised part of `.data` — `image.read` returns nothing there — so its value is written at runtime and **cannot be read statically**. The cheapest live check is to read that dword out of the process with the overlay or `dumpStruct.py`.

On success: `new CTheatre(strategy->tag)` (`push 0xA8`, ctor `0x4AEFB0`), id from `g_theatre_id` (`0x170AEBC`) with id type `0x2D`, slot 6 with the pair, `+0x70 = front->+0x28`, `0x4AF580(theatre, front, 1)`, append to `made`, and the front's provinces come out of `leftover`.

### Sites 2 to 5 — four hardcoded province seats for two hardcoded countries

These four are the answer to the question the previous survey asked, and they are all the same shape. Each reads a **fixed index into the province vector**, `CCurrentGameState +0xB8C` (`provinces_begin`, the vector of `CMapProvince*` indexed by id, per `BiceLib/GameClasses/CCurrentGameState.hpp`):

| site | country gate | province offset | index | `map/definition.csv` | extra gate |
| --- | --- | --- | --- | --- | --- |
| 2 `0x8AA419` | `strategy->tagId == db->+0x4` | `[+0x28D4]` | 2613 | **Paris** | `made.count < 2` (`0x8AA346`) |
| 3 `0x8AA605` | same branch | `[+0x1E20]` | 1928 | **Warszawa** | `made.count == 1` (`0x8AA52F`) |
| 4 `0x8AA7E6` | `strategy->tagId == db->+0x1C` | `[+0x3928]` | 3658 | **San Fransisco** | none |
| 5 `0x8AA9C3` | same branch | `[+0x46C8]` | 4530 | **Washington D.C.** | none |

and each then requires all three of:

    province->+0x2B4 == the area this iteration is on
    province->+0x338 == strategy->tagId          ; we control it
    !0x4A56B0(province, 0)

before building the theatre, setting `+0x70 = 0`, appending to `made`, calling **`CTheatre::AddKeyProvince`** (`0x4AFCE0`, receiver in **ESI**) with that province, then **`CTheatre::AddProvince`** (`0x4AF950`, receiver in **EAX**), then removing the province from `leftover`.

**The two countries are GER and USA, and this is read, not guessed.** `CCountryDataBase` carries 45 `CCountryTag` slots at `+0x0` with an 8-byte stride; its constructor (`0x4024D0`) zeroes exactly those 45 id halves (`+0x4`, `+0xC`, … `+0x164`) and nothing else in the range, and `project.json` already has `+0x16C`/`+0x170`/`+0x174` as the countries vector and `+0x17C` as the 64 tag buckets, which brackets the array neatly. The names and their order are an array of 3-char strings in `.rdata` at `0x15C1DE4` — `GER ENG SOV USA JAP FRA ITA PHI CHI CHC CGX CSX KOR MEN SIK CXB CYN BEL LUX HOL POL ROM HUN BUL TUR YUG SLO CZE AUS MAN DEN NOR FIN EST LAT LIT SWE SCH SPA SPR ETH CAN SAF AST NZL` — immediately followed by the string `countrydatabase.cpp`, which is the translation unit. And the function at `0x515CC0` is a 45-arm string-compare chain over exactly that array which, on a match, caches the tag into the matching slot:

    "GER" (0x15C1DE4) -> db +0x0/+0x4     store at 0x51622F
    "ENG" (0x15C1DE8) -> db +0x8/+0xC     store at 0x516336
    "SOV" (0x15C1DEC) -> db +0x10/+0x14   store at 0x51643B
    "USA" (0x15C1DF0) -> db +0x18/+0x1C   store at 0x516546
    "JAP" (0x15C1DF4) -> db +0x20/+0x24   store at 0x516612
    "FRA" (0x15C1DF8) -> db +0x28/+0x2C   store at 0x5166D3

so slot 0 is GER and slot 3 is USA, in .rdata order, with no off-by-one from the `"Null"`/zero pair that sits just before `GER` at `0x15C1DDC`/`0x15C1DE0`. The pairing then reads itself: **Germany gets a hardcoded theatre at Paris and one at Warszawa; the USA gets one at San Fransisco and one at Washington D.C.** — the two conquered capitals and the two coasts.

**This converges with a live reading already in the record.** `CLASSES.md` says of `CTheatre +0x40` (`key_provinces`): *"3 of 100 theatres hold exactly one province here and it looks like the theatre's seat - Paris on the theatre whose HQ unit is `Paris HQ`, San Francisco on `Pacific High Command`, Washington D.C. on `Eastern Defense Command`."* Those are three of these four, and `0x4AFCE0` — the `key` adder — is called from nowhere else in `BuildTheatres`. The fourth, Warszawa, needs Germany to hold it and needs its area to already have exactly one theatre.

That last asymmetry is read and worth stating plainly, because it is not symmetric the way one would expect. Reaching site 2 needs `made.count < 2`; reaching site 3 needs `made.count == 1`. Since Paris and Warszawa are in different areas, in Paris's area site 2 fires from a count of 0 or 1 and site 3's province then fails its area test; in Warszawa's area site 2's province fails the area test and site 3 fires **only if site 1 already made exactly one theatre for that area**.

### Site 6 (`0x8AAB02`) — the whole-area fallback

Gated at `0x8AAAD6`–`0x8AAAE1`:

    if (leftover.count != area->+0x2C) skip

i.e. it fires only when **nothing above has claimed a single province of the area**. That is the catch-all: one theatre for the area as a whole, which then takes the provinces through `0x4AF950` at `0x8AAC08`.

After site 6 the function runs two further passes (`0x8AAC40`–`0x8AB4C6`) that hand *remaining* provinces to theatres already made — `0x4AF950` at `0x8AAE70` and `0x8AAF41`, `0x4AF580` at `0x8AB357` and `0x8AB748`, with `leftover.count` decremented at `0x8AAECA` and `0x8AAF9A`. No `CTheatre` is constructed there; `CTheatre::CTheatre` appears in this function at exactly the six addresses above and nowhere else.

### So, in one paragraph

Per area: one theatre for each enemy front whose enemy holds at least eight provinces of adjacent land, or a large enough ratio of it; plus, for Germany and the United States only, a theatre seated on one of four named provinces when that province is in this area and under their control; plus, if none of that claimed anything, one theatre for the area. The candidate explanations the previous survey offered — land versus sea, home versus overseas, a fixed set of six roles — are all wrong.

## 2. `CAIInvasion::AddUnit` partitions by domain, and `+0x74` is the air list

**First, a correction of extent.** `FINDINGS-aitheatre.md` says `+0x54` is appended at `0x8A17BA`/`0x8A17D0` and `+0x64` at `0x8A182B`/`0x8A1841` *"in two small functions between slots 63 and 64 that were not read"*. There are no such functions. `AddUnit` (slot 63) runs `0x8A1680`–`0x8A1853` with the first `int3` at `0x8A1856`; `0x8A1860` is slot 64. All four of those addresses are inside `AddUnit`, and reading it through settles open item 5 **by proof rather than inference**:

    bool __thiscall CAIInvasion::AddUnit(CAIInvasion* this@ECX, CUnit* unit)

      if (unit->slot17())                       ; [vft+0x44]
          if already in +0x74 return true
          steal unit->+0x198 (slot 64 on the old owner, then +0x198 = this
                              unless +0x3D or +0x3E is set)
          push_back onto +0x74 / +0x78 / +0x7C
          return true
      if (unit->slot15())                       ; [vft+0x3C]
          if already in +0x54 return true
          unit->slot9()->+0x2E4 = 0
          steal unit->+0x198
          push_back onto +0x54 / +0x58 / +0x5C
          return true
      if (unit->slot16())                       ; [vft+0x40]
          if already in +0x64 return true
          0x89CA60()                            ; the same +0x198 steal, folded out
          push_back onto +0x64 / +0x68 / +0x6C
          return true
      return false

and `project.json`'s own `vftable_slots` already records **`CUnit` slot 15 = `IsLand`, slot 16 = `IsNaval`, slot 17 = `IsAir`**. So:

| list | head | populated when | the record says |
| --- | --- | --- | --- |
| land | `+0x54` | `IsLand` | land force — **correct, and now proved** |
| naval | `+0x64` | `IsNaval` | transports — **correct, and now proved** |
| air | `+0x74` | `IsAir` | *"every unit committed"* — **wrong** |

The three lists are a disjoint partition of the committed units by domain, and a unit that is none of the three is refused. `project.json`'s `units_first` on `+0x74` and `CAIInvasion::GetUnits` on `0x49F910` (slot 62) are both too wide; reported, not changed. That also tightens the already-recorded warning about `CUnit +0x198`: anything that reads that field and assumes a `CAIUnit` can get a `CAIInvasion`, and `+0x64` on one of those is the head of the naval list.

`0x89CA60` is worth a note of its own: it is a 44-byte compiler-folded fragment, entered by `call` and ending in a bare `ret`, that operates on **`edi` and `esi` from the caller's frame** (the unit and the invasion). It is not a method of anything.

## 3. Slots 60, 61 and 70

| slot | body | what it is | holders (`whoslot.py`) |
| --- | --- | --- | --- |
| 60 | `0x791940` | `lea eax,[ecx+0x54]` — the **land** list getter | **2** — `CAIInvasion` slot 60 and `CGraphicalTableLedger` slot 17 |
| 61 | `0x8E9090` | `lea eax,[ecx+0x64]` — the **naval** list getter | 1 |
| 62 | `0x89F910` | `lea eax,[ecx+0x74]` — the **air** list getter | 1 |
| 70 | `0x8A18E0` | below | 1 |

Trap 4 bites on slot 60 and only slot 60: two one-instruction accessors with the same displacement folded into one body, so naming `0x791940` `CAIInvasion::GetLandForce` would put that name on a table ledger's slot 17. It is left unnamed here. Slots 61 and 62 have one holder each and are safe.

Slot 70 (`0x8A18E0`, twelve instructions, `ret 8`):

    if (this->+0x88 && province->+0x2B4 == (this->+0x88)->+0x2B4) return
    0x897B40(this->+0x8C, arg1, province)

— a unit in the embarkation port's own area is the invasion's business; anything else is handed back to the owning `CEU3AI`. What the slot *means* to `CAIAgent`'s interface, and what `0x897B40` is, were not established.

## 4. `+0x84` and `+0x88` are the other way round

This is the correction that matters. `FINDINGS-aitheatre.md` and `project.json` both have `+0x84` as `staging_province` ("where it sails from") and `+0x88` as `landing_province` ("where it lands"), and `0x49FBC0` as `CAIInvasion::PickLandingSite`. **It is the reverse: `+0x84` is the objective in enemy territory, and `+0x88` is the friendly port of embarkation.** Five independent readings, from the producer, the consumer and the orders:

1. **The producer.** `CEU3AI::PlanAmphibiousInvasion` passes the ctor's second argument — the one the ctor stores at `+0x84` (`0x89F961`) — from `[esp+0x48]`, and `[esp+0x48]` is filled two ways, both inside the **target** area: either by a minimising distance search over that area's port list (`COwnerArea +0x48`, walked from `0x892C87`, best written at `0x893066`), where a candidate that passes `CCountry::IsFriendly` is *skipped* for the capacity read at `0x8930AD`; or by `0x893E70(ai, area, 0)` at `0x8930C6`, whose answer's `naval_base` capacity (`+0x300` then `+0x20`) is read immediately afterwards.
2. **`DoTick`.** `0x89FB40` re-runs the picker whenever `!0x4EF7C0(country, &(+0x88)->controller, 1)`. `0x4EF7C0` is `CCountry::IsFriendly` by `project.json`'s own entry, so **`+0x88` must be friendly-controlled** or the agent chooses another.
3. **Stage 2.** `0x8A0610` returns at once unless `CCountry::IsEnemy(country@ESI, &(+0x84)->controller@EDX)` holds (`0x8A0671`), so **`+0x84` must be enemy-controlled**. (`CCountry::IsEnemy` takes its receiver in **ESI**, the tag in **EDX** and a third thing in **EDI** — not `__thiscall`; `project.json`'s signature for `0x2F210` should be checked.)
4. **Stage 3, the orders.** At `0x8A101F`–`0x8A1040`, when `+0x90` is not yet `(+0x88)->+0xD0`, the fleet is given a **`transport`** order (save token `0x3A8`) to `+0x88`. Only once it is there does the code reach `0x8A104B`, test `IsEnemy` on `(+0x84)->controller`, and give the fleet the **`invasion`** order (token `0x3A5`) on a province derived from `+0x84`. Transport to `+0x88`, invasion at `+0x84`.
5. **Stage 1.** `0x8A01F0` marches the **land** force to `+0x88` through `CEU3AI::MoveUnit`, using `0x5A1A90` for a direct route and otherwise the nearest port in the unit's own area or in a *friendly* neighbouring area. You do not march a land army to an enemy beach.

The weights inside `0x89FBC0` read the same way once the roles are swapped. Lower is better, and the three multipliers are **0.3** (`[0x160A3E8]`) when the area's representative province is controlled by us (`0x89FF74` compares against `this->+0x38`), **0.75** (`[0x160A638]`) when the area holds *our own* acting capital (`0x89FF91`–`0x89FFAE`), and a penalty of 4.0 against 1.0/2.0 when the area is not the **candidate country's** capital area (`0x89FE2D`–`0x89FE3A`). A 0.3× preference for our own ground is absurd for a landing site and exactly right for a port of embarkation. The naval base term, `(1.5 - (navalBase->+0x20 / 1000) / 10.0) * w`, is the only one that can lower the score, so a port is what makes a province eligible — which was true in the old reading too, and is simply less strange now.

So the names should be:

| address / field | record | should be |
| --- | --- | --- |
| `0x49FBC0` | `CAIInvasion::PickLandingSite` | `CAIInvasion::PickEmbarkationPort` |
| `CAIInvasion +0x84` | `staging_province` | the **objective** — enemy-held, set at construction, re-pointed within its own area by `0x893E70` |
| `CAIInvasion +0x88` | `landing_province` | the **port of embarkation** — friendly-held, re-chosen whenever it stops being so |
| `CAIInvasion +0x90` | `landing_province_id` | the province id the force is **currently ordered to**: initialised to `(+0x88)->id`, overwritten by stage 1 with an intermediate port and by stage 3 |

and the function that really chooses where the troops come ashore is **`0x893E70`**, called from the planner with `invasionOrNull = 0` and from stage 3 with the objective's own area, its answer written into `+0x84` immediately before the `invasion` order is issued on it.

## 5. The stage machine

`DoTick` (slot 73) calls three functions in order. All three are `void __stdcall (CAIInvasion*)`, `ret 4`, with clean `int3` boundaries at `0x8A0605`, `0x8A09AB` and `0x8A11AB`.

### Stage 1 — `0x8A01F0`, march the land force to the port

Over `+0x54`: skip a unit whose `slot9()` object has `+0x300` set, or whose current province's map data (`+0xD4`) has the `+0x22` byte clear. Then **drop** the unit — onto a local list that is fed to slot 64 (`RemoveUnit`) at `0x8A05C0`–`0x8A05D0` — when either `0x8A11B0(this, unit)` answers true or `unit->+0x128 != this->+0x38`. Otherwise:

    dest = GetMovementDestinationProvince(unit) ?: unit->+0x130
    if (dest == this->+0x88)       order->+0x2E4 = dest->id ; done
    if (dest->id == order->+0x2E4) remember dest->id        ; already en route
    if (0x5A1A90(&this->tag, unit->province, this->+0x88, &out))
        MoveUnit(unit, (+0x88)->id, 0, 1, 1, this)
    else
        best over unit->province->area->+0x48 (the area's ports), by
            0x4A5570(port, (+0x88)->id)/1000 and 0x4D52A0(country, +0x88, port, 0);
        failing that, the same over every port of every neighbouring area
            (area->+0x34) whose controller passes CCountry::IsFriendly;
        then MoveUnit to it and set +0x90 to its id

`0x8A11B0` (`bool __fastcall (this@ECX, CUnit* unit@EAX)`, bare `ret`) is the "you can walk there" test, and it is the exact mirror of the planner's `AreaIsConnectedTo` gate. True when the unit's province *is* `+0x84`, when its area is `+0x84`'s area, when `0x4A6B00(province@EAX, objectiveArea)` holds, or when a neighbouring area of the unit's is enemy-controlled **and** `AreaIsConnectedTo(unitArea, objectiveArea)`. False early when `0x4A56B0(province, 0)` is false, when the unit's area is `+0x88`'s, or when it is our acting capital's. A unit that can march to the objective is thrown out of the invasion.

### Stage 2 — `0x8A0610`, load at night

Preconditions, in order: `+0x6C == 1`; the single naval unit's `COrder` (`CUnit +0xB0`) answers save token `0x3A5` (`invasion`) from slot 16; `CCountry::IsEnemy((+0x84)->controller)`. Then a **night** window:

    hour = (gamestate->+0xBDC - 0x29C55C0) % 24
    proceed only if hour <= 0x4A7450(province) or hour >= 0x4A74D0(province)
    remaining = 0x4A7450(province) - hour
    if (remaining < 3) return
    deadline = now + remaining

and `0x5D6880(&(+0x84)->+0x2B8, tagChars, tagId)` must answer non-null. It then picks **up to three** land units standing in the fleet's own province (`+0x130` equal, `+0x110 == 0`, `+0x140 <= 0`, `+0x11C <= 0`), scored by the two floats `0x5C7250` returns against the `0.5` at `0x15AB304` and the `0.33` at `0x160A958`, and for each issues

    0x89AD00(ai, 0x6FB /*ground_attack*/, unit, (+0x84)->id, &{(+0x84)->id}, &now, &deadline, 0x1A8CC94)

So the AI loads its invasion force **only in the dark, and only with at least three hours of darkness left**, and the order it writes expires at sunrise. The two province functions `0x4A7450` and `0x4A74D0` take the province in **ESI** and are, on this evidence, sunrise and sunset; that is an inference from the modulo-24 comparison, not a reading of their bodies.

### Stage 3 — `0x8A09B0`, sail and issue the invasion order

A first pass over `+0x64` cleans up each fleet's order through `0x89ABD0`, issuing `0x18D` (`none`) when `slot11()->+0x2EC <= 0` and the order's slot 24 agrees, or `0x3A8` (`transport`) when the current order is neither `0x4E5` (`support_attack`) nor `0x56C` (`carrier_protection`) and the fleet is not already at `+0x90`. A second pass counts the loaded land units and their readiness, building the `0x8C`-byte object at `0x8A0F46` through `0x5E3A20` and handing it to `gamestate->+0xBE8`'s slot 18.

Then the decision, at `0x8A100B`:

    if (+0x90 != (+0x88)->id) {
        0x89ABD0(ai, 0x3A8 /*transport*/, fleet)     ; EDI = (+0x88)->id
        +0x90 = (+0x88)->id
        return
    }
    if (IsEnemy(us, &(+0x84)->controller)) {
        area = (+0x84)->+0x2B4
        +0x84 = 0x893E70(ai, area, this)
        if (!+0x84) { 0x894C40(ai@ESI, area); +0x3E = 1; return }
        0x89ABD0(ai, 0x3A5 /*invasion*/, fleet)      ; EDI = (+0x84)->id
    } else {
        if (area->+0x2C >= 4) goto transport
        count the land units in the area whose owner is NOT an enemy
        if (count <= area->+0x2C * 10) goto transport
        if (!0x894A70(ai, +0x84))      goto transport
        0x89ABD0(ai, 0x3A5 /*invasion*/, fleet)
    transport:
        0x89ABD0(ai, 0x3A8 /*transport*/, fleet)     ; EDI = (+0x84)->id
    }

`0x89ABD0` is the three-stack-argument wrapper `(CEU3AI*, SaveToken, CUnit*)` with **the destination province id in EDI** — consistent at all five call sites, where EDI is loaded in the instruction immediately before the pushes — and it tail-calls `0x89AD00` at `0x89ACD0`. `0x89AD00` is the order factory: for `0x3A5` it first walks `ai->+0x40` setting every unit agent's `+0x86 = 1`, refuses outright when `unit->+0x158` is non-zero, and then allocates a `0xA0`-byte `COrder` subclass.

The `else` arm — objective no longer enemy-held, small area, more than ten friendly land units per province, then still an `invasion` order — reads oddly and is recorded as read rather than explained.

## 6. `CCountry +0xF98` is not `enemies`, and the owner is always in it

The membership walk is `CCountry::RebuildNeighbours` (`0x4E21E0`) at `0x4E32E9`–`0x4E338E`, with the pair's `CDiplomacyStatus*` in `[esp+0x14]` and the other country's id in `edi`:

    if (status->+0x58 == 0)            skip          ; a BYTE test
    if (edi == us->+0xCA8)             append        ; <-- ourselves, unconditionally
    else if (us->+0xE28[edi]->+0x20)   skip          ; `war`
    else if (other is REB)             skip
    else if (us is REB)                skip
    append to +0xF98 / +0xF9C / +0xFA0               ; nodes 0x14 bytes

The unconditional self-insertion at `0x4E32F7` is the part the previous survey did not have, and it is what makes the list make sense: **`+0xF98` is us plus every country at `+0x58` that we are not at war with.** `0x89FBC0` iterates it looking for a port to load troops in, which is precisely why belligerents are excluded and why we are always a member. The obvious name was indeed wrong.

The field has **seven readers and every one is in the AI layer** — `0x88D14F` (in `0x88C140`), `0x895A62` (in `0x895530`), `0x897826` (in `0x8976E0`), `0x89FD52` (in `0x89FBC0`), `0x8AC3A9` (in `0x8AC390`), `0x8CC823` (in `0x8CC690`), `0x8D9F76` (in `0x8D9E30`) — plus the clear in `0x4D2B60`, the write in the constructor `0x4C8A40` and the destructor's `lea` in `0x4CA740`. Since only one of the seven was followed, the name proposed in `project.json` is taken from the **membership rule** rather than from that single use, per trap 14: `non_hostile_countries`.

`CDiplomacyStatus +0x58` is still not identified, but one guess can be eliminated: it is **not** `military_access`, which `fieldmap.py CDiplomacyStatus` places at `+0x4C` (save token `0x2F0`). `+0x58` is not a save key at all — the loader's keys around it are `+0x50 last_send_diplomat`, `+0x54 last_war` and `+0x5C threat` — and `RebuildNeighbours` only reads it. The cheapest live check is to dump the whole `CDiplomacyStatus` array for one country in a running game and see which pairs have the byte set.

## 7. Everything above that disagrees with the existing record

Reported, not overwritten.

| record | evidence against |
| --- | --- |
| `CAIInvasion +0x84` = `staging_province`, "where it sails from" | the planner picks it inside the **target** area; stages 2 and 3 require `IsEnemy` on its controller; stage 3 issues the `invasion` order on it |
| `CAIInvasion +0x88` = `landing_province`, "where it lands" | `DoTick` requires `CCountry::IsFriendly` on its controller; stage 1 marches the land force there overland; stage 3 issues a `transport` order to it |
| `0x49FBC0` = `CAIInvasion::PickLandingSite` | its three score multipliers all favour our own and our capital's ground; it iterates a country list that excludes everyone we are at war with. It picks the port of embarkation |
| `0x4EF7C0` described as "is this still a country I may land on" | `project.json` already names it `CCountry::IsFriendly`, and the test is on `+0x88` |
| `CAIInvasion +0x74` = `units_first`, "every unit committed"; `0x49F910` = `GetUnits` | `AddUnit` reaches `+0x74` only through `CUnit` slot 17, which `project.json` records as `IsAir` |
| "`+0x54` is appended at `0x8A17BA` … in two small functions between slots 63 and 64" | there are no such functions: `AddUnit` is `0x8A1680`–`0x8A1853`, first `int3` at `0x8A1856` |
| the land/transport split marked **inferred** | it is now read: `CUnit` slots 15/16/17 against `+0x54`/`+0x64`/`+0x74` |
| `CCountry::IsEnemy` (`0x42F210`) signature | receiver in **ESI**, tag in **EDX**, a third operand in **EDI**; not a `__thiscall` |

Two additions to `TRAPS.md`:

- **Trap 2, known pairs:** add `0x893C80`/`0x893E70`. The first ends `ret 8` at `0x893E6D` with no padding, so `image.functionStart(0x893E70)` answers `0x893C80`; `0x893E70` has its own prologue and SEH push and is a real entry.
- **Trap 4:** `0x791940` is a new folded one-liner — two holders, `CAIInvasion` slot 60 and `CGraphicalTableLedger` slot 17 — and it is exactly the shape that invites a wrong class name.

## 8. A negative, with its control

The one negative claim attempted here **failed its control and is therefore not made.** A scan for stores into `CCountryDataBase`'s first `0x178` bytes, following the register loaded from the singleton `0x1A855A4` forward for `0x80` bytes across all 2464 references, found zero stores — but the same scan also failed to find `BuildTheatres`' own well-known *reads* of `+0x4` and `+0x1C`, because it stops at the first `call` and the lazy-singleton construction puts a `call` between the load and the use. So that scan says nothing, and the identification of `db +0x0` as GER and `db +0x18` as USA rests instead on the 45-arm store chain in `0x515CC0`, which is positive evidence.

## What is not established

1. **`CDiplomacyStatus +0x58`**, the byte that gates `CCountry +0xF98`. Not a save key; only read in `RebuildNeighbours`; not `military_access` (`+0x4C`). Cheapest live check: dump one country's whole `+0xE28` array and see which pairs carry it.
2. **`0x1B15028`** (rva `0x1715028`), the front-versus-area ratio threshold at `0x8AA09C`. It is in zero-initialised `.data`, so there is no static value. Cheapest live check: read the dword out of the process.
3. **`0x4AF580`** (`CTheatre::AddFront` as proposed) — only its first ~60 instructions were read. Whether it appends the `CAreaBorder` to `CTheatre +0x50` was not checked, and the `CTheatre +0x60` list that `AddProvince` also fills was not traced to a save key either way.
4. **`0x893E70`**, the real landing-province chooser, was read only through its two call sites. Its body is the last piece of the invasion chain still unread, and it is now the most valuable single function in this layer.
5. **`0x8A9390`** — the predicate `BuildTheatres` and `0x47DA40` both apply to a front's `local_enemy`. Signature only.
6. **`0x4A56B0`** still has no name. It is the 10× penalty in `PickEmbarkationPort`, a hard disqualifier for a hardcoded theatre seat, and a gate in `0x8A11B0`; it requires `province->+0x330` non-zero and then walks the province's adjacency list skipping entries of type 3. "Isolated / no land link" fits all three uses but was not proved.
7. **The remaining helpers** read only as shapes: `0x5A1A90` (route exists), `0x4D52A0` (reachability), `0x4A5570` (distance, thousandths), `0x4A6B00`, `0x5D6880`, `0x5C7250` (two floats off a land unit), `0x5CEFB0`, `0x5E3A20`, `0x5C0160`, `0x894A70`, `0x894C40`, `0x897B40`, `0x47FD90`.
8. **`COwnerArea`'s remaining layout.** `+0x24`/`+0x2C`, `+0x34`, `+0x48`/`+0x50` and `+0x74` are placed here; slot 0 is a bool that gates an area everywhere, and is unidentified. `+0x30`–`+0x33`, `+0x38`–`+0x47` and the rest were not touched.
9. **Nothing was watched in a running game.** Three cheap live checks this file adds to the three the previous one left: a `CTheatre` with a key province should exist only for GER at Paris or Warszawa and for USA at San Fransisco or Washington D.C.; `CTheatre +0x70` (`hot`) should be set on exactly those theatres whose originating `CAreaBorder` has `front = yes`, and clear on all four hardcoded ones; and a live `CAIInvasion` should have an **enemy**-controlled province at `+0x84` and a **friendly**-controlled one at `+0x88`, which is the one-line falsification of section 4.
