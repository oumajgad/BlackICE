#include <Hooks/HistoryLeaderRanks.hpp>

#include <GameClasses/CLeader.hpp>
#include <GameClasses/CRankChange.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <vector>

namespace {

    /**
     * **Where the daily pass gives a leader coming into service rank 1**:
     * `mov dword ptr [edi + 0x6C], 1`, seven bytes, EDI the leader and EBX the country.
     * The append to `active_leaders` follows at the next instruction.
     *
     * The only branch into these seven bytes is the `je` at `0xDAAB3` - the case of a
     * country with nobody in service - and it lands on the first byte, which is where the
     * jump goes. reversing/findings/FINDINGS-leaders.md, section 3.
     */
    const uintptr_t STORE_SITE = 0xDAACE;
    const unsigned char STORE_BYTES[7] = { 0xC7, 0x47, 0x6C, 0x01, 0x00, 0x00, 0x00 };
    const uintptr_t STORE_RESUME = 0xDAAD5;

    const int LOWEST_RANK = 1;
    const int HIGHEST_RANK = 4;

    uintptr_t rankChangeVFTable = 0;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stub, which is why it is a plain word.
    DWORD storeResume = 0;

    /**
    @brief the rank the leader's first `rank` line names, held to 1 to 4; 1 if he has none

    The first CRankChange in list order, which is the entry the daily pass matched: it
    walks the same list and stops at the first entry answering the `rank` save token.
    */
    int historyRank(uintptr_t leader) {
        const std::vector<uintptr_t> entries =
            HDS::walkList(leader + CLeader::Offsets::history_entries);
        for (uintptr_t entry : entries) {
            uintptr_t table = 0;
            if (!Mem::tryRead(entry, table) || table != rankChangeVFTable) {
                continue;
            }
            int rank = LOWEST_RANK;
            if (!Mem::tryRead(entry + CRankChange::Offsets::rank, rank)) {
                return LOWEST_RANK;
            }
            if (rank < LOWEST_RANK) {
                return LOWEST_RANK;
            }
            if (rank > HIGHEST_RANK) {
                return HIGHEST_RANK;
            }
            return rank;
        }
        return LOWEST_RANK;
    }

    /**@brief what the store wrote, with the rank the history names in place of 1*/
    void __stdcall giveHistoryRank(uintptr_t leader) {
        *reinterpret_cast<int*>(leader + CLeader::Offsets::rank) = historyRank(leader);
    }

    /**
    @brief stands in for the store; the registers and flags are the pass's again after

    Nothing after the store reads the flags it left - it is a `mov` - but they are kept all
    the same, as every stub here keeps them.
    */
    __declspec(naked) void storeReached() {
        __asm {
            pushad
            pushfd
            push edi                        // the leader
            call giveHistoryRank
            popfd
            popad
            jmp [storeResume]
        }
    }
}

bool Hooks::HistoryLeaderRanks::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + STORE_SITE, STORE_BYTES, 7)) {
        statusText = "the daily pass does not give rank 1 where this build expects";
        ERROR_OUT(printf("HistoryLeaderRanks: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + STORE_SITE)));
        return false;
    }

    rankChangeVFTable = base + CRankChange::VFTable::CRankChange;
    storeResume = static_cast<DWORD>(base + STORE_RESUME);

    if (!Hooks::hook(reinterpret_cast<void*>(base + STORE_SITE), &storeReached, 5, 2)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::HistoryLeaderRanks::installed() {
    return installedFlag;
}

const char* Hooks::HistoryLeaderRanks::status() {
    return statusText;
}
