# Convoys and trade

Read out of the executable on 2026-10-01, with one savegame used as an oracle for the order
of a convoy's goods mask. Addresses are virtual, based `0x400000`, with the rva where a
finding names one. Nothing here needed a running game.

`CLASSES.md` already had `CConvoy`'s saved layout and the pools a convoy credits; this is the
behaviour - who moves a convoy, what it carries, what a lost one costs, and how a raid is
resolved. It also closes three open questions that were not in this subject:
`CCurrentGameState +0x58`, `CConvoy +0xAC`, and the table at `0x174DA00`.

## The shape of the thing

**A convoy is not a unit and has no ships.** It is a `CConvoy` record with two integer
counters - `transports` (`+0x98`) and `escorts` (`+0x9C`) - a start and end province, a
province path, and a seven-entry goods mask. Nothing in the convoy module and nothing in the
raid code touches `CNavy +0x2E4` `carrying`; a search of `0x4C4F00..0x4C7C00` for that
displacement returns zero hits. **`carrying` is naval transport of land divisions and is a
different system entirely.** When a raid needs something to shoot at, it *builds* a throwaway
`CNavy` out of `convoy` and `escort` ship definitions for the occasion (below).

So the only link between a convoy and the fleet is the `convoy_escort` order, and that link
is one number in the spotting roll.

## Where it runs on the schedule

| what | rva | when |
| --- | --- | --- |
| `RunSupplyAndConvoyIterations` | `0x278AB0` | the supply driver, several iterations a day |
| `CConvoy::RunDelivery` | `0xC6C30` | from the above and from `RunCountryDailyPass` (`0xDA530`) |
| `CConvoy::ClearPath` | `0xC6930` | the day after an attack, and from `0xDA530` |
| lend-lease efficiency regain | inside `0xDA530` at `0x4DABA8` | daily |
| `CCountry::RunDailyTradeRoutes` | `0xFEE70` | from `0xDA530` at `0x4DB43A`, daily |
| `CCountry::RunHourlyAITrade` | `0xDC410` | hourly, per country, **on a TBB worker thread** |
| `CCountry::UpdateMonthly` | `0xDC840` | from `RunMonthlyPass` (`0x283B50`) |

**`0x278AB0` is a loop, and that answers `FINDINGS-supply.md`'s question about
`CCurrentGameState +0x58`.** The iteration count is

    iterations = (tutorial_active (+0xD9D) || arcade_mode (+0xC9C) > 0) ? 1 : max_supply_depot_distance (+0x58) + 2

Each iteration snapshots every country's stockpile into a per-country `CGoodsPool` vector,
runs `CSupply::DailySupplyPass` (`0x2872D0`, skipped in Arcade), then walks every country's
convoys. The test at `0x678F72..0x678F99` is the interesting part: **a convoy whose mask
includes supplies or fuel delivers on every iteration; a lend-lease, trade or pure-resource
convoy delivers only on iteration 0.** That is how supply crosses several sea legs within one
day while a resource shipment crosses one.

**The goods order is the pool's order**, not the game's display order, and a savegame settles
it: `ship={ 1 1 0 0 0 0 0 }` is a supply convoy and `ship={ 0 0 0 1 1 1 1 }` a resource one,
against `CGoodsPool`'s `supplies, fuel, money, crude_oil, metal, energy, rare_materials`. So
goods 0 and 1 - the two the code treats specially throughout - are supplies and fuel.

## What a convoy carries, and the six things that cap it

`CConvoy::RunDelivery` (rva `0xC6C30`, `ret 4`) is the whole convoy economy in one function.
It zeroes the convoy's `daily` pool first, then bails on `path_count < 2`, `transports == 0`,
or `CConvoy::IsRouteUsable` false. **A lend-lease convoy bails here too** - the `jne` at
`0x4C6CBB` jumps straight to the date tail - so nothing in this function moves a lend-lease
load, and where one does move was not established.

With `S` the start province, `E` the end province and `C = GetCountry(S.controller)`:

1. **The source pool** is the national stockpile (`CCountry::GetPool`, so the exile pool at
   `+0x9F8` or the acting capital's `pool`) when `S.area == C`'s acting capital's area, and
   **`S`'s own `pool` (`+0x15C`) otherwise**. That is the mechanism behind the observed
   "a cut-off network's production waits in the loading port's pool".
2. **A puppet keeps 1000.000 of everything.** If `C->overlord_id (+0xF3C)` is the convoy's
   owner, every good has 1,000,000 thousandths subtracted and is then clamped into
   `[0, 99999.000]` by `CGoodsPool::ClampEach` (`0x123830`).
3. **Efficiency** multiplies all seven goods: `CConvoy::GetEfficiency` / 1000.
4. **The destination naval base caps every good**, through `ClampEach(NavalBaseCapacity(E))`
   - and only on a home-loaded run (step 1's same-area case). An overseas-to-overseas run
   skips the cap.
5. **Control.** If `S.controller.id` is neither the convoy's owner nor its puppet, nothing
   moves.
6. **The mask** zeroes every good the `ship` vector does not carry, and then supplies and
   fuel alone are capped by `AreaSupplyAndFuelHeadroom`.

Then the source pays, `ConvoyedOut` is credited on `S.controller` and `ConvoyedIn` on
`E.controller` (each only when the two areas differ), the load lands in `E`'s `pool` - or in
`E.controller`'s national stockpile when `S` sits outside its own controller's capital area -
`E`'s `throughput` buffer is credited, and `convoy->daily` records the run. Last, if
`GetDays(now) - GetDays(last_attack) == 1`, the path is dropped.

### `AreaSupplyAndFuelHeadroom` (rva `0xDD4D0`) - the define that decides how much supply crosses water

Four arguments, two out-params. It walks the destination's area (`CMapProvince +0x2B4`,
through `area->+0x70` and each node's `+0x48`) and sums four figures over its provinces: the
`drawn` buffer's supplies and fuel, and the `pool`'s supplies and fuel. Then

    *outSupplies = areaDrawnSupplies * SUPPLYPOOL_DAYS (military +0x3C) - areaPoolSupplies
    *outFuel     = areaDrawnFuel     * SUPPLYPOOL_DAYS                 - areaPoolFuel

**So an overseas theatre stops importing once its whole area holds `SUPPLYPOOL_DAYS` of its
own daily draw.** It is 35 in vanilla and in BlackICE. Raising it is the only way to let a
convoy route build a deeper stockpile at the far end; the per-run tonnage cap is the naval
base, and this is the stock cap.

## Efficiency, transports and escorts

`CConvoy::GetEfficiency` (rva `0xC6B80`, already in `project.json` as `inferred` - it is
confirmed now):

    eff = 1000
    need = GetDesiredTransports(convoy)
    if (need != 0) eff = transports * 1000 / need
    if (is_lend_lease) eff = eff * lend_lease_efficiency (+0xAC) / 1000

**It is not clamped at 1000**, so a route with more transports than it needs carries more
than its source produces would suggest - the clamps upstream are the naval base and the area
headroom, not this.

`CConvoy::GetDesiredTransports` (rva `0xC7320`) is where two economy defines are read, and
nowhere else in the image reads them:

    p = path_count * CONVOY_PATH_LENGTH_MULT        (economy +0x3C, BlackICE 0.33)
    if (is_trade) p = p * CONVOY_TRADE_WEIGHT_MULT  (economy +0x40, BlackICE 0.2)
    b = provinces[end_province_id]->naval_base->level_max (+0x20) / 10
    return (b * p / 1000 + 1000) / 1000

Note **`level_max`, not `level_current`** - `NavalBaseCapacity` (`0xA75D0`) uses `+0x24`, the
current level, and this uses `+0x20`. So a destination port *built* for level 10 demands ten
times the transports a level-1 port does whatever state it is in, while the tonnage it can
actually land follows the damage. Mod consequence: **`CONVOY_PATH_LENGTH_MULT` is the single
biggest lever on how many transports a nation must build**, and it multiplies the province
count of the path, not a distance.

`CConvoy::ComputeDesiredEscorts` (rva `0xC7450`) fills `+0x94`:

    escorts_wanted = 0
    if (!owner->is_at_war (+0xACC)) return
    want = transports / 2 + 1
    if (transports < GetDesiredTransports(convoy)) want += 3
    if (transports > 10)                          want += 4
    d = GetDays(now) - GetDays(last_attack)
    escorts_wanted = want + (d < 3 ? 5 : d < 7 ? 3 : d < 15 ? 1 : 0)

**Not one define in it.** Every number is a literal, so the escort demand curve is not
moddable, and a convoy wants no escorts at all while its owner is at peace.

### `CConvoy +0xAC` is the lend-lease efficiency

`FINDINGS-supply.md` listed it as "the lend-lease efficiency factor" with nothing behind it.
Three sites settle it, and the mod's own comments on the defines match the arithmetic word for
word:

- `GetEfficiency` multiplies by it / 1000 when `is_lend_lease` is set.
- `CConvoy::LoseShips` subtracts `LL_CONVOY_EFF_IMPACT * transportsLost / transports`,
  floored at 0.
- The daily pass adds `LL_CONVOY_EFF_REGAIN` while it is below 1000.

BlackICE sets those to 0.5 and 0.02, so losing half a lend-lease route's transports drops it
to 75% and it takes twelve days to come back.

## What a lost convoy costs

`CConvoy::LoseShips` (rva `0xC5940`, `ret 0x18`, six arguments: convoy, transports lost,
escorts lost, the province, the attacker's tag and the attacker's country id):

    transportsLost = min(transportsLost, transports)
    escortsLost    = min(escortsLost,    escorts)
    if (is_lend_lease && transportsLost > 0 && transports > 0)
        lend_lease_efficiency -= LL_CONVOY_EFF_IMPACT * (transportsLost * 1000 / transports) / 1000
        lend_lease_efficiency  = max(lend_lease_efficiency, 0)
    escorts    -= escortsLost
    transports -= transportsLost
    threat      = THREAT_FROM_CONVOYS_MODIFIER (economy +0x30) * (transportsLost + escortsLost)
    0x4F4E80(countries[attackerId], &threat, ...)                 ; the attacker's threat; the callee was not read
    ... CONVOY_ATTACK_ON_US / WE_ATTACK_CONVOY, message types convoys_1 and convoys_2 ...
    last_attack (+0xCC) = gameState->tick (+0xBDC)                ; the write, at 0x4C6903

**There is no direct IC, resource or supply penalty anywhere in it.** The cost is entirely
indirect and entirely proportional:

- the goods that route carries tomorrow fall by `transportsLost / desiredTransports`, because
  that ratio *is* `GetEfficiency` and `GetEfficiency` multiplies every good;
- the ships have to be rebuilt at `CONVOY_BUILD_COST` / `ESCORT_BUILD_COST` IC over
  `CONVOY_BUILD_TIME` / `ESCORT_BUILD_TIME` days, each already known to scale by a technology
  figure (`CCountry::GetConvoyBuildCost`, `0xFD590`, and its three siblings);
- a lend-lease route loses efficiency on top, by `LL_CONVOY_EFF_IMPACT` times the share sunk;
- the raider's country gains `THREAT_FROM_CONVOYS_MODIFIER` (0.1 in BlackICE) of threat per
  ship sunk, transports and escorts counted alike.

In thousandths: three transports lost out of eight, on a route that wants eight, takes
efficiency from 1000 to 625, so every good drops to 62.5% of what it was; a lend-lease route
would additionally take `500 * 375 / 1000 = 187` off its `+0xAC`, from 1000 to 813.

## The raid, end to end

`ResolveConvoyRaid` (rva `0x1D1250`) is one body with an early `ret 4` at `0x5D201C` and the
success path continuing at `0x5D201F` in the same frame - trap 3, not two functions. Three
callers, all order code: `0x1998EF` from `CAirConvoyRaid` and `0x19C66B` / `0x1A02CD` from
`CConvoyRaid`.

**1. The raider's attack.** Over the raider's regiments, with `def = CSubUnit->+0x58`:

    a = raider->IsNaval() ? def->convoy_attack (+0x164) : def->sea_attack (+0x168)
    attack += a * (strength/100) * (organisation/100)
    detect  = max over regiments of def->surface_detection (+0x150)

The two per-100 factors are `x * 1000 / 100000` each. **A surface or submarine raider uses
`convoy_attack`; an air convoy raid uses `sea_attack`** - the air mission never reads
`convoy_attack` at all, which is worth knowing before tuning naval bombers.

**2. Finding a convoy**, over every convoy registered in the raider's own sea zone
(`raider->current_province (+0x130)->convoys (+0x38..+0x3C)`):

- skip our own convoys;
- if `CDiplomacyStatus->war (+0x20)` is null the pair is not at war, and the raid is only
  allowed when either side is `"REB"` or the check at `0x763A0` passes on the status's
  `+0x24` (what that object is was not established);
- skip a convoy with no transports;
- then `if (Random() % 50 < detect / 1000)` the convoy is a candidate.

So **the raider's `surface_detection` is the per-convoy find chance out of 50** - a ship with
`surface_detection = 5` finds a given convoy one time in ten per resolution. Among
candidates it prefers one whose `GetDefence` is at or below the attack and otherwise keeps
the first one it saw.

**3. The test.** An **air** raid multiplies the attack by a hardcoded 5.0 before comparing.
If `GetDefence(target) > attack` the raid fails with `CONVOY_TOO_STRONG`, and the victim's
statistics series at `CCountry +0x1184` takes
`-(STRAT_CONVOY_DAMAGE / victim->convoys_count) / 10` - so that figure is **per convoy the
victim owns**, and a nation with 200 convoys records a 200th of it.

`CConvoy::GetDefence` (rva `0xC7C10`):

    d = escorts * 5000                                    ; 5.0 per escort, a literal
    if (path_count != 0) d = d / path_count
    d = d * (1000 + technology_status (+0xDF8)->+0x78) / 1000

**Escort cover is diluted by route length.** Five escorts on a four-province route defend as
6.25; the same five on a twenty-province route as 1.25. `+0xDF8 + 0x78` is the
escort-efficiency technology effect; the 5.0 is not a define.

**4. The sinking.** A throwaway `CNavy` is built (`CNavy::CNavy` at `0x1CEE20`, byte `+0x48`
set) and filled with `CShip` regiments of the `convoy` and `escort` subunit definitions taken
from the singleton at `0x1ADE80` (`+0x88` and `+0xA8`; which is which was not established),
in counts scaled by `max(path_count * 0.2, 1.0)` - **so a longer route exposes fewer ships to
any one raid**, the mirror of the defence dilution. The fight resolves, the two loss counts
are rounded, and `CConvoy::LoseShips` is called.

**5.** `raider->current_province->last_convoy_attack (+0x1C) = gameState->tick` at rva
`0x1D286D`. **That is the writer nothing had found.** It is on the success path, after the
sinking - so the field marks a sea zone where a raid *landed*, not one where a raid was
attempted, and `NAVAL_INTERCEPTION_AFTER_ATTACK_FACTOR` only ever helps interception where
ships actually went down. The search: all 1290 `mov [reg+0x1c], reg32` sites in `.text`,
filtered to the 13 with a `+0xBDC` read in the preceding 24 bytes; this is the only one in
the simulation code and the other twelve write their own objects in diplomacy and interface
code. A store through a different encoding was not excluded.

### What `convoy_escort` actually does, and the trap in it

**A `convoy_escort` order on a fleet does not add escorts to any convoy.** The two are
unrelated:

- `CConvoy +0x9C escorts` is a count bought in production at `ESCORT_BUILD_COST`, and it is
  the *only* thing `GetDefence` reads. It defends automatically, everywhere the route goes, with
  no order and no fleet.
- the `convoy_escort` order (token `0x6E8`) is a naval mission for a real fleet, and its only
  effect on the raid found anywhere is the term `ShouldStartNavalCombat` builds from
  `COrder::GetMissionEfficiency(escort) - GetMissionEfficiency(raid)`, which scales the
  spotting chance of a normal naval combat. `CConvoyEscortOrder`'s own overrides (slots 0, 2,
  4, 6, 11, 13, 14, 15, 16) are the order's movement and validity; slot 14 (`0x19F440`)
  rebuilds the order's path at `+0x48` and nothing in it touches a `CConvoy`.

So escorting is a fleet hunting the raider through ordinary naval combat, and the convoy's
own survival is decided by the `escorts` counter. A mod that wants escorting fleets to matter
has to work through the spotting side.

### `COrder::GetMissionEfficiency`'s modifier table is settled

`FINDINGS-navaldetection.md` left "which modifier ids the table at `0x174DA00` holds" open
because the table is past the end of the file's raw `.data`. Trap 8b was the right lead: a
startup initialiser fills it, and it is `InitMissionEfficiencyModifiers`, rva `0x183810`.

    for (i = 0; i < 33; i++) {
        if (i == 0) { table[0] = 0; continue; }
        token = MissionIndexToOrderToken(i);                       // 0x184640
        name  = <token's save key> + "_eff";                       // the literal '_eff' at 0x15C5310
        id    = (modifierDefs.end - modifierDefs.begin) / 4;       // 0x1686194 / 0x1686198
        def   = new CModifierDefinition(0x2C bytes, vftable 0x15BC4E4);
        def->name (+0x4) = name; def->+0x20 = token; def->id (+0x24) = id; def->+0x28 = 0x0101;
        modifierDefs.push_back(def);                               // 0x5C5D0
        table[i] = id;
    }

**So the 32 mission-efficiency modifiers are created by the engine, not read out of a file**,
their keys are `<order save token>_eff`, and their ids are consecutive from whatever the
modifier count was when startup reached that function - which is why they are invisible to a
static scan of `modifierIds.json`.

`MissionIndexToOrderToken` is a jump table at `0x58471C`, 33 two-instruction cases, and it
gives the whole index→mission mapping both tables share:

```
 0 none                  1 support_attack        2 strategic_redeployment  3 move_order
 4 rebase                5 reserves              6 patrol                  7 intercept
 8 sortie                9 convoy_escort        10 convoy_raid            11 air_convoy_raid
12 transport            13 invasion             14 strategic_bomb         15 logistical_strike
16 runway_cratering     17 installation_strike  18 ground_attack          19 interdiction
20 air_intercept        21 carrier_protection   22 paradrop_mission       23 port_strike
24 naval_strike         25 rebase_to_carrier    26 nuke_mission           27 transport_supplies_mission
28 rebase_air           29 air_reserve          30 air_superiority        31 join_fleet
32 join_air
```

**Mod consequence: `convoy_escort_eff` and `convoy_raid_eff` are real country modifier keys**
and the only mod-facing lever on that term. BlackICE defines neither - a grep of `common/`
for `*_eff` finds one unrelated event modifier - so the spotting difference between an escort
and a raider currently rests on the technology array at `CTechnologyStatus +0xE0` alone.

## Trade routes

**A trade route is a `CRelation`, not a convoy.** `CTradeRoute` (vftable `0x15FBD48`, 12
slots, base `CRelation`, RTTI) lives on the pair's `CDiplomacyStatus` as the list at
**`+0x60` with its count at `+0x68`** - which is what the game's own Lua
`CDiplomacyStatus:GetTradeRoutes()` hands out. A country also has a `CArray<CTradeRoute*>`
(the luabind registration for `CCountry::GetTradeRoutes`), whose offset was not found.
`CCountry +0xE28` is the per-country `CDiplomacyStatus*` array, indexed by the other
country's id.

Its loader (`0x64CBA0`) accepts exactly five keys - `from`, `to`, `convoy`, `trade_from`,
`trade_to` - and the base `CRelation` adds `first`, `second` and `start_date`, which a real
savegame's block carries:

```
trade={ to="POL" from="HON"
        trade_from={ 0.000 0.000 0.000 0.000 0.000 0.000 0.559 }
        trade_to  ={ 0.000 0.000 0.635 0.000 0.000 0.000 0.000 }
        first="HON" second="POL" start_date="1.1.1.0" }
```

`from` lands at `+0x24`/`+0x28` and `to` at `+0x2C`/`+0x30` (fieldmap, out of the loader).
The two goods blocks are **not placed with any confidence**: the constructor zeroes two
three-dword groups at `+0x34` and `+0x44`, which is the shape of a vector header rather than
of seven values, and the loader's handlers pass their destination in a register so fieldmap
records nothing. The constructor also leaves `+0x40` and `+0x50` unaccounted for. Said plainly
so nobody builds on it.

### How the goods move, and what breaks a route

`CCountry::RunDailyTradeRoutes` (rva `0xFEE70`), from the per-country daily pass. **A trade
convoy is skipped by both delivery sites** (`is_trade` is tested at `0x4DAB57` and
`0x678F7E`), so the trade transfer happens here instead. For every country in the database -
"REB" skipped - it takes the pair's status, skips a pair with no routes, and for each route:

- **no transports on the serving convoy → the route is off**, with the reason string
  `TRADE_INACTIVE_CONVOY`. Not reduced: off.
- **the seller has none of the good → off**, `TRADE_INACTIVE_NO_RES`.
- otherwise `CConvoy::GetEfficiency` (called at `0xFF380`) scales the amount, and three pools
  are credited: `TradedAway` (`CCountry +0x7DC`), `TradedFor` (`+0x86C`) and
  `TradedAwaySansAlliedSupply` (`+0x800`), with the roles swapped for the other direction.

So convoy efficiency is a straight multiplier on a trade, and sinking a trade route's
transports to zero cancels the trade rather than shrinking it. `CCountry::NeedConvoyToTradeWith`
(`0x103C60`, already in `CLASSES.md`) is what decides whether a route needs a convoy at all.

### Who drives a route - the AI, through the mod's Lua

`CCountry::RunHourlyAITrade` (rva `0xDC410`). Its only caller is `0x27B1A2` inside
`0x27B160`, the per-country body of `ProcessAITradeFunctor`, which `FINDINGS-tick.md` has
fanned out from `RunHourlyPass` at `0x6829DC`. So this is **once per country per hour, on a
TBB worker thread.** It draws `MT19937Next` (`0x6A2B90`) directly against the game state's
generator at `+0x124` - not through `Random` - and then

    if (draw % 6  == 0)  Lua ProposeTrades(country->ai (+0x1D8), country->tag (+0xCA4))
    else if (draw % 10 == 0)  Lua EvalutateExistingTrades(country->ai, country->tag)

through the bridge at `0x110280` (name in EAX, result buffer in ESI). **Both names are
BlackICE's own, in `script/ai_trade.lua`** - including the engine's own misspelling of
`EvalutateExistingTrades`, which the mod therefore has to keep. So **the AI's trade decisions
are entirely the mod's**, and a Lua error in `ai_trade.lua` silently stops the AI trading.

It also means the engine itself calls Lua from a TBB worker thread, which is worth knowing
before BiceLib hooks anything in `ai_trade.lua`'s call chain.

### The separate diplomacy question

`FINDINGS-diplomacy.md` asks how `CTradeAction` reaches `DiploScore_OfferTrade`. **Not
answered**, and this is as far as it got: `CTradeAction`'s luabind registrations include
`const CTradeRoute& GetTradeRoute() const`, `void SetTradeRoute(CTradeRoute&)`,
`CFixedPoint Get(GoodsCategory) const`, `void Set(GoodsCategory, CFixedPoint)` and a static
`CTradeAction* create(CCountryTag, CCountryTag)`; and **`CEU3AI` has two registered methods
taking a `CTradeRoute&` and returning `bool`**, one const and one not (the mangled names at
`0x15F02C8` and `0x15F02E8`). Those are the shape of the untraced route - the AI is handed a
route object and asked a yes/no - but the wrapper at `0xA44Cxx` was not followed to its
caller. The hourly driver above is a *different* path and does not go through slot 17.

## What was not established

- **Where a lend-lease convoy's load actually moves.** `CConvoy::RunDelivery` refuses one
  outright and both delivery sites hand it one. The lend-lease vectors at `CCountry +0x6B8`,
  `+0x6C8`, `+0x6D8` are the obvious next place.
- **`CConvoy +0xA4` and `+0xA8`.** The raid passes both to `0x463EC0` together with the
  convoy's `daily` pool and the raider's tag, which is the strategic-warfare cargo statistic
  (`linechart_our_convoy_cargo`). Not named here.
- **`CDiplomacyStatus +0x24`**, the object that lets a raid happen between countries that are
  not at war, and `0x763A0`, the check applied to it against the province's `+0x358` list.
- **Which of `0x1ADE80`'s `+0x88` and `+0xA8`** is the `convoy` definition and which the
  `escort`.
- **`CTradeRoute`'s `trade_from` / `trade_to` layout**, and where `CCountry` keeps its own
  `CArray<CTradeRoute*>`.
- **The body of the dummy naval combat** the raid fights between building the throwaway
  `CNavy` and calling `LoseShips` - `0x5D2230..0x5D2560` - including whether the raider can
  take losses itself.
- **`CCountry +0x580`**, set to 1 by `0xE6EE0` right before it repaths every convoy the
  country owns.
- **`0x4F4E80`**, which `LoseShips` hands the threat figure to; named only by its argument.

## The defines, and which ones the engine never reads

Everything convoy-shaped in `defines.lua`, with the one reader found for each. All in the
`economy` block (`CDefines +0x9C`) unless said otherwise.

| define | block offset | BlackICE | what reads it |
| --- | --- | --- | --- |
| `CONVOY_BUILD_COST` | `+0x14` | 3 | `CCountry::GetConvoyBuildCost` `0xFD590` |
| `CONVOY_BUILD_TIME` | `+0x18` | 40 | `0xFD600` |
| `ESCORT_BUILD_COST` | `+0x1C` | 3 | `0xFD670` |
| `ESCORT_BUILD_TIME` | `+0x20` | 90 | `0xFD6E0` |
| `THREAT_FROM_CONVOYS_MODIFIER` | `+0x30` | 0.1 | `CConvoy::LoseShips` `0xC5940` - threat per ship sunk |
| `CONVOY_CONSTRUCTION_SIZE` | `+0x34` | 10 | **not read here**; construction, not traced |
| `MAX_DAILY_TRADE` | `+0x38` | 100 | **not found** - no reader identified |
| `CONVOY_PATH_LENGTH_MULT` | `+0x3C` | 0.33 | `GetDesiredTransports` `0xC7320`, sole reader |
| `CONVOY_TRADE_WEIGHT_MULT` | `+0x40` | 0.2 | `GetDesiredTransports`, trade routes only |
| `LL_CONVOY_EFF_IMPACT` | `+0x4C` | 0.5 | `CConvoy::LoseShips` |
| `LL_CONVOY_EFF_REGAIN` | `+0x50` | 0.02 | the daily pass, `0x4DABB9` |
| `SUPPLYPOOL_DAYS` | military `+0x3C` | 35 | `AreaSupplyAndFuelHeadroom` `0xDD4D0`, and the land supply pass |
| `NAVAL_BASE_EFFICIENCY` | military `+0x274` | | `NavalBaseCapacity` `0xA75D0` |
| `STRAT_CONVOY_DAMAGE` | military `+0x14C` | -0.5 | `ResolveConvoyRaid`, divided by the victim's convoy count |
| `EXP_GAIN_CONVOY_MODIFIER` | military `+0x58` | 0.1 | not read on any path followed here |
| `NAVAL_INTERCEPTION_AFTER_ATTACK_FACTOR` | military `+0x270` | | `ShouldStartNavalCombat`, against `last_convoy_attack` |

**`MAX_DAILY_TRADE` has no reader this found**, which is the kind of negative worth recording
- but trap 8 says a `GetDefines` negative is not evidence, and the three ways a define hides
all apply, so treat it as unconfirmed rather than dead.

**What is *not* a define, and so cannot be tuned:** 5.0 defence per escort; the whole escort
demand curve (`/2 + 1`, `+3`, `+4`, and the 5/3/1 recency bonus); the `% 50` detection roll;
the 5.0 air-raid attack multiplier; the 0.2 per path province that scales how many ships a
raid exposes; the per-100 strength and organisation divisors in the raider's attack; the
1000.000 reserve a puppet keeps; and the `/10` on the beaten-raid statistic.
