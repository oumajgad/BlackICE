# Who sets `plan_air_stance`, and who fills the four `air_target_provinces_*` lists

Read statically off `hoi3_tfh.exe` on 2026-10-02 with the game not running. Addresses here are
**rvas** against an image base of `0x400000`, which is what `ghidra/project.json` and the
`GameClasses` headers use; where a disassembly line is quoted the virtual address is the rva plus
`0x400000`. This file closes open items 1 and 3 of `findings/FINDINGS-airnaval4.md` and corrects the
conclusion of the first.

**In one line.** The AI sets `plan_air_stance` to **2** itself, on every one of its unit agents,
once per `ProcessAI` pass — so the five strategic and naval air missions are **live**, not dead, and
`FINDINGS-airnaval4.md`'s headline is wrong. And the writer of the four `air_target_provinces_*`
lists is `0x4B4740`, which reaches them through a plain `lea reg, [agent + 0x1FC]` — the one shape
that file said no displacement scan could follow.

## 1. The AI's own writer of air stance 2

`CEU3AI::UpdateUnitStances` (`0x4912D0`) runs two loops over `ai->unit_agents (+0x40)`. The second
(head reloaded at `0x491621`, body `0x491630`, back edge from `0x491B99`) is, in full:

```
0x491630  unit = agent->slot74()                     ; ReturnDwordAt0x64 = agent->unit (+0x64)
0x491655  if (!unit) continue
0x491660  if (unit->plan_air_stance   (+0x20C) == 2 &&
0x49166E     unit->plan_naval_stance (+0x210) == 2) continue
0x4916AD  cmd = new CSetPlanAttributesCommand(unit, 5, 2, 2, &-1000, &-1000)
0x491751  post cmd
```

`cfg.py` gives `0x491630` two incoming edges — the fall-through from `0x49162A` and the loop's own
back edge — and no others, so the block is the loop body and is conditional on nothing but
`unit != 0`. **The `== 2 && == 2` test is an idempotence check, not a gate**: it exists only to
avoid re-posting a command that would change nothing, which is why the steady state of every agent
unit is stance 2.

The constructor (`0x1E7710`, `ret 0x1C`) stores its arguments at `+0x68` stance, `+0x6C` air_stance,
`+0x70` naval_stance, `+0x74`/`+0x78` the two power estimates, and hardcodes `+0x64 active = 1` at
`0x1E77AD`. 5 and the two −1000s are the command's "leave alone" sentinels; the two 2s are real
writes, landing in `CSetPlanAttributesCommand::Execute` at `0x1E7907` and `0x1E7950`. Because
`active` is always 1, Execute's `CUnitPlan::SetActive` call at `0x1E7822` can never take the reset
arm.

One caller: `ProcessAI` at `0x489B8F`. `image.retsBefore(0x4894E0, 0x489B8F)` returns the two
`ret 4`s at `0x489618` and `0x48986A` — the trap-3 early exits `TRAPS.md` already documents for that
function — and `cfg.py` walking from `0x4894E0` reaches `0x489B67`, so the call site is in
`ProcessAI`'s own frame and on its main path. It is AI worker-thread code and needs nothing from the
player.

### Why the record said the opposite

`findings/FINDINGS-airnaval4.md` reasoned from the live distribution of `CUnit +0x20C` — 1 on 1,125
of 1,126 air formations — to "the five strategic and naval air missions are not reached in a normal
game". **But the gate does not read an air formation's stance.** `0x4CF902` is

```
mov edx, [ebp + 8]          ; the agent
mov eax, [edx + 0x64]       ; agent->unit - the army or theatre HQ
cmp dword ptr [eax + 0x20C], 2
```

and `CAIUnit +0x64 unit` is already recorded, with slot 74 (`ReturnDwordAt0x64`, `0x4AF4D0`) as its
getter. The object the gate reads is the agent's unit, and `UpdateUnitStances` writes 2 onto exactly
that object, for exactly those agents. The same live note records **2 on all 101 of the armies
attached to a `CAIUnit` agent**, and sets them aside as "a biased subsample of one army per
theatre". Those 101 *are* the population the instruction reads. The caution was pointing at the
answer.

It also explains that note's unexplained finding — `+0x20C` and `+0x210` identical on all 4,864
objects read: one command sets both to 2, and `CUnitPlan`'s constructor and reset set both to 1.

### Every writer of `CUnit +0x20C`

| writer | value | reachable from |
| --- | --- | --- |
| `CSetPlanAttributesCommand::Execute`, store at `0x1E7907` | the command's `+0x6C`, skipped when it is 3 | **the only store by this displacement**; everything below goes through it |
| `CUnitPlan::CUnitPlan`, `0x4DE9EF` | **1** | construction, so 1 is every unit's starting value |
| `CUnitPlan::SetActive(plan, 0)`, `0x4DEB78` | **1** | deactivating a plan resets it; reached from `CActivateUnitPlanCommand::Execute` and `CUnitPlan::ApplyToUnit`, both interface commands |
| `CUnitPlan::LoadKey`, `0x4DF93B` | whatever the save holds | load |

### And the seven posters, by their `air_stance` argument

| site | enclosing | air_stance | path |
| --- | --- | --- | --- |
| `0x35244E` | GUI, `0x3523F0` | the player's chosen value | player |
| `0x351C8E` | GUI, `0x351C30` | 3 (it is the naval twin) | player |
| **`0x4916AD`** | **`CEU3AI::UpdateUnitStances`** | **2** | **AI, every pass, every agent** |
| `0x4B5152` | `0x4B5060` | 3 | AI, power estimates only |
| `0x4B7E87` | `0x4B60F0` | 3 | AI, power estimates only |
| `0x4C375E` | `CAIUnit::SetPlanStance` | 3 | AI, ground stance only |
| `0x4DAD74` | `CAIUnit::Slot76_BuildPlan` | **0** | AI, at plan build |

Each argument was read by tracking `esp` forward from the enclosing function's entry against the
constructor's own stores, not by counting pushes: the idiom at every site is `push ecx` to reserve a
slot, `mov ecx, esp`, `push ecx`, and then `mov [ecx], 0xFFFFFC18` **over the pushed pointer**, so
the two power arguments look like pointers in the disassembly and are plain −1000 by the time the
call happens.

**The AI's two writers pull against each other**, and the order settles it: slot 76 zeroes both
stances when it builds a plan, and `UpdateUnitStances` drives them back to 2 on the next pass. Slot
76 is reached from `CEU3AI::CreateAgentsForPlannedUnits`, which `ProcessAI` runs only while
`ai->unit_agents_count (+0x48)` is zero, and from `CObjectivesEntry` slot 22 — so 0 is the transient
and 2 is the resting state.

### The searches, and the control

The negative here needed a positive control before it turned positive, and it had one.
`fieldchain.py --field 0x20C --writes` returns 344 candidate sites across `.text`; **exactly one is
on a `CUnit`**, `0x1E7907`, and that is the writer the record already carried. So the method
demonstrably sees a writer of this field. (It nearly produced a false negative anyway: the first
reading took only the tail of its 345-line output, and `0x1E7907` sorts in the middle.)

For the plan side, a displacement scan is useless — `CUnitPlan +0x10` is a disp8 — so the search was
over **every register-form `lea reg,[x+0x1FC]` in `.text`**, which is the only route to a plan
pointer that is not a `CUnitPlan` method's own argument, the plan being embedded by value. Each
enclosing body was then scanned for a store to `+0xC`/`+0x10`/`+0x14`. That returns the constructor,
the `SetActive` reset and `LoadKey`; the control is that it also returns `CUnit::CUnit`'s own
in-place plan construction at `0x1B5232`.

The one blind spot worth stating: the seven command sites come from a **direct**-call scan of the
constructor, so a construction reached indirectly would not appear. All seven are direct calls.

### What is still open

**A live read of an AI country's agent units at `plan_air_stance`.** If any read 1, something clears
it faster than `ProcessAI` restores it, and the candidates are the two `SetActive` reset paths. That
is the only check this section wants and it is one command.

## 2. `CUnitPlan::SetActive`, and the record's 0 that is a 1

The record says the deactivate arm resets `air_stance` and `naval_stance` to **0**. It does not:

```
0x4DEB73  mov     eax, 1
0x4DEB78  mov     dword ptr [esi + 0x10], eax     ; air_stance  = 1
0x4DEB7B  mov     dword ptr [esi + 0x14], eax     ; naval_stance = 1
0x4DEB7E  xor     eax, eax
0x4DEB80  mov     dword ptr [esi + 0xC], 2        ; stance = 2
```

`functionStart(0x4DEB78)` answers `0x4DEB10` and `retsBefore` between them is empty, so the store is
inside `SetActive` and not in a following function (traps 2 and 3). The difference is not cosmetic:
**0 is the value at which phase 4 does not run at all** (`0x4CEE6E`), 1 is the value at which it runs
and issues `ground_attack` and `air_intercept`. A reset therefore leaves the unit flying CAS and
interception, not grounded.

Three callers: `CUnitPlan::ApplyToUnit` (`0x1D0F16`), `CActivateUnitPlanCommand::Execute`
(`0x1E5451`) and `CSetPlanAttributesCommand::Execute` (`0x1E7822`). The last cannot take the reset
arm. **So the reset is reachable only from the two plan-level commands, both of which the interface
posts** — which is the one way a player can silence an agent's strategic air war, until the next
`ProcessAI` pass restores it.

Its recorded signature also placed `this@ESI` and left `active` bare. `scripts/checkSignatures.py`
calls that certainly wrong, because Ghidra reads a signature as custom storage the moment one
parameter says where it lives and then drops any parameter that does not. `active` is the single
stack argument at `[ebp+8]`, so `@stack:4`, and `ret 4` agrees.

**`CActivateUnitPlanCommand::Execute` (`0x1E5400`) was not in the record at all.** Virtual slot 6,
one holder (`vtable.py --holding` gives table `0x15C925C` and nothing else, so no fold), bare `ret`.
It resolves `this->+0x40`/`+0x44` through `FindPersistentById` against `[0x1A857F0]` or
`[0x1A857F4]` by whether the type half exceeds `0x1268`, backs up eight bytes to the `CUnit`, and
calls `SetActive(&unit->plan, this->+0x64)`. Its failure arm is its sibling's: a lookup that fails
falls to `xor eax,eax` and the plan pointer becomes `0x1FC`, which survives only because an invalid
command is rejected before slot 6 runs.

## 3. `0x4B4740` fills all four `air_target_provinces_*` lists

`0x4B4740` to the `ret 4` at `0x4B4E59`, `void __stdcall CAIUnit::BuildAirTargetProvinceLists(CAIUnit* agent)`.
Fourteen `int3` before the entry and a `push ebp; mov ebp,esp` prologue; four `int3` after the exit.
Both boundaries clean, so trap 2 does not apply either side.

`esi` is a `CAIUnit` from **two distinctive neighbours rather than from a displacement** (trap 12):
`mov eax,esi; call 0x4BBAE0` is `CAIUnit::GetArea`, and `lea ecx,[esi+0x34]; call 0x2610` is
`CCountryTag::GetCountry` on the recorded `CAIAgent +0x34 country_tag`.

One caller, `CAIUnit::Tick` at `0x4B0A4F`, under:

```
0x4B0A38  if (agent->unit (+0x64) == 0)        skip
0x4B0A3E  if (Tick's own replan flag is set)   call
0x4B0A45  if (agent->+0x83 != 0)               skip
0x4B0A4E  call 0x4B4740
```

and the function sets `agent->+0x83 = 1` as its last act (`0x4B4E18`). **So the four lists are built
once per agent and rebuilt only on a replan.** Nothing in either body clears the byte; it is
recorded as `air_target_lists_built`, and the name rests on those two sites alone — `+0x83` is a
disp8 and cannot be byte-searched, so its readers were not enumerated image-wide. That is trap 14's
`tutorial_active` shape and the reason this one is `inferred`.

### Step 1: the candidate provinces

`GetArea(agent)` first; when it answers nothing, the agent's `unit->current_province_ptr (+0x130)`'s
theatre id pair (`CMapProvince +0x380`/`+0x384`) is resolved through `FindPersistentById` and used in
its place. All four lists are then emptied with four calls to `CListOfOwned_ClearByPointer`
(`0x4B47C2`, `0x4B47D1`, `0x4B47E0`, `0x4B47EF`).

It walks `CCountry +0xD70` — a `CList` whose payloads are `CMapProvince` — for three sets of
countries, keeping a province when its `+0x54 home_base_ptr`'s virtual slot 1 answers false and its
own `+0x380`/`+0x384` matches the area object's id pair at `+8`/`+0xC`:

- our own country (`0x4B481A`),
- our faction leader, `+0xF3C` indexed into the country database at `[0x1A855A4]+0x16C`, when
  `has_faction (+0xF34)` is set (`0x4B48E7`),
- every country in `+0xF78` (`0x4B4989`).

And separately, into a `std::vector<CMapProvince*>` at `[esp+0x38]`, the same `+0xD70` provinces of
every country in `enemies (+0x1008)` whose `+0x44` byte is set and whose area (`+0x2B4`) equals that
country's own `CCountry::GetActingCapitalLocation`'s area (`0x4B4A30`–`0x4B4B80`).

### Step 2: four scores per candidate

Each record is 0x10 bytes and is a `CPersistent`: vftable `0x15EB644`, save id `0x18D` at `+4`, the
province id (`CMapProvince +0xD0`) at `+8`, the float at `+0xC`. Built at `0x4B4C1B`–`0x4B4C45` and
inserted by `CList_InsertByAscendingScore` (`0x4DD590`). **This confirms, from the writer, the
payload layout `FINDINGS-airnaval4.md` deduced from the reader alone** — including that it is not the
0x1C scored-province record `+0x2C0` uses.

| list | appended at | the float is the mean distance to |
| --- | --- | --- |
| `+0x1FC` default | `0x4B4C68` | `ops_area (+0x90)` when `manage_reserve (+0x364)` is set, else the enemy-home-base vector; **blended `0.75·s(+0x1AC) + 0.25·s(that)`** when `invasion_target_provinces` is non-empty |
| `+0x20C` strategic | `0x4B4CC1` | `strategic_target_provinces (+0x18C)` |
| `+0x21C` naval | `0x4B4D1A` | `enemy_sighting_provinces (+0x19C)` |
| `+0x22C` transport | `0x4B4E00` | `invasion_target_provinces (+0x1AC)`, under the gate below |

The blend is explicit: `[0x160A4E8]` is 3.0 and `xmm3` holds `[0x160A258]` = 0.25, so the arithmetic
at `0x4B4BF2`–`0x4B4C11` is `(s2 * 3 + s1) * 0.25`. The branch at `0x4B4BBD` is a `jne` on
`agent->+0x364`, taken when the byte is **set**, which is the arm that keeps `eax = agent + 0x90`;
the `lea eax,[esp+0x40]` it skips is the enemy-base vector's begin (the two pushes at `0x4B4BB1`/
`0x4B4BB6` are what shift `+0x38` to `+0x40`). Nothing between the `cmp` and the `jne` touches flags.

So the naval-bomber list is "bases near where we last saw the enemy", which is what makes it the
naval one in practice — there is no test on water anywhere in it.

### The scorer, `0x4B4E60`

`float __stdcall CAIUnit::MeanDistanceToProvinceList(void* provinces@EAX, CAIUnit* agent@stack:4, CMapProvince* province@stack:8) @XMM0`.
Five callers, all inside the builder. Three `ret 8` exits at `0x4B4F02`, `0x4B4F79` and `0x4B4F8A`.

```
n = (end - begin) / 4
if (n > 0):
    total = sum over p of CMap::DistanceBetweenProvinces(province->id, p->id, g_CMap [0x1A8557C])
    if (province is itself one of them) total *= 2.0            ; [0x160A360]
    return total / n
; the vector is empty - fall back on the plan's objectives
n = agent->unit->plan_objectives_count (+0x23C)
if (n <= 0) return 10000.0f                                     ; [0x160A59C]
total = sum over the CObjective list at unit->plan_objectives (+0x234), linked through +0x1C,
        of DistanceBetweenProvinces(province->id, objective->+8)
return total / n
```

So the figure is a **mean map distance** in `DistanceBetweenProvinces`'s units — four times the
straight-line distance, not a path length — doubled when the candidate base is itself one of the
provinces measured against, and 10000 when there is nothing at all to measure against. Since
`CList_InsertByAscendingScore` keeps the lists lowest-first, **low is good**: the AI prefers a base
close to the set each list is for, and the doubling pushes a base that is itself a target towards
the back.

It also settles, for free, that **`CObjective +8` is a province id**: it is the second argument of a
function whose own record types both arguments as ids. `CObjective`'s 0x24-byte layout and its
`+0x1C` next link are exactly what `CopyObjectiveList`'s record already gives.

The argument positions were fixed from the call sites, not assumed: `0x4B4BB1` pushes the province
and `0x4B4BB6` the agent, so `[ebp+8]` is the agent — which `0x4B4F08` then dereferences at `+0x64`,
the recorded `CAIUnit::unit`.

One note for a decompilation: the float comes back in **XMM0**, read directly by every call site
(`movaps xmm2, xmm0` at `0x4B4BDA`), not in ST(0) where Ghidra models a `float` return on a 32-bit
`__stdcall`. The signature therefore places the return as `@XMM0` and all three parameters with it,
because Ghidra's custom storage is all-or-nothing.

### The ascending insert, `0x4DD590`

`void __stdcall CList_InsertByAscendingScore(void* list, void** item)`, `ret 8`, four callers — the
four appends and nothing else. It is the **ascending twin** of the recorded
`CList_InsertByDescendingScore (0x4DD4B0)`, and the two differ in exactly two instructions:

```
0x4DD4B0:  movss xmm0,[ecx+8]     comisd xmm2, xmm1   ; new vs node -> DESCENDING
0x4DD590:  movss xmm0,[ecx+0xC]   comisd xmm1, xmm2   ; node vs new -> ASCENDING
```

Otherwise identical: walk back from the tail (`[list+4]`, prev at node `+4`), insert after the first
node that does not have to be passed, bump the count at `[list+8]`, and fall through to `0x5F5E0` to
push at the head when every existing node loses. **So the four lists are lowest-score-first**, which
is what makes the mean distance a cost rather than a merit. The two readings stand or fall together
on `0x5F5E0` being a push-front, which is the arm both twins take in the same circumstance.

### The transport list's gate is the reader's gate inverted

At `0x4B4D1F`–`0x4B4DAC`: `n = (agent->+0x170 − agent->+0x16C) / 4`; if `n <= 0`, **nothing is
appended to `+0x22C` at all**. Otherwise, for each `CUnit` in that vector, the unit's
`current_province_ptr (+0x130)`'s area (`+0x2B4`) must answer true to its own virtual slot 0, and the
candidate is accepted if that area *is* the candidate's area or appears in the area's `+0x34` list.
One acceptance is enough.

In `CAIUnit_ManageAirUnits` phase 2 the same vector is tested at `0x4CE28E`–`0x4CE29F` with the
sense reversed: for a wing carrying a transport plane, `(+0x170 − +0x16C) & ~3 > 0` makes the body
**jump out** (`jg 0x4CE63B`) and skip the wing entirely, and `+0x22C` is selected only when the
vector is empty. Both sites use the identical `test eax, 0xFFFFFFFC` idiom on the same field pair,
which is what makes the comparison safe; only the branch senses differ.

**So the transport list is filled only when that vector is non-empty and read only when it is
empty.** Within one pass the two can never both hold, so anything phase 2 reads out of `+0x22C` was
built on an earlier pass: the lists are built once and then only on a replan (`+0x83`), while
`+0x16C` is erased and refilled by slot 78 every pass (`0x4B1E14`). Reported as read, not explained
— it looks like a sense error in one of the two places, and nothing in the code says which.

### Why no earlier pass found the writer, which is the part worth keeping

`findings/FINDINGS-airnaval4.md` wrote that a writer must exist but "reaches the list through a
pointer no displacement scan can follow", and told the next reader that `fieldchain.py --holder`
would not find it either. **That diagnosis is wrong, and it is the kind of wrong that costs a
wave.** The writer reaches every list through a plain `lea reg, [agent + 0x1FC]` — exactly the shape
the record ruled out — and

    python scripts/fieldchain.py --field 0x1FC

prints `0x4B47BB` and `0x4B4C61  lea eax,[ebx+0x1fc]  in 0x4B4740` in its first screen of output.

What actually went wrong is narrower: that pass's scan ran "from all 2,067 recorded function
entries", and `0x4B4740` was not one of them. **The method was entry-limited, not
displacement-blind**, and the write-up recorded the wrong one of the two. This is trap 9's rule read
one notch too strongly: decoding only from recorded entries does stay synchronised, but it cannot
reach a function nobody has recorded, which is precisely where an unknown writer lives.
Byte-searching a disp32 encoding and decoding **at each hit** has the same safety and no such hole.

And the first search the open item prescribed could not have worked at all. "The other callers of the
teardown helper at rva `0x4B6260`" — `0x4B6260` is the **virtual** address the destructor's
disassembly prints (`call 0x4b6260`); the rva is `0xB6260`. Trap 1, carried from a disassembly line
into a sentence of rvas. At the right address it is already recorded as
**`CListOfOwned_ClearByPointer`, with 79 callers** across the whole image: a generic list clear that
discriminates nothing.

### Completeness of the writer claim, and its control

A byte search of `.text` for the disp32 encodings of all twelve words of the four lists — exhaustive
for the encoding, since every one of the twelve exceeds `0x7F` and so must be encoded as disp32 —
then a decode at every hit, keeping the **1,599** whose decoded instruction really carries that
displacement on a base register other than `esp`/`ebp`.

In `0x4A0000`–`0x4E0000`, exactly four functions compute or store one of the four **head** addresses:

| function | what it does |
| --- | --- |
| `CAIUnit::CAIUnit` (`0x4AF530`) | zeroes all twelve words, `0x4AF778`–`0x4AF7CC` |
| `CAIUnit::~CAIUnit` (`0x4AFC30`) | tears all four down, `0x4AFD6F`–`0x4AFD9A` |
| **`CAIUnit::BuildAirTargetProvinceLists` (`0x4B4740`)** | four clears and four appends |
| `CAIUnit_ManageAirUnits` | the four reads, `0x4CE253`/`0x4CE2AD`/`0x4CE27B`/`0x4CE2A5` |

Every other hit at those displacements in the same band is on a different object and is excluded by
its holder rather than by the displacement (trap 12): `0x4CD9B5`, `0x4CEE6E` and `0x4CF908` are
`CUnit +0x20C`, and `0x4DF7B7`'s `esi` is a `CUnitPlan`, which is 0x90 bytes and cannot have a
`+0x22C` at all.

**The positive control** is that the same scan reports the constructor's zeroing at `0x4AF778` and
the air body's four reads — exactly the code the previous pass saw, and one function more. A method
that sees everything the entry-limited scan saw, plus a function it missed, has earned its silence
about a fifth writer.

## What is not established

1. **Nothing here was watched in a running game.** Section 1 in particular rests on static reading
   plus a correct reading of the *existing* live note. The check it wants is one command: an AI
   country's agent units read at `plan_air_stance`.
2. **`CCountry +0xD70`** — the builder's input. Its payloads are certainly `CMapProvince` (their
   `+0xD0` is fed to `DistanceBetweenProvinces` as a province id and their `+0x2B4` compared against
   a capital province's area), but the field is deliberately **not named**. `fieldchain --field 0xD70`
   gives 28 trap-12 candidates and `CCountry::RebuildNeighbours` (`0xE21E0`) is among the writers,
   which does not obviously fit "the country's air-base provinces". Naming it off one consumer is
   trap 14's `tutorial_active` case. The writers to read are `0xE21E0`, `0xCA740` and `0xC8A40`.
3. **`CCountry +0xF78`** — a `CCountryList` walked between the faction leader and `enemies (+0x1008)`,
   with the same `{tagChars, tagId, prev@+8, next@+0xC}` node shape. Allies by position in that
   sequence, which is not a reading.
4. **`CMapProvince +0x54`'s virtual slot 1** (the skip predicate at `0x4B4835`) and the area object's
   **slot 0** (`0x4B4D63`). Both are reached through a pointer whose class RTTI does not name here,
   and naming a slot body from one call site is trap 4.
5. **`CAIUnit +0x84`**, read by `CAIUnit::Tick` at `0x4B09DC` as part of the decision that sets the
   replan flag the builder's caller tests. Unnamed and unread.
6. **Which of the two transport-list gates is the mistake.** Both are read off instructions; that one
   of them is a sense error is an inference from their being mutually exclusive, and the code does
   not say which side is intended.

## Frontier

As rvas: `0xC0700` (the vector reallocate, also on wave 9's frontier), `0x5F5E0` (the `CList`
push-front both score inserts fall through to), `0x794936` (`_Xlen`, the `'vector<T> too long'`
throw). `0xB6260` is recorded as `CListOfOwned_ClearByPointer` at `likely` only, and it has now been
read end to end with 79 callers counted, so it could be promoted to `confirmed` by whoever next
touches that entry.

## The fragment, and what the checks said

`reversing/fragments/merged/airstance.json`: **9 addresses and 7 struct fields**, using
`struct_fields`, only `confirmed`/`inferred`, and `no_signature` present on every entry. Five of the
nine addresses are `revises`, which is most of this file's value.

`python ghidra/mergeFindings.py --check` reports **no entry-level problem** — only the expected
"source `reversing/findings/FINDINGS-airstance.md` does not exist" until this document is
transcribed, alongside three sibling agents' write-ups in the same state.

`python scripts/checkSignatures.py` audits `project.json` only and so cannot see a fragment. The four
new or revised signatures were therefore run through `checkSignatures`' own `expected()`,
`carriesClass()` and `storageComplaint()` over a scratchpad copy of `project.json` with the fragment
folded in. All four agree with their `ret`: `0x4B4740` `__stdcall` one stack argument against `ret 4`;
`0x4B4E60` one register and two stack arguments against `ret 8`; `0x4DD590` two stack arguments
against `ret 8`; `0x1E5400` `__thiscall` with only `this` against a bare `ret`. Two storage
complaints showed up on the first run and both were real: `0x4B4E60` placed one of three parameters,
and `CUnitPlan::SetActive` — already in `project.json`, unchanged for two waves — placed `this@ESI`
and left `active` homeless. Both are fixed in the fragment.

**Confidence.** Eight of the nine addresses are `confirmed`; so is every revision. `CAIUnit +0x83
air_target_lists_built` is the one honest `inferred`: the mechanism is read off two instructions, but
the name rests on those two sites and a disp8 cannot be enumerated.

---

## Transcription note

Read and written by wave 10's agent D; transcribed by the session that collected the wave, because an
agent's `Write` is refused for this path. Spot-checked independently before transcription, all
confirming: the idempotence test (`mov eax,2; cmp [ebx+0x20C],eax; jne; cmp [ebx+0x210],eax; je`,
falling through to `push 0x7c; call operator_new`); the command's arguments (`push 2; push 2; push 5;
push ebx; push eax`, with `mov [ecx], 0xfffffc18` written twice over reserved slots); the phase-4
gate reading `[ebp+8]` → `+0x64` → `+0x20C`; and `SetActive`'s `mov eax, 1` feeding both stores.

**The trap-14 claim in section 1 is confirmed and is worse than it reads.** `project.json`'s entry
for `CEU3AI::UpdateUnitStances` has said, since `FINDINGS-aiplans.md`, *"It also builds
CSetPlanAttributesCommand directly at 0x4916AD with (unit, 5, 2, 2, -1000, -1000) - stance left
alone, air and naval stance both set to 2."* So the record already contained the answer, in the
entry for the function that is the answer, while a findings file published the opposite conclusion
from a live distribution read off the wrong class of object. Nothing in the pipeline compares a new
conclusion against what the record already says, and this is the second instance in two waves — the
other being the `skip_automation_keys` comment knowing a key that `CGameState::LoadKey`'s own key
list omits.
