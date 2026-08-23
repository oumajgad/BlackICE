#pragma once

/**
 * What the game was holding at the moment each combat finished.
 *
 * The game records a CCombatHistoryEntry when a combat ends, and prunes those after a
 * few days - and they carry no casualty figures anyway. So the numbers have to be
 * taken at the moment of the event, which is what the hook in Hooks/CCombatHooks is
 * for: the function that records an entry is handed the CCombat itself, still alive,
 * with both its combatants.
 *
 * Everything the report needs - both countries, the province, the branch, who won,
 * the losses and the men each side had - is read out by name here. Whole blocks of the
 * combatants used to be kept beside that, for a search on the page to hunt an unknown
 * field through; there is nothing left to hunt, and the reversing folder has the
 * scripts for the next one.
 *
 * The hook runs on whichever thread the game finishes a combat on, so everything here
 * is behind a lock and does no more work than copying bytes.
 */

#include <cstdint>

namespace Combat {
    const int MAX_RECORDS = 64;

    /**
     * What kind of fight it was, which the game keeps as a class rather than a field.
     *
     * The three bombings are `CBombing`'s subclasses: a raid on a province, on the
     * land units in one, and on ships. They are combats like any other and end up in
     * the same history, but nobody wins them - neither side is emptied - and what the
     * target loses is not the same currency as a division's strength.
     */
    enum class Branch
    {
        Unknown,
        Land,
        Air,
        Naval,
        GroundBombing,
        LandBombing,
        NavalBombing,
    };

    const char* branchName(Branch branch);

    /**@brief true for the three kinds of bombing raid*/
    bool isBombing(Branch branch);

    /**
     * Which side was left standing, and so won.
     *
     * A combatant's country list is empty by the time the combat is recorded for
     * exactly one of the two sides, and that is the side that lost - confirmed in
     * game against battles whose outcome was known. It is also why the loser has no
     * tag: the game reads the tag out of that same empty list.
     */
    enum class Outcome
    {
        Unknown, // both sides standing, or neither - not seen, but not assumed away
        AttackerWon,
        DefenderWon,
    };

    const char* outcomeName(Outcome outcome);

    struct Side
    {
        uintptr_t address = 0;
        char tag[8] = {};     // "ITA", or "---" when this side has no country left
        int countryId = 0;
        int countryCount = 0; // combatant+0x5c, which is what decides the tag

        // Still had a country in the fight when the combat was recorded, which is
        // what marks the winner.
        bool standing = false;

        // This side's own country, from the second list at +0x64 - the one it keeps
        // when the list the game reads is emptied. On the beaten side that is the
        // only thing left naming it.
        char retainedTag[8] = {};
        int retainedId = 0;

        // Strength lost, in thousandths: 21900 is the 21 the game reports. One side's
        // losses are the other side's kills, which is the whole of what the report
        // needs from a combat.
        int losses = 0;

        // How many men were in the fight on this side.
        //
        // Copied from what the game does to print "out of 25700 troops" when a battle
        // ends: it walks every subunit type there is and adds up the tally kept per
        // type at +0x74, each divided by a thousand. Numbers rather than pointers, so
        // unlike the units themselves they are still there once the fight is over.
        int men = 0;
    };

    struct Record
    {
        uintptr_t combat = 0;
        uintptr_t vftable = 0;
        Branch branch = Branch::Unknown; // which of the three kinds, from the vftable
        unsigned int tick = 0;
        int provinceId = 0;
        int flag = 0;            // combat+0x2b, which the entry keeps at +0x20
        Outcome winner = Outcome::Unknown;

        Side attacker;
        Side defender;
    };

    /**@brief starts or stops capturing. Enabling installs the hook, once*/
    bool setRecording(bool on);
    bool recording();

    /**@brief why recording could not be turned on, when it could not*/
    const char* status();

    /**@brief called from the hook with the combat that just ended*/
    void note(uintptr_t combat);

    /**
     * The buffer is a ring, and records are numbered rather than indexed.
     *
     * The hook fills it and the store empties it, on different threads and at their
     * own paces, so what matters is which records the reader has already seen. A
     * sequence number says that; an index into a wrapping buffer does not. If the
     * reader falls far enough behind that a record is overwritten before it is read,
     * asking for it says so instead of quietly handing back a newer one.
     */
    unsigned int written();
    unsigned int oldestKept();

    /**@brief copies record \p sequence out. False if it is not (or no longer) there*/
    bool copySequence(unsigned int sequence, Record& out);

    void clear();
}
