#include <Hooks/UnitAttachmentLimit.hpp>

#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/CTrait.hpp>
#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <unordered_map>

namespace {
    // cmp dword ptr [ebp+0x8], 5; pop edi
    const uintptr_t SITE = 0x1B9733;
    const unsigned char SITE_BYTES[5] = { 0x83, 0x7D, 0x08, 0x05, 0x5F };

    const int GAME_LIMIT = 5;
    const int ALWAYS = 999;

    // Indexed by country id. BlackICE has 107 tags; the bound is checked all the same.
    const int MAX_COUNTRIES = 300;
    const int LEVELS = 3;

    int defaults[LEVELS] = { GAME_LIMIT, GAME_LIMIT, GAME_LIMIT };
    int perCountry[LEVELS][MAX_COUNTRIES] = {};     // 0 is "the default"

    std::unordered_map<std::string, int> commandLimitTraits;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stub, which is why it is a plain word.
    DWORD resume = 0;

    int levelIndex(Hooks::UnitAttachmentLimit::Level level) {
        return static_cast<int>(level);
    }

    /**@brief which of the three a unit's oob_level is, or -1 for a division*/
    int levelOf(int oobLevel) {
        switch (oobLevel) {
            case CUnit::Level::ArmyGroup: return levelIndex(Hooks::UnitAttachmentLimit::Level::ArmyGroup);
            case CUnit::Level::Army: return levelIndex(Hooks::UnitAttachmentLimit::Level::Army);
            case CUnit::Level::Corps: return levelIndex(Hooks::UnitAttachmentLimit::Level::Corps);
            default: return -1;
        }
    }

    /**@brief a brigade on its own, which the game holds as a one-brigade division*/
    bool loneBrigade(uintptr_t unit) {
        return Mem::readOr<int32_t>(unit + CUnit::Offsets::regiments + HDS::ListOffsets::count) == 1
            && Mem::readOr<int32_t>(unit + CUnit::Offsets::oob_level) == CUnit::Level::Division;
    }

    int traitsEffect(uintptr_t leader) {
        int effect = 0;
        for (uintptr_t trait : HDS::walkList(leader + CLeader::Offsets::traits)) {
            const auto found = commandLimitTraits.find(HDS::readString(trait + CTrait::Offsets::name));
            if (found != commandLimitTraits.end()) {
                effect += found->second;
            }
        }
        return effect;
    }

    int loneBrigadesUnder(uintptr_t commander) {
        int count = 0;
        for (uintptr_t unit : HDS::walkList(commander + CUnit::Offsets::children)) {
            if (loneBrigade(unit)) {
                count++;
            }
        }
        return count;
    }

    /**@brief the limit to compare the commander's count against; see the header*/
    int __stdcall limitFor(uintptr_t unitToAttach, uintptr_t lastCounted) {
        if (loneBrigade(unitToAttach)) {
            return ALWAYS;
        }
        // Never 0: the function returns at 0x1B9705 before the loop without subordinates
        const uintptr_t commander = Mem::readOr<uint32_t>(lastCounted + CUnit::Offsets::higher_oob_unit_ptr);
        if (commander == 0) {
            return GAME_LIMIT;
        }

        int limit = GAME_LIMIT;
        const int level = levelOf(Mem::readOr<int32_t>(commander + CUnit::Offsets::oob_level));
        if (level >= 0) {
            const int id = Mem::readOr<int32_t>(unitToAttach + CUnit::Offsets::owner + CCountryTag::Offsets::id, -1);
            const int own = (id >= 0 && id < MAX_COUNTRIES) ? perCountry[level][id] : 0;
            limit = own != 0 ? own : defaults[level];
        }

        const uintptr_t leader = Mem::readOr<uint32_t>(commander + CUnit::Offsets::leader_ptr);
        if (leader != 0) {
            limit += traitsEffect(leader);
        }
        return limit + loneBrigadesUnder(commander);
    }

    /**
    @brief the count against our limit, then the `pop edi` replaced

    The last subordinate counted is EDI, which the loop loads from each node
    (`mov edi, [esi]`). It used to be taken from ECX, which holds the same unit only
    because it was `this` for the virtual call each pass makes - a register the callee may
    leave anything in.
    */
    __declspec(naked) void testStub() {
        __asm {
            pushad
            push edi                        // the last subordinate counted
            push ebx                        // the unit to attach
            call limitFor
            cmp dword ptr [ebp + 0x8], eax  // the count against our limit
            popad                           // leaves the flags alone
            pop edi                         // the rest of the bytes replaced
            jmp [resume]
        }
    }
}

bool Hooks::UnitAttachmentLimit::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    resume = static_cast<DWORD>(base + SITE + sizeof(SITE_BYTES));
    if (!Hooks::hookAt(base + SITE, &testStub, SITE_BYTES, sizeof(SITE_BYTES))) {
        statusText = Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof(SITE_BYTES))
            ? "could not make the code writable"
            : "the subordinate test is not what this build expects";
        return false;
    }
    installedFlag = true;
    statusText = "installed";
    return true;
}

void Hooks::UnitAttachmentLimit::setDefault(Level level, int limit) {
    defaults[levelIndex(level)] = limit;
}

void Hooks::UnitAttachmentLimit::setForCountry(Level level, int countryId, int limit) {
    if (countryId >= 0 && countryId < MAX_COUNTRIES) {
        perCountry[levelIndex(level)][countryId] = limit;
    }
}

int Hooks::UnitAttachmentLimit::countryLimit(Level level, int countryId) {
    if (countryId < 0 || countryId >= MAX_COUNTRIES) {
        return 0;
    }
    return perCountry[levelIndex(level)][countryId];
}

void Hooks::UnitAttachmentLimit::addCommandLimitTrait(const std::string& traitName, int effect) {
    if (commandLimitTraits.emplace(traitName, effect).second) {
        INFO_OUT(printf("UnitAttachmentLimit: trait '%s' changes the limit by %d\n",
            traitName.c_str(), effect));
    }
}

bool Hooks::UnitAttachmentLimit::installed() {
    return installedFlag;
}

const char* Hooks::UnitAttachmentLimit::status() {
    return statusText;
}
