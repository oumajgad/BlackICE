# Research speed, the practical bonus, and tech decay

Three formulas, read out of `hoi3_tfh.exe` statically. Every address is given as a virtual
address with its rva beside it, because `project.json` wants the rva and the disassembler
prints the VA.

Two units are in play and they are not the same one:

- **thousandths** - the usual HoI3 integer scaling, `1.000` stored as `1000`;
- **`1.0 = 0x8000`** - a 64-bit fixed point (`fpml::fixed_point<__int64,48,15>`), which is
  what a technology's *progress* is kept in and what the gain function answers.

Each formula below says which.

---

## 1. The daily research gain - `0x532C20` (rva `0x132C20`)

**Convention, taken from the `ret`.** `ret 0xC` at `0x532EB4`, three stack arguments, and
**two register arguments**:

    int64* GetResearchGain(
        int level@ECX,                  // -1 means "the level after the one researched"
        CTechnology* technology@EDX,
        CTechnologyStatus* status,      // [ebp+8]
        int64* out,                     // [ebp+0xC], 1.0 = 0x8000
        int leadership)                 // [ebp+0x10], thousandths; -1000 means "look it up"
    // answers `out` in eax

Both callers set both registers explicitly: `0x532F3E` does `or ecx, -1` and `mov edx, esi`,
and `0x532B8A`/`0x532B8E` do `mov ecx, [ebp+8]` / `mov edx, esi`. So this cannot be written
as an ordinary function and the registers have to be annotated.

`i = technology->index` (`CTechnology +0x244`) throughout.

- `level == -1` -> `level = status->level_by_technology[i] + 1` (`+0x218`, `0x532C53`).
- `leadership == -1000` -> `leadership = status->leadership_by_technology[i]`
  (`+0x238`, `0x532C66`).

### The formula

    cost        = GetResearchCost(status, technology)        // 0x5333F0, thousandths
    if cost <= 0:  out = 0 and return                       // 0x532CA8..0x532E95

    dueYear     = level <= 1 ? technology->start_year                      // +0x2B4
                             : technology->first_offset                    // +0x2B8
                               + max(level-2,0) * technology->additional_offset  // +0x2C0

    year        = (state->tick - 43800000) / 24 / 365.0      // truncated; 0x532D69..0x532D99
    early       = dueYear - year

    yearPenalty = early > 0 ? 1.000 + early * TECHNOLOGY_YEAR_IMPACT       // 0x532DA1
                            : 1.000

    efficiency  = max(1.000 + MODIFIER_RESEARCH_EFFICIENCY                 // modifier id 73
                            + status->research_efficiency,                 // +0xA8
                      0.100)                                              // global 0x1A87BE8

    gain        = leadership * efficiency / yearPenalty     // thousandths, 0x532DD5..0x532E39
    out         = (gain / 1000) / (cost / 1000)             // 1.0 = 0x8000, 0x532E5A..0x532E90

So, in the units a modder thinks in, **the progress a technology makes in one call is**

    levels per day = leadership x research_efficiency / year_penalty / cost

**It divides by `0x5333F0`'s answer, it does not multiply by it.** The survey said
"scaled by"; the code at `0x532E89` is `__alldiv(gain << 15, ratio)`.

The two helpers are the CRT's 64-bit pair: `0xB99AF0` is `__allmul` and `0xB99980` is
`__alldiv`. That is fixed by `0x532E22`, where the same value is multiplied by 1000 and
divided by `esi` inline when it fits in 32 bits and through those two helpers when it does
not.

### `start_year`, `first_offset` and `additional_offset` are difficulty, not gates

**Confirmed, and they are calendar years.** `0x29C55C0` is `43,800,000`, which is exactly
the tick epoch `BiceLib`'s `utils::gameTickToParts` already uses, and `[0x160A550]` is the
double `365.0`. So `(tick - 43800000) / 24 / 365.0` truncated *is the calendar year* -
`1936`, not a count of elapsed years. Subtracting it from `start_year` therefore measures
**how many years ahead of schedule the level is being researched**.

The mod's own data agrees: across `technologies/*.txt`, `start_year` takes the values
`1900, 1910, 1914, 1917, 1918, 1920, 1924 ... 1942` and up, `first_offset` takes
`1901 ... 1961`, and `additional_offset` takes only `1, 2, 3, 4, 5, 6`. So:

| key | what it is |
| --- | --- |
| `start_year` | the year **level 1** is due |
| `first_offset` | the year **level 2** is due - not an offset at all |
| `additional_offset` | the **years added per level** past level 2 |

`TECHNOLOGY_YEAR_IMPACT` is `2.5` in BlackICE's `defines.lua`, so a level due in 1940 and
researched in 1936 costs `1 + 4 x 2.5 = 11x` the time. **Nothing here blocks the
research** - the gate is the `allow` block, evaluated in `0x535760` (see below).

`TECHNOLOGY_YEAR_IMPACT` has exactly two readers, `0x532DA1` here and `0x542595`
(in the function at `0x542560`, not read).

### The globals

Three file-scope constants, all built at startup from float literals by a
`float -> fixed_point -> int` pair (`0x401FD0` then `0xC08870`), so **they are compiled in
and no define moves them**:

| global | initialiser | value | what it does |
| --- | --- | --- | --- |
| `0x1A87BE8` | `0xCBBE70`, float `100.5` at `0x160A684` | `100` | floor on `efficiency`: research never runs below **10%** |
| `0x1A87BB4` | `0xCBBEA0`, the same literal | `100` | `difficulty` scale: **+10% cost per point** |
| `0x1A87B70` | `0xCBBED0`, float `900.5` at `0x160AAC8` | `900` | cap on the practical bonus: at most **90% off** |

`0x1A8559B` is the **`instantresearch` console flag**, not a define: `0x4400A2` toggles it
and prints `Instant research ON` / `Instant research OFF`.

---

## 2. The research cost, and the practical bonus - `0x5333F0` (rva `0x1333F0`)

`ret 8` at `0x5334E5`, so a method with two stack arguments:

    int* __thiscall CTechnologyStatus::GetResearchCost(
        CTechnologyStatus* this, int* out, CTechnology* technology)
    // answers `out` in eax; the value is thousandths

### The formula

    base  = (technology->difficulty x 0.100 + 1.000) x 125            // 0x5333FD..0x533440

    bonus = 0
    for each node of technology->research_bonus_from (+0x2A4):        // 0x533448..0x53348B
        bonus += Ability(node->category) x node->weight               // node +0, +4, next +0xC
    if technology->is_nuclear (+0x2CC):
        bonus += MODIFIER_NUKE_RESEARCH                               // modifier id 96
    bonus = min(bonus, 0.900)                                         // global 0x1A87B70

    cost  = base x (1.000 - bonus)

`difficulty` is `CTechnology +0x2C8`, the file key `difficulty` (save token `0x35F`), and
the loader reads it at `0x534B19` with `0xB969F1` - **the same helper `start_year` goes
through at `0x5351BF`** - so it is a plain integer and not scaled by 1000. BlackICE's values
are `1, 2, 3 ... 14`; three technologies write `difficulty = 0.5`, which that helper
truncates to `0`.

So for `difficulty = 1` the base cost is `137.5` and for `difficulty = 14` it is `300`, in
the same units the gain is in - **leadership-days per level before the practical bonus**.

### `Ability` - the per-category term, `0x5332B0` (rva `0x1332B0`)

`ret 8`, two stack arguments, and **the out pointer travels in `ESI`** (`mov eax, esi` at
`0x53336A`, and `esi` is only ever written through, never loaded) - the same shape as
`CCountry::GetCategoryBuildDiscount`:

    int* GetCategoryResearchAbility(
        int* out@ESI, CTechnologyStatus* status, CTechnologyCategory* category)

    level = max(country->own_ability[cat], the sharer's own_ability[cat])  // +0x698 / +0x6A8
    a     = clamp(level, 0, 20.000) - 5.000                               // 0x533319..0x533331
    if a > 1.000:  a = sqrt(a)                                            // 0xA9CEC0
    return a x 0.100

`country` is `status->+0x248`. The sharing lookup is the same one
`CCountry::GetCategoryBuildDiscount` makes: `CCountry +0x6A8` holds a `CCountryTag` per
category and the higher of the two levels wins.

**The `20.000` at `0x533319` is an immediate, not `MAX_TECH_ABILITY`.** The define lives at
`CDefines` `country +0x44` and is read only at `0x4CF30F` and `0x4E03FE`
(`CCountry::SetTechAbility`). So raising `MAX_TECH_ABILITY` past 20 lets a country's level go
higher but **the research bonus stops counting at 20.000**.

Below `5.000` the term is negative and the `js` at `0x533339` skips the square root, so it
passes straight through: a category at level 0 contributes `-0.5` per unit of weight and the
technology costs *more*.

`0xA9CEC0` is a fixed-point square root in thousandths - `0` for a non-positive input, an
initial guess of `x/2`, then Newton iterations on `g - (g*g/1000 - x)/(2g)`. Read as
structure; **inference**, not proved by test.

### Callers

Four: `0x4D6101` and `0x4D6192` (both in the function at `0x4D59D0`, which is in no vftable
and was not read - the survey's "tooltip"), `0x532C7B` (the gain above) and `0x820C92`
(in `0x81F070`).

---

## 3. Practical and theory decay - `0x4204A0` (rva `0x204A0`)

`ret 8` at `0x420774`, two stack arguments plus `ecx`:

    void ApplyTechCategoryDecay(
        CCountryTag* tag@ECX,        // [ecx+4] is the country id; [ecx] goes to a dead slot
        void* customGameSettings,    // [ebp+8]
        bool theory)                 // [ebp+0xC], tested as a byte

`ebx = countryDataBase->countries_by_id[tag->id]` (`[0x1A855A4] + 0x16C`, an inlined
`CCountryTag::GetCountry`).

### The formula

    months  = theory ? settings->theory_decay_months      // +0x70
                     : settings->practice_decay_months    // +0x74

    slack   = Reinforcement->[+8] x Reinforcement->[+0x10]
            + Upgrade->[+8]       x Upgrade->[+0x10]      // 1.0 = 0x8000, then to thousandths

    for each CTechnologyCategory in the database ([0x1A87B78] + 0x1C):
        if !category->vslot2()            : skip          // 0x4205D8
        if category->is_theory != theory  : skip          // +0x60 vs the argument, 0x4205E5

        extra = theory ? 1.000
                       : settings->extra_practice_decay[category]   // default 1.000

        step  = BASE_TECH_DECAY x (1.000 + country->decay_modifier[category->index])
                x extra x months x (1.000 - slack)
        step  = clamp(step, -1.000, 0)                    // 0x4206CE..0x4206DD

        level = max(country->own_ability[cat], the sharer's)         // +0x698 / +0x6A8
        CCountry::SetTechAbility(country, category, level x (1.000 + step))

`Reinforcement` and `Upgrade` are `CCountry::production_distribution[4]` and `[5]`
(`CCountry +0x5F4`, read at `0x420538` as `[+0x10]` and `[+0x14]`, which
`CProductionDistribution` already names). **So IC going into reinforcements and upgrades
slows the decay**, and at `slack >= 1.000` it stops it entirely. Which two 64-bit
`CDistributionSetting` fields `+8` and `+0x10` are was recorded here as **not
established**. It was already answered elsewhere: `+0x10` is `factor` and **`+8` is
`base_percentage`**, the slider's own share - `project.json`, `CLASSES.md` and
`FINDINGS-production.md` all have it, from the luabind registration that exposes `0x4C8920` as
`GetPercentage`. So `slack` is the **sum of the Upgrade and Reinforcement slider positions**,
in thousandths - the share of IC those sliders *ask for*, formed before need is consulted at
all. See `FINDINGS-survivors.md` §3.

`country->decay_modifier[...]` is `CCountry +0x1174`, and the array's end is `+0x1178`.

### `BASE_TECH_DECAY` has two readers, and the second one *is* a tick

**Corrected.** This section first claimed a single reader. It has two, and the one it missed
is the monthly one that actually matters - `0x4DCACA`, in `CCountry::UpdateMonthly`. See
`FINDINGS-techdecay.md`; what follows is still an accurate reading of the *other* reader.

The scan that produced the wrong answer looked at every `call GetDefines (0x445D90)` site in
`.text` and took the first two displacement reads after the call. **`GetDefines` is inlined**
at `0x4DCA62..0x4DCABD` - the same body, the same `push 0x11C` and `call 0x4452E0`, the same
singleton `[0x1A86040]` - so there is no `call` there for such a scan to anchor on. Any
"only reader of a define" claim in this folder arrived at that way carries the same risk.

**What that site is reached from is the surprise.** The two wrappers are

| wrapper | argument | which half |
| --- | --- | --- |
| `0x41FE10` (rva `0x1FE10`) | `theory = 1` | theories |
| `0x41FFF0` (rva `0x1FFF0`) | `theory = 0` | practicals |

called at `0x41FFCA` and **`0x42047C`** - not `0x4204F8`, which is a `call 0x4DDD80` inside
`0x4204A0`'s own body. Each wrapper first **recomputes every ability of its half from
scratch**: it zeroes each matching category through `CCountry::SetTechAbility` and then, for
every technology whose `on_completion` (`CTechnology +0x28C`, a `CTechnologyCategory*`) is in
that half and whose researched level is above zero, adds
`(level + [0x160A460]) x [0x160A300]` into it (`0x41FF3A..0x41FFA1`, through `0x4E02F0`).
Only then does it apply the decay.

Both wrappers have exactly one caller: `0x41D560` (rva `0x1D560`, extent
`0x41D560..0x41E33C`, `ret 8` - verified by linear sweep, there is no `ret` before
`0x41E33C`). And `0x41D560`'s two callers are

- `0x428AA0` - `CCgmSetStageCommand` slot 6 (RTTI), the **custom game** stage command;
- `0x65A2B0` - `CInGameIdler` slot 3, the one-shot in-game initialisation, which at
  `0x661812` also calls the settings parser `0x41F9A0`.

Neither is a daily or monthly tick, so **this** reader runs only when the custom game
settings are applied - at game start, or when the custom-game stage changes. Ongoing drift
comes from the other one: `CCountry::UpdateMonthly` applies `BASE_TECH_DECAY` to every
category once a month, so tuning the define changes both the ability a country begins with
and the rate it bleeds away during play.

### `customGameSettings` - the CGM singleton

`[ebp+8]` is a lazily built singleton, `0xD8` bytes, held at `0x1A85C1C` and fetched by
`0x41C4E0` (constructor `0x41C570`). It has no vftable, so RTTI does not name it. Its save
loader is `0x41F9A0`, and the save tokens it reads name it: it is the **Custom Game
Modifier** block.

| offset | save token | what |
| --- | --- | --- |
| `+0x70` | `0x835` `theory_decay_months` | read with `0xB969F1`, so a plain integer |
| `+0x74` | `0x836` `practice_decay_months` | the same |
| `+0xA0` | `0x837` `unit_cost_mult` | a `CCGMUnitCostMult` sub-loader |
| `+0xB8` | `0x83A` `extra_practice_decay` | a `CCGExtraPracticeDecay` sub-loader; its map is `+0xC0..+0xC4` |
| `+0xD0` | `0x543` `officers_ratio` | |

The constructor zeroes `+0x70` and `+0x74` (`0x41C5D6`, `0x41C5D9`), so **with no
`theory_decay_months` / `practice_decay_months` in the save the whole decay step is zero**
whatever `BASE_TECH_DECAY` says. The `extra_practice_decay` map is looked up at `0x42060B`
through `0x4213C0`, keyed by `CTechnologyCategory +0x4`, value at the node's `+0x10`, and
falls back to `1.000` when the key is absent (`0x420631`). Reading it as a multiplier on that
category's decay is **inference from its use**; where the map is filled was not found.

`CTechnologyCategory +0x60` is a bool and the code says which way round: the `theory = 0`
pass is the one that consults `extra_practice_decay`, so **`+0x60 == 0` is a practical and
`+0x60 != 0` is a theory** - which matches `common/technology.txt`'s two lists,
`theoretical = { ... }` and `practical = { ... }` (save tokens `0x75C` and `0x75B`).

---

## 4. How a finished technology reaches the country

### `0x532F10` (rva `0x132F10`) - one tick of one technology

`ret 8` at `0x532F98` and `0x53300F`, two stack arguments, and **`this` arrives in `EAX`**:

    bool AdvanceResearch(
        CTechnologyStatus* this@EAX,
        CTechnology* technology,     // [ebp+8]
        int leadership)              // [ebp+0xC], thousandths

**The survey had the register wrong**: the *technology* is the first stack argument, at
`[ebp+8]`; it is the *status* that arrives in `eax` (`mov esi, eax` at `0x532F1E`, then
`[esi+0x238]`, `[esi+0x228]`, `[esi+0x218]`). Both call sites set it - `mov eax, [esp+0xA0]`
at `0x51F737` and `0x51F9D0`. It is `0x532970` below that takes its technology in `edi`.

What it does, with `i = technology->index`:

1. `status->leadership_by_technology[i] = leadership` (`+0x238`, `0x532F2E`).
2. `status->progress[i] += GetResearchGain(-1, technology, status, &g, -1000)` - a 64-bit
   `add`/`adc` at `0x532F5B`, so `+0x228` is an **array of 8-byte `1.0 = 0x8000` fixed
   points**, `i` scaled by 8.
3. Returns `false` unless `progress[i] >= 1.0` **or** the `instantresearch` byte at
   `0x1A8559B` is set (`0x532F87`).
4. Otherwise `progress[i] -= 1.0`, floored at 0; `status->level_by_technology[i]++`
   (`+0x218`); `ApplyTechnologyEffects(status, 1000)` with the technology in `edi`; and
   **if `technology->additional_offset == 0` the leftover progress is zeroed** (`0x532FE9`) -
   a single-level technology keeps nothing.
5. Returns `true`.

### `0x532970` (rva `0x132970`) - applying a technology at a scale

`ret 8` at `0x532B61`, and **the technology really does arrive in `EDI`**: it is never loaded
in the body and every use is `[edi + ...]` (first at `0x532A76`). Both real callers set it -
`0x53292D` (`mov edi, [eax+ebx*4]`) and `0x532FD5` (`mov edi, [ebp+8]`).

    void ApplyTechnologyEffects(
        CTechnology* technology@EDI,
        CTechnologyStatus* status,   // [ebp+8]
        int scale)                   // [ebp+0xC], thousandths

    for i in 0 .. number of unit types:                  // the database at 0x1A886F0
        status->build_cost_by_unit_type[i]    += technology->+0x2D0[i] x scale / 1000
        status->build_cost_mp_by_unit_type[i] += technology->+0x2E0[i] x scale / 1000
        status->build_time_by_unit_type[i]    += technology->+0x2F0[i] x scale / 1000
    for each of technology->activate_unit (+0x300 .. +0x304):
        status->unit_available[definition->index] = true          // +0x27C
    if technology->activate_building->vslot8():
        status->building_available[building->+0x54] = true        // +0x28C
    0x5374F0(status, technology, scale)                           // the country-wide effects

**The third array is one the survey missed** (`+0x2F0` into `+0x26C`, the build time), and
`+0x300..+0x304` is the `activate_unit` vector `CTechnology.hpp` says has "no field of its own
here".

**`CTechnology +0x2D0` is a pointer, not `int[4]`.** `0x532A76` is `mov edx, [edi+0x2D0]` and
then `mov eax, [esi+edx]` with `esi = i*4`, so it is the begin pointer of a per-unit-type int
array - exactly parallel to `CTechnologyStatus +0x24C`. The same holds for `+0x2E0` and
`+0x2F0`. `project.json` and `CTechnology.hpp` both record these as `int[4]` with "what those
sixteen bytes hold has not been read"; what they hold is a vector's begin, end and capacity.

### The two callers that are not the tick

- `0x532840` (rva `0x132840`, `ret 4`, one argument, the status) **reapplies every technology
  from scratch**: `0x531DE0` first, then for each technology in the database with a level
  above zero it calls `ApplyTechnologyEffects` with `scale = level x 1000` (`0x532937`).
  `0x41DC85` calls it per country, immediately before the theory recompute. Note
  `image.functionStart(0x532943)` answers `0x532940`, which is inside this function - an
  abutting-function miss.
- `0x52EF9B`, in the function at `0x52E3A0`, not read.

### The research tick itself

`0x532F10`'s three callers are `0x51F73F` and `0x51F9DB`, both in **`CDistributeResearch` slot
0** (`0x51F620`, vftable `0x15C2340`, RTTI), plus `0x9A2747` in `0x9A2710`. So the gain is
spent by the **research share of the leadership distribution**. That the call is once a day is
**inference**, from two things: the leadership distribution is a daily pass, and the estimate
function below turns `1.0 / gain` into a count of *days*.

`0x532EC0` (rva `0x132EC0`, a bare `ret`, the object in `EAX`) zeroes the whole
`+0x238..+0x23C` leadership vector; its one caller is `0x51F6BA`, in the same tick, so the tick
clears the assignments and then writes them back one technology at a time.

### The estimate - `0x532B70` (rva `0x132B70`)

`ret 0xC`, three stack arguments and **two register arguments**, the technology in `eax` and
the status in `edi`:

    int GetDaysToResearch(
        CTechnology* technology@EAX, CTechnologyStatus* status@EDI,
        int level, int leadership, bool fromScratch)

    gain = GetResearchGain(level, technology, status, &g, leadership)
    if gain <= 0: return -1
    remaining = fromScratch ? 1.0 : 1.0 - status->progress[i]
    return remaining / gain + 1

Five callers: `0x41A2C0`, `0x41A2F7`, `0x815CED`, `0x81F13C`, `0x8235D3`.

### `0x535760` (rva `0x135760`) - the gate

Not part of the brief, but it is where `max_level` and `additional_offset` do act as gates.
`ret 0xC`, the technology in `ecx`, a `CCountryTag` pair and a level on the stack:

- `additional_offset == 0` -> only levels `0` and `1` pass (`0x53579C..0x5357AC`), so
  **`additional_offset = 0` declares a single-level technology**;
- the level must not exceed `max_level` (`+0x2C4`, `0x5357B8`);
- a per-technology ceiling out of the CGM settings (`0x41F500`, its `+0x28`);
- and finally the technology's own `allow` block, `[this+0x248]` slot 6, with
  `cmp al, 1; sete al`.

Its polarity at the two use sites (`0x51F728`, `0x5335CA`, both `jne` past the research) reads
the opposite way round from that ending, and **was not resolved**.

---

## Field offsets this establishes

`CTechnologyStatus`:

| offset | name | evidence |
| --- | --- | --- |
| `+0xA8` | `research_efficiency` | `fieldmap.py 0x537DB0` names the effect key at `+0xA8`; read at `0x532DF0` |
| `+0x228` | `progress_by_technology`, `int64*`, `1.0 = 0x8000` | `0x532F5B` `add`/`adc`, index `i*8` |
| `+0x238` / `+0x23C` | `leadership_by_technology` vector | written `0x532F2E`, read `0x532C66`, cleared `0x532EC0` |
| `+0x248` | `country`, `CCountry*` | `0x532DD8` then `+0xDA8` and `+0xDF8`; `0x5332DF` |
| `+0x27C` | `unit_available`, `bool*` by unit-type index | `0x532B16`, tested `0x533030` |
| `+0x28C` | `building_available`, `bool*` by `CBuilding +0x54` | `0x532B3E` |
| `+0x1F8` | a per-category int array folded into `CCountry +0x1174` | `0x4DE3D6`; **that it is the `decay` effect key is inference** - `decay` (token `0x52E`) is the one key of the 47-effect switch `fieldmap` cannot place |

`CTechnology`:

| offset | name | evidence |
| --- | --- | --- |
| `+0x28C` | `on_completion`, `CTechnologyCategory*` | `fieldmap.py CTechnology` token `0x445`; used as a category at `0x41FEFC` |
| `+0x2A4` | `research_bonus_from`, list: `[0]` category, `[4]` weight, next at `[0xC]` | `0x533448..0x53348B` |
| `+0x2C8` | `difficulty` | `fieldmap` token `0x35F`; read `0x5333FD` |
| `+0x2D0` / `+0x2E0` / `+0x2F0` | `int*` per unit type, **not `int[4]`** | `0x532A76`, `0x532AA0`, `0x532AC3` |
| `+0x300` / `+0x304` | `activate_unit` vector, `CSubUnitDefinition**` | `0x532AEE..0x532B1C` |

`CCountry`:

| offset | name | evidence |
| --- | --- | --- |
| `+0x1174` / `+0x1178` | `tech_decay_modifier` vector, `int*` by category index, thousandths | read `0x420652` as `BASE_TECH_DECAY x (this + 1000) / 1000`; written `0x4DE3ED` |

---

## What contradicts the existing record

1. **`CCountry +0x1174` is not the tech *ability* array.** The ability is `CCountry +0x698`,
   and both `0x5332B0` and `0x4204A0` read it there. `+0x1174` is only ever used as a
   multiplier on `BASE_TECH_DECAY` (`0x420652`). Calling it the ability array is what makes
   `fixMinisterTechDecay` look like an ability patch when it is a **decay** patch.
2. **`CTechnology +0x2D0/+0x2E0/+0x2F0` are pointers**, not `int[4]`; `CTechnology.hpp` and
   `project.json` both say `int[4]` and "what those sixteen bytes hold has not been read".
3. **`0x532F10` takes its technology on the stack and its `CTechnologyStatus` in `eax`** - the
   survey's "the technology arrives in `edi`" belongs to `0x532970`.
4. **`0x532C20` divides by `0x5333F0`'s answer**, it does not scale by it.
5. **`0x4204A0`'s second caller is `0x42047C`**, not `0x4204F8` (which is a call *inside*
   `0x4204A0`).
6. `0x5333F0`'s base term carries a **`x125`** the survey did not mention, and that factor is
   what sets the whole cost scale.

---

## The decay chain is not hidden behind a virtual call

Worth recording because it was the obvious explanation and it is wrong. `0x4204A0`'s call
graph is shallow and does not reach the tick, which invites the thought that the per-period
application is reached virtually and so invisible to `findRefs`, which only sees direct calls.

**It is not.** None of `0x4204A0`, its two callers' functions, its grandparent `0x41D560`, or
either of that function's two call sites appears in **any** vftable slot of **any** class in the
RTTI export. Every edge in the chain is a direct call, so `findRefs` saw all of them.

The mechanism was simply a second, separate function: **`CCountry::UpdateMonthly`
(rva `0xDC840`)**, called directly from `RunMonthlyPass` at `0x683BE9`, which writes
`CCountry +0x698` at `0x4DCB20`. No virtual call anywhere in it. `FINDINGS-techdecay.md` has
the arithmetic and how it differs from this chain's.

The lead this section offered - "`0x41FFF0` among them, which sits immediately beside this
chain" - was **wrong**, and wrong in the folder's most repeated way: `0x41FFF0` ends at its
`ret 8` at `0x420492` with `int3` padding, and the `+0x698` accesses credited to it
(`0x420703`, `0x42070C`, `0x420717`) are inside `0x4204A0`, a fresh function with its own SEH
frame. An extent walk ran through a `ret`. That is the fifth time in this folder.

## What is not established

- **The tick period.** That `0x532C20` is called once a day is inference from
  `CDistributeResearch` being a leadership slider and from `0x532B70` reading the result as
  days. Nothing here measures it, and the game was not run.
- ~~**Whether anything decays tech ability during play.**~~ **Answered:**
  `CCountry::UpdateMonthly` does, monthly, under the same define. The suspicion recorded here -
  that the `GetDefines`-call scan could miss a reader - was right, though not for the reason
  guessed: the miss was an *inlined* `GetDefines`, not a stashed pointer.
- ~~**`CDistributionSetting +8`.**~~ **Never open - it is `base_percentage`**, named since
  `FINDINGS-production.md`, and this file was simply stale against the record (trap 14). `slack`
  is the sum of the Upgrade and Reinforcement **slider positions**, not spare capacity: the
  product is formed before need is consulted, so practical decay is slowed in proportion to
  what a country *allocates*, whether or not any of it is spent or needed. Since the six
  production shares sum to one, `slack <= 1000`. `FINDINGS-survivors.md` §3.
- **Where `extra_practice_decay`'s map is filled.** `CCGExtraPracticeDecay::LoadKey` exists in
  `project.json`, but no store into `settings +0xC0` was found anywhere in
  `0x41C570..0x421400`, and reading the value as a multiplier rests on its use at `0x420689`,
  not on the loader.
- **`CTechnologyCategory +0x4`, the map key.** `+0x8` is the key string, so `+0x4` is something
  else; which field it is was not read.
- **`0x535760`'s polarity**, as above.
- **`0x4D59D0`**, the function holding two of `0x5333F0`'s callers, and the `0x81xxxx` callers
  of `0x5333F0`, `0x5332B0` and `0x532B70`. Not in `luabind.json`, not in any vftable, not
  read.
- **`0x5374F0`**, where `0x532970` hands the country-wide effects off. Guessed at from its
  neighbour `0x537DB0` (the 47-effect switch); its body was not read.
- **`[0x160A460]` and `[0x160A300]`**, the two doubles the ability recompute at `0x41FF44` and
  `0x41FF55` uses. Not read, so how a technology's level turns into practical points is only
  half known.
- **`0xA9CEC0` is a square root by structure, not by test.** Nothing here evaluates it.
- Everything above is static. `CTechnologyStatus +0x228`, `+0x238` and `+0x1F8` have not been
  read out of a running game.
