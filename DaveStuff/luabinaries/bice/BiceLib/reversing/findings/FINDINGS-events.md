# Events

Why a loaded savegame fires no events until the month turns. Everything here was read out of
the executable on 2026-09-30; addresses are virtual, based at `0x400000`, with the rva beside
them. The game was not running for any of it.

**In one line.** The daily event pass does not look at the event database. It walks a
**per-country candidate list** at `CCountry+0x8`, and that list is built in exactly one
function, `0x9C0050`, which the tick calls **only on a month change**. The list is not in the
save and `CCountry::AfterLoad` does not build it, so after a load every country list is
empty and the daily pass has nothing to iterate. **The hypothesis in FINDINGS-tick.md is
correct: `RunMonthlyPass` builds what the daily call walks.**

## The three layers

    g_event_list  (0x1B15670)            every CEvent the scenario loaded
        |                                 rebuilt monthly, and on one game-entry path, by
        v   0x9C0050                      filtering it per country
    CCountry +0x8 / +0xC / +0x10          that country candidate events
        |
        v   0x9C0A40                      once a day: re-check trigger, roll MTTH, fire
    0x9C0C80                              fire

Only the middle arrow is monthly. The bottom one is daily. That is the whole bug.

## `RunMonthlyPass` (rva `0x283B50`) read in full

`0x683B50` to `0x683D0F`, `ret 4`, clean `int3` padding after it. Its one caller is
`RunHourlyTick` at `0x6821C1`, on a month change. Taking the game state on the stack:

    0x683B70   0x683A50(state)
    0x683B90   for i = 1 .. (state+0xB90 - state+0xB8C)/4 - 1     note: starts at 1, not 0
                   e = [state+0xB8C][i]
                   0x49F3E0(e)
                   if (e->+0x24 != 0) { e->+0x24 -= 0x53; if (e->+0x24 < 0) e->+0x24 = 0; }
    0x683BE0   for i = 1 .. (state+0xBC0 - state+0xBBC)/4 - 1
                   0x4DC840(([state+0xBBC])[i])                   thiscall
    0x683BF3   state = the CCurrentGameState singleton at 0x1A89790, constructed if null
    0x683C69   if (state->+0xD9D == 0) {
    0x683C72       if (g_event_list == 0) g_event_list = new zeroed 0x20 bytes
    0x683CE1       0x9C0050(g_event_list)          <-- the event bookkeeping
               }
    0x683CE6   for (n = state->+0xC7C; n; n = n->+8)  0x4BA4D0(n->[0])

So the answer to job 1 is **yes, and it is one call**: `0x9C0050`. The `-0x53` (83) decay on
`+0x24` of whatever `state+0xB8C` holds is a second piece of monthly bookkeeping, unidentified.
`state+0xD9D` is a byte the constructor zeroes (it is the upper byte of the word written at
`+0xD9C`), and it gates the event step in the daily pass as well - see below.

## `0x9C0050` - the per-country candidate rebuild

`0x9C0050` (rva `0x5C0050`) to `0x9C0421`, `ret 4`, one stack argument: the event list.
It abuts `0x9BF7B0`, which ends at `0x9C003E` with `ret 8` - another pair to be careful with.

**Pass 1, `0x9C010F` to `0x9C0185`: every country list is thrown away.** For each entry of
the country database at `[0x1A855A4]` (`+0x168` count, `+0x16C` array), the entry own
`CCountryTag` pair at `+0xCA4`/`+0xCA8` is copied to the stack and resolved with
`CCountryTag::GetCountry` (rva `0x2610`, an exact name in `project.json`). The resulting
`CCountry` has a `CList` at `+0x8`/`+0xC`/`+0x10`; every node is freed, walking `node+8`,
and the three words are zeroed. **Pass 1 has no `+0xCF8` gate - every country is cleared.**

**Pass 2, `0x9C02E1` to `0x9C040B`: the list is refilled from the event list.** The argument
`+0x00` is a `CList` head; each node is `{data, prev, next, byte}` at `+0`/`+4`/`+8`/`+0xC`, and
`node[0]` is a `CEvent`. An event is skipped when any of these holds:

| at | test | what it is, from `fieldmap.py CEvent` |
| --- | --- | --- |
| `0x9C02FF` | `(event+0xD8) - (event+0xD4) < 4` | **`option`** is empty - an event with no options is never a candidate |
| `0x9C0313` | `byte event+0x170 != 0` | **`is_triggered_only`** |
| `0x9C031F` | `byte event+0x172 != 0` **and** the `+0xC38` lookup already holds it | **`fire_only_once`** already fired |

The `fire_only_once` check is `0x68DC10(&state->+0xC38 @ECX, &event->id @EDI)` with the event
id pair taken from `event+0x8`/`+0xC`; a result equal to the event itself means "skip", a null
result means "proceed". So `CCurrentGameState+0xC38` is the already-fired registry.

For each surviving event, an inner loop over the same country array runs, and **this** one skips
any country whose `CCountry+0xCF8` is `<= 0` (`0x9C0385`; job 2 verification - the gate is
confirmed, that `+0xCF8` is the owned-province count I take from the existing record and did not
re-derive). A `CEventScope` is built on the stack for that country and the event **`trigger`**
(`event+0x30`, `fieldmap`-confirmed) has slot 6 called on it with the scope. On `true`, a 0x10-byte
node is allocated and appended to that country `+0x8`/`+0xC` list and `+0x10` incremented.

That is the only place in the image that writes those three words - `0x9C0050` has exactly two
callers, both found with `findRefs.py --callers`.

## `0x9C0A40` - the daily pass, and why an empty list means silence

`0x9C0A40` (rva `0x5C0A40`) to `0x9C0C76`, **bare `ret` and no arguments at all**, nothing in
`ecx`. Its one caller is `RunDailyPass` at `0x683050`. `image.functionStart` walks back to
`0x9C08F1` on it; that is the abutting-function trap the tick findings already flag.

    for each country in [0x1A855A4]+0x16C:
        if (country->+0xCF8 <= 0)      continue      0x9C0B3E
        esi = country->+0x8                          0x9C0B52
        if (esi == 0)                  continue      0x9C0B57   <-- the whole bug
        for (; esi; esi = esi->+8):
            event = esi[0]
            if (!event->trigger->slot6(&scope))  continue       0x9C0B72
            chance = CMeanTimeToHappen::GetChance(event+0xE4 @EAX, &scope @EDI)   0x9C0B85
            r = (temper(mt) & 0x7FFFFFFF) * 2^-31                0x9C0BD9
            if (chance > r)  0x9C0C80(event, &scope)             0x9C0C49

`event+0xE4` is **`mean_time_to_happen`** by `fieldmap`, which independently confirms the
`GetChance` call is on the right sub-object. `0x9C0BD9` is the MT19937 tempering the tick
findings already recorded, and `0x160A2B8` is exactly `2^-31`, so `r` is uniform on `[0,1)`.

**There is no accumulator and no per-event "last evaluated" field.** `GetChance` is memoryless -
it reads only `days` and the modifier list. So the second hypothesis in FINDINGS-tick.md, that
loading resets an accumulated-days figure, is **wrong**: no such figure exists.

`0x9C0430` scenario-versus-global branch is also **not** the daily gate. Its two callers are in
`CEU3Application::LoadEverything` (`0x63253D`) and `CInGameIdler::Enter` (`0x65AC0A`), not on the
tick at all; `CCurrentGameState+0xD0C` is the scenario pointer and `scenario+0xB0` the events it
carries. That hypothesis is ruled out too.

## What `RunDailyPass` does around the call

`0x682F7B` to `0x683050` is the standard MSVC lazy-singleton shape and it is easy to misread as a
daily rebuild. It is not:

    if (state->+0xD9D != 0)   skip the event step entirely     0x682F82
    if (g_event_list != 0)    goto 0x683050                    0x682F8F
    ... allocate a zeroed 0x20-byte list and install it, destroying the old (dead here) ...
    0x683050: 0x9C0A40()

The destroy-and-replace block can only run when `g_event_list` was null, so **the event list is
never rebuilt daily**. `RunMonthlyPass` has the same shape at `0x683C69`/`0x683C72`.

## The load path

Three findings, each independent:

- **The candidate list is not in the save.** `fieldmap.py CCountry` over `CCountry::LoadKey`
  (`0x4CCDA0`) lists 57 keys and **not one lands at `+0x8`, `+0xC` or `+0x10`**. It could not be,
  either - the nodes hold raw `CEvent*`.
- **`CCountry::AfterLoad` does not build it.** `0x4D2500` to the `ret` at `0x4D273D`; the only
  instruction in the whole body touching those offsets is a read, `mov ebx,[ebx+8]` at
  `0x4D270A`, walking the unrelated `+0xF40` list. Nothing writes `+0x8`/`+0xC`/`+0x10`.
- **The one non-monthly builder is a game-entry path, not a load path.** `0x9C0050` other
  caller is `0x682510` (rva `0x282510`), at `0x68255B`. `0x682510` takes the game state **in
  `eax`**, lazily creates the event list through `0x9C1460`, calls `0x9C0050` on it, and then
  does five other things (`0x68BB90(state)`, `0x68C190()`, `0x4B59C0(state+0xAEC @EAX)`, a
  per-entry `0x5082C0` loop over `state+0xBBC`, and a seven-dword `+0x164..+0x17C` ->
  `+0x188..+0x1A0` snapshot over `state+0x54`). Its own two callers are **`CInGameIdler` vftable
  slot 67** (`0x64C170`, vftable `0x15CEB54`) and **`CReopenLobby::Execute`** (`0x6D8430`,
  `CCommand` slot 6). Neither is a load. `CEU3Idler`, `CBackEndIdler` and `CNudgeIdler` all leave
  slot 67 as the do-nothing `0xABF890`, so `CInGameIdler` is the only implementor.

Inside `0x64C170` the call is gated: `obj = this->slot18()` (`0x64D800`, which returns
`[[this+0x1790]+0x12C]`) and `if (obj->+0x236 == 0)` the event build is skipped outright
(`0x64C20C`-`0x64C214`). What that object and that byte are is **unknown**.

**So, in the terms job 3 asked for: the field the daily pass needs - `CCountry+0x8` - is written
only by `0x9C0050`, which the tick reaches only on a month change, and nothing on the load path
writes it.** That is the bug. That the load genuinely misses `0x682510` is the one inferred link:
it follows from the reported symptom plus the two negatives above, not from having traced the
loader.

**One sharp correction to the folklore.** `RunHourlyTick` runs the daily pass at `0x68213A` and
the monthly pass at `0x6821C1` - **daily first**. So on the 1st, `0x9C0A40` still runs against
empty lists and only afterwards does `0x9C0050` refill them. The earliest day an MTTH event can
fire is therefore the **2nd**, not the 1st.

The barrage is consistent with this but only partly explained by it: on that one day every
candidate gets its first roll of the month at once, and any event whose `mean_time_to_happen`
`days` is `<= 0` returns a chance of exactly 1.0 and fires with certainty. How much of a real
barrage that accounts for is inference, not measurement.

## What would confirm it in one sitting

In order of how decisive they are, and 1 needs no event to fire at all.

1. **Read `CCountry+0x10` for the player country from BiceLib.** It is a single dword, the
   candidate count. Right after a load it should be **0**; after the month change it should be in
   the hundreds. Nothing else in any hypothesis predicts that. The country is
   `CCountryTag::GetCountry` (`0x402610`, thiscall on an 8-byte tag pair) or any country pointer
   already in hand.
2. **Make the delay track the calendar, not the elapsed time.** Save on the 28th, load, and
   events should resume within a few days. Save on the 2nd, load, and they should stay dead for
   about 29 days. A per-event timer reset would give the same wait in both cases; this mechanism
   gives a wait equal to the distance to the month boundary, plus one day.
3. **Watch for the resumption day.** If the barrage lands on the **2nd** the reading above is
   exact. If it lands on the **1st**, something else also rebuilds the lists and the ordering
   above is incomplete - worth knowing either way.
4. **Triggered-only events should be unaffected.** `is_triggered_only = yes` events are never in
   the candidate list, and `0x9C0C80` has ten callers besides the daily pass. So an event fired by
   another event `option`/`immediate` should work normally right after a load. If those are also
   dead, the cause is elsewhere.
5. **The surgical fix to test.** After a load, call `0x9C0050` once with `[0x1B15670]`. It is
   `__stdcall`, one argument, and `0x682510` calls it with nothing but the event list, so it is
   self-contained. It runs on the tick thread, so a Present-hook call is on the right thread -
   but it walks every country and every event, so it is not something to run per frame. If events
   resume the next day, the mechanism is proven and the fix is a one-call hook on whatever the
   load path tail turns out to be.

## `CMeanTimeToHappen::GetChance` (rva `0x5C4AB0`), and the formula

`0x9C4AB0` to `0x9C4B85`. **`this` in `EAX`, the `CEventScope*` in `EDI`**, result in `st0`,
bare `ret` - not a convention to guess at, and not `thiscall`.

    days = (float)this->days                          +0x08 int
    for (m = this->modifiers.first; m; m = m->next)    +0x0C head; node {data, ?, next at +8}
        if (m->condition->slot6(scope))                [[m]+0x18] called with edi = scope
            days *= (float)m->factor / 1000.0          m+0x40 int; 0x160A300 == 1000.0
    if (!(0.0 < days))  return 1.0f                    0x9C4B1B, comiss - days <= 0 is certainty
    return 1.0f - 0.5f ** (1.0f / days)                0x160A308 == 0.5

Both constants were read out of the image: `0x160A300` is the double `1000.0` and `0x160A308` the
double `0.5`. So **`factor` is in thousandths** - `factor = 0.5` in script is 500 in memory, the
house rule again - and **`days` is a median, not a mean**: `p = 1 - 0.5^(1/days)` is exactly the
per-day probability that gives a 50% chance of having fired after `days` days. For `days = 30`
that is 2.28% a day; for `days = 1`, 50%.

The emitted code computes it as `c = exp(log(0.5)/days)` and then, redundantly, `exp(log(c))`
before `1 - c`, with a `float` store and reload between every step - so the answer is quantised to
single precision at four separate points. That `0xC0B9B0` is natural log and `0xC0BAFC` is exp is
**inference** from the shape of the result; neither is named in `project.json` and neither body was
read.

## `CEventScope`, and the one field the two builders disagree about

Vftable `0x15B8AEC`, base `CPersistent`, 6 slots, from the RTTI export. Both `0x9C0050` and
`0x9C0A40` build one on the stack, 0x48 bytes, field for field identically once the different
frame bases (`ebp-0x84` and `ebp-0x70`) are lined up:

    +0x00  vftable 0x15B8AEC
    +0x04  0x18D               a constant, the same at both sites
    +0x08  a draw from 0xAA2F80, taken once at the top of each function
    +0x0C  the same draw
    +0x10  CCountryTag: 0x2D2D2D ("---") at construction, then the country being scoped
    +0x18  CCountryTag: left as 0x2D2D2D ("---")
    +0x20 .. +0x28   zero
    +0x2C  the same draw again
    +0x30  zero
    +0x34  ** the days in the current month in 0x9C0050; zero in 0x9C0A40 **
    +0x38  a pointer to the scope itself
    +0x3C  word 1
    +0x40, +0x44  zero

`0x2D2D2D` is "---" as three bytes, the HoI3 null country tag, which is why reading `+0x10` and
`+0x18` as two `CCountryTag`s - THIS and an unset FROM - is the natural reading. That is
inference from the constant and from the fact that only `+0x10` is ever filled in.

`+0x34` is the only real difference. `0x9C0050` derives it at `0x9C0273`-`0x9C02E4` by
recomputing the day of the year from `state+0xBDC` exactly as `RunHourlyTick` does (the same
`0x29C55C0` epoch, the same `365.0` at `0x160A550`) and then walking `MonthLengthTable`
(`0x1713294`) to land on the current month length. `0x9C0A40` leaves it zero. `GetChance` never
reads the scope - it only forwards it - so this matters only to whatever a `trigger` does with it.

## The event list object

A 0x20-byte heap object at `g_event_list` = `0x1B15670`, no vftable, plain zero-init. Two
`CList`s, one at `+0x00` and one at `+0x10`, each `{first, last, count, byte}`. Only `+0x00` is
walked by `0x9C0050`; what `+0x10` holds is unknown. Nineteen code references. The accessors:

| VA | rva | `ret` | what |
| --- | --- | --- | --- |
| `0x9BF640` | `0x5BF640` | bare | getter; creates it if null and returns it |
| `0x9C1460` | `0x5C1460` | `ret 4` | setter; destroys and frees the old one, returns `&g_event_list` in `eax` |
| `0x9BF690` | `0x5BF690` | `ret 4` | its destructor, stack argument; the two `CList`s are torn down inline by the caller afterwards, which is why the daily pass looks longer than it is |
| `0x9BF720` | `0x5BF720` | bare, arg in `EDI` | unread; called on it both from the head of `0x9C0430` and from the daily pass teardown |
| `0x9BF7B0` | `0x5BF7B0` | `ret 8` | unread; `(list, scenario+0xB0)`, the scenario-events branch |
| `0x9C0430` | `0x5C0430` | thiscall | `0x9BF720(this)`, then `0x9BF7B0(this, scenario+0xB0)` if `state+0xD0C != 0`, else a global branch that was not read |

## What BiceLib does with it

`GameState/EventCandidates.cpp` and `BiceLib.Events.rebuildCandidates()`, 2026-09-30.
**Nothing is patched.** The engine's `RebuildCountryEventCandidates` is left exactly as
written and simply called earlier, with the same argument the monthly pass passes - the
contents of `g_event_list` (rva `0x1715670`).

**Driven from the mod's Lua**, not from the DLL's own frame loop: the call sits in
`IntelligenceMinisterUtilityThings` in `script/ai_omg_handlers.lua`, in the block guarded by
`SaveLoaded ~= true`, which the OMG country's intelligence minister tick reaches once after
each load. That keeps it switchable with the rest of the mod's scripted behaviour. Two
consequences worth knowing: it happens at that minister's hour rather than within a second of
the load, so the first events arrive a day or two in rather than immediately; and it is behind
`G_UtilityEnabled`, so a game with the utility off does not get the fix.

**It covers every country.** Pass 1 walks the whole country database and frees every
country's list with no filter of any kind - there is exactly one reference to `+0xCF8` in the
function and it is not in pass 1. Pass 2 refills each country that owns at least one province,
skipping the rest on `cmp ... +0xCF8; jle` at `0x9C0385`. A province-less country is therefore
left with an empty list, which changes nothing: the daily pass applies the same filter, so it
would never have looked at that country anyway. The count the log reports is the player's only
because that is the cheapest one to look up.

Why the call is safe:

- **It is idempotent.** Pass 1 throws every list away before pass 2 refills, so calling it
  when the lists are already good costs one wasted pass. A new game, where something on the
  entry path already builds them, is unharmed.
- **It runs on the right thread.** The Lua state, the tick and the overlay's Present all
  belong to one thread, so nothing can be mid-rebuild.
- **It waits for the same gate the engine waits for.** `CCurrentGameState +0xD9D`, which the
  autosave work named `autosave_blocked`, has to be zero - the monthly pass gates its own call
  on that byte too. Which is a small finding of its own: a byte previously known only as
  "must be zero before the game will write a save" also blocks this bookkeeping, so it reads
  more like *a save or a load is in progress* than anything to do with saving specifically.
- **It checks the function before calling it**, and refuses rather than calling something it
  does not recognise.

**A byte signature must not contain an absolute address.** The first working version checked
ten head bytes, the last four of which were the operand of the function's `push <SEH handler>`.
It failed every time, reporting that the rebuild was "not what this build expects". The image is
built `DYNAMIC_BASE` and carries a type-3 relocation sitting exactly on that operand (rva
`0x5C0056`), so the loader rewrites it whenever the module lands anywhere but `0x400000` -
which it usually does; a crash dump from this month had the game at `0x380000`. **The bytes on
disk are not the bytes in memory.** The check now compares the six opcode bytes literally and
the handler against `base + rva`, which is what `CrashSave.cpp` already did for the save writer.
None of the mod's other patches is exposed to this: every one of them edits opcodes, modrm
bytes or small immediates, and not one writes or compares an address.

`EventCandidates::status()` records what the last call did, including the player's candidate
count either side of it - `countBefore` being 0 after a load is the measurement that confirms
the diagnosis rather than only the fix.

## What is not established

- **That loading a savegame really does skip `0x682510`.** Everything else here is read; this one
  link is inferred from the symptom plus the two negatives (not in the `CCountry` save grammar, not
  written by `CCountry::AfterLoad`). `CInGameIdler` slot 67 has no locatable call site -
  `slotcalls.py 67` reports 219 sites in 58 functions and none of them touch `+0x1790`, so the
  dispatch is through a base-typed pointer somewhere this did not find. Test 1 above settles it in
  one value and should be run before the mechanism is treated as fact.
- **`[[CInGameIdler+0x1790]+0x12C]` and its byte at `+0x236`**, which gates the whole event build
  inside `0x64C170`. Unknown. If it is something like "single player" or "not a hotjoin", it could
  be a second, separate reason the build is skipped.
- **`CCurrentGameState+0xD9D`.** It gates the event step in both the daily and the monthly pass.
  The constructor zeroes it (it is the upper byte of the word at `+0xD9C`). Nothing was found that
  sets it. If something does set it after a load, that is a simpler bug than this one, and it
  would stop events permanently rather than until the month turns.
- **`0x9C0C80` was not read.** Named `FireEvent` here from its two arguments and its ten call
  sites - `0x9C0C80` to the `ret 8` at `0x9C1450` - but the body, and therefore where the option
  list and the message go, is unopened. It is the obvious next thing.
- **What `g_event_list+0x10`, the second `CList`, holds.**
- **`0x683A50`, `0x49F3E0`, `0x4DC840`, `0x4BA4D0`** - the rest of `RunMonthlyPass` - and the
  `-83` monthly decay of `+0x24` on whatever `state+0xB8C` holds.
- **Whether `0x1A855A4` is the country database class.** Its `+0x168`/`+0x16C` count/array and the
  `0x57C`-byte lazy construction through `0x4024D0` are read; the class is not identified here.
- **`0xC0B9B0` and `0xC0BAFC`** as `log` and `exp`. Inferred from the formula shape only.
- **The five other calls in `0x682510`** (`0x68BB90`, `0x68C190`, `0x4B59C0`, `0x5082C0`, and the
  `+0x164..+0x17C` -> `+0x188..+0x1A0` snapshot), and therefore what the function is really for.
  The name proposed for it covers only the part that was read.
- **Do not name `0xABF890`.** It is the universal empty virtual: **1691 vftable slots across 916
  classes**. `CEU3Idler` slot 67, `CEventScope` slot 5 and the `AfterLoad` the task mentions are
  all the same folded stub, and it means nothing about any of them.
