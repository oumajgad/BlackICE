# When each unit-level update runs, and on which thread

Addresses below are **virtual** (base `0x400000`) with the rva beside them where a finding names one.

---

## In one line

`CUnit::CheckOrderAndCombat` runs **on the tick thread**, once per game hour, from a per-country function that `RunHourlyPass` calls itself — and that function is also what *builds the list* the unit fan-out then chews on a worker thread. So `COrder` slot 14 is hookable with the ordinary rules. `+0xD9D` is the **tutorial** flag and cannot be set in a normal game, so it is not the AI-stopped bug. Both intel fan-outs come out of one function that the tick reaches daily (unconditionally) and hourly (on request). And `0x28DB20` is not "deferred unit deletion" — it is a TBB concurrent-queue `try_pop`, which turns out to be exactly the mechanism that keeps a worker thread from ever freeing a unit.

---

## 1. `CUnit` slot 31 — answered, and the answer is good news

### The enumeration is closed

`CUnit::CheckOrderAndCombat` (rva `0x1BA2F0`) has **zero direct callers**. Slot 31 is displacement `+0x7C`, so I looked for the dispatch three ways and then closed the question a fourth way:

- **Which classes hold it at slot 31.** Reading the image at all 2707 vftable addresses in the RTTI export: `CUnit` (`0x15C85CC`), `CArmy` (`0x15BDE0C`), `CAir` (`0x15C8774`) hold `0x5BA2F0`; `CNavy` (`0x15C869C`) holds the override `0x5CFDD0`. It appears at **no other slot of any class**.
- **`slotcalls.py 31`** finds 522 sites in 257 functions — nearly all other classes' slot 31.
- **The target's convention closes it.** `0x5BA2F0` runs to a **bare `ret`** at `0x5BAC49` with no `int3` and no other `ret` in between, so it is `__thiscall` with **no stack arguments**. `CNavy`'s override is 0x34 bytes and ends `jmp 0x5BA2F0` at `0x5CFDFF`, which agrees. So a real call site must put the receiver in ECX and push nothing.
- **And the decisive check:** `image.findBytes` for `0x5BA2F0` anywhere in the image returns exactly **three** hits, and for `0x5CFDD0` exactly **one** — and all four are slot `+0x7C` of the four vftables (`0x15BDE88`, `0x15C8648`, `0x15C87F0`, `0x15C8718`). **There is no function-pointer table, no Lua binding, no thunk.** Every call must be a `[reg+0x7C]` dispatch.

Filtering the 522 on shape leaves fifteen; an aligned linear sweep of `.text` (resynced at every `int3` run, so `push 0x7c` cannot masquerade as a slot load) leaves twelve. All but one have a receiver that is demonstrably not a `CUnit`: `CStratWarfareWindow` slot 5, `CPoliticsView` slot 6, `CSideMenuDeploy` slot 7, `CWindowForLoadedUnitsEntry` slot 9, `CBackEndIdler` slot 3, `CInGameIdler` slot 3, a window proc at `0xACC2E0`, a receiver that is `state+0xBE8` (the in-game screen) at `0x867AA8`, and GUI/serialisation bodies around `'bookmarks'`, `'sup_subunits'` and `'list'`. Several of them dispatch slots above `+0xA4`, which alone rules out a 42-slot `CUnit`.

### The one real call site

    0x004D8F72   mov  eax, [edx + 0x7c]
    0x004D8F78   mov  ecx, esi
    0x004D8F7D   call eax                  <- CUnit::CheckOrderAndCombat

inside **`0x4D8EB0`** (rva `0xD8EB0`), which has exactly **one caller: `0x682833`, inside `RunHourlyPass` itself** (`retsBefore(0x682630, 0x682833)` is empty, so this is not the `0x682630`/`0x682C20` abutting trap). `this` is a `CCountry` — `+0xBAC` (`units`), `+0xCA4` (`tag`), `+0xCA8` (`id`), `+0xCF8` (owned provinces), `+0x95`, `+0x580` all line up — and the caller loop is a **serial** walk of the country vector `CCurrentGameState +0xBBC` gated on `CCountry +0x44`:

    0x00682820  for (i = 0; i < countryCount; ++i)
    0x0068282C      if (vec[i]->+0x44 == 0) continue;
    0x00682832      push edi                          // a std::vector<CUnit*> collector
    0x00682833      call 0x4D8EB0                     // ecx = the country

**So: `CUnit` slot 31 runs on the tick thread, once per game hour, once per unit. `COrder` slot 14 is hookable with the ordinary rules — it may touch Lua, the ImGui frame and the D3D device.** I propose the name `RunCountryHourlyPass` for `0x4D8EB0` (`void __thiscall (CCountry*, std::vector<CUnit*>* survivors)`, `ret 4`, `0x4D8EB0`–`0x4D9165`).

### What that function does, in order

Per node of `country->units` (a node is `{unit, ?, next}`):

    unit->slot31()                                   0x4D8F7D   CheckOrderAndCombat
    if (unit->+0x40 == 0 && unit->slot15())
        CGameState::RemoveUnit(state)(unit, 0, 1)    0x4D8FB5   synchronous, this thread
    else if (no provinces && not government-in-exile && owner != "REB")
        CGameState::RemoveUnit(state)(unit, 0, 1)    0x4D8FFD
    else
        survivors->push_back(unit)                   0x4D9004-0x4D904F

then `0x508C30(country)`; then an hour gate, `hour == country->id % 24`, feeding `0x8AC400(country + 0x48C, matched)` — or `0x8A9B10(country + 0x48C, 0)` when `CCountry +0x580` is set; then `0x4E0B80(country)` when the province count is positive; then `country->+0x11CC = 0`.

**The `survivors` vector is the unit fan-out's input.** `RunHourlyPass` takes its length at `0x68283D`, builds the `blocked_range` at `0x68287D`–`0x682880` with the vector as the functor's payload, and calls `SpawnProcessUnitParallelFor` at `0x682887`. `ProcessUnitFunctor`'s serial body then reads `functor->+0x10` as that vector and calls `CUnit::UpdateHourly` per element:

    0x0068ECC1  mov  ecx, [esi + 0x10]
    0x0068ECC4  mov  edx, [ecx]
    0x0068ECC6  mov  ecx, [edx + edi*4]
    0x0068ECC9  call 0x5B9C50                  CUnit::UpdateHourly

(The bare `ret` at `0x68ECBC` before it is `start_for::execute`'s early exit for the split case, not a function boundary — the epilogue at `0x68ECD3` pops the same frame. Trap 3, resolved the right way round.)

So the hourly unit work is **two phases**: order/combat validity serially on the tick thread over *all* units, then per-unit simulation on workers over the *survivors*. That is a clean design and it is exactly what makes slot 31 safe.

Also worth recording: **the hour gate at `0x4D9088`–`0x4D90C6` puts AI-region code (`0x8A9B10`, `0x8AC400`, on `CCountry +0x48C`) on the tick thread**, which contradicts nothing but is the first thing found in the AI address range that is *not* on a worker.

---

## 2. `CCurrentGameState +0xD9D` is the tutorial flag, and it cannot cause the bug

An aligned displacement sweep for `[reg + 0xD9D]` gives **14 sites and exactly two writers**:

    0x0071D365  mov byte [eax+0xD9D], bl   (bl = 0)   in 0x71D2D0
    0x0071D6BA  mov byte [eax+0xD9D], 1               in 0x71D4B0

Neither `0x71D2D0` nor `0x71D4B0` has a direct caller and neither is in any vftable. `image.findValue` finds **one** reference to each: `0x71CD89` and `0x71CD72`, both inside `0x71CD20`, which writes the vftable `0x15D5FD0` = **`CTutorialScreen`** and builds two `VCTutorialScreen::__CButtonObserverGlue` objects (`0x15D600C`) holding those two pointers. The constructor registers exactly seven button observers: `back_button`, then `tutorial_button_1` … `tutorial_button_6`. `0x71D4B0`'s body compares the pressed button against `tutorial_button_1`…`_6` and loads something under `tutorial/`.

So **`+0xD9D` is set when the player starts a tutorial from the tutorial screen and cleared when they press back**. It is also zeroed wherever a `CCurrentGameState` is constructed, by the *word* store `mov word [esi+0xD9C], 0` (at `0x4D8F05`, `0x683D62`, `0x71D320`, `0x478309` and the other singleton guards) — which zeroes `+0xD9C` and `+0xD9D` together.

**What it does when set** — three gates, all on the tick:

| where | when set |
| --- | --- |
| `RunHourlyPass`, `0x682B14` | **does not clear `ai_pass_done` (`+0xC68`)**, so the parallel AI pass never runs again; jumps to `0x682B37` instead, a per-country loop over `CCountry +0xF24` (`declarewar`) posting a command per pending entry through `country->+0xF1C` slot 18 → `+0x38` slot 6 |
| `RunDailyPass`, `0x682F7B` | jumps to `0x683055`, **skipping `RunDailyEventPass` (`0x9C0A40`)** and the lazy build of the global at `0x1B15670` that it uses |
| `RunMonthlyPass`, `0x683C69` | jumps to `0x683CE6`, **skipping the event-candidate rebuild `call 0x9C0050` at `0x683CE1`** |

Read together: **a tutorial runs with the event system off and with the parallel AI pass latched off**, doing war declarations through the command queue instead. That is coherent, and it is the strongest support for the name.

### The correction you asked me to raise rather than make

`project.json` records this field as **`CCurrentGameState.autosave_blocked`** (uint8_t). I believe that name is wrong and should become `tutorial_active`:

- the only two writers in the image are `CTutorialScreen` button handlers;
- `autosave_blocked` was evidently named after **one reader**, the autosave gate at `0x661DC9` inside `0x661D20`, which `DailyUpdate_CallAutosaveCheck` (`0x261D0C`) reaches. There are **twelve** readers, including `RunHourlyPass`, `RunDailyPass`, `RunMonthlyPass`, `CTopBar` slot 0 (`0x6CBF6E`) and `CFrontEnd` slot 3 (`0x6EFF77`). Naming a flag after one of its readers is the mistake trap 14 warns about;
- `FINDINGS-autosave.md` itself still says, at its *What is not established* list, "`gameState + 0xD9D`, the gate at step 4 … meaning not established". So the name in `project.json` is ahead of the folder's own prose.

I have **not** put a conflicting field entry in the JSON.

### And the practical answer

**`+0xD9D` is not a plausible cause of "the AI stopped playing".** There is no path to setting it except pressing a tutorial button, and any freshly constructed game state has it zero — which a load does. If an AI-stopped report exists, the cause is elsewhere; `FINDINGS-aisched.md`'s caveat can be downgraded from "the one thing that could falsify hourly in some game mode" to "reachable only in a tutorial".

---

## 3. The two intel fan-outs — one launcher, two schedules, both on the tick thread

**`0x688D40` is one function**, `0x688D40` to `ret 4` at `0x689303`, and it contains **both** launchers:

    0x00688DD8  call 0x68E510   SpawnClearIntelParallelForOuter  -> ClearIntelFunctor
    0x00689278  call 0x68E5E0   SpawnUpdateIntelParallelForOuter -> UpdateIntelFunctor

`retsBefore(0x688D40, 0x689278)` is empty, so `image.functionStart(0x689278)` answering `0x689201` is a mis-walk, not a second function. `FINDINGS-aisched.md` did not say where `0x689278` lived; it lives here. Propose the name **`RunIntelRefresh`**.

Six callers, and two of them are on the tick:

| caller | schedule |
| --- | --- |
| `0x683056`, in `RunDailyPass` | **once a game day, unconditional** — it sits at the daily pass's tail, *after* the `+0xD9D` branch target `0x683055`, so even a tutorial reaches it |
| `0x6822C3`, in `RunHourlyTick` | **at the end of any hour in which a refresh is pending** — through the wrapper `0x689310` |
| `0x41D8EA` `ApplyCustomGameSettings`, `0x66042A`, `0x683EC9` `RefreshAllCountries`, `0x69DDB3` `CNudgeIdler` slot 3 | one-offs, not recurring |

The hourly wrapper (`0x689310`, propose **`RunIntelRefreshIfRequested`**) is ten instructions: `eax = state + 0xCF8`, and it calls `RunIntelRefresh` only when `[eax+8] >= 1` and the head node's value is `-1`. That list is a `CList` of 0x10-byte nodes in the `{first, last, count}` shape (`+0xCF8` / `+0xCFC` / `+0xD00`), and the one writer found is **`CSetCountryControllerCommand` slot 6** (`0x6D3390`, the function with the `'controlcommands.cpp'`, `'AI will control '` strings), which allocates a node holding `-1` at `0x6D3887`. Neither the wrapper nor `RunIntelRefresh` drains the list, so once a controller change queues a `-1` the hourly path keeps firing. What a value other than `-1` would mean is **not established**.

**For hooking:** the launch point is always the tick thread; the per-element work (`0x688170` for clear, `0x6883B0` for update) is always on **TBB workers**. Anything BiceLib wants to do with intel either reads it from the tick thread between passes, or must be thread-safe.

---

## 4. The thread map

`RunHourlyPass` calls, in order: `0x682833` `RunCountryHourlyPass` (serial per country) → `0x682887` unit fan-out → `0x6828D4` country fan-out → `0x6829DC` AI-trade fan-out and `0x6829E4` sets `ai_pass_done` → `0x682A3B` province fan-out → `0x682A90` `CCombatManager::Tick` → `0x682B14` the `+0xD9D` gate and `0x682B1D` the `ai_pass_done` clear.

`RunDailyPass` calls, in order: `0x682D6B` `0x4F28B0` per country (serial) → `0x682DDD` `ProcessCountriesPreDailyUpdate` fan-out → `0x682E03`–`0x682E2A` per country `0x4E39C0` then `RunCountryDailyPass` (serial) → `0x682E41`–`0x682E5D` per province `RunDailyProvincePass` (serial) → `0x682F7B` the `+0xD9D` gate → `0x683050` `RunDailyEventPass` → `0x683056` `RunIntelRefresh`.

| function | rva | its caller | caller in a TBB functor? | thread | hookable by BiceLib? |
| --- | --- | --- | --- | --- | --- |
| `CUnit::UpdateHourly` | `0x1B9C50` | `0x68ECC9`, serial body of `ProcessUnitFunctor start_for::execute` (`0x68EBF0`) | **yes** | **TBB worker**, hourly | **no Lua, no message, no ImGui, no D3D** |
| `CUnit::CheckOrderAndCombat` — slot 31 | `0x1BA2F0` | `0x4D8F7D` in `RunCountryHourlyPass`, itself called only from `RunHourlyPass` `0x682833` | no | **tick thread**, hourly, per unit | **yes** |
| `CNavy::CheckOrderAndCombat` — slot 31 override | `0x1CFDD0` | same dispatch; tail-jumps into the base | no | tick thread, hourly | yes |
| `CUnit::UpdateDaily` — slot 32 | `0x1BAF70` | `0x4DB291` in `RunCountryDailyPass`, itself called only from `RunDailyPass` `0x682E1A` | no | **tick thread**, daily, per unit | **yes** |
| `CAir::UpdateDaily` — slot 32 override | `0x1D0B60` | same dispatch; `0x5D0E01` calls the base | no | tick thread, daily | yes |
| `CCountry` per-hour (`RunCountryHourlyPass`) | `0xD8EB0` | `RunHourlyPass` `0x682833` | no | tick thread, hourly, per country | yes |
| `RunCountryDailyPass` (previously guessed at as `CCountry::UpdateDaily`) | `0xDA530` | `RunDailyPass` `0x682E1A`, in a loop over `state+0xBBC` gated on `CCountry +0x44`; `__stdcall`, country on the stack | no | tick thread, daily, per country | yes |
| `CCountry::UpdateIC` | `0xF0CC0` | `0x4DB442` inside `RunCountryDailyPass` (reachable from `0x4DA530` per `cfg.py`); also `0x4D633D` and `CInGameIdler` slot 3 `0x65B2C5`, both one-offs | no | tick thread, daily, per country | yes |
| `CCountry::UpdateMonthly` | `0xDC840` | `RunMonthlyPass` `0x683BE9` | no | tick thread, monthly | yes |
| `CCountry::RecountUnitTotals` (proposed) | `0x1004F0` | `0x68EDC1`, serial body of `ProcessCountryFunctor start_for::execute` (`0x68ECE0`); five other callers, none in a functor | **yes** | **TBB worker**, hourly | **no** — and note it *writes* `CCountry +0xC8/+0xCC/+0xD0/+0x108C` from that thread |
| `RunDailyProvincePass` | `0x9EAB0` | `RunDailyPass` `0x682E4B`, in a serial loop over `state+0xB8C` | no | tick thread, daily, per province | yes |
| `RebuildProvinceModifierValues` | `0x9F3E0` | 15 callers; the recurring one is `RunMonthlyPass` `0x683B9A`. **None of the fifteen is inside any of the eight `execute` bodies or any functor serial body** | no | tick thread | yes |
| `CCombatManager::Tick` | `0x2FB70` | `0x682A90` in `RunHourlyPass` | no | tick thread, hourly | yes (as `FINDINGS-airnaval.md` says) |
| `ProcessProvinceFunctor` body | `0x27B1C0` | `0x68EEB0` | **yes** | TBB worker, hourly | no |
| `ProcessAITradeFunctor` body | `0x27B160` | `0x68EDE0` | **yes** | TBB worker, hourly | no |
| `ProcessAI` and every minister tick | `0x4894E0` | `0x68F15A` | **yes** | TBB worker, hourly | no |
| `ClearIntelFunctor` / `UpdateIntelFunctor` bodies | `0x288170` / `0x2883B0` | `0x68F170` / `0x68F250` | **yes** | TBB worker; **daily always, hourly on request** | no |

`0x682E1A` and `0x682E4B` both sit inside `RunDailyPass` even though `image.functionStart` answers `RunHourlyPass` — `retsBefore(0x682C20, …)` is empty for both. That is the `0x682630`/`0x682C20` abutting pair, and it is why the daily entries above are attributed by extent and not by `functionStart`.

**One honest caveat on slot 32.** The `+0x7C` enumeration is closed (the four vftable slots are the only references to the function in the entire image). For `+0x80` I did the same aligned sweep and region filter and found only `0x4DB291` with a `CUnit` receiver — the other near misses (`0x5BF160`, `0x5BF17A`, `0x5C0B7C`) dispatch slot 32 of the sub-objects at `CUnit +0x164` and `+0x168`, not of a unit. But `+0x80` is a far commoner displacement, so treat "one call site" for slot 32 as a strong result rather than a closed one.

---

## 5. Deferred unit deletion — and no, a worker never frees a unit

**`0x28DB20` is mis-described in `FINDINGS-tick.md`.** The function is `tbb::strict_ppl::concurrent_queue::internal_try_pop`: a `lock cmpxchg` loop on a head counter, then `0x68EA80` on the micro-queue at `rep + 0x180 + ((ticket*3) & 7) * 0x50`, returning false when head reaches tail. `ret 8`. Its two callers are the tick's drain loop and the queue's own clear helper (`0x68EBA0`, which abuts `ProcessUnitFunctor::execute` — another abutting pair).

The *stage* is the loop `0x682230`–`0x6822B7` at the very end of `RunHourlyTick`:

    while (queue at state+0xBF4 is non-empty) {
        pop {id_type, id}                        0x682268  try_pop
        db = (id_type <= 0x1268) ? [0x1A857F4] : [0x1A857F0]
        ref = 0xA9DA00(db, &pair)                0x68229C
        unit = ref - 8                           0x6822A5   CReferenceObject sub-object is at CUnit+8
        CGameState::RemoveUnit(state)(unit, 0, 1) 0x6822B2
    }

and the queue is filled by **`0x684C80`**, thirty instructions, object in EAX, state on the stack, `lock xadd` on the tail counter and a push into the selected micro-queue. Propose **`CGameState::QueueUnitRemoval`**. Eight callers, and the two that answer the question are `0x5B9F0C` and `0x5B9FE7`, **both inside `CUnit::UpdateHourly`** — so:

**A TBB worker never frees a unit. It pushes the unit's id pair onto a lock-free queue, and the tick thread drains that queue at the end of `RunHourlyTick` and does the removal.**

The rest of the removal picture:

- `CUnit::CheckOrderAndCombat` also enqueues (`0x5BA4C8`, `0x5BA714`) — tick thread, still deferred.
- `CUnit::UpdateDaily` enqueues indirectly through `CheckTransportOverload` (`0x5BB413` → `0x5CFBD0`), which `project.json` already documents correctly, calling `+0xBF8` "the game state's message ring". It is a work queue, not a message ring; the entry is otherwise right and I have not touched it.
- `CAir::UpdateDaily` enqueues at `0x5D0D8F`; `CNavy` slot 18 (`0x5D01B0`) at `0x5D0443`; `CRemoveBrigadeEffect` slot 11 (`0x9BBF10`) pushes inline at `0x9BC11D`; one AI-region site at `0x8ABBE8` I did not trace to a thread.
- **The exception that matters:** `RunCountryHourlyPass` calls `CGameState::RemoveUnit` **directly and synchronously** at `0x4D8FB5` and `0x4D8FFD`, inside the same loop that dispatches slot 31. So a `CUnit*` a hook captured during that loop can be freed before the loop finishes. **A hook on slot 31, or on anything under it, must not cache a `CUnit*` across the hourly country pass.** Within one slot-31 call it is safe; the removal happens after the dispatch returns.

Practical rule for BiceLib: a `CUnit*` obtained on the tick thread is good until the end of `RunHourlyTick` (the drain), except inside `RunCountryHourlyPass`, where it is good only until the slot-31 dispatch returns.

---

## What is not established

- What `CCurrentGameState +0xCF8`'s non-`-1` values mean, and what drains that list (nothing found does).
- `0x508C30`, `0x4E0B80`, `0x8A9B10` and `0x8AC400`, the tail of `RunCountryHourlyPass`, and what `CCountry +0x48C` and `+0x11CC` are.
- `CCountry +0x44`, the byte four separate country loops now use to skip an entry (`0x68282C`, `0x682D65`, `0x682E08`, `0x68F059`, `0x683EA9`). Still not claimed, for the reason `FINDINGS-aisched.md` gives.
- `0x1B15670`, the global `RunDailyPass` and `RunMonthlyPass` build lazily and the tutorial branch skips, and `0x9BF720` which is called on it.
- `CUnit +0x290`, which `CCountry::RecountUnitTotals` uses to skip a unit, and what `CCountry +0xC8/+0xCC/+0xD0/+0x108C` count.
- `0x66042A`'s containing function (`functionStart` cannot find a boundary; the last `int3` before it is *after* it, at `0x6604BF`).
- Whether the eight-micro-queue layout means the removal queue is genuinely contended, i.e. whether `0x170ABB0` being `1` makes the fan-outs effectively serial — `FINDINGS-aisched.md`'s open question, untouched here.

## Everything I propose, in one list

`addresses`: `0xD8EB0 RunCountryHourlyPass`, `0x1CFDD0 CNavy::CheckOrderAndCombat`, `0x284C80 CGameState::QueueUnitRemoval`, `0x28DB20 ConcurrentQueue_TryPop`, `0x28DA00 ConcurrentQueue_MicroQueuePush`, `0x288D40 RunIntelRefresh`, `0x289310 RunIntelRefreshIfRequested`, `0x31D4B0 CTutorialScreen::OnTutorialButtonPressed`, `0x31D2D0 CTutorialScreen::OnBackButtonPressed` (likely), `0x1004F0 CCountry::RecountUnitTotals` (likely).

`fields`: `CCurrentGameState +0xBF4 pending_unit_removals`, `+0xBF8 pending_unit_removals_rep`, `+0xCF8/+0xCFC/+0xD00 intel_refresh_requests_{first,last,count}`.

Corrections for you to apply, not redefined by me: `CCurrentGameState +0xD9D` should be `tutorial_active`, not `autosave_blocked`; `FINDINGS-tick.md`'s ninth tick stage should say the stage is a drain loop and `0x28DB20` is only the queue pop; `FINDINGS-airnaval.md`'s open question "the cadence and thread of `CUnit` slot 31" is now closed (tick thread, hourly, per unit).
