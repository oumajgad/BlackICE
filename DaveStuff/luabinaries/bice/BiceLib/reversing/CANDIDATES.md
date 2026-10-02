# What to read next, and why

A work queue. `PROGRESS.md` is the scoreboard and is generated; this is hand-written and says
what is *worth* reading, with enough of an anchor that nobody has to find it twice.

Collected by parallel surveys of the domains the record had barely touched - six on
2026-09-30, six more on 2026-10-01. **Every address below was checked against the executable** -
a vftable slot read, a call site decoded, a string reference confirmed - not taken from a class
name that sounded right. Addresses are virtual (based `0x400000`) with the rva beside them.

**The grammar frontier is closed.** All 266 `LoadKey` switches have been read
(`FINDINGS-definitions.md`, `FINDINGS-script.md`), and `fieldmap.py` has the offset most keys
store to. So a loader is never the prize any more. What is missing everywhere is **runtime
behaviour** and **what a field means**.

## Done

- ~~**The tick.**~~ `FINDINGS-tick.md`, 2026-09-30. The clock, the command it posts, the five
  periodic passes and their gates, the TBB fan-out (all five functors named from RTTI), and the
  generator. It also settled two things that were written down wrongly and answered the open
  question in `FINDINGS-autosave.md` about what calls `CInGameIdler` slot 53.
- ~~**The `DiploScore` bridge.**~~ `FINDINGS-diplomacy.md`. Slot 17 is `GetAIAcceptance` (the
  game's own name, from luabind); nine of the nineteen concrete actions ask the mod's Lua
  through `GetDiploScoreFromLua` (`0x60DC70`), **five point the slot at a hard-zero stub**, and
  five reach Lua by a route not yet traced. `CCountry +0x1D8` is the country's `CEU3AI`.
- ~~**Why a loaded save fires no events until the month turns.**~~ `FINDINGS-events.md`. The
  daily pass walks `CCountry +0x8`, a candidate list written **only** by `RunMonthlyPass`; a
  load never fills it. Also `GetChance` = `1 - 0.5^(1/days)`, so `mean_time_to_happen` is a
  **median**.
- ~~**The daily IC total.**~~ `FINDINGS-ic.md`. `CCountry::UpdateIC` (`0xF0CC0`), the fields it
  writes, and the verdict that `Patches::fixOffMapIC` is unreachable dead code.
- ~~**Research speed, the practical bonus, decay.**~~ `FINDINGS-research.md`. The year fields
  are difficulty, not gates; the bonus cap and efficiency floor are compiled-in floats.
- ~~**The AI.**~~ `FINDINGS-ai.md`. Slot 9/slot 10, the per-country hour stagger, and that the
  five minister ticks **are** the mod's `*Minister_Tick` Lua functions.
- ~~**The build queue and the IC/leadership split.**~~ `FINDINGS-production.md`. The split is
  queue order; `+0x608` is IC that costs no resources; no gearing term exists in `Distribute`.
- ~~**The daily country pass and alignment.**~~ `FINDINGS-politics.md`. Seven drift terms, the
  faction-invite gate, and that `CCountry +0x628` is the **laws**, not ministers.
- ~~**Where practical and theory decay is applied.**~~ `FINDINGS-techdecay.md`, 2026-09-30.
  `CCountry::UpdateMonthly` (`0x4DC840`), one caller in `RunMonthlyPass`: 2%/month at zero
  slack. **`BASE_TECH_DECAY` has two readers, not one** - the survey missed this one because
  `GetDefines` is *inlined* there. The monthly rule ignores the three custom-game decay
  settings entirely and has no floor.
- ~~**How often the AI really runs.**~~ `FINDINGS-aisched.md`. **Hourly**, through a latch
  handshake between `RunHourlyPass` and `CInGameIdler::Update` rather than a tick stage. The
  supposed contradiction was two misreadings: `0x28E350` is a **sixth** functor
  (`ProcessCountriesPreDailyUpdate`), and the "second set of `parallel_for` sites" was each
  `start_for` writing its own vftable into its own child. `RunYearlyPass` does one thing:
  appends a nation-size statistics sample per country.
- ~~**The command post choke point.**~~ `FINDINGS-commands.md`. The session, the four channel
  classes and the mode that picks them; `Execute` is called only from `Session::PumpCommands`
  (`0x689940`); `+0x34` means "may originate commands", not "a channel exists". The hourly
  tick command's random-state snapshot **is** in the wire form.
- ~~**Air and naval mission resolution.**~~ `FINDINGS-airnaval.md`. What starts an intercept,
  the `DEFENSIVE_*` limits that gate every wing, the four-hour air combat, and - the result
  with teeth - **a naval row's `+0x84` is a ship count, not strength.**
- ~~**Occupation, partisans and resistance.**~~ `FINDINGS-occupation.md`. Revolt risk end to
  end, including that its plus/minus 0.1 step and 0.2 suppression cap are **compiled-in globals
  no `defines.lua` entry can reach**; suppression is summed over adjacent provinces too; and
  there is no hardcoded occupation penalty at all.
- ~~**The daily roll that turns revolt risk into a revolt.**~~ `FINDINGS-revolt.md`,
  2026-09-30. `0x4C07C0`, one caller in `CCountry`'s daily pass. Two gates:
  `Random() % 10000 < round(risk/50)`, and then **`Random() % 365 == 0`**. The second divides
  everything by 365, so `P(revolt per province per year) = risk points / 500`, halved for an AI
  country - about 9%/province/year at BlackICE's worst occupation policy. **`spawn_chance` is
  not dead**; it is the rebel *type* selector. One byte at `0x4C0B03` is the whole lever.
- ~~**The cadence and thread of `CUnit` slot 31**, and `CCurrentGameState +0xD9D`.~~
  `FINDINGS-schedule.md`, 2026-09-30. Slot 31 is **tick thread, hourly, per unit**, so
  `COrder` slot 14 is hookable under the ordinary rules. **`+0xD9D` is the tutorial flag** -
  nothing but a tutorial button sets it and a fresh game state has it zero, so it is *not* a
  candidate cause of "the AI stopped playing", and the `FINDINGS-aisched.md` caveat drops from
  "could falsify hourly in some game mode" to "reachable only in a tutorial". `0x28DB20` is a
  TBB `concurrent_queue::try_pop`, which is the mechanism that keeps a worker from ever freeing
  a unit.
- ~~**`ShouldStartNavalCombat` (`0x431840`), detection and positioning.**~~
  `FINDINGS-navaldetection.md`, 2026-09-30. Read end to end: six no-gates, six yes-gates, the
  four scale factors, the positioning number from the roll that creates it to the cap it creeps
  towards, and the disengage chance. The dominant term in disengaging is the constant 10000 -
  and the one thing that moves it is **`CMapProvince +0x2C`, the night flag**, which makes a
  battle about eleven times likelier to break off at night.
- ~~**`CSpyPresence` and the espionage sliders.**~~ `FINDINGS-espionage.md`, 2026-09-30. The
  record field by field, the nine missions and which function resolves each, detection and
  `spiescaught`, and the leadership slider. Also settled the RNG sign worry the naval survey
  raised: the tempering shifts are arithmetic, so no draw is negative and the image-wide
  `Random() % N` idiom is sound.
- ~~**`CAIUnit` - 90 slots, theatres, fronts and battle plans.**~~ `FINDINGS-aiunit.md`,
  2026-09-30. Two premises were false: there are **no `CAIUnit` subclasses**, and there is no
  class hierarchy of theatres and fronts. **The AI never asks the mod's Lua anything** (three
  independent checks) and every decision leaves through the command queue.
- ~~**Weather's effect on combat and movement.**~~ `FINDINGS-weather.md`, 2026-09-30.
  `BM_WEATHER` in four places rather than one, the movement term, the air-mission gate, and all
  56 defines - whose readers a `GetDefines` scan cannot find at all, because
  `CWeatherManager::InitialiseWeatherState` caches the whole block into individual globals at
  startup. That is a **third** way a define hides, after inlining.
- ~~**`CWeatherFront`, and where every weather number comes from.**~~
  `FINDINGS-weatherfront.md`, 2026-10-01. A front is a travelling parcel of humidity and low
  pressure; nothing writes rain or cloud directly, `CWeather::Update` manufactures cloud from
  the humidity-to-temperature ratio and rain from the cloud. The rain formula was checked
  against a savegame, 2092 provinces of 2092. It also corrected the windspeed decay the record
  had carried as 0.980 - it is **0.750**, and 0.980 is a different global.
- ~~**What pushes onto the combat-modifier list.**~~ `FINDINGS-combatmods.md`, 2026-10-01. The
  whole census: **two** adders, 69 call sites, 30 ids. `CUnit::AddCombatModifier` puts land
  modifiers on the division; `CSubUnit::AddCombatModifier` (48 sites, and the one the record
  had missed) puts naval, air and both sides of a bombing on the individual ship or wing. Only
  `BM_SURPRISE_PENALTY` is dead. Five corrections to `FINDINGS-combat.md` came out of it.
- ~~**How the AI decides where its armies go.**~~ `FINDINGS-aiplans.md`, 2026-10-01. The AI
  does not invent a front: it scores the fronts the theatre layer already draws against the
  unit's own objectives by map distance, and claims its **fair share by division count** -
  `round(myDivisions x frontLength / unitsOnThatFront)` provinces - as the plan's ops area.
  Objective priority is `victory_points x 20` plus two additive terms, and **nothing in the AI
  was found that branches on it**.
- ~~**The AI's theatre layer, and `CAIInvasion`.**~~ `FINDINGS-aitheatre.md`, 2026-10-01. The
  two anonymous per-country theatre holders are named and neither is a new class: `+0x48C` is
  the country's `CAIStrategy` and `+0x570` is the order of battle's own list. A `CTheatre` is
  made three ways and loaded a fourth, and **`CAIUnit` slot 85 creates one through the same
  command the player's button posts**.
- ~~**Convoys and trade.**~~ `FINDINGS-convoys.md`, 2026-10-01. What a convoy carries and the
  six things that cap it, efficiency, what a lost convoy costs, the raid end to end, and trade
  routes - including that the AI drives a route through the mod's Lua.
- ~~**What a division's stats are made of.**~~ `FINDINGS-unitdef.md`, 2026-10-01. `CUnit +0xC8`
  is a `CSubUnitDefinition` the division **owns**, rebuilt from its brigades by
  `CUnit::RebuildDefinition` under three rules - sum, cap, mean. The aggregation looks naive
  and is not: every field whose summed form would be nonsense is fixed before a reader sees it.
- ~~**`0x49F3E0`, the province's own monthly work.**~~ Read as part of `FINDINGS-revolt.md` §3.

- ~~**Leaders - experience, skill, traits, promotion.**~~ `FINDINGS-leaders.md`. **Promotion
  skill loss does not exist in this build**, proved from the whole body of
  `CPromoteLeaderCommand::Execute` plus a sweep of every writer of `CLeader +0x70`. Combat is
  the only source of experience; `max_skill` is a speed multiplier, not a cap; and
  `CLeader::PostLoad` recomputes skill upward on load, so the save's `skill` is a floor.

- ~~**`CAIUnit::SetArea` and the five `ReplanSubtree` callees.**~~ `FINDINGS-setarea.md`,
  2026-10-01. The second, theatre-driven way an agent gets an ops area, and - the part nobody
  had - **slot 83 is how an area reaches subordinates**: the parent slices it by division weight
  and writes straight into each child agent's `+0x90`. **Nothing dispatches slot 83**, with slot
  82 as a positive control, so either it is dead or it is entered by a route the scan cannot see.
- ~~**The power estimator, slot 78's ladder, slot 79.**~~ `FINDINGS-power.md`, 2026-10-01. Power is
  **strength x organisation x a per-brigade stat sum**, +8% per fort level and nothing else - no
  terrain, leader, supply, air or naval support. The ladder is inverted from its name: the
  "commitment factor" is a **minimum strength**, so a winning AI demands 70% and a losing one
  accepts 20%. All seven `.data` floats are compiled-in literals.
- ~~**The six `new CTheatre` sites, and `CAIInvasion`'s stages.**~~ `FINDINGS-theatre2.md`,
  2026-10-01. One front rule, **four hardcoded province seats** - Paris and Warszawa for Germany,
  San Fransisco and Washington D.C. for the USA - and a fallback. And `CAIInvasion +0x84`/`+0x88`
  were **the wrong way round** in the record: `+0x84` is the enemy objective, `+0x88` the friendly
  port of embarkation.
- ~~**`CWeather::BaseTemperature`'s latitude model.**~~ `FINDINGS-temperature.md`, 2026-10-01.
  `map/climate.bmp`'s **palette index** is the whole geography of temperature, at
  `(index - 100) x 0.150 C` per province pixel. The southern hemisphere has **no winter at all**,
  from one clamp at `0x96412` where `abs()` was meant. And the season is recomputed **daily**, not
  frozen for a session - which makes `low_pressure_zones`' climate mask a seasonal gate.
- ~~**The three load-bearing negatives and the suspected ops-area bug.**~~
  `FINDINGS-negatives.md`, 2026-10-01. All four settled, three of them against the record. It also
  found **trap 2 sitting inside trap 3's own worked example**.
- ~~**The three leads that kept surviving.**~~ `FINDINGS-survivors.md`, 2026-10-01. Four of the
  five diplomatic actions do reach Lua, through name-specialised clones; `CEmbargoAction` returns a
  constant **100**; and `0x1A8562F` is the **`yesmen` cheat**, which inverts what
  `FINDINGS-diplomacy.md` told modders about their own scripts.

### Wave 6, 2026-10-01

- ~~**Where the AI comes ashore.**~~ `FINDINGS-invasion.md`. `0x893E70` read end to end. A naval
  base of level **1** is a hard requirement, so the AI lands in a **port and never on a beach**;
  all-strait contact is worth +10000, which effectively forbids such a landing; and **the AI will
  never invade a province whose connected sea zone is in `black_sea_region` or
  `baltic_sea_region`** of `map/region.txt`, two hardcoded name lookups. `COASTAL_FORT_LEVEL` is
  the strongest lever because it is the only term that **scales** another. One piece no mod can
  reach: when the target area holds **Germany's acting capital** and the **Soviet Union** is weak,
  every candidate there gets a free doubling, and a **French-owned** province a further 25%.
  It also replaced `0x4A56B0`'s proposed name - it is "has a hostile land neighbour", the opposite
  of "isolated".
- ~~**`CAIUnit` slot 83, and whether anything enters it.**~~ `FINDINGS-subdivide.md`. **Dead in
  this build**, proved five ways with controls, the decisive one structural: the only references
  anywhere in the image to any of the 90 addresses in `CAIUnit`'s vftable are the **two writes of
  its base**, in the constructor and destructor. The one call site with slot 83's convention
  dispatches on the `CInGameIdler`, whose slot 83 is the folded `ReturnFalse`. So **no subordinate
  agent ever receives an ops area by that route.** The body it guards is complete - largest-
  remainder apportionment by division count, then a greedy contiguous fill scored by mean distance
  from the child's own brigades - and contains a reachable null dereference at `0x8C1089`.
- ~~**What the AI thinks it needs built.**~~ `FINDINGS-forceneeds.md`. The fourteen `CCountry`
  offsets are **not** per-type lists: every one is the `fuel` member of a different `CGoodsPool`,
  and the two sums are `GetDailyIncome(FUEL)` and `GetDailyExpense(FUEL)` inlined - whose whole
  effect is to **halve the armour and mechanised want** when a country is at war with a negative
  fuel balance. And **the arm an AI country takes (`0x8B5210`) asks only for aircraft**, proved
  three ways with controls, so the 5.5 KB of land-and-naval demand is the **player's delegated**
  planner. `0x5ADE80` renamed `CSubUnitDataBase::GetInstance`, which is what made the block
  readable.
- ~~**Six fields the AI reads that nothing named.**~~ `FINDINGS-aifields.md`. `CGameState +0xBAC`
  is the **allied objectives indexed by who asked** - `set_allied_objective` is its only producer
  and the key is absent from all three savegames checked, with a control. `CCountry +0xACC` is
  `at_war` from its sole writer. And **`CMapProvince +0x5C` is the province's infrastructure**:
  the `+0x24 == 12` its writer gates on is a **`CModifier` id**, `MODIFIER_INFRASTRUCTURE`, never
  a building index, so the "mod reorders `buildings.txt`" obstacle was a misreading. It has
  **five** writers, three computing, so it tracks infrastructure in play.
- ~~**The AI's trade predicates and the neighbour byte.**~~ `FINDINGS-trade2.md`. The two mangled
  names are **template instantiations, not registrations**, and the const one belongs to a sixth
  predicate nobody had: `CEU3AI::HasTradeGoneStale`. **Slot 13 is `IsValid`, 14 `IsSelectable`,
  17 `GetAIAcceptance`** - all three named by the game itself through pointer-to-virtual-member
  thunks whose `jmp [eax+N]` gives the slot outright, so `FINDINGS-diplomacy.md`'s "the slot cannot
  be read from the registration" is wrong and slot 17 is no longer an inference. **Goods index 2 is
  `money`**, treated as the price of the other six, which is why it is skipped.
  **`CDiplomacyStatus +0x58` is the co-belligerent flag**, from two symmetric writers.
- ~~**Closing out the combat-modifier census.**~~ `FINDINGS-combat3.md`. **Land surprise is a
  half-removed feature**: one read of `surprise_chance` in the whole image and the answer is
  discarded, `SURPRISE_BONUS` has zero readers against controls of 6, 8, 18 and 23. The
  `BM_ARMOR_ADVANTAGE` flag reaches **one script trigger and nothing else**, while the armour
  mechanic it describes is live and independent in `FireUnit`. And the big one - **`CCombatant`
  slot 11's number is a display quantity**: its only consumer is the `combat_status` window's
  per-tick refresh, which inverts what this file said about `CSubUnit +0x54` (see below).

### Wave 7, 2026-10-02

Five agents, five findings files, and **two published claims corrected** - which is the part worth
reading first, because both were wrong in the record and one was wrong in the brief that launched
the wave.

**A. `FINDINGS-gui.md` - and `combat_status` is not a window.** The brief's whole premise was
wrong. `combat_status` and `combat_status_close` are **`billboardType` entries in
`interface/mapitems.gfx`** - textured quads drawn on the map - not GUI windows, and the lookup runs
against the **object-type registry at `CGraphics +0x6BCF0`**, which is not the GUI registry and
does not resemble it: the GUI registry is a case-insensitive **ternary search tree** and does not
use `StringHashFind` at all. Checked against the file on disk, which settles it in one line:
`billboardType = { name = "combat_status" ... noOfFrames = 3 }`, and `noOfFrames = 3` is exactly
why the record had already observed that slot 24 takes 0, 1 or 2. **The observation was right and
the word "window" was wrong.** `CCombat +0x2C`/`+0x30` are now `combat_status_billboard` and
`combat_status_close_billboard`, typed `CBillboardObject*`, freed with the combat by
`CCombat::DestroyInterface` - so the DLL must re-read them and never cache them across a combat
ending. Seven GUI classes entered the record (`CGraphics`, `CGui`, `CGuiType`, `CWindowType`,
`CObjectType`, `C3dVisibleObject`, and `CBillboardObject`, whose name is ours because only the
*type* class has an RTTI entry). Closes `FINDINGS-combat3.md`'s open item 2. **The real
find-a-window-by-name call shape is in its §3.**

**B. `FINDINGS-uinumbers.md` - and five `CCountry` goods pools finally have names.** The *read this
rather than recompute it* list runs to 24 call shapes, each graded for whether it is safe to call
from the DLL. But the best thing in it is not a function to call at all:
`BuildGoodsLedgerTooltip` (`0x4F3000`) renders one goods category's whole daily ledger, and every
`RES_*` key in it is pushed within four instructions of the load of the value it labels. So the
offsets are *read*, and five pools the record carried as `unknown_pool_*`/`unused_pool_*` are now
**`convoyed_out` (+0x7B8), `traded_away` (+0x7DC), `repaid_away` (+0x824), `income_from_debt`
(+0x848) and `traded_for` (+0x86C)**. The positive control came free and is inside the same
function: two of the seven keys name pools the record already knew (`RES_PROD` -> `home_produced`,
`RES_CONVOYED_IN` -> `convoyed_in`), with the same instruction shape, so the method reproduces two
known answers before being trusted on five unknown ones. **This settles which of `+0x7B8`/`+0x7DC`
is which**, which the record had recorded as not established because the expense side offered no
asymmetry to fit on - the asymmetry was on the *display* side instead. `repaid_away` and
`income_from_debt` keep their "nothing fills this" note: a name is not a claim that a field is
live, and those two are an income/expense pair for a lending mechanic that exists in the layout
and in the interface and is inert in this build.

**C. `FINDINGS-opsarea.md` - neither name survived, and `CCountry +0xCC` is answered.**
`0x8BD270` -> **`CAIUnit::ScoreOpsAreaProvinces`** (it apportions nothing; `0x4C8EE0` does that
from what this leaves behind) and `0x8BBB50` -> **`CAIUnit::RebuildFrontAndApproaches`** (the old
name was true of the first 190 of 3,339 bytes and silent about the rest). Both read end to end.
And **`CCountry +0xCC` is `army_combat_value`**, the country's total brigade combat value in
thousandths, written hourly by `CCountry::RecountUnitTotals` **on a TBB worker** - so a hook there
must not assume the main thread. The route was not the savegame, which cannot see it because
`LoadKey` never writes it and `SaveContents` never emits it, but a scan of `CCountry::*` member
bodies.

**D. `FINDINGS-reorganise.md` - both names wrong in their verb, right in their domain, and the
extent wrong.** `CAIUnit_ManageAirUnits` and `CAIUnit_ManageNavalUnits`, `likely`: regrouping is
phase 3 of four in the air body and one of nine in the naval one, so "Reorganise" named a fraction
of each. The domains are now **`confirmed` from instructions** rather than guessed - the air body
caches the `type_index` of all eight air role definitions and no others, reads only
`CUnit::plan_air_stance (+0x20C)`, and is the engine's **sole** producer of `air_intercept`,
`logistical_strike` and `join_air`; the naval body reads only `plan_naval_stance (+0x210)` and is
the sole producer of `convoy_raid`, `patrol` and `intercept`. **And the air body's recorded extent
was short by 5,813 bytes** - the `ret 8` at `0x8CEE68` is a shared epilogue laid out mid-function,
which three `jne`s jump *over* and four sites in the far tail jump *back* to. Verified here before
applying: code at `0x8D04E6` jumps to `0x8CEE4F` and shares that epilogue's `[ebp-0xd]` local,
which is impossible unless it is the same frame. **So the "19 KB between them" in this file's own
wave-7 brief was wrong; the pair is 25,264 bytes.**

**E. `FINDINGS-startup.md` - and my stage numbering was wrong in three places, two badly.** As the
brief warned it might be, since the numbering was `.rdata` layout and not a reading. There are
**not thirteen stage functions but four**: `CEU3Application::LoadEverything` (`CEU3Application`
slot 6, rva `0x22FAC0`), the databases/map/history monolith (rva `0x2348F0`), the checksum
(`0x232DA0`) and the graphical map (`0x234570`). **The checksum is last, not seventh. The databases
are twelfth from the end, not ninth** - they run before events, sounds, flags, history and the
idler. **The graphical map is not called by `LoadEverything` at all**; the frontend calls it, after
the whole of startup. The two-technology-phase reading survived and sharpened: **phase 1 reads
`common/technology.txt` (folders and categories), phase 2 reads every `.txt` in `technologies/` and
makes the `CTechnology` objects, with the map and `CSubUnitDataBase` built in between** - which is
the load-order shape a content mod's bugs live in. **`CLASSES.md:1413` is closed**: all 24
`common/` files are paired to their loader by instruction, nine of them corroborated by names
already in the record. And a bonus that lands on the DLL: **`CCurrentGameState` is created at rva
`0x239A86`**, inside the database stage - which is precisely why `current() != 0` answers "yes" at
the main menu. The bytes there are worth seeing: `push 0xDA8` (the object's size), the constructor,
then `mov byte ptr [esi+0xDA4], 0` - `in_game` initialised to zero at construction, which is the
guard `Gui::Lua::sessionActive()` reads.

**Record after the wave:** 2,207 functions (was 2,088), 234 structs, 2,580 fields, 495 labels;
60 classes read, up from 57. The Ghidra apply now reports **`failed: 2`**, and the second one is
documented in `CLAUDE.md` - Ghidra gives `GuiTypeTree_Find` a body that runs past five `int3` into
`TernarySearchTreeFind`, and the bytes say the record is right and Ghidra is wrong.

**One tooling bug fixed, because it gave a wrong diagnosis.** `mergeEntries.py`'s `rttiVftable`
answered `None` both for a class RTTI has never heard of and for a class it knows but holds no
vftable address for, and the caller reported both as "check the name". Six correctly-named classes
were rejected with a message telling the next reader to go and doubt names that were already
right. The question is now split - `rttiKnows` against `rttiVftable` - and a struct name that is
deliberately ours goes in a new `OURS` table with its reason, the way `PREFER` already handles
address collisions.

### Wave 8, 2026-10-02 - the first wave with a running game

Five agents, **read-only access to a live process**, and the single most useful result the
interface work has produced. The game was a paused Ireland campaign at 1936-01-01 00:00.

**A caution that cost a premise.** I told four agents the game was playing **France**. It was
playing **Ireland**. That was my inference from province 2613 (Paris) being *readable*, which is
true in every game and is not evidence of who is played; `+0xC30 player` reads `IRE`, id 20. Two
agents had already reached it themselves and one said so before I corrected it. **An inference
stated as a fact in a brief is the same error as an inference stated as a fact in the record** -
and worse, because an agent cannot check it.

**A. `FINDINGS-guilive.md` - the name-to-live-object path, and it works today.** This is what the
DLL has been wanting. Every live widget in the process is in one flat
`std::vector<CGuiObject*>` at **`CEU3Gui +0x5C`**; `CGuiObject +0x24` is the widget's `CGuiType*`
and that type's `+8` is its **name**. A live `CFixedWindow` additionally carries **six
case-insensitive ternary search trees of its children by name**, at `+0x324`, `+0x348`, `+0x36C`,
`+0x390`, `+0x3B4`, `+0x3D8`.

I verified the whole chain independently: **2,305 widgets, 1,142 distinct names**, and on a
`textBoxType` widget the name is at `+0x54`, the font at `+0x70` and **the displayed text at
`+0xD8`**. Reading the top bar gave Ireland's own figures - `ic_number` `§R10/§G21/21`,
`manpower_number` `115`, `money_number` `§G591`, `leadership_number` `§G108%`, `oil_number`
`§R1870`, `supplies_number` `§G391`.

**Two hazards, both found by doing it rather than reading about it:**

1. **Every top-bar widget exists twice**, and one copy holds placeholder text - `ic_number`'s
   other instance reads `1000`, and the others read `???`. **Taking the first match by name out of
   the flat list gives you the placeholder.** The window's child tree is the correct route, which
   is exactly what the agent used.
2. **The text is Windows-1252 and carries the game's colour escapes** (`§R`, `§G`). It has to go
   through `Text::toUtf8`, as the house rule already says for anything read out of the game.

**D. `FINDINGS-session.md` - and a sentence in shipped code was wrong.** `in_game`
(`CCurrentGameState +0xDA4`) has **six writers in the whole image and only one writes a one**,
`0x25D126` in `CInGameIdler::Enter`. Of 2,822 occurrences of the displacement, 2,772 are copies of
one inlined get-or-create accessor - which also explains the "2,773 direct callers of
`CGameState::CGameState`" that `FINDINGS-startup.md` flagged: they are accessor copies, not
constructions, and at most one ever constructs anything.

**`in_game` is NOT set during a load.** `CLAUDE.md`, `GameClock.cpp` and this file all said it was,
and all three gave that as the reason `GameClock::movedInPlay()` is stricter. The savegame loader
contains none of the six writers and is reachable only from the pre-game lobby or
`CTutorialScreen`, neither of which is the in-game screen. **The guard itself is right and does not
change**; the window it really excludes is the **tail of `CInGameIdler::Enter`** - the write lands
0x4A92 bytes before the end of it and everything after that builds the in-game interface, so there
is a stretch where a session exists, `in_game` is 1, and the in-game GUI does not. All three
places now say so. *A wrong reason attached to correct code is worse than no comment, because the
next person to change the code reasons from it.*

I re-derived the census by a second method before touching the shipped comment, and it agreed at
every stage. Also: `+0xD9C` is `loaded_from_save`, read thirteen times inside `Enter`; the game
state object is created **once per process and never replaced**; and at the main menu
`+0xBE8 in_game_screen` holds a **`CFrontEnd`**, not a `CInGameIdler`, so anything reaching
`CInGameIdler` fields through it must gate on `in_game` first.

**E. `FINDINGS-aiconsumer.md` - and the live game could not answer the AI question.** `0x4D57F0`
read end to end: it is **the land half of slot 73** and the consumer of `CAIUnit +0x294`, `+0x1BC`,
`+0x1CC`, `+0x2C0` and `+0x11C`, which is what makes the ops-area scoring mean something. Two
standing questions closed: **`CUnit +0x98` is `CUnitBaseProvince` / `CUnitBaseCarrier`** (open since
2026-09; I corroborated both as real RTTI classes with instances past the 800 limit, and
`CUnitBase` itself has no vftable, so it is the interface), and **`CCountry +0xACD` is
`in_undeclared_war`**.

**But the live check it was sent to do is unanswerable in this session state, and it proved that
rather than guessing.** At tick 0 **no `CUnit` has an AI agent at all**: all 112 `CAIUnit` objects
are freshly constructed shells with `unit == 0` and every data pointer null, controls included. So
the four air list heads being null is **not** evidence about phase 2. I confirmed it: 112 agents,
0 with a unit pointer, 0 non-null heads. **To answer it the game has to be unpaused and run far
enough for the AI to attach.**

**The agent then revised this file after the played-country correction reached it**, and the
revision is the one on disk. It verified `IRE` itself, and re-running the census per country turned
up that **Ireland has no `CAIUnit` agent at all** - 112 agents across 78 tags, none of them `IRE`,
with France on 7, ENG 8, SOV 8, GER 3 - so the sample had been 100% AI countries all along and the
item-4 result did not depend on the bad premise. More usefully, **re-checking made it find its own
error**: the one anomaly it had been about to report, "a single `CArmy`/`CAir`/`CNavy` at
`plan_stance` 0", was three **false positives from `hoi3.instances`** matching a table of vftable
*addresses* in the data heap at `0x6ECF5C78`-`0x6ECF5CA8`. Three `CUnit`s cannot sit 4 and 0x1C
bytes apart. The corrected distributions are 100%, not 99.7% - the anomaly was the tool, not the
game. **That is now `TRAPS.md` trap 15**, and I re-checked my own `CUnitBaseProvince` corroboration
against it: 900 hits with a 0x30 stride in 876 of 899 gaps and valid code in every sampled vftable
slot 0, so those are real objects and `CUnit +0x98` stands. Three function names also changed,
`...BarForStance` to `...ThresholdForStance`.

**C. `FINDINGS-mapbuild.md`** - the map build, its cache and how the frontend is reached, read
statically and against the live map. It also noted, correctly, that nothing in it rested on who was
played, because every province was selected by id and the geometry is identical either way.

**B. `FINDINGS-uinumbers2.md` - one more field map, and two dead leads with the control to prove
it.** The brief's two top-ranked leads (the eleven other ledger pages and the `BUILD_*_DRO`
cluster) are **both dead, for the same structural reason**, and the agent supplied the positive
control that says so rather than reporting a flat negative. The third lead paid: **`0x138D60` is a
second `BuildGoodsLedgerTooltip`**, and it names **57 fields of `CTechStatistics`** - the struct
`CCountry +0xDF8` points at - of which 16 were already in the record under consumer-derived names
and about 41 are new. Offsets and **three different scales** were checked against the running game
and the mod's own `technologies/*.txt`, with nine exact single-declaration matches.

It also **found and fixed a bug in the sweep's own attribution method** (a phantom call target),
re-ran it over all 9,491 key references, and then ranked by *shape* rather than key count - which
says there is **exactly one more function of the valuable shape in the whole sweep, and it is the
one it read**. So the remaining ~160 low-scoring candidates are unlikely to be field maps, which
turns "365 unread" from a backlog into a closed question. Of the 389, **223 are scored and 11
bodies read**.

This agent also caught the played-country error itself: its live block came from the country
database's cached **FRA** slot, which it had labelled from the cache rather than verifying, and it
re-read both with the tag checked off `CCountry +0xCA4`/`+0xCA8`.

**Record after the wave:** 2,252 functions (was 2,207), 241 structs, 2,642 fields, 526 labels;
**62 classes read**, up from 60. Ghidra still reports the documented `failed: 2`.

### Tiers 1 and 2, 2026-10-02 - the first session with a war save and a hook

Two static agents plus live work in a GER 1942 save. **Both tier-1 questions are answered and the
tier-2 block is cleared.** The pattern worth carrying forward: of the five things that went wrong,
**four were my own inferences from counts or absences**, and all four were caught by one more
measurement or by David's knowledge of the game - not by argument.

**1. `CCombatant` slot 11: nothing else calls it. Confirmed live.** A static census (four sweeps,
each with its own positive control) cut 1,033 virtual calls through `+0x2C` to the two sites in
`CCombat` slot 17, bounded by one route it could not close - the vcall thunk at `0x149E00`
dispatched from a runtime-filled listener table. **A hook then recorded 39,414 calls with overflow
0, the slot counts summing exactly to the total, and three return addresses, all accounted for**:
`0x168EED` (39,222 - `CLandCombatant`'s own forwarder into the same body), `0x17B085` (96) and
`0x17B093` (96). **The thunk route never fired.** So `FINDINGS-combatmods.md`'s "the defence-side
modifiers are live" is struck: for **naval, air and bombing** the defence side of that census is
cosmetic in this build, including `BM_POOR_SCREEN_PENALTY` and a bombing target's
`BM_FORT_MODIFIER`, and a mod cannot reach the simulation through any of them. **Land survives** -
`CUnit +0xF0` is read by the AI's land-attack-odds estimator at `0x8D9825`/`0x8D9C3A`, which the
census did not have. *Caveat written into the file: bombing never ran in the session, so that arm
rests on the static reading alone.*

Two things the same work settled on the way: **the refresh is player-gated** (`CCombat::Tick` calls
it only when the player's own country id is in the attacker's or defender's list, so an AI-vs-AI
battle never computes those modifiers at all - **player-only**, not merely display-only), and
`FINDINGS-combatmods.md` §9's `0x4A7` extent was wrong (it is `0x187`; `0x4A7` was measured from
`ApplyLosses`, the arithmetic outliving the trap-2 error it came from).

**2. The reset path cannot be observed mid-wipe. Both shipped guards are correct.**
`CInGameIdler::Update` does reach `CGameState::ResetSession` in ordinary play - it is the tutorial's
return to the menu - but the wipe at `0x65472C` and the `in_game` clear at `0x654775` sit **73 bytes
apart in one straight-line block with no `ret` between them**. The two residuals I pushed back on
both resolved: the single branch in the window is the `operator new` failure arm, where
`CInGameIdler::Leave` still clears the byte and the arm then faults anyway; and the indirect call
inside the window is slot 4 of a 0xC0-byte object, **a bare `ret 4` shared stub** that executes
nothing. Separately, `CLAUDE.md`, `GameClock.cpp` and this file all said "`in_game` is set for the
whole of a load" - **that was wrong** and all three now say what the window really is (the tail of
`CInGameIdler::Enter`, after the byte is set and before the in-game GUI exists).

**3. The GUI vector does remove elements, and there is a leak.** Demonstrated twice: opening the
production window erased the outliner's six widget names, and dismissing two message popups removed
fourteen. **Erase-and-compact with no holes** - `widget_nulls` stayed 0 throughout while
`widget_end` moved by exactly the count delta and `widget_begin` never moved. **So BiceLib must
never cache a widget pointer or an index across a panel opening or closing**; the index case is
worse, because after a compaction it addresses a different live widget and returns plausible
garbage. Found by accident: **every open/close of a full-screen window permanently leaks 30
widgets** (ten each of `outliner_header`, `outliner_header_entry`, `entry_text`), measured 10 -> 20
-> 40 over three cycles with the vector total matching to the widget. Popups by contrast are
perfectly symmetric, so **the leak is one broken path, not a broken mechanism**. A by-product: a
live widget name (`DefaultPopup`) traced to `interface/eu3dialog.gui` on disk, whose loader
`CEU3DialogGuiType::LoadKey` was already named - the chain closing in both directions.

**4. The tier-2 block, all four cleared.** The air rebase list heads are **populated** (93 of 102
agents), so `CAIUnit_ManageAirUnits`' phase 2 is not dead code - though every agent's unit is a
`CArmy`, which casts doubt on the "air target provinces" names. `plan_air_stance` is **1** on 1,125
of 1,126 live `CAir`, so of the three arms the one that runs is the plain one with full thresholds -
and `+0x20C`/`+0x210` hold the **identical value on all 4,864 objects read**, which the static
reading did not predict. `CRegion +0x6D` reads 1 on **30 of 2,000+** regions against 0 of 400 at the
scenario start, so the +100-per-region scoring does fire. And the debt pools are explained rather
than closed - see the open list.

**5. The menu trip: six claims confirmed by one observation.** The game-state pointer was
**byte-identical** before and after (`0x37BBD818`), so the object is reset and never replaced;
`in_game` 1 -> 0, `loaded_from_save` 1 -> 0, `in_game_screen` from `CInGameIdler` to **`CFrontEnd`**,
`player` from `GER` to `---`, and the tick back to the 1936 epoch.

**What was corrected, and it is the useful part.** "The missing agent is the player's" (Germany has
three theatres, so three would have to be missing); "that agent is a false positive" (it sits mid-run
in a regular 0x388 stride with the right vftable); "it is freed memory" (an *attached* agent's
`+0x294` is equally large, and nothing churns). The real answer came from a field, not a count:
**`CTheatre +0x7C`/`+0x80` is the owner tag and id**, and there is **no pointer either way between
`CAIUnit` and `CTheatre`** - a sound negative with the complete target set and a working control - so
the association is by country. With it, theatres and agents match per country almost everywhere, and
the agentless ones can be named: **CHI, BHU and one null-tag theatre**. The agent pool holds
transients in both directions, which is why the counts never matched.

**And one defect in my own tooling, found by its own output.** The live snapshot script printed the
trap-15 spacing discriminator without acting on it, and so reported **87 `CCombat` at the main
menu**, where none can exist. Every combat count it printed was contaminated. No conclusion rested
on them, but they had been reported as fact. `TRAPS.md` trap 15 now carries it as a worked example:
printing a discriminator is not applying it, and a figure that cannot possibly be true is the
cheapest check available.

## What those left behind

**Empty as of 2026-10-01** - `FINDINGS-survivors.md` closed all three. What they turned into
is below, kept because each has a residue worth knowing.

- ~~**`CDistributionSetting +8`.**~~ **It was never open.** It is `base_percentage`, named since
  `FINDINGS-production.md`; three documents including this one were stale against the record.
  **That is trap 14 from the direction the trap file did not warn about** - the check for what
  already exists belongs before an item goes *on* the queue, not only before a name goes in.
  The residue: `slack` is the sum of two **slider positions** (what is requested), not spare
  capacity, which makes the word `slack` actively misleading in `FINDINGS-techdecay.md`.
- **The five diplomatic actions** whose slot 17 neither pushes a literal nor calls the bridge -
  `CCallAllyAction` (`0xA2AC80`), `CEmbargoAction` (`0xA438F0`), `CLicenceTechnologyAction`
  (`0xA3D3F0`), `CRequestLendLeaseAction` (`0xA0FE20`), `CTradeAction` (`0xA38B00`) - against
  the five Lua wrappers around `0xA444xx`-`0xA44Cxx` that do, each with one caller.
  `FINDINGS-convoys.md` got one step further on the last of them without closing it: `CEU3AI`
  has two registered methods taking a `CTradeRoute&` and returning `bool` (mangled names at
  `0x15F02C8` and `0x15F02E8`), which is the right shape for the untraced route - the AI handed
  a route and asked yes or no - but the wrapper was not followed to its caller.
- **`0x4FA0B0`** recomputes all seven alignment terms and would confirm every formula in
  `FINDINGS-politics.md` cheaply.

## The queue

**Wave 9 is planned below, four agents.** David's priority order still holds: the interface layer,
then the last unread AI blocks, then core engine flow, then the rest. What is not scheduled is
further down.

**Before any of it launches, one piece of housekeeping:** `FINDINGS-guilive.md`'s *What is not
established* item 1 - "whether anything removes an element from `CGui +0x5C`" - **is answered** and
should be struck. It was settled live on 2026-10-02 (erase-and-compact, no holes, demonstrated
twice). Leaving it is the stale-open-list trap in trap 14, and it would send an agent to re-derive
a settled fact.

### Wave 9, planned - four agents

**A. `0x8D93B0`, the AI land-attack-odds estimator.** rva `0x4D93B0`, 2,682 bytes, recursive, and
**unread**. This is the single most load-bearing unread function in the record: it is the only
non-display reader of the land defence product `CUnit +0xF0`, and therefore the only reason the
land half of `FINDINGS-combatmods.md`'s census survived the demotion. That claim is `likely`
*solely* because this body has not been read. Reading it either promotes a published claim to
`confirmed` or demolishes it, which is the best value-per-byte on the list.

Two specific questions it must answer. Is `esi` really a `CUnit`? The identification rests on the
`+0xF0`/`+0xF8` pair being distinctive (trap 12's neighbour fallback) and not on
`fieldchain.py --holder`, which **works now** - that bug was fixed on 2026-10-01, whatever a
leftover note in `FINDINGS-slot11.md` says. And **are the products ever non-neutral when this
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

**C. Finish the live GUI layer.** Four items from `FINDINGS-guilive.md`, now much cheaper than when
they were written because the access route is known and verified: `CInGameIdler +0x1790` ->
`CEU3Application` -> `+0x120` -> the one `CEU3Gui`, three reads, with no global anywhere in the
image (a scan of all 16 MB for the live pointer found zero).

- **Nine of the twelve live widget classes cannot be named** - the RTTI export has no entry for
  them, so they need naming from their vftables and behaviour, the way `CBillboardObject` was.
- **`CFixedWindow +0x4C` is a linked list of something**, walked by slot 36 (`0xAC1220`).
- **Registries 1 (`+0x348`) and 5 (`+0x3D8`) are empty on all 206 windows**, so what they hold is
  unknown. A live game with panels open is the way in.
- **The ledger window's class** (`FINDINGS-uinumbers2.md`): `0x3C1ED0` is in no vftable.

**D. The session lifecycle's remaining gaps.** `FINDINGS-session.md` named these and deliberately
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

### Also open, not scheduled

**The one that would change a published claim.** Everything else here is an addition; this is a
subtraction.

1. ~~**Does anything outside `CCombat` slot 17 call `CCombatant` slot 11?**~~ **ANSWERED
   2026-10-02, statically and then live: no.** See `FINDINGS-slot11.md` and the Done entry above.
   39,414 hooked calls, three return addresses, all accounted for, and the one route the static
   sweep could not close never fired. The subtraction was applied: `FINDINGS-combatmods.md`'s
   defence-side claim is struck for naval, air and bombing and kept for land.

   **What is left of it is narrow and worth keeping:** *bombing never ran in that session*, so the
   bombing arm rests on the static reading alone; and `FINDINGS-combat3.md`'s own open item 1 -
   enumerating `CCombat` **slot 17**'s receivers outside the combat module - is **not** closed.
   `FINDINGS-slot11.md` §7 shows why the same method cannot close it: the filters cut slot 11 from
   1,033 sites to 14 but slot 17 only from 1,871 to 573, because the discriminating power came from
   the receiver's production site and a `CCombat` pointer is reachable from too many places.

2. **Whether `CCountry +0x824` `repaid_away` and `+0x848` `income_from_debt` are ever written.**
   **Partly answered live 2026-10-02 and it needs the game run on, not more reading:** non-zero in
   **0 of 108** live countries at the scenario start, with `home_produced` and `usage` populated in
   106 of them and four sibling trade pools populated too, through the identical read path - so the
   zero is the field's and not the reader's. But that shows "not yet", never "never", and a lending
   mechanic is exactly what would only fill once a loan exists.
   The tooltip proves the game is willing to *display* both, and the record says nothing writes
   either and every reader gets zero. If that holds, it is a whole inert lending mechanic, and
   worth knowing before anyone tries to use it. The savegame is the cheap oracle: neither key
   should appear.

3. ~~**What a "region" is as a class.**~~ **ANSWERED live 2026-10-02: it is `CRegion`.**
   `CMapProvince +0x358` is a `vector<CRegion*>`, so the class is reached as
   `*(*(province + 0x358))`, and `classNameForVftable` answers `CRegion` on 8 of 8 provinces
   tried. `hoi3.instances` finds 400+ of them at a **uniform 0x78 stride**, which is the trap-15
   check for real objects rather than a pointer table, and `+0x6D` is in range of a 0x78-byte
   object. `CAreaBorder` was correctly eliminated. **What the `+0x6D` byte means is still open**,
   and is now a question about one named 0.1 KB class: it reads **0 on all 400 regions** at the
   scenario start, so `ScoreOpsAreaProvinces`'s "+100 per region" never fires there. Whether that
   is because the AI is not yet running or because the byte is set by war is the remaining
   question, and running the game on would answer it.

   *The original entry follows, for the search it proposed.* `ScoreOpsAreaProvinces` adds +100 per region whose byte at
   `+0x6D` is set, and `CAreaBorder` is eliminated (its constructor initialises only to `+0x28`).
   `UndeclaredWarCoversProvince` (rva `0x763A0`) compares `CUndeclaredWar +0x28`/`+0x2C`'s members
   against the list, so the members' class is whatever that vector holds. **A live `dumpStruct.py`
   on `provinces[n]->+0x358`'s first payload names it for free**, because the vftable identifies
   the class.

4. ~~**`CUnit +0x98`'s class**~~ - **ANSWERED by `FINDINGS-aiconsumer.md`: `CUnitBaseProvince`
   and `CUnitBaseCarrier`**, the two concrete subclasses of `CUnitBase` (which has no vftable of
   its own, so it is the interface). Corroborated against trap 15: both show hundreds of live
   instances at a regular stride with valid code in vftable slot 0. Open since 2026-09.

   *Original entry:* Both AI
   bodies lean on it constantly - slot 0 is the province, slot 1 a validity test - and
   `CMapProvince +0x54` now gives a second handle on it. Agent D calls it the cheapest unanswered
   question about either body.

5. ~~**`CCountry +0xACD`**~~ - **ANSWERED by `FINDINGS-aiconsumer.md`: `in_undeclared_war`**,
   named from its two writers with a positive control. Was beside the recorded `+0xACC at_war` and tested with it at five places
   across slot 73 and both AI bodies. Still unnamed anywhere.

6. **The game's own name for `GuiTooltipText`.** No vftable, so RTTI cannot name it; 114 callers of
   its destructor and 86 producers, but no consumer was found, and a consumer is what would name
   it. The struct is in the record under our name, flagged as ours.

7. **The force-needs half's remaining 2 KB.**

8. **`0x4AF580`** (`CTheatre::AddFront` as proposed), read only to its first ~60 instructions.

## Loose ends the findings flag themselves

Cheap, because the context is already written down.

| where | the question |
| --- | --- |
| ~~`CLASSES.md:1413`~~ | **answered** in `FINDINGS-startup.md`: all 24 `common/` files are paired to their loader by instruction, through the per-file stack slot, with nine of the pairings independently corroborated by names already in `project.json`. **`CLASSES.md:1413` should be struck.** |
| ~~`FINDINGS-combat.md:372`~~ | **answered** in `FINDINGS-airnaval.md`: the hook fires for every kind, and `+0x84` is **not** the same scale - a naval row counts ships |
| ~~`FINDINGS-combat.md:546`~~ | **answered** in `FINDINGS-combatmods.md`: 69 call sites across two adders, with what decides each of the 30 ids |
| ~~`FINDINGS-combat.md`, "which slot air and naval override"~~ | **answered, and the question was wrong.** There is no override: naval and air modifiers go on a **different object** through a second adder, and `CUnit::ResetCombatModifiers` is called from the **base** slot 19 that every kind runs. `CUnit +0xDC` on a ship is cleared every tick and never filled |
| ~~`CLASSES.md` `+0x618`/`+0x628`~~ | **answered, four independent ways** (`FINDINGS-aifields.md` §6). `+0x618` is `ministers`, one per government position; `+0x628` is `laws`, one per **law group**, pre-filled with the `CNullLaw` singleton and resized from the law database. A country's laws are saved as `<law group name> = <law name>`, which is why `CCountry::LoadKey` has no `law` key at all. **`CLASSES.md`'s closing "One is left" paragraph is stale and should go** |
| ~~`CLASSES.md:453`~~ | **answered, and the question was wrong**: neither is a define. `Define10` and `Define50` are `(int)floor(10.5f)` and `(int)floor(50.5f)` statics written by their own `.CRT$XCU` initialisers, each appearing exactly once in the CRT table - so no `defines.lua` entry can move them. `Define10` is also the **same global** as `CUnit::AddCombatModifier`'s clamp floor. `FINDINGS-combat3.md` §5 |
| ~~`FINDINGS-combatmods.md`~~ | **both answered** (`FINDINGS-combat3.md` §1-2). `surprise_chance` feeds **nothing** - one read in the image, the answer discarded, and `SURPRISE_BONUS` has no reader at all against four controls, so land surprise is a half-removed feature. `BM_ARMOR_ADVANTAGE`'s flag is read by **one script trigger** and nothing else; the armour mechanic itself is live and independent in `CLandCombatant::FireUnit`, swapping both land dice sizes - and the flag's rule and the mechanic's rule are different computations that **can disagree** |
| `FINDINGS-weatherfront.md` | two front headings in the user's savegame that do not fit the 0.125 lattice. Both are facts in the file and neither is accounted for |
| ~~`FINDINGS-aitheatre.md`~~ | **answered**: `CCountry +0xF98` is **us plus our co-belligerents, minus anyone we are also at war with**, because the byte `RebuildNeighbours` tests is `CDiplomacyStatus +0x58`, the co-belligerent flag - named from two symmetric writers called out of `CWar::AddAttacker`/`AddDefender` (`FINDINGS-trade2.md` §5). Separately, `CCountry +0x1008` **is** `enemies`, a list of who we are at war with, written by `0x4E6A70` (`FINDINGS-aifields.md` §2) |

## A method worth reusing

**`definesMap.py` backwards.** Scan for `call GetDefines (0x445D90)` followed within a few
instructions by `[reg + <block>]`, then read which `+<field>` comes next. A define is read from
only one or two places in the image, so this turns a name in `defines.lua` straight into a
function address with no guessing. Four of the politics candidates came from it, and it has not
been pointed at the economy or combat defines yet.

**It misses inlined call sites, and one of those hid the most-wanted function in the folder.**
`CCountry::UpdateMonthly` reads `BASE_TECH_DECAY` with `GetDefines` inlined into it - the same
body, the same `push 0x11C` and `call 0x4452E0`, the same singleton `[0x1A86040]`, but no
`call 0x445D90` for the scan to anchor on. The scan therefore reported "exactly one reader" of
that define, and the record carried the wrong conclusion until the function was found another
way. **So a negative result from this method is not evidence**, and any claim of the form "the
only reader of X" that came from it needs the singleton address searched for directly before it
is believed. `findValue(0x1A86040)` is the cheap check.

**And a third way a define hides, which is worse than inlining because the scan comes back
*empty*.** The whole `weather` block - all 56 entries - is read **once**, at startup, by
`CWeatherManager::InitialiseWeatherState` (`0x4B54F0`), which copies 49 of them into individual
globals with one `mov ecx,[eax+0xEC]; mov edx,[ecx+N]; mov [global],edx` apiece. Every consumer
afterwards reads a bare absolute address, so a scan for `call GetDefines` finds **zero** readers
of a block that 56 live values come out of. `scratchpad/naval/definecache.py` recovers them by
scanning for that three-instruction shape; it found 51 globals across the `military` and
`weather` blocks. **So three things can hide a define: `GetDefines` inlined into the caller, the
block cached into globals at startup, and a value that was never a define at all but a
`(int)floor(N.5f)` static written by its own `.CRT$XCU` initialiser** - there are 7299 of the
last kind, and two of them are the combat-modifier clamp floors that a mod cannot move.

**A scan built on `image.functionStart` is off by one function wherever two abut.** Use
`image.retsBefore(candidate, address)` to see it - a `ret` in between means look, because it is
either an abutting function or an early exit with a cold path after it.
