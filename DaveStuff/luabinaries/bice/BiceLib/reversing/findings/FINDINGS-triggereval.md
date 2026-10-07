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
passes the result on — a bool it inverts.

> **Corrected 2026-10-06 (wave 14).** This paragraph used to continue "so under an odd number of
> NOTs a satisfied condition is *not* reported to the collector". **That is true of one leaf and
> false of nine**, and since both roots pass `0` it comes out backwards in the common case. The ten
> leaves that read the flag do five different things with it, and only `CExistsTrigger` behaves as
> "report only if set" — see §12, which has the table. The flag is best read as **`negated`**.

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

## 10. Slot 11 has one root, and it is a once-a-game-day panel refresh

Added 2026-10-06, wave 14. §6 ends by saying the cost is "doubled wherever a tooltip is open because
slot 11 re-evaluates rather than reading a cached answer". That was an inference from the signature.
It is nearly right about the mechanism and wrong about where it happens.

**There is exactly one place in the image that enters slot 11 from outside the trigger classes.**
`BuildTriggeredModifierEntry` (rva `0x2D1130`) does, at `0x2D13DE`-`0x2D1415`:

    passed = 0; total = 0;                                         ; [ebp-0x34], [ebp-0x38]
    (&modifier->trigger)->CountEvaluation(scope, &passed, &total)  ; slot 11, via [eax+0x2C]
    sprintf(buf, "%d / %d", passed, total)                         ; the string at VA 0x15D2D5C

and the result goes into a gui element called `modifier_strip`. So the "n of m conditions met" figure
§6 inferred is real, and **the format string is literally `"%d / %d"`**, read out of the image.

The receiver is `modifier + 0x88` taken by `lea`, i.e. a **by-value sub-object**.
`CTriggeredModifier`'s constructor (rva `0x5B950`) constructs a `CAndTrigger` there, and
`CTriggeredModifier` and `CCovertOpsMission` are the only two classes in the image that embed one at
`+0x88` - found by scanning all 31 code references to the `CAndTrigger` vftable for a `lea` of
`+0x88`. The gui element names (`modifier_name` at `0x2D1160`, `modifier_strip` at
`0x2D120A`/`0x2D1372`, `modifier_effect` at `0x2D1273`) settle which of the two it is, which is why
the function's *name* is marked `inferred` while the mechanism is not.

### How often

The chain is `CInGameIdler::Update` -> `UpdateTutorialAndAuxWindows` (rva `0x24FC70`, which the
record already describes as running every frame, and which already named `0x2D1CB0` as one of its two
unread callees) -> `RefreshTriggeredModifierPanel` (rva `0x2D1CB0`) -> `0x2D1930` ->
`BuildTriggeredModifierEntry`, once per listed modifier (the call at `0x2D1C80` sits in a loop,
`inc [ebp+8]; cmp eax,esi; jl 0x2D1C41`).

`RefreshTriggeredModifierPanel` is where the frequency is decided. `0x2D1CB0` to the bare `ret` at
`0x2D1DD4`, receiver in **EDI** and no stack argument - so `__fastcall` with an explicit register
rather than a `__thiscall`, which is trap 11. `retsBefore` empty, 7 `int3` before and 11 after. Three
gates, each of which returns having done nothing:

    if ([[recv+0x20] + 0x5B] == 0) return;              ; 0x2D1CDA  - a visibility byte
    state = g_CCurrentGameState (VA 0x1A89790)          ; built here if absent
    if (state->player_id (+0xC34) == 0) return;         ; 0x2D1D68
    day = (state->tick (+0xBDC) - 0x29C55C0) / 24       ; RunHourlyTick's own arithmetic
    doy = day - (int)(day / 365.0) * 365.0              ; VA 0x160A550 is the double 365.0
    if (doy == recv->+0x74) return;                     ; 0x2D1DB9
    recv->+0x74 = doy; 0x2D1930(recv)

So the panel - and every trigger tree under it - is rebuilt **once per game day**, and only while
that visibility byte is set and a country is being played. It also lazily constructs the `0xDA8`-byte
`CCurrentGameState` when the global is null; that is a get-or-create and not part of the refresh.
(`0x15CF674` resolves to `CCurrentGameState` out of the RTTI export, which is how that allocation was
identified.)

One detail for anyone tempted to think the "unchanged" path is free: `BuildTriggeredModifierEntry`
skips re-setting `modifier_name` and `modifier_effect` when `[recv+0x28]` already holds this modifier
(`0x2D1155`), **but the `CountEvaluation` walk is on both paths**. A refresh re-walks the tree even
when the displayed modifier has not changed.

### The search, and its positive controls

This is a negative about the rest of the image, so how it was reached matters.

A byte-wise scan of `.text` for **both** MSVC virtual-call forms through displacement `+0x2C` -
`call [reg+0x2C]`, and `mov R,[reg+0x2C]` followed within `0x24` bytes by `call R` - gives **1,083
sites**, each decoded in a window that lands exactly on the call rather than from a guess (trap 9).
Of those, **24 pass three stack arguments**, which is what slot 11's signature takes:

- **three are the slot-11 bodies' own recursions**: `0x5D0CEA` in `CAndTrigger::CountEvaluation`,
  `0x5D13A4` in `CNotTrigger::CountEvaluation`, `0x5D24F4` in `CContextTrigger::CountEvaluation`.
  *These are the positive control*: the record documents all three independently, the scan finds all
  three, and it correctly finds none in `CTrigger::CountEvaluation` or `COrTrigger::CountEvaluation`,
  which the record says call children's **slot 6** instead. Three positives and two true negatives.
- **one is the root** above.
- **twenty are other classes' slot 11**, each decoded and rejected on its shape - they return a value,
  or take one or two arguments. The twelve non-trigger ones in `0x5B0000`-`0x620000` are the effect
  side, `CEffect`'s own slot 11 being `Execute`; the one decoded in detail is `FireEvent` at
  `0x5C13E2`, two arguments, on the effect embedded at `CEvent +0x98`.

And `findRefs.py --callers` reports **0 direct calls** to each of the five slot-11 bodies
(`0x5D06C0`, `0x5D0CD0`, `0x5D1230`, `0x5D1380`, `0x5D24C0`). *Positive control for that tool*: the
same command finds the one direct call to `0x5D0680` from `0x5D24A7` that the record already holds.

**`image.findValue` is not the check for a direct call** - a `call rel32` carries a displacement, not
the address, so `findValue` answers 0 for a function with a hundred callers. It was run first here and
would have been a silent false negative had `findRefs` not been run after it.

**The one shape this cannot see**: three arguments written with `mov [esp+N], ...` instead of pushed,
which a frame-pointer-omitted caller can do. That is the residual gap in the negative.

## 11. Slot 10 has two roots, and a trigger is often a by-value sub-object

The same scan over `+0x28` gives **334 sites**, of which **15 pass four arguments**: the three slot-10
recursions (`0x5D069A`, `0x5D129A`, `0x5D135E`), five sites inside leaf slot-10 bodies, five in
unrelated classes, and **two roots, both inside `ApplyCountryAIStrategies` (rva `0x4A62A0`)**:

| site | receiver | arguments |
| --- | --- | --- |
| `0x4A63C2` | the `CAndTrigger` embedded at `+0xC4` of `[esi+0xE40]`, after that object's own slot 6 answers true | `collector=ebx, scope=&[esi+0xE44], polarity=0, weight=0x258` |
| `0x4A6566` | a trigger embedded at `+0x24` of each element of a pointer array | `collector=ebx, scope=&[ebp-0x64] (a stack CEventScope), polarity=0, weight=0xC8` |

So the weighted attribution walk runs exactly as often as that function does; its one caller is the
AI strategy cache rebuild at `0x4A5C90`, which has eight callers of its own. **The class of the
objects holding those embedded triggers was not identified** - that is AI-side work and was left.

**Why the first pass found no root at all, and this is the generalisable part.** Both sites load the
vftable as `mov reg,[obj+<offset>]`, because the trigger is a **by-value sub-object** rather than a
pointer. A filter that accepted a vftable load only in its textbook form `mov reg,[obj]` -
displacement zero - threw both roots away and reported that the whole slot-10 chain had no entry
point. Reading an embedded sub-object's virtual call is as ordinary here as reading a pointer's, and
`CTriggeredModifier +0x88`, `CEvent +0x98` and the two above are four instances of it in one
afternoon. **A vftable-load pattern must allow a non-zero displacement.**

## 12. The polarity flag: one leaf behaves as §6 said and nine do not

§6's generalisation is corrected in place above. This is the measurement behind it.

Of the **20 distinct slot-10 bodies** the 168 `CTrigger` descendants' tables hold (167 descendants
plus `CTrigger`; three of them do not have "Trigger" in the name - `CHasCombinedArmsBonus`,
`CMTTHModifier` and the game's own typo `CNationalProvinceTigger`), ten test `byte ptr [ebp+0x10]`,
and they do **five different things** with it:

| rva | class(es) | what the flag does |
| --- | --- | --- |
| `0x5D5F10` | `CControlsTrigger`, `COwnsTrigger` | `jne` -> own epilogue: **silent when set** |
| `0x5DB2F0` | `CSubUnitTrigger` | **silent when set** |
| `0x5E4A50` | `CHasBuildingTrigger` | **silent when set** |
| `0x5EB000` | `CUndeclaredWarWithTrigger`, `CWarWithTrigger` | **silent when set** |
| `0x5EF4B0` | `CVassalOfTrigger` | **silent when set** |
| `0x5FCB30` | `CFactionTrigger` | **silent when set** |
| `0x5DABA0` | `CExistsTrigger` | `je` -> own epilogue: **silent when clear**, so it reports only a *negated* `exists`. The one §6 generalised from |
| `0x5EFB60` | `CAllianceWithTrigger` | **negates the weight**: `cmp byte [ebp+0x10],0 / je / neg eax` at `0x5EFBA8`-`0x5EFBB7`, with a second `neg` at `0x5EFC02` so its two collector calls get opposite signs |
| `0x5DEFA0` | `CRelationTrigger` | **switches collector**: the same three arguments pushed, then `0x4A5270` when set and `0x4A5420` when clear |
| `0x5DF8A0` | `COwnedByTrigger` | **inverts the comparison**: `jne skip` at `0x5DF8FC` against `je skip` at `0x5DF911` on the same tag comparison, both converging on the same report through `0x4A4F50` |

The other ten bodies never read it: `CNotTrigger` flips it, **five scope rebinders** forward it
untouched (`CRegionScopeTrigger`, `CAnyNeighborProvinceTrigger`, `CAnyOwnedProvinceTrigger`,
`CAnyNeighborCountryTrigger`, `CAnyCoreTrigger` - each copying the scope with
`CEventScope::CopyConstruct`, rva `0x3C850`), 140 classes inherit `CTrigger`'s base forwarder, and
`CUnitsInProvinceTrigger` points at the folded no-op `DoNothing_4Args`.

**How the table was settled:** every one of the ten jump targets was followed to see whether it is the
body's own epilogue - pops and `ret`, no call between it and the `ret` - or a second reporting path.
Seven are epilogues; three are second paths, which is precisely the distinction a jump-target
*distance* cannot make (`COwnedByTrigger`'s target is 40 bytes before its `ret` and
`CAllianceWithTrigger`'s is 85, and both of those are code, not cleanup). The parameter is still
spelled `polarity` in ten recorded signatures and was left spelled that way; only the account of what
it means changed.

**The collector family is now visible**, and it is five entry points rather than one: `0x4A4F50`,
`0x4A51C0`, `0x4A5270`, `0x4A5420`, `0x4A5620`, all unnamed and all in `CAIStrategy`'s region. The
record already has `0x4A5270` inserting into a map a `CAIStrategy` owns. **`0x4A51C0` is the one that
takes text** (from `CHasBuildingTrigger`), which is a shape worth knowing before anyone reads them.

## 13. The cache question, settled from the layout as well as from the bodies

§6's "there is no cache anywhere" is right, and two things now stand behind it that did not.

**`CAndTrigger` adds no field to `CTrigger`.** Its inline construction at `0x1612F`-`0x1614E` writes
`+0x4` (`type_id` `0x18D`), `+0x0` (the `CTrigger` vftable), the word at `+0x18`, `__ehvec_ctor` over
`&this[+0x1C]` (element size `0x10`, count 2, element ctor rva `0x9DB0`, dtor rva `0xC480`), the byte
at `+0x3C`, and then the `CAndTrigger` vftable over the `CTrigger` one - and nothing else. And one
object embeds six `CAndTrigger`s by value at `+0x30`, `+0x70`, `+0xB0`, `+0xF0`, `+0x130` and
`+0x170`: **an exact `0x40` stride, five times over.** So `CAndTrigger` is `0x40` bytes, identical to
`CTrigger`, and **there is nowhere on the most numerous class in the forest for a cache to live.**

That size was reached **twice in one wave by two independent routes** - the `0x40` stride above, and
`CTrigger::LoadKey` asking `operator new` for exactly `0x40` at `0x5C912D` (§16). Two routes to the
same size is better evidence than either alone.

**`CTrigger`'s layout is now complete**, and `+0x14` is accounted for. The base constructor writes the
child list and its fourth member together at `0x1610D`-`0x16116`:

    mov [edi+8], 0 ; mov [edi+0xC], 0 ; mov [edi+0x10], 0 ; mov byte [edi+0x14], 0

which is the `{first, last, count, spare}` shape the record describes for every other `CList` here.
So `+0x8` through `+0x14` is one container, `+0x18`/`+0x19` the two keyword bools, `+0x1C` and `+0x2C`
the two `0x10`-byte sub-objects, `+0x3C` a byte, total `0x40`. The `+0x40` that 259 slot bodies read
is the **derived** class's first field - the leaf's argument - not a `CTrigger` field at all, which is
a useful cross-check on the size.

**Nothing on a trigger is read as a cache.** A taint scan over **all 379 distinct bodies in the twelve
slots of all 168 `CTrigger` descendants** - taint starting at ECX, following `mov r, ecx` and
`mov r, <tainted>`, each body decoded from the address its own vftable holds, so no `functionStart`,
which is unreliable across this region - finds `this`-relative reads of `+0x0` (12 bodies), `+0x8`
(16), `+0xC` (1), `+0x10` (2), `+0x18` (49), `+0x19` (14), `+0x40` (259) and `+0x44` (36), and **none
at all** of `+0x14`, `+0x1C`, `+0x2C` or `+0x3C`. The `+0x8`, `+0x18` and `+0x40` counts are the
positive control: they are fields the record already knows are read, in the same code, by the same
method. The gap this cannot see is a non-virtual member function, or any code reaching the fields
through a pointer from outside the trigger classes; within the 379 virtuals the silence is real.

## 14. What a trigger forest actually costs

The answer the wave was opened for, stated for a mod author and for the maintainer.

- **Per game day, per country: one full walk of every candidate event's trigger tree** through slot 6,
  from `RunDailyEventPass` (rva `0x5C0A40`). This is the whole cost and nothing above changes it.
  Thousands of decisions and events is thousands of tree walks a day.
- **Nothing is cached**, so a tree is re-walked from the top every time. The only heap traffic in
  evaluation is `CEventScope::MakeScope`'s `ally` and `local_enemy` arms, which `new` and free a
  vector per evaluation, plus the per-iteration allocations in the three scope-rebinding slot-10
  bodies. Everything else is stack-only pointer chasing: a `0x48`-byte scope copy per context node and
  one indirect call per child.
- **Tooltips do not double it.** Slot 11 is not the tooltip path - `CTrigger::GetBlockText` (slot 9)
  draws requirement tooltips and uses slot 6 for the red/green icon per line. Slot 11's single root is
  a triggered-modifier panel strip that refreshes **once per game day while that panel is visible**.
  §6's "doubled wherever a tooltip is open" should be read as "one extra walk per visible triggered
  modifier per day" - negligible against the daily event pass.
- **Condition order inside an `and` does matter, for evaluation.** `CAndTrigger::Evaluate` calls each
  child's slot 6 and stops at the first that answers 0 (`test al,al; je` at `0x5D06FD`), so putting a
  cheap, often-false condition first in an `and = { ... }` genuinely saves the rest.
  `COrTrigger::Evaluate` stops at the first child that answers 1 (`cmp al,1` at `0x5D0D1D`), so put
  the **likeliest** condition first in an `or`. The expensive conditions to put last are the ones that
  scope - `any_owned_province`, `any_neighbor_province`, `any_core`, `ally`, `local_enemy` - because
  those allocate.
- **But the tally does not short-circuit.** `CAndTrigger::CountEvaluation` has no exit test on a
  child's result; its loop's only condition is `test esi,esi` on the next node. It calls every child's
  slot 11, and each leaf's slot 11 calls that leaf's own slot 6. So the `"%d / %d"` figure costs a full
  evaluation of every condition under the block **even when the first one fails** - which is exactly
  why it matters that this runs daily on a gated panel and not per frame.
- **For BiceLib:** there is nothing here to hook or memoise for a frame-time win. If a frame-time
  complaint is ever traced to the trigger forest, the daily event pass is where it lives, not the GUI;
  and `RefreshTriggeredModifierPanel`'s day-of-year gate at `CCurrentGameState +0xBDC` is a clean,
  already-understood choke point if the panel ever does show up in a profile.

## 15. `CVariables::SaveContents` and `CVariables::LoadKey`, and why they looked unrecorded

Wave 14's plan said these two (rvas `0x77060`, `0x77080`) "are described inside other entries'
comments and recorded as neither", and that both rvas were unrecorded. **True of `project.json` and
false of the fact base** - which is trap 14's three-halves problem in its exact shape.
`buildFindings.py` has a pass that walks the RTTI `introduces` list and names CPersistent's five for
every class that supplies its own, *including* classes where CPersistent sits at a non-zero offset, so
`bicelib_findings.json` carries both at `CERTAIN` with the right signature, the `base@ECX` storage,
and the note that **`this` is the CPersistent sub-object, `CVariables + 36`**. They have been in
Ghidra all along, and no `project.json` entry was added - it would be a second record for an address
that already has one, and its signature would fight the generated one.

Reading them was still worth it, because the mechanics are nowhere.

**`CVariables::SaveContents` (rva `0x77060`, `ret 4`).** `this` is the CPersistent sub-object, so
`[ecx-0x20]` is `CVariables +0x4` (`root`) and `ecx-0x24` is the object. The whole body is
`if (root) CVariables::SaveSubtree(writer, root)`, which is why **an empty variable set writes no
`variables={}` block at all**, rather than an empty one.

**`CVariables::LoadKey` (rva `0x77080`, `ret 8`)**, `0x1C` bytes read end to end:

    v = operator new(0x20)                    ; a CVariable: Hoi3CString at +0, int at +0x1C
    v->name.length = 0; v->name.maxLength = 0xF; v->name[0] = 0; v->value = 0
    std::string::assign(&v->name, parse+0x24, strlen(parse+0x24))
    v->value = *TokenToFixedPoint(parse+0x228, &parse)     ; thousandths
    (*(CVariables*)(this-0x24))->vftable[6](v, v)          ; NameTree_Insert, rva 0x4D8A0

Three things in that. **It never reads its `key` argument** - the variable's name comes from the raw
key *text* at `parse+0x24`, not from the token at `parse+0x228`, so **a variable may be named anything
and need not be a registered save token**. The value goes through `TokenToFixedPoint`, so **a variable
is thousandths**, matching `CVariableTrigger`'s threshold. And the out-pointer handed to
`TokenToFixedPoint` is `&[ebp+8]` - the function **overwrites its own `parse` argument slot** as
scratch, which is legal only because `parse` is already live in EDI. A signature reading `parse` as
in-out would be wrong, and reading the slot as a second local would be wrong too.

## 16. The trigger containers, and what the sizes settle

`CTrigger::LoadKey` builds one class per keyword as `push <size>; call operator_new; push eax;
call <constructor>`, so pairing the three names every size. Done for the whole switch, that is **156
class/size pairs**. Two traps had to be handled: **capstone stops silently** about `0x60000` bytes in
(trap 9's third form, so each stop is resumed one byte on - 2 resumes over this function), and the
constructors are **not inlined**, so the vftable has to be read out of the constructor's own body. The
distribution is `0x44` x 111, `0x48` x 16, `0x40` x 10, `0x5C` x 9, `0x4C` x 5, `0x60` x 2, and one
each of `0x50`, `0x64` and `0x150`.

**`CAndTrigger`, `COrTrigger` and `CNotTrigger` are each exactly `0x40` and add nothing to
`CTrigger`.** Their three constructors (rvas `0x16010`, `0x5CB730`, `0x5CB7B0`) are the **same body
three times** - the compiler emitted a copy each rather than sharing one, which is why the linker did
not fold them - and each writes only `CTrigger`'s members, as §13 lists. So **`CTrigger`'s recorded
`0x40` is now fixed by an allocation and not only by its 129 readers**, and the two `0x10`-byte
members at `+0x1C` and `+0x2C` are `CTrigger`'s rather than the context scope's, which closes an open
question in `CContextTrigger::CContextTrigger`'s own comment.

**`CContextTrigger` is `0x150` and the spec is the whole of it.** `operator new(0x150)` at
`0x5CAEA6`; the caller then does `sub esp,0x104 / mov ecx,0x41 / rep movsd` and the constructor ends
`ret 0x108` (4 for `this`, `0x104` for the spec by value), copying through `EventScopeSpec_Construct`
into `this+0x40`. That function copies `0x104` bytes and then **writes the last three fields itself**:
`+0x104 = 0`, `+0x108 = 0x2D2D2D` (`"---"`, the null tag), `+0x10C = 0`, then resolves the text -
`atoi` into `+0x104` as a province id, or, when `token == 0xF`, a country lookup. So
`0x40 + 0x110 = 0x150` exactly. This is **independent agreement** with the arithmetic already written
into `CEventScopeSpec`'s own comment, not a first settlement.

**`CTagTrigger::Evaluate` (rva `0x5E8960`)**, two `ret 4` at `0x5E898D` and `0x5E89AB`, one function
(the `je 0x5E8990` at `0x5E8976` jumps past the first). 10 `int3` above, only **2** below - a boundary
the "run of three" rule walks past.

    id = this->tag.id (+0x44)
    if      (this->arg_is_this (+0x18)) id = scope->this_scope (+0x38)->country_id (+0x14)
    else if (this->arg_is_from (+0x19)) id = scope->this_scope (+0x38)->from_country_id (+0x1C)
    return scope->country_id (+0x14) == id

The three tag characters at `+0x40` are copied into a stack slot in every arm and **nothing reads them
again before either exit**, so **`GER = { ... }` as a condition compares by country index only**. THIS
and FROM are both read through `scope->this_scope`, not off the scope itself. And since `+0x18`/`+0x19`
are `CTrigger`'s own flags, **`THIS = { ... }` and a literal tag are the same class.**

**`CHasCountryFlagTrigger::Evaluate` (rva `0x5E20B0`)**, two `ret 4` at `0x5E2100`/`0x5E2108`, one
function via the `je 0x5E2103`.

    name    = c_str(this->flag (+0x40))                        ; the maxLength>=0x10 small-string test
    country = database[0x1A855A4]->+0x16C[ scope->country_id ]
    found   = country->flags (+0x180)->vftable[2](name)        ; GuiTypeTree_Find, 0x67DEE0
    return found != 0 && found->is_set (+0x1C) != 0

**`has_country_flag` is a test of the flag's value, not of its existence** - and because `CFlags`
clears the byte rather than removing the node, **a flag that has been cleared is still in the tree and
answers false**, which is the correct behaviour arrived at by a route nobody would guess.
`CCountry +0x180 flags` and `CFlag +0x1C is_set` were both already recorded and agree. The lookup is
done per evaluation rather than resolved at load, so an unknown flag name is a permanent false rather
than an error - the same silence the engine gives every other bad name.

**`CVariableTrigger`**: `operator new(0x60)` at `0x5C9BC0` closes the layout its `Evaluate` already
read. Its `LoadKey` (rva `0x5F0260`) confirms both halves - token `0x61E` (`which`) does
`std::string::assign(this+0x40, ...)` and token `0x2A6` (`value`) does `TokenToFixedPoint` into
`+0x5C`, so **the threshold is thousandths**, which the record did not say.
`0x40 + 0x1C + 4 = 0x60`.

**`CTechnologyTrigger`** (rva `0x5DB430`, read end to end): `[ecx+0x44]` is a `CTechnology*`
dereferenced at `+0x244` (its recorded `Index`) and `[ecx+0x40]` is the level, compared `setge`. **No
size**: alone in the family it is not built from a `new` inside the switch - the keyword falls through
to the technology database - so nothing was found to settle it, and none was guessed.

## 17. The collectors: what the weighted walk writes, and why it is cheap

Added 2026-10-06, wave 15. §12 ended by saying "the collector family is now visible, and it is five
entry points rather than one". **It is ten**, and the five the trigger walk reaches are the half of
the family that trigger conditions can argue about.

### They are not five, and they are not thunks

`0x4A4F50` to `0x4A5800` is one contiguous run of ten small functions in `CAIStrategy`'s region, each
ending `ret 8` or `ret 0xC`, each with nothing but padding between it and the next:

| rva | list | hash | cap | reached from a trigger? |
| --- | --- | --- | --- | --- |
| `0x4A4F50` | `conquer_prov` `+0x1C` | - | 40, or **60** for `_AI_MILITARIST_` | yes - `CControlsTrigger`/`COwnsTrigger`, `COwnedByTrigger`, `CFactionTrigger` |
| `0x4A5090` | `defend_prov` `+0x2C` | - | 1000 | no |
| `0x4A51C0` | `building_prov` `+0x10C` | - | none | yes - `CHasBuildingTrigger` only |
| `0x4A5240` | `threat` `+0x3C` | `+0x4C` | **none** | no |
| `0x4A5270` | `antagonize` `+0x58` | `+0x68` | 7 | yes - six leaves |
| `0x4A5340` | `rival` `+0x11C` | `+0x12C` | 4 | no |
| `0x4A5420` | `befriend` `+0x74` | `+0x84` | 7, or **14** for `_AI_DIPLOMAT_` | yes - four leaves |
| `0x4A5520` | `protect` `+0x90` | `+0xA0` | 7, or 14 for `_AI_DIPLOMAT_` | no |
| `0x4A5620` | `vassal` `+0xAC` | `+0xBC` | 10 | yes - `CVassalOfTrigger`, the caller the record had not attributed |
| `0x4A5700` | `military_access` `+0xC8` | `+0xD8` | 10 | no |

**Trap 4 is cleared with controls on both claimants.** `vtable.py --holding` reports **zero** tables
for all ten (and for the three insert helpers, the clear and the token mapper), while the same
command on `CExistsTrigger`'s slot-10 body reports one - so the tool was working. An index of
`luabind.json`'s 620 `pointer` values finds none of the sixteen, while finding both known fold cases
it should, `0x63D780` and `0x16000`. **None of them is a virtual or a shared stub.**

Two of the ten are **adapters for a single caller**: `MergeAIStrategy` bypasses `0x4A51C0` and
`0x4A5240` and calls their helpers `0x4A58F0` and `0x4A5A60` directly. Those two exist only because
the trigger leaf's call shape differs - which is the honest answer to "why five entry points rather
than one": **there is one per list, and the trigger side needed two of them wrapped.**

### The collector is the country's own `CAIStrategy`

`ApplyCountryAIStrategies`' `collector=ebx` is its own argument, the merged `CAIStrategy` at
`CCountry +0x48C`. Three independent things say so and were each read: `+0x18` is `Personality` and
two of the caps branch on it; `+0xC` is the strategy's own country id and `0x4A5A60` refuses to
record it; and `MergeAIStrategy` - which the record already types `CAIStrategy*` on both arguments -
calls all ten adders.

### What is collected, and keyed by what

**A weight against a key, accumulating, ranked, and capped.** Three payload classes, all
`CPersistent` with token `0x18D`, all now declared:

- **`CProvinceValue`** (`0x10`) - `{id, value}`, the element of `conquer_prov` and `defend_prov`.
- **`CCountryValue`** (`0x14`) - `{CCountryTag tag, value}`, the element of the seven country-keyed
  lists, held in both the list and a hash beside it.
- **`CStringIntInt`** (`0x2C`) - `{id, Hoi3CString key, value}`, the element of `building_prov`, and
  the only pair-keyed one.

Each insert walks for an existing entry with the same key and, if it finds one, **adds** the weight
to it; it then unlinks the entry and re-inserts it in weight order, so the list is sorted high-to-low
from head to tail. If the accumulated total falls to zero or below the entry is destroyed - in the
country case removed from the hash too. The caller then pops from the **tail** until the count is
under its cap, so **a cap drops the weakest entries, never the oldest.** `threat` is the only list
with no cap.

The seven country-keyed lists each carry a hash of the same payloads at **list + 0x10**,
`{count, bucket_count, buckets}` with `bucket_count` `0x1FF` - the list for ordered, capped
iteration, the hash for `strategy->threat[countryId]` lookups, which is what `CAIUnit::SetArea`
already does.

**The savegame is the oracle for all of it**, and a strong one. The merged strategy is saved under
the key **`ai`** (the two sources are `ai_hard_strategy` and `ai_event_strategy`, both empty for
Germany in a 1942 Ireland game), and every list writes one block per entry:
`conquer_prov = { id=33 value=50 }`. Measured over `Ireland1942_05_11_11.hoi3`, across **108
strategy blocks**, the largest block per list is `antagonize` **exactly 7**, `befriend` **exactly
14**, `vassal` **exactly 10**, `rival` **exactly 4**, `protect` 12, `conquer_prov` 38, `defend_prov`
183, `military_access` 8, `threat` 14, `building_prov` **absent entirely**. **Four caps are hit dead
on; none is exceeded.** `building_prov`'s absence is the expected shape of a list whose only
contributor is a `has_building` condition inside an AI strategy's trigger block, and the positive
control is that the other nine appear in the same blocks written by the same `SaveContents`. These
figures were produced twice, by two independently written parsers.

One observation offered as an observation: **every `conquer_prov` value in that save is exactly 50**
(489 of them), while the two walk roots pass weights of 600 and 200. `COrTrigger::WalkChildren`
divides the weight by its child count (§6), so 50 is what 600 or 200 looks like after being split -
but the AI-side callers `0x4A6957`/`0x4A69B5` also feed those two lists, so nothing here
distinguishes the two sources.

### `0x4A51C0`'s text argument

It is a **building name**, and `building_prov` is the only list keyed by a pair.
`CHasBuildingTrigger::WalkChildren` reads `*(this->+0x40) + 0x1C` - the building definition's own
name string, not a copy on the trigger - puts `scope->province` in EDX and the walk's weight in ECX,
and passes the string **by value**. An existing entry matches only when both the province id and the
name string match. The payload's weight sits at `+0x28` rather than `+0xC`, which is why
`building_prov` has a sorted-insert helper of its own (`0x4AE700`) instead of sharing `0x4AE630`.

That function's convention defeats a signature and is recorded as `no_signature`: `ret 0x20` is 4
(the strategy) + `0x1C` (the `Hoi3CString`), and the province and weight arrive in EDX and ECX and are
**forwarded by stack position** - `push ecx; push ecx; push edx` in its own prologue, so they land as
the helper's arguments 3 and 4. The arithmetic closes: the helper's own `ret 0x28` is
4 + `0x1C` + 4 + 4.

### The cost answer, in terms the maintainer can act on

**The weighted walk is not a periodic cost.** Its only route in is `CAIStrategy::Rebuild` ->
`ApplyCountryAIStrategies`, and `Rebuild` has **eleven** callers:

- **`RunCountryDailyPass`** - the only daily one, and it is gated:
  `if (!strategy->initialized && !strategy->is_static) Rebuild()`. `Rebuild` sets `initialized` at
  the end, so after the first successful rebuild the daily pass skips it. **Effectively a
  once-per-country initialisation.**
- **`CInGameIdler::Enter`** - twice, once directly and once through
  `CCountry::UpdateAtWarAndEnemies`. Session start.
- **`CCountry::UpdateAtWarAndEnemies`** - at session entry and on **both sides** of each of
  `CWar::AddAttacker`, `RemoveAttacker`, `AddDefender`, `RemoveDefender`.
- **`CFaction::AddCountry`** (twice), **`CPeaceAction::Apply`**, **`CAddAIStrategyEffect::Execute`**.
- Three unnamed `CCountry` methods (rvas `0xE0460`, `0xE39C0`, `0xEE860`).

So: **a handful per country per game year, driven by war and diplomacy, plus one initialisation.**
Against the daily event pass of §14 - every candidate event's whole tree, per country, per day,
through slot 6 - slot 10 is **negligible, and there is nothing here to hook or memoise.**

**And every rebuild starts from nothing.** `Rebuild` calls `CAIStrategy::ClearCollectedLists` first,
which empties all ten lists and all seven hashes, then stamps `+0x10 = state->tick` and `+0x14 = 1`.
So the weights in a save's `ai` block are **one rebuild's worth**, not a running total over the game -
which also means a mod author can read the walk's output straight out of a savegame and compare it
against the trigger blocks that produced it.

**A frequency claim in the record had to be corrected to reach that answer.**
`CCountry::UpdateAtWarAndEnemies`' entry said one of its callers was "`0x65B398` (inside
CInGameIdler's hourly body)". `0x65B398` is a **virtual** address (rva `0x25B398`), and
`functionStart` answers `CInGameIdler::Enter` with `retsBefore` empty - **session entry, not
hourly**. Since that function calls `Rebuild` unconditionally, "hourly" there would have made the
whole weighted walk an hourly per-country cost. **Trap 1 again, in a record that is otherwise rvas
throughout**, and the same entry's eleven `Rebuild` caller addresses were VAs stored as rvas and the
count was given as eight.

### The two embedded-trigger holders, which wave 14 left

Both identified, and neither needed any AI policy read.

**Root 1 - `CMission`.** `CCountry +0xE40` is a `CMission*`: the country's current mission
**definition**, as distinct from the saved `active_mission` instance at `+0xE38`. What names it is a
trigger: `CActiveMissionTrigger::Evaluate` (rva `0x5F16D0`) is the whole of
`return scopeCountry->+0xE40 == this->+0x40`, and `vtable.py --holding` puts that body in exactly one
table. `CMission` embeds **three** `CAndTrigger`s and the one `ApplyCountryAIStrategies` walks is the
middle, at `+0xC4`; of the 31 code references to the `CAndTrigger` vftable, only two neighbourhoods
also form a `+0xC4` address, and the one at rva `0x5C506E` is in the function that writes
`CMission`'s own vftable. The scope the walk passes, `CCountry +0xE44`, is an embedded `CEventScope` -
`0x48` bytes, with a second of the same size at `+0xE8C`, both copied from one record by rva
`0xEE76B`.

**Root 2 - `CVictoryCondition`.** `CCurrentGameState +0xD08`, which the record already names
`victory_conditions`, holds a vector of `CFaction*` at `+8`/`+0xC` and a parallel array of
`0x10`-byte per-faction vectors at `+0x18`. `ApplyCountryAIStrategies` finds the index of
`CCountry +0xD8` (`faction`) in the first and walks every element of the matching vector, calling
slot 10 on a trigger embedded at each element's `+0x24` with weight 200. `CVictoryCondition`'s
vftable has exactly one code reference, in a constructor that inline-constructs a `CAndTrigger` at
`+0x24`.

So the walk is: **the country's current mission's condition block, weight 600, plus every victory
condition its faction holds, weight 200** - and what it writes is "which provinces and which
countries do my mission and my victory conditions argue for, and how strongly".

### Three abutting-function pairs for `TRAPS.md`

All in this family, all with **one or two `int3`** between a `ret` and a fresh `push ebp`, so the
"run of three" rule walks past each: `0x4A51BC`/`0x4A51C0`, `0x4A533C`/`0x4A5340`, and (two `int3`)
`0x4A508B`/`0x4A5090`. `functionStart` happens to get all three right because each next function
opens with a prologue byte - the same situation as the existing `0x47BC5D`/`0x47BC60` row - but a
padding-run scan would merge them.

### A `0x5D49D0` discrepancy, since corrected

`CCasusBelli::RemoveFromStatus`'s comment named the list-unlink helper `0x5D49D0`. In a file of rvas
that means VA `0x9D49D0`, where the bytes are mid-function. The helper is at **VA** `0x5D49D0`, i.e.
**rva `0x1D49D0`**, which opens cleanly `push ebp; mov ebp, esp; mov eax,[ebp+8]`. Corrected in the
record 2026-10-06.

### What was left at the AI boundary, explicitly

- **`ApplyCountryAIStrategies`' other work.** Its tail from `0x4A64B4` calls eight AI routines
  (`0x4A6580`, `0x4A67B0`, `0x4A6980`, `0x4A6AC0`, `0x4A73C0`, `0x4A8250`, `0x4A8AF0`, and
  `0x4A5B50` four times on list bases). Not read.
- **`CAIStrategy::ClearCollectedLists`' tail** from `0x4A3ECE`: a `0xC0`-byte singleton at absolute
  `0x1A886F0` with its own `0x1FF`-bucket hash, walked under a bool the five callers disagree about.
  Not read - the one reason that entry is `inferred`.
- **What consumes the collected lists.** Structurally answered - they are the strategy's own
  persistent fields, written once per rebuild and read many times after, with `CAIUnit::SetArea`
  already recorded as a reader of `threat` and `antagonize` through their hashes - but the readers of
  `conquer_prov`, `defend_prov` and `building_prov` are AI decision logic and were not sought.
- **`CVictoryCondition`/`CVictoryConditionManager` layout**, `CMission`'s other two `CAndTrigger`s
  and its size, and which of the three is `potential` and which `trigger`. Scenario- and AI-side;
  `CMission` is declared with no fields rather than guessed at.

**One recommendation deliberately not taken:** retyping `CAIStrategy`'s ten list heads from `void*`
to `CList<CProvinceValue*>` / `CList<CCountryValue*>` / `CList<CStringIntInt*>`. `buildFindings`
generates `CList<T>`/`CListNode<T>` for any pointer element, so that one change would type every walk
of these lists end to end and **fold the ten `*_count` fields** added here into their containers. It
was left out because it is ten `revised` field records and the `CCountryList` work was reworking
hand-rolled list triples at the same time; the two want deciding together rather than landing in one
merge from two directions.

## 18. `CTriggeredModifier` keeps two trigger trees, not one

Added 2026-10-06, wave 15. §10 found the `CAndTrigger` at `+0x88` and said the rest of the layout was
unsettled. The rest of it is three lines of constructor, and **there are two of them**.

    CTriggeredModifier : CStaticModifier : CModifier        size 0xC8  (push 0xC8 at 0x5BE74)
      +0x00 .. 0x2B   CModifier                             0x2C
      +0x2C .. 0x47   name          Hoi3CString             0x1C      (CStaticModifier's, size 0x48)
      +0x48 .. 0x87   potential     CAndTrigger             0x40
      +0x88 .. 0xC7   trigger       CAndTrigger             0x40

and that is the whole class: `0x48 + 0x40 + 0x40 = 0xC8`, which is the allocation. The constructor
(rva `0x5B950`, **one caller**, at `0x5BE9E`) builds the `+0x48` one first - `mov [esi], 0x15B589C`
at `0x5B9E8` - and the `+0x88` one second, at `0x5BA38`; the destructor (`0x5BA50`) destroys `+0x88`
then `+0x48` before calling `CStaticModifier`'s. **§10's scan could not see the first because it
looked for a `lea` of `+0x88` specifically**, which is a gap in that search rather than an error in
its conclusion.

**Which is which comes from `CTriggeredModifier::LoadKey`** (rva `0x5BAC0`), and neither arm parses
anything itself:

    if (key == 0x633 /* potential */)  (this+0x48)->Load(parse)      ; slot 3, at 0x5BAE2
    if (key == 0x321 /* trigger   */)  (this+0x88)->Load(parse)      ; slot 3, at 0x5BAF5
    else                               CModifier::LoadKey(parse, key)

So the sub-object `BuildTriggeredModifierEntry` walks through slot 11 to print `"%d / %d"` into
`modifier_strip` is the **`trigger`** block's, not the `potential` block's. **The panel's "n of m
conditions met" counts the conditions for the modifier to *apply*, and says nothing about whether it
is eligible at all.** That `+0x88` is the one the gui takes is now settled from two directions: the
token, and §10's own `lea`.

What the engine does with the `potential`/`trigger` distinction is **not** read here; only the
offset-to-keyword mapping is.

`CStaticModifier` is declared at the same time because nothing laid it out and `CTriggeredModifier`
derives from it: size `0x48` off `push 0x48; call operator_new` at `0x5A54A` inside
`LoadModifierDefinitions` (`0x5A490`), and `name` at `+0x2C` from the in-place empty-short-string
triple followed by `std::string::assign`, which both construction sites do identically.

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

**Wave 15's sections were transcribed the same way**, 2026-10-06, and the `revised` rows of each
fragment were verified off the bytes by the collecting session before the wave was merged - which
is what caught the one correction to a published claim that wave made.

