# The window's children: `+0x414` is the subwindow map, `+0x2FC` is not, and every `LoadKey` token has a container

Read on 2026-10-02 **with no running game**. Addresses are **virtual** (image base `0x400000`) with
the rva beside anything the record needs — trap 1. Offsets on `CFixedWindow` are **complete-object**
offsets, matching `project.json`; where a body uses the `CGuiObject`-relative form the complete one
is `0x18` higher and both are given.

## In one line

`CFixedWindow +0x414` is the window's **subwindow map** — a `std::vector` of `0x20`-byte
`{Hoi3CString name; CFixedWindow* window}` entries, filled by the constructor from the
`windowType` keyword's declared-name list at `CWindowType +0x214`, and called a *subwindow* by the
engine's own warning at `fixedwindow.cpp` line 1042. So **`+0x2FC` is not the child-window
container** and `project.json`'s `child_windows_begin` is misplaced as well as misnamed: `+0x2FC`
is written only by `CFixedWindow::AttachChild` (slot 22) and erased only by slot 23, which is
runtime attachment, and the same `AttachChild` body writes the `+0x74` list — so
**`attached_children_head` is right, and is now confirmed rather than inferred.** Reading
`CWindowType::LoadKey`'s two byte/jump-table pairs out gives all **28** keywords with their
containers, which turns `FINDINGS-guistatic.md`'s three `likely`s into `confirmed`s
(`3dButtonType` → registry `+0x360`, `threeDguiType` → registry `+0x3F0`,
`multiSpriteButtonType` → vector `+0x27C`) and corrects two more of its rows: `+0x194` is
`multiSpriteButtonType`, not the second of `guiButtonType`/`checkboxType`, and `+0x204` is
`checkboxType`. There are **thirteen** per-kind containers, at `+0x184`..`+0x244`, **not fourteen
from `+0x174`**; `+0x174` is a 4-stride pointer vector and the fourteenth participant is the
all-kinds declaration-order list at `+0x25C`. `CWindowType` is `0x2A4` bytes, `CFixedWindow` is
`0x4C8`, and the whole `CWindowType` scalar layout falls out of the switch.

---

## 1. The two lookup functions (guistatic open item 5, first half)

Both are template bodies that take their container as an argument, and **all nine call sites in
the image pass `CFixedWindow +0x414`**. The element is `0x20` bytes,
`{Hoi3CString name at +0; CFixedWindow* window at +0x1C}`.

### `0xAC4580` (rva `0x6C4580`) — `SubWindowMap_Contains`

    bool __stdcall SubWindowMap_Contains(void* map, Hoi3CString* name)      ret 8

A linear scan from `[map]` to `[map+4]` at a `0x20` stride. Each element's `+0x10`/`+0x14`
size/capacity pair is read exactly as the key's is (`0xAC45A4`/`0xAC45AC` against
`0xAC45B7`/`0xAC45C9`), which is MSVC's `std::string` layout with the SSO branch on both sides;
the compare is `0x415F70`, a `memcmp` with the two pointers in **ECX and EDX** and the length
pushed. Returns `al`: 1 at `0xAC45F7`, 0 at `0xAC4604` when the walk runs off the end. Nothing in
`ecx`, two stack arguments, `ret 8` on both exits — `__stdcall`.

Four callers: `0xAC1004` (the constructor's resolve loop), `0xAC2BCD` (slot 12), `0xAC2C51`
(slot 27), `0xAC3FC7` (the `CGuiObject` slot-37 descendant test).

### `0xAC4640` (rva `0x6C4640`) — `SubWindowMap_FindOrAdd`

    CFixedWindow** __stdcall SubWindowMap_FindOrAdd(void* map, Hoi3CString* name)    ret 8

The same scan, but it returns a **pointer to the value slot** — `lea eax, [edi + 0x1C]` at
`0xAC46D0` — and **on a miss it appends a default entry under that name and returns the new
slot**. The miss path builds an empty string (`0x401BD0`), hands the pair to the vector insert
`0x542FC0` (which takes the vector in **EDI**, so `mov edi, esi` first at `0xAC4716`), and then
computes `begin + ((end - begin) & ~0x1F) - 4`. That mask is the compiler's divide-by-`0x20` and
is independent corroboration of the element size. Own SEH frame, handler `0xC14BD8`.

Because it inserts, it is never safe alone, and **four of its five callers guard it with
`SubWindowMap_Contains` five bytes earlier**. The fifth, `0x7FC3FC`, calls it unguarded on
`[this+0xA8] + 0x414` with a name made by converting an integer to a decimal string (`0xB9A0C4`,
radix 10 — *numbered* subwindows), then dereferences `[eax]` and calls slot 20 on it, so that
site relies on the entry existing. `0x7FC350` is on the frontier.

### Why these names, and the honest caveat

The bodies are generic; the name is from the only container they are ever used on, and from the
engine's own word for it. `0xAC2C20` logs

    'Warning: Atempt to access nonexistant subwindow '   (0x1601DF4, the misspelling is the engine's)

from `'fixedwindow.cpp'` (`0x1601DB0`) line `0x412` = **1042** when `Contains` says no, and
`+0x414` is the only container that function touches. That is a name read off the bytes.

### The third one, which the brief did not ask for

`0xAC44F0` (rva `0x6C44F0`) — `SubWindowMap_Add`:

    void __stdcall SubWindowMap_Add(Hoi3CString* name, CFixedWindow** window, void* map@EDI)   ret 8

Builds the `0x20`-byte pair on its own stack — string assigned from `name` at `+0`, then `*window`
written at `+0x1C` — and hands it to `0x542FC0`, which wants the vector in **EDI**, so the
container reaches this function in EDI and never touches the stack. The `@EDI` matches the
already-recorded `std::vector_pushBackByAddress` (`0x46CC20`), which is the pointer-element
version of the same template. Exactly one caller: `0xAC0C86`, three instructions after
`lea edi, [ebx + 0x414]`.

---

## 2. `+0x414` against `+0x2FC` — the verdict, with the bytes

### Who fills `+0x414`

The `CFixedWindow` constructor, at `0xAC0C33`..`0xAC0C90`:

```
0x00AC0C33  mov  ecx, [ebp + 0x44]       ; <- &CWindowType + 0x214
0x00AC0C36  mov  esi, [ecx]              ; head of the declared-name list
0x00AC0C3A  je   0xac0c92                ; empty: skip
loop:
0x00AC0C4A  sub  esp, 0x1c               ; an Hoi3CString by value on the stack
0x00AC0C64  push esi                     ;   the node, whose name is at +0
0x00AC0C68  call 0x401bd0                ;   std::string::assignString
0x00AC0C6D  mov  ecx, [ebx + 0x88]       ; the window's own CWindowType
0x00AC0C73  call 0xac76d0                ;   CWindowType::CreateWindow
0x00AC0C7C  push esi                     ;   the name again, as the key
0x00AC0C7D  lea  edi, [ebx + 0x414]      ;   <- the subwindow map
0x00AC0C83  mov  [ebp + 0x6c], eax       ;   the built window
0x00AC0C86  call 0xac44f0                ;   SubWindowMap_Add
0x00AC0C8B  mov  esi, [esi + 0x20]       ;   next name
0x00AC0C90  jne  0xac0c3c
```

`[ebp+0x44]` is `&CWindowType + 0x214`, and that is **counted, not guessed**: the window factory
`0xAC4FE0` makes exactly **26** pushes between `0xAC501A` and `0xAC50D2` with no intervening
`call` and no `esp` adjustment, which matches the constructor's `ret 0x68` (26 × 4), and the push
that lands at `[ebp+0x44]` is `lea ecx, [esi + 0x214]` at `0xAC506E` with `esi` the `CWindowType`.

`0xAC76D0` resolves the name in the gui-type tree embedded at `CWindowType +0x150` (vftable
`0x1602108`, the same embedded tree as `CGui +0x34`), falls back to `[this+0x14C]`'s slot 18 with
the type's own `parent` string at `+0x68`, calls `0xAC4FE0` — `operator new(0x4C8)` then
`CFixedWindow::CFixedWindow` — adjusts with `lea ebx, [esi + 0x18]` and registers the object with
the `CGui` through slot 16. **So a subwindow is a full `CFixedWindow`**, and `CFixedWindow` is
`0x4C8` bytes.

### The element layout, read three independent ways

1. `add edi, 0x20` in `0xAC4580`, `0xAC4640`, `0xAC27C8` (Show) and `0xAC3FF0` (slot 37).
2. `lea eax, [edi + 0x1C]` as the value slot in `0xAC4640`.
3. `and ecx, 0xFFFFFFE0` in both `0xAC4640` and the insert `0x542FC0`.

And the value really is a **complete** `CFixedWindow*`, which is the point: Show's walk reads it
and dispatches on its `CGuiObject` subobject —

```
0x00AC27D0  cmp  edi, [esi + 0x400]      ; esi is the CGuiObject, so +0x3FC/+0x400 = complete +0x414/+0x418
0x00AC27D8  mov  ecx, [edi + 0x1c]       ; the window
0x00AC27DB  mov  edx, [ecx + 0x18]       ;   its CGuiObject vftable
0x00AC27DE  mov  eax, [edx + 0x34]       ;   slot 13
0x00AC27E1  add  ecx, 0x18               ;   this = window + 0x18
0x00AC27E4  call eax
0x00AC27E6  add  edi, 0x20
```

`TWindow : CWindowObservable(0), CGuiObject(24)` in the RTTI export is why the adjustment is
`0x18`, and `CFixedWindow`'s own constructor uses the same one (`lea eax, [ebx + 0x18];
call 0xA7FF60` at `0xABF923`).

### Who fills `+0x2FC` — and it is not the constructor

A scan of `0xABE000`..`0xAC9000` from `int3`-delimited entries for displacements
`0x2FC`/`0x300`/`0x304`/`0x30C` finds **no build block in the constructor at all**; its only
`+0x2FC` instructions are the zeroing at `0xABFB50` and the resolve loop's step-9 `lea` at
`0xAC0F4A`. The writer is `CFixedWindow::AttachChild` (`0xAC2F90`, primary slot 22), and it writes
**both** halves in one body:

```
0x00AC2F9B  lea  edi, [esi + 0x30c]      ; the names vector
0x00AC2FA1  call 0x417620                ;   push_back the name
0x00AC2FA6  lea  edi, [esi + 0x2fc]      ; the children vector
0x00AC2FAF  call 0x86cc20                ;   push_back the child pointer
0x00AC2FB4  mov  edi, [esi + 0x78]       ; and then the +0x74 list's tail
0x00AC2FB7  push 0x10
0x00AC2FB9  call 0xb9602f                ;   operator new(0x10) for the node
...
0x00AC2FEE  mov  [esi + 0x74], eax       ;   head, when the count was zero
```

Slot 23 (`0xAC3020`) is the matching erase: it linear-searches `+0x2FC` for the pointer,
`add [edi+0x300], -4`, and removes the matching name from `+0x30C`.

So `+0x2FC` and `+0x74` are **one pair**, written by one function, and `FINDINGS-guilive.md`'s
live measurement of that vector — 46 buttons, 20 child windows, 1 icon across 206 windows — is
exactly what "whatever game code attached at run time" should look like. Because the constructor
never fills `+0x2FC`, step 9 of its resolve loop can never hit, which is why **the `+0x74` list
can only ever be filled by `AttachChild`** — and that is the whole content of the name
`attached_children_head`.

### So: which one does the game mean by a window's children?

Both, in two different senses, and the record needs both names to say which:

| | | |
| --- | --- | --- |
| `+0x414` (+ the `+0x64` list) | **subwindows** | the child *windows* the `.gui` file declares under `windowType`, built by the constructor, indexed by name, reached by `GetSubWindow` |
| `+0x2FC` (+ the `+0x74` list) | **attached children** | whatever game code hands to slot 22 at run time, of any kind |

`attached_children_head` survives, upgraded from inferred to confirmed. `child_windows_begin`
does not: it wants to be `attached_children_begin`, with `+0x300`/`+0x304` the end and capacity
end and `+0x30C` the parallel names vector.

### The two functions that read the map

- `0xAC2C20` (rva `0x6C2C20`) = **`CFixedWindow::GetSubWindow`**,
  `CFixedWindow* __thiscall (Hoi3CString* name)`, `ret 4`, primary slot 27. `Contains`, then
  `FindOrAdd`, then `mov eax, [eax]` — **no `+0x18`**, so it returns the complete window. On a
  miss it logs the warning quoted above and returns 0 at `0xAC2D6A`.
- `0xAC2AF0` (rva `0x6C2AF0`) = **`CFixedWindow::FindChild`**,
  `CGuiObject* __thiscall (Hoi3CString* name)`, `ret 4`, primary slot 12 — the general lookup, in
  this fixed order, stopping at the first hit:

  | # | container | how |
  | --- | --- | --- |
  | 1 | vector pair `+0x25C`/`+0x26C` (`guiButtonType`) | `0xAC47C0` |
  | 2 | vector pair `+0x27C`/`+0x28C` (`multiSpriteButtonType`) | `0xAC47C0` |
  | 3 | registry `+0x360` (`3dButtonType`) | slot 1 |
  | 4 | registry `+0x33C` (`textBoxType`) | slot 1 |
  | 5 | registry `+0x384` (`editBoxType`) | slot 1 |
  | 6 | **map `+0x414` (subwindows)** | result `[eax] + 0x18` |
  | 7 | vector pair `+0x2FC`/`+0x30C` (attached) | `0xAC47C0` |

  The `+0x18` on step 6 **and nowhere else** is the discriminator: a subwindow is stored complete
  and has to be converted; everything else is already a `CGuiObject*`. A null value is returned as
  0, not as `0x18`. The three early `ret 4`s inside the body (`0xAC2B67`, `0xAC2B95`, `0xAC2BC3`)
  are the registry hits, not abutting functions — `retsBefore` plus the shared epilogue settles it
  (trap 2).

Both bodies appear in exactly one RTTI table, `CEU3DialogGui` slots 27 and 12 at object offset 0,
because the GUI framework was compiled without RTTI; reading `0x1601F88 + 27*4` and
`0x1601F88 + 12*4` out of the image gives the same two addresses. Neither has a direct caller.

### The other walkers, for the record

`+0x414` is also walked by primary slots 20 (`0xAC1F60`), 28 (`0xAC2DE0`), 31, 32, 39, 47, by
Show (`0xAC2690`) and Hide (`0xAC2270`), by `0xAC3620`/`0xAC38F0`, and by `CGuiObject` slot 37
(`0xAC3D10`, object offset 24) — which first asks the map for the name and then recurses over
every entry, so the subwindow tree is what "is this object a descendant" descends. All of them
read `[entry+0x1C]` and dispatch on `value + 0x18`. The destructor `0xAC1280` tears the vector
down at `0xAC13D2`..`0xAC140A`.

---

## 3. Every `CWindowType::LoadKey` token, and its container (guistatic open item 4)

`CWindowType::LoadKey` is rva `0x6C55E0`, already `confirmed` in `project.json`. Its dispatch is

```
0x00AC5603  cmp  eax, 0x140              ; token 320 exactly -> 0xAC64F8
0x00AC5614  lea  ecx, [eax - 0x2e]       ; tokens 46..193
0x00AC5617  cmp  ecx, 0x93
0x00AC5623  movzx ecx, byte ptr [ecx + 0xac6ab8]
0x00AC562A  jmp  dword ptr [ecx*4 + 0xac6a5c]
0x00AC651C  lea  ecx, [eax - 0x141]      ; tokens 321..420
0x00AC6522  cmp  ecx, 0x63
0x00AC652B  movzx edx, byte ptr [ecx + 0xac6b64]
0x00AC6532  jmp  dword ptr [edx*4 + 0xac6b4c]
```

Both byte/jump-table pairs read out, the default (`0xAC6A3B`) dropped and the tokens resolved
through `ghidra/saveTokens.json`, give **28 keywords** — exactly the count `switchmap.py` reports.

### The thirteen child kinds

| `CWindowType` | keyword | token | child type ctor | copied to `CFixedWindow` |
| --- | --- | --- | --- | --- |
| `+0x184` | `guiButtonType` | 124 | `0xB2DA90` | vector `+0x25C`/`+0x26C` |
| `+0x194` | **`multiSpriteButtonType`** | 177 | `0xB2DA90` | vector `+0x27C`/`+0x28C` |
| `+0x1A4` | **`3dButtonType`** | 168 | `0xB30490` | names `+0x434` → registry `+0x360` |
| `+0x1B4` | `textBoxType` | 130 | `0xB31940` | names `+0x424` → registry `+0x33C` |
| `+0x1C4` | `instantTextBoxType` | 327 | `0xB2A820` | vector `+0x2BC`/`+0x2CC` |
| `+0x1D4` | `scrollbarType` | 137 | `0xB28120` | names `+0x464` → registry `+0x3CC` |
| `+0x1E4` | `editBoxType` | 167 | `0xB29DC0` | names `+0x444` → registry `+0x384` |
| `+0x1F4` | `iconType` | 179 | `0xAC81F0` | vector `+0x29C`/`+0x2AC` |
| `+0x204` | **`checkboxType`** | 193 | `0xB2DA90` | vector `+0x31C`/`+0x32C` |
| `+0x214` | **`windowType`** | 152 | **`0xAC48C0` = `CWindowType::CWindowType`** | **map `+0x414`** |
| `+0x224` | `listBoxType` | 166 | `0xB2B030` | names `+0x454` → registry `+0x3A8` |
| `+0x234` | **`threeDguiType`** | 359 | — (block `0xAC655B`) | names `+0x474` → registry `+0x3F0` |
| `+0x244` | `OverlappingElementsBoxType` | 374 | `0xB2A430` | vector `+0x2DC`/`+0x2EC` |

Each is `{head, tail, count, byte}` at a `0x10` stride, and the **nodes are `0x28` bytes**, not
`0x24`: `push 0x28; call operator_new` at `0xAC629A`, the child's name as an `Hoi3CString` at
`+0`, `prev` at `+0x1C`, `next` at `+0x20`, a byte at `+0x24`, with the old tail's `+0x20`
patched at `0xAC6312`. **The lists hold names, not objects** — each built child type goes into the
single gui-type tree at `CWindowType +0x150`, which is why `CreateWindow` and the six per-kind
widget factories all look a name up there.

The *window*-side half of each row is pinned by the same 26-push count as `+0x214`:

| factory push | arg slot | constructor reads it at | and then writes |
| --- | --- | --- | --- |
| `lea edx,[esi+0x184]` `0xAC50AE` | `[ebp+0x20]` | `0xAC0822` | `lea esi,[ebx+0x25C]` |
| `lea ecx,[esi+0x194]` `0xAC50A7` | `[ebp+0x24]` | `0xAC08FB` | `lea esi,[ebx+0x27C]` |
| `lea ecx,[esi+0x1A4]` `0xAC5091` | `[ebp+0x34]` | `0xABFD20` | `[ebx+0x434]` |
| `lea edx,[esi+0x1B4]` `0xAC50A0` | `[ebp+0x28]` | `0xABFCE2` | `[ebx+0x424]` |
| `lea ecx,[esi+0x1C4]` `0xAC5099` | `[ebp+0x2C]` | `0xAC062D` | `lea esi,[ebx+0x2BC]` |
| `lea ecx,[esi+0x1D4]` `0xAC5050` | `[ebp+0x5C]` | `0xABFDDD` | `[ebx+0x464]` |
| `lea edx,[esi+0x1E4]` `0xAC5089` | `[ebp+0x38]` | `0xABFD5F` | `[ebx+0x444]` |
| `lea ecx,[esi+0x1F4]` `0xAC5082` | `[ebp+0x3C]` | `0xAC0212` | `lea esi,[ebx+0x29C]` |
| `lea edx,[esi+0x204]` `0xAC507B` | `[ebp+0x40]` | `0xAC0B00` | `lea esi,[ebx+0x31C]` |
| `lea ecx,[esi+0x214]` `0xAC506E` | `[ebp+0x44]` | `0xAC0C33` | `lea edi,[ebx+0x414]` |
| `lea edx,[esi+0x224]` `0xAC506D` | `[ebp+0x48]` | `0xABFD9E` | `[ebx+0x454]` |
| `lea edx,[esi+0x234]` `0xAC5049` | `[ebp+0x60]` | `0xABFE1C` | `[ebx+0x474]` |
| `lea edx,[esi+0x244]` `0xAC5041` | `[ebp+0x68]` | `0xAC0435` | `lea esi,[ebx+0x2DC]` |
| `lea edx,[esi+0x25C]` `0xAC5057` | `[ebp+0x58]` | `0xABFDDB` | the resolve loop |

### The three `likely`s, settled

- **`3dButtonType` → registry `+0x360`.** Token 168's list is `+0x1A4`; the constructor copies
  `+0x1A4` into the window's `+0x434` name list, which `project.json` already calls
  `three_d_button_names`, and that list is the source for the registry at `+0x360` —
  `registry_unused`. **`confirmed`**, independently of guistatic's two readings and agreeing with
  both. Its child type ctor is `0xB30490` / vftable `0x1606C04`, the "type class §3 never saw".
- **`threeDguiType` → registry `+0x3F0`.** Token 359's list is `+0x234` → window `+0x474`
  (`three_d_gui_names`) → registry `+0x3F0` (`registry_unused_2`). **`confirmed`.**
- **`multiSpriteButtonType` → vector `+0x27C`.** Token 177's list is `+0x194` → window `+0x27C`
  (`child_vector_unused`). **`confirmed`.**

And the emptiness still stands with its cause, re-run case-sensitively over both `interface/`
trees: `3dButtonType` 0/0 files, `multiSpriteButtonType` 0/0, `threeDguiType` 0/0, against
`windowType` 50/77 in the same grep as the positive control.

### Two of guistatic's rows corrected

`FINDINGS-guistatic.md` §2 put `+0x184` and `+0x194` as "`guiButtonType` or `checkboxType`" and
"the other of those two", and `+0x204` as "the **third** user of the button type class". The
tokens say `+0x184` = `guiButtonType`, `+0x194` = `multiSpriteButtonType`, `+0x204` =
`checkboxType`. All three really do share the `0xB2DA90` type class — a checkbox type *is* a
button type, and a multi-sprite button is a variant of one — which is exactly why the type class
alone could not separate them and why the keyword had to be read.

### And "fourteen containers from `+0x174`" is wrong twice

There are **thirteen**, and they run `+0x184`..`+0x244`. `CWindowType +0x174`/`+0x178`/`+0x17C`
is a separate three-pointer `std::vector` — zeroed by the destructor `0xAC4CE0`, walked by
`CWindowType` slot 7 (`0xAC5350`) with `add esi, 4` and `mov ecx, [esi]`, so a **pointer vector at
a 4-byte stride**, not a `0x10` container, and `LoadKey` never touches it. The fourteenth
participant is the **all-kinds declaration-order list at `+0x25C`**: every one of the thirteen
per-kind cases appends to its own list and then `jmp 0xAC58B5` into one shared tail that appends
the same name there, and `&this+0x25C` is what the factory hands the constructor as the argument
its resolve loop walks. That is what lets the loop place children in declaration order *across*
kinds.

### The scalar keywords, which come free

| keyword | token | `CWindowType` | reader |
| --- | --- | --- | --- |
| `parent` | 132 | `+0x68` `Hoi3CString` | `ParseString` |
| `background` | 153 | `+0x84` `Hoi3CString` | `ParseString` |
| `position` | 75 | `+0xA0` `int[2]` | `0xA7B670` — already recorded |
| `size` | 46 | `+0xA8` `int[2]` | `0xA7B670` — already recorded |
| `verticalScrollbar` | 158 | `+0xB0` `Hoi3CString` | `ParseString` |
| `horizontalScrollbar` | 159 | `+0xCC` `Hoi3CString` | `ParseString` |
| `horizontalBorder` | 163 | `+0xE8` `Hoi3CString` | `ParseString` |
| `verticalBorder` | 164 | `+0x104` `Hoi3CString` | `ParseString` |
| `priority` | 138 | `+0x124` `int` | `0x67B640` — unnamed |
| `moveable` | 154 | `+0x128` `int` | `ParseInt` |
| `fullScreen` | 47 | `+0x254` `bool` | `ParseBool` |
| `click_to_front` | 420 | `+0x255` `bool` | `ParseBool` |
| `orientation` | 191 | `+0x258` `void*` | string → `0xB29CC0` → stored |
| `upsound` | 320 | `+0x26C` `Hoi3CString` | `ParseString` |
| `downsound` | 321 | `+0x288` `Hoi3CString` | `ParseString` |

The string block chains exactly at `Hoi3CString`'s `0x1C`: `0x68 → 0x84 → 0xA0`, then
`0xB0 → 0xCC → 0xE8 → 0x104`, ending at `0x120` with `0x124` the next scalar; and
`0x288 + 0x1C = 0x2A4`, the `operator new` size, so `down_sound` is the last member. `moveable`
is an **int**, not a bool — `ParseInt`, not `ParseBool` — although the factory reads only its low
word.

---

## 4. `CWindowType` itself

- `0xAC48C0` (rva `0x6C48C0`) = **`CWindowType::CWindowType`**,
  `CWindowType* __stdcall (CWindowType* this, void* inherited@ECX, CGui* gui@EDX)`, `ret 4`.
  `this` arrives on the **stack** at `[ebp+8]` and comes back in `eax`; `ecx` and `edx` are
  untouched from entry to the stores at `0xAC49BC`/`0xAC49C2` (scanned), so both really are
  register arguments. It writes vftable `0x1602178` at `+0` and `0x16021A4` at `+0x64`, the type
  id `0x18D` at `+4`, the embedded gui-type tree at `+0x150`, and zeroes the whole child area.
  **`0x1602178` is `CWindowType`'s table because slot 4 of it is `0xAC55E0`,
  `CWindowType::LoadKey`**, which `project.json` already holds. `0xAC4C40` is the
  scalar-deleting destructor that follows, and it is slot 0 of the same table, which is what says
  the `ret 4` at `0xAC4C2E` is the real end (trap 3).
- **`CWindowType` is `0x2A4` bytes** (`push 0x2A4` at `0xAC6212`), and the class is **recursive**:
  the `windowType` case builds a `CWindowType`.
- `0xAC76D0` (rva `0x6C76D0`) = **`CWindowType::CreateWindow`**,
  `CFixedWindow* __thiscall (Hoi3CString name, void* param2, void* param3)`, `ret 0x24` — `0x1C`
  for the by-value string plus two dwords. Two callers: `0xAC0C73` and `0xAC3C27`.
- `CWindowType +0x14C` is the `CGui`, **`inferred`** (likely): it is the object `CreateWindow`
  calls slot 18 on for a default type and slot 16 on to register the new gui object, which is what
  `CGui` does elsewhere, but nothing here pins the class. `+0x148` is unidentified and is left
  unnamed rather than guessed.

---

## What is not established

1. **`CWindowType +0x148`.** Inherited from the parent type through ECX and stored; the window
   factory passes it on as the constructor's second argument. Never read in anything I decoded.
   *What would settle it:* read `0xAC4FE0` properly — its six stack arguments are the last gap in
   this chain.
2. **`0xAC4FE0`, the window factory, is read but not named.** `__stdcall`, `ret 0x18`, six stack
   arguments plus the `CWindowType` in **ESI**; `operator new(0x4C8)` then
   `CFixedWindow::CFixedWindow` with 26 pushes. I can say what every push *is* in terms of the
   type's fields but not what four of the six arguments *mean*, so it is on the frontier rather
   than in the record. Inventing names for them is exactly what the contract says not to do.
3. **`threeDguiType`'s child type constructor.** The other twelve cases call one identifiable
   constructor; token 359's block (`0xAC655B`) writes the window type's own `+0x84`/`+0x88`/
   `+0x90`/`+0x94` as well as appending to `+0x234`, and the type object it builds was not
   isolated. *Static, and small.*
4. **`0x415F70` and `0x542FC0` are CRT/STL template bodies and are unnamed.** `0x415F70` is a
   `memcmp` with the pointers in ECX and EDX and the length pushed `__cdecl`; `0x542FC0` is a
   `std::vector::insert` for `0x20`-byte elements with the vector in EDI. Both want a fold count
   before a name (trap 4), which I did not take.
5. **The `.gui` key lookup looks case-insensitive, and that is `inferred`.** The compiled token
   table spells the keyword `listBoxType`; a case-sensitive grep finds `listboxType` in 36 of the
   game's `.gui` files and 55 of the mod's against `listBoxType` in 3 and 5. Since
   `FINDINGS-guilive.md` measured 78 live list-box registry entries across 206 windows, the
   lower-case spelling cannot be being dropped. *What would settle it:* read the tokenizer's
   lookup. This matters for the record because the engine's spelling and the data's spelling
   differ, and a case-sensitive sweep for a keyword will under-count — which is the same shape of
   error as the `Checkbox`/`CheckBox` one.
6. **The window-side name-list node size.** The *type*-side nodes are `0x28`
   (`operator new(0x28)`); the window's copies are made by `0x409D00`, whose allocation I did not
   read. `FINDINGS-guistatic.md` says `0x24` for the window side. The shapes are otherwise
   identical (next at `+0x20`), so `0x28` is likely for both, but I did not check it and the two
   claims are about different lists.
7. **Nothing here was observed running.** Every address, offset, size and vftable is read out of
   `hoi3_tfh.exe` and is build-specific. The only live numbers quoted are
   `FINDINGS-guilive.md`'s, cited as its; the only data-file numbers are the `interface/` greps,
   specific to this BlackICE install.

---

## Frontier

`0x6C4FE0` (the window factory, `ret 0x18`, `type@ESI`), `0x6C1F60` (primary slot 20),
`0x6C3D10` (`CGuiObject` slot 37, the recursive descendant test), `0x6C3020` (primary slot 23,
the detach/erase), `0x6C47C0` (the vector-pair by-name lookup, used by seven kinds),
`0x6C5350` (`CWindowType` slot 7, walks `+0x174`), `0x6C4CE0` and `0x6C4C40`
(`CWindowType`'s destructor and its deleting thunk), `0x6C1280` (`CFixedWindow`'s destructor),
`0x6C2DA0`, `0x6C2DE0`, `0x6C3200`, `0x6C3620`, `0x6C38F0`, `0x6C33D0`, `0x6C3BC0` (the other
`+0x414` walkers), `0x142FC0` (`vector::insert`, `0x20` elements, `vector@EDI`),
`0x15F70` (`memcmp`, pointers in ECX/EDX), `0x17620` (`vector<Hoi3CString>::push_back`),
`0x9D00` (the name-list node copy), `0x67B640` (`priority`'s parse helper),
`0x67B670` (the `{x=,y=}` int-pair reader — **not** the recorded `ParseIntPair` at `0x909C0`),
`0x67C3F0`, `0x729CC0` (`orientation`), `0x72B030`, `0x72A430`, `0x730490` (the list-box,
overlapping-box and 3d-button type constructors), `0x3FC350` (the one game-code user of the
subwindow map, keyed by a decimal integer).

---

## Transcription note

Read and written by wave 10's agent C; transcribed by the session that collected the wave, because
an agent's `Write` is refused for this path. The claims spot-checked independently before
transcription, all confirming: the `+0x74` / `+0x2FC` field names as `project.json` actually holds
them, the `'Atempt to access nonexistant subwindow'` string (one hit, at `0x1601DFD`) and
`'fixedwindow.cpp'` (one hit, `0x1601DB0`), the constructor's build loop at `0xAC0C33` ending
`lea edi, [ebx + 0x414]; call 0xac44f0`, `AttachChild` at `0xAC2F90` writing `+0x30C`, `+0x2FC`,
`+0x78` and `+0x74` in one body, and all sixteen token numbers in sections 3's tables against
`ghidra/saveTokens.json`.

**The brief this agent was given was wrong about where wave 9's name landed** — it said
`attached_children_head` sits on `+0x2FC` and that `+0x414` might unseat it. `project.json` has
`attached_children_head` on **`+0x74`** and `child_windows_begin` on **`+0x2FC`**, which is a
different claim and a weaker one. The agent checked rather than accepting it, which is why the
answer came back as "the name survives and is now confirmed" instead of a hunt for a replacement.
