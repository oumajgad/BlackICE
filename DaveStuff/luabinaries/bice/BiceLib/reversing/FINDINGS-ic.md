# How a country's IC is worked out

The function BiceLib has been patching blind since before this folder existed: rva
`0xF0CC0`, VA `0x4F0CC0`. It is **not** a method - it ends `ret 8` at `0x4F15BB` and
takes nothing in `ecx`:

    void __stdcall CCountry::UpdateIC(
        CCountry* country,          // [ebp+8], parked in ebx immediately
        bool applyDailyEffects)     // [ebp+0xC]

**Its extent is `0x4F0CC0`..`0x4F15BD`, 0x8FE bytes**, not the `0x740` the work queue
guessed. `0x4F15BB` is the `ret 8`, `0x4F15BE`/`0x4F15BF` are `int3` padding, and
`0x4F15C0` is a fresh prologue. Nothing abuts it at either end.

It returns nothing. Everything it does it writes into the `CCountry`.

## What it writes

| offset | | |
| --- | --- | --- |
| `+0x604` | the **finished total IC**, in whole IC, never below 1 | zeroed at entry, written three times |
| `+0x608` | the part of that total which came from **lend-lease** | zeroed at entry |
| `+0x60C` | the **province base**, in whole IC, *before* any modifier | zeroed at entry, written once |
| `+0x610` | the base of the core provinces in the capital's own area | zeroed at entry, added to per province |
| `+0x614` | how much IC a **resource shortage** cost, in thousandths, **negative** | written only when short |
| `+0x8B4`, `+0x8D8`, `+0x968` | three `CGoodsPool`s, all seven goods each, zeroed at entry from the constant at `0x1A87818` | |

`+0x604` and `+0x60C` are `GetTotalIC` and `GetMaxIC` in `CLASSES.md`, and BiceLib's
`CCountry.hpp` calls `+0x604` `base_ic`. **That name is on the wrong field.** The base is
`+0x60C`; `+0x604` is what is left after the global modifier, lend-lease and the resource
cap. Nothing here makes `+0x60C` a *maximum* either - it is simply the pre-modifier sum,
and it is smaller than `+0x604` for any country with a positive `GLOBAL_IC`.

## The province sum

The loop runs `0x4F0E41`..`0x4F0F7D` over the list at **`CCountry +0xD00`** - nodes of
`{ province id, ?, next }`, the id looked up in `CCurrentGameState +0xB8C`, the array of
every province by id. **Which set of provinces that list is, owned or controlled, is not
established here.**

A province contributes, at `0x4F0EFD`:

    values = [province + 0x114]                       // its CProvinceModifier's values
    contribution = values[IC] * (1000 + values[LOCAL_IC]) / 1000

`+0x114` is `CProvince +0xFC` (the `CProvinceModifier`) plus `CModifier +0x18` (the values
pointer) - already in `CLASSES.md`. `+0x78` of the values is entry 15, `MODIFIER_IC`;
`+0x80` is entry 16, `MODIFIER_LOCAL_IC`. So **`CMapProvince +0x330` is not what scales a
province's contribution at all** - the two modifier entries are, and `+0x330` only picks
which provinces also count towards `+0x610`.

Only a positive contribution is added to the running total (`0x4F0F72`, `jle`); a negative
one is dropped from the sum but still counted towards `+0x610`.

**Nothing here reads infrastructure, occupation, damage or resources.** Whatever
infrastructure and occupation do to a province's IC, they do it by moving
`values[MODIFIER_IC]` or `values[MODIFIER_LOCAL_IC]` before this runs, not here.

### `+0x330`, and what `+0x610` counts

`CProvince +0x32C` is the owner `CCountryTag` and `+0x334` the controller
(`CLASSES.md`); a tag's id is at `+0x4` of it. So `[province+0x330]` - the instruction
`Hook_OffmapIc_CountLocalIc` replaces - is the **owner's country id**, and the mod's own
comment on that hook ("per province, esi province, ebx country") never said what it was.

The three tests a province must pass to be added to `+0x610` are, at `0x4F0F2B`:

1. its owner id equals `CCountry +0xCA8`, this country's own id;
2. its `COwnerArea*` (`+0x2B4`) equals the acting capital's, via
   `CCountry::GetActingCapitalLocation` (`0x2F100`);
3. this country is in the province's `core` list (`+0x344`, key at `+0x4`, next at `+0xC`).

So `+0x610` is the IC of the **core home ground in the capital's own area**. It is read in
two places, `0x4F1C9E` and `0x51AC33`, neither of them named; the first checks
`CCurrentGameState +0xC9C` (arcade mode) and the capital's area first. **What the game
calls it is not established.**

## Where the sum starts, and the country-level scaling

The accumulator is **not** seeded at zero. At `0x4F0E27`:

    seed = [[[0x1A86208] + 0x64] + 0x18] + 0x78

`0x1A86208` is a lazily built `0xBC`-byte singleton (`0x45A380` builds it, `0x45C440`
assigns it, `0x45BD30` builds a 511-bucket map inside it). `0x4595C0` is handed it
together with a `CModifier` to recompute - `CCountry +0xD90` at `0x4DDDFE`, `CProvince
+0xFC` at `0x49F456` - so **it is the static-modifier database**, and entries in it are
`CModifier`s: `0x45A54A` allocates `0x48` bytes and calls the `CModifier` constructor
(`0x4593F0`), which also fixes **`sizeof(CModifier) = 0x48`**. `+0x18` is therefore a
values pointer and `+0x78` its `MODIFIER_IC`. **Which modifier `+0x64` is, is not
established** - only that one global modifier's `MODIFIER_IC` is added to every country's
province sum as a flat amount in thousandths.

Then, `0x4F0F85`..`0x4F0FF3`:

    base       = sum / 1000                          -> +0x604 and +0x60C
    multiplier = 1000 + countryValues[GLOBAL_IC] + technologyStatus[+0x90]
    total      = base * 1000 * multiplier / 1000 / 1000
    if total < 1: total = 1                          -> +0x604

`countryValues` is `CCountry +0xDA8`; `+0x88` of it is entry 17, `MODIFIER_GLOBAL_IC`.

**`CCountry +0xDF8` is a `CTechnologyStatus*`** - the constructor allocates `0x29C` bytes
and builds it at `0x4C9C64`/`0x4C9C8B` with `0x5311B0`, which writes vftable `0x15C35BC`,
and the RTTI export names that `CTechnologyStatus` (bases `CTechStatistics`,
`PAVCTechnology::__CArray`). Its `+0x90` is the technology IC bonus in thousandths; `+0x98`
is the energy-to-oil conversion bonus (below). The same pointer is read at `+0x10` by
`SupplyCapacity` (`0x49DE44`), beside `countryValues[SUPPLY_THROUGHPUT]`. BiceLib had
nothing on `+0xDF8`.

Note `base` is re-multiplied by 1000 at `0x4F0FA9` **after** being truncated to whole IC,
so the fractional part of the province sum is lost before the global modifier is applied.
That is the instruction the second byte patch sits on.

## The rest of the function, and what gates it

**The industry need**, `0x4F13E8`..`0x4F1462`, unconditional: `+0x968` is filled with
`total * 1.0` metal (`+0x18`), `total * 2.0` energy (`+0x1C`) and `total * 0.5` rares
(`+0x20`). `CLASSES.md` already had `+0x968` as "what the country's industry needs -
metal, energy and rares in 1 : 2 : 0.5 for every country without exception". **This is the
function that writes it**, and the ratio is three `imul`s by `0x3E8`, `0x7D0` and a divide
by `0x7D0`.

Two blocks run only when `applyDailyEffects` is true.

**The energy to crude-oil conversion**, `0x4F1075`..`0x4F13E2`. It is the half of the pair
`CLASSES.md` describes as "`+0x8D8` and `+0x8B4` are the conversion pair" and as "Germany
took 340 oil *and* 178 energy and made 781 fuel *and* 34 oil - synthetic oil from coal":
here energy is the input and **crude oil** the output. It sums the crude-oil (`pool+0x14`)
and energy (`pool+0x1C`) slots of fifteen of the 23 pools to get the day's balance in each,
takes the rate as `1 + 2 * technologyStatus[+0x98]`, caps the run at
`max(total_ic * 0.05, 1.0)` and at the energy left over after industry
(`stockpile energy - total_ic * 2`), then at `0x4F13C8` credits the stockpile's crude oil,
debits its energy, and records the pair in `+0x8B4` (`+0x14`) and `+0x8D8` (`+0x1C`).

`0x4F17F0` is the rate on its own, a separate int3-padded function, three callers, args in
registers:

    int* __fastcall CCountry::GetOilConversionRate(int* out@EAX, CCountry* country@EDX)
    *out = <the once-cached global 0x1A87478> + technologyStatus[+0x98]

**The resource cap and lend-lease**, `0x4F146E`..`0x4F15A5`:

- `0x4F15C0` (four callers, `country` in `esi`, out-param on the stack, `ret 4`) works out
  the IC the stockpile's metal and energy can actually support, from `pool+0x18` less
  `CCountry +0x95C` and `pool+0x1C` less `+0x960`. Where that is below `+0x604`,
  `+0x614` is set to `(limit - total) * 1000` and `+0x604` is cut to the limit.
- `+0x6E8` is `lend_lease_income` (`FINDINGS-fieldmap.md`, from `CCountry::LoadKey`), with
  `+0x6C8` `lend_lease_from` and `+0x6D8` `lend_lease_from_yesterday`. `+0x6E8 / 1000` is
  **added to `+0x604`** and stored on its own in `+0x608`. The two 12-byte-element vectors
  are then rolled over and drained.

`+0x608` is read five times, all in `0x518D67`..`0x51CEE9` - the `CDistribute*` production
allocation cluster another agent has. That is the connection: the sliders spend
`+0x604`, and the lend-lease share of it is `+0x608`.

`+0x614` is written in exactly two places in the whole image, this function and the
`CCountry` constructor (`0x4C8D25`), and **read nowhere** - no site in `.text` loads it.

## The callers want different things

| call site | in | flag |
| --- | --- | --- |
| `0x4DB442` | `0x4DA530`, the per-country daily economy pass | **1** |
| `0x4D633D` | `0x4D59D0`, reached once from `CInGameIdler::Enter` | 0 (`ebx`, the zero register) |
| `0x65B2C5` | `CInGameIdler::Enter` itself (`0x25A2B0`) | 0 |

`0x4DA530` takes a `CCountry*` and is called once, from `0x682E1A` - which is inside
**`RunDailyPass` (rva `0x282C20`)**, not `RunHourlyPass` (`0x282630`), although
`image.functionStart` says the latter: the two abut with no padding, the same trap
`FINDINGS-supply.md` records. `RunDailyPass` loops the country vector and calls `0x4E39C0`
then `0x4DA530` for each country whose `+0x44` is set.

So: **once a day the full pass runs; on entering a game it runs twice with the flag off**,
which recomputes `+0x604`, `+0x60C`, `+0x610` and `+0x968` without converting anything,
without the resource cap and **without lend-lease IC**. A `+0x604` read before the first
midnight of a loaded game is therefore missing its lend-lease share and its shortage cap.

## Where it sits among the named IC functions

Nothing else computes IC; they all read what this wrote.

- `CCountry::GetAvailableIC` (`0xF4D70`) is a loop of five: `GetSpareICIn` for categories
  1..5, summed, divided by 1000. It never touches `+0x604`.
- `CCountry::GetSpareICIn` (`0xF4B90`) and `GetUsedIC` (`0xF4B60`, over the construction
  list) are the spend side.
- `GetDailyIncome` / `Expense` / `Balance` / `Need` (`0xF1830`, `0xF1950`, `0xF18A0`,
  `0xF19A0`) work over the 23 goods pools - including `+0x8B4`, `+0x8D8` and `+0x968`,
  all three of which this function writes. So the daily figures for metal, energy, rares
  and crude oil are downstream of it.
- `CCountry::ConsumeIcResources` (`0xF16D0`, seven callers, `country` in `esi`, the IC in
  thousandths on the stack, `ret 4`) is the matching spend: energy x2, metal x1, rares
  x0.5 credited to `+0x98C` (`usage`) and debited from the stockpile. **This function does
  not call it** - it only sizes the need in `+0x968`.

## The offmap IC fix

### What the game does not do

**The original code never reads `countryValues[MODIFIER_IC]`.** Over the whole 0x8FE
bytes the only read of `CCountry +0xDA8`'s values is `+0x88` (`GLOBAL_IC`) at `0x4F0FAF`.
A country's own `MODIFIER_IC` entry is maintained by the modifier machinery and, as far as
this function is concerned, discarded. That is the hole both generations of the mod's fix
aim at.

### The hooks, which are what actually runs

`script/bicelib_lua.lua:57` calls `BiceLib.ComplexPatches.fixOffMapIC()`, which is
`fixOffMapIC(lua_State*)` in `bice.cpp:643`. It installs **only the two hooks** and never
calls `Patches::fixOffMapIC`.

- `Hook_OffmapIc_CountLocalIc`, rva `0xF0F22`, over `mov ecx,[esi+0x330]`: per province it
  reads `[[province+0x114]+0x78]` - `values[MODIFIER_IC]`, the province base - subtracts it
  from `eax`, which at that point is the contribution *with* `LOCAL_IC` applied, and
  accumulates the difference per country id. That is the total local-IC effect, in
  thousandths. My reading of the arithmetic agrees with the hook exactly.
- `Hook_OffmapIc_SetBaseIc`, rva `0xF0F9D`, over `mov [ebx+0x604],eax` (6 bytes, jumpback
  `+6` = `0xF0FA3`): takes `eax` (the province base in whole IC) and `[ecx+0x78]`
  (`countryValues[MODIFIER_IC]`, thousandths), derives
  `offmapIc = MODIFIER_IC/1000 - (base - localEffect/1000)`, writes `offmapIc * 1000` back
  into the modifier entry, and returns `base + offmapIc` as the new `+0x604`.

Both hook sites are unchanged in this executable: `0xF0F22` is still
`8b 8e 30 03 00 00` (6 bytes, so a 5-byte jmp plus one spare byte fits) and `0xF0F9D` is
still `89 83 04 06 00 00`. `ecx` still holds `country->GlobalModifier.values` at `0xF0F9D`,
loaded at `0xF0F85` and not touched in between. **The hooks are correct against this
build.**

### Verdict on `Patches::fixOffMapIC`

**Mechanically still correct; semantically superseded; and dead code.**

- `0xF0F90` really is `f7 6d 08`, `imul dword ptr [ebp+8]`, exactly 3 bytes. The patch
  writes `f7 69 78`, `imul dword ptr [ecx+0x78]` - same length, same boundary, and `ecx`
  is still the values pointer.
- `0xF0FA9` really is `69 c0 e8 03 00 00`, `imul eax, eax, 0x3E8`, exactly 6 bytes. The
  patch writes `8b 41 78 90 90 90`, `mov eax,[ecx+0x78]` plus three `nop` - same length,
  same boundary, `ecx` still valid.

So neither patch would corrupt an instruction stream. What it *does* is replace the
province sum with `countryValues[MODIFIER_IC]` at both the truncation and the
re-multiplication, which makes the accumulated province sum - and therefore **every
province's `LOCAL_IC`** - entirely unused, because `[ebp+8]` is read nowhere else before it
is reassigned. It is the first generation of the same fix, and the hook pair replaced it
precisely to keep `LOCAL_IC`.

Three reasons to drop it rather than keep it:

1. **Nothing calls it.** `Patches::fixOffMapIC` has no caller anywhere in the DLL or the
   mod's Lua. Only the Lua-exported `fixOffMapIC` runs, and that installs the hooks.
2. **It is incompatible with the hooks.** `0xF0F90` is before `Hook_OffmapIc_SetBaseIc`,
   so with both applied the hook's `baseIcWithLocalButNoOffmap` would arrive as
   `MODIFIER_IC/1000` and `offmapIc` would come out as the local-IC effect. `0xF0FA9` is
   *after* the hook's jumpback (`0xF0FA3`), so it would still run and feed `MODIFIER_IC`
   into the global multiply in place of the hook's answer.
3. It loses `LOCAL_IC` outright, which is the thing the hooks exist to preserve.

## What is not established

- **What `countryValues[MODIFIER_IC]` actually holds when this function runs.** The mod's
  hook names it `baseIcWithOffmapButNoLocal` and its whole arithmetic depends on that -
  province base IC plus the offmap part. I found no write to it: the modifier machinery
  (`0x4595C0`) fills a `CModifier`'s values from its source list generically, and whether
  province IC is one of those sources is unread. If it is **not**, and the entry holds only
  the flat `ic = N` from laws, techs and events, then the hook's `baseBaseIC` subtraction
  is wrong. The hook also writes `offmapIc * 1000` back into the entry every pass, which
  makes the value self-referential from the second day on. **This is the one thing here
  worth measuring in a running game**, and it cannot be settled statically.
- **Which modifier `[0x1A86208]+0x64` is.** Only that a global `CModifier`'s
  `MODIFIER_IC` seeds every country's province sum. This is a second, entirely separate
  channel for flat IC and nobody has looked at it.
- **Whether `CCountry +0xD00` is the owned or the controlled provinces.** The IC pass
  walks it; the `+0x610` test then filters on ownership, which only makes sense as a
  *narrowing*, so controlled is the likelier of the two - but that is an inference from the
  shape of the test, not a reading.
- **The game's name for `+0x610`**, and why its two readers want it.
- **`+0x614` is never cleared** - not at entry here, only in the constructor - and nothing
  reads it. Whether a getter reaches it by some other route was not chased.
- **`CCountry +0x95C` and `+0x960`**, the two figures `0x4F15C0` subtracts from the
  stockpile's metal and energy before working out the resource limit. Unread.
- **`0x4F15C0` was only read as far as `0x4F1640`.** The metal and energy terms and the
  fact that it returns its out-pointer are read; the final combination is not.
- **`CTechnologyStatus`'s layout.** `+0x90` is the IC bonus and `+0x98` the conversion
  bonus by what reads them here, and `+0x10` is something supply-related by
  `SupplyCapacity`. Nothing else about the 0x29C bytes.
- **The eight pools the conversion block does not sum**, and why those fifteen.
- `0x4D59D0`, the second caller, was read only far enough to establish that its `ebx` is
  the zero register at the call. What the function as a whole is for is unread.

## One contradiction with the existing record

`CLASSES.md` gives `CCurrentGameState`'s vftable as `0x11CF674`. The value the 2773 inline
constructor sites write is **`0x15CF674`** (`0x40B93C` is one of them), and the RTTI export
agrees: `CCurrentGameState`, vftable `0x015CF674`, 7 slots, base `CGameState`. The 2773
count in `CLASSES.md` is right, so it is the digit that is wrong, not the claim.
