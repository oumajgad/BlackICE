# Orders of battle

An order of battle - an OOB - is a file in `history/units/` describing units. It is either
named from a country's history file, giving what that country starts with, or loaded during a
game by an event or decision:

```
load_oob = "USA/advhq_usa_veteran.txt"
```

The path is relative to `history/units/` and uses forward slashes. Syntax is the same as
everywhere else - see [the overview](README.md).

A complete small one, `history/units/BHU_1936.txt`:

```
corps = {
    name = "Royal Bhutanese Army"
    location = 9472
    regiment = { type = hq_brigade name = "Royal Bhutanese Army HQ" historical_model = 0 }
    division = {
        name = "Household Division"
        location = 9472
        is_reserve = yes
        regiment = { type = colonial_garrison_brigade historical_model = 0 }
        regiment = { type = colonial_militia_brigade historical_model = 0 }
    }
}
```

## Top level

| Key | What it does |
| --- | --- |
| `theatre` `armygroup` `army` `corps` `division` | a land formation |
| `navy` | a fleet |
| `air` | an air formation |
| `military_construction` | a unit in the production queue |
| `building_construction` | a building under construction |
| `convoy_construction` | convoys under construction |
| `unit_deployment` | a built unit waiting in the deployment pool |

A file may hold any number of these, in any combination.

An OOB file is read by the same loader that reads a country's history, so **every key a
country accepts also works here** - `ideology`, `officers`, laws, `capital` and the rest. It
works, but a country's starting state belongs in `history/countries/`: a key put here is
re-applied every time an event loads the file.

## Land formations

The five land keys nest widest-first by convention:

```
theatre  >  armygroup  >  army  >  corps  >  division  >  regiment
```

The game does not enforce that - all five are the same kind of object, and any of them may
contain any other, plus `navy` and `air` blocks. A `division` is simply the level you hang
`regiment` blocks off.

All five take the same keys:

| Key | What it does |
| --- | --- |
| `location` | province id the formation sits in. **Leave it out and the formation is read in full and then silently thrown away** - the one key you cannot omit, unless the block is in a [`unit_deployment`](#the-deployment-pool) |
| `name` | its name. Optional - leave it off and the game names the formation itself |
| `id` | fixes its unit id, rather than letting the game assign one |
| `leader` | id of the commander, from `history/leaders/` |
| `is_reserve` | `yes` makes it a reserve formation |
| `is_prioritized` | `yes` moves it up the production queue |
| `can_upgrade` | whether its brigades may be upgraded |
| `can_reinforce` | whether it may be reinforced |
| `expeditionary_owner` | tag it is on loan from, for expeditionary forces |
| `path` | province id it is already moving toward |
| `movement_progress` | how far along that move it starts |
| `supplies` `fuel` | stocks it starts with |
| `dig_in` | entrenchment level it starts with |

`can_upgrade` works on land formations, fleets and air formations. It does **not** work
inside a `regiment`, `ship`, `wing` or `military_construction`.

## Regiments, ships and wings

The brigades a formation is made of: `regiment` inside a land formation, `ship` inside a
`navy`, `wing` inside an `air`. All three take the same keys.

| Key | What it does |
| --- | --- |
| `type` | the brigade type, from `units/` - e.g. `infantry_brigade`. **Needed** |
| `historical_model` | which model of that type, `0` being the earliest. **Needed** |
| `name` | its name. Usually left off a regiment or wing and auto-named; always given for a ship |
| `experience` | starting experience |
| `strength` | starting strength |
| `organisation` | starting organisation |
| `builder` | tag that built it, for lend-lease |
| `home` | home province |
| `is_reserve` | reserve flag |
| `pride` | marks a ship as the pride of the fleet |

## Fleets

`navy` takes the [land formation keys](#land-formations) and adds:

| Key | What it does |
| --- | --- |
| `base` | home port province. **Needed** |
| `ship` | a ship in the fleet. **At least one needed** |
| `at_sea` | whether the fleet starts at sea rather than in port |
| `division` | land units loaded aboard, see [below](#troops-aboard-ships-and-planes) |

## Air formations

`air` takes the [land formation keys](#land-formations) and adds:

| Key | What it does |
| --- | --- |
| `base` | home airbase province. **Needed** |
| `wing` | a wing in the formation. **At least one needed** |
| `division` | land units aboard, for transport planes |

## Carrier air groups

An `air` block **inside a `ship`** is that carrier's air group, and takes only:

| Key | What it does |
| --- | --- |
| `location` | where it is. **Needed** |
| `wing` | a wing aboard. **At least one needed** |

No `name` and no `base`.

## Troops aboard ships and planes

A `division` inside a `navy` or an `air` is cargo - units already loaded when the game
starts. It is an ordinary formation block, so the same keys apply; give it a `name`, a
`location` and its `regiment` blocks.

## Units in the production queue

`military_construction` puts a unit into the production queue instead of on the map.

| Key | What it does |
| --- | --- |
| `<brigade type> = { ... }` | a subunit being built. **At least one needed** |
| `country` | tag building it. Leave it out and the country the OOB was loaded for is used |
| `cost` | total IC cost |
| `progress` | IC already spent, so how far along it starts |
| `duration` | days to completion |
| `name` | the finished division's name |
| `is_reserve` | reserve flag |
| `is_prioritized` | move it up the queue |

Each subunit block takes a `name`, an optional `experience`, and one of the two model forms
below. `organisation` does **not** work here: organisation starts at zero after construction
regardless.

```
military_construction = {
    country = GER
    name = "Heeres-Flak-Artillerie-Abt 100"     # the division's name
    is_reserve = yes

    heavy_anti_air_brigade = { historical_model = 4 }
    civilian_truck_transport = { name = "" historical_model = 7 }

    cost = 7.100
    duration = 90.000
    progress = 31.500
}
```

Note the two levels of `name`: the one directly under `military_construction` is the
division's, the one inside a subunit block is that brigade's.

### Saying which model is being built

Either a model number, or a list of technology levels. A subunit uses one or the other:

```
heavy_anti_air_brigade = { historical_model = 4 }        # by model number
```

```
light_cruiser = {                                        # by technology level
    name = "Ping Hai"
    model = {
        0 0 0 0 0 1 1 1 1 0 0 1 1 0 1 1 0 1
    }
}
```

`model` is **one level per technology that affects that unit type, in the order the
technology files are read**. The order is not arbitrary - move one number and you have
described a different ship.

**Get the string from the Utility rather than writing it:** *GameInfo → Units* shows the
model string for the selected unit. Copy that value straight in.

Its length depends on how many technologies affect the unit, so it differs between unit types
and changes whenever the tech tree does. Several lists in the mod are now shorter than they
should be because they were generated against an older tree - if you are editing one,
regenerate it rather than patching it by hand.

`model` only works on a `military_construction` subunit. A `regiment`, `ship` or `wing` uses
`historical_model`.

## Buildings and convoys under construction

| `building_construction` key | What it does |
| --- | --- |
| `building` | which building |
| `location` | province it is being built in |
| `size` | how many |
| `cost` `progress` `duration` | as for `military_construction` |
| `country` | tag building it |
| `status` | leftover bookkeeping, [see below](#status-is-two-different-keys) - writing it does nothing |
| `id` | fixes its id |

`convoy_construction` takes `country`, `size`, `cost`, `progress`, `duration` and an optional
`id`, plus `status` - which here means something quite different.

### `status` is two different keys

**On a `convoy_construction` it decides escorts or transports.** `status = yes` makes the
finished convoys escorts; anything else, `no` included, leaves them as transports. That is
the one `status` in an OOB file that does anything, and `yes` is the only spelling that
carries meaning - transports are what you get by default, so the mod's 101 `status = no`
lines are simply redundant while its 19 `status = yes` lines are doing real work.

**Anywhere else it is leftover bookkeeping.** On a `building_construction` or a
`military_construction`, `status` is how much of a day's work the item received the last time
the production queue advanced: `1` fully funded, `0` unfunded, a fraction for part funded.
The game overwrites it the next time the queue ticks, and nothing in the game reads it.

So setting it in an OOB file changes nothing - not cost, not speed, not what gets built. The
four building items in the mod that write `status = 1` may as well not. (The "nothing reads
it" comes from two sweeps of the game's code that found no reader; strong, though a sweep can
miss misaligned code.)

## The deployment pool

`unit_deployment` holds a unit that has been built but not yet placed on the map - the pool
the player deploys from.

| Key | What it does |
| --- | --- |
| `army` `theatre` `armygroup` `corps` `division` | the unit waiting to be deployed. All five mean the same thing here |
| `navy` | a fleet waiting to be deployed |
| `air` | an air formation waiting to be deployed |
| `id` | fixes its id |

Two things to get right:

- **One unit per block.** A second unit keyword in the same `unit_deployment` overwrites the
  first, and the first is leaked. Write one block per unit, which is what the game's own
  saves do.
- **No `location`, and none wanted.** A pooled unit is not on the map, so it has no province.
  This is the one place a formation may omit `location` without being discarded.

Firing the same `load_oob` twice adds every `unit_deployment` in it twice - the list is only
ever appended to, nothing de-duplicates, and the `id` values are not checked against anything.

## Keys you will see but should not write

A handful of files here were copied out of a savegame. They carry keys that are save state
rather than settings - the loader accepts them, but there is no reason to write one by hand:

`highest` `current_distance` `sunk_by` `track` `previous` `retreat`
`possible_retreat` `disengage` `arrow_state` `start_date` `end_date` `was_paradropped`
`attack_delay` `combat_hours` `expeditionary_date` `aggression_enabled` `aggression_setting`
`country_intel` `target` `parent` `staging_province` `plan`

The construction blocks have their own set, none of which the mod writes:

`unit` `manpower` `factor` `accumulated_experiance` `accumulated_progress` `count`

(`accumulated_experiance` is the game's own spelling.)

Those files are also recognisable by `organisation=25.311`-style precision and technology
names carrying `{n 0}` pairs. Do not copy the style into a new file.

## One wrong key wrecks the rest of the file

This is worth understanding before hand-writing an OOB, because the damage is much wider than
the line you got wrong.

An unrecognised key is not skipped. The parser reads the key, the `=`, and **one** value
token - and for `foo = {` that one token is the `{` itself. The loader does not know `foo`, so
it refuses the key and **consumes nothing**. Parsing then resumes at the next token, which is
the first key *inside* the block it just refused.

So the block's contents are read as keys of whatever encloses it, and the first `}` that turns
up where a key should be **ends the enclosing object early**. Everything after that point in
the file is not read at all.

A single mistyped block name can therefore take out the rest of the file, not just its own
unit. Nothing warns: the message goes onto a list that is only ever printed for savegames and
DLC, never for a data file.

Checking a file against the tables above is the cheap way to find it: a key that is not in
them is either a typo or savegame leftovers.

---

Formation and brigade keys are read out of the game -
[`FINDINGS-oob.md`](../../DaveStuff/luabinaries/bice/BiceLib/reversing/FINDINGS-oob.md) has
the loaders behind them, and the `CConstruction` family in
[`CLASSES.md`](../../DaveStuff/luabinaries/bice/BiceLib/reversing/CLASSES.md) covers the three
construction blocks, including where each key lands and which class shadows `status`.

Counts are from the 4,508 files in `history/units/`.
