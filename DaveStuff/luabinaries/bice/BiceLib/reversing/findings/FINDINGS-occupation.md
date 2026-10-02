# Occupation, revolt risk, partisans and rebels

Read out of `hoi3_tfh.exe` on 2026-09-30, statically. Addresses are **virtual** (base
`0x400000`) with the rva beside them, because `project.json` wants rvas and the
disassembler prints virtual addresses. Nothing here was measured in a running game.

**In one line.** Occupation is not a special case in the engine: a `COccupationPolicy`
*is* a `CModifier`, and the whole of it is added into the occupied province's modifier
values by the province modifier rebuild. Revolt risk is one accumulator per province
(`CProvince +0x328`) that the daily pass moves by a **hardcoded plus or minus 0.1 a day**
while the controller is at war with the owner, and what the game reads is that accumulator
plus `LOCAL_REVOLT_RISK` plus the controller's `GLOBAL_REVOLT_RISK` minus the province's
garrison suppression, floored at `MINIMUM_REVOLT_RISK`. Partisans and rebels are brigades
created for a `CRebelFaction`; the two creation paths read here are the government-in-exile
underground mobilisation and the province revolt.

---

## 1. Revolt risk

### 1.1 The accumulator and what changes it

`CProvince +0x328` (`revolt_risk`, thousandths, already in the record) is moved in exactly
one place: **the daily province pass at `0x49EAB0` (rva `0x9EAB0`)**.

That function is `f(CMapProvince*)`, `ret 4`, and it is called once per province from a
plain serial loop at `0x682E4B`:

    0x00682E41  mov ecx, [ebx + 0xb8c]        ; the province vector
    0x00682E47  mov edx, [ecx + esi*4]
    0x00682E4A  push edx
    0x00682E4B  call 0x49eab0

`0x682E4B` lies inside **`RunDailyPass`** (`0x682C20`..`0x683077`), not `RunHourlyPass` -
the two abut, which is the trap `FINDINGS-tick.md` already names, and `image.functionStart`
answers `RunHourlyPass` for this address. `FINDINGS-tick.md` already lists `0x49EAB0` in
`RunDailyPass`'s callee list without saying what it is. **The loop is serial on the calling
thread; no TBB task is involved**, so this is hookable from BiceLib on the game thread.

The revolt-risk block runs at `0x49EE0F`..`0x49EED6`:

    controller = CountryOf(province->controller_tag)            ; +0x334, via 0x402610
    if (province->owner_id == controller->id)  goto floorAtZero ; +0x330 vs +0xCA8
    ; --- inlined CCountry::IsEnemy, byte for byte the same as 0x42F1B0 ---
    status = controller->statuses[province->owner_id]           ; +0xE28
    if (status->+0x20 == 0
        && province->owner_tag != 'REB'                        ; +0x32C
        && controller->tag     != 'REB')      goto floorAtZero  ; +0xCA4
    ; --------------------------------------------------------------------
    ceiling = provinceValues[MODIFIER_LOCAL_PARTISAN_SUPPORT]   ; [[p+0x114]+0x260]
    step    = 0.100                                            ; g at 0x1A86CF4
    if (province->revolt_risk > ceiling) step = -0.100
    suppress = min( province->suppression * 0.100, 0.200 )      ; +0x28, g at 0x1A86CD0
    province->revolt_risk += step - suppress
    if (province->revolt_risk > ceiling) province->revolt_risk = ceiling
  floorAtZero:
    if (province->revolt_risk < 0) province->revolt_risk = 0

Written the way a modder thinks, with `local_partisan_support` and revolt risk both in
percentage points (that is the unit `common/occupation_policies.txt` uses - 9, 16, 25):

| condition | change per day |
| --- | --- |
| owner controls the province, or controller is not at war with owner | **none** |
| garrison suppression 0 | **+0.1** |
| garrison suppression 1.0 | **0.0** |
| garrison suppression 2.0 or more | **-0.1** |
| already above `local_partisan_support` | `-0.1 - min(suppression*0.1, 0.2)`, then clamped down to `local_partisan_support` |

and it is clamped to `[0, local_partisan_support]` afterwards - the floor at 0 runs on every
province every day, the ceiling only on the branch that changed it.

**Three things a modder will want from that.**

- `local_partisan_support` is the **cap on a province's accumulated revolt risk**, not a
  separate partisan statistic. `MODIFIER_LOCAL_PARTISAN_SUPPORT` is modifier id `0x4C`
  (76), so `+0x260` in the values array, and `0x49EE77` is the read.
- **The step and the suppression cap are compiled into the exe.** They are the two
  fixed-point globals `0x1A86CF4` and `0x1A86CD0`, built at startup by the initialisers at
  `0xCB0FA0` and `0xCB1030` from the floats 100.5 and 200.5 at `0x160A684` and
  `0x160A64C` (`0x401FD0` is `floor`, `0xC08870` the float-to-int, so they land as 100 and
  200 thousandths). **No `defines.lua` entry touches them.** Both globals are also read by
  unrelated code (`0x4A3B12`, `0x4A3B1A` in the building-level change at `0x4A39B0`), so
  they are generic 0.1 and 0.2 constants and must not be named after revolt.
- The gate is **`controller->IsEnemy(owner)`**, inlined. Identical code is
  `CCountry::IsEnemy` at `0x42F1B0` (rva `0x2F1B0`), already in the record. So revolt risk
  does **not** accumulate in a province you occupy from somebody you have peace with - and
  it *does* accumulate whenever either side is `REB`, because `IsEnemy` answers true for
  `REB` unconditionally.

`CDiplomacyStatus +0x20` is the war between the pair - non-null means at war. That is read
off `IsEnemy`'s shape rather than from the writer, so it is **inferred**; the record has no
name at that offset.

### 1.2 What the game actually reads: the effective revolt risk

`0x4A4050` (rva `0xA4050`) is the getter. It has a **register convention** - its address is
taken nowhere - province in `edi`, the out `int*` in `esi`, one dword pushed and left for the
caller, plain `ret`:

    *out = 0
    if (CountryOf(province->controller_tag)->IsEnemy(&province->owner_tag))
        *out = province->revolt_risk                            ; +0x328
    if (province->controller_id != 0) {
        c = CountryOf( controller_tag == 'REB' ? province->owner_tag
                                               : province->controller_tag )
        *out += c->countryValues[MODIFIER_GLOBAL_REVOLT_RISK]    ; [[c+0xDA8]+0x10]
    }
    *out += provinceValues[MODIFIER_LOCAL_REVOLT_RISK]           ; [[p+0x114]+0x8]
    *out -= province->suppression                                ; +0x28
    return out

So all three of the first three modifiers are accounted for:

    revolt_risk_shown =
        max( MINIMUM_REVOLT_RISK(province),
               (controller at war with owner ? province.revolt_risk : 0)
             + GLOBAL_REVOLT_RISK(the country whose revolt this is)
             + LOCAL_REVOLT_RISK(province)
             - suppression(province) )

The `max` with `MINIMUM_REVOLT_RISK` is **not** inside `0x4A4050`. It is applied by the
caller, and that is exactly what separates the two script triggers:

| trigger | vftable | slot 6 | what it compares |
| --- | --- | --- | --- |
| `CRevoltRiskTrigger` | `0x15F87E0` | `0x9E7590` (rva `0x5E7590`) | `max(provinceValues[MINIMUM_REVOLT_RISK] clamped at >= 0, 0x4A4050)` > `value * 1000` |
| `CPureRevoltRiskTrigger` | `0x15F8814` | `0x9E6940` (rva `0x5E6940`) | `0x4A4050` > `value * 1000`, no floor |

`0x9E7649`..`0x9E7660` is the floor:

    0x009E7644  call  0x4a4050
    0x009E7649  mov   ecx, [edi + 0x114]       ; the province's values
    0x009E764F  mov   eax, [ecx]               ; values[MINIMUM_REVOLT_RISK]
    0x009E7652  test  eax, eax
    0x009E7654  jns   0x9e7658
    0x009E7656  xor   eax, eax                 ; a negative minimum counts as 0
    0x009E765B  cmp   ecx, eax
    0x009E765D  cmovl ecx, eax                 ; max(revoltRisk, minimum)

**So `revolt_risk` in a trigger is the effective figure and `pure_revolt_risk` the same
figure without the minimum floor.** The two differ only when `minimum_revolt_risk` exceeds
everything else, and `pure_` is the one that can read the negative values a big garrison
produces.

`0x4A40E0` (rva `0xA40E0`) is a three-instruction accessor that writes the raw `+0x328`
into an out pointer; it has one call site (`0x5FE390`) and is in no vftable.

### 1.3 Suppression: `CProvince +0x28`

`+0x28` is recomputed once a day, in the same pass, immediately before the revolt-risk
block:

    0x0049EDF7  mov  edi, ebx                  ; the province
    0x0049EDF9  call 0x49f360
    0x0049EE02  mov  eax, [eax]
    0x0049EE04  mov  [ebx + 0x28], eax

`0x49F360` (rva `0x9F360`), province in `edi`, out `int*` on the stack, `ret 4`:

    *out = SuppressionIn(province)                              ; 0x49F250
    for each p in province->+0x14C .. +0x150                    ; the adjacency vector
        if (p->path_node->is_land                               ; [p+0xD4]+0x22
            && p->controller_id == province->controller_id)      ; +0x338
            *out += SuppressionIn(p)

`0x49F250` (rva `0x9F250`), province in `eax`, out `int*` on the stack, `ret 4`:

    *out = 0
    for each unit in province->units                            ; +0x2B8
        if (!CountryOf(unit->owner_tag)->SameSide(&province->controller_tag, true))
            continue                                            ; 0x4EF7C0
        strength = sum over unit->regiments of regiment->+0x5C   ; +0x38, CRegiment +0x5C
        ratio    = strength * 1000 / unit->GetMaxStrength()      ; vtable slot 23
        *out    += ratio * unit->definition->suppression / 1000  ; [unit+0xC8]+0x130
    *out = *out / 10                                            ; x1000 then /10000

`CSubUnitDefinition +0x130` is `suppression`, already in the record, and that is what pins
this function. Two things worth a modder's attention:

- **suppression is taken once from `CUnit +0xC8`** - but that is **not** the same as "not
  summed over its brigades", which is what this said until 2026-10-01 and which was wrong.
  `+0xC8` is a `CSubUnitDefinition` the division **owns**, rebuilt by
  `CUnit::RebuildDefinition` (rva `0x1B5ED0`) by summing each brigade's own definition
  (`CSubUnit +0x58`) into it across 60 fields through `0x1A7FC0`, and `suppression` (`+0x130`)
  is one of the plain sums. So a division's suppression **is** the total of its brigades',
  scaled by how intact the division is. One read of an aggregate is not evidence of no
  aggregation. See `FINDINGS-unitdef.md`.
- **a unit suppresses its own province and every adjacent land province under the same
  controller**, so one garrison covers a cluster; and the `/10` at the end means the number
  that lands in `+0x28` is suppression times 100 in thousandths, so a brigade with
  `suppression = 2.0` at full strength contributes 0.2 to the figure that both the daily
  step and the effective revolt risk use.
- **So the real figures are per *division*, not per brigade.** With brigade suppression summing
  into the division's definition, a full-strength division contributes
  `(sum of its brigades' suppression) / 10`. At BlackICE's values that is 1.8 for three
  `garrison_brigade` (6 each), 2.55 for three militia (8.5), 0.3 for three infantry (1). The
  daily step freezes at a province total of 1.0 and saturates at 2.0, so **one properly built
  garrison or militia division saturates its province and every same-controller land
  neighbour** - which is a different conclusion from the per-brigade reading this file
  originally carried.

The friendly test at `0x4EF7C0` returns true at once when the tags match and otherwise goes
to the faction/alliance database, so an allied garrison counts. It is not named here - it is
a general diplomacy helper, not a revolt one.

### 1.4 Where the occupation policy enters the province's modifier values

`0x49F3E0` (rva `0x9F3E0`, `ret 4`, ends `0x4A0673`) is the **province modifier rebuild** -
it writes `CProvince +0xFC`'s values array, which is what `+0x114` points into. The daily
pass calls it at `0x49EE0A` behind a local flag, and the full-revolt path calls it at
`0x65BF7A` just before spawning.

Inside it, at `0x49FBE2`:

    if (province->owner_id == province->controller_id) skip
    if (province->controller_tag == 'REB')             skip
    controller = countryDb->byId[province->controller_id]    ; [0x1A855A4]+0x16C
    policy     = controller->statuses[province->owner_id]->+0x10
    if (!policy) skip
    for id in 0 .. modifierDefinitionCount                  ; ([0x1A86198]-[0x1A86194])/4
        provinceValues[id] += policy->values[id]            ; policy is a CModifier, +0x18

`CDiplomacyStatus +0x10` is `occupation_policy` - that is read off the loader
(`CDiplomacyStatus::LoadKey`, `0xA48190`, key `occupation_policy`, token `0x57C`), not
guessed. And RTTI says **`COccupationPolicy : CModifier`**.

**That is the whole occupation penalty.** There is no separate hardcoded reduction to IC,
resources, manpower or leadership for an occupied province: `local_ic`, `local_resources`,
`local_manpower_modifier`, `local_leadership_modifier`, `local_partisan_support` and
`local_revolt_risk` out of `common/occupation_policies.txt` are added into the province's
modifier values here and then consumed by the ordinary IC, resource, manpower and revolt
paths. Which is also why `local_partisan_support` and `local_revolt_risk` in that file
reach revolt risk by two different routes - one as the cap on the accumulator, one as a
flat addend on the effective figure.

Note the `REB` exclusion: **a province that `REB` controls gets no occupation policy
modifier at all**, whatever policy the pair has.

---

## 2. Partisans from an underground

`0x50B630` (rva `0x10B630`), `ret 8`, taking `(CCountry* exile, CMapProvince* source)` on
the stack. It is the only function in the image that logs
`"Failed to spawn partisant from underground at location "` (`country.cpp`, at `0x50BA2B`).

    ; pick where the partisans appear
    edges  = source->path_node->+0x90 .. +0x94        ; stride 0x14, ProvinceEdge
    target = source                                   ; the default
    pick a random edge (0xAA2F80 % edgeCount)
    if (that neighbour is in a real area && neighbour->owner_id == source->owner_id)
        target = that neighbour
    else
        walk the edges in order and take the first that passes the same two tests
    if (target is in no real area) -> log the failure and return

    ; create them
    faction = 0x4C0430( the global at 0x1A871D8, target, 1, &exile->tag )
    0x4C1160( this = target, faction,
              UNDERGROUND_SPAWN_STRENGTH / 1000, true, &exile->tag )

    ; pay for them
    u = source->underground_building                   ; +0x30C
    u->level_current -= SPAWN_PARTISAN_LIMIT           ; +0x24, floored at 0
    u->+0x28 = (level changed)                         ; the dirty byte

So, in modder terms:

- **the partisans do not appear in the province with the underground**; they appear in a
  neighbour that the same country *owns*, picked at random among the qualifying neighbours,
  and only fall back to the underground's own province when no neighbour qualifies;
- **the brigade count is `UNDERGROUND_SPAWN_STRENGTH`** (military block, `CDefines+0xAC`
  `+0x264`), truncated to a whole number, and `0x4C1160` clamps it to at least 1;
- **the cost is `SPAWN_PARTISAN_LIMIT` levels off the source province's `underground`
  building**, floored at 0. The same define is the *threshold* elsewhere (below), so it is
  doing double duty as "the level one mobilisation needs" and "the level one mobilisation
  burns".

`SPAWN_PARTISAN_LIMIT` is at `CDefines+0xAC` `+0x248` and the image reads it in five places,
four of them in this cluster (`0x50B0BD`, `0x50B20F`, `0x50B485`, `0x50B4D3`) plus
`0x88A4F1`; `definesMap.py` run backwards is how they were found.

### The availability checks around it

`0x50AFD0` (rva `0x10AFD0`), thiscall on a `CCountry`, `ret 4`, builds the
tooltip/availability text for mobilising undergrounds:

    if (!this->+0x95) -> 'WE_NOT_GOVERNMENT_IN_EXILE'
    total = 0 ; ready = 0
    for each province the country OWNS (province->owner_id == this->id, over +0xD60)
        total++
        if (province->underground_building->level_current > SPAWN_PARTISAN_LIMIT) ready++
    if (ready == 0) -> 'UNDERGROUNDS_NOT_PREPARED' with TOTAL = total
    else            -> the ready/total text

**`CCountry +0x95` is the government-in-exile flag.** The record currently names it
`use_own_pool` with the comment "when set, GetPool answers the country's pool at `+0x9F8`
instead of the capital's". Both readings can be true of the same byte - an exile has no
capital to draw a pool from - but the name is describing a consequence rather than the
field. This finding does not redefine it; see *Contradictions*.

Two sibling functions do the same job for the two player-facing actions, with the same shape
and the same `LIMIT` / `CURRENT` / `UNDERGROUND_NOT_STRONG_ENOUGH` keys: `0x50B4A0`
(`MOBILIZE_PARTISANS`, reads `SPAWN_PARTISAN_LIMIT` at `0x50B485` and `0x50B4D3`) and
`0x50BB60` (`MOBILIZE_UNDERGROUND`, reads `SPAWN_UNDERGROUND_LIMIT` at `0x50BB49` and
`0x50BB93`). `0x50B1E0` is a second, whole-country variant of `0x50AFD0`.

### The rest of the underground cluster

`definesMap.py` backwards puts the whole underground model in one block of the image, and
none of it was named before:

| define | `CDefines+0xAC` | read at | in |
| --- | --- | --- | --- |
| `MAX_UNDERGROUND_DISTANCE` | `+0x250` | `0x509067`, `0x5092A6` | `0x509050`, `0x509230` |
| `UNDERGOUND_INITIAL_STRENGTH` (sic) | `+0x254` | `0x50925A`, `0x5092B7` | the same two |
| `UNDERGROUND_STRENGTH_GAIN` | `+0x258` | `0x50A1B7` | `0x50A110` |
| `UNDERGROUND_DETECT_CHANCE` | `+0x25C` | `0x50A1CB` | `0x50A110` |
| `SPAWN_PARTISAN_LIMIT` | `+0x248` | `0x50B0BD`, `0x50B20F`, `0x50B485`, `0x50B4D3` | the tooltips |
| `UNDERGROUND_SPAWN_STRENGTH` | `+0x264` | `0x50B69C` | `0x50B630`, the spawn |
| `SPAWN_UNDERGROUND_LIMIT` | `+0x24C` | `0x50BB49`, `0x50BB93` | `0x50BB60` |
| `UNDERGROUND_PARTISAN_STRENGTH` | `+0x260` | - | **no reader found** |

`0x50A110` (rva `0x10A110`, 0xD30 bytes) is the underground's own periodic work - it reads
both `UNDERGROUND_STRENGTH_GAIN` and `UNDERGROUND_DETECT_CHANCE`, reads
`provinceValues[MODIFIER_LOCAL_PARTISAN_SUPPORT]` at `0x50A278`, and builds the
`OURUNDERGROUNDREMOVED` and `UNDERGROUNDREMOVED` messages with `COUNTRY` and `PROV`
parameters. It is **not read here**; it is the largest single lead left in this domain.

`UNDERGROUND_PARTISAN_STRENGTH` is pushed by `CDefines::Load`, so it is stored, but the
backwards scan finds nothing reading `CDefines+0xAC` `+0x260` anywhere in the image. That is
the `WHITESEA` case in `definesMap.py`'s docstring one step further on: the engine reads the
key and then never uses it. Treat it as **likely dead**, with the caveat that the scan only
follows a block pointer taken from `GetDefines`'s return within one function.

---

## 3. `CRebelFaction` and `CRebelType`

### 3.1 Layout, from the loaders

`fieldmap.py` reads both loaders cleanly, and the runtime code agrees with every offset it
gives. **`CRebelType`** (`common/rebel_types.txt`, `CRebelType::LoadKey`):

| key | offset | note |
| --- | --- | --- |
| `spawn_chance` | `+0x28` | a factor/modifier block, read into |
| `movement_evaluation` | `+0x44` | the same shape |
| `siege_won_trigger` | `+0x60` | |
| `can_enforce_trigger` | `+0xE0` | |
| `siege_won_effect` | `+0x120` | |
| `demands_enforced_effect` | `+0x160` | |
| `area` | `+0x180` dword | |
| `ideology` | `+0x184` dword | |
| `unit` | `+0x188` dword | the `CSubUnitDefinition*` the brigades are built from |
| `defection` | `+0x18C` dword | |
| `independence` | `+0x190` dword | |
| `defect_delay` | `+0x194` dword | |
| `resilient` | `+0x198` byte | |
| `reinforcing` | `+0x199` byte | |
| `smart` | `+0x19A` byte | |
| `auto_convert` | `+0x19B` byte | |

`is_triggered_only` is in the switch but lands nowhere the walker can see.

Two independent runtime confirmations: `0x686D1D` tests `type->+0x190` (`independence`)
before it will match a faction to a province, and the record's own note on
`CUnit::RetreatFromCombat` says the `REB` path needs "a flag at `+0x30`'s `+0x198`" -
`+0x30` is the faction's type and `+0x198` is `resilient`.

**`CRebelFaction`** (`CReferenceObject` base, vftable `0x15C0B6C`, 8 slots):

| key | offset | note |
| --- | --- | --- |
| `id` | `+0x8` | from the shared one-key `id` base; `+0x8` type, `+0xC` value |
| `type` | `+0x30` | the `CRebelType*` |
| `province` | `+0x34` | |
| `country` | `+0x38` | whose rebels these are; `CCountryTag` is 8 bytes, so the tag is at `+0x38` and its id at `+0x3C` |
| `government` | `+0x40` | |
| `independence` | `+0x44` | the country it wants released, its id at `+0x48`; **the daily faction pass deletes the faction the moment that country exists** |
| `target` | `+0x74`, `+0x78` | **the record already has `+0x70`/`+0x74`/`+0x78` as the targets list**, first/last/count; what `fieldmap.py` sees as two dwords is the push_back updating the tail and the count, not an id pair |
| `army` | `+0x84`, `+0x88` | the same shape: the record has `+0x80`/`+0x84`/`+0x88` as the armies list, and `fieldmap.py` is seeing the tail and count |
| `provinces` | `+0x94` | the record calls this a **vector** of ids ending at `+0x98`; the daily pass walks it as a **linked list**, payload at `+0x0` and next at `+0x8` - see *Contradictions* |
| - | `+0x90` | the **"delete me" byte**, set by the daily pass |

### 3.2 The daily pass

`RunDailyPass` walks the rebel factions itself, right after the province loop:

    0x00682E64  mov edi, [ebx + 0xc7c]        ; rebel_factions, already in the record
    0x00682E72  mov esi, [edi]
    0x00682E78  call 0x4b9d60                 ; the faction's daily work
    0x00682E7D  cmp byte [esi + 0x90], 0      ; did it ask to die?
    ...         unlink from +0xC7C/+0xC80, free it, dec +0xC84

so **a rebel faction is updated once a day and can remove itself the same day**, unless
`CCurrentGameState +0xC88` is set, in which case it is only marked (`+0xC` on the node) and
left in the list - that looks like an iteration guard.

`0x4B9D60` (rva `0xB9D60`, `f(CRebelFaction*)`, `ret 4`) opens with the two death tests:

    0x4BD4E0(faction)                                        ; not read here
    if (CountryOf(faction->country_tag)->+0xCF8 <= 0
        && faction->type->area == 0)        -> faction->+0x90 = 1 ; return
    if (faction->independence.id != 0            ; +0x48
        && CountryOf(faction->independence_tag)->+0xCF8 > 0)
                                           -> faction->+0x90 = 1 ; return

then walks `faction->provinces` (`+0x94`), and for each province id whose province is
**controlled by `REB` and has a non-null owner** calls `0x4B98D0(faction, ownerTag,
ownerId)` and, on true, appends a 0x10-byte node to a list it builds on the stack. That list
is the faction's business with each owner it is in revolt against; what `0x4B98D0` decides
and what the list is then used for are **not established**.

`CCountry +0xCF8` is not in the record. It sits just before `+0xD00`, the province-id list
head, and every one of its readers tests it against 0 as a liveness check (`0x4DAF22`,
`0x4DB41D`, `0x4DB7C9`, `0x4DB92B`, `0x4DBEC7`, all inside the daily politics region).
**Most likely the country's province count** - inference, not established, and deliberately
not recorded as a field here. Read with that reading, the two tests say: a faction dies when
the country it fights for holds nothing and its type is not area-bound, and **an
independence faction dies the moment the country it wanted to release exists** - its goal is
met.

### 3.3 Finding the faction for a province, and creating the brigades

`0x686CF0` (rva `0x286CF0`, game state in `eax`, `ret 8`): walk `+0xC7C`, keep the faction
whose `+0x30` is the wanted `CRebelType*`; when that type's `independence` (`+0x190`) is
non-zero, also require the area computed from the faction's `+0x44`/`+0x48` by `0x4BF6F0` to
match the province. So **one faction per (rebel type, area)**, and a nation-wide type shares
one faction.

`0x686C10` (rva `0x286C10`, game state in `eax`, `ret 4`) is the other lookup: it walks
`+0xC7C` and, inside each faction, the **armies** list at `+0x80` (nodes of 20 bytes, next
at `+0xC`), matching the node's object id at `+0x0`/`+0x4` against the argument's `+0x10`
and `+0x14`. This is the function the record
already mentions in `CUnit::RetreatFromCombat`'s comment as `0x286C10`.

`0x4C1160` (rva `0xC1160`, thiscall on the province, `ret 0x10`) is **the shared "put rebel
brigades in this province" call** - five call sites, including the underground spawn and the
province revolt. Its arguments are `(faction, count, bool, CCountryTag*)`:

    if (!province->area->slot0())          return    ; +0x2B4, not a real area
    if (!province->path_node->+0x13D)      return    ; a CProvinceTemplate flag
    if (count < 1) count = 1
    faction = 0x686CF0(province, arg1)               ; the faction for this province
    0x4A40F0(...)                                    ; not read here
    if (faction == 0) -> 0x686D80(...) with the string at 0x15B4945 and return
    if (province->controller_tag != 'REB')
        0x4B9150(province->controller_tag, province->controller_id)
    0x4BAA20(faction, &tmp, province, count, bool, tag)

`0x4BAA20` (rva `0xBAA20`, `ret 0x14`) is the creation proper. It is the only function that
reads `MODIFIER_PARTISAN_EFFICENCY` off a country's values (`[[c+0xDA8]+0x278]` at
`0x4BAD3F`; the other reader is `0x628060`, UI). It raises the player-facing message from
`REBELS` / `REBELDESC` / `PROV` / `REVOLT` with `MESSAGE_HEAD_MARS`, **clamps its count
argument to 1..4** (`0x4BAACD`..`0x4BAADD`), and records the pre-revolt owner and controller
pair when the province is occupied and the actor is not an exile. Its body past that point is
**not read here**; it is 0xDE0 bytes and the largest remaining lead after `0x50A110`.

`0x4A6C30` (rva `0xA6C30`), thiscall on a province, is the **full province revolt**, called
only from `0x65BF81` (the in-game screen path, so a command or a console action; the caller
also calls the modifier rebuild `0x49F3E0` immediately before, and checks the province's
controller for `REB` immediately after):

    if (province->revolt_risk == 0)
        province->revolt_risk = provinceValues[MODIFIER_LOCAL_PARTISAN_SUPPORT]
    if (province->+0x60 == 0) return                  ; no rebel type chosen
    brigades = province->+0x64 * max(1, province->manpower / 1000)   ; +0x320
    faction  = 0x686CF0(province, province->+0x60)
    if (faction) 0x4BAA20(faction, ..., province, brigades, 0, "---")
    else         0x686D80(...)                        ; make the faction first

**`CProvince +0x60` is a `CRebelType*` and `+0x64` the brigades-per-manpower-point
multiplier** - that is `likely`, from this one reader plus the argument `0x686CF0` expects;
neither is written by the save writer, and the only writers found (`0x496AB1`, `0x40DE92`)
zero them, so whatever chooses a province's rebel type at runtime is **not
established**.

---

## 4. What else is special-cased for `REB`

`FINDINGS-politics.md` records the daily politics pass forcing dissent to 0 for `REB`.
Every other `REB` special case found in this domain, each a literal R/E/B byte comparison:

| where | on | effect |
| --- | --- | --- |
| `0x42F1BF` `CCountry::IsEnemy` | either tag | **everybody is at war with `REB` and `REB` with everybody**, with no `CDiplomacyStatus` entry |
| `0x49EE3B` daily province pass | province owner, else controller | revolt risk accumulates even without a war entry |
| `0x49FBF7` modifier rebuild | province controller | **a `REB`-held province gets no occupation policy modifier** |
| `0x4A4089` effective revolt risk | province controller | `GLOBAL_REVOLT_RISK` is taken from the province's **owner** instead of its controller |
| `0x4B9E92` daily rebel faction pass | province controller | only `REB`-controlled provinces count as the faction's |
| `0x4C045D` inside `0x4C0430` | province controller | a distinct path when the province is already `REB`-held |
| `0x4C130A` inside `0x4C1160` | province controller | `0x4B9150(controller)` runs **only** when the controller is not `REB` |
| `0x4B8F40` | - | the only other function in the rebel block that holds the literal `REB`; almost certainly the `REB` country lookup, **not read here** |

**Does the mod's `REB` match what the engine expects?** The engine needs `REB` to be a real,
loadable country: it constructs a `CCountry` for it, indexes `+0xE28` with it, gives it a tag
at `+0xCA4`, walks its provinces, and forces its dissent to zero every day. The mod's own
setup was not audited as part of this work - that is left as a check, and the cheapest form
of it is that a missing `REB` flag `.tga` kills startup outright, so a `REB` that loads at
all has at least a tag and a flag.

---

## What is not established

- **What turns revolt risk into an actual revolt.** The accumulator, the effective figure,
  the two triggers and both creation paths are read. The **daily roll** that consumes the
  effective revolt risk and calls into `0x4BAA20` was not found. `0x4A4050`'s callers are the
  two triggers plus six sites in the `0x60xxxx`, `0x6Exxxx`, `0x86xxxx`, `0x8Bxxxx` and
  `0x8Exxxx` ranges that look like UI, and none of them is in the daily pass. It may be in
  `0x50A110`, in `0x4BAA20`'s unread body, in the event machinery (`rebel_types.txt`'s
  `spawn_chance` is a factor block, which is the `CMeanTimeToHappen` shape), or a `REB` AI
  behaviour. **`spawn_chance` being evaluated by the engine at all was not confirmed.**
- **How often the underground grows and is detected** - `0x50A110` is unread, so
  `UNDERGROUND_STRENGTH_GAIN` and `UNDERGROUND_DETECT_CHANCE` have a reader but no rate.
- **`0x4BAA20`'s body** past its argument clamping: the unit creation, where
  `MODIFIER_PARTISAN_EFFICENCY` is applied, and what the 1..4 clamp is clamping.
- **What `0x4B98D0` decides** in the daily faction pass, and what the 0x10-byte node list it
  feeds is for.
- **`CCountry +0xCF8`.** Read as a liveness test in many places; "province count" is
  inference and it is deliberately not recorded as a field.
- **`CProvince +0x60` and `+0x64`.** Recorded as `likely`; nothing found that sets them to a
  real value.
- **`CProvinceTemplate +0x13D`**, which gates rebel creation in `0x4C1160`, is still the
  unknown flag the record already says it is.
- **The units of `CProvince +0x28`.** The arithmetic is exact (suppression x 1000 / 10 per
  unit at full strength) but nothing here was measured in a running game, so the claim that a
  `suppression = 2.0` brigade lands as 200 rests on reading `CSubUnitDefinition +0x130` as
  thousandths like every other loader field.
- **`CDiplomacyStatus +0x20`** is inferred to be the war from `IsEnemy`'s shape; its writer
  was not found.
- **The occupation policy's `allow` block** - `COccupationPolicy::LoadKey` (`0x52CEE0`) keeps
  it off the object where `fieldmap.py` can see it, and nothing here reads who evaluates it.
- **`CExecuteRebelAcceptanceCommand` and `REBEL_ACCEPTANCE_MONTHS`.** The command's loader
  takes one key (`scope`), `CCountry` has `last_rebel_acceptance` and the define is at
  `CDefines+0xCC` `+0x10`, but the backwards scan finds **no reader of that define**, and the
  acceptance runtime was not reached. "Acceptance" is still unexplained.
- **`CSpawnPartisanCommand` and `CSpawnFullRevoltCommand` `Execute`.** Only their loaders are
  read. `0x4A6C30` is reached from the screen, which is consistent with
  `CSpawnFullRevoltCommand`, but the vftable slot was not checked.

## Contradictions with the existing record

- **`CCountry +0x95`** is recorded as `use_own_pool`. `0x50AFF5` tests it and produces
  `WE_NOT_GOVERNMENT_IN_EXILE` when it is clear, so the field is the government-in-exile flag
  and `use_own_pool` names a consequence. Nothing is redefined here.
- **`CRebelFaction +0x94`.** The record calls it "a vector, ending at `+0x98`". The daily
  faction pass at `0x4B9DE7`..`0x4B9E0F` walks it as a **linked list** - `edi = [node]` is
  the province id and `[node + 8]` is the next node, with the walk ending on null rather
  than on `+0x98`. One of the two readings is wrong and this work does not settle which;
  nothing is redefined here.
- **`0x49EAB0` is in `RunDailyPass`, not `RunHourlyPass`.** `FINDINGS-tick.md` has it right
  in the callee list; `image.functionStart(0x682E4B)` answers `RunHourlyPass` because the two
  functions abut. Anything built on that helper's answer in this range is wrong by one
  function.

## How this was found

`definesMap.py` run backwards, as the brief suggested, is what opened the domain: a scan for
`call 0x445D90` sites followed by `mov reg, [eax + <block>]` and then any `[reg + <field>]`
read turns each define name straight into an address, and the partisan and underground
defines all landed in one 0x3000-byte block of the image that had no names in it at all.

Two scanning traps cost time and are worth recording:

- **Linear-decoding the whole `.text`** from its first byte desyncs on the first jump table
  and then reports confident nonsense: a scan for `[reg + 0x328]` that way found **one** site
  in the image, when there are 54, and the province save writer alone has two. Decoding each
  function from its own entry - found from the `int3` padding between them, 25679 of them -
  fixes it.
- **The scratchpad is shared with other agents.** A scratch `dispscan.py` was overwritten
  mid-session by another agent's file of the same name. Scratch scripts in this folder need a
  per-task prefix.
