#pragma once
#include <cstdint>
#include <string>
#include <unordered_map>
#include <lua.hpp>

/**
 * The save path settles what several of these are: `CLeader::SaveContents` (`0x17FDB0`) and
 * `CLeader::LoadKey` (`0x17F800`) carry `id`, `name`, `type`, `rank`, `country`, `skill`,
 * `max_skill`, `loyalty`, `experience`, `current_experience`, `picture`, `trait`,
 * `add_trait`, `gainable_trait` and `history`. **Read live** across 8000 leaders.
 */
namespace CLeader {
    namespace Offsets {
        constexpr uintptr_t id_type = 0x8;           // type half of the save's `id` pair
        constexpr uintptr_t id = 0xC;
        constexpr uintptr_t traits = 0x30;           // a list (HDS::ListOffsets) of CTrait*
        constexpr uintptr_t unit_ptr = 0x40;

        /**@brief a CCountryTag, saved as `country`. **Read live**: the tags read back on all
           8000 leaders*/
        constexpr uintptr_t country = 0x44;

        constexpr uintptr_t name = 0x4C;             // a Hoi3CString

        /**@brief saved as `type`, and **0 land, 1 sea, 2 air**: matching 7296 leaders to
           `history/leaders/*.txt` on country and id, every `type = land` is 0, every
           `type = sea` is 1 and every `type = air` is 2, with no exceptions*/
        constexpr uintptr_t type = 0x68;

        /**@brief saved as `rank`. **Read live**: 0 to 4, which is why the rank factor table
           in AddExperience has five slots*/
        constexpr uintptr_t rank = 0x6C;
        constexpr uintptr_t skill = 0x70;
        constexpr uintptr_t max_skill = 0x74;

        /**
         * **One 64-bit value, not two words.** The loader reads `current_experience` with
         * `%lld` straight into these eight bytes, and `AddExperience` (`0x181CE0`) adds to
         * them with `add`/`adc` and compares them against the promotion threshold as a pair.
         * So `experience` and `experience_2` are the low and high halves of one number in
         * the game's 48.15 fixed point, where 32768 is 1. It is a career total, not a
         * per-level count.
         *
         * **The high half can be reached.** The threshold table at `0x130AEE4` holds 1000,
         * 2000, 4000, 8000, 12000, 18000, 25000, 33000, 43000 and 60000 for skills 0 to 9 -
         * the same figures as `Hooks/CLeaderHooks.cpp` once shifted by 15 - and then
         * **100000000 for skill 10**, which is 3276800000000 shifted and can never be
         * reached. So 10 is the real ceiling, not the `skill >= 12` guard at the top of
         * AddExperience. But that guard is the only thing that stops the adding, and it
         * never fires, so **a leader parked at skill 10 keeps accruing for ever**: the total
         * passes 2^31 after another 5536 experience points and 2^32 after 71000, and the
         * high half stops being zero.
         *
         * **Read live** on 8000 leaders in a 1942 game: every high half is zero, and the
         * largest total is 809977445 - 38% of the way to 2^31. So the low word on its own is
         * right for now, and reading it *signed* is what would break first.
         */
        constexpr uintptr_t current_experience = 0x78;
        constexpr uintptr_t experience = 0x78;       // kept: the low half of the pair above
        constexpr uintptr_t experience_2 = 0x7C;     // the high half

        /**@brief saved as `loyalty`, x1000. **Read live**: 1000 on 5107 of 8000 leaders and
           0 on 2825, so it carries a real value*/
        constexpr uintptr_t loyalty = 0x80;

        /**@brief a CLeaderHistory held by value - not a pointer - saved as `history` through
           its own Load and Save. **Read live**: a CLeaderHistory by its own RTTI*/
        constexpr uintptr_t history = 0x84;

        /**@brief the leader's portrait, a std::string, saved as `picture`. **Read live**:
           `L54027`, and `empty_position` on the null leader*/
        constexpr uintptr_t picture = 0xA8;

        /**
         * **The skill and experience the leader was defined with.** The `skill` handler
         * writes +0xC8 as well, but only while it is still negative, so it keeps the first
         * value; +0xCC takes the save's `experience` key in whole points.
         *
         * `ResetToStarting` (`0x181E10`) is what they are for: it sets `rank` to 0, puts
         * +0xC8 back into `skill` and converts +0xCC into the 48.15 `current_experience`.
         * Nothing here is a skill *loss* mechanic - the game has none, and +0xC8 is never
         * above the current skill.
         *
         * **It holds the skill the mod's files define.** Matching 7296 live leaders to
         * `history/leaders/*.txt` on country and id: +0xC8 is the file's `skill` on **every
         * one of them**, including the 1117 whose current skill has since risen above it.
         * 6179 are still at it and **none is below it** - so a leader never ends up worse
         * than defined.
         *
         * Nothing in the executable decrements a leader's skill: there is not one
         * `dec`/`sub` against +0x70 in the image, and the only path that can lower it is
         * `ResetToStarting`, called from a single loop over `CCountry::Offsets::leaders`
         * inside an unnamed routine at `0xD2B60` (itself called from two places). Even that
         * resets *to* the definition rather than below it. +0xCC is zero on all 8000.
         */
        constexpr uintptr_t starting_skill = 0xC8;
        constexpr uintptr_t starting_experience = 0xCC;
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x17FDB0;  // slot 2
        constexpr uintptr_t LoadKey = 0x17F800;       // slot 4

        /**
         * **Gives a leader experience and promotes him when he has enough**, the leader in
         * esi. It does nothing at all while `skill >= 12`, scales the gain by
         * `1 + (max_skill - skill)^2 / 5` - so a leader far below his maximum gains much
         * faster - and divides the lot by 3 once he is at or past that maximum. Then it adds
         * to `current_experience` as a 64-bit pair and compares it, also as a pair, against
         * `SKILL_THRESHOLDS[skill]` shifted into fixed point.
         */
        constexpr uintptr_t AddExperience = 0x181CE0;

        /**
         * **Rank does not change how fast a leader learns.** AddExperience multiplies the
         * gain by `RANK_FACTOR[rank]`, but that table is a *function-local static* - five
         * 64-bit slots at `0x17EB6E8` behind the one-byte "have I built this yet" guard at
         * `0x17EB710` - and the constructor fills all five with the same number, the double
         * `32768.5` at `0x120A548` truncated to **32768, which is exactly 1.0** in the 48.15
         * fixed point. The half is there so the truncating conversion lands on 32768 rather
         * than 32767.
         *
         * **Read live**: all five slots are 32768 and the guard is 1. **Nothing else in the
         * executable touches the array** - ten writes for the one-time fill and two reads
         * for the lookup, all inside AddExperience - so the per-rank factor is 1.0 for every
         * rank and always will be.
         */
        constexpr uintptr_t RANK_FACTOR = 0x17EB6E8;
        constexpr uintptr_t RANK_FACTOR_BUILT = 0x17EB710;

        /**@brief puts a leader back to `starting_skill` and `starting_experience` with rank
           0; the leader in eax*/
        constexpr uintptr_t ResetToStarting = 0x181E10;
    }

    namespace Global {
        /**@brief **the experience each skill needs**, ints indexed by the current skill and
           shifted left 15 into the 48.15 fixed point before the comparison: 1000, 2000,
           4000, 8000, 12000, 18000, 25000, 33000, 43000, 60000 for skills 0 to 9, then
           100000000 for skill 10 - a figure no leader can reach, which is what caps the
           skill at 10*/
        constexpr uintptr_t SKILL_THRESHOLDS = 0x130AEE4;
    }

    /**@brief what `type` holds, proven against the leader files*/
    enum class Type { Land = 0, Sea = 1, Air = 2 };

    /**@brief `land`, `sea`, `air`, or `unknown` for anything else*/
    const char* typeName(int type);

    struct CLeader
    {
        uintptr_t _address;
        unsigned int id;
        uintptr_t trait_ll_start;
        uintptr_t trait_ll_end;
        int number_of_traits;
        uintptr_t unit_ptr;
        // By value: the game's copy is Windows-1252 and lives at the game's pleasure,
        // so it is converted and copied out rather than pointed at.
        std::string country;
        int country_id;
        std::string name;
        std::string picture;
        int type;
        int rank;
        int skill;
        int max_skill;

        /**@brief the skill the leader was defined with; `skill` never falls below it*/
        int starting_skill;

        /**
         * **One 64-bit value.** The game reads it with `%lld` and adds to it with
         * `add`/`adc`, so the old pair of `experience` and `experience_2` words was always
         * the low and high halves of this. The 48.15 fixed point, where 32768 is 1, and a
         * career total rather than a per-level count.
         */
        long long experience;

        /**@brief the experience the leader was defined with, in whole points*/
        int starting_experience;

        int loyalty;
    };

    namespace VFTable {
        constexpr uintptr_t CLeader = 0x11C5220;   // module relative, RTTI, 10 slots
    }

    extern std::unordered_map<unsigned int, uintptr_t>* leaderCache;

    CLeader Make(uintptr_t addr);
    void CacheLeaders();
    CLeader GetLeaderById(unsigned int id);
    void PushCLeaderToStack(lua_State* L, CLeader leader);
}