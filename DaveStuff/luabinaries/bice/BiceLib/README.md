# Overview

`BiceLib.dll` is a C++ module loaded into `hoi3_tfh.exe` to do what the game's own Lua API
cannot:

* read the running game's state straight out of memory
* patch bugs at runtime, either by rewriting a few bytes or by standing in front of a
  function and doing the work in C++
* add to or change existing game mechanics
* add variables to what the game's own tooltips and effect texts say
* draw an in-game utility overlay

**It runs inside the game's own process.** Addresses are resolved against the module base
at load, so nothing here is tied to where Windows happens to put the image, and patches are
applied to live code. An earlier version read the game from outside; that is no longer how
any of this works.

Two other files cover the parts this one does not:

| | |
| --- | --- |
| `README-imgui.md` | the utility overlay - what it draws, how it is switched on, how it gets on screen |
| `reversing/README.md` | how the addresses in here were found, and the tooling that finds more |

Everything below is the Lua API, grouped as it is grouped in Lua. Almost all of it is
switched on from `script/bicelib_lua.lua`, which runs once per session.

## Loading it

* **BiceLib.setModuleBase()**
    * Finds `hoi3_tfh.exe` in memory and stores its base. **Everything else needs this**, so
      it is the first call `bicelib_lua.lua` makes.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * Does nothing if called twice.
* **BiceLib.startConsole()**
    * Opens a console window for the module's own logging - every `INFO`, `WARNING` and
      `ERROR` line in this document's functions goes there.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * Quick-edit mode is turned off deliberately: clicking in a Windows console selects
          text and **freezes the process that owns it** until the selection is cleared.
        * Does nothing if called twice.
* **BiceLib.stopConsole()**
    * Detaches the console so its window can be closed.
    * **Params**: /
    * **Return values**: /

## BiceLib.GameInfo
* **getCountryFlags(string countryTag)**:
    * Get a list of all current countryflags
    * **Params**:
        * *countryTag*: The TAG for which to retrieve the flags
    * **Return values**:
        1. *flags*: List of strings
    * **Notes**:
        * The first call can take up to a second to complete since it needs to find the country in memory. Subsequent calls are near instant due to caching. The cache is shared between *GameInfo* functions.
* **getCountryVariables(string countryTag)**:
    * Get a map of all current countryVariables
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *vars*: Mapping of *name (string)* -> *value (number)*
    * **Notes**:
        * The values are in the fixed point number format. E.g. if the returned value is 12050, then the ingame representation is 12.05
        * The first call can take up to a second to complete since it needs to find the country in memory. Subsequent calls are near instant due to caching. The cache is shared between *GameInfo* functions.
* **getCountryActiveEventModifiers(string countryTag)**:
    * Get a map of all current event modifiers and their expiry date
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *modifiers*: Mapping of *name (string)* -> *expiry date (string)*
    * **Notes**:
        * The first call can take up to a second to complete since it needs to find the country in memory. Subsequent calls are near instant due to caching. The cache is shared between *GameInfo* functions.
* **getCountryGeneralModifiers(string countryTag)**:
    * Get a map of the country's general modifiers and their current values
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the modifiers
    * **Return values**:
        1. *modifiers*: Mapping of *name (string)* -> *value (number)*, or *nil* if the tag wasn't found
* **getCountryOffmapIc(string countryTag)**:
    * Gets the offmap ic value of a country
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *offmapIC*: integer / nil if the countryTag wasn't found
    * **Notes**:
        * requires the offmap IC patch to be active
* **getProvinceDetails(number provinceId)**:
    * Gets details of a province
    * **Params**:
        1. *provinceId*: The ID of the province
    * **Return values**:
        1. *details*: A table with the following entries: 
            - id            -> number
            - supply_pool   -> number
            - fuel_pool     -> number
            - oil           -> number
            - metal         -> number
            - energy        -> number
            - rares         -> number
            - manpower      -> number
            - leadership    -> number
            - modifiers     -> table with the following entries
                - local_ic          -> number
                - local_oil         -> number
                - local_energy      -> number
                - local_metal       -> number
                - local_rares       -> number
                - local_leadership  -> number

## BiceLib.Leaders
* **activateRankSpecificTraits()**
    * Ranks specific traits are traits which exists in 2 states. "Active" and "InActive". The 2 states are 2 different traits, which get exchanged when a rank change to the specific rank occurs.
    * This can be used to represent a leaders ability (or inability) at certain command levels.
    * Use the *addRankSpecificTrait* function to register traits.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * The traits display will only be updated after reopening the leader list.
* **addRankSpecificTrait(string activeName, string inActiveName, number lowerRank, number upperRank)**
    * Register a trait pair to a rank.
    * Traits **MUST** be prefixed with **rankSpecificTrait_**
    * **Params**:
        1. *activeName*: The full name of the rank in its active state
        2. *inActiveName*: The full name of the rank in its inactive state
        3. *lowerRank*: The first rank at which the trait should be in the *active* state
        4. *upperRank*: The last rank at which the trait should be in the *active* state
    * **Return values**:
        1. *success* (boolean): If the specified trait can't be found this will be *false*
    * **Notes**:
        * The traits display will only be updated after reopening the leader list.
* **checkRankSpecificTraitsConsistency()**
    * Goes through all leaders and checks if their rank specific traits match their current rank.
    * **Params**: /
    * **Return values**: /
* **~~activateLeaderPromotionSkillLoss()~~ (currently bugged)**
    * This will make leaders lose/gain skill levels when the are promoted/demoted, like it was in older Hoi games.
    * Each leader has to receive a "pskill_XYZ" trait which represents his pure skill level. With the combination of rank + pure skill the game can now determine the appropiate skill level.
    * Percentual progress towards the next skill level is preserved 1:1 between promotions/demotions (rounded down to the nearest whole %).
    * If a leader has gained a skill level by fighting long enough his "pskill" trait will be updated during the next rank change.
    * If a leader doesn't have a "pskill" he is not affected by this entire mechanic.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * The game actually tracks the total experience amount gained, and each level requires a different amount of total exp. Due to number overflow this causes the entire skill progression system to break past lvl 10. There are some extremely complicated instructions in the code which appear to accomodate values above lvl 10, by saving the value as a 64 bit number, but inside a savefile it only saves a 32 bit number. The 64 bit number also appears to be very much broken.
        * The skill number display will only be updated after reopening the leader list.
* **addTraitToLeader(int leaderId, string traitName)**
    * Adds a trait to a leader.
    * **Params**:
        1. *leaderId*: The ID of the leader
        2. *traitName*: The full case-correct in-code name of the trait
    * **Return values**:
        1. *success* (boolean): If the specified trait or leader can't be found this will be *false*
    * **Notes**:
        * The traits display will only be updated after reopening the leader list.
        * This can add the same trait multiple times. During a save load the excess traits are removed.
* **getLeaderDetails(int leaderId)**
    * Gets everything known about one leader - name, rank, skill, experience, traits, what
      he commands.
    * **Params**:
        1. *leaderId*: The ID of the leader
    * **Return values**:
        1. *details*: A table, or *nil* if no leader has that id
* **activateLeaderListShowMaxSkill()**
    * This will make the ingame leader list also display a leaders max skill.
    * Max skill will be displayed inside parentheses following the current skill e.g.: "3 (7)"
    * **Params**: /
    * **Return values**: /
* **activateLeaderListShowMaxSkillSelected()**
    * Same as *activateLeaderListShowMaxSkill*, except that this applies to the currently active leader in the leader list
    * **Params**: /
    * **Return values**: /

## BiceLib.Units
* **setCorpsUnitLimit(int newLimit, string countryTag)**
    * set the limit of unit attachements for corps
    * **Params**:
        1. *newLimit*: The new limit
        2. *countryTag*: The country for which this limit should apply. To set a default use the "---" tag.
    * **Return values**: /
* **setArmyUnitLimit(int newLimit, string countryTag)**
    * set the limit of unit attachements for armies
    * **Params**:
        1. *newLimit*: The new limit
        2. *countryTag*: The country for which this limit should apply. To set a default use the "---" tag.
    * **Return values**: /
* **setArmyGroupUnitLimit(int newLimit, string countryTag)**
    * set the limit of unit attachements for army groups
    * **Params**:
        1. *newLimit*: The new limit
        2. *countryTag*: The country for which this limit should apply. To set a default use the "---" tag.
    * **Return values**: /
* **addCommandLimitTrait(string traitName, int effect)**
    * register a trait which should have an effect on the unit limit
    * **Params**:
        1. *traitName*: The name of the trait
        2. *effect*: How many more (or less) units should be able to be attached
    * **Return values**: /
    * **Notes**:
        * This is more of a soft effect since you can assign a leader with this trait, attach a unit, unassign the leader.

## BiceLib.Navy
* **setScreenPenalty(int newPenalty)**
    * set the defence penalty capital ships will receive if they don't have enough screens in their fleet (vanilla is 33%)
    * **Params**:
        1. *newPenalty*: The new penalty
    * **Return values**: /
* **setScreensPerCapitalRatio(int newRatio)**
    * set the ration of screens needed per capital ship (vanilla is 1)
    * **Params**:
        1. *newRatio*: The new ratio
    * **Return values**: /

## BiceLib.BytePatches
Patches which only need a few bytes to be changed.
* **fixMinisterTechDecay()**
    * The "Minister tech ability decay" modifier simply does not work. This fixes that.
    * **Params**: /
    * **Return values**: /
* **disableWarExhaustionNeutralityReset()**
    * Normally the game adds a countries "War Exhaustion" to its neutrality after a war (when it switches from war to peace)
    * For Black ICE we don't want that.
    * **Params**: /
    * **Return values**: /
* **disableInterAiExpeditionaries()**
    * This patch makes the AI never send/retrieve expeditionary units from other AI countries.
    * AI countries will send expeditionary to each other when the unit is on the territory of its ally. However the AI is likely to send the majority of their units to countries which don't need them, and then won't recall them. 
    * This happens especially in cases when the AI just conquered a country and immediately after creates a puppet.
    * **Params**: /
    * **Return values**: /
* **historicalModelLogicFix()**
    * A country can be handed a model it cannot field. When the game picks which model a
      unit is built with, it scores each one by the **absolute** difference between the
      technology levels the model asks for and the levels the country has - so a model
      asking for *more* than the country has scores exactly as well as one asking for the
      same amount *less*.
    * This makes asking for more than is researched cost a flat, enormous penalty instead,
      so such a model loses to any model that fits.
    * **Params**: /
    * **Return values**: /
* **seaTerrainColourInSimplifiedMapMode()**
    * Makes the Simplified Terrain map mode colour the sea as well as the land.
    * That mode already works out a colour for all 3,547 sea provinces; the water ignored
      them, because the shader that samples province colours is only used for two of the
      map styles. This puts Simplified into the set that uses it.
    * **Params**: /
    * **Return values**: /

## BiceLib.ComplexPatches
Patches which require some extra logic and hooking.
* **fixOffMapIC()**
    * makes the "IC" modifier usable in event/triggered modifiers, essentially being offmap IC
    * **Params**: /
    * **Return values**: /
* **enablePlacingNonResearchedBuildings()**
    * This enables the placement of buildings by the player for which he has not researched the technology yet.
    * This is needed for when an event gives the player buildings which he should place manually.
    * **Params**: /
    * **Return values**: /

## BiceLib.EffectTexts
Extra variables for what the game shows when an effect fires. **Each of these only adds
variables - nothing appears until the localisation asks for them.**
* **activateKillLeaderVariables()**
    * Adds `$UNIT$`, `$LOCATION$` and `$WHERE$` to what the `kill_leader` effect shows, so
      `KILL_LEADER_EFFECT` can say which unit the leader commands and where it is.
    * **Params**: /
    * **Return values**: /
* **activateLoadOobDetails()**
    * Replaces what `load_oob` shows - a file path and nothing else - with what the file
      would actually do: how many units appear and where, what they are made of, and which
      leaders it takes, with what each of those commands now.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * The file is read off disk, because nothing about it is in memory until the effect
          fires.
* **activateTriggerIndent()**
    * Indents what is inside an `and` or an `or` in a requirement tooltip.
    * The game renders a requirement tree one line per trigger, three spaces per level, and
      both container triggers pass a constant for their children instead of their own depth
      plus one - so a condition inside an `and` or an `or` is drawn flush left whatever it
      is nested in.
    * **Params**: /
    * **Return values**: /
* **activateTriggerScroll()**
    * Lets a requirement tooltip too tall for the screen be scrolled with **Alt and the
      arrow keys**.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * Nothing about the tooltip window is touched: the text itself is shortened from
          the front, which works because the game rebuilds it continuously while hovered.

## BiceLib.Tooltips
Extra variables for the game's own tooltips. **As with the effect texts, nothing appears
until the localisation asks.**
* **activateManpowerBreakdown()**
    * Splits the manpower tooltip's "needs X manpower to reinforce" into land, air and
      naval, and offers each as a variable `MANPOWER_DETAILS_IRO` can place: `$LAND$`,
      `$AIR$` and `$NAVY$`.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * The three are taken from the one instruction that builds the total, so they add
          up to it rather than merely ought to.
* **activateCombatUnitStats()**
    * The modifier list a unit shows in a battle says `Attack Modifier: 44.70%` and never
      what of. This adds `$SOFTATTACK$`, `$HARDATTACK$`, `$PIERCING$`, `$DEFENSIVENESS$`,
      `$TOUGHNESS$`, `$ARMOR$` and `$AIRATTACK$` to `BATTLE_ATTACKMOD`, totalled over the
      division's brigades from each one's own definition - which already has its technology
      in it.
    * **Params**: /
    * **Return values**: /

## BiceLib.Messages
* **show(string text, string header, number provinceId, string line2, string line3)**
    * Puts one of the game's own message popups in front of the player, with text of your
      own.
    * **Params**:
        1. *text*: the message's first line. **The only argument that is needed.**
        2. *header*: who is reporting it. Defaults to "BlackICE reports that".
        3. *provinceId*: what the message points at, and what its *Goto* button goes to.
           Defaults to the player's capital.
        4. *line2*, *line3*: two more lines, empty by default.
    * **Return values**:
        1. *success* (boolean): *false* with no game running, or if the queue is full
    * **Notes**:
        * Shown through the `BICE_MESSAGE` type, declared in
          `interface/messagetypes.txt` and written in `localisation/BiceLib_messages.csv`.
          A message's lines come from the localisation for its **type**, so the only way to
          show arbitrary text is for that type's lines to be variables - which is what they
          are.
        * The popup appears **on the next frame**, not during the call. A message raised
          straight away from inside the overlay's rendering comes up as an empty window;
          this is queued and raised where the game raises its own.

## BiceLib.Inspector
* **getSelectedEntity()**
    * Returns objects of what the player has selected ingame.
    * **Params**: /
    * **Return values**: A list of tables.

## BiceLib.Overlay
The in-game utility. See `README-imgui.md` for what it draws and for the settings that
switch it on; these two are just the Lua handles.
* **enable()**
    * Installs the Direct3D hooks the overlay draws through. Called from
      `script/gui-imgui.lua` rather than at startup, so turning the overlay off means the
      hooks are never installed at all.
    * **Params**: /
    * **Return values**: /
* **toggle()**
    * Shows and hides it, the same as pressing **INSERT**.
    * **Params**: /
    * **Return values**: /

## BiceLib.Reversing
Workbench tools for reverse engineering, not for a normal session. Each is armed by hand
and most write a csv next to the game. See `reversing/README.md`.
* **activateCounters()**
    * Counts how often the game reaches each address named in `BiceLibCounters.txt`, and
      writes the totals to `BiceLibCounters.csv` once a game day.
    * The disassembly says what code *would* do, not whether the game ever goes there.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * Without the file this does nothing and says so.
* **activateWatch()**
    * Records what the game state fields named in `BiceLibWatch.txt` hold, writing a row to
      `BiceLibWatch.csv` whenever one of them changes.
    * **Params**: /
    * **Return values**: /
    * **Notes**:
        * Hooks nothing: it reads once a frame and refuses an offset outside the object, so
          a wrong line in the file costs a wrong number in a csv rather than the game.
* **watchWrite(number address, number size)**
    * Traps writes to an address and reports which instruction made them.
    * **Params**:
        1. *address*: what to watch
        2. *size*: 1, 2 or 4
    * **Return values**:
        1. *success* (boolean)
* **watchCombatModifiers(number offset)**
    * The same trap, on the combat modifier list of the unit the last battle tooltip was
      about. For a field nothing in the image appears to store to.
    * **Params**:
        1. *offset*: which field, defaulting to `0xDC`
    * **Return values**:
        1. *success* (boolean)
    * **Notes**:
        * Have a combat running and hover a unit in it, then call this and let the combat
          tick.
* **watchSubunit(number offset)**
    * The same trap, on a field of the first subunit of that unit.
    * **Params**:
        1. *offset*: which field, defaulting to `0xAC`
    * **Return values**:
        1. *success* (boolean)
* **stopWatching()**
    * Clears whichever watch is armed and writes what it saw to `BiceLibWrites.csv`.
    * **Params**: /
    * **Return values**: /
* **probeMessages(boolean on)**
    * Prints the arguments of the next few messages the game posts, and of the popups it
      builds their text into.
    * For telling a message BiceLib raised apart from one the game raised itself, which is
      the only way to see which field of an object passed by value on the stack is wrong.
    * **Params**:
        1. *on*: *false* puts the patched bytes back. Defaults to *true*.
    * **Return values**:
        1. *success* (boolean)
