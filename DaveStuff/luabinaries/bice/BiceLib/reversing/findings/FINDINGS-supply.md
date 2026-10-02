# How supply reaches a unit

`CSupply::DailySupplyPass` (rva `0x2872D0`) is the daily distribution, and it is not a
method - `ret 0x14`, nothing in `ecx`:

    void __stdcall CSupply::DailySupplyPass(
        CCurrentGameState* state,
        int* capacity,      // one entry per province id
        int* fuelNeed,
        int* supplyNeed,
        int* stepLoss)

The four arrays are `_alloca`'d, zeroed, and filled only for provinces whose
`CProvinceTemplate +0x13D` is set - `capacity` from `SupplyCapacity` (`0x9DD00`),
`supplyNeed` and `fuelNeed` from `SupplyNeed` (`0x9E020`), `stepLoss` from `SupplyLoss`
(`0x9DE80`).

**In Arcade the network pass does not run at all.** Both entry points - `0x287070`
(`RunDailySupplyPass`) and `0x278AB0`, reached from `CInGameIdler::Enter` - are gated on
`arcade_mode` (`CCurrentGameState +0xC9C`) being at or below zero. That is the same switch
`CUnit::ConsumeSuppliesAndFuel` takes its arcade branch on, read the other way round: in
Arcade a unit draws straight from the owner's capital pool and none of what follows
happens. Every save carries `setgameplayoptions = { 2 0 }`, so Normal is the default and
this is the path that runs.

## What it walks

`CCurrentGameState +0x54`, `provinces_by_supply_order`. `supply_depot_id` (`+0x48`) is
only ever compared for equality, so it is the **network label**; `supply_depot_distance`
(`+0x4C`) is the distance from the depot, `0` at a depot. A neighbour counts only when it
carries the same label and is strictly closer.

**Farthest first is derived, not assumed.** The **daily** pass at rva `0x282C20` -
`RunDailyPass`, reached from the tick body at `0x2813F0` only when the day number changes -
rebuilds the network when `CCurrentGameState +0x50` says it is dirty, resets the order to id
order, then `qsort`s it with the comparator at rva `0x27B100` - 0x2A bytes that return `+1` when
the *second* argument's `+0x4C` is larger, so it sorts descending. Element 0 is the
province farthest from its depot, and the one-sweep argument below stands on that rather
than on the field's name.

**Once a day, not once an hour**, which this said until 2026-09-30. `0x282630` is the
*hourly* pass and ends at `0x282C1D` with `ret 4`; `0x282C20` begins a new function with its
own prologue, and the two abut with no padding, which is how they came to be read as one.
The hourly pass does call `CSupply::RebuildSupplyNetwork` (at `0x2826E8`, on the same dirty
flag), so a depot label changed during the hour is acted on within the hour - but the sort
and `RunDailySupplyPass` are behind the day-change branch.

**The distance is weighted, not a hop count**, and **the weight belongs to the province
entered, not to the edge.** `CSupply::SpreadFromDepot` (rva `0x289BE0`) relaxes outward
from each depot, and the cost of a step is worked out from the province being entered
alone - its modifier block at `CMapProvince +0x114`, which is a **pointer** to an array of
**8-byte entries** indexed by the modifier id, value in the low dword and a
`CModifierDefinition*` in the high one. So a modifier's offset is `id * 8`, which is why the
three reads below are `+0x60`, `+0x68` and `+0x70` for ids 12, 13 and 14:

    infra = MODIFIER_INFRASTRUCTURE * (1000 + LOCAL_INFRASTRUCTURE + GLOBAL_INFRASTRUCTURE) / 1000
    infra = clamp(infra, 10, 1000)
    step  = max(4000 - 4 * infra, 1000) / 1000  *  CProvinceTemplate +0x24

Both divisions are integer, so the factor before `+0x24` is **1, 2 or 3** - this said
1 to 4 before, which is wrong. The lower clamp is what puts 4 out of reach: it is a
function static built once at `0x289CD5` from the float `10.5` at `0x160A680` through
`floor` and `ftol`, so `infra` is never below 10 and `4000 - 4 * infra` never above 3960.
The bands, as a share of full infrastructure:

| infra | factor |
| --- | --- |
| above 0.5 | 1 |
| over 0.25, up to 0.5 | 2 |
| 0.25 and under | 3 |

Whether an infrastructure *level* of 5 lands on `infra == 500` has not been read live, so
those are shares of full infrastructure and not levels.

**So each province has one entry cost, and a route's distance is the sum of the entry
costs along it** - which is what makes a route reconstructible from the stored fields
alone. A same-network neighbour `u` of `v` is a predecessor of `v` on a least-cost route
exactly when `d(u) == d(v) - cost(v)`, and because `cost(v)` does not depend on which way
`v` is entered, every predecessor of `v` sits at the same distance. `cost(v)` need not be
recomputed at all: it is `d(v)` less the largest `d(u)` among `v`'s closer same-network
neighbours.

**The relaxation re-enqueues, so the stored distances are true minima.** The queue is
FIFO, but a province that improves is pushed back on - the node is allocated at
`0x289DAA`, immediately after the write at `0x289DA4` - which makes this Bellman-Ford by
queue rather than one breadth-first sweep. Without that re-push the descent above would
not be sound.

The plain hop count is a *different* field, `CProvince +0x50`, which the daily pass never
reads. The same loop maintains it, as the popped province's hops plus one at each
improvement - so it counts hops **along the winning route**, not the map's shortest hop
count, and `+0x4C` less `+0x50` is what that route's infrastructure costs on top of its
length. `100000` is the reset "infinity".

A province's label is its controller's **acting capital province id**, from
`CProvince::UpdateSupplyDepot` (rva `0xA70C0`) via `CCountry::FindSupplyDepot` - so two
provinces share a network when they resolve to the same acting capital, and a province
whose `supply_depot_id` equals its own id *is* a depot.

`g_CMap +0x2200` is the province vector indexed by province id, and `CMap`'s constructor
reserves it to 14500 - so it never grows and province pointers never move, which is what
makes walking it this way safe.

## The three phases

**Phase 1** swaps `drawn`↔`last_drawn` and `throughput`↔`last_throughput`, then zeroes
today's `drawn`, `throughput` and `need`. So the `last_*` buffers are yesterday's, and
phase 2 reads them.

**Phase 2**, forward - farthest from the depot first. A province that **is** its
controller's acting capital is skipped but for copying `pool` into `last_pool`: the
national stockpile is the end of the chain, not a link in it. For everything else:

    need   = supplyNeed[id] / fuelNeed[id]   (raised to 1000 if under it and the pool is thin)
    want   = need * SUPPLYPOOL_DAYS - pool   (SUPPLYPOOL_DAYS is 35)
    local  = min(need, current_producing)    and CCountry +0xA24/+0xA28 record it
    want   = clamp(want - local, 0, need * 2)
    drawn += want

Then three sweeps over the template's `ProvinceEdge` vector, each considering only
same-network, strictly-closer neighbours:

1. **Take goods.** Available is the neighbour's `last_pool` capped by `capacity[nid]`, and
   scaled down where yesterday's `last_drawn` exceeded its `last_throughput` - congestion
   rationing, by this province's share of yesterday's demand. The take bumps the
   neighbour's `drawn` *and* `throughput`, comes off its `pool`, and arrives less
   `stepLoss[id]`.
2. **Split the rest** evenly over the qualifying neighbours, each share capped by that
   neighbour's `capacity - drawn`.
3. **Dump what is left** into each closer neighbour's `drawn`.

Sweeps 2 and 3 move **demand, not goods**, and that is what the farthest-first order buys:
by the time the pass reaches the depot's immediate neighbours, every unmet want in the
network is already sitting in their `drawn`. One sweep does what would otherwise need to
iterate to a fixed point.

**Phase 3**, backward - nearest the depot first. A province short in **both** supplies and
fuel keeps everything. Otherwise `surplus = pool - (need * 35 + drawn)`:

- **At a depot**, the surplus ships to the controller's acting capital, limited by the sum
  over the province's convoys of `NavalBaseCapacity * CConvoy::GetEfficiency / 1000`, and
  recorded in `CCountry::sent_back`.
- **Anywhere else** the whole surplus goes to the *first* closer neighbour on the same
  network, **with no capacity limit at all**. Only the sea leg is metered.

## What the two double buffers mean

**`drawn` is what was asked of a province today** - its own shortfall plus everything
passed inward from farther out. **`throughput` is what actually moved through it.** Their
ratio is the next day's rationing input.

`drawn / SupplyCapacity` is exactly what BiceLib's supply-load map mode already draws,
which is worth knowing: that map mode was built before any of this was understood, and it
happens to show the right quantity.

## Supply is not produced here

`current_producing` is read only to reduce what has to be fetched. Every pool increase in
this function is a transfer out of another pool. The stockpile is filled upstream:
`0x278AB0` snapshots every country's stockpile - the acting capital's `pool`, or
`pool_in_exile` where `+0x95` is set - into a vector of `CGoodsPool` before calling the
pass.

## Not settled

- **Which other countries can label a province.** `CCountry::FindSupplyDepot` recurses
  through `CCountry +0xF34`/`+0xF38` and the area's `+0x34` list, and until those are named
  it is not settled whether that reaches allies, puppets or lend-lease partners.
- **`COwnerArea +0x69`/`+0x70`**, the area-level override that gets first refusal on a
  province's label. `COwnerArea` is not in `project.json` at all.
- **What reads `CCurrentGameState +0x58`**, the largest distance on the map clamped to 500.
- **`CProvinceTemplate +0x24`**, the per-province traversal cost the relaxation multiplies
  its step by. Its runtime values were never sampled, and that is the one thing that would
  say whether the weighted distance and a hop count coincide in practice.
- **`CCountry +0xA1C`** is an unnamed `CGoodsPool` - the slot between `pool_in_exile`
  (`+0x9F8`) and `unit_demand` (`+0xA40`) is exactly one pool wide, and this pass writes
  its supplies and fuel at `+0xA24`/`+0xA28`, as does `CUnit::ConsumeSuppliesAndFuel`.
  Left unnamed deliberately.
- **`CProvinceTemplate +0x13D`**, the flag that decides whether a province takes part at
  all. Tested at every level; still unidentified.
- `CMapProvince +0x54`/`+0x58`, the two extra unit lists `SupplyNeed` walks, and
  `CConvoy +0xAC`, the lend-lease efficiency factor.

## defines.lua is read by name, not by position

This section previously warned that `CDefinesSupply` past `+0x40` was anchored against an
old copy of the mod's `defines.lua` and could not be trusted. **That was wrong, and the
model behind it was wrong.** `RADIO_CORPS_LEADER_DISTANCE` at `+0x210` is correct, and so
is every other recorded supply define.

`LoadDefines` (rva `0x46210`) is one unrolled run of 396 loads, each of the shape

    mov   esi, [ebx + 0xAC]      the block
    push  0x15B93C0              "SUPPLY_TAX", a literal in .rdata
    call  ReadDefineThousandths
    mov   [esi + 0x34], eax      a displacement compiled into the function

so a define's offset **cannot move when the mod's file changes**. Reordering
`common/defines.lua` does nothing. A key the file does not define stores 0; a key the file
defines that the executable never asks for is simply never read, and BlackICE has four of
those - `PRIDE_SUNK_DISSENT_IMPACT`, `WHITESEA`, `WHITESEA_BLOCKER` and
`GFX_RAINIMPACT_LIMIT`.

The positional reading looked confirmed because `country` and `economy` happen to sit in
the engine's order in both files. `military` is where it comes apart, and the engine's own
order is not the file's there even ignoring the mod's additions.

`reversing/scripts/definesMap.py` reads the whole map out of the executable and diffs it against
both `project.json` and a mod's `defines.lua`. **That is the check worth running after a
defines change** - not to find moved offsets, but to find keys the engine wants and the
file no longer provides.

One naming wart left alone: `CDefinesSupply` is a misnomer. `CDefines +0xAC` is the whole
179-entry `military` block, from `MAX_MANPOWER` at `+0x0` to `NEW_LEADER_ORG_HIT` at
`+0x2C4`.
