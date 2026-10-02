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

**Wave 9 is planned below, four agents.** David's priority order still holds: the interface layer,
then the last unread AI blocks, then core engine flow, then the rest. What is not scheduled is
further down.

### Wave 9, planned - four agents

**A. `0x8D93B0`, the AI land-attack-odds estimator.** rva `0x4D93B0`, 2,682 bytes, recursive, and
**unread**. This is the single most load-bearing unread function in the record: it is the only
non-display reader of the land defence product `CUnit +0xF0`, and therefore the only reason the
land half of `findings/FINDINGS-combatmods.md`'s census survived the demotion. That claim is `likely`
*solely* because this body has not been read. Reading it either promotes a published claim to
`confirmed` or demolishes it, which is the best value-per-byte on the list.

Two specific questions it must answer. Is `esi` really a `CUnit`? The identification rests on the
`+0xF0`/`+0xF8` pair being distinctive (trap 12's neighbour fallback) and not on
`fieldchain.py --holder`, which **works now** - that bug was fixed on 2026-10-01, whatever a
leftover note in `findings/FINDINGS-slot11.md` says. And **are the products ever non-neutral when this
runs?** `CCombatant::ApplyCombatModifiers` resets them to 1000 every tick, so if this function only
ever sees 1000 the reader is real but the value is not. Its output is compared against
`LandAttackOddsThresholdForStance` and the 3.0 / 1.5 / 1.1 attack bars and the 0.8 abort bar in
`CAIUnit_ManageLandUnits`, so what it returns decides whether the AI attacks and whether it breaks
off.

**B. The two biggest unread AI bodies.** The air body's **phase 4**, `0x8CEE76`-`0x8D04E6`, 5.7 KB -
where `ground_attack`, `air_intercept`, `logistical_strike`, `strategic_bomb`/`nuke_mission` and
`naval_strike`/`port_strike` are actually assigned - and the naval body's **convoy/rebase block** at
`0x4D2418`, 3.6 KB, which holds the **only `MT19937Next` call in either body**, so a randomised AI
decision worth knowing precisely.

Carry in two live results that bear on it. `plan_air_stance` reads **1** on 1,125 of 1,126 live
`CAir` formations, so of phase 4's three arms the one that runs is the plain one with full
thresholds - 0 (off) and 2 (halved) were not observed. And the four list heads phase 2 scores from
are **populated** (93 of 102 agents), so phase 2 is not dead code - **but every one of those agents'
units is a `CArmy`, not a `CAir`**, which puts the `air_target_provinces_*` names in doubt. Settle
whether they are air-specific or generic target lists.

**C. Finish the live GUI layer.** Four items from `findings/FINDINGS-guilive.md`, now much cheaper than when
they were written because the access route is known and verified: `CInGameIdler +0x1790` ->
`CEU3Application` -> `+0x120` -> the one `CEU3Gui`, three reads, with no global anywhere in the
image (a scan of all 16 MB for the live pointer found zero).

- **Nine of the twelve live widget classes cannot be named** - the RTTI export has no entry for
  them, so they need naming from their vftables and behaviour, the way `CBillboardObject` was.
- **`CFixedWindow +0x4C` is a linked list of something**, walked by slot 36 (`0xAC1220`).
- **Registries 1 (`+0x348`) and 5 (`+0x3D8`) are empty on all 206 windows**, so what they hold is
  unknown. A live game with panels open is the way in.
- **The ledger window's class** (`findings/FINDINGS-uinumbers2.md`): `0x3C1ED0` is in no vftable.

**D. The session lifecycle's remaining gaps.** `findings/FINDINGS-session.md` named these and deliberately
left them.

- **`0x23A460`** - five callers across the lobby, `CTutorialScreen` and `CInGameIdler`; writes
  `loaded_from_save`; calls the full reset. The file calls it "probably the real start-a-game entry
  point" and declines to name it. Its extent is unsettled (two `ret`s, so trap 2 or trap 3).
- **`0x27B240`'s 2,217 bytes**, read only as far as the reset block at `0x67B581`.
- **The `session_manager` naming conflict.** `CInGameIdler +0x1790` is recorded as `session_manager`,
  from a reading of its one writer - but the live object there resolves by RTTI to a
  **`CEU3Application`**. One of those is wrong, or they are the same thing under two names. The
  conflict is written on the field and deliberately not resolved by renaming on one observation.

### Deferred, at David's call

- **Finding the outliner leak in the code.** The symptom is quantified and reproducible - every
  open/close of a full-screen window permanently leaks 30 widgets, ten each of `outliner_header`,
  `outliner_header_entry` and `entry_text`, while six sibling outliner names tear down correctly -
  and the difference between those two paths is where the answer is. **Not needed yet**; the new
  widget counter on the Memory page will say whether it matters over a long game before anyone
  spends an agent on it.

### Open, not scheduled

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
   earlier version of this entry overclaimed it as such. David's own recall of the *allow debts
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
10. **Two front headings in David's savegame that do not fit the 0.125 lattice**
    (`findings/FINDINGS-weatherfront.md`). Both are facts in the file and neither is accounted for.

### Two decisions that are David's, not findable by reading

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
| `findings/FINDINGS-resetpath.md` | the deferred session-exit path, and whether `Update` can reach the reset with `in_game` set |
| `findings/FINDINGS-startup.md` | how the engine boots, stage by stage, and which loader claims each `common/` file |
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
| `findings/FINDINGS-uinumbers.md` | what the interface already computes |
| `findings/FINDINGS-uinumbers2.md` | what the interface already computes, part two |
| `findings/FINDINGS-messages.md` | the message system |
| `findings/FINDINGS-effecttext.md` | how an event option's effect text is built |
| `findings/FINDINGS-text.md` | how the game measures text |

**The loaders, now a closed frontier**

| | |
| --- | --- |
| `findings/FINDINGS-definitions.md` | every loader's grammar, key by key |
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
