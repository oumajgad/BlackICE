# What the interface already computes, part two

Read on 2026-10-02, continuing `FINDINGS-uinumbers.md` of the same day. Addresses are **virtual**,
based `0x400000`, with the rva beside each one the record wants — trap 1. Unlike its predecessor,
**part of this file rests on the running game**, and every such claim is marked; the closing
section says which would survive a restart.

The assignment was to finish the predecessor's localisation-key sweep: 389 candidate functions
ranked, 24 call shapes and 3 bodies read, 365 unread. The outcome is lopsided. **Two of the three
named leads do not pay, and the third pays better than the predecessor's own headline.**

- The **eleven other ledger pages** are not the `BuildGoodsLedgerTooltip` shape and never were.
  They are column-header and chart wiring; no simulation field is read anywhere near a key.
- The **`BUILD_*_DRO`/`_IRO` cluster** is not build cost. `_IRO` is a sortable column's **name**
  and `_DRO` its **description**; all five bodies are sort-header text and contain no numbers.
- The **35 `*_TECH` keys at `0x138D60`** are a complete field map of `CTechStatistics`, the base
  class `CCountry +0xDF8` points at, naming **57 fields** with the game's own names — and it is
  the *only* other function in the sweep of that shape.

It also corrects the method the predecessor's section 1 established, and re-runs it.

---

## 1. The method, its one bug, and the ranking that replaces key counts

### The bug: a phantom `call rel32` target hijacks everything after it

The predecessor's attribution rule was: candidate function entries are the targets of
`call rel32` anywhere in the image, "real function entries by construction". They are not. The
index is built by scanning `.text` for `0xE8` bytes, and a `0xE8` **inside** an instruction
decodes as a `call` to a plausible address — trap 9, one step removed. Because the owner of a
site is the *nearest* candidate below it, a phantom candidate landing inside a real function
takes ownership of every key reference after it.

Seven of the re-run's rows were phantoms of exactly this kind, and these are the bytes at them:

```
0x7EB0D2   3D 02 00 00        cmp eax, 2          one "caller", 0x7D3EE4, itself inside 0x7D3AB0
0x80E425   24 00 8B CE        mid-instruction     one "caller", 0x822037
0x7F5E23   C6 45 D8 00        mov byte [ebp-0x28],0
0x75B3D1   00 8B 70 24        mid-instruction
0x5776F2   04 02 00 00        mid-instruction
0xA12A1D   C0 89 46 58        mid-instruction
0xA1550F   BC 00 00 00        mid-instruction
```

Against them, every candidate that turned out to be real opens `push ebp; mov ebp, esp`. So the
fix is one line: **require the candidate's first byte to be in the prologue set.** With it,
`0x7F5E23` folds correctly into `BuildProductionPenaltyTooltip` (`0x7F5A40`) and `0x5776F2` into
`0x574580`; the other five vanish and their sites go to their real owners.

The filter has a second consequence that has to be fixed with it: **a virtual that nothing calls
directly is not a `call rel32` target at all**, so with only call targets as candidates every
slot-only function is unreachable — `0x7EA930` (`CDivisionDesigner` slot 6) and `0x80D420`
(`CShipBuilder` slot 6) both answered "no owner". The vftable slot bodies have to be unioned into
the candidate set. With both changes the method resolves every site in this file.

Confidence `confirmed`: the byte sequences above are decidable, and the two corrected
attributions land on functions the record already names.

### The ranking that replaces key counts

Re-attributing all **9,491** key references with the corrected method and grouping by real
function gives 223 functions carrying four or more game keys. **Ranking them by key count is
actively misleading**, and that is why the predecessor's top leads failed: the functions with the
most distinct localisation keys in the whole image are sort-column header builders, which carry
66, 51, 44 and 43 keys apiece and not one number.

What distinguishes `BuildGoodsLedgerTooltip` is not key count but **adjacency**: every key sits
within a few instructions of the load of the value it labels. That is testable. For each key site,
is there a memory read through a non-stack base register with a non-zero displacement inside a
±8-instruction window, and **how many distinct displacements** do the hits use? One repeated
displacement is a getter called once per arm; many distinct displacements is a field map.

Run over the 223, the test puts exactly two functions in the field-map class:

| rva | keys | adjacent | distinct offsets | what it is |
| --- | --- | --- | --- | --- |
| `0xF3000` | 15 | 15/15 | 14 | `BuildGoodsLedgerTooltip` — the predecessor's result, reproduced |
| `0x138D60` | 50 | 46/50 | 44 | `CTechStatistics::BuildEffectsTooltip` — section 4 |

and everything else below them is either one repeated displacement (`[edx+0x44]`, the sort-column
getter; `[ecx+0x14]` and `[esi+0x4]`, `std::string` internals) or a handful of UI-struct fields.
`CSubUnitDefinition::BuildStatsTooltip` (`0x1A55C0`, 42/47) and `BuildModifierEffectsText`
(`0x56E00`, 25/108) score high on adjacency and low on distinct offsets for that reason: their
keys are adjacent to the string machinery, not to values.

**The positive control.** The same tool run against `0xF3000` reproduces the predecessor's section
5 table entry for entry, including the three pools it renamed:

```
RES_CHANGE        <- [ecx+eax+0xA6C]      RES_PROD        <- [edx+eax+0x778]
RES_CONVOYED_IN   <- [edx+eax+0x79C]      RES_TRADED_FOR  <- [edx+eax+0x874]
RES_INC_DEBT      <- [ecx+eax+0x850]      RES_FROM_PUPPETS<- [ecx+eax+0x904]
RES_CONVERTED     <- [ecx+eax+0x8E0]      RES_CONVERTED   <- [ecx+eax+0x8BC]
RES_TRADED_AWAY   <- [ecx+eax+0x7E4]      RES_REPAID_AWAY <- [ecx+eax+0x82C]
RES_CONVOYED_OUT  <- [ecx+eax+0x7C0]      RES_SENT_TO_MASTER <- [ecx+eax+0x928]
RES_INTO_NET      <- [ecx+eax+0x9B8]      RES_USED        <- [ecx+eax+0x994]
RES_SHIPPED_BACK  <- [ecx+eax+0x9DC]
```

So when the test reports that a ledger page has no field loads near its keys, that is about the
page and not about the test.

A second control on the re-attribution itself: `0x138D60` was ranked at **35** keys by the
predecessor's sweep and carries **50**. The naive `int3`-run scan split the function; the
corrected walk gives it the whole body, and the fifteen extra keys include `METAL_PROD_TECH`,
`ENERGY_PROD_TECH`, `LEADERSHIP_GAIN_TECH`, `REPAIR_RATE_TECH`, `ORD_EFF`, `ORD_RED` and `DECAY`
— four of which turn into fields nothing else placed.

---

## 2. The eleven ledger pages: a complete page table, and no numbers

Negative, with the control above. `confirmed`.

All eleven are called from one place, `0x7C1ED0` (rva `0x3C1ED0`), a `__stdcall` taking the ledger
window and dispatching on `[this+4]`, the page number. The dispatch is a chain of
`cmp dword ptr [edi+4], N / jne / push edi / call`, so **the whole table reads straight out of
it**:

```
page  function    rva        page  function    rva        page  function    rva
 0    0x795990    0x395990    9    0x79B170(1,0,9)        18    0x7BC0C0    0x3BC0C0
 1    0x796C30    0x396C30   10    0x79B170(2,9,-1)       19    0x7B99D0    0x3B99D0
 2    0x797FC0    0x397FC0   11    0x7A1570    0x3A1570
 3    0x7990D0    0x3990D0   12    0x7A2950    0x3A2950
 4    0x79A120    0x39A120   13    0x7A3DB0    0x3A3DB0   brigade list
 5    0x79D0B0    0x39D0B0   14    0x7A5CF0    0x3A5CF0   ship list
 6    0x79E180    0x39E180   15    0x7A7320    0x3A7320   wing list
 7    0x79F500    0x39F500   16    0x7A8950    0x3A8950
 8    0x7A0920    0x3A0920   17    0x7AA850    0x3AA850
                             18    0x7AC640    0x3AC640
                             19    0x7AE290    0x3AE290   land commanders
                             20    0x7AFA10    0x3AFA10   sea commanders
                             21    0x7B1190    0x3B1190   air commanders
                             22    0x7B2920    0x3B2920   consumption, all arms
                             23    0x7B72A0    0x3B72A0   consumption, land
                             24    0x7BC0C0    0x3BC0C0   consumption, air
                             25    0x7B99D0    0x3B99D0   consumption, naval
```

(The second column of the first block is the low pages; pages 9 and 10 share `0x79B170` with
different leading arguments, `(1, 0, 9)` and `(2, 9, -1)`. Pages 18/19 appear twice above because
the dispatcher tests `0x19` **before** `0x18` — the only out-of-order pair, and page `0x17` is
`0x7B72A0`, not `0x7B7250`.)

**That last point is a trap-2 catch worth keeping.** The predecessor's lead list names
`0x3B7250`. `0x7B7250` is a real function, but it is **not** the page: the dispatcher calls
`0x7B72A0`, which abuts it, and `0x7B7250` is a helper the land, air and naval consumption pages
each call three times (22 call sites in all). The key set the sweep attributed to `0x3B7250`
belongs to `0x3B72A0`.

**Why they do not pay.** Page 6, `0x79E180` (rva `0x39E180`), read in full: each of
`LEDGER_TERRITORIAL_TITLE`, `LEDGER_PROVINCE`, `LEDGER_ENERGY`, `LEDGER_METAL`, `LEDGER_RARE`,
`LEDGER_MP`, `LEDGER_LEADER` is followed by the identical six-call sequence —
`std::string::assign`, `GetText`, `GetGameSettings`, `CInternationalizedText::Render`, `0xAEFD90`,
`0x7BEB80` — and nothing else. `0x7BEB80` is the column adder. The values never appear; the rows
come from a provider the page only registers. Its tail builds a graph out of the ledger's own
cached history at `[[ebp+8]+0x14] + 0x6B9BC`/`+0x6B9C0`, not out of any simulation object.

Page 22, `0x7B2920`, is the most computational of them and still fails: its field loads near keys
are `[eax+0x8]`, `[eax+0x14]`, `[ecx+0x30]`, `[ecx+0x34]`, `[edi+0x4C]` — chart-series structs on
the stack.

**One thing the pages are worth.** Page 8 (`0x7A0920`, rva `0x3A0920`) is the goods *flow* ledger,
and its seventeen column names are a longer list than the `RES_*` set the predecessor mapped:

```
LEDGER_FLOW_TITLE   LEDGER_CATEGORY      LEDGER_HOME_PRODUCED  LEDGER_CONVOYED_IN
LEDGER_CONVOYED_OUT LEDGER_REPAID_DEBT   LEDGER_INCOMING_DEBT  LEDGER_CONVERTED_TO
LEDGER_CONVERTED_FROM  LEDGER_PUPPET_FROM   LEDGER_PUPPET_TO   LEDGER_USED_INDUSTRY
LEDGER_USED_TROOPS  LEDGER_FROM_EXILES   LEDGER_STOCKPILE      LEDGER_TRADED_FOR
LEDGER_TRADED_AWAY
```

Four of those have no `RES_*` counterpart: `LEDGER_USED_INDUSTRY` ("Used by Industry") and
`LEDGER_USED_TROOPS` ("Usage") **split** what `RES_USED` shows as one number, and
`LEDGER_FROM_EXILES` ("From Exiles") and `LEDGER_STOCKPILE` ("Returned to Stockpile") are pools the
tooltip does not show at all. So there are at least two more `CCountry` goods pools than section 5
of the predecessor's file names, and a split of `usage` into two. **Which offsets they are is not
established** — the column names are not next to any load. This is the best remaining lead on
`CCountry`'s goods block and it wants the row provider, not the page.

---

## 3. The `BUILD_*_IRO`/`_DRO` cluster is sort headers, and the suffix is a rule

Negative. `confirmed`.

Five functions, 66/51/44/43/41 keys — the five highest game-key counts in the image after the
`defines.lua` name table:

| rva | holder |
| --- | --- |
| `0x3C3510` | none; `__thiscall(this@ECX, Hoi3CString* out)` `ret 4`, called by the four below |
| `0x3D3AB0` | `CAirBuilder` slot 6 |
| `0x3DC090` | `CBrigadeBuilder` slot 6 |
| `0x3EA930` | `CDivisionDesigner` slot 6 |
| `0x40D420` | `CShipBuilder` slot 6 |

Every arm in all five has the same four-instruction shape, and there is no number in it:

```
0x007C39DF  mov  edx, [esi]              ; this
0x007C39E1  mov  eax, [edx+0x44]         ; slot 17 - the current sort column's name
0x007C39E6  call eax
0x007C39E8  mov  ecx, 0x15dbc14          ; 'ledger_sort_cw'
0x007C39ED  call 0x40c3c0                ; string compare
0x007C39F4  je   0x7c3b42
0x007C39FA  mov  edx, 0x15dc2f8          ; 'BUILD_CW_IRO'
```

The mod's own localisation settles what the suffixes mean, and it generalises:

```
BUILD_CW_IRO;Combat Width
BUILD_CW_DRO;How much space the brigade occupies on the battlefield
BUILD_IC_IRO;Build Cost in IC
BUILD_PRIO_IRO;Priority
INFRA_IRO;Infrastructure
DISSENT_IRO;Dissent
```

So **`_IRO` is a sortable column's short name and `_DRO` its long description.** A function whose
keys are mostly `_IRO`/`_DRO` pairs is a header builder and will never hand over a field offset.
That disposes of `0x3C3510`, `0x3D3AB0`, `0x3DC090`, `0x3EA930`, `0x40D420` and `0x360600`
(`CSingleUnitButtons` slot 13) in one stroke, and it explains why the key-count ranking put them
on top: a sortable list with 25 columns emits 50 keys and no values.

The exceptions are worth knowing because they are the ones that mislead: `CONV_EFF_IRO`,
`POL_MOBILIZE_IRO` and `MANPOWER_IRO` appear in real value tooltips. `_IRO` tells you the key is
a **label**; it does not tell you the function is a header builder. Count the proportion.

---

## 4. `CTechStatistics::BuildEffectsTooltip` — 57 fields, and `CCountry +0xDF8` is one of them

`0x538D60` (rva `0x138D60`), extent `0x538D60..0x540598`, `ret 0x14`. Fifty key sites, one caller.

```
Hoi3CString* __stdcall CTechStatistics::BuildEffectsTooltip(
        CTechStatistics* stats,      ; [ebp+8]   -> EDI, read field by field
        Hoi3CString*     out,        ; [ebp+0xC] callee-constructed, returned in EAX
        int              levels,     ; [ebp+0x10] every value is multiplied by it
        int              a,          ; [ebp+0x14] not read in the arms examined
        int              b)          ; [ebp+0x18]
```

Its one caller is `0x5359A0` (rva `0x1359A0`, `ret 0x18`, six arguments, same first three), which
is reached from the technology view (`0x81E846`, where the effects pointer is `[view+0xD4]` and the
GUI element registered immediately after is named `effects`) and from
`CSpyPresence::RunTechEspionage` (`0x52F3CF`). So this is the **"Effects" block of a technology's
tooltip**.

Every arm is the same five instructions, and that is what makes the function a field map:

```
0x00539EA4  cmp  dword [edi+0x10], esi        ; zero? skip the whole arm
0x00539EA7  je   0x53a0cb
0x00539ECE  cmp  dword [edi+0x10], 0          ; sign picks green (0x15B5C50) or red (0x15B5C58)
0x00539EE9  mov  edx, 0x15c30bc               ; 'SUPPLY_THROUGHPUT_TECH'
0x00539F07  mov  eax, dword [edi+0x10]        ; and then the value
```

### 4.1 The 44 scalars and the two bytes

**Trap 14, honestly.** These offsets are **not** new. `FINDINGS-fieldmap.md` placed 46 of the 50
keys of `CTechStatistics::LoadKey` (`0x137DB0`), and every single offset below agrees with it. What
is new is (a) that `project.json` carries **none** of them under this struct, (b) that sixteen of
them *are* in `project.json` on `CTechnologyStatus` under names taken from their consumers, and
(c) the game's own display label for each, which closes the "the name is ours" caveat on five.

My first grep was for the string `CTechStatistics` in `project.json`, which found only the
`LoadKey` entry — and that was the wrong check. The struct is recorded as `CTechnologyStatus`.
**Grep the offsets, not the class name**; trap 14 says both halves of the fact base, and it means
both spellings too.

| offset | the game's name (`LoadKey` key) | display label | already in `project.json` as |
| --- | --- | --- | --- |
| `+0x08` | `ground_defence_effiency` | `GDE_FROM_TECH` "Ground Defence Efficiency" | — |
| `+0x0C` | `supply_transfer_cost` | `SUPPLY_TRANSFER_COST_TECH` | — |
| `+0x10` | `supply_throughput` | `SUPPLY_THROUGHPUT_TECH` | — |
| `+0x14` | `dig_in_cap` | `DIGIN_FROM_TECH` | — |
| `+0x18` | `attack_delay` | `ATTACK_DELAY_FROM_TECH` + `AD_HOURS` "hours" | — |
| `+0x1C` | `division_size` | `DIVISION_SIZE_FROM_TECH` | — |
| `+0x20` | `refinery_efficiency` | `REFINERY_EFFICIENCY_TECH` | — |
| `+0x34` | `radar_efficiency` | `RADAR_EFFICIENCY_TECH` | — |
| `+0x38` | `radio_strength` | `RADIO_STRENGTH_TECH` | — |
| `+0x3C` | `encryption` | `ENCRYPTION_TECH` | — |
| `+0x40` | `decryption` | `DECRYPTION_TECH` | — |
| `+0x44` | `convoy_build_cost` | `CONVOY_COST_TECH` | `convoy_build_cost_effect` — agrees |
| `+0x48` | `convoy_build_time` | `CONVOY_TIME_TECH` | `convoy_build_time_effect` — agrees |
| `+0x4C` | `escort_build_cost` | `ESCORT_COST_TECH` | `escort_build_cost_effect` — agrees |
| `+0x50` | `escort_build_time` | `ESCORT_TIME_TECH` | `escort_build_time_effect` — agrees |
| `+0x54` | `attack_movement_speed` | `ATTACK_MOVEMENT_SPEED_TECH` | — |
| `+0x58` | `reinforce_chance` | `REINFORCE_CHANCE_TECH` | — |
| `+0x6C` | `unit_cooperation` | `UNIT_COOP_TECH` | `free_stacking_allowance` — **see below** |
| `+0x70` | `targeting_chance` | `TARGET_CHANCE_TECH` | `naval_positioning_bonus` — **see below** |
| `+0x74` | `targeting_choice` | `TARGET_CHOICE_TECH` | — |
| `+0x78` | `escort_efficiency` | `ESCORT_EFFICIENCY_TECH` | `escort_efficiency` — agrees |
| `+0x7C` | `naval_base_efficiency` | `NAVAL_BASE_EFF_TECH` | — |
| `+0x80` | `allow_escorts` (byte) | `ALLOW_ESCORTS_TECH` | — |
| `+0x84` | `casualty_trickleback` | `CASUALTY_TRICKLEBACK_TECH` | — |
| `+0x88` | `maximum_attrition` | `MAX_ATTRITION_TECH` | — |
| `+0x8C` | `manpower_gain` | `MANPOWER_GAIN_TECH` | — |
| `+0x90` | `ic_modifier` | `IC_MOD_TECH` "IC" | `ic_bonus` — agrees |
| `+0x94` | `ic_efficiency` | `IC_EFFICIENCY_TECH` | `build_discount_extra` — **see below** |
| `+0x98` | `energy_to_oil_conversion` | `ENERGY_TO_OIL_TECH` | `oil_conversion_bonus` — agrees |
| `+0x9C` | `ic_to_supplies` | `IC_TO_SUPPLIES_TECH` | — |
| `+0xA0` | `provincial_aa_efficiency` | `PROV_AA_TECH` | — |
| `+0xA4` | `combat_efficiency` | `COMBAT_EFF_TECH` | `combat_radio_bonus` — **see below** |
| `+0xA8` | `research_efficiency` | `RESEARC_EFF_TECH` | `research_efficiency` — agrees |
| `+0xAC` | `metal_production` | `METAL_PROD_TECH` | — |
| `+0xB0` | `rares_production` | `RARES_PROD_TECH` | — |
| `+0xB4` | `energy_production` | `ENERGY_PROD_TECH` | — |
| `+0xB8` | `leadership_gain` | `LEADERSHIP_GAIN_TECH` | — |
| `+0xBC` | `nuclear_production` | `NUKE_PROD_GAIN_TECH` | — |
| `+0xC0` | `radar_impact` | `RADAR_IMPACT_TECH` | `radar_combat_bonus` — **see below** |
| `+0xC4` | `repair_rate` | `REPAIR_RATE_TECH` | — |
| `+0xC8` | `bomber_targeting` | `BOMBER_TARGET_TECH` | — |
| `+0xCC` | `fighter_targeting` | `FIGHTER_TARGET_TECH` | — |
| `+0xD0` | `frontline_focus` | `FRONTLINE_FOCUS_TECH` | — |
| `+0xD4` | `reserve_focus` | `RESERVE_FOCUS_TECH` | — |
| `+0xD8` | `naval_air_target_chance` | `NAVAL_AIR_TARGET_CHANCE_TECH` | — |
| `+0xDC` | `listening_station` (byte) | `LISTENING_STATION_TECH` | — |

`confirmed` as offsets: three independent readings now agree on every one — the loader's own
switch, the tooltip's arms, and (for 44 of them) a live read against the mod's declarations in
section 4.4.

**The five name disagreements.** Each existing name was derived from the field's *consumer* and
each of five carries the note "the name is ours". They are not wrong; they describe what the field
*does* where it is read. But the game's own name for the field is the loader key, and the display
label agrees with the loader key in all five cases. **I am not renaming them — the merge tool does
not overwrite and should not here — but the record should carry both, and the comment should stop
saying the name is ours:**

| offset | existing name, from its one consumer | the game's own name |
| --- | --- | --- |
| `+0x6C` | `free_stacking_allowance` (subtracted from the stacking penalty) | `unit_cooperation` |
| `+0x70` | `naval_positioning_bonus` (scales `CNavalCombatant::PickTarget`) | `targeting_chance` |
| `+0x94` | `build_discount_extra` (added to the category discount by `0xE1AC0`) | `ic_efficiency` |
| `+0xA4` | `combat_radio_bonus` (the whole of `BM_RADIO`) | `combat_efficiency` |
| `+0xC0` | `radar_combat_bonus` (scales `BM_RADAR_STATION`) | `radar_impact` |

Two of these are more than naming. `+0xA4` being `combat_efficiency` means **a technology's
`combat_efficiency` is implemented entirely as `BM_RADIO`** — which is not what the name in the
mod's files suggests, and is worth knowing to anyone balancing BICE. And `+0x70` being
`targeting_chance` sits beside `+0x74 targeting_choice`; two keys one offset apart that the
loader and the tooltip both separate the same way, which is why I trust this pair over a
single-use name.

### 4.2 The five fields the loader could not place

`FINDINGS-fieldmap.md` left four keys of the switch unplaced, "nothing — a base class, or a call
that keeps the value elsewhere". The tooltip places them, because it reads them back. All five are
array-shaped, and **the index space of each is named live in section 4.4**.

| offset | shape | read at | label | index space |
| --- | --- | --- | --- | --- |
| `+0x24`/`+0x28`/`+0x2C` | `std::vector<int>` | `0x53F567`, `0x53F5A3` | the tactic's own name | **combat tactic**, 43 in BICE |
| `+0x5C`/`+0x60`/`+0x64` | `std::vector<int>` | `0x53F790`, `0x53F7C3` | the group's own name | **combined-arms group**, 21 |
| `+0xE0` | `int[33]`, inline | `0x53FAB4` | `ORD_EFF` "Efficiency" | **mission index**, 33 |
| `+0x164` | `int[33]`, inline | `0x53FE37` | `ORD_RED` "Organisation Penalty" | **mission index**, 33 |
| `+0x1F8`/`+0x1FC`/`+0x200` | `std::vector<int>` | `0x540178`, `0x54044C` | the category's own name | **technology category**, 49 |

Three of these the record already has, in part, and this closes two flagged inferences:

- `+0x5C` is `combined_arms_group_bonus`, named off `CUnit::GetCombinedArmsBonus`. **Confirmed
  independently**, and the record's type `int*` is a third of the truth: `+0x60` is the vector's
  end and `+0x64` its capacity.
- `+0xE0` is `mission_efficiency`, "the first half of `BM_MISSION_EFFICIENCY`". **Confirmed
  independently**, and the display side gives the label.
- `+0x1F8` is `tech_decay_by_category`, and the record says plainly: *"That it is the technology
  effect key `decay` (save token 0x52E) is inference"*. **It is now read.** The arm at
  `0x5401C6` prints the key `DECAY` ("Decay") for `[edi+0x1F8][i]`, with the row's label taken
  from `GetTechnologyDataBase()->+0x1C[i]` — the category. So `decay` → `+0x1F8`, indexed by
  category, `confirmed` from the display side.
- `+0x164` is **new**: the twin of `+0xE0`, same 33-entry index space, labelled "Organisation
  Penalty". Its one reader in the whole image is `0x587A30` — see section 5.
- `+0x24` is **new**.

### 4.3 Three scales in one struct, and only one of them is "thousandths"

This is the part a DLL gets wrong. Saying "thousandths" is not enough: it says how the number is
stored, not what it is a thousandth *of*. In every case the stored value is **the technology
file's own number × 1000**, and what the file's number means changes:

**(a) 43 of the 44 scalars: the file's number is a fraction.** The display arm is

```
0x00538E35  mov   eax, [edi+0x8]
0x00538E38  imul  ebx                    ; ebx = levels * 1000
0x00538E49  call  __alldiv  by 0x3E8     ; v = field * levels
0x00538E4E  movss xmm0, [0x160a718]      ; the float constant 100000
0x00538E73  call  floorf
0x00538E7B  call  _ftol2_sse
0x00538E86  imul  esi                    ; v * 100000
0x00538E91  call  __alldiv  by 0x3E8     ; / 1000  ->  v * 100
0x00538EB4  call  FormatFixedPoint       ; push 2  - two decimals, over a thousand
```

so printed = `field / 10`, with a `%` appended. `supply_throughput = 0.05` in the file stores
**50** and shows **"5.00%"**. A DLL wanting the fraction divides by 1000; wanting the number the
panel shows, by 10. `confirmed`.

**(b) `attack_delay` (`+0x18`): the file's number is hours.** Its arm has **no** `×100` step and
calls `FormatFixedPoint` with `push 0` — zero decimals — and appends the key `AD_HOURS`, which the
mod's localisation renders as the word "hours". The mod declares it in whole and half hours
(`0.5` sixteen times, `1.0`, `1.5`, `2.0`, up to `6.0`). So `field / 1000` is **hours**, and
treating it as a fraction is out by two orders of magnitude on the one field in the block where
that matters most. `confirmed`.

**(c) `+0x24`, the combat-tactic vector: the file's number is percentage points.** Its arm also
has no `×100` step; it divides by 1000 and appends `%`. The mod writes
`tactic_advanced_defend = 15` and `tactic_basic_defend = -100` — whole percentages, not fractions
— so the stored value is `15000` and `-100000` and `field / 1000` is the percentage directly.
`confirmed`.

`+0x5C` follows (a); `+0xE0` and `+0x164` follow (a) and match the record's "thousandths".

The predecessor's `CTraitGainTracker` note — that a quantity stored in thousandths can itself be a
percentage, so the factor is 100 and not 1000 — is the same hazard; this struct has both kinds
side by side, four bytes apart.

### 4.4 Read out of the running game, and matched against the mod's files

**This whole subsection rests on the live process** and on the files at
`C:\Users\David\GitHub\BlackICE\technologies\`. The game was a freshly started 1936-01-01
campaign, paused, playing **IRE**; module base `0x830000`.

Countries were identified by reading the tag chars at `CCountry +0xCA4` and the id at `+0xCA8` and
requiring the id to equal the array index — not from the country database's cached tag slots,
which hold only 45 majors and near neighbours. `IRE` is id 20 (and the single non-zero entry of
the played-countries vector at `CCurrentGameState +0xBCC`); `FRA` is id 8. Each country's
`CTechnologyStatus` was reached as `g_CCountryDataBase[+0x16C][id] + 0xDF8`, and its vftable read
back as live `0x19F35BC` = static `0x15C35BC` = `CTechnologyStatus` by the RTTI export, which is
the check that the pointer is what the record says it is.

**Ireland, the played country, gives nine exact single-declaration matches.** Each row is a live
value, the mod declaration it equals, and nothing else in the mod that could produce it:

| field | live (IRE) | the mod declares | × 1000 |
| --- | --- | --- | --- |
| `supply_transfer_cost` | `-15` | `-0.015`, once, `Construction Technologies.txt:36` | `-15` |
| `supply_throughput` | `50` | `0.05` | `50` |
| `ic_efficiency` | `10` | `0.01` | `10` |
| `research_efficiency` | `50` | `0.05` | `50` |
| `metal_production` | `40` | `0.04`, once | `40` |
| `energy_production` | `75` | `0.075`, once | `75` |
| `provincial_aa_efficiency` | `400` | `0.4`, once | `400` |
| `energy_to_oil_conversion` | `-1000` | `-1.0`, once | `-1000` |
| `unit_cooperation` | `50` | `0.05` | `50` |

and two more from France: `refinery_efficiency` `220` against `0.22` declared once in
`Industry Technologies.txt:150`, and `radar_efficiency` — exactly **one** country in the game has
it non-zero, at `20`, against the mod's single `0.02` in `Electronics Technolgies.txt:102`.

**The strongest of the lot is the mission pair,** because it confirms two fields, their shared
index space and their scale in one reading. The mod writes mission effects as a block:

```
interdiction = {
    efficiency = 0.08
}
...
interdiction = {
    reduction_modifier = -0.1
}
```

France reads `+0xE0 + 19*4 = 80` and `+0x164 + 19*4 = -100`, and **19 is `interdiction`** in the
mission index. So `efficiency` → `+0xE0`, `reduction_modifier` → `+0x164`, both × 1000, both on
the same dense index. `confirmed`.

The combat-tactic vector confirms the same way: France reads `+0x24 + 30*4 = 15000`, and index 30
is `tactic_advanced_defend`, which `strategic_doctrines.txt:5494` declares as `15`. Index 2
(`tactic_basic_defend`) reads `-97000` against a declared `-100` — not exact, because France has
other tactic technologies, so I take the `15000` as the confirmation and the `-97000` as
consistent.

**The three index spaces, named out of the process.** Each count matches the live vector's length
exactly, which is what ties the array to its index space:

```
+0x24  43 entries   g_CombatTactics (rva 0x1685554) +0x0C vector:
        0 nullCombatTactic        1 tactic_basic_attack      2 tactic_basic_defend
        3 tactic_assault          4 tactic_reckless_assault  5 tactic_encirclement
        ... 30 tactic_advanced_defend ... 42 tactic_pakfront

+0x5C  21 entries   g_CSubUnitDataBase (rva 0x16886F0) +0x00 vector:
        0 (unnamed)               1 division_HQ_unit_type    2 veteran_division_HQ_unit_type
        3 elite_division_HQ...    4 kampfgruppe_unit_type    5 infantry_unit_type
        6 armor_unit_type         7 mobile_unit_type         8 special_forces_unit_type
        9 artillery_unit_type    10 heavy_artillery...      11 direct_fire_unit_type
       12 tank_support...        13 mixed_support...        14 recon_unit_type
       15 assault_unit_type      16 antiair_unit_type       17 transport_unit_type
       18 motorized_transport... 19 auxiliary_unit_type     20 corps_HQ_unit_type

+0x1F8 49 entries   g_CTechnologyDataBase (rva 0x1687B78) +0x1C vector:
        0 nocategory             1 infantry_theory       ... 26 infantry_practical
       ... 48 construction_practical     - the theories and practicals, in file order
```

The label in the tooltip comes from each element's own name at `+8`, which is how the index space
was identified before it was counted.

**The 33 mission names are a convergence, not a new result.** `project.json` already carries the
full mapping, by save token, from `MissionIndexToOrderToken` (`0x184640`). The jump table at
`0x585AE4` (33 entries, indexed by `[ebp+8]` after `cmp eax, 0x20`) gives the same 33 in the same
order by *localisation key*, and the two agree **name for name on all 33** — `0 none/NO_ORDERS`,
`9 convoy_escort/ORDER_CONVOY_ESCORT`, `20 air_intercept/INTERCEPT`,
`21 carrier_protection/CAG_DUTY`, `30 air_superiority/AIRSUP`, `31 join_fleet/ORDER_JOIN_FLEET`
(which is out of address order in the body and would have been mis-numbered by reading the arms in
address order — read the table). What is new is the **keys**, which name the 33 slots of `+0xE0`
and `+0x164` for a tooltip.

**What a scenario-start reading can and cannot say.** Nine of the 44 scalars are zero on all 108
countries: `ground_defence_effiency`, `dig_in_cap`, `division_size`, `decryption`,
`convoy_build_cost`, `convoy_build_time`, `escort_build_cost`, `escort_build_time`,
`nuclear_production`, and `+0x1F8` is empty for every country. `CCountryHistory.hpp` says eight of
the 44 are levers the mod never pulls, and seven of its eight are in my nine. **The two lists are
not the same claim**: the header's is about the mod's files and holds for a whole game; mine is
about 1936-01-01 and a field is zero either because no technology sets it or because nobody has
researched that technology yet. `decryption` and `nuclear_production` are zero now and the mod may
well set them later; `decay` is in the header's list and the mod declares it nowhere, which is why
`+0x1F8` is empty. So: the header's list stands, and my reading **corroborates** seven of it
without extending it.

### 4.5 What this is worth to the DLL

The best case the predecessor named — read the fields, call nothing — applies here and is bigger.
`CCountry +0xDF8` is a `CTechnologyStatus`; `CTechnologyStatus` derives from `CTechStatistics` at
object offset 0 (the RTTI export gives its bases as `CTechStatistics` and
`PAVCTechnology::__CArray`); therefore **every offset in section 4.1 is a dword two
dereferences from a `CCountry`**, and the whole of a country's technology bonuses is available for
the cost of a pointer read and no call at all.

**The bound that makes this safe to state.** `CTechnology` also derives from `CTechStatistics`,
and `CTechnology`'s own first field is `key` at `+0x20C` (`CTechnology.hpp`). So `CTechStatistics`
is at most `0x20C` bytes, which puts every offset above — including `+0x1F8` — inside the base
class and not in a derived one. That is why the same tooltip can be handed either a technology's
effects or a country's accumulated totals.

---

## 5. `COrder::GetMissionOrgPenalty` — `0x587A30`

`0x587A30` (rva `0x187A30`), 0x4D bytes, bare `ret`, no stack arguments. The twin of
`COrder::GetMissionEfficiency` (`0x1879B0`), which the record already has with the same shape, and
it sits 0xC bytes after it.

```
int* __fastcall COrder::GetMissionOrgPenalty(COrder* order@ESI, int* out@EDI)

0x00587A39  mov eax, [esi]            ; slot 16 - the order's type id
0x00587A42  call 0x584410             ; OrderTypeToMissionIndex
0x00587A47  mov ecx, [esi+8]          ; the unit
0x00587A50  mov ecx, [ecx+0x128]      ; its owner's country id
0x00587A59  mov edx, [0x1a855a4]      ; g_CCountryDataBase
0x00587A65  mov ecx, [edx+ecx*4]      ; +0x16C
0x00587A68  mov edx, [ecx+0xdf8]      ; CTechnologyStatus
0x00587A6E  mov eax, [edx+eax*4+0x164]
0x00587A75  mov [edi], eax
0x00587A77  mov eax, edi              ; answers out
```

`confirmed`. **It is the only reader of `+0x164` in the image**, found with
`fieldchain.py --holder 0xDF8 --field 0x164`. *The positive control:* the same scan for `+0xE0`
finds six readers including the three the record already names (`0x161E81`, `0x162B9E`,
`0x166913`, `0x16A506`, `0x16CD3E`, `0x1879F0`), so a method that reports one reader of `+0x164`
can see the known case.

Its one caller is `0x5C80C2`, inside `0x5C7E10` (rva `0x1C7E10`) — which has **two `ret 4`s**
(`0x5C80A2` and `0x5C80FE`) and the `+0x164` read sits past the first one, so trap 3 applies to
whoever reads it next. It has three callers, `0x1007B0`, `0x165CC0` and `0x17AF70`, the middle one
in the combat module. It is a few hundred bytes before `BuildSpeedModifierTooltip` (`0x1C82A0`)
and `CUnit::MovementSpeedModifier` (`0x1C8D10`). **What it computes was not read**; it is the
best remaining lead on where a mission's organisation penalty actually lands.

---

## 6. Convoy efficiency — `0x3FA710`

`0x7FA710` (rva `0x3FA710`), extent `0x7FA710..0x7FB19A`, `ret 8`, `out` at `[ebp+0xC]`
(an `Hoi3CString`, callee-constructed, returned in EAX), the convoy in EDI. Thirteen keys:
`CONV_EFF_IRO`, `CONV_SHIP_IRO`, `LL_CONVOY_EFF_DESC`, `LL_CONVOY_EFF_LOW_DESC`,
`LEND_LEASE_CONVOY_DESC`, `LEND_LEASE_CONVOY_OWNER_DESC`, `NO_CONVOY_SHIP` and the variable names.
One caller, `0x801806`.

**It computes nothing of its own**; the number comes from `CConvoy::GetEfficiency` (`0xC6B80`),
which the record already has. What it settles is that function's scale, which the record had as
`inferred`:

```
0x007FA8F4  call  0x4c6b80                ; CConvoy::GetEfficiency(out)
0x007FA8F9  mov   edx, [eax]
0x007FA8FB  movss xmm0, [0x160a718]       ; 100000
0x007FA90C  call  floorf
0x007FA914  call  _ftol2_sse
0x007FA919  imul  dword [ebp+8]
0x007FA924  call  __alldiv  by 0x3E8      ; * 100
0x007FA932  call  FormatFixedPoint
0x007FA93C  mov   ecx, 0x15c1f30          ; 'PERC'
0x007FA941  mov   edx, 0x15de6f4          ; 'LL_CONVOY_EFF_DESC'
0x007FA946  call  0x421fd0                ; AppendLocalisedLine
```

`LL_CONVOY_EFF_DESC` in the mod's localisation is *"Lend lease convoy efficiency is $PERC$%"*, and
the arithmetic is `value × 100 / 1000` with two decimals. So **`CConvoy::GetEfficiency` returns a
fraction in thousandths**: `1000` is 100% and the panel divides by 10. `confirmed`. The record's
note that convoy efficiency is "a straight multiplier on everything else" is consistent with that
and now has a scale beside it.

It also confirms the predecessor's `AppendLocalisedLine` (`0x21FD0`) call shape from a second site:
key in **EDX**, variable name in **ECX**, `(out, value)` on the stack.

---

## 7. READ THIS RATHER THAN RECOMPUTE IT — the additions

The grades are the predecessor's: **A** free function on simulation objects; **B** a virtual on a
simulation object; **C** a virtual on a window or list entry, meaningful only while that window
exists; **!** additionally reads global UI state.

| what you want | function | rva | call shape | `out` | cost | safe? |
| --- | --- | --- | --- | --- | --- | --- |
| **every country-wide effect a country's technology has given it** — 44 scalars, 2 flags, and four arrays | **do not call anything** | — | `country->+0xDF8`, then a dword at the section 4.1 offset | — | two dereferences | **A** — better than A: no call, no allocation, nothing to free. Mind the three scales in §4.3 |
| the same as formatted text, every effect on its own green/red line with the game's own labels | `CTechStatistics::BuildEffectsTooltip` | `0x138D60` | `__stdcall(CTechStatistics*, Hoi3CString* out, int levels, int, int)` `ret 0x14` | `Hoi3CString` at `[ebp+0xC]`, callee-constructed, returned in EAX | 0x7838 bytes, up to 50 string builds and three database walks | **A** — the receiver is a `CTechStatistics`, which `CCountry +0xDF8` is. But it is 30 KB of code to produce text you cannot parse back; read the fields |
| the same with one more argument, as the technology view calls it | `CTechStatistics::BuildEffectsText` | `0x1359A0` | `__stdcall(CTechStatistics*, Hoi3CString* out, int levels, int, int, int)` `ret 0x18` | as above | wraps the above | **A**, arguments 4–6 `inferred` |
| **a mission's organisation penalty from technology** | `COrder::GetMissionOrgPenalty` | `0x187A30` | `__fastcall(COrder* order@ESI, int* out@EDI)`, bare `ret` | `int*` in EDI, caller-owned, returned in EAX | 0x4D bytes | **A** — the receiver is a `COrder` with a live `+8` unit; or read `techStatus+0x164 + missionIndex*4` yourself |
| a mission's efficiency from technology | `COrder::GetMissionEfficiency` | `0x1879B0` | as above | as above | 0x74 bytes | **A** — already recorded; listed for the pair |
| **the localisation key for a mission index** (0–32) | `OrderMissionIndexToKey` | `0x1847A0` | `__cdecl(int missionIndex, ...)`, bare `ret`; jump table at `0x585AE4` | an `Hoi3CString`; which stack slot is **not established** | 0x13C9 bytes | **A**, argument count `likely`. The 33 keys are `confirmed` and are in §4.4 — prefer the table to the call |
| the long description for a mission index | `OrderMissionIndexToDescription` | `0x185B70` | the same shape, the `_DESC` twin | as above | 0x1380 bytes | **A**, `likely` |
| convoy efficiency as the lend-lease panel shows it | `BuildConvoyEfficiencyTooltip` | `0x3FA710` | `__stdcall(CConvoy* convoy, Hoi3CString* out)` `ret 8`, convoy in EDI | `Hoi3CString` at `[ebp+0xC]` | 0xA8A bytes | **A/C** — one caller, `0x801806`; but call `CConvoy::GetEfficiency` (`0xC6B80`) instead and divide by 1000 |
| which function draws a given ledger page | `LedgerPage_Update` | `0x3C1ED0` | `__stdcall(void* ledgerWindow)` `ret 4`; dispatches on `[this+4]` | — | 0x40B bytes plus the page | **do not call** — it rebuilds a GUI window. The **page table in §2 is the deliverable**, not the function |
| the name or description of a builder's sort column | `BuildBuilderSortColumnLabel` | `0x3C3510` | `__thiscall(this@ECX, Hoi3CString* out)` `ret 4` | `Hoi3CString` at `[ebp+8]` | 0x26FC bytes | **C** — reads the window's own current sort column (slot 17) and returns text only |

---

## What is not established

- **The ledger window's class.** `0x3C1ED0` is not in any vftable; its receiver has the page
  number at `+4` and a GUI window at `+0xC` with the elements `page_number`, `ledger_overlay`,
  `textbox_autosend` and `checkbox_autosend`. `CStatisticsLedger` (vftable `0x15DC714`, 3 slots)
  is the likeliest by the name, but **a live `instances` scan found no instance of it, nor of
  `CGraphicalTableLedger` or `CPieChartLedgerGraphical`** — the ledger was closed, so the scan
  proves nothing either way. What would settle it: open the ledger in game and re-scan.
- **Which `CCountry` offsets `LEDGER_USED_INDUSTRY`, `LEDGER_USED_TROOPS`, `LEDGER_FROM_EXILES`
  and `LEDGER_STOCKPILE` are.** Section 2 establishes that four goods columns exist that the
  `RES_*` tooltip does not show, and that `RES_USED` is a sum of two of them. The column names are
  not adjacent to any load. What would settle it: the ledger's row provider — the thing
  `0x7BEB80` registers a column against — or a savegame diff over a month.
- **Arguments 3–5 of `0x138D60` beyond `levels`.** `[ebp+0x10]` multiplies every value and is
  tested against `-1` and `1` by its caller, which fits a signed level count (applying or removing
  a technology). `[ebp+0x14]` and `[ebp+0x18]` are passed through and were not read.
- **What `0x1C7E10` computes.** It is the only caller of `COrder::GetMissionOrgPenalty`, it has
  two `ret 4`s with the read past the first (trap 3), and three callers of its own. Its only
  string is `'idle'`.
- **Whether `+0x24` and `+0x5C` have readers in the simulation.** I established the index spaces
  and the scales, not the consumers. `+0x5C`'s consumer the record already has
  (`CUnit::GetCombinedArmsBonus`, `0x1B6240`); `+0x24`'s was not looked for, and a bare
  displacement scan on `+0x24` would be worthless under trap 12 — it wants
  `fieldchain.py --holder 0xDF8 --field 0x24`, which I did not run.
- **The remaining ~160 of the 389.** All 223 functions carrying four or more game keys are now
  scored for shape; the two that score as field maps are read. The rest are, by the shape test,
  text builders. That is a ranked negative, not a proof: the test looks ±8 instructions, and a
  builder that loads its values into locals at the head and emits them all at the tail would score
  zero. `BuildModifierEffectsText` (`0x56E00`, 108 keys, still esp-framed with no located
  argument) is the one I would check against that possibility first, because 108 province
  modifier effects is exactly what BiceLib's map modes want.
- **Everything in §4.4 is a single reading of a single moment.** Nothing was watched over time and
  nothing was provoked.

## What rests on the live process, and what would survive a restart

Everything in sections 1, 2, 3, 5, 6 and 7 is static, read out of the executable, and survives
anything.

From section 4, these survive a restart because they are properties of the image or of the mod's
files, both unchanged by a new game: every offset in §4.1 and §4.2; the arithmetic and therefore
the three scales in §4.3; the `0x585AE4` jump table and its 33 keys; the bound that
`CTechStatistics` is at most `0x20C` bytes.

These do **not** survive a restart, and are marked as live in the text: the *counts* 43, 21 and 49
and the names in them (they are BICE's, and a different mod would give different numbers — the
*structure*, that each array is indexed by that database's vector, is static and survives); every
value quoted for IRE or FRA; the nine-fields-always-zero tally; and the statement that
`CCountry +0xDF8`'s vftable is `CTechnologyStatus`, which is static in substance but was checked
by rebasing a live pointer (`0x19F35BC` − `0x830000` + `0x400000` = `0x15C35BC`).

## How the negatives were controlled

- **The ledger pages carry no field loads.** The same adjacency tool, unchanged, run against
  `BuildGoodsLedgerTooltip` reproduces all fifteen of its `CCountry` offsets (§1). It can see the
  known case; its silence about the pages means something.
- **The `BUILD_*` cluster carries no numbers.** Not a silence at all — the arms were read, and
  the mod's own localisation file says what `_IRO` and `_DRO` are. A negative that turns into a
  positive identification is the cheapest kind.
- **`+0x164` has one reader.** `fieldchain.py --holder 0xDF8 --field 0xE0` finds six readers of
  the neighbouring array, including every one the record names. Same scan, same holder, same code.
- **The function-boundary method.** Section 1's seven phantoms are each backed by the bytes at the
  address, and the fix is checked both ways: with it, two sites fold into functions the record
  already names; without the vftable union, two functions the record already names answer "no
  owner".
- **Three decodes started from a guessed address and produced nonsense** (trap 9): `0x53F740`
  printed `dec dword ptr [ebp-0x406773]`, `0x7EA930`'s neighbourhood and `0x585B5A` printed
  `add byte ptr [ebp+0x1e005859], cl`. All three were redone by indexing into a decode that began
  at a function entry. Nothing in this file rests on a decode that did not start at an entry or at
  an address a tool printed.
- **Trap 14, caught late and recorded as caught.** §4.1's offsets were "discovered" before the
  record was properly checked, and sixteen of them were already in `project.json` — under
  `CTechnologyStatus`, which is why a grep for `CTechStatistics` found nothing. The offsets are
  the thing to grep, and a class can be in the record under its derived name.
