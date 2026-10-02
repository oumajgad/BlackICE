# The live GUI: from a window name to the object holding the number

Read on 2026-10-02 against a **running game** — the first findings file here where that is true of the
GUI layer. Static addresses are **virtual** (image base `0x400000`) with the rva beside anything the
record needs. The live process was based at `0x830000` this session and that moves every launch, so
every live pointer below is rebased to a static VA before it is named (`static = live - base +
0x400000`): trap 1 in its second hat.

The session: a freshly started 1936-01-01 00:00 campaign, **playing IRE (Ireland)**, paused,
`in_game = 1`, no combat in progress. `CCurrentGameState +0xC30` reads `IRE` id 20. The brief said
France; it was wrong and the correction matters for exactly one paragraph (§6), where the numbers I
read off the topbar are Ireland's.

This file is the half `FINDINGS-gui.md` could not reach. That file's open item 1 was *"how you get
from a window type to the live window object that holds a computed number"*. It is answered here,
and so are its items 2, 4, 5, 6, 9(b) and 9(c); item 7 is answered and item 3 is partly answered.

## In one line

Every live widget in the process is in one flat `std::vector<CGuiObject*>` at **`CGui +0x5C`** —
2,305 of them in this session — and each one holds its `CGuiType*` at **`+0x24`** and the owning
`CGui` at **`+0x28`**, so a name is one dereference and a string compare away; a live
**`CFixedWindow`** additionally carries **six case-insensitive ternary search trees keyed by child
name** (`+0x324` text boxes, `+0x36C` edit boxes, `+0x390` list boxes, `+0x3B4` scrollbars, two
empty) beside **seven unindexed child vectors** (`+0x244` buttons, `+0x284` icons, `+0x2A4` instant
text boxes, `+0x2C4` overlapping-element boxes, `+0x2E4` child windows, `+0x304` checkboxes, one
empty), and `topbar`'s text-box tree hands back the sixteen topbar numbers by name with their
rendered text at **`+0xD8`**. **The GUI framework was compiled without RTTI**, which is why
`classNameForVftable` names none of the twelve live widget classes and why the instance side was
unreachable before — the names come back out of the *derived* classes that do have RTTI
(`CEU3Minimap < CIcon < CButton`, `CEU3DialogGui < CFixedWindow < TWindow`), which fixes
`CIcon = 0x15FFC68` and `CFixedWindow = 0x1601F88` with its `CGuiObject` subobject at `+0x18`. On
the way through: `CInGameIdler +0x178C` **is** the `CEU3Graphics` (pointer equality, live),
`CInGameIdler +0x1790` is the **`CEU3Application`** and not a "session manager", `CGraphics +0x6B9BC`
is the screen **width** (reads 1920 beside `+0x6B9C0`'s 1080), `CInGameIdler::Enter`'s whole unit-row
calculation reproduces exactly (`(1080-144)/40-1 = 22`, and `+0x1DF8` reads 22), `CBillboardType`'s
vftable really is `0x1605258` (20,546 live billboards all point at a type of that class), and a
duplicate `guiTypes` name **overwrites and leaks** the earlier type while still bumping the count —
which is why the tree holds 1,547 distinct names under a count of 1,550.

---

## 0. Method, and what the live process bought

Three things did all the work, and only the first was available to the predecessor.

- `hoi3.instances(pm, "CEU3Gui")` → one object. Every singleton in this layer has exactly one live
  instance (`CEU3Gui`, `CEU3Graphics`, `CEU3Application`, `CInGameIdler`), which makes pointer
  equality a usable proof technique: a field that holds the only `CEU3Graphics` in the process *is*
  the graphics, with no inference step.
- **Reading the MSVC complete object locator at `vftable - 4` directly out of the image**, rather
  than through the RTTI export. The export's *hierarchy descriptor* gives the full base chain, which
  names classes that have no vftable of their own. That is how `CIcon`, `CButton`, `TButton`,
  `CFixedWindow`, `TWindow` and `CGuiObject` got attached to live vftables.
- **The mod's `interface/*.gui` files as the oracle**, parsed with brace tracking
  (`probes/guilive/guiparse.py`) so every `name = "x"` is attributed to the keyword that opened its
  block. 3,306 names, 1,482 of them top-level.

### The one thing the live process settled that nothing else could

`interface/*.gui` declares exactly six top-level `textBoxType` entries and exactly six top-level
`instantTextBoxType` entries. The ternary search tree holds exactly six entries of class
`0x1606A38` and exactly six of class `0x1606C40`. **Both assignments fit the counts**, and I had them
the wrong way round until the live objects decided it: `goto_text` and `pie_heading`, declared
`instantTextBoxType`, hold a `0x1606A38` type; `select_nation_label` and
`CreateMPGameHeadingTextBox`, declared `textBoxType`, hold a `0x1606C40` type. Trap 15 in a new
shape — a fit against a count that two hypotheses both satisfy is not a fit at all.

### Three wrong turns, recorded so nobody repeats them

1. **`CFixedWindow +0x4C` is a linked list, not a vector.** I read `+0x4C`/`+0x50` as a
   `begin`/`end` pair and got spans that happened to divide by `0x18`, which produced a plausible
   "array of 0x18-byte child records" — 2,145 records, 12,870 claimed children against 2,305 live
   objects, and `country_info` as its own parent. Slot 36 (`0xAC1220`) settles it: `mov esi,
   [edi+0x4C]` … `mov esi, [esi+8]` is a list walk. **Nothing in this file rests on `+0x4C`** and
   it is listed as unidentified in §9.
2. **`findInstances.py CLandCombat` returns one match and it is not an object.** Its `+0x18`
   province is null and `+0x2C`/`+0x30` are garbage. It is a dword in the heap that happens to equal
   the vftable address. A single scan hit above `DATA_SECTION_START` is not an instance; check its
   fields.
3. **Trap 14, again.** `FINDINGS-gui.md` §9 item 5 asks what `[CCombat+0x18]->+0xD0` is.
   `CMapProvince +0xD0` is `id` and has been in *both* `project.json` and
   `BiceLib/GameClasses/CMapProvince.hpp` all along, with `path_node_ptr` at `+0xD4` right beside it
   exactly as that item guessed. Live corroboration, since it is free: the `+0xD0` values over all
   14,190 live `CMapProvince` objects are a bijection onto `0..14189`. **The item was answered
   before it was written.**

## 1. The live object list: `CGui +0x5C`

`CEU3Gui`'s live layout, read out of the process (one instance, at `0x28C85940` this session):

```
+0x00  vftable 0x15CD754   TGui          (32 slots)
+0x04  vftable 0x15CD7D8   CPersistent   (6 slots)
+0x0C  vftable 0x15CD7F4   CFactory      (3 slots)
+0x30  0x14960048          -> the one live CEU3Graphics
+0x34  vftable 0x1602108   the embedded name tree (the gui-type registry)
+0x38  0x055B7B20          its root
+0x3C  0                   its mode byte: 0 = ternary tree
+0x40  1550                its insert count
+0x5C  0x293A5F68          vector<CGuiObject*> begin
+0x60  0x293A836C          vector<CGuiObject*> end     -> (0x2404 / 4) = 2305 objects
+0x64  0x293E4768          vector<CGuiObject*> capacity end
```

The base layout `CGui : TGui(0), CPersistent(4), CFactory(12)` that `FINDINGS-gui.md` took from the
RTTI export is visible directly in those three vftable slots. **`CGui +0x30` is the
`CEU3Graphics`** — pointer equality with the process's only instance; `confirmed` (live).

**`+0x5C` is the live widget list.** Two independent reasons, one static and one live:

- `TGui` slots 16 and 23 are both `0xA7DC60`, six instructions: `lea edi, [ecx+0x5C]; lea eax,
  [ebp+8]; call 0x86CC20` — a `push_back`. Eleven more `TGui` slots end the same way
  (`0xA7CA50`, `0xA7CAA0`, `0xA7CB10`, `0xA7CB50`, `0xA7CB90`, `0xA7CBF0`, `0xA7CCB0`, `0xA7CD20`,
  `0xA7CD60`, `0xA7CE30`, `0xA7CEA0`, `0xA7CF10`, `0xA7CF80`), each of which first looks a name up in
  the `+0x34` tree, builds something from the type it finds, and pushes the result into `+0x5C`.
  **Those thirteen slots are the by-name widget factories**, one per element kind. Slots 19
  (`0xA7DBD0`) and 30 (`0xA7DE00`) iterate `+0x5C..+0x60`.
- Live: all 2,305 entries are readable objects, 2,305 of 2,305 have a pointer at `+0x24` to an object
  with a readable `std::string` at `+8`, and that string is a name declared in an `interface/*.gui`
  file in 2,287 cases (the other 18 are names the vanilla `interface/` folder declares and the mod
  does not override).

Confidence `confirmed`; the static half of it survives a restart, the count 2,305 does not.

### What is in it

Twelve widget classes plus `CEU3Minimap`. The **keyword** column is the `.gui` keyword of the type
each object's `+0x24` points at, cross-tabulated over all 2,305 objects against the parsed `.gui`
files; the **stride** is the modal spacing between consecutive objects of the class in the heap,
which gives the allocation size.

| object vftable | `.gui` keyword it is built from | live | stride | class name |
| --- | --- | --- | --- | --- |
| `0x1607698` | `guiButtonType` | 686 | `0x168` | — (no RTTI) |
| `0x15FDB70` | `instantTextBoxType` | 473 | `0x100` | — |
| `0x15FFC68` | `iconType` | 402 | `0xF8` | **`CIcon`** |
| `0x1602058` | `windowType` | 206 | `0x508` | **`CFixedWindow`**, subobject — see §2 |
| `0x15FE3B8` | `textBoxType` | 102 | `0x148` | — |
| `0x15FFB38` | `guiButtonType` | 100 | `0xC0` | — (slider handles) |
| `0x16077D0` | `guiButtonType` | 92 | `0x100` | — (scrollbar track buttons) |
| `0x15FF7A0` | `scrollbarType` | 92 | `0x3A8` | — |
| `0x15FE758` | `listboxType` | 79 | `0x168` | — , subobject at complete `+4` |
| `0x15FDFC8` | `checkboxType` | 54 | `0x158` | — |
| `0x16013D8` | `OverlappingElementsBoxType` | 11 | `0x190` | — |
| `0x15FED90` | `editBoxType` | 7 | `0x1D8` | — |
| `0x15CF15C` | `iconType` | 1 | — | **`CEU3Minimap`** |

Three classes come out of `guiButtonType` and the split is not a keyword: of the 100 objects of
`0x15FFB38`, 92 are named `*SliderButton` (74 `listboxSliderButton`, 10 `ds_SliderButton`, 8
`landslider_SliderButton`) and all 92 objects of `0x16077D0` are named `listboxTrackButton` — and
there are exactly 92 live scrollbars. **A scrollbar builds one handle and one track button of its
own classes**; the rest of the buttons come from `guiButtonType` declarations. `likely` — the
scrollbar constructor was not read, the correspondence is a count match and a name match.

`checkboxType` and `guiButtonType` share **one** type class (`0x1606AD0`) but have **different**
object classes (`0x15FDFC8` against `0x1607698`), so the two keywords are one type and two widgets.

### Why nothing could name these before

**The GUI framework was compiled without RTTI.** `[vftable - 4]` is not a complete object locator
for any of the twelve classes above, nor for the ten type classes in §3. The positive control the
negative needs:

```
0x015CF15C  .?AVCEU3Minimap@@        thisOffset=0
   bases: CEU3Minimap < CIcon < CButton < TButton < CGuiObject < TCollisionObserver
          < CButtonObservable < CObservable<CButtonObserver,CButtonClassObservable>
          < TObservable<CButtonObserver,CButtonClassObservable>
0x015CD754  .?AVCEU3Gui@@            bases: CEU3Gui < CGui < TGui < CPersistent < CFactory
0x015CD548  .?AVCEU3DialogGuiType@@  bases: CEU3DialogGuiType < CWindowType < CGuiType
                                            < CPersistent < CFactory
0x015E14C8  .?AVCEU3Graphics@@       bases: CEU3Graphics < CGraphics < CFactory < CPersistent
0x01602058  <[vftable-4] = 0xCCCCCCC1, not a locator>
0x015FFC68  <[vftable-4] not a locator>
```

The same method that names four classes in a row fails on every framework vftable, so the silence is
the image's and not the tool's. It also explains the shape of the brief's warning that `CGui`,
`CGuiObject`, `CWindowType` and `CGuiType` "are all real RTTI classes": they are real *names* in the
export with **zero** vftables, because the only place they appear is in some derived class's
hierarchy descriptor. `CGuiObject` appears in six, `CFixedWindow` in two, `CIcon` in two,
`CStandardlistboxItem` in 251. And a sweep of **every** hierarchy descriptor in the image for
`TextBox|Listbox|Scrollbar|EditBox|Overlap|Checkbox` finds **nothing** — there is no `CTextBox`, no
`CListbox`, no `CScrollbar`, no `CEditBox` name anywhere in `hoi3_tfh.exe`. Those nine classes cannot
be named from the binary, and §11's `project.json` entries record them by their `.gui` keyword and
say so.

## 2. `CFixedWindow`, and the `+0x18` that will bite

`CEU3DialogGui::CEU3DialogGui` (`0x63DE70`, rva `0x23DE70`) ends:

```
0x0063DF35  call 0xabf8e0                      ; the base constructor
0x0063DF43  mov  dword ptr [esi], 0x15cd3c4    ; CEU3DialogGui's primary vftable
0x0063DF49  mov  dword ptr [esi + 0x18], 0x15cd494   ; its CGuiObject subobject, at +0x18
```

and `0xABF8E0` writes `[ebx] = 0x1601F88` and `[ebx + 0x18] = 0x1602058`. `CEU3DialogGui`'s immediate
base is `CFixedWindow`, so **`0xABF8E0` is `CFixedWindow::CFixedWindow` (rva `0x6BF8E0`),
`0x1601F88` is `CFixedWindow`'s primary vftable, and `0x1602058` is its `CGuiObject` subobject's
vftable at object offset `0x18`.** Live confirmation, which is the part that matters: for all 206
window pointers in `CGui +0x5C`, the dword at **`pointer - 0x18`** is `0x1601F88`, with no
exceptions. `confirmed`.

The same shape, one step simpler, for icons: `CEU3Minimap::CEU3Minimap` (`0x67A3C0`, rva `0x27A3C0`)
calls `0xAA1C00` and then writes `0x15CF15C` at offset 0; `0xAA1C00` writes `0x15FFC68` at offset 0
and `0x15FFD94` at `+0x48`. So **`0xAA1C00` is `CIcon::CIcon` (rva `0x6A1C00`)** and for an icon the
`CGuiObject` subobject *is* the object.

**The consequence for BiceLib:** `CGui +0x5C` holds `CGuiObject*`, not complete-object pointers, and
the adjustment is per class — `0x18` for a window, `0` for an icon or a button, `+4` for a list box
(§5). Every offset in §4 and §5 below is stated **relative to the `CGuiObject` pointer the vector
hands you**, which is the only one you have. §11's `project.json` entries for `CFixedWindow` are
stated relative to the **complete** object, i.e. `0x18` higher, because that is what a Ghidra struct
needs; each comment says so.

## 3. The type side, live: which class is which `.gui` keyword

Walking the ternary search tree at `CGui +0x34` (`probes/guilive/tst.py`): **27,302 nodes, 1,547
distinct names**, against an insert count of **1,550** at `+0x40`. Every value is an object of one
of ten classes, and matching the per-class counts against the mod's 1,482 top-level declarations
plus the live object correlation of §1 names all ten:

| type vftable | `.gui` keyword | top-level entries, live | mod declares (top level) |
| --- | --- | --- | --- |
| `0x1606B04` | `positionType` | 997 | 993 |
| `0x1602178` | `windowType` | 284 | 274 |
| `0x16021B0` | `iconType` | 221 | 180 |
| `0x15CD548` | `eu3dialogtype` (`CEU3DialogGuiType`, has RTTI) | 15 | 7 |
| `0x1606AD0` | `guiButtonType` **and** `checkboxType` | 14 | 12 |
| `0x1606A38` | `instantTextBoxType` | 6 | 6 |
| `0x1606C40` | `textBoxType` | 6 | 6 |
| `0x1606958` | `scrollbarType` | 2 | 2 |
| `0x1606A64` | `listboxType` / `listBoxType` | 2 | 2 |
| `0x1606A0C` | `OverlappingElementsBoxType` | 0 top level | 0 |
| `0x16069E0` | `editBoxType` | 0 top level | 0 |

The live totals are consistently a little higher than the mod's, because the game's own
`interface/` folder is loaded too and the mod only overrides files of the same name — 65 of the 1,547
names (`creditstext`, `tableheadertext`, `fps_counter`, `pausetext`, `tooltip`, `channeluserlisting`,
…) are not in the mod at all. The last two rows are named from §1's live objects, whose types are
nested inside a `windowType` and therefore never reach the tree.

**`FINDINGS-gui.md` §9 item 6 is answered: a `positionType` is the class with vftable `0x1606B04`**,
and its `position` is at `+0x64`/`+0x68`, which that file inferred from `CInGameIdler::Enter` and
could not check. Live:

```
unitlist_start   type 0x295455B0  class 0x1606B04  name@+8 'unitlist_start'   +0x64=0   +0x68=144
unitlist_offset  type 0x29545CB8  class 0x1606B04  name@+8 'unitlist_offset'  +0x64=16  +0x68=40
```

against `interface/unitpanel.gui`'s `position = { x = 0 y = 144 }` and `{ x = 16 y = 40 }`. Exact.
`confirmed`. And the `+0x64`/`+0xA0` collision that file warned about is real and is now explained
rather than only observed: `+0x64` is a coordinate on a `positionType` and `CFixedWindow`'s own data
on a `CWindowType`.

### `CWindowType +0xA0` and `+0xA8` are each two ints, and the engine writes to them

```
country_production  type 0x29421680  +0xA0=-555  +0xA4=-330  +0xA8=1120  +0xAC=768
topbar              type 0x297BC240  +0xA0=0     +0xA4=0     +0xA8=1920  +0xAC=1080
```

`interface/country_production.gui` declares `position = { x = -555 y = -330 }` and `size = { x =
1120 y = 768 }` — exact, which confirms `FINDINGS-gui.md` §4 live and adds that x is at `+0` and y
at `+4` of each pair.

`interface/topbar.gui` declares `size = { x=2048 y=100 }` and `fullScreen = yes`, and the live type
reads **1920 x 1080** — the screen. So **`fullScreen = yes` causes the declared `size` on the
`CWindowType` to be overwritten with the screen resolution**, and a `CWindowType` is therefore *not*
read-only reference data: the engine mutates it. For the DLL this means a size read off a type may
not be the file's, and two windows sharing a type share the mutation. The observation is
`confirmed`; attributing it to `fullScreen` is `likely` (the writer was not located; `fullScreen` is
one of `CWindowType::LoadKey`'s 28 keys and the values agree exactly with `CGraphics +0x6B9BC/+0x6B9C0`).

### `0xA7DF60`, the `guiTypes` block reader — `FINDINGS-gui.md` §9 item 7, closed

`void __cdecl CGui_LoadGuiTypes(CParseContext * ctx, NameTree * types, CFactory * factory)`, `ret
0xC`. The loop, read whole:

```
0x00A7DF80  mov  esi, [ebx + 0x1C]             ; the tokeniser on the parse context
0x00A7DF83  cmp  byte ptr [esi + 0x110], 0     ; lookahead already fetched?
0x00A7DF93  call [tokeniser + 4]               ;   no: fetch, into [esi+8], 0x13 on EOF
0x00A7DFBA  mov  eax, [ebp - 0x104]            ; the token id
0x00A7DFC0  cmp  eax, 4                        ; '}' -> done
0x00A7DFC5  cmp  eax, 0x13                     ; EOF -> done
0x00A7DFCB  call 0xa7acb0                      ; consume it
0x00A7DFD0  mov  eax, [ebx + 0x20]             ; the keyword
0x00A7DFDD  call [factory_vftable + 8]         ; factory slot 2: build the CGuiType subclass
0x00A7DFE1  test esi, esi                      ;   null -> next keyword, in silence
0x00A7DFED  call [newobject_vftable + 0xC]     ; slot 3 = CPersistent::Load: parse its block
0x00A7DFF9  push esi                           ; the value
0x00A7DFFC  call [newobject_vftable + 0x18]    ; slot 6 on the new type -> &its name
0x00A7E004  push eax                           ; the key
0x00A7E005  call [types_vftable + 0x18]        ; container slot 6 = Insert(name, value)
0x00A7E007  jmp  0xa7df80
```

So the factory at `CGui +0xC` maps the inner keyword to the class, the new object parses its own
block, and its own slot 6 supplies the key. `confirmed` (the record currently has this entry as
`inferred`).

### A duplicate `guiTypes` name overwrites, leaks, and is still counted

Container slot 6 is `0x44D8A0` (rva `0x4D8A0`), `__thiscall`, `ret 8`. It branches on the mode byte
at container `+8`:

- `+8 == 1`: `0x44D8E0` (rva `0x4D8E0`), which allocates a `0x24`-byte node holding the key as a
  `std::string`. **Not the path the GUI uses** — `CGui +0x3C` reads 0 live, as do all six registries
  on all 206 live windows.
- `+8 == 0`: the `const char*` is taken out of the `std::string` and `0x44DA70` (rva `0x4DA70`) is
  called as `TernarySearchTreeInsert(key@EAX, table, &root, value)`, `ret 0xC`.

`0x44DA70` lowercases each character with `tolower` (`0x44DAA1`) before storing it in the node, which
is the insert-side half of the case-insensitivity `FINDINGS-gui.md` found on the lookup side. Its two
exits are the whole answer to "what happens to a duplicate":

```
0x0044DAF8  mov  eax, [ebp + 0x10]    ; new key: fill the fresh node
0x0044DAFB  mov  [esi], eax
0x0044DB00  inc  dword ptr [eax + 0xC]
0x0044DB07  ret  0xc

0x0044DB0A  mov  ecx, [ebx]           ; EXISTING key: the node already there
0x0044DB0C  mov  edx, [ebp + 0x10]
0x0044DB14  mov  dword ptr [ecx], edx ;   overwrite the value
0x0044DB16  inc  dword ptr [eax + 0xC];   and still bump the count
0x0044DB1B  ret  0xc
```

**A second `guiTypes` entry with the same name replaces the first, the first `CGuiType` is leaked,
and the count at container `+0xC` over-counts by the number of duplicates.** `confirmed`, static.
And the live tree says there are **three** duplicate top-level gui type names in the loaded set:
1,550 inserts, 1,547 distinct nodes. The three are not identified; the mod's own files carry 452
duplicate names overall, nearly all of them nested children, which the tree never sees.

For a modder this is the real content of the item: `guiTypes` and `guitypes` are the same key, two
window names differing only in case are the same window, the loader never says so, and the later one
wins.

## 4. `CGuiObject`: the three fields every widget has

Measured over all 2,305 live objects, across all thirteen classes:

| offset | holds | evidence |
| --- | --- | --- |
| `+0x24` | the widget's **`CGuiType*`** | non-null on 2,305 of 2,305, and `[type+8]` is a readable name on all 2,305 |
| `+0x28` | the owning **`CGui*`** | equals the one live `CEU3Gui` on 2,305 of 2,305 |
| `+0x43` | **is open / visible**, a byte | 1 on 129 objects, 0 on 2,176; `CFixedWindow::Hide` writes it 0 and `Show` writes it 1 |

`+0x24` and `+0x28` are `confirmed` and the method survives a restart; the counts do not.
`+0x43` is `confirmed` on a static write plus a live differential:

```
CFixedWindow::Show  0xAC2690 (rva 0x6C2690) : 0x00AC26CC  mov byte ptr [esi + 0x43], 1
CFixedWindow::Hide  0xAC2270 (rva 0x6C2270) : 0x00AC22A3  mov byte ptr [esi + 0x43], 0
```

and the twelve windows with `+0x43 == 1` are exactly what is on screen in a paused 1936 game:
`topbar`, `menubar`, `outliner` with three of its row windows, four `alerticon_window`,
`diplomessageicons_window`, `actions_list_current`. The 194 others — `country_technology`,
`division_designer`, `ship_builder_window`, `JoinGamePassword` — are built, allocated, and closed.
**A window object existing tells you nothing about whether it is on screen; `+0x43` does.**

Note what `+0x43` is *not*: `+0x44` is also a byte with a getter (`0x1602058` slot 2, `mov al,
[ecx+0x44]`) and a setter (slot 33), and it reads 0 on 2,304 of 2,305 objects. Whatever it is, it is
not visibility. Trap 12 with the two candidates one byte apart.

## 5. The live window: six name registries and seven child vectors

All offsets **relative to the `CGuiObject` pointer** (= complete `CFixedWindow` + `0x18`).

The six registries are six embedded copies of the same container as `CGui +0x34` — same vftable
`0x1602108`, same `{vftable, root, modeByte, count, …}` layout, stride `0x24`. They were found by
scanning every live gui object for the dword `0x1602108`: it appears at six offsets, on **all 206
windows and nowhere else**. Each is paired with a linked list of child names at a second offset,
stride `0x10`, and `CFixedWindow::Hide` walks the list, looks each name up in the registry and calls
`Hide` on what comes back — which is what pairs them:

| registry | name list | what the registry holds | entries, all 206 windows |
| --- | --- | --- | --- |
| `+0x324` | `+0x40C` | `textBoxType` objects (`0x15FE3B8`) | 101 |
| `+0x348` | `+0x41C` | — empty on every window | 0 |
| `+0x36C` | `+0x42C` | `editBoxType` objects (`0x15FED90`) | 7 |
| `+0x390` | `+0x43C` | `listboxType` objects, complete pointer = `CGuiObject - 4` | 78 |
| `+0x3B4` | `+0x44C` | `scrollbarType` objects (`0x15FF7A0`) | 19 |
| `+0x3D8` | `+0x45C` | — empty on every window | 0 |

The `Hide` fragment that establishes the pairing, one of six identical arms:

```
0x00AC2395  mov  edi, [esi + 0x40c]            ; head of the text-box name list
0x00AC23A0  mov  edx, [esi + 0x324]            ;   the registry's vftable
0x00AC23A6  mov  eax, [edx + 4]                ;   slot 1: find(std::string const&)
0x00AC23A9  push edi                           ;   the node, whose first field is the name
0x00AC23AA  lea  ecx, [esi + 0x324]            ;   the registry
0x00AC23B0  call eax                           ;   -> the live child
0x00AC23B6  mov  eax, [child_vftable + 0x38]   ;   slot 14
0x00AC23B9  call eax                           ;   Hide()
0x00AC23BB  mov  edi, [edi + 0x20]             ;   next node
```

For the registry counts, 101 of the 102 live text boxes and 78 of the 79 live list boxes are indexed,
so the index is essentially complete for those kinds. `confirmed` for the offsets and the kinds; the
counts are this session's.

Beside them, seven plain `begin`/`end` vectors, stride `0x20`, which `Hide` iterates without any
name lookup:

| vector | holds | elements, all 206 windows |
| --- | --- | --- |
| `+0x244` | `guiButtonType` objects (`0x1607698`) | 455 |
| `+0x264` | — empty on every window | 0 |
| `+0x284` | `iconType` objects (`CIcon`, `0x15FFC68`) | 398 |
| `+0x2A4` | `instantTextBoxType` objects (`0x15FDB70`) | 473 |
| `+0x2C4` | `OverlappingElementsBoxType` objects (`0x16013D8`) | 11 |
| `+0x2E4` | mixed: 46 buttons, **20 child windows**, 1 icon | 67 |
| `+0x304` | `checkboxType` objects (`0x15FDFC8`) | 54 |

So **a button, an icon, an instant text box or a checkbox cannot be found by name on its parent
window** — only through the type registry (which gives the type, not the object) or by scanning. A
text box, edit box, list box or scrollbar can. That asymmetry is the single most important thing in
this file for anyone writing against it: the four kinds the UI puts *numbers* in are the indexed
ones, and the ones it puts *decoration and controls* in are not.

`+0x2E4` holding child windows explains why §1's naive parent walk found 184 of 206 windows
"parentless": only 20 windows are children of another window; the rest are top level. The 686
buttons split 455 into window vectors and 92+100 into scrollbars and list boxes, leaving the
remainder as children of list box items and other non-window owners.

## 6. The payoff: reading a number the UI has already computed

`topbar`'s text-box registry at `+0x324` has sixteen entries, and the text each object is rendering
is a `std::string` at **`+0xD8`** (on the `0x15FE3B8` class) or **`+0xD0`** (on the `0x15FDB70`
instant class). Read out of the live process, with the game paused on 1936-01-01 playing Ireland:

```
registry key            object       +0x54 (own name)        +0xD8 (rendered text)
countryname             0x78947160   'CountryName'           'Ireland'
datetext                0x78946C40   'DateText'              '0:00 1, January 1936'
ic_number               0x78946200   'ic_number'             '\xa7R10/\xa7G21/21'
manpower_number         0x78945CE0   'manpower_number'       '115'
leadership_number       0x78946720   'leadership_number'     '\xa7G108%'
money_number            0x78946D88   'money_number'          '\xa7G591'
supplies_number         0x789460B8   'supplies_number'       '\xa7G391'
fuel_number             0x78945B98   'fuel_number'           '\xa7G462'
energy_number           0x78947018   'energy_number'         '\xa7G3804'
metal_number            0x78945530   'metal_number'          '\xa7G1906'
raremat_number          0x78945F70   'raremat_number'        '\xa7G951'
oil_number              0x78945A50   'oil_number'            '\xa7R1870'
national_unity_number   0x78946868   'national_unity_number' '\xa7Y80%'
dissent_number          0x789469B0   'dissent_number'        '\xa7G0.00'
diplomacy_number        0x78946348   'diplomacy_number'      '9'
espionage_number        0x789465D8   'espionage_number'       '0'
```

Four things fall out of that table and each one is worth having:

- **The text is already formatted, already coloured and already thousandths-resolved.** `\xa7` is
  `§`, the Clausewitz colour escape — `§G` green, `§R` red, `§Y` yellow. A consumer has to strip
  them, and the string is **Windows-1252**, so it goes through `Text::toUtf8` like everything else
  read out of the game.
- **`countryname` reads `Ireland`**, which agrees independently with `CCurrentGameState +0xC30`'s
  `IRE`. Two unrelated readings of who is being played, and they agree — which is also the check
  that caught the brief's "France".
- **`+0x54` is the object's own copy of its name, in the declared case** (`CountryName`,
  `DateText`), while the tree key is lowercased (`countryname`, `datetext`). That is the
  case-insensitivity of §3 visible from both ends in one object. The offset is class-specific — on
  the `0x15FDB70` instant class, `+0x54` is the *font* name, because that class has no name copy and
  everything after it shifts down by `0x1C`.
- `ic_number`'s `10/21/21` is three numbers in one string. A consumer wanting the parts wants the
  country field, not the widget; a consumer wanting *what the player sees* wants the widget. That is
  the whole trade this file exists to document.

`confirmed` for `+0xD8` and `+0xD0` as the rendered text (the strings are what the UI shows, checked
against `IC_title` reading `'Industrial Capacity'` and `supplies_value` reading `'xx'` — a widget the
game has built and not yet filled). **These particular values are one observation of one session**
and would differ in any other game; the offsets would not.

## 7. The call shape for the DLL

Two paths, and they answer different questions.

```c
// --- the type, for anything declared in a .gui file: position, size, the name itself.
//     Process lifetime after startup. Safe to hold.
//
//   CCurrentGameState* gs = CCurrentGameState::current();
//   if (!gs->in_game)              return 0;            // +0xDA4. Gate FIRST - see below.
//   void*     screen = gs->+0xBE8;                      // a CInGameIdler while in game
//   CEU3Gui*  gui    = screen->vf[14]();                // 0x64D7E0: returns [screen+0x60]
//   CGuiType* type   = gui->vf[18](&name);              // 0xA7DBC0: the TST walk, 0 on miss
//   // type->+8  = name (Hoi3CString)
//   // CWindowType: +0xA0/+0xA4 = position x,y   +0xA8/+0xAC = size x,y
//   // positionType (class 0x1606B04): +0x64/+0x68 = x,y

// --- the live object, for anything the UI has computed. Re-read every time.
//
//   for (CGuiObject** p = gui->+0x5C; p != gui->+0x60; ++p) {
//       CGuiType* t = (*p)->+0x24;
//       if (streqIgnoreCase(t->+8, wanted)) { ... }      // +0x28 is the owning CGui
//   }
//
// --- a named child of a window, without the scan. The window pointer from the vector is
//     the CGuiObject subobject; the registries are at these offsets from IT.
//
//   void* reg   = (char*)window + 0x324;                 // text boxes; +0x36C edit, +0x390
//                                                        // list, +0x3B4 scrollbars
//   void* child = ((void*(__thiscall**)(void*, const Hoi3CString*))(*(void***)reg))[1](reg, &name);
//   // or skip the string wrapper: slot 2 of the same vftable, GuiTypeTree_Find (0xA7DEE0),
//   // takes a plain const char* and the walk lowercases it, so any case works.
//   // text box text: child->+0xD8   (instant text box: +0xD0)
```

Three properties of that shape worth stating because each one is a trap:

- **The scan is the only name→object path for a top-level widget**, because `CGui +0x5C` is a flat
  vector and nothing indexes it by name. 2,305 string compares is cheap once a day and wrong every
  frame. Cache the pointer, not the result, and revalidate `+0x24` before trusting it.
- **A name is not unique.** `ic_cost_value` occurs four times live and `ic_cost_label` four times;
  the mod's `.gui` files carry 452 duplicate names. Reaching a *specific* widget means finding its
  window first and using that window's registry, not the global scan.
- **The offsets in the third block are `CGuiObject`-relative.** From a complete `CFixedWindow*` add
  `0x18`; from a list box's own pointer add `4`.

## 8. Lifetime, which is the part I can only half answer

What is established:

- **`in_game` is not enough.** A sibling reading establishes that `CCurrentGameState +0xDA4` is set
  `0x4A92` bytes before the end of `CInGameIdler::Enter`, and everything after that write builds
  `menubar`, `chat_list` and `mapmode_1`..`mapmode_10`. So **there is a window in which `in_game ==
  1` and the in-game widgets do not exist yet.** A by-name lookup in that window returns null, which
  is survivable; a blind dereference of it is not. In this session `Enter` had finished and all of
  `menubar`, `chat_list`, `mapmode_1`, `mapmode_10` are present, so the path above resolves.
- **`+0xBE8` is class-polymorphic and must be gated.** At the main menu it holds a `CFrontEnd`, not
  a `CInGameIdler`, because `CFrontEnd::CFrontEnd` makes itself the in-game screen. The *particular*
  walk above happens to survive that, because `CFrontEnd` holds the same three-byte body
  (`0x64D7E0`) at the same slot 14 and so returns the same single `CEU3Gui` — but that is a property
  of one accessor and not of the pointer. Anything else read off `+0xBE8` is reading the wrong class.
  Gate on `in_game` first, as `Gui::Lua::sessionActive()` already does.
- **A window object outlives its own visibility**, by a long way: 194 of 206 live windows are closed.
  `+0x43` is the question to ask.
- **`CGui +0x5C` appears never to be pruned.** `CFrontEnd` has **zero** live instances — a real
  negative, with the positive control that the same scan finds exactly one `CInGameIdler`, one
  `CEU3Gui`, one `CEU3Graphics` and one `CEU3Application` — and yet `JoinGamePassword`,
  `HostEditBox`, `CreateMPGameDialog`, `JoinGameButton` and about 190 other front-end widgets are
  still in the vector, still allocated, still with valid type pointers. The removal hook is there in
  the interface and empty in this class: `CFixedWindow`'s child walk calls `gui->vf[27](element)`
  before destroying each child, and slot 27 on `CEU3Gui`'s `TGui` vftable is `0x60CD50`, the shared
  `ret 4` stub. **`likely`**: the front-end widgets are retained (or leaked — the two are
  indistinguishable from outside) for the life of the process.
- **All 2,305 entries are well-formed.** Not one is a dangling pointer: every one has a readable
  `CGuiType*` at `+0x24` whose `+8` is a readable name, and `+0x28` equals the `CGui` on every one.
  So in *this* session there are no stale entries in the vector.

What is **not** established, and it is the important gap: **I did not find any code that removes an
element from `CGui +0x5C`.** Thirteen `TGui` slots push into it; a byte scan of `0xA7C000..0xA7E100`
for `add reg, 0x5C` / `lea reg, [reg+0x5C]` finds fourteen sites and every one of them is a
`push_back`. That is suggestive and it is not proof — the scan covers only `CGui`'s own bodies, and
an erase could live in a widget destructor. **So I cannot promise a pointer out of the vector stays
valid across a screen change, and BiceLib should treat it as revalidate-before-use.** The decisive
experiment is cheap and needs a hand on the keyboard: snapshot `CGui +0x60 - CGui +0x5C`, leave to
the main menu, load a different game, and look again. If the count only ever rises, nothing is
removed and every pointer is permanently valid; if it falls, the vector is pruned and a held pointer
can dangle. One save/load answers it and I could not run it.

## 9. Side results, and what they correct in the record

- **`CInGameIdler +0x178C` is the `CEU3Graphics`.** `project.json` has it as `session_sibling` with
  "Not identified"; `FINDINGS-gui.md` §8 argued it was the graphics from two members of the
  `CGraphics` constructor. Live: `[idler+0x178C]` equals the process's only `CEU3Graphics`, byte for
  byte, and so does `CGui +0x30`. **`confirmed`**; wants renaming to `graphics`.
- **`CInGameIdler +0x1790` is the `CEU3Application`.** It is recorded as `session_manager`. Live:
  `[idler+0x1790]` equals the one live `CEU3Application`. That makes `FINDINGS-gui.md` §9 item 3
  mostly answered too — `CInGameIdler` slot 15 is `[this+0x1790]->[0x124]`, so the object it returns
  is **`CEU3Application +0x124`**, one slot past `+0x120`, which that file established is the
  `CEU3Gui`. The object itself has no RTTI and I did not identify it; the billboards are registered
  in *its* `+0x1DF0` array. **`confirmed`** for the `CEU3Application` identification, and the name
  `session_manager` is wrong.
- **`CGraphics +0x6B9BC` is the screen width.** `FINDINGS-gui.md` §9 item 4 called it inference from
  a neighbour. Live it reads **1920** next to `+0x6B9C0`'s **1080**, which also confirms the existing
  `screen_height` name on `+0x6B9C0`. **`confirmed`**.
- **`CInGameIdler::Enter`'s unit-row arithmetic reproduces exactly.** `+0x1DF0` reads `0x00900000`
  (x=0, y=144), `+0x1DF4` reads `0x00280010` (x=16, y=40), `+0x1DF8` reads **22**, and
  `(1080 - 144) / 40 - 1 = 22`. Every term of `FINDINGS-gui.md` §4's worked example checked against
  the live process. **`confirmed`.**
- **`FINDINGS-gui.md` §9 item 2 is closed: `CBillboardType`'s vftable is `0x1605258`.** That file
  found it by scanning `.rdata` for the table holding `0xB07340` at slot 18 and marked the whole §6
  identification `likely` because of it. Live: there are **20,546** objects with vftable `0x16010D0`,
  the modal heap spacing between them is `0xB88` (against the `0xB48` allocation that file read off
  the `new`), **every one** of them holds a type pointer at `+0x138`, and **every one** of those
  types has vftable `0x1605258` and a name that `interface/mapitems.gfx` declares as a
  `billboardType`: `capital` 10642, `counter_arrow` 5620, `building_fake_air_base` 815,
  `building_naval_base` 698, `resource_energy` 595, `resource_metal` 497, `building_anti_air` 471,
  `resource_raremat` 391, `building_land_fort` 255, `building_fortress` 193, `resource_oil` 109,
  `building_coastal_fort` 99, then nineteen `STRATEGIC_*`. One class, one type class, 106
  `billboardType` declarations in the file. **§6's `likely` can go to `confirmed`**, and `+0x138` as
  the type pointer on the object is confirmed too.
- **But §9 item 9(c)'s prediction is wrong as stated.** It predicted "two billboards per combat and
  none otherwise" from `findInstances.py` on `0x16010D0`. There are 20,546 of that class with **no
  combat in progress at all**: it is the billboard class for everything on the map, not for
  combat_status. What is true is the narrower claim: **no live object of that class has a non-empty
  caption at `+0xB2C`** (checked on all 20,546) and **no live billboard's type is `combat_status` or
  `combat_status_close`** — consistent with the two being created on demand per combat and freed
  with it. The right live check for §6 is still waiting for a battle.
- **`FINDINGS-gui.md` §9 item 5 is answered by the fact base, not by this work.** See §0.

## What is not established

1. **Whether anything removes an element from `CGui +0x5C`.** §8. This is the one gap that affects
   the DLL's correctness and the experiment is one save/load.
2. **Nine of the twelve live widget classes cannot be named.** The image's RTTI contains no
   `CTextBox`, `CListbox`, `CScrollbar`, `CEditBox`, `COverlappingElementsBox` or `CCheckBox` name
   anywhere — swept over every hierarchy descriptor in the export, with the positive control that
   the same sweep recovers `CIcon`, `CButton`, `TButton`, `CFixedWindow`, `TWindow`, `CGuiObject`,
   `CStandardlistboxItem` and `TListboxItem`. §11 records them by their `.gui` keyword and flags the
   names as ours. *Cheapest route to real names:* a log or assert string inside one of the twelve
   constructors; Paradox classes usually name their own `.cpp`.
3. **Registries 1 (`+0x348`) and 5 (`+0x3D8`) are empty on all 206 windows**, so what they hold is
   unknown. Their name lists (`+0x41C`, `+0x45C`) are empty too, so this is not a half-built index —
   nothing in the loaded mod puts anything in them. *Cheapest check:* read the `CWindowType::LoadKey`
   case that fills the corresponding list; the six lists are at a `0x10` stride so the handlers
   should be adjacent.
4. **`CFixedWindow +0x4C` is a linked list of something.** Slot 36 (`0xAC1220`) walks it via node
   `+8` and for each node calls `gui->vf[27](node->+0)` and then `node->+0`'s slot 36. Nodes are
   `0x18` bytes and hold gui objects, 3D objects and `0x16010D0` billboards indiscriminately, which
   makes a draw or collision list the obvious reading and that is **inference from the membership,
   not a reading**. `CGui +0x44` points at a chain of the same node shape. *Cheapest check:* read
   `gui` slot 27 on a class that overrides it — on `CEU3Gui` it is the empty stub.
5. **The object `CInGameIdler` slot 15 returns, `CEU3Application +0x124`.** Identified as a field,
   not as a class; it has no RTTI. It owns the billboards and carries the `+0x1DF0` array indexed by
   province id.
6. **`CFixedWindow +0x228` is a packed `x | y << 16`** returned through slot 15 (`0xAC3590`), and
   `+0x238` is written by slots 1 and 6. Neither was checked against anything. `topbar` reads
   `+0x228 = 0`, `rightClickMenu` reads `0x012C012C` = (300, 300).
7. **`CFixedWindow +0x43` against `+0x44`.** `+0x43` is visibility; `+0x44` has its own getter and
   setter (slots 2 and 33) and reads 0 on 2,304 of 2,305 objects. What it is was not established.
8. **Which three gui type names are duplicated.** The count says three; identifying them means
   diffing the mod's top-level names against the vanilla folder's in load order.
9. **`CFixedWindow +0x46C`** is the first thing both `Show` and `Hide` dispatch into, before any
   child. Not identified.
10. **Every number in this file that is a count is this session's.** 2,305 objects, 1,547 types, 206
    windows, 12 open windows, 20,546 billboards, and all sixteen topbar strings would be different
    in another game, at another resolution, or with another mod. What survives a restart is the
    offsets, the class-to-keyword map, the call shape, and the static function bodies. What does not
    is every table of counts, and `countryname = 'Ireland'` most of all.
