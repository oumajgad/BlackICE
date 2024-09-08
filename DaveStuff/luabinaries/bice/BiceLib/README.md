# Overview

This is a LUA module written in C++ to achieve the following:
* read game infos directly from memory which is not exposed by the existing Hoi3 LUA API
    * This lib uses the "external" approach to reading memory. This makes it easier to test and is (pretty much) exactly as fast as using the "internal" way.
* apply bugfix patches at runtime
* modify/expand existing game mechanics
* apply other miscellaneous patches

These features are activated and configured via LUA.


## Informational functions
* **getFlags(string countryTag)**:
    * Get a list of all current countryflags
    * **Params**:
        * *countryTag*: The TAG for which to retrieve the flags
    * **Return values**:
        1. *flags*: List of strings
* **getVariables(string countryTag)**:
    * Get a map of all current countryVariables
    * **Params**:
        1. *countryTag*: The TAG for which to retrieve the variables
    * **Return values**:
        1. *vars*: Mapping of *name (string)* -> *value (number)*
    * **Notes**:
        * The values are in the fixed point number format. E.g. if the returned value is 12050, then the ingame representation is 12.05

## Bugfixes
* **activateOffmapICPatch()**
    * makes the "IC" modifier usable in event/triggered modifiers, essentially being offmap IC
    * This breaks the "local_ic" building modifier, so any buildings giving local IC will need a triggered modifier to add their IC effect
    * **Params**: /
    * **Return values**: /

* **activateMinisterTechDecayPatch()**
    * The "Minister tech ability decay" modifier simply does not work. This fixes that.
    * **Params**: /
    * **Return values**: /
* **activateWarExhaustionNeutralityResetPatch()**
    * Normally the game adds a countries "War Exhaustion" to its neutrality after a war (when it switches from war to peace)
    * For Black ICE we don't want that.
    * **Params**: /
    * **Return values**: /

## Mechanical changes
### Leaders
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
        1. *success* (boolean): If the specified rank can't be found this will be *false*
    * **Notes**:
        * The traits display will only be updated after reopening the leader list.
* **activateLeaderPromotionSkillLoss()**
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
### Units
* **setCorpsUnitLimit**
    * set the limit of unit attachements for corps 
    * **Params**:
        1. *newLimit*: The new limit
        2. *force* (boolean): If you call this function a 2nd time it will not do anything. Use force to overwrite this behaviour
    * **Return values**: /
* **setArmyUnitLimit**
    * set the limit of unit attachements for armies 
    * **Params**:
        1. *newLimit*: The new limit
        2. *force* (boolean): If you call this function a 2nd time it will not do anything. Use force to overwrite this behaviour
    * **Return values**: /
* **setArmyGroupUnitLimit**
    * set the limit of unit attachements for army groups 
    * **Params**:
        1. *newLimit*: The new limit
        2. *force* (boolean): If you call this function a 2nd time it will not do anything. Use force to overwrite this behaviour
    * **Return values**: /
* **addCommandLimitTrait**
    * register a trait which should have an effect on the unit limit
    * **Params**:
        1. *traitName*: The name of the trait
        2. *effect*: How many more (or less) units should be able to be attached
    * **Return values**: /
## Other patches
* **activateLeaderListShowMaxSkill()**
    * This will make the ingame leader list also display a leaders max skill.
    * Max skill will be displayed inside parentheses following the current skill e.g.: "3 (7)"
    * **Params**: /
    * **Return values**: /
* **activateLeaderListShowMaxSkillSelected()**
    * Same as *activateLeaderListShowMaxSkill*, except that this applies to the currently active leader in the leader list
    * **Params**: /
    * **Return values**: /
