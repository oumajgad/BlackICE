# What the AI thinks it can win

`FINDINGS-aiplans.md` left three things unread and called `0x8B60F0` the highest-value one:
the power estimator behind slot 78's commitment ladder. This is that function, the middle of
slot 78, slot 79, and the three `CTransferSubUnitCommand` sites — plus the function the
predecessor did not know existed, which is where `our_power` and `their_power` actually come
from in an ordinary game.

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is
marked *seen*. Addresses are **virtual** (image base `0x400000`) unless written rva. Numbers are
thousandths unless said otherwise (trap 7).

Three of this file's claims were re-checked independently before it was accepted, because the
ladder's direction is counterintuitive enough to be worth doubting: the factor selection at
`0x8B1F81`–`0x8B1FEA`, its use at `0x8B27FB`–`0x8B2825` (`comisd xmm3, xmm2` then **`ja`** — the
division is held back when the factor *exceeds* strength, so the factor is a floor), and the seven
`.data` words, which read back as exact IEEE floats `2, 1.5, 0.25, 0.75, 0.6, 0.4, 0.2`. A
startup-cached define would be an int in thousandths, so that last check is what settles their
nature. All three hold.

## In one line

A unit's power is **strength × organisation × a per-brigade-type stat sum**, summed over the
brigades and over the agent's divisions, with one terrain term — **+8% per fort level** for a
division that is standing still in a defensive stance — and nothing else; `their_power` is a
by-product of a quite separate question, *how many divisions do I need in this theatre*; and the
ratio of the two sets the **minimum strength a division must have before the AI will commit it**,
which is high when the AI is winning and low when it is losing.

## The tool this reading needed, and the trap it is for

`scratchpad/power/frame.py` normalises every `[esp + N]` in a function to a frame slot by
tracking push depth, and `annfp.py` prints an annotated disassembly with those slots. Without it
this reading is wrong, and here is the specific way:

`our_power` lives in `0x8B60F0`'s frame slot `fp+0x4C`. It is written at `[esp+0x4c]` at
`0x8B61E8`, used as a **loop counter** at `0x8B620A`/`0x8B6214`, and then **re-zeroed at
`[esp+0x50]`** at `0x8B6227`, because a `push` was outstanding. Grep the raw displacement and you
miss the reset, and the counter's leftover value — the number of convoy ship definitions — looks
like part of the answer. That is trap 12's shape applied to a stack frame instead of to an object.

Four rules, in decreasing certainty: `push`/`pop`/`sub esp`/`add esp` are exact; a direct `call`
is credited the callee's own first `ret N`; an indirect `call` through a vftable slot is credited
the pushes made since the previous call or branch, because these are all `__thiscall`; and a `mov
byte ptr [esp+X], <imm>` to the EH state slot resynchronises.

Three things in there each cost a wrong reading before they were fixed, and all three are worth
knowing:

- **Work the EH slot out, do not guess it.** For MSVC's `push ebp; mov ebp,esp; and esp,-8; push
  -1; push <handler>; push fs:[0]; mov fs:[0],esp; sub esp,N; push ebx; push esi; push edi`, the
  saved `fs:[0]` sits at `fp+N+12` and the trylevel — the `push -1` — at `fp+N+20`. The resync
  anchor is the second. Slot 78 has `sub esp,0xA8`, so its anchor is `fp+0xBC`, not `fp+0xB4`;
  using `0xB4` moved the frame by 8 bytes after `0x8B2066` and made slot 78's commitment factor
  look **dead**. It is not dead: it is read at `0x8B27FB`.
- **Only an immediate source may resynchronise.** Letting `mov byte ptr [esp+0x74], bl` count as
  the EH state moved `0x8B82F0`'s whole frame by `0x28`.
- **Follow a hot-patch stub, and only a hot-patch stub.** `free` (`0xB95F9B`) is `mov edi,edi;
  push ebp; mov ebp,esp; pop ebp; jmp <real>`, and reading the `ret 4` that happens to follow the
  stub drifted every local by 4. But following a `jmp` *later* in a body is wrong the other way —
  it cost `CGameState::CGameState` its real `ret 4`. The rule is: follow a `jmp` only within the
  first 8 bytes of the entry.

`--check` prints the depth at every write to the EH slot. All three functions read here come out
clean: the only disagreements left are the epilogues reading the SEH link at `fp+N+12`, which is
correct.

## `CUnit::GetPower`, slot 27 — the whole of what a unit is worth

`0x5C73F0`, `int* __thiscall (CUnit* this, int* out)`, `ret 4`. **One body in four vftables —
`CUnit`, `CArmy`, `CNavy`, `CAir`, all at slot 27** — which is inheritance, not folding, so the
name is `CUnit`'s (trap 4; the holder count is 4 across 4 classes, and they are one family).

```
*out = 0
for (su in this->subunits (+0x38)) {
    typeValue = *GetSubUnitDefinitionCombatValue(su->definition (+0x58), &local)
    *out += (su->strength(+0x5C) / 100) * typeValue / 1000
            * (su->organisation(+0x60) / 100) / 1000
}
return out
```

The scalings are `x * 1000 / 100000` twice, which is `/100` on a thousandths value. `su->+0x58`
is the regiment's **technology-applied** definition, so technology enters here and only here.

**A unit above the division level contributes nothing**, because only a division holds regiments
(`CUnit +0x38`). That is why summing over a whole OOB subtree, which is what `0x8B60F0` does,
does not double count.

### `0x5A8690` — what one brigade type is worth

`int* __fastcall (CSubUnitDefinition* definition@EAX, int* out@ESI)`. Bare `ret`, both arguments
in registers, so it is `__fastcall` and **not** a `__thiscall` — trap 11, and the reason it is
recorded as a free function rather than `CSubUnitDefinition::`. Five callers: `0x5C741B` (slot
27), `0x8E2281` and `0x8E26AC` (`ComputePlanWantedSubUnits`), and `0x77B89F`/`0x77B8BD` in the
interface — so this number is also **on screen somewhere**, which makes it checkable.

It abuts `0x5A8540` with **no padding at all** — a new pair for trap 2's list, and
`functionStart` lands in `0x5A8540` for any address inside it.

```
*out = 0
if (definition->+0x2D)                                    // land
    base = soft_attack(+0x134) + hard_attack(+0x138) + piercing_attack(+0x13C)
    *out = (base + (defensiveness(+0x11C) + toughness(+0x120)) / 10 + armor(+0x12C))
           * (2000 - softness(+0x124)) / 1000
else if (definition->is_air (+0x2C))
    *out = air_attack(+0x140) + air_defence(+0x128) + 500
else                                                      // ship
    *out = (500 + sea_attack(+0x168) + sea_defence(+0x160)) * hull(+0x178) / 1000
```

`+0x2D` is a new field, sitting between `is_air` (`+0x2C`) and `is_ship` (`+0x2E`), which is
where a land flag belongs. **Named from this one consumer, so inferred.**

**So the answer to "what goes into a power figure" is: strength, organisation, and seven of the
unit file's own numbers.** Nothing else. For a land brigade the three attacks count at face
value, defensiveness and toughness at a tenth each, armour at face value, and the lot is scaled
by `2 - softness` — which is the term with teeth, because an infantry brigade at softness 1.0
scores ×1.0 and an armour brigade at 0.2 scores ×1.8. **Every one of those is a key in
`units/*.txt`**, so a mod moves this number by editing brigade stats, and by nothing else.

The 500 added to both the air and the naval arm is the global `0x1A886AC` (rva `0x16886AC`),
which is zero in the file and written **once**, by its own `.CRT$XCU` initialiser at `0xCC39AB`,
as `(int)floorf(500.5f)` from the float at `0x160A5E8`. That is trap 8's third case: it was never
a define and no `defines.lua` entry can reach it.

### The fort bonus, and where terrain does and does not enter

`0x8B9490`, `int __stdcall (CAIUnit* agent, int* powerOut)`, `ret 8`, one caller (`0x8B508E`).
Recorded as a free function because `agent` arrives on the stack, not in `ecx` (trap 11).

```
for (unit in agent->+0x11C) {                   // the land units slot 78 collected
    if (unit->oob_level (+0x1F4) != 4) continue  // divisions only
    p = *CUnit::GetPower(unit, &local)
    if (unit->movement_destination_province_id (+0x2CC) > 0) goto add
    kind = unit->order(+0xB0)->GetKind()                        // slot 16
    if (kind != 0x4E5 && kind != 0x56C && unit->order->vf[24]()) goto add
    if (agent->unit->plan.stance (CUnit +0x208) >= 3) goto add
    fort = province->modifiers(+0x114)[FORT_LEVEL] / 1000        // +0x50, id 10
    p = p * (1000 + fort * 80) / 1000
 add:
    *powerOut += p
    counted++
}
return counted
```

`CMapProvince +0x114` is already recorded as `modifiers`, indexed `id * 8` (trap 5), and `+0x50`
is already fixed as id 10 `FORT_LEVEL` by `FINDINGS-combatmods.md`. The 80 is an inlined
`(int)floorf(80.5f)` — not even a global, so it is beyond any mod's reach.

**So the only terrain the AI's power figure knows about is the land fort, at +8% per level, and
only for a division that is not moving, is not under a move or redeployment order, and whose plan
stance is below 3.** Weather, terrain type, river, amphibious, night — none of it. Air and naval
support do not enter either: `CUnit::GetPower` walks one unit's own brigades and nothing else.

## `CAIUnit::UpdatePlanPower` (`0x8B5060`) — the writer the predecessor did not have

`void __thiscall (CAIUnit* this)`, bare `ret`. Two callers: `0x8BA02E`, inside
`CAIUnit::SetUnit` (slot 63), and `0x88E553` in `CEU3AI`.

```
this->+0x35C = 0;  this->+0x358 = SumOurPower(this, &this->+0x35C)
this->+0x360 = 0;  this->+0x354 = CAIUnit::EstimateTheatreNeed(this, &this->+0x360)
if (unit->plan.our_power/1000   != this->+0x35C/1000 ||
    unit->plan.their_power/1000 != this->+0x360/1000)
    post CSetPlanAttributesCommand(unit, 5, 3, 3, this->+0x35C, this->+0x360)
```

Stance 5 and air/naval 3 are the command's **own sentinels** — `CSetPlanAttributesCommand::Execute`
(`0x5E77D0`) skips the stance when `+0x68 == 5` (`0x5E7827`) and the air and naval stances when
`+0x6C`/`+0x70 == 3` (`0x5E78C4`, `0x5E790D`) — so this call sets nothing but the two powers. It
then writes `cmd->+0x74` to `CUnit +0x27C` and `cmd->+0x78` to `CUnit +0x280`, which are
`CUnitPlan +0x80 our_power` and `+0x84 their_power`, each skipped when the argument is negative
(`js` at `0x5E795B` and `0x5E79A3`) — which is what makes `-1000` the "unchanged" sentinel slot 76
and slot 77 use.

Four new `CAIUnit` fields fall out: **`+0x35C` our_power, `+0x360` their_power, `+0x358` the
division count, `+0x354` the division need.**

`CSetPlanAttributesCommand`'s constructor (`0x5E7710`, `ret 0x1C`) has seven callers. Five pass
`(-1000, -1000)`; only two pass real figures, and both are in this chain: `0x8B5152`, in this
function, and `0x8B7E87`, in `0x8B60F0`. **So these two are the complete set of writers of
`our_power`/`their_power` outside the savegame loader.**

## `0x8B60F0` and `0x8B5210` — one job, two arms, split on who is playing

Slot 73 at `0x8B0B5F`:

```
edx = gamestate->played_countries_array (+0xBCC)
if (edx[this->countryId] != 0) 0x8B60F0(this)      ; a human plays this country
else                          0x8B5210(this)
```

The decode is synchronised from slot 73's entry and unambiguous. `CCurrentGameState +0xBCC` is
already recorded as `played_countries_array`; the corroboration is `0x6D3BE7`, which writes
`array[id] = 1` in the same breath as `gamestate->+0xC30`/`+0xC34`, the player tag and id.

| | `0x8B5210` | `0x8B60F0` |
| --- | --- | --- |
| extent | `0x8B5210`–`0x8B60EC` (`ret 4`), 3804 bytes | `0x8B60F0`–`0x8B7F79` (`ret 4` at `0x8B7F77`), 7818 bytes |
| caller | `0x8B0B76` | `0x8B0B7D` |
| runs for | a country no human plays | a country a human plays |
| `CSetPlanForcesCommand` | yes, `0x8B6028` | yes, `0x8B7D9B` |
| `CSetPlanAttributesCommand` | **no** | yes, `0x8B7E87` |

**They abut with a single `int3` between them** — `0x8B5210`'s `ret 4` is at `0x8B60EC`, the
`int3` at `0x8B60EF`, and `0x8B60F0` is the next byte. `functionStart` survives that, but any
scan that looks for a *run* of padding does not. New for trap 2's list.

The practical consequence: **for an AI-only country, `our_power`/`their_power` are whatever
`CAIUnit::UpdatePlanPower` last set.** For the player's own delegated plans they are overwritten
by `0x8B60F0`, **with a different formula** — see below. That is a real discrepancy in the game,
not a reading error.

### What `0x8B60F0` actually does

```
area = CAIUnit::GetArea(this);  if (!area || !this->unit) return
country = GetCountry(&this->tag)
shortage = 1.0
if (country->+0x590 / 1000 < 0.2) shortage = 1.0 + (0.2 - that) * 2.5     ; 1.0 .. 1.5
fp+0x54 = country->+0x594 / 1000
convoyDefs = GetConvoyShipDefinitions()
build a per-subunit-type want vector at fp+0x68, one entry per type        ; 0x4221F0
their_power = 0                                                            ; fp+0x18
need = CAIUnit::EstimateTheatreNeed(this, &their_power)                    ; 0x8B622B
brigadeDemand = this->+0x370 + (int)round(need * shortage * 3.0)           ; fp+0x38
our_power = 0                                                              ; fp+0x4C, re-zeroed at 0x8B6227
for (army in this->+0x11C) { our_power += *CUnit::GetPower(army); brigades += army->+0x40 }
  ... 5.5 KB of per-type demand, which was not read line by line ...
if (the want vector differs from unit->plan.min (CUnit +0x26C)) post CSetPlanForcesCommand
post CSetPlanAttributesCommand(unit, 5, 3, 3, our_power, their_power)
```

**`our_power` here is not what `SumOurPower` computes.** It is the plain sum of `CUnit::GetPower`
over *every* entry of `+0x11C`, with **no `oob_level == 4` filter and no fort bonus**. The filter
makes no difference (a non-division contributes nothing), but the fort bonus does: the player's
delegated plans get a fort-less figure and the AI's get one that is up to 1.8× larger on a
level-10 fort.

`CAIUnit +0x11C` holds **`CArmy*`**: slot 78 pushes `unit->vf[9]()` there, and only after
`unit->vf[15]()` (the `isLand` type tag, `0xA92590` = `mov al,1`) answers true, so only a `CArmy`
reaches it. `+0x40` is `regiments_count`.

**`CCountry +0x590` and `+0x594` have exactly one reader each in the whole image — this function —
and no writer anywhere.** A complete byte scan of `.text` for the little-endian displacement, with
every instruction length tried so that SSE stores are not missed, finds `+0x590` read at
`0x8B6141` and written only at `0x649C6C`, which is a `CInGameIdler`; `+0x594` is read at
`0x8B61A7` and written nowhere. The **positive control** for that scan is the same scan on `CUnit
+0x2C8` and on `CCountry +0x590` itself, both of which do turn up writes — so the method can see
a write when there is one. If both fields really are always zero, the shortage factor is a
constant **1.5** and `fp+0x54` is a constant **0**, which zeroes one term of the brigade demand.
That is **inferred**, not read: a writer holding a pointer to a sub-object of `CCountry` would use
a different displacement and this scan cannot see it. `dumpStruct.py` on a `CCountry` settles it
in one look.

### `CAIUnit::EstimateTheatreNeed` (`0x8B9610`) and `CAIUnit::EstimateAreaNeed` (`0x8B82F0`)

`0x8B9610` is `int __thiscall (CAIUnit* this, int* theirPowerOut)`, `ret 4`, two callers
(`0x8B50A8`, `0x8B622B`), and it is eight instructions of logic:

```
area = CAIUnit::GetArea(this);  if (!area) return 0
visited = {}
for (node in area->+0x84) total += EstimateAreaNeed(node[0], theirPowerOut, &visited, 1)
free visited; return total
```

**`CTheatre +0x84` is a new field: a `CList` of `COwnerArea*`, the regions the theatre spans** —
distinct from `fronts_first` (`+0x50`, `CAreaBorder`) and `provinces_first` (`+0x30`).

`0x8B82F0` is `int __thiscall (CAIUnit* this, COwnerArea* region, int* theirPowerOut, CList*
visited, bool relaxed)`, `ret 0x10`, 4507 bytes, four callers of which one is itself. It is **the
only place `their_power` is computed.** Two early exits:

- if the region's first province is controlled by an enemy, it answers
  `CountEnemyUnitsInArea(&country->strategy (CCountry +0x48C), region, 0)` and touches
  `*theirPowerOut` not at all (`0x8B83B0`–`0x8B83D6`);
- it answers 0 when a pair of country-database comparisons match (`0x8B83D9`–`0x8B843F`).

Otherwise it counts the agent's objectives that lie in this region (`0x8B8520`–`0x8B86BA`), then
walks the agent's front-province vector at `CAIUnit +0xC0` and for each province `p`:

```
if (!p->area->IsValid()) next
isFront = false
for (edge in p->template(+0xD4)->edges(+0x90, 20 bytes each)) {
    if (edge->kind == 3) continue
    nb = gamestate->provinces[edge->neighbour]
    if (!nb->template->+0x13D) continue
    if (nb->area != region) continue
    if (nb->+0x5C >= 200) { isFront = true; break }          ; the global 0x1B151E4
}
diplo = country->diplomacy(+0xE28)[p->controller_id]
if (isFront && diplo->+0x28) {
    months = monthsSince(diplo->+0x28->+0x18)
    if (months < GetDefines()->diplomacy(+0xBC)->NAP_UNBREAKABLE_MONTHS(+0xE4) * 2 / 3)
        isFront = false
}
if (!isFront) next
atWar = 0x8A9A30(p->controller)
...
weight = 1000
if (relaxed && diplo->+0x28 == 0) { if (!atWar) weight = 500 }
else                             { if ( atWar) weight = 2000 }
if (halve) weight = weight / 2
floor = (p->+0x5C <= 300 || halve) ? 500 : 1000              ; globals 0x1B15204, 0x1B15218
enemyCount = 0; enemyStrength = 0
for (u in p->units (+0x2B8)) {
    if (!u->vf[15]()) continue
    if (u->owner_id == 0 || u->tag == "REB" ||
        (!IsSameSide(country, &u->tag) &&
         (!country->diplomacy[u->owner_id]->+0x58 || 0x42F1B0(country, &u->tag)))) {
        enemyCount++
        enemyStrength += *CUnit::GetPower(u)
    }
}
score = max(floor, enemyCount * weight / 1000)
power = enemyStrength * weight / 1000
if (p->area == country->GetActingCapitalLocation()->area && <a faction test>) {
    score += weight;  power += power * weight / 1000
}
if (score > 1000 && <three capital-adjacency gates>) { power = power * 1000 / score; score = 1000 }
*theirPowerOut += power
weightSum += score
```

The function's **return value** is a division count for the region, taken from the weight sum:

```
need = (int)(weightSum / min(region->provinceCount (+0x2C), 40))
cap  = region->provinceCount / 4;  if (cap < 1 && !relaxed) cap = 1
need = min(need, cap)
if (region->+0x3C == 0 && region != our capital's area) {
    if (need > 1 && provinceCount <  3) need = 1
    if (need > 2 && provinceCount < 15) need = 2
}
if (need == 0 && weightSum > 2.0) need = 1
return need
```

It recurses into neighbouring regions through `CAIUnit +0x338` — only into a region whose
`COwnerArea +0x6C` **equals** this one's, and only when `0x4803F0` of that pointer answers more
than 1 — adding each result to its own and deduplicating through the `visited` list.

So `their_power` is **enemy divisions' `GetPower`, weighted by how much of a front each province
is, normalised by the region's size, and summed over the theatre's regions**. Every weight in it
is a literal: 1000, 2000, 500, the `/2`, the 40, the `/4`, the `3` and `15` province counts, and
the three `(int)floor(N.5f)` statics below. **The one number a mod can move is
`NAP_UNBREAKABLE_MONTHS`.**

### The one define in the whole chain

`diplomacy.NAP_UNBREAKABLE_MONTHS` (block `+0xBC`, offset `+0xE4`, confirmed against
`definesMap.py --block diplomacy`), read through a plain `call GetDefines` at `0x8B8980`. The
arithmetic is `value * 2000 / 1000`, then `* 1000 / 3000`, then `/ 1000`, which is
`NAP_UNBREAKABLE_MONTHS * 2 / 3` in whole months. BlackICE sets it to 10, so **the AI will not
treat a border as a front until the NAP with that country is about 6 months old.** Raising the
define makes the AI blind to a NAP border for longer; lowering it makes it plan against a fresh
pact sooner. That is a real, reachable lever on AI behaviour, and it is the only one in this code.

### The three `(int)floor(N.5f)` statics

| global | value | written by | what it gates |
| --- | --- | --- | --- |
| `0x1B151E4` (rva `0x17151E4`) | **200** | `0xD118EB`, from `floorf` of the float `0x160A64C` = 200.5 | a neighbour's `CMapProvince +0x5C` must reach it for the province to be a front. **Eight readers across the unit AI** — `0x8B8835`, `0x8B9738`, `0x8BADBC`, `0x8BB7BF`, `0x8BBCFA`, `0x8CFB8C`, `0x8DA60C`, `0x8DAA79` |
| `0x1B15204` (rva `0x1715204`) | **300** | `0xD1194B`, from `0x160AAB4` = 300.5 | at or below it, the province's own weight floor drops |
| `0x1B15218` (rva `0x1715218`) | **500** | `0xD11A3B`, from `0x160A5E8` = 500.5 | that reduced floor |

All three are trap 8's third case: zero in the file, written once each by their own `.CRT$XCU`
initialiser, and unreachable from `defines.lua`. The float `0x160A5E8` seeds both `0x1B15218`
and the 500 in the air and naval brigade values — the same literal, two statics.

**`CMapProvince +0x5C` is a new field and it is not fully settled.** It is an int in thousandths
that the unit AI uses as "is this province worth a front", with the two thresholds above. Its
**only writer** is `CProvince::LoadKey`'s default arm, which treats an unrecognised key as a
building name, looks it up, and — when the loaded building's definition `+0x24` is **12** — sets
`province->+0x5C = building->level(+0x20) * definition->+0x8 / 1000` (`0x496132`–`0x496152`).
Which building type index 12 is was **not** established: the index is assigned in load order and
BlackICE has reordered `common/buildings.txt`, so counting entries in the mod's file proves
nothing about the stock engine's expectation. Consumers elsewhere — `CVerySafePathFind::MayStep`
adds it to a path cost, `CCountry::FindSupplyDepot` and `CConvoy::IsRouteUsable` read it,
`CUnit::EnterProvince` subtracts it — all point at infrastructure, but that is **inference from a
consumer set, not a reading**, and the building index does not support it. The cheapest check is
`dumpStruct.py` on a province and a comparison with the province panel.

## The middle of slot 78, `0x8B2100`–`0x8B32AC`

`void __thiscall`, `0x8B1D10`–`0x8B32AC` (bare `ret`), with the `bad_alloc` throw path at
`0x8B32AD`–`0x8B32DF` reached by the `je` at `0x8B2053`. Slot 79 begins at `0x8B32E0`. Called
from slot 73 at `0x8B0A1D` when `this->+0x86` is set, or the hour matches `(id+9) % 24`, or the
daily-stagger flag is set. **Whenever `0x8B60F0` runs, slot 78 has already run in the same
pass**, because `0x8B60F0` is reached only under that same flag (`0x8B0A9B`) and slot 78's gate is
a superset of it.

### Step 1 — ten containers, not seven

`0x8B1D42`–`0x8B1F43` erases nine vectors and frees one list, then `this->+0x348 = 0`:

| container | what the body puts in it |
| --- | --- |
| `+0xDC`/`+0xE0`/`+0xE4` | every **naval** unit of the subtree, as `unit->vf[11]()` (`0x8B25A2`) |
| `+0xEC`/`+0xF0`/`+0xF4` | the naval units with `transport_capacity` (`CUnit +0xC8 -> +0x144`) that hold no objectives or fail `0x8B16F0` (`0x8B2687`) |
| `+0xFC`/`+0x100`/`+0x104` | a `CList` of every **air** unit, as `unit->vf[13]()`, appended through `0x8DD3D0` (`0x8B26A8`) |
| `+0x10C`/`+0x110` | the air units with transport capacity (`0x8B26E9`) |
| `+0x11C`/`+0x120` | every **land** unit, as `unit->vf[9]()` — i.e. `CArmy*` (`0x8B228D`). **This is the vector `our_power` sums** |
| `+0x12C`/`+0x130` | the divisions that pass the commitment gate (`0x8B2CDA` and, via `0x8B288B`, `0x8B2893`) |
| `+0x13C`/`+0x140` | the same divisions, second copy (`0x8B28AF`) |
| `+0x14C`/`+0x150` | the units whose `oob_level` is not 4 (`0x8B2A02`) |
| `+0x15C`/`+0x160` | the divisions **held back** (`0x8B2994` → `0x8B288B`) |
| `+0x16C`/`+0x170` | the armies whose `+0x2FC` is 8 (`0x8B23A8`) |
| `+0x1AC`/`+0x1B0`/`+0x1B4` | a `std::vector<int>` of `order->+0xC` for every unit whose order kind is the save token `0x3A5` (`0x8B21A2`) — erased first of all, at `0x8B2000` |

**`CAIUnit +0xFC` is the list head, `+0x100` the tail, `+0x104` the count.** The record has
`+0x100 subordinate_list_first`, one word too high: the walk-and-free at `0x8B1E76` starts from
`[esi+0xFC]` and all three words are zeroed at `0x8B1E94`, `0x8B1E9A`, `0x8B1EA0`. `+0x104` is
**`0x8CD890`'s entry test**.

Also at the top: `fp+0x3F = ((+0x110 - +0x10C) & ~3) > 0`, written at `0x8B1D53`. The record calls
this "slot 78's entry test". **It is not an entry test** — the function always runs; the flag is
read **once**, at `0x8B272D`, as a per-division skip when `unit->vf[9]()->+0x2FC == 8`.

### Step 2 — the commitment ladder, and what it actually does

`0x8B1F45`–`0x8B1FEA`:

```
ratio = CUnitPlan::GetPowerRatio(&this->unit->plan) / 1000    ; our_power*1000/their_power
factor = 0.5
if      (ratio > 2.00) factor = 0.7
else if (ratio > 1.50) factor = 0.6
else if (ratio < 0.25) factor = 0.2
else if (ratio < 0.50) factor = 0.3
else if (ratio < 0.75) factor = 0.4
```

The factor is read **exactly once**, at `0x8B27FB`, and it is a **minimum strength**:

```
if (!this->+0x364) → push the division straight onto the held-back vector
if (!canReachTheArea) → the same
GetUnitAverageStrengthAndOrganisation(division, &strength, &organisation)   ; 0x5C7250
if (factor > strength)       → held back                      0x8B280E
if (0.300 > organisation)    → held back                      0x8B2825
if (division->+0x2C8) {                                       ; already held back once
    if (factor + (1 - factor) * 0.5 > strength) → held back    0x8B285A
    if (0.650 > organisation)                   → held back    0x8B2876
}
→ committed: push onto +0x12C and +0x13C
```

**So the better the AI thinks it is doing, the higher the bar a division must clear to be
used.** At a ratio above 2 it wants 70% average strength; losing badly, below 0.25, it will
commit a division at 20%. `CUnit +0x2C8` is the hysteresis bit: once a division has been held
back, it must reach halfway between the factor and full strength, and 65% organisation, to come
back. That is the whole of the "commitment ladder", and the predecessor's framing — "the AI's own
reading of am I winning here" — is right about the input and understates what it controls.

`GetUnitAverageStrengthAndOrganisation` (`0x5C7250`, `void __stdcall`, `ret 0xC`) is
`strength / GetMaxStrength` and `organisation / CSubUnit::GetMaxOrganisation` per regiment,
summed and divided by `regiments_count` — two averages over the brigades, each 0..1.

### The seven `.data` float constants: all seven are literals

`FINDINGS-aiplans.md` left these unresolved. Three independent tests settle every one:

| address | rva | value | where |
| --- | --- | --- | --- |
| `0x1718064` | `0x1318064` | `2.0f` | ladder threshold, `0x8B1F81` |
| `0x17179AC` | `0x13179AC` | `1.5f` | ladder threshold, `0x8B1F94` |
| `0x171DE18` | `0x131DE18` | `0.25f` | ladder threshold, `0x8B1FA7` |
| `0x17179A8` | `0x13179A8` | `0.75f` | ladder threshold, `0x8B1FD5`, and the recall strength floor at `0x8B2BB5` |
| `0x170AC00` | `0x130AC00` | `0.6f` | factor, `0x8B1F9D` |
| `0x170AC10` | `0x130AC10` | `0.4f` | factor, `0x8B1FE2` |
| `0x171618C` | `0x131618C` | `0.2f` | factor, `0x8B1FB4` |

1. **The file holds the float bits.** A startup-cached define's global is *uninitialised* `.data`
   — `0x1A886AC`, `0x1B151E4`, `0x1B15204` and `0x1B15218` all read back as no bytes at all — and
   it is stored as an **int in thousandths**, never as an IEEE float. These seven read back as
   exactly 2.0, 1.5, 0.25, 0.75, 0.6, 0.4, 0.2.
2. **`scratchpad/naval/definecache.py` has no entry for any of them.** That negative has a
   positive control: the same run maps 51 globals across the `military` and `weather` blocks,
   including `MAX_OFFICERS` at `0x1BEA3EC` and `LOW_ORG_REGAIN_BONUS` at `0x1BEBBD8`, so the tool
   is working on this image.
3. **The values are the ladder.** 2.00, 1.50, 0.75, 0.25 are its four thresholds and 0.6, 0.4,
   0.2 three of its six outputs; the remaining three outputs are `0.7f` at `0x160A2E8`, `0.3f` at
   `0x15C05EC` and `0.5f` at `0x15AB304`, which are in `.rdata`. **The constant pool straddles
   `.rdata` and `.data` in this image** — `1.0f` lives at `0x171DBAC`, in `.data` — so being in
   `.data` says nothing at all. That is the whole explanation of the puzzle.

**None of the ladder's nine constants is a define, a cached define or a static. They are compiled
in and a mod cannot move any of them.**

### Step 3 — the reserve, which is where stance enters

`0x8B2A15`–`0x8B2B1D`, after the per-unit loop:

```
stance = this->unit->plan.stance (CUnit +0x208)
surplus = -2
if (this->+0x364) {
    nDiv = count(+0x12C)
    if (nDiv > 10 || this->unit->oob_level != 0) {         ; a theatre agent with <= 10 skips it
        nArea = count(this->+0x90)                         ; the ops area's province count
        surplus = 0
        if (nDiv > nArea * 1.5) {
            k = (stance == 4 || stance == 1) ? 10 : (stance == 3) ? 7 : 5
            surplus = nDiv / k
        }
        if (nArea > nDiv - surplus) surplus = nDiv - nArea
    }
}
limit = surplus + 2
```

**The reserve is a fraction of the committed divisions, and the fraction is chosen by the plan
stance**: a tenth at stance 4 and at stance 1, a seventh at stance 3, a fifth otherwise — and
nothing at all unless the agent has more than 1.5 divisions per ops-area province. It is then
capped so the committed force never drops below the ops area's province count.

With `+0x364` clear, or for a theatre agent with ten or fewer divisions, `surplus` is **-2**,
`limit` is 0, and the two loops below degenerate into "recall everything you can, detach nothing".

### Step 4 — recalling from the reserve (`0x8B2B1D`–`0x8B2CF2`)

While `count(+0x15C) > limit`, pick the best held-back division and put it back:

```
best = 0; bestScore = 0
for (u in this->+0x15C) {
    GetUnitAverageStrengthAndOrganisation(u, &strength, &organisation)
    if (0.33 > organisation) continue
    if (0.75 > strength)     continue
    score = strength + organisation
    if (u->+0x2FC == 8) score += 1.0
    if (score > bestScore) { best = u; bestScore = score }
}
if (!best) stop
erase best from +0x15C;  best->+0x2C8 = 0;  push best onto +0x12C
decrement the per-province counter for best's current province      ; 0x8DCF30
```

### Step 5 — detaching into the reserve (`0x8B2D92`–`0x8B3284`)

While `count(+0x15C) < surplus`, pick the worst committed division and take it out. This is the
only scoring in slot 78 and it is worth having in full:

```
best = 0; bestScore = -100000.0
for (u in this->+0x12C) {
    dest = u->GetMovementDestinationProvince() ?: u->current_province
    if (this->unit->oob_level == 0 && GetArea() && dest->area != 0x4B14F0(area)
        && dest->area not in this->+0x338) continue
    onFrontier = false; neighbourWeMayUse = false
    for (edge in dest->template edges) {
        if (edge->kind == 3) continue
        nb = provinces[edge->neighbour]
        if (!nb->template->+0x13D || !nb->area->IsValid()) continue
        if (nb->controller_id == this->countryId) continue
        if (IsEnemy(country, &nb->controller)) { onFrontier = true; continue }
        if (0x8ADE10(&country->strategy, nb->controller)) neighbourWeMayUse = true
    }
    if (neighbourWeMayUse) continue
    if (onFrontier) {
        for (su in dest->+0x2EC) if (su->vf[11]() == 1) goto next
        if (0x5D5C20(&dest->units) >= 2) goto next
    }
    GetUnitAverageStrengthAndOrganisation(u, &strength, &organisation)
    score = ((1 - organisation) + (1 - strength)) * 5
    if (u->+0xD4 >  0)   score += 1.0
    if (u->+0x2FC == 8)  score += 0.9
    if (u->+0x2C8)       score += 0.2
    if (stance >= 3) { if (u->+0x2FC == 3) score -= 2.0; else if (u->+0x2FC == 4) score -= 1.5 }
    else             { if (u->+0x2FC == 4) score += 2.0; else if (u->+0x2FC == 3) score += 1.0 }
    if (firstBrigadeDefinition) {
        if (def->type_index == g_CSubUnitDataBase->+0x54->type_index) score += 2.0
        else if (def->type_index == g_CSubUnitDataBase->+0x40->type_index) score -= 2.0
    }
    if (onFrontier) score -= perProvinceCounter(dest)
    if (score > bestScore) { best = u; bestScore = score }
}
erase best from +0x12C;  best->+0x2C8 = 1;  push onto +0x15C; bump the counter
```

**The division the AI pulls out of the line is the one in the worst condition**, nudged by its
role (`CArmy +0x2FC`), by the plan stance, and by its leading brigade's type matching one of the
two definitions `CSubUnitDataBase +0x54` and `+0x40` hold. Every constant here is a literal.

### The one command slot 78 posts, and a correction to it

`0x8B24CB`, as the record has it, but the object being indexed is a **province**, not the army:

```
if (army->ai_param_b (+0x2E4) > 0) {
    prov = gamestate->provinces[army->+0x2E4]
    if (prov->+0x304->+0x20 / 1000 >= 1) next unit            ; the building is still there
    army->+0x2E4 = 0
    post CSetAIParamCommand(unit, army->ai_param_a (+0x2E8), 0)
}
```

So **`CArmy +0x2E4` is a province id**, and `CMapProvince +0x304` is a pointer to one of that
province's buildings whose `+0x20` is its level. The record reads the indexed object as
`army->+0x304`.

## Slot 79, `0x8B32E0`–`0x8B3A4F` — expeditions, both directions

`void __thiscall CAIUnit::ManageExpeditions(CAIUnit*)`, bare `ret` at `0x8B3A46`. Gated on
`owner_ai->+0x2C`; called from slot 73 at `0x8B0A36` under the same daily-stagger flag that gates
`0x8B60F0`, so it runs after slot 78 in the same pass and reads the vector slot 78 just built.

It walks `CAIUnit +0x11C` and splits on `CUnit::expeditionary_owner` (`+0x28C`, already recorded,
saved under that key) and its id half `+0x290`:

**Branch 1, `0x8B335D`–`0x8B3690`: give a loaned unit back.** The unit has an expeditionary owner.
Skip if that owner is a government in exile (`CCountry +0x95`), if a human plays it, if the unit
has a blocking order (`0x8AF4E0`), or if `0x895140(ownerCountry, province->area, &flag, 1)`
answers true. Otherwise **detach every child** — `CDetachUnitCommand` (`0x5DE1D0`) at `0x8B34D1`,
one site, inside the children loop — and post `CSendExpeditionCommand(unit, unit->+0x28C,
unit->+0x290)` at `0x8B35C5`.

**Branch 2, `0x8B36DA`–`0x8B3A1B`: lend a unit away.** The unit has no expeditionary owner.
Require: its destination is not our own territory; the province it stands in is not ours; we are
not at war with that controller (`0x42F1B0`) and it is not an enemy; **the controller is in our own
faction** (`CCountry +0xD8` equal both ways); the unit is a leaf (`+0x1EC == 0`) with `oob_level
!= 0`; and `0x895140(ourCountry, province->area, &flag, 1)` answers true. Then it **erases the
unit from six of the agent's own vectors** — `+0x13C`, `+0x12C`, `+0x14C`, `+0x15C`, `+0x16C`,
`+0x11C`, each through `0x8DCE00` — and posts `CSendExpeditionCommand(unit, that province's
controller tag)` at `0x8B3973`.

**One command does both directions because `CSendExpeditionCommand::Execute` (`0x5E9660`) is a
toggle.** It collects the unit's subtree, and for each unit compares `CUnit +0x290` with the
command's own `+0x68`: **equal, and it clears the field** (`+0x290 = 0`, `+0x28C = '---'`, at
`0x5E96FC`–`0x5E970E`) — the expedition goes home. The not-equal arm at `0x5E97A2` is the one that
sets it, and was not read.

The constructor `0x5E95B0` is `ret 0x10`, `0x6C` bytes, vftable `0x15C951C`, save token `0x18D`,
target tag letters at `+0x64` and id at `+0x68`.

## The three `CTransferSubUnitCommand` sites belong to two slot-73 callees

`findRefs.py --callers`, with the owning function found by taking the greatest **direct-call
target** at or below each site rather than by walking back to padding — the int3-delimited block
around these is 16 KB and holds several functions, so `functionStart` is useless here:

| site | function | extent | caller |
| --- | --- | --- | --- |
| `0x8CE90E` | `0x8CD890` | `ret 8` at `0x8CEE68` | **slot 73**, `0x8B0C6E` |
| `0x8D1341`, `0x8D1BEB` | `0x8D0880` | first `ret 8` at `0x8D08E5`, real end `0x8D3E67`, int3 `0x8D3EA2` | **slot 73**, `0x8B0CB3` |

So it is two bodies, not three, and both are slot-73 callees that `FINDINGS-aiunit.md`'s list of
them (`0x8BA550`, `0x8C3330`, `0x8B0D20`, `0x8DCAE0`, `0x8B1820`, `0x8B4740`) does not have.

`0x8D0880` is trap 3 again: its **first** `ret 8` at `0x8D08E5` is an early exit
(`if (!force && !country->+0xACC && !country->+0xACD) return false`), the body continues at
`0x8D08E8`, and the frame fits — `[esp+0x3a4]` under `sub esp,0x398` plus three register pushes.

Both are `bool __stdcall (CAIUnit* agent, bool force)`. `0x8CD890`'s own entry test is
`if (agent->+0x104 < 1) return false` — the count of the air-unit list — and its call list is
`CSubUnitDataBase` built and destroyed on the stack, `GetConvoyShipDefinitions`,
`CMap::DistanceBetweenProvinces`, `UnitHasBlockingOrder` twice and one
`CTransferSubUnitCommand`. `0x8D0880`'s is `CountShipsByRole` seven times,
`CConvoy::GetDesiredTransports`, `CEU3AI::MoveUnit` four times and two
`CTransferSubUnitCommand`. **The names in `project.json` — `CAIUnit_ReorganiseAirUnits` and
`CAIUnit_ReorganiseNavalUnits` — come from those gates and call lists alone and are marked
`inferred`. Neither body was read.**

## What a mod can and cannot reach

| the AI's number | where it comes from | can a mod move it? |
| --- | --- | --- |
| a brigade's contribution to power | `soft_attack`, `hard_attack`, `piercing_attack`, `defensiveness`, `toughness`, `armor`, `softness`, `air_attack`, `air_defence`, `sea_attack`, `sea_defence`, `hull` on the definition | **yes** — `units/*.txt`, and technology, since the definition is the tech-applied one |
| the 500 added to every ship and aircraft | `(int)floorf(500.5f)` static at `0x1A886AC` | **no** |
| the fort bonus, +8% per level | the fort level is a building, the 80 is an inlined `(int)floorf(80.5f)` | the **level** yes, the 8% no |
| "is this province a front" (200), and the 300/500 weight floor | `(int)floor(N.5f)` statics `0x1B151E4`, `0x1B15204`, `0x1B15218` | **no** |
| whether a NAP border counts as a front | `diplomacy.NAP_UNBREAKABLE_MONTHS × 2 / 3` months | **yes** — the one define in the whole chain |
| the commitment ladder: 2.00/1.50/0.75/0.50/0.25 and 0.7/0.6/0.5/0.4/0.3/0.2 | compiled-in float literals, four in `.rdata` and seven in `.data` | **no** |
| the 0.300 / 0.650 organisation bars and the halfway strength rule | compiled-in literals | **no** |
| the reserve fraction (1/10, 1/7, 1/5) | compiled-in, selected by the plan stance | **no**, but the **stance** is reachable through `CSetPlanAttributesCommand` |
| the detachment score's weights | compiled-in literals, plus `CSubUnitDataBase +0x54`/`+0x40` type indices | **no** |

**The honest summary for a modder: the only two levers on this code are brigade stats and
`NAP_UNBREAKABLE_MONTHS`.** Everything else in the commitment, reserve and detachment decisions is
compiled in. `FINDINGS-aiunit.md`'s "five defines and that is all" stands, and
`NAP_UNBREAKABLE_MONTHS` is a sixth, in a body the earlier survey had not reached.

## Thread safety

Everything here runs where slot 73 runs: on a TBB worker, once per game hour, under
`ProcessAIFunctor::execute`. `0x8B60F0`, `0x8B5210`, `0x8B82F0` and slot 79 each inline the
`CCurrentGameState` lazy construction — `0x8B60F0` does it four times — and `0x8B82F0` also
inlines `CCountryDataBase`'s, at `0x8B8311`–`0x8B8358`, which is a **second singleton the stock
game builds from a worker thread**. Neither touches Lua: no `call GetDefines` in `0x8B60F0` at
all, one in `0x8B82F0`, and no reference to `0x8EACA0` or the `0x1A86040` singleton in any body
read here.

## What is not established

1. **The force-needs half of `0x8B60F0`**, `0x8B62BC`–`0x8B7D13` — about 5.5 KB that turns the
   division need into a per-subunit-type want vector. Read as a structure and a call list only.
   `0x5A3BC0`, called 25 times, is a per-type availability test
   (`bool (something@ECX, CSubUnitDefinition*@EDX)` that answers true when the definition's
   `+0xD4`/`+0xD8` vector is empty); the `CCountry` offsets it feeds on — `+0x77C`, `+0x854`,
   `+0x878`, `+0x8C0`, `+0x908`, `+0x9E0`, `+0xA70` summed one way and `+0x7C4`, `+0x7E8`,
   `+0x830`, `+0x8E4`, `+0x92C`, `+0x998`, `+0x9BC` another — were not identified.
2. **`0x8B5210` entirely.** Extent, caller, gate and the one command it posts; nothing else.
3. **`CCountry +0x590` and `+0x594`.** One reader each, no writer found by a complete byte scan of
   `.text` with a positive control. If they are really always zero the shortage factor is a
   constant 1.5 and one term of the brigade demand is a constant 0. `dumpStruct.py` on a
   `CCountry` settles it in one look, and it is the single cheapest check in this file.
4. **`CMapProvince +0x5C`.** The role is read precisely; the identity is not. Its one writer is
   `CProvince::LoadKey`'s building arm, gated on building definition `+0x24 == 12`, and which
   building that is cannot be counted off the mod's reordered `buildings.txt`.
5. **`CMapProvince +0x304`** — which building it points at.
6. **`CArmy +0x2FC`**, the role enum. Values 3, 4 and 8 are all that the branches show.
7. **`CAIUnit +0x364`**, which switches the whole reserve mechanism on, and **`+0x86`**, which
   asks for a slot-78 pass: both are read here and neither has a writer in any body read.
8. **`0x8CD890` and `0x8D0880`**, 19 KB between them, read as extents, gates, callers and call
   lists. Their names in `project.json` are `inferred` and should be treated as placeholders.
9. **`CSendExpeditionCommand::Execute`'s not-equal arm**, `0x5E97A2` onward.
10. **Nothing was watched in a running game.** Five cheap checks, in order of value:
    - `CCountry +0x590`/`+0x594` on any country — item 3, and it decides whether half of
      `0x8B60F0`'s arithmetic is live.
    - `CUnitPlan our_power`/`their_power` on an **AI** country's theatre unit. They should be
      non-zero, because `CAIUnit::UpdatePlanPower` maintains them for everybody; if they are zero
      for AI countries and non-zero only for the player's, then `0x8B5060` is not running as read
      and the whole commitment ladder is driven off stale numbers.
    - `CAIUnit +0x35C`/`+0x360` against the plan's `+0x27C`/`+0x280` on the same agent: they should
      agree to within a thousandth, because that is exactly the test `0x8B5060` makes.
    - `CMapProvince +0x5C / 1000` against the province panel, to settle item 4.
    - A division sitting in a level-N land fort under a defensive stance should contribute
      `(1 + 0.08 N)` times its bare power; the bare power is computable from the savegame, which is
      plain text and holds `strength`, `organisation` and `type` for every regiment.
