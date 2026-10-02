# Where practical and theory decay is actually applied

Read out of `hoi3_tfh.exe` on 2026-09-30, statically. Addresses are **virtual** (base
`0x400000`) with the rva beside them; `VA = RVA + 0x400000`.

**In one line.** Decay is applied **once a month, per country, inside `0x4DC840`
(rva `0xDC840`)**, which `RunMonthlyPass` calls at `0x683BE9` for every country in the game
state's country vector. That function reads `BASE_TECH_DECAY` at `0x4DCACA` and writes
`CCountry +0x698` (`category_levels`) directly at `0x4DCB20`. It is a **second reader of
`BASE_TECH_DECAY`** that the previous survey missed, and it is on the tick.

---

## 1. The monthly function

`0x4DC840`, extent `0x4DC840..0x4DCD69`, **`ret` with no immediate**, SEH handler
`0xC5D647`, `this` in `ECX`, no stack arguments:

    void __thiscall CCountry::UpdateMonthly(CCountry* this)

Clean `int3` padding at `0x4DCD6A..0x4DCD6F` and a fresh prologue at `0x4DCD70`, so the
extent is not an abutting-function artefact.

**Exactly one caller**, `0x683BE9`, inside `RunMonthlyPass` (rva `0x283B50`):

    0x683BBA   count = ([state+0xBC0] - [state+0xBBC]) >> 2      the country vector
    0x683BC9   edi = 1                                           id 0 is skipped
    0x683BE0   ecx = [state+0xBBC][edi]
    0x683BE9   call 0x4DC840

`findRefs --callers 0x4DC840` returns that one call and `findRefs --address 0x4DC840`
returns no data reference, so it is in no vftable and reached from nowhere else. Decay is
therefore **monthly and only monthly**.

Tech decay is only part of what the function does; the rest is the country's other monthly
bookkeeping (see section 5). **Do not call it a decay function.**

## 2. The formula, instruction by instruction

### The slack term, `0x4DC8D9..0x4DC943`

    ebx = [this+0x5F4]                       ProductionDistribution, vector begin
    for d in { [ebx+0x14], [ebx+0x10] }:     elements 5 (Upgrade) and 4 (Reinforcement)
        p = int64(d[+8..+0xC]) * int64(d[+0x10..+0x14])      __allmul, 0xB99AF0
        p >>= 15                                            1.0 = 0x8000
    slack = (p_upgrade + p_reinforcement) * 0x1F40000 >> 30  -> thousandths

`0x1F40000` is `1000 << 15`, and the two `shrd .., 0xf` pairs at `0x4DC938`/`0x4DC93F` are
one `>> 30`. So each `CDistributionSetting` field is a `1.0 = 0x8000` fixed point, their
product is converted to **thousandths**, and the sum is parked in `[ebp-0x18]`.

This is the same `[+8] x [+0x10]` over `ProductionDistribution` elements 4 and 5 that
`0x4204A0` computes at `0x420538` - the two functions agree exactly on the slack term.

### The gate, `0x4DC9C0`

    al = [CCurrentGameState +0xDA4]           in_game
    test al, al
    je  0x4DCB2A                              skip the whole decay loop

`+0xDA4` is already recorded as `in_game`, zeroed by the `CCurrentGameState` constructor
(`0x67B130`, at `0x67B146`) and set to 1 by `EnterGame_SetInGame` (rva `0x25D126`). So
**no decay happens outside a live session**, however many month boundaries pass.

The game state is fetched through an inlined lazy singleton on `[0x1A89790]`
(`0x4DC946..0x4DC9B9`), which is why nothing looked like a call to a getter.

### The loop, `0x4DC9D1..0x4DCB25`

    0x4DCA36   count = ([0x1A87B78]+0x20 - [0x1A87B78]+0x1C) >> 2     every category
    0x4DCA44   if i >= count: exit to 0x4DCB2A
    0x4DCA4A   ebx = i * 4
    0x4DCA51   mod  = [this+0x1174][i]                tech_decay_modifier, thousandths
    0x4DCA5A   mod += 1000
    0x4DCAC4   ecx  = [0x1A86040]->[+0xCC]            the CDefines `country` block
    0x4DCACA   eax  = [ecx+0x40]                      BASE_TECH_DECAY
    0x4DCACD   step = eax * mod                       imul, 64-bit
    0x4DCAD9   step = step / 1000                     __alldiv, 0xB99980
    0x4DCAE5   eax  = 1000 - slack
    0x4DCAEA   step = step * eax
    0x4DCAF3   step = step / 1000
    0x4DCAF8   if step > 0: step = 0                  test/jle/xor - clamped ABOVE only
    0x4DCAFE   edi  = [this+0x698]                    category_levels
    0x4DCB04   ecx  = step + 1000
    0x4DCB0A   eax  = [edi + i*4]
    0x4DCB0D   imul ecx
    0x4DCB18   / 1000
    0x4DCB20   [edi + i*4] = eax
    0x4DCB1D   i++ and back to 0x4DC9D1

In one line, with everything in thousandths:

    step  = BASE_TECH_DECAY x (1000 + tech_decay_modifier[i]) / 1000
                            x (1000 - slack) / 1000,     clamped to <= 0
    category_levels[i] = category_levels[i] x (1000 + step) / 1000

BlackICE's `common/defines.lua` has `BASE_TECH_DECAY = -0.02` and its own comment reads
"how many percent lost each month in tech categories" - which this code confirms as a
**fraction per month**, so 2% of every practical and theory, every month, at slack 0.

## 3. The `BASE_TECH_DECAY` reader count is wrong in the existing record

`FINDINGS-research.md` and `project.json` both say `0x4204A0` is "the image's **only** reader
of `BASE_TECH_DECAY`". **There are two:** `0x420661` and `0x4DCACA`.

The survey missed this one because **`GetDefines` is inlined here**. `0x4DCA62..0x4DCABD` is
a copy of `GetDefines`' own body (`0x445D90`): test `[0x1A86040]`, `operator new` `0x11C`
bytes, `call 0x4452E0` (the `CDefines` constructor, the same one `0x445DCF` calls), publish it
back. There is **no `call 0x445D90`**, so a scan anchored on that call cannot see it. The same
inlining hides the technology database (`[0x1A87B78]`, constructor `0x540D60`) and the country
database (`[0x1A855A4]`, constructor `0x4024D0`).

**The lesson for `definesMap.py`-backwards: the inlined lazy singleton is a second shape, and
any "only reader of X" claim made from the `call GetDefines` scan alone is an upper bound on
confidence, not a result.**

## 4. How the monthly decay differs from `0x4204A0`

Both apply the same shape of step to the same array, but they are not the same rule:

| | `0x4204A0` (game start / CGM stage) | `0x4DC840` (monthly) |
| --- | --- | --- |
| which categories | one half per call, skipped unless `vslot2()`, split on `+0x60` | **every** category index, `0..count-1`, no split and no skip |
| `theory_decay_months` / `practice_decay_months` | multiplies the step | **not read** |
| `extra_practice_decay` | multiplies a practical's step | **not read** |
| the CGM singleton `0x1A85C1C` | fetched via `0x41C4E0` | **never touched** |
| lower clamp | `step` clamped to `[-1000, 0]` | **clamped above at 0 only, no floor** |
| base level | `max(own_ability, the sharer's)` (`+0x698` vs `+0x6A8`) | the country's **own** level only |
| how it writes | `CCountry::SetTechAbility` (`0x4E03C0`), floor 0, cap `MAX_TECH_ABILITY` | **straight into the array**, no floor, no cap |
| gate | none | `CCurrentGameState +0xDA4` `in_game` |

Three consequences worth having for tuning:

- **`theory_decay_months` and `practice_decay_months` do not affect ongoing decay at all.**
  They only scale the one-shot step applied when the custom game settings are applied. The
  same goes for `extra_practice_decay`: a category cannot be given a different *monthly*
  rate through it. The only per-category monthly knob is `CCountry +0x1174`.
- Theories and practicals decay at **identical** monthly rates in this build. Any difference a
  player sees comes from `+0x1174` or from the gain side, not from the decay rate.
- A `tech_decay_modifier` of `-1000` or below turns the step positive, which the clamp at
  `0x4DCAF8` then zeroes - so **a decay modifier at or past -1.000 disables that category's
  decay entirely and cannot be pushed further into a gain**. In the other direction there is
  no floor: with `BASE_TECH_DECAY = -0.02`, a modifier of `+49000` would make `step = -1000`
  and wipe the category to zero in one month, and past that the level would go negative. That
  is only reachable by stacking, and BiceLib's `fixMinisterTechDecay` (rva `0xDE3ED`, the
  `mov` turned into an `add`) is what makes `+0x1174` stack - so the boundary is worth knowing
  even though nothing plausible reaches it.

## 5. The rest of `CCountry::UpdateMonthly`, for context

Read but not pursued, so that nobody mistakes the function for a decay function:

    0x4DC8D3   [this+0x11D4] = 0                   spiescaught, reset monthly
    0x4DC8D9   the slack term (section 2)   <- but see the note on what `slack` means
    0x4DC9C0   the decay loop (section 2)
    0x4DCB2C   0x4F0270(this)
    0x4DCB3D   [this+0x90] += [this+0xDF8]->[+0xBC]
    0x4DCB98   0x4DDD80(this), 0x4FBC10(this), 0x4E1C00(this), 0x4E1FC0(this)
    0x4DCBAF   tag == "REB" skips the next block
    0x4DCBD3   [this+0xAD0] = 0 then clamped down to [this+0xDA8]->[+0x48]   war_exhaustion
    0x4DCC13   0x4FBF80 when war_exhaustion is positive and [this+0xACC] is clear
    0x4DCC1E   a loop over every country in the country database ([0x1A855A4]+0x16C),
               skipping any with [+0xCF8] <= 0, calling 0x4E78D0(this, tag) - relations
    0x4DCD3E   0x4F6D00(this), then 0x528770 on [this+0x10BC] and [this+0x10F4]

## 6. The census of writers to `CCountry +0x698`

A byte-level scan of `.text` for the encoded displacement `0x698` finds **90 distinct
instruction sites**. `+0x698` is an `int*`, so a write to the array is a *load* of `+0x698`
followed by a store through the loaded register; tracking each loaded register forward to the
next store through it gives **exactly four** array writers:

| site | in | what |
| --- | --- | --- |
| `0x4CF32F` | `CCountry::LoadKey` (rva `0xCF2F3`) | a history file's `*_theory` / `*_practical`, assigning |
| `0x4D45EB` | `0x4D2B60` | **a reset**: stores the same zero register into every index, then zeroes `+0xE20`, `+0xBCC`, `+0xBD0`, `+0x158`, `+0xA94`. Callers `0x4CA64E` and `0x67BDFC`. Not identified further and **not named here** |
| `0x4DCB20` | `CCountry::UpdateMonthly` | **the monthly decay** |
| `0x4E0431` | `CCountry::SetTechAbility` | the general setter, and `0x4204A0` reaches the array only through it |

Three more sites store to `[reg]` where `reg` was loaded from `+0x698` - `0x4E02C9`,
`0x533345`, `0x817F9E` - but those are the out-pointer of a `GetAbility`-shaped reader, not
the array. Every other site of the 90 is a read or a `lea` (many of the `lea`s, in the
`0x704AF0`-`0x7167A0` band, are a `+0x698` field on some other class entirely).

`CCountry::SetTechAbility` itself has **7 callers**: `0x41FEC5` and `0x4200A8` (the two
rebuild wrappers zeroing their half), `0x420741` (`0x4204A0`'s decay store), `0x4E03A6` (its
own neighbour), `0x5EF04C` and `0x5EF076` (`CCategoryChange`, slot 7 of a
`CCountryHistoryEntry` - an apply/undo record, vftable `0x15C9784`), and `0x9BDD98`
(`CPracticalEffect::Execute`). **None of those is on a tick.**

So: the only code in the image that reduces a category level over time is `0x4DCB20`.

## 7. Two negatives, so nobody redoes them

### `state+0xB8C` is the province vector, not anything to do with technology

`RunMonthlyPass`' unidentified `-83` at `0x683BA5` decays `+0x24` of each entry of
`state+0xB8C`. `project.json` already records `CCurrentGameState +0xB8C` as
`provinces_begin` and `CMapProvince +0x24` as `nationalism` (named from the key
`SaveContents` writes it under). So that loop is

    for each province, id 1 upwards:
        0x49F3E0(province)                  the province's own monthly work
        if province->nationalism != 0:
            province->nationalism -= 83     floored at 0 (0x683BAB)

**83 is `1000/12` because nationalism is counted in years and runs down one year per year**,
which fits the `YEARS_OF_NATIONALISM` define in the same `country` block as
`BASE_TECH_DECAY` (`+0x8`). That the define is what seeds the field is **inference**; the
arithmetic and the two field names are read. Either way it has nothing to do with
technology categories, and the `1000/12` coincidence that made it look promising is a
coincidence.

### `0x41FFF0` does not have three `+0x698` accesses

The lead said `0x41FFF0` was the most promising candidate because of accesses at `0x420703`,
`0x42070C` and `0x420717`. Those three addresses are **inside `0x4204A0`**, whose body runs
`0x4204A0..0x420774`. `0x41FFF0` is `RecalculatePracticalAbilities` and ends before
`0x4204A0` begins. The attribution came from a function-extent walk that ran past a `ret`,
which is trap 2 in this folder's list.

## What is not established

- **What `0x4D2B60` is.** It clears `category_levels` along with the capital and four other
  fields, and its two callers are `0x4CA64E` (inside `0x4C9C64`) and `0x67BDFC` (inside
  `0x67BAF0`). "A country reset on load or on release" is a guess and is not recorded as a
  name.
- **`CDistributionSetting +8`.** Unchanged from `FINDINGS-research.md`: `+0x10` is recorded as
  `factor`, `+8` is undocumented, and the slack term is their product. Which slider state the
  product represents - the share actually spent, or the share requested - was not read.
- **Whether `+0x1174` is ever non-zero in a plain game.** The only writer recorded is
  `0x4DE3ED` in the `decay` effect's handler; nothing here checked what fills it from
  ministers or ideas.
- **Why the two decay rules differ.** That `0x4204A0` is a months-scaled catch-up applied when
  settings change and `0x4DC840` the per-month step is the obvious reading, but the code says
  only what each one does.
- **`0x49F3E0`** - the province's monthly work - and everything in section 5 past the slack
  term. `war_exhaustion`'s monthly clamp against `[this+0xDA8]->[+0x48]` in particular looks
  like a cap worth a finding of its own.
- Nothing here was checked against the running game. The whole document is static reading.
