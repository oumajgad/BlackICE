# How the AI decides where its armies go

`FINDINGS-aiunit.md` mapped `CAIUnit` and named two bodies as the highest-value unread code in the class. This is those two, read line by line, plus what the reading dragged in with it: the `CUnitPlan` the AI is writing, the objective generator that feeds it, and the stance decider that is **not** in `CAIUnit` at all.

Read statically off `C:\Users\David\Hearts of Iron 3\hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is marked *seen*. Addresses are **virtual** (image base `0x400000`) unless written `rva`.

## In one line

The AI does not invent a front. It takes the **fronts the theatre layer already draws** (`CAreaBorder`, one per theatre per neighbour), scores every front province against the unit's own **plan objectives** by map distance with two 10× proximity bonuses, takes the nearest one, and then claims **its fair share of that front by division count** — `round(myDivisions × frontLength / unitsOnThatFront)` provinces — as the plan's operations area. It then pushes the objectives down to the subordinates and re-plans the whole agent subtree. Everything leaves through `CSetPlanOpsAreaCommand`, so the mod's command-level hooks see all of it.

## Correction to `FINDINGS-aiunit.md`: slot 78 does not issue the detach and expedition commands

The predecessor's command table put `CDetachUnitCommand` (`0x5DE1D0`) and `CSendExpeditionCommand` (`0x5E95B0`) in **slots 78, 79**. `findRefs.py --callers` settles it:

| command | call sites inside `CAIUnit` | which slot that is |
| --- | --- | --- |
| `CDetachUnitCommand` `0x5DE1D0` | `0x8B34D1` | **slot 79** (`0x8B32E0`–`0x8B3A46`) |
| `CSendExpeditionCommand` `0x5E95B0` | `0x8B35C5`, `0x8B3973` | **slot 79** |
| `CTransferSubUnitCommand` `0x5DCA90` | `0x8CE90E`, `0x8D1341`, `0x8D1BEB` | **neither** — three unnamed bodies |
| `CSetAIParamCommand` `0x5E90B0` | `0x8B24CB` | **slot 78** |

So **slot 78 issues exactly one command, `CSetAIParamCommand`**, and the detach/expedition logic is slot 79's. This is trap 3 biting the predecessor the other way round: slot 78's `ret` at `0x8B32AC` is not the end (an EH funclet runs to `0x8B32DF`), but slot 79 begins at `0x8B32E0`. Reading "slot 78" as `0x8B1D10`–`0x8B3A46` is what produced the wrong table.

## Slot 76, `0x8DABD0`–`0x8DCA6A` — the plan builder

`bool __thiscall CAIUnit::BuildPlan()`. Bare `ret`, no arguments, **answers whether it posted a command** — the byte `[esp+0x27]`, seeded 0 at `0x8DAC1B`, set to 1 beside every post, returned at `0x8DCA59`. Four exits: `0x8DAC17`, `0x8DAD9F`, `0x8DAE63`, `0x8DCA6A`.

Two locals carry the function:

```
[esp+0x18]   this
[esp+0x20]   CCountryTag::GetCountry(&this->tag)  - the agent's own CCountry*
```

`[esp+0x20]` is written at `0x8DAC2C` as `[esp+0x28]` with two pushes outstanding; that eight-byte offset is the kind of thing that makes a frame unreadable, and it is also why every `0x4EFA00`/`0x4EF7C0`/`0x4EE110` call in the body has a `CCountry*` in `ecx`.

### Step 0 — only the topmost agent in an OOB chain plans

```
edi = this->unit (+0x64);   if (!edi) return false
GetCountry(&this->tag)
0x89A080(this->owner (+0x60), unit)              ; prunes agents under this unit
climb higher_oob_unit_ptr (CUnit +0x1E0), keeping the last non-null CUnit +0x198
if (that agent != this) goto the epilogue and return false
```

An agent whose unit has a planning ancestor does nothing here; the ancestor plans for it and pushes the result down (`0x8DAC50`–`0x8DAC69`).

### Step 1 — the theatre-adoption path, and the only stance slot 76 ever writes

Taken when `unit->oob_level (+0x1F4) == 0` **and** `unit->current_province (+0x130) != 0` (`0x8DAC71`–`0x8DAC83`). It walks `CCountry +0x570`, the theatre list, and for each theatre:

1. skips it if any other `CAIUnit` on `owner->+0x40` already records that theatre's id pair in its own `+0x68`/`+0x6C` and commands a unit at `oob_level` 0 (`0x8DACB0`–`0x8DACED`);
2. resolves the theatre's `unit` key (`CTheatre +0x74`/`+0x78`) through `0xA9D390` and requires it to be **this agent's own unit** (`0x8DAD1E`);
3. adopts it — `this->+0x68 = theatre->id_type`, `this->+0x6C = theatre->id`, then `CAIUnit::SetArea(this, theatre)`;
4. posts `CSetPlanAttributesCommand(unit, 1, 0, 0, -1000, -1000)` and returns true.

By the sentinels `project.json` already records for that command, those six arguments mean **active = true, stance = 1, air_stance = 0, naval_stance = 0, our_power and their_power unchanged** (both negative, which that command skips). The plan's constructor defaults stance to 2 and both air/naval stances to 1, so the theatre agent is deliberately moved off the defaults.

**That is the only stance slot 76 writes, and it is a constant.**

### Step 2 — the frontier province off the plan's drawn path

`CUnit +0x244` is `CUnitPlan +0x48`, the plan's **`path`** list (project.json's `CUnitPlan::CUnitPlan` lays the object out). Slot 76 walks it and stops at the last province whose *successor* the agent may not enter:

```
for (node in unit->plan.path) {
    prov = gamestate->provinces[node->id]
    if (node->next) {
        if (!CanOperateIn(country, &provinces[next->id]->controller))   ; 0x4EFA00
            chosen = prov; break
    } else {
        for each adjacency edge of prov (20-byte records at prov->template(+0xD4)+0x90) {
            if (edge->kind (+0x0) == 3) continue
            nb = gamestate->provinces[edge->neighbour (+0x4)]
            if (!nb->template->+0x22) continue
            if (!nb->owner_area (+0x2B4)->IsValid()) continue           ; COwnerArea slot 0
            if (!nb->template->+0x13D) continue
            if (!CanOperateIn(country, &nb->controller)) { chosen = prov; break }
        }
    }
}
```

`chosen` is `[esp+0x28]`. If the plan has no path, or the path never reaches hostile ground, `chosen` stays null and the function takes the fallback at step 5.

### Step 3 — the candidate fronts

```
0x4EE110(country, &tags)          ; every country the agent may operate in
for (t in tags) allTheatres += countryDatabase[t.id]->theatres (+0x570)
```

`0x4EE110` walks every country in the game and keeps those that pass the same filter `0x4EFA00` applies — allied/same-faction, or has granted military access and is not an enemy — skipping id 0 and `REB`. One caller in the image: this one.

`allTheatres` is `[esp+0xA0]`. Its members' **`+0x50` lists are `CAreaBorder`s**, which `CLASSES.md` already names `front`, each carrying its province array as the `PAVCProvince::__CArray` base at `+0x8`/`+0xC`.

### Step 4 — score every front province against every objective (the main path)

For each `CObjective` on `unit->plan.objectives` (`CUnit +0x234`):

* skip the objective if `CCountry::IsFriendly(country, &objProv->controller, true)` (`0x4EF7C0`) — **the AI will not build a front against a province it is friendly with**;
* for every front of every candidate theatre, for every province `p` of that front, ask whether the front is live against the same enemy as the objective: `p` must be adjacent to some `nb` with a usable owner area and template, and either `nb->controller == objProv->controller`, or **both** `objProv` and `nb` are enemies by the province-aware `CCountry::IsEnemy` (`0x42F210`, inlined twice at `0x8DB3DD`–`0x8DB4D2`). Such a front is added, deduplicated, to `[esp+0x90]`;
* and score it:

```
score = (float)(CMap::Distance(p, objProv) + 10.0)
if (unit->current_province->theatre_id == thisTheatre->id)  score *= 0.1
if (unit->current_province->owner_area == p->owner_area)    score *= 0.1
else if (that owner area is in the unit's area's neighbour list at +0x34) score *= 0.1
```

(`0x8DB55F`–`0x8DB664`; the two 0.1 multipliers compose, so a front in your own theatre *and* your own region scores 100× better than the same distance elsewhere. The `+10` keeps the product non-zero when the objective is on the front province itself.)

The lowest score wins and records three things: the front province (`[esp+0x28]`), its theatre (`[esp+0x30]`) and a pointer to the front's province array (`[esp+0x3C]`).

`CMap::Distance` is `0x492030(provA@EAX, provB@EDX, CMap*)`: four times the integer square root of the squared difference of `CMap +0x2A60`'s per-province `+0x2C`/`+0x30` coordinates, with a wrap at half the width at `CMap +0x2A74`. It is straight-line distance on the map, **not** a path length — 77 callers in the image.

### Step 5 — how much of that front the agent takes

This is the answer to "what decides the ops area" (`0x8DBF77`–`0x8DC25D`):

```
myDivisions = (unit->isLand() && unit->oob_level >= 4 ? 1 : 0)
            + sum over unit->children of CountDivisions(child)        ; 0x5BDB00
unitsOnFront = the number of the country's land leaf units belonging to *other* agents
               whose destination (0x89AF00) or current province is one of this front's provinces
frontLength  = the front's province count

density = (float)(myDivisions + unitsOnFront) / (float)frontLength
share   = density > 0 ? max(1, (int)round(myDivisions / density)) : 1
share   = min(share, myDivisions)
```

`share = round(myDivisions × frontLength / (myDivisions + unitsOnFront))`, clamped to `[1, myDivisions]`. **It mixes units with divisions** — `myDivisions` counts `oob_level >= 4` bodies, `unitsOnFront` counts leaf units — which is in the bytes and may well be a bug, but it is what the game does.

The area is then built as:

* the chosen front province, and
* the `share - 1` further front provinces **nearest the chosen one** by `CMap::Distance` (`0x8DC3C0`–`0x8DC581`), and
* every province of every *other* collected front that lies in an owner area where this agent has **at least as many** leaf units as all other agents put together (`0x8DC587`–`0x8DC741`; the test is `mine < others -> skip`, so a tie counts as ours).

Each one goes into two places: a `CList` of province **ids** that becomes the command's payload, and the agent's own `vector<CMapProvince*>` at **`CAIUnit +0x90`/`+0x94`/`+0x98`** — a field nobody had named.

### Step 6 — what is posted, and what happens next

```
cmd = new CSetPlanOpsAreaCommand(unit, &provinceIds)           ; 0x5E60B0, 0x78 bytes
gamestate->idler(+0xBE8)->session(slot 18)->channel(+0x38)->post(slot 6, cmd)
free CArmy +0x2EC; CopyObjectiveList(&army->+0x2EC, &unit->plan.objectives)
CAIUnit::ReplanSubtree(this)                                   ; 0x8DCA70
return true
```

`0x8DCA70` is the recursive re-plan and it is what spends the `+0x90` vector:

```
0x8BBB50(this, &this->opsArea)      ; rebuilds the vector at CAIUnit +0xC0 from it
0x8BC860(this, &this->opsArea)
if (unit && unit->plan.active (+0x204) == 0) 0x8BCD60(this, &this->opsArea)
0x8BDF30(this); 0x8BD270(this)
this->vf[82](true)                  ; the CSetCommandLevel slot
for (child in this->children (+0x44)) ReplanSubtree(child)
0x8C3330(this)
```

That is where `CSetPlanAxisCommand` and `CSetPlanForcesCommand` live — the predecessor was right to call them "slot 76's subtree", and this is the function that is the subtree.

**`CSetPlanOpsAreaCommand::Execute` sets the ops area, not the fallback line.** Its `+0x74` byte chooses between `CUnitPlan::SetFallbackLine` and `CUnitPlan::SetOpsArea`, and the constructor leaves it zero at `0x5E616B`, so every command slot 76 builds takes the `SetOpsArea` arm — which also calls `CUnit::RefreshPlanForceNeeds`, so **changing the ops area changes what the plan asks for in brigades**. The constructor copies the list node by node (`0x542F60` in a loop), so the source list is not consumed.

### Step 7 — the fallback, and a double command that looks wrong

When no front scored against any objective (`chosen == 0` at `0x8DB69B`), `0x8DB6A5`–`0x8DBE3E` runs a second, looser pass: for each objective in a province the agent may enter, for each front of each candidate theatre, it takes the front provinces that are **in the same owner area as the objective**, within `600.0` of it by `CMap::Distance`, whose relevant neighbour's owner area holds **fewer than 5** provinces (`0x8DBA56`, `0x8DBBEF`).

Then, at `0x8DBCD3`:

```
if (unit->plan.ops_area_count (+0x21C) > 0 || this->opsArea is non-empty)
    post CSetPlanOpsAreaCommand(unit, &provinces)
    re-copy the objectives into CArmy +0x2EC; ReplanSubtree
free both lists and zero the province list
erase this->opsArea                                            ; 0x4440B0, vector::erase(all)
if (unit->plan.ops_area_count (+0x21C) > 0)
    post CSetPlanOpsAreaCommand(unit, &provinces)               ; <- the list is now EMPTY
re-copy the objectives into CArmy +0x2EC; ReplanSubtree
```

**Both posts are on the same straight-line path.** `0x8DBE39` falls through to `0x8DBE3E`, the free loop at `0x8DBE3E`–`0x8DBE56` empties `[esp+0x7C]`, `0x8DBE72` zeroes its head/tail/count, and `0x8DBEE1` hands the same `[esp+0x7C]` to the second constructor. Commands execute in queue order, so when a unit already had an ops area and slot 76 reached the fallback, **the second command undoes the first**: the net effect is that the ops area is cleared. I checked the frame offsets three times — `esp` is at its base at both `lea` sites, and `[esp+0x18]` is `this` at both tests — and I cannot read it any other way. Two readings are possible and the image cannot choose between them:

* it is a bug, and a unit the AI cannot find a front for loses its ops area entirely; or
* clearing is the intent, and the first post is dead work whose payload is usually empty anyway (the fallback's three filters are strict).

Either way **the main path is unaffected** — it posts once, at `0x8DC747`, and jumps straight to the shared epilogue. A live check would settle it in one game: watch a land unit under AI control with an ops area and no reachable objective and see whether its area survives the hour.

### Which defines slot 76 reads: none

No `call GetDefines (0x445D90)`, no reference to the `0x1A86040` singleton, and no `0x8EACA0` (the per-thread `lua_State`) anywhere in `0x8DABD0`–`0x8DCA6A`, in slot 78, in slot 84, in the objective generator `0x8980E0` or in the stance decider `0x8912D0`. So `FINDINGS-aiunit.md`'s "five defines and that is all" stands, and the Lua negative extends to the three new bodies.

Every number in slot 76 — `10.0`, `0.1`, `600.0`, `1e6`, `1e7`, `20.0`, `0.0` — is a float or double constant in `.rdata` (`0x160A300`–`0x160A7CC`, `0x15AB304`, `0x15BED10`), which is MSVC's constant pool. Slot 78's power-ratio ladder reads `.data` addresses instead (`0x1718064`, `0x17179A8`, `0x17179AC`, `0x170AC00`, `0x170AC10`, `0x171618C`, `0x171DE18`); `scratchpad/naval/definecache.py` maps **none** of them to a define, but trap 8 says a negative from a define scan is not evidence, so treat those seven as unresolved rather than as literals.

## Slot 78, `0x8B1D10`–`0x8B32DF` — subordinate bookkeeping

`void __thiscall`, bare `ret`. I read its frame, its openings and its one command; I did **not** read all 5.5 KB of its middle.

Its first act is to **tear down seven containers on `CAIUnit` and rebuild them**:

```
entry test: hadSubordinates = (this->+0x110 - this->+0x10C) > 0        0x8B1D48
erase the vectors at +0x13C/+0x140, +0x12C/+0x130, +0x14C/+0x150,
                     +0x15C/+0x160, +0x16C/+0x170, +0x11C/+0x120
free the list at +0x100/+0x104 and clear +0x10C/+0x110
this->+0x348 = 0
```

So `CAIUnit +0xFC`–`+0x170` is a block of per-pass subordinate-assignment containers.

Then it computes a single commitment factor from the plan's power estimate (`0x8B1F45`–`0x8B1FEA`):

```
ratio = CUnitPlan::GetPowerRatio(&unit->plan)      ; 0x8DFE80: our_power*1000/their_power
                                                   ;   1000 when their_power <= 0, -1 when == 0
factor = 0.5
if      (ratio/1000 >  2.00) factor = 0.7
else if (ratio/1000 >  1.50) factor = 0.6
else if (ratio/1000 <  0.25) factor = 0.2
else if (ratio/1000 <  0.50) factor = 0.3
else if (ratio/1000 <  0.75) factor = 0.4
```

**That is the AI's own reading of "am I winning here"**, and `our_power`/`their_power` are `CUnitPlan +0x80`/`+0x84` — the two fields `CSetPlanAttributesCommand` sets from `0x8B7E87` (inside `0x8B60F0`, a 7.8 KB power estimator nobody has read). So the mod can see the inputs to this number in a savegame.

The one command, at `0x8B24CB`:

```
if (army->+0x304->+0x20 / 1000 < 1) {
    army->+0x2E4 = 0                                   ; written directly first
    cmd = new CSetAIParamCommand(unit, army->+0x2E8, 0) ; 0x5E90B0, 0x6C bytes, token 0x735
    post(cmd)
}
```

`CSetAIParamCommand::Execute` (`0x5E9160`) resolves the unit, requires `isLand()`, and writes `army->+0x2E8 = cmd->+0x64` and `army->+0x2E4 = cmd->+0x68`. So **`CArmy +0x2E4` and `+0x2E8` are two AI parameters a command replicates**, and slot 78 zeroes the first while preserving the second. It writes the field locally *and* posts the command, which is the normal shape for something that has to agree across a multiplayer session.

What the rest of slot 78 touches, read as a call list rather than as logic: `0x50F4A0` (builds a 0x10-byte object with the constants 7 and 8 beside it), `0x5B6E60`, `0x5C0160`, `0x89AAB0`, `0x8B16F0`, `0x8DD3D0`, `CAIUnit::GetArea`, `0x4B14F0`, `0x5C7250` (twice), `CCountry::GetActingCapitalLocation` (twice), `0x44EE90`, `CanOperateIn` (`0x4EFA00`, twice), `0x8DCF30`, `CCountry::IsEnemy` (`0x42F210`), `CSubUnitDataBase` built and destroyed on the stack at `0x8B2D1F`/`0x8B2D4A`, `0x8ADE10`, `0x5D5C20`, `0x68D990`, `0x8DCED0`, and `std::vector::push_back` (`0x86CC20`) nine times. The capital-location pair and `CanOperateIn` together say it is deciding **which of the agent's subordinates belong where**, with the capital as one of the anchors; the `CSubUnitDataBase` on the stack says it is also counting brigade types. The `_CxxThrowException` at `0x8B32DA` is the `vector<T> too long` arm, not logic.

**This is where I stopped on slot 78.** The next reader should take it in the order the frame suggests: the six vectors it rebuilds are the output, so working backwards from each `push_back` site to the condition that reaches it will give the whole function in six pieces.

## `CObjective`'s priority in practice

`CObjective` is `0x24` bytes, vftable `0x15C8BE0`, and is its own list node. Seven bodies in the image write its vftable, which is the complete set of places an objective is born:

| where | priority it writes | the rest |
| --- | --- | --- |
| `CTogglePlanObjectiveCommand::Execute` `0x5E6ED0` | **`0x190` = 400**, hardcoded at `0x5E701B` | `invasion = 0`, `hold = 1` |
| `CEU3AI::GenerateObjectives` `0x8980E0` | computed — see below | `hold = 0`, `invasion` from a local |
| `CopyObjectiveList` `0x8DD350` | copied | copied |
| `CAIUnit::DistributeObjectives` slot 84 `0x8C1790` | copied, twice | copied |
| `0x5EBEA0` (a `CList<CObjective>::push_back`, 114 bytes) | copied | copied |
| `CSetPlanObjectivesCommand::LoadKey` `0x5E6AA0` | from the save | from the save |
| `CUnitPlan::LoadKey` `0x8DF720` | from the save | from the save |

**So the only two writers that choose a number are the interface's toggle and the AI's generator.** Everything else copies. The interface always writes 400 and `hold = yes`; the AI always writes `hold = no`.

### The AI's formula

`0x8980E0(CEU3AI*)`, `ret 4`, **one caller: `ProcessAI` at `0x889AA8`** — so it runs on a TBB worker thread, once per game hour, with the rest of the AI pass. For each unit agent whose `CAIUnit::GetArea` resolves and whose theatre is `hot` (`CTheatre +0x70`), it walks that theatre's fronts and their provinces' adjacencies, and for each candidate province:

```
priority  = province->victory_points (CMapProvince +0x34) * 20          0x89844C
priority += matching entry's +0xC from CCountry +0x4A8, if the province is in that list   0x8984A0
priority += 100 if the province id is in CEU3AI +0x118                  0x8984A5
if (priority < 1) the province is dropped                               0x8984AC
then: 0x4B08C0(province, myTheatre) is the distance to my own theatre's fronts,
      and if any *other* unit agent's theatre is closer, the province is dropped   0x8985F3
```

The survivors become `CObjective`s on a list handed to `CSetPlanObjectivesCommand` (`0x5E68B0`) at `0x898767`.

**The scale is therefore `victory_points × 20`, plus two additive terms of which one is exactly 100.** A 5-VP province scores 100, a 10-VP province 200. Nothing divides by 1000, so **priority is not thousandths**: it is a raw integer on roughly a 0–1000 range, and the interface's 400 sits in the middle of it. `0x4B08C0(province@ECX, theatre@EAX)` is "the smallest `CMap::Distance` from this province to any province of any front of that theatre", seeded at `1000000`.

### What reads it

I could not find a consumer. Slot 84 (`0x8C1790`), the body that distributes the agent's objectives among its subordinate armies, reads `province` (`+0x8`) and `invasion` (`+0x10`) and **ignores `priority` entirely**: it scores each (subordinate, objective) pair with `0x8C1C90(sub@EAX, this@ECX, provinceId)` plus `subordinate->objectiveCount * 20.0` as a load-balancing penalty, and takes the minimum. `CopyObjectiveList` and the five copying writers only move the field. A displacement sweep for `+0xC` reads inside functions that also walk a `CObjective` list through `+0x1C` produced 24 candidate functions, all but five in UI or unrelated code, and the five in the AI range are either the writers above or false positives (`0x8D7F80`'s `+0x2EC` is a different object's list — its node payloads answer a slot-11 virtual, and `CObjective` has six slots).

**So: `priority` is written by the generator and the interface, carried through every copy, saved and loaded — and I found nothing in the AI that branches on it.** That is a negative worth recording as a negative, not as a fact: `+0xC` is too common a displacement for a sweep to be conclusive, and the UI panel bodies at `0x742AA0`, `0x743950`, `0x743B10`, `0x75EC40` were not read. If the mod wants the AI to weigh objectives, the number it is already given may be inert.

### Slot 84, in passing

`bool CAIUnit::DistributeObjectives()` (`0x8C1790`–`0x8C1C8E`) is the missing half of the objective story:

1. collect this unit's land children that themselves have children (`CUnit +0x1EC > 0`), clearing each one's `CArmy +0x2EC`;
2. for every **non-invasion** objective on this agent's own `CArmy +0x2EC`, give a copy to the subordinate with the lowest `0x8C1C90(sub, this, objective->province) + 20 * sub->objectiveCount`;
3. for any subordinate still holding nothing, give it a copy of its own nearest objective;
4. for each subordinate, if its plan's objective count (`CUnit +0x23C`) or the set of provinces differs from what was just computed, post `CSetPlanObjectivesCommand(sub, &sub->+0x2EC)`;
5. free each `CArmy +0x2EC` again and answer whether anything was posted.

`CArmy +0x2EC`/`+0x2F0`/`+0x2F4` is therefore a **scratch list, not state**: slot 76, slot 73 and slot 84 all refill it from `CUnit +0x234` and slot 84 frees it when it is done.

## Who decides the stance — and it is not `CAIUnit`

`CAIUnit` slot 77 (`0x8C36F0`–`0x8C38BD`, `ret 4`) is `void CAIUnit::SetPlanStance(int stance)`: it sets `this->+0x80 = 1`, posts `CSetPlanAttributesCommand(unit, stance, 3, 3, -1000, -1000)` — so only the ground stance — and then **recurses into every child agent with the same value** before calling `0x8C3330(this)`. (`this->+0x80 = 1` is also one of slot 73's gates, which makes `+0x80` "a stance has been set at least once".)

Slot 77 has six call sites. The AI's is **`0x8912D0`–`0x892185`** (`ret 8`, `(CEU3AI*, bool force)`), whose **only caller is `ProcessAI` at `0x889B8F`**. It computes a 0–4 value, clamps it (`0x891B46`–`0x891B52`), and calls slot 77 only when it differs from `unit->plan.stance` (`CUnit +0x208`) — `0x891B7F`. It is gated on `CEU3AI +0xA9` unless forced. It also posts a `CSetPlanAttributesCommand` directly at `0x8916AD` with `(unit, 5, 2, 2, -1000, -1000)` — air and naval stance 2, ground stance untouched.

**So three different `ProcessAI` helpers write a unit's plan, all on worker threads:** `0x8980E0` the objectives, `0x8912D0` the stance, and the `CAIUnit` agents themselves (through slot 9) the ops area. A modder looking for "where the AI decided to attack here" has to look at all three.

## Thread safety — no new tick-thread route found

Nothing in slot 76, slot 78, slot 84, `0x8980E0`, `0x8912D0` or `0x8DCA70` is reachable from the tick thread other than by the two routes `FINDINGS-aiunit.md` already names: `CEU3AI::CreateUnitAgent` (`0x89A1B0`) from `CObjectivesEntry` slot 22, which calls slot 76 at `0x74FB8C`, and the observer slots. `0x8980E0` and `0x8912D0` have exactly one caller each and both are inside `ProcessAI`.

**One thing a hook author must know:** slot 76 and slot 84 both post commands, and the post goes `gamestate->+0xBE8` (the `CInGameIdler`) → slot 18 (the session) → `+0x38` (the channel) → slot 6. That chain is walked **on the worker thread**, ten times inside slot 76 alone, with the `CCurrentGameState` singleton's lazy construction inlined at every one of them (`if (!g_CCurrentGameState) new CCurrentGameState`). So the command channel is already being written from worker threads by the stock game — useful, because it means a BiceLib hook on `CCommand::Execute` or on the post sees AI decisions without having to be thread-safe about *where they were made*.

## New field layout

```
CAIUnit  (0x374 bytes, vftable 0x15EC0B4)
  +0x80  byte     set to 1 by slot 77 - "a stance has been set"; a slot 73 gate
  +0x90  vector<CMapProvince*>  the ops area slot 76 computes; +0x94 end, +0x98 capacity end.
                  Erased and refilled every pass; consumed by ReplanSubtree (0x8DCA70)
  +0xC0  vector   rebuilt from the ops area by 0x8BBB50; +0xC4 end, +0xC8 capacity
  +0x100/+0x104   a list slot 78 frees and rebuilds
  +0x10C/+0x110   a vector; slot 78's entry test is whether it was non-empty
  +0x11C, +0x12C, +0x13C, +0x14C, +0x15C, +0x16C   six more vectors slot 78 erases
  +0x348   zeroed at the top of slot 78

CArmy
  +0x2E4   an AI parameter; CSetAIParamCommand's second value. Slot 78 zeroes it
  +0x2E8   an AI parameter; CSetAIParamCommand's first value
  +0x2EC/+0x2F0/+0x2F4   scratch copy of the plan's objectives, refilled per pass

CMapProvince
  +0x2B4   COwnerArea* - already named `area`; the null object is CNullOwnerArea
           (vftable 0x15BDB7C), lazily built as 0x98 bytes into the global 0x1A85574 at
           0x496AC3 and written into every province at 0x496AE3, so slot 0 is an IsValid
  +0x338   controller id (the id half of the `controller` tag at +0x334)
  +0x380   the province's theatre object id, type half   } compared against CTheatre +0x8/+0xC
  +0x384   the province's theatre object id, serial half }

COwnerArea  (vftable 0x15BDB50, 3 slots; CNullOwnerArea overrides slot 0 only)
  +0x24    pointer to its CMapProvince* array
  +0x2C    how many provinces it holds
  +0x34    a CList of neighbouring COwnerArea*

CAreaBorder  (vftable 0x15BDB60; base PAVCProvince::__CArray at +8)
  +0x08/+0x0C   the front's province array, begin and end
  +0x1C/+0x20   its local_enemy tag: letters and id

CDiplomacyStatus  (the entries of CCountry +0xE28, indexed by country id)
  +0x58    a byte that, with "not at war", is what lets one country's armies use another's
           territory. **Inferred** from three independent consumers (0x4EFA00, 0x4EF7C0,
           0x4EE110) all treating it that way; nothing names it

CCountry
  +0x4A8   a list; a matching entry's +0xC is added to an AI objective's priority
  +0xF34   byte: is in a faction
  +0xF38/+0xF3C   a CCountryTag: the faction leader or overlord. Read by 0x4EF940 / 0x4EF7C0

CEU3AI
  +0xA9    gates UpdateUnitStances unless forced
  +0x118   a list of province ids; membership adds 100 to an objective's priority

CUnit  (all inside the CUnitPlan at +0x1FC, whose layout project.json already has)
  +0x1EC   children count
  +0x21C   plan ops-area province count  (CUnitPlan +0x20)
  +0x23C   plan objective count          (CUnitPlan +0x40)
  +0x244   plan `path` list head         (CUnitPlan +0x48)
  +0x2CC   movement destination province id
```

## Functions this named

| address | name | how sure |
| --- | --- | --- |
| `0x492030` | `CMap::DistanceBetweenProvinces` | read; 77 callers |
| `0x4EF940` | `CCountry::IsSameSide(tag)` — self, overlord, same faction leader | read; 37 callers |
| `0x4EF7C0` | `CCountry::IsFriendly(tag, includeRequested)` | read; 75 callers |
| `0x4EFA00` | `CCountry::CanOperateIn(tag)` — allied, or access and not at war | read; 31 callers |
| `0x4EE110` | `CCountry::CollectCountriesWeCanOperateIn(out)` | read; 1 caller |
| `0x4B08C0` | `CAIUnit::DistanceToTheatreFronts(province, theatre)` | read; 4 callers |
| `0x5BDB00` | `CUnit::CountDivisions(bool landOnly)` — recursive, `oob_level >= 4` | read; 5 callers |
| `0x89AF00` | `CUnit::GetMovementDestinationProvince()` | read; 52 callers |
| `0x8DFE80` | `CUnitPlan::GetPowerRatio(out)` — `our*1000/their` | read; 5 callers |
| `0x8DCA70` | `CAIUnit::ReplanSubtree()` | read; 4 callers |
| `0x8C36F0` | `CAIUnit::SetPlanStance(int)` — slot 77 | read |
| `0x8C1790` | `CAIUnit::DistributeObjectives()` — slot 84 | read |
| `0x8980E0` | `CEU3AI::GenerateUnitObjectives()` | read; 1 caller, `ProcessAI` |
| `0x8912D0` | `CEU3AI::UpdateUnitStances(bool force)` | read; 1 caller, `ProcessAI` |
| `0x5E7710` | `CSetPlanAttributesCommand::CSetPlanAttributesCommand(this, unit, stance, air, naval, ourPower, theirPower)` | read |
| `0x5E90B0` / `0x5E9160` | `CSetAIParamCommand` ctor and `::Execute` | read |
| `0x5E6ED0` | `CTogglePlanObjectiveCommand::Execute` | read |
| `0x89C070` | `CList::AppendAllNodes(src@EAX, dest@ESI)` — a template, used for both `CTheatre*` and ints | read; 14 callers. **Do not name it after a domain** |
| `0x8A30D0` | `CList::FreeNodes()` — 97 callers, same caution | read |
| `0x86CC20` | `std::vector<T*>::push_back(vec@EDI, &value@EAX)` — 178 callers | read |
| `0x4440B0` | `std::vector<T>::erase(out@EDI, vec, first, last)` | read |
| `0x8DD860` | `std::vector<T>::assign(dest@ESI, src)` | read |

`0x89A080(CEU3AI*, CUnit*)` is also read far enough to say what it is for: it walks the owner's unit-agent list, asks each agent slot 74 for its unit, and collects every agent whose unit is a **descendant** of the argument. Slot 76 calls it first thing, so the list it builds is almost certainly agents to be retired now that this unit is planning for them — but I did not read past `0x89A10D` and do not claim it.

## What I did not establish

1. **The middle of slot 78**, `0x8B2100`–`0x8B32AC`.
2. **Slot 79** (`0x8B32E0`–`0x8B3A46`), where detach and expedition actually are, and the three `CTransferSubUnitCommand` sites at `0x8CE90E`, `0x8D1341`, `0x8D1BEB`.
3. **`CAIUnit::SetArea` (`0x8BA5A0`, 5433 bytes)** and the five `ReplanSubtree` callees `0x8BBB50`, `0x8BC860`, `0x8BCD60`, `0x8BDF30`, `0x8BD270` — the biggest unread block left in the class, and where `CSetPlanAxisCommand` and `CSetPlanForcesCommand` are issued.
4. **`0x8B60F0`** (7.8 KB), the power estimator that writes `our_power`/`their_power` — the inputs to slot 78's commitment ladder.
5. **`CCountry +0x4A8`** and **`CEU3AI +0x118`** — the two additive terms in the priority formula.
6. **`CProvinceTemplate +0x22` and `+0x13D`**, the two byte gates every adjacency walk in this code applies, and edge kind `3`, which every walk skips.
7. Whether the fallback path's second, empty `CSetPlanOpsAreaCommand` is a bug. One game settles it.
8. The seven `.data` float constants in slot 78's ladder — literals or startup-cached defines.
9. The arithmetic inside `0x8912D0` that produces the 0–4 stance.
10. **Nothing was watched in a running game.** Three cheap checks: a land unit under AI control should end up with an ops area whose province count equals its division share of its front; `CArmy +0x2EC` should be empty whenever you look at it, because every writer frees it in the same pass; and an AI objective's `priority` should be a multiple of 20 plus 0 or 100 unless `CCountry +0x4A8` contributed.
