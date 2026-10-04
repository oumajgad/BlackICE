# CMapPoint: 879,780 of them, 16 bytes each, and where they live

Read statically out of `hoi3_tfh.exe` on 2026-10-03. Nothing here needed the game running.
Addresses below are **rvas** against an image base of `0x400000` unless a line says VA;
`VA = rva + 0x400000`. Only valid for this build.

**In one line.** A `CMapPoint` is CPersistent's four-byte vftable, CPersistent's four-byte
dead `token` word, `float x` and `float y` — **0x10 bytes** — and every one of the 879,780
live instances is either one of two held by value in a `CProvinceTemplate` or an element of
that template's **flat `std::vector<CMapPoint>` at `+0x258`, which holds exactly one point
per building type**. 14,190 templates × (60 + 2) = **879,780**, which is `ghidra/census.json`'s
live count to the unit. It costs **13.5–13.6 MiB**, half of it vftable pointers and a word
nothing reads, it is built during database loading before any session exists, and the only
`delete` that would free it is in `CEU3Application`'s destructor.

---

## 1. What the record said, and the two things it had wrong

Trap 14, run first on both halves (`grep -n <offset> reversing/ghidra/project.json
BiceLib/GameClasses/*.hpp`):

- The whole record for the class was **one entry**, `CMapPoint::LoadKey` at `0x5D2A0`,
  `confirmed`, whose comment said its switch names **one key, `y`**. **It names two, `x` and
  `y`.** That is the first correction, and it matters because the published reading of the
  class — in `CANDIDATES.md` and in the brief that produced this file — was "each is a
  coordinate, so `x` must be implied by position in a list". It is not implied; it is a key,
  and positions.txt writes both of them.
- `CProvinceTemplate +0x3C`/`+0x40` are **already named** `text_position_x`/`text_position_y`
  and `+0x4C`/`+0x50` are **already named** `city_x`/`city_y`. This file proposes no rename
  for any of the four. What it adds is that they are not loose float pairs: each is the `x`/`y`
  of a **`CMapPoint` held by value**, at `+0x34` and `+0x44` respectively. That accounts for
  two of the 62 points per province, which is what makes the census arithmetic close.
- `CProvinceTemplate` is **already recorded as 0x27C bytes**, "allocated at `0x8A153`", and
  `CProvinceTemplate::CProvinceTemplate` is already named **in prose** in the `+0x7C` and
  `+0x28` field comments, with the EDX and ECX arguments already described. This file gives
  that name an address entry; it does not discover it.
- `g_CBuildingDataBase` (VA `0x1A870D4`) is **already recorded in full**, including that
  `+0xC`/`+0x10`/`+0x14` is its `vector<CBuilding*>`, that `CBuilding +0x54` is the building's
  `index`, and that `+0x1C` is air_base and `+0x20` naval_base. Everything below leans on
  that entry; none of it re-establishes it.
- Nothing in `BiceLib/GameClasses/*.hpp` names anything on `CProvinceTemplate` — there is no
  such header. The `0x34` and `0x268` hits in the headers are `CMapProvince`'s
  `victory_points` and `current_producing`, a different class.

## 2. The layout, from both directions

`CMapPoint::SaveContents` (`0x5D1D0`, **CMapPoint slot 2**, 197 bytes, `ret 4`) writes the
whole object and writes exactly two keys:

```
0x5D1E3   movss xmm0, [edi+8]        ; edi = ecx = this
0x5D1E9   mov   ecx, 0x1F            ; key token 0x1F = 'x'
0x5D1F4   call  SaveWriteKey
          ... float formatter 0x79625D with '%f' (VA 0x15FD134), SaveWriteValue, SaveWriteToken(0x10)
0x5D239   movss xmm0, [edi+0xc]
0x5D244   mov   ecx, 0x20            ; key token 0x20 = 'y'
```

`CMapPoint::LoadKey` (`0x5D2A0`, **slot 4**, 92 bytes, two `ret 8`) says the same thing in
reverse. Its entire discrimination is three instructions:

```
0x5D2A3   mov eax, [ebp+0xc]         ; the key token
0x5D2A6   sub eax, 0x1f              ; je -> 'x' case, which does `add ecx, 8`   (0x5D2D6)
0x5D2AC   dec eax                    ; je -> 'y' case, which does `add ecx, 0xc` (0x5D2C1)
          otherwise ReportUnknownKey (0x5D2B3)
```

Each case is `sscanf(parse+0x22C, "%f", &field)` through `0x7964D4`, with a zero return going
to `ReportParseError` (`0x5D2F2`). `ghidra/saveTokens.json`: 31 → `x`, 32 → `y`.

So:

| offset | | |
| --- | --- | --- |
| `+0x00` | `void* vftable` | VA `0x15BC65C`, six slots |
| `+0x04` | `SaveToken token` | `none` (0x18D) in every inlined constructor; see `CPersistent.hpp` on why nothing reads it |
| `+0x08` | `float x` | save key `x`, token 0x1F |
| `+0x0C` | `float y` | save key `y`, token 0x20 |
| size | **0x10** | |

The two keys are also the whole of the class's save shape: `CPersistent::Save` (slot 1,
`0x5BB10`) writes the braces, slot 2 writes the two keys, slot 3 is `CPersistent::Load`
(`0x67C050`) and slot 5 is the 1691-holder stub. The RTTI export says CMapPoint introduces
only slots 2 and 4.

**Why the size is `0x10` and not inferred from the loader.** Six places say it, in four
different shapes, and none of them is the save block:

| where | what |
| --- | --- |
| `0x90541`, `0xA9DCE`, `0xA9E4E` | `shl eax, 4` on a building index, then `add eax, [t+0x258]` |
| `0x919FC`, `0xA95B4` | `sar eax, 4` on `_Mylast - _Myfirst` to get an element count |
| `0xA9618` | `add dword [edi+0x25c], 0x10` — the inlined `push_back` |
| `0xACEBA`, `0xACF3C`, `0xA982A` | `add eax, 0x10` / `add esi, 0x10` in the fill, copy and destruct loops |

`confirmed`. What would show it wrong: a single access site with a different stride.

## 3. The two template loops, which are CMapPoint-specific

`CMapPointFillDefaultN` (`0xACE90`, 50 bytes, bare `ret`) is
`std::_Uninitialized_default_fill_n<CMapPoint>`. It plants the class's vftable inline, so it
is not a trap-4 fold, and `vtable.py --holding` puts it in no table at all:

```
f(first@EAX, count@ECX, unused@stack:4)
  eax += 8
  edx = 0x15BC65C
  loop: [eax-4] = 0x18D ; [eax-8] = edx ; [eax] = 0.0f ; [eax+4] = 0.0f ; eax += 0x10 ; --ecx
```

`CMapPointCopyConstructRange` (`0xACF10`, bare `ret`) is the matching
`std::_Uninitialized_copy<CMapPoint>`, used when the vector reallocates. It writes a **fresh**
vftable and token into the destination and copies only the two floats — which is itself a
statement that those are the only data in the object.

Each has exactly one caller: `0x91A8F` and `0xAC88F`. **Trap 2 twice over:** `0xACF10` abuts
`0xACED0`, whose bare `ret` at `0xACF0F` is followed with no padding at all, and `0xACED0` is
a copy loop over **0x14**-byte elements that has nothing to do with this class.

## 4. What holds them: a flat vector, one point per building type

`CProvinceTemplate::CProvinceTemplate` (`0xA92B0`, `ret 4`, `this` on the stack and returned in
EAX, the `CMap +0x2198` entry in ECX → `+0x28`, the province id in EDX → `+0x7C`) does three
things that matter here.

It plants the **two embedded points**:

```
0xA9302  [edi+0x38] = 0x18D        0xA9317  [edi+0x48] = 0x18D
0xA930A  [edi+0x34] = 0x15BC65C    0xA931A  [edi+0x44] = 0x15BC65C
0xA92F8  [edi+0x3C] = 0.0f         0xA930D  [edi+0x4C] = 0.0f
0xA92FD  [edi+0x40] = 0.0f         0xA9312  [edi+0x50] = 0.0f
```

— so `+0x34..+0x43` is a `CMapPoint` whose `x`/`y` are the already-named `text_position_x/_y`,
and `+0x44..+0x53` is one whose `x`/`y` are `city_x/_y`.

Then it sizes the two per-building vectors:

```
0xA9524  eax = g_CBuildingDataBase (VA 0x1A870D4)
0xA9529  esi = [eax+0x10] - [eax+0xC]      ; the vector<CBuilding*>, in bytes
0xA9535  esi >>= 2                         ; = the number of building types
0xA953C  vector<CMapPoint>::reserve(esi)   on edi+0x258
0xA9548  vector<float>::reserve(esi)       on edi+0x268
         then esi push_backs of {vftable, 0x18D, 0.0f, 0.0f} and of 0.0f
```

So the fields are:

| offset | |
| --- | --- |
| `+0x258` / `+0x25C` / `+0x260` | `std::vector<CMapPoint> building_positions` — begin / end / capacity |
| `+0x268` / `+0x26C` / `+0x270` | `std::vector<float> building_nudges` — same count, same index |

Both are indexed by `CBuilding +0x54`, the building type's `index`. `+0x270 + 4 = 0x274`,
inside the 0x27C the record already gives the class.

**It is a flat vector and the distinction is worth 20 MiB.** A `CList` of 0x10-byte nodes per
point would roughly triple an 8-byte payload; this adds **nothing** per element — three
pointers per province, inside the template, and one heap block. And because the `reserve` is
exact and the pushes exactly fill it, **the capacity has no slack**: the `push_back`'s grow arm
(`cmp eax, [edi+0x260]` at `0xA9596`/`0xA95DC`) is taken only on the last push, and
`CMap::ComputeProvinceGeometry`'s later `resize` finds the length already correct and falls
straight through its `jbe`/`jae` pair.

## 5. The count, closed

- **Provinces.** The mod's `map/definition.csv` has 14,189 data lines, ids 1..14,189, and its
  `map/positions.txt` has 14,189 province blocks. With index 0 that is **14,190** template
  slots, which is also `census.json`'s `CProvinceHistory` count exactly.
- **Building types.** The mod's `common/buildings.txt` declares **59** (identical to the
  repository's `common/buildings.txt`, and unchanged across the census date — the commit
  before 2026-09-20 declares 59 too). The loader adds one built-in: `operator new(0xE0)` at
  `0xB7647` builds a `CBuilding` named `'nobuilding'` (`0xB7510`, the string at VA
  `0x15C09A8`), caches it in the singleton at VA `0x1A8559C`, inserts it into the database's
  hash (`0xB8AF0`) and **pushes it into the `vector<CBuilding*>` at `+0xC`** through
  `0x46CC20` at `0xB7696` — the very vector whose length sizes every province's point array.
  So **N = 60**.
- **The points.** 14,190 × (60 + 2) = **879,780**. `census.json` says 879,780.

That is exact, so it is a check rather than a plausibility argument: one more or one fewer
building type would miss it by 14,190. A second, independent reading agrees — `census.json`'s
1,702,800 `CProvinceBuilding` is 14,190 × 120 = 14,190 × 2 × 60, the same multiplier.

Trap 15 does not bite here and the layout says why: a flat `vector<CMapPoint>` has a stride of
**exactly** the object size, which is what `instances()`'s discriminator asks for. If the
census is ever re-measured, the gaps inside one province's block must all be 0x10 and the gap
between blocks must be larger; anything smaller than 0x10 would mean the count is a table.

## 6. What it costs

| | bytes | MiB |
| --- | --- | --- |
| payload: 879,780 × 0x10 | 14,076,480 | **13.42** |
| — in the vectors: 14,190 × 60 × 16, as 14,190 blocks of 960 B | 13,622,400 | 12.99 |
| — embedded: 14,190 × 2 × 16, no separate allocation | 454,080 | 0.43 |
| container: 3 pointers × 14,190, inside the template — **not extra heap** | 170,280 | 0.16 |
| container, **per element** | **0** | 0 |
| allocator: 14,190 blocks × 8–16 B of heap header | 113,520 – 227,040 | 0.11 – 0.22 |
| **total** | **14,190,000 – 14,303,520** | **13.53 – 13.64** |
| of which vftable + dead token, 8 of every 16 bytes | 7,038,240 | **6.71** |
| the geometry proper | 7,038,240 | 6.71 |

The allocator line is **`inferred`** and says so: `findings/FINDINGS-allocator.md` establishes
that `operator new` → `malloc` → `HeapAlloc(_crtheap, 0, size)` with **no small-object pool**,
so the per-block cost is the NT heap's own, which is not readable out of this image. Eight
bytes of header at 8-byte granularity is the 32-bit figure; 16 is the pessimistic end. The
range is honest and the figure is small either way — the brief's "plus small-object allocator
overhead" was the wrong model: the allocation is **per vector, not per point**, so per-point
allocator overhead is zero.

The sibling `vector<float>` at `+0x268` costs another 14,190 × 240 = 3,405,600 B = **3.25 MiB**
in the same number of blocks, and in this mod's data **every byte of it is zero**: all 14,168
`building_nudge` blocks in `positions.txt` are empty (`{ }`).

**The figure to act on.** One building type costs 16 + 4 = **20 bytes per province** = 283,800
B = **0.27 MiB**, present from database load to process exit whether any province ever has
that building or not. Vanilla's 11 declared types (+`nobuilding` = 12) cost 3.25 MiB; the mod's
59 (= 60) cost 16.24 MiB. **BlackICE's 48 extra building types cost 12.99 MiB of positions
geometry over vanilla**, and the same multiplier sits in front of `CProvinceBuilding`'s 1.7
million instances.

## 7. Who writes them

`CMap::LoadMapFiles` calls two things back to back:

- `CMap::ComputeProvinceGeometry` (`0x917A0`, `ret 4`, one caller at `0x8A739`) — the
  per-province derived-geometry pass the record already quotes for `+0x2C`, `+0x30`, `+0x5C`,
  `+0x60`, `+0x64`, `+0x68` and `+0xA2`. It also `resize`s both vectors to the building-type
  count (`0x919E5`..`0x91AAB` for the points via `0xACBD0`/`0xAC830`/`0x91A8F`, then the same
  shape with `>> 2` and `0xC0700` for the floats). Both branches are **no-ops**, because the
  constructor already sized them.
- `CMap::LoadPositionsFile` (`0x8FBB0`, already recorded, ends `ret 4` at `0x90383`) — whose
  switch dispatches two sub-blocks:

| token | | handler |
| --- | --- | --- |
| `0x6CC` `building_position` | at `0x902B1` | `CMap::LoadBuildingPositions` (`0x90390`, `ret 0xc`) |
| `0x6CB` `building_nudge` | at `0x902BD` | `LoadBuildingNudges` (`0x90750`, `ret 8`) |

Both tokens come off the switch's own `sub`/`je` chain — `sub eax,0x3d6` (`text_scale`),
`sub eax,0x2f5` (cumulative `0x6CB`), `dec eax` (`0x6CC`) — and `0x6CB`/`0x6CC` are **exactly**
the two block names in the file, so the arithmetic, the token table and the data agree three
ways. **Trap 2: `0x90750` begins at the byte after `0x90390`'s `ret 0xc`** (`c2 0c 00 | 55 8b
ec`), with no padding, so a displacement scan credits the nudge loader's work to the position
loader.

`LoadBuildingPositions` per key: look the key text up in the building database (`0xB8B60`),
construct a **stack** `CMapPoint` and call its slot 3 to parse `{ x= y= }`, then

```
0x90541  shl  eax, 4                ; CBuilding::index * 0x10
0x90544  add  eax, [ecx+0x258]      ; province->building_positions
0x9054A  movss [eax+8], xmm0        ; x
0x90554  movss [eax+0xc], xmm0      ; y
0x90559  cmp  esi, [ebp-0x18]       ; the building against g_CBuildingDataBase +0x20 (naval_base)
         jne  <next key>            ; so the raster check below runs for the naval base ONLY
```

— a detail worth having: the "is this pixel inside the province" validation against
`CMap +0x20E0` is applied to the naval base's position and to no other building type.

`LoadBuildingNudges` is the same shape one float wide: `sscanf(..., "%f", &v)` then
`province->building_nudges[building->index] = v` (`0x908E8`/`0x908EB`/`0x908F6`).

The two embedded points are filled by `LoadPositionsFile` itself, at `0x8FE47` (token `0x3D2`
`text_position`) and `0x90054` (token `0x2A2` `city`), each through a **stack** `CMapPoint`
whose x/y are copied out into the template's floats — which is why those four offsets have had
names since `FINDINGS-mapbuild.md` without anyone noticing the objects they belong to.

## 8. Who reads them, and whether they are ever freed

Found by decoding forward from **every** `int3` boundary in `.text`, whatever the first byte
is, and collecting every instruction whose memory displacement is one of
`0x258`/`0x25C`/`0x260`/`0x268`/`0x26C`/`0x270`. The widened form matters: the first pass only
decoded bodies whose first byte was in `functionStart`'s prologue set, which is the hole trap 2
describes. Its positive control is that the widened scan returns all seven functions the
narrow one found, plus five more. Stack displacements were discarded (trap 12).

| reader | when | what it takes |
| --- | --- | --- |
| `CProvinceTemplate::GetNavalBasePosition` (`0xA9D70`), 8 callers | runtime | `&positions[naval_base.index]` |
| `CProvinceTemplate::GetAirBasePosition` (`0xA9DF0`), 1 caller | runtime | `&positions[air_base.index]` |
| `0xA9E70`, called from `CMap::LoadMapFiles` at `0x8AE99` | load | the naval-base position, as the measuring point for a land↔sea neighbour distance |
| `0x23F790` (at `0x23FB06`), 2 callers | display build | `positions[index]` for an **arbitrary** building, minus `label_x`/`label_y`, into a 3-float vector handed to an object factory — the building graphics |
| `0x242010` (at `0x642230`), 1 caller | display build | the same shape, plus the nudge float |
| `0x29ED40`, `0x29EF50`, `0x29F120` | editor | read **and write** both vectors by arbitrary index, comparing the building's name against the literal `'naval_base'`; the nudge float is read, a constant subtracted, and written back. No direct caller and no virtual table for any of the three, so **how they are reached is not settled** |
| `CProvinceTemplate::Save` (`0xAA300`, slot 1) | save | walks both vectors whole; holds the image's only reference to the `'building_nudge'` literal |

**Freed: only at process exit.** `CProvinceTemplate::~CProvinceTemplate` (`0xA9770`) frees the
float vector at `0xA97ED` and the point vector at `0xA9838`, calling each element's slot 0 with
the delete flag clear on the way (`0xA9820`..`0xA982F`, stride 0x10). It has one caller, the
slot-0 thunk `0xA9730` — and `image.findValue(0x4A9730)` returns **nothing**, so that thunk is
reachable only through the virtual table. The one slot-0 call on a `CProvinceTemplate` anywhere
in the image is the loop inside `CMap::~CMap`:

```
0x88BD0  eax = [esi+0x2A60]            ; the template array
0x88BD6  ecx = [eax + edi*4]
0x88BDD  edx = [ecx] ; eax = [edx]     ; slot 0
0x88BE1  push 1                        ; delete
0x88BE3  call eax
0x88BE6  cmp edi, [esi+0x2A64]         ; the count
0x88C2E  [g_CMap] = 0
0x88C39  operator delete[]([esi+0x2A60])
```

And `g_CMap` (VA `0x1A8557C`) has exactly **two** writers in the image: `InitMapLogic` at
`0x88260`, which stores the one `CMap` (`operator new(0x2A94)`), and `CMap::~CMap` itself at
`0x88C2E`, which nulls it. Scanning all 499 `.text` references to `g_CMap` for a deleting
virtual call — `push 1` within three instructions of an indirect call — returns **two**
candidates, one of which is a false positive (`0x92F27`, where slot 3 is called on the map and
slot 0 on a different object). The other is real:

```
0x22F934  edx = [ecx] ; eax = [edx]    ; ecx = g_CMap
0x22F938  push 1
0x22F93A  call eax
```

inside **`CEU3Application::~CEU3Application`** (`0x22F420`; its one caller `0x22F3F6` sits in
`0x22F3F0`, which `vtable.py --holding` places at `CEU3Application` slot 0). The positive
control for that scan is the identical shape at `0x88BE3`, which the same matcher finds.

So: **the whole 879,780-object graph is built once, during `CEU3Application::LoadDatabases`,
and freed once, when the application object is destroyed.** It is therefore not a per-session
cost at all — it is 13.5 MiB resident at the main menu, before a game exists, for the whole
life of the process. And it is not reclaimable by role, because `0x23F790` reads the array at
an arbitrary building index to place the building graphics. What *is* reclaimable in principle
is the shape: **half of the 13.42 MiB is a vftable pointer and a `token` word that
`CPersistent.hpp` already records as read by nothing**, on a struct whose entire content is two
floats.

## 9. Where `functionStart` is wrong in this neighbourhood

Four cases, all of which cost time here:

| | |
| --- | --- |
| `0x90390` / `0x90750` | `ret 0xc` then `push ebp` with no padding |
| `0xA9D40` / `0xA9D70` | `ret 4` then a fresh SEH prologue with no padding |
| `0xACED0` / `0xACF10` | bare `ret` then `push ebp` with no padding |
| `0x22F420` | **not abutment.** `functionStart(0x22F92C)` answers `0x22F6CC`, which is not an entry: the `0xCC` the walk stops at (`0x22F6CB`) is the low byte of a `call rel32` displacement, `e8 cc 68 56 00`, and the next byte happens to be `0x68`, in the prologue set. `retsBefore` does **not** catch it — it returns an empty list, because x86 resynchronised and the decode looked clean. Requiring a run of ≥ 3 `int3` on the backward walk gets it right |

## 10. What is not established

- **How the three editor bodies at `0x29ED40`/`0x29EF50`/`0x29F120` are reached.** None has a
  direct caller and none is in a virtual table. Their shape — a key code switch, a building
  selected through `+0xA84`, the nudge float nudged by a constant and written back, the
  `'naval_base'` name compared — says in-game position editor, but that is a reading of what
  the code is for, not an instruction, and it is marked `inferred` accordingly.
- **What the `building_nudge` float means.** Nothing in the mod's data sets one, so there is no
  oracle. A rotation is the obvious guess and is not evidence.
- **`CProvinceTemplate::Save`'s body**, beyond the two vector walks and the string reference.
  Its `ret 4` at `0xAB2D1` has a bare `ret` at `0xAB308` after it, which is trap 3 territory
  and was not resolved.
- **The NT heap's per-block overhead** on this process, which is why the cost is a range.
- **Whether `CProvinceTemplate::Save` is ever called in a shipped game.** positions.txt is a
  map file, not a savegame block, so the writer is presumably the editor's; that was not
  checked and nothing here depends on it.

---

## Transcription note

Read and written by wave 11's agent C; transcribed by the session that collected the wave,
because an agent's `Write` is refused for this path. Spot-checked independently before
transcription, all confirming:

- **The two keys**, which correct both the record and the brief: `CMapPoint::LoadKey` at VA
  `0x45D2A0` does `mov eax, [ebp+0xc]; sub eax, 0x1f; je` then `dec eax; je`, and
  `saveTokens.json` gives `0x1F` → `x`, `0x20` → `y`. The record's comment said one key, `y`,
  and the brief built a hypothesis on it — "whether the single `y` key means `x` is implied by
  position in a list". It is not implied.
- **The arithmetic, which closes to the unit.** `census.json`: `CMapPoint` 879,780,
  `CProvinceBuilding` 1,702,800, `CProvinceHistory` 14,190. The mod's `common/buildings.txt`
  declares 59 blocks; `map/definition.csv` has 14,189 data lines. So 14,190 × (60 + 2) =
  879,780 and 14,190 × 2 × 60 = 1,702,800, both exact — **two independent census figures
  landing on the same multiplier**, which is much stronger than either alone.
- **The actionable figure**: 20 bytes per building type per province × 14,190 = 283,800 B =
  0.27 MiB each, so 48 extra types = **12.99 MiB**.
