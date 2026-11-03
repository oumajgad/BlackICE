#include <Hooks/OobLeaderRanks.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryDataBase.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace {

    /**
     * **The two calls that put a leader read from a file on his unit**, both in
     * `CUnit::LoadKey`'s `leader` case and both `SetLeader(unit@ECX, leader, 0, 0)`.
     * `ebx` is the unit's CPersistent sub-object there, so ECX is `ebx - 8`.
     *
     * - `0x1B7787`: `leader = N`, a plain number looked up as `{id = N, type = 0x25}`
     *   across the whole game - what an order of battle writes;
     * - `0x1B77E7`: `leader = { id type }` - what a save writes, and what an order of
     *   battle may write too.
     *
     * reversing/findings/FINDINGS-leaderassign.md, sections 3 and 3.1.
     */
    const uintptr_t SET_LEADER_SITES[] = { 0x1B7787, 0x1B77E7 };

    /**
     * **The three calls to `CCountry::LoadOobFile`**, each `push country; call`:
     *
     * - `0x5BBD62`, in `CLoadOOBEffect::Execute` - the `load_oob` effect;
     * - `0x25B4EC`, in `CInGameIdler::Enter` - a new game's history order of battle;
     * - `0x1C3A6`, reached from `CCgmResetCurrentStageCommand::Execute` - the custom game
     *   setup's reset of its units stage.
     *
     * A save is read through none of them, which is the whole of how the fitting tells an
     * order of battle from a save. reversing/findings/FINDINGS-leaderassign.md, section 3.1.
     */
    const uintptr_t LOAD_OOB_SITES[] = { 0x5BBD62, 0x25B4EC, 0x1C3A6 };

    typedef void(__stdcall* LoadOobFile)(uintptr_t country);

    // SetLeader is __thiscall. A free function cannot be, so it is called and stood in
    // for as __fastcall: the unit in ECX the same, EDX unused by both, and the three stack
    // arguments cleaned by the callee in both - `ret 0xC`.
    typedef void(__fastcall* SetLeader)(uintptr_t unit, uintptr_t unusedEdx, uintptr_t leader,
        int resetTraitHours, int organisationHit);

    typedef void(__stdcall* AddActiveLeader)(uintptr_t country, uintptr_t leader, int record);

    LoadOobFile loadOobFile = nullptr;
    SetLeader setLeader = nullptr;
    AddActiveLeader addActiveLeader = nullptr;

    uintptr_t gameBase = 0;
    uintptr_t leaderVFTable = 0;
    uintptr_t armyVFTable = 0;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    /**
     * **How many order of battle files are being read right now.** A count rather than a
     * flag so that a file read inside another - nothing does that today - would not clear
     * it early. The game is single threaded through all three callers.
     */
    int filesLoading = 0;

    /**@brief clears the count however LoadOobFile is left, a thrown exception included*/
    struct LoadingScope
    {
        LoadingScope() { filesLoading++; }
        ~LoadingScope() { filesLoading--; }
    };

    /**@brief writes a five byte call at \p site to \p target*/
    bool writeCall(uintptr_t site, void* target) {
        unsigned char* at = reinterpret_cast<unsigned char*>(site);
        DWORD protection = 0;
        if (!VirtualProtect(at, 5, PAGE_EXECUTE_READWRITE, &protection)) {
            return false;
        }
        at[0] = 0xE8;
        *reinterpret_cast<uint32_t*>(at + 1) = static_cast<uint32_t>(
            reinterpret_cast<uintptr_t>(target) - site - 5);
        DWORD ignored = 0;
        VirtualProtect(at, 5, protection, &ignored);
        FlushInstructionCache(GetCurrentProcess(), at, 5);
        return true;
    }

    /**@brief the country with this id, the way `CCountryTag::GetCountry` reaches it*/
    uintptr_t countryById(int id) {
        uintptr_t database = 0;
        uintptr_t first = 0;
        uintptr_t last = 0;
        uintptr_t country = 0;
        if (id <= 0
            || !Mem::tryRead(gameBase + CCountryDataBase::GLOBAL_POINTER, database)
            || database == 0
            || !Mem::tryRead(database + CCountryDataBase::Offsets::countries_first, first)
            || !Mem::tryRead(database + CCountryDataBase::Offsets::countries_last, last)) {
            return 0;
        }
        const uintptr_t at = first + 4u * static_cast<unsigned>(id);
        if (first == 0 || at >= last || !Mem::tryRead(at, country)) {
            return 0;
        }
        return country;
    }

    /**@brief whether the leader is in the country's active_leaders*/
    bool inService(uintptr_t country, uintptr_t leader) {
        const std::vector<uintptr_t> active =
            HDS::walkList(country + CCountry::Offsets::active_leaders);
        for (uintptr_t each : active) {
            if (each == leader) {
                return true;
            }
        }
        return false;
    }

    /**
    @brief gives the leader the rank the unit takes, and puts him in service

    Everything that would make the game's own assignment refuse him for reasons other than
    rank is a reason to leave him as he is: not a real leader (the null leader has a
    vftable of its own), not a land leader, not a land unit, or another country's leader.
    */
    void fitLeader(uintptr_t unit, uintptr_t leader) {
        uintptr_t table = 0;
        if (!Mem::tryRead(leader, table) || table != leaderVFTable) {
            return;
        }
        if (!Mem::tryRead(unit, table) || table != armyVFTable) {
            return;
        }
        int type = -1;
        int level = -1;
        int leaderCountry = 0;
        int unitCountry = 0;
        int rank = 0;
        if (!Mem::tryRead(leader + CLeader::Offsets::type, type)
            || type != static_cast<int>(CLeader::Type::Land)
            || !Mem::tryRead(unit + CUnit::Offsets::oob_level, level)
            || !Mem::tryRead(leader + CLeader::Offsets::country + CCountryTag::Offsets::id,
                leaderCountry)
            || !Mem::tryRead(unit + CUnit::Offsets::owner + CCountryTag::Offsets::id,
                unitCountry)
            || leaderCountry != unitCountry
            || !Mem::tryRead(leader + CLeader::Offsets::rank, rank)) {
            return;
        }
        const int wanted = Hooks::OobLeaderRanks::rankFor(level);
        if (wanted == 0) {
            return;
        }
        if (rank != wanted) {
            *reinterpret_cast<int*>(leader + CLeader::Offsets::rank) = wanted;
        }

        const uintptr_t country = countryById(unitCountry);
        if (country != 0 && !inService(country, leader)) {
            addActiveLeader(country, leader, 0);
        }
    }

    /**@brief stands in for LoadOobFile, counting while it runs*/
    void __stdcall loadOobFileCounted(uintptr_t country) {
        LoadingScope scope;
        loadOobFile(country);
    }

    /**@brief stands in for SetLeader in CUnit::LoadKey, fitting the leader first when the
              key comes from an order of battle file*/
    void __fastcall setLeaderFromFile(uintptr_t unit, uintptr_t unusedEdx, uintptr_t leader,
        int resetTraitHours, int organisationHit) {
        if (filesLoading > 0) {
            fitLeader(unit, leader);
        }
        setLeader(unit, unusedEdx, leader, resetTraitHours, organisationHit);
    }
}

int Hooks::OobLeaderRanks::rankFor(int oobLevel) {
    switch (oobLevel) {
    case CUnit::Level::Division:
        return 1;
    case CUnit::Level::Corps:
        return 2;
    case CUnit::Level::Army:
        return 3;
    case CUnit::Level::ArmyGroup:
    case CUnit::Level::Theatre:
        return 4;
    default:
        return 0;
    }
}

bool Hooks::OobLeaderRanks::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    // Every site is checked before any is written, so a build where one has moved is left
    // exactly as it was.
    for (uintptr_t site : SET_LEADER_SITES) {
        if (!Hooks::isCallTo(base + site, base + CUnit::GameFunction::SetLeader)) {
            statusText = "a leader is not put on its unit where this build expects";
            ERROR_OUT(printf("OobLeaderRanks: %#010x is not the call expected\n",
                static_cast<unsigned>(base + site)));
            return false;
        }
    }
    for (uintptr_t site : LOAD_OOB_SITES) {
        if (!Hooks::isCallTo(base + site, base + CCountry::GameFunction::LoadOobFile)) {
            statusText = "an order of battle is not loaded where this build expects";
            ERROR_OUT(printf("OobLeaderRanks: %#010x is not the call expected\n",
                static_cast<unsigned>(base + site)));
            return false;
        }
    }

    gameBase = base;
    leaderVFTable = base + CLeader::VFTable::CLeader;
    armyVFTable = base + CUnit::VFTable::CArmy;
    loadOobFile = reinterpret_cast<LoadOobFile>(base + CCountry::GameFunction::LoadOobFile);
    setLeader = reinterpret_cast<SetLeader>(base + CUnit::GameFunction::SetLeader);
    addActiveLeader = reinterpret_cast<AddActiveLeader>(
        base + CCountry::GameFunction::AddActiveLeader);

    for (uintptr_t site : SET_LEADER_SITES) {
        if (!writeCall(base + site, reinterpret_cast<void*>(&setLeaderFromFile))) {
            statusText = "could not make the code writable";
            return false;
        }
    }
    for (uintptr_t site : LOAD_OOB_SITES) {
        if (!writeCall(base + site, reinterpret_cast<void*>(&loadOobFileCounted))) {
            statusText = "could not make the code writable";
            return false;
        }
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::OobLeaderRanks::installed() {
    return installedFlag;
}

const char* Hooks::OobLeaderRanks::status() {
    return statusText;
}
