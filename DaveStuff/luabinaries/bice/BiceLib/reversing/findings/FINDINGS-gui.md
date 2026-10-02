# The GUI framework: finding a thing by name, and what the combat-status "window" really is

Read statically off `hoi3_tfh.exe` on 2026-10-02; the game was not running, so nothing here is
marked *seen*. Addresses are **virtual** (image base `0x400000`) with the rva beside them wherever
a finding depends on it. The starting point was `FINDINGS-combat3.md`'s open item 2 — the classes
of `CCombat +0x2C` and `+0x30` — and the brief's four questions about the GUI layer. Scripts are
in `scratchpad/gui/`.

## In one line

`combat_status` is not a window: it is a `billboardType` in `interface/mapitems.gfx`, and the
lookup that finds it runs against the **object-type registry at `CGraphics +0x6BCF0`**, a
511-bucket chained hash whose elements are `CObjectType` subclasses keyed by a `std::string` at
`+8`; `CCombat +0x2C` and `+0x30` hold two live billboard objects of the 0xB48-byte class with
vftable `0x16010D0`, built by `CBillboardType::CreateInstance` (`0xB07340`), and their slot 24 is
`C3dVisibleObject::SetFrame` writing a `short` at `+0x4E`, which is why it takes 0, 1 or 2 — the
`.gfx` entry says `noOfFrames = 3`; the brief's claim that the close billboard's slot 24 takes no
argument is wrong, the compiler hoisted the push. `StringHashFind` serves **at least seven**
registries, five of them on `CGraphics`, and the **GUI type registry is not one of them**: gui
types live in a case-insensitive **ternary search tree** at `CGui +0x34`, filled by
`CGui::LoadKey`, whose entire top-level grammar is the single key `guiTypes`, reached by
`CEU3Gui::GetGuiType` = **TGui slot 18**. `CGuiType +8` is the name, `CWindowType +0xA0` the
position and `+0xA8` the size, and `CInGameIdler::Enter` is the worked example of reading a number
the UI already computed: it divides the screen height by a `positionType`'s declared `y` to get
how many unit rows fit.

---

## 0. Method, and the one thing that would have gone wrong

Everything below rests on three scans over the executable plus the mod's own `interface/` folder as
the oracle, and the oracle is what caught the premise error. The brief, `FINDINGS-combat3.md` and
`project.json` all describe `CCombat +0x2C` as a *GUI window* named `combat_status`. One grep —

    grep -rn "combat_status" interface/

— answers `interface/mapitems.gfx:101: name = "combat_status"`, inside an `objectTypes = { ... }`
block, as a `billboardType`. Every structural question after that had a different answer. **The
file on disk was cheaper than any of the three code paths and it was the only thing that said the
subject was wrong**, which is the same lesson `map/region.txt` taught the blacklist work.

The three scans, all in `scratchpad/gui/`:

- `dispscan.py <value>` — every `.text` instruction whose memory displacement or immediate equals a
  value, realigning the decode so an instruction *contains* the located bytes (the trick
  `findRefs.py` uses; decoding from a guess is trap 9).
- `names.py <tableDisplacement>` — for every `add reg, <disp>; … call 0x9C7D60` site, the string
  literal pushed just before it. This is what identifies a registry: the names it is asked for,
  checked against the `.gfx`/`.gui` files.
- `tables.py` — how EAX was formed at each of `StringHashFind`'s 206 call sites, which counts the
  registries it serves.
- `factories.py` / `ctors.py` — every caller of a base constructor, the vftable the derived
  constructor then writes, and the `push <size>` that fed `operator new` before it.

## 1. The registry the `combat_status` lookup runs against

### Where it lives

`CCombat::UpdateCombatStatusWindow` (`0x57BD70`, rva `0x17BD70`) builds the table pointer like this:

```
0x57BE0B  mov  edi, [[0x1A89790] + 0xBE8]     ; g_CCurrentGameState->in_game_screen, a CInGameIdler
0x57BE13  push 0x15C4C78                      ; 'combat_status'
0x57BE29  call 0x40A160                       ; std::string ctor on the stack
0x57BE3C  call [edi_vftable + 0x3C]           ; CInGameIdler slot 15
0x57BE3E  lea  ebx, [eax + 0xA70]
0x57BE4B  call [edi_vftable + 0x44]           ; CInGameIdler slot 17 = GetSessionSibling
0x57BE51  add  eax, 0x6BCF0
0x57BE56  call 0x9C7D60                       ; StringHashFind(table@EAX, &name)
```

`CInGameIdler` slot 17 is `0x64D7D0` (rva `0x24D7D0`), three bytes: `mov eax,[ecx+0x178C]; ret`.
`project.json` already names `CInGameIdler +0x178C` `session_sibling` and says "what it is has not
been established". **It is the `CEU3Graphics`.** Two independent uses settle it:

- `+0x6BCF0`, the table, is initialised by the constructor at `0xA6DAB0` (rva `0x66DAB0`), which is
  the constructor of `CEU3Graphics`' base — `0x840680` (rva `0x440680`) calls it and then writes
  `CEU3Graphics`' own vftables `0x15E14C8` / `0x15E14E0`, which the RTTI export names.
- `CInGameIdler::Enter` reads `[this+0x178C]`'s `+0x6B9BC` and `+0x6B9C0` at `0x65A488`, and both
  are written by that same constructor at `0xA6DD33`/`0xA6DD3C`.

So the field is a `CEU3Graphics*`, and `CGraphics` is its base at object offset 0, so
`CGraphics +0x6BCF0` and `CEU3Graphics +0x6BCF0` are the same address. **`session_sibling` wants
renaming to `graphics`** (see §8).

### What it is

A 511-bucket chained hash in exactly the shape `StringHashFind`'s own entry already describes.
From the constructor (`ebx` is the `CGraphics`, and `edi` is 0 by then — `xor edi,edi` at
`0xA6DE6E`, which is worth checking because `edi` held `0x1FF` earlier in the same body):

```
0x00A6DE9F  mov  eax, 0x1FF
0x00A6DEA4  mov  [ebx + 0x6BCF4], eax          ; bucketCount = 511
0x00A6DEB4  mov  [ebx + 0x6BCF0], edi          ; count = 0
0x00A6DEBF  call 0xB94BEC                      ; allocate 511 * 4
0x00A6DED1  mov  [ebx + 0x6BCF8], eax          ; buckets
```

So the table base is `+0x6BCF0`: `{int count; unsigned bucketCount; Node** buckets;}`, which is why
`add eax, 0x6BCF0` is what gets handed to the find.

### What it holds, and that the key is at `+8`

The insert half is **`0x542D80`** (rva `0x142D80`), and it takes the table in **EDI** and the value
on the stack:

```
0x00542D83  mov    ecx, [ebp+8]                ; the value being inserted
0x00542D86  cmp    [ecx + 0x1C], 0x10          ; std::string SSO test at value+8
0x00542D8D  mov    esi, [ecx + 8]              ;   long form: the heap buffer
0x00542D92  lea    esi, [ecx + 8]              ;   short form: the inline buffer
0x00542D95  mov    edx, [ecx + 0x18]           ; its length
0x00542DA8  imul   eax, eax, 0x3D              ; h = (h + c) * 61
0x00542DB2  div    [edi + 4]                   ; modulo bucketCount
0x00542DB5  push   8                           ; new node {value, next}
0x00542DD9  inc    [edi]                       ; ++count
```

Same hash, same modulus, same node shape, and the **key is the `std::string` at `value + 8`** —
which is what `StringHashFind`'s own entry says about this instantiation. So the elements are
objects with a `std::string` name at `+8`.

Its one caller is `CEU3Graphics::LoadKey`'s `objectTypes` case (§2), which hands it
`(CGraphics+4) + 0x6BCEC` — i.e. `CGraphics + 0x6BCF0`, because inside `LoadKey` `this` is the
`CPersistent` subobject at `+4`. **Reading that `0x6BCEC` as the table base would have put every
field in this section four bytes out**; the `lea eax,[edi-4]` two instructions earlier is the tell.

### The element class

`objectTypes` entries are `CObjectType` subclasses. The RTTI export gives the whole family:

```
CObjectType : CPersistent
  C2dObjectType
    CSpriteType
      CMaskedSpriteType          vftable 0x15E1D44
  C3dObjectType
    CBillboardType
      CWeatherBillboardType      vftable 0x15E3F44
    CCounterType                 vftable 0x15E1324
    CFlagType                    vftable 0x15E1624
    CMasked3dFlagType            vftable 0x15E1B2C
    CProjectionType              vftable 0x15E1FDC
    CProvinceType                vftable 0x15E35E4
    CProvinceWaterType           vftable 0x15E37EC
```

`CObjectType +8` is therefore the `name`, and the `objectTypes` keywords in the `.gfx` files —
`billboardType`, `mapinfo`, `animatedmaptext`, `mapTextType`, `projectionType`, `battlearrow`,
`Masked3dFlag`, `weatherBillboardType`, `maskedShieldType`, `EMFXActorType` — are the subclasses.
`CProjectionType::LoadKey` is already in `FINDINGS-definitions.md` at rva `0x44E330`, and its keys
(`spin`, `pulsating`, `pulseLowest`, `pulseSpeed`, `additative`, `expanding`, `duration`, `fadeout`,
`size`, `textureFile`) are exactly the keys `projectionType = { }` uses in `interface/mapitems.gfx`.
That is the fit that makes the family identification more than a name match.

### The positive control on the name list

`names.py 0x6BCF0` recovers the literal pushed at each of this table's lookup sites. Every one that
resolves is a name declared inside an `objectTypes = { }` block:

| name looked up | declared in |
| --- | --- |
| `combat_status`, `combat_status_close`, `counter_arrow`, `unit_counter`, `unit_counter_close`, `capital`, `allied_objective`, `icon_objective_strip`, `air_battle_icon`, `air_bombed_us_icon`, `air_bombed_them_icon`, `large_air_base`, `large_anti_air`, `large_naval_base`, `naval_convoy_raided_icon`, `naval_convoy_sunk_icon`, `naval_raider_defended_icon`, `naval_raider_attacked_icon` | `interface/mapitems.gfx` |
| `invasionArrow`, `moveArrow`, `unitInvasionArrow` | `interface/arrows.gfx` |
| `mi_text` | `interface/battlearrow.gfx` |
| `MessageMapText`, `MapObjectiveOther` | `interface/core.gfx` |

Not one of them is a `.gui` name, and not one is a `spriteType`. Three literals did not resolve to a
file (`Generic`, `Rank`, `NOTOOLTIP`); those are built up at runtime from a prefix plus a suffix, so
the literal the scan recovers is only the prefix.

### `StringHashFind` is generic: how generic

`tables.py` resolves how EAX was formed at each of the **206** direct call sites:

```
  add  0xA0        63 sites        lea 0xA0        7 sites
  add  0x6BCF0     49 sites        lea 0x6BCF0     2 sites
  add  0x10        19 sites        lea 0x10        8 sites
  add  0x2C        11 sites
  add  0x4C         4 sites
  add  0x1C         3 sites
  abs  0x1          1 site         unresolved     39 sites
```

So **at least seven distinct registries**, and the object-type one is the second biggest consumer.
The 39 unresolved sites are honest: the scan only understands `add reg, imm`, `lea reg, [reg+imm]`
and `mov reg, imm32`, and gives up rather than guess.

### The other four registries on `CGraphics`

`CEU3Graphics::LoadKey` (`0xA70EB0`, rva `0x670EB0`, already in the record with its five keys) is a
flat switch, and each case hands a table address to a reader. `this` inside it is the `CPersistent`
subobject at `CGraphics+4`, so every `edi + N` below is `CGraphics + N + 4`:

| key | token | reader | table |
| --- | --- | --- | --- |
| `fonts` | 28 | `0xA78210` | **`CGraphics +0x88`** |
| `bitmapfonts` | 335 | `0xA78210` | **`CGraphics +0x94`** |
| `spriteTypes` | 52 | `0xA78170` | **`CGraphics +0xA0`** |
| `lightTypes` | 82 | `0xA78170` | **`CGraphics +0xAC`** |
| `objectTypes` | 54 | `0xA78170` into a temporary, then `0x542D80` per element | **`CGraphics +0x6BCF0`** |

All five are the same `{count, 511, buckets}` shape, all five are initialised in the same
constructor, and `0xA6F5E0` tears down exactly these five together, which is independent
corroboration that they are one family of five and not four plus a coincidence.

`names.py 0xA0` confirms the sprite table the same way: every literal it recovers is a `GFX_*` name
(`GFX_topbar_bg`, `GFX_terrainimg_plains`, `GFX_no_ship_selected`, `GFX_empty_position`,
`GFX_theatres_`, `GFX_counter_`, `GFX_small_counter_`, `GFX_map_counter_`), and `spriteType = { name
= "GFX_..." }` is what `interface/*.gfx` declares 6,881 times.

## 2. The loaders

### `.gfx`

`CEU3Graphics::LoadKey` is the whole grammar of a `.gfx` file and it was already in the record. What
is new is the layout: which key fills which table, in the table above. The `objectTypes` case is the
only one that is not a straight "parse into this table":

```
0x00A70F6B  call 0xA78170                      ; parse the block into a temporary vector
0x00A70F9C  call [objectType_vftable + 0x3C]   ; slot 15, a per-element predicate
0x00A70FA5  je   0xA70FBC                      ;   false -> log and drop
0x00A70FAC  add  edi, 0x6BCEC                  ; edi was CGraphics+4
0x00A70FB2  call 0x542D80                      ; insert
```

and the failure arm logs `Failed to load 3d object type = <name>` from `graphics.cpp:1258`. So an
object type that fails its own slot-15 check never reaches the registry, and the only evidence a mod
author gets is that line in `setup.log`.

### `.gui`

The brief's three strings — `LOADING_GUI_DEF` (`0x15CC884`), `Loaded GUI Definition File: `
(`0x15CC89C`) and `Loading GUI <` (`0x15CC8D8`) — are all in `CEU3Application::LoadEverything`
(rva `0x22FAC0`, already named), and the last two are a progress log and a **stage timer**
respectively, not the loader. The loader is three instructions in that function:

```
0x006320E0  mov  eax, [edi + 0x120]            ; edi = CEU3Application; +0x120 = the CEU3Gui
0x006320EA  lea  ecx, [eax + 4]                ; its CPersistent subobject
0x006320F3  mov  eax, [vftable + 0xC]          ; slot 3 = CPersistent::Load (0xA7C050)
0x006320F7  call eax                           ; with the parsed file
```

`CEU3Gui`'s `CPersistent` vftable is `0x15CD7D8`; slot 4 is `0xA7D700`, inherited unchanged from
`CGui` (`0x15FDA90` slot 4 is the same address). So **the `.gui` grammar is `CGui::LoadKey`, rva
`0x67D700`** — and it has exactly one case:

```
0x00A7D703  cmp  [ebp+0xC], 0x7B               ; token 123
0x00A7D707  jne  0xA7D735                      ; anything else: ignored in silence
0x00A7D709  lea  eax, [ecx - 4]                ; the CGui  (this is CGui+4 inside LoadKey)
0x00A7D710  lea  eax, [ecx + 8]                ; CGui+0xC = the CFactory base
0x00A7D714  add  ecx, 0x30                     ; CGui+0x34 = the gui-type registry
0x00A7D71C  call 0xA7DF60                      ; read the block, creating through the factory
```

Token 123 is `guitypes`. **The oracle fits exactly**: across the mod's 102 `interface/*.gui` files
there are only three top-level keys, and 52 of the 54 occurrences are `guiTypes = {`. (The other
two files open with `windowType = {` and `instantTextBoxType = {` at column 0 — those files load
nothing at all, because `CGui::LoadKey` drops every token but 123. That is a real, silent mod bug of
exactly the kind `FINDINGS-script.md` describes.)

`0xA7DF60`'s three arguments name the three halves of the mechanism and confirm `CGui`'s base
layout, which the RTTI export gives as `CGui : TGui(0), CPersistent(4), CFactory(12)`:
the parse context, `&CGui+0x34` (where the entries go) and `CGui+0xC` (the factory that knows which
subclass each inner keyword builds).

### The gui-type grammar, three levels of it

Inner keywords in the mod's `.gui` files, by frequency: `positionType` 992, `guiButtonType` 939,
`iconType` 757, `instantTextBoxType` 584, `windowType` 325, `textBoxType` 277, `checkboxType` 96,
`listboxType` 90, `scrollbarType` 33, `OverlappingElementsBoxType` 20, `editBoxType` 14,
`eu3dialogtype` 7, `shieldtype` 4.

The `LoadKey` chain for one of them, read from `CEU3DialogGuiType` down:

```
CEU3DialogGuiType::LoadKey   0x63DD10 (rva 0x23DD10)   1 key:  shieldtype (448)
    default -> CWindowType::LoadKey   0xAC55E0 (rva 0x6C55E0)   28 cases
        default -> CGuiType::LoadKey  0xAC8710 (rva 0x6C8710)    5 cases
```

`CEU3DialogGuiType::LoadKey` is already in the record as "1 of them, one case each: `shieldtype`",
which is right as far as it goes — the note that it forwards to a base was missing, and the base
carries 33 more keys.

`CGuiType::LoadKey`'s five, the ones every gui element accepts: `name`, `dontRender`, `pdx_tooltip`,
`pdx_tooltip_delayed`, `scope`.

`CWindowType::LoadKey`'s 28, of which `switchmap.py` could name 22 against the compiled token table:
`size`, `position`, `fullScreen`, `parent`, `priority`, `background`, `moveable`,
`verticalScrollbar`, `horizontalScrollbar`, `horizontalBorder`, `verticalBorder`, and the child
elements `windowType`, `guiButtonType`, `iconType`, `textBoxType`, `editBoxType`, `checkboxType`,
`listBoxType`, `scrollbarType`, `3dButtonType`, `multiSpriteButtonType`, `threeDguiType`.
**Ignore `switchmap.py`'s class column on this one** — it reports `std::length_error` and
`std::out_of_range` for eight cases, because the last vftable each case body writes belongs to the
`std::string` throw helper rather than to the element being built. That is the tool's documented
failure mode and it is not a finding about the GUI.

## 3. How you find a gui type by name, and it is not `StringHashFind`

`CInGameIdler::Enter` is the clean example, because the record already cites its
`Missing unitlist_start or unitlist_offset gui type.` message:

```
0x0065A2EB  push 0x15CE198                     ; 'unitlist_start'
0x0065A31E  call 0x40A160                      ; std::string on the stack
0x0065A32C  mov  edx, [idler_vftable + 0x38]   ; CInGameIdler slot 14
0x0065A331  call edx                           ; -> [idler + 0x60]
0x0065A335  mov  edx, [result_vftable + 0x48]  ; slot 18 of what came back
0x0065A342  call edx                           ; (&name) -> the gui type, or null
```

`CInGameIdler` slot 14 is `0x64D7E0` (rva `0x24D7E0`): `mov eax,[ecx+0x60]; ret`. `CFrontEnd` holds
the same body at the same slot, so `+0x60` is a `CEU3Idler` member. Slot 18 of what it returns is
`0xA7DBC0`, which is `TGui`'s slot 18 on `CEU3Gui`'s own vftable `0x15CD754` — so **`CInGameIdler
+0x60` is the `CEU3Gui`**, and slot 18 is the by-name lookup. (`likely`: the write to `+0x60` was
not located, and the identification rests on slot 18 of the returned object being `TGui`'s.)

The lookup itself is four small bodies and no hash at all:

```
0x00A7DBC0  add  ecx, 0x34                     ; CGui+0x34, the embedded registry
0x00A7DBC3  mov  eax, [ecx]                    ; its vftable, 0x1602108
0x00A7DBC6  mov  eax, [eax + 4]                ; slot 1
0x00A7DBCC  jmp  eax                           ;   -> 0xAACE70

0x00AACE70  ; std::string -> const char*, then tail-call slot 2 (0xA7DEE0)

0x00A7DEE0  cmp  [ecx + 4], 0                  ; the tree root, at CGui+0x38
0x00A7DEEA  jne  ...                           ; empty -> null
0x00A7DEF3  jmp  0xA7E030

0x00A7E030  ; the walk
0x00A7E040  movsx eax, byte ptr [ebx]          ; the query character
0x00A7E046  call  0xB96692                     ; tolower
0x00A7E04B  movsx ecx, byte ptr [edi + 4]      ; the node's character
0x00A7E052  sub   eax, ecx
0x00A7E054  jne   0xA7E061                     ;   mismatch
0x00A7E056  cmp   byte ptr [ebx + 1], al       ;   match and end of string -> found
0x00A7E05B  inc   ebx                          ;   match, more to go: descend the equal child
0x00A7E05C  lea   esi, [edi + 0x10]
0x00A7E061  lea   esi, [edi + 0xC]             ;   mismatch, go high
0x00A7E068  lea   esi, [edi + 8]               ;   mismatch, go low
0x00A7E079  mov   edx, [esi]; mov eax, [edx]   ; the node's stored pointer
```

So the GUI registry is a **ternary search tree**, node `{void* value; char key; Node* low; Node*
high; Node* equal;}` at `+0`, `+4`, `+8`, `+0xC`, `+0x10`, and the comparison is
**case-insensitive**: the query is lowercased per character. That last point matters for a mod —
`guiTypes` and `guitypes` are the same name to the tree, and so are two window names differing only
in case, which is a collision the loader will not warn about.

**The call shape BiceLib needs, for a type:**

```
CEU3Gui*  gui  = idler->vf[14]();          // 0x64D7E0: [idler + 0x60]
CGuiType* type = gui->vf[18](&name);       // 0xA7DBC0: tolower-insensitive TST walk, null on miss
```

Nothing allocates, nothing caches, the string argument is an ordinary `std::string`, and the result
is a long-lived pointer: the tree is built once in `CEU3Application::LoadEverything` and the types
are never rebuilt during a session. **Lifetime is the whole process after startup.** That makes it
safe to hold, unlike anything in §6.

## 4. What a gui type holds

Two offsets are read directly out of the loader, and both are `confirmed` because the store is in
the handler:

```
CGuiType::LoadKey, key 0x1A (name):
0x00AC8772  add  edi, 8                        ; edi = this (CGuiType is CPersistent-derived at 0)
0x00AC8776  call 0xA7AFB0                      ; ParseString (already named, rva 0x67AFB0)

CWindowType::LoadKey, key 0x4B (position):
0x00AC5658  lea  edi, [ebx + 0xA0]
0x00AC565E  call 0xA7B670                      ; the `{ x = y = }` reader

CWindowType::LoadKey, key 0x2E (size):
0x00AC5703  lea  edi, [ebx + 0xA8]
0x00AC5709  call 0xA7B670
```

So **`CGuiType +8` is `name`** — the same offset as `CObjectType +8`, which is why one
`StringHashFind` instantiation keyed at `value+8` can serve both families — and on a `CWindowType`,
**`+0xA0` is `position` and `+0xA8` is `size`**, each a pair of ints.

### The worked example: reading a number the UI already computed

`CInGameIdler::Enter` looks up two `positionType` entries and derives a layout from them:

```
0x0065A436  mov  eax, [esp + 0x44]             ; (short)start->x | (short)start->y << 16
0x0065A43A  mov  [ebx + 0x1DF0], eax
0x0065A45E  mov  [ebx + 0x1DF4], eax           ; the same packing for unitlist_offset
0x0065A464  cmp  word ptr [ebx + 0x1DF6], 0
0x0065A47B  mov  word ptr [ebx + 0x1DF6], cx   ;   guard: 0 -> 1
0x0065A482  mov  eax, [ebx + 0x178C]           ; the CEU3Graphics
0x0065A48E  mov  eax, [eax + 0x6B9C0]          ; the screen height
0x0065A494  movsx ecx, word ptr [ebx + 0x1DF2] ; unitlist_start.y
0x0065A49B  sub  eax, ecx
0x0065A49D  movsx ecx, word ptr [ebx + 0x1DF6] ; unitlist_offset.y
0x0065A4A9  idiv ecx
0x0065A4AB  dec  eax
0x0065A4AC  mov  [ebx + 0x1DF8], eax           ; how many unit rows fit on screen
```

and `interface/unitpanel.gui` declares

```
positionType = { name = "unitlist_start"  position = { x = 0  y = 144 } }
positionType = { name = "unitlist_offset" position = { x = 16 y = 40  } }
```

`rows = (screenHeight - 144) / 40 - 1`. Every term of that is accounted for by the file, which is as
tight a fit as this folder gets. Two caveats, both important:

- The position is read at `[type + 0x64]` / `[type + 0x68]` on these objects, **not** at `+0xA0`.
  A `positionType` is a different `CGuiType` subclass from a `CWindowType`, and `CWindowType` has its
  `CFactory` base at offset 100 (`0x64`) — so `+0x64` is a vftable pointer on a window type and a
  coordinate on a position type. **The offset of `position` is per-subclass**; this is trap 12 with a
  worked collision. Use `+0xA0` only when you know the object is a `CWindowType` descendant.
- `CGraphics +0x6B9C0` as the screen height is `likely`: the arithmetic only works if it is a height
  in pixels, and the `y` values make it a height rather than a width, but the writer was not read.

## 5. `StringHashFind`'s own entry needs no correction

It is `confirmed` and it is right: 206 call sites, `{count, bucketCount, buckets}`,
`h = (h + c) * 0x3D`, key at `value+8`, no class on the name because the body is shared. What this
file adds is the identity of two of its owners (`+0xA0` sprite types, `+0x6BCF0` object types, both
on `CGraphics`) and the name of the insert half for that instantiation (`0x542D80`, rva `0x142D80`).
Note the existing entry's claim that "the insert half at `0x5C87C0`" keys at `value+4`: that is a
*different* instantiation, and the one these two tables use is `0x542D80` with the key at `value+8`.
Both can be true; they are two template expansions.

## 6. The classes of `CCombat +0x2C` and `+0x30` — `FINDINGS-combat3.md` open item 2, closed

### What `combat_status` is

```
# interface/mapitems.gfx
objectTypes = {
    billboardType = {
        name = "combat_status"
        textureFile = "gfx\\mapitems\\combat_status.dds"
        scale = 2.6
        noOfFrames = 3
        font_size = 7
        offset2 = { 0.0 0.0 -2.5 }
        font = "Arial_17_black"
    }
    billboardType = {
        name = "combat_status_close"
        textureFile = "gfx\\mapitems\\combat_status.dds"
        scale = 1.7
        noOfFrames = 3
        font_size = 7
        offset2 = { 0.0 0.0 -3.0 }
        font = "Arial_17_black"
    }
}
```

A billboard with three frames and a font. **`noOfFrames = 3` is why slot 24 is called with 0, 1 or
2**, which is the first and cheapest check anyone could have run on the old reading.

### From the type to the object

The registry hands back a `CBillboardType`; its **slot 18** is the factory:

```
0x0057BE5B  mov  edx, [eax]                    ; eax = the CObjectType the find returned
0x0057BE5D  mov  ecx, eax
0x0057BE5F  mov  eax, [edx + 0x48]             ; slot 18
0x0057BE62  call eax                           ; -> the live object
0x0057BE7F  mov  [esi + 0x2C], ecx             ; cached on the CCombat
```

Slot 18 is `CreateInstance` across the whole `C3dObjectType` family, each one a `new <size>` followed
by the matching constructor:

| type | slot 18 | size | object vftable |
| --- | --- | --- | --- |
| `C3dObjectType` (inherited by `CProjectionType`, `CProvinceType`, `CProvinceWaterType`) | `0x83AD10` | `0x138` | `0x15B4B54` (`C3dVisibleObject`) |
| `CCounterType` | `0x83BB00` | `0x1C0` | `0x15E0F6C` (`CCounterObject`) |
| `CMasked3dFlagType` | `0x84B600` | `0x158` | `0x15E1BAC` (`CMasked3dFlag`) |
| **`CBillboardType`** (table `0x1605258`, inherited by `CWeatherBillboardType`) | **`0xB07340`** | **`0xB48`** | **`0x16010D0`** |
| `CFlagType` | `0xA80690` (the shared empty stub) | — | creates nothing |

### The identification

`CCombat +0x2C` and `+0x30` are objects of the class with vftable **`0x16010D0`**, 94 slots, size
`0xB48`, constructed by `0xAB68F0` (rva `0x6B68F0`) which calls the `C3dVisibleObject` constructor
`0x4011B0` and then writes its own vftable and `[this+0x138] = the type`. Confidence **`likely`**,
on four pieces of evidence that all have to be wrong together:

1. **The five slots the combat code calls are all present and all make sense on this table** —
   13, 24, 37, 44 and 90, named in §7. On an 11-slot `CEU3DialogGuiType` vftable, which is what a
   "GUI window" reading would require, slot 90 (`+0x168`) does not exist at all. That alone kills
   the old reading.
2. **The caption.** `CCombat::UpdateCombatStatusWindow` does
   `mov ecx,[esi+0x2C]; add ecx,0xB2C; call 0x401BD0` — `std::string::assignString`, already named.
   Of the 23 classes that derive from `C3dVisibleObject`, exactly one has a `std::string` at
   `+0xB2C`: its constructor `0xAB68F0` initialises it at `0xAB698F`, and its accessors at
   `0xAB6A00` and `0xAB6BE0` are the only other code in the image that touches that displacement on
   such an object. `0xB2C + 0x1C` (the size of an `Hoi3CString`) is `0xB48`, the allocation size,
   exactly — the caption is the last member.
3. **`noOfFrames = 3` against slot 24's three argument values.**
4. **`CBillboardType` is the only `objectTypes` subclass whose factory produces a `0xB48` object**,
   and `combat_status` is declared a `billboardType`.

What keeps it off `confirmed`: `CBillboardType`'s own vftable (`0x1605258`) was identified by
scanning `.rdata` for the table that holds `0xB07340` at slot 18, not by reading a
`CBillboardType` constructor — the class has no RTTI entry, so `vtable.py --holding` cannot see it
(it only knows the export's tables). §9 says what closes that.

### `project.json` is wrong here and needs the overwrite script

```
CCombat +0x2C  "combat_status_window"        "The cached GUI window named 'combat_status' …"
CCombat +0x30  "combat_status_close_button"  "The cached GUI element … Its slot 24 is called
                                              with no argument each tick."
```

Three corrections: they are billboards, not GUI objects; the type should be the billboard class
rather than `void*`; and **slot 24 on `+0x30` does take an argument** — see §7.

## 7. The slot vocabulary

Every slot below is a slot of **`C3dVisibleObject`**'s vftable `0x15B4B54` (rva `0x11B4B54`), which
the billboard class shares except where noted. Each body is small enough to read whole, which is
what makes these `confirmed`.

| slot | `+disp` | body | what it is |
| --- | --- | --- | --- |
| 13 | `+0x34` | `0xA60440` — `mov byte [ecx+0x29], 1; ret` | `Show()` |
| 14 | `+0x38` | `0xA60450` — `mov byte [ecx+0x29], 0; ret` | `Hide()` |
| 15 | `+0x3C` | `0x4010A0` — `mov al, [ecx+0x29]; ret` | `IsVisible()` |
| 16 | `+0x40` | `0x4010B0` — `mov [ecx+0xE8], arg; ret 4` | `SetScene(void*)` |
| 17 | `+0x44` | `0x4010C0` — `mov eax, [ecx+0xE8]; ret` | `GetScene()` |
| 24 | `+0x60` | `0xA60460` — `mov word [ecx+0x4E], arg; ret 4` | **`SetFrame(short)`** |
| 25 | `+0x64` | `0xA60470` — `movsx eax, word [ecx+0x4E]; ret` | `GetFrame()` |
| 37 | `+0x94` | `0xA5DCD0` base; **`0xAB6F50`** on the billboard — `[ecx+0xB24] = -(arg + π/2)` | `SetRotation(float)` |
| 44 | `+0xB0` | `0xA5D3D0` — rebuilds the transform at `+0x54` from `+0x94` and the parent at `+0xE4` | `UpdateTransform()` |
| 90 | `+0x168` | `0x84AB80` — `[ecx+0x84..0x8C] = arg[0..2]; [ecx+0x90] = 1.0f` | **`SetPosition(const float xyz[3])`** |

**Slot 24 is `ret 4`.** That makes the brief's "slot 24 is called with no argument" decidable, and
it is wrong: the compiler hoisted the push above the first call. All four arms look like this —

```
0x0057C288  mov  ecx, [esi + 0x2C]
0x0057C28D  mov  eax, [vftable + 0x60]
0x0057C290  push 2
0x0057C292  call eax                           ; status billboard: SetFrame(2)
0x0057C294  push 2                             ; <- the argument for the NEXT call
0x0057C296  mov  ecx, [esi + 0x30]
0x0057C29B  mov  eax, [vftable + 0x60]
0x0057C29E  call eax                           ; close billboard: SetFrame(2)
```

— and a `ret 4` callee with no push would unbalance the frame, so the hoisted push is the only
reading that works.

**Slot numbers prove nothing on their own.** `slotcalls.py 24` reports **222 sites in 143
functions** for `+0x60`; the identification above rests entirely on the two-instruction body in
`C3dVisibleObject`'s table, not on the displacement. Trap 12 in its usual form.

### What the per-tick refresh actually does, re-read

```
first call only
  look up 'combat_status' and 'combat_status_close' in CGraphics +0x6BCF0
  CreateInstance each (slot 18), cache in CCombat +0x2C / +0x30
  hand each to a container on CInGameIdler slot 15's object (+0xA70 and +0xBEC), slot 4
  register each in that object's +0x1DF0 array, indexed by [CCombat+0x18]->+0xD0, via 0x640CA0
  Show() both (slot 13)
every call
  position = -((attacker.units[0].pos + defender.units[0].pos) * 0.5)     ; 0x160A308 is 0.5
  SetPosition on both (slot 90), then UpdateTransform on both (slot 44)
  SetRotation(attacker.units[0].+0x104 + π/2) on both (slot 37)           ; 0x160A2A0 is π/2
  share = CCombat slot 17 (GetAttackerStrengthShare, already named), thousandths
  SetFrame on +0x2C with 0 / 1 / 2 from share vs 660 and 330, inverted when the player defends
  SetFrame on +0x30 with the same value
  caption  = FormatFixedPoint(share * 100000 / 1000)                     ; share 660 -> "66.000"
  assignString into (+0x2C)+0xB2C, and the same into (+0x30)+0xB2C
```

So the display quantity `FINDINGS-combat3.md` traced the whole modifier census to is a **string at
`billboard + 0xB2C`**, and it is the attacker's share of summed strength as a percentage with three
decimals. That is the number the UI has already computed, in the place BiceLib can read it.

### Lifetime

`CCombat`'s deleting destructor (slot 0, `0x56DEF0`) releases the attacker and defender and then
calls `0x56DF80` (rva `0x16DF80`), which is where the billboards go:

```
0x0056E02F  mov  ecx, [ebx + 0x2C]
0x0056E034  je   0x56E067                      ; null -> skip
0x0056E038  call [vftable + 0x38]              ; Hide()
0x0056E045  call [vftable + 0x44]              ; GetScene()
0x0056E04F  call [idler_vftable + 0x44]        ; CInGameIdler slot 17 -> the CEU3Graphics
0x0056E056  call 0xA6FBC0                      ; destroy it
0x0056E05E  mov  [ebx + 0x2C], 0
0x0056E067  mov  ecx, [ebx + 0x30]             ; and the same for the close billboard
```

It ends with a bare `ret` at `0x56E0AA`, and `0x56E0B0` is `CCombat::LoadKey`, which the record
already holds at rva `0x16E0B0` — so `0x16DF80` is a complete body and the `ret` really is its end
(trap 3 checked: `retsBefore` is empty from `0x56DF80`).

**So for BiceLib:** `CCombat +0x2C` is null until the first tick of a combat the player's own
country is in, non-null for the life of that combat, and freed with the combat. It must be
re-read every time and never cached across a combat ending. The `CGuiType` pointers of §3 are the
opposite — process-lifetime and safe to hold.

## 8. What else this corrects or adds to the record

- **`CInGameIdler +0x178C`** is named `session_sibling` with "what it is has not been established".
  It is the **`CEU3Graphics`**, on two independent uses (`+0x6BCF0` and `+0x6B9C0`, both members
  written by the `CGraphics` constructor). Wants renaming to `graphics`.
- **`CCombat +0x2C` / `+0x30`** — §6.
- **`CEU3DialogGuiType::LoadKey`**'s entry is right about its one key but does not say that it
  forwards every other key to `CWindowType::LoadKey` (`0xAC55E0`), which forwards to
  `CGuiType::LoadKey` (`0xAC8710`). A `.gui` `eu3dialogtype` therefore accepts 34 keys, not 1.
- **`CEU3Graphics::LoadKey`**'s entry lists its five keys; the table in §1 adds which registry each
  one fills.

## What is not established

1. **How you get from a window *type* to the live window object that holds a computed number.**
   §3 and §4 give the type and the numbers *declared* in the `.gui` file; they do not give the live
   widget. `CGui` has two containers that look like the live side — a vector at `+0x5C`/`+0x60`
   (slot 19, `0xA7DBD0`, iterates it; slot 16 and slot 23, both `0xA7DC60`, push into it) and
   something at `+0x7C` (slot 22, `0xA7DC30`) — and neither was read. *Cheapest check:* read
   `TGui`'s 32 slots on `0x15CD754` and keep the ones whose body takes a `std::string`; `0xA7CD20`
   (slot 21), `0xA7CFE0` (slot 20) and `0xA7DC80` (slot 25) are the untried ones with plausible
   shapes. Failing that, pick a window whose number BiceLib wants, find the class that owns it
   (`CEU3DialogGui`, vftable `0x15CD3C4`, is the concrete `CFixedWindow`), and find who holds the
   instance — that is a `pointsto.py` question in a running game, not a static one.
2. **`CBillboardType`'s vftable is `0x1605258` by elimination, not by reading a constructor.** The
   table was found by scanning `.rdata` for the one that holds `0xB07340` at slot 18, and the class
   has no RTTI entry. *Cheapest check:* `image.findValue(0x1605258)` to find the constructor that
   writes it, then read its `LoadKey` (slot 4 of that table) and check its cases against
   `billboardType`'s keys in `mapitems.gfx` — `scale`, `noOfFrames`, `font`, `font_size`, `offset2`,
   `textureFile`. A fit there promotes §6 to `confirmed`.
3. **The object `CInGameIdler` slot 15 returns.** `0x64D7C0` is `[this+0x1790]->[0x124]`, and
   `+0x1790` is already named `session_manager`. That object carries containers at `+0xA70` and
   `+0xBEC` and an array at `+0x1DF0` indexed by `[CCombat+0x18]->+0xD0`, and it is the thing that
   actually owns and draws the billboards. It is almost certainly the map/scene. *Cheapest check:*
   `findRefs.py --callers 0x6F07A0` and read `CFrontEnd`'s construction of the idler, which passes
   `[frontEnd+0x20C]` and `[frontEnd+0x210]` — the first is the graphics by §1, so the second names
   `+0x1790` and `+0x124` falls out of it.
4. **`CGraphics +0x6B9BC`** is loaded next to `+0x6B9C0` in `CInGameIdler::Enter` and then not used
   on that path. The pairing makes "screen width" the obvious reading and that is **inference from a
   neighbour, not a reading**. *Cheapest check:* `dispscan.py 0x6B9BC` and find a consumer that
   divides an x coordinate by it.
5. **`[CCombat+0x18]->+0xD0`**, the index into the scene's `+0x1DF0` array. `CCombat +0x18` is named
   `province` in the record; whether it is a `CProvince` or a `CMapProvince`, and what `+0xD0` is,
   were not established. *Cheapest check:* `fieldchain.py --holder` on the province pointer, or
   compare against `CMapProvince +0xD4` (`path_node`), which the record already holds — an index at
   `+0xD0` immediately before a node pointer at `+0xD4` is a shape worth testing.
6. **Which `CGuiType` subclass a `positionType` is, and where every other subclass puts its
   `position`.** §4 establishes `+0x64`/`+0x68` for the objects `CInGameIdler::Enter` reads and
   `+0xA0` for a `CWindowType`, and warns that the two collide. *Cheapest check:* the factory at
   `CGui +0xC` maps the inner keyword to the class; reading it names all thirteen subclasses in one
   go, and each one's `LoadKey` then gives its own layout.
7. **`0xA7DF60`, the `guiTypes` block reader, was not read.** That it creates through the factory
   and inserts into the tree is `inferred` from its three arguments and from the tree being
   non-empty at lookup time. *Cheapest check:* read it; it is the function that would say whether a
   duplicate name replaces or is dropped, which is a real modding question.
8. **39 of `StringHashFind`'s 206 call sites** could not be attributed to a table by `tables.py`, so
   "at least seven registries" is a floor, not a count. *Cheapest check:* widen the EAX-provenance
   walk to follow one `mov eax, [reg+disp]` back a step.
9. **Nothing was watched in a running game.** Three live checks, in order of value: (a) open a
   combat the player is in and read the `std::string` at `CCombat->+0x2C + 0xB2C` — it should hold
   the same percentage the billboard shows, which closes §6 and §7 together in one battle;
   (b) call `gui->vf[18]("unitlist_start")` from BiceLib and check `+0x64`/`+0x68` read 0 and 144;
   (c) `findInstances.py` on the vftable `0x16010D0` while two combats the player is in are
   running — two billboards per combat and none otherwise is what §6 predicts.
