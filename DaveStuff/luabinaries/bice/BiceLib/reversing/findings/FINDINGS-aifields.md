# Six fields the AI reads and nothing named

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is
marked *seen* and every live check is listed at the end instead. Addresses are **virtual** (image
base `0x400000`) with the rva beside them wherever a finding depends on one. The six questions came
from the "what is not established" lists of `FINDINGS-negatives.md`, `FINDINGS-power.md`,
`FINDINGS-setarea.md` and `FINDINGS-politics.md`. Scripts are in `scratchpad/aifields/`.

## In one line

`CGameState +0xBAC` is the **allied objectives, inverted** — the save key is `allied_objectives` and
the only thing that writes one is `CSetAlliedObjectiveCommand`, so the AI's flat +100 objective
bonus is a player or AI asking an ally to take a province; `CCountry +0xACC` is `at_war`, from its
sole writer; `CMapProvince +0x5C` is the province's **infrastructure**, because the `+0x24` the
writer gates on is a **modifier id and never was a building index**, which dissolves the blocker
rather than solving it; `+0x304` is the **air base**, a name the record already carries on
`CProvince` and contradicts on `CMapProvince`; `CArmy +0x2FC` has **ten** values, 0..9, all of them
read off one `ret`-less classifier that is `CArmy` virtual slot 41; and `+0x618`/`+0x628` were
already closed, so what is added there is the two arrays' **lengths**, which settle it a fourth way.

## 0. The method, and the one place it needed a control

Four of the six were name-the-field questions and three of those were already named — the brief was
built from the surveys' own open lists without grepping `project.json`, which is trap 14 arriving
from the direction `TRAPS.md` warns about. Each section below says what the record already had, so
the convergences are visible as convergences.

The only claim here that is a negative is "how many writers does `CMapProvince +0x5C` have", and the
record's answer to it (*exactly one*) turns out to be wrong. `scratchpad/aifields/storescan.py` is
what settled it: entries are the union of every `call rel32` target and every slot of every vftable
in the RTTI export, each body decoded forward from its entry to the first run of two `int3` (so a
cold path past a `ret` stays inside its own body, trap 3, at the price of over-reach into an
abutting function, trap 2 — the safe direction here). Nothing is decoded from a guess (trap 9). It
reports **427 stores to `[reg + 0x5C]`** in `.text`, and because `0x5C` is encoded as a `disp8` a
byte search cannot find any of them, which is why the cheaper `dispscan.py` is useless for this
offset and says so.

*The positive control:* the scan finds `0x496152`, the writer the record already names, and the
"distinctive neighbours" filter of trap 12 marks it as a province because the same register is used
with `+0xD0` and `+0x310` in the same body. It also marks 226 others, nearly all on `+0x4C`/`+0x50`
alone, which are worthless — so every candidate carrying three or more province-distinctive
displacements was read by hand, and that is where the two extra computing writers came from. A scan
that could not see `0x496152` would have said nothing about them.

---

## 1. `CGameState +0xBAC` is the allied objectives, keyed by who asked

`CEU3AI::RebuildPriorityProvinces` (`0x8976E0`, rva `0x4976E0`, `ret 4`) is read in full below,
because the record's account of its second half has the membership test backwards.

### What the field is

`+0xBAC` and `+0xB9C` are twins, and the constructor says so: `CGameState::CGameState` zeroes
`+0xB9C`/`+0xBA0`/`+0xBA4` at `0x67D2E7`–`0x67D2F3` and `+0xBAC`/`+0xBB0`/`+0xBB4` at
`0x67D2F9`–`0x67D305`, in the same run of vector triples that gives `+0xB8C` the provinces and
`+0xBBC` the countries. Both are `std::vector` with **0x10-byte elements**, and both are resized to
the **country count** by `0x67E320` (`ret 8`): `0x67E413`–`0x67E425` computes
`(state->+0xBC0 - state->+0xBBC) / 4` and `0x67E428`'s `sar eax, 4` is the element size, through the
0x10-element helpers `0x68D760`/`0x68D7D0`/`0x68F3C0`. So **the subscript is a country id, not a
province id.**

Each element is itself a vector — begin, end, capacity — of **0x14-byte records**. A record is
`{ province id, int* begin, int* end, int* capacity, ? }`: the inner vector's element size is 4
(`sar eax, 2` at `0x89798B`-adjacent reads and at `0x67F9F8`) and the outer stride is 0x14 (`add ebx, 0x14`
at `0x897982`, `add [esp+0x40], 0x14` at `0x67FA35`, the `0x66666667`/`sar edx, 3` divide-by-20 at
`0x68AD4D`–`0x68AD65`).

### The save key names it

`CGameState::LoadKey` (`0x67FCB0`) has a case for token **1880, `allied_objectives`**, and
`switchmap.py`'s own solver puts that case at **`0x680973`** — which is the arm that reads a list of
ints through `0x45F450` and then consumes them **three at a time**:

```
0x680995   ReadIntList(parse, &v)
0x6809B0   a = v[i] ; c = v[i+1] ; b = v[i+2]
0x6809BF   0x68AD20(state, a, b, c)                      ; add one objective
0x6809C4   i += 3
```

`CGameState::SaveContents` (slot 2, `0x67E6F0`) writes the same key from **`+0xB9C` only**, at
`0x67F97E`–`0x67FA73`:

```
for i in 0 .. (+0xBA0 - +0xB9C)/0x10:        ; i is a country id
    for each 0x14-byte record r in (+0xB9C)[i]:
        for each int q in r->+4 .. r->+8:
            push_back(out, r->+0)            ; 0x67FA09
            push_back(out, q)                ; 0x67FA18
            push_back(out, i)                ; 0x67FA21
SaveWriteKey(0x758, out)                     ; 0x67FA6C, 0x67FA73 - skipped when out is empty
```

So the save holds triples **(province, q, i)** and the loader hands `0x68AD20` **(province, i, q)**.
The two agree, which is a round-trip check rather than a reading of one side.

### Who the two country ids are

`CSetAlliedObjectiveCommand::Execute` is **`0x553C00`** (rva `0x153C00`), `CSetAlliedObjectiveCommand`
virtual slot 6 — found by reading `0x15C3EE4 + 6*4` out of the RTTI export, not inferred. Its whole
body:

```
if (this->province (+0x4C) < 0)        return      ; 0x553C21
if (this->requester_id (+0x48) == 0)   return      ; 0x553C2A
if (this->country_id   (+0x40) == 0)   return      ; 0x553C38
state = GetCurrentGameState()                       ; inlined, 0x553C56-0x553CC2
if (this->active (+0x50))                           ; 0x553C4D
     0x68AD20(state, province, country_id, requester_id)   ; 0x553CD0
else 0x68B270(state, province, country_id, requester_id)   ; 0x553D64
```

Its slot 5 at `0x553D80` is `mov eax, 0x757; ret` — save token **1879, `set_allied_objective`**, the
command's own name. `FINDINGS-fieldmap.md` places three of its four keys (`country` `+0x3C`/`+0x40`,
`requester` `+0x44`/`+0x48`, `province` `+0x4C`) and lists `active` as unplaced; it is the byte at
**`+0x50`**, read at `0x553C4D`.

`0x68AD20` (rva `0x28AD20`, `ret 0x10`) then writes **both** indexes:

```
rec = find-or-create a record with +0 == province in (state->+0xB9C)[country_id]   ; 0x68AD44-0x68AE19
append requester_id to rec's int vector, unless already present                    ; 0x68AD91, 0x68AE96
rec2 = find-or-create a record with +0 == province in (state->+0xBAC)[requester_id] ; 0x68AF83-0x68AF8C
append country_id to rec2's int vector, unless already present                      ; 0x68B0E7, 0x68B247
```

`0x68B270` (`ret 0x10`) is the exact inverse and `0x68B4C0` (`ret 8`) empties both entries for one
country and scrubs that country out of every other country's requester lists — its one caller is
`CFaction::RemoveMember` (`0x522700`, `ret 4`, `this` in ecx) at `0x5227C3`, so leaving a faction
cancels every allied objective in either direction. `0x68B4C0` is also the cleanest single proof that
the outer subscript and the inner ints are both country ids.

**So: `CGameState +0xB9C` is the allied objectives indexed by the country the objective is set for,
and `+0xBAC` is the same data indexed by the country that asked.** Only `+0xB9C` is saved; `+0xBAC`
is rebuilt on load because `0x68AD20` writes both.

### What `0x8976E0` actually does with it

```
free every node of ai->+0x118 and zero +0x118/+0x11C/+0x120            ; 0x897703-0x897731
me = CCountryTag::GetCountry(&ai->+0x20)                               ; 0x897722, call 0x402610
if (me->at_war (+0xACC) == 0) return                                   ; 0x89773C -> 0x897A1F
if (!me->faction(+0xD8)->slot7()) skip the faction walk                ; 0x89775F-0x89776E
for node in me->faction->+0x28:                                        ; head at 0x897782, next +0xC
    if (node->id (+4) == ai->+0x24) continue                           ; 0x8977A1
    if (countryDb[0x1A855A4]->+0x16C[node->id]->at_war (+0xACC) == 0) continue   ; 0x8977BB
    append the tag to a local 0x14-byte-node list                      ; 0x8977C4-0x8977ED
for node in me->non_hostile_countries (+0xF98):                        ; 0x897826, no at_war filter
    if (node->id == ai->+0x24) continue                                ; 0x897845
    if the local list already holds that id, continue                  ; 0x897852
    append it
for each tag Y on the local list:                                      ; 0x8978C6
    if (Y == ai->+0x24) continue
    state = GetCurrentGameState()                                      ; inlined, 0x8978DF-0x897949
    for each 0x14-byte record r in (state->+0xBAC)[Y]:                 ; 0x897954, 0x897957
        if (r's int vector contains ai->+0x24)                         ; 0x897990-0x89799B
            append r->+0 to ai->+0x118                                 ; 0x89799F-0x897A03
destroy the local list                                                 ; 0x897A1A
```

Read in English: **for every ally at war and every non-hostile neighbour, take the provinces that
country has asked *us* to take, and give each of them +100 on its AI objective priority.** The
faction slot 7 test is a constant-returning virtual — `0xA92590` is `mov al, 1; ret` for `CFaction`
and `0x592360` is `xor al, al; ret` for `CNullFaction` — so it is "is this a real faction", and it is
left unnamed here because `mov al,1; ret` is exactly the shape trap 4 is about.

The `+0xACC` filter applies only to the faction walk; the `+0xF98` walk has none. And the whole pass
is abandoned at `0x89773C` unless **our own** country is at war, so `CEU3AI +0x118` is empty in
peacetime whatever anyone has set.

### Two things a modder can act on

`set_allied_objective` is the only producer. Nothing in the AI, the event system or any loader
creates one: `allied_objectives` has no other writer, and none of the three savegames checked in this
repository contains the key at all (`Germany1936_01_06_01`, `IRE_1941_10_30_01_premonth`,
`Ireland1941_10_27_10`) — *control:* the same grep over the same files finds `automate_sliders`,
`victory_conditions` and `fired_events` once each and `battle_plan` 255 times, so the absence is the
feature being unused and not a bad grep. The writer skips the key when the vector is empty
(`test ecx, 0xFFFFFFFC; jle` at `0x67FA5F`), which is why an unused feature leaves no trace.

And because `FINDINGS-negatives.md` established that **nothing weights, scores or orders anything by
`CObjective::priority`**, this +100 cannot steer the AI either. What it does do is make the
generator's dirty check at `0x89871A` fail, so the AI reposts its objective list that hour. Setting
an allied objective is visible to the AI exactly as far as "recompute", and no further.

---

## 2. `CCountry +0xACC` is `at_war`, from its only writer

The record carried this as a comment and never as a field: `CLASSES.md` and
`BiceLib/GameClasses/CCountry.hpp:297` both say "isAtWar is the byte at `+0xACC`" in passing on
`last_surrender`, and `project.json` has no entry at the offset. Position is not evidence (trap 12),
so here is the writer.

**`0x4E6A70`** (rva `0xE6A70`, `ret 8`, `this` in ecx) is the only body in `.text` that stores to a
byte at `[reg+0xACC]` through an object base — the two sites are `0x4E6A91` and `0x4E6BCC`, both in
it. (`dispscan.py 0xACC` finds 101 instructions carrying the displacement; the only other byte
stores are `esp`-relative stack locals, and the one `mov dword ptr [ebx+0xacc], 0x838b0000` at
`0x4D4637` is a misaligned decode, as the immediate shows.)

```
this->at_war (+0xACC) = 0                                        ; 0x4E6A91
free the list at +0x1008, zero +0x1008/+0x100C/+0x1010           ; 0x4E6A97-0x4E6AC0
state = GetCurrentGameState() ; tick = state->+0xBDC             ; 0x4E6B3F
db = [0x1A855A4] ; n = db->+0x168                                ; 0x4E6B85
for i in 0..n:
    other = db->+0x16C[i]
    dip = this->+0xE28[other->id (+0xCA8)]                       ; 0x4E6BBB
    if (dip->war (+0x20) == 0) continue                          ; 0x4E6BC7
    this->at_war = 1                                             ; 0x4E6BCC
    append {other->tag(+0xCA4), other->id, prev, next, byte} to +0x1008   ; 0x4E6BD9-0x4E6C29
    dip->+0x54 = tick                                            ; 0x4E6C32
```

`CDiplomacyStatus +0x20` is already recorded as `war`. So **`+0xACC` is set exactly when some
diplomacy status says this country is at war with somebody**, it is recomputed from scratch, and
every reader in the image tests it as a byte against zero. That is `at_war`, and it agrees with the
header's comment — two readings converging, which trap 14 says to expect.

The same loop is the writer of **`CCountry +0x1008`**, a `CCountryList` of the countries we are at
war with (tail `+0x100C`, count `+0x1010`, nodes `0x14` bytes `{tagChars, tagId, prev@+8, next@+0xC,
byte}`). `project.json` already notes that the inferred `CCountry::IsWarTarget` (rva `0xA9390`)
"consults `ourCountry->+0x1008`"; this is what it consults, so the function is `enemies`.

**Nine callers, and they are what the name has to fit:** `0x65B398`, inside `CInGameIdler`'s hourly
body, and eight sites between `0xA503D6` and `0xA51BF5` in the diplomacy-action code, each of which
resolves two `CCountryTag` through `0x402610` and calls this on **both** sides. Nothing else writes
`at_war`, so a mod cannot set it and a hook on it is a hook on this function.

The second half of the body is the mobilisation side and gives one more field: `+0x94` is
**`mobilised`**, set to 1 at `0x4E6D49` immediately after the static modifier `initial_mobilization`
is added, on the transition from clear to at-war; the modifier is removed again on the reverse
transition, and the path at `0x4E6E44` also clears `+0x94` at `0x4E6EBD` — but only when the
played-countries array `CGameState +0xBCC` says the country is not played. `project.json` already
records that `CSubUnit` slot 12 skips `RESERVES_PENALTY_SIZE` when the owner's `+0x94` is set, which
is what mobilisation would do, so the name is `likely` rather than `confirmed`; the asymmetry is the
reason.

---

## 3. `CMapProvince +0x5C` is the province's infrastructure

The record has this as `ai_front_value` with a precise role and an open identity: *"when the loaded
building's definition `+0x24` is 12… Which building type index 12 is was not established — the mod
reorders `common/buildings.txt`, so it is not safe to count."*

**The blocker is not a blocker, because `+0x24` is not an index into anything the mod can reorder.**
The instruction before the gate loads it:

```
0x496125   mov ecx, [esi + 0xC]          ; esi is the CBuilding, +0xC is its CModifier
0x496128   cmp dword ptr [ecx + 0x24], 0xC
```

`project.json` already records both halves of that and never joined them: `CBuilding +0xC` is
`effect`, "the modifier definition `effect_size` belongs to", and `CModifier +0x24` is `id`, "which
modifier this is… the constructor at rva `0x56D50` takes it in edx and writes it here". The identical
three-instruction shape is the recorded `CBuildingDataBase_RoleByModifierId` (rva `0xB78AB`), whose
five compares at `0x4B78AE` onward are against `0x2E`, `0x2D`, `0x4B`, `0x0F`, `0x66` —
MODIFIER_AIR_CAPACITY, NAVAL_CAPACITY, LOCAL_AA, IC, LOCAL_UNDERGROUND — i.e. **modifier ids, from a
fixed engine-side enum of 107 entries that `reversing/scripts/modifierIds.py` reads straight out of the
global initialiser.**

Entry **12 is `MODIFIER_INFRASTRUCTURE`**. The building that carries it is `infra`, whatever position
it holds in the file; BlackICE's `common/buildings.txt` declares `infra = { … infrastructure = 0.1 …
max_level = 10 }` as "building no.21" and that number is irrelevant.

So the formula at `0x496132`–`0x496152` reads:

```
province->+0x5C = infraBuilding->level_max (+0x20) * infraDefinition->effect_size (+0x8) / 1000
```

`CProvinceBuilding +0x20` is `level_max`, **x1000** (`BiceLib/GameClasses/CProvinceBuilding.hpp`:
"an infrastructure of 4 reads as 4000… of 1,500 provinces carrying infrastructure, all 1,500 give a
level between 1 and 10 once divided down"), and `effect_size` is 100 for `infrastructure = 0.1`. So
`+0x5C` is `level × 100`: **0 to 1000 in thousandths, where 1000 is infra 10 and 100% — the figure
the game's own UI shows as a percentage.** The AI's 200 and 300 thresholds are 20% and 30%, i.e.
infra levels 2 and 3.

### Three further routes, each independent of the formula

**(a) The tooltip calls it infra.** `ProvinceTooltip_Build` (`0x4973E0`) emits the localisation key
**`TOOLOWINFRA`** when the field is below 200:

```
0x4993DB   mov eax, [edi + 0xCC]          ; the CProvinceTemplate
0x4993E1   cmp byte [eax + 0x22], bl      ; is_land
0x4993EA   mov eax, [edi + 0x54]
0x4993ED   cmp eax, [0x1A86CD0]           ; g_FixedPoint0_200
0x4993F3   jge <skip>
0x4993F9   mov edx, 0x15BE634             ; 'TOOLOWINFRA'
```

`edi` is **province + 8** — the `CSelectable` sub-object, which is why `CMapProvince` has a second
vftable at `+0x8`. It is used with `-0x8` in the same body, and six already-recorded fields line up
under the shift: `+0xC8`/`+0xCC` are `id`/`path_node_ptr`, `+0x2A8` is `capital`, `+0x2F8`/`+0x2FC`
are `naval_base`/`air_base`, `+0x32C`/`+0x330` are `controller`/`controller_id`. So `[edi+0x54]` is
`province +0x5C`. (This site is past the function's first `ret 8` at `0x4983B4` — trap 3 — and the
frame check settles it: the block after it writes `[esp+0x2244]`, the same EH state slot as the
prologue's `sub esp, 0x2244`-sized frame, and the byte after the `ret` is a bare
`mov eax, [0x1A89790]` with no padding and no prologue.)

**(b) The crossing thresholds are infra levels 1 and 2.** `0x4B7FA0` (rva `0xB7FA0`, `ret 4`) is a
`CProvinceBuilding` method — `this` on the stack, `this->+0x18` its `CBuilding` and `this->+0x1C` its
province — and it runs after a level has moved:

```
0x4B7FC4   cmp [this->+0x18->+0xC + 0x24], 0xC        ; MODIFIER_INFRASTRUCTURE again
0x4B7FD7   edi = province->+0x5C                       ; the old value
0x4B8024   province->+0x5C = this->level_max (+0x20) / 10
0x4B8029   cmp edi, [0x1A87098]                        ; 200
0x4B802F   cmp new, [0x1A870B4]                        ; 100
0x4B808E   raise a message through 0x47F540 with the province's controller
0x4B8096   invalidate four path/supply caches: 0x47FFF0, 0x47FEB0, 0x4807F0, 0x480690
```

`[0x1A87098]` is `(int)floorf(200.5f)` from its own initialiser at `0xCB3CB0`, `[0x1A870B4]` is
`(int)floorf(100.5f)` from `0xCB3C20` — one reader each, hence the names `g_InfraThreshold0_200` and
`g_InfraThreshold0_100`, and both are separate statics over the same two floats as the recorded
`g_FixedPoint0_200`/`g_FixedPoint0_100` (trap 8's third case: no `defines.lua` entry reaches any of
them). Crossing one full level of infrastructure invalidating the pathfinder is exactly what the
`impassable_infra` province flag in a savegame is about. **Note also that this writer hardcodes the
0.1** — a multiply by 1000 and a divide by 10000 — where the other two read it out of `effect_size`.

**(c) The savegame.** `Ireland1941_10_27_10.hoi3` province 1 reads
`infra = { 1.000 1.000 }` — `level_max` and `level_current` — and carries
`flags = { impassable_infra = yes }`. Level 1 is `+0x5C` = 100, which is the threshold in (b).

### What this changes about the field's meaning

- It is computed from **`level_max`, not `level_current`** (`0x49613E`, `0x4A3B01`-adjacent,
  `0x4B7FD1`). A province whose infrastructure has been bombed but not demolished still reports its
  undamaged figure to the AI.
- It is **not** the aggregate infrastructure the simulation uses. That is
  `provinceValues[MODIFIER_INFRASTRUCTURE]` in the array at `+0x114` scaled by LOCAL_ and
  GLOBAL_INFRASTRUCTURE, which the supply relaxation, the daily province pass and the muddyness
  branch all read and which `project.json` already documents. So a national or event modifier moves
  the simulation's infrastructure and **cannot** move the AI's front test.
- It **is** maintained during play, which the record's one-writer reading implied it was not. See
  the corrections.

---

## 4. `CMapProvince +0x304` is the air base — and the record already said so once

`project.json` carries the offset twice, with two different names, because Ghidra has no inheritance
between `CProvince` and `CMapProvince`:

| | |
| --- | --- |
| `CProvince +0x304` | `air_base` — "`buildings[air_base.index]`: the province's air base, cached at rva `0x9694F` out of `g_CBuildingDataBase +0x1C`" |
| `CMapProvince +0x304` | `ai_param_building` — "A pointer to one of the province's buildings… Which building it points at was not established" |

`CMapProvince` derives from `CProvince` and adds nothing at the offset, so they are one field and the
first entry answers the second. Confirmed at the instruction:

```
0x496940   eax = g_CBuildingDataBase[0x1A870D4]->+0x1C     ; the cached air_base CBuilding
0x496943   eax = eax->index (+0x54)
0x496946   ecx = province->+0x310                          ; the CProvinceBuilding* array
0x49694F   province->+0x304 = ecx[eax]
```

and it is one of four in a row in the same body (`0x496480`): `+0x300` from `db->+0x20` at `0x4969D7`,
`+0x308` from `db->+0x24` at `0x4968C7`, `+0x30C` from `db->+0x28` at `0x496A5F`. The database slots
are already named in `project.json` from `CBuildingDataBase_RoleByModifierId`: `+0x1C` is the
building whose modifier is `MODIFIER_AIR_CAPACITY` (`0x2E`), which is `air_base`.

So `CAIUnit` slot 78's test at `0x4B245F`–`0x4B2482` —
`provinces[army->ai_param_b]->+0x304->+0x20 / 1000 >= 1` — reads: **"does that province still have an
air base of at least level 1"**, and `CArmy +0x2E4 ai_param_b` is the id of a province an air-base
task was set for. (`+0x20` is `level_max`, so the test survives damage; it fails only when the base
is gone.)

---

## 5. `CArmy +0x2FC`: the enum is 0..9 and the writer enumerates all ten

**`0x5CE8A0`** (rva `0x1CE8A0`, bare `ret`, `this` in ecx) is **`CArmy` virtual slot 41** — read out
of `0x15BDE0C + 41*4`, not inferred. It has **zero direct callers**; it is only ever dispatched. And
it is the only implementation in the family: `CUnit` slot 41 is `_purecall` (`0xB961D5`, which pushes
`[0x174D238]` and calls through `[0xD2B040]`), and `CAir` and `CNavy` both hold the folded empty stub
`0xABF890` there — the 1691-holder stub trap 4 names. So **only an army has a role.**

It writes ten literals: 9 at `0x5CE8C1`, 0 at `0x5CEB15`, 3 at `0x5CEB04`, 5 at `0x5CEB34`, `edi` at
`0x5CEB46` (and `edi = 6` at `0x5CEA0A`), 7 at `0x5CEB54`, 8 at `0x5CEB66`, 4 at `0x5CEBA6`, 1 at
`0x5CEC04`, 2 at `0x5CEC17`. That is the whole value set, read off stores rather than off branches.

```
role = 9                                                            ; 0x5CE8C1
if (this->brigade_count (+0x40) == 0) return                        ; 0x5CE8CB -> 0x5CEC23, role stays 9
for node in this->+0x38:                                            ; the PAVCSubUnit::__CList base
    def = node->subunit->sub_unit_definition_ptr (+0x58)            ; 0x5CEA47-0x5CEA49
    t   = def->type_index (+0x24)                                   ; 0x5CEA4C
    if (t == db->hq_brigade(+0x78)->type_index) { role = 0; return } ; 0x5CEA52 -> 0x5CEB10
    if (t is police(+0x4C) / garrison(+0x50) / militia(+0x54))  ++n5
    if (t == bergsjaeger(+0x40))                                ++n6
    if (t == marine(+0x44))                                     ++n7
    if (t == paratrooper(+0x48))                                ++n8
    if (def->combat_width (+0xE8) < 1000) ++narrow                   ; 0x5CEAA6
    speedSum    += def->max_speed (+0x108)                          ; 0x5CEAB5
    softnessSum += def->softness  (+0x124)                          ; 0x5CEABE
n = this->+0x40
if (softnessSum / n <  g_FixedPoint0_500)  { role = 3; goto done }   ; 0x5CEAFC
else if (n5) role = 5 ; else if (n6) role = 6
     else if (n7) role = 7 ; else if (n8) role = 8                   ; 0x5CEB2E-0x5CEB66
done:
if (role == 9) {                                                    ; 0x5CEB70
    if (speedSum / n >= 6000)                 role = 4              ; 0x5CEB9F
    else if (narrow*1000 / n >= g_FixedPoint0_500) role = 1         ; 0x5CEBFC
    if (role == 9)                            role = 2              ; 0x5CEC0E-0x5CEC17
}
```

The seven brigade keys come from cached `CSubUnitDefinition*` on `g_CSubUnitDataBase`, and the record
**already names every one of those slots** from `CSubUnitDataBase_RoleByKey` — so re-deriving the
chain at `0x5AF867` was a convergence check, not a discovery: `+0x78 hq_brigade`,
`+0x4C police_brigade`, `+0x50 garrison_brigade`, `+0x54 militia_brigade`,
`+0x40 bergsjaeger_brigade`, `+0x44 marine_brigade`, `+0x48 paratrooper_brigade`. It agreed on all
seven.

`g_FixedPoint0_500` is `[0x1A8875C]` (rva `0x168875C`), `(int)floorf(500.5f)` from the initialiser at
`0xCC4150` over the float `0x160A5E8` — **the same literal that already seeds `g_AiAreaWeightFloor`
(`0x1715218`) and `0x16886AC`**, so this is a third static over one float and naming it after any one
use would overstate it. Its only other reader is `0x5C6189`.

### What the numbers mean

In the body's own order of precedence:

| value | the condition | reads as |
| --- | --- | --- |
| 9 | no brigades at all | empty formation |
| 0 | any brigade is an `hq_brigade` | an HQ |
| 3 | average `softness` under 0.500 | armour |
| 5 | any `police_brigade`, `garrison_brigade` or `militia_brigade` | garrison |
| 6 | any `bergsjaeger_brigade` | mountain |
| 7 | any `marine_brigade` | marine |
| 8 | any `paratrooper_brigade` | airborne |
| 4 | average `max_speed` at or above 6.000 | motorised |
| 1 | at least half the brigades have `combat_width` under 1.000 | mostly support |
| 2 | anything else | infantry |

The English words are this reading's; the numbers and the conditions are instructions. Two of the
four come with a cross-check: in the stock `units/` folder, `combat_width = 0` is exactly the support
brigades (`anti_air`, `anti_tank`, `armored_car`, `artillery`, `engineer`, `hq`, `police`,
`rocket_artillery`, `sp_artillery`, `sp_rct_artillery`, `super_heavy_armor`, `tank_destroyer`),
`combat_width = 1` the infantry family and `combat_width = 2` the three armour brigades — so role 1
is a formation that is half support or more; and softness under 0.5 is the armour brigades and
nothing else.

So the branches `FINDINGS-power.md` recorded read as: slot 78's `== 8` at `0x4B231E`, `0x4B2BC2` and
`0x4B30B9` is **an airborne formation**, and the `== 3` / `== 4` pair in its detachment score at
`0x4B30FA`–`0x4B3170` is **armour against motorised**.

Finally, **it is recomputed whenever the order of battle changes**: `AddRegimentToUnit` (`0x5BE640`)
dispatches slot 41 at `0x5BE96A` and `RemoveRegimentFromUnit` (`0x5BE9A0`) at `0x5BED3F`, both with
`ecx` = the unit. (`slotcalls.py 41` reports 45 sites in 34 functions and is unselective, as its own
docstring warns; those two were confirmed by reading the `mov eax, [edx+0xA4]; call eax` pair, and
`0x5C2B6A` was rejected because its `[eax+0xA4]` is on a `CProvinceTemplate`.)

---

## 6. `CCountry +0x618` vs `+0x628` was already closed — here are the bounds that close it a fourth way

`project.json` already names `+0x618 ministers` and `+0x628 laws` and already carries the slot-count
argument. One line, as asked: I had read the two `Execute` bodies before the correction arrived, so
what follows is the part that was not already there, and nothing in it disagrees.

**The two commands' index fields are different because `position` is two different classes.**
`CChangeMinisterCommand::Execute` (`0x54E2D0`, slot 6, bare `ret`) is one statement at
`0x54E305`–`0x54E31E`: `GetCountryById(cmd->+0x40)->ministers[ cmd->position(+0x48)->+0x4C ] = cmd->id(+0x44)`.
`CChangeLawCommand::Execute` (`0x54EF60`, slot 6, bare `ret`) is
`GetCountryById(cmd->+0x40)->laws[ cmd->position(+0x48)->+0x50 ] = cmd->law(+0x44)` at
`0x54EF85`–`0x54EFB0`. `CChangeLawCommand::LoadKey`'s `position` arm (`0x54FC57`) sscanf's an integer
and indexes **`GetLawDataBase()->+0x28`**, the law-group vector; its `law` arm (`0x54FC9E`) indexes
`->+0x18`, the law vector. `GetLawDataBase` is `0x5298C0` (rva `0x1298C0`, bare `ret`, the usual lazy
singleton over `[0x1A878C8]`, abutting its own constructor at `0x529920` with no padding — trap 2).
So `+0x4C` is `CGovernmentPosition::index`, which `project.json` already has, and `+0x50` is
`CLawGroup`'s own index.

**The array lengths settle it on their own.** Both are `std::vector<T*>`, stride 4, zeroed together
in the constructor (`0x4C8D2B`, `0x4C8D3D`) and freed together (`0x4CB179`, `0x4CB154`):

| | `+0x618` | `+0x628` |
| --- | --- | --- |
| end / capacity | `+0x61C` / `+0x620` | `+0x62C` / `+0x630` |
| resized at | `0x4CA09A`–`0x4CA0AA` | `0x4CA1D0`–`0x4CA1E0` |
| to the count of | `[0x1A87990]->+0x10 - +0xC` over 4, **the government positions** | `GetLawDataBase()->+0x2C - +0x28` over 4, **the law groups** |
| pre-filled with | the `CNullMinister` singleton `[0x1A855C8]`, built by `0x52C1B0` | the `CNullLaw` singleton `[0x1A855B8]`, built by `0x529400` |
| save guard | slot 8 — `CMinister`'s last of nine | slot 16 — `CLaw`'s last of seventeen |

The two singleton constructors were identified by the vftable they write, out of the RTTI export, not
by name. That is a fourth agreeing reading and the one that cannot be confused by a slot number: an
array one entry per law group and filled with `CNullLaw` is the laws.

**The save keys.** `CCountry::SaveContents` walks `+0x618` at `0x4D0F96`–`0x4D109B`, asks slot 8, and
writes `position->+0x2C` as the key and the minister's `id` (`+0xC`) through `%d`
(`0x15FD128`) as the value. It walks `+0x628` at `0x4D10C1`–`0x4D11BE`, asks slot 16, and writes
`group->+0x54` as the key and `law->+0x2C` as the value — both of those are **save tokens**, written
through `0xA7A1B0` and `0x461360` respectively, so a country's laws are saved as
`<law group name> = <law name>`. Which is why `CCountry::LoadKey` has **no `law` key at all**: the
default arm resolves the key text as a law group through the database's name map at `0x4CF337`–
`0x4CF3A7`, looks the value up as a law, and stores it at `laws[group->+0x50]`. `switchmap.py` on
`CCountry::LoadKey` confirms the key list: `government` (534, which sets `+0xDFC`, the `CGovernment`)
and `ministers` (1081, which calls `0x4F0A00` or `0x4F08F0`) and nothing law-shaped.

---

## Corrections to the record

1. **`FINDINGS-negatives.md` §1 and `project.json`'s `CEU3AI::RebuildPriorityProvinces` comment have
   the membership test inverted.** Both say the function appends `[record+0]` "where
   `[record+4]..[record+8]` — an int array — does **not** contain our own country id". It appends
   when it **does**. Read off `cfg.py 0x897960 0xB0`, not off one jump (trap 13): block `0x89799B`
   has two predecessors, `0x897992(taken)` — the match arm, where `eax` is still below `end` — and
   `0x897999(fall)`, the exhausted loop where `eax == end`; its `je 0x897963` is the *skip*, and the
   fall-through at `0x89799F` is the append.
2. **Same two places: the `0x14`-byte records are not the top level of `CGameState +0xBAC`.** The
   outer vector's elements are `0x10` bytes and indexed by country id; the `0x14`-byte records live
   in the per-country vectors inside it. The other `0x14`-byte nodes in that function are a
   **local list of `CCountryTag` built on the stack** at `[esp+0x28]` and destroyed at `0x897A1A`.
3. **Same two places: the faction walk is not the only source of candidates.** `0x8976E0` walks
   `CCountry +0xF98` (`non_hostile_countries`) as a second pass at `0x897826`–`0x8978AF`, with a
   dedupe against the local list and **no `+0xACC` filter**. The record describes only the faction
   half.
4. **`FINDINGS-power.md` and `project.json`'s `CMapProvince +0x5C`: "Written in exactly one place" is
   wrong — there are five sites and three of them compute it.** `CProvince::CProvince` zeroes it at
   `0x494767` (identified by the `CProvince` vftables it writes at `0x49473B`/`0x494741`); the
   province building reset `0x496480` zeroes it at `0x496680`; `CProvince::LoadKey` computes it at
   `0x496152`; `SetProvinceBuildingLevel` (`0x4A39B0`) computes it at `0x4A3B0A`; and
   `CProvinceBuilding_OnLevelChanged` (`0x4B7FA0`) computes it at `0x4B8024`. **This matters beyond
   bookkeeping:** one writer in `LoadKey` would mean the AI's front value is a load-time snapshot,
   and it is not — it tracks infrastructure as it is built, and the last of the three even
   invalidates the pathfinder when it crosses a level boundary.
5. **`FINDINGS-power.md`'s open item "which building type index 12 is was not established" rests on a
   misreading, not on the mod's file order.** `+0x24` is a `CModifier` id, read off the object at
   `CBuilding +0xC`, and both halves were already in `project.json`.
6. **`project.json`'s `CMapProvince +0x304 = ai_param_building` is superseded by its own
   `CProvince +0x304 = air_base`.** One field, two entries, and the second is right.
7. **`CLASSES.md`'s closing "One is left" paragraph is stale.** It says `+0x628` is "the first of an
   array of `CMinister*` the loader writes while reading `government`" and that "what it is for has
   not been established". It is the laws, it is not written by the `government` arm (that arm sets
   `+0xDFC`), and `project.json` has carried the correction for some time. The paragraph should go.
8. **`FINDINGS-fieldmap.md` lists `CSetAlliedObjectiveCommand`'s `active` as unplaced.** It is the
   byte at `+0x50`, read at `0x553C4D`.
9. `SetProvinceBuildingLevel` (`0x4A39B0`) is a **trap 3 case worth adding to the table**: its first
   `ret 0xC` is at `0x4A3AD2` and the main path is the block after it, reached by the `jne 0x4A3AD5`
   at `0x4A39E1`. `0x68AD20`/`0x68B270`/`0x68B4C0` are a **trap 2 run of three abutting functions**
   with no padding anywhere between `0x68AD20` and `0x68B7C2`.

---

## What is not established

1. **`CSubUnitDefinition +0xE8 combat_width` after technology.** Role 1 is "half the brigades have
   `combat_width` under 1.000", and the stock files make that "half are support brigades" — but
   BlackICE's `technologies/` folder changes `combat_width`, and a technology that pushed a line
   brigade under 1.0 would silently reclassify armies. *Cheapest check:* `definitions.py` over the
   mod's technology files for every `combat_width` effect, then one `dumpStruct.py` on a
   `CSubUnitDefinition` for a late-war infantry brigade in a running game.
2. **Whether anything reads `CArmy +0x2FC` outside `CAIUnit` slot 78.** Slot 78's five tests are the
   only readers the record has, and they only distinguish 8, 3 and 4 — so six of the ten values may
   have no consumer at all, which would make most of the classifier dead weight. *Cheapest check:*
   `fieldchain.py --holder 0x2FC` bounded to the bodies that hold a `CArmy`, with `+0x2E4`/`+0x2E8`
   as the positive control since both have known readers.
3. **`CDiplomacyStatus +0x54`.** `0x4E6C32` stamps it with the current tick for every pair at war and
   for nobody else, but because `0x4E6A70` runs on every diplomatic action and once an hour, the
   value is refreshed rather than stamped at the start — so it is "last seen at war", not a war-start
   date. No reader was looked for. *Cheapest check:* `dispscan.py 0x54` is useless (disp8), so
   `storescan.py 0x54 --neighbours 0x20,0x14,0x4C,0x58` with `+0x20` as the control.
4. **Why `CCountry +0x94 mobilised` is cleared only for unplayed countries.** The path at `0x4E6DCB`
   removes the `initial_mobilization` modifier without clearing the byte; the one at `0x4E6E44`
   clears it but is gated on `CGameState +0xBCC[id] == 0`. Either the player demobilises somewhere
   else or he never does. *Cheapest check:* live — `watch.py` the player's `CCountry +0x94` across a
   white peace.
5. **The fifth dword of the allied-objective record.** The record is `0x14` bytes and only `+0x0`
   (province) and `+0x4`/`+0x8`/`+0xC` (the int vector) are ever touched by any of the four functions
   that handle it. `+0x10` is written by nothing. *Cheapest check:* it is cheap only live, and it is
   not worth a session.
6. **What `CCountry +0x698` is.** `CCountry::LoadKey`'s default arm writes `[+0x698][idx]` at
   `0x4CF329`, immediately before the law branch, in the same "resolve the key as a name" shape. It
   is a third per-something array beside `ministers` and `laws`. *Cheapest check:* read the few
   instructions before `0x4CF329` for which database the index comes out of.
7. **The second half of `CChangeLawCommand::Execute`.** A byte at `+0x4C`, none of the three keys the
   loader places, gates a computation through `0x4F0570` whose negated result lands at
   `country+0x9F8` or elsewhere depending on `country->+0x95`. Almost certainly the dissent a law
   change costs, which is a number modders ask about. *Cheapest check:* read `0x4F0570`; it is small.
8. **Whether `CGameState +0xB9C` has any reader at all.** Everything found reads `+0xBAC`; `+0xB9C`
   is written, saved and iterated by the save writer and the cleanup, and the AI never looks at it.
   If that is really so, the forward index exists only to be saved. *Cheapest check:*
   `storescan.py`-style decode-from-entries for *loads* of `[reg+0xB9C]`, with `+0xBAC` as the
   positive control — the control is what makes the answer mean anything, and `0x897957` is the known
   `+0xBAC` reader it must find.
9. **Nothing here was watched in a running game.** Three live checks, in order of value:
   - `dumpStruct.py` a province and compare `+0x5C / 10` against the infrastructure the province
     panel shows, and `+0x5C` against `provinceValues[MODIFIER_INFRASTRUCTURE]` at `+0x114 + 0x60`.
     Those two should differ wherever a modifier is in play, and if they do not, item 3's separation
     of the two figures is wrong.
   - `dumpStruct.py` a handful of armies' `+0x2FC` against what the OOB shows them to be: an HQ
     should read 0, a panzer division 3, a mountain division 6.
   - `census.py`-style count of `CCountry +0x1010 enemies_count` against the wars in the save, which
     checks item 2's loop in one look.
