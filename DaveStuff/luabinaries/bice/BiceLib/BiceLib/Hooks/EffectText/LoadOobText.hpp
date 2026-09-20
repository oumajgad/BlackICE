#pragma once

/**
 * What `load_oob` shows in an event option's tooltip, which was a file path and nothing
 * else.
 *
 * The effect looks its own path up as though it were a localisation key, finds nothing,
 * and shows the path. **There is no key to fill in**, so this writes the whole line
 * instead: how many units appear and where, what they are made of, and which leaders
 * the file takes - with what each of those commands now, which is the part a player
 * cannot find out any other way.
 *
 * Nothing about the file is in memory until the effect fires - it opens and parses it
 * there and then - so the file is read off disk the same way the game will read it. See
 * GameState/OobFile.hpp.
 *
 * **A leader whose rank is below the job gets a red line.** The rule is the order of
 * battle's own levels - a division is a major general's, a corps a lieutenant general's,
 * and everything above a corps a general's - and it is David's choice, made against the
 * numbers rather than assumed: across the mod's own `history/units`, corps are led by a
 * rank 1 leader 613 times of 844, so the warning is meant to fire on those. Fleets and
 * air commands are left out, because their levels do not line up with the land ones.
 *
 * The engine has no such rule to copy - its only rank defines, `AIR_RANK_1..4` and
 * `NAVAL_RANK_1..4`, are command limits, not level requirements.
 *
 * Two stubs: one at the text builder's entry to catch the effect, and one at the last
 * call before it returns, where the built string is in hand and can be replaced. See
 * EffectText.hpp for the shared parts, and reversing/FINDINGS-effecttext.md for the
 * addresses.
 *
 * **Switched on from Lua**: `BiceLib.EffectTexts.activateLoadOobDetails()`.
 */
namespace Hooks {
    namespace EffectText {
        namespace LoadOob {
            /**@brief patches the effect's two sites, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
