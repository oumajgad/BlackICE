# The map build, its cache, and how the frontend is reached

Read out of `hoi3_tfh.exe` on 2026-10-02, statically **and against the running game** (base
`0x830000` that launch; the mod is `tfh/mod/BlackICE GitHub`, 1936-01-01, paused). Addresses
below are **virtual** (base `0x400000`) with the rva beside them; `VA = RVA + 0x400000`. Only
valid for this build.

**In one line.** The map cache is governed by **one byte**, `CMap +0x28`, set once from **one
number**, `CMap +0x2C`, which is the **sum of a Fletcher-style checksum over exactly seven map
files** — and `climate.bmp` and `rivers.bmp` are not among the seven, so changing them leaves
every derived cache stale and the engine says nothing. `ProvinceEdge +0x10` arrives verbatim out
of **`map/cache/adjacencies.bin`**, not `map.bin`, and its sign convention is now settled
numerically against 83 558 live edges. `CProvinceTemplate +0x64/+0x68` is **`positions.txt`'s
`unit` position**, falling back to the bounding-box centre — 14 189 of 14 189. And `CFrontEnd`
slot 3 is reached from the run loop's pending-screen swap at `0xA913A0`.

---

## 1. What is new here, and what was already in the record

Trap 14, run first, on both halves (`grep -n <offset> reversing/ghidra/project.json
BiceLib/GameClasses/*.hpp`):

- **`CProvinceTemplate +0x64`/`+0x68` are already named** `position_x`/`position_y` in
  `project.json`, with the write sites `0x8FEBB`/`0x8FEC4` and `0x9009D`/`0x900A0` already
  recorded and with `IsNight` and `LoadProvinceClimate` already named as the readers. What was
  open was *which* pixel. That is what this file closes; it proposes no rename.
- **`ProvinceEdge +0x10` is already named** `bearing`, `likely`, with `CWeatherFront::Tick` as
  the only reader. What was open was the writer and the convention.
- **`g_CMap` at rva `0x168557C` was already in both halves** — `project.json` and
  `BiceLib/GameClasses/CMap.hpp`'s `GLOBAL_POINTER`. My live reading (it equals the one live
  `CMap` instance's address exactly) is *corroboration*, not first settlement, and I say so
  because the distinction is the whole of trap 14's second half.
- **`CMap::CMap` (`0x4883A0`, rva `0x883A0`) is already recorded in full**, including the twelve
  file-name strings and the six resolved-path globals. I add nothing to it.
- `0x8DFA0` and `0x8E2E0` are already named `ReadMapCache`/`WriteMapCache`. **Their recorded
  comments name the wrong file** — see §11.

## 2. The frame: four functions and one flag

The whole of what `time.log` attributes to `map.cpp` lines 288–636 happens under one function.

| function | VA | rva | extent | exit | convention |
| --- | --- | --- | --- | --- | --- |
| `CMap::CMap` | `0x4883A0` | `0x883A0` | `0x4883A0..0x4889AB` | — | already recorded |
| `CMap::LoadMapFiles` (`InitMapLogic`'s whole body) | `0x489BA0` | `0x89BA0` | `0x489BA0..0x48B7CB` | `ret` | `__thiscall`, `this` in ecx |
| `CMap::ComputeCacheStamp` | `0x492100` | `0x92100` | `0x492100..0x4921D7` | bare `ret` | `__thiscall`, returns the stamp in eax |
| `CMap::IsCacheStale` | `0x4921E0` | `0x921E0` | `0x4921E0..0x4922C6` | `ret 4` | one stack arg, the `CMap`; returns bool in al |
| `CMap::WriteCacheStamp` | `0x4922D0` | `0x922D0` | `0x4922D0..0x492387` | `ret 4` | one stack arg, the `CMap` |

Every boundary is a clean `int3` run (`0x4889AB` ×5, `0x48B7CB` ×5, `0x4921D7` ×9, `0x4922C6`
×10, `0x492387` ×9), so none is an abutting-function artefact, and `retsBefore(0x489BA0,
0x48B7CA)` over `LoadMapFiles` decodes 1 846 instructions without desynchronising.

The flag is set in the first thirty instructions of `LoadMapFiles`:

```
0x00489C33   mov ecx, ebx                  ; the CMap
0x00489C35   call 0x492100                 ; ComputeCacheStamp -> eax
0x00489C3A   push ebx
0x00489C3B   mov dword [ebx + 0x2c], eax   ; CMap +0x2C  = the stamp
0x00489C3E   call 0x4921e0                 ; IsCacheStale(this)
0x00489C49   mov byte [ebx + 0x28], al     ; CMap +0x28  = cache_stale
0x00489CFF   push 7; push 'map.cpp'; push 0x120 (=288)   ; 'generate colorspace'
```

`CMap +0x28` is then the **only** gate on every map cache. Its readers, all found by scanning
`0x480000..0x4A5000` for a byte-sized use of `+0x28` inside a function that also touches a
`CMap`-distinctive displacement (`+0x2200`, `+0x2A60`, `+0x2A74`, `+0x21FC`):

| reader | what it guards |
| --- | --- |
| `0x48A6A0` in `LoadMapFiles` | the adjacency graph: `adjacencies.bin` or rebuild |
| `0x48A777` in `LoadMapFiles` | the `CALC_PATHS` block — `map.cpp:597` *calculate paths* and `:605` *fix naval distances* |
| `0x48AE73` in `LoadMapFiles` | whether to **write** `adjacencies.bin` back |
| `0x48B808` | `map/cache/provincecache.bin` |
| `0x48BE3C` | `map/cache/climate.bin` |
| `0x48DA46` | `map/cache/navaldist.bin` |
| `0x490E76` | not read |

`confirmed`. **The dynamic corroboration is in the mod's own `time.log` from the running
session**: `[map.cpp:597]: It takes <0> seconds to calculate paths.` — zero, because the block
is skipped; and `CMap +0x28` reads `0` live. Two independent statements that the cache was
valid this launch.

## 3. The invalidation rule, closed end to end

**`CMap +0x2C` is a checksum sum, not a time.** `ComputeCacheStamp` (`0x492100`) builds a
`std::vector<std::string>` of file paths, checksums each, and returns the **plain 32-bit sum**:

```
0x00492129   call 0x492390                 ; collect the paths (this arrives in ESI, see below)
0x00492137   ecx = end - begin ; / 0x1C    ; magic 0x92492493 -> std::string is 0x1C bytes
0x00492154   lea ecx, [ebx + esi]          ; &path[i]
0x00492157   call 0xAB3D00                 ; ChecksumFile(path)
0x0049215C   add dword [ebp - 0x10], eax   ; accumulate
0x004921C6   mov eax, dword [ebp - 0x10]   ; return the sum
```

`0x492390` (rva `0x92390`) is the collector, and it takes the `CMap` **in ESI** — it never
writes esi and relies on `0x492100` having left it there. That is trap 11 territory: it is not a
`__thiscall`, it is `__fastcall` with `map@ESI` and the out-vector on the stack. It pushes seven
paths, in this order:

| # | source | what it is |
| --- | --- | --- |
| 1 | global `0x170C750` (rva `0x130C750`) | `map/default.map` |
| 2 | `CMap +0x2070` | `positions_file` → `map/positions.txt` |
| 3 | `CMap +0x2128` | `terrain_definition_file` → `map/terrain.txt` |
| 4 | `CMap +0x208C` | `provinces_file` → `map/provinces.bmp` |
| 5 | `CMap +0x20A8` | `terrain_file` → `map/terrain.bmp` |
| 6 | `CMap +0x210C` | **`map/definition.csv`** — the string `project.json` calls `unknown_210c` |
| 7 | `CMap +0x2054` | `adjacencies_file` → `map/adjacencies.csv` |

The right-hand column is **read out of the running game**, which is also what settles `+0x210C`:
`project.json` guessed `definitions` and the guess is right.

`ChecksumFile` (`0xAB3D00`, rva `0x6B3D00`) is `__thiscall` on the `std::string`: empty path or
`FileExists` (`0xB84A20`, rva `0x784A20`, a boolean wrapper over `0xB84660`) false → return 0;
otherwise open the path for reading and call `CBinaryStream::Checksum(-1)` (`0xA6D300`, rva
`0x66D300`), which is a Fletcher-32 with modulus `0xFFFF` and a subtract-once reduction, read in
256 KiB chunks:

```
a = 0; b = 0
for each byte v:
    a += v ; if (a > 0xFFFF) a -= 0xFFFF
    b += a ; if (b > 0xFFFF) b -= 0xFFFF
return (a << 16) | b
```

**The whole thing reproduces exactly.** Recomputing those seven checksums over the mod's own
`map/` folder in Python gives:

```
default.map      0x362B2773      positions.txt    0x61C19F47
terrain.txt      0x3E60C54C      provinces.bmp    0xADEAFEDE
terrain.bmp      0x95384207      definition.csv   0x7E1D931F
adjacencies.csv  0xEDDE4C5F
                 ----------
sum              0x856CAC69
```

and `CMap +0x2C` read out of the running process is **`0x856CAC69`**, and
`…\Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\map\cache\time` contains
**`0x856CAC69`** as its four bytes. Three agreeing readings — the instructions, the files on
disk, and the live field. `confirmed`.

*The positive control for the file list.* The same program run against the **base** `tfh/map/`
folder gives `0x93E125C4`, and `tfh/map/cache/time` on disk contains `0x93E125C4`. A different
seven files, a different sum, and the stamp file that belongs to them agrees too. If the file
list were wrong, one of the two could agree by luck; both could not.

`IsCacheStale` (`0x4921E0`) then decides, and the polarity is **true means rebuild**:

```
if (path of cache/time is empty)        return 1
if (!FileExists(cache/time))            return 1
open cache/time for reading
if (the stream failed)                  return 0        <-- see below
read 4 bytes
return (those 4 bytes != map->+0x2C)                    ; setne
```

The third line is the odd one: an open failure answers *not stale*. It is unreachable in
practice, because `FileExists` has already passed on the line above, so I record it as written
rather than as a hazard. `confirmed` for the code; `inferred` that it is dead.

`WriteCacheStamp` (`0x4922D0`) is the counterpart: open `cache/time` with the write flag and
write the four bytes of `map->+0x2C`. It has **exactly one caller, `0x85531B` (rva `0x45531B`)**,
which is outside the map module — in the graphics side. That is consistent with the file dates
in the user cache folder: `map.bin` at 10:09 and `time` at 15:24, i.e. the stamp is committed
late, after the frontend's own caches, not when the map logic finishes.

### Where the files actually are, which is the part a modder needs

The engine's strings are bare relative paths — read live, `CMap +0x208C` is literally
`map/provinces.bmp` and the stamp-file global is literally `map/cache/time`. They resolve through
the engine's file layer, and the layer sends the two directions to **different places**:

- **reads of content** land in the mod: `…\Hearts of Iron 3\tfh\mod\BlackICE GitHub\map\…`
  (proved by the stamp matching that folder's seven files and no other's);
- **the cache** lands in the writable per-mod user directory:
  `…\Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\map\cache\`.

So there is one cache per mod, beside the saves, and deleting it is how a modder forces a rebuild.
`confirmed` — the stamp file in that folder holds the mod's sum, and the base game's holds the
base game's.

### The six files that do **not** invalidate anything

`default.map` names twelve files. Seven are in the stamp (counting `default.map` itself). These
are not:

`climate.bmp` (`+0x20EC`), `rivers.bmp` (`+0x20C4`), `continent.txt` (`+0x2144`),
`region.txt` (`+0x2160`), `coastlines.txt` (`+0x217C`), `trees.txt` (`+0x219C`).

**`climate.bmp` is the one that bites**, because `map/cache/climate.bin` is derived from it and is
gated on the same single flag. Edit `climate.bmp` alone and every province keeps the temperature
the old image gave it, for as long as the cache survives — with no log line, because nothing
checks. `FINDINGS-temperature.md` makes `climate.bmp` "the whole geography of temperature"; this
is the mechanism by which an edit to it can do nothing at all. `confirmed` for the file list and
the shared gate; `inferred` that this is a bug rather than a decision.

## 4. `map/cache/climate.bin` — the format, and what it proves

56 760 bytes = 14 190 × 4. It is `int32 climateIndex[province_count]`, indexed by **province id**
from 0, holding the **palette index** sampled out of `climate.bmp` — not the temperature.
`climate.bin[0] = 158` is the null province; `[1..5] = 146`, `[6] = 111`.

The check that matters: sampling the mod's `climate.bmp` at each province's `(+0x64, +0x68)`
with the pixel formula of §7 reproduces **all 14 189 entries, exactly**. Two controls, both run:
sampling the unflipped row gives 878 of 14 189, and sampling at `(+0x2C, +0x30)` — the
bounding-box centre — gives 14 023, i.e. close but wrong on 166 provinces. So the formula is
right, the field is right, and the two coordinate pairs really are different fields.
`confirmed`.

This also explains an apparent contradiction worth recording so nobody re-derives it: live
`base_temperature` is **not** `(index − 100) × 150` for every province — only 8 865 of 14 189.
The residual is a constant per province, −20 000 for the arctic ones, which is
`terrain.txt`'s own `temperature`, exactly as `FINDINGS-temperature.md` §2 states. The formula
there is right; a reader comparing it against live memory needs the terrain term.

## 5. `map/cache/adjacencies.bin` — the exact format, and `ProvinceEdge +0x10`'s proximate writer

**The recorded answer names the wrong file.** `0x48DFA0`'s path string is `cache/adjacencies.bin`
(`.rdata` `0x15BE2C8`, referenced at `0x48DFD1`), and `0x48E2E0`'s is the same string at
`0x48E30B`. `/cache/map.bin` (`0x15BDF8C`) is referenced only at `0x486FE7` and `0x48708A`,
inside `0x486F10` — a different class, whose sole caller is `0x850AB0` (rva `0x450AB0`) in the
graphics module. So the province graph has nothing to do with `map.bin`. `confirmed` by the
string references and by the size arithmetic below.

`CMap::ReadAdjacencyCache` (`0x48DFA0`, rva `0x8DFA0`, `bool __stdcall(CMap*)`, `ret 4`):

```
path = MapPath("cache/adjacencies.bin")            ; 0x489060
open it for reading                                 ; 0xA6C1B0, flag 0
for id = 0 .. map->+0x2A64 - 1:                     ; 0x48E0B3, the template count (14190)
    t = map->+0x2A60[id]                            ; 0x48E0C5, the CProvinceTemplate*
    read int n                                      ; 0x48E0D7, read(&n, 4)
    repeat n times:
        read 20 bytes into a stack record           ; 0x48E107, read(&rec, 0x14)
        for each existing edge e in t->+0x90..+0x94 (stride 0x14):
            if (e.to_province == rec.to_province) goto next   ; 0x48E15A / je 0x48E171
        push_back(rec) onto t->+0x90                ; 0x48E16C, call 0x4ACCA0
return true                                         ; 0x48E1FC; the two catch arms log
                                                    ; 'File exception:' at map.cpp:1037 and return false
```

`CMap::WriteAdjacencyCache` (`0x48E2E0`, rva `0x8E2E0`) is the mirror, with **no header at all**:
open with the write flag (`0x48E3A3`), then for each id write the 4-byte count
`(end-begin)/0x14` (`0x48E423`) and then each edge as raw `0x14` bytes (`0x48E461`, `push 0x14`).

**So `ProvinceEdge +0x10`'s proximate writer is `memcpy` out of the file**, and here is the whole
path from bytes to field: byte offset 0 of the file is province 0's count; after each count come
`count × 20` bytes; those twenty bytes are copied into a stack record at `[ebp-0x58]`, lifted
into `[ebp-0x3c]` as five dwords (`0x48E10C`–`0x48E127`) and `push_back`ed unchanged, so
`file[k+16..k+19]` *is* `ProvinceEdge +0x10`.

Three independent confirmations, and the first two are arithmetic identities:

1. **Size.** Live, the 14 189 templates hold **83 558** edges in total. `14190 × 4 + 83558 × 20
   = 1 727 920`, and `…\BlackICE GitHub\map\cache\adjacencies.bin` is **1 727 920 bytes**. Exact.
2. **Bytes.** The first 120 bytes of the file decode as `0`, then `3`, then
   `{0,7,0,14300,781} {0,6,0,15400,850} {0,13197,0,13000,104}`, then `3`, then
   `{0,8,0,12000,605} {0,13,0,14000,766} …` — and province 1's edge vector read out of live
   memory is `[0,7,0,14300,781] [0,6,0,15400,850] [0,13197,0,13000,104]`, province 2's is
   `[0,8,0,12000,605] [0,13,0,14000,766] …`. Byte for byte.
3. **Count.** Walking the mod's `provinces.bmp` for 4-adjacent pairs of different provinces finds
   83 120 ordered pairs, against 83 558 edges in memory — the surplus being `adjacencies.csv`'s
   explicit ones.

`confirmed`, and **the merge semantics are the part worth keeping**: the cache only **adds**
edges whose `to_province` is not already present. It never overwrites one. So if any pass has
already created an edge for that neighbour, the cache's distance and bearing for it are
discarded. In practice `ReadAdjacencyCache` runs before anything else creates edges, so this
does not fire — but it is the reason a half-stale cache degrades silently rather than loudly.

### Every place an edge can be created — there are four, and that is all

`0x4ACCA0` (rva `0xACCA0`) is `std::vector<ProvinceEdge>::push_back`, and `findRefs --callers`
gives it **exactly four** call sites:

| site | record pushed |
| --- | --- |
| `0x48E16C`, `ReadAdjacencyCache` | twenty bytes verbatim from the file |
| `0x4913D9` and `0x491442`, inside `0x4911B0` | `{0, other, 0, 0, 0}` — the stack record at `[ebp-0x54]`, with `+0x4C/+0x48/+0x44` all zeroed |
| `0x4A9CD5`, inside `CProvinceTemplate::AddEdge` (`0x4A9C90`) | whatever the caller built; `adjacencies.csv`'s loader `0x48E520` is how it is reached |

`0x4911B0` (rva `0x911B0`) is the raster builder — the function `LoadMapFiles` calls at
`0x48A6B6` when the cache cannot be used. **`FINDINGS-temperature.md` attributes that
`{0, to, 0, 0, 0}` record to `0x917A0`; it is `0x4911B0`.** `0x917A0` is the geometry pass that
follows, and it writes `+0x2C`, `+0x30`, `+0x5C`, `+0x60` on the template, not edges.

So nothing creates an edge with a non-zero bearing. **The bearing must be filled in place, by a
pass that walks an existing vector, and I did not find that pass.** §6 says what it computes;
§12 says what I ruled out.

## 6. `ProvinceEdge +0x10`'s convention, settled from the live game

With 83 558 live edges and every province's coordinates, the convention is decidable without the
code. It is:

```
dx = wrapByMapWidth(other.position_x - this.position_x)     ; CProvinceTemplate +0x64
dy =               (other.position_y - this.position_y)     ; CProvinceTemplate +0x68
bearing = floor( 1000 * (atan2(dy, -dx) mod 2pi) / 2pi + 0.5 )
```

Note the `-dx`: the angle is mirrored in x relative to the ordinary `atan2(dy, dx)`. In cardinal
terms, with y growing north:

| direction | bearing |
| --- | --- |
| west | `0` **or `1000`** |
| north | `250` |
| east | `500` |
| south | `750` |

**The maximum bearing in live memory is `1000`, not `999`** — the rounding is not wrapped, so a
near-due-west edge stores `1000`. 768 edges do. Anything comparing bearings modulo 1000 has to
allow for it, and `IsAngleWithinArc` (`0xB4490`) is where that would matter.

The fit, by pair kind:

| pair | edges | formula exact |
| --- | --- | --- |
| land–land | 56 810 | **56 211 (98.95 %)** |
| sea–sea | 19 124 | **18 840 (98.51 %)** |
| land–sea | 7 624 | 539 (7.07 %) |

`likely` for the formula on same-kind edges — two populations of tens of thousands at 99 % is not
a coincidence, but 1 % is unexplained and no instruction was read. **`+0x64/+0x68` is the input,
not `+0x2C/+0x30`**: the same fit run on the bounding-box centres gives 64.2 % and on
`+0x5C/+0x60` the identical 64.2 %, and run on the *floating-point* positions out of
`positions.txt` it gets *worse* (73.3 %), so the engine uses the truncated integer pair. That
discrimination is the useful part: it says the bearing is computed **after** `positions.txt` is
parsed, which puts it in the `CALC_PATHS` block (`0x48A777` onward, `map.cpp:597`) and not in the
graph builder.

**Land–sea edges are computed some other way and I did not find it.** The negative is controlled:
the same method sees the same-kind answer at 99 %, so its silence here is about the data, not the
method. Three hypotheses were tested against the raster and all three failed — the land
province's position to the mean of the shared border on the sea side (1.1 %), to the mean on its
own side (1.6 %), and from its own border mean to the sea province's position (1.1 %), against a
7.1 % control of position-to-position. A sea zone is hundreds of pixels across, so a
centre-to-centre bearing would be meaningless and the engine is evidently doing something local;
what, is open.

**`ProvinceEdge +0xC` (distance) is not geometric and I did not settle it.** For Paris's six
edges the ratio of stored distance to centre-to-centre pixel distance runs 950, 1035, 1118, 1299,
1342, 1532 — no constant. Every value seen is a multiple of 50. `CALC_PATHS` and
`map.cpp:605 fix naval distances` are where to look.

## 7. Which pixel `CProvinceTemplate +0x64/+0x68` is — closed

Both write sites are inside **one** function, `0x48FBB0` (rva `0x8FBB0`,
`0x48FBB0..0x490386`), which is the **`positions.txt` loader**: it builds a `Tokenizer` over
`CMap +0x2070` at `0x48FC64` and switches on the save token in `[esi+0x20]`. Three of its keys
touch the template:

| token | key | what it writes |
| --- | --- | --- |
| `0x256` | `unit` | an **int** pair via `0x4909C0`, then `+0x68 = y` (`0x49009D`), `+0x64 = x` (`0x4900A0`) — **unconditionally** |
| `0x3D2` | `text_position` | a **float** pair to `+0x3C`/`+0x40`, and then `+0x68`/`+0x64` as truncated ints (`0x48FEBB`/`0x48FEC4`) **only when `is_land` (+0x22) is clear** |
| `0x2A2` | `city` | a float pair to `+0x4C`/`+0x50` |

The land/sea gate is one instruction:

```
0x0048FEA5   cmp byte [ebx + 0x22], 0      ; is_land
0x0048FEA9   mov eax, [ebp + 8]
0x0048FEAC   mov eax, [eax + 0x2a60]       ; the template array
0x0048FEB2   mov ecx, [eax + ecx*4]        ; whoever owns the pixel at (x, y)
0x0048FEB5   jne 0x48fda0                  ; land -> back to the token loop, write nothing
0x0048FEBB   mov [ebx + 0x68], edx         ; sea -> position_y
0x0048FEC4   mov [ebx + 0x64], esi         ;        position_x
0x0048FED8   mov [ebx + 0xa2], al          ; northern_hemisphere = (+0x68 >= height/2)
0x0048FEDE   cmp ecx, ebx                  ; does that pixel belong to this province?
0x0048FF5C   push 'Unit position outside province for seazone #'   ; map.cpp:1309, channel 0x10004
```

and the land path has the same check with `'Unit position outside province for #'`.

**The complete rule, and it fits 14 189 of 14 189 provinces in the live game:**

1. the default is the bounding-box centre, i.e. the same values as `+0x2C`/`+0x30`;
2. `positions.txt`'s `unit = { x y }` overwrites it, truncated to int, on **any** province;
3. `positions.txt`'s `text_position = { x y }` overwrites it, truncated to int, on a **sea zone
   only**;
4. **last one in file order wins.**

Rule 4 is not decoration: 61 sea zones declare both, with `unit` first, and on all 61 the live
field is `text_position`'s value. Modelling rules 1–3 with `unit` given priority fits 14 128;
applying them in file order fits **14 189 of 14 189**. `confirmed`.

Of the 14 189: `unit` decides 2 756, `text_position` decides 88, and the bounding-box centre
stands for **11 345**. So for four provinces in five, `+0x64/+0x68` is the bbox centre and
`FINDINGS-temperature.md`'s "one pixel decides a province" is the centre pixel; for the other
2 844 it is a hand-placed point out of `positions.txt`.

`+0x4C/+0x50` behaves the same way with `city`: Paris declares no `city` and reads
`(2786.0, 1658.0)`, its bbox centre as floats. `+0x3C/+0x40` holds `text_position` verbatim —
Paris reads `2786.300048828125, 1657.5` against the file's `x=2786.300049 y=1657.500000`.

### The pixel formula

`CProvinceTemplate` coordinates index the map bitmaps like this:

```
provinces.bmp, 24bpp, 5616 x 2160:
    offset = 54 + ((2159 - y) * 5616 + x) * 3      ; bytes are B, G, R
climate.bmp, 8bpp paletted, 5616 x 2160:
    offset = 1078 + (2159 - y) * 5616 + x          ; the byte is the palette index
```

i.e. **engine y counts rows from the end of the file's pixel array**, which is the same as the
row index in a top-down (display-order) buffer. The engine's y grows **north**, which
`FINDINGS-temperature.md` §4 established from `positions.txt`, and the first scanline stored in
the file is the northernmost.

Two independent confirmations of the formula, both exhaustive:

- **Bounding boxes.** Enumerating every province's pixels under this formula and comparing
  against `+0x80`/`+0x84`/`+0x88`/`+0x8C` agrees for **all 14 189** provinces. That also
  independently confirms those four fields as the pixel bounding box.
- **Latitudes.** Murmansk is at engine y 2060–2071, Reykjavik 2004–2049, Paris 1652–1663, Cape
  Town 229–255, Hobart 129–160, Ushuaia 58–90. North is high y, `+0xA2` is 1 on the first three
  and 0 on the last three, and `+0xA2` is therefore the **northern** hemisphere, which is what
  `FINDINGS-temperature.md` argued and what `project.json` still calls `southern_hemisphere`.

One consequence worth stating because it is counter-intuitive and I checked it: PIL's row 0 of
`provinces.bmp` is engine y 0, which is the far south. A positive `biHeight` means the file is
stored bottom-up, so **the image, opened in a viewer, is vertically mirrored relative to
geography**. The formula above is what matters; this is the sentence that saves the next person
an hour.

### 51 provinces sample a neighbour's pixel

Under the formula, `(+0x64, +0x68)` lies inside its own province for 14 132 of 14 189. Of the
other 57, **51 land on a pixel that belongs to a different province** and **6 land on a pixel
whose colour is in no `definition.csv` row** (the mod's `provinces.bmp` has 14 217 such pixels).
Every one of the 57 is a province taking the bounding-box centre default — so the engine's own
check never runs on them, because it only fires inside the `positions.txt` handler, and
`error.log` from the live session is empty. Those 51 provinces take their climate, and their
`IsNight` longitude, from a neighbour. Concave shapes are the cause.

**The control for that claim is the engine's own raster** — see §8. It returns the same answers,
including `0` for the same six.

## 8. `CMap +0x20E0` is the province-id raster

`project.json` records `+0x20E0`/`+0x20E4`/`+0x20E8` as "three dwords the constructor zeroes,
unidentified". `+0x20E0` is a pointer to an image object, and the `positions.txt` loader uses it
to answer "which province owns this pixel":

```
0x004900BC   ecx = [map + 0x20E0]
0x004900C2   eax = [ecx + 0x18]            ; stride
0x004900CB   imul eax, y
0x004900CE   edi = [ecx + 0x0C]            ; bytes per pixel
0x004900D1   imul edi, x
0x004900D6   eax += [ecx + 0x20]           ; pixel base
0x004900D9   ecx = p[1] << 8 | p[0]        ; a 16-bit province id
0x004900E5   cmp [templates + ecx*4], ebx  ; is that us?
```

Read live, the object is: `+0x04` width **5616**, `+0x08` height **2160**, `+0x0C` bytes per
pixel **2**, `+0x10` bits per pixel **16**, `+0x18`/`+0x1C` stride **11232** (= 5616 × 2),
`+0x20` the pixel data. Looking 2 000 provinces up in it at their own `(+0x64, +0x68)` returns
the province itself 1 984 times, and **the 16 misses are the same 16, with the same wrong ids**,
that the `provinces.bmp` reading gives — `76 → 0`, `119 → 101`, `127 → 10501`, `165 → 0`,
`230 → 216`. So the engine's raster and my bitmap reading are the same function, and the
"unmatched colour" cases are the engine's too. `confirmed`, **live**.

Size note, `inferred`: `map/cache/provincecache.bin` is 24 261 174 bytes and
`5616 × 2160 × 2 = 24 261 120`, a difference of 54. That is the right size for this raster plus a
small header. `map/cache/map.bin` is 12 144 209 against `5616 × 2160 = 12 130 560`, which fits an
8-bit raster plus 13 649 bytes, and I did not establish what it holds.

## 9. How `CFrontEnd` slot 3 is reached — `FINDINGS-startup.md`'s open item, closed

`main.cpp:601` calls `0xA90F90` (rva `0x690F90`), which is `CEU3Application::Run` and takes the
application **in EDI** (another register-receiver: it reads `[edi+0xd8]` in its second
instruction without ever setting edi). It sets the process affinity to a single CPU, calls
vftable slot 7 — which for `CEU3Application` is `0xABF890`, the 1691-slot shared empty stub, so
nothing — and then runs its loop from `0xA910A1` to `0xA9142D`, exiting when
`app->+0xF8 == 0x12`.

Three fields do the work. `app +0x84` is the **current** screen, `app +0xE0` the **pending** one
and `app +0x88` the "a screen is pending" byte. `CEU3Application::SetNextScreen` (`0xA90F40`, rva
`0x690F40`, `this` in **ESI**, `ret 4`) installs the pending one:

```
0x00A90F47   mov byte [esi + 0x88], 1
0x00A90F6E   mov dword [esi + 0xe0], edi       ; the new screen
```

and it has two callers — **`0x6329F8`, inside `LoadEverything` at stage 17** (right after
`CFrontEnd::CFrontEnd` at `0x6ED660`, the `'Idler Initialised <'` line), and `0x6F1231`.

The swap, at the bottom of the loop, is guarded by the pending byte:

```
0x00A913A0   cmp byte [edi + 0x88], 0
0x00A913A7   je 0xa91426                       ; nothing pending -> round again
0x00A913AD   old = [edi + 0x84]; if (old) old->slot 4()          ; vftable +0x10
0x00A913BE   next = [edi + 0xe0]; [edi + 0xe0] = 0
0x00A913CE   if (old && old != next) old->slot 0(1)              ; destroy the old screen
0x00A913E4   [edi + 0x84] = next
0x00A913FD   [edi + 0x88] = 0
0x00A91404   next->slot 2([edi + 0xe4], [edi + 0xe8])            ; vftable +8
0x00A9140C   next->slot 3()                                      ; vftable +0xC   <-- here
0x00A91419   next->slot 5()                                      ; vftable +0x14
0x00A91426   cmp dword [edi + 0xf8], 0x12
0x00A9142D   jne 0xa910a1
```

So the chain is complete: **`LoadEverything` builds the `CFrontEnd` and hands it to
`SetNextScreen`; `main.cpp:601` enters the run loop; on its first pass the loop sees the pending
byte, installs the `CFrontEnd` as the current screen, and calls its slot 3 at `0xA9140C`** —
which is `0x6EEF00`, the function that logs `'entering frontend...'` at `frontend.cpp:423` and
goes on to call `InitialiseGraphicalMap` at `0x6EF51A`. `confirmed`, by instruction.

And it answers the question behind the question: **slot 3 is a one-shot activation hook**, not
per-frame work, because the whole block including slots 2, 3 and 5 is inside
`if (pending)`. The per-frame call on the current screen is slot 1, at `0xA9138D`. That is also
why the lobby and the tutorial are reached the same way — they are different screen objects
pushed through `SetNextScreen` — which fits the sibling finding that the savegame loader is
reachable only from those two screens.

## 10. The path registry, and one of `FINDINGS-startup.md`'s open items

`0x1A85558` (rva `0x1685558`) holds a **pointer** to a path registry; the code is
`mov eax, [0x1A85558]; add eax, <N>`, so `[0x1685558 + N]` in the record means
`*[0x1685558] + N`. Read live, the registry holds bare folder names as `std::string` at stride
`0x1C` from `+0x80`:

```
+0x080 common       +0x09C events        +0x0B8 gfx          +0x0D4 history
+0x0F0 interface    +0x10C localisation  +0x128 map          +0x144 sound
+0x160 decisions    +0x17C missions      +0x198 units        +0x1B4 technologies
+0x1D0 script       +0x1EC cgm           +0x208 battleplans
```

A second block of fifteen runs on the same lattice from `+0x224` (= `+0x80 + 15 × 0x1C`), and
**every one of the fifteen is empty in this session**, with the count at `+0x70` reading 0. That
is the override/second-search-directory block.

Two of `FINDINGS-startup.md`'s four unidentified fields fall out of the lattice, and both fit
what the code does with them: `+0x358` is index 11 of the second block, i.e. the override for
`technologies` at `+0x1B4` — and technology phase 2 reads exactly that pair. `+0x2CC` is index 6,
the override for `map` at `+0x128` — and `0x489060` (rva `0x89060`), the map path builder, reads
exactly `+0x2CC`. `confirmed` for `+0x128`, `+0x1B4` and the lattice (live strings); `likely`
that `+0x2CC` and `+0x358` are those two overrides.

Which means `FINDINGS-startup.md`'s "the `common/` loop reads `+0x278` and `+0x2CC`" needs a look:
`+0x2CC` is read by `CMap::CMap` through `0x489060`, not by the `common/` loop, and on the lattice
`+0x278` would be the `history` override rather than anything to do with `common`. I did not
re-read the `common/` loop, so I flag it rather than claim it.

## 11. Corrections to the existing record

For you to apply; the merge tool will not overwrite a name, so these are arguments, not entries.

1. **`0x8DFA0` and `0x8E2E0`'s comments name the wrong file.** Both say `map/cache/map.bin`. The
   string each one references is `cache/adjacencies.bin` (`0x15BE2C8`, at `0x48DFD1` and
   `0x48E30B`); `/cache/map.bin` is referenced only from `0x486F10`, a class in the graphics
   module. Suggest renaming to `CMap::ReadAdjacencyCache` / `CMap::WriteAdjacencyCache`, with
   signatures `bool __stdcall CMap::ReadAdjacencyCache(CMap* this)` and
   `void __stdcall CMap::WriteAdjacencyCache(CMap* this)`, and the §5 format in the comment. The
   size identity `14190*4 + 83558*20 = 1727920` and the byte-for-byte match against live memory
   are the evidence.
2. **`0x8DFA0`'s comment says the cache is "where a non-zero bearing actually comes from" and
   that the two in-code builders write zero. Both halves of that are right, but the builder it
   names is wrong**: `{0, to, 0, 0, 0}` is pushed by `0x4911B0` (rva `0x911B0`), not by `0x917A0`.
   `FINDINGS-temperature.md` §10's table has the same misattribution. `0x917A0` writes the
   template's `+0x2C`/`+0x30`/`+0x5C`/`+0x60`; it does not touch edges. `findRefs --callers
   0x4ACCA0` gives the complete four-site list in §5.
3. **`CMap +0x210C` is `definitions_file`** — `map/definition.csv`, read live. `project.json`'s
   `unknown_210c` guessed exactly that and the guess is right. Renaming it closes "the one of the
   twelve that the loader side could not place".
4. **`CMap +0x2A64` is the province-template count**, not "purpose not known". Both
   `ReadAdjacencyCache` (`0x48E0B3`) and `WriteAdjacencyCache` (`0x48E3DF`, `0x48E497`) use it as
   the loop bound over `+0x2A60`. `BiceLib/GameClasses/CMap.hpp`'s comment on `province_count`
   says the same thing about `+0x2A64` — "holds 14190 as well; what it is for is not known" —
   and can now say what it is for.
5. **`CProvinceTemplate +0xA2` is the northern hemisphere, not `southern_hemisphere`.**
   `FINDINGS-temperature.md` §4 already argued this three ways; §7 above adds a fourth, from six
   named cities whose latitudes are known, and the field reads 1 on all three northern ones and 0
   on all three southern ones. The name in `project.json` is still the wrong way round, and it is
   the kind of name that will mislead whoever reads it next.
6. **`FINDINGS-temperature.md`'s open item "which pixel `+0x64/+0x68` is" is closed** by §7, and
   its "`ProvinceEdge +0x10`'s writer — narrowed to map.bin" wants replacing with §5 and §6.

## 12. What is not established

- **Where `ProvinceEdge +0x10` and `+0xC` are computed.** The inputs are settled (`+0x64/+0x68`,
  §6) and the arrival path is settled (§5), but no instruction was found that writes either
  field. What I ruled out, with the controls: `0x4ACCA0` has exactly four callers and none of them
  supplies a non-zero bearing, so it is not created but filled; a scan of `0x480000..0x4A5000`
  for functions reading both `+0x64` and `+0x68` *and* `+0x90`/`+0x94` and storing to `[reg+0xC]`
  or `[reg+0x10]` returned seven functions and none of them is an edge filler; an image-wide scan
  for functions carrying the `0x66666667` divide-by-20 magic together with `+0x90`, `+0x94` and
  such a store returned hundreds of unrelated hits. *What would settle it:* the fill almost
  certainly lives under the `CALC_PATHS` block at `0x48A777`, whose six calls I did not trace —
  `0xA82490`, `0x45FA80`, `0xA82E40`, `0x840E90`, `0xA87020` and `0x4C0700` (twice). Read those,
  starting with `0x4C0700`, since it is the one called twice and the only one in the game's own
  address range besides `0x45FA80`.
- **What a land–sea bearing is measured between.** §6's three border-based hypotheses each scored
  1–2 % against a 7 % control, so they are wrong rather than unproven. The same-kind fit at 99 %
  is the positive control that says the method works when the answer is there.
- **The 1 % of same-kind edges the bearing formula misses** — 599 land–land and 284 sea–sea.
  *Cheapest check:* intersect them with the pairs `adjacencies.csv` declares explicitly; if they
  are the same set, the explicit edges are getting their bearing from somewhere else.
- **What `map/cache/map.bin` holds**, and the class at `0x486F10` that owns it. Its one caller is
  `0x850AB0`, in the graphics module, and its object carries the map width+1 and height+1 at
  `+0x20`/`+0x24` and a path string at `+0x28`. I note specifically that this `+0x28` is a
  `std::string`, not a second stale flag — `mov byte [edi+0x28], bl` there is the string being
  emptied, and reading it as a flag would be trap 12.
- **`0x48F260` and `0x48FAC0`** (rva `0x8F260`, `0x8FAC0`), called at `0x48A6FA` and `0x48A700`
  between the adjacency graph and the geometry pass. Not read.
- **`CMap +0x2A70`**, which reads `1077092384` live; and `CMap +0x20E4`/`+0x20E8`, still
  unidentified beside the raster pointer at `+0x20E0`.
- **Whether `IsCacheStale`'s open-failure arm is reachable.** I argue it is not, because
  `FileExists` has already passed, but I did not prove the two cannot disagree.
- **The stage order inside `LoadMapFiles`.** I established the order of the eight sites that
  matter (the three `+0x28` gates and the five calls between them) from the call graph and from
  the fact that the function contains no loop over its stages — but I did not read the whole
  1 846 instructions, and I make no claim about anything I did not name.

### Which claims rest on the live process, and which survive a restart

**Static, survives anything:** §2's function extents and the gate sites; §3's checksum algorithm,
file list and polarity; §5's cache format and the four-site edge-creation list; §7's write sites
and the land/sea gate; §9's whole chain; §11's corrections.

**Live, and survives a restart because it is recomputed from files every launch:** §7's rule for
`+0x64/+0x68` (the `positions.txt` pass at `0x48A73F` is **not** gated on the stale flag, so it
runs every start); the pixel formula in §7, confirmed against `definition.csv` and
`provinces.bmp` on disk; §4's `climate.bin` identity; §5's byte-for-byte match, which is a file on
disk against a field.

**Live, and does not survive:** the stamp value `0x856CAC69` and `CMap +0x28 = 0` are facts about
this mod's current seven files and this launch's cache — change any of the seven and both change.
The object addresses (`CMap` at `0x29453020`, the raster at `0x297CF220`, the registry at
`0x54FD428`) are gone at the next launch. §6's percentages and §7's 14 189-of-14 189 would
re-measure the same on a restart with the same files, and would not if the mod's map changed.
§8's raster field layout is live-only in the sense that I read the values rather than the code
that writes them.

## 13. The headline for the mod, in five lines

1. **One byte decides every map cache**, and it comes from the checksums of seven files:
   `default.map`, `positions.txt`, `terrain.txt`, `provinces.bmp`, `terrain.bmp`,
   `definition.csv`, `adjacencies.csv`.
2. **Editing `climate.bmp` or `rivers.bmp` invalidates nothing.** `cache/climate.bin` is derived
   from `climate.bmp` and gated on that same byte, so a climate edit can have no effect at all,
   silently. Delete `…\Documents\Paradox Interactive\Hearts of Iron III\<mod>\map\cache\` to force
   a rebuild — that, not the game folder, is where the cache lives.
3. **`map/cache/adjacencies.bin` is positional and headerless**: a count then that many 20-byte
   records, province id 0 upward, no ids in the file. Change `max_provinces` without the stamp
   changing and the whole file is read against the wrong provinces. The stamp covers
   `default.map`, so in practice it does change — but that is the mechanism by which a stale
   cache would be catastrophic rather than merely wrong.
4. **A province's climate comes from one pixel**, and that pixel is `positions.txt`'s `unit`
   position where there is one and the bounding-box centre otherwise. **51 provinces currently
   sample a pixel belonging to a different province** and 6 sample a pixel whose colour is in no
   `definition.csv` row. The engine only warns when the position was given explicitly, so none of
   the 51 is logged. Adding a `unit` entry inside the province is the fix, and it is also how the
   engine would start reporting them.
5. **`map/cache/climate.bin` is directly readable**: 14 190 little-endian int32s, indexed by
   province id, each the palette index out of `climate.bmp`. Temperature is
   `(index − 100) × 0.150 °C` plus `terrain.txt`'s `temperature` — so that file is a
   ready-made audit of what climate every province actually got.
