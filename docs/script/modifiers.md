# Script modifiers

<!-- The keyword lists come from CTrigger::LoadKey and CEffect::LoadKey, read out of
     the game itself. reversing/findings/FINDINGS-script.md in the reversing folder has the save token
     and implementing class of every one. -->

The named values a modifier block can change, grouped as the old notes
grouped them. Most run from `-1.0` to `1.0`, where `0.2` means +20%.

**The game has a fixed list of modifier keys: 142 of them.** The fact base read it out of the
game as `CModifierValues` in `ghidra/project.json` (`hoi3-reversing`):
- 107 kinds such as `global_ic`;
- 32 mission efficiencies, each written as its order's name, such as `convoy_raid`;
- `suseptibility_axis`, `suseptibility_allies` and `suseptibility_comintern`.

A modifier block takes these and nothing else: event, static and triggered modifiers, laws,
ministers, ideologies, governments, occupation policies, strategic resources. Any other key
is dropped without a word. The BICE Validator checks every such block against the list
(`tools/BiceValidator/bicevalidator/schemas/modifier_names.json`).

This page is a guide to what the mod uses, grouped as the old notes grouped it, and not the
whole list. Two of its sections are not modifier keys at all - **Technology** and
**Unit leaders** list a technology's and a trait's own keys - and say so below.

## Events, ministers, leaders and laws

| Modifier | Note |
| --- | --- |
| `ruling_party_support` |  |
| `peace_consumer_goods_demand` |  |
| `global_manpower_modifier` |  |
| `global_leadership_modifier` |  |
| `dissent` |  |
| `drift_speed` |  |
| `global_ic` |  |
| `global_money` |  |
| `unit_recruitment_time` |  |
| `war_consumer_goods_demand` |  |
| `espionage_bonus` |  |
| `counter_intelligence` |  |
| `national_unity` | overall NU impact |
| `national_unity_effect` | modifies NU gain/loss from events |
| `global_resources` |  |
| `industrial_efficiency` |  |
| `unit_start_experience` |  |
| `global_revolt_risk` |  |
| `global_leadership` |  |
| `max_war_exhaustion` |  |
| `war_exhaustion` | this is not monthly, it only applies the value as an offset. War exhaustion gets added to neutrality after a war ends. |
| `threat_resistance` | lowers the threat generated against your country |
| `sw_national_unity_effect` | modifies gain/loss from strategic warfare |
| `air_intercept` | plus any other mission type |
| `ground_attack` |  |
| `interdiction` |  |
| `logistical_strike` |  |
| `installation_strike` |  |
| `runway_cratering` |  |
| `carrier_protection` |  |
| `strategic_bomb` |  |
| `paradrop_mission` |  |
| `combat_movement_speed` |  |
| `org_regain` |  |
| `soft_attack` |  |
| `hard_attack` |  |
| `convoy_raid` |  |
| `supply_throughput` |  |
| `leader_defence` |  |
| `land_build_speed` |  |
| `tank_build_speed` |  |
| `territorial_pride` |  |
| `port_strike` |  |
| `naval_strike` |  |
| `neutrality_change` |  |
| `supply_consumption` |  |

## Laws

| Modifier | Note |
| --- | --- |
| `partisan_efficiency` |  |
| `reserves_penalty_size` |  |
| `peacetime_manpower_rotation` |  |
| `officer_recruitment` |  |
| `reinforcement_bonus` |  |
| `unit_repair` |  |
| `research_efficiency` |  |

## Ministers

| Modifier | Note |
| --- | --- |
| `suseptibility_comintern` |  |
| `threat_impact` |  |
| `suseptibility_axis` |  |
| `peace_offmap_intel` |  |
| `suseptibility_allies` |  |
| `decay` | decay = { chemical_engineering = -0.25 }. A minister type's own key, not a modifier key: it works in `common/minister_types.txt` and nowhere else |
| `global_supplies` |  |
| `offmap_land_intel` |  |
| `offmap_political_intel` |  |
| `offmap_naval_intel` |  |
| `offmap_industry_intel` |  |
| `attack_reinforce_chance` |  |
| `defend_reinforce_chance` |  |
| `naval_base_efficiency` |  |
| `land_organisation` |  |
| `naval_organisation` |  |
| `air_organisation` |  |
| `suseptibility` |  |

## Provinces

| Modifier | Note |
| --- | --- |
| `local_partisan_support` |  |
| `local_manpower_modifier` |  |
| `local_leadership_modifier` |  |
| `local_ic` |  |
| `local_resources` |  |
| `local_revolt_risk` |  |
| `attrition` |  |
| `minimum_revolt_risk` |  |

## Strategic Resources

| Modifier | Note |
| --- | --- |
| `air_build_speed` |  |
| `amm_movement_speed` |  |
| `nuke_research` |  |
| `winter_effects` | reduces attrition/combat penalty from low temperature |
| `jungle_effects` | reduces attrition/combat penalty from high temperature in humid terrain (not necessarely jungle, but very likely) |
| `rocket_build_speed` |  |
| `casualty_trickleback` |  |
| `naval_build_speed` |  |
| `fuel_conversion` |  |
| `tank_build_speed` |  |
| `land_build_speed` |  |

## Technology

**These are a technology's own keys, not modifier keys.** They work in a technology in
`technologies/`. In any modifier block they do nothing. Only `casualty_trickleback`,
`research_efficiency` and `supply_throughput` are on both lists. The mod has `repair_rate`,
`ic_efficiency` and `energy_to_oil_conversion` in modifier blocks, where they do nothing.

| Key | Note |
| --- | --- |
| `casualty_trickleback` |  |
| `maximum_attrition` |  |
| `manpower_gain` |  |
| `ic_modifier` |  |
| `ic_efficiency` |  |
| `energy_to_oil_conversion` |  |
| `ic_to_supplies` |  |
| `provincial_aa_efficiency` |  |
| `combat_efficiency` |  |
| `encryption` |  |
| `radar_efficiency` |  |
| `research_efficiency` |  |
| `decryption` |  |
| `refinery_efficiency` |  |
| `metal_production` |  |
| `rares_production` |  |
| `energy_production` |  |
| `leadership_gain` |  |
| `supply_transfer_cost` | supply tax |
| `supply_throughput` | supply throughput |
| `repair_rate` | for buildings |

## Unit leaders

**These are a leader trait's own keys, not modifier keys.** They work in `common/traits.txt`
and `common/gainable_traits.txt`. In any modifier block they do nothing. Only
`supply_consumption` is on both lists. A trait keeps at most 16 effects and drops the rest
without a word.

| Key | Note |
| --- | --- |
| `xp_gain` |  |
| `surprise_chance` |  |
| `supply_consumption` |  |
| `defence_modifier` |  |
| `offence_modifier` |  |
| `winter_attrition` |  |
| `river_attack` |  |
| `fort_attack` |  |
| `combined_arms_bonus` |  |
| `out_of_supply_modifier` |  |
| `submarine_attack` |  |
| `disengage_timer` |  |
| `spread_out` |  |
| `spotting_chance` |  |
| `defender_softness` |  |
| `strategic_attack` |  |
| `night_attack` |  |
| `naval_attack` |  |
| `tactical_attack` |  |
