#pragma once
#include <string>

/**
 * Sets how many units an army group, an army and a corps may command, per country, with
 * leader traits that raise or lower it - in place of the game's five.
 *
 * `CUnit_MayTakeSubordinate` (`0x1B96B0`) counts the commander's subordinates into
 * `[ebp+0x8]` - the subordinate's own argument slot, reused once EBX holds it - and refuses
 * one more at five: `cmp dword ptr [ebp+0x8], 5; pop edi` at `0x1B9733`, five bytes, with
 * EBX the unit to attach and EDI the last subordinate counted. A commander with no
 * subordinates leaves at `0x1B9705` (`test esi, esi; je`, answering true) before the loop,
 * so EDI is always a unit here. The hook compares against a limit of its own instead, then
 * replays the `pop edi`; the `jl` after it reads the flags as before.
 *
 * ## The limit
 *
 * The level of the commander (ECX's superior) picks one of three limits - the country's
 * own where one is set, otherwise the default - plus every command limit trait its leader
 * holds, plus the brigades it already commands, which are held as one-brigade divisions and
 * are meant not to count. A one-brigade division being attached is always allowed.
 *
 * ## Multiplayer
 *
 * Reads only the units and the limits, and the limits are set from Lua on every machine by
 * the same script (`CheckOobUnitLimitTechnologyStatus`), so every machine answers alike.
 *
 * reversing/findings/FINDINGS-bicelibsites.md, section 6, has the loop.
 *
 * **Switched on from Lua** by the first `BiceLib.Units.set*UnitLimit` or
 * `addCommandLimitTrait`.
 */
namespace Hooks {
    namespace UnitAttachmentLimit {
        /**@brief the three levels a limit is set for*/
        enum class Level { ArmyGroup, Army, Corps };

        /**@brief hooks the test, once; safe to call again*/
        bool install();

        /**@brief the limit for every country without one of its own; 5 until set*/
        void setDefault(Level level, int limit);

        /**@brief the country's own limit; 0 goes back to the default. Ignores an id past 300*/
        void setForCountry(Level level, int countryId, int limit);

        /**@brief the country's own limit, 0 where it has none or the id is out of range*/
        int countryLimit(Level level, int countryId);

        /**@brief what a leader with this trait adds to the limit of the unit he commands*/
        void addCommandLimitTrait(const std::string& traitName, int effect);

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
