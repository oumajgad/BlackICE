#include <Hooks/RankSpecificTraits.hpp>

#include <GameClasses/CLeader.hpp>
#include <GameClasses/CTrait.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <vector>

namespace {
    const char* const PREFIX = "rankSpecificTrait_";

    // mov [edi+0x6C], eax; cmp [edi+0x68], ebx
    const uintptr_t RANK_SITE = 0x1D7CDC;
    const unsigned char RANK_BYTES[6] = { 0x89, 0x47, 0x6C, 0x39, 0x5F, 0x68 };

    // add ecx, 0x2C; lea edi, [esp+0xC]
    const uintptr_t SAVE_SITE = 0x17FF08;
    const unsigned char SAVE_BYTES[7] = { 0x83, 0xC1, 0x2C, 0x8D, 0x7C, 0x24, 0x0C };

    // A leader holds a handful of traits; this only stops a list that is not one.
    const int MAX_TRAITS = 1024;

    struct Pair
    {
        int lowestRank;
        int highestRank;
        uintptr_t activeTrait;
        uintptr_t inactiveTrait;
    };

    std::vector<Pair> pairs;
    std::unordered_map<std::string, size_t> byActiveName;
    std::unordered_map<std::string, size_t> byInactiveName;

    bool installedFlag = false;
    bool activeFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, which is why they are plain words.
    DWORD rankResume = 0;
    DWORD saveResume = 0;

    // What a rank-specific trait is saved as: a one-character string in the game's own
    // layout, inline because it is shorter than sixteen.
    HDS::Hoi3CString blank = { " ", 1 };

    bool rankSpecific(const std::string& name) {
        return name.compare(0, strlen(PREFIX), PREFIX) == 0;
    }

    /**@brief the trait that belongs in a node now, or 0 to leave it*/
    uintptr_t swapFor(const std::string& name, int rank) {
        const auto active = byActiveName.find(name);
        if (active != byActiveName.end()) {
            const Pair& pair = pairs[active->second];
            const bool inRange = rank >= pair.lowestRank && rank <= pair.highestRank;
            return inRange ? 0 : pair.inactiveTrait;
        }
        const auto inactive = byInactiveName.find(name);
        if (inactive != byInactiveName.end()) {
            const Pair& pair = pairs[inactive->second];
            const bool inRange = rank >= pair.lowestRank && rank <= pair.highestRank;
            return inRange ? pair.activeTrait : 0;
        }
        WARNING_OUT(printf("RankSpecificTraits: '%s' was not declared from Lua\n", name.c_str()));
        return 0;
    }

    /**
    @brief swaps each of the leader's pairs to the half \p rank calls for

    Walked by hand rather than through HDS::walkList, because a swap writes the node.
    */
    void matchRank(uintptr_t leader, int rank) {
        uintptr_t node = Mem::readOr<uint32_t>(leader + CLeader::Offsets::traits + HDS::ListOffsets::first);
        for (int steps = 0; node != 0 && steps < MAX_TRAITS; steps++) {
            const uintptr_t trait = Mem::readOr<uint32_t>(node + HDS::NodeOffsets::data);
            const std::string name = HDS::readString(trait + CTrait::Offsets::name);
            if (rankSpecific(name)) {
                const uintptr_t replacement = swapFor(name, rank);
                if (replacement != 0) {
                    *reinterpret_cast<uintptr_t*>(node + HDS::NodeOffsets::data) = replacement;
                    DEBUG_OUT(printf("RankSpecificTraits: '%s' swapped at rank %d for '%s'\n",
                        name.c_str(), rank,
                        HDS::readString(leader + CLeader::Offsets::name).c_str()));
                }
            }
            node = Mem::readOr<uint32_t>(node + HDS::NodeOffsets::next);
        }
    }

    void __stdcall rankChanging(uintptr_t leader, int rank) {
        if (activeFlag) {
            matchRank(leader, rank);
        }
    }

    /**@brief the string the save writes for \p trait: its name, or the blank*/
    uintptr_t __stdcall savedName(uintptr_t trait) {
        const uintptr_t name = trait + CTrait::Offsets::name;
        if (activeFlag && rankSpecific(HDS::readString(name))) {
            return reinterpret_cast<uintptr_t>(&blank);
        }
        return name;
    }

    /**@brief before the new rank is stored; the six bytes replayed after*/
    __declspec(naked) void rankStub() {
        __asm {
            pushad
            pushfd
            push eax                        // the new rank
            push edi                        // the leader
            call rankChanging
            popfd
            popad
            mov [edi + 0x6C], eax
            cmp [edi + 0x68], ebx           // its flags are the ones the jne after reads
            jmp [rankResume]
        }
    }

    /**@brief stands in for `add ecx, 0x2C`: ECX becomes the string to write*/
    __declspec(naked) void saveStub() {
        __asm {
            pushad
            pushfd
            push ecx                        // the trait
            call savedName
            mov [esp + 0x1C], eax           // over the ecx pushad saved
            popfd
            popad
            lea edi, [esp + 0xC]
            jmp [saveResume]
        }
    }
}

bool Hooks::RankSpecificTraits::add(const std::string& activeName,
    const std::string& inactiveName, int lowestRank, int highestRank) {
    if (byActiveName.count(activeName) != 0) {
        return true;
    }
    if (CTrait::count() == 0) {
        INFO_OUT(printf("RankSpecificTraits: '%s' waits until the traits are loaded\n",
            activeName.c_str()));
        return false;
    }
    const uintptr_t activeTrait = CTrait::findByName(activeName);
    const uintptr_t inactiveTrait = CTrait::findByName(inactiveName);
    if (activeTrait == 0 || inactiveTrait == 0) {
        ERROR_OUT(printf("RankSpecificTraits: '%s' or '%s' is not a trait\n",
            activeName.c_str(), inactiveName.c_str()));
        return false;
    }

    pairs.push_back(Pair{ lowestRank, highestRank, activeTrait, inactiveTrait });
    byActiveName[activeName] = pairs.size() - 1;
    byInactiveName[inactiveName] = pairs.size() - 1;
    INFO_OUT(printf("RankSpecificTraits: '%s' / '%s' for ranks %d to %d\n",
        activeName.c_str(), inactiveName.c_str(), lowestRank, highestRank));
    return true;
}

bool Hooks::RankSpecificTraits::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + RANK_SITE, RANK_BYTES, sizeof(RANK_BYTES))
        || !Hooks::bytesAre(base + SAVE_SITE, SAVE_BYTES, sizeof(SAVE_BYTES))) {
        statusText = "the promotion or the leader save is not what this build expects";
        return false;
    }

    rankResume = static_cast<DWORD>(base + RANK_SITE + sizeof(RANK_BYTES));
    saveResume = static_cast<DWORD>(base + SAVE_SITE + sizeof(SAVE_BYTES));
    if (!Hooks::hookAt(base + RANK_SITE, &rankStub, RANK_BYTES, sizeof(RANK_BYTES))
        || !Hooks::hookAt(base + SAVE_SITE, &saveStub, SAVE_BYTES, sizeof(SAVE_BYTES))) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::RankSpecificTraits::activate() {
    if (!activeFlag && installedFlag && CTrait::count() != 0) {
        activeFlag = true;
        INFO_OUT(printf("RankSpecificTraits: on\n"));
    }
    return activeFlag;
}

void Hooks::RankSpecificTraits::checkAllLeaders() {
    if (!activeFlag) {
        return;
    }
    for (uintptr_t leader : ::CLeader::all()) {
        matchRank(leader, Mem::readOr<int32_t>(leader + ::CLeader::Offsets::rank));
    }
}

bool Hooks::RankSpecificTraits::installed() {
    return installedFlag;
}

bool Hooks::RankSpecificTraits::active() {
    return activeFlag;
}

const char* Hooks::RankSpecificTraits::status() {
    return statusText;
}
