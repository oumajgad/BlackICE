# What the AI thinks it needs built

`FINDINGS-power.md` is yesterday's work and it owns `0x8B60F0`. It read the first half — where
`our_power` and `their_power` come from, and what the commitment ladder does with them — and left
the second half, `0x8B62BC`–`0x8B7D13`, as a structure and a call list. This is that half, plus
the sibling arm `0x8B5210` which it had only as an extent, plus the two things that blocked both:
the pair of `CCountry` offset families that turn out not to be what they looked like, and the
per-type availability test `0x5A3BC0`.

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is
marked *seen*. Addresses are **virtual** (image base `0x400000`) with the rva beside them where it
matters, and in the `project.json` entries the file hands back they are rvas throughout (trap 1).
Numbers are thousandths unless said otherwise (trap 7).

Two facts arrived from elsewhere while this was being read and are used rather than re-derived:
**`CArmy +0x2FC` is `army_role`**, ten values written by `CArmy` slot 41 (`0x5CE8A0`), of which 8
is airborne; and **`CMapProvince +0x5C` is infrastructure**, which retires the "which building is
index 12" question `FINDINGS-power.md` left open.

## In one line

The force-needs half of `0x8B60F0` turns one number — a division count — into a want of nineteen
different unit types, and **every term in it comes from one of six places**: the share of the
agent's provinces whose terrain is *named* `plains` or `mountain`, the number of regions the
theatre spans, the country's base IC, the convoy tonnage it is trying to protect, the enemy
brigades it has sighted, and the `usable_by` / technology availability of each type; the day's
**fuel balance** is in there too, and all it does is halve the armour demand; and the whole of it
runs **only for a country a human is playing**, because the arm every AI country takes
(`0x8B5210`) is the same code with the land and naval half cut out — it asks for aircraft and
nothing else.

## Corrections to the record

These come first because two of them are load-bearing and one of them is in this brief.

### 1. `0x5ADE80` is `CSubUnitDataBase::GetInstance`, not `GetConvoyShipDefinitions`

The record has `0x5ADE80` (rva `0x1ADE80`) as `GetConvoyShipDefinitions`, `likely`, with the
comment admitting "the rest of the object was not read". It is the `CSubUnitDataBase` singleton
accessor, and the proof is three instructions long:

- it reads the global `[0x1A886F0]` and returns it when non-null;
- on null it does `operator new(0xC0)` (`0x5ADEA2`), calls **`0x5ADEE0`** — which the record
  already names `CSubUnitDataBase::CSubUnitDataBase` — and installs the result through
  **`0x5B1BE0`**, which the record already names `CSubUnitDataBase::SetInstance` and which writes
  that same global;
- every offset its callers then read is already a named `CSubUnitDataBase` field in
  `project.json`: `+0x1C`/`+0x20` the definition array, `+0x2C` `armor_brigade`, `+0x34`
  `infantry_brigade`, `+0xA8` `destroyer`, and so on through all 33 of the cached type pointers.

So the two offsets `ResolveConvoyRaid` takes — the thing that produced the old name — are
`+0x88` `transport_ship` (the convoy) and `+0xA8` `destroyer` (the escort), which also answers
that entry's "which of the two offsets is which was not established".

This is not a cosmetic fix. With the right name, `0x8B60F0`'s 5.5 KB stops being an opaque wall of
`[eax + 0xNN]` and becomes a list of unit types by name, which is the whole reason this half was
readable at all. **It needs a hand edit to `project.json`** — the pipeline refuses to overwrite an
existing name, so it is deliberately *not* in the entries file this hand-back carries.

### 2. The two `CCountry` offset families are `GetDailyIncome(fuel)` and `GetDailyExpense(fuel)`

The brief describes them as "per-sub-unit-type lists or counters" on the strength of their spacing.
They are not lists at all. `CCountry +0x74C` is the first of 23 embedded `CGoodsPool`, each `0x24`
bytes, and a pool's goods live at `pool + 8 + category * 4`. Lay the two families on that grid:

| the brief's family | pool | pool + 8 + 1*4 |
| --- | --- | --- |
| `+0x77C` | `+0x770` | `fuel` |
| `+0x854` | `+0x848` | `fuel` |
| `+0x878` | `+0x86C` | `fuel` |
| `+0x8C0` | `+0x8B4` | `fuel` |
| `+0x908` | `+0x8FC` | `fuel` |
| `+0x9E0` | `+0x9D4` | `fuel` |
| `+0xA70` | `+0xA64` | `fuel` |

and the other seven the same way: `+0x7C4`→`+0x7B8`, `+0x7E8`→`+0x7DC`, `+0x830`→`+0x824`,
`+0x8E4`→`+0x8D8`, `+0x92C`→`+0x920`, `+0x998`→`+0x98C`, `+0x9BC`→`+0x9B0`. **Every one of the
fourteen is the `fuel` member of a different country goods pool.** The spacing that looked like a
stride is the pool stride.

And the two sums are two functions already in the record, inlined:

```
CCountry::GetDailyIncome  (0x4F1830)  [ecx + edx*4 + 0x778] + 0x79C + 0x904 + 0x874 + 0x8BC + 0x850 + 0xA6C + 0x9DC
CCountry::GetDailyExpense (0x4F1950)  [ecx + edx*4 + 0x7E4] - 0x928 - 0x82C + 0x7C0 + 0x8E0 + 0x994 + 0x9B8
```

with `edx` the goods category. At category 1 those bases become exactly the two families — the
income one minus `+0x79C`, which `GetDailyIncome` skips for categories 0 and 1 (`0x4F184A`,
`0x4F1851`). That the offsets are `base + 4` and not `base + 0` is what pins the category to **1**
rather than 0, and `CGoodsPool::ReadSave`'s own jump table says category 1 is `fuel` (supplies
`+8`, fuel `+0xC`, money `+0x10`, crude_oil `+0x14`, metal `+0x18`, energy `+0x1C`,
rare_materials `+0x20`).

`0x8B64D2`–`0x8B6500` is therefore `GetDailyIncome(FUEL) / 1000` and `0x8B6533`–`0x8B6576` is
`GetDailyExpense(FUEL) / 1000`, and `0x8B6592` subtracts the second from the first. *How checked:*
the offsets are read off the disassembly and matched term for term against the two out-of-line
functions, which were disassembled in full for the comparison.

### 3. `CAIUnit +0x364` and `+0x86` both have writers — the brief's negative is wrong

The brief says of both "neither has a writer in any body read so far", and invites a controlled
negative. There is no negative to produce; both are written, and for `+0x364` **the record already
contains the answer** in a different field's comment, which is trap 14 in its purest form.

`CAIUnit +0x364` is written at `0x8BDFC6` and `0x8BE11D`, inside
`CAIUnit::ClassifyOpsAreaFrontier` (`0x8BDF30`) — a function the record already has, whose own
comment says it "sets `+0x364` and `+0x365` together (written as the word `0x101` at `0x4BE11D`)
when we are at war with the neighbour's controller". The reason neither `FINDINGS-power.md`'s scan
nor an ordinary displacement scan sees it is that **both writes are 16 bits wide**:

```
0x8BDFC6   mov word ptr [edi + 0x364], 0        ; clears +0x364 and +0x365 together
0x8BE11D   mov word ptr [eax + 0x364], 0x101    ; sets both to 1
0x8AF9D0   mov word ptr [esi + 0x364], bx       ; CAIUnit::CAIUnit, zeroes both
```

A scan for byte or dword stores *at displacement `0x364`* cannot see a word store, and a scan for
the displacement bytes alone sees `0x364` but not the width. The fix is to ask the question
properly — for every `(displacement, width)` pair that *covers* the byte — which is what
`scratchpad/forceneeds/coverstore.py` does; see *The tools* below.

So **the reserve mechanism in slot 78 is live**, and live in a specific place: it switches on for an
agent whose operations area borders a country we are actually at war with. The commitment ladder,
the recall loop and the detachment score are not dead code.

`CAIUnit +0x86` is worse: it has **fourteen** writers. Thirteen set it to 1 —
`CEU3AI::CreateUnitOrder` (`0x89AD38`), `CAIUnit::SetPlanStance` (`0x8C3871`), two in `0x890DB0`
and eight in `0x88F593` — and slot 78 clears it at `0x8B328C`, which the record also already has.
Beyond that, **the constructor seeds it 1**, by a store nobody would look for:

```
0x8AF59A   mov dword ptr [esi + 0x84], 0x10101    ; +0x84 = +0x85 = +0x86 = 1, +0x87 = 0
```

so every agent asks for a slot-78 pass on its first opportunity. *The positive control* for the
scan that found these: the same run finds `0x8B328C`, the one writer the record already knew
about, and `0x8AF9D7`'s `mov byte ptr [esi+0x366], 1` on the neighbouring field.

### 4. `ComputePlanWantedSubUnits` is a third writer of `our_power` and `their_power`

`FINDINGS-power.md` says "these two are the complete set of writers of `our_power`/`their_power`
outside the savegame loader", meaning `CAIUnit::UpdatePlanPower` and `0x8B60F0` through
`CSetPlanAttributesCommand`. There is a third. `CUnit::UpdatePlanForceNeeds` (`0x5BD240`), on the
arm where its fifth argument is null, calls `ComputePlanWantedSubUnits` with the plan's own
buffers:

```
0x5BD498   eax = &unit->plan (CUnit + 0x1FC)
           push 0
           push eax + 0x84          ; CUnit +0x280 their_power
           push eax + 0x80          ; CUnit +0x27C our_power
           *(eax+0x84) = 0
           push eax + 0x70          ; CUnit +0x26C plan_subunit_wanted
           *(eax+0x80) = 0
           ... call 0x8E1D00
```

So the two power fields are zeroed and refilled there. That matters for the live checks
`FINDINGS-power.md` proposes: comparing `CAIUnit +0x35C`/`+0x360` against the plan's
`+0x27C`/`+0x280` can disagree without `0x8B5060` being broken, because a third writer may have
been there in between.

### 5. `CAIUnit::GetArea` returns a `CTheatre`, so `+0x8C` is its region count

Not a correction so much as a consequence the record had not drawn. `CAIUnit::GetArea` is already
recorded as answering a `CTheatre`, and `CTheatre +0x84` is already recorded as the head of a
`CList<COwnerArea*>`. This class keeps every list as head/tail/count triples — `+0x30`/`+0x34`/
`+0x38`, `+0x40`/`+0x44`/`+0x48`, `+0x50`/`+0x54`/`+0x58`, `+0x60`/`+0x64`/`+0x68` — so `+0x88` is
the tail and **`+0x8C` the count**, and `+0x8C` is read twice in the force planner as a plain
integer: once scaled into the garrison demand (`0x8B6489`) and once as a floor on the marine
demand (`0x8B6B35`). Both uses are consistent with "how many regions does this theatre span" and
with nothing else. Marked `likely`.

## 1. `0x5A3BC0` — the `usable_by` gate, and why it is the hinge of the whole function

`bool __fastcall (char* countryTag@ECX, CSubUnitDefinition* definition@EDX)`, `0x5A3BC0`
(rva `0x1A3BC0`) to the bare `ret` at `0x5A3C7B`, **50 direct callers**. The definition arrives in
EDX and not ECX, so it is recorded as a free function and not as a `CSubUnitDefinition::` member
(trap 11); the bare `ret` agrees with no stack arguments.

```
n = (definition->+0xD8 - definition->+0xD4) / 0x1C          ; 0x5A3BEB, magic 0x92492493 shift 4
if (n == 0) return true                                     ; 0x5A3C00
s = std::string(countryTag)                                  ; strlen inline, then 0x40A160
r = find(definition->+0xD4, definition->+0xD8, s)            ; 0x5B1BC0 -> 0x794A40
return definition->+0xD4 <= r && r < definition->+0xD8
```

`0x5B1BC0` is six instructions: it takes the vector in **EDI**, the string in EDX and an out-pair
in ESI, calls `0x794A40` with (begin in eax, end, &string) and returns `{found, &vector}`;
`0x794A40` is a string-comparing scan whose loop tests the 16-character SSO threshold at
`[elem+0x14]`, which is `std::string::compare` over `Hoi3CString`. The `/ 0x1C` fixes the element
size at **28 bytes**, and 28 is exactly `Hoi3CString`'s stride elsewhere in the record
(`CSubUnitDefinition +0x8` `key` to `+0x24`, `+0x198` `sprite` to `+0x1B4`).

**The vector is `usable_by`.** `fieldmap.py CSubUnitDefinition` places save token `0x826`,
`usable_by`, at `+0xD4` as a "read into" — the handler hands the field's address to a reader. So:

> `0x5A3BC0` answers **true when the definition declares no `usable_by` block at all**, and
> otherwise true only when the country's tag is one of the tags it lists.

That first clause is the one with teeth, because it means the gate is inert for every type a mod
does not restrict, and a mod that *does* restrict a type removes it from the AI's want vector for
every other country in one line.

The brief describes the function as "answering true when the definition's `+0xD4`/`+0xD8` vector is
empty". That is half of it — the empty case is the early `mov al, 1` — but the non-empty case is a
membership test and not a failure, and the string being tested is `CCountry +0xCA4`, the country's
own three-letter tag (`techStatus->country (+0x248) + 0xCA4` at every call site).

Where the 50 callers are: **24 in `0x8B60F0`**, **7 in `0x8B5210`**, **12 in
`ComputePlanWantedSubUnits`** (`0x8E1D00`), and 7 elsewhere, of which `0x77B86A` is in the
interface — so, like `GetSubUnitDefinitionCombatValue`, this predicate is **on screen somewhere**
and is checkable against the game's own UI.

Every AI call site has the same two-part shape, and it is worth stating once because it recurs
thirty-one times:

```
if (!techStatus->unit_available[definition->type_index]        ; CTechnologyStatus +0x27C, CSubUnitDefinition +0x24
    || !SubUnitDefinitionIsUsableBy(country->tag, definition))
    definition = <the fallback>
```

`CTechnologyStatus +0x27C` is already recorded as `unit_available`, "one byte per unit type,
indexed by `CSubUnitDefinition`'s index, set by `ApplyTechnologyEffects`". So **a type reaches the
AI's want vector only if some technology has activated it and `usable_by` admits the country.**

## 2. `CTerrain`'s five flags are set from the terrain's *name*

`0x8B62E0` classifies each of the agent's provinces by two bytes:

```
terrain = province->template (+0xD4) -> terrain (+0xC)
if (terrain->+0x69) mountainCount++
else if (terrain->+0x68) plainsCount++
```

`CTerrain +0x68` and `+0x69` are not in `map/terrain.txt`. `CTerrain::LoadKey` (`0x4ADA10`) has
exactly twelve cases — `movement_cost`, `defence`/`defender`, `attack`/`attacker`, `temperature`,
`attrition`, `humidity`, `precipitation`, `color`, `is_water`, `inland_sea` — and none of them
lands there. The two bytes come from the **constructor**:

**`CTerrain::CTerrain`, `0x4AD7E0` (rva `0xAD7E0`), `ret 0x1C`**, `this` in ESI, the terrain id in
ECX (stored at `+0x8`), the name as a 28-byte `Hoi3CString` by value. It writes CTerrain's vftable
`0x15C0764` at `0x4AD80A` — the RTTI export gives `CTerrain` that vftable with 8 slots, so the
attribution is free — then `0x18D` at `+0x4` and `+0x10`, a second vftable `0x15B6914` at `+0xC`,
`1.0f` at `+0x14`/`+0x18`/`+0x1C`/`+0x20`, `1` at `+0x24`, and zeroes `+0x48`..`+0x6C`. And then,
at the end, five string comparisons against hardcoded literals:

| offset | set when the name is | at | the literal |
| --- | --- | --- | --- |
| `+0x68` | `plains` | `0x4AD8E9` | `0x15C06B4` |
| `+0x69` | `mountain` | `0x4AD92B` | `0x15C06BC` |
| `+0x6A` | `urban` | `0x4AD96A` | `0x15C06C8` |
| `+0x6B` | `desert` | `0x4AD981` | `0x15C06D0` |
| `+0x6C` | `arctic` | `0x4AD998` | `0x15C06D8` |

The first three use an inlined character loop, the last two go through `0x40C3C0`. The chain is a
`jmp`-to-exit ladder, so a terrain gets at most one of the five.

**This is a real and completely non-obvious modding fact.** The AI's demand for mountain troops
exists because a terrain in `map/terrain.txt` is spelled `mountain`; its demand for armour and
mechanised brigades exists because one is spelled `plains`. Rename either and that demand goes to
zero, silently, with no error anywhere — the engine does not consider a missing name wrong (see
`FINDINGS-script.md`). `is_urban`, `is_desert` and `is_arctic` are read by neither force planner;
where they *are* read was not chased.

Two more things fall out of the same read. `inland_sea` lands at **`CTerrain +0x54`** (handler at
`0x4ADBAF`, `this + 0x54` handed to the bool reader `0xA7B410`) and `is_water` at `+0x48`
(`0x4ADB51`), which is the already-recorded field — `fieldmap.py` reports both as unplaced only
because the destination arrives as a register argument, which is step 3 of `README.md`'s recipe.

## 3. The force-needs half of `0x8B60F0`, block by block

The frame is the one `FINDINGS-power.md` established:
`annfp.py 0x8B60F0 0x1E8A --prologue 0x8B6117 --eh 0x94`. The slots that matter:

| slot | what it holds |
| --- | --- |
| `fp+0x10` | the `CSubUnitDataBase` singleton |
| `fp+0x14` | the `CCountry` |
| `fp+0x20` | `&agent->tag` |
| `fp+0x28` | the `CTheatre` from `CAIUnit::GetArea` |
| `fp+0x30` | the shortage factor, `1.0`..`1.5` |
| `fp+0x34` | total brigades the agent commands |
| `fp+0x38` | **brigadeDemand** |
| `fp+0x4C` | `our_power` |
| `fp+0x18` | `their_power` |
| `fp+0x68` | **the want vector**, `int` per subunit type |

`fp+0x54` is reused three times (the `+0x594` scale, then the fuel income, then the destroyer
definition) and `fp+0x1C`, `fp+0x24`, `fp+0x2C`, `fp+0x40`, `fp+0x44`, `fp+0x48`, `fp+0x58` are
each reused twice or more. Reading this function without `frame.py` normalising the depth is how
you end up attributing one slot's value to another; that is trap 12 applied to a stack frame, and
it is why the tooling exists.

### 3.1 The province census and the denominator

```
mountainCount = 0 ; plainsCount = 0                                 ; fp+0x24, fp+0x1C
for (p in agent->ops_area (+0x90))        classify p's terrain      ; 0x8B62E0
for (p in agent->front_provinces (+0xC0)) classify p's terrain      ; 0x8B6320
total = count(+0xC0) + count(+0x90)                                 ; 0x8B6348
if (total < 1) {
    for (front in theatre->fronts (+0x50)) {                        ; CAreaBorder list
        total += count(front->+0x8 .. +0xC)
        for (p in that vector) classify p's terrain                 ; 0x8B63A1
    }
    if (total < 1) { free the want vector; return }                 ; 0x8B63D1
}
```

Note `+0xC4` — the end of the front-province vector whose begin the record has at `+0xC0` — which
is new, and note that the ops area and the front list can overlap, so a province can be counted
twice. The fallback through the theatre's fronts is the only place in either arm that reads
`CTheatre +0x50`.

### 3.2 brigadeDemand, and the five land wants

```
need       = CAIUnit::EstimateTheatreNeed(agent, &their_power)        ; 0x8B622B
shortage   = 1.0 ; if (country->+0x590/1000 < 0.2) shortage = 1.0 + (0.2 - that) * 2.5
brigadeDemand = agent->invasion_brigade_need (+0x370) + round(need * shortage * 3.0)   ; 0x8B626D

mountainShare = round(brigadeDemand * (mountainCount / total) * 0.5)  ; fp+0x3C, 0x8B6445
armourShare   = round(brigadeDemand * (plainsCount   / total) * (country->+0x594 / 1000))
                                                                     ; fp+0x2C -> fp+0x40 and fp+0x44
garrisonWant  = min(round(theatre->areas_count * shortage * 3), brigadeDemand)   ; fp+0x48, 0x8B64C5

if (fuelIncome - fuelExpense < 0 && country->is_at_war (+0xACC))
    armourShare = armourShare / 2                                    ; 0x8B65B4, both copies

rest = brigadeDemand - mountainShare - garrisonWant - armourShare - armourShare
if (rest < 0) rest = 0                                               ; 0x8B65D9

want[bergsjaeger or infantry] += mountainShare                       ; 0x8B684D
want[armour chain]            += armourShare                         ; 0x8B6857
want[mech chain]              += armourShare                         ; 0x8B6861
want[garrison or infantry]    += garrisonWant                        ; 0x8B686F
want[infantry]                += rest                                ; 0x8B6879
```

Four things in there are worth saying out loud.

**The armour and the mechanised want are the same number**, written twice from one slot; there is
no separate calculation for the two.

**The fuel balance's only effect in this whole function is that halving.** Nothing else reads
either fuel figure. And because the halving happens *before* `rest` is worked out, a fuel shortage
does not reduce the total demand — it moves brigades from armour and mechanised into **infantry**.
That is a sensible behaviour and it is the one place the economy reaches the AI's order of battle
here.

**`CCountry +0x594` scales the armour and mechanised want directly.** If it is zero — see §6 — the
armour and mechanised wants are both zero and the whole of `brigadeDemand` that is not mountain or
garrison lands on infantry.

**The substitution ladder is `0x8B65DD`–`0x8B683E`**, eight availability tests with fallbacks:

| first choice | then | then |
| --- | --- | --- |
| `battleship` | `heavy_cruiser` | `light_cruiser` |
| `heavy_cruiser` | `light_cruiser` | — |
| `mechanized_brigade` | `motorized_brigade` | `infantry_brigade` |
| `armor_brigade` | `light_armor_brigade` | whatever the mechanised chain settled on |
| `bergsjaeger_brigade` | `infantry_brigade` | — |
| `garrison_brigade` | `infantry_brigade` | — |

Every one of those thirteen names is a **key in `common/units/*.txt`** that `CSubUnitDataBase`
caches as it parses (`+0x2C` `armor_brigade`, `+0x34` `infantry_brigade`, `+0x38`
`motorized_brigade`, `+0x3C` `mechanized_brigade`, `+0x40` `bergsjaeger_brigade`, `+0x44`
`marine_brigade`, `+0x48` `paratrooper_brigade`, `+0x50` `garrison_brigade`, `+0x84`
`light_armor_brigade`, `+0x98` `battleship`, `+0xA0` `heavy_cruiser`, `+0xA4` `light_cruiser`,
`+0xA8` `destroyer`, and the rest). The record already says those cached pointers are "never
written, and so left as the uninitialised allocation, if no unit file declares that key" — which
makes a missing key here a wild pointer, not a zero, and the AI dereferences it unconditionally at
`+0x24` to get a `type_index`. **A mod that removes one of these thirteen unit names does not
weaken the AI; it hands it a garbage pointer once an hour on a worker thread.**

### 3.3 Paratroopers and marines

Gated twice: `country->base_ic (+0x604) >= 50` (`0x8B689A`), and the capital province's theatre id
pair (`CMapProvince +0x380`/`+0x384`, already recorded) must equal this theatre's own
(`CTheatre +0x8`/`+0xC`) — so only the agent for the theatre containing the capital does this
(`0x8B68C3`).

```
canPara   = available(paratrooper) && available(transport_plane)     ; fp+0xF
canMarine = available(marine)                                        ; fp+0xE

w = 0
for (node in unit->plan_objectives (+0x234)) {                       ; node: id at +8, force at +0x10, next at +0x1C
    p = provinces[node->+8]
    if (p->controller_id == country->id) continue
    d = country->diplomacy_status_array[p->controller_id]
    if (!d->+0x20 && p->controller != "REB" && country->tag != "REB"
        && (!d->+0x24 || !0x4763A0(p))) continue
    a = p->area (+0x2B4) ; cap = GetActingCapitalLocation()->area
    if (cap is in a->neighbour_areas (+0x34)) continue
    w++
    if (a->provinces_count (+0x2C) >  5) w++
    if (a->provinces_count       > 10) w++
}
w = max(w, country->base_ic / 40)                                    ; 0x8B6B07, magic 0x66666667 shift 4
if (canPara)   want[paratrooper] += w - w/2                          ; ceil(w/2)
if (canMarine) want[marine]       = (w/2 >= areas_count - 1) ? w/2 : areas_count   ; a plain store, not +=
```

So **the AI wants amphibious and airborne force in proportion to how many of its objectives sit in
enemy-held regions it cannot walk to**, with a floor of one brigade of each per 40 base IC, and the
marine want additionally floored at the theatre's region count. The marine line is the only place
in either arm that *assigns* a want rather than adding to one.

### 3.4 Transport planes

```
if (available(transport_plane)) {
    tonnage = 0
    for (army in agent->+0x11C)
        if any brigade of army is of paratrooper's type
            tonnage += sum over army's brigades of definition->transport_weight (+0x10C) / 1000
    w1 = paratrooper->transport_weight / 1000 * want[paratrooper]
    if (w1 > tonnage) tonnage = w1
    if (tonnage > 0) {
        n = ceil(tonnage / (transport_plane->transport_capacity (+0x144) / 1000))   ; 0x8B6D3E
        want[transport_plane] += n
    }
}
```

The ceiling is explicit: truncate, compare, and increment if the truncation lost anything
(`0x8B6D50`). Both `transport_weight` and `transport_capacity` are `units/*.txt` keys, so **the
number of transport aircraft the AI asks for is set entirely by the mod's own weights** — make a
paratrooper brigade heavier and the AI asks for more transports, one for one.

### 3.5 Strategic bombers

```
s = 0
for (p in agent->strategic_target_provinces (+0x18C))
    s += p->modifiers[MODIFIER_LOCAL_IC] / 1000 + p->current_producing.crude_oil (+0x27C) / 1000
s = s / 300                                                          ; 0x8B7002, the double at 0x160A7E8
if (count(agent->ops_area (+0x90)) > 0) s = s * 0.5                  ; 0x8B7014
if (s > 0) want[strategic_bomber] += round(s)
```

`CMapProvince +0x114` is the already-recorded modifier array indexed `id * 8`, so `+0x80` is
modifier 16, and `modifierIds.py` says 16 is `MODIFIER_LOCAL_IC`. `CProvince +0x27C` is
`current_producing` + `0x14`, and `current_producing` is already recorded at `+0x268` as a
`CGoodsPool` from the save key of the same name, with `max_producing` one `0x24` stride later at
`+0x28C` — so `+0x27C` is that pool's **crude_oil**. Two independent surveys agreeing on `+0x268`
is convergence, not a collision (trap 14), and the entries file therefore does not re-add it.

So the strategic-bomber want is **one aircraft per 300 units of (industry + oil) in the target
provinces, halved whenever the agent has an operations area of its own**. The loop is unrolled by
four (`0x8B6E00`) with a scalar tail at `0x8B6F90`, which is why it looks like four copies of the
same arithmetic.

### 3.6 Tactical bombers, CAS and interceptors

```
tb = available(tactical_bomber) ? tactical_bomber : cas              ; 0x8B7098
if (available(tb)) want[tb] += (brigadeDemand + totalBrigades) / 40  ; 0x8B70EF
...
if (available(interceptor)) want[interceptor] += (brigadeDemand + totalBrigades) / 40   ; 0x8B7D10
```

The same number twice, at the two ends of the function, from the same two slots. `/40` is
`0x66666667` with shift 4 both times. **One tactical bomber and one interceptor per forty brigades
the theatre has or wants**, and no other input at all.

The `tactical_bomber` → `cas` fallback is the only place CAS appears in either arm, so a mod whose
`tactical_bomber` is not unlocked gets CAS asked for in its place and never otherwise.

### 3.7 Submarines and transport ships

```
sub = available(nuclear_submarine) ? nuclear_submarine : submarine   ; 0x8B7134
if (available(sub)) want[sub] += agent->submarine_want (+0xD8)       ; 0x8B7182
```

That is the whole submarine calculation: a field copied in, unscaled. `+0xD8` is zeroed by the
constructor and accumulated by the unidentified `CEU3AI` helper `0x88C140` (`+= [esp+0x48]` at
`0x88C750` and again at `0x88D52A`).

```
enemyTotal = 0 ; visited = {}
for (node in unit->plan_objectives (+0x234)) {
    p = provinces[node->+8]
    ... the same enemy test as §3.3, plus a war-in-common test through
        diplomacy->+0x24's vector at +0x28/+0x2C against province->+0x358 ...
    a = p->area ; if (!a->IsValid() || a in visited) continue
    append a to visited
    if (node->+0x10 >= 1) enemyTotal += node->+0x10
    else if (no province of agent->+0xC0 is in a)
        enemyTotal += CountEnemyUnitsInArea(&country->strategy, a, 0)
}
tonnage = max(4 * enemyTotal * infantry->transport_weight / 1000, agent->+0xD4)   ; 0x8B7479
n = ceil(tonnage / (transport_ship->transport_capacity / 1000))
portAreas = count of theatre->areas whose ports_count (+0x50) > 0                  ; 0x8B74D0
want[transport_ship] += agent->invasion_transport_need (+0x36C) + max(n, portAreas - 1)
```

So the sealift the AI asks for is **four infantry divisions' worth of tonnage per enemy division
standing in an objective region it has to cross water to reach**, floored at `+0xD4` and at one
transport per port-bearing region less one, plus whatever an amphibious plan has already booked.
`COwnerArea +0x48`/`+0x50` is already recorded as the port list and its count.

`node->+0x10` is new: a per-objective force figure that, when set, replaces the enemy count
outright. Not chased further.

### 3.8 The enemy-sighting ledger and the surface fleet

Two symmetric loops over two `CAIUnit` lists of unit object id pairs, resolved through the id
registry (`0x1A857F0` / `0x1A857F4`, the same pair `CAIUnit::GetArea` uses). The first,
`+0x25C`, at `0x8B7550`:

```
for each sighted unit that belongs to an enemy:
    for (su in unit->subunits (+0x38)) {
        d = su->definition (+0x58)
        if (d->type_index == heavy_cruiser->type_index) {
            want[our cruiser (fp+0x30)]++ ;      score += 0.07
        } else if (d->is_capital (+0x2F)) {
            want[our capital ship (fp+0x24)]++ ; score += 0.15
        } else {
            if (d->type_index != transport_ship->type_index && available(destroyer))
                want[destroyer]++
            if (d->type_index != our sub type) score += 0.02
        }
    }
    push unit->current_province_ptr (+0x130) onto agent->+0x19C
```

and the second, `+0x26C`, at `0x8B78B3`, is the exact mirror: `dec` where the first has `inc`, and
`score -= 0.07 / 0.15 / 0.02` where the first adds. The three constants are the `.rdata` doubles
`0x160A7E0`, `0x160A7D8` and `0x160A7D0`. **So the two lists are sightings gained and sightings
lost, and the want vector is maintained as a running reply to what the AI can see.**

Note that the *enemy's* ship is matched against the stock `heavy_cruiser` type index, while *our*
reply is whatever the fallback chain settled on — so a mod can change what the AI builds in answer
to a cruiser without changing what it recognises as one.

Then three adjustments:

```
want[destroyer] = want[destroyer] / 2                                           ; 0x8B7A30
v = want[transport_ship] / 3 + want[capital ship]                               ; 0x8B7A46, magic 0x55555556
if (want[destroyer] < v) want[destroyer] = v                                    ; 0x8B7A67
want[naval_bomber] = round(score)                                               ; 0x8B7AAD, a plain store
```

### 3.9 The escort ratios

Reached only when the agent's theatre is the capital's theatre (`0x8B7ACC`, the same id-pair test
as §3.3):

```
T = sum of CConvoy::GetDesiredTransports(convoy) over country->convoys (+0xA0)
want[destroyer]      = max(want[destroyer],      T / 20)      ; 0x8B7B16, 0x66666667 shift 3
want[light_cruiser]  = max(want[light_cruiser],  T / 35)      ; 0x8B7B22, 0xEA0EA0EB shift 5
want[our cruiser]    = max(want[our cruiser],    T / 50)      ; 0x8B7B35, 0x51EB851F shift 4
want[capital ship]   = max(want[capital ship],   T / 100)     ; 0x8B7B46, 0x51EB851F shift 5
want[carrier]        = max(want[carrier],        T / 200)     ; 0x8B7B5B, 0x51EB851F shift 6
```

These are **floors, not additions** — five `cmp`/`mov` pairs, `0x8B7B81`–`0x8B7C23`. `CConvoy::
GetDesiredTransports` is already recorded as the only reader of two `economy` defines
(`CONVOY_PATH_LENGTH_MULT` among them), so this is one of the very few places a `defines.lua`
entry reaches the AI's shopping list — indirectly, through how many transports each route wants.

The five divisors are compiled-in libdivide sequences; the `/35` one (`0xEA0EA0EB` with the
add-dividend correction and shift 5) is the only non-round divisor in either arm and is worth
recording for exactly that reason.

### 3.10 Multi-role

```
if (available(multi_role))
    want[multi_role] += round(0.5 * want-worth-of-tactical-bombers (fp+0x58)
                            + 0.5 * the naval sighting score (fp+0x1C)
                            + 0.5 * the transport-plane count (fp+0x40))        ; 0x8B7CBD
```

Half of three other wants. Nothing else goes into it.

### 3.11 The post gate

```
if ((db count * 4) != (unit->+0x270 - unit->+0x26C)
    || any want[i] != unit->plan_subunit_wanted[i])
    post CSetPlanForcesCommand(unit, &want)                      ; 0x8B7D9B
post CSetPlanAttributesCommand(unit, 5, 3, 3, our_power, their_power)   ; 0x8B7E87
free the visited list; free the want vector; return
```

The attributes command is posted **unconditionally**, the forces command only on a change. The
argument order of the attributes command is settled here independently of
`FINDINGS-power.md`: `ret 0x1C` is seven dwords, and the pushes at `0x8B7E63`–`0x8B7E86` lay the
stack out as `(this, unit, 5, 3, 3, fp+0x4C, fp+0x18)` = `(…, our_power, their_power)`, which is
what that file says.

`CUnit +0x270` — the end of the `plan_subunit_wanted` vector whose begin the record has at
`+0x26C` — is new, and it is read at `0x8B7D1C`/`0x8B7D25`.

## 4. `0x8B5210` — `CAIUnit::UpdatePlanForces`, the arm every AI country takes

The brief asks for this function entirely, and the answer is short and surprising.

Extent `0x8B5210`–`0x8B60EC` (`ret 4`), 3804 bytes. Frame:
`annfp.py 0x8B5210 0xEE0 --prologue 0x8B5234 --eh 0x64`; `sub esp, 0x50` puts the trylevel at
`fp + 0x50 + 20 = fp+0x64`, and `frame.py --check` agrees at all seven writes to it, the only
disagreement being the epilogue reading the SEH link at `fp+0x5C`, which is correct.

```
country = GetCountry(&agent->tag)
db = CSubUnitDataBase::GetInstance()                                  ; inlined lazy init
brigadeDemand = agent->+0x354 * 3 + agent->invasion_brigade_need (+0x370)      ; 0x8B528B
totalBrigades = sum of army->regiments_count (+0x40) over agent->+0x11C
want = vector<int>(GetNumberOfSubUnits()), all zero
```

and then **six** want entries, and no others:

| want | from |
| --- | --- |
| `transport_plane` | tonnage of the agent's **airborne** armies (`+0x16C`) over a transport's capacity, `0x8B5642` |
| `tactical_bomber` or `cas` | `(totalBrigades + brigadeDemand) / 40`, `0x8B56E3` |
| `strategic_bomber` | the same industry-and-oil sum over `+0x18C`, `/300`, halved, `0x8B59B3` |
| `naval_bomber` | `round(the sighting score)`, a plain store, `0x8B5EC7` |
| `multi_role` | `round(0.5·tacBomber + 0.5·score + 0.5·transportPlanes)`, `0x8B5F62` |
| `interceptor` | `(totalBrigades + brigadeDemand) / 40`, `0x8B5FB4` |

**All six are aircraft.** There is no land want and no ship want anywhere in the function.

*How that negative was checked, and its control.* Three independent ways, and the third is the one
that settles it:

1. The want vector is indexed only by `[reg + reg*4]`, because the index is a `type_index` read at
   run time. There are exactly **six** stores of that shape in the whole function — the six above
   — against **twenty-six** in `0x8B60F0`. The same regex over the two listings is the control: it
   finds all of `0x8B60F0`'s, including the five land ones at `0x8B684D`–`0x8B6879` and the
   `inc`/`dec` pairs in the sighting loops.
2. `0x5A3BC0` is called **7** times here against **24** there; a land or naval want would need an
   availability test, and there are only seven and they are accounted for (transport_plane,
   tactical_bomber, cas, strategic_bomber, naval_bomber, multi_role, interceptor).
3. The database pointer lives in `fp+0x10` and is loaded into a register at exactly ten places
   (`0x8B5304`, `0x8B53FE`, `0x8B55C3`, `0x8B5659`, `0x8B5694`, `0x8B56EA`, `0x8B59B6`,
   `0x8B5E7D`, `0x8B5ED4`, and the lazy-init). Following each one, the fields read off it are:
   `+0x1C`/`+0x20` twice (vector sizing), `transport_plane`, `tactical_bomber`, `cas`,
   `strategic_bomber`, then `heavy_cruiser` + `submarine` + `transport_ship` **as comparison
   operands only**, then `naval_bomber`, `multi_role`, `interceptor`. `armor_brigade`,
   `infantry_brigade`, `garrison_brigade`, `marine_brigade`, `paratrooper_brigade`,
   `bergsjaeger_brigade`, `destroyer`, `battleship`, `light_cruiser` and `carrier` are **never
   loaded**. The control here is the same walk over `0x8B60F0`, which does load every one of them.

The sighting loops are present (`0x8B5A00` and `0x8B5D60`, with the same two `0x4C0700` vector
grows as the other arm's `0x8B7835`/`0x8B788C`) and they do maintain the score and the province
list at `+0x19C` — but where `0x8B60F0` increments cruiser, capital-ship and destroyer wants inside
them, this arm only accumulates the float. That is why `heavy_cruiser`, `submarine` and
`transport_ship` are loaded: to classify the *enemy's* brigades, not to ask for our own.

It also posts **only** `CSetPlanForcesCommand` (`0x8B6028`), never
`CSetPlanAttributesCommand` — which the record already says, and which means
`our_power`/`their_power` for an AI country stay whatever `CAIUnit::UpdatePlanPower` last set.

Three further differences from the played arm, all of them simplifications:

- **no shortage factor**: `brigadeDemand` is `need * 3` flat, using the *cached* need at
  `CAIUnit +0x354` rather than re-running `EstimateTheatreNeed`. So `CCountry +0x590` never enters
  an AI country's planning at all;
- **no fuel arithmetic**: neither `GetDailyIncome` nor `GetDailyExpense` is inlined here;
- the transport-plane tonnage is summed over `agent->+0x16C` — slot 78's "armies whose
  `army_role` is 8", i.e. the **airborne** ones — rather than over every army containing a
  paratrooper brigade, and it `round`s where the other arm `ceil`s.

## 5. Which arm an AI country takes

`FINDINGS-power.md` says the pair splits on who is playing. Checked again independently, from slot
73's entry, because everything above depends on it:

```
0x8B0B5F   ecx = [esi + 0x34]                  ; agent->tag letters
0x8B0B62   edx = [eax + 0xBCC]                 ; gamestate->played_countries_array
0x8B0B6C   ecx = [esi + 0x38]                  ; agent->countryId
0x8B0B6F   cmp dword ptr [edx + ecx*4], 0
0x8B0B73   push esi
0x8B0B74   jne 0x8B0B7D                        ; non-zero -> 0x8B60F0
0x8B0B76   call 0x8B5210                       ; zero     -> 0x8B5210
```

`CCurrentGameState +0xBCC` is already recorded as `played_countries_array`, "non zero for a played
country". So **`0x8B5210` is the arm for the ~107 AI countries and `0x8B60F0` the arm for the one
or few a human plays.** The 5.5 KB of land-and-naval want this file spends most of its length on is
therefore the *player's delegated* planner, and the AI's own planner is the six-aircraft one.

That inverts the natural reading of `FINDINGS-power.md`'s table, and it is the single most
consequential thing in this file for a mod: **nothing in `units/*.txt`, no terrain name, no
`usable_by` block and no fuel balance changes what an AI country's unit agents ask for, because
they only ever ask for aircraft.** Those levers act on the player's delegated theatres and on
`ComputePlanWantedSubUnits`, which is a different function.

## 6. `CCountry +0x590` and `+0x594`

The brief's live negative, attacked from the other side as instructed. It survives, and it got
sharper.

**What was done.** Four searches, three of them methods `FINDINGS-power.md` did not use:

1. **`CCountry::LoadKey`'s own save-key placement.** `fieldmap.py CCountry` places 120 keys; none
   of them lands at `+0x590` or `+0x594`. *Control:* the same run places `acting_capital` at
   `+0xE24`, `usage` at `+0x98C`, `major` at `+0x15C` and 117 others, so the method sees this
   class's keys.
2. **The constructor.** `CCountry::CCountry` is `0x4C8A40`, `ret 0x10`, reached from two
   `operator new(0x1208)` sites (`0x515D91` and `0x5178C7`) and nowhere else — so
   `sizeof(CCountry) == 0x1208`, and **the allocation is not zeroed**. The constructor initialises
   field by field, with no `memset` of the object; its one `rep stosd` (`0x4C9D07`) fills a
   six-element vector at `+0x5E4`, not the object. **There is not one store anywhere in the
   `+0x560`..`+0x5F0` range.** *Control:* the same disassembly shows the constructor's stores at
   `+0x8`..`+0x90`, `+0x5E0`..`+0x5F8` and beyond, so the search can see this function's writes.
3. **A covering-store scan of all of `.text`** — every `(displacement, width)` pair that touches
   the byte, for widths 1, 2, 4, 8 and 16, integer *and* x87 *and* SSE forms (`fistp`, `fstp`,
   `movss`, `movsd`, `movd`, `movaps`, `movq`), for all six non-SIB base registers, each hit
   verified by decoding forward from its function's entry. `+0x590`: **one** store, `0x649C6C`.
   `+0x594`: **none at all.** *Controls:* the same scan finds four writers of `CCountry +0x580`
   (`theatres_dirty`) and seven of `CCountry +0x604` (`base_ic`, all in `CCountry::UpdateIC`), and
   on `CAIUnit +0x364` it finds the three word-wide stores that the older byte-and-dword scan had
   missed — which is the scan proving it can see exactly the kind of writer that defeated the
   previous attempt.
4. **An exhaustive displacement scan**, which searches for the four displacement bytes themselves
   and lets the decoder say what the instruction is — so it covers SIB addressing and every opcode
   map. Filtered to non-stack bases: `+0x590` has the one store at `0x649C6C`; `+0x594` has none.
   *Control:* run on `+0x604` it finds `CCountry::UpdateIC`'s six.

**And `0x649C6C` is not a `CCountry`.** `FINDINGS-power.md` called it "a `CInGameIdler`" and was
right to. In context it writes a *vftable pointer* into a strided array of sub-objects:

```
0x649C5A   [ebx+0x5E0] = 0 ; [ebx+0x5E4] = 0 ; [ebx+0x5E8] = 0
0x649C6C   [ebx+0x590] = 0x15B5554
0x649C72   [ebx+0x540] = 0x15B5554
0x649C78   [ebx+0x4F0] = 0x15B5554
0x649C7E   [ebx+0x4A0] = 0x15B5554
0x649C84   [ebx+0x450] = 0x15B5554
0x649C8A   [ebx+0x418] = 0x15B5580
```

A `0x50` stride of identical vftable writes. `CCountry` has `strategy` (a `CAIStrategy` by value)
occupying `+0x48C` onward and nothing of that shape, so the object here is a different class
entirely. **Neither field has a writer.**

**The consequence, and it is worse than "always zero".** Because the constructor does not
initialise them either, `CCountry +0x590` and `+0x594` are **uninitialised heap**, not zero.
`operator new(0x1208)` on this allocator does not zero. In practice the 108 countries are built
early, out of freshly committed pages that Windows zeroes, so both will almost certainly read 0 —
but that is a property of the allocator's state, not of the code. On the zero reading:

- the shortage factor is a constant **1.5**, so the played arm's `brigadeDemand` is
  `invasion_brigade_need + round(need * 4.5)` and the garrison want is
  `min(round(areas_count * 4.5), brigadeDemand)`;
- `+0x594 / 1000` is **0**, so `armourShare` is 0, so **the player's delegated theatres never ask
  for a single armour, light armour, mechanised or motorised brigade**, and the whole of
  `brigadeDemand` not spent on mountain troops and garrisons lands on infantry;
- and the fuel-shortage halving at `0x8B65B4` halves zero, so that branch is inert too.

Which makes the terrain census in §3.1 half dead: the `plains` count is computed, divided, scaled
by zero and thrown away. The `mountain` count is live.

This is still **inferred**, for one reason only: a writer that held a pointer to a *sub-object* of
`CCountry` — say `country + 0x570`, writing `[reg + 0x20]` and `[reg + 0x24]` — would use a
different displacement, and no displacement scan can see that. Nothing suggests such a sub-object
exists at `+0x570` (`+0x570`..`+0x578` is the recorded `oob_theatres` triple and `+0x580` is
`theatres_dirty`), but it cannot be excluded statically. **`dumpStruct.py` on any `CCountry` with
`--length 0x600` settles it in one look**, and it remains the single cheapest check in this
chain — now with a sharper question attached: not "are they zero" but "are they zero on *every*
country, and are they *the same* on every country", because uninitialised memory would differ
between them and a genuine zero would not.

## 7. The new `CAIUnit` fields, and where each one comes from

| offset | name | writer | reader |
| --- | --- | --- | --- |
| `+0xC4` | `front_provinces_last` | the vector helpers | `0x8B630E`, `0x8B634E` |
| `+0xD4` | `amphibious_transport_tonnage` | ctor `0x8AF604`; `0x8C67CC` in the unidentified `0x8C4370` | `0x8B7479` |
| `+0xD8` | `submarine_want` | ctor `0x8AF60A`; `0x88C750` and `0x88D52A` in the unidentified `0x88C140` | `0x8B7182` |
| `+0x18C`/`+0x190` | `strategic_target_provinces` | cleared by ctor `0x8AF6E2` and dtor `0x8B00C1`; filled through a `lea` | `0x8B6E00`, `0x8B5770` |
| `+0x19C`/`+0x1A0` | `enemy_sighting_provinces` | `0x8B77CE`..`0x8B78A0` | nothing found |
| `+0x25C` | `enemy_units_sighted_first` | ctor `0x8AF802`; `0x88CB21` | `0x8B7550`, `0x8B5A00` |
| `+0x26C` | `enemy_units_lost_first` | ctor `0x8AF81A`; `0x88D4E6` | `0x8B78B3`, `0x8B5D60` |
| `+0x36C` | `invasion_transport_need` | ctor; cleared `0x892489`, added `0x8935DE` | `0x8B74F0` |
| `+0x370` | `invasion_brigade_need` | ctor; cleared `0x892483`, added `0x893756` | `0x8B626D`, `0x8B528B` |

The last two are the best-attested of the set, because they have exactly one producer and one
consumer each. `CEU3AI::PlanAmphibiousInvasion` zeroes both when it is handed an agent and then
accumulates into them:

```
0x8935DE   agent->+0x36C += (tonnage short) / (transport_ship->transport_capacity / 1000) + 1
0x893756   agent->+0x370 += (brigades wanted - brigades available)
```

So **an amphibious invasion the AI is planning raises the land demand and the sealift demand of
the whole theatre**, and does so through two fields that are reset at the start of each planning
pass rather than accumulating forever.

`+0x18C` is the one to be careful about: a displacement scan finds only the constructor's and the
destructor's clears, which looks like "nothing fills it" and is not — a `std::vector` is filled
through `lea reg, [agent+0x18C]` handed to a grow helper, and the displacement then belongs to the
`lea`, not to any store. That is the same shape as trap 8's case 2 and is worth stating as a
general caution: **for a vector field, the absence of stores at its displacement is the normal
case and means nothing.**

## 8. Does any of it survive? The `UpdatePlanForceNeeds` gate

Both arms' only output is `CSetPlanForcesCommand`, and `CSetPlanForcesCommand::Execute`
(`0x5E88A0`) does two things in order: it hands the vector to `CUnitPlan::SetMinForces`
(`0x8DF0F0`), which **replaces** `CUnit +0x26C`, and then it calls `CUnit::RefreshPlanForceNeeds`
(`0x5BD6F0`), which for a unit at `oob_level 0` re-enters `CUnit::UpdatePlanForceNeeds`
(`0x5BD240`) — and that function's `wanted == 0` arm **recomputes `plan+0x70` from
`ComputePlanWantedSubUnits`**, overwriting what `SetMinForces` just installed.

What stops that is one test:

```
0x5BD442   walk up unit->higher_oob (+0x1E0) to the top
0x5BD454   if (top->plan_active (CUnit +0x204) != 0 && top->oob_level (+0x1F4) == 0)
               skip to 0x5BD4CB            ; ComputePlanWantedSubUnits is not called
0x5BD498   else fill plan+0x70, plan+0x80 and plan+0x84 from ComputePlanWantedSubUnits
```

So: **with an active plan at the top of the order of battle, the AI force planner's vector sticks;
without one, it is overwritten within the same command's execution.** Since the agent's own unit is
the theatre (`oob_level 0`) and slot 77 sets `plan_active` through
`CSetPlanAttributesCommand`, the normal case for a managed theatre is that it sticks — but that
chain was not traced end to end and the claim is therefore **likely**, not confirmed. It is also
the right first thing to check if an AI country's plans turn out to want land brigades after all:
the six-aircraft vector from §4 and the land composition from `ComputePlanWantedSubUnits` are two
different producers of the same field, and which one is in it depends on this byte.

## 9. What a mod can and cannot reach

`FINDINGS-power.md`'s table covered the power estimate. This one covers the want vector, and the
first column says which arm it applies to.

| the AI's number | arm | where it comes from | can a mod move it? |
| --- | --- | --- | --- |
| which types are even considered | both | `technology_status->unit_available` and `usable_by` | **yes** — the tech tree, and `usable_by` in `units/*.txt` |
| the thirteen cached type names | both | `CSubUnitDataBase +0x2C`..`+0xAC`, keyed by the unit file's own top-level name | **yes, and dangerously** — remove one and the pointer is uninitialised |
| mountain-troop demand | played only | the share of provinces whose terrain is *named* `mountain`, times `0.5` | **the share yes** (terrain names and province terrain); the `0.5` no |
| armour and mechanised demand | played only | the share of provinces whose terrain is *named* `plains`, times `CCountry +0x594` | **no, and probably moot** — `+0x594` has no writer |
| garrison demand | played only | `theatre->areas_count * shortage * 3`, capped at the brigade demand | the region count yes, the `3` no |
| infantry demand | played only | the remainder of the brigade demand | indirectly |
| the brigade demand itself | both | `EstimateTheatreNeed * 3` (`* shortage` on the played arm) plus `invasion_brigade_need` | only through `NAP_UNBREAKABLE_MONTHS`, per `FINDINGS-power.md` |
| paratrooper and marine demand | played only | enemy-held objective regions not adjacent to the capital's, floored at `base_ic / 40` | the objectives and the IC yes; the `/40`, the `/2` and the `>5`/`>10` no |
| transport aircraft | both | paradrop tonnage over `transport_capacity` | **yes** — `transport_weight` and `transport_capacity` in `units/*.txt` |
| strategic bombers | both | (`MODIFIER_LOCAL_IC` + `current_producing.crude_oil`) over 300 | the target provinces' industry and oil yes, the 300 no |
| tactical bombers and interceptors | both | `(brigades + brigadeDemand) / 40` | no |
| multi-role | both | half of three other wants | no |
| submarines | played only | `CAIUnit +0xD8`, copied in unscaled | not from a data file |
| transport ships | played only | 4 × enemy divisions in objective regions × infantry `transport_weight`, over `transport_capacity` | **yes** — the two weights |
| destroyers, cruisers, capital ships, carriers | played only | enemy sightings, then floored at convoy tonnage / 20, 35, 50, 100, 200 | the convoy count yes (and `CONVOY_PATH_LENGTH_MULT` through it); the five divisors no |
| naval bombers | both | the sighting score, `0.07` per enemy cruiser, `0.15` per capital ship, `0.02` otherwise | no |

**The honest summary for a modder.** For the player's delegated theatres there are four real
levers: `usable_by`, the technology that activates a type, the terrain *names* in
`map/terrain.txt`, and `transport_weight`/`transport_capacity`. For an AI country there are two,
because the arm it takes asks only for aircraft: the technology/`usable_by` gate, and the transport
weights. Everything else in both arms is a compiled-in literal.

## 10. The tools this needed

`scratchpad/forceneeds/` holds three scripts, and two of them exist because the existing ones gave
a wrong negative.

**`coverstore.py <offset>`** — every store in `.text` that writes the byte at `[reg + offset]`, at
any width. It enumerates store encodings for widths 1, 2, 4, 8 and 16 at every displacement from
`offset-15` to `offset`, integer, x87 and SSE, for the six non-SIB base registers, and verifies
each hit by decoding forward from the owning function's entry so nothing is printed that the
decoder does not agree is an instruction there. **This is the script that found `CAIUnit +0x364`'s
writer.** The lesson it encodes is small and general: *a field can be written by a store whose
displacement is lower than the field's own*, and `mov word ptr [esi+0x364], bx` is how that looks
in practice.

**`dispscan.py <offset>`** — the exhaustive version. It searches for the four displacement bytes
themselves and asks the decoder what instruction covers them, so it catches SIB addressing and
every opcode map, at the price of false positives that the `--writes` filter and a grep against
`esp`/`ebp` remove. Run it as the second opinion when `coverstore.py` reports nothing.

**`bytefield.py <offset> [--dword] [--writes]`** — the cheap first pass, one displacement only.

**`power/annfp.py`** and **`power/frame.py`** from `FINDINGS-power.md` did all the actual reading;
`forceneeds/enrich.py` is six lines on top of `annfp.py` that annotate every `[reg + 0xNN]` read
off the `CSubUnitDataBase` singleton with that field's name from `project.json`. That last one is
the difference between 1800 unreadable lines and a list of unit types, and it only works because
the record already had all 33 of those fields — which is the argument for `project.json` being
machine-readable rather than prose.

The invocations that reproduce the two listings:

```
python power/annfp.py 0x8B60F0 0x1E8A --prologue 0x8B6117 --eh 0x94 | python forceneeds/enrich.py -
python power/annfp.py 0x8B5210 0xEE0  --prologue 0x8B5234 --eh 0x64 | python forceneeds/enrich.py -
python power/frame.py  0x8B5210 0xEE0  --prologue 0x8B5234 --eh 0x64 --check
```

## 11. Thread safety

Nothing changes from `FINDINGS-power.md`: both arms run where slot 73 runs, on a TBB worker, once
per game hour under `ProcessAIFunctor::execute`, and both inline the `CCurrentGameState` lazy
construction — `0x8B60F0` four times, `0x8B5210` three. Neither touches Lua: there is no
`call GetDefines` in either body and no reference to `0x8EACA0` or the `0x1A86040` singleton.
`0x8B5210` additionally inlines `CSubUnitDataBase`'s lazy construction at `0x8B524A`, which is a
**third singleton the stock game builds from a worker thread**, after `CCurrentGameState` and
`CCountryDataBase`.

## What is not established

1. **`CCountry +0x590`/`+0x594`** still. Four searches with four controls say no writer; the one
   hole left is a writer holding a pointer to a sub-object at a different displacement. *Cheapest
   check:* `dumpStruct.py` on two or three `CCountry` with `--length 0x600`. If the two dwords are
   zero on every country, the claim lands; if they differ between countries, they are
   uninitialised heap and the arithmetic above them is not merely dead but unpredictable.
2. **Which of `CCountry +0x7B8` and `+0x7DC` is `traded_away` and which is `convoyed_out`.** Both
   are `GetDailyExpense` terms and the expense side skips neither, so there is no asymmetry to fit
   on. *Cheapest check:* find the writer inside `CConvoy::RunDelivery` or
   `CCountry::RunDailyTradeRoutes`, both of which are already named.
3. **`0x88C140` and `0x8C4370`**, the two unidentified producers of `CAIUnit +0xD8` (the submarine
   want) and `+0xD4` (the sealift floor). Neither is in any vftable, so neither gets a name for
   free. *Cheapest check:* `findRefs.py --callers` on each, and the caller will be a slot-73
   callee.
4. **`CUnit +0x234`'s objective node layout.** `+0x8` is a province id and `+0x10` a force figure
   that overrides the enemy count; `+0x1C` is the next pointer. The record has the list as
   `plan_objectives`, "a list of CObjective, each 0x24 bytes"; the remaining fields were not read.
   *Cheapest check:* `CObjective::LoadKey`, which the grammar frontier says has been read.
5. **Whether an AI country's plan ends up holding the six-aircraft vector or
   `ComputePlanWantedSubUnits`' land composition.** §8 gives the gate and the two producers but
   not the resolution. *Cheapest check:* `dumpStruct.py` on an AI theatre's `CUnit` at `+0x26C`
   with `--length 0x10`, and read the vector: six non-zero entries at aircraft indices means
   `0x8B5210` won; a broad spread including infantry means `ComputePlanWantedSubUnits` did.
6. **`CSubUnitDefinition +0x1B8` `minimum_of_type` and `+0x1BC` `max_percentage_of_type`.** Both
   placed from `CSubUnitDefinition::LoadKey` by `fieldmap.py`, neither with a consumer read. They
   are the only per-type quantity caps in the definition, which makes them the most promising
   unexamined lever on what gets built. *Cheapest check:* `bytefield.py 0x1B8 --dword` and
   `0x1BC --dword`, filtered to readers.
7. **`CSubUnitDefinition +0x1C0` `available_trigger`.** A `CTrigger` by its key's name, not read by
   either force planner. If some *other* path honours it, it is a scriptable gate on buildability
   and worth a section of its own. *Cheapest check:* the same scan, for readers.
8. **`CTerrain +0x6A`/`+0x6B`/`+0x6C`** — `is_urban`, `is_desert`, `is_arctic` are set and read by
   nothing in either force planner. *Cheapest check:* `coverstore.py 0x6A` and friends, filtered to
   loads.
9. **`0x4763A0`**, the predicate both arms apply to an objective province before counting it as
   enemy-held. Unnamed and unread; it takes the province in ECX and answers a bool.
10. **`0x8CD890` and `0x8D0880`** are still extents, gates and call lists, and their `project.json`
    names are still `inferred` placeholders. Not touched here.
11. **`CSendExpeditionCommand::Execute`'s not-equal arm** at `0x5E97A2`. Not touched here.
12. **Nothing was watched in a running game.** In order of value: `CCountry +0x590`/`+0x594` on
    several countries (item 1); an AI theatre's `CUnit +0x26C` (item 5); `CTheatre +0x8C` against
    the number of regions a theatre visibly spans, which confirms the garrison and marine
    arithmetic in one look; and a country whose `map/terrain.txt` has had `mountain` renamed,
    which should take the played arm's bergsjaeger want to zero and is the cheapest confirmation
    available that the name-matching in `CTerrain::CTerrain` is really what drives it.
