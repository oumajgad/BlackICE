# Air phase 4's mission assignment, and the naval body's convoy raid and rebase block

Read statically off `hoi3_tfh.exe` on 2026-10-02 with the game not running. Addresses are
**virtual**, based at `0x400000`, with the rva beside them wherever a finding names one. This
file extends `findings/FINDINGS-reorganise.md` and closes four of its eleven open items.

> **CORRECTED 2026-10-02 by `findings/FINDINGS-airstance.md`.** The gating below is read correctly;
> **the conclusion drawn from it is wrong.** `CEU3AI::UpdateUnitStances` (rva `0x4912D0`) posts
> `CSetPlanAttributesCommand(unit, 5, 2, 2, -1000, -1000)` on **every** AI unit agent, **every**
> `ProcessAI` pass, so stance 2 is the steady state and **all seven missions are live**. The live
> distribution quoted here - stance 1 on 1,125 of 1,126 air formations - was read off the wrong class
> of object: the gate at `0x4CF902` reads `agent->unit (+0x64)`, the **army or theatre HQ**, and this
> file's own note recorded **2 on all 101 of the armies attached to an agent** before setting them
> aside as a biased subsample. They were the population the gate reads.
>
> Worse, the fact was **already in `project.json`**: the entry for `CEU3AI::UpdateUnitStances` has
> said since `FINDINGS-aiplans.md` that it builds that command "with (unit, 5, 2, 2, -1000, -1000) -
> stance left alone, air and naval stance both set to 2". Read the corrected account before using
> anything in section 1 of this file.

**In one line.** Phase 4 of the air body is **gated into two halves by `plan_air_stance`, and
only stance 2 reaches five of its seven missions** - so on the recorded live distribution the
AI's air force flies close air support and interception and nothing else. *(Not so - see the
correction above. The gating is right; "nothing else" is not.)* The naval body's
single random draw is a **roulette-wheel pick of a convoy-route province for a submarine
wolfpack**, weighted by the convoy's tonnage times the distance from the route's midpoint. And
`0x4A7450`/`0x4A74D0` are **sunset and sunrise, in that order** - which inverts a conclusion in
`findings/FINDINGS-theatre2.md`.

## The one instruction that matters most

```
0x008CF902  mov     edx, dword ptr [ebp + 8]
0x008CF905  mov     eax, dword ptr [edx + 0x64]      ; agent->unit
0x008CF908  cmp     dword ptr [eax + 0x20c], 2       ; plan_air_stance
0x008CF90F  je      0x8cf9fb                         ; -> the strategic and naval arm
0x008CF915  ...                                      ; -> free everything and return
```

There are exactly two edges out of it. So phase 4 has **two arms, not three**:

| `plan_air_stance` | what phase 4 does |
| --- | --- |
| 0 | nothing - the gate at `0x8CEE6E` returns through the epilogue before any pool is built |
| **1** (and 3, the "not set" sentinel) | `ground_attack` and `air_intercept` **only** |
| 2 | those two, **then** `logistical_strike`, `strategic_bomb`/`nuke_mission` and `naval_strike`/`port_strike` |

`CUnit +0x20C`'s own record carries the live distribution: **1 on 1,125 of 1,126 air formations**
in a 1942 German save. On that evidence the five strategic and naval air missions are not reached
in a normal game. That is the single most consequential thing in 5.7 KB of code, and it is three
instructions. It is also the exact opposite of what the brief carried in: the live stance is 1,
and stance 1 is the *restricted* arm, not the full-threshold one. The "halved thresholds at stance
2" reading is about **phase 1**'s fitness test (`0x8CD9B5`), a different decision in a different
phase; stance 2 both loosens the fitness bar and unlocks the strategic missions, which is coherent
once the two are kept apart.

I did not watch this running. The claim about what a real game does rests on the recorded live
stance distribution, not on bytes.

## The pools, and a correction to the published block map

Phase 4 opens at `0x8CEE76` by zeroing four `CList`s on the stack - `{head, tail, count, byte}`
apiece - and reusing `[ebp+0xC]`, which held the caller's `force`, as a budget
`agent->+0x1E4 * 4`. The loop at `0x8CEEF0` walks listB (phase 1's candidate list, head at
`[ebp-0xD0]`), repeats the `combats_count (+0x11C) <= 0` / `CUnit_IsAtOwnBase` /
`!UnitHasBlockingOrder` / not-already-in-listA gates, calls `CountSubUnitsByTypeIndex`, and sorts
the wing into one pool:

| pool | where | fed by | consumed by |
| --- | --- | --- | --- |
| **P** | `[ebp-0x114]` | the leftovers of the first arm (`0x8CF134`) | `ground_attack` |
| **Q** | `[ebp-0xBC]` | strategic bombers, `strategic_attack > 50000`, and part of the overflow (`0x8CF0E9`) | `logistical_strike`, then `strategic_bomb`/`nuke_mission` |
| **R** | `[ebp-0x38]` | naval bombers (`0x8CEFA8`) **and** budgeted tacticals/CAS/CAG with `sea_attack > 0` (`0x8CF05A`) | `naval_strike`/`port_strike` |
| **S** | `[ebp-0xF0]` | interceptors (`0x8CEFF6`) | `air_intercept` |

The chain, in order:

```
if (counts[tactical_bomber] > 0 || counts[cas] > 0 || counts[cag] > 0)  goto firstArm
if (counts[strategic_bomber] > 0)                                       -> Q
if (wing->def->strategic_attack (+0x17C) > 50000)                       -> Q
if (counts[naval_bomber] > 0)                                           -> R
if (counts[interceptor] > 0)                                            -> S
drop the wing

firstArm:                                                                  0x8CF047
if (budget > 0 && wing->def->sea_attack (+0x168) > 0) { -> R; budget-- }
else {                                                                     0x8CF0A2
    if (agent->ops_area (+0x90/+0x94) is non-empty)                      -> P
    if (!country->at_war && !country->in_undeclared_war)                 -> P
    if (wing->def->strategic_attack < 1000)                              -> P
    if (counts[cag] > 0)                                                 -> P
    -> Q
}
```

**Two corrections to `findings/FINDINGS-reorganise.md` here.** It put the `agent->+0x1E4 * 4`
budget on "the tactical pool" and left `CSubUnitDefinition +0x168` as open item 7, "not
identified". The budget is on the **naval-strike** pool, and `+0x168` is **`sea_attack`, already
named in `project.json`** - trap 14, and naming it is what makes the arm read correctly. A
tactical bomber or CAS wing with any sea attack is diverted to anti-shipping work, up to
`agent->+0x1E4 * 4` wings a pass; the rest fall through to close air support.

## Mission by mission

Every one of the seven goes through `CEU3AI::CreateUnitOrder(ai, token, unit, provinceId,
provinceIdList, int* from, int* to, 0x1A8CC94)`, whose recorded signature matches the pushes
argument for argument at all six call sites. `from` and `to` are **absolute hours**, read from
`CCurrentGameState::tick (+0xBDC)`, which `0x8CF1F6` loads into `[ebp+0xC]` once and every block
reuses. So each air mission carries a window.

| mission | token | window | weather cap | range test |
| --- | --- | --- | --- | --- |
| `ground_attack` | `0x6FB` | now → **local sunset** | 400 (invasion arm) / 330 (battle arm) | yes |
| `air_intercept` | `0x718` | now → **now + 120 h** | **none** | yes |
| `logistical_strike` | `0x6FD` | now → **now + 24 h** | 330 | yes |
| `strategic_bomb` / `nuke_mission` | `0x6F9` / `0x579` | now → **now + 24 h** | 330 | yes |
| `naval_strike` / `port_strike` | `0x700` / `0x701` | now → **local sunset** | 330 | yes |

The range test is always the same shape: `wing->def->range (+0x148) >= 1000 * CMap::DistanceBetweenProvinces(...)`.

### `ground_attack`, `0x8CF18A`-`0x8CF63C`

A survey then a per-wing loop over pool P.

**The survey (`0x8CF18A`-`0x8CF31F`)** walks the agent's front provinces (`+0xC0`/`+0xC4`) and
keeps a province in the list at `[ebp-0x94]` when it can be seen and a battle is going on in it:

```
if (p->intel_country_count (+0x374) <= ourCountry->id (+0xCA8))  skip
if (p->intel_by_country_ptr (+0x370)[ourId] < 2)                 skip   ; 0 unseen, 3 partial, 9 own
for (u in p->units (+0x2B8))
    if (u->slot15() && u->combats_count (+0x11C) > 0 && u->current_combat (+0x110) == 0)
        { keep p; break }
```

So **the close-air-support target set is the provinces on our own front where a battle is in
progress.** That is what open item 1 of `FINDINGS-reorganise` asked for.

**The per-wing loop (`0x8CF330`)**, after the listA / `home_base_ptr` gates, applies the daylight
window (below) and then tries two target arms in order:

1. `agent->+0x1AC` (recorded as `invasion_target_provinces`): at least one enemy land unit
   (`CountEnemyLandUnitsInList`), weather at or below **`[0x1B151C0]` = 400**, and in range.
2. the battle provinces from the survey: weather at or below **`[0x1B15240]` = 330**, **at most
   one of the agent's own wings already on `ground_attack` against that province** (counted at
   `0x8CF4F0`-`0x8CF514` by walking `agent->air_units_first (+0xFC)` and comparing
   `order->slot16() == 0x6FB && order->+0xC == p`), and in range.

The order goes out at `0x8CF5F5` and the chosen province is then **removed from the survey list**
(`CList_RemoveNode`, `0x8CF61A`), so two wings are never sent to the same battle in one pass.

Note the two different weather caps. The AI will fly CAS over an amphibious objective in weather
it refuses for an ordinary battle. `FINDINGS-reorganise` listed only the 330.

### The daylight window, and a correction to `FINDINGS-theatre2.md`

Both `ground_attack` and `naval_strike` schedule off this, and so does `CAIInvasion` stage 2:

```
0x008CF37E  call    0x4a7450              ; esi = the airbase province
0x008CF393  call    0x4a74d0
0x008CF39A  hour = (gameState->tick (+0xBDC) - 43710912) % 24
0x008CF3AA  if (hour > A && hour < B) skip the wing
0x008CF3B6  hoursLeft = A - hour
0x008CF3BB  if (hoursLeft < 3) skip the wing
            ...  from = tick,  to = tick + hoursLeft
```

The two functions are 28 and 30 instructions, `this` in ESI, bare `ret`, and **identical
instruction for instruction up to the final combine**:

```
0x004A7450 ...  lea eax, [edx + eax + 0xc]      ; q + 12
0x004A74D0 ...  mov eax, 0xc; sub eax, ecx      ; 12 - q
```

where `q = (latitude_north (+0x388) * daylightMonthFactor[m] / 1000 + 12000) / 2000` through
`__alldiv`/`__allmul` and a final `/1000`. The month table at `[0x170C8B0]` is signed:
`{-6000, -3000, 0, 3000, 6000, 12000, 6000, 3000, 0, -3000, -6000, -12000}`, and `m` is the global
month at `[0x1A85590]`, rotated by six months when `CProvinceTemplate::southern_hemisphere
(+0xA2)` is **clear**.

The arithmetic names them, with three checks that all land:

| | `q` | `0x4A74D0` | `0x4A7450` | |
| --- | --- | --- | --- | --- |
| equator | 6 | 6 | 18 | twelve hours of daylight |
| lat 1000, `+12000` month | 12 | 0 | 24 | midnight sun |
| lat 1000, `-12000` month | 0 | 12 | 12 | polar night |

So **`0x4A7450` is `CProvince::GetSunsetHour` and `0x4A74D0` is `CProvince::GetSunriseHour`**,
and because `|latitude_north * factor / 1000| <= 12000`, **`q` is in `[0, 12]` always**. Two
consequences:

- The guard at `0x8CF3AA` (and `0x8D0241`, and the same shape in `CAIInvasion` stage 2) is
  **unsatisfiable**: it needs `sunrise > sunset`, and they cannot cross. Dead code.
- The gate that actually bites is `sunset - hour >= 3`, and the window runs **to sunset**. These
  are **daylight** missions with at least three hours of daylight left.

`findings/FINDINGS-theatre2.md` reads the identical pattern in `CAIInvasion` stage 2 and
concludes "the AI loads its invasion force **only in the dark**, and only with at least three
hours of darkness left... the order it writes expires at sunrise", and says explicitly that the
sunrise/sunset attribution is "an inference from the modulo-24 comparison, not a reading of their
bodies". The bodies are now read and the attribution is the other way round. **That paragraph is
inverted and should be corrected** — *and it has been, on transcription of this file.*

One more thing the constant hides: `43710912` is `24 * 1821288`, so subtracting it changes nothing
modulo 24. `hour` is just `tick % 24`.

### `air_intercept`, `0x8CF643`-`0x8CF902`

Gated on `country->at_war || country->in_undeclared_war`, then per wing in pool S it **scans the
whole province table** - `gameState->provinces_begin (+0xB8C)` to `+0xB90`, the loop index
doubling as the province id - and collects every province where:

```
0x4EFA50(province@EDI, ourCountry, 0)                              holds
p->intel_by_country_ptr[ourId] >= 2                                (and the length check)
!(p->+0x304->+0x20 > 0 && CCountry::IsEnemy(us, &p->controller))   i.e. not a developed enemy province
wing->def->range >= 1000 * distance                                in range
```

Every accepted id goes on a list, and the order takes the **whole list** plus the first id as its
scalar target, with a **120-hour** window. There is **no weather test anywhere in this block** -
positive control: a scan of phase 4 for `CWeather::AirCombatEffect` finds exactly five sites,
`0x8CF437`, `0x8CF4C8`, `0x8CFC8F`, `0x8CFEFE`, `0x8D00A8`, and none is between `0x8CF643` and
`0x8CF902`.

`0x4EFA50` is the predicate `findings/FINDINGS-opsarea.md` leaves open as its own question 2. It
is called here with its third argument `0` and our own country. I did not read it; what I can add
is that it opens `if (!prov->template->+0x13D) return false`, then tests the agent country's
per-country array at `+0xE28` indexed by the province's owner id (`+0x330`) and controller id
(`+0x338`) for a non-zero `+0x20`, then `template->is_land (+0x22)`, then `0x4EF7C0` twice. That
is four arms more than the record's one-line summary, which is consistent with `FINDINGS-opsarea`
suspecting the summary is incomplete.

### `logistical_strike`, `0x8CF9FB`-`0x8CFD85` (stance 2 only)

Opens with a **power-ratio veto**:

```
0x008CFA07  eax = &agent->unit->plan (CUnit +0x1FC)
0x008CFA0F  call CUnitPlan::GetPowerRatio
0x008CFA16  if (ratio >= [0x1B15210] /* 750 */) skip the whole arm
```

`GetPowerRatio` is `our_power * 1000 / their_power`, so **the AI interdicts only while it holds
less than 0.75 of the enemy's power on that plan** - when it is losing, not when it is winning.

The survey then rebuilds `[ebp-0x94]` as **enemy rear-area provinces**: for each enemy-controlled
front province, for each of its template's edges (`+0xD4 -> +0x90`/`+0x94`, stride `0x14`) that is
not edge kind 3, the neighbour must have `template->is_land (+0x22)` and `+0x13D` set, be
enemy-controlled, have `ai_front_value (+0x5C)` at least **`[0x1B151E4]` = 200**, and **not** pass
`CProvince::HasHostileLandNeighbour`. That last clause is the whole point: a province one step
*behind* the enemy's front line.

Per wing in Q: weather at or below 330, in range, **24-hour** window. No sunrise/sunset test -
interdiction is flown round the clock.

### `strategic_bomb` / `nuke_mission`, `0x8CFDA5`-`0x8CFFF8` (stance 2 only)

The survey walks `agent->strategic_target_provinces (+0x18C`/`+0x190)` and keeps each
enemy-controlled province. **When `ourCountry->nukes (+0x90) >= 1000`** - at least one bomb, since
these are thousandths - an extra filter applies:

```
0x008CFE13  m = p->cores (+0x344);  if (!m) skip
0x008CFE1D  target = p->controller_id (+0x338)
0x008CFE23  for (node = m; node; node = node->+0xC) if (node->+4 == target) accept
            skip
```

So **a nuke is only ever aimed at territory its controller also cores** - never at land the enemy
merely occupies. `CMapProvince +0x344 cores` and `+0x338 controller_id` are both already in the
record, which is what makes this readable.

The token is chosen **once, per country, per pass** at `0x8CFF8E`: `nuke_mission (0x579)` when
`nukes >= 1000`, `strategic_bomb (0x6F9)` otherwise. It is not per target and not per wing - **one
bomb in stock turns the entire strategic bomber force onto nuke missions.**

`CCountry +0x90` is `nukes`: `findings/FINDINGS-fieldmap.md` already maps the `nukes` key (save
token `0x577`) to `+0x90` from `CCountry::LoadKey`. I greped both halves of the fact base per
trap 14 - `project.json` and `BiceLib/GameClasses/CCountry.hpp` - and neither carries it, so this
is a first landing of a fact `findings/` already held.

### `naval_strike` / `port_strike`, `0x8CFFFB`-`0x8D03E8` (stance 2 only)

The survey walks `agent->enemy_units_sighted (+0x25C)`, resolves each id pair through `0xA9D390`
and backs up eight bytes to the `CUnit`, requires `CCountry::IsEnemy` on `owner (+0x124)` and
weather at or below 330 over `current_province_ptr (+0x130)`, and then **splits on the target
province's `template->is_land (+0x22)`**:

```
0x008D00C7  cmp byte ptr [template + 0x22], 0
0x008D00D3  je 0x8d0127                        ; a sea zone  -> list Y at [ebp-0x4C]
            ...                                ; a land province -> list X at [ebp-0xE0]
0x008D0166  if (sea && u->movement_order_remaining (+0x140) > 0)
                also push map->provinces[u->+0x138[0]]->id onto Y
```

The issue repeats the sunset window and then tries **Y first with `naval_strike (0x700)`**; only
when nothing in Y is in range does it fall through to **X with `port_strike (0x701)`**, the token
being rewritten at `0x8D030C`. So **port strike is the fallback, not a separate decision** - and
it works because a ship in harbour sits in the coastal *land* province.

## Three of the four thresholds were unnamed, and none is a define

`findings/FINDINGS-reorganise.md` open item 3 reported `[0x1B15240]` as having "five readers in
`.text`... **no writer in `.text`**", correctly flagged it as trap 8's second or third shape, and
named the two settling searches. **It is the third shape, and the writer was in the scan's own
output all along.**

```
0x00D11960  movss   xmm0, dword ptr [0x160a6e0]     ; 330.5f
0x00D11968  push    ecx
0x00D11969  movss   dword ptr [esp], xmm0
0x00D1196E  call    0x401fd0                        ; floorf
0x00D11973  add     esp, 4
0x00D11976  call    0xc08870                        ; _ftol2_sse
0x00D1197B  mov     dword ptr [0x1b15240], eax
0x00D11980  ret
```

That is the `(int)floor(N.5f)` `.CRT$XCU` static initialiser, trap 8 case 3. **The reason the
earlier pass read it as a sixth reader is trap 1's cousin: `.text` here runs to `0xD2B000`, not to
the `0x970000` the folder's notes assume**, so `findValue(..., '.text')` returns the initialiser's
store alongside the real readers and it looks like one of them.

All four thresholds phase 4 uses are the same shape:

| global (rva) | value | initialiser | literal | readers |
| --- | --- | --- | --- | --- |
| `0x1715240` **`g_AiAirMissionWeatherCap`** | **330** | `0xD11960` | `330.5f` at `0x160A6E0` | 5 code: `0x8B126F`, `0x8CF4CF`, `0x8CFC96`, `0x8CFF05`, `0x8D00AF` |
| `0x17151C0` **`g_AiAirInvasionTargetWeatherCap`** | **400** | `0xD119C0` | `400.5f` at `0x160A6DC` | **1**: `0x8CF43E` |
| `0x1715210` **`g_AiLogisticalStrikePowerRatioCap`** | **750** | `0xD11B40` | `750.5f` at `0x160A614` | **1**: `0x8CFA16` |
| `0x17151E4` `g_AiFrontProvinceThreshold` | 200 | `0xD118D0` | `200.5f` at `0x160A64C` | **9** code, across the unit AI |

The last one was **already in `project.json`** from `FINDINGS-power.md` with the same value, the
same initialiser and the same "not a define" verdict - trap 14, caught by the merge, and a clean
convergence. What my pass adds to it is a **ninth** reader, `0x8CFB8A`, the interdiction front-value
floor; the record's comment says eight.

**So the figure that stops the AI flying in bad weather now has a name, a value and a reason it
cannot be modded.** None of the four is reachable from `defines.lua`.

## The naval body: the only random draw in either body

`0x8D2418`-`0x8D3237`, the block the brief wanted, is **one loop over the agent's fleets** with
three jobs: raid a convoy, rebase to a better port, and collect the fleets that are still free for
the later patrol and intercept phases. Index at `[esp+0x64]`, count at `[esp+0x118]`, the fleet
vector at `[esp+0xB0]`.

### Who raids

```
if (fleet->retreat (+0x158))                        continue
if (0x5C0160(fleet, 0))                             continue       ; not read
if (fleet->regiments_count (+0x40) < 1)             continue
CountShipsByRole(fleet, counts)
wolfpack = aiRunsUnits ? counts[subs] == fleet->regiments_count
                       : counts[transports] < 1 && counts[subs] > fleet->regiments_count / 2
if (fleet->order->slot24())                         continue       ; busy
if (!country->at_war && !country->in_undeclared_war) continue
if (!wolfpack)                                      continue
if (agent->unit->plan_naval_stance (+0x210) == 0)   continue
```

`aiRunsUnits` is `[esp+0x27]`, set at `0x8D0C43`/`0x8D0C4A` from
`owner_ai->runs_units (+0x2C) || agent->unit->+0x205` - the same flag the air body's regroup phase
uses. So **convoy raiding is for submarine fleets only**, and the bar is stricter when the AI is
actually driving its own units (all subs) than when it is not (no transports, over half subs).

### Scoring the routes, `0x8D2526`-`0x8D28B3`

It walks `agent->+0x24C`, a `CList` of **convoy object id pairs** (type at `+0`, serial at `+4`,
link at `+0xC`), resolving each through `FindPersistentById` against `[0x1A857F0]` when the id type
is above `0x1268` and `[0x1A857F4]` otherwise. A convoy counts when `CCountry::IsEnemyTag` accepts
its `+0x30`/`+0x34` tag, or failing that when that tag is on our
`undeclared_war_opponents (+0x1018)` list. Then, per province of the convoy's `path (CConvoy
+0xB0)`:

```
skip *(convoy->+0xB0) and *(convoy->+0xB4)      ; the route's two endpoint ports
skip 0x2927 <= id <= 0x292A                     ; four hard-coded province ids
skip what 0x8D0520(agent, id) refuses           ; the faction/home-waters test, not read
require COrder::IsTargetInRange(fleet, id)
weight = CConvoy::GetDesiredTransports(convoy) * abs(i + 1 - path_count / 2)
push id onto the candidate vector, weight onto the weight vector, weight onto the total
```

The index arithmetic is explicit: `[esp+0x18]` is seeded `-(path_count/2)` at `0x8D2639`,
incremented once per node at `0x8D264F`, and absolute-valued at `0x8D2800`. So **the weight is
zero at the route's midpoint and largest at its ends** - the AI's submarines are drawn to the
waters near the convoy terminals rather than to mid-ocean, and a province sitting exactly at the
midpoint can never be picked at all. I am reporting that rather than explaining it; it reads as a
deliberate "shipping concentrates near its ports" model, but nothing in the code says so.

A second pass per candidate (`0x8D2830`-`0x8D2894`) accumulates the same `GetDesiredTransports`
into an ordered map keyed by each province of the agent's area (`area->+0x94`) that lies within
the fleet's `range (+0x148)` of the candidate - a **raidable-tonnage-per-port** figure the rebase
block then has to hand.

### The draw, `0x8D2B59`-`0x8D2CB6`

```
0x008D2B5B  if (candidateCount [esp+0xFC] <= 0)  skip
0x008D2B6C  if (totalWeight   [esp+0x38]  <= 0)  skip
0x008D2BBA  eax = &gameState->+0x124                        ; the CSimpleRandom
0x008D2BBF  call    MT19937Next
0x008D2BCC  idiv    edi                                      ; r = draw % totalWeight
0x008D2BD5  chosen = 0
0x008D2BD7  while (c < candidatesEnd && r > 0) { chosen = *c; r -= *w; c++; w++ }
```

Plain roulette-wheel selection. **What is drawn:** one 32-bit MT19937 value. **Over what range:**
`% totalWeight`, where the total is the sum of `GetDesiredTransports * abs(distance from route
midpoint)` over every in-range, non-endpoint province of every known enemy convoy route. **What
it decides:** the single province a submarine fleet is sent to raid.

One quirk worth knowing: **`r` can come out 0** - one draw in `totalWeight` - and then the loop
exits before reading a candidate, `chosen` stays 0, and the order is issued against province id 0
anyway. Nothing between `0x8D2BF9` and the push at `0x8D2C9D` tests it.

The order: `CreateUnitOrder(ai, 0x6E9 convoy_raid, fleet, chosen, &emptyList, &tick, &tick +
0x1F8, 0x1A8CC94)` at `0x8D2CA5`. **`0x1F8` = 504 hours = 21 days**, much the longest-lived order
either body writes, and the province list it passes is **empty** - the single drawn province is
the whole mission.

### Rebase, `0x8D2D8B`-`0x8D3141`

Skipped for any fleet holding a submarine (`0x8D2E3A`), and skipped when the current port is not
overcrowded:

```
0x008D2EDC  cap = homePort->naval_base (+0x300)->level_max (+0x20) / 1000 + 2
0x008D2EF8  if (shipsAtBase + pendingArrivals <= cap) keep the port
```

Otherwise, over `area->+0x94` (the theatre's provinces), lowest score wins from `1e6f`:

```
if (candidate->area (+0x2B4) != fleetParent->province->area)        skip
score = (float)DistanceBetweenProvinces(candidate, fleetParentProvince) + 10.0
load  = shipsBasedAt(candidate->+0x58) + pendingArrivals[candidate->id]
        + (not already there ? fleet->regiments_count : 0)
over  = load - candidate->naval_base->level_max / 1000
if (over > 0) score += over * 2000
if (already there) score *= 0.75
if (score < best && CMapProvince::CanUnitReach(candidate, fleet, 0, 0)) best = candidate
```

then the pending-arrivals map is moved over and `CEU3AI::IssueUnitOrder(ai, 0x6DE rebase, fleet,
best->id)` goes out at `0x8D313C`. So **fleets spread themselves over the theatre's ports in
proportion to berth capacity, pay 2000 per berth of overcrowding, get a 25% discount for staying
put, and never leave their own `COwnerArea`.** The `+ 10.0` floor means distance never scores zero.

The constants are compiled-in: `1e6f` at `[0x160A598]`, `10.0` at `[0x160A340]`, `0.75` at
`[0x160A638]`, and `2000` as an immediate at `0x8D3002`. None is a define.

### The tail, `0x8D3146`-`0x8D3227`

For a fleet with no transports whose order is not `rebase (0x6DE)`, `0x6E5` or
`convoy_raid (0x6E9)`, `agent->+0x280 += fleet->slot27() / 1000.0`. Then the fleet is pushed onto
the vector at `[esp+0x154]` if its order does not block, or if it does but is
`patrol (0x42E)` or `convoy_escort (0x6E8)` - and that vector is what the patrol
(`0x8D33C0`) and intercept (`0x8D3800`) phases consume.

## `CAIUnit +0x1FC`/`+0x20C`/`+0x21C`/`+0x22C`: the names stand, and here is exactly what they rest on

The brief asked me to settle whether these are air-specific or generic. **I cannot settle it
statically, and the reason is itself the finding.**

What is solid:

- **The only reader in the image is air phase 2.** It picks one of the four by the wing's role at
  `0x8CE253`-`0x8CE27B` and scores it for a `rebase_air` destination. A bounded decode from every
  recorded function entry, looking at both `mov` and `lea` against all twelve list slots, finds no
  other read.
- **The node shape in the record is self-contradictory and I can correct it.** `0x8CE2D6` takes
  the link from `node+8` and the payload from `node+0`; `0x8CE34E` reads `payload->+8` as an index
  into `gameState->provinces_begin (+0xB8C)` and `payload->+0xC` as the float weight. So the node
  is `{payload, prev, next, byte}` and the **payload** is a small record with the id at `+8` and
  the weight at `+0xC`. It is *not* the `0x1C` scored-province record `+0x2C0` uses, whose
  province is a `CMapProvince*` at `+0` and whose score is a float at `+8`.
- **Nothing writes them.** The same scan finds writes only in `CAIUnit::CAIUnit`
  (`0x8AF778`-`0x8AF7CC`, all twelve slots zeroed) and `CAIUnit::~CAIUnit`
  (`0x8AFD6F`-`0x8AFD9A`, all four torn down through `0x4B6260`). The positive control is that the
  same scan reports those writes and the four reads, i.e. it can see this exact code. A follow-up
  scan for `add reg, 0x1FC` turned up one AI hit, `0x8B1F50` in slot 78 - and it is
  `unit + 0x1FC`, the `CUnitPlan`. **Trap 12, not a writer.**

And now the useful part. **The live observation in the brief - populated on 93 of 102 agents - is
itself the positive control that proves my writer search has a hole.** A writer exists; it reaches
the list through a pointer no displacement scan can follow, almost certainly in a function
`project.json` has never heard of.

> **CORRECTED by `findings/FINDINGS-airstance.md`.** The second half of that sentence was right and
> **the first half was the wrong diagnosis** - which is the half that would have cost the next wave.
> The writer is `CAIUnit::BuildAirTargetProvinceLists` (rva `0x4B4740`) and it reaches every list
> through a plain `lea reg, [agent + 0x1FC]`, exactly the shape ruled out here;
> `python scripts/fieldchain.py --field 0x1FC` prints it in its first screen. The real hole was that
> this scan ran **only from the 2,067 recorded function entries**, and `0x4B4740` was not one of them:
> **entry-limited, not displacement-blind.** Decoding only from recorded entries does stay
> synchronised (trap 9) but cannot reach a function nobody has recorded - which is precisely where an
> unknown writer lives. Byte-search the disp32 encoding and decode *at each hit* instead: same
> safety, no hole. So the honest statement is: these names describe *the only use
the image makes of these fields*, which is how the rest of the record names fields, and they do
**not** rest on anything about what fills them.

**The brief's second observation does not impeach the names.** "Every one of those agents' units
was a `CArmy`" is the normal case for any `CAIUnit` above wing level, because air formations hang
off army and theatre HQs; the air body's own entry gate is `agent->air_units_count (+0x104) >= 1`,
not "the agent's unit is a `CAir`". The reading that *would* impeach them is an agent with **zero**
air units carrying a populated list, and that needs a live read. Until then the names stay.

## Also established

**`CMapProvince +0x58` is the naval sibling of `+0x54`.** The rebase block hands
`candidate->+0x58 + 4` to the same ship counter (`0x5D5CC0`) that it hands
`fleet->home_base_ptr (+0x98) + 4` eight instructions earlier (`0x8D2EC2` against `0x8D2FB4`). So
`+0x58` is where a province keeps the object a *fleet* bases at, and `+0x54` - already recorded as
the object an air unit's `+0x98` holds - is the airfield. Proposed `naval_base_station`, and
`inferred` rather than confirmed: what makes it the naval one is that only fleets reach it, which
is a reading of the callers.

**`CAIUnit +0x1AC` is a `std::vector<CMapProvince*>`, not `vector<int>`.** Phase 4 walks it at
`0x8CF403` and uses each element three ways no int survives: `lea eax,[elem+0x2B8]` into
`CountEnemyLandUnitsInList`, `lea edi,[elem+0x68]` into `CWeather::AirCombatEffect`, and
`[elem+0xD0]` into `CMap::DistanceBetweenProvinces`. The name and extent are unchanged; only the
element type is corrected.

**`CMapProvince +0x300` is read as the port's berth capacity through `level_max`, not
`level_current`.** `+0x300 naval_base` is already recorded; what is new is that the AI sizes a port
by `CProvinceBuilding +0x20 level_max / 1000`, the maximum level, not the built one.

**And that is evidence - not proof - toward `+0x304` being the air base.** `FINDINGS-reorganise`
open item 5 leaves `+0x304 ai_param_building` unresolved. Three things now point one way:
`+0x300` is the naval base and `+0x304` sits immediately beside it; air phase 2 divides the number
of wings in a province by `+0x304 -> +0x24 / 1000`, which is an airfield's capacity; and
`CBuildingDataBase`'s role ladder (the equates at rva `0xB78AE`/`0xB78BC`) pairs
`MODIFIER_NAVAL_CAPACITY` and `MODIFIER_AIR_CAPACITY` adjacently. The counter-evidence is
unchanged: slot 78 reads the same pointer's `+0x20` as an **army**'s AI parameter. I am not
renaming it on that, and the cheap check is still the writer in `CProvince::LoadKey`'s building
arm.

**`CProvinceTemplate +0xA2 southern_hemisphere` gets a third independent sighting.** The record has
it from `FINDINGS-weatherfront.md`, written by a `setge` on `y >= half the map height`, with
`ComputeProvinceClimate` rotating its season table by half a year off it. The sunrise/sunset pair
rotates the *daylight* month table by exactly half a year off the same byte. I had guessed the
opposite polarity from the branch alone; the record corrected me (trap 14), and the agreement is
worth recording as corroboration rather than as a new field.

## What is not established

1. **Nothing here was watched in a running game.** The stance-2 result in particular wants one
   live check: find an AI air formation with `plan_air_stance == 2` and confirm it is rare. If it
   is as rare as the recorded distribution suggests, `logistical_strike`, `strategic_bomb`,
   `nuke_mission`, `naval_strike` and `port_strike` are effectively dead for the AI, and that is a
   mod-facing fact about the whole air war. **What writes `plan_air_stance` for an AI unit** is the
   search; `CSetPlanAttributesCommand::Execute` (rva `0x1E77D0`) is the handle.
2. **`CAIUnit +0x1E4` is still unnamed, deliberately.** Its use is now exact - `* 4` is the cap on
   how many wings may enter the naval-strike pool in a pass - but I did not count its readers
   image-wide, and `CUnit +0x1E4` is `children`, so a bare displacement scan is worthless
   (trap 12). Naming it off one reader is exactly trap 14's `tutorial_active` case.
3. **Who writes the four `air_target_provinces_*` lists.** See above: the search to run is the
   other callers of the teardown helper `0x4B6260`, and a decode of the whole `0x8A0000`-`0x8E0000`
   range from `int3`-run boundaries rather than from recorded entries only. Note that
   `FINDINGS-reorganise` prescribed `fieldchain.py --holder` for this; a holder scan will not find
   it either, because the writer does not use the displacement.
4. **`0x4EFA50`** - read four arms deep and no further. It is `FINDINGS-opsarea.md`'s own open
   question 2 and the extra arms I saw support its suspicion that the record's summary is
   incomplete.
5. **`0x8D0520`** - the per-province predicate that excludes a convoy province from raiding.
   `FINDINGS-reorganise` describes it as a faction test on `CCountry +0xD8`. Until it is read, the
   sentence "the AI will not raid its own side's shipping lanes" is an inference from where it
   sits, not a reading.
6. **The four hard-coded province ids `0x2927`-`0x292A`** excluded from convoy raiding. The
   exclusion is `confirmed` from the instruction at `0x8D2674`-`0x8D2682`; what those four
   provinces are is not. A live read of `provinces[10535..10538]` would answer it in one command.
7. **`0x5C0160`** - the second entry gate on a fleet in the convoy block, called `(fleet, 0)`,
   `ret 8`. Not read.
8. **`CProvinceTemplate +0x13D`** is still the unexplained flag the record calls
   `unknown_flag_13d`. `0x4EFA50` returns false outright when it is clear and the interdiction
   survey requires it alongside `is_land`, which is two more readers and no more meaning.
9. **`CAIUnit +0x280`**, the float the naval tail accumulates `fleet->slot27() / 1000` into. Not
   named, no writer searched for.
10. **`0x8DD0A0`, `0x8DCED0`, `0x8DD000`** - the per-province ordered map's `operator[]`,
    destructor and constructor, used by both bodies. Described in `FINDINGS-reorganise` as "its
    `operator[]`" but recorded nowhere, and I did not read them. They are on the frontier.
11. **Whether `r == 0` in the convoy draw actually happens.** The degenerate "province id 0" order
    is a reading of the loop, not an observation. It needs `totalWeight` to divide the draw
    exactly, which is a 1-in-`totalWeight` event per raid decision - rare but not negligible over
    a campaign, and a `convoy_raid` order against province 0 is the kind of thing that would show
    up in a save.

---

## The fragment, and what the check said

`reversing/fragments/merged/airnaval4.json`: **18 addresses and 8 struct fields**, using
`struct_fields` and only `confirmed`/`inferred`. Two facts about the merge were hit independently
while writing it: `CONFIDENCES` has no `likely`, and `KINDS` has no `label`, so every block label is
recorded as `kind: "instruction"` with a `no_signature` saying it is a label inside an
already-recorded body.

`python ghidra/mergeFindings.py --check` reported only the three missing write-ups (this file and
the two sibling agents'), with **no entry-level problem** against any of the 18 addresses or 8
fields. The `source` gate and the entry checks share one output, so entry problems would have
appeared in the same list.

**Two trap-14 collisions, both caught by the merge on the first run, both convergent:**

- `0x17151E4` is already `g_AiFrontProvinceThreshold` from `FINDINGS-power.md`, with the same 200,
  the same initialiser and the same "not a define". The entry was renamed to match and reduced to a
  `revises` that adds the ninth reader (`0x8CFB8A`) against the record's "eight places".
- `CProvinceTemplate +0xA2` is already `southern_hemisphere`. **The guessed polarity was backwards
  and the record is right**; the field entry was dropped entirely and the inverted sentence in
  `GetSunsetHour`'s comment fixed. The convergence is written up in prose instead, as corroboration.

`python scripts/checkSignatures.py` reports `1295 entries checked, 88 disagree` - all pre-existing,
none from this fragment. It audits `project.json` only, so it cannot see the fragment; the two
function signatures here are register-only `__fastcall` with no stack parameters against a bare
`ret`, which is what the convention implies, and both names carry `CProvince::`.

Four entries are honestly `likely` rather than `confirmed` - `CMapProvince +0x58
naval_base_station` most of all, where the mechanism is read but the word "naval" is an argument
from the callers. Those are recorded as `inferred` with "likely, and why" in the comment, which
reads as weaker than the evidence warrants and is a consequence of the tooling mismatch, not of the
evidence.

**Frontier** (what these blocks call that nobody has named), as rvas: `0x4EFA50`, `0x4DD0A0`,
`0x4DCED0`, `0x4DD000`, `0x1C0160`, `0xA5570`, `0x1D5CC0`, `0x221F0`, `0x4D0520`, `0xC0700`,
`0x6C310`.

---

## Checked on transcription, 2026-10-02

Four of this document's load-bearing claims were re-run before filing, because an agent's report is
not evidence on its own. All four hold.

- **The stance gate is exactly as quoted.** `cfg.py` confirms `0x8CF902` is a real branch target
  (reached from `0x8CF656`, `0x8CF664` and the fall-through at `0x8CF8FC`), so it is a safe decode
  start, and disassembling from it gives `cmp dword ptr [eax + 0x20c], 2` at `0x8CF908` followed by
  `je 0x8cf9fb` — with exactly two edges out. The headline stands: **stance 2 is required** to reach
  the five strategic and naval missions. *This also corrects the brief that launched the work*,
  which told the agent stance 1 was the full-threshold arm; the halving belongs to phase 1's fitness
  test, a different decision.
- **Sunset and sunrise, in that order.** Both tails were disassembled: `0x4A7450` ends
  `lea eax,[edx+eax+0xc]` (q + 12, the later hour) and `0x4A74D0` ends `mov eax,0xc; sub eax,ecx`
  (12 − q, the earlier). Both end in a bare `ret`.
- **`findings/FINDINGS-theatre2.md` has been corrected**, not merely flagged: its stage 2 heading,
  its "night window" sentence and its conclusion paragraph. The old text is quoted inside the
  correction so the record shows what changed and why, and it credits the file for having flagged
  its own attribution as an inference — which is what made this a five-minute fix.
- **The weather cap's static initialiser is real.** Disassembling `0xD11960` gives exactly the
  quoted eight instructions, `330.5f` through `floorf` and `_ftol2_sse` into `[0x1B15240]`. So the
  figure that stops the AI flying in bad weather is a `(int)floor(N.5f)` CRT static — trap 8 case 3
  — and no `defines.lua` entry can move it.

One claim was **not** checked and should be treated as the agent's: that `.text` runs to `0xD2B000`
rather than the `0x970000` the folder's notes assume. The initialiser at `0xD11960` is certainly
inside `.text`, which is consistent with it, but the section bound itself was not read.

**Landed 2026-10-02.** The fragment merged into `../ghidra/project.json` and moved to `../fragments/merged/airnaval4.json`, which is why the path above is `merged/` and not `incoming/`. The Ghidra apply has run, against a scratch copy of the `Hoi3_v12.1.2` project, and reported **failed: 2** - the documented pass mark, both failures being the two known over-long Ghidra bodies. So these names are in `project.json`, in `bicelib_findings.json` and in that Ghidra database. **the maintainer's own project was not written to**: Ghidra was open on it at the time.
