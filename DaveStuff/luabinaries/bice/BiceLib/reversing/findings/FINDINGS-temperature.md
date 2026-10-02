# Temperature — where the number comes from, and the one line that breaks it

Read out of the executable on 2026-10-01, continuing `FINDINGS-weather.md` and `FINDINGS-weatherfront.md`. Addresses are **RVAs** against an image base of `0x400000` (trap 1); where a virtual address is meant it says so. Checked against `Ireland1945_01_22_02.hoi3` (date `1945.1.22.2`, 14 189 weather blocks), against BlackICE's `map/climate.bmp` and `map/positions.txt`, and against vanilla TFH's `map/cache/climate.bin`. Everything stated as a formula was read instruction by instruction; everything stated as a consequence is marked as one.

§4's bug was re-verified independently before this file was accepted, since it is a claim about an engine defect: the clamp at rva `0x96412` (`jns` then `xor eax, eax`) and the `neg` at rva `0x9646D` are both exactly where the survey puts them, and there are twelve `int3` bytes before the entry. **One correction to its wording:** the `neg` is not strictly unreachable. `or eax, 0xffffffff` at rva `0x96426` yields −1 on the divide-by-zero guard path, which the `neg` would then flip. For any real map height that path cannot be taken, so the `neg` is dead in practice and its presence is still the evidence that `abs()` was intended — but "unreachable" overstates it.

## In one paragraph

A province's temperature is a **base from `map/climate.bmp`** plus the terrain's own `temperature`, moved up or down by at most ten degrees by a **season**. The base is `(palette index − 100) × 0.150 °C` sampled at one pixel per province and is the whole reason Siberia is cold and the Sahara is hot; the season is `CProvince +0x30`, a band 1..5 recomputed **every game day** from the day of the year and the province's latitude. The latitude comes from `CProvince +0x388`, and that field is **zero for every province south of the equator** because of a single `xor eax, eax` at `0x96412` where an `abs()` was meant — the dead `neg` eight instructions later proves the intent. So the southern hemisphere has no season, no latitude penalty and no seasonal day length: it sits permanently in climate 3, which is `+5.000 °C`, all year. Everything north of about 19 °N gets the full model.

## 1. `CWeather::BaseTemperature` (`0xB22E0`), in full

`int* BaseTemperature(int* out@ESI, CWeather* w@[ebp+8])`, `ret 4`, answers `out` in EAX. The function runs `0xB22E0` to the `ret` at `0xB2580`, and `0xB2583`–`0xB258F` is `int3` padding up to `CWeather::Update` at `0xB2590`, so there is no cold path past the `ret` (trap 3). Not a `__thiscall`: the `CWeather*` arrives on the stack and the destination in ESI, the same shape as `CWeatherFront::Tick`. The one call site is `0xB29F9`, inside `CWeather::Update`, with `esi = &[ebp-0xc]`.

```
prov = w->province                                  ; CWeather +0x2C
out  = prov->path_node_ptr->base_temperature        ; CProvinceTemplate +0x8
if (prov->climate == 0) ComputeProvinceClimate(prov)        ; 0xB22FE
switch (prov->climate) {                            ; CProvince +0x30

  case 3:  out += 5.000
           if (prov->is_night) out -= 2.000
           break

  case 4:  out += 1.000
           if (prov->is_night) out -= 2.000
           break

  case 2:  out += 1.000
           if (prov->is_night) out -= 2.000
           break

  case 1:  out -= 1.000
           if (prov->latitude_north > 950) out -= 1.000       ; 0xB23A1
           if (prov->latitude_north > 650) out -= 1.000       ; 0xB23ED
           if (prov->is_night) out -= 2.000
           break

  case 5:  out -= 4.000
           if (prov->latitude_north > 950) out -= 2.000       ; 0xB247E
           if (prov->latitude_north > 650) out -= 4.000       ; 0xB24CA
           if (out < -3.000 && w->frozen >= 1.000)            ; 0xB24DA, 0xB24E2
               out -= w->windspeed * 0.125 + 5.000            ; 0xB2506
           if (prov->is_night) out -= 5.000                   ; 0xB252A
           break
}
; common tail
if (out > 10.000 || !prov->path_node_ptr->is_land)                  ; 0xB2532, 0xB2543
    out -= w->cloud_coverage * CLOUDCOVERAGETEMPERATUREDROP / 1000  ; 0xB254C
if (out < 3.000 && w->precipitation > 0) out -= 4.000               ; 0xB2566, 0xB256D
return out
```

Four things in that are new.

**Night costs 5.000 in climate 5 and 2.000 everywhere else.** `0xB252A` adds `0xFFFFEC78` = −5000 where the other four branches add `0xFFFFF830` = −2000. `FINDINGS-weather.md`'s "minus 2.000 at night" is right for four climates out of five.

**Climate 5 has a wind chill, and nothing else in the image makes windspeed change temperature.** It is gated twice: the running total must already be below −3.000 (`0xB24DA`) *and* `frozen` must be at its ceiling of 1.000 (`0xB24E2`). The coefficient is an inline `(int)floor(125.5f)` from the float at `0x120A9E4`, so 0.125 °C per unit of windspeed, and there is a flat 5.000 on top. At the 35.820 windspeed the earlier survey measured that is another −9.478.

**The cloud term's condition reads oddly and is not a typo.** `jg` on 10000 at `0xB2538` takes the drop; otherwise the land flag at `0xB2543` *skips* it. So cloud cools a **sea** province always and a **land** province only where the base is already above 10 °C. With `CLOUDCOVERAGETEMPERATUREDROP = 8` and cloud clamped to 1.000 it is worth up to −8.000.

**The last term is a cold-rain term.** Below 3.000 °C, any precipitation at all costs a further 4.000. It is the only place in the function where precipitation appears, and because it fires *below* 3 °C it pushes provinces toward `frozen`, not away from it.

### The latitude thresholds are not defines

`950` and `650` are MSVC function statics, initialised once from the floats `950.5f` (`0x120A9EC`) and `650.5f` (`0x120A9E8`) under four bits of the guard word at `0x17EBC1C` — bit 0 → `0x17EBC18`, bit 1 → `0x17EBC14`, bit 2 → `0x17EBC10`, bit 3 → `0x17EBC0C`. Climate 1 and climate 5 each get their own pair holding the same two numbers. They are the `(int)floor(N.5f)` kind: **no `defines.lua` entry reaches them**, and nor does the 125 wind-chill coefficient. The only define in the whole function is `CLOUDCOVERAGETEMPERATUREDROP`, read as the cached global `0x130CAC4` (`= 8000`).

## 2. `CProvinceTemplate +0x8` is `map/climate.bmp`

`CProvinceTemplate::CProvinceTemplate` (`0xA92B0`) zeroes `+0x8` at `0xA92E4`. It is written in **exactly one** place and read in exactly one place.

The writer is `LoadProvinceClimate` (`0x8BE00`), called once from the map build at `0x8AE32`. It samples one byte of the climate image per province —

```
img = map->climate_image                      ; CMap +0x2108, built at 0x8C110 from
                                              ; default.map's `climate` filename (CMap +0x20EC)
for (i = 0; i < map->province_count; ++i) {
    t     = map->templates[i]                 ; CMap +0x2A60
    index = img->pixels[ img->pitch * t->position_y + img->bpp * t->position_x ]   ; 0x8BF82
    out[i] = index
}
```

— caches that array to and from `map/cache/climate.bin`, and then turns it into temperatures:

```
k = (int)floor(150.5f)                        ; 150, from 0x120A83C, hoisted at 0x8C078
for (i = 0; i < map->province_count; ++i) {
    t = map->templates[i]
    t->base_temperature = (climate[i] - 100) * k + t->terrain->temperature   ; 0x8C0DD
}
```

So, in thousandths of a degree, **`base = (palette index − 100) × 150 + terrain.temperature`**, i.e. `0.150 °C` per index step with index 100 as zero. The 150 is an inline `(int)floor(150.5f)` — not a define, not even a cached static.

**That the byte is a palette index, not a colour channel, is confirmed from the data.** Vanilla TFH's `map/cache/climate.bin` is 56 676 bytes = 14 169 int32, one per province; its 77 distinct values are all 8-bit indices that occur in `tfh/map/climate.bmp`, min 26, max 255, and not one value in the cache is absent from the bitmap. So `img->+0xC` is 1 and the sample is the index.

### What that gives BlackICE

`map/climate.bmp` is 5616 × 2160, 8-bit, 84 distinct indices in use, running 26 to 255. The palette is a blue→cyan→green→yellow→red ramp, so a modder painting it is painting temperature directly:

| index | palette rgb | base contribution |
| --- | --- | --- |
| 26 | 62, 0, 255 | −11.100 |
| 50 | 0, 16, 255 | −7.500 |
| 99 | 0, 255, 223 | −0.150 |
| 111 | 0, 255, 128 | +1.650 |
| 146 | 151, 255, 0 | +6.900 |
| 159 | 255, 255, 0 | +8.850 |
| 255 | — | +23.250 |

and `terrain.txt`'s `temperature` adds between −22.000 (`hills_arctic`) and +12.000 (`desert`, `mountain_desert`). So the whole achievable base is **−33.100 to +35.250**, against a season worth at most ±10.

**Two mod-facing consequences.** First, `climate.bmp` must keep its palette: the engine reads the *index*, so recolouring the palette changes nothing and re-indexing an otherwise identical image changes everything. Second, one pixel decides a province — `CProvinceTemplate +0x64/+0x68`, the position the map loader wrote, not an average over the province's area — so a province whose stored position lands on a stray pixel takes that pixel's temperature for the whole game.

## 3. `ComputeProvinceClimate` (`0xA81A0`) — the season, in full

`void ComputeProvinceClimate(CMapProvince* prov@[ebp+8])`, `ret 4`. It writes `CProvince +0x30` and nothing else.

```
prov->climate = 3                                   ; 0xA81CB, the default
north = prov->path_node_ptr->+0xA2                  ; the hemisphere byte
                                                    ; slot order: -0x24,-0x20,-0x1c,-0x18,-0x14,-0x10
band = north ? {4, 4, 3, 2, 1, 5} : {2, 1, 5, 4, 4, 3}

lat = prov->latitude_north                          ; CProvince +0x388
if (lat <= 250) return                              ; 0xA8222 - climate stays 3
L = (lat - 250) * 1000 / 750 * 183 / 1000           ; days, 0 .. 183
W = 183 / 2 = 91                                    ; 0x130C8E0 = 183000
X = 365 - 2*W - L = 183 - L

day = ((g_CCurrentGameState->date - 43800000) / 24) % 365    ; 0xA8344 .. 0xA838E
d   = day - L/2

if      (d <= 0)                  prov->climate = band[F]
else if (d <= W/2)                prov->climate = band[A]
else if (d <= W)                  prov->climate = band[B]
else if (d <= W + X)              prov->climate = band[C]
else if (d <= 2W + X - W/2)       prov->climate = band[D]
else if (d <= 2W + X)             prov->climate = band[E]
else                              prov->climate = band[F]
```

`43800000` is `hoi3.py`'s `TICK_EPOCH`, hour 0 of day 0 of year 0, so **`day` is the day of the year directly** and band F is centred on 1 January. The `% 365` is done the long way, `(int)(days / 365.0) * 365.0` subtracted from `days` through the double `365.0` at `0x120A550`; a Clausewitz year has no leap day, so it is exact.

Reading the band list in the order the code uses it gives a plain seasonal cycle:

| band | width in days | northern | southern | what it is |
| --- | --- | --- | --- | --- |
| F | `L` | **5** | 3 | centred on 1 January — northern deep winter |
| A | 45 | 1 | 4 | late winter |
| B | 46 | 2 | 4 | spring |
| C | `183 − L` | 3 | 5 | centred on 3 July — northern summer |
| D | 45 | 4 | 1 | autumn |
| E | 46 | 4 | 2 | late autumn |

and mapping that through §1 gives the offsets: winter −4.000 (plus up to −6.000 of latitude, plus wind chill, plus −5.000 at night), late winter −1.000 (plus up to −2.000), spring +1.000, summer +5.000, autumn +1.000. The asymmetry is in the right direction — autumn warmer than late winter — and the four shoulder bands are a fixed 45/46/45/46 days regardless of latitude, with **winter and summer sharing the remaining 183 days in proportion to latitude**: at the top of the map `L = 183`, so six months of winter and no summer at all; just above the 0.250 cut, `L = 0`, so no winter and six months of summer.

### The hemisphere byte is the other way round

`project.json` calls `CProvinceTemplate +0xA2` `southern_hemisphere`. It is the **northern** hemisphere, and the table above only reads correctly that way. Three independent checks:

- `map/positions.txt` says province 1, Porsangerhalvøya (≈71 °N), has `y = 2106` on a 2160-pixel map. **Province y grows northward.** `+0xA2` is set at `0x8FED8` where `+0x68 >= height/2`, so it is set in the north.
- `IsNight` (`0xA7390`) shifts the month by six **where `+0xA2` is clear** (`jne` at `0xA73CD` skips the shift). The hemisphere that needs its day-length table shifted half a year is the southern one.
- With `+0xA2` as northern, band F (1 January) is northern climate 5 and southern climate 3; the other way round it would make 1 January the warmest northern day.

The same inversion flips `FINDINGS-weatherfront.md`'s note that a new front's `rotation` is negated in the southern hemisphere: `CreateFront` negates it at `0xB5EF4` where `+0xA2` is **set**, which is the north.

### Where the latitude bands fall on BlackICE's map

Calibrating on province 1 (`y = 2106` ⇒ `latitude_north = 950` ⇒ 71 °N) gives about 14.4 pixels per degree:

| `CProvince +0x388` | pixels north of the equator | ≈ latitude | what changes |
| --- | --- | --- | --- |
| 250 | 270 | 19 °N | below this, no season at all |
| 650 | 702 | 49 °N | winter −4.000 more, late winter −1.000 more |
| 950 | 1026 | 71 °N | winter −2.000 more, late winter −1.000 more |

The tests are strictly `>`, so Porsangerhalvøya at exactly 950 gets the 650 penalties and not the 950 ones.

## 4. `CProvince +0x388`, and the line that breaks the southern hemisphere

`ComputeProvinceLatitude` (`0x963F0`) — a new name; `this` arrives in **EDI**, bare `ret`, and `image.functionStart` walked past it because its first byte is `push ecx` (`0x51`), which was not in that helper's prologue set. (**Fixed 2026-10-01**: `0x51`, `0x52` and `0x50` were added to the set in `image.py`, with the known-good cases regression-checked.) There are twelve `int3` bytes immediately before it.

```
half = map->height / 2                          ; CMap +0x2A78
dy   = prov->path_node_ptr->label_y - half      ; CProvinceTemplate +0x60
if (dy < 0) dy = 0                              ; 0x96412
prov->latitude_north = dy * 1000 / half         ; 0x96463
if (prov->latitude_north < 0)
    prov->latitude_north = -prov->latitude_north ; 0x9646D - dead for any real map
```

One caller: `CInGameIdler::Enter` at `0x25AFAD`, in a loop over every province in `state+0xB8C`, immediately before `ComputeProvinceClimate` at `0x25AFB3`. So the field is recomputed on every entry into a game and never again; `CProvince::CProvince` zeroes it at `0x94B44`; it is not a save key.

**`0x96412` is the bug.** `dy` is negative for every province south of the equator, so all of them get `latitude_north = 0`, which is at or below the 250 cut, so `ComputeProvinceClimate` returns at `0xA8222` with `climate` left at its default **3**. The consequences, all of them read rather than guessed:

- the entire southern hemisphere sits at **+5.000 °C of season, every day of the year**;
- it never reaches a latitude penalty or the climate-5 wind chill;
- `IsNight` multiplies its per-month day-length table (`0x130C8B0`, thousandths `{−6, −3, 0, +3, +6, +12, +6, +3, 0, −3, −6, −12}`) by `latitude_north`, so southern provinces get **twelve-hour days all year**;
- and `CWeather::Update`'s climate-3 multiplier (`0xB2A4B`) is permanently on there, so southern provinces chase their target ten times as fast as northern ones.

The `neg` at `0x9646D` is the evidence that this is a mistake and not a design: it takes the absolute value of a number the clamp has already made non-negative. The intended line was plainly `abs(y − height/2)`. Strictly it is reachable on one path — `or eax, 0xffffffff` at `0x96426` yields −1 when `half` is zero, the divide-by-zero guard — so it is dead for any real map rather than unreachable outright.

**This is a one-byte fix in principle** — the `jns` at `0x96410` skipping the `xor eax, eax` — but it is an engine behaviour change, not a mod file, and it would make the southern hemisphere colder in July for the first time. Noted, not recommended.

`CProvinceTemplate +0x60` is the y the function reads. `0x917A0` writes it at `0x91827` as a copy of `+0x30`, which is itself `bbox_y + bbox_height/2` (`0x91815`); `MapDistance` (`0x92030`) uses the `+0x2C`/`+0x30` pair and wraps the **x** half by the map width at `CMap +0x2A74`, which is what fixes `+0x30` as y and therefore `+0x60` as y. The code after `0x91839` in the same function goes on to refine `+0x5C`/`+0x60`, so that pair is better described as the province's representative point than as a duplicate of the bounding-box centre; it stays a map pixel coordinate either way.

## 5. The climate is **not** frozen for a session — `FINDINGS-weatherfront.md` is wrong here

`FINDINGS-weatherfront.md` argues that "all six callers call it only where `CProvince+0x30` is 0", that nothing zeroes `+0x30`, and so that a province's season is decided once in the first game hour and then frozen until a reload. It names the honest test and marks the claim as an absence of evidence. **Two of the six callers have no guard at all.**

| call site | in | guarded on `+0x30 == 0`? |
| --- | --- | --- |
| `0xB22FE` | `CWeather::BaseTemperature` | yes (`0xB22EC`) |
| `0xB2A43` | `CWeather::Update` | yes (`0xB2A39`) |
| `0xB2A69` | `CWeather::Update` | yes (`0xB2A5F`) |
| `0xB5DF6` | `CWeatherManager::CreateFront` | yes (`0xB5DEC`) |
| **`0x9EAE6`** | **`RunDailyProvincePass` (`0x9EAB0`)** | **no** |
| **`0x25AFB3`** | **`CInGameIdler::Enter` (`0x25A2B0`)** | **no** |

`RunDailyProvincePass` calls it as the first thing it does, with the only gate above it being `CProvinceTemplate +0x13D` at `0x9EAD5`; `RunDailyPass` runs it once a game day for every province in `state+0xB8C` (`0x282E4B`, already in `FINDINGS-schedule.md`'s table). So **a province's season is recomputed once a game day**, and `+0x30` is a live value, not a cached one. The lazy `if (climate == 0)` guards on the other four sites are a first-hour safety net, nothing more.

Three conclusions that rested on the old reading have to go with it:

1. `low_pressure_zones`' climate bitmask is a **seasonal** gate after all, not a static per-zone on/off switch. A zone that declares `31` is silent through the band that answers 5 — which, north of 19 °N, is **winter**. Thirteen of BlackICE's nineteen zones (and fourteen of vanilla's eighteen) therefore stop spawning fronts in the northern winter. South of the equator, where the climate is pinned at 3, the mask is static, and `31` covers 3, so those zones never stop.
2. The climate-3 ×10 temperature multiplier in `CWeather::Update` is **not** fixed at the start date. It is on in the northern summer, off in the northern winter, and permanently on in the whole southern hemisphere.
3. The set of mask-eligible zones changes with the season, which matters for §11.

*Positive control for the negative half of this.* The claim "nothing stores `CProvinceTemplate +0x8`" is a negative, so it was run with controls: the same holder-tied scan (a register loaded from `CProvince +0xD4`, then a window to the store) was asked for `+0x13D` and `+0x22`, fields with known readers, and found 93 and 239 sites including the known `0x9EAD5` and `0xB25A2`. Asked for `+0x8` it found two reads (`0xB22F6`, and `0x7ADD4E`, which is `[esp+0xd4]` and a false positive) and **no stores**; a second scan through `CMap +0x2A60` — the template array, which is how the map loader reaches them — found the stores to `+0x2C`, `+0x30` and `+0x60` in `0x917A0` and again none to `+0x8`. The writer was then found from the other direction entirely, through `default.map`'s `climate` key, so the two agree.

## 6. What the savegame says

`Ireland1945_01_22_02.hoi3`, 22 January 1945, 14 189 province weather blocks — one per province.

| | |
| --- | --- |
| temperature | −50.000 … +41.224, median +4.121, p1 −32.005, p99 +37.000 |
| frozen | 4 777 provinces above 0, **497 at 1.000** |
| windspeed | 0.000 … 92.731 |

A 91-degree spread settles that the base temperature carries the geography; the season alone could not produce it.

**The ceiling.** In January every province south of 19 °N is climate 3, so its target is `base + 5.000`, less a cloud drop above 10 °C. The highest reachable base is `+23.250` (index 255) `+ 12.000` (desert) `= +35.250`, so the ceiling is `+40.250`. The save's maximum is **+41.224**, 0.974 over, which is inside one chase step — climate 3 multiplies the step by ten, giving 1.500 °C an hour. Four of the ten warmest provinces (`10388`, `10359`, `10352`, `10439`) have `y` between 414 and 519, i.e. deep in the southern hemisphere, with essentially zero windspeed.

**The floor, to the thousandth.** Province `595` reads `temperature=-50.000 frozen=1.000 humidity=0.788 pressure=1013.867` with no `windspeed`, `precipitation` or `cloud_coverage` key at all, so those three are zero. `positions.txt` puts it at `y = 2128`, i.e. `latitude_north = (2128 − 1080) × 1000 / 1080 = 970`, above both thresholds; 22 January is inside band F, so climate 5. Then

```
target = base − 4.000 (climate 5)
              − 2.000 (lat > 950) − 4.000 (lat > 650)
              − 5.000 (night)
              − 5.000 (wind chill's flat term; windspeed 0, frozen 1.000)
       = base − 20.000
```

with no cloud term (cloud 0) and no cold-rain term (precipitation 0). An arctic terrain (`−20.000`) on the bitmap's coldest index 26 (`−11.100`) gives `base = −31.100` and a target of `−51.100`, which `CWeather::Clamp` holds at **−50.000** — exactly what the file contains, and the same for the other 29 provinces pinned there. Every one of the fifteen coldest provinces in the save has `y` between 2079 and 2149, i.e. the Arctic. **That is the whole model checked end to end against the engine's own output.**

It also shows the wind chill is reached in play: `336` reads `temperature=-50.000` with `windspeed=69.444` and `frozen=1.000`, which satisfies both of its gates.

## 7. `CWeather::Update`'s three interpolations, read line by line

`FINDINGS-weather.md` said these were traced only far enough to see which terrain field feeds them, and `FINDINGS-weatherfront.md` then corrected the precipitation one from an interpolation to a threshold. All three were read again from the bytes. **The `FINDINGS-weatherfront.md` version is right in every particular**, including the corrected windspeed decay of 0.750 (`imul dword ptr [0x1686F3C]` at `0xB25B1`); below is what the instructions say, with the three small things it did not mention.

```
; humidity                                           0xB25D4 - 0xB26AD
t = max(temperature, 0)
if (land) cap = terrain->humidity * 5                ; CTerrain +0x60, 0xB25F4
else    { cap = 5 * 1000; t += 10.000 }              ; eax preset to 1000 at 0xB25D7
if (humidity >= 1000) t = t * 1000 / humidity        ; 0xB2622
pNorm = (pressure - PRESSUREMIN) * 1000 / (PRESSUREMAX - PRESSUREMIN)
humidity += (1000 - pNorm) * t / 1000 * cap / 1000   ; the 1000 is [0x130CAEC]

; cloud coverage                                     0xB26B0 - 0xB2747
ratio = (temperature > 0) ? humidity * 1000 / temperature * 10 : humidity
thr   = 50.000 - terrain->precipitation - (land ? 30.000 : 0)      ; CTerrain +0x64
if (ratio >= thr && humidity > 0) cloud += front ? 100 : 200
else                              cloud -= 50

; precipitation                                      0xB274A - 0xB2804
precipitation = 0
thr = land ? (front ? 250 : 0) : 500                 ; [0x1686F40] halved for land
if (cloud > thr) precipitation = 2000 * (cloud - thr) / 1000
if (front == 0) { cloud -= precipitation * 200 / 1000
                  humidity -= precipitation * 10000 / 1000 }
```

The three things to add:

- **the muddyness and frozen block is land only.** `0xB280B` jumps straight to the temperature step when `CProvinceTemplate +0x22` is clear, so sea provinces never grow mud or ice. That is consistent with everything downstream but was not stated.
- **the final pressure step reads `CProvince +0x14`, not `CWeather +0x28`.** `FINDINGS-weatherfront.md` says "everything inside `Update` tests `+0x28`, never `+0x14`"; `0xB2AB9` is `cmp dword ptr [eax+0x14], 0` on the province. In practice the two agree, because the manager's clear and the fronts' re-stamp both run on the main thread before the province pass is spawned, but the sentence is wrong.
- **the temperature step's base is `land ? 2 : 1`** (`0xB29E6`/`0xB29F0`), so sea temperatures move at half the rate of land ones before any multiplier. With `TEMPERATURECHANGESPEED = 0.075` that is 0.150 °C an hour on land, 1.500 under the climate-3 multiplier, and 15.000 when the target is more than 10 °C away.

## 8. `CProvinceTemplate +0x13D` is the simulation switch, and it is not `is_land`

`FINDINGS-weather.md` reads `UpdateProvinceWeatherRange`'s test of `+0x13D` as "land, by this flag rather than `+0x22`". It is not a land test — sea provinces have weather, and `CWeather::Update` has explicit sea branches. The writer settles it.

`MarkSimulatedProvinces` (`0x285FB0`), `(CCurrentGameState* state, CScenario* scenario)`:

```
on = (scenario == 0)
for (p in state->provinces) p->path_node_ptr->+0x13D = on       ; 0x28600F
if (scenario != 0)
    for (id in scenario->provinces)                             ; CScenario +0x98/+0x9C
        state->provinces[id]->path_node_ptr->+0x13D = 1          ; 0x286062
```

`CScenario +0x98` is the vector `CScenario::LoadKey` (`0x5E990`, vftable slot 4 of VA `0x15BC784`) fills for save token `0x1DC` = `provinces`, at `0x5EA5C`. Nine callers, all sitting beside an install of `g_CCurrentGameState` (`0x1A89790`), one of them `CGameState::LoadKey`.

So **`+0x13D` means "this province is simulated"**: on for every province in an ordinary campaign — which is why `project.json`'s note says it is 1 in every province seen — and restricted to a scenario's own `provinces` list in a scenario. 93 sites read it through `CProvince +0xD4`, including the supply pass, the supply network builder, the weather pass and `RunDailyProvincePass`, which is the complete list of things a scenario switches off outside its area. `FINDINGS-aiplans.md` wants the same field.

`+0x22` is already `is_land` in `project.json` and that reading holds — 239 sites read it through `+0xD4`, among them `CWeather::Update`'s `land` flag at `0xB25A2` and `BaseTemperature`'s sea test at `0xB2543`.

## 9. `CProvince +0x114` was already named

The open question was what object the muddyness branch reaches its infrastructure figure through. `project.json` **already answers it**, on `CMapProvince`: `+0x114` is the province's `CModifierValues` array, indexed by `modifier id × 8` with the value in the low dword. So the muddyness branch's `+0x60`, `+0x68` and `+0x70` are modifier ids 12, 13 and 14 — `MODIFIER_INFRASTRUCTURE`, `LOCAL_INFRASTRUCTURE` and `GLOBAL_INFRASTRUCTURE`, exactly as `FINDINGS-weather.md` describes them. `RunDailyProvincePass` does the identical arithmetic at `0x9EB26`–`0x9EB47`, which is a second, independent reading of the same three slots. The only gap is that `project.json` carries the offset on `CMapProvince` and not on `CProvince`; the entry here adds it.

## 10. `ProvinceEdge +0x10` — where the value comes from, and why no `fpatan`

Still not settled, but narrowed. There are exactly three places in the image that store into a `ProvinceEdge`, found through `CProvinceTemplate::AddEdge` (`0xA9C90`, which is `lea edi, [eax+0x90]` then a `push_back`) and through the two direct `push_back`s on `+0x90`:

| builder | what it puts in `+0xC` / `+0x10` |
| --- | --- |
| `0x917A0`, the per-province pass that also computes the centres | the record is `{0, to, 0, 0, 0}` — **distance and bearing both zero** |
| `0x8E520`, the `adjacencies.csv` loader | `{kind, to, crossed, edx, edx}` at `0x8E8A4`–`0x8E8AF` — the **same register** in both |
| `0x8DFA0`, `ReadMapCache` | twenty bytes read verbatim out of the binary cache at `0x8E107` and pushed at `0x8E16C` |

And `WriteMapCache` (`0x8E2E0`) dumps them straight back: per province an int count (`0x8E423`) then each record as a raw `0x14` bytes (`0x8E461`). `map/cache/map.bin` exists beside `climate.bin` and is 12 144 137 bytes for vanilla.

**So the real bearings arrive deserialised, which is why the earlier survey found no `fpatan` in the map loader: the loader does not compute the field, it reads it.** Because the cache is a verbatim dump, something must still fill it before the first write, and that was not found. Two scans came back empty — stores to `[reg+0x10]` within a window of a `0x14` stride on the same register (19 hits, all unrelated; the only edge-shaped one is the vector-reallocation copy at rva `0xACEFD`), and SIB-form stores `[reg + reg*4 + 0x10]` (six hits, none in the map region). **Both negatives are uncontrolled**: the control for the first, asking it for `+0x4`, returned nothing at all, because the constructors build their record on the stack with no stride. So those scans prove nothing and the field's writer is simply still missing.

The field is certainly not always zero. In the 1945 save, fronts with `direction` 0.486, 0.584, 0.614, 0.709, 0.739 and 0.959 have grown to 31, 40, 12, 18, 23 and 26 provinces; if every bearing were zero only fronts heading near 0.000 could recruit anything, since `IsAngleWithinArc(direction, bearing, arc)` compares the two. So `bearing` stays **likely**, with the provenance now known.

## 11. The two front headings that did not fit

`FINDINGS-weatherfront.md` could not account for four of zone `13833`'s fronts sharing `0.060` or for one of `13895`'s reading `1.011`. One of those is now explained and the other has a mechanism.

**`1.011` is not off the lattice — it is drift, and the wrap is only in one place.** `CWeatherManager::CreateFront` wraps the *cached* heading (`if (d > 1000) d -= 1000`, `0xB5EB8`), but `CWeatherFront::Tick` then does `direction += rotation` on every move and **never re-wraps**. `rotation` starts at ±10 and decays by ×0.800, so a front's heading can drift up to ±0.050 past its birth value and out of `[0, 1000]` entirely. `1.011` is a front born at or just under `1.000` that has drifted up. The same arithmetic lets `direction` go slightly negative, and `IsAngleWithinArc`'s `%` on a negative centre is a C remainder, so the arc straddles the wrap asymmetrically there.

**The repeats are the norm, not an anomaly.** The 1945 save has 107 fronts, and the earlier survey's "steps of exactly 0.125 … the same lattice appears in every multi-front zone" does not survive it: zone `13833` has six fronts at exactly `0.048`, zone `920` five at `0.191`, `13895` four at `0.843`, `10237` three at `0.744`, and zone `13657`'s eight sit at 0.127/0.179×3/0.198/0.219/0.256/0.259 — steps of 0.019 to 0.052, not 0.125. `MAXFROMEACHPRESSURE` is still 8, so the step is still `1000000 / 8000 = 125`.

The mechanism, and this is **inference from the code rather than a reading of a bug**: both the per-zone heading cache and the per-zone cooldown are indexed by a counter that `CreateFront` does **not** advance when a zone fails the climate mask (`continue` without `++i` at `0xB5E0A`), while it does advance on the other three skips. The index is therefore "position among the zones not masked out", not a stable identity for a zone — and §5 shows the mask-eligible set changes **every game day** with the season. So a zone's heading slot and cooldown slot drift onto other zones' slots over a game, which both breaks the 0.125 lattice and lets a zone be picked again before its own cooldown would have allowed it. `CWeatherManager::ResetZoneState` (`0xB59C0`) is not part of it: it has one call site, `0x28256B` in `RebuildEventCandidatesAndDailyCaches` (`0x282510`), whose two callers (`0x24C296`, `0x2D8658`) are both in the game-entry path, so headings are re-randomised at a session start and not periodically. The exact sixfold repeat of `0.048` could not be reduced to instructions, and that is said rather than papered over.

## What is not established

- **`ProvinceEdge +0x10`'s writer.** Narrowed to "it comes out of `map/cache/map.bin`", which is itself a verbatim dump, so the computation exists and was not found. Both scans that came back empty had failing controls, so they are not evidence. Cheapest live check: read one province's edge list out of the running game with `dumpStruct.py` on `path_node_ptr +0x90`, and compare `+0x10` against the compass bearing from `+0x2C`/`+0x30` to the neighbour's — one province settles the units and the sign convention at once.
- **The exact repeat of `0.048` six times in one zone.** The slot/zone mismatch is a mechanism, not a derivation. Cheapest live check: watch `CGameState +0xB14` (`CWeatherManager +0x28`) as a vector while fronts spawn, and print the index `CreateFront` uses alongside the zone it picked.
- **Which pixel `CProvinceTemplate +0x64`/`+0x68` actually is.** The map loader writes it at two sites (`0x8FEBB` for sea, `0x9009D` for land) and what it computes there was not read, so "one pixel per province" is confirmed but *which* pixel is not. It matters only for provinces near a climate boundary.
- **Whether `0x917A0` refines `+0x5C`/`+0x60` after `0x91827`.** The function continues past that store with what looks like a search for a better representative point. Either way it is a y coordinate, so nothing in §4 depends on it.
- **`CProvinceTemplate +0x28`.** Whatever `CMap +0x2198` holds per province id; named from the constructor only.
- **No live reading.** Everything here is off the bytes and off one savegame. The one thing a running game would settle cheaply and nothing else can: watch one northern province's `CProvince +0x30` across two game months and confirm it steps through the bands §3 predicts — that is also the direct confirmation of §5.

## The headline for the mod, in four lines

1. **`map/climate.bmp` is the whole geography of temperature**, `(palette index − 100) × 0.150 °C` plus `terrain.txt`'s `temperature`. The engine reads the palette **index**, so re-indexing the image changes the climate and recolouring the palette does not.
2. **The southern hemisphere has no winter at all** — `+5.000 °C` of season every day of the year, twelve-hour days, and no latitude or wind-chill penalty — because of one clamp at `0x96412`. That decides how much of the southern map can ever become `frozen`: essentially none of it, unless `climate.bmp` plus terrain already puts a province below −5 °C.
3. **North of ~19 °N the model is real and recomputed daily**: winter is `L` days wide where `L` grows linearly from 0 at 19 °N to 183 at the top of the map, and winter costs −4 plus −4 above 49 °N plus −2 above 71 °N plus −5 at night plus `0.125 × windspeed` of wind chill once the ground is fully frozen.
4. **None of the temperature numbers are defines** except `CLOUDCOVERAGETEMPERATUREDROP`. The 150 °C-per-index scale, the 125 wind-chill coefficient and the 950/650 latitude thresholds are all compiled-in `(int)floor(N.5f)` statics that no `defines.lua` entry can reach.
