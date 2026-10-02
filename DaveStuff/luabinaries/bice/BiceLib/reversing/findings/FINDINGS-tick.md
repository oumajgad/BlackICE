# The tick

How the game gets from one hour to the next, and what it does when it arrives. Everything
here was read out of the executable on 2026-09-30; the addresses are virtual, based at
`0x400000`, with the rva beside them where a finding names one.

**In one line.** The frame loop accumulates real time in the game state, and when enough has
built up it posts a `CHourlyTickCommand` through the command queue. Executing that command
advances the clock by one hour and runs the hourly work; if the hour turned the day, the
month or the year, it runs those passes too, in that order, before returning.

## The clock

`CCurrentGameState::AdvanceClock` (rva `0x281130`) is called once a frame, from inside
`CInGameIdler::Update` at `0x656006` - its only caller in the image. It is a `thiscall` on
the game state and takes the frame's elapsed time in `xmm0`, which is not a convention MSVC
uses for a stack float; treat the argument as "already in `xmm0`" rather than assuming a
stack slot.

    +0xBE4   float    the accumulator: this frame's delta is added to it every call
    +0xBEC   int      the speed setting, 0 to 4, an index into five float thresholds
    +0xBF0   byte     a tick is in flight

The five thresholds are loaded onto the stack from `0x160A2EC`, `0x1718064`, `0x171DBAC`,
`0x15AB304` and `0x160A740` and then indexed by `+0xBEC`, which is why speed is a *table*
lookup and not arithmetic on one constant. If the accumulator has not reached the threshold
for the current speed the function does nothing else.

**`+0xBF0` is the interlock, and the tick body is what sets it.** `AdvanceClock` tests it at
`0x68114F` and jumps past the whole posting path when it is set; `RunHourlyTick` sets it to 1
in its third instruction (`0x681425`). So while an hour is being processed no further hour can
be queued, however long the processing takes. Time accumulates during it - the add to `+0xBE4`
happens before the test - so a slow tick is caught up afterwards rather than lost.

When an hour is due, the accumulator is zeroed, `operator new` takes **0x4C bytes**, the
`CHourlyTickCommand` constructor (`0x6DA2C0`) is called with a pointer to the game state's
`+0xC58`, and the command is posted: `[state+0xBE8]` (`in_game_screen`) slot 18 returns an
object, and that object's `+0x38` gets slot 6 called with the command. That two-step is the
route every `CCommand` takes, and it is the same `+0x34` byte the autosave work found the
multiplayer branch testing.

## The tick body

`RunHourlyTick` (rva `0x2813F0`), `__stdcall`, taking the game state and the command's
payload at `command+0x3C`. Reached only from `CHourlyTickCommand::Execute` (rva `0x2DA370`),
which first makes sure the `CCurrentGameState` singleton at `0x1A89790` exists, constructing a
`0xDA8`-byte one if it does not.

**`mov byte [edi+0xBF0], 1`** at `0x681425`, then the date is taken apart:

    ecx = [state+0xBDC] - 0x29C55C0          the tick counter, less the epoch
    days = ecx / 24                          via the 0x2AAAAAAB magic and sar 2
    ... then MonthLengthTable (0x1713294) and the double 365.0 at 0x160A550

`0x29C55C0` is 43,800,000, which is 5000 x 365 x 24 - so `tick` counts **hours** from an epoch
5000 years before year zero, on 365-day years. (The factorisation is the evidence; that the
designers thought of it as 5000 BC is inference.) The single advance in the whole image is
`inc dword [edi+0xBDC]` at `0x68155F`. A second counter at `0x1A8560C` is incremented once
per tick and is not otherwise identified here.

The stages, in the order they run:

| at | runs | calls | what |
| --- | --- | --- | --- |
| `0x68207A` | every hour | `0x282440` | snapshots the generator state into `state+0xC58` |
| `0x682080` | every hour | `RunHourlyPass` `0x282630` | the hourly simulation pass |
| `0x68213A` | **day changed** | `RunDailyPass` `0x282C20` | everything daily - see below |
| `0x68213F` | day changed | `in_game_screen` slot 53 -> `0x261CA0` | the screen's own daily update |
| `0x6821C1` | month changed | `RunMonthlyPass` `0x283B50` | |
| `0x6821C6` | month changed | slot 54 | a no-op stub, `0xA92590` |
| `0x682211` | year changed | `RunYearlyPass` `0x283D20` | |
| `0x682216` | year changed | slot 55 | the same stub |
| `0x682268` | every hour, last | `0x28DB20` | deferred unit deletion, through `CGameState::RemoveUnit` |

Each of the three gates is a comparison against the value saved before the increment, with a
`je` over the call: the day at `0x682133` (`cmp [esp+0x28], eax`), the month at `0x6821BA`, the
year at `0x68220A`. Slots 54 and 55 both hold the same do-nothing stub, so **nothing in this
build hangs off the monthly or yearly screen hook** - only the two pass functions do work.

## `RunHourlyPass` and `RunDailyPass` are two functions

They abut with no padding between them: `0x282630` ends at `0x282C1D` with `ret 4`, and
`0x282C20` opens its own prologue. Read as one function - which is how the supply findings
first recorded it - the daily work looks hourly. It is not.

The hourly pass calls exactly one thing this document has identified:
`CSupply::RebuildSupplyNetwork`, at `0x2826E8`, guarded on the dirty flag at
`CCurrentGameState +0x50`. So a depot label changed during the hour is repaired inside the
hour.

`RunDailyPass` (rva `0x282C20`, to `0x283077`, `ret 4`) calls, in order:

    0x28C190, 0x63030, a CGameState construction,
    CSupply::RebuildSupplyNetwork (0x282CEF, on the same dirty flag),
    CSupply::ResetSupplyOrder, a qsort with the comparator at 0x27B100 pushed at 0x282D0C,
    CProvince::UpdateSupplyDepot in a loop, 0x4F28B0,
    RunDailySupplyPass (0x282D7E),
    0x28A0A0, 0x28E350, 0x4E39C0, 0x4DA530, 0x49EAB0, 0x4B9D60,
    0x5BF720, 0x5C0A40, 0x288D40, 0x143AB0

So **the supply order is sorted and the supply pass run once a day**, not once an hour.

Two of those are worth naming as leads rather than left as numbers:

- **`0x4DA530`** is a per-country pass over the country vector and is the daily politics work -
  it writes effective neutrality from neutrality, reads the alignment defines, and zeroes
  dissent for the `REB` country.
- **`0x5C0A40`** is where events are evaluated. It calls `CMeanTimeToHappen::GetChance`
  (`0x9C4AB0`) at `0x9C0B85`, draws from the generator (`0xAA2F80`, with the refill at
  `0xAA2C80`) and calls `0x9C0C80` on a hit. So **the daily pass reaches the event machinery
  once a day** - but see *The daily event call and what players see* below before concluding
  events are evaluated daily. Note that `0x9C0520` and `0x9C0A40` are *also* two abutting
  functions -
  `0x9C0520` ends at `0x9C0A3D` with `ret 4` and `0x9C0A40` has its own prologue and its own
  SEH handler - so a scan that runs from `0x9C0520` attributes this loop to the wrong one.

## The daily event call and what players see do not agree

The call above is read from the executable and is not in doubt: `RunDailyPass` calls
`0x9C0A40` every day, and that function computes a mean-time-to-happen chance and draws from
the generator. **What is in doubt is whether that amounts to evaluating events.**

Against it, from playing the game: **after loading a savegame, events do not fire until the
first of the following month**, and then arrive as a barrage on that day. Reported by David,
2026-09-30, from long experience of the mod rather than a single session. If the daily call
were doing the whole job, a loaded save would produce events the next day.

**This was settled the same day - see `FINDINGS-events.md`.** The daily pass walks a
per-country candidate list at `CCountry +0x8`, skips any country whose list is null, and that
list is written in exactly one function, which only `RunMonthlyPass` and a lobby path call. A
load leaves it empty, so the pass skips every country until the month turns. Two of the four
shapes guessed below turned out to be wrong and are kept only so nobody tries them again:
there is **no** per-event accumulated-days or last-evaluated field, `GetChance` being
memoryless; and `0x9C0430`'s scenario/global branch is not on the tick at all, its callers
being `CEU3Application::LoadEverything` and `CInGameIdler::Enter`, so `+0xD0C` cannot gate it.

The shapes as they were guessed:

- **`RunMonthlyPass` (`0x283B50`) builds or refreshes what the daily call walks**, and a load
  leaves it empty until the next month boundary. This is the cheapest hypothesis to test and it
  points at a function that is already named and still unread.
- Each event carries a "last evaluated" or accumulated-days figure that loading resets, so
  nothing reaches its threshold until a monthly pass reseeds it.
- The daily call's country loop is gated on something a freshly loaded game has not set. The
  loop is known to skip any country whose owned-province count (`+0xCF8`) is zero or less.
- `0x9C0430` chooses between a scenario pass (`0x9BF7B0`, off `scenario+0xB0`) and a global one
  depending on game-state `+0xD0C`; a load may take the other branch for a while.

So **do not cite this document for how often events are evaluated** - cite
`FINDINGS-events.md`. What this one establishes is only which function the tick calls, and
when.

## Part of the daily pass is not on this thread

Functions that construct a `tbb::task_group_context` and allocate a root task through it -
the imports at `0xD2B55C`, `0xD2B574`, `0xD2B578` and `0xD2B58C`. The game links Intel TBB and
fans work out to worker threads, and **the RTTI export names the functor for each one**, so
there is no guesswork about what is being parallelised:

| fan-out | functor | its one caller | so it runs |
| --- | --- | --- | --- |
| `0x28DFD0` | `ProcessUnitFunctor` | `0x682887` in `RunHourlyPass` | every hour |
| `0x28E0B0` | `ProcessCountryFunctor` | `0x6828D4` in `RunHourlyPass` | every hour |
| `0x28E190` | `ProcessAITradeFunctor` | `0x6829DC` in `RunHourlyPass` | every hour |
| `0x28E270` | `ProcessProvinceFunctor` | `0x682A3B` in `RunHourlyPass` | every hour |
| `0x28E350` | `ProcessCountriesPreDailyUpdate` | `0x682DDD` in `RunDailyPass` | once a day |
| `0x28E430` | `ProcessAIFunctor` | `0x68310B` in `CGameState::RunAIPass` | every hour |
| `0x28E800` | `ClearIntelFunctor` | `0x68E510`, from `0x688DD8` | not established |
| `0x28E870` | `UpdateIntelFunctor` | `0x68E5E0`, from `0x689278` | not established |

**Two corrections, both of which this document got wrong first time round.**

`0x28E350` is **not** the AI fan-out. It writes vftable `0x15CF72C`, which RTTI names
`start_for<..., ProcessCountriesPreDailyUpdate, ...>`; the AI's is `0x15CF73C`, written by
`0x28E430` at `0x68E4AE`. The two functions are otherwise instruction-identical, which is how
they came to be conflated. So `RunDailyPass` never touches the AI at all - its fan-out rebuilds
each country's neighbours.

And there is **no second set of `parallel_for` sites**. Each functor vftable's second reference
is inside its own `start_for::execute` (slot 1), in `0x68EBF0`-`0x68F2FC`: a `start_for` that
splits its range allocates a **child of its own type** and so writes the same vftable. Verified
for all eight. Nothing was hiding.

**So the AI pass is hourly, and `FINDINGS-ai.md` was right throughout.** The path is not a tick
stage at all - it is a latch handshake between the hourly pass and the idler:

- `RunHourlyPass` **sets** `CCurrentGameState +0xC68` at `0x6829E4`, right after launching the
  AI trade fan-out, so the AI pass cannot start while the hourly pass is still running;
- at its end it **clears** the byte at `0x682B1D`, but only if `+0xD9D` is zero - `jne 0x682B37`
  skips the clear otherwise;
- `CInGameIdler::Update` offers `CGameState::RunAIPass` (`0x283080`) every frame; the function
  returns immediately while the byte is set, and on the one frame it is clear it runs the AI
  fan-out and sets the byte again (`0x683116`).

The practical consequence: **`ForeignMinister_Tick` and its siblings run once per game day per
live AI country**, at hour `(country_id + 13) mod 24`, because the hour gate is offered every
hour and matches once a day. The unknown that remains is what `+0xD9D` is: while it is non-zero
the latch is never released and the AI pass stops recurring entirely.

**This matters for hooking.** BiceLib's existing hooks are safe because they run on the thread
that owns the Direct3D device and the Lua state. A hook placed inside one of these functors is
not on that thread, so it must not touch Lua, must not raise a message, and must not assume
the ImGui frame. Nothing in the repository mentioned TBB before this.

## The generator

`g_random_seed` (rva `0x1310F80`) is already named for the save field it writes, but it is the
base of the **whole 624-word Mersenne Twister state**: `0x1310F80 + 624*4 = 0x1311940`, which
is exactly the index variable the draw code divides by `0x270` (624). The refill is `0x6A2C80`,
a raw draw `0x6A2F80`.

The tempering in the draw at `0x9C0BD9` is MT19937's, once the compiler's rewrite is undone:
`y ^= y >> 11`; `y ^= (y & 0xFF3A58AD) << 7`, where the low 25 bits of that mask are
`0x9D2C5680 >> 7`; `y ^= (y & 0xFFFFDF8C) << 15`, low 17 bits `0xEFC60000 >> 15`; `y ^= y >> 18`.
Both masks match exactly.

**One deviation worth knowing: both right shifts are `sar`, not `shr`.** The state is treated
as signed, so for words with the high bit set this does not produce reference MT19937 output.
The result is masked with `0x7FFFFFFF` before use.

`0x282440`, run every hour on `state+0xC58`, clears that vector and pushes two dwords into it:
`g_random_draws` (`0x174DA8C`) and the contents of `0x174DA94`, which is not identified. The
`CHourlyTickCommand` constructor is handed a pointer to the same `+0xC58`, so **the tick
command carries the generator's bookkeeping with it** - which is what a multiplayer peer would
need to stay in step. That reading is inference; nothing here traced the command onto a socket.

## What is not established

- What `RunYearlyPass` (`0x283D20` to `0x283E7D`, `ret 4`) does. Since slots 54 and 55 are
  stubs, it is the whole of the game's yearly behaviour, which makes it unusually cheap for
  what it would explain.
- **`RunMonthlyPass` is now partly read** (`FINDINGS-techdecay.md`). Its shape is two loops and
  a tail: one over the province vector `state+0xB8C` from index 1, calling `0x49F3E0` per
  province and then running province `nationalism` (`+0x24`) down by 83 thousandths with a floor
  at zero (`0x683BA5`); one over the country vector `state+0xBBC` from index 1, calling
  `CCountry::UpdateMonthly` (`0x4DC840`), which is **where technology practicals and theories
  decay**; then the event-candidate rebuild at `0x683CE1`. `0x49F3E0`, the province's own
  monthly work, is still unread.
- **The block at `0x683E80` to the bare `ret` at `0x683ED1`.** It follows the yearly pass's
  `ret 4` without padding, has no prologue, and uses `edi` without setting it, so it is
  out-of-line code belonging to some other function. Which one is unknown. Anything that reads
  from `0x283D20` to the next `int3` will wrongly swallow it - the third time in this document
  that abutting functions have caused exactly that.
- Which of the daily pass's unnamed callees does what, beyond the two called out above.
- `0x174DA94`, the second dword the hourly snapshot records.
- `0x1A8560C`, incremented once per tick.
- The five speed thresholds' values, and which index is pause.
- Whether the `+0xC58` snapshot is actually sent to peers, or only kept for the save.
- What `in_game_screen` slot 18 returns, and what class holds the `+0x38` the command is
  posted to. That is the choke point every `CCommand` passes through and it is the obvious
  next thing to name.
