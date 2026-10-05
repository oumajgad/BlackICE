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

## Wave 13 - reconcile the record with itself, and close what wave 12 opened

Planned 2026-10-04. **Every address below was resolved against `project.json` and decoded out of the
executable while this was written**, and the counts come from scripts rather than recall. The method
is given with each number so an agent can reproduce it.

**Why this shape.** Wave 12's largest finding was not about the game. It was that `CCountry +0xF88`
had been `Allies` in the repository the whole time, while wave 11 carried it as an open question and
wave 12 was planned around settling it - because the standing check was two paths and the fact base
has three. That was found by accident. **Measured since: 713 fields the generated record holds that
`project.json` has no field for, across 115 structs, and 108 offsets where the two disagree on the
name.** So the single highest-value thing available is not another class; it is making the record
agree with itself, once, with a script that keeps it agreeing.

The other three briefs close wave 12's own remainders, which are unusually well specified because
each agent named its gap instead of rounding up.

### What the verification caught this time, recorded rather than quietly fixed

The plan's rule is that the citations are checked while it is written. Four were wrong:

- **Agent B's frontier mixed a VA into a list declared as rvas.** `0x5010C0` is a VA; the rva is
  **`0x1010C0`**, which is `mov eax,[ecx+0xd08]; ret` - the controlled-provinces count, exactly as
  B's *prose* said. Its sibling `0x1010D0` is `mov eax,[ecx+0xcf8]; ret`, the owned count. Trap 1,
  in a frontier list, which is the worst place for it because the next wave reads frontiers as
  work items.
- **Agent A's frontier gives `0x12F100` as "the goods-pool getter the six resource triggers
  share". There is no such function.** `functionStart` lands at rva `0x12EF98`, and reading the
  calls out of the first resource trigger's body gives `0x42F100` - rva **`0x2F100`**, which is
  **`CCountry::GetActingCapitalLocation`, already recorded and `confirmed`**. So the address was
  wrong *and* the description was. This sharpens brief B rather than costing it anything: see there.
- Two citations in my own first draft were rvas where the agent had written VAs (`0x47BBE0` for
  what is rva `0x7BBE0`, and the same mistake on the war-goal chain). The agents' frontier lists
  were right and my transcription was not.

### Wave 12's loose ends, already closed by the collecting session - do not redo these

- `CDiplomacyStatus +0x38 relation` is now `confirmed` with its writer, its ±200000 clamp and the
  `defines.lua` corroboration; `+0x2C influence_running` is refined to **the `CInfluence*` itself**,
  one-sided, with the direction question settled by `CInfluence::Activate`.
- `CCountry::ChangeNeutrality`'s signature storage is complete, so it no longer reads as
  "certainly wrong" beside its new sibling `ChangeNationalUnity`.
- `CLAUDE.md` and `ghidra/README.md` now say **`failed: 0` is the pass mark**, and the two failures
  they used to excuse are explained: both predecessors are **thunks that tail-jump into** their
  targets, Ghidra had merged thunk and target, and the old byte-level argument was about a third
  function (`functionStart(0xA7E020)` answers `0xA7DF60`). `CANDIDATES.md`'s wave 12 entry has it.

---

### A. Reconcile the three halves of the fact base

**The highest-leverage brief in the wave, and the most mechanical.** The fact base is
`ghidra/project.json`, the `BiceLib/GameClasses/*.hpp` headers, and **`ghidra/luabind.json` ->
`ghidra/bicelib_findings.json`** - the Lua half, extracted from the game's own luabind
registrations, merged by `buildFindings.py`, and therefore **already showing in Ghidra** while not
being in the hand-maintained record that everyone greps.

Measured, by comparing the generated record against `project.json`'s own structs:

| | |
| --- | --- |
| `project.json` | 165 structs, 2,232 fields |
| the generated record | 245 structs, 2,863 fields |
| **fields the generated record has and `project.json` has no field for** | **713, across 115 structs** |
| **offsets where the two give different names** | **108** |

The 713 are the `Allies` case repeated: an answer that is in the repository, that Ghidra shows, and
that **cannot be found by the grep `TRAPS.md` tells you to run**, because the Lua half stores
offsets as **decimal integers** (`3976`, not `0xF88`). The biggest clusters are `CAir` 60, `CNavy`
60, `CArmy` 59, `CCountry` 27, `CShip` 26, `CWing` 26, `CRegiment` 25 - which is a direct answer to
why the unit classes keep looking unread.

Most of the 108 are harmless convention differences (`cost` / `Cost`, `country_tag` / `CountryTag`)
and the brief should say so rather than inflate them. **Some are not**, and those are the prize:
`CCountry +0x604` is `base_ic` in `project.json` and `TotalIC` in the Lua half, and `+0x60C` is
`max_ic` against `MaxIC` - both of which wave 12's agent A read as the operands of `total_ic` and
`enemy_ic_ratio`, so there is a live question about which name is right and a reading that bears on
it. `CCountry +0x94`/`+0x95` (`mobilised`/`government_in_exile` against `isMobilized`/
`isGovernmentInExile`) matter to brief B.

**What to deliver, in this order:**

1. **The reconciliation, as a document**: the 713 grouped by struct with a verdict per group -
   *free and trustworthy* (a Lua accessor whose whole body is the `lea`), *free but unchecked*, or
   *disagrees with something*. Do not try to verify 713 fields; **triage all of them and verify the
   ones that matter**, and say which you skipped.
2. **The 108 disagreements, each classified** as convention or substance, with the substantive ones
   read off the bytes and settled. This is the part where a wrong name is currently reaching Ghidra.
3. **A script in `scripts/`** that does the comparison, so this never has to be rediscovered. There
   is a working version in the session scratchpad to start from; it belongs in the repository with
   the other 39.
4. **The sixteen tiny accessors agent B put first**, which are two or three instructions each and
   for which `luabind.json` already holds a name, a class and a signature. All sixteen verified
   **unrecorded** in `project.json` while this was written, and fifteen are present in the Lua half:

   | rva | first instruction | what it gives |
   | --- | --- | --- |
   | `0xE6A10` | `lea eax,[ecx+0xf78]` | `CCountry::GetVassals` |
   | `0xE6A20` | `lea eax,[ecx+0xf88]` | `CCountry::GetAllies` - the wave 12 answer |
   | `0xE6A30` | `push ebp` | `CCountry::CalculateIsAllied` |
   | `0xE2190` | `mov eax,[ecx+0x1064]` | `CCountry::GetNumOfAllies` |
   | `0x94660` | `cmp dword [ecx+0x14],0` | `CDiplomacyStatus::HasAlliance` |
   | `0x648730` / `0x648760` | `push ebp` | `IsGuaranting` / `IsGuaranteed` |
   | `0x649C90` | `mov al,[ecx+0x58]` | `IsFightingWarTogether` - a third witness for `co_belligerent` |
   | `0x64A3F0` | `mov al,[ecx+0x4c]` | `HasMilitaryAccess` |
   | `0x1010C0` / `0x1010D0` | `mov eax,[ecx+0xd08]` / `[ecx+0xcf8]` | the controlled / owned province counts **(corrected from B's frontier)** |
   | `0x3A660` / `0x17AE0` / `0xC3040` | `lea eax,[ecx+0xcf0]` / `[ecx+0xd00]` / `[ecx+0xd10]` | Owned / Controlled / Core provinces |
   | `0x63D780` | `mov eax,[ecx+0x30]` | `CFaction::GetNumberOfMembers` |
   | `0x1235E0` | `cmp dword [ecx+0x30],0` | `CFaction::GetFactionLeader` - **returns the first member** |

   Note the `lea` bodies are the strongest kind of field evidence there is: the whole function is
   the offset. **But `CFaction::GetMembers` is already in `project.json` as `LeaThisPlus28`, a
   fold** - so check the holder count before putting a class name on any of these (trap 4), and
   expect at least one to have to stay class-free.

**Also in this brief, because it is the same kind of work:** `mergeFindings.py --check` does not
compare `struct_fields` **between** incoming fragments, only against `project.json`, so two agents
naming one offset differently lands both records. Wave 12's agent A caught that by reading a sibling
fragment by hand. A cross-fragment checker exists in the session scratchpad; promote it, or fold it
into `--check`.

### B. `CEffect` slot 12, and what a government in exile really reads

**Two things, both left by wave 12's agent C and A respectively, and both cheap.**

**Slot 12 is the last unread virtual in the effect family.** 43 of `CEffect`'s 101 concrete classes
have a thirteenth slot, five bodies supply it, and the grouping is **exactly by scalar middle
class** - which is the interesting part, because it means the slot is the scalar families' own, not
`CEffect`'s. All five verified **unrecorded** and all five open `push ebp`:

| rva | holders | the middle class it goes with |
| --- | --- | --- |
| `0x59D4F0` | 24 | `CIntEffect`'s group - the biggest, so start here |
| `0x59CB90` | 11 | `CValueEffect`'s group |
| `0x5BD110` | 4 | |
| `0x59DC90` | 2 | |
| `0x59E220` | 2 | |

Agent C called this the highest-value single item on the effect side. `CEffect`'s own slot map is
recorded now (slot 11 `Execute`, 9 `GetText`, 8 `GetBlockText`, 10 `GetTargetText`, 6
`GetKeywordToken`, 7 `TakeScalarValue`), so the table is a map to read this against rather than a
thing to re-derive. **Note `CEffect` has a `structs` record and `CTrigger` has one, so new fields on
either can go in a fragment.**

**Then the six resource triggers, where the plan's own source was wrong and the question got
better.** `money`, `energy`, `metal`, `rare_materials`, `crude_oil`, `supplies` - one
32-instruction shape repeated `0x370` bytes apart from rva **`0x5F5E70`** to **`0x5F6FA0`**, both
verified unrecorded, both `push ebp`. Agent A read them as branching on
`government_in_exile (CCountry +0x95)` and said they reach the pool through a getter at
`0x12F100`.

**There is no function at `0x12F100`.** Reading the calls out of the first body gives `0x42F100`,
which is rva `0x2F100` - **`CCountry::GetActingCapitalLocation`, already recorded and `confirmed`**.
So the branch does not select a different pool: it looks up an **acting capital**, which is what a
government in exile has instead of its own. The question to answer is therefore the sharper one:
**does a government in exile read its host's goods, or its own, and which province's?** That is
mod-facing and currently unknown in either direction.

Six leaves for the price of one shape, and the `0x370` stride is the discriminator that says they
really are one shape - but **verify it on at least two of the six** rather than assuming the stride,
because a regular stride across six classes is also what a fold looks like from the outside.

### C. The diplomatic remainder

**Wave 12's agent D closed slot 7 but named its own gap precisely**, which makes this the
best-specified brief in the wave. Three parts.

**1. The war-goal chain.** All four verified **unrecorded**, all four clean entries:

| rva | VA | what is known |
| --- | --- | --- |
| `0x651FB0` | `0xA51FB0` | called with `(status->war (+0x20), actor.tag, actor.id)` - the add itself |
| `0x649EB0` | `0xA49EB0` | a predicate that must answer true, or the effect returns |
| `0x649F40` | `0xA49F40` | called `(status, 0)` once a matching casus belli is found |
| `0x7BBE0` | `0x47BBE0` | called with `ECX = &this->warGoal`; reads `+0x18`, `+0x1C`, `+0xC`, which `BiceLib/GameClasses/CWarGoal.hpp` independently names `actor.tag`, `actor.index`, `casusBelli`. `push ebp; mov ebp, esp; sub esp,0x50` |

D's reading that *adding a war goal consumes the casus belli that justified it* is explicitly
**inference** - the removal and the delete are read, the causal account is not. Settle it.

**2. The threat adder, rva `0xF50A0` (VA `0x4F50A0`)**, unrecorded, four callers. This is where
`LEAVE_NAP_THREAT_COST` lands, and it is the one that produced **a fourth way a define hides from a
block scan**, to go beside trap 8's three: the value is never loaded, the body does
`add edi, 0x60` on the register already holding the diplomacy block and passes the **address**.
`EMBARGO_THREAT_COST` (+0x88) is almost certainly reached the same way - `CEmbargoAction` calls this
twice and never loads `+0x88`. Confirm that, and the trap gets its fourth case with two witnesses
instead of one.

**3. The four slot-7 bodies whose writes are unread.** All four **are recorded**, as
`*::Apply [inferred]` - so this is not a naming job, it is "what does accepting this actually
change": `CDeclareWarAction` (rva `0x612030`), `CCallAllyAction` (`0x627BA0`), `CFactionAction`
(`0x630E70`), `CLicenceTechnologyAction` (`0x63B5A0`). D read their extents, defines, call sets and
message keys but not their `CDiplomacyStatus`/`CCountry` writes, and these are the four that reach
into the war, faction and technology layers.

**And one thing to report in prose rather than in a fragment.** `mergeFindings.py` **refuses
`struct_fields` for a struct `project.json` does not hold**, and it holds **none** of
`CRelation`, `CNap`, `CAlliance`, `CGuarantee`, `CEmbargo`, `CAlign`, `CInfluence`, `CDependency`,
`CCasusBelli`, `CDiplomacy`, `CDiplomaticActionCommand` or `CNullDiplomaticAction` - all twelve
verified absent. D described `CRelation`'s layout (`+0x8` first, `+0x10` second, `+0x18`
start_date, `+0x1C` end_date, `+0x20` a byte, subclass fields from `+0x24`) and it is recorded
nowhere. **Give the layouts as prose and the collecting session will hand-add the structs**;
`CRelation` at least is worth having, since nine subclasses write through it.

### D. The claims that rest on writers only

**A brief whose deliverable is corrections, not names.** Four places where something published is
thinner than it reads, each one the shape of trap 14's own worked example - `CCurrentGameState
+0xD9D` was called `autosave_blocked` from one gate and is `tutorial_active`, with twelve readers.

**1. `CDiplomacyStatus +0x59 changed`.** Eleven writers, **no reader was ever looked for**. The
record says so honestly - "the name says what the writers have in common and nothing about what it
is for; a dirty flag for the diplomacy screen is a guess" - which is exactly the state that wants
one scan. `CCountry::ChangeRelation` (rva `0xE65C0`, `confirmed`) sets it on both sides, and seven
of the nine `CRelation::Activate` bodies set it. **`CAlign`'s and `CEmbargo`'s do not**, and why
they differ is its own small question with a real answer. Find the readers, and if there are none,
say so **with a positive control** - a field you know is read, scanned the same way.

**2. Which end of `surrender_progress` means "about to surrender".** The scale is read off a clamp
(`0..1000`, compared as `progress * 100` against `script * 1000`, so effectively `progress / 10`);
the **direction is not**. `CCountry::GetSurrenderProgress` (rva `0xFCB80`) is recorded `inferred`;
its divisor at rva **`0xFCC60`** is **unrecorded** and is what the question turns on. It matters
because BlackICE writes both `surrender_progress = 80` and `= 0.05`, and on one reading the second
is satisfied by `progress >= 1` out of 1000, i.e. essentially always.

**3. `check_variable`'s side effect.** `CVariableTrigger::Evaluate` asks `CVariables` for the name
and, **on a miss, creates it** - rva **`0x76FB0`**, unrecorded, `push ebp` - then evaluates
`0 >= value`. So a condition on a never-set variable is true whenever the threshold is `<= 0`
**and it mutates the game state from inside a trigger**. Read `0x76FB0` and establish what it
actually creates and whether the variable then persists into the save. The save is plain text and
writes variables as `BaseIC=35.000`, so that half is a grep.

**4. `remove_brigade` matches a regiment's historical name, case-sensitively.** The reading is
solid; what is unknown is **what an unnamed regiment holds in `CSubUnit +0x68`**, which decides
whether `remove_brigade = <a subunit type>` can ever match - and the mod uses the keyword **6,881
times**. A decode of `CSubUnit::SetType` found no write to `+0x68`, which is weaker than it sounds.
**The oracle is the savegame, not the executable**: a `regiment = { }` block writes `name`, so
grepping the saves for the strings the mod's own `remove_brigade` lines use settles it in one
command. 45 saves at `%USERPROFILE%\Documents\Paradox Interactive\Hearts of Iron III\BlackICE
GitHub\save games\` - per mod, **not** the install folder.

**Also free here:** `CEffect +0x14` is touched by none of the three destructors and by nothing in
`CEffect::LoadKey`. It is not even known to be live. One scan settles it.

---

## Deliberately not in this wave

**The AI, for the third wave running.** `CAIStrategy`'s collector - rvas `0x4A5270`, `0x4A5A60`,
`0x4A73C0` - is still the largest single unread thing in the image: the whole of trigger slot 10's
weighted-attribution walk exists to feed it and nothing is known about what it does with the
weights. It is out because the standing steer is away from AI logic, not because it stopped being
the best item in that direction. **Brief A's data makes it cheaper than it was**: the Lua half
already names `CAIStrategy +0x18 Personality` and `+0x148 WarTargets`, neither of which
`project.json` holds. Say the word and it swaps in for any brief here.

## Two live checks, still independent of any wave

Both would **correct a published claim** rather than add one, and both need a session:

- **`CUnit +0x2DC` across an attack decision onto an opposed amphibious landing** - the amphibious
  sign bug, which rests entirely on one opcode byte (`subsd` where the river arm has `addsd`). The
  one worth doing first; it is thinner evidence than a published claim should rest on.
- **AI agent units' `plan_air_stance`** - whether anything clears stance 2 faster than `ProcessAI`
  restores it.

And wave 12's, cheaper than either: **whether a faction member can lack a bilateral alliance**,
which decides whether `ally = { ... }` is genuinely wider than `alliance_with`. Compare
`CCountry +0xF90` (the allies count) against `CFaction +0x30` (the members count) and against the
pairs whose `CDiplomacyStatus +0x14` is non-null.

## The standing rules for every brief

All learned the hard way; all go in every brief.

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
