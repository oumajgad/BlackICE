# The two bodies behind CAIUnit slot 73's air and naval halves

Read statically off `hoi3_tfh.exe` on 2026-10-02 with the game not running. Addresses are
**virtual**, based at `0x400000`, with the rva beside them wherever a finding names one.

The job was to earn or remove two `inferred` names: `CAIUnit_ReorganiseAirUnits` (`0x8CD890`,
rva `0x4CD890`) and `CAIUnit_ReorganiseNavalUnits` (`0x8D0880`, rva `0x4D0880`). They had
survived three waves on the strength of their gates and call lists alone.

**In one line.** The *domain* half of each name is right and is now **confirmed from
instructions**: `0x8CD890` touches nothing but air and `0x8D0880` nothing but naval. The *verb*
is wrong — "reorganise" names one phase out of four (air) and one out of nine (naval), and the
dominant activity in both is **issuing the agent's air and naval mission orders for the pass**.
And the recorded extent of `0x8CD890` was short by 5,813 bytes, which is where the record's
"19 KB between them" came from.

## Extents and both boundaries

### `0x8CD890` — the recorded extent is wrong, by more than half the function

`project.json` has `0x4CD890-0x4CEE68 (ret 8)`. The `ret 8` at `0x8CEE68` is real but it is
**not the end**: it is a shared epilogue laid out in the middle of the function. Three
conditional branches *before* it jump past it, and four jumps *after* it come back to it.

```
0x008CEE1A  jne     0x8cee6b          ; if (force)                -> the second half
0x008CEE26  jne     0x8cee6b          ; if (country->at_war)      -> the second half
0x008CEE2F  jne     0x8cee6b          ; if (country->+0xACD)      -> the second half
0x008CEE31  lea     esi, [ebp - 0x144]   <- the epilogue proper starts here
0x008CEE4F  mov     al, byte ptr [ebp - 0xd]
0x008CEE68  ret     8
0x008CEE6B  mov     eax, dword ptr [esi + 0x64]     ; the second half begins
0x008CEE74  je      0x8cee31          ; plan_air_stance == 0 -> back to the epilogue
...
0x008CF9DE  je      0x8cee4f
0x008CF9F6  jmp     0x8cee4f
0x008D04CE  je      0x8cee4f
0x008D04E6  jmp     0x8cee4f
```

Walking every branch from `0x8CD890` reaches **3231 instructions** and every byte up to
`0x8D051D`; the only gaps are seven alignment `nop`s (`8d 49 00`, `8d a4 24 ...`). So:

| | air | naval |
| --- | --- | --- |
| extent | `0x8CD890`-`0x8D051D` (rva `0x4CD890`-`0x4D051D`) | `0x8D0880`-`0x8D3EA1` (rva `0x4D0880`-`0x4D3EA1`) |
| bytes | **11,406** (recorded: 5,593) | 13,858 (recorded: correct) |
| `ret`s inside | one, `ret 8` at `0x8CEE68` | two, `ret 8` at `0x8D08E5` and `0x8D3E67` |
| last block | the `bad_alloc` throw, `0x8D04EB`-`0x8D051D`, reached by `je` at `0x8CE16B` | the `bad_alloc` throw, `0x8D3E6A`-`0x8D3EA1`, past the final `ret` |
| padding after | `int3` x2 at `0x8D051E`, then `0x8D0520` | `int3` x14 at `0x8D3EA2`, then `0x8D3EB0` |

**Trap 2, upper boundary.** The previous function ends `ret 4` at `0x8CD88C`, there is a single
`int3` at `0x8CD88F`, and `0x8CD890` opens `55 8B EC 64 A1` (SEH prologue).
`image.functionStart(0x8CD890)` answers `0x8CD890`, and `retsBefore(0x8CC690, 0x8CD890)` ends on
that `ret 4` — the boundary is sound.

**Trap 2, and a fresh pair of worked examples.** `functionStart` is *badly* wrong inside this
function, in the second of trap 2's two ways:

```
functionStart(0x008CEE6B)  = 0x008CDED6    ; wrong - inside 0x8CD890
functionStart(0x008D04EB)  = 0x008CF05D    ; wrong - inside 0x8CD890
functionStart(0x008D3E6A)  = None          ; the naval throw tail
```

Both wrong answers are lone `0xCC` bytes that fall inside a four-byte displacement or immediate
and are followed by a byte in the prologue set (`0x8CDED6` is `6a 10` = `push 0x10`, the
`operator new(0x10)` of a list node; `0x8CF05D` is the same). There are **twenty-eight** such
isolated `0xCC` bytes between `0x8CD890` and `0x8D051D`. So in this region a padding scan that
accepts a run of one is useless, and `functionStart` cannot be used at all — which is why
`FINDINGS-power.md` was right to attribute these two bodies by taking the greatest direct-call
target at or below a site instead.

**The check that says "look".** `image.retsBefore(0x8CD890, 0x8D051E)` returns exactly one entry,
`(0x8CEE68, '8')`, and `retsBefore(0x8D0880, 0x8D3E6A)` returns two. In both cases the single
disassembly question — *does anything jump past it?* — settles it in one scan.

**`0x8D0520` really is its own function**, not a cold block of the air body: `int3` x2 before it,
a fresh `55 8B EC 83` prologue, `ret 8` twice, and **four callers, all four inside `0x8D0880`**
(`0x8D268A`, `0x8D32DD`, `0x8D335D`, `0x8D382E`). It is a naval helper that lazily builds
`CCountryDataBase` and tests the agent country's faction (`CCountry +0xD8`) — not read further.

## Signature, callers and the conditions

Both are `ret 8`, so `__stdcall` with two dword arguments, and both return a bool in `al`.

```
bool __stdcall CAIUnit_ManageAirUnits   (CAIUnit* agent, int  force)   ; 0x8CD890
bool __stdcall CAIUnit_ManageNavalUnits (CAIUnit* agent, bool force)   ; 0x8D0880
```

One caller each, both in **`CAIUnit` slot 73** (`0x8B0730`), both under the same "is this agent
the topmost one for its unit" walk that slot 76 uses:

```
0x008B0C3D  mov     eax, dword ptr [esi + 0x64]      ; agent->unit
0x008B0C40  mov     ecx, dword ptr [eax + 0x198]     ; walk up +0x1E0 until +0x198 is set
0x008B0C64  cmp     ecx, esi
0x008B0C66  jne     0x8b0c73                         ; not the top agent -> skip
0x008B0C68  mov     edx, dword ptr [esp + 0xc]       ; the daily-stagger flag, as a DWORD
0x008B0C6C  push    edx
0x008B0C6D  push    esi
0x008B0C6E  call    0x8cd890

0x008B0C98  cmp     byte ptr [esp + 0xc], 0          ; daily stagger
0x008B0C9D  jne     0x8b0cac
0x008B0C9F  cmp     byte ptr [esi + 0x85], 0         ; or a naval replan is pending
0x008B0CA6  jne     0x8b0cac
0x008B0CA8  xor     al, al
0x008B0CAA  jmp     0x8b0cb1
0x008B0CAC  mov     eax, 1
0x008B0CB1  push    eax
0x008B0CB2  push    esi
0x008B0CB3  call    0x8d0880
```

So the air body is called with slot 73's daily-stagger flag; the naval body with
`dailyStagger || agent->+0x85`. **Neither return value is used** — slot 73 drops `al` on the
floor at `0x8B0C73` and `0x8B0CB8`.

**The air call pushes a dword where slot 73 only ever wrote a byte.** `[esp+0xc]` in slot 73 is
written `mov byte ptr [esp+0xc], 0`/`1` at `0x8B09E3`/`0x8B09EA`; its upper three bytes still
hold the top of an unrelated int stored there at `0x8B0820` (a modulo-24 hour value). The air
body **reads byte 3 of that argument**:

```
0x008CE14E  mov     al, byte ptr [ebp + 0xf]
0x008CE155  mov     byte ptr [ebp - 0x144], al
```

`[ebp-0x144]` is the first byte of a stack hash container (sentinel node at `[ebp-0x140]`, bucket
vector at `[ebp-0x134]` filled with 16 copies of the sentinel by
`std::vector::_insert_n` (`0x50F4A0`), mask 7 at `[ebp-0x124]`, maxidx 8 at `[ebp-0x120]`,
max_load_factor `1.0f` at `[ebp-0x11C]`), and nothing ever reads that byte back — every later use
is `lea esi/edi, [ebp-0x144]` for the container as a whole. So this is **an uninitialised read
with no observable consequence**, not a second parameter. It is recorded here only so the next
reader does not spend an hour on it. The naval caller zero-extends properly
(`movzx ecx, al` at `0x8B0C33` is the neighbouring site; `0x8B0CAC` sets a clean 1).

Entry gates:

```
air     0x8CD8BA:  if (agent->air_units_count (+0x104) < 1) return false
naval   0x8D08A1:  if (!force && !country->at_war (+0xACC) && !country->+0xACD) return false
        0x8D08E8:  if (force) agent->+0x85 = 0
        0x8D08FE:  if ((agent->naval_units_last - naval_units_first) < 4) return false   ; no fleets
```

Both then require an area: `CAIUnit::GetArea(agent)`, and when that answers null they resolve the
unit's current-province id pair `+0x380`/`+0x384` through the object-id resolver (`0xA9D390`, the
stack-argument sibling of `FindPersistentById`) and bail if it is not found. The naval one
additionally requires the resolved area's `+0x80` to equal the agent's own tag id
(`0x8D0986`).

## Verdict on `CAIUnit_ReorganiseAirUnits` (`0x8CD890`, rva `0x4CD890`)

**Air: confirmed. Reorganise: rejected. Rename to `CAIUnit_ManageAirUnits`, `likely`.**

### Why "air" is now confirmed rather than inferred

Three independent instruction-level readings, any one of which would do:

**1. It reads all eight of `CSubUnitDataBase`'s cached air role definitions and none of the
others.** The prologue caches their `type_index` (`CSubUnitDefinition +0x24`) into locals:

```
0x008CD945  mov edx,[eax+0x64] ; +0x24 -> [ebp-0xf8]   strategic_bomber
0x008CD951  mov edx,[eax+0x58] ; +0x24 -> [ebp-0xc0]   tactical_bomber
0x008CD95D  mov edx,[eax+0x5c] ; +0x24 -> [ebp-0x84]   cas
0x008CD979  mov edx,[eax+0x60] ; +0x24 -> [ebp-0xf4]   cag
0x008CD985  mov edx,[eax+0x68] ; +0x24 -> [ebp-0xa0]   naval_bomber
0x008CD991  mov edx,[eax+0x74] ; +0x24 -> [ebp-0xac]   transport_plane
0x008CD99D  mov edx,[eax+0x6c] ; +0x24 -> [ebp-0x50]   interceptor
0x008CD9A9  mov eax,[eax+0x70] ; +0x24 -> [ebp-0x18]   multi_role
```

`CSubUnitDataBase +0x58`..`+0x74` are exactly the eight air keys and there are no others; the
naval keys at `+0x88`..`+0xAC` and the land keys at `+0x2C`..`+0x84` are never touched.

**2. It reads `CUnit::plan_air_stance (+0x20C)` and never `plan_naval_stance (+0x210)`.** Three
sites: `0x8CD9B5`, `0x8CEE6E`, `0x8CF908`. A scan of the whole body for `[reg+0x210]` returns
zero hits. The naval body is the exact mirror: `+0x210` at `0x8D24DB` and `0x8D3243`, `+0x20C`
nowhere.

**3. It is the only place in `.text` that creates most air missions.** `image.findBytes` for
`push imm32` of each order save token:

| token | `push imm32` sites in `.text` |
| --- | --- |
| `0x718` `air_intercept` | **`0x8CF8B9` only** |
| `0x6FD` `logistical_strike` | **`0x8CFD54` only** |
| `0x717` `join_air` | **`0x8CECE4` only** |
| `0x6FB` `ground_attack` | `0x8A096A` (CAIInvasion), `0x8CF5E5` |
| `0x574` `rebase_air` | `0x8CD29A`, `0x8CE595` |

The four remaining air tokens are absent from that scan because they are loaded into a register
or a local first, not pushed — the **positive control** is that the same scan finds the five
above. They are at `0x8CFF98` (`mov eax, 0x6F9` `strategic_bomb`), `0x8CFF9F`
(`mov eax, 0x579` `nuke_mission`), `0x8D025D` (`mov dword ptr [ebp-0x1c], 0x700` `naval_strike`)
and `0x8D030C` (`... 0x701` `port_strike`) — all four inside `0x8CD890`.

### Why "reorganise" has to go

Regrouping — detaching a wing from an over-mixed air group into a new unit — is phase 3 of four,
about 1.8 KB of 11.4. It posts a `CCreateUnitCommand` and a `CTransferSubUnitCommand`
(`0x8CE8D3` and `0x8CE90E`), and that pair is the whole of what the old name described. The
other three phases cancel orders, rebase, and **assign seven kinds of air mission**; the mission
blocks alone are 5.8 KB. A name that covers a sixth of a function and is then cited as if it
covered the function is exactly the failure mode the record has had before.

### The block map

Four phases. The compiler laid the epilogue between phases 3 and 4.

**Phase 1, `0x8CDA90`-`0x8CE142` (1,714 bytes), read closely — triage the air units.**
Walks the `CList` at `agent->air_units_first (+0xFC)`.

```
for (node = agent->+0xFC; node; node = node->+8) {
    wing = node[0]
    if (wing->retreat (+0x158)) continue                               0x8CDA97
    if (wing->order->slot16() == join_air) {                           0x8CDAB4
        hq = resolve(order->+0x10, order->+0x14) - 8                   0x8CDAD8 (0xA9D390)
        if (hq) { add hq and wing to listA; continue }                 ; the join is still live
        IssueUnitOrder(ai, none, wing, wing->base->province)            0x8CDBC1
    }
    if (!country->at_war && !country->+0xACD) goto notThreatened       0x8CDBCB
    if (!wing->+0x98 || !base->slot0()) goto notThreatened
    CollectUnitsMovingIntoProvince(baseProvince, &list, 1, agentTag)    0x8CDC38 (0x8B1480)
    if (list.count > 0) {                     ; enemy land units are marching on the airfield
        force = 1                                                      0x8CDC54
        if (wing->order->slot24() && wing->order->slot16() != rebase_air)
            IssueUnitOrder(ai, none, wing, ...)                        0x8CDC8E
        add wing to listB; continue
    }
notThreatened:
    thresholds = plan_air_stance == 2 ? (0.5f, 0.75f) : (0.7f, 0.85f)  0x8CD9B5
    CountSubUnitsByTypeIndex(wing, counts)                             0x8CDD3D
    if (counts[cag] > 0 || counts[interceptor] != 0) thresholds *= 0.5  0x8CDD48
    for (w in wing->+0x38) {                                           0x8CDDE2
        s = w->+0x5C / w->slot12()       ; strength fraction
        o = w->+0x60 / GetMaxOrganisation(w)
        if (strengthHigh > s) add w to listC                           0x8CDED1
        if (orgHigh      > o) flagOrgLow = 1                           0x8CDF29
        if (strengthLow  > s || orgLow > o) flagUnfit = 1              0x8CDF60
    }
    if (flagUnfit && wing->order->slot24()) {                          0x8CDF6C
        if (AllSubUnitsAreCag(wing) && wing->base->slot1())            0x8CDF89
             IssueUnitOrder(ai, carrier_protection, wing, base)        0x8CDFD6
        else IssueUnitOrder(ai, none, wing, base)
        continue
    }
    if ((flagOrgLow || listC non-empty) && !wing->order->slot24()
        && UnitIsAtOwnBase(wing)) continue       ; leave it resting    0x8CE016
    if (UnitHasBlockingOrder(wing)) continue                           0x8CE03D
    if (wing->combats_count (+0x11C) > 0) continue                     0x8CE062
    add wing to listB                                                  0x8CE087
}
```

**The four fitness thresholds are selected by the plan's `air_stance` and halved for a carrier
or interceptor group.** At stance 2 a wing needs 50% strength and 75% organisation (25%/37.5%
for CAG/interceptor groups); at any other stance 70% and 85%. Every constant is a compiled-in
`float` literal — `0.5f` at `0x15AB304`, `0.75f` at `0x17179A8`, `0.7f` at `0x160A2E8`, `0.85f`
at `0x160A834`, and the halving factor `0.5` (a double) at `0x160A308`. None is a define.

**Phase 2, `0x8CE1E9`-`0x8CE63E` (1,086 bytes), read closely — rebase.** Runs only when
`force` is set, i.e. when the caller's daily flag is on **or** phase 1 found an airfield with
enemy land units marching into it. Per wing in listB it picks a destination list on the agent by
role, scores every province in it, and issues `rebase_air` to the best:

```
if (counts[cag] >= 1) skip                                             0x8CE240
if (counts[strategic_bomber] > 0)             list = agent->+0x20C     0x8CE259
else if (wing->def->strategic_attack (+0x17C) > 50000) list = agent->+0x20C
else if (counts[naval_bomber] > 0)            list = agent->+0x21C     0x8CE270
else if (counts[transport_plane] > 0) {
        if ((agent->+0x170 - agent->+0x16C) & ~3 > 0) skip             0x8CE29F
        list = agent->+0x22C }
else                                          list = agent->+0x1FC     0x8CE253

best = currentBaseProvince;  bestScore = 1e6f    ; [0x160A598]
for (t = list; t; t = t->+8) {
    prov = provinces[t->+8]
    CollectUnitsMovingIntoProvince(prov, &l, 1, tag); if (l.count>0) skip  0x8CE37D
    score = t->+0xC
    if (wing->parent->oob_level (+0x1F4) != 0)
        score = (score + DistanceBetweenProvinces(agentProvince, prov)) * 0.5   0x8CE3E7
    if (counts[transport_plane] < 1) {
        load  = occupancy[prov->id]                                    0x8CE440
              + sum of u->regiments_count over prov->+0x54->+4
              + (wing->+0x98 != prov->+0x54 ? wing->regiments_count : 0)
        load /= prov->+0x304->+0x24 / 1000.0                           0x8CE4A0
        if (load > 1.0f) score *= load                                 0x8CE4D6
    }
    if (bestScore > score) { best = prov; bestScore = score }          0x8CE502
}
if (best && best != currentBaseProvince) {
    IssueUnitOrder(ai, rebase_air, wing, best->id)                     0x8CE595
    occupancy[best->id]   += wing->regiments_count                     0x8CE5BD
    occupancy[oldBase->id] -= wing->regiments_count                    0x8CE5F3
    add wing to listA;  returnValue = 1                               0x8CE637
}
```

Lower is better. The occupancy map is the stack hash container at `[ebp-0x144]`, keyed by
province id, maintained across the whole pass; `0x8DD0A0` is its `operator[]`. **So the AI
spreads its wings over airfields in proportion to the airfield's size**, and the denominator is
`CMapProvince +0x304 -> +0x24`, which is the one piece of real evidence anyone has had about what
`+0x304` points at — see *What is not established*.

**Phase 3, `0x8CE64F`-`0x8CED97` (1,767 bytes), read closely — split and merge air groups.**
Gated on

```
0x008CE64F  if (!agent->+0x88 && !force) skip the phase
0x008CE662  if (!owner_ai->runs_units (+0x2C) && !agent->unit->+0x205) skip
0x008CE67B  agent->+0x88 = 0
```

For every wing in listB that is out of combat, sitting at its own base, not blocked and not
already in listA, it counts the group's types and applies a **composition rule per role**; any
wing that breaks it is detached. The rules, read off the chain at `0x8CE770`-`0x8CE88A`:

| the wing is a | detach it when |
| --- | --- |
| `strategic_bomber` | the group holds more than **3** strategic bombers |
| `tactical_bomber` | more than **2** tacticals, or any strategic, naval bomber, transport plane or CAS |
| `naval_bomber` | more than **2** naval bombers, or any strategic, tactical, transport plane or CAS |
| `transport_plane` | more than **1** transport plane, or any strategic, tactical, naval bomber or CAS |
| `cas` | more than **2** CAS, or any strategic, tactical, naval bomber or transport plane |
| `interceptor` | the group holds anything that is not an interceptor or a multi_role |
| anything else | `strategic_attack > 50000`, or more than **1** multi_role, or any strategic, interceptor or CAS |

A detachment allocates a fresh unit id (`word[0x1A857EC] + 0x1268`, serial `[0x1A857F8]++`), posts
a `CCreateUnitCommand` through `PostCreateUnitCommand(&id, currentProvince, 2, baseProvince)`
(`0x8CE8D3`) and then one `CTransferSubUnitCommand` (`0x8CE90E`) for the wing. **The third
argument `2` is the kind of unit to create; the naval body passes `1` at both of its sites.**
Afterwards `counts[type]--` (`0x8CE9B7`), `agent->+0x88 = 1` and the return value is set.

Then, for a group with fewer than 3 wings, it walks `agent->+0xFC` for a compatible partner —
neither side may have `strategic_attack > 50000` — merges the two count vectors to test the same
rules, and issues `CreateUnitOrder(ai, join_air, ...)` (`0x8CECEA`).

**The hinge, `0x8CEDA8`-`0x8CEE74`.** If a regroup is still pending after phase 3, the function
**returns 1 without assigning any missions** (`0x8CEE12`). Otherwise phase 4 runs only when
`force` is set or the country is at war (`0x8CEE16`-`0x8CEE2F`), and only when
`plan_air_stance != 0` (`0x8CEE6E`).

**Phase 4, `0x8CEE76`-`0x8D04E6` (5,744 bytes) — assign the missions.** Read as a block map plus
the cited mission sites, not instruction by instruction. The per-wing loop at `0x8CEEF0` repeats
the out-of-combat / at-base / not-blocked / not-in-listA gates and then sorts the wing into one
of four local pools by role (`0x8CEF4B`-`0x8CF042`): tactical/CAS/CAG, strategic bomber or
`strategic_attack > 50000`, naval bomber, interceptor. The tactical pool is capped by a budget
`agent->+0x1E4 * 4` set at `0x8CEEDF` and decremented at `0x8CF08C`/`0x8CF097`, and a wing only
enters it when its definition's `+0x168` is positive.

| block | mission issued | what it scores on |
| --- | --- | --- |
| `0x8CF330`-`0x8CF636` | `ground_attack` (`0x8CF5E5`) | sunrise/sunset (`0x4A7450`/`0x4A74D0`), `CountEnemyLandUnitsInList`, `CWeather::AirCombatEffect` x2, distance x2 |
| `0x8CF670`-`0x8CF8FC` | `air_intercept` (`0x8CF8B9`) | `0x4EFA50` (a hostile-province predicate), `CCountry::IsEnemy`, distance |
| `0x8CF8FD`-`0x8CFC36` | - | cleanup, `CUnitPlan::GetPowerRatio`, `CCountry::IsEnemy` x2, `CProvince::HasHostileLandNeighbour` |
| `0x8CFC37`-`0x8CFD7F` | `logistical_strike` (`0x8CFD54`) | weather, distance |
| `0x8CFDE0`-`0x8CFFF5` | `strategic_bomb` or `nuke_mission` (`0x8CFFD6`) | weather, distance; the token is `nuke_mission` when `country->+0x90 >= 1000` (`0x8CFF8E`) |
| `0x8D0042`-`0x8D03E8` | `naval_strike` or `port_strike` (`0x8D03CE`) | resolves an enemy unit by id pair, `IsEnemy`, weather, sunrise/sunset, distance x3 |
| `0x8D03E9`-`0x8D04E6` | - | cleanup, then `jmp 0x8CEE4F` into the epilogue |

**One global threshold gates the weather test for every one of those missions.** Four sites do
`cmp eax, dword ptr [0x1B15240]` on the result of `CWeather::AirCombatEffect` and bail when it is
larger (`0x8CF4CF`, `0x8CFC96`, `0x8CFF05`, `0x8D00AF`). `image.findValue(0x1B15240)` finds five
readers in `.text` — those four and `0x8B126F` — and **no writer**, which is trap 8's second or
third shape and is discussed under *What is not established*.

**Return value.** `al = [ebp-0xd]`, seeded 0 at `0x8CD8D5` and set to 1 at `0x8CE637` (a rebase
was issued), `0x8CEA19` and `0x8CEA2C` (a group was split or merged), and `0x8CEE12` (a regroup
was still pending). So it means **"I changed the air order of battle"** - and nothing reads it.

## Verdict on `CAIUnit_ReorganiseNavalUnits` (`0x8D0880`, rva `0x4D0880`)

**Naval: confirmed. Reorganise: rejected. Rename to `CAIUnit_ManageNavalUnits`, `likely`.**

### Why "naval" is confirmed

Same three readings, mirrored. It calls `CountShipsByRole` seven times and branches on
`CSubUnitDefinition::is_capital (+0x2F)`, `is_transport (+0x30)` and `is_sub (+0x31)`; it reads
`CUnit::plan_naval_stance (+0x210)` and never `plan_air_stance`; and the `push imm32` scan makes
it the **only** producer of `convoy_raid` (`0x8D2C9F`), `patrol` (`0x8D3776`) and `intercept`
(`0x8D3CCF`), plus two of the three `join_fleet` sites and all three `rebase` sites.

### The block map

Nine top-level loops. The first three were read closely; the rest are mapped by span, iteration
subject and call list.

| loop | bytes | what it does |
| --- | --- | --- |
| `0x8D08CF`-`0x8D098C` | 189 | the entry gate and the area resolution (read) |
| `0x8D099D`-`0x8D0A7F` | 226 | **withdraw from a losing sea battle** (read) |
| `0x8D0B30`-`0x8D0C27` | 247 | **send an idle fleet back to port** (read) |
| `0x8D0D70`-`0x8D1496` | 1,830 | choose a home port, `rebase` there, and split off the ships that cannot use it - `PostCreateUnitCommand(kind 1)` at `0x8D12EA` then a `CTransferSubUnitCommand` per ship in a vector at `0x8D1341` |
| `0x8D14F0`-`0x8D19CD` | 1,245 | **classify what each fleet is already doing** - `slot16()` against `support_attack`, `carrier_protection`, `join_fleet`, `convoy_raid`, `convoy_escort`, `patrol`, `intercept`; cancels with `none` or sends the fleet home |
| `0x8D19F6`-`0x8D2025` | 1,583 | **split fleets by role, and `join_fleet` small ones** - the "reorganise" phase (read) |
| `0x8D2120`-`0x8D23C0` | 672 | enemy-fleet survey - `IsEnemy`, `CountShipsByRole`, distance |
| `0x8D2418`-`0x8D3237` | 3,615 | the big one: `convoy_raid` (`0x8D2C9F`), `rebase` x2, `CConvoy::GetDesiredTransports` x2, `COrder::IsTargetInRange`, `MT19937Next`, the occupancy map x7 |
| `0x8D33C0`-`0x8D37B1` | 1,009 | `patrol` (`0x8D3776`) |
| `0x8D3800`-`0x8D3DC4` | 1,476 | `intercept` (`0x8D3CCF`) and `join_fleet` (`0x8D3D10`) |

**Phase 1, `0x8D099D`-`0x8D0A7F`, read closely.** For every fleet in the vector at
`agent->naval_units_first (+0xDC)`, for every combat in the fleet's `CUnit::combats (+0x114)`
list: skip when the combat's slot 8 answers true or its slot 12 answers false, work out which
side the fleet is on by searching `combat->+0x14 -> +0x40`, take the combat's slot-17 ratio in
thousandths (complemented against `1.0` at `0x160A248` for the matched side), and

```
0x008D0A37  if (0.5f > ratio) {                         ; [0x15AB304]
0x008D0A49      p = CUnit::FindRetreatProvince(fleet)
0x008D0A68      if (p) CEU3AI::MoveUnit(ai, fleet, p->id, 0, 0, 0, 0)
            }
```

**Phase 2, `0x8D0B30`-`0x8D0C27`, read closely.** Per fleet: skip one that is still moving
(`+0x140 > 0`) or whose order's slot 24 answers true; otherwise check `UnitIsAtOwnBase`,
`CMapProvince::CanUnitReach`, and `MoveUnit` it home (`0x8D0C13`).

**Phase 5's composition rules, `0x8D1AD0`-`0x8D1D13`, read closely.** `CountShipsByRole` fills
five counts - subs, transports, screens, carriers, capitals - and
`total = screens + carriers + transports + capitals` (`0x8D1A63`-`0x8D1A80`).

| the ship is | detach it when |
| --- | --- |
| `is_capital` | the fleet holds more than **4** capitals |
| `is_transport` | `agent->unit->+0x284` is zero **and** (more than **4** transports, or any carrier or capital) |
| `is_sub` | more than **3** subs, or the fleet holds **anything** that is not a sub |
| anything else (a screen) | more than **4** screens |

The detachment path is the same shape as the air one: a fresh id, `PostCreateUnitCommand(&id,
currentProvince, 1, baseProvince)` at `0x8D1BA4`, a `CTransferSubUnitCommand` at `0x8D1BEB`,
then the matching role count is decremented (`0x8D1CB4`-`0x8D1CD2`).

**Return value.** `al = [esp+0x37]`, seeded 0 at `0x8D0998` and set to 1 at **only two places**,
`0x8D1D32` and `0x8D1FFC`, both inside phase 5. So the naval bool means "I split or merged a
fleet" and says nothing about the eight other phases - a different meaning from the air one's,
which is a reason not to describe the two as near-twins without qualification.

### Are the two near-twins?

Partly, and it is worth being precise because the brief asked. They share: the same signature and
caller test; the same `operator new(0xDA8)` + `CGameState::CGameState` + `[obj] = 0x15CF674`
inline construction of the `CCurrentGameState` singleton at `0x1A89790` (four times in the air
body, five in the naval); the same `PostCreateUnitCommand` + `CTransferSubUnitCommand` split
mechanism, differing only in the kind argument; the same per-province occupancy map through
`0x8DD0A0`; the same `UnitIsAtOwnBase` / `UnitHasBlockingOrder` / `retreat` / `combats_count`
gate chain; and the same "cancel with `none`, then re-order" idiom.

They are **not** copies. The air body's four phases are ordered triage → rebase → regroup →
missions, with a single mission pass that fans out by role. The naval body has nine phases, opens
with two things the air body has no analogue of (combat withdrawal and sending idle fleets home),
and keeps a separate mission block per order kind. The naval body is 2.4 KB larger and has 314
branch targets against the air body's 350 in 2 KB less code, so it is the flatter of the two.

## Also established

**`0x8B1480` is `CollectUnitsMovingIntoProvince`**, `ret 0x14`, four callers (`0x8CB0C3`,
`0x8CDC38`, `0x8CE37D`, `0x8D6FA8`). Read end to end. For each edge of
`province->path_node_ptr (+0xD4)`'s edge vector (`+0x90`/`+0x94`, stride `0x14`) it skips a
neighbour whose template is not `is_land (+0x13D)` or whose `+0x2B8` unit list is empty, then per
unit requires slot 15, then **either** the inlined at-war test against the caller's tag (when
arg3 is non-zero) **or** `CCountry::IsFriendly` (when it is zero), then requires the unit's
movement destination — `provinces[unit->+0x13C[0]]` when `+0x140 > 0`, else null — to be
**this** province, and pushes `unit->slot9()` onto the output list. With arg3 = 1, which is what
both air call sites pass, it answers *"which enemy land units are marching into this province
right now"*. That is the airfield-evacuation trigger.

**`0x5BD740` is `CUnit::CountSubUnitsByTypeIndex`**, `void __stdcall (CUnit* unit)` with the
output array in **ESI**, `ret 4`, 52 instructions, read end to end. It lazily builds
`CSubUnitDataBase`, memsets `(definitions_end - definitions_begin)` ints at ESI, then walks
`unit->+0x38` doing `counts[subunit->+0x58->type_index]++`. Both bodies `_alloca` the array
(`0x8CDA79`, `0x8CE698`) before calling it. 12 callers.

**`0x8BEAD0` is `PostCreateUnitCommand`.** `void __fastcall (CAIUnit* agent@ESI, int* idPair,
int provinceId, int unitKind, int baseProvinceId)`, `ret 0x10`, three callers — `0x8CE8D3`,
`0x8D12EA`, `0x8D1BA4`, i.e. only these two bodies. It allocates `0x5C` bytes and calls
`0x547870`, which writes vftable `0x15C36D4`: **`CCreateUnitCommand`** per the RTTI export. So
`0x547870` is `CCreateUnitCommand::CCreateUnitCommand`, `ret 0x24`, and the `unitKind` argument
is **1 for a navy and 2 for an air unit** at all three sites.

**`0x5CDC30` is `CUnit_IsAtOwnBase`**, `bool __fastcall (CUnit* unit@ESI)`, bare `ret`, 28
instructions, read end to end, 58 callers:

```
if (!unit->+0x98) return false
if (unit->+0x98->slot0() != unit->current_province_ptr) return false
if (unit->+0x98->slot1()) {
    u = unit->+0x98->+0x18 -> +0xB0
    if (u->+0x11C > 0)  return false
    if (u->+0x110 != 0) return false
}
return true
```

The third clause's object is not identified; the first two are what the name rests on.

**`0x5D1220`**, `bool __fastcall (CUnit* unit@EDX)`, 15 instructions: false if any subunit's
definition has `+0x32` clear, otherwise `unit->regiments_count > 0`. It is the gate for issuing
`carrier_protection` (`0x8CDF89`), which makes `CSubUnitDefinition +0x32` the carrier-air-group
flag — it sits in the run `+0x2C is_air`, `+0x2D is_land`, `+0x2E is_ship`, `+0x2F is_capital`,
`+0x30 is_transport`, `+0x31 is_sub`, `+0x32 ?`, `+0x33 is_rocket`, `+0x34 is_tank`, and `+0x32`
is the only gap. Proposed `is_cag` and `CUnit_AllSubUnitsAreCag`, both `likely`, and they stand or
fall together.

**`CUnit +0x11C` is the count of the `combats` CList at `+0x114`.** `+0x114` is already recorded
as the list head, `CList` is head/tail/count, and both bodies test `+0x11C > 0` as "this unit is
fighting" (`0x8CE062`, `0x8CE6B7`, `0x8CEEF5`, `0x8D1A1A`).

**Four per-role province lists on `CAIUnit`.** Phase 2 picks one of `+0x1FC`, `+0x20C`, `+0x21C`,
`+0x22C` by the wing's role and walks it as a `CList` (payload at `+0`, next at `+8`), taking a
province id from the node's `+8` and a float weight from its `+0xC`. Only the heads are read
here; nothing in either body writes them.

**`CMapProvince +0x54` is the object a unit's home base pointer `CUnit +0x98` points at.** It is
compared for identity against `wing->+0x98` at `0x8CE47D`, and `+0x54 -> +4` is walked as a
`CList` of the units stationed there whose `regiments_count` are summed into the airfield
occupancy figure.

**Four more small things.** The object-id resolver returns a pointer **8 bytes into** the unit —
both bodies do `lea edi, [eax-8]` right after it (`0x8CDAE8`, `0x8D0E6D`, `0x8D1682`), which is
the `CSelectable` subobject at offset 8 that `reversing/README.md` describes for `CCombat`.
`CAIUnit +0x85` is cleared by the naval body at `0x8D08E8` and read by slot 73 at `0x8B0C9F` as
one of the two things that force a naval pass — the naval sibling of `+0x86`
`replan_subordinates`. `CAIUnit +0x88` is read, cleared and set by the air body only, and gates
its regroup phase. And `CAIUnit::GetArea` is called first thing by both, so both inherit its
walk up the `+0x40` parent chain.

## What a mod can and cannot reach

Every numeric constant read in either body is a compiled-in `float` or integer literal, with one
exception and one unknown:

| the AI's number | where it comes from | can a mod move it? |
| --- | --- | --- |
| the four wing fitness thresholds, 0.5/0.75 and 0.7/0.85 | `float` literals at `0x15AB304`, `0x17179A8`, `0x160A2E8`, `0x160A834` | **no** - but which pair is used is chosen by `plan_air_stance`, which `CSetPlanAttributesCommand` can set |
| the CAG/interceptor halving | the double `0.5` at `0x160A308` | **no** |
| the air group composition caps 3/2/2/1/2 | compiled-in immediates in the chain at `0x8CE770` | **no** |
| the fleet composition caps 4/4/3/4 | compiled-in immediates at `0x8D1AD0` | **no** |
| the 50000 long-range cut-off | compiled-in `0xC350`, compared against `CSubUnitDefinition::strategic_attack (+0x17C)` | the **definition** value yes, through `units/*.txt` and technology; the 50000 no |
| the naval disengage bar, 0.5 | `0x15AB304` again | **no** |
| the airfield crowding divisor | `CMapProvince +0x304 -> +0x24`, a building field | the **building level** yes, the formula no |
| the nuke threshold, 1000 | compiled-in, against `CCountry +0x90` | **no** |
| the weather cap on every air mission | the global at `0x1B15240` | **unknown** - see below |

## What is not established

1. **The air body's phase 4 was mapped, not read.** `0x8CEE76`-`0x8D04E6`, 5.7 KB. The gate
   chain, the four pools, the budget and the six mission sites are read; the per-mission scoring
   inside each block is not. The ground-attack block (`0x8CF330`) is the one worth doing next -
   it is the only one that calls `CountEnemyLandUnitsInList`, so it is where the AI decides which
   enemy stack to bomb.
2. **Six of the naval body's nine phases were mapped, not read**, including the 3.6 KB loop at
   `0x8D2418` that contains `convoy_raid`, both `rebase` sites, `CConvoy::GetDesiredTransports`
   twice and the only `MT19937Next` in either body. That random draw at `0x8D2BBF` is the single
   most interesting unread instruction in this file: it is the only non-deterministic step
   anywhere in the two bodies.
3. **The global at `0x1B15240`.** Five readers in `.text`, all `cmp eax, [0x1B15240]` on a
   `CWeather::AirCombatEffect` result, four of them inside `0x8CD890`; **no writer in `.text`.**
   The negative has a control: the same `image.findValue` call finds all five readers, so the scan
   works - what it cannot see is a `.CRT$XCU` static initialiser or a startup define cache, which
   are trap 8's cases 2 and 3. The settling searches are `scratchpad/naval/definecache.py` (which
   recovers 51 cached-define globals and would show this one if it were one) and the `(int)floor(N.5f)`
   static list. Until then the figure that stops the AI flying in bad weather has no name.
4. **What writes `CAIUnit +0x1FC`, `+0x20C`, `+0x21C`, `+0x22C`.** Read-only here. The search is
   `fieldchain.py --holder` over the `0x8B0000`-`0x8E0000` AI functions; a bare `--field` scan on
   `+0x1FC` is worthless because `CUnit +0x1FC` is `plan`, which is read everywhere (trap 12).
5. **`CMapProvince +0x304`.** `FINDINGS-power.md` leaves this open. This file adds one piece of
   evidence and does not close it: at `0x8CE4A0` its `+0x24` is the divisor of the number of
   wings stationed in the province, which reads as an air base's capacity. But slot 78 reads the
   same pointer's `+0x20` as "is the building still there" for an **army**'s AI parameter, which
   an airbase would be an odd thing to be. Either it is a generic "the building this AI cares
   about" slot or one of the two readings is of a different field than it looks. The cheap check
   is the writer in `CProvince::LoadKey`'s building arm, which `FINDINGS-power.md` already
   located for `+0x5C`.
6. **`CAIUnit +0x1E4`**, read once at `0x8CEED2`, multiplied by 4 and used as a countdown on how
   many ground-attack missions may be created in a pass. No writer looked for, and the identity
   is not established, so it is deliberately not named below.
7. **`CSubUnitDefinition +0x168`** - a wing only enters the ground-attack pool when it is
   positive (`0x8CF052`). Not identified.
8. **`CUnit +0x284`** - non-zero switches off the transport-ship composition rule
   (`0x8D1AF7`) and is compared against a province id at `0x8D15EA`. Reads as an amphibious
   operation's target province. Not named.
9. **`CCountry +0xACD`**, which sits beside the recorded `+0xACC at_war` and is tested with it at
   five places across slot 73 and both bodies. Still unnamed anywhere in the record.
10. **`CUnit +0x98`'s class.** Both bodies lean on it constantly - slot 0 is the province, slot 1
    is a validity test - and `CMapProvince +0x54` now gives a second handle on it. It remains the
    cheapest unanswered question about either body, and `FINDINGS-airnaval.md` has been asking it
    since 2026-09.
11. **Nothing here was watched in a running game.** The two cheapest live checks, in order of
    value: `dumpStruct.py` on an AI country's theatre `CAIUnit` for `+0x1FC`/`+0x20C`/`+0x21C`/
    `+0x22C` (four list heads - if they are all null in a live game then phase 2 never rebases
    anything and half of what is written above is dead code); and `plan_air_stance` on an AI
    country's units, because `0` switches phase 4 off entirely and `2` halves every fitness
    threshold.
