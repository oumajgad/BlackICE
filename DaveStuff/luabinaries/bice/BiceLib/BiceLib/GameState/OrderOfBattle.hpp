#pragma once

/**
 * A country's order of battle, read out of the running game.
 *
 * What the game's structures look like is in GameClasses - CUnit, CRegiment, CLeader
 * and the rest, a header per class. This file is the shape rather than the layout: it
 * works out which unit reports to which, and hands the result back as plain values.
 *
 * Everything is read through Mem::tryRead, so a pointer that is not what it was taken
 * for fails instead of taking the process down, and nothing in here holds a game
 * pointer past the call that read it.
 *
 * A unit is a node in a tree: theatres at the top, then army groups, armies, corps
 * and divisions. The same structure carries land, air and naval units, which are told
 * apart by the vtable the game gave them rather than by their level.
 */

#include <cstdint>
#include <string>
#include <vector>

namespace Oob {
    enum class Branch
    {
        Unknown,
        Land,
        Air,
        Naval,
    };

    const char* branchName(Branch branch);

    /**@brief the game's name for an OOB level, or "Level n" past what it names*/
    const char* levelName(int level, Branch branch);

    /**@brief one regiment, brigade or ship inside a unit*/
    struct Regiment
    {
        std::string name;
        int strength = 0;      // x1000
        int organisation = 0;  // x1000
    };

    struct Unit
    {
        uintptr_t address = 0;
        std::string name;
        int id = 0;
        int type = 0;
        int level = 0;
        Branch branch = Branch::Unknown;
        bool selected = false;

        int supplyPercent = 0;   // x10, so 1000 is 100%
        int fuelPercent = 0;
        int digIn = 0;           // x1000
        int combatArmsBonus = 0; // x10
        int combatCooldown = 0;  // hours x1000

        bool upgradePriority = false;
        bool upgradeActive = false;
        bool reinforcementsActive = false;

        int regimentCount = 0;

        // What this unit's own regiments consume, in thousandths, as the game
        // works it out - leader and country effects included. Zero for a unit
        // that holds no regiments itself, which is every level above division.
        int supplyConsumption = 0;
        int fuelConsumption = 0;
        uintptr_t leader = 0;
        std::string leaderName;
        int leaderSkill = 0;
        int leaderMaxSkill = 0;

        // A unit can carry a leader that is not one: the game names it "(no leader)"
        // rather than leaving the pointer empty, so both have to be checked.
        bool hasLeader = false;

        // A leader that is missing, which is not the same as one that is absent: a
        // division of a single brigade cannot be given a commander at all, so having
        // none is correct. Counts and highlighting go by this rather than hasLeader.
        bool leaderMissing = false;
        uintptr_t province = 0;
        int provinceId = 0;

        // Indices into Tree::units. -1 for a unit with no parent among those read.
        int parent = -1;
        std::vector<int> children;

        // Everything below this unit, not counting the unit itself.
        int landBelow = 0;
        int airBelow = 0;
        int navalBelow = 0;
        int regimentsBelow = 0;
        int supplyConsumptionBelow = 0;
        int fuelConsumptionBelow = 0;
        int leaderlessBelow = 0;
        int unitsBelow = 0;
        int depthBelow = 0;

        // Averaged over unitsBelow, on the same x10 scale as the unit's own figures.
        // Every unit counts the same however big it is: this says how well supplied
        // the formation is, not how much of the supply it is receiving.
        int supplyAverageBelow = 0;
        int fuelAverageBelow = 0;
    };

    struct Tree
    {
        std::vector<Unit> units;

        // Indices into units. Roots and each unit's children are sorted by name, so
        // the tree reads in the order a person would look for a formation in. The
        // game's own order follows whenever each unit was created.
        std::vector<int> roots;

        bool available = false;
        std::string reason;       // why it is not, when it is not

        int landTotal = 0;
        int airTotal = 0;
        int navalTotal = 0;
        int regimentTotal = 0;
        int supplyConsumptionTotal = 0;
        int fuelConsumptionTotal = 0;
        int leaderlessTotal = 0;

        // Across every unit, on the same x10 scale.
        int supplyAverage = 0;
        int fuelAverage = 0;

        /**@brief units left unread because the cap was hit; 0 when everything fitted*/
        int truncated = 0;
    };

    /**
    @brief reads the whole order of battle of one country

    The country's own list mixes units from every level and says nothing about the
    shape, so the tree is worked out from the units: who each one reports to, and
    therefore which of them report to nobody.

    @param country a CCountry instance, as the country cache hands them out
    */
    Tree read(uintptr_t country);

    /**
    @brief reads one unit's regiments, which the tree deliberately does not

    A division holds a handful and a country holds thousands, so these are read when
    a unit is actually looked at rather than for every unit on every refresh.
    */
    std::vector<Regiment> regiments(uintptr_t unit);
}
