# Weather, and what it actually does

Read out of the executable on 2026-09-30. Addresses are **RVAs** against an image base of
`0x400000`, like the rest of this folder; where a virtual address is meant it says so.

**The headline is not a negative.** Weather in this build is a real simulation with nine
consumers, and two of them - land movement and supply losses - are tuned by `defines.lua`
entries that BlackICE has already changed. Nothing about weather is cosmetic except the
picture, and **no weather define is dead**: all 56 the engine reads have at least one reader.
The one dead entry is in the mod's own file - see *The one dead define* below.

What weather reaches:

| what | where | which fields |
| --- | --- | --- |
| **land combat**, as `BM_WEATHER` | `CLandCombatant::ApplyCombatModifiers` | precipitation, windspeed, temperature |
| **naval combat**, as `BM_WEATHER` | `CNavalCombatant::ApplyCombatModifiers` | windspeed, precipitation |
| **air and bombing combat**, as `BM_WEATHER` | `CAirCombatant::` and `CBomberCombatant::ApplyCombatModifiers` | windspeed, temperature, cloud, precipitation |
| **land movement speed** | `CUnit::MovementSpeedModifier` | muddyness, frozen, temperature |
| **supply losses** | `SupplyLoss` (`0x9DE80`) | muddyness, frozen |
| **attrition** | `GetProvinceAttrition` (`0xA0990`) | temperature, windspeed |
| **a naval battle breaking off** | `CNavalCombat::Tick` | windspeed, precipitation |
| **naval spotting** | `ShouldStartNavalCombat` (`0x31840`) | cloud, precipitation |
| **firing range** | `CSubUnit::FiringRange` (`0x1AC470`) | precipitation |
| **whether a wing may enter a province** | `CAir::CanMoveTo` (`0x1D0ED0`) | cloud |

## 1. Where it is stored, and who writes it

### The fields

`CProvince +0x68` is a `CWeather` held by value - already recorded, and now confirmed from
the other side: `CProvince::CProvince` (`0x94700`) writes the `CWeather` vftable (VA
`0x15C08D4`) at `[esi+0x68]` at `0x9476D`, the `CPersistent` meta word `0x18D` at `+0x6C`,
zeroes `+0x70`..`+0x8C`, and then does two more things nobody had noticed:

```
0x94795   mov dword ptr [esi + 0x94], esi          ; the weather's back pointer to the province
0x9479E   mov edx, dword ptr [g_PRESSUREDEFAULT]
0x947A4   mov dword ptr [esi + 0x74], edx          ; pressure starts at PRESSUREDEFAULT
```

So the class is ten fields, not eight:

| CWeather | in a province | save key | |
| --- | --- | --- | --- |
| `+0x08` | `+0x70` | `humidity` | |
| `+0x0C` | `+0x74` | `pressure` | starts at `PRESSUREDEFAULT` |
| `+0x10` | `+0x78` | `windspeed` | |
| `+0x14` | `+0x7C` | `temperature` | |
| `+0x18` | `+0x80` | `precipitation` | |
| `+0x1C` | `+0x84` | `muddyness` | |
| `+0x20` | `+0x88` | `frozen` | |
| `+0x24` | `+0x8C` | `cloud_coverage` | |
| `+0x28` | `+0x90` | - | the `CWeatherFront*` over the province, cached each hour |
| `+0x2C` | `+0x94` | - | **`CProvince*`**, back pointer, written by the constructor |

The back pointer is what makes the rest legible: every `CWeather` method reaches the
province's terrain, its climate and its night flag through `+0x2C`, the same convention
`CProvinceModifier` uses at its own `+0x2C`. RTTI knows all three weather classes, so the new
structs are anchored: `CWeather` vftable VA `0x15C08D4`, `CWeatherFront` VA `0x15C08B8`,
`CWeatherManager` VA `0x15CF5C0`.

Four more province fields belong to weather, none of them saved:

| | |
| --- | --- |
| `CProvince +0x10` | scratch for the pressure walk: the cost so far, set to 99999 on every province at the start of each propagation |
| `CProvince +0x14` | **the `CWeatherFront` currently over this province**, or 0 |
| `CProvince +0x2C` | a byte: **is it night here** |
| `CProvince +0x30` | a climate zone in 1..5, filled lazily by `ComputeProvinceClimate` (`0xA81A0`) |
| `CProvince +0x98`, `+0x9C` | the weather picture's name and a redraw flag |

`CGameState +0xAEC` is a `CWeatherManager` **held by value**, not a pointer -
`CGameState::CGameState` writes its vftable (VA `0x15CF5C0`) straight into `[ebx+0xAEC]` at
`0x27D1BD`. `project.json` types that field `void*`; it should be `CWeatherManager`. Its own
fields:

```
CWeatherManager                embedded in CGameState at +0xAEC
  +0x08  first front           the live CWeatherFronts
  +0x0c  last front
  +0x10  count
  +0x14  a byte - while set, a spent front is marked rather than freed
  +0x18  begin                 one countdown per low pressure zone
  +0x1c  end
```

### Who advances it, and how often

**Two calls, both out of `RunHourlyPass` (`0x282630`), and nowhere else.**

```
0x2826F3   lea edi, [ebx + 0xaec]      ; the CWeatherManager
           call 0xB5A20                ; CWeatherManager::Tick
...
0x282A3B   call 0x28E270               ; -> the per-province weather pass
```

`0x28E270` is the function `project.json` already calls `ProcessProvinceFunctor`, and
`RunHourlyPass` is its **only** caller. It spawns a TBB task whose vftable is at VA
`0x15CF71C`; `execute` is `0x28EEB0` (`ProcessProvinceFunctor_start_for::execute`), which
halves the province range recursively and calls `UpdateProvinceWeatherRange` (`0x27B1C0`) on
each leaf. That function is what the name hides:

```
for each province in the range:
    if (province->template->+0x13D):                 # land, by this flag rather than +0x22
        province->is_night = IsNight(province, ...)   # 0xA7390
        CWeather::Update(&province->weather)          # 0xB2590
        name = CWeather::GraphicName(&province->weather)
        if (name != province->+0x98) { province->+0x9C = 1; province->+0x98 = name }
```

So **province weather changes once an hour, on every land province**, and the thing this
folder had recorded as a generically-named province functor is the weather update.

`CWeatherManager::Tick` (`0xB5A20`, `this` in **EDI**) does the global half, in this order:

1. fills the per-zone countdown vector at `+0x18` if it is empty (`0xB54F0`) and
   **decrements every entry**;
2. for each province id on **`CMap +0x21C8`** - `default.map`'s `high_pressure_zones`, a key
   `fieldmap.py` left unplaced - calls `PropagateHighPressure` (`0xB6050`);
3. while the front count at `+0x10` is below `(number of low_pressure_zones) x
   MAXFROMEACHPRESSURE/1000`, makes another front (`0xB5D80`) and links it. With BlackICE's
   `default.map` that is 19 zones x 8 = **152 fronts**;
4. clears `CProvince +0x14` on every province in the game state's vector at `+0xB8C`;
5. ticks each front (`0xB4620`), unlinking and freeing the ones that answer false. A live
   front re-stamps itself onto `+0x14` for every province on its own list, which is why step
   4 has to come first.

`PropagateHighPressure` is a breadth-first walk over the province graph out of one seed: the
seed's pressure is set to `PRESSUREMAX`, and for a neighbour reached at distance `d`
(`CProvinceTemplate +0x24` per step, the neighbour id at `edge+4` through `CMap +0x2200`) the
target is `seedPressure - d x PRESSUREREDUCTION/1000`; where that beats the neighbour's own
pressure the neighbour's pressure rises by **one `PRESSUREPROPAGATION` step** and the walk
continues through it while the target stays positive.

`CWeatherFront::Tick` (`0xB4620`) decrements the front's `+0x24` - the loader's `speed` key,
used as a countdown - and only moves the front when it hits zero, resetting it to
`WEATHERMOVEMENTDELAY/1000`. So `speed` is "hours per step", not a velocity.

`CWeather::Update` (`0xB2590`, `this` in **EDI**) is the per-province hour. The parts that
matter to the mod:

- with **no front over the province**, windspeed decays by a compiled-in **0.750** an hour
  and `CWeather +0x28` is cleared; with one, the front is cached there.
  *(Corrected 2026-10-01. This said 0.980, as did `project.json`. The bytes at `0xB25B1`
  are `imul dword ptr [0x1A86F3C]` and `[0x1686F3C]` is `floor(750.5)` = 750, with exactly
  two references in the image - that read and its CRT initialiser. 0.980 is `[0x168703C]`,
  a different global: the humidity and pressure transfer factor in `SpreadWeather`. Found
  by the `CWeatherFront` survey - see `FINDINGS-weatherfront.md`.)*
- humidity is pulled towards the **terrain's own `humidity`** (`CTerrain +0x60`, read at
  `0xB25F4`) and precipitation towards **`50.000 - terrain.precipitation`** (`CTerrain
  +0x64`, read at `0xB2708`). The exact interpolation was not read line by line.
- **muddyness rises** (`0xB28F7`) while it rains, or while frozen ground sits above -5 C;
  otherwise it **dries by `max(infrastructure effect, 2)` an hour**, where the infrastructure
  effect is the province's `MODIFIER_INFRASTRUCTURE` x `(1000 + LOCAL_INFRASTRUCTURE +
  GLOBAL_INFRASTRUCTURE)/1000`, capped at 1000. Below -5 C it is zeroed outright and `frozen`
  takes over.
- **frozen** rises by `HOURLYFROZENINCREASE` below -5 C when precipitation is over 0.250, by
  fractions of it (200/1000, 100/1000 - both compiled-in) in the drier cold branches, and
  falls by `HOURLYTHAW` above 0 C.
- `CWeather::BaseTemperature` (`0xB22E0`) gives the temperature it is pulled towards:
  `CProvinceTemplate +0x8` plus a per-climate offset picked on `CProvince +0x30`, minus 2.000
  at night.
- `CWeather::Clamp` (`0xB2210`) finishes: windspeed to [0, 200.000], temperature to
  [-50.000, 50.000], humidity to [`MINHUMIDITY`, `MAXHUMIDITY`], muddyness and frozen to
  [0, 1.000].

## 2. Combat - `BM_WEATHER`, in four places, not one

`BM_WEATHER` is `0x1A`, and it is one of the ids that **does** have a call site. It has four,
and every one is the same shape:

```
effect = CWeather::<kind>Effect(&combat->province->weather, owner tag)
if (effect != 0):
    combatant->+0x22 = 1
    AddCombatModifier(BM_WEATHER, -effect, -effect)      # attack and defence alike
```

| combatant | the effect | the adder |
| --- | --- | --- |
| `CLandCombatant::ApplyCombatModifiers` `0x169B50` | `CWeather::LandCombatEffect` `0xB4000`, called at `0x16A986` | `CUnit::AddCombatModifier`, `0x16A9B7` |
| `CNavalCombatant::ApplyCombatModifiers` `0x166480` | inline at `0x166B63` | `CSubUnit::AddCombatModifier`, `0x166BC4` |
| `CAirCombatant::ApplyCombatModifiers` `0x16C6F0` | `CWeather::AirCombatEffect` `0xB4130`, at `0x16D118` | `CSubUnit::AddCombatModifier`, `0x16D147` |
| `CBomberCombatant::ApplyCombatModifiers` `0x161680` | `CWeather::BombCombatEffect` `0xB41B0`, at `0x16212B` | `CSubUnit::AddCombatModifier`, `0x162162` |

**Weather is applied identically to attack and to defence**, so it never shifts the balance of
a battle - it shortens it for both sides at once. And it is skipped entirely when the effect
comes out zero, which is the common case in good weather.

### `FINDINGS-combat.md` needs correcting: there is a second adder

`CSubUnit::AddCombatModifier` (**`0x1AC300`**) is exactly `CUnit::AddCombatModifier`
(`0x1C3040`) against a sub unit: it appends a 12-byte `{id, attack, defence}` record to the
`CList` at `CSubUnit +0x40/+0x44/+0x48` and multiplies `max(1000+value, 10)` into two running
products. Its floor is its own global (`0x168868C`, 10, from the float `10.5` - the Define10
trick again, but a separate global read at 22 sites).

`combatModifierSites.py` only scans `CUnit::AddCombatModifier`, which is why
`FINDINGS-combat.md` says *"nine ids have no call site at all"* and *"the modifier list is
land only"*. **Seven of those nine push their id through the sub-unit adder**:

| id | | pushed in |
| --- | --- | --- |
| `0x09` | `BM_RADIO` | bomber, target, air combatants |
| `0x14` | `BM_BASE_PROXIMITY` | air combatant |
| `0x15` | `BM_POOR_SCREEN_PENALTY` | naval combatant, target combatants |
| `0x16` | `BM_RADAR_STATION` | bomber, air combatants |
| `0x17` | `BM_INTERCEPT` | air combatant, twice |
| `0x18` | `BM_AIRCOMBAT` | bomber combatant |
| `0x1D` | `BM_SURPRISE_BONUS` | bomber, naval combatants |

Only `BM_ARMOR_ADVANTAGE` (`0x13`) and `BM_SURPRISE_PENALTY` (`0x1C`) have no call site
anywhere. The watch that found nothing on `CUnit +0xE4` through a naval and an air battle was
right about `CUnit` and wrong about the conclusion: **air and naval modifiers live on the ship
or the wing, not on the unit.** The per-kind override the file predicted is not a tick slot -
it is the choice of adder.

(Also, for what it is worth while I was in there: `CUnit::AddCombatModifier` multiplies its
clamped values into `CUnit +0xEC` and `+0xF0`, which `project.json` already names
`combat_attack_product` / `combat_defend_product`. `FINDINGS-combat.md`'s prose says slot 19
writes `+0xF4`/`+0xF8` as the modifier product and `ApplyUnitStrengths` writes `+0xEC`/`+0xF0`
afterwards; if that ordering is right the products would be overwritten. Worth a look, but it
is outside what I was asked to settle.)

### The land effect, term by term

`CWeather::LandCombatEffect` (`0xB4000`), `(CWeather*, int* out, CCountryTag)`, `ret 0x10`,
all thousandths:

```
rain = min( precipitation * (windspeed + 5000)/1000 * LANDRAINIMPACTMODIFIER/1000,
            LANDRAINIMPACTCAP )
out  = rain
if temperature < LANDLOWTEMPERATURETHRESHOLD:
    out += ( -(LANDLOWTEMPERATURETHRESHOLD + temperature) / 20 )
           * LANDLOWTEMPERATUREIMPACT/1000
           * (1000 - owner.MODIFIER_WINTER_EFFECTS)/1000
if temperature > LANDHIGHTEMPERATURETHRESHOLD:
    heat = LANDHIGHTEMPERATUREIMPACT
    if terrain.humidity > 0:  heat = heat * (1000 - owner.MODIFIER_JUNGLE_EFFECTS)/1000
    out += heat
```

Note the cold term's arithmetic is literally `-(threshold + temperature)`, not
`threshold - temperature`, so with BlackICE's `LANDLOWTEMPERATURETHRESHOLD = -5` it is
discontinuous at the threshold: at exactly -5 C it already yields `10000/20 = 500` before the
impact scaling, not zero. That is what the bytes do.

Two things worth pulling out.

**`WINTER_EFFECTS` and `JUNGLE_EFFECTS` are country modifiers 0x62 and 0x63**, reached as
`country->GlobalModifier.values[+0x310]` and `[+0x318]`. They reduce the weather penalty
rather than change the weather, and they apply to **land combat, land movement and attrition
only** - the air and bomb effects are handed a `CCountryTag` on the stack (their `ret 8`
cleans it) and never read it.

**What counts as "jungle" is `CTerrain +0x60`, which is `terrain.txt`'s `humidity`, being
positive.** That offset is the gap the fieldmap already left between `attrition` (`+0x5C`) and
`precipitation` (`+0x64`). In BlackICE the terrains with a positive humidity are `jungle`
(0.8), `hills_jungle` (1), `mountain_jungle` (0.9), `equator_sea` (0.5) and
**`highlands_woods` (5)** - the deserts all set `-50`. So `highlands_woods` counts as jungle
for `JUNGLE_EFFECTS`, which is almost certainly a missing decimal point in the mod's
`terrain.txt`.

### Naval and air

Naval is inlined rather than a `CWeather` method:

```
out = windspeed * NAVALWINDSPEEDMODIFIER/1000 + precipitation * NAVALRAINMODIFIER/1000
```

With BlackICE's `NAVALWINDSPEEDMODIFIER = 0.001` and `NAVALRAINMODIFIER = 0.55`, rain does
essentially all of it.

Air and bombing share one shape against their own defines:

```
out = windspeed * ...WINDSPEEDMODIFIER/1000
    + (temperature <= ...LOWTEMPERATURETHRESHOLD  ? ...LOWTEMPERATUREIMPACT  : 0)
    + (temperature >= ...HIGHTEMPERATURETHRESHOLD ? ...HIGHTEMPERATUREIMPACT : 0)
    + cloud_coverage * ...CLOUDMODIFIER/1000
    + precipitation * ...RAINMODIFIER/1000
```

## 3. Movement

`CUnit::MovementSpeedModifier` (`0x1C8D10`) builds a multiplier in thousandths through an out
pointer, starting at 1000 and multiplying term after term into it. The weather term is at
`0x1C900A`, and it is **land only** - the whole block is inside `if (unit->slot 15 /* isLand
*/)`:

```
province = unit->+0x130                                   # where it is heading
w        = CWeather::MovementEffect(&province->weather, unit->owner)   # 0xB4230, negative
out = out * (1000 + w + province->modifiers[MODIFIER_LOCAL_UNIT_SPEED]) / 1000
```

so the weather and the province's own `LOCAL_UNIT_SPEED` share **one** multiplier rather than
composing.

`CWeather::MovementEffect` (`0xB4230`), `this` in EDI, `int* out` in ESI, a `CCountryTag` by
value on the stack (`ret 8`):

```
out = (frozen == 0) ? muddyness * MUDDYNESSMOVEMENTMODIFIER/1000 : 0
if temperature < LANDLOWTEMPERATURETHRESHOLD:
    out += COLDMOVEMENTMODIFIER * (1000 - owner.MODIFIER_WINTER_EFFECTS)/1000
out = max(out, -989)                       # g_WeatherMovementFloor, 0x1687030
```

Three things the mod's authors should know.

- **Frozen ground pays no mud penalty at all.** `frozen` being non-zero skips the muddyness
  term outright - it is not blended, it is a switch.
- **BlackICE already saturates the engine's floor.** `-989` is not a define; a CRT static
  initialiser at `0x8B39C0` truncates the float `-989.5` at `0x120A7C4`, the same trick as
  `Define10`/`Define50`. With `MUDDYNESSMOVEMENTMODIFIER = -0.75` at full muddyness and
  `COLDMOVEMENTMODIFIER = -0.5`, the sum is `-1250` and is clipped to `-989`, i.e. a movement
  multiplier of `(1000-989)/1000 = 0.011`. Making either modifier more severe cannot change
  anything once both apply.
- **`WINTER_EFFECTS` only scales the cold half**, never the mud.

The full term list of `0x1C8D10`, in the order they multiply (the non-weather ones were read
once each and are summarised rather than confirmed): a combat term when the unit is attacking
in a battle it is part of; the owner's `MODIFIER_COMBAT_MOVEMENT_SPEED` (entry 63) plus the
leader/HQ effect of type 5, capped at 1000 and floored at `Define10`; a fuel term on
`fuel_received_percentage`; the terrain's `movement` adjuster for the next province out of the
sub unit definition's terrain vector at `+0x54`; an order term (`0x1D0F80`, effect `0x1C`);
**the weather and `LOCAL_UNIT_SPEED` term**; and a tail term built from how many of the unit's
regiments set the byte at `definition +0x35`.

There is a second, inlined copy of `CWeather::MovementEffect` at `0x33D5B1`-`0x33D60A`, inside
`0x33D460` in the interface region, reading the fields straight off the province rather than
through a `CWeather*`. It is almost certainly the movement tooltip; that was not confirmed.

## 4. Air missions - it exists, and it is not `IsFitToFly`

`CAirOrder::IsFitToFly` (`0x18A090`) really does not read weather. The gate is one slot
further out:

```
CUnit::CanMoveTo   is vftable slot 35, 0x1C2BA0
CArmy, CNavy       inherit it
CAir               OVERRIDES it with 0x1D0ED0
```

`CAir::CanMoveTo` (`0x1D0ED0`), `this` in ECX untouched, province on the stack, `ret 4`:

```
if (province->cloud_coverage >= ALLOWEDTOFLYTHRESHOLD) return false;
return CUnit::CanMoveTo(province);          # tail call
```

Confirmed from the bytes and from the vftable: `CAir`'s vftable is VA `0x15C8774`, and VA
`0x15C8800` - slot 35 - holds `0x5D0ED0`. It is the only reference to that function anywhere
in the image, which is why a `--callers` scan finds none.

`ALLOWEDTOFLYTHRESHOLD` is `0.7` in BlackICE, so **a wing cannot enter a province whose cloud
coverage is 70 % or more**. `cloud_coverage` is clamped to `[0, 1.000]`. Slot 35 is called from
45 sites in 38 functions, which is too unselective to enumerate honestly; I did not establish
which of them are the mission paths. How often cloud coverage actually reaches 0.700 has
**not** been measured in a running game, and that is the one number that decides whether this
gate bites - a good candidate for a live check.

Beyond that gate, air weather reaches combat as `BM_WEATHER` (above) and the bombing raid's
bomber side the same way. Nothing weather-related was found in the mission machinery itself.

## 5. The defines - all 56 read, and why a `GetDefines` scan finds none of them

`defines.lua`'s `weather` block is `CDefines +0xEC`, 56 entries, `definesMap.py --block
weather`. **A scan for `mov reg, [CDefines + 0xEC]` outside `CDefines::Load` finds no
readers**, which looks exactly like a dead block and is not.
**`CWeatherManager::InitialiseWeatherState` (`0xB54F0`)** copies **49 of the 56** into
individual globals at startup, one
`mov ecx,[eax+0xEC]; mov edx,[ecx+N]; mov [global],edx` per define, and every consumer reads
the global. This is the same blind spot as trap 8, one step further out: it is not that
`GetDefines` is inlined, it is that the block is never read again after startup.

*(Corrected 2026-10-01. This originally gave the cache its own entry point at `0xB5670`
and named it `CacheWeatherDefines`, with the countdown-vector fill at `0xB54F0` as a
separate function - the naval survey in the same wave read it the other way round. The
bytes settle it: `retsBefore` finds **no `ret` at all** between `0x4B54F0` and the first
cache write at `0x4B58A7`, the first `int3` after `0x4B54F0` is at `0x4B59BC`, and
`0x4B5670` is not a function start - it decodes as garbage, and `buildFindings` agrees.
It is **one** function that does both, which is why `CWeatherManager::Tick` calls it when
the per-zone vector is empty and the defines are cached as a side effect of the first
call. See `FINDINGS-navaldetection.md`.)*

The seven it does not cache - the six `GFX_*` limits and `INITIAL_SIMULATION_HOURS_AHEAD` -
are read straight off the block, at `0xB4400` and `0x25C820`.

Every one of the 56 has at least one reader:

| define | read by |
| --- | --- |
| `PRESSURE*`, `MAXHUMIDITY`, `MINHUMIDITY`, `MAXFROMEACHPRESSURE`, `LOWPRESSURE*`, `TEMPERATURECHANGESPEED`, `CLOUDCOVERAGETEMPERATUREDROP`, `HOURLY*` | the simulation only, inside `0xB2xxx`-`0xB6xxx` |
| `*ATTRITIONTHRESHOLD` (3) | `CWeather::AttritionEffect` -> `GetProvinceAttrition` |
| `LAND*` (6) | `CWeather::LandCombatEffect` -> `BM_WEATHER` on land |
| `AIR*` (7) | `CWeather::AirCombatEffect` -> `BM_WEATHER` on a wing |
| `BOMB*` (7) | `CWeather::BombCombatEffect` -> `BM_WEATHER` on a bomber |
| `NAVALWINDSPEEDMODIFIER`, `NAVALRAINMODIFIER` | `CNavalCombatant::ApplyCombatModifiers` **and** `CNavalCombat::Tick` |
| `MUDDYNESSMOVEMENTMODIFIER`, `COLDMOVEMENTMODIFIER`, `WEATHERMOVEMENTDELAY` | `CWeather::MovementEffect` and `CWeatherFront::Tick` |
| `MUDDYNESSSUPPLYTAXMODIFIER` | `SupplyLoss` (`0x9DE80`) |
| `SPOTTINGCLOUDMODIFIER`, `SPOTTINGRAINMODIFIER` | `ShouldStartNavalCombat` (`0x31840`) |
| `ALLOWEDTOFLYTHRESHOLD` | `CAir::CanMoveTo` (`0x1D0ED0`) |
| `FIRINGRANGEMODIFIER` | `CSubUnit::FiringRange` (`0x1AC470`) and an inlined copy at `0x1672C0` |
| `GFX_*` (6) | `CWeather::GraphicName` (`0xB4400`) only - cosmetic |
| `INITIAL_SIMULATION_HOURS_AHEAD` | the new-game setup loop at `0x25C820`, which runs the whole weather tick that many times before the game starts |

### The one dead define

`definesMap.py --lua` on the mod's own file:

```
== weather  engine 56, file 57
   file defines GFX_RAINIMPACT_LIMIT - the engine never reads it
```

**`GFX_RAINIMPACT_LIMIT = 0.1` does nothing.** The engine's six graphics limits are
`GFX_RAIN_LIMIT`, `GFX_SNOW_LIMIT`, `GFX_STORM_LIMIT`, `GFX_SNOW_STORM_LIMIT`,
`GFX_PARTIAL_CLOUD_LIMIT` and `GFX_CLOUD_LIMIT`; there is no seventh. Vanilla TFH's
`defines.lua` carries the same dead line, so this is inherited, not introduced.

## The other consumers, briefly

**Supply losses, not supply capacity.** `0x9DD00` (`SupplyCapacity`) and `0x9DE80`
(`SupplyLoss`) **abut with no padding** - `0x9DD00` ends at `0x9DE7D` with `ret 8` and
`0x9DE80` opens its own prologue - and the muddyness term is in the second one. Reading from
`0x9DD00` puts it in the wrong function, which is trap 2 doing its job:

```
out = SUPPLY_TAX                                     # CDefines military +0x34
if (province->owner_id == province->controller_id): out /= 2
mud = (frozen == 0) ? muddyness * MUDDYNESSSUPPLYTAXMODIFIER/1000 : 0
out = out * (1000 + mud + <a terrain/partisan term>) / 1000
out += country->+0xDF8->+0xC
if (out < 0) out = 0
```

So **mud raises supply losses** and frozen ground does not. BlackICE has this at `0.9` against
vanilla TFH's `0.25`, so a fully muddy province loses up to `1.9x` the supply tax where
vanilla loses `1.25x`.

**Attrition.** `GetProvinceAttrition` (`0xA0990`) calls `CWeather::AttritionEffect` (`0xB3F30`)
at `0xA0A60` with the province's weather and the unit's owner tag. The effect is 1.000 above
`HIGHTEMPERATUREATTRITIONTHRESHOLD` (scaled by `1000 - JUNGLE_EFFECTS` in positive-humidity
terrain), 1.000 below `LOWTEMPERATUREATTRITIONTHRESHOLD` (scaled by `1000 - WINTER_EFFECTS`), a
flat 1.000 above `WINDATTRITIONTHRESHOLD`, and 0 otherwise - three thresholds and no gradient.
Where the province's temperature is negative the leader/HQ effect of type 6 (`0x1D1120`) is
added to it, and the sum is floored at 0.

**A naval battle breaking off.** `CNavalCombat::Tick` (`0x17BA00`), after delegating to the
base tick, at `0x17BA3D`:

```
chance = ( duration*1000
         + windspeed * NAVALWINDSPEEDMODIFIER/1000
         + precipitation * NAVALRAINMODIFIER/1000
         + 10000
         + (province->is_night ? 11000 : 1000) ) / 1000
if (duration > 2 && rand()%1000 < chance):  every ship on both sides tries to leave
```

**Naval spotting.** `ShouldStartNavalCombat` (`0x31840`) at `0x3200D` scales its spotting
figure by `(1000 - cloud_coverage x SPOTTINGCLOUDMODIFIER/1000 - precipitation x
SPOTTINGRAINMODIFIER/1000)/1000`. Both modifiers are `0.2` in BlackICE, so the worst weather
hides 40 % of a fleet's detectability.

**Firing range.** `CSubUnit::FiringRange` (`0x1AC470`) takes the definition's range (`+0x14C`)
and, where the sub unit has a parent `CUnit`, scales it by `(1000 +
province->precipitation x FIRINGRANGEMODIFIER/1000)/1000`. `FIRINGRANGEMODIFIER` is `-0.5`, so
heavy rain halves range. The same maths is inlined in the naval combat code at `0x1672C0`.

## What was not established

- **No live reading.** Everything here is off the bytes; nothing was checked against a running
  game. In particular: what `cloud_coverage` and `muddyness` actually reach in play, which is
  what decides whether the air gate and the movement floor bite at all.
- The exact interpolation `CWeather::Update` uses for humidity, precipitation and
  cloud_coverage. The muddyness and frozen branches were read; the three above them were only
  traced far enough to see which terrain fields feed them.
- `CWeatherManager +0x14`, the flag that stops fronts being freed - nothing was found that
  sets it.
- **`CWeatherFront`'s movement** (the second half of `0xB4620`, and `0xB42B0` which it calls) -
  where a front goes next, and how it writes windspeed, precipitation and cloud_coverage onto
  the provinces it covers. This is the biggest remaining gap: it is the *source* of the numbers
  every consumer above reads.
- Which of slot 35's 45 call sites are the air mission paths.
- Whether `0x33D460` is the movement tooltip.
- `CProvinceTemplate +0x13D`, the flag `UpdateProvinceWeatherRange` tests instead of
  `+0x22 is_land`.
- The non-weather terms of `CUnit::MovementSpeedModifier` were read once each and are
  summarised, not confirmed.

## Two existing entries this contradicts

Neither is redefined here; both want a second look.

1. **`CLASSES.md`, *Supply and fuel consumption*** says the command-reach maths uses "the
   distance between the unit's province and the HQ's (province `+0x2C` and `+0x30`, wrapped by
   `CMap + 0x2A74`)". `CProvince +0x2C` takes a **byte** store (`mov byte ptr [esi+0x2c], al`
   at `0x27B204`) and `+0x30` holds a small enumeration compared against 1, 3 and 4 (`0xB22EC`,
   `0xB2306`, `0xB2331`), so they cannot also be a pair of coordinates. `IsNight` (`0xA7390`)
   takes its x position from **`CProvinceTemplate +0x64`** and does divide it by `CMap +0x2A74`,
   so the `CMap +0x2A74` half of that note is right and the province offsets look like they
   belong on the template.

2. **`FINDINGS-combat.md`, *The modifier list is land only*** and its nine ids with no call
   site. Seven of the nine are pushed through `CSubUnit::AddCombatModifier` (`0x1AC300`), and
   `combatModifierSites.py` should scan both adders. The conclusion that `CUnit +0xDC` is never
   filled for air or naval stands; the conclusion that those modifiers do not exist does not.

Also worth a note rather than a contradiction: `project.json` types `CGameState +0xAEC` as
`void* weather`. It is a `CWeatherManager` **embedded by value** - `CGameState::CGameState`
writes the vftable into it at `0x27D1BD`.

## A new trap for the folder's list

**A single linear `capstone` sweep of the whole 9.6 MB `.text` silently loses instructions.**
My first scan for readers of `[CDefines+0xEC]` was a linear disassembly from the start of
`.text`; it reported 77 sites and *zero* onward reads, and the same sweep could not even find
`mov dword ptr [ebx+0xaec], 0x15cf5c0` in `CGameState::CGameState`, an instruction I had
already seen with `findRefs.py`. The sweep desynchronises on embedded data and never
resynchronises usefully. `fieldchain.py --field 0xAEC` - which byte-searches for the disp32 and
decodes a short window at each hit - found all 18 sites including the one in `RunHourlyPass`
that is the whole answer to "how often does weather change". **Byte-search then decode locally;
never trust a whole-section linear sweep for a negative result.** `scratchpad/weather/defreaders.py`
is the broken version and `defreaders2.py` the corrected one, if the contrast is worth keeping.

Related, and already in the traps list but it bit here too: `image.functionStart()` walked from
`0x9DEDD` back into `SupplyCapacity` across the `ret 8` at `0x9DE7D`, which would have put the
muddyness supply term in the wrong function. Checking for `int3` padding is what caught it.
