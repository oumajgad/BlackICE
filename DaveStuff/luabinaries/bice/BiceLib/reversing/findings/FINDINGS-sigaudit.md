# The signature audit — what `checkSignatures.py` was wrong about, and what the record was

*2026-10-02, wave 10. Covers the 87 disagreements `checkSignatures.py` reported against
1,301 entries. 30 were the tool, 57 were the record. The tool is patched, the records are
corrected in `fragments/merged/sigaudit.json`, and the run now checks 1,321 entries and
reports 64 — which falls to 1 once the fragment lands.*

`FINDINGS-session2.md`'s lesson generalises: **a wrong signature does not fail the check,
it disables it.** Every entry in this file was a check that looked like it was running.

## The tool was wrong three ways, and all three were systematic

**A `__thiscall`'s receiver is in ecx by position, not by being called `this`.** The old
code dropped the first parameter only when it matched `\bthis\b`. Ghidra's rule is
positional. The image settles it: `GuiTypeTree_Find` (rva `0x67DEE0`) is

    push ebp; mov ebp, esp
    cmp dword ptr [ecx + 4], 0
    lea eax, [ecx + 4]
    jne 0xa7def2
    xor eax, eax; pop ebp; ret 4
    pop ebp; jmp 0xa7e030        ; tail call to TernarySearchTreeFind

— ecx is the tree, and its signature spells that parameter `void* tree`. Seven entries were
counted four bytes too large this way: `OwnerAreaCost_NoEnemy` `0x80F50`,
`OwnerAreaCost_Accessible` `0x81000`, `CNavalCombatant::PickTarget` `0x1675D0`,
`CList::FreeNodes` `0x4A30D0`, `GuiTypeTree_Find` `0x67DEE0`, `GuiTypeTree_FindByString`
`0x6ACE70`, `ChecksumFile` `0x6B3D00`.

The exception is why the drop cannot be unconditional: `CPersistent::Load` is `__thiscall`
with `(CParseContext* parse@stack:4)` and no receiver spelled, so an `@` on the first
parameter wins over the convention.

**`__fastcall`'s implicit ecx/edx assignment must not override explicit storage.**
`FINDINGS-attackodds.md` found this and under-counted it: the branch drops the first two
four-byte parameters by size alone, so it swallows a parameter already marked `@stack:` —
but it also swallows a *bare* parameter the author had plainly left on the stack.
`CMap::CollectCacheStampFiles(CMap* map@ESI, std::vector<std::string>* out)` does `ret 4`:
`map` is in esi, `out` is at `[ebp+8]`. Twenty-one entries, twenty of them four bytes short.

The rule that fits all of them: **once a `__fastcall` signature places any parameter, the
convention stops assigning registers by itself.** The findings use `__fastcall` as
"register arguments, callee cleans" and then spell the registers out, so a bare parameter
in such a signature is the stack one.

**`Hoi3CString` by value is `0x1C`.** Its own section below.

**And the `may not be a function start` hint was noise.** All five entries it flagged open
`55 8b ec` with a `ret` tail in the bytes immediately before — real boundaries that
`functionStart` walked past because the previous function abuts with no `int3` (trap 2).
The hint now needs both a `ret` in between *and* a prologue byte at the entry to stay
silent, and it fires once, on the one address that really is mid-function.

## `__cdecl` written where the callee cleans — 21 entries, one word each

The checker's docstring already names this class (`ParseObjectId`, recorded `__cdecl`,
`ret 8`) and nobody had swept it. Swapping the word to `__stdcall` and re-running makes the
recorded parameter list predict the exact `ret` immediate for 21 of the 22 `__cdecl`
disagreements. **The parameter lists were right; the convention word was wrong.**

Four hand checks, to rule out the coincidence of "one parameter in a register plus one
unlisted stack argument reaching the same total": `CSpyPresence::CSpyPresence` `0x12D380`
(the object at `[ebp+8]`, slots +8/+0xC/+0x10, `ret 0xc`), `RunDailyProvincePass` `0x9EAB0`
(`[ebp+8]` → `[ebx+0xd4]`, `ret 4`), `CSetPlanAttributesCommand::CSetPlanAttributesCommand`
`0x1E7710` (seven slots, +8 to +0x20, `ret 0x1c`), `CAIUnit::SetArea` `0x4BA5A0`.

Three of the 21 also needed the rest of their parameters placed, because a signature Ghidra
reads as CUSTOM_STORAGE drops any parameter that does not say where it lives —
`TernarySearchTreeInsert` `0x4DA70`, `ClearIntelFunctor_SerialBody` `0x288170`,
`UpdateIntelFunctor_SerialBody` `0x2883B0`. A fourth needed its name (below).

The full list: `0x4D8E0` `StringKeyNodeInsert` (12), `0x4DA70` `TernarySearchTreeInsert` (12),
`0x89060` `CMap::MapPath` (8), `0x909C0` `ParseIntPair` (8), `0x9EAB0` `RunDailyProvincePass` (4),
`0x9F3E0` `RebuildProvinceModifierValues` (4), `0xB9D60` `RunDailyRebelFactionPass` (4),
`0xDD4D0` `AreaSupplyAndFuelHeadroom` (16), `0x12D380`/`0x12E3A0`/`0x12EBE0`/`0x12FD40` the four
`CSpyPresence` bodies (12 each), `0x1878C0` `COrder::OrderReturnToBase` (4), `0x1E7710` (28),
`0x1E90B0` (16), `0x1E95B0` (16), `0x288170`/`0x2883B0` the two TBB serial bodies (4),
`0x28DB20` `ConcurrentQueue_TryPop` (8), `0x4BA5A0` `CAIUnit::SetArea` (8), `0x67DF60`
`CGui_LoadGuiTypes` (12).

## The register written as a comment — 5 entries

`/*ecx*/` and `/*eax*/` are comments. Ghidra reads the parameter as a stack one and so does
`checkSignatures.py`, so the storage never reaches the database and the receiver is counted
twice. `GetProvinceRawRevoltRisk` `0xA40E0` is the whole argument in three instructions:

    mov edx, dword ptr [ecx + 0x328]
    mov dword ptr [eax], edx
    ret

Both arguments are in registers, the `ret` is bare, and the record predicted 8. Also
`GetMobilizeUndergroundsAvailability` `0x10AFD0`, `CreateRebelBrigadesInProvince` `0xC1160`,
`FindRebelFactionByObjectId` `0x286C10`, `FindRebelFactionForProvince` `0x286CF0`. Write
`@ECX` / `@EAX`; the comment form is invisible to everything that matters.

## The effect `Execute` family takes two stack arguments

Seven `*Effect::Execute` bodies were recorded `(this, CEventScope* scope)` and all seven
`ret 8`. ecx is the receiver in every one — `CAddAIStrategyEffect::Execute` `0x5B0E00` does
`mov edi, ecx; lea ecx, [edi+0x20]`, `CFixedAIStrategyEffect::Execute` `0x5B0E90` does
`mov cl, byte ptr [ecx+0x20]` — and the scope arrives at `[ebp+8]`. The second dword is
often never read, which is why only the `ret` can see it.

The spelling comes from the family's own record: `CLoadOOBEffect::Execute` (`0x5BBD00`)
already carries `(this, CEventScope* scope, int unknown)` and agrees with its `ret`. So one
sibling had it right and seven were written from the shorter shape.

`0x5A6B10`, `0x5ABA30`, `0x5B0E00`, `0x5B0E90`, `0x5B57F0`, `0x5BDCF0`, `0x5BE130`.

## A `Hoi3CString` passed by value is `0x1C`, not `0x18`

`project.json`'s struct record, its comment and `checkSignatures.KNOWN` all said `0x18` —
`char[16]` + `length` + `maxLength`, "the three fields, with nothing after them". The type
is four bytes larger than that: there is a fourth dword at `+0x18` inside `sizeof`.

**The decisive evidence was already in the repository, on the C++ side.**
`BiceLib/GameClasses/CTrait.hpp` records `CTrait +0xE8` as a `Hoi3CString[16]` with
`EFFECT_TYPE_STRIDE = 0x1C` and checks it as `0xE8 + 16 * 0x1C == 0x2A8`. That is an
**array**, not a run of class members, and an array's elements are contiguous at `sizeof`
intervals — so the stride *is* the size, whatever the fourth dword turns out to be. The
header's own note, "a string is `0x18` bytes and the stride is `0x1C`, so four bytes go
spare", describes something an array cannot do. This is trap 14 exactly: the header had
measured the right number, and the `project.json` comment cites that very line as evidence
for the wrong one.

Corroborating, from the layouts the record already holds: four classes put a **named**
non-string field at exactly `string + 0x1C` with nothing in the gap — `CMessageVariable`
(`key` 0x0, `value` 0x1C, `previous` 0x38, size 0x44), `GuiTooltipText` (0x0, 0x1C, 0x38,
then `int number` at 0x54), `CTechnologyCategory` (0x8, 0x24, 0x40, then `int index` at
0x5C), `CBuilding` (`name` 0x1C, `displayName` 0x38, then `int index` at 0x54). Nine classes
show consecutive strings 0x1C apart; none shows 0x18. The layout is 4-aligned, so MSVC
inserts nothing between two of them.

And two frames that the 0x1C reading explains exactly while 0x18 needs an invented unused
dword: `CTerrain::CTerrain` `0xAD7E0` (`ret 0x1C`, reads +8 and +0x1C — the string's
`maxLength` at object offset 0x14) and `AppendStatisticsSample` `0x1F3B90` (`ret 0x28`,
collection at +8, string at +0xC, value at +0x28, year at +0x2C; `0xC + 0x1C = 0x28`, and
`+0x24` — the string's fourth dword — is the only slot never read).

**What the fourth dword is, is not established.** An allocator member of MSVC's
`_String_val` would account for it, and that is the explanation the reading agent proposed.
But `CTrait.hpp` read those four bytes **live** across its `Hoi3CString[16]` and found
"fragments of the parser's own buffer — `"ds ="`, `"  pl"` — zero only where the heap
happened to be", with nothing writing them. That fits **trailing padding** at least as well
as an allocator. The record therefore carries it as `unused_tail` with the question left
open, because the size is what the signatures need and the size holds either way. *What
would show the name wrong:* anything at all reading the dword.

**Why the old reading looked settled, and what was wrong with it.** It rested on
`CKillLeaderEffect::GetText` and `CLoadOOBEffect::GetText` doing `ret 40` "against a sibling
shape of 16", the sibling being `CAndTrigger::GetText`. That subtracts a `CTrigger`'s
virtual from a `CEffect`'s — different hierarchies, different signatures — so it never
established the 24. The record's own comment admits `CBuilding::CBuilding` cannot tell the
two apart, and that is the tell: `4 + 24 + 4 + 4` and `4 + 28 + 4` both reach its `ret 36`,
and the difference is whether `int unread` is an argument or the string's fourth dword.

**Consequences.** Five records change, and three invented parameters go away:
`CKillLeaderEffect::GetText` `0x5ADD30` and `CLoadOOBEffect::GetText` `0x5BBE40` each shed
one trailing `int`; `CAddDivisionEffect::GetText` `0x5B5FA0` and `CPracticalEffect::GetText`
`0x5BDDB0` had no parameters at all against a `ret 40` and gain the family shape — all four
read the same three frame slots (+8, +0x10, +0x24) and all four `ret 0x28`;
`CBuilding::CBuilding` `0xB6320` loses `int unread`.

**On the C++ side**, `BiceLib/HoiDataStructures.hpp` has `StringOffsets::SIZE = 0x18` and a
three-member `struct Hoi3CString`. Nothing uses `SIZE` and `CTrait.hpp` hardcodes `0x1C`, so
nothing is broken today — but any new code that strides an array of strings by
`sizeof(Hoi3CString)` will be off by four per element.

## `CCountryTag` by value is 8 bytes, and two records count its `id` twice

`CCountryTag` was unsized in `checkSignatures.KNOWN`, which skipped 16 entries on that
parameter alone. `project.json`'s own struct record says `char tag[4]; int id`, size 0x8, and
the findings corroborate it wherever one is passed as two words (`CTheatre::CTheatre`,
`CSendExpeditionCommand::CSendExpeditionCommand`). Sizing it took the run from 1301 entries
checked to 1321: 18 of the 20 agree with their own `ret`, and the two that do not are the
same mistake twice —

- `CAIAgent::CAIAgent` `0x49C720`, recorded `(this@EAX, CCountryTag tag, int countryId)`
- `CAIStrategy::IsWarCandidate` `0x4A9A30`, recorded `(this@EDI, CCountryTag tag, int id)`

Both `ret 8` with exactly +8 and +0xC read. The tag *is* the whole argument list and the
trailing `int` is its own `id` half written a second time. A wrong size here would have
arrived as 20 new disagreements rather than 2, which is the same argument the `SaveToken`
row in `KNOWN` rests on.

`CCountry::CanBreakNap` `0xEFCA0` is the same shape from the other side: `[ecx+0xe28]` makes
ecx the receiver, it `ret 8`, and **the only frame slot it reads is `+0xC`** — the tag's
`id`. Recorded as `int otherCountryId`; it is a `CCountryTag` by value, of which the body
uses half.

## Receivers and registers the bytes settle

- **`ProvinceEdgeVector::push_back` `0xACCA0`** — `record` is in **eax**, not on the stack.
  The vector comes through edi (`[edi]`, `[edi+4]`, `[edi+8]`), five dwords are copied from
  eax, `add dword ptr [edi+4], 0x14` advances the end, and both exits are a **bare `ret`**.
  A `ProvinceEdge` is 0x14 bytes.
- **`CFixedWindow::AttachChild` `0x6C2F90`** — the receiver was not spelled at all.
  `mov esi, ecx` then `[esi+0x30c]`, `[esi+0x2fc]`, `[esi+0x78]`; name at `[ebp+8]`, child
  at `[ebp+0xc]`; `ret 8`.
- **`ProcessAITradeFunctor::operator()` `0x27B160`** — receiver in **eax** (`[eax+4]`,
  `[eax]`), *and* a stack argument at `[ebp+8]`, *and* the signature named the body
  `ProcessAITradeFunctor_body` while the entry is called `ProcessAITradeFunctor::operator()`.
  The two sibling TBB bodies take their `blocked_range` the same way.
- **`CCountry::CollectCountriesWeCanOperateIn` `0xEE110`** — ecx is never read before being
  written; +8 and +0xC are both stack and `[ebp+0xC]` is initialised as the out list (writes
  at +0, +4, +8 and a byte at +0xC). `__stdcall`, not `__thiscall`.
- **`CTheatre::CTheatre` `0xAEFB0`** — the object arrives in **eax**: the vftable and the
  first fields are written through it (`mov [eax], 0x15c3ae4`, `mov [eax+4], 0x18d`). `ret 8`,
  not the 12 three stack arguments would need.
- **`CPureRevoltRiskTrigger::Evaluate` `0x5E6940`** (`mov [ebp-0x10], ecx`) and
  **`CRevoltRiskTrigger::Evaluate` `0x5E7590`** (`mov ebx, ecx`) are `__thiscall`, recorded
  `__stdcall`; the scope is at `[ebp+8]` and both `ret 4`.
- **`CreateRebelsForFaction` `0xBAA20`** — `actor` travels in **ecx**, which is why it
  cleans 20 and not 24. The call site at `0x4C134A`:

      mov ecx, [ebp+0x10]; mov edx, [ebp+0xc]; push ecx
      mov ecx, [ebp+0x14]              ; <- reloaded and left live across the call
      push edx; push edi; lea eax, [esp+0x1c]; push eax; push esi
      call 0x4baa20

  Five pushes, and the ecx it reloads is its own caller's `+0x14` — which is
  `CreateRebelBrigadesInProvince`'s `actor`. Callee side: `ret 0x14`, frame slots +8 to +0x18.
- **`CHourlyTickCommand::Clone` `0x2DA430`** — no parameters recorded, against `ret 0x1C`.
  It takes one `Hoi3CString` **by value**: the inlined string destructor at the tail,
  `cmp dword ptr [ebp+0x1c], 0x10; jb ...; mov eax, [ebp+8]; push eax`, reads capacity at
  `+8+0x14` and the pointer at `+8+0`, so the object starts at `+8` and `0x1C` is exactly one
  string. `vtable.py --holding` says the body is `CHourlyTickCommand` slot 13 and nothing
  else's. A `Clone` taking a string by value is odd; the signature is now right about the
  stack, the name may still want a look.

## One further stack argument, type not established — 12 entries

In each the `ret` immediate is four or eight bytes larger than the recorded list and the
extra dword is often never read, so only the `ret` can see it. Recorded as `int unknown`
(the spelling the record already uses) and marked `inferred`: `CCombatant::AddTerrainModifier`
`0x165530`, `CLandCombatant::AddAssaultModifiers` `0x169750`, `CEspionageView::BuildTooltip`
`0x21FCD0`, `CCombatMember::BuildTooltip` `0x2A9E90`, `CProductionView::BuildTooltip`
`0x3FFD30`, `RunSupplyAndConvoyIterations` `0x278AB0`, `CEU3Application::Run` `0x690F90`
(two of them), the three `CommandChannel::Pump` bodies `0x7352C0`/`0x73A8C0`/`0x73BF90`,
`CDistributeDiplomacy::GetNeedTooltip` `0x11E8E0`, and `CCountry::CanBreakNap` `0xEFCA0`.

## Phantom parameters — 4 entries

`CDistributeReinforcement::GetNeedTooltip` `0x11CAD0` and `CDistributeUpgrade::GetNeedTooltip`
`0x11DBB0` both read `[ecx+0x18]`, take one `out` at `[ebp+8]` and `ret 4` — their
`int unknown1, int unknown2` do not exist. And `CAIAgent::CAIAgent` `0x49C720` /
`CAIStrategy::IsWarCandidate` `0x4A9A30` double-count the tag's `id`, as above.

The three `GetNeedTooltip` records look to have had their parameter lists **crossed**: the two
`int unknown`s written on Reinforcement and Upgrade (which `ret 4`) belong on Diplomacy
(which `ret 0xc`).

## `CMap::MapPath` is not a `CMap` member

`0x89060` was recorded `std::string* __cdecl CMap::MapPath(std::string* out, std::string*
name)` against a `ret 8`. The convention is the smaller error. There is no receiver at all:
the function reads the path registry out of the global at `0x1A85558` (rva `0x1685558`) +
0x2CC — which the entry's own comment already records — takes `out` at `[ebp+8]` and `name`
at `[ebp+0xc]`, and touches ecx only as a pointer into its own frame
(`lea ecx, [ebp-0xa0]`). `ret 8` leaves no room for a third argument.

A `Class::` qualifier on a function that takes no such receiver makes Ghidra invent a `this`
and shift every argument along (trap 11), and that is precisely what the `ret` check cannot
see — the arithmetic is right either way. Recorded here as a free `MapPath`.

**The same shape, left open on purpose.** `CNavalCombatant::PickTarget` `0x1675D0` takes its
receiver in ecx and that receiver is a **`CSubUnit`**: `mov edi, ecx`, then `[edi+0xb0]` —
`CSubUnit::unit_ptr` — dereferenced to `[eax+0x290]` and `[eax+0x28c]`, which are
`CUnit::expeditionary_owner_id` and `CUnit::expeditionary_owner`. The record's first
parameter `CSubUnit* attacker` is the receiver, so Ghidra will type `this` as a
`CNavalCombatant` and misread every field access through it. Its `ret` now agrees and
`carriesClass` passes, so **nothing will flag it again**; it needs a naming decision rather
than an arithmetic fix.

## Two new disagreements, and both are record defects the old tool was hiding

The patch is more sensitive here, not less. `CFixedWindow::AttachChild` `0x6C2F90` never
spelled its receiver and the old name-matching rule got 8 by accident; and
`ProvinceEdgeVector::push_back` `0xACCA0` puts `record` in eax against a bare `ret`.

## One disagreement left, and it is the record's address

`CreateMapBinCacheOwner` `0x450AB0` is **not a function**. It is the `call 0x486F10` at
`0x850AB0`, inside the function that starts at rva `0x450520`, with no `ret` in between and
`push eax` immediately before it:

    0x00850A9A  push 0x48
    0x00850A9C  call 0xb9602f          ; operator new
    ...
    0x00850AAF  push eax
    0x00850AB0  call 0x486f10          ; <- the recorded "function"

The entry's own comment says "the only caller of 0x486F10, the constructor that builds the
`<dir>/cache/map.bin` path" — so the author knew what it was and recorded the call site
instead of the caller's entry. Three ways out and none of them is obvious: re-point to rva
`0x450520` (a large loader that may not deserve the name), re-point to rva `0x86F10` (the
constructor, which is what the name describes), or drop the entry. Left for a hand decision.

## `likely` in `mergeFindings.py`: the recommendation is **no**

`project.json` holds **219 `likely` address entries**, against 1,784 `confirmed` and 85
`inferred`. Not a handful. No struct field carries a confidence at all.

**Accepting the word would change nothing downstream.** `buildFindings.py` line 303 is
`CONFIDENCE = {"confirmed": "CERTAIN", "inferred": "TENTATIVE"}` and line 856 is
`conf = CONFIDENCE.get(a["confidence"], "TENTATIVE")`. So all 219 `likely`s already apply
cleanly and land in Ghidra as **TENTATIVE**, indistinguishable from `inferred`. The
vocabulary has three words and the pipeline has two buckets.

**It would remove the only check on the word.** That `.get(..., "TENTATIVE")` default means a
*typo* also silently becomes TENTATIVE. `TRAPS.md` closes by listing `read`, `partial` and
`inference` as words written by mistake and caught by the validator. The validator catches
them precisely because its list is short.

So the asymmetry points the other way from how the wave 10 plan framed it: the validator is
not the odd one out, it is the only strict part of the chain, and `project.json`, `TRAPS.md`,
`CLAUDE.md` and `fragments/README.md` are four documents describing a distinction nothing
consumes.

In order of preference:

- **(a) Leave `CONFIDENCES` alone.** Drop the third word from the three documents, keep
  `fragments/README.md`'s existing advice ("write `inferred` and say 'likely, and why' in the
  comment"), and convert the 219 in one scripted pass — they all become `inferred`, since that
  is already what they mean to Ghidra.
- **(b) If the three-word vocabulary is wanted, change both ends together**:
  `CONFIDENCES = ("confirmed", "likely", "inferred")` *and* an explicit
  `CONFIDENCE = {"confirmed": "CERTAIN", "likely": "TENTATIVE", "inferred": "TENTATIVE"}` with
  the `.get` default removed so a misspelling raises instead of degrading quietly.

Adding the word to the validator **alone** is the one option to argue against: it legitimises a
distinction that is discarded three steps later, and it widens the only net that catches a typo.

## The patch to `scripts/checkSignatures.py`

Five changes, each with the evidence written into the comment next to it:

1. `expected()`, `__thiscall` branch — receiver by position, not by the word `this`; an `@` on
   the first parameter wins.
2. `expected()`, `__fastcall` branch — the implicit ecx/edx assignment applies only where the
   signature places nothing.
3. `KNOWN["hoi3cstring"]` `0x18` → `0x1C`, with the old reasoning rebutted rather than deleted.
4. `KNOWN["ccountrytag"] = 8` added — new, and it is what took the run from 1301 checked to 1321.
5. `main()`, the function-start hint — now needs both a `ret` in between and a prologue byte to
   stay silent.

**Deliberately not made lenient.** Of the 87, 23 net moved to "agrees"; 28 were fixed outright
and 5 new ones appeared because the fixed rules can now see defects the old ones papered over.
The three sections the `ret` cannot see (`never mentions their class`, `custom storage
incomplete`, `no signature at all`) are untouched at 31/176/55.

An "unpredictable" bucket was tried and thrown away: modelling Ghidra's actual rule resolves
every mixed case correctly, and `storageComplaint` already lists all 176, so a second bucket
would have double-reported while hiding 20 predictions that are in fact right.

## The fragment, and two notes about `revises`

`fragments/merged/sigaudit.json` holds **63 revisions** (38 `confirmed`, 25 `inferred`) and
**1 struct field**.

**The wave 10 plan's premise that a wrong signature needs a hand edit is out of date.**
`mergeFindings.py` has a **`revises`** key for exactly this: an entry carrying
`"revises": "<why>"` that changes something already recorded is accepted, and `land()` replaces
the whole record. Without it you get "project.json already records that, differently — say
revises, with why".

Two traps in using it, both worth passing on:

- A revision rebuilds the record from `ADDRESS_KEYS` alone, so a missing `comment` or `source`
  is **silently blanked**. Each entry here therefore carries the existing `kind`, `name`,
  `comment` and `source` verbatim, with one sentence appended, and `locals` carried through
  where present. The fragment was generated from `project.json` rather than written by hand for
  this reason.
- `slots_noted` is needed on any fragment that revises virtuals, or every owning class is
  demanded under `vftable_slots`; and a **rename** needs `replaces` as well as `revises`, or
  `existing()` cannot find the old record.

## Hand edits — two

1. **`project.json`, struct `Hoi3CString`: `"size": "0x18"` → `"0x1C"`.** `FIELD_KEYS` has no
   `size`, so a fragment cannot change it. Its long comment also argues the 0x18 case at length
   and needs replacing. The field at `+0x18` does land from the fragment.
2. **`0x450AB0 CreateMapBinCacheOwner`** — the address decision above.

## What is not established

- The second argument of the seven effect `Execute` bodies, and of the five
  `BuildTooltip`/`AddModifier` bodies in the same shape. The `ret` establishes that it exists
  and is four bytes; nothing here names it. `slotcalls.py 11` is 1,056 sites in 666 functions,
  so the slot number is no help — it wants the effect-list runner found directly.
- Which of the three `GetNeedTooltip` records is the odd one. Reinforcement `0x11CAD0` and
  Upgrade `0x11DBB0` take one stack argument and `ret 4`; Diplomacy `0x11E8E0` takes three and
  `ret 0xc`. The two `int unknown`s were written on the first two and belong on the third, which
  looks like the three lists were crossed — but a virtual's slot ought to give all three the
  same shape, so one of the three may not be the virtual it is filed as.
- Whether `CHourlyTickCommand::Clone` is a `Clone`.
- What the fourth dword of `Hoi3CString` is, as above.
- The 55 member functions with no signature at all, and the 114 whose custom storage is
  certainly incomplete. Neither is a `ret` question and neither is touched here.

---

## Transcription note

Read and written by wave 10's agent B; transcribed by the session that collected the wave,
because an agent's `Write` is refused for this path. The string-size claim was spot-checked
independently before transcription and holds in its decisive form: `CTrait.hpp` line 111 has
`EFFECT_TYPE_STRIDE = 0x1C` with the comment `0xE8 + 16 * 0x1C == 0x2A8` on a
`Hoi3CString[16]`, and `project.json`'s struct record does say `size: 0x18` with three fields.
`BiceLib/HoiDataStructures.hpp:69` does have `SIZE = 0x18`.

**One change made in transcription.** The fragment recorded the new field at `+0x18` as
`allocator`, with the comment stating it is MSVC's `_String_val` allocator member. That is an
explanation, not a reading, and `CTrait.hpp`'s own **live** observation of those four bytes —
parser-buffer fragments, nothing writing them — fits trailing padding at least as well. The
field is landed as **`unused_tail`** with the question marked open. The size correction, which
is what the 63 signature revisions rest on, is unaffected: an array's stride is its `sizeof`
whichever the answer is.
