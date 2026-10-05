# The three halves of the fact base, reconciled

Wave 13 agent A, 2026-10-05. Addresses are **rvas** against an image base of `0x400000` unless a
line says VA. Tooling: `scripts/reconcileFacts.py` (`--extras`, `--disagree`, `--accessors`,
`--grep`, `--json`) and `scripts/crossFragments.py`.

## The shape of the 713

`ghidra/project.json` has 173 structs and 2,232 fields; the generated record
(`ghidra/bicelib_findings.json`) has 249 and 2,863; **713 fields across 115 structs** are in the
second and have no field record in the first. Grouped by where they come from, the number
collapses:

| provenance | count | is it a fact about the game? |
| --- | --- | --- |
| **inherited** | 386 | **no.** Ghidra has no inheritance between structures, so `buildFindings.py` copies a base's fields onto each derived struct |
| **generated `CList` plumbing** | 216 | **no.** The one recorded `CList` shape stamped onto 28 instantiations, plus the 26 `CListNode<T>` types the build makes so a node's `data` has a type |
| **Lua accessor** | 93 | yes |
| **Lua `def_readwrite`** | 18 | yes |

**That is the answer to why the unit classes keep looking unread, and it is not that they are
unread.** `CAir` 60, `CArmy` 59, `CNavy` 59 are `CUnit`'s fields; `CShip`/`CWing`/`CRegiment`
26/26/25 are `CSubUnit`'s; `CAirOrder`/`CMoveOrder`/`CNavalOrder`/`CNullOrder`/`CSupportAttackOrder`
11 each are `COrder`'s; the three `CConstruction` kinds 10 each are `CConstruction`'s. Not one of
those 386 is a claim about anything; they are the derived struct being laid out so it reads. A count
of "fields the generated record has and we do not" is therefore **not** a measure of unread layout,
and taking it for one is how `CAir` got onto a queue.

The 216 are the same kind of artefact one level down. `CList` is recorded once, size `0x10`, and the
build lays that shape onto every instantiation a field names - `CList<CUnit*>`,
`CList<CMinister*>`, `CUnitList` and 25 more - four fields apiece, plus four on each generated node
type. They exist so that `node->data->field` decompiles instead of stopping at an untyped word.

**So the actionable set is 111, not 713** - and of those, 67 are on a struct `project.json` already
records, which is what `struct_fields` can land. The other 44 are on 18 structs with no record at
all, and a fragment cannot create one: `mergeFindings` refuses a field on a struct it has never
heard of. Those 18 are listed under *What was skipped*.

### Verdict per group

- **Free and trustworthy (67, landed).** `luabindExtract.accessor_field` accepts a body of
  **exactly two instructions** - one read of a member and a bare `ret` - or one of three strict
  by-value shapes. The whole function is the offset, which is the strongest kind of field evidence
  available here, and it is machine-checkable: `reconcileFacts.py --accessors` re-derives all
  **207** accessor-derived field offsets from `hoi3_tfh.exe` over 173 distinct addresses, and **all
  207 agree**. The other 20 Lua fields are `def_readwrite`, where the offset is a constant in the
  registration itself and there is no body to check.
- **Free but unchecked: none**, in the sense the brief meant. There is no Lua field whose offset
  could not be re-derived. What *is* unchecked is the **meaning** of each: the name is the one the
  game registered, and nothing here tests that the name describes the field's behaviour. Where that
  mattered it was read - below.
- **Disagrees with something: 108 offsets**, handled in the next section.

### The one thing a reader must not conclude from a `lea`

A two-instruction accessor can be, and often is, **folded by the linker** across classes with
nothing to do with each other. That moves the risk entirely onto the **function's** name and never
onto the field: MSVC emitted `mov eax,[ecx+0x30]` *from `CFaction`'s own source*, and ICF merging it
with `CLicenceTechnologyAction`'s identical getter afterwards says nothing about either class's
layout. So the field is `confirmed` and the function has to stay class-free. Of the 173 accessor
addresses, **29 carry more than one luabind registration**.

## The 108 disagreements

`reconcileFacts.py --disagree` prints them with a `spelling` / `READ IT` mark. **71 are the same
word spelled differently** and inflating them would bury the rest: `cost`/`Cost`,
`country_tag`/`CountryTag`, `is_ship`/`isShip`, `manpower`/`Manpower`, `max_ic`/`MaxIC`,
`mobilised`/`isMobilized`. The classifier normalises case, punctuation, a leading
`is`/`has`/`can`/`use`, and `-ise`/`-ize`.

Of the 37 it marks `READ IT`, **21 are still vocabulary** once read - two names for one thing, where
neither is wrong and in several cases *ours* is the more informative one:

| | |
| --- | --- |
| `CDiplomacyStatus +0x38` | `relation` against `Value`. Ours is better; the game's is vague |
| `CIdeologyGroup +0x58` | `position_x` against `Position`. Ours says which of a pair |
| `CSubUnitDefinition +0xEC` | `max_strength` against `DefaultStrength`. Ours is the key in the unit file |
| `CSubUnitDefinition +0x11C` | `defensiveness` against `Defensivness` - the game's own typo |
| `CSubUnitDefinition +0x2D` | `is_land` against `isRegiment`; a regiment *is* the land subunit kind |
| `CCountry +0x1008` | `enemies` against `CurrentAtWarWith` |
| `CConvoy +0x90`/`+0x94` | `transports_wanted`/`escorts_wanted` against `Desired...` |
| `CTradeRoute +0x54` | `disabled` against `isInactive` - same polarity |
| `CDiplomacyStatus +0x58` | `co_belligerent` against `isFightingWarTogether`; `FINDINGS-trade2.md` found it set when either country joins the side of a war the other is on, which is what fighting a war together is |

**Important, because the Lua name is the one that reaches Ghidra.** `buildFindings.merge_fields`
resolves a collision by priority - 0 `def_readwrite`, 1 accessor, 2 a `GameClasses` header, 3
everything else - and demotes the loser into the winner's comment as `BiceLib: <name> ...`. So the
game's name always wins and `project.json` can hold a better name that nobody ever sees in a
decompilation. That is an argument for making the record *agree* rather than for arguing with it,
which is what the revisions below do.

### The eight that were substance

Six of these were never a question of wording.

**`CCountry +0x604`: `base_ic` is wrong, `TotalIC` is right. `confirmed`.**
`CCountry::UpdateIC` writes the summed province base to **both** `+0x604` and `+0x60C` from one
register (`mov [ebx+0x604],eax` at `0xF0F9D`, `mov [ebx+0x60C],eax` at `0xF0FA3`) and then never
touches `+0x60C` again. `+0x604` alone is then scaled by
`(1000 + countryValues[GLOBAL_IC] + technologyStatus.ic_bonus) / 1000` and floored at 1
(`0xF0FA9`-`0xF0FEB`), cut to what the metal and energy stockpiles support (`0xF14A6`), and finally
topped up with the resource-free lend-lease IC (`0xF14C1`). So **`+0x60C` is the base and `+0x604`
is the total actually delivered** - the exact opposite of what the two names said. `base_ic` came
from `BiceLib/Hooks/HookedPatches.cpp:73`, not from a reading.

**And this settles the live question about the two triggers, off the bytes:**

- `CTotalICTrigger::Evaluate` (rva `0x1FEB50`) does `cmp dword [country+0x604], eax` at `0x9FEB8A`.
  The script keyword **`total_ic` reads TotalIC**, so the keyword and the Lua accessor are the same
  word for the same field.
- `CEnemyIcRatioTrigger::Evaluate` (rva `0x208070`) reads `[country+0x60C]` at `0xA080E8` and again
  at `0xA0810A` for each enemy off the `+0x1008` list. **`enemy_ic_ratio` compares MaxIC** - raw
  province IC on both sides, before the global and technology scaling, before the resource cap and
  before lend-lease. For the mod that is a real consequence: `enemy_ic_ratio` is not a ratio of the
  IC either country actually runs on.

Both recorded names are defensible for `+0x60C`; only `+0x604` was wrong, and only in a way that
mattered.

**`CCountry +0xF34`/`+0xF38`: `has_faction`/`faction_leader_tag` are wrong. `isSubject`/`Overlord`
are right. `confirmed`.** `fieldchain.py --field 0xF38 --writes` returns four stores and they are all
in one function plus its two callers. That function is **rva `0xEDD80`**, now recorded as
`CCountry::UpdateSubjectStatus`. It:

1. clears `+0xF34`, writes `'---'` (`0x2D2D2D`) to `+0xF38` and 0 to `+0xF3C`;
2. walks the country's own diplomacy array (`+0xE28`..`+0xE2C`, indexed by the other country's id)
   and reads each status's relation at **`+0x18`** - the field `project.json` already names
   `dependency`, "the pair's overlord/puppet relationship";
3. calls that relation's **vftable slot 7** and compares the answer with **`0x298`**, which
   `ghidra/saveTokens.json` gives as token 664 **`vassal`**;
4. then tests the relation's `+0xC` against the status's own `+0xC` - the same
   one-pointer-two-directions test `IsGuaranting`/`IsGuaranteed` use on `+0x1C`;
5. on a match sets `+0xF34` to 1 and copies that country's tag out of the database (`[0x1A855A4]`,
   `+0x16C` indexed by the id) into `+0xF38`/`+0xF3C`.

Its four callers are `CDependency::Activate` (`0xA477D1`, `0xA477EF`) and CDependency slot 11 at
`0xA47800` (`0xA47873`, `0xA47891`), once per side each - which closes that entry's own "also calls
0x4EDD80 on each country". **Faction membership is a different field**: `CCountry +0xD8` is the
`CFaction*`. The recorded reading of `CCountry::IsSameSide` survives intact - a shared `+0xF3C` does
make two countries the same side; it does so because they share an **overlord**.

`UpdateSubjectStatus` takes the country in **EDI** with nothing on the stack and a bare `ret`, so it
is `__cdecl` with the receiver placed, not `__thiscall` (trap 11).

**`CCountry +0xD00`/`+0xD10`: `province_ids`/`claims` -> `ControlledProvinces`/`CoreProvinces`, and
`void*` -> `CList<int>`.** Both entries' own comments *already said so in bold prose* and left the
key alone - trap 14's fourth question, answered inside a single entry. `claims` is EU3 vocabulary;
HoI3 calls these cores, and HoI3 also has claims in the peace machinery, so the two must not be
conflated. Retyping them to the embedded `CList<int>` also explains `+0xCF8` and `+0xD08`: they are
the lists' own `count` members, not separate fields, which is why `buildFindings` folds them into the
host's comment.

**`CCountry +0x1184`: `void*` is wrong - it is an embedded object.**
`CCountry::GetStrategicWarfare` (rva `0x2F280`) is `lea eax,[ecx+0x1184]; ret` registered as
returning `CStrategicWarfare&`, and a `lea` cannot be a pointer load. The Lua half gives that class
`+0x8 ConvoyImpact`, `+0xC AlliesImpact`, `+0x10 BombingImpact`, and `CStrategicWarfare::LoadKey`
(rva `0x1309B0`) has exactly three keys - `convoy`, `alliance`, `ground_bombing` - which is an
independent corroboration from the loader side. The recorded account survives: `ResolveConvoyRaid` at
`0x5D1FFB` does `lea edi,[country+0x1184]` and calls `0x130600`, which allocates an eight-byte node
and links it, so the series the strategic-warfare screen draws lives *inside* the object.
`convoy_damage_statistics` named one series the object owns, not the field.

**`CCountry +0x11D8`: `int` is wrong.** `CCountry::GetHighestThreat` (rva `0x1074F0`) is
`lea eax,[ecx+0x11D8]; ret` returning `CCountryTag const&` - eight bytes, letters here and the id at
`+0x11DC`, which is the shape the entry already described and the initialiser it already quoted
(`'---'`). With `int` on it every read of the id half decompiled as an unnamed offset past a scalar.

**`CProvince +0x5C` and `CMapProvince +0x5C`: `infrastructure` is ambiguous between two things the
game distinguishes by accessor.** `CProvince::GetMaxInfrastructure` (rva `0x6C360`) copies `+0x5C`
out as a `CFixedPoint`. `CProvince::GetInfrastructure` (rva `0x94570`) is a different and much longer
function that **does not read `+0x5C` at all**: it takes the province's modifier array at `+0x114`
and computes
`values[MODIFIER_INFRASTRUCTURE] * (1000 + values[LOCAL_INFRASTRUCTURE] + values[GLOBAL_INFRASTRUCTURE]) / 1000`,
floors it at a cached constant and clamps it at **1000**. Two accessors, two quantities. That clamp
also fixes the scale, together with the recorded live check (100.00% of 10,642 provinces' `infra`
keys agreeing with `infra * 100`): `+0x5C` is thousandths of full infrastructure, 1000 being 100%,
and `infra = 10` in history is the maximum. The unit AI's thresholds then read as 20% and 30% of full
infrastructure. **RTTI has `CMapProvince` deriving from `CProvince` at offset 0, so the two records
are one field** and both are revised; leaving one would make the record contradict itself, since one
entry carries "the full account" and the other points at it.

**Two more, read but not revised**, because the Lua side is better and the change is cosmetic:
`CAIStrategy +0xE4` (`area_theatres_first`, `CTheatre*`, against `Theatres`, `CList<CTheatre*>`) and
`CTechnology +0x2A4` (`void*` against `CList<CResearchBonus>`). These are **framing**, not fact: the
embedded CList begins at the offset, so our record named its `first` member and the game's names the
list. The Lua spelling is better because `buildFindings` then lays `CList`'s own fields down and folds
`+0xE8`/`+0xEC` into it, which is already what the generated record does today.

## The sixteen accessors, plus one

All sixteen verified from the bytes and still absent from `project.json`; fourteen take a class name,
two must not, and a seventeenth was added.

| rva | body | recorded as |
| --- | --- | --- |
| `0xE6A10` | `lea eax,[ecx+0xf78]; ret` | `CCountry::GetVassals` |
| `0xE6A20` | `lea eax,[ecx+0xf88]; ret` | `CCountry::GetAllies` |
| `0xE6A30` | `mov eax,[ecx+0xf88]` + list walk, `ret 8` | `CCountry::CalculateIsAllied` |
| `0xE2190` | `mov eax,[ecx+0x1064]; ret` | `CCountry::GetNumOfAllies` |
| `0x94660` | `cmp dword [ecx+0x14],0; setne al; ret` | `CDiplomacyStatus::HasAlliance` |
| `0x648730` / `0x648760` | the same body, `setne` / `sete` | `IsGuaranting` / `IsGuaranteed` |
| `0x649C90` | `mov al,[ecx+0x58]; ret` | `CDiplomacyStatus::IsFightingWarTogether` |
| `0x64A3F0` | `mov al,[ecx+0x4c]; ret` | **`ReturnByteAt0x4C`** - class-free |
| `0x1010C0` / `0x1010D0` | `mov eax,[ecx+0xd08]` / `[ecx+0xcf8]` | `GetNumberOfControlledProvinces` / `GetNumberOfOwnedProvinces` |
| `0x3A660` / `0x17AE0` / `0xC3040` | `lea eax,[ecx+0xcf0]` / `[ecx+0xd00]` / `[ecx+0xd10]` | `GetOwnedProvinces` / `GetControlledProvinces` / `GetCoreProvinces` |
| `0x63D780` | `mov eax,[ecx+0x30]; ret` | **`ReturnDwordAt0x30`** - class-free |
| `0x1235E0` | `cmp dword [ecx+0x30],0; mov eax,0x170CF48; je; mov eax,[ecx+0x28]; ret` | `CFaction::GetFactionLeader` |
| `0xEDD80` | SEH prologue, country in EDI, bare `ret` | `CCountry::UpdateSubjectStatus` |

**One was expected to have to stay class-free. There are two, and the one anybody would have guessed
is not the dangerous one.**

- **`0x64A3F0`** is registered as `CDiplomacyStatus::HasMilitaryAccess` *and* fills **slot 70 of
  sixteen graphics classes** - `C2dObject`, `C3dObject`, `C3dVisibleObject`, `CAreaCircleObject`,
  `CCounterObject`, `CCounterStack`, `CHoiAvatar`, `CMasked3dFlag`, `CProjectionObject`,
  `CProvinceCollisionObject`, `CProvinceObject`, `CProvinceWaterObject`, `CShield3dObject`,
  `CShieldObject`, `CSmallAvatarBase`, `CUnitArrow`. Sixteen tables is over `mergeFindings`' `FOLDED`
  threshold, so this one would have been caught.
- **`0x63D780`** is in **no virtual table at all** - the usual holder count answers zero and says
  nothing - and carries **two** luabind registrations, `CFaction::GetNumberOfMembers` and
  `CLicenceTechnologyAction::GetParalell`. Nothing in the existing toolchain would have refused
  `CFaction::GetNumberOfMembers`. This is `LeaThisPlus28`'s exact situation and takes the same answer.

Both fields still land: `CDiplomacyStatus +0x4C hasMilitaryAccess` and `CFaction +0x30
NumberOfMembers`.

**`CFaction::GetFactionLeader` returns the first member, and there is no leader field.** `+0x30` is
`NumberOfMembers` and `+0x28` is `Members`; with members it returns `Members.first`, and because a
`CListNode`'s payload sits at offset 0 and the payload is a `CCountryTag` by value, the node pointer
*is* a `CCountryTag*`. With none it returns the global at `0x170CF48`, whose eight bytes read
`2d 2d 2d 00 00 00 00 00` - the null tag `---` with id 0. Worth knowing before anyone goes looking
for a leader field on `CFaction`.

**`CalculateIsAllied` is a second witness for the list's element type.** It walks from `[ecx+0xF88]`
comparing `[node+4]` against `[ebp+0xC]` and following `[node+0xC]`. Data at `+0`, `next` at `+0xC`
is `CListNode<CCountryTag>` with an eight-byte payload - so `+0xF88` holds tags by value, not
pointers, and `[ebp+0xC]` is the id half of a `CCountryTag` passed by value, hence `ret 8`.

**Five of the seventeen were already named in the record's prose with no entry of their own** - trap
14's third place to look, found by looking. `CDiplomacyStatus +0x14`'s comment names `HasAlliance`
with its rva; `+0x1C`'s names both guarantee predicates with theirs; `CCountry +0xD00`'s names
`GetControlledProvinces` and `GetNumberOfControlledProvinces`; `+0xD10`'s names `GetCoreProvinces`.
And `CDependency::Activate`'s comment points at `0x4EDD80` and says "Only the status writes were
read" - the frontier item that this reading closes.

## Why `CCountry +0xF88` survived a wave, stated once properly

`CCountry::GetAllies` is `lea eax,[ecx+0xF88]; ret` and a registered Lua accessor. The name has been
in the repository the whole time, in `ghidra/luabind.json`, as
`{"offset": 3976, "name": "Allies", "type": "CCountryList"}`. **The Lua half stores offsets as
decimal integers**, so the hex grep trap 14 prescribes is a silent false negative over it:
`grep 0xF88` finds one hit, inside a quoted copy of someone else's comment. Wave 11's agent ran
exactly the prescribed check, found nothing, and correctly declined to name the field; the next wave
was then planned around settling whether `ally = { ... }` scopes to a *bordering* country, which it
does not. `reconcileFacts.py --grep 0xF88` now answers it in one command, in all three halves, with
both spellings.

## Three things the tooling turned up that nobody asked for

**1. `project.json` holds four duplicate field records, and two of them cost typing.**

| | |
| --- | --- |
| `CCountry +0xA8C` | `int neutrality` twice (FINDINGS-numtriggers, FINDINGS-effects) - harmless |
| `CCountry +0x10B8` | `int national_unity` twice - harmless |
| `CDiplomacyStatus +0x14` | `void* alliance` **and** `CAlliance* alliance` |
| `CDiplomacyStatus +0x1C` | `void* guarantee` **and** `CGuarantee* guarantee` |

`merge_fields` keeps one and demotes the other into its comment, and **the `void*` is the one that
wins**: the generated record shows `0x14 alliance | void*` and `0x1C guarantee | void*`. So the
decompilation gets `void*` where the record also holds `CAlliance*`. These were **not** fixed in the
fragment - `replaceField` is textual and matches a field by offset, and with two records at one
offset it could edit the wrong one. The fix is a hand edit: delete the `void*` record of each pair.

**2. Trap 4's holder check has only ever been run against the virtual tables, and the luabind
registrations are a second, independent source of claimants.** `reconcileFacts.py` now reports it.
Five recorded names sit on a body another registration claims:

| rva | recorded as | also registered as |
| --- | --- | --- |
| `0x16000` | `CEffect::GetKeywordToken` | `CAIStrategy::GetPersonality`, `CDiplomaticAction::GetType` |
| `0x944C0` | `COrder::GetStance` | `CDiplomacyStatus::GetWar` |
| `0xC8920` | `CDistributionSetting::GetBasePercentage` | `CDiplomacyStatus::GetTarget`, `CAIStrategy::GetCountryTag` |
| `0x4E9090` | `CAIInvasion::GetTransports` | `CAIForeignMinister::GetProposedWarTarget` (`lea eax,[ecx+0x64]; ret`) |
| `0x2EF70` | `CDate::GetDays` | `CEU3Date::GetTotalDays` - not a fold, a naming mismatch; probably the same class |

The first three each contain an explicit, and now false, negative. `CEffect::GetKeywordToken` says
"nothing outside it holds the body at all". `COrder::GetStance` says "the 37th is some unrelated
class's slot 0" - it is `CDiplomacyStatus::GetWar`, so there are at least two unrelated claimants.
`CDistributionSetting::GetBasePercentage` says "nothing calls it directly, so Lua is its only
consumer", having traced the one registration it came in by; Lua registers that address **three**
times, on three unrelated classes whose `+0x8` is a `longlong`, a `CCountryTag` and a `CCountryTag`
respectively. Same eight bytes, three meanings. **None of these were renamed**: the names are
load-bearing in a lot of prose and the right correction is the maintainer's call. They are a clean
queue item, and the check that found them is one command.

**3. `related()` is near-useless as a fold discriminator.** `mergeFindings.related()` walks RTTI bases
transitively, and nearly every game class descends from `CPersistent`, so `CEffect` and `CAIStrategy`
come back "related". The fold branch is `elif len(tables) > FOLDED and not related(...)`, so it rarely
fires on grounds of relatedness. Worth knowing before trusting a silent pass.

## The tooling gap, closed twice over

`mergeFindings --check` compared **address** entries between incoming fragments (`claimedName`,
`claimedRva`) but never `struct_fields` - so two agents naming one offset differently were neither
refused nor reported and **both records landed for one field**. That is worse than a drop:
`buildFindings` keeps whichever comes first and nothing complains.

`claimedField` is now in `problems()`, comparing **name and type** (a field keeping its name and
changing its type is what added the type to the project.json comparison in the first place), and
`scripts/crossFragments.py` is the same check as a *report*, because an agreement between two agents
is corroboration and `--check` can only say no.

**Running it over `fragments/merged/` proves the gap cost something.** Six field disagreements already
landed:

- `CAIUnit +0x1FC`, `+0x20C`, `+0x21C`, `+0x22C` - `airnaval4.json` says `void *`, `airstance.json`
  says `CList`, both with `revises`. `airstance`'s `CList` is what `project.json` holds today, so the
  better answer won **by merge order**, not by anything checking.
- `CDiplomacyStatus +0x14` and `+0x1C` - `diploaccept.json` (`CAlliance*`, `CGuarantee*`) against
  `scopetriggers.json` (`void*`), neither revising, so **both landed**. Those are two of the four
  duplicates above, now attributed.

Five more pairs agree, including two agents independently deriving `CUnit +0x2D4`/`+0x2DC` and two
independently deriving `CCountry::RebuildNeighbours`.

## Trap 1, twice in one session, and what caught it

Both times a scan returned **zero hits** and both times the method was pointed at the wrong address
space. First a scan of `ResolveConvoyRaid` for `+0x1184` at VA `0x9D1250`, because `TRAPS.md`'s trap
3 table quotes it as `0x5D1250` - which is a **virtual** address; the rva is `0x1D1250`. Then a scan
of the two IC triggers at VA `0x5FEB50` / `0x608070`, because `project.json`'s own entry comments
quote those numbers - and there they are **rvas**, so the VAs are `0x9FEB50` / `0xA08070`. **The
record is not consistent about which it writes in prose; only the `rva` key is reliable.**

What caught it both times was the rule at the foot of `TRAPS.md`: **a negative needs a positive
control.** "No reference to `+0x1184` anywhere in a function the record says appends to it" is not a
finding, it is a broken scan, and the cheapest test is whether the same scan can see something you
already know is there. Published, the first one would have contradicted a correct entry on the
strength of a decode of somebody else's bytes.

A near-miss in the same spirit: `CCountry::UpdateIC`'s comment says the scale factor is
`countryValues[GLOBAL_IC] + technologyStatus[+0x90]`, and the instruction at `0x4F0FAF` reads
`[[country+0xDA8]+0x88]`. The comment is right: `+0xDA8` is the country's modifier values,
`0x88 / 8 = 17` is `MODIFIER_GLOBAL_IC` (trap 5), and the `+0x90` read happens earlier at `0xF0E3B`
and arrives cached in `[ebp-0x18]`, exactly as the `CTechnologyStatus +0x90` entry says. Checking a
new conclusion against the record before publishing it is what stopped that one.

## What was skipped, and why

- **713 fields were not verified.** 602 of them are inheritance and generated `CList` plumbing and
  carry no claim; the instruction was to triage all and verify what matters, and that is what the
  table at the top does.
- **The *meaning* of the 67 additions was not read.** Each one's offset is machine-verified and each
  name is the game's own; what is *not* established for any of them is that the name describes the
  behaviour. For the diplomacy and province set it was read; for `CEU3AI`'s four,
  `CAITechMinister`'s arrays, `CCountry +0x10BC`/`+0x10F4`
  (`accessIdeologyOrganization`/`accessIdeologyPopularity`), `+0x11F8`/`+0x1204` (the two running
  averages) and the rest, it was not.
- **44 Lua fields cannot land**, because `mergeFindings` refuses a field on a struct `project.json`
  has no record for and a fragment cannot add one. They are on 18 structs:
  `CAIEspionageMinister`, `CAIForeignMinister`, `CAIIntel`, `CAIPoliticsMinister`,
  `CAIProductionMinister`, `CAITechMinister` (`+0x54 OwnerAI` on all five ministers, from one folded
  body), `CCallAllyAction`, `CDecision`, **`CGoodsValues`** (7 `def_readwrite` floats: money, fuel,
  crude oil, metal, energy, rare materials, supplies), `CLicenceTechnologyAction`,
  `CList<CSubUnitConstructionEntry>`, `CList<CSubUnitDefinition const *>`, `CResearchBonus`,
  **`CResourceValues`** (6 `def_readwrite` floats: daily expense, daily home, convoyed in, pool,
  daily income, daily balance), `CSendExpeditionaryForceAction`, **`CStrategicWarfare`** (the three
  impacts, corroborated by its own `LoadKey`'s three keys), `CSubUnitConstructionEntry`,
  `CTechnologyFolder`. The 13 `def_readwrite` ones among these are the **strongest** records in the
  whole Lua half - the offset is a constant in the registration - and they are the ones the pipeline
  cannot take. Either `mergeFindings` grows a `structs` key, or someone adds the 18 stubs to
  `project.json` by hand.
- **The 21 vocabulary disagreements were left alone**, and `CAIStrategy +0xE4` and `CTechnology
  +0x2A4`, which are framing rather than fact.
- **The five folded function names were not renamed**, nor the four duplicate field records fixed.
  Both are hand edits to `project.json` and both are queue items with the evidence written down.
- **`CEventScope +0x10` is a lead nobody followed.** The record has `char[4] country_tag`; the Lua
  half types it `CCountryTag&`, which is eight bytes with an id at `+0x14`. If that is right there is
  an unrecorded field at `CEventScope +0x14`, and the scope's tag reads would be comparing the id half
  rather than the letters - which is how every other tag comparison in this image works.
- **Frontier**: `0x647800` (CDependency slot 11, the deactivation twin of `CDependency::Activate`,
  unrecorded), `0x130600` (the eight-byte-node list append inside `CStrategicWarfare`), `0x94570`
  (`CProvince::GetInfrastructure`, the effective-infrastructure computation).
