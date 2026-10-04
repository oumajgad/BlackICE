# The GUI layer read statically: two child lists, the two empty registries, and the ledger's class

Read on 2026-10-02 **with no running game**, which is the point: all four items were written as live
questions in `findings/FINDINGS-guilive.md` and `findings/FINDINGS-uinumbers2.md`, and all four had a
static route. Addresses are **virtual** (image base `0x400000`) with the rva beside anything the
record needs — trap 1. Offsets on `CFixedWindow` are **complete-object** offsets, matching
`project.json`'s existing entries; where `FINDINGS-guilive.md` states a `CGuiObject`-relative offset
the complete one is `0x18` higher, and both are given.

## In one line

`CFixedWindow` carries **two ordered intrusive lists of `CGuiObject*` children** at complete `+0x64`
and `+0x74` (= `FINDINGS-guilive.md`'s `+0x4C` and `+0x5C`), each `{head, tail, count, flag}` with
`0x10`-byte nodes `{value, prev, next, bool}` — **not** `0x18`-byte nodes, and the "3D objects and
billboards indiscriminately" reading was contamination from the retracted vector reading; the
window resolves **fourteen** kinds of declared child in a fixed order and everything except the
children attached through slot 22 goes into the `+0x64` list, which is why only two lists serve
thirteen kinds. **Registries 1 and 5 are the `3dButtonType` and `threeDguiType` indexes** and the
unused vector at `+0x27C` is `multiSpriteButtonType`'s — all three are empty on every live window
because those three keywords occur **zero** times in the mod's *and* the game's own `interface/`
folders (positive control in the same grep: `positionType` 996/392, `shieldtype` 25/35). **The
ledger window is a `CStatisticsLedger`**, settled by its constructor at `0x7C0E60` writing that
class's RTTI vftable and then calling `LedgerPage_Update` on itself — and that call shows the
recorded signature describes the wrong parameter: the receiver is in **EDI** and the stack argument
is the **page number**. On the nine unnamed widget classes the news is mixed but real: the
source-file route works and yields one name (`textboxtype.cpp`), the checkbox constructor **names
itself `CheckBox`**, and `FINDINGS-guilive.md`'s RTTI negative is **wrong as stated** — the export
does contain `CCheckBoxObserver` and `CScrollbarObserver`, which the earlier sweep missed because
the image spells it `CheckBox` with a capital B.

---

## 0. Method, and the three tools that did the work

- **`image.decode` from int3-delimited entries only**, never a linear sweep (trap 9). Three
  scratchpad scripts: one that reports every memory displacement in a wanted set across a VA range,
  one that walks a single function printing calls and high displacements in address order, and one
  that decodes a window of a function from its real entry so the stream stays synchronised.
- **A whole-`.text` hunt for linked-list push/pop**: a store `mov [R+D], S` with a load
  `mov T, [R+D]` through the same base register within `0x30` bytes, at displacements `0x4C` and
  `0x5C`. It found 38 sites and **not one** in the `CFixedWindow` block, which is what proved the
  lists are not manipulated at the `CGuiObject`-relative offsets at all. Its positive control is
  that it does find the `CGui` constructor's own `+0x4C` store.
- **A source-file map**: every string in the image matching `*.cpp|*.h|*.hpp`, and every `.text`
  site that pushes one. The linker keeps an `.obj`'s code contiguous, so these sites bracket the
  code each `.cpp` produced. 120 file-name strings, 874 push sites.

## 1. `CFixedWindow +0x4C` — a linked list of what? (guilive open item 4)

### What it is

Two lists, not one, and they are the same kind of thing. **Complete `+0x60`..`+0x80` is two
`{head, tail, count, flag}` containers**, zeroed by the constructor:

```
0x00ABF949  mov  byte ptr [ebx + 0x60], 1
0x00ABF94D  mov  dword ptr [ebx + 0x64], esi     ; list A head   (CGuiObject +0x4C)
0x00ABF950  mov  dword ptr [ebx + 0x68], esi     ;        tail
0x00ABF953  mov  dword ptr [ebx + 0x6c], esi     ;        count
0x00ABF956  mov  byte ptr [ebx + 0x70], 0        ;        flag
0x00ABF95A  mov  dword ptr [ebx + 0x74], esi     ; list B head   (CGuiObject +0x5C)
0x00ABF95D  mov  dword ptr [ebx + 0x78], esi     ;        tail
0x00ABF960  mov  dword ptr [ebx + 0x7c], esi     ;        count
0x00ABF963  mov  byte ptr [ebx + 0x80], 0
```

**The elements are `CGuiObject*`.** Four `CFixedWindow` bodies walk both heads identically, and
every one of them invokes a `CGuiObject` *virtual slot* on `node->value`:

| slot (of `0x1602058`, the `CGuiObject` subobject table) | body | what it does with each node |
| --- | --- | --- |
| 34 | `0xAC4080` (rva `0x6C4080`), `ret 4` | `value->vf[17]()` for the child's own name, string-compares it against the argument, and on a match calls `value->vf[33](1)`; otherwise recurses with `value->vf[34](arg)`. Returns a bool. |
| 35 | `0xAC4140` (rva `0x6C4140`), bare `ret` | writes `byte [this+0x44] = 0` and calls `value->vf[33](0)` on every node of both lists |
| 36 | **`0xAC1220` (rva `0x6C1220`)**, bare `ret` | `gui->vf[27](value)` then `value->vf[36]()` — recursive over the whole subtree |
| 38 | `0xAC4030` (rva `0x6C4030`), `ret 4` | writes `byte [this+0x48] = arg` and calls `value->vf[38](arg)` on every node |

Slots 17, 33, 34, 36 and 38 are all `CGuiObject` slot indices, which is what makes the element type
`CGuiObject*` a **reading** rather than an inference. `confirmed`.

**The node is `0x10` bytes, `{CGuiObject* value; Node* prev; Node* next; bool}`**, read off three
identical allocate-and-link sites (`push 0x10; call 0xB9602F`). `FINDINGS-guilive.md` §9 item 4 says
`0x18` and says the nodes hold gui objects, 3D objects and billboards indiscriminately; both come
from the retracted `+0x4C`/`+0x50` vector reading and are **wrong**. The append:

```
0x00AC2FB4  mov  edi, [esi + 0x78]            ; the old tail
0x00AC2FB7  push 0x10
0x00AC2FB9  call 0xb9602f                     ; operator new
0x00AC2FCA  mov  [eax], ebx                   ; value   = the child
0x00AC2FCC  mov  [eax + 4], edi               ; prev    = old tail
0x00AC2FCF  mov  [eax + 8], ecx               ; next    = 0
0x00AC2FD2  mov  [eax + 0xc], cl              ; flag    = 0
0x00AC2FD9  mov  ecx, [esi + 0x7c]            ; the count
0x00AC2FDF  mov  [esi + 0x78], eax            ; tail    = the new node
0x00AC2FE2  mov  [esi + 0x7c], edx            ; count + 1
0x00AC2FE5  test ecx, ecx
0x00AC2FE9  mov  [edi + 8], eax               ;   non-empty: old tail's next
0x00AC2FEE  mov  [esi + 0x74], eax            ;   empty:     the head
```

So insertion is at the **end** and the list is in **declaration order**.

### Why there are two, and what distinguishes them

The `CFixedWindow` constructor's last act is an **ordered resolve loop** (`0xAC0DF0`..`0xAC10A3`).
It walks a linked list of declared child *names* (`0x24`-byte nodes, next at `+0x20`) and for each
name searches the window's **fourteen** per-kind containers in a fixed order, stopping at the first
hit:

| # | container searched | pushed to |
| --- | --- | --- |
| 1 | registry `+0x3CC` (scrollbars) | `+0x64` |
| 2 | vector `+0x25C` / names `+0x26C` (buttons) | `+0x64` |
| 3 | vector `+0x27C` / `+0x28C` | `+0x64` |
| 4 | registry `+0x33C` (text boxes) | `+0x64` |
| 5 | vector `+0x2BC` / `+0x2CC` (instant text boxes) | `+0x64` |
| 6 | **registry `+0x360`** | `+0x64` |
| 7 | registry `+0x384` (edit boxes) | `+0x64` |
| 8 | vector `+0x29C` / `+0x2AC` (icons) | `+0x64` |
| 9 | vector `+0x2FC` / `+0x30C` | **`+0x74`** |
| 10 | vector `+0x31C` / `+0x32C` (checkboxes) | `+0x64` |
| 11 | registry `+0x3A8` (list boxes), result `+ 4` | `+0x64` |
| 12 | container `+0x414`, result `[eax] + 0x18` | `+0x64` |
| 13 | **registry `+0x3F0`** | `+0x64` |
| 14 | vector `+0x2DC` / `+0x2EC` (overlapping boxes) | `+0x64` |

The `+ 4` at step 11 and the `+ 0x18` at step 12 are the per-class complete→`CGuiObject`
adjustments `FINDINGS-guilive.md` §2 warns about, visible in the engine's own code.

So **`+0x74` holds exactly the children found in the `+0x2FC` vector and `+0x64` holds all the
others.** `project.json` calls `+0x2FC` `child_windows_begin`, and the constructor has **no build
block for it at all** — it is filled only by slot 22, which is how a declared child window gets
there (`CGui`'s window factory calls the parent's slot 22). But `FINDINGS-guilive.md` §5 measured
that vector live and found **46 buttons, 20 child windows and 1 icon** across 206 windows, so game
code attaches non-windows through the same slot. I have therefore named the lists for the
discriminator and not for "window":

| complete | `CGuiObject`-rel | name | what |
| --- | --- | --- | --- |
| `+0x64` / `+0x68` / `+0x6C` | `+0x4C` / `+0x50` / `+0x54` | `child_elements_head` / `_tail` / `_count` | every child the constructor resolved out of the other thirteen containers, in declared order |
| `+0x74` / `+0x78` / `+0x7C` | `+0x5C` / `+0x60` / `+0x64` | `attached_children_head` / `_tail` / `_count` | the children present in the `+0x2FC` vector, i.e. attached through slot 22 |

Two function names fall out, both `confirmed`:

- **`CFixedWindow::DetachChildren`**, `0xAC1220` (rva `0x6C1220`), `void __thiscall ...(void)`,
  `CGuiObject` slot 36. **Its receiver is the `CGuiObject` subobject**, so Ghidra typing `this` as
  `CFixedWindow*` will put every displacement in the body `0x18` low; the comment says so.
- **`CFixedWindow::AttachChild`**, `0xAC2F90` (rva `0x6C2F90`),
  `void __thiscall ...(Hoi3CString* name, CGuiObject* child)`, `ret 8`, primary vftable slot 22.
  Receiver here is the **complete** object.

Both bodies appear in exactly one RTTI table — `CEU3DialogGui` slots 36 and 22 — because the
framework has no RTTI of its own; the fragment records them there and `slots_noted` explains why.

### A free answer: guilive open item 7, `+0x43` against `+0x44`

Slot 35 writes `byte [this+0x44] = 0` on itself and then clears the same byte on every child in
both lists through slot 33. Slot 34 finds a child **by name** over the subtree and sets that one
byte to 1 through the same slot 33. Clear-the-whole-tree plus set-one-by-name, over a widget tree,
with a getter at slot 2 — **that is keyboard focus**, and it fits the live differential
`FINDINGS-guilive.md` records exactly: `+0x44` reads 0 on 2,304 of 2,305 widgets, i.e. **exactly
one is set**. Recorded as `has_focus`, **likely** (written `inferred` in the fragment, see §6).

### A refinement to guilive §5's seven "vectors"

They are seven **pairs** at `0x20` stride, not seven vectors: `{vector<CGuiObject*> children at X;
vector<Hoi3CString> names at X+0x10}`. The second half is a names vector — the constructor divides
its byte span by `0x1C` (`imul 0x92492493; sar 4` at `0xAC08B6`), which is `Hoi3CString`'s size. So
`+0x26C`, `+0x28C`, `+0x2AC`, `+0x2CC`, `+0x2EC`, `+0x30C` and `+0x32C` are the name vectors
matching `+0x25C`, `+0x27C`, `+0x29C`, `+0x2BC`, `+0x2DC`, `+0x2FC` and `+0x31C`.

## 2. Registries 1 and 5: what they hold (guilive open item 3)

### The pairing is index for index, and the name list is the *source*

Each registry is filled from its own name list, not the other way round:

```
0x00AC0A3D  mov  esi, [ebx + 0x434]        ; head of name list 1
0x00AC0A74  call 0xac6c80                  ;   build the widget for this name
0x00AC0A7E  call 0xac1970                  ;   place it on the window
0x00AC0A83  mov  edx, [ebx + 0x360]        ;   registry 1
0x00AC0A94  call eax                       ;   its slot 6 = Insert(name, widget)
0x00AC0A96  mov  esi, [esi + 0x20]         ;   next name
```

The same three-step shape appears for `+0x424`/`+0x33C`, `+0x444`/`+0x384`, `+0x454`/`+0x3A8`,
`+0x464`/`+0x3CC` and `+0x474`/`+0x3F0`. **`FINDINGS-guilive.md` §5's pairing table is confirmed,
and extended: the name lists hold the names the `.gui` file declared and the registry maps each one
to the live widget built for it.** `confirmed`.

### The kinds

Each of the six has its own factory, and the factory's allocation size and widget constructor name
the kind. All six factories share one prologue: `this` is the `CWindowType` at window `+0x88`, the
name is looked up in the gui-type tree embedded at **`CWindowType +0x150`**, and a default is built
from `[CWindowType +0x14C]` if it is absent.

| registry | name list | factory | alloc | widget ctor | widget vftable | kind |
| --- | --- | --- | --- | --- | --- | --- |
| `+0x33C` | `+0x424` | `0xAC73C0` | `0x134` | `0xA87770` | `0x15FE3B8` | `textBoxType` |
| **`+0x360`** | **`+0x434`** | `0xAC6C80` → `0xB30A10` | `0x128` | `0xB5C270` | **`0x16094A8`** | **`3dButtonType`** |
| `+0x384` | `+0x444` | `0xAC72B0` | `0x1D0` | `0xA8F160` | `0x15FED90` | `editBoxType` |
| `+0x3A8` | `+0x454` | `0xAC77F0` → `0xB2BDC0` | `0x160` | — | `0x15FE758` | `listboxType` |
| `+0x3CC` | `+0x464` | `0xAC74D0` | `0x398` | `0xA9DB30` | `0x15FF7A0` | `scrollbarType` |
| **`+0x3F0`** | **`+0x474`** | **`0xB45670`** (external) | `0x84` | `0xB5FE90` | **`0x1609658`** | **`threeDguiType`** |

Four of the six reproduce `FINDINGS-guilive.md` §1's live class table from the static side, each
with its allocation size one step below the observed modal heap stride (`0x1D0`/`0x1D8`,
`0x160`/`0x168`, `0x398`/`0x3A8`, and `0xF0`/`0xF8` for icons) — that agreement is the positive
control for the whole method.

**Registry 1 is `3dButtonType`.** Three things, independently:

1. Its widget's constructor `0xB5C270` (rva `0x75C270`) builds on `0xACFA70`, the `CButton`-level
   constructor that writes `0x15FFA10` at `+0` and `0x15FFB28` at `+0x48` — the same two-vftable
   shape `CIcon`'s constructor has. So the widget is a **button**.
2. That constructor looks its graphic up in the **`objectTypes` registry on `CGraphics`**:
   `0x00B5C41A add eax, 0x6bcf0; call 0x9c7d60`, where `eax` came from `[this+0x88]`. `+0x6BCF0` is
   the 511-bucket table `FINDINGS-gui.md` §1 establishes holds `C3dObjectType` subclasses. **A
   button whose graphic is a 3D object type.**
3. On the type side, `CWindowType::LoadKey` (rva `0x6C55E0`) has fourteen per-kind containers at a
   `0x10` stride from `+0x174` to `+0x244`, and each child case builds its child type with a
   distinct constructor:

   | container | type ctor | type vftable | keyword |
   | --- | --- | --- | --- |
   | `+0x184` | `0xB2DA90` | `0x1606AD0` | `guiButtonType` or `checkboxType` |
   | `+0x194` | `0xB2DA90` | `0x1606AD0` | the other of those two |
   | **`+0x1A4`** | **`0xB30490`** | **`0x1606C04`** | — a type class §3 never saw |
   | `+0x1B4` | `0xB31940` | `0x1606C40` | `textBoxType` |
   | `+0x1C4` | `0xB2A820` | `0x1606A38` | `instantTextBoxType` |
   | `+0x1D4` | `0xB28120` | `0x1606958` | `scrollbarType` |
   | `+0x1E4` | `0xB29DC0` | `0x16069E0` | `editBoxType` |
   | `+0x1F4` | `0xAC81F0` | `0x16021B0` | `iconType` |
   | **`+0x204`** | `0xB2DA90` | `0x1606AD0` | the **third** user of the button type class |

   `0xB30490` and registry 1's widget builder `0xB30A10` are `0x580` apart — one translation unit.
   So the container `+0x1A4`, the type class `0x1606C04`, the widget class `0x16094A8` and registry
   1 are all one kind, and it is the only unused kind with a type class of its own.

**Registry 5 is `threeDguiType`.** It is the one kind not built by a `0xAC6xxx`/`0xAC7xxx` factory
at all: the name is looked up in `CWindowType +0x150`, handed to the **external** factory
`0xB45670` (rva `0x745670`), which reads an *alignment keyword* off the type (string compares
against `'LOWER_LEFT'` at `0x1602140` and `'CENTRE'` at `0x1607BAC`), positions the widget against
`CGraphics +0x6B9BC`/`+0x6B9C0` (the confirmed screen width and height), allocates `0x84` bytes and
constructs through `0xB5FE90` — which calls the `CGuiObject` constructor `0xA7FF60` and writes
**three** vftables, `0x1609658` at `+0`, `0x1609728` at `+0x48` and `0x1609738` at `+0x60`. So it
is a `CGuiObject` subclass and **not** a button, unlike the other two unused kinds. Its `.obj`
also carries `'Mock GUI Fixed 16x16 Default Format'` and `'Lars'`.

**And the unused vector at `+0x27C` is `multiSpriteButtonType`'s** (type container `+0x204`, sharing
`guiButtonType`'s type class `0x1606AD0`; widget `0x1609280`, constructor `0xB5B310` (rva
`0x75B310`), which builds by calling the ordinary `guiButton` widget constructor `0xB3FA50` first —
a *variant* of a button rather than a new one).

### Why all three are empty, which is the real content of the item

**The three keywords occur zero times in the loaded data.**

```
3dButtonType           mod 0   game 0
multiSpriteButtonType  mod 0   game 0
threeDguiType          mod 0   game 0
positionType           mod 996 game 392      <- positive control, same grep
shieldtype             mod 25  game 35       <- positive control, same grep
```

So these are not half-built indexes and nothing is missing: `CWindowType::LoadKey` accepts three
child keywords that neither BlackICE nor vanilla Hearts of Iron 3 ever writes. A mod author *could*
use them — `3dButtonType` would give a button whose graphic is an `objectTypes` entry, and
`threeDguiType` a screen-aligned 3D element — and the engine would index them by name on the parent
window exactly like text boxes and list boxes. `confirmed` for the emptiness and its cause;
**likely** for which of the three keywords is which container (written `inferred` in the fragment).

Also settled on the way: `CGuiObject` is **`0x48` bytes**. `TButton : CGuiObject(0),
CButtonObservable(72)` in the export, the checkbox constructor writes its second vftable at `+0x48`
immediately after calling `CGuiObject::CGuiObject` (**`0xA7FF60`, rva `0x67FF60`** — a new name, and
the constructor the `CFixedWindow` constructor calls with `ebx + 0x18`), and `CFixedWindow`'s own
data therefore begins at complete `+0x60`. That is what proves `+0x64` and `+0x74` are
`CFixedWindow`'s fields and not `CGuiObject`'s.

## 3. The nine unnamed widget classes (guilive open item 2)

### The route the plan named works, and yields one name

`FINDINGS-guilive.md` named the cheapest route as "a log or assert string inside one of the twelve
constructors", on the `CBillboardObject` precedent. I ran it to exhaustion.

**The positive control first.** The whole image holds **120** source-file-name strings. Two of them
land where they can be checked:

- `fixedwindow.cpp` (`0x1601DB0`) is pushed at `0xAC1A0A`, inside `0xAC1970` (rva `0x6C1970`, the
  per-kind placement helper the constructor calls once per child), and at `0xAC2C7F`, inside
  `0xAC2C20` — **`CFixedWindow` primary vftable slot 27**. Both are provably `CFixedWindow`'s.
- `guitype.cpp` (`0x1602218`) is pushed at `0xAC88F9`, inside `0xAC8710` — which `project.json`
  already records as **`CGuiType::LoadKey`**.

So the method sees the known cases. **What it does not see is the nine classes.** Of the 120 names,
four touch the GUI at all: `fixedwindow.cpp`, `guitype.cpp`, `spritetype.cpp`, `textboxtype.cpp`.
There is **no** `listboxtype.cpp`, `scrollbartype.cpp`, `editboxtype.cpp`, `checkboxtype.cpp`,
`overlappingelementsboxtype.cpp` or `guibuttontype.cpp` anywhere in `hoi3_tfh.exe`, and in the
whole gui-type code block `0xB21000`..`0xB34000` only two functions emit a file name at all
(`meshtype.cpp` at `0xB216BF` and `textboxtype.cpp` at `0xB32173`).

**The one it does yield.** `textboxtype.cpp` is pushed at `0xB32173` inside `0xB31DC0` (rva
`0x731DC0`), which logs `'Error reading textblock in file '` at line 93; and the `textBoxType` type
class's constructor `0xB31940` (rva `0x731940`), which writes vftable `0x1606C40`, is `0x480` bytes
earlier in the same `.obj`. So **the type class `0x1606C40` is `CTextBoxType`** — which is an
independent corroboration of `FINDINGS-guilive.md` §3's live keyword assignment, the one that file
says it had the wrong way round until the live objects decided it. `likely` for the exact
identifier; `confirmed` that the class comes from a file called `textboxtype.cpp`.

### The checkbox widget names itself

Scanning all twelve widget constructors for string literals gives exactly one that is not a tooltip
sentinel or a cursor name:

```
CheckBox widget ctor 0xA80FA0 (rva 0x680FA0), which writes vftable 0x15FDFC8 at 0xA81000:
0x00A816AD  push 8
0x00A816B2  push 0x15fdfb8                 ; 'CheckBox'
0x00A816D3  call 0x40a160                  ; std::string
0x00A816EB  call [[ebx+0x64] + 0xC4]       ; slot 49 on the object at +0x64
```

Three things make this the class's own name for itself rather than a data key: the literal sits at
`0x15FDFB8`, **`0x10` bytes before the checkbox widget's own vftable `0x15FDFC8`** in `.rdata` (the
same adjacency `textboxtype.cpp` has to `0x1606C40`); no `CheckBox` key exists in either the mod's
or the game's `gfx/`, `interface/` or `sound/` data; and the other eleven constructors have nothing
comparable. **So the `checkboxType` widget class is `CCheckBox`.** `confirmed` for the self-name
`CheckBox`; `likely` for the `C` prefix.

### `FINDINGS-guilive.md`'s RTTI negative is wrong as stated, and here is the correction

That file says, with a strong positive control, that a sweep of every hierarchy descriptor for
`TextBox|Listbox|Scrollbar|EditBox|Overlap|Checkbox` finds **nothing**, and concludes "there is no
`CTextBox`, no `CListbox`, no `CScrollbar`, no `CEditBox` name anywhere in `hoi3_tfh.exe`". Searched
over the export's full name list instead, it finds:

```
CCheckBoxObserver                                   CScrollbarObserver
CCheckBoxObserverGlue<T>   x 24 instantiations      CScrollbarObserverGlue<T>  x 2
TListboxItem    CStandardlistboxItem    CMessageListboxItem
```

**The reason the sweep missed them is almost certainly the capital B**: the image spells it
`CheckBox`, and `Checkbox` does not occur. `Scrollbar` would have matched, which points at the
sweep having been restricted to the twelve classes' own hierarchy descriptors rather than the whole
export.

This does not hand over the widget identifiers directly, but it is strong evidence by the
framework's **own** convention, which the export lets you verify twice over: `CButtonObserver` +
`CButtonObservable` go with `CButton`, and `TButton : CGuiObject(0), CButtonObservable(72)`;
`CWindowObservable` goes with `TWindow`, and `TWindow : CWindowObservable(0), CGuiObject(24)`. On
that convention **`CCheckBoxObserver` implies `CCheckBox` and `CScrollbarObserver` implies
`CScrollbar`** — and `CCheckBox` is exactly what the constructor's own string says. `likely` for
`CScrollbar`; the checkbox is better than that. `TListboxItem`'s lower-case `b` also suggests the
list box is spelled `CListbox` rather than `CListBox`, which is `inferred` and no more.

### Score

| `.gui` keyword | widget vftable | name, and how |
| --- | --- | --- |
| `checkboxType` | `0x15FDFC8` | **`CCheckBox`** — its own constructor's string, plus `CCheckBoxObserver` |
| `scrollbarType` | `0x15FF7A0` | **`CScrollbar`** — `CScrollbarObserver` and the observer convention, `likely` |
| `textBoxType` | `0x15FE3B8` | still unnamed; but its **type** class is `CTextBoxType` from `textboxtype.cpp` |
| `listboxType` | `0x15FE758` | still unnamed; `CListbox` spelling `inferred` from `TListboxItem` |
| `editBoxType`, `instantTextBoxType`, `OverlappingElementsBoxType`, and the three button classes `0x1607698` / `0x15FFB38` / `0x16077D0` | | **still unnamed, and the static routes are now exhausted** |

## 4. The ledger window's class — settled, and the recorded signature is wrong

`LedgerPage_Update` (rva `0x3C1ED0`, VA `0x7C1ED0`) has **13 direct callers**, all in one `.obj`
spanning `0x7BF000`..`0x7C3600`, and that `.obj` emits no source-file name. None of the enclosing
functions is in a vftable. But two of the callers are the constructor and the destructor:

```
0x15DC714 (CStatisticsLedger's RTTI vftable, 3 slots) is written at exactly two sites:
   0x007C0E93  in 0x007C0E60   <- the constructor
   0x007C28C3  in 0x007C28A0   <- the destructor
0x15DC724 (VCStatisticsLedger::__CButtonObserverGlue) is written at one:
   0x007C0EB5  in 0x007C0E60
```

and `0x7C0E60` is caller number four, at `0x7C1C19`. **So `LedgerPage_Update`'s receiver is a
`CStatisticsLedger*`.** `confirmed` — a machine could have checked it: the only two writers of that
class's vftable are both in the same block as the thirteen call sites, and one of them calls the
function on the object it has just constructed. `FINDINGS-uinumbers2.md` named `CStatisticsLedger`
as "the likeliest by the name" and could not get further because the live `instances` scan found
none with the ledger closed; this settles it without a game.

**The constructor**, `0x7C0E60` (rva `0x3C0E60`), `ret 0x14` — five stack dwords, `this` first:

```
0x007C0E7F  mov  ebx, [ebp + 8]              ; this
0x007C0E82  mov  [ebx + 4], eax              ; <- [ebp+0x14], the page number
0x007C0E8E  mov  [ebx + 0x10], eax           ; <- [ebp+0x10]
0x007C0E91  mov  [ebx], 0x15dc714            ; CStatisticsLedger
0x007C0E97  mov  [ebx + 0x14], edx           ; <- [ebp+0xC]
0x007C0EB5  mov  eax, 0x15dc724
0x007C0EBB  mov  [ebx + 0x50], eax           ; CButtonObserverGlue<CStatisticsLedger> #1
0x007C0EBE  mov  [ebx + 0x54], ebx           ;   its owner
0x007C0EC1  mov  [ebx + 0x58], 0x7c2810      ;   its handler
0x007C0EE3  mov  [ebx + 0x7c], eax           ; glue #2
0x007C0EE6  mov  [ebx + 0x80], ebx
0x007C0EEC  mov  [ebx + 0x84], 0x7c2860      ;   its handler
```

Both handlers, `0x7C2810` and `0x7C2860`, are among the thirteen callers — they are the ledger's
page buttons.

### The signature correction

`project.json` records `void __stdcall LedgerPage_Update(void* ledgerWindow)`, `ret 4`. The `ret` is
right and the parameter is **not**:

```
0x007C1C13  mov  ecx, [ebx + 4]              ; the PAGE NUMBER
0x007C1C16  push ecx
0x007C1C17  mov  edi, ebx                    ; the object, in EDI
0x007C1C19  call 0x7c1ed0

0x007C1ED0  ...
0x007C1EEE  mov  ecx, [edi + 0xc]            ; the gui window
0x007C1EF3  mov  edx, [eax + 0x2c]           ;   slot 11
0x007C1EFA  mov  eax, [ebp + 8]              ; the stack argument
0x007C1F0F  mov  [edi + 4], eax              ;   WRITTEN into +4
0x007C1F06  push 0x15dc260                   ; 'page_number'
```

Confirmed at a second call site: `0x7BFFC0` is a `__thiscall` of the same class
(`mov edi, ecx`) and does `mov eax,[edi+4]; push eax; call 0x7c1ed0`. So the correct form is

    void __stdcall CStatisticsLedger::ShowPage(CStatisticsLedger* ledger@EDI, int page)   ret 4

— the receiver is a **register** argument (trap 11's second half: not a `__thiscall`, because the
receiver is in EDI, so it needs an explicit `@EDI`), the stack argument is the page, and the
function is a **setter** that stores the page and rebuilds the window. The page table in
`FINDINGS-uinumbers2.md` §2 is unaffected; only the receiver's class and the argument's meaning
change. **This is not in the fragment** — the merge refuses to overwrite an existing name
or signature, and the brief said not to report `LedgerPage_Update` as a new finding. It wants a hand
edit.

Two `CStatisticsLedger` fields also want a hand edit, because the merge takes `struct_fields` only
for a struct `project.json` already has and `CStatisticsLedger` is not one of them:

| offset | name | type | evidence |
| --- | --- | --- | --- |
| `+0x4` | `page` | `int` | written by the constructor from its 4th stack argument at `0x7C0E82`, and by `ShowPage` from its stack argument at `0x7C1F0F`; read back at `0x7C1F27` and by caller `0x7BFFC9` |
| `+0xC` | `window` | `void*` | `ShowPage`'s first act is a virtual call on it, slot 11, at `0x7C1EEE`; the `page_number`, `ledger_overlay`, `textbox_autosend` and `checkbox_autosend` elements are reached through it |

## 5. The fragment, and what `--check` said

`fragments/merged/guistatic.json`: **2 addresses, 12 struct fields, 2 vftable slots, 23 frontier
entries.** `python ghidra/mergeFindings.py --check` reported no problem in this file; the batch was
refused only on a sibling agent's missing write-up. Three things worth knowing about it:

1. **Every key in `ADDRESS_KEYS` must be *present*, not merely valid.** The check is
   `if key not in entry and key != "source"`, and `no_signature` is in that tuple, so an entry that
   has a perfectly good `signature` is still refused with "no no_signature" until you add
   `"no_signature": null`. Both entries here carry it. This belongs in `fragments/README.md` —
   *and has since been added to it.*
2. **`struct_fields` cannot create a struct.** `CStatisticsLedger` was refused with "no such struct
   in project.json" and those two fields were dropped to the prose above.
3. **`likely` → `inferred`**, on `CGuiObject +0x44` (`has_focus`) and on the three keyword
   attributions in §2; each comment says "likely, and why" in so many words.

`checkSignatures.py` reads `project.json` and not fragments, so both signatures were checked by hand
against the `ret`: `DetachChildren` is `__thiscall` with no stack argument and ends in a bare `ret`
at `0xAC1279`; `AttachChild` is `__thiscall` with two stack dwords and ends `ret 8` at `0xAC3016`.
Both agree. The merge and the Ghidra apply were **not** run by the agent.

## What is not established

1. **Six of the twelve widget classes still have no name, and the static routes are exhausted.**
   `textBoxType` (`0x15FE3B8`), `instantTextBoxType` (`0x15FDB70`), `listboxType` (`0x15FE758`),
   `editBoxType` (`0x15FED90`), `OverlappingElementsBoxType` (`0x16013D8`) and the three button
   classes (`0x1607698`, `0x15FFB38`, `0x16077D0`). All three static routes have been run with
   positive controls: no RTTI locator at `vftable - 4` (guilive's control), no source-file string in
   their `.obj`s (120 names in the image, four GUI-related, control = `fixedwindow.cpp` and
   `guitype.cpp` resolving to known functions), and no self-naming literal in their constructors
   (control = the checkbox constructor's `'CheckBox'`). *What would settle them:* nothing a live
   game can do either — these are compiler-erased names. The remaining avenues are a symbol-bearing
   build of another Clausewitz-era title, or a Paradox-published header. **A named gap, and a
   permanent one for this image.**
2. **`CCheckBox` and `CScrollbar` are the names, not the spellings.** `CheckBox` is the string the
   class builds; `CCheckBoxObserver` and `CScrollbarObserver` are the identifiers the export
   carries. The `C` prefix on the widget itself is convention. Nothing can check the prefix.
3. **What the checkbox constructor does with its own name.** It is passed to slot 49 of the object
   at widget `+0x64`, which was not identified. Tracing `+0x64` back through `0xA80FA0` would say
   whether the name is used for a sound, an effect or a log line, which would tell you *why* the
   class knows its own name — interesting, not load-bearing, and purely static.
4. **Which keyword each of the three unused kinds is, exactly.** `3dButtonType` → registry 1 rests
   on two readings (a `CButton` base, and the `CGraphics +0x6BCF0` object-type lookup) and is
   strong; `threeDguiType` → registry 5 rests on it being the only non-button of the three and
   going through an external factory; `multiSpriteButtonType` → vector `+0x27C` is then the
   remainder, corroborated by its widget being built on top of the ordinary `guiButton` widget and
   sharing `guiButtonType`'s type class. *What would settle it outright, and it is static:* read
   the four unresolved `CWindowType::LoadKey` containers (`+0x214`, `+0x224`, `+0x234`, `+0x244`)
   and tie each LoadKey **token** to its container — the scan resolved the type constructor for nine
   of the fourteen containers and attributed the other five to generic helpers. That is one
   careful pass over `0xAC55E0`..`0xAC6C00` and it would turn three `likely`s into `confirmed`s.
5. **Container `+0x414` is the fourteenth kind and is unidentified.** It is a three-pointer
   container, looked up by name through `0xAC4580`/`0xAC4640`, and its result is adjusted
   `[eax] + 0x18` — a complete→`CGuiObject` conversion, which means it holds **complete
   `CFixedWindow` pointers**, i.e. windows. `FINDINGS-guilive.md` never saw it. Given that, it is
   possible that `+0x414` and not `+0x2FC` is the real child-window container and that
   `project.json`'s `child_windows_begin` is misplaced rather than merely a misnomer. *What would
   settle it:* static — read `0xAC4580`/`0xAC4640` and whatever fills `+0x414`. **Do this before
   trusting the name `attached_children_head`.**
6. **What `CGui` slot 27 is for.** `CFixedWindow::DetachChildren` hands every child to it, and on
   `CEU3Gui` it is the shared `ret 4` stub `0x60CD50`, so this build cannot say. No class in the
   image overrides it (`vtable.py --holding` on the stub is useless here — it is in 1,420 slots).
   The slot exists and does nothing, which is already what `FINDINGS-guilive.md` §8 concluded about
   front-end widget retention.
7. **`CFixedWindow +0x60` (byte, set to 1 by the constructor) and `+0x48`/`+0x44` on the
   `CGuiObject` side.** `AttachChild` passes `byte [this+0x60]` to the new child's slot 38, and slot
   38 stores its argument in `byte [this+0x48]` and propagates it down both child lists. So
   `+0x60` is some window-wide flag that every descendant mirrors at its own `+0x48`. Not
   identified. *What would settle it:* a live differential — snapshot `+0x60` on all 206 windows
   and on a window being shown and hidden; two reads, under a minute with a game running.
8. **`has_focus` on `CGuiObject +0x44` is `likely`, not confirmed.** *The live check that would
   settle it, in one minute:* click into `HostEditBox` or any text field, and read `+0x44` across
   all live widgets — if exactly the focused widget has it set, it is confirmed; if a second widget
   has it, it is something else. A second check: press a key and see whether it reaches the widget
   whose `+0x44` is 1.
9. **The `+0x2FC` vector's real contents.** `FINDINGS-guilive.md` §5 measured 46 buttons, 20 child
   windows and 1 icon live, which is what forced the neutral name `attached_children_head`. *The
   live check:* for the 46 buttons in that vector, read each one's `+0x24` type name and find who
   called slot 22 for them — if they are all `CEU3DialogGui` subclasses adding their own title-bar
   buttons, the vector is "attached by game code" and the name is right.
10. **Nothing here was observed running.** Every address, offset, allocation size and vftable in this
    file is read out of `hoi3_tfh.exe` and is build-specific; the only numbers quoted from a live
    session are `FINDINGS-guilive.md`'s, cited as its, and the only numbers quoted from data files
    are the two `interface/` greps, which are specific to this BlackICE install.

---

## Frontier

`0x6C4080`, `0x6C4140`, `0x6C4030` (the other three list walkers), `0x6C1970` (the per-kind
placement helper, a `fixedwindow.cpp` function that logs through `0xA64A30`), `0x6C47C0` and
`0x6C4580` (the by-name child lookups the resolve chain uses), the nine child factories
`0x6C6C80`, `0x6C6E80`, `0x6C72B0`, `0x6C73C0`, `0x6C74D0`, `0x6C75D0`, `0x6C77F0`, `0x6C78F0`,
`0x6C71A0`, their widget builders `0x730A10`, `0x72C2A0`, `0x75C270`, `0x75B310`, `0x745670`,
`0x75FE90`, the `CButton`-level constructor `0x6CFA70`, and `0x3C0E60`
(`CStatisticsLedger::CStatisticsLedger`, `ret 0x14`, with a second exit at `0x7C1CA3` — trap 3,
unresolved).

---

## Checked on transcription, 2026-10-02

The two claims that correct published work were re-run before filing, and both hold.

- **The RTTI negative in `FINDINGS-guilive.md` really is wrong for two of the six names.** Searched
  over the export's 2,645 class names directly: **`CheckBox` 29 hits** (`CCheckBoxObserver` plus 28
  glue instantiations), **`Scrollbar` 3** (`CScrollbarObserver` plus 2), and `Checkbox` with a
  lower-case b **zero** — which is exactly the spelling the published sweep used, so the
  capital-B explanation is confirmed rather than merely plausible. `TextBox`, `EditBox` and
  `Overlap` genuinely return zero, so the negative stands for those three. `FINDINGS-guilive.md`
  has been corrected in §1 and in its open item 2.
- **The three unused keywords really are absent from the data.** Re-grepped over both the mod's and
  the game's own `interface/` folders: `3dButtonType`, `multiSpriteButtonType` and `threeDguiType`
  match **zero** files in either, while the controls `positionType` (15 mod / 16 game files) and
  `shieldtype` (9 / 10) match in both. The agent quoted occurrence counts and these are file
  counts; either way the controls work and the three are unused.

Also confirmed: `mergeFindings.py`'s key-presence rule is as reported — `ADDRESS_KEYS` includes
`no_signature` and the test is `if key not in entry`, so a signed entry must still carry
`"no_signature": null`. That, the `struct_fields` spelling and the missing `likely` are now written
into `fragments/README.md`, since three of the four wave 9 agents hit at least one of them.

**Landed 2026-10-02.** The fragment merged into `../ghidra/project.json` and moved to `../fragments/merged/guistatic.json`, which is why the path above is `merged/` and not `incoming/`. The Ghidra apply has run, against a scratch copy of the `Hoi3_v12.1.2` project, and reported **failed: 2** - the documented pass mark, both failures being the two known over-long Ghidra bodies. So these names are in `project.json`, in `bicelib_findings.json` and in that Ghidra database. **the maintainer's own project was not written to**: Ghidra was open on it at the time.
