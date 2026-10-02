# The build queue, and how IC and leadership are split

Static reading of `hoi3_tfh.exe`, image base `0x400000`. Every address is given as
`VA / rva`. The game was not running for any of this, so everything below is read out of
the image; where a fact comes from somewhere else it says so.

The centre is `CDistributeProduction::Distribute`, `0x519D10 / 0x119D10`, slot 0 of
vftable `0x15C21D4`. It is one of **ten** `CDistributionSetting` subclasses that all put
their work in slot 0 - the nine in the work queue plus `CDistributeReinforcement`, which
`FINDINGS-manpower.md` already read.

## The shape all ten share

`CDistributeReinforcement::Distribute` fixed the signature and the nine siblings agree
with it (`ret 0x10` on every one, `this` in ecx):

    CFixedPoint* __thiscall Distribute(this, CFixedPoint* out@stack:4,
                                       __int64 available@stack:8, bool flag@stack:16)

`available` is a `fpml::fixed_point<__int64,48,15>`, so **32768 is 1**. The settings' own
fields, from `CLASSES.md` and confirmed at the construction site `0x4C9D98`:

| | |
| --- | --- |
| `+0x8` | the slider's share, `GetBasePercentage`, fixed 15 |
| `+0x10` | a second factor, set to `0x8000` (= 1) by the constructor |
| `+0x18` | the country |

`CDistributeProduction` is allocated `0x30` bytes (`push 0x30` at `0x4C9D87`) and adds
two of its own fields, both zeroed there: `+0x20` and `+0x28`.

The twelve slots, read with `vtable.py` across all nine at once. Only slot 0 and slots 2
and 3 do arithmetic; 1, 5 and 6 build strings:

| slot | what it is | production's |
| --- | --- | --- |
| 0 | `Distribute` | `0x519D10` |
| 1 | a tooltip - pushes the key `SLIDER_NEED` | `0x51A300` |
| 2 | a share turned into an amount: `percentage x TotalIC (+0x604)` | `0x51A440` |
| 3 | `GetNeeded` (already named) | `0x51A2E0` |
| 4 | a shared stub `0xABF890`; only `CDistributeResearch` overrides it (`0x51F4D0`) | - |
| 5 | a second, longer tooltip, with SEH | `0x51A590` |
| 6 | the slider's name - pushes the key `DISTRIBUTE_PRODUCTION` | `0x51A9A0` |

Slots 1, 5 and 6 are why the "second per-class function" at slot 5 reads the
`LEADERSHIP_TO_*` defines: they are the text that tells the player what the slider buys.

## Two budgets, and the resource price of IC

Every IC distributor starts by working out two amounts from the same share:

    pool     = percentage x factor x available                 ; [esp+0x28] in production
    freePool = percentage x factor x CCountry +0x608           ; [esp+0x40]

`+0x608` is read by exactly five functions and they are the five IC distributors -
consumer goods `0x518D67`, production `0x519D5E`, supply `0x51AB4A`, reinforcement
`0x51BB96`, upgrade `0x51CEE9`. Lend lease does not read it. It is written in three
places: the `CCountry` constructor (`0x4D3E8A`), the daily reset (`0x4F0DE4`) and
`0x4F14D0`, which is the interesting one:

    eax = GetResourceLimitedIC(country) / 1000        ; 0x4F1474, see below
    if (TotalIC(+0x604) > eax) {
        [+0x614] = (eax - TotalIC) * 1000             ; the shortfall, negative
        [+0x604] = eax                                ; TotalIC is CAPPED by resources
    }
    esi       = [+0x6E8] / 1000
    [+0x604] += esi
    [+0x608]  = esi

and `+0x60C` (`GetMaxIC`) keeps the figure `+0x604` had before the cap (`0x4F0FA3` sets
both to the same value; only `+0x604` is then capped).

So `+0x608` is a component added to total IC **after** the resource cap. What the
distributors do with it says what it is for: **the share of `freePool` is spent with no
resource draw, and everything beyond it is charged metal, energy and rare materials at
the moment it is spent.** That the number is resource-free is confirmed by the code;
where it comes from (`CCountry +0x6E8`, and the vectors at `+0x6C8`/`+0x6D8` beside it)
is the daily-IC pass's business and is **not established here**.

### What an IC point costs in resources

Two functions, both taking `this` in **esi** and one stack argument (`ret 4`), and both
called only by the IC distributors and the daily pass:

**`0x4F15C0 / 0xF15C0`** - how much more IC the stockpile will support, in thousandths,
never negative. It reads the national stockpile (the acting capital's pool at province
`+0x15C`, or `CCountry +0x9F8` for a government in exile - the same choice
`CCountry::GetPool` makes) and takes off the country's pool at `+0x944`:

    metal  = pool +0x18 - country +0x95C
    energy = pool +0x1C - country +0x960
    rare   = pool +0x20 - country +0x964
    out    = max(0, min(metal, energy * 1000/2000, rare * 2000/1000))

**`0x4F16D0 / 0xF16D0`** - spend that much IC's worth. For `ic` thousandths it does

    country +0x9A4 (usage, metal)  += ic
    country +0x9A8 (usage, energy) += ic * 2000/1000
    country +0x9AC (usage, rare)   += ic * 1000/2000
    stockpile metal -= ic ;  energy -= 2*ic ;  rare -= ic/2

so **one IC costs 1 metal, 2 energy and 0.5 rare materials**, and the expense is booked
to the `usage` pool (`+0x98C`, named from the save writer in `CLASSES.md`). The goods
order comes from `CLASSES.md`: a `CGoodsPool` holds supplies, fuel, money, crude, metal,
energy, rare from its own `+0x8`.

Its seven callers are the whole of the IC economy: lend lease `0x5188FE`, consumer goods
`0x518DE3`, production `0x51A077` and `0x51A16D`, supply `0x51ADAE`, reinforcement
`0x51C496`, upgrade `0x51D56E`.

## `CDistributeProduction::Distribute`, step by step

Extent checked: it ends `ret 0x10` at `0x51A280`, `int3` padding follows, and `0x51A290`
is a fresh prologue - so the extent is `0x519D10..0x51A282`.

The queue is `CCountry +0xF40`, a list of `0x10`-byte nodes {item, prev, next, byte}
with the tail at `+0xF44`, the size at `+0xF48` and a byte at `+0xF4C` that means "the
list is being walked, defer the unlink". The loop walks it head to tail; the back edge is
`0x51A230 -> 0x519DC0`.

For each item, with `need = item->cost (+0x30) / 1000` converted to fixed 15 (the
`0x1F40000` in the decompile is 1000 in fixed 15, and `+0x30` is thousandths):

1. **Is it still buildable.** Virtual slot 12 (`[vftable+0x30]`) is called with
   `&country->tag` (`+0xCA4`). `CConstruction`'s body is `0x4831C0`: true when `+0x44`
   (`location`) is null, or when `[[+0x44] + 0x338]` equals the tag's id half, or when
   slot 11 says so. False, and the item is unlinked, freed and destructed
   (`0x519E34..0x519E7D`), or - if `+0xF4C` is set - only marked at node `+0xC` and
   destructed. `location` is null on every military and convoy item and a province on
   building items (`CLASSES.md`, read live), so **in practice this cancels building
   projects in provinces the country no longer holds** and never touches unit builds.
2. **No money left.** If `pool <= 0`: `AddProgress(0)` unless the `flag` argument is set
   (`0x51A213`, the third `AddProgress` call site), which zeroes the item's `status`, and
   on to the next item.
3. **A free item.** If `need <= 0`: `AddProgress(1000)` (`0x519ED9`, the literal-1000
   call site).
4. **The funded case.** If `freePool > 0`:

        base  = min(1.0, freePool / need)
        spent = base * need
        pool -= spent ;  freePool -= spent
        amount = base * 1000                              ; thousandths of a day's work

   and if `base` came out under 1.0 and `pool` is still positive, a top-up:

        extra = min(1.0, pool / (need - spent)) * (1 - base)
        want  = extra * need
        this->+0x28 += want
        if (GetResourceLimitedIC(country) >= want * 1000) {
            ConsumeICResources(country, want * 1000)
            pool   -= want
            amount += extra * 1000
            if (amount >= floorf(999.5f)) amount = 1000   ; 0x51A0A2..0x51A0CE
        }

   Otherwise (`freePool` exhausted) the whole day is bought with resources:

        frac = min(1.0, pool / need)
        this->+0x28 += frac * need
        if (GetResourceLimitedIC(country) >= frac*need*1000) {
            ConsumeICResources(...) ;  pool -= frac*need ;  amount = frac * 1000
        } else amount = 0                                 ; 0x51A1AC

   then `AddProgress(amount)` at `0x51A1B6`.
5. **Completion.** If `progress (+0x38) >= duration (+0x34)`, or the global byte at
   `0x1A8559A` is set, virtual slot 9 (`[vftable+0x24]`) is called; when it answers
   exactly 1 the item is unlinked from `+0xF40` (through `0x5D49D0`) and destructed, and
   a local byte is set.
6. **After the walk**, if anything completed: `0x4DDD80` is called with the country, and
   then **slot 14 (`[vftable+0x38]`) is called on every remaining item** - the cost
   recompute. Finally `0x51A290` rebuilds `this->+0x20`.

### So: what decides each item's share

**Queue order, and nothing else.** There is no proportional split, no per-item priority
field and no weighting. The loop hands each item, in list order from `+0xF40`, up to one
full day of its own cost, and stops funding when the allocation runs out. The only
subtlety is the two-tier budget: the resource-free part (`freePool`) is drawn first, and
what is taken beyond it has to pass the metal/energy/rare check, so **an item can be
skipped entirely for want of resources even when IC is allocated** (`amount = 0` at
`0x51A1AC`) while a later item in the queue, needing less, still gets funded.

### The two cached fields

`0x51A290 / 0x11A290` takes `this` in **esi** and has a bare `ret`. It zeroes `+0x20`,
walks `+0xF40` and adds each item's `cost / 1000` into it. **Slot 3 `GetNeeded` is
`0x51A2E0`, which is nothing but `out = this->+0x20`** (`ret 4`, `this` in ecx). So
`+0x20` is the queue's total daily IC appetite and it is refreshed at the end of every
pass.

`+0x28` accumulates the IC each pass **asked for beyond the free part** - the add happens
before the resource check, so it counts what was wanted, not necessarily what was got.
Nothing in the nine bodies reads it back.

`Distribute` itself always returns zero for production (`0x51A26F`).

The `flag` argument's only use in this body is step 2 - skipping the `AddProgress(0)` on
unfunded items. It is not "skip the last step" here.

## Where cost and duration come from

**`CMilitaryConstruction` slot 14, `0x485300 / 0x85300`**, `this` in ecx, bare `ret`, and
it ends with exactly three stores:

    [this+0x34] = duration
    [this+0x30] = cost
    [this+0xA0] = the practical factor

It calls **`CCountry::GetBuildCostIC` (`0x4E18F0 / 0xE18F0`)** at `0x485494` and
`0x4854EF`, and **`CCountry::GetBuildTime` (`0x4E19A0 / 0xE19A0`)** at `0x4855B6` and
`0x4855CF`, both on the country found as `gamestate[+0x16C][this+0x4C]` - the country the
item is for. The fourth argument to `GetBuildCostIC` is `byte [this+0x8C]`, `is_reserve`.

It has two arms. Where `+0x84` (`brigades_count`) is positive **and** the first element of
the vector at `+0x7C` has a non-null `+0x38` - an existing brigade, so the item is an
upgrade - it takes the difference between the new cost and the old (`0x4854F8`, floored at
zero) and applies three `military` defines, `+0x234 UNIT_UPGRADE_COST`,
`+0x238 UNIT_UPGRADE_TIME` and `+0x23C UNIT_UPGRADE_PRACTICAL_MOD`, the last scaled by
the upgrade's share of the full cost. The other arm walks the brigade list and adds up a
fresh build. Both end at `0x48588F`.

So the whole of an item's cost and duration is `GetBuildCostIC` and `GetBuildTime`, which
`project.json` already documents, and the queue-side arithmetic adds only the upgrade
defines. **Slot 14 runs at exactly two moments**: once when the item is queued
(`0x546166`), and on every queued item whenever any item completes (`0x51A253`). It does
*not* run daily, so a queued item's cost lags the country's current technology and
practical until something in the queue finishes.

## `AddProgress`, `status`, and the practical

`CConstruction::AddProgress` (`0x4837D0 / 0x837D0`) is already named and
`FINDINGS-oob.md` has it right: it works out `amount * 1000 / duration`, hands that to
virtual slot 20, adds `amount` to `progress` and writes `status (+0x3C)`. Two things to
add.

**It is the only writer of `+0x3C`** - `FINDINGS-oob.md` and `project.json` both already
say so, from two sweeps. The brief's "the writer is not identified" is out of date.

**Slot 20 is where the practical goes.** `CMilitaryConstruction`'s is
`0x4846D0 / 0x846D0` (`this` in ecx, `ret 4`):

    m = country->modifiers[+0xDA8][0x1A0]              ; MODIFIER_UNIT_START_EXPERIENCE
    if (is_reserve) m = this->reserves_factor(+0x9C) * m / 1000
    this->accumulated_experience(+0xA4) += m * fraction / 1000
    this->accumulated_progress(+0xA8)   += fraction

The modifier array is **eight bytes an entry**: `GetBuildCostIC` reads
`RESERVES_PENALTY_SIZE`, modifier 77, at `+0x268`, and 77 x 8 = `0x268`. So `+0x1A0` is
modifier 52, `MODIFIER_UNIT_START_EXPERIENCE`. `+0xA4` and `+0xA8` are already recorded
in `project.json` as `accumulated_experiance` (the game's spelling) and
`accumulated_progress`, which is what makes this reading safe.

`+0xA0` is not saved or loaded: the constructor sets it to 1000 (`0x483ED2`), slot 14
writes it, both instant-build paths zero it (`0x546192`, `0x547208`), and slot 9 reads it
once, at `0x484EBC`:

    gain = brigadeDefinition[+0xE4]
    if (is_reserve) gain = gain * reserves_factor / 1000
    gain = gain * this->+0xA0 / 1000
    0x4E02F0(country, definition->+0x3C /* technology category */, gain)

and `0x4E02F0 / 0xE02F0` scales the gain down by the ability already held -
`max(1000, ability * 1000 / TECH_ABILITY_GAIN_DIVISOR)` as a divisor, off
`CCountry +0x698`, the same array `GetCategoryBuildDiscount` reads. It is also called by
`CDistributeResearch::Distribute` (`0x51FA04`).

### Where the gearing term is, and is not

There is **no gearing bonus and no practical term anywhere in `Distribute`**. The whole
of it is the two budgets, the queue order and the resource check; nothing in the loop
reads a technology, a practical or a category.

The practical loop is elsewhere and it closes like this: finishing an item awards
category ability through `0x4E02F0`, and that ability comes back as a cost discount
inside `GetBuildCostIC` - `CTechnologyStatus +0x24C` for the unit type plus
`GetCategoryBuildDiscount`'s figure for the category. Since slot 14 only re-reads that on
a queue completion, **the discount a completed unit earns reaches the rest of the queue
at the moment it completes** and not before, which is exactly the sweep at `0x51A253`.

## Queue insertion

`CConstructUnitCommand::Execute` (`0x545BA0 / 0x145BA0`) allocates `0xAC` bytes, builds a
`CMilitaryConstruction` with `0x483E10`, and copies the command across: `+0x58/+0x5C` the
unit, `+0x3C/+0x40` into `country (+0x48/+0x4C)`, `+0x70` into `+0x40`, `+0x44/+0x48` (or
`+0x3C/+0x40` when the first pair is empty) into `builder (+0x50/+0x54)`, the province
into `location (+0x44)`, `byte +0x74` into `is_reserve (+0x8C)`, `+0x78/+0x7C` into the
target pair. It charges manpower off `CCountry +0xBCC` at `0x546105` and stores it into
`+0x98`. Then, at `0x546166`, it calls **slot 14** - so the item's first cost and duration
are `GetBuildCostIC x GetBuildTime` for the country's technology at that instant.

**`byte [cmd+0x80]` is "build it now".** At `0x54616D`:

- **clear** - `0x4F5600 / 0xF5600` is called with the construction in eax and the country
  in edi. That is the enqueue: it sets `location (+0x44)` back to zero, calls slot 8,
  copies the country's tag from `+0xCA4/+0xCA8` into `+0x48/+0x4C`, and appends a new
  `0x10`-byte node at the tail of `+0xF40`/`+0xF44`. (This is why `location` reads null on
  every military item.)
- **set** - `AddProgress(this->duration)` at `0x546182`, which makes `progress == duration`
  in one step, then slot 9 to deliver it, then `+0xA0 = 0` so it earns no practical, then
  the destructor. Nothing is ever put in the queue.

`CConstructSingleUnitCommand::Execute` (`0x546E40 / 0x146E40`) does the same at
`0x5471FC`, but **its flag is `byte [cmd+0x68]`, not `+0x80`**.

That is the path history and at-start OOB use, and it explains why an at-start unit has no
practical behind it.

## The siblings

All of these are slot 0 and none had a direct caller, which is why nothing had found them.

| class | slot 0 | what it does with its share |
| --- | --- | --- |
| `CDistributeLendLease` | `0x518800 / 0x118800` | no defines; `0x508620` and `0x508900`; charges resources at `0x5188FE`. The only sibling that does not read `+0x608` |
| `CDistributeConsumerGoods` | `0x518C50 / 0x118C50` | money and dissent - below |
| `CDistributeProduction` | `0x519D10 / 0x119D10` | the build queue - above |
| `CDistributeSupply` | `0x51AA80 / 0x11AA80` | `economy +0x10 IC_TO_SUPPLIES` at `0x51ADD8`; adds supplies to `HomeProduced` (`+0x778`), to the capital province's pool (`+0x164`) and `current_producing` (`+0x270`), and to the `to` pool (`+0x9B8`); raises a message; charges resources at `0x51ADAE` |
| `CDistributeReinforcement` | `0x51BA60 / 0x11BA60` | already read - `FINDINGS-manpower.md` |
| `CDistributeUpgrade` | `0x51CE60 / 0x11CE60` | zeroes then rebuilds `CCountry +0xAA4` (`upgrade_cost`) at `0x51CF4C` and `0x51D4E1`; reads `military +0x2AC/+0x2B0/+0x2B4`, `SHIP_`/`AIR_`/`LAND_UPGRADE_SPEED_MOD`; calls `GetBuildTime` and `GetCategoryBuildDiscount`; charges resources at `0x51D56E` |
| `CDistributeNCO` | `0x51DF40 / 0x11DF40` | `economy +0x2C LEADERSHIP_TO_OFFICERS` at `0x51DF86` and modifier 82 `MODIFIER_OFFICER_RECRUITMENT` (`+0x290`); it stores nothing - the officers are the **return value** |
| `CDistributeDiplomacy` | `0x51E4B0 / 0x11E4B0` | `economy +0x4 LEADERSHIP_TO_DIPLOMACY` at `0x51E4F2`; adds the result to `CCountry +0xA88`, with a cap |
| `CDistributeEspionage` | `0x51ED00 / 0x11ED00` | `country +0x1C MAX_NUMBER_OF_SPIES` at `0x51ED23` and `economy +0x24 LEADERSHIP_TO_SPIES` at `0x51ED91`; writes then decrements `CCountry +0x1170`; raises two messages; ends in `0x4DDD80` |
| `CDistributeResearch` | `0x51F620 / 0x11F620` | `0x532EC0`, `0x535760`, `0x532F10` (the research tick another agent has), `0x540D60`/`0x540B50`, and `0x4E02F0` - the same ability gain a finished unit uses. No defines of its own. The only class that also overrides slot 4 (`0x51F4D0`) |

The brief's claim about the leadership defines is **verified** with `definesMap.py`
backwards: `LEADERSHIP_TO_OFFICERS` (`economy +0x2C`) is read at `0x51DF91` (NCO slot 0)
and `0x51E155` (NCO slot 5) and nowhere else; `LEADERSHIP_TO_DIPLOMACY` (`+0x4`) at
`0x51E4FD` and `0x51E662`; `LEADERSHIP_TO_SPIES` (`+0x24`) at `0x51ED9C` and `0x51F27F`.

## Consumer goods: money, and the dissent rate

`0x518C50 / 0x118C50`. Two halves.

**Money.** If `available` is non-zero it calls `0x518F00 / 0x118F00` - `out` in esi,
three stack args, `ret 0xC` - with (this, 1000, MaxIC(+0x60C) x 1000). That helper is

    out = fraction * ic / 1000                                  ; = MaxIC*1000 here
    out = out * economy +0x8 IC_TO_MONEY / 1000
    out = out * (1000 + modifier 31 MODIFIER_GLOBAL_MONEY) / 1000

and slot 0 adds the answer to `HomeProduced`'s money (`CCountry +0x780`) and to the
national stockpile's money (`pool +0x10`). **The fraction slot 0 passes is the literal
1000, and the IC it passes is `MaxIC`, so the money income has no term from the consumer
goods share at all.** That is unexpected and is reported rather than explained; the other
caller, `0x4F065A` in the daily IC pass, also reads `+0x60C` (`0x4F063C`).

**The resource charge.** `alloc = percentage x factor x available` in thousandths, less
`percentage x factor x (+0x608)`; if positive, `ConsumeICResources` is called with it
(`0x518DE3`). Consumer goods spends its whole allocation every day, so it pays for all of
it that is not resource-free, in one go.

**Dissent.** Skipped when the `flag` argument is set, and skipped when
`gamestate +0xD0C` is non-zero. Otherwise `0x518F80 / 0x118F80` (`out` in edi, `ret 0x10`)
computes, in fixed 15:

    delta = CCountry::GetConsumerGoodsNeeded(country)         ; 0x4FA020, thousandths
          - percentage x factor
          + modifier 43 MODIFIER_DISSENT

and slot 0 turns that into thousandths and does

    if (country +0xCA8 != 0) { dissent(+0x10B4) += delta; if (dissent < 0) dissent = 0; }
    else                       dissent = 0

So **the rate is one for one and linear: a slider one point above what the country needs
takes one point of dissent off per day, and a point short adds one per day**, both in the
same units as dissent itself (thousandths, so a full 1.00 of oversupply is 1000/day),
plus whatever `MODIFIER_DISSENT` contributes. There is no decay term of any other kind -
no percentage, no half-life.

`CCountry::GetConsumerGoodsNeeded`, `0x4FA020 / 0xFA020` (`this` in **eax**, `out` in
**esi**), is modifier 40 `MODIFIER_WAR_CONSUMER_GOODS_DEMAND` or 41
`MODIFIER_PEACE_CONSUMER_GOODS_DEMAND` - chosen by `byte [country+0xACC]` being zero -
plus a term from `0x4F9F10`, clamped between `floorf(10.5f)` and `floorf(990.5f)`, so
**between 0.010 and 0.990**. `CDistributeConsumerGoods::GetNeeded` (slot 3, `0x519030`)
is the same two terms: `GetConsumerGoodsNeeded + MODIFIER_DISSENT`.

## Corrections to the existing record

- **`CConstruction +0x3C`'s writer was already identified.** `FINDINGS-oob.md` and
  `project.json` both name `AddProgress` and both are right; `CANDIDATES.md` asks for a
  writer that is already on record.
- **`CLASSES.md` says `CCountry +0x944` is "never used in this build" and "written
  nowhere but the constructor and the two daily resets".** It is *read*:
  `GetResourceLimitedIC` takes its metal, energy and rare (`+0x95C`, `+0x960`, `+0x964`)
  off the stockpile as a reservation. That it measured zero in 108 countries is consistent
  - nothing writes it - but the pool has a job, and the name for it is "resources already
  reserved against IC".
- **The modifier values array is eight bytes an entry**, not four:
  `RESERVES_PENALTY_SIZE` is modifier 77 and sits at `+0x268`. Dividing such an offset by
  four - as a first pass at slot 20 here did - lands on the wrong modifier.
- **The brief's "slot `0x24`" for the per-item call is two different slots.**
  `[vftable+0x30]` (slot 12) is the buildability test at the top of the loop;
  `[vftable+0x24]` (slot 9) is the completion at the bottom. Both are in the loop.
- **The instant-build flag is not at `+0x80` on both commands.** `CConstructUnitCommand`
  uses `byte [cmd+0x80]`, `CConstructSingleUnitCommand` uses `byte [cmd+0x68]`.
- `CANDIDATES.md` lists nine subclasses; there are ten, and `CDistributeReinforcement`
  (`0x51BA60`) is the one already named.

## What is not established

- **What `CCountry +0x608` actually is.** Its role is read - the resource-free part of
  the day's IC - but its origin is `CCountry +0x6E8`, which `0x4F14D0` fills out of
  machinery (`+0x6C8`, `+0x6D8`, `0x511E10`, `0x50FA80`) belonging to the daily IC pass.
  Offmap IC is a guess and is written here as a guess, nothing more.
- **Why the consumer-goods money income ignores the slider.** Read twice; the fraction
  argument is a literal 1000 and the IC is `MaxIC`. Either the money is genuinely
  independent of the share, or a second money path exists that this reading has not
  found. Not resolved.
- **Who reads `IC_TO_CONSUMER_GOODS` (`economy +0xC`).** Not `CDistributeConsumerGoods`,
  which reads only `IC_TO_MONEY`. `GetSpareICIn`'s existing comment says a define scales
  the consumer arm's `GetNeeded`, but `GetSpareICIn` itself calls `GetDefines` nowhere in
  its body, so the reader is unidentified.
- **The global byte at `0x1A8559A`**, which lets an item attempt completion with
  `progress < duration`. Unidentified; a debug or cheat flag is the obvious guess and is
  only a guess.
- **`0x4DDD80 / 0xDDD80`**, called with the country after anything in the queue completes
  and at the end of the espionage distribute. Not read.
- **`0x4E02F0 / 0xE02F0`'s calling convention.** The formula is read (a diminishing gain
  against `CCountry +0x698`, divided by
  `max(1000, ability*1000/TECH_ABILITY_GAIN_DIVISOR)`) but its `ret` was not reached, so
  no signature is offered and it is left unnamed.
- **`CDistributeLendLease` and `CDistributeResearch` slot 0 beyond their call lists.**
  Neither was read as a body; only what they call and what they write.
- **Slots 7 to 11 of `CDistributionSetting`.** They are shared stubs (`0x592360` is
  `xor al,al; ret`, `0xA92590` is `mov al,1; ret`) and, per the trap about small shared
  functions, nothing here counts how many classes share them, so none is named.
- **`CConstruction` slot 9's body.** Only the practical award at `0x484EBC` was read out
  of it; what else delivering a unit does is untouched.
- **Everything live.** The game was not running. Every number above is the image's, and
  nothing here has been watched actually happening.
