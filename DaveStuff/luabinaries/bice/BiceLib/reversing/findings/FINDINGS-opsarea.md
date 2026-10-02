# The last two replan callees: what scores an operations area, and what finds the way out of it

`FINDINGS-subdivide.md` left four of the five `CAIUnit::ReplanSubtree` callees read and two not: `0x8BD270`, carrying the `inferred` name `CAIUnit::ApportionOpsArea`, and `0x8BBB50`, carrying the `inferred` name `CAIUnit_RebuildFrontFromOpsArea`. Both are read end to end here. **Neither name survives.** It also left `CCountry +0xCC` open, with the note that the savegame is not an oracle for it; `0x8BD270` turned out to be the way in, not because it says what the field is but because it says what *kind* of field it has to be, and that was enough to find the writer.

Read statically off `hoi3_tfh.exe` on 2026-10-02; the game was not running, so nothing here is marked *seen*. Addresses are **virtual** (image base `0x400000`) unless written `rva`.

## In one line each

**`0x8BD270` (rva `0x4BD270`) does not apportion anything. It scores.** Once per province of the agent's operations area it computes a float priority, writes it into a fresh `0x1C`-byte record, inserts the record into a score-ordered `CList` at `CAIUnit +0x2C0`, indexes it by province in the ordered map at `+0x2D0`, and accumulates the sum of all the scores into `CAIUnit +0x34C`. The apportioning happens one function further on, in `0x8C8EE0`, which divides a count in proportion to `record->+8 / agent->+0x34C` — so `0x8BD270` produces the weights and something else spends them. Proposed name: **`CAIUnit::ScoreOpsAreaProvinces`**.

**`0x8BBB50` (rva `0x4BBB50`) does rebuild the front, but that is its first third.** It then scores each front province by its mean map distance from the unit's own plan objectives and normalises those scores to 0..100 in the ordered map at `CAIUnit +0x294`; and then selects, out of the country's own owner-area list, the areas that are reachable in at most two area-hops but *not* reachable without crossing an enemy, records all their provinces in `CAIUnit +0x1CC`, and records the enemy-held or contested provinces lying on the three shortest routes to them in `CAIUnit +0x1BC`. Proposed name: **`CAIUnit::RebuildFrontAndApproaches`**.

**`CCountry +0xCC` is the country's total brigade combat value, in thousandths** — the sum of `GetSubUnitDefinitionCombatValue` over every brigade, ship and wing it commands. `CCountry::RecountUnitTotals` (rva `0x1004F0`) writes it, hourly, on a TBB worker.

---

## 1. Extents and boundaries — trap 2 on both ends of both bodies

Both ends of both functions are clean, and the check was run rather than assumed.

| | `0x8BBB50` | `0x8BD270` |
| --- | --- | --- |
| entry preceded by | 10 `int3` | 3 `int3` after a `call` |
| `image.functionStart(entry)` | answers itself | answers itself |
| first bytes | `55 8B EC 6A FF 68 5C BB C3 00` — `push ebp; mov ebp,esp; push -1; push 0xC3BB5C` (SEH) | `55 8B EC 64 A1 ...` — `push ebp; mov ebp,esp; mov eax,fs:[0]` (SEH) |
| exit | `ret 8` at `0x8BC858` | `ret 4` at `0x8BDCB5` |
| `retsBefore(entry, exit+0x20)` | exactly one `ret`, the exit | exactly one `ret`, the exit |
| after the exit | 5 `int3`, then a fresh SEH prologue at `0x8BC860` (`CAIUnit::RebuildAreaNeighbourProvinces`) | 8 `int3`, then a fresh SEH prologue at `0x8BDCC0` |
| branch targets past the exit | none | none |

**Trap 3 does not apply to either.** `cfg.py`'s walk from each entry decodes 975 and 767 instructions respectively, the highest branch target is `0x8BC848` and `0x8BDCA2` — both inside the body — and the only `ret` reached is the single exit. Neither body has a `_CxxThrowException` arm outside it; `0x8BBB50`'s one `"list<T> too long"` throw (`0x8BC1EF`, string at `0x15C1AD4`) is *inside* the body, at a lower address than the exit. The two and three small coverage gaps the walk leaves are MSVC alignment nops (`8d 49 00`, `8d a4 24 00 00 00 00`, `8d 9b 00 00 00 00`, `8b ff`), not unreached code.

**One correction to the record falls out of this.** `project.json`'s `0x4BBB50` comment says the function "abut[s] the next function at 0x4BC860 with no int3". There are five `int3` between them. The extent and the `ret 8` are right; only that clause is wrong, and it matters because it is the sort of clause someone later uses to justify *not* running the check.

### A new flavour of trap 2 that cost time in this pass, and should go in `TRAPS.md`

`image.functionStart(0x8BDC5C)` answers **`0x8BD6EE`**, which is 2.4 KB inside `0x8BD270`. Nothing abuts and no prologue is unusual. The cause is that `0x8BD6EB` is

```
0x008BD6EB  89 45 CC     mov dword ptr [ebp - 0x34], eax
```

— the `0xCC` is the **disp8 of `-0x34`**, and the next byte, `0x8B`, is in the prologue set. So the backward walk sees "`int3` then a prologue byte" and stops. This is trap 2's second cause (an apparent boundary that is not one) with a third mechanism: not an abutting function, not an unusual prologue, but **an `0xCC` displacement byte inside an ordinary instruction**. It is common — `[ebp-0x34]`, `[reg-0x34]`, and `imm8 = 0xCC` all produce it — and the only symptom is a function attribution that is silently wrong by thousands of bytes.

The same thing bit a scratch entry-walk built for this pass: requiring a **run of three** `int3` before accepting a prologue byte removed every false entry it had produced (it had reported `0x8C91A5` and `0x8D653C` as function entries; both are mid-instruction inside `0x8C8EE0` and `0x8D57F0`). **A single `int3` is not padding. Require a run.**

### Signatures

Both are as `project.json` already has them, and both are confirmed by the `ret` immediate:

```
void __stdcall CAIUnit::ScoreOpsAreaProvinces(CAIUnit* agent)                      ; 0x8BD270, ret 4
void __stdcall CAIUnit::RebuildFrontAndApproaches(CAIUnit* agent, void* opsArea)   ; 0x8BBB50, ret 8
```

`0x8BBB50`'s second argument is read **only in step 1** (`0x8BBBAF`–`0x8BBD43`); from `0x8BBD9B` on, `[ebp+0xC]` is reused as a scratch slot for three different loop cursors. Anyone decompiling it should expect that, because Ghidra will present the argument as live throughout.

### Callers

Scanned by resolving every `e8`/`e9`/`eb` in `.text` against the target, not by searching for the address (trap 9-safe: the target is checked, not the stream). The count for `0x8BBB50` agrees with `FINDINGS-subdivide.md`'s method-3 control (3); the count for `0x8BD270` agrees too (4).

| callee | call site | caller |
| --- | --- | --- |
| `0x8BBB50` | `0x8BB980` | `CAIUnit::SetArea` (`0x8BA5A0`) |
| | `0x8C05BD` | `CAIUnit::SetOpsAreaAndReplan` (`0x8C0550`) |
| | `0x8DCA7D` | `CAIUnit::ReplanSubtree` (`0x8DCA70`) |
| `0x8BD270` | `0x8BB9A7` | `CAIUnit::SetArea` |
| | `0x8C05E8` | `CAIUnit::SetOpsAreaAndReplan` |
| | `0x8C3844` | **`CAIUnit::SetPlanStance` (slot 77, `0x8C36F0`)** |
| | `0x8DCAA8` | `CAIUnit::ReplanSubtree` |

**The asymmetry is the first piece of evidence about what `0x8BD270` is for.** `SetPlanStance`'s tail is

```
0x008C382A  call 0x8c3330                  ; CAIUnit::UpdatePlanAxis
0x008C382F  cmp  dword ptr [ebp + 8], 0    ; the new stance
0x008C3833  jne  0x8c3843
0x008C3835  lea  ecx, [edi + 0x90]
0x008C383B  push ecx
0x008C383C  mov  ecx, edi
0x008C383E  call 0x8bcd60                  ; CAIUnit::RebuildOpsAreaProvinceRecords
0x008C3843  push edi
0x008C3844  call 0x8bd270                  ; the scorer
```

so a stance change re-runs the scorer and *nothing else* of the replan chain. That is exactly right if the scorer's output depends on the stance — and it does: `0x8BD270` branches on `unit->plan_stance` (`CUnit +0x208`) at `0x8BD91E`. It is also right that `0x8BCD60` is re-run only when the new stance is 0, because the consumers select `(+0x2FC, +0x30C)` — `0x8BCD60`'s pair — over `(+0x2C0, +0x2D0)` — `0x8BD270`'s pair — on exactly that test. See section 4.

---

## 2. `0x8BD270` end to end: a per-province priority score

`ebx` holds the agent for most of the body, but **`xor ebx, ebx` at `0x8BD50B` destroys it** and it is reloaded from `[ebp+8]` at `0x8BD73F`, `0x8BD8BF` and `0x8BDA41`. Field attribution in the middle of the function has to respect that; it is the one place a careless `--field` reading would mis-assign an offset.

### The guards and the setup (`0x8BD270`–`0x8BD33D`)

```
agent = [ebp+8]
if (agent->unit (+0x64) == 0)                       return        ; 0x8BD296
n = (agent->+0x94 - agent->+0x90) >> 2                            ; ops-area province count
if (n < 1)                                          return        ; 0x8BD2AE
m = (agent->+0x130 - agent->+0x12C) >> 2                          ; count of the +0x12C vector
frac           = (float)(m % n) / (float)n          ; [ebp-0x48]  ; 0x8BD2E8
carry          = 0.0f                               ; [ebp-0x2C]
agent->+0x34C  = 0.0f                                             ; 0x8BD2F5
agent->+0x350  = 0.0f                                             ; 0x8BD2FD
AIOrderedMap_Clear(&agent->+0x2D0)                                ; 0x8DCFC0, receiver in EAX
CListOfOwned_Clear(&agent->+0x2C0)                                ; 0x481C80
ourCountry = CCountryTag::GetCountry(&agent->+0x34)   ; [ebp-0x18]
stance     = agent->unit->+0x208                     ; [ebp-0x44]
```

`m % n` is the whole use of `m`: the quotient from the `idiv` is discarded. `frac` is then accumulated once per province and pays out a flat `+20` each time it crosses 1.0, so **exactly `m mod n` of the `n` provinces get the `+20`, spread evenly through the ops-area vector's own order** — the same largest-remainder trick slot 83 uses for its quotas. Why the bonus count is `m mod n` rather than anything else is not established; `CAIUnit +0x12C` is the record's `subordinate_vector3_first`, one of slot 78's containers, and its meaning is not established either.

### The objective-area set — built only for the human's own country (`0x8BD340`–`0x8BD454`)

```
if (agent->owner_ai (+0x60)->runs_units (+0x2C) != 0)  skip this whole block
for (o = agent->unit->plan_objectives (+0x234); o; o = o->+0x1C) {
    area = gamestate->provinces[o->+8]->area (+0x2B4)
    if (area is not already in the local list)  append it
}
```

The local list is a plain `CList` at `[ebp-0x6C]/[ebp-0x68]/[ebp-0x64]`, freed at `0x8BDC81`. So it is the **set of distinct owner areas the unit's plan objectives sit in**, and `CEU3AI::runs_units` gates it the way round that looks backwards and is not: the record's own entry says that byte is "1 for an AI-run country, 0 for the human's own country", so **this set exists only when the agent belongs to the player's country**. That fits — a human's objectives are the human's, an AI's come from its strategy, and the strategy's own equivalent is applied further down at `0x8BDB97` under the opposite test.

That makes `0x8BD270` the **fifth and sixth** consumer of `CEU3AI +0x2C`; the field's comment says "four consumers in the unit AI", so the count wants raising by two (`0x8BD343` and `0x8BDB9A`).

### The per-province loop (`0x8BD454`–`0x8BDC7B`)

Once per province `p` of `agent->+0x90`, index `i` in `[ebp-0x30]`:

```
rec = new 0x1C { p, 0.0f, 0.0f, 0, 0, 0, 0 }         ; 0x8BD491
friendlyNb = 0   [ebp-0x24]      frontNb = 0   [ebp-0x28]
flagA      = 0   [ebp-0xE]       flagB   = 0   [ebp-0xD]
weakMul    = 1000              ; [ebp-0x3C], thousandths
adj = (p->template (+0xD4)->+0x94 - +0x90) / 20
if (adj > 0) {
    tags = _alloca(adj * 8)  ; 0x8BD513 is _chkstk, with 0xA110CA7E guards either end
    tagCount = 0             ; [ebp-0x14]
    ... the adjacency loop, below ...
    ... then the +0xCC ratio, below ...
}
... the score, below ...
```

**The adjacency loop** (`0x8BD540`–`0x8BD76B`), once per 20-byte adjacency record of `p`'s template:

```
if (record->+0 == 3)                                      next   ; edge kind 3
nb = gamestate->provinces_begin (+0xB8C)[ record->+4 ]
if (!nb->template->+0x22 || !nb->template->+0x13D)        next
interesting = 0
if (!flagA) {
    if (CAIStrategy::IsWarCandidate(ourCountry+0x48C, nb->controller))
        { flagA = 1; interesting = 1; }
    else if (nb->area is in the objective-area set)
        { flagA = 1; interesting = 1; }
}
if (!flagB) {
    c = CCountryTag::GetCountry(&nb->+0x334)
    if (c->is_major (+0x15C) || c->max_ic (+0x60C) > 100)
        if (CAIStrategy::IsFrontWorthyEnemy(ourCountry+0x48C, nb->controller))
            { flagB = 1; interesting = 1; }
}
if (interesting && nb->controller_id != 0 && nb->controller != "REB")
    if (nb->controller_id not already in tags)  tags[tagCount++] = nb->controller
if (nb->controller_id != 0 && nb->controller != "REB")
    if (CCountry::IsSameSide(ourCountry, &nb->controller)
        || (ourCountry->diplomacy[nb->controller_id]->+0x58
            && !CCountry::IsEnemyTag(ourCountry, &nb->controller)))
            ++friendlyNb
    else if (nb is in agent->front_provinces (+0xC0 .. +0xC4))
            ++frontNb
```

The three adjacency gates are the same three the rest of the unit AI uses. Four things come out of this block:

- `friendlyNb` is **adjacent provinces we may enter** — same side, or military access (`CDiplomacyStatus +0x58`) and not an enemy.
- `frontNb` is **adjacent provinces that are on the front**, tested by membership of `CAIUnit +0xC0`. This is a reader of the vector `0x8BBB50` fills, which is the link between the two bodies, and it confirms the two run in the recorded order (`0x8BBB50` first, from `ReplanSubtree`, `SetArea` and `SetOpsAreaAndReplan` alike).
- `flagA` is sticky and means "some neighbour of some province of my area is a war candidate, or lies in an area one of my objectives is in".
- `flagB` is sticky and means "some neighbour is controlled by a front-worthy enemy that is either a major or has `max_ic > 100`". Note `max_ic` is **not** in thousandths here: `CCountry +0x60C` is recorded as an int and the comparison is against the literal `0x64`, so the test is "more than 100 IC" and not "more than 0.1".

**The `CCountry +0xCC` ratio** (`0x8BD771`–`0x8BD8BC`) — the arithmetic `FINDINGS-subdivide.md` quoted, now with its inputs identified:

```
if (tagCount <= 0)  weakMul stays 1000
else {
    total = sum over tags of CCountryTag::GetCountry(tag)->+0xCC       ; 0x8BD78F
    mean  = __alldiv(__allmul(total, 1000), tagCount * 1000)           ; = total / tagCount
    ours  = CCountryTag::GetCountry(&agent->+0x34)->+0xCC              ; 0x8BD7D2
    if (ours <= 0)  weakMul stays 1000
    else {
        r = mean * 1000 / ours                      ; thousandths
        if (r > 150)  weakMul stays 1000            ; floorf(150.5f) at 0x160A83C
        else weakMul = max(r * 1000 / 150, 50)      ; floorf(50.5f)  at 0x160A7B4
    }
}
```

**The list the mean is taken over is the open item `FINDINGS-subdivide.md` left.** It is the `_alloca`'d array: the **distinct controller tags of the "interesting" neighbours of this one province** — neighbours that are war candidates, or in an objective's area, or front-worthy enemies — with `REB` and tag id 0 excluded. It is per province, rebuilt for every province, and never longer than the province's adjacency count. `[ebp-0x5C]` is its base and `[ebp-0x14]` its count, as that file guessed.

So the test reads: **if the countries across this province's borders are collectively worth at most 15% of us, scale this province's priority down in proportion, with a floor of 5%.** `150` and `50` are 0.150 and 0.050 of a ratio, which is what `FINDINGS-subdivide.md` concluded; `weakMul` itself is a thousandths multiplier applied at `0x8BDBEB`.

**The score** (`0x8BD8C5`–`0x8BDC25`). `[0x171DBB0]` is the float `10.0`.

```
score   = 10.0f
defPrio = 0
for (node = ourCountry->+0x4B8; node; node = node->+8)        ; strategy.defend_prov
    if (node->data->+8 == p->id) { defPrio = node->data->+0xC; break; }
if (agent->+0x364 == 0) {
    prio = defPrio / 2
    goto PEACE
}
prio = defPrio / 8
if (stance >= 3) goto PUSH
/* WAR, stance < 3 */
    if (p->area->provinces_count (+0x2C) > 5)
        score = (float)(10 * friendlyNb - 10)
    if (!(friendlyNb <= 1 && frontNb >= 3))
        score = score + 2 * (p->modifiers[FORT_LEVEL] / 1000) + 20.0
    if (p->supply_depot_id (+0x48) == p->id)
        score += 100.0
    goto COMMON
PUSH:                                                        ; stance >= 3
    if (p->supply_depot_id == p->id)  score = 15.0f
    for (node = agent->+0x1BC; node; node = node->+8)         ; the hostile-route provinces
        if (p->id is among node->data's adjacency neighbours)
            score *= 2.0
    goto COMMON
PEACE:                                                       ; agent->+0x364 == 0
    carry += frac                                            ; [ebp-0x2C]
    score  = (float)(10 * (p->modifiers[FORT_LEVEL] / 1000)) + 10.0
    if (flagB)  score += 10.0
    if (carry >= 1.0f) { carry -= 1.0; score += 20.0; }
COMMON:
    if (agent->unit->oob_level (+0x1F4) == 0) {               ; theatre-level agents only
        frontLen = 0
        for (b = p->area->fronts_first (+0x74); b; b = b->+8)  ; CAreaBorder list
            if (p is in b->data's province vector (+0x8 .. +0xC)) {
                frontLen = that vector's element count
                break
            }
        if ((double)frontLen / n < 0.2)  score *= 3.0
    }
    if (agent->owner_ai->runs_units)  score += (float)prio
    for (node = p->regions_first (+0x358); node; node = node->+8)
        if (node->data->+0x6D)  score += 100.0
    score *= weakMul / 1000.0
    if (!flagA && agent->+0x364)  score = 0.0f
    agent->+0x34C += score                                   ; 0x8BDC28
    rec->+8 = score                                          ; 0x8BDC57
    CList_InsertByDescendingScore(&agent->+0x2C0, &rec)       ; 0x8DD4B0
    *AIOrderedMap_SubscriptFloat(&agent->+0x2D0, &p) = rec    ; 0x8DCF30
```

`p->modifiers[FORT_LEVEL]` is `[p->+0x114 + 0x50] / 1000` — `CMapProvince +0x114` is the record's modifier array, indexed `id * 8` (trap 5), and `+0x50` is id 10 `FORT_LEVEL`, which the record already establishes from `CLandCombat`. So **fort level is the single largest structural input to a peacetime score**: `10 * level + 10`, against `2 * level + 20` at war.

Constants, none of them thousandths except `weakMul`: `0x171DBB0` float `10.0`; `0x160A340` double `10.0`; `0x160A318` double `20.0`; `0x160A358` double `100.0`; `0x160A838` float `15.0`; `0x160A360` double `2.0`; `0x160A4E8` double `3.0`; `0x160A260` double `0.2`; `0x160A300` double `1000.0`; `0x171DBAC` float `1.0`; `0x160A248` double `1.0`; `0x15BED10` float `0.0`.

Six readings worth stating plainly:

- **`CCountry +0x4B8` is `CCountry::strategy.defend_prov`.** `CAIStrategy` is held by value at `CCountry +0x48C` and the record names `CAIStrategy +0x2C` `defend_prov`; `0x48C + 0x2C = 0x4B8`. The positive control is three instructions away: `0x8BD613` and `0x8BD677` build `ourCountry + 0x48C` and hand it to `CAIStrategy::IsWarCandidate` and `::IsFrontWorthyEnemy`, whose own record entries say every call site reaches them that way. The node payload carries the **province id at `+8` and an int priority at `+0xC`**; that is new. Whether the payload class is `CIDValue`, whose `+8`/`+0xC` slot 83 uses as a two-halves object id, is **not** established and the two readings do not agree, so it should not be assumed.
- **`CMapProvince +0x48` is the record's `supply_depot_id`, and `+0x48 == +0xD0` means the province *is* a depot.** So a supply depot is worth `+100` at war and is pinned to a base of `15.0` when the stance is 3 or more. `0x8BCD60` uses the same identity as its filter, which is a second reader of the same idiom.
- **`CMapProvince +0x358` is already in the record as `CProvince::regions_first`** (trap 14 — I nearly spent a session on it). The `+100` per region is therefore `+100` per region the province belongs to whose byte at `+0x6D` is set. What that byte is remains open; see section 6.
- **`COwnerArea +0x74`'s `CAreaBorder` entries carry their province vector at `+0x8`/`+0xC`**, which the record already has, and the ratio `frontLen / opsAreaSize < 0.2` tripling the score means **a province on a narrow front is worth three times one on a broad one** — but only to a theatre-level agent, because the whole block is behind `oob_level == 0`.
- **`agent->+0x364` is the frontier-at-war flag, not `manage_reserve`.** `project.json` names it `manage_reserve` from a single slot-78 reader, while `+0x365`'s own comment in the same file says "`+0x364` is 'shooting war on my frontier'" — the record contradicts itself. `CAIUnit::ClassifyOpsAreaFrontier` writes it as the low half of the word `0x101`, and `0x8BD270` reads it twice, and both readings only make sense as the war flag: it switches the scorer between a peacetime formula and a wartime one, and it enables the "zero the score of a province with no interesting neighbour" rule. That is a third reader, agreeing with the writer. This is trap 14's second lesson — a name that fits one reader may not fit three.
- **`agent->+0x350` is zeroed and never written again, by this function or by anything else in the AI module.** `project.json` calls it `apportion_b`, which was a guess off the old name of `0x4BD270`; with that name gone, `+0x350` has no evidence behind its name at all.

---

## 3. `0x8BBB50` end to end: the front, and the way out of the area

### Step 1 — rebuild the front (`0x8BBB50`–`0x8BBD43`)

```
agent      = [ebp+8]
ourCountry = CCountryTag::GetCountry(&agent->+0x34)
clear agent->front_provinces (+0xC0/+0xC4)                 ; zero-length memmove, end = begin
for each province p of the handed ops-area vector [ebp+0xC] {
    for each 20-byte adjacency record of p->template (+0xD4) {
        if (record->+0 == 3)                                           next
        nb = gamestate->provinces_begin[ record->+4 ]
        if (!nb->template->+0x22 || !nb->template->+0x13D)              next
        if (!CAIStrategy::IsFrontWorthyEnemy(ourCountry+0x48C, nb->controller)) next
        if (nb->ai_front_value (+0x5C) < g_AiFrontProvinceThreshold)     next
        if (nb not already in agent->+0xC0)
            std::vector_pushBackByAddress(&agent->+0xC0, &nb)
    }
}
```

`g_AiFrontProvinceThreshold` is VA `0x1B151E4`, rva `0x17151E4`, and the record already has it as the compiled-in **200**. So **`CAIUnit +0xC0` is the vector of the enemy-held provinces adjacent to the operations area that are worth fighting over**: controlled by a front-worthy enemy, and with `ai_front_value` at or above 200. The record's existing entry for `+0xC0` says "What it holds was not established - only that 0x4BBB50 empties it before walking the ops area's provinces"; it is established now, and the name `front_provinces_first` was right.

This is also an eighth reader of `g_AiFrontProvinceThreshold` against `CMapProvince +0x5C`, which that global's entry says there are eight of — consistent.

### Step 2 — score the front provinces by nearness to the plan objectives (`0x8BBD49`–`0x8BC1E8`)

Everything from here needs a unit: `if (agent->unit (+0x64) == 0) goto exit` at `0x8BBD50`.

```
clear the ordered map at agent->+0x294      ; sentinel +0x298, size +0x29C, nodes freed
clear the vector at agent->+0x2A4/+0x2A8
0x50F4A0(agent->+0x2A4, &sentinel)   with ecx = 0x10        ; not read
agent->+0x2B4 = 7 ;  agent->+0x2B8 = 8                      ; two constants, meaning unknown
maxMean = 0.0f  [ebp-0x18]        minMean = 1e6  [ebp-0x1C]
for each front province f of agent->+0xC0 {
    sum = 0.0f ; count = 0
    for (o = agent->unit->plan_objectives (+0x234); o; o = o->+0x1C) {
        if (gamestate->provinces[o->+8]->area != f->area)  next
        sum += (float)CMap::DistanceBetweenProvinces(f->id, o->+8, g_CMap)
        ++count
    }
    if (count > 0) {
        mean = sum / count
        if (mean > maxMean) maxMean = mean
        if (mean < minMean) minMean = mean
        *AIOrderedMap_SubscriptFloat(&agent->+0x294, &f) = mean      ; 0x8DCE40, receiver EDI
    }
}
spread = maxMean - minMean
if (spread > 0.0f)
    for each node of the map at agent->+0x294
        node->value = (maxMean - node->value) * 100.0 / spread
```

So the map ends up holding, per front province, **a 0..100 score with 100 on the front province nearest the unit's own plan objectives**. The objective is only counted when it lies in the *same owner area* as the front province, which is why the map can come out empty — and when it does, step 3 runs anyway.

The re-keying loop looks for each node's own key in the map it is iterating (`AIOrderedMap_Find` at `0x8BC166`, with an insert arm at `0x8BC173`–`0x8BC1C7` complete with the `"list<T> too long"` throw), so the insert arm is dead in practice: it is an inlined `operator[]` applied to a key the map already holds. Worth knowing before anyone reads the insert arm as a second code path.

`CAIUnit +0x294` is the same circular-sentinel ordered map `FINDINGS-subdivide.md` describes for the local container in slot 83 — `+0x00` comparator byte, `+0x04` sentinel, `+0x08` size, nodes `{next, prev, key, value}`.

### Step 3 — select target areas, their provinces, and the hostile ground on the way (`0x8BBFF9`–`0x8BC82F`)

```
free and zero the CLists at agent->+0x1BC and agent->+0x1CC
myAreas = {}                                              ; local CList [ebp-0x74]
for each province p of agent->+0x90
    if (p->controller_id (+0x338) == agent->country_id (+0x38)
        && p->area->vf[0]()
        && p->area not already in myAreas
        && 0x47FD90(p->area))
            myAreas += p->area
for (node = ourCountry->areas_first (+0xD30); node; node = node->+8) {
    target = node->data                                   ; a COwnerArea*
    if (!target->+0x68)                                                      next
    if (target == CCountry::GetActingCapitalLocation(ourCountry)->area)       next
    if (!0x47FD90(target))                                                   next
    for each myArea in myAreas {
        if (myArea == target)                                                next
        if (!OwnerAreaPathFind(myArea, target, {Accessible, ourTag}, &path))  next
        if (path.count > 2)                                                  next
        if ( OwnerAreaPathFind(myArea, target, {NoEnemy,    ourTag}, &path))  next
        /* accepted */
        for each province q of target->provinces_first (+0x24)
            if (q not already in agent->+0x1CC)  agent->+0x1CC += q
        jumpOff = {}                                      ; up to three, local CList [ebp-0x64]
        while (jumpOff.count < 3) {
            best = 100000.0f ; pick = 0
            for each province tp of target->provinces_first
                for each province s of agent->+0x90
                    if (s->area != myArea)      next
                    d = CMap::DistanceBetweenProvinces(tp->id, s->id, g_CMap)
                    if (d < best && s not already in jumpOff) { best = d; pick = s; }
            if (!pick) break
            jumpOff += pick
        }
        for each start in jumpOff {
            if (!CCountryTag::FindProvinceRoute(&ourTag, start,
                                                target->provinces_first->data, &route))
                continue
            for each province id in route {
                r = gamestate->provinces[id]
                take = 0
                if (r->controller_id == ourCountry->id)                 next
                if (ourCountry->diplomacy[r->controller_id]->war (+0x20))        take = 1
                else if (r->controller == "REB" || ourCountry->tag == "REB")     take = 1
                else take = UndeclaredWarCoversProvince(
                                 ourCountry->diplomacy[r->controller_id]->+0x24, r)
                if (take && r not already in agent->+0x1BC)  agent->+0x1BC += r
            }
        }
    }
}
```

So:

- **`CAIUnit +0x1CC/+0x1D0/+0x1D4` is a `CList<CMapProvince*>`: every province of every selected target area.**
- **`CAIUnit +0x1BC/+0x1C0/+0x1C4` is a `CList<CMapProvince*>`: the enemy-held, rebel-held or undeclared-war-covered provinces lying on the up-to-three shortest routes from the operations area to those target areas.** This is the list `0x8BD270` reads at `0x8BD9C8` to double a province's score when the stance is 3 or more — which closes the loop between the two bodies in the other direction, and explains why a pushing agent values exactly the provinces next to the road forward.
- **`CCountry +0xD30` is the record's `areas_first`**, the country's own `COwnerArea` list. The payload is confirmed a `COwnerArea` four independent ways in this one block: it is compared against `GetActingCapitalLocation()->+0x2B4`, handed to `0x47FD90` alongside provinces' `+0x2B4`, handed to `OwnerAreaPathFind` as a goal, and walked at `+0x24` as a province `CList`.
- The last branch is an **inlined copy of `UndeclaredWarCoversProvince` (`0x4763A0`)**, which the record already has: it walks the undeclared war's vector at `+0x28`/`+0x2C` against the province's `regions_first` (`+0x358`) list. `CDiplomacyStatus +0x24` is the record's `undeclared_war`. Nothing new, but it is the reason the block looks like an unexplained vector walk if you read it cold.

The acceptance test is the interesting part and I want to be precise about it, because it reads backwards until you read both functors:

```
0x00481000  OwnerAreaCost_Accessible(area)   ; functor vftable 0x15C1BF8
    if (area->provinces_count (+0x2C) == 0)                     return -1.0f
    if (!0x4EFA50(countryArray[ourId], 0))                      return -1.0f
    return +1.0f

0x00480F50  OwnerAreaCost_NoEnemy(area)      ; functor vftable 0x15C1BF0
    tag = (area->provinces_count == 0) ? "---"/0
                                      : area->provinces_first->data->controller
    if (CCountry::IsEnemyTag(countryArray[ourId], &tag))        return -1.0f
    if (area->provinces_count == 0)                             return -1.0f
    if (!0x4EFA50(...))                                         return -1.0f
    return +1.0f
```

Both functors are three dwords on the stack — `{vftable, ourTagChars, ourTagId}` — and both return their cost in `ST0`, with `-1.0` from `[0x170AC0C]` as the impassable marker. The condition the caller imposes is **"a path exists under `Accessible`, in at most two area-hops, and no path exists under `NoEnemy`"**. Under the plainest reading of `0x4EFA50` (rva `0xEFA50`, the record's "false for tag id 0 and `REB`; true if `IsSameSide`; otherwise military access and not an enemy") the two functors should agree on every area, which would make the condition unsatisfiable. They do not obviously differ, and **I am reporting that rather than explaining it**: either `0x4EFA50`'s recorded summary is incomplete, or the two functors' argument passing differs in a way the first 0x70 bytes of each do not show (`0x481000` pushes `0` and `countryArray[ourId]` while holding the area's first province in `EDI` and our tag chars at `[esp+8]`; `0x480F50` pushes the same pair with a different register layout). Settling it needs `0x4EFA50` read end to end, which I did not do. What is solid is the shape: **two different reachability predicates over the owner-area graph, a two-hop limit, and acceptance on a disagreement between them.**

I read only `0x4811A0`'s first 0x90 bytes. Its arguments are established — start area in `ECX`, goal area, cost functor, out `CList` — and it opens by seeding a one-node list with the start and short-circuiting when start equals goal, so it is a graph search returning a path. The name `OwnerAreaPathFind` is therefore `inferred`. `0x47FD90` I read only the head of: it takes an area, returns a bool, and walks the area's `neighbour_areas_first` (`+0x34`) deriving each neighbour's controller tag with the same `"---"`-for-empty idiom. I am **not** naming it.

---

## 4. Who spends what these two functions produce

Scanned over the AI module `0x8AF000`–`0x8E0000` by decoding from int3-run boundaries, with the containing function reported. **The window is the limitation to state**: `CAIUnit`'s code is confined to this module as far as anything here has found, but a reader outside it would not be seen, and a bare whole-image displacement scan is useless for these offsets (trap 12 — `[reg+0x2B4]` alone returns pages of `CMapProvince::area`, and `[reg+0x2C8]` returns slot 78's and `CAIUnit::ClearUnit`'s writes, which are on a **`CUnit`**, not the agent: `ClearUnit` compares `eax` against `esi->+0x64` two instructions earlier and slot 78's `ebx` is the register it reads `oob_level` off).

| field | writers | readers |
| --- | --- | --- |
| `+0xC0`/`+0xC4` front vector | `0x8BBB50` step 1 | `0x8BD270` (`0x8BD74B`), `0x8B630E`, `0x8B634E` |
| `+0x1BC` hostile-route list | ctor, dtor, `0x8BBB50` | `0x8BD270` (`0x8BD9C8`), `0x8C8EE0`-family (`0x8C9D25`, `0x8C9E81`, `0x8CA0F3`), `0x8CA97A`, `0x8D57F0` |
| `+0x1CC` target-area provinces | ctor, dtor, `0x8BBB50` | `0x8C8EE0`-family (`0x8C9D03`), `0x8D57F0`, `0x8D653C` |
| `+0x294` objective-nearness map | ctor, dtor, `0x8BBB50` | **nothing else in the window** |
| `+0x2C0` scored-province list | ctor, dtor, `0x8BD270` | `0x8CC450`, `0x8DCAE0`, `0x8D57F0` (`0x8D6FB3`) |
| `+0x2D0` province→record map | ctor, dtor, `0x8BD270` | `0x8CC450` |
| `+0x34C` score total | ctor, `0x8BD270` | `0x8C8EE0` (`0x8C9329`, `0x8C934D`, `0x8C9489`) |

The positive control for that scan is in the table itself: it finds five readers of `+0x1BC` and three of `+0x2C0` in the same pass that finds none of `+0x294`, so its silence about `+0x294` is the kind that means something. A second, independent control points the same way: `AIOrderedMap_SubscriptFloat` (`0x8DCE40`), the only subscript used on `+0x294`, has exactly **two** callers in the whole image — `0x8BBB50` and `0x8D57F0` — against the 50 callers of its sibling `0x8DCF30`. So **the objective-nearness scores in `+0x294` are written on every replan and read by at most one function**, `0x8D57F0`, which this pass did not read.

### `0x8C8EE0` is what spends the scores, and it proves what they are

`0x8C8EE0` (rva `0x4C8EE0`) is the function containing `0x8C9329`. It walks the `0x1C` records and does, per record `rec`:

```
0x008C9317  xmm0 = rec->+8                        ; the score
0x008C931C  xmm1 = 1.0f
0x008C9324  if (1.0f > score && agent->+0x34C >= 1.0f)  { rec->+0xC = 0; next }
0x008C933A  share = (float)[ebp+0x14] * (double)score / (double)agent->+0x34C
0x008C9363  k     = (int)share
            carry += share - k                    ; [ebp-0x2C], largest remainder again
0x008C938D  if (k > rec->+0x18)  { carry += k - rec->+0x18; k = rec->+0x18; }
0x008C93B6  rec->+0xC = k
```

A count in `[ebp+0x14]` is divided among the ops-area provinces **in proportion to each province's score over the total in `+0x34C`**, by the largest-remainder method, capped per province at `rec->+0x18`. That is the apportioning, and it is not in `0x8BD270`. It also fixes the record layout:

```
the 0x1C scored-province record  (allocated at 0x8BD491, and by 0x8BCD60 for its own pair)
  +0x00  CMapProvince*  the province
  +0x04  float          zeroed by 0x8BD270 and not written by it
  +0x08  float          the priority score 0x8BD270 computes; the sort key of the +0x2C0 list
  +0x0C  int            the amount apportioned to this province (0x8C93B6); -1000 is a sentinel
                        the reader at 0x8C9478 tests for
  +0x10  int            zeroed at birth; not written by 0x8BD270
  +0x14  int            zeroed at birth; not written by 0x8BD270
  +0x18  int            a per-province cap, written at 0x8C930C from 0x8BF350
```

### The two containers are a pair, chosen by the plan stance

Both consumers that take the list and the map together choose between two identical pairs on the same test:

```
0x008CC4CE  (0x8CC450)        0x008DCB26  (0x8DCAE0)
    list = &agent->+0x2C0         list = &agent->+0x2C0
    map  = &agent->+0x2D0
    if (unit && unit->+0x208 == 0) {   if (unit->+0x208 == 0)
        list = &agent->+0x2FC              list = &agent->+0x2FC
        map  = &agent->+0x30C
    }
```

`(+0x2FC, +0x30C)` is the pair `CAIUnit::RebuildOpsAreaProvinceRecords` (`0x8BCD60`) builds, and `0x8BCD60` is called **only** when `unit->plan_stance == 0` — every caller guards it that way. So the two are **parallel copies of the same structure, one per plan-stance regime**: stance 0 uses `0x8BCD60`'s, every other stance uses `0x8BD270`'s. `0x8BD270` fills its pair unconditionally, so at stance 0 its work is computed and then ignored. Both consumers are reached from `CAIUnit::Tick` — `0x8DCAE0` at `0x8B09F0` and `0x8CC450` at `0x8B0BC2`.

---

## 5. `CCountry +0xCC`, settled

`FINDINGS-subdivide.md` left this open with two obstacles: `CCountry::LoadKey` never writes it, so there is no save oracle, and it had one reader, through the `GetCountry` idiom. Both obstacles were real and neither was the way in.

### What `0x8BD270` contributes

Not a value, but a **type constraint**, and a tight one. The field is averaged over a set of *other countries* and divided by *our own*; the ratio is compared against 0.150 with a floor at 0.050; and the consequence is that a province stops mattering. So `+0xCC` has to be a country-level magnitude, comparable across countries, where our own figure is normally many times a weak neighbour's and where 15% is a meaningful "not a threat" line. That rules out most of what sits near it and points at a strength or size measure.

### The search that found it

Scan every function in `project.json` whose name begins `CCountry` — 68 of them — and decode each body looking for `[reg + 0xCC]`, with `+0xC4` (`officers`, known) as the positive control.

| displacement | hits in `CCountry*` bodies |
| --- | --- |
| `+0xC4` (control) | 4: `CCountryDataBase::CCountryDataBase`, **`CCountry::LoadKey` writes it**, **`CCountry::SaveContents` reads it**, `CCountryDataBase::AddCountry` |
| `+0xCC` | 10, of which the only writers are `CCountryDataBase` setup and **`CCountry::RecountUnitTotals`, four times** |
| `+0xC8` | 5, same shape |
| `+0xD0` | 14, same shape |

The control finds the known writer and the known reader of `officers`, so the method sees what it is supposed to see.

### What `RecountUnitTotals` does

`CCountry::RecountUnitTotals` (rva `0x1004F0`, VA `0x5004F0`) — the record already has it, as the serial body of `ProcessCountryFunctor`, running **hourly on a TBB worker**, and its own entry ends with the open item "what `CCountry +0xC8/+0xCC/+0xD0/+0x108C` count". They count this:

```
this->+0xC8 = this->+0xCC = this->+0xD0 = this->+0x108C = 0
three passes:
  A) for each unit of this->units (+0xBAC) with expeditionary_owner_id (+0x290) == 0
  B) for each unit of each faction member (this->faction +0xD8, member list +0x28)
        whose expeditionary_owner_id == this->id            ; units on loan to us
  C) for each of this->deployments (+0x688) whose kind is 0x4B4
  in each pass, per unit:
      this->+0xC8   += unit->regiments_count (+0x40) * 1000
      per subunit s of unit->regiments (+0x38):
          if (unit->vf[15]() && (this->mobilised (+0x94) || !s->is_reserve (+0xA4)))
              ++this->+0x108C
          this->+0xCC += *GetSubUnitDefinitionCombatValue(s->sub_unit_definition_ptr (+0x58))
          this->+0xD0 += s->sub_unit_definition_ptr->officers (+0x118)
```

`GetSubUnitDefinitionCombatValue` (rva `0x1A8690`) is already `confirmed` in the record as "**what one brigade type is worth to the AI**", out of the definition's own stats. So:

- **`CCountry +0xCC` is the country's total brigade combat value**, summed over every brigade, ship and wing it commands including expeditionary units lent to it and finished-but-unplaced deployments, in the same units `GetSubUnitDefinitionCombatValue` produces — thousandths.
- `CCountry +0xC8` is the total number of regiments/ships/wings, x1000 (`CUnit +0x40` is the record's `regiments_count`).
- `CCountry +0xD0` is the **officers those brigades require**, the sum of each definition's `officers`, which puts it directly beside the `officers` pool at `+0xC4`.
- `CCountry +0x108C` counts the land brigades in service — those under a unit the land predicate (unit slot 15) accepts, counting reserves only while the country is mobilised.

### Two more readers, and the second confirmation

`FINDINGS-subdivide.md` named the limitation of the `GetCountry` scan exactly right: it cannot see a country reached as `[db + 0x16C][id]`. Running that chain as well (country array load, index by id, then `[+0xCC]` with the base register pinned to the indexed result) finds **two more readers**, both in `CEU3AI::UpdateUnitStances` (rva `0x4912D0`, VA `0x8912D0`):

```
0x008918C3  movd  xmm1, dword ptr [edx + 0xcc]     ; per member of a side's country list
0x008918D3  mov   ecx,  dword ptr [eax + 0xfe8]
...
0x00891994  movd  xmm0, dword ptr [eax + 0xcc]
0x0089199C  cvtdq2ps xmm0, xmm0
0x0089199F  cvtss2sd xmm0, xmm0
0x008919A3  divsd xmm0, qword ptr [0x160a300]      ; / 1000.0
0x008919B6  addsd xmm0, xmm1                       ; into a running total
```

Both sum `+0xCC / 1000` across the members of a side. Two things follow. **`+0xCC` is in thousandths** when used as a magnitude, which is consistent with the ratio in `0x8BD270` and with trap 7. And `UpdateUnitStances` is the AI's stance picker, whose own record entry says "the arithmetic that produces the 0-4 value was not read" — it is a comparison of the two sides' summed combat value, so that open item now has a lead. Control for this chain: the same scan at `+0xBCC` (`Manpower`) and `+0xA90` (`effective_neutrality`) returns 28 and 17 hits including named readers, so it is not a scan that finds nothing.

So `+0xCC` has **three** readers in the image across both access idioms — `0x8BD270` and the two in `UpdateUnitStances` — and one writer, and the writer settles it.

---

## 6. The verdict on each name

### `0x8BD270` — `CAIUnit::ApportionOpsArea` must go

**The name is wrong, not merely unproven.** It apportions nothing: it computes one float per ops-area province, and the apportionment of a count across those provinces is done by `0x8C8EE0` out of the figures this function leaves behind. A name that attributes the consumer's job to the producer is worse than a neutral one, because it closes the question of where the apportioning happens — and the answer is a different function in a different part of the module.

It was always an `inferred` guess, from "the remainder arithmetic and the two float outputs" at the head. Both inputs to that guess now read differently: the remainder arithmetic is a largest-remainder spreader for a flat `+20` peacetime bonus, and of the "two float outputs" one is the sum of the scores and the other is never written.

**Proposed: `CAIUnit::ScoreOpsAreaProvinces`, `likely`.** The mechanism is read end to end and is `confirmed`; `likely` is for the word "score", which is a description of what the float is rather than a name the game gives it. The strongest evidence for the word is external to this body: `0x8C8EE0` divides a quantity in proportion to `record->+8 / agent->+0x34C`, which is what a weight is, and `CList_InsertByDescendingScore` keeps the list sorted on it best-first, which is what a priority is.

### `0x8BBB50` — `CAIUnit_RebuildFrontFromOpsArea` is true of a third of the body

**The name is not wrong, it is incomplete, and the incompleteness is the dangerous kind** — it describes `0x8BBB50`–`0x8BBD43` accurately and says nothing about `0x8BBD49`–`0x8BC82F`, which is 2.8 of the 3.3 KB and writes three containers the first part does not touch. Anyone citing the name would conclude the function is a front rebuilder and that `+0x1BC`, `+0x1CC` and `+0x294` come from somewhere else. They do not.

The name also lacks a `::`, which is trap 11's symptom; the receiver is on the stack here so the convention is right, but the qualifier should be there for the same reason the sibling callees have it.

**Proposed: `CAIUnit::RebuildFrontAndApproaches`, `likely`.** "Front" for step 1, which is `confirmed`: enemy-held neighbours of the area above the 200 `ai_front_value` floor. "Approaches" for steps 2 and 3, which are read end to end but whose purpose — ranking the front by nearness to the objectives, and finding the target areas and the hostile ground on the way to them — is a reading of intent and not of a label. If the second half had to be named on its own it would be `SelectTargetAreasAndRoutes`; the single-name compromise is the cost of the function doing both.

Two alternatives considered and rejected: keeping the old name with an extended comment (rejected — the name is what gets cited, and five waves of this folder's history say the comment is not read), and renaming to something purely structural like `CAIUnit::ReplanStep1` (rejected — it would be unfalsifiable, and the body does have a subject).

---

## 7. Corrections to the record

1. **`0x4BBB50` does not abut `0x4BC860`.** Five `int3` sit between `ret 8` at `0x4BC85B` and the next prologue at `0x4BC860`. The extent and the signature in that entry are right.
2. **`CAIUnit +0x364` is not `manage_reserve`.** `project.json` contradicts itself: `+0x364` is named `manage_reserve` off one slot-78 reader while `+0x365`'s own comment states that `+0x364` means "shooting war on my frontier". `CAIUnit::ClassifyOpsAreaFrontier` writes it, and `0x4BD270` reads it twice — as the switch between a peacetime and a wartime scoring formula, and as the enable for zeroing a province with no hostile neighbour. Three sites, one meaning. Rename to `frontier_at_war` and re-read slot 78's use as "only bother with the reserve calculation when my frontier is at war".
3. **`CAIUnit +0x34C` is not `apportion_a`.** It is the sum of the per-province scores, read as the denominator by `0x4C8EE0` at `0x4C934D` and `0x4C9489`. Rename to `ops_area_score_total`.
4. **`CAIUnit +0x350` is not `apportion_b`.** It is zeroed by `0x4BD270` and written by nothing in the AI module that this pass's scan could see (control: the same scan sees `+0x34C`'s three readers and `+0x2C0`'s three). The name was a sibling of a name that is now gone; it should become `unknown_350` until a writer turns up.
5. **`CAIUnit +0xC0`'s contents are established.** The entry says "What it holds was not established". It holds the provinces adjacent to the operations area that `CAIStrategy::IsFrontWorthyEnemy` accepts and whose `ai_front_value` (`CMapProvince +0x5C`) is at least `g_AiFrontProvinceThreshold` (200). `0x4BD270` reads it at `0x4BD74B` to count a province's front-facing neighbours.
6. **`CCountry::RecountUnitTotals`'s open item is closed.** Its entry and `FINDINGS-schedule.md`'s "what `CCountry +0xC8/+0xCC/+0xD0/+0x108C` count" both resolve: `+0xC8` regiments x1000, `+0xCC` total brigade combat value, `+0xD0` officers required, `+0x108C` land brigades in service. The entry's statement that it "adds `unit->+0x40 * 1000` to `+0xC8`" is right; the three passes (own units, expeditionary units on loan, pending deployments) are worth adding, as is the fact that each `+0xCC` term is `GetSubUnitDefinitionCombatValue` of the brigade's definition.
7. **`CEU3AI::UpdateUnitStances`'s arithmetic has a lead.** Its entry says "The arithmetic that produces the 0-4 value was not read". It sums `CCountry +0xCC / 1000` over the members of each side — `0x4918C3` and `0x491994` — so the stance comes out of a comparison of the two sides' total brigade combat value, with `CCountry +0xFE8` as a second term.
8. **`CEU3AI +0x2C` has six consumers in the unit AI, not four.** `0x4BD343` and `0x4BDB9A` are two more, and they use it in opposite senses: the plan-objective area set is built only when it is **clear** (the human's own country) and the `defend_prov` priority is added only when it is **set**.
9. **`FINDINGS-subdivide.md`'s open item 3 is answered.** "Which list of `CCountryTag` the mean is taken over" — the `_alloca`'d array of the distinct controller tags of the current province's "interesting" neighbours, rebuilt per province. "What the resulting `[ebp-0x3C]` is used for" — it is a thousandths multiplier applied to that province's score at `0x4BDBFB`.
10. **`FINDINGS-subdivide.md`'s open item 2 is answered**, in section 5: `CCountry +0xCC` is the total brigade combat value, written by `CCountry::RecountUnitTotals`.
11. **`FINDINGS-subdivide.md`'s open item 4 is answered**: `0x4BBB50`'s middle is read here.

---

## 8. Field and layout notes

```
CCountry
  +0xC8    int  total regiments/ships/wings x1000. CCountry::RecountUnitTotals (0x1004F0) zeroes it
                and adds unit->regiments_count (CUnit +0x40) * 1000 per unit, in three passes
  +0xCC    int  TOTAL BRIGADE COMBAT VALUE, thousandths. The sum of
                GetSubUnitDefinitionCombatValue (0x1A8690) over every brigade, ship and wing the
                country commands - its own units, units on loan from faction members
                (CUnit +0x290 == our id) and finished deployments. Written only by
                CCountry::RecountUnitTotals, hourly, on a TBB worker; CCountry::LoadKey never
                writes it, so it is NOT in the savegame. Three readers:
                CAIUnit::ScoreOpsAreaProvinces (0x4BD78F, 0x4BD7D2) averages it over the hostile
                countries across a province's borders and compares that with our own against the
                0.150 / 0.050 thresholds; CEU3AI::UpdateUnitStances sums it over a side's members
                at 0x4918C3 and 0x491994, dividing by 1000 each time
  +0xD0    int  OFFICERS REQUIRED: the sum of each commanded brigade's definition `officers`
                (CSubUnitDefinition +0x118). Same writer, same three passes. Sits beside the
                officers pool at +0xC4
  +0x108C  int  land brigades in service: counted per subunit of a unit the land predicate
                (unit slot 15) accepts, taking reserves (CSubUnit +0xA4) only while the country
                is mobilised (CCountry +0x94). Same writer
  +0x4B8        NOT a field of its own - it is strategy(+0x48C).defend_prov (CAIStrategy +0x2C).
                CAIUnit::ScoreOpsAreaProvinces walks it at 0x4BD8E3 and reads node->data->+8 as a
                province id and node->data->+0xC as an int priority

CAIAgent  (so CAIUnit too - single inheritance, one vftable at offset 0)
  +0x34  CCountryTag  the agent's country: four characters here, the id at +0x38. Both bodies
                read it as `lea ecx,[agent+0x34]; call CCountryTag::GetCountry`, and
                AreaMayWidenFrontSearch's caller reads +0x38 as the country id directly. NEW
  +0x38  int          the id half of +0x34. NEW

CAIUnit
  +0x1BC/+0x1C0/+0x1C4  CList<CMapProvince*> first/last/count: the enemy-held, rebel-held or
                undeclared-war-covered provinces on the up-to-three shortest routes from the
                operations area to the selected target areas. Cleared and refilled by
                CAIUnit::RebuildFrontAndApproaches (0x4BBFFB clears, 0x4BC72F-0x4BC791 fills).
                CAIUnit::ScoreOpsAreaProvinces doubles a province's score once per member of this
                list the province is adjacent to, but only when plan stance >= 3 (0x4BD9C8).
                Four other readers: 0x4C8EE0's cluster, 0x4CA97A, 0x4D57F0. NEW
  +0x1CC/+0x1D0/+0x1D4  CList<CMapProvince*>: every province of every selected target area. Same
                writer (0x4BC3E5-0x4BC44A). Read by 0x4C956B, 0x4D57F0 and 0x4D653C. NEW
  +0x294  the circular-sentinel ordered map, front province -> a 0..100 score, 100 on the front
                province nearest the unit's plan objectives. Layout as slot 83's local map:
                +0x294 comparator byte, +0x298 sentinel node, +0x29C size; nodes
                {next, prev, key, value}. Built by CAIUnit::RebuildFrontAndApproaches: mean map
                distance per front province first (0x4BBF98), then rescaled in place
                (0x4BC120-0x4BC1E8). Subscripted through 0x4DCE40, which has only two callers in
                the image, so the only possible consumer is 0x4D57F0. NEW
  +0x298  the map's sentinel; +0x29C its size. NEW
  +0x2A4/+0x2A8  a vector that CAIUnit::RebuildFrontAndApproaches clears at 0x4BBD9E-0x4BBDBE and
                never fills; its begin is then handed to 0x10F4A0 with ecx = 0x10. What it holds
                is not established. NEW, named unknown_2a4 / unknown_2a8 deliberately
  +0x2B4  int   written to the constant 7 by CAIUnit::RebuildFrontAndApproaches at 0x4BBDD8 and by
                nothing else this pass found. Meaning not established. NEW, unknown_2b4
  +0x2B8  int   written to the constant 8 at 0x4BBDDF. Meaning not established. NEW, unknown_2b8
  +0x2C0/+0x2C4/+0x2C8  CList first/last/count of the 0x1C scored-province records, kept in
                DESCENDING score order by 0x4DD4B0. Cleared by CAIUnit::ScoreOpsAreaProvinces
                through 0x81C80 at 0x4BD30A and refilled one record per ops-area province.
                Consumers pair it with the map at +0x2D0, or with (+0x2FC, +0x30C) instead when
                unit->plan_stance (CUnit +0x208) is 0. **+0x2C8 is this list's count; the
                `byte [reg+0x2C8]` sites in slot 78, CAIUnit::ClearUnit and CAIUnit::SetPlanStance
                are CUnit +0x2C8, a different object (trap 12).** NEW
  +0x2D0  the ordered map CMapProvince* -> the 0x1C record, same layout as +0x294. Cleared through
                0x4DCFC0 at 0x4BD2D3, filled at 0x4BDC6A. Read by 0x4CC450. NEW
  +0x34C  float  the sum of every ops-area province's score. Rename of `apportion_a`
  +0x364  uint8  rename of `manage_reserve`: shooting war on the agent's frontier

the 0x1C scored-province record (allocated at 0x4BD491 by the scorer, and by 0x4BCD60 for its
own pair at +0x2FC/+0x30C)
  +0x00  CMapProvince*  the province
  +0x04  float          zeroed at birth, not written by the scorer
  +0x08  float          the priority score; the sort key of the +0x2C0 list
  +0x0C  int            the amount apportioned to the province by 0x4C93B6; -1000 is a sentinel
  +0x10  int            zeroed at birth
  +0x14  int            zeroed at birth
  +0x18  int            a per-province cap on +0x0C, written at 0x4C930C from 0x4BF350

constants CAIUnit::ScoreOpsAreaProvinces uses - only weakMul is thousandths
  0x171DBB0  float  10.0     the base score
  0x160A340  double 10.0     the peacetime flat term
  0x160A318  double 20.0     the wartime flat term, and the largest-remainder payout
  0x160A358  double 100.0    +100 per region whose +0x6D byte is set
  0x160A838  float  15.0     a supply depot's base score at plan stance >= 3
  0x160A360  double 2.0      the multiplier per adjacency to a +0x1BC province
  0x160A4E8  double 3.0      the narrow-front multiplier
  0x160A260  double 0.2      the narrow-front threshold, front length / ops-area size
  0x160A300  double 1000.0   the weakMul divisor
  0x171DBAC  float  1.0      the largest-remainder carry test
  0x160A248  double 1.0      subtracted when the carry pays out
  0x15BED10  float  0.0      the spread test in RebuildFrontAndApproaches
  0x160A500  float  1e5      the jump-off province best-distance seed
  0x160A83C  float  150.5    floorf'd to 150, the ratio threshold
  0x160A7B4  float  50.5     floorf'd to 50, the multiplier floor
  0x170AC0C  float  -1.0     the owner-area cost functors' impassable marker
```

## 9. Functions this named

| address | rva | name | how sure |
| --- | --- | --- | --- |
| `0x8BD270` | `0x4BD270` | `CAIUnit::ScoreOpsAreaProvinces` — **replaces** `ApportionOpsArea` | read end to end; name `likely` |
| `0x8BBB50` | `0x4BBB50` | `CAIUnit::RebuildFrontAndApproaches` — **replaces** `CAIUnit_RebuildFrontFromOpsArea` | read end to end; name `likely` |
| `0x481C80` | `0x81C80` | `CListOfOwned_Clear` | read end to end |
| `0x8DD4B0` | `0x4DD4B0` | `CList_InsertByDescendingScore` | read end to end |
| `0x8DCE40` | `0x4DCE40` | `AIOrderedMap_SubscriptFloat` | read via its use and its two callers; `likely` |
| `0x8DCF30` | `0x4DCF30` | `AIOrderedMap_Subscript` | already described in the record's prose, unnamed in `project.json`; `likely` |
| `0x8DCFC0` | `0x4DCFC0` | `AIOrderedMap_Clear` | already described in prose; 4 callers; `likely` |
| `0x8DD130` | `0x4DD130` | `AIOrderedMap_Find` | already described in prose; 13 callers; `likely` |
| `0x8DE4D0` | `0x4DE4D0` | `AIOrderedMap_NewNode` | 2 callers, both insert paths; `likely` |
| `0x4811A0` | `0x811A0` | `OwnerAreaPathFind` | head only; name is `inferred` |
| `0x480F50` | `0x80F50` | `OwnerAreaCost_NoEnemy` | read end to end; name `likely` |
| `0x481000` | `0x81000` | `OwnerAreaCost_Accessible` | read end to end; name `likely` |

Not named, deliberately: `0x47FD90` (head only), `0x8C8EE0` (the apportioner — identified and its two load-bearing instructions read, body not), `0x8CC450`, `0x8DCAE0`, `0x8D57F0`, `0x50F4A0`.

## 10. What is not established

1. **`CAreaBorder` is not the owner of the `+0x6D` byte, and nothing names the region class.** `CMapProvince +0x358` is the record's `CProvince::regions_first`, and `ScoreOpsAreaProvinces` adds `+100` per region whose byte at `+0x6D` is set. What a "region" is as a class — and therefore what that byte is — is open. I eliminated `CAreaBorder`: its constructor at `0x47DF70`–`0x47DFA5` initialises only to `+0x28`, so a `+0x6D` is out of range for it. **The search that would settle it**: `UndeclaredWarCoversProvince` (rva `0x763A0`) compares `CUndeclaredWar +0x28`/`+0x2C`'s members against this list, so the members' class is whatever that vector holds; `findRefs.py --vftable` on the candidates the RTTI export offers with "region" in the name, or `pointsto.py` on a live node payload, would name it in one step. A live `dumpStruct.py` on `provinces[n]->+0x358`'s first payload would name it for free, because the vftable identifies the class.
2. **Why the two owner-area cost functors can ever disagree.** The acceptance test in `RebuildFrontAndApproaches` step 3 requires a path under `OwnerAreaCost_Accessible` and *no* path under `OwnerAreaCost_NoEnemy`, and on the record's summary of `0x4EFA50` the two predicates should coincide. **The search**: read `0x4EFA50` (rva `0xEFA50`) end to end — it is short and already partly described — and settle the two functors' argument passing, which differs in register layout between `0x80F50` and `0x81000`.
3. **`0x4811A0`'s body.** Read only its first 0x90 bytes. Whether it is a BFS, a Dijkstra or an A\* over the `COwnerArea` neighbour graph, and whether the `+1.0`/`-1.0` cost is used as a weight or only as a passability flag, are not established — and the second of those decides whether "at most two" means two hops or a cost of two. **The search**: read it; it has few callers and the functor interface is now known.
4. **`0x47FD90`.** A bool over an owner area, applied three times in step 3 as a precondition on both our own areas and the target. Head only.
5. **What `CAIUnit +0x294`'s scores are for.** They are rebuilt on every replan and have at most one consumer, `0x4D57F0` (via `0x4DCE40`, 2 callers in the image). **The search**: read `0x4D57F0` — it also reads `+0x1BC`, `+0x1CC` and `+0x2C0`, so it is probably the single largest consumer of both bodies' output and is the obvious next target.
6. **What `0x4C8EE0` apportions.** Its `[ebp+0x14]` is the count divided among the provinces in proportion to the scores, and `0x4BF350` supplies the per-province cap at `rec->+0x18`. Given `CSetPlanForcesCommand` is issued below slot 76, brigades are the obvious guess and I am not making it. **The search**: read `0x4C8EE0` and its caller; the argument is a plain stack int and its producer will name it.
7. **Why the largest-remainder bonus count is `m mod n`.** `m` is the element count of `CAIUnit +0x12C`, one of slot 78's containers, whose contents are not established; `n` is the ops-area size. `m mod n` is an odd quantity to spread. **The search**: establish what `+0x12C` holds, which is a slot-78 question, not an `0x4BD270` one.
8. **`CAIUnit +0x2A4`/`+0x2A8`, and the constants 7 and 8 at `+0x2B4`/`+0x2B8`.** All four are written by `RebuildFrontAndApproaches` and nothing in the module reads them that the windowed scan saw. The scan's window is `0x8AF000`–`0x8E0000`; **a negative outside it is not claimed**, because a whole-image displacement scan on these offsets is useless (trap 12: `[reg+0x2B4]` returns a page of `CMapProvince::area`). **The search**: `fieldchain.py --holder 0x64 ...` from a known `CAIUnit` pointer, or widening the int3-run decode to the whole of `.text` and accepting the noise.
9. **Whether the payload of `defend_prov` is a `CIDValue`.** Here `+8` is a province id and `+0xC` an int priority; in slot 83 a `CIDValue`'s `+8`/`+0xC` are the two halves of an object id and `+0x10` is the value. Both readings are solid for their own site, so either the class is generic over its halves or they are two classes. **The search**: `findRefs.py --vftable` on `0x15EC094` to find every constructor, and read the one `CAIStrategy::LoadKey` uses for `defend_prov`.
10. **Nothing was watched in a running game.** Four cheap falsifiers this file adds, in order of cost:
    - **`CCountry +0xCC` should rank countries the way armies do.** `dumpStruct.py` four countries of different sizes with `--length 0x120` and compare `+0xC8`, `+0xCC` and `+0xD0`: `+0xC8 / 1000` should equal the country's brigade count exactly, and `+0xD0` should be close to `+0xC4` (`officers`) for a country that is not short of officers. If `+0xC8/1000` is not an integer brigade count, section 5 is wrong.
    - **`CAIUnit +0x2C8` should equal the ops-area province count** on any agent whose `+0x90` is non-empty, since the scorer writes exactly one record per province. A mismatch means `+0x2C0`'s shape is misread.
    - **`CAIUnit +0x294`'s values should all be in [0, 100]** after a replan, with at least one 0 and one 100 whenever the map holds two or more entries. That is a direct test of the rescaling loop.
    - **`CAIUnit +0x1BC` should hold only provinces the country is not the controller of.** One non-ours-excluded entry refutes the route filter as read.
