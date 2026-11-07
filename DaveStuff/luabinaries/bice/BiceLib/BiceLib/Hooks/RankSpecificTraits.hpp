#pragma once
#include <string>

/**
 * Rank-specific traits: a trait that only does anything while its leader holds one of a
 * range of ranks.
 *
 * Each is a **pair of traits** the mod defines, both named `rankSpecificTrait_...`: an
 * active one carrying the effects and an inactive one carrying none. A leader holds one of
 * the two, and whenever his rank changes the one he holds is swapped for the other where
 * the new rank is inside or outside the pair's range - in place, in his trait list, so the
 * game sees an ordinary trait.
 *
 * **Switched off in BlackICE** (`script/bicelib_lua.lua` has the calls commented out), and
 * kept by the maintainer's word of 2026-11-06. Cleaned up out of `CLeaderHooks.cpp` on
 * 2026-11-07 without changing what it does; the skill loss on promotion that shared that
 * file and its rank hook was deleted.
 *
 * ## The two hooks
 *
 * | rva | in | what |
 * | --- | --- | --- |
 * | `0x1D7CDC` | `CPromoteLeaderCommand::Execute` | `mov [edi+0x6C], eax; cmp [edi+0x68], ebx` - the new rank stored, EDI the leader. The pair is checked first, then the six bytes replayed |
 * | `0x17FF08` | `CLeader::SaveContents` | `add ecx, 0x2C; lea edi, [esp+0xC]` - ECX the trait, turned into its name for the save. A rank-specific trait is written as `" "` instead |
 *
 * **So a rank-specific trait is never saved**, and a loaded leader holds neither of the
 * pair until something gives it to him again. That is how it was written; it is recorded
 * here, not judged.
 *
 * ## Multiplayer
 *
 * The swap runs inside the promotion command's Execute, on every machine, from the leader
 * and the rank alone - nothing local - so every machine makes the same swap.
 *
 * reversing/findings/FINDINGS-bicelibsites.md, section 2, has both sites.
 */
namespace Hooks {
    namespace RankSpecificTraits {
        /**
        @brief declares a pair; false while the traits are not loaded yet, or when a name
               is not a trait

        Safe to call again for the same active name, which is ignored. Ranks are inclusive.
        */
        bool add(const std::string& activeName, const std::string& inactiveName,
            int lowestRank, int highestRank);

        /**@brief installs both hooks, once; safe to call again*/
        bool install();

        /**
        @brief starts swapping, once the traits are loaded

        Before that a rank change does nothing here, which is what deferring meant in the
        old code: the first Lua state runs before the traits exist, and a later one after.
        @returns whether it is on
        */
        bool activate();

        /**@brief swaps every leader's pair to match the rank he holds now*/
        void checkAllLeaders();

        bool installed();
        bool active();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
