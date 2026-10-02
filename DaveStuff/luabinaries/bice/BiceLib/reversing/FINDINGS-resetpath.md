# The deferred session-exit path: can `Update` reach the game-state reset with `in_game` set?

Read out of `hoi3_tfh.exe` on 2026-10-02, **statically only** — nothing here was run, and no claim
below is `[live]`. Addresses are **virtual** (image base `0x400000`) with the rva beside them where
it matters; `VA = RVA + 0x400000` (trap 1). Only valid for this build.

**The answer, first. No — there is no frame in which `Gui::Lua::sessionActive()` can say "yes" over
a game state that `0x27BAF0 CGameState::ResetSession` has just wiped.** The path is real and it is
reachable in ordinary play, so the question was a good one: `CInGameIdler::Update` calls `0x2542B0`
**unconditionally, once per frame**, and `0x2542B0` reaches the full reset through `0x23A460`
whenever `CInGameIdler +0x1CDA` is set — which happens when a **tutorial** finishes. But on that
branch `in_game` is cleared before anything else in the process can look at it: at `0x6ED9AF`,
inside `CFrontEnd::CFrontEnd`, which `0x2542B0` calls **0x49 bytes after the reset returns to it**;
and again at `0x262337` in `CInGameIdler::Leave`, which the run loop calls four instructions after
`Update`'s vftable slot returns. `FINDINGS-session.md` section 4's conclusion — *"neither shipped
guard needs changing"* — survives this reading, and section 11 item 1 can be closed.

**One sentence about where to look for that 0x49 bytes, because it is easy to misread.** Both the
reset and the clear are in the **caller**, `0x2542B0`: `call 0x63a460` at `0x65472C` and
`call 0x6ed660` at `0x654775`, and `0x654775 - 0x65472C = 0x49` exactly, with no `ret` between them.
Nothing inside `0x23A460` clears the byte. `0x23A460` does contain **five** `mov byte [reg+0xDA4], 0`
instructions — at `0x63A4C8`, `0x63A54F`, `0x63A5DB`, `0x63A6D8` and `0x63A7A2` — and **every one of
them is dead**: each sits in the `operator new` succeeded arm of a copy of the inlined
`get-or-create g_CCurrentGameState` accessor, guarded on `[0x1A89790] == 0`, which is never true
after startup. That is the 2,772-copy phenomenon `FINDINGS-session.md` section 1 established, seen
five times in one 0x3DD-byte function. Looking for the live clear inside `0x23A460` finds only those
and concludes the mechanism fails; it is in the caller.

---

## 1. `0x2542B0` is called on every frame, and the gate is inside it, not above it

`CInGameIdler::Update` (rva `0x2559D0`) spans `0x6559D0..0x656B83` with **exactly one** `ret 4`, at
`0x656B80`: `image.retsBefore(0x6559D0, 0x656B83)` returns `[(0x656B80, '4')]`, so the extent is
clean of both trap 2 and trap 3. 1178 instructions. `image.functionStart(0x65676A)` agrees at
`0x6559D0`.

`cfg.py 0x6559D0 0x11B4` was read as a graph, not as one jump (trap 13). The block holding the call
is reached unconditionally:

```
0x0065671D:  <- 0x656711(taken), 0x65671B(flow)
   0x0065671D  mov     eax, dword ptr [ebx + 0x1cb0]
   0x00656723  cmp     eax, esi
   0x00656725  je      0x656739

0x00656739:  <- 0x656725(taken), 0x656737(fall)
   0x00656739  mov     dword ptr [ebx + 0x1cb0], esi
   ...
   0x0065675D  mov     byte ptr [ebx + 0xa80], 0
   0x00656764  call    0x654000
   0x00656769  push    ebx
   0x0065676A  call    0x6542b0          ; <-- the call in question
   0x0065676F  cmp     byte ptr [ebx + 0x1d3d], 0
```

Walking the edge list backwards, `0x656739` is reached from `0x656725(taken)` and `0x656737(fall)`,
both out of `0x65671D`, and the chain upward from there — `0x656711`, `0x6566F1`, `0x6566C2`,
`0x6566B5`, `0x65667A`, `0x656672`, `0x656650`, `0x6565AF`, `0x656588`, `0x656558`, `0x6564D1`,
`0x6564AE`, `0x65647D`, `0x656463`, `0x656456`, `0x65644F` — is a run of **diamonds only**: every
conditional in it has both arms rejoining before the next one. The join at the top is

```
0x0065644F:  <- 0x656027(taken), 0x656281(taken), 0x65628D(taken), 0x65644A(flow)
   0x0065644F  cmp     dword ptr [ebx + 0xd28], 1
```

and a machine check over every block header in the function found **no other edge** from anywhere
below `0x65644F` into anything at or above it:

```
edges from before 0x65644F into blocks at/after it:
  [('0x65644f','0x656027'), ('0x65644f','0x656281'),
   ('0x65644f','0x65628d'), ('0x65644f','0x65644a')]
```

All four land on `0x65644F` itself. With a single `ret` in the function, every execution of
`CInGameIdler::Update` therefore passes through `0x65676A`. **`confirmed`: `0x2542B0` runs once per
frame while the in-game screen is current, and nothing above it gates it.** The gate
`FINDINGS-session.md` was looking for does not exist at this level; it is inside `0x2542B0`.

`findRefs.py --callers 0x006542B0` reports **one** caller, `0x65676A`. The call is
`push ebx; call 0x6542b0` with `ebx = this`, so `0x2542B0` takes the idler as a **stack** argument,
not in `ecx` — it is not a `__thiscall` and must not be given a `::` name (trap 11).

## 2. What `0x2542B0` is: the three deferred ways a session ends

**Extent, settled before quoting it.** int3 padding of 9 bytes ends at `0x6542AF`, so the function
starts at `0x6542B0`; the next padding is 4 bytes at `0x65492C`. `image.retsBefore(0x6542B0,
0x65492C)` returns **two** `ret 4`s, at `0x6547CF` and `0x654929` — and this is **trap 3, not trap
2**: the branch `0x65457A je 0x6547d2` jumps from inside the function to `0x6547D2`, past the first
`ret`, and both exits restore the same SEH slot `[esp+0x74]` and share the `mov esp, ebp; pop ebp`
epilogue of the one frame. So: **one function, `0x6542B0..0x65492C` (rva `0x2542B0..0x25492C`),
0x67C bytes, 471 instructions, two `ret 4` exits.** `confirmed`.

The body is three sequential one-shot request flags on the idler, read in this order:

```
f(CInGameIdler* idler):

  // the elimination detector, run every frame
  if (idler->+5 == 0) {
      tag     = idler->slot23()                        // the played tag {chars, id}
      country = g_CCountryDataBase[0x1A855A4]->+0x16C[tag.id]
      if (country->NumberOfOwnedProvinces (+0xCF8) < 1)       // 0x654306
          if (tag.chars[0..2] != "REB")                       // 0x65431D..0x65432C
              idler->+0x1CD9 = 1                              // 0x65432E
  }

  if (idler->+0x1CD9) {                                       // 0x654335  GAME OVER
      release the global at [0x1A857E8]
      if (idler->multiplayer (+0x68))
          idler->SetSession(new CSession("", "NoAdress", "InitialSession"))   // 0x654461
      free idler->+0x1D28; ...
      new(0x600) + MakeBackEndIdler(app, it, graphics, gui)    // 0x654518
      app->+0x88 = 1; app->+0xE0 = the CBackEndIdler           // SetNextScreen, inlined
  }                                                            // falls through

  if (idler->+0x1CDA) {                                       // 0x654573  EXIT TO MENU
      release the global at [0x1A857E8]
      if (idler->multiplayer (+0x68))
          idler->SetSession(new CSession("", "NoAdress", "InitialSession"))   // 0x65469D
      free idler->+0x1D28; ...
      [[app]+0xE4]->slot4(1)                                  // 0x654728  (an empty stub)
      ResetGameStateToStartDate(1)                            // 0x65472C  <-- THE RESET
      [[app]+0xE4]->slot4(0)                                  // 0x654743  (the same stub)
      screen = new(0x8B0)                                     // 0x65474A
      if (screen != 0)                                        // 0x65475E/0x654760
          CFrontEnd::CFrontEnd(screen, graphics, gui, app)     // 0x654775 -> clears in_game
      else
          screen = 0                                          // 0x65477E
      app->+0x88 = 1; app->+0xE0 = screen
      return;                                                 // 0x6547CF  ret 4
  }

  if (idler->+0x1CD8) {                                       // 0x6547D2  QUIT
      ... same session replacement ...
      byte [0x1A857EF] = 1
      PostQuitMessage(0)                                      // 0x654912
  }
  return;                                                     // 0x654929  ret 4
```

Supporting readings, each cheap and each checked:

- **`PostQuitMessage`.** `call dword ptr [0xD2B2BC]` resolves through the import directory to
  `USER32.dll!PostQuitMessage`. `confirmed`.
- **The three string literals the function references are `0x15B4945` (the shared empty string),
  `0x15CC4C0 "NoAdress"` and `0x15CC4CC "InitialSession"`**, and all three are arguments to
  `0xA887A0`, which `project.json` already identifies as the `CSession` constructor
  (`session.cpp`, vftable written at `0xA887E0`). So the "session-ish" guess in
  `FINDINGS-session.md` section 4 was right about those two strings and **wrong about
  `messagelog_window` / `messagecat_*`: those are not referenced anywhere in `0x6542B0..0x65492C`.**
  The 471 instructions were read in full and the only immediates that point into `.rdata` text are
  the three above. That half of section 4's string list is a mis-attribution, most likely from a
  `functionStart` over a wider range.
- **`CCountry +0xCF8` is `NumberOfOwnedProvinces`**, already named in `project.json` (it is the same
  field `RunDailyRevoltRoll` and `RebuildCountryEventCandidates` gate on). So the opening block is
  the **"you have been annihilated"** detector: a played country reduced to zero provinces that is
  not `REB` gets the game-over flag, and the very next `if` acts on it in the same call.
  `confirmed` for the instructions, `likely` for the reading.
- **`CInGameIdler +0x68 multiplayer`** is already in `project.json` with the comment *"zero in
  single player; the autosave decision branches on it, apparently multiplayer (untested)"*. All
  three branches here gate the `CSession("NoAdress", "InitialSession")` replacement on it, which is
  an **independent third reader that fits the name exactly**: only a networked game has a live
  session to tear down and replace with the placeholder. Code-side corroboration, not a test.
- **`0x6087C0` is already named `SessionManager::MakeBackEndIdler`** and its comment already cites
  this very call site (`0x254518`). The 0x600-byte object it builds carries vftable `0x15CA9B4`,
  which the RTTI export names **`CBackEndIdler`**. It calls `CGameState::SetInGameScreen`
  (`0x680F30`) at `0x608925`. See section 7 — that is a side finding worth having.
- **`0x6ED660` is already named `CFrontEnd::CFrontEnd`**, signature
  `CFrontEnd *(CFrontEnd *this, void *sibling, void *arg3, void *sessionManager)`. The call at
  `0x654775` pushes `[idler+0x1790]`, `[idler+0x60]`, `[idler+0x178C]`, then the new allocation — so
  the arguments are `(new, graphics, gui, app)`, matching the recorded signature argument for
  argument, and `retsBefore(0x6ED660, 0x6EDC00)` plus the `ret 0x10` at `0x6EDB96` confirm four
  stack arguments and confirm that the `in_game = 0` write at `0x6ED9AF` is **inside** it.

**Proposed name: `ProcessSessionEndRequests` (rva `0x2542B0`), `likely`.** No string names it; the
name reads the body. It is not a vftable slot — `image.findValue(0x6542B0, '.rdata')` returns
nothing — so trap 4 does not apply.

## 3. The window between the reset and the `in_game` clear, instruction by instruction

This is the whole of the hazard, and it is 0x49 bytes of the **caller**:

```
0x0065472A  push    1
0x0065472C  call    0x63a460          ; ResetGameStateToStartDate(1) -> CGameState::ResetSession
0x00654731  mov     ecx, dword ptr [ebx + 0x1790]      ; the CEU3Application
0x00654737  mov     ecx, dword ptr [ecx + 0xe4]
0x0065473D  mov     edx, dword ptr [ecx]
0x0065473F  mov     eax, dword ptr [edx + 0x10]        ; slot 4
0x00654742  push    esi                                ; 0
0x00654743  call    eax                                ; <-- (a) the indirect call
0x00654745  push    0x8b0
0x0065474A  call    0xb9602f                           ; operator new
0x0065474F  add     esp, 4
0x00654752  mov     dword ptr [esp + 0x20], eax
0x00654756  mov     dword ptr [esp + 0x7c], 0xd
0x0065475E  cmp     eax, esi
0x00654760  je      0x65477e                           ; <-- (b) the only branch in the window
0x00654762  mov     ecx, dword ptr [ebx + 0x1790]
...
0x00654775  call    0x6ed660                           ; CFrontEnd::CFrontEnd
                                                       ;   -> 0x6ED9AF: in_game = 0
0x0065477A  mov     edi, eax
0x0065477C  jmp     0x654780
0x0065477E  xor     edi, edi                           ; the allocation-failure arm
0x00654780  ...                                        ; app->+0x88 = 1; app->+0xE0 = edi
```

**The window is not unconditional, and the one branch in it skips the clear.** That is worth stating
plainly rather than glossing. Both items are settled below.

### (a) The indirect call at `0x654743` is an empty stub: it reads nothing and raises nothing

`CInGameIdler +0x1790` is the `CEU3Application` (section 8 correction 1). Its `+0xE4` is written
**once** in the image, by the base `CApplication` constructor `0xA909A0` — which
`CEU3Application::CEU3Application` (`0x62F080`) calls at `0x62F0F3` — with a 0xC0-byte object:

```
0x00A90ACC  mov     dword ptr [esi + 0xe0], ebx        ; the app's pending screen, zeroed
0x00A90AD2  push    0xc0
0x00A90ADB  call    0xb9602f                           ; operator new(0xC0)
0x00A90AEE  je      0xa90b1a
0x00A90AF0  push    edi
0x00A90AF1  call    0xb32cb0                           ; its constructor
0x00A90AF6  mov     dword ptr [edi], 0x15fddc0         ; primary vftable
0x00A90AFC  mov     dword ptr [edi + 0x18], 0x15fde20  ; three more - multiple inheritance
0x00A90B03  mov     dword ptr [edi + 0x30], 0x15fde30
0x00A90B0A  mov     dword ptr [edi + 0x48], 0x15fde40
0x00A90B11  mov     dword ptr [edi + 0x60], 0x15fde50
0x00A90B1A  xor     edi, edi
0x00A90B1C  mov     dword ptr [esi + 0xe4], edi        ; app->+0xE4 = it
```

That `esi` is the application and not something else is self-evident from the same function zeroing
`+0x88` at `0xA90AAA` and `+0xE0` at `0xA90ACC` — the exact pair that
`CEU3Application::SetNextScreen` writes and that `CEU3Application::Run` reads. So the `+0x88`/`+0xE0`
object and the `+0xE4` object are the same object's fields, read from two different constructors.

Reading vftable `0x15FDDC0` directly out of `.rdata`:

```
slot 0 0xa802c0   slot 1 0xa80b00   slot 2 0xa80b60   slot 3 0xa80ba0
slot 4 0x60cd50   slot 5 0xb32f00   slot 6 0x60cd50   slot 7 0xb18460
```

`[edx+0x10]` is **slot 4**, index 4, and slot 4 is **`0x60CD50`**, which `TRAPS.md` trap 4 already
lists as a shared folded stub with 1420 holders. Its body is one instruction:

```
0x0060CD50  ret     4
```

**So the call at `0x654743` executes no instruction other than its own return.** It cannot read the
game state, cannot raise a message, cannot reach the DLL, and the single-frame hazard this would
otherwise open does not exist. It also explains the apparent stack imbalance at the call site
(`push 1; call eax` with no `add esp, 4`): the stub cleans its own argument.

Three checks behind that, because an indirect call deserves them:

- **The vftable at `+0` is `0x15FDDC0` for the object's whole life.** `image.findValue(0x15FDDC0,
  '.text')` returns three sites: `0xA90AF8` (the operand of the write above), `0xA802C8` — which is
  inside `0xA802C0`, **slot 0 of that same vftable**, i.e. the standard MSVC destructor re-establishing
  its own class — and `0xA804BD`, another method of the same class. None of the three changes what the
  object is. `confirmed`.
- **The other `+0xE4` in this part of the image is a different class (trap 12 again).** A scan of all
  185 stores to `[reg+0xE4]` in `.text` found only one other candidate near the application,
  `0xA90B1C`'s apparent twin at `0x691710` in `0x6913F0` — and `0x6913F0` writes vftable
  `0x15CFBA4`, which the RTTI export names **`CIngameLobby`** (base `0x15C3AE4 CReferenceObject`,
  sub-vftables at `+0x30`/`+0x40`/`+0x50`, one of them `CSessionInfoObserver`). It has `+0xE0`,
  `+0xE4`, `+0xF4` and `+0xF8` of its own and is not the application. `findRefs --callers` reports
  0 direct callers for it and exactly 1 for `0x62F080` (`0xA59C43`, startup). `confirmed`. *Positive
  control for the "only one writer" negative:* the same scan does find `0x691710` and
  `0x67D148` (`mov byte [ebx+0xE4], 0` in `CGameState::CGameState`), so it sees constructor stores at
  this displacement, in both dword and byte form, in this part of the image.
- **`CEU3Application +0xE4` is not `CEU3Application +0x124`.** `+0x124` is the field `CInGameIdler`
  slot 15 returns —

  ```
  0x0064D7C0  mov     eax, dword ptr [ecx + 0x1790]
  0x0064D7C6  mov     eax, dword ptr [eax + 0x124]
  0x0064D7CC  ret
  ```

  — and `FINDINGS-guilive.md` and `FINDINGS-session.md` are right that it is unidentified. It plays
  no part in this window and the two offsets should not be run together.

The same stub call appears once more with argument 1 at `0x654726`, immediately **before** the reset,
and a third time in `CInGameIdler::AutosaveWrite` at `0x65000C`, immediately before the
`save games/` path is built. So the idiom is a suspend/resume bracket around a long operation, and it
is inert in all three places in this build.

### (b) The branch at `0x654760` skips the clear, and it is the allocation-failure arm

`eax` is the result of `new(0x8B0)` at `0x65474A` and `esi` is the zero register, so
`je 0x65477E` is taken **only when `operator new` returns null**. On that arm `edi` is zeroed, the
`CFrontEnd` is never constructed, and `in_game` is therefore **not** cleared inside `0x2542B0`. The
function still runs its tail:

```
0x00654788  mov     ebx, dword ptr [ebx + 0x1790]      ; the application
0x00654797  mov     byte ptr [ebx + 0x88], 1           ; a screen change is pending
0x006547B8  mov     dword ptr [ebx + 0xe0], edi        ; ... and the pending screen is NULL
0x006547CF  ret     4
```

**The residual closes two ways, and the first is the one that matters.**

1. **`CInGameIdler::Leave` still clears the byte on that arm.** The run loop's swap takes the
   *outgoing* screen's slot 4 **before** it touches the incoming pointer (section 4):
   `0x2913AD` loads `app->+0x84`, which is still the live `CInGameIdler`, tests it non-null, and
   calls slot 4 at `0x2913BC`. That is `CInGameIdler::Leave`, which clears `in_game` at `0x262337`.
   Only afterwards, at `0x2913BE`, does the swap read `app->+0xE0`. So `in_game` reaches 0 on the
   failure arm too, by the same instruction and at the same point in the frame as on every ordinary
   exit. `confirmed`.
2. **And the arm is self-terminating.** With `app->+0xE0 == 0`, the swap writes `app->+0x84 = 0` at
   `0x2913E4` and then dereferences it with no null test:

   ```
   0x00A913E4  mov     dword ptr [edi + 0x84], esi     ; = 0
   0x00A913EA  mov     eax, dword ptr [edi + 0xe8]
   0x00A913F0  mov     ecx, dword ptr [edi + 0x84]     ; = 0
   0x00A913F6  push    eax
   0x00A913F7  mov     eax, dword ptr [edi + 0xe4]
   0x00A913FD  mov     byte ptr [edi + 0x88], 0
   0x00A91404  mov     edx, dword ptr [ecx]            ; <-- null dereference
   ```

   So an exit-to-menu under a failed 0x8B0 allocation clears `in_game`, then faults in the run loop
   0x48 bytes later. This is the same class of arm as the dead "release the old one" branch
   `FINDINGS-session.md` section 5 identified — reachable only if `operator new` returns 0, which in
   this process means it is already over. **Not claimed to matter in practice; recorded because it is
   the only branch in the window and the window should not be described as straight-line.**

**With (a) and (b) settled, the window contains one empty stub, one allocation, one branch whose
only arm still clears the byte through `Leave`, and the first 0x34F bytes of
`CFrontEnd::CFrontEnd`.** `confirmed` for the ordering, the stub and the branch; `likely` for
"nothing in the window can present a frame", because the nine sub-object constructor calls inside
`CFrontEnd::CFrontEnd` before `0x6ED9AF` (`0x644280`, `0x6450F0`, `0x6F5B40` x5, `0xA65250`,
`0x63C1D0`, `0x4024D0`, `0x518480`, plus string work and `0x67D070`) were not walked transitively.
Section 4 is why that residue does not affect the answer.

## 4. The control that does not depend on the window: the run loop clears `in_game` four instructions after `Update`'s slot returns

**`CInGameIdler::Update` has no direct callers.** `image.findValue(0x6559D0, '.text')` returns
**nothing**; `image.findValue(0x6559D0, '.rdata')` returns **one** address, `0x15CEB58`, which is
`CInGameIdler`'s vftable `0x15CEB54` **+ 4 — slot 1**. So it is reached only through the vftable, and
any claim about its caller has to be made about a slot, not a `call rel32`. (One holder, so trap 4
is satisfied as well: it is not a fold.) Reading the table directly:

```
CInGameIdler slot 0  0x649680
CInGameIdler slot 1  0x6559d0   = CInGameIdler::Update
CInGameIdler slot 2  0x644b40
CInGameIdler slot 3  0x65a2b0   = CInGameIdler::Enter   (sets in_game at 0x25D126)
CInGameIdler slot 4  0x662060   = CInGameIdler::Leave    (clears in_game at 0x262337)
```

`CInGameIdler::Leave` really does own that clear: padding ends at `0x66205F` so `0x662060` is the
entry, and `image.retsBefore(0x662060, 0x662340)` is **empty**, so `0x662337` is inside it with no
boundary crossed. Slot 1 and slot 4 are per-class — `CFrontEnd` holds `0x6EDD60` and `0x6F0140`,
`CBackEndIdler` holds `0x608AF0` — so the slot identifies the class.

`CEU3Application::Run` (rva `0x290F90`) is the frame loop. Its tail, read end to end:

```
0x00A9138D  mov     ecx, dword ptr [edi + 0x84]     ; the current screen
0x00A91393  test    ecx, ecx
0x00A91395  je      0xa913a0
0x00A91397  mov     edx, dword ptr [ecx]            ; its vftable
0x00A91399  mov     eax, dword ptr [edx + 4]        ; slot 1
0x00A9139C  push    1
0x00A9139E  call    eax                             ; slot1(currentScreen)
0x00A913A0  cmp     byte ptr [edi + 0x88], 0        ; a screen change pending?
0x00A913A7  je      0xa91426
0x00A913AD  mov     ecx, dword ptr [edi + 0x84]     ; still the OUTGOING screen
0x00A913B3  test    ecx, ecx
0x00A913B5  je      0xa913be
0x00A913B7  mov     edx, dword ptr [ecx]
0x00A913B9  mov     eax, dword ptr [edx + 0x10]     ; slot 4
0x00A913BC  call    eax                             ; slot4(outgoingScreen)
0x00A913BE  mov     esi, dword ptr [edi + 0xe0]     ; only now: the pending screen
0x00A913C4  mov     dword ptr [edi + 0xe0], 0
0x00A913CE  mov     ecx, dword ptr [edi + 0x84]
0x00A913D4  cmp     esi, ecx
0x00A913D6  je      0xa913e4
0x00A913D8  test    ecx, ecx
0x00A913DA  je      0xa913e4
0x00A913DC  mov     edx, dword ptr [ecx]
0x00A913DE  mov     eax, dword ptr [edx]
0x00A913E0  push    1
0x00A913E2  call    eax                             ; release the old screen
0x00A913E4  mov     dword ptr [edi + 0x84], esi     ; the new screen becomes current
...
0x00A9140C  slot 3 of the new screen                ; CFrontEnd::Enter -> in_game = 0 again
0x00A91419  slot 5 of the new screen
0x00A91426  cmp     dword ptr [edi + 0xf8], 0x12
0x00A9142D  jne     0xa910a1                        ; next frame
```

So, stated as an indirect call with the slots named: **while the in-game screen is current,
`slot1(currentScreen)` at `0x29139E` is `CInGameIdler::Update`, and `slot4(outgoingScreen)` at
`0x2913BC` is `CInGameIdler::Leave` — and between `Update`'s slot returning at `0x2913A0` and
`Leave`'s slot being called there are four instructions, none of them a call.** No frame can be
presented in between, whatever `Update` did to the game state, and whatever arm of section 3(b) it
took. `confirmed` from the bytes.

`project.json`'s own entry for `CEU3Application::Run` describes the swap block but records only its
calls to the *incoming* screen's slots 2, 3 and 5; it does not mention the **outgoing** screen's
slot 4, which is the half that matters here.

So on every one of the three branches:

| branch | resets the game state? | when `in_game` goes to 0 |
| --- | --- | --- |
| `+0x1CD9` game over → `CBackEndIdler` | **no** | `Leave`, `0x2913BC` → `0x262337` |
| `+0x1CDA` exit to menu → `CFrontEnd` | **yes**, `0x65472C` | `CFrontEnd::CFrontEnd` `0x2ED9AF`, 0x49 bytes later in `0x2542B0`; then `Leave` `0x262337`; then `CFrontEnd::Enter` `0x2EFE58`. On the failed-allocation arm the first of those three does not happen and the other two still do. |
| `+0x1CD8` quit | **no** | — (`PostQuitMessage`; the process is leaving) |

**The only branch that wipes the state is also the only one that clears the byte inside itself, and
even when that inner clear is skipped the run loop clears it before the next frame.** `confirmed`.

Two notes on the edges of that table. The three `if`s are **sequential, not exclusive**: if
`+0x1CD9` and `+0x1CDA` were both set in one frame — a tutorial in which the played country loses
its last province — branch A would install a `CBackEndIdler` as the pending screen and branch B
would then overwrite it with a `CFrontEnd` and reset. The outcome is still `in_game == 0`. And
`+0x1CD9` is never cleared once set, which is harmless only because the idler is released at the
swap.

## 5. What sets `+0x1CDA`: the tutorial, and nothing else

This is the "reachable, but only when X" part, and X is specific.

`fieldchain.py --field <offset> --writes` on each of the three flags gives, in full:

```
[reg + 0x1CD8]: 0x64846D  mov dword [ebx+0x1cd8], esi   in CInGameIdler::CInGameIdler (0x6474A0)
                0x64C001  mov byte  [ecx+0x1cd8], 1     in 0x64C000
                0x6547D2  cmp byte  [ebx+0x1cd8], 0     in 0x6542B0

[reg + 0x1CD9]: 0x64C010  mov byte  [ecx+0x1cd9], 1     in 0x64C010
                0x65432E  mov byte  [ebx+0x1cd9], 1     in 0x6542B0
                0x654335  cmp byte  [ebx+0x1cd9], 0     in 0x6542B0

[reg + 0x1CDA]: 0x648473  mov byte  [ebx+0x1cda], 0     in CInGameIdler::CInGameIdler (0x6474A0)
                0x64FF10  mov byte  [esi+0x1cda], 1     in 0x64FC70
                0x654573  cmp byte  [ebx+0x1cda], 0     in 0x6542B0
```

*The negative has its positive control* (the closing section of `TRAPS.md`): the same scan, in the
same class, finds the two **immediate** stores `mov byte [ecx+0x1cd8], 1` and
`mov byte [ecx+0x1cd9], 1` through two different base registers, and the constructor's **dword**
zero at `+0x1CD8` covering all three bytes. So the method sees writes to these fields in both
encodings, and its silence about any other writer is evidence.

`0x64C000` and `0x64C010` are two separate micro-functions, properly padded:

```
0x0064C000  push    ecx
0x0064C001  mov     byte ptr [ecx + 0x1cd8], 1
0x0064C008  call    0x677130
0x0064C00D  ret
0x0064C00E  int3
0x0064C00F  int3
0x0064C010  mov     byte ptr [ecx + 0x1cd9], 1
0x0064C017  ret
```

Reading `CInGameIdler`'s vftable `0x15CEB54` directly, they are **slot 73** (`0x15CEC78`) and
**slot 74** (`0x15CEC7C`); `image.findValue` over `.rdata` finds each address at exactly one
vftable entry, so neither is a fold (trap 4). They are the idler's `RequestQuit` and
`RequestGameOver` hooks, and they are what a menu button would call. `confirmed`.

**`+0x1CDA` has exactly one writer of a one in the whole image, and it is driven by the tutorial.**
`0x64FF10` sits in `0x64FC70` (rva `0x24FC70`, `0x64FC70..0x64FF77`, bare `ret` at `0x64FF76`,
`retsBefore` empty, receiver in **ESI** and no stack argument — trap 11, so `__fastcall ... @ESI`).
`findRefs.py --callers 0x0064FC70` reports **one** caller: `0x655AF4`, inside
`CInGameIdler::Update`, in a block reached unconditionally (same diamond analysis as section 1):

```
0x00655AED  mov     esi, ebx
0x00655AEF  call    0x64f850
0x00655AF4  call    0x64fc70
```

Inside it:

```
0x0064FDFA  cmp     byte ptr [eax + 0xd9d], bl      ; state->tutorial_active == 0 ?
0x0064FE00  je      0x64feb3                        ;   not a tutorial -> never create one
0x0064FE06  slot 91 (+0x16C) on this                ; already have a runner?
0x0064FE14  jne     0x64feb3
0x0064FE97  mov     eax, dword ptr [edi + 0xda0]    ; state->+0xDA0
0x0064FEA6  push    1 ; push eax
0x0064FEAA  slot 90 (+0x168) on this                ; create the runner with that value

0x0064FEB3  slot 91 (+0x16C) on this                ; is a runner live?
0x0064FEC1  je      0x64ff1e
0x0064FEC3  mov     ecx, dword ptr [esi + 0x1d54]
0x0064FEFD  cmp     byte ptr [ecx + 0x3c], bl       ; finished?
0x0064FF00  je      0x64ff17
0x0064FF02  slot 90 (+0x168) on this with (0, 0)    ; destroy it
0x0064FF10  mov     byte ptr [esi + 0x1cda], 1      ; <-- request the main menu
```

The two slots, read off the same vftable:

```
slot 90  0x674FE0   ret 8   (bool create, int value)
   releases this->+0x1D54 through its slot 1 with 1 and nulls it; if create,
   new(0x40) + 0x8E7370, stores it at +0x1D54, then 0x8E7950(it, max(value,1) - 1)

slot 91  0x675080
   0x00675080  xor     eax, eax
   0x00675082  cmp     dword ptr [ecx + 0x1d54], eax
   0x00675088  setne   al
   0x0067508B  ret
```

**So the object at `CInGameIdler +0x1D54` exists only inside a tutorial**, because the only
`create = 1` call sits under `if (state->tutorial_active)`. When its `+0x3C` byte says it is done,
`0x24FC70` destroys it and sets `exit_to_menu_requested`; later in the *same* `Update`,
`0x2542B0` acts on it. `confirmed` for the control flow and the writer census; `likely` for the
name `tutorial_runner`.

**And `CCurrentGameState +0xDA0` is the tutorial number.** Applying `FINDINGS-session.md`
section 1's own discriminator — the `CCurrentGameState` vftable constant `0x15CF674` within the
0x18 bytes before the access — to all **2441** instructions in `.text` whose own displacement is
`0xDA0`: 2434 are copies of the inlined get-or-create accessor, leaving **seven**:

```
0x4CACC5  mov dword [ebx+0xDA0], esi   in 0x4CA740   - another class (trap 12; the record
                                                       already discarded 0x4CACBF for 0xD9C
                                                       the same way)
0x64FE97  mov eax, dword [edi+0xDA0]   in 0x64FC70   - THE ONLY READ IN THE IMAGE
0x67B140  mov dword [esi+0xDA0], eax   in CCurrentGameState::CCurrentGameState  - zero
0x67B59F  mov dword [esi+0xDA0], ebx   in the startup reset 0x27B240            - zero
0x6EFEF5  mov dword [eax+0xDA0], ebx   inside CFrontEnd::Enter (0x6EEF00..0x6F013C; trap 2
                                        makes functionStart answer 0x6EF761)    - zero
0x71D3E2  mov dword [esi+0xDA0], ebx   in 0x71D2D0, CTutorialScreen territory   - zero
0x71D73C  mov dword [eax+0xDA0], edi   in CTutorialScreen::OnTutorialButtonPressed
```

and the last one is the answer. Decoding `CTutorialScreen::OnTutorialButtonPressed` (`0x71D4B0`)
forward from its entry:

```
0x0071D54A  mov     edi, 1
0x0071D58D  mov     edi, 2
0x0071D5D0  mov     edi, 3
0x0071D5E9  mov     edi, 4
0x0071D602  mov     edi, 5
0x0071D61F  mov     edi, 6          ; one arm per tutorial button
...
0x0071D6BA  mov     byte ptr [eax + 0xd9d], 1     ; tutorial_active = 1
...
0x0071D73C  mov     dword ptr [eax + 0xda0], edi  ; and the tutorial number beside it
```

**`CCurrentGameState +0xDA0` is set to 1..6 by the tutorial screen's button handler, next to
`tutorial_active`, and read in exactly one place in the image — the creation of the tutorial
runner.** `confirmed` for both writer and reader; `likely` for the name `tutorial_id`. Trap 14
check, both halves: `grep -n 0xDA0 reversing/ghidra/project.json BiceLib/GameClasses/*.hpp` finds it
only as "zeroes +0xDA0" inside three function comments, with no name on either side, and
`CCurrentGameState.hpp` has `tutorial_active = 0xD9D` and `in_game = 0xDA4` with nothing between
them.

**So X, in full: a tutorial session whose lesson runner has reported itself finished.** That is
reachable in a shipped game — it is what happens at the end of every tutorial — which is why the
question needed answering rather than dismissing. Sections 3 and 4 are why the answer is still no.

## 6. `0x23A460`: what it is, and why it is not "start a game"

`FINDINGS-session.md` section 11 item 2 left this with an unsettled extent and no name. Both are now
settled.

**Extent, and it is trap 2, not trap 3.** Padding of 11 bytes ends at `0x63A45F`; the function
starts at `0x63A460`. `image.retsBefore(0x63A460, 0x63AA10)` returns `[(0x63A83A,'4'),
(0x63AA01,'0xC')]`, the two `ret`s section 11 flagged. The first is its own: `cfg.py 0x63A460 0x3DD`
walks 283 instructions and **no edge from the body lands at or past `0x63A83A`**, and
`image.functionStart(0x63A840)` answers `0x63A840`, a fresh prologue. The two are separated by
**three** `int3` only — so a padding scan looking for a run of five or more walks straight past the
boundary, exactly the `0x685F40`/`0x685FB0` shape `FINDINGS-session.md` section 10 recorded. **New
trap-2 pair for the list: `0x63A460` / `0x63A840`, three bytes of padding.**

So the extent is `0x63A460..0x63A83C` (rva `0x23A460..0x23A83C`), 0x3DD bytes, `ret 4`, **one stack
argument** — a flag at `[ebp+8]`.

The body, read end to end:

```
0x0063A47C  call 0x47FFF0            ; three global registry clears; 0x47D160 walks the
0x0063A481  call 0x4807F0            ;   country database at [0x1A855A4] (+0x168 count,
0x0063A486  call 0x47D160            ;   +0x16C array). Not named here.
0x0063A48B  get-or-create g_CCurrentGameState        ; copy 1 of 5 - dead clear at 0x63A4C8
0x0063A505  call 0x67BAF0            ; CGameState::ResetSession - the full 4026-byte reset
0x0063A50A  if (arg != 0) {
0x0063A519      get-or-create again                  ; copy 2 - dead clear at 0x63A54F
0x0063A582      call 0x685F40        ;   CGameState::ClearPlayers
            }
0x0063A587  call 0x63A330            ; the same helper the savegame loader calls at 0x67CEAD
0x0063A58C  call 0x47FFF0 / 0x4807F0 / 0x47D160     ; the three clears again
0x0063A5A5  get-or-create again                      ; copy 3 - dead clear at 0x63A5DB
0x0063A60E  mov byte [esi+0xD9C], bl ; loaded_from_save = 0
0x0063A691  call 0x445D90            ; GetDefines (trap 8's anchor)
0x0063A696  mov edi, [eax+8]
0x0063A6A2  get-or-create again                      ; copy 4 - dead clear at 0x63A6D8
0x0063A710  mov [eax+0xBDC], edi     ; state->tick = the defines' start tick
0x0063A76C  get-or-create again                      ; copy 5 - dead clear at 0x63A7A2
            ... four cycles of get-or-create / register on the global at [0x1A88BC0],
                ending with 0x5F52A0(that, &state->tick, 0x170DD3C)
0x0063A83A  ret 4
```

It **creates nothing**. It clears three registries, runs the full game-state reset, optionally
clears the player list, clears `loaded_from_save`, and **puts the clock back to the start date from
`defines`**, then re-registers the clock with the object at `[0x1A88BC0]`. That is a wipe to a
neutral pre-game state, not a session build — the session build is `CFrontEnd::LaunchGame` plus
`CInGameIdler::Enter`, as section 5 of `FINDINGS-session.md` already has it. **So the guess "probably
the real 'start a game' entry point" should be withdrawn**, and `FINDINGS-session.md`'s instinct not
to name it on that basis was right.

**And it does not clear `in_game`.** The five `mov byte [reg+0xDA4], 0` instructions marked above are
each inside the `operator new` succeeded arm of a copy of the inlined get-or-create accessor,
guarded on `[0x1A89790] == 0`. The global is non-null from the database stage of startup onward
(`FINDINGS-session.md` section 5: created once per process and never replaced), so none of the five
ever executes. They are five of the 2,772 accessor copies that section 1 of that file accounted for,
and anyone looking inside `0x23A460` for the live clear will find only these. The live clear is in
the caller — section 3.

The argument's meaning falls out of the five call sites:

| site (VA) | enclosing function | argument |
| --- | --- | --- |
| `0x60BB2A` | `0x60BAF0` (rva `0x20BAF0`) | `1` |
| `0x65472C` | `ProcessSessionEndRequests` | `1` |
| `0x70D2FD` | `0x70D010` (rva `0x30D010`, gamesetup) | `1` |
| `0x7147A7` | `0x714100` (rva `0x314100`, `CGameSetup` slot 11) | forwards its own `[ebp+8]` |
| `0x71D98E` | `CTutorialScreen::OnTutorialButtonPressed` | `ebx` = **0** |

Four pass 1; the tutorial screen passes 0, and it is the one caller that is about to **set up** a
game rather than abandon one — it must not clear the player list it is about to fill. Three of the
five also call virtual slot 64 on the outgoing screen immediately beforehand, the same slot the
savegame loader calls at `0x67CE9D`.

**Proposed name: `ResetGameStateToStartDate` (rva `0x23A460`), signature
`void __stdcall ResetGameStateToStartDate(bool clearPlayers)`, `likely`.** `confirmed` for the
extent, for the call to `CGameState::ResetSession`, for the `clearPlayers` branch, for the
`loaded_from_save` clear, for the clock write and for the five dead clears; `likely` for the
argument's name; `inferred` for `0x23A330` and the three registry clears, which were not read.

## 7. A second finding, free: on the game-over frame, `in_game_screen` is a `CBackEndIdler`

`FINDINGS-session.md` section 6 establishes that *"at the main menu, `state->in_game_screen` is a
`CFrontEnd`, not a `CInGameIdler`"*. There is a third case, and it is inside a running game:

`MakeBackEndIdler`, which branch A calls at `0x654518`, calls `CGameState::SetInGameScreen`
(`0x680F30`) at `0x608925` with the fresh `CBackEndIdler`. Branch A does **not** write `in_game`.
So from `0x654525` until `Leave` runs at `0x2913BC`, `in_game` is **1** while
`state->in_game_screen` is a `CBackEndIdler` — that is the tail of `ProcessSessionEndRequests` plus
the whole tail of `CInGameIdler::Update` (`0x65676F..0x656B80`, about 0x410 bytes, which I did not
read). `confirmed` from the call sites.

This is a trap for anything that reads `CInGameIdler` fields through `+0xBE8` gated only on
`in_game`. On the BiceLib side, `CInGameIdler::current()` (`BiceLib/GameClasses/CInGameIdler.cpp`)
is already safe: it checks the object's own vftable against `CInGameIdler::VFTable::CInGameIdler`
before returning it, and its comment says why. `Hooks::MapMode`'s `screenShowingVp()`
(`BiceLib/Hooks/MapModeHooks.cpp`) does **not** check the vftable; it reads `+0xBE8` and then
`CInGameIdler::Offsets::current_map_mode` (`+0xD34`) off it through `Mem::tryRead` and compares
against `VICTORY_POINTS`. That fails safe — a mismatch answers 0, which its own comment anticipates
— but it is a false-positive read of a foreign class at that displacement on this frame and at the
main menu. **No code change is proposed here; that is the DLL side's call.**

## 8. Corrections the merge tool cannot make, because it never overwrites a name

1. **`0x22F080` is named `SessionManager::SessionManager`. It is `CEU3Application::CEU3Application`.**
   The function builds the strings `"HoI3 v4.02"` and `"HoI3"`, calls the base constructor
   `0xA909A0`, and at `0x62F136` writes the vftable **`0x15CD1A8`**, which the RTTI export names
   `CEU3Application` (9 slots at object offset 0, plus a 4-slot secondary at `+8`).
   `retsBefore(0x62F080, 0x62F140)` is empty, so the write is inside it; the padding before
   `0x62F080` is 14 bytes, so the entry is right; and `findRefs --callers` reports exactly one
   caller, `0xA59C43`, at startup. The existing comment's *"No RTTI"* is therefore also wrong.
   `confirmed`.
   - The consequence is the useful part: **`CInGameIdler +0x1790` (currently `session_manager`) and
     `CFrontEnd +0x210` and `CBackEndIdler +0xB8` are the `CEU3Application`.** `project.json`
     already says so elsewhere — the entry for `0x234570` reads *"`mov ecx,[esi+0x210]; call
     0x634570`, so `this` is the application reached off CFrontEnd +0x210"* — and it is what makes
     the `[+0x88] = 1; [+0xE0] = screen` idiom in all three branches of `ProcessSessionEndRequests`
     legible as `CEU3Application::SetNextScreen` (`0x290F40`) inlined, against the loop in
     `CEU3Application::Run` that reads `+0x88`, `+0xE0`, `+0x84` and `+0xF8`. The base constructor
     `0xA909A0` zeroing `+0x88` and `+0xE0` and installing `+0xE4` in the same breath is the
     independent confirmation. The session at `+0x12C` is a field **on** the application, which is
     where the `SessionManager` reading came from.
   - `0x2087C0 SessionManager::MakeBackEndIdler` carries the same misattributed qualifier; the body
     description in its comment is correct.
2. **`CInGameIdler +0x178C` is named `session_sibling` with *"Not identified"*, and the same file
   identifies it.** `CGui +0x30 graphics`'s comment reads *"The CGraphics, and the same object as
   `CInGameIdler+0x178C`. Confirmed live by pointer equality…"*. The two entries disagree inside one
   file. This reading corroborates the `CGui` one independently: `MakeBackEndIdler` writes
   `+0xB0 = gui`, `+0xB4 = graphics`, `+0xB8 = the application`, and `CFrontEnd::CFrontEnd` is handed
   `(graphics, gui, app)` in that order from `[idler+0x178C]`, `[idler+0x60]`, `[idler+0x1790]`.
   **Rename `CInGameIdler +0x178C` to `graphics`**, and `CFrontEnd +0x20C` / `CBackEndIdler +0xB4`
   with it. (Trap 14 one level in: the open note was stale against the same file, not against the
   headers.)
3. **`CCurrentGameState +0xDA4 in_game`'s field comment** should gain the sentence that the deferred
   exit path clears it inside `ProcessSessionEndRequests` itself, at `0x2ED9AF`, 0x49 bytes after
   the game state has already been reset — and that `CInGameIdler::Leave` clears it again at
   `0x2913BC` four instructions after `Update`'s slot returns, which is what makes the path harmless
   even on the allocation-failure arm. Neither fact is in the record anywhere.
4. **`CEU3Application::Run`'s comment** lists the swap block's calls to the *incoming* screen's
   slots 2, 3 and 5. It should also say that the block calls the **outgoing** screen's slot 4
   (`CInGameIdler::Leave` `0x262060` / `CFrontEnd` `0x2F0140`) **first**, at `0x2913BC`, before it
   reads `+0xE0` — that is where `in_game` is cleared on every ordinary exit, and the ordering is
   load-bearing.
5. **`FINDINGS-session.md` section 4's string list for `0x2542B0`** attributes `messagelog_window`
   and `messagecat_*` to it. Those are not referenced in `0x2542B0..0x25492C`. `NoAdress` and
   `InitialSession` are, as `CSession` constructor arguments.
6. **`FINDINGS-session.md` section 5's gloss on `0x23A460`** — *"looks like 'start a game from
   nothing'"* — should be replaced by section 6 above. It starts nothing.
7. **`CEU3Application +0x124` stays unidentified**, and should not be conflated with `+0xE4`.
   `+0x124` is what `CInGameIdler` slot 15 (`0x24D7C0`) returns; `+0xE4` is the 0xC0-byte observable
   installed by the base constructor, whose slot 4 is an empty stub. Both `FINDINGS-guilive.md` and
   `FINDINGS-session.md` are correct that `+0x124` is open.
8. **`FINDINGS-session.md` section 11 items 1 and 2** can both be closed.

## 9. New trap material

- **A new trap-2 pair with a three-byte gap: `0x63A460` / `0x63A840`.** Same failure mode as
  `0x685F40`/`0x685FB0`: the run length of the padding is the bug, not the prologue set. The two
  `ret`s `retsBefore` reports for `0x63A460` are its own and its neighbour's.
- **A clean worked example of trap 3 that is *not* trap 2: `0x2542B0`.** `ret 4` at `0x6547CF`,
  then `0x6547D2` continues the same function, reached by `0x65457A je 0x6547d2` from inside it, and
  the second exit at `0x654929` restores the same SEH slot. The discriminators that settled it were
  the inbound branch and the shared `[esp+0x74]` unwind slot; a fresh prologue would have said the
  opposite.
- **`findRefs --callers` returning zero for a vftable slot is not absence, and the fix is one
  command.** `CInGameIdler::Update` (`0x2559D0`) has **no** `call rel32` anywhere in the image;
  `image.findValue(0x6559D0, '.text')` is empty and `image.findValue(0x6559D0, '.rdata')` returns
  exactly `0x15CEB58` = its class's vftable + 4. So a claim about its caller must be made about a
  slot. The same single `.rdata` hit also discharges trap 4. **Any statement of the form "X is called
  from Y" about a virtual needs the `.rdata` lookup, not the `.text` one.**
- **An indirect call that looks like work and is a 1420-holder stub.** `[[app]+0xE4]->slot4(arg)`
  resolves to `0x20CD50`, a bare `ret 4`. Reading the vftable by hand is cheap and it is the only way
  to know; `[vft + 0x10]` is slot **4**, index 4 — taking it as index 3 produced
  `mov eax,[0x1BEA548]; ret`, a confident-looking global getter, and the wrong function. The
  follow-up check is `findValue` on the vftable constant: if its only writers are the constructor and
  the class's own slot 0, the class cannot have changed under you.
- **`+0xE4` is not the application (trap 12).** `0x2913F0` writes `+0xE0`, `+0xE4`, `+0xF4` and
  `+0xF8` just like `CApplication`'s constructor does, and constructs a **`CIngameLobby`**
  (vftable `0x15CFBA4`, base `CReferenceObject`, with a `CSessionInfoObserver` sub-object at
  `+0x30`). Four matching displacements in the same address band is not an identification.
- **An `operator new` failure arm can be the only branch in a window, and it is worth naming rather
  than smoothing over.** `0x654760` in `ProcessSessionEndRequests` installs a **null** pending screen,
  and the run loop then dereferences it with no test at `0x691404`. Reading the block as
  straight-line is almost right and exactly the kind of "almost" this folder has been bitten by; the
  honest form is "one branch, and here is why it is discounted".
- **`CFrontEnd::Enter`'s extent defeats `functionStart` too.** `image.functionStart(0x6EFEF5)`
  answers `0x6EF761`; the function is `0x6EEF00..0x6F013C` per `project.json`. Same shape as the
  `CInGameIdler::Enter` / `CInGameIdler::CInGameIdler` cases already on the list.
- **A displacement of `0xDA0` is not this class either**, on the same terms as `0xDA4`/`0xD9C`/
  `0xD0C`: 2441 references reduce to seven, and one of those seven is a different class. The
  `0x15CF674`-within-0x18-bytes test is again the discriminator that works.
- **And five dead copies of the same clear in one function.** `0x23A460` contains five
  `mov byte [reg+0xDA4], 0` instructions and not one of them runs. A grep for the clear inside a
  function is not a reading of the function; the accessor idiom has to be recognised first.

## 10. What is not established

- **Whether anything inside `CFrontEnd::CFrontEnd`'s first 0x34F bytes can present a frame.** Nine
  sub-object constructor calls were listed but not walked transitively. This does **not** affect the
  answer, because section 4 closes the question independently of the window's contents — but if
  someone wants the window itself proven empty, that is the remaining work, and the way to do it is
  to find the game's own `Present` call site and run `frontier.py --from 0x6ED660` against it.
- **`CInGameIdler +5`**, the byte that suppresses the elimination detector. Read once, at
  `0x6542D9`; no writer sought. It is low enough to belong to a `CEU3Idler` base.
- **The class of the 0x40-byte `tutorial_runner` at `CInGameIdler +0x1D54`**, and what its `+0x38`
  and `+0x3C` are. Its constructor is `0x8E7370`, `0x8E7950(it, n)` sets something from the tutorial
  id, and `0x833F40`/`0x8E72B0` are consulted on `+0x20` and on `[+0x38]`. None of those four was
  read. The name rests on the creation gate, not on the object.
- **The class of the 0xC0-byte object at `CEU3Application +0xE4`.** No RTTI for any of its five
  vftables (`0x15FDDC0`, `0x15FDE20`, `0x15FDE30`, `0x15FDE40`, `0x15FDE50`); its constructor is
  `0xB32CB0`. Only slot 4 was resolved, which was all this question needed. **And `+0x124`, the
  neighbouring field `CInGameIdler` slot 15 returns, remains unidentified.**
- **The tail of `CInGameIdler::Update`, `0x65676F..0x656B80`** (about 0x410 bytes), which on the
  exit-to-menu branch runs with the game state already wiped and `in_game` already 0, and on the
  game-over branch runs with `in_game_screen` pointing at a `CBackEndIdler`. That is the game's own
  business, but it was not read and it is where a crash on exit would live if there is one.
- **`0x23A330`**, called both by `ResetGameStateToStartDate` and by the savegame loader
  (`0x67CEAD`); and the three registry clears `0x47FFF0`, `0x4807F0`, `0x47D160`. Not read.
- **Which `defines` entry `[GetDefines()+8]` is** — the value `ResetGameStateToStartDate` writes
  into `state->tick`. It is read as a bare dword off the defines object, not through a block
  pointer, so it is a scalar; `definesMap.py` would name it.
- **The global at `[0x1A88BC0]`** that the reset registers the clock with through
  `0x5F52A0(it, &state->tick, 0x170DD3C)`, and the byte `[0x1A857EF]` the quit branch sets, and the
  byte `[0x1A857BF]` that `0x24FC70` moves around the tutorial block. Three unread globals.
- **Whether `CGameState +0xDA0` wants the same name as `CCurrentGameState +0xDA0`.** The field is
  written by the `CCurrentGameState` constructor, so it belongs to the derived class; but
  `project.json` carries both structs and `FINDINGS-session.md` section 9 found the two halves of
  `+0xD9D` disagreeing for exactly this reason. Only `CCurrentGameState` is proposed below.
