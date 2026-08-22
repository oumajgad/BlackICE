#pragma once

#include <Windows.h>

/**
 * Catches every combat the moment the game finishes it.
 *
 * The game records a CCombatHistoryEntry when a combat ends, and the function that
 * does it - 0x0042f960 in the executable - is handed the CCombat itself as its second
 * argument. That is the only moment the combat, its two combatants and their units are
 * all still alive and final: the entry the game keeps afterwards holds a date, a
 * province and one country tag, and no figures at all.
 *
 * Hooking there rather than at either of the two places a combat can end means one
 * hook catches land, air and naval alike.
 *
 * "Still alive" is not quite true of the units: by the time this runs the combatants
 * have been emptied of them. What the two sides were made of is still there in the
 * per-type tallies beside them, which is where the size of a force is read from - see
 * Combat/CombatLog.
 */
namespace Hooks {
    namespace Combat {
        extern DWORD jumpBack;

        /**@brief patches the game, once. False if it could not be done*/
        bool install();
        bool installed();

        /**@brief why install() failed, when it did*/
        const char* status();

        void combatRecordedHook();
    }
}
