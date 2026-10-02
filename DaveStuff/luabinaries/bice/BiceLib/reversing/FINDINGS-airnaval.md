# Air and naval missions

How an air or naval combat starts, what decides its kind, how long it lasts, and what the
losses on a naval row actually count. Read statically off `hoi3_tfh.exe`; nothing here was
watched in a running game, and the two places that matters are called out.

Addresses are **virtual** unless written `rva`. Image base `0x400000`.

## The two results worth most

### The combat-history hook does fire for air and naval

This closes the open question at `FINDINGS-combat.md` line 372.

`CCombatManager::Tick` (rva `0x2FB70`) has **one caller, `0x00682A90`, inside `RunHourlyPass`
itself** - not inside any of the TBB functors. So combat resolution *and* combat recording run
once a game hour on the tick thread, which is the thread that owns the Lua state and the D3D
device. They are hookable with the ordinary rules.

The loop snapshots every live combat off `manager + 0x08` into a stack array first, then per
combat:

    if (!c->byte[0x29]) c->slot13()
    if (c->slot15(param) == 1) CCombat::Finish(c, manager)

Slot 15 is Tick and returns 1 exactly when the combat is over. `CCombat::Finish` (rva
`0x31730`) falls into the tail at rva `0x31620`, which unlinks the combat, raises the UI
notification when `combat + 0x0C` is set, calls `CCombatHistory::RecordCombat(manager + 0x18,
combat)` and deletes it.

**No step on that path tests the kind of combat.** Land, naval, air and all three bombings are
recorded by the same code.

The second `RecordCombat` caller (`0x1D2904`) writes `gameState + 0xB74` - the same history
list - which places **the one `CCombatManager` at `CCurrentGameState + 0xB5C`**. That is static
reasoning from two call sites, not a live read.

### `CCombatant + 0x84` is not the same scale for ships as for planes

`CCombatant::ApplyLosses` (rva `0x165FD0`, `this` in **EDI**) opens by calling
`this->+0x3C->slot11()` for the combat's kind and branching on it:

| kind | what `+0x84` accumulates |
| --- | --- |
| 1 land, 3 air, 4/5 ground and land bombing | `CUnit::SettleCombatDamage` summed per regiment - **the same currency as land brigades** |
| 2 naval, 6 | a flat `0x3E8` per **sunk ship**, at `0x0056627C` |

So on a naval row `+0x84` is a **ship count in thousandths** - 3000 means three ships - and on
an air row it is strength, directly comparable with land. Reading a naval row as strength is
wrong by orders of magnitude. `CCombatant + 0x88` is the same figure broken down by
`CSubUnitDefinition::type_index`, and the naval branch adds its flat `0x3E8` to both at once
(`0x00566275` and `0x0056627C`).

Anything that presents combat losses - a Combat Reports page included - has to branch on the
kind before it formats `+0x84`.

## What starts an air combat

`CCombatManager::CheckForCombat` (rva `0x30960`, ~34 callers, all of them "this unit's
situation changed") is where every combat in the game starts. Two exits:
`CCombatManager::StartCombat` for the ordinary case, and `CCombatManager::StartBombing` for a
bombing, reached only when `unit->slot17()` (`CUnit::IsAir`) **and**
`unit->order->slot17(province)` are both true.

`CCombatManager::StartCombat` then filters each unit standing in the province through
`CUnit::CanEngage` (rva `0x1C01F0`, `this` in **EDI**, `ret 0xC`), which calls
`order->slot34()` and `order->slot25()` **on each side in turn**:

- **slot 34** - "this order will fight an air-to-air combat". The base returns false; only
  `CAirInterceptOrder` and `CAirPatrol` flip it to the shared `mov al,1` stub.
  `CCarrierProtection` computes it: average organisation (slot 20) must reach
  **`CAG_DUTY_MINIMUM_ORG_LIMIT`** (defines `military + 0xEC`) and the order's province must
  have `+0x2F4 > 0`.
- **slot 25** - `CAirOrder::IsFitToFly` (rva `0x18A090`). The base and every naval order return
  false; **this one body is shared by all 19 `CAirOrder` subclasses.** It returns false before
  `+0x28` (`start_date`), then tests strength% and organisation% in thousandths against a limit
  the order's `stance` (`COrder + 0x20`) selects: stance 0 `AGGRESSIVE_*`, stance 2 `PASSIVE_*`,
  otherwise `DEFENSIVE_*` (`military +0xD4/+0xD8/+0xDC` for organisation, `+0xE0/+0xE4/+0xE8`
  for strength).

**Since `stance` reads 1 on every order in a live game, the `DEFENSIVE_STRENGTH_LIMIT` /
`DEFENSIVE_ORGANISATION_LIMIT` pair is what actually gates every wing.** The other four
defines are reachable but unused in practice. That is the mod-facing consequence of this
section.

**The kind is decided by the defender**, not by the attacker's mission.

`CCombatManager::CreateCombat`'s jump table at `0x31604` confirms the numbering from the
construction side, independently of the slot-11 constants `FINDINGS-combat.md` read it from:
1 land, 2 naval, 3 air, 4 ground bombing, 5 land bombing, 6 naval bombing.

## An air combat lasts four hours

`CAirCombat::Tick` (rva `0x17BC50`) calls `CCombat::Tick` (rva `0x16EBE0`) first and returns
early if the base says the combat is over; otherwise it ends `return this->+0x20 >= 4`.
`CCombat + 0x20` is an hour count - `CNavalCombat::Tick` uses the same field multiplied by 1000
as the growing term of its per-tick disengage chance - and the manager ticks hourly, so **an
air combat runs at most four hours unless the base tick ends it sooner.**

## Bombing

`COrder::ShouldBombProvince` (rva `0x18BEF0`) is slot 17 and is, in full,
`return province == this->+0x68`. It appears in **exactly six** vftables, all bombing missions:
`CStrategicBombOrder`, `CBombLogisiticsOrder`, `CBombRunwayOrder`, `CBombInstallationOrder`,
`CNavalStrikeOrder`, `CPortStrikeOrder`. The base returns false, and
`CAirInterdictionOrder`, `CGroundAttackOrder` and `CCarrierProtection` have their own bodies.

So a bombing combat starts in `CAirOrder + 0x68` and no other province, and **`CAirPatrol` and
`CAirInterceptOrder` never bomb.**

## `CAirInterceptOrder`, read out

- **slot 11** `CanReachTarget` (rva `0x18EB60`) - eight instructions, defers entirely to
  `CUnit` slot 34. Shared with `CAirPatrol`.
- **slot 14** `IsStillValid` (rva `0x18ECE0`) - returns "order dead" when the unit has no base
  at `+0x98`; otherwise runs `UpdateMission`, and if `COrder::IsTargetInRange` fails it orders
  a return to base, clears `+0x68` and keeps the order alive; on success it tail-jumps to
  `CAirOrder`'s slot 14.
- **slot 15** `BuildDescription` (rva `0x18ED30`) - **interface text, not simulation.** It
  composes `INTERCEPT_SHORT_DESC`, or `STRAT_BOMB_RETURNING` when `return_to_base` is set.
  `COrder` leaves slot 15 pure virtual, so every concrete order has one; worth knowing before
  reading any order's slot 15 as behaviour.
- `UpdateMission` (rva `0x18FEB0`) needs `unit->+0x140` (provinces left to move) and `+0x11C`
  (combats) both at or below zero, and **compares the current tick `gameState + 0xBDC` against
  `this->+0x2C`, the order's `death_date`, sending the wing home once it is past.** So
  `death_date` is the mission's expiry, not merely a save field.

`COrder::IsTargetInRange` (rva `0x1CE0A0`, `this` in **EAX**) short-circuits to true for the
three rebase orders and for any unit with no base; otherwise it takes the range from
`unit->+0xC8->+0x148` (the `CSubUnitDefinition`) and the origin from the base province.

## The order type ids are save tokens

`CLASSES.md` records these as unexplained constants. They are the save tokens, so a mod's own
files name them:

| id | token |
| --- | --- |
| `0x18D` | `none` |
| `0x573` | `rebase_to_carrier` |
| `0x574` | `rebase_air` |
| `0x6DE` | `rebase` |
| `0x6E9` | `convoy_raid` |
| `0x6FA` | `air_superiority` |
| `0x718` | `air_intercept` |

`CreateOrder` (rva `0x183AA0`) is the factory: one binary-search switch on the token with a
case per concrete class. `CUnit::SetOrder` (rva `0x1CD9E0`, `this` in **EAX**) parks a fresh
`CreateOrder(0x18D, 0)` in `+0xB0` while it deletes the old order, so **`CUnit + 0xB0` is
briefly a throwaway `CNullOrder` in the middle of that function** - a hook reading the order
there can see it.

## Threads, for hooking

- `CCombatManager::Tick` and everything under it - **tick thread**, hookable.
- `CUnit::UpdateHourly` (rva `0x1B9C50`) is the per-unit leaf of `ProcessUnitFunctor`, so it
  runs on a **TBB worker thread**. Nothing hooked there may touch Lua or the ImGui frame. It
  does movement, per-regiment organisation regain, an owner test against the literal `"REB"`
  and the retreat flag; it does **not** read `CUnit + 0xB0` and never dispatches slot 31.
- `CUnit::CheckOrderAndCombat` (rva `0x1BA2F0`) is slot 31, shared by `CUnit`/`CArmy`/`CAir`
  (`CNavy` overrides at rva `0x1CFDD0`). It is **the only simulation driver of `COrder` slot 14**
  found: it calls `order->slot14()` and replaces the order with a fresh `CNullOrder` when it
  returns false. **How often it runs, and on which thread, is not established** - it is called
  by neither `CUnit::UpdateHourly` nor `CUnit::UpdateDaily`.

## Contradicts the existing record

`FINDINGS-combat.md`'s section "The modifier list is land only" argues that air and naval never
reach the base combat tick. **They do.** `CAirCombat::Tick` makes no vtable call at all - its
first act is a direct `call` to `CCombat::Tick` - and `CNavalCombat::Tick` opens the same way.
The live watchpoint result that section rests on (`CUnit + 0xDC` never filled for ships or
wings) still stands; the reasoning offered for it does not.

## What is not established

- **The cadence and thread of `CUnit` slot 31.** This is the gap that matters most: it decides
  whether `COrder` slot 14 is hookable at all.
- **The body of `ShouldStartNavalCombat` (rva `0x31840`)** - ~0x800 bytes over `CNavy + 0x370`
  and `+0x374`, a flag at `+0x31`, and defines at `0x01A86F90` and `0x01A8702C`. **This is
  where fleet detection and positioning live**, and none of it is read. Its entry conditions
  are: bails when the other unit's `+0x40 < 1`, when our navy's `+0x2F8 > 0`, or when our order
  is `convoy_raid`. The call site does `cmp al, 1`, so it returns a code and not a bool.
- Which defines `0x01A87058`, `0x01A86FFC`, `0x01A86F90` and `0x01A8702C` are.
- `CAirOrder` slots 35-39.
- The class of `CUnit + 0x98`, the home-base object. Its slot 0 returns a `CMapProvince*`.
- Nothing here crossed the combat-modifier push, so the land-only modifier question is
  untouched either way.
