# What consumes revolt risk: the roll, the rebel type, and the underground

Read out of `hoi3_tfh.exe` statically on 2026-09-30. Addresses are **virtual** (base
`0x400000`) with the rva beside them where a finding names one. Nothing here was measured
in a running game. This closes the hole `FINDINGS-occupation.md` left open.

**In one line.** The revolt roll exists and it is **`0x4C07C0`**, called once a day for every
country from `CCountry`'s daily pass (`0x4DA530`, at `0x4DBBC2`). For each province in the
country's list at `+0xD00` it takes the effective revolt risk through
`GetProvinceEffectiveRevoltRisk` (`0x4A4050`), floors it at `MINIMUM_REVOLT_RISK`, and passes
**two** independent rolls before it spawns anything: `Random() % 10000 < round(risk/50)` and
then `Random() % 365 == 0`. The second roll is what makes revolts almost never happen: over a
whole year the two together come to **`effective_revolt_risk_in_percentage_points / 500`**,
and to half that for an AI country. `rebel_types.txt`'s `spawn_chance` is **not** a dead key -
it is the *rebel type selector*, evaluated as a `CMeanTimeToHappen` by `0x4C0430`, and the type
with the largest value wins. The steady stream of partisans a player actually sees does not
come from the roll at all: it comes from `0x50A110`, the underground pass, which spawns
partisans **deterministically** every day an underground is at or above `SPAWN_PARTISAN_LIMIT`
and its `underground_action` is 0.

---

## 1. The roll: `0x4C07C0`

`0x4C07C0` (rva `0xC07C0`, `0x4C07C0`..`0x4C0B41`, `f(CCountry*)` on the stack, `ret 4`).
It has exactly **one** caller, `0x4DBBC2`, which `FINDINGS-politics.md` already records in
`0x4DA530`'s callee table as *"unread; every non-`REB` country that owns provinces"*. So it is
**daily, on the game thread, once per country**.

    void RunDailyRevoltRoll(CCountry* country)              ; 0x4C07C0
    {
        if (country->NumberOfOwnedProvinces <= 0) return             ; +0xCF8, 0x4C07E3
        gs = GetGameState()                                          ; inlined, 0x4C07EF
        if (!gs->in_game) return                                     ; +0xDA4, 0x4C0862
        if (gs->scenario != 0                                        ; +0xD0C
            && !CountryIdListContains(gs->scenario + 0x78,
                                      country->tag.id))  return      ; 0x4A8630, 0x4C0881
        for (node = country->province_ids; node; node = node[2])      ; +0xD00, 0x4C092A
        {
            province = gs->provinces[node[0]]                        ; +0xB8C, 0x4C09C8
            if (!province->area->slot0())          continue          ; +0x2B4, 0x4C09D8
            denom = 10000                                            ; 0x4C09E7
            if (gs->playedByHuman[country->tag.id] == 0)             ; +0xBCC, 0x4C0A78
                denom = 20000
            risk = GetProvinceEffectiveRevoltRisk(province)           ; 0x4A4050, 0x4C0A87
            risk = max(risk, max(province->values[MINIMUM_REVOLT_RISK], 0))
            threshold = (int)( (int64)floorf(20000.5) * risk / 1000 / 1000.0 )
                      = round(risk / 50)                             ; 0x4C0AA8..0x4C0AF3
            if (Random() % denom >= threshold)     continue          ; 0x4C0AF6
            if (Random() % 365    != 0)            continue          ; 0x4C0B03
            SpawnRebelsOfChosenTypeInProvince(province@ESI, "---"@EDI, 3)
                                                                     ; 0x4C1110, 0x4C0B23
        }
    }

Every line of that is read out of the bytes. The two constants are worth spelling out:

- **`[0x160AAE0]` is the float `20000.5`** and `[0x160A300]` the double `1000.0`, so the whole
  of `0x4C0AA8`..`0x4C0AF3` is `threshold = round(revolt_risk_thousandths / 50)`. There is no
  `defines.lua` entry anywhere in it; the 20000.5 is compiled in, exactly like the `100.5` /
  `200.5` pair `FINDINGS-occupation.md` found behind the daily step, and like them it is a
  generic constant that must not be named after revolt.
- **`0x16D` is 365** and the test is `remainder == 0`, so the second gate is a flat 1-in-365
  every day. The bytes at `0x4C0AF6` are
  `e8 85 24 5e 00 | 99 | f7 7d e4 | 3b d7 | 7d 25 | e8 78 24 5e 00 | 99 | b9 6d 01 00 00 |
  f7 f9 | 85 d2 | 75 14 | 6a 03 | ... | e8 e8 05 00 00`, which is the whole thing: two
  `call Random`, two `idiv`, two skips, `push 3`, `call 0x4C1110`.

### 1.1 What that comes to

Because the second gate is a flat 1/365 and the first is independent of it, the probability
that a given province revolts **in a year** is simply `threshold / denom`, and

    P(revolt in a province per year) = effective_revolt_risk_in_points / 500     (human)
                                     = effective_revolt_risk_in_points / 1000    (AI)

| effective revolt risk | per province-day | per province-year (human) | (AI) |
| --- | --- | --- | --- |
| 1 point | 5.5e-6 | 0.20 % | 0.10 % |
| 5 points | 2.7e-5 | 1.0 % | 0.5 % |
| 10 points | 5.5e-5 | 2.0 % | 1.0 % |
| 25 points | 1.4e-4 | 5.0 % | 2.5 % |
| 47 points | 2.6e-4 | 9.4 % | 4.7 % |

The last row is BlackICE's worst case: `total_exploitation` gives `local_partisan_support = 25`
(the cap on the accumulator) and `local_revolt_risk = 22`, so about 47 points before
suppression. **That is a one-in-ten chance per province per year, and the mod should not expect
this path to produce partisans.** Anything below `0.025` points rounds `threshold` to zero and
makes a revolt outright impossible, since `fistp` rounds to nearest.

Two hard-coded asymmetries fall out of the same read and neither is in any script file:

- **An AI country gets exactly half a human's revolt chance.** `CCurrentGameState +0xBCC` is
  already in `CLASSES.md` as *"one entry per country id, non zero for one somebody is
  playing"*; a zero there doubles the denominator to 20000 (`0x4C0A7D`).
- **A scenario can switch revolts off for a country.** When `gameState +0xD0C` (the scenario)
  is set, a country whose id is not in the list at `scenario + 0x78` never rolls at all
  (`0x4A8630`, a nine-instruction "is this id in the list" walker, `eax` = the list head,
  `ecx` = the `CCountryTag*`).

### 1.2 `Random()` and why the sign does not bite

`0xAA2F80` (rva `0x6A2F80`) is the engine's `Random()`: it makes the global generator object at
`[0x174DA90]` if it does not exist, bumps the draw counter `g_random_draws` (`0x174DA8C`), and
tail-jumps to `0xAA2B90` with the MT19937 state `g_random_seed` (`0x1710F80`) in `eax`.
`0xAA2B90` (rva `0x6A2B90`) is the tempering, and the index is at `state + 0x9C0` - which is
`0x1711940`, which is the address `project.json` already had for the generator state. `0xAA2C80` is the twist. Three thin wrappers sit
beside it: `0xAA2B20` returns a float in `[0,1)` (mask `0x7FFFFFFF`, multiply by the `2^-31` at
`0x160A2B8`), and `0xAA2B50` / `0xAA2FD0` return `(r % 1000) * 1000 / 1000000` as a thousandths
fraction. `0xAA2ED0` reseeds from `[0x174DA94]` and is called from `RunHourlyTick` (`0x681C79`)
and `0x6D7BF2`.

`Random()` is used everywhere as `Random() % N` with a **signed** `idiv` and no `abs`, which
would let a negative draw pass any `< threshold` test about half the time. **It cannot happen
here**: this MT19937 is modified in two visible ways.

- **Both right shifts in the tempering are arithmetic** (`sar edx, 0xb` at `0xAA2BAD` and
  `sar eax, 0x12` at `0xAA2BD7`), so `y ^= y>>11` already clears bit 31 and `y ^= y>>18` clears
  it again - the returned value is always in `[0, 0x7FFFFFFF]`. That is also why `0xAA2B20`
  bothers to mask: the masking is redundant, and whoever wrote `0xAA2B20` did not know it.
  **Do not "fix" a `% N` site on the theory that the draw can be negative.**
- **The twist constant is `0x9908B0DF`, not the standard `0x9908B00D`** - `xor edx, 0x9908b0df`
  at `0xAA2CE5`, `0xAA2D34`, `0xAA2D81` and `0xAA2DCF`, the four copies of the unrolled loop -
  and the twist's `y >> 1` is `sar` as well (`0xAA2CCA`, `0xAA2D19`, `0xAA2D67`, `0xAA2DB4`).
  Anyone reimplementing the game's RNG to predict a roll or reproduce a save must use
  `0x9908B0DF` and arithmetic shifts or the sequence will not match.

### 1.3 Exhaustion: every candidate, enumerated

This is the part that makes the answer an answer rather than a guess. Everything below was
enumerated by brute force over `.text` (every `E8`/`E9` whose target is the function) or by
decoding each `int3`-delimited entry and indexing every `[reg + disp]` operand, never by
linear-decoding the section.

**Every caller of `GetProvinceEffectiveRevoltRisk` (`0x4A4050`)** - 20 call sites in 10
functions, which is more than the predecessor's six:

| function | sites | what it is |
| --- | --- | --- |
| `0x49F3E0` `RebuildProvinceModifierValues` | `0x4A0520`, `0x4A05C1` | **the `revolt_risk` static modifier** - section 3 |
| `0x4C07C0` | `0x4C0A87` | **the roll** |
| `0x601230` | 4 | UI |
| `0x601B70` | 3 | UI (the province view; also reads `+0x328` directly) |
| `0x6DED60` | 2 | UI |
| `0x865C40` | 4 | UI |
| `0x8B9710` | `0x8B9D46` | AI |
| `0x8E1160` | `0x8E1AA6` | AI |
| `0x9E6940` `CPureRevoltRiskTrigger::Evaluate` | 1 | script |
| `0x9E7590` `CRevoltRiskTrigger::Evaluate` | 1 | script |

Neither AI reader calls `0x4C1160`, `0x4C1110`, `0x4BAA20` or `0x4A6C30`, so neither can spawn.

**Every `[reg + 0x328]` site in the image** - 51, in 33 functions. The ones where the register
really is a `CProvince`: `0x494C10` / `0x496480` / `0x495880` / `0x49AD50` / `0x49CC40` (save
and load), `0x49EAB0` `RunDailyProvincePass` (the six sites of the daily step already read),
`0x4A4050`, `0x4A40E0` `GetProvinceRawRevoltRisk`, **`0x4A40F0` (a setter - below)**,
`0x4A4250` (a UI text builder, one caller at `0x6E678D`), `0x4A6C30`
`SpawnFullRevoltInProvince`, and then UI (`0x601B70`, `0x65CBB0`, `0x61A340`, `0x63C520`,
`0x6474A0`, `0x6F6E00`, `0x7FD520`, `0x84EDE0`, `0x9D1590`, `0xA874E0`, `0xB460F0` and the
rest). `0x5307A0` is combat and its `+0x328` is not a province.

**`0x4A40F0`** (rva `0xA40F0`) is the missing half of the pair: `SetProvinceRevoltRisk(CProvince*
province, int value, bool announce)`, `ret 0xC`. It writes `max(value, 0)` into `+0x328` and,
when `announce`, allocates 0x18 bytes through `0x5FE2D0` and reports the change. Its four call
sites are `0x4C1301` (inside `CreateRebelBrigadesInProvince`), `0x5FE3EB`, `0x5FE410` and
`0x9A55E3`. The first one matters: **creating rebel brigades in a province sets its revolt risk
back to 0** - `SetProvinceRevoltRisk(province, 0, false)`.

**Every function in the image with an inlined MT19937 draw** - 20, found by indexing every
reference to the index at `0x1711940` and the state at `0x1710F80`: `0x49EAB0`
`RunDailyProvincePass`, `0x4BAA20` `CreateRebelsForFaction`, `0x4FC100` (elections),
`0x50A110` (the underground pass), `0x52FD40`, `0x5601A0`, `0x560600`, `0x5608A0`, `0x560B90`,
`0x5631E0`, `0x5637C0`, `0x5649A0`, `0x566E70`, `0x567250`, `0x567930`, `0x56B910`, `0x56D790`,
`0x57B2A0` (all combat), `0x9C0920` (the daily event pass) and `0xAA2ED0` (the reseed itself).

**`RunDailyProvincePass` does draw a random number, and it is not the revolt roll.** The three
draws at `0x49EFBD`..`0x49F06B` sit inside a block gated on `province->+0x20 == 1`,
`province->area->slot0()` and `area->+0x68`, and the drawn value is written into a stack
`CEventScope` beside the string `'on_encirclement'` (`0x15BE94C`, pushed at `0x49F036`). It is
the **encirclement on_action**, not a revolt. Nothing in `0x49EAB0` past the revolt-risk block
at `0x49EED6` touches `+0x328` again.

**Every caller of `Random()`** (`0xAA2F80`) - 61 sites in 36 functions. The four in the rebel
block are `0x4B99D0` (`0x4B9A8F`), `0x4B9D60` `RunDailyRebelFactionPass` (`0x4BA9D4`),
`0x4BCBB0` and `0x4C07C0`. Nothing else in the image both reads revolt risk and draws.

**Every caller of `SpawnFullRevoltInProvince` (`0x4A6C30`)** - exactly one, `0x65BF81`, as the
predecessor had it. **Every caller of `CreateRebelBrigadesInProvince` (`0x4C1160`)** - five:
`0x43DF5A` (a console handler, section 5), `0x4C114E` (from `0x4C1110`, the roll's spawn),
`0x50B92B` (`SpawnPartisansFromUnderground`), `0x99F5B5` (`CCreateRebelsEffect::Execute`) and
`0x9A4F2E` (`CCreateRevoltEffect::Execute`). **Every caller of `CreateRebelsForFaction`
(`0x4BAA20`)** - three: `0x4A6D38` (inside `0x4A6C30`), `0x4C134A` (inside `0x4C1160`) and
`0x686EE7`.

So the complete set of ways rebel brigades come into existence in this build is: the daily
roll, the underground pass, the full-province revolt from the screen, the two script effects,
and one console handler. **There is no other tick that consumes revolt risk.**

### 1.4 `0x4C1110`, the roll's spawn

`0x4C1110` (rva `0xC1110`), **register convention** - province in `esi`, `CCountryTag*` in
`edi`, brigade count on the stack, `ret 4`. Two callers: `0x4C0B23` (the roll) and `0x43E03F`.

    if (!province->area->slot0())            return       ; +0x2B4
    if (!province->path_node->+0x13D)        return       ; +0xD4, the CProvinceTemplate flag
    type = ChooseRebelTypeForProvince(GetRebelTypeDatabase(), province, false, tag)
    CreateRebelBrigadesInProvince(this=province, type, count, false, tag)

`0x4BFE70` (rva `0xBFE70`) is a **six-line lazy getter for the global at `0x1A871D8`** - it
takes no arguments and ends in a bare `ret` at `0x4BFECF`, and `0x4BFED0` is a different
function abutting it with no `int3` between. That matters: the three pushes at `0x4C1136`..
`0x4C1138` survive the `call 0x4BFE70`, so with the `push eax` that follows they are
`0x4C0430`'s four arguments. `FINDINGS-occupation.md` read the same shape correctly at
`0x50B630`.

**Correction to the record.** `FINDINGS-occupation.md` calls `0x4C1160`'s first argument
`faction`. It is a **`CRebelType*`**: `0x4C12EF` passes it straight to
`FindRebelFactionForProvince` (`0x686CF0`), which the same document says matches a faction by
its `+0x30` - the type. The same document's own reading of `0x686CF0` is right; only the
argument name on `0x4C1160` is wrong.

---

## 2. `spawn_chance` is the rebel type selector, not a dead key

`CRebelType +0x28` and `+0x44` are both **embedded `CMeanTimeToHappen` objects** (0x1C bytes,
vftable `0x15F5CB8`, RTTI `CMeanTimeToHappen : CPersistent`). The constructor
(`CRebelType::CRebelType`, the only writer of `CRebelType`'s vftable `0x15C0BC8`, at
`0x4BEF3E`) writes that vftable into `+0x28` at `0x4BEF6B` and into `+0x44` at `0x4BEF85`, with
the persistent id `0x18D` beside each. `CRebelType::LoadKey` (`0x4BFA40`) hands the parse
context to slot 3 of each (`0x4BFCA8` for `spawn_chance`, `0x4BFCC8` for
`movement_evaluation`).

`CMeanTimeToHappen` has two evaluators, and this is the whole of it:

| | rva | callers |
| --- | --- | --- |
| `CMeanTimeToHappen::GetChance` | `0x5C4AB0` | **one**: `0x9C0B85`, the daily event pass. Its address appears nowhere as data, so there is no indirect call either. |
| `CMeanTimeToHappen::GetDays` (`0x9C4B90`) | `0x5C4B90` | 13 sites in 5 functions: `0x45CF8F`, **`0x4B9B4F` and `0x4B9C9F`**, **`0x4C0676`**, `0x9C0F0D`/`0x9C0FFD` (`FireEvent`), and seven in `0x9C56B0` (decisions) |

`0x9C4B90` is `int* __fastcall CMeanTimeToHappen::GetDays(CMeanTimeToHappen* this@EAX, int*
out@EDI, CEventScope* scope)`, `ret 4`:

    *out = this->days * 1000                                     ; +0x8
    for (m = this->modifiers; m; m = m->next)                    ; +0xC, next at +0x8
        if (m->condition->slot6(scope))                          ; [[m]] + 0x18
            *out = *out * m->factor / 1000                       ; [m] + 0x40, thousandths

**`0x4C0676` passes `rebelType + 0x28`.** So `spawn_chance` *is* evaluated. The function around
it is:

    CRebelType* __stdcall ChooseRebelTypeForProvince(       ; 0x4C0430 (rva 0xC0430), ret 0x10
            CRebelTypeDatabase* db, CMapProvince* province,
            bool allowTriggeredOnly, CCountryTag* tag)
    {
        if (province->controller_tag == 'REB') {                  ; +0x334, 0x4C0456
            f = 0x686C60(province)                                ; the faction already there
            if (f) return f->type;                                ; +0x30
        }
        build a CEventScope on the stack (vftable 0x15B8AEC, persistent id 0x18D);
        its country is *tag when allowTriggeredOnly, else the province's owner
        (+0x32C/+0x330), and its province is province->id (+0xD0)
        best = 0; chosen = 0
        for (type in db->+0xC .. db->+0x10)                       ; a vector<CRebelType*>
        {
            if (type->is_triggered_only && !allowTriggeredOnly) continue   ; +0x19C, 0x4C063B
            if (type->independence != 0) {                        ; +0x190
                0x4BF6F0(type, &area, province)
                if (area.+0x4 == 0) continue                      ; no such country/area
            }
            days = CMeanTimeToHappen::GetDays(&type->spawn_chance, &scope)  ; 0x4C0676
            if (days > best) { best = days; chosen = type; }      ; 0x4C0681
        }
        return chosen
    }

**The rebel type with the largest `spawn_chance` value wins**, and the mod's own comment in
`common/rebel_types.txt` - *"The rebel type with the highest modifier for this province gets
picked"* - says exactly that. So the record's comment on `CRebelType +0x28` ("Nothing was
found...") should be replaced; see *Contradictions*. Four consequences a modder can use:

- **A `modifier` with `factor = 0.0` whose condition holds vetoes the type entirely**, because
  the accumulator is multiplicative and `best` starts at 0 with a strict `>`. `partisans`
  carries `factor = 0.0` for `controlled_by = owner`, for `has_building = underground` and for
  `not = { infra = 2 }`, which is why a province the owner controls, or one with an
  underground, or one with infrastructure below 2, never gets partisans from the roll.
- **If every type scores 0, no type is chosen**, `0x4C1160` gets a null `CRebelType*`,
  `0x686CF0` finds no faction and the call logs and returns. Nothing spawns and nothing breaks.
- **The top-level `factor` is the base**, in thousandths, so `factor = 15` is 15000 and the
  comparison between types is on that scale. Only the ordering matters; the magnitude does not.
- **`CRebelType +0x19C` is `is_triggered_only`**, which `fieldmap.py` could not place. Read out
  of the loader: the switch's jump table is at `0x4BFD9C` with a byte index table at `0x4BFDD8`
  and a base of `eax - 0x61D` (`0x4BFB72`), so token `0x61D` is index 0 and lands at `0x4BFD7A`,
  `add edi, 0x19C; push edi; call 0xA7B410` - the same bool parser every other byte key uses.
  Only `ChooseRebelTypeForProvince`'s `allowTriggeredOnly` argument lets such a type be picked,
  and the only caller that passes `true` is the underground spawn (`0x50B920`). That is exactly
  why BlackICE's `organized_partisans` is `is_triggered_only = yes` with `factor = 10.0` on
  `has_building = underground`: it is the underground's type and nothing else can draw it.

`movement_evaluation` (`+0x44`) is evaluated the same way, in `0x4B99D0` at `0x4B9B4F` and
`0x4B9C9F`, with `edi = faction->type` (`0x4B9AE3`). That function is called from
`RunDailyRebelFactionPass` at `0x4BA238` and is the rebel army's per-province move scoring; the
same `factor = 0.0 / not = { infra = 2 }` veto applies there.

---

## 3. `0x49F3E0`: what the rest of the province rebuild does

`0x49F3E0` (rva `0x9F3E0`) is already named `RebuildProvinceModifierValues` in the record.
Its real extent is `0x49F3E0`..`0x4A068B` (`int3` padding at `0x49F3D3`..`0x49F3E0` and
`0x4A068C`..`0x4A0690`); it has two `ret 4`s, at `0x4A0673` and `0x4A0689`, both in the same
frame. It has **15 call sites in 12 functions**, of which `RunMonthlyPass` (`0x683B9A`) and
`RunDailyProvincePass` (`0x49EE0A`) are the two on a tick; the others are the screen
(`0x65AFA8`, `0x65BF7A`, `0x65BFF1`, `0x65C00F`), `ApplyCustomGameSettings` (`0x41E050`), the
building-level change `0x4A39B0` and five more. So it is a rebuild callable from anywhere, not
"the province's monthly work".

**Its two working variables**, both spilled early and used throughout:

- `[esp+0x10]` = `province + 0xFC`, the `CProvinceModifier` the record already names. Its
  values array is at `+0x18`, which is `province + 0x114` - **that is where `+0x114` comes
  from**, and the entries are 8 bytes (`id * 8`). Its `+0x8`/`+0xC`/`+0x10` are a vector of
  every contributing `CModifier*`, rebuilt at the same time, which is what the tooltip reads.
- `[esp+0x14]` = the lazily built singleton at **`[0x1A86208]`**, 0xBC bytes, made by
  `operator new(0xBC)` and `0x45BD30` at `0x49F40D`..`0x49F43E` and installed by `0x45C440`.
  `0x45BD30` gives it a 0x1FF-bucket hash at `+0x0`/`+0x4`/`+0x8` and an empty vector at
  `+0xC`/`+0x10`/`+0x14`; everything from `+0x18` up is a named `CStaticModifier*`. **This is
  `common/static_modifiers.txt`'s database.** It has no RTTI and its constructor writes no
  vftable, so no struct is declared for it here - only the global is recorded.

The function clears `province + 0xFC` (`0x4595C0`) and `province + 0x12C` (`0x4B6260`), then
adds, in order:

| at | what |
| --- | --- |
| `0x49F490`..`0x49F521` | **every building in the province** (`+0x310`..`+0x314`): scales the building's own modifier by `level_current * definition->+0x24 / 1000` and adds it at the id in `definition->+0x24` |
| `0x49F595` | static `+0x1C`, when the province's area differs from its controller's *and* `province->+0x368` differs from the controller's - i.e. **`overseas`** |
| `0x49F686` | static `+0x34`, when the area is not core to the controller (`0x47E540(area, tag, id) == 0`) and the owner/`+0x354`/`+0x300` gate at `0x49F643` passes |
| `0x49F765`, `0x49F826`, `0x49F8C4`, `0x49F91A`, `0x49FABC`, `0x49FD5E`, `0x49FE99`, `0x49FFC0` | statics `+0x4C`, `+0x20`, `+0x24`, `+0x28`, `+0x2C`, `+0x34` again, `+0x38`, `+0x3C` - the terrain / coast / blockade family, each added flat |
| `0x49FB4B`..`0x49FFAC` | eight `0xB94936` / `0x4C0700` pairs - the timed and conditional province modifiers |
| `0x49FBE2` | **the occupation policy**, as `FINDINGS-occupation.md` read it |
| `0x4A0010`..`0x4A00EB` | static `+0x40` **scaled by `province->manpower` (`+0x320`)** and only when that is positive - the `manpower` static modifier |
| `0x4A0204`..`0x4A02C0` | static `+0x44`, only when `controller_id == owner_id` (`0x4A01F8`) and the province is not in the list at `+0x344`; the block at `0x4A0305` then walks `province + 0x13C`, ages each entry with the `0x29C55C0` epoch and the `365.0` at `0x160A550`, and drops it past a year. This is the **`nationalism`** family |
| `0x4A03E6`..`0x4A047F` | `province->+0x378` caches `values[MODIFIER_RADAR_LEVEL]` (id `0x30`, so `+0x180`); crossing 1000 in either direction calls `0x4DD250` or `0x4DD370` on the controller with `province->id`. **Nothing to do with revolt** |
| `0x4A051C`..`0x4A0689` | **the `revolt_risk` static modifier** |

The last block is the one this document cares about:

    0x4A051C  lea   esi, [esp+0x28]
    0x4A0520  call  0x4A4050                       ; effective revolt risk
    0x4A0525  ...   floor at max(values[MINIMUM_REVOLT_RISK], 0)
    0x4A053D  jle   0x4A0678                       ; <= 0 -> nothing
    0x4A0543  eax = statics->+0x48                 ; the static modifier
    0x4A0550  je    0x4A0678                       ; not declared -> nothing
              copy it into a fresh CStaticModifier (0x48 bytes, vftable 0x15BC568,
              +0x40 = 0xF, +0x3C = 0), name and all, via 0x45A020 and 0x401BD0
    0x4A05C1  call  0x4A4050 again, floor again
    0x4A05DB  call  0x45A080(copy, thatValue)      ; values[id] = values[id] * v / 1000
    0x4A05E0  for id in 0 .. modifierCount: provinceValues[id] += copy->values[id]
    0x4A0621  push_back the copy into province->+0xFC's contributor list

So **`static_modifiers.txt`'s `revolt_risk` block is multiplied by the province's effective
revolt risk in percentage points** and added to the province's modifiers, freshly every
rebuild. BlackICE's `revolt_risk = { local_ic = -0.02, local_manpower_modifier = -0.02,
local_resources = -0.02 }` therefore means **-2 % IC, manpower and resources per point of
revolt risk** - at 47 points that is `-94 %` of each, which is a far bigger effect on an
occupied province than the revolt roll will ever be. `+0x40 = 0xF` on the copy is a source tag
the tooltip uses; the `manpower` and `nationalism` copies write it identically, so it is not
revolt-specific.

`0x4A4050` is called **twice** with the same arguments, three instructions apart, and the first
result is only used for the `> 0` test. That is the compiler failing to common them, not two
different figures.

**On naming the static modifier slots.** `+0x40` and `+0x48` are pinned by what the engine
scales them with (the province's manpower and its revolt risk), and `+0x44` by the year
arithmetic; those three are safe. The field order does **not** follow the file's order - if it
did, `+0x48` would be `nationalism` - so the other slots are left unnamed, and nothing in the
image reads `+0x30`.

---

## 4. The underground pass, `0x50A110` - where partisans actually come from

`0x50A110` (rva `0x10A110`, `0x50A110`..`0x50AE40`, `f(CCountry*)` on the stack) is called
unconditionally from `CCountry`'s daily pass at `0x4DBB64`. It walks the list at
`CCountry +0xD60` (nodes `{ province id, ?, next }`) and for each province does three things.

**1. Grow the underground.**

    factor = province->values[MODIFIER_LOCAL_PARTISAN_SUPPORT] * 10 / 1000 + 1000
                                                        ; [[p+0x114]+0x260], 0x50A278
    gain   = factor * UNDERGROUND_STRENGTH_GAIN / 1000   ; defines military +0x258
    u = province->underground                            ; +0x30C
    u->level_current += gain                             ; +0x24
    if (u->level_current > u->level_max) u->level_current = u->level_max   ; +0x20
    u->+0x28 = (it changed)                              ; the dirty byte

so **growth per day is `UNDERGROUND_STRENGTH_GAIN * (1 + local_partisan_support / 100)`**, with
`local_partisan_support` in percentage points - a point of partisan support is a flat +1 % on
underground growth and nothing more. BlackICE sets `UNDERGROUND_STRENGTH_GAIN = 0.05` against
vanilla's `0.01`, so undergrounds there grow five times as fast.

**2. Roll for detection.**

    threshold = round( province->suppression * UNDERGROUND_DETECT_CHANCE / 1000 / 1000.0 )
                                                        ; +0x28, defines military +0x25C
    if (Random() % 1000 < threshold)  -> the underground is removed

`P(detected per day) = suppression * UNDERGROUND_DETECT_CHANCE / 1e9`, both stored in
thousandths. This is the reader `FINDINGS-occupation.md` found but could not rate. The detected
provinces go on a stack list which the tail of the function (`0x50AD1E` onwards) turns into the
`OURUNDERGROUNDREMOVED` / `UNDERGROUNDREMOVED` messages. **The absolute rate depends on the
units of `CProvince +0x28`, which is still unmeasured** - if the predecessor's reading is right
(a `suppression = 2.0` brigade at full strength lands as 200), then with
`UNDERGROUND_DETECT_CHANCE = 2` one such brigade gives `threshold = round(0.4) = 0`, i.e. no
detection at all, and it takes about five such brigades before detection becomes possible.

**3. Act on `underground_action`.** `CProvince +0x394` is already in the record as
`underground_action`, and `0x50AC4E` is the switch that gives the three values their meaning:

| `underground_action` | at | what happens every day |
| --- | --- | --- |
| **0** | `0x50AC74` | if `CanMobilizePartisans(country, province)` the province is pushed onto a vector; after the loop, `SpawnPartisansFromUnderground(country, province)` (`0x50B630`) runs for each one, at `0x50AD08` |
| **1** | `0x50AC5B` | if `CanSpawnUnderground(country, province)` then `0x50BD00(province)` - a new underground somewhere else, and it draws its own random number at `0x50BD8D` |
| **2** or more | - | nothing. The record already notes 2 is the default and is not saved |

and a province whose controller is back to its owner (`+0x338 == +0x330`, `0x50ABFE`) goes on
the removal list instead, so **liberating a province removes the underground in it**.

The two predicates are twins, `country@EAX, province@ESI`, bare `ret`, returning `bool`:

    0x50B450  CanMobilizePartisans:   province->id in country->+0xD60
                                      && ( [0x1A85599] != 0
                                           || province->underground->level_current
                                              >= SPAWN_PARTISAN_LIMIT )
    0x50BB20  CanSpawnUnderground:    the same, with SPAWN_UNDERGROUND_LIMIT and no bypass

`[0x1A85599]` is a one-byte global that bypasses the level requirement - almost certainly a
cheat or debug switch; it is not read as a define and no writer was found.

**This is the path that produces partisans in practice, and it has no roll at all.** An
underground on action 0, at or above `SPAWN_PARTISAN_LIMIT`, spawns partisans *every single
day*, each spawn burning `SPAWN_PARTISAN_LIMIT` levels off it (`FINDINGS-occupation.md`
section 2). With BlackICE's `UNDERGROUND_STRENGTH_GAIN = 0.05` and `SPAWN_PARTISAN_LIMIT = 10`
that is one wave per 200 days at zero partisan support, and it is the number to tune if
partisans feel wrong - not revolt risk.

---

## 5. The other three ways rebels appear

**`CCreateRebelsEffect::Execute`** (`0x99F480`, rva `0x59F480`, slot 11 of vftable
`0x15F4AA8`):

    province = gameState->provinces[scope->+0x28]
    count    = province->manpower * effect->+0x20 / 1000 / 1000      ; 0x99F535..0x99F567
    CreateRebelBrigadesInProvince(province, effect->+0x24, count, false, "---")

so **`create_rebels` names its own rebel type (`+0x24`), bypassing `spawn_chance` entirely**,
and its value scales the count by the province's manpower.

**`CCreateRevoltEffect::Execute`** (`0x9A4DD0`, rva `0x5A4DD0`, slot 11 of vftable
`0x15F4A70`) is the scripted twin of the roll's spawn: the same `slot0()` and `+0x13D` gates,
then `ChooseRebelTypeForProvince(db, province, false, tag)` and
`CreateRebelBrigadesInProvince`. So **`create_revolt` goes through `spawn_chance` and
`create_rebels` does not.**

**`0x43DDE0`** (rva `0x3DDE0`) is a genuine function start (padded at `0x43DDD8`) with **no
call site and no vftable slot anywhere in the image**. It takes a `std::string*` out parameter,
parses two integers with `0xB969F1`, resets the byte at `[0x1A87280]` through `0x4C0780`, and
then calls either `CreateRebelBrigadesInProvince` (`0x43DF5A`) or `0x4C1110` (`0x43E03F`).
That shape is a **console command handler** registered at runtime, which is why nothing
references it. It is recorded as `likely`, with no name beyond "spawns rebels and returns a
text reply".

---

## What is not established

- **Why the 1-in-365 gate is there.** It is unambiguous in the bytes and it dominates the
  result, but there is nothing to say whether it was meant as "about once a year" on top of a
  per-day risk or is a mistake. Nothing else in the image pairs two gates this way.
- **Whether `CCountry +0xD00` is owned or controlled provinces.** `FINDINGS-ic.md` already
  flags this. `CLASSES.md` names `OwnedProvinces` at `+0xCF0` with its count at `+0xCF8`, so
  `+0xD00` is a *second* list, and a revolt pass over the provinces a country **controls** is
  what the rest of the revolt model implies - the accumulator only moves where controller and
  owner differ. That is a second piece of circumstantial evidence for "controlled", not proof.
- **The names of static modifiers `+0x1C`, `+0x20`, `+0x24`, `+0x28`, `+0x2C`, `+0x34`,
  `+0x38`, `+0x3C`.** Pinned only by their conditions, and the field order does not follow the
  file order.
- **The exact scale `0x4A0204` applies** to the nationalism copy: the value is in `edi` and is
  set before `0x4A0130`, which was not traced.
- **`0x4BAA20`'s body** past the argument clamp, still. Its inlined MT draw at `0x4BADED` was
  not followed; it is after the `MODIFIER_PARTISAN_EFFICENCY` read, so it is probably the
  brigade strength or the target province, not a go/no-go.
- **`0x4B98D0`**, still. It has 16 call sites in 6 functions, including
  `CCombatManager::CheckForCombat`, which suggests a "are these two at war over this province"
  predicate rather than anything revolt-specific.
- **`CProvince +0x60` / `+0x64`**, still. `ChooseRebelTypeForProvince` is *not* what fills
  `+0x60` - it returns its answer and stores nothing - so `SpawnFullRevoltInProvince`'s
  dependence on `+0x60` being set is as unexplained as the predecessor left it.
- **`CProvince +0x28`'s units**, still unmeasured, and the underground detection rate rests on
  it.
- **`[0x1A87280]`**, the one-byte global `0x4C0780` resets and the daily pass tests at
  `0x4DBB69`. `0x4C0780` has five call sites in four functions, all in the rebel block, but it
  is the generic auto_ptr-reset idiom and is deliberately not named here.
- **`0x4A4250`** (a UI text builder reading `+0x328` twice), **`0x686D80`** and **`0xAA2BF0`**
  (the RNG initialiser) were not read.

## Contradictions with the existing record

- **`CRebelType +0x28 spawn_chance`.** The record's comment says *"Nothing was found that
  reads it"*. It **is** read, at `0x4C0670`, by `ChooseRebelTypeForProvince` (`0x4C0430`)
  through `CMeanTimeToHappen::GetDays` (`0x9C4B90`), and it is what picks the rebel type. The
  field is not redefined here; the comment needs replacing.
- **`0x4C1160`'s first argument** is named `faction` in `FINDINGS-occupation.md`. It is a
  `CRebelType*` (`0x4C12EF` hands it to `FindRebelFactionForProvince`). Nothing is redefined
  here.
- **`CCountry +0xCF8` is not unnamed.** `FINDINGS-occupation.md` says it is "not in the
  record" and guesses "province count". `CLASSES.md`'s `CList<T>` row already carries the
  game's own name for it - `NumberOfOwnedProvinces`, at `+0xCF8`, the count word of the
  `OwnedProvinces` list at `+0xCF0`. The guess was right and the name was already there.
- **`CMeanTimeToHappen` is not only for events and decisions.** The record's comment on the
  daily event pass and `CANDIDATES.md` treat `GetChance` as the evaluator. `GetChance` has one
  caller; the workhorse is `GetDays` (`0x9C4B90`), with 13 call sites, and it is what decisions,
  `FireEvent`, the rebel type choice and rebel movement all use. Nothing is redefined here.

## How this was found

Two scans, both built to avoid the traps the folder already records, in
`scratchpad/revolt/`:

- **A whole-image index built by decoding each `int3`-delimited entry from its own start**,
  recording every direct call target and every `[reg + disp]` operand. That is what made
  "every reader of `+0x328`" and "every function with an inlined MT draw" answerable. A first
  attempt split on *every* `0xCC` byte and produced fake function starts wherever a jump table
  held one; requiring the candidate to be 16-byte aligned or the padding run to be three bytes
  or longer fixed it, and cut 55,273 blobs to 36,003.
- **A brute-force `E8`/`E9` scan for callers**, independent of the index, so a call inside a
  block the index mis-split is still found. This is what turned up the eight `0x4A4050`
  callers the predecessor missed.

Three traps cost time and are worth recording:

- **`image.functionStart` and any padding-based split are wrong at an abutting pair, and there
  are more pairs than the record lists.** `0x4BFE70`/`0x4BFED0` and `0x4A6C10`/`0x4A6C30` both
  abut with a single `int3` or none; getting `0x4BFE70` wrong would have made `0x4C0430`'s
  argument list wrong, which is the whole of section 2. `0x4A6C10` is a three-instruction
  setter, *not* part of `SpawnFullRevoltInProvince`. Both were caught by looking at the bytes.
- **A function's start is not where its padding is.** `0x4DAFE0` and `0x4A0367` both look like
  entries because a jump table inside `0x4DA530` and inside `0x49F3E0` contains a `0xCC`.
  Neither is in a vftable and neither has a caller, which is the cheap test.
- **The engine's MT19937 uses arithmetic shifts in the tempering**, so `Random()` is always
  non-negative and the `% N` idiom that looks broken everywhere is not. Half an hour went into
  a bug that is not there - and the same read turned up the non-standard twist constant.


## Practical note for the mod

If BlackICE wants revolt risk to mean anything, the single highest-leverage change is at **`0x4C0B03`** — nop the `jne` after `Random() % 365` and the per-province chance goes from `risk/500` per *year* to `risk/500` per *day*, which is almost certainly too far the other way; a smaller divisor there is the tunable. Everything else about revolt risk already works and is well-scripted; it is that one gate that neuters it.
