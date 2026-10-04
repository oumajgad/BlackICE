# `CAIUnit` slot 73's land half: who spends the ops-area and front scores

Read on 2026-10-02. Two sources, kept apart throughout: `0x8D57F0` and its helpers were read
**statically** off `hoi3_tfh.exe` and survive a restart; a section at the end reports what the
**live process** said, and that section is the only one whose claims are session-dependent.

Addresses are **virtual**, based at `0x400000`, with the rva beside anything a finding names.

The job was `FINDINGS-opsarea.md`'s open item 5: `CAIUnit +0x294`'s objective-nearness scores are
rebuilt on every replan and have at most one consumer, `0x8D57F0`, reached through
`AIOrderedMap_SubscriptFloat` (`0x8DCE40`, two callers in the image). A score with no known
consumer is a number with no known effect.

## In one line

**`0x8D57F0` (rva `0x4D57F0`) is the land third of slot 73**, the sibling of
`CAIUnit_ManageAirUnits` (`0x8CD890`) and `CAIUnit_ManageNavalUnits` (`0x8D0880`), and it is
where the AI decides **which enemy province to attack and which of its land units to send**. It
scores every enemy-held province on the agent's front, takes them best first, assembles an attack
force unit by unit against an odds estimate, and issues either `support_attack` or a plain move
per unit. It is the consumer of `+0x294`, `+0x1BC`, `+0x1CC` and `+0x2C0` — all four at once —
and `+0x294`'s scores are read in exactly one instruction, `0x8D5F70`, **only when the unit's
plan stance is 3 or 4.**

Proposed name: **`CAIUnit_ManageLandUnits`**, `likely` — the domain is confirmed from
instructions, the verb is a naming choice made to match its two siblings.

## Extent, boundaries and signature

```
entry                0x008D57F0  (rva 0x4D57F0)
end                  0x008D7F7E  (rva 0x4D7F7E)
bytes                10,126
instructions reached 2,768   (every branch walked from the entry)
rets inside          two, both `ret 4`: 0x008D7F5B (success) and 0x008D7F7B (the bail)
```

**Trap 2, upper boundary.** The previous function (`0x8D5720`, below) ends with a bare `ret` at
`0x8D57E5`, then sixteen `int3`, then `0x8D57F0` opens `55 8B EC 64 A1 00 00 00 00 6A FF 68 DB B8 C3 00`
— an SEH prologue. `image.retsBefore(0x8D57F0, 0x8D7F7E)` returns exactly the two `ret 4`s above
and nothing else, so **trap 3 does not apply**: there is no cold block past a `ret` here. After
`0x8D7F7E` come two `int3` and a fresh `55 8B EC 64 A1` prologue at `0x8D7F80`.

**Trap 2, and two fresh worked examples.** `image.functionStart` is useless *inside* this body,
the same way `FINDINGS-reorganise.md` found for the air body:

```
functionStart(0x008D6B45)  = 0x008D653C    ; wrong - mid-instruction inside 0x8D57F0
functionStart(0x008D7D00)  = 0x008D78FB    ; wrong - likewise
```

`0x8D653C` is the same false entry `FINDINGS-opsarea.md` already recorded for its own scratch
entry-walk. Attribute call sites here with `findRefs.py --callers`, never with a backward walk.

**One dead five-byte block.** The branch walk covers every byte from `0x8D57F0` to `0x8D7F7E`
except ten alignment nops and `0x8D613B`–`0x8D613F`, which decodes (from the known boundary at
`0x8D6136`, not from a guess — trap 9) as an **unreferenced** `jmp 0x8D6140` followed by a
three-byte `lea ecx,[ecx+0]`. It is a loop-rotation leftover with no predecessor. There are no
indirect jumps anywhere in the function, so no jump table can be hiding a path.

Signature. `ret 4`, one stack argument at `[ebp+8]`, off which it reads `+0x60` (`owner_ai`) and
`+0x64` (`unit`); `al` returns from `[ebp-0x45]`.

```
bool __stdcall CAIUnit_ManageLandUnits(CAIUnit* agent)     ; 0x8D57F0, rva 0x4D57F0
```

## The caller, and the gate slot 73 puts in front of it

One direct caller in the image, `0x8B0D01`, inside **`CAIUnit` slot 73** (`0x8B0730`, which ends
with a bare `ret` at `0x8B0D17`). Slot 73 therefore calls four things in order, and the land body
is the last:

```
0x008B0C6E  call    0x8cd890        ; CAIUnit_ManageAirUnits   (air)
0x008B0CB3  call    0x8d0880        ; CAIUnit_ManageNavalUnits (naval)
0x008B0CB8  call    0x8d5720        ; move the agent's own HQ   (below)
0x008B0D01  call    0x8d57f0        ; CAIUnit_ManageLandUnits  (land)
```

The gate, read off `0x8B0CBD`–`0x8B0D01`:

```
if (dailyStagger /* byte [esp+0xc] */ != 0) goto call;         0x8B0CBD
country = agent->tag.GetCountry();
if (!country->at_war (+0xACC) && !country->+0xACD
                              && country->+0xF50 <= 0) goto skip;   0x8B0CCC-0x8B0CE5
if (arg2 % 3 != 0) goto skip;                                  0x8B0CE7-0x8B0CFE
call: CAIUnit_ManageLandUnits(agent);
```

So the land body runs **unconditionally on slot 73's daily-stagger pass**, and otherwise only on
one pass in three and only when the country is at war, has an undeclared war (`+0xACD`, named
below) or has `+0xF50` positive. `arg2` is slot 73's second argument, the one it also reduces
modulo 24 into `[esp+0xc]` at `0x8B0820` — which independently corroborates
`FINDINGS-reorganise.md`'s note that the air call's dword argument carries that stale hour value
in its upper three bytes.

The return value is dropped on the floor, like the air and naval ones.

## `0x8D5720`, the small sibling nobody had looked at

Read end to end: 70 instructions, `0x8D5720`–`0x8D57E5`, bare `ret`, one caller (slot 73 at
`0x8B0CB8`), `this` in ESI.

```
bool __fastcall CAIUnit_MoveAgentUnitToCommandProvince(CAIUnit* agent@ESI)   ; rva 0x4D5720
```

```
if (!(unit && unit->oob_level (+0x1F4) != 0)) {
    hasArea = !(agent->+0x68 == 0 && agent->+0x6C == 0);
    if (hasArea && agent->parent (+0x40)) return false;        ; top agent only
}
if (unit->slot9()->+0x2FC != 0)              return false;     ; CArmy::army_role must be 0
if (!agent->+0x54)                           return false;
if (agent->slot86(unit))                     return false;
if (unit->retreat (+0x158))                  return false;
if (unit->combats_count (+0x11C) > 0)        return false;
dest = CUnit::GetMovementDestinationProvince(unit) or unit->current_province (+0x130);
if (agent->+0x54 == dest)                    return false;     ; already going there
if (CMapProvince::CanUnitReach(agent->+0x54, unit, 1, 1)) {    ; 0x5C7710
    CEU3AI::MoveUnit(owner_ai, unit, agent->+0x54->id (+0xD0), 0, 1, 1, 0);
    return true;
}
return false;
```

**This settles the type of `CAIUnit +0x54`, and the record has it wrong.** `project.json` calls it
`command_level_state`, an `int`. Here it is used twice in three instructions as a
`CMapProvince*`: it is compared for identity against a province pointer at `0x8D57AB`, its `+0xD0`
is handed to `MoveUnit` as a province id at `0x8D57C3`, and it is the `this` of
`CMapProvince::CanUnitReach` at `0x8D57B7` — a function whose first instruction is
`cmp [unit+0x130], this`. So `+0x54` is **the province the agent wants its own HQ unit to stand
in**, which is consistent with the record's own note that slot 82 writes it from
`0x4DA340(this, unit->oob_level)` and then posts `CSetCommandLevel`. The existing name is right
in spirit and wrong in type; I argue the correction in prose rather than submitting it, because
the merge tool will not overwrite.

## Phase 1, `0x8D5846`–`0x8D678F`: score every enemy-held front province

### The entry gates

```
0x8D5812  if (!(unit && unit->oob_level != 0)) {
0x8D5825      hasArea = !(agent->+0x68 == 0 && agent->+0x6C == 0);
0x8D5840      if (hasArea && agent->parent (+0x40)) return false;
          }
0x8D5846  if (((agent->+0x130 - agent->+0x12C) & ~3) < 4) return false;   ; vector 3 is empty
0x8D585E  if (!agent->+0x364)                             return false;   ; frontier at war
0x8D586B  if (!agent->+0x366)                             return false;
```

The first two mirror `0x8D5720` exactly. The third is new information about
`CAIUnit +0x12C`, whose contents `FINDINGS-opsarea.md` lists as unestablished: whatever it holds,
**the land pass does nothing at all while it is empty.** The fourth is the important one —
`agent->+0x364` is `CAIUnit::ClassifyOpsAreaFrontier`'s "shooting war on my frontier" byte, so
**this entire function is dead for any agent whose operations area does not touch an active war.**

Then the usual lazy construction of the `CCurrentGameState` singleton at `0x1A89790`, and:

```
0x8D58F4  arcade     = (gamestate->arcade_mode (+0xC9C) > 0)
0x8D58FA  planStance = unit->plan_stance (CUnit +0x208)
0x8D5900  country    = agent->tag.GetCountry()
0x8D5923  mayAttackByDefault = (planStance > 1)
```

### The supply-distance ramp

Unless arcade mode is on, it measures the agent's front against its own supply depot:

```
0x8D5944  if (ops area non-empty) {
0x8D5970      depot = opsArea[0]->supply_depot_id (+0x48)
              for (f in agent->front_provinces (+0xC0..+0xC4))
                  d = CMap::DistanceBetweenProvinces(f->id, depot)
                  maxDist = max(maxDist, d);  minDist = min(minDist, d)   ; min seeded 1e6 [0x160A598]
0x8D59F2      spread = maxDist - minDist
          }
```

### The per-province loop

For each province `p` of `agent->front_provinces (+0xC0)`, skipping any that
`CCountry::IsEnemy(country, p->controller, p)` rejects:

```
weight = 1.0f                                                   [0x171DBAC]
if (arcade)            weight = 100.0f                          [0x1717BFC]
else if (spread > 0)   weight = (maxDist - dist(p, depot)) * 500.0 / spread      [0x160A538]
if (p->area->provinces_count (+0x2C) < 3)  weight *= 2.0         [0x160A360]

listA = {}   ; land neighbours of p we may operate in
listB = {}   ; enemy land neighbours of p
worthAttacking = false
allNeighboursAreTargets = true

for (e in p->path_node_ptr (+0xD4)->edges (+0x90..+0x94, stride 0x14)) {
    if (e->kind (+0x00) == 3) continue                     ; impassable
    q = provinces[e->to_province (+0x04)]
    if (!q->tmpl->+0x22 /*is_land*/ || !q->tmpl->+0x13D) continue
    if (CCountry::IsEnemy(country, q->controller, q)) {
        prio = objective priority of q in unit->plan_objectives (+0x234), else 0
        weight += prio / 2                                 ; 0x8D5BF8-0x8D5C10
        listB += q
    }
    if (!CCountry::CanOperateIn(country, q->controller)) continue
    if (q not in agent->target_area_provinces (+0x1CC)) allNeighboursAreTargets = false
    listA += q
    if (gamestate->scenario (+0xD0C) || q->controller_id == agent->country_id
        || countryArray[q->controller_id] != 0)  worthAttacking = true
}
if (!worthAttacking) { free both lists; next p }            ; 0x8D5D1B
```

**The stance-3/4 arm, `0x8D5D84`–`0x8D5F8D`.** Only when `planStance` is exactly 3 or 4:

```
weight += objective priority of p itself                    ; not halved this time
for (t in unit->plan_path (CUnit +0x244))  { p == t ? weight += 90.0 : adjacent ? weight += 45.0 }
for (t in unit->+0x258 /* the plan's second path */) { same 90.0 / 45.0 }
if (allNeighboursAreTargets) weight += 1000.0               [0x160A300]
weight += *AIOrderedMap_SubscriptFloat(&agent->+0x294, &p)  ; 0x8D5F6B  <<<< THE CONSUMER
```

`[0x160A778]` is 90.0 and `[0x160A720]` is 45.0, both doubles.

**That single `movss` at `0x8D5F70` is the whole of what `CAIUnit +0x294` is for.** The 0..100
objective-nearness score that `CAIUnit::RebuildFrontAndApproaches` computes for every front
province on every replan is **added, unweighted, to that province's attack priority** — and only
at plan stance 3 or 4. At any other stance the map is rebuilt and never read. `FINDINGS-opsarea.md`
open item 5 is closed, with the qualification that the consumption is stance-gated.

Then, for every stance:

```
0x8D5F94  widthMul = (planStance == 3) ? 20 : (planStance == 4) ? 10 : 50
0x8D5FB9  weight += (listA.count - 1) * widthMul

for (r in agent->hostile_route_provinces (+0x1BC)) {        ; 0x8D5FF4
    if (r == p) { weight += 1000.0; onRoute = true }         [0x160A300]
    else if (p adjacent to r) weight += 500.0                [0x160A538]
}
```

**So the provinces on the shortest routes to the selected target areas are worth +1000, and
anything beside them +500**, which dwarfs every other term and is the mechanism by which the
agent attacks along one axis instead of everywhere. That closes the loop
`FINDINGS-opsarea.md` described from the other side: `ScoreOpsAreaProvinces` doubles a province's
*defensive* score for `+0x1BC` adjacency, and this doubles down on it for the attack.

**The dead-end rule, `0x8D60A6`–`0x8D6428`** — reached only when `p` is *not* on a hostile route:

```
if (listA.count != 1) skip the rule
if (p->area->provinces_count <= 5) skip
e = listA.first                                     ; the single operable neighbour
if (e->area->provinces_count <= 3) skip
listC = the land neighbours of e we may operate in  ; plus a sea-edge count via p->tmpl->+0xA0
if (listC.count >= 3 || seaEdges >= 1) skip
redundant = some OTHER enemy front province f in the same area as p has an operable land
            neighbour that p does not have                   ; 0x8D6290-0x8D6393
if (redundant) {
    if (listC.count < 2)     { drop p entirely }
    else if (planStance < 3) { drop p entirely }
    else weight *= (planStance == 3) ? 0.25 : 0.5            [0x160A258, 0x160A308]
}
```

In words: a front province whose only way forward is a cul-de-sac already covered by a
neighbouring front province is **removed from consideration below stance 3**, and quartered or
halved above it.

**Two salient bonuses, stance 3 and up** (`0x8D6428`–`0x8D669C`):

```
for (e in listB) {                                           ; 0x8D6435
    friendlyNeighbour = some land neighbour of e is IsSameSide, or a co-belligerent
                        (diplomacy[id]->co_belligerent (+0x58)) that is not an enemy
    enemyNeighbours   = how many of e's neighbours are enemy (or e itself)
    if (friendlyNeighbour && enemyNeighbours < 3)
        weight += (planStance == 3) ? 125.0 : 250.0           [0x160A920, 0x160A918]
}
if (listA.count > 1 && some member of listA is adjacent to no other member)
    weight += (planStance == 3) ? 200.0 : 400.0               [0x160A4D0, 0x160A710]
```

The first is "this enemy province is a thin salient"; the second is "my approaches to it are
disconnected, so I want more of them".

**The port term, and the record** (`0x8D669C`):

```
nb = p->naval_base (+0x300)
if (nb->level_max (+0x20) > 0) weight += (nb->level_max / 1000 + 20) * 5    ; = 5*level + 100
rec = new CProvinceFloat { 0x15EB644, 0x18D, p->id, weight }                ; 0x8D66E4
CList_InsertByDescendingFloatAtC(&out, &rec)                                ; 0x89C330
```

`0x15EB644` is **`CProvinceFloat`** per the RTTI export, so the 0x10-byte record is
`{vftable, 0x18D, int provinceId, float value}`. `0x89C330` walks the list from the tail
backwards through `node->+4` while the new value exceeds the node's `+0xC`, so the list comes out
**score-descending, highest at the head** — the `+0xC`-keyed sibling of
`CList_InsertByDescendingScore` (`0x8DD4B0`), which keys on `+8`.

## Phase 2, `0x8D6795`–`0x8D7CB9`: take the targets best first and build a force

### The per-target preamble

```
rec = node->data;  p = provinces[rec->+8];  weight = rec->+0xC
effStance = planStance
if (weight >= 500.0) effStance = 4                           ; 0x8D67D3
mayAttack = (planStance > 1)
if (p->controller == "REB")                      mayAttack = true
else if (p->area->provinces_count < 6)           mayAttack = true
else if (p holds no unit answering slot 15 && effStance >= 3) mayAttack = true
```

**A province scoring 500 or more is attacked as if the plan stance were 4**, whatever the plan
actually says — and since being on a hostile route is worth +1000 on its own, every province on
the main axis gets the stance-4 treatment. That is the single most consequential line in the
function and it has no equivalent in the air or naval bodies.

Then the shared-boundary count (`0x8D6868`–`0x8D69EC`): for each land neighbour of `p` that is on
our side or a non-enemy co-belligerent, collect the distinct `COwnerArea +0x6C` (`region_group`)
values. If there is more than one, `mayAttack` is forced true as well. `sharedBoundary` is that
count, and it relaxes almost every later test.

### Gathering candidates, and two new `CUnit` fields

For each land neighbour `n` of `p`, for each unit `u` in `n->units (+0x2B8)` with
`u->slot15()` true (land — **`CArmy` slot 15 is `ReturnTrue`, `CAir` and `CNavy` `ReturnFalse`**,
which confirms the record's "unit slot 15 is the land predicate" from the vftables) and
`u->children_count (+0x1EC) == 0`:

```
d = CUnit_GetPendingDestinationProvince(u)                   ; 0x89B010
if (d == p)  alreadyComing += u
if (d && IsEnemy(country, d->controller))        skip u      ; committed elsewhere
if (u->+0x2C9 != 0)                              skip u
if (topmost agent above u != agent)              skip u      ; walk +0x1E0 for +0x198
if (!mayAttack)                                  skip u
if (u is in an attacking combat /* 0x5C0160 */ && (d || sharedBoundary < 2
      || u->current_province not in agent->+0x1CC))  skip u
FuelConsumption(u, &out, 0); if (out[0] > 0 && u->+0x100 == 0) skip u    ; dry
if (u->ai_held_back (+0x2C8) && sharedBoundary < 2) skip u
if (agent->slot86(u))                            skip u
...
```

and then the fitness, `0x8D6EA9`–`0x8D715A`:

```
enemyNeighbours = enemy land neighbours of u's province n
uncovered       = how many of those are GARRISONED and nothing of ours is already
                  heading at them       ; 0x8D6FA8 CollectUnitsMovingIntoProvince(r,&t,0,r->controller)
                                        ; r counts only when r->units_count (+0x2C0) + t.count >= 1,
                                        ;   unless n's area is a single province and r's holds > 5
score = enemyNeighbours * 10 - agent->slot89(p, u, 1) * 10                [0x160A340 = 10]
if (agent->slot88(u) > 95.0f) score += 100.0                   [0x160A910 = 95, 0x160A358 = 100]
if (topmost agent above u != agent)      score /= 10.0         [0x160A340]
else if (UnitHasBlockingOrder(u))        score /= 5.0          [0x160A508 = 5]
u->+0x2B8 = score            (float)                           ; 0x8D714A
u->+0x2BC = (float)uncovered                                   ; 0x8D715A
insert u into the candidate list, descending by +0x2B8          ; 0x549CE0 CList_InsertBefore
```

**`CUnit +0x2B8` and `+0x2BC` are two floats this function writes and nothing in the record
names.** They are per-pass scratch on the unit rather than persistent state: `+0x2B8` is the
candidate's attack fitness and is read back three instructions later to order the list; `+0x2BC`
is the count of garrisoned enemy provinces beside the unit that nobody is attacking, and it is
the input to the stay-or-go decision below. Note `CUnit +0x2B8` is *not*
`CMapProvince +0x2B8` — both appear in this function, on different registers (trap 12).

### The defenders, and the odds

```
for (v in p->units (+0x2B8)) with v->slot15():                 ; 0x8D7215
    include v when diplomacy[v->owner_id]->war (+0x20) != 0, or either tag is "REB",
    or the undeclared war covers p (an inlined scan of CUndeclaredWar +0x28/+0x2C
    against p->regions (+0x358))
    -> defenders
odds       = 0x8D93B0(attackers, &defenders, p, 0, 1)          ; 0x8D73A0, receiver = agent
oddsBefore = odds
portSupply = some attacker's province has no supply depot (+0x48 == 0) while
             p->+0x330 and p->+0x354 are both set and p->naval_base->level_max > 0
```

`attackers` starts as the units already ordered at `p`. `0x8D93B0` (rva `0x4D93B0`, 2,682 bytes)
is recursive — its three callers are these two sites and itself at `0x8D99CE` — and I did **not**
read it. Everything below rests only on its being monotone in our side's strength, which the
call sites make plain.

### Committing units one at a time

```
for (u in candidates, best first) {                            ; 0x8D7404
    if (u->combat_cooldown (+0xD4) > 0 && defenders.count > 0) skip
    if (u->retreat (+0x158))                                   skip
    if (odds >= LandAttackOddsThresholdForStance(effStance)                 ; 0x8C04C0: 5/4/3
        && u's own province has more than one enemy neighbour) skip        ; 0x8D755A
    if (p->area->provinces_count > 5 && sharedBoundary < 2
        && (p is garrisoned || effStance < 3)) {
        GetUnitAverageStrengthAndOrganisation(u, &str, &org)
        if (str < LandUnitStrengthThresholdForStance(effStance))     skip  ; 0x8C04F0: 0.7/0.6/0.5
        if (org < LandUnitOrganisationThresholdForStance(effStance)) skip  ; 0x8C0520: 0.75/0.6/0.5
    }
    mustStay = true
    if (u->+0x2BC > 0 && u's province has a supply depot) {
        mustStay = some other friendly land unit w in u's province can take over
                   (not in combat, not already committed, w->slot9()->+0x2FC != 0,
                    CUnit_GetPendingDestinationProvince(w) == 0, !agent->slot86(w))
        if (!mustStay && u's province is in agent->+0x1CC) mustStay = true
    }
    attackers += u;  if (!mustStay) movable += u
    newOdds = 0x8D93B0(attackers, &defenders, p, 0, 1)                     ; 0x8D78E0
    if (odds > newOdds) { attackers -= u; movable -= u }   ; adding it made things worse
    else odds = newOdds
}
```

The three stance tables are each called from exactly one site in the whole image — this function —
so naming them after it is safe. Their shape is `sub eax,2; je` / `sub eax,2; je`, i.e. stance 2
and stance 4 get special values and everything else the default:

| helper | stance 2 | stance 4 | otherwise |
| --- | --- | --- | --- |
| `0x8C04C0` attack-odds bar above which a unit may be left in place | 5.0 `[0x160A2EC]` | 3.0 `[0x171DC88]` | 4.0 `[0x171DF34]` |
| `0x8C04F0` required strength fraction | 0.7 `[0x160A2E8]` | 0.5 `[0x15AB304]` | 0.6 `[0x170AC00]` |
| `0x8C0520` required organisation fraction | 0.75 `[0x17179A8]` | 0.5 `[0x15AB304]` | 0.6 `[0x170AC00]` |

Those are the same four literals `FINDINGS-reorganise.md` found the air body using for wing
fitness (`0.5`/`0.75` and `0.7`/`0.85`), minus `0.85` — so the land and air halves share a
constant pool but not a rule.

### The decision, `0x8D7963`–`0x8D7BD6`

```
attackBar = (effStance == 2) ? 3.0f : (effStance == 4) ? 1.1f : 1.5f   [0x171DC88, 0x160A2F0, 0x17179AC]
cancelBar = 0.8f                                                       [0x174C564]
if (sharedBoundary > 1 || portSupply) { attackBar = 0.2f; cancelBar = 0.01f }   [0x171618C, 0x160A378]

if (mayAttack && odds >= attackBar && movable.count < attackers.count) {
    for (u in attackers) {
        if (CUnit_GetPendingDestinationProvince(u) is an enemy province) continue
        if (u->retreat) continue
        if (!owner_ai->runs_units (+0x2C) && no agent above u) continue
        if (u in movable) CEU3AI::IssueUnitOrder(owner_ai, support_attack, u, p->id)  ; 0x8D7AD6
        else              CEU3AI::MoveUnit(owner_ai, u, p->id, 0,0,0,0)               ; 0x8D7AAE
        returnValue = 1
    }
} else if (cancelBar > oddsBefore && cancelBar > odds && attackers.count > 0) {
    for (u in attackers) that are ours, bound for p, not retreating, and either not
        fighting or fighting a combat whose slot 12 answers true:
        0x89AAB0(u, owner_ai)        ; stand down
}
```

**`support_attack` goes to the unit that cannot be spared, and a move to the unit that can** —
and that is the clean answer to what the order is for. `movable` holds exactly those units that
cover a garrisoned enemy province nobody else is attacking, sit in a supplied province, have no
stand-in available and are not in a target area; `mustStay` is true for everyone else. Which
means the naming is inverted from what it looks like: a unit in `movable` is the one that
**stays where it is and supports**, and `movable.count < attackers.count` is the requirement that
at least one unit can physically march. I am reporting the branch as read and flagging that the
local name is the opposite of the behaviour, because this is where a careless reading would
invert the mechanic.

`0x89AAB0` has six callers and I did not read it; from this site and from `0x8D7F14` it is the
"cancel this unit's order" primitive, and it reads `CUnit +0x2CC` on entry.

## Phase 3, `0x8D7CBF`–`0x8D7F2C`: call off attacks that are failing

```
CListOfOwned_ClearByPointer(&scoredProvinces)        ; 0x4B6260, destroys the CProvinceFloat records
for (u in agent->+0x11C .. +0x120) {
    if (u->combats_count (+0x11C) <= 0) continue
    d = CUnit_GetPendingDestinationProvince(u);  if (!d) continue
    if (!IsEnemy(country, d->controller, d)) continue
    if (d is in agent->hostile_route_provinces (+0x1BC)) continue    ; never abandon the main axis
    if (u->current_province is in agent->+0x1CC) {
        if (every land neighbour of d that IsFriendly is in the same area as u) 0x89AAB0(u, owner_ai)
        continue
    }
    for (c in u->combats (+0x114)) {
        if (u is in c->defender (+0x14)->units (+0x40)) {
            if (c->slot17() / 1000.0 > 0.5f && 0x5C0000(u)) 0x89AAB0(u, owner_ai)   [0x15AB304]
        } else if (u->order (+0xB0)->slot16() == support_attack) {
            if (every unit of c->attacker (+0x10)->units has a blocking order (slot 24))
                0x89AAB0(u, owner_ai)
        }
    }
}
return [ebp-0x45];
```

Two things worth keeping. The first is that **`agent->+0x11C` holds `CUnit*`** — the record's
`subordinate_vector2_first` with "what it holds was not established". Every use here is a
`CUnit`: `+0x11C`, `+0x114`, `+0x130`, `+0xB0` and the pending-destination helper. `likely`.
The second is the slot-17 convention: the land body takes the combat's own slot-17 ratio
uncomplemented and disengages when it is **above** 0.5, where the naval body complements it for
the matched side and disengages **below** 0.5. Both use `[0x15AB304]`. I am recording the
instruction rather than a unified story, because the two cannot both be "losing" under one
reading of slot 17 and I did not read slot 17.

**Return value.** `[ebp-0x45]`, seeded 0 at `0x8D587D` and set to 1 at exactly one place,
`0x8D7AB3`, inside the commit loop. So the bool means **"I ordered at least one land unit to
attack"** — a third different meaning from the air body's "I changed the air order of battle" and
the naval body's "I split or merged a fleet" — and, like both of those, nothing reads it.

## Also established

**`CCountry +0xACD` is `in_undeclared_war`, and the function that writes it is the twin of
`CCountry::UpdateAtWarAndEnemies`.** This has been open since `FINDINGS-reorganise.md` asked it,
and it is `confirmed` from instructions. A displacement scan over `.text` finds exactly 15
decoded uses of `[reg+0xACD]` and two of them are writes, both inside `0x4E6EE0` (rva `0xE6EE0`,
448 bytes, bare `ret`, `this` in ESI, read end to end):

```
void __fastcall CCountry::UpdateUndeclaredWars(CCountry* this@ESI)      ; 0x4E6EE0

this->+0xACD = 0                                                ; 0x4E6EFC
free and clear the list at +0x1018 / +0x101C / +0x1020
db = the lazily-built CCountryDataBase at [0x1A855A4]
for (other in db->+0x16C[0 .. db->+0x168)) {
    ds = this->diplomacy_status_array (+0xE28)[other->id (+0xCA8)]
    if (ds->undeclared_war (+0x24) == 0) continue
    this->+0xACD = 1                                            ; 0x4E7025
    append a 0x14-byte node {tagChars, prev, next, 0, 0} carrying other->tag (+0xCA4)
}
```

The eight callers are `CUndeclaredWar::AddAttacker` (`0x476040`), `CUndeclaredWar::AddDefender`
(`0x4761C0`) and their two removal siblings (`0x4760F0`, `0x476270`), each calling it twice —
once per side — immediately after writing `diplomacy[other]->+0x24`. And `+0x1018/+0x101C/+0x1020`
is the undeclared-war mirror of `+0x1008 enemies` / `+0x100C` / `+0x1010`, node layout and all,
which the record already documents as `{tagChars, tagId, prev@+8, next@+0xC, byte}` rebuilt by
`UpdateAtWarAndEnemies`.

The **positive control** for that negative-shaped scan is in the same run: the identical scan for
`+0xACC` decodes 101 sites and finds `UpdateAtWarAndEnemies`'s own two writes at `0x4E6A91` and
`0x4E6BCC`. A method that sees the known writers of the neighbouring byte and then reports only
two for `+0xACD` is a method whose silence means something.

**`CUnit +0x98`'s class, open since 2026-09 in `FINDINGS-airnaval.md`: it is a `CUnitBase`, and
the hierarchy has exactly two leaves.** Over every live `CArmy`, `CAir` and `CNavy`,
`classNameForVftable` on `+0x98` answers `CUnitBaseProvince` 542 times, `CUnitBaseCarrier` 11
times and null 2,263 times. The RTTI export gives `CUnitBase` **two** virtual slots and both
leaves override both:

| slot | `CUnitBaseProvince` | `CUnitBaseCarrier` |
| --- | --- | --- |
| 0 | `0x4944C0` — `mov eax,[ecx+0x20]; ret` | `0x5D5570` |
| 1 | `0x592360` `ReturnFalse` | `0xA92590` `ReturnTrue` |

So **slot 1 is `IsCarrier()`, not a validity test.** `FINDINGS-reorganise.md` read it as
"a validity test", and under that reading the air body's gate before issuing
`carrier_protection` (`wing->+0x98->slot1()` at `0x8CDF89`) looked arbitrary; under this one it is
exactly right — a CAG group may only be given carrier protection when its base *is* a carrier.
Two live corroborations, both 100%:

- `CUnitBaseProvince +0x20` points at a `CMapProvince` on 400 of 400 sampled, and
  `home_base->+0x20 == unit->current_province (+0x130)` on **540 of 542** units, the two
  exceptions being units in transit. (Caveat: `+0x18` on this class is the `CSelectable`
  subobject's vftable pointer per RTTI, so `+0x20` sits just past it.)
- `CUnitBaseCarrier +0x18` points at a `CShip` on 1,851 of 1,851, and that ship's `+0xB0` at a
  `CNavy` on all 1,851. That resolves the third clause of `CUnit_IsAtOwnBase` (`0x5CDC30`), which
  `FINDINGS-reorganise.md` left as "the object is not identified": it reads
  `base->+0x18->+0xB0`, which is **the fleet carrying the air group**, and refuses when that
  fleet's `combats_count (+0x11C)` or `current_combat (+0x110)` says it is fighting.

**And `0x4944C0` is a fold whose recorded name is wrong for one of its holders — trap 4 in its
"a high count is not disqualifying" form.** The body is `mov eax,[ecx+0x20]; ret` and sits in 37
vftable slots: 36 of them are slot 19 of a `COrder` subclass, which is why it is named
`COrder::GetStance`, and the 37th is `CUnitBaseProvince` slot 0, where the same three bytes read
a completely different field. The name is right for 36 holders and wrong for the one that
matters here. I am not submitting a rename — `COrder::GetStance` is the better name for 36/37 —
but the record should carry the exception, because anyone chasing `CUnit +0x98->slot0()` through
Ghidra will land on `COrder::GetStance` and stop.

**`CAIUnit +0x2A4`, `+0x2A8`, `+0x2B4` and `+0x2B8` are not fields of `CAIUnit`.** They are
interior members of the container that begins at `+0x294`, and this closes
`FINDINGS-opsarea.md`'s open item 8 outright rather than advancing it. The constructor builds
three 0x3C-byte containers in place at `+0x294`, `+0x2D0` and `+0x30C`; read live, all three have
the identical interior, period 0x3C:

```
container + 0x00   comparator byte, then uninitialised padding
container + 0x04   sentinel node
container + 0x08   size
container + 0x10   bucket vector begin
container + 0x14   bucket vector end
container + 0x18   bucket vector end-of-storage
container + 0x20   mask            = 7
container + 0x24   max index       = 8
container + 0x28   max load factor = 1.0f
```

Mapped onto `CAIUnit`, the `+0x294` container's bucket vector is `+0x2A4/+0x2A8/+0x2AC`, its mask
is `+0x2B4` and its max index `+0x2B8`, and `+0x2BC` holds `1.0f`. That is **member for member
the stack hash container `FINDINGS-reorganise.md` documented in the air body** — sentinel node,
bucket vector filled with 16 copies of the sentinel by `std::vector::_insert_n`, mask 7 at
`[ebp-0x124]`, maxidx 8 at `[ebp-0x120]`, max load factor `1.0f` at `[ebp-0x11C]`. So:

- `+0x2A4/+0x2A8` is "a vector cleared and never filled" because it is the bucket vector, and a
  `clear()` reinitialises it to eight empty buckets;
- the constants 7 and 8 written to `+0x2B4`/`+0x2B8` by `RebuildFrontAndApproaches` at
  `0x4BBDD8`/`0x4BBDDF` are that rehash, not two mystery fields;
- nothing reads them because nothing is supposed to except the container's own `operator[]`;
- and `+0x294` is a **hash map**, not an "ordered map" — the "comparator byte / sentinel / size"
  reading is the list half of a `stdext::hash_map`, correct as far as it goes.

Live, every one of the 112 agents shows mask 7, maxidx 8 and `1.0f` in all three containers. The
four `unknown_*` names in `project.json` should be withdrawn; I argue it here rather than
submitting, since the merge tool will not overwrite.

**Small functions read end to end.** All of these are generic container or accessor bodies with
register receivers, named class-free on purpose:

| address | rva | what it is | callers |
| --- | --- | --- | --- |
| `0x44EE90` | `0x4EE90` | `CList_Contains(list@EAX, value@ECX)`, bare `ret` | 18 |
| `0x50D1E0` | `0x10D1E0` | `CList_FreeAndClear(list@EDI)`, frees nodes and zeroes head/tail/count | 177 |
| `0x4B6260` | `0xB6260` | the `__cdecl` twin of `CListOfOwned_Clear` (`0x81C80`): calls each payload's slot 0 with 1, then frees | 79 |
| `0x5D49D0` | `0x1D49D0` | `CList_RemoveNode(list@ESI, node)`, `ret 4`; marks `node->+0xC` instead when the list owns its nodes | 215 |
| `0x549CE0` | `0x149CE0` | `CList_InsertBefore(list, item, before)`, `ret 0xC` | 6 |
| `0x89C330` | `0x49C330` | `CList_InsertByDescendingFloatAtC(list, item)`, `ret 8`, keyed on `item->+0xC` | 3 |
| `0x89B010` | `0x49B010` | `CUnit_GetPendingDestinationProvince`: `provinces[this->+0x2CC]` if set, else `order->+0xC` when `order->slot24()`, else null | 8 |
| `0x5B4EC0` | `0x1B4EC0` | `mov eax,ecx; ret` — **`ReturnThis`**, in 20 vftable slots across many classes | 7 |

`ReturnThis` is worth the entry on its own, because it is what `CArmy` slot 9 and `CNavy` slot 12
contain. Every `unit->slot9()` in this function and in `CollectUnitsMovingIntoProvince` therefore
just yields the unit back, and reading it as a conversion is what made the argument counts at
`0x8D70A7` and `0x8D70CD` look inconsistent: the `push 1` at `0x8D70A0` is slot 89's third
argument being pushed before slot 9 is called, not an argument to slot 9.

`ProvinceEdge::kind == 3` meaning impassable, which the record already carries from
`CPathFind::MayStep`, picks up nine more corroborating sites here — every one of this function's
nine edge walks opens with it.

## What a mod can and cannot reach

Every number in this function is a compiled-in literal. Nothing in it comes from `defines.lua`.

| the AI's number | where it comes from | can a mod move it? |
| --- | --- | --- |
| the supply-distance ramp, 500 | double at `0x160A538` | **no** |
| the arcade flat weight, 100 | float at `0x1717BFC`; selected by `gamestate->arcade_mode` | the **lobby setting** yes, the number no |
| the small-area doubling, 2.0 | double at `0x160A360` | **no** |
| the plan-path bonuses, 90 and 45 | doubles at `0x160A778`, `0x160A720` | **no** — but the path is the player's/AI's plan |
| the target-area and hostile-route bonuses, 1000 and 500 | doubles at `0x160A300`, `0x160A538` | **no** |
| the front-width term, 50/20/10 | immediates at `0x8D5F94`, keyed on plan stance | the **stance** yes, through `CSetPlanAttributesCommand` |
| the salient bonuses, 125/250 and 200/400 | doubles at `0x160A920`/`0x160A918`, `0x160A4D0`/`0x160A710` | **no** |
| the dead-end penalty, 0.25 / 0.5 | doubles at `0x160A258`, `0x160A308` | **no** |
| the naval-base term, 5 per level + 100 | immediates at `0x8D66B4`-`0x8D66CA` | the **base level** yes, the formula no |
| the stance-4 promotion threshold, 500 | double at `0x160A538` | **no** |
| the odds bars 5/4/3, 3.0/1.5/1.1 and 0.8 | `0x8C04C0` and the chain at `0x8D7963` | **no** |
| the strength and organisation bars 0.7/0.6/0.5 and 0.75/0.6/0.5 | `0x8C04F0`, `0x8C0520` | **no** |
| the shared-boundary and port relaxations, 0.2 and 0.01 | floats at `0x171618C`, `0x160A378` | **no** |
| the disengage bar, 0.5 | float at `0x15AB304` | **no** |

The one lever a mod does have is the **plan stance**, which selects between the tables at three
separate points and switches four whole scoring blocks on and off.

## What the live process said

**Everything in this section is a statement about one paused session and is marked as such.**
Module base `0x830000` when read (`static = live - base + 0x400000`). The session: played country
`IRE`, id 20 (`CCurrentGameState +0xC30`/`+0xC34`), `loaded_from_save (+0xD9C)` 0, tick 60759360 =
**1936-01-01 00:00**, `arcade_mode (+0xC9C)` 0, `scenario (+0xD0C)` 0.

### The check that could have deleted work, and why it cannot be made in this session

`FINDINGS-reorganise.md` open item 11 asks whether `CAIUnit +0x1FC`, `+0x20C`, `+0x21C` and
`+0x22C` — the four per-role rebase destination lists the air body's phase 2 scores — are ever
non-null, and says that if they are all null then half that file is dead code.

**Why there are 112 agents and none for the played country - answered by the maintainer, 2026-10-02.**
Not a missing object and not an anomaly: **a `CAIUnit` exists per AI-controlled theatre**, and
HoI3 treats theatre AI control as a per-theatre toggle, so the player's own theatre simply has
no agent. That is why the census found 112 agents over 78 tags with no `IRE` among them. It also
means the agent count is not a property of the scenario - it moves as a player takes theatres
over or hands them back, and a player who leaves their theatres on AI keeps agents for their own
country. **This is separate from the null-shells finding below**, which is about the AI not
having run at tick 0 rather than about who controls what; both hold at once.

**All four are null on all 112 live `CAIUnit` agents. The answer is worthless, and the reason it
is worthless is the positive control.** On the same 112 agents, so is everything else:

```
+0x64  unit            null on 112/112      +0x1BC hostile route   null on 112/112
+0x90  ops area        null on 112/112      +0x1CC target areas    null on 112/112
+0xC0  front           null on 112/112      +0x294 map size        0    on 112/112
+0xDC  naval units     null on 112/112      +0x2C8 scored count    0    on 112/112
+0xFC  air units       null on 112/112      +0x11C, +0x12C vectors null on 112/112
+0x364 frontier at war 0    on 112/112      +0x366                 1    on 112/112 (ctor seed)
```

And `CUnit +0x198 ai_agent` is null on all 2,816 units (2,258 `CArmy`, 326 `CAir`, 232 `CNavy`).
The only non-zero dwords anywhere in a live agent are the container proxies, sentinels,
comparators and the constructor's documented seeds (`+0x80 = 0x100`, `+0x84 = 0x10101`,
`+0x88 = 1`, `+0x366 = 1`).

So these 112 agents — roughly one per country against 114 `CTheatre` and 110 `CEU3AI` — are
**freshly constructed shells that have never been bound to a unit**, because the game is paused
on the first tick and `ProcessAI` has not run. There is no field on `CAIUnit` that is populated,
so there is no control that could tell a real null from an unreached one. The honest reading is
**"not readable in this session"**, not "null". A second, independent statement of the same fact:
`agent->+0x364` is 0 on every agent, so `0x8D57F0`'s own entry gate is false everywhere too, and
`CEU3AI +0x2C runs_units` is still 1 on 107 of 110 (the record says `ProcessAI` clears it for the
player's country the first time it runs — it has not).

What would settle it: unpause, let a few game days pass — ideally into a war, since `+0x1BC` and
`+0x1CC` are only filled for an agent whose frontier is at war — and re-read. The script is
`scratchpad/live_aiunit.py`.

**Ireland being the played country does not narrow this.** Ireland has no `CAIUnit` agent at all,
so all 112 belong to AI countries, France included with 7 (ENG 8, SOV 8, GER 3, ITA 2, USA 2,
JAP 2, and 80 across the minors). Nothing had to be excluded.

### The stance distribution, which *is* readable

This one does not depend on the AI having run, because the stances come from the scenario:

```
plan_stance       (CUnit +0x208)  = 2  on 2257/2257 CArmy, 325/325 CAir, 231/231 CNavy
plan_air_stance   (CUnit +0x20C)  = 1  on all of them  (324 AI-owned CAir + 1 IRE-owned)
plan_naval_stance (CUnit +0x210)  = 1  on all of them
plan_active       (CUnit +0x204)  = 0  on all of them
```

Three consequences, all for the scenario start and all overturnable by a war:

1. **The air body's phase 4 runs for every air unit** — `plan_air_stance` is 1, never 0, so the
   `plan_air_stance != 0` gate at `0x8CEE6E` never closes; and it is never 2, so the halved
   fitness thresholds (50%/75%) are the arm that **does not** run and 70%/85% is the live one.
2. **`CAIUnit +0x294`'s scores are never read at the scenario start**, because this function
   consumes them only at plan stance 3 or 4 and the live stance is 2 everywhere. The map is
   rebuilt on every replan regardless. The score becomes live the moment a plan is pushed to
   stance 3, or — via the `weight >= 500` promotion — never, since that promotion sets only the
   *effective* stance used later in phase 2, not the `[ebp-0x88]` the `+0x294` read is gated on.
3. **The stance-2 arm of the land body is the one that runs:** odds bar 5.0 for leaving a unit in
   place, 0.7 strength and 0.75 organisation required, a 3.0 bar to attack and 0.8 to call it
   off, the width term at 50 per extra approach, and all four stance-3/4 scoring blocks off.

### A tooling trap this session produced

**`hoi3.instances` can return a match inside a table of vftable addresses in the data heap**, and
it did: `0x6ECF5C78`–`0x6ECF5CA8` holds the `CLandCombat`, `CAir`, `CArmy` and `CNavy` vftable
addresses within 0x30 bytes of each other, interleaved with code addresses. That yielded one
phantom "instance" for each of `CArmy`, `CAir` and `CNavy`, and reading `plan_stance` off them
produced a spurious "one unit at stance 0" in all three censuses — which I nearly reported. Three
`CUnit`-derived objects cannot sit 4 and 0x1C bytes apart.

The giveaway is **several different classes matching within a few dozen bytes**, and the control
is cheap: a real unit has `owner_id (+0x128)` in 1..107 and a small `regiments_count (+0x40)`,
while the phantoms had owner `'\0\0\0\0'`, id 0 and `regiments_count` 10,436,600. A per-class
overlap filter does **not** catch this, because each class contributes only one hit.

### Corroborations of static claims

| claim | live check | result |
| --- | --- | --- |
| `CUnit +0x98` is a `CUnitBase` | `classNameForVftable` over all units | 542 `CUnitBaseProvince`, 11 `CUnitBaseCarrier`, 2263 null |
| `CUnitBaseProvince +0x20` is the base's province | 400 sampled; and vs `CUnit +0x130` | 400/400 `CMapProvince`; 540/542 equal |
| `CUnitBaseCarrier +0x18` is the carrier ship | all 1851 | 1851/1851 `CShip`, whose `+0xB0` is a `CNavy` |
| `CCountry +0xACD` is undeclared war | all 108 countries | 0 on 108/108, with `+0x1020` also 0 — and `+0xACC` is 1 on 5 with `enemies_count` 1 or 2, which is the control |
| the `+0x294`/`+0x2D0`/`+0x30C` containers are hash maps | all 112 agents | mask 7, maxidx 8, `1.0f` in all three on 112/112 |

## What is not established

1. **The air body's phase 4 was not read.** `0x8CEE76`–`0x8D04E6`, 5.7 KB, assignment item 2.
   I did not reach it. What this file adds is only the live stance distribution above, which says
   which arm of it runs and that it is never switched off at the scenario start.
2. **The naval body's six unread phases were not read**, including the 3.6 KB convoy/rebase block
   at `0x8D2418` and its `MT19937Next` at `0x8D2BBF`, assignment item 3. Not reached.
3. **`0x8D93B0` (rva `0x4D93B0`), the odds estimator, was not read.** 2,682 bytes, recursive
   (three callers: `0x8D73A0`, `0x8D78E0` and itself at `0x8D99CE`), and it uses the 64-bit divide
   helpers `0xB99980` and `0xB99AF0` four and two times. **Everything this file says about when
   the AI attacks rests on its scale**, since the bars 5.0/4.0/3.0 and 3.0/1.5/1.1/0.8 are
   compared against its return value and nothing here establishes what a value of 1.0 means.
   **The search:** read it; its arguments are known (`agent@ECX`, our `CList`, a pointer to the
   defender list, the province, 0, 1) and it has few callers.
4. **`CAIUnit` slots 86, 88 and 89** — `0x8C7540`, `0x8BE560`, `0x8BE7E0`, 639/635/744 bytes, each
   in exactly one vftable slot and with no direct callers. Slot 86 is a veto on a unit
   (three sites here, plus `0x8D5720`); slot 88 returns a float compared against 95.0 and returns
   0.0 for a unit with no brigades, so it reads as a percentage; slot 89 returns a float treated
   as the enemy's power at a province. None was read.
5. **`0x89AAB0`** — the stand-down primitive, six callers, 287 bytes, two allocations. Read only
   from its call sites and its first instruction (`this->+0x2CC`). What command it posts is not
   established, and that is what decides whether a cancelled attack stops or reverses.
6. **`CUnit +0x2C9`** — one reader in the image as far as this pass looked (`0x8D6CE0`,
   non-zero disqualifies a candidate unit) and no writer searched for. It sits between
   `ai_held_back (+0x2C8)` and `ai_pass_scratch (+0x2CA)`, so it is probably a third flag of the
   same family. **The search:** a `dispscan`-style displacement scan over `.text` for
   `[reg+0x2C9]`, which is distinctive enough to be worth running (unlike `+0x2B8`).
7. **`CMapProvince +0x330` and `+0x354`** — both tested non-zero, together, beside the naval-base
   level in the "an unsupplied attacker but the target has a working port" test (`0x8D73D0` and
   `0x8D77CA`). Two readers each, no writer searched for, not named.
8. **`CCountry +0xF50`** — an int slot 73 tests `> 0` as an alternative to `at_war` and
   `in_undeclared_war` when deciding whether to run the land pass at all. Not named. **The
   search:** the same displacement scan; `0xF50` is distinctive.
9. **`CAIUnit +0x12C`'s contents.** Still open — `FINDINGS-opsarea.md`'s item 7 needs it for the
   largest-remainder `m mod n`. This file adds only that the land pass refuses to run while the
   vector is empty, which makes it load-bearing twice over.
10. **Slot 17's sign convention.** The land body disengages when `combat->slot17()/1000 > 0.5`
    and the naval body when the complemented value is `< 0.5`. Both cannot be "we are losing"
    under one reading. **The search:** read slot 17 on one `CCombat` subclass; it is one function.
11. **Whether the stance-2 default survives contact.** Every live claim in *What the live process
    said* is a reading of a campaign paused on its first tick. The stance distribution is the
    scenario's initial state, not a steady state, and the four air lists are unreadable rather
    than empty. One session is one data point, and this one is the least informative session
    there is.
