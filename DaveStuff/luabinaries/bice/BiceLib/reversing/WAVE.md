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

## Wave 14 - the evaluation half of the script language, and the structs that cannot land

Planned 2026-10-05, immediately after wave 13 landed. **Every address below was resolved against
`project.json` and decoded out of the executable while this was written**, and the counts come from
scripts rather than from recall or from an earlier document. The method is given with each number.

**Why this shape.** `CANDIDATES.md`'s standing survey calls the evaluation half of the event script
language the strongest candidate away from the AI, and it is right about the area - BlackICE is an
enormous event and decision mod and these are the semantics behind every condition in it. But the
survey's own arithmetic is three waves out of date, and re-measuring it changed what is worth doing
(see below). What is actually left is **not** 145 unread `Evaluate` bodies; it is the *spine* of the
trigger forest - how a scope is rebound, and what a forest costs to walk - plus a tooling limit that
is currently blocking the three most populous classes in the game from having any fields at all.

### What the verification caught this time, recorded rather than quietly fixed

Two things, and the first changes a brief.

- **`CANDIDATES.md` says "a grep of the whole record finds 7 named `Evaluate` bodies in the image".
  There are now 64.** Measured, not recalled: `[a for a in project.json.addresses if
  a.name.endswith('::Evaluate')]` answers 64, against 152 trigger keywords in
  `findings/FINDINGS-script.md`. The survey was written 2026-10-03 and waves 11, 12 and 13 have
  landed since - wave 13 alone added six. So "the record knows how a condition displays itself and
  not how it answers" is no longer true of 42% of them, and a brief built on the old number would
  have gone looking for a hole that is half filled. **This is trap 14's open-list clause exactly: a
  survey is a claim about the record as it stood when it was written.** `CANDIDATES.md` is corrected.
- **Wave 13's agent C gave the faction mutation as `0x4F5F30`, which is a virtual address.** Its own
  document declares VAs, so the rva is **`0xF5F30`** - and that is a real function entry opening
  `push ebp`, still unrecorded. `0x4F5F30` as an rva decodes as `in eax, 0x5d` and is not an entry.
  Trap 1, caught by decoding the citation before writing it into a brief.

### What wave 13 settled - do not redo these

- **The trigger spine's slot map is fully recorded**, with signatures: slot 6 `Evaluate`, 7
  `LoadArgument`, 8 `GetText`, 9 `GetBlockText`, 10 `WalkChildren`, 11 `CountEvaluation`. So is
  `CEffect`'s. These are a map to read bodies *against*, not something to re-derive.
- `CContextTrigger::Evaluate` (rva `0x5D1530`), `CAndTrigger::Evaluate` (`0x5D06E0`),
  `CNotTrigger::Evaluate` (`0x5D12C0`), `COrTrigger::Evaluate` (`0x5D0D00`) are all **recorded and
  `confirmed`**. Slots 10 and 11 are recorded for the spine too - `WalkChildren` on 4 classes,
  `CountEvaluation` on 5. **What is unread is what those bodies do**, not what they are called.
- The six resource triggers are one shape confirmed six ways; `CValueTrigger::TakeScalarValue` keeps
  the decimal where `CIntEffect`'s multiplies by 1000; there is no `fuel` trigger.
- `CVariableTrigger::Evaluate` creates the variable on a miss, and a variable worth exactly zero is
  dropped by the save walker.
- `CDiplomacyStatus +0x59` has no reader; `surrender_progress` is high-means-surrendering;
  `remove_brigade` can never match a type token.

---

### A. Teach the pipeline to create a struct, and land the classes blocked behind it

**The highest-leverage brief in the wave, and it unblocks brief B.** `ghidra/mergeFindings.py`
**refuses a `struct_fields` entry for a struct `project.json` does not already hold, and a fragment
has no way to create one.** So a whole class's layout cannot be contributed by an agent at all, only
by a hand edit, and the queue has been accumulating them.

What is blocked, all re-verified absent from `project.json` 2026-10-05:

| | |
| --- | --- |
| **7 `CTrigger` classes** | `CContextTrigger`, `CAndTrigger`, `CNotTrigger`, `CTechnologyTrigger`, `CHasCountryFlagTrigger`, `CTagTrigger`, `CVariableTrigger` |
| **12 diplomatic classes** | `CRelation`, `CNap`, `CAlliance`, `CGuarantee`, `CEmbargo`, `CAlign`, `CInfluence`, `CDependency`, `CCasusBelli`, `CDiplomacy`, `CDiplomaticActionCommand`, `CNullDiplomaticAction` |
| **18 Lua-only structs** | 44 fields, of which **13 are `def_readwrite`** - the strongest records in the whole Lua half, because the offset is a constant in the registration. `CGoodsValues`, `CResourceValues` and `CStrategicWarfare` are the ones worth having |

**The first three are the point.** `CAndTrigger` has **100,464 live instances**, `CNotTrigger`
28,006, `CContextTrigger` 10,974 - the three most populous classes in the trigger forest - and
between them they have **no field records at all**, while their `Evaluate`, `WalkChildren` and
`CountEvaluation` bodies are named and confirmed. Brief B cannot land a field without this.

Deliver, in this order:

1. **The tooling change.** A fragment needs to be able to declare a struct. Decide the shape - most
   likely a `structs` key alongside `struct_fields`, carrying a name and optionally a size and an
   `inherits` - and make `--check` validate it the way it validates everything else. Note
   `buildFindings` already handles `"inherits"`, and that **`"inherits"` only works for a base at
   offset 0** (`ghidra/README.md` says so); `CRelation`'s subclasses are exactly that shape.
2. **A second limit, same file, same kind:** `vftable_slots` is keyed by class with **no way to say
   which of a class's two tables a slot belongs to**. That is why `CVariables::SaveContents` (rva
   `0x77060`) and `CVariables::LoadKey` (`0x77080`) are described inside other entries' comments and
   recorded as neither - they are slots 2 and 4 of `CVariables`' *second* table (`0x11BD724`). Fix or
   report, your judgement.
3. **Then land them**, and **verify each layout rather than trusting the prose that describes it**.
   `CRelation`'s seven fields and `CCasusBelli`'s `+0x24` are written out in
   `findings/FINDINGS-diploaction.md` section 27 with the addresses of every write;
   `CCasusBelliType`'s 22 loader offsets are in the same section. Re-derive, do not transcribe - the
   prose is a lead, and wave 13 found one case where the prose was right and the entry wrong and one
   the other way round.

**Also in this brief, because it is the same kind of work, and both are *reports* rather than
fixes:** `project.json` holds **four duplicate field records** - `CDiplomacyStatus +0x14` and `+0x1C`
each hold `void*` **and** the typed pointer, and `merge_fields` keeps the `void*`, so **the
decompilation gets `void*`** while the record also holds `CAlliance*`. (`CCountry +0xA8C` and
`+0x10B8` are the same shape and harmless.) They were deliberately not fixed in wave 13 because the
pairs are not identical - each carries a different comment from a different findings file - so
deleting one loses a reading. **Say what the merged record should say**; the hand edit is the
maintainer's.

And **five recorded names sit on a body another luabind registration also claims** - `0x16000`,
`0x944C0`, `0xC8920`, `0x4E9090`, `0x2EF70` - three of which contain an explicit negative the
registrations contradict. `scripts/reconcileFacts.py` prints them in one command. Report, do not
rename.

### B. `CContextTrigger` - what `owner = { ... }` actually rebinds

**The most mod-facing single thing left in the script language.** `CContextTrigger` derives from
`CAndTrigger`, has **10,974 live instances**, and is the scope switch - `owner = { ... }`,
`controller = { ... }`, a bare country tag. Its `Evaluate` (rva `0x5D1530`) and `WalkChildren`
(`0x5D2470`) and `CountEvaluation` (`0x5D24C0`) are **all recorded and confirmed**, and its
constructor (`0x5D14A0`) is recorded with the note that it takes a `0x104`-byte scope specification
by value (`ret 0x108`) - which is why `checkSignatures` skips it.

**What is not read is the rebinding**, and `findings/FINDINGS-scopetriggers.md` places only **2 of
its 153 keys**. The question, which a modder cannot answer from the files: when a condition is
written inside `owner = { ... }`, what exactly does the inner scope see - and for the keys that take
a *province* or a *country tag*, which field of `CEventScope` is overwritten and which is left alone?

`CEventScope`'s own layout is partly recorded: `+0x10` `country_tag`, `+0x14` the id, `+0x18`/`+0x1C`
the `from` pair, `+0x28` the province. **And there is a live lead on it**: wave 13's agent A found the
Lua half types `+0x10` as `CCountryTag&`, which is eight bytes with the id at `+0x14`, while the
record has `char[4]`. If the Lua half is right there is an **unrecorded `CEventScope +0x14`** and the
scope's tag comparisons read the id half rather than the letters - which is how every other tag
comparison in this image works. Settle that on the way through; it is one decode.

`CAndTrigger`, `CNotTrigger` and `COrTrigger` are the forest's spine and brief C also reads them -
**coordinate: you own `CContextTrigger` and the scope classes, C owns slots 10 and 11.** A field on
`CAndTrigger` from either of you needs brief A's tooling first; if it is not ready, give the layout as
prose.

### C. What a trigger forest costs, and whether evaluation is cached

**`CAndTrigger` has 100,464 live instances** and BlackICE has thousands of decisions and events. If
every one re-walks its tree on a schedule, that is a measurable cost in a mod this size, and it is
the kind of thing that shows up as a frame-time complaint nobody can locate.

Slots 10 and 11 are the two to read, both recorded with signatures and **neither read**:

    void __thiscall WalkChildren(CTrigger*, void* collector, CEventScope*, bool polarity, int weight)
    void __thiscall CountEvaluation(CTrigger*, CEventScope*, int* passed, int* total)

Recorded bodies: `WalkChildren` on `CTrigger` (rva `0x5D0680`), `COrTrigger` (`0x5D1270`),
`CNotTrigger` (`0x5D1340`), `CContextTrigger` (`0x5D2470`); `CountEvaluation` on `CTrigger`
(`0x5D06C0`), `CAndTrigger` (`0x5D0CD0`), `COrTrigger` (`0x5D1230`), `CNotTrigger` (`0x5D1380`),
`CContextTrigger` (`0x5D24C0`).

The questions, in order of value:

1. **Is any evaluation result cached on the trigger, or is every call a fresh walk?** A cache would
   be a field, and `CAndTrigger` has no struct record - so if you find one, brief A is what lets it
   land, and prose is the fallback.
2. **Who calls `CountEvaluation`, and how often?** Its signature takes `passed` and `total` out
   parameters, which is tooltip arithmetic ("3 of 5 conditions met"). If it is only ever called from
   a tooltip builder the cost is paid on hover and does not matter; if a periodic calls it, it does.
3. **What `WalkChildren`'s `collector` and `weight` are for.** The record notes trigger slot 10's
   weighted-attribution walk exists to feed `CAIStrategy`'s collector - which is the AI item held out
   of four waves now - so reading the walk from the *trigger* side gets most of the way into that
   without touching AI logic.
4. **`CAndTrigger::Evaluate` is short-circuiting or it is not**, and that is one decode.

**A trap to expect**: `functionStart(0x5D06E0 + 0x400000)` does **not** answer `CAndTrigger::Evaluate`'s
own entry - verified while this was written - so that body is a trap 2 case. Read extents from the
vftable, which is the rule anyway.

### D. The faction layer

**Wave 13's agent C named this the single highest-value thing it left.** `CFactionAction::Apply`'s
only country write, in `0x2157` bytes, is the influence charge - verified two independent ways - so
**the faction membership change is not in slot 7.** It is in **rva `0xF5F30`** (VA `0x4F5F30`; the
plan it came from declared VAs and this is the corrected rva), a ~`0x950`-byte `__thiscall` called
twice from `CFactionAction::Apply` at VAs `0xA319B2` and `0xA31AF5` with
`ECX = country->faction (+0xD8)` and `(CCountry*, 0, 1)` on the stack, `ret 0xC`. Unrecorded, a real
entry, opens `push ebp`.

What the record already has to read it against: `CFaction` **has** a struct, 10 fields, including
`+0x28 Members` and `+0x30 NumberOfMembers`; `CFaction::GetFactionLeader` (rva `0x1235E0`) **returns
the first member and there is no leader field**; the members list holds `CCountryTag` by value, so a
node pointer is a `CCountryTag*`. `CFactionAction::Apply`'s gate is read in full, including the new
clause that **a country may not join a faction while at war with any member**.

And the open question this finally lets someone answer, which has been on the queue since wave 12:
**can a faction member lack a bilateral alliance?** That decides whether `ally = { ... }` is genuinely
wider than `alliance_with`, which is a real difference to a mod. Compare `CCountry +0xF90` (the allies
count) against `CFaction +0x30` (the members count) and against the pairs whose `CDiplomacyStatus
+0x14` is non-null. `CCountry::CalculateIsAllied` (rva `0xE6A30`) walks `+0xF88` and is the function
that answers it in the engine.

---

## Deliberately not in this wave

**The AI, for the fourth wave running.** `CAIStrategy`'s collector - rvas `0x4A5270`, `0x4A5A60`,
`0x4A73C0`, all three verified **unrecorded** and all three opening `push ebp` - is still the largest
single unread thing in the image. It is out because the standing steer is away from AI logic, not
because it stopped being the best item in that direction, and **brief C reaches the trigger side of
it without touching it**. Say the word and it swaps in for any brief here.

## Two live checks, still independent of any wave

Both would **correct a published claim** rather than add one, and both need a session:

- **`CUnit +0x2DC` across an attack decision onto an opposed amphibious landing** - the amphibious
  sign bug, which rests entirely on one opcode byte (`subsd` where the river arm has `addsd`). The one
  worth doing first; it is thinner evidence than a published claim should rest on.
- **AI agent units' `plan_air_stance`** - whether anything clears stance 2 faster than `ProcessAI`
  restores it.

And a third, cheaper than either and now well specified by wave 13: **does anything keep
`CCountry +0x9F8 pool_in_exile` in step with the host's pool?** If something does, the separation of
the exile's goods from its host's is true of the bytes and invisible in play. The savegame is the
oracle, since a government-in-exile country's `pool` block is plain text.

---
## The standing rules for every brief

All learned the hard way; all go in every brief.

- **Demand the report's shape, in these words.** Wave 13 came back in four different shapes and
  finding "what actually changed in the record" was four different searches:

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

  The synopsis is what the maintainer reads and the tables are the index to the record, so all three
  are the agent's job rather than the collecting session's. **The `revised` rows are the ones to
  verify off the bytes before merging** - a wrong new name costs little, a wrong overwrite costs a
  published claim. `CLAUDE.md`'s subagent section carries this too, because this file gets replaced.

  **Both tables are unconditional**, and the field one is not negotiable on the grounds that a brief
  does not look field-heavy. Wave 13's brief A had no field framing, its function table read
  **`0 revised`**, and its two biggest results were field overwrites (`CCountry +0x604` and
  `+0xF34`/`+0xF38`) - nine revisions among 76 field records. Which briefs turn out field-heavy is
  not knowable when the brief is written, and a wrong **type** is what reaches the decompilation.
- Give every agent **`TRAPS.md`**, and say the scripts are in `scripts/`, the write-ups in
  `findings/`, and that commands run from `reversing/`.
- **Addresses in `project.json` and the `GameClasses` headers are rvas against an image base of
  `0x400000`; disassemblers print VAs.** Trap 1. It has caught agents in waves 10, 11 **and 12** in
  their own prose, it is in two of wave 12's frontier lists, and it caught the collecting session
  three times - most recently by passing an rva to `image.read`, which takes a VA. **`image.read`,
  `image.decode` and `image.findValue` all take VAs; `image.both` takes a VA and prints the rva.**
  And `image.decode(addr, n)` takes **`n` bytes, not `n` instructions** - asking for 1 returns
  nothing at all, which once produced a silent "no writers anywhere".
- **The fact base has three halves** - `project.json`, the `GameClasses` headers, and
  `ghidra/luabind.json` / `ghidra/bicelib_findings.json`, **which stores offsets in decimal**, so
  `grep 0xF88` over it is a silent false negative. Brief A is this rule turned into work.
- The fragment field list is **`struct_fields`**, never `fields`. `confidence` takes only
  `confirmed`/`inferred`. Every `ADDRESS_KEYS` key must be *present*, so a signed entry still needs
  `"no_signature": null`. **`revises`** replaces a record whole and rebuilds from `ADDRESS_KEYS`
  alone, so a missing `comment` or `source` is **silently blanked**; a rename needs `replaces` too.
  A `__thiscall` name needs `::` **and** an explicit `this` in the parameter list.
- Say which facts are **already recorded**, and **check a new conclusion against the record before
  publishing it.** Across waves 10-12 this caught nine cases where the record already held the
  answer or contradicted itself.
- **Verify both ends of a function's extent, and prefer the vftable to any padding rule**: an
  address a table holds is an entry by definition and the next slot is the upper bound. The "run of
  at least three `int3`" rule is **sufficient, not necessary** - wave 12 found three real
  boundaries it walks straight past. `functionStart`'s prologue set now includes `0x8A` and `0x85`.
- Quote `checkSignatures.py`'s baseline so a new disagreement means one of *their* signatures is
  wrong. It is **1,517 entries, none disagree**. Note `--only` can check an address already in
  `project.json` but gives an agent no way to check its own new entries; agent C wrote its own and
  recommended a `--candidates` flag, which is on brief A's tooling list.
- An agent's `Write` is refused for `findings/FINDINGS-*.md`; the write-up comes back as prose and
  someone transcribes it **the same session**.
- **Pick what matters, read it properly, and say what you skipped.** A partial reading that names
  its own gap is worth more than a sweep that rounds up - `fragments/README.md` says so and waves
  11 and 12 both bore it out.

## Launching this

Four briefs, built from the sections above. Then the pipeline, which is idempotent:

    python ghidra/mergeFindings.py --check      # refuses until each write-up exists
    python ghidra/mergeFindings.py
    python ghidra/buildFindings.py              # the oracle - validates against the exe
    ...headless ApplyBiceLibFindings            # failed: 0 is the pass mark

The full headless command, with the install path and which project, is in `ghidra/README.md`. Run it
against a **copy**; the maintainer's project is usually open and holds the lock, and **applying to
their own project is their step.**
