# Script effects

<!-- The keyword lists come from CTrigger::LoadKey and CEffect::LoadKey, read out of
     the game itself. reversing/findings/FINDINGS-script.md in the reversing folder has the save token
     and implementing class of every one. -->

What an event or a decision can do. There are **91** of them and every
one is listed here.

The same rule as for triggers: an unrecognised key is **silently dropped** and the effect
quietly does nothing.

Entries marked **(unverified)** are keywords the engine accepts but this mod never uses.
Their description is inferred from the class the loader builds.

## Effects

| Keyword | What it does | Syntax | Uses in the mod |
| --- | --- | --- | --- |
| `add_ai_strategy` | **(from the disassembly, not tested)** Gives the current country an AI strategy. The block is a `CAIStrategy` - the effect's `Load` hands the whole block straight to one - so its keys are `air_perc` `antagonize` `area_theatre` `armor_bias` `befriend` `building_prov` `conquer_prov` `consolidate` `defend_prov` `initialized` `land_perc` `max_subunits` `military_access` `naval_perc` `personality` `protect` `rival` `static` `threat` `vassal` `war_with`. | `add_ai_strategy = { befriend = ENG }` |  |
| `add_casus_belli` | **(from the disassembly, not tested)** The mirror of `casus_belli`: same call with the two countries swapped, so the **named** country gets the war goal against the **current** one. Takes a tag, `this` or `FROM`. | `add_casus_belli = ENG` |  |
| `add_core` | Make a certain province a core of the current country. | `add_core = <province id>` | 575 |
| `add_country_modifier` | Add a country modifier with certain effects to the country. | `add_country_modifier = <name of modifier>` | 4460 |
| `add_division` | **(~unverified~ works, units spawn with no techs and full strength)** Adds a division. | `add_division = { name = <name> where = <province id> <brigade type> = <name> <brigade type> = <name> }` |  |
| `add_province_modifier` | Applies a named modifier to a province, optionally for a limited duration. | `add_province_modifier = ...` | 47 |
| `add_wargoal` | Adds a War Goal to the current country towards the target country. It won't start a new war, only works if there's already one in progress. | `add_wargoal = ...` | 28 |
| `any_controlled` | Any controlled province. | `any_controlled = ...` | 277 |
| `any_country` | Any available country. | `any_country = ...` | 4236 |
| `any_nearby_province` | **(from the disassembly, not tested)** A **province** scope, and two things make it easy to write one that does nothing: it visits only the provinces **the current province's controller controls** - the same list `any_controlled` walks - and `distance` is measured in **map coordinates**, not provinces, so a small number reaches nothing. | `<province> = { any_nearby_province = { distance = 200 limit = { ... } <effects> } }` |  |
| `any_neighbor_country` | Any country neighboring the current country. | `any_neighbor_country = ...` | 1 |
| `any_neighbor_province` | Any province neighboring the current province. | `any_neighbor_province = ...` | 116 |
| `any_owned` | Any owned province. | `any_owned = ...` | 130 |
| `capital` | Move the capital to a new province. | `capital = <province id>` | 67 |
| `casus_belli` | A casus belli against the target. As a trigger it tests for one; as an effect it grants one. Takes the type, e.g. `conquer`. | `casus_belli = ...` | 202 |
| `change_controller` | Change the controller of a province. | `change_controller = tag` | 178 |
| `change_manpower` | Increase/decrease the manpower available in a certain province. | `change_manpower = x  # (x = +-1..)` | 98 |
| `change_province_name` | Changes the name of the current province. | `change_province_name = <new name>` | 1 |
| `change_variable` | Increases or decreases the value of an existing variable. | `change_variable =  {` | 1540 |
| `clr_country_flag` | Removes the specified country flag. | `clr_country_flag = <name of flag>` | 9056 |
| `clr_global_flag` | Removes the specified global flag. | `clr_global_flag = <name of flag>` | 80 |
| `clr_province_flag` | Removes the specified province flag (need a province scope). | `clr_province_flag = <name of flag>` | 27 |
| `country_event` | Triggers the specified country event for the current country. | `country_event = <event id>` | 10315 |
| `coup_by` | Stages a coup in this country by the target. | `coup_by = ...` | 3 |
| `create_alliance` | Creates an alliance with the specified country. | `create_alliance = this / from / tag` | 15 |
| `create_revolt` | Creates a revolt of the specified size. | `create_revolt = x # (x = 1 / 2 / 3)` | 542 |
| `create_vassal` | Creates the given country as a vassal. | `create_vassal = ...` | 21 |
| `crude_oil` | Increase/decrease a province’s max production of crude oil. | `crude_oil = x` | 92 |
| `dissent` | Increase/decrease a country’s dissent value. | `dissent = x # (x = +-1..)` | 689 |
| `do_election` | Immediately triggers an election in the tag country, regardless of government type. | `do_election = tag` | 15 |
| `end_guarantee` | The current country will no longer guarantee the specified country. | `end_guarantee = tag` | 73 |
| `end_military_access` | Ends the military access between the specified country, tag1 and the current country, tag2. | `tag1 = { end_military_access = tag2 }` | 8 |
| `end_non_aggression_pact` | Ends a non-aggression pact between the current country and the specified country. | `end_non_aggression_pact = tag` | 17 |
| `end_war` | Ends any war between the specified country, tag1 and the current country, tag2. | `tag1 =  { end_war = tag2 }` | 87 |
| `energy` | Increase/decrease a province’s max production of energy. | `energy = x` | 2168 |
| `fixed_ai_strategy` | **(from the disassembly)** Not a strategy block at all: a plain `yes`/`no` that sets one byte on the country, `CCountry +0x4A1`. **Nothing in the game reads that byte** - the write is its only access in the whole executable - so the effect does nothing. | `fixed_ai_strategy = yes` |  |
| `form_government_in_exile` | Create a government in exile for the current country. | `form_government_in_exile = yes / no` | 11 |
| `fuel` | Increase or decrease a country's or province's fuel. Works as an effect only - as a *condition* it is silently ignored, see [triggers.md](triggers.md#keys-that-do-not-work). | `fuel = x` | 383 |
| `government` | Change the current type of government for the country. | `government = <government type> / THIS / FROM` | 340 |
| `guarantee` | The current country will guarantee the specified country. | `guarantee = tag` | 7 |
| `inherit` | Allow the current country to inherit the specified country. | `inherit = tag` | 33 |
| `join_faction` | Makes the current country a member of the specified faction. | `join_faction = axis / allies / comintern` | 107 |
| `kill_leader` | Kill the specified leader. | `kill_leader = <leader id>` | 2024 |
| `leadership` | Increase/decrease the leadership produced in a certain province. | `leadership = x  # (x = +-1..)` | 92 |
| `leave_alliance` | Remove the current country from an alliance with the specified country. | `leave_alliance = this / from / tag` | 39 |
| `leave_faction` | Remove the current country from the specified faction. | `leave_faction = axis / allies / comintern` | 39 |
| `load_oob` | Adds units (including their hierarchy) defined in txt file to the current country's OOB. | `load_oob = "destroyers_for_bases.txt"` | 4845 |
| `local_intel_boost` | Raises intelligence on the target for a time. | `local_intel_boost = ...` | 12 |
| `manpower` | Increase/decrease the amount of manpower a country has. | `manpower = x  #(x = +-0..1)` | 1907 |
| `metal` | Increase/decrease a province’s max production of metal. | `metal = x` | 2423 |
| `military_access` | Gives the specified country, tag1 military access to the current country, tag2. | `tag1 = { military_access = tag2 }` | 22 |
| `modify_spies` | **(does not work)** Meant to add spies to the current country's own presence in another. The engine never reads its block - the keyword is wired as a scalar and its value handler is a stub - so it runs with no target and an uninitialised count, showing *Add 587232376 spies to Null*. Five bytes fix that and the rest of the effect is correct, but it was tried and not kept: see reversing/findings/FINDINGS-script.md. | - |  |
| `money` | Increase/decrease the amount of money a country has. | `money = x  #( x = +-1..)` | 2226 |
| `national_unity` | Increase/decrease a country’s amount of national unity. | `national_unity = x  #(x = +-1..100)` | 382 |
| `neutrality` | Increase/decrease a country’s base neutrality value. | `neutrality = x # (x = +-1..100)` | 186 |
| `non_aggression_pact` | Creates a non-aggression pact between the current country and the specified country. | `non_aggression_pact = tag` | 62 |
| `officer_pool` | Adds to the country's officer pool. | `officer_pool = ...` | 639 |
| `organisation` | Increase/decrease the ruling party’s organisation. | `organisation = x #(x = +-1..)` | 347 |
| `popularity` | Increase/decrease the ruling party’s popularity. | `popularity = x # (x = +-1..)` | 361 |
| `practical` | **(~unverified~, works)** Changes practical knowledge. | `practical = ...` |  |
| `province_event` | Fires an event in the province scope, the province equivalent of `country_event`. | `province_event = ...` | 80 |
| `random` | Effects within the block has an x percents chance of taking effect. | `random = {` | 24 |
| `random_country` | Picks a random country. | `random_country = ...` | 87 |
| `random_empty_neighbor_province` | Picks a random empty province neighboring the current province. | `random_empty_neighbor_province = ...` |  |
| `random_list` | Effects within the block has an x percents chance of taking effect. (for example:) | `random_list = {` | 313 |
| `random_neighbor_province` | Picks a random province neighboring the current province. | `random_neighbor_province = ...` | 8 |
| `random_owned` | Picks a random province. | `random_owned = ...` | 806 |
| `rare_materials` | Increase/decrease a province’s max production of rare materials. | `rare_materials = x` | 2171 |
| `relation` | Increase/decrease the relations value between two countries by x. | `relation = { who = TAG/THIS value = x }` | 1989 |
| `release` | Allows the current country to release the specified country and thereby create a new independent nation. | `release = tag` | 72 |
| `release_vassal` | Allows the current country to release the specified country as a vassal. | `release_vassal = this / from / random / tag` | 78 |
| `remove_brigade` | Removes specified brigade from the map. | `remove_brigade = <name>` | 6894 |
| `remove_core` | The specified province will no longer be core province. | `remove_core = <province id>` | 125 |
| `remove_country_modifier` | Removes a certain country modifier from the current country. | `remove_country_modifier = <name of modifier>` | 637 |
| `remove_fow` | Fog of war. As a trigger it tests whether fog of war has been lifted; as an effect it lifts it. | `remove_fow = ...` |  |
| `remove_minister` | Removes the minister (id removes a certain minister, yes removes one at random, position removes the minister in a certain position; can't remove the head_of_state or head_of_government randomly). | `remove_minister = <minister id> / yes / <position>` | 143 |
| `remove_province_modifier` | Removes a named province modifier previously added with `add_province_modifier`. | `remove_province_modifier = ...` | 103 |
| `revolt_risk` | Revolt risk. As a trigger it tests the current value; as an effect it changes it. | `revolt_risk = ...` | 2 |
| `secede_province` | Cede a certain province to the specified country. | `<province id> = { secede_province = tag }` | 701 |
| `set_country_flag` | Sets a flag for the current country. | `set_country_flag = <name of flag>` | 8161 |
| `set_global_flag` | Sets a global flag regardless of country. | `set_global_flag = <name of flag>` | 198 |
| `set_province_flag` | Sets a province flag (need a province scope). | `set_province_flag = <name of flag>` | 167 |
| `set_variable` | Creates a new variable and assigns it the specified value. | `set_variable = {` | 1020 |
| `split_troops` | Hands a fraction of the country's troops to the target, as a value between 0 and 1. Written in the receiving country's scope: `GER = { split_troops = 0.10 }`. **Can move the affected units into a random adjacent province under unknown circumstances.** | `tag = { split_troops = x }` | 23 |
| `strategic_resource` | An effect to add or remove a strategic resource from a province. | `strategic_resource = <resource_name> / none` | 68 |
| `supplies` | Increase/decrease a province’s max production of supplies. | `supplies = x` | 2230 |
| `surrender_inherit` | The target inherits this country's holdings on surrender. | `surrender_inherit = ...` | 11 |
| `threat` | Increase/decrease the specified country’s threat value towards the current country by x. | `threat { who = tag / all value = x }` | 391 |
| `undeclared_war` | Allows units of the current country and tag country to fight each other in a delimited area. Works properly just for sea zones so far, as the attacker cannot capture provinces this way. | `undeclared_war = ...` | 3 |
| `war` | Start a war between the current country and the specified country with a defined wargoal. The "Aquire Territory" wargoal requires also region = <region_name> to be specified. Wargoals can be found in common/cb_types.txt file. (example of Winter War:) | `war = ...` | 742 |
| `war_exhaustion` | Changes war exhaustion by the given offset. Applied once, not monthly. In the base game war exhaustion is added to neutrality when a war ends; BiceLib patches that out, so in BlackICE it is not. | `war_exhaustion = ...` | 36 |

## Not keywords, but they work anyway

An effect key that is not in the switch above still works if it names something the game
declares elsewhere. These are the ones the old notes covered, and they are worth knowing
because they look like keywords and are not:

| Written as | What it does | Why it works |
| --- | --- | --- |
| `industry = x` | Changes a province's IC by x, roughly 1-10. | `industry` is a building, declared in `common/buildings.txt`. Any building name can be used this way. |
| `head_of_state = <minister id>` | Appoints that minister. `head_of_government`, `foreign_minister`, `armament_minister`, `minister_of_security` and `minister_of_intelligence` all work the same way. | Handled by the minister loader, not the effect switch. As a condition the same keys test who currently holds the post. |
| `<province id> = { <brigade type> = current }` | Gives the country a new brigade in that province - `militia_brigade`, `infantry_brigade` and so on. `<brigade type> = <province id>` works too. | The province id opens a scope, and the brigade type names a unit. The brigade attaches itself to any unit already in the province, and **spawns without any technology applied**. |

## Inside an option

Two keys shape an option rather than doing anything to the world:

| Keyword | What it does | Syntax |
| --- | --- | --- |
| `ai_chance` | The percentage chance the AI picks this option. | `ai_chance = { factor = x }` |
| `modifier` | Multiplies the surrounding `ai_chance` when its conditions hold. Several may be added. Note this is the same keyword as the one inside `mean_time_to_happen`, doing the same job for a different number. | `modifier = { factor = x ... }` |
