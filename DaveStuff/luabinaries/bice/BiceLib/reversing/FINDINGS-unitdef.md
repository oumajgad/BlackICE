# What a division's stats are made of

`CUnit +0xC8` is not a pointer into the definition database. It is a `CSubUnitDefinition` the
unit **owns**, `0x228` bytes, allocated by `CUnit::CUnit` (rva `0x1B5010`) at `0x1B5348` and
constructed at `0x1B5396` with the key string `---`. Nothing else in the image writes
`CUnit +0xC8`. It is rebuilt from the unit's brigades by **`CUnit::RebuildDefinition`
(rva `0x1B5ED0`)**, and everything the game knows about "what this division is" comes out of
that one function.

Addresses are **RVAs** unless written otherwise; image base `0x400000`. Read statically; **no
running game was used**, so where a conclusion rests on a scale rather than an instruction it
says so.

## The headline: the aggregation looks naive and is not

`CSubUnitDefinition::Add` (rva `0x1A7FC0`) is a flat sum of 59 fields. But
`CUnit::RebuildDefinition` then **undoes four of them** with a min or a max, writes a fifth as
a mean, and finally calls **`CSubUnitDefinition::Divide` (rva `0x1A83B0`)**, which averages
organisation, morale, softness and every `CUnitAdjuster`. Every field whose summed form would
be nonsense is fixed before any reader sees it, and a census of the readers found **none** where
the value is wrong for the use.

So there are three rules, not one:

| rule | fields |
| --- | --- |
| **sum** | `max_strength`, `combat_width`, `soft_attack`, `hard_attack`, `air_attack`, `suppression`, `defensiveness`, `toughness`, `officers`, `supply_consumption`, `fuel_consumption`, `transport_weight`, `transport_capability`, `hull`, `strategic_attack`, `carrier_size`, `distance`, every naval attack and defence, `surface_detection`, `air_detection`, `sub_detection`, `visibility`, `radio_strength`, `positioning`, `amphibious_invasion_defence`, `build_cost_ic`, `build_cost_manpower`, `build_time` |
| **cap — min or max of one brigade** | `maximum_speed` (min), `range` (min), `armor_value` (max), `ap_attack` (max) |
| **mean** | `default_organisation`, `default_morale`, `softness`, `amphibious_invasion_speed`, and every adjuster: `night`, `fort`, `river`, `amphibious`, the terrain blocks |

Verified at the instruction level: `0x1B603D`-`0x1B60EA` holds the four fixups (`jl` plus a
zero guard for the two mins, `jle` for the two maxes), and `Divide` writes exactly `+0xF0`,
`+0xF4`, `+0x124` and five calls to `CUnitAdjuster::Divide`.

## The rebuild, in order

`void __stdcall CUnit::RebuildDefinition(CUnit* unit@stack:4, bool keepStrength@stack:8)`,
`0x1B5ED0..0x1B623C`, `ret 8`. The second argument is forwarded to
`CSubUnit::ApplyTechnologies` and used nowhere else.

1. Make `g_CSubUnitDataBase` (VA `0x1A886F0`) if it is null. **The `operator new(0xC0)` at
   `0x1B5F02` is that database, not the definition** — it is guarded by
   `cmp dword ptr [0x1A886F0], 0` three instructions in.
2. Zero `CUnit +0x1D0`, a vector of one int per entry of the database's definition vector.
3. **Reset the definition** by `StringHashFind` on the key `---` and
   `CSubUnitDefinition::Assign` from the hit. The database holds a `---` entry whose vftable the
   loader overwrites with `CNullSubUnitDefinition`'s, so the reset is a copy of an all-zero
   definition — a zero dressed as a copy. It is the only thing that clears the accumulators.
4. Per brigade over `regiments` (`+0x38`): `CSubUnit::ApplyTechnologies` first, so the brigade's
   own `+0x58` definition is itself rebuilt from its template plus its technology levels; then
   either `Add` of all 59 fields or the reduced path; then the four min/max fixups; then
   accumulate `amphibious_invasion_speed` and its count; then mark
   `CUnit +0x1D0[definition->unit_group]`.
5. After the loop: total `CUnit +0x1CC base_ca_bonus`, write the mean
   `amphibious_invasion_speed`, and `Divide(definition, regiments_count * 1000)`.

## What makes a brigade stop contributing

`0x1B5FEC` calls `CUnit` slot 15 — `IsLand`, true only for `CArmy`. So the reduced path is
**land only**; a ship or a wing always contributes all 59 fields. For a land unit:

```
if (unit->IsLand()
    && brigade->definition->combat_width <= 0          // 0x1B5FF5
    && (brigade->strength     < 100                    // 0x1B6003, g_IneffectiveStrength
     || brigade->organisation < 1000))                 // 0x1B600E, g_IneffectiveOrganisation
    definition->softness += brigade->definition->softness;
else
    Add(definition, brigade->definition);
```

**The type test comes first and does the most work.** `combat_width <= 0` is what a *support*
brigade has — an HQ, signals, engineer or anti-air attachment that takes no frontage. A
fighting brigade has positive `combat_width` and can **never** fall onto the reduced path,
however beaten up it is. For a zero-width brigade, dropping below *either* threshold stops it
contributing.

Both thresholds are hardcoded literals, not defines. `g_IneffectiveStrength` (VA `0x1A886CC`)
is written once, by the startup initialiser at VA `0xCC3690`, which truncates the float `100.5`
at VA `0x160A684` — `(int)floor(100.5f)` = **100**. `g_IneffectiveOrganisation`
(VA `0x170D7A0`) has **no writer anywhere in `.text`**; its four bytes in the file are
`e8 03 00 00` = **1000**. That same `100.5` literal also feeds the revolt-risk daily step
global, so it is a shared constant and must not be named after either domain.

### The denominator does not shrink

`Divide` divides by `regiments_count`, which counts the reduced-path brigades too, and the
reduced path contributes nothing to `default_organisation` or `default_morale`. **So a
knocked-out support brigade pulls its division's maximum organisation and morale down by
(N−1)/N while contributing nothing**, and keeps doing so until it is repaired or detached. It
still contributes its `softness`, which is why that is the one field the reduced path adds — the
division's soft/hard proportion stays honest.

## Two things that look like bugs

**`toughness` is added twice.** `0x1A803E`/`0x1A8044` reads and adds `+0x120`, and
`0x1A80AA`/`0x1A80B0` does it again. The encodings are byte-identical at both
(`8b 81 20 01 00 00 01 86 20 01 00 00`, confirmed), and those are the only two sites touching
`+0x120` in the function. So every brigade contributes **twice** its `toughness` to its
division, and every technology level applies twice to a sub unit's own. `+0x104`
`repair_cost_multiplier` is the only field of the `+0xE8..+0x194` block the function never
touches, and the duplicate sits where it would have fallen in the ordering — so the likeliest
reading is a copy-paste that replaced it. Either way: **`toughness` is double-weighted and
`repair_cost_multiplier` is dead at both levels.**

**The `sprite` copy is unreachable.** `0x1A8372..0x1A8399` is
`if (src->priority > dst->priority) { dst->priority = src->priority; dst->sprite = src->sprite; }`
— a max with a string carried along, which is how you would pick "the picture of the most
important brigade". But `priority` was already *added* into the destination 0x142 bytes earlier,
at `0x1A8230`, so for non-negative priorities the comparison can never pass. A division's
definition keeps the empty `sprite` the null definition gave it.

## When the rebuild runs

Eight direct callers, none indirect (the function is in no vftable slot): `CUnit::UpdateHourly`
(`0x1BA2D6`), `AddRegimentToUnit` (`0x1BE937`), `RemoveRegimentFromUnit` (`0x1BEB3B`),
`CUnit::AfterLoad` (`0x1B813D`, the only one passing `true`), `CDistributeUpgrade::Distribute`
(`0x11D52B`), `0x10333E`, `0x1CDFD0`, and a GUI object at `0x3627AF`.

**The hourly one is not a refresh.** `CUnit::UpdateHourly` recomputes the effectiveness
predicate for a land unit's zero-width brigades, caches each answer in `CSubUnit +0xD4`, and
calls the rebuild only *if one of them changed*. Nothing else is on a clock.

So a division's stats refresh **on attach, on detach, on upgrade, on load, and on the hour a
support brigade crosses one of the two thresholds — nothing else.** In particular nothing
rebuilds on a strength change in combat, and that is correct: the aggregated fields are
definition figures, not current ones, and current strength is read off the sub units. **A stat
read mid-combat is not stale.** The only aggregated figure that moves with the fighting is the
organisation/morale mean, and that is refreshed on the hour a support brigade breaks.

One inconsistency: `UpdateHourly` tests `combat_width != 0` where `RebuildDefinition` tests
`<= 0`. A brigade with a negative `combat_width` would be classified differently by the two, so
its contribution could change without triggering a rebuild. No mod declares a negative
`combat_width`, so this is a curiosity.

## Corrections to the existing record

1. **`CUnit +0xC8`** is recorded as `CSubUnitDefinitionPtr`, "sub unit definition". It is owned,
   synthesised and unshared — the name understates it and invites exactly the misreading that
   it points into the definition database.
2. **`ShouldStartNavalCombat` does not read `CUnit +0xC8`.** `FINDINGS-navaldetection.md` has
   its `surface_detection`, `sub_detection` and `visibility` coming off the unit's definition;
   they are read off **`CSubUnit +0x58`**, the real per-ship definition, inside a loop over both
   sides' sub units (`0x31DB2`, `0x31DC6`, `0x31E1B`, `0x31E24`). So naval spotting is per ship
   and the aggregation never enters it.
3. **`CSubUnitDefinition +0x198` is a `Hoi3CString`, not an int** — `Add` assigns it with
   `std::string::assign` at `0x1A8399`, and `unit_group` sits 0x1C further on at `+0x1B4`.
   `CLASSES.md` has it as `int sprite`.
4. **`+0x180`**: `project.json` says `sub_unit_amount`; `LoadKey` and the supply code both say
   `radio_strength`. Not re-derived here beyond noting the disagreement.
5. **`unit_group` (`+0x1B4`) is a sub unit type index**, not an index into
   `combined_arms.txt`'s order — proved by `g_CSubUnitDataBase->begin[unit_group]` at `0x1B610F`.

## What this means for the mod

- **A summed stat scales with division size.** Adding a brigade adds its whole figure.
- **A capped stat is a per-division limit.** `maximum_speed` and `range` are the **worst**
  brigade's; `armor_value` and `ap_attack` are the **best** brigade's. So one slow brigade slows
  the whole division, and a single well-armoured brigade gives the whole division its armour
  value. That second one is the lever a unit designer will care about most.
- **Organisation, morale, softness and every terrain/night/river/fort/amphibious modifier are
  means.** Diluting a division with a brigade that has a poor modifier in some terrain really
  does dilute it, and a brigade with no entry for that terrain contributes a zero to the mean —
  worse than not being there.
- **`toughness` counts double**, so any balance figure derived from it is worth half what the
  arithmetic suggests at division level.
- **`repair_cost_multiplier` does nothing**, at either level.
- **A broken support brigade costs organisation and morale** rather than merely contributing
  nothing. Repairing or detaching an HQ or signals brigade at zero organisation measurably
  helps the division, and the effect lands on the hour.
- **`amphibious_invasion_defence` grows with division size** while `amphibious_invasion_speed`
  does not.

## What is not established

- The scale of `CSubUnit::strength` and `::organisation` is inferred from the build-cost floor
  sharing the `100.5` literal, not read off a live object or a save. The conclusion
  ("effectively destroyed or routed") holds either way, but a tooltip figure would differ.
- `CSubUnitDefinition +0x28`, where a combined arms group's bonus lives: the constructor puts
  the token `none` in it, `LoadKey` never writes it, and the combined-arms total is its only
  reader. What fills it is unknown.
- `CUnit +0x1F8`, the gate on `CArmy::GetAttackValue`/`GetDefenceValue` (`>= 7`) and on the
  renaming in `AddRegimentToUnit`/`RemoveRegimentFromUnit` (`>= 3`). It is not `oob_level`
  (`+0x1F4`).
- `CArmy +0x300`, on which two amphibious findings depend: `amphibious_invasion_defence`'s
  readers reach it through `AsArmy()->[+0x300]->+0xC8`, and `extra_amphibious_defence`
  (`+0x200`, looked up through a container at `+0x218`) is never aggregated, so on a unit's own
  definition that lookup can only miss.
- `0x102BC0` and `0x362780`, two of the eight callers, were read only at the call site.
- Nothing was checked against a running game or a savegame.
