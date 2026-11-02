#pragma once
#include <cstdint>

/**
 * CRankChange - one `rank = N` line of a leader's `history` block.
 *
 * Built only by `CLeaderHistory::LoadEntry`, 0x18 bytes, and held in the leader's history
 * entries (CLeader::Offsets::history_entries) beside the skill, loyalty and trait lines.
 * It is the only history entry whose slot 6 answers the `rank` save token, 0x10A - which
 * is what the daily pass looks for to bring a leader into service.
 *
 * reversing/findings/FINDINGS-leaders.md, section 3.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CRankChange {
    namespace Offsets {
        /**@brief the line's date, in the engine's hours. **Inferred** from the daily pass
                  comparing it with today*/
        constexpr uintptr_t date = 0x8;

        /**@brief the CLeader the line is about*/
        constexpr uintptr_t leader = 0xC;

        /**@brief the rank the line names, as written*/
        constexpr uintptr_t rank = 0x10;

        /**@brief the rank `Apply` replaced, kept for its undo; never saved*/
        constexpr uintptr_t previous_rank = 0x14;
    }

    namespace VFTable {
        constexpr uintptr_t CRankChange = 0x11C9EB0;   // module relative, RTTI
    }

    constexpr uintptr_t SIZE = 0x18;
}
