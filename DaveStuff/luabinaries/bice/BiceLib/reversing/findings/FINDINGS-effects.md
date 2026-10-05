# The effect half of the event script language

The grammar was read in `findings/FINDINGS-script.md` (91 effect keywords out of
`CEffect::LoadKey`'s switch) and two effects' tooltips in `findings/FINDINGS-effecttext.md`.
`findings/FINDINGS-triggereval.md` read the scoping machinery from the trigger side and named
`CContextEffect` as where the effect half should start. This is the effect side: the base class's
virtual table, the behaviour of the busiest leaves, and the thing wave 11 left open — what the
second argument of `Execute` is.

Addresses are **rvas** against an image base of `0x400000`, as everywhere in this folder. Where a
virtual address appears it says so.

## 1. The slot map — `CEffect` has twelve slots and this is all of them

`CEffect`'s vftable is at rva `0x11B58F4` (VA `0x15B58F4`) and has **12 slots**. The family is
**111 classes**, of which **101** have a table of their own; the other ten are the abstract
middles — `CAddModifierEffect`, `CBoolEffect`, `CCountryTargetEffect`, `CDiplomaticEffect`,
`CFlagEffect`, `CIntEffect`, `CRemoveModifierEffect`, `CStringEffect`, `CValueEffect`,
`CVariableEffect` — which the RTTI export gives no vftable at all. Forty-three of the 101 have a
thirteenth slot.

| slot | the base's body | name | how many of the 101 keep it |
| --- | --- | --- | --- |
| 0 | `0x59C540` | **`~CEffect`**, the virtual deleting destructor | 74 (9 distinct bodies) |
| 1 | `0x5BB10` | `CPersistent::Save` *(recorded)* | 101 |
| 2 | `0x20CD50` | `CPersistent::SaveContents`, the folded empty one | 101 |
| 3 | `0x67C050` | `CPersistent::Load` *(recorded)* | 100 — `CAddAIStrategyEffect` overrides it |
| 4 | `0x599CA0` | `CEffect::LoadKey` *(recorded)* | 74 (16 distinct) |
| 5 | `0x6BF890` | `CPersistent::AfterLoad`, the folded empty one | 101 |
| 6 | `0x16000` | **`GetKeywordToken`** | **101 — nobody overrides it** |
| 7 | `0x15FF0` | `CEffect::TakeScalarValue` *(recorded)*, `ret 0x104` | 28 (18 distinct) |
| 8 | `0x59C710` | **`GetBlockText`** | 87 (15 distinct) |
| 9 | `0x5B0ED0` | **`GetText`** | 24 (78 distinct) |
| 10 | `0x59CB20` | **`GetTargetText`** | 98 (4 distinct) |
| 11 | `0x59C6E0` | **`Execute`** | 2 (100 distinct) |
| 12 | — | introduced by the scalar middles; **not read** | `0x59CB90` ×11, `0x59D4F0` ×24, `0x59DC90` ×2, `0x59E220` ×2, `0x5BD110` ×4 |

**Slot 11 is `Execute`** — `confirmed`, and three ways over. Ten `*Effect::Execute` bodies
`project.json` already names all sit at slot 11 of their own class's table
(`CCreateRebelsEffect` `0x59F480`, `CCreateRevoltEffect` `0x5A4DD0`, `CReversedCasusBelliEffect`
`0x5A6B10`, `CAnyNearbyProvinceEffect` `0x5ABA30`, `CAddAIStrategyEffect` `0x5B0E00`,
`CFixedAIStrategyEffect` `0x5B0E90`, `CAddDivisionEffect` `0x5B57F0`, `CLoadOOBEffect` `0x5BBD00`,
`CPracticalEffect` `0x5BDCF0`, `CModifySpiesEffect` `0x5BE130`). All 100 distinct slot-11 bodies in
the family end `ret 8` and all 100 open `push ebp; mov ebp, esp`. And the base's own body is the
self-referential proof: it walks the child list and dispatches slot 11 on each child.

**Slot 9 is `GetText`** — the four `*Effect::GetText` bodies the record holds
(`CKillLeaderEffect` `0x5ADD30`, `CAddDivisionEffect` `0x5B5FA0`, `CLoadOOBEffect` `0x5BBE40`,
`CPracticalEffect` `0x5BDDB0`) all sit at slot 9. `confirmed`.

**Slot 4 is `LoadKey`** — thirteen recorded `*Effect::LoadKey` bodies all sit at slot 4, which also
matches `CPersistent`'s own slot 4. **Slot 3 is `Load`**: `CAddAIStrategyEffect::Load`
(`0x5B0DF0`) is the one override and it is at slot 3.

Note that the RTTI export's `introduces` list for `CEffect` names slots 0, 4, 6, 8, 9 and 11 — it
omits 7 and 10, both of which `CEffect` plainly supplies. That is trap 10 exactly.

### Slot 6 — `GetKeywordToken`, and what `CEffect +0x18` is

The whole body is three bytes of instruction:

    0x416000  8b 41 18   mov eax, dword ptr [ecx + 0x18]
    0x416003  c3         ret

`findings/FINDINGS-script.md` noted this body as "slot 6 means something else on CEffect … a plain
getter" without saying what of. **The field is the `SaveToken` of the keyword that built the
effect**, and it has exactly one writer in the image: the common tail of `CEffect::LoadKey`, at
`0x59B630`,

    if (newEffect != 0) newEffect->+0x18 = key;      // key is LoadKey's own third argument

and `cfg.py --lands-in` shows that every arm of the 91-case switch converges on `0x59B625`, four
instructions above it. A decode of all 8,136 bytes of `CEffect::LoadKey` finds no other non-`esp`
write to a `+0x18`. `confirmed`.

Its one reader is slot 8, which uses it to decide whether two adjacent children belong on the same
tooltip line. So an effect knows which keyword wrote it, and the only thing that knowledge is used
for is formatting.

Trap 4 was checked: `0x16000` is held 101 times, all at slot 6, and every holder is in the
`CEffect` family — inheritance, not folding, so the class-qualified name is right.

### Slots 8, 9 and 10 — the three text virtuals, and how they compose

    Hoi3CString* GetBlockText(Hoi3CString* out, CEventScope* scope, int depth,
                              Hoi3CString group, int unknown)      // slot 8, ret 0x2C
    Hoi3CString* GetText     (Hoi3CString* out, CEventScope* scope,
                              Hoi3CString group, int unknown)      // slot 9, ret 0x28
    Hoi3CString* GetTargetText(Hoi3CString* out, CEventScope* scope) // slot 10, ret 8

(`Hoi3CString` by value is `0x1C`, which is what `scripts/checkSignatures.py` already establishes;
4+4+4+0x1C+4 = 0x2C and 4+4+0x1C+4 = 0x28, and the executable agrees with both.)

`CEffect::GetBlockText` (`0x59C710`, `0x401` bytes, one `ret 0x2C` at `0x59CB0E`) does, in order:

1. appends three spaces (`0x11F39A8`) `depth` times;
2. calls **its own slot 9** with a copy of its `group` argument and its trailing int;
3. walks the children at `this+8`, and for each child calls the **child's slot 10** for a short
   label. While `child->slot6() == nextChild->slot6()` and the label is non-empty it appends
   `§W,§Y ` (`0x11F39AC`, six characters) and keeps collecting;
4. when the run ends it calls that child's **slot 8** with the collected text as its `group`
   argument and the same `depth` and trailing int.

So consecutive effects written with the same keyword are rendered as one comma-separated line, and
the recursion into slot 8 with an identical argument shape is what fixes the signature. The 14
classes that override slot 8 are exactly the scope and iteration effects — the ten `CAny*`/`CRandom*`
forms, `CRegionScopeEffect` and `CContextEffect` — which is the same split as on the trigger side.

`CEffect::GetText` (`0x5B0ED0`) is the base saying nothing: `*out = ""` (the shared empty string at
`0x11B4945`), destroy the `group` string, return `out`. The `group` parameter is what the four
recorded leaf signatures call `unread`; **the base does read it**, if only to free it, and slot 8
is what fills it, so "unread" is a slightly stronger word than the bytes support. Not revised here —
it is a parameter name, and the four entries are otherwise right.

`CEffect::GetTargetText` (slot 10) is a short label for the thing the effect acts on. Only three
classes override it — `CAddCoreEffect` (`0x5A0040`), `CRemCoreEffect` (`0x5A08D0`) and
`CAddSubUnitEffect` (`0x5A8B40`) — and `CAddCoreEffect`'s renders the target province, falling back
from `this->+0x28` to `scope->province (+0x28)` and, with the FROM flag set, to
`scope->from_province (+0x30)`. The name is BiceLib's, from the body and from how slot 8 uses the
result; it is `inferred`.

**The slot-10 base body is deliberately left unnamed as a function.** `0x59CB20` is "set the out
string to empty and return it", and it is held **99** times: 98 at slot 10 of a family table and
once at **slot 2 of `CStatisticsLedger`**, which is not in the family. Naming it for `CEffect`
would put that name on a statistics ledger — trap 4, and the one holder outside the family is
exactly the dangerous kind. The *slot* is named; the *body* is not.

### Slot 0 — the destructor, and where a derived effect's own data starts

`0x59C540` is MSVC's deleting destructor: write `CEffect`'s vftable, free every node of the child
list through the list helper at `0x4B6260`, zero `+8`/`+0xC`/`+0x10`, then
`if (flags & 1) free(this)`, returning `this` in EAX. `ret 4`. 74 holders, all family.

**It does not touch `+0x20`.** The eleven string-valued effects —
`CChangeVariableEffect`, `CClrCountryFlagEffect`, `CClrGlobalFlagEffect`, `CClrProvinceFlagEffect`,
`CLoadOOBEffect`, `CRemoveBrigadeEffect`, `CRenameProvinceEffect`, `CSetCountryFlagEffect`,
`CSetGlobalFlagEffect`, `CSetProvinceFlagEffect`, `CSetVariableEffect` — have their own slot 0 at
`0x59C4E0`, which calls `0x59C5C0` to free the `Hoi3CString` at `+0x20` first. That settles the
layout question `findings/FINDINGS-effecttext.md` left open ("`0x18` to `0x1F` is not established"):

| offset | what |
| --- | --- |
| `+0x0` | vftable |
| `+0x4` | `CPersistent::token` |
| `+0x8`/`+0xC`/`+0x10` | the `CList` of child effects — RTTI's `PAVCEffect::__CList` base; all three destructors zero them together |
| `+0x14` | **not established.** Nothing in the three destructors or in `CEffect::LoadKey` touches it |
| `+0x18` | **`keyword`**, the `SaveToken` slot 6 returns |
| `+0x1C` | **`use_this`** — the value was the word `this` (token 0x377) |
| `+0x1D` | **`use_from`** — the value was the word `from` (token 0x34F) |
| `+0x20` | **the derived class's own data begins** |

The two flag bytes are written at the same offsets by three unrelated slot-7 handlers —
`CIntEffect`'s (`0x59D4A0`), `CValueEffect`'s (`0x59CB50`) and, per `FINDINGS-script.md`, the casus
belli effects' — and are cleared together with a single `mov word ptr [ecx+0x1c], 0`, which is how
we know they are two bools and not one dword. Putting them on `CEffect` rather than on each
subclass is **inference**: siblings' own data would start at the same offset either way. What
settles it is that `CFlagEffect`'s slot 7 puts its string at `+0x20` and not at `+0x1C`, and so
does every other subclass — so `+0x18`..`+0x1F` is base territory and **`CEffect` is `0x20`
bytes**.

## 2. `Execute`'s second argument: nothing reads it

`void __thiscall CEffect::Execute(CEffect* this, CEventScope* scope, int unused)`

Wave 11's agent B established that seven `*Effect::Execute` bodies take a second stack argument the
record was missing. What it *is*: **nothing in the `CEffect` family reads it.**

Of the 100 distinct slot-11 bodies, 11 contain a read of `[ebp+0xC]`, and every one of the 11 is a
scope or iteration effect that pushes the value straight into its own child dispatch and does
nothing else with it — `CEffect` itself, `CMultipleTargetEffect`, `CRegionScopeEffect`, the six
`CAny*` forms, `CRandomCountryEffect`, `CRandomOwnedEffect`, `CRandomNeighborProvinceEffect`,
`CAnyNearbyProvinceEffect`. The other 89 ignore it. And two nodes **replace** it: both
`CRandomEffect::Execute` and `CContextEffect::Execute` pass a literal `0` to their children
whatever they were handed, so even the pass-through is not reliable.

*The positive control for that negative:* the same scan, over the same extents (each bounded by the
next known function entry, so no body runs into its neighbour), finds a read of `[ebp+8]` — the
scope — in **98 of the 100**. The method can see stack-argument reads; 11 of 100 is a result, not a
blind spot.

Two call sites were found:

- `FireEvent` (`0x5C0C80`, recorded) dispatches slot 11 on the event's own effect block at
  `CEvent +0x98` at `0x5C13E2` and passes **0** (`ebx`, zeroed at `0x5C1152`).
- A small register-convention helper at **rva `0x5BF3D0`** — which `image.functionStart` walks
  straight past, because it opens `test edx, edx` (`0x85`) and the previous function ends `ret 8`
  at `0x5BF3CD` with no padding at all: trap 2's third cause. With a negative index it runs the
  event's own block at `+0x98` with **0**; otherwise it indexes a vector of options at
  `+0xD4`/`+0xD8`, takes that option's effect at `option + 0x28`, and passes **the option index**.

So the value is 0 or an event-option index, and no effect can see either. `unused` is what the
executable supports. `CLoadOOBEffect::Execute`'s signature is revised accordingly, from
`int unknown` to `int unused`, with the scan written into its comment.

## 3. `CContextEffect` — the effect side narrows, exactly as the trigger side does

10,686 live instances. Three slots overridden, 8, 9 and 11, and all three call
`CEventScope::MakeScope` (`0x5C1C10`, recorded).

**`CContextEffect::Execute`, rva `0x59E2B0`**, `0x4C` bytes, one `ret 8` at `0x59E2FB`, two `int3`
and then slot 9 at `0x59E300`:

    CEventScope out;                                      // 0x48 bytes on its own stack
    CEventScope::MakeScope(scope, this->spec (+0x20), &out);
    if (out.resolved (+0x3C))
        for (node = this->children_first (+8); node; node = node->next (+8))
            node->payload->Execute(&out, 0);              // slot 11

`MakeScope` copy-constructs the receiver into `out` and then overwrites only `country` and/or
`province`, so **a context effect narrows the scope it was given rather than building a new one** —
the same mechanism, through the same function, as `CContextTrigger`. The ten context tokens and
their meanings are the ones `FINDINGS-triggereval.md` read; nothing about them differs on this
side. **The brief's question — narrow or the opposite — answers "the same".**

Two differences that do matter:

- **An unresolvable context is a silent no-op, not a failure.** On the trigger side
  `CContextTrigger::Evaluate` returns *false*, which fails the whole condition. Here the children
  are simply skipped and the rest of the effect block runs. So `owner = { ... }` on an unowned
  province, or `ally = { ... }` for a country with an empty list, quietly drops its contents.
- **The children are given a literal `0` as `Execute`'s second argument**, not the context's own.

**`CContextEffect::GetBlockText`, rva `0x59E520`**, `0x422` bytes, one `ret 0x2C` at `0x59E93F`:
indents by `depth`, asks its own slot 9 for the context's line, calls `MakeScope` at `0x59E635`,
and walks its children against the **new** scope with the same slot-6 grouping the base does. It
**never reads `out.resolved`**, whereas slots 11 and 9 both do. That is the same asymmetry
`FINDINGS-triggereval.md` found between `CContextTrigger::Evaluate` and its
`CountEvaluation`/`GetBlockText`, reached from the other half of the language: the tooltip
describes children the executor will refuse.

**`CContextEffect::GetText`, rva `0x59E300`**, `ret 0x28`, calls `MakeScope` at `0x59E337` and gates
on `+0x3C` at `0x59E33C`. Not read past the gate.

`FINDINGS-triggereval.md`'s record of `CEventScope::resolved` already names `0x59E2CD` and
`0x59E33C` as "two of the three effect-side callers of `MakeScope`". Both land exactly where this
reading puts them, which is two independent arrivals at the same two instructions, and the third
caller — slot 8 at `0x59E635` — is now identified as the one that does not test the flag.

`CContextEffect`'s spec sits at `+0x20` and is the `0x110`-byte `CEventScopeSpec`, so the object is
`0x130` bytes (against `CContextTrigger`'s `0x150` with the spec at `+0x40`). *That size is
arithmetic from the spec's offset, not an allocation read — `inferred`.*

## 4. The scalar handlers, and where "numbers are thousandths" enters the language

Slot 7 takes the scalar a keyword was written with. `ret 0x104`, because the argument is the
`{ SaveToken token; char text[0x100] }` pair the record spells `CToken`. Four handlers matter:

| rva | holders | what it does with the number |
| --- | --- | --- |
| `0x15FF0` | 28 | `CEffect::TakeScalarValue`, **the whole body is `ret 0x104`** — recorded; `FINDINGS-script.md`'s `modify_spies` story |
| `0x59D4A0` | 21 | **`CIntEffect::TakeScalarValue`** — `+0x20 = atoi(text) * 1000` |
| `0x59CB50` | 11 | **`CValueEffect::TakeScalarValue`** — `+0x20 = ParseThousandths(text)` |
| `0x5A4940` | 7 | the string form — `+0x20 = Hoi3CString(text)`; the six flag effects and `CRenameProvinceEffect` |

All four first clear `use_this`/`use_from` and `+0x20`, then branch on the token: `0x377` (`this`)
sets `+0x1C`, `0x34F` (`from`) sets `+0x1D`, anything else is the value.

**The difference between the two number forms is invisible in the script and matters.**

`CIntEffect`'s is `atoi` and then `imul eax, eax, 0x3e8`. So an integer effect's number is **stored
in thousandths with everything after the decimal point already lost** — `national_unity = 2.5` is 2,
not 2.5. The twenty-one keywords on it include `country_event`, `province_event`, `national_unity`
and `random`.

`CValueEffect`'s goes through **`ParseThousandths` (rva `0x6696A0`)**, which is where the
convention is actually implemented and which ten call sites across the image share. `sscanf(text,
"%i")` for the whole part; with no `.` in the text the answer is `whole * 1000`; with one it copies
**up to three** characters after the dot into a `"000"` template, skips leading zeros, parses that,
negates it when the whole part was negative, and answers `whole * 1000 + fraction`. A fourth
decimal place is silently dropped. So `dissent = 2.5` is 2500 and means 2.5. The eleven keywords on
it are `dissent`, `neutrality`, `manpower`, `change_manpower`, `leadership`, `organisation`,
`popularity`, `revoltrisk`, `warexhaustion`, `officer_pool`, `split_troops`.

*The control for the `×1000`* is that two consumers divide it straight back out, both with the same
`0x10624dd3` + `sar edx, 6` idiom: `CCountryEventEffect::Execute` at `0x5AE4BA`, to recover an event
id, and `CRandomEffect::Execute` at `0x5AF962`, to recover a percentage.

## 5. The effects themselves

### `set_country_flag` / `clr_country_flag`, and the flag machinery was already in the record

`CSetCountryFlagEffect::Execute` **`0x5A4970`** (8,120 live) and `CClrCountryFlagEffect::Execute`
**`0x5A49E0`** (9,057 live, the busiest leaf in the family).

Both take the name out of the `Hoi3CString` at `this+0x20`, find the country as
`CCountryDataBase ([0x1A855A4]) ->+0x16C[scope->country_id (+0x14)]`, and dispatch **slot 2 of the
`CFlags` held by value at `CCountry +0x180`** with it. On a hit the setter writes
`CFlag::is_set (+0x1C) = 1` and the clearer writes `0`.

**`CFlags` slot 2 is rva `0x67DEE0`, which `project.json` already holds as `GuiTypeTree_Find`**, and
slot 6 is `0x4D8A0`, already held as `NameTree_Insert`. Those are the name-tree template the GUI
registries use, shared with `CFlags` and `CVariables`. Three things fall out of that, and all three
were already in the record under GUI-sounding names:

- **A flag lookup is case-insensitive.** `GuiTypeTree_Find` tail-jumps to `TernarySearchTreeFind`
  (`0x67E030`), which the record describes as calling `tolower` on each query byte, and
  `TernarySearchTreeInsert` (`0x4DA70`) lowercases each byte it stores. So
  `set_country_flag = Foo` and `has_country_flag = foo` are the same flag. `confirmed`, by
  composition with a record entry rather than by re-reading the walk.
- **`CFlag::is_set` was named from the reader** (`CFlags::IsFlagSet`, `0x4D620`, via
  `BiceLib/GameClasses/CFlags.hpp`). This is the writer, agreeing — an independent confirmation,
  not a first settlement.
- **A `CFlag` is `0x20` bytes**: `operator new(0x20)` in the creator.

**The asymmetry.** Setting a flag that does not exist **creates** it, through
**`CFlags_AddFlag` (rva `0x4D640`)** — `operator new(0x20)`, `is_set = 1`, assign the name, insert
through slot 6 with the element passed as both name and value (which works because `CFlag::name` is
at offset 0). Clearing a flag that does not exist **does nothing**: there is no call to the creator
anywhere in any of the three `clr_*` bodies. The observable result is the same; the difference is
that a `set` always succeeds and a `clr` on an unknown name is free.

`CFlags_AddFlag` takes **the name in EDI** and the container on the stack, so it is not a
`__thiscall` and carries no `::` (trap 11): `CFlag* __stdcall CFlags_AddFlag(CFlags* flags@stack:4,
const char* name@EDI) @EAX`, `ret 4`.

### `set_global_flag` / `clr_global_flag`, `set_province_flag` / `clr_province_flag` — and two corrections to the record

`CSetGlobalFlagEffect::Execute` `0x5A4C10`, `CClrGlobalFlagEffect::Execute` `0x5A4D00`,
`CSetProvinceFlagEffect::Execute` `0x5A4A30`, `CClrProvinceFlagEffect::Execute` `0x5A4B30`. Same
shape; the only difference is which tree.

The global one dispatches on **`CGameState + 0xC4`**. The province one resolves
`state->provinces_begin (+0xB8C)[scope->province (+0x28)]` and dispatches on
**`CProvince + 0xA0`**. Both differ from what `project.json` says, and both differ the same way:

| the record said | it is | what the record's offset really is |
| --- | --- | --- |
| `CGameState +0xE8 flags void*` | `CGameState +0xC4 flags CFlags` | the `CPersistent` **second base** of that `CFlags`, `0x24` into it |
| `CCurrentGameState +0xE8 flags void*` | `+0xC4` | the same |
| `CMapProvince +0xC4 flags CPersistent*` | `CProvince/CMapProvince +0xA0 flags CFlags` | the same |
| `CProvince +0xC4 flags CPersistent*` | `+0xA0` | the same |

Three constructors settle it, each writing `CFlags`' own vftable and then `CFlags`' `CPersistent`
vftable exactly `0x24` apart — which is the second base `CFlags.hpp` has documented all along:

| constructor | `CFlags` vftable (VA `0x15BB468`) | its `CPersistent` (VA `0x15BB48C`) |
| --- | --- | --- |
| `CGameState::CGameState` (`0x27D070`) | `+0xC4` at `0x27D155` | `+0xE8` at `0x27D15F` |
| `CProvince::CProvince` (`0x94700`) | `+0xA0` at `0x494807` (VA) | `+0xC4` at `0x494811` (VA) |
| `CCountry::CCountry` (`0xC8A40`) | `+0x180` at `0x4C8C71` (VA) | `+0x1A4` at `0x4C8C7B` (VA) |

The third row is the control: `CCountry +0x180 flags CFlags` is what the record *already* says, and
reading it the same way gives the same answer. The old names were right about the **save** — a save
routine does call slot 1 on the `CPersistent` sub-object, which is exactly what the old comment
said — and wrong about the **object**. Nothing in BiceLib reads them: `CCountry.cpp` reads country
flags at `+0x180`, which is correct; `CMapProvince.hpp`'s `flags = 0xC4` is only a comment and
nothing walks a tree from it. Had anything tried, `0xC4 + CTernary::Offsets::root` would have read
`+0xC8` and the root is at `+0xA4`.

### `national_unity`, `neutrality`, `dissent` — three scales settled

`CNationalUnityEffect::Execute` **`0x5B19D0`**: `if (this->+0x20 != 0)
CCountry::ChangeNationalUnity(country, this->+0x20)`.

**`CCountry::ChangeNationalUnity` (rva `0xF8B80`)** is new, and is the only writer of
**`CCountry +0x10B8`**:

    scale = global_modifier.values (+0xDA8) [MODIFIER_NATIONAL_UNITY_EFFECT] + 1000
    this->+0x10B8 += (delta * scale) / 1000;            // through the 64-bit helper 0xB99980
    clamp(this->+0x10B8, 1000, 100000)

So **national unity is in thousandths and is held between 1.0 and 100.0**. The modifier index is the
displacement `0x220` off the values pointer; an entry is 8 bytes (trap 5), so `0x220/8 = 0x44`, and
`scripts/modifierIds.py` names id `0x44` **`MODIFIER_NATIONAL_UNITY_EFFECT`** — the modifier's own
name is the independent evidence for the function's. `CCountry +0xD90 global_modifier` and
`CModifier::values = +0x18` were both already recorded, which is how `+0xDA8` resolves.

`CNeutralityEffect::Execute` **`0x5B9740`** calls the already-recorded `CCountry::ChangeNeutrality`
(`0xFBF80`, writing `CCountry +0xA8C`) with `logHistory = true`. **So a `neutrality` effect writes
an entry into the country's history list, which the daily drift (the same function with `false`)
does not.** `CCountry +0xA8C` has been `neutrality` in `CCountry.hpp` since it was named from the
save key, and was described in `project.json`'s comment on that setter, but was **not recorded as a
field** — trap 14's two-halves problem again. Added, as corroboration rather than first settlement.

`CDissentEffect::Execute` **`0x5BA0B0`** writes `CCountry +0x10B4` inline — `+= value`, floored at
zero, **no upper clamp**, no setter. `+0x10B4` was already named `dissent` from the daily pass
zeroing it for the rebel country; this is a second, unrelated writer agreeing.

All three go through `CValueEffect`/`CIntEffect` slot 7, so: `dissent` and `neutrality` accept
decimals, `national_unity` does not.

### `add_country_modifier` — idempotent, and silent about a typo

`CAddCountryModifierEffect::Execute` **`0x5A38A0`** (4,420 live). Its loader
(`CAddCountryModifierEffect::LoadKey`, recorded, keys `duration` and `name`) puts the resolved
`CStaticModifier*` at `+0x24` and the duration at `+0x20` — **plain `atoi`, no `×1000`, so duration
is in days**, read against `CIntEffect`'s handler which does have the multiply.

Three behaviours a mod author cannot see from the script:

- **If `+0x24` is null the effect does nothing.** That is what an unknown modifier name produces,
  and the loader reports nothing either, so a misspelt `name` is a completely silent no-op.
- **It walks `CCountry +0x648 active_modifiers` and returns if a node's payload already points at
  the same `CStaticModifier`.** So re-applying a modifier a country already has neither stacks it
  nor refreshes its duration. The dedup is `mov edx,[eax]; cmp [edx+8], esi; je <exit>`.
- Otherwise it calls rva `0xDFB90` with the country, the modifier's name (a `Hoi3CString` by value
  out of `CStaticModifier +0x2C`) and the duration. That function is on the frontier.

### `country_event` — it re-tests the target event's own trigger

`CCountryEventEffect::Execute` **`0x5AE3E0`** (4,636 live). Unlike a context effect, it **builds a
fresh `CEventScope`** on its stack (vftable VA `0x15B8AEC`, token `0x18D`) rather than narrowing
one:

| field of the new scope | from |
| --- | --- |
| `random_state`/`seed` | two steps of the **parent** scope's LCG (`0x343FD`/`0x269EC3`), `(r1*r2) & 0x3FFFFFFF`, **written back into the parent** |
| `country_tag`/`country_id` | the parent scope's own country — the event is raised **for** the scope's country |
| `from_country_tag`/`from_country_id` | the parent's **`this_scope (+0x38)`**'s country — so FROM is the originally scoped country, not the immediately enclosing one |
| `from_province` | that `this_scope`'s province instead, when it has no country |
| `this_scope` | copied from the parent |

Then `eventId = this->+0x20 / 1000`, `FindPersistentById({0x28, eventId}, [0x1A857F4])` — the event
registry — and, the part that matters:

    if (event->trigger (+0x30)->Evaluate(&out))      // slot 6
        FireEvent(event, &out);

**A `country_event` pointing at an event whose own `trigger` block is false fires nothing, and says
nothing.** So does one pointing at an id that does not exist. `confirmed`.

The `/1000` is the control on `CIntEffect`'s `×1000`, and the FROM behaviour explains the usual
idiom: inside `any_country = { country_event = X }`, the event's `country` is the iterated country
and its FROM is the original one.

### `random` — twenty instructions, and it advances the scope's randomness whether or not it fires

`CRandomEffect::Execute` **`0x5AF920`**:

    r = LCG(scope->random_state (+8)) twice, state written back;      // 0x343FD / 0x269EC3
    roll = ((r1 >> 16 & 0x7fff) * (r2 >> 16 & 0x7fff)) % 100;
    if (roll < this->chance (+0x20) / 1000)
        for each child: child->Execute(scope, 0);

So `chance` is a whole-number percentage (its loader's switch names exactly one key, `chance`),
`chance = 100` always fires, `chance = 0` never does, the draw is deterministic given the scope's
seed, and **evaluating a `random` block advances the scope's random state either way**. It is the
same two-step recurrence and the same in-place state that the `ally` and `local_enemy` *trigger*
contexts use through the LCG at rva `0x6A2E90`, so effect randomness and trigger randomness share
one stream per scope. And it passes the children a literal `0` as `Execute`'s second argument.

### `remove_brigade` — it matches the regiment's **name**, not its type

`CRemoveBrigadeEffect::Execute` **`0x5BBF10`** (6,881 live). Three `ret 8` exits, at `0x5BC030`,
`0x5BC133` and `0x5BC1DB`; the class's slot 9 begins at `0x5BC1E0`, two bytes past the last, which
is trap 3's cheapest check saying the `ret` really is the end.

It walks the scope country's `units (CCountry +0xBAC)` and, inside each, the unit's
`regiments (CUnit +0x38)`. For each regiment it calls **slot 8** and compares the result for exact
equality with the effect's own `CStringEffect::text (+0x20)` — a `memcmp` over
`min(len_a, len_b)` plus a length test, so it is **case-sensitive**, unlike the flag trees.

Regiment slot 8 is rva `0x6C6C50`, whose whole body returns a copy of the string at `this + 0x68`.
`project.json` already names `CSubUnit +0x68` **`name`, "historical regiment name, saved as
`name`"**. So the string the keyword is written with is matched against the regiment's historical
name. (`0x6C6C50` is held five times, including `CEU3DialogGuiType` slot 8, so it is a fold and
stays unnamed — trap 4.)

On the first match it stops. If the unit holds more than one regiment
(`regiments_count (+0x40) != 1`) it calls the already-recorded `RemoveRegimentFromUnit`
(`0x1BE9A0`). If it holds exactly one, it takes a longer path through the game state, a
localisation render and `ConcurrentQueue_MicroQueuePush` (`0x28DA00`), which is where disbanding
the whole unit and telling the player would live. **That path was not read.**

## 6. Traps hit in this pass

- **Trap 1**, twice, both caught by garbage decodes: `disasm.py` reading `0x5A2DE0` and `0x6696A0`
  as virtual addresses when they are rvas. Both times the symptom was `rcr`/`pop esp` in the first
  instruction, which is trap 9 arriving through trap 1.
- **Trap 2**, three times. `0x5BF3D0` (the event/option effect dispatcher) opens `test edx, edx`,
  which is not in `functionStart`'s prologue set, and the previous function ends `ret 8` on the
  byte before — so `functionStart` answers `0x5BF300` and `retsBefore` returns five `ret`s. The
  padding between `CSetCountryFlagEffect::Execute` and `CClrCountryFlagEffect::Execute` is a
  **single** `int3`, and between `CEffect` slot 10 and the next function likewise, so a scan for a
  run of padding walks through both.
- **Trap 3.** A first pass at the slot-11 survey used "first `ret` followed by `int3`" as the
  extent and reported `CRemCoreEffect`, `CCapitalEffect` and others as reading `[ebp+0xC]` when the
  read was in the *next* slot's body. Re-bounding every extent by the next known function entry
  took the count from a mess to 11 of 100, and the three `ret 0x28`/`ret 0x2C` values that showed
  up in "slot 11" bodies were the tell.
- **Trap 4**, decisively, twice: `0x59CB20` (99 holders, one of them `CStatisticsLedger`) and
  `0x6C6C50` (five holders, one of them `CEU3DialogGuiType`) are both left class-free. And twice
  the other way, where a high count was fine: `0x16000` in 101 slots and `0x59C540` in 74 are one
  family each.
- **Trap 7** throughout — see §4. `national_unity` and `country_event` are integer-only in
  thousandths; `dissent` and `neutrality` take three decimals; `duration` on
  `add_country_modifier` is in plain days.
- **Trap 10**: `CEffect`'s `introduces` list names six slots and it supplies eight.
- **Trap 14**, four times, and three of them paid: `CFlag::is_set` and `CFlags`' whole lookup were
  already in the record (under GUI names) — the flag effects only confirm them; `CCountry +0xA8C`
  was named in `CCountry.hpp` and in a function comment but not as a field; `CSubUnit +0x68` was
  already `name`, which is what makes `remove_brigade`'s reading mean something; and `CGameState`
  and `CMapProvince` both had `flags` recorded at the wrong offset, which only showed up because
  the effects go somewhere else.

## 7. What is not established

- **`CEffect +0x14`.** Untouched by all three destructors and by `CEffect::LoadKey`. Not even
  known to be live.
- **Slot 12.** Forty-three classes have it, five bodies supply it (`0x59CB90` ×11, `0x59D4F0` ×24,
  `0x59DC90` ×2, `0x59E220` ×2, `0x5BD110` ×4), and the grouping is exactly by scalar middle class
  — `CValueEffect`, `CIntEffect`, `CStringEffect` and two more. Not read at all. This is the
  highest-value single item left on the effect side, because it is the one virtual the scalar
  families introduce for themselves.
- **What an unnamed regiment has in `CSubUnit +0x68`**, which is what decides whether
  `remove_brigade = <a subunit type>` can ever match. A decode of `CSubUnit::SetType` (`0x1ABF30`)
  finds no write to `+0x68`, but that is a weaker check than reading a live regiment and the
  mod uses the keyword 6,881 times. **The cheap oracle is the savegame**: a `regiment = { ... }`
  block writes `name`, so grepping a save for the strings the mod's `remove_brigade` lines use
  settles it in one command.
- **`CRemoveBrigadeEffect`'s last-regiment path** (`0x5BC04E` onward) — the game state, the
  localisation render and the queue push. Whether it disbands the unit was not read.
- **`0xDFB90`**, which is what `add_country_modifier` actually calls to attach the modifier, and
  `0x1B4E00`, the static-modifier database's lookup by name.
- **The thirteen other slot-8 overrides** (the `CAny*`/`CRandom*`/`CRegionScope` forms) and the
  **78 slot-9 `GetText` bodies**. None read beyond identifying the slot.
- **`CContextEffect`'s size**, `0x130`, is arithmetic from the spec's offset rather than an
  allocation read.
- **`CEffect::GetTargetText`'s name** is BiceLib's, from three overriders and one use site.
- **The second argument of slot 8 and slot 9's trailing `int`** (`unknown` in both signatures) is
  forwarded by every body read here and consumed by none of them. It is not the same question as
  `Execute`'s second argument and was not pursued.
- **84 of the 111 effects** were not read at all. Named here: the six flag effects,
  `CContextEffect`, `CEffect` itself, `CMultipleTargetEffect`, `CNationalUnityEffect`,
  `CNeutralityEffect`, `CDissentEffect`, `CAddCountryModifierEffect`, `CCountryEventEffect`,
  `CRandomEffect`, `CRemoveBrigadeEffect`. Deliberately skipped, in rough order of how much they
  would repay: `CAddCoreEffect`/`CRemCoreEffect`/`CAddSubUnitEffect` (the three slot-10
  overriders), `CAddProvinceModifierEffect` and `CRemoveCountryModifierEffect` (siblings of one
  already read), the ten `CAny*`/`CRandom*` iteration effects, and
  `CProvinceEventEffect` (`0x5AE780`, the exact twin of `country_event`).

## Frontier

`0x59CB20` (the folded empty-string body at slot 10), `0x59C4E0` + `0x59C5C0` + `0x59C650` (the
string-effect destructors), `0x5A4940` + `0x59E1D0` (the two string scalar handlers), `0x59D4F0` +
`0x59CB90` + `0x59E220` + `0x59DC90` + `0x5BD110` (**slot 12**), `0xDFB90` (attach a country
modifier), `0x1B4E00` (static modifier by name), `0x4D6A0` (the other `CFlags` lookup beside
`CFlags::IsFlagSet`), `0x5A0040` + `0x5A08D0` + `0x5A8B40` (the slot-10 overrides), `0x284CE0` +
`0x28DA00` (the last-regiment path), `0x15F70` (the string compare), `0x8A3880` (`std::string`
teardown), `0x4B6260` (the child-list node freer), `0x5A3940` + `0x5A3170` + `0x5BC1E0` + `0x5AE520`
+ `0x5B1A10` + `0x5B9780` + `0x5BA110` (the slot-9 `GetText` of the effects read here), `0x5AB7B0` +
`0x5ABF30` + `0x5AC370` + `0x5AC810` + `0x5ACAD0` + `0x5ACD20` + `0x5AF9A0` + `0x5AE040` +
`0x5B0000` + `0x5AD440` + `0x5AD100` + `0x5AB320` + `0x5ABC60` (the thirteen other slot-8
overrides), `0x5A3EE0` + `0x5A4600` (`CRemoveCountryModifierEffect`), `0x5AE780`
(`CProvinceEventEffect::Execute`), `0x5BF3D0` (the event/option effect dispatcher — the second
caller of `Execute`), `0x6C6C50` (the folded `+0x68` string getter).

---

## Transcription note

Read and written by wave 12's agent C; transcribed by the session that collected the wave, because
an agent's `Write` is refused for this path.

The agent named the four `flags` field corrections as the riskiest part of its fragment and said to
drop them first if the apply objected. They were **checked before transcription and are right**:
`CGameState::CGameState` at VA `0x67D155` is
`mov dword ptr [ebx + 0xc4], 0x15bb468` and at `0x67D15F` is
`mov dword ptr [ebx + 0xe8], 0x15bb48c` — two vftables exactly `0x24` apart, so `+0xC4` is the
`CFlags` and the record's `+0xE8` was its `CPersistent` second base. The old entries were right
about the save path and wrong about the object, which is why nothing had caught it: the effects go
somewhere the save routine never looks.

Two things the agent found and deliberately left for this session, both acted on:

- **`CCountry::ChangeNeutrality` (`0xFBF80`) has incomplete custom storage** in its recorded
  signature — `this@ESI` is placed and the other two parameters are not, which
  `checkSignatures.py --only 0xFBF80` calls "1 certainly wrong". The agent spelled its own new
  `CCountry::ChangeNationalUnity` completely, so the two would have looked inconsistent.
- **`0x5BF3CD`/`0x5BF3D0`** is a new trap 2 pair whose entry `functionStart` cannot find at all,
  because `0x5BF3D0` opens `test edx, edx` (byte `0x85`) and abuts a `ret 8`. With
  `0x5A49E0`/`0x5A4A30` and `0x59CB4C`/`0x59CB50`, both single-`int3` pairs, these went into
  `TRAPS.md`.

The agent also recommended promoting its `wave12c_sigcheck.py` to `scripts/` as a `--candidates`
flag on `checkSignatures.py`: the existing `--only` can check a signature that is already in
`project.json`, which leaves an agent unable to check its own new entries before submitting them.
That is a real gap in the tooling and is on the queue rather than done.
