# `CAIUnit::SetArea` — how the operations area is drawn, and how it reaches the subordinates

`FINDINGS-aiplans.md` read slot 76, the plan builder, and named `CAIUnit::SetArea` plus the five `ReplanSubtree` callees as the biggest unread block left in the class. This is that block, together with the two bodies that actually issue `CSetPlanAxisCommand` and `CSetPlanForcesCommand` — neither of which is where the record said it was — and slot 83, which is the top-down distribution nobody had found.

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is marked *seen*. Addresses are **virtual** (image base `0x400000`) unless written `rva`.

## In one line

`SetArea` is the **second**, theatre-driven way an agent gets an operations area — slot 76 scores a front against objectives, `SetArea` takes the fronts of the theatre it is handed, keeps the front provinces that touch ground the agent may fight over, prunes that set against the AI's own province list at `CEU3AI +0x118`, writes the result into the agent's own `vector<CMapProvince*>` at `CAIUnit +0x90`, posts one `CSetPlanOpsAreaCommand`, and then runs the same five-call replan `ReplanSubtree` runs. The *axis* is the plan's drawn route and is written by `0x8C3330`; the *forces* are the plan's per-subunit brigade request and are written by `0x8B5210`; and the area reaches subordinates through slot 83 (`0x8C0790`) calling `0x8C0550`, which is the only function in the image that writes another agent's operations area.

## What `SetArea` sets, and on what

`void __cdecl CAIUnit::SetArea(CAIUnit* agent, CTheatre* area)`, `ret 8`, `0x8BA5A0`–`0x8BBAD6`, 5433 bytes, **no `ret` anywhere in the body before the single epilogue** (`image.retsBefore(0x8BA5A0, 0x8BB980)` is empty), so trap 2 and trap 3 both pass here and the five calls at `0x8BB980`–`0x8BB9A7` really are inside it.

It writes **nothing on the `CUnitPlan`**. Everything it changes is on the `CAIUnit`, on the `CArmy`, or inside a command:

| what | where | when |
| --- | --- | --- |
| `agent->area_dirty` (`+0x87`) = 0 | `0x8BA5C7` | **unconditionally, first instruction of the body** — before any of the guards |
| `agent->+0x338` freed and rebuilt | `0x8BA679`, through `0x8B0D20` | always |
| `agent->opsArea` (`+0x90`) cleared | `0x8BA6A1`, through `0x4A8590` (`vector::clear`) | always |
| `agent->opsArea` refilled | `0x8BAFD8`–`0x8BB051` and `0x8BB7E4`–`0x8BB8D7` | per accepted front province |
| entries erased from `agent->opsArea` again | `0x8BB530`–`0x8BB5C4` | the `CEU3AI +0x118` prune |
| `CSetPlanOpsAreaCommand(unit, &provinceIds)` posted | ctor `0x8BB6CB`, post `0x8BB954` | always reached |
| `CArmy +0x2EC` freed, then refilled from `CUnit +0x234` | `0x8BB9B8`–`0x8BBA00` | always |
| slot 82 called with **`false`** | `0x8BBA11` | always |
| `agent->+0x84 = 1`, `agent->+0x82 = 0` | `0x8BBA17`, `0x8BBA1E` | always |

So **the plan's ops area changes only through the command**, exactly as `FINDINGS-aiunit.md`'s "every AI unit decision goes through the command queue" says — but the agent's own copy at `+0x90` is written directly, and that copy is what the five replan callees consume. The `CUnitPlan` fields in `FINDINGS-aiplans.md`'s "New field layout" need no extension from this body; the new layout is all `CAIUnit`.

The guards, at `0x8BA5CD`–`0x8BA5E9`: it does nothing (beyond clearing `+0x87`) unless the agent has a unit (`+0x64`), the `area` argument is non-null, and `unit->oob_level` (`CUnit +0x1F4`) is 0. `project.json`'s existing comment on `0x4BA5A0` says exactly this and is right.

### The five passes, in order

**Pass A — the objectives' owner areas** (`0x8BA704`–`0x8BA7C7`). For each `CObjective` on `unit->plan.objectives` (`CUnit +0x234`), take its province, skip it if the province's **owner** id (`CMapProvince +0x330`) is this agent's country, and collect the distinct `COwnerArea*` (`+0x2B4`) into a local list. **This whole pass is skipped when `agent->owner->+0x2C` is set** (`0x8BA6FE`, `jne`), and `+0x2C` is set for every AI-run country — see *The one flag that splits the AI from the human* below. So objectives constrain `SetArea` only for a human's delegated AI.

**Pass B — the candidate fronts** (`0x8BA803`–`0x8BAA98`). `CList::AppendAllNodes` copies the handed theatre's own front list (`CTheatre +0x50`, `CAreaBorder` nodes) into a local list. Then, for each `COwnerArea*` on `agent->+0x338`, it resolves the area's controlling country, asks `0x895140(ourCountry, ownerArea, &out, 0)`, and when the out-byte is set adds the area to a second container *and* walks that controller's whole theatre list (`CCountry +0x570`), appending any front whose first province sits in that owner area, deduplicated. A front is skipped where the front's enemy is us, or — when we are in a faction and not at war with it, and neither side is `REB` — where `CCountry::IsSameSide` or the diplomacy status's `+0x24`/`0x4763A0` pair rules it out.

**Pass C — which fronts are objective-relevant** (`0x8BAA98`–`0x8BAC89`), run only when pass A found something. For each front, for each of its provinces, for each 20-byte adjacency record at `province->template(+0xD4)+0x90` (skipping edge kind 3, requiring template `+0x22` and `+0x13D`): if the neighbour is hostile — the inlined `CCountry::IsEnemy` shape, now identified exactly, see below — and its owner area is one of pass A's, the **front** is added to a third container.

**Pass D — the area itself** (`0x8BACA0`–`0x8BB0C8`). This is the loop that fills `+0x90`. Per front it computes a byte I will call `wideOpen` (`[esp+0x12]`):

```
wideOpen = (area->hot (CTheatre +0x70) == 0)
        || CAIStrategy::<0x8ADE10>(&country->strategy, front->enemyTag, front->enemyId)
        || (  country->strategy.threat[front->enemyId]          >= 40000        ; 0x8BAD15
           && countryDB[front->enemyId]->effective_neutrality   <= 20000 )      ; 0x8BAD1D
if (pass C found any front) wideOpen = 0                                        ; 0x8BAD31
```

and then processes the front only if `front->+0x28` is set, or `CAIStrategy::IsWarCandidate` (`0x8A9A30`) accepts its enemy, or (`wideOpen` and `0x8A9390` accepts its enemy), or the front is in pass C's set. Per province of an accepted front:

```
if (province->+0x5C < 200)                       continue     ; the g_AIProvinceFloor200 static
if (!province->area->IsValid())                  continue     ; COwnerArea slot 0
if (province->controller != our country
    && !0x4A56B0(province, 0)
    && countryDB[controller]->faction_leader_id != our id)  continue
for each adjacency edge, with the same three gates and the inlined IsEnemy:
    if (wideOpen-for-this-province)   require the neighbour's owner area to be one of pass A's
    else                             the first hostile neighbour with a valid owner area is enough
push province onto agent->opsArea (+0x90)   and   province->id (+0xD0) onto the command's id list
```

**Pass E — the `CEU3AI +0x118` prune** (`0x8BB0C8`–`0x8BB627`), run only when pass B's owner-area container is non-empty. For each province id in `agent->owner->+0x118` — the list `FINDINGS-aiplans.md` already records as adding 100 to an objective's priority — if that province's owner area is one of pass B's, or a neighbour of one (`COwnerArea +0x34`), then: if we are at war with its owner, the **three nearest** ops-area provinces to it are marked keep (seeded at `0x989680` = 10 000 000, `0x8BB27E`–`0x8BB3C4`); otherwise **every** ops-area province within `CMap::Distance` 100 of it is marked keep. Afterwards every ops-area province whose owner area is in pass B's set and which is *not* marked keep is erased from `+0x90` and its id removed from the command's list. So `CEU3AI +0x118` is a focusing list: inside those owner areas, only ground near a listed province survives.

**The second chance** (`0x8BB656`–`0x8BB943`). If the agent has an area id pair and `+0x90` came out **empty** and the theatre has fronts, it walks the theatre's own fronts again and, for each, computes

```
value  = countryDB[front->enemyId]->strategy.threat[our country id]
if (owner->+0x2C) value += our country->strategy.antagonize[front->enemyId]
if (value > 100) take every province of that front that passes the +0x5C and owner-area tests
```

using the two hash tables inside the embedded `CAIStrategy` (`CCountry +0x4DC`/`+0x4E0` is `strategy +0x50`/`+0x54`, the `threat` hash; `+0x4F8`/`+0x4FC` is `strategy +0x6C`/`+0x70`, `antagonize`). Then it posts, exactly once, whatever it has.

### The epilogue is an inlined `ReplanSubtree` plus two extras

```
0x8BB97E  0x8BBB50(agent, &agent->+0x90)
0x8BB987  0x8BC860(agent, &agent->+0x90)
0x8BB99B  if (unit->+0x208 == 0) 0x8BCD60(agent@ECX, &agent->+0x90)
0x8BB9A1  0x8BDF30(agent)
0x8BB9A7  0x8BD270(agent)
0x8BB9AC  free CArmy +0x2EC; CopyObjectiveList(&army->+0x2EC, &unit->+0x234)
0x8BBA11  agent->vf[82](false)
0x8BBA17  agent->+0x84 = 1; agent->+0x82 = 0
```

Compare `CAIUnit::ReplanSubtree` (`0x8DCA70`, 107 bytes, read end to end): the same five calls, then `vf[82](**true**)`, then recursion into every child agent, then `0x8C3330`. `SetArea` does not recurse and does not touch the axis; `ReplanSubtree` does not copy the objectives.

## `CSetPlanAxisCommand` — an axis is the plan's drawn route

`findRefs.py --callers 0x5E7FC0` gives exactly two sites: `0x5C2A93` (interface) and **`0x8C35F4`**, inside `0x8C3330`. `FINDINGS-aiunit.md` put this under "slot 76's subtree"; that is true only transitively — `0x8C3330` is reached from `ReplanSubtree` (`0x8DCAD2`), from slot 77 `SetPlanStance` (`0x8C382A`) **and from slot 73, the hourly tick** (`0x8B08D8`). It is not reached from `SetArea`.

The constructor is `CSetPlanAxisCommand(self, CUnit* unit, CList* path, CList* path2)` — 0x8C bytes, both lists copied node by node by `0x542F60` into `+0x64` and `+0x78` with their counts mirrored at `+0x74` and `+0x88`. Its `Execute` (slot 6, `0x5E80E0`) hands `plan = unit + 0x1FC` to **`CUnitPlan::CopyPath` (`0x8DF050`) and `CUnitPlan::CopyPath2` (`0x8DF0A0`)**. So from the bytes: an axis is *not* a direction code or an angle — it is the plan's two province paths, the arrow the player draws on the battle-plan map. That agrees with the command's three save keys (`path`, `path2`, `unit`) that `project.json` already records.

What decides the arguments, in `CAIUnit::UpdatePlanAxis` (`0x8C3330`, 956 bytes, read end to end):

1. return unless `agent->unit` exists; return if a theatre-level agent has a parent; **return unless `owner->+0x2C` is set** — so the AI never redraws a human-played country's arrows;
2. `agent->+0x80 = 1`;
3. **only if `CUnitPlan::stance` (`CUnit +0x208`) is 3 or 4** — the two highest of the 0–4 range `CEU3AI::UpdateUnitStances` produces — score every (ops-area province, plan objective province) pair: `0x5CE350(opsProv, objProv, 0, 0, tag, countryId)` must accept it, then the smallest `CMap::DistanceBetweenProvinces` wins;
4. hand the winning pair to `0x5A1A90(&agent->tag@ECX, from, to, &path)`, which fills a `CList` with a province route;
5. `path2` is **always left empty**: the `owner->+0x2C` test at `0x8C3578` that chooses between the two destination lists can only answer one way, because the function already returned when `+0x2C` was clear — a dead branch the compiler kept;
6. post only if the plan's `path` count (`CUnit +0x24C`), `path2` count (`+0x260`) or either list's contents differ from what was just computed.

So the AI draws an attack arrow only for an aggressive stance, from the ops-area province nearest an objective to that objective, and clears `path2` while doing it.

## `CSetPlanForcesCommand` — forces are brigades, and there are two planners

`findRefs.py --callers 0x5E87E0`: `0x8B6028` and `0x8B7D9B`. Neither is in slot 76's subtree either. The enclosing functions are `0x8B5210` and `0x8B60F0`, and **slot 73 picks between them**:

```
0x8B0B62  edx = gamestate->played_countries_array (+0xBCC)
0x8B0B6F  if (edx[agent->countryId] == 0)  0x8B5210(agent)      ; an AI-run country
0x8B0B7D  else                             0x8B60F0(agent)      ; a human-played country
```

`CAIUnit::UpdatePlanForces` (`0x8B5210`, 3807 bytes) resolves the agent's `CCountry`, lazily builds the `CSubUnitDataBase` singleton, sums `+0x40` over the objects in the agent's vector at `+0x11C`/`+0x120` (one of the seven containers slot 78 rebuilds — so slot 78's output feeds the force request), adds `agent->+0x354 * 3 + agent->+0x370`, fills a `vector<int>` indexed by subunit type index (`definition +0x24`), compares it element by element against the plan's existing min vector (`CUnit +0x26C`/`+0x270`, already named `plan_subunit_wanted`) and posts only on a difference. `CSetPlanForcesCommand::Execute` hands that vector to `CUnitPlan::SetMinForces`. So **forces is the plan's minimum brigade composition per subunit type, not an allocation of units to the plan.**

`0x8B60F0` (7818 bytes) is the same job for a human-played country and also posts the `CSetPlanAttributesCommand` at `0x8B7E87`. Its body is unread.

The AI side's power estimate turns out to be a separate, smaller function: **`CAIUnit::UpdatePlanPowers` (`0x8B5060`)**, called from slot 63 `SetUnit` (`0x8BA02E`) and from `0x88E553`. It fills `agent->+0x35C` and `+0x360` as the out-parameters of `0x8B9490` and `0x8B9610` and, when either differs from the plan's current value divided by 1000, posts `CSetPlanAttributesCommand(unit, 5, 3, 3, +0x35C, +0x360)` at `0x8B5152`. The `5` and the two `3`s are out-of-range sentinels — the same trick slot 77 uses with `(stance, 3, 3)` and `0x8912D0` with `(5, 2, 2)` — so that call writes **only** `our_power`/`their_power`. That closes the loop on slot 78's commitment ladder: `CUnitPlan +0x80`/`+0x84` come from `CAIUnit +0x35C`/`+0x360`.

## The five `ReplanSubtree` callees

All five are called, in the same order, from exactly three places: `ReplanSubtree` (`0x8DCA70`), `SetArea` (`0x8BB980`+) and `CAIUnit::SetOpsAreaAndReplan` (`0x8C0550`). The third one, `0x8BCD60`, is the only conditional member, and **the condition is not what the record says**: every caller guards it with `unit->+0x208 == 0`, which is `CUnitPlan::stance == 0` (the plan is at `CUnit +0x1FC`, stance at `CUnitPlan +0xC`), not `plan.active` at `+0x204`. `FINDINGS-aiplans.md` has it as `unit->plan.active (+0x204) == 0`; the bytes at `0x8DCA90`, `0x8BB98F` and `0x8C05D0` are all `cmp dword ptr [eax + 0x208], 0`.

| address | size | signature | what it does |
| --- | --- | --- | --- |
| `0x8BBB50` | 3339 | `(agent, opsArea)`, `ret 8` | clears `agent->+0xC0`/`+0xC4` and walks the ops area and its adjacencies. **It also calls the route builder `0x5A1A90` at `0x8BC5C5`** and `CCountry::GetActingCapitalLocation` at `0x8BC25D`, and touches `agent->+0x1BC`–`+0x1D4` and `+0x298`. `project.json`'s existing name `CAIUnit_RebuildFrontFromOpsArea` and its `inferred` mark still stand; the route call is new and suggests the name is about a *route* through the area, not a front line. Middle still unread. |
| `0x8BC860` | 1276 | `(agent, opsArea)`, `ret 8` | clears **two** vectors, `+0xA0`/`+0xA4` and `+0xB0`/`+0xB4`, then walks the ops area's adjacencies and pushes onto `+0xA0` the outside neighbours the country **may enter** — `IsSameSide`, or access (`status +0x58`) and not an enemy — deduplicated three ways. Named `CAIUnit::RebuildAreaNeighbourProvinces`, *likely*; the middle (`0x8BC9DD`–`0x8BCC50`), which presumably fills `+0xB0` with the hostile half, is unread. |
| `0x8BCD60` | 1293 | `(this@ECX, opsArea)`, `ret 4` | resets the 0x3C-byte container at `+0x30C` (`0x8DCFC0`) and the one at `+0x2FC` (`0x481C80`), then for each ops-area province whose `+0x48` equals its own id looks it up in the map at `+0x30C` (`0x8DCF30` is that map's `operator[]`) and allocates a 0x1C-byte record where the slot is empty. `CAIUnit::RebuildOpsAreaProvinceRecords`, *inferred*. |
| `0x8BDF30` | 652 | `(agent)`, `ret 4`, returns `agent->+0x364` | **read end to end.** Zeroes `+0x364`, `+0x365`, `+0x366`; sets `+0x366` per ops-area province unless all of (`gamestate +0xD0C` zero, province not ours, `owner->+0x2C` set); sets `+0x364`/`+0x365` together (as the word `0x101`) when any adjacent province's controller is one we are at war with, and `+0x365` alone when `CAIStrategy::IsWarCandidate` accepts it. `CAIUnit::ClassifyOpsAreaFrontier`, *confirmed*. |
| `0x8BD270` | 2632 | `(agent)`, `ret 4` | returns at once unless the agent has a unit and ≥1 ops-area province; computes `(m % n) / (float)n` where `n` is the ops-area size and `m` the element count of `+0x12C`/`+0x130`; zeroes the floats `+0x34C` and `+0x350`; resets the containers at `+0x2D0` and `+0x2C0`. Further in it averages `CCountry +0xCC` over a list of tags and compares against 150 and 50 — both `(int)floorf(N.5f)` statics, trap 8 case 3. `CAIUnit::ApportionOpsArea`, *inferred*; the middle is the one genuinely unread body of the five. |

### What makes the AI replan rather than keep a plan

Five distinct triggers, all read:

1. **The weekly re-anchor.** Slot 73 calls `GetArea` then `SetArea` when `agent->+0x87` (`area_dirty`) is set, or at hour 1 of a day where `dayOfYear % 7 == 0` (`0x8B085A`–`0x8B08BE`). `CEU3AI::EnsureAgentForArea` (`0x88A880`) sets `+0x87`.
2. **A theatre adoption.** Slot 76 step 1 calls `SetArea` at `0x8DAD31` when it adopts a theatre.
3. **A unit change.** Slot 63 `SetUnit` calls `SetArea` at `0x8B9F41` and `UpdatePlanPowers` at `0x8BA02E`.
4. **A new ops area.** Slot 76's own post is followed by `ReplanSubtree` (`0x8DCAC7` etc.).
5. **A stance change.** Slot 77 calls `0x8BCD60`, `0x8BD270` and `0x8C3330` directly.

And three things are only ever posted on a *difference*, which is the brake on all of it: the axis (`0x8C35A5`–`0x8C35C9`, counts and contents), the forces (`0x8B5FD5`–`0x8B5FFD`, length and every element) and the powers (`0x8B50E0`/`0x8B5112`, both compared after dividing by 1000). Slot 83 does the same for a subordinate's area.

## How the area propagates down an OOB subtree

This is the part nobody had. `CAIUnit::SetOpsAreaAndReplan` (`0x8C0550`, 165 bytes, read end to end) is

```
void __stdcall (CAIUnit* agent, vector<CMapProvince*>* newArea)
    clear agent->+0x90 ; vector::assign(&agent->+0x90, newArea)      ; 0x8DD860
    0x8BBB50(agent, &agent->+0x90)
    0x8BC860(agent, &agent->+0x90)
    if (agent->unit->+0x208 == 0) 0x8BCD60(agent@ECX, &agent->+0x90)
    0x8BDF30(agent) ; 0x8BD270(agent)
```

**It is the only function in the image that writes an operations area onto an agent other than the one computing it, and it has exactly one caller** — `0x8C156C`, inside **`CAIUnit` slot 83, `0x8C0790`**. `findRefs.py --callers 0x8C0550` gives that one site; `--callers` on the slot bodies `0x8C0600`, `0x8C0790`, `0x8C1790`, `0x8DAB00` gives zero each, so every one of them is reached only through the vftable.

Slot 83, `bool __thiscall CAIUnit::DistributeOpsAreaToSubordinates()`, `0x8C0790` to the bare `ret` at `0x8C177A`. **It is a fresh instance of trap 3**: two `_CxxThrowException` arms (`"list<T> too long"`, `"vector<T> too long"`) sit after that `ret`, out to `0x8C178E`, and slot 84 begins at `0x8C1790`.

Its entry test is the exact mirror of slot 76's: it answers false unless the agent's unit is **below** theatre level (`oob_level != 0`) or the agent records no area id pair, and unless its own `+0x90` is non-empty. Then:

1. build a `std::map<COwnerArea*,int>` of the ops area keyed by owner area (`0x8DD000` constructs, `0x8DCF30` is `operator[]`), and a list of the ops-area provinces with **exactly one** usable neighbour outside the area — the chokepoints;
2. for each child unit of its own unit that passes `vf[15]`, whose first province's owner area is the current one or a neighbour of it, build a **`CIDValue`** (RTTI-named, vftable `0x15EC094`, 20 bytes: `+4 = 0x18D`, `+8`/`+0xC` the child's object id pair, `+0x10 = divisions * 1000` from `CUnit::CountDivisions`) and push it onto a weight list, accumulating the total;
3. (scoring middle, `0x8C0D60`–`0x8C13A0`, **not read**) — this is where the slice per subordinate is chosen;
4. per subordinate: count how many of the slice are already in the subordinate's plan ops area (`CUnit +0x214` list) and skip if that equals the plan's count at `+0x21C`; otherwise post `CSetPlanOpsAreaCommand(subUnit, &provinceIds)` at `0x8C1491`; then, where the subordinate has an agent (`CUnit +0x198`) whose slot 65 answers true, call `SetOpsAreaAndReplan` on it with the slice (`0x8C156C`).

**So the mechanism is: parent agent computes an area → slot 83 slices it by subordinate division weight → one `CSetPlanOpsAreaCommand` per subordinate unit *and* a direct write into the subordinate agent's `+0x90` followed by its own five-call replan.** The subordinate agents never compute an area of their own; slot 76 refuses to, and `SetArea` refuses to for any unit above `oob_level` 0.

**The open end, and it is a real one.** `slotcalls.py 83` reports 30 sites in 23 functions and **not one of them is in `CAIUnit`'s code**; the one in the AI module, `0x881733`, is `gamestate->in_game_screen`'s own slot 83. A targeted exhaustive scan of `0x880000`–`0x8E0000` for every instruction using displacement `0x14C` finds ten, all of them plain field accesses (`CAIUnit +0x14C` is one of slot 78's vectors) and the `CInGameIdler` one. **Positive control: the same `slotcalls.py` run for slot 82 (`+0x148`) finds its three real dispatches — `0x8B099B` in slot 73, `0x8BBA07` in `SetArea`, `0x8DCAAF` in `ReplanSubtree` — all three of which were read independently.** So the method can see this shape in this code, and its silence about slot 83 means something. Either slot 83 is dead in this build, or it is entered by a route this scan cannot see. The first is not claimed; the cheapest live check is a BiceLib hook on `0x8C0790` (worker-thread safe: log a counter only) for one game month.

## The one flag that splits the AI from the human

`CEU3AI +0x2C` gates four things in this code, traced to both ends:

- `CEU3AI`'s constructor (`0x888020`, vftable `0x15EB660`) seeds **`+0x2C = 1`** at `0x8880BA`;
- `ProcessAI` (`0x8894E0`) clears it at `0x8895BA`, once, guarded on it still being set, when `ai->tag.id == gamestate->player_id` (`+0xC34`).

So **`+0x2C` is 1 for every AI-run country and 0 for the human's own country.** Its consumers:

| site | effect when `+0x2C` is clear (the human's delegated AI) |
| --- | --- |
| `0x8C3330` entry | returns at once — **the AI never redraws the human's attack arrows** |
| slot 82 `0x8C0679` | no `CSetCommandLevel` posted |
| `SetArea` `0x8BA6FE` | the objectives→owner-areas pass **does** run, and so the ops area is constrained to fronts that face the objectives; for an AI country that pass is skipped and the front choice falls back to the hot/threat/strategy tests |
| `0x8BDF30` `0x8BE02A` | `+0x366` is set unconditionally |

The same split appears a second, independent way in slot 73's `played_countries_array[countryId]` branch between `0x8B5210` and `0x8B60F0`. Two different mechanisms encoding the same distinction is good corroboration for both.

## Corrections to the record

1. **`CAIUnit +0xB0` is not a `COrder*`.** `project.json` has `CAIUnit +0xB0 = order (COrder*)`, sourced to `UnitHasBlockingOrder` (`0x4AF4E0` rva). That function's receiver is in `ESI` and reads `[esi+0x2CC]` and `[esi+0xB0]`; at its call site `0x8B3398` the receiver was just used with `+0x28C`/`+0x290` (a `CCountryTag` indexing the country database) and at `0x8C292D` with `+0x1F4`, which is `CUnit::oob_level`. **The receiver is a `CUnit`**, and `CUnit +0x2CC` is already named `movement destination province id` in `FINDINGS-aiplans.md`. Meanwhile `0x8BC860` clears `agent->+0xB0`/`+0xB4` with the standard zero-length-memmove vector-clear idiom at `0x8BC8B2`–`0x8BC8DD`. So `CAIUnit +0xB0`/`+0xB4`/`+0xB8` is a `vector<CMapProvince*>`, the `order` field belongs on `CUnit`, and `UnitHasBlockingOrder`'s entry should say `CUnit*`.
2. **`0x8BCD60`'s guard is `plan.stance == 0`, not `plan.active == 0`** — `FINDINGS-aiplans.md`, the `ReplanSubtree` listing. `CUnit +0x208` is `CUnitPlan +0xC`.
3. **`CSetPlanForcesCommand` is not issued in slot 76's subtree** — `FINDINGS-aiunit.md`'s command table. Both sites are slot 73's callees (`0x8B5210`, `0x8B60F0`). And `CSetPlanAxisCommand`'s one AI site, `0x8C3330`, is reached from slot 73 and slot 77 as well as from `ReplanSubtree`.
4. **`CSetPlanOpsAreaCommand` has two more AI sites** than the table shows: `0x8BB6CB` in `SetArea` and `0x8C1491` in slot 83, beside slot 76's three.
5. **`GetOwnerAI` on a `CAIUnit` does not reliably answer null.** `FINDINGS-aiunit.md` says the constructor zeroes `+0x54` so the luabind getter answers null. Slot 82 *writes* `+0x54` at `0x8C0775`, from `0x8DA340(this, unit->oob_level)`. After slot 82 has run once on an agent, `GetOwnerAI` hands back whatever that returned — which is not a `CEU3AI*`. Anyone scripting against it should treat the answer as garbage, not as null.
6. **`FINDINGS-aiunit.md`'s open item 5 is already closed in `project.json`.** `CCountry +0x48C` is the embedded `CAIStrategy` (`strategy`), and its `+0xE4` is the `area_theatre` `CList<CTheatre*>`. The three unnamed functions the AI calls on it — `0x8ADE10`, `0x8A9A30`, `0x8A9390` — are `CAIStrategy` methods, all reached as `reg = country + 0x48C`.

## New field layout

```
CAIUnit  (0x374 bytes, vftable 0x15EC0B4)
  +0x54  int      NOT permanently zero: slot 82 writes it from 0x8DA340(this, oob_level) at 0x8C0775
  +0x82  byte     cleared by SetArea at 0x8BBA1E
  +0x84  byte     set to 1 by SetArea at 0x8BBA17 (the ctor already seeds it 1 via +0x84 = 0x10101)
  +0xA0/+0xA4/+0xA8  vector<CMapProvince*>: the ops area's outside neighbours the country MAY enter.
                     Cleared and refilled by 0x8BC860 every replan; push_back at 0x8BCD12
  +0xB0/+0xB4/+0xB8  a second such vector, cleared by 0x8BC860 at 0x8BC8B2. **NOT the COrder* the
                     record has here** - see Corrections 1
  +0x2C0, +0x2D0     containers 0x8BD270 resets
  +0x2FC             a container 0x8BCD60 resets through 0x481C80
  +0x30C             a std::map keyed by CMapProvince*, rebuilt by 0x8BCD60; 0x8DCF30 is its operator[]
  +0x338/+0x33C/+0x340  CList<COwnerArea*>. Rebuilt by CAIUnit::RebuildFocusOwnerAreas (0x8B0D20) from
                     the agent's theatre's +0x84 list through 0x8B0F20; read by SetArea pass B to widen
                     the front search past its own theatre
  +0x34C, +0x350  float   zeroed by 0x8BD270 at 0x8BD2F5/0x8BD2FD
  +0x354  int      return value of 0x8B9610; read by UpdatePlanForces as +0x354 * 3 + +0x370
  +0x358  int      return value of 0x8B9490
  +0x35C  int      our_power  - the CSetPlanAttributesCommand argument at 0x8B5152 -> CUnitPlan +0x80
  +0x360  int      their_power - the same call                                     -> CUnitPlan +0x84
  +0x364  byte     frontier_at_war        } written as the word 0x101 at 0x8BE11D
  +0x365  byte     frontier_war_candidate }
  +0x366  byte     frontier_controlled; ctor seeds 1, 0x8BDF30 recomputes

CEU3AI
  +0x2C   byte     1 for an AI-run country, 0 for the human's own. Seeded 1 by the ctor (0x8880BA),
                   cleared once by ProcessAI at 0x8895BA for the played country

CAIStrategy  (embedded at CCountry +0x48C)
  +0x50/+0x54  the bucket count (0x1FF) and bucket array of the hash over the `threat` list at +0x3C.
               Node payload: key at +0xC, value at +0x10. Read as threat[countryId] at 0x8BB70E
  +0x6C/+0x70  the same for `antagonize` at +0x58; read at 0x8BB75D

CDiplomacyStatus  (the entries of CCountry +0xE28, indexed by country id)
  +0x20   int   at_war. Read as exactly that by CCountry::IsEnemyTag (0x42F1B0) and by its twelve
                inlined copies through CAIUnit's area code
  +0x24   a war-shaped object: 0x4763A0(it@EAX, province@ECX) matches its +0x28/+0x2C id vector
                against the province's +0x358 list. Unresolved
  +0x5C   int   compared against 40000 in SetArea's wideOpen test (0x8BAD15). Unresolved

CMapProvince
  +0x330  int   the OWNER id (the id half of the `owner` tag at +0x32C), as against the controller id
                at +0x338. SetArea pass A keys on it at 0x8BA740, pass E at 0x8BB173
  +0x5C   int   compared against the static 200 as the FIRST filter on every province the unit AI will
                put in an operations area (0x8BADBA, 0x8BB7C7). Nine AI readers. Unresolved

CAreaBorder
  +0x28   byte  set -> SetArea processes this front unconditionally (0x8BAD38)

CTheatre
  +0x84   a CList whose entries hold a COwnerArea* at +0x6C; RebuildFocusOwnerAreas walks it
```

## Functions this named

| address | rva | name | how sure |
| --- | --- | --- | --- |
| `0x8C3330` | `0x4C3330` | `CAIUnit::UpdatePlanAxis` — issues `CSetPlanAxisCommand` | read end to end |
| `0x8C0550` | `0x4C0550` | `CAIUnit::SetOpsAreaAndReplan` | read end to end |
| `0x8C0790` | `0x4C0790` | `CAIUnit::DistributeOpsAreaToSubordinates` (slot 83) | entry, weights and output read; scoring middle not |
| `0x8B5210` | `0x4B5210` | `CAIUnit::UpdatePlanForces` — issues `CSetPlanForcesCommand` | head and output read |
| `0x8B60F0` | `0x4B60F0` | `CAIUnit::UpdatePlanForcesForPlayedCountry` | dispatch only; body unread |
| `0x8B5060` | `0x4B5060` | `CAIUnit::UpdatePlanPowers` | read end to end |
| `0x8B0D20` | `0x4B0D20` | `CAIUnit::RebuildFocusOwnerAreas` | read end to end |
| `0x8BA550` | `0x4BA550` | `CAIUnit::GetWantedCommandLevel` | from its one use; body unread |
| `0x8BDF30` | `0x4BDF30` | `CAIUnit::ClassifyOpsAreaFrontier` | read end to end |
| `0x8BC860` | `0x4BC860` | `CAIUnit::RebuildAreaNeighbourProvinces` | head and tail read |
| `0x8BCD60` | `0x4BCD60` | `CAIUnit::RebuildOpsAreaProvinceRecords` | head only |
| `0x8BD270` | `0x4BD270` | `CAIUnit::ApportionOpsArea` | head and the float section only |
| `0x5E7FC0` | `0x1E7FC0` | `CSetPlanAxisCommand::CSetPlanAxisCommand(self, unit, path, path2)` | read |
| `0x5E80E0` | `0x1E80E0` | `CSetPlanAxisCommand::Execute` — `CopyPath` + `CopyPath2` | read |
| `0x5E87E0` | `0x1E87E0` | `CSetPlanForcesCommand::CSetPlanForcesCommand(self, unit, min)` | read at the call site |
| `0x42F1B0` | `0x2F1B0` | `CCountry::IsEnemyTag` — the tag-only sibling of `0x42F210` | read end to end |
| `0x5A1A90` | `0x1A1A90` | `CCountryTag::FindProvinceRoute(from, to, outPath)` | inference from its consumer |
| `0x8A9A30` | `0x4A9A30` | `CAIStrategy::IsWarCandidate(tag, id)`, receiver in **EDI** | head read; name inferred |
| `0x1B151E4` | `0x17151E4` | `g_AIProvinceFloor200` — `(int)floorf(200.5f)`, initialiser at `0xD118D0` | read |
| `0x4A8590` | `0xA8590` | `std::vector<T*>::clear` — the same memmove idiom, 1 arg, `ret 4` | read end to end |

## What is not established

1. **How `CAIUnit` slot 83 is entered.** The distribution path is read; nothing calls it. Exhaustive `0x14C` scan over `0x880000`–`0x8E0000`, with slot 82 as a positive control that the method found all three of. This is the single most important open question here, because if it is never entered no subordinate agent ever receives an area.
2. **The middle of slot 83** (`0x8C0D60`–`0x8C13A0`) — how the parent's area is actually sliced per subordinate, given the `CIDValue` division weights. The `0x8BE1C0` helper it uses (10 callers) is unread.
3. **`CMapProvince +0x5C`** and its 200 floor. Nine AI readers, and it is the first gate on every province the AI will fight over, so a wrong guess here mis-states the whole area calculation. The cheapest check is live: `dumpStruct.py` a handful of provinces and compare `+0x5C` against anything in the savegame for the same province.
4. **`0x895140`** (4 args, out-bool), the predicate that decides which of the agent's focus owner areas widen the front search, and **`0x8ADE10`** / **`0x8A9390`**, the other two `CAIStrategy` methods in `SetArea`'s front gate.
5. **`CDiplomacyStatus +0x5C`** (the 40000 threshold) and **`CCountry +0xCC`** (the 150/50 thresholds in `0x8BD270`). Both look like thousandths, which would make them 40.0, 150.0 and 50.0, but there is no second reader to confirm the scale — trap 7 cuts both ways.
6. **`0x8BD270`'s middle** and `0x8BBB50`'s middle — the two unread bodies of the five, 2.6 KB and 3.3 KB.
7. **`0x8B60F0`** (7.8 KB), still unread, and now known to be the *human-played* country's force planner rather than a general one.
8. **`0x8DA340`**, whose return value slot 82 stores in `CAIUnit +0x54`, and **`0x8B9490`/`0x8B9610`**, which produce `our_power`/`their_power`.
9. **`CTheatre +0x84`** and `0x8B0F20`, the two halves of how `+0x338` is filled, and `0x803F0`'s `> 1` test that gates it.
10. **Whether `path2` is ever non-empty for an AI plan.** The only AI writer leaves it empty on a provably dead branch, and the command always replaces both lists, so an AI replan should erase any `path2` a human drew on a delegated unit. One game settles it: draw a two-arm plan on a unit, delegate it, and see whether the second arm survives the hour.
11. **Nothing was watched in a running game.** Three cheap checks that would falsify the central claims: `CEU3AI +0x2C` should read 1 on every AI country and 0 on the player's; a subordinate land agent's `+0x90` vector should be non-empty if and only if slot 83 is in fact reached; and an AI unit's plan `path` should be non-empty only while its `plan.stance` is 3 or 4.
