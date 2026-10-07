# The next wave

**This file holds one thing: the wave that is planned but has not run.** It exists because the plan
used to live in `CANDIDATES.md`, which is five hundred lines of queue and archive, and finding the
plan in it was a search rather than a glance.

The contract, so the two files do not drift:

| | |
| --- | --- |
| **`WAVE.md`** (this file) | the plan for the wave that has **not launched**. Overwritten by the next plan |
| `CANDIDATES.md` | the standing queue and the archive. **A wave's result goes there**, not here, along with the area-level backlog a plan is chosen from |

So: plan here -> launch -> write the result into `CANDIDATES.md` -> replace this file with the next
plan. If this file describes a wave that has already landed, it is stale and `CANDIDATES.md` is the
truth.

---

## Wave 15 - the collectors, the field 77 classes are waiting for, and two things that do not work

> **LANDED 2026-10-06. This file is stale and is kept only as history until the next plan replaces
> it** - which is what the contract above says to do with it. All five briefs ran; the result is in
> `CANDIDATES.md` and the write-ups are in `findings/FINDINGS-faction.md` §§7-12,
> `FINDINGS-triggereval.md` §§17-18, `FINDINGS-numtriggers.md` §9, `FINDINGS-scopetriggers.md` §17,
> `FINDINGS-commands.md` and `FINDINGS-diploaction.md` §31. **Do not launch anything from the briefs
> below** - several of their premises were settled by the wave itself, which is exactly the staleness
> the *Read this before writing the briefs* section warns about. The standing rules at the end are
> still current and are the part worth carrying into the next plan.

Planned 2026-10-06, immediately after wave 14 landed. Wave 14's result is in `CANDIDATES.md`.

**Brief E was added by the maintainer** off the Lua API census, and it is the only brief here that
starts from an observed failure rather than from a hole in the record: `CSetFlagCommand` was tried and
the flag never arrived, and `CSendExpeditionaryForceAction`'s constructor takes no unit. Those two are
worth more than their size suggests, because a bug with a known-good sibling to diff against is the
cheapest kind of question this folder ever gets.

### Read this before writing the briefs

**Wave 14's single biggest cost was stale premises in its own briefs, and the plan it came from warned
about exactly that.** Three of four briefs asserted something the record already held:

- brief B was told to expect an unrecorded `CEventScope +0x14`; it had been recorded for waves.
- brief C was told slots 10 and 11 were "recorded with signatures and neither read". Wave 11 read all
  nine bodies on 2026-10-03, and `FINDINGS-triggereval.md` §6 is *headed* "Slots 10 and 11 - and the
  answer on caching".
- brief D was told `CFaction +0x30 NumberOfMembers` is a field record. It is not, and must not be -
  `Members` is a laid-out `CList`, so `+0x30` already resolves as `Members.count`.

All three agents caught it themselves and redirected, so the cost was bounded - but it was paid three
times. **The collecting session verified the plan's addresses and not its claims about what was
unread**, and the second half is what shapes a brief.

**So: for every deliverable, before writing it into a brief, grep the subject in `findings/` and in
`project.json`'s names *and comments*, not just the rva.** The plan below did that, and it caught one
immediately - see brief A.

### What wave 14 settled - do not redo these

- **The trigger forest's cost is answered.** Nothing is cached, anywhere; `CAndTrigger` is `0x40` and
  has nowhere to put a cache. `and` short-circuits, `or` short-circuits, the `"%d / %d"` tally does
  not. Slot 11 has **one** root, a once-a-game-day panel. Slot 10 has **two**, both in
  `ApplyCountryAIStrategies`. `FINDINGS-triggereval.md` §10-16.
- **A scope switch writes five offsets and nothing else**, and all eleven `CContextTrigger` forms are
  placed. `FINDINGS-scopetriggers.md` §11-16.
- **The faction layer**: `CFaction::AddCountry` (rva `0xF5F30`) is the one gateway, a join creates no
  alliance, and leadership is positional. `FINDINGS-faction.md`.
- **A fragment can declare a struct** (`structs` key), `vftable_slots` is applied to the right table,
  and `checkSignatures.py --candidates` checks an agent's own entries. `fragments/README.md`.
- The polarity flag is **five different mechanisms across ten leaves**, not one; `FINDINGS-triggereval.md`
  §12 has the table, and §6's generalisation is corrected in place.

---

### A. `CValueTrigger` and `CIntTrigger` - one field, 77 classes

**The highest value per unit of work in the image right now, and it is smaller than it looks.**

Wave 14's agent A called this "the single biggest remaining win in this family" and said the blocker
was that *"which body belongs to which class is not settled - neither class has a vftable of its own,
so it has to be argued from which derived classes hold which body, and I did not do it."*

**That premise is false, and this is the check wave 14 kept skipping.** Both bodies are already in
`project.json`, **`confirmed`, read end to end, and correctly assigned**, sourced to
`findings/FINDINGS-numtriggers.md`:

- `CValueTrigger::LoadArgument` rva `0x5D13E0` - *"Slot 7 for the forty `CValueTrigger` leaves, and
  the whole reason their operands are in thousandths"*. `TokenToFixedPoint` into `+0x40`.
- `CIntTrigger::LoadArgument` rva `0x5D1400` - *"Slot 7 for the thirty-seven `CIntTrigger` leaves:
  `atoi`, with no scaling at all"*. Tests `0x377`/`0x34F` for `this`/`from`, then `+0x40`.

So nothing needs deciding. **What is missing is the declarations**, which were impossible until wave
14 and are now a `structs` key away: `CValueTrigger` and `CIntTrigger` are both **absent** from
`project.json` (verified 2026-10-06), `CTrigger` is present at size `0x40` with 6 fields, and
`+0x40` is `value` on both - the record's own `CTechnologyTrigger +0x40` and `CTagTrigger +0x40` are
the same offset for the same reason.

Deliver:

1. **Declare `CValueTrigger` and `CIntTrigger`**, `inherits: CTrigger`, with `value` at `+0x40` -
   typed to match each one's units, and **say in the comment that one is thousandths and the other is
   not**, because that difference is the whole mod-facing point and a modder writing `dissent = 2`
   versus an `atoi` keyword cannot otherwise tell.
2. **Then the leaves.** The record says 40 and 37. `inherits` only works for a base at offset 0,
   which is exactly this shape, so one declaration per leaf places the field on all 77. **Derive the
   membership from the vftables rather than from the counts** - the counts are the record's and are
   what you are checking. `vtable.py --holding 0x5D13E0` and `--holding 0x5D1400` is the command, and
   it takes a **VA**.
3. **Sizes: `0x44` is the right answer only where an allocation says so.** Wave 14 measured the
   distribution from `CTrigger::LoadKey`'s `new`/constructor pairs - `0x44` x 111, `0x48` x 16, `0x40`
   x 10, `0x5C` x 9, `0x4C` x 5, `0x60` x 2, and one each of `0x50`, `0x64`, `0x150` - so **a leaf
   that is not `0x44` has a second field and must not be given a blanket size.** A declared `size` is
   now authoritative **downward** in Ghidra, so a guessed one silently drops whatever Ghidra holds
   past it. Omit it where no allocation was read, and say which you omitted.
4. **`scratchpad/triggersizes.py` from wave 14 produces those 156 pairs in one command** and is worth
   promoting to `scripts/` as part of this. Name it and document it.

Also here, because it is the same kind of work and each is one declaration:
**`CContextEffect`** (spec at `+0x20`, object `0x130`, same `CEventScopeSpec` - wave 14 read it and
did not declare it), **`CTriggeredModifier`** (the embedded `CAndTrigger` at `+0x88`, from
`FINDINGS-triggereval.md` §10), and **`CTrigger +0x3C`** as a *lead only* - cleared by every container
constructor, set to 1 by `CTrigger::LoadKey` at `0x5C915B`, no reader identified and none looked for.

### B. The five collectors - what the weighted walk is actually for

**What the whole slot-10 machinery exists for**, and wave 14 got as close as its steer allowed by
reading the walk from the trigger side.

Five entry points, **all five verified unrecorded in `project.json` 2026-10-06**, all in
`CAIStrategy`'s region, all reached only from leaf `WalkChildren` bodies:

| rva | known from |
| --- | --- |
| `0x4A4F50` | `COwnedByTrigger`'s two converging report paths |
| `0x4A51C0` | `CHasBuildingTrigger` - **the only one handed text** |
| `0x4A5270` | `CRelationTrigger` when the flag is set; the record already says it inserts into a map a `CAIStrategy` owns |
| `0x4A5420` | `CRelationTrigger` when the flag is clear |
| `0x4A5620` | the fifth, caller not yet attributed |

`FINDINGS-triggereval.md` §11-12 is the map to read them against: both roots pass `polarity = 0` and
weights `0x258`/`0xC8`, `CAllianceWithTrigger` negates the weight, `CRelationTrigger` chooses between
two of these five, and the receiver `ebx` is the collector in every leaf.

The questions, in order of value:

1. **What is collected, and keyed by what?** A map insert keyed by country, by province, by strategy
   id? That decides whether the walk is "which countries does this strategy care about" or something
   narrower.
2. **Why five entry points rather than one** - and specifically what `0x4A51C0`'s text argument is
   for, since it is the odd one and the shape to understand first.
3. **What reads the collection**, and when. If it is consumed once per AI rebuild then the weights are
   a one-off scoring pass; if something reads it per decision, the weights are live.

**This is the AI item the steer has held out of five waves**, and it is in this wave deliberately,
**reduced to its trigger-facing half**: you are reading what the trigger walk *writes*, not AI
decision logic. `CAIStrategy::Rebuild` (rva `0x4A5C90`) and `ApplyCountryAIStrategies` (`0x4A62A0`)
are both already recorded and are the boundary - **read up to them and stop.** If the reading turns
into AI policy, note the lead and stop; say so rather than following it.

A loose end this would also close: **the class of the objects holding the two embedded triggers** at
`[esi+0xE40]+0xC4` and `+0x24` of an array element, which wave 14 left because naming them is
AI-side.

### C. The faction leave path, and the rule nobody has written down

**Wave 14's most interesting single leftover, and it is one function read.**

`CDeclareWarAction::Apply`'s call at VA `0xA121CE` passes `(country, 0, 0)` to
`CFaction::AddCountry` on a path **gated by a slot-7 `IsValid` answering false** - which, since
`FINDINGS-faction.md` §1.1 step 3 establishes that calling `AddCountry` with an invalid faction *is*
leaving one, means **declaring war may eject a country from its faction.** That would be a real game
rule that no file states.

What wave 14 could not pin down, and said so: which object that `IsValid` test is on, and the
arithmetic of the two tag pairs at `[esp+0x24]` against the action's `+0x10`/`+0x14`.

Read it, and settle:

1. **Whose faction is being tested, and whose membership is cleared** - the declarer's or the
   target's.
2. **Under what condition**, in terms a mod author can act on. "Declaring war on a faction member
   ejects you" and "declaring war while in a faction ejects you" are very different rules.
3. Whether this is the *only* non-`CFactionAction` route into `AddCountry`. Wave 14 left **six
   unidentified callers**: `0x19360`, `0xD94A0`, `0x14BD00`, `0x14C980`, `0x5A1C60`, `0x5AEBF0`. Even
   classifying them by what they are (loader, action, AI, GUI) without reading each is worth having.

Then, if there is room, **`0x102BC0`** - the capitulation/exile function that holds the faction leader
promotion (`FINDINGS-faction.md` §3). Unrecorded, 7 callers, four `ret`s between `0x50315F` and
`0x5033AD`, so **bounding it is the work** and trap 3 is live. It sets `government_in_exile (+0x95)`
and scales `Manpower` and `officers`. **Take the leader promotion as already read** and do not redo
it.

### D. `CCountryList`, and the fields that cannot land without it

**A tooling-shaped brief, like wave 14's A, and it retires a workaround.**

`CCountryList` has **no layout at all** - verified absent from `project.json` 2026-10-06, and not
special-cased beside `CUnitList` in `buildFindings.py`'s `CList` pass. So `CCountry +0xF88 Allies`,
`+0xF78 Vassals` and the rest **decompile as untyped blobs**, and the count word a condition reads is
unreachable.

Three things, and the order matters:

1. **Give `CCountryList` its layout.** `CList` is already laid out at size `0x10`
   (`first`/`last`/`count`/`flag`), and `FINDINGS-faction.md` §2 establishes the node as `0x14` bytes
   with payload at `+0`, `prev` at `+8`, `next` at `+0xC`, holding `CCountryTag` **by value**. Decide
   whether this is a `structs` declaration, an `inherits: CList`, or a special case in the `CList`
   pass beside `CUnitList` - **and say why**, because the `CList` pass is what generates node types
   and a declaration will not.
2. **Then retire the workaround.** `CCountry +0xF98`/`+0xF9C`/`+0xFA0` are hand-added
   `non_hostile_countries_first`/`_last`/`_count` records - the same thing done by hand, and
   `+0xF98` is typed `CCountryList` while its two siblings are `void*` and `int`. Once the list has a
   layout these should go the way the four `flags_persistent` fields went on 2026-10-05.
   **`mergeFindings`' `structs` key is create-only and cannot delete a field**, so this is a report
   plus a recommended hand edit, not a fix you land.
3. **Check the fold before proposing any deletion.** `ghidra/README.md`'s section on it is
   mandatory reading for this brief: two of wave 14's four agents proposed deleting a correct record
   because they mistook a folded field for an apply-cycle risk. **A field inside a larger typed one is
   not placed at all**, so it cannot conflict - and `project.json` does not show you that.

Also in this brief, and **read this carefully because three of the five items it used to list were
done on 2026-10-06, after this plan was first written** - which is the staleness this file warns about
in its own opening, caught within the hour:

- ~~`CTradeRoute` needs `inherits: CRelation`~~ **done.** It has it, and its `+0xC first_id` /
  `+0x14 second_id` are now folded into the inherited 8-byte tags.
- ~~the two wrong `vftable_rva`s~~ **done**, `CBuildingConstruction` and `CConvoyConstruction`
  corrected to `0x11BDCAC` and `0x11BDD04`.
- ~~the four duplicate `(struct, offset)` records~~ **done.** `CDiplomacyStatus +0x14` is
  `CAlliance*` and `+0x1C` is `CGuarantee*`; there are **zero** duplicate pairs in the record now.
- **Still open: `buildFindings.py` reports neither a duplicate `(struct, offset)` nor a fold.** Both
  are one-line additions. The duplicate reporter **would print nothing today**, which is exactly why
  it is worth adding - it is a guard against them coming back silently, not a backlog report, and a
  duplicate costs more than a duplicate address entry because `merge_fields` quietly keeps whichever
  comes first. The fold reporter is the more valuable of the two: two of wave 14's four agents reached
  a wrong conclusion for want of it. **Report or implement, your judgement, but do not make either
  *refuse*.**
- **Still open and new: `CStrategicWarfare`, `CSubUnitConstructionEntry` and ten more classes are
  reachable from Lua and register fields nobody exercises** - see the census in `ghidra/README.md`.
  `CCountryList` and `CUnitList` are in that list with **zero** registered members, which is an
  independent confirmation of this brief's premise: neither half of the fact base has their layout.

---

### E. Two Lua-reachable things that do not work, or do not make sense

**The maintainer picked both of these off the census of reachable-but-unused classes, and each comes
with a concrete reason.** Everything below was resolved against `project.json` and decoded out of the
executable while this was written; where the record already holds something, it says so, because this
wave's predecessor paid three times for not checking that.

#### E1. `CSetFlagCommand` - posted, and the flag never arrives

**The maintainer tried this years ago and the flag never reached the country.** That is a reproducible
failure with a known-good sibling to compare against, which makes it the most tractable bug-shaped
item on the queue.

What the record already has:

| | |
| --- | --- |
| `CSetFlagCommand::LoadKey` | rva `0x152F30`, **recorded and `confirmed`**: its switch names **two** keys, `country` and `flagType` |
| the vftable | VA `0x15C3E24`, one table, `CCommand` at offset 0 |
| slot 6 `Execute` | rva **`0x152C30`** - **unrecorded, and the target** |
| slot 2 `SaveContents` | rva `0x152E20` - unrecorded |
| `CSetFlagCommand::Clone` | the luabind registration points at rva `0x598420`, which the record **already** holds as `VirtualThunkSlot13` - a shared `mov eax,[ecx]; jmp [eax+0x34]` thunk. **Do not name it for this class** (trap 4); the record is right |

**The controlled comparison, and it is why this brief is cheap.** `CSetVariableCommand` has the
*same constructor shape* - `(CCountryTag, const CString&, CFixedPoint)` against `(CCountryTag, const
CString&, bool)` - its vftable is `0x15C3E64`, `0x40` bytes along from this one, and **the mod uses it
successfully in ten files**:

    CCurrentGameState.Post(CSetVariableCommand(tag, CString("zzDsafe_..."), CFixedPoint(1)))

Its slot 6 `Execute` is rva **`0x1532C0`**, also unrecorded. **Read the two side by side**; two
commands of one shape where one works in production and one does not should give up the difference
quickly.

**One hypothesis is already dead** and is recorded here so nobody re-tests it: *"Lua has no way to
post a `CCommand`"* is false. `CCurrentGameState:Post(CCommand*)` and `CEU3AI:Post(CCommand*)` are
both registered, and the working sibling goes through the first of them.

Three live hypotheses, in the order they are worth testing:

1. **`flagType` is a type, not a name.** The loader's key is `flagType`, and the image has a flag
   *type* database - `LoadFlags` (rva `0x440BC0`) and `CFlagType::LoadKey` (`0x4450B0`), both
   recorded. If `Execute` resolves the `CString` against that database, a flag name that is not a
   registered `CFlagType` resolves to nothing and the command does nothing - silently, which is how
   this engine treats every bad name. **This would explain the symptom exactly**, and BlackICE's
   country flags are arbitrary strings rather than declared types.
2. **The node is created but `is_set` is left clear.** Wave 14 read
   `CHasCountryFlagTrigger::Evaluate` (`0x5E20B0`) and established that it tests
   `found->is_set (+0x1C) != 0`, **not** the node's existence - and that `CFlags` clears the byte
   rather than removing the node. So a flag can be in the tree and answer false. If the command's
   `bool` argument is not landing on `+0x1C`, the flag would be set and invisible.
3. **It writes to the wrong `CFlags`.** `CFlags_AddFlag` is rva `0x4D640`, recorded; a country's flags
   are `CCountry +0x180`, and global and province flags live on other objects.

**The reference implementation that does work is in the record**: `CSetCountryFlagEffect::Execute`
(rva `0x5A4970`), the event language's `set_country_flag`, alongside `CClrCountryFlagEffect::Execute`
(`0x5A49E0`). **Diff the command against the effect** - same end, two routes, one of them trusted by
thousands of BlackICE events.

Deliver: `Execute` read instruction by instruction, named and signed; the same for
`CSetVariableCommand::Execute` as the control; and **a plain statement of why the flag does not
arrive, with what would show it wrong.** If it turns out the command works and the original attempt
was wrong in some other way, say that - it is just as useful an answer and the maintainer has asked
for a negative to carry its control.

#### E2. `CSendExpeditionaryForceAction` - a unit the constructor never takes

**The maintainer's objection: the Lua constructor is `(CCountryTag, CCountryTag)` and takes no unit,
so it is unclear how this is supposed to work at all.** The API itself says a unit is involved, which
is what makes the question sharp rather than rhetorical.

Already settled, decoded 2026-10-06:

| | |
| --- | --- |
| `GetClaimType` | rva `0x63B3D0`, the whole body being `mov eax, [ecx+0x28]; ret` - so **`ClaimType` is `+0x28`**, and luabind's registered offset of 40 agrees |
| its enum | **`TAKE = 0`, `SEND = 1`** - the action is bidirectional, which the class name hides |
| `GetUnit` | rva `0x63B380`, a real body reading **`[eax+0x2C]`** - so **there is a unit field** |
| `GetTag` | rva `0x598400`, a **virtual thunk** - `mov eax,[ecx]; jmp [eax+0x50]`, i.e. slot 20. Unrecorded, and class-free by nature |
| `LoadKey` | rva `0x63B300`, **recorded and `confirmed`**: its switch names **`action` and `unit`** |
| `Apply` | rva `0x6395B0`, **recorded but `inferred`**, and its own comment says *"Not read instruction by instruction; the name is inference from the family"* |

So the shape of the answer is already visible: **`+0x28` and `+0x2C` are fields the save/load path
fills from the keys `action` and `unit`, and the two-tag Lua constructor leaves them at whatever the
constructor sets.** The question is what `Apply` then does with a null or default unit.

The questions, in order of value:

1. **What does `Apply` do when `+0x2C` is null** - which is what a Lua-constructed one will have
   unless the constructor fills it. Does it pick a unit, no-op, or fault? That is the whole of the
   maintainer's question and it is one function read.
2. **Is there any way to set `+0x2C` from Lua?** Nothing registered writes it - `GetUnit` is a getter
   and the constructor takes two tags - so **if there is no setter, the Lua registration is
   unusable by construction** and that is the answer. Say so plainly if it is true.
3. **What `TAKE` versus `SEND` changes**, and which one a two-tag constructor gets.
4. **Read `Apply` properly.** `0xA395B0` to the bare `ret` at `0xA3A853` is **`0x12A3` bytes** - this
   is a big body, so expect **trap 3** and verify the extent with `retsBefore` before trusting any
   interior `ret`. The record already notes it reads `EXPEDITION_INFLUENCE_COST` (diplomacy `+0xAC`)
   and `EXPEDITION_RETURN_TIME` (`+0xB0`), that `EXPEDITION_RECLAIM_TIME` (`+0xB4`) is **not** read,
   that it reaches the unit layer through `0x59A190` eleven times plus `0x4E06F0`/`0x4E0830`/
   `0x4E0860`/`0x5D3840`, and that it keys `OUREXPACC`, `OUREXPDEC`, `EXPOTHER`. **Revise that entry
   from `inferred` to `confirmed` if the reading bears it out, and correct it if it does not** - it is
   the kind of family-inference entry this folder treats as a lead rather than a fact.
5. `CDiplomaticAction::MakeCommand` (slot 6, rva `0x60E890`) is recorded in full and is the post
   route; **its only engine caller is the hourly AI pass at `0x682BC2`**. So if the engine itself only
   ever builds this action from the AI, the AI is where `+0x2C` gets filled, and that is the place to
   look for how a unit is chosen.

**Both of these are mod-facing**, so state the result in terms a mod author can act on: for E1,
whether `CSetFlagCommand` can be made to work from Lua and how; for E2, whether
`CSendExpeditionaryForceAction` is usable from Lua at all. A clear "this registration cannot be used
from script, and here is the instruction that decides it" is a complete answer to either.

## Deliberately not in this wave

- **`CCasusBelliType`'s 22 loader offsets.** Landable now, and reproducible in one command - token
  table `0x416924`, jump table `0x4168E0`, base token `0x78D` - but it is 22 rows of its own and wants
  one agent whole rather than a corner of another brief.
- **`CTrigger +0x1C[2]`.** A `std::vector`-shaped container of two `0x10`-byte elements whose
  ctor/dtor (`0x9DB0`, `0xC480`, both unrecorded) are referenced from **200** sites. Naming it needs
  the *container* identified, not the trigger, and a displacement scan provably cannot settle it -
  wave 14 tried and wrote it up as a trap 12 case.
- **The `CEventScope +0x10` typing fix.** Narrow and well specified (`CANDIDATES.md` item 6) but it is
  a change to `buildFindings`' preference rule, which is the maintainer's call about how the two
  halves of the fact base arbitrate.

## Two live checks, still independent of any wave

Both would **correct a published claim** rather than add one, and both need a session:

- **`CUnit +0x2DC` across an attack decision onto an opposed amphibious landing** - the amphibious
  sign bug, which rests entirely on one opcode byte (`subsd` where the river arm has `addsd`). Still
  the one worth doing first; it is thinner evidence than a published claim should rest on.
- **AI agent units' `plan_air_stance`** - whether anything clears stance 2 faster than `ProcessAI`
  restores it.

And the three from `FINDINGS-airdefence.md`, which would settle whether `air_defence` is inert in play
as well as in the bytes: a hook on `0x160D44`, a hook on `0x160FDE`, and zeroing every `air_defence`
in a copy of the mod to compare two identical bombing runs.

---
## The standing rules for every brief

All learned the hard way; all go in every brief.

- **Demand the report's shape, in these words.** Wave 13 came back in four different shapes; wave 14
  came back in four consistent ones, so this works:

  > **Open your report with a synopsis of 2-5 sentences** - what you set out to settle, what you
  > settled, and anything you *corrected* rather than added. No preamble before it.
  >
  > **Then a table of every function your fragment touches**, one row each, before the write-up:
  >
  > | rva | name | new or revised | confidence | one line |
  >
  > Use `revised` for anything that already had a record, and say in the last column what changed
  > about it. If the fragment touches no function, say so in one line rather than omitting the table.
  >
  > **Then the same table for every struct field your fragment touches:**
  >
  > | struct | offset | name | type | new or revised |
  >
  > Same rule: `revised` for anything that already had a record, and say what changed - a name, a
  > type, or both. If the fragment touches no field, say so in one line.

  **And now a third table, for the `structs` key**, since a declaration is as consequential as a field
  and wave 14 landed eighteen of them:

  > **Then every struct your fragment declares:**
  >
  > | struct | size | inherits | vftable rva | own fields |

  The synopsis is what the maintainer reads and the tables are the index to the record. **The
  `revised` rows are the ones to verify off the bytes before merging** - a wrong new name costs
  little, a wrong overwrite costs a published claim. Wave 14's five `revised` rows were all verified
  this way and all held, including one that corrected a published generalisation.
- Give every agent **`TRAPS.md`**, and say the scripts are in `scripts/`, the write-ups in
  `findings/`, and that commands run from `reversing/`.
- **Addresses in `project.json` and the `GameClasses` headers are rvas against an image base of
  `0x400000`; disassemblers print VAs.** Trap 1. It has caught agents in waves 10, 11 and 12 in their
  own prose, and in wave 14 it was the *plan* that was wrong - the faction mutation was handed over as
  `0x4F5F30`, a VA, from a document that declared VAs. **`image.read`, `image.decode` and
  `image.findValue` all take VAs; `image.both` takes a VA and prints the rva.** And
  `image.decode(addr, n)` takes **`n` bytes, not `n` instructions** - asking for 1 returns nothing at
  all, which once produced a silent "no writers anywhere".
- **The fact base has three halves** - `project.json`, the `GameClasses` headers, and
  `ghidra/luabind.json` / `ghidra/bicelib_findings.json`, **which stores offsets in decimal**, so
  `grep 0xF88` over it is a silent false negative. Wave 14 paid for this twice: `CVariables::SaveContents`
  and `CVariables::LoadKey` were "unrecorded" in `project.json` and **`CERTAIN` with signatures in the
  generated file all along**, and 18 classes with 44 fields looked blocked while already being in
  Ghidra through `luabind.json`. **Grep all three before concluding anything is missing.**
- The fragment field list is **`struct_fields`**, never `fields`; a new class goes in **`structs`**,
  and a `fields` key inside a declaration is refused. `confidence` takes only
  `confirmed`/`inferred`. Every `ADDRESS_KEYS` key must be *present*, so a signed entry still needs
  `"no_signature": null`. **`revises`** replaces a record whole and rebuilds from `ADDRESS_KEYS`
  alone, so a missing `comment` or `source` is **silently blanked**; a rename needs `replaces` too. A
  `__thiscall` name needs `::` **and** an explicit `this` in the parameter list.
- **Name your fragment after the topic, not the wave** - `faction.json`, `countrylist.json`,
  `setflag-expedition.json`. Lower case, hyphens, no wave number and no agent letter.
  `fragments/merged/` is one flat archive of every fragment ever landed and you look in it for
  *the faction one*; a `wave15-` prefix sorts it by something git already tells you and buries
  the topic. Six of sixty had drifted before this was written down on 2026-10-07.
- **Check your own signatures**: `python scripts/checkSignatures.py --candidates
  fragments/incoming/<yours>.json`. The whole-image baseline is **1,605 entries, none disagree**
  (2026-10-07; it was 1,582 before wave 14 landed). "None disagree" is the pass mark, not the count.
- Say which facts are **already recorded**, and **check a new conclusion against the record before
  publishing it.** Across waves 10-14 this caught more than a dozen cases where the record already
  held the answer or contradicted itself - and in wave 14 it was three of the four *briefs* that were
  stale, not the agents.
- **Verify both ends of a function's extent, and prefer the vftable to any padding rule**: an address
  a table holds is an entry by definition and the next slot is the upper bound. The "run of at least
  three `int3`" rule is **sufficient, not necessary** - wave 14 found `CTagTrigger::Evaluate` with two.
  And **trap 3 is live**: `CFaction::AddCountry` has two interior `ret 0xC` with `0x2CC` bytes of real
  code past the first, including the two strings that name it.
- An agent's `Write` is refused for `findings/FINDINGS-*.md`; the write-up comes back as prose and
  someone transcribes it **the same session**.
- **Pick what matters, read it properly, and say what you skipped.** A partial reading that names its
  own gap is worth more than a sweep that rounds up - and **a negative needs a positive control in the
  same paragraph.**

## Launching this

Five briefs, built from the sections above. Then the pipeline, which is idempotent:

    python ghidra/mergeFindings.py --check      # refuses until each write-up exists
    python ghidra/mergeFindings.py
    python ghidra/buildFindings.py              # the oracle - validates against the exe
    ...headless ApplyBiceLibFindings            # failed: 0 AND struct fields: 0 on a second run

The full headless command, with the install path and which project, is in `ghidra/README.md`. Run it
against a **copy**; the maintainer's project is usually open and holds the lock, and **applying to
their own project is their step.**

**One thing to expect on the next apply against the maintainer's project**, from wave 14 rather than
this one: 93 vftable slots are in it under names that were wrong, and an `overwrite` run renames them
to `vf_N`. `TRAPS.md`'s section under trap 4 lists the affected tables. **That is a fix landing, not a
failure.**
