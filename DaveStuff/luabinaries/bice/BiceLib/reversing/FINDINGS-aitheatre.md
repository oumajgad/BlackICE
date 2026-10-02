# The AI's theatre layer, and `CAIInvasion`

`FINDINGS-aiunit.md` left two anonymous per-country objects holding theatre lists and asked for their names. **Both are named, and neither is a new class.** The second half of this file is `CAIInvasion`, which turns out to be the most compact piece of AI the game has.

Read statically off `hoi3_tfh.exe` on 2026-10-01, game not running. Addresses are **virtual** (base `0x400000`) unless marked rva. Nothing here was watched in a running game.

## 1. `CCountry +0x48C` is a `CAIStrategy`, and the game calls it `Strategy`

It is not a new class and it is not a manager. The luabind table names it outright:

    CCountry::GetStrategy   0x00417BE0   lea eax, [ecx+0x48C]; ret
    ghidra/luabind.json:   { "name": "Strategy", "offset": 1164, "type": "CAIStrategy" }

1164 is `0x48C`. **RTTI knows `CAIStrategy`** (vftable rva `0x11EBF24`, base `CPersistent`), so no vftable anchor is needed. Two independent confirmations out of the bytes:

- **`CCountry`'s own constructor builds three `CAIStrategy` by value.** At `0x4C8CD6`, `0x4C8CE6` and `0x4C8CF6` it calls `CAIStrategy::CAIStrategy` (`0x8A33A0`, `this` on the stack, writes vftable `0x15EBF24` at `0x8A33D4`), the last of them with `lea edx, [ebx+0x48C]`. The destructor (`0x4CA740`) destroys the same three in reverse — `lea ecx,[ebx+0x48C]`, `[ebx+0x334]`, `[ebx+0x1DC]` at `0x4CB1D6`/`0x4CB1F7`/`0x4CB206`, each through `0x8A3880`.
- **`CCountry::LoadKey` hands a block straight to it**: at `0x4CE0D1`, `mov edx,[ebx+0x48C]; mov edx,[edx+0xC]; lea ecx,[ebx+0x48C]; call edx` — slot 3, `CPersistent::Load`, on the subobject.

So the three strategies are `+0x1DC` (`ai_hard_strategy`), `+0x334` (`ai_event_strategy`) — both already in `project.json` — and **`+0x48C`, the merged working copy**. Three per country × 108 countries is 324, which is what `CLASSES.md`'s "326 of them live" counts, plus two elsewhere.

### This disagrees with `project.json`, which calls the class `AIStrategyCache`

The merge refuses to overwrite, so this is reported rather than changed:

| `project.json` says | should be |
| --- | --- |
| `AIStrategyCache::Rebuild` rva `0x4A5C90` | `CAIStrategy::Rebuild`, `this` = `&country->Strategy` |
| `ApplyCountryAIStrategies(AIStrategyCache* acc)` rva `0x4A62A0` | `(CAIStrategy* acc)` |
| `MergeAIStrategy(AIStrategyCache* acc, CAIStrategy** strategy)` rva `0x4A3B90` | `(CAIStrategy* dest, CAIStrategy* src)` |

`AIStrategyCache` is a correct *description* — the object is the cache of the two loaded strategies merged together, and `Rebuild`'s `+0x10 = tick` / `+0x14 = 1` stamp is exactly a cache validity stamp — but it is not a class. Every caller of `Rebuild` passes `&country[+0x48C]`, so the receiver has a name already.

### `CAIStrategy`'s layout, as far as this work touched it

The eighteen save keys are in `project.json` already. What is new:

| offset | what | evidence |
| --- | --- | --- |
| `+0x4` | `0x18D`, a constant type id the ctor writes | `0x8A33CD` |
| `+0x8` | **`CCountryTag`** — chars at `+0x8`, id at `+0xC` | ctor writes `0x2D2D2D` (`"---"`) at `0x8A33DA`; `ApplyCountryAIStrategies` does `GetCountry(&acc[+8])`; `0x8A9B10` reads `[+8]`/`[+0xC]` and tests the three bytes against `'R','E','B'` |
| `+0x10` | the tick the cache was last rebuilt at | `Rebuild`, already recorded |
| `+0x18` | `personality` | `FINDINGS-fieldmap.md` |
| `+0xE4`/`+0xE8`/`+0xEC` | **the theatre list** — `CList<CTheatre*>`, nodes `0x10` bytes `{data, prev, next, byte}` | below |
| `+0x14C`/`+0x150`/`+0x148` | `war_with` | `FINDINGS-fieldmap.md` |

**`+0xE4` is the `area_theatre` list, both ways round.**

- `CAIStrategy::LoadKey`'s `area_theatre` case (token `0x6EF`) at `0x8A4685`–`0x8A473C`: `new CTheatre(strategy->tag)` (`push 0xA8`, ctor `0x4AEFB0`, both halves of the tag pushed), then the theatre's slot 3 with the parse context, then its slot 6 with its own id pair, then a push_back onto `+0xE4`/`+0xE8`/`+0xEC`.
- `CAIStrategy::SaveContents` (slot 2, `0x8A4860`) reads `+0xE4` at `0x8A4D43` and writes key id `0x6EF` at `0x8A4D56`.

So `FindTheatreForUnit`'s `manager[+0xE4]` is `country->Strategy.area_theatres`, and `project.json`'s argument name `countryTheatreManager` can be read as `CAIStrategy* strategy`.

(Also worth recording: `FindTheatreForUnit` is `0x8ACD00`–`0x8ACD4A` with `int3` padding after it, so `0x8ACD50` is a **separate** function. Any name of the form `FindTheatreForUnit+0x50` is nearest-entry noise, not an interior address.)

## 2. `CCountry +0x570` is the *order of battle's* theatre list, and it is a different set

`+0x570`/`+0x574`/`+0x578` is a `CList` of the same shape (first, last, count; `0x10`-byte nodes). It has **32 accesses in the whole image and exactly two writers**, and both are command `Execute` bodies — slot 6 on a `CCommand`, per `FINDINGS-commands.md`:

| function | class, slot | what it does |
| --- | --- | --- |
| `0x550570` | `CAddTheatreCommand` slot 6 | registers the `CTheatre` it carries at `+0x44` (its slot 6, with the id pair) and appends it to `countries[cmd->+0x40]->+0x570` |
| `0x5DF600` | `CCreateHigherCommand` slot 6 | `new CTheatre(country->tag)` at `0x5DFCD8`–`0x5DFCFB` and appends it to `country->+0x570` at `0x5DFE20` |
| `0x5509C0` | `CRemoveTheatreCommand` slot 6 | the counterpart, unlinking from the same list |

Verified by reading the four theatre commands' vftables side by side (`CAddTheatreCommand` `0x15C3CA4`, `CRemoveTheatreCommand` `0x15C3CE4`, `CAlterTheatreCommand` `0x15C3C64`, `CUpdateTheatreCommand` `0x15C955C`): slot 6 differs in all four, slots 1 and 3 are the shared `CPersistent` pair, which is the signature of a `CCommand` family.

### How the two lists differ

**They are populated by disjoint code and neither ever writes the other.**

| | `CAIStrategy +0xE4` | `CCountry +0x570` |
| --- | --- | --- |
| filled by | the `area_theatre` key, and the AI's own rebuilder `0x8A9B10`/`0x8AC400` | `CCreateHigherCommand::Execute`, `CAddTheatreCommand::Execute` |
| emptied by | the strategy's own clear (`0x8A3DE0`) and destructor | `CRemoveTheatreCommand::Execute` |
| saved | **yes** — `CAIStrategy::SaveContents` writes it as `area_theatre` | **no**. Neither `CCountry::SaveContents` (`0x4CFF20`) nor `CCountry::LoadKey` (`0x4CCDA0`) appears among the 32 sites that touch `+0x570` |
| read by the AI | `FindTheatreForUnit` (`0x8ACD00`); the refresh pass `0x8ABC90` | `CEU3AI::CreateAgentsForTheatres` (`0x88AA80`, at `0x88AAAC`); `ProcessAI`'s readiness walk (`0x8897F7`); `CAIUnit::SetArea` (`0x8BA919`) and the plan builder slot 76 (`0x8DAC89`) |
| read by the interface | not seen | yes — `0x64D850` is in the `CInGameIdler` family, `0x66A3D0` in the map-mode band |

So the honest reading, and it is an inference from who writes each: **`+0x570` is the theatre list of the live order of battle** — a theatre exists there because the player (or the AI through `CCreateHigherCommand`) pressed the button that made an HQ — and **`CAIStrategy +0xE4` is the AI's own plan of theatres**, which is the thing the savegame keeps. That is why `CreateAgentsForTheatres` reads `+0x570` (one agent per theatre that actually exists) while `FindTheatreForUnit` reads `+0xE4` (which of my planned theatres owns this unit's OOB root).

**A consequence worth checking in a game**: because `+0x570` is never loaded, it should be empty immediately after loading a save, and `CreateAgentsForTheatres` should therefore create nothing until a `CCreateHigherCommand` executes. That is the one cheap live falsification of this section.

### `ProcessAI` uses `+0x570` as a readiness gate

At `0x8897E8`–`0x889852`, before any agent loop:

    if (!ai->+0xA6) goto agent loops
    for (node = GetCountry(ai->tag)->+0x570; node; node = node->next)
        theatre = node->data
        if (ResolveObjectId(theatre->+0x74, theatre->+0x78) == 0) goto agent loops   ; retry next hour
    AnnounceLoadedUnitsToScreen(ai, ai->id == gamestate->+0xC34)                      ; 0x88D560
    ai->+0xA6 = 0

`CTheatre +0x74`/`+0x78` is the theatre's `unit` key, so the test is "does every theatre have a live HQ unit yet". **`CEU3AI +0xA6` is the flag that asks for this**: the AI's theatre rebuilder sets it (`0x8ABAA4`, `0x8ABB77`, `0x8ABF22`, all `mov byte [country->ai + 0xA6], 1`) and only `ProcessAI` clears it (`0x8896BC`, `0x889852`). `+0xA5` is a second such flag, set at `0x889B94` and read at `0x88961B`, `0x889A82`, `0x899CF2`; what it means was not established.

Note that `AnnounceLoadedUnitsToScreen` hands objects to `CCurrentGameState::in_game_screen` **from a TBB worker thread** — see the thread section.

## 3. Who makes a theatre, and when

Four producers, and they fall into two camps.

**Commands — the order of battle's theatres.**

- `CCreateHigherCommand` is the live one. Its three real constructors are `0x5DF320` (two callers: `0x75DB4B`, in the interface function at `0x75DAE0`, and **`0x8C31AF`, which is inside `CAIUnit` slot 85's body, `0x8C20C0`**) and `0x5DF430` (one caller, `0x66ADDB` in `0x66AC80`, also interface). So *the AI creates theatres through the same button the player uses*, out of slot 85 — the slot `FINDINGS-aiunit.md` had as the `RADIO_*` command-range slot. That file's command table should gain `CCreateHigherCommand` for slot 85.
- `CAddTheatreCommand` appears to be **dead in this build**. Its vftable `0x15C3CA4` is written in exactly two places: `0x5504B2`, in the registration prototype `0x550430` whose only caller is the command-type registry, and `0x550551`, in `0x5504D0` whose only caller is `0x550815` inside the class's own slot 13 (clone). Nothing `new`s a fresh one, so it can only arrive through the command factory — i.e. off the wire or out of a command stream.

  (The registry is `0x885050`, a single ~`0x2EE7`-byte function reached once from `0xA58E2D` in the setup path; it calls the default constructor of every command class in the game. `functionStart` attributes `0x886064`/`0x8860C7`/`0x8871F8` to it correctly, and those three calls are registrations, **not** theatre creations. This is an easy wrong finding: the naive reading is "setup posts AddTheatre and CreateHigher commands", and it is false.)

**The AI — its own `area_theatre` plan.** `0x8A9B10` is the theatre builder: `void __stdcall (CAIStrategy* strategy, bool fromScratchHint)`, `ret 8`, VA `0x8A9B10`–`0x8ABC83` in one body (`image.retsBefore` finds one interior `ret` at `0x8A9C2A`, which is a real early exit sharing the frame, not an abutting function — `0x8A9C2D` reloads `[0x1A855A4]` and carries on inside the same `sub esp, 0x150`). It:

- bails at once for the `REB` tag (`cmp al,0x52 / dl,0x45 / al,0x42` at `0x8A9B43`–`0x8A9B56`) and for a zero tag id;
- when `in_game` (`gamestate +0xDA4`) is set **and the strategy already has theatres** (`+0xEC > 0`), tail-calls the cheaper refresh `0x8ABC90(strategy, 1)` and returns;
- otherwise builds theatres from scratch: **six separate `new CTheatre` sites** (`0x8AA0DE`, `0x8AA419`, `0x8AA605`, `0x8AA7E6`, `0x8AA9C3`, `0x8AAB02`), each `push 0xA8` then `0x4AEFB0(tagChars, tagId)`, each stamping the id from the global counter **`g_theatre_id` (`0x170AEBC`)** with id type `0x2D` (45) and registering through the theatre's slot 6;
- appends them to `strategy->+0xE4` at `0x8AB8E0`/`0x8AB8F5` and `0x8AB9AA`;
- and for each one, if `GetCountry(&strategy->tag)->+0x1D8` (the `CEU3AI`) is non-null, calls `CEU3AI::EnsureAgentForArea(ai, theatre, 1)` and sets `ai->+0xA6 = 1`.

**So a `CTheatre` is made three ways: by the player's Create-Higher-Command, by `CAIUnit` slot 85 issuing the same command, and by the AI's own `0x8A9B10` — and it is loaded a fourth way, out of the `area_theatre` block of a save.** The scenario does not make them directly; there is no `theatre` key that produces a `CTheatre` (the OOB's `theatre =` makes a `CArmy`, per `FINDINGS-oob.md`), which closes that file's open question *"whether a top-level theatre also makes a CTheatre"* in the negative.

`CTheatre` is **`0xA8` bytes** — all seven allocation sites `push 0xA8`. Its slot 6 takes a `{type, serial}` id pair by pointer and is called immediately after construction everywhere; that is the register-with-the-object-table call. Constructor `0x4AEFB0` (rva `0xAEFB0`), `this` in EAX, tag's two halves on the stack; a second argument-less constructor `0x4AEEB0` serves `CAddTheatreCommand`'s prototype and clone.

## 4. `EnsureAgentForArea`'s four callers, and the `0x8ABxxx` region

All four live in **two** functions, and both are the AI theatre layer:

| call site | containing function | extent |
| --- | --- | --- |
| `0x8ABAEF`, `0x8ABC38` | `0x8A9B10`, the theatre builder | `0x8A9B10`–`0x8ABC83`, `ret 8` |
| `0x8ABE8F`, `0x8ABFAE` | `0x8ABC90`, the theatre refresh | `0x8ABC90`–`0x8ABFF6`, `ret 8` |

`0x8ABC90` begins after `int3` padding at `0x8ABC86`–`0x8ABC8F`, so it is a genuine boundary and not the abutting-function trap. Its only caller is `0x8A9C15`, the early-exit arm above. It takes `(CAIStrategy*, bool)`, walks `GetCountry(&strategy->tag)->+0xD00` (`province_ids`) and re-sorts those provinces over the existing theatres; it is the per-province refresh that `0x8A9B10` delegates to when it has nothing to build.

The third member of the family is **`0x8AC400`**, `(CAIStrategy*, bool isMyHour)`, which also appends to `+0xE8` (at `0x8ACCA1`). It is called from `0x8ABC44` and from `RunCountryHourlyPass`.

`0x8A8EF0(CAIStrategy*, COwnerArea*, bool)`, `ret 0xC`, is the area-strength query the invasion planner uses: it walks the area's provinces (`COwnerArea +0x24`, count `+0x2C`), then each province's `units` (`CProvince +0x2B8`), and counts the ones belonging to a country the strategy's owner is at war with, excluding `REB` on either side. It reads the strategy only to get its tag at `+0x8`.

## 5. The entry points, and which thread each is on

This is the part a BiceLib hook has to get right, and the two halves of the theatre layer are on **different threads**.

| function | reached from | thread |
| --- | --- | --- |
| `0x8A9B10` theatre builder | `RunCountryHourlyPass` at `0x4D9093` | **tick thread** |
| `0x8AC400` theatre maintenance | `RunCountryHourlyPass` at `0x4D90C6` | **tick thread** |
| `0x8ABC90` theatre refresh | `0x8A9C15`, inside the builder | **tick thread** |
| `CEU3AI::EnsureAgentForArea` `0x88A880` | all four callers are in the two functions above | **tick thread** |
| `CEU3AI::CreateAgentsForTheatres` `0x88AA80` | `ProcessAI` at `0x889A61` | **worker** |
| `ProcessAI`'s `+0x570` readiness walk | `ProcessAI` at `0x8897F7` | **worker** |
| the invasion planner `0x892190` | `ProcessAI` at `0x889A39` and `0x889AB5` | **worker** |
| `CAIInvasion` slot 10 / slot 73 | `ProcessAI`'s `+0x50` loop at `0x889887` | **worker** |
| `FindTheatreForUnit` `0x8ACD00` | both sides | **either** |

`RunCountryHourlyPass` is tick-thread by `project.json`'s own confirmed entry: one caller, `RunHourlyPass` at `0x682833`, in a serial loop over the country vector. `0x4D9093` sits inside its body — `retsBefore(0x4D8EB0, 0x4D9093)` is empty, and `0x4D8EB0` is a fresh prologue with its own SEH push after a single `int3` at `0x4D8EAF`.

**So `CAIUnit` construction is not worker-only after all.** `FINDINGS-aiunit.md` listed `EnsureAgentForArea`'s thread as "not traced"; it is the tick thread, which makes it the third tick-thread way into `CAIUnit` beside `CreateUnitAgent` and the observer slots. The theatre *objects* and the agents *for* them are both made on the tick thread; only the hourly agent ticking is on workers.

`RunCountryHourlyPass` chooses between the two passes on a dirty flag:

    if (country->+0x580)  0x8A9B10(&country->Strategy, 0)         ; full build
    else                  0x8AC400(&country->Strategy, hour == country->id % 24)

**`CCountry +0x580` is the "rebuild my theatres" flag**: set at `0x4A3517`, `0x4B8268`, `0x4E3E63` and `0x4E7152`, cleared at `0x661952`, and read by `ProcessAI` at `0x88951C`. The `% 24` on the other arm is the same per-country stagger the ministers and `CAIUnit` slot 73 use.

## 6. `CAIInvasion` — what makes the AI invade, and where it lands

74 slots, vftable `0x15EBAE4`, base `CAIAgent`, **`0x94` bytes** (`push 0x94` at `0x893AFB`). Constructor `0x89F920` (rva `0x49F920`), `ret 8`:

    CAIInvasion(CCountryTag* tag@ECX, CProvince* staging, CEU3AI* owner)

It forwards the tag's two halves to `CAIAgent::CAIAgent` (`0x89C720`, `this` in EAX), writes vftable `0x15EBAE4` at `0x89F934`, zeroes three `CList`s and stores the two stack arguments.

    CAIInvasion  (0x94 bytes; vftable 0x15EBAE4; ctor 0x89F920 writes it at 0x89F934)
      +0x34  CCountryTag  the owner, CAIAgent's
      +0x38  int          the owner's country id, CAIAgent's
      +0x3C  byte         enabled, CAIAgent's
      +0x3D  byte         a second flag; AddUnit refuses to claim a unit while it is set
      +0x3E  byte         finished - once set, slot 10 never does anything again
      +0x54/+0x58/+0x5C (+byte 0x60)  CList: the land force
      +0x64/+0x68/+0x6C (+byte 0x70)  CList: the transports
      +0x74/+0x78/+0x7C (+byte 0x80)  CList: every unit committed; slot 62 is its getter
      +0x84  CProvince*   where it sails from
      +0x88  CProvince*   where it lands - null until the agent has picked one
      +0x8C  CEU3AI*      the owner AI
      +0x90  int          the landing province's id (CProvince +0xD0)

`+0x84` and `+0x88` are provinces on three agreeing readings: `0x4EF7C0` is called with `[+0x88] + 0x334`, and `CProvince +0x334` is `controller`; `[+0x84] + 0x2B4` is compared against a `COwnerArea*`, and `CProvince +0x2B4` is `area`; and `+0x90` is set from `[+0x88] + 0xD0`, which is `CProvince::id`.

### The slots it supplies

Read out of the image at the vftable address, not from the `introduces` list — which again reports fewer than the class actually supplies.

| slot | body | what it is |
| --- | --- | --- |
| 0 | `0x89F980` | scalar deleting destructor |
| 10 | `0x89FB10` | the tick gate (below) |
| 49 | `0x89FB00` | `jmp CAIAgent::Disable` |
| 52 | `0x89FAF0` | **Enable** — `+0x3C = 1; +0x30 = 1`, four instructions |
| 54 | `0xABF890` | overrides `CAIAgent`'s with the shared empty |
| 60 | `0x791940` | not read |
| 61 | `0x8E9090` | not read |
| 62 | `0x89F910` | `lea eax,[ecx+0x74]; ret` — the committed-units getter |
| 63 | `0x8A1680` | **AddUnit** |
| 64 | `0x8A1860` | RemoveUnit |
| 66 | `0xA92590` | `mov al,1` — the type tag. `CAIUnit` has `mov al,1` at slot 65 and `xor al,al` at 66; `CAIInvasion` is the mirror, exactly as `FINDINGS-aiunit.md` predicted |
| 70 | `0x8A18E0` | compares two `+0x2B4` (areas) and, when they differ, calls `0x897B40(this->+0x8C, ...)` |
| 73 | `0x89FB40` | the real tick |

**Slot 63 (`AddUnit`) steals the unit's agent pointer.** At `0x8A16B2`–`0x8A16D7`:

    if (unit->+0x198 && unit->+0x198 != this)  unit->+0x198->slot64(unit)
    if (!this->+0x3D && !this->+0x3E)          unit->+0x198 = this
    push_back onto +0x74/+0x78/+0x7C

So **`CUnit +0x198` can hold a `CAIInvasion*` as well as a `CAIUnit*`.** `project.json` has that field as `ai_agent CAIUnit*`, written by `CAIUnit::SetUnit`; the type is too narrow. Reported, not changed — anything that reads `CUnit +0x198` and assumes a `CAIUnit` can get a `CAIInvasion` and read `+0x64` (the unit pointer on a `CAIUnit`) out of the middle of its transport list.

### The tick, and when an invasion is over

Slot 10 (`0x89FB10`) is eleven instructions:

    if (this->+0x3E) return
    this->+0x3E = IsInvasionOver(this)            ; 0x8A12F0
    if (this->+0x3E) return
    this->slot73()
    this->+0x30 = 1                               ; ask to be ticked again

`IsInvasionOver` (`0x8A12F0`, `ret 4`) answers true — the agent is done forever — when **`+0x6C < 1` (no transports left) or `+0x5C < 1` (no land units left)**. Otherwise, when `+0x6C == 1`, it also checks the single transport's `COrder*` at `CUnit +0xB0`, asks it slot 16 for its type id and compares it with **`0x3A5`** — the save token `invasion`, i.e. `CNavalInvasionOrder` — and then that the order's `+0x2EC` is positive.

Slot 73 (`0x89FB40`, forty instructions) is the whole of the agent's behaviour:

    country = GetCountry(&this->tag)
    if (!this->+0x88 || !0x4EF7C0(country, &this->+0x88->controller, 1))
        PickLandingSite(this)                                 ; 0x89FBC0
    if (!this->+0x88)                       { this->+0x3E = 1; return }
    if (!0x4EF7C0(country, &this->+0x88->controller, 1))  { this->+0x3E = 1; return }
    0x8A01F0(this)                                            ; not read
    0x8A0610(this)                                            ; not read
    0x8A09B0(this)                                            ; not read

`0x4EF7C0(CCountry* us@ECX, CCountryTag* them, bool)` compares `them->id` against `us->+0xCA8`, then looks the other country up and reads its `Overlord` (`+0xF38`); it is the "is this still a country I may land on" test. **So an invasion re-picks its landing province whenever the one it had stops qualifying, and kills itself when nothing qualifies.**

### Where it decides to land — `0x89FBC0`

`PickLandingSite(CAIInvasion* this)`, `ret 4`, `0x89FBC0`–`0x8A01E6`. It is a **minimising** search: the running best is initialised to `0xF4240` = 1,000,000 at `0x89FD45`, and a candidate replaces it on `jl`.

1. **It measures its own force first.** Over `this->+0x54` it climbs each unit's slot 9 and requires `[that +0x300] == 0`, then `unit->current_province (+0x130)->area (+0x2B4)` to pass a virtual, collecting the distinct areas into a local list. Then `canTakeMore = (this->+0x5C <= 5) && SumTransportWeight(&this->+0x64) >= SumTransportWeight(&this->+0x54)` — at most five land units, and lift at least as big as the load. `SumTransportWeight` (`0x5D6690`, list in EAX) is already named in `project.json`.
2. **A range limit.** `0x47FD90(GetActingCapitalLocation(country)->area)` returns a bool and picks the limit: **1000 when true, 2000 when false** (`movzx/neg/sbb/and 0xFFFFFC18/add 0x7D0` at `0x89FD2D`–`0x89FD39`).
3. **Outer loop: every country in `country->+0xF98`.** Inner loop: every `COwnerArea` in that country's `+0xD30`. An area is skipped when it is the staging province's own area.
4. **A per-area weight**, 1.0 by default; when `0x47FD90(area)` is true it becomes 2.0, and 4.0 when the area is **not** the one holding the owner's acting capital. (All three constants read out of `.rdata`: `0x171DBAC` = 1.0, `0x1718064` = 2.0, `0x171DF34` = 4.0.)
5. **Inner-inner loop: every province in the area** (`COwnerArea +0x24`, next at `+8`):
   - `0x4D52A0(country, province, this->+0x84, 1)` must pass — a reachability test;
   - `dist = 0x4A5570(province, this->+0x84->id)`, floored at 1000 and **rejected above the limit from step 2**;
   - `w = 1.0`, or **10.0** when `0x4A56B0(province, 0)` is true — a tenfold penalty;
   - `score = (1.5 - (province->naval_base->+0x20 / 1000) / 10.0) * w` (`0x160A6B8` = 1.5, `0x160A340` = 10.0; `CProvince +0x300` is `naval_base`);
   - `score *= 0.3` (`0x160A3E8`) when the area's controller is **our own** country (`cmp eax, [this+0x38]`);
   - and the best score wins, writing `this->+0x88 = province` and `this->+0x90 = province->id` at `0x8A0176`/`0x8A0186`.

**So where the AI lands is, in one line: the nearest-enough enemy-held province with the biggest port, inside an area it cannot walk to, weighted three times over — 10× against provinces `0x4A56B0` rejects, 2× for the enemy's capital area against 4× for anywhere else, and 0.3× for retaking our own ground.** Lower is better, and the naval base is the only term that can reduce the score, so **a port is what makes a province a landing site**.

### What makes the AI mount an invasion at all — `0x892190`

`void __stdcall (CEU3AI* ai, void* outList, CAIUnit* agentOrNull)`, `0x892190`–`0x893C70` (`ret 0xC`). Two call sites, both in `ProcessAI`:

- `0x889A39`, once per unit agent in `ai->+0x40`, on the branch taken when the country **is** the player's (`gamestate +0xC34 == tag.id`) and `ai->+0x2C == 0`, gated behind an `id & 1` parity test;
- `0x889AB5`, once with `agentOrNull = 0`, on the ordinary AI-country branch, after `CreateAgentsForTheatres`.

Its named callees say what it weighs, and the shape is unambiguous:

| callee | what it contributes |
| --- | --- |
| `CCountry::IsEnemy` `0x42F210` (twice) | the target must be an enemy |
| **`AreaIsConnectedTo` `0x4B8DC0`** | at `0x892B9E`: `if (area->slot0() && area != ourArea && AreaIsConnectedTo(area, ourArea)) skip` — **the AI only invades an area it cannot reach overland.** This is the amphibious test |
| `0x8A8EF0` | enemy units in the area, clamped to >= 1, multiplied into the score — a weakly held area is preferred |
| `NavalBaseCapacity` `0x4A75D0` (three sites) | port capacity at both ends |
| `CUnit::SupplyConsumption` `0x5BB560` (four sites) | what the force will cost to supply |
| `SumTransportWeight` `0x5D66D0` (four sites) | the lift |
| `CSubUnit::GetMaxOrganisation` `0x5AB700` | force readiness |
| `GetActingCapitalLocation` / `GetCapitalLocation` | distance anchors |
| `AddMonths` `0x4B8C90` | a date horizon |

and the decision itself, at `0x893AD7`–`0x893B5D`:

    if (candidateTransports.count < 1)                      return
    if (SumTransportWeight(&candidateTransports) < required) return
    inv = new CAIInvasion(&ai->tag, stagingProvince, ai)     ; push 0x94
    push_back onto ai->+0x50/+0x54/+0x58
    for each of three gathered lists:  inv->slot63(unit)     ; AddUnit, [vft+0xFC]
    inv->slot7()                                            ; CReferenceObject AddRef
    inv->slot52()                                           ; Enable, [vft+0xD0]

**So: the AI commits to an amphibious invasion the hour it has gathered enough transport lift to carry the land force it has picked, against an enemy area it cannot march to.** The agent then runs once an hour until its force is gone, re-choosing its landing province whenever the one it has stops being an enemy's.

## What is not established

1. **`CCountry +0xF98`** — the country list the landing search iterates. It is one of twelve `CCountryList` on `CCountry`, nodes `0x14` bytes `{tagChars, tagId, prev@+8, next@+0xC, byte}`, rebuilt by `CCountry::RebuildNeighbours` (`0x4E21E0`) at `0x4E3341`–`0x4E338E`. Membership needs `CDiplomacyStatus +0x58` set, and then excludes `REB` on either side **and any country `CDiplomacyStatus +0x20` (`war`) says we are at war with**. That last exclusion is the one that does not fit "the invasion target list", so the obvious name is probably wrong and `+0x58` was not identified. **Do not assume this is `enemies`.** (The same walk also confirms `+0xF88` is `Allies` — it is the list `CDiplomacyStatus +0x14` feeds, alongside the `NumOfAllies` counter at `+0x1064` — and `+0x1028` is `SpyingOnUs`, fed from the espionage vector at `+0x1160`.)
2. **`CCountry +0xD30`** — the list of `COwnerArea*` walked per country. Read only through this path; which areas it holds (owned, controlled, present-in) was not traced. `COwnerArea` has no struct in `project.json` at all; what this work used of it is `+0x24` (provinces list, next at `+8`) and `+0x2C` (count).
3. **`0x47FD90`, `0x4D52A0`, `0x4A5570`, `0x4A56B0`** — the four predicates and the distance function the landing search leans on, read only as "returns a bool / returns a number". `0x4A56B0` in particular is the 10× penalty and deserves a name.
4. **`CAIInvasion` slots 60, 61, 70** and the three stage functions `0x8A01F0`, `0x8A0610`, `0x8A09B0` — the part that actually loads the transports, sails and issues the `CNavalInvasionOrder`. Read as addresses only. `0x8A09B0` is the likely home of the order.
5. **Which of `+0x54` and `+0x64` gets filled where.** Slot 63 appends only to `+0x74`; `+0x54` is appended at `0x8A17BA`/`0x8A17D0` and `+0x64` at `0x8A182B`/`0x8A1841`, in two small functions between slot 63 and slot 64 that were not read. The land/transport split is **inferred** from `SumTransportWeight(+0x64) >= SumTransportWeight(+0x54)` and from `IsInvasionOver` asking `+0x64`'s first member for a `CNavalInvasionOrder`, not proved.
6. **`CEU3AI +0xA5`** and **`CEU3AI +0x2C`** — both read as gates and neither explained.
7. **The six `new CTheatre` sites in `0x8A9B10` were not told apart.** Six distinct code paths make a theatre; what distinguishes them (land/sea, home/overseas, a fixed set of six roles) was not read. That is the single biggest remaining hole in the theatre layer.
8. **Nothing was watched in a running game.** Three cheap live checks: `CCountry +0x570`'s count should be zero on a freshly loaded save and non-zero after the player makes a theatre; `CCountry +0x48C +0xEC` should equal the number of `area_theatre` blocks in that country's save block; and `census.py CAIStrategy` should find three per country plus a handful.

---

### Three disagreements with the existing record, reported not redefined

| record | evidence against |
| --- | --- |
| `AIStrategyCache` as a class name (`0x4A5C90`, `0x4A62A0`, `0x4A3B90`) | `CCountry::GetStrategy` + the three in-place constructions in `CCountry`'s ctor; it is a `CAIStrategy` |
| `CUnit +0x198` typed `CAIUnit*` | `CAIInvasion::AddUnit` (slot 63, `0x8A16D7`) writes a `CAIInvasion*` there |
| `FindTheatreForUnit`'s second argument `void* countryTheatreManager` | it is a `CAIStrategy*`; `manager[+0xE4]` is the `area_theatre` list |

### Two additions to `FINDINGS-aiunit.md`

- `CEU3AI::EnsureAgentForArea`'s thread is **not** untraced: all four callers reach it from `RunCountryHourlyPass`, i.e. the **tick** thread. `CAIUnit` is therefore constructed on the tick thread by three of its four paths, not one.
- Slot 85's command table should gain **`CCreateHigherCommand`** (`0x5DF320` called at `0x8C31AF`, inside slot 85's body `0x8C20C0`).

### Scratchpad

`scratchpad/aitheatre/` holds three reusable scripts: `name.py` (nearest `project.json` entry for an address — useful but it *invents* `Foo+0xN` names for unnamed code, so never quote its output as a finding), `calls.py` (every direct and virtual call in a range, with names), `whoslot.py` (which vftables hold a function and at which slot, from the RTTI export). The last one is how the four theatre commands' slot 6 was settled and is the tool the "count holders before naming a slot body" rule wants.
