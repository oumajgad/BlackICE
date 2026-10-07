# What to read next, and why

The work queue. `PROGRESS.md` is the scoreboard and is generated; `CLASSES.md` is the prose account
of each class that has been read; this file is hand-written and says what is *worth* reading next,
with enough of an anchor that nobody has to find it twice. Read `TRAPS.md` before starting any of
it.

Addresses are virtual, based `0x400000`, with the rva beside them where both are given. That is
trap 1 and it is still the most frequent error.

**Cleaned out 2026-10-02.** Everything answered was removed - the `Done` archive that used to run
to 485 lines, and the four items in the open list that had since been settled. What each findings
file established is in that file; the index at the end of this page says which one to open. Where an
answered item left a residue that is still open, the residue is carried below under its own
heading rather than left buried in a struck entry.

**If a findings file cites a section of this one that is not here**, it was removed in that
cleanout and the whole of the old text is in commit `e73600a1d`. Three files were written from
briefs built out of *What those left behind*, and `findings/FINDINGS-survivors.md`, `findings/FINDINGS-production.md`,
`findings/FINDINGS-politics.md` and `findings/FINDINGS-revolt.md` all quote this file as it stood. Those citations are
true about the brief that was given and have been left alone on purpose.

**Two frontiers are closed and are never the prize any more.** All 266 `LoadKey` switches have been
read (`findings/FINDINGS-definitions.md`, `findings/FINDINGS-script.md`), and `fieldmap.py` has the offset most keys
store to, so a loader is never the thing worth reading. What is missing nearly everywhere is
**runtime behaviour** and **what a field means** - which is why the queue is now mostly live tests
and AI bodies.

## The queue

**Wave 9 is planned below, four agents.** the maintainer's priority order still holds: the interface layer,
then the last unread AI blocks, then core engine flow, then the rest. What is not scheduled is
further down.

### Wave 9, 2026-10-02 - four agents, and what the plan got wrong

**The plan below was checked against `ghidra/project.json` before launch and four things in it were
wrong.** Recorded here rather than quietly fixed, because three of the four are the same failure and
it is the one that keeps happening: *this file described as unnamed or unsettled what the record had
already settled.* That is trap 14 from the direction the trap file warns about least - a queue entry
goes stale while the record moves on under it. The briefs went out corrected.

| in the plan | what the record actually says |
| --- | --- |
| `0x8D93B0` is "**unread**" | the *body* is unread; the function is **already named** `CAIUnit_EstimateAttackOdds` with a full signature, `inferred`, and its two `CUnit +0xF0` readers are already recorded as instruction entries at rva `0x4D9825` and `0x4D9C3A` |
| the naval block "at `0x4D2418`" | that is an **rva**; the VA is `0x8D2418`. The air range in the same sentence was given as VAs - **trap 1 inside one sentence**, which is exactly the wave 7 mistake |
| `0x23A460`'s "extent is unsettled (two `ret`s, so trap 2 or trap 3)" | **settled**, and recorded as settled: trap 2, rva `0x23A460`-`0x23A83C`, `0x3DD` bytes, 283 instructions, with `cfg.py` showing no edge into the neighbour. Also already named `ResetGameStateToStartDate` |
| "the ledger window's class: `0x3C1ED0` is in no vftable" | `0x3C1ED0` is an rva, already named `LedgerPage_Update`, `confirmed`. What is in no vftable is the **class of its `void* ledgerWindow` parameter** - a different question, and the brief was rewritten to ask it |

`0x27B240` was also already named (`CGameState_ResetAtHistoryExecute`), which the plan did not say.

**No game was running when this wave launched**, so all four agents were briefed for static work.
That matters most for agent C, whose four items were written as live questions - but each has a
static route named in `FINDINGS-guilive.md` itself, and that is the route it was sent down.


**What came back.**

**All four came back and all four corrected something already published.** That is the pattern worth
noting: the wave's value was less in the new ground than in what reading the bytes did to claims the
record was already making.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `FINDINGS-attackodds.md` | `CAIUnit::EstimateAttackOdds` read end to end - it returns `ourDamage / theirDamage`, and `esi` is a `CUnit` by a five-link chain, so the land half of `FINDINGS-combatmods.md` is **promoted to a reading** | the recorded **signature** (`__fastcall` is wrong, `ret 16` against the function's `ret 20`); the published "monotone in committed strength" claim, which the *caller* enforces; and `CCombat` slot 17's "only one call site" |
| B `FINDINGS-airnaval4.md` | air phase 4's seven missions, the convoy raid's roulette draw, and three unnamed compiled-in thresholds | **phase 4 has two arms, not three** - `plan_air_stance` must be **2** for five of the seven missions, and the live stance is 1 on 1,125 of 1,126 formations. Also `0x4A7450`/`0x4A74D0` are **sunset/sunrise**, which inverted `FINDINGS-theatre2.md`'s "loads only in the dark" |
| C `FINDINGS-guistatic.md` | `CFixedWindow`'s **two** `CGuiObject*` child lists; registries 1 and 5 are the `3dButtonType` and `threeDguiType` indexes, empty because those keywords appear **zero** times in mod or vanilla; the ledger is a `CStatisticsLedger`; `CCheckBox` named from the widget's own string | `FINDINGS-guilive.md`'s RTTI negative - **wrong for two of six names despite carrying a positive control**, because the sweep spelled it `Checkbox` and the image spells it `CheckBox`. Also its `0x18`-byte node size (it is `0x10`) and `LedgerPage_Update`'s recorded parameter |
| D `FINDINGS-session2.md` | `0x27B240` end to end - its last 0x560 bytes **parse `gameplaysettings.txt`** into the game state, a live but unused mod hook; `0x23A330` named | `CInGameIdler +0x1790` is the **`CEU3Application`**, not a `session_manager` - `SessionManager` occurs **zero** times in the image, and the shipping DLL was already right where `project.json` was wrong |

**Landed:** 21 addresses and 27 struct fields merged; the record went 2,270 -> **2,275 functions** and
2,707 -> **2,739 fields**, labels 543 -> 559. Recorded signatures that disagree with their `ret` went
88 -> **87**.

**The Ghidra apply ran and reported `failed: 2`** - the pass mark, and both failures are the two
documented over-long bodies (`TernarySearchTreeFind` inside Ghidra's `GuiTypeTree_Find`, `MT19937Next`
inside its `CSimpleRandom::GetInteger`). It named 2,273 functions, 559 labels, 2,033 signatures, 88
struct fields and 206 virtual tables, and the two `CInGameIdler` renames landed visibly
(`+0x1790 application: named session_manager`).

**It ran against a scratch copy, not the maintainer's project.** Ghidra was open on `Hoi3_v12.1.2` at the
time - a live lock and a 1.2 GB `javaw.exe` - and the contract in `fragments/README.md` says
concurrent headless runs fight over the lock. So the names are in `project.json`,
`bicelib_findings.json` and the scratch database; **applying them to `Hoi3_v12.1.2` is the maintainer's step**,
the same division as `Deploy.ps1` and the game folder.

*An earlier version of this entry said the Ghidra installation was not on this machine. That was
wrong - the search behind it was `find /c -maxdepth 4` and the installs sit at depth 6, under
`Documents\Ghidra\ghidra_*_PUBLIC\support\`. The exact command is in `ghidra/README.md`.*

**Three schema faults in the agent contract, found independently by three of the four agents** and
now written into `fragments/README.md`: the field list is `struct_fields` and a fragment saying
`fields` lands nothing silently; `confidence` takes only `confirmed`/`inferred` although four
documents and `project.json` itself use `likely`; and **every** key in `ADDRESS_KEYS` must be
present, so a signed entry still needs `"no_signature": null`. The first of those was **my** error in
all four briefs.

### Wave 10, landed 2026-10-02 - four agents, and the record arguing with itself

**All four came back; three of them overturned a published conclusion, and two of those three found
the contradicting fact already sitting in `project.json`.** That is the wave's lesson and it is a
process one: nothing in the pipeline compares a new conclusion against what the record already says.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `FINDINGS-aihelpers.md` | both AI combat helpers read end to end. **The AI keeps its own copy of the land combat modifier model** - 11 of 20 modifiers identical, 4 partial, 6 absent - and it **adds** fractions where the battle **multiplies** clamped factors. The helper is the **dominant** term, not a garnish: single terms reach ±4.0 against an engagement factor whose maximum is 1.0 | an **amphibious sign bug** (`subsd` where the river arm has `addsd`, both guarded by the same `jns`), making an opposed landing the most attractive move in the AI's model; `FINDINGS-combatmods.md`'s stacking rule, which is right for the defender and wrong for the attacker; and §10's callee list, which attributes four functions to both helpers when two are defence-only |
| B `FINDINGS-sigaudit.md` | the 87 disagreements were **30 tool and 57 record**, and the run now reports **1** - the one left is a recorded address that is not a function start | **`Hoi3CString` by value is `0x1C`, not `0x18`** - and the proof was already in `BiceLib/GameClasses/CTrait.hpp`, which strides a `Hoi3CString[16]` by `0x1C` and checks it. Three *invented* parameters removed as a result. Also `CMap::MapPath` is not a `CMap` member, and five records write the register as a C comment, which reaches nothing |
| C `FINDINGS-guicontainers.md` | `+0x414` is the **subwindow map**, the engine's own word, from its warning at `fixedwindow.cpp:1042`; all 28 `CWindowType::LoadKey` tokens tied to their containers, turning three `likely`s into `confirmed`s | `child_windows_begin` on `+0x2FC`, which is the vector half of `AttachChild`'s pair and not a child-window container; and "fourteen containers from `+0x174`", which is wrong twice - there are thirteen, from `+0x184` |
| D `FINDINGS-airstance.md` | `0x4B4740` fills all four `air_target_provinces_*` lists, reached by a plain `lea reg,[agent+0x1FC]`; the scorer is a **mean map distance** and the lists are **lowest-first**, so low is good | **`FINDINGS-airnaval4.md`'s headline.** The AI *does* set `plan_air_stance` to 2, on every agent, every `ProcessAI` pass - so the five strategic and naval air missions are **live**. The live distribution that said otherwise was read off air formations; the gate reads `agent->unit`, the army. Also `CUnitPlan::SetActive` resets to **1**, not 0 |

**Landed:** 85 addresses and 40 struct fields offered, 20 new addresses and 40 fields merged, the
rest revisions. Record **2,275 -> 2,291 functions**, **2,739 -> 2,771 fields**, labels 559 -> 563,
signatures 2,033 -> **2,050**. Headless apply **`failed: 2`** - the pass mark, both the documented
over-long bodies. **Signature disagreements 87 -> 1.**

**Two agents' work collided productively.** B's patched checker immediately flagged three of C's
brand-new signatures: C wrote `__thiscall` with `this` implicit *and* the real parameter left bare,
which under Ghidra's positional rule puts `name` in ECX. Fixed by spelling `this`. A tool patch that
catches a defect in another agent's output the same hour it lands is the best evidence it is right.

**What the plan got wrong this time** - the fourth wave running, so it is worth keeping the tally:

| the plan said | the bytes said |
| --- | --- |
| `attached_children_head` sits on `+0x2FC` and `+0x414` may unseat it | it is on **`+0x74`**; `+0x2FC` is `child_windows_begin`. Different claim, and the name **survives** - `AttachChild` writes `+0x2FC` and `+0x74` in one body |
| the `__fastcall` signature bug "accounts for 3, not 49" | 21, not 3. It swallows a **bare** parameter too, not only an `@stack:` one |
| a wrong signature needs a hand edit, because the merge never overwrites one | `mergeFindings.py` has a **`revises`** key for exactly this; 63 revisions landed from a fragment |
| fourteen `CWindowType` containers at a `0x10` stride from `+0x174` | thirteen, from `+0x184`; `+0x174` is an unrelated 4-stride pointer vector `LoadKey` never touches |
| `gameplaysettings.txt`'s grammar makes the hook "nearly useless" | the premise held, the conclusion did not - the save grammar *contains* a `gameplaysettings` key. What limits the hook is **when** it runs |

### Also ready, and cheaper than they look

- ~~**`gameplaysettings.txt`'s key set.**~~ **Done 2026-10-02**, written up as
  `findings/FINDINGS-session2.md` section 7, and the prediction recorded here was half wrong. It
  *is* the game state's save grammar - 21 of the switch's keys appear at the top level of a real
  save - but that grammar contains a **`gameplaysettings`** key of its own (token 1551, arm at VA
  `0x68048A`, recursing through slot 3 into the `CGamePlaySettings` the record already names at
  `CCurrentGameState +0xC90`), so the file is named after a block that genuinely exists and the
  "nearly useless" conclusion drawn here did not follow. `CGamePlaySettings::LoadKey` (rva
  `0x28A550`) takes exactly one key, `setgameplayoptions`, so the nested payload is two ints:
  `difficulty` and `arcade_mode`. What really limits the hook is **when** it runs - `0x27B240`'s one
  caller is `CEU3Application::LoadEverything`, so the parse is at startup, and the lobby writes both
  of those values afterwards and wins.
  **Two things came out of it that are worth more than the item was:** the recorded key list for
  `CGameState::LoadKey` is **short by at least five** (`ai`, `convoy`, `theatre`,
  `strategic_warfare`, `sunk_ships` - all five read by hand off the chained-`sub` arms, with `ai`
  cross-checked because its arm reads the `skip_automation_keys` byte that the record's own field
  comment says gates `ai`); and **45 savegames are on this machine after all**, under
  `Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\save games\` - per mod, not
  in the install - so the plain-text oracle is available and a pass today that reported none had
  simply looked in the wrong two places.
- **`0x27E550`** (VA `0x67E550`, **unrecorded** - checked; the nearest below is
  `CGameState_SetProvincesAndSizePerCountryVectors` at rva `0x27E320`). It installs the game state's
  country list from the database and resizes the per-country vectors; read far enough in wave 9 to
  describe, not to name. On the frontier.
- **`0x4EFA50`** (VA `0x8EFA50`, **unrecorded** - checked) - the province predicate air phase 4 and
  the ops-area scorer both call, and `FINDINGS-opsarea.md`'s own open question 2. Wave 9 read four
  arms into it and reports the record's one-line summary is incomplete.
- **`0x4D0520`** (VA `0x8D0520`, **unrecorded** - checked) - the per-province predicate that excludes
  a convoy province from raiding. Until it is read, "the AI will not raid its own side's shipping
  lanes" is an inference from where it sits.
- **`CGameState::LoadKey`'s key list and `CGamePlaySettings::LoadKey`'s comment** need a **hand
  edit** for the same reason - the merge never overwrites a comment. Add the five missing keys to rva
  `0x27FCB0`, and note on rva `0x28A550` that it is the grammar of a mod's `gameplaysettings.txt`
  inner block and not only of a save's. `findings/FINDINGS-session2.md` section 7 has both, with the
  path-by-path evidence.
- **`CStatisticsLedger`'s two fields and `LedgerPage_Update`'s signature** still need a **hand
  edit**, but for one reason rather than two: `struct_fields` cannot create a struct that
  `project.json` lacks. **The "merge never overwrites a signature" half of this was wrong** -
  `mergeFindings.py` has a `revises` key and wave 10 landed 63 signature revisions through it.
  `FINDINGS-guistatic.md` §4 has the corrected form (`ShowPage(ledger@EDI, int page)`) and the two
  fields with their evidence.

### Wave 10's three decisions - two done 2026-10-03, one still open

1. **STILL OPEN: `0x450AB0 CreateMapBinCacheOwner` is not a function start.** It is the
   `call 0x486F10` *instruction* at VA `0x850AB0`, sitting inside the function that begins at rva
   `0x450520`; `functionStart` answers `0x450520` and `retsBefore` between them is empty, so there
   is no boundary in between. The author wanted to record *the caller* of the constructor and wrote
   down the address of the call rather than the caller's entry. **Two things follow:** the name never
   reaches Ghidra at all (`buildFindings.py` prints `not a function start, left out:
   00850AB0 ::CreateMapBinCacheOwner`), and it is the **last** of the original 87 signature
   disagreements, since a `void (void)` signature predicts `ret 0` against the `ret 4` found by
   disassembling on from mid-function.
   **Recommended: re-point it to rva `0x86F10`**, which is what the name actually describes. That
   address is a clean function start (`push ebp; mov ebp, esp`), ends `ret 4` at VA `0x4872DC`
   followed by `int3`, publishes itself at the global `0x1A85578` (`mov [0x1a85578], edi` at
   `0x486F8F`), references `'/cache/map.bin'` twice, and has exactly one caller - the very call that
   was mis-recorded. It wants the signature `void __stdcall CreateMapBinCacheOwner(void* owner)`,
   `this` arriving on the stack from the caller's `operator new(0x48)`. The alternative, re-pointing
   to `0x450520`, gives the name to a large loader that does much more than this; dropping the entry
   loses a live name for no gain. **The fact the entry exists to carry - that `map.bin` is the
   graphics side's and not the province graph's - is already applied to `0x8DFA0` and `0x8E2E0` and
   survives any of the three choices.**
2. ~~**`CNavalCombatant::PickTarget`**~~ **Done: renamed `CSubUnit::PickTarget`.** The receiver is in
   ECX and is a `CSubUnit` - the entry does `mov edi, ecx; mov eax, [edi+0xb0]` and `+0xB0` is
   `CSubUnit::unit_ptr`. Checked first that it is **not a virtual** (`vtable.py --holding`: no table)
   and has one caller, `CNavalCombatant::Attack`, so nothing inherits the old qualifier. The reason
   is recorded on the entry so the next reader does not put `CNavalCombatant::` back.
3. ~~**`CDefines +0xAC`**~~ **Done: `CDefinesSupply` -> `CDefinesMilitary`, `supply_defines_ptr` ->
   `military_defines_ptr`.** A live game was offered and **would not have helped** - the question was
   never factual. `definesMap.py --check` lists the blocks `defines.lua` actually has: country,
   economy, military, diplomacy, alignment, map, weather, goods_cost. **There is no `supply` block**,
   so the old name had no referent to be right about, and the pointer and all 178 field names were
   correct the whole time. Only the two labels were wrong. `FINDINGS-supply.md` had recorded it as "a
   naming wart left alone" since that wave, which is why it took a prompt to fix rather than a
   discovery. Nothing in code depended on either name - one doc comment in
   `BiceLib/GameClasses/CDefines.hpp`, one line of `CLASSES.md`, one in `FINDINGS-supply.md`.
   *One thing to know when you apply this:* a struct **rename** leaves the old `CDefinesSupply`
   behind in a Ghidra database that already has it, since the apply creates by name and does not
   delete. `ResetBiceLibOrphans` is the tool for that if it bothers you.

Plus **`likely`, which agent B answered with evidence and a recommendation rather than a change**:
`project.json` holds **219** of them, `buildFindings.py` maps `confirmed`->CERTAIN and
`inferred`->TENTATIVE with a `.get(..., "TENTATIVE")` default, so all 219 already land as TENTATIVE -
*indistinguishable from `inferred`*. B recommends **not** adding the word, because that default means
a **typo** also degrades silently and the validator's short list is the only thing that catches one.
Preferred fix: drop the third word from the three documents and convert the 219. A wrinkle worth
knowing: the Ghidra output *does* have a LIKELY tier with 81 members, but those come from
`buildFindings`'s own hardcoded cases (folded bodies, luabind wrappers) - so a real tier exists that
the record's own `likely` cannot reach, which strengthens B's case rather than weakening it.

## Wave 14 landed, 2026-10-06

Four briefs: the fragment tooling plus the blocked structs, `CContextTrigger`'s scope rebinding, what
a trigger forest costs, and the faction layer. **27 addresses, 18 new structs and 20 struct fields
landed**, which generated **121 new fields** off the eight `inherits`-only subclasses. `buildFindings`
printed no `!` lines; the headless apply gave `struct fields: 450, replaced: 0, failed: 0` and then
`0 / 0 / 0` on a second pass - **the first wave to settle to the pass mark on its own**.

Where the prose went: `findings/FINDINGS-faction.md` (new), `findings/FINDINGS-triggereval.md`
§10-16, `findings/FINDINGS-scopetriggers.md` §11-16, `findings/FINDINGS-diploaction.md` §30.

**The four results worth knowing without opening a file:**

- **`ally = { ... }` is enormously wider than `alliance_with`**, and this had been an open question
  since wave 12. A faction join writes no `CDiplomacyStatus` field at all, and in the 1945 save the
  whole world holds **7** bilateral alliances against **674** intra-faction country pairs. Two of
  those 7 are between countries in no faction, so the implication fails both ways. `is_in_faction`
  is the test for "same side"; `alliance_with` is the test for "we have a treaty".
- **Nothing in the trigger forest is cached, and `and` short-circuits while the tooltip tally does
  not.** The cost is one full tree walk per candidate event per country per game day, from
  `RunDailyEventPass`. Slot 11 - the `"%d / %d"` figure - has exactly **one** root in the image, a
  triggered-modifier panel gated on a day-of-year change, so tooltips do not double anything.
- **A scope switch writes five offsets and nothing else**, so `FROM`, `THIS`, the seed, the rebel
  faction and the combatant provably survive any depth of nesting - while `ally` and `local_enemy`
  keep the *outer* province and `capital_scope`/`sea_zone` throw the country away.
- **Faction leadership is positional and cannot be set.** It is the first member; a join always
  appends. The only promotion path in the image runs when the leader goes into exile, and picks the
  surviving member with the highest max IC.

### Queued hand edits - the first three are done, 2026-10-06

These came out of wave 14 and are listed here because `mergeFindings`' `structs` key is create-only
and the duplicates predate the check that would have refused them.

1. ~~**`CTradeRoute` needs `"inherits": "CRelation"`.**~~ **Done 2026-10-06.** RTTI puts `CRelation`
   at **offset 0** on it and no CRelation field shared an offset with its twelve, so it was safe. Its
   `+0xC first_id` and `+0x14 second_id` - whose own comments already said "Id half of the CRelation
   base's `first`/`second`" - are now folded into the inherited 8-byte tags, which the apply reported
   as `CTradeRoute+0x8 replaced 'first_id' with first`. Generated fields 3036 -> 3040: six inherited
   minus the two folded.
2. ~~**`CBuildingConstruction` and `CConvoyConstruction` have wrong `vftable_rva`s.**~~ **Done
   2026-10-06**, `0x11BDCD4` -> `0x11BDCAC` and `0x11BDD34` -> `0x11BDD04`. Verified off the bytes
   before the edit: `[0x15BDCA8]` and `[0x15BDD00]` hold `0x1611C8C` and `0x1611C38`, which are
   `.rdata` complete-object-locator pointers, so each table begins at the next dword - and
   `[0x15BDCAC]` and `[0x15BDD04]` both hold `0x5501D0`, a real code address and their shared first
   slot. The recorded values were 10 and 12 slots in.
3. ~~**Four duplicate field records.**~~ **Done 2026-10-06**, merged to one each, the survivor keeping
   position zero so the fold order is unchanged. `CDiplomacyStatus +0x14` is now **`CAlliance*`** and
   `+0x1C` **`CGuarantee*`** - both previously reached the decompilation as `void*`, because
   `merge_fields` keeps whichever record comes first - each carrying both halves of the account, since
   the `void*` records held the predicate derivations and the typed ones the `Activate` writers and
   save blocks. `CCountry +0xA8C` and `+0x10B8` were the harmless shape (same name, same type) and
   just have their two comments merged; note the **Lua half still wins their name and type**, so they
   reach Ghidra as `Neutrality`/`NationalUnity` typed `CFixedPoint`, which is item 6's rule and is
   right here.
4. **`buildFindings.py` should print a `!!` line for a duplicate `(struct, offset)`**, the way it
   already does for two address entries on one rva. A one-line `Counter`. **It would print nothing
   today** - item 3 cleared the last four - which is exactly why it is worth adding now: it is a guard
   against the duplicates coming back silently, not a backlog report. The reason to add it at all is
   that a duplicate costs more than a duplicate address entry does, because `merge_fields` quietly
   keeps whichever comes first and the file then holds two answers with neither run complaining.
   Refusing rather than reporting is still the wrong call: a wave should not be blocked on a record
   nobody has had time to merge.
5. **`buildFindings.py` should report its folds.** A field lying inside a larger typed one is dropped
   from the generated output and its text moved into the host's comment, and **nothing says so** - the
   existing overlap warning runs on the post-fold list. Two of wave 14's four agents independently
   concluded that the twelve `CCountryTag` id-half records would start an apply cycle; both were wrong,
   and both would have been saved by one printed line. The shape of that output is a judgement call,
   which is why it is queued rather than done.
6. ~~**`CEventScope +0x10` reaches Ghidra as a 4-byte `CCountryTag *`** over four bytes of tag
   letters.~~ **Done 2026-10-06**, by two rules rather than one, because there turned out to be two
   independent causes. See *The Lua API census* below; the field is now `country_tag char[4]` and
   `CResearchBonus +0x4` is `CFixedPoint` by value. `CList<CSubUnitConstructionEntry> +0x4` is left
   alone and that is now a result rather than a gap: it is accessor-derived, where a `T&` can
   legitimately be a pointer member.
7. **`reconcileFacts.py`'s wording** for the Lua-only row should say "already in the record, through
   the Lua half" rather than "need a struct record first", which reads as 44 missing facts and cost an
   agent a detour.

### The residue - what wave 14 left, in rough order of value

- **The five collector entry points**: `0x4A4F50`, `0x4A51C0`, `0x4A5270`, `0x4A5420`, `0x4A5620`, all
  unnamed, all in `CAIStrategy`'s region. This is **what the whole slot-10 machinery exists for**, and
  reading it from the trigger side got as close as the standing steer allows. `0x4A51C0` is the one
  that takes **text**, which is the shape to know before starting.
- **`CValueTrigger` and `CIntTrigger`'s slot 7** (`0x5D13E0`, `0x5D1400`, abutting, two different unit
  conventions - `TokenToFixedPoint` into `+0x40` versus an argument-token test against `0x377`).
  Neither class has a vftable of its own, so which body belongs to which has to be argued from the
  derived classes that hold each. Settling it matters out of proportion: **111 of the 156 trigger
  classes are `new(0x44)`**, one dword at `+0x40`, so one declaration each would place that field on
  all of them. **The single biggest remaining win in this family.**
- **`CDeclareWarAction::Apply`'s call at `0xA121CE`** passes `(country, 0, 0)` on a path gated by a
  slot-7 `IsValid` answering false - so it is a faction *leave*. **It looks like declaring war can
  eject a country from a faction**, which would be a real rule nobody has written down.
- **`0x102BC0`**, the capitulation/exile function holding the faction leader promotion. 7 callers,
  four `ret`s between `0x50315F` and `0x5033AD`; worth a brief of its own.
- **`CCountryList` has no layout at all** - not a struct record, and not special-cased beside
  `CUnitList` in the `CList` pass - so `Allies (+0xF88)`, `Vassals (+0xF78)` and the rest decompile as
  untyped blobs. Giving it the `CList` layout would retire the three hand-added
  `non_hostile_countries_*` workaround records at `+0xF98`-`+0xFA0` at the same time.
- **`CCasusBelliType`'s 22 loader offsets**, now landable: token table `0x416924`, jump table
  `0x4168E0`, base token `0x78D`. Best given to one agent whole.
- **`CContextEffect`'s struct** - spec at `+0x20`, object `0x130`, same `CEventScopeSpec`. One
  declaration.
- **`CTrigger +0x1C[2]`** - a `std::vector`-shaped container of two `0x10`-byte elements; its element
  ctor/dtor (`0x9DB0`, `0xC480`) are referenced from **200** sites, so naming it needs the container
  identified rather than the trigger. A displacement scan **cannot** settle it; that was tried and is
  written up as a trap 12 case.
- **`CTrigger +0x3C`** - cleared by every container constructor and set to 1 by `CTrigger::LoadKey` at
  `0x5C915B`. No reader identified.
- **`scratchpad/triggersizes.py`** pairs 156 trigger class names with their allocation sizes in one
  command and generalises to any loader that builds its classes with `new`/constructor pairs. Worth
  promoting to `scripts/` by someone who can name it.
- **Two holes in wave 14's own negatives, both stated by the agents rather than found later:** slot
  11's root search cannot see three arguments written with `mov [esp+N]` instead of pushed; and the
  faction layer's "no alliance is created" rests on `0x4E70A0` and `0x4FBC10` having been skimmed only.

## A live check: does `at_sea` lock a fleet's `carrying` list? - 2026-10-07

**This would be a real bug if it holds, and it is cheap to test in a session.** It came out of
settling what `CList +0xC` means (`findings/FINDINGS-factbase.md`).

What is established, both ends off instructions:

- **`CList`'s fourth member at `+0xC` is a deferred-deletion lock.** While set, code that would
  remove a node **marks it and leaves it linked** instead. `CWeatherManager::Tick` reads it at VA
  `0x4B5CD7` and branches: set -> `mov byte ptr [eax+0xc], 1` on the spent node and skip the
  unlink; clear -> relink `prev`/`next` and fix `first`/`last`.
- **`CUnit +0x2E4 carrying` is a `CList<CUnit*>`**, so `0x10` bytes, `+0x2E4`..`+0x2F4`.
  `CheckTransportOverload` (rva `0x1CFBD0`) reads it twice, `add eax, 0x2e4` and
  `mov esi, [edi+0x2e4]`.
- **`CNavy::LoadKey`'s save-token-`0x3FC` (`at_sea`) handler writes a dword there**:
  `mov dword ptr [ebx + 0x2f0], eax` at `0x1CF6FE`. `+0x2F0` is offset `0xC` inside `carrying`.

So on the face of it, **a fleet restored from a save with `at_sea` set has a non-zero lock on its
own carried-units list, and would never unlink a node from it again** - the list would still work,
it would just never shrink. That is exactly the shape of thing nobody notices.

**Why it is a check and not a finding.** A layout where the game deliberately parks a loaded field
in a container's lock slot is strange enough to want confirming, and three readings are possible:
the collision is real and is a bug; `carrying` is not `0x10` here (some other list instantiation);
or one of the two offsets is a few bytes out despite both being instruction-anchored. Nothing
static separates them, because both claims rest on decoded instructions that are individually
sound.

**The test, in one session.** Load a save with a fleet at sea carrying at least one unit, then
watch `CUnit +0x2E4`'s `count` (`+0x2EC`) across an unload:

- if the count **decreases**, the lock is not being set and the collision is not real;
- if the count **stays** while the carried units are plainly gone, the lock is set and the nodes
  are being marked rather than unlinked - the bug;
- and `+0x2F0` can be read directly at the same time: non-zero after loading an at-sea fleet is
  the lock being set, zero means `at_sea` is not landing where it looks like it does.

A second, cheaper angle: compare a fleet that was **at sea in the save** against one that put to
sea during play. Only the first goes through `LoadKey`, so only the first should show the symptom.

The record carries the open question on both fields - `CList +0xC no_unlink` and
`CNavy +0x2F0 at_sea` - rather than a claim, and `at_sea`'s type was corrected from `uint8_t` to
`int` at the same time, since the write is four bytes wide.

## The planned next wave is in `WAVE.md`

**It is not in this file any more.** `WAVE.md` holds the wave that is planned and has not launched,
on its own, because finding the plan in five hundred lines of queue and archive was a search rather
than a glance. This file keeps the standing backlog and every landed wave's result.

**Wave 13 has landed** - its result is two sections down. **Wave 14 is written into `WAVE.md`
and has not launched**: four briefs, the first of which teaches the pipeline to create a struct and
lands the 37 classes blocked behind that, and the other three take the evaluation half of the
script language and the faction layer. So `WAVE.md` is current, not stale, and the paragraph here
that said otherwise was itself stale within a day of being written - which is the drift the
two-file contract at the top of `WAVE.md` exists to prevent. The AI collector has now been held out
of four waves running.

### 2026-10-05, from `TODO.md`: the air defence stat, and it is not a scale bug

**`air_defence` has no consumer in any combat path.** `findings/FINDINGS-airdefence.md` has it in
full. The TODO asked whether the stat misses the fixed point system or is a magnitude too low;
neither. It is parsed by the same `TokenToFixedPoint` as 42 of its 44 siblings (`air_attack` is the
positive control, byte-for-byte the same four instructions), and divided by the same `1000.0` in
all three unit stat panels. The one combat function in the image that reads it,
`CBomberCombatant::FireUnit` (`0x160B90`, named this session), multiplies it by the target's
`combat_defend_product` and writes it back to its own frame slot, where **nothing ever reads it** -
five accesses to the slot, no esp alias, decode verified by recursive descent reaching 829 of 829
instructions. MSVC kept the store because the `imul` reads it on the next iteration: a dead cycle,
not a dead store.

Every air and bombing roll instead uses a flat `CHANCE_TO_AVOID_HIT_AT_NO_DEF` - four sites, all
clamped to 99000, none of them reading `BASE_CHANCE_TO_AVOID_HIT`. `CUnit::RollToHit`, which is
where a defence stat buys anything, has **exactly one caller in the image** and it is
`CLandCombatant::FireUnit`. So the mechanic is land-only by construction. In BlackICE that means a
flat 30% chance to be hit per shot for every brigade, ship and wing under air attack, whatever its
air defence; an AA brigade's `air_defence = 25` is inert and its `air_attack = 22` is the live half.

**And the same question about `sea_defence`, asked by a player a few hours later, has the same
answer only cleaner**: neither `sea_defence` (+0x160) nor `surface_defence` (+0x174) is read
in any combat function - 3 definition-pointer reads each, none in the combat classes, and a
654-function closure from the naval roots with no `+0x160` read in it. The positive control is
in the same function: the identical filter finds `sea_attack` twice and `hull` three times in
`CNavalCombatant::Attack`. `hull` is the ship survivability dial, as a straight divisor on
both kinds of damage. That also closes `findings/FINDINGS-combatmods.md` §9's open question -
naval does **not** have the land `defences_used` structure, because `CUnit::RollToHit` has one
caller and it is `CLandCombatant::FireUnit`. All five stats now carry comments on
`CSubUnitDefinition`, which had none.

Two corrections to the record came out of it, both now in `project.json`:

- **`CSubUnit + 0x54`'s "read at 0x56645E and nowhere else" is false** - there is a second reader at
  `0x160E5B` - and the conclusion built on it survives, because that second reader's result is the
  discarded air defence value.
- **`CCombatant + 0xB0` `front_line` is the land family's layout, not the base's.** The air and
  bombing combatants use the same offset as a count with an inline `CSubUnit* targets[1024]` at
  `+0xB4`. The allocation sizes settle it: `CLandCombatant` is **0xE4**, `CAirCombatant` and the
  `CBombTargetCombatant` family **0x10B4**, `CBomberCombatant` **0x10E8**, and `0x10B4 - 0xB4` is
  exactly 0x1000. So `sizeof(CCombatant)` is 0xB0 and the field belongs on `CLandCombatant` - which
  has no struct record to move it to. **That is a third live instance of wave 14 brief A's
  blocker.**

What it left open, and none of it is urgent:

- **`0x346260` and `0x499770`**, the two `air_defence` readers named only by address.
- **`0x163110`**, the other half of what `CGroundTargetCombatant::Attack` forwards to, unread.
- **`StaticAntiAirTerm` (`0x162370`, `likely`)** read only as far as `STATIC_AA_SCALE` and the
  `[side+0x114]`/`+0x258` value it scales. The province's anti-air is a third channel and reading
  it through would close the anti-air picture.
- **The two live checks** in the findings file: a hook on `0x160D44` to prove the path is reached at
  all, and one on `0x160FDE` to show the threshold never moves with the target's air defence.
- **Whether this is worth a mod-side answer.** If the stat is inert, every `air_defence` line in
  `units/*.txt` is documentation rather than balance, and the AA that does work is `air_attack` plus
  the province's static AA. That is the maintainer's call, not a reversing question.

### Wave 13, landed 2026-10-05 - four agents, and the headline was that a measurement was misleading

**The wave's shape: brief A's own premise did not survive brief A.** The wave was planned around
"713 fields the generated record holds that `project.json` has no field for", read as a measure of
unread layout. It is not one. **386 are inheritance copies** - Ghidra has no struct inheritance, so
`buildFindings` stamps a base's fields onto every derived struct - and **216 are generated `CList`
plumbing**. `CAir` 60, `CNavy` 60, `CArmy` 59 are `CUnit`'s fields counted three times. The
actionable set is **111**, and the unit classes were never the hole they looked like. *Taking that
count for unread layout is how `CAir` got onto a queue.*

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A | 111 actionable fields triaged, 67 landed; 108 name disagreements classified; `reconcileFacts.py` and `crossFragments.py` written; `--check` taught to compare `struct_fields` across fragments | `CCountry +0x604` is **`TotalIC`**, not `base_ic`; `+0xF34`/`+0xF38` are **`isSubject`/`Overlord`**, not `has_faction`/`faction_leader_tag`; trap 4's holder check had only ever been run against the vftables |
| B | there is **no `CEffect` slot 12** - five sibling middles each declare their own, and one slot index carries two unrelated signatures; a government in exile reads **its own** pool | the plan's replacement reading of the resource-trigger branch, which said the branch does not select a different pool. It does |
| C | the war-goal chain end to end; `0xF50A0` is a **breadth-first spread**, not an adder; `CDiplomacyStatus::LoadKey` gives ten keys to ten offsets | "adding a war goal consumes the casus belli" is no longer inference - the function's own key is `WELOSECB`; `0xF50A0` has seven call sites, not four; trap 2's prologue set needs `0xC6` |
| D | `+0x59` has **no reader**, from a 60-site census of the whole image; `check_variable`'s side effect is **erased by the next save**; every regiment has a name | **`surrender_progress` was inverted in the record** - high means about to surrender; `CEffect +0x14` is a byte written 41 times by `LoadKey`, where the record said nothing touched it; `CTernaryNode`'s three links |

**Counts:** 2,478 -> 2,504 functions, 2,232 -> 2,260 signatures, `project.json` 2,232 -> 2,311
fields. `checkSignatures` 1,573 entries none disagreeing, `checkrefs` 658 all resolving, headless
apply `failed: 0`. Write-ups: `findings/FINDINGS-factbase.md` (new) plus sections appended to
`FINDINGS-effects.md`, `FINDINGS-numtriggers.md`, `FINDINGS-diploaction.md` and
`FINDINGS-negatives.md`.

**Two results were overwrites and both were verified off the bytes by the collecting session**
rather than taken on the agent's word, because a wrong new name costs little and a wrong overwrite
costs a published claim. `0xFCC60` really is `1000 - clamp(controlled*1000/owned)` and the caller
really does take the occupied share as the multiplicand with unity as the divisor, so the direction
reverses; and `CCountry::UpdateIC` really does write `+0x604` and `+0x60C` from one register and then
scale, floor and re-read only `+0x604`. That check is now a standing rule - see the report format in
`CLAUDE.md`'s subagent section.

#### What the wave changed about how a wave is run

- **Agent reports now have a required shape**: a 2-5 sentence synopsis, then a table of every
  function the fragment touches marked `new` or `revised`. Wave 13 came back in four different
  shapes and finding "what actually changed in the record" was four separate searches. In
  `CLAUDE.md` and in `WAVE.md`'s standing rules.
- **The `revised` rows are the ones to verify.** See above.
- `mergeFindings --check` now refuses a cross-fragment `struct_fields` disagreement, and
  `scripts/crossFragments.py` reports agreements as corroboration. Running it over
  `fragments/merged/` found **six field disagreements that had already landed**, one pair resolved
  by merge order rather than by anything checking.

#### Mod-facing, for the maintainer rather than for the record

1. **Fifteen `remove_brigade` lines in the mod are dead because of case.** Fourteen are one
   systematic typo - `Kampfgruppe` for `KampfGruppe` - all in `events/KampfGruppen.txt`; the
   fifteenth is `Thomas Mcguire` for `Thomas McGuire` in `events/battlecommanders.txt:2740`.
   `events/KampfGruppen.txt:712` also has `brigade_in_combat = "Kampfgruppe Bock"`, which will have
   the same problem if that trigger compares the same way - **that trigger was not read**.
2. **`enemy_ic_ratio` compares MaxIC**, i.e. raw province IC before the global and technology
   scaling, before the resource cap and before lend-lease. It is not a ratio of the IC either
   country runs on. `total_ic` reads the scaled total.
3. **`money = 0.5` means half a unit as a trigger and zero as an effect.** All seven `*PoolEffect`
   classes are `CIntEffect` heirs, whose scalar is `atoi(text) * 1000`; the six triggers are
   `CValueTrigger` heirs, whose scalar keeps the decimal. Nothing in the script shows the difference.
4. **There is no `fuel` trigger**, though `CFuelPoolEffect` exists - a script can set a country's
   fuel and cannot test it.
5. **`surrender_progress = 0.05` is "any loss at all", not "always true"** - and it measures occupied
   **claimed** territory, so a mod-made country whose claims list holds no province it owns can never
   surrender by this measure.
6. **`war`, `war_goal`, `undeclared_war_region` and `modify_spies` with no country named** fall
   through to the scoped province's **controller**, not its owner. Occupation, not ownership.
7. **Flag and variable names are case-insensitive** (the tree folds the key through `tolower`), which
   is the exact opposite of `remove_brigade`.

#### Open, from wave 13, in rough order of value

1. **`0x4F5F30`, the faction mutation** - a ~0x950-byte `__thiscall` where `CFactionAction`'s real
   effect lives, since slot 7's only country write is the influence charge. Agent C named this the
   single highest-value thing it left.
2. **Four duplicate field records, where the `void*` wins.** `CDiplomacyStatus +0x14` and `+0x1C`
   hold both `void*` and `CAlliance*`/`CGuarantee*`; `merge_fields` keeps the `void*` and demotes the
   typed one into its comment, **so the decompilation gets `void*`** - confirmed in the generated
   record. `CCountry +0xA8C` and `+0x10B8` are the same shape but harmless (same name and type
   twice). Deliberately not fixed: the pairs are *not* identical - each carries a different comment
   from a different findings file - so deleting one loses a reading and merging them is a content
   call. Four hand edits.
3. **Five recorded names sit on a body another luabind registration claims** - `0x16000`, `0x944C0`,
   `0xC8920`, `0x4E9090`, `0x2EF70`. Three contain an explicit, now-false negative such as "nothing
   outside it holds the body at all". `reconcileFacts.py` prints them in one command. Renaming is the
   maintainer's call because the names are load-bearing in a lot of prose.
4. **44 Lua fields cannot land**, because `mergeFindings` refuses a field on a struct `project.json`
   has no record for and a fragment cannot create one. 18 structs; the 13 `def_readwrite` ones among
   them are the **strongest** records in the whole Lua half. Either `mergeFindings` grows a `structs`
   key or the 18 stubs go in by hand. `CGoodsValues`, `CResourceValues` and `CStrategicWarfare` are
   the ones worth having.
5. **`CCasusBelliType`'s 22 loader offsets** - the table is derived and written out in
   `FINDINGS-diploaction.md` section 27; the struct holds one field. A hand-add.
6. **`CRelation` and eleven sibling structs still do not exist** in `project.json`, so nine
   subclasses write through a layout recorded nowhere. The layouts are prose in the same section.
7. **When does a casus belli expire?** `CCasusBelli` slot 11 (`0x647D20`) is the only path that
   raises `WELOSECB` to the player and has **zero direct callers** - reached virtually.
8. **`CEventScope +0x10`** - the record has `char[4] country_tag`, the Lua half types it
   `CCountryTag&`. If the Lua half is right there is an unrecorded `+0x14` and the scope's tag
   comparisons read the id half, which is how every other tag comparison in the image works.
9. **A tooling limitation worth fixing**: `vftable_slots` is keyed by class with no way to say
   *which* of a class's two tables a slot belongs to, which is why `CVariables::SaveContents`
   (`0x77060`) and `CVariables::LoadKey` (`0x77080`) are described inside other entries' comments
   and recorded as neither.
10. **The 963 `remove_brigade` values that match no declared name at all** - counted, not audited,
    mostly `events/SpanishCivilWar.txt`.

### Wave 12, landed 2026-10-04 - four agents, and the fact base turned out to have three halves

**The wave's shape: the two sharpest findings were both already in the repository**, in places the
standing rule did not say to look. Wave 11 asked whether `ally = { ... }` scopes to a *bordering*
country; the answer was `Allies`, sitting in `ghidra/bicelib_findings.json` under the decimal offset
`3976`. That is trap 14 for the fifth time and it is now written into the trap with its own clause.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `findings/FINDINGS-numtriggers.md` | **the units question, mechanically**: a leaf's scale is decided by which of **five** slot-7 bodies its base gives it, not by its own loader, so the answer is a table rather than a reading per trigger. `manpower_percentage` and `revolt_percentage` are **fractions, not percentages** - `= 50` demands fifty times the country's own ceiling. `enemy_ic_ratio` is the only one testing `<=`. `check_variable` **creates** the variable it cannot find, and compares `>=`, so a condition on a never-set variable is true whenever the threshold is `<= 0` | **the plan's own example.** `strength_ratio` **does not exist in this build** - no class, not among the 152 keywords, and the only occurrences anywhere under the mod root are in `WAVE.md` and this file. Also `max_manpower_greater_than` tests **current** manpower: its slot 6 is a linker fold of `CManpowerTrigger`'s body and has never read `+0xBD0` |
| B `findings/FINDINGS-scopetriggers.md` | **`ally = { ... }` scopes to a random *allied* country** - `CCountry +0xF88` is `Allies`, five agreeing witnesses, and `CCountry::GetAllies` (rva `0xE6A20`) is the whole of `lea eax,[ecx+0xF88]; ret`. `Allies` is every bilateral alliance **plus every faction member**, which `alliance_with` does not consult. **Every region name in `map/region.txt` is a trigger keyword**, resolved before the `CContextTrigger` arm. `CEventScope +0x40` is the `CCombatant`, so eight combat conditions are silently false outside a combat | the record's description of `RebuildNeighbours` as filling "two neighbour sets and the two `CCountryList`" - **it fills nine lists**. `CCountry +0xD00` and `+0xD10`, whose comments claimed open questions that two Lua accessors had already answered. And the brief's own route in: the five `GetBlockText` renderers were not needed, because the vftables were cheaper |
| C `findings/FINDINGS-effects.md` | **the whole `CEffect` slot map**, 12 slots, from a record that held none - slot 11 `Execute`, 9 `GetText`, 8 `GetBlockText`, 10 `GetTargetText`, 6 `GetKeywordToken`, and `CEffect` is `0x20` bytes. **`Execute`'s mystery second argument is read by nothing** in all 111 classes (11 of 100 bodies pass it through, two replace it with 0), with a positive control that the same scan sees the scope in 98 of 100. `country_event` **re-tests the target event's own trigger** and fires nothing, silently, if it is false. `add_country_modifier` is **idempotent** and a misspelt name is a silent no-op | **`flags` was recorded at the wrong offset on four structs** - `CGameState`/`CCurrentGameState +0xE8` and `CProvince`/`CMapProvince +0xC4` are the `CPersistent` *second base* of a `CFlags`, `0x24` into it. Three constructors settle it and `CCountry +0x180`, already recorded correctly, is the control. The headers carried the same error and nothing read them, which is why it survived |
| D `findings/FINDINGS-diploaction.md` §11-20 | **slot 7, the step where an agreement happens**, closed with a stated remainder. One shape twenty times: charge the influence **on PROPOSE**, build a `CRelation` subclass on ACCEPT, call its slot 10 to hang it on **both** parties, append to the one global list, move the relation. **`CCountry::ChangeRelation` (rva `0xE65C0`) is `CDiplomacyStatus +0x38`'s missing writer** - relation is symmetric *by construction* and is thousandths on a ±200.000 scale, with `EMBARGO_RELATION_CHANGE = -200.0` hitting the clamp floor exactly. **A guarantee and an embargo take effect when offered and are never answered** | §9's "`0x00A435F0` is the war-goal base" - `CWarGoalBaseAction` slot 7 is `_purecall` and that body is its two derived classes', folded. The class count: **21 tables, 20 distinct bodies**, not twenty-four |

**The numbers.** 2,352 -> **2,462** functions, 2,806 -> **2,863** fields, 2,110 -> **2,220**
signatures, 1,412 -> **1,517** signature entries checked with **none disagreeing**, classes `read`
66 -> **67**. 113 addresses and 58 struct fields landed off 115 submitted. The headless apply
reported **`failed: 0`**, not the documented `failed: 2` - and chasing that down corrected a
"known issue" that was never real. See the note below.

**Four fields were named twice, by two agents each, and all four agreed**: `CCountry +0x10B8
national_unity` and `+0xA8C neutrality` (A from the trigger side, C from the effect side), and
`CDiplomacyStatus +0x14 alliance` and `+0x1C guarantee` (B from the scopes, D from the actions).
That is four independent corroborations rather than four collisions, and it is the first wave where
the overlap was checked mechanically.

**A gap in the tooling, found by agent A reading another agent's fragment by hand.**
`mergeFindings.py --check` compares `struct_fields` against `project.json` but **not against the
other fragments in `incoming/`**, so two agents naming one offset differently is neither refused nor
reported and both records land - which `mergeFindings.py`'s own documentation calls worse than being
dropped. A withdrew three of its own entries that way. There is now a cross-fragment checker in the
session scratchpad; **promoting it to `scripts/` is on the queue and not done.**

**A second tooling gap, from agent C**: `checkSignatures.py --only` can check a signature that is
already in `project.json`, which leaves an agent unable to check its own new entries before
submitting them. C wrote its own and recommends a `--candidates` flag. Also on the queue.

**`failed: 0`, and chasing down why corrected a documented "known issue" that was never real.**
`CLAUDE.md` had excused two failures since wave 7 as Ghidra giving a function a body that runs past
its real end and swallowing the next one: `MT19937Next` (`0xAA2B90`) inside
`CSimpleRandom::GetInteger` (`0xAA2B10`), and `TernarySearchTreeFind` (`0xA7E030`) inside
`GuiTypeTree_Find` (`0xA7DEE0`). This apply reported `failed: 0` with no `!` lines and neither name
in the log. The first guess - that the maintainer had split the bodies themselves - was **wrong,
they had not**, so it was probed: a read-only Ghidra script over a copy, printing exactly what the
apply tests (`getFunctionAt` against `getFunctionContaining`).

**Both predecessors are thunks that tail-jump into the function below them.**
`CSimpleRandom::GetInteger` is the whole of `mov eax, ecx; jmp 0xAA2B90` followed by `int3`;
`GuiTypeTree_Find` is a null check, `xor eax,eax; ret 4` on one arm and `pop ebp; jmp 0xA7E030` on
the other, then `int3`. Ghidra's 7- and 24-byte bodies for them are **correct**. There was never an
over-long body to arbitrate: what Ghidra had done was **merge each thunk with its tail-call target
into one function**, which is ordinary behaviour on a tail call.

**And the byte-level argument the old text rested on was about a different function.** It said
"`0xA7DEE0` ends `ret 0xc` at `0xA7E028`, then five `int3`, then a clean `push ebp` - two functions,
properly padded apart". That `ret 0xc` is real and so is the padding, but `functionStart(0xA7E020)`
answers **`0xA7DF60`**. Two functions were conflated, and the conclusion that the record's names
were right was true for an unrelated reason.

In the current project all four addresses are proper entries, so the names land. **`CLAUDE.md` and
`ghidra/README.md` now say `failed: 0` is the pass mark and any failure is a real one**, with the
bytes and the note that if the pair ever returns, the repair belongs on the **thunk**, not the
target. *The lesson is trap 2's own: a `ret`, a padding run and a clean prologue prove a boundary
between the two functions they sit between, and say nothing about a third one named in the same
sentence.*

### Wave 11, landed 2026-10-03 - four agents, and two premises refuted

**The wave's shape: two of the four briefs were wrong about the thing they were built on, and both
agents said so and answered the better question instead.** That is the second wave running where
the plan's own reasoning needed correcting by the bytes.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `FINDINGS-triggereval.md` | **there is no cache anywhere** in trigger evaluation - no memo, no dirty bit, no tick stamp - so `RunDailyEventPass` re-walks every tree every day, doubled wherever a tooltip is open because slot 11 re-evaluates rather than reading slot 6's answer. `CEventScope` taken from 2 named dwords to 12. The four composites' slot 6 read, and `CContextTrigger` **narrows** a scope by copying it, it does not build one | the plan's "clean boundaries on both sides" (trap 2, three times); `CEventScope`'s recorded **size**, where the struct said `0x38` and its own field comment said `0x48`; slot 10's recorded signature, whose 4th argument is an int **weight** divided among branches, not an `int* total`; and `CNotTrigger` is a **NOR** |
| B `FINDINGS-history.md` | the history is a **reversible do/undo transaction log** keyed on dates, `AddEntry` its only public way in; **~3 MB** for 48,998 entries, with the arithmetic and its assumptions; `g_NullDate` promoted and explained as **year zero** on the engine's own calendar | **the brief's premise.** The history *is* read after load - three ways, one of them **every single day** for every leader of every country. And `CLeaderHistory +0x40 trait_gain` is not a field of a 0x24-byte struct: those four bytes are `CLeader +0xC4`, which **the record already held**, so it carried one field twice under two owners |
| C `FINDINGS-mappoint.md` | **879,780 = 14,190 x (60 + 2), exactly** - one point per building type per province plus two embedded. 0x10 bytes from six independent strides; a **flat** vector with an exact `reserve`, so zero per-element and zero slack overhead; **13.5-13.6 MiB**, half of it vftable and a word nothing reads; built once at database load, freed only in `CEU3Application`'s destructor | the record's "one key, `y`" - **it is two, `x` and `y`** - and with it the plan's hypothesis that `x` was implied by position. Also the brief's "plus small-object allocator overhead": the allocation is **per vector, not per point**, so per-point allocator cost is zero |
| D `FINDINGS-diploaction.md` | the offer lifecycle end to end, Lua `Create` to the entry in a save; `value` is a **bool**, not thousandths; the null action is a **static singleton** whose `IsValid()` is `xor al,al; ret`, used as "am I still empty" | **`type` has three values, not two** - `ACCEPT = 2` is registered eight instructions after the other pair, and 21 of 56 save blocks carry it. And **`CCountry +0xF24` is not `declarewar`**: it is the pending-action list of *any* kind, and `declarewar` is the one of nineteen tokens the compiler emitted a literal for |

**Landed:** 84 addresses and 36 struct fields offered, **80 addresses and 36 fields merged**. Record
**2,292 -> 2,352 functions**, 2,777 -> **2,806 fields**, signatures 2,051 -> **2,110**, labels
563 -> 567, virtual tables 206 -> **207**. Headless apply **`failed: 2`** - the pass mark, both
documented over-long bodies. `checkSignatures.py` **1,412 entries, none disagree** - the zero
baseline wave 10 reached held through all 80 new entries.

**The actionable mod figure of the wave**, from C: one building type costs 16 + 4 = **20 bytes per
province**, present from database load to process exit whether any province has that building or
not. That is 0.27 MiB each, so **BlackICE's 48 extra building types cost 12.99 MiB** over vanilla -
and the same multiplier sits in front of `CProvinceBuilding`'s 1,702,800 instances, which is
14,190 x 2 x 60 exactly. Two independent census figures landing on one multiplier.

**And the methodological one**, from D: **`CDiplomaticAction`'s 22,113 "live" is not an object
count.** The class is abstract - ten of its 22 slots are `_purecall` - and every destructor in the
family writes the *base* vftable into the object as it unwinds, so freed-and-unreused memory still
answers to it. `census.py`'s own docstring warns about exactly this. Any census number for an
abstract base wants that check before it is believed.

**Four new trap cases went into `TRAPS.md`**, including a genuinely new third cause for
`functionStart`: it can stop on a `0xCC` that is **the low byte of a `call rel32` displacement**,
and `retsBefore` does *not* catch it because x86 resynchronises and the decode looks clean. Requiring
a run of three `int3` fixes it.

## Away from the AI: where else there is to go

Surveyed 2026-10-03 at the maintainer's request, after wave 10, by reading `PROGRESS.md`'s own table back
rather than by taste. **Every loader grammar in the image has already been read** - `PROGRESS.md`
says so and it is right - so what is left everywhere is *layout and behaviour*, not grammar.

The arithmetic that frames the choice: of 1,141 classes, **858 have no `read` class anywhere in
their ancestry**, and those hold **2.1 million living objects**. Counting ancestry is the whole
trick, and getting it wrong is how this survey nearly went to the wrong place - see the two dead
ends at the end.

### 1. The evaluation half of the event script language - the strongest candidate

**The grammar is read, the tooltips are read, and the answers are not.**
`findings/FINDINGS-script.md` has all **152 trigger keywords and 91 effect keywords**, one class
each. `CTrigger` slot 9 `GetBlockText` and slot 8 `GetText` - how a condition *draws itself in a
tooltip* - are read in detail, including `CAndTrigger`'s and `CContextTrigger`'s overrides.

But slot **6** is `Evaluate`, `bool __thiscall (CTrigger*, CEventScope*)`, and a grep of the whole
record finds **7 named `Evaluate` bodies in the image**, four of them narrow leaves
(`CPureRevoltRiskTrigger`, `CRevoltRiskTrigger`, `CCombatModifierTrigger`, `CCombatIsConvoyTrigger`,
`CCombatIsWinnerTrigger`). So for ~152 trigger classes **the record knows how a condition displays
itself and not how it answers.** `CEffect` has no vftable slots recorded at all.

> **Re-measured 2026-10-05, and the two sentences above are stale: there are now 64 named
> `Evaluate` bodies, not 7, and `CEffect`'s slot map is fully recorded.** Waves 11, 12 and 13 landed
> after this survey was written and wave 13 alone added six. The area is still the strongest
> candidate away from the AI, but what is left in it is the **spine** - how `CContextTrigger`
> rebinds a scope, and what walking a forest costs - rather than a hundred unread leaves. Wave 14's
> briefs B and C are built on the re-measured picture; `WAVE.md` carries the arithmetic. **This is
> trap 14's open-list clause: a survey is a claim about the record as it stood when it was written,
> and the next wave is what invalidates it.** The three most populous trigger classes
> (`CAndTrigger` 100,464 live, `CNotTrigger` 28,006, `CContextTrigger` 10,974) have named
> `Evaluate` bodies and **no struct records at all**, which is brief A's problem rather than this
> section's.

The live population backs it: `CAndTrigger` **100,464**, `CTechnologyTrigger` 33,204, `CEffect`
28,627, `CNotTrigger` 28,006, `CHasCountryFlagTrigger` 18,966, `CVariableTrigger` 12,815,
`CTrigger` 11,343, `CTagTrigger` 11,196, `CContextTrigger` 10,974 - **over 260,000 live objects**,
nearly all `RTTI`-only.

Why it matters for this mod specifically: BlackICE is an enormous event and decision mod, and these
are the semantics behind every condition in it. Concrete questions with concrete answers:

- **`CContextTrigger` derives from `CAndTrigger`** and has 10,974 instances - it is the scope
  switch (`owner = { ... }`, `controller = { ... }`, a bare country tag). Only **2 of 153** keys
  placed. How it rebinds the scope is the difference between a condition meaning what the modder
  thinks and not.
- **`CVariableTrigger`** - variables are a modding feature and nothing is known about it.
- **Is evaluation cached, and what is the cost of a trigger forest?** Slots 10 and 11 are
  `WalkChildren` and `CountEvaluation`, both recorded with signatures and neither read. If every
  decision re-walks its tree on a schedule, that is a measurable cost in a mod with thousands.
- **What a comparison actually compares.** `strength_ratio`, "controlled", "in combat" - the kind
  of thing that is guessed at in mod forums and is sitting in the bytes.

### 2. The retained-history question - a memory finding waiting to happen

`CLeaderHistory` **24,138** live, `CRankChange` **24,547**, `CTraitGainTracker` **24,137**,
`CCountryDecisionChange` 15,755, `CProvinceHistory` 14,190 - **about 103,000 live objects** of
*history*, and `CRankChange` and `CCountryDecisionChange` are `RTTI` with no field and no function
named.

The question that makes this more than a layout exercise: **does the engine keep every leader's and
province's full history in memory for the whole game, and does anything ever read it after load?**
HoI3 dies of address space, not of leaks (`hoi3-crash-dump-diagnosis`), so a hundred thousand
retained objects nobody reads is worth knowing about. It also lands next to a mechanic the maintainer already
has: the dormant no-leader-skill-loss work, and `CTraitGainTracker` already has 4 fields and 6 named
functions, so it is the cheapest way in.

### 3. `CMapPoint` - 879,780 live, the single biggest population in the game

`CMapPoint::LoadKey` takes **one key, `y`**, so each is a coordinate and there are **879,780 of
them** - more than every other unread class combined, and nothing is recorded but that loader. At a
plausible 8-16 bytes plus small-object allocator overhead this is on the order of ten megabytes of
map geometry, in a process that runs out of address space.

**This is the biggest unanswered memory question in the image** and it is pure plumbing - no mod
semantics, no AI. It extends the measured work in `hoi3-memory-where-it-goes` rather than starting
something new. Best paired with the Memory page, which can count them live.

### 4. Diplomacy's action layer - smaller, self-contained

`CDiplomaticAction` 22,113 live (`placed`, 2 fields, 2 functions) plus `CNullDiplomaticAction`
13,669. `findings/FINDINGS-diplomacy.md` covers the save's diplomacy block and the agreement kinds;
the **action** object - what an offer *is* while it is in flight - is not read. A contained job with
a clear boundary, and the one of these four that could be done in a single pass.

### Two candidates that died on inspection, recorded so nobody re-proposes them

- **`CRegiment` / `CWing` are not unread.** `PROGRESS.md` shows `CRegiment` with **1** field at
  `0xD8` bytes and 27,277 live, which reads like virgin territory - but its base **`CSubUnit` is
  `read` with 28 fields at the same `0xD8`**, and the table's `fields` column is each class's *own*
  named fields by design. The layout is largely known; only the derived slice is not. Same for
  `CWing` (0 own fields, 2,298 live). **Rank on ancestry, not on the `fields` column.**
- **The modifier system is better covered than its `RTTI` marks suggest.** `CStaticModifier` is
  31,318 live with no struct and no named function, which looks like the mod's main lever lying
  untouched - but `CModifier` is `placed` with a header, and **`CModifierValues` already has 143
  fields named at `0x478` bytes**, which is the whole modifier value table. What `CStaticModifier`
  adds over its base is a thin slice. `ActiveModifier`, `CModifierDefinition`, `CModifierEntry` and
  `CMTTHModifier` are all recorded too.

### The live queue - when a game is running

Wave 9 was entirely static and generated a long list of things that one session with a game would
close in minutes. **Worth doing all of these in one sitting rather than briefing an agent per item.**

| what to read | what it settles | from |
| --- | --- | --- |
| `plan_air_stance` across AI air formations, looking for a **2** | whether five air missions are dead for the AI | `FINDINGS-airnaval4.md` |
| `CGuiObject +0x44` with a text field focused | `has_focus`, currently `likely` | `FINDINGS-guistatic.md` |
| `CFixedWindow +0x60` on all 206 windows, and on one being shown and hidden | the window-wide flag every descendant mirrors at `+0x48` | `FINDINGS-guistatic.md` |
| `provinces[10535..10538]` | what the four province ids hard-coded out of convoy raiding are | `FINDINGS-airnaval4.md` |
| `CRegion +0x6D` after a war has run on | whether war sets the byte `ScoreOpsAreaProvinces` adds +100 for | the open list above |
| the debt pools after a war with debts allowed | `repaid_away` / `income_from_debt`, still "not established" | the open list above |
| a hook on `EstimateAttackOdds`'s return for one province | the damage-ratio formula, outright | `FINDINGS-attackodds.md` |
| `state->tick` between `CInGameIdler::Leave` and `CFrontEnd::Enter` | which instruction wrote the 60759360 | `FINDINGS-session2.md` |
| the `+0x2FC` vector's 46 buttons, by type name and who called slot 22 | whether `attached_children_head` is the right name | `FINDINGS-guistatic.md` |
| **AI agent units' `plan_air_stance`, on an AI country** | whether anything clears stance 2 faster than `ProcessAI` restores it - agent D's one remaining open item, and the last thing between "the strategic air war is live" and certainty | `FINDINGS-airstance.md` |
| **`CUnit +0x2DC` across an attack decision onto an opposed amphibious landing** | the **amphibious sign bug**. If real, the estimate *rises* where it should fall. Currently the whole claim rests on one opcode byte (`subsd` where the river arm has `addsd`) | `FINDINGS-aihelpers.md` |
| a **bombing** combat with the slot 11 probe still installed | the one arm of the slot 11 result that rests on static reading alone | the open list above |

### Deferred, at the maintainer's call

- **Finding the outliner leak in the code.** The symptom is quantified and reproducible - every
  open/close of a full-screen window permanently leaks 30 widgets, ten each of `outliner_header`,
  `outliner_header_entry` and `entry_text`, while six sibling outliner names tear down correctly -
  and the difference between those two paths is where the answer is. **Not needed yet**; the new
  widget counter on the Memory page will say whether it matters over a long game before anyone
  spends an agent on it.

### Open, not scheduled

**Two leader-assignment flags the Ctrl-unassign feature passes without knowing what they do.**
Both are small, both are self-contained, and neither blocks anything - the feature has been tested
in single player and in **multiplayer** and works. They are here so that whoever next touches
leader assignment does not have to re-derive them.

1. **`CAssignLeaderCommand +0x8C`**, the fourth argument of its constructor (rva `0x1D7430`).
   The two swap sites in one function at rva `0x33ACAC` and `0x33ADA2` pass **0**; the two
   single-assignment sites at `0x3665A4` and `0x36955C` pass **1**. BiceLib passes 1, matching the
   site that builds the same command it builds - an assign-the-empty-leader - but *why* the swap
   passes 0 is unread. The field is written by the constructor and read somewhere in `Execute`
   (rva `0x1D7570`) or in the command's save path; one scan for readers of `+0x8C` settles it.
   **The cheap guess to test first** is that it is "announce this to the player", since the swap
   is one user action that posts two commands and would otherwise report itself twice.

2. **`CUnit::SetLeader`'s two trailing ints** (rva `0x1BFC10`, `ret 0xc`). Four call sites read,
   three distinct combinations: `(CLeader::null(), 1, 0)` from `CRemoveAllLeadersCommand::Execute`,
   `(leader, 1, 1)` and `(CLeader::null(), 0, 0)` from `CAssignLeaderCommand::Execute`, and
   `(CLeader::null(), 0, 0)` at rva `0x1D7DA7`. So the first is **not** "is there a leader" - the
   remove-all path passes 1 with the empty leader - and the pattern that fits what is read is
   first = "this is the assignment that counts", second = "a leader is arriving rather than
   leaving". **That is a reading of three call sites, not of the body**, which is the thing to do:
   23 callers makes it worth reading properly once.

**The one reversing dependency left in the BiceCommand framework: a persistent reference both
ways.** Added 2026-10-05. The framework (`BiceLib/Commands/CBiceCommands.hpp`) carries `int32`
arguments, which is already enough for ids, enums and flags - but a command that names a *unit*, a
*leader* or a *province* has to carry it the way `CAssignLeaderCommand` does, as a `CPersistent`
**id pair**, because that is what makes it mean the same object on every peer. A pair is two
`int32`s, so the payload format already holds one; what is missing is the conversion.

3. **`0x42DD70`** turns an object pointer into the pair, and **`FindPersistentById`
   (`0x69DA00`)** resolves it back, choosing the registry `[0x1A857F0]` or `[0x1A857F4]` on
   whether the id exceeds `0x1268` - all three read already, from
   `CAssignLeaderCommand::Execute` (rva `0x1D7570`), which does exactly this for both of its
   ends. What is **not** read is `0x42DD70`'s own signature and convention, or whether it is
   general or unit-specific. One function, and it unblocks every command that names a game
   object rather than a number. Worth a small helper on the framework once it is read, because
   every such command will want the same two calls.

---


**The one that would change a published claim.** Everything else here is an addition; this is a
subtraction, and it is what is left of the slot 11 question after the live run closed the main part
of it.

1. **`CCombat` slot 17's receivers outside the combat module** - `findings/FINDINGS-combat3.md`'s own open
   item 1, and it is **not** closed. `findings/FINDINGS-slot11.md` §7 says why the method that closed slot
   11 cannot close this one: the filters cut slot 11 from 1,033 call sites to 14, but slot 17 only
   from 1,871 to 573, because the discriminating power came from the receiver's production site and
   a `CCombat` pointer is reachable from too many places. A different method is needed, not more of
   the same sweep.
2. **The bombing arm of the slot 11 result rests on the static reading alone.** No bombing combat
   ran in the session that produced 39,414 hooked calls, so for naval, air and land the demotion in
   `findings/FINDINGS-combatmods.md` is backed live and for bombing it is not. One bombing combat would
   settle it, and the probe hook still exists for exactly that.
3. **Whether `CCountry +0x824` `repaid_away` and `+0x848` `income_from_debt` are ever written.**
   Non-zero in **0 of 108** live countries at a scenario start, with `home_produced` and `usage`
   populated in 106 of them and four sibling trade pools populated too, through the identical read
   path - so the zero is the field's and not the reader's. **That is not the same as inert**, and an
   earlier version of this entry overclaimed it as such. the maintainer's own recall of the *allow debts
   during war* trading mechanic is what corrected it, and it is corroborated in the image:
   `CDebtAction` exists and has **zero live instances**, which is exactly what predicts these zeros
   at peace. So the honest status is "not established", and what would settle it is a game run on
   through a war with debts allowed - not more reading. The savegame is the cheap oracle: neither
   key should appear while it holds.
4. **What `CRegion +0x6D` means.** Now a question about one named 0.1 KB class rather than an
   unknown one: `CMapProvince +0x358` is a `vector<CRegion*>`, `classNameForVftable` answers
   `CRegion` on 8 of 8 provinces tried, and `hoi3.instances` finds 400+ at a **uniform 0x78
   stride**, which is the trap-15 check for real objects rather than a table of vftable pointers.
   The byte reads **0 on all 400 regions** at a scenario start, so `ScoreOpsAreaProvinces`'s
   "+100 per region whose `+0x6D` is set" never fires there. Whether that is because the AI is not
   running yet or because war sets the byte is the remaining question, and running the game on
   answers it.
5. **The game's own name for `GuiTooltipText`.** No vftable, so RTTI cannot name it; 114 callers of
   its destructor and 86 producers, but no consumer was found, and a consumer is what would name
   it. The struct is in the record under our name, flagged as ours.
6. **The five diplomatic actions** whose slot 17 neither pushes a literal nor calls the bridge -
   `CCallAllyAction` (`0xA2AC80`), `CEmbargoAction` (`0xA438F0`), `CLicenceTechnologyAction`
   (`0xA3D3F0`), `CRequestLendLeaseAction` (`0xA0FE20`), `CTradeAction` (`0xA38B00`) - against the
   five Lua wrappers around `0xA444xx`-`0xA44Cxx` that do, each with one caller. `FINDINGS-
   convoys.md` got one step further on the last of them without closing it: `CEU3AI` has two
   registered methods taking a `CTradeRoute&` and returning `bool` (mangled names at `0x15F02C8`
   and `0x15F02E8`), which is the right shape for the untraced route - the AI handed a route and
   asked yes or no - but the wrapper was not followed to its caller.
7. **`0x4FA0B0`** recomputes all seven alignment terms and would confirm every formula in
   `findings/FINDINGS-politics.md` cheaply.
8. **The force-needs half's remaining 2 KB** (`findings/FINDINGS-forceneeds.md`).
9. **`0x4AF580`** (`CTheatre::AddFront` as proposed), read only to its first ~60 instructions.
10. **Two front headings in the maintainer's savegame that do not fit the 0.125 lattice**
    (`findings/FINDINGS-weatherfront.md`). Both are facts in the file and neither is accounted for.

### Two decisions that are the maintainer's, not findable by reading

- **`CTradeRoute +0x34` and `+0x44`.** Six independent readings, including the engine's own
  `GetTradedFromOf`, say the record has the two the wrong way round. Both are still marked
  `inferred`, not `proven`, and swapping a published field on six readings without a live
  confirmation is the kind of change that should be asked for rather than made.
- **Whether the slot 11 probe hook comes out.** Its own header says it should be deleted now that
  it has answered. The one reason to keep it is item 2 above - a bombing combat.

### Wording to fix while passing

- `findings/FINDINGS-techdecay.md` calls `slack` spare capacity. It is the **sum of two slider positions**,
  which is what is *requested*, so the word is actively misleading there.

## What has already been read

67 findings files, which is where the evidence for anything in `project.json` or a `GameClasses`
header lives. This replaces the `Done` archive: the archive restated each file's headline and named
only 40 of the 67, so it was both longer and less useful than a complete list.

**The engine's own flow**

| | |
| --- | --- |
| `findings/FINDINGS-tick.md` | the tick: the clock, the command it posts, the five periodic passes and the TBB fan-out |
| `findings/FINDINGS-schedule.md` | when each unit-level update runs, and on which thread |
| `findings/FINDINGS-commands.md` | the command queue, the four channel classes, and the one `Execute` caller |
| `findings/FINDINGS-session.md` | the session lifecycle: what `in_game` means, and what creates and destroys a game |
| `findings/FINDINGS-sigaudit.md` | the signature audit: 87 disagreements down to 1, and the string size |
| `findings/FINDINGS-session2.md` | the startup reset's second half, and what `CInGameIdler +0x1790` really is |
| `findings/FINDINGS-resetpath.md` | the deferred session-exit path, and whether `Update` can reach the reset with `in_game` set |
| `findings/FINDINGS-startup.md` | how the engine boots, stage by stage, and which loader claims each `common/` file |
| `findings/FINDINGS-mappoint.md` | 879,780 map points: 14,190 x 62 exactly, and the 13 MiB they cost |
| `findings/FINDINGS-mapbuild.md` | the map build, its cache, and how the frontend is reached |
| `findings/FINDINGS-allocator.md` | the allocator, and what a call site gives away |
| `findings/FINDINGS-save.md` | how the game writes a save |
| `findings/FINDINGS-autosave.md` | how the game decides to autosave |

**The AI**

| | |
| --- | --- |
| `findings/FINDINGS-ai.md` | the AI: slot 9/slot 10, the per-country hour stagger, the five minister ticks |
| `findings/FINDINGS-aisched.md` | how often the AI runs - hourly, by latch handshake - and what a year change does |
| `findings/FINDINGS-aiunit.md` | `CAIUnit`: 90 slots, theatres, fronts and battle plans |
| `findings/FINDINGS-aiplans.md` | how the AI decides where its armies go, and the fair-share ops area |
| `findings/FINDINGS-aitheatre.md` | the AI's theatre layer, and `CAIInvasion` |
| `findings/FINDINGS-theatre2.md` | the six theatre sites, and `CAIInvasion`'s stage machine |
| `findings/FINDINGS-setarea.md` | how an ops area is drawn, and how it reaches subordinates |
| `findings/FINDINGS-subdivide.md` | slot 83: how an area is sliced, and the proof nobody ever asks for it |
| `findings/FINDINGS-opsarea.md` | what scores an operations area, and what finds the way out of it |
| `findings/FINDINGS-reorganise.md` | the two bodies behind slot 73's air and naval halves |
| `findings/FINDINGS-aihelpers.md` | the AI's own combat modifier model, and how far it agrees with the battle's |
| `findings/FINDINGS-attackodds.md` | the AI's land attack odds: `ourDamage / theirDamage`, read end to end |
| `findings/FINDINGS-airstance.md` | who sets air stance 2, and who fills the air target lists |
| `findings/FINDINGS-airnaval4.md` | air phase 4's mission assignment, and the naval convoy raid and rebase |
| `findings/FINDINGS-aiconsumer.md` | slot 73's land half: who spends the ops-area and front scores |
| `findings/FINDINGS-power.md` | what the AI thinks it can win: strength x org x a per-brigade stat sum |
| `findings/FINDINGS-forceneeds.md` | what the AI thinks it needs built, and that an AI country asks only for aircraft |
| `findings/FINDINGS-invasion.md` | where the AI comes ashore: `PickInvasionLandingProvince` end to end |
| `findings/FINDINGS-aifields.md` | six fields the AI reads that nothing named, including `CMapProvince +0x5C` |
| `findings/FINDINGS-trade2.md` | the AI's trade predicates, the two gates, and who counts as a neighbour |
| `findings/FINDINGS-negatives.md` | four load-bearing negatives, and what a positive control did to each |
| `findings/FINDINGS-survivors.md` | the three leads that kept surviving |

**Combat, units and supply**

| | |
| --- | --- |
| `findings/FINDINGS-combat.md` | combat: the standing account, and the five things later files corrected in it |
| `findings/FINDINGS-combatmods.md` | combat modifiers: the whole census, two adders, 69 sites, 30 ids |
| `findings/FINDINGS-combat3.md` | the leftovers: land surprise as a half-removed feature, `BM_ARMOR_ADVANTAGE` |
| `findings/FINDINGS-slot11.md` | does anything outside `CCombat` slot 17 call `CCombatant` slot 11? - settled live, no |
| `findings/FINDINGS-navaldetection.md` | naval detection, positioning and fleet disengagement |
| `findings/FINDINGS-airnaval.md` | air and naval missions, and that a naval row's `+0x84` counts ships |
| `findings/FINDINGS-unitdef.md` | what a division's stats are made of - sum, cap, mean |
| `findings/FINDINGS-leaders.md` | leaders: experience, skill, traits, and that promotion skill loss does not exist |
| `findings/FINDINGS-supply.md` | how supply reaches a unit |
| `findings/FINDINGS-manpower.md` | manpower: what the drain is made of |
| `findings/FINDINGS-redeploy.md` | strategic redeployment and the route finder |
| `findings/FINDINGS-shatter.md` | shattering, and being removed from the game |

**The country: economy, politics, diplomacy**

| | |
| --- | --- |
| `findings/FINDINGS-ic.md` | how a country's IC is worked out |
| `findings/FINDINGS-production.md` | the build queue, and how IC and leadership are split |
| `findings/FINDINGS-politics.md` | alignment, the seven drift terms, and the country's daily pass |
| `findings/FINDINGS-research.md` | research speed, the practical bonus, and tech decay |
| `findings/FINDINGS-techdecay.md` | where practical and theory decay is actually applied |
| `findings/FINDINGS-occupation.md` | occupation, revolt risk, partisans and rebels |
| `findings/FINDINGS-revolt.md` | what consumes revolt risk: the roll, the rebel type, the underground |
| `findings/FINDINGS-convoys.md` | convoys and trade, and that the AI drives a route through the mod's Lua |
| `findings/FINDINGS-espionage.md` | spies, intelligence, and what the espionage sliders buy |
| `findings/FINDINGS-events.md` | events, and why a loaded save fires none until the month turns |
| `findings/FINDINGS-diploaction.md` | a diplomatic offer in flight: three stages, the lifecycle, the null singleton |
| `findings/FINDINGS-diplomacy.md` | how the engine asks the mod's Lua whether the AI accepts |
| `findings/FINDINGS-oob.md` | the order of battle, key by key |

**Weather and the map**

| | |
| --- | --- |
| `findings/FINDINGS-weather.md` | weather, and what it actually does to combat and movement |
| `findings/FINDINGS-weatherfront.md` | `CWeatherFront`: the source of every weather number |
| `findings/FINDINGS-temperature.md` | temperature, and the one missing `abs()` that gives the south no winter |
| `findings/FINDINGS-mapmode.md` | the VP map mode, and where to take it over |
| `findings/FINDINGS-camera.md` | the map camera, and what moves it |

**The interface, and text**

| | |
| --- | --- |
| `findings/FINDINGS-gui.md` | the GUI framework: finding a thing by name, and what the combat-status window is |
| `findings/FINDINGS-guilive.md` | the live GUI: from a window name to the object holding the number |
| `findings/FINDINGS-history.md` | the history subsystem: a do/undo replay log, read every day, and what it costs |
| `findings/FINDINGS-guicontainers.md` | the subwindow map, and every `CWindowType::LoadKey` token's container |
| `findings/FINDINGS-guistatic.md` | the GUI read statically: the child lists, the empty registries, the ledger's class |
| `findings/FINDINGS-uinumbers.md` | what the interface already computes |
| `findings/FINDINGS-uinumbers2.md` | what the interface already computes, part two |
| `findings/FINDINGS-messages.md` | the message system |
| `findings/FINDINGS-effecttext.md` | how an event option's effect text is built |
| `findings/FINDINGS-text.md` | how the game measures text |

**The loaders, now a closed frontier**

| | |
| --- | --- |
| `findings/FINDINGS-definitions.md` | every loader's grammar, key by key |
| `findings/FINDINGS-triggereval.md` | how a condition **answers**: slot 6, `CEventScope`, and the absence of any cache |
| `findings/FINDINGS-script.md` | the event script language: 152 trigger keywords and 91 effect keywords |
| `findings/FINDINGS-fieldmap.md` | which field each key lands in |

## A method worth reusing

**`definesMap.py` backwards.** Scan for `call GetDefines (0x445D90)` followed within a few
instructions by `[reg + <block>]`, then read which `+<field>` comes next. A define is read from only
one or two places in the image, so this turns a name in `defines.lua` straight into a function
address with no guessing. Four of the politics candidates came from it, and **it has not been
pointed at the economy or combat defines yet**, which is the live part of this note.

**A negative result from it is not evidence** - three different things hide a define, and all three
are written up as trap 8 in `TRAPS.md` with the check for each. That text used to be duplicated
here; it is not any more.
