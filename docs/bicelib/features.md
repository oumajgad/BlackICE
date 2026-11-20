# BiceLib: every feature, as behaviour

## What this file is for

BiceLib is the C++ module (`BiceLib.dll`) that BlackICE loads into the running game, Hearts of
Iron 3: Their Finest Hour. It mends faults of the original, adds and changes rules, extends
what tooltips and effect texts say, draws an in-game utility, gives the mod's Lua things the
game's own Lua API does not, and carries developer tooling.

This file describes **all of it as behaviour**: what each feature does, exactly enough to build
it again from the text, for a reader who will never open BiceLib's source. That reader is a
reimplementation of the game's engine that is to offer these features natively and is not
allowed to read the DLL, because the DLL's source is written against the memory layout of one
build of one executable. So this file holds **no address, offset, virtual-table position, byte
pattern or structure layout** - only game functions and classes named by what they do. Where a
number appears it is a game value, a count or a default, in decimal.

It is a description, not a design: where BiceLib does something odd, the oddity is described
as it is, and the closing sections collect what looks like a fault.

## How it was made

Written on 2026-11-20 by reading, in the BlackICE repository:

- BiceLib's own documents: `README.md` (the Lua API), `README-imgui.md` (the overlay),
  `BiceLib/Gui/Pages/README.md` (adding a page), and its `CLAUDE.md`;
- the source under `DaveStuff/luabinaries/bice/BiceLib/BiceLib`: `bice.cpp` (every function
  registered with Lua), `Patches.*`, all of `Hooks/` (with `Hooks/EffectText`, `Hooks/Tooltips`
  and `Hooks/TriggerText`), `Commands/`, `Overlay.*`, all of `Gui/` and its pages, all of
  `GameState/`, `Reversing/`, `Settings.*`, `CrashReport.*`, `Diagnostics.*`, `TextTable.*`,
  `TextEncoding.*`, `MemScan.*`, and the `.cpp` workers under `GameClasses/` that build the
  tables handed to Lua (the headers there were read only for what a field means);
- the mod's Lua that works with it: `script/bicelib_lua.lua`, `script/utility_settings.lua`,
  `script/gui-imgui.lua`, `script/bicedata.lua`, `script/utility_imgui/`,
  `script/utility_data/`, and the callers of `BiceLib.*` elsewhere under `script/`
  (`ai_variable.lua`, `ai_omg_handlers.lua`, `ai_globals.lua`, the old utility's files);
- the mod's content the features name: `localisation/*.csv`, `interface/messagetypes.txt`, the
  events and covert operation of the resource conversion;
- for the original game's behaviour, the reverse-engineering fact base's write-ups, cited as
  `reversing/findings/FINDINGS-<name>.md` (the fact base's logical name; every file cited was
  checked to exist on that date).

The parts on the overlay's pages, the texts and the tooling were drafted by separate readers
of those files to one brief and assembled here; the parts on fixes, rules, leaders and
commands were written from the source directly.

**Where each statement comes from** is marked: `(source)` - the code that does it was read;
`(readme)` - only BiceLib's README says so; `(comment)` - a comment in the code says so and
the code was not checked for it; `(findings)` - the cited fact-base write-up says so. A marker
at the end of a paragraph covers the paragraph. Where code and README disagree the code is
followed, and the disagreement is listed in the closing section.

**State is reported as the mod has it committed** (`git show HEAD:script/bicelib_lua.lua` and
`HEAD:script/utility_settings.lua`, on 2026-11-20). The working tree on that date differed: it
had nearly every call in `bicelib_lua.lua` commented out, leaving `fixMaxInfrastructure` on,
`BiceLib.startConsole()` switched on, and `G_ImguiUtilityEnabled = false` - a temporary state
for making reference savegames. Nothing below describes that temporary state.

Everything is valid for this one build of the game; the behaviour described is what a
reimplementation needs, not the means.

## Conventions

- **Thousandths.** The game's numbers are fixed-point: `12050` is 12.050. Where a figure is in
  thousandths the text says so; a country variable set with `value = 50` is stored as 50000.
- **Kinds.** Each feature is one of: *fix* - mends something the original plainly gets wrong;
  *rule* - a new or changed game rule that is the mod's design choice; *text* - only changes
  what a tooltip, message or effect text says; *interface* - windows, pages, map modes, input
  handling, autosaves; *infrastructure* - something mods build on; *tooling* - developer and
  reverse-engineering aids.
- **Switches.** Almost every feature is switched on by a Lua call made from the mod's
  `script/bicelib_lua.lua`, which the mod's `autoexec.lua` loads in every Lua state the game
  creates. A switch stays on for the life of the process. The overlay and everything hanging
  on it is switched by `G_ImguiUtilityEnabled` in `script/utility_settings.lua`.
- **Text.** Game and mod text is Windows-1252. Colour escapes in game text are the section
  sign followed by a letter; the parts say how they write them.
- **Sections.** Each feature section gives, in this order and omitting what has nothing to
  say: what the original does without it; what the feature does; the inputs a mod gives it;
  when it applies; multiplayer and saves; where the player sees it.

## Inventory

State: **on** - switched on in the mod as committed; **off** - the call exists in the mod but
is commented out; **off, kept** - not in use, deliberately not deleted; **abandoned** - dead;
**by hand** - nothing in the mod calls it, a developer does; **with the overlay** - present
whenever the overlay is enabled, which it is in the mod as committed
(`G_ImguiUtilityEnabled = true`); **always** - in place once the DLL is loaded.

### Fixes, rules and leaders (part 1)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| `BytePatches.fixMinisterTechDecay` | fix | on | ministers' technology-decay modifiers are added to the technology's instead of being overwritten by it |
| `BytePatches.disableWarExhaustionNeutralityReset` | rule | on | war exhaustion is zeroed monthly and never paid into neutrality at peace |
| `BytePatches.disableInterAiExpeditionaries` | rule | on | the AI's expeditions pass neither lends units nor gives loaned ones back |
| `BytePatches.historicalModelLogicFix` | fix | on | a historical model that needs unresearched technology loses to any that does not |
| `BytePatches.seaTerrainColourInSimplifiedMapMode` | interface | on | the Simplified Terrain map mode colours the sea too |
| `ComplexPatches.fixOffMapIC`, `GameInfo.getCountryOffmapIc` | fix | on | a country-level `ic` modifier counts as off-map IC; Lua can read the figure |
| `ComplexPatches.enablePlacingNonResearchedBuildings` | rule | on | a finished building may be placed without its technology; every other placing test stands |
| `ComplexPatches.fixQueuedHistoricalModel` | fix | on | a queued brigade's `historical_model` gets a level for every technology, so none shifts |
| `ComplexPatches.fixMaxInfrastructure` | fix | on | a province's maximum infrastructure stays its `infra` building's figure, whatever other infrastructure building it has |
| `ComplexPatches.customResourceConversion`, `GameInfo.getCountryResourceConversion` | rule | on | a played country sets its own daily energy-to-oil and oil-to-fuel conversion through country variables |
| `Units.setCorpsUnitLimit`, `setArmyUnitLimit`, `setArmyGroupUnitLimit` | rule | on | how many units a corps, army and army group may command, by default and per country; the mod raises it by technology |
| `Units.addCommandLimitTrait` | rule | off | leader traits that raise or lower that limit |
| `Navy.setScreenPenalty`, `setScreensPerCapitalRatio` | rule | off | a flat capital-ship penalty below a set ratio of screens, in place of the sliding scale |
| `Leaders.activateLeaderListShowMaxSkill`, `...Selected` | text | on | the leader window shows `skill (max skill)` |
| `Leaders.activateCtrlUnassignSelected` | interface | on | Ctrl on the "unassign all leaders" confirmation unassigns only the selected units' leaders |
| `Leaders.activateOobLeaderRanks` | fix | on | a leader an order of battle puts on a land unit gets that unit's rank and is put in service |
| `Leaders.activateHistoryLeaderRanks` | fix | on | a leader dated after the start enters service at the rank his history names, not rank 1 |
| `Leaders.activateRankSpecificTraits`, `addRankSpecificTrait`, `checkRankSpecificTraitsConsistency` | rule | off, kept | pairs of traits swapped as a leader's rank enters or leaves a range |
| promotion skill loss (`activateLeaderPromotionSkillLoss`) | rule | abandoned | deleted from the source; only the README still lists it |

### Texts (part 2)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| extra `$VARIABLE$` and localised-text machinery | infrastructure | always | how the text features add a variable to a line the game is building, and read a key |
| `EffectTexts.activateKillLeaderVariables` | text | on | `$UNIT$`, `$LOCATION$`, `$WHERE$` for the `kill_leader` effect's text |
| `EffectTexts.activateLoadOobDetails` | text | on | `load_oob` shows what the file would do instead of its path |
| `EffectTexts.activateTriggerIndent` | fix | on | requirement tooltips indent what is inside `and`, `or` and scopes correctly |
| `EffectTexts.activateTriggerScroll` | interface | on | a requirement tooltip taller than the screen scrolls with Alt and the arrow keys or wheel |
| `Tooltips.activateManpowerBreakdown` | text | on | the manpower tooltip's reinforcement need split by land, air and navy, with four more figures |
| `Tooltips.activateCombatUnitStats` | text | on | a unit's battle tooltip ends with its summed stats and damage dealt and taken |
| text table and tooltip font probe | infrastructure | on | aligned columns in a tooltip drawn in a proportional font |
| `Tooltips.activateParadropLine` | text | on | the division designer says whether the design can be paradropped, and which brigades stop it |
| `Tooltips.activateCombinedArmsLine` | text | on | the designer's combined-arms icons say the group's bonus and whether it is a base group |

### The command framework (part 3)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| `Commands.registerBiceCommands` | infrastructure | on | one new game command type carrying a kind and integer arguments, so mod actions can be multiplayer safe |
| `Commands.postExampleCommand`, kind "ping" | tooling | by hand | the one existing kind: logs its arguments on every machine |

### The overlay's core and what it drives (part 4)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| `Overlay.enable`, `Overlay.toggle` | interface | on | the in-game utility: windows of pages drawn over the game, opened with a key (INSERT by default) |
| Options > Utility Options | interface | with the overlay | toggle key, font size, layout reset, theme, crash report test, console buttons |
| Options > Game Settings | interface | with the overlay | the edge scrolling switch; where event popups appear (rewrites a marked line of the mod's interface file) |
| Options > Custom Auto-Saves, the custom autosaves | interface | with the overlay; each save off by default | two extra rotating autosaves: before the month changes, and by real time |
| map edge scrolling | interface | with the overlay; scrolling on by default | lets the player switch off scrolling at the screen edge |
| settings files | infrastructure | always | `BiceLibSettings.ini` and the layout file beside the DLL |
| the daily callback `BiceLibDailyPeriodics` | infrastructure | with the overlay | the DLL calls a Lua function of the mod once a game day on every machine |
| `Messages.show` | infrastructure | always; nothing in the mod calls it | one of the game's own message popups with the caller's text |
| `Events.rebuildCandidates` | fix | on, once per Lua state (unreached until 2026-11-20) | rebuilds the event candidate lists a load leaves empty |
| `require "BiceLib"`, `startConsole`, `stopConsole`, `setModuleBase` | tooling | on; console off | loading the module; the debug console |
| text encoding | infrastructure | always | game text is converted from Windows-1252 where it is read |
| localisation lookup | infrastructure | always | the DLL's own read of a localisation key |

### Pages: Setup and Country Info (part 5)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| shared: selected country, page-to-Lua contract, pending changes | interface | with the overlay | what every page of these groups relies on |
| Setup > Country | interface | with the overlay | chooses the country the pages report on; lists players; shows the daily callback's result |
| Setup > Special | interface | with the overlay | moves unit animation files into a backup folder and back |
| Setup > Misc | interface | with the overlay | hides two groups of the mod's decisions |
| Country Info > Country Modifiers | interface | with the overlay | the mod's computed country figures, off-map IC and general modifiers |
| Country Info > IC Days | interface | with the overlay | the mod's IC-days account |
| Country Info > Puppets | interface | with the overlay | each puppet's focus, settable |
| Country Info > Strategic Res. | interface | with the overlay | the mod's strategic resources: production, use, balance |
| Country Info > Resource Conversion | interface | with the overlay | sets the eight conversion variables; shows today's caps |
| Country Info > Strategic Trades | interface | with the overlay | the country's strategic resource trades |
| Country Info > Global Market | interface | with the overlay | who has spare production of a strategic resource |
| Country Info > National Focus | interface | with the overlay | the national focus, settable, with its effects |
| Country Info > Minister Buildings | interface | with the overlay | progress to the next building each minister places |
| shared: the staged form of the AI pages | interface | with the overlay | stage, apply and activate a block of AI settings variables |
| Country Info > Trade AI | interface | with the overlay | custom limits for the mod's trade AI |
| Country Info > Prod. Sliders AI | interface | with the overlay | custom priorities for the mod's production slider AI |
| Country Info > LS Sliders AI | interface | with the overlay | custom bounds for the mod's leadership slider AI |

### Pages: Game Info, Inspector lists, Stats, Help; game-info reads (part 6)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| shared conventions | interface | with the overlay | bridge, reported country, list widget, formats |
| Game Info > Traits | interface | with the overlay | every leader trait of the mod with its effects |
| Game Info > Generals | interface | with the overlay | the country's leaders from their files, with their state in the running game |
| Game Info > Modifiers | interface | with the overlay | the mod's event and triggered modifiers with their effects |
| Game Info > Techs | interface | with the overlay | every technology with its effects at a chosen level |
| Game Info > Units | interface | with the overlay | unit statistics with technology applied, and a what-if calculator |
| Game Info > Unit Models | interface | with the overlay | the country's unit models, their technology needs, their sprite |
| Inspector > Active Flags | interface | with the overlay | the country's flags, read from game state |
| Inspector > Active Variables | interface | with the overlay | the country's variables, read from game state |
| Inspector > Active Event Modifiers | interface | with the overlay | the country's timed modifiers and their expiry |
| Stats > Setup | interface | with the overlay | switches the mod's statistics collection and edits its country list |
| statistics collection (mod Lua) | tooling | off until the player switches it on | daily figures per country appended to text files |
| Stats > Statistics | interface | with the overlay | plots the collected series |
| Help > Misc, Ministers + Buildings, National Focus | interface | with the overlay | the mod's help text |
| `GameInfo.getCountryFlags` | infrastructure | always | a country's flags |
| `GameInfo.getCountryVariables` | infrastructure | always | a country's variables, in thousandths |
| `GameInfo.getCountryActiveEventModifiers` | infrastructure | always | a country's timed modifiers with expiry dates |
| `GameInfo.getCountryGeneralModifiers` | infrastructure | always | every modifier kind's total in the country's global modifier |
| `GameInfo.getProvinceDetails` | infrastructure | always | a province's pools, production and local modifiers |
| `Leaders.getLeaderDetails` | infrastructure | always | one leader's state in the running game |
| `Leaders.addTraitToLeader` | infrastructure | always; nothing in the mod calls it | gives a leader a trait through the game's own routine |
| `Inspector.getSelectedEntity` | infrastructure | always | what the player has selected, with unit statistics |

### Inspector: map mode, combat record, order of battle (part 7)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| Inspector > Custom Mapmode, the custom map mode | interface | with the overlay; off until ticked | the Victory Points map mode repainted by a chosen building level, resource or supply figure |
| manpower and leadership in the Resources map mode tooltip | text | with the custom map mode's hooks | two more lines in that tooltip |
| the combat record | infrastructure | with the overlay | every finished combat captured and kept per campaign in files |
| Inspector > Combat Reports | interface | with the overlay | the record by period, kind and country, with detail |
| order of battle read | infrastructure | with the overlay | a country's whole order of battle read from game state |
| Inspector > OOB Browser | interface | with the overlay | the order of battle as a tree with unit details |
| Inspector > OOB Report | interface | with the overlay | the order of battle counted |
| Inspector > Unit Inspector | interface | with the overlay | the selected units' statistics and terrain modifiers |
| Inspector > Province Buildings | interface | with the overlay | where the country has a chosen building, with province details |

### Tooling (part 8)

| feature | kind | state | one line |
| --- | --- | --- | --- |
| guarded reads of game state | infrastructure | always | a read that fails yields nothing instead of a crash |
| crash report | tooling | with the overlay | a text report and a minidump when the process crashes |
| crash save | tooling | with the overlay | save the game, say why, close it - once |
| out-of-memory watch | tooling | with the overlay | reacts with a crash save when free address space runs low |
| pure-call handler | tooling | with the overlay | turns the runtime's "pure virtual function call" abort into a crash save |
| Diagnostics | infrastructure | always | which thread draws, which Lua state it uses |
| Debug > Thread Check, Memory, Lua Console, Timing, and a virtual-call probe page | tooling | with the overlay | developer pages |
| warm-up (`G_ImguiWarmupEnabled`) | interface | on | parses the mod's files a set per frame at the main menu |
| `Reversing.activateCounters` | tooling | off | counts how often the game reaches named code locations |
| `Reversing.activateWatch` | tooling | off | logs changes of named game-state fields |
| `Reversing.watchWrite`, `watchCombatModifiers`, `watchSubunit`, `stopWatching` | tooling | by hand | finds which code writes a field |
| `Reversing.probeMessages` | tooling | by hand | prints what the game passes when it posts a message |

## Part 1 - Fixes, rules and leaders

### What every switch in this part has in common

Kind: infrastructure
Switch: each feature below is switched on by one Lua call, made by the mod's `script/bicelib_lua.lua` at its top level.

**How a switch behaves** - `script/bicelib_lua.lua` is required by the mod's `autoexec.lua` in every Lua state the game creates, and its top-level block makes every call again each time. Every switch is therefore written to be called repeatedly: the first call that succeeds puts the feature in place for the rest of the process, and later calls do nothing and answer true. (source)

- **Process-wide, not per game.** A feature stays on from the call until the game exits: across the main menu, every load, every new game. None of the features in this part can be switched off again, except where a section says so. (source)
- **Checked before anything is changed.** Each feature first verifies that the game code it stands on is exactly the code of the one executable it was written for; if not, it changes nothing, prints an error line to the debug console and answers false. The five "byte patches" also accept code that already carries the change (an executable patched on disk) and count that as done. A feature is never left half applied by a failed check. (source)
- **Return value.** Every switch returns a boolean - true when the feature is in place - except the `BiceLib.Units` and `BiceLib.Navy` setters, which return nothing on success and false only when their hook could not be installed. The README documents no return value for most of them. (source)
- **Same on every machine.** The mod's Lua is the same on every machine of a multiplayer game, so every machine has the same switches on. Every rule in this part reads only game state that all machines hold alike and runs inside passes all machines run, unless its section says otherwise. A game in which one player ran a different BiceLib, or different switches, would diverge. (source for the mechanism; comment for the claim that it holds in play, except where a section records a test)
- **Nothing here is stored in the savegame** beyond what the game itself stores. Where a feature keeps figures of its own outside the save, its section says what is lost or rebuilt on a load.

Figures called "thousandths" are the game's fixed-point numbers: `12050` is 12.050.

### `BiceLib.BytePatches.fixMinisterTechDecay()`

Kind: fix
Switch: `BiceLib.BytePatches.fixMinisterTechDecay()`

**What the original does without it** - each country holds, per technology category (the practical and theory categories), a "technology decay modifier" in thousandths. Once a month every category's level decays by `step = BASE_TECH_DECAY x (1000 + decay modifier of the category) / 1000`, further scaled by the country's research slack and never above 0; the level becomes `level x (1000 + step) / 1000` (reversing/findings/FINDINGS-techdecay.md, section 2). The modifier is made again whenever the country's static modifiers are rebuilt, in three steps: (1) every category's figure is set to 0; (2) for every minister in the cabinet, the minister's figure for each category is added; (3) for every category, the figure the country's technology status holds for it (what researched technologies give) is **stored over** the result. Step 3 throws step 2 away, so a minister's decay modifier never has any effect (reversing/findings/FINDINGS-bicelibsites.md, section 4). (comment, findings)

**What the feature does** - step 3 adds instead of storing. The modifier of a category is then the sum of every cabinet minister's figure for it plus the technology status's figure. Because step 1 still zeroes first, nothing accumulates from one rebuild to the next. Nothing else about decay changes. (source)

**Inputs a mod gives it** - none to the call. It makes the per-category decay modifiers on minister types in `common/ministers.txt` (and whatever else feeds a minister's figures) take effect. (comment)

**When it applies** - once per process; at the next rebuild of each country's static modifiers after the call. Cannot be switched off.

**Multiplayer and saves** - inside the modifier rebuild every machine runs, from the cabinet and the technology status alone. Nothing kept outside the save: the figure is derived and rebuilt.

**Where the player sees it** - indirectly: the monthly loss of practical and theoretical knowledge changes with the ministers in office.

### `BiceLib.BytePatches.disableWarExhaustionNeutralityReset()`

Kind: rule
Switch: `BiceLib.BytePatches.disableWarExhaustionNeutralityReset()`

**What the original does without it** - in each country's monthly pass: war exhaustion goes up by the country's `war_exhaustion` modifier value (the `war` static modifier gives 0.041 a month in the base game), is floored at 0 and capped at the country's maximum-war-exhaustion modifier (100). Then, if the country is at peace and its war exhaustion is above 0, the whole figure is added to the country's neutrality and war exhaustion is set back to 0 (reversing/findings/FINDINGS-diplostate.md; reversing/findings/FINDINGS-bicelibsites.md, section 5). (findings)

**What the feature does** - two changes in that monthly pass (source):

1. where the month's amount was added and floored, the country's war exhaustion is instead **set to 0**;
2. the reset to 0 after the hand-over to neutrality is removed (it can no longer be reached with anything to reset).

Because the figure is 0 when the peace test is made, nothing is ever handed to neutrality. The consequence is wider than the function's name: **war exhaustion no longer accumulates at all** - every country's figure is 0 after each monthly pass, including a figure a new game or an effect gave it earlier in the month, and so the `war_exhaustion` static modifier, which the game scales by that figure, does nothing from the first monthly pass on. The README describes only the neutrality part ("For Black ICE we don't want that"). (source for the two changes; the consequence is read off them and the findings)

**Inputs a mod gives it** - none.

**When it applies** - once per process; from the next monthly pass. Cannot be switched off.

**Multiplayer and saves** - inside the monthly pass every machine runs. Nothing kept outside the save.

**Where the player sees it** - neutrality no longer jumps up in the first month of peace after a war; war exhaustion reads 0.

### `BiceLib.BytePatches.disableInterAiExpeditionaries()`

Kind: rule
Switch: `BiceLib.BytePatches.disableInterAiExpeditionaries()`

**What the original does without it** - each AI-run country's unit AI has an expeditions pass with two branches (reversing/findings/FINDINGS-power.md, "expeditions, both directions"; reversing/findings/FINDINGS-agents.md, section C.7). *Give back*: a unit it holds on loan is returned to its owner unless the owner is a government in exile, a person plays the owner, the unit is under a blocking order, or an area test says to keep it. *Lend*: a unit of its own that stands in a province controlled by another country of the same faction (two countries with no faction also pass), not at war with it, is a leaf of the order of battle, and passes the same area test, is handed to that controller as an expeditionary force. Both are done by posting the game's send-expedition command, which toggles the unit's expeditionary owner. (findings)

**What the feature does** - one conditional skip in each branch is made unconditional, so the AI's pass leaves both branches without posting anything: **an AI country never lends a unit through this pass and never gives a loaned one back through it** (source: two conditional jumps turned into plain jumps; which condition each belonged to was not re-read for this document). The README states the purpose: AI countries lent most of their army to allies that did not need it, especially to a freshly released puppet, and did not recall it. Expeditionary forces a player sends or returns by hand, and the game's other routes home (for example on a war's end), are not touched. (readme for the purpose)

**Inputs a mod gives it** - none.

**When it applies** - once per process; from the AI's next pass. Cannot be switched off.

**Multiplayer and saves** - the AI's passes post commands on the machine that runs the AI; the change removes commands and adds none. Nothing kept outside the save. Units already on loan in a save stay on loan.

**Where the player sees it** - AI allies no longer hand units to each other (or, through this pass, to a player's country).

### `BiceLib.BytePatches.historicalModelLogicFix()`

Kind: fix
Switch: `BiceLib.BytePatches.historicalModelLogicFix()`

**What the original does without it** - when a unit is built or shown, the game picks which historical model (an entry of `units/models`, a set of technology levels for a unit type) fits the country. For every model of the type it adds up, over the technologies that model names, `|level the country has researched - level the model asks for| x 1000`, and takes the model with the smallest total. Because the difference is taken as an absolute value, a model asking for one level *more* than the country has scores exactly like a model asking for one level *less*, so a country can be handed a model it has not researched. (comment)

**What the feature does** - for a technology where the model asks for **more** than the country has researched, the term added is a flat 1,048,576 instead of the difference times 1000. A term where the model asks for the same or less is unchanged. So any model that needs something unresearched loses to every model that does not, and among models that all need something unresearched the one with the fewest such technologies wins (each costs the same flat amount, whatever the gap). (source)

**Inputs a mod gives it** - none; it acts on the mod's `units/models` files.

**When it applies** - once per process; wherever the game picks a model afterwards. Cannot be switched off.

**Multiplayer and saves** - a pure function of the country's technology and the models. Nothing kept.

**Where the player sees it** - the model name and picture of units in the production screen and of built units.

### `BiceLib.BytePatches.seaTerrainColourInSimplifiedMapMode()`

Kind: interface
Switch: `BiceLib.BytePatches.seaTerrainColourInSimplifiedMapMode()`

**What the original does without it** - the Simplified Terrain map mode works out a colour for every province, the 3,547 sea provinces included, but the sea is drawn plain: the water is drawn by an effect of its own that exists in two forms, and only the form compiled with province colours samples the province colour textures. Which form is used, and whether the sea's colour texture is filled at all, follows one "map style" number each map mode writes into the graphics settings; only the styles of the Air and Naval map modes select the coloured water. Simplified Terrain writes a style that does not (reversing/findings/FINDINGS-mapmode.md). (comment)

**What the feature does** - the Simplified Terrain map mode writes the Air map mode's style number instead of its own. The sea is then drawn in the colours the mode already computes. Only this map mode's setter is changed; Infrastructure, which writes the same plain style from a setter of its own, keeps plain water. (source)

**Inputs a mod gives it** - none; the colours are the terrain colours the mode already uses.

**When it applies** - once per process; the next time the Simplified Terrain map mode is selected. Cannot be switched off.

**Multiplayer and saves** - display only, local.

**Where the player sees it** - the map, in the Simplified Terrain map mode.

### `BiceLib.ComplexPatches.fixOffMapIC()` and `BiceLib.GameInfo.getCountryOffmapIc(tag)`

Kind: fix
Switch: `BiceLib.ComplexPatches.fixOffMapIC()`

**What the original does without it** - once a day per country, the game's IC routine sums over the country's provinces `province IC x (1000 + province LOCAL_IC) / 1000`, where both figures are entries of the province's own modifier in thousandths (a province with a negative result adds nothing). The sum, cut to whole IC, becomes the country's IC before the global IC modifier, lend-lease and the resource cap are applied. **The country's own `IC` modifier entry is never read**: an `ic = N` in an event modifier, a triggered modifier or any other country-level modifier does nothing (reversing/findings/FINDINGS-ic.md, "The offmap IC fix"). (findings)

**What the feature does** - makes the country-level `IC` modifier entry count, as "off-map IC" (source):

1. While the provinces are summed, for each province the difference between its term and its plain `IC` entry - what `LOCAL_IC` added, in thousandths - is added to a running figure kept per country (`local`).
2. When the sum (whole IC) is about to be stored as the country's IC:
   - `withoutLocal = sum - local / 1000` (integer division toward zero), and `local` is cleared for the next day;
   - `offmap = (the country's global modifier IC entry) / 1000 - withoutLocal`, in whole IC - that is, whatever the country's `IC` entry holds beyond the plain IC of its provinces;
   - `offmap` is remembered for the country (this is what `getCountryOffmapIc` returns) and **written back into the country's `IC` modifier entry** as `offmap x 1000`;
   - the figure stored as the country's IC is `sum + offmap`.

   The game then carries on with that figure exactly as before: global IC modifier, lend-lease, resource cap.

Edge cases as coded: a country whose id is outside 0 to 299, or whose modifier cannot be read, is left to the game untouched; `offmap` may be negative, and is added all the same; the per-country figures live in a table indexed by country id. The arithmetic assumes the country's `IC` entry, as the modifier rebuild leaves it, includes the plain IC of the country's provinces - the code subtracts them to find the remainder - and that the entry is rebuilt before each day's pass, since the routine overwrites it with the remainder alone. Neither assumption was verified for this document. (source; the assumptions are inference)

`BiceLib.GameInfo.getCountryOffmapIc(tag)` returns the `offmap` figure of the last daily pass as an integer (whole IC), 0 for a country no pass has reached yet or with the fix off, and nil for a tag that names no country. (source)

**Inputs a mod gives it** - `ic = <number>` in country-level modifiers (event modifiers, triggered modifiers, and the like). The mod's `utility_data/bicedata_countryinfo.lua` reads `getCountryOffmapIc` for the overlay's Country Modifiers page.

**When it applies** - once per process; from each country's next daily IC pass. Cannot be switched off.

**Multiplayer and saves** - inside the daily pass every machine runs, from the country's own figures. The remembered `offmap` and the running `local` figures are outside the save and are rebuilt by the first daily pass after a load; until then `getCountryOffmapIc` answers what the previous game left (the table is not cleared on a load).

**Where the player sees it** - the country's IC in the top bar and production screen; the off-map figure itself on the overlay's Country Modifiers page.

### `BiceLib.ComplexPatches.enablePlacingNonResearchedBuildings()`

Kind: rule
Switch: `BiceLib.ComplexPatches.enablePlacingNonResearchedBuildings()`

**What the original does without it** - a finished building waiting in the deployment queue may be placed in a province only if the country's "is this building allowed here" test passes. That test refuses, in this order: (1) a building the country has not been given by research; (2) a province the country does not control (the underground excepted); (3) a province where the levels already there plus the levels queued for it reach the building's `max_level`; (4) a port building in a province without a port; (5) the building's `not_if_x_exists` rule; (6) a missing prerequisite building. So a building an event hands to a country that has not researched it can never be placed (reversing/findings/FINDINGS-bicelibsites.md, sections 7 and 7.1). (comment, findings)

**What the feature does** - while the question is asked **for placing a finished building**, test (1) passes outright; tests (2) to (6) are asked as always. Every other caller of the same test - ordering a building in the production screen, the Lua API's answer to the AI, and the rest - gets the game's answer unchanged, research included. (source)

Until 2026-11-07 the feature asked much less (only whether the level in the province was below `max_level`) and so also let a building into provinces the country did not control, past `max_level` counting queued levels, and without port or prerequisites; that is no longer so. (comment)

**Inputs a mod gives it** - none to the call. The mod's events that add buildings to a country's deployment queue rely on it.

**When it applies** - once per process. Cannot be switched off.

**Multiplayer and saves** - the waiver is in force only while the placing test itself runs, on whichever machine runs it, and nothing local decides it. Nothing kept.

**Where the player sees it** - the deployment menu and the map: provinces offered for a building the country has not researched.

### `BiceLib.ComplexPatches.fixQueuedHistoricalModel()`

Kind: fix
Switch: `BiceLib.ComplexPatches.fixQueuedHistoricalModel()`

**What the original does without it** - a brigade of a `military_construction` line in an order of battle may carry `historical_model = N`. Reading it, the game walks the technologies of the brigade's unit type in order and, for each one **the model names**, appends that technology's level to the line's list of levels; for a technology the model does not name it appends nothing. When the brigade is built the list is handed out by position, first entry to the type's first technology and so on. So every level after a technology the model leaves out lands on the technology before the one meant, and the type's last technologies get none. Most models in `units/models` leave technologies out. A unit placed directly on the map with the same model is given its levels by technology, not by position, and is right (reversing/findings/FINDINGS-buildqueue.md, section 10). (comment)

**What the feature does** - for a technology of the unit type that the model does not name, a level of 0 is appended. The list then has exactly one entry per technology of the type, in the type's order, so each level is built on the technology it belongs to, and an unnamed technology is built at level 0 - the same as the model gives a unit placed on the map. (source)

**Inputs a mod gives it** - none; it acts on `historical_model` in `military_construction` blocks. The mod's validator reports the shift (its checks BV218 and BV219) and stays quiet when it finds this call in `bicelib_lua.lua`. (comment in the mod's Lua)

**When it applies** - once per process; whenever such a line is read afterwards (a new game's history, `load_oob`). It must be on before the files are read; lines read earlier keep their shifted lists. Cannot be switched off.

**Multiplayer and saves** - a pure function of the file and the models, at load. The list is part of the queue line and is saved by the game as it stands.

**Where the player sees it** - the equipment levels of brigades that come out of a scripted production line.

### `BiceLib.ComplexPatches.fixMaxInfrastructure()`

Kind: fix
Switch: `BiceLib.ComplexPatches.fixMaxInfrastructure()`

**What the original does without it** - every province holds a "maximum infrastructure" figure in thousandths. It is what the supply areas are made from - a province belongs to an area only when the figure is above 100, that is above one level - and areas are what the supply network groups and what the AI's theatres and fronts are built on. The game writes the figure in three places: when a saved province's buildings are read, when the building effect sets a building's level, and when a construction finishes. In each it writes `the building's built level x the building's "infrastructure" effect figure / 1000` for **whichever building with the `infrastructure` effect it is handling at that moment**, with no comparison against what is there. With one such building, as in the base game, that is harmless. BlackICE has a second, `extra_infra` (`infrastructure = 0.05`), saved after `infra` in every province, so a loaded province held `extra_infra`'s level x 50: Shanghai, with `infra` 8, came back as 50. Areas are made from scratch only as a game is entered, so after a load 1,603 provinces of a 1937 save were in no area at all (no supply grouping, no AI front), and the AI's daily sealift pass, reading the first province of the empty area for a unit bound for such a province, crashed the game as the save loaded (reversing/findings/FINDINGS-extrainfra.md). (comment)

**What the feature does** - at each of the three writes, straight after the game's own write, the figure is replaced by that of the province's building named exactly `infra`: `infra's built level x infra's effect figure / 1000`, in 64-bit arithmetic, cut toward zero - the game's own formula. A province that holds no `infra` entry keeps the game's figure, as does every province if no building is called `infra` (an error line is printed once). In the building-effect path the game goes on to test the new figure to decide whether a province in no area joins one; it is given the corrected figure. `extra_infra`'s bonus to *effective* infrastructure is not touched: the game works that out separately from the province's modifiers. (source)

"Built level" is the building's level as built (its maximum level in the province), not the level currently working after damage. (source)

**Inputs a mod gives it** - none to the call; it expects the base infrastructure building to be called `infra`, found by name the first time one of the three writes is reached and remembered for the process.

**When it applies** - once per process, and **it must be on before a save is loaded** (or a new game's provinces are set up): it corrects the figure only as the game writes it, and repairs nothing already written. Cannot be switched off.

**Multiplayer and saves** - it reads only the province's own buildings, inside the load and the effects every machine runs. Nothing kept outside the save. The savegame is unchanged in format; the figure is derived on load.

**Where the player sees it** - no screen of its own: supply areas, the AI's fronts and a crash on load that no longer happens.

### `BiceLib.ComplexPatches.customResourceConversion()` and `BiceLib.GameInfo.getCountryResourceConversion(tag)`

Kind: rule
Switch: `BiceLib.ComplexPatches.customResourceConversion()`

**What the original does without it** - both conversions run once a day in each country's daily pass, energy first, and are hard-coded except for the yields (reversing/findings/FINDINGS-distribute.md, sections 4 and 6) (comment):

- *Energy into crude oil*: at most `max(0.05 x IC, 1)` crude oil a day, each costing `1 / rate` energy, where `rate` (crude oil per energy) is a base of 0.1 plus the country's technology bonus; only towards holding twice as much energy as crude oil; never out of the `2 x IC` energy that industry needs that day; nothing at a rate of 0 or below.
- *Crude oil into fuel*: `IC / 2` crude oil a day, unless fuel is at 99,000, or fuel is above a year of the crude oil coming in and above twice the crude oil held. The fuel made per crude oil follows technology and the `FUEL_CONVERSION` modifier.

In BlackICE energy into crude oil starts closed: every country's history gives it the modifier `hidden_coal_to_oil_base_counter` (`energy_to_oil_conversion = -1`), so the rate is 0.1 - 1 = -0.9; `hidden_coal_to_oil_activate` adds 1 back, and only events 48998 (the synthetic industry) and 93673 (Germany's Four Year Plan) give it. (comment)

**What the feature does** - for a country that **a person plays** and that has switched a conversion on through a country variable, the decision of how much to convert that day is taken from the country's variables. Everything else stays the game's own code: moving the goods, the two conversion ledgers the statistics and tomorrow's figures read, the yields, the spreading of the fuel over the capital's area. A country nobody plays, a played country that has not switched a conversion on, and both conversions when the feature is off, convert exactly as the game does. "Played" is the game's own test, the one the `ai` trigger asks. (source)

All eight variables are read in thousandths, like every country variable (`set_variable = { which = X value = 50 }` stores 50000 and means 50 a day). A negative value reads as 0. (source)

| variable | meaning |
| --- | --- |
| `zzDsafe_usesCustomOilConversion` | not 0: energy into crude oil follows the next three |
| `zzDsafe_CustomConversion_energyPerDay` | energy to spend a day; 0 converts nothing |
| `zzDsafe_CustomConversion_energyKeep` | never take the energy stockpile below this; 0 is no extra limit |
| `zzDsafe_CustomConversion_oilTarget` | convert only while crude oil held is below this; 0 is no target |
| `zzDsafe_usesCustomFuelConversion` | not 0: crude oil into fuel follows the next three |
| `zzDsafe_CustomConversion_crudePerDay` | crude oil to refine a day; 0 refines nothing |
| `zzDsafe_CustomConversion_crudeKeep` | never take the crude oil stockpile below this; 0 is no limit |
| `zzDsafe_CustomConversion_fuelTarget` | refine only while fuel held is below this; 0 is no target |

Nought has to mean "off" or "no limit" because a save drops a variable that is exactly 0 and a missing variable reads 0. (comment)

*Energy into crude oil, for a played country with the switch on* (source). `IC` is the country's whole IC as the routine has just worked it out; stockpile figures are those of the country's stockpile (the acting capital's pool, or the exile pool for a government in exile); everything else is in thousandths; divisions are integer divisions toward zero.

1. If the day's effects are not being applied (the game also runs this routine without them), convert nothing.
2. If the country has no stockpile or no technology status, convert nothing.
3. If `oilTarget > 0` and crude oil held `>= oilTarget`, convert nothing.
4. `floor = max(2000 x IC, energyKeep)`; `spare = energy held - floor`. If `spare <= 0`, convert nothing.
5. `rate = base rate + technology bonus` (the base is read from the game, 100, a tenth). If `rate <= 0`, convert nothing - BlackICE's closed gate stays closed.
6. `per = max((1000000 + rate / 2) / rate, 1000)` - the energy one crude oil costs, rounded to nearest, never below 1.
7. `cap = max(50 x IC, 1000) x per / 1000` - the game's own most, `max(0.05 x IC, 1)` crude oil, expressed as energy.
8. `spend = min(energyPerDay, cap, spare)`; `made = spend x rate / 1000`. If `spend <= 0` or `made <= 0`, convert nothing.
9. Otherwise the game's own writes are run with `spend` energy taken and `made` crude oil added.

So the game's "only towards twice as much energy as crude oil" rule does not apply to such a country; the `2 x IC` floor, the capacity and the rate do. The floor is kept because the game's resource cap, a few steps later in the same routine, cuts that day's IC by one for every two energy short, without telling anyone. (source; comment for the reason)

*Crude oil into fuel, for a played country with the switch on* (source):

1. If fuel held `>= 99,000`, refine nothing (the game's own stop, kept).
2. If `fuelTarget > 0` and fuel held `>= fuelTarget`, refine nothing.
3. `cap = (IC / 2) x 1000` - half the IC, halved toward zero, in whole crude oil.
4. `spend = min(crudePerDay, cap, crude oil held - crudeKeep)`. If `spend <= 0`, refine nothing.
5. Otherwise the game's own writes are run with `spend` crude oil: yield by technology and `FUEL_CONVERSION`, and the fuel spread as the game spreads it.

The game's second stop (a year of incoming crude oil and twice the crude oil held) does not apply to such a country. (source)

`BiceLib.GameInfo.getCountryResourceConversion(tag)` returns nil when the feature is not on, the tag names no country, or the country has no technology status; otherwise a table of what the country may convert today, worked out by the same arithmetic and divided by 1000 (source):

| key | type | meaning |
| --- | --- | --- |
| `oil_rate` | number | crude oil one energy makes (step 5 above); may be 0 or negative |
| `energy_cap` | number | the most energy that may be spent a day (step 7); 0 when the rate is 0 or below |
| `energy_floor` | number | `2 x IC`, the energy industry needs, never converted |
| `crude_cap` | number | the most crude oil that may be refined a day (`IC / 2`, whole) |
| `played` | boolean | whether a person plays the country |

**Inputs a mod gives it** - the eight variables. In BlackICE they are set three ways: by events 1553 to 1555, reached from the covert operation `set_resource_conversion` in the player's capital (presets; described with the overlay's Resource Conversion page); by that overlay page (any value); or by any event or decision of the mod. The modifiers `hidden_coal_to_oil_base_counter` and `hidden_coal_to_oil_activate` are the mod's gate on the energy side.

**When it applies** - once per process; from each country's next daily pass. Settings made while the energy gate is closed wait and apply from the day it opens. Cannot be switched off; a country returns to the game's rule by setting its `uses` variable to 0.

**Multiplayer and saves** - every machine runs the daily pass, and the decision reads only what all hold alike: the variables, who plays which country, the stockpile, the IC and the technology; integer arithmetic only. The variables are set by events and decisions, which run everywhere, or by the game's set-variable command, which is broadcast (comment). The settings are ordinary country variables and are saved with the game; nothing is kept outside it. A country that passes from a player to the AI (or back) changes rule from the next daily pass.

**Where the player sees it** - the stockpile and the daily resource ledger; the settings on the overlay's Resource Conversion page and in the covert operation's events.

### `BiceLib.Units.setCorpsUnitLimit`, `setArmyUnitLimit`, `setArmyGroupUnitLimit`, `addCommandLimitTrait` - how many units a command may hold

Kind: rule
Switch: the first call of any of the four installs the feature; the mod calls the three setters with the default tag in `bicelib_lua.lua` and per country from `CheckOobUnitLimitTechnologyStatus`.

**What the original does without it** - the game's test of whether a land unit may be put under a commander (asked by the attach buttons and lists, by drag and drop in the order of battle, and by the AI) refuses when the unit's level is not below the commander's, and - for a land commander of any level but theatre - when the commander **already has five subordinates** (the unit itself not counted if it is already one of them). Five is hard-coded. A theatre has no limit (reversing/findings/FINDINGS-attachbuttons.md; reversing/findings/FINDINGS-bicelibsites.md, section 6). (findings)

**What the feature does** - the five is replaced by a limit worked out each time the test is made. The test passes while `subordinates already counted < limit`. (source)

1. If the unit to attach is a **lone brigade** - a division-level unit holding exactly one brigade - the limit is 999: it may always be attached.
2. Otherwise start from the base: the commander's level picks one of three figures - army group, army or corps. For that level, the figure set for the **country that owns the unit being attached** is used if it is not 0; otherwise the default for the level. A commander of any other level starts from 5. All defaults are 5 until set.
3. Add the effect of every command-limit trait the commander's leader holds (each registered trait name adds its number, which may be negative; a trait held twice counts twice). No leader, no addition.
4. Add the number of lone brigades already under the commander, so that they do not use up places.

A commander with no subordinates at all always accepts (the game answers before counting). The limit can be exceeded in ways the game allowed before - by lowering it afterwards, or, as the README notes for traits, by assigning a leader with a positive trait, attaching, and unassigning him: nothing is detached when a limit falls. (source; readme for the last remark)

**Inputs a mod gives it** (source)

- `setCorpsUnitLimit(limit, tag)`, `setArmyUnitLimit(limit, tag)`, `setArmyGroupUnitLimit(limit, tag)`: `limit` an integer; `tag` either `"---"`, which sets the default for the level, or a country tag, which sets that country's own figure (0 puts the country back on the default). An unknown tag is ignored silently. Countries are held by their numeric id, up to 300.
- `addCommandLimitTrait(traitName, effect)`: registers a leader trait by its exact name with an integer effect. A name registered twice keeps its first effect. The name is not checked against the game's traits.
- The mod's contract: `G_BASE_COC_LIMIT` (4 in `script/ai_globals.lua`) is the default for all three levels. `CheckOobUnitLimitTechnologyStatus(skipDayCheck)` in `script/ai_variable.lua` then sets every existing country's three figures: starting from `G_BASE_COC_LIMIT` at each level, it adds for each of these technologies the listed amount once the country's level of it has reached the listed level:

| technology | level reached | adds | to |
| --- | --- | --- | --- |
| `Corps_command_structure_BK` | 2, and again at 4 | 1 each | corps |
| `army_HQ_DB` | 4 | 2 | army |
| `army_group_HQ_DB` | 3 | 1 | army group |
| `army_command_structure_grand_battle` | 2, and again at 4 | 1 each | army |
| `armygroup_command_structure_grand_battle` | 2, and again at 4 | 1 each | army group |
| `corps_HQ_SF` | 4, and again at 5 | 1 each | corps |
| `army_HQ_SF` | 4, and again at 5 | 1 each | army |

  It runs only when the day of the month is divisible by 5, unless called with `true`. It is called from the mod's intelligence-minister tick (on the machine that runs the AI scripts; once with `true` on the first such tick of a Lua state, through `RunBiceLibPeriodicsManually`), and from `BiceLibDailyPeriodics`, which the DLL itself calls once a game day on every machine - with `true` on the first day after a load - precisely because a multiplayer client runs none of the scheduled scripts and would otherwise keep the defaults. No command-limit trait is registered in the mod as committed (the two example calls are commented out).

**When it applies** - installed by the first setter call, process-wide. The figures are plain memory: they are set again by the mod's Lua at each load of the script and by the daily callback. Cannot be switched off, but setting every figure to 5 and registering no trait restores the game's rule except for the lone-brigade allowances.

**Multiplayer and saves** - the test reads only the units and the limits. The limits are **not in the savegame** and are not sent between machines: every machine must compute the same figures, which the mod arranges by running the same script on the same days everywhere through the daily callback. After a load every country is on the default until the first daily callback (which passes `firstDay = 1` and so sets them at once). The per-country table is not cleared between games in one process. (source)

**Where the player sees it** - wherever a unit is attached: the attach list of a unit's panel, the order of battle browser, drag and drop.

### `BiceLib.Navy.setScreenPenalty(penalty)` and `setScreensPerCapitalRatio(ratio)`

Kind: rule
Switch: either call installs the feature. **Off in the mod**: both calls are commented out in `bicelib_lua.lua`.

**What the original does without it** - in a naval battle each fleet's ships are counted: `capitals` (ships whose type is flagged as a capital ship) and `screens` (ships whose type carries the unit files' warship flag and is not a transport, as the findings name the flags). If there is at least one capital ship and `screens < capitals`, every capital ship of the fleet gets a defence-only combat penalty of `(1 - screens / capitals) / 3` - a sliding scale reaching 33.3% with no screens at all (reversing/findings/FINDINGS-combatmods.md, section 6). (findings)

**What the feature does** - the sliding scale is replaced by a flat figure: if `screens < capitals x ratio`, the penalty is `penalty`; otherwise there is none. It is applied where the game applied its own (to capital ships, to defence). With a fleet without capital ships the game never reaches the test. Defaults until set: `penalty` 333 (thousandths, 33.3%), `ratio` 1. (source)

**Inputs a mod gives it** - `setScreenPenalty(penalty)`: integer thousandths. `setScreensPerCapitalRatio(ratio)`: integer screens wanted per capital ship. **Each figure can be set once per process; later calls for the same figure are ignored.** No range check is made on either. (source)

**When it applies** - process-wide from the first call; from the next hour of naval combat. Cannot be switched off.

**Multiplayer and saves** - inside the combat every machine runs, from the fleets and two constants set by the same script everywhere. Nothing saved.

**Where the player sees it** - the poor-screen penalty among a capital ship's modifiers in a naval battle.

### `BiceLib.Leaders.activateLeaderListShowMaxSkill()` and `activateLeaderListShowMaxSkillSelected()`

Kind: text
Switch: either call; each installs both places.

**What the original does without it** - the leader assignment window shows a leader's skill as a bare number in two places: on each row of the list of available leaders, and for the leader currently on the unit. A leader's maximum skill, which caps what experience can give him, is shown nowhere (reversing/findings/FINDINGS-bicelibsites.md, section 3). (comment)

**What the feature does** - in both places the text becomes `<skill> (<max skill>)`, for example `3 (5)`: the two integers in decimal, one space, parentheses, no colour. For an entry that is not a real leader (the game's "no leader" placeholder) the game's own text is kept. (source)

**Inputs a mod gives it** - none. No localisation key is involved.

**When it applies** - once per process; the next time the window builds its rows. Cannot be switched off.

**Multiplayer and saves** - display only; nothing of the game's state is written.

**Where the player sees it** - the leader assignment window, in the skill column of the list and beside the selected leader.

### `BiceLib.Leaders.activateCtrlUnassignSelected()`

Kind: interface
Switch: `BiceLib.Leaders.activateCtrlUnassignSelected()`

**What the original does without it** - the leader assignment window has an "unassign all leaders" button. It raises a confirmation dialog (`CONFIRM_REMOVEAll`), and confirming posts one game command naming the played country; when that command runs, on every machine, it walks all of the country's units and puts the "no leader" placeholder on each, skipping only units on loan to another country. There is no way to unassign the leaders of some units only, other than one by one. (comment)

**What the feature does** - when the confirmation is clicked **with either Ctrl key held down at that moment**: (source)

1. The units currently selected on the map are taken, keeping only those that are land, naval or air units (a selected province is ignored), owned by the played country, not on loan to another country, and that have a leader (not none, not the placeholder). These are the same exclusions the country-wide command applies, so the result is always a subset of what the button would have done.
2. If none is left, **nothing is posted at all** and the dialog's own command is discarded: a Ctrl-click with nothing eligible selected deliberately does not fall back to unassigning everybody.
3. Otherwise, for each such unit, one of the game's own assign-leader commands is posted, assigning the "no leader" placeholder to that unit - the same command the game posts when a player removes one unit's leader by hand - and the country-wide command is discarded.

With Ctrl up, or if the played country cannot be determined, the dialog posts its country-wide command exactly as before. The selection is read at the click; it survives the leader window being open. (source; comment for the last remark)

**Inputs a mod gives it** - none. The dialog's text is the game's.

**When it applies** - once per process, in a game. The feature has an internal on/off flag that the Lua call sets on; nothing in the mod sets it off.

**Multiplayer and saves** - this is the worked example of the rule the command framework states. The Ctrl key and the selection are local, so they are read only in the dialog's click handler, which runs only on the clicking player's machine; what is broadcast is a list of ordinary per-unit commands, each naming its unit and leader by their persistent ids, so every machine does the same. An earlier version filtered inside the country-wide command as it ran, which stripped a subset on the clicking machine and everything on the others; it is recorded as the mistake not to repeat (reversing/findings/FINDINGS-commands.md, point 5). Tested in multiplayer on 2026-10-04. Nothing saved. (comment)

**Where the player sees it** - the leader assignment window's "unassign all" confirmation.

### `BiceLib.Leaders.activateOobLeaderRanks()`

Kind: fix
Switch: `BiceLib.Leaders.activateOobLeaderRanks()`

**What the original does without it** - `leader = N` in an order of battle file puts leader N on the unit whoever he is: nothing of his is compared with the unit. The game's own rule for who may be assigned to a land unit by a player or by the automatic choice is an exact rank per level - division 1, corps 2, army 3, army group 4, theatre 4. A leader put by a file on a unit above or below his rank stays there: below the rank the command needs, the unit gets nothing of him in battle and his name is drawn in red. In addition a leader whose history dates his first `rank` after the current day is at rank 0 and not in his country's list of leaders in service; on that date the daily pass puts him in service at rank 1 (reversing/findings/FINDINGS-leaderassign.md, sections 3 and 3.1). (comment)

**What the feature does** - whenever a leader is put on a unit **while an order of battle file is being read**, just before the game's own assignment (source):

1. Nothing is done unless: the leader is a real leader (not the placeholder); the unit is a land unit; the leader is a land leader; the leader's country is the unit's owner; and the unit's level is division, corps, army, army group or theatre.
2. The leader's rank is set to the rank of the unit's level - 1, 2, 3, 4, 4 - whether that raises or lowers it. Nothing else of the leader changes (skill, experience and traits stay).
3. If the leader is not in his country's list of leaders in service, he is added to it through the game's own routine, with no entry filed in the country's history (the daily pass files none either). Without this, a leader whose first `rank` lies in the future would be found missing on that date and set to rank 1.

"While an order of battle file is being read" means inside the game's order-of-battle loader, which has exactly three callers: the `load_oob` effect, a new game's history order of battle, and the custom game setup's reset of its units. **A savegame is read through none of them**, so a loaded game's leaders are never touched; the unit reader is shared, which is why the feature counts entries into the loader and acts only while the count is above 0. Both spellings of the key are covered: `leader = N` and `leader = { id = N type = T }`. (source)

Left alone: fleets and air units (they take any rank), a leader of the wrong arm, and **another country's leader** - the maintainer's choice, and also because in a new game a country's leaders are put in service just before its own order of battle is read, so adding another country's leader early could be repeated by the game later. (comment)

**Inputs a mod gives it** - none; it acts on the mod's order of battle files (`history/units`) and leader histories.

**When it applies** - once per process; it must be on before a new game is started or a `load_oob` fires. Cannot be switched off.

**Multiplayer and saves** - everything it reads is game state, at the point the file's units are made, so it does on each machine what loading the file does there. The resulting ranks and service lists are ordinary game state and are saved. (comment)

**Where the player sees it** - leaders of units created by a scenario start or an event: their rank, and no red names for rank mismatches.

### `BiceLib.Leaders.activateHistoryLeaderRanks()`

Kind: fix
Switch: `BiceLib.Leaders.activateHistoryLeaderRanks()`

**What the original does without it** - a leader whose history dates his first `rank` line after the game's start is at rank 0 and out of service until that day. On that day the country's daily pass finds the leader's first history entry of the `rank` kind, matches its date against today, and - if he is not yet in service - puts him in the list of leaders in service **at rank 1, whatever the line says**: `1939.1.1 = { rank = 3 }` makes a rank 1 leader in 1939. BlackICE's histories have 527 such lines. A later `rank` line of a leader already in service is never applied at all (reversing/findings/FINDINGS-leaders.md, section 3). (comment)

**What the feature does** - at that one point, the rank given is the one the line names: the rank of the first `rank` entry in the leader's history list (the entry the pass matched), held to the range 1 to 4 (below 1 becomes 1, above 4 becomes 4); a leader with no such entry gets 1. Everything else is the game's: the day, the test that he is not in service yet, the adding to the list. (source)

It does not apply later `rank` lines; the pass still looks only at the first. A leader an order of battle has already put in service (the previous feature) is skipped by the pass on his day, as always, and keeps the rank his unit gave him. (comment)

**Inputs a mod gives it** - none; it acts on `history/leaders`. The mod's validator reports each such line (BV313) and looks for this call.

**When it applies** - once per process; on each later daily pass. Cannot be switched off. Leaders who came into service at rank 1 before it was on are not corrected.

**Multiplayer and saves** - it reads only the leader's own history, inside the daily pass every machine runs. The rank is ordinary saved state.

**Where the player sees it** - the rank of leaders who become available during a game.

### Rank-specific traits - `BiceLib.Leaders.activateRankSpecificTraits()`, `addRankSpecificTrait(...)`, `checkRankSpecificTraitsConsistency()`

Kind: rule
Switch: `activateRankSpecificTraits()`. **Off in the mod and kept**: the three calls are commented out in `bicelib_lua.lua`; by the maintainer's word (2026-11-06) the feature is not in use but is not to be deleted.

**What the original does without it** - a leader's traits do not depend on his rank.

**What the feature does** - a mod declares pairs of traits, an *active* one carrying effects and an *inactive* one carrying none, with a range of ranks. A leader holds one of the two; when his rank changes, the trait he holds is exchanged in place for the other half where the new rank calls for it, so the game sees an ordinary trait. (source)

- *Declaring*: `addRankSpecificTrait(activeName, inactiveName, lowestRank, highestRank)`; ranks inclusive. Returns false, and declares nothing, while the game's traits are not loaded yet (the first Lua state runs before they are; a later state's call succeeds) or when either name is not a trait. A pair whose active name is already declared is ignored and answers true.
- *Switching on*: `activateRankSpecificTraits()` installs the feature and starts it once the game's traits are loaded; it returns whether it is on. Before that, rank changes do nothing.
- *The swap*: when a promotion or demotion command runs (the game's promote-leader command), just before the new rank is stored, each trait in the leader's list whose name begins with `rankSpecificTrait_` is looked up: an active trait whose range does not contain the new rank is replaced by its inactive half; an inactive trait whose range contains the new rank is replaced by its active half; otherwise it stays. A trait with the prefix that was never declared is left and a warning is printed. Rank changes made any other way (the two rank fixes above, a history) trigger no swap.
- *Consistency*: `checkRankSpecificTraitsConsistency()` applies the same swap to every leader in the game for the rank he holds now. Does nothing while the feature is not on.
- *Saving*: while the feature is on, **a trait whose name begins with the prefix is written to the savegame as a single space instead of its name**, so it is not saved: a loaded leader holds neither half until something gives it to him again. The header records this as how it was written, "not judged".

**Inputs a mod gives it** - trait pairs in `common/traits.txt` whose names both begin with `rankSpecificTrait_`; the four arguments above. The README notes the leader window shows the change only after it is reopened.

**When it applies** - process-wide once activated. Cannot be switched off.

**Multiplayer and saves** - the swap runs inside the promotion command, on every machine, from the leader and the rank alone. Rank-specific traits are deliberately absent from saves (above), so they would have to be re-given after every load; nothing in the DLL does that.

**Where the player sees it** - a leader's trait list.

### Promotion skill loss - `activateLeaderPromotionSkillLoss()` (abandoned, deleted)

Kind: rule
Switch: none. **Abandoned**: the function is no longer registered with Lua and its code was deleted on 2026-11-07; only `README.md` still lists it, struck through and marked "currently bugged". The maintainer's word is that it is dead.

**What it was meant to do** (readme only; no code exists to check it against) - make a leader lose or gain skill levels on promotion or demotion, as in older games of the series. Each leader was to hold a trait `pskill_N` stating his "pure" skill; rank and pure skill together gave his shown skill; percentage progress to the next level was to be kept across the change, rounded down to a whole percent; a leader with no `pskill` trait was unaffected. The README records why it never worked: the game tracks total experience with a different amount per level, and the arithmetic breaks past level 10.

The commented-out examples `addCommandLimitTrait("pskill_1", -1)` and `("pskill_4", 1)` in `bicelib_lua.lua` are leftovers of the same idea. A reimplementation should not build this feature.

## Part 2 - Texts: effect texts, requirement tooltips, tooltips

### Notation used in this part

The game colours text with a two-character escape: the section sign (Windows-1252 character
code 167) followed by a letter. Below, `[Y]` is section sign + `Y` (yellow), `[R]` is section
sign + `R` (red), `[G]` is section sign + `G` (green) and `[W]` is section sign + `W` (back to
white, the reset every line here uses). The game also has section sign + `!` as a reset in its
own texts; BiceLib never writes that one. `\n` is a line break.

"The game's number formatter" means the routine the game itself prints fixed-point figures
with: it takes a value in thousandths and a number of decimals, divides by a thousand, **cuts
(does not round)** to that many decimals and writes no thousands separators
(reversing/findings/FINDINGS-manpower.md, section "The tooltip"; the cutting is stated in
reversing/findings/FINDINGS-diplomacyview.md and others). So 12050 with one decimal is `12.0`
and with two is `12.05`.

All eight switches below share one contract (source): each is a Lua function that takes no
argument, installs its change once per process, and returns one boolean - `true` if it is
installed (also when it already was), `false` if not, with the reason printed to BiceLib's log
as `'<name>' failed: <reason>`. Before writing anything each one checks that the game code at
the places it changes is exactly what it expects, and writes nothing at all if any check fails.
None can be switched off again in a running process. None needs `BiceLib.setModuleBase()` to
have been called first: the DLL finds the game module by itself as it loads, and that function
only prints where it is (a switch fails with "hoi3_tfh.exe is not loaded" only if the module
was not found at all).

### Shared machinery: an extra `$VARIABLE$` in a localised line, and reading a localised text

Kind: infrastructure
Switch: none of its own - used by activateKillLeaderVariables, activateLoadOobDetails,
activateManpowerBreakdown and activateParadropLine

**What the original does without it** - A localised line is fetched by key as a *text object*:
the entry the key found plus a list of pending `$NAME$` replacements. The code that builds a
sentence adds replacements one at a time (variable name without the dollar signs, value as
text; both are copied), and the text is turned into characters only at the end, when every
`$NAME$` that has a replacement is substituted. A `$NAME$` nothing replaced is drawn literally,
dollars and all. (reversing/findings/FINDINGS-effecttext.md)

**What the feature does** - BiceLib has two tools built on that (source):

- *Set a variable on a text being built.* Given the text object a game routine is still
  filling, it adds one more replacement through the game's own replace routine: name, value.
  The value is Windows-1252 text and may contain colour escapes. Because a replacement only
  shows where the localisation string asks for the name, adding one changes nothing until the
  mod's `.csv` uses it; and a string that asks for a variable BiceLib did not fill (feature
  switched off or failed) shows the bare `$NAME$`, which is deliberate - a failed install is
  visible, not silent (comment).
- *Read a localised text by key.* Looks the key up, renders it with no replacements and the
  game's current colour settings, and returns the characters in Windows-1252. A key built from
  a prefix and a number (`PROV` and a province id give `PROV1234`) is the same call. The
  helper's own documentation says a key with no entry gives an empty text, and every caller
  falls back as though it does (province: the bare id number; unit type: the type's key)
  (comment). Note that the same sources describe the original `load_oob` text as "the path
  looked up as a key, which shows the path", i.e. a missing key rendering as the key itself;
  which of the two a missing key really gives was not verified here. A reimplementation should
  simply use the stated fallbacks when no localised name exists. A lookup of a missing key
  creates an empty entry in the game's table as a side effect, so it is meant for keys expected
  to exist, and should be asked only while a game is running (comment).

A third shared helper strips colour escapes from a text: every section sign is removed together
with the one character after it (a trailing lone section sign is just removed) (source). It is
applied to unit names, leader names and province names before they are wrapped in a colour of
BiceLib's own, because a name carrying its own escape would end the surrounding colour at the
name - and unit names in this mod do carry them (comment).

**Multiplayer and saves** - Display only. Nothing is stored.

### BiceLib.EffectTexts.activateKillLeaderVariables()

Kind: text
Switch: `BiceLib.EffectTexts.activateKillLeaderVariables()`

**What the original does without it** - In an event option's tooltip (and wherever else an
effect describes itself) the `kill_leader` effect writes the localisation key
`KILL_LEADER_EFFECT` with one variable, `$NAME$`. The effect's value is a leader id; the leader
is looked for among the scope country's leaders in service, and `$NAME$` is replaced by `[Y]` +
the leader's name + `[W]`. The base game's English text is `Leader [Y]$NAME$[W] will die.\n`.
It says nothing about what the leader commands or where.
(reversing/findings/FINDINGS-effecttext.md; base text from the install's `localisation/misc.csv`)

**What the feature does** - Three more variables are set on the same text, just before the
game's own `$NAME$` replacement, for the same leader (source):

| variable | value |
| --- | --- |
| `$UNIT$` | the name of the unit the leader commands now, colour escapes stripped; empty if he commands nothing |
| `$LOCATION$` | the localised name (`PROV<id>`) of the province that unit is in now, colour escapes stripped; empty if he commands nothing, or the unit's province cannot be read or has id 0 or less |
| `$WHERE$` | a ready-made bracket, see below; empty if he commands nothing |

`$WHERE$` is exactly:

- unit and province both known: ` (` + `[R]` + unit + `[W]` + `, ` + `[R]` + province + `[W]` + `)`
  - a leading space, then the bracket;
- unit known, province not: ` (` + `[R]` + unit + `[W]` + `)`;
- no unit: the empty text (so no empty ` ()` is left behind).

The bracket holds punctuation and colour only, no words, so the localisation owns every word of
the sentence (comment). The whole `$WHERE$` value is cut at 255 characters (source).

All three are always set when the leader was identified - to empty text where there is nothing
to say - so a localisation using them never shows a bare `$UNIT$`. If the text is built without
the leader having been identified, none of the three is set and a string asking for them shows
them literally (source).

The mod's text, which is what makes anything appear: `KILL_LEADER_EFFECT` =
`Leader [Y]$NAME$[W]$WHERE$ will be removed.\n` (mod's `localisation/misc.csv`). Result, for
example: `Leader [Y]Erwin Rommel[W] ([R]7. Panzer-Division[W], [R]Koeln[W]) will be removed.`

**Inputs a mod gives it** - The localisation key `KILL_LEADER_EFFECT` using any of `$UNIT$`,
`$LOCATION$`, `$WHERE$`; province names under `PROV<id>`. No Lua arguments.

**When it applies** - From the call on, in every tooltip the effect describes itself in. Call
once per process; it cannot be undone. The province name lookup needs a game to be running,
which is the only time the effect text is built.

**Multiplayer and saves** - Display only and local: it reads the leader's current unit and that
unit's current province each time the text is built, changes no game state, posts no command
and keeps nothing.

**Where the player sees it** - Event option tooltips (and decision effect tooltips) that
contain `kill_leader`.

State in the mod: called in the committed `script/bicelib_lua.lua`.

### BiceLib.EffectTexts.activateLoadOobDetails()

Kind: text
Switch: `BiceLib.EffectTexts.activateLoadOobDetails()`

**What the original does without it** - The `load_oob = "<path>"` effect describes itself by
handing its own path to the localisation lookup as though it were a key and showing what comes
back, which is the bare path, e.g. `GER/GER_Kriegsmarine_Creation.txt`. There is no key and no
variable. Nothing about the file is in memory until the effect fires: firing opens
`history/units/<path>` (the mod's copy before the game's), parses it into the scope country as
though it were part of that country's save block - making the units, assigning the leaders
named by `leader = <id>`, queueing `military_construction` entries - and forgets the file.
(reversing/findings/FINDINGS-effecttext.md)

**What the feature does** - The text the effect was going to show is replaced, whole, by a
description built from the file on disk and from the live game (source). It is English and
hard-coded; no localisation key is involved except province names.

*Finding the file.* The path is taken exactly as the effect carries it. Two places are tried,
in this order, and the first that yields a non-empty file wins: the mod's
`history/units/<path>`, then the game's own `history/units/<path>` (BiceLib locates both
relative to its own DLL, which sits in the mod's `script` folder inside the game's `tfh/mod`
tree; the game's `tfh/history/units` is not tried). A file that is missing, unreadable or empty
in both places counts as not found. (source)

*Reading the file.* It is not a full parse; it is a character scan that keeps a stack of the
names of the blocks it is inside (source):

- `#` starts a comment that runs to the end of the line.
- A double quote starts a quoted text that runs to the next double quote; everything in it is
  skipped, and the "last word" is forgotten.
- A *word* is a run of letters, digits, `_` and `-`. Everything else (white space, `=`) is
  skipped. The scan remembers the last word seen.
- `{` opens a block named by the last word seen (so `corps = {` opens a block `corps`; the word
  is then forgotten). `}` closes the innermost block.
- When a block opens, its name is counted: `regiment` adds one **brigade**, `ship` one
  **ship**, `wing` one **wing**, `military_construction` one **construction**.
- A word that follows the word `location`, while at least one block is open, is read as a
  whole number; if it is above 0 it adds one **unit** and one to that province's count. So a
  "unit" is every block that carries a `location` of its own: a theatre, army group, army,
  corps, division, fleet or air unit. A `location` outside any block is ignored.
- A word that follows the word `leader` is read as a whole number; if it is above 0 it records
  one **leader assignment**: the leader id and the name of the innermost open block (the
  *kind*: `division`, `corps`, `army`, `armygroup`, `theatre`, `navy`, `air`, ...; empty when
  no block is open). Assignments keep the file's order.

After the scan the provinces are made into a list of *places* - province id, its localised name
(`PROV<id>`), and its unit count - sorted by unit count, largest first, and by province id,
smallest first, where counts are equal.

The parsed result is kept per path for the life of the process and never re-read; that
includes "not found" and the province names as they were localised at the first ask. (source)

*The text.* Lines, in this order; a line appears only under the stated condition (source):

1. The path, exactly as written in the effect. Always.
2. If the file was not found: `\n` + `[R]Not in the mod or the game.[W]` - and nothing more.
3. If there is at least one unit: `\n` + `[Y]` + unit count + `[W]` + ` units in ` + the places.
   The places are joined by `, `; each is `[Y]` + name + `[W]`, followed by ` (` + count + `)`
   only when more than one unit appears there. A province with no localised name is written as
   its id number. Only the first **4** places are listed unless Alt is held; when places are
   left out the line ends ` and N more`, N being the number of places not listed.
4. If anything was counted: `\n` + the contents, uncoloured, the non-zero ones of
   `N brigades`, `N ships`, `N wings` in that order, joined by `, `.
5. If there is at least one construction: `\n` + `[Y]` + count + `[W]` + ` added to production`.
6. If the file assigns at least one leader: `\n` + `[Y]` + number of assignments + `[W]` +
   ` leaders take command:`, then one entry per assignment in file order - only the first
   **10** unless Alt is held, after which a line `\n` + two spaces + `and N more` (N = the
   assignments not shown) ends the list. Each entry is found by id among **all the leaders of
   the country the effect's scope is about** (not only those in service):
   - id not among them: `\n` + two spaces + `[R]` + the id + ` - not one of this country's leaders` + `[W]`;
   - otherwise: `\n` + two spaces + `[Y]` + the leader's name (escapes stripped) + `[W]` +
     ` to ` + article + ` ` + kind + ` - ` + where he is now. The kind is the block name from
     the file, or the word `unit` when it is empty. The article is `an` when the kind begins
     with a, e, i, o or u (either case), else `a` - "an army", "an armygroup", "an air", "a
     corps", "a division", "a theatre", "a navy". Where he is now is the plain words
     `no command` if he commands nothing, else `[R]` + his unit's name + (`, ` + its province's
     name, when known) + `[W]` - red because that unit is about to lose him (comment);
   - and, for a found leader whose kind is one of the five land levels and whose present rank
     is not the rank that level takes (division 1, corps 2, army 3, armygroup 4, theatre 4 -
     the game's own exact-rank rule for who may be put on a land unit,
     reversing/findings/FINDINGS-leaderassign.md, section 6), one more line under his:
     - if the feature `BiceLib.Leaders.activateOobLeaderRanks()` is installed **and** he is a
       land leader (so loading the file will change his rank):
       `\n` + four spaces + `rank R, made W for a corps` (R his rank now, W the wanted rank,
       article and kind as above), uncoloured;
     - otherwise: `\n` + four spaces + `[R]rank R, and a corps wants W[W]`.
     Kinds `navy`, `air` and anything else have no rank rule and never get this line.
7. If any list above was cut short: `\n` + `[G]hold Alt for the rest[W]` + `\n`.
8. Always, at the very end: one `\n`. The game runs the texts of an option's effects together
   with nothing between them, so without it the next effect's sentence (or the next
   `load_oob`'s path) would start on this description's last line (comment).

The counts are plain whole numbers, and the nouns are not adjusted for one ("1 units in",
"1 leaders take command:").

*Alt.* Holding either Alt key lifts both limits (4 places, 10 leaders). The key's state is read
directly from the keyboard each time the text is built, and because the game rebuilds a tooltip
continuously while the mouse is over it, the tooltip grows and shrinks as the key goes down and
up. The hint line (7) is shown only when something was actually left out. (source)

*Caching of the built text.* The last built text is kept and reused while all of these hold:
the path is the same, the Alt state is the same, and no more than 1000 ms have passed since it
was built. Otherwise it is built again. So a leader reassigned while the tooltip is up shows
within a second. The scope's country is not part of what the kept text is keyed on. (source)

**Inputs a mod gives it** - The files under `history/units`; province names under `PROV<id>`;
no Lua arguments. It consults whether `activateOobLeaderRanks` is installed.

**When it applies** - From the call on, wherever a `load_oob` effect describes itself, in a
running game. Once per process, not reversible. Holding Alt over the tooltip is safe only
because the overlay's window procedure swallows the "Alt opens the window menu" system command,
which otherwise freezes the game's drawing until a click (source, Overlay.cpp); that hook
exists when the overlay is enabled (`BiceLib.Overlay.enable()`, which the mod's
`script/gui-imgui.lua` calls).

**Multiplayer and saves** - Display only and local. It reads a file from the local disk, the
local keyboard, and the scope country's leaders; it changes no game state and posts nothing.
The parsed-file cache lives outside the save and for the whole process, so a file edited while
the game runs is not seen until restart.

**Where the player sees it** - Event option and decision tooltips containing `load_oob`.

State in the mod: called in the committed `script/bicelib_lua.lua`.

### BiceLib.EffectTexts.activateTriggerIndent()

Kind: fix
Switch: `BiceLib.EffectTexts.activateTriggerIndent()`

**What the original does without it** - A block of conditions (a technology's `allow`, a
decision's `allow`, and every other place a trigger block describes itself) is drawn as a tree,
one line per condition. Two building blocks: `IND(n)` is three spaces written n times, and
`STAR(c)` is the seven characters `(` `[R]` `*` `[W]` `)` when condition c, evaluated in the
scope in hand, gives the result that counts as unmet, else `(` `[G]` `*` `[W]` `)`. "Unmet" is
false normally and is turned round inside a `not`. Every trigger has a *one-line text* (empty
for containers) and a *block text* (empty for leaves). The original renderers
(reversing/findings/FINDINGS-techtext.md, section 2; reversing/findings/FINDINGS-script.md,
"How a requirement tooltip is drawn"; reversing/findings/FINDINGS-scripttext.md, section 5.2):

- **Base block** at depth d: a negative d is made positive and remembered. For each child in
  order: if its one-line text is not empty, write `IND(d)`, then `STAR(child)` only when d is 0
  or d arrived negative, then the line; then append the child's block text at the same depth.
- **`and`** at depth 0: exactly the base block (so a top-level `allow`, an implicit `and`, has
  no header). At depth d above 0: `IND(d)` + text of `AND_TRIGGER_STARTS` + `:\n`; then for
  each child: its block text asked **at depth 0**, or, if that is empty and the child has no
  children, its one-line text; if the result is not empty: `IND(d)` + `STAR(child)` + result.
- **`or`** at depth d: `IND(d)`; `STAR(itself)` only at depth 0; text of `OR_TRIGGER_STARTS` +
  `:\n`; then the children as for `and`, except a child's block text is asked **at depth 1**.
- **`not`**: the base block with "unmet" turned round, depth unchanged.
- **Iterating scopes** (`any_owned_province`, `any_neighbor_province`, `any_neighbor_country`,
  `any_core`, a region): `IND(d)`; `STAR(itself)` only at depth 0; (`IND(d)` a second time for
  `any_owned_province` and `any_neighbor_province`); the header text + `:\n`; then the base
  block for the children at depth d plus one, in the scope unchanged - so the children get no
  asterisk.
- **Context scopes** (a country tag, a province number, `owner`, `controller`, `capital_scope`,
  `FROM`, `THIS`, `overlord` and the like): `IND(d)`; `STAR(itself)` only at depth 0; the
  scope's name; then, when the children come to two lines or more, `:\n` + the base block at
  depth d plus one in the new scope (no asterisks); when they come to one line, that line is
  joined onto the name after a space, its own asterisk removed and its first letter lower-cased.

Three sums are wrong and they compound: a header indents itself although its parent already
indented the line (so a nested block's text sits to the right of its own asterisk); a
container's children are indented to the container's depth, not one deeper (so a condition sits
level with the header above it); and a child block is told depth 0 (from `and`) or 1 (from
`or`) whatever its real depth (so nothing gets deeper than one level). Typical result:

    (*)One of the following must be true:
    (*)   All of the below:
       (*)condition C        <- should be two levels in
       (*)condition D

Texts: `AND_TRIGGER_STARTS` = "All of the below", `OR_TRIGGER_STARTS` = "One of the following
must be true" (same in the base game and the mod).

**What the feature does** - It changes the arithmetic only; the wording of every line, the
asterisks' colours and the order are the game's. Six corrections (source; the same six are
checked against the game in reversing/findings/FINDINGS-scripttext.md, section 5.3):

1. **No header indents itself.** The leading `IND(d)` of `and`, `or`, the five iterating
   scopes and the context scope is no longer written (for `any_owned_province` and
   `any_neighbor_province` both of their two indents go). The "only at depth 0" asterisk test
   of those headers is untouched.
2. **Each child line of an `and` or an `or` is indented `IND(d + 1)`**, not `IND(d)`.
3. **A child block of an `and` or an `or` is asked at depth d plus one**, not 0 or 1. (A leaf
   child's one-line text is still asked at depth 0, as before.)
4. **In the base block, a child whose one-line text is empty** - a container - **gets
   `IND(d)` + `STAR(child)` written before its block text is appended, when d is above 0.**
   At d = 0 nothing is added, because a block draws its own asterisk there. The asterisk is
   written whenever d is above 0, whether or not the base block is one that stars its leaves.
5. **A context scope asks for its many-line children at the negative of (d plus one)**, which
   is the engine's own way of saying "indent this deep and star the lines" - the conditions
   under a context scope are evaluated in a real scope of their own, so their asterisks mean
   something. The one-line form is untouched. The iterating scopes are deliberately left
   without asterisks on their leaves: their conditions would be evaluated against the country,
   not against any province, and would be red for ever (comment).
6. **A `not` has all leading spaces removed from the text it produced**, because it sits on a
   line its parent has already placed. Only spaces at the very front of the whole text go.

`enemy = { }` and a mean-time-to-happen `modifier` block share the `and` renderer and so are
corrected with it (comment; reversing/findings/FINDINGS-scripttext.md, section 5.2).

The corrected renderers, in full:

- **Base block** at depth d (negative: remembered, made positive): for each child: if its
  one-line text is not empty, `IND(d)` + (`STAR(child)` when d is 0 or arrived negative) + the
  line; if it is empty and d is above 0, `IND(d)` + `STAR(child)`; then the child's block text
  at depth d.
- **`and`** at depth 0: the base block. At d above 0: `AND_TRIGGER_STARTS` + `:\n`; each child:
  its block text at depth d plus one, or its one-line text if that is empty and it has no
  children; if not empty: `IND(d + 1)` + `STAR(child)` + result.
- **`or`** at depth d: `STAR(itself)` only at depth 0; `OR_TRIGGER_STARTS` + `:\n`; children
  as for the corrected `and`.
- **`not`**: the base block with "unmet" turned round at depth d, leading spaces removed.
- **Iterating scope** at depth d: `STAR(itself)` only at depth 0; header + `:\n`
  (`any_owned_province`: `ANY_PROVINCE_STARTS` + ` (` + the scope country's name + `)` + `:\n`);
  the base block at depth d plus one.
- **Context scope** at depth d: `STAR(itself)` only at depth 0; the name; many lines: `:\n` +
  the base block at minus (d plus one) in the new scope; one line: as the original.

The upshot: a line that is n headers deep starts with 3n spaces, then its asterisk, then its
text; a header is itself a line of its parent, at its parent's children's depth, with the
asterisk the parent (or, at the top, the header itself) draws. A tree

    allow = { A  or = { B  and = { C D }  not = { E } }  GER = { F G }  any_owned_province = { H I } }

comes out as (`(*)` standing for the seven-character asterisk; nothing is inserted between it
and the text that follows):

    (*)A
    (*)One of the following must be true:
       (*)B
       (*)All of the below:
          (*)C
          (*)D
       (*)E, worded as its negation
    (*)Germany:
       (*)F
       (*)G
    (*)Any owned province (Germany):
       H
       I

Things that stay as the original has them, and follow from the rules above: an `and` reached at
depth 0 - the top level, an explicit `and` directly inside it, or one directly inside a
top-level `not` - draws no header and its conditions read as part of the list around it; a
`not` holding several conditions puts the second and later ones on lines of their own, indented
to the block's depth with no asterisk (inside an `and` or `or`), since only the front of the
`not`'s text is trimmed; leaves directly inside an iterating scope have no asterisk.

**Inputs a mod gives it** - None. No Lua arguments, no keys of its own.

**When it applies** - From the call on, to every trigger block text. All its changes are
installed together or not at all. Once per process, not reversible.

**Multiplayer and saves** - Display only. Evaluating a condition for an asterisk is what the
original already does; nothing is changed or stored.

**Where the player sees it** - Technology requirement tooltips, a decision's requirement
tooltip (its info icon), triggered modifiers' conditions, and any other tooltip made from a
trigger block.

State in the mod: called in the committed `script/bicelib_lua.lua`.

### BiceLib.EffectTexts.activateTriggerScroll()

Kind: interface
Switch: `BiceLib.EffectTexts.activateTriggerScroll()` (the mouse wheel part also needs the
overlay's window procedure, i.e. `BiceLib.Overlay.enable()`)

**What the original does without it** - A requirement tooltip with more lines than fit on the
screen simply runs off the bottom. The game neither shrinks nor scrolls it, and the rest cannot
be read. The game rebuilds a tooltip's text continuously while the mouse rests on it (comment).

**What the feature does** - Nothing about the tooltip window is touched. Each time the game
finishes building the text of a whole requirement tree - the `and` renderer returning from a
call at depth 0 - BiceLib may shorten that text from the front before the tooltip sees it, so
what was below the screen moves up (source):

- *Line count.* Lines = the number of line breaks in the finished text plus one (a wrapped long
  line counts once, so one step can move the picture by more than one row). With 3 lines or
  fewer the text is never touched and the scroll position is reset to 0.
- *Scroll position.* One number for the whole process: how many lines are hidden above. It is
  reset to 0 (and any wheel movement not yet applied is dropped) whenever the untrimmed text
  differs from the last untrimmed text seen - a different tooltip, or the same one whose
  contents changed. It is not reset by time or by the tooltip closing: returning to a tooltip
  whose text is identical to the last one scrolled resumes where it was.
- *Keys.* Either Alt key held plus Down: one line further (position plus 1). Alt plus Up: one
  line back. A fresh press acts at once; a held key repeats every 130 ms. If both arrows are
  held, Down wins. Without Alt the arrows do nothing here. The keys are read directly from the
  keyboard each time the text is built.
- *Wheel.* With Alt held, one notch of the wheel moves 3 lines; rolling forward (away from the
  user) moves towards the top. A wheel message is taken - and then kept from the game - only
  when all of these hold: the feature is installed; Alt is down; the last requirement text
  built had more than 3 lines; it was built no more than 250 ms ago (which is how "a scrollable
  requirement tooltip is on screen" is known); and the movement is at least one whole notch.
  Otherwise the wheel goes to the game untouched (the map, or a list under the tooltip). Alt
  is required because decisions and triggered modifiers show their conditions over a list that
  itself scrolls with the wheel (comment). Wheel movement is collected and applied at the next
  build of the text.
- *Clamping.* After keys and wheel are applied, the position is held between 0 and (lines
  minus 3), so at least the last lines stay visible and the tooltip cannot be emptied.
- *What is shown.*
  - Position 0 and fewer than 50 lines: the text exactly as the game built it.
  - Position 0 and 50 lines or more: one line is put in front of the text:
    `[Y]... hold Alt and scroll, with the wheel or the arrow keys[W]` + `\n`. The 50 is a guess
    at "likely taller than the screen" (comment).
  - Position N above 0: the first N lines are dropped and this line is put in front of the
    rest: `[Y]... N more above (Alt + wheel or Up/Down)[W]` + `\n`.
  There is no indicator of how much remains below. Both lines are English and hard-coded.

**Inputs a mod gives it** - None.

**When it applies** - From the call on, for any trigger-block text whose root is an `and`
rendered at depth 0: technology `allow`, decision `allow`, triggered modifier conditions and
the like. Once per process, not reversible. The arrow keys work without the overlay; the wheel
only with it.

**Multiplayer and saves** - Display and local input only. One scroll position, the last text
and a timestamp are kept in memory; nothing reaches the game state or the save.

**Where the player sees it** - Any long requirement tooltip.

State in the mod: called in the committed `script/bicelib_lua.lua`.

### BiceLib.Tooltips.activateManpowerBreakdown()

Kind: text
Switch: `BiceLib.Tooltips.activateManpowerBreakdown()`

**What the original does without it** - The tooltip of the top bar's manpower figure writes
`MANPOWER_DETAILS_IRO` with two variables: `$NEED$`, the manpower it would take to bring every
subunit of the country back to full strength, and `$USED$`, the manpower reinforcement spent
today. Both are fixed-point thousandths, printed by the game's number formatter with **two
decimals when the need is below 10.000 and one decimal at or above it**. Base text: "Our army
needs [Y]$NEED$[W] manpower to reinforce, and we use [Y]$USED$[W] every day." Both figures are
rebuilt from nothing each day by the country's reinforcement pass, which walks every unit and
every subunit short of strength and adds, for each,

    need = missing strength x the subunit's build_cost_manpower / its max_strength

(both from the subunit's own definition, which already has technology in it) - refilling all
of a subunit costs what building it cost. (reversing/findings/FINDINGS-topbartooltip.md,
section 9; reversing/findings/FINDINGS-manpower.md)

Three daily mechanics feed that need, and the original shows none of them
(reversing/findings/FINDINGS-manpower.md; the header of ManpowerText.hpp):

- *Troop rotation.* The country modifier `peacetime_manpower_rotation` (set by laws) is an
  annual rate. In each land unit's daily update - land only, and not gated on peace despite the
  name - every brigade loses strength each day: its maximum strength times the annual rate,
  divided by 365 (in the game's fixed point: maximum x rate in thousandths / 365000), the new
  strength held between 0 and the maximum, with the rate first multiplied by
  `1 + (1 - supply received) x PEACETIME_MANPOWER_ROTATION_LOW_SUPPLY_FACTOR` for an
  under-supplied unit. It takes strength, not manpower; the manpower is spent when
  reinforcement puts the strength back.
- *Attrition.* The daily attrition pass takes strength off a land unit's brigades the same way
  (rate from the province's modifier, skipped while the unit is in combat).
- *Casualty trickleback.* The only one that gives manpower back: a share of casualties is
  credited to the country's manpower pool.

**What the feature does** - Seven more variables are set on the same text, for the country the
tooltip is about (source). None shows unless the localisation asks for it.

| variable | value | format |
| --- | --- | --- |
| `$LAND$` | the part of `$NEED$` that is for brigades (land subunits) | game formatter, the same decimals as `$NEED$`: 1 if the need is 10.000 or more, else 2 |
| `$AIR$` | the part that is for air wings | same |
| `$NAVY$` | the part that is for ships | same |
| `$ROTATION$` | the country's `peacetime_manpower_rotation`, as a percentage figure without a percent sign: the modifier value times 100 | game formatter, 1 decimal (a rate of 0.025 reads `2.5`) |
| `$ROTATIONCOST$` | what rotation cost in manpower on the last complete day, projected over a month: `day x 365 / 12` (whole-number arithmetic on thousandths) | game formatter, 1 decimal if the result is 10.000 or more, else 2 |
| `$ATTRITION$` | the average day's attrition cost in manpower over the days recorded, times a month: `sum of recorded days x 365 / 12 / number of days` | same rule |
| `$TRICKLEBACK$` | the same average for manpower returned by casualty trickleback | same rule |

How each is obtained (source):

- *The split.* BiceLib does not recompute the need. It watches the reinforcement pass: where
  the pass clears a country's counters, BiceLib clears that country's three parts; where the
  pass adds one subunit's share to the country's need, BiceLib adds the same amount to land,
  air or navy according to whether that subunit is a brigade, a wing or a ship, and to a
  running total. So the three parts add up to `$NEED$` by construction. When the tooltip is
  built the running total is compared with the country's need figure: only if they are equal
  (or the country has no record yet and its need is 0, which gives three zeroes) are the three
  shown. Otherwise all three are set to **empty text** - blank, never wrong. That happens
  only until the next daily pass after the feature was installed mid-day, or if a subunit of an
  unknown kind was counted.
- *Rotation rate.* Read directly from the country's modifier each time, so it is right from
  the first tooltip. Empty text if it cannot be read.
- *Rotation cost.* Where rotation writes a brigade's reduced strength, BiceLib takes the
  strength actually removed (before minus after, after the game's clamping), prices it as
  `removed x build_cost_manpower / max_strength` from that brigade's own definition (64-bit
  multiply, cut to a whole number of thousandths; nothing counted if any term is 0 or less),
  and adds it to the owning country's pending figure. A country's "day" is closed where its
  reinforcement pass begins: pending becomes "the last complete day" and pending restarts at
  0. The first close after installation is thrown away (it covers a part day), so
  `$ROTATIONCOST$` is empty text until the country's second pass.
- *Attrition.* Counted and priced exactly like rotation, at the place attrition writes a
  brigade's reduced strength; kept as one figure per closed day in a ring of **30 days** per
  country (oldest overwritten). Empty text until one day has been closed.
- *Trickleback.* The amount the game credits to the country's manpower pool is added as it is
  (it is already manpower); positive amounts only; same 30-day ring and same average.

Rotation is projected from one day because it is a rate; the other two are averaged because
they depend on where units stand and whether anyone is fighting, so the figure starts rough and
settles (comment). "A month" is a twelfth of a 365-day year everywhere here.

The mod's text (mod's `localisation/interface.csv`), which places them:

    MANPOWER_DETAILS_IRO = Our army needs [Y]$NEED$[W] manpower to reinforce, and we use [Y]$USED$[W] every day.\n
    Needs: Land [Y]$LAND$[W]  Air [Y]$AIR$[W]  Navy [Y]$NAVY$[W]\n
    Troop rotation cycles [Y]$ROTATION$%[W] of our army out each year, costing about [Y]$ROTATIONCOST$[W] manpower a month\n
    Attrition costs us about [Y]$ATTRITION$[W] a month, and [G]$TRICKLEBACK$[W] comes back from the wounded

(one key, shown here broken at its `\n`s; two spaces separate the three "Needs" items; the
percent sign after `$ROTATION$` is the localisation's).

**Inputs a mod gives it** - The key `MANPOWER_DETAILS_IRO` using any of the seven variables;
the law modifier `peacetime_manpower_rotation`; the define
`PEACETIME_MANPOWER_ROTATION_LOW_SUPPLY_FACTOR` (read by the game, not by BiceLib). No Lua
arguments.

**When it applies** - Counting starts at the call; the split is trustworthy from each
country's next daily reinforcement pass, the rotation cost from the second, the averages from
the first closed day. Once per process, not reversible.

**Multiplayer and saves** - Display only: the hooks watch the daily passes and change nothing
in them. The per-country records (up to 512 countries, keyed by the live country object; the
whole table is emptied when it fills, costing at most a day of blanks) live in memory only:
they are not in the save, are empty after a restart, and a newly loaded game starts its
countries' histories afresh. Every machine counts for itself; nothing depends on the figures.

**Where the player sees it** - The tooltip of the manpower figure in the top bar.

State in the mod: called in the committed `script/bicelib_lua.lua`.

### BiceLib.Tooltips.activateCombatUnitStats() - the stat block and the damage tallies on a battle's unit tooltip

Kind: text
Switch: `BiceLib.Tooltips.activateCombatUnitStats()` (this one call also installs the damage
counting; there is no separate switch for it)

**What the original does without it** - Hovering a land unit in a battle window gives (the
whole-unit tooltip; the strength bar, organisation bar and width strip have short ones of their
own): the leader line (`LEADER_COMMAND_INFO` with `$NAME$` and `$SKILL$`, or
`NO_LEADER_FOR_THIS_1` / `_2`), `BATTLE_ATTACKMOD` ("Attack Modifier") + `: ` + a percentage to
two decimals, `BATTLE_DEFENDMOD` ("Defend Modifier") the same, one line per combat modifier on
the unit (name + `: ` + signed percentage), the side's tactic's figures, then `AP_ATTACK` + its
piercing attack and `ARMOR_VALUE` + its armour, each on its own line. The attack percentage is
the unit's attack product times a second attack multiplier (1 except while landing from the
sea); the defend percentage likewise; the modifiers multiply, they do not add. It never says
what the percentages are percentages of, and the game keeps no record of what one unit has
dealt or taken in a battle - only what a side has lost.
(reversing/findings/FINDINGS-battletooltips.md, section 3; header of CombatUnitDamage.hpp)

**What the feature does** - A block of English, hard-coded text is appended to the end of that
whole-unit tooltip, after the armour line (source). It cannot be done with variables in a
localisation key, because the game appends `: <value>` after rendering a line's key, so
anything in the key would land between the label and its number (comment). The block is added
only when the tooltip being finished is the one whose attack-modifier line was just built for a
unit (so not on the bar tooltips, and not on the attacker's reserve entries, ship or wing
tooltips, which other routines build - reversing/findings/FINDINGS-battletooltips.md,
sections 4 to 6), the unit has at least one readable brigade, and the tooltip's text is of a
sane length (at most 16384 characters).

*The stats.* For each brigade of the unit, from **that brigade's own definition** (the copy
the game has already rebuilt with every researched technology in it - not the type's shared
template), four fixed-point figures are **summed over all brigades**: soft attack, hard
attack, defensiveness, toughness. Nothing is weighted by strength and nothing is averaged.
Piercing attack and armour are deliberately left out: the game's own tooltip prints both just
above, and neither is scaled by the combat modifiers (comment).

*The modifiers.* attack = attack product x second attack multiplier / 1000, defend = defence
product x second defence multiplier / 1000 - the same two figures the tooltip's two percentage
lines print - each a thousandths factor, cut to a whole number.

*Layout.* The block is:

    \n
    [Y]Base[W] -> [Y]effective[W]\n
    <stat table>

and, when damage figures exist for the unit (below):

    \n
    [Y]Damage[W]\n
    <damage table>

with no line break after the last table. Since the game's own text ends with a line break, the
leading `\n` leaves one blank line before the "Base -> effective" heading; there is no blank
line before "Damage".

The stat table has two columns and four rows; every row is indented by two spaces; the first
column is the caption written as `[W]` + caption (the reset is written because the previous
cell ended in a coloured number), the second the value:

| caption | base figure | scaled by |
| --- | --- | --- |
| `Soft Attack:` | sum of soft attack | attack |
| `Hard Attack:` | sum of hard attack | attack |
| `Defensiveness:` | sum of defensiveness | defend |
| `Toughness:` | sum of toughness | defend |

A value is `[Y]` + base + `[W]` when the modifier is exactly 1.000 (or the modifiers could not
be read), else `[Y]` + base + `[W]` + ` -> ` + `[Y]` + effective + `[W]`, where effective =
base x modifier / 1000 (64-bit, cut). Base and effective are printed by the game's number
formatter with **one decimal**. The arrow is the two characters `->`.

The damage table has four columns and five rows, two-space indent, columns three and four
right-aligned:

| | | `[W]Strength` | `[W]Organisation` |
| --- | --- | --- | --- |
| `[W]Battle` | `[W]dealt:` | `[Y]`a`[W]` | `[Y]`b`[W]` |
| (empty) | `[W]taken:` | `[Y]`c`[W]` | `[Y]`d`[W]` |
| `[W]Last tick` | `[W]dealt:` | `[Y]`e`[W]` | `[Y]`f`[W]` |
| (empty) | `[W]taken:` | `[Y]`g`[W]` | `[Y]`h`[W]` |

All eight figures are thousandths printed with one decimal by the game's formatter. The first
two cells of the heading row are empty. Column alignment in a proportional font is described
under "Shared machinery: columns in a tooltip" below.

*The damage tallies (land combat only).* BiceLib counts them itself, from two places in the
game's land combat (source):

- *A shot lands.* Where land combat has worked out one shot's damage and is about to apply it
  to the target unit, BiceLib has the firing unit, the target unit, the strength damage, the
  organisation damage and the firing side's battle. Strength damage is added to the firer's
  "dealt" and the target's "taken" at once. Organisation damage is only *noted* against the
  target as asked-for: per target, a list of up to 16 distinct attackers with what each has
  asked, and the total asked (asks beyond the 16th attacker still count in the total, credited
  to no one). The first shot to arrive after a settle (below) starts that list afresh.
- *Damage is settled.* Where a brigade's pending damage is actually taken off it, the
  organisation removed has already been capped by the game at what the brigade still has.
  That capped amount is added to the brigade's unit's "organisation taken" (only for a unit
  that already has a tally), and is shared out to the attackers on the target's list in
  proportion to what each asked: `share = removed x asked / total asked`, then
  `share x 1000 / the target's number of brigades` is added to that attacker's "organisation
  dealt" (kept a thousand times finer to avoid cutting small shares to nothing).
- *Reading.* Strength dealt and taken are the sums as they are. Organisation taken is the sum
  divided by the unit's present number of brigades (a unit's organisation being the average of
  its brigades'); organisation dealt is its sum divided by 1000. Whole-number division, cut.
- *One battle.* Each unit's tally remembers which battle it belongs to. A shot that arrives
  for a different battle clears the unit's tally first, so the figures are the current (or
  most recent) battle's, not a running total. Nothing clears a tally when a battle ends - a
  unit keeps showing its last battle's figures until it fights again. When the game records a
  finished land combat (signalled through the combat-record hook, which belongs to the combat
  log feature and exists only if that is recording), the tallies stamped with it are marked
  finished, so a later battle can never be mistaken for it.
- *One round ("Last tick").* The same four figures are kept a second time, stamped with the
  game hour in which they arrived; the first damage under a later hour clears them. So they
  read as the last hour in which the unit dealt or took something, not as the current hour.
- *Which units have figures.* The "Damage" part is shown only for a unit that has a tally,
  i.e. that has fired or been hit in land combat since the process started (and has not been
  pushed out of the table). Tallies are keyed by the unit's type and id, hold up to 4096 units,
  and a newcomer that finds its eight candidate places taken evicts one other unit's figures.

**Inputs a mod gives it** - None. No Lua arguments; no localisation keys (the block is
hard-coded English); the tooltip font as named by the `ToolTip` text box type in
`interface/core.gui` (`Arial14` in the base game and the mod) is used for alignment.

**When it applies** - From the call on. If the damage counting cannot be installed the stat
block still is (the failure is logged). Once per process, not reversible. Neither the damage
counting nor the tooltip font probe has a Lua switch of its own: the damage counting is
installed by this call and by nothing else, and the font probe (next section) is armed on
demand by the stat block itself; this call also reads the `Arial14` font descriptor from disk
once, so that no file is read while a tooltip is being drawn. (source)

**Multiplayer and saves** - Display only: the two combat hooks observe and pass the game's own
calls on unchanged. The tallies are in memory only - not saved, empty after a restart, and not
cleared when another game is loaded in the same process (they are keyed by unit id). Each
machine counts for itself.

**Where the player sees it** - The battle window: the tooltip of a land unit entry (committed
units, and the defender's reserves).

State in the mod: called in the committed `script/bicelib_lua.lua`. The source also keeps the
last unit a battle tooltip was about for two reverse-engineering probes
(`BiceLib.Reversing` write watches); that is tooling, not part of the feature.

### Shared machinery: columns in a tooltip (the text table and the tooltip font probe)

Kind: infrastructure
Switch: none of its own - installed and used by activateCombatUnitStats

**What the original does without it** - Tooltips are drawn in a proportional bitmap font (the
`ToolTip` text box type's font, `Arial14`), so padding a label to a fixed number of characters
does not line a second column up. The game's own string-width routine, for a font: skips a
colour escape and the character after it; adds each glyph's advance (nothing for a glyph the
font lacks); adds the kerning between a glyph and the literal next character (escape or not);
treats a line break as ending a line and returns the widest line; and has widths for the icon
escapes. The font's descriptor (`gfx/fonts/<name>.fnt`, AngelCode text format) is where the
advances and kerning pairs come from. (reversing/findings/FINDINGS-text.md)

**What the feature does** -

*Table layout* (source). A table is rows of cells, an indent text put before every row, a gap
between columns (default: twice the width of a space), and per-column alignment (left by
default, or right). Cells carry their own colour escapes, which are neither added nor counted.
Rendering:

1. A column's width is the widest of its cells, in pixels.
2. Column starts: the first starts at the width of the indent; each next one at the previous
   start + previous width + gap.
3. Each row: write the indent; then for each cell, the target position is its column's start
   (plus column width minus cell width when right-aligned); pad from the current position to
   the target with spaces - the number of spaces is (distance + half a space) divided by the
   space width, cut, i.e. the nearest whole number of spaces, and never fewer than one for any
   column after the first; the current position then becomes where the padding actually ended
   plus the cell's width (so rounding does not accumulate along a row).
4. A row with fewer cells just ends early; nothing is padded after a row's last cell; rows are
   joined with line breaks and there is no trailing line break.

Padding can only be whole spaces, so a column lands within half a space (one or two pixels)
of where it was aimed; that is a property of the medium (comment).

*Measuring* (source). Widths come from the game's own string-width routine for the font
tooltips are really drawn in, once that font is known. To learn it, BiceLib briefly listens on
the routine: after it has appended its block to a battle tooltip it starts listening for a
measured string that contains the word `effective`; the font used for that string is kept; at
the start of the next battle tooltip it stops listening and from then on measures through that
font. It tries at most three times per process and, once a font is caught, never listens
again. Until then - so for the first battle tooltip of a process - widths are computed from the
descriptor `gfx/fonts/Arial14.fnt` (looked for in the mod, then the game's `tfh` folder, then
the game's root): each character's advance plus kerning with the literal next character,
colour escapes skipped, widest line. If no descriptor is found every character counts as one
unit (plain character counting). A caught font that measures a space as 0 or less is refused
and the descriptor stays in use.

A native implementation has no need of the probe: it should measure with the tooltip's actual
font and apply the table algorithm above.

**Multiplayer and saves** - Display only; the caught font is per process.

### BiceLib.Tooltips.activateParadropLine()

Kind: text
Switch: `BiceLib.Tooltips.activateParadropLine()`

**What the original does without it** - The division designer says nowhere whether the design
can be dropped by parachute. Its `terrainbonus` element's tooltip is the terrain summary the
designer keeps for the current design (one line per terrain, then river, night, fort and
amphibious, each with the design's averaged attack, defence, movement and attrition
adjustments); an empty design has an empty summary and so no tooltip. The game's rule for
putting a land unit aboard transport planes requires, among other things, that **every
brigade** of it has `can_paradrop`, and that its transport weight - the brigades'
`transport_weight` summed and cut to a whole number - fits the planes' transport capability.
(reversing/findings/FINDINGS-buildertooltips.md, sections 2, 5 and 6;
reversing/findings/FINDINGS-transport.md, D.2)

**What the feature does** - The `terrainbonus` tooltip gets a first line saying whether the
design can be paradropped, followed by a blank line and then the original terrain summary
(source). English, hard-coded. For a design with at least one brigade:

- every brigade's type has `can_paradrop`:

      This unit [G]can[W] be paradropped (Weight: N)

- otherwise:

      This unit [R]can not[W] be paradropped (Weight: N):
         <name of a blocking brigade type>
         <name of the next>

  one line per *distinct* blocking type name, each indented three spaces, in the order the
  types first occur in the design. A type's name is the localised text of its key (the name the
  brigade picker shows), or the key itself when there is no text, or `?` when the key cannot be
  read.

Only `can` / `can not` are coloured. ` (Weight: N)` (with a leading space) is the design's
transport weight: each brigade's type **made at the player country's current technology
levels** (the design itself holds the unresearched types, and technology changes
`transport_weight` in this mod), their `transport_weight` summed in thousandths and divided by
1000, cut to a whole number. If the weight cannot be worked out (no player country, a figure
unreadable) the ` (Weight: N)` part is omitted and the rest still shows. After the line(s):
if the terrain summary is not empty, `\n\n` and the summary. An empty design adds nothing at
all (the tooltip stays empty and so stays hidden). If any brigade's `can_paradrop` cannot be
read, the tooltip is left as the game made it.

The weight is remembered for the last design asked about (the same list of brigade types, for
the same player country) and reused while the tooltip is rebuilt, so research completed while
the tooltip is up shows only after the next change to the design (comment).

The organisation and plane-capacity tests of the real boarding rule are not reported: a design
on paper has no organisation and no plane (comment).

**Inputs a mod gives it** - `can_paradrop = yes` and `transport_weight` in unit type files;
the unit types' localised names. No Lua arguments.

**When it applies** - From the call on, whenever the designer's terrain tooltip is built. Once
per process, not reversible.

**Multiplayer and saves** - Display only and local (uses the local player's country for the
technology levels). Nothing is stored beyond the remembered weight.

**Where the player sees it** - Production screen, division designer window, the terrain
summary element's tooltip.

State in the mod: called in the committed `script/bicelib_lua.lua`. Not mentioned in BiceLib's
README.

### BiceLib.Tooltips.activateCombinedArmsLine()

Kind: text
Switch: `BiceLib.Tooltips.activateCombinedArmsLine()`

**What the original does without it** - In the division designer, each combined arms indicator
icon (`combined_arms_indicator_<n>`, n counting the groups of `common/combined_arms.txt` from
1) has a tooltip that is the group's localised name, with the group's description
(`<key>_desc`) as the delayed part. It says neither how much the group adds nor whether it is a
*base* group. The designer's rule: a group's indicator lights, and the group adds to the
design's combined arms bonus, only when some brigade of the design is in that group **and**
some brigade of the design is in a group marked `base = yes`; what it adds is the group's
`value` plus the country's research bonus for that group. Combat gates the combined arms
modifier on a base group the same way. (reversing/findings/FINDINGS-buildertooltips.md,
sections 2 and 7; reversing/findings/FINDINGS-builders.md, section 2)

**What the feature does** - Two lines are added under the group's name in the tooltip's main
text (source). English, hard-coded:

    <group name>
    Combined arms bonus: <P>
    Base: [G]yes[W] - activates combined arms for the division

or, for a group that is not a base group:

    Base: [R]no[W] - counts only alongside a base brigade

`<P>` is the group's `value` plus the **player country's** research bonus for the group, as a
signed percentage with one decimal: thousandths divided by ten for the whole part and the
remainder for the decimal, always with a sign - a plus sign for zero and above, a minus sign
below (a total of 125 thousandths reads as plus 12.5 percent: sign, `12.5`, `%`). When the
research bonus is not zero, ` (<T> from technology)` follows on the same line, `<T>` being the
research part alone in the same format. Only `yes` / `no` are coloured. The delayed description
is untouched. If the group cannot be identified among the game's groups, or its figures cannot
be read, the tooltip is left as the game made it; a research bonus that cannot be read counts
as zero.

**Inputs a mod gives it** - `common/combined_arms.txt` (`base`, `value` per group) and the
technologies' combined arms bonuses. No Lua arguments.

**When it applies** - From the call on. Once per process, not reversible.

**Multiplayer and saves** - Display only and local (the local player's research). Nothing is
stored.

**Where the player sees it** - Production screen, division designer window, the combined arms
indicator icons' tooltips.

State in the mod: called in the committed `script/bicelib_lua.lua`. Not mentioned in BiceLib's
README.

## Part 3 - The command framework

### The command framework - `BiceLib.Commands.registerBiceCommands()`

Kind: infrastructure
Switch: `BiceLib.Commands.registerBiceCommands()`, called in the top-level block of `script/bicelib_lua.lua`.

**What the original does without it** - every change a player or an AI makes to a running game is a *command*: an object naming what to do and to what, posted to the session's command channel. In single player and multiplayer alike a posted command is serialised (in the savegame's own key-value format, its first token naming the command's type), and what later runs is not the object posted but one rebuilt from that serial form by cloning a prototype the game keeps for each type in a process-wide registry. In multiplayer the serial form is broadcast, and every machine drains the commands through one ordered loop, each running the command's `Execute`. That ordering is the whole of how machines stay in step. The set of command types is fixed in the executable: a mod can post existing commands from Lua but cannot add an action the game has no command for (reversing/findings/FINDINGS-commands.md). (comment)

So an action a mod (or the DLL) performs by writing game state directly, or decides inside a command from something only one machine knows - a pressed key, the local selection, which country the local player plays - happens on one machine only, or differently on each: a desync.

**What the feature does** - it adds **one** new command type to the game's registry, the *BiceCommand*, whose only content is a text payload in a format of BiceLib's own. The payload names a **kind** (which mod action this is) and carries up to 32 integer arguments. Any number of mod actions then ride on the one type: adding an action is choosing a kind number and writing a handler; nothing about the game's own types has to be learnt again. (source)

*The payload, format version "B1"* (source) - a string of fixed-width upper-case hexadecimal digits with no separators:

    "B1"  kind (4 digits)  count (2 digits)  count arguments (8 digits each)

- The whole string is `8 + 8 x count` characters; `count` is 0 to 32.
- `kind` is an unsigned 16-bit number. Each argument is a signed 32-bit integer in two's complement.
- Decoding is strict: the first two characters must be `B1`; every other character must be a hexadecimal digit; `count` must be at most 32; and the length must equal `8 + 8 x count` exactly. Anything else is refused whole - never partly read. A future incompatible format would use another version marker and be refused by builds that only know "B1".
- Text was chosen over raw bytes because the value passes through the game's own writer and reader of quoted strings in text saves and of raw strings in binary ones; an alphabet without quotes, backslashes, whitespace or the game's colour marker survives both unescaped. Strings are deliberately not an argument type; an object reference travels as its persistent id pair, two integers, which is how the game's own commands name a unit or a leader so that it means the same on every machine.

*The command object* (source) - it behaves as an ordinary game command in every respect the game asks about: it may always be posted; it is not recorded after it runs; it saves itself as the base command's own keys plus one extra key whose value is the payload string; it loads that key back; it can be cloned, the clone carrying the payload. The type id and the payload's key are two fixed, otherwise unused ids of the game's built-in save-token table, identical in every process running the same executable - deliberately not tokens a mod's content could shift.

*Kinds* (source) - a kind is declared in the DLL with `registerKind(kind number, name, handler)`: the name is for the log only, the number is what travels. At most 64 kinds; declaring a number twice is refused. Kind numbers are BiceLib's own, allocated in one append-only list: renumbering an existing kind would break multiplayer against an older DLL, while adding one at the end is safe.

*Posting* (source) - `post(kind, arguments, count)` builds one command and hands it to the session's command channel, exactly as the game's own user interface posts. It refuses, with an error line and a false result, when: the type is not registered; the kind is not registered on this machine (posting a kind nothing handles is caught where it was made, not as a silent nothing everywhere); the arguments do not encode (more than 32, or a count without arguments); or no game is on screen (the game's own "in game" flag). The channel takes ownership of the object.

*Running* (source) - when the command comes out of the channel, on **every** machine, it decodes its payload and calls the handler registered for the kind with the arguments exactly as posted. An undecodable payload, or a kind this build does not know, is logged and does nothing - on a machine running a different BiceLib that is a divergence the framework can report but not prevent. Each run prints one line to the debug console (kind name and number, argument count, and the command's turn stamps).

*Registering* (source) - `registerBiceCommands()` puts the prototype in the game's registry and then declares the kinds that exist (today: the example). It answers false, changing nothing, when the registry is not initialised, when another class already claims the type id, when the game command it models itself on is not what this build should hold, or when either token id is outside the game's token table. It is idempotent, and there is deliberately no unregister: the registry outlives any one game and would be left pointing into the DLL.

**The rule that makes it multiplayer safe** - stated in the source three times, and binding on every kind:

> A handler runs on every machine in the game, inside the ordered command loop, so it must do the same thing everywhere. **Everything it needs has to arrive in its arguments.** A local input may choose *which* commands to post; it may never change *what* a command does when it runs.

So the keyboard, the mouse, the local selection and "who am I playing" are read where only the acting player's machine runs - a click handler, an overlay page - and turned into commands that name their own targets by id. Reading any of them inside a handler makes the handler do something different on each machine, which no test inside the handler can repair. The Ctrl-unassign feature is the worked example of getting this wrong first and right second. (comment; reversing/findings/FINDINGS-commands.md, point 5)

**Inputs a mod gives it** - nothing from Lua beyond the registering call: kinds and handlers are C++ in the DLL. There is no Lua function that posts an arbitrary kind.

**When it applies** - **once per process, and before anything is posted - in single player too.** The single-player post also serialises the command and rebuilds it through the registry, so with the type unregistered the rebuilt object is nothing and the post carries on regardless; and the receiving side of multiplayer silently drops a command whose type it does not know, so every moment before registration is a window in which a peer's command is ignored here. No game needs to be running: the registry exists from process start to process exit. The mod therefore registers at the top level of its Lua, not in a session. (source for the call's behaviour; comment for the game's)

**Multiplayer and saves** - this is the multiplayer mechanism. A BiceCommand is not kept after it runs, so nothing of it reaches a savegame except through what its handler did to game state. All machines must run the same BiceLib (same kinds, same numbers). The round trip was tested in single player and multiplayer on 2026-10-05 (comment).

**Where the player sees it** - nowhere directly.

### The existing kinds: "ping" and `BiceLib.Commands.postExampleCommand(args)`

Kind: tooling
Switch: the kind is declared by `registerBiceCommands()`; a ping is posted by `BiceLib.Commands.postExampleCommand(args)`, which nothing in the mod calls.

**What the feature does** - **kind 1, "ping", is the only kind that exists.** Its handler prints its arguments to the debug console and does nothing else: `BiceCommand ping: no arguments`, or `BiceCommand ping: [a, b, c]` with the integers in decimal, comma-and-space separated, on one line. It exists to exercise the framework: in single player a logged line proves the type id, the prototype, the serial form, the rebuild and the clone; with arguments it proves the payload survives; in multiplayer every machine should log the same line for the same post. (source)

No feature of BiceLib posts a BiceCommand today. The features that act on the game from an input - Ctrl-unassign, the overlay's pages - post the game's **own** commands (assign leader, set variable, and so on), which were already sufficient for them.

**Inputs a mod gives it** - `postExampleCommand(args)`: `args` is an optional Lua table (array from 1) of numbers, at most 32; omitted, nil or `{}` posts a ping with no arguments. Each number is converted to a 32-bit integer (a fraction is cut). The call returns false and posts nothing when `args` is neither nil nor a table, when the table is longer than 32, when any entry is not a number (refused, never coerced: a silent 0 would be a different command on every machine at once), or when `post` refuses as described above. Otherwise true. (source)

**When it applies** - in a running game, after registration.

**Multiplayer and saves** - runs on every machine; changes nothing; nothing saved.

**Where the player sees it** - only in the debug console.

## Part 4 - The overlay's core and what it drives

### The overlay - `BiceLib.Overlay.enable()` and `BiceLib.Overlay.toggle()`

Kind: interface
Switch: `BiceLib.Overlay.enable()`, called at the end of the mod's `script/gui-imgui.lua`, which `script/autoexec.lua` requires only when the global `G_ImguiUtilityEnabled` (set in `script/utility_settings.lua`, committed value `true`) is true. There is no call that removes it again; it stays for the life of the process.

**What the original does without it** - nothing: this is new. The original game has no in-game utility window, and the mod's older utility (the wxWidgets one, `G_UtilityEnabled`, committed value `false`, called deprecated in `autoexec.lua`) opened separate desktop windows.

**What the feature does**

*Enabling.* `BiceLib.Overlay.enable()` does five things in this order and returns one boolean, true when the drawing hooks went in (source):

1. installs BiceLib's crash reporter (described in its own section);
2. installs the pure-virtual-call handler (described in its own section);
3. installs the drawing hooks: from then on BiceLib runs once for every frame the game presents, just before the frame reaches the screen, once whenever the graphics device is reset (resolution change, alt-tab), and once for every texture the game creates (the last only counts textures for the Debug group's Memory page). Calling it again is harmless: the hooks are installed once per process;
4. puts back the saved Custom Auto-Saves settings (see that section);
5. puts back the saved map edge scrolling setting (see that section).

Steps 4 and 5 run whether or not step 3 succeeded. Failure of step 3 logs `[ERROR] Could not install the ImGui overlay`. The mod calls `enable()` once per Lua state, because `autoexec.lua` runs once per state; only the first call does anything (source).

`BiceLib.Overlay.toggle()` flips shown/hidden exactly as the toggle key does and returns the new state as a boolean (true = now showing) (source).

*First presented frame.* On the first frame after enabling, BiceLib finds the game's own window from the graphics device, sets the user interface library up (docking on; the mouse cursor is never changed by the overlay - the cursor is always the game's), applies the theme, and puts its own handler in front of the game window's message handler. It logs `[INFO] Overlay: ImGui ready - press INSERT to toggle` (the text names INSERT even when the key has been rebound). The overlay **starts hidden** (source).

*What runs on every presented frame, in this order* - this list is the set of behaviours that are "on with the overlay" (source):

1. Remember which thread is presenting (thread diagnostics, shown on the Debug group's Thread Check page).
2. The one-time setup above, if it has not succeeded yet.
3. One warm-up step (see "Warm-up" below). Runs hidden or shown, at the main menu too.
4. The combat record store's update - files finished battles away for the Combat Reports page (described in its own section). Runs hidden or shown.
5. Sample the game clock (see "The game clock guards" under the daily callback).
6. The reverse-engineering field watch sample, only if that probe was armed from Lua (tooling, described in its own section).
7. The custom map mode's once-a-game-day repaint while that map mode is on (described in its own section).
8. The daily callback into the mod's Lua, `BiceLibDailyPeriodics` (see its section).
9. The reverse-engineering counters' once-a-game-day row, only if that probe was armed (tooling).
10. The out-of-memory watch: checks how much address space is left and saves and closes the game rather than letting it die (described in its own section). Runs hidden or shown.
11. If the game window is minimised or has an empty client area: draw nothing this frame and leave the layout untouched (a frame drawn into a minimised window would squeeze every overlay window into a corner and that would be saved).
12. If the overlay is showing: on the first frame after being shown, ask each dock to put back the tab it was showing when the overlay was hidden; then draw all overlay windows. If the overlay is hidden: on the first hidden frame write the layout file out at once; and, only where pages may be dragged out of the game window, draw four empty frames so that detached windows close.
13. Hand the frame on to the game's own present.

Steps 3 to 12 happen only once the one-time setup has succeeded. Messages queued with `BiceLib.Messages.show` are **not** raised from this hook (see that section), and the autosave decision is not made here either (see Custom Auto-Saves).

*Crash guard.* The drawing in step 12 is guarded. If it faults, a crash report is written, the log says `[ERROR] The overlay crashed and has been switched off. The report is <path>`, and the overlay draws nothing more for the rest of the process. The game carries on, and steps 3 to 10 keep running (source).

*Input.* While the hooks are in, BiceLib sees every message sent to the game window before the game does, and applies these rules in order (source):

1. The window-menu command that tapping Alt produces is swallowed, always (overlay shown or hidden). Tapping Alt would otherwise start Windows' own menu loop, which freezes the game's drawing until a click. Alt-F4 and Alt-Enter are different commands and still work. The cost is the window menu on Alt and Alt-Space.
2. A mouse wheel message is first offered to the tall-requirement-tooltip scroller (a separate feature, `BiceLib.EffectTexts.activateTriggerScroll`); if that feature takes it, the game does not see it.
3. On a key-down: if the Utility Options page is waiting for a new toggle key, the key is swallowed and, unless it is Escape, becomes the toggle key. Otherwise, if the pressed key is the toggle key and no overlay text box currently has the keyboard, the overlay is shown or hidden and the key is swallowed.
4. Only while the overlay is showing: the message is given to the overlay. Mouse messages are then swallowed when the overlay wants the mouse (the pointer is over an overlay window, or an overlay drag is in progress) and keyboard messages when the overlay wants the keyboard (a text box or overlay navigation has it). Everything else goes on to the game, so the map can still be scrolled and clicked beside the overlay's windows.
5. While hidden the overlay receives no input at all. Showing or hiding it also discards any input the overlay had queued and any keys it thought were held, so neither side inherits the other's key presses.

*Toggle key.* INSERT by default (Windows virtual key 45). Rebindable on the Utility Options page; stored as setting `overlay.toggleKey`. A stored value outside 1 to 255 is ignored and INSERT is used. The key works at the main menu as well as in a game. There are no other global hotkeys (source).

*Main menu versus a game.* The hooks, the toggle key, the layout and every page's window work the same in both. What differs is the data: every call a page makes into the mod's Lua is refused outside a running game (see "Lua bridge" below), so at the main menu pages show `Lua unavailable: no game session` or their own equivalent. Pages that read nothing from Lua (Utility Options, Custom Auto-Saves, the map half of Game Settings) work fully at the menu. The warm-up is the one thing that deliberately calls the mod's Lua at the menu (source).

*Windows and layout* (source):

- **The control window**, titled `Utility`. Always present while the overlay is showing; cannot be docked. It has a menu bar with two menus and a row of small buttons:
  - menu `Windows`: one checkable entry per group that shows or hides that group's window, a separator, and `Show all` which opens every group window;
  - menu `Pages`: every page, listed under a greyed caption per group with a separator between groups, each a checkable entry that opens or closes that page;
  - one small button per group, in group order, each toggling that group's window; the buttons wrap onto further lines when the window is narrow.
  First-run position 40,40; first-run width 520; minimum width 160.
- **One window per group**, titled `Utility - <group>`. Each holds a dock area of its own; the group's pages are tabs in it. First-run size 720 by 520, first-run position (80 plus 28 times the group's index) on both axes so the windows are staggered. A group window has no menu of its own. Closing a group window hides its pages without undocking them.
- **Groups, in order**: `Setup`, `Country Info`, `Game Info`, `Inspector`, `Stats`, `Options`, `Help`, `Debug`. A page naming any other group sorts after these and gets a window of its own for that group. Only groups that have at least one page get a window.
- **Order of pages**: by group, then by the page's order number (low first; default 1000), then alphabetically by title. That is the order of the tabs on a first run and the order of the `Pages` menu.
- **The pages as built** (title, order number) - their contents are described in other sections:
  - Setup: Country (10), Special (15), Misc (130)
  - Country Info: Country Modifiers (20), IC Days (30), Puppets (40), Strategic Res. (50), Resource Conversion (55), Strategic Trades (60), Global Market (70), National Focus (80), Minister Buildings (90), Trade AI (100), Prod. Sliders AI (110), LS Sliders AI (120)
  - Game Info: Traits (50), Generals (60), Modifiers (70), Techs (80), Units (90), Unit Models (100)
  - Inspector: Unit Inspector (10), OOB Browser (15), OOB Report (16), Combat Reports (17), Active Flags (20), Active Variables (30), Active Event Modifiers (40), Province Buildings (50), Custom Mapmode (55)
  - Stats: Setup (10), Statistics (20)
  - Options: Game Settings (10), Custom Auto-Saves (20), Utility Options (30)
  - Help: Misc (10), Ministers + Buildings (20), National Focus (30)
  - Debug: Thread Check (10), Memory (20), Lua Console (30), Timing (40), and one reverse-engineering probe page (60; its title names a build-specific index and is left to the tooling section)
- **Window identity.** A page's window is known by its title; where two pages share a title (`Misc` in Setup and Help, `National Focus` in Country Info and Help) each gets the hidden suffix `##<group>` so they stay distinct. The suffix is part of the saved names.
- **A page's group only decides where it starts.** On a first run with no layout file each group's pages are docked as tabs of that group. After that the player's arrangement wins: a tab can be dragged to another group's window, split beside another tab, or floated on its own, and it stays there, including for a page whose group changed in a later build.
- **Dragging a page out of the game window** into an operating-system window of its own (for a second monitor) is possible only when the game is not in exclusive fullscreen and the presenting thread owns the game window. This is re-checked after every device reset; switching to fullscreen pulls detached pages back inside over the next frames. Detached windows have no task bar entry, do not take keyboard focus when they appear, and are closed while the overlay is hidden.
- **Defaults for what is open**: every group window closed, every page open - so on a first run the overlay comes up showing only the control window. What is open is remembered per window in the settings file (keys `groups.<group>` and `pages.<window name>`), written when a value changes. On start everything is opened for three frames so pages can settle into their docks, then the saved open/closed states are applied.
- **Tab memory.** While hidden nothing is drawn, so on showing again each dock is told to reselect the tab it showed before; this is retried for at most 30 frames and stops once the selection has held for two frames running.
- **Keyboard tab switching.** With a docked page focused, Left/Right arrow or A/D step to the previous/next tab of that dock, wrapping round. Disabled while a text box has the keyboard and on a page that declares it uses those keys itself (only the OOB Browser).
- **Timing.** The time each page's drawing takes is recorded (first, last, worst, count) for the Debug group's Timing page.

*Layout file.* `BiceLibImGui.ini`, in the folder `BiceLib.dll` is in (the mod's `script` folder). It is the user interface library's own layout file: window positions and sizes and which window is docked where. It is written periodically while the overlay is showing (about five seconds after a change (comment)) and at once when the overlay is hidden. Deleting it restores the code's arrangement; so does `Reset layout...` on the Utility Options page. Whether each window is open is not in this file but in the settings file (source).

*Fonts, scale, theme.* No font file is loaded: the overlay draws with the user interface library's built-in default font. There is no DPI handling. One global text scale, 0.60 to 2.00, is adjustable on the Utility Options page and is not saved. Four themes exist, chosen on the Utility Options page and stored as setting `gui.theme` by id; an unknown or missing id means `dark` (source). Each theme is eleven surface colours plus eight "meaning" colours pages use for warnings and the like (decimal R,G,B):

| role | dark | grey | light | army_green |
| --- | --- | --- | --- | --- |
| deep (behind everything, menus, input fields) | 16,16,18 | 58,60,64 | 226,226,222 | 45,45,31 |
| panel (window background) | 26,26,28 | 78,80,85 | 244,244,240 | 74,74,51 |
| raised (buttons, table headers) | 44,44,48 | 98,101,107 | 214,214,208 | 96,96,66 |
| hover | 58,58,64 | 118,122,129 | 198,202,212 | 122,122,84 |
| active | 74,74,82 | 138,142,150 | 176,184,202 | 146,146,100 |
| edge (borders, separators) | 10,10,12 | 44,46,49 | 178,178,172 | 32,32,22 |
| text | 236,236,236 | 232,234,237 | 28,28,26 | 232,232,216 |
| dim text | 128,128,132 | 160,164,170 | 122,122,116 | 150,150,128 |
| accent | 66,150,250 | 104,160,220 | 28,96,168 | 226,162,38 |
| dim accent | 44,100,168 | 70,110,155 | 120,156,200 | 150,108,26 |
| positive (filling bars) | 96,180,110 | 110,180,120 | 38,132,62 | 122,176,74 |
| mark: warning | 204,153,51 | 230,180,70 | 158,100,0 | 226,162,38 |
| mark: error | 217,89,89 | 232,110,105 | 180,30,30 | 196,74,62 |
| mark: error, dim | 158,87,87 | 180,95,90 | 140,60,60 | 146,62,54 |
| mark: error fill | 115,38,38 | 96,52,50 | 248,214,214 | 74,34,30 |
| mark: success | 115,217,115 | 130,210,130 | 20,118,48 | 140,196,88 |
| mark: success fill | 66,150,89 | 80,140,95 | 96,168,112 | 100,146,62 |
| mark: info | 140,179,230 | 150,190,235 | 20,84,160 | 150,178,214 |
| mark: strong | 255,255,255 | 255,255,255 | 0,0,0 | 255,250,232 |

Theme display names: `Dark`, `Grey`, `Light`, `Army green`. The focused window's title bar and the selected tab are tinted with the accent; frames have a one-unit border and corners rounded by two units; windows that may be detached from the game are forced to square corners and an opaque background (source).

*The Lua bridge - the contract between pages and the mod's Lua* (source):

- Pages call functions of the mod's Lua **by dotted path under the global table `BiceLibGui`**, for example `BiceLibGui.Options.Collect`. The first segment is looked up in the globals of the Lua state, each further segment by indexing the table before it; the last must be a function. A missing segment is reported as `'<path up to it>' is nil`, a non-table in the middle as `'<path>' is not a table`, a non-function at the end as `'<path>' is not a function`.
- The Lua state used is the one the presenting thread itself most recently entered BiceLib from (the game presents and runs Lua on the same thread). It is not "the first state that loaded BiceLib".
- Calls take no argument, one string, one number, or a string and a number, and run **inside a protected call**. A Lua error is logged as `[ERROR] LuaBridge: <path> failed: <message>` and the call counts as failed with reason `the Lua call raised an error`.
- Calls made for data must return **one table**; anything else fails with `the Lua call did not return a table`. From that table the page reads plain fields only: numbers, booleans (an absent field gives the caller's default; any other value is its truthiness), strings, arrays of strings, and arrays of flat tables. Every string read is converted from Windows-1252 to UTF-8 at this point.
- **By convention every answer carries `available` (boolean) and, when false, `reason` (string).** The mod's `Page.Guard(fn, ...)` helper (`script/utility_imgui/imgui_page.lua`) runs a page function under `pcall` and turns an error into `{ available = false, reason = <error text> }`, so a Lua error reaches the player as text on the page.
- **A call is allowed only when all four hold**, checked in this order, and the first failure is the reason a page shows:
  1. a game is on screen - reason `no game session`;
  2. the caller is on the presenting thread - `not on the render thread`;
  3. that thread has run Lua through BiceLib at least once - `the render thread has not run Lua yet`;
  4. no BiceLib Lua function is already executing on this thread - `a Lua call is already in flight`.
- **The session guard (condition 1) is the game's own "a game is on screen" flag**, not the existence of the game state object. The game state object is created once per process and exists from the main menu onward, so testing its pointer answers "yes" at the main menu - exactly where the game's Lua API faults inside the game's own code, which a protected call cannot catch. The flag is raised at exactly one point, on entering a running game after the session is built and before the in-game interface is built, and lowered on returning to the front end; it is not raised during a load (findings: `reversing/findings/FINDINGS-session.md`).
- Two callers lift condition 1 for the length of one call: the warm-up (it only parses mod files) and the Debug group's Lua Console when its `Needs a session` box is unticked.

*Warm-up* (source). The mod's data providers parse the mod's files lazily, so the first page opened would otherwise stall for seconds. With the warm-up on, the overlay calls the mod's Lua once per presented frame, hidden or shown, at the main menu or in a game, until all sets are parsed:

- Nothing happens for the first 5000 milliseconds after the first frame, so it does not compete with the game's own loading.
- On the first frame Lua can be reached it calls `BiceLibGui.Warmup.State()` once, which must return `{ available = true, done = <bool>, remaining = <n>, total = <n>, enabled = <bool> }`. `enabled` is `G_ImguiWarmupEnabled ~= false` - only an explicit `false` in `utility_settings.lua` turns the warm-up off. This is the only moment the setting is read.
- On each later frame it calls `BiceLibGui.Warmup.Step()`, which parses exactly one set and returns `{ available = true, done = <bool>, remaining = <n>, name = <set name> }`. An answer with `available` false ends the warm-up for good.
- The sets, in order (worst first): `Unit models`, `Generals`, `Units`, `Technologies`, `Traits`, `Modifiers`, `Province buildings`. Each step calls the matching provider's parse (`BiceData.UnitModels.Choices(nil)`, `BiceData.Generals.ForCountry(nil)`, `BiceData.Units.Choices()`, `BiceData.Techs.ModifierValues()`, `BiceData.Traits.Choices()`, `BiceData.Modifiers.Choices()`, `BiceData.ProvinceBuildings.Choices()`). A step that throws is not retried: the step counter is advanced before the step runs.
- The Debug group's Timing page reports progress (`<done> of <total> - last: <name> (<ms> ms)`, `done, <ms> ms spent up front`, `waiting to start`, or `off - pages will parse when first opened`) and has a `Parse now` button that runs all remaining steps at once (at most 32), freezing the game while it does. That button goes through the normal session rule, so it only works in a game.
- With the warm-up off, the same parsing happens when a page first asks.

*The country every page reports on* (source). One "selected country" is shared by all pages. While the overlay is drawing it is re-read every 2000 milliseconds (and immediately after the player changes it) by calling `BiceLibGui.Country.CurrentTag()`, which returns `{ available = true, tag = "GER" }` or `{ available = false, reason = "No player country" }`. The rule is the mod's (`BiceData.Players.CurrentTag`):

- the choice lives in the Lua global `G_PlayerCountry` (per Lua state, not in the savegame);
- if nothing has been chosen it becomes the tag of the country the local player is playing (`CCurrentGameState.GetPlayer()`), remembered as an automatic choice;
- an automatic choice follows the player when a different game is loaded; a deliberate choice is left alone;
- the Setup group's Country page can point the pages at **any** country tag, not only a human player's, by `BiceLibGui.Country.SelectPlayer(tag)` (the tag is upper-cased). It is refused, with the reason `not a country, or its player does not allow it`, when the tag names no country or that country's variable `disable_gui_access` equals 1. That country variable is the opt-out by which a player stops others inspecting their country.

*`script/gui-imgui.lua`* (source). Runs once per Lua state. It creates the global `BiceLibGui` if absent, then requires one Lua module per page inside `pcall`, so a broken page cannot abort `autoexec.lua`. Each module must define its table on `BiceLibGui`; a module that loads without defining its key is reported as failed (the usual cause is a module-name collision with the old utility, which is why every module file is prefixed `imgui_`). The list, as module -> key: `imgui_country` -> `Country`, `imgui_ic_days` -> `ICDays`, `imgui_countryinfo` -> `CountryInfo`, `imgui_puppets` -> `Puppets`, `imgui_stratresources` -> `StratResources`, `imgui_trades` -> `Trades`, `imgui_natfocus` -> `NatFocus`, `imgui_ministerbuildings` -> `MinisterBuildings`, `imgui_tradeai` -> `TradeAi`, `imgui_prodsliders` -> `ProdSliders`, `imgui_lssliders` -> `LsSliders`, `imgui_resourceconversion` -> `ResourceConversion`, `imgui_misc` -> `Misc`, `imgui_options` -> `Options`, `imgui_help` -> `Help`, `imgui_stats` -> `Stats`, `imgui_console` -> `Console`, `imgui_warmup` -> `Warmup`, `imgui_traits` -> `Traits`, `imgui_generals` -> `Generals`, `imgui_modifiers` -> `Modifiers`, `imgui_techs` -> `Techs`, `imgui_units` -> `Units`, `imgui_unitmodels` -> `UnitModels`, `imgui_provincebuildings` -> `ProvinceBuildings`, `imgui_oob` -> `Oob`, `imgui_combat` -> `Combat`. It logs `gui-imgui loaded pages: <list>` and, if any, `gui-imgui FAILED pages: <module: reason | ...>` through `BiceLibLuaLog`, and finally calls `BiceLib.Overlay.enable()` if BiceLib loaded. `autoexec.lua` requires it inside `pcall` and logs `gui-imgui failed to load: <error>` on failure. Before it, `autoexec.lua` requires `utility_settings` and `bicedata` (the shared data providers, which hold no interface and parse nothing until asked).

*Sprites in pages* (source). Pages can show the mod's `.tga` pictures (the Unit Models page does). A picture is read from the path the mod's Lua reports, decoded if it is an uncompressed or run-length-encoded true-colour TGA of 24 or 32 bits per pixel (anything else is refused, and the page shows no picture), and kept for the rest of the process keyed by path.

**Inputs a mod gives it** - `G_ImguiUtilityEnabled`, `G_ImguiWarmupEnabled` (`script/utility_settings.lua`); the global table `BiceLibGui` with one sub-table per page; `BiceLibGui.Warmup.State`/`Step`; `BiceLibGui.Country.CurrentTag`/`SelectPlayer`; the Lua global `G_PlayerCountry`; the country variable `disable_gui_access`; the log function `BiceLibLuaLog` (source).

**When it applies** - from the first frame after `enable()` until the process ends. It cannot be switched off again in a running process; turning `G_ImguiUtilityEnabled` off and restarting means the hooks are never installed, and with them everything in the per-frame list above (and the saved autosave and edge-scroll settings) is off.

**Multiplayer and saves** - purely local. The overlay itself posts no game commands and writes no game state; individual pages that change the game do so through game commands and are described in their own sections. Nothing of the overlay is in the savegame: layout, open windows, theme and toggle key are per install; the selected country is per Lua state and falls back to the local player.

**Where the player sees it** - over the game, on pressing INSERT.

### Options page: Utility Options

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`); the page is in the Options group, third tab.

**What the original does without it** - nothing: this is new.

**What the feature does** - settings of the overlay itself; nothing here changes the game (source).

Section `This overlay`:
- Text `Open and close with`, then a button labelled with the toggle key's name as Windows names it (for example `Insert`; a key Windows has no name for shows as `Key <number>`). Clicking it turns it into the disabled prompt `press a key...` with a `Cancel` button beside it; the next key pressed becomes the toggle key and is saved (setting `overlay.toggleKey`), except Escape, which cancels. The key pressed is not passed on to the game. Help text: `Click it, then press the key to use. Escape cancels. A letter still types normally into a text box, so only a key pressed outside one opens the overlay.`
- Slider `Font size`, 0.60 to 2.00, shown as a multiplier with two decimals followed by the letter x, clamped even when typed; scales all overlay text. Button `Reset` sets 1.00. Not saved: it returns to 1.00 when the game restarts.
- Only when pages cannot be detached: the warning line `Pages cannot be dragged out of the game window.` with a tooltip explaining that this needs windowed or borderless mode.
- Button `Reset layout...` with the note `Puts every window back where the code puts it`. It opens a confirmation dialog `Reset layout?` with the text `Every page goes back to being a tab of its own group, every window forgets its position and size, and what is open goes back to the defaults. The building and map mode settings are not touched.` and buttons `Reset` and `Cancel`. `Reset` takes effect at the start of the next frame: every page, group window and the control window forget position, size and docking; each group's dock is rebuilt with its own pages in sorted order; the open/closed settings are returned to their defaults (groups closed, pages open) in the settings file; then the ordinary start-up sequence applies them.
- Line `Saved settings: <full path of the settings file>` (omitted if the DLL's folder could not be determined).

Section `Theme`: one radio button per theme (`Dark`, `Grey`, `Light`, `Army green`) with the theme's description as tooltip (`Dark grey panels with a blue accent, which the utility has always used. Easiest to pick out over a busy map.` / `Mid grey panels: the dark theme's readability without its weight, if the dark one is heavy and the light one glares.` / `Paper: the overlay as a document over the map. For playing in daylight, or if the dark styles are hard to read.` / `Olive panels, amber headings.`). Choosing one applies it at once and saves it (setting `gui.theme`).

Section `Crash reports`: explanatory text; button `Write a test report` (writes a report for a deliberately raised exception; status `Test report written`); button `Copy folder path` (copies the crash report folder's path to the clipboard; status `Folder path copied`); the folder path; and, once any report was written this session, `<n> written this session, the last being <path>`. The crash reporter itself is described in its own section.

Section `Debug console`: buttons `Open` and `Detach`, which call the Lua functions `BiceLib.startConsole` and `BiceLib.stopConsole` through the Lua bridge (status `Console opened` / `Console detached`), and the note `The separate console window BiceLib writes its log to. Not to be confused with the Lua Console on the Debug dock, which runs script.`

**Inputs a mod gives it** - none.

**When it applies** - any time the overlay is showing, main menu included; the two console buttons go through the Lua bridge and therefore do nothing outside a running game.

**Multiplayer and saves** - local only. Toggle key, theme and open windows persist in `BiceLibSettings.ini`; font size does not persist.

**Where the player sees it** - overlay, Options group, tab `Utility Options`.

### Options page: Game Settings

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`); Options group, first tab.

**What the original does without it** - the game offers no setting for either thing on this page.

**What the feature does** (source)

Section `Map`: checkbox `Scroll the map when the mouse is at the screen edge`, ticked by default. It switches the map edge scrolling feature (next-but-one section) at once and saves it. Tooltip: `Off stops the map moving when the cursor reaches the edge of the screen. The arrow keys and dragging with the middle mouse button still work. The game's own scroll_speed setting is the speed of all scrolling, so turning it down would have slowed those too. This patches out the four edge tests instead and leaves the rest alone. Takes effect at once, and is remembered.` If it is off but could not be applied, a warning `Not applied: <reason>` is shown.

Section `Popup positions`: needs the mod's Lua, so outside a game it shows `Lua unavailable: <reason>` instead (the Map section above still works).
- A row `Event popups` with two buttons, `Left` and `Center`; the button for the state the file is already in is disabled. After them: `currently left` / `currently center`; or the warning `edited by hand` (tooltip: the marked line is there but holds neither known position); or the error `not found` (tooltip: the marked line is missing from the interface file; check that the mod version matches).
- Button `Re-read the files`, and beside it either the result of the last change (`Event popups moved` in the success colour, or `Could not write the file: <reason>` in the error colour) or the hint `Restart the game for a change to take effect`.
- The explanation `This rewrites a marked line in the mod's own interface file, so the setting outlives the session and applies to every save - and reinstalling the mod undoes it.` and the file's path.

How it works: the page calls `BiceLibGui.Options.Collect()` once on first draw and on `Re-read the files`, and `BiceLibGui.Options.SetEventPopups(mode)` with the number 0 for left or 1 for center. The mod's provider (`script/utility_data/bicedata_options.lua`) does the work on the file `tfh/mod/BlackICE <G_MOD_VERSION>/interface/eventwindow.gui`, relative to the game's working directory:
- the line to act on is the one containing the comment mark `# _UtilityMark_EventPopup_position`;
- "center" writes that line as two tabs followed by `position = { x=700 y=255 } # _UtilityMark_EventPopup_position`; "left" writes `position = { x=0 y=255 } # _UtilityMark_EventPopup_position` in the same form;
- the current state is found by comparing the first marked line, whole, with those two: equal to one of them gives `left` or `center`, anything else `custom`, no marked line `unknown`;
- writing is done by the mod's `ReplaceLineAtCommentMark(file, mark, newLine)`, which rewrites the whole file replacing every line that contains the mark.
`Collect` answers `{ available, eventPopups, eventFile, messagePopups, dialogFile }`; the page reads only the first three. `SetEventPopups` answers the same plus `ok` and `reason`. (The provider can also move the message and combat-start popups in `eu3dialog.gui` by four similar marks; the overlay no longer offers that - only the deprecated wx utility does.)

**Inputs a mod gives it** - the marked line in `interface/eventwindow.gui`; `G_MOD_VERSION`; `ReplaceLineAtCommentMark` from `script/file-io.lua`; `BiceLibGui.Options.*`.

**When it applies** - the map checkbox: any time, at once. The popup position: needs a running game to change (Lua bridge rule) and a restart of the game to take effect, since the game reads its interface files at start.

**Multiplayer and saves** - local only. The popup position lives in the mod's own interface file (per install, all saves; undone by reinstalling the mod). Changing an interface file may matter to the game's multiplayer checksum (not examined here).

**Where the player sees it** - overlay, Options group, tab `Game Settings`; the effect is where event windows appear.

### Options page and feature: Custom Auto-Saves

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable` restores the saved switches); each of the two saves is then switched by its own checkbox on the page. Both are off by default.

**What the original does without it** (findings: `reversing/findings/FINDINGS-autosave.md`)

- Once per game day the in-game screen's daily update runs an **autosave decision**. It first clears a single "autosave requested" flag, then: in a tutorial, stops; if the player's `settings.txt` has `debug_saves` non-zero (say N), requests a save on the 1st of every Nth month and ignores the frequency; otherwise looks at the `autosave` frequency from `settings.txt` and requests a save when the date matches: `NEVER` never; `WEEKLY` every seventh day; `MONTHLY` on the 1st of every month; `HALFYEAR` on 1 January and 1 July; `YEARLY` on 1 January (the default); `FIVE_YEAR` on 1 January of a year divisible by five. The calendar has 365-day years and no leap day.
- The **writer** runs every frame. When the flag is raised it waits one frame, clears the flag, and writes the save. With `debug_saves` zero it rotates three files, `autosave.hoi3`, `oldautosave.hoi3`, `olderautosave.hoi3`; otherwise it writes one dated file per save.
- Because the decision clears the flag every time it runs, a request not yet written when the next decision runs is cancelled.
- In a multiplayer session the decision takes a different branch that appears to send something to the other machines rather than raise the flag; this is inferred and untested.

**What the feature does** - adds **two extra autosaves alongside the game's own**. The game's own schedule and files are untouched; each extra save keeps three rotating files of its own, so no set pushes another out (source).

*The two saves.*
1. **Before the month changes** ("monthly"): one save a month, a chosen number of days before the 1st of the next month. With `days` the setting (1 to 27, default 2), the save day is the day of the month equal to (days in this month) minus `days` plus 1: with 2, the 30th of a 31-day month and the 27th of February; with 1, the last day of the month. The upper bound 27 keeps the day inside February. (The page's tooltip gives `the 26th of February` for 2 days; the code's rule gives the 27th - see Possible BiceLib bugs.) The purpose now is a rollback point just before the game's once-a-month work (monthly event candidate rebuild, research decay); the original purpose, working round events not firing after a mid-month load, is obsolete (comment).
2. **On a timer** ("timed"): one save every so many minutes of **real time** (1 to 240, default 15), measured with the system's millisecond clock regardless of game speed.

*When a save is asked for.* BiceLib stands inside the game's autosave decision, immediately after the game clears its request flag and before the game makes up its own mind. So both extra saves are decided **once per game day and at no other moment** - a paused game takes none, and a timed save lands on the first day change after its interval is up. On each decision, in this order:

1. If a request of BiceLib's from an earlier decision was never written (the game has just cancelled it by clearing the flag), give up the claim on that save's name; put the timer back to where it was before that request; and if the dropped request was the monthly one, allow the same day to ask again.
2. If the monthly save is on, today is the save day, and no monthly save has been asked for on this calendar day yet: ask for a monthly save and stop (there is one request flag, so one save; the monthly save wins because it must land on a particular day).
3. Otherwise, if the timed save is on:
   - if the timer is not running, start it now and stop (the interval is counted from the first day change that reaches the decision, not from the main menu);
   - if less than `minutes` times 60,000 milliseconds have passed since the timer was (re)started, stop;
   - otherwise ask for a timed save.

"Asking" means: raise the game's own request flag, note which kind the next save belongs to, restart the timer from now (every save, of either kind, restarts it - the timer promises that no more than its interval goes unsaved), add one to that kind's "asked for" count and record the game date. The game's own decision then runs as always and may raise the same flag; a flag already raised is one save. Log line: `[INFO] AutoSave: asked for a pre-month save on <date>` or `... a timed save on <date>`, the date written `year.month.day hour:00` without leading zeros.

*How the save is made.* By the game's own autosave writer, unchanged, one frame after the request: it is an ordinary autosave in every respect except its name. BiceLib stands at the point where the writer decides how to name the file. For a save BiceLib asked for, it answers "rotate three files" whatever `debug_saves` says, and supplies that kind's three names; for any other save it answers truthfully and supplies the game's own three names. The claim is used up by one save.

*File names and rotation.* For a base name `<name>` the three files are, newest first: `<name>.hoi3`, `old<name>.hoi3`, `older<name>.hoi3`. Defaults: `autosave_premonth.hoi3`, `oldautosave_premonth.hoi3`, `olderautosave_premonth.hoi3`; and `autosave_timed.hoi3`, `oldautosave_timed.hoi3`, `olderautosave_timed.hoi3`. A third set, base name `crashsave`, is used by the out-of-memory watch (described in its own section). Three files per kind are kept and no more. The rotation is the game's own routine working on those names: if the newest exists and the middle one exists, the oldest is deleted, the middle is renamed to the oldest and the newest to the middle; then the save is written as the newest (comment). Because files are renamed as they age, a name does not carry the date; the save itself does, and the load menu shows it. The files go wherever the game's own autosave goes - the player's save games folder - since the writer is the game's (not separately verified).

*Names.* A base name may hold only letters A-Z and a-z, digits, `-` and `_`, at most 39 characters. An empty name falls back to the kind's default. A changed name applies from the next save of that kind; files under the old name are left as they are.

*Guards.* None beyond the above: there is no test for multiplayer, and the extra saves are decided before the game's own "no autosaves in a tutorial" test. The decision is only reached from the in-game screen's daily update, so nothing is asked for at the main menu or during a load (source for the absence of tests; findings for the order of the game's own steps).

*`AutoSave::restore()`* - called by `BiceLib.Overlay.enable()`. Reads the settings once, hands both base names to the naming hook, and if either save is switched on installs the two hooks and makes them active. Without it the saved switches would only take effect when the page was first drawn. With both saves off the hooks are not installed at all on a fresh start; once installed they stay, and while inactive they do exactly what the game's own instructions did (source).

*The hooks in behavioural terms* (source):
- **Decision hook**: lets the game clear its request flag as it always does and then, only while active, gives BiceLib the in-game screen object and the current hour count so it can run the three steps above.
- **Naming hook**: only while active, intercepts the writer's read of `debug_saves`; for a save BiceLib claimed it forces the three-file rotation and substitutes that kind's names, otherwise it passes the real value on and restores the game's names.
- The three names the game's rotation uses are redirected, for as long as the hooks are installed, to text BiceLib owns; that text holds the game's own three names except during a save of BiceLib's, and is put back to the game's names when the feature is switched off.
- Installation checks that the game's code at each place is exactly what this build should hold and writes nothing if not; the page then shows `Not hooked: <reason>` (`the autosave code is not what this build expects`, `could not make the code writable`, `hoi3_tfh.exe is not loaded`).

*The page* (source). Introductory text: `Two extra saves, each switched on by itself. Both sit alongside the game's own autosave: the frequency in settings.txt keeps working exactly as it did, and each of these keeps three rotating files of its own, so no set ever pushes another out.` If either save is on but the hooks could not be installed: warning `Not hooked: <reason>`. Then two columns of equal width.

Left column, heading `Before the month changes`:
- explanatory text about the month turn;
- checkbox `Save before every month change` - switches the monthly save, saved at once;
- heading `When`; slider `Days before the 1st`, 1 to 27, clamped; changing it saves it and lets a save be asked for on the new day even if one was already asked for this month. Tooltip: `Counted back from the 1st of the next month, so every month is measured from its own end: 2 days -> the 30th of a 31 day month, the 26th of February; 1 day -> the last day of the month`;
- heading `Name`; text box `File name` (the base name); applied when editing finishes and only if valid, otherwise the warning `Letters, digits, - and _ only. Not saved while it says this.`; below it `Rotating between, newest first:` and the three file names as bullets;
- heading `This session`; `None asked for yet.` or `<n> asked for, the last on <date>` (requests since the DLL was loaded, not files written).

Right column, heading `On a timer`:
- explanatory text;
- checkbox `Save every so often` - switches the timed save, saved at once; switching it either way stops the timer, so the first interval is counted from the next day change;
- heading `How often`; slider `Minutes`, 1 to 240, logarithmic, clamped; saved at once. The interval is measured from the last save, so shortening it can make a save due immediately and lengthening it postpones the next. Tooltip: `Real minutes, not game time. The save is taken on the first day change after the interval is up, which is the only moment the game asks. A paused game never gets there, so nothing is saved while it is paused - and nothing has happened to save.`;
- heading `Name`; the same text box and file list for the timed save;
- heading `This session`; one of `Next in <m>:<ss>` (time left, seconds rounded up), `Due on the next day change.`, or - when the save is on but the timer is not running - `Waiting for a game to be playing.`; then `None asked for yet.` or `<n> asked for, the last on <date>`.

**Inputs a mod gives it** - none. Settings keys (in `BiceLibSettings.ini`): `autoSave.enabled` (0 or 1, default 0), `autoSave.daysBeforeMonthEnd` (default 2, clamped to 1..27 on read), `autoSave.saveName` (default `autosave_premonth`; if absent, the older key `autoSave.suffix` is used if present), `autoSave.timed.enabled` (default 0), `autoSave.timed.minutes` (default 15, clamped to 1..240), `autoSave.timed.saveName` (default `autosave_timed`).

**When it applies** - from `Overlay.enable()` (saved switches) or from ticking a box; can be switched off at any time, after which the game decides alone again. Works only in a running game by construction.

**Multiplayer and saves** - local: each machine with a save switched on writes its own files on its own schedule. No game command is posted and no game state other than the game's own "autosave requested" flag is touched. The timer, the "already asked today" marker and the session counts are held in memory outside the savegame and are not reset by loading another game (see Possible BiceLib bugs).

**Where the player sees it** - overlay, Options group, tab `Custom Auto-Saves`; the files appear in the game's load menu.

### Map edge scrolling

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable` restores the saved choice); changed with the checkbox on the Game Settings page.

**What the original does without it** - every frame, after handling the arrow keys and middle-button dragging, the map camera makes four tests - top, bottom, left and right - of the mouse position against the edges of the view, with a margin of six pixels, and moves the camera when the pointer is at an edge. There is no setting to stop this; `scroll_speed` in `settings.txt` is the speed of all scrolling, so lowering it slows the keyboard too (comment).

**What the feature does** - a single on/off choice. On (the default) is the game's own behaviour, untouched. Off skips all four edge tests, so the map no longer moves when the pointer reaches a screen edge; the arrow keys and dragging with the middle mouse button work as before. The change takes effect at once and is saved. If the game's camera code is not what this build should hold nothing is changed and the reason is shown (`the camera does not test the screen edge where this build expects`) (source).

**Inputs a mod gives it** - none. Setting `map.edgeScroll` in `BiceLibSettings.ini`: 1 = scroll at the edge (default), 0 = do not.

**When it applies** - the saved choice is put back by `Overlay.enable()`: only an "off" needs applying. It can be switched either way at any time, main menu or game.

**Multiplayer and saves** - local input handling only; no game state, nothing in the savegame, identical game on every machine whatever each player chooses.

**Where the player sees it** - the map; the switch is on the overlay's Game Settings page.

### Settings files

Kind: infrastructure
Switch: always on once the DLL is loaded (the file is read the first time any setting is asked for).

**What the original does without it** - nothing: this is new.

**What the feature does**

*`BiceLibSettings.ini`* - in the folder `BiceLib.dll` is in (the mod's `script` folder). Plain text, one `key=value` per line. The first line written is the comment `# BiceLib settings. Written by the overlay, safe to edit by hand.` Reading: blank lines and lines starting with `#` are skipped; a line without `=` is skipped; the key is the text before the first `=`, the value everything after it, both trimmed of spaces and tabs; a line with an empty key is skipped. The file is read **once**, on the first access; a missing file is normal and every setting then has its default. On **every** change the whole file is rewritten at once, keys in ascending order, so a setting survives even if the game never closes cleanly. If the file cannot be written the new values still hold for the session. A numeric setting whose text does not start with a number counts as absent. If the DLL's folder cannot be determined nothing is read or written (source).

Every key (source):

| key | meaning | default |
| --- | --- | --- |
| `overlay.toggleKey` | Windows virtual key code that shows and hides the overlay; values outside 1..255 are ignored | 45 (INSERT) |
| `gui.theme` | theme id: `dark`, `grey`, `light`, `army_green`; unknown means `dark` | `dark` |
| `groups.<group>` | whether that group's window is open (0/1); one per group: `groups.Setup`, `groups.Country Info`, `groups.Game Info`, `groups.Inspector`, `groups.Stats`, `groups.Options`, `groups.Help`, `groups.Debug` | 0 |
| `pages.<window name>` | whether that page is open (0/1); the window name is the page title, with `##<group>` appended for the titles used twice (`pages.Misc##Setup`, `pages.Misc##Help`, `pages.National Focus##Country Info`, `pages.National Focus##Help`) | 1 |
| `autoSave.enabled` | monthly extra autosave on (0/1) | 0 |
| `autoSave.daysBeforeMonthEnd` | days before the 1st, 1..27 | 2 |
| `autoSave.saveName` | base file name of the monthly set | `autosave_premonth` |
| `autoSave.suffix` | older name of `autoSave.saveName`; read only, as its fallback | - |
| `autoSave.timed.enabled` | timed extra autosave on (0/1) | 0 |
| `autoSave.timed.minutes` | real minutes between timed saves, 1..240 | 15 |
| `autoSave.timed.saveName` | base file name of the timed set | `autosave_timed` |
| `map.edgeScroll` | map scrolls at the screen edge (0/1) | 1 |
| `customMapMode.palette` | `green` or `heat` - owned by the custom map mode (described in its own section) | `green` |
| `outOfMemory.watch` | out-of-memory watch on (0/1) - described in its own section | 1 |
| `outOfMemory.triggerAtKb` | its threshold in kilobytes (a value of 0 or less is read as 1) - described in its own section | 2048 |

*`BiceLibImGui.ini`* - same folder. The overlay's layout (positions, sizes, docking); see the overlay section.

*Other files BiceLib or its Lua side read or write, named here and described with their own features*: the folder `BiceLibScripts` beside the DLL (the Lua Console's saved scripts, one `.lua` each); the folder `combat_reports` beside the DLL (the combat record store); the crash report pairs `BiceLibCrash_<nnn>.txt` and `.dmp` (the mod's deploy script names their folder `crash_reports`); `OutOfMemory.log` beside the DLL; the reverse-engineering probe files `BiceLibCounters.txt`/`.csv`, `BiceLibWatch.txt`/`.csv` and `BiceLibWrites.csv`; `lua_output.txt` in the game's working directory (the mod-side log, see "Console and loading"); and the mod's `interface/eventwindow.gui`, one line of which the Game Settings page rewrites. The mod's deploy script, which clears the `script` folder before copying, keeps `BiceLibSettings.ini`, `BiceLibImGui.ini`, `BiceLibScripts`, `combat_reports`, `crash_reports`, `BiceLibCounters.csv` and `BiceLibWatch.csv` across a deploy (source).

**Inputs a mod gives it** - none.

**When it applies** - always.

**Multiplayer and saves** - per install, never synchronised, not per savegame.

**Where the player sees it** - the Utility Options page shows the file's path.

### The daily callback - `BiceLibDailyPeriodics`

Kind: infrastructure
Switch: on with the overlay (`BiceLib.Overlay.enable`): it is driven from the per-frame hook, so with the overlay disabled it never runs.

**What the original does without it** - the game calls a mod's Lua only through its AI entry points (the minister "ticks"), and in multiplayer only the host runs those; a client runs none of the mod's scheduled scripts. Anything a mod sets up from those scripts in the DLL's own memory - here the per-country headquarters attachment limits, which depend on technology - therefore never happens on a client (comment).

**What the feature does** - the DLL itself calls one global Lua function of the mod once per game day, in every game on every machine (source).

*The game clock guards.* Once per presented frame the DLL reads the game's hour counter (0 when there is no game state). Two rules are built on it:

- **A clock jump** is a frame on which the counter changed and the new or the old value is 0, or it went backwards, or it went forward by 24 hours or more. A jump means a load or a new game. It starts a new **session number** (a counter that only increases) and resets a count of steady steps to zero.
- **`movedInPlay`** ("the clock moved this frame, in play") is true on a frame when all of these hold: the counter changed since the last frame; the change was not a jump; at least two non-jump forward steps have now been seen since the last jump (this frame's included); and the game's own "a game is on screen" flag is set. It is false on every frame the clock did not move - so always at the main menu and while paused.

The two halves answer different questions and neither covers the other. The flag alone is set a little too early: it goes up on entering a game before the in-game interface has been built. The steady-step count alone cannot tell a paused game from the main menu, and during the tail of entering a game the clock cannot have stepped yet. So `movedInPlay` gates once-a-day work, while the flag alone (`sessionActive`, in the Lua bridge) gates ordinary Lua calls, which must also work while paused (source; findings: `reversing/findings/FINDINGS-session.md`).

*When the call is made.* On the first frame for which all hold:
1. `movedInPlay` is true;
2. the current day (hour counter divided by 24, whole) differs from the day of the last call;
3. the hour of day is 1 or later - so that on the host it comes after the mod's own scheduled scripts, which run at about 01:00 (comment);
4. a Lua call is allowed by the Lua bridge's four conditions (game on screen, presenting thread, a known Lua state, no call in flight). If not, the same test is made again on the next frame the clock moves.

The call runs on the presenting thread, which is also the thread the game runs its Lua on, in that thread's Lua state, inside a protected call.

*Argument.* One number, `firstDay`: 1 if this is the first call since the session number changed (the first call after a load or a new game), else 0.

*Expected answer.* A table. One field is read: `oob_limits_checked` (boolean) - whether this call also re-checked the headquarters attachment limits. The mod's function also returns `bicelib_loaded`, which the DLL does not read.

*After the call* the DLL records, for the Setup group's Country page: the hour counter of the call; whether it succeeded; the failure reason if not; the last call on which `oob_limits_checked` was true; and the local player's tag with the corps, army and army group attachment limits BiceLib now holds for that country. This record is emptied at the first call of a new session, and reads as empty as soon as the session number changes.

*Failure.* If the global function is missing, raises an error, or returns something that is not a table, the call counts as failed with the bridge's reason (`'BiceLibDailyPeriodics' is nil ...`, `the Lua call raised an error` - the Lua message itself goes to the log as `[ERROR] LuaBridge: BiceLibDailyPeriodics failed: <message>` - or `the Lua call did not return a table`). **A call that was attempted counts for the day even if it failed**: it is not retried until the next day.

*The mod's function* (`script/bicelib_lua.lua`):

    function BiceLibDailyPeriodics(firstDay)
        local loaded = BiceLib ~= nil
        local first = firstDay == 1
        local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
        if loaded then
            CheckOobUnitLimitTechnologyStatus(first)
        end
        return {
            bicelib_loaded = loaded,
            oob_limits_checked = loaded and (first or dayOfMonth % 5 == 0),
        }
    end

`CheckOobUnitLimitTechnologyStatus(skipDayCheck)` (in `script/ai_variable.lua`, described with the unit attachment limits) does its work only when the game's day-of-month value is divisible by five, unless `skipDayCheck` is true. So the limits are set up at once on the first day after a load and then on the same days on every machine. On the host the same function also runs from the mod's own schedule (the OMG country's intelligence minister tick at about 01:00, and once at that tick's first run through `RunBiceLibPeriodicsManually()`), which is harmless duplication.

**Inputs a mod gives it** - the global Lua function `BiceLibDailyPeriodics(firstDay)` returning a table with `oob_limits_checked`; game Lua API used by the mod's function: `CCurrentGameState.GetCurrentDate():GetDayOfMonth()`.

**When it applies** - from `Overlay.enable()`, in every game of the process, single player and multiplayer, host and client. No switch other than the overlay's.

**Multiplayer and saves** - runs on every machine at the same game day and hour rule, so the values it sets are the same everywhere provided they depend only on synchronised game state (technology levels). It posts no commands itself. The "last day called" and session number are in memory only.

**Where the player sees it** - overlay, Setup group, Country page, section `BiceLib setup`: `Not run yet in this game.`; or `Last run <date>` (success colour); or `Last run <date> failed: <reason>` (error colour); then, if known, `HQ unit limits checked <date>` and `<TAG> may attach: corps <n>, army <n>, army group <n>`; and the note `Runs by itself once a game day, in every player's game - the mod's scripts only run on the host, so this is how each game gets the HQ unit limits. It first runs a couple of game hours after a load is unpaused, and checks the limits then and on every fifth day of the month.` Dates are written `year.month.day hour:00`.

### `BiceLib.Messages.show(text, header, provinceId, line2, line3)`

Kind: infrastructure
Switch: always on once the DLL is loaded; the per-frame flush hook is installed the first time a message is queued.

**What the original does without it** - the game shows the player message popups of fixed types: each type is declared in `interface/messagetypes.txt` (whether it pops up, is logged, is marked on the map, pauses) and its text comes from localisation keys built from the type's name: `<TYPE>_SETUP` (the line on the message settings screen), `<TYPE>_HEADER` (who reports it), `<TYPE>_1` to `<TYPE>_6` (the popup's lines, `*` for an unused one), `<TYPE>_LOG`, `<TYPE>_BTN1` to `<TYPE>_BTN3`, `<TYPE>_MAP`. The type registry is built from the file, so a type a mod declares is a type the game knows; a name the registry lacks logs `Failed to find message type: <name>` and shows nothing. The game raises a message only for the country the local player plays, never for an AI country. A mod's script has no way to show a message with text of its own (findings: `reversing/findings/FINDINGS-messages.md`).

**What the feature does** - shows one of the game's own message popups, with the caller's text, to the local player (source).

*Arguments.*
1. `text` (string, required): the first line. Missing, not a string, or empty: nothing is queued, the log says `[ERROR] 'Messages.show' needs some text`, the result is false.
2. `header` (string, optional): who reports it. Default `BlackICE reports that`.
3. `provinceId` (number, optional): the province the message points at. Absent, 0 or negative: the capital of the local player's country (the declared capital).
4. `line2`, 5. `line3` (strings, optional): two more lines, default empty.

*Result.* One boolean: true if the message was queued. False when the text is empty, when no game is running (no player country: `[ERROR] 'Messages.show' needs a running game`), when the queue is full, or when the flush hook could not be installed (`[ERROR] 'Messages.show' failed: <reason>`).

*The type.* Always `BICE_MESSAGE`, declared in the mod's `interface/messagetypes.txt` as:

    BICE_MESSAGE = {
    log = yes
    onmap=no
    popup=yes
    idle=no
    option=no
    pausepopup=no
    categories = "cat_other"
    }

and written in `localisation/BiceLib_messages.csv` (key;English):

    BICE_MESSAGE_SETUP;A message from the utility or from a script.
    BICE_MESSAGE_HEADER;$HEADER$
    BICE_MESSAGE_1;$TEXT$
    BICE_MESSAGE_2;$TEXT2$
    BICE_MESSAGE_3;$TEXT3$
    BICE_MESSAGE_4;*
    BICE_MESSAGE_5;*
    BICE_MESSAGE_6;*
    BICE_MESSAGE_LOG;$TEXT$
    BICE_MESSAGE_BTN1;OK
    BICE_MESSAGE_BTN2;OK
    BICE_MESSAGE_BTN3;Goto
    BICE_MESSAGE_MAP;$TEXT$

A message's text comes from the localisation of its type, so arbitrary text is only possible because this type's lines are nothing but variables. The call sets all four - `HEADER`, `TEXT`, `TEXT2`, `TEXT3` - always, empty where the caller left one out. They are added after the country's own standard message variables (the set every message of the game starts with, `$COUNTRY$` first, `$MONARCHTITLE$` among them), so those are available too. So: the popup shows the header, up to three lines and the buttons `OK` and `Goto`; the message log gets one line, the text; there is no map marker; the game is not paused. The player can change these per type on the game's message settings screen like any other type, where it is listed as `A message from the utility or from a script.`

*Goto.* The message carries the province from argument 3 (or the capital) and no unit; the popup's `Goto` button takes the map to that province (comment; the game's own button behaviour).

*Queueing.* The call does not raise the message. It copies the type, the variables, the country and the province into a queue and returns. The queue is drained **at the start of the in-game screen's own per-frame update** - where the game raises its own messages - and that update runs every frame whether the clock runs or not, so a message queued while paused still appears, on the next frame. The whole queue is taken at once and raised oldest first; a message queued while others are being raised waits for the next frame.

*Why it is queued.* Two measured traps (findings: `reversing/findings/FINDINGS-messages.md`): (1) a message raised from inside the presented-frame hook - anything the overlay draws or its Lua Console runs - is built correctly, posts without complaint, and comes up as an **empty window**: no header, no lines, no buttons. The same message raised from the game's own update or tick comes up right; Lua has nothing to do with it, and the cause was not established. (2) A country's standard message variables are one list owned by the country, cleared and refilled for each message and released when the message is built; raising a message while another for the same country is part-built frees the outer one's variables and has crashed the game. Raising everything from one place, once a frame, avoids both.

*Capacity.* At most 64 messages may wait. A 65th is dropped: `[WARNING] Game::Message: 64 already waiting, dropping 'BICE_MESSAGE'`, result false.

*Who sees it.* Only the local player of the machine the call ran on: the message is raised for the country that machine's player is playing. Nothing is sent to other machines.

*Text encoding.* The strings are handed to the game unchanged, so they must be Windows-1252 like all game text.

*Other message types through the same mechanism.* The DLL's message class can raise any declared type with any `$VARIABLE$` set, but in the present source **nothing other than `Messages.show` uses it** (source: searched). The mod also declares `BICE_UNITDESTROYED` (`log = yes`, `onmap=yes`, `popup=yes`, `idle=no`, `option=no`, `pausepopup=no`, `categories = "cat_combat"`) with localisation `BICE_UNITDESTROYED_SETUP` = `When one of our divisions is destroyed outright.`, `_HEADER` = `$chief_of_army$ reports that`, `_1` = `$UNIT$ destroyed!`, `_2` = `$MONARCHTITLE$, $UNIT$ has been overrun and destroyed. With no ground left to fall back to, the division could not be reformed.`, `_3` = `$LOCATION$`, `_4` to `_6` = `*`, `_LOG` = `$UNIT$ destroyed in $LOCATION$.`, `_BTN1` and `_BTN2` = `OK`, `_BTN3` = `Goto`, `_MAP` = `$UNIT$ destroyed!`. No code in the DLL raises it now; the fact base records that an earlier build raised it by borrowing the game's own "division shattered" message and that this code is gone (findings). `BiceLib.Reversing.probeMessages` is a diagnostic that prints the next few messages the game posts (tooling).

**Inputs a mod gives it** - the `BICE_MESSAGE` entry in `interface/messagetypes.txt`; the thirteen `BICE_MESSAGE_*` localisation keys above; the five arguments.

**When it applies** - any time a game is running, from any Lua context (an AI tick, an event-driven script, the overlay's Lua Console). No game need be unpaused.

**Multiplayer and saves** - local and cosmetic: no command is posted, no game state changes, nothing is saved; a queued message not yet shown is lost if the game is left. A script that calls it from the host-only AI scripts shows it on the host only.

**Where the player sees it** - the game's own message popup and message log.

### `BiceLib.Events.rebuildCandidates()`

Kind: fix
Switch: the Lua call itself, each time it is called. The mod calls it from `script/ai_omg_handlers.lua` (see "When it applies").

**What the original does without it** (findings: `reversing/findings/FINDINGS-events.md`) - events that fire by themselves work in three layers:

1. the list of every event the scenario loaded;
2. for each country, a **candidate list**: the events that could fire for it;
3. the **daily pass**: for each country owning at least one province whose candidate list is not empty, for each candidate, re-test the event's trigger, compute a chance from its mean time to happen, draw a uniform number in [0,1), and fire the event if the chance is greater.

Layer 2 is rebuilt by one routine: first every country's candidate list is emptied (all countries, no filter); then, for every event that has at least one option, is not `is_triggered_only`, and is not a `fire_only_once` event that has already fired, and for every country owning at least one province, the event's trigger is evaluated in that country's scope and, if true, the event is appended to that country's list. The game's clock runs this rebuild **only in the monthly pass** (and on one game-entry path that a load does not appear to take). The candidate lists are not in the savegame and are not rebuilt after loading. So **a loaded game has every candidate list empty and fires no self-firing events until the month turns**; and since on the 1st the daily pass runs before the monthly one, the earliest such an event can fire is the 2nd. Load on the 2nd of a month and nearly four weeks of events pile up behind the month change. Events with `is_triggered_only` are unaffected: they are never candidates. In a tutorial the game deliberately skips both the daily event pass and this rebuild.

**What the feature does** - calls the game's own rebuild routine at once, with the same argument the monthly pass gives it. Nothing is patched and the rebuild itself is the game's. It covers every country. It is idempotent: the lists are emptied before being refilled, so calling it when they are already good costs one wasted pass (source).

It returns one boolean, true if the rebuild ran. Before calling it checks, in order, and refuses (returning false and logging `[ERROR] EventCandidates: not rebuilding the event lists - <reason>`) when:
1. no game is on screen - `no game is on screen`;
2. the game module cannot be found - `the game module could not be found`;
3. the game's rebuild routine is not the one this build should hold - `the engine's rebuild is not what this build expects`;
4. the scenario's event list does not exist yet - `the scenario's event list does not exist yet`;
5. there is no game state - `no game state`; or a tutorial is running - `a tutorial is running, which the engine runs without events` (the same gate the game's monthly pass applies).

The call is guarded: a fault inside the rebuild is caught, logged as `[ERROR] EventCandidates: the rebuild faulted at tick <n>`, and the result is false. On success it logs `[INFO] EventCandidates: rebuilt every country's candidate event list at tick <n> (day <d>, hour <h>); <TAG> went from <before> candidates to <after>`, where the counts are the local player's country's candidate count before and after (0 before is what a fresh load shows; hundreds after). The same facts are kept as a status record in the DLL; no page displays it (source).

**Inputs a mod gives it** - none.

**When it applies** - must be called from the game's own thread while a game is on screen. The mod's call sits in `IntelligenceMinisterUtilityThings()`, the first function the mod schedules on the OMG country's intelligence minister tick (about 01:00 each game day, on the machine that runs the AI scripts), inside the block that runs once per Lua state, while the file's local `setupDone` is still false:

    if setupDone == false then
        setupDone = true
        ...
        RunBiceLibPeriodicsManually()
        if BiceLib ~= nil then
            BiceLib.Events.rebuildCandidates()
        end
    end

No other script calls it, and nothing sets `setupDone` back. It happens at that tick rather than at the moment of loading, so events resume a day or so after a load. (source)

**Until 2026-11-20 the call was never reached with the mod's settings.** It sat further down, in the block guarded by the Lua global `SaveLoaded`, which comes after the line `if G_UtilityEnabled ~= true then return end` - and `G_UtilityEnabled`, the old wxWidgets utility's switch, has been `false` in `script/utility_settings.lua` since before the call was written. It was found by this write-up and moved above that line the same day.

**Multiplayer and saves** - it changes which events can fire on the machine that calls it, by calling the game's own routine directly; it posts no command. The mod's call runs only where AI scripts run (the host). Whether candidate lists and the daily event pass must agree across machines was not examined. The lists are not saved, which is the fault being mended.

**Where the player sees it** - nowhere directly; events fire in the first weeks after a load instead of arriving in a burst after the next month change.

### Console and loading - `require "BiceLib"`, `BiceLib.startConsole()`, `BiceLib.stopConsole()`, `BiceLib.setModuleBase()`

Kind: tooling
Switch: `require "BiceLib"` in `script/bicelib_lua.lua`, which `autoexec.lua` requires in every Lua state; the console by `BiceLib.startConsole()` (commented out in the committed script) or the Utility Options page's `Open` button.

**What the original does without it** - the game loads Lua C modules through `require` and `package.cpath`; it has no log console.

**What the feature does** (source)

*Loading.* `autoexec.lua` adds the mod's `script` folder (`tfh/mod/BlackICE <G_MOD_VERSION>/script/`) to `package.cpath`, and `bicelib_lua.lua` does `pcall(require, "BiceLib")`. The module, on load into a Lua state:
- records that Lua state in a process-wide list of every state that has loaded it (the game opens one Lua state per AI context, never closes any, and each runs `autoexec.lua`; the list only grows, and the Debug group's Memory page uses it to total the Lua memory of all states, counting states that share one registry once);
- creates the global table `BiceLib` holding `startConsole`, `stopConsole`, `setModuleBase` and these sub-tables of functions: `GameInfo` (`getProvinceDetails`, `getCountryFlags`, `getCountryVariables`, `getCountryOffmapIc`, `getCountryResourceConversion`, `getCountryActiveEventModifiers`, `getCountryGeneralModifiers`), `Leaders` (`addRankSpecificTrait`, `activateRankSpecificTraits`, `checkRankSpecificTraitsConsistency`, `activateLeaderListShowMaxSkill`, `activateLeaderListShowMaxSkillSelected`, `activateCtrlUnassignSelected`, `activateOobLeaderRanks`, `activateHistoryLeaderRanks`, `addTraitToLeader`, `getLeaderDetails`), `Units` (`setCorpsUnitLimit`, `setArmyUnitLimit`, `setArmyGroupUnitLimit`, `addCommandLimitTrait`), `Navy` (`setScreenPenalty`, `setScreensPerCapitalRatio`), `BytePatches` (`fixMinisterTechDecay`, `disableWarExhaustionNeutralityReset`, `disableInterAiExpeditionaries`, `historicalModelLogicFix`, `seaTerrainColourInSimplifiedMapMode`), `ComplexPatches` (`fixOffMapIC`, `enablePlacingNonResearchedBuildings`, `fixQueuedHistoricalModel`, `fixMaxInfrastructure`, `customResourceConversion`), `Events` (`rebuildCandidates`), `EffectTexts` (`activateKillLeaderVariables`, `activateLoadOobDetails`, `activateTriggerIndent`, `activateTriggerScroll`), `Tooltips` (`activateManpowerBreakdown`, `activateCombatUnitStats`, `activateParadropLine`, `activateCombinedArmsLine`), `Messages` (`show`), `Reversing` (`activateCounters`, `watchCombatModifiers`, `watchSubunit`, `watchWrite`, `stopWatching`, `activateWatch`, `probeMessages`), `Commands` (`registerBiceCommands`, `postExampleCommand`), `Inspector` (`getSelectedEntity`), `Overlay` (`enable`, `toggle`);
- calls the mod's global `BiceLibLuaLog`, if it exists, twice: with `Loaded BiceLib` and with `LUA_STATES: <number of states so far>`;
- returns the module table.

So there is **one module table per Lua state**, but everything behind it - hooks, settings, queues, the overlay - is one per process. The mod's switch-on calls therefore run once per Lua state, and every switch is written to be harmless when repeated.

The mod stores the table in the global `BiceLib` only on success. On failure it logs `Failed to load BiceLib.dll. BlackICE will not work correctly - check your Anti-Virus program` and the error through the mod's debug log, leaves `BiceLib` nil, and `HasLoadedBiceLibSuccessfully()` answers false; all later uses are guarded by `BiceLib ~= nil`. A separate mod routine, `DetermineBiceLibLoadStatus()`, then posts a set-variable command on the OMG country (`OmgBiceLibLoadStatusTrigger` = 1) once, for the mod's own in-game warning.

*`BiceLib.setModuleBase()`* - prints one log line with where the game executable is loaded, and nothing else. No arguments, no results. Historical: it used to have to be called before any hook; the DLL now finds this out by itself as it loads, and the function is kept so scripts that call it keep working.

*`BiceLib.startConsole()`* - opens a console window and sends the DLL's log output to it. Every log line of the DLL begins with `[INFO] `, `[WARNING] ` or `[ERROR] ` (and `[DEBUG] [<function>:<line>] ` in debug builds only). The console's quick-edit mode is switched off on purpose: selecting text in a Windows console freezes the process writing to it until the selection is cleared. The window is moved 50 pixels right and down and sized 1000 by 600. Does nothing if the console is already open. No arguments, no results. Without the console the log lines go nowhere visible.

*`BiceLib.stopConsole()`* - prints `Console has been detached! You can now close the console window.` and detaches the console so its window can be closed without closing the game. Does nothing if none is open. `startConsole` may be called again afterwards.

*The mod-side log helper* (`script/bicelib_lua.lua`): `BiceLibLuaLog(text)` appends the line `BiceLib: '<text>' ` to `lua_output.txt` in the game's working directory (the same file the mod's own `Utils.LUA_DEBUGOUT` appends `LUA_DEBUG '<text>' ` lines to); `ResetBiceLibLuaLog()` empties that file. The DLL calls `BiceLibLuaLog` only if the global exists and inside a protected call; an error in it is logged as `[ERROR] BiceLibLuaLog failed: <message>`.

**Inputs a mod gives it** - optionally the global function `BiceLibLuaLog(text)`.

**When it applies** - at Lua start-up, before any game; the console at any time.

**Multiplayer and saves** - none.

**Where the player sees it** - a separate console window (developers); `lua_output.txt`.

### Text encoding

Kind: infrastructure
Switch: always on once the DLL is loaded.

**What the original does without it** - the game's data files and the strings it keeps in memory are Windows-1252. The overlay's user interface library needs UTF-8 and draws anything else as its fallback glyph, so German names full of umlauts would arrive as rows of `?`.

**What the feature does** - one conversion rule, applied **at the point text is read out of the game or out of the mod's Lua, once, not at each place it is drawn** (source):

- If the bytes are already well-formed UTF-8 they are returned unchanged. This makes the conversion safe to apply twice and safe on sources that are already UTF-8; plain ASCII is the same in both encodings and is never touched. (The well-formedness test: lead bytes of two-, three- and four-byte sequences with the right number of continuation bytes; the two overlong two-byte lead values and lead values beyond the Unicode range are rejected; a sequence cut off by the end of the text is rejected.)
- Otherwise the bytes are converted from code page 1252 - fixed, not the machine's locale - to UTF-8. If the conversion fails the original bytes are returned.

It is applied to every string field and string-array element a page reads through the Lua bridge, and to strings the DLL reads from the game's memory for display (comment for the latter). Text travelling the other way is **not** converted: what `BiceLib.Messages.show` is given and what the DLL's localisation lookup returns are Windows-1252 and are handed to the game as they are.

**Inputs a mod gives it** - none; mod text files stay Windows-1252.

**When it applies** - always.

**Multiplayer and saves** - none.

**Where the player sees it** - correct accented characters in overlay pages.

### Localisation lookup (internal helper)

Kind: infrastructure
Switch: always on once the DLL is loaded; used by other features (effect texts and tooltips, described in its own section).

**What the original does without it** - the game's localisation lookup answers with a text object (the entry found plus a list of `$VARIABLE$` replacements to apply when drawn), not with characters; turning it into characters is a second, rendering step (comment; `reversing/findings/FINDINGS-effecttext.md`).

**What the feature does** - gives the DLL's own features "the text for a localisation key": it performs the game's lookup and the game's rendering with no replacements and returns the resulting characters, in Windows-1252. A key the game has no entry for yields the empty string - and, as with the game's own lookup, leaves an empty entry for that key behind - so it is meant for keys expected to exist. A variant builds the key from a prefix and a number (for example a province's name key from `PROV` and its id). It must be asked while a game is running: asked at the main menu before the localisation files are read it would answer nothing (source for the behaviour; comment for the main-menu warning).

**Inputs a mod gives it** - the mod's localisation `.csv` files.

**When it applies** - on demand by other features.

**Multiplayer and saves** - none.

**Where the player sees it** - indirectly, in the texts of features that use it.

## Part 5 - Pages: Setup and Country Info

### Shared by every page in this part: the selected country, the page-to-Lua contract, pending changes

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new.

**What the feature does**

*Pages.* A page is one tab. It has a title (the tab label), a group (the dockable window it starts in on a first run with no saved layout) and an order number (position in the group, low first; pages sharing an order sort by title). The groups, in display order, are `Setup`, `Country Info`, `Game Info`, `Inspector`, `Stats`, `Options`, `Help`, `Debug`. A page's body is drawn only while its tab is the visible one, so its timers only run then. (source)

*The selected country.* All pages of this part except Setup > Special report on, and write to, one country: "the selected country". It is the Lua global `G_PlayerCountry` (a tag string) in the Lua state the render thread uses, resolved by `BiceData.Players.CurrentTag()`:

1. `actual` = `tostring(CCurrentGameState.GetPlayer())`, the country the local machine plays (nil if there is none).
2. If `G_PlayerCountry` is nil: if `actual` is nil the answer is nil ("no country"); otherwise `G_PlayerCountry` becomes `actual` and the choice is remembered as automatic.
3. Otherwise, if the current choice is automatic and `actual` differs from it (another save was loaded), `G_PlayerCountry` becomes `actual`. A deliberate choice (made on Setup > Country) is never moved.
4. The answer is `G_PlayerCountry`.

The overlay polls `BiceLibGui.Country.CurrentTag()` centrally, once every 2000 ms while the overlay draws, and caches the tag for pages that read game state without Lua; it answers `{ available = true, tag = <TAG> }` or `{ available = false, reason = "No player country" }`. Setup > Country forces a re-poll after every selection. The selected country need not be the one the local player plays, and need not be played by anyone. Nothing checks that the machine is the multiplayer host. (source)

*The contract between a page and its Lua.* Each page calls global Lua functions by dotted path, `BiceLibGui.<Page>.<Function>`, with no argument, one string, one number, or a string and a number. Every data call returns one table of plain values (numbers, strings, booleans, arrays of strings, arrays of flat tables - never userdata) that always carries `available` (boolean) and, when false, `reason` (string). All page functions run inside `Page.Guard` (a `pcall`): a Lua error becomes `{ available = false, reason = <error text> }`. Every string read from Lua is converted from Windows-1252 to UTF-8 at the point it is read. A missing boolean reads as false (two read as true when missing: `selling` on Strategic Res. and `bufferNco` on LS Sliders AI), a missing number as 0, a missing string as empty. (source)

A call is only made when all of these hold, otherwise it is skipped and the page shows `Lua unavailable: <reason>` in the dim text colour:

- a game is in play - the game's own in-game flag on the current game state, false at the main menu and in the lobby - reason `no game session`;
- the caller is the render thread - `not on the render thread`;
- the render thread has a Lua state - `the render thread has not run Lua yet`;
- no other Lua call is in flight on this thread - `a Lua call is already in flight`.

Other reasons: `'<path prefix>' is nil (state <id>)`, `'<path prefix>' is not a table (state <id>)`, `'<path>' is not a function`, `the Lua call raised an error` (the message goes to BiceLib's console as `LuaBridge: <path> failed: <message>`), `the Lua call did not return a table`. (source)

*The common header row.* Unless a page's section says otherwise its first row is: a `Refresh` button (re-reads now and restarts the timer); an `Auto` checkbox (default ticked) that re-reads every 2000 ms of wall-clock time while the tab is visible - the first draw reads at once; then, on the same line, in the dim text colour, either `Lua unavailable: <reason>` (the call could not be made; nothing else is drawn), or the table's `reason` (when `available` is false; nothing else is drawn), or the selected country's tag. (source)

*Reading and writing country variables.* Providers read a variable as `country:GetVariables():GetVariable(CString(name)):Get()` - a number; a variable never set reads 0. They write only by posting the game's own command: `CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(name), CFixedPoint(value)))`, with `countryTag = CCountryDataBase.GetTag(tag)`. Values are given in whole units (`CFixedPoint(50)` is 50.000). No page in this part writes game state any other way, and none sets a flag. (source)

*Pending changes.* `Post` queues the command; reading the variable straight afterwards still gives the old value. So a page that writes records the requested value as pending before the call, shows the requested value instead of the game's with a marker in the warning colour, and drops the pending value when a later read returns the same value. Except on Resource Conversion (10 second timeout) a pending value has no timeout and is not cleared when the selected country changes. (source)

*Colours.* Pages ask the theme for a meaning rather than naming a colour. In the default "dark" theme: warning 204,153,51 (amber); error 217,89,89 (red); error fill 115,38,38; success 115,217,115 (green); success fill 66,150,89. "Dim" is the theme's disabled-text colour. The other themes (grey, light, army green) give other values for the same meanings. (source)

*`wheelCombo`.* A drop-down whose selection can also be stepped with the mouse wheel while hovered: wheel up moves towards the first item, clamped at both ends, and the wheel does not scroll the page underneath. (source)

**Inputs a mod gives it** - `script/gui-imgui.lua` must `require` one module per page (`imgui_country`, `imgui_ic_days`, `imgui_countryinfo`, `imgui_puppets`, `imgui_stratresources`, `imgui_trades`, `imgui_natfocus`, `imgui_ministerbuildings`, `imgui_tradeai`, `imgui_prodsliders`, `imgui_lssliders`, `imgui_resourceconversion`, `imgui_misc`, ...), each defining its table on the global `BiceLibGui` (`Country`, `ICDays`, `CountryInfo`, `Puppets`, `StratResources`, `Trades`, `NatFocus`, `MinisterBuildings`, `TradeAi`, `ProdSliders`, `LsSliders`, `ResourceConversion`, `Misc`); the loader logs through `BiceLibLuaLog` which modules loaded and which failed, and then calls `BiceLib.Overlay.enable()`. `script/bicedata.lua` must have loaded the providers (`BiceData.*`). The mod's helper `GetCountryIterCacheDict()` (in `ai_variable.lua`) is used by two providers: it returns, cached for the life of the Lua state, a map tag string -> country tag object of every country the country `OMG` has a diplomacy record towards, leaving out `REB`, `OMG` and `---`. (source)

**When it applies** - the Lua-backed pages show data only while a game is in play; at the main menu they show `Lua unavailable: no game session`. `G_PlayerCountry` lives in the Lua state, not in the save: a deliberate selection survives loading another save in the same process; an automatic one follows the new player. (source)

**Multiplayer and saves** - every change is a `CSetVariableCommand` posted to the game, which the game broadcasts and runs on every machine (comment in `Hooks/ResourceConversion.hpp`); country variables are saved with the game (a variable that is exactly 0 is dropped from the save and reads 0 again, which is the same thing). The selection, the pending markers, the unsent edits of the three AI forms and each page's `Auto` setting are local to one machine and are not saved. Because the pages act on the selected country, any machine running the overlay can post variable changes for any country it can select. (source, except the broadcast statement: comment)

**Where the player sees it** - the overlay (INSERT), windows `Setup` and `Country Info`.

### Setup > Country (page "Country")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Country`, group `Setup`, order 10.

**What the original does without it** - nothing: this is new.

**What the feature does** - chooses the selected country for every other page, lists the human players, and reports what BiceLib's own daily job did in this game.

Header row as shared (Refresh, Auto every 2000 ms, status), except that on success no tag follows it. Data call: `BiceLibGui.Country.Collect()`.

Section `Country` (separator with that caption):

- If the Lua global `G_PlayerCountry` is empty: dim `No country selected - pages fall back to the actual player.` Otherwise `Selected: <TAG>`. (Because `Collect` resolves the selected country first, which fills `G_PlayerCountry` automatically, the first form only appears when the machine plays no country.)
- If the local machine plays a country: `You are playing: <TAG>` followed on the same line by a small `Select` button that selects that tag.
- A text box 70 units wide for a tag: input forced to upper case, at most 7 characters, its content selected on focus, Enter submits. Beside it a `Set` button (tooltip `Any country's tag, whether anyone is playing it or not.`) and the dim hint `or type a tag`. Enter or `Set` with a non-empty box selects the typed tag.
- If the last selection failed, one line in the warning colour: `<TAG>: not a country, or its player does not allow it`, or `Lua unavailable: <reason>` when the call could not be made. Cleared by the next selection attempt.

Section `Human players`:

- Button `Get players`: calls `BiceLibGui.Country.RefreshPlayers()` and re-reads. Beside it, dim, `<n> found`.
- With no players listed: wrapped text `Press Get players to scan. In single player this lists only you.` and nothing more in this section.
- Otherwise one radio button per player tag, in ascending tag order; the one equal to `G_PlayerCountry` is filled; clicking another selects it. Below, wrapped: `A player can block the host from selecting their country; the selection silently stays put in that case.`

Section `BiceLib setup` - the result of the daily periodics (see Inputs):

- Never run in this game: dim `Not run yet in this game.`
- Last call failed: error colour `Last run <date> failed: <error>`, the error being the bridge's reason text.
- Last call succeeded: success colour `Last run <date>`.
- If any call in this game also checked the HQ unit limits: `HQ unit limits checked <date>` (the date of the latest such call).
- If the limits of the country the local machine plays could be read after the last successful call: `<TAG> may attach: corps <n>, army <n>, army group <n>` - the number of units BiceLib currently allows that country to attach under a corps, an army and an army group headquarters. This is always the played country, not the selected one.
- Then, wrapped: `Runs by itself once a game day, in every player's game - the mod's scripts only run on the host, so this is how each game gets the HQ unit limits. It first runs a couple of game hours after a load is unpaused, and checks the limits then and on every fifth day of the month.`

`<date>` is `year.month.day hour:00` with month and day counted from 1, the hour from 0, no zero padding (for example `1936.1.5 1:00`). (source)

**What the player can change, and how**

- *Selecting a country* (`Select`, `Set`/Enter, a radio button): `BiceLibGui.Country.SelectPlayer(tag)` -> `BiceData.Players.Select(tag)`. An empty tag fails. The tag is upper-cased. It is refused unless `BiceData.Players.AllowsSelection(tag)`: the country's variables must be obtainable (`CCountryDataBase.GetTag(tag):GetCountry()` not nil) and its variable `disable_gui_access` must not be 1. On success `G_PlayerCountry = tag`, the choice is marked deliberate, and - only if the old wxWidgets utility is loaded - `G_DaysSinceLastUpdate = 0` and `GuiRefreshLoop(true)` are run to keep that utility in step. The answer is `{ available = true, tag = TAG }` or `{ available = false, reason = "not a country, or its player does not allow it" }`. The page then invalidates the central selection cache and re-reads. This is a local Lua write; nothing is posted to the game.
- *Get players*: `BiceData.Players.Determine()`: every tag of `GetCountryIterCacheDict()` for which `CCurrentGameState.IsPlayer(countryTag)` is true, sorted ascending, stored in the global `G_PlayerCountries` (which other mod scripts also read, for instance the daily IC-days reduction). The mod also runs it once by itself, on the first daily pass of its scheduled scripts. Local Lua write. (source)

**Inputs a mod gives it**

- `BiceLibGui.Country.Collect()` returns `available = true`, `players` (array of tag strings: `G_PlayerCountries` or empty), `selected` (`G_PlayerCountry` or ""), `current` (the resolved selected tag; not read by the page), `actual_player` (`tostring(CCurrentGameState.GetPlayer())` or "").
- The country variable `disable_gui_access` (1 = this country may not be selected). BlackICE sets it with two zero-cost covert operations a human player runs in his own, self-controlled capital: `disable_gui_acess` (sets 1, offered while it is not 1) and `enable_gui_acess` (sets 0, offered while it is 1).
- The daily periodics. Once per game day BiceLib itself calls the global Lua function `BiceLibDailyPeriodics(firstDay)`: on the first frame, of a day not yet handled, on which the game clock has moved in normal play, the hour is 1 or later and a Lua call is possible; `firstDay` is the number 1 on the first call after a load (a new session) and 0 otherwise. If Lua is busy the next such frame tries again; a call that was made counts for the day even if it failed. The function must return a table; BiceLib reads its boolean `oob_limits_checked`. BlackICE's function calls `CheckOobUnitLimitTechnologyStatus(first)` when the DLL is loaded and returns `{ bicelib_loaded = <DLL loaded>, oob_limits_checked = <loaded and (first or day of month divisible by 5)> }`. `CheckOobUnitLimitTechnologyStatus` (in `ai_variable.lua`; it does nothing unless forced or the day of the month is divisible by 5) works out for every existing country a corps, army and army group limit - each starting at `G_BASE_COC_LIMIT` (4) and raised by fixed amounts at fixed levels of seven technologies - and hands them to `BiceLib.Units.setCorpsUnitLimit`, `setArmyUnitLimit` and `setArmyGroupUnitLimit` with the country's tag. After a successful call BiceLib notes the three limits it now holds for the played country. The status is emptied when a new session starts and is shown empty until the first call of that session. (source)

**When it applies** - needs a game in play for everything below the header; needs no selected country (it is where one is chosen).

**Multiplayer and saves** - the selection and the player list are local and unsaved. The periodics run on every machine, clients included, which is their purpose: the mod's scheduled scripts run only on the host (comment), and the unit limits are held in each process's memory, not in the save, so they are set again after every load (`firstDay`). (source)

**Where the player sees it** - overlay, `Setup` window, first tab.

### Setup > Special (page "Special")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Special`, group `Setup`, order 15.

**What the original does without it** - the game loads the 3D unit sprite files in `gfx\anims` beside the executable whether or not a mod ever draws them; BlackICE draws none, and they take around 300 MB of a 32-bit address space (comment).

**What the feature does** - moves those files into a `backup` subfolder and back. Nothing is deleted, no Lua is involved, and it works at the main menu.

Paths: `<folder of the game executable>\gfx\anims\` and `<same>\gfx\anims\backup\`. Five file names are never moved out (compared without regard to case): `Thumbs.db`, `GenericTankDiffuse.dds`, `GenericTankSpecular.dds`, `GenericTank.xac`, `TankIdleA.xsm` - the generic tank is the fallback model the game still needs. Subfolders are never counted or moved.

The page scans both folders on its first draw, after every move, and on `Rescan`. It draws, top to bottom:

1. Wrapped: `The mod draws no 3D unit sprites, but the game loads them regardless - around 300 MB of an address space that only has 2 to 4 GB in it. Moving them aside is worth doing, and reversible: nothing is deleted, the files go to a backup folder and come back from it.`
2. If `gfx\anims` does not exist: error colour `Not found: <path>`, then `This is looked up next to hoi3_tfh.exe. If the game lives somewhere else, nothing here can be done.`, and nothing else.
3. A table with columns (unnamed), `Files`, `Size` and two rows: `In gfx\anims (movable)` - count and total size of the files there, leaving out the five kept names; `In the backup folder` - count and size of all files there. Size is megabytes (bytes / 1048576) with no decimals, as `<n> MB`.
4. A state line: no movable files and some in backup - success colour `The sprites are moved aside.`; files in backup otherwise - warning colour `Partly moved: there are sprites in both places.`; else dim `The sprites are in place.`
5. While a game is in play: warning colour `Best done at the main menu.` and `Once a game has been started the sprites may be open, and an open file cannot be moved. Nothing is lost if that happens - the files that fail are listed and stay where they are - but a set moved half way is not what you want mid game.` This is advice only; the buttons stay usable.
6. Buttons: `Remove sprites` (disabled with no movable files; hover tooltip then `Nothing left to move: gfx\anims holds only the files that stay behind`), `Restore sprites` (disabled with no files in backup; tooltip `The backup folder is empty` or, if the folder does not exist, `No backup folder yet - nothing has been moved aside`), `Rescan`.
7. `Remove sprites` opens a modal titled `Move the sprites aside?`: `Move <n> files (<size>) into`, the backup path, `The generic tank model stays behind as a fallback. The game will be frozen for a moment while the files move.`, in play also (warning colour) `A game is running: sprites it has open will refuse to move.`, buttons `Move them` and `Cancel`.
8. `Restore sprites` opens a modal titled `Put the sprites back?`: `Move <n> files (<size>) back into`, the anims path, `Needed before playing vanilla or another mod.`, buttons `Put them back` and `Cancel`.
9. After a move, a result line - success colour, or error colour if any file failed: `Not found: <source path>`, or `Nothing to move`, or `Moved <m> of <n> files` with `, <k> failed` appended when some failed. Up to five failures are listed below as `<file>: <system error text> (<system error code>)`. If nothing failed: `Restart the game for this to take effect.`

A move lists the source folder first (skipping the kept names only in the remove direction), creates the destination folder if there is something to move, then moves each file by name; a file that cannot be moved (the game has it open, or one of that name is already at the destination) is counted as failed and left where it is. Both directions are moves on one volume, so a mistake is undone with the other button. (source)

**Inputs a mod gives it** - none.

**When it applies** - any time the overlay is up; meant for the main menu, since files the game has opened refuse to move. The effect on memory comes at the next start of the game. (source)

**Multiplayer and saves** - changes files of the local install only; no game state.

**Where the player sees it** - overlay, `Setup` window, second tab.

### Setup > Misc (page "Misc")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Misc`, group `Setup`, order 130.

**What the original does without it** - nothing: this is new. (The variables are read by BlackICE's own decisions.)

**What the feature does** - two switches that hide groups of the mod's decisions from the selected country's decision list.

Header row as shared (2000 ms). Then a separator captioned `Decisions` and two checkboxes:

- `Hide the resource trading decisions` - ticked when the variable `disable_resource_trade_decision` is 1.
- `Hide the mine expansion decisions` - ticked when `disable_mines_expansion_decision` is 1.

Then, wrapped: `Hiding a decision only takes it out of your own decision list. The AI carries on using it either way, so this is about a tidy list rather than about how the game plays.` (source)

**What the player can change, and how** - ticking or clearing a box calls `BiceLibGui.Misc.SetTradeHidden(n)` or `BiceLibGui.Misc.SetMinesHidden(n)` with n = 1 (hide) or 0 (show). Each posts one `CSetVariableCommand` for the selected country - `disable_resource_trade_decision` or `disable_mines_expansion_decision`, value 1 or 0 - and returns the same table as `Collect`. While the request is pending the box shows the requested state, followed by `waiting...` in the warning colour (tooltip `Waiting for the game to apply this`), until a read returns the requested value. (source)

**Inputs a mod gives it** - `BiceLibGui.Misc.Collect()` returns `available`, `tag`, `tradeHidden`, `minesHidden` (booleans: variable equals 1), or `reason = "No country selected"`. The mod's decisions read the two variables (`decisions/resource_trading.txt`, `decisions/resource_mines_investment.txt`); `common/covert_ops.txt` refers to them as well. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - game command, broadcast; the variables are in the save. (source; broadcast: comment)

**Where the player sees it** - overlay, `Setup` window; the effect is in the game's decision list.

### Country Info > Country Modifiers (page "Country Modifiers")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Country Modifiers`, group `Country Info`, order 20. Read only.

**What the original does without it** - nothing: this is new. The game's Lua API does not give the technology part of several of these figures, which is why the provider adds it from the mod's files (comment).

**What the feature does** - header row as shared (2000 ms), then one two-column table (label 62 percent of the width, value 38 percent, no header) per section, each under a separator carrying the section name. The page draws whatever sections and rows `BiceLibGui.CountryInfo.Collect()` returns (`sections`: array of `{ name, rows }`, `rows`: array of `{ label, value }`, `value` already text). BlackICE returns these, in this order:

Section `Industry`
- `Base IC` - `country:GetMaxIC()`, no decimals.
- `Offmap IC` - `BiceLib.GameInfo.getCountryOffmapIc(tag)`, whole IC as worked out by the last daily pass, 0 if nil; no decimals. Needs BiceLib's offmap IC patch (readme).
- `IC modifier` - the global modifier's `_MODIFIER_GLOBAL_IC_` value plus the technology contribution of `ic_modifier`; shown as a percentage: value times 100, two decimals, `%`.
- `IC efficiency` - country variable `IcEffVariable`, two decimals.
- `Supplies per IC` - the sum of four terms, multiplied by `defines.economy.IC_TO_SUPPLIES`: one; the global modifier's `_MODIFIER_GLOBAL_SUPPLIES_` value; the technology contribution of `ic_to_supplies`; and 0.035 times the variable `supplies_factory_count`. Two decimals.

Section `Research and supply`
- `Research efficiency` - variable `ResEffVariable`, two decimals.
- `Supply throughput` - variable `SuppThrouVariable`, two decimals.

Section `Military`
- `Repair efficiency` - global modifier `_MODIFIER_UNIT_REPAIR_` plus technology contribution of `repair_rate`, as a percentage.
- `Org regain` - global modifier `_MODIFIER_ORG_REGAIN_` plus technology contribution of `org_regain`, as a percentage.
- `Attack delay` - `defines.military.UNIT_ATTACK_DELAY` minus the technology contribution of `attack_delay`, no decimals.
- `Starting experience` - global modifier `_MODIFIER_UNIT_START_EXPERIENCE_`, two decimals.
- `Trickleback` - `BiceLib.GameInfo.getCountryGeneralModifiers(tag)["MODIFIER_TRICKLEBACK"] x 0.001` plus the technology contribution of `casualty_trickleback`, as a percentage; the text `unavailable` when the DLL is not loaded or the entry is missing.

Section `War exhaustion`
- `Monthly` - global modifier `_MODIFIER_WAR_EXHAUSTION_`, plus 20 while `country:IsAtWar()`; two decimals.
- `Current` - variable `war_exhaustion`, one decimal.

"Global modifier" values are `country:GetGlobalModifier():GetValue(CModifier.<name>):Get()`. The "technology contribution" of an effect key is the sum, over every technology whose definition has that key, of the key's value times the selected country's level of that technology (`country:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(name))`; a name that is not a technology counts as level 0). The definitions come from the mod's own files, parsed once per Lua state: every file of `tfh\mod\BlackICE <G_MOD_VERSION>\technologies`, read with the mod's `PdxParser`; only the keys `ic_efficiency`, `ic_modifier`, `research_efficiency`, `supply_throughput`, `repair_rate`, `org_regain`, `attack_delay`, `ic_to_supplies`, `casualty_trickleback` at the top level of a technology are collected (`BiceData.Techs.ModifierValues()`). (source)

**Inputs a mod gives it** - the provider `BiceData.CountryInfo.Collect()`; the variables `IcEffVariable`, `ResEffVariable`, `SuppThrouVariable` (written daily by `CountryModifiers` in `ai_variable.lua`), `supplies_factory_count`, `war_exhaustion`; the defines `military.UNIT_ATTACK_DELAY` and `economy.IC_TO_SUPPLIES`. From BiceLib: `getCountryOffmapIc(tag)` (integer, whole IC, or nil for an unknown tag) and `getCountryGeneralModifiers(tag)` (a map from each entry name of the country's global modifier, such as `MODIFIER_TRICKLEBACK`, to its raw value in thousandths, or nil). (source)

**When it applies** - a game in play and a selected country; otherwise the reason `No country selected`.

**Multiplayer and saves** - reads only.

**Where the player sees it** - overlay, `Country Info` window.

### Country Info > IC Days (page "IC Days")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `IC Days`, group `Country Info`, order 30.

**What the original does without it** - nothing: this is new. "IC days" is a BlackICE mechanic kept in country variables: a debt of IC days (raised by the mod's events; not followed further here) that the country pays off daily at a rate the player chooses.

**What the feature does** - header row as shared, but the interval is 1000 ms and the `Auto` box has the tooltip `Re-read once a second while a game is running.` Then a separator and a two-column table without header:

| row | value |
| --- | --- |
| `IC days left` | variable `IC_days_spent`, never shown below 0; two decimals |
| `Base IC` | variable `BaseIC`; no decimals |
| `Current investment` | variable `event_unit_investment` as `<n>%`, no decimals; while a change is pending, the requested value as `<n>%...` in the warning colour |
| `Daily IC days reduction` | `BaseIC x investment / 100`, rounded to the nearest whole number with halves going up; no decimals; while a change is pending, dim `...` |

Then a separator captioned `Set investment` and an integer slider, 260 units wide, from 20 to 90, labelled `<n>%`. While it is not being dragged it follows the game's value (or the pending one), clamped into 20..90 for display only; Ctrl+click turns it into a text box whose input is clamped to the same range. Below, wrapped: `Drag to choose, and let go to apply. Ctrl+click the slider to type a number instead. Investment converts base IC into IC days at the shown daily rate.` (source)

**What the player can change, and how** - when the slider is released after an edit (once, not during the drag) the page records the value as pending and calls `BiceLibGui.ICDays.SetInvestment(value)`, which posts `CSetVariableCommand(tag, "event_unit_investment", value)` for the selected country, then re-reads. The pending value is dropped when the game's value, truncated to an integer, equals it. (source)

**Inputs a mod gives it** - `BiceLibGui.ICDays.Collect()` returns `available`, `tag`, `ic_days_left`, `base_ic`, `investment`, `daily_reduction`; reasons `No player country`, `No country for tag`. The mod's daily script `ICDaysSpentCalculation` (`ai_variable.lua`, run on the host at the 13:00 minister tick) does the paying off, for each tag in `G_PlayerCountries` only: an investment below 20 is posted as 20; if `IC_days_spent` is above 0 it is lowered by the same rounded `BaseIC x investment / 100` the page shows. `BaseIC` is written by other daily scripts of the mod. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - game command, broadcast; the variable is in the save. (source; broadcast: comment)

**Where the player sees it** - overlay, `Country Info` window.

### Country Info > Puppets (page "Puppets")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Puppets`, group `Country Info`, order 40.

**What the original does without it** - nothing: this is new. A puppet's "production focus" is a BlackICE mechanic kept in a variable of the puppet.

**What the feature does** - header row as shared (2000 ms); the tag shown is the centrally polled selected tag.

Separator `Puppet focus decision`: a checkbox `Available in game`, ticked unless the selected country's variable `disable_pupped_focus_decision` is 1 (spelled so). Tooltip: `Whether the decision for setting a puppet's focus is` / `offered in game. Turning it off hides the decision.` While a change is pending the box shows the requested state and `(pending)` follows in the warning colour.

Separator `Vassals`: with no puppets, dim `This country has no puppets.` and nothing more. Otherwise a table with header, columns `Puppet` (40 percent) and `Focus` (60 percent), one row per puppet in ascending tag order. A row is selectable across both columns; clicking it makes that puppet the one the buttons act on (`BiceLibGui.Puppets.Select(tag)`, which only records the tag in the page's Lua and returns the table again). `Focus` shows the focus name; for the acted-on puppet with a change pending it shows the requested name followed by `...` in the warning colour.

Below the table: with no puppet chosen, dim `Select a puppet to set its focus.` Otherwise `Set focus for <TAG>` - followed by `(waiting for the game)` in the warning colour while a change is pending - and eight buttons, each 84 units wide, four to a line, in this fixed order with these indexes: 1 `Rares`, 2 `Energy`, 3 `Metal`, 4 `Navy`, 5 `Air`, 6 `Army`, 7 `Oil`, 8 `None`. The button of the current focus (the pending one if any) is drawn in the success-fill colour. Any index outside 1 to 8, including an unset variable (0), reads as `None`. (source)

**What the player can change, and how**

- A focus button calls `BiceLibGui.Puppets.SetFocus(index)`, which posts `CSetVariableCommand(<puppet tag>, "puppet_focus_variable", index)` - on the puppet, not on the selected country - and returns the table again; `{ available = false, reason = "No puppet selected" }` if none is chosen. Pending until the puppet's variable reads the same index; choosing another puppet drops the pending focus.
- The checkbox calls `BiceLibGui.Puppets.SetDecisionEnabled(n)` (1 or 0), which posts `CSetVariableCommand(<selected tag>, "disable_pupped_focus_decision", 0 if enabled else 1)`. (source)

**Inputs a mod gives it** - `BiceLibGui.Puppets.Collect()` returns `available`, `puppets` (array of `{ tag, focus }`, focus being the name), `focus_names` (the eight names in index order), `selected` (the acted-on puppet or ""), `selected_focus` (its index, 0 if none), `decision_enabled`. The puppets are `country:GetVassals()` of the selected country, each as `tostring(vassal:GetCountry():GetCountryTag())`, sorted ascending. A chosen puppet that is no longer in the list is forgotten on the next read. The variable `puppet_focus_variable` is read by the mod's production AI (`ai_production_minister.lua`) and its puppet focus events; `disable_pupped_focus_decision` by `decisions/puppet_focus_decision.txt`. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - game commands, broadcast; variables are in the save. Which puppet is chosen is local. (source; broadcast: comment)

**Where the player sees it** - overlay, `Country Info` window.

### Country Info > Strategic Res. (page "Strategic Res.")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Strategic Res.`, group `Country Info`, order 50.

**What the original does without it** - nothing: this is new. BlackICE's ten strategic resources are not game resources; they are kept in country variables.

**What the feature does** - header row as shared (2000 ms), then one table with header, one row per resource in ascending key order: `aluminium`, `chromite`, `copper`, `manganese`, `mass_livestock`, `molybdenum`, `nickel`, `rubber`, `tungsten`, `zinc`.

| column | content |
| --- | --- |
| `Resource` | the key with its first letter capitalised; `mass_livestock` is `Mass Livestock` |
| `Balance` | variable `<key>_ActualBalance` minus 1000 (the mod stores the balance offset by 1000 so that it can go negative); no decimals; in the error colour when below 0 |
| `Selling` | variable `<key>_trade_sell`: how many trades the country sells this resource in; no decimals |
| `Buying` | variable `<key>_trade_buy`; no decimals |
| `Sales` | a checkbox, ticked unless variable `<key>_deactivate_sales` is 1, followed by `Selling` or `Stopped`; while a change is pending, `Selling...` or `Stopped...` in the warning colour with the tooltip `Waiting for the game to apply this` |

The numeric columns are fixed width, the name column takes the rest. (source)

**What the player can change, and how** - the checkbox calls `BiceLibGui.StratResources.SetSelling(key, n)` (1 = allow, 0 = stop), which posts `CSetVariableCommand(<selected tag>, "<key>_deactivate_sales", 0 if allowed else 1)` and returns the table again. Pending per resource until the game reports the requested state. (source)

**Inputs a mod gives it** - `BiceLibGui.StratResources.Collect()` returns `available`, `tag`, `rows` (array of `{ key, name, balance, sell, buy, selling }`). The balances are written by the mod's daily scripts in `ai_variable.lua`; the trade counts by its trade bookkeeping (see Strategic Trades); `<key>_deactivate_sales` is read by `decisions/resource_trading.txt` and by `ai_variable.lua` (how they use it was not followed further). (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - game command, broadcast; variables are in the save. (source; broadcast: comment)

**Where the player sees it** - overlay, `Country Info` window.

### Country Info > Resource Conversion (page "Resource Conversion")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`); what it sets only takes effect with `BiceLib.ComplexPatches.customResourceConversion()` on

Tab title `Resource Conversion`, group `Country Info`, order 55.

**What the original does without it** - once a day, in each country's daily pass, the game converts energy into crude oil and then crude oil into fuel by rules no file can move: at most `max(0.05 x IC, 1)` crude oil a day from energy, at `1 / rate` energy each (`rate` = 0.1 plus technology), only towards holding twice as much energy as crude oil and never out of the `2 x IC` energy industry needs that day; and `IC / 2` crude oil refined a day unless fuel is at 99,000, or above a year of the crude oil coming in and above twice the crude oil held (comment in `Hooks/ResourceConversion.hpp`; reversing/findings/FINDINGS-distribute.md, sections 4 and 6). There is no player control.

**What the feature does** - shows and sets the eight country variables that BiceLib's conversion patch reads for a country a person plays, and shows what the country may convert today. All amounts are a day's, in the units a stockpile is shown in; 0 means "off" or "no limit" (a save drops a variable that is exactly 0, so 0 and never-set must mean the same).

| page field | country variable | meaning to the patch |
| --- | --- | --- |
| `usesOil` | `zzDsafe_usesCustomOilConversion` | 1: energy into crude oil follows the three values below; anything else: the game decides |
| `energyPerDay` | `zzDsafe_CustomConversion_energyPerDay` | energy to spend a day; cut to the capacity |
| `energyKeep` | `zzDsafe_CustomConversion_energyKeep` | never take the energy stockpile below this (the `2 x IC` floor applies as well, whichever is higher) |
| `oilTarget` | `zzDsafe_CustomConversion_oilTarget` | convert only while crude oil held is below this; 0: no limit |
| `usesFuel` | `zzDsafe_usesCustomFuelConversion` | 1: crude oil into fuel follows the three values below |
| `crudePerDay` | `zzDsafe_CustomConversion_crudePerDay` | crude oil to refine a day; cut to the capacity |
| `crudeKeep` | `zzDsafe_CustomConversion_crudeKeep` | never take the crude oil stockpile below this |
| `fuelTarget` | `zzDsafe_CustomConversion_fuelTarget` | refine only while fuel held is below this; 0: no limit; the game's own stop at 99,000 stays |

Layout, top to bottom:

1. Header row as shared, but the interval is 1000 ms and `Auto` has the tooltip `Re-read once a second while a game is running.`
2. If the patch is not on (`installed` false): error colour `The conversion patch is not on, so nothing here takes effect.` Otherwise, if nobody plays the selected country: warning colour `Nobody plays <TAG>, so it converts as the game decides.`
3. If the last send was refused, its reason in the error colour (`Unknown field: <name>`, `No country selected`, or `Could not reach Lua`).
4. Separator `Energy into crude oil`, then:
   - checkbox `Set it myself` (field `usesOil`; ticked when the shown value is not 0). Tooltip: `Off: the game decides - it converts only while we hold more than twice as much energy as crude oil.` / `On: the values below decide, within what our IC allows.` A warning-colour `...` follows while the change is pending.
   - a three-column table without header, greyed out and not editable while the box is not ticked: label, a whole-number input box, and a pending marker (`...` in the warning colour). Rows:
     - `Energy a day` (`energyPerDay`) - tooltip `Energy to spend each day. More than our IC allows is cut to it.`
     - `Keep at least` (`energyKeep`) - tooltip `Never take energy below this. What industry needs today is never converted whatever this says.`
     - `Stop at crude oil` (`oilTarget`) - tooltip `Convert only while we hold less crude oil than this. 0: no limit.`
   - if the patch is on and `oil_rate` is 0 or below: warning colour `No energy can be turned into crude oil yet: technology puts the rate at <oil_rate, two decimals>, and nothing converts at 0 or below.` and dim `Developing a synthetic industry opens it. What is set above applies from then.`
   - otherwise, if the patch is on: dim `Today: at most <energy_cap, two decimals> energy a day, each making <oil_rate, two decimals> crude oil. <energy_floor, no decimals> energy is kept for industry.`
5. Separator `Crude oil into fuel`, built the same way:
   - checkbox `Set it myself` (field `usesFuel`). Tooltip: `Off: the game decides - it refines until we hold more than a year of the crude oil coming in and more than twice our crude oil.` / `On: the values below decide, within what our IC allows.`
   - rows `Crude oil a day` (`crudePerDay`) - `Crude oil to refine each day. More than our IC allows is cut to it.`; `Keep at least` (`crudeKeep`) - `Never take crude oil below this.`; `Stop at fuel` (`fuelTarget`) - `Refine only while we hold less fuel than this. 0: no limit. The game stops at 99,000 whatever this says.`
   - if the patch is on: dim `Today: at most <crude_cap, no decimals> crude oil a day. How much fuel it makes is the game's: technology and laws.`
6. Wrapped: `All amounts are a day's, in stockpile units. Type a number and click away or press Enter to apply it. The covert operation in your capital, Resource conversion, sets the same values from presets.`

A number box shows the pending value if there is one, else the game's value, rounded to the nearest whole number, and is not overwritten while the player is typing in it. (source)

**What the player can change, and how** - every field is sent on its own, at once (there is no Apply):

- a checkbox change sends `(field, 1)` or `(field, 0)`;
- a number box sends when it loses focus after an edit (click away, Tab, Enter); a negative entry is made 0 first.

Sending records `(value, time)` as pending for the field and calls `BiceLibGui.ResourceConversion.Set(field, value)` -> `BiceData.ResourceConversion.Set`: the field must be one of the eight names (else `false, "Unknown field: <field>"`), a country must be selected (else `false, "No country selected"`), a nil or negative value becomes 0, and `CSetVariableCommand(<selected tag>, <variable>, value)` is posted. The answer is `{ ok, reason }`; on refusal the pending entry is removed and the reason shown. A pending entry is dropped at a refresh when the game's value is within 0.0005 of it, or silently after 10 seconds. (source)

**What `BiceLib.GameInfo.getCountryResourceConversion` is used for** - the provider calls it with the selected tag on every refresh. nil means the patch is not on (or the game has no answer for that country) and gives `installed = false`. Otherwise the table supplies the page's `played` flag and the three "Today" figures, so the page states the caps the patch will really hold the player's amounts to. BiceLib works them out from the country's current IC (a whole number) and technology with the same arithmetic the patch uses, in thousandths, and returns them divided by 1000:

- `oil_rate` - crude oil one energy makes: the game's base rate (0.1) plus the country's technology bonus to oil conversion.
- `energy_cap` - the most energy that may be spent a day: 0 if the rate is 0 or below; otherwise `most x per / 1000` (integer division), with `per = max((1000000 + rate / 2) / rate, 1000)` (the energy one crude oil costs, rounded to nearest, never below 1) and `most = max(50 x IC, 1000)` (the game's 0.05 crude oil per IC, never below 1), `rate` in thousandths.
- `energy_floor` - `2 x IC`, the energy industry needs today, never converted.
- `crude_cap` - `IC / 2` rounded towards zero, in whole units.
- `played` - whether a person plays the country (the test the `ai` trigger makes), so that its own settings apply.

In BlackICE energy into crude oil starts closed: every country's history gives it a modifier putting the rate at 0.1 minus 1, and only the synthetic-industry events bring it back above 0; the page's warning line covers that state, and values set early apply from the day it opens (comment). (source for the arithmetic and the page; comment where marked)

**The presets (mod content, same variables)** - the covert operation `set_resource_conversion` (cost 0; valid in the capital of a human-played country that owns and controls it; localised `Resource conversion`) fires country event 1553, which leads to 1554 (energy into crude oil) or 1555 (crude oil into fuel). The presets write only the switch and the per-day amount; they never touch the `Keep` or `Target` variables.

| event 1554 option | `zzDsafe_usesCustomOilConversion` | `zzDsafe_CustomConversion_energyPerDay` |
| --- | --- | --- |
| `Let our engineers decide` | 0 | unchanged |
| `Stop converting energy` | 1 | 0 |
| `10 energy a day` | 1 | 10 |
| `25 energy a day` | 1 | 25 |
| `50 energy a day` | 1 | 50 |
| `As much as our industry allows` | 1 | 99999 |
| `Back` | returns to event 1553 | |

| event 1555 option | `zzDsafe_usesCustomFuelConversion` | `zzDsafe_CustomConversion_crudePerDay` |
| --- | --- | --- |
| `Let our engineers decide` | 0 | unchanged |
| `Stop refining` | 1 | 0 |
| `10 crude oil a day` | 1 | 10 |
| `25 crude oil a day` | 1 | 25 |
| `50 crude oil a day` | 1 | 50 |
| `As much as our refineries allow` | 1 | 99999 |
| `Back` | returns to event 1553 | |

Event 1553's options are `Energy into crude oil`, `Crude oil into fuel`, `Leave things as they are`. Localisation keys: `set_resource_conversion`, `set_resource_conversion_desc`, `EVTNAME1553`..`1555`, `EVTDESC1553`..`1555`, `EVTOPTA1553`..`EVTOPTC1553`, `EVTOPTA1554`..`EVTOPTG1554`, `EVTOPTA1555`..`EVTOPTG1555`, in `localisation/BiceLib_conversion.csv`. So "switch on with an amount of 0" means convert nothing, and 99999 means "whatever the capacity allows". (source)

**Inputs a mod gives it** - `BiceLibGui.ResourceConversion.Collect()` returns `available`, `tag`, the eight fields by the names above (numbers), `installed`, and, when installed, `played`, `oil_rate`, `energy_cap`, `energy_floor`, `crude_cap`; reason `No country selected`. (source)

**When it applies** - a game in play and a selected country. The values can be set at any time, also while the patch is off (they then do nothing) and for a country nobody plays (it converts as the game does until someone plays it). The mod as committed makes the call that switches the patch on. (source)

**Multiplayer and saves** - the values are ordinary country variables set by a broadcast game command and stored in the save; the patch reads only what every machine holds alike (comment in `Hooks/ResourceConversion.hpp`). The "Today" figures are a local read.

**Where the player sees it** - overlay, `Country Info` window; the effect is in the daily resource ledger.

### Country Info > Strategic Trades (page "Strategic Trades")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Strategic Trades`, group `Country Info`, order 60. Read only. (Registered by the same source file as Global Market.)

**What the original does without it** - nothing: this is new. Trades in BlackICE's strategic resources are a mod mechanic kept in country variables and mirrored in a Lua table.

**What the feature does** - header row as shared (2000 ms). Then a separator `Buying` with a table of the trades in which the selected country is the buyer, and a separator `Selling` with a table of those in which it is the seller. An empty list shows dim `None.` instead of a table. Each table has a header and three columns:

| column | content |
| --- | --- |
| `Seller` (in Buying) or `Buyer` (in Selling) | the other side's tag |
| `Resource` | the resource key, for example `chromite` |
| `Expires` | days until expiry as `<n>d`; in the warning colour when 7 or fewer |

Both lists are ordered by days until expiry, soonest first. Days until expiry is the trade's expiry day minus `CCurrentGameState.GetCurrentDate():GetTotalDays()` (0 minus today if the trade has no expiry day). (source)

**Inputs a mod gives it** - `BiceLibGui.Trades.Collect()` returns `available`, `tag`, `buys`, `sales` (arrays of `{ buyer, seller, resource, expires_in }`); reasons `No country selected`, `Trade data not available yet` (when the global is nil). The data is the mod's global Lua table `GlobalTradesData`: tag -> `{ totalTrades, activeTrades, trades = { ["trade_<n>"] = { buyer = <tag>, seller = <tag>, resource = <key>, expiryDate = <total days> } } }`, held under the buyer's tag. The mod's scheduled scripts keep it (`ai_variable.lua`, run at the 17:00 minister tick): `InitTradingData` rebuilds it once per Lua state from the variables `zDsafe_totalTrades`, `zDsafe_activeTrades` and `zDsafe_trade_<n>_buyer|_seller|_resource|_expiryDate` (buyer and seller as indexes into the mod's country list, resource as an index into its strategic resource list); `CheckPendingTrades`/`HandlePendingTrade` add a trade lasting 365 days and raise `<key>_trade_buy` on the buyer and `<key>_trade_sell` on the seller by 1; `CheckExpiredTrades` removes it and lowers them. The page shows whatever that table holds in the render thread's Lua state. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - reads only. The table is rebuilt from saved variables by the mod's scripts, which run on the host (comment); on a machine where they have not run the lists are empty.

**Where the player sees it** - overlay, `Country Info` window.

### Country Info > Global Market (page "Global Market")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Global Market`, group `Country Info`, order 70. Read only.

**What the original does without it** - nothing: this is new.

**What the feature does** - for one strategic resource, lists every country with spare production of it. Independent of the selected country.

First row: `Refresh`; `Auto` (default off; tooltip `Off by default: this reads a variable from every` / `country in the game, which is too much for a timer.`; when ticked the interval is 5000 ms); a resource drop-down (`wheelCombo`, 160 wide) of the ten strategic resources in ascending key order under their display names. Choosing a resource refreshes at once. There is no read on first draw: until `Refresh` is pressed or a resource is chosen the page shows only the bridge's last reason text in dim, and after a failed call the same; a `reason` returned by Lua is shown dim (`No resource selected`).

With data: if no row, dim `No country has spare production of this resource.` Otherwise a vertically scrolling table with a frozen header, sized to leave room for the note below it (never less than three text lines high):

| column | content |
| --- | --- |
| `Country` | tag |
| `Potential` | the country's variable `<key>_building_balance` minus 1000 (the country's production of the resource, its puppets' included (comment)); no decimals |
| `Sales` | variable `<key>_trade_sell`; no decimals |
| `Available` | Potential minus Sales; no decimals; in the success colour when above 0 |
| `Next expiry` | `<n>d`, or dim `-` |

Only countries with Potential above 0 are listed, largest Potential first. `Next expiry` is -1 (shown `-`) unless Sales is above 0 and a trade with that seller and resource is found in `GlobalTradesData`; then it is that trade's expiry day minus today.

Below, wrapped: `A trade decision can be unavailable even when a country has resources spare: each trade applies a two day cooldown that blocks the buy decision while it is handled. Wait and watch your decisions.` (source)

**Inputs a mod gives it** - `BiceLibGui.Trades.Resources()` returns `available`, `resources` (array of `{ key, name }`; fetched once, when the list is still empty). `BiceLibGui.Trades.Market(key)` returns `available`, `resource`, `rows` (array of `{ tag, potential, sales, available, next_expiry }`). The provider walks `GetCountryIterCacheDict()` and reads two variables per country. (source)

**When it applies** - a game in play; no selected country needed.

**Multiplayer and saves** - reads only.

**Where the player sees it** - overlay, `Country Info` window.

### Country Info > National Focus (page "National Focus")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `National Focus`, group `Country Info`, order 80.

**What the original does without it** - nothing: this is new. The national focus is a BlackICE mechanic: one country variable names the active focus, a day counter per focus rises while it is active and falls while it is not, and the mod's triggered modifiers give bonuses by counter.

**What the feature does** - header row as shared (2000 ms). On first successful draw the page also fetches the focus effects once (`BiceLibGui.NatFocus.Effects()`), which parses mod files.

Wrapped: `The focus can be changed at any time, but the effects are not instant: a new focus takes about 90 days before it gives anything, and the old one wears off over as long as it was active for. Bonuses come in three tiers, reached after 90, 360 and 720 days.`

A line `Current focus:` followed by the active focus's name (`None` for index 0 or below, `Unknown` for an index not in the list); while a change is pending, the requested name followed by `...` in the warning colour with the tooltip `Waiting for the game to apply this`. Beside it a `Clear` button, disabled when the shown focus is none.

A table with header, one row per focus in this fixed index order - 1 `Ground Forces` (`ground_forces`), 2 `Air Force` (`air_force`), 3 `Navy` (`navy`), 4 `Economy` (`economy`), 5 `Science` (`science`), 6 `Health + Education` (`health_and_education`), 7 `Natural Resources` (`natural_resources`):

| column | content |
| --- | --- |
| `Focus` | the name; in the success colour for the shown (active or pending) focus |
| `Days` | variable `<key>_national_focus_days_active`, never shown below 0; no decimals |
| `Tier` | 0 to 3: the highest of the thresholds 90, 360, 720 the days have reached (days >= threshold) |
| `Next tier` | a progress bar filled to days / next threshold with the overlay text `<days> / <next threshold>`; dim `max` at tier 3 |
| `Effect` | at tier 0 dim `below tier 1`; otherwise the effects of the focus at its current tier as `<label> <value>` joined by `, `, or `-` if none are known. Hovering shows a tooltip: the focus name, then for each tier that has effects a caption `Tier <n>` (with ` (active)` on the current tier) and one line per effect, `<label>  <value>` - normal text for the current tier, dim for the others |
| (unnamed) | for the shown focus dim `Active` (`...` while pending); for every other focus a `Set` button |

(source)

**What the player can change, and how** - `Set` on a row and `Clear` call `BiceLibGui.NatFocus.Set(index)` (the row's index, or 0 to clear), which posts `CSetVariableCommand(<selected tag>, "national_focus", index)` and returns the table again. The requested index is pending until the variable reads the same. (source)

**Inputs a mod gives it**

- `BiceLibGui.NatFocus.Collect()` returns `available`, `tag`, `active` (variable `national_focus`), `rows` (array of `{ index, key, name, days, tier, nextTier, active }`, `nextTier` 0 at the top tier).
- `BiceLibGui.NatFocus.Effects()` returns `available`, `rows` (array of `{ key, name, tier, label, value }`, one per effect) and `tierLabels` (`90 days`, `360 days`, `720 days`; not used by this page). The effects are read once per Lua state from the mod's `common\event_modifiers.txt` and `common\triggered_modifiers.txt` (under `tfh\mod\BlackICE <G_MOD_VERSION>\`): for focus key K and tier word W (`one`, `two`, `three`) every modifier named exactly `Nat_focus_<K>_<W>` or beginning `Nat_focus_<K>_<W>_` is merged (a tier with more than five effects is split over several such modifiers because the game's own modifier tooltip shows five); the keys `potential`, `trigger` and `icon` are left out; of a key written twice the last value counts. `label` is the effect key's localised name - looked up in the mod's localisation as `MODIFIER_<KEY IN UPPER CASE>`, then `<key in lower case>_eff`, then `<KEY IN UPPER CASE>`, then by three special cases (`global_manpower_modifier` -> `GLOBAL_MANPOWER`, `local_manpower_modifier` -> `LOCAL_MANPOWER`, `casualty_trickleback` -> `CASUALTY_TRICKLEBACK_TECH`), else the raw key. `value` is the number times the multiplier, with two decimals and the unit, that `script\utility\gameinfos\unitConversion.csv` (semicolon separated: effect key; multiplier; unit) gives for the key, or the raw value as text when the key is not in that file. Effects of a tier are sorted by label, ascending.
- The mod's daily script `CalculateFocuses` (`ai_variable.lua`, host, 17:00 tick): with d = days since it last ran, for every country it adds d to the active focus's counter, subtracts d from every other counter that is above 0, sets a negative one to 0, rounds to the nearest whole number and posts the result. The index order above is the order that script uses and must not change. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - game command, broadcast; variables are in the save. (source; broadcast: comment)

**Where the player sees it** - overlay, `Country Info` window; the bonuses themselves show in the game as triggered modifiers.

### Country Info > Minister Buildings (page "Minister Buildings")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Minister Buildings`, group `Country Info`, order 90. Read only.

**What the original does without it** - nothing: this is new. In BlackICE each kind of "minister building" has a counter variable that the mod's decisions and events tick up, and a threshold at which the building is placed.

**What the feature does** - header row as shared (2000 ms) with one addition between `Auto` and the status: a sort drop-down (`wheelCombo`, 120 wide) with `Progress` (default), `Name`, `Category`.

Wrapped: `Progress towards the next building each of your ministers will place. The counters are maintained by the AI, so nothing on this page can be set.`

A vertically scrolling table with frozen header:

| column | content |
| --- | --- |
| `Building` | display name |
| `Count` | `<count> / <trigger>`, no decimals; count is the variable `<key>_variable_count_minister`, never shown below 0 |
| `Progress` | a progress bar filled to count / trigger (drawn full at most) with the overlay text `<percent, one decimal>%` (the percentage itself is not capped) |

Rows, in "Category" order, with key and trigger:

| # | key | name | trigger |
| --- | --- | --- | --- |
| 1 | `smallarms_factory` | Small Arms Factory | 80 |
| 2 | `tank_factory` | Tank Factory | 90 |
| 3 | `light_aircraft_factory` | Light Aircraft Factory | 110 |
| 4 | `medium_aircraft_factory` | Medium Aircraft Factory | 110 |
| 5 | `heavy_aircraft_factory` | Heavy Aircraft Factory | 110 |
| 6 | `small_ship_shipyard` | Small Shipyard | 30 |
| 7 | `medium_ship_shipyard` | Medium Shipyard | 54 |
| 8 | `capital_ship_shipyard` | Capital Shipyard | 80 |
| 9 | `submarine_shipyard` | Submarine Shipyard | 90 |
| 10 | `heavy_industry` | Heavy Industry | 70 |
| 11 | `supplies_factory` | Manufacturing (Supply) | 30 |
| 12 | `research_lab` | Research Centers | 42 |
| 13 | `military_college` | Training Centers | 50 |
| 14 | `artillery_factory` | Artillery Factory | 65 |
| 15 | `radar_station` | Radar Station | 40 |
| 16 | `automotive_factory` | Automotive Factory | 54 |
| 17 | `resource_buildings` | Resource Mines | 54 |
| 18 | `rail_terminus` | Railway Terminus | 30 |
| 19 | `hospital` | Hospital | 40 |

Sort: `Progress` - percentage descending, ties in category order; `Name` - by name without regard to case; `Category` - the order above. The sort is stable and re-applied on every refresh and whenever the mode changes. (source)

**Inputs a mod gives it** - `BiceLibGui.MinisterBuildings.Collect()` returns `available`, `tag`, `rows` (array of `{ key, name, order, count, trigger, percent }`, percent = count / trigger x 100). The names and triggers are fixed in the provider; the counters are the mod's (`decisions/Minister_count.txt` and `events/National_focus_buildings.txt` refer to them; not followed further). (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - reads only.

**Where the player sees it** - overlay, `Country Info` window.

### Shared by the three AI settings pages (Trade AI, Prod. Sliders AI, LS Sliders AI): the staged form

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. BlackICE lets a human player hand trade, the production sliders or the leadership sliders to the mod's own AI Lua, steered by a block of country variables per system. Each block has a common prefix, a "uses" variable (1 once the country has been configured) and an "active" variable (1 while the AI should run).

**What the feature does** - the three pages are forms, not reports. They have no `Refresh`/`Auto` row. Each provider exposes five functions on `BiceLibGui.<Page>`: `Collect()`, `SetValue(field, value)`, `Discard()`, `Commit()`, `SetActive(n)`.

*Loading and polling.* Every 2000 ms while visible the page calls `Collect()`. Until the first successful load, and on `Reload`, it takes everything (and marks the form unedited). Afterwards it takes only `active`, `configured` and the tag, leaving the fields being edited alone - unless the tag has changed, in which case all values are replaced by the new country's and any edits are lost. While the country has never been configured (`configured` false) `Collect()` returns the page's defaults instead of the variables (which are all 0).

*The top row.* A button `Enable` or `Disable` (by the shown active state); the state - success colour `Active`, dim `Inactive`, or while pending `Active...` / `Inactive...` in the warning colour with the tooltip `Waiting for the game to apply this`; a button `Apply`; a button `Reload` (tooltip `Reads the settings back from the game, discarding edits`); the tag, dim.

*Status lines.* If not configured: warning colour `Never configured - showing defaults. Apply to adopt them.` Then either the result of the last Apply (success colour `Applied`, or the refusal reason in the error colour) or, if a field has been edited since, warning colour `Edited - press Apply to send it to the game`. Editing any field clears the last result.

*Apply.* (1) `Discard()` empties the provider's staging table. (2) The page calls `SetValue(field, value)` once per field, in the order given in each page's section. The provider accepts only field names on its whitelist and answers `{ ok, reason }`; an unknown one gives `ok = false`, `reason = "Unknown field: <field>"`, which stops the Apply with that reason shown and nothing posted. (3) `Commit()`: the provider applies its own rule (see each page), then for every staged field posts `CSetVariableCommand(<selected tag>, <prefix><field>, value)` - in no particular order - and finally posts the "uses" variable = 1; it empties the staging table and answers `{ ok = true, corrections = [ { field, value } ... ] }` (plus the fields of `Collect()`, which the page ignores because they still show the old values), or `{ ok = false, reason }` with nothing posted (`No country selected`, or the rule's own message). A missing provider function answers `Data provider missing: <function>`.

*Enable / Disable.* `Enable` first performs an Apply, so the AI starts on what is on screen; if that is refused nothing more happens. Then the page records the requested state as pending and calls `SetActive(1)`, which posts the "uses" variable = 1 and the "active" variable = 1. `Disable` calls `SetActive(0)`, which posts only the "active" variable = 0. Both return the `Collect()` table. (source)

**Multiplayer and saves** - everything is posted as `CSetVariableCommand`s, broadcast; the variables are in the save. The staged and edited values are local until Apply. The AI Lua that reads the variables is the mod's and runs where the mod's scripts run. (source; broadcast: comment)

### Country Info > Trade AI (page "Trade AI")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Trade AI`, group `Country Info`, order 100. Form as described in the shared section.

**What the original does without it** - nothing: this is new.

**What the feature does** - prefix `zzDsafe_TradeAi_`, "uses" `zzDsafe_usesCustomTradeAi`, "active" `zzDsafe_CustomTradeAiActive`.

Below the common rows: a number box `Max daily deficit` (120 wide, no decimals; tooltip `The largest daily money deficit the AI may run to pay for its purchases`); then a table with header:

| column | content |
| --- | --- |
| `Resource` | name |
| `Daily surplus` | number box, two decimals |
| `Sell above` | number box, no decimals; dim `-` for Money |
| `Stockpile` | number box, no decimals; dim `-` for Money |

Rows, fields and defaults (shown until the country is configured):

| name | key | Daily surplus (`<key>_Buffer`) | Sell above (`<key>_BufferSaleCap`) | Stockpile (`<key>_BufferCancelCap`) |
| --- | --- | --- | --- | --- |
| Money | `MONEY` | 1 | - | - |
| Fuel | `FUEL` | 1 | 30000 | 20000 |
| Energy | `ENERGY` | 5 | 40000 | 30000 |
| Metal | `METAL` | 2.5 | 20000 | 15000 |
| Rares | `RARE_MATERIALS` | 1 | 10000 | 7500 |
| Crude Oil | `CRUDE_OIL` | 0.25 | 20000 | 15000 |

`Max daily deficit` is the field `MaxDailySell`, default 50.

Then, wrapped: `Daily surplus is how much of a resource the AI keeps coming in each day beyond what the country actually needs. It only sells once the stockpile is above "Sell above", and cancels its own purchases once the stockpile is above "Stockpile". Supplies are left to the AI's own judgement.` (source)

**What the player can change, and how** - Apply stages `MaxDailySell`, then per row `<key>_Buffer` and, for rows with caps, `<key>_BufferSaleCap` and `<key>_BufferCancelCap`. Commit has no rule of its own. It posts each as `zzDsafe_TradeAi_<field>`; for every `<key>_BufferCancelCap` it also posts `zzDsafe_TradeAi_<key>_BufferBuyCap` with the same value; then `zzDsafe_usesCustomTradeAi` = 1; then `zzDsafe_WantsToChangeCustomTradeAi` = 1, which asks the mod's trade AI to reload its limits. Enable/Disable set `zzDsafe_CustomTradeAiActive`. (source)

**Inputs a mod gives it** - `Collect()` returns `available`, `tag`, `active`, `configured`, `maxDailySell`, `rows` (array of `{ key, name, hasCaps, buffer, saleCap, cancelCap }`). The mod's `ai_trade.lua` consumes the variables: its daily `CheckCountryWantsToChangeCustomTradeAi` (host, 13:00 tick) reloads a country's limits from the variables when `zzDsafe_WantsToChangeCustomTradeAi` is 1 (and posts it back to 0 and the "uses" variable to 1), and its trade routines use those limits for a country whose `zzDsafe_CustomTradeAiActive` is 1. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - as the shared form.

**Where the player sees it** - overlay, `Country Info` window; the effect is in the country's trade agreements.

### Country Info > Prod. Sliders AI (page "Prod. Sliders AI")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `Prod. Sliders AI`, group `Country Info`, order 110. Form as described in the shared section.

**What the original does without it** - nothing: this is new.

**What the feature does** - prefix `zzDsafe_CustomProductionSliders_`, "uses" `zzDsafe_usesCustomProductionSliders`, "active" `zzDsafe_CustomProductionSliders_isActive`.

Below the common rows, a table with header:

| column | content |
| --- | --- |
| `Category` | name |
| `Priority` | whole-number box; its background is the error-fill colour, with the tooltip `Another category already uses this priority`, while another row has the same number |
| `Amount` | number box, no decimals |
| `Mode` | drop-down (`wheelCombo`): `Percentage` (0) or `Flat IC` (1); for Lend Lease the fixed dim text `Flat IC` |
| `Extra` | by category: a checkbox `Limit` and a number box (Upgrades, Reinforcement); a checkbox `Goal` and a number box (Supply); a checkbox `Reduce dissent` (Consumer Goods); nothing otherwise |

Rows, in this order, with their defaults (shown until configured; the extra checkboxes default to off):

| name | key | priority | amount | mode | extra |
| --- | --- | --- | --- | --- | --- |
| Upgrades | `upgrade` | 4 | 100 | Percentage | limit 50 |
| Reinforcement | `reinforce` | 2 | 100 | Percentage | limit 50 |
| Supply | `supply` | 3 | 100 | Percentage | goal 50000 |
| Production | `production` | 5 | 25 | Flat IC | - |
| Consumer Goods | `consumer` | 1 | 100 | Percentage | reduce dissent |
| Lend Lease | `lendLease` | 6 | 0 | fixed Flat IC | - |

Then, wrapped: `This only takes effect with "Prioritize Upgrades/Custom" selected in the production window. IC is handed out in priority order, starting at 1, and each priority may only be used once. A category that cannot be paid for in full takes whatever is left and the ones after it get nothing; anything still unspent goes to production. Amount is read either as a share of what the category needs or as a flat IC figure, depending on its mode.` and `Upgrades and reinforcement can be capped so an emergency cannot swallow the whole budget. Supply can be given a stockpile goal, which it puts a little extra IC towards until it is reached. Consumer goods can take 50% more IC while there is dissent.` (source)

**What the player can change, and how** - Apply stages, per row: `<key>Prio`, `<key>Amount`, `<key>InvestMode`; then for Upgrades and Reinforcement `<key>Limit` and `<key>Limit_active` (1 or 0); for Supply `supplyGoal` and `supplyGoal_active`; for Consumer Goods `reduceDissent`. Commit's rule: if two staged priorities are equal it refuses with `Priority <n> used by both <first category name> and <second category name>` (categories taken in the table's order) and posts nothing. Otherwise each is posted as `zzDsafe_CustomProductionSliders_<field>`, then the "uses" variable = 1. (source)

**Inputs a mod gives it** - `Collect()` returns `available`, `tag`, `active`, `configured`, `rows` (array of `{ key, name, extra ("limit", "goal", "dissent" or ""), fixedMode, prio, amount, mode, limit, limitActive, goal, goalActive, reduceDissent }`). The mod's `ai_production_minister.lua` consumes the variables in `BalanceProductionSliders`, the function the game calls to set a country's production sliders: when the "active" variable is 1 and the priority selection the game passes in equals 2 (the setting the page's text calls "Prioritize Upgrades/Custom"), it computes the six shares itself and posts a `CChangeInvestmentCommand`. In short (mod code, summarised): each category's need is taken as a share of total IC; with `reduceDissent` on and dissent above 0.01 the consumer need becomes `max(0.075, need x 1.5)`; an active limit caps the upgrade or reinforcement need at `limit / total IC`; an active supply goal not yet met raises the supply need to the larger of need x 1.2 and (need in IC plus 10, or plus 3 when total IC is 100 or less) / total IC; then, in priority order 1, 2, 3 ..., a Percentage category takes `min(what is left, need x amount / 100)` and a Flat IC category `min(what is left, amount / total IC)` (Lend Lease is always flat); anything above 0.01 still left goes to production. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - as the shared form.

**Where the player sees it** - overlay, `Country Info` window; the effect is on the production sliders.

### Country Info > LS Sliders AI (page "LS Sliders AI")

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

Tab title `LS Sliders AI`, group `Country Info`, order 120. Form as described in the shared section.

**What the original does without it** - nothing: this is new.

**What the feature does** - prefix `zzDsafe_CustomLeadershipSliders_`, "uses" `zzDsafe_usesCustomLsSliders`, "active" `zzDsafe_CustomLeadershipSliders_isActive`.

Below the common rows, a table with header: an unnamed name column, `Lower`, `Upper` (number boxes, no decimals). Rows and defaults:

| name | key | lower | upper | maximum |
| --- | --- | --- | --- | --- |
| Officers | `officers` | 110 | 110 | 110 |
| Spies | `spies` | 10 | 20 | none |
| Diplo | `diplo` | 10 | 20 | none |

A row with a maximum has the tooltip `The engine will not take more than <maximum>` on its name. Below the table a checkbox `Buffer NCOs` (default ticked; tooltip `Keeps producing officers for 10 more days, for a buffer of around 500`).

Then, wrapped: `This only takes effect with "Slider AI" selected in the technology window. The numbers are resource amounts rather than slider positions: once a resource falls below its lower threshold the AI produces it until the upper threshold is reached, and how much leadership that takes is its own decision.`; `Officers cannot be set above 110, which is an engine limit. Diplomacy takes influences already running into account. Leadership is handed out to officers first, then spies, then diplomacy, and research takes whatever is left.`; and `Warning:` in the warning colour followed by `with the slider AI on, the game stops automatically continuing research once a level finishes.` (source)

**What the player can change, and how** - Apply stages, per row, `<key>Lower` and `<key>Upper`, then `bufferProdNco` (1 or 0). Commit's rule, per category in table order: a lower or an upper value above the category's maximum is lowered to the maximum; then, if lower is above upper, lower is set to upper. Every value changed this way is returned as a correction `{ field, value }`; the page writes the corrections back into its boxes and shows `Applied, with values corrected to fit the limits` instead of `Applied`. The fields are posted as `zzDsafe_CustomLeadershipSliders_<field>`, then the "uses" variable = 1. (source)

**Inputs a mod gives it** - `Collect()` returns `available`, `tag`, `active`, `configured`, `bufferNco`, `rows` (array of `{ key, name, maximum (0 = none), lower, upper }`). The mod's `ai_tech_minister.lua` consumes the variables when the "active" variable is 1: the officer thresholds are read divided by 100 as an officer ratio, the spy and diplomat thresholds as amounts; it keeps its own working variables under the same prefix (`investingNco`, `investingSpies`, `investingDiplo`, `previousNco`, `previousSpies`, `previousDiplo`, `dateReachedNco`, `bonusNco`), which the page neither shows nor writes. (source)

**When it applies** - a game in play and a selected country.

**Multiplayer and saves** - as the shared form.

**Where the player sees it** - overlay, `Country Info` window; the effect is on the leadership sliders.

## Part 6 - Pages: Game Info, Inspector lists, Stats, Help; the game-info reads

### Shared conventions of the pages in this part

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, which the mod calls only when `G_ImguiUtilityEnabled` is true in `script/utility_settings.lua`; the mod as committed has it `true`)

**What the original does without it** - nothing: this is new. The original has no window that shows a mod's trait, technology, unit, modifier or leader definitions, a country's flags and variables, or collected statistics.

**What the feature does** - Every page below is one tab of a dockable window named after its group. Groups in display order are `Setup`, `Country Info`, `Game Info`, `Inspector`, `Stats`, `Options`, `Help`, `Debug`; inside a group pages sort by their order number (low first), then by title. A page whose title is used by another page gets the internal window name `<title>##<group>` (the part from `##` is not shown), so the Help group's "Misc" and "National Focus" tabs are distinct from the Setup "Misc" and Country Info "National Focus" tabs. A page is drawn only while the overlay is visible and its tab is the one showing; all of a page's state (lists, selection, filters, pane widths) is memory of the overlay process and is kept while the game runs, across saves and loads, and is lost when the game exits. (source)

*The Lua bridge.* A page that needs mod data calls a global Lua function by dotted path (for example `BiceLibGui.Traits.Collect`) in the Lua state the render thread uses, with no argument, one string, one number, or a string and a number, and expects one table back. The call is refused, and the page shows the refusal text in dim grey, when any of these holds (checked in this order): no game is on screen - text `no game session` (this is the game's own "in game" flag, false at the main menu and in the lobby); the caller is not the render thread - `not on the render thread`; the render thread has not yet run any Lua - `the render thread has not run Lua yet`; a Lua call is already running on this thread - `a Lua call is already in flight`. Further failure texts: `'<path prefix>' is nil (state <id>)`, `'<path prefix>' is not a table (state <id>)`, `'<path>' is not a function`, `the Lua call raised an error` (the Lua message goes to the DLL's console log as `LuaBridge: <path> failed: <message>`), `the Lua call did not return a table`. From the returned table the page reads number fields (a missing or non-numeric field reads as the given default, 0 unless said), boolean fields (nil reads as the default, anything else by Lua truthiness), string fields (numbers are accepted as strings; nil reads as the default), plain arrays of strings, and arrays of flat tables. Every string read is converted from Windows-1252 to UTF-8 unless it already is valid UTF-8. (source)

*The mod side of every call.* Each `BiceLibGui.<Page>.<Function>` wraps its body in `Page.Guard` (`utility_imgui/imgui_page.lua`): the body runs under `pcall`, and an error becomes the table `{ available = false, reason = <error text> }`. A successful answer carries `available = true`. Pages show `reason` (default text `unavailable`) when `available` is false. (source)

*The reported country.* Once per frame the overlay refreshes, at most every 2000 ms, the tag every page reports on by calling `BiceLibGui.Country.CurrentTag()`; the answer is `{ available = true, tag = "GER" }` or `{ available = false, reason = "No player country" }`. The mod's rule (`BiceData.Players.CurrentTag`): the tag is the Lua global `G_PlayerCountry`; when that is nil it is set to the tag `CCurrentGameState.GetPlayer()` answers and marked as chosen automatically; while it is an automatic choice it follows the actual player whenever the two differ (so a newly loaded save moves it); a deliberate choice on the Setup "Country" page is left alone. When no tag is known the stored tag is empty and its reason is the refusal or `reason` text. (source)

*Choice strings.* Lists of definitions are arrays of strings of the form `<English localisation of the key> [<key>]`, or `[<key>]` when the key has no localisation (`BiceData.Translations.Choice`). The localisation table is every file of `tfh\mod\BlackICE <G_MOD_VERSION>\localisation`, read as semicolon separated text taking only the first two columns (key, English); lines starting with `#` are skipped; a key in a later file replaces the same key from an earlier one; the table is built on first use and kept for the life of the Lua state. The key is recovered from a choice string as the text between the first `[` and the first `]` after it; a string with no such pair is used whole (`KeyFromChoice`). (source)

*The filtered list widget* (used for every definition list): a bordered child pane holding a full-width text input with the hint `Filter` and, below it, one selectable row per item whose text contains the filter as a case-insensitive substring (empty filter = all). The selected item is highlighted; if it is filtered out nothing is highlighted but the selection string is kept. While the pane has keyboard focus and the filter box is not being typed in, Down selects the next visible row (the first when nothing visible is selected), Up the previous (the last when nothing is selected), Home the first, End the last, clamped at both ends without wrapping; the newly selected row is scrolled to the vertical centre, and the keyboard is claimed so the game map does not also scroll. Clicking a row selects it. The widget reports "selection changed" for a click (even on the already selected row) and for a key move. (source)

*Splitters and the wheel combo.* Two panes side by side are separated by a 6 pixel wide draggable divider that changes the left pane's width, clamped so the left pane keeps at least a minimum width (120 unless said) and the right pane at least a minimum (200 unless said); the mouse cursor becomes the east-west resize cursor over it. A "wheel combo" is a drop-down whose selection also moves one item per mouse wheel notch while hovered (wheel up = towards the first item), clamped at both ends, and which keeps the wheel from scrolling the page. (source)

*Text dumps.* Several panes show a Lua table rendered as text by the mod's `Utils.Dump` family. A table renders as `{`, a line break, then one line per entry indented four spaces per nesting level, then `}` at the parent's indent. An entry with a non-numeric key renders as `"<key>" = <value>`; an entry with a numeric key renders as the value alone; a nested table renders recursively; any other value renders through `tostring`. Entry order: `Utils.Dump` - keys sorted by their upper-cased text; `Utils.DumpCustomOrder(t, order)` - the keys named in `order` first in that order (those present), then the rest sorted as before, nested tables through `Utils.Dump`; `Utils.PushTablesToEndAndSort` followed by `Utils.DumpByMetatableOrder` - at every level all non-table entries first, sorted by upper-cased key, then all table entries, sorted the same way. These panes are read-only multi-line text boxes, so the text can be selected and copied. (source)

*Effect values.* `BiceData.Translations.ConvertEffect(key, value)` looks `key` up in `tfh\mod\BlackICE <G_MOD_VERSION>\script\utility\gameinfos\unitConversion.csv` (semicolon separated, `#` lines skipped, columns: effect key; multiplier; unit text, which may begin with a space, for example ` kph` or ` days`). When found the result is `value * multiplier` formatted with two decimals followed by the unit text (so `0.05` with multiplier 100 and unit `%` gives `5.00%`); when not found the result is the value as text, unchanged. Keys that end in `_tech` in that file are the technology and unit variants of an effect (looked up as `<key>_tech`). (source)

*Meaning colours.* "Warning" and "error" text use the active overlay theme's mark colours, as R,G,B: dark theme warning 204,153,51 and error 217,89,89; grey theme 230,180,70 and 232,110,105; light theme 158,100,0 and 180,30,30; army green theme 226,162,38 and 196,74,62. "Dim" text is the theme's disabled-text colour. (source)

**Inputs a mod gives it** - the Lua global tables `BiceLibGui` and `BiceData` (loaded by `gui-imgui.lua` and `bicedata.lua`), the globals `G_PlayerCountry`, `G_MOD_VERSION` (the folder suffix in every path `tfh\mod\BlackICE <G_MOD_VERSION>\...`, relative to the game's working directory), the helper modules `Utils`, `PdxParser`, `CsvParser`, `GetFilesFromPath` (file names of one folder, subfolders left out) and `CheckFileExists`. `PdxParser.parseFile(path)` turns a Clausewitz text file into nested Lua tables: `key = value` gives a string value (numbers stay strings), `key = { ... }` with at least one `=` before the first closing brace gives a table, without one gives a list of strings, `#` starts a comment, a key repeated in one block becomes a list of its values in file order, and the keys `not`, `or`, `and`, `tag`, `this`, `from`, `limit` are upper-cased whatever their case in the file. With a second argument `true` the top level is returned as a list of one-key tables in file order instead of one merged table. (source)

**When it applies** - Pages exist from the moment the overlay is installed. Every call through the bridge needs a game on screen, so at the main menu these pages show `no game session` (the Inspector list pages show the selection's reason instead). The mod data behind the Game Info pages can be parsed ahead of time by the overlay's warm-up (one dataset per frame at the main menu, starting 5 seconds after the first frame, when `G_ImguiWarmupEnabled` is not `false`), in this order: unit models, generals, units, technologies, traits, modifiers, province buildings. (source)

**Multiplayer and saves** - Nothing in this shared layer changes game state. `BiceData.Players.CurrentTag` may assign the Lua global `G_PlayerCountry` on the local machine only.

**Where the player sees it** - the overlay (INSERT), windows "Game Info", "Inspector", "Stats" and "Help".

### Page "Traits" (Game Info, order 50)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. In the original a trait's effects can only be read from its tooltip on a leader that has it.

**What the feature does** - Top row: a button `Reload`, then on the same line a dim status. Before a list is loaded the status is `Press Reload to parse traits.txt.` or the failure text; the page makes exactly one automatic load attempt, on the first frame it is drawn in the process, and after that loads only on `Reload`. `Reload` fetches the list again and, when a trait is selected, its details again. Once loaded the status is `<N> traits`.

Below: left pane, the filtered list of every trait as choice strings, initial width 260 pixels; a splitter; right pane. The right pane shows `Select a trait.` (dim) when nothing is selected, the failure text when the detail call failed, and otherwise: the bare trait key; a separator; the label `Effects` over a read-only text box taking half the remaining height (less one text line); the label `Triggers` over a second box of the same height, which reads `(none)` when the trait has no trigger text. Details are fetched once, when the selection changes. There is no timed refresh. (source)

List (`BiceLibGui.Traits.Collect()` returns `{ available, traits = { choice strings } }`): one entry per top-level key of `common\traits.txt`, sorted by upper-cased choice string.

Details (`BiceLibGui.Traits.Details(choice)` returns `{ available, key, effects, triggers }`, or unavailable with reason `Unknown trait: <choice>`):

- `effects` is a dump (non-table entries alphabetical, then table entries) of: the entry `allowed_leader` copied raw from the definition and forced to be the first line; for every other key with a plain value, an entry named by the localisation of `TRAIT_<KEY IN UPPER CASE>` (the raw key when there is none) whose value is `ConvertEffect(key, value)`; for the keys `terrain_speed`, `terrain_attack`, `terrain_defence` (blocks of `type = <terrain>` and `value = <number>`, one block or several) an entry named `Speed`, `Attack` or `Defence` holding a list of `{ type = <localised terrain name, else the raw type>, value = <value * 100 with two decimals>% }` sorted by upper-cased type. A table-valued key other than those three makes the detail call fail with a Lua error text.
- `triggers` is `Utils.Dump` of the list of every `gainable_trait = { ... }` block of `common\gainable_traits.txt` whose `trait` names this key, each block shown without its `trait` line; empty text when there is none. (source)

`BiceLibGui.Traits.EffectsForKey(key)` (used by the Generals page) returns `{ available, effects }` with the same effect dump but without the `allowed_leader` entry, or unavailable with `Unknown trait: <key>`. (source)

**Inputs a mod gives it** - files `common\traits.txt`, `common\gainable_traits.txt`, the localisation folder (keys `<trait key>`, `TRAIT_<EFFECT>`, terrain names), `unitConversion.csv`. All parsed off disk by the mod's Lua on first use and cached for the life of that Lua state; no game API is used.

**When it applies** - needs a game on screen for the bridge; no country is needed. Data is static.

**Multiplayer and saves** - read-only; nothing is stored in a save. Each machine shows its own files.

**Where the player sees it** - overlay window "Game Info", tab "Traits".

### Page "Generals" (Game Info, order 60)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original shows only leaders already in service, in the leader assignment window, without maximum skill, availability date or the unit they stand in.

**What the feature does** - Lists every leader the mod defines for the reported country, whether or not he is in service, with his definition, where the running game has him, and his traits.

Top row: button `Reload`; the reported tag in dim text (`no country` when empty); a wheel combo 160 pixels wide with the items `All`, `Land`, `Sea`, `Air` (default `All`). The list is fetched whenever the reported tag differs from the tag last loaded, and on `Reload`; fetching clears the selection. When no list is loaded the page shows `No generals loaded.` or the failure text and nothing else. Otherwise a dim line `<visible> of <total> generals` (visible = after the branch combo, before the text filter).

Left pane (initial width 420): the filtered list of leader labels restricted to the chosen branch (`land`, `sea` or `air`, compared with the definition's `type`). A label is `<skill> (<max_skill>)  <type>  '<name>'  <earliest history date> [<id>]`, for example `3 (6)  land  'Erwin Rommel'  1936.1.1 [1234]` (two spaces between the parts; the date reads `nil` for a leader with no history block). Splitter. Right pane: `Select a general.` when nothing is selected, the failure text, or:

- separator titled `In game`, then `Location: <province name> (<province id>)` and `Unit:     <unit name>`;
- separator titled `Definition`, then a read-only text box, 40 percent of the remaining height, holding `Utils.Dump` of the leader record with the keys `available_date`, `country`, `id`, `max_skill`, `name`, `rank`, `starting_skill`, `traits` (a nested list of choice strings), `type`;
- separator titled `Traits`, then `No traits.` or: a filtered list of the leader's traits as choice strings (initial width 240, its own filter), a splitter (minimum 120 left, 150 right), and a read-only text box that reads `Select a trait.` until a trait is chosen and then shows that trait's effect dump from `BiceLibGui.Traits.EffectsForKey` (the key is the text between the last `[` and the last `]` of the chosen string), or the failure text.

Details are fetched once when a leader is selected; trait effects once when a trait is selected. No timed refresh, so the location is as of the moment of selection. (source)

List (`BiceLibGui.Generals.Collect(tag)` returns `{ available, tag, generals = { { id, branch, label } } }`): every leader whose `country` equals the tag and who has a `skill`, ordered by `skill` descending and then by name ascending. Both comparisons are on the text read from the file, so a skill of `10` sorts below `9`. (source)

Leader records (`BiceData.Generals`): every file of `history\leaders` is parsed; each top-level key is a leader id whose block gives `name`, `skill` (shown as starting skill), `max_skill`, `add_trait` (one or several, turned into choice strings), `type`, `country`, and `history = { <date> = { rank = <n> } ... }`. `available_date` and `rank` are taken from the earliest history date, found by comparing year, month, day part by part as text. (source)

Details (`BiceLibGui.Generals.Details(id)` returns `{ available, id, dump, traits, location, location_id, unit_name }`, or unavailable with `Unknown leader: <id>`): `location`, `location_id` and `unit_name` start as `unknown`. When the DLL is loaded the mod calls `BiceLib.Leaders.getLeaderDetails(tonumber(id))`; if that answers a table, `location_id` becomes its `province_id` as text and `location` the localisation of `PROV<province_id>` (else `unknown`) when `province_id` is present, and `unit_name` its `unit_name` (else `unknown`). A leader without a unit therefore shows `Location: unknown (unknown)` and `Unit:     unknown`. (source)

**Inputs a mod gives it** - files of `history\leaders` parsed off disk on first use and cached for the life of the Lua state; localisation keys `PROV<id>` and trait keys; the DLL's `getLeaderDetails` for the live part (direct read of game state).

**When it applies** - needs a game on screen and a reported country.

**Multiplayer and saves** - read-only. Nothing is stored in a save.

**Where the player sees it** - overlay window "Game Info", tab "Generals".

### Page "Modifiers" (Game Info, order 70)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original shows an event or triggered modifier only while a country has it, and never its conditions.

**What the feature does** - Top row: `Reload` (refetches the list and the selected modifier's details), then a dim status: `Loading...` or the failure text before a list exists (one automatic load attempt on the first frame the page is drawn in the process, afterwards only `Reload`), `<N> modifiers` once loaded.

Left pane (initial width 300): filtered list of choice strings. Splitter. Right pane: `Select a modifier.`, the failure text, or: the bare key followed on the same line by `(Event)` or `(Triggered)` in dim text; a separator; label `Effects` over a read-only text box of half the remaining height (less one text line); label `Conditions` over a read-only text box filling the rest, reading `(none)` when empty. Details are fetched when the selection changes. No timed refresh. (source)

List (`BiceLibGui.Modifiers.Collect()` returns `{ available, modifiers = { choice strings } }`): every top-level key of `common\event_modifiers.txt` (kind `Event`) and then of `common\triggered_modifiers.txt` (kind `Triggered`), sorted by upper-cased choice string. A key defined in both files appears twice in the list and has the second file's definition and kind. (source)

Details (`BiceLibGui.Modifiers.Details(choice)` returns `{ available, key, kind, effects, triggers }`, or unavailable with `Unknown modifier: <choice>`):

- `effects`: the definition without `potential`, `trigger` and `icon`; each remaining key is renamed to the first localisation found among `MODIFIER_<KEY UPPER>`, `<key lower>_eff`, `<KEY UPPER>`, and for three keys a fixed alternative (`global_manpower_modifier` to `GLOBAL_MANPOWER`, `local_manpower_modifier` to `LOCAL_MANPOWER`, `casualty_trickleback` to `CASUALTY_TRICKLEBACK_TECH`), else left as the raw key; its value is `ConvertEffect(key, value)`, taking the last value when the key is written more than once. The text is a dump with all entries in upper-cased alphabetical order of the translated names.
- `triggers`: a dump of only the `potential` and `trigger` blocks, in that order, with raw keys. (source)

**Inputs a mod gives it** - `common\event_modifiers.txt`, `common\triggered_modifiers.txt`, localisation, `unitConversion.csv`; all parsed off disk on first use and cached; no game API.

**When it applies** - needs a game on screen for the bridge; no country needed.

**Multiplayer and saves** - read-only; nothing saved.

**Where the player sees it** - overlay window "Game Info", tab "Modifiers".

### Page "Techs" (Game Info, order 80)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original's technology screen shows the next level's effects only, and no requirement script.

**What the feature does** - Top row: `Reload` (refetches the list, and the selected technology at the level currently shown), then dim status `Loading...` / failure text / `<N> technologies`, with the same single automatic load attempt as the Modifiers page.

Left pane (initial width 300): filtered list of choice strings. Splitter. Right pane: `Select a technology.`, the failure text, or:

- the bare technology key;
- a level row: `Level <shown level>`, a small button `-` (acts only while the shown level is above 1: refetches at one level lower), a small button `+` (refetches at one level higher, with no upper limit), then either `| researched: <n>` (dim) with a small button `Reset` (acts when the shown level differs from the researched level: refetches at the researched level), or `| not researched` (dim) when the reported country has level 0;
- a separator; label `Effects at this level` over a read-only text box of 55 percent of the remaining height (less one text line); label `Requirements` over a read-only text box filling the rest, `(none)` when empty.

Selecting a technology fetches details with level 0, which asks the mod to choose: the reported country's researched level, or 1 when that is 0. No timed refresh. (source)

List (`BiceLibGui.Techs.Collect()` returns `{ available, techs = { choice strings } }`): every block of every file of the `technologies` folder, kept in file order internally (a technology's position in that order is its index, used for unit model strings) and listed sorted by upper-cased choice string. Each definition's `folder` key is discarded. (source)

Details (`BiceLibGui.Techs.Details(choice, level)` returns `{ available, key, player_level, shown_level, effects, requirements }`, or unavailable with `Unknown tech: <choice>`):

- `player_level`: the reported country's level, read through the game's Lua API as `CCountryDataBase.GetTag(tag):GetCountry():GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(key))`; 0 when there is no reported country, when the key is not a technology the game knows, or when the call fails.
- `effects`: the definition without the requirement keys `start_year`, `first_offset`, `additional_offset`, `difficulty`, `max_level`, `change`, `research_bonus_from`, `allow`; every numeric value at any depth is multiplied by the shown level and written with two decimals; then every key at every depth is renamed to the first localisation found among `<key>`, `MODIFIER_<KEY UPPER>`, `<KEY UPPER>_TECH`, `<key lower>_eff`, `<KEY UPPER>`, a fixed table of special cases (`manpower_gain` to `GLOBAL_MANPOWER`, `ic_efficiency` to `MODIFIER_INDUSTRIAL_EFFICIENCY`, `casualty_trickleback` to `CASUALTY_TRICKLEBACK_TECH`, `refinery_efficiency` to `MODIFIER_FUEL_CONVERSION`, `energy_to_oil_conversion` to `ENERGY_TO_OIL_TECH`, `energy_production` to `ENERGY_PROD_TECH`, `metal_production` to `METAL_PROD_TECH`, `rares_production` to `RARES_PROD_TECH`, `research_efficiency` to `RESEARC_EFF_TECH`, `unit_cooperation` to `UNIT_COOP_TECH`, `provincial_aa_efficiency` to `PROV_AA_TECH`, `default_organisation` to `DEFAULT_ORG`, `build_cost_manpower` to `BUILD_COST_MP`), then the literal `Delay between attacks` for `attack_delay`, else the raw key. Values: for the keys `movement`, `attack`, `defence` the value times 100 with two decimals and `%`; for `attrition` the value with two decimals and `%`; for the keys `stealable`, `can_upgrade`, `on_completion`, `activate_building`, `activate_unit`, `is_nuclear`, `change`, `max_level`, `difficulty`, `start_year`, `first_offset`, `additional_offset`, `listening_station`, `has_country_flag` the value as it stands; for everything else `ConvertEffect(<key>_tech, value)`. Nested blocks (a unit type's block inside the technology) are translated the same way. The text is a dump with plain entries first and blocks after, each alphabetical; an entry of the as-it-stands group whose name found no localisation is moved to the top.
- `requirements`: a dump of only the requirement keys named above, in that order, raw. (source)

**Inputs a mod gives it** - the `technologies` folder, localisation, `unitConversion.csv`, parsed off disk on first use and cached; the game's Lua API for the researched level.

**When it applies** - needs a game on screen; the researched level needs a reported country, the rest does not.

**Multiplayer and saves** - read-only; nothing saved.

**Where the player sees it** - overlay window "Game Info", tab "Techs".

### Page "Units" (Game Info, order 90)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original shows a unit type's figures only for the model the country can build now.

**What the feature does** - A viewer of every unit type's statistics with the technologies that upgrade it applied, and a what-if calculator: each technology's assumed level can be raised or lowered to see the resulting statistics and the unit's model string. The assumed levels are numbers held in the mod's Lua memory only; nothing in the game changes.

Top row: `Reload` (refetches the list and reselects the selected unit), then dim status `Loading...` / failure text / `<N> units`, with one automatic load attempt on the first frame the page is drawn in the process.

Left pane (initial width 280): filtered list of unit choice strings. Splitter. Right pane: `Select a unit.`, the failure text, or:

- the bare unit key;
- label `Model`, a read-only single-line text box holding the model string, and a button `Copy` (tooltip `Copy the model string to the clipboard`) that puts the model string on the clipboard;
- a separator; label `Stats with current tech levels` over a read-only text box of 45 percent of the remaining height;
- a separator titled `Technologies`, then `No technologies upgrade this unit.` (dim) or: small buttons `-`, `+`, `Reset all`, and a status: `select a tech to adjust` (dim) when no technology is selected; `<tech key>: level <assumed> (researched <actual>)` in the warning colour when the assumed level differs from the researched one; `<tech key>: level <n> (researched)` (dim) when they are equal. Below, a filtered list of the unit's technologies (initial width 300, own filter) with labels `<assumed level> - <choice string>`, a splitter (minimum 150 left, 150 right), and a pane showing `Select a technology.` or the selected technology's effect text in a read-only box, preceded by the two-line warning `Not researched. Showing level 1 for reference;` / `it is not included in the stats above.` in the warning colour when the assumed level is 0.

`-` and `+` change the selected technology's assumed level by one (never below 0, no upper limit) and refetch statistics, model string and technology list together; `Reset all` sets every assumed level of every unit back to the reported country's researched levels. After either, the previously selected technology is found again in the new list as the first label that contains its key as a substring. No timed refresh. (source)

Mod contract:

- `BiceLibGui.Units.Collect()` returns `{ available, units = { choice strings } }`: every top-level key of every file directly in the `units` folder (subfolders are not read), sorted by upper-cased choice string.
- `BiceLibGui.Units.Select(choice)`, `ChangeTechLevel(techChoice, delta)` and `ResetTechLevels()` all return `{ available, key, model, stats, techs = { { key, label, level } } }`. The mod remembers the selected unit between calls; with none selected the answer is unavailable with `No unit selected`, and an unknown choice gives `Unknown unit: <choice>`.
- `BiceLibGui.Units.TechDetails(techChoice)` returns `{ available, key, level, researched, applied, effects }`: `level` the assumed level, `researched` the reported country's level, `applied` false when the assumed level is 0, `effects` the technology's block for this unit rendered as on the Techs page at the assumed level, or at level 1 when the assumed level is 0. (source)

How the mod builds the data (`BiceData.Units`): a technology upgrades a unit when its definition has a key equal to the unit's key; that nested block is the technology's effect on the unit. For every unit and every such technology the mod stores the block, an assumed level, and the technology's file-order index. The assumed levels are set from the reported country's researched levels at the moment the unit files are first parsed, and again only by `Reset all`; they are not re-read when the reported country changes or a save is loaded. (source)

- `stats`: start from the unit's definition; for each upgrading technology multiply every number of its block by the assumed level (two decimals) and add it to the unit's value of the same key (a key the unit lacks takes the technology's value; nested terrain blocks are added terrain by terrain; the technology key `activate` is ignored); then rename keys and format values exactly as the Techs page does (so most values go through `ConvertEffect(<key>_tech, value)`); dump with plain entries first and blocks after, each alphabetical. The keys `active`, `priority`, `sprite`, `available_trigger`, `usable_by` are removed from the text when they found no localisation.
- `model`: the assumed levels of all upgrading technologies in technology file order, joined by single spaces. A comment in the source says this is the form pasted into event files to spawn a unit at those technology levels. (source, comment)
- technology list order: by upper-cased localised technology name, technologies without localisation last (by key).

**Inputs a mod gives it** - files of `units` and `technologies`, localisation, `unitConversion.csv`, parsed off disk and cached; the game's Lua API for researched levels (as on the Techs page).

**When it applies** - needs a game on screen; researched levels need a reported country.

**Multiplayer and saves** - changes nothing in the game. The assumed levels live in the local Lua state and are lost when the game exits.

**Where the player sees it** - overlay window "Game Info", tab "Units".

### Page "Unit Models" (Game Info, order 100)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new.

**What the feature does** - Lists the reported country's unit models, shows for a selected model which technology levels it requires against what the country has, and draws the sprite file the game would use for it.

Top row: `Reload`; the reported tag (dim, `no country` when empty); when a list is loaded, `| <N> models` (dim). The list is fetched when the reported tag changes and on `Reload`; fetching clears the selection. Without a list: `No models loaded.` or the failure text (`No country selected`, `No unit models for <TAG>`).

Left pane (initial width 280): filtered list of model strings `[<unit type>.<level, two digits>] <name>` where the name is the localisation of `<TAG>_<unit type>_<level>` or else of `<unit type>` (omitted when neither exists), sorted by upper-cased text. Splitter. Right pane: `Select a model.`, the failure text, or:

- the model ident (`<unit type>.<NN>`);
- separator titled `Required technologies`, then `No technology requirements.` (dim) or a three-column table with a frozen header, alternating row backgrounds, inner borders and vertical scrolling, 45 percent of the remaining height: `Technology` (stretching; text `<required> (<researched>) - <choice string>`), `Needs` (required level as an integer), `Has` (the country's researched level as an integer, drawn in the error colour when it is below the required level). Rows are ordered by upper-cased localised technology name, unlocalised ones last.
- separator titled `Sprite`: when there is no image, the status text (`No image`) in dim; when the file cannot be decoded, `Could not load <path>`; otherwise small buttons `-`, `+`, `Fit`, `1:1`, a dim line `fit (<percent>%)  |  <width>x<height>  |  <status>` (or `<percent>%  |  ...` when not fitting), and the image in a bordered pane with a horizontal scrollbar. Zoom steps are 0.5, 1, 2, 3, 4, 6, 8; `-` and `+` leave fit mode and move one step (clamped); `1:1` sets step 1; `Fit` (the default) scales the image down to the pane width when it is wider and never enlarges it. Zoom state is shared by all models. (source)

Mod contract: `BiceLibGui.UnitModels.Collect()` returns `{ available, tag, models = { strings } }` for the mod's current reported tag; `BiceLibGui.UnitModels.Details(choice)` returns `{ available, key, techs = { { key, required, researched, label } }, image_path, image_status }`. (source)

How the mod builds the data (`BiceData.UnitModels`): every file of `units\models` is parsed; the first three characters of the file name are the country tag; each top-level key `<unit type>.<level>` holds `<technology> = <required level>` pairs. `researched` comes from the game's Lua API as on the Techs page. The sprite: with base folder `gfx\models\`, a candidate is `<prefix><unit type>_<i>.tga`; for a prefix the mod takes the highest `i` from 0 to the model's level whose file exists, and calls it exact when `i` equals the level. It tries the prefix `<tag in lower case>_`, then `<TAG>_`; when a country file exists for the exact level the result is that path with status `Country specific (exact level)`; otherwise it tries no prefix and returns that path with `Generic (exact level)` or `Generic (fallback level)`; otherwise no path and `No image`. A country file for a lower level is never used. The path is relative to the game directory. The overlay decodes the file itself: uncompressed or run-length-encoded true-colour TGA, 24 or 32 bits per pixel; anything else counts as not loadable. Decoded images are cached by path. (source)

**Inputs a mod gives it** - `units\models\*.txt`, `gfx\models\*.tga`, localisation; the game's Lua API for researched levels.

**When it applies** - needs a game on screen and a reported country.

**Multiplayer and saves** - read-only; nothing saved.

**Where the player sees it** - overlay window "Game Info", tab "Unit Models".

### Page "Active Flags" (Inspector, order 20)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original never shows a country's flags.

**What the feature does** - A filterable table of the reported country's flags. It is one of three pages (with "Active Variables" and "Active Event Modifiers") that share one layout and differ only in their rows. They use no Lua except the shared poll of the reported tag; the rows are read straight from the game's country object by the DLL, with the same readers as the `BiceLib.GameInfo` functions described further down.

Top row: button `Refresh` (re-reads the reported tag at once and reloads the rows); checkbox `Auto` (on by default; while on, the rows are reloaded when 2000 ms have passed since the last load, checked each frame the page is drawn); then either the reason the page has no data, in dim text, and nothing else on the page, or the reported tag in dim text. Reasons: the selection's reason when no tag is known; `No cached country for <TAG> (run cacheCountries)` when the game's country list has no country with that tag.

Second row: a text input with hint `Filter` and a dim counter `<shown>/<total>`. Then a table with a frozen header, alternating row backgrounds, inner borders and vertical scrolling. Rows are sorted by name, case-insensitively ascending; the filter keeps rows whose name contains the filter text as a case-insensitive substring (a second column is not searched). Each of the three pages keeps its own filter, `Auto` state and timer.

This page's table has the single column `Name`: one row per flag held in the country's flag store. (source)

**Inputs a mod gives it** - none beyond the reported tag.

**When it applies** - needs a reported country, which needs a game on screen.

**Multiplayer and saves** - a read-only view of state the savegame already holds.

**Where the player sees it** - overlay window "Inspector", tab "Active Flags".

### Page "Active Variables" (Inspector, order 30)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original never shows a country's variables.

**What the feature does** - The layout, refresh, sorting and filter of the "Active Flags" page, with two columns: `Name` (65 percent of the width) and `Value` (35 percent). One row per country variable whose value is not zero; the value is the stored thousandths divided by 1000 and printed with no decimals (so 12.05 shows as `12`). (source)

**Inputs a mod gives it** - none beyond the reported tag.

**When it applies** - needs a reported country, which needs a game on screen.

**Multiplayer and saves** - a read-only view of state the savegame already holds.

**Where the player sees it** - overlay window "Inspector", tab "Active Variables".

### Page "Active Event Modifiers" (Inspector, order 40)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. The original shows a country's event modifiers only as icons with tooltips on the diplomacy screen, without their keys.

**What the feature does** - The layout, refresh, sorting and filter of the "Active Flags" page, with two columns: `Name` (65 percent) and `Expires` (35 percent). One row per entry of the country's list of timed modifiers (what `add_country_modifier` fills): the modifier's key, and its expiry as `<year>.<month>.<day> <hour>:00` without zero padding, on the game's calendar of 365-day years. The same modifier present twice gives two rows. The original stores a modifier that never ends with a date in year 1 or earlier (reversing/findings/FINDINGS-countrymodifier.md), so such a row shows a date like `1.1.1 0:00`. (source)

**Inputs a mod gives it** - none beyond the reported tag.

**When it applies** - needs a reported country, which needs a game on screen.

**Multiplayer and saves** - a read-only view of state the savegame already holds.

**Where the player sees it** - overlay window "Inspector", tab "Active Event Modifiers".

### Page "Setup" (Stats, order 10)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new.

**What the feature does** - Switches the mod's statistics collection on and off and edits the list of countries it covers. The page itself collects nothing; it reads and posts country variables of the country `OMG` (see the next section for the collector).

Both Stats pages share one poll: at most every 2000 ms a drawn Stats page calls `BiceLibGui.Stats.Collect()`. If the call is refused the page shows `Lua unavailable: <reason>`; if the answer is unavailable it shows the reason (`No game session` when the tag `OMG` names no country). The answer is `{ available, collecting (bool), customListActive (bool), ident (number, 0 = none yet), path = "tfh/mod/BlackICE <G_MOD_VERSION>/stats", version = <G_MOD_VERSION>, countries = { every tag }, custom = { listed tags } }`, where `countries` is every country of `CCurrentGameState.GetCountries()` except the tag `---`, sorted, and `custom` those of them whose variable `zStatsCustomList_<TAG>` on OMG equals 1.

Layout:

- checkbox `Collect statistics`; at horizontal position 260 on the same line `Run <ident>` (tooltip `Each run writes to its own folder, so a new game does not overwrite the last one. Assigned on the first collection.`) or, while ident is 0, dim `no run number yet` (tooltip `Assigned when collection first writes something.`);
- checkbox `Only the countries listed below`;
- wrapped text: `Meant for development: collection writes a file per statistic per country every day, which the game feels. Restricting it to a few countries keeps that in hand. Expect command prompts to flash past while the folders are created.`;
- separator titled `Countries collected`; while the second checkbox is off, dim text `Every human player is collected while the switch above is off. The list is still editable.`;
- a pane 200 by 220 pixels headed `All countries` with a filtered list of every tag (selection only);
- beside it, 60 pixels down, buttons `Add >>` (disabled when nothing is selected or the selected tag is already listed) and `<< Remove` (disabled when nothing is selected or the tag is not listed);
- a pane 200 by 220 headed `Collected (<n>)` listing the listed tags alphabetically as selectable rows (clicking one makes it the selected tag for the two buttons).

Because a posted change takes effect a moment later, every control shows the requested state until the game reports it: a checkbox shows the requested value with `waiting...` in the warning colour beside it until a poll returns that value; a tag asked to be added appears in the right pane at once, and a tag asked to be added or removed is drawn in the warning colour with the tooltip `Waiting for the game to apply this` until a poll shows the list in the requested state. The two buttons act on the requested state, so a second click cannot undo an unanswered request. (source)

What each control does:

- `Collect statistics` calls `BiceLibGui.Stats.SetCollecting(1 or 0)`, which posts `CSetVariableCommand(OMG, "StatisticsToggle", 1 or 0)` through `CCurrentGameState.Post`.
- `Only the countries listed below` calls `BiceLibGui.Stats.SetCustomListActive(1 or 0)`, which posts `StatisticsCustomList` = 1 or 0 on OMG the same way.
- `Add >>` / `<< Remove` call `BiceLibGui.Stats.SetCountryCollected(tag, 1 or 0)`, which posts `zStatsCustomList_<TAG>` = 1 or 0 on OMG, then posts `StatisticsCustomListVersion` = its current value plus one (so other Lua states drop their cached list), and updates the local Lua state's cached list (`Stats.CustomCountryList[tag]`) at once. An empty tag does nothing.

Each of these calls returns a fresh snapshot in the same shape as `Collect`. (source)

**Inputs a mod gives it** - a country with the tag `OMG`; the variables `StatisticsToggle`, `StatisticsCustomList`, `StatisticsCustomListVersion`, `StatisticsIdent`, `zStatsCustomList_<TAG>` on it; `BiceData.Stats` and `BiceData.Country` (variables are read with `country:GetVariables():GetVariable(CString(name)):Get()`, a never-set variable reading 0).

**When it applies** - needs a game on screen. Can be switched on and off at any time.

**Multiplayer and saves** - Every change is a game command (`CSetVariableCommand`) posted through the game's own command queue, so it is applied on every machine and the variables are part of the savegame: the switches, the list and the run number survive a save and load. `CCurrentGameState.Post` is asynchronous (readme), which is why the page shows pending states.

**Where the player sees it** - overlay window "Stats", tab "Setup".

### Statistics collection behind the Stats pages (mod Lua, not in the DLL)

Kind: tooling
Switch: the OMG country variable `StatisticsToggle` = 1, set from the Stats "Setup" page (or the old wxWidgets utility); the collector itself is always loaded with the mod's Lua, whether or not the overlay is enabled

**What the original does without it** - nothing: this is new. The original records statistics only for its own end-of-game and ledger screens.

**What the feature does** - While switched on, the mod's Lua appends one line per statistic per covered country per game day to plain text files. It lives in `script/utility/stats/stats.lua` and is driven by the game's daily AI minister callbacks; the DLL takes no part in collecting. (source)

*Who is covered.* (a) Every human-played country (the list `G_PlayerCountries`, which the mod fills by asking `CCurrentGameState.IsPlayer` for every tag the first time OMG's handlers run in a Lua state, and again whenever the overlay's Country page asks for the players), once a day from the hidden country OMG's politics-minister tick (the schedule comment says about 17:00): `Stats.CollectPlayerStatistics` first re-reads `StatisticsToggle`, `StatisticsCustomList` and `StatisticsCustomListVersion` from OMG, and when collection is on writes all four groups below for each player tag that passes the list check. (b) Every country whose AI minister callbacks run, from those callbacks in that country's own Lua state: the tech minister tick (when called with its sliders flag) writes the leadership group, the production minister writes the slider group when it balances sliders and the general group every tick, and the intelligence minister writes the politics group on the days its random gate (`GetAIRand() mod 9 == 0`) lets its body run. Each of those checks the Lua state's own copy of the toggle and the list check; that copy is refreshed from OMG's variables at every intelligence-minister tick in Lua states other than the one OMG's handlers run in, and by the daily player pass in that one. The list check passes every tag while `StatisticsCustomList` is not 1, and otherwise only tags whose `zStatsCustomList_<TAG>` is 1 (the per-state cache of that list is rebuilt when the version variable changes). So with the custom list off, AI countries are written too, not only human players. (source)

*What is written.* File name = statistic name; values formatted with no decimals unless said:

- leadership group: `ls_TotalLeadership`, `ls_Percent_Research`, `ls_Percent_Espionage`, `ls_Percent_Diplomacy`, `ls_Percent_NCO` (the four leadership shares times 100), `intel_FreeSpies`, `intel_DomesticSpies` (level of the country's spy presence in itself), `intel_TotalSpiesAbroad` (sum of its spy presence levels in other existing countries), `diplo_Neutrality`, `diplo_EffectiveNeutrality` (both written from `GetNeutrality`, so the two are always equal);
- slider group: `prod__IcEff` (the global industrial efficiency modifier plus, for each technology with an `ic_efficiency` value, that value times the country's level, rounded to three decimals, times 100), `prod__TotalIc`, and for each of `LendLease`, `Consumer`, `Production`, `Supply`, `Reinforce`, `Upgrade` the pair `prod_<Name>_%` (share times 100) and `prod_<Name>_IC` (share times total IC);
- politics group: `pol_Popularity_Single_<ideology key>` for every ideology (two decimals), `pol_Popularity_Group_<ideology group key>` (sum over the group, two decimals), `other_ProvincesControlled`, `other_ProvincesOwned`;
- general group: `other_u_LandCountTotal`, `other_u_AirCountTotal`, `other_u_NavalCountTotal`, `other_u_TotalDivisions`, `other_ManpowerTotal`, and for each of `energy`, `metal`, `rares`, `oil`, `supplies`, `fuel`, `money`: `res_pool_<good>` (stockpile), `res_balance_<good>` (daily balance), `res_tradeFor_<good>` and `res_tradeAway_<good>` (traded for and away, allied supply excluded). For players the three unit counts are regiments, planes and ships from the country's unit collection; for AI countries they are the production minister's own counts, which include units in the build queue. (source)

*Where it is stored.* Under `tfh/mod/BlackICE <G_MOD_VERSION>/stats/` in the game directory:

- `identcounter`: one line, the next run number to hand out; created holding `1`.
- `<run>/zzSetup` and `<run>/<TAG>/zzSetup`: marker files holding `Setup complete`; the folders are created with the shell's `mkdir` (the command prompt windows the page warns about).
- `<run>/<TAG>/<statistic name>`: created holding the header `Date,<statistic name>`; each collection appends a line break and `<day>,<value>`, where `<day>` is the game date's total day count minus 706640 (365 times 1936, so day 0 is 1 January 1936 on the game's 365-day calendar). Files are only ever appended to.

The run number is the OMG variable `StatisticsIdent`. When a Lua state first needs it and the variable reads 0, it takes the number in `identcounter`, posts `StatisticsIdent` = that number as a game command, and writes the number plus one back to `identcounter`. Each Lua state then remembers the run number, and which folders it has made, for the rest of the process. (source)

*What survives a save and load.* In the savegame: the switches, the custom list, its version counter and the run number (all OMG country variables). On disk outside the savegame: every collected value. In memory only: each Lua state's copy of the switches (re-read daily), its cached list, its remembered run number and folder markers. Consequences: reloading an earlier save of the same game keeps appending to the same files, so day numbers jump backwards (the Statistics page drops the superseded readings when it loads a file); and because a Lua state never forgets its run number, loading a save of a different game without restarting the program keeps writing into the folder of the game collected first, while the pages read the folder named by the loaded save's `StatisticsIdent`. (source)

**Inputs a mod gives it** - the OMG variables above; the game's Lua API (`GetTotalLeadership`, `GetLeadershipDistributionAt`, `GetProductionDistributionAt`, `GetTotalIC`, `GetPool`, `GetDailyBalance`, `GetTradedForSansAlliedSupply`, `GetTradedAwaySansAlliedSupply`, `GetUnits`, `GetManpower`, `AccessIdeologyPopularity`, `GetNumberOfControlledProvinces`, `GetNumberOfOwnedProvinces`, `GetSpyPresence`, `GetNeutrality`); `BiceData.Techs.ModifierValues()` for the technology `ic_efficiency` values (parsed from the `technologies` folder).

**When it applies** - only in a running game, on days the callbacks fire.

**Multiplayer and saves** - The files are written on the machine whose Lua runs the callbacks; which machines those are in multiplayer was not established here. The posted run number is a synchronised game command.

**Where the player sees it** - only through the Stats pages or the external plotting tool.

### Page "Statistics" (Stats, order 20)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new.

**What the feature does** - Reads the files the collector wrote for the current run and plots chosen series in the overlay, or hands the choice to an external plotting program.

The page uses the shared Stats poll for the run number, the stats path and the mod version. The run folder is `<game directory><path>\<ident>\`. On its first draw, and on the button `Rescan`, it scans that folder: the countries are its subfolders, the statistics the union of the file names inside them (the name `zzSetup` is skipped in both), each sorted case-insensitively. A dim note beside `Rescan` reads `Nothing collected yet.` (ident 0), `No data in <folder>`, or `<n> countries, <m> statistics`; it is also where the external tool's outcome is reported. With no countries found the page shows only the wrapped text `Statistics appear here once collection has been switched on for a while. Each day writes one line per statistic.`

Otherwise:

- a bordered pane 190 by 200 headed `Countries` with one checkbox per country;
- a bordered pane 320 by 200 headed `Statistics` with a full-width text input (hint `Filter`, a case-sensitive substring match on the statistic name) and one checkbox per statistic;
- a column: `<n> countries`, `<n> statistics` (the numbers ticked), then buttons `Plot here` and `Open in the tool` (both disabled until at least one country and one statistic are ticked; the second has the tooltip `Runs visualizeStatisticCLI.exe, which draws proper axes and takes a few seconds`) and `Clear` (unticks everything and removes the plots). Ticking or unticking anything removes the current plots.

`Plot here` loads, for every ticked country and statistic in alphabetical order (country first), the file `<run folder><country>\<statistic>`: the first line is skipped; every later line with a comma gives a day (integer before the comma) and a value (number after it). Because files are only appended to, whenever a line's day is not greater than the last kept day, all kept points with a day greater than or equal to it are dropped (counted as discarded) before the new point is added, so the kept days are strictly increasing and a reload from an earlier save, or two lines for the same day, leave only the later readings. A file with no usable point gives no series.

Plots appear under a separator titled `Plot` with a checkbox `One plot` (tooltip `Draws every series into the same axes instead of one plot each`, off by default):

- off: for each series a heading `--` in the series colour, `<country> - <statistic>`, dim `<n> points`, and when points were discarded dim `(<n> dropped)` with the tooltip `The file carries on past a crash or a reload from an earlier save. Readings from the timeline that was abandoned are dropped rather than plotted alongside the one that replaced it.`; then a plot 90 pixels high.
- on: one plot 260 pixels high holding every series, followed by a legend line per series: `--` in its colour, `<country> - <statistic>`, dim `(<min> to <max>)` with two decimals.

A plot is a frame as wide as the page, filled with the frame background colour and outlined with the border colour. The horizontal axis is the day, from the earliest first day to the latest last day of the series drawn; the vertical axis runs from the lowest to the highest value among them (a span of 1 is used when all values are equal), with 2 pixels of margin top and bottom. Each series is a polyline 1.5 pixels thick through its points; series colours cycle by series index through, as R,G,B: 120,190,255; 255,170,90; 130,220,140; 240,130,200; 230,220,120; 180,150,255; 120,230,220; 255,130,130. When the last day is not after the first day the frame is replaced by dim `Not enough data to plot.` Under each frame a dim caption `<lowest> to <highest>, <first date> to <last date>` (two decimals). No axes or grid lines are drawn. Hovering a frame draws a vertical line at the mouse and a tooltip: the date of the hovered day (the day nearest the mouse position), a separator, and per series `--` in its colour, `<country> <statistic>`, the value of the series point nearest that day (two decimals; of two equally near points the later one) and, when that point's day is not the hovered day, its own date in dim brackets; a filled dot of radius 3 marks each such point. Dates are written `<day of month> <Mon> <year>` with English three-letter month names, computed from the day number on a calendar of 365-day years with no leap day where day 0 is 1 January 1936 (days before that count backwards into 1935). (source)

`Open in the tool` starts `<game directory><path>\visualizeStatisticCLI.exe` with the arguments `<mod version> <ident> <ticked countries, comma separated> <ticked statistics, comma separated>` and the game directory as working directory. The note becomes `Not found: <path>` when the program is missing, `Could not start the tool (error <code>)` when starting fails, else `Started the plotting tool`. The program is the mod's own (its source is in the mod repository under `tools/visualizeStatistics`); the page expects a copy beside the data. (source)

**Inputs a mod gives it** - `BiceLibGui.Stats.Collect()` for `ident`, `path`, `version`; the collector's files; optionally `visualizeStatisticCLI.exe` in the stats folder.

**When it applies** - needs a game on screen (for the poll). The scan is not repeated automatically; `Rescan` is needed after the run number is first assigned or new countries appear, and `Plot here` again to pick up new days.

**Multiplayer and saves** - read-only; reads local files.

**Where the player sees it** - overlay window "Stats", tab "Statistics".

### Page "Misc" (Help, order 10)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new.

**What the feature does** - A page of the mod's own help text (its window name is `Misc##Help`, because the Setup group also has a "Misc" page). It fetches its content with `BiceLibGui.Help.Section("misc")`, trying again on every drawn frame until a call gets through (showing `Loading...` or the refusal text meanwhile), and then draws from memory for the rest of the process.

The answer is `{ available = true, entries = { entry } }`; an unknown section name gives an empty list. An entry has `kind` and `text`; a `card` entry also has `title`, `subtitle` and `lines` (array of strings). Drawing, entry by entry:

- `heading`: text longer than 60 characters is drawn as a wrapped paragraph after a little spacing; shorter text as a titled separator line;
- `item`: a bullet followed by the wrapped text;
- `card`: consecutive cards are gathered into one table with alternating row backgrounds and inner borders and the columns `Building` (weight 0.8; the card's title), `Focus` (weight 0.7; the subtitle, dim) and `Ministers` (weight 1.5; the lines, one under another); the table ends at the first entry that is not a card;
- any other kind (`text`): a wrapped paragraph followed by spacing. (source)

The text is data in the mod's `utility_data/bicedata_help.lua`. Section `misc` holds, in order: heading `Strategic Resources` and a paragraph (strategic resource trades last one year, one resource level is needed per 200 IC with no penalty below 100 IC, a trade costs 2000 money, halved between allies); heading `Airdroppable Units` and fourteen items (unit names); heading `Unit Training` and a paragraph; heading `Event Spawned Units` and two paragraphs (about the mod's `ICDays` penalty); and a closing heading sentence saying that units which events will remove have yellow names. (source)

**Inputs a mod gives it** - `BiceData.Help.Section(name)` returning the entry list; no files, no game API.

**When it applies** - needs a game on screen for the first fetch only.

**Multiplayer and saves** - static text; nothing saved.

**Where the player sees it** - overlay window "Help", tab "Misc".

### Page "Ministers + Buildings" (Help, order 20)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. That ministers grant buildings is a BlackICE mechanic.

**What the feature does** - The same page mechanism as Help "Misc", fetching `BiceLibGui.Help.Section("ministers")`. The section holds a heading sentence (longer than 60 characters, so drawn as a paragraph), an explanatory paragraph, and nineteen items, one per building (Smallarms Factory, Artillery Factory, Tank Factory, Automotive Factory, Light, Medium and Heavy Aircraft Factory, Radar Station, Capital, Medium, Small and Submarine Shipyard, Heavy Industry, Manufacturing Plant, Rail Terminous, Research Lab, Training Base, Hospital, Resource buildings). Each item's text is written as a line `---<building>---`, a line `--<focus>--`, and lines such as `2x Infantry Proponent`. The mod turns an item whose text starts with `---<title>---` into a `card` entry: `title` is the text between the triple hyphens, `subtitle` the text between the double hyphens of the line that starts with two hyphens, `lines` every other line. The nineteen cards therefore draw as one three-column table: building, the national focus that doubles its building speed, and the minister types that grant it with their multipliers. (source)

**Inputs a mod gives it** - `BiceData.Help.Section("ministers")`; the text is the mod's and is not checked against the minister or building files.

**When it applies** - needs a game on screen for the first fetch only.

**Multiplayer and saves** - static text; nothing saved.

**Where the player sees it** - overlay window "Help", tab "Ministers + Buildings".

### Page "National Focus" (Help, order 30)

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`)

**What the original does without it** - nothing: this is new. National focus is a BlackICE mechanic built from a country variable and triggered modifiers; the original has no screen for it.

**What the feature does** - A table of what each of the mod's seven national focuses grants at each of its three tiers (window name `National Focus##Help`, because the Country Info group has a page of the same title). Until loaded, the page shows a button `Load` and the dim text `Reads the mod's modifier files, which takes a moment.` (or the refusal text after a failed attempt); pressing `Load` calls `BiceLibGui.NatFocus.Effects()` once and the result is kept for the rest of the process.

Loaded, it shows the wrapped text `What each national focus gives once it has been active long enough. A tier includes everything from the tiers before it only where the mod repeats it, so read each column on its own.`, then a four-column table with full borders, alternating row backgrounds, vertical scrolling and the first row and first column frozen: `Focus` (weight 0.7) and `Level I (<label 1>)`, `Level II (<label 2>)`, `Level III (<label 3>)` (weight 1 each). One row per focus: its name, and in each tier column one line per effect reading `<effect name>  <value>` (two spaces), or a dim `-` when the tier has none. (source)

Mod contract: the answer is `{ available, rows = { { key, name, tier (1 to 3), label, value } }, tierLabels = { "90 days", "360 days", "720 days" } }`, rows grouped by focus in the order ground_forces `Ground Forces`, air_force `Air Force`, navy `Navy`, economy `Economy`, science `Science`, health_and_education `Health + Education`, natural_resources `Natural Resources`. For focus key F and tier word W (`one`, `two`, `three`) the mod merges every modifier of `common\event_modifiers.txt` and `common\triggered_modifiers.txt` whose name is exactly `Nat_focus_<F>_<W>` or starts with that followed by `_`, leaving out the keys `potential`, `trigger` and `icon` and taking the last value of a repeated key; each remaining key becomes a row with `label` the translated effect name (as on the Modifiers page) and `value` = `ConvertEffect(key, value)`; rows of a tier are sorted by label. Rows with a tier outside 1 to 3 are ignored by the page. (source)

**Inputs a mod gives it** - modifiers named `Nat_focus_<focus>_<one|two|three>[_suffix]`, the tier day counts 90, 360 and 720 (constants of the mod's Lua), localisation, `unitConversion.csv`.

**When it applies** - needs a game on screen when `Load` is pressed.

**Multiplayer and saves** - static; nothing saved.

**Where the player sees it** - overlay window "Help", tab "National Focus".

### The Lua game-info reads: what they share

All of the following are plain Lua C functions on the `BiceLib` module table, available in every Lua state that has loaded the DLL. They read the running game's objects directly (every read is guarded, so data that is not there yields nil, zero or an empty string rather than a fault) and, except `addTraitToLeader`, change nothing. None of them checks that a game is on screen: at the main menu they answer from whatever the process holds at that moment (what that is was not established here), except `getSelectedEntity`, which answers nil. Strings they return are converted from the game's Windows-1252 to UTF-8. An argument of the wrong type raises a normal Lua argument error. (source)

A tag argument is matched against each country in the game's own country list by its first three characters, exactly and case-sensitively; a string shorter than three characters, or one that matches no country, counts as unknown. There is no cache: the list is walked on every call. (source)

### `BiceLib.GameInfo.getCountryFlags(tag)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API can test one flag by name (`GetFlags():IsFlagSet(name)`) but cannot list flags.

**What the feature does** - Returns an array (indices from 1) of strings: the name of every flag held in the country's flag store, in the store's own order, which is alphabetical by the lower-cased name (the order a savegame writes them in). Flag names are case-insensitive in the original (comment). Unknown tag: nil. A country with no flags: an empty table. The reader lists every flag entry the store holds and does not test the entry's own "set" marker. (source)

**Inputs a mod gives it** - `tag`: string, a three-letter country tag.

**When it applies** - any time; meaningful in a running game.

**Multiplayer and saves** - read-only.

**Where the player sees it** - the overlay's "Active Flags" page uses the same reader directly; in the mod's Lua only the old wxWidgets utility calls it (`script/utility/gameinfos/flags.lua`, with `G_PlayerCountry`).

### `BiceLib.GameInfo.getCountryVariables(tag)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API can read one variable by name but cannot list them.

**What the feature does** - Returns a table mapping variable name (string) to value (integer): the raw fixed-point value in thousandths, so `12050` means 12.05. Variables whose value is exactly zero are left out. Unknown tag: nil. No variables: an empty table. (source)

**Inputs a mod gives it** - `tag`: string.

**When it applies** - any time; meaningful in a running game.

**Multiplayer and saves** - read-only.

**Where the player sees it** - the overlay's "Active Variables" page uses the same reader; in the mod's Lua only the old wxWidgets utility calls it (`script/utility/gameinfos/vars.lua`, which divides by 1000 and prints with no decimals).

### `BiceLib.GameInfo.getCountryActiveEventModifiers(tag)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API has no list of a country's timed (event) modifiers.

**What the feature does** - Returns a table mapping modifier key (string) to expiry (string) for every entry of the country's list of active timed modifiers, the list `add_country_modifier` fills and a save writes. The expiry is the entry's stored hour converted to `<year>.<month>.<day> <hour>:00`, numbers without padding, on the game's calendar of 365-day years. A modifier with no end is stored by the original with a date in year 1 or earlier (reversing/findings/FINDINGS-countrymodifier.md) and comes out as such a date. Because the table is keyed by name, a modifier present more than once appears once, with the expiry of its last entry. Unknown tag: nil. None active: an empty table. (source)

**Inputs a mod gives it** - `tag`: string.

**When it applies** - any time; meaningful in a running game.

**Multiplayer and saves** - read-only.

**Where the player sees it** - the overlay's "Active Event Modifiers" page uses the same reader; in the mod's Lua only the old wxWidgets utility calls it (`script/utility/gameinfos/activeEventModifiers.lua`).

### `BiceLib.GameInfo.getCountryGeneralModifiers(tag)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API reads one value of a country's global modifier at a time (`GetGlobalModifier():GetValue(kind)`) and only for the kinds it registers as constants; kinds without a Lua constant, such as casualty trickleback, cannot be read.

**What the feature does** - Returns a table mapping the name of each modifier kind (string) to that kind's current total in the country's global modifier (number, an integer in thousandths: 1000 is a value of 1, which for a percentage-type modifier is 100 percent). It covers every one of the 143 kinds this game build has: the engine's fixed kinds, one efficiency kind per mission type, and one susceptibility kind per faction (reversing/findings/FINDINGS-modifierkinds.md). The key is the name string the kind's definition carries; the one the mod relies on is `MODIFIER_TRICKLEBACK`. Kinds that share a name collapse into one key holding the later kind's value (the original defines the naval intel boost kind twice). These totals are what the game's own rebuild of the country modifier produced; they do not include what the game adds from technology at the point of use. Unknown tag: nil. A country whose modifier holds no values: an empty table. (source)

**Inputs a mod gives it** - `tag`: string.

**When it applies** - any time; meaningful in a running game.

**Multiplayer and saves** - read-only.

**Where the player sees it** - `script/utility_data/bicedata_countryinfo.lua` (the Country Info page's provider) calls it with the reported tag and shows casualty trickleback as `MODIFIER_TRICKLEBACK * 0.001` plus the technology contribution.

### `BiceLib.GameInfo.getProvinceDetails(provinceId)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API exposes a province's buildings, owner and infrastructure, but not its stockpile, its resource output or its local modifier values.

**What the feature does** - Returns one table for the province with that id, or nil when the id is negative, not below the number of provinces, or has no province object. Id 0 is the map's placeholder province and answers a table. Every number is an integer in thousandths:

- `id`: the province id (a plain integer, not scaled);
- `supply_pool`, `fuel_pool`: supplies and fuel physically lying in the province. In a country's capital province this pool is the national stockpile (comment);
- `oil`, `metal`, `energy`, `rares`: what the province currently yields per day of crude oil, metal, energy and rare materials, before national modifiers (the save's `current_producing`);
- `manpower`, `leadership`: the province's own manpower and leadership figures;
- `modifiers`: a table with `local_ic`, `local_oil`, `local_energy`, `local_metal`, `local_rares`, `local_leadership` - the province's local modifier values of the kinds local IC, local crude oil, local energy, local metal, local rare materials and local leadership (1000 = a value of 1, i.e. 100 percent); all six read 0 when the province's modifier holds no values. (source)

**Inputs a mod gives it** - `provinceId`: integer.

**When it applies** - any time; meaningful in a running game.

**Multiplayer and saves** - read-only.

**Where the player sees it** - `script/utility_data/bicedata_provincebuildings.lua` (the Province Buildings page's provider) calls it and shows the plain figures as `value / 1000` with two decimals and the modifiers as `value / 10` with two decimals and `%`.

### `BiceLib.Leaders.getLeaderDetails(leaderId)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API has no way to find a leader by id or to ask which unit he commands and where it stands.

**What the feature does** - Returns one table for the leader with that id, or nil when no leader of any country has it. Leaders are found through an index of every leader of every country, built on the first call of a game session and rebuilt when a load or a new game is noticed or a cached entry no longer reads as that leader; where two leaders share an id the first found wins. Keys:

- `id` (integer);
- `name` (string);
- `country` (string, the owning country's three-letter tag);
- `picture` (string, the portrait name);
- `type` (string): `land`, `sea` or `air`; `unknown` for any other stored value;
- `rank` (integer, 0 to 4; per the README's account of land ranks 1 is division, 2 corps, 3 army, 4 army group and theatre);
- `skill`, `max_skill` (integers);
- `starting_skill` (integer): the skill the leader was defined with; the current skill is never below it (comment);
- `experience` (number): the leader's career experience total in the game's binary fixed point with 15 fractional bits - divide by 32768 for experience points. It is not in thousandths;
- `loyalty` (integer, thousandths: 1000 is 1.0);
- `number_of_traits` (integer);
- `province_id` (integer): the id of the province the leader's unit stands in; absent when he commands no unit or the unit has no province;
- `unit_name` (string): the name of the unit he commands; absent when he commands none.

The leader's traits themselves are not returned. (source)

**Inputs a mod gives it** - `leaderId`: integer.

**When it applies** - any time; meaningful in a running game.

**Multiplayer and saves** - read-only.

**Where the player sees it** - `script/utility_imgui/GameInfo/imgui_generals.lua` (the Generals page; reads `province_id` and `unit_name`), and the old wxWidgets utility (`script/utility/gameinfos/generals.lua` likewise, and `script/gui-utility.lua`, which calls it with id 1 only to build the index early).

### `BiceLib.Leaders.addTraitToLeader(leaderId, traitName)`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - a leader gains a trait only from his history file or through the game's own gainable-trait rule after combat; script has no effect that adds a trait to a chosen leader.

**What the feature does** - Finds the leader by id (as `getLeaderDetails` does) and the trait whose name equals `traitName` exactly (case-sensitive) in the game's loaded trait list, and calls the game's own add-trait routine for the pair, immediately, on the calling machine. Returns `true` after the call. Returns `false`, and writes an error line to the DLL's log, when no leader has the id (`addTraitToLeader: no leader with id <id>`) or, the leader being found, no trait has the name (`addTraitToLeader: no trait called '<name>'`); the trait list is empty until the mod's traits are loaded, so the call fails before that. The game's routine consults the trait's per-branch data for the leader's branch before adding (comment); what follows from that was not read here. The same trait can be added more than once; the surplus copies disappear when the save is loaded again, and the leader list shows the change only after it is reopened (readme).

**Inputs a mod gives it** - `leaderId`: integer; `traitName`: string, a key of `common\traits.txt`.

**When it applies** - in a running game, after the traits are loaded.

**Multiplayer and saves** - It writes game state directly and posts no command, so in multiplayer it changes only the machine that calls it unless every machine makes the same call at the same point. The added trait is saved with the leader.

**Where the player sees it** - no file of the mod's `script` folder calls it at present.

### `BiceLib.Inspector.getSelectedEntity()`

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - the game's Lua API cannot tell what the player has selected on the map, nor read a unit's aggregate figures.

**What the feature does** - Takes no argument. Returns nil when there is no in-game screen (main menu, lobby) or the map's terrain list cannot be read. Otherwise returns an array (indices from 1) with one table per thing in the player's current selection, in the selection's order (an empty table when nothing is selected). Every entry has `type` (string): `Army`, `Navy`, `Air`, `Province`, or `Unknown` for anything else. A `Province` or `Unknown` entry has nothing more. A unit entry also has:

- `name` (string): the unit's name;
- 36 statistics read from the unit's own definition object, each an integer in thousandths. That object is the one the original rebuilds for the whole unit from its brigades (reversing/findings/FINDINGS-unitdef.md): most figures are sums over the brigades; maximum speed and range are the lowest brigade's, armour and piercing attack the highest brigade's; organisation, morale, softness and every terrain modifier are means. The keys: `radio_strength`, `max_strength`, `max_organisation`, `manpower` (the build cost in manpower), `morale`, `supply_consumption`, `fuel_consumption`, `officers`, `max_speed`, `air_defence`, `air_attack`, `soft_attack`, `hard_attack`, `air_detection`, `transport_capacity`, `sea_attack`; for land `width`, `weight`, `defensiveness`, `toughness`, `softness`, `armor`, `suppression`, `piercing_attack`; for ships `range`, `firing_distance`, `surface_detection`, `visibility`, `sea_defence`, `convoy_attack`, `sub_attack`, `shore_bombardment`, `hull`, `positioning`; for aircraft `strategic_attack`, `surface_defence`. All 36 are present whatever the unit's kind;
- one table per terrain of `map/terrain.txt`, keyed by the terrain's name: `is_water` (boolean), `attack`, `defence`, `attrition` (integers in thousandths, each the unit's own terrain modifier plus the terrain's own value of the same name) and `movement` (the unit's own terrain modifier alone). A terrain named like a statistic would be overwritten by the statistic.

When the unit has no definition object the entry has only `type` and `name`. (source)

The supply and fuel figures here are the definition's base figures; what the game displays for a unit also scales each brigade by its remaining strength and applies the country's supply consumption modifier and the army group leader's skill (comment).

**Inputs a mod gives it** - none.

**When it applies** - in a running game.

**Multiplayer and saves** - read-only, and local by nature: it reads the local player's selection, so it must never decide what a synchronised command does.

**Where the player sees it** - only the old wxWidgets utility calls it (`script/utility/gameinfos/inspector.lua`: one details window per selected unit, scaling values by 0.001, `morale` and `softness` by 0.1 with `%`, terrain `attack`, `defence` and `movement` by 0.1 with `%`, terrain `attrition` by 0.001 with `%`, and showing land terrains for armies, water terrains for navies and none for air units). The overlay's "Unit Inspector" page reads the same data in C++ without this function.

## Part 7 - Inspector: custom map mode, combat record, order of battle

### The Inspector group: what its pages share

Six pages of this part sit in the overlay's `Inspector` dock group, which the code calls "what the running game says about a particular thing". Their tab titles and order numbers within the group (low first) are: `Unit Inspector` 10, `OOB Browser` 15, `OOB Report` 16, `Combat Reports` 17, `Province Buildings` 50, `Custom Mapmode` 55. The group only decides where a page is docked on a first run with no saved layout. (source)

"The selected country" below always means the overlay's one selected country: a three letter tag the overlay polls from the mod's Lua every 2 seconds while it is on screen (`BiceLibGui.Country.CurrentTag`, which answers the country chosen on the overlay's Country page, and otherwise the local player's own country). It is empty at the main menu, and each page then shows the reason text instead of data. (source)

Pages that call the mod's Lua do so through the overlay's Lua bridge, which refuses every call unless a game is on screen, the caller is the render thread, and no other call is in flight; a refused call leaves the page showing the bridge's reason text. Every Lua function a page calls answers with a table carrying `available` (boolean) and, when false, `reason` (string); the mod wraps each in `Page.Guard`, which turns a Lua error into `{ available = false, reason = <error text> }`. (source)

All text read out of the game (unit, leader and regiment names) is converted from Windows-1252 before it is shown. Colours named "Error", "ErrorDim", "Warning", "Success" and "Strong" below are the overlay theme's semantic colours (red, dimmed red, amber, green, and the theme's highest contrast text colour); their exact values belong to the theme and were not read for this part. (source, comment)

None of these pages changes game state except as said in "The combat record" (two country variables). There is nothing on the Unit Inspector, the two OOB pages, Province Buildings or Custom Mapmode that the player can use to alter the game. (source)

### Custom Mapmode page and the custom map mode (a takeover of the Victory Points map mode)

Kind: interface
Switch: the page exists with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`). The map mode itself is off until the player ticks "Paint the VP map mode with this instead" on the page; ticking it the first time installs the map mode hooks, which are never removed afterwards.

**What the original does without it** - The game has sixteen map mode buttons and no way for a mod to add one. Its Victory Points ("VP") map mode gives every province a grey base (darker when the viewing country's intelligence on the province is below 2) and, for a province with victory points, one of three fixed hues - green for the player's own and its faction's, red for an enemy's or the rebels', yellow for anyone else's - at one of two brightnesses (1 to 14 points, 15 or more). Its province tooltip adds a points line (localisation key `PROV_POINTS`). In the VP mode the sea is not drawn from province colours at all. The game's own Resources map mode tooltip lists crude oil, metal, energy and rare materials, current against maximum, and nothing about manpower or leadership; its Supply map mode tooltip lists where the province is supplied from, how many nodes away, local supplies and fuel, what is required and received (`LOGTT_1` to `LOGTT_7`). (reversing/findings/FINDINGS-mapmode.md)

**What the feature does**

*What a custom map mode is.* There is exactly one custom map mode, and it has no button of its own: while it is switched on, the game's VP map mode button shows it instead of victory points. It shades every province by one figure the province holds, chosen by the player from three built-in lists ("kinds"): a building's level, a resource's amount, or a supply figure. The lists are fixed in the DLL, except that the building list is read from the running game's own building definitions. Nothing is defined in Lua, in a mod file or by the player; the player only picks which source is shown. Each kind remembers its own last pick. (source)

*How it replaces the VP colours.* While the mode is on (ticked, and a source is chosen), two things change inside the game's VP colouring pass and nothing else: every province is treated as having zero victory points, so the game never gives it an owner hue; and the single colour the game then stores for the province is replaced by the mode's colour. The colour is one flat colour per province (the game stores it into both of the province's two colour slots, so there are no stripes), fully opaque. The game's data is never written: the province's real victory points stay as they are and count as before for the game's rules. While the mode is off the hooks do exactly what the original instructions did, so the VP map mode is the game's own again. (source)

*The colour of one province*, in this order (source):

1. Read the viewing country's intelligence level on the province - the viewing country being the one the game is drawing the map for, the same one its fog of war uses. A level that cannot be read counts as 0. The province is "seen" when the level is 6 or more. 6 is the level at which the game's province window starts showing buildings (found by testing, per the findings); applying it to resources too is the DLL's assumption. (source, comment)
2. Kind Supply and not seen: dark grey 120,120,120, whatever the province holds - not even that there is something to show.
3. The province has no value for the source ("nothing to show", see each source below): light grey 200,200,200 when seen, dark grey 120,120,120 when not.
4. Otherwise the province is drawn in one of ten shades of the current palette: the shade for its value when seen, and shade 1 (the lowest) when not seen - so an unseen province says the thing is there without saying how much.

Sea provinces are not treated specially by this rule (most have no value and would come out grey), but the VP map mode does not draw the sea from province colours, so the sea looks as it does in the game's VP mode. (source for the rule; reversing/findings/FINDINGS-mapmode.md for the sea)

*The two palettes*, decimal R,G,B for shades 1 to 10 (source):

| shade | "green shades" (default) | "red to green" (heat) |
| --- | --- | --- |
| 1 | 27,106,27 | 25,0,0 |
| 2 | 31,123,31 | 153,0,0 |
| 3 | 34,139,34 | 204,25,0 |
| 4 | 38,156,38 | 255,76,0 |
| 5 | 42,172,42 | 255,255,0 |
| 6 | 45,189,45 | 165,191,0 |
| 7 | 49,205,49 | 25,102,0 |
| 8 | 52,222,52 | 51,127,0 |
| 9 | 56,238,56 | 63,186,0 |
| 10 | 60,255,60 | 0,255,0 |

The green ramp is computed, with integer division: green = 90 + (165 * shade) / 10, red = blue = 24 + (36 * shade) / 10. The heat ramp is the ten colours of the game's own Infrastructure map mode, copied as they are, including its step backwards in brightness between shades 6 and 7. (source; reversing/findings/FINDINGS-mapmode.md for where the heat colours come from)

*From value to shade.* Three ways, by source (source):

- **Level** (every building): the shade is the level, held between 1 and 10.
- **Bands** (most supply sources): ten fixed start values, lowest first. The shade is 1 plus the number of starts after the first that the value reaches; that is, shade k covers values from start k up to but not including start k plus one, and shade 10 everything from the tenth start up. A value below the first start is shade 1.
- **Map** (every resource, and the traffic and stock supply sources): ten start values worked out from the map itself, then used exactly like bands. Collect the source's value from every province that has one greater than zero, sort ascending, and take `low` = the entry at index floor(0.01 * n) and `high` = the entry at index floor(0.99 * n) (index capped at n - 1), n being the count. If `high` is not above `low`, all ten starts are `low` (every province with at least that much is shade 10). Otherwise start i (i = 0 to 9) is `low * (high / low) ^ (i / 9)`, rounded up to a whole raw value (a tolerance of one billionth is subtracted before rounding up), with the first start set to exactly `low` and the last to exactly `high`. So the scale is logarithmic between the 1st and the 99th percentile of the provinces that have any. The count n is kept for the legend.

Where a source is marked "higher is worse" the shade is reversed after that: shade becomes 11 minus shade, so the bottom shade is still the one to worry about.

*Kind Buildings.* The list is every building the game defines, in the order of the game's own building table, skipping the table's first entry (a placeholder meaning "no building"). Each entry shows the building's display name as the game localised it, and its key. The value is the building's **current** level in the province (the level after bombing damage, not the built maximum), held by the game in thousandths and cut to whole levels; a level of 0 or less, or above 100, is "nothing to show". Scaling: Level. (source)

*Kind Resources.* Six fixed entries, in this order: `energy` "Energy", `metal` "Metal", `rare_materials` "Rare Materials", `crude_oil` "Crude Oil", `manpower` "Manpower", `leadership` "Leadership". The first four are what the province currently yields of that good (the province's current production figures, not its `local_` modifiers); the last two are the province's manpower and leadership. All are thousandths. A value of 0 or less, or above 1000.000, is "nothing to show". Scaling: Map. (source)

*Kind Supply.* Eleven fixed entries, in this order (source; the two game routines named are described in reversing/findings/FINDINGS-supplynetwork.md, section 7):

| key | label | value (raw) | scaling | legend unit | higher is worse |
| --- | --- | --- | --- | --- | --- |
| `days_of_supplies` | Days of supplies | supplies lying in the province times 1000, divided by what the units drawing on the province need a day (integer division); thousandths of a day, capped at 365 days. Nothing to show where the daily need is 0 | Bands 0, 1, 2, 3, 5, 7, 10, 15, 21, 30 days | days | no |
| `days_of_fuel` | Days of fuel | the same for fuel | the same bands | days | no |
| `depot_distance` | Distance to depot | the cost of the route from the province to the depot that supplies it, as the game's supply network stores it (each province entered costs 1, 2 or 3 by infrastructure, times a size factor). A province marked cut off from every depot reads as "cut off" (100000). Nothing to show for a province in no supply network (depot number 0: the sea, and some land) | Bands 0, 1, 2, 4, 7, 12, 20, 35, 60, cut off | cost | yes |
| `depot_detour` | Infrastructure penalty | that cost less the number of provinces on the route, never below 0. Nothing to show where the province is in no network, is cut off, or the count cannot be read | Bands 0, 1, 2, 3, 5, 8, 12, 18, 26, 40 | cost | yes |
| `supply_load` | Supply line load | supplies asked of the province today (its own units' shortfall and what provinces further out want through it) times 1000, divided by what the province can pass on in a day; thousandths, capped at 10000. The capacity is the game's own supply capacity routine, called for every province. A capacity of 0 or less reads as 10000. Nothing to show where nothing is asked today | Bands 0, 10, 20, 30, 40, 50, 60, 70, 85, 100 percent | percent | yes |
| `fuel_load` | Fuel line load | the same for fuel, against the same capacity | the same bands | percent | yes |
| `supply_tax` | Supply tax | what a load loses crossing the province: the game's own supply loss routine, called for every province that is in a supply network; thousandths. Nothing to show for a province in no network, or where the routine answers below 0 | Bands 0, 0.025, 0.04, 0.05, 0.06, 0.075, 0.1, 0.125, 0.15, 0.19 | amount | yes |
| `supply_traffic` | Supply traffic | supplies passed on through the province today (the daily supply pass's throughput figure for today); thousandths. Nothing to show at 0 | Map | amount | no |
| `fuel_traffic` | Fuel traffic | the same for fuel | Map | amount | no |
| `supply_stock` | Supplies stored | supplies lying in the province; thousandths. Nothing to show at 0 | Map | amount | no |
| `fuel_stock` | Fuel stored | fuel lying in the province | Map | amount | no |

The bands in the table are written in display units; the comparison is made on the raw values (thousandths of a day, thousandths of capacity, thousandths of tax, and plain numbers for the two cost sources). An amount read for these that is below zero or above 1,000,000.000 counts as 0. For reference, the capacity routine per the findings: unlimited (99999.000) for a controller's acting capital and every province bordering it; otherwise the infrastructure level squared, times the define `INFRA_THROUGHPUT_IMPACT`, times `OWNED_AND_CONTROLLED_THROUGHPUT_CAP_BONUS` on ground the controller also owns, times one plus the controller's supply throughput modifier and technology. The loss routine: the define `SUPPLY_TAX`, halved on ground the controller also owns, raised by mud (`MUDDYNESSSUPPLYTAXMODIFIER`) unless the ground is frozen, raised by partisan support (`PARTISAN_EFFECT_ON_SUPPLY_TAX`) less suppression where the controller is the owner's enemy, plus the controller's technology figure for supply transfer cost (negative in the files), never below 0. A reimplementation that has these two rules need only evaluate them per province. (reversing/findings/FINDINGS-supplynetwork.md)

Each supply source carries an explanation the legend prints, exactly (source):

- Days of supplies: "How many days the supplies in the province last its units, at what they use a day. Each shade starts at the number of days under it. The game keeps a province stocked for 35 days of its need, so a well supplied one sits in the top shade. Only provinces with units that use supplies are shaded."
- Days of fuel: "How many days the fuel in the province lasts its units, at what they use a day. Each shade starts at the number of days under it. The game keeps a province stocked for 35 days of its need, so a well supplied one sits in the top shade. Only provinces with units that use fuel are shaded."
- Distance to depot: "How far the province is from the depot that supplies it. Supply is handed along province by province, so the further it has to travel, the less of it arrives. Poor infrastructure makes a province count as two or three instead of one, so a route across bad ground is further than it looks on the map. Each shade starts at the number under it. Depots themselves are the top shade, provinces with no supply line at all the bottom one, and land in no supply network is grey."
- Infrastructure penalty: "How much of that distance is poor infrastructure rather than real distance. Zero means the way to the depot is good all the way and costs nothing extra. Eight means the route counts as eight provinces longer than it really is, because of what it crosses. This is the number that building infrastructure brings down. Provinces with no supply line at all show nothing."
- Supply line load: "How much of what the province can pass on in a day is asked of it today - its own units' shortfall and what provinces further out want through it. Each shade starts at the share under it; at 100% the line through here is full, and anything beyond waits. How much a province can pass on is the game's own figure, worked out from the province's modifiers and its controller's."
- Fuel line load: "The same for fuel, which shares the province's capacity figure: how much of what it can pass on in a day is asked of it today. At 100% the line through here is full."
- Supply tax: "What a load of supplies or fuel loses crossing the province - the same amount whatever the size of the load, so a long line of small loads loses the most. Half on the controller's own ground; more in mud, unless the ground is frozen; more again where partisans are active in occupied land; less with the controller's supply technologies. Each shade starts at the tax under it. The game's own figure, worked out for each province once a day. Land in no supply network is grey."
- Supply traffic: "Supplies passed on through the province today, on their way out from the depot - the supply lines themselves."
- Fuel traffic: "Fuel passed on through the province today, on its way out from the depot."
- Supplies stored: "Supplies in the province. A capital's are the country's whole stockpile, so it sits in the top shade."
- Fuel stored: "Fuel in the province. A capital's is the country's whole stockpile, so it sits in the top shade."

The "35 days" in the first two is BlackICE's value of the define `SUPPLYPOOL_DAYS`, written into the text rather than read. (comment)

*When colours are recomputed.* (source)

- The game itself runs its VP colouring pass when the VP map mode is picked and, not reliably, as days pass; every such pass goes through the takeover. (comment)
- The DLL asks the game to run that pass again at once (only if the VP map mode is the one on screen; otherwise nothing happens) when the checkbox is ticked or unticked, when a source or kind is picked, and when the palette is changed.
- Once a game day: every frame the DLL checks that a game is on screen (the game's own in-game flag, so this also works while paused), that the mode is on, and that the VP map mode is the one on screen. If so, in the first frame of each game day at hour 1 or later (after the game's midnight processing), it recomputes what the shown source needs and asks for a repaint. When the VP map mode has just come back on screen after another mode was shown, the next such frame repaints regardless of the day (still not before hour 1).
- What is recomputed with the daily repaint: the Map scale of a supply source, the per-province capacities for the two load sources, and the per-province taxes for the tax source. A resource's Map scale is computed only when the resource is picked or the checkbox is ticked, not daily. Capacities, taxes and scales are also computed when their source is picked and when the checkbox is ticked.
- While any other map mode is on screen nothing is computed at all; the per-province capacity and tax calls (one call into the game per province) are the costly part.

*The province tooltip in the mode.* While the mode is on and the VP map mode is on screen, the tooltip for the province under the mouse is the one of another game map mode, borrowed whole: kind Supply shows the game's Supply map mode tooltip, kind Resources the game's Resources map mode tooltip (with the two added lines of the next section), and kind Buildings keeps the VP tooltip, since no game tooltip lists buildings. Any other map mode's tooltip is untouched. (source)

*The page.* Tab title `Custom Mapmode`, group `Inspector`, order 55. No refresh interval: it draws from the DLL's own state each frame. (source)

- If the building list is empty (no game has been entered yet in this process): the dimmed line "Nothing read yet - load a game first." and a button "Try again" (drops the cached list so the next frame reads again). Nothing else is drawn.
- Checkbox "Paint the VP map mode with this instead". It shows what was clicked, not whether anything came of it. Tooltip: "While this is on, the VP map mode shows what is chosen" / "below instead of victory points." / blank line / "Switch map mode away and back for the map to redraw." Ticking it installs the hooks if needed, picks the first source of the current kind if none is chosen, computes the scale and asks for a repaint.
- Under it, in the Warning colour, when ticked: "Not hooked: <status>" if the hooks could not be installed (status texts: "hoi3_tfh.exe is not loaded", "the code is not what this build expects", "could not make the code writable"), otherwise "Reselect the VP map mode in game to redraw the map."
- A single button whose label names the palette in use: "Palette: green shades" or "Palette: red to green"; a click switches to the other, saves it and repaints. Tooltip: "Green shades: one colour, brighter with the value." / "Red to green: red at the bottom shade, through orange and yellow," / "to green at the top."
- "Shade by" with three radio buttons: "Buildings", "Resources", "Supply". Choosing one switches kind, returns to that kind's last pick (the first entry if it has none) and repaints.
- A heading "Building", "Resource" or "Supply", then on the left a filterable list 380 wide, as tall as the window allows, of the kind's sources labelled "<display name> [<key>]" (the key alone where there is no display name). The key is part of the label on purpose: two buildings share the display name "Air Base". The list has a filter box (case-insensitive "contains", one filter text remembered per kind), is walked with the up and down arrows, Home and End while it has focus, and a click or key move selects - which shows that source on the map at once.
- On the right: the selected source's display name, its key dimmed, and the legend; or "Nothing selected."
- The legend, headed "Shades": if the source is not a Level source and no scale could be computed, "No province has any of this." Otherwise a row of ten colour swatches, shade 1 to 10, in exactly the colours the map uses, and under each: for a building the shade number; for anything else the value that shade starts at (for a "higher is worse" source the starts run the other way with the shades, the largest under shade 1). Start values print by unit: *amount* and *days* as the value in units with about three figures - no decimals from 100 up, one from 10, two from 1, three below 1, trailing zeros and a trailing point removed, never in exponent form; *cost* as the whole number, or "cut off" for the cut-off value; *percent* as the raw value divided by 10, whole, with a percent sign.
- Under the swatches, wrapped: the source's explanation if it has one; for a Map source "Each shade starts at the amount under it. N provinces have any; the scale runs from the 1% with the least to the 1% with the most, so everything above X shares the top shade." (N the count, X the last start), with the hover text "Logarithmic, so each shade covers about the same step up rather than the same amount. Amounts like these are lopsided: a scale running evenly to the largest puts most provinces that have any in the bottom shade. Worked out from the map when chosen, and for supply again every day."; for a building "Levels 1 to 10, the same ladder the game's infrastructure map climbs."; and last, for kind Supply "Grey: nothing to show. Only provinces you have the intel for - your own and your allies' - show any supply; the rest are dark grey.", otherwise "Grey: none here - light where you can see the province, dark where not."

**Inputs a mod gives it** - None directly. The building list, with display names, comes from the game's loaded building definitions (the mod's `common/buildings.txt` and its localisation, as the game read them). The defines named above act through the game's own routines. One settings key, `customMapMode.palette`, in `BiceLibSettings.ini` beside the DLL (plain `key=value` lines): `green` or `heat`; anything else, or no line, reads as green. (source)

**When it applies** - The page can be opened at any time but lists nothing until a game has been entered once; the building list is then kept for the rest of the process. The hooks are installed the first time the checkbox is ticked, after checking that the game code at all four hook points is exactly what this build of the executable should have (if not, nothing is patched and the page says so); they stay installed until the game exits, and unticking the box makes three of them inert (the fourth is the next section). The mode starts off in every run of the game: the tick, the kind and the picks are kept only in memory, so they survive leaving a game and loading another within one run and are gone when the game is closed. Nothing is computed at the main menu or while another map mode is shown. A game cannot start on the VP map mode, so a campaign begins with none of this running. After another savegame is loaded in the same run, a resource's scale is still the one computed when it was picked, until it is picked again or the box is ticked again. (source)

**Multiplayer and saves** - Purely local display: nothing is written to game state, no command is posted, nothing is in the savegame. Each player sees it only on their own machine and only with their own overlay. It shows nothing the player's intelligence does not allow: below intelligence 6 a building or resource province shows only that the thing exists, and a supply province nothing. The only thing kept outside the game is the palette choice in `BiceLibSettings.ini`. (source)

**Where the player sees it** - The `Custom Mapmode` page of the overlay, and the main map whenever the game's VP map mode button is the selected one; the province tooltip there.

### Always with the map mode hooks: manpower and leadership lines in the Resources map mode tooltip

Kind: text
Switch: installed together with the custom map mode hooks, the first time "Paint the VP map mode with this instead" is ticked on the Custom Mapmode page in a run of the game. It has no off state: from then until the game exits it applies, also with the custom map mode unticked.

**What the original does without it** - The Resources map mode's province tooltip lists the province's crude oil, metal, energy and rare materials, each current against maximum, behind an intelligence test of 1 or more, and then its strategic resource. A province's manpower and leadership are not mentioned. (reversing/findings/FINDINGS-mapmode.md)

**What the feature does** - After the four goods lines and before the strategic resource line, it appends up to two lines to the tooltip text, each on a new line, with no colour codes (source):

    <text of MANPOWER_IRO>: <figure>
    <text of PV_LEADERSHIP>: <figure>

A line is added only when the province's figure is greater than zero. The figure is the province's manpower or leadership (thousandths) rounded to hundredths, half up - five is added to the value and the sum divided by 10 with integer division - and printed with exactly two decimals, for example `1.25` (two decimals because leadership runs in steps as small as 0.05). Both lines are left out when the local player's intelligence level on the province is below 1, which is the same test the goods lines have. The player meant here is the game's local player country, not the overlay's selected country. (source)

**Inputs a mod gives it** - The localisation keys `MANPOWER_IRO` ("Manpower" in English) and `PV_LEADERSHIP` ("Leadership"), both of which the base game already has; they are looked up through the game's own localisation. (source)

**When it applies** - Whenever the game builds the Resources tooltip after the hooks are in: in the game's own Resources map mode, and in the custom map mode's Resources kind, which borrows that tooltip. Not before the custom map mode has been ticked once in the current run. (source)

**Multiplayer and saves** - Local text only; nothing is changed, posted or saved.

**Where the player sees it** - The province tooltip in the Resources map mode (and in the custom map mode while it shades by a resource).

### Always on with the overlay: the combat record (capture of every finished combat, kept per campaign in files)

Kind: infrastructure
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`). There is no further switch: recording is on by default and nothing in the interface turns it off. The hook on the game's combat recording is installed by the overlay's per-frame step, the first time (checked once a second) the game's clock reads a real date - in practice when the first game of the run is entered - and is never removed.

**What the original does without it** - When a combat ends the game adds an entry to its combat history holding the hour it ended, the kind of combat, the province, and the tag of one side only - the winner; the other slot reads `---`. No casualty figure is kept. The history is pruned every hour of entries older than 168 hours (a week). So the game itself can never answer "what did this war cost over a year". (reversing/findings/FINDINGS-combat.md)

**What the feature does**

*What is observed, and when.* One hook, on the game routine that records a finished combat into its history. It runs once per combat, at the moment the combat ends - never at its start and never hourly - for every kind: land, air and naval battles and the three kinds of bombing raid (on a province, on the land units in one, on ships). At that moment the combat and both its sides still exist with their final figures; the units themselves have already been taken off the sides. The hook runs on whichever game thread finishes the combat, only copies figures into a small in-memory ring, and touches neither files nor Lua. (source; reversing/findings/FINDINGS-combat.md confirms the routine is reached for every kind)

*What is captured per combat.* (source)

- the game hour (tick) at which it was recorded;
- the kind, from the combat's class: Land, Air, Naval, Ground bombing, Land bombing, Naval bombing, or unknown;
- the id of the province it was fought in (0 if none could be read);
- for the attacker and for the defender:
  - the tag and country id the game itself would name the side by: the first country in the side's list of countries still in the fight, or `---` with id 0 when that list is empty;
  - whether the side was "standing" (that list not empty);
  - a second tag and id, from the first entry of a second list each side keeps of its own countries, which is not emptied when the side is beaten. It is accepted only if it looks like a tag: three characters that are capital letters or digits, a terminator, and an id below 1024;
  - losses: the strength the side lost over the whole combat, in thousandths, as the game totals it for its own battle message (21900 is the "21" the game reports). Per the findings, in a naval battle this figure is a count of ships sunk, 1000 per ship, and in land and air combat it is strength in the units' own currency;
  - men: how many men the side had in the fight - the sum, over every sub unit type the game defines, of the side's per-type tally divided by 1000 (each entry divided before adding, negative or zero entries skipped), which is how the game arrives at "out of 25700 troops". It is a headcount only for land and naval battles; in an air combat the tally counts sub units, and a bombing raid leaves it empty.

There are no per-unit figures: nothing is recorded about individual units, regiments, leaders or ships, and nothing is derived by comparing snapshots - every figure is a total the game holds at the end. (source)

*Who won.* If exactly one side is standing, that side won (this is the test the game itself makes when it writes a tag or `---`). Otherwise the outcome is unknown, which is the normal result for a bombing raid, where both sides keep their countries. When there is a winner, the loser's tag and id are filled in from the loser's second list - but only if the winner's second list names the winner's own tag, a check with a known answer that guards against the second list being misread. If the check fails, or the loser's second list gave no tag, the loser stays `---` and the combat can be counted for the winner only. Only the first country of a side is ever read, so an allied force is recorded under one tag. (source)

*From ring to file.* The ring holds the last 64 captured combats, numbered in sequence. Once a second, on the render thread (inside the overlay's frame hook, whether or not the overlay is visible), the store step runs (source):

1. Watch the game clock for a savegame load (below).
2. Do nothing further until at least one combat has been captured in this run. A captured combat is the proof that a game is really running, which is what makes it safe to call the game's Lua API.
3. If no campaign number is known yet: at most every 2 seconds ask Lua `BiceLibGui.Combat.Campaign`; once it answers a non-zero id, fix the two file paths and create the folder.
4. Once, read both files and work out the timeline.
5. If no session is known, or a load has been seen since the last one: at most every 2 seconds call Lua `BiceLibGui.Combat.NewSession` and write the new session down. Otherwise, while the last claim is unconfirmed, call `BiceLibGui.Combat.Session` every 5 seconds until the game reports the claimed number back.
6. With a session known, take every captured combat not yet filed, in order, and file it under the current session - unless a combat with the same tick, province, attacker tag and defender tag is already in the timeline being played (a guard against the same combat arriving twice). Filing means appending one line to the campaign file and adding it to memory.

If more than 64 combats are captured before step 6 can run (for instance while no campaign number can be claimed), the overwritten ones are gone and are counted as "lost"; the page reports the count.

*The files.* Folder `combat_reports` beside the DLL (the mod's `script` folder; the mod's deploy script lists the folder among those it preserves). Plain text, lines ending in a newline, values separated by semicolons, lines starting with `#` and empty lines ignored. (source)

`campaign_<id>.txt`, one line per combat, appended as combats are filed and never rewritten. When the file is new it starts with this header:

    # BiceLib combat record: tick;branch;province;attackerTag;attackerId;attackerLosses;attackerMen;defenderTag;defenderId;defenderLosses;defenderMen;winner;session
    # branch: L land, A air, N naval, and a bombing raid in lower case - g on a province, l on the land units in one, n on ships
    # a line with no session belongs to session 0, written before there were any

Fields: `tick` unsigned; `branch` one character `L`, `A`, `N`, `g`, `l`, `n`, or `?` for unknown; `province` id; tags up to 7 characters, `---` for an unnamed side; ids; losses in thousandths; men whole; `winner` one character `A` (attacker), `D` (defender) or `?`; `session` unsigned. On reading, a line with fewer than 12 readable fields is skipped; a line with 12 (no session) belongs to session 0.

`campaign_<id>_sessions.txt`, one line per session, appended when a session is claimed. Header when new:

    # BiceLib combat sessions: id;parent;startTick
    # one line per savegame load. The parents lead back to the start of the campaign, and that chain is the timeline being played.

A line with fewer than three fields, or with id 0, is skipped.

A tick is the game's hour count: 43,800,000 plus ((year times 365) plus the day of the year counted from 0) times 24, plus the hour; years have 365 days and no leap day. (source)

*Campaigns.* A campaign is identified by a number from 1 to 999999 kept in the country variable `bice_combat_campaign` of the mod's housekeeping country `OMG`, so it travels in the savegame. The first time it is asked for and found 0, the mod's Lua picks one and posts it; the answer stays 0 until the posted change has taken effect, and the DLL simply asks again. (source)

*Sessions and the timeline.* A campaign file can hold several versions of the same months: load an old savegame and play on, and those months are fought again. So every entry into a game - a new game, or any savegame load - starts a *session*, numbered 1 to 999999 and kept in the country variable `bice_combat_session` of `OMG`. Because a savegame carries whichever session was live when it was written, the number found in the variable at the moment a new session is claimed is that session's *parent*. (source)

- Spotting a load: once a second the game clock is sampled. A reading of 0 means no game (and the next real reading counts as a load). A load is noted, with the tick read, when the previous sample was 0, when the clock went backwards, or when it jumped forward by more than 2160 hours (90 days) in one step. Only the most recent load is remembered.
- A new session's start tick is the tick noted at the load, or the current tick if no load was noted.
- The timeline being played is the chain from the current session through its parents to session 0 (the root, which also owns every line written before sessions existed), at most 512 links. The current session counts whole; each ancestor counts only combats whose tick is strictly below the start tick of its child in the chain. If a session in the chain is missing from the sessions file, the chain ends with the root counted whole instead of being cut.
- A combat in the file whose session is not in the chain, or whose tick is at or past its session's bound, is "set aside": kept in the file, left out of every figure. Going back to a savegame of that branch makes it count again.
- Between a load being noted and the next combat anywhere in the world (which is what lets the DLL ask Lua for the new session), figures are still those of the timeline before the load.

*Reading the record.* The store offers the page: the campaign number (0 until claimed) and the reason text while there is none ("waiting for a campaign", "Lua unavailable: <reason>", "claiming a campaign number", or Lua's own reason such as "No player country yet"); the two file paths; the current session number; the number of links in the chain; the count set aside; whether a load is pending; the lost count; the entries of the timeline; the current tick; and a tally for one tag between two ticks (both included), for one kind or all. A tally counts a combat for the tag when it is the recorded attacker or defender: combats; won and lost (only where a winner is recorded); as attacker; as defender; losses (the tag's own side) and kills (the other side's losses), both summed in 64 bits. (source)

**Inputs a mod gives it** - The mod's Lua must provide, under `BiceLibGui.Combat` (source):

- `Campaign()` - answers `{ available = true, tag = <selected tag>, id = <number> }`, where id is `BiceData.Combat.EnsureId()`: the stored campaign number, or 0 after posting a freshly picked one. Answers unavailable with reason "No player country yet" while the overlay has no selected country.
- `Session(expected)` - answers `{ available = true, id = <stored session number> }`; if `expected` is above 0 and differs from what is stored, it posts `expected` again (so a claim that never landed is retried before a savegame can carry the wrong session).
- `NewSession()` - answers `{ available = true, id = <new number>, previous = <stored number> }` after posting the new number; unavailable with "No player country yet" without a selected country.

The Lua side reads the variables through the game's Lua API (`CCountryDataBase.GetTag("OMG"):GetCountry():GetVariables():GetVariable(CString(name)):Get()`, rounded to a whole number) and writes them by posting the game's own set-variable command (`CCurrentGameState.Post(CSetVariableCommand(tag, CString(name), CFixedPoint(value)))`). A number is picked as 1 plus ((Lua's `os.clock()` times 1000, floored) plus a random number from 1 to 999999 plus, for each character of the selected tag, its byte value times its position times 7919, plus the current date's total days) modulo 999999; a new session number equal to its parent is moved on by one. The mod must have a country `OMG`. (source)

**When it applies** - From the first combat that ends after a game is entered, in every game of the run, for as long as the overlay is enabled; whether the overlay is shown makes no difference. Nothing is recorded for combats that ended while the overlay was disabled or before the hook was in, so a year's figures need a year of play with it on. (source)

**Multiplayer and saves** - The two numbers live in the savegame as country variables of `OMG` and are set through the game's ordinary command queue, so every machine holds the same values. The files are local to each machine and are not part of the savegame: a player who deletes them, or plays the save on another machine, starts with an empty record, and a record cannot be rebuilt from a savegame. In memory, the campaign number and the loaded file are kept for the whole run of the game. The same hook also tells BiceLib's per-unit combat damage tooltip feature (described in its own section) that a battle has ended. (source)

**Where the player sees it** - Only through the Combat Reports page; the files can also be read in a text editor.

### Combat Reports page

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`).

**What the original does without it** - Nothing: this is new. The game shows a battle result once, as a message, and keeps a week of history without casualties.

**What the feature does** - Tab title `Combat Reports`, group `Inspector`, order 17. It needs no refresh: it reads the combat record's in-memory timeline every frame, and the record itself is brought up to date once a second. Everything is for the overlay's selected country. (source)

*Period.* A row of radio buttons: "Day" (1 day), "Week" (7, the default), "Month" (30), "Half year" (182), "Year" (365), "Custom". For a fixed period the range is from the current game hour minus days times 24 (not below 0) to the current hour, and the row ends with the dimmed text "last N days | TAG".

For "Custom" the row continues with two date boxes ("from" and "to", just wide enough for a date like 1936.12.31), the word "to" between them, and five buttons. Dates are written year.month.day. The first time Custom is picked with a readable game date, the range is set from 720 hours (30 days) before now to now, which the page counts as 31 days because both end days are included whole. The "to" box has the hover text "Dates as the game counts them: year.month.day, the way they are written in the list below. Both ends are included, the last one for the whole of its day." The buttons: "-" ("A day off the end") and "+" ("A day onto the end") move the end by one day, never before the start; "<" ("Both ends back a day") and ">" ("Both ends on a day") slide the whole range a day; these four repeat while held; "Now" puts the range back to that starting range, ending today, and replaces whatever is typed (disabled, with "The game's date cannot be read, so there is no current date to move the range to.", when there is no game date; otherwise its hover text is "Back to 31 days ending today, <date> - the range the page starts at. Whatever is typed in the two boxes is replaced."). Each frame both boxes are read: the start counts from hour 0 of its day and the end through hour 23; if both read as dates they become the range (swapped if the start is after the end), and the row ends with "N days | TAG", N being the hours between divided by 24, plus one. If either does not read as a date the range stays where it was and the row ends, in the Warning colour, with "not a date - write it as 1936.1.1 | showing <from> to <to>". (source)

*The figures table.* Columns: an unnamed label column, "Land", "Air", "Naval", "Bombing" (the three kinds of raid added together), "Total" (every kind, including combats of unknown kind). Rows, each the selected country's tally over the range: "Combats", "Won", "Lost", "As attacker", "As defender", "Enemy casualties" (the other side's losses), "Own casualties" (its own). Casualties are the thousandths summed and then divided by 1000, whole. Every number is written with a full stop between groups of three digits (1234567 as 1.234.567). Because a naval battle's losses are ships and a raid's target losses are of another kind again, the Total column adds unlike things; the page does not say so. (source; reversing/findings/FINDINGS-combat.md for what the figures mean per kind)

*Notes under the table*, each only when it applies (source):

- Warning colour: "N combats in this period name only their winner." - the number of combats in the timeline and the range, for any country, in which either side is still `---`. Its hover text explains that the game names only the winner, that the loser's name comes from a second list the beaten side keeps, and that where that could not be read "the combat belongs to nobody and is counted for neither side".
- Warning colour: "No campaign yet: <reason>"; or dimmed "Campaign N, M combats recorded" (M the timeline's count), with a hover text giving the campaign file's path, "Session S, D deep in the campaign's history" and the session file's path.
- On the same line, Warning colour, if the hook could not be installed: "- not recording, so nothing is being added".
- Warning colour: "A savegame was just loaded - these are still the figures from before it." while a load has been noted and its session not yet claimed; hover text: "Which run of the campaign a savegame belongs to is kept on OMG, and reading it means calling the game's script, which is only safe to do once a combat has been caught. The next combat anywhere in the world settles it - usually within game hours, and in peacetime there is nothing being miscounted meanwhile."
- Dimmed: "N combats set aside, on branches this campaign left"; hover text: "Combats in the file that this campaign did not fight: they were fought after an old savegame was loaded, on a run that was then left for another. They stay in the file, because going back to that run would make them count again, and they are left out of every figure on this page."

*Last battles.* A heading "Last battles", then the selected country's most recent combats in the timeline, newest first, at most 16, regardless of the period chosen above. With no selected country: "No country selected."; with none recorded: "Nothing recorded for TAG yet. Battles are added as they finish." The table grows with its rows and scrolls only if the window is too short. Columns (source):

| column | content |
| --- | --- |
| Ended | the date and hour it ended, as `year.month.day hour:00` |
| Kind | "Land", "Air", "Naval", "Ground bombing", "Land bombing", "Naval bombing", or "?" |
| Result | "Won" in the Success colour, "Lost" in the Error colour, or a dimmed "-" where no winner is recorded (every bombing raid) |
| Role | "Attacker" or "Defender" |
| Against | the other side's tag |
| Enemy casualties | the other side's losses, thousandths divided by 1000, grouped as above |
| Of | the men the other side had, grouped - shown only for a land or naval battle and when above 0; otherwise a dimmed "---" |
| Own casualties | the selected country's losses |
| Of | the men it had, on the same terms |
| Province | "Name (id)", or the id alone where the province has no name or the id is 0 |

Province names come from the mod's Lua, `BiceLibGui.Oob.ProvinceName(id)`, and are remembered (an empty answer too) in a cache of at most 16 that is emptied when a seventeenth is wanted. Under the table, in the Error colour, if any captured combats were lost before filing: "N combats were caught but could not be filed, so they are missing from all of this." (source)

There is no detail view of a single combat, no sorting, no filter other than the period and the selected country, no export, and nothing the player can change. (source)

**Inputs a mod gives it** - `BiceLibGui.Oob.ProvinceName(provinceId)`, which answers `{ available = true, name = <text or ""> }` from the mod's merged localisation table, key `PROV` followed by the id. Everything else comes from the combat record. (source)

**When it applies** - The page draws at any time; with no game it shows empty figures and "No campaign yet". Figures cover only what has been recorded on this machine.

**Multiplayer and saves** - Display only. See the combat record for what is kept where. The selected country may be any country the overlay lets the player select, so the page shows another country's recorded battles and losses as readily as the player's own.

**Where the player sees it** - The `Combat Reports` tab of the overlay's Inspector window.

### Order of battle read (shared by the OOB Browser and the OOB Report)

Kind: infrastructure
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`); no hook is installed for it.

**What the original does without it** - Nothing: this is new. It is a read for the overlay's own pages and is not offered to the mod's Lua.

**What the feature does** - Reads the whole order of battle of one country straight from the running game's state (no Lua), on the render thread, and returns plain values. Each page keeps its own copy and reads again on its own schedule. (source)

*Gathering.* Start from the country's own list of units, which mixes every level. For each unit, read it and then queue every unit in its list of subordinates, breadth first. Only armies, fleets and air units count (told apart by class); anything else is skipped. A unit met twice is read once. At most 20000 units are read; the rest are only counted as left out. (source)

*Read per unit:* name; id; command level; branch (Land, Air, Naval); the percentage of supplies and of fuel it received (tenths of a percent); dig-in level (thousandths); combined arms bonus (tenths of a percent); combat cooldown (hours, thousandths); three order flags - upgrade priority, upgrades active, reinforcements active; the number of regiments (brigades, ships, wings) it holds itself (a count below 0 or above 1000 reads as 0); for a unit with regiments, its daily supply and fuel consumption (thousandths), asked of the game's own routine for it - the figure the game's unit tooltip shows, which per the code comments is the regiments' base consumption scaled by remaining strength, the country's supply consumption modifier and the army group leader's skill; its leader's name, skill and maximum skill; and the province it stands in, with its id. A unit above division level holds no regiments and so has no consumption of its own. (source, comment)

*Leaders.* The game puts a placeholder named "(no leader)" on an unled unit, so a unit "has a leader" only if its leader's name does not contain that text. A unit's leader is "missing" when it has none - except a division with exactly one regiment, which cannot be given a commander and so is not missing one. (source)

*The tree.* A unit's parent is the unit its own "higher unit" link points to, if that unit was read and is not itself; otherwise the unit in whose subordinate list it was found; otherwise it has none and is a top level formation. Top level formations, and the children of every unit, are sorted by name, ignoring case for ASCII letters, a shorter name before a longer one that starts with it, and by unit id where names are equal. (source)

*Totals.* For the whole country: the number of land, air and naval units; regiments; supply and fuel consumption summed; units whose leader is missing; and the plain average of the supply percentage and of the fuel percentage over all units (integer division; every unit counts the same whatever its size). For each unit, over everything below it and not counting itself: land, air and naval units; regiments; consumption; units with a missing leader; the number of units; how many levels deep; and the same two averages over the units below. (source)

*Regiments* are read separately, for one unit at a time: each regiment's own name, its type key as the mod's unit files spell it (for example `artillery_brigade`), its strength and its organisation (thousandths). Strength as shown is the raw value divided by 10 for a land unit and by 1000 for air and naval. (source)

*Names for display.* Command levels: for land, "Theatre", "Army Group", "Army", "Corps", "Division", "Navy" for the level the game numbers after division, and "Unit" for any other; every naval unit is "Fleet" and every air unit "Wing" whatever its level. A unit's kind is the branch name and the level name, for example "Land Corps", "Naval Fleet", "Air Wing". (source)

*Failure texts:* "no country selected", "this country has no units". (source)

**Inputs a mod gives it** - None.

**When it applies** - Only meaningful with a game running; the pages ask for it only when they have a selected country.

**Multiplayer and saves** - Read only and local. It reads the true state of whichever country is selected, including a foreign one: there is no intelligence or fog of war filter anywhere in it.

**Where the player sees it** - Through the two pages below.

### OOB Browser page

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`).

**What the original does without it** - Nothing: this is new. It is separate from the game's own order of battle browser and does not change it.

**What the feature does** - Tab title `OOB Browser`, group `Inspector`, order 15. It shows the selected country's order of battle as a tree, with one unit's details beside it. While this page has the keyboard, the arrow keys and W, A, S, D belong to its tree, so the dock's tabs cannot be stepped with them. (source)

*Reading.* The tree is read whole: when "Refresh" is pressed; whenever the selected country's tag differs from the one last read (so also the first time a country is known); and, with the "Auto" checkbox ticked (off by default; hover text "Re-reads every five seconds. Reading a whole order of battle is thousands of small reads, so this is off by default."), every 5 seconds. The selection is kept across a refresh by the unit itself, not by its position. (source)

*Top of the page.* "Refresh", "Auto", the selected tag dimmed. If there is nothing to show, the reason, or "Press Refresh to read the order of battle." Otherwise "N units: L land, A air, V naval, in R regiments"; if the cap was hit, in the Warning colour, "Stopped after N units; the rest were not read."; then "Expand all", "Collapse all" (each acts once, on every node) and a text box, 200 wide, with the hint "filter by name". (source)

*The tree (left half; the divider between the halves can be dragged).* One node per unit, labelled with its name or "(unnamed)", children under their parent, all collapsed at first. A node opens on its arrow or on a double click; a single click selects the unit. A unit whose leader is missing is drawn in the Error colour; a unit that only has such a unit somewhere below it, in the ErrorDim colour. After the name, where anything is below it, the dimmed count of units below in brackets, whose hover text is "L land, A air, V naval below", with a second line "N of them without a commander" when N is above 0. The filter keeps a unit if its name contains the text (ASCII case ignored) or anything below it does, so the path to a match stays visible; non-matching ancestors on the path are still shown. (source)

*Keys while the tree has focus (and the filter box is not being typed in).* Down or S: next visible node. Up or W: previous. Right or D: open a closed formation, or step to the next visible node if it is already open. Left or A: close an open formation, or go to its parent if it is closed or has no children. With nothing selected the first key selects the top node. The view scrolls to keep the selection on screen. While the tree has focus it claims the keyboard, so the game's own hotkeys (and map scrolling) do not fire. (source)

*Details (right half).* With nothing selected: "Select a unit on the left." Otherwise a heading with the unit's name and two small buttons (source):

- "Copy" - puts the details on the clipboard as text (below). Hover text: "Puts this unit's details, and its regiments, on the clipboard as text".
- "Move to" - centres the game's map on the province the unit is in, by calling the same game routine as the location button on the game's unit panel; disabled when the unit is in no province. Hover text: "Moves the map to where this unit is, the way the location button on the unit panel does." or "This unit is not in a province." It does not select the unit in the game and changes nothing but the local camera.

Then a two column table of rows, in this order (source):

| label | value |
| --- | --- |
| Kind | branch and level name |
| Id | the unit's id |
| Commander | "<leader name> (skill S of M)" (a "?" for an empty name), or "none" when the unit has no leader object at all |
| Province | "<name> (<id>)", or the id alone when there is no name; the row is left out when the unit is in no province. The name is asked of Lua (`BiceLibGui.Oob.ProvinceName`) once when the selection changes |
| Supply | received supply percentage, whole percent |
| Fuel | received fuel percentage, whole percent |
| Supply used | daily supply consumption, two decimals - only for a unit with regiments |
| Fuel used | daily fuel consumption, two decimals - only for a unit with regiments |
| Dug in | dig-in level, one decimal |
| Combined arms | the bonus, whole percent |
| Combat cooldown | "N hours", whole - only when above 0 |
| Orders | any of the words "priority", "reinforcing", "upgrading" that apply, in that order, separated by spaces; "-" if none |

Then "Below this unit": either "Nothing - this is the bottom of the tree." or the lines "L land, A air, V naval"; "N subordinate formations, D levels deep" (N the direct children); "R regiments below"; "N without a commander" (Error colour when above 0, otherwise the Strong colour); "Supply X% average, fuel Y% average" (hover: "Averaged over the N units below this one, each counting the same whatever its size."); "Consumes X supply, Y fuel" - everything below plus the unit itself, two decimals (hover: "What the game itself works out for each unit, so the leader and country effects are included - not the sum of the unit types' base figures.").

Then "Regiments": "None of its own.", or a scrolling table with columns "Regiment" (its name, or "(unnamed)"), "Strength" (one decimal, scaled by branch as above) and "Org" (organisation, one decimal), in the order the unit holds them, followed by the dimmed line "Strength and organisation as the game displays them." The regiments are read when the selection changes. (source)

*Copy format.* Lines end with a carriage return and line feed. First the unit's name; then each table row as two spaces, the label padded to 16 characters, a space and the value; then, if the unit has children, an empty line, "Below this unit" and the rows "Units" ("L land, A air, V naval"), "Formations" ("N, D levels deep"), "Regiments", "No commander", "Average" ("X% supply, Y% fuel"), "Consumes" ("X supply, Y fuel") in the same layout; then, if it has regiments, an empty line, "Regiments" and one line each: two spaces, the name padded to 40, the strength in a width of 6 with one decimal, " strength", the organisation likewise, " org". Nothing is written to a file. (source)

**Inputs a mod gives it** - `BiceLibGui.Oob.ProvinceName(provinceId)`: `{ available = true, name = <text or ""> }`, from the mod's localisation key `PROV` followed by the id; `{ available = false, reason = "not a province id" }` for a non-number. (source)

**When it applies** - With a game running and a country selected.

**Multiplayer and saves** - Local and read only; "Move to" moves only the local camera and posts no command, so it is safe in multiplayer. Nothing is saved. As the read has no intelligence filter, the page shows a foreign country's full order of battle, supply state and leaders if that country is selected.

**Where the player sees it** - The `OOB Browser` tab of the overlay's Inspector window.

### OOB Report page

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`).

**What the original does without it** - Nothing: this is new. The game gives no count of a country's units by level or by type.

**What the feature does** - Tab title `OOB Report`, group `Inspector`, order 16. The same order of battle as the browser, counted instead of walked; it reads its own copy. (source)

*Reading.* "Refresh" reads; so does a change of the selected country's tag (including the first time one is known); with "Auto" ticked (off by default, same hover text as the browser's) it reads again every 5 seconds once a first read has happened. Before any read the page says "Press Refresh to read the order of battle."; if the read gave nothing, the reason. A read also walks every unit's regiments to count them by type, which the browser never does. Top line: "Refresh", "Auto", the tag dimmed, and after a read a "Copy" button (hover: "Puts the whole report on the clipboard as text"). (source)

*Totals* (left of a two part row): "N units: L land, A air, V naval"; "R regiments across T formations that report to nobody" (T the number of top level formations); "N units without a commander" (Error colour when above 0, otherwise Strong); "Supply X% average, fuel Y% average" (hover: "Averaged over every unit, each counting the same whatever its size."); "Consumes X supply and Y fuel a day", two decimals (hover: "Asked of the game for each unit rather than added up from the unit types, so the leader and country effects are in it - the same figure the game's own tooltip shows."). (source)

*By kind* (right of that row): a table "Kind", "Units", "Regiments" with one row per kind of unit present (branch and level name), counting the units of that kind and the regiments they hold themselves (a dimmed "-" for none). Rows run down the chain of command: land kinds by level from theatre to division, then air, then naval, then anything unknown; equal ranks by the kind's text. (source)

*Top level formations:* a table eight rows tall that scrolls, with a fixed header: "Formation" (name; hover shows its kind), "Land", "Air", "Naval" (units below it, not counting itself), "Regiments" (below it plus its own), "Supply" and "Fuel" (consumption below it plus its own, two decimals), in the tree's order (by name). Under it: "Counts below a formation exclude the formation itself, so a theatre's land count is the units under its command rather than a count that includes it." (source)

*By type:* one row per type of regiment and branch (a type appearing in two branches gives two rows), with how many the country has, most numerous first and by key where counts are equal. A regiment whose type could not be read is not counted. Above the table: "Show" and the radio buttons "All", "Land", "Air", "Naval", which filter this table only, and the dimmed "S of T types". If no type could be counted at all: "No regiment named a type it could be counted under."; if the filter leaves none: "This country has no <branch> regiments." Columns "Type" and "Count"; the type is shown as "<localised name> [<key>]", or the key alone where the mod has no name for it; hover shows the branch. The table takes the rest of the window. (source)

Type names are asked of the mod's Lua in one call per read, only for keys not asked before; answers (empty ones too) are remembered until the game exits. (source)

*Copy format* (lines end with carriage return and line feed): "Order of battle - TAG", an empty line, "N units: L land, A air, V naval", "R regiments in T formations that report to nobody", "N units without a commander", "X% supply, Y% fuel on average", "consumes X supply and Y fuel a day", an empty line; "By kind" and per row two spaces, the kind padded to 24, the unit count in a width of 5, " units, ", the regiment count in a width of 5, " regiments"; an empty line, "Top level formations" and per row two spaces, the name padded to 40, then "%4d land %4d air %4d naval %5d regiments %8.2f supply %8.2f fuel"; an empty line, "By type" (or "By type (<branch> only)" when filtered) and per shown row two spaces, the display text padded to 48 and the count in a width of 5. The clipboard only; no file is written. (source)

**Inputs a mod gives it** - `BiceLibGui.Oob.TypeNames(joinedKeys)`: the type keys joined by semicolons; answers `{ available = true, names = { ... } }`, one entry per key in the order asked, the mod's localisation text for the key itself (no prefix) or an empty string. (source)

**When it applies** - With a game running and a country selected.

**Multiplayer and saves** - Local and read only; nothing saved or posted. No intelligence filter, as for the browser.

**Where the player sees it** - The `OOB Report` tab of the overlay's Inspector window.

### Unit Inspector page

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`); no hook is installed for it.

**What the original does without it** - Nothing: this is new.

**What the feature does** - Tab title `Unit Inspector`, group `Inspector`, order 10. It lists whatever the player currently has selected in the game (the in-game screen's own selection list) and, for units, a table of stats and a table of terrain modifiers. It reads the selection again every 250 milliseconds while the page is drawn, directly from the game, without Lua. It is read only. (source)

*Without a game:* "CIngameIdler: not found" and "The in game screen only exists once a session is running. Load or start a game and this fills in on its own." (source)

*With a game:* a dimmed line giving the memory address of the in-game screen object (a developer's aid with no meaning for a rebuild), then "Nothing selected." or "N selected", then one collapsible block per selected thing, at most 256, the first open by default. A block's heading is "[Type] name": Type is "Army", "Navy", "Air", "Province" or "Unknown" by the class of the selected object; the name is the unit's name, or "(unnamed)" - a province or unknown thing always shows "(unnamed)". Inside: a dimmed line with the object's memory address (the same kind of aid); for anything but a unit, "No details for this entity type."; for a unit, the two tables. (source)

*The stat table* has columns "Stat" and "Value", one row per stat that applies to the unit's branch, in the order below; the value is printed with two decimals followed by its unit text. The figures are read from the unit's own definition record. According to a code comment, checked against a live game, that record is not the shared unit type but a per-unit aggregate - its strength, attacks, consumption, cost and defensiveness the sums over the unit's regiments, its speed that of the slowest - with each regiment's technology levels already in it. (source for the list; comment for the aggregate)

| stat | shown for | scale and unit |
| --- | --- | --- |
| max_strength | all | land: raw divided by 10; naval and air: thousandths |
| max_organisation | all | thousandths |
| morale | all | raw divided by 10, "%" |
| manpower | all | thousandths (the manpower build cost) |
| officers | all | thousandths |
| max_speed | all | thousandths, " kph" |
| build_cost_ic | all | thousandths |
| build_time | all | thousandths, " days" |
| completion_size | all | thousandths |
| supply_consumption | all | thousandths |
| fuel_consumption | all | thousandths |
| air_defence | all | thousandths |
| air_attack | all | thousandths |
| radio_strength | naval, air | thousandths |
| soft_attack | land, air | thousandths |
| hard_attack | land, air | thousandths |
| air_detection | naval, air | thousandths |
| transport_capacity | naval, air | thousandths |
| sea_attack | naval, air | thousandths |
| width | land | thousandths |
| weight | land | thousandths |
| defensiveness | land | thousandths |
| toughness | land | thousandths |
| softness | land | raw divided by 10, "%" |
| armor | land | thousandths |
| suppression | land | thousandths |
| piercing_attack | land | thousandths |
| range | naval, air | thousandths, " km" |
| firing_distance | naval | thousandths, " km" |
| surface_detection | naval, air | thousandths |
| visibility | naval | thousandths |
| sea_defence | naval | thousandths |
| convoy_attack | naval | thousandths |
| sub_attack | naval | thousandths |
| sub_detection | naval | thousandths |
| carrier_size | naval | thousandths |
| shore_bombardment | naval | thousandths |
| hull | naval | thousandths |
| positioning | naval | thousandths |
| strategic_attack | air | thousandths |
| surface_defence | air | thousandths |

Under the stat table, in the Warning colour: "Base values for the unit type.", with the hover text "Per sub unit, and before the effects the game applies: leader traits, the commanders above the unit, national modifiers, terrain, and how much strength is left." / blank line / "For what a whole unit actually consumes, the OOB Browser asks the game itself and matches its tooltip." (source)

*Terrain modifiers* - a collapsed section "Terrain modifiers", for armies and fleets only (an air unit has none). Columns "Terrain", "Att", "Def", "Move", "Speed", "Attr". One row per terrain the map defines, in the map's order: an army gets the land terrains, a fleet the water terrains. (source)

- Att, Def and Attr are the unit's own modifier for that terrain plus the terrain's own attack, defence and attrition value from the map's terrain file; Move is the unit's own movement modifier for the terrain alone. All are thousandths. Att, Def and Move print as percent with one decimal (raw divided by 10); Attr prints as the raw value divided by 1000 with two decimals and a percent sign.
- Speed is what the unit moves at there: max_speed times (1000 plus the movement modifier) divided by 1000, integer division, not below 0, printed in kph with two decimals. The terrain's own `movement_cost` plays no part - per a code comment, the game parses that field and never uses it. (source, comment)
- After the terrains come up to four dimmed rows for the unit file's `night`, `fort`, `river` and `amphibious` blocks - for an army all four, for a fleet only `night` - each the unit's own modifiers with nothing added and a speed worked out the same way. A block whose four numbers are all zero is left out.

**Inputs a mod gives it** - None directly; the stat names are those of the unit files, and the terrain names and values those of the map's terrain file as the game loaded them.

**When it applies** - Only while a game is on screen; it follows a game being loaded or left by itself.

**Multiplayer and saves** - Local and read only. It shows what is selected, and the game lets a player select only what it lets them select.

**Where the player sees it** - The `Unit Inspector` tab of the overlay's Inspector window.

### Province Buildings page

Kind: interface
Switch: on with the overlay (`BiceLib.Overlay.enable`, i.e. `G_ImguiUtilityEnabled`); no hook is installed for it.

**What the original does without it** - Nothing: this is new.

**What the feature does** - Tab title `Province Buildings`, group `Inspector`, order 50. For a building chosen from a list: every province the selected country controls, with the building's level there, and for a province chosen from that list its production figures and local modifiers. It is read only: nothing can be built, changed or queued from it. All its data comes through the mod's Lua. (source)

*Refreshing.* There is no timer. The building list is fetched once, the first time the page is drawn (if that fails, for example at the main menu, the reason stays on the page until "Refresh" is pressed). The province list is fetched when a building is picked, the details when a province is picked. "Refresh" fetches all three again. A change of the selected country does not by itself refresh anything. (source)

*Top line:* "Refresh"; the selected tag dimmed, or "no country"; and a drop-down, 120 wide, with "Name" and "Level" (default "Level") that re-sorts the province list and can also be stepped with the mouse wheel. (source)

*Three panes, with draggable dividers:* (source)

1. Buildings (220 wide at first): a filterable, arrow-key list of every building, each as "<localised name> [<key>]", or "[<key>]" where there is no localisation, sorted by that text ignoring case. Picking one clears the other two panes and fetches its provinces.
2. Provinces (260 wide at first): "Select a building.", or an error text, or "N provinces" above a filterable list. Each entry reads "<level> - <name>[ (occupied)] [<province id>]": the level as a whole number (cut, not rounded), the province's localised name or its id where it has none, and " (occupied)" where the country controls the province without owning it. Order: provinces the country owns first, then occupied ones; within each, by level, highest first, when the sort is "Level"; then by name, ignoring case.
3. Details: "Select a province.", or an error text, or "Province <id>", then "Base production" with a two column table and "Local modifiers" with another (each "(none)" if empty), and the line "Base values only. These modifiers are local; national and global ones are not included here."

*What the figures are.* (source)

- The level is the building's maximum (built) level in the province, as the game's Lua API reports it - not the current level after damage.
- "Base production" rows, in this order, each raw thousandths divided by 1000 and printed with two decimals: "Energy", "Metal", "Rares", "Oil" (what the province currently produces of each good), "Leadership", "Manpower" (the province's own figures), "Supply pool", "Fuel pool" (supplies and fuel lying in the province).
- "Local modifiers" rows, each raw divided by 10 and printed with two decimals and a percent sign: "Local energy", "Local metal", "Local rares", "Local oil", "Local IC", "Local leadership" - the province's own modifier values of those kinds.

**Inputs a mod gives it** - Three Lua functions under `BiceLibGui.ProvinceBuildings` (source):

- `Collect()` - `{ available = true, buildings = { "<name> [<key>]", ... } }`. The mod builds the list by parsing its own `common/buildings.txt` (found under `tfh\mod\BlackICE <version>\`, relative to the game's folder) for the keys and looking each up in its merged localisation table.
- `Provinces(choice)` - takes the list entry as shown, extracts the key between the first square brackets, and answers `{ available = true, tag, key, provinces = { { id = <text>, name = <text>, level = <number>, occupied = <boolean> }, ... } }`; unavailable with "No country selected" without a selected country. It uses the game's Lua API: `CBuildingDataBase.GetBuilding(key)`, the country's `GetControlledProvinces()`, `CCurrentGameState.GetProvince(id)`, `province:GetBuilding(building):GetMax():Get()` for the level, and `province:GetOwner()` compared with the country's tag for `occupied`. A province is listed when its level is 0 or more. Names come from the localisation key `PROV` followed by the id.
- `Details(provinceId)` - `{ available = true, id, values = { { label, value }, ... }, modifiers = { { label, value }, ... } }` with the labels and formatted texts above; unavailable with "BiceLib.dll was not loaded" or "No details for province <id>". It gets its raw numbers from BiceLib's own Lua function `BiceLib.GameInfo.getProvinceDetails(provinceId)`, which answers nil for an id the map does not have and otherwise a table with `id`, `supply_pool`, `fuel_pool`, `oil`, `metal`, `energy`, `rares`, `manpower`, `leadership` (all thousandths) and `modifiers` holding `local_ic`, `local_oil`, `local_energy`, `local_metal`, `local_rares`, `local_leadership` (tenths of a percent).

**When it applies** - With a game running; the Lua bridge refuses the calls otherwise and the page shows the reason.

**Multiplayer and saves** - Local and read only; posts nothing and saves nothing. It lists the provinces of whichever country is selected, and the details call answers for any province id without an intelligence test.

**Where the player sees it** - The `Province Buildings` tab of the overlay's Inspector window.

## Part 8 - Tooling

### Terms used in this part

Three terms are used throughout this part.

- **Beside the DLL** means the folder `BiceLib.dll` itself was loaded from, found from the DLL's own module handle and not from the working directory or the game's folder. In a deployed mod that is the mod's `script` folder. Every file this part reads or writes lives there, with two exceptions that are named where they occur: the crash save (written by the game's own writer into the game's own save-game folder) and the combat-refresh probe's report (the user's temporary folder). Nothing here uses the working directory. (source)
- **The debug console** is the process's standard output, visible only in the console window `BiceLib.startConsole()` opens (the mod's `script/bicelib_lua.lua` has that call commented out as committed; the Utility Options page has a button for it). Lines are prefixed `[INFO] ` or `[ERROR] `. Several tools below have no other output. (source)
- **The frame hook** is BiceLib's replacement for the Direct3D device's present call, installed by `BiceLib.Overlay.enable()`. It runs once per presented frame, from the first frame of the main menu onward, whether or not the overlay is showing. Everything below that says "once a frame" hangs on it, and none of it runs when the overlay is not enabled. As the mod is committed, `G_ImguiUtilityEnabled = true` in `script/utility_settings.lua`, so the overlay is enabled and all of it runs in a player's game; with that setting false none of the crash reporting, crash saving, watching or Debug pages exists. (source)

Nothing in this part is localised: every text is a fixed English string in the DLL or in the mod's Lua, and no localisation key is looked up. (source)

### Always on: reads of game memory are guarded and fail soft

Kind: infrastructure
Switch: always on once the DLL is loaded

**What the original does without it** - nothing: this is new.

**What the feature does** - Every read BiceLib makes of a game structure that might not be what it assumes goes through one helper that asks the operating system to copy the bytes (a cross-process style read of its own process) instead of dereferencing the pointer. A null address, a null destination, a zero size, an unmapped or protected page, or a short read all return "could not read" and the caller takes a fallback value (zero, an empty list, "no session") instead of faulting. A companion helper returns the value or a caller-given fallback. Scans of the process's memory for a known pointer value (used to find a singleton when no direct route exists) walk only committed, private, readable, non-guard regions, read a page at a time through the same guarded copy, test only 4-byte-aligned positions, and skip any page that went away since it was listed. (source)

The rule a reimplementation should take from it is behavioural: a tool that inspects the running game must never be able to crash it, so a failed lookup shows as a missing value, a `-` in a csv or a refusal with a reason, never as an exception. (source)

**When it applies** - always; no switch.

**Multiplayer and saves** - reads only; no state.

### Crash report (`crash_reports/BiceLibCrash_NNN.txt` and `.dmp`)

Kind: tooling
Switch: on with the overlay (`BiceLib.Overlay.enable()`), armed as that call's first step; a test report can be written from Options at any time

**What the original does without it** - An unhandled exception goes to whatever top-level exception filter the game and its C runtime had installed; the player is left with, at most, a Windows error dialog, and a local dump only if they had set Windows up for one beforehand. (comment)

**What the feature does**

*Arming.* `BiceLib.Overlay.enable()` arms the reporter before anything else it does - before the pure-call handler and before the overlay's Direct3D hooks - so a crash while installing the overlay is already caught. Arming happens once per process (later calls do nothing) and does three things: (source)

1. Builds the report folder path, `crash_reports\` beside the DLL, creates the folder, and works out the next report number: starting at 1, the first number N for which `BiceLibCrash_NNN.txt` does not exist, capped at 999. This is done once, at arming, so reports left by earlier sessions are never overwritten.
2. Loads `dbghelp.dll` by name and looks up its minidump writer. If the library or the function is missing, text reports are still written and dumps are silently skipped.
3. Installs a process-wide **unhandled exception filter** and remembers the filter that was installed before it. (It is the top-level filter, not a vectored handler: it sees only exceptions nothing else handled, as the process is about to die.)

Both the paths and the dump function are resolved at arming so that writing a report later needs no memory allocation and no library load. (source)

*What triggers a report.* Three things: (source)

1. **Any unhandled exception anywhere in the process**, of any class - access violations, C++ exceptions, heap corruption, stack overflow and so on, whether the fault is in BiceLib, the game or another DLL. The filter writes a report with the origin text `the unhandled exception filter`, then calls the previously installed filter and returns its answer; if there was none it answers "keep searching". So the game's own crash handling still happens afterwards and this only adds a report. No dialog is shown by BiceLib and the process is not kept alive.
2. **An exception inside the overlay's own drawing.** The whole per-frame overlay draw runs inside a structured exception guard. When it catches anything it writes a report with the origin text `the overlay`, marks the overlay as failed for the rest of the process (it is hidden and never drawn again; the toggle key no longer brings it back), closes the Direct3D scene the overlay may have left open so the game's next frame is not broken, and prints `[ERROR] The overlay crashed and has been switched off. The report is <path>` to the debug console. The game carries on. The once-a-frame work outside the draw (warm-up, the watches, the out-of-memory watch) continues.
3. **The test button** (below): raises a breakpoint exception on purpose, catches it at once, and writes a report with the origin text `a test, not a crash`. It goes through exactly the same writing code as a real crash; nothing is switched off.

*What a report is.* A numbered pair of files in `crash_reports\` beside the DLL: `BiceLibCrash_NNN.txt` and `BiceLibCrash_NNN.dmp`, NNN being three digits with leading zeros. Each report takes the next number and the number then advances, so one crash that causes another leaves both and the lowest number is the first. At 999 the number stops advancing and later reports overwrite pair 999. A report is skipped entirely if the folder could not be worked out or the exception record is missing. (source)

*The text file* (written whole, replacing any file of that name; lines end in carriage return and line feed; at most about 4000 characters) holds, in this order: (source)

- an empty line, then a rule of equals signs;
- ` BiceLib crash report <k>, caught in <origin>` - k counts the reports written in this session from 1 (it is not the file number); origin is one of the three texts above;
- ` <local date as YYYY-MM-DD> <local time as HH:MM:SS>   BiceLib built <the DLL's build date> <build time>`;
- a second rule of equals signs;
- ` exception   <name> (<the exception code, eight hexadecimal digits>)` - the name is one of `ACCESS_VIOLATION`, `ARRAY_BOUNDS_EXCEEDED`, `DATATYPE_MISALIGNMENT`, `FLT_DIVIDE_BY_ZERO`, `ILLEGAL_INSTRUCTION`, `INT_DIVIDE_BY_ZERO`, `PRIV_INSTRUCTION`, `STACK_OVERFLOW`, `IN_PAGE_ERROR`, `BREAKPOINT`, `SINGLE_STEP`, `INVALID_HANDLE`, `NONCONTINUABLE`, `FLT_INVALID_OPERATION`, `FLT_OVERFLOW`, `FLT_STACK_CHECK`, `INT_OVERFLOW`, `HEAP_CORRUPTION`, `a C++ exception`, or `unknown`;
- ` at          <the faulting instruction's address>`, followed when the address lies inside a loaded module by `  =  <module file name>+<distance into the module>` - the pair a symbol lookup needs;
- for an access violation only: ` while      reading|writing|executing <the address that was touched>`;
- ` registers  ` and the nine general 32-bit registers of the faulting thread (instruction pointer, stack pointer, frame pointer, then the six others) over three lines, when a thread context was supplied;
- ` overlay    open|closed, frames started <n>, finished <n>` - whether the overlay was showing, and how many guarded overlay draws had begun and completed this session (started one more than finished means the crash was inside a draw);
- ` last page  <page title>` or `(not inside a page)` - the title of the overlay page whose draw was running. The page registry notes each open page's title just before drawing it and clears the note once all pages are done, and the note is cleared at the start and end of every guarded draw, so a crash in ImGui's own rendering or outside the overlay is not blamed on a page;
- ` BiceLib    <full path of the DLL> loaded at <its load address>`;
- ` thread     <thread id>`, with `  <-- the fault is inside BiceLib` appended when the faulting module's file name is `BiceLib.dll` (compared without case).

The text holds **no** call stack, no module list, no game date, no country and no name of a Lua function: the stack and the modules are what the dump is for, and nothing of the game's state is read while crashing. (source)

*The dump file* is a Windows minidump of the current process written through `dbghelp.dll`: the normal minidump content (every thread's stack and context, the module list, the exception) plus per-thread information and the list of unloaded modules, with the exception attached to the crashing thread. No heap is included, so it is a few megabytes. It is skipped when dbghelp was not found or the file cannot be created. (source)

*The player-facing controls* are on the overlay's Options page, under a separator **Crash reports**: (source)

- wrapped text: `If BiceLib crashes, it writes what happened into a numbered pair of files instead of leaving you to find a Windows dump. Send the whole folder, or the lowest numbered pair in it - the first crash is usually the one that caused the rest.`
- button **Write a test report** - writes the test report; the page's status line then reads `Test report written`. Tooltip: `Writes a report for an exception raised on purpose, so the file can be found and sent before a real crash happens. Nothing is broken by pressing this.`
- button **Copy folder path** - puts the folder's path on the clipboard; status `Folder path copied`.
- the folder's path in dimmed text; and, once at least one report was written this session, `<k> written this session, the last being <path of the newest text file>`.

**Inputs a mod gives it** - none. The mod's deploy script lists `crash_reports` among the things it preserves in the `script` folder when it clears and re-copies that folder. (source)

**When it applies** - from `BiceLib.Overlay.enable()` to the end of the process, at the main menu as much as in a game. It cannot be switched off again. Without the overlay enabled it is never armed and no report is ever written. (source)

**Multiplayer and saves** - local to the machine; nothing in a savegame; no game state is read or changed.

**Where the player sees it** - the files in `crash_reports`, the Options page block, and one console line when the overlay itself crashed.

### Crash save ("crashsave", then a message box, then the game closes)

Kind: tooling
Switch: no switch of its own; used by the out-of-memory watch and by the pure-call handler (both on with the overlay), and by two test buttons on Debug > Memory

**What the original does without it** - When the process can no longer be given memory, or a pure virtual function is called, the game dies where it stands and everything since the last save is lost. (comment)

**What the feature does** - It is the shared "the game is finished: save it, say why, close it" routine. It runs **at most once per process**: the first caller wins and every later request is ignored. It has two ways in. (source)

*From the frame loop* (used by the out-of-memory watch, where there will be a next frame):

1. Record the reason text, the free address space at that moment, and the calling thread; append a line to the log (below).
2. If no game is running (there is no in-game screen object), finish at once as a failure with the text `no game is running, so there was nothing to save`.
3. Claim the name of the next save for the "crash" kind of BiceLib's extra autosaves (installing and activating the autosave hooks if they were not already; if they cannot be installed the save still happens under the game's own autosave names), then raise the game's own "an autosave is requested" flag directly. The game's own autosave writer, which looks at that flag every frame, does the saving on its own thread in its own time.
4. Each following frame, read the flag back through a guarded read. Unreadable: failure, `the game state could not be read`. Once the flag is seen cleared, wait two more frames, then finish as a success with the text `written after <n> frames` (n counted from the request). If the flag is still up after more than 600 frames: failure, `the game never wrote it`.

*On the spot* (used by the pure-call handler, which cannot return and has no next frame):

1. If a crash save is already under way: when the caller is the very thread that is saving, end the process immediately (the save above it on the stack can never finish); when it is another thread, wait forever in 100 ms sleeps - the saving thread shows its message box and ends the process itself.
2. Record reason, optional caveat paragraph, free space and thread; log. No game running: failure as above.
3. Check that the game's autosave writer is the code this build of the DLL expects; if not: failure, `the game's save writer is not what this build expects`.
4. Claim the crash name as above, raise both the request flag and the writer's own one-frame-delay flag, and call the game's autosave writer directly on the calling thread, so the file is written before the call returns.
5. If the request flag is not cleared afterwards (or cannot be read): failure, `the game's writer declined it`. Otherwise success, `written on the spot`.

*The file.* The game's own autosave writer writes it, into the game's own save-game folder, under the name `crashsave.hoi3`, using the game's own three-file rotation applied to a set of its own: before writing, if `crashsave.hoi3` and `oldcrashsave.hoi3` both exist, `oldercrashsave.hoi3` is deleted, `oldcrashsave.hoi3` becomes `oldercrashsave.hoi3` and `crashsave.hoi3` becomes `oldcrashsave.hoi3`. A crash save therefore never pushes out one of the game's own autosaves or one of BiceLib's monthly or timed ones. The base name `crashsave` is fixed (the monthly and timed names are settable; this one is not). The original's rotation is described in `reversing/findings/FINDINGS-autosave.md`. (source, comment for the rotation's steps)

*Finishing.* Success or failure, the routine records the free address space again, appends a second log line, shows one modal Windows message box owned by the game window - title `BlackICE`, error icon, a single OK button, topmost and brought to the foreground - and when it is dismissed **terminates the process immediately** with exit code 0 (no orderly shutdown, on purpose: every destructor on the way out of a broken process is another chance to fault). (source)

The message box text on success, where `<reason>` is the caller's text and `<caveat>` is the caller's optional paragraph or nothing:

    Hearts of Iron 3 <reason> and cannot carry on.

    Your game was saved first, as "crashsave" - load it from the save game list as usual.
    <caveat>
    The game will close when you press OK.

and on failure, where `<why>` is the failure text from the steps above:

    Hearts of Iron 3 <reason> and cannot carry on.

    The save could not be written: <why>.

    The game will close when you press OK.

`<reason>` is `has run out of memory` from the out-of-memory watch, `hit an internal error (a pure virtual call)` from the pure-call handler, and `has stopped working` if a caller gave none. (source)

*The log.* `OutOfMemory.log` beside the DLL, opened on first use for appending (never truncated, shared so it can be read or deleted while the game runs) and flushed after every line. The crash save writes: (source)

- when asked: an empty line, then `--- crash save asked for: the game <reason>, <n> KB free ---`
- when finished: `--- crash save (<reason>): <outcome text>, <n> KB free before, <n> KB after ---`

"Free" here is the total free virtual address space of the process, in units of 1024 bytes.

**Inputs a mod gives it** - none.

**When it applies** - only when one of its callers fires. Its per-frame half is pumped from the frame hook, so the frame-loop path needs the overlay enabled. At the main menu there is nothing to save: the failure message is shown and the game is still closed. (source)

**Multiplayer and saves** - local. It writes an ordinary savegame through the game's own writer and then ends this machine's process; it posts no command and changes no simulation state. In the pure-call case the saved state may be inconsistent, which the message says. (source)

**Where the player sees it** - the message box; the `crashsave` entry in the load-game list; the "Last attempt" line on Debug > Memory (which, since the process ends, is only ever seen while the box is up).

### Out-of-memory watch

Kind: tooling
Switch: on with the overlay (`BiceLib.Overlay.enable()`); a checkbox on Debug > Memory turns the reaction off and on, remembered in `BiceLibSettings.ini`

**What the original does without it** - The game is a 32-bit process and dies when it can no longer be given a large enough single block of address space, long before the machine is out of memory. It dies wherever it happens to be, without its own allocator ever reporting a refusal. Two such deaths were measured with 16 MB and 30 MB still free in total and no free block larger than 244 KB. See `reversing/findings/FINDINGS-allocator.md`. (comment)

**What the feature does** - Once per frame, from the frame hook and regardless of whether the overlay is showing: (source)

1. On first use, read the two settings (below).
2. Read the process's total free virtual address space (one system call); kept only for display.
3. If a crash save has been started by anyone, pump it (previous section) and do nothing else this frame.
4. Every 30th frame - and every frame while the last result was zero - **probe the largest block the process can still be given**: try to reserve (not commit) address space of 64 MB, then 32, 16, 8, 4, 2, 1 MB, 512 KB, 256 KB, in that order, releasing a successful reservation at once; the answer is the first size that succeeds, or 0 if even 256 KB fails. (MB and KB here are binary: 1 MB is 1,048,576 bytes.) The answer is therefore one of ten values, and reads 64 MB for anything larger. The probe runs whether or not the watch is on, so the page can always show it. "Every 30 frames" is a frame count, not a clock: twice a second at 60 frames a second.
5. If the watch is on and the probed block is **smaller than the trigger size**, fire.

Firing appends `--- out of memory: largest block <n> KB ---` to `OutOfMemory.log` and asks for a crash save from the frame loop with the reason `has run out of memory`. What follows - the save, the message box, closing the game - is the crash save's, once only. There is no warning stage, no in-game message, no pause and no autosave before the threshold: the only reaction is the save-and-close. (source)

The default trigger size is 2 MB. With the probe's fixed sizes that means: fire as soon as a 2 MB reservation fails. (source)

*Settings*, in `BiceLibSettings.ini` beside the DLL (plain `key=value` lines, written whenever a value is changed): (source)

- `outOfMemory.watch` - 1 or 0, default 1 (on).
- `outOfMemory.triggerAtKb` - the trigger size in units of 1024 bytes, default 2048; a value of zero or less is read as 1.

Both are changed from Debug > Memory (described there): a checkbox, and a number box in MB limited to 1 through 512.

*The ballast* is a test aid on the same page, not part of the watch: it reserves address space and keeps it, so the trigger can be seen firing in a minute instead of after an evening. Asked to leave L bytes free, it first releases any ballast it holds, measures the total free address space by walking the address space, then reserves blocks of the nine probe sizes, largest size first, taking as many of each size as fit while free space stays above L and the block would not cut into L, to a limit of 8192 reservations. It logs `--- ballast: <n> reservations, <n> MB held, <n> MB left free (largest block <n> KB) ---`. Nothing gives the ballast back except the release button, which frees all of it and logs `--- ballast released ---`. The amount left free is approximate, since free space includes holes too small to use. (source)

*The allocation-failure hook.* An earlier version also installed a handler into the game's own C runtime so that a refused allocation would be caught at the moment it happened, and kept a 64 MB reserve to hand to the save. Both are **removed from the source**: the handler was installed, live, and never called, because the game dies without its own allocator ever refusing anything, and the save was measured to need about 356 KB. The source keeps only the account of it (and one orphaned comment on the Memory page). Treat it as **deferred, not present**. (comment)

**Inputs a mod gives it** - none. The mod's deploy script preserves `BiceLibSettings.ini`; it does not preserve `OutOfMemory.log`. (source)

**When it applies** - every presented frame once the overlay is enabled and its drawing layer has initialised, main menu included. At the main menu a trigger has nothing to save and still closes the game with the failure message. Turning the checkbox off leaves the game to die as it would have; the probe and the display continue. (source)

**Multiplayer and saves** - local; no state in the save; no commands.

**Where the player sees it** - only through the crash save's message box, and on Debug > Memory.

### Pure-call handler

Kind: tooling
Switch: on with the overlay (`BiceLib.Overlay.enable()`), installed as that call's second step, before the Direct3D hooks

**What the original does without it** - A call to a pure virtual function - in practice an object used while half constructed or after it was destroyed - ends in the game's C runtime printing a runtime error and aborting the process. The runtime has a slot for a handler to call first; the game leaves it empty. (comment; see `reversing/findings/FINDINGS-allocator.md`, its last section)

**What the feature does** - It puts a handler of BiceLib's into the game's own runtime's pure-call handler slot. No instruction of the game is patched; one pointer-sized global of the game's runtime is written (encoded the way the runtime expects). Installation is refused, leaving everything untouched, when the game module is not loaded (`hoi3_tfh.exe is not loaded`), when the runtime's pure-call routine is not the code this build of the DLL expects (`_purecall is not what this build expects`), when the slot already holds a handler (`something already has the purecall handler` - somebody else's handler is never taken over), or when the slot cannot be written (`could not write the handler`). On success the status is `installed`. It is installed once per process. The source has a routine that puts the runtime's original empty value back (status `removed`), but nothing calls it. (source)

When a pure virtual call happens, on whatever thread, the handler: (source)

1. If a pure call is already being handled (a second one raised while saving), returns - which lets the runtime abort as it would have. This stops a recursion.
2. Otherwise calls the crash save's on-the-spot path with the reason `hit an internal error (a pure virtual call)` and this caveat paragraph for the message box: `This kind of error means part of the game was already in a broken state when the save was taken, so it cannot be guaranteed to load correctly or to be complete.` That path does not return: it saves on the faulting thread by calling the game's writer directly, shows the message box and ends the process.

Because it is a slot in the runtime and not a poll, it works on any thread and whether or not frames are being drawn. Two risks are accepted and stated in the source: the broken object may be walked by the save and fault again, and a pure call on a thread other than the game's main one leaves the main thread free to change state under the save; neither is worse than the abort that was coming. (comment)

Debug > Memory shows `Pure virtual call handler: <status>` and, while installed, a **Provoke one** button that calls the game's own pure-call routine exactly as a pure virtual slot would - a faithful test that saves and closes the game. (source)

**Inputs a mod gives it** - none.

**When it applies** - from `BiceLib.Overlay.enable()` to the end of the process; cannot be switched off from the interface. Not installed when the overlay is not enabled. (source)

**Multiplayer and saves** - local; writes a savegame through the game's own writer, then ends the process.

**Where the player sees it** - the crash save's message box.

### Diagnostics: the Lua scope marker and the render-thread record

Kind: infrastructure
Switch: always on once the DLL is loaded (the marker is compiled into four entry points); the per-frame note needs the overlay

**What the original does without it** - nothing: this is new.

**What the feature does** - It answers, by measurement, "which thread draws frames, which Lua state does that thread use, and is any other thread inside Lua while a frame is drawn". It began as a one-off check before the overlay was written and is now what the overlay's bridge into Lua relies on. (source)

*The marker.* A scope object placed at the top of four functions the game's Lua calls into the DLL: the DLL's module loader (run once for every Lua state that requires BiceLib), `BiceLib.GameInfo.getProvinceDetails`, `BiceLib.Leaders.getLeaderDetails` and `BiceLib.Inspector.getSelectedEntity`. No other exported function carries it. On entry it: (source)

- records the call against the calling thread in a table of at most 8 threads - thread id, the Lua state most recently seen on that thread, and a call count (a ninth thread is not recorded);
- adds one to a total call count;
- raises a per-thread nesting depth, and on the outermost entry adds one to the number of threads currently inside a marked call, remembering the highest that number has been.

On exit it lowers the depth and, on leaving the outermost level, the number of threads inside.

*The per-frame note.* At the top of every frame hook call it records the calling thread as "the render thread", counts the frame as "inside our own Lua call" when that thread is itself inside a marked call, and counts it as "another thread in Lua" when any other thread is inside one. (source)

*What reads it.* (source)

- The overlay's bridge into Lua: the state it calls into is "the Lua state most recently seen on the render thread", and a call is refused with the reason `not on the render thread`, `the render thread has not run Lua yet` (no marked function has run on that thread yet), or `a Lua call is already in flight` (the calling thread is inside a marked call, so the interpreter would be re-entered). Every overlay page that asks Lua for data, the Lua console and the warm-up go through this.
- The Debug > Thread Check page, which displays all of it.

It is **not** used by the crash report. The crash report's own context (the page being drawn, frames started and finished) is kept by the crash reporter itself; no Lua function name and no game date reach a report. (source)

**When it applies** - the marker from the first `require` of the DLL; the per-frame note once the overlay is enabled.

**Multiplayer and saves** - process-local counters; nothing saved; no game state read or changed.

**Where the player sees it** - Debug > Thread Check, and the "Cannot reach Lua: ..." reasons pages show.

### The Debug window

Kind: tooling
Switch: on with the overlay (`BiceLib.Overlay.enable()`)

The overlay groups its pages into dockable windows by group name; the group **Debug** holds five pages, as tabs in this order (ascending order number): **Thread Check** (10), **Memory** (20), **Lua Console** (30), **Timing** (40), **a virtual-call probe page** (60; its title names a build-specific position and is not reproduced in this file). The group only decides where a page starts on a first run; afterwards the player's saved layout wins. Each page is described in its own section below. A page's code runs only while its tab is the one showing. (source)

### Debug > Thread Check

Kind: tooling
Switch: on with the overlay

**What the original does without it** - nothing: this is new.

**What the feature does** - A read-only display of the Diagnostics record, top to bottom: (source)

- separator `Lua / render thread check`;
- `Render thread: <thread id>`;
- if no marked Lua call has been seen yet: dimmed `No Lua calls seen yet.` and the hint `Load a save, or open the old utility and hit Refresh.`, and nothing more;
- a three-column table, one row per recorded thread (at most 8): **Thread** (the id; the render thread's row is in the theme's success colour with ` (render)` appended), **lua_State** (the state's run-time address, as an identity to compare rows by), **Calls**;
- `Max threads inside Lua at once: <n>`;
- `Frames with another thread in Lua: <n>`;
- `Frames inside our own Lua call:    <n>`;
- a verdict line: in the error colour `The render thread has never run Lua - snapshot bridge needed.`; or in the success colour `The render thread runs Lua and never renders while another thread is inside Lua - direct calls look safe.`; or in the warning colour `The render thread runs Lua, but other threads are in Lua during frames. Safe only if those threads use a different lua_State (compare above).`

No controls. Refreshes every frame.

**When it applies** - main menu and in game. **Multiplayer and saves** - display only.

### Debug > Memory

Kind: tooling
Switch: on with the overlay; the texture counts start when the overlay's hooks go in

**What the original does without it** - nothing: this is new.

**What the feature does** - One scrolling page of process-memory readouts, with the controls for the crash save. Sizes are shown as whole MB (bytes divided by 1,048,576, no decimals) below 1024 MB and as GB with two decimals from there. While the page is showing, the process figures and the widget sample are refreshed every 500 ms; everything else is read every frame. Sections in order: (source)

*1. `Memory (32 bit process)`.*

- Bar **Private bytes (commit)**: the process's private commit charge against the address-space limit.
- Bar **Address space (committed + reserved)**: everything not free in the address space, against the limit.
- Each bar carries the text `<used> / <limit> (<percent>%)` and is green below 60 percent, amber from 60, red from 85.
- `Working set:` physical memory held. `Largest free block:` the largest free region found by walking the whole address space (a different measurement from the watch's probe). `Limit:` the top of the user address space as the system reports it, followed by `(large address aware)` when it is above 2 GB, else `(not large address aware)`; tooltip: a 32-bit process gets 2 GB, or 4 GB on 64-bit Windows when the executable is flagged large address aware.
- A paragraph explaining that out of memory happens when no single free block is large enough, with a tooltip that a shrinking free block cannot be recovered while the game runs.

*2. `Where the address space goes`.* A table **Kind | Committed | Reserved | Regions** with three rows, each with a tooltip: `Private (the game's own)` (everything the game allocated for itself), `Mapped (files, driver)` (file mappings and shared memory, largely the graphics driver's), `Image (DLLs)` (the executable and its DLLs; fixed). Then `Largest single private block: <size>` - the largest committed private region.

*3. `GUI widgets`* - a count of the game's own interface widgets, sampled every 500 ms while the page shows. It exists to watch for a leak in the original's interface (widgets that are created again on each rebuild and never destroyed). It is tied to this build of the executable and has no meaning elsewhere.

- If the game's interface object has not been found: dimmed `The gui object has not been found. It is resolved on the first sample, which needs the game past the main menu once.` and nothing more.
- `In use: <n> of <capacity> slots`, with a small button **Reset baseline** (forgets the history, the baseline, the peak, the "moved" mark and the previous name count).
- `Baseline <n>, peak <n>, drift <signed n>` - baseline is the count at the first sample after a reset, peak the highest since, drift the current count minus the baseline.
- A line plot of the last samples (at most 1800, newest at the right, 60 units high) captioned `<n> samples, newest at the right`; before two samples exist, `Collecting - the plot needs a few samples.`
- In the error colour, when the game's widget list has been moved to a new buffer since the baseline: `The vector has reallocated: its buffer moved since the baseline.` and a sentence that any cached widget pointer is then dangling.
- In the warning colour, when drift is positive: `<signed drift> since the baseline.` and a paragraph on what growth is expected and what is not.
- Button **Count names (walks every widget)** with the dimmed note `one pointer chase and one string per widget - not on a timer`. It walks every widget once, reading each one's interface-definition type name (capped at 63 characters), and shows `Walked <n>, <n> distinct names, <n> null slots` (a warning line if any slot was empty), then `Change is against the previous scan.` or, on a first scan, `Scan again to get a change column - one scan cannot show growth.`, then a table **Widget type | Live | Change** of the ten commonest names, most numerous first, ties by name ascending. Change is the count minus that name's count in the previous scan (a name absent before counts as all new): warning colour with a sign when positive, plain with a sign when negative, dimmed `0` when unchanged, `-` on a first scan. If the walk failed: `The walk could not read the vector.`

*4. `Lua`.*

- If no Lua state has loaded BiceLib: dimmed `No Lua state has loaded BiceLib yet.`
- `States: <n>` - the number of Lua states that have required the DLL (the DLL keeps every one; the game never closes a state) - and, when some of them are coroutines of one another, `(<m> independent, the rest are coroutines)`. Two states are the same interpreter when they share a registry.
- `Total:`, `Largest:`, `Average:` - each independent state's memory by the interpreter's own accounting (its garbage collector's byte count), summed, the largest one, and the sum divided by the number of independent states.
- A note that this covers what the interpreter allocated and only ever grows.

*5. `Textures created`* - an inventory of every Direct3D texture created through the device since the overlay's hooks were installed, by pixel format. It exists to answer whether compressed texture files stay compressed once loaded.

- If the texture-creation hook could not be installed: dimmed `CreateTexture is not hooked, so nothing is counted.` If nothing has been created: `Nothing created yet.`
- `Alive: <n> textures, <size>` with a small **Reset** button (clears the created totals; what is alive stays - tooltip says so).
- `Created: <n> textures, <size>  (<size> released since)`.
- In the warning colour, when the release hook is not in place: `Release is not hooked, so nothing ever leaves the live totals.`
- `Compressed:   <size>` `(DXT, as stored)`; `Uncompressed: <size>`; `Managed pool: <size>` with a tooltip that managed-pool textures keep a system-memory copy as well, so those bytes are spent twice.
- A table **Format | Alive | Size | Managed | Created | (unnamed)**, one row per pixel format (at most 32), largest live size first: the format's name (the common uncompressed formats by their Direct3D names, a four-character code such as DXT1 as itself, anything else as `format <number>`), live count, live bytes, live managed-pool bytes, count ever created (dimmed when equal to the live count), and a last cell reading `compressed` in the success colour for the block-compressed formats, dimmed `unsized` for a format whose size cannot be worked out, else `-`.
- A closing note: alive means the last reference has not gone; textures created before the hooks went in are missing; the overlay's own textures are included; sizes are computed, not asked of the driver.

How the inventory is kept: the hook on texture creation lets the device create the texture, reads the real number of mip levels back from the texture, and records format, pool and a computed size - for block-compressed formats, per level, (width rounded up to a multiple of 4, divided by 4) times (height likewise) times 8 or 16 bytes by format; for plain formats width times height times 1 to 4 bytes per pixel; each level half the one above down to 1 by 1; unknown formats are counted with size 0. A second hook on the texture's release removes it from the live totals when its last reference goes. A new texture arriving at an address already recorded replaces the old record. Counting is thread-safe. The hooks only observe; they change nothing about the textures. (source)

*6. `Crash save`* - the controls for the out-of-memory watch and the pure-call handler.

- `Largest block it can still get: <size>` - the watch's probe. When it is at most twice the trigger size, ` - getting close` follows in orange (red 255, green 128, blue 77). Tooltip: it is measured by asking for a block and giving it straight back, it is what the trigger watches, and the total below is not.
- Dimmed `Free in total: <size>`.
- Checkbox **Save and close the game when it runs out** - the watch's on/off setting. Tooltip: below the threshold the game is saved as "crashsave", told why in a message box, and closed; off, the game is left to die however it would have.
- Number box **Fire below this block size, MB** - the trigger size in whole MB, steps of 1 and 5, limited to 1 through 512; stored at once.
- Button **Save and close now** - fires the watch's trigger immediately, whatever the free space: the real path, message box and closing the game included.
- `Pure virtual call handler: <status>` with a tooltip describing it, and while installed a small button **Provoke one** (tooltip: it saves and closes the game; save first).
- Once any crash save has been asked for: `Last attempt: the game <reason> - <outcome> (<size> free before, <size> after)`.

*7. `Ballast - play the game to death`.*

- While nothing is held: number box **MB to leave the game** (default 50, steps 10 and 50, limited to 8 through 1024) and button **Hold everything else** (tooltip: takes the address space and keeps it so the crash save fires at whatever the game tries next; nothing gives it back except the release button; save first).
- While ballast is held: `Holding <size> in <n> reservations` and button **Release the ballast**.
- A note that every crash save is appended to `OutOfMemory.log` beside the DLL with how much room there was before and after.

**Inputs a mod gives it** - none.

**When it applies** - viewable at the main menu and in a game. The widget count needs the game to have been past the main menu once.

**Multiplayer and saves** - display only, apart from the crash-save controls, whose effects are those sections'. The ballast changes the process's address space, not the game's state.

### Debug > Lua Console

Kind: tooling
Switch: on with the overlay; the Lua half is the mod's `script/utility_imgui/Debug/imgui_console.lua`, loaded by `script/gui-imgui.lua`

**What the original does without it** - nothing: this is new. (The original's own console takes its own commands, not Lua.)

**What the feature does** - A text editor and a transcript: paste Lua, run it inside the game's own Lua state, read what it printed or returned. (source)

*How a script is run.* The page calls the mod's Lua function `BiceLibGui.Console.Run(source)` with the editor's text, through the overlay's bridge: on the render thread, in the Lua state most recently seen on that thread (the same state every overlay page's data comes from, holding the mod's globals and the game's Lua API), inside a protected call. The game is frozen until it returns. The Lua function: (source)

1. Returns an empty success for an empty string.
2. Compiles the text first with `return ` put in front of it, so a bare expression yields its value; if that does not compile, compiles the text as written. A compile error is returned as the run's error. The chunk is named `console`.
3. Runs the chunk in a **scratch environment**: a table that reads through to the real globals but keeps its own writes, so `x = 1` in one run is still there in the next without creating a global. The scratch table also offers `_G` (the real globals, for a deliberate global write) and `_SCRATCH` (itself). It persists across runs until reset.
4. Replaces the global `print` for the duration of the run with one that appends a line to the run's output - string arguments as themselves, anything else in the dump form below, arguments separated by tabs - and restores the original afterwards on both the success and the error path.
5. Installs an instruction-count hook that raises the error `stopped after 20000000 instructions - is it looping?` every 20,000,000 interpreter instructions, and removes it afterwards. (A script that catches errors itself can swallow it.)
6. Runs the chunk under a protected call with a traceback handler, timing it with the interpreter's processor clock.
7. On an error: returns the captured print output and the error message with its traceback.
8. On success: appends to the output one line `=> ` followed by every returned value in the dump form, separated by `, ` (a returned `nil` is shown; a chunk that returns nothing adds no line). Output longer than 60,000 characters is cut there and `[output truncated]` added on a new line.

It returns a table with `available` (true), `ok`, `output`, `error` and `elapsed` (seconds). The whole of it is wrapped in the pages' shared guard, which turns an error in the wrapper itself into `available = false` with a `reason`.

*The dump form.* Strings in double quotes, cut after 400 characters with `..[<length> chars]`; numbers, booleans, functions and game objects as the interpreter's own text for them; tables expanded to 4 levels (`{...}` beyond), a table met again inside itself as `<seen above>`, at most 80 entries per table (`...` after them), the array part first in order and then the other keys sorted by their text as `key = value`; a table of at most 6 entries with nothing nested on one line `{ a, b }`, otherwise one entry per line, indented two spaces per level. An empty table is `{}`. (source)

*The "needs a session" gate.* The bridge normally refuses any call into Lua unless the game's own "a game is on screen" flag is set, because the game's Lua API faults in the game's own code at the main menu and no protected call can catch that. The console has a checkbox **Needs a session**, on by default; while it is off the gate is lifted for the console's own calls only (each call restores it on the way out, so no other page is affected). Its tooltip: `Off lets scripts run at the main menu. The mod's own Lua is fine there; touching game state faults and takes the game with it.` When a call cannot be made, the transcript entry shows `Cannot reach Lua: <reason>` in the error colour, the reason being `no game session`, `not on the render thread`, `the render thread has not run Lua yet`, `a Lua call is already in flight`, a note that a part of the function's dotted name is nil or not a table, `the Lua call raised an error`, or `the Lua call did not return a table`. (source)

*Controls*, in order: (source)

- **Run** (tooltip `Ctrl+Enter`; Ctrl and Enter together run from anywhere on the page, including inside the editor, where Enter alone is a newline). An empty editor does nothing.
- **Clear input** - empties the editor. **Clear output** - empties the transcript. **Copy output** - puts the whole transcript on the clipboard, each run as `> <source>`, then its output, then its error, each on their own lines.
- **Reset scratch** (tooltip `Forgets variables left behind by previous runs`) - calls `BiceLibGui.Console.Reset()`, which drops the scratch environment and returns the output `scratch environment cleared`; the transcript gets an entry whose source reads `(reset)`.
- **Examples** - a drop-down that replaces the editor's text with one of six starting points: `Selected country`, `Read a country variable`, `List the human players`, `Whole page snapshot`, `Search the globals`, `Post a variable (writes!)`. They call the mod's data providers (`BiceData.Players.CurrentTag`, `BiceData.Country.Variables`, `BiceData.Country.Get`, `BiceData.Players.Determine`, `BiceLibGui.StratResources.Collect`, `BiceData.Country.Set`); the last one posts a change to a country variable named `zz_console_test`.
- **Needs a session** - above.
- **History** (shown once something has been run) - a drop-down of the sources run this session, newest first, each labelled by its first line cut to 60 characters with the full text as a tooltip; choosing one puts it back in the editor. A source is added after every run that reached Lua, runs that ended in an error included, unless it equals the previous entry; the oldest is dropped beyond 40. History is not kept between sessions.
- A **Script name** text box, **Save**, a **Saved** drop-down, **Delete**, **Folder**, and a status text - saved scripts, below.
- The editor: a multi-line box holding up to 32,767 characters, Tab inserts a tab, initially 180 units high, with a draggable splitter under it (the editor at least 60 high, the transcript at least 80).
- The transcript: each run shows `> ` and its source in the theme's info colour, its output in plain text, its error in the error colour, and - only when the run succeeded and took at least 0.01 s - a dimmed `(<seconds with two decimals> s)`. The view scrolls to the newest entry after each run. The oldest entry is dropped beyond 60. An empty transcript shows the hint `An expression is printed on its own, so "1 + 1" or "BiceData.Players.CurrentTag()" is enough. Statements run as written, and print() goes here. Variables you set stay set until Reset scratch.` Text coming back from Lua is converted from Windows-1252 for display.

*Saved scripts.* Plain `.lua` text files, one per script, in the folder `BiceLibScripts\` beside the DLL; the file is exactly the editor's text, bytes as typed, named `<script name>.lua`. The folder is created the first time something is saved (or the Folder button is pressed), so an install that never saves one never gets it. (source)

- A name may hold only ASCII letters, digits, spaces, `-` and `_`, 1 to 48 characters; anything else is refused with `Names may hold letters, digits, spaces, - and _ only`.
- **Save** is disabled while the name or the editor is empty. If a file of that name exists, a modal **Replace script?** asks `"<name>" already exists. Replace it with what is in the editor?` with **Replace** and **Cancel**. Status afterwards: `Saved <name>` or `Could not write <path>`.
- **Saved** lists the folder's `.lua` files without the extension, sorted without regard to case, re-read each time the list is opened (so a file dropped in from outside appears without a restart); it reads `(none saved)` / `Nothing saved yet` when empty. Choosing one loads it into the editor and puts its name in the name box: status `Loaded <name>`, `Could not read <name>`, or - for a file that does not fit the editor - `Too big for the editor (<n> bytes); not loaded` (never loaded in part).
- **Delete** is enabled when the name box holds a listed name; a modal **Delete script?** asks `Delete "<name>"? The file goes for good, not to the recycle bin.` with **Delete** and **Cancel**. Status `Deleted <name>` or `Could not delete <name>`.
- **Folder** opens the folder in the system's file browser (tooltip `Opens <folder>, so scripts can be edited outside the game`).
- The status text is in the success or the error colour.

**Inputs a mod gives it** - the two Lua functions `BiceLibGui.Console.Run(source)` and `BiceLibGui.Console.Reset()`, each returning a table with the fields above; the bridge finds them by dotted name in the render thread's Lua state. The mod's deploy script preserves `BiceLibScripts`. (source)

**When it applies** - in a game by default; at the main menu only with **Needs a session** off.

**Multiplayer and saves** - The console itself changes nothing, but a script can do anything the game's Lua API allows, on this machine only: it runs in one player's interface Lua state, so a change it makes that does not go through a posted game command is a change on one machine. Nothing of the console is in a savegame. (source)

**Where the player sees it** - the Debug window's Lua Console tab.

### Warm-up of the pages' data (`G_ImguiWarmupEnabled`)

Kind: interface
Switch: on with the overlay; `G_ImguiWarmupEnabled` in the mod's `script/utility_settings.lua` (default true; only an explicit `false` turns it off)

**What the original does without it** - nothing: this is new.

**What the feature does** - The overlay's data providers parse the mod's files the first time something asks, so the first page opened would stall for seconds. The warm-up pays that cost up front, one dataset per frame, while the game sits at the menu. (source)

It is driven from the frame hook, before the visibility check, so it runs whether or not the overlay is showing:

1. Nothing happens for the first 5000 ms after the first frame on which the overlay's drawing layer is ready.
2. It needs no game session - the session gate is lifted for its calls - but it does need the bridge's other conditions (the render thread has run Lua, no Lua call in flight); a frame where they do not hold is skipped.
3. On the first frame that reaches Lua it calls `BiceLibGui.Warmup.State()` and takes `total` (the number of datasets), `done` and `enabled` from the answer. That is the one point where the setting is read. Nothing is parsed on this frame.
4. On each later frame, while enabled and not finished, it calls `BiceLibGui.Warmup.Step()` once, timing the call. The answer's `done`, `remaining` and `name` update the progress (datasets done is `total` minus `remaining`; the last dataset's name and time; the total time). An answer with `available` false - the module is missing or a step raised an error - ends the warm-up for the session.

The mod's `script/utility_imgui/imgui_warmup.lua` holds the list, slowest first: `Unit models`, `Generals`, `Units`, `Technologies`, `Traits`, `Modifiers`, `Province buildings`; each step calls the provider function that forces that dataset to parse (`BiceData.UnitModels.Choices(nil)`, `BiceData.Generals.ForCountry(nil)`, `BiceData.Units.Choices()`, `BiceData.Techs.ModifierValues()`, `BiceData.Traits.Choices()`, `BiceData.Modifiers.Choices()`, `BiceData.ProvinceBuildings.Choices()`). A step is counted before it runs, so one that fails is not retried. `Step()` returns `{ available, done, remaining, name }`; `State()` returns `{ available, done, remaining, total, enabled }`. (source)

The **Parse now** button on Debug > Timing runs every outstanding step in one frame (at most 32 calls), freezing the game for as long as that takes. (source)

**When it applies** - once per process, normally at the main menu within seconds of start-up. It only parses files; it reads no game state.

**Multiplayer and saves** - none; local caches of the mod's own files.

**Where the player sees it** - only as the absence of a stall, and as the progress line on Debug > Timing.

### Debug > Timing

Kind: tooling
Switch: on with the overlay

**What the original does without it** - nothing: this is new.

**What the feature does** - It reports what each overlay page's drawing costs. The page registry times every page's draw call (the page's own code only, not the window frame around it) with the high-resolution counter and keeps, per page: the time of the first draw, the time of the latest draw, the longest draw so far, and the number of draws. A page is drawn only while its tab is showing, so a page never looked at has no figures. (source)

Top to bottom: (source)

- `<sum> ms across <n> pages` - the sum of the first-draw times of the pages drawn at least once, without decimals - followed by dimmed `(<m> not drawn yet)` with the tooltip `A page is only drawn once its tab is looked at, so its cost has not been paid yet.`
- Radio buttons **Slowest** (the default: rows ordered by first-draw time, longest first, equal ones in page order) and **Page order**.
- Button **Reset** - clears every measurement; tooltip: what is recorded afterwards is a first draw again but not a cold one, since whatever a page loaded is still loaded.
- A paragraph explaining First, Worst and Last.
- Separator `Warm up`, a sentence describing the warm-up and naming `G_ImguiWarmupEnabled` in `script/utility_settings.lua`, then one status: in the success colour `done, <ms> ms spent up front`; or `<done> of <total> - last: <dataset name> (<ms> ms)`; or dimmed `waiting to start`; or dimmed `off - pages will parse when first opened`. Beside it the button **Parse now**, disabled once the warm-up has finished. The page only reports the setting; it has no control that turns the warm-up on or off.
- A scrolling table with a fixed header, one row per registered overlay page (every group, not only Debug): **Page** (its title), **Group** (dimmed), **First**, **Worst**, **Last**, **Draws**. A page never drawn shows dimmed `not drawn` under First and empty cells after it. First and Worst are in milliseconds with one decimal, Last with two; First is in the warning colour from 5.0 ms up.

**When it applies** - main menu and in game. **Multiplayer and saves** - display only.

### Debug > the virtual-call probe page (a reverse-engineering probe)

Kind: tooling
Switch: on with the overlay; the probe itself is installed by a button on the page and records only while a checkbox is ticked

This page is a **probe**: it answers one reverse-engineering question about this build of the executable, and its own source says it should be deleted once the question is settled. Its title is the position of a routine in a class's table of virtual functions and means nothing outside this build. (comment)

**The question, in behavioural terms** - In a battle each participant has a routine that rebuilds the list of combat modifiers shown for it. The static reading of the executable says the only thing that ever calls that routine is the battle's own refresh of its on-map status display - once for the attacking side and once for the defending side, with land participants arriving through their class's own pass-through to the shared routine - and that this refresh runs only for battles in which the local player's country is among the attackers or the defenders. If that is the whole story, the defence-side figures of every naval, air and bombing combat modifier are display only in the original: they reach the battle display and nothing in the simulation, so a mod cannot affect an outcome through them; and they are computed for the player's battles alone. A static reading cannot rule out a caller it could not see, so the probe records, in a running game, the return location of every call to the routine. Only the known locations: the reading stands. Any other: it is wrong, and the location names the caller. The findings file records the result - 39,414 calls in one session, all from the three known locations, confirmed for land and naval combat, bombing not separately confirmed: the fact base's write-up on this probe. (source for the page's own statement of it; the result from the findings file)

**What the feature does** (source)

- Three paragraphs of explanation (which name the expected return locations by address), and in the warning colour `You have to be fighting. Observing is not enough.` with the reason: the refresh is gated on the player's own country being in the battle, so an observer records nothing.
- Under the separator `Probe`, before installation: button **Install the hook** and the status in the warning colour (`not installed yet`, `the game module has not been found yet`, a refusal because the routine's first bytes are not the ones this build of the DLL expects, or `the patch could not be written`). Installing redirects the start of the routine through a stub of BiceLib's; it is refused, with nothing written, when the bytes there are not the expected ones. Once installed it stays for the process.
- After installation: checkbox **Recording**; button **Reset** (forgets all counts); button **Write report to file**; the status (`installed, not recording` or `installed, recording`); and after a report was written `Report: <path>` or `Report: could not be written`. While not recording, a note that the hook then runs no code of BiceLib's - one comparison per call, then the displaced instructions - so it is safe to leave installed.
- `Calls seen: <n>   distinct return addresses: <m>`; in the error colour when the table overflowed `<k> calls arrived after the table filled - addresses were lost.`
- With no calls yet: while recording, the warning `Nothing yet - and a zero here is NOT a result.` and the explanation again; otherwise dimmed `Nothing yet - switch recording on.`
- A table **Return address | Calls | Known?**, one row per distinct return location (shown relative to the game module's load address): its count, and either a success-coloured label naming the battle's refresh for each of the three expected locations or `UNKNOWN` in the error colour.
- A verdict: error colour `<n> caller(s) the static reading did not find.` with an instruction to correct the findings file; or warning colour `Only known callers so far, but the table overflowed - not conclusive.`; or success colour `Only <the known caller>, over <n> calls.` with a caution that this is evidence, not proof, and that land, air, naval and bombing battles should all be fought.

While recording, each call adds one to a total and to the count for its return location in a fixed table of 32 locations; a 33rd distinct location is counted as overflow instead. Counting is safe from any thread. Nothing is written to disk from the hook. The report button writes a text file of its own into the user's temporary folder (the system's temp path) and shows the full path: a heading line, the module's load address, the status, the call and overflow totals, the expected locations, one line for each of the 32 table positions (location, count, and `empty`, `known (...)` or `UNKNOWN`), and a closing line giving the sum of the counts and what it should equal. (source)

**When it applies** - installed by hand; meaningful only in a game in which the player is fighting.

**Multiplayer and saves** - observes only; no game state is read beyond the return location or changed. Local.

### `BiceLib.Reversing.activateCounters()` - how often the game reaches a place in its code

Kind: tooling
Switch: `BiceLib.Reversing.activateCounters()`; commented out in the mod's `script/bicelib_lua.lua`

All seven `BiceLib.Reversing` functions are workbench tools for reading this one build of `hoi3_tfh.exe`. Their inputs are code locations and field positions in that build, and their outputs are evidence about it. A reimplementation has nothing to count, watch or trap in this way; they are listed so the list of what exists is complete. (readme, source)

**What the original does without it** - nothing: this is new.

**What the feature does** - The disassembly says what code would do, not whether the game ever goes there. This counts how often the running game reaches each code location named in a file. (source)

*Arguments:* none. *Returns:* true when the counters were installed, and also when there was nothing to do (no file, or a file naming none); false, with the reason printed to the debug console, when the file names something that could not be installed.

*Input:* `BiceLibCounters.txt` beside the DLL. One counter per line, three fields separated by semicolons:

    <code location> ; <the bytes expected there, as two-digit hexadecimal values separated by spaces> ; <label>

Blank lines and lines starting with `#` are ignored. The first field is a code location relative to the game module's load address, in any C number notation. The bytes are both the check that the location is what the author thinks and the instructions the counter replays, so they must be whole instructions, at least 5 and at most 32 bytes. The label becomes a csv column heading; commas in it become spaces. A line is refused when any of its bytes could be the start of a relative jump or call (which cannot be replayed from elsewhere) - a deliberately over-eager test that reads every byte - unless the line starts with `!`, which says the author has checked. At most 64 counters. The file is a template kept in the fact base's `probes` folder; the mod's deploy script copies every `.txt` from that folder into the deployed `script` folder when the fact base is checked out beside the mod. (source)

*Installing.* Every line is parsed and every location's bytes are compared with the running game before anything is changed; one bad line or one mismatch installs nothing and reports which (`BiceLibCounters.txt line <n>: <why>`, or `'<label>' is not at that address in this build`). Each location is then redirected through a small generated stub that adds one to that counter (safely from any thread), replays the displaced instructions and returns to the instruction after them. Once counters are installed, a further call does nothing and returns true (the game runs the mod's set-up once per Lua state). The counters cannot be removed again. Status texts otherwise: `no BiceLibCounters.txt, so nothing to count`, `BiceLibCounters.txt names no counters`, `<n> counters installed`. (source)

*Output:* `BiceLibCounters.csv` beside the DLL, appended to and never truncated. From the frame hook, on a frame where the game clock has just moved in play (never at the menu or while paused), a row is written the first time each new game day is seen:

    day,hour,<label 1>,<label 2>,...
    <day>,<hour>,<count 1>,<count 2>,...

`day` is the game's hour counter divided by 24 (whole number), `hour` the remainder. Counts are **cumulative** since installation, so a missed row costs nothing and the daily rate is a subtraction. The heading line is written before the first row, and again after every jump of the clock (a load or a new game), which marks the break; the totals carry on across it. (source)

**When it applies** - call once, any time after the DLL has loaded; rows need the overlay enabled (the frame hook writes them).

**Multiplayer and saves** - local; the game's code is patched at the named places but replays the same instructions, so behaviour is unchanged if the file is right. A wrong file can crash the game: the tool cannot check that nothing jumps into the middle of the replaced bytes or that they end on an instruction boundary. (comment)

**Where the player sees it** - nowhere; the csv and one console line.

### `BiceLib.Reversing.activateWatch()` - what fields of the game state hold, and when they change

Kind: tooling
Switch: `BiceLib.Reversing.activateWatch()`; commented out in the mod's `script/bicelib_lua.lua`

**What the original does without it** - nothing: this is new.

**What the feature does** - It samples named fields of the game's central game-state object once a frame and writes a row whenever one changes. It patches nothing. It was written to confirm that one byte of that object means "a game is on screen" (see `reversing/findings/FINDINGS-session.md`). (source, comment)

*Arguments:* none. *Returns:* true when watching or when there was nothing to do; false with the reason printed when a line of the file is wrong.

*Input:* `BiceLibWatch.txt` beside the DLL, one field per line:

    <position of the field inside the game-state object> ; <size in bytes: 1, 2 or 4> ; <label>

Blank lines and `#` lines are ignored; commas in a label become spaces; at most 32 fields. A field that would reach past the end of the object is refused (`that offset is past the end of CCurrentGameState`), which is what makes a wrong line harmless. Status texts: `no BiceLibWatch.txt, so nothing to watch`, `BiceLibWatch.txt names no fields`, `<n> fields watched`, `already watching <n> fields` (a repeat call with the same file keeps its state, so the game's once-per-Lua-state set-up does not restart it), or `BiceLibWatch.txt line <n>: <why>`. Same template and deploy arrangement as the counters file. (source)

*Sampling.* Every frame from the frame hook - deliberately **not** gated on the game clock, because the sample that matters is the one at the main menu. Each field is read through the guarded read. A row is written when this is the first sample, when the game-state object appears or disappears, or when any field's readability or value differs from the last row; the clock columns never cause a row. (source)

*Output:* `BiceLibWatch.csv` beside the DLL, appended:

    tick,day,hour,inplay,pointer,<label 1>,<label 2>,...

`tick` is the game's hour counter (0 without a game state), `day` and `hour` derive from it as above, `inplay` is 1 on a frame where the clock has just moved in play, `pointer` is 1 when the game-state object exists, and each field is its unsigned value in decimal or `-` when it could not be read. The clock columns are context, and how the instrument checks itself: a file whose rows all read tick 0 never reached a game. A whole campaign is a handful of rows. (source)

**When it applies** - call once; sampling needs the overlay enabled. Cannot be switched off except by a later call finding no file or an empty one.

**Multiplayer and saves** - reads only; local.

### `BiceLib.Reversing.watchWrite`, `watchCombatModifiers`, `watchSubunit`, `stopWatching` - which instruction writes a field

Kind: tooling
Switch: by hand, from the Lua console; nothing in the mod calls them

**What the original does without it** - nothing: this is new.

**What the feature does** - It sets one processor hardware data breakpoint on a memory location, on every thread of the process that exists at that moment, and installs a first-in-line exception handler that, each time the location is written, records where the writing code was and lets the game carry on. It is the heaviest of the probes: it changes the debug registers of every thread and puts a handler in front of the game's own exception handling. The handler claims only its own trap and passes everything else on untouched. Only one watch exists at a time; arming again replaces it and starts a fresh answer. (source)

- **`watchWrite(address, size)`** - `address`: the absolute run-time address to watch (a number). `size`: 1, 2 or 4 bytes, 4 when left out. Refused when the address is zero, the size is not one of those (`the address is null or the size is not 1, 2 or 4`), the address is not a multiple of the size (`a hardware watchpoint has to be aligned to its own size`), the game module is not loaded, the handler cannot be installed, or no thread accepts the breakpoint (`no thread would take the watchpoint`). The row label is `address`. Returns true or false; a failure's reason is printed.
- **`watchCombatModifiers(offset)`** - watches 4 bytes inside the unit the last battle tooltip was built for. `offset` is the position of the field inside the unit object; left out, it defaults to a fixed field of the unit (the head of the unit's list of combat modifiers). It needs BiceLib's battle-tooltip hook (`BiceLib.Tooltips.activateCombatUnitStats`) to be on, since that hook is what remembers the unit: have a combat running, hover a unit in it, then call this. With no unit remembered it refuses with `no unit yet - hover a unit in a battle first, so the tooltip hook records which one, then arm`. The unit's address is printed.
- **`watchSubunit(offset)`** - the same, on the **first brigade or ship** of that unit. `offset` is the position inside that object; left out, it defaults to a fixed field of the subunit (a pending-damage total). Refuses also with `that unit has no first subunit to watch`.
- **`stopWatching()`** - clears the breakpoint on every thread, writes the csv, removes the handler, and forgets the remembered unit (so the next run has to hover its own). Always returns true and prints `WriteWatch: disarmed`.

*Output.* The first time each distinct writer is seen, a line goes to the debug console: the label, the writer's location relative to the game module, and the field's value at that moment. The location reported is that of the instruction **after** the one that wrote - a data breakpoint traps once the write has completed - and the line says so. Later hits from the same place are only counted. If 64 distinct writers accumulate, the watch disarms itself (`... distinct writers, which is not an answer - disarming`). On `stopWatching()` - or when a new watch replaces an armed one - `BiceLibWrites.csv` beside the DLL is rewritten from scratch:

    watched,size,label,eip_rva,after_rva,value,hits

one row per distinct writer: the watched address, the size, the label, the writer's location twice (the two columns are the same number: the location after the store is all that is known), the field's value when that writer was first seen, and how many times it was seen. Addresses and the value are in hexadecimal. (source)

**When it applies** - armed and disarmed by hand, in a running game. Threads created after arming are not watched.

**Multiplayer and saves** - observes only; local. No game state is changed.

### `BiceLib.Reversing.probeMessages(on)` - what the game passes when it posts a message

Kind: tooling
Switch: by hand, from the Lua console; nothing in the mod calls it

**What the original does without it** - nothing: this is new.

**What the feature does** - It prints the arguments of the next few messages the game posts to the player, and notes each time a message popup's text is built, so a message BiceLib raised can be compared field by field with one the game raised itself. (source)

*Arguments:* `on` - boolean; left out or true arms the probe, false disarms it. *Returns:* true on success (disarming always succeeds), false with the reason printed (`hoi3_tfh.exe is not loaded`, or a note that one of the two routines does not begin with the bytes this build of the DLL expects, or `could not make the code writable`).

*Arming* redirects the start of two game routines through stubs that print and then carry on unchanged: the routine that posts a message, and the routine that fills a message popup's text in. Both are checked against the expected bytes first. It prints `MessageProbe: the next 8 messages posted will print their arguments`. Arming while already armed changes nothing (status `already armed`) and does not restart the count. Disarming puts the original bytes back. (source)

*Output*, to the debug console only, for the first 8 posts after arming:

- the post's number, where it was posted from (the caller's return location), the thread, and a tag when the caller is the game's own unit-shattering routine;
- the message handler, province and popup-builder arguments (as pointers);
- the player's tag and id fields and the two country fields of the message;
- the message type's name;
- the message's date text;
- the message's heading text, its province with the id that province reports;
- the number of text variables the message carries and up to 40 of them as `$KEY$ = "value"` - the list every `$KEY$` in the type's localised lines is filled from.

and for the first 8 popup-text builds: the build's number, the popup, where it was called from and the thread. Unreadable strings print as a note, non-printable characters as dots. The probe only reads memory; it never calls back into the game. (source)

**When it applies** - by hand, in a running game; stays in until disarmed, silent after its 8 and 8.

**Multiplayer and saves** - observes only; local.

## Registered functions against the README

Every function the DLL registers with Lua, from the registration tables in `bice.cpp`, set
beside `README.md`. `require "BiceLib"` returns one module table per Lua state, with three
functions of its own and fourteen sub-tables. (source)

| table | functions registered | README |
| --- | --- | --- |
| (module) | `startConsole`, `stopConsole`, `setModuleBase` | all three listed |
| `GameInfo` | `getProvinceDetails`, `getCountryFlags`, `getCountryVariables`, `getCountryOffmapIc`, `getCountryResourceConversion`, `getCountryActiveEventModifiers`, `getCountryGeneralModifiers` | all seven listed |
| `Leaders` | `addRankSpecificTrait`, `activateRankSpecificTraits`, `checkRankSpecificTraitsConsistency`, `activateLeaderListShowMaxSkill`, `activateLeaderListShowMaxSkillSelected`, `activateCtrlUnassignSelected`, `activateOobLeaderRanks`, `activateHistoryLeaderRanks`, `addTraitToLeader`, `getLeaderDetails` | `activateCtrlUnassignSelected` is **missing** from the README; the README lists `activateLeaderPromotionSkillLoss`, which is **not registered** (deleted) |
| `Units` | `setCorpsUnitLimit`, `setArmyUnitLimit`, `setArmyGroupUnitLimit`, `addCommandLimitTrait` | all four listed |
| `Navy` | `setScreenPenalty`, `setScreensPerCapitalRatio` | both listed |
| `BytePatches` | `fixMinisterTechDecay`, `disableWarExhaustionNeutralityReset`, `disableInterAiExpeditionaries`, `historicalModelLogicFix`, `seaTerrainColourInSimplifiedMapMode` | all five listed |
| `ComplexPatches` | `fixOffMapIC`, `enablePlacingNonResearchedBuildings`, `fixQueuedHistoricalModel`, `fixMaxInfrastructure`, `customResourceConversion` | all five listed |
| `Events` | `rebuildCandidates` | the whole table is **missing** from the README |
| `EffectTexts` | `activateKillLeaderVariables`, `activateLoadOobDetails`, `activateTriggerIndent`, `activateTriggerScroll` | all four listed |
| `Tooltips` | `activateManpowerBreakdown`, `activateCombatUnitStats`, `activateParadropLine`, `activateCombinedArmsLine` | `activateParadropLine` and `activateCombinedArmsLine` are **missing** from the README |
| `Messages` | `show` | listed |
| `Reversing` | `activateCounters`, `watchCombatModifiers`, `watchSubunit`, `watchWrite`, `stopWatching`, `activateWatch`, `probeMessages` | all seven listed |
| `Commands` | `registerBiceCommands`, `postExampleCommand` | both listed |
| `Inspector` | `getSelectedEntity` | listed |
| `Overlay` | `enable`, `toggle` | both listed |

That is 58 functions: 3 on the module and 55 in the tables. Four are not in the README, and
one the README lists does not exist.

What the DLL does with **no Lua switch of its own** - all of it hanging on
`BiceLib.Overlay.enable()`, none of it on loading the DLL alone: the crash reporter and the
pure-call handler; the saved autosave and edge-scroll settings put back; and, from the
per-frame hook, the daily callback into `BiceLibDailyPeriodics`, the combat record, the
out-of-memory watch, the warm-up, and the overlay's drawing. Loading
the DLL by itself installs nothing in the game: it finds the game module, registers the Lua
tables, and notes the Lua state. (source)

## README and source disagreements

The code was followed in every case.

### In part 1 (fixes, rules, leaders) and in the README's general statements

- The README's opening says almost all of the API "is switched on from `script/bicelib_lua.lua`, which runs once per session". The script runs at the top level in every Lua state the game creates, several times per process; every switch is written to be called again.
- The README gives "Return values: /" for nearly every switch. Every byte patch, every `ComplexPatches` call and every `activate...` call returns a boolean; `activateRankSpecificTraits` returns whether it is on; the `Units` and `Navy` setters return nothing on success and false when their hook could not go in.
- `activateLeaderPromotionSkillLoss` is documented (struck through, "currently bugged") and no longer exists in the source.
- `activateCtrlUnassignSelected` exists, is switched on in the mod, and is not documented.
- `disableWarExhaustionNeutralityReset`: the README describes only the end of the payment into neutrality. The change sets war exhaustion to 0 in every monthly pass, so it no longer accumulates at all.
- `disableInterAiExpeditionaries`: the README says the AI never sends or retrieves expeditionary units "from other AI countries". The change is two unconditional skips in the AI's expeditions pass; nothing in it tests whether the other country is run by the AI. Which test each skip replaced was not re-read here.
- `addRankSpecificTrait`: the README says it returns false "if the specified trait can't be found"; it also returns false while the game's traits are not loaded yet, and true for a pair already declared.
- `addRankSpecificTrait`: the README says traits "MUST be prefixed with rankSpecificTrait_"; the code does not check the prefix when a pair is declared - an unprefixed pair is accepted and then never swapped, because only prefixed traits are looked at.
- `setScreenPenalty`: the README does not say the figure is in thousandths, nor that each of the two figures can be set only once per process.
- `set...UnitLimit`: the README does not mention the lone-brigade allowances (a one-brigade division may always be attached, and those already attached do not count), which are part of the rule.
- `getCountryOffmapIc`: the README says "requires the offmap IC patch to be active"; without it the function still answers, with 0.
- `getCountryResourceConversion`, `customResourceConversion`, `fixMaxInfrastructure`, `fixQueuedHistoricalModel`, `historicalModelLogicFix`, `enablePlacingNonResearchedBuildings`, `activateOobLeaderRanks`, `activateHistoryLeaderRanks`: the README and the code agree.
- The command framework: the README and the code agree. The README's "only three such ids are free" and the header's account of which two are used agree with each other.

### In part 2 (texts)

- **activateCombatUnitStats.** The README (and the comment above the function in bice.cpp, and
  the mod's older wording) say it adds the variables `$SOFTATTACK$`, `$HARDATTACK$`,
  `$PIERCING$`, `$DEFENSIVENESS$`, `$TOUGHNESS$`, `$ARMOR$` and `$AIRATTACK$` to
  `BATTLE_ATTACKMOD` and that "nothing appears until the localisation asks". The code sets no
  variable at all: it appends a hard-coded English block (four summed stats with their
  effective values, plus the damage tallies) to the end of the tooltip. Piercing, armour and
  air attack are not in it. The header of CombatUnitStats.hpp also still says armour and
  piercing are averaged over the brigades that have one; the code neither reads nor shows them.
- **Damage tallies.** The README does not mention the "Damage" table (battle and last-tick,
  strength and organisation, dealt and taken) that the same switch installs.
- **activateManpowerBreakdown.** The README lists three variables (`$LAND$`, `$AIR$`,
  `$NAVY$`); the code sets seven, adding `$ROTATION$`, `$ROTATIONCOST$`, `$ATTRITION$` and
  `$TRICKLEBACK$`, and the mod's `MANPOWER_DETAILS_IRO` uses all seven.
- **activateTriggerIndent.** The README and the header of TriggerIndentText.hpp describe four
  changes that replace the constant depth `and` and `or` pass to their children. The code makes
  a different and larger set: header self-indents removed (for `and`, `or` and six scope
  renderers), children indented one deeper, child blocks told their real depth, an indent and
  asterisk for block children in the base renderer, asterisks inside context scopes, and
  leading spaces trimmed from a `not`. The depth passed for a leaf child's one-line text is not
  changed, contrary to the header's table.
- **activateTriggerScroll.** The README names only Alt and the arrow keys; the code also
  scrolls with Alt and the mouse wheel (through the overlay's window procedure), and adds the
  two hint lines. The header's remark that the install checks eighteen bytes is stale (it
  checks one instruction).
- **activateKillLeaderVariables.** The comment in KillLeaderText.cpp and
  reversing/findings/FINDINGS-effecttext.md say the unit and province in `$WHERE$` are yellow;
  the code writes them red.
- **activateLoadOobDetails.** reversing/findings/FINDINGS-effecttext.md still describes the
  rank line by the maintainer's earlier rule (division 1, corps 2, everything above 3). The
  code uses division 1, corps 2, army 3, army group 4, theatre 4, and words the line
  differently depending on whether activateOobLeaderRanks is installed (the header of
  LoadOobText.hpp records the change, dated 2026-11-01). The README does not mention the Alt
  key, the limits of 4 places and 10 leaders, the rank line or the "added to production" line.
- **Return values.** The README gives "/" (none) for all six documented functions; every one
  returns a boolean.
- **activateParadropLine and activateCombinedArmsLine** are absent from the README.
- **CombatUnitDamage.cpp** has a comment saying the table holds 2048 units; the constant is 4096.

### In part 4 (the overlay's core)

1. **Group names.** `README-imgui.md`, `Gui/Pages/README.md` and the page template name the first group `Main`. The code's first group is `Setup`; no group called `Main` exists, and a page declaring `Main` would sort last into a window of its own.
2. **What the Lua bridge's session guard tests.** `README-imgui.md` says `sessionActive()` means "a game state object exists, which is already true at the main menu". The code reads the game's "a game is on screen" flag, which is false at the main menu; the pointer test is the bug that was fixed.
3. **Return values of the overlay functions.** `README.md` lists no return values for `Overlay.enable()` and `Overlay.toggle()`. The code returns a boolean from each (hooks installed; now showing).
4. **Toggle key.** Both READMEs say only "press INSERT". The code has a rebindable key saved as `overlay.toggleKey`.
5. **Switching the warm-up from the Timing page.** `utility_settings.lua` and a comment in `Gui/Warmup.cpp` say the Debug group's Timing page can switch the warm-up off or on for a session. The Timing page only reports it and offers `Parse now`; its own comment says it is deliberately not switched there.
6. **`in_game` during a load.** The header comment of `GameState/GameClock.hpp` says the flag "is set for the whole of a load". The comment in `GameClock.cpp`, BiceLib's `CLAUDE.md` and `reversing/findings/FINDINGS-session.md` say the opposite (it is not set during a load); the code's behaviour matches the latter.
7. **When the mod rebuilds event candidates.** `GameState/EventCandidates.hpp` says the mod's handler "runs once after each save is loaded". In the mod's script the call sits behind `G_UtilityEnabled` (committed `false`) and behind a global flag nothing resets.
8. **Why the monthly autosave exists.** `reversing/findings/FINDINGS-autosave.md` (section "What BiceLib does with it") still gives the old reason (a save made after the month change fires nothing that month). The source comments in `AutoSave.hpp` and `AutoSavePage.cpp` say that reason is gone and must not be stated: it is a rollback point.
9. **`Messages.show` result.** `README.md` gives two reasons for false (no game running, queue full). The code also returns false for empty or missing text and when the flush hook cannot be installed.
10. **Where the saved game settings are restored.** A comment in `GameSettingsPage.cpp` says the edge-scroll setting is "put back at startup". It is put back by `BiceLib.Overlay.enable()`, so only when the overlay is enabled.

### In part 5 (Setup and Country Info pages)

- **Where a page's Lua file lives.** `Gui/Pages/README.md` says `script/utility_imgui/imgui_<name>.lua`. The files are in per-group subfolders (`utility_imgui/Setup/`, `utility_imgui/CountryInfo/`, ...), which `autoexec.lua` adds to the Lua search path.
- **Who may select another player's country.** The comment in `imgui_country.lua` says the multiplayer host can inspect another player's country. Nothing in the code tests for the host: any machine may select any country whose `disable_gui_access` is not 1.
- **IC Days refresh.** A comment in `imgui_ic_days.lua` says the page does not refresh until asked. The page refreshes by itself every second with `Auto` ticked, which is the default.
- **The opt-out text on Setup > Country.** The page's own text says a blocked selection "silently stays put". The code shows a warning line naming the tag and the reason.

### In part 6 (Game Info, Stats, Help pages; game-info reads)

- `README.md` says of `getCountryFlags`, `getCountryVariables` and `getCountryActiveEventModifiers` that the first call can take up to a second because the country has to be found in memory, and that later calls are fast through a cache shared by the GameInfo functions. The code has no such cache and no memory search: it walks the game's own country list on every call.
- `README.md` does not say that those three functions return nil for an unknown tag (it says so only for `getCountryGeneralModifiers`); the code returns nil for all four. It also does not say that `getCountryVariables` leaves out variables whose value is zero, or that `getProvinceDetails` returns nil for an id the map lacks.
- `README.md` describes `getLeaderDetails` as returning "name, rank, skill, experience, traits, what he commands". The code returns no traits, only `number_of_traits`; it does return the keys listed above, which the README does not enumerate, and `experience` is in the 15-fractional-bit fixed point rather than thousandths.
- `README.md` describes `getSelectedEntity` only as "A list of tables" and does not mention the nil result outside a game.
- `README-imgui.md` points at a page folder `Oob/` for pages that read memory directly; the order of battle pages are in `Inspector/`.
- The Stats "Setup" page text says "Every human player is collected while the switch above is off". The mod's collector, with the custom list off, also writes statistics for every AI country from its minister callbacks.
- The comment at the top of `GeneralsPage.cpp` and `TraitsPage.cpp` says the definitions are parsed "once per session"; the mod's caches are per Lua state and are never dropped, so it is once per process.
- `imgui_warmup.lua` says of its steps "Nothing here needs a game session: it is all file parsing". Its Units step asks the game's Lua API for the player and for researched levels (see the next heading).
- The comment in `bicedata_generals.lua` says leaders are listed "highest starting skill first"; the comparison is on text, so a two-digit skill sorts below a one-digit one.

### In part 7 (Inspector)

- `README-imgui.md` says the order of battle code is in a folder `Oob/` and that its layout knowledge comes from a memory map kept elsewhere in the mod's repository. In the code both OOB pages are in the `Inspector` pages folder, the read is `GameState/OrderOfBattle`, and the layouts are in the DLL's own class headers.
- `reversing/findings/FINDINGS-mapmode.md` (section "What BiceLib does with all this") describes the custom map mode as two hooks painting building levels in green. The code has four hooks (two in the colouring, one choosing the tooltip's map mode, one adding lines to the Resources tooltip), three kinds of source and two palettes. The same file marks the Resources tooltip hook "Not yet run in the game".
- `reversing/findings/FINDINGS-combat.md` says a campaign file line missing a field is skipped. The code makes one exception: a line with every field but the last (the session) is read as session 0.
- The comment on the land strength scale in `OrderOfBattle.cpp` says land regiments hold strength "in hundredths"; the code beside it, and the header, divide by 10.
- The OOB Report's code comment says the first read "stays deliberate" so that opening the page does not start thousands of reads by itself. The code reads as soon as the selected country's tag is known, because a tag change triggers a read and the tag last read starts out empty; "Press Refresh to read the order of battle." is seen only while there is no selected country.
- The comment above the environment rows in `Inspector.cpp` says `night` is listed for every branch. The code returns before those rows for an air unit, so an air unit shows no terrain section at all.

### In part 8 (tooling)

- `README-imgui.md` lists four Debug pages in the order Timing, Memory, Lua Console, Thread Check. The code registers five, and their order numbers give Thread Check, Memory, Lua Console, Timing, and the probe page. The readme's summary of the Memory page also leaves out its GUI widgets, Crash save and Ballast sections.
- `README.md` documents `watchWrite(address, size)` with both parameters required; the code defaults `size` to 4.
- The comment in `Reversing/WriteWatch.hpp` gives the csv columns as `watched,size,eip_rva,after_rva,value,hits`; the code writes a `label` column after `size`.
- The comments in `Reversing/Counters.hpp` and `Watch.hpp` (and the template files) say the two input files are not shipped and must be copied by hand; the mod's `zDsafeMoveFiles.py` copies every `.txt` from the fact base's `probes` folder into the deployed `script` folder. The Lua calls remain commented out, so nothing reads them unless a developer uncomments one.
- The mod's `script/utility_settings.lua` and a comment in `Gui/Warmup.cpp` say the Timing page can turn the warm-up off for a session through a checkbox. The Timing page has no such control; it reports the setting and offers only **Parse now**.
- `GameState/OutOfMemory.hpp` and the Memory page's tooltip say the probe is taken "twice a second"; the code takes it every 30 presented frames, which is twice a second only at 60 frames a second.
- A comment in `Gui/WidgetStats.cpp` sizes the widget history for one sample every two seconds (1800 samples, an hour); the Memory page samples every 500 ms and only while it is showing, so 1800 samples are 15 minutes of the page being open.
- The Timing page's own text says "Worst and last are the frames after that" (after the first draw); the code's worst figure includes the first draw.
- The probe's header speaks of two expected return locations; the code accepts three (the land class's pass-through was added after the first run flagged it as unknown), while the report file's `expected` line still lists two.
- `Gui/Pages/Debug/MemoryPage.cpp` carries an orphaned comment describing a readout of "what the new handler has caught, and the button that provokes it". No such code exists; `GameState/OutOfMemory.hpp` says the allocation-failure handler was removed.

## Possible bugs in BiceLib itself

Read off the code, none tried in the game unless a line says so. They are listed so that a
reimplementation can decide, case by case, whether to copy the behaviour.

### In part 1 (fixes, rules, leaders) and part 3 (commands)

- **`disableWarExhaustionNeutralityReset` switches war exhaustion off altogether.** Storing 0 where the month's amount was added means no country ever holds war exhaustion after a monthly pass, so the `war_exhaustion` static modifier and any condition on war exhaustion are dead too. If only the payment into neutrality was unwanted, this does more than was meant.
- **`fixOffMapIC` keeps its per-country figures across games.** The remembered off-map figure and the running local-IC figure are indexed by country id and never cleared, so after loading another game `getCountryOffmapIc` answers the previous game's figure until that country's first daily pass, and a running figure left from a pass that did not finish would be subtracted once in the new game.
- **`fixOffMapIC` overwrites the country's `IC` modifier entry** with the remainder each day. This is right only if the entry is rebuilt (province IC and all) before every daily pass; if a day passes without a rebuild, the next pass would subtract the provinces from a figure that no longer holds them. Not verified either way.
- **Unit limits: the country is taken from the unit being attached, not from the commander.** They are the same country except where a unit on loan is involved; then the lender's limit decides how full the borrower's command may be.
- **Unit limits are not cleared between games** in one process; a country's own figures from the last game stand until the daily callback sets them again, and the defaults stand as the script's top-level calls last set them.
- **`addCommandLimitTrait` keeps the first effect** given for a trait name and ignores a later call silently, and does not check that the trait exists.
- **`setScreenPenalty` and `setScreensPerCapitalRatio` ignore every call after the first** without saying so, and take any integer: a ratio of 0 or less switches the penalty off.
- **A `set...UnitLimit` call for an unknown tag does nothing and says nothing.**
- **Rank-specific traits are written to the savegame as a single space.** What the game's loader makes of a leader trait named " " was not established; and since nothing gives the traits back after a load, the feature cannot work across a save without more mod-side work. It is off.
- **Rank-specific traits swap only in the promotion command.** A rank changed by `activateOobLeaderRanks`, `activateHistoryLeaderRanks` or history leaves the pair as it was until `checkRankSpecificTraitsConsistency` is called.
- **Ctrl-unassign passes a flag whose meaning is not established** to the assign-leader command (the value the game's own single-unit unassign passes). Tested working in single player and multiplayer.
- **`postExampleCommand` converts numbers to 32-bit integers without a range check**; a number outside the range gives an unspecified argument, the same on every machine.
- **A kind unknown to one machine is a silent divergence there** (logged only). The framework has no version handshake between machines; it relies on everyone running the same DLL.

### In part 2 (texts)

- **Scroll breaks when an `and` is rendered at depth 0 inside the tree** (inference from the
  source and the findings, not tried in the game). The scroll hook runs at every exit of the
  `and` renderer called at depth 0, and an explicit `and` directly inside the top-level block
  (or under a top-level `not`) is also rendered at depth 0. Each such inner call presents a
  different "whole text", which resets the scroll position; a key press seen during the inner
  call can drop a line from the inner block and put the "... N more above" marker in the middle
  of the tree; and the outer text then differs from the last one seen and resets again. The
  same would apply to `enemy = { }` and MTTH `modifier` blocks, which share the renderer.
- **Scroll position survives leaving the tooltip.** It is reset only when the text differs,
  so going back to a tooltip with the identical text shows it still scrolled. Possibly
  intended.
- **Asterisk on a block inside an iterating scope.** Correction 4 writes an asterisk for any
  container child of the base block at a depth above 0, including an `and`/`or`/`not` directly
  inside `any_owned_province` and its like - where leaf conditions deliberately get none
  because they are evaluated against the country and not a province. That asterisk is evaluated
  the same wrong way.
- **A text-less leaf.** Correction 4 keys on "the child's one-line text is empty". A leaf
  condition that has no text at all (the findings list seven tactic conditions) would, at a
  depth above 0, get an indent and an asterisk with no text and no line break after it.
- **Damage tallies outside their battle.** Organisation "taken" is added at every settle of
  any brigade of a unit that has a tally, whatever caused the loss (air attack, for instance,
  after a land battle), and without checking the battle stamp; and each such settle hands
  shares to the attackers still on the target's list from the last land shots, however old.
  The attackers on that list are remembered as live objects, not by id. Tallies are not
  cleared when another save is loaded, so a unit with the same type and id in the new game
  shows the old game's figures until it fights. The battle-ended signal that retires a stamp
  exists only while the combat log's recording hook is installed.
- **Font probe marker.** The probe keeps the font of the first measured string containing
  `effective`; if some other text containing that word is measured in a different font before
  the tooltip is, the wrong font is used for the rest of the process.
- **load_oob text cache ignores the scope.** The one-second cache is keyed on path and Alt
  only, so the same file shown for two different countries within a second would show the
  first country's leader lines for both.
- **load_oob does not look in the expansion's folder.** The file is tried in the mod's
  `history/units` and then in the game root's `history/units`; the install also has a
  `tfh/history/units`, which is not tried. A file that exists only there reads as "Not in the
  mod or the game.", and one that exists in both is read from the root's copy, which may not be
  the one the game loads.
- **load_oob file cache is for the whole process.** A file not found at the first ask stays
  "Not in the mod or the game." until restart, and province names are those localised at the
  first ask.
- **load_oob counting rule.** Any block with a `location` counts as a unit that appears,
  including one nested inside a `military_construction` block (which goes to the production
  queue, not the map), and its `regiment`/`ship`/`wing` blocks count as brigades, ships and
  wings. Counts of one still read "1 units" and "1 leaders take command:".
- **kill_leader `$WHERE$` length.** The value is cut at 255 characters, which could cut inside
  a colour escape for a very long unit and province name.

### In part 4 (the overlay's core)

1. **February in the monthly autosave tooltip.** The rule in code is save day = days in month minus `days` plus 1, which for 2 days gives the 30th of a 31-day month (as the tooltip says) but the **27th** of February, not the 26th the tooltip and the header comment state.
2. **Saved autosave and edge-scroll settings depend on the overlay.** Both are restored only inside `BiceLib.Overlay.enable()`. With `G_ImguiUtilityEnabled = false` a player's saved "no edge scrolling" and extra autosaves silently stop applying.
3. **Autosave timer and day marker are never reset between games.** The timed save's "timer running" state is only cleared by toggling its checkbox, so time spent at the main menu counts and the first day change of the next game can save immediately; the comment says the timer starts with each session. The monthly "already asked on this day" marker also survives a load, so loading a save dated the same calendar day asks for no monthly save that day.
4. **Extra autosaves ignore the game's own gates.** The request is made before the game's "no autosaves in a tutorial" test and without the game's multiplayer branch, so an extra save can be requested in a tutorial and is written locally in multiplayer. Whether either causes harm was not established.
5. **Daily callback: a failed first call uses up `firstDay`.** The day and session are recorded before the Lua call, so if the first call after a load fails (function missing, Lua error) the next day's call passes `firstDay = 0` and the at-once setup is skipped until the mod's own day rule next applies. Also the "last day called" is not reset by a load, so reloading onto the same calendar day delays the first call by a day.
6. **Console buttons always report success.** The Utility Options page's `Open` and `Detach` set the status `Console opened` / `Console detached` without checking the Lua call's result; outside a running game the call is refused and nothing happens.
7. **(Mod Lua) Event popup change always reports failure.** `BiceData.Options` treats any non-empty string returned by `ReplaceLineAtCommentMark` as an error, but that helper returns `Edited: <file>` on success. So after a successful change the page shows `Could not write the file: Edited: <path>` in the error colour, although the file was changed and the state line updates.
8. **(Mod Lua) `rebuildCandidates` was unreachable with the mod's settings - mended 2026-11-20**, as described in its section: the fix for events after a load was only applied when the deprecated wx utility was enabled. The call now sits above that switch and runs once per Lua state.
9. **`Messages.show` with a bad province id.** A positive id that is not a province yields "no province" and the message is queued anyway; what the game's `Goto` then does was not checked.
10. **After the overlay's crash guard trips**, the toggle key can still set the overlay "showing"; nothing is drawn, but window input is again offered to the overlay and may be swallowed on the strength of stale state from its last frame.
11. **Failed one-time setup is retried every frame.** If the user-interface back ends fail to initialise, the setup runs again on each frame and creates a new interface context each time without releasing the last.
12. **Toggle key and system keys.** Only ordinary key-down messages are examined, so a key Windows delivers as a system key (F10, or any key with Alt held) can neither be bound nor toggle the overlay.
13. **`Parse now` at the main menu.** The Timing page's button runs under the normal session rule, so at the main menu - where the warm-up is meant to do its work - it does nothing.

### In part 5 (Setup and Country Info pages)

- **The opt-out also blocks one's own country.** `BiceData.Players.Select` applies the `disable_gui_access` test to every deliberate selection, including the `Select` button beside `You are playing`. A player who has opted out and then selects another country cannot select his own again until he opts back in (automatic selection is not tested, but no longer applies once a deliberate choice was made). The failure message cannot tell this from "not a country".
- **Pending markers that never time out.** On Misc, IC Days, Puppets, Strategic Res., National Focus and the `Active` state of the three AI pages a pending request is only dropped when the game reports the requested value. If the command never lands, or something else writes a different value, the page keeps showing the requested value with its marker indefinitely. Only Resource Conversion gives up (after 10 seconds). The pending values are also not reset when the selected country changes, so a request made for one country is shown against the next one until it happens to match.
- **Global Market before its first read.** The page makes no call on first draw and `Auto` is off, so until `Refresh` is pressed or a resource chosen it shows the bridge's last reason text, which belongs to whatever call some other page last failed (or `no Lua call made yet`), not to this page.
- **Global Market "Next expiry".** `findTrade` returns the first trade it meets for the seller and resource in an unordered table walk, so with several trades the figure is not necessarily the soonest expiry.
- **Trade AI: variables the AI reads and the page never posts** (mod Lua, not the DLL). After the reload that `zzDsafe_WantsToChangeCustomTradeAi` triggers, `ai_trade.lua` reads `zzDsafe_TradeAi_MONEY_BufferSaleCap` and the four `zzDsafe_TradeAi_SUPPLIES_...` variables; the provider posts neither (it leaves supplies out and gives Money no caps), so they read 0 unless something else set them. Not verified in play.
- **Prod. Sliders AI: only duplicate priorities are refused** (mod Lua). The mod's AI walks the priorities as 1, 2, 3 ... and stops at the first number nobody holds, so a set with a gap or a number outside 1 to 6 (which the page accepts) leaves the later categories without a share. Not verified in play.
- **`BiceLibDailyPeriodics`' `bicelib_loaded`** is returned by the mod and never read by the DLL; harmless.

### In part 6 (Game Info, Stats, Help pages; game-info reads)

- `getCountryFlags` and the "Active Flags" page list every flag entry in the country's flag store without testing the entry's "set" marker, which is the only thing the game's own flag test reads. If the original keeps an entry after `clr_country_flag`, cleared flags are shown as active. Not verified against a running game.
- Traits, Modifiers, Techs and Units make one automatic load attempt on the first frame the page is drawn in the process. If that frame is at the main menu the attempt is refused (`no game session`) and is never repeated; in a game the page keeps showing that text until `Reload` is pressed.
- The Help text pages mark a section as loaded without checking the answer's `available` flag: if the Lua side raised an error the page stays blank for the rest of the process and the error text is never shown.
- "Active Variables" prints values with no decimals, so a fractional variable is shown rounded (0.4 as `0`, a small negative value as `-0`).
- The Units page finds the selected technology again after a level change by looking for its key as a substring of the new labels and taking the first hit, so a technology whose key is contained in another's key can lose the selection to that other technology.
- Units page data: the assumed levels are captured when the unit files are first parsed and are not refreshed when the reported country changes or another save is loaded, so the "researched" baseline in the statistics can belong to a different country until `Reset all`. When the warm-up parses the unit files at the main menu, that capture calls the game's Lua API (`CCurrentGameState.GetPlayer`, `CTechnologyDataBase.GetTechnology`, the country's technology status) outside a session, which the READMEs say must never happen; it may also set `G_PlayerCountry` there. Read from the code, not observed.
- `getCountryActiveEventModifiers` and `getCountryGeneralModifiers` return tables keyed by name, so entries sharing a name are silently merged; the "Active Event Modifiers" page, which uses the list form, shows both.
- Key extraction is inconsistent: the mod's `KeyFromChoice` takes the text between the first `[` and the first `]`, the Generals page's trait lookup the text between the last `[` and the last `]`. A localised name containing square brackets breaks the first.
- The Statistics page scans the run folder once, on its first draw; if the run number is still 0 then, it shows `Nothing collected yet.` until `Rescan` is pressed even after collection has started. Its statistic filter is case-sensitive while every other filter in the overlay is not. The tooltip about the external tool is attached only to the `Open in the tool` button, and the tool's arguments are passed unquoted, so a mod version containing a space would split into two arguments.
- The Stats "Setup" explanation of who is collected is wrong for AI countries (see the disagreement above).
- Mod Lua, not the DLL, but visible through these pages: the collector's run number is cached per Lua state for the life of the process, so after loading a save of a different game it keeps writing into the earlier game's folder while the pages read the folder of the loaded save; two Lua states asking for a run number on the same day before the posted variable has landed can each take a different number from `identcounter`; and `diplo_EffectiveNeutrality` is written from the same call as `diplo_Neutrality`.
- An event modifier that never expires is shown with its stored placeholder date (year 1 or earlier) rather than as permanent.

### In part 7 (Inspector)

- **The campaign number is asked once per run of the game.** The store keeps the first non-zero campaign number, the file paths and the loaded file for the life of the process. Leaving a game and loading a savegame of a different campaign in the same run appears to file that campaign's combats into the first campaign's file and to judge them against its sessions.
- **Two overlays in one multiplayer game each claim a session.** Each machine running the overlay posts its own new number into the one shared `bice_combat_session` variable on every load, and re-posts every 5 seconds until it has once seen its own number stored. The last poster's number is what the savegame carries, so on the other machines the next load names a parent their sessions file does not have, and the timeline falls back to counting the whole root. The same race exists for the campaign number on a new game. Read from the code, not observed.
- **The Combat Reports hover text names a memory offset.** The player-facing explanation of "name only their winner" quotes an internal structure offset of this build.
- **The Unit Inspector's caption contradicts its own data source.** The page says "Base values for the unit type ... Per sub unit, and before the effects the game applies", while the comment where the figures are read says they are the unit's own aggregate over its regiments with technology already applied.
- **The Custom Mapmode page tells the player to reselect the VP map mode** ("Reselect the VP map mode in game to redraw the map." is shown the whole time the mode is on, and the checkbox hover says to switch away and back), although the code repaints at once whenever the VP map mode is on screen.
- **A resource's shade scale is not refreshed by a load or by passing days**, only when the resource is picked or the box is ticked; after loading a different savegame in the same run the legend and shades use the earlier game's scale until then.
- **Province Buildings lists every controlled province.** The mod's Lua keeps a province when the building's maximum level is 0 or more, which a level cannot fail, so provinces without the building are listed at level 0, while the page's own description says "every province the country controls that has it". Whether the game's Lua API can answer a negative level for a building a province cannot hold was not checked.
- **"Base production" on the Province Buildings page is current production**: the four goods come from the province's current yield, not its base or maximum values, and the footer line calls them base values.
- **The OOB Browser's Commander row** shows the placeholder leader as "(no leader) (skill 0 of 0)"-style text rather than "none", because "none" is shown only when the unit has no leader object at all, while the missing-leader colouring uses the name test.
- **Combat Reports' Total column and the casualty rows add unlike quantities** (strength lost on land and in the air, ships in thousands at sea, and whatever a bombing target loses), without saying so on the page.
- **The 35 days in the two "Days of ..." legend texts is written into the text**, not read from the define, so it is wrong for any mod or game with another `SUPPLYPOOL_DAYS`.

### In part 8 (tooling)

- **Crash save, frame-loop path: success is inferred from the request flag going down.** The game's own autosave decision also clears that flag each time it runs (BiceLib's autosave hook stands on that very instruction and releases the name claim when it happens). If that decision runs between the request and the writer picking it up, the request is cancelled, the crash save still reports `written after <n> frames`, and the message box tells the player the game was saved as "crashsave" when nothing was written. Whether the game's frame order allows this was not established from the source.
- **Write watch: the self-disarm at 64 distinct writers loses the results.** It clears the breakpoints and marks the watch as not armed without writing the csv; `stopWatching()` then sees nothing armed and writes nothing, so the 64 rows exist only as console lines. The exception handler also stays installed until `stopWatching()`.
- **Write watch: only threads that exist when it is armed get the breakpoint**, so a write from a thread created later is missed and reads as "nothing writes it".
- **Lua console: an error inside the Lua wrapper itself is shown as a blank entry.** The shared guard answers `available = false` with a `reason`, but the page reads only `ok`, `output`, `error` and `elapsed`, so the entry shows the source and nothing else.
- **Timing page: "Parse now" does nothing at the main menu.** The per-frame warm-up lifts the session gate for its calls; the button's path does not, so with no game on screen every call is refused with "no game session" and the button silently does nothing - at the one place the warm-up is meant to run.
- **Memory page: wrong tooltip when the pure-call handler is not installed.** The "Provoke one" tooltip is attached to whatever was drawn last; with no button drawn, that is the status line, so hovering the status shows the provoke tooltip instead of the status line's own.
- **Counters: a failure while writing the redirections leaves a partial install.** All checks are made before anything is changed, but if redirecting counter k fails, counters before k stay redirected and are reported in the csv while the call returns false.
- **Out-of-memory watch at the main menu** closes the game with "The save could not be written: no game is running, so there was nothing to save". By the code's own logic this is intended, but it means a low-memory main menu is closed with nothing gained.
- **The probe page** labels all three known return locations with the same "known caller" text although one of them is the land class's pass-through, and the written report's `expected` line omits it. Cosmetic.
- **Diagnostics** updates its "most threads inside Lua at once" figure and reads its thread table without full synchronisation, so the figure can be under-recorded in a race. Display only.

## Not fully described

What this file could not state with the confidence of the rest, and why.

- **`disableInterAiExpeditionaries`**: the two skips are known; which condition of the AI's pass each replaced was not re-read, so "never lends, never gives back" is the reading of two unconditional skips against the findings' account of the two branches, not a traced path.
- **`fixOffMapIC`**: what the country's `IC` modifier entry holds before the routine runs, and when it is rebuilt, were not read; the arithmetic is given as coded.
- **`historicalModelLogicFix`**: how the game breaks a tie between two models of equal score was not read.
- **The command framework**: how the game's channel orders and stamps commands is the fact base's subject (reversing/findings/FINDINGS-commands.md), not restated here.
- **Text features**: what the game renders for a localisation key it does not have (nothing, or the key itself) - the sources disagree, and the fallbacks each caller uses are given instead; whether a space follows the asterisk in a requirement line depends on each condition's own text, which was not read; the reach of scope names and condition wordings is cited from reversing/findings/FINDINGS-scripttext.md and not derived again.
- **Custom autosaves**: where the files land and the exact steps of the three-file rotation are the game's own routine, given from comments and reversing/findings/FINDINGS-autosave.md; the effect of an extra autosave in multiplayer was not established.
- **`Messages.show`**: what the message's Goto does with a province id that names no province.
- **`Events.rebuildCandidates`**: its effect in multiplayer.
- **`getCountryGeneralModifiers`**: the key strings are each modifier kind's own name as the game holds it; only the one the mod reads is attested in what was read, so the full list of names is not given.
- **The game-info reads at the main menu**: none but `getSelectedEntity` is gated on a session; what the others return there depends on what the process holds.
- **`addTraitToLeader`**: what the game's add-trait routine refuses (it tests the trait against the leader's branch) is from a header comment.
- **Statistics collection**: which machines write the files in multiplayer depends on where the mod's minister callbacks run.
- **The pages' Lua**: whether the mod's scheduled scripts run in the same Lua state as the one the overlay calls into (it matters for two globals the pages read) was not established; the mod AI that consumes the Trade, Production and Leadership settings is summarised, not specified.
- **Colours**: page colours are given by the theme's names (error, warning, success, dim) and in decimal for the default dark theme only.
- **The combat record**: what a "loss" is at sea and in a bombing is from reversing/findings/FINDINGS-combat.md; the supply figures a custom map mode can show are the game's own routines, cited from reversing/findings/FINDINGS-supplynetwork.md.
- **The crash save's rotation** rests on a code comment; whether the game's frame order lets the frame-loop crash save report success for a cancelled request was not established.
- **One Debug page** is a reverse-engineering probe whose title and explanatory text name build-specific positions; it is described by what it asks, and its title is not reproduced. One hover text on the Combat Reports page is paraphrased for the same reason.
- **The help pages' text** is summarised (headings, counts, structure); it lives in the mod's `script/utility_data/bicedata_help.lua`.
- **The two default arguments of `watchCombatModifiers` and `watchSubunit`** are positions inside game objects and are described, not given.
