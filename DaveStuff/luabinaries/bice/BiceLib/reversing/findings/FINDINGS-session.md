# The session lifecycle: what `in_game` means, and what creates and destroys a game

Read out of `hoi3_tfh.exe` on 2026-10-02, statically, **and out of a running game** — a paused
Ireland campaign at 1936-01-01 00:00, module base `0x830000`. Static addresses below are
**virtual** (base `0x400000`) with the rva beside them; `VA = RVA + 0x400000`. Live addresses are
rebased with `static = live - 0x830000 + 0x400000`. Only valid for this build.

**Claims that rest on the live process are marked `[live]`.** One session is one data point. Every
`[live]` claim would have to be taken again after a restart; every unmarked claim is read out of
the bytes and survives a restart.

**In one line.** `in_game` has **six** writers in the whole image and only one of them writes a
one; the game state object is created **once per process** and is never replaced, only reset; a
savegame can only be loaded from the lobby or the tutorial screen, so **`in_game` is zero for the
whole of a load, not one**; and the window `GameClock::movedInPlay()` exists to exclude is real
but is the *tail of `CInGameIdler::Enter`*, not a load.

> **Independently re-derived 2026-10-02 before anything in the record was changed on its
> strength.** The writer census below was reproduced by a second method — decoding forward from
> every occurrence of the displacement bytes rather than scanning candidate starts — and it
> returned the same numbers at every stage: 2,822 raw occurrences, 2,820 instructions whose own
> displacement is `0xDA4`, 2,778 non-stack writes, 2,772 inlined accessor copies, and **the same
> six real writes at the same six addresses, with only `0x65D126` setting a one**. It was also
> confirmed directly that none of the six falls inside the load path `0x67CAE0..0x67CFB2`, and that
> `LoadSaveFile`'s only three callers are at `0x70B08B`, `0x70B73C` and `0x71D933`.

---

## 1. Every writer of `CCurrentGameState +0xDA4 in_game`

The scan: find the 4-byte little-endian displacement `0xDA4` in `.text`, then try decoding one
instruction from each of the few plausible starts before it and keep the decodes whose own
displacement field lands exactly on those bytes. This is not a linear sweep (trap 9) and it is not
a `functionStart` walk (trap 2). It finds **2820 instructions**: 2780 writes and 40 reads.

2772 of the 2780 writes are **one inlined idiom**, identified by the `CCurrentGameState` vftable
constant `0x15CF674` appearing in the 0x18 bytes immediately before the write — the compiler emits

```
mov  eax, [0x1A89790]          ; g_CCurrentGameState
cmp  eax, ebx                  ; ebx is the zero register
jne  <past>                    ; already there: keep it
push 0xDA8
call 0xB9602F                  ; operator new
mov  esi, eax
push esi
call 0x67D070                  ; CGameState::CGameState
mov  dword [esi], 0x15CF674    ; CCurrentGameState's vftable
mov  word  [esi+0xD9C], bx     ; clears +0xD9C and tutorial_active +0xD9D together
mov  dword [esi+0xDA0], ebx
mov  byte  [esi+0xDA4], bl     ; in_game = 0        <-- one of the 2772
...
mov  ecx, [0x1A89790]          ; release the old one, if any and different
cmp  esi, ecx
je   <skip>
cmp  ecx, ebx
je   <skip>
mov  edx, [ecx]
mov  eax, [edx]
push 1
call eax
mov  [0x1A89790], esi          ; install
<past>:
```

That is `CCurrentGameState* GetCurrent() { if (!g) SetCurrent(new CCurrentGameState()); return g; }`
inlined. It accounts for the "2,773 direct callers of `CGameState::CGameState`" that
`FINDINGS-startup.md` section 11 item 7 flagged and asked for an explanation of: **there are not
2,773 constructions of a game state, there are 2,773 copies of a lazy accessor, of which at most
one ever constructs anything.** `confirmed`.

Two of the remaining eight writes are `[esp + 0xDA4]` — stack frames, not this field (trap 12).
**Six instructions write the real field:**

| site (VA) | rva | instruction | value | where |
| --- | --- | --- | --- | --- |
| `0x67B146` | `0x27B146` | `mov byte [esi+0xDA4], al` | 0 | **`CCurrentGameState::CCurrentGameState`** — the *out-of-line* constructor, 38 bytes, 282 direct callers |
| `0x67B599` | `0x27B599` | `mov byte [esi+0xDA4], bl` | 0 | `0x27B240`, called once, from `LoadEverything`'s `history execute` stage |
| `0x65D126` | `0x25D126` | `mov byte [ecx+0xDA4], 1` | **1** | `CInGameIdler::Enter`, after the session is built |
| `0x662337` | `0x262337` | `mov byte [eax+0xDA4], 0` | 0 | `CInGameIdler::Leave` |
| `0x6ED9AF` | `0x2ED9AF` | `mov byte [eax+0xDA4], 0` | 0 | `CFrontEnd::CFrontEnd` |
| `0x6EFE58` | `0x2EFE58` | `mov byte [eax+0xDA4], bl` | 0 | `CFrontEnd::Enter` |

Four of those six were already in `project.json`'s comment on the field, which is right and which
this reading corroborates instruction for instruction. **The two that were not are `0x27B146` and
`0x27B599`,** and the first of them matters beyond this field — see section 7.

**So `in_game` is written a one at exactly one instruction in the image.** That claim was already
in the record; it now has a clean method behind it rather than a scan the record itself described
as unable to be made clean.

**What each clear means, and the one that is a surprise:**

- `0x27B146` and the 2772 inline copies are **construction**. Not a state change: the object did
  not exist a moment earlier.
- `0x27B599` is the **startup reset**, inside `0x27B240` (`0x67B240..0x67BAE6`, `ret 4`, exactly
  one caller — `0x63286D` inside `CEU3Application::LoadEverything`, the `history execute <` stage
  at `eu3application.cpp:573`). It zeroes `in_game_screen (+0xBE8)`, `+0xD9C`, `in_game` and
  `+0xDA0` on the global state and then calls
  `CGameState_SetProvincesAndSizePerCountryVectors`. `confirmed` that it runs once at startup on
  the global; the rest of its 2217 bytes **was not read end to end**.
- `0x2ED9AF` is in **`CFrontEnd::CFrontEnd`**. The frontend's *constructor* clears `in_game` — and
  104 bytes later, at `0x6EDB47`, it calls `CGameState::SetInGameScreen` and makes **itself** the
  game state's `+0xBE8`. See section 6; this is a trap for the DLL.
- `0x2EFE58` is in `CFrontEnd::Enter`, and the shape is worth stating exactly because it is not
  what "clears the byte" suggests:

```
0x6EFDD1   mov   eax, [0x1A89790]
0x6EFDD6   cmp   eax, ebx
0x6EFDD8   jne   0x6EFE4D            ; a state already exists -> keep it
           ... construct a fresh one, install it ...
0x6EFE4D   mov   edi, [esp+0x8C]
0x6EFE58   mov   byte [eax+0xDA4], bl   ; GetCurrent()->in_game = 0
```

  i.e. it is `CCurrentGameState::current()->in_game = 0` with the accessor inlined in front of it.
  **Returning to the main menu does not replace the game state object; it zeroes one byte on the
  one that is already there.** `confirmed`.
- `0x262337` is the same shape in `CInGameIdler::Leave`, immediately after the inlined accessor's
  install at `0x262325`.

## 2. Nothing else touches the byte, and the things that might have

Checked and **negative**, each with the positive control named:

- **Saving does not touch it.** `CInGameIdler::AutosaveWrite` (`0x24FF80`) and
  `CInGameIdler::AutosaveCheck` (`0x261D20`) are not among the six writers. *Control:*
  `CInGameIdler::Enter` and `::Leave`, in the same class, **are** among them, found by the same
  scan — so the scan can see this class.
- **Pausing does not touch it.** No writer sits in `AdvanceClock` or `RunHourlyTick`. `[live]`
  direct confirmation: the game is paused right now (`game_speed +0xBEC` reads 0,
  `tick_in_flight +0xBF0` reads 0) and `in_game` reads **1**.
- **The savegame loader does not touch it.** `0x27CE30` and the reset it calls, `0x27BAF0`, write
  `+0xD9C`, `+0x50`, `+0xC8C`, `+0xBE4`, `+0xBEC` and `+0xBE8` — and not `+0xDA4`. *Control:* the
  same per-displacement scan run on `0xD9C` finds `0x27BB26` and `0x27CEB9` inside exactly those
  two functions, so the method sees writes in this code.

## 3. The 36 readers

Excluding stack displacements, 36 instructions read the byte. The ones whose containing function
the record already names:

| reader | function |
| --- | --- |
| `0x9E0CE` | `SupplyNeed` |
| `0xC0862` | `RunDailyRevoltRoll` |
| `0xDC9C0` | `CCountry::UpdateMonthly` (the technology-decay gate) |
| `0xE6CBB` | `CCountry::UpdateAtWarAndEnemies` |
| `0x1BB3E8` | `CUnit::UpdateDaily` — the attrition / transport-overload gate |
| `0x255AB7` | **`CInGameIdler::Update`** |
| `0x4A9BE5` | `CAIStrategy::BuildTheatres` |
| `0x4ACB27` | `CAIStrategy::MaintainTheatres` |

`CInGameIdler::Update`'s is new here and is the most interesting, because it is per frame:

```
0x655AA7   mov   [0x1A89790], eax        ; tail of the inlined accessor
0x655AB7   cmp   byte [eax+0xDA4], 0
0x655ABE   je    0x655ACB
0x655AC0   mov   edi, [eax+0xD68]        ; strategic_warfare
0x655AC6   call  0x462F70
```

So the per-frame strategic-warfare pass is gated on `in_game`. `confirmed`.

The remaining 28 are in functions nothing names yet, ten of them in the `0x612030`–`0x64A400`
range. Not followed up.

## 4. The crux: is `in_game` set during a load? No — and `movedInPlay()` is still right

`CLAUDE.md` records that `in_game` "is set for the whole of a load, where the clock jumps", and
offers that as the reason `GameClock::movedInPlay()` exists. **The first half of that sentence does
not survive the reading.** The second half — that a stricter guard is needed — does, for a
different reason.

**The load path, read end to end.** `0x27CE30` (`0x67CE30..0x67CFB2`, `ret 8`, plus an exception
funclet out to `0x67D060` — trap 3) is the savegame loader:

```
0x67CE57  push ebx ; call 0x67BAF0              ; reset the game state (clears +0xD9C)
0x67CE9D  in_game_screen (+0xBE8) virtual slot 64
0x67CEAD  call 0x63A330
0x67CEB9  mov byte [ebx+0xD9C], 1               ; <-- "this game came from a save"
0x67CEC0  call 0x680F30                         ; re-install the in-game screen
0x67CEC6  call 0x68BB90
0x67CEDD  call [[ebx]+0xC]                      ; virtual slot 3 = CPersistent::Load - parse it
0x67CF0B  lea ecx,[ebx+0xD10] ; call 0x45E690   ; look the scenario up by the name LoadKey stored
0x67CF1A  get-or-create g_CCurrentGameState     ; a no-op: it is already there
0x67CF90  call 0x685FB0                         ; MarkSimulatedProvinces(state, scenario)
0x67CF96  call 0x68BB90 ; 0x67CF9D call 0x68C190
0x67CFB2  ret 8
```

It never writes `+0xDA4`. Its own caller, `0x27CAE0` (`LoadSaveFile`, `0x67CAE0..0x67CE2F`,
`ret 8`), has **three** callers and no others:

- `0x30B08B` and `0x30B73C`, both inside `0x30A5C6` — which carries `gamesetup.cpp`,
  `save_games_list`, `SAVE_LOADED`, `SAVE_TRANSFER_DONE`, `play_button`, `multiplayer_list`. That
  is `CGameSetup`, the pre-game lobby.
- `0x31D933`, inside `CTutorialScreen::OnTutorialButtonPressed` — the tutorial loads a prepared
  save.

**Both are screens that are not the in-game screen, so `in_game` is 0 while either runs.** The
byte only becomes 1 once `CInGameIdler::Enter` reaches `0x25D126`, which is after the whole
session has been built. `confirmed` for the three call sites and for the loader not writing the
byte; `likely` for "therefore `in_game` is 0 for every load", because it rests on the lobby and
the tutorial screen never being live while the in-game screen is.

**What `movedInPlay()` is actually excluding, and it is a real window.** `CInGameIdler::Enter`
spans `0x65A2B0..0x661BB8`, about 0x7900 bytes. The write at `0x65D126` is **0x4A92 bytes from the
end of it**. Everything after it is the in-game interface — `menubar`, `chat_list`,
`mapmode_1`..`mapmode_10`. So there is a stretch in which `in_game` is 1, the game state is
complete, and the in-game GUI does not exist yet; and the clock cannot have stepped, because
`AdvanceClock` is only reached from `CInGameIdler::Update`, which has not run. The record's own
live note on the field says exactly this from the other side — "1 from the frame a campaign comes
up, while the clock still reports not in play, which is the write landing before the GUI is
built". That observation is correct, and this is its mechanism.

**So: neither shipped guard needs changing.**

- `Gui::Lua::sessionActive()` reading `+0xDA4` is right for "is a game on screen".
- `GameClock::movedInPlay()` being stricter is right, and the reason to write in the comment is
  *"`in_game` is set before `CInGameIdler::Enter` has finished building the in-game interface"*,
  not *"`in_game` is set for the whole of a load"*. **That one sentence in `CLAUDE.md` and in the
  `movedInPlay` comment is the only thing I would change.**

**A third state neither guard covers, and I could not settle it.** `CInGameIdler::Update`
(`0x2559D0`) calls `0x2542B0` at `0x25676A`, and `0x2542B0` calls the full game-state reset
`0x27BAF0` at `0x25472C`. `0x2542B0` is a `CInGameIdler` method (not a vftable slot; it carries
`InitialSession`, `NoAdress`, `messagelog_window`, `messagecat_*`), so **the per-frame update of
the in-game idler can reach a routine that resets the game state**, and the reset does not clear
`in_game`. If that path is reachable with `in_game` already 1 — a mid-session restart or a
deferred load taking effect inside the frame loop — then there is a frame in which
`sessionActive()` says yes over a game state that has just been wiped. I have **not** established
that it is reachable in a running game; the gate on it was not read. *What would settle it:*
`cfg.py` on `0x2559D0` for the edges into the block holding `0x25676A`, and a `findRefs --callers`
sweep for what sets whatever that block tests. Until then this is a **lead, not a claim**.

## 5. What creates and destroys a session — and the object is never replaced

**The object.** `FINDINGS-startup.md` section 9 has the creation site, `0x239A86`, inside the
database stage. What this reading adds is that **nothing in the image replaces it.** Every
allocation of `0xDA8` bytes in `.text` — there are **3054** — is followed within 0x50 bytes by a
call to `CGameState::CGameState` (`0x27D070`, 2966 of them) or to the out-of-line
`CCurrentGameState::CCurrentGameState` (`0x27B130`, 88 of them), and **every one is guarded on the
global being null**: 2966 by an inline `mov reg,[0x1A89790]; cmp reg,0; jne` within 0x30 bytes;
52 more within 0x80 bytes; and the last 36 by a `call 0x40C370; test eax,eax; jne` — where
`0x40C370` is a two-instruction `mov eax,[0x1A89790]; ret`, the game's own non-inlined
`current()`. *Positive control:* the four construction sites I had already read by hand
(`0x239A6B` in the database stage, `0x6EFDDA` in `CFrontEnd::Enter`, `0x6F093B` in
`CFrontEnd::LaunchGame`, `0x67B2C9` in the startup reset) are all reported guarded by the same
test. `confirmed` for the shape and for the 2966; `likely` for the exhaustive claim, because the
last 36 were settled by sampling four of them rather than all.

The consequence: the `SetCurrent` idiom's "release the old one" arm (`cmp new,[g]; je; cmp [g],0;
je; call [[g]][0](1)`) is present in all 1928 install sites and **dead in every one of them**,
because `new` is only non-equal to `g` when `g` was null. The only way to reach it is for
`operator new` to return 0. So:

**The game state object lives for the whole process. It is created once, kept across the menu,
kept across launching a game, kept across returning to the menu, and loaded into in place.
`likely`.**

`[live]` **corroboration, and it is one data point:** `hoi3.instances(pm, "CCurrentGameState")`
finds **exactly one** object, and it is the one `g_CCurrentGameState` points at
(`0x39DADC48`). `CGameState` finds zero, `CFrontEnd` finds **zero** — the frontend object does not
survive launching a game — and `CInGameIdler` finds one.

**The check that would settle "reused or replaced" outright, which I did not perform** because it
needs the user: note `g_CCurrentGameState`'s value now (`0x39DADC48` in this run), have the user
return to the main menu and start another game, and read it again. **The reading above predicts
the same address.** If it changes, section 5 is wrong and the 36 unsampled allocation sites are
where to look.

**The session.** Distinct from the object, and it does converge:

| | |
| --- | --- |
| **make it** | `CFrontEnd::LaunchGame` (`0x2F07A0`). It get-or-creates the game state five times over (never constructing, because it already exists), logs `Start-date:`, `Country:`, `[[ Launching MULTIPLAYER-game ]]` when `CFrontEnd +0x68` is set, calls `0x2868F0` (`gamestate.cpp:2929`, `Human controller set for `, which fills the played-countries vector), then `new(0x1E00)` and `CInGameIdler::CInGameIdler`. |
| **fill it** | for a new game, `CInGameIdler::Enter`'s own `ADAPTING_HISTORY` pass; for a load, `0x27CE30` from the lobby. **Both end up in `CInGameIdler::Enter`**, which is where the two paths converge, and which branches on `+0xD9C` thirteen times to tell them apart (section 7). |
| **open the gate** | `CInGameIdler::Enter` `0x25D126`. |
| **close the gate** | `CInGameIdler::Leave` `0x262337`, then `CFrontEnd::CFrontEnd` `0x2ED9AF` and `CFrontEnd::Enter` `0x2EFE58` on the way back to the menu. |
| **tear the session down** | `CInGameIdler::Leave` (slot 4) frees the idler's lists; `0x27BAF0` (`0x67BAF0..0x67CAA7`, `ret 4`) is the game state's own 4026-byte reset, which clears `+0x50`, `+0xD9C`, `+0xC8C`, `+0xBE4`, `+0xBEC` and calls `MarkSimulatedProvinces(state, 0)` — so it **nulls `scenario`**. Three callers: the startup reset `0x27B240`, the savegame loader `0x27CE30`, and `0x23A460`. |

`0x23A460` (`ret 4` at `0x63A83A`) is the one worth naming later: five callers —
`CGameSetup` **slot 11** (`0x314100`), `CTutorialScreen::OnTutorialButtonPressed` (`0x31D4B0`),
`0x30D010` (gamesetup), `0x20BAF0`, and `0x2542B0` (the `CInGameIdler` method from section 4). It
also writes `+0xD9C`. It looks like "start a game from nothing", but **I did not read it**, and the
int3 scan gives it two `ret`s (`ret 4` at `0x63A83A`, `ret 0xC` at `0x63AA01`) so its extent is
either trap 2 or trap 3 and is unsettled. Not proposed as a name.

## 6. `in_game_screen +0xBE8` is "the current screen", not "the in-game idler"

Four instructions write a `+0xBE8` displacement and only three are this field. The setter is
`0x280F30` (`0x680F30..0x680FD3`, `ret 4`, the state on the stack and the screen **in EDI**), and
its five callers are `SessionManager::MakeBackEndIdler`, a site at `0x24901C` **inside
`CInGameIdler::CInGameIdler`** (`image.retsBefore(0x6474A0, 0x648728)` returns `[]`, so the
constructor really does extend that far — the `functionStart` answer of `0x248728` is trap 2),
the savegame loader, `0x29D793`, and **`CFrontEnd::CFrontEnd`**.

So the ordering, and it is load-bearing for the DLL:

1. `CFrontEnd::CFrontEnd` — `in_game = 0`, and `in_game_screen = the CFrontEnd`.
2. `CFrontEnd::LaunchGame` → `CInGameIdler::CInGameIdler` — `in_game_screen = the CInGameIdler`,
   `in_game` **still 0**.
3. `CInGameIdler::Enter` builds the session — `in_game` still 0.
4. `0x25D126` — `in_game = 1`. The in-game GUI is **not yet built**.
5. the rest of `Enter`, then `CInGameIdler::Update` starts stepping the clock.

**At the main menu, `state->in_game_screen` is a `CFrontEnd`, not a `CInGameIdler`.** Anything
reading `CInGameIdler` fields through `+0xBE8` must gate on `in_game` first — which is another,
independent reason the existing `inGame()` guard is the right one. `confirmed` from the call sites.
`[live]` corroboration: `+0xBE8` resolves to `CInGameIdler` by its own RTTI right now, in a game.

## 7. `+0xD9C` is "this game came from a savegame" — and it is the new-game/load switch

The record has `+0xD9C` as nothing but "the word store that clears `tutorial_active` with it". It
is a flag in its own right, and it is the field that answers "new game or load".

**Writers** (per-displacement scan on `0xD9C`, construction sites excluded, and the two `dword`
writes at `0x4CACBF`/`0x4D3E0E` discarded as other classes — trap 12):

| site | value | where |
| --- | --- | --- |
| `0x27CEB9` | **1** | the savegame loader `0x27CE30`, set immediately before `CPersistent::Load` runs |
| `0x27BB26` | 0 | the game-state reset `0x27BAF0` — which the loader calls *first*, so the sequence is clear-then-set |
| `0x27B599` | 0 | the startup reset `0x27B240` |
| `0x23A60E` | `bl` | `0x23A460`, the unread "start a game" function |
| `0x27B13A` | 0 | the out-of-line constructor (as a dword, covering `+0xD9C..+0xD9F`) |

**Readers: 23, and thirteen of them are inside `CInGameIdler::Enter`** (`0x25A89B`, `0x25ACA2`,
`0x25B06B`, `0x25B26D`, `0x25B37F`, `0x25B4D4`, `0x25B8B7`, `0x25BF47`, `0x25C7F0`, `0x25D22D`,
`0x25D4C9`, `0x261935`, `0x261A85`). The rest: `CCountry::LoadKey` (`0x4CE6B1`),
`CUnit::LoadKey` (`0x1B70C7`), `SupplyNeed` (`0x9E0D7`), `ProcessAI` twice (`0x4896B3`,
`0x4897CB`), `0x248CD2`/`0x248EFD` (inside `CInGameIdler::CInGameIdler`), `0x24C317`,
`0x30E744`, `0x31545A`, `0x315D31`, `0x3160F9` (all `gamesetup.cpp` territory).

So: `+0xD9C` is set for the life of the session once a save has been loaded, and `Enter` consults
it thirteen times to decide what it has to build itself versus what the save already carries. Two
save parsers read it too. **`likely` for the name `loaded_from_save`;** what is `confirmed` is
that it is set to 1 by the savegame loader and to 0 by the three resets, and that it has 23
readers, 13 of them in `Enter`.

`[live]` **it reads 0** in this session — which, with the writer list, says **this is a freshly
started campaign and not a loaded save**, and that in turn is what lets section 8 say what it
says. One data point, and a restart would have to re-establish it.

## 8. `+0xD0C scenario` — and the premise of the question was wrong

The record says "the scenario, or **null in a loaded save**". That is true but it reads as though
being loaded were the special case. It is not.

**Exactly one instruction writes the field on the game state**: `0x2868B0`, inside
`MarkSimulatedProvinces` (`0x285FB0..0x6868E7`, `ret 8`), which stores its **second argument**
there unconditionally:

```
0x6868AA   mov   ecx, [ebp+0xC]        ; the scenario argument
0x6868AD   mov   eax, [ebp+8]          ; the game state
0x6868B0   mov   [eax+0xD0C], ecx      ; state->scenario = scenario
```

(The other two hits are `CGameState::CGameState` zeroing it at `0x27D535`, and `0x4C964D`, which
is `+0xD0C` on a different class.) So the field is a **pure function of who calls
`MarkSimulatedProvinces` and with what.** That extends the record's own entry for that function,
which describes only its effect on `CProvinceTemplate +0x13D`. Its nine callers:

- `0x27C99A`, inside the game-state reset `0x27BAF0` — **`push 0`**. The reset nulls it.
- `0x2807A3`, inside `CGameState::LoadKey` — `push ebx`, the zero register. Null.
- `0x27CF90`, inside the savegame loader — the scenario that `0x45E690` resolved from the
  `scenario` name the save put at `+0xD10`. Null when the save carries no `scenario` key.
- six in the `0x307610`–`0x310500` band (the lobby); five push the zero register, and `0x30FBDE`
  pushes `[ebp+8]`, so that one is the candidate for a real scenario. Not traced further.

And the save **only ever writes the key when the field is non-null** — `CGameState::SaveContents`
at `0x67E771`: `mov eax,[edi+0xD0C]; test eax,eax; je <skip>; mov ecx, 0x770; lea esi,[eax+8]`.
So an ordinary campaign's save has no `scenario=` line, and loading it leaves the field null. The
"null in a loaded save" observation is a *consequence* of the field being null in an ordinary
campaign, not something loading does.

**`[live]`, and this is the answer to the question as posed:** in a **new** game (section 7:
`+0xD9C` is 0) of the 1936 campaign, `scenario` is **null**, `scenario_name (+0xD10)` is an empty
`std::string`, and `hoi3.instances(pm, "CScenario")` finds **zero** objects. So the assignment's
premise — "null in a loaded save and non-null in a new game" — is **wrong about the new game**.
`CCountry::classNameForVftable` could not be run on the pointer because there is no pointer.
`confirmed` that it is null here; `likely` that the field means "a `scenarios/*.txt` scenario is
being played" rather than "a game has been started", from the single writer, the save-key gate,
and the zero live `CScenario`s.

**`0x895140` step 9 (`AreaMayWidenFrontSearch`, rva `0x495140`), what it does differently.** The
read is at `0x49549F`, `cmp dword [edx+0xD0C], 0`. The record's account of step 9 is right and the
field's meaning sharpens it: the final arm is *"true if some neighbour area of more than five
provinces belongs to someone we are at war with, **and** either `scenario` is set **or** the war's
own attacker/defender vectors say the leading enemy is not human-played"*. With `scenario` null —
which, per the above, is **every ordinary campaign, new or loaded** — the `scenario` disjunct is
dead and the human-played test always runs: an AI theatre agent **will not** widen its front search
into a neighbour area whose war is led by a human. With `scenario` non-null, the human-played test
is short-circuited and the agent widens regardless. `confirmed` for the instruction and the
structure (both from the record's own end-to-end read and this reading of the field); the
behavioural reading is `likely`.

The same disjunction appears in `CAIStrategy::IsFrontWorthyEnemy` (`0x4A947B`),
`CEU3AI::CreateMinisters` (`0x488967`, which returns outright when `scenario` is set, so **in a
scenario no country gets ministers**), `RunHourlyPass`, `CGameState::StartAI`,
`CLoadOOBEffect::Execute`, `LoadEvents` and 40 other sites. All of them are in the branch an
ordinary campaign never takes.

## 9. Field sweep: what a live `CCurrentGameState` holds that is not already named

Trap 14 first: `project.json` already names **74** fields across `CCurrentGameState` and
`CGameState`. A full `dumpStruct`-style sweep of the live object, with
`classNameForVftable` on every four bytes, found **no unnamed pointer worth naming**. Every
non-zero pointer in it is already in the record, and the three that resolve by RTTI resolve to
what the record says — `+0xBE8 CInGameIdler`, `+0xC6C`/`+0xC70`/`+0xC74` `CGraphStatistics`,
`+0xD08 CVictoryConditionManager`. Three non-zero dwords are unaccounted for (`+0x430`, `+0x6C0`,
`+0x7F0`) and all three look like uninitialised padding inside an embedded sub-object rather than
fields; **not claimed**.

So the only field news is `+0xD9C` (section 7), and two **corrections** that the merge tool cannot
make because it never overwrites a name:

1. **`CGameState +0xD9D` still reads `autosave_blocked`, "meaning not established".** The
   `CCurrentGameState` copy was corrected to `tutorial_active` on 2026-09-30 with a long comment;
   the `CGameState` copy was not. The two halves of the same field disagree in one file. **Apply
   `tutorial_active` and the `CCurrentGameState` comment to the `CGameState` row by hand.**
2. **`CCurrentGameState +0x18 tag_18` says "a tag field holding the null tag `---`; not the player
   tag".** `[live]` it holds **`IRE`, id 20 — the player's own tag**, byte for byte identical to
   `+0xC30 player`. `+0x90` does hold `---`, so that half of the comment is fine. The "holding
   `---`" claim for `+0x18` is a session-specific observation that this session contradicts.
   `CGameState::LoadKey` handles a `controller` key (token `0x1ED`) that
   `CGameState::SaveContents` **never writes**, and `0x1ED`'s handler at `0x67FDDC` is a loop over
   a vector rather than a store, so I could not place it. **Suggest the comment be weakened to
   "a tag field; read as the player's own tag in a single-player game, and as `---` in another
   session, so what distinguishes the two is not established" rather than a new name.**
   `inferred`, one data point each way.

Incidentally `[live]`: `+0xBCC played_countries_array` is a **vector begin pointer**, not an inline
array — `{begin, end, cap}` at `+0xBCC`/`+0xBD0`/`+0xBD4`, 108 four-byte entries, exactly one
non-zero (id 20). That matches how the record's own call sites use it
(`gameState->+0xBCC[country id]`), so it is a confirmation rather than a change.

## 10. New trap material

- **A new trap-2 pair, and it is the worst kind — a 16-byte stub.** `0x67CAD0` is a five-instruction
  tail-call thunk ending `ret` at `0x67CADF`; `0x67CAE0`, the real `LoadSaveFile`, begins at the
  **very next byte** with no padding. `image.functionStart` on anything inside `LoadSaveFile`
  answers `0x67CAD0`, and `retsBefore(0x67CAD0, 0x67CAE0)` returns one `ret` and says so at once.
- **`0x685F40`/`0x685FB0`**: `0x685F40` ends with a bare `ret` at `0x685FAC` and only **three**
  `int3` follow, so a scan for a run of five or more padding bytes walks straight past the
  boundary and swallows `MarkSimulatedProvinces`. The run length is the bug, not the prologue set.
- **`CInGameIdler::CInGameIdler` runs from `0x2474A0` to past `0x249020`**, which
  `functionStart`'s default limit cannot see; `retsBefore(0x6474A0, 0x648728)` returns `[]` and
  settles it. `CInGameIdler::Enter` has the same problem at 0x7900 bytes and the record already
  notes it.
- **A displacement of `0xDA4`, `0xD9C` or `0xD0C` is not this class.** 2780 "writes" to `+0xDA4`
  reduce to six; 2809 references to `+0xD9C` reduce to five writers; `+0xD0C` has writers on at
  least two unrelated classes. The discriminator that worked was not the displacement and not
  `functionStart` — it was **the `0x15CF674` vftable constant within 0x18 bytes before the write**,
  which separates "this is the constructor's own zeroing" from everything else in one test.

## 11. What is not established

- **Whether `0x2542B0` — and so the game-state reset — is reachable from `CInGameIdler::Update`
  with `in_game` already 1.** Section 4. This is the one open question that could still make a
  shipped guard wrong, and it is the next thing to read. *What would settle it:* `cfg.py 0x6559D0`
  for the edges into the block at `0x656740`, and what that block's predecessor tests.
- **`0x23A460`.** Five callers across the lobby, the tutorial and `CInGameIdler`; writes `+0xD9C`;
  calls the full reset. Its extent is unsettled (two `ret`s, so trap 2 or trap 3) and its body was
  not read. Probably the real "start a game" entry point, and probably the thing a full account of
  the lifecycle is missing. Not named here on purpose.
- **`0x27B240`'s 2217 bytes**, beyond the reset block at `0x67B581` and its one caller.
- **What `scenario` actually points at.** Zero live `CScenario`s, so `classNameForVftable` had
  nothing to resolve. The assignment asked for its type by RTTI and I could not supply it.
  *What would settle it:* the same read in a game started from a `scenarios/*.txt` entry rather
  than a campaign bookmark — or `findInstances.py CScenario` in one.
- **Whether the game state object survives a return to the menu, measured rather than read.**
  Section 5 gives the prediction and the one-line check; it needs the user to leave and re-enter a
  game, which I was told not to ask for.
- **`controller` (token `0x1ED`)** — handled by `CGameState::LoadKey` at `0x67FDDC`, never written
  by `SaveContents`, and its destination not placed. The `+0x18` question in section 9 hangs on it.
- **The 28 unnamed readers of `in_game`**, ten of them clustered in `0x612030`–`0x64A400`.
- **The 36 of 3054 `0xDA8` allocations** whose null-guard was established by sampling rather than
  by a test over all of them. The byte-window method cannot settle them; decoding each function's
  flow would.
- **`+0xC8C`**, cleared by `0x27BAF0` beside `+0xD9C`. Zero live. No meaning read.

## 12. Everything I propose, in one list

`addresses`, functions: `0xC370 GetCurrentGameState`,
`0x27B130 CCurrentGameState::CCurrentGameState`, `0x27BAF0 CGameState::ResetSession` (likely),
`0x27CAE0 LoadSaveFile` (likely), `0x27CE30 CGameState::LoadFromSave`,
`0x280F30 CGameState::SetInGameScreen`, `0x285F40 CGameState::ClearPlayers` (likely),
`0x2868F0 CGameState::AssignHumanControllers` (likely),
`0x27B240 CGameState_ResetAtHistoryExecute` (likely).

`addresses`, instructions: `0x27B146`, `0x27B599`, `0x27CEB9`, `0x27BB26`, `0x2868B0`.

`fields`: `CCurrentGameState +0xD9C loaded_from_save` and the same on `CGameState`.

Corrections for a human to apply, which the merge tool will not: the two in section 9; the note on
`0x27D070`'s comment that `CCurrentGameState` **does** have a standalone constructor
(`0x27B130`, 282 callers); the `in_game` field comment to add `0x27B146` and `0x27B599` to its
writer list; and the one sentence in `CLAUDE.md` and in `GameClock::movedInPlay()`'s comment
identified in section 4.
