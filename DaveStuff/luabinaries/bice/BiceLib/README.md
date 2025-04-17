# Overview

This is a LUA module written in C++ to achieve the following:
* read game infos directly from memory which is not exposed by the existing Hoi3 LUA API
    * This lib uses the "external" approach to reading memory. This makes it easier to test and is (pretty much) exactly as fast as using the "internal" way.
* apply bugfix patches at runtime
* modify/expand existing game mechanics
* apply other miscellaneous patches

LUA functions are provided to activate and configure the module. They are grouped the following way:

## BiceLib.GameInfo
* **getFlags(string countryTag)**:
    * Get a list of all current countryflags
    * **Params**:
        * *countryTag*: The TAG for which to retrieve the flags
    * **Return values**:
        1. *flags*: List of strings
    * **Notes**:
        * The first call can take up to a second to complete since it needs to find the country in memory. Subsequent calls are near instant due to caching. The cache is shared between *GameInfo* functions.
* **getVariables(string countryTag)**:
    * Get a map of all current countryVariables
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *vars*: Mapping of *name (string)* -> *value (number)*
    * **Notes**:
        * The values are in the fixed point number format. E.g. if the returned value is 12050, then the ingame representation is 12.05
        * The first call can take up to a second to complete since it needs to find the country in memory. Subsequent calls are near instant due to caching. The cache is shared between *GameInfo* functions.
* **getActiveEventModifiers(string countryTag)**:
    * Get a map of all current event modifiers and their expiry date
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *modifiers*: Mapping of *name (string)* -> *expiry date (string)*
    * **Notes**:
        * The first call can take up to a second to complete since it needs to find the country in memory. Subsequent calls are near instant due to caching. The cache is shared between *GameInfo* functions.
* **getCountryOffmapIc(string countryTag)**:
    * Gets the offmap ic value of a country
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *offmapIC*: integer / nil if the countryTag wasn't found
    * **Notes**:
        * requires the offmap IC patch to be active

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

## BiceLib.BytePatches
Patches which only need a few bytes to be changed.
* **fixMinisterTechDecayDone()**
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
