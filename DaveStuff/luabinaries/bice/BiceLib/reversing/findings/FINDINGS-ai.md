# The AI

When the AI runs, on which thread, and what each of the five ministers does. Everything here
was read out of the executable on 2026-09-30; the game was not running. Addresses are virtual,
based at `0x400000`, with the rva beside them where a finding names one.

**In one line.** Every country owns a `CEU3AI`, which owns five minister agents; a
`tbb::parallel_for` runs all of them **once per game hour, on TBB worker threads**, and each
minister does its real work on one hour of the day picked from the country's own id - then
hands the decision to a named global function in the mod's Lua.

## The objects

`CCountry +0x1D8` is the country's `CEU3AI` (already recorded; see `FINDINGS-diplomacy.md`).
Two fields next to it turned out to matter more than expected:

    CCountry +0xCA4   CCountryTag by value - the three tag letters plus a NUL
    CCountry +0xCA8   the country's **id**: its index into the country database

Both are written by `CCountry::CCountry` (`0x4C8A40`) from its second and third arguments, at
`0x4C95D3` (`al`, `ah`, `cl`, `0`) and `0x4C95EC`. The id is what the whole engine indexes by:
`CCurrentGameState +0xBCC` (`played_countries_array`, already recorded) is indexed by it at
`0x6561AC`, and `g_CCountryDataBase[+0x16C]` is indexed by it at `0x8895DB` and `0x6EC106`.
The two `CCountry::CCountry` call sites are `0x515D91` - the `---` placeholder, tag
`0x2D2D2D`, id `0`, in a `0x1208`-byte object - and `0x5178C7`.

`CEU3AI::CEU3AI` is **`0x888020` (rva `0x488020`), `ret 0xC`**, taking `(this, tag, id)`. Its
first act is to build the string `script/ai_country.lua` (`0x15EB628`) and hand it with `this`
to `0xA7E210`: **`CEU3AI` is the `CReloadableInterface` for that file.** It then fills:

    CEU3AI +0x20   CCountryTag   the country's tag        (from arg 2)
    CEU3AI +0x24   int           the country's id         (from arg 3)
    CEU3AI +0x60   CAIForeignMinister*
    CEU3AI +0x64   CAIProductionMinister*
    CEU3AI +0x68   CAIEspionageMinister*
    CEU3AI +0x6C   CAITechMinister*
    CEU3AI +0x70   CAIPoliticsMinister*
    CEU3AI +0x74   the agent list head   (node: [0] agent, [4] prev, [8] next, [0xC] byte)
    CEU3AI +0x78   the agent list tail
    CEU3AI +0x7C   the agent count

**The survey's "the five ministers land at `+0x60/+0x64/+0x68/+0x6C/+0x74`" is wrong.** The
fifth is `+0x70`; `+0x74` is the head of the agent list the driver walks. Read from the
five create/destroy blocks in `0x888F30`, each of which stores to its own offset and then
pushes the same pointer onto the `+0x74` list.

Its only callers are `0x6832DB` and `0x683629`, both inside **`0x683140` (rva `0x283140`)**,
which logs `Starting AI` (`0x15CF31C`) from `gamestate.cpp` line `0x795`. That function walks
every country (`gamestate+0xBBC`), news `0x12C` bytes, constructs a `CEU3AI` with
`(country[+0xCA4], country[+0xCA8])`, writes it to `country+0x1D8` at `0x6832FD`, and pushes
it into a vector at **`CCurrentGameState +0x114 / +0x118 / +0x11C`**. That vector is the whole
AI: it is what the parallel pass iterates.

### The minister agents

`CAIAgent::CAIAgent` is **`0x89C720` (rva `0x49C720`), `ret 8`, and takes `this` in `EAX`** -
confirmed: the first instruction is `mov dword [eax], 0x15C3AE4` with nothing having written
`eax` in the function. It sets `+0x04 = 0x18D`, `+0x28 = 0x0F`, `+0x24 = 0`, `+0x30 = 0`,
`+0x3C..+0x3E = 0`, `+0x40..+0x4C = 0`, `+0x50 = 0`, and

    CAIAgent +0x34   CCountryTag   arg 1
    CAIAgent +0x38   int           arg 2
    CAIAgent +0x3C   byte          the enable flag - **0 at construction**
    CAIAgent +0x54   CEU3AI*       the owner (luabind calls it `OwnerAI`), set by each subclass

**`+0x38` is the country's id, not an opaque stagger.** Both arguments come straight off the
owner: every minister constructor does `push [esi+0x24]; push [esi+0x20]` with `esi` = the
`CEU3AI` (`0x8890D1`, `0x8891CE`, `0x8893D9`, `0x89CAD6`, `0x89D2E9`, `0x8AE7D6`), and
`CEU3AI +0x24` is the id. Independent confirmation: `CAITechMinister` slot 47 (`0x8AE9B0`)
opens `cmp dword [ecx+0xCA8], eax` with `eax = this[+0x38]` and returns unless they are equal -
it is comparing a `CCountry`'s id against its own `+0x38`. **So the stagger is per-country,
stable, and equal to the id, which is what makes the schedule below predictable.**

The four subclass constructors that are separate functions, all `this` in `EAX` and the owner
in `ESI`:

    0x49D2E0  CAIForeignMinister     0x74 bytes, vftable 0x15EB97C, ->CEU3AI+0x60
    0x49CAD0  CAIEspionageMinister   0x5C bytes, vftable 0x15EB7BC, ->CEU3AI+0x68
    0x4AE7D0  CAITechMinister        0x80 bytes, vftable 0x15EBF5C, ->CEU3AI+0x6C, +0x5C/+0x5D = 1,1

`CAIProductionMinister` (`0x60` bytes, vftable `0x15EBD7C`) and `CAIPoliticsMinister` (`0x5C`
bytes, vftable `0x15EBC2C`) have no separate constructor - both are inlined into the two
creation functions.

### Who creates them, and the delegation flags

**`CEU3AI::CreateMinisters` - `0x8888C0` (rva `0x4888C0`), `thiscall`, bare `ret`.** Its one
caller is the tail of `CEU3AI::CEU3AI` at `0x888566`, so the ministers exist from the moment
the `CEU3AI` does. For each of the five it decides:

    isPlayer = (this->id (+0x24) == gamestate->player_id (+0xC34))      0x88895E
    if (gamestate[+0xD0C] != 0) return;                                 0x888975
    if (!isPlayer)                            -> create it
    else if (GetLocalPlayer()->flags[n] == 1) -> create it
    else                                      -> destroy it

`GetLocalPlayer` is **`0x685F00` (rva `0x285F00`), `ret 4`**: it walks the list at
`gamestate+0x60` on `+0x54`, matching `[entry+0x1C]` against `in_game_screen` slot 18's
`+0x6C`, and falls back to `gamestate+0x70`. Its `+0x38` is an array of five ints, and the
index order the two creation functions use is

    flags[0] -> CAIForeignMinister      (+0x60)
    flags[1] -> CAIProductionMinister   (+0x64)
    flags[2] -> CAITechMinister         (+0x6C)
    flags[3] -> CAIPoliticsMinister     (+0x70)
    flags[4] -> CAIEspionageMinister    (+0x68)

**So an AI country always gets all five ministers, and the human's country gets one only for
the ministries it has delegated.** `CGameState::LoadKey` (already recorded) reads
`automate_trade`, `automate_sliders` and `automate_tech_sliders` off the save's `player`
record, which lines up with flags 0, 1 and 2; that pairing is inference, the branch order is
not.

**`0x888F30` (rva `0x488F30`)** is the same decision re-run for the player alone. It takes
**`this` in `EDI`** with a bare `ret` - confirmed at its call site `0x6EC109`, `mov edi,
[country+0x1D8]` where the country is `g_CCountryDataBase[+0x16C][gamestate->player_id]` - and
it skips the `isPlayer` test, always consulting `GetLocalPlayer`. Its four callers are UI:
`0x6EBF00` is slot 13 of `CCountryView`, `CDiplomacyView`, `CEspionageView`, `CPoliticsView`,
`CProductionView` and `CTheatreView`; `0x822290` and `0x822600` are slots 12 and 13 of
`CTechnologyView`; `0x6EBB00` is in no vftable. It is the delegate-a-ministry switch, and the
survey was right about that. It also sets the tech minister's two bytes `+0x5C`/`+0x5D` from a
four-way switch on `GetLocalPlayer()[+0x30]` (`0x889319`-`0x889367`).

## The virtual interface

`vtable.py CAIAgent CAIPoliticsMinister CAITechMinister CAIEspionageMinister
CAIProductionMinister CAIForeignMinister CAIInvasion CAIUnit --all` confirms the survey:
**slot 8 and slot 9 are identical in all seven subclasses, slot 10 differs in every one.**
(There are seven subclasses, and the survey's list left one out: `CAIInvasion`.)

    slot 8   0x49C6F0   CAIAgent::IsEnabled   xor eax,eax; cmp byte [ecx+0x3C], al; setne al; ret
    slot 9   0x49CA90   CAIAgent::Update      shared by all seven, 0 direct callers
    slot 10  per class  the "do your job" slot

    slot 10: Foreign 0x49D600  Production 0x4A22E0  Tech 0x4AEAD0
             Politics 0x4A1A40  Espionage 0x49CEC0  Invasion 0x49FB10  CAIUnit 0x4B0710
             CAIAgent's own is the shared empty 0xABF890

`CAIAgent::Update` in full, and it is 21 instructions:

    if (this->vf[8]())                  ; [vftable+0x20]
        if (--this->countdown (+0x30) == 0)
            this->vf[10]();             ; [vftable+0x28]
    for (node = this->children (+0x44); node; node = node->next (+8))
        node->agent->vf[9]();           ; [vftable+0x24]

Slots 11 to 47 are the `CAISubscriber` observer interface and are `0x60CD50` / `0xA806D0`
stubs in every minister except two:

- **`CAIForeignMinister` slot 41 (`0x49E490`), `ret 8`**, taking two `CCountry*`. It reads
  `b->id (+0xCA8)`, looks up `a[+0xE28][id]`, takes that record's `+0x20`, and calls the mod's
  Lua `ForeignMinister_OnWar` (via `0x89E860`) with both countries' tags at `+0xCA4`. So this
  is the "a war concerns me" notification, and it goes to Lua.
- **`CAITechMinister` slot 47 (`0x4AE9B0`), `ret 8`**, taking `(CCountry*, int)`. It returns
  immediately unless `country->id == this->id`, then news `0x48` bytes and builds an object
  with `0x557E00(obj, this->tag, this->id, arg2)` - a command, on the shape of the object -
  before touching the game state. What the notification is, is not established.

## The driver

**`ProcessAI` - `0x8894E0` (rva `0x4894E0`), `__stdcall`, `ret 4`**, taking one `CEU3AI*`.
Extent `0x8894E0` to the `ret 4` at `0x889BB5`, then `int3` padding. It does more than walk a
list:

    if (ai[+0x128] != 0) return;                                    0x889506
    country = CCountryTag::GetCountry(&ai->tag);                     0x889517
    if (country[+0x580] != 0) return;                                0x88951C
    if (ai->id == gamestate->player_id && ai[+0x2C]) ai[+0x2C] = 0;   0x8895AC
    0x89A800(ai);  0x889E10(&ai->tag, ai);                           0x8895C0, 0x8895C8
    rec = g_CCountryDataBase[+0x16C][ai->id];
    if (rec[+0xCF8] <= 0 && rec[+0x95] == 0) { 0x899A10(ai); return; }    0x8895E4
    ... 0x88961B, a branch on ai[+0xA5] / ai[+0xA6] and gamestate[+0xD9C]
    for (node = ai[+0x74]; node; node = node[+8])                     0x8896C8
        if (node[0] && byte[node[0] + 0x3C]) node[0]->vf[9]();
    if (ai[+0x60]) 0x89E010(ai[+0x60]);                               0x8896F7
    ... continues past 0x88977B

The `+0x3C` gate and the `+8` chain are as the survey described. **Note the enable flag is 0
at construction**, so something must set `agent+0x3C` before any minister does anything; which
code does that is not established.

## When it runs, and on which thread

The driver has exactly four callers.

**1. The recurring one, and it is threaded.** `0x68F080` (rva `0x28F080`) is
`tbb::internal::start_for<blocked_range<...>, ProcessAIFunctor, auto_partitioner>::execute` -
the name is in the RTTI export verbatim, vftable `0x15CF73C`. It halves its range and spawns a
child task through `tbb::internal::allocate_child_proxy::allocate` (`0xD2B570`) while the
range is bigger than the grain, and otherwise runs the serial body at `0x68F14D`:
`for (i = begin; i < end; ++i) ProcessAI(functor->vec[i])`. Its launcher is `0x68E430` (rva
`0x28E430`), which inits a `task_group_context`, allocates a root task and spawns it.

The launcher's single caller is **`0x683080` (rva `0x283080`), `ret 4`**, taking the game
state, and that is the gate:

    if (gamestate[+0xC68] != 0) return;                         0x68309F
    count = (gamestate[+0x118] - gamestate[+0x114]) / 4         the CEU3AI vector
    grain = max(1, count / ([0x170ABB0] == 1 ? 1 : 16))
    byte [0x1A857BF] = 1     ... parallel_for ...   restore
    gamestate[+0xC68] = 1                                       0x683116

`0x683080` is called once a frame from `CInGameIdler::Update` at `0x656278`, and
**`RunHourlyPass` (`0x282630`, already named) clears `gamestate[+0xC68]` at its very end**
(`0x682B1D`, guarded by `byte[gs+0xD9D] == 0`). A byte-exact sweep of `.text` finds only seven
instructions touching `+0xC68`: two zeroing writes in the `CGameState` constructor region
(`0x67C5DF`, `0x67D480`), the set and clear inside `RunHourlyPass` (`0x6829E4`, `0x682B1D`),
and the test/set pair in `0x683080`. **So the AI pass runs exactly once per game hour, on TBB
worker threads, from the frame after the hour turns.** A hook on `0x4894E0` or on any minister
tick is therefore *not* main-thread-only, and re-entrancy across countries is real.

**2. `CInGameIdler::Update` at `0x6561D1`, and it fires once per process.** The loop at
`0x6560E0`-`0x6561DB` walks every country, skips any with no `CEU3AI`, skips any the
`played_countries_array` marks as human (`0x6561B2`), calls `0x88D560(ai, 0)` and then
`ProcessAI(ai)`. It is reached only when idler slot 57 returns true, `byte [0x1BEA470] == 0`
and `byte [idler+0x68] != 0` (`0x65602D`) - and the loop's own exit sets `[0x1BEA470] = 1` at
`0x6561E0`. `findRefs.py --address 0x1BEA470` finds exactly two references in the whole image:
that read and that write. **Nothing clears it**, so this path is a one-off kick, not the
recurring driver. (That it is a deliberate one-shot rather than a bug is inference.)

**3. `CInGameIdler::Enter` at `0x66196F`** (already-named function, `0x25A2B0`): walks every
country, clears `country[+0x580]`, and calls `ProcessAI` when `byte[ebx+0x68] == 0`. Once per
game entered.

**4. `CInGameIdler` slot 67 (`0x64C170`, rva `0x24C170`) at `0x64C349`**: walks every country
and calls `ProcessAI` on each, gated on `byte[gamestate+0xD9C]`. What invokes slot 67 is not
established.

`0x88D560` (rva `0x48D560`) is the helper called just before `ProcessAI` in path 2: it walks
`country[+0xBAC]` (`units`) and, for each unit with `[unit+0x1F4] != 0`, calls `0x88DA40` to
get a per-unit object whose `+0x7C`/`+0x80` are a tag and an id it checks against the
`CEU3AI`'s. That is almost certainly the `CAIUnit` agent refresh, but nothing here watched it
construct one. Six callers.

## The schedule

**Every minister's slot 10 is `void __thiscall`, bare `ret`.** Each opens
`this->countdown (+0x30) = 1`, so slot 9 calls slot 10 again on the very next pass - the
throttling is not in `+0x30`, it is the date test inside each body. And the date test is
**not** what the survey said.

    stagger = this[+0x38]                  ; the country's id
    hours   = gamestate[+0xBDC] - 0x29C55C0
    act if  (stagger + K) % 24 == hours % 24

`idiv` leaves the remainder in `edx`, and `hours % 24` is the **hour of the day**, not the day
(Foreign `0x89D64B`-`0x89D676`; Politics `0x8A1A5F`-`0x8A1A9B`; Espionage `0x89CEDF`-
`0x89CF13`; and the second gate in Tech `0x8AEC12`-`0x8AEC40` and Production
`0x8A23F5`-`0x8A241A`). Since the pass itself runs once an hour, **each minister acts exactly
once a game day, at the hour `(country_id + K) mod 24`**:

    K = 0x0D (13)   CAIForeignMinister
    K = 0x11 (17)   CAIPoliticsMinister
    K = 0x01 ( 1)   CAIEspionageMinister
    K = 0x03 ( 3)   CAITechMinister
    K = 0x05 ( 5)   CAIProductionMinister

So for a country with id 7: espionage at 08:00, tech at 10:00, production at 12:00, foreign at
20:00, politics at 00:00 of the next day. The stagger spreads the load across the day, and a
modder can predict it from the country's position in the database.

Three bodies add a coarser rhythm on top, and Tech and Production get there through the same
day-of-month arithmetic:

    days       = hours / 24                       via the 0x2AAAAAAB magic, sar 2
    dayOfYear  = days - (int)((float)(int)(days / 365.0) * 365.0)    365.0 at 0x160A550
    month      = the loop at 0x8AEB4D / 0x8A235D, subtracting month lengths from 0x1713294
    dayOfMonth = dayOfYear - sum(month lengths before month)

- **Tech** (`0x4AEAD0`): before the hour gate, if either of its two vectors (`+0x60..+0x64`,
  `+0x70..+0x74`) is empty **or** `this[+0x58] > dayOfMonth` - which is only true when the
  month has just rolled over - it calls `0x8AECA0(this)` then `0x8AEF40(this)` and stores
  `dayOfMonth` in `+0x58`. So its plan is rebuilt **monthly**, and executed daily.
- **Production** (`0x4A22E0`): after the hour gate it calls `0x899770(this->OwnerAI)`, then
  runs the main block only if `this[+0x5C] < 0.0f` **or** `dayOfMonth % 14 == 0` - so on the
  1st and the 15th of the month, or whenever `+0x5C` is negative. The constructor seeds `+0x5C`
  from the `-1.0f` at `0x170AC0C`, so the first pass always runs. When it does run it sets
  `+0x5C = (float)*0x4EE560(country) / 1000.0` - a thousandths value cached as a float, of
  which the meaning is not established.
- **Politics** (`0x4A1A40`): inside the hour gate, `0x44C5C0()` is divided by 7 with the
  `0x92492493` magic and `0x8A1D40(this)` runs only when the remainder is zero - a **weekly**
  sub-task on top of the daily one.

## What the ministers decide: they ask the mod's Lua

Every minister's slot 10 ends in the same shape:

    call 0x8EACA0        ; the per-thread Lua state holder
    mov  edi, [eax]      ; lua_State*
    lea  ecx, [local]; mov [local], this; push ecx
    call <pusher>        ; lua_pushstring(L, "<Name>"); lua_gettable(L, LUA_GLOBALSINDEX)
    call <invoker>

**`0x8EACA0` (rva `0x4EACA0`) is a per-thread Lua state**, and that is the strongest evidence
that the AI is meant to run off the main thread: it reads `fs:[0x2C]` (the TLS array), and on
first use for a thread takes `EnterCriticalSection(0x1B15418)`, calls `luaL_newstate`
(`0xD2B478`) and `luaL_openlibs` (`0xD2B46C`), and runs `script/autoexec.lua`
(`0x15EC700`). Every AI Lua call in the image goes through it.

The pushers each hold one global function name, and `lua_pushstring` (`0xD2B4E8`) followed by
`lua_gettable` (`0xD2B45C`) with `0xFFFFD8EE` (`LUA_GLOBALSINDEX`, -10002) is a plain global
lookup:

    0x49E7C0   ForeignMinister_Tick                called from 0x89D69F  (Foreign slot 10)
    0x49D0D0   IntelligenceMinister_Tick           called from 0x89CF2F  (Espionage slot 10)
    0x4A2040   PoliticsMinister_Tick               called from 0x8A1AE4  (Politics slot 10)
    0x4A2B00   ProductionMinister_Tick             called from 0x8A249B  (Production slot 10)
    0x4AF280   TechMinister_Tick                   called from 0x8AEC60  (Tech slot 10)
    0x49E800   ForeignMinister_EvaluateDecision
    0x49E860   ForeignMinister_OnWar               called from foreign slot 41, 0x89E4F5

Those are exactly the files the mod ships: `script/ai_foreign_minister.lua`,
`ai_intelligence_minister.lua`, `ai_politics_minister.lua`, `ai_production_minister.lua`,
`ai_tech_minister.lua`. **The mod's AI Lua is not decoration - it is the whole decision.** The
same sweep for pushed name strings also finds `AI_GenerateNonHistoricalRelation` (pushed at
`0x5100D3`) beside the fourteen `DiploScore_*` names already recorded in
`FINDINGS-diplomacy.md`.

Each pusher is `cdecl` with one stack argument and no cleanup, taking the `lua_State` in `EDI`
and an output buffer in `ESI`, and returning `ESI` in `EAX`. `0x49E7C0` fills that buffer with
`{[0] = L, [4] = 1, [8] = 0xB7E9D0, [0xC] = arg, [0x10] = 0}`.

### What Foreign does before it calls Lua

`0x49D600` is the most mod-relevant body and the only one read past the gate here:

    if (byte this[+0x70]) { this[+0x70] = 0; return; }           a skip-once flag, 0x89D621
    ... the hour gate ...
    0x89E010(this);  then ForeignMinister_Tick                   0x89D67D, 0x89D69F
    if (this[+0x58] && (float)this[+0x5C] > 50.0)                50.0 at 0x160A4C8
        0x89A750(this->OwnerAI, this[+0x58]);                    0x89D6F0
        release this[+0x58]; this[+0x58] = 0; this[+0x5C] = -1.0f
    country = GetCountry(&this->tag)
    if (!country->is_major (+0x15C) || country[+0x60C] > 100)
        0x8AD9B0(&country[+0x48C])                               0x89D73D
    for (node = country[+0x5D4]; node; node = node[+8])           0x89D757
        rel = country[+0xE28][ node[+0xC] ]
        if (rel[+0x4C]) -> build something with 0xA230D0 and post it through
                           country[+0xF1C] slot 18 -> [+0x38] slot 6, then return
        else if (country->neighbours (+0xF58)[ node[+0xC] ])
            if (!0x8ADEF0(&country[+0x48C], node[+8], node[+0xC], node)) flag = 1

So: **a pending decision is held at `+0x58` with a 0-100 score at `+0x5C`, and it is executed
when the score passes 50** - the same 0-100 scale `CDiplomaticAction` slot 17 gets from
`ai_diplomacy.lua`. That `+0x58` is a `CDiplomaticAction` is inference, but it is refcounted
(released through slot 0 with argument 1) and it is handed to `0x89A750` with the owner AI.
The loop after it filters the list at `country+0x5D4` by whether the other country is a
`neighbour`, which is why a non-adjacent target needs a different route.

## `CAIStrategy` - who consumes it

The consumer is **`0x8A62A0` (rva `0x4A62A0`)**, and there is exactly one path to
`CCountry +0x1DC` in the image. A sweep of all 1295 `CCountryTag::GetCountry` call sites for a
`+0x1DC` access within `0x30` bytes returns one hit, `0x8A62C4`:

    country = GetCountry(&acc[+8]);
    0x8A3B90(acc, &country[+0x1DC]);     ai_hard_strategy      0x8A62D6
    0x8A3B90(acc, &country[+0x334]);     ai_event_strategy     0x8A62EA

`0x8A3B90` is the merge routine the existing record already reached from the other side:
`CAddAIStrategyEffect::Execute` (`0x5B0E00`) hands its embedded `CAIStrategy` and the scope
country's `+0x334` to `0x4A3B90`. So **`ai_hard_strategy`, `ai_event_strategy` and the
`add_ai_strategy` effect all feed the same accumulator through the same function.**

`acc` is a cache: `0x8A5C90` (rva `0x4A5C90`, `thiscall`) is its rebuild, and it
- bails when `acc[+0xC] == 0` or the tag at `acc+0x8` is `REB` (`0x8A5CBE`-`0x8A5CCE`),
- stamps `acc[+0x10] = gamestate->tick` and `acc[+0x14] = 1` (`0x8A5D99`, `0x8A5DB8`),
- and calls `0x8A5DD0`, `0x8ACE20`, `0x8AD430`, then `0x8A62A0`, then `0x8AD6E0`.

`0x8A5C90` has **11 direct callers**, spread across `0x4DB7C4`, `0x4E055D`, `0x4E3E5E`,
`0x4E6CCB`, `0x4EF2A2`, `0x4EF781`, `0x4F640E`, `0x4F645B`, `0x65C282`, `0x9B0E78` and
`0xA4018C`. So the strategy is consumed widely and lazily, per tick, rather than by one
minister. Which class owns the cache object is not established.

## What is not established

- **What sets `CAIAgent +0x3C`.** The constructor leaves it 0, and both the driver and slot 9
  gate on it, so nothing in this document explains how a minister becomes live. This is the
  single biggest hole and the cheapest next thing to close.
- `CEU3AI +0x128` and `CCountry +0x580`, the driver's two opening gates, and
  `CCurrentGameState +0xD0C` / `+0xD9C` / `+0xD9D`, which gate the creation function, slot 67's
  loop and the hourly re-arm. Any one of them could turn the AI off wholesale.
- The rest of `ProcessAI` past `0x88977B`, and its helpers `0x89A800`, `0x889E10`, `0x899A10`,
  `0x89E010`.
- `CCountry +0x48C`, `+0x5D4`, `+0xE28` and `+0xF1C`, all of which the Foreign minister reads,
  and `+0xCF8` / `+0x95` on the country-database record the driver tests.
- Which of the five `GetLocalPlayer()[+0x38]` flags is which save key. The branch order is
  read; the pairing with `automate_trade` / `automate_sliders` / `automate_tech_sliders` is
  inference, and flags 3 and 4 have no save key named here at all.
- What `CAITechMinister` slot 47's second argument is, and what event calls it. Same for what
  invokes `CInGameIdler` slot 67.
- The Tech minister's `0x8AECA0` / `0x8AEF40` (the monthly re-plan) and its two bytes
  `+0x5C`/`+0x5D`; the Politics minister's weekly `0x8A1D40`; the Production minister's
  `0x899770` and the thousandths value `0x4EE560` returns.
- `CAIInvasion` and `CAIUnit` - both are `CAIAgent` subclasses with their own slot 10
  (`0x49FB10`, `0x4B0710`) and `CAIUnit` has 17 extra slots of its own. Neither body was read.
  Neither constructor has a direct caller, so how those agents come into being is unknown.
- Whether the one-shot latches (`0x1BEA470` for the serial loop, `CCurrentGameState +0xC68`
  cleared hourly for the parallel one) behave as read in play. Both are static reads; David
  can settle the first in one game by watching whether path 2 ever fires twice.
- `0x1A857BF`, the global the parallel pass sets while running, and `0x170ABB0`, which is 1
  when the grain is the whole range (so, presumably, the single-thread setting).
