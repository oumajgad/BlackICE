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

## Wave 12 - finish the event script language

Planned 2026-10-04. **Every address below was resolved out of a virtual table and checked against
`project.json` while this was written**, and the counts come from walking `PROGRESS.md`'s
`derives from` column transitively rather than from recall. Wave 7 shipped three errors from memory,
wave 9's plan had four, and wave 11's plan asserted a function boundary it had checked on one side
only - so the verified form is given inline and the method is given with it.

**Why this area.** Wave 11 read the *machinery* of the script language: slot 6 is the answer,
`CEventScope` is what it answers against, `CContextTrigger` narrows a scope rather than building one,
and **nothing is cached anywhere**. What is still unread is the *content* - what each condition
actually compares and what each effect actually does. That is the largest unexplored population that
changes what a mod author can rely on, and it is now cheap, because the machinery is known and the
composite bodies turned out to be 0x3F-0x60 bytes each.

### The sizing, measured

| | |
| --- | --- |
| `CTrigger` family | **168 classes**. Slot 6 is `Evaluate`, recorded, and **111 of its distinct bodies are unnamed** against 19 named |
| `CEffect` family | **111 classes**. **Slot 11 is `Execute`** - see below - and the base's own body at rva `0x59C6E0` is unrecorded, as is every leaf body checked |
| busiest triggers, live | `CAndTrigger` 100,464 · `CTechnologyTrigger` 33,204 · `CNotTrigger` 28,006 · `CHasCountryFlagTrigger` 18,966 · `CVariableTrigger` 12,815 · `CTagTrigger` 11,196 · `CContextTrigger` 10,974 |
| busiest effects, live | `CEffect` 28,627 · `CContextEffect` 10,686 · `CClrCountryFlagEffect` 9,057 · `CSetCountryFlagEffect` 8,120 · `CRemoveBrigadeEffect` 6,881 · `CLoadOOBEffect` 4,828 · `CCountryEventEffect` 4,636 · `CAddCountryModifierEffect` 4,420 |

**Slot 11 is `Execute` on the effect side, established here so no agent redoes it.**
`vtable.py --holding` on three bodies `project.json` already names as `*Effect::Execute` puts all
three at slot 11: `CAddAIStrategyEffect` (rva `0x5B0E00`), `CLoadOOBEffect` (`0x5BBD00`) and
`CAnyNearbyProvinceEffect` (`0x5ABA30`). **But `CEffect` has *no* `vftable_slots` record at all**, so
the record does not hold that fact and landing it is part of agent C's job.

**How the families were enumerated**, so an agent can reproduce and extend it: parse
`PROGRESS.md`'s table, take the `derives from` column, close it transitively from `CTrigger` or
`CEffect`, then run `scripts/vtable.py <reference> <batch...>` with the base first - a slot showing
`=` matches the base and an address is an override. Check each address against `project.json`.

**111 unnamed bodies is more than one agent should attempt**, which is why the leaves are split by
kind below. **Every brief says: pick the ones that matter, read them properly, and state which you
skipped.** A partial reading that names its own gap is worth more than a sweep that rounds up -
`fragments/README.md` says so and wave 11 bore it out.

### The standing rules for every brief

All learned the hard way; all four go in every brief.

- Give every agent **`TRAPS.md`**, and say the scripts are in `scripts/`, the write-ups in
  `findings/`, and that commands run from `reversing/`.
- **Addresses in `project.json` and the `GameClasses` headers are rvas against an image base of
  `0x400000`; disassemblers print VAs.** Trap 1. It caught agents in waves 10 and 11 *in their own
  prose*, and it caught the collecting session too.
- The fragment field list is **`struct_fields`**, never `fields`. `confidence` takes only
  `confirmed`/`inferred`. Every key in `ADDRESS_KEYS` must be present, so a signed entry still needs
  `"no_signature": null`. **`revises`** accepts a correction and replaces the record whole; a rename
  needs `replaces` too; a revision rebuilds from `ADDRESS_KEYS` alone, so a missing `comment` or
  `source` is **silently blanked**.
- Say which facts are **already recorded**, so nothing comes back as new.
- **Check a new conclusion against what the record already says before publishing it.** Across waves
  10 and 11 this caught four cases where the record already held the answer or contradicted itself.
- **Verify both ends of a function's extent.** Wave 11's plan asserted "clean boundaries on both
  sides" having checked only the upper one, and three bodies in that family abut their predecessor
  with no padding at all.
- `checkSignatures.py` currently reports **1,412 entries, none disagree**. That zero is a clean
  baseline - say so, because a new disagreement then means one of *their* signatures is wrong.
- An agent's `Write` is refused for `findings/FINDINGS-*.md`; the write-up comes back as prose and
  someone transcribes it the same session.

---

### A. The numeric and comparison triggers

**The bucket a mod author actually writes, and the one where being wrong is silent.** Conditions like
`strength_ratio`, `manpower`, `ic`, `dissent`, `war_exhaustion`, `amount_of_brigades`,
`air_battles_fought`. Each is a leaf whose slot 6 does one comparison, and the question for each is
the same three-part one: **what is read, against what, and in what units.**

Units are the trap. **Numbers in this game are thousandths** (`237964731` is `237964.731`) - that
convention is invisible in the bytes, it has cost this project sessions, and a trigger compared
against the wrong scale is a condition that is silently always true or always false. Say which
each one is.

Verified handles, all **unrecorded**: `CAmountOfBrigadesTrigger` slot 6 at rva `0x5F3E90`,
`CAirBattlesFoughtTrigger` at rva `0x601AC0`, `CAlwaysTrigger` at rva `0x5D3920` (worth reading
first - it should be the simplest body in the family and is a free check that the method works).

Already recorded and **not** to be re-reported: `CPureRevoltRiskTrigger::Evaluate` (rva `0x5E6940`),
`CRevoltRiskTrigger::Evaluate` (`0x5E7590`), `CCombatModifierTrigger::Evaluate` (`0x607E80`),
`CCombatIsConvoyTrigger::Evaluate` (`0x607F70`), `CCombatIsWinnerTrigger::Evaluate` (`0x607F90`),
and wave 11's four composites. `CIntTrigger` is the base several of these derive from -
`CTechnologyTrigger` (33,204 live) is one - so reading that base may cover a dozen leaves at once,
and is the first thing to look at.

### B. The scope and set triggers, and one loose end worth closing

Conditions that quantify over a set or test a relation: `any_owned_province`,
`any_neighbor_country`, `any_core`, `controlled_by`, `exists`, `alliance_with`, `is_ally`. Their
tooltip renderers are **already read** - `CRegionScopeTrigger::GetBlockText` (rva `0x5DCA10`),
`CAnyNeighborProvinceTrigger::GetBlockText` (`0x5DCED0`), `CAnyOwnedProvinceTrigger::GetBlockText`
(`0x5DD5B0`), `CAnyNeighborCountryTrigger::GetBlockText` (`0x5E5FD0`), `CAnyCoreTrigger::GetBlockText`
(`0x5E64F0`) - so for this bucket the rendering side is a map of the evaluation side, which is the
cheapest way in. `CAllianceWithTrigger` slot 6 is rva `0x5EF5A0`, **unrecorded**.

**Then the loose end, and it is the item on this wave with the sharpest mod-facing consequence.**
Wave 11's agent A found that the `ally` scope (token 0x359) reads a `CList` at **`CCountry +0xF88`**
and deliberately refused to name it. Checked: `+0xF88`, `+0xF8C` and `+0xF90` are **not in
`project.json` at all**. The field is written by `CCountry::RebuildNeighbours` (rva `0xE21E0`),
appended from both of its walks, and it is **none of the four neighbour fields `CCountry.hpp` names**
(`neighbours +0xF58`, `controller_neighbours +0xF68`, and the two `CCountryList` at `+0xFD8`/`+0xFE8`).

So one of two things is true and the bytes do not choose: either that field is not what
`RebuildNeighbours` makes it look like, or **`ally = { ... }` scopes to a random *bordering* country
rather than an allied one.** Either answer matters to anyone writing events, and the record's
description of `RebuildNeighbours` as filling "two neighbour sets and the two `CCountryList` they
stand for" is already known to be **incomplete** - it also fills this fifth structure. Read
`RebuildNeighbours` and settle it.

### C. The effect side

**The other half of the script language, and it is barely touched.** 91 effect keywords have their
grammar read (`findings/FINDINGS-script.md`) and almost nothing has its behaviour read.

Start with the slot map, because **`CEffect` has no `vftable_slots` record at all**. What is already
known, from the tables: **slot 11 is `Execute`** (the three-body check above), slot 9 lines up with
the `*Effect::GetText` bodies `project.json` already holds, and slots 0, 4 and 8 also vary across the
family. Landing the slot map for `CEffect` is the single highest-leverage thing in this brief,
because every later effect finding hangs off it.

Then the effects themselves, chosen by live count rather than by taste: `CSetCountryFlagEffect`
(8,120) and `CClrCountryFlagEffect` (9,057), `CRemoveBrigadeEffect` (6,881),
`CAddCountryModifierEffect` (4,420), `CCountryEventEffect` (4,636). Verified unrecorded leaf bodies
to start from: `CNationalUnityEffect` slot 11 at rva `0x5B19D0`, `CNeutralityEffect` at rva
`0x5B9740`, and the base's own at rva `0x59C6E0`.

**And `CContextEffect`, the effect-side twin of the scoping wave 11 read** - slot 11 at rva
`0x59E2B0` and slot 8 at rva `0x59E520`, **both unrecorded**. Both call
`CEventScope::MakeScope`, which **is** recorded (rva `0x5C1C10`, `confirmed`) and is the function
agent A read. 10,686 live. This is the piece that
makes the scoping account complete rather than half of one, and wave 11 named it as where the effect
half should start.

Note for free: agent B's signature audit established that **seven `*Effect::Execute` bodies take a
second stack argument** the record was missing, and that the one sibling which had it right
(`CLoadOOBEffect::Execute`, rva `0x5BBD00`) spells it `(this, CEventScope* scope, int unknown)`. What
that second dword *is* remains unnamed, and this brief is the natural place to settle it.

### D. What accepting an agreement actually does

**Slot 7 of the diplomatic actions - the per-class effect, unread in all 24 classes.** Wave 11's
agent D traced the whole offer lifecycle except the one step where the agreement happens, and called
this the single biggest thing left in its area.

Verified handles, all **unrecorded**: `CTradeAction` slot 7 at rva `0x6352F0`, `CNapAction` at rva
`0x62B090`, `CWarGoalBaseAction` at rva `0x6435F0`.

What the record already holds, so none of it is re-reported: slot 7 is `_purecall` on the base and
overridden by every concrete class; `CDiplomaticActionCommand::Execute` (rva `0x60E120`) calls it at
rva `0x60E19E` between the cooldown write and the clone-and-queue; the `type` enum is PROPOSE 0 /
DECLINE 1 / **ACCEPT 2**; `value` is a **bool**, not thousandths; and all 21 concrete class tokens
are mapped in `findings/FINDINGS-diploaction.md` section 3.

Self-contained, and it closes a file rather than opening one.

---

## Deliberately not in this wave

**The `CAIStrategy` collector that trigger slot 10 reports to** - rvas `0x4A5270`, `0x4A5A60`,
`0x4A73C0`. Wave 11's agent A called it the highest-value item on its frontier, because the whole
slot-10 weighted-attribution walk exists to feed it and nothing is known about what it does with the
weights. It is left out only because it is squarely **AI logic**, which this run of waves has been
steering away from; it is the best item in that direction whenever the AI is back on the table.

## Two live checks, independent of any wave

Both are in `CANDIDATES.md`'s live queue, at the top, and both would **correct a published claim**
rather than add a new one:

- **AI agent units' `plan_air_stance`** - whether anything clears stance 2 faster than `ProcessAI`
  restores it.
- **`CUnit +0x2DC` across an attack decision onto an opposed amphibious landing** - the amphibious
  sign bug, which currently rests entirely on one opcode byte (`subsd` where the river arm has
  `addsd`). That is thinner evidence than a published claim should rest on.

## Launching this

Four briefs, built from the sections above. Then the usual pipeline, which is idempotent:

    python ghidra/mergeFindings.py --check      # refuses until each write-up exists
    python ghidra/mergeFindings.py
    python ghidra/buildFindings.py              # the oracle - validates against the exe
    ...headless ApplyBiceLibFindings            # failed: 2 is the pass mark

The full headless command, with the install path and which project, is in `ghidra/README.md`. Run it
against a **copy**; the maintainer's project is usually open and holds the lock, and **applying to their own
project is his step.**
