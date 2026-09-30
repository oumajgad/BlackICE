# What to read next, and why

A work queue. `PROGRESS.md` is the scoreboard and is generated; this is hand-written and says
what is *worth* reading, with enough of an anchor that nobody has to find it twice.

Collected 2026-09-30 by six parallel surveys of the domains the record had barely touched.
**Every address below was checked against the executable** - a vftable slot read, a call site
decoded, a string reference confirmed - not taken from a class name that sounded right.
Addresses are virtual (based `0x400000`) with the rva beside them.

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

## What those left behind

Small, anchored, and each one an afternoon or less:

- **`RunMonthlyPass` and `RunYearlyPass` bodies** beyond the event-list rebuild. Since the
  monthly and yearly screen hooks are both do-nothing stubs, these two functions are the whole
  of the game's monthly and yearly behaviour.
- **How often the AI really runs.** `ProcessAIFunctor`'s fan-out is called once a day from
  `RunDailyPass`, but a second `parallel_for` site exists near `0x68F101` and
  `CInGameIdler::Update` reaches AI code too. The two schedules disagree; one of them is the
  one that matters.
- **Where practical decay is actually applied.** `0x204A0` is the only reader of
  `BASE_TECH_DECAY` and is reached from a command and an idler function, not the tick - yet
  practicals visibly decay in play, so something else must apply it. **Not a virtual call**:
  nothing in that chain sits in any vftable slot, so `findRefs` saw every caller. Start instead
  from the 27 functions that touch `CCountry +0x698` `category_levels`, `0x41FFF0` first - it is
  immediately beside the decay code. See `FINDINGS-research.md`.
- **The five diplomatic actions** whose slot 17 neither pushes a literal nor calls the bridge -
  `CCallAllyAction` (`0xA2AC80`), `CEmbargoAction` (`0xA438F0`), `CLicenceTechnologyAction`
  (`0xA3D3F0`), `CRequestLendLeaseAction` (`0xA0FE20`), `CTradeAction` (`0xA38B00`) - against
  the five Lua wrappers around `0xA444xx`-`0xA44Cxx` that do, each with one caller.
- **The command post choke point**: `in_game_screen` slot 18 returns an object whose `+0x38`
  gets slot 6 called with the command. The single point all ~105 `CCommand` subclasses pass
  through, and where the multiplayer question lives.
- **`0x4FA0B0`** recomputes all seven alignment terms and would confirm every formula in
  `FINDINGS-politics.md` cheaply.
- **`CSpyPresence`**, the 0xF8-byte espionage record, and **`CAIUnit`** (90 slots, 34
  introduced - theatres, fronts and battle plans). A day and two days respectively.

## The queue

**Empty, for the first time.** Every candidate the 2026-09-30 survey raised has been read and
written up - see *Done* above - so the next queue has to be collected the same way: pick the
domains the record has barely touched, anchor each candidate in something actually seen in the
executable, and check every claim against the bytes before writing it down.

What is left of the old queue is in *What those left behind*, and those are follow-ups rather
than candidates: each one is a specific question with an address attached.

**Domains still untouched**, as a starting point for the next round: air and naval mission
resolution (`CAirOrder` had 208 live intercept orders in a census); weather's effect on combat
and movement, as opposed to the `CWeatherFront` grammar already read; occupation, partisans and
resistance; leaders - experience, traits and promotion; and the interface classes, which nothing
has ever looked at because they are not simulation.

## Loose ends the findings flag themselves

Cheap, because the context is already written down.

| where | the question |
| --- | --- |
| `FINDINGS-combat.md:546` | what pushes onto the combat-modifier list - the notes call it "the obvious next step", and it is where each modifier is *decided* rather than totalled |
| `CLASSES.md:1413` | how a `common/` file is matched to the class it fills - why a top-level key becomes a `CBuilding` and not a `CGovernment` |
| `FINDINGS-combat.md:372` | whether the combat-history hook fires for air and naval, and whether `+0x84` losses are the same scale for ships |
| `CLASSES.md` `+0x618`/`+0x628` | `CChangeLawCommand::Execute` writes `+0x628` and `CChangeMinisterCommand::Execute` writes `+0x618`, with different index fields - so `+0x628` looks like the **laws** array, which `CLASSES.md` records as unestablished |
| `CLASSES.md:453` | two combat defines whose names are not known (10 and 50) |

## A method worth reusing

**`definesMap.py` backwards.** Scan for `call GetDefines (0x445D90)` followed within a few
instructions by `[reg + <block>]`, then read which `+<field>` comes next. A define is read from
only one or two places in the image, so this turns a name in `defines.lua` straight into a
function address with no guessing. Four of the politics candidates came from it, and it has not
been pointed at the economy or combat defines yet.
