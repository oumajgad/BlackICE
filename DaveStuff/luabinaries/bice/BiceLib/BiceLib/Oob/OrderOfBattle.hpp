#pragma once

/**
 * A country's order of battle, read out of the running game.
 *
 * Standalone rather than built on GameClasses: everything the game's unit structures
 * look like is written down in one place here (OrderOfBattle.cpp), read through
 * Mem::tryRead so a pointer that turns out not to be what we assumed fails instead of
 * taking the process down, and handed back as plain values. Nothing in here holds a
 * game pointer past the call that read it.
 *
 * The layout came from the memory map in DaveStuff/mem, which is where anything
 * learned about these structures should go back to.
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
        uintptr_t leader = 0;
        std::string leaderName;
        int leaderSkill = 0;
        int leaderMaxSkill = 0;

        // A unit can carry a leader that is not one: the game names it "(no leader)"
        // rather than leaving the pointer empty, so both have to be checked.
        bool hasLeader = false;
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
        int leaderlessBelow = 0;
        int depthBelow = 0;
    };

    struct Tree
    {
        std::vector<Unit> units;

        // Indices into units. Roots and each unit's children are sorted by name, so
        // the tree reads in the order a person would look for a formation in - the
        // game's own order is whatever it happened to build things in.
        std::vector<int> roots;

        bool available = false;
        std::string reason;       // why it is not, when it is not

        int landTotal = 0;
        int airTotal = 0;
        int navalTotal = 0;
        int regimentTotal = 0;
        int leaderlessTotal = 0;

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
