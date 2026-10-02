# How often the AI runs, and what a year change does

Two questions, both settled out of the executable on 2026-09-30 with the game not running.
Addresses are virtual, based at `0x400000`, with the rva beside them where a finding names
one.

**In one line.** There is exactly **one** recurring path to the AI and it is **hourly**;
`RunDailyPass`'s TBB fan-out is a *different* functor that nobody had identified, and the
"second set of `parallel_for` sites" `FINDINGS-tick.md` warned about does not exist - it is the
recursive child-task allocation inside each `start_for::execute`. `RunYearlyPass` writes one
statistics sample per country per year and bumps a counter; that is all it does.

## The contradiction, and why both halves of it were wrong

`FINDINGS-tick.md` ends its TBB table with

    | 0x28E350 | ProcessAIFunctor | 0x682DDD | once a day |

and adds that each of the five functor vftables is referenced twice, "so a second set of
`parallel_for` sites exists". Both statements are mistakes, and each has a one-instruction
disproof.

### `0x68E350` is not the AI fan-out

`0x68E350` (rva `0x28E350`) writes the vftable **`0x15CF72C`** into the root task it allocates,
at `0x68E3CE`:

    0x0068E3CE  mov     dword ptr [esi], 0x15cf72c

`0x68E430` (rva `0x28E430`, already named `SpawnProcessAIParallelFor`) writes `0x15CF73C` at
`0x68E4AE`. The two functions are otherwise instruction-for-instruction identical - separate
template instantiations of `tbb::parallel_for` - which is presumably how they came to be read as
one. The RTTI export settles which is which:

    0x15CF72C   start_for<blocked_range<I>, ProcessCountriesPreDailyUpdate, auto_partitioner>
    0x15CF73C   start_for<blocked_range<I>, ProcessAIFunctor,               auto_partitioner>

So the fan-out `RunDailyPass` calls at `0x682DDD` is **`ProcessCountriesPreDailyUpdate`**, a
sixth functor the tick document does not list at all. Nothing in `RunDailyPass` touches the AI.

### The "second set of sites" is `start_for::execute` splitting its own range

Every one of these functor vftables has three slots, and slot 1 - `tbb::task::execute` - is a
separate function per functor:

| vftable | functor | slot 0 | **slot 1 = `execute`** | slot 2 |
| --- | --- | --- | --- | --- |
| `0x15CF6EC` | `ProcessUnitFunctor` | `0x68E8F0` | `0x68EBF0` | `0x60CD50` |
| `0x15CF6FC` | `ProcessCountryFunctor` | `0x68E8F0` | `0x68ECE0` | `0x60CD50` |
| `0x15CF70C` | `ProcessAITradeFunctor` | `0x68E8F0` | `0x68EDE0` | `0x60CD50` |
| `0x15CF71C` | `ProcessProvinceFunctor` | `0x68E8F0` | `0x68EEB0` | `0x60CD50` |
| `0x15CF72C` | `ProcessCountriesPreDailyUpdate` | `0x68E8F0` | `0x68EF80` | `0x60CD50` |
| `0x15CF73C` | `ProcessAIFunctor` | `0x68E8F0` | `0x68F080` | `0x60CD50` |
| `0x15CF74C` | `ClearIntelFunctor` | `0x68E8F0` | `0x68F170` | `0x60CD50` |
| `0x15CF75C` | `UpdateIntelFunctor` | `0x68E8F0` | `0x68F250` | `0x60CD50` |

`0x68EBF0` to `0x68F2FC` **is** the `0x68EC00`-`0x68F101` range the tick document flagged. A
`start_for` task that is handed a range larger than its grain allocates a *child* `start_for` of
its own type and writes the same vftable into it - which is the second reference, once per
functor, and it is inside that functor's own `execute`:

    ClearIntel  0x68F1E6  in 0x68F170        AITrade   0x68EE56  in 0x68EDE0
    Unit        0x68EC6F  in 0x68EBF0        Province  0x68EF26  in 0x68EEB0
    Country     0x68ED61  in 0x68ECE0        PreDaily  0x68EFFF  in 0x68EF80
    AI          0x68F0FF  in 0x68F080        UpdIntel  0x68F684  in 0x68F510 (*)

`findRefs.py --address` on all eight vftables returns exactly two hits each: the launcher's root
task and the `execute`'s child task. **There is no second launch site for any of them.**
(*) `UpdateIntelFunctor`'s second write is at `0x68F684`, past `0x68F250`'s own `ret` - that
function's continuation is `0x68F510`, which is not read here.

### The abutting-function trap was *not* what happened at `0x283080`

The brief was right to suspect it and wrong on the facts. `RunDailyPass` ends at `0x683077`
with `ret 4`, and there are **six `int3` bytes** at `0x68307A`-`0x68307F` before `0x683080`'s
own `push ebp; mov ebp, esp` and its own SEH handler push (`0xC11888`). `0x683080` is a genuine
separate function with `ret 4` at `0x683133` and ten bytes of padding after it. The previous
"hourly via `CInGameIdler::Update` -> `0x283080`" reading is sound.

(There is a fresh instance of the trap two hundred bytes away, though: `0x68E510` ends with a
bare `ret` at `0x68E5DF` and `0x68E5E0` begins a new function - `push ebp; mov ebp, esp; and
esp, -8` plus its own SEH push `0xC1183D` - with **no** padding, and `0x68E6B0` abuts that one
in turn with a third. `0x68E5E0` has its own caller, `0x689278`. That is the fifth time in this
folder.)

## The whole fan-out map, as read

Each launcher has exactly one direct caller (`findRefs.py --callers`), and each `execute`
has a serial body that runs when the range is down to the grain.

| functor | launcher | its one caller | in | `execute` | serial body calls |
| --- | --- | --- | --- | --- | --- |
| `ProcessUnitFunctor` | `0x68DFD0` | `0x682887` | `RunHourlyPass` | `0x68EBF0` | `0x5B9C50` |
| `ProcessCountryFunctor` | `0x68E0B0` | `0x6828D4` | `RunHourlyPass` | `0x68ECE0` | `0x5004F0` |
| `ProcessAITradeFunctor` | `0x68E190` | `0x6829DC` | `RunHourlyPass` | `0x68EDE0` | `0x67B160` |
| `ProcessProvinceFunctor` | `0x68E270` | `0x682A3B` | `RunHourlyPass` | `0x68EEB0` | `0x67B1C0` |
| `ProcessCountriesPreDailyUpdate` | `0x68E350` | `0x682DDD` | `RunDailyPass` | `0x68EF80` | `0x5033B0`, `CCountry::RebuildNeighbours` |
| `ProcessAIFunctor` | `0x68E430` | `0x68310B` | `CGameState::RunAIPass` | `0x68F080` | `ProcessAI` (`0x8894E0`) |
| `ClearIntelFunctor` | `0x68E800` | `0x68E598` | `0x68E510` | `0x68F170` | `0x688170` |
| `UpdateIntelFunctor` | `0x68E870` | `0x68E668` | `0x68E5E0` | `0x68F250` | `0x6883B0` |

The four `RunHourlyPass` callers and the one `RunDailyPass` caller are confirmed by
`image.functionStart` against the named extents. `0x683056`, the call to `0x688D40`, sits in
`RunDailyPass` even though `functionStart` reports `RunHourlyPass` - that is the
`0x682630`/`0x682C20` abutting pair fooling a padding-based scan, and `RunDailyPass`'s extent
(`0x682C20`-`0x683077`) is what decides it.

The six launchers in the first six rows end in a **bare `ret`** with one stack argument the
caller pops (`add esp, 4` at `0x683113` after the AI one), and take the `blocked_range` in
**`EDI`**. The two intel launchers end `ret 8`. The range is three dwords in TBB's declaration
order, `my_end` at `+0`, `my_begin` at `+4`, `my_grainsize` at `+8` - visible both in the
emptiness test `mov eax,[edi+4]; cmp eax,[edi]; jae <skip>` and in `RunAIPass` filling
`[ebp-0x1C] = count`, `[ebp-0x18] = 0`, `[ebp-0x14] = grain` with `edi = ebp-0x1C`.

### Both intel functors are reached from the daily pass

`0x68E510` launches `ClearIntelFunctor` and is called once, from `0x688DD8`; `0x68E5E0`
launches `UpdateIntelFunctor` and is called once, from `0x689278`. Both of those two take the
`blocked_range` in **`ECX`**, not `EDI`, and one stack argument the caller pops: `lea ecx,
[ebp-0x6C]` over `{end, 0, grain}` and `push eax` at `0x688DD4` and `0x689274`, with
`add esp, 4` at `0x68927D`. `0x688DD8` is inside
`0x688D40`, and `0x688D40`'s six callers include `0x683056`, the last call in `RunDailyPass`.
So intel is cleared and recomputed on TBB workers **at least once a day**; the other five
callers of `0x688D40` (`0x41D8EA` in `ApplyCustomGameSettings`, `0x66042A`, `0x683EC9`,
`0x68932D`, `0x69DDB3`) are not on the tick and are not read here.

## So the AI is hourly

The chain, every link of it confirmed:

    CInGameIdler::Update (0x6559D0)            once a frame
      -> 0x683080  CGameState::RunAIPass       at 0x656278, ret 4
           gate: if (state[+0xC68] != 0) return                 0x68309F
           grain = max(1, count / ([0x170ABB0] == 1 ? 1 : 16))  0x6830CC-0x6830F1
           byte [0x1A857BF] = 1 ... restore afterwards
      -> 0x68E430  SpawnProcessAIParallelFor   at 0x68310B
           state[+0xC68] = 1                                    0x683116
      -> 0x68F080  ProcessAIFunctor start_for::execute
           serial body 0x68F14D: for (i = begin; i < end; ++i) ProcessAI(vec[i])
      -> 0x8894E0  ProcessAI                   at 0x68F15A
      -> CAIAgent::Update, slot 9              per agent on the CEU3AI's +0x74 list
      -> the minister's slot 10, e.g. CAIForeignMinister 0x49D600
      -> ForeignMinister_Tick                  at 0x89D69F, when the hour gate matches

`vec` is `CCurrentGameState +0x114` (`ai_agents`): `RunAIPass` computes
`count = (state[+0x118] - state[+0x114]) / 4` and hands `&state[+0x114]` in as the functor, and
`execute` dereferences it - `mov ecx,[esi+0x10]; mov edx,[ecx]; mov eax,[edx+edi*4]`.

**The latch is what makes it hourly.** A displacement-exact sweep of `.text` for
`[reg + 0xC68]` (locating the four-byte displacement in the bytes and decoding backwards to a
covering instruction) finds seven sites, five of them on the game state:

    0x67C5DF   mov byte [ebx+0xC68], 0    in 0x67BAF0, the CGameState construction region
    0x67D480   mov byte [ebx+0xC68], 0    in CGameState::CGameState (0x67D070)
    0x6829E4   mov byte [eax+0xC68], 1    RunHourlyPass, right after the AITrade fan-out
    0x682B1D   mov byte [edi+0xC68], 0    RunHourlyPass, at its end
    0x68309F   cmp byte [ebx+0xC68], 0    RunAIPass, the gate
    0x683116   mov byte [ebx+0xC68], 1    RunAIPass, after the spawn

(The other two, `0x51836B` in `0x518200` and the `[esp+0xC68]` stack accesses, are not this
field.) `+0xC68` is already recorded as `ai_pass_done`. So: the hourly pass clears it as its
last act, the next frame `RunAIPass` sees zero, runs the parallel AI pass and sets it again, and
nothing clears it until the next hour. **One AI pass per game hour**, lagging the hour by
however long the command queue takes to execute the tick.

**One caveat nobody had noticed.** The clear at `0x682B1D` is guarded:

    0x00682B14  cmp     byte ptr [esi + 0xd9d], 0
    0x00682B1B  jne     0x682b37
    0x00682B1D  mov     byte ptr [edi + 0xc68], 0

`esi` there is the `CCurrentGameState` singleton at `0x1A89790` (which the surrounding code
constructs if it is null), `edi` is the state passed in. When `+0xD9D` is **non-zero** the
function jumps to `0x682B37` instead - a country loop that posts a command per country through
`country[+0xF1C]` slot 18 -> `+0x38` slot 6 - and **never clears `+0xC68`**. On that path the
parallel AI pass would not run again at all. What `+0xD9D` means is not established (it is one
of the three gates `FINDINGS-ai.md` already lists as unknown); that it selects a
non-parallel or non-local mode is **inference**.

### The answer to the deliverable question

`ForeignMinister_Tick` is called **once per game day for each country whose AI is live, at the
game hour `(country_id + 13) mod 24`** - which is exactly what `FINDINGS-ai.md` says, and the
tension the brief raised was caused by the tick document's misattribution, not by the schedule.
The hour gates can match because the pass is hourly.

Conditions, all from `FINDINGS-ai.md` and unchanged by this document: the country must have a
`CEU3AI` with a live `CAIForeignMinister` (every AI country gets all five ministers; the human's
country gets one only for a delegated ministry); `ProcessAI`'s opening gates must pass
(`CEU3AI +0x128 == 0`, `CCountry +0x580 == 0`, and the country-database record's `+0xCF8 > 0` or
`+0x95 != 0`); the agent's enable byte `+0x3C` must be set; and the foreign minister's
skip-once byte `+0x70` must be clear. For 24 countries' worth of ids the hours are distinct, so
the work spreads across the day rather than landing on one hour.

**For hooking**: unchanged and worth repeating, because the "once a day" reading would have made
it look safer than it is. `ProcessAI` and every minister tick run on **TBB worker threads**, not
the thread that owns the Direct3D device and the game's Lua state. The ministers' Lua runs on a
*per-thread* `lua_State` (`0x8EACA0`), not the game's. A BiceLib hook there must not touch the
main Lua state, must not raise a message, and must not assume the ImGui frame.

### What the daily fan-out actually does

`ProcessCountriesPreDailyUpdate`'s serial body, `0x68F04D`, over the country vector
`CCurrentGameState +0xBBC`:

    for (i = begin; i < end; ++i) {
        c = vec[i];
        if (c[+0x44] == 0) continue;
        0x5033B0(c);                      // this in EAX
        CCountry::RebuildNeighbours(c);   // 0x4E21E0, one stack argument
    }

`0x5033B0` (rva `0x1033B0`) is `0x5033B0`-`0x503650`, bare `ret`, `this` in `EAX`, and is
nothing but an unrolled fill: 56 stores of the dword at the global `0x1A87818` into
`country + 0x79C` through `country + 0x8B0`, in eight groups of seven at a stride of `0x24`.
So the country carries an eight-element array of `0x24`-byte records there and seven fields of
each are reset once a day. What the array is, and what value `0x1A87818` holds, are not
established - the global sits in a zero-fill part of `.data`, so the file does not say.

`RunDailyPass` also runs a serial loop over the same vector with the same `[c+0x44]` gate
immediately before the fan-out (`0x682D60`-`0x682D7B`, calling `0x4F28B0` with the country in
`EAX`), so the daily country work is one serial pass then one parallel pass.

## `RunYearlyPass`, rva `0x283D20`

`0x683D20` to the `ret 4` at `0x683E7D`, `__stdcall`, one `CCurrentGameState*`. Since
`in_game_screen` slot 55 is the do-nothing stub, this is the whole of a year change.

It opens with the same singleton guard `RunHourlyPass` uses: if `[0x1A89790]` is null it takes
`0xDA8` bytes, calls `CGameState::CGameState` (`0x67D070`), writes the vftable `0x15CF674`,
zeroes `+0xD9C` (word), `+0xDA0` and `+0xDA4`, releases whatever was there and stores the new
pointer (`0x683D4F`-`0x683DBA`). Then:

    year = (int)( (double)((tick - 0x29C55C0) / 24) / 365.0 )     0x683DBE-0x683DF6
           tick from the *argument*'s +0xBDC; 365.0 at 0x160A550
    for (p = singleton[+0xBBC]; p >= begin && p < end; p += 4) {   0x683E00
        c = *p;
        AppendStatisticsSample(state[+0xC70],           // nation_size_statistics
                               CCountryTag string from c[+0xCA4],
                               c[+0xCF8],               // the owned-province count
                               year);
    }
    state[+0xC78]++;                                              0x683E67

The tag is turned into a `Hoi3CString` on the stack - `sub esp, 0x1C`, capacity `0xF`, size `0`,
then an inline `strlen` over `c+0xCA4` and `std::string::assign` (`0x40A160`) at `0x683E4B` -
and passed **by value**. Note the loop reads the *singleton*'s country vector while the year
comes off the *argument*'s tick; usually the same object.

**`0x5F3B90` (rva `0x1F3B90`), `ret 0x28`, `__stdcall`** - and `0x28` = 40 = `4 + 0x1C + 4 + 4`,
which fixes the argument list exactly: `(void* collection, Hoi3CString name, int value,
int year)`. One caller in the whole image, this loop. It walks the collection's records -
begin `collection[+8]`, end `collection[+0xC]`, stride `0x44`, each record holding a name at
`+0x18` compared with `0x415F70` - and appends `value` to that record's vector at `+0x24`/`+0x28`
and `year` to the one at `+0x34`/`+0x38`. If no record matches it builds a fresh one (name, two
vectors) and pushes it in, freeing the temporaries through `0xB95F9B`.

So **a year change appends one (province count, year) sample per country to
`nation_size_statistics` and increments a counter. Nothing else.** That is consistent with
`+0xC6C`/`+0xC70`/`+0xC74` already being recorded as the three statistics the save carries: the
graph the game draws of nation size over time is built here, one point per country per year.

**`CCurrentGameState +0xC78` is new.** A displacement sweep for `[reg + 0xC78]` finds exactly
two sites on the game state: `0x67D487`, which zeroes it in `CGameState::CGameState` right
after the `+0xC68` zero, and `0x683E67`, the increment here. Nothing reads it, nothing saves it.
So it is a count of year changes since the game state object was built - which, because a load
constructs a new one, is **not** the number of years since 1936.

## The unattributed block at `0x683E80` is a function with twelve callers

It is not out-of-line code. `0x683E80` to the bare `ret` at `0x683ED1`, frame-less
(`push ecx` reserves the slot, `pop ecx` at the end), the game state in **`EDI`**, no stack
arguments, then ten `int3`. A rel32 scan of `.text` for anything targeting
`0x683E80`-`0x683ED1` finds four internal branches and **twelve calls**: `0x6D629C`, `0x6EDA27`,
`0x6F4474`, `0x6F4AC4`, `0x6F50C4`, `0x6F5724`, `0x707F16`, `0x70B333`, `0x70B798`, `0x70BA89`,
`0x7148D2` and `0x71DAB5`. Two of the containing functions are in vftables: `0x6D60C0` is
**`CSetHistoryDate` slot 6** and `0x714100` is **`CGameSetup` slot 11**, so the callers are the
lobby and scenario-setup machinery. None of the twelve is on the tick.

    for (i = 0; i < countryCount; ++i)                  vector at state[+0xBBC]
        if (vec[i][+0x44] != 0) 0x4E3EB0(vec[i]);        country in ESI
    0x688D40(state);

`0x4E3EB0` (rva `0xE3EB0`) is a ten-instruction wrapper, bare `ret`, country in `ESI`:
`CCountry::RebuildNeighbours(c)` then `0x4E39C0(c)` - and `RunDailyPass` calls `0x4E39C0`
itself. So this function is "redo, for every country at once, the parts of the daily pass that
depend on which countries exist", and `0x688D40` at the end is the same call `RunDailyPass`
makes last. The name given here, `RefreshAllCountries`, is **inference from that shape and from
the two vftable callers**; nothing was watched running.

The comment currently on `RunYearlyPass` in `project.json` says the block "uses edi without
setting it and has no prologue, so it is out-of-line code belonging to some other function".
The first half is true and the conclusion is wrong; `EDI` is its calling convention.

## What is not established

- **`CCurrentGameState +0xD9D`**, which decides whether `RunHourlyPass` clears `ai_pass_done` at
  all. On the other branch the parallel AI pass would stop recurring, and the loop that branch
  runs instead (`0x682B37`-`0x682C07`, posting a command per country) is not read. This is the
  one thing that could falsify "hourly" in some game mode, and it cannot be settled statically.
- **`0x170ABB0`**, which makes the AI grain the whole range (one chunk, so effectively serial)
  when it is `1` and a sixteenth otherwise. Written once, at `0xA566E3`. Whether it is the
  thread count, a `settings.txt` key or a debug switch is unknown - and if it is `1` in a normal
  game then "on worker threads" is true but "concurrently" is not.
- **`0x1A857BF`**, the byte `RunAIPass`, `RunHourlyPass` and `RunDailyPass` all save, set to 1
  and restore around their fan-outs. A clean sweep of it was not done here; the naive scan is
  swamped by misaligned decodes of `add eax, 0x1a857bf`.
- **What the eight `0x24`-byte records at `CCountry +0x79C`-`+0x8B0` are**, which `0x5033B0`
  resets daily, and the value at `0x1A87818` it resets them to. Eight is suggestive given HoI3's
  six resources plus money and manpower, but that is a guess and is recorded here only so nobody
  mistakes it for a reading.
- **`CCountry +0x44`**, the byte three separate country loops use to skip an entry
  (`0x682D65`, `0x68F059`, `0x683EA9`). It is plainly "this slot is in use", but it is not
  claimed here because `CCountry` fields are being written by several people at once.
- The serial bodies of the four hourly functors - `0x5B9C50` (unit), `0x5004F0` (country),
  `0x67B160` (AI trade), `0x67B1C0` (province) - and the two intel ones, `0x688170` and
  `0x6883B0`. Named as callees only; none was read.
- `UpdateIntelFunctor`'s `execute` continues past `0x68F2FC` into `0x68F510`, which is where its
  child task is allocated. Why that split exists is unknown.
- The five other callers of `0x688D40` (`0x41D8EA` in `ApplyCustomGameSettings`, `0x66042A`,
  `0x683EC9`, `0x68932D`, `0x69DDB3`), so "intel is daily" is a floor, not a schedule.
- `0x4E39C0`, the second half of `0x4E3EB0`, and `0x4F28B0`, the daily serial pass's per-country
  call. Both are in the tick document's list of `RunDailyPass` callees and both are still just
  numbers.
- Which class owns the statistics collection `+0xC70` points at, and what its `0x44`-byte
  records are beyond "a name at `+0x18` and two parallel vectors".
- `RunMonthlyPass` (`0x283B50`-`0x283D0F`) is still unread. It is the last of the four passes
  with no contents recorded, and `FINDINGS-events.md` makes it the thing that decides when
  events fire.
