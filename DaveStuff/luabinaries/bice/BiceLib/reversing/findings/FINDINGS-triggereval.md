# The evaluation half of the event script language

The grammar was read (`findings/FINDINGS-script.md`, 152 trigger keywords out of `CTrigger::LoadKey`)
and the tooltips were read (`findings/FINDINGS-guilive.md` and the `GetBlockText` family). This is the
answers: slot 6 on the four composite triggers, the object every one of them is passed, and what it
costs.

Addresses are **rvas** against an image base of `0x400000`, as everywhere in this folder.

## 1. `CTrigger` slot 6 is `_purecall`, so there is no default answer

`CTrigger`'s own slot 6 is VA `0xB961D5`, `_purecall`, already recorded as such. There is no
inherited `Evaluate` anywhere in the family: **every one of the 164 concrete triggers supplies its
own**. A survey of the trigger family's 12-slot tables gives 162 distinct slot-6 bodies for 164
classes, and the only two that share are `CAndTrigger`/`CMTTHModifier` and
`CManpowerTrigger`/`CMaxManpowerGreaterThanTrigger` — both pairs related by inheritance, so neither
is a fold (trap 4). That is why there are 152 keywords and no fallback: an unimplemented condition
would crash rather than default to true.

## 2. `CEventScope` — the spine, now 12 of 14 dwords named

`0x48` bytes (**not `0x38`** — see the hand edits at the end), vftable rva `0x11B8AEC`, base
`CPersistent`. Two sources, and they agree key for key: `CEventScope::SaveContents` (rva `0x5C1690`,
slot 2) and `CEventScope::LoadKey` (rva `0x5C1890`, slot 4, already recorded) handle the same six
tokens and the same six offsets.

| offset | name | from |
| --- | --- | --- |
| `+0x0` | vftable | ctor |
| `+0x4` | `CPersistent::token` = `0x18D` (`none`) | ctor |
| `+0x8` | **`random_state`** | ctor's EDX; the LCG at rva `0x6A2E90` updates it in place |
| `+0xC` | *unnamed* — the ctor's EDX again; no reader found | — |
| `+0x10` | **`country_tag`** `char[4]` | key `country` (0x24D) |
| `+0x14` | `country_id` (already recorded) | key `country` |
| `+0x18` | **`from_country_tag`** `char[4]` | key `from_country` (0x61B) |
| `+0x1C` | **`from_country_id`** | key `from_country` |
| `+0x20` | **`rebel_faction_type`** | key `rebel_faction` (0x644), via `ParseObjectId` |
| `+0x24` | **`rebel_faction_id`** | key `rebel_faction` |
| `+0x28` | **`province`** | key `province` (0x1EE) |
| `+0x2C` | **`seed`** | key `seed` (0x356) — the only key written unconditionally |
| `+0x30` | **`from_province`** | key `from_province` (0x61C) |
| `+0x34` | `days_in_month` (already recorded) | neither save nor load |
| `+0x38` | **`this_scope`** `CEventScope*` | ctor sets it to `this` |
| `+0x3C` | **`resolved`** `bool` | ctor = 1 |
| `+0x3D` | **`unknown_context`** `bool` | ctor = 0 |
| `+0x40` | *unnamed* — the ctor's one stack argument, 0 at 28 of 29 call sites | — |
| `+0x44` | *unnamed* — zeroed by the ctor, no other writer found | — |

Three of these are the ones that matter.

**`this_scope` (+0x38).** The constructor writes `mov [eax+0x38], eax`, and the copy constructor
copies the pointer **verbatim**. So `this_scope` always points at the scope the event was raised
with, however deeply contexts have been nested, and it is never null. Two readers: the `this`
context (token 0x377) and `EventScope_GetCountryTag` (rva `0x5C1A40`), which answers "which country
is this scope about" — the scope's country if it has one, otherwise the owner of its province —
and reaches the scope *only* through `+0x38`.

**`random_state` (+0x8).** The constructor seeds it from EDX, the same value it writes to `seed`
(+0x2C); at two of the call sites inspected (`0xB9A99`, `0x1769A0`) that value comes straight out
of the generator at rva `0x6A2F80`. The scope resolver passes `&scope->+8` to the LCG at rva
`0x6A2E90` — two steps of MSVC's `rand` recurrence (`0x343FD`/`0x269EC3`), state written back,
returning a 30-bit product. So the `ally` and `local_enemy` contexts are **deterministic given the
seed and advance it as a side effect of being evaluated**. A copy starts wherever the parent had
got to and advances its own copy, so a context does not advance its parent's state.

**`resolved` (+0x3C) and `unknown_context` (+0x3D).** The constructor writes them as one word
(`mov word ptr [eax+0x3c], 1`); the copy constructor copies them as two separate `movzx` bytes,
which is how we know they are two bools. Each has exactly one writer:

- `+0x3D` is set only at rva `0x5C1F01`, the default arm of the resolver's switch, and read in
  exactly **one** place in the image: `CTrigger::LoadKey` at rva `0x5CAE9B`.
- `+0x3C` is cleared only at rva `0x5C1F34`, when the candidate list came up empty. Four readers:
  `CContextTrigger::Evaluate` (`0x5D154D`), `CContextTrigger::WalkChildren` (`0x5D248D`), and two of
  the three effect-side resolver calls (`0x59E2CD`, `0x59E33C`).

## 3. The grammar/evaluation seam, which explains 10,974 `CContextTrigger`s

`FINDINGS-script.md` could place only 2 of `CContextTrigger`'s 153 keys. That is because **its keys
are not in `CTrigger::LoadKey`'s table at all.** In the loader's default arm, at rva `0x5CAE62`:

    spec = EventScopeSpec_Construct(&local, CParseContext + 0x20)   ; 0x5CAE72
    throwaway = CEventScope::CEventScope(&scope, 0, 0)               ; 0x5CAE82
    CEventScope::MakeScope(throwaway, spec, &out)                    ; 0x5CAE96
    if (out.unknown_context == 0)                                    ; 0x5CAE9B
        new CContextTrigger(operator new(0x150), spec)               ; 0x5CAEA6 / 0x5CAED7
    else
        parse error through 'trigger.cpp'                            ; 0x5CAEEE

So an unrecognised trigger key is **speculatively resolved as a scope**, and the resolver's own
"I did not recognise that" flag is what decides between a context block and a parse error. The
complete list of `CContextTrigger` keys is: the ten tokens in the table below, plus any country tag
the country database knows, plus any number.

`EventScopeSpec_Construct` (rva `0x5C1B30`) builds the spec: it copies `0x104` bytes —
`{ SaveToken token; char text[0x100]; }` — then derives `+0x104` = `atoi(text)` when the text is a
number, or `+0x108`/`+0x10C` = `CCountryDataBase::GetTag(text)` when the token is `0xF`. The spec
is `0x110` bytes and lives at `CContextTrigger + 0x40`; `0x40 + 0x110 = 0x150`, the allocation
size, so the spec is the whole of `CContextTrigger`'s own data.

Tokens `0xC` and `0xF` are **not in the compiled token table**, and neither are the other low ids
7, 10, 13, 14, 15 and 19 — they are the lexer's own classes. `0xF` is the one tried as a country
tag and `0xC` the one the resolver answers with the literal province id, so they are the identifier
and number classes. *That part is inference, not read.*

## 4. How `CContextTrigger` rebinds the scope — `CEventScope::MakeScope`, rva `0x5C1C10`

`CEventScope* __thiscall CEventScope::MakeScope(CEventScope* this, void* spec, CEventScope* out)`,
`ret 8`, four `ret 8` exits all restoring the same SEH slot `[esp+0x84]` (trap 3, one function).
Eight callers: `CContextTrigger` slots 6, 9, 10 and 11, `CTrigger::LoadKey`, and `CContextEffect`
slots 8 and 11 (rvas `0x59E2B0`, `0x59E520`).

**It copies the receiver into `out` first**, through `CEventScope::CopyConstruct`. So the new scope
inherits the random state, the seed, `rebel_faction`, both `from_*` fields, `days_in_month` and
`this_scope` unchanged, and only `country` and/or `province` are then overwritten. That one fact is
the whole rebinding mechanism: **a context narrows the scope, it does not build a new one.**

Then: if the spec carried a literal country tag (`+0x10C != 0`) the country is replaced and the
province zeroed — the `GER = { ... }` form, tested **before** the switch. Otherwise a switch on
`spec->token`:

| token | id | what it sets |
| --- | --- | --- |
| (number) | 0xC | `province = spec->+0x104`, `country = "---"` |
| `owner` | 0x1EC | `country` = `g_CMap(0x1A8557C)->+0x2200[province]->owner (+0x32C)`, `province = 0` |
| `controller` | 0x1ED | the same province's `controller (+0x334)`, `province = 0` |
| `from` | 0x34F | `country = from_country (+0x18)`, `province = from_province (+0x30)` |
| `ally` | 0x359 | a **random** entry of the CList at `CCountry +0xF88` — see §7 |
| `this` | 0x377 | the country and province of `this_scope (+0x38)`; returns at once |
| `capital_scope` | 0x3B4 | `province` = `CCountry::acting_capital_province_id (+0xE24)`, `country = "---"` |
| `sea_zone` | 0x3E8 | `province` = `CMapProvince::path_node_ptr (+0xD4) -> +0xA4` (unnamed field), `country = "---"` |
| `local_enemy` | 0x621 | a **random** owner tag among `CMapProvince::units (+0x2B8)` whose `CUnit::combats_count (+0x11C) > 0` and whose `CUnit::owner_id (+0x128)` is not the province's owner id |
| `overlord` | 0x631 | `CCountry::faction_leader_tag (+0xF38)`, `province = 0` |
| anything else | — | `unknown_context = 1`, then falls into the empty-candidate arm |

**The control for the token decoding** is that nine of the ten tokens name a field the record
already held, under a name that matches: `owner`/`controller` are `CMapProvince +0x32C`/`+0x334`,
`capital_scope` is `acting_capital_province_id`, `overlord` is `faction_leader_tag`, `local_enemy`
walks `CMapProvince::units` testing `CUnit::combats_count` and `CUnit::owner_id`, `from` reads the
two `from_*` fields `CEventScope::LoadKey` loads under those names. Nine independent agreements.

`overlord` is worth noting for the mod side: it resolves to the **faction leader**, which is what
`CCountry +0xF38` is.

## 5. Slot 6 for the four composites

All four are the same loop over `children_first (+0x8)` — payload at `node+0`, next at `node+8` —
dispatching `[vftable+0x18]`. **None of them reads any field but `+0x8`** (and `+0x40` for the
context), allocates nothing in the common case, and holds nothing between calls.

| class | rva | empty child list | otherwise |
| --- | --- | --- | --- |
| `CAndTrigger::Evaluate` | `0x5D06E0` | **true** | false at the first child that answers 0 |
| `COrTrigger::Evaluate` | `0x5D0D00` | **false** | true at the first child that answers 1 |
| `CNotTrigger::Evaluate` | `0x5D12C0` | **true** | false at the first child that answers 1 — so it is a **NOR**, and plain negation only because the scripts write one child |
| `CContextTrigger::Evaluate` | `0x5D1530` | true (after the gate) | `MakeScope`, then `false` if `!resolved`, then AND over the children with the new scope |

A detail that is in the bytes rather than inferred: the AND tests `test al,al / je`, the OR and the
NOT test `cmp al,1 / je`. For a bool that is the same question.

**An unresolvable context is false, not an error.** `owner = { ... }` on an unowned province, or
`ally = { ... }` for a country whose list is empty, makes the whole block fail silently.

**Trap 2, three times.** `image.functionStart` is wrong about three of these entries and the
vftables are what settle them:

- `0x5D06E0` → answers `0x5D06C0`: `CTrigger::CountEvaluation` ends `ret 0xC` at `0x5D06DD` with
  **no padding at all**. (The brief this agent was given said "clean boundaries on both sides". It is
  right about the upper boundary — 11 `int3`, then `GetBlockText` at `0x5D0720` — and **wrong about
  the lower one**, which was verified only on the upper side when the plan was written.)
- `0x5D0D00` → answers `0x5D0CD0`: `CAndTrigger::CountEvaluation` ends `ret 0xC` at `0x5D0CFD`,
  no padding.
- `0x5D0680` → answers `0x5D0663`, which is *inside an instruction*: the previous function ends
  `ret 0x10` at `0x5D067D..0x5D067F` and this prologue is the very next byte, so the backward walk
  never saw a boundary at all. `retsBefore(0x9D0680, 0x9D06C0)` returns exactly one `ret`, and
  `CTrigger`'s RTTI `introduces` gives slot 10 as `0x9D0680`.

## 6. Slots 10 and 11 — and the answer on caching

**There is no cache. Anywhere.**

- No composite `Evaluate` reads any field but the child-list head. There is no memo, no dirty bit,
  no tick stamp.
- `CTrigger +0x1C` and `+0x2C` *are* two `0x10`-byte containers, built by the base constructor
  through `__ehvec_ctor` (rva `0x796170`, element size `0x10`, count 2, ctor rva `0x9DB0`,
  destructor rva `0xC480` which frees a linked list). **None of the four `Evaluate` bodies touches
  either**, so they are not an evaluation cache. What does read them was not found; see §8.
- Slot 11, `CountEvaluation`, is a **second complete evaluation**, not a cached reading of the
  first. `CTrigger::CountEvaluation` (rva `0x5D06C0`) is `if (this->Evaluate(scope)) ++*passed;
  ++*total;` — it calls its *own* slot 6. 153 of the 164 classes inherit it.
- Slot 10, `WalkChildren`, is not an evaluation helper at all. `CExistsTrigger`'s override
  (`0x5DABA0`) is `if (polarity && this->Evaluate(scope)) collect(collector, weight, this->+0x44,
  this->+0x48)` through rva `0x4A5270`, which inserts into a map owned by a **`CAIStrategy`** (its
  destructor is rva `0x4A3880`). So slot 10 is the AI's **weighted attribution walk**: which
  country or province a condition argues for, and how strongly. One of the 164 classes overrides it
  with a deliberate no-op, `CUnitsInProvinceTrigger`, pointing at the already-recorded folded stub
  `DoNothing_4Args` (rva `0x44A610`).

**Slot 10's recorded signature is wrong in its argument order.** The count is right — `ret 0x10`,
four stack arguments — but the scope is the **second**, not the first, and the last two are not
counters:

    void __thiscall CTrigger::WalkChildren(CTrigger* this, void* collector,
                                           CEventScope* scope, bool polarity, int weight)

Fixed by three bodies. `CContextTrigger::WalkChildren` (`0x5D2470`) rebinds `[ebp+0xC]` and passes
`[ebp+8]` through untouched. `COrTrigger::WalkChildren` (`0x5D1270`) divides `[ebp+0x14]` by
`children_count (+0x10)` and clamps to ≥1 — nothing but a weight is divided among branches.
`CNotTrigger::WalkChildren` (`0x5D1340`) reads `[ebp+0x10]` as a byte, compares it with zero and
passes the result on — a polarity bool it inverts, so under an odd number of NOTs a satisfied
condition is *not* reported to the collector.

(`COrTrigger::WalkChildren` divides by `children_count` **without testing it for zero**. An
`or = { }` with no children would fault here; the loader never builds one, so this is a note about
the body, not a reachable bug.)

The slot-11 overrides give the tooltip's "n of m met" its arithmetic:

| class | rva | what it counts |
| --- | --- | --- |
| `CTrigger` | `0x5D06C0` | itself: `+1` to total, `+1` to passed if its own slot 6 is true |
| `CAndTrigger` | `0x5D0CD0` | recurses into children's **slot 11**; 8 holders, all deriving from `CAndTrigger` |
| `COrTrigger` | `0x5D1230` | `+1` to total whatever the block holds; `+1` to passed if any branch's **slot 6** is true |
| `CNotTrigger` | `0x5D1380` | counts children into private locals, then adds `innerTotal - innerPassed` to passed and `innerTotal` to total — a NOT reports `m - n` of `m` |
| `CContextTrigger` | `0x5D24C0` | rebinds the scope, then children's slot 11 |

**`CContextTrigger::CountEvaluation` does not test `resolved`**, and neither does
`CContextTrigger::GetBlockText` (decoded end to end, `0x5D1590..0x5D2466`, no read of `+0x3C` at
all), whereas `Evaluate` and `WalkChildren` both do. So when a context resolves to nothing the
tooltip counts its children against a scope the evaluator refuses — a real asymmetry between the
displayed tally and the answer, read off the bytes.

**What a trigger forest costs, then.** `RunDailyEventPass` (rva `0x5C0A40`, already recorded)
re-evaluates every candidate event's `trigger (+0x30)` slot 6 once a day, per country, against a
freshly inlined stack `CEventScope`. With no cache anywhere, that is a full re-walk of every tree
every day. The one place evaluation touches the **heap** is `CEventScope::MakeScope`'s `ally` and
`local_enemy` arms, which `operator new` and free a `std::vector<CCountryTag>` of candidates **per
evaluation**. Every other context, and every And/Or/Not node, is stack-only pointer chasing: the
per-node cost is the `0x48`-byte copy a context makes (18 dword moves) plus one indirect call per
child. So the cost model for a mod with thousands of triggers is **(number of live nodes) ×
(evaluations per day)**, with a heap allocation added for each `ally`/`local_enemy` node, and
doubled wherever a tooltip is open because slot 11 re-evaluates rather than reading a cached answer.

## 7. What the bytes refuse — `ally` does not read anything called allies

The `ally` context (token 0x359) reads a CList at **`CCountry +0xF88`** — head `+0xF88`, tail
`+0xF8C`, count `+0xF90`, nodes of `0x14` bytes shaped `{tagChars, tagId, prev, next, flag}`, the
same node layout `project.json` already describes for `CCountry::enemies (+0x1008)`. It walks the
list through `node+0xC`, collects `node+0` as an 8-byte tag pair, and picks one at random.

That list is written by **`CCountry::RebuildNeighbours` (rva `0xE21E0`)**, appended from *both* of
its walks (`0xE32E3` and `0xE3605`), with `0xE2339` clearing it at the top — and
`retsBefore(0x4E21E0, 0x4E3620)` returns **no** `ret`, so those sites really are inside that
function and this is not trap 2. Rva `0xE6A30` is an "is this tag in the list" membership test over
it.

And it is **none of the four neighbour fields `CCountry.hpp` names** (`neighbours +0xF58`,
`controller_neighbours +0xF68`, and the two `CCountryList` at `+0xFD8`/`+0xFE8`), nor anything in
`project.json`. So either the field is not what `RebuildNeighbours` makes it look like, or
**`ally = { ... }` scopes to a random bordering country.** One of those two names is wrong and the
bytes do not say which, so neither was recorded: the field is reported, not named. The existing
record's description of `CCountry::RebuildNeighbours` as filling "two neighbour sets and the two
`CCountryList` they stand for" is **incomplete** — it also fills this fifth structure.

## 8. What is not established

- `CEventScope +0xC` — the constructor's EDX again, beside `random_state`. The copy constructor
  copies it; no reader found. Could be the initial state kept for a reset, could be dead.
- `CEventScope +0x40` / `+0x44` — the constructor's one stack argument and a zero. 0 at 28 of the
  29 call sites inspected; `0x74501` is the exception and passes its own `[ebp+0xc]`. One call site
  is not a name.
- `CMapProvince::path_node_ptr (+0xD4) + 0xA4` — the province id the `sea_zone` context answers
  with. A field on `CProvinceTemplate`, which has no record.
- `CTrigger +0x14` (byte), `+0x18` (word), `+0x1C`/`+0x2C` (two `0x10`-byte containers), `+0x3C`
  (byte). All written by the base constructor; a scan of all 379 trigger-family slot bodies for
  `this`-relative reads of them produced only candidates (trap 12 — the register tracking follows
  `mov reg, ecx` and nothing harder), and none of the four `Evaluate` bodies is among them.
- The `0x110`-byte scope specification itself. It has no RTTI class, and `mergeFindings` refuses
  `struct_fields` for a struct `project.json` does not already hold. Hence `void*` in two
  signatures. **Added by hand** as `CEventScopeSpec` — see below.

## 9. Traps hit in this pass

Trap 1 twice over (the brief's VA/rva table is right; `disasm.py` reads a bare `0x5C1890` as a VA,
so the first read of `CEventScope::LoadKey` decoded garbage from the middle of an unrelated
function, which is exactly trap 9 arriving through trap 1). Trap 2 three times (§5). Trap 3 four
times, all benign and all settled by the jump targets and the shared SEH slot. Trap 4 twice, both
times the answer was inheritance (`CMTTHModifier` derives from `CAndTrigger`; the eight holders of
`0x5D0CD0` all derive from `CAndTrigger`). Trap 12 on `CCountry +0xF88` and on the `CTrigger`
base-field scan. Trap 14 decisively, twice: `CCountry +0xF38` was already `faction_leader_tag`
(which *corroborated* the `overlord` reading rather than conflicting with it), and `CCountry.hpp`
already names four neighbour fields, which is what stopped `+0xF88` being called `allies`.

**And one claim withdrawn before it was written down**: `+0x3C` was initially read as gated in
`CContextTrigger::GetBlockText` at `0x5D15D6`, on the strength of the instruction sitting right
after the `MakeScope` call. It is `mov edx, [edi+0x38]` — a read of `this_scope`, not the flag.
Decoding the whole of `GetBlockText` found no read of `+0x3C` anywhere in it. The four entries that
repeated the wrong count were corrected before the fragment was finished.

## Frontier

Reached from the bodies above and unnamed: `0x6A2E90` (the LCG the scope's randomness runs on),
`0x22690` (append an 8-byte tag to a vector), `0x66F260`, `0x780F60`, `0x796170` (`__ehvec_ctor`),
`0x9DB0`, `0xC480`, `0x14B50` (the `CTrigger +0x1C`/`+0x2C` element ctor/dtor), `0x6789F0`
(`ParseObjectId`'s save twin), `0x4A5270` + `0x4A5A60` + `0x4A73C0` (the `CAIStrategy` collector
slot 10 reports to — the highest-value item on this list, since it is what the whole slot-10
machinery exists for), the eighteen leaf slot-10 overrides (`0x5DABA0`, `0x5D5F10`, `0x5EB000`,
`0x5EFB60`, `0x5E6820`, `0x5E6300`, `0x5DD240`, `0x5DDA20`, `0x5DCC20`, `0x5DEFA0`, `0x5DB2F0`,
`0x5E4A50`, `0x5FCB30`, `0x5DF8A0`, `0x5EF4B0`), and `0x59E2B0` + `0x59E520` — **`CContextEffect`
slots 11 and 8**, the effect-side twin of `CContextTrigger`, which calls the same `MakeScope` and is
where the next wave should start if it wants the effect half of scoping.

Deliberately not started, per the brief: the ~148 leaf triggers' individual semantics.

---

## Transcription note

Read and written by wave 11's agent A; transcribed by the session that collected the wave, because
an agent's `Write` is refused for this path. Spot-checked independently before transcription, all
confirming:

- **The trap-2 boundary**, which is an error in the brief this agent was given: `ret 0xc` at VA
  `0x9D06DD` followed immediately by `push ebp` at `0x9D06E0`, no padding, and `functionStart`
  answers `0x9D06C0`. The plan verified the *upper* boundary (int3 run before `GetBlockText`) and
  asserted both.
- **`CEventScope`'s size**, and the record contradicting itself: the struct's `size` field says
  `0x38` while its own `+0x34` comment reads *"CEventScope is 0x48 bytes, vftable 0x15B8AEC, base
  CPersistent; +0x10 and +0x18 are two CCountryTags"* — which independently corroborates this
  agent's `+0x10 country_tag` and `+0x18 from_country_tag`. (That comment also writes the vftable as
  a VA in a record of rvas, which is trap 1 in prose.)
- **The slot-10 argument order**: `COrTrigger::WalkChildren` at VA `0x9D1273` does
  `mov eax, [ebp+0x14]; cdq; idiv [ecx+0x10]` then `cmp edi, 1`. The fourth stack argument is
  divided by `children_count` and clamped, so it is an **int weight**, not the `int* total` the
  recorded signature puts there.
- **The NOR reading**: `CNotTrigger::Evaluate` walks `[ecx+8]` dispatching `[vftable+0x18]` and does
  `cmp al, 1; je` to the false path, with the empty list falling through to the true path.
