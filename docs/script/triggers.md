# Script triggers

<!-- The keyword lists come from CTrigger::LoadKey and CEffect::LoadKey, read out of
     the game itself. reversing/findings/FINDINGS-script.md in the reversing folder has the save token
     and implementing class of every one. -->

The conditions an event or a decision can test. There are **152** of
them and every one is listed here.

A key that is none of these, and none of the names the game declares elsewhere (a
technology, a unit type, a province id, a country tag), is **silently dropped** - the
condition never fires and nothing is logged. See
[the overview](README.md#when-a-key-is-wrong-nothing-happens).

Entries marked **(unverified)** are keywords the engine accepts but this mod never uses.
Their description is inferred from the name of the class the loader builds and has not been
confirmed in game.

## Event header keys

Not conditions as such - these control the event itself rather than testing anything about the world.

| Keyword | What it does | Syntax | Uses in the mod |
| --- | --- | --- | --- |
| `id` | Event ID number. | `id = Event_ID` | 5717 |
| `major` | Marks the event as a major one, so it is shown to every player rather than only the country it fires for. | `major = yes` | 252 |
| `is_triggered_only` | Such event will not fire unless triggered by another event or decision. Additional trigger conditions may still be added. | `is_triggered_only = yes` | 2764 |
| `mean_time_to_happen` | An average timespan around which an event randomly fires. | `mean_time_to_happen = { months = x / days = x }` | 1546 |
| `modifier` | Multiplies the current mean_time_to_happen probability by x when certain conditions are met. More modifiers for one mean_time_to_happen may be added. (e.g. mean_time_to_happen will be 5 days (half of the original) during and after June:) | `modifier = { factor = x ... }` | 419 |

## Conditions

| Keyword | What it does | Syntax | Uses in the mod |
| --- | --- | --- | --- |
| `active_mission` | **(unverified)** Whether a given mission is currently active. | `active_mission = ...` |  |
| `ai` | Returns true if the country is handled by the AI. | `ai = yes / no` | 3063 |
| `air_battles_fought` | How many air battles the country has fought. | `air_battles_fought = ...` | 33 |
| `alliance_with` | Returns true if the country is allied with the specified country. | `alliance_with = tag / this / from` | 138 |
| `always` | **(unverified)** Always true, or always false with `always = no`. The usual way to switch a condition off without deleting it. | `always = ...` |  |
| `and` | All parts of the group are valid. | `and = ...` | 7448 |
| `any_core` | Any province that is a core of the current country. | `any_core = ...` |  |
| `any_neighbor_country` | Any country neighboring the current country. | `any_neighbor_country = ...` | 1 |
| `any_neighbor_province` | Any province neighboring the current province. | `any_neighbor_province = ...` | 116 |
| `any_owned_province` | Any owned province. | `any_owned_province = ...` | 72 |
| `base_neutrality` | Returns true if a country’s base neutrality value is equal to x or more. | `base_neutrality = x` |  |
| `blockade` | Returns true if the blockade percentage is equal to x or above. | `blockade = x` |  |
| `brigade_exist` | True when a brigade with the given name exists. Takes the unit's name as a string, not a yes/no - the mod's most used trigger by a wide margin. | `brigade_exist = ...` | 5695 |
| `brigade_in_combat` | Returns true if said brigade is currently in combat. # Spaces in Names break it. # Will only check for units in TAG, so add "TAG = {}" if you check for another nations unit | `brigade_in_combat = <name>` | 115 |
| `can_create_vassals` | Returns true if the current country can create a puppet state. | `can_create_vassals = yes / no` |  |
| `capital` | Returns true if the specified capital is the current country’s capital. | `capital = <province id>` | 67 |
| `casus_belli` | A casus belli against the target. As a trigger it tests for one; as an effect it grants one. Takes the type, e.g. `conquer`. | `casus_belli = ...` | 202 |
| `check_variable` | Returns true if the <variable name> has been set at an earlier stage and its value is equal to x. | `check_variable = {` | 8035 |
| `continent` | Returns true if the current province belongs to the specified continent. | `continent = <name of continent>` | 23 |
| `controlled_by` | Returns true if the province is controlled by the specified country. | `controlled_by = tag` | 2765 |
| `controls` | Returns true if the current country controls the specified province. | `controls = <province id>` | 4658 |
| `country_units_in_province` | Returns true if the current country has x or more units in the specified province. | `country_units_in_province = x` | 53 |
| `crude_oil` | Returns true if the amount of crude oil a country has is equal to x or more. | `crude_oil = x` | 92 |
| `date` | Returns true if x is the current date or a later date. | `date = x  # (yyyy.m.d)		#starts at 1; so 1939.5.1 == 1st of May` | 3564 |
| `dissent` | Returns true if a country’s dissent value is equal to x or more. | `dissent = x` | 689 |
| `empty` | Returns true if the current province is empty. | `empty = yes / no` |  |
| `energy` | Returns true if the amount of energy a country has is equal to x or more. | `energy = x` | 2168 |
| `exists` | Returns true if the specified country exists. | `exists = tag` | 1739 |
| `faction` | Returns true if a country belongs to the specified faction. | `faction = axis /allies / comintern` | 2420 |
| `faction_progress` | Returns true if the victory progress of the current faction is equal to x percent or more. | `faction_progress = x   # (x = 1..)` |  |
| `government` | Returns true if the country has the specified government type. | `government = <government type>` | 340 |
| `government_in_exile` | Returns true if the specified country has a government in exile. | `government_in_exile = yes / no` | 100 |
| `guarantee` | Returns true if the specified country is guaranteeing the independence of the current country. | `guarantee = tag` | 7 |
| `has_building` | Returns true if the current province has the specified building. | `has_building = <building type>` | 53 |
| `has_cb` | Checks to see if the scoped country has a war goal on it from the specified country | `has_cb = { actor = THIS type = aquire_all_cores }` |  |
| `has_country_flag` | Returns true if the current country has the specified flag. | `has_country_flag = <name of flag>` | 17066 |
| `has_country_modifier` | Returns true if the current country has the specified modifier. | `has_country_modifier = <name of modifer>` | 3984 |
| `has_empty_adjacent_province` | **(unverified)** Whether an adjacent province is empty. | `has_empty_adjacent_province = ...` |  |
| `has_global_flag` | Returns true if any country has set a global flag. | `has_global_flag = <name of flag>` | 299 |
| `has_hostile_spy_mission` | **(unverified)** Whether a hostile spy mission is running here. | `has_hostile_spy_mission = ...` |  |
| `has_leader` | Returns true if the country has the specified leader. | `has_leader = <name of leader>` |  |
| `has_province_flag` | Returns true if the current province has the specified flag. | `has_province_flag = <name of flag>` | 120 |
| `has_province_modifier` | Returns true if the current province has the specified modifier. | `has_province_modifier = <name of modifer>` | 27 |
| `has_removable_minister` | If the minister can be replaced in his position. | `has_removable_minister = yes / no` | 2 |
| `has_strategic_resource` | A trigger to check if a province has any strategic resource. | `has_strategic_resource = yes / no						-- Do not use "has_strategic_resource = no". It does not work always. instead put the "yes" one in a "not = {}"` | 22 |
| `has_wargoal` | Checks if current country has any wargoals set against tag country. | `has_wargoal = tag` | 16 |
| `ideology` | Returns true if the country’s ruling party belongs to the specified ideology. | `ideology = <ideology type>` | 34 |
| `ideology_group` | Returns true if the country’s ruling party belongs to the specified ideology group. | `ideology_group = <ideology group name> (fascism, democracy, communism)` | 24 |
| `is_blockaded` | Returns true if the province is blockaded. | `is_blockaded = yes / no` |  |
| `is_capital` | Returns true if the current province is a capital. | `is_capital = yes / no` | 2 |
| `is_core` | Returns true if the specified province is a core of the current country. | `is_core = <province id>` | 714 |
| `is_in_any_faction` | Returns true if a country is a member of a faction. | `is_in_any_faction = yes / no` | 77 |
| `is_mission_country` | **(unverified)** Whether this country is the mission's target. | `is_mission_country = ...` |  |
| `is_mission_province` | **(unverified)** Whether this province is the mission's target. | `is_mission_province = ...` |  |
| `is_possible_vassal` | Returns true if the specified country can be released as a puppet state. | `is_possible_vassal = yes / no` |  |
| `is_subject` | Returns true if the current country is a puppet. | `is_subject = yes / no` | 102 |
| `is_threatend` | The threat level against this country. Note the engine's own misspelling - `is_threatened` is not a keyword and is silently ignored. | `is_threatend = ...` | 2 |
| `land_battles_fought` | How many land battles the country has fought. | `land_battles_fought = ...` | 3 |
| `last_air_battle_loser_losses` | **(unverified)** Casualties the losing side took in the last air battle. | `last_air_battle_loser_losses = ...` |  |
| `last_air_battle_winner_losses` | **(unverified)** Casualties the winning side took in the last air battle. | `last_air_battle_winner_losses = ...` |  |
| `last_battle_loser_losses` | Casualties the losing side took in the most recent land battle. | `last_battle_loser_losses = ...` | 60 |
| `last_battle_winner_losses` | Casualties the winning side took in the most recent land battle. | `last_battle_winner_losses = ...` | 36 |
| `last_mission` | **(unverified)** The most recent mission. | `last_mission = ...` |  |
| `last_naval_battle_loser_losses` | **(unverified)** Casualties the losing side took in the last naval battle. | `last_naval_battle_loser_losses = ...` |  |
| `last_naval_battle_winner_losses` | **(unverified)** Casualties the winning side took in the last naval battle. | `last_naval_battle_winner_losses = ...` |  |
| `leadership` | Returns true if the province has a leadership value equal to x or higher. | `leadership = x` | 92 |
| `lost_IC` | Returns true if the number of IC that a country has lost is equal to x or more. | `lost_IC = x` |  |
| `lost_national` | Returns true if the number of core provinces that a country has lost is equal to x or more. | `lost_national = x` | 8 |
| `manpower` | Returns true if the country / province has a manpower value equal to x or higher. | `manpower = x` | 1907 |
| `manpower_percentage` | Returns true if the country has a manpower percentage of x or above. | `manpower_percentage = x` |  |
| `max_manpower` | Returns true if the country’s maximum manpower is equal to x or higher. | `max_manpower = x` | 28 |
| `max_manpower_greater_than` | Returns true if the country’s maximum number of manpower is equal to x or more. | `max_manpower_greater_than = x` |  |
| `metal` | Returns true if the amount of metal a country has is equal to x or more. | `metal = x` | 2423 |
| `military_access` | Returns true if the specified country has military access to the current country. | `military_access = tag` | 22 |
| `minister_alive` | Returns true if the specified minister is active. | `minister_alive = <minister id>` | 9 |
| `money` | Returns true if the amount of money a country has is equal to x or more. | `money = x` | 2226 |
| `month` | Returns true if x is the current month or a later month. | `month = x	#starts at 0: so month = 5 == June` | 462 |
| `national_unity` | Returns true if the country’s national unity is equal to x or more. | `national_unity = x` | 382 |
| `nationalism` | Returns true if the nationalism value is equal to x or more. | `nationalism = x` |  |
| `naval_battles_fought` | **(unverified)** How many naval battles the country has fought. | `naval_battles_fought = ...` |  |
| `neighbour` | True when the target country borders this one. Note the British spelling - `neighbor` is not a keyword and is silently ignored. | `neighbour = ...` | 11 |
| `neutrality` | Returns true if a country’s effective neutrality value is equal to x or more. | `neutrality = x` | 186 |
| `non_aggression_pact` | Returns true if the specified country has a non-aggression pact with the current country. | `non_aggression_pact = tag` | 62 |
| `not` | No parts of the group are valid. # While this should have an implicit AND inside of it, it does not work correctly unless you explicitly state the AND | `not = ...` | 17880 |
| `num_in_faction` | Returns true if the number of members belonging to the same faction as the current country is equal to x or more. | `num_in_faction = x` |  |
| `num_of_allies` | Returns true if the number of allies equals x or more. | `num_of_allies = x` |  |
| `num_of_cities` | Returns true if the country has x or more cities. | `num_of_cities = x` | 3 |
| `num_of_convoys` | Returns true if the number of convoys belonging to a country is equal to x or more. | `num_of_convoys = x` |  |
| `num_of_ports` | Returns true if the country has x or more ports. | `num_of_ports = x` | 10 |
| `num_of_revolts` | Returns true if there are x or more revolts in the country. | `num_of_revolts = x` |  |
| `num_of_vassals` | Returns true if the number of puppets a country has is equal to x or more. | `num_of_vassals = x` | 4 |
| `or` | At least one part of the group is valid. | `or = ...` | 2410 |
| `organisation` | Returns true if a country’s ruling party has an organisation value equal to x or more. | `organisation = x` | 347 |
| `owned_by` | Returns true if the specified country owns the current province. | `owned_by = tag` | 243 |
| `owns` | Returns true if the country owns the specified province. | `owns = <province id>` | 66 |
| `popularity` | Returns true if the country’s ruling party has a popularity value equal to x or more. | `popularity = x` | 361 |
| `province_id` | Returns true if current province has the specified ID. | `province_id = <province id>` | 28 |
| `pure_revolt_risk` | **(unverified)** Revolt risk before modifiers, as opposed to `revolt_risk`. | `pure_revolt_risk = ...` |  |
| `rare_materials` | Returns true if the amount of rare materials a country has is equal to x or more. | `rare_materials = x` | 2171 |
| `region` | Returns true if the province belongs to the specified region. | `region = <name of region>` | 217 |
| `relation` | Returns true if the specified country has a relation value equal to y or higher with the specified country. | `relation = { who = tag value = y }` | 1989 |
| `remove_fow` | Fog of war. As a trigger it tests whether fog of war has been lifted; as an effect it lifts it. | `remove_fow = ...` |  |
| `revolt_percentage` | Returns true if the percentage of revolts in the country is equal to x or higher. | `revolt_percentage = x` |  |
| `revolt_risk` | Revolt risk. As a trigger it tests the current value; as an effect it changes it. | `revolt_risk = ...` | 2 |
| `spies` | **(unverified)** How many spies the country has. | `spies = ...` |  |
| `spy_mission_count` | **(unverified)** How many spy missions are running. | `spy_mission_count = ...` |  |
| `strat_allies_impact` | Returns true if the strategic impact from allies is equal to x or more. | `strat_allies_impact =  x` |  |
| `strat_bomb_impact` | Returns true if the strategic impact from bombing is equal to x or more. | `strat_bomb_impact =  x` |  |
| `strat_convoy_impact` | Returns true if the strategic impact from a convoy is equal to x or more. | `strat_convoy_impact =  x` |  |
| `strategic_resource` | A trigger to check if a country/province has a specific resource. | `strategic_resource = <resource_name>` | 68 |
| `supplies` | Returns true if the amount of supplies a country has is equal to x or more. | `supplies = x` | 2230 |
| `surrender_progress` | Unlike the lost_national, this checks directly for surrender progress. Since FTM 3.05, the surrender formula is counted as CoreStillControlledVPs / OwnedVPs; i.e. the x per cent loss of victory points located in provinces, which the current country has both cores and ownership of | `surrender_progress = x` | 47 |
| `tag` | Returns true if the current country has a country tag that matches the specified tag. | `tag = <country tag>` | 10583 |
| `threat` | Returns true if the threat value is equal to x or more. | `threat = x` | 391 |
| `total_amount_of_brigades` | Returns true if the number of brigades belonging to a country is equal to x or more. | `total_amount_of_brigades = x` | 121 |
| `total_amount_of_divisions` | Returns true if the number of divisions belonging to a country is equal to x or more. | `total_amount_of_divisions = x` |  |
| `total_amount_of_planes` | Returns true if the number of planes belonging to a country is equal to x or more. | `total_amount_of_planes = x` | 68 |
| `total_amount_of_ships` | Returns true if the number of ships belonging to a country is equal to x or more. | `total_amount_of_ships = x` | 51 |
| `total_defensives` | Returns true if the number of defensive battles a country is currently involved in is equal to x or more. | `total_defensives = x` |  |
| `total_ic` | Returns true if the total amount of ic a country has is equal to x or more. | `total_ic = x` | 70 |
| `total_num_of_ports` | Returns true if the total number of ports a country has is equal to x or more. | `total_num_of_ports = x` | 2 |
| `total_of_ours_sunk` | Returns true if the number of sunken ships belonging to the current country is equal to x or more. | `total_of_ours_sunk = x` |  |
| `total_offensives` | Returns true if the number of offensive battles a country is currently involved in is equal to x or more. | `total_defensives = x` |  |
| `total_sea_battles` | Returns true if the number of sea battles currently undertaken is equal to x or more. | `total_sea_battles = x` |  |
| `total_sunk_by_us` | Returns true if the total number of ships sunk by the current country is equal to x or more. | `total_sunk_by_us = x` | 1 |
| `total_we_bomb` | Returns true if the number of provinces we are currently bombing is equal to x or more. | `total_we_bomb = x` |  |
| `truce_with` | Returns true if the current country has a truce with the specified country. | `truce_with = tag / this / from` |  |
| `undeclared_war_with` | **(unverified)** Whether an undeclared war is running with the target. | `undeclared_war_with = ...` |  |
| `unit_has_leader` | Returns true if any unit in the current country has a leader. | `unit_has_leader = yes / no` |  |
| `unit_in_battle` | Returns true if the country has any unit that is fighting a battle. | `unit_in_battle = yes / no` |  |
| `units_in_province` | Returns true if there are x or more units in the current province. This means actual Divisions, NOT the brigades they are made of | `units_in_province = x` | 88 |
| `vassal_of` | Returns true if the current country is a puppet state to the specified country. | `vassal_of = tag / this / from` | 123 |
| `war` | Returns true if the current country is at war. | `war = yes / no` | 742 |
| `war_exhaustion` | Returns true if the country’s war exhaustion is equal to x or above. | `war_exhaustion = x` | 36 |
| `war_with` | Returns true if the current country is at war with the specified country. | `war_with = tag` | 2729 |
| `year` | Returns true if x is the current year or a later year. | `year = x` | 1394 |

## Combat scope conditions

Only meaningful inside a combat event, where the scope is a battle rather than a country or a province.

| Keyword | What it does | Syntax | Uses in the mod |
| --- | --- | --- | --- |
| `enemy` | **(unverified)** Scope over the enemy in a combat. | `enemy = ...` |  |
| `enemy_ic_ratio` | **(unverified)** The ratio of enemy industrial capacity to this country's. | `enemy_ic_ratio = ...` |  |
| `frontage_full` | **(unverified)** Whether the combat frontage is fully occupied. | `frontage_full = ...` |  |
| `has_armour_unit` | **(unverified)** Whether a combat involves an armoured unit. | `has_armour_unit = ...` |  |
| `has_combat_modifier` | **(unverified)** Whether a named combat modifier applies. | `has_combat_modifier = ...` |  |
| `has_combined_arms` | **(unverified)** Whether the combined arms bonus applies. | `has_combined_arms = ...` |  |
| `is_attacker` | **(unverified)** Whether this side is the attacker in a combat. | `is_attacker = ...` |  |
| `is_convoy` | **(unverified)** Whether the combat involves a convoy. | `is_convoy = ...` |  |
| `is_winner` | **(unverified)** Whether this side is winning the combat. | `is_winner = ...` |  |
| `out_of_supply_days` | **(unverified)** How many days a unit has been out of supply. | `out_of_supply_days = ...` |  |
| `province_temperature` | **(unverified)** The temperature in the province a combat is fought in. | `province_temperature = ...` |  |
| `reserves` | **(unverified)** Whether a unit is a reserve. | `reserves = ...` |  |
| `skill` | **(unverified)** A leader's skill. | `skill = ...` |  |
| `skill_advantage` | **(unverified)** The skill difference between the two commanders in a combat. | `skill_advantage = ...` |  |
| `terrain` | **(unverified)** The terrain a combat is fought in. | `terrain = ...` |  |
| `trait` | **(unverified)** Whether a commander has a given trait. | `trait = ...` |  |

## Keys that do not work

The notes these pages replace listed all four of these. **None of them is a keyword**,
so the engine drops the condition without a word and it simply never fires. They are
kept here because anybody who learnt them from the old notes needs to find that out.

| Written in the old notes | Use instead | Why |
| --- | --- | --- |
| `brigade_exists` | `brigade_exist` | the engine has no trailing 's' |
| `fuel` | nothing - there is no fuel condition | `fuel = x` is a real **effect**, so it looks like it should test fuel too. It does not. The old notes said so: "DOES NOT WORK - how silly of me to assume it did" |
| `is_threatened` | `is_threatend` | the engine's own misspelling is the real keyword |
| `neighbor` | `neighbour` | the engine uses the British spelling |
| `port` | `naval_base = <level>, or num_of_ports / total_num_of_ports` | there is no 'port' condition at all. 'port = yes' is real, but it is a property of a building definition in common/buildings.txt, not something an event can test |
