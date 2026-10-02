# CWeatherFront — the source of every weather number

## In one paragraph

A low pressure zone named in `default.map` spawns a `CWeatherFront` every day or so. The front is a **blob of provinces with a compass heading**. Every `WEATHERMOVEMENTDELAY` hours it throws away the provinces it is standing on and recruits their neighbours — but only the neighbours whose *bearing* lies inside an arc around its heading, and only where the province it is leaving still has low pressure. As each province is left behind it hands its humidity, its low pressure, its windspeed and its temperature to the neighbours it recruited. That is the whole of the movement. **Nothing writes precipitation or cloud coverage directly**: `CWeather::Update` manufactures cloud from the humidity-to-temperature ratio an hour at a time, and precipitation from the cloud. So a front is a travelling parcel of humidity and low pressure, and rain is a local consequence of it.

## 1. `CWeatherFront::Tick` (`0xB4620`), all of it

`bool Tick(CWeatherFront* f@[ebp+8])`, `ret 4`. Not a `thiscall` — the front comes in on the stack.

### The hour that is not a move

```
--f->move_countdown                                 ; f+0x24
if (f->move_countdown > 0) {
    for (p in f->provinces) p->weather_front = f;   ; CProvince+0x14, re-stamped
    return true;
}
```

`CWeatherManager::Tick` clears `CProvince+0x14` on **every** province each hour (`0xB5C7C`, through `g_CCurrentGameState+0xB8C`), so every front has to write itself back onto its own provinces every hour or they would lose their front after one tick. That is all a non-move hour does.

### Setting up a move

```
count = f->provinces_count                   ; f+0x14
f->move_countdown = WEATHERMOVEMENTDELAY / 1000
arc = 200                                    ; [0x1686F80], a compiled-in literal
if (count < 3)   arc += 150                  ; [0x1687000]
if (count > 30)  arc = arc * 1000 / 2000     ; halve
if (count > 100) arc = arc * 1000 / 2000     ; halve again
f->direction += f->rotation                  ; f+0x08 += f+0x20
f->rotation   = f->rotation * 800 / 1000     ; [0x1687028]
if (count < 1) return false                  ; an empty front dies
if (count < 4 && MapDistance(map, f->provinces[0]->id, f->home->id) > 4000)
    return false                             ; a small front too far from home dies
```

**`arc` is an angular half-width in thousandths of a full turn.** A fresh front (`count < 3`) gets ±0.350 = ±126° and can go almost anywhere; a settled front ±0.200 = ±72°; over 30 provinces ±0.100; over 100 provinces ±0.050 = ±18°. **A big front is directional, a small one wanders.** None of the four numbers is a define — all are `(int)floor(N.5f)` statics, each with exactly one reader in the whole image.

`MapDistance` (`0x92030`, `(CMap* m@stack, idA@EAX, idB@EDX) -> int`, `ret 4`) is `isqrt(16 * (dx² + dy²))` over `map+0x2A60[id]` coordinates `+0x2C`/`+0x30`, with dx wrapped by the map width at `map+0x2A74`. So **it answers four times the pixel distance**, and `> 4000` means "more than 1000 map pixels from home".

### The move

```
local = copy of f->provinces                 ; and each p->weather_front = f on the way
clear f->provinces                           ; the front now covers nothing
for (p in local) {
    if (p->weather.pressure >= PRESSUREDEFAULT) continue                        ; (a)
    recruited = {}; spreadHere = false
    for (edge in p->path_node_ptr->edges) {                  ; CProvinceTemplate+0x90
        n = map->provinces[edge->to_province]
        if (n->weather_front != 0) continue                                     ; (b)
        if (n->weather.pressure - PRESSURETHRESHOLD > p->weather.pressure) continue ; (c)
        if (f->provinces_count > 100 && spreadHere) continue                    ; (d)
        if (!IsAngleWithinArc(f->direction, edge->bearing, arc)) continue       ; (e)
        spreadHere = true
        recruited += &n->weather
        n->weather_front = f
        f->provinces += n                                    ; the front grows here
    }
    SpreadWeather(&p->weather, &recruited)                   ; 0xB42B0
}
for (p in local) p->weather_front = 0        ; the front LEAVES everywhere it was
return f->provinces_count > 0
```

**(a) `PRESSUREDEFAULT` is the real limiter.** A province the front stands on spreads nothing once its own pressure has recovered to `PRESSUREDEFAULT` (1013 in BlackICE). Pressure recovers by `PRESSURESTEP` an hour, so a front dies out as the low it carries fills in.

**(b)** A province already carrying any front is never recruited. Since the whole footprint was re-stamped just above, **a front never re-occupies a province it stands on**, and two fronts never overlap; whichever ticks first wins a contested province.

**(c) `PRESSURETHRESHOLD` cannot fire at BlackICE's numbers.** The test needs `n.pressure − 300.000 > p.pressure`, and `CWeather::Clamp` holds every pressure inside `[PRESSUREMIN, PRESSUREMAX]` = `[870, 1090]`, a span of 220. `PRESSURETHRESHOLD` has **exactly one reader in the image** (`0xB4890`), so this is the whole of its effect: at 300 it is dead; it would begin to bite below 220.

**(d)** Over 100 provinces, each province the front leaves may recruit **one** neighbour only. That is what stops a front swallowing a continent.

**(e)** `IsAngleWithinArc` is `0xB4490`:

```
bool IsAngleWithinArc(int value@[ebp+8], int centre@[ebp+0xC], int half@[ebp+0x10]) // bare ret
    hi = (centre + half) % 1000
    lo = (centre - half) % 1000
    if (lo < hi) return lo <= value && value <= hi
    else         return value >= lo || value <= hi        // wrapped
```

A circle of 1000 units. `edge->bearing` is `ProvinceEdge+0x10`, the last unnamed field of the 20-byte edge record.

### What it adds up to

A front **steps forward**: it abandons its whole footprint and takes the ring of neighbours in front of it. Its size is self-regulating — a province with no eligible neighbour contributes nothing, so a front shrinks over water it has crossed and dies when it recruits nothing. `rotation` is a **one-off curvature, not a spin**: it starts at ±0.010 and is multiplied by 0.800 every move, so the total heading change over a front's life is bounded by 0.010/(1−0.8) = 0.050 (18°), and integer truncation zeroes it after about eleven moves (~22 game hours). After that the front travels in a straight line. The sign comes from the hemisphere (§5).

## 2. `SpreadWeather` (`0xB42B0`) — the source of every number

`void SpreadWeather(CWeather* from@[ebp+8], CList<CWeather*>* to@[ebp+0xC])`, `ret 8`. Called once per province the front is leaving, with the provinces that province just recruited. All four constants are compiled-in literals, not defines.

```
rain = from->humidity * 980 / 1000                 ; [0x168703C] = 980
from->humidity -= rain / 5                         ; the source keeps 4/5 of what it gave
for (t in to) {
    t->humidity += rain                            ; the WHOLE of it, per neighbour

    windDelta = (from->windspeed - t->windspeed) * 970 / 1000      ; [0x1686FCC] = 970
    dp = t->pressure - from->pressure
    if (dp > 0) {                                  ; the neighbour is the higher pressure
        t->pressure -= dp * 980 / 1000             ; [0x168703C] again: pulled almost flat
        windDelta = max(dp * 250 / 1000, windDelta) ; [0x1686F98] = 250
    }
    t->windspeed += windDelta

    dt = (from->temperature - t->temperature) * 950 / 1000         ; [0x1687068] = 950
    t->temperature += clamp(dt, -10000, +10000)
}
```

**Humidity is created, not moved.** Each recruited neighbour gains 0.980 of the source's humidity *on top of its own*, while the source loses only 0.196 of it — once, no matter how many neighbours it fed. A front is a humidity pump. The only things that take humidity away are rain (§3) and `MAXHUMIDITY`.

**Windspeed is the pressure gradient.** `0.250 × (neighbour pressure − source pressure)`, or the decayed advection of the source's own wind, whichever is larger. A fresh low at `PRESSUREMIN` (870) against 1013 air gives 0.250 × 143 = 35.750 — exactly the range a real savegame shows (max 35.820 over 2092 provinces). Where there is **no** front, `CWeather::Update` decays windspeed by `× 750/1000` an hour, so wind dies within a few hours behind a front.

**The low travels with the front.** `t->pressure -= 0.980 × (t->pressure − from->pressure)` drags each new province almost all the way to the source's pressure. Nothing else lowers a province's pressure except the one-off drop when a front is born.

**Nothing here writes precipitation, cloud coverage, muddyness or frozen.** All four are produced inside `CWeather::Update` from humidity, temperature and the terrain. **That is the headline: a front's only outputs are humidity, pressure, windspeed and temperature.** `SpreadWeather` does not call `CWeather::Clamp`, so all four can be out of range until the province's own `Update` runs later the same hour.

## 3. The full `CWeatherFront` layout

`operator new(0x28)` at `0xB5F02`, so the object is **40 bytes and complete**. Read off the constructor `0xB44E0`, destructor `0xB45D0`, `SaveContents` `0xB4A20`, `LoadKey` `0xB4C30` and the Tick together.

| Offset | Name | Save key | Where it comes from |
| --- | --- | --- | --- |
| +0x00 | vftable | — | `0x15C08B8`, 13 slots |
| +0x04 | CPersistent's token word | — | `none` (397) |
| +0x08 | `direction` | `direction` | runtime: the per-zone heading cache, `CWeatherManager+0x28` |
| +0x0C | `provinces` head | `provinces` | runtime; starts as just `home` |
| +0x10 | `provinces` tail | — | |
| +0x14 | `provinces` count | — | the front's size, and its liveness test |
| +0x18 | the `CList`'s trailing byte | — | zeroed by the constructor |
| +0x1C | `home` | `home` | **`default.map`'s `low_pressure_zones`** — the only field that is |
| +0x20 | `rotation` | `rotation` | runtime: `±10` (`[0x1686FC8]`), sign by hemisphere |
| +0x24 | `move_countdown` | `speed` | runtime: `WEATHERMOVEMENTDELAY / 1000` |

**Exactly one field comes out of `default.map`, and it is the home province id.** Everything else is runtime, and all five are save keys — names from the save-token table: `direction` 76, `rotation` 382, `speed` 109, `home` 596, `provinces` 476. `project.json` already carries `home` at +0x1C and `move_countdown` at +0x24 with the same meanings; the rest are new, nothing conflicts.

### The constructor, and what being born costs the map

`CWeatherFront::CWeatherFront(this@[ebp+8], home@[ebp+0xC], direction@[ebp+0x10], rotation@[ebp+0x14])`, `ret 0x10`:

```
+0x04 = none; +0x00 = vftable; the CList and +0x20 zeroed
provinces = { home }                        ; the front starts one province wide
+0x20 = rotation; +0x24 = 0; +0x08 = direction; +0x1C = home
drop  = LOWPRESSUREBASE + 1000 * (Random() % (LOWPRESSUREOFFSET / 1000))
home->weather.pressure -= drop
CWeather::Clamp(&home->weather)
```

With `LOWPRESSUREBASE = 100` and `LOWPRESSUREOFFSET = 100` the drop is 100.000–199.000 hPa. From 1013 that is 814–913 and `PRESSUREMIN` is 870, so **roughly three new lows in five are clamped straight onto `PRESSUREMIN`**. Neither define is read anywhere else in the image.

**`LOWPRESSUREOFFSET` must stay at or above 1.** `idiv edi` at `0xB4595` with `edi = LOWPRESSUREOFFSET / 1000`, no zero check. Below 1.0 in `defines.lua` that is a division by zero the first time a front is created — inside the first game hour.

`+0x24` starting at 0 means the first `Tick` decrements it to −1 and the front moves immediately. The destructor (`0xB45D0`, `this` in EDI, reached through slot 0 `0xB1FC0`) clears `CProvince+0x14` on every covered province and frees the list.

## 4. `CWeather::Update` (`0xB2590`): the three branches that were unread

`this` in EDI, no stack arguments, bare `ret`. Runs once an hour per province **on a TBB worker thread**. `land` below is `CProvinceTemplate+0x22` through `CProvince+0xD4`.

### Step 0, the front — and a correction

```
if (province->weather_front == 0) { windspeed = windspeed * 750 / 1000; front = 0 }
else                               front = province->weather_front
```

**`[0x1686F3C]` is 750, not 980.** `project.json`'s comment on `CWeather+0x10` said windspeed decays by 0.980 an hour with no front, and so did `FINDINGS-weather.md`. The bytes at `0xB25B1` are `f7 2d 3c 6f a8 01` = `imul dword ptr [0x1a86f3c]`, and `[0x1686F3C]` is `floor(750.5) = 750`, with exactly two references in the image: this read and its CRT initialiser at `0xCB391B`. **0.980 is `[0x168703C]`, the humidity/pressure transfer factor in `SpreadWeather` — a different global.** *(Both the field comment and `FINDINGS-weather.md` were corrected on 2026-10-01.)*

### Humidity

```
t = max(temperature, 0)
if (land) cap = terrain->humidity * 5           ; CTerrain+0x60, ×5000/1000
else    { cap = 5000; t += 10000 }              ; the sea evaporates as if 10 C warmer
if (humidity >= 1000) t = t * 1000 / humidity   ; saturation: the wetter, the slower
pNorm = (pressure - PRESSUREMIN) * 1000 / (PRESSUREMAX - PRESSUREMIN)    ; 0..1000
humidity += (1000 - pNorm) * t / 1000 * cap / 1000
```

The `1000` in `1000 − pNorm` is `[0x130CAEC]` and is **not** a define: `CWeatherManager::InitialiseWeatherState` (`0xB54F0`) copies the weather block only as far as `+0xC0`, and **nothing in the whole image writes `0x130CAEC`** — it has one reference, the read at `0xB2685`, and the file initialises it to `0x3E8`. So it is a hardcoded 1.000 and no define moves the pressure→humidity coupling.

Humidity grows **fastest where pressure is lowest** (under a front), grows with temperature, saturates as it rises, and is multiplied by five times the terrain's own `humidity`. In BlackICE every desert declares `humidity = -50.0`, so `cap` = −250.000 and the term is strongly negative: **deserts actively dry out** and pin at `MINHUMIDITY` = 0. Jungle's 0.8 gives `cap` = 4.000.

### Cloud coverage

```
if (temperature > 0) ratio = (humidity * 1000 / temperature) * 10
else                 ratio = humidity
threshold = 50000 - terrain->precipitation - (land ? 30000 : 0)      ; CTerrain+0x64
if (ratio >= threshold && humidity > 0) cloud += front ? 100 : 200   ; 0x1686F5C / 0x1686FA0
else                                    cloud -= 50                  ; 0x1686FE8
```

`ratio` is relative humidity in all but name. `50.000 − CTerrain+0x64` is a **threshold**, not an interpolation target — `FINDINGS-weather.md` had the right field and the wrong shape. A high terrain `precipitation` lowers the bar; land lowers it by a further 30.000 outright. The `front ? 100 : 200` reads backwards and is not (`cmp dword ptr [edi+0x28], 0; je 0x4b2737` at `0xB2727`): a province **with** a front gains the *smaller* 0.100. The reason is the next step.

### Precipitation

```
precipitation = 0
thr = land ? (front ? 250 : 0) : 500             ; 500 = [0x1686F40], halved for land
if (cloud > thr) precipitation = 2000 * (cloud - thr) / 1000      ; floor(2000.5) inline
if (front == 0) {
    cloud     -= precipitation * 200 / 1000      ; [0x1686F30]
    humidity  -= precipitation * 10000 / 1000    ; i.e. 10 × precipitation
}
```

**`precipitation = 2.000 × (cloud_coverage − threshold)`**, then clamped to `[0, 1.000]`. **Verified against a savegame on 2092 provinces out of 2092** (§6).

The asymmetry now makes sense: **without a front the system is self-limiting** — rain burns off a fifth of its own cloud and ten times its own volume of humidity every hour, so the low thresholds are safe. **With a front, rain consumes neither**, and the front keeps topping humidity up: that is why a front means days of rain and clear air means a shower. The `2.000` is an inline `(int)floor(2000.5f)` at `0xB2786` — a literal, not even a cached static, so nothing in `defines.lua` moves it.

### Muddyness and frozen, corrected

Muddyness is as recorded: `infra = clamp(prov+0x114->+0x60 × (1000 + +0x68 + +0x70) / 1000, 10, 1000)`, then `muddyness += (1000 − infra) × 50/1000` while `precipitation > 0.500` or while frozen ground sits above −5 C, else `muddyness -= max(infra × 5/1000, 2)`. Above 15 C it loses a further 5 an hour; below −5 C it is zeroed.

**The frozen branch is richer than "rises by `HOURLYFROZENINCREASE` below −5 C."** Read at `0xB2952`–`0xB29DA`, four cases in order:

| Condition | Effect |
| --- | --- |
| `temperature < -5 C` **and** `precipitation > 0.250` | `frozen += HOURLYFROZENINCREASE` (snowfall) |
| else `temperature < -10 C` and `frozen < 0.500` | `frozen += 0.200 × HOURLYFROZENINCREASE` |
| else `temperature < -2 C` and `frozen < 0.250` | `frozen += 0.100 × HOURLYFROZENINCREASE` |
| else `temperature > 0 C` | `frozen -= HOURLYTHAW` |

So hard ground only builds past 0.500 where it is snowing, and between −2 C and −10 C it creeps to 0.250 and stops. The 0.200/0.100 are inline `floor(200.5)`/`floor(100.5)`; the ceilings are `[0x1686F40]` = 500 and `[0x1686F74]` = 250.

### Temperature, and a define whose sign gates dead code

```
step = land ? 2 : 1
target = CWeather::BaseTemperature(this)                 ; 0xB22E0
if (target > temperature + 10000) step *= 10
else if (target < temperature - 10000) step *= 10
else if (target < temperature -  5000) step *= 5
if (TEMPERATURECHANGESPEED > 0 && province->climate == 3) step *= 10
if (TEMPERATURECHANGESPEED < 0 && province->climate == 5) step *= 2
delta = step * 1000 * TEMPERATURECHANGESPEED / 1000
temperature += (temperature > target) ? -delta : +delta
```

Both climate multipliers are gated on the **sign of `TEMPERATURECHANGESPEED`** (`0xB2A30`, `0xB2A56`; `[ebp-8]` holds it and nothing writes it in between). It is 0.075 in BlackICE and positive in vanilla, so **the climate-5 doubling is unreachable dead code**. The direction of the step is chosen separately at `0xB2A92`, so the sign is not doing double duty.

### Pressure, last

```
if (pressure < PRESSUREDEFAULT && (land || province->weather_front == 0))
    pressure += PRESSURESTEP
CWeather::Clamp(this)
```

Pressure only ever drifts **up** toward `PRESSUREDEFAULT`, never down — and at sea a front holds its low open by suppressing even that.

### `CWeather::Clamp` (`0xB2210`), for the ranges

`this` in EAX, bare `ret`. windspeed `[0, 200.000]`; temperature `[−50.000, +50.000]`; humidity `[MINHUMIDITY, MAXHUMIDITY]`; **muddyness, frozen, precipitation and cloud coverage all `[0, 1.000]`**; pressure `[PRESSUREMIN, PRESSUREMAX]`. So `ALLOWEDTOFLYTHRESHOLD` and the cloud/precipitation `GFX_*` limits are compared against a 0..1 figure while `GFX_STORM_LIMIT`/`GFX_SNOW_STORM_LIMIT` are compared against a 0..200 one.

## 5. `CWeatherManager`: the parts that were open

### `+0x14` is dead code

`0xB5CD7` tests a byte at `this+0x14`; when set, a spent front's **list node is marked** (`node+0xC = 1`) instead of unlinked, while the front object is deleted through its vftable either way.

The manager is embedded at `CGameState+0xAEC`, so the byte is `CGameState+0xB00`. There are **eight instructions in the whole image touching `[reg+0xB00]`**, and only one is a write to a `CGameState`: `mov byte ptr [ebx+0xb00], 0` at `0x27D1D9`, inside `CGameState::CGameState`, sixteen bytes after it writes the manager's vftable at `+0xAEC`. (`0xC9470` is the same displacement on an unrelated object — a `std::string` being initialised.) **Nothing ever sets it**, so the marking path never runs. Just as well: the marked node is left with `node->data` pointing at freed memory and the walker at `0xB5CA4` dereferences it unconditionally, so the next hour would tick a deleted front. **Dead code, and a use-after-free if it were reached.** No define, save key or script reaches it.

### Two per-zone vectors, not one

`CWeatherManager::InitialiseWeatherState` (`0xB54F0`) — the same function that copies the weather define block into individual globals — pushes one zero onto **two** vectors per low pressure zone:

| Offset | Holds |
| --- | --- |
| +0x18 / +0x1C / +0x20 | the per-zone **cooldown**, decremented every hour at `0xB5A65` |
| +0x28 / +0x2C / +0x30 | the per-zone **heading cache** |

Only `+0x18` was recorded. `+0x28` is what decides which way a new front sets off, and it explains the savegame. `0xB59C0` (`this` in EAX, bare `ret`, one caller at `0x28256B`) resets both: every `+0x28` entry to `[0x168701C]` — one reference in the image, that read, and past the end of `.data`'s raw bytes, so **zero**, meaning "pick a fresh random heading" — and every cooldown to 0. `InitialiseWeatherState` clears only `+0x18` before refilling both, so if it ever ran twice `+0x28` would double; it cannot, because `Tick` calls it only while `+0x18` is empty.

### `CWeatherManager::CreateFront` (`0xB5D80`), and `default.map`'s second column

`low_pressure_zones` is written `provinceId = number`; `CMap+0x21D8` is a vector of **8-byte** records, and the number is a **bitmask over the province's climate zone**:

```
if (province->climate == 0) ComputeProvinceClimate(province)
if (!(zone->mask & (1 << province->climate))) continue       ; 0xB5E01-0xB5E0A
```

`ComputeProvinceClimate` (`0xA81A0`) answers 1..5, so the mask's **bit 0 is wasted and bit 5 is needed for climate 5**. `31` = bits 0..4 therefore covers climates 1–4 and **not 5**; `62` or `63` would cover all five. Thirteen of BlackICE's nineteen zones use 31, as do fourteen of vanilla's eighteen — so this is a **vanilla** trait, not a BlackICE mistake, but the "all weather" zones are silent in one of five bands. BlackICE's own deltas against vanilla: `11438` (med.) 31→16, plus a new `10372 = 31`.

**`ComputeProvinceClimate`'s 1..5 is a season, not a latitude band.** It picks one of six locals by the day of the year (from `g_CCurrentGameState+0xBDC`, with a latitude-dependent offset), and the six are `{1,2,3,4,4,5}` where `CProvinceTemplate+0xA2` is set and `{4,4,5,1,2,3}` where clear — **the same list rotated by three, i.e. half a year**. `+0xA2` is written at `0x8FED8` as `template->+0x68 >= CMap->+0x2A78 / 2`: the province's y against half the map height, i.e. the **southern hemisphere flag**. That is also the flag `CreateFront` uses to negate a new front's `rotation`.

And it is cached: all six callers call it only where `CProvince+0x30` is 0, **nothing in the image zeroes `+0x30`**, and `climate` is not one of the 22 keys `CProvince::SaveContents` writes. So a province's season is worked out once from whatever date it is when its weather is first touched — inside the first game hour, or the `INITIAL_SIMULATION_HOURS_AHEAD` pre-roll — and then **frozen for the session, changing only across a save and reload**. That makes the `low_pressure_zones` masks a static per-zone on/off switch rather than the seasonal gate they look like. *(Read, not watched: it rests on finding no writer of `+0x30`, on the save keys, and on the `!= 0` guard at all six call sites.)*

The rest of `CreateFront`:

```
for (zone in map->low_pressure_zones) {
    if (!(zone.mask & (1 << climate(zone.province)))) continue      ; index NOT advanced
    if (zone.province->weather_front) { ++i; continue }
    if (manager->cooldown[i] > 0)     { ++i; continue }
    manager->cooldown[i] = 0
    if (count of live fronts with home == zone.province
        >= MAXFROMEACHPRESSURE / 1000) { ++i; continue }
    d = manager->heading[i]
    if (d == 0) d = Random() % 1000                                ; 0x6A2FD0
    else      { d += 1000000 / MAXFROMEACHPRESSURE; if (d > 1000) d -= 1000; }
    manager->heading[i] = d
    manager->cooldown[i] = 24 + Random() % 48                      ; hours
    rot = 10; if (zone.province->path_node_ptr->+0xA2) rot = -rot
    return new CWeatherFront(zone.province, d, rot)
}
return 0
```

**`MAXFROMEACHPRESSURE` does two jobs.** `/1000` it is the number of fronts one zone may have alive; and `1000000 / MAXFROMEACHPRESSURE` is the angular step between successive fronts from that zone. At BlackICE's 8: 8 fronts and a step of 125 — **one eighth of the compass each**, so a zone's fronts fan out evenly. `CWeatherManager::Tick` uses the same `/1000` for the global cap (`fronts_count < zoneCount × MAXFROMEACHPRESSURE / 1000`), so BlackICE's ceiling is 19 × 8 = **152 fronts**. The zone cooldown, `24 + Random() % 48` hours, is **hardcoded** — no define touches it.

`0x6A2FD0` (already named `RandomThousandths` in `project.json`, which my reading agrees with) is `MT19937Next() % 1000` written through an out pointer — that is what settles that headings are **thousandths of a full turn**. Note `CreateFront` passes the address of its own loop index to it, so the index is clobbered; harmless, because the function returns immediately afterwards.

### `PropagateHighPressure` (`0xB6050`) — the outline corrected

`this` = the seed `CMapProvince` in **ECX**, `ret` (no arguments). Called once per id on `CMap+0x21C8` from `CWeatherManager::Tick` at `0xB5A9E`.

```
for (p in map->provinces) p->weather_pressure_distance = 99999      ; CProvince+0x10
seed->weather.pressure = PRESSUREMAX                                ; set outright
seed->weather_pressure_distance = 0
queue = { seed }
while (queue) {
    cur = pop_front(queue); d0 = cur->weather_pressure_distance
    for (edge in cur->path_node_ptr->edges) {
        n = map->provinces[edge->to_province]
        d = n->path_node_ptr->+0x24 + d0                  ; the traversal cost, not hops
        if (n->weather_pressure_distance <= d) continue
        target = PRESSUREMAX - d * PRESSUREREDUCTION      ; see below
        if (target <= n->weather.pressure) continue
        n->weather.pressure += PRESSUREPROPAGATION        ; ONE step, not set to target
        n->weather_pressure_distance = d
        if (target > 0) push(queue, n)
    }
}
```

Three corrections, all from `0xB6155`–`0xB619D`:

- **The distance is not hop count.** It accumulates `CProvinceTemplate+0x24`, the same per-province traversal cost `CSupply::SpreadFromDepot` uses. Mountains and bad terrain cost a high pressure zone reach, exactly as they cost supply.
- **`target = PRESSUREMAX − d × PRESSUREREDUCTION`, not `− d × PRESSUREREDUCTION/1000`.** The code is `imul eax,eax,0x3e8` (d×1000) then `imul [PRESSUREREDUCTION]` then `/1000`, which cancels — both are already thousandths. At `PRESSUREREDUCTION = 2` the walk reaches `target <= 0` at an accumulated cost of 545 and stops.
- The seed is **set** to `PRESSUREMAX`; everything else is nudged by one `PRESSUREPROPAGATION` per hour, so a province under a high climbs toward its target at 10.000 hPa/hour rather than jumping.

Confirmed otherwise as outlined. The cost: **the 99999 reset is a pass over all ~5000 provinces, once per high pressure zone, every hour** — nineteen highs is about 95,000 stores an hour before the walk starts.

## 6. `CProvince+0x10` and `+0x14` (the optional item)

- **`+0x10`** is used by nothing but `PropagateHighPressure`: 99999 for every province at the top of each propagation, then the accumulated cost as the walk reaches each one. Pure scratch; not a save key, no reader outside `0xB6050`.
- **`+0x14`** is the front over the province. Three writers: `CWeatherManager::Tick` zeroes it on every province each hour (`0xB5C7C`); `CWeatherFront::Tick` writes the front onto its own provinces (quiet hour and as it recruits) and clears it on everything it leaves; the front's destructor clears it on everything it covered.
- **`CWeather+0x28`** is a *copy* of `+0x14`, taken at the top of `CWeather::Update` (`0xB25D1`) so the rest of that function — on a TBB worker thread — reads one stable value. Everything inside `Update` tests `+0x28`, never `+0x14`. Since the manager's clear and the fronts' re-stamp both happen on the main thread in `RunHourlyPass` (`0x2826F3`) before the province pass is spawned (`0x282A3B`), the copy is consistent.

## 7. The numbers: which define moves what

Every `weather` define is copied into an individual global at startup by `CWeatherManager::InitialiseWeatherState` (`0xB54F0`) and read from there afterwards. The copy covers block offsets `+0x00`–`+0xC0`; the six `GFX_*_LIMIT` entries (`+0xC4`..`+0xD8`) and `INITIAL_SIMULATION_HOURS_AHEAD` (`+0xDC`) are **not** cached and are read straight out of `[CDefines+0xEC]`.

**Tool bug worth fixing:** `scratchpad/naval/definecache.py` recovers 46 and **misses `PRESSUREMAX` (+0x4) and `PRESSUREDEFAULT` (+0x8)** — its regex requires a `0x` prefix on the displacement and capstone prints `[ecx + 4]` / `[ecx + 8]` without one. They are `0x130CA94` and `0x130CA9C`, read out of the copier at `0xB56AF` and `0xB56BE`. Any block with an entry at +0x4 or +0x8 is short by two. (`0x130CA9C` = `PRESSUREDEFAULT` is load-bearing here — it is the gate that stops a front spreading.)

| Define | BlackICE | Readers | What it moves |
| --- | --- | --- | --- |
| `PRESSUREMIN` | 870 | `Clamp`, `Update` | pressure floor; bottom of the humidity term's pressure scale |
| `PRESSUREMAX` | 1090 | `Clamp`, `Update`, `PropagateHighPressure` | ceiling; top of that scale; what a high pressure seed is set to |
| `PRESSUREDEFAULT` | 1013 | `CProvince::CProvince`, `Update`, **`CWeatherFront::Tick`** | a new province's pressure; the target `PRESSURESTEP` drifts to; **the gate that stops a front spreading** |
| `PRESSURESTEP` | 5 | `Update` only | how fast a low fills in: 5.000 hPa/hour |
| `PRESSUREREDUCTION` | 2 | `PropagateHighPressure` only | how fast a high's target falls with cost; walk stops at cost 545 |
| `PRESSUREPROPAGATION` | 10 | `PropagateHighPressure` only | climb toward that target, per hour |
| `PRESSURETHRESHOLD` | 300 | one site, `0xB4890` | **nothing at this value.** Bites below 220 |
| `MAXHUMIDITY` / `MINHUMIDITY` | 100 / 0 | `Clamp` only | the humidity range |
| `MAXFROMEACHPRESSURE` | 8 | three sites | fronts per zone; global cap (zones × this); **and the 1/8 turn between a zone's fronts** |
| `LOWPRESSUREBASE` / `LOWPRESSUREOFFSET` | 100 / 100 | the constructor only | depth of a new low (100–199 hPa). **OFFSET below 1 divides by zero** |
| `WEATHERMOVEMENTDELAY` | 2 | `CWeatherFront::Tick` only | hours per step |
| `TEMPERATURECHANGESPEED` | 0.075 | `Update` | chase rate to `BaseTemperature`; **its sign gates two climate multipliers, one unreachable while positive** |
| `HOURLYFROZENINCREASE` / `HOURLYTHAW` | 0.075 / 0.025 | `Update` | the frozen branch |
| `CLOUDCOVERAGETEMPERATUREDROP` | 8 | one site, `0xB254D`, **inside `CWeather::BaseTemperature`** | how much cloud cools the temperature a province is pulled toward |
| the six `GFX_*_LIMIT` | 0.1/0.1/15/15/0.3/0.8 | `CWeather::GraphicName` (`0xB4400`) | the displayed weather, below |
| `GFX_RAINIMPACT_LIMIT` | 0.1 | **none** | **dead, confirmed** — there is no seventh limit |

`CWeather::GraphicName`, `this` in EAX, bare `ret`, answering one of seven `std::string` globals at `0x130CAF0 + 0x1C·k` (uninitialised `.data`, so not readable statically):

```
if (precipitation > GFX_SNOW_LIMIT && temperature < -5 C)
     return windspeed > GFX_SNOW_STORM_LIMIT ? snowstorm : snow
if (precipitation > GFX_RAIN_LIMIT)
     return windspeed > GFX_STORM_LIMIT      ? storm     : rain
if (cloud > GFX_CLOUD_LIMIT)         return overcast
if (cloud > GFX_PARTIAL_CLOUD_LIMIT) return partly cloudy
return clear
```

The **snow limit is tested before the rain limit**, so it must be the larger of the two to mean anything; BlackICE sets both to 0.1, which makes the snow branch a pure temperature test.

### Numbers that are **not** defines

Fourteen compiled-in `(int)floor(N.5f)` statics, each with one or two readers in the whole image, all in this subsystem. No `defines.lua` entry moves any of them.

| Global (rva) | Value | What it is |
| --- | --- | --- |
| `0x1686F80` | 200 | the front's base spread arc, thousandths of a turn |
| `0x1687000` | 150 | added while the front covers fewer than 3 provinces |
| `0x1687028` | 800 | `rotation` decay per move |
| `0x1686FC8` | 10 | a new front's `rotation`, negated in the southern hemisphere |
| `0x168703C` | 980 | humidity handed on, and the pressure a neighbour is pulled down by |
| `0x1686FCC` | 970 | windspeed advection |
| `0x1686F98` | 250 | pressure difference → windspeed |
| `0x1687068` | 950 | temperature advection (clamped ±10.000) |
| `0x1686F3C` | 750 | **windspeed decay an hour with no front** — the old 0.980 note is wrong |
| `0x1686F5C` / `0x1686FA0` | 100 / 200 | cloud gained an hour, with / without a front |
| `0x1686FE8` | 50 | cloud lost an hour when the air is too dry |
| `0x1686F30` | 200 | cloud burnt off per unit of rain (no front only) |
| `0x1686F40` | 500 | the sea's precipitation threshold, the frozen ceiling at −10 C, and the infra clamp |
| `0x1686F74` | 250 | the snowfall precipitation threshold and the frozen ceiling at −2 C |
| `0x130CAEC` | 1000 | the `1.000` in the humidity term's `1000 − pNorm`. **File-initialised, never written by code** |

Plus three magnitudes that are not even cached statics but inline `(int)floor(N.5f)` conversions: `2000` (precipitation per unit of cloud, `0xB2786`), `10000` (humidity lost per unit of rain, `0xB27D5`), and `200`/`100` (the two partial freezing rates, `0xB2988`, `0xB29C5`).

## 8. What the savegame confirms

`autosave.hoi3` from the 1942 BlackICE game under `Documents/Paradox Interactive/Hearts of Iron III/BlackICE GitHub/save games`. The `weather={ front={ … } }` block is the engine's own output.

**The precipitation formula, on 2092 provinces out of 2092.** Every province whose weather block carries both `cloud_coverage` and `precipitation` satisfies `precipitation = clamp(2 × (cloud − thr), 0, 1)` for one of the three thresholds, with the cloud read back either as saved (front present) or as `cloud + 0.2 × precipitation` (no front, so the cloud was burnt off *after* the rain was computed). Not one exception. That confirms the `2.000` multiplier, all three thresholds, the `0.200` burn-off and its ordering inside `Update`.

**`MAXFROMEACHPRESSURE` really is both numbers.** 45 fronts across 12 of the 19 zones; the busiest, `13833`, holds **exactly 8**. Its headings are `0.060, 0.185, 0.310, 0.435, 0.560` — **steps of exactly 0.125** = `1000000 / MAXFROMEACHPRESSURE`. The same lattice appears in every multi-front zone: `11980` 0.134/0.259/0.384, `11566` 0.256/0.381/0.506, `10597` 0.477/0.602/0.727/0.852, `12125` 0.520/0.645/0.769, `13895` 0.136/0.261/0.761/0.886.

**`speed` is the countdown and `WEATHERMOVEMENTDELAY` is 2.** Every front reads `speed=1` or `speed=2` (23 and 22) — exactly a countdown reset to 2 and decremented hourly.

**`rotation` dies within a day.** 38 of 45 are `0.000`; the seven others are 0.001, 0.002, 0.003, 0.004, 0.008, −0.003, −0.008 — the ×0.8 decay from ±0.010 truncating to nothing. **The negatives confirm the hemisphere flip.** So in practice a front's heading is fixed; only the youngest fronts on the map still curve at all.

**The ranges** over those provinces: humidity 0.087–100.000 (`MAXHUMIDITY` = 100 exactly), pressure 889.967–1017.489 (inside `[870, 1090]`, above `PRESSUREDEFAULT` where a high reaches), windspeed 1.552–35.820 (against `WINDATTRITIONTHRESHOLD` 30 and `GFX_STORM_LIMIT` 15), temperature −6.167–7.124, and precipitation, muddyness, frozen and cloud all inside `[0, 1.000]`.

### One inference the savegame killed

`CWeatherFront::SaveContents` pushes the format string `"%d"` at `0x15DC2B4` for `direction` and `rotation`, while `LoadKey` reads them back through `0x669550`, which is the thousandths parser (`intPart × 1000 + fraction`). That looks like a ×1000 on every save/load round trip, which would wreck the arc test, and I had it written up as an engine bug. **It is not one.** The `"%d"` push is the *compact* branch, taken only when `writer+0xC` is set; the ordinary branch calls `0x6694C0`, the thousandths *formatter* — and the savegame proves it: the file says `direction=0.739`, not `739`. Round trip intact. `speed` is the one that genuinely uses `"%d"` and plain `atoi`, and the file says `speed=2`, which is why the two agree.

## 9. What was not established

- **`ProvinceEdge+0x10`.** Its only reader is the arc test, and the units are settled by the other side of the comparison (a heading seeded `Random() % 1000` and stepped by `1000000 / MAXFROMEACHPRESSURE`). But **I did not find what writes it** — there is no `fpatan` anywhere in the map loader and I could not locate the edge builder. Called `bearing`, confidence *likely*.
- **Two front headings in the savegame do not fit the lattice.** Four of zone `13833`'s eight fronts share `0.060` exactly, and one of `13895`'s reads `1.011`, above the `if (d > 1000) d -= 1000` wrap. Both are facts in the file and I cannot account for either: the cache advances by 125 per spawn and is wrapped before it is stored. Something in the spawn bookkeeping — most likely the interaction between the cache index, which counts only climate-eligible zones, and a reload re-randomising the cache — is not fully read.
- **Whether the climate/season really is frozen for a session.** The argument is sound but it is an absence of evidence; the honest test is to watch one province's `+0x30` across a few game months. The consequences (static `low_pressure_zones` masks, a climate-3 multiplier fixed at the start date) rest on it.
- **`CProvince+0x114`**, the object the muddyness branch gets its infrastructure figure from through `+0x60`/`+0x68`/`+0x70` — named only by what the arithmetic does with it.
- **`CWeather::BaseTemperature` (`0xB22E0`)** is read only far enough to see that it keys off the climate zone (3 adds 5.000, 4 adds 1.000, 1 subtracts 1.000), the night flag `CProvince+0x2C` (−2.000), `CProvince+0x388` and `CLOUDCOVERAGETEMPERATUREDROP`. Its whole latitude model is unread, and it is the other half of where temperature comes from — the obvious next job.

## Mod-facing summary

1. **`WEATHERMOVEMENTDELAY` is hours per step**; at 2 a front moves twelve times a day.
2. **`MAXFROMEACHPRESSURE` is the one knob with real reach**: fronts per zone, the global front count (`zones × it`, currently 152), and the angle between a zone's fronts.
3. **`PRESSUREDEFAULT` is what kills a front**, through `PRESSURESTEP`. Lower `PRESSURESTEP` and fronts live much longer.
4. **`PRESSURETHRESHOLD` does nothing at 300** and only starts to matter below `PRESSUREMAX − PRESSUREMIN` = 220.
5. **`GFX_RAINIMPACT_LIMIT` is dead** (confirmed — six limits, no seventh). **`GFX_SNOW_LIMIT` is tested before `GFX_RAIN_LIMIT`**, so leaving both at 0.1 makes the snow branch a pure temperature test.
6. **`LOWPRESSUREOFFSET` must stay at or above 1.0** or the first front created divides by zero.
7. **`terrain.txt`'s `humidity` is multiplied by five** and is the whole of a land province's evaporation; the desert's `−50.0` is a hard dry-out that pins humidity at zero and overrides its own `precipitation = 50`. `terrain.txt`'s `precipitation` *lowers the cloud threshold* rather than adding rain.
8. **Rain is `2 × (cloud − threshold)`, and the threshold is 0 on land with no front.** Clear-air showers are cheap and self-extinguishing; front rain persists because a front suppresses both the cloud burn-off and the humidity drain.
9. **`TEMPERATURECHANGESPEED`'s sign gates dead code** — while positive, the climate-5 doubling at `0xB2A56` is unreachable.
10. **`low_pressure_zones`' second column is a climate bitmask**, and `31` (used by 13 of BlackICE's 19 zones, and by vanilla) leaves climate 5 uncovered; `62`/`63` would cover all five.
11. **Nineteen `high_pressure_zones` cost ~95,000 province writes an hour** before any pressure is propagated. The one place where a long list in `default.map` has a measurable cost.

## Disagreements with what is already recorded (not overwritten)

1. **`CWeather+0x10` windspeed decay is 0.750, not 0.980.** `project.json`'s comment says 0.980; the bytes at `0xB25B1` are `imul dword ptr [0x1a86f3c]` and `[0x1686F3C]` = `floor(750.5)` = 750, two references in the image. 0.980 is `[0x168703C]`, the humidity/pressure transfer in `SpreadWeather`.
2. **`PropagateHighPressure`'s target is `PRESSUREMAX − d × PRESSUREREDUCTION`**, not `− d × PRESSUREREDUCTION/1000` (the ×1000 and /1000 cancel at `0xB6169`–`0xB6180`), and `d` is a sum of `CProvinceTemplate+0x24` traversal costs rather than a hop count.
3. **`CWeather::Update`'s precipitation is not interpolated toward `50.000 − CTerrain+0x64`** — that expression is a *threshold* on the humidity/temperature ratio for cloud growth. Precipitation is `2.000 × (cloud − threshold)`.
4. **`CWeatherManager+0x14`**'s existing comment says "what sets it was not established"; nothing sets it, and the path is dead (and would be a use-after-free).
5. **`0x6A2FD0`** is already `RandomThousandths` in `project.json` and my reading agrees; I removed my duplicate entry.
6. **`definecache.py` had a regex bug** that silently dropped any define at block offset +0x4 or +0x8: the displacement alternation only matched hex. *Fixed 2026-10-01 - it accepts `(0x[0-9a-f]+|\d+)` now and recovers 51 globals rather than 49, the two extra being `PRESSUREMAX` (+0x4) and `PRESSUREDEFAULT` (+0x8).*
