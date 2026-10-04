# Three settlements: the startup reset's second half, `ResetGameStateToStartDate`'s name, and what sits at `CInGameIdler +0x1790`

Read out of `hoi3_tfh.exe` on 2026-10-02, **statically only** — no game was running and nothing below is `[live]` except where it cites an observation already in the record. Addresses are given as **VA** with the rva beside them; `VA = RVA + 0x400000` (trap 1). Only valid for this build.

**In one line.** `0x27B240` is read end to end and its last 0x560 bytes are not a reset at all — they build a path and **parse `gameplaysettings.txt` into the game state through `CPersistent::Load`**, which makes a mod's `mod/<mod>/gameplaysettings.txt` a startup hook nothing in the record knew about; it changes nothing about the `in_game` window, because it runs once, at startup, before the first screen exists. `ResetGameStateToStartDate` keeps its name and the reading that produced it survives re-derivation, with one over-claim removed. And `CInGameIdler +0x1790` is the `CEU3Application`: the chain is complete in the bytes, the string `SessionManager` does not occur anywhere in the image, and the rename is machine-checkable — it turns a twice-skipped `checkSignatures` entry into one that is checked and passes.

---

## 1. `0x27B240`: the whole function, and it is not only a reset

**Extent, re-derived.** Entry `0x67B240` (rva `0x27B240`); `image.retsBefore(0x67B240, 0x67BB00)` returns **exactly one** `ret`, `(0x67BAE6, '4')`; the bytes there are `c2 04 00` then **seven** `int3` then `55 8b ec 83 e4` — a fresh prologue, which is `CGameState::ResetSession` at `0x67BAF0`. So the last byte is `0x67BAE8` and the size is `0x8A9` = **2217** bytes, 586 instructions by `cfg.py`, one stack argument. Neither trap 2 nor trap 3 applies. (The brief said 2214 bytes, i.e. `0x27BAE6 − 0x27B240`, which is the entry-to-`ret` distance rather than the size; the record's own comment says 2217 and is right.)

**One caller, confirmed by a sweep.** `findRefs.py --callers 0x67B240` reports one direct call, `0x63286D`. An `int3`-run scan over `0x62F000..0x633000` puts the padding boundaries at `0x62FAC0` and `0x632CE6`, so `CEU3Application::LoadEverything` is one padded block `0x62FAC0..0x632CE6` (0x3226 bytes) and **both** `0x63286D` and the first `CFrontEnd` construction at `0x6329DE` are inside it, in that order. `image.functionStart` answers `None` for both — the function is longer than its `0x2500` limit — and `retsBefore(0x62FAC0, 0x632B00)` returns a bare `ret` at `0x630C97`, which is trap 3 inside `LoadEverything`, not a boundary. **The padding scan is what settles it; `functionStart` cannot.**

**The body, in order.** The first four steps were not in the record at all.

| at | what |
| --- | --- |
| `0x67B268` | get-or-create the 4-byte factory at `[0x174DA90]`, vftable `0x15FDF60` — the same lazy object `Random` (rva `0x6A2F80`) makes |
| `0x67B299` | `state->+0xF0 = factory->slot1()`. Slot 1 is `0xA803C0`: `new(4)`, write vftable `0x15FDCFC`, return it. Then slot 1 **of that** is called — `0x15FDCFC` slot 1 is `0xABF890`, the 1691-holder empty stub (trap 4), so that call does nothing |
| `0x67B2C0` | inlined get-or-create of `g_CCurrentGameState` — dead, it exists from the database stage |
| `0x67B33B`–`0x67B3C1` | walk `state->countries_begin (+0xBBC)`, take each country's **tag (`CCountry +0xCA4`)**, `strlen` it and assign it into a local `std::vector<Hoi3CString>` |
| `0x67B3C3`–`0x67B3FB` | zero a 0x10-byte temp, `0x4148B0(&temp@EAX, &tags)` to fill it from the vector, then `0x5F3640(state->income_statistics (+0xC6C), temp)` — **and `0x5F3640` ends `ret 0x14`**, which is the thing that identifies the 0x10-byte temp as a by-value second argument rather than a discarded local. So the statistics series are re-keyed by country tag |
| `0x67B400` | `if (state->+0xCEC != 0) goto 0x67B581` — the next block is conditional |
| `0x67B40C`–`0x67B57C` | rebuild the singly-linked list at `state->+0xCE8`, count `+0xCEC`, tail `+0xCE4`. One 0x10-byte node `{value, next, 0, 0}` per element of the vector at `+0x1C` of the global at `[0x1A878BC]` (0x40 bytes, ctor `0x5272E0`) whose **virtual slot 6** returns true; the value is that element's `+0x54`, or, when null, the **`CNullFaction`** singleton at `[0x1A855A8]` (built with `0x5224B0` and given vftable `0x15C248C`, which the RTTI export names `CNullFaction`) |
| `0x67B58D`–`0x67B59F` | clear `in_game_screen (+0xBE8)`, `loaded_from_save (+0xD9C)`, **`in_game (+0xDA4)`** and `tutorial_id (+0xDA0)` |
| `0x67B5A5` | `CGameState_SetProvincesAndSizePerCountryVectors(state, [0x1A8557C]+0x2200)` |
| `0x67B5AA`–`0x67B5ED` | get-or-create the 0x57C-byte **`CCountryDataBase`** at `[0x1A855A4]` with `CCountryDataBase::CCountryDataBase` (`0x4024D0`), then `0x67E550(state, &db->+0x16C)` |
| `0x67B5F3` | **`CGameState::ResetSession (0x67BAF0)`** |
| `0x67B5FF` | `0x68A6E0([0x1A8557C])` — which parses `<...>/colors.txt` (three references to `'/colors.txt'` and one to `'UNNAMED_SESSION'`) |
| `0x67B604`–`0x67BA69` | the `gameplaysettings.txt` block — see below |
| `0x67BA8F`–`0x67BACF` | free the tag vector, 0x1C stride, the stride confirming the element is a `Hoi3CString` |

`0x67E550(state, countryArray)` is worth a line of its own: it clears `state->played_countries (+0xBCC/+0xBD0)` and `state->countries (+0xBBC/+0xBC0)` to empty, resizes **both** to `n = (db_end − db_begin)/4` through `0x84AFB0`, copies every `CCountry*` from the database array into `state->countries[i]` and writes 0 into `state->played_countries[i]`, then truncates the 0xA0-element vector at `+0xD40/+0xD44` and calls the state's own virtual slot 6. So this is where the game state's country list comes from, and it is the database's, not the save's. `ret 8`, two stack arguments; **not named here** — it is on the frontier.

**The `gameplaysettings.txt` block, which is the news.**

```
0x67B606  assign  'gameplaysettings.txt'                 ; the image's ONLY reference to it
0x67B694  0x40C600(settings@[0x1A863F8], out@ESI)        ; the mod folder name as a string
0x67B699  cmp [eax+0x10], 0 ; setne [esp+0x13]           ; is the mod name non-empty?
   when it is:
0x67B770    'mod/' + <mod>                               ; std::string::operatorPlusChars
0x67B78E    ... + '/'                                    ; operatorPlus, the 1-char string 0x15B5180
0x67B7A9    ... + 'gameplaysettings.txt'                 ; operatorPlus
0x67B7BE    assignString -> replaces the path            ; so the game-root copy is NOT read
0x67B8B3  FileExists(path)        (0x784A20, already named)
   when it exists:
0x67B8C8  new(0x360) ; inlined CParseContext::CParseContext  - vftable 0x15FD93C, name
          'UNNAMED_SESSION' at +0x32C, +0x358 = 1, tokenizer at +0x1C
0x67B91B  new(0x114) ; inlined Tokenizer::Tokenizer       - vftable 0x15FD1F0 then 0x15FD1FC
0x67BA57  call [[state]+0xC]     ; VIRTUAL SLOT 3 = CPersistent::Load
0x67BA69  release the CParseContext through slot 0 with 1
```

Both constructors are inlined copies of functions the record already holds: `CParseContext::CParseContext` (rva `0x67A460`), whose comment gives vftable `0x11FD93C` as an rva — `0x15FD93C` as a VA, exactly the table written here — with the tokenizer at `+0x1C`, `+0x358 = 1` and the name assigned into `+0x32C`, field for field; and `Tokenizer::Tokenizer` (rva `0x669990`, VA `0xA69990`), recorded as 0x114 bytes with vftable `0x11FD1FC` (rva) = `0x15FD1FC` (VA), which is the table written at `0x67B9AD`. Virtual slot 3 was read straight out of `CCurrentGameState`'s vftable: `0x15CF674` slot 3 is `0xA7C050`, which the record has as `CPersistent::Load` at slot 3 of 748 classes.

**So: `gameplaysettings.txt` is parsed into the global game state at startup, by `CGameState::LoadKey`, and when a mod is active only the mod's copy is looked for.** Neither file exists in this install (`$USERPROFILE/Hearts of Iron 3/` has no `gameplaysettings.txt`, nor does any folder under `mod/`), so the block is skipped here and nothing in BlackICE's behaviour depends on it today. It is a live, unused hook: anything `CGameState::LoadKey` accepts can be set from a file in the mod folder before the first screen appears. **Section 7 says what that is, and why "before the first screen appears" is the sentence that limits it** - the two values the file's own `gameplaysettings` block can reach are both written again from the lobby afterwards. `confirmed` for the parse chain and for the single string reference; `likely` for "only the mod's copy", which rests on reading `[eax+0x10]` as the mod string's length — the displacement fits `Hoi3CString`'s `size` field, and the capacity test four bytes along at `+0x14` is what the function's own `cmp [esp+0x64], 0x10` guards use.

**Proposed name: `CGameState_StartupResetAndLoadGameplaySettings`** (rva `0x27B240`), signature unchanged (`void __stdcall ...(CGameState* state)`, `ret 4`). The old name described the one call site, and its own comment said so.

## 2. What it implies for `in_game`, and for `movedInPlay()` — nothing changes

`0x27B240` runs **once per process**, at `LoadEverything`'s `history execute` stage, and `LoadEverything` builds the first `CFrontEnd` *later in the same function*, at `0x6329DE`. So when its clear at `0x67B599` executes there is no screen object in the process at all and `in_game` is already 0 — the write is belt-and-braces, as is its clear of `in_game_screen (+0xBE8)`, the field `CFrontEnd::CFrontEnd` will fill 0x170 bytes later.

The full life of the byte, now closed on both ends:

| | |
| --- | --- |
| `0x67B146` / the 2772 inline copies | construction — the object did not exist |
| `0x67B599` | **this function**, once, at startup, before any screen |
| `0x6ED9AF` | `CFrontEnd::CFrontEnd` |
| `0x6EFE58` | `CFrontEnd::Enter` |
| `0x65D126` | `CInGameIdler::Enter` — **the only write of a one in the image** |
| `0x662337` | `CInGameIdler::Leave` |

**`Gui::Lua::sessionActive()` and `GameClock::movedInPlay()` both stand.** Nothing read here contradicts `FINDINGS-session.md` section 4 or `CLAUDE.md`: the window `movedInPlay()` excludes is still the tail of `CInGameIdler::Enter`, and `in_game` is still 0 for the whole of a load. The one thing this adds is that `CGameState::ResetSession` is reached at startup from here, which makes its three callers a complete set with no overlap: this one (once, before any session), the savegame loader (from the lobby or the tutorial screen, `in_game` 0), and `ResetGameStateToStartDate` (the deferred exit path, which `FINDINGS-resetpath.md` already settled).

## 3. `ResetGameStateToStartDate`: the name holds, and one claim about it should not be made

`FINDINGS-resetpath.md` section 6 had already read this function and withdrawn the "start a game" guess; the brief's description of the record as open was stale. Re-derived independently, everything in the record agrees: `findRefs.py --callers 0x63A460` gives exactly the five sites `0x60BB2A`, `0x65472C`, `0x70D2FD`, `0x7147A7`, `0x71D98E`; `retsBefore` gives the two `ret`s and `0x63A840` is a fresh prologue three `int3` later. **The name is right and the reading is right.** Two additions and one subtraction:

**Added — the fifth call site is the same shape as the second.** `0x60BAF0` (rva `0x20BAF0`) was unidentified. It is a `__thiscall` on a **`CBackEndIdler`** (`this+0xB8` the application, `+0xB0` the gui, `+0xB4` the graphics) and its body is, instruction for instruction, the exit-to-menu branch of `ProcessSessionEndRequests`: `[[app]+0xE4]->slot4(1)`, `ResetGameStateToStartDate(1)`, `[[app]+0xE4]->slot4(0)`, set `gui->+0x238`, walk `gui->+0x5C..+0x60` calling slot 12 on each, `new(0x8B0)`, `CFrontEnd::CFrontEnd(it, graphics, gui, app)`, `app->+0x88 = 1; app->+0xE0 = it`. So it is the **back-end idler's own "return to the main menu"** — the way out of the end-of-game screen — and it is a second ordinary path to the full reset, which matters because `FINDINGS-resetpath.md` section 5 established that `+0x1CDA` is set only by a finished tutorial. `confirmed` from the body; `likely` that this is what an ordinary exit-to-menu uses, because no caller of `0x20BAF0` was traced.

**Added — `0x23A330` is settled.** `0x63A330..0x63A454`, bare `ret`, **no arguments**. It sets **four globals to 1** — `[0x170AF7C]`, `[0x170AF78]`, `[0x170AEB8]`, `[0x170AEBC]` — with two dead copies of the inlined get-or-create between them, and does nothing else. Those four globals have 10, 33, 16 and 20 references; the named readers are `CGameState::LoadKey` (two of them), `CCreateHigherCommand::Execute`, `CreateRebelsForFaction` and `CSubUnit::AfterLoad`. Its two callers are exactly the two places that have just wiped the object graph or are about to overwrite it: `ResetGameStateToStartDate` at `0x63A587` and the savegame loader at `0x67CEAD`. **Proposed name `ResetGlobalIdCounters`, `inferred`** — only a sample of the 79 references was read, and what each counter counts was not established.

**Subtracted — do not use the live tick measurement as confirmation of this function.** `project.json` carries a `[live]` note on `CGameState::ResetSession` and `CGameState::ClearPlayers` that a menu trip left the tick at **60759360**, and `ResetGameStateToStartDate` is the only one of the three resets that writes `+0xBDC` (a per-displacement scan over the three ranges finds `0x63A710` in this one and nothing in the other two). It is tempting to read the measurement as a live confirmation of this function's clock write. **It is not sound.** A full `0xBDC` census over `.text` — 365 raw occurrences, 327 decoded, 24 with the field as the first operand — attributes the game-state writers to `CGameState::CGameState`, `CGameState::LoadKey`, `RunHourlyTick` (an `inc`), `ResetGameStateToStartDate`, `CTutorialScreen::OnTutorialButtonPressed`, and **four unnamed functions in the `0x6F4250..0x6F5500` band**, which is `CFrontEnd` territory and is exactly where a bookmark's start date would be written. Returning to the menu runs `CFrontEnd::Enter`, so either explanation fits the observation. The arithmetic is at least clean: `43800000 + 1936 × 365 × 24 = 60759360` exactly, so the value is 1936-01-01 00:00 on the game's own 365-day calendar — but which instruction put it there is **not established**.

I am therefore **not proposing a confidence change** on `0x23A460`. Its `likely` covers the name of the `clearPlayers` argument, which rests on one caller passing 0, and raising the whole entry to `confirmed` would carry that along. (And `mergeFindings.py` cannot express `likely` at all — see section 6.)

## 4. `CInGameIdler +0x1790` is the `CEU3Application`. The field was misnamed.

The conflict is resolved, statically, and the chain has no gaps.

**Step 1 — one writer.** A per-displacement scan over `.text` for `0x1790` (decode forward from each plausible start before the displacement bytes; keep decodes whose own displacement field lands on them — not a linear sweep, trap 9, and not a `functionStart` walk, trap 2) finds **32** accesses: 31 reads and **one** write, `0x648418 mov [ebx+0x1790], edx` with `edx = [ebp+0x14]`, inside `CInGameIdler::CInGameIdler`. *Positive control for the negative:* the same scan finds the `+0x1788` and `+0x178C` writes six and twelve bytes earlier in the same instruction stream, through the same base register, so it can see writes here.

**Step 2 — where argument 4 comes from.** `findRefs.py --callers 0x6474A0` gives `CInGameIdler::CInGameIdler` exactly **one** caller, `0x6F1144` in `CFrontEnd::LaunchGame`:

```
0x6F1123  lea eax,[ecx+0xc0]      ; push #1  -> arg 5
0x6F1136  push edx                ; [ecx+0x68] zero-extended, the multiplayer byte -> arg 4
0x6F113A  push eax                ; [ecx+0x210]  -> arg 3
0x6F1141  push edx                ; [ecx+0x60]   -> arg 2
0x6F1142  push eax                ; [ecx+0x20c]  -> arg 1
0x6F1143  push esi                ; the new CInGameIdler
0x6F1144  call 0x6474a0
```
`ecx` is the `CFrontEnd`. So `+0x178C = [frontEnd+0x20C]` and `+0x1790 = [frontEnd+0x210]`, which is what the record already says.

**Step 3 — where `CFrontEnd +0x210` comes from, and this is the link that was missing.** `findRefs.py --callers 0x6ED660` gives `CFrontEnd::CFrontEnd` three callers: `0x60BB9D` (the back-end idler, section 3), `0x654775` (the deferred exit path) and **`0x6329DE`, inside `CEU3Application::LoadEverything`** — the first one, which has to get the object from somewhere other than an idler:

```
0x6329CE  mov ecx, [edi+0x120]    ; CEU3Application +0x120  gui      (already named)
0x6329D4  mov edx, [edi+0x11c]    ; CEU3Application +0x11C  graphics (already named)
0x6329DA  push edi                ; <-- arg 4 is EDI, the application's own `this`
0x6329DB  push ecx
0x6329DC  push edx
0x6329DD  push eax                ; the new 0x8B0-byte CFrontEnd
0x6329DE  call 0x6ed660
```
`CFrontEnd::CFrontEnd`'s own record already states that it writes `[this+0x20C] = arg2` and `[this+0x210] = arg4`. So the application passes itself in, `CFrontEnd` keeps it at `+0x210`, and `CInGameIdler` copies it to `+0x1790`. The loop then closes on itself: `0x654775` and `0x60BB9D` hand `+0x1790` and `+0xB8` back as arg 4.

**Step 4 — the class, from the constructor.** `0x22F080` (currently recorded `SessionManager::SessionManager`, "No RTTI") writes **`[this] = 0x15CD1A8`** at `0x62F134` and **`[this+8] = 0x15CD1D0`** at `0x62F13A`. The RTTI export names both tables **`CEU3Application`** (9 slots at offset 0, 4 at `+8`). `retsBefore(0x62F080, 0x62F140)` is empty, so both writes are inside the function; `0x62F070` holds `14 c3` then 14 `int3`, so the entry is right; one caller, `0xA59C43`, at startup.

**Step 5 — the name `SessionManager` is not in the image.** A byte search over every section for `SessionManager`, `CSessionManager`, `session_manager` and `sessionmanager` returns **zero** hits. *Positive control:* the same search finds `CEU3Application` in `.data` at `0x171796C` (the RTTI type descriptor) and `eu3application` in `.rdata` at `0x15CC508` (the source file `LoadEverything`'s log lines cite), so it can see both kinds of name.

**Where the misnomer came from, and it is not nonsense.** `CInGameIdler::GetSession` (virtual slot 18, rva `0x24D800`) is three instructions returning `[[idler+0x1790]+0x12C]`, and `CEU3Application::CEU3Application` builds the startup session at `0x22F30F` and stores it there. So the application **holds** a session at `+0x12C`, and the class was named after that one field. `SessionManager::MakeBackEndIdler` is a real symbol — the concept exists in the source — but it is not this class's name; its receiver is loaded `mov ecx, [ebx+0x1790]` at `0x654510`.

**Trap 14, both halves, and the two halves disagree.** `project.json` says `session_manager`. `BiceLib/Gui/WidgetStats.cpp:81-86` already says the opposite — it names the offset `IDLER_APPLICATION` and its comment reads *"CInGameIdler +0x1790 is the CEU3Application, and the application holds the gui at +0x120"*. The shipping DLL has been right about this; the record has not. Renaming brings `project.json` into line with code already in the build.

**So: rename `CInGameIdler +0x1790` to `application`, type `CEU3Application*`.** `confirmed` — every link is in the bytes and the live RTTI read agrees. **What would show it wrong:** `edi` at `0x6329CE` not being the application. Four matching displacements in one address band is not an identification (trap 12, and `FINDINGS-resetpath.md`'s own `+0xE4` worked example), so the discriminator is not `+0x11C`/`+0x120` — it is that `0x22F080` writes `CEU3Application`'s own RTTI vftable into the object its single caller constructs, which is a separate fact from the displacements. If the RTTI export mapped `0x15CD1A8` to a second class, or if the vftable write at `0x62F134` turned out to belong to an inlined base constructor rather than to `0x22F080`, the rename would be unsafe. Neither holds.

**And `+0x178C` falls out with it.** It is recorded `session_sibling`, *"Not identified"*. `LoadEverything` passes `CEU3Application +0x11C` — already named `graphics` from a live RTTI read — as `CFrontEnd::CFrontEnd`'s arg 2; `CFrontEnd` stores arg 2 at `+0x20C`; `CInGameIdler::CInGameIdler` copies `[frontEnd+0x20C]` to `+0x178C` at `0x648412`. That is a third agreement with `CGui +0x30`'s comment, which already called it the graphics by live pointer equality. **Rename to `graphics`, type `CEU3Graphics*`.** It inherits `+0x11C`'s confidence rather than adding to it: if `CEU3Application +0x11C` were mis-named, this is wrong the same way.

## 5. Corrections for a human to apply, because the merge never overwrites

1. **`0x22F080` is `CEU3Application::CEU3Application`, not `SessionManager::SessionManager`, and its *"No RTTI"* is wrong** (section 4). `FINDINGS-resetpath.md` section 8 item 1 already said this and it has not been applied.
2. **`0x2087C0 SessionManager::MakeBackEndIdler`** carries the same bad qualifier — `CEU3Application::MakeBackEndIdler`. The body description in its comment is correct and unchanged.
3. **`CInGameIdler +0x1790` → `application` / `CEU3Application*`** and **`+0x178C` → `graphics` / `CEU3Graphics*`** (section 4). `CFrontEnd +0x210`/`+0x20C` and `CBackEndIdler +0xB8`/`+0xB4` want the same names, but `project.json` has no `CFrontEnd` or `CBackEndIdler` struct, so there is nowhere to put them.
4. **`CGameState_ResetAtHistoryExecute` → `CGameState_StartupResetAndLoadGameplaySettings`**, with the full body (section 1).
5. **`FINDINGS-session.md` section 11 item 3** — *"`0x27B240`'s 2217 bytes"* — can be closed. **Section 5's `[live]` tick note** on `CGameState::ResetSession` and `CGameState::ClearPlayers` should gain the sentence that four unnamed writers of `+0xBDC` sit in the `0x6F4250..0x6F5500` frontend band, so the observed 60759360 does **not** by itself establish that `ResetGameStateToStartDate` ran (section 3).
6. **`CCurrentGameState +0xBDC tick`'s comment** should gain the writer census: `CGameState::CGameState`, `CGameState::LoadKey`, `RunHourlyTick` (`inc`), `ResetGameStateToStartDate`, `CTutorialScreen::OnTutorialButtonPressed`, and `0x2F4250`/`0x2F48A0`/`0x2F4EA0`/`0x2F5500` (unnamed) and `0x307BF0`, `0x2D60C0`, `0x2327F6`.
7. **`CEU3Application +0x12C` is the `CSession`** — a new field, proposed in the fragment.

## 6. New trap material, and one tooling conflict worth fixing

- **`mergeFindings.py` does not accept `likely`.** `CONFIDENCES = ("confirmed", "inferred")`, and the error text it prints is *"confidence must be confirmed or inferred"*. `TRAPS.md`'s closing section, `CLAUDE.md` and `fragments/README.md` all state the vocabulary as `confirmed` / `likely` / `inferred`, and `project.json` is full of `likely` entries that the merge would now refuse. **Any revision of a `likely` entry has to change its confidence, which is a second claim smuggled in with the first** — that is why section 3 declines to revise `0x23A460` at all. Either the validator or the three documents is wrong; I did not change either.
- **`fragments/README.md` documents the field list as `struct_fields`; the brief (and the plan it came from) says `fields`.** `fields` is silently ignored — `problems()` and the writer both read `struct_fields` only, so a fragment using `fields` passes `--check` reporting *zero* fields and lands nothing. The one in `fragments/merged/session2.json` uses `struct_fields`.
- **A callee's `ret N` is how you find a by-value struct argument.** `0x5F3640` ends `ret 0x14` with one pointer pushed, which is the only thing that identifies the 0x10-byte stack temp built at `0x67B3C3` as its second argument rather than a dead local. Reading the block without checking the callee's cleanup gives a function that builds a container and throws it away — and makes every `[esp+N]` for the next 0x30 bytes come out shifted by 0x10. **When `esp` drops mid-block and nothing adds it back, the callee's `ret` is the missing number.**
- **`functionStart` cannot see `CEU3Application::LoadEverything` at all**, and the thing that can is an `int3`-run scan: `0x62FAC0..0x632CE6`, with a trap-3 bare `ret` at `0x630C97` inside it. Add it to the `CInGameIdler::Enter` / `CInGameIdler::CInGameIdler` / `CFrontEnd::Enter` list of functions longer than the limit.
- **A constructor rename can be machine-checked, and the old name was what blocked the check.** Under `SessionManager::SessionManager`, `checkSignatures.py` skipped `0x22F080` twice — *"no virtual table recorded for SessionManager"* and *"no calling convention in the signature"*. Run against a patched copy with the name `CEU3Application::CEU3Application` and an explicit `__stdcall`, it reports **"1 entries checked against their ret / none disagree"**: both the `ret 0xC`-against-three-arguments test and the constructor-against-vftable test ran and agreed. **A wrong class name does not fail that check, it disables it** — which is exactly how `0x27D070` got through, and it is an argument for preferring an RTTI name even when a descriptive one reads better.
- **Five dead `in_game` clears, now six functions deep.** `0x27B240` contains one live clear and one dead accessor copy; `0x23A460` contains five dead ones; `0x23A330` contains two. The `0x15CF674`-within-0x18-bytes discriminator is still the only test that separates them, and a `grep` for the clear inside a function is still not a reading of the function.

## 7. What is not established

- **Which instruction wrote the 60759360 the live menu trip observed.** Section 3. Four unnamed writers of `+0xBDC` in `0x6F4250..0x6F5500` are an alternative to `ResetGameStateToStartDate`, and the static reading cannot choose. *What would settle it:* a hook or breakpoint on `0x63A710`, or reading `state->tick` between `CInGameIdler::Leave` and `CFrontEnd::Enter`. Needs the game running.
- **`state->+0xF0`, and the 4-byte object with vftable `0x15FDCFC` that `0x27B240` puts there.** Neither the field nor the class is named; four of the table's six slots are the 1691-holder empty stub, so the object does almost nothing, and the factory at `[0x174DA90]` is the one `Random` uses, which does not obviously fit. **Not named.** *What would settle it:* the readers of `+0xF0` on the game state, and `0x680210`/`0xB50610`, the two slots that are not stubs.
- **`state->+0xCE8` / `+0xCEC` / `+0xCE4`, and the registry at `[0x1A878BC]`.** A list head, a count and a tail, rebuilt once at startup from objects whose `+0x54` defaults to `CNullFaction` — so the elements are something faction-bearing, and `+0x54` is a hundreds-of-hits displacement (trap 12). The element class was not identified and **no name is proposed for any of the four**. *What would settle it:* the RTTI name of whatever the vector at `[0x1A878BC]+0x1C` holds, i.e. a vftable read off one element, which needs the game running — or `vtable.py --holding` on the slot-6 bodies.
- **`0x27E550`.** Read far enough to say it installs the country list and resizes the per-country vectors, not far enough to name: its tail calls `0x68F830`, `0xB9610D`/`0xB96170` over 0xA0-byte and 0x10-byte elements, and the state's virtual slot 6. On the frontier.
- **`0x4148B0`** — the vector-of-strings to 0x10-byte-container conversion — and **`0x5F3640`**, which takes the result and the statistics object. "The statistics series are re-keyed by country tag" is the reading of a `ret 0x14` and two arguments, not of either body. `likely`, and it is the one behavioural gloss in section 1 that is not `confirmed`.
- **`0x68A6E0`**, which parses `colors.txt` off `[0x1A85558]+0x294`; **`0x47FFF0`, `0x4807F0`, `0x47D160`**, the three per-country passes `ResetGameStateToStartDate` runs twice — all three walk `[0x1A855A4]` count `+0x168` / array `+0x16C`, and `0x47D160` frees a linked list at `CCountry +0xD30` per country, but what each caches was not established; and **`0xA6C1B0`** / **`0xA69AD0`**, the internals of the inlined `Tokenizer::Tokenizer`.
- ~~**What `CGameState::LoadKey` keys `gameplaysettings.txt` may legally contain.**~~ **Answered 2026-10-02 - see section 7 below.** Two thirds of it was already in `project.json` when this file was written, which is the uncomfortable part.
- **Whether `0x20BAF0` is what an ordinary "exit to main menu" uses.** Its body is unambiguous; its callers were not traced. Section 3.
- **The `CGameState` / `CCurrentGameState` duplication.** Everything proposed here that touches a game-state field is described in prose only, so the two halves cannot drift further from this document — but `+0xD9D`'s disagreement, flagged in `FINDINGS-session.md` section 9, is still unapplied.

---

## 7. What `gameplaysettings.txt` may contain - the open item, closed

Added 2026-10-02, by whoever collected wave 10 rather than by an agent; the item was costed at half
an hour and took about that.

### The short answer

A `gameplaysettings.txt` in the mod folder is parsed as **the game state's own save grammar**, and
that grammar has a `gameplaysettings` key in it. So the file a modder would write is:

    gameplaysettings = {
        setgameplayoptions = { 2 0 }     # difficulty, arcade_mode
    }

and **`CGamePlaySettings::LoadKey` (rva `0x28A550`) accepts exactly one key**, `setgameplayoptions`,
which `project.json` already recorded as "the block of options a save carries". The nested payload is
therefore two integers and nothing else.

The other thirty-odd keys are the save file's, and the settings-shaped ones among them -
`ai_seed`, `automate_sliders`, `automate_tech_sliders`, `automate_trade`, `ai`, `player`,
`victory_conditions`, `start_date` - sit at the **top level** of the file, not inside the
`gameplaysettings` block.

### The chain, read rather than assumed

`CGameState::LoadKey`'s arm for token **1551** (`gameplaysettings`) is at VA `0x68048A`, reached by
`cmp eax, 0x60f; je` at `0x680222`:

    0x68048A  mov eax, [ebx + 0xc90]     ; the sub-object
    0x680493  mov eax, [eax + 0xc]       ; its vftable slot 3 = CPersistent::Load
    0x680496  lea ecx, [ebx + 0xc90]
    0x68049C  push edx                   ; the CParseContext
    0x68049D  call eax
    0x6804B3  ret 8

`project.json` already names `CCurrentGameState +0xC90` as `gameplay_settings`, "saved as
`gameplaysettings`. **Read live**: a CGamePlaySettings" - so the recursion target was known and only
the arm was missing. `confirmed`.

### The oracle agrees, and the oracle exists after all

A savegame is plain text, and **45 of them are on this machine** - in
`Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\save games\`, i.e. **per mod**,
not in the install folder and not in a top-level `save games`. (An earlier pass today looked in the
install and in `Hearts of Iron III\save games`, found neither, and said there were none. The
`arcade_mode` field comment in `project.json` cites that exact folder, so the location was already
written down.) Every save checked carries, byte for byte:

    gameplaysettings=
    {
    	setgameplayoptions=
    	{
    2 0 	}
    }

`2 0` being `difficulty = NORMAL`, `arcade_mode = 0`, which is what both field comments predict.

### Why the hook is weaker than it looks, and it is not the reason the plan gave

`CANDIDATES.md`'s wave 10 plan guessed, from `switchmap.py` reporting 33 cases with keys like `id`,
`controller`, `unit` and `combat`, that this "reads like the game state's **save** grammar, not a
settings grammar", and concluded the hook was "real but nearly useless". **The premise is right and
the conclusion was wrong for the stated reason.** It is the save grammar - 21 of the switch's keys
appear at the top level of a real save - but the save grammar *contains* the settings block, so the
file is named after a key that genuinely exists.

The real limit is **when** it runs. `0x27B240` has exactly **one** direct caller, at `0x63286D`,
inside `CEU3Application::LoadEverything` (rva `0x22FAC0`) - so the file is parsed once per process,
during startup, before any lobby or scenario exists. And both values its `gameplaysettings` block can
reach are, per their own field comments, "written only by `CSetGamePlayOptions::Execute` (`0x2D5D20`)"
and "set once when the game is started or loaded". **The lobby's write lands after the file's and
wins.** That is worth knowing precisely rather than approximately, because `arcade_mode` is the
switch between the two supply models (`CUnit::ConsumeSuppliesAndFuel` tests it at `0x1BBA3A`): if the
file's value *did* survive, this would be a very large lever indeed. It does not appear to.

The top-level automation keys are gated differently: `automate_sliders`, `automate_tech_sliders`,
`automate_trade` and `ai` are applied only while `+0xCF4 skip_automation_keys` is **clear**
(`0x680250`: `mov al, [ebx+0xcf4]; test al, al; jne <skip>`). `0x27B240` never writes `+0xCF4` -
there is no reference to that displacement anywhere in `0x67B240..0x67BAE8` - so whatever the
constructor leaves stands at parse time. What sets the byte is still not established, as the field
comment says.

### The record's key list for `CGameState::LoadKey` is short, by at least five

This is the part worth acting on. `project.json` records 31 keys for rva `0x27FCB0`. A real save
carries seven top-level keys that are not among them - `ai`, `convoy`, `count`, `seed`,
`strategic_warfare`, `sunk_ships`, `theatre` - and **five of those seven are demonstrably cases of
this very switch**, read by hand with the register state checked on each path:

| key | token | where | how `eax` stands there |
| --- | --- | --- | --- |
| `theatre` | 1125 | `sub eax, 0x465; je` at `0x68018E` | raw - the arm is entered by `jg 0x68018e` from `cmp eax, 0x3f6` at `0x6800F4`, and `cmp` does not write `eax` |
| `convoy` | 1240 | `sub eax, 0x73; jne` at `0x680195` | cumulative: `0x465 + 0x73 = 0x4D8` = 1240 |
| `strategic_warfare` | 1413 | `sub eax, 0x585; je` at `0x680233` | raw - reached through `cmp`/`jg`/`je` only |
| `sunk_ships` | 1439 | `sub eax, 0x1a; je` at `0x68023E` | cumulative: `0x585 + 0x1a = 0x59F` = 1439 |
| `ai` | 1516 | `sub eax, 0x4d; jne` at `0x680247` | cumulative: `0x59F + 0x4d = 0x5EC` = 1516 |

`ai` has an independent cross-check, and it is the one that makes this more than arithmetic: its arm
at `0x680250` opens by reading **`[ebx + 0xcf4]`**, and `project.json`'s own comment on
`+0xCF4 skip_automation_keys` says that byte gates "`automate_sliders`, `automate_tech_sliders`,
`automate_trade` and **`ai`**". So the record already knew `ai` was a key of this switch *in a field
comment*, while its key list for the switch omits it. The record contradicts itself, which is the
cheapest possible evidence that the list is the thing that is wrong.

`count` (928) and `seed` (854) were **not** found, as a direct immediate or by a chain from a raw
path, and no claim is made about them. They may be another class's, or in a run this hand reading did
not walk.

*What would show this section wrong:* a per-path enumeration of the whole switch that does not
produce these five, or a save whose `theatre=`/`convoy=` is nested rather than top level.

### A tooling note, and a method that failed

**Neither quick route enumerates this switch, and one of them produced confident nonsense.**

- `switchmap.py 0x67FCB0` without a running game falls back to the compiled tokens and resolves
  **14 of its 22 non-object cases**, so its output read as a key list is short by eight.
- A throwaway decoder written for this pass tracked the running `sub` total **linearly down the
  listing** instead of per path. It reported `step`, `cgm_research_reset` and `text2` as keys of this
  switch and said `gameplaysettings` was never compared - in a function whose `gameplaysettings` arm
  had already been read by eye ten minutes earlier. All three names are artefacts; none of them is a
  key here. The lesson is the one `switchmap.py`'s own docstring already gives for the decompiler -
  *the switch cannot lie, but a tree walked as a straight line can* - and it applies to a hand
  script just as much. The five keys above are hand-read with the path stated for exactly this
  reason.

A correct enumeration wants a real per-path walk, which is what `definitions.py` and `switchmap.py`
are for; extending one of them to this function is a small job and is **not** done.

### What this leaves for the record

A hand edit, because `mergeFindings.py` never overwrites an existing comment:

- `CGameState::LoadKey` (rva `0x27FCB0`) - add `ai`, `convoy`, `theatre`, `strategic_warfare` and
  `sunk_ships` to the recorded key list, and say the list is read from the switch by hand where
  `definitions.py` missed the chained-`sub` arms.
- `CGamePlaySettings::LoadKey` (rva `0x28A550`) - note that this is the grammar of a mod's
  `gameplaysettings.txt` inner block, not only of a save's.

---

## The fragment, and what the two checks said

Written to **`reversing/fragments/merged/session2.json`** — 4 addresses, 3 struct fields. Every entry carries `source`, `evidence` (what was checked **and** what would show it wrong) and, where it changes an existing record, `revises` with the reason. `slots_noted` records that none of the four addresses is in any virtual table: `mergeFindings.inTables()` returns nothing for `0x67B240`, `0x63A330`, `0x62F080` or `0x6087C0`.

Contents: `0x27B240 CGameState_StartupResetAndLoadGameplaySettings` (`confirmed`, revises) · `0x23A330 ResetGlobalIdCounters` (`inferred`, new) · `0x22F080 CEU3Application::CEU3Application` (`confirmed`, revises) · `0x2087C0 CEU3Application::MakeBackEndIdler` (`confirmed`, revises, qualifier only) · `CInGameIdler +0x1790 application` (revises) · `CInGameIdler +0x178C graphics` (revises) · `CEU3Application +0x12C session` (new). `frontier` lists the 14 unnamed callees.

**`python ghidra/mergeFindings.py --check`:**

```
refused, 1 problem:
   session2.json: source reversing/findings/FINDINGS-session2.md does not exist
```

That is the only problem, and it is the expected one — the agent's `Write` is refused for `findings/FINDINGS-*.md`, so the write-up existed only in its report until this transcription. Run with `source` temporarily pointed at an existing findings file, the same fragment reports:

```
1 file, 4 addresses, 3 struct fields - no conflicts
```

So **nothing else is wrong with it**: no name or address collision, no missing key, no confidence outside `confirmed`/`inferred`, no unrecorded vftable slot, no `__thiscall` without a `::`.

**`python scripts/checkSignatures.py`:** `1295 entries checked against their ret / 88 disagree with the executable / 12 skipped`. That is the **pre-existing baseline** — the script reads `project.json`, not the fragment, so it says nothing about these entries until the merge runs. None of the entries touched here is among the 88: `--only` on `0x27B240` and `0x2087C0` each report *"1 entries checked against their ret / none disagree"*, and `0x22F080` reports **0 checked** with two skip reasons, *"no virtual table recorded for SessionManager"* and *"no calling convention in the signature"*. Run against a patched copy carrying the rename and an explicit `__stdcall`, that becomes *"1 entries checked against their ret / none disagree"* with **no skips** — so the rename is itself machine-confirmed, by the tool's own constructor-against-vftable test. `0x23A330` is new (bare `ret`, no arguments, `__cdecl`) and cannot be checked until it lands; its `ret` was verified by hand with `retsBefore(0x63A330, 0x63A730)` → `[(0x63A454, None)]`.

The merge itself and the Ghidra apply were **not** run.

---

## Checked on transcription, 2026-10-02

Three of this document's load-bearing claims were re-checked independently before it was filed, because an agent's report is not evidence on its own:

- **`gameplaysettings.txt` occurs exactly once in the image.** A raw byte search of `hoi3_tfh.exe` returns **1** hit. The "only reference" claim holds on the string side.
- **`SessionManager` and `session_manager` return zero hits** in a raw byte search of the whole file, and the positive controls both appear: `CEU3Application` (1) and `eu3application` (1). So the rename rests on a negative with a working control, which is the standard `TRAPS.md` asks for.
- **The `checkSignatures.py` baseline is as quoted** — `1295 entries checked / 88 disagree / 12 skipped` on an unmodified `project.json`. Those 88 are pre-existing and unrelated to this wave; they are a standing question about the record that nobody has acted on.

Two cosmetic repairs were made in transcription and no content was changed: `0x11FD9 3C` → `0x11FD93C` and `0x23 27F6` → `0x2327F6`, both plainly stray spaces inside a hex literal.

**Landed 2026-10-02.** The fragment merged into `../ghidra/project.json` and moved to `../fragments/merged/session2.json`, which is why the path above is `merged/` and not `incoming/`. The Ghidra apply has run, against a scratch copy of the `Hoi3_v12.1.2` project, and reported **failed: 2** - the documented pass mark, both failures being the two known over-long Ghidra bodies. So these names are in `project.json`, in `bicelib_findings.json` and in that Ghidra database. **the maintainer's own project was not written to**: Ghidra was open on it at the time.
