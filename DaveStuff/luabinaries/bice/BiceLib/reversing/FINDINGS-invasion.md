# Where the AI comes ashore: `CEU3AI::PickInvasionLandingProvince`, read end to end

**In one line:** the AI lands on an **enemy port of at least naval base level 1** that touches real sea rather than a lake, whose sea zone is **not** in `map/region.txt`'s `black_sea_region` or `baltic_sea_region`, which a ship from its own acting capital's area can reach — and among those it minimises a score whose movable terms are the enemy garrison standing there, **`COASTAL_FORT_LEVEL`**, the province's **victory points**, and how near it is to the army's own battle-plan objectives. Almost all of it is reachable from the mod's files; the parts that are not are a Germany-and-France special case and three `.rdata` literals.

`FINDINGS-theatre2.md` closed by calling `0x893E70` "the most valuable single function in this layer". This file reads it, and in the same pass settles its open items 5 and 6 — `0x8A9390` and `0x4A56B0` — and finishes `0x894A70`, the gate `CAIInvasion` stage 3 applies. Read statically off `hoi3_tfh.exe` on 2026-10-01, **game not running**; addresses are **virtual** (base `0x400000`) with the rva beside each entry point, and nothing here was watched in a running game. The two non-executable sources used are the mod's own `map/region.txt` and `localisation/regions.csv`.

**It does not contradict `FINDINGS-theatre2.md` §4.** It confirms it from the other end, and §10 says why in the strongest terms the evidence allows.

---

## 1. Extent and signature — trap 2, then trap 3, both checked

```
CEU3AI::EstimateProvinceDefence      0x00893C80   rva 0x493C80   ret 8     ends 0x893E6D
CEU3AI::PickInvasionLandingProvince  0x00893E70   rva 0x493E70   ret 0xC   ends 0x894A69
CEU3AI::PickNearestInvadableNeighbourProvince
                                     0x00894A70   rva 0x494A70   ret 8     ends 0x894A69+ (see §13)
CEU3AI::AbandonInvasionArea          0x00894C40   rva 0x494C40   (already in the record)
```

`image.functionStart(0x893E70)` answers `0x893C80`, exactly as `TRAPS.md` trap 2 records: the first function's `ret 8` is at `0x893E6D` and `0x893E70` is the **next byte**, with no padding at all. `0x893E70` has its own prologue — `push ebp; mov ebp,esp; and esp,0xFFFFFFF8`, an SEH frame with handler `0xC3C027`, `sub esp,0x50`, then `push ebx/esi/edi` — so it is a real entry, and it is the target of two `call`s (`findRefs.py --callers` finds `0x8930C6` in `CEU3AI::PlanAmphibiousInvasion` and `0x8A1154` in stage 3), which is what settles it independently of the walker.

`image.retsBefore(0x893E70, 0x894A69)` is **empty**: the body has one `ret 0xC` at `0x894A69` and the next four bytes are `int3`. So trap 3 does not apply here — there is no cold block past the return, and `0x894A70` is a fresh prologue of its own. The one `0xCC` byte inside the body, at `0x893F8F`, is the low byte of the displacement in `movd xmm0, dword ptr [eax + 0xbcc]` at `0x893F8B`, not padding; a scan for a *run* of `int3` gets this right and a scan for a single one does not.

The recorded signature is right and can be raised from `likely`:

```c
CProvince* __stdcall CEU3AI::PickInvasionLandingProvince(
        CEU3AI* ai,              // [ebp+8]
        COwnerArea* area,        // [ebp+0xC]  — the TARGET area
        CAIInvasion* invasionOrNull);  // [ebp+0x10]
```

`ret 0xC` agrees with three stack arguments and nothing in registers. The answer is a `CProvince*` in `eax`, taken from `[esp+0x3C]` at `0x894A54`; `[esp+0x3C]` is zeroed at `0x893FC5`, and the empty-area exit at `0x893FD5` jumps **past** that load to `0x894A58` with `eax` already zeroed at `0x893FC3`, so "nothing qualified" and "the area has no provinces" both come back null. That null is what stage 3 tests at `0x8A1163` before killing the agent.

## 2. The frame, and the two singletons it builds on demand

| slot | holds |
| --- | --- |
| `[esp+0x0F]` | the Germany-capital flag of §7 — zeroed at `0x893EF5`, set at `0x893FB0` |
| `[esp+0x0D]` | **two different things.** In the neighbour pass it is "this candidate touches real sea" (`0x894103`), consumed at `0x8942E3`; it is then re-zeroed at `0x8943B0` and reused for "the candidate is itself a plan objective" (`0x8944A4`, `0x8945C0`), consumed at `0x89465A` |
| `[esp+0x0E]` | set to 1 per candidate at `0x89402E`, cleared at `0x8941AB` for any accepted neighbour whose `ProvinceEdge.kind` is not 1 |
| `[esp+0x10]` | the plan-objective distance accumulator, then the score itself |
| `[esp+0x14]` | the candidate province |
| `[esp+0x18]` | the edge byte offset in the neighbour pass; the plan-objective count in the middle; the edge index again in the final gate |
| `[esp+0x1C]` | `value`, the attractiveness accumulator |
| `[esp+0x20]` | `navalSum`, the enemy neighbours' naval base levels |
| `[esp+0x24]` | `N`, how many enemy neighbours were accepted |
| `[esp+0x28]` | `fP` = `EstimateProvinceDefence(ai, candidate)` |
| `[esp+0x2C]` | `us` — `GetCountry(&ai->country_tag)`, from `0x893E97` |
| `[esp+0x30]` | the cursor into the area's province list |
| `[esp+0x34]` | `g_CCountryDataBase` |
| `[esp+0x38]` | the running best score, initialised to the float **1000000.0** at `0x160A598` |
| `[esp+0x3C]` | the winning province, initialised to 0 |

`lea ecx,[esi+0x20]; call 0x402610` at `0x893E94` is `CCountryTag::GetCountry(&ai->country_tag)` — `CEU3AI +0x20` is the tag, both already in the record.

Two lazy singletons are constructed inline, five times between them, and each one is a nuisance when reading rather than a finding: `g_CCountryDataBase` at `0x1A855A4` (`push 0x57C`, ctor `0x4024D0`) and `g_CCurrentGameState` at `0x1A89790` (`push 0xDA8`, base ctor `CGameState::CGameState` `0x67D070`, then vftable `0x15CF674` and the three derived fields `+0xD9C`/`+0xDA0`/`+0xDA4` zeroed). That vftable is a free trap-1 check: `project.json` records `CCurrentGameState`'s vftable as **rva** `0x11CF674` and the code writes the **VA** `0x15CF674`. The four copies in this function sit at `0x894056`, `0x89440D`, `0x894529` and `0x894911`.

## 3. The outer loop, and what the candidate is never asked

```
for (node = area->provinces_first (+0x24); node; node = node->next (+8)) {
    P = node->data;                       // a CMapProvince*
    edges = P->path_node_ptr (+0xD4)      // CProvinceTemplate
    n     = (edges->+0x94 - edges->+0x90) / 0x14      // ProvinceEdge is 20 bytes
```

The divide is the usual `imul 0x66666667; sar edx,3` by 20 at `0x894006`–`0x894019`, and the record already has `CProvinceTemplate +0x90`/`+0x94` as the edge vector and `ProvinceEdge` as `{kind, to_province, crossed_province, distance, bearing}`.

**The candidate's own owner and controller are never tested.** There is no comparison of `P->+0x330` or `P->+0x338` against anything until the Germany special case in §7 and the capital bonus in §6, and neither is a filter. What makes a province of the target area eligible is entirely (a) its own port and coast, (b) who its *neighbours* are, and (c) whether our navy can get there. That is worth saying plainly because the obvious guess — "it must be enemy-held" — is false, and `CEU3AI::PlanAmphibiousInvasion` has already established by then that the *area* is an enemy's.

## 4. The neighbour pass: who counts as an enemy neighbour, and what each one contributes

Per edge `e` of the candidate, at `0x89403F`–`0x8942DD`:

```
if (!e_template_of(e.to_province)->+0x13D)              continue        0x8940E7
if (!neighbourTemplate->is_land (+0x22))                                0x8940F4
      if (!MapProvinceIsLandlockedWater(neighbourTemplate))  coastal = 1   0x894103
if (!n->area->slot0())                                  continue        0x894108
if (n->controller_id (+0x338) == us->id (+0xCA8))       continue        0x894126
status = us->diplomacy_status_array (+0xE28) [n->controller_id]
if (status->war (+0x20))                                accept          0x89413B
else if (n->controller is REB)                          accept          0x894141
else if (we are REB)                                    accept          0x89415C
else if (!status->+0x24)                                continue        0x894177
else if (!UndeclaredWarCoversProvince(status->+0x24, n)) continue       0x894184
accept:
    if (e.kind != 1)                                    [esp+0x0E] = 0  0x8941A5
    navalSum += n->naval_base (+0x300)->+0x20 / 1000.0                  0x8941B7
    if (P->template->sea_province_id (+0xA4) > 0
        && n->template->sea_province_id == P->template->sea_province_id) {
            value += (2.0 - EstimateProvinceDefence(ai, n)) * 20.0      0x894218
            value += 2 * n->victory_points (+0x34)                      0x894220
            if (countries[n->controller_id]->capital_province_id (+0xE20) == n->id)
                value += 10.0                                           0x894298
    }
    N++                                                                 0x8942AA
```

Four things in that are worth having on their own.

**`0x4A9B70` is "is this water landlocked".** It is `bool __fastcall MapProvinceIsLandlockedWater(CProvinceTemplate* data@EAX)` — a register convention, and at the call site `eax` is still the neighbour's template from `0x8940E1`, so it takes no stack argument and ends in a bare `ret`. Body `0x4A9B70`–`0x4A9BDE` (rva `0xA9B70`): false unless `is_land` is clear; **true at once when `+0x14` is set**; otherwise it walks the edge vector, indexes each `to_province` into `CMap +0x2A60`, and answers true only if every neighbour is land. A single water province with no water neighbour — a lake.

So the coast test is: *the candidate must be adjacent to water that is not a lake.* Five direct callers.

**The positive control for `+0x22`, in the same read.** `0x4A9BE0` (rva `0xA9BE0`, 3 callers) is its byte-for-byte mirror: false unless `is_land` is **set**, then false as soon as any neighbour is land — a one-province island. That the two functions sit next to each other with opposite polarity is what makes `is_land`'s sense here certain rather than assumed, and the record's own `CProvinceTemplate +0x22` comment agrees.

Both of these defeat `image.functionStart`, which answers `0x4A9B33` for either: their first byte is `0x80` (`cmp byte ptr [eax+0x22], 0`), which is not in the walker's prologue set. Four `int3` precede `0x4A9B70` and a single `int3` precedes `0x4A9BE0`, and both are direct call targets. **This is the same failure the walker already had for `push ecx`, fixed on 2026-10-01 by adding `0x51/0x52/0x50` — `0x80` and `0x83`-with-a-byte-operand deserve the same treatment**, and the `0x4A9BE0` case is also a fresh trap-2 pair for the list.

**`0x4763A0` is the undeclared war's region test, and it closes a hole in `CCountry::IsEnemy`.** `bool __fastcall UndeclaredWarCoversProvince(CUndeclaredWar* war@EAX, CProvince* province@ECX)`, body `0x4763A0`–`0x4763EB` (rva `0x763A0`), bare `ret`, 29 direct callers. It takes the vector at `war->+0x28`/`+0x2C`, length `(end-begin)/4`, and for each member walks `province->+0x358` (next at `+8`) looking for it. Three independent reasons to call the class `CUndeclaredWar`:

1. **Locality.** `0x4763A0` sits inside `undeclared_war.cpp`'s translation unit — `CUndeclaredWar::LoadKey` is `0x475A60`, `AddAttacker` `0x476040`, `AddDefender` `0x4761C0`, and the file-name literal `'undeclared_war.cpp'` is at `0x15BD680`, pushed three times inside `LoadKey`.
2. **The loader has the key.** `python fieldmap.py CUndeclaredWar` reports two keys, `defender` (token `0x2B2`) and **`region` (token `0x414`)**, both as "nothing — a base class, or a call that keeps the value elsewhere". The `+0x28`/`+0x2C` vector is where `region` lands, which is that unplaced key placed.
3. **Its callers.** `CCountry::IsEnemy` (`0x42F266`), and the dozen places that inline the same cascade: `CCombatManager::CheckForCombat`, `CUnit::CanEngage`, `ResolveConvoyRaid`, `EnemyAirStrengthIn`, `CAIUnit::SetArea` (twice), `CAIUnit::ClassifyOpsAreaFrontier`, `CAIUnit_ComputePlanForcesAndPower`, and this file's `0x894184` and `0x894B4F`. Every one of them reaches it from `CDiplomacyStatus +0x24`.

Which gives the record two things it did not have. **`CDiplomacyStatus +0x24` is `undeclared_war`** — the field between `+0x20 war` and `+0x28 nap`. And **`CProvince +0x358`/`+0x360` is the province's region list** (head and count), which §5 then pins down from the other side. It also completes `CCountry::IsEnemy`'s own entry, which says only "a further branch that reads `+0x24` of the status and asks the province": the branch is *the province lies in a region this undeclared war covers*, and that is why the overload takes a province in `EDI` at all.

**`ProvinceEdge.kind != 1` clears `[esp+0x0E]`.** Kind 1 is the edge with a `crossed_province` — the `map/adjacencies.csv` kind, a strait crossing — and kind 3 is the impassable one `CPathFind::MayStep` refuses. So `[esp+0x0E]` survives as 1 only when **every** accepted enemy neighbour is reached across a strait rather than over an ordinary land border, and §6 shows that costs the candidate 10000. Read; the reason is inference — the reading that fits is that such a province is on *our* side of a strait and needs a crossing rather than a landing — and it is not proved.

## 5. The region blacklist: the Black Sea and the Baltic are hardcoded by name

This is the most mod-visible thing in the function, and it hides behind three anonymous globals.

```
0x894334   if (P->template->sea_province_id == 0) skip both checks
0x894336   if (P->template->sea_province_id ∈ (*(void**)0x1A85588)->vector(+8,+0xC))  reject
0x894363   if (P->template->sea_province_id ∈ (*(void**)0x1A8558C)->vector(+8,+0xC))  reject
```

Both are the `std::find` idiom, and both reject **on a hit**: after the loop `cmp eax, ecx; jne 0x894A49` at `0x89435D` and `0x894381`, where `ecx` is `end`, so `eax != end` means found and found means next province.

The three globals are written in one place each, inside the function at `0x489BA0`, and each is a name looked up out of `CMap +0x2A50` through the string hash table at `0x52A710`:

| global (VA) | rva | the literal it is looked up by | stored at |
| --- | --- | --- | --- |
| `0x1A85584` | `0x1685584` | `'mediterranean_region'` (`0x15BE1C8`) | `0x48B6D0` |
| `0x1A85588` | `0x1685588` | `'black_sea_region'` (`0x15BE1E0`) | `0x48B734` |
| `0x1A8558C` | `0x168558C` | `'baltic_sea_region'` (`0x15BE1F4`) | `0x48B79F` |

`0x52A710` is a bucket hash over `CMap +0x2A50`: it hashes the key string, indexes `+8` by the hash modulo `+4`, and walks the chain comparing the key against **`entry + 0x18`**, returning `*(bucket_node)` on a match and 0 on exhaustion. So the object a region global holds carries its own name as a `std::string` at `+0x18` and the vector the landing chooser searches at `+0x8`/`+0xC`.

**The mod's own file is the oracle, and it matches exactly.** `map/region.txt` in this repository begins:

```
black_sea_region = {
	10593 10594 10595 10596 10597 10598 11382
}
baltic_sea_region = {
	10500 10502 ... 10516
}
mediterranean_region = {
	10560 ... 11456 10586 10591
}
```

Three names, in that order, as the file's first three entries, each a flat list of **province ids** that are sea zones — which settles that the `+0x8`/`+0xC` vector holds ids and not pointers, because otherwise the search against `sea_province_id` could never match and the whole test would be dead. `localisation/regions.csv` line 1 gives `black_sea_region;Black Sea`, so the names are the game's own, not internal.

So, stated as a mod can use it:

> **The AI will never plan an amphibious invasion onto a province whose single connected sea zone is listed in `black_sea_region` or `baltic_sea_region` in `map/region.txt`.** Which sea zones those are is the mod's to decide. `mediterranean_region` is loaded beside them and is **not** consulted here — it, and these two, are read instead by the canal/strait passage tests at `0x4A7F80` and `0x4D5190`, which also read four province ids out of the defines block at `GetDefines()->+0xFC`. That is the Gibraltar / Bosphorus / Kiel machinery and it was not read further.

`CProvinceTemplate +0xA4` is `sea_province_id`, which the record already describes as "on a land province, the id of the one sea province it connects to; 0 where there is none" — so the test is on the single sea zone the province fronts, not on all of them. A province fronting two sea zones is judged by whichever one `+0xA4` holds.

## 6. The score, term by term

`CEU3AI::PickInvasionLandingProvince` **minimises**: the running best starts at `1000000.0f` and `comisd xmm1, xmm0; jbe 0x894A49` at `0x894886` rejects unless `best > score`. Same convention as `CAIInvasion::PickEmbarkationPort`.

After the neighbour pass, at `0x8942E3`–`0x89487F`:

```
if (!coastal)                            next province        0x8942E8
if (P->naval_base->+0x20 < 1000)         next province        0x8942F8   // level < 1
value = navalSum + value                                      0x894305
<the two region blacklists of §5>
fP = EstimateProvinceDefence(ai, P)                           0x894390

// the plan-objective pass, §6a
if (area->provinces_count > 1 && fP > 5.0 && planCount == 0)  next province   0x894626
if (planCount > 0) planDist /= planCount                      0x894639
if (P is itself a plan objective) planDist /= 10.0            0x894661

cap = NavalBaseCapacity(P)                                    0x894685
score  = planDist
score -= (cap / 1000) * 10.0                                  0x8946CE
score -= value * 0.5                                          0x8946E9
score -= N                                                    0x8946FF
if (P->naval_base->+0x20 > 0)
     score -= (2.0 - fP) * 20.0                               0x89472A
if ([esp+0x0E] && N > 0) score += 10000.0                     0x894741
score += fP * 34.0                                            0x894765
score -= 2 * P->victory_points (+0x34)                         0x894784
<the Germany/France special case of §7>
if (countries[P->controller_id]->capital_province_id == P->id)
     score -= 20.0                                            0x894833
for (inv in ai->invasion_agents_first (+0x50))
     if (inv != invasionOrNull && inv->+0x84 == P) score += 1000.0   0x894867
```

Every constant is an `.rdata` literal, read with `image.read` and unpacked:

| address | value | where |
| --- | --- | --- |
| `0x160A598` | `1000000.0f` | the initial best |
| `0x160A2EC` | `5.0f` | the defence threshold that forces a plan objective |
| `0x160A300` | `1000.0` | the thousandths divisor, everywhere |
| `0x160A308` | `0.5` | the `value` weight |
| `0x160A318` | `20.0` | the per-province defence weight |
| `0x160A340` | `10.0` | the naval-capacity weight, and the enemy-capital bonus to `value` |
| `0x160A358` | `100.0` | the Soviet manpower threshold, §7 |
| `0x160A360` | `2.0` | the defence term's pivot, and the negative-score multiplier, §7 |
| `0x160A370` | `10000.0` | the all-straits penalty |
| `0x160A638` | `0.75` | §7 |
| `0x160A64C` | `200.5f` | §7 — `(int)floorf(200.5f)` is 200 |
| `0x160A960` | `1.25` | §7 |
| `0x160A968` | `34.0` | the defence term again, with the opposite sign |

Two notes on the arithmetic. The `(2.0 - fP) * 20.0` term at `0x894707` is guarded by the flags from `cmp dword [eax+0x20], 0` set back at `0x8946AC` — the SSE instructions between them do not touch `EFLAGS` — so it applies only when the naval base level is positive. Since `< 1000` was already a rejection, **it always applies**; the test is dead. And `fP` enters the score twice with opposite signs, `-20·(2-fP)` and `+34·fP`, which together come to `54·fP - 40`: defence is penalised at 54 per unit, and a wholly undefended province gets a flat 40 off.

The last term is an anti-collision rule worth stating: **two of a country's invasions will not pile onto the same objective**, because any other live `CAIInvasion` already pointing `+0x84` at this province costs it 1000.

### 6a. The plan-objective distance, and what `CEU3AI +0x2C` picks between

At `0x894395`, `cmp byte [esi+0x2c], 0` on the `CEU3AI` splits two passes that compute the same three numbers. The record has `CEU3AI +0x2C` as `runs_units`, "1 for an AI-run country, 0 for the human's own country", and both arms read correctly that way:

- **`runs_units == 0` — the human's country** (`0x8943BB`–`0x8944FE`). For each `CAIUnit` in `ai->unit_agents_first (+0x40)`, call slot 74 (`[vft+0x128]`) twice and take `+0x234` of the answer. `CUnit +0x234` is `plan_objectives`, a list of `CObjective` at `0x24` bytes each with the province id at `+0x8` and the next at `+0x1C` — and that is exactly the stride the code walks (`mov ebx,[edi+8]; mov edi,[edi+0x1C]`), so **slot 74 returns the agent's `CUnit*`**. Reported, not named: trap 4 says count the vftable holders of a one-line getter first.
- **`runs_units != 0` — an AI country** (`0x894503`–`0x89460C`). The same body over `ai->+0x118`, which the record has as `priority_province_list_first`, "a list of province ids", filled by `CEU3AI::RebuildPriorityProvinces`. The nodes here hold ids directly (`ebx = [edi]`, `edi = [edi+8]`, then `provinces[ebx]`), which corroborates that description.

Either way, per objective province `q`:

```
if (q->area (+0x2B4) != area)  skip
if (q == P)                    onPlan = 1
planDist += CMap::DistanceBetweenProvinces(P->id@EAX, q->id@EDX, g_CMap)
planCount++
```

`DistanceBetweenProvinces` (`0x492030`) is the record's own "four times the straight-line map distance", not a path length, so this is proximity and not reachability. `g_CMap` is the singleton at `0x1A8557C`, the same one `0x4A9B70` indexes `+0x2A60` out of.

So: **an invasion goes where the army already wants to go.** For the player's country that means the player's own battle plans steer the AI's amphibious suggestion; for an AI country it is the AI's priority provinces. And the gate at `0x894626` makes it a requirement rather than a preference whenever the target area has more than one province and the candidate's defence estimate is over 5.0.

## 7. The one piece a mod cannot reach: Germany's capital area, France's provinces, and a weak Soviet Union

`[esp+0x0F]` is set in the preamble, at `0x893EA0`–`0x893FB0`, and used once:

```
db  = g_CCountryDataBase (0x1A855A4)
ger = db->countries_first(+0x16C)[ db->+0x4 ]            // slot 0 of the 45 tag slots
if (ger->GetActingCapitalLocation()->area (+0x2B4) == area) {        0x893F05
    me = GetCountry(&ai->country_tag)
    if (me->is_major (+0x15C) || me->max_ic (+0x60C) > 100) {        0x893F16
        limit = (int)floorf(200.5f)                                  // 200
        sov = db->countries_first[ db->+0x14 ]           // slot 2
        if (*0x4FCB80(sov, &tmp) > limit)                [esp+0x0F] = 1
        else if (100.0 > sov->Manpower (+0xBCC) / 1000)  [esp+0x0F] = 1
    }
}
```

and then, at `0x894772`–`0x894800`:

```
if ([esp+0x0F]) {
    score *= (score < 0.0) ? 2.0 : 0.5;
    if (P->owner_id (+0x330) == db->+0x2C)               // slot 5
        score *= (score < 0.0) ? 1.25 : 0.75;
}
```

Minimising, so both multipliers **improve** the candidate whichever side of zero it is on — a sign-aware preference, which is why there are two of each.

**The three country slots are read, not guessed, and the whole index map is checked.** The 45 three-character names live in `.rdata` at `0x15C1DE4`, four bytes apart, and `image.read` across all 46 slots gives `GER ENG SOV USA JAP FRA ITA PHI CHI CHC CGX CSX KOR MEN SIK CXB CYN BEL LUX HOL POL ROM HUN BUL TUR YUG SLO CZE AUS MAN DEN NOR FIN EST LAT LIT SWE SCH SPA SPR ETH CAN SAF AST NZL`, immediately followed by `'coun'` — the start of `countrydatabase.cpp` — so the array is exactly 45 long. The store chain at `0x515CC0` then fixes the stride: `"GER"` stores `[eax]`/`[eax+4]` at `0x51622F`/`0x516231`, `"ENG"` `[eax+8]`/`[eax+0xC]` at `0x516333`/`0x516336`, `"ITA"` `[eax+0x30]`/`[eax+0x34]` at `0x51673E`/`0x516741`, `"CHI"` `[eax+0x40]`/`[eax+0x44]`, `"BEL"` `[eax+0x88]`/`[eax+0x8C]`. So **slot `i` is chars at `i*8`, id at `i*8+4`**, which confirms `FINDINGS-theatre2.md` §1 and extends it to all 45.

Therefore `db->+0x4` is **GER**, `db->+0x14` is **SOV**, `db->+0x2C` is **FRA**, and the rule reads:

> When the target area is the one holding **Germany's acting capital**, and the invading country is a major or has over 100 max IC, and the **Soviet Union** is either over 20% through whatever `0x4FCB80` measures or down below 100 manpower, every candidate in that area gets a free doubling of preference — and a **French-owned** province in it gets a further 25%.

That is a compiled-in literal a mod cannot reach: the tags are `.rdata` strings and the slots are fixed by `countrydatabase.cpp`. The only way to move it is to stop a province being French-owned or to stop Germany's acting capital being in that area.

`0x4FCB80` is left unnamed and is in §17. Its arithmetic is read: `__thiscall(CCountry* this, int* out)` with `ret 4`, answering `0` when `this->government_in_exile (+0x95)` is set, `1000` when `this->+0xD08` is zero, and otherwise `clamp(0x4FCC60(this) * 1000 / (this->+0x10B8 / 100), 0, 1000)`, where `0x4FCC60(this@EAX, out@EDI)` is `1000 - clamp(this->+0xBE4 * 1000 / this->+0xBE0, 0, 1000)` and 0 when `+0xBE0 <= 0`. So it is a complement-of-a-ratio in thousandths, normalised against another figure — a "how much of its X has it lost" number, with the threshold at 0.2. Nine callers, one of which (`0x9F8210`) looks like a Lua accessor and would name it in one read.

## 8. The two accept gates

Once a candidate beats the running best, two more tests stand between it and `[esp+0x3C]`.

**The fleet gate, only when `invasionOrNull` is non-null** (`0x894890`–`0x8949FC`). It opens with `invasion->slot66()` (`[vft+0x108]`, `0x108/4 = 66`), and `FINDINGS-aitheatre.md`'s slot table has `CAIInvasion` slot 66 as the body `0xA92590`, `mov al,1` — the type tag. So on a real `CAIInvasion` **it always answers true and the gate always applies**. It then walks the candidate's edges again and needs one neighbour that is water (`is_land` clear) with `+0x13D` set, for which:

```
transports = invasion->slot61()        // [vft+0xF4] = lea eax,[ecx+0x64]
if (transports->count (+0x6C) <= 0)   next edge
first = *transports                    // the head node's CUnit*
if (first->slot35(seaProvince))        accept                  0x8949E0
```

`[vft+0xF4]/4 = 61`, which `FINDINGS-theatre2.md` §3 records as the **naval** list getter `0x8E9090`, `lea eax,[ecx+0x64]`; `+8` off that is `transports_count` at `+0x6C`. `CUnit` slot 35 is `[vft+0x8C]` and is not named here. So: *the invasion's first transport must be able to enter the sea zone off the beach.* When the planner calls with `invasionOrNull = 0` there is no fleet yet and this is skipped entirely — the planner's answer is therefore less constrained than stage 3's re-pick, which is a real behavioural difference and not an optimisation.

**The capital-port gate, always** (`0x8949FE`–`0x894A37`):

```
home = GetActingCapitalLocation(us)->area (+0x2B4)
if (!home->ports_first (+0x48))  next province
for (port in home->ports_first)
    if (0x4D52A0(us, port, P, 1))  accept
next province
```

So the landing site must be reachable, by whatever `0x4D52A0` tests, **from a port in our own acting capital's area** — not from the invasion's port of embarkation, and not from the fleet's current position. A country whose capital area has no naval base plans no amphibious invasion at all, anywhere. `0x4D52A0`'s argument order is fixed by the pushes at `0x894A25`–`0x894A29`: `(CCountry* us, CMapProvince* from, CMapProvince* to, bool)`, which agrees with `FINDINGS-aitheatre.md`'s reading of the same call in `PickEmbarkationPort`.

## 9. `0x893C80` is the beach-defence estimate, and `COASTAL_FORT_LEVEL` is in it

`float __stdcall CEU3AI::EstimateProvinceDefence(CEU3AI* ai, CProvince* province)`, `0x893C80`–`0x893E6D` (rva `0x493C80`), `ret 8`, answer in `xmm0`. Both callers are inside `PickInvasionLandingProvince` — `0x894184` against a neighbour, `0x894390` against the candidate — and nothing else in the image calls it.

```
total = 0.0f
for (u in province->units (+0x2B8)) {
    if (!u->slot15())                              continue   // IsLand, per vftable_slots
    if (!IsEnemy(GetCountry(&ai->tag)@ESI, &u->owner (+0x124)@EDX, province@EDI))
                                                   continue
    for (s in u->regiments (+0x38)) {
        frac = s->strength (+0x5C) * 1000 / s->slot12(&out,0,0);   // thousandths
        frac /= 1000.0;
        if (s->sub_unit_definition_ptr (+0x58)->type_index (+0x24)
            == g_CSubUnitDataBase->hq_brigade (+0x78)->type_index)
                frac /= 3.0;
        total += frac;
    }
}
total *= (province->modifiers (+0x114) [11] / 1000 / 5.0 + 1.0);
return total;
```

Three identifications that carry the whole reading, all from the record:

- `CSubUnitDataBase +0x78` is **`hq_brigade`**, one of the role definitions the units loader caches as it parses. So **an HQ brigade standing on the beach counts for a third of a line regiment**, which is as sensible a rule as the game has.
- `CProvince +0x114` is the `CProvinceModifier`'s values array, indexed `id * 8` (trap 5). `FINDINGS-combatmods.md` fixed that indexing with four independent reads and gives `+0x58` as **id 11, `COASTAL_FORT_LEVEL`**. So the final scale is `1 + COASTAL_FORT_LEVEL / 5`: **each coastal fort level makes the AI value the province 20% less as a landing site**, compounding into both the `-20·(2-fP)` and `+34·fP` terms for a net `+54` per unit of estimated defence.
- `s->slot12()` is `[vft+0x30]`; `CSubUnit +0x5C` is `strength` and `+0x58` the definition. The `strength / max` shape and the `x * 1000 / y` with a 64-bit fallback through `0xB99AF0`/`0xB99980` are the house idiom for a thousandths ratio.

The `3.0` at `0x160A4E8` and the `5.0` at `0x160A508` are `.rdata` literals, not defines.

Note the asymmetry: `fP` is computed against the **candidate** and the gate at `0x894626` treats `fP > 5.0` as "heavily held"; the same function against a **neighbour** feeds `value` with `(2.0 - f) * 20.0`, so a lightly held enemy neighbour is worth up to +40 of attractiveness and a heavily held one is a penalty. An undefended enemy hinterland next to the beach is what the AI is really looking for.

## 10. So: what makes the AI pick one landing province over another, in terms a mod can see

Ranked by how much of it a mod owns.

**Hard requirements, all mod-reachable:**

1. **A naval base of at least level 1** on the landing province itself (`0x8942F8`, `< 1000` thousandths rejects). The AI lands in a **port**, never on an open beach.
2. **Adjacency to real sea** — a water neighbour that is not a lake (`0x8942E8`).
3. **The connected sea zone must not be in `black_sea_region` or `baltic_sea_region`** of `map/region.txt` (§5).
4. **Sea reachability from a port in the invader's own acting capital's area** (§8).
5. **At least one plan objective in the area**, whenever the area has more than one province and the candidate's defence estimate exceeds 5.0 (§6a). `map/area.txt` decides the areas; the plans decide the objectives.
6. When stage 3 re-picks, **the invasion's lead transport must be able to enter the sea zone** (§8).

**Preferences, in the order of how much they move the score:**

| term | sign | what a mod moves it with |
| --- | --- | --- |
| all enemy contact over strait crossings | **+10000** | `map/adjacencies.csv` |
| another invasion already on this province | **+1000** | nothing — behaviour |
| estimated enemy defence `fP`, net | **+54 per unit** | garrison size, and `COASTAL_FORT_LEVEL` multiplying it by `1 + level/5` |
| flat bonus for an undefended province | **−40** | same |
| enemy neighbours' defence, through `value` | **−10 per lightly-held neighbour** | same, on the neighbours |
| enemy neighbours' victory points, through `value` | **−1 per VP** | `history/` province VPs |
| the candidate's own victory points | **−2 per VP** | same |
| naval base **capacity** of the landing province | **−10 per daily unit** | base level, `NAVAL_BASE_EFFICIENCY`, the supply define `NavalBaseCapacity` caches |
| enemy neighbours' naval base levels, through `value` | **−0.5 per level** | base levels |
| count of enemy neighbours `N` | **−1 each** | the front's shape |
| the province is its controller's capital | **−20** | `history/` capitals |
| an enemy neighbour is its controller's capital | **−5** (10 into `value`, halved) | same |
| distance to the army's plan objectives | **+1 per 4 map pixels**, and **/10** if the province is itself an objective | the plans |

**Not mod-reachable:** the Germany-capital-area doubling and the France 1.25×/0.75× inside it, the Soviet-weakness threshold of 200 and 100 manpower, and every one of the fourteen `.rdata` floats in §6. The `2.0`, `20.0`, `34.0`, `0.5`, `10.0` and `10000.0` weights are **compiled-in literals a mod cannot reach**, and so are the 3.0 and 5.0 in `EstimateProvinceDefence`.

**And `COASTAL_FORT_LEVEL` is the single most useful lever**, because it is the only term that scales another one: it multiplies the garrison estimate, which then enters the score twice. That is a claim about the arithmetic and it is read, not watched.

## 11. `0x4A56B0` — the proposed name was wrong, and the right one fits all three uses

`bool __thiscall CProvince::HasHostileLandNeighbour(CProvince* this, bool requireGarrison)`, `0x4A56B0`–`0x4A57C9` (rva `0xA56B0`), `ret 4`, read end to end, 14 direct callers.

```
if (this->owner_id (+0x330) == 0)                return false
n = (template->+0x94 - template->+0x90) / 0x14
if (n <= 0)                                      return false
for each edge e {
    if (e.kind == 3)                             continue      // the impassable kind
    nb = g_CMap->provinces (+0x2200) [e.to_province]
    if (!nb->template->is_land)                   continue
    if (!nb->area->slot0())                      continue
    if (nb->controller_id == this->controller_id) continue
    if (!IsEnemy(countries[nb->controller_id]@ESI, &this->controller@EDX, this@EDI))
                                                  continue
    if (!requireGarrison)                        return true
    if (CountLandUnitsInList(&nb->units (+0x2B8)) > 0)  return true
}
return false
```

The `mov esi, [esp+0x1C]` at `0x4A579C` is a reload of the clobbered loop bound, not a break; the loop runs to the end.

**"Isolated / no land link" is the opposite of what this does.** The predicate is *this province is in land contact with an enemy* — it is on a front. And every one of the three recorded uses reads naturally that way, which is the test the old name failed:

| use | with the new reading |
| --- | --- |
| the 10× weight in `CAIInvasion::PickEmbarkationPort` | don't load an invasion force in a frontline port |
| `!0x4A56B0(province, 0)` required for the four hardcoded theatre seats in `BuildTheatres` | a theatre HQ does not sit on the front line |
| false is an early `false` in `CAIInvasion::UnitCanReachObjectiveOverland` | a unit not in contact with any enemy by land is not going to march to the objective |

`CountLandUnitsInList` (`0x5D5C60`, rva `0x1D5C60`, bare `ret`, receiver in `ECX`) is its one helper and has exactly one caller: it walks the list and counts members whose `[vft+0x3C]` answers true, and `project.json`'s `vftable_slots` has `CUnit` slot 15 as `IsLand`. So the second argument means **"and that neighbour must have a land unit standing in it"**. `0x5D5C90` is a separate function of the same shape.

`CCountry::IsEnemy` at the call site takes its receiver in `ESI`, the tag in `EDX` and — the operand `FINDINGS-theatre2.md` noted but did not identify — **a `CProvince*` in `EDI`**, which here is `this`. Reading `0x42F210` through settles that third operand for good: it is only used in the undeclared-war branch of §4, and `project.json` already has the convention right.

## 12. `0x8A9390` is the front-worthiness predicate, and most of it is a compiled-in table

`bool __thiscall CAIStrategy::IsFrontWorthyEnemy(CAIStrategy* this, CCountryTag tag)`, `0x8A9390`–`0x8A9A29` (rva `0x4A9390`), `ret 8`, 18 direct callers. The tag arrives by value as two dwords, `chars` at `[ebp+8]` and `id` at `[ebp+0xC]`; `this` is in `ECX` and its own tag is at `+0x8`/`+0xC`.

Four interior `ret 8` at `0x8A94DC`, `0x8A9676`, `0x8A96D1` and `0x8A977A`. **These are trap 3, not trap 2**: each is reached by a `je`/`jne` from inside the body (`0x8A94B2 → 0x8A94DF` is the clearest), each restores the one SEH frame set up by the single `sub esp, 0x20`, and the first `int3` run is at `0x8A9A2C`. `0x8A9A30` is a separate function.

The cascade, in order:

```
F = (g_CCurrentGameState->scenario (+0xD0C) != 0)                        0x8A947B
if (tag.id == this->tag.id)                                 return false 0x8A949A
them = countries[tag.id]
if (them->has_faction (+0xF34))
     return IsFrontWorthyEnemy(this, them->faction_leader (+0xF38))      0x8A94C6
if (0x8A9A30(this@EDI, tag))                                return true  0x8A94E8
if (CCountry::IsFriendly(GetCountry(&this->tag), &tag, 1))  return false 0x8A9504
us = GetCountry(&this->tag)
if (us->has_faction && countries[us->faction_leader_id]->diplomacy[tag.id]->+0x14)
                                                            return false 0x8A954C
if (0x8ADE10(this, tag))                                    return true  0x8A9582
if (F)                                                      return false 0x8A9593
theirFaction = them->faction (+0xD8);  ourFaction = us->faction
if (!ourFaction->slot7())              goto the second table            0x8A95A6
if (theirFaction->slot7() && theirFaction != ourFaction)    return true  0x8A95BF
<the first table>
```

`CCountry +0xD8` is `faction` and is never null — a country in no faction points at the shared singleton at `0x1A855A8` — so `theirFaction == ourFaction` meaning "not a front" also quietly makes two factionless countries not a front.

**The table.** `ESI` holds `g_CCountryDataBase` throughout, and the arms compare our own tag id against one slot and then the other country's id against a list of slots. With the slot map fixed in §7:

| we are | their tag makes it a front |
| --- | --- |
| **SOV** (`+0x14`) | LIT, ROM, POL, SPA, SPR, ETH, SWE, HUN, BUL, TUR, YUG, SLO, CZE, AUS, MAN, JAP — unconditionally |
| **GER** (`+0x4`) | HOL, BEL, LUX, POL, LAT — unconditionally |
| **FRA** (`+0x2C`) | ITA unconditionally (and only when the two factions differ); BEL and LUX through the shared tail |
| **BEL** (`+0x8C`) | LUX, through the same tail |
| **ENG** (`+0xC`) | the tail only |
| **JAP** (`+0x24`) | CHC, CHI, CGX, CSX, KOR, MAN, MEN, SIK, CXB, CYN |

and on the branch taken when our own faction's slot 7 is false:

| we are | their tag |
| --- | --- |
| **LIT** (`+0x11C`) | SCH → false, GER → false, SOV → **true** |
| **JAP** (`+0x24`) | the same ten Chinese and Korean tags |

The shared tail at `0x8A9705`–`0x8A9779` reads the other country's faction leader, answers false when that is us, and then requires `CCountry::IsEnemyTag` (`0x42F1B0`) to hold. So the table is a mix: some pairs are unconditional fronts, others only license the ordinary enmity test.

Everything past `0x8A98D0` — a `GetIdeologies` (`0x527280`) comparison, JAP and ITA special cases, and a computation through the 64-bit helpers and `floorf` — is the generic fallback and **was not read**. The function is `0x699` bytes and this is its skeleton, not its whole.

Even so, the useful sentence is available: **which neighbours a country raises a theatre front against is, for the six majors and Lithuania, a compiled-in list of tags.** `CAreaBorder`'s `local_enemy` key proposes the pair and this function vetoes it. A mod can change neither list.

## 13. `0x894A70`, the gate stage 3 applies

`CProvince* __stdcall CEU3AI::PickNearestInvadableNeighbourProvince(CEU3AI* ai, CProvince* from)`, `0x894A70`–`0x894C29` (rva `0x494A70`), `ret 8`, with a second `ret 8` at `0x894C34` returning null and the `int3` run at `0x894C37`. Two callers: `CAIInvasion` stage 3 at `0x8A10xx`, where only null-ness matters, and `0x8A11B0`.

```
best = 1000000.0f; result = 0
for (a in from->area (+0x2B4)->neighbour_areas (+0x34)) {
    if (a->provinces_count == 0) { tag = "---"/0; }
    else { p = *a->provinces_first; tag = p->controller; }
    us = GetCountry(&ai->country_tag)
    if (tag.id == us->id)                     continue
    status = us->diplomacy[tag.id]
    if (!status->war && !REB(tag) && !REB(us)) {
        if (!a->provinces_first)              continue
        if (!status->undeclared_war (+0x24))  continue
        if (!UndeclaredWarCoversProvince(status->+0x24, ...))  continue
    }
    for (q in a->provinces_first) {
        if (q->template->sea_province_id (+0xA4) < 1)  continue
        enemies = CountEnemyLandUnitsInList(&q->units (+0x2B8), us->tag)
        d       = 0x4A5570(q@ECX, &out, from->id)
        score   = d / 1000.0 + 34.0 * enemies
        if (score < best) { best = score; result = q; }
    }
}
return result
```

The `34.0` is the same `0x160A968` the landing chooser uses, and the `1000000.0f` the same `0x160A598`. `0x4A5570` is the naval distance of `FINDINGS-theatre2.md`'s open list: it indexes `CMap +0x2A60` by both ids and works off the template's `+0xAC`, falling back to `sea_province_id`; only its head was read.

`CountEnemyLandUnitsInList` (`0x5D6880`, rva `0x1D6880`, `ret 8`, the list in `EAX` and the tag's halves on the stack) skips a unit whose slot 16 (`IsNaval`) or slot 17 (`IsAir`) answers true, then counts it when `CCountry::IsEnemy(GetCountry(&unit->owner), &tag, unit->current_province)` holds. Eight callers. **This is a different function from `SumTransportWeight`**, which `project.json` has at rva `0x1D6690`; `FINDINGS-aitheatre.md` cites `0x5D66D0` for `SumTransportWeight` and `FINDINGS-theatre2.md` cites `0x5D6690`, and the record's address is the right one. `CAIInvasion` stage 2's `0x5D6880(&(+0x84)->+0x2B8, tag)` is this function and is a *count*, tested for zero, not a pointer tested for null.

So the stage-3 `else` arm that `FINDINGS-theatre2.md` §5 recorded "as read rather than explained" has one more piece of its sense: `0x894A70` asks whether there is **any coastal province in an area neighbouring the objective's that is worth invading**, and if there is not, the fleet is given a `transport` order instead of an `invasion` one.

## 14. Negatives, each with its positive control

**No define reaches the landing decision.** A scan of `0x893E70`–`0x894A69` for `call GetDefines (0x445D90)` finds none, and so do the same scans of `0x893C80`, `0x8A9390` and `0x4A56B0`. **The control:** the identical scan over `0x4A7F80` (the canal test, 60 bytes away from code this file reads) finds one at `0x4A7FBE`, and over `NavalBaseCapacity (0x4A75D0)` finds two, at `0x4A7607` and `0x4A76B1` — and the record independently says `NavalBaseCapacity` caches a supply define. So the method sees defines where they are, and its silence here is evidence.

**But only for the first of trap 8's three ways.** The second leg of the scan, for the inlined `GetDefines` singleton `[0x1A86040]`, found nothing *anywhere*, including in both controls — so that leg has **no** positive control and says nothing. An inlined `GetDefines` and a block cached into globals at startup are both still possible. What *is* positive is that all fourteen scoring constants were read out of `.rdata` as literal floats and doubles, which is trap 8's third case and the one that cannot be moved from `defines.lua` at all.

**`mediterranean_region` is not consulted by the landing chooser.** A byte search of `.text` for each of the three absolutes found `0x1A85584` at `0x48B682`, `0x48B6D1`, `0x4A802B`, `0x4A80EA` and `0x4D5195` — none inside `0x893E70` — while the **same search in the same run** found `0x1A85588` at `0x894337` and `0x1A8558C` at `0x894364`, which are the two the function does read. The control is the search finding the other two globals in the body it is said not to contain the first one.

## 15. Corrections to the record

Reported, not overwritten. The merge refuses to replace an existing name, so these want a human decision.

| the record says | the evidence |
| --- | --- |
| `0x4A56B0` unnamed, "'isolated / no land link' fits all three uses but was never proved" (`FINDINGS-theatre2.md` open item 6) | **the opposite.** `0x4A56B0` returns true when the province has an enemy-controlled **land** neighbour over a passable edge. §11, with all three uses re-read |
| `CEU3AI::PickInvasionLandingProvince` rva `0x493E70`, confidence `likely`, comment "read so far only through its two call sites" | the body is now read end to end; the signature's `ret 0xC` and three arguments are confirmed. Propose `confirmed` and the comment this file supports |
| `TRAPS.md` trap 2's known pairs | add **`0x4A9BE0`** (preceded by a single `int3` after `0x4A9B70`'s `pop ebx; ret`) |
| `image.functionStart`'s prologue byte set | add **`0x80`**. Both `0x4A9B70` and `0x4A9BE0` begin `cmp byte ptr [eax+0x22], 0` and the walker runs past them to `0x4A9B33`, exactly the failure the `0x51/0x52/0x50` addition fixed for `push ecx` |
| `FINDINGS-aitheatre.md` and `FINDINGS-theatre2.md` cite `SumTransportWeight` as `0x5D66D0` and `0x5D6690` respectively | the record's rva `0x1D6690` is right; `0x5D6880` is a **different** function, `CountEnemyLandUnitsInList`, and it is the one stage 2 calls |
| `FINDINGS-theatre2.md` §5: stage 2's `0x5D6880(...)` "must answer non-null" | it answers a **count**, and the test is for zero |
| `CCountry::IsEnemy`'s "further branch that reads `+0x24` of the status and asks the province" | the branch is `UndeclaredWarCoversProvince`, `CDiplomacyStatus +0x24` is the `CUndeclaredWar`, and the question is whether the province is in one of its regions |
| `CEU3AI +0x118 priority_province_list`, "what fills it was not traced" | still not traced, but **what reads it** is now one more thing: `PickInvasionLandingProvince`'s plan-distance pass on the AI-country arm, which corroborates the "list of province ids" reading from its node shape |
| `FINDINGS-aitheatre.md` open item 6, "`CEU3AI +0x2C` read as a gate and not explained" | the record already renamed it `runs_units`; this function's two arms are a second independent corroboration — agent plans for the human's country, priority provinces for an AI's |

**And explicitly, on the correction this work was told to watch:** nothing here contradicts `FINDINGS-theatre2.md` §4. It **confirms it from the producer's side.** `0x893E70` is called with the **target** area, its candidates are judged entirely by enemy neighbours and sea access from our capital, the answer is written into `+0x84` and an `invasion` order is issued on it. `0x89FBC0` iterates `CCountry +0xF98` — us plus every non-hostile country — prefers our own ground at 0.3× and writes `+0x88`. The two functions could not be more clearly opposite, and `+0x84` is the objective.

## 16. What a live session would settle in one look

1. **The region blacklist.** Start a Baltic or Black Sea war the AI should want to invade across and confirm no `CAIInvasion` ever appears with `+0x84` in a province whose `path_node_ptr->+0xA4` is one of `map/region.txt`'s `baltic_sea_region` / `black_sea_region` ids. One `dumpStruct.py` on a live `CAIInvasion` plus the file.
2. **`COASTAL_FORT_LEVEL`.** Raise coastal forts on one province of a two-port area and watch which one the invasion picks. This is the whole of §10's claim in one experiment.
3. **The port requirement.** No live `CAIInvasion` should ever have `(+0x84)->naval_base->+0x20 < 1000`. A single counterexample falsifies §6's first gate.
4. **`CProvinceTemplate +0x14`.** Dump it for a known lake, a known inland sea province and an ocean province; if it is 1, 0 and 0, the `is_lake` reading is settled.
5. **`CDiplomacyStatus +0x24`.** In a game with the Sino-Japanese undeclared war running, dump CHI's row of JAP's `+0xE28` array and check `+0x24` is the `CUndeclaredWar` and that its `+0x28` vector holds region objects.

## 17. What is not established

1. **`0x4FCB80`** — the Soviet-weakness measure of §7. Arithmetic fully read (`clamp((1000 - +0xBE4*1000/+0xBE0) * 1000 / (+0x10B8/100), 0, 1000)`, zero for a government in exile, 1000 when `+0xD08` is zero); meaning not. **Cheapest check:** read `0x9F8210`, one of its nine callers, which has the shape of a Lua accessor and would name it outright. Failing that, `CCountry +0xBE0`, `+0xBE4`, `+0xD08` and `+0x10B8` live for two countries, one healthy and one half conquered.
2. **`CProvinceTemplate +0x14`** — recorded as `unknown_flag_14`, `inferred`. The `is_lake` reading rests on one use. **Cheapest check:** live, item 4 above; or find its writer in the map loader.
3. **The tail of `0x8A9390`, past `0x8A98D0`** — the ideology and threat fallback, about `0x150` bytes, not read. Nor were `0x8A9A30` or `0x8ADE10`, the two helpers that can answer true before the table is reached. **Cheapest check:** read `0x8A9A30` (`0x8A9A30`–`0x8A9A76`, small) first; it is the one that short-circuits earliest.
4. **`CCurrentGameState +0xD0C`'s polarity in `0x8A9390`.** The record has it as `scenario`, "null in a loaded save", and the predicate returns **false** when it is non-null — so on that reading the whole faction-and-table half of the function only runs in a game loaded from a save, which is odd enough to be worth doubting one of the two readings. **Cheapest check:** read the byte in a running game started from a scenario, and again after a save-load.
5. **`CUnit` slot 35** (`[vft+0x8C]`), the test the lead transport applies to a sea province in §8, and **`CAIUnit` slot 74** (`[vft+0x128]`), which returns the agent's `CUnit`. Both read only as shapes; `whoslot.py` should count their holders before either is named (trap 4).
6. **`0x4D52A0`** — still only "a reachability test", now with its argument order fixed as `(CCountry*, from, to, bool)`. It is the gate that decides whether a country can mount an invasion at all, so it is the most valuable unread helper left in this chain.
7. **`ProvinceEdge.kind`'s full vocabulary.** Kind 1 (a crossing with a `crossed_province`) and kind 3 (impassable) are known; what kind 0 and anything else mean is not, and the `+10000` penalty of §6 turns on it. **Cheapest check:** `map/adjacencies.csv` against a live dump of one straits province's edge vector.
8. **`COwnerArea` slot 0**, the bool that gates an area in four places in this file alone, and `CProvinceTemplate +0x13D`, which the record already calls "1 in every province seen; not a land/sea flag" and which gates every edge here. Both unchanged from `FINDINGS-theatre2.md`.
9. **`CAIInvasion` slots 60, 61 and 70, and the three stage functions.** Untouched here, as the brief allowed — `0x893E70` took the time. `FINDINGS-theatre2.md` §3 and §5 remain the account of them. The one thing this file adds is that slot 61 is reached from outside the class, at `0x8949BF`, which is a second confirmation that it is the naval list getter.
10. **`0x4AF580` (`CTheatre::AddFront`)** — still only its first ~60 instructions. Whether it appends the `CAreaBorder` to `CTheatre +0x50`, and whether the `CTheatre +0x60` list reaches a save key, are both still open.
11. **Nothing was watched in a running game.** Every claim above is static, and §16 is the list of the cheap live falsifications this file adds.
