# How the engine boots, stage by stage

Read out of `hoi3_tfh.exe` on 2026-10-02, statically. Addresses are **virtual** (base
`0x400000`) with the rva beside them; `VA = RVA + 0x400000`. Only valid for this build.

**In one line.** Startup is **one virtual, `CEU3Application` slot 6 (`0x62FAC0`, rva
`0x22FAC0`), called from `main.cpp:592`**, and it inlines every stage into its own body
except four calls: the sound-effect loader (`0x63A190`), the **databases/map/history
monolith** (`0x6348F0`, rva `0x2348F0`) which is one straight-line function of 5,512
instructions spanning `eu3application.cpp` lines ~790–1285, and **the checksum**
(`0x632DA0`), which runs **last**. The graphical map (`0x634570`) is not in this chain at
all: `CFrontEnd` slot 3 calls it after startup has finished. The hypothesised stage order
that opened this work was `.rdata` layout, and `.rdata` layout is the **source-file** order
of the three called functions, not the call order — trap 12, in its purest form.

---

## 1. Why address order *is* evidence here, and when it is not

Trap 12 says position is not evidence. Two different positions are in play and only one of
them is worthless:

- **`.rdata` string order is worthless.** The strings for the checksum (`0x15CC990`
  onward), the map (`0x15CCB40`) and the databases (`0x15CCD74`) sit in that order in
  `.rdata` because the three *functions* that reference them sit in that order in
  `eu3application.cpp` — lines 759, 768 and 917 respectively. The linker emitted them in
  source order. The **call** order is checksum last, map after everything, databases early.
- **Address order inside one straight-line function is execution order.** `LoadEverything`
  and the database monolith each contain no loop over their stages; every branch is a local
  null test. So the order the blocks appear in is the order they run.

Two independent confirmations of the second claim, which is what the rest of this file
rests on:

1. **`__LINE__` is an immediate in the image.** The log idiom is

   ```
   push <strlen>; push <file string>; call 0x40A160     ; std::string("eu3application.cpp")
   push <flags>; push <__LINE__>; push <that string>; call 0x402410
   mov edx, <message>; call 0xA64A00                    ; operator<<
   ...; call 0xA647D0                                   ; emit
   ```

   so every log site carries its source line. Across `LoadEverything` the lines run
   267, 274, 299, 325, 327, 330, 343, 370, 373, 376, 378, 384, 435, 444, 450, 454, 507,
   510, 515, 518, 522, 543, 553, 573, 579 — **monotonically increasing with address**.
   Across the database monolith they run 917 → 1283, also monotonic. `flags` picks the
   channel: `3` is `system.log`, `0x10000` `game.log`/`setup.log`, `0x10005` the RAM
   lines, `0x10006` `time.log`, `0x10004` the error channel.

2. **A real startup log already on disk agrees line for line.** The mod's own
   `%USERPROFILE%\Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\logs\time.log`
   and `system.log` (2026-10-02) print exactly these line numbers in exactly this order.
   Nothing was launched to get them; they are files. They are **dynamic evidence of a past
   run**, so they corroborate rather than establish, but the static line numbers and the
   log never disagree once.

The nine `LOADING_*` / `INIT_*` / `CREATING_*` keys are loading-screen progress text, and
all nine are in the mod's own `localisation/frontend.csv` — including
`LOADING_DATABASES2;Loading Databases II...`, which is the engine saying out loud that
there is a second database stage.

## 2. The frame: four functions, not thirteen

| function | VA | rva | extent | exit | convention |
| --- | --- | --- | --- | --- | --- |
| `CEU3Application::LoadEverything` (slot 6) | `0x62FAC0` | `0x22FAC0` | `0x62FAC0..0x632CE5` | bare `ret`, plus an early bare `ret` at `0x630C97` (the "sound card not installed" path) | `__thiscall`, no stack args |
| `CEU3Application::LoadDatabases` (recorded as `LoadCommonFiles`) | `0x6348F0` | `0x2348F0` | `0x6348F0..0x63A185` | `ret 4` at `0x639FDA`; the blocks past it to `0x63A181` are the two `catch` arms, both ending in `_CxxThrowException` | one stack arg, the application |
| `CEU3Application::CreateChecksum` | `0x632DA0` | `0x232DA0` | `0x632DA0..0x634568` | `ret 4` | one stack arg, the application |
| `CEU3Application::InitialiseGraphicalMap` | `0x634570` | `0x234570` | `0x634570..0x6348E2` | bare `ret` | `__thiscall`, no stack args |

All four boundaries are clean `int3` runs (`0x632CE6` ×10, `0x63A186` ×10, `0x63456B` ×5,
`0x6348E3` ×13), so none is an abutting-function artefact. `retsBefore` over the database
monolith returns **exactly one** `ret` in `0x5895` bytes, which is why I am confident it is
one body and not a desynchronised sweep.

`LoadEverything` and `CFrontEnd` slot 3 are both reached through a vftable, so
`findRefs --callers` reports zero for each; `image.findBytes` finds the function address
once each, in `.rdata`, and the RTTI export resolves the holder:

```
0x62FAC0 appears at 0x015CD1C0 -> CEU3Application vftable 0x015CD1A8, slot 6 of 9
0x6EEF00 appears at 0x015D4598 -> CFrontEnd       vftable 0x015D458C, slot 3 of 110
```

And `main` calls that slot by instruction, immediately after logging `main.cpp:592`:

```
0x00A59FA4   push 'main.cpp' ... push 3; push 0x248 (=592); call 0x402410   ; 'Init Application...'
0x00A5A019   mov ecx, [ebp - 0x18]          ; the CEU3Application
0x00A5A028   mov edx, [ecx]
0x00A5A02A   mov eax, [edx + 0x18]          ; slot 6
0x00A5A02D   call eax                       ; -> LoadEverything
...
0x00A5A10A   push 3; push 0x259 (=601); ...                                 ; 'Run Application...'
0x00A5A18E   call 0xA90F90                  ; the run loop; the frontend is entered from here
```

`confirmed`. The function that holds all eighteen `main.cpp` log sites exits with
`ret 0x10` at `0xA5A2E5`, but **its entry is not pinned down** — `functionStart` answers
`0xA58B9F`, which is not an instruction boundary, and `0xA570A0` (the byte after the
previous `ret 0x10`) does not decode as a prologue. See *What is not established*.

## 3. The corrected sequence

`eu3application.cpp` line numbers are the static immediates. Indentation shows nesting.

| # | line | what | the function that does it | confidence |
| --- | --- | --- | --- | --- |
| 0 | main.cpp:592 | `Init Application...` → `CEU3Application` slot 6 | `0xA5A02D` | confirmed |
| 1 | 267 | `Initialise Defines` | `GetDefines 0x445D90` + `LoadDefines 0x446210` | confirmed |
| 2 | 274 | `App Init` | `0xA90D70` | likely |
| 3 | 299 | `Cursors Defines` — 13 `/cursors/*.cur\|.ani` paths | inline | confirmed |
| 4 | 325 | `Used RAM before sound&music [` | — | confirmed |
| 5 | 327 | `Sound...` | `0xABB8E0`, `0x632CF0`, `0xAD9080`, `0xAB8CD0` | likely |
| 6 | 370 | `Initiliasing Music & Sound<` (the engine's typo) | ends the sound stage | confirmed |
| 7 | 376/378 | `Initialise Graphics...` / `Graphics Done` | `0x840680` | confirmed |
| 8 | 384 | `Used RAM CEU3Graphics construction [` | — | confirmed |
| 9 | 435 | `Loading .gfx files <`, progress `LOADING_MAP_SPRITES` | enumerate `.gfx` ×2 dirs (`0xA6BCB0`), parse each, then `0x531DB0` | confirmed |
| 10 | 450 | `Initialise Graphics<` | `0xA711B0`, `0x84B020`, `0x883290` | likely |
| 11 | 507/515 | progress `LOADING_GUI_DEF`, `Loaded GUI Definition File: ` per file, then `Loading GUI <` | enumerate `.gui` ×2 dirs, parse each; then `0x67D740` | confirmed position, interior not read (owned elsewhere) |
| **12** | **522** | **`****> databases was total of <` — the whole database/map/history stage** | **`0x6348F0`, called at `0x6323C7`** | **confirmed** |
| 13 | — | progress `LOAD_EVENTS` | `GetEventList 0x9BF640` then `0x9C0430` | confirmed |
| 14 | 543 | progress `LOADING_SOUNDS`, then `Loading Soundeffects <` | `0x63A190`, called at `0x6325EA` | confirmed |
| 15 | 553 | `Loading Flags <` | `0x840BC0`, called at `0x6326B1` | confirmed |
| 16 | 573 | `history execute <` | `GetDefines`, three `CGameState::CGameState` (`0x67D070`), `0x67B240`, `0x5FA7E0`/`0x5F52A0` ×2 | confirmed position, interior partly read |
| 17 | 579 | `Idler Initialised <` | `CFrontEnd::CFrontEnd 0x6ED660`, `0xA90F40` | confirmed |
| **18** | **759–761** | **`Creating checksum for all files took `, `Checksum is `, `Testversion 4(settings)`** | **`0x632DA0`, called at `0x632AB4` — the last call in the stage** | **confirmed** |
| 19 | — | `0x6ECF60`, `0x6ECFB0`, `GetCustomGameSettings 0x41C4E0`, `0x41CAF0` | tail of `LoadEverything` | confirmed |
| 20 | main.cpp:596/601 | `Total loadtime after app init`, `Run Application...` | `main` | confirmed |
| **21** | **frontend.cpp:423–583** | **the frontend: `entering frontend...`, `LOAD_GFX`, artwork, `init map` → `0x634570` (`initialise map` 768, `Initialising Graphical Map <` 775, `Cleaning up after Graphical Map <` 779), `Mapflags`, `eu3 idler restore`, `Device objects`, `reloaded`, `frontend screens`, `Total loadtime was `** | **`CFrontEnd` slot 3, `0x6EEF00`** | **confirmed** |

`0x632DA0` and `0x634570` each have **exactly one** direct caller
(`findRefs --callers`): `0x632AB4` inside `LoadEverything`, and `0x6EF51A` inside
`CFrontEnd` slot 3 respectively. The frontend's call site is

```
0x006EF514   mov ecx, [esi + 0x210]      ; the CEU3Application, off CFrontEnd +0x210
0x006EF51A   call 0x634570
```

## 4. Where the hypothesised numbering was wrong

Stated plainly, because three of these would have produced wrong claims:

- **Stage 7, the checksum, is actually the *last* thing `LoadEverything` does** — after
  the idler (hypothesised 13). It is called at `0x632AB4`, 158 bytes before the function's
  final `ret`. In the real log it costs 10.3 of the 33.8 seconds of app init, which is why
  it is worth knowing it is at the end and not the middle.
- **Stages 8 and 10 are not one thing and not in this function.** `'initialise map'`
  (`0x15CCB40`) and `'Initialising Graphical Map <'` (`0x15CCB50`) are the **graphical**
  map, in `0x634570`, called from the **frontend**, after the checksum and after
  `LoadEverything` has returned. `INIT_MAP_LOGIC` and `'Map Initialized'` are the **map
  logic**, a different thing, inside the database monolith at `0x637774` (`call 0x488200`).
  Putting them adjacent at 8 and 10 reads as one stage split by a database pass; it is two
  unrelated stages 25 seconds apart.
- **Stages 9 and 11 are not after stages 5–7.** The databases run at line 522, before
  `LOAD_EVENTS` (13), the sounds (14), the flags (15), history execute (16), the idler (17)
  and the checksum (18). The hypothesis had them after events, sounds, flags and checksum.
- **The hypothesis was right about the shape it flagged as suspicious.** Two
  technology-database phases with the map built in between is exactly what happens, and
  stages 9/10/11 really are one interleaved run — just all inside a single function.
- **Six stages are missing from the table entirely:** `Initialise Defines` (267),
  `App Init` (274), `Cursors Defines` (299), `Sound...` (327), the *second*
  `Initialise Graphics<` at 450 (distinct from `Initialise Graphics...` at 376), and
  `Loading GUI <` (515). Plus, inside the database stage, `country database <` (1134),
  `final pass of databases <` (1226) and `Loading History Database <` (1261).

## 5. The database stage is one function, and it is three stages

`0x6348F0` (rva `0x2348F0`) is recorded as `LoadCommonFiles`, "works out which
`common/*.txt` to read and reads them". That describes its **first eighth**. The whole
function, in order:

```
0x6348F0  prologue; 0x63490E call 0xB98920
0x634A34..0x6354A1   build 24 local std::strings, one per common/ file name
0x63552F..0x6365A8   for each of 2 search directories, for each of the 24 names:
                       path = <dir> + name ; if FileExists(path) then
                       <per-file resolved-path slot> = path     ; the mod's copy wins
0x6365D0  progress LOADING_DATABASES
0x6366DC  line  917  'Used RAM before databases loaded ['
0x636779  0x456E00, 0x45D4A0, InitMissionEfficiencyModifiers 0x583810
0x636828  ideologies.txt ... 0x63725B line 1000 'GovernmentDatabase Initialized'
0x637343  interface/messagetypes.txt and messagetypes_custom.txt
0x63750D  line 1042 'Loading Databases <'            <-- phase 1 timer ends
0x6375DC  line 1045 'Used RAM before Map Logics ['
0x637662  progress INIT_MAP_LOGIC
0x637774  call 0x488200                              <-- ALL of the map logic
0x6377BB  line 1056 'Map Initialized'
0x637853  progress LOADING_DATABASES2
0x6379A5  combined_arms.txt + unit_upgrades.txt -> CSubUnitDataBase
0x637B09  line 1069 'CSubUnitDataBase  Initialized'
0x637BA3  call 0x540D00 ; 0x637BA9 call 0x540E90      <-- technology phase 2
0x637BED  line 1080 'TechnologyDatabase Phase #2 Initialized'
0x637C8B  line 1083 'units&techh database <'
0x637DBF  laws, traits, gainable_traits, combat_tactics
0x638255  call 0x540E60                               <-- technology after-load pass
0x6382C6  countries.txt, country_colors.txt
0x638485  line 1130 'CountryDatabase Initialized' ; 0x638528 line 1134 'country database <'
0x6385C8  call 0x5B0870 -> line 1144 'Historical Models Initialized'
0x6386D6  occupation_policies, strategic_resources, triggered_modifiers, on_actions
0x638C5C  music/*.txt   (the song database)
0x638DDC  cb_types, rebel_types, covert_ops
0x63935B  line 1226 'final pass of databases <'
0x6394F7  scenarios/*.txt -> line 1258 'History Initialized'
0x6398F5  line 1261 'Loading History Database <'
0x639A86  create CCurrentGameState (see section 9)
0x639AF9  call 0x543430 -> faction_aims.txt into CCurrentGameState +0xD08
0x639FDA  ret 4
0x639FF2  catch (file exception) -> 'File exception!'   -> _CxxThrowException
0x63A0C5  catch (...)             -> 'Unknown exception!' -> _CxxThrowException
```

The map logic is **one call**, `0x488200` (rva `0x88200`, extent `0x488200..0x488395`, bare
`ret`). It stores its argument into the global `0x1A85580` (rva `0x1685580`) and allocates
`0x2A94` bytes. Everything `time.log` attributes to `map.cpp` lines 288–636 — generate
colorspace, load mapfiles, generate provinces, bounding boxes, calculate paths, fix naval
distances — happens under it. `likely` for the name `InitMapLogic`; `confirmed` for the
position and the single call site.

**The directory search is a registry, not a constant.** A global at `0x1A85558` (rva
`0x1685558`, already referenced in `project.json`'s `CCountry::LoadOobFile` comment as
`[0x1685558 + 0x50]`) holds the search directories as `std::string` fields and a count at
`+0x70`. The `common/` loop reads `+0x278` and `+0x2CC`; technology phase 2 reads `+0x358`
and `+0x1B4`. `confirmed` that those fields are read; **which directory each field holds is
inferred** from what the loader then does with it.

## 6. The two technology phases, and what each one actually does

This was the headline question. The answer is sharper than "two passes over one file".

| | phase 1 | phase 2 |
| --- | --- | --- |
| singleton | `0x540D00` (rva `0x140D00`) | the same |
| worker | `0x541BC0` (rva `0x141BC0`), extent `0x541BC0..0x542519`, `ret 4` | `0x540E90` (rva `0x140E90`), extent `0x540E90..0x541BBB`, `ret 4` |
| call site | `0x6369B2`, `mov ecx, eax; push esi` → `__thiscall(this, CParseContext*)` | `0x637BA9`, `push eax` → **one stack argument, the database, and no parse context at all** |
| input | **`common/technology.txt`**, resolved into the per-file slot `[ebp-0x778]` | **every `.txt` in the `technologies/` directory**, enumerated itself |
| what it builds | mentions `CNullTechnologyFolder` (`0x541E36`) and `CNullTechnologyCategory` (`0x542214`) — **the folder/category skeleton** | mentions `CNullTechnology` (`0x54140C`), pushes `'notech'` (`0x5413FA`), and logs `'TECHNOLOGIES loaded '` through `technology.cpp` — **the technologies themselves** |
| when | line 943, before the map | line 1080, **after** the map logic *and* after `CSubUnitDataBase` is built |

Phase 2 does its own directory work, which is the decisive evidence that it is not a second
pass over the same file:

```
0x00540F30   eax = [0x1A85558]; eax += 0x358        ; search directory A
0x00540F5A   call 0x401BD0                          ; std::string::assign
0x00540F67   ecx = [0x1A85558]; ecx += 0x1B4        ; search directory B
0x00540F93   call 0x401BD0
0x00540FA6   edi = [0x1A85558 + 0x70]               ; how many directories
0x00540FCD   push '.txt'; call 0xA6BCB0             ; list A's *.txt
0x00541027   push '.txt'; call 0xA6BCB0             ; list B's *.txt
0x00541091   call 0x794A40                          ; merge
0x00541568   call 0xA69990                          ; Tokenizer over each path
0x00541834   'TECHNOLOGIES loaded '                 ; technology.cpp
```

Oracle check: the mod has `%USERPROFILE%\GitHub\BlackICE\technologies\` with ~30 `.txt`
files (`01_Infantry Technologies.txt`, `Jet Technologies.txt`, …) and
`%USERPROFILE%\GitHub\BlackICE\common\technology.txt` alongside. The split matches exactly.
`confirmed`.

**What this means for load order, and it is the point of the exercise.** A technology can
only be built after the sub-unit definitions exist, because its effects name them: phase 2
runs immediately after `CSubUnitDataBase` is loaded from `combined_arms.txt` and
`unit_upgrades.txt`, and after the map logic. So:

- Anything a `technologies/*.txt` file references **must be declared in `common/`**, in the
  files parsed before line 1069 — and `laws.txt`, `traits.txt`, `gainable_traits.txt`,
  `combat_tactics.txt`, `countries.txt`, `occupation_policies.txt`,
  `strategic_resources.txt`, `triggered_modifiers.txt`, `on_actions.txt`, `cb_types.txt`,
  `rebel_types.txt` and `covert_ops.txt` are **all parsed after it**. A technology effect
  naming a law, a trait, a strategic resource or an occupation policy is resolving a name
  the engine has not read yet. Combined with the fact the engine returns **index 0, the
  null object**, for a name it cannot find (`FINDINGS-script.md`), that is a silent
  misresolution, not an error.
- `common/technology.txt`'s folders and categories, by contrast, are available to
  everything.
- There is a third technology call: `0x540E60` (rva `0x140E60`, extent
  `0x540E60..0x540E8C`, `ret 4`) at `0x638255`, after `combat_tactics.txt` and before
  `countries.txt`. Its whole body walks the database's first vector (`[db+0]..[db+4]`,
  4-byte elements) and calls **virtual slot 6** on every element. An after-load fix-up over
  all technologies. `likely`.

I have **not** established which keys phase 2 resolves against which database, i.e. exactly
which technology effects are exposed to the ordering problem above. That is the next step
and it is `CTechnology::LoadKey`, not this file.

## 7. Every `common/` file and the loader that consumes it — closing `CLASSES.md:1413`

The dispatch is not a table. **Each file gets its own local `std::string` for its resolved
path**, written by the selection loop and handed to the `Tokenizer` in that database's
block. The stack slot is the link, by instruction:

```
; selection loop, per file, per directory
0x0063615E   mov edx, 0x15CCCC8          ; '/ideologies.txt'
0x00636169   call 0xA5A7A0               ; std::string(name)
0x0063617E   call 0xA5B0D0               ; <dir> + name
0x00636187   lea ecx, [ebp - 0x60c]      ; <-- ideologies.txt's own slot
0x00636191   call 0x401BD0               ; assign
...
; the Ideology database's block
0x006367F2   lea ecx, [ebp - 0x60c]      ; <-- the same slot
0x006367FB   call 0xA69990               ; Tokenizer::Tokenizer(path)
0x00636816   call 0xA7A460               ; CParseContext::CParseContext
0x00636828   call 0x527280               ; GetIdeologies  (the singleton)
0x0063682F   call 0x527470               ; the loader (db, context)
```

The 24 slots, and the loader each is given. Parse order is reading order; "VA" columns are
virtual.

| # | file | resolved-path slot | singleton | loader | `ret` |
| --- | --- | --- | --- | --- | --- |
| 1 | `ideologies.txt` | `[ebp-0x60c]` | `0x527280` **GetIdeologies** | `0x527470` | 8 |
| 2 | `technology.txt` | `[ebp-0x778]` | `0x540D00` | `0x541BC0` (phase 1) | 4 |
| 3 | `static_modifiers.txt` | `[ebp-0x740]` | `0x45A380` | `0x45A490` | 8 |
| 4 | `event_modifiers.txt` | `[ebp-0x708]` | `0x45A380` | `0x45A490` (same loader, 2nd call) | 8 |
| 5 | `minister_types.txt` | `[ebp-0x4f4]` | `0x52B140` **GetMinisterTypes** | `0x52B1A0` | 8 |
| 6 | `government_positions.txt` | `[ebp-0x724]` | `0x52BA30` **GetGovernmentPositions** | `0x52BA90` | 8 |
| 7 | `buildings.txt` | `[ebp-0x6d0]` | `0x4B7580` | `0x4B75E0` | 8 |
| 8 | `governments.txt` | `[ebp-0x698]` | `0x525410` | `0x525470` | 8 |
| — | `interface/messagetypes.txt` | `[ebp-0xf50]` | `0x698E80` **GetMessageHandler** | `0x698EE0` | 8 |
| — | `messagetypes_custom.txt` | a local | `0x698E80` | `0x698EE0` | 8 |
| 9 | `combined_arms.txt` | `[ebp-0x644]` | `0x5ADE80` **CSubUnitDataBase::GetInstance** | `0x5AE1C0` | 0xC |
| 10 | `unit_upgrades.txt` | `[ebp-0x510]` | same | same call, both contexts | 0xC |
| — | `technologies/*.txt` | enumerated | `0x540D00` | `0x540E90` (phase 2) | 4 |
| 11 | `laws.txt` | `[ebp-0x6b4]` | `0x5298C0` **GetLawDataBase** | `0x529B20` | 8 |
| 12 | `traits.txt` | `[ebp-0x5d4]` | `0x5B4640` **CTrait::database** | `0x5B46B0` | 8 |
| 13 | `gainable_traits.txt` | `[ebp-0x75c]` | `0x473930` **CGainableTraitDataBase::instance** | `0x473C70` | 8 |
| 14 | `combat_tactics.txt` | `[ebp-0x59c]` | `0x439DA0` | `0x439E10` | 8 |
| 15 | `countries.txt` | `[ebp-0x660]` | `g_CCountryDataBase 0x1A855A4`, created inline as `new(0x57C)` + `0x4024D0` | `0x515CC0` **CCountryDataBase::AddCountry** | 8 |
| 16 | `country_colors.txt` | `[ebp-0x628]` | same global | `0x518200` | 8 |
| 17 | `occupation_policies.txt` | `[ebp-0x67c]` | `0x52D040` | `0x52D0A0` | 8 |
| 18 | `strategic_resources.txt` | `[ebp-0x564]` | `0x460B90` | `0x460BF0` | 8 |
| 19 | `triggered_modifiers.txt` | `[ebp-0x5f0]` | `0x45BCD0` | `0x45BD90` | 8 |
| 20 | `on_actions.txt` | `[ebp-0x5b8]` | `0x9C7EB0` | `0x9C7F80` | 8 |
| — | `music/*.txt` | `[ebp-0xb6c]` | `0x45CA60` | `0x45CB60` (builds `CSong`) | 8 |
| 21 | `cb_types.txt` | `[ebp-0x6ec]` | `0x416A40` | `0x416AA0` | 8 |
| 22 | `rebel_types.txt` | `[ebp-0x580]` | `0x4BFE70` **GetRebelTypeDatabase** | `0x4BFED0` | 8 |
| 23 | `covert_ops.txt` | `[ebp-0x52c]` | `0x444E80` | `0x444EE0` | 8 |
| — | `scenarios/*.txt` | `[ebp-0xbdc]` | — | `0x45E720`/`0x45E5D0`/`0x45F380` | — |
| 24 | `faction_aims.txt` | `[ebp-0x548]` | `g_CCurrentGameState` | `0x543430`, into `+0xD08` | 8 |

Except for technology phase 1 (`__thiscall`, `mov ecx, eax; push ctx`), **every loader is
`loader(database, CParseContext*)` with `ret 8`**, called as `call <singleton>; push ctx;
push eax; call <loader>`, and `CSubUnitDataBase`'s takes three (`ret 0xC`):

```
0x00637A70   call 0x5ADE80                 ; CSubUnitDataBase::GetInstance -> eax
0x00637A75   mov edx, [ebp - 0x1c]         ; the combined_arms.txt context
0x00637A78   push edx
0x00637A79   push esi                      ; the unit_upgrades.txt context
0x00637A7A   push eax
0x00637A7B   call 0x5AE1C0
```

**The positive control, which is what makes me confident in the whole table.** Nine of the
singletons were **already named in `project.json` from unrelated work** — `GetIdeologies`,
`GetMinisterTypes`, `GetGovernmentPositions`, `GetMessageHandler`,
`CSubUnitDataBase::GetInstance`, `GetLawDataBase`, `CTrait::database`,
`CGainableTraitDataBase::instance`, `GetRebelTypeDatabase` — and **every one of the nine
pairs with the file its name predicts**. Nine for nine, from a method that knew nothing
about the names. Two more agree a second way: `0x4BFE70`/`0x4BFED0` is a known abutting pair
in `TRAPS.md` trap 2, and here they are precisely the accessor/loader pair for
`rebel_types.txt`; and `0x4024D0` is recorded as `CCountryDataBase::CCountryDataBase`
"takes the freshly allocated `0x57C` bytes", which is exactly the `push 0x57c` at
`0x6382FC`.

And the mod on disk is the other oracle: all 24 names exist in
`%USERPROFILE%\GitHub\BlackICE\common\`. Two files in that folder are **not** in the
engine's list at all — `combat_events.txt` and `cot_colors.txt`. `cot_colors.txt` is an EU3
leftover (centre of trade). Neither is read by this stage. I did not search the rest of the
image for them, so this is **not** a claim that nothing reads them.

Three `common/`-folder things are loaded elsewhere, not here: `graphicalculturetype.txt` and
`bookmarks.txt` at the very top of `LoadEverything` (`0x62FBDA` onward), `defines.lua` by
`LoadDefines` at line 267, and `common/countries/*` by `countries.txt`'s own loader.

## 8. The checksum, and what it covers

`0x632DA0` logs at lines 759–761 and its file list is the `.rdata` run from `0x15CC9A0`:

```
common/countries   units/models   units/country   /country
history/countries  history/diplomacy  history/provinces  history/wars
history/leaders    history/units      /units
map/default.map    map/cache/time     map/cache/adjacencies.bin
/default.map       /cache/time        /cache/adjacencies.bin
/cgm               /battleplans
```

Then `'Creating checksum for all files took '`, `'Checksum is '`, and
`'Testversion 4(settings)'`. This is the multiplayer desync hash: it covers the content that
must match between clients and deliberately does not cover `common/*.txt` as files, the
graphics or the localisation. `confirmed` for the list; **`inferred` for "multiplayer"** —
nothing in this function says MP, the reading comes from what is and is not in the list.

## 9. Where `CCurrentGameState` is created — and why `current() != 0` at the main menu

At the tail of the database stage, after the history database:

```
0x00639A5F   cmp [0x1A89790], ebx          ; g_CCurrentGameState already there?
0x00639A65   jne 0x639AEB                  ; then keep it
0x00639A6B   push 0xDA8
0x00639A70   call 0xB9602F                 ; operator new
0x00639A86   call 0x67D070                 ; CGameState::CGameState
0x00639A8B   mov [esi], 0x15CF674          ; the CCurrentGameState vftable
0x00639A91   mov word [esi + 0xD9C], 0
0x00639A9A   mov [esi + 0xDA0], ebx
0x00639AA0   mov byte [esi + 0xDA4], 0     ; in_game = 0
0x00639AD3   mov [0x1A89790], esi          ; publish; the old one is released above
0x00639AEB   ecx = [0x1A89790]
0x00639AF1   eax = [ecx + 0xD08]           ; victory_conditions
0x00639AF9   push edi (the faction_aims.txt context); push eax; call 0x543430
```

Every constant matches `BiceLib/GameClasses/CCurrentGameState.hpp` exactly: `GLOBAL_POINTER
= 0x1689790`, `Vftables::CCurrentGameState = 0x11CF674`, size `0xDA8`,
`Offsets::in_game = 0xDA4`, `Offsets::victory_conditions = 0xD08`. So this is the creation
site, `confirmed`, and it is **inside startup's database stage** — long before any session.
That is the mechanism behind the bug `CLAUDE.md` records: `CCurrentGameState::current() != 0`
is true at the main menu because the object was built here, at `0x639A86`, with `in_game`
deliberately zeroed on the next line.

It also adds evidence for `+0xD08 = victory_conditions`, which was recorded from
`CGameState::SaveContents`: **`common/faction_aims.txt` is parsed into it at startup**, by
`0x543430` (rva `0x143430`, extent `0x543430..0x543AA2`, `ret 8`). Two independent readings,
the save key and the file, converge.

## 10. The memory measurement, as a mechanism

Two mechanisms, both worth knowing because they are the engine's own instrumentation of
where the memory goes and they cost nothing to read.

**RAM.** `GetCurrentProcess` (`[0xD2B174]`) then `GetProcessMemoryInfo` (`[0xD2B264]`,
`PSAPI.DLL`) with `push 0x28` — a 40-byte `PROCESS_MEMORY_COUNTERS` — taken twice into two
stack buffers, and the printed number is the **difference of the field at `+0xC`**, which is
`WorkingSetSize`. Printed as `'<label>[' <n> ' KB]'`, so it is a delta in kilobytes of
working set, not a total. Sites in startup: lines 325, 373, 384, 444, 454, 510, 518, 917,
1045, plus `main.cpp:422` and `521`.

**A float variant.** Later sites call `0xAB3C50` and convert with `_ftol2_sse`
(`0xC08870`) instead — `'Used RAM before databases loaded ['` and `'Used RAM before Map
Logics ['` both do. `0xAB3C50` returns a float; `likely` that it is a cheaper RAM query on
the graphics object, **not established**.

**Video memory.** The `'Used video memory before …'` family lives in `provincemanager.cpp`
and `bordermanager.cpp` (strings `0x15E22A8` onward: `World is created`, `CreateBorders()`,
`CreateProvinceTexts()`, `CreateProvinceTrees()`, `CreateRivers()`, `CreateMesh()`, `waves`,
and `alt tab` at `0x15FD6A4`), together with a `[RAM usage]` family for the same steps.
Those are the frontend's world build, i.e. the second half of `0x634570`. I did not read
their mechanism; the assignment said not to chase the numbers.

## 11. Corrections to the existing record

These are for you to apply; I have not redefined anything the pipeline would refuse.

1. **`0x2348F0` is recorded as `LoadCommonFiles` and the comment describes one eighth of
   it.** The function is `0x6348F0..0x63A185`, `ret 4`, and it also contains the map-logic
   call, both technology phases, the historical models, `music/*.txt`, `scenarios/*.txt`,
   the history database, the creation of `CCurrentGameState` and `faction_aims.txt`. Suggest
   renaming to `CEU3Application::LoadDatabases` and replacing the comment. Signature:
   `void __stdcall CEU3Application::LoadDatabases(CEU3Application* app)`.
2. **`0x127470` is recorded as `LoadCommonFileContents`, "the driver `LoadCommonFiles` calls
   once a `CParseContext` is built".** It is not a driver: it has **exactly one caller**
   (`0x63682F`) and is `CIdeologyDataBase`'s own file reader — there are 23 siblings with
   the same shape, each with one caller. Its body does mention `CNullFaction`, which is worth
   a second look. Suggest renaming to `LoadIdeologies` or `CIdeologyDataBase::LoadFile`.
   **This is trap 14's "a name that fits one reader may not fit twelve", with twelve
   replaced by twenty-four.**
3. **`CLASSES.md`'s `common/` list is in the wrong order for its own caption.** It says "in
   the order they are loaded" and gives the `.rdata` order (technology first, ideologies
   sixteenth). That is the order the **name strings are constructed**. The order they are
   **parsed** is section 7's table — `ideologies.txt` **first**, `faction_aims.txt`
   **last of all, after the history database**. There is also a third order, the `FileExists`
   resolution loop, in which `covert_ops.txt` moves from 24th to 11th; that one is a compiler
   scheduling artefact and means nothing.
4. **`CLASSES.md`'s startup paragraph has the order wrong for the same reason**: it puts the
   databases after the `.gui` files (right) but then `LOAD_EVENTS`, the sound effects, the
   flags, history and the idler after them (right) — and omits the checksum, which is last,
   and the graphical map, which is in the frontend. Its "What is not established: how a
   given file is matched to the class it fills" is now closed.
5. **New abutting-function pairs for `TRAPS.md` trap 2**, every one a database accessor
   followed immediately by its loader with no padding: `0x4B7580`/`0x4B75E0`,
   `0x525410`/`0x525470`, `0x52D040`/`0x52D0A0`, `0x460B90`/`0x460BF0`,
   `0x416A40`/`0x416AA0`, `0x444E80`/`0x444EE0`. `functionStart` on any loader in that list
   answers the accessor, and the whole section-7 table would have come out shifted by one
   function if I had trusted it.
6. **`functionStart` false positives from a `0xCC` byte inside an instruction.** Inside
   `0x6348F0` there are 61 single `0xCC` bytes, all of them displacement or immediate bytes,
   and `functionStart(0x637853)` answers `0x637339` because of the one at `0x637338`. Trap 2
   names the prologue-set cause; this is a different cause with the same symptom, and the
   cure is the same: `retsBefore` returned `[]`, which said immediately that `0x637339` was
   not a boundary.
7. **`0x67D070` is recorded as `CGameState::CGameState` and has 2,773 direct callers.** The
   vftable it writes, `0x15CF674`, really is `CGameState`'s per RTTI, so the name is not
   wrong — but 2,773 constructions of a game state wants an explanation before anybody leans
   on it. Flagging, not claiming.

## 12. What is not established

- **The entry of `main`.** The function holding all eighteen `main.cpp` log sites exits
  `ret 0x10` at `0xA5A2E5`; `functionStart` answers `0xA58B9F`, not an instruction boundary,
  and `0xA570A0` (after the previous `ret 0x10`) does not decode as a prologue. *What would
  settle it:* decode forward from the CRT entry point in the PE header, or find the
  `_tWinMain` thunk — one of the two will land on the real prologue.
- **How `CFrontEnd` slot 3 is reached.** `main.cpp:601` calls `0xA90F90` and the live log
  puts `frontend.cpp:423` next, so the order is settled; the call chain is not. *What would
  settle it:* trace `0xA90F90` and look for a `call [reg+0xC]`.
- **Stages 2, 5, 10 and 16's interiors** — `0xA90D70` (`App Init`), the sound chain, the
  second `Initialise Graphics<`, and `history execute` (which makes three `CGameState`s).
  *What would settle it:* `logsites.py` on each, since each almost certainly narrates itself
  the same way.
- **Which technology keys phase 2 resolves against a database that has not been read yet.**
  This is the one that matters for the mod and it is the obvious next job. *What would settle
  it:* read `CTechnology::LoadKey` with the `SaveToken` enum applied, and list the keys whose
  handlers call a name lookup; cross against section 7's parse order.
- **Which search directory each `[0x1685558 + N]` field is.** I established that `+0x278`,
  `+0x2CC`, `+0x358`, `+0x1B4` are read and `+0x70` is a count. *What would settle it:*
  find the registry's initialiser — `findValue(0x1A85558)` and look for the writer.
- **`0x45E720`, `0x45E5D0`, `0x45F380`** (the `scenarios/*.txt` readers) and
  **`0x9C5590`, `0x9C6650`, `0x998BD0`, `0x998E30`** (between the casus belli types and the
  rebel types). Not traced.
- **`0x640600`/`0x640950`**, what `0x634570` news and builds, and `0x4924E0`, what it cleans
  up afterwards. The `provincemanager.cpp` and `bordermanager.cpp` timings come from under
  them.
- **Whether `combat_events.txt` and `cot_colors.txt` are read anywhere.** I established only
  that **this stage does not read them**, which is a negative with no positive control
  behind it — the control would be to run the same `findBytes` search for a filename this
  stage *does* read, e.g. `'/laws.txt'`, and check the search finds its one site. Do that
  before calling either file dead.
- **The GUI stage's interior** (`0x67D740` and the `.gui` parse), deliberately left alone —
  another agent owns it. All I claim is the function and the position.

## 13. Everything I propose, in one list

`addresses`, functions: `0x232DA0 CEU3Application::CreateChecksum`,
`0x234570 CEU3Application::InitialiseGraphicalMap`, `0x2EEF00 CFrontEnd::Enter` (likely),
`0x23A190 LoadSoundEffects` (likely), `0x440BC0 LoadFlags` (likely),
`0x440680 InitialiseGraphics` (likely), `0x131DB0 LoadMapSprites` (likely),
`0x5C0430 LoadEvents` (likely), `0x27D740 InitialiseGui` (likely),
`0x88200 InitMapLogic` (likely), `0x66BCB0 ListFilesWithExtension` (likely),
`0x140D00 GetTechnologyDataBase`, `0x141BC0 CTechnologyDataBase::LoadTechnologyFile`,
`0x140E90 CTechnologyDataBase::LoadTechnologies`,
`0x140E60 CTechnologyDataBase::AfterLoadAll` (likely), `0x5A380 GetModifierDataBase`
(likely), `0x5A490 LoadModifierDefinitions`, `0x12B1A0 LoadMinisterTypes`,
`0x12BA90 LoadGovernmentPositions`, `0xB7580 GetBuildingDataBase`, `0xB75E0 LoadBuildings`,
`0x125410 GetGovernmentDataBase`, `0x125470 LoadGovernments`, `0x298EE0 LoadMessageTypes`,
`0x1AE1C0 CSubUnitDataBase::LoadDefinitions`,
`0x1B0870 CSubUnitDataBase::BuildHistoricalModels`, `0x129B20 LoadLaws`,
`0x1B46B0 LoadTraits`, `0x73C70 LoadGainableTraits`, `0x39DA0 GetCombatTactics`,
`0x39E10 LoadCombatTactics`, `0x118200 LoadCountryColors`, `0x12D040 GetOccupationPolicies`,
`0x12D0A0 LoadOccupationPolicies`, `0x60B90 GetStrategicResources`,
`0x60BF0 LoadStrategicResources`, `0x5BCD0 GetTriggeredModifiers`,
`0x5BD90 LoadTriggeredModifiers`, `0x5C7EB0 GetOnActions`, `0x5C7F80 LoadOnActions`,
`0x5CA60 GetSongDataBase` (likely), `0x5CB60 LoadSongs`, `0x16A40 GetCasusBelliTypes`,
`0x16AA0 LoadCasusBelliTypes`, `0xBFED0 LoadRebelTypes`, `0x44E80 GetCovertOperations`,
`0x44EE0 LoadCovertOperations`, `0x143430 LoadFactionAims`.

`addresses`, globals: `0x1687B78 g_CTechnologyDataBase`, `0x1685580 g_MapLogic` (likely).

`fields`: none new — `CCurrentGameState +0xD08` and `+0xDA4` are already right and this
work adds evidence for both rather than changing them.

Corrections for you to apply, not redefined by me: the seven items in section 11.
