# What the interface already computes

Read out of the executable on 2026-10-02; nothing here needed the game running. Addresses are
**virtual**, based `0x400000`, with the rva beside each one the record wants - trap 1. The
question was BiceLib's: the DLL repeatedly needs numbers the simulation does not keep as fields,
and a panel that displays such a number has already computed it. So: **what can be read rather
than recomputed, what does it cost, and is it safe to call from inside the process.**

The record held 23 `*Tooltip*` entries when this started, nineteen of them the
`ProvinceTooltip_*` family. That was an undercount, as expected. This file adds 24 call shapes,
resolves the one open item in `FINDINGS-survivors.md`, corrects one recorded signature, and
names five `CCountry` goods pools the record carried as `unknown_pool_*` and `unused_pool_*`.

**The headline is the fifth of those.** `BuildGoodsLedgerTooltip` (rva `0xF3000`) is a complete
per-goods income-and-expenditure ledger, and because it reads fifteen `CCountry` arrays by name
it hands over the **field offsets** - which is better than a function to call, because reading a
dword costs nothing and cannot throw.

---

## 1. How the sweep was done, and its positive control

A localisation key is a string literal in `.rdata`, and a tooltip is usually the only reader of
its own key. So: every NUL-terminated `[A-Z][A-Z0-9_]{3,63}` string in `.rdata` and `.data`
(6905 of them), every four-byte reference to one in `.text`, grouped by the function that
contains the reference, ranked by distinct keys. 389 functions survive after the Windows
`ERROR_*`/`CERT_*`/`HRESULT` tables and the `defines.lua` name table (rva `0x46210`, 395 keys)
are filtered out.

**Attributing a reference to a function is where this could have gone wrong, and it did at
first.** The first pass found candidate entries by scanning `.text` for a run of `0xCC` followed
by a prologue byte. That is trap 9 wearing a disguise: a `0xCC` *byte* inside an instruction is
not an `int3`, and `call 0xffc9ccf0` encodes as `e8 f0 cc c9 ff`, which produced a phantom
function boundary at `0x7852DD` and sent the first reading of item 1 in the wrong direction for
twenty minutes. Five of the sweep's top rows (`0x5A66A2`, `0x6E638A`, `0x6CDB71`, `0x61A41B`,
`0x723CD1`) are phantoms of the same kind.

The method that works, and which every address in this file was resolved with:

1. take the nearest address **below** the site that is the target of a `call rel32` somewhere in
   the image - those are real function entries by construction (15220 of them);
2. decode forward from it until an `int3` **instruction**;
3. if the site is inside, that is the function; otherwise skip the padding and repeat.

*The positive control.* Run against the five keys the record already attributes:

| key | string | the one reference | the record's owner | inside it? |
| --- | --- | --- | --- | --- |
| `FACTION_DRIFT_RELATIONS` | `0x15C1618` | `0x4FAE5D` | `CAlignment::BuildDriftTooltip` `0x4FA0B0..0x4FBBD8` | yes |
| `TRAIT_GAIN_PROGRESS` | `0x15BD620` | `0x474311` | `CTraitGainTracker::BuildProgressTooltip` `0x474240` | yes |
| `LOGTT_4` | `0x15BE6B4` | `0x499DD4` | `ProvinceTooltip_Build` `0x4973E0..0x49DCF5` | yes |
| `UNIT_COMBAT_WIDTH` | `0x15D6504` | `0x72A4FA` (+2 more) | `CCombatView::BuildUnitTooltip` `0x729D40` | yes |
| `SLIDER_NEED` | `0x15C1F14` | `0x51A32C` (+4 more) | `CDistributeProduction::GetNeedTooltip` `0x51A300` | yes |

So the sweep can see what is already known, and the two keys with extra references turned those
extras into findings rather than noise (sections 5 and 7).

**A bonus from the control.** `ProvinceTooltip_Build` is **slot 3 of the *second* vftable of
`CProvince` (`0x15BEBA4`) and of `CMapProvince` (`0x15BEC1C`)** - read straight out of
`vftable + 12`, both answer `0x4973E0`. The record said only "reached through a vtable". Its
extent is `0x4973E0..0x49DCF5`, which contains the 20-entry jump table at `0x49DCA4` the record
already has, so the extent and the record agree.

---

## 2. The out parameter has two shapes, and getting it wrong corrupts the stack

This is the single most load-bearing thing in this file for the DLL. A tooltip builder's `out`
argument is **either** a bare `Hoi3CString` (0x1C bytes) **or** a 0x5C-byte three-string record.
There is no way to tell from the name and the two are not interchangeable.

### The record, and its ABI

```
struct GuiTooltipText {      // 0x5C bytes
    Hoi3CString text;        // +0x00   the only slot most builders fill
    Hoi3CString second;      // +0x1C
    Hoi3CString third;       // +0x38
    int         number;      // +0x54   initialised 0
    bool        flag;        // +0x58   initialised 1
};
```

The layout is read off its three compiler-generated members, all three previously unrecorded:

| what | rva | convention | body |
| --- | --- | --- | --- |
| destructor | `0xC500` | `this` in **ESI**, bare `ret` | frees and empties the strings at `+0x38`, `+0x1C`, `+0` in that order, each guarded by `capacity >= 0x10` |
| copy constructor | `0xC560` | `this` on the stack, source in **EDI**, `ret 4`, answers `this` | three `std::string::assignString` calls on `+0`, `+0x1C`, `+0x38`, then `+0x54` and the byte at `+0x58` |
| `operator=` | `0x128B0` | dest in **ESI**, source in **EDI**, bare `ret`, answers ESI | the same five fields, no prologue at all |

The copy constructor is the cleanest evidence, because it names every field exactly once:

```
0x0040C57A  mov  esi, [ebp+8]            ; this
0x0040C582  mov  [esi+0x14], 0xf         ; string 1 empty
0x0040C58F  mov  byte [esi], bl
0x0040C591  call 0x401bd0                ; assignString(this+0,    src+0,    0, -1)
0x0040C59F  lea  eax, [edi+0x1c]
0x0040C5AF  call 0x401bd0                ; assignString(this+0x1c, src+0x1c, 0, -1)
0x0040C5BE  lea  edx, [edi+0x38]
0x0040C5CE  call 0x401bd0                ; assignString(this+0x38, src+0x38, 0, -1)
0x0040C5D3  mov  eax, [edi+0x54]
0x0040C5D6  mov  [esi+0x54], eax
0x0040C5D9  mov  cl,  [edi+0x58]
0x0040C5DC  mov  [esi+0x58], cl
0x0040C5F0  ret  4
```

**The destructor has 114 callers and `operator=` 27**, so this is the GUI's standard
tooltip-result type rather than one panel's local struct. A scan of `.text` for
`mov byte ptr [reg+0x58], 1` - the one instruction every producer of this type emits -
finds **86 sites**, and they land in exactly the functions the key sweep ranked highest.
Confidence `confirmed` for the layout and the three members; **the game's own name for the type
is not established** (see *What is not established*), so it is recorded as `GuiTooltipText`,
class-free.

### Who constructs it and who destroys it

**The callee constructs, the caller destroys.** `CAlignment::BuildDriftTooltip` is the worked
example: its first act is to write the empty state over all three strings and set `+0x54 = 0`,
`+0x58 = 1`.

```
0x004FA0DB  mov  edi, [ebp+0xc]          ; out
0x004FA0E4  mov  [edi+0x14], eax         ; eax = 0xf
0x004FA0E7  mov  [edi+0x10], ebx         ; ebx = 0
0x004FA0EA  mov  byte [edi], bl
0x004FA0EC  mov  [edi+0x30], eax         ; string 2
0x004FA0F5  mov  [edi+0x4c], eax         ; string 3
0x004FA100  mov  [edi+0x54], eax         ; eax has just been xor'd to 0
0x004FA103  mov  byte [edi+0x58], 1
```

and its caller passes raw stack space and destroys it afterwards:

```
0x007853EB  lea  eax, [ebp-0xc4]         ; uninitialised 0x5C bytes
0x007853F1  push eax                     ; out
0x007853F5  call 0x402610                ; CCountryTag::GetCountry
0x007853FD  push eax                     ; country
0x007853FE  call 0x4fa0b0
0x00785403  mov  edi, eax                ; the returned out
0x00785405  mov  esi, ebx                ; this function's own out
0x0078540E  call 0x4128b0                ; *ebx = *edi
0x00785413  lea  esi, [ebp-0xc4]
0x00785419  call 0x40c500                ; destroy the local
```

So from the DLL: **give it 0x5C bytes of zeroed stack, call, use, then call `0xC500` with the
pointer in ESI.** Do not pre-construct the strings; the callee overwrites the length and capacity
words without freeing, so a pre-constructed string with a heap buffer leaks.

The same discipline applies to the `Hoi3CString` form: those builders also write
`[out+0x14] = 0xF; [out+0x10] = 0; *out = 0` before touching it, so `out` must be raw space, and
the caller frees it.

### Which builders take which

Settled per function by reading the first instruction that touches the argument. Where a builder
writes `+0x58` on a *local* rather than on its argument - most of them do, because they assemble
sub-tooltips - that is not evidence about the argument, and those are marked below.

---

## 3. Item 1: `CAlignment::BuildDriftTooltip`'s caller, and the out object

`FINDINGS-survivors.md` left this open: *"The out object `CAlignment::BuildDriftTooltip` fills
(`[ebp+0xC]`, 0x5C bytes, three 0x1C-byte string slots), and which screen reads it. Its one
caller, inside the function that begins somewhere before `0x7853C0`, was not identified -
`functionStart` lands at `0x784E30` with two `ret`s in between."*

Both halves are now closed, and the trap-2 check was the whole of it.

### The caller is `0x785250`, not `0x784E30`

`functionStart(0x7853FE)` answers `0x784E30`, and `retsBefore(0x784E30, 0x7853FE)` answers two
bare `ret`s, at `0x784EE1` and `0x78524F`. Trap 2 says look. What settles it is not the `ret`s
but **the instruction immediately after the second one**:

```
0x0078524D  pop  ebp
0x0078524F  ret                          ; bare - a bool return, al set by `xor al,al` / the body
0x00785250  push ebp                     ; a fresh prologue, no int3 between
0x00785251  mov  ebp, esp
0x00785253  push -1
0x00785255  push 0xc77c0c                ; its own SEH scope table - 0x784E30's is 0xc2ca2c
...
0x00785430  ret  4
```

So there are **two** functions here and the boundary is unpadded:

| | extent | ends | shape |
| --- | --- | --- | --- |
| `0x784E30` | `0x784E30..0x78524F` | bare `ret` ×2 (`0x784EE1` is an early exit, `0x784EC9` jumps past it - trap 3) | `bool __thiscall(this)`, pushes `country_info` and `country_flag` |
| **`0x785250`** | `0x785250..0x785432` | `ret 4` at `0x785430` | `GuiTooltipText* __thiscall(this@ECX, GuiTooltipText* out)`, answers `out` |

Two independent signals say the split is real and not a cold path: the two bodies push
**different SEH scope tables** (`0xC2CA2C` against `0xC77C0C`), and they have **different `ret`
immediates**, which one MSVC function cannot. `0x784E30` also returns a byte in `al` while
`0x785250` returns a pointer in `eax`. The jump at `0x784EC9 -> 0x784EE2` is inside the first
function, not across the boundary.

**This is trap 2's second failure mode, not its first.** The functions do abut, but
`functionStart` would have walked past `0x785250` anyway - it only accepts a candidate whose first
byte is in its prologue set, and here the candidate *is* `push ebp` (`0x55`), so what defeated it
is purely the missing padding. `retsBefore` was the check and it worked.

### What `0x785250` is

`this` arrives in ECX and is used as a `CCountryTag` - `mov ecx, edi; call 0x402610`
(`CCountryTag::GetCountry`) at `0x7853F3`. Its one caller is `0x7801F0`, inside
**`CDiplomacyView` slot 10** (`0x77F490`, vftable `0x15D63..`/`CDiplomacyView[10]`), which is the
function the key sweep ranks on `CGM_TOOLTIP_FACTION_ALIGN`, `CGM_TOOLTIP_LEAVE_FACTION`,
`CGM_TOOLTIP_REJOIN_FACTION`, `DIP_HIGHEST_THREAT_TOOLTIP` and
`DIP_HIGHEST_THREAT_TOOLTIP_DELAYED`. So the answer to "which screen reads it" is **the diplomacy
view's faction column**.

`0x785250` chooses between two texts:

```
0x007852B2  call 0x78f900                ; a predicate on `this`
0x007852B7  test al, al
0x007852B9  je   0x785330
     ; true  -> LEAVE_FACTION_INTENTION with $COUNTRY$
0x00785330  push edi                     ; this
0x00785331  call 0x78f790                ; the country's faction, or null
0x00785339  cmp  eax, esi                ; esi = 0
0x0078533B  je   0x7853eb                ; null -> the drift tooltip
```

so **the alignment-drift tooltip is what a country with no faction shows**, and a faction member
shows a leave/rejoin intention instead. That is a behavioural fact the politics findings did not
have.

### The out object

It is the `GuiTooltipText` of section 2. `BuildDriftTooltip` fills **only `text` (+0)**, leaves
`second` and `third` empty, sets `number = 0` and `flag = true`, and hands the finished text over
with one `appendString` at `0x4FBB6E`. `0x785250` copies that into its own out with
`operator=` and destroys the temporary. The class is `confirmed` as a structure and as the GUI's
shared tooltip type; the game's own *name* for it is not established.

---

## 4. Item 2: `CTraitGainTracker::BuildProgressTooltip`

`0x474240` (rva `0x74240`), already `confirmed`. Everything the record says holds. Three
additions.

**Its extent is `0x474240..0x47442D`, and a fresh `push ebp` sits at `0x474430`.** There are
three `ret 8`s in the region (`0x47442D`, `0x47444F`, `0x474601`) and a prologue three bytes
after the first, so this is trap 2 again - benign here, because the record's address is the entry
and nothing was computed from a wrong extent, but worth stating so nobody extends the body later.

**The map walk and the arguments.**

```
0x0047425C  mov  ebx, [ebp+0xc]          ; out, an Hoi3CString
0x0047426A  mov  [ebx+0x14], 0xf         ; constructed here, not by the caller
0x00474289  mov  eax, [eax+0xc]          ; tracker->map (+0xC)
0x0047428C  mov  esi, [eax]              ; _Myhead->_Left = begin
0x004742A4  cmp  [esi+0x10], edi         ; value > 0 ?
0x004742AD  cmp  [esi+0x10], 0x186a0     ; value < 100000 ?
0x004742CD  mov  ecx, [esi+0xc]          ; the key
0x004742D0  mov  ecx, [ecx+0x10]
0x004742D5  mov  edx, [edx+0x18]         ; slot 6 - the trait's name
0x004742E3  push 2                       ; two decimals
0x004742FB  call 0xa5aca0                ; FormatFixedPoint
0x00474319  call 0x4735d0                ; TRAIT_GAIN_PROGRESS with $TRAIT$ and $PROG$
0x004743CC  cmp  byte [esi+0x15], 0      ; _Isnil - the in-order successor walk
```

`+0xC`, `+0x10`, `+0x15` are MSVC's `_Tree_node`: `_Left 0`, `_Parent 4`, `_Right 8`,
`_Myval 0xC`, `_Color 0x14`, `_Isnil 0x15`. So the pair is a four-byte key at `+0xC` and a
four-byte value at `+0x10`, which is what makes `[esi+0x10]` the progress.

**The scale, and why it is worth flagging.** The record already names the formatter: rva
`0x65ACA0` is `FormatFixedPoint`, `confirmed`, "the value over a thousand, with as many decimal
places as asked for". Its body is the proof -

```
0x00A5ACE5  mov  eax, 0x10624dd3
0x00A5ACEA  imul ebx
0x00A5ACEC  sar  edx, 6                  ; ebx / 1000, the integer part
0x00A5AD16  imul esi, esi, 0x3e8
0x00A5AD1E  sub  ebx, esi
0x00A5AD21  add  ebx, 0x3e8              ; the remainder with a leading 1 so itoa keeps zeros
```

- so the progress field is in **thousandths of a percent**: `100000` prints as `100.00` and means
100%. Trap 7 holds, but one level deeper than usual: the quantity being stored in thousandths is
itself a percentage, so a DLL reading `tracker->map[trait]` must divide by 100000 to get a
fraction and by 1000 to get the number the game shows. Mistaking it for ordinary thousandths is a
factor of 100.

Callers `0x58161F` and `0x765DA9` are as recorded. `0x58161F` is inside **`CLeader` slot 9 /
`CNullLeader` slot 9** (`0x580220`, the leader tooltip - `LEADER_SKILL`, `LEADER_XP`,
`LEADER_POSITIONING`, `LEADER_COMMAND_SIZE`, `ACTUAL_TRAITS_DESC`, `TO_GAIN_TRAITS_DESC`), so the
trait-progress lines are the `TO_GAIN_TRAITS_DESC` block of the leader tooltip.

---

## 5. The goods ledger, and five `CCountry` pools it names

`0xF3000` (rva `0xF3000`), `confirmed`. `Hoi3CString* __stdcall (CCountry*, Hoi3CString* out,
int goods)`, `ret 0xC`, extent `0x4F3000..0x4F4B5E`. Fourteen call sites; the argument order is
read off them rather than guessed:

```
0x006CCCD9  push 5                       ; goods
0x006CCCDB  lea  ecx, [esp+0x18]
0x006CCCDF  push ecx                     ; out
0x006CCCE0  push edi                     ; country
0x006CCCE1  call 0x4f3000
```

Seven of the fourteen are in `CTopBar` slot 5 (`0x6CCB80`), one per goods category; the rest are
in the production view's region around `0x801AA9`, which also shows the country lookup
(`[[0x1A855A4]+0x16C][player_id]`).

**Every localisation key in it is immediately preceded by the load of the value it labels**, so
the mapping is read and not inferred. The index is the `CGoodsPool` index the record already has
- a pool's array starts at `pool+8`, so `0` is supplies, `1` fuel, `2` money, `3` crude oil,
`4` metal, `5` energy, `6` rare materials.

| key | read at | array | the pool the record already has | status |
| --- | --- | --- | --- | --- |
| `RES_PROD` | `0x4F3350` | `country + goods*4 + 0x778` | `+0x770 home_produced` | agrees |
| `RES_CONVOYED_IN` | `0x4F35DF` | `+0x79C` | `+0x794 convoyed_in` | agrees |
| `RES_CONVOYED_OUT` | `0x4F43FE` | `+0x7C0` | `+0x7B8 unknown_pool_7b8` | **names it `convoyed_out`** |
| `RES_TRADED_AWAY` | `0x4F4160` | `+0x7E4` | `+0x7DC unknown_pool_7dc` | **names it `traded_away`** |
| `RES_REPAID_AWAY` | `0x4F42AF` | `+0x82C` | `+0x824 unused_pool_824` | **names it `repaid_away`** |
| `RES_INC_DEBT` | `0x4F396C` | `+0x850` | `+0x848 unused_pool_848` | **names it `income_from_debt`** |
| `RES_TRADED_FOR` | `0x4F3750` | `+0x874` | `+0x86C unknown_pool_86c` | **names it `traded_for`** |
| `RES_CONVERTED` | `0x4F3F89` | `+0x8BC` | `+0x8B4 conversion_made` | agrees |
| `RES_CONVERTED` | `0x4F3DA4` | `+0x8E0`, shown negated (`neg ecx`) | `+0x8D8 conversion_used` | agrees |
| `RES_FROM_PUPPETS` | `0x4F3B88` | `+0x904` | `+0x8FC tribute_received` | agrees |
| `RES_SENT_TO_MASTER` | `0x4F454D` | `+0x928`, shown when `< 0` (`jge` skips) | `+0x920 tribute_sent` | agrees, and confirms it is held negative |
| `RES_USED` | `0x4F47EB` | `+0x994` | `+0x98C usage` | agrees |
| `RES_INTO_NET` | `0x4F469C` | `+0x9B8` | `+0x9B0 sent_to` | agrees |
| `RES_SHIPPED_BACK` | `0x4F493A` | `+0x9DC` | `+0x9D4 sent_back` | agrees |

**`convoyed_out` is a convergence, not a new claim.** `project.json`'s own comment on the convoy
economy (`0x4C6...`) already says "`ConvoyedOut` (+0x7B8) is credited on S.controller and
`ConvoyedIn` (+0x794) on E.controller". Two readings from opposite ends of the code agree, which
is trap 14's good case.

**Two of the four "unused" pools are used.** `+0x824` and `+0x848` are recorded as "a CGoodsPool
nothing fills". They are read here and labelled `RES_REPAID_AWAY` and `RES_INC_DEBT`, which is
debt service in goods - plausible in a game where a loan is paid in resources, and exactly the
sort of thing that is zero in most games and so looks unfilled. The names are `likely`, not
`confirmed`: the tooltip proves what the game *calls* each array, not that anything writes it.

**`RES_CONVOYED_IN` is suppressed for supplies and fuel** (`cmp eax, 1 / cmp eax, 0; je` at
`0x4F35CB`), which fits the convoy function's own special-casing of those two through the area
headroom path.

Two aggregates are computed at the head and are what the `RES_CHANGE` line is built from
(`confirmed` as instructions, `likely` as interpretation):

```
0x004F3041  edx = +0x9B8 - +0x82C - +0x928 + +0x994 + +0x8E0 + +0x7C0 + +0x7E4   -> [ebp-0x14]
0x004F304F  esi = +0x778  (+ +0x79C when goods > 1)
0x004F30C1  eax = +0xA6C + +0x9DC + +0x850 + +0x8BC + +0x874
```

`+0xA6C` is the array of `+0xA64 unused_pool_A64`, which the record says "has writes but is empty
in practice"; it is in the income sum here.

It returns its `out` (`mov esi, [ebp+0xc]` at `0x4F4AFB`, `mov eax, esi` in the epilogue).

**For the DLL this is the best case available: do not call it, read the fields.** Fifteen dwords
per goods category, all thousandths, all on `CCountry`.

---

## 6. The distributor need-tooltips are six bodies, and one recorded signature is wrong

`SLIDER_NEED` has five references, not one. Resolved to entries and vftable slots:

| rva | slot | holders | `ret` |
| --- | --- | --- | --- |
| `0x11A300` | 1 | `CDistributeProduction` | **`0xC`** |
| `0x11CAD0` | 3 | `CDistributeReinforcement` | `0xC` |
| `0x11DBB0` | 3 | `CDistributeUpgrade` | `0xC` |
| `0x11E8E0` | 1 | `CDistributeDiplomacy` | `4` |
| `0x121480` | 1 | `CDistributeConsumerGoods`, `CDistributeResearch`, `CDistributeSupply` | `0xC` |

Two things follow. **The slot is not stable across the family** - 1 for four of them and 3 for
two - so a BiceLib hook that assumes one index would call the wrong virtual on two distributors.
And `0x121480` is held by three classes at the same slot, which under trap 4 is a fold inside one
family: the body is shared and is recorded class-free rather than as any one distributor's.

**The correction.** `project.json` records
`Hoi3CString* __thiscall CDistributeProduction::GetNeedTooltip(CDistributeProduction*,
Hoi3CString* out)`, which predicts `ret 4`. The function does **`ret 0xC`**: three stack
arguments, of which this body reads only the first (`mov esi, [ebp+8]` at `0x51A369`), with the
receiver in ECX (`mov [ebp-0x14], ecx` at `0x51A328`). The signature wants a third and fourth
parameter added, or `checkSignatures.py` will keep flagging it. The recorded confidence of
`likely` was right.

---

## 7. READ THIS RATHER THAN RECOMPUTE IT

Everything below is reached either as a free function with explicit arguments or as a numbered
vftable slot. **Safety is the column that matters**, and it is graded:

- **A** - a free function whose inputs are simulation objects and whose `out` the caller owns.
  Safe from any BiceLib thread that holds the pointers, including a tick.
- **B** - a virtual on a *simulation* object (`CProvince`, `CLeader`, `CSubUnitDefinition`,
  `CCombatMember`). Safe, but the receiver must be a real instance, so check its vftable first.
- **C** - a virtual on a *window or list-entry* object. It reads that object's own UI state -
  which tab is open, which row is hovered, what the mouse is over - so it is only meaningful
  while that window exists and is showing what you want. Calling it with a synthesised receiver
  is a crash.
- **!** - additionally reads global UI state (the current map mode, the hovered element), so the
  answer depends on the moment, not only on the arguments.

| what you want | function | rva | call shape | `out` | cost | safe? |
| --- | --- | --- | --- | --- | --- | --- |
| **a country's whole per-goods ledger** - produced, convoyed in/out, traded for/away, debt in/out, tribute in/out, converted, used, shipped back, net | `BuildGoodsLedgerTooltip` | `0xF3000` | `__stdcall(CCountry*, Hoi3CString* out, int goods)` `ret 0xC` | `Hoi3CString` at `[ebp+0xC]`, callee-constructed | 0x1B5F bytes, ~15 string builds | **A** - but prefer the 15 field offsets in section 5 and call nothing |
| alignment drift, all seven terms with the game's own labels | `CAlignment::BuildDriftTooltip` | `0xFA0B0` | `__stdcall(CCountry*, GuiTooltipText* out)` `ret 8` | `GuiTooltipText` at `[ebp+0xC]` | 0x1B29 bytes; recomputes all seven terms and an integer sqrt | **A** |
| whether a country would leave/rejoin its faction, else the drift text | `BuildFactionIntentionTooltip` | `0x385250` | `__thiscall(this@ECX /*CCountryTag-like*/, GuiTooltipText* out)` `ret 4` | `GuiTooltipText` at `[ebp+8]` | 0x1E3 bytes | **A**, receiver class `inferred` |
| a leader's trait-gain progress, formatted | `CTraitGainTracker::BuildProgressTooltip` | `0x74240` | `__stdcall(CTraitGainTracker*, Hoi3CString* out)` `ret 8` | `Hoi3CString` at `[ebp+0xC]` | 0x1EE bytes, one map walk | **A** |
| a leader's skill, XP, command size, positioning, traits held and traits coming | `CLeader::BuildTooltip` | `0x180220` | slot **9** of `CLeader` (`0x15C5220`) and `CNullLeader`, `ret 4` | `Hoi3CString` at `[ebp+8]` | 0x1583 bytes | **B** |
| **a unit's movement speed broken into its nine causes** - terrain, weather, fuel, combat, trait, adjacency, local modifier, motorised bonus, retreating | `BuildSpeedModifierTooltip` | `0x1C82A0` | `__stdcall(a, b)` `ret 8`; one argument is the `GuiTooltipText* out`, the other is written through by `0x5C8D10` first | `GuiTooltipText`; which slot is **not established** | 0xA64 bytes; calls `0x5C8D10` once to compute the terms | **A** once the two arguments are told apart |
| **a unit's attrition broken into infrastructure, weather, tech and terrain** | `BuildAttritionTooltip` | `0xA0BA0` | `__stdcall(?, Hoi3CString* out, CUnit* unit)` `ret 0xC`; gated on the unit's slot 9 returning true, else `out` is emptied | `Hoi3CString` at `[ebp+0xC]` | 0x112E bytes | **A**; argument 1 not identified |
| a unit definition's whole stat block - 47 keys from `MAX_STRENGTH` to `RADIO_STRENGTH` | `CSubUnitDefinition::BuildStatsTooltip` | `0x1A55C0` | slot **8** of `CSubUnitDefinition` (`0x15BDC04`) and `CNullSubUnitDefinition`, `ret 0xC`, receiver in ECX | `Hoi3CString` at `[ebp+8]` | 0x1F37 bytes | **B**; the two further stack arguments are not identified |
| a **live** brigade's effective stats, `UNIT_STATS` / `BV_STRENGTH` / `BV_EXPERIENCE` plus the 50-key block | `BuildUnitStatsTooltip` | `0x31F460` | `ret 8`, receiver in ECX; `[ebp+8]` is **not** a string - it is a 0x30+ byte object the function constructs two vftables into (`0x15D626C`, `0x15D6280`) | **not established** | 0x6534 bytes and a `_chkstk` of **0x17E0** | **do not call blind** - the return object is unidentified |
| combat odds as the outliner shows them - our/their leader, numbers, result and progress | `CCombatMember::BuildTooltip` | `0x2A9E90` | slot **13** of `CCombatMember` (`0x15D0B3C`), `ret 8`, receiver in ECX | `Hoi3CString` at `[ebp+8]` | 0x626 bytes | **B** - `CCombatMember` is a list entry, not a simulation object; it points at the combat |
| research efficiency and the four priority penalties, `MODIFIER_RESEARCH_EFFICIENCY`, `TECH_SUSPEND` | `CCurrentResearchEntry::BuildTooltip` | `0x416A10` | slot **12** of `CCurrentResearchEntry` (`0x15DFD4C`), `ret 8` | `[ebp+8]`/`[ebp+0xC]`, shape not pinned | 0xB1A bytes | **C** |
| production penalty and practical progress - `PEN_FULL_SPEED`, `PEN_MAX_PRIO`, `PEN_PARTIAL_PROGRESS`, `PEN_NO_PROGRESS`, plus inherited experience | `BuildProductionPenaltyTooltip` | `0x3F5A40` | `ret 8`, receiver in ECX, `out` at `[ebp+8]` | `Hoi3CString` | 0xC6E bytes | **A/C** - one caller, `CProductionView` slot 10 (`0x3FFD30`) |
| the top bar's entire number set - IC wasted/available/base/from-technology, every resource in and out, dissent, diplomatic influence, national unity, espionage, free spies, officers, manpower, money | `CTopBar::BuildTooltip` | `0x2CCB80` | slot **5** of `CTopBar` (`0x15D2C90`), `ret 8` | `[ebp+0xC]` | 0x23BA bytes, 41 keys | **C !** - its first act is `[this+0x380]`'s slot 4, the hovered element. It answers about **whatever the mouse is over**, so it is useless to a DLL that wants a specific number |
| intelligence estimates with and without the delay - spies caught, detected actions, estimated IC/manpower/dissent/unity/leadership, neutrality | `CEspionageView::BuildTooltip` | `0x21FCD0` | slot **10** of `CEspionageView` (`0x15CC10C`), `ret 8`; body `0x21FCD0..0x2225CF` (trap 2, a fresh prologue at `0x2225D0`) | `[ebp+8]` | 0x2900 bytes, 40 keys | **C** - reads the selected nation and item |
| strategic warfare: our/their bombers, provinces, IC and manpower lost, convoys, attackers, cargo | `BuildStratWarfareTooltip` | `0x66E50` | `ret 0xC`, `out` at `[ebp+0xC]`, a mode in `[ebp+0x10]`; called from `CTopBar` slot 5 at `0x6CCBED` | `Hoi3CString` | 0xDF2 bytes | **A/C** |
| the SWM tab tooltips only | `CStratWarfareWindow::GetTabTooltip` | `0x66D50` | slot **5** of `CStratWarfareWindow` (`0x15BD104`), `ret 4`, body only **0x100 bytes** - it abuts `0x66E50`, which is where the keys are | `Hoi3CString` at `[ebp+0xC]` | trivial | **C** |
| a province's modifier effects - 108 keys, every `MODIFIER_*` plus revolt risk, manpower, attrition, fort levels, war exhaustion | `BuildModifierEffectsText` | `0x56E00` | bare `ret` (`__cdecl`), **esp-framed, no `[ebp+N]` arguments at all** | not established | 0x2546 bytes | **unknown** - one caller, `0x6348F0` |
| the province view's own block - weather by name, temperature, owner, claim, occupier, railways, underground/partisan status | `BuildProvinceViewTooltip` | `0x2E4250` | `ret 0xC`; body `0x2E4250..0x2E7BFF` (trap 2, a fresh prologue at `0x2E7C00`) | `[ebp+0xC]` | 0x39B0 bytes, 52 keys | **A/C** - one caller, `CInGameIdler` slot 109 (`0x2C5290`) |
| per-province lines for all 15 map modes - supply (`LOGTT_*`), intel, victory points, theatre, weather, infrastructure, resources, air, naval | `ProvinceTooltip_Build` | `0x973E0` | slot **3** of `CProvince`'s second vftable (`0x15BEBA4`) and `CMapProvince`'s (`0x15BEC1C`) | as recorded | 0x6916 bytes, 0x2244 frame | **B !** - the receiver is a province you choose, but the function asks the in-game idler for the **current map mode**, so which arm runs is not yours to pick |
| per-goods trade surplus, `DIP_SURPLUS` / `DIP_NO_SURPLUS` for all seven | `BuildTradeSurplusTooltip` | `0x386690` | `ret 8`, `out` at `[ebp+8]` | `Hoi3CString` | 0x1D87 bytes | **A/C** - one caller in `CDiplomacyView` slot 10 |
| a brigade list row's combat width, upgrade target and reserve state | `CSubUnitEntry::BuildTooltip` | `0x3493B0` | slot **13** of `CSubUnitEntry` (`0x15D88CC`), `ret 8` | `[ebp+8]` and `[ebp+0xC]` | 0xB2F bytes | **C** |
| the outliner header counts - combats, armies, navies, air units, bombing | `BuildOutlinerHeaderTooltip` | `0x2AE0D0` | bare `ret`, three callers | `Hoi3CString` | 0x525 bytes | **A/C** |
| the need line of each production slider | the six bodies in section 6 | `0x11A300`, `0x11CAD0`, `0x11DBB0`, `0x11E8E0`, `0x121480` | slot 1 or slot 3, see the table | `Hoi3CString` at `[ebp+8]` | tiny | **C** |

### Two text helpers BiceLib will want if it extends rather than reads

Neither is in `project.json`.

- **`0x21FD0`** (122 callers, bare `ret`, `__cdecl` with register arguments): the localisation key
  in **EDX**, the variable name in **ECX**, the out string and the substitution value on the
  stack. It is `append one localised line with one $VAR$ filled in` and it is how every one of
  these builders writes a line - `mov ecx, 'PERC'; mov edx, 'SPEED_MODIFIER'; push value;
  push out; call 0x421fd0`. The exact stack argument count is **not established** (the one call
  site read cleans `0x10`).
- **`0x735D0`** (36 callers, bare `ret`): the two-variable form, key in **ECX** and two
  `(name, value)` pairs pushed - `TRAIT_GAIN_PROGRESS` with `$TRAIT$` and `$PROG$` at
  `0x474319`. Not read through.

The record already has what sits under them: `FormatFixedPoint` (`0x65ACA0`),
`CInternationalizedText::Render` (`0x682E40`), `std::string::assign` (`0xA160`),
`assignString` (`0x1BD0`), `appendString` (`0x33E30`), `appendChars` (`0x33B40`).

---

## What is not established

- **The game's own name for `GuiTooltipText`.** It has no vftable, so RTTI cannot name it, and
  nothing that handles it is registered to Lua. What would settle it: find the GUI function that
  *consumes* one - something that reads `+0x1C`, `+0x38`, `+0x54` and `+0x58` and hands them to a
  text element. All 86 producers were enumerated; no consumer was looked for.
- **What `second` (+0x1C), `third` (+0x38), `number` (+0x54) and `flag` (+0x58) mean.** Every
  builder read here fills only `text`. The localisation table has pairs like
  `DIP_HIGHEST_THREAT_TOOLTIP` / `_DELAYED` and `ESP_NUM_SPIES` / `_DELAYED`, which makes
  "the delayed tooltip" a reasonable guess for one of the string slots - but it is a guess, and
  `inferred` at best. What would settle it: a producer that fills more than one. Of the 86,
  `0x66E50`, `0x7F5A40` and `0x3493B0` are the likeliest.
- **`BuildSpeedModifierTooltip`'s two arguments.** `ret 8`, and `0x5C82C4` passes `&[ebp+8]` to
  `0x5C8D10` alongside the value of `[ebp+8]`, then re-reads `[ebp+8]` afterwards - so the first
  argument is written through. Which of the two is the out and which the unit was not decided.
- **`BuildUnitStatsTooltip`'s (`0x31F460`) return object.** It constructs something with vftables
  `0x15D626C` and `0x15D6280`, a self-pointer at `+8` and `0x727120` at `+0xC`, inside a 0x17E0
  byte frame. Until that type is identified the function must not be called from the DLL. What
  would settle it: `whoslot.py` on `0x15D626C`.
- **`BuildModifierEffectsText` (`0x56E00`) is esp-framed** and no stack argument was located.
  108 keys and one caller; worth a proper read because a province's effective modifier list is
  something BiceLib's map modes would use.
- **`BuildAttritionTooltip`'s first argument**, and the identity of the slot-9 predicate it gates
  on.
- **Whether `CCountry +0x824` and `+0x848` are ever written.** The tooltip proves the game calls
  them `RES_REPAID_AWAY` and `RES_INC_DEBT`; it does not prove anything fills them, and the
  record's "nothing fills it" came from a scan that was not repeated here. Under trap 12 a bare
  displacement scan would not settle it either; the honest check is a savegame with a loan in it.
- **The 365 functions in the sweep that were not read.** The filtered ranking is in
  `scratchpad/locsweep.json`. The ones most likely to pay, by key content and by being numbers
  the simulation does not store:
  - `0x138D60` (35 `*_TECH` keys) - what each technology effect contributes.
  - `0x1713E0` (`ATTACKER`, `DEFENDER`, `ATTTOTAL`, `ATTDETAIL`, `ATTUNIT`, `BOMBTHEM`) - body
    `0x1713E0..0x17257F`, trap 2 at `0x172580`. Looks like the strategic-bombing attack detail.
  - `0x3A3DB0`, `0x3A5CF0`, `0x3A7320`, `0x3AE290`, `0x3AFA10`, `0x3B1190`, `0x3B2920`,
    `0x3B7250`, `0x3B99D0`, `0x3BC0C0`, `0x39E180` - the eleven ledger pages, every one a table
    of per-unit and per-country totals.
  - `0x3C3510`, `0x3D3AB0`, `0x3DC090`, `0x3EA930`, `0x40D420` - the `BUILD_*_DRO`/`_IRO`
    cluster, which is build cost and time per brigade type.
  - `0x3FA710` (`CONV_EFF_IRO`, `LL_CONVOY_EFF_DESC`) - convoy efficiency.
  - `0x687F0` (`SWM_GRAPH_*_VAL`) - the strategic warfare graph maxima.
  - `0x2BE790` (`POL_MOBILIZE_*`, `POL_LIB_*`) - mobilisation and liberation gates.
- **Nothing here was checked against a running game.** It is all static reading, and the three
  "what BiceLib should read" offsets in section 5 are the cheapest thing in the file to verify:
  the savegame is plain text and names the pools.

## How the negatives were controlled

- **The key sweep.** Section 1's table: run against the five keys the record already attributes,
  it finds all five and places every reference inside the function the record names. So when it
  reports that a function has no localisation keys, that is about the function and not about the
  method.
- **The producer scan** for `GuiTooltipText` (`mov byte ptr [reg+0x58], 1`, 86 hits) was checked
  the other way: the first attempt searched for `mov dword ptr [reg+0x4C], 0xF` and found **7**,
  because almost every producer loads `0xF` into a register first. Seven would have been a
  confident wrong answer about how widespread the type is. The byte-store form has no register
  variant and the 86 it finds include every function the key sweep independently ranked at the
  top, which is the control.
- **The function-boundary method.** The naive byte scan for `int3` runs put phantom entries at
  `0x7852DD`, `0x5A66A2`, `0x6E638A`, `0x6CDB71`, `0x61A41B` and `0x723CD1`; the call-target
  chaining method places `0x49A5BE` inside `ProvinceTooltip_Build` and `0x5A66A2` inside
  `CSubUnitDefinition` slot 8, both of which are the right answers by the record. Every address
  in this file was resolved with the second method and none with the first.
- **Two decodes started from a guessed address and produced nonsense** (trap 9): `0x4FA0D0`
  printed `sldt word ptr [eax]` and `0x4127A0` printed `notrack call`. Both were redone from a
  function entry. Nothing in this file rests on a decode that did not start at an entry or at an
  address a tool printed.
