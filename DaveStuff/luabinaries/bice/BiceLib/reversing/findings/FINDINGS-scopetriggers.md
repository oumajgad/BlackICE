# The scope and set triggers, and what `ally` really scopes to

The grammar was read (`findings/FINDINGS-script.md`), the tooltips were read
(`findings/FINDINGS-guilive.md`), and wave 11 read the evaluation *machinery* -
`CEventScope`, `MakeScope`, the four composites, slots 10 and 11
(`findings/FINDINGS-triggereval.md`). This is the **content** of slot 6 for the conditions
that quantify over a set or test a relation, plus the loose end wave 11 deliberately
refused to name.

Addresses are **rvas** against an image base of `0x400000`, as everywhere in this folder.
Where a VA appears it is written as one and said to be one.

---

## 1. `ally` scopes to an ally. The record already said so, in the third place nobody greps

**`CCountry +0xF88` is the `Allies` `CCountryList`.** `confirmed`, five ways:

1. **`CCountry::GetAllies`**, VA `0x4E6A20` (rva `0xE6A20`), is `lea eax,[ecx+0xF88]; ret` and
   nothing else. It is a **registered Lua accessor** - `ghidra/luabind.json` carries the
   registration as `CCountryList& GetAllies(CCountry&)` with the
   `return_clausewitz_iterator` policy.
2. **`CCountry::CalculateIsAllied`**, VA `0x4E6A30` (rva `0xE6A30`), `bool
   CalculateIsAllied(CCountry const&, CCountryTag)`, walks that list on `node->+0xC`
   comparing `node->+4` with the argument's id. This is the function
   `findings/FINDINGS-triggereval.md` §7 found and called "an 'is this tag in the list'
   membership test" without knowing its name.
3. **`CCountry::GetNumOfAllies`**, VA `0x4E2190` (rva `0xE2190`), is
   `mov eax,[ecx+0x1064]; ret` - and the append to `+0xF88` in
   `CCountry::RebuildNeighbours` **increments `+0x1064`** two instructions earlier, at
   `0x4E3290`.
4. The append is gated on **`CDiplomacyStatus +0x14`**, which
   `CDiplomacyStatus::HasAlliance` (VA `0x494660`) tests with
   `cmp dword [ecx+0x14], 0; setne al; ret` - and which the event language's own
   `alliance_with` trigger evaluates (§4 below).
5. The script keyword **`num_of_allies`** (`CNumOfAlliesTrigger::Evaluate`, rva
   `0x5D8FD0`) is `countries[scope->country_id]->+0x1064 >= this->+0x40`. The counter the
   `+0xF88` append bumps is the one the language calls the number of allies.

So of the two readings the brief put side by side, **the first is right**: the field is
not what `RebuildNeighbours` makes it look like, because that function does far more than
neighbours. `ally = { ... }` picks a random **allied** country. It does not scope to a
bordering one.

**And this was already in the record.** `ghidra/bicelib_findings.json` - the Lua half of
the fact base, which `buildFindings.py` merges alongside `project.json` - holds
`{"offset": 3976, "name": "Allies", "type": "CCountryList", "comment": "read by
CCountry::GetAllies"}`, and `3976` is `0xF88`. It also holds `Vassals` at `0xF78`,
`NumOfAllies` at `0x1064`, `OwnedProvinces` at `0xCF0`, `ControlledProvinces` at `0xD00`
and `CoreProvinces` at `0xD10`. Wave 11's agent A checked `project.json` and
`BiceLib/GameClasses/CCountry.hpp`, which is what trap 14 tells you to check, and the
answer was in neither.

**Trap 14 needs a third clause.** The fact base has *three* halves, not two:

    grep -n 0xF88 reversing/ghidra/project.json \
                  reversing/ghidra/bicelib_findings.json \
                  BiceLib/GameClasses/*.hpp

and because the Lua half stores offsets as **decimal integers**, a hex grep misses it
entirely. `0xF88` appears in `bicelib_findings.json` exactly once - inside a quoted copy
of `MakeScope`'s own comment. The right query is `python -c` over the JSON, or
`grep 3976`. That is the whole reason a settled fact survived a wave as an open question.

A smaller consequence: `+0xF88`'s siblings make the stride obvious. `CCountry` carries a
run of `CCountryList`s 0x10 bytes apart - `+0xF78` Vassals, `+0xF88` Allies, `+0xF98`
non_hostile_countries, `+0xFA8`, `+0xFB8`, `+0xFC8`, `+0xFD8` Neighbours, `+0xFE8`
ControllerNeighbours - each `{head, tail, count}` with 0x14-byte nodes
`{tagChars, tagId, prev@+8, next@+0xC, byte}`.

## 2. `CCountry::RebuildNeighbours` (rva `0xE21E0`) - nine lists, not two

Extent, both ends verified: `0x4E21E0` to the **single** `ret 4` at `0x4E39B9`.
`retsBefore(0x4E21E0, 0x4E39BA)` returns that one `ret` and nothing else, so the whole
`0x17DC` bytes are one body (not trap 2, not trap 3). Eight `int3` before the entry; four
after the exit, then `0x4E39C0`, the other function `RunDailyPass` calls beside it.

The record's description - "fills a country's two neighbour sets and the two
`CCountryList` they stand for" - is true of one of its three passes.

**Pass 1, the province walks** (`0x4E2421`-`0x4E2E52`). What the old comment described:
`OwnedProvinces (+0xCF0)` -> `neighbours (+0xF58)` and `+0xFD8`, marking the owner of each
adjacent province **whose owner and controller agree**; `ControlledProvinces (+0xD00)` ->
`controller_neighbours (+0xF68)` and `+0xFE8`, marking the controller of each adjacent
province owned by somebody else. This pass also recomputes a block of per-country
counters in the `+0x1048`..`+0x107C` range, of which only `NumOfPorts (+0x105C)` is named.

**Pass 2, the whole country database** (`0x4E318E`-`0x4E3566`). One
`CDiplomacyStatus* = country->+0xE28[other]` per other country with owned provinces, and a
different list per predicate:

| list | gate | append |
| --- | --- | --- |
| `Allies +0xF88`, `++NumOfAllies +0x1064` | `CDiplomacyStatus +0x14` (`alliance`) non-null | `0x4E32E3` |
| `non_hostile_countries +0xF98` | `+0x58` (`co_belligerent`), then the REB/`war` exclusions already recorded | `0x4E338E` |
| `+0xFC8` | `+0x1C` (`guarantee`) non-null, plus a direction test on the relation's `+0xC` | `0x4E3406` |
| `Vassals +0xF78`, `++ +0x1068` | `+0x18` non-null **and** its slot 7 answering token `0x298` (`vassal`), plus a direction test | `0x4E3499` |
| `+0xFA8` | `+0x14` or `+0x18` non-null, **or** the other country sharing our faction (`+0xD8`) | `0x4E3553` |
| `SpyingOnUs +0x1028` | the other country's `espionage (+0x1160)[our id]` having a positive allocation | `0x4E3280` |

The else-arm of the `+0xFA8` test is where `highest_threat (+0x11D8`/`+0x11DC)` is chosen,
by maximum `CDiplomacyStatus +0x5C` (`0x4E34DD`-`0x4E3504`). So the same loop that decides
who is friendly decides who is feared.

**Pass 2b, the faction walk** (`0x4E356C`-`0x4E360B`), and this is the half that matters
for `ally`. After the database loop it walks `country->faction (+0xD8) ->members (+0x28)`
and appends every member but itself to `Allies (+0xF88)`, **skipping any tag already in the
list** (the dedupe walk at `0x4E359C`-`0x4E35B0`) and incrementing `+0x1064` for each one
it does add. `CFaction +0x28` is `Members` by `CFaction::GetMembers` (VA `0xA38F90`), and
`+0x30` is the count by `CFaction::GetNumberOfMembers` (VA `0xA3D780`).

So **`Allies` is everyone we have a bilateral alliance with, plus every member of our
faction.** The dedupe exists because the two usually overlap.

**Pass 3, over the allies list it has just built** (`0x4E3616`-`0x4E370D`). Appends to
`+0xFB8` every ally that is not a `government_in_exile (+0x95)`, whose acting capital is on
the **same continent** as ours (`CCountry::GetActingCapitalLocation` at `0x42F100`, then
`CProvince +0x368`, which `CProvince::GetContinent` names), whose `+0x60C` is at least half
of ours, and which is itself `at_war (+0xACC)`. An AI "allies worth counting on" set;
`inferred`, from the shape, and not named.

### The one mod-facing gap this leaves

`alliance_with = GER` tests `CDiplomacyStatus +0x14` only. `ally = { ... }` draws from a
list that also contains every faction member. **Whether a faction member can lack a
bilateral alliance is a game-rules question these bytes do not answer** - the dedupe
implies the two sets usually coincide. If it matters to a script, the cheap live check is:
in a session, pick a country in a faction, read `CCountry +0xF90` (the allies count) and
`CFaction +0x30` (the member count) and compare both against the set of pairs whose
`CDiplomacyStatus +0x14` is non-null. If `+0xF90` exceeds the bilateral count, faction
membership really does widen `ally`.

## 3. The family, and how it is identified mechanically

The 168-class `CTrigger` family splits cleanly. **Eight classes share both slot 8
(`CAndTrigger::GetText`, `0x5E64C0`) and slot 11 (`CAndTrigger::CountEvaluation`,
`0x5D0CD0`)**, and they are exactly the block-shaped ones: `CAndTrigger`, `CMTTHModifier`,
and the six **scope** triggers `CAnyCoreTrigger`, `CAnyNeighborCountryTrigger`,
`CAnyNeighborProvinceTrigger`, `CAnyOwnedProvinceTrigger`, `CEnemyScopeTrigger`,
`CRegionScopeTrigger`. All six derive from `CAndTrigger` in the RTTI export - which is the
eight holders of `0x5D0CD0` that `FINDINGS-triggereval.md` §9 already counted.

That pair of slots is a usable discriminator: **a trigger that renders and counts like an
AND block is a scope**, and `CContextTrigger` is the seventh (slot 8 the same, slot 11 its
own). The relational leaves - `exists`, `controlled_by`, `owned_by`, `controls`,
`is_core`, `region`, `neighbour`, `alliance_with` - all keep `CTrigger::CountEvaluation`
at slot 11, i.e. they count as one condition.

**`is_ally` does not exist.** It is not among the 152 trigger keywords in
`FINDINGS-script.md`'s table and there is no `CIsAllyTrigger` in the RTTI export.
`alliance_with` is the keyword, and `CCountry::CalculateIsAllied` is the C++ predicate it
amounts to.

### Slot 7 is "take your argument", and it writes the `THIS`/`FROM` flags

`CTrigger`'s own slot 7 is the empty `ret 0x104` stub at rva `0x15FF0`.
`CTrigger::LoadKey` (`0x5C8D10`) calls the slot exactly once, at `0x5C8E6F`, having copied
`0x104` bytes of `{SaveToken token; char text[0x100];}` from `parse+0x228` onto the stack.
So slot 7 takes the token and the raw text of the key and is the leaf's own argument
parser. Recorded as `LoadArgument`.

**The shared country-tag implementation is rva `0x5E8F40`:**

    if (key == 0x377 /* this */) { this->arg_is_this (+0x18) = 1; return; }
    if (key == 0x34F /* from */) { this->arg_is_from (+0x19) = 1; return; }
    tag = CCountryDataBase::GetTag(g_CCountryDataBase (0x1A855A4), &local, &text);
    this->+0x40 = tag.chars;  this->+0x44 = tag.id;

It is **slot 7 in sixteen tables** - `CAllianceWith`, `CCasusBelli`,
`CCountryUnitsInProvince`, `CGrantsMilitaryAccess`, `CGuarantee`, `CHasWarGoal`,
`CIsPossibleVassal`, `CNeighbour`, `CNonAgggressionPact`, `COwnedBy`, `CTag`, `CThreat`,
`CTruceWith`, `CUndeclaredWarWith`, `CVassalOf`, `CWarWith`. Twelve derive from
`CTagTrigger` (inheritance); the other four derive straight from `CTrigger` and are a fold
of an identical body. **Trap 4:** that is why it is recorded class-free, as
`TriggerLoadCountryTagArgument`, and why `CTrigger` slot 7 carries the slot name instead.

This closes two of `FINDINGS-triggereval.md` §8's open items. `CTrigger +0x18` is
**`arg_is_this`** and `+0x19` is **`arg_is_from`** - the word the base constructor zeroes
is two bools, and the "no reader found" was a scan that could not see the three-way branch
at the top of five different leaves. `confirmed`: the writer is gated on the two tokens
`project.json` already names `this` and `from` in `MakeScope`'s switch.

**But what `arg_is_this` resolves to is not uniform**, which is worth a script author's
attention:

- `alliance_with` and `controlled_by`/`owned_by` go through **`EventScope_GetCountryTag`**
  (`0x5C1A40`), which falls back on a province's owner when the scope names no country.
- `neighbour` and `is_core` read **`scope->this_scope (+0x38) ->country (+0x10/+0x14)`**
  directly, so on a province-only scope the `THIS` form yields `"---"`/0.

`FROM` is uniform: every reader takes `this_scope`'s `from_country`, i.e. **off the
original scope, not off whatever context the condition is nested inside.**

## 4. The relational leaves, one line each (all `confirmed`, all single-holder slot 6)

| keyword | class | rva | what it does | empty / degenerate case |
| --- | --- | --- | --- | --- |
| `exists` | `CExistsTrigger` | `0x5DA1A0` | two forms. `exists = TAG`: `countries[this->+0x48]->NumberOfOwnedProvinces (+0xCF8) > 0`, **ignoring the bool at `+0x40`**. `exists = yes\|no`: the same test on the *scope's* country, compared with `+0x40` | no province scope involved at all |
| `controlled_by` | `CControlledByTrigger` | `0x5DFAB0` | `province->controller_id (+0x338)` against the argument; four arms - `THIS`, `FROM`, a literal tag, and **a keyword arm that compares the controller with the owner** (`this->+0x44` byte set) | **false** when `scope->province == 0` |
| `owned_by` | `COwnedByTrigger` | `0x5DF250` | the same body with `owner_id (+0x330)` | **false** when `scope->province == 0` |
| `controls` | `CControlsTrigger` | `0x5D5F60` | `provinces[this->+0x40]->controller_id == scope->country_id`. The province comes from the **trigger**, so it works in a country scope and ignores any enclosing province scope | - |
| `is_core` | `CIsCoreTrigger` | `0x5D6660` | walks `CProvince::cores (+0x344)` of `this->+0x40 ? this->+0x40 : scope->province`, matching `node->+4` against the resolved tag | **false** on an empty cores list, tested before the first dereference |
| `region` | `CRegionTrigger` | `0x5E55E0` | walks `CProvince::regions_first (+0x358)` comparing `node->+0` with `this->+0x40`, which is a **`CRegion*`**, not a name or an id | **false** on an empty list and on province 0 |
| `neighbour` | `CNeighbourTrigger` | `0x5E9000` | `countries[other.id]->neighbours (+0xF58) [scope->country_id] != 0` - it indexes **the other country's** byte array with **our** id | - |
| `alliance_with` | `CAllianceWithTrigger` | `0x5EF5A0` | `us->+0xE28[other.id]->alliance (+0x14) != 0`, i.e. exactly `CDiplomacyStatus::HasAlliance`. **Factions are not consulted** | - |

Two of those deserve a sentence more.

**`controlled_by`'s fourth arm** is a real keyword form that asks "is this province not
occupied", and which keyword selects it was *not* read - `CControlledByTrigger`'s own slot
7 at `0x5DF9D0` is the loader and was not decoded. Reported, not named.

**`neighbour`'s direction matters** because `+0xF58` is not symmetric: it is filled from
the provinces a country **owns**, so an occupier lands in `controller_neighbours (+0xF68)`
instead, and two countries bordering each other only across an occupied province are in
neither.

## 5. The scope triggers - what set, where it lives, what is tested, and the empty case

All six share one shape: **copy the scope** with `CEventScope::CopyConstruct` (`0x3C850`),
walk a set, overwrite one or two fields of the copy per member, and AND the children
against it through `[vftable+0x18]`. The **first** member on which every child answers true
wins. No heap allocation, no state kept between calls, no cache - consistent with
`FINDINGS-triggereval.md` §6.

| keyword | class | rva | the set, and where it lives | what it rebinds | empty set | no children |
| --- | --- | --- | --- | --- | --- | --- |
| `any_owned_province` | `CAnyOwnedProvinceTrigger` | `0x5DD460` | `CCountry +0xCF0` (`OwnedProvinces`), nodes `{id, ?, next@+8}` | `province` only (`copy+0x28 = provinces[node->+0]->id (+0xD0)`) | **false** | true at the first province |
| `any_neighbor_province` | `CAnyNeighborProvinceTrigger` | `0x5DCCA0` | `CProvinceTemplate +0x90`/`+0x94` via `province->path_node_ptr (+0xD4)`; **0x14-byte edge records, far province's index at edge+4** | `province` only | **false** | true at the first *owned* neighbour |
| `any_neighbor_country` | `CAnyNeighborCountryTrigger` | `0x5E5F30` | `CCountry +0xFD8` (`Neighbours`) | `country_tag`/`country_id`; **`province` is NOT cleared** | **false** | true at the first neighbour |
| `any_core` | `CAnyCoreTrigger` | `0x5E6390` | `CProvince +0x344` (`cores`) of the **scope's province** | `country_tag`/`country_id`; `province` left alone | **false** | true at the first coring country |
| `<region name>` | `CRegionScopeTrigger` | `0x5DC990` | `this->region (+0x40) ->+8`/`+0xC`, a `std::vector<int>` of province ids | `province` only | **false** | true at the first province |
| `enemy` | `CEnemyScopeTrigger` | `0x607980` | **no set** - one rebinding | `combatant (+0x40)` and `country`; `province` left alone | n/a; **false when the scope has no combatant** | **true** |

Four things in that table are worth pulling out.

**`any_core` is a province scope that quantifies over countries.** It takes
`scope->province`, walks the countries that hold a core there, and rebinds `country` to
each. It is the transpose of what the keyword looks like it should mean, and on a
country-only scope `scope->province` is 0, province 0's cores list is empty, and the whole
block is **false**. The country-side mirror is `CCountry +0xD10`, which the Lua half calls
`CoreProvinces`.

**`any_neighbor_province` filters on ownership.** `if (neighbour->owner_id (+0x330) == 0)
continue`, at `0x5DCE25`. Sea zones and unowned land are never visited, so the scope cannot
cross water and cannot see empty land.

**`any_neighbor_country` does not clear `province`.** `CEventScope::MakeScope`'s country
contexts zero it; this one does not (there is no store to `copy+0x28` anywhere in the
body). So a province condition inside an `any_neighbor_country` block still sees the
province the block was entered with - which is either a convenience or a trap depending on
what you meant.

**`enemy = { ... }` only works inside a combat.**

    me = scope->combatant (+0x40)
    if (me == 0) return false
    foe = me->is_attacker (+0x38) ? me->combat (+0x3C)->defender (+0x14)
                                  : me->combat (+0x3C)->attacker (+0x10)
    copy.combatant = foe
    copy.country   = *foe->countries (+0x54)        // the head node's {chars, id}
    return AND over the children

It derives from `CAndTrigger` and shares And's `GetText` and `CountEvaluation`, but there
is no loop: one rebinding and one AND. So `enemy = { }` with no children is **true**, and
an `enemy` block in an ordinary event is **false**.

And **there is no null test on `foe->countries (+0x54)`.** `project.json`'s own note on
that field is "the countries still in the fight; **emptied on the beaten side**", so a
scope reaching this after the other side has been emptied dereferences null at `0x6079C0`.
Not reachable from the loader - it needs a combat scope and a decided combat in the same
frame - but it is in the bytes, and it is the only fault this pass found.

## 6. Every region name is a trigger keyword

`CRegionScopeTrigger` has no entry in `FINDINGS-script.md`'s keyword table because it has
no keyword. Its vftable (VA `0x15F8404`) is referenced from exactly **one** place in the
image, `0x5DC974`, inside its own constructor, and that constructor has exactly **one**
caller: `0x5CAE56`, in `CTrigger::LoadKey`'s unknown-key arm.

The arm runs `0x5CAE1C`-`0x5CAE5D`:

    region = StringHashFind(g_CMap (0x1A8557C) + 0x2A50, keyText)    ; 0x52A710
    if (region != 0) {
        t = operator new(0x44)
        new CRegionScopeTrigger(t, region)                            ; 0x5CAE56
    } else
        goto 0x5CAE62                                                 ; the CContextTrigger arm

`0x5CAE62` is the address `FINDINGS-triggereval.md` §3 already names as the start of the
`CContextTrigger` arm, so **the loader's order for a key that is not in the compiled
trigger table is: region name, then speculative scope resolution, then
`Unknown trigger-type`.** §3 had the second and third steps and not the first.

`project.json` corroborates both halves independently: its `mediterranean_region` entry
says regions are "looked up by name out of `CMap +0x2A50` by the string hash table at
`0x52A710`" and that "the region object carries a `std::vector<int>` of province ids at
`+0x8`/`+0xC`" - which is exactly the vector `CRegionScopeTrigger::Evaluate` iterates. It
also settles what `CMap +0x2A50` indexes, which that field's own comment left open.

The `push 0x44` on the allocation fixes **`sizeof(CTrigger) == 0x40`**, which is why every
leaf's own data starts at `+0x40`.

## 7. `CEventScope +0x40` is the `CCombatant` - and the record said so without recording it

`FINDINGS-triggereval.md` §8 left `+0x40` open: "the constructor's one stack argument, 0 at
28 of the 29 call sites inspected; `0x74501` is the exception". It is the **combat side the
scope is about**, and the exception is the one place a combat raises an event.

**This is trap 14 in its subtler form.** Three `project.json` function entries already say
so in prose - `CCombatModifierTrigger::Evaluate` (`0x607E80`), `CCombatIsConvoyTrigger::Evaluate`
(`0x607F70`) and `CCombatIsWinnerTrigger::Evaluate` (`0x607F90`), the last two calling
themselves the "second" and "third independent witness that a combat trigger's scope holds
the CCombatant at `+0x40`" - while the **field** was never written into `CEventScope`. An
open item in one findings file and a settled fact in three address comments, with nothing
connecting them. This pass is the fourth and fifth witness
(`CEnemyScopeTrigger::Evaluate`, `CCombatHasArmourUnitTrigger::Evaluate`) and the first
time the field itself is recorded.

Every displacement those bodies take off it lands on a name `CCombatant` already has:
`+0x38 is_attacker`, `+0x3C combat`, `+0x54 countries`, `+0xB0 front_line`, and through the
combat, `CCombat +0x10 attacker` / `+0x14 defender` / `+0x2A` / `+0x2B`. Five agreements
with names derived from elsewhere.

Consequence for scripts: **a scope with `+0x40` null makes all eight combat conditions
false**, silently. `MakeScope` never writes the field and `CopyConstruct` copies it, so it
survives every context rebinding - `enemy = { ... }` is the only thing in the language that
changes it.

## 8. Two fields named off the Lua predicates

- **`CDiplomacyStatus +0x14` = `alliance`.** `CDiplomacyStatus::HasAlliance` (rva
  `0x94660`) is `cmp dword [ecx+0x14], 0; setne al; ret`. Three agreeing readers: the
  predicate, `alliance_with`, and the `+0xF88` append.
- **`CDiplomacyStatus +0x1C` = `guarantee`.** `IsGuaranting` (`0x648730`) and
  `IsGuaranteed` (`0x648760`) are the same body twice: both read `+0x1C`, both answer false
  on null, and both compare the relation's `+0xC` with the status's own `+0xC` - `setne` for
  one, `sete` for the other. One pointer, two directions, **no token test**.

So the relation run is `+0x14 alliance`, `+0x18` (see below), `+0x1C guarantee`,
`+0x20 war`, `+0x24 undeclared_war`, `+0x28 nap`.

**`+0x18` is deliberately not named.** `RebuildNeighbours`'s vassal arm requires it
non-null **and** its slot 7 (`[vft+0x1C]`) to answer save token `0x298`, which is `vassal`
in the live token table - and the list it feeds is `CCountry +0xF78`, which
`CCountry::GetVassals` calls `Vassals`. Two routes to "vassal". But `+0xFA8`'s gate accepts
`+0x18` non-null *without* the token test, so the slot can evidently hold more than one
kind of relation, and `+0x14`/`+0x1C` are tested with no token check at all. Reported, not
named.

## 9. Traps hit in this pass

- **Trap 14, twice, and it is the headline.** `CCountry +0xF88` was named `Allies` in
  `ghidra/bicelib_findings.json` and `CEventScope +0x40` was called the `CCombatant` in
  three `project.json` comments. Both were carried as open questions. The lesson is the new
  third clause in §1: the fact base has three halves and the Lua half stores offsets in
  **decimal**, so a hex grep over it is a silent false negative. `CProvince +0x344 cores`,
  `+0x358 regions_first`, `CProvinceTemplate +0x90 edges_begin`, `CCombatant +0x38`/`+0x3C`/
  `+0x54`/`+0xB0` and `CCombat +0x10`/`+0x14` were all already named and all corroborated
  this pass's readings - nine agreements that cost one grep each.
- **Trap 2, three times, and once it is the *lower* boundary.**
  `CAnyOwnedProvinceTrigger::Evaluate` (`0x5DD460`) and `CIsCoreTrigger::Evaluate`
  (`0x5D6660`) each have exactly **one** `int3` before the entry, with the previous
  function's `ret 0x10` / `ret 0x104` immediately before it.
  `CAnyNeighborProvinceTrigger::Evaluate` (`0x5DCCA0`) has three. In all three the boundary
  is established by the preceding `ret` plus a fresh `push ebp` **and** by the vftable
  naming the entry - not by a padding run, which the brief's "at least three `int3`" rule
  would have refused. `functionStart` happens to answer correctly on all three, which is
  luck, not evidence.
- **Trap 3, the converse, once and expensively if it had been missed.** Scanning forward
  from `0x5DD460` for a padding run lands at `0x5DDA16`, `0x5B6` bytes later - which
  swallows the whole of **slot 9**, `GetBlockText` at `0x5DD5B0`. The body ends at the
  second `ret 4`, `0x5DD5AD`, three bytes before it. The check that settles it is the one
  trap 3's own entry names: the next slot's body starts there.
- **Trap 4, once, decisively.** `0x5E8F40` is slot 7 in **sixteen** tables. All sixteen
  share `CTrigger`, so `mergeFindings`'s fold test (`FOLDED = 8` plus `related()`) does not
  refuse it - but twelve are `CTagTrigger` descendants and four are not, so no one class
  owns it. Recorded class-free. `CFaction::GetMembers` is the same hazard from the other
  side: its body is already in `project.json` as **`LeaThisPlus28`**, a fold, and only the
  luabind registration's RTTI type ties that address to `CFaction`.
- **Trap 12, avoided by neighbours rather than by `fieldchain`.** Every field claim here is
  anchored either on a Lua accessor whose whole body is the `lea`, or on a register whose
  neighbours identify the object - `+0x38`/`+0x3C`/`+0x54`/`+0xB0` together are a
  `CCombatant` whatever else they might be.
- **Trap 1**: nothing was lost to it this pass, but `vtable.py` and the RTTI export print
  **virtual** addresses while `project.json` wants rvas, and the two differ by `0x400000` on
  every address in §3-§6.

## 10. What is not established

1. **Which keyword selects `controlled_by`'s owner-comparison arm**, and `owned_by`'s. The
   arm is read; the loaders that set `this->+0x44`'s flag byte
   (`0x5DF9D0`, `0x5DF250`'s twin) were not decoded.
2. **`CIsCoreTrigger`'s literal-tag arm** resolves through `0xA9D390`, read only as far as
   "returns an object whose `+0x44`/`+0x48` is a tag pair". That call is the weakest step in
   §4.
3. **`CDiplomacyStatus +0x18`** - a relation pointer whose token is tested for `vassal` in
   one place and not tested at all in another. Named nowhere, and not named here.
4. **`CCountry +0xFA8`, `+0xFB8` and `+0xFC8`** - three country lists
   `RebuildNeighbours` fills, with their gates read (§2) and no Lua accessor and no other
   reader traced. `+0xFC8` is one of the two guarantee directions and which one was not
   settled.
5. **The `+0x1048`..`+0x107C` counter block** that pass 1 recomputes. Only `NumOfPorts
   (+0x105C)` and `NumOfAllies (+0x1064)` are named.
6. **The 0x14-byte edge record** at `CProvinceTemplate +0x90`. Only `+4`, the far province's
   index, was read; the other 0x10 bytes were not, and the record has no struct for the edge
   itself.
7. **Whether a faction member can lack a bilateral alliance** - the one question in §2 that
   the bytes do not decide. The live check is in §2.
8. **Deliberately skipped**, and named rather than rounded up: the remaining ~140 leaf
   triggers; the slot-7 loaders, slot-8 `GetText` bodies and slot-10 `WalkChildren`
   overrides of the fourteen classes read here; `CCombinedArmsTrigger` (`0x607A00`),
   `CCombatTemperature` (`0x607E50`), `CCombatTerrain` (`0x607DC0`) and
   `CHasCombinedArmsBonus` (`0x607D60`); and the five `GetBlockText` bodies the brief
   offered as a route in - the vftables were cheaper and the rendering side was not needed.

## Frontier

Unnamed and reached from the bodies above. The first group is the one to take first,
because **`ghidra/luabind.json` already holds a name, a class and a signature for every
one of them** and they are two or three instructions each: `0xE6A10`
(`CCountry::GetVassals`), `0xE6A20` (`GetAllies`), `0xE6A30` (`CalculateIsAllied`),
`0xE2190` (`GetNumOfAllies`), `0x94660` (`CDiplomacyStatus::HasAlliance`), `0x648730` /
`0x648760` (`IsGuaranting` / `IsGuaranteed`), `0x649C90` (`IsFightingWarTogether`, which
reads `+0x58` and so corroborates `co_belligerent` from a third side), `0x64A3F0`
(`HasMilitaryAccess`, `+0x4C`), `0x1010D0` / `0x5010C0`
(`GetNumberOfOwned/ControlledProvinces`), `0x3A660` / `0x17AE0` / `0xC3040`
(`GetOwnedProvinces` / `GetControlledProvinces` / `GetCoreProvinces`), `0x63D780`
(`CFaction::GetNumberOfMembers`), `0x1235E0` (`CFaction::GetFactionLeader`, which returns
the **first member** of the list - `cmp [ecx+0x30],0; mov eax,0x170CF48; je; mov
eax,[ecx+0x28]`).

Then: `0x12A710` (the `CMap +0x2A50` by-name lookup, i.e. how a region name becomes a
scope), `0x69D390` (the tag resolution `is_core`'s literal arm uses), `0xE39C0` (the other
function `RunDailyPass` calls beside `RebuildNeighbours`), the slot-7 loaders `0x5DA0D0`,
`0x5DF9D0`, `0x5D6500`, `0x5E5550`, `0x5D1400`, `0x5D1450`, `0x5D1480`, the slot-8
`GetText` bodies `0x5DA210`, `0x5DFC30`, `0x5DF3A0`, `0x5D6020`, `0x5D6910`, `0x5E56C0`,
`0x5E9070`, `0x5EF620`, the slot-10 overrides `0x5DF8A0` and `0x5EFB60`, and the unread
combat leaves `0x607A00`, `0x607D60`, `0x607DC0`, `0x607E50`, `0x607FD0`.

---

## Two disagreements with the record, reported and only half-redefined

| record | evidence against |
| --- | --- |
| `CCountry +0xD00 province_ids`, whose comment says "**Whether it is the owned or the controlled provinces is not established**" | `CCountry::GetControlledProvinces` (VA `0x417AE0`) is `lea eax,[ecx+0xD00]; ret`. It is the controlled provinces, and `+0xD08` is the CList's count (`GetNumberOfControlledProvinces`, VA `0x5010C0`). The earlier inference from the `+0x610` test was right |
| `CCountry +0xD10 claims`, "Named from that use; no loader key was checked" | `CCountry::GetCoreProvinces` (VA `0x4C3040`) is `lea eax,[ecx+0xD10]; ret`. These are HoI3's **core** provinces, the country side of `CProvince +0x344 cores` |

Both are revised **in their comments only**, deliberately. The Lua half already spells them
`ControlledProvinces` and `CoreProvinces`, and `buildFindings.py` prefers that name and
folds `project.json`'s into the comment - so those are the names Ghidra already shows, and
renaming here would be churn. What needed fixing was two sentences claiming a question was
open.

A third, acted on by the collecting session rather than by this file: the three recorded
combat triggers at `0x607E80`, `0x607F70` and `0x607F90` type their second parameter
`void* scope` and can now take `CEventScope*`.

---

## Transcription note

Read and written by wave 12's agent B; transcribed by the session that collected the wave,
because an agent's `Write` is refused for this path.

The headline was spot-checked before transcription and is **confirmed in all three parts**:
`CCountry::GetAllies` at VA `0x4E6A20` decodes to exactly `lea eax, [ecx + 0xf88]; ret`
followed by five `int3`; `ghidra/bicelib_findings.json` holds
`{"offset": 3976, "name": "Allies", "type": "CCountryList", "comment": "read by
CCountry::GetAllies"}` at `structs[64].fields[50]`, and 3976 is 0xF88; and a hex grep for
`0xF88` across `project.json` and the `GameClasses` headers returns **exactly one** hit -
inside `CEventScope::MakeScope`'s own comment, which is the very place wave 11 found the
field and declined to name it. The third clause has been added to `TRAPS.md` trap 14.

So the brief put two readings side by side and the first is right: `ally = { ... }` scopes
to a random **allied** country. The field is not what `RebuildNeighbours` makes it look
like, because that function fills nine lists rather than two.
