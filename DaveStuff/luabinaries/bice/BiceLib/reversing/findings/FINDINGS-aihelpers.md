# The AI's own combat modifier model: `0x4D8C50` and `0x4D8590`

rva `0x4D8C50` (attack side) and rva `0x4D8590` (defence side), the two helpers
`FINDINGS-attackodds.md` §10 named as "the next thing to read in this area". Both read end
to end 2026-10-02, by decoding from the entry and taking the block graph off
`scripts/cfg.py`.

The short answer: **`FINDINGS-attackodds.md` §10's guess was right.** The AI does not ask the
combat module what a battle's modifiers would be. It recomputes them, in its own code, from
the same defines and the same unit fields — and then **adds** the fractions where the combat
module multiplies clamped factors. Of the 20 live land modifier ids it reproduces 11 term for
term, 4 partially, omits 6, and applies one with the sign reversed.

## 1. Extent, convention, and the two names

| | `0x4D8C50` — attack side | `0x4D8590` — defence side |
| --- | --- | --- |
| extent | `0x4D8C50`–`0x4D93A6`, 0x757 bytes | `0x4D8590`–`0x4D8C49`, 0x6BA bytes |
| instructions / blocks | 533 / 61 | 499 / 47 |
| exit | one **bare** `ret` | one **bare** `ret` |
| receiver | **ECX** | **EAX** (`mov esi,eax` at `0x4D8598`) |
| arguments | `target province`, `ownBrigades`, `ownProvinceCount` | `ownBrigades − 3·enemyProvinces`, `enemyProvinceCount` |
| caller cleans | 0xC | 8 |
| answer in | **XMM0** | **XMM0** |
| SEH frame | yes | no |
| callers | one, `0x4D95A1` | one, `0x4D9A2D` |
| cache | `CUnit +0x2DC` / dirty `+0x2E0` | `CUnit +0x2D4` / dirty `+0x2D8` |

Both extents are settled, not guessed: `image.retsBefore` returns exactly one `ret` in each
body, each is followed by an `int3` run (6 and 9 bytes), and `cfg.py --lands-in` over the
padding reports nothing branching into it — so trap 3 does not apply to either.

`vtable.py --holding` puts neither in any virtual table, and `image.findBytes` finds neither
address as a value anywhere in `.text`, `.rdata` or `.data`. **One direct caller each, both
inside `CAIUnit::EstimateAttackOdds`, and nothing else can reach them.** That is what makes
the argument readings safe.

**No ordinary convention describes either.** A receiver in EAX, an answer in XMM0 and a
caller that cleans the stack are three separate departures from anything MSVC emits for a
declared function; this is LTCG giving a private helper a convention of its own, exactly as
`project.json` already records for `LandAttackOddsThresholdForStance` and
`CUnit::MeanDistanceToProvince`. So the signatures place every parameter explicitly and spell
the convention `__cdecl` because the caller cleans:

    float __cdecl AICombatEstimateAttackValue(CUnit* unit@ECX, CMapProvince* target@stack:4,
                                              int ownBrigades@stack:8, int ownProvinceCount@stack:0xC)
    float __cdecl AICombatEstimateDefenceValue(CUnit* unit@EAX,
                                              int brigadesLessThreeEnemyProvinces@stack:4,
                                              int enemyProvinceCount@stack:8)

**The names.** `this` is a `CUnit`, not a `CAIUnit`: the fields reached through it are
`+0x2D4`/`+0x2D8`/`+0x2DC`/`+0x2E0` (already recorded as this pair's own caches), `+0xC8`
`CSubUnitDefinitionPtr`, `+0x12C` `leader_ptr`, `+0x130` `current_province_ptr`, `+0x1C8`
`dig_in_level`, `+0x1CC` `base_ca_bonus`, `+0x1F4` `oob_level`, `+0x1E0`
`higher_oob_unit_ptr`, `+0xFC` `supply_received_percentage`, `+0x124`/`+0x128`/`+0x28C`/`+0x290`
the owner pair and the expeditionary pair, and a virtual call through `[[esi]+0x58]` which is
`CUnit` slot 22. **But they sit in the AI's code**, interleaved with
`CAIUnit_ManageLandUnits` (`0x4D57F0`) and `CAIUnit::EstimateAttackOdds` (`0x4D93B0`), which is
where MSVC puts functions from one translation unit. So they are the AI's helpers over a
`CUnit`, not `CUnit` methods, and by trap 11 a class qualifier would be a claim the placement
contradicts. Hence `AICombatEstimateAttackValue` / `AICombatEstimateDefenceValue` — unqualified,
and matching the `ai_combat_estimate_attack` / `ai_combat_estimate_defence` field names the
last wave landed.

The SEH frame on `0x4D8C50` is not about exceptions in the arithmetic: its last block **inlines
`GetDefines`**, with `operator new`, `CDefines::CDefines` (rva `0x452E0`) and a slot-0 destructor
call on the lazy-construct path at `0x4D92D9`–`0x4D9320`. That is trap 8 case 1 happening inside a
function that also calls `GetDefines` properly six times.

## 2. The formulas

Every term is computed in 64-bit integer thousandths through `__allmul`/`__alldiv`, converted to
float and divided by `1000.0` (the double at `0x160A300`), and **added into a float accumulator**.
`country` is `unit->expeditionary_owner_id ? GetCountry(&unit->expeditionary_owner) :
GetCountry(&unit->owner)` in both — the combat module's own rule. `trait(n)` is
`CUnit::CommandEffect(unit, &out, n)`.

### `0x4D8C50`, attack side

Cached half (returned from `+0x2DC` when `+0x2E0` is clear; recomputed and written at `0x4D8FC2`):

```
v  = (base_ca_bonus + SumCombinedArmsGroupTech(owner, &out, unit) + trait(9 combined_arms_bonus))/1000
                                                                   ; only if base_ca_bonus > 0
v += slot22()/100 * (1000 + trait(23 experience_bonus))/1000 / 1000
v += (leader->skill * COMBAT_LEADER_IMPACT/1000 + trait(4 offence_modifier))/1000
                                                                   ; only if LeaderHasRankForCommand && skill > 0
v -= dissent * 10/1000 * COMBAT_DISSENT_IMPACT/1000 * (1000 + trait(20 dissent_impact))/1000 / 1000
v -= COMBAT_SUPPLY_LACK_IMPACT * (1000 - supply_received_percentage)/1000
                              * (1000 + trait(10 out_of_supply_modifier))/1000 / 1000
v += GetDifficultyCombatModifier(country)/1000
```

Uncached half:

```
n   = ownBrigades - 3*ownProvinceCount
f   = 1000;  for i in 1 .. min(n-1, 99):  f = f * (1000 + BASE_STACKING_PENALTY)/1000
raw = 1000 - f - country->technology_status->free_stacking_allowance
walk up higher_oob_unit_ptr to the unit whose oob_level is 0; if found
    raw -= floorf((thatLeader->skill + 0.0005)*1000) * 10 / 1000
if raw > 0: v -= raw/1000
v -= CWeather::LandCombatEffect(&target->weather, &out, unit->owner)/1000
find the ProvinceEdge from unit->current_province_ptr to target->id:
    kind 2 -> e = RIVER_CROSSING_PENALTY + def->river.attack + trait(7 river_attack)
              if e < 0:  v += e/1000                                      ; 0x4D9201, addsd
    kind 1 -> amph = true
              e = AMPHIBIOUS_LANDING_PENALTY + def->amphibious.attack + trait(25 amph_attack)
              if e < 0:  v -= e/1000                                      ; 0x4D9270, subsd
v += (target->template->terrain->attack + def->terrain_adjusters[terrainId].attack)/1000
v += (target->modifiers[amph ? 11 COASTAL_FORT_LEVEL : 10 FORT_LEVEL]/1000*1000)
       * BASE_FORT_PENALTY/1000 / 1000
```

### `0x4D8590`, defence side

Cached half (returned from `+0x2D4` when `+0x2D8` is clear; recomputed and written at `0x4D8A88`):

```
v  = trait(24 fort_defence)/1000                                         ; the seed, unconditional
v += (base_ca_bonus + SumCombinedArmsGroupTech + trait(9 combined_arms_bonus))/1000
v += slot22()/100 * (1000 + trait(23 experience_bonus))/1000 / 1000
v += (leader->skill * COMBAT_LEADER_IMPACT/1000 + trait(3 defence_modifier))/1000
v += dig_in_level * DIG_IN_FACTOR/1000 * (1000 + trait(26 digin_bonus))/1000 / 1000
v += (prov->template->terrain->defence + def->terrain_adjusters[terrainId].defence)/1000
v -= dissent * 10/1000 * COMBAT_DISSENT_IMPACT/1000 * (1000 + trait(20 dissent_impact))/1000 / 1000
v -= COMBAT_SUPPLY_LACK_IMPACT * (1000 - supply_received_percentage)/1000
                              * (1000 + trait(10 out_of_supply_modifier))/1000 / 1000
v += GetDifficultyCombatModifier(country)/1000
if prov->area->IsValid() and ProvinceIsEncircled(prov, &unit->owner):
    e = ENCIRCLED_PENALTY * (1000 + trait(21 encirclement_bonus))/1000
    if e < 0: e = 0;  v -= e/1000
```

Uncached half:

```
n   = min(arg1, 100)                                                     ; the clamp at 0x4D8A93
f   = 1000;  repeat n-1 times:  f = f * (1000 + BASE_STACKING_PENALTY)/1000
raw = 1000 - f - country->technology_status->free_stacking_allowance
walk up higher_oob_unit_ptr to oob_level 0; if found
    raw -= floorf((thatLeader->skill + 0.0005)*1000) * 10 / 1000
if raw > 0: v -= raw/1000
if enemyProvinceCount > 2 and !CProvinceTemplate::IsIsolatedLand(prov->template):
    e = (enemyProvinceCount - 2)*1000 * ENVELOPMENT_PENALTY/1000
          * (1000 + trait(22 envelopment_bonus))/1000
    if e < 0: e = 0;  v -= e/1000
```

The `10` in three places is **not** a define: it is a fifth `(int)floorf(10.5f)` static, at rva
`0x17151FC`, written by its own `.CRT$XCU` initialiser at rva `0x911780` off the **same** float
literal `10.5` (rva `0x120A680`) that `InitDefine10` uses. `image.findBytes` of the address returns
exactly five hits — the four reads in these two functions and the one store. Recorded as
`k_thousandths_10_ai`, joining `k_thousandths_10`, `g_CombatModifierFloor`, `g_IneffectiveStrength`
and `Define10`. **No `defines.lua` entry can move it.**

The division is split the way the cache key in `FINDINGS-attackodds.md` §5 requires: everything
that depends on the unit alone is cached, everything that depends on the arguments is not. The
defence helper's uncached half is exactly the two terms that read our side's numbers — which is why
`+0x18` of the caller's cache (the distinct-province count) is the only key it needs.

## 3. The agree/disagree table

Against `CLandCombatant::ApplyCombatModifiers` (`0x169B50`) plus slot 20
(`CCombatant::AddTerrainModifier`) and slot 27 (`AddAssaultModifiers`), as
`FINDINGS-combatmods.md` §5 has them:

| id | modifier | side in battle | AI attack helper | AI defence helper |
| --- | --- | --- | --- | --- |
| 0x00 | BM_DISSENT | both | **identical** | **identical** |
| 0x01 | BM_LEADER_BONUS | both | partial — no `terrain_attack` trait (`0x5D0F80` kind 29) | partial — no `terrain_defence` trait (kind 30) **and no `MODIFIER_LEADER_DEFENCE`** |
| 0x02 | BM_DIFFICULTY | both | **identical** (same `0x4DF9B0`) | **identical** |
| 0x03 | BM_ENCIRCLEMENT_PENALTY | defender | n/a | **identical** formula; gate is `area->IsValid()` where the battle uses `template->is_land` |
| 0x04 | BM_ENVELOPMENT_PENALTY | defender | n/a | **identical** |
| 0x05 | BM_DIVISION_PENALTY (stacking) | both | **identical**, same loop shape | **identical** |
| 0x06 | BM_EXPERIENCE | both | **identical** | **identical** |
| 0x07 | BM_MISSION_EFFICIENCY | both | **absent** | **absent** |
| 0x08 | BM_TERRITORIAL_PRIDE | both | **absent** | **absent** |
| 0x0A | BM_DUGIN_MODIFIER | defender | n/a | **identical** |
| 0x0B | BM_AMPH_PENALTY | attacker | **sign reversed**, and stripped of the landing-craft interpolation, the naval-base test, the `max(v,-990)` floor, the REB case and the own-province-is-water case | n/a |
| 0x0C | BM_FORT_MODIFIER | both | partial — `level × BASE_FORT_PENALTY` only; no `trait(8 fort_attack)`, no `def->fort.attack`, no `if v > 0: v = 0` | partial — the `fort_defence` trait, but **with no fort-level gate** |
| 0x0D | BM_PARATROOP_PENALTY | attacker | **absent** | n/a |
| 0x0E | BM_RIVER_PENALTY | attacker | **identical** | n/a |
| 0x0F | BM_SHORE_BOMBARD | both | **absent** | **absent** |
| 0x10 | BM_LACK_OF_SUPPLIES | both | identical minus the `!unit->+0x97` paradrop gate | same |
| 0x11 | BM_MULTIPLE | defender | n/a | **absent** — `EstimateAttackOdds`'s own engagement term covers "busy elsewhere" its own way |
| 0x12 | BM_COMBINED_ARMS | both | **identical** | **identical** |
| 0x19 | BM_TERRAIN | both | **identical**, off the target province's terrain | **identical**, off the unit's own province |
| 0x1A | BM_WEATHER | both | **identical** — the same `CWeather::LandCombatEffect` | **absent** |
| 0x1B | BM_NIGHT_MODIFIER | both | **absent** | **absent** |

`0x13 BM_ARMOR_ADVANTAGE` and `0x1C BM_SURPRISE_PENALTY` never become modifier entries at all, so
their absence here says nothing. The rest of the ids are naval, air or bombing.

**11 identical, 4 partial, 6 absent, 1 sign-reversed.** And one asymmetry inside the AI itself:
the attack helper reads the weather and the defence helper does not, so the AI docks its own
attackers for rain and gives the defenders a free pass.

### Which defines each model reads

The AI reads ten `military` defines directly — `COMBAT_LEADER_IMPACT`, `COMBAT_DISSENT_IMPACT`,
`COMBAT_SUPPLY_LACK_IMPACT`, `BASE_STACKING_PENALTY`, `DIG_IN_FACTOR`, `ENCIRCLED_PENALTY`,
`ENVELOPMENT_PENALTY`, `RIVER_CROSSING_PENALTY`, `AMPHIBIOUS_LANDING_PENALTY`,
`BASE_FORT_PENALTY` — plus `COMBAT_DIFFICULTY_IMPACT` through `GetDifficultyCombatModifier` and
the `LAND*` weather defines through `CWeather::LandCombatEffect`. Every one of those it reads with
the same formula the battle uses, so those stay in step.

**These the battle reads and the AI does not:**

| define | what it moves in battle | what it moves in the AI's decision |
| --- | --- | --- |
| `MULTIPLE_COMBATS_PENALTY` | a defender already in >1 combat | nothing |
| `PARADROP_PENALTY` | a paradropping attacker | nothing |
| `BASE_NIGHT_PENALTY` | both sides at night | nothing |
| `SHORE_BOMBARDMENT_MOD`, `SHORE_BOMBARDMENT_CAP` | both sides, from enemy fleets offshore | nothing |
| `AMPHIBIOUS_INVADE_LANDING_PENALTY_DECREASE` | how far landing-craft tech cancels the amphibious penalty | nothing |

So **tuning any of those six changes what happens in a battle and does not change the AI's decision
to start one.** That is the fact a mod author wants and nobody had.

### Two concrete disagreements, in BlackICE's own numbers

Taken from `units/armor_brigade.txt` (`river.attack = -0.5`, `amphibious.attack = -1.1`,
`fort.attack = 0.55`) and `common/defines.lua`:

- **A three-brigade armour division attacking a level-3 fort.** The battle computes
  `3000 × (−0.23) + 3×550 = +960`, clamps it to 0 by `if v > 0: v = 0`, and adds **nothing**. The AI
  computes `3000 × (−0.23) = −690` and docks the estimate **−0.69** — because it omits
  `def->fort.attack` and therefore never reaches the clamp. *The AI believes in a fort penalty the
  battle will not charge it.*
- **A three-brigade armour amphibious landing.** `e = −0.7 + 3×(−1.1) = −4.0`. The battle adds
  `−4.0` (before the landing-craft interpolation and the `−990` floor). The AI, through the `subsd`
  at `0x4D9270`, adds **+4.0** — four times the entire maximum of the engagement term it is added
  to. *The sign bug makes an opposed amphibious landing the single most attractive move in the AI's
  model.*

### The sign bug, on the bytes

Both arms of the same `if`/`else`, both reached only when `e < 0` (`jns` at `0x4D91D9` and
`0x4D924C`):

```
0x4D9201   f2 0f 58 c1   addsd  xmm0, xmm1      ; river:       v = e/1000 + v
0x4D9270   f2 0f 5c c1   subsd  xmm0, xmm1      ; amphibious:  v = v - e/1000
```

Read off `disasm.py --bytes`, not off a mnemonic. The only alternative reading — that `e` is
positive on the amphibious arm — is forbidden by the `jns` two instructions earlier.

### The structural difference, which is bigger than any single row

`CUnit::AddCombatModifier` turns each value into a **multiplicative** factor:
`attackProduct = attackProduct × max(value + 1000, 10)/1000`. The AI **adds** the same fractions.
Two +50% modifiers give ×2.25 in the battle's product and +1.0 in the AI's sum; a −100% modifier
takes the product to its 1% floor and takes the AI's sum down by 1.0 with no floor at all. The two
models are the same list of formulas combined by different algebra, and only the formulas agree.

For honesty about what the product then does: `FINDINGS-slot11.md` §4 and `FINDINGS-combat3.md` §3
establish that `CUnit +0xEC`/`+0xF0` are read by `CCombatant` slot 11 (the `combat_status`
billboard) and by this AI estimator, and that the modifiers reach the *shot counts* by other routes.
So the claim here is about **the modifier model**, not about who wins the fight.

## 4. Garnish or dominant? Dominant.

`EstimateAttackOdds` computes, per unit,
`weight = strengthFraction × orgFraction × (engagement + helper(u))`, with `addsd xmm0, xmm1` at
`0x4D95BF` (ours) and `0x4D9A4B` (theirs). **There is no clamp anywhere.** A `grep` for
`maxss|minss|maxsd|minsd` over the full 0xA7B-byte disassembly of `0x4D93B0` finds none, and its
only three float comparisons are the `0.5f` squaring bar (`0x4D9565`), the recursion's `== 0` test
(`0x4D99F7`) and the `theirDamage <= 0` exit (`0x4D9D7B`) — all three already accounted for in
`FINDINGS-attackodds.md`.

`engagement` is seeded `1.0f` (the float at `0x171DBAC`) and every factor applied to it is in
`(0, 1]`, so **`engagement ∈ (0, 1]`**. Against that ceiling, single helper terms at BlackICE's
values:

| term | magnitude |
| --- | --- |
| experience, at 100 experience | **+1.00** — exactly the whole maximum of `engagement` |
| experience, at 30 | +0.30 |
| leader, skill 5 | `5 × 0.06` = +0.30 |
| stacking, 24 brigades from 1 province | `1 − 0.975²⁰` = **−0.40** |
| fort, level 5 (AI's partial formula) | `5 × −0.23` = **−1.15** |
| river, 3-brigade armour | `−0.8 + 3×(−0.5)` = **−2.30** |
| amphibious, 3-brigade armour (wrong sign) | **+4.00** |
| envelopment, 5 directions | `3 × 0.2` = −0.60 |
| encirclement | −0.50 |
| dissent 10% | −0.15 |
| supply at 50% | −0.175 |

So the helper is the **dominant** term for any unit that is not pinned in another combat, which is
every candidate the AI actually evaluates (`engagement` only falls below 1.0 when the unit is
already in a fight). Two consequences follow arithmetically:

1. **`engagement + helper` can go negative, so a unit can contribute negatively to our own
   `A` and `B` sums.** A fresh 12-brigade division at 30 experience under a skill-3 leader,
   crossing a river into a level-3 fort: `0.30 + 0.18 − 0.24 − 0.69 − 2.30 ≈ −2.75`. At full
   strength and organisation its weight is `−2.75`. Adding it *lowers* our modelled damage. The AI
   is protected from committing such a unit only by the caller: `CAIUnit_ManageLandUnits` compares
   the new figure against the old at `0x4D78EE` and backs the unit out — `FINDINGS-attackodds.md`
   §8's point, which this strengthens.
2. **It is not protected from the other direction.** If every defender's helper is below
   `−engagement`, `A_theirs` and `B_theirs` go negative, `theirDamage ≤ 0`, and the function takes
   its `50.0f` exit at `0x4D9D7E` — far above every bar the caller tests (3.0 / 4.0 / 5.0 by stance,
   `LandAttackOddsThresholdForStance`). **A heavily stacked, enveloped, encircled defender reads as a
   free attack**, by the same route "no defenders at all" does.

**The integer-vs-double asymmetry does not bear on this.** Inside both helpers the arithmetic is
*identical*: 64-bit integer thousandths through `__allmul`/`__alldiv`, converted and divided by
`1000.0` as a double, accumulated in a float. The asymmetry `FINDINGS-attackodds.md` §3 found is
only in `EstimateAttackOdds`'s own strength/organisation scaling — ours truncates
`strength × 1000 / 100000` to an integer (0.1% granularity of the 0..1 fraction, via the
`0x14F8B589` magic at `0x4D95EA`), theirs divides by `1000.0` then by `100.0` in doubles at
`0x4D9A74`/`0x4D9A84`. Worst case that moves a unit's weight by `0.001 × (engagement + helper)` —
three orders of magnitude below the helper terms above. It **cannot** change the answer to this
question, and the record should say so rather than leaving it as an open asymmetry of unknown size.

## 5. The two helpers' other callees, named

`SumCombinedArmsGroupTech` (rva `0x1B6740`, `ret 4`, receiver in ECX, out in EAX, unit on the
stack) resolves `g_CCountryDataBase->+0x16C[owner->id]` and sums
`country->technology_status->+0x5C[g]` over every combined-arms group `g` set in
`unit->subunit_group_present_begin`. It is the middle term of `CUnit::GetCombinedArmsBonus`
(`0x1B6240`) — which inlines the same loop rather than calling this, so the two are duplicates.
**Exactly two callers, both these helpers.**

`ProvinceIsEncircled` (rva `0xA6850`, `ret 4`, province in EDI, tag on the stack, 0xC1 bytes) is
read through for the first time. `project.json` called it "not read through" with "the province is
encircled for this owner" as a reading of its use; the body supports the reading:

```
if (!province->area->IsValid())                                   return false
if (province->area->+0x2C >= 2)                                   return false
if (CProvinceTemplate::IsIsolatedLand(province->path_node_ptr))   return false
for each neighbouring area a in province->area->+0x34:
    controller = a->+0x2C ? a->provinces[0]->controller : "---"
    if (CCountry::IsFriendly(g_CCountryDataBase->+0x16C[controllerId], owner, 1)) return false
return true
```

So **"encircled" means a one-province owner area that is not an all-water-bordered island and has
no friendly neighbouring area.** The `+0x2C >= 2` test is the load-bearing one and explains why
`ENCIRCLED_PENALTY` is rare: it needs the pocket to be its own `COwnerArea`. Two `ret 4`s, at
`0xA6872` and `0xA690E`; the first is the shared false path three jumps and a fall-through reach,
so trap 3 does not apply. `COwnerArea` has no struct in `project.json`, so `+0x24`/`+0x2C`/`+0x34`
cannot be recorded — they are from `FINDINGS-aitheatre.md` and `FINDINGS-aiplans.md`, which read
them independently.

Also settled for free: `COwnerArea` slot 0 is `ReturnTrue` (rva `0x692590`) and `CNullOwnerArea`
slot 0 is `ReturnFalse` (rva `0x192360`), so `area->IsValid()` is literally "the area is not the
null object". Both are folded stubs and must not be named for either class (trap 4).

## 6. Frontier

| rva | what | why it is open |
| --- | --- | --- |
| `0x1C6400` | `CUnit` slot 22, called by both helpers through `[[esi]+0x58]` | almost certainly `CUnit::GetAverageExperience` — it is the sibling of the already-named slots 20 and 21, it walks `this->+0x38` reading `[subunit+0x3C]` with a `jns` clamp at zero, and it touches `g_CDefines` where `PRIDE_BONUS_EXP` would be, which is `FINDINGS-combatmods.md` §6's naval experience formula. **Only its first thirty instructions were read**, so it is listed rather than named. Naming it also means recording the slot for `CUnit`, `CArmy`, `CNavy` and `CAir`. |
| `0x452E0` | `CDefines::CDefines`, reached only from the inlined `GetDefines` in `0x4D8C50` | never recorded; the recorded `GetDefines` (`0x45D90`) calls it |

Everything else either helper calls is already named: `__alldiv` (`0x799980`), `__allmul`
(`0x799AF0`), `CUnit::CommandEffect` (`0x1D1120`), `GetDefines` (`0x45D90`),
`CUnit::LeaderHasRankForCommand` (`0x1CD960`), `GetDifficultyCombatModifier` (`0xDF9B0`),
`CCountryTag::GetCountry` (`0x2610`), `floorf` (`0x1FD0`), `_ftol2_sse` (`0x808870`),
`operator_new` (`0x79602F`), `CWeather::LandCombatEffect` (`0xB4000`, attack side only),
`CProvinceTemplate::IsIsolatedLand` (`0xA9BE0`, defence side only).

**Every field access resolves to a named field.** `CUnit` +0x40, +0xC8, +0xFC, +0x124, +0x128,
+0x12C, +0x130, +0x1C8, +0x1CC, +0x1D0/+0x1D4, +0x1E0, +0x1F4, +0x28C, +0x290, +0x2D4–+0x2E0;
`CCountry` +0xCA4, +0xDF8, +0x10B4; `CTechnologyStatus` +0x6C; `CLeader` +0x70; `CMapProvince`
+0x68, +0xD0, +0xD4, +0x114, +0x2B4; `CProvinceTemplate` +0xC, +0x90, +0x94; `CTerrain` +0x8,
+0x4C, +0x50; `CSubUnitDefinition` +0x54 and the `river`/`amphibious` `CUnitAdjuster` blocks at
+0x94/+0xAC (so +0x9C and +0xB4 are their `attack` members); `CUnitAdjuster` +0x8/+0xC;
`ProvinceEdge` +0x0/+0x4; `CDefines` +0xAC and seven `military` offsets. **Nothing unnamed.**

## 7. What was found wrong in the record

**1. `FINDINGS-attackodds.md` §10, and the brief written from it, say "Both reach … `0x1D1120`,
`0xDF9B0`, `0x1CD960`, `CProvinceTemplate::IsIsolatedLand` (`0xA9BE0`) and the unnamed encirclement
helper at `0xA6850`." Only the defence helper reaches the last two.** A call-target census of each
body:

| callee | `0x4D8590` | `0x4D8C50` |
| --- | --- | --- |
| `0xA9BE0 IsIsolatedLand` | 1 | **0** |
| `0xA6850` encirclement | 1 | **0** |
| `0xB4000 CWeather::LandCombatEffect` | **0** | 1 |
| `0x452E0 CDefines::CDefines` + `operator_new` | **0** | 1 each |
| `0x1B6740 SumCombinedArmsGroupTech` | 1 | 1 — *not mentioned in §10 at all* |

The four §10 names that really are shared are `GetDefines()+0xAC`, `CommandEffect`,
`GetDifficultyCombatModifier` and `LeaderHasRankForCommand`. This matters because the two
absences are exactly the per-side asymmetry: encirclement and islands are defender-only concepts
and the weather is, in the AI, attacker-only.

**2. `FINDINGS-combatmods.md` §5's `BM_DIVISION_PENALTY` says `n = … − 3 × (distinct provinces the
enemy attacks from)`. That is right for the defender and wrong for the attacker, and the bytes
say so plainly.** The directions array is built at VA `0x56A024` (rva `0x16A024`) behind a split on
`this->is_attacker` (`CCombatant +0x38`), with `ebx = this` set at VA `0x569B77` and `[ebp+8] = other`:

```
0x56A024  mov al, byte ptr [ebx + 0x38]      ; is_attacker
0x56A027  test al, al
0x56A029  jne 0x56A0CD                       ; attacker  -> walks [ebx+0x40], ITS OWN units
0x56A02F  mov ecx, dword ptr [ebp + 8]       ; defender  -> walks the OTHER combatant's units
0x56A032  mov edi, dword ptr [ecx + 0x40]
```

The invariant that holds on both sides is **"the number of provinces the attack comes from"** — the
attacker's own provinces are the attack's directions, and so are the attacker's provinces as the
defender sees them. Read literally, the published rule would make the attacker's exponent fall by 3
for the single province the defenders stand in, which is a different number, and the AI's attack-side
`ownBrigades − 3 × ownProvinceCount` would then **disagree** with the battle. It agrees. So this is
the one correction that changes a conclusion in this file rather than just a sentence.
(`BM_ENVELOPMENT_PENALTY`'s description is unaffected: that one is defender-only, so the array really
is the enemy's there.)

**3. `CUnit +0x2D4` and `+0x2DC` both end "not from the helper's body, which was not read."** Read
now. The fragment revises both comments to say what the cached float holds and, more usefully,
*which* modifiers are in the cache and which are not — because the split is the thing a reader of
those fields needs.

**4. `CDefines +0xAC` is recorded as `supply_defines_ptr`, typed `CDefinesSupply*`.** It is the
**military** block: `scripts/definesMap.py --check` prints `military  CDefines+0xAC
MAX_MANPOWER..NEW_LEADER_ORG_HIT  179 entries  CDefinesSupply`, and the struct's 178 recorded fields
carry the military names. The pointer and the field names are right; the field's own name and the
struct's name misdescribe the block, presumably from having first been found through
`SUPPLYPOOL_DAYS` (`+0x3C`) and `SUPPLY_TAX` (`+0x34`). All ten defines these two helpers read come
through it. Not revised here — renaming a struct is a bigger change than one fragment should make —
but `definesMap.py --check` has been printing the disagreement all along, which is the argument for
running it.

## 8. What is not established

- **Nothing live.** No hook on either return value, so the magnitudes in §4 are arithmetic from the
  mod's own `defines.lua` and `units/*.txt`, not observation. One `movss` watch on `CUnit +0x2DC`
  over one attack decision would settle §4 and the sign bug together: a division ordered onto an
  opposed landing should show its estimate *rise*.
- **Whether the `+0x2D4`/`+0x2DC` caches survive a save/load**, inherited unchanged from
  `FINDINGS-attackodds.md`. Both are floats with no save key in the record, so they are presumably
  zero after a load until `CUnit::CheckOrderAndCombat` next runs — and since `+0x2D8`/`+0x2E0` would
  also be zero, a zero *clean* cache would be *used*, not recomputed. That is a guess about the
  loader, which was not read, and it is the one place a stale cache could be visible.
- **`CUnit` slot 22's body**, read only as far as its first thirty instructions (frontier).
- **Whether the amphibious sign is a bug or an intent not visible here.** What can be said is that
  the two arms of one `if`/`else` differ by one opcode byte, that both are guarded identically, and
  that the battle's own arm for the same modifier subtracts. Three reasons to call it a bug and no
  reading of the bytes that makes it deliberate — but no AI amphibious decision was watched.
- **`COwnerArea`'s layout**, which `ProvinceIsEncircled` depends on and which no struct records.

## Confidence

`confirmed`, in the sense a machine could check: both extents (`retsBefore`, the `int3` runs,
`cfg.py --lands-in`); both conventions (the single call site each, `vtable.py --holding`,
`findBytes` over all three sections); the return register (the caller's first use is a `cvtss2sd`
on XMM0 with no load between); every define offset (against `definesMap.py --block military`);
every field name (all already recorded); every trait kind (against `FINDINGS-combatmods.md` §4's
settled table); the sign bug (opcode bytes); the absence of any clamp (a `maxss|minss` grep over
the whole caller); the 10-static's five references and its initialiser; §7.1's call-target census
and §7.2's `is_attacker` split.

`inferred` — in the fragment, because the validator has no third word — that the names
`AICombatEstimateAttackValue` / `AICombatEstimateDefenceValue` are the right ones rather than
`CUnit::`-qualified; and the practical readings in §4.1 and §4.2 about what the unclamped sum does to
the AI's behaviour, which are arithmetic from the formulas and not watched.

Not claimed: anything about `CUnit` slot 22's body, the loader, or how often
`CUnit::CheckOrderAndCombat` runs.

---

## Transcription note

Read and written by wave 10's agent A; transcribed by the session that collected the wave, because
an agent's `Write` is refused for this path. Spot-checked independently before transcription, all
confirming: the sign asymmetry at the opcode level (`f2 0f 58 c1` against `f2 0f 5c c1`, both arms
guarded by a `jns` to the same join at VA `0x8D927A`); the absence of any `maxss`/`minss`/`maxsd`/
`minsd` in the whole 0xA7B bytes of `EstimateAttackOdds`; the `is_attacker` split in §7.2; and the
five references to the `10` static.

One presentational fix made in transcription: §7.2 originally gave `0x56A024` and `0x569B77` as
rvas, in a file whose rule is that addresses are rvas. They are **virtual** addresses (rva
`0x16A024` and `0x169B77`), as the `0x169B50` in the same sentence makes clear. Trap 1, in a file
that otherwise observes it carefully — the instruction addresses were quoted straight out of a
disassembly listing into prose written in rvas, which is exactly how this one keeps happening.
