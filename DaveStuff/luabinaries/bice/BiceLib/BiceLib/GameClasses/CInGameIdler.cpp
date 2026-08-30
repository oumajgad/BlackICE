#include <GameClasses/CInGameIdler.hpp>

#include <GameClasses/CCurrentGameState.hpp>
#include <MemScan.hpp>

namespace {
    /**
    @brief the live CInGameIdler, checked against its own vftable

    Reached through the game state rather than by scanning, and only answered when the
    object there carries this class's vftable. That check is what makes calling a slot
    by index safe: it says the table being indexed is the one the index was taken
    from.
    */
    uintptr_t liveIdler() {
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        const uintptr_t state = CCurrentGameState::current();
        if (base == 0 || state == 0) {
            return 0;
        }

        uint32_t idler = 0;
        if (!Mem::tryRead(state + CCurrentGameState::Offsets::in_game_screen, idler)
            || idler == 0) {
            return 0;
        }

        uint32_t vftable = 0;
        if (!Mem::tryRead(idler, vftable)
            || vftable != base + CInGameIdler::VFTable::CInGameIdler) {
            return 0;
        }
        return idler;
    }
}

bool CInGameIdler::centreOnProvince(uintptr_t province) {
    if (province == 0) {
        return false;
    }

    const uintptr_t idler = liveIdler();
    if (idler == 0) {
        return false;
    }

    uint32_t vftable = 0;
    if (!Mem::tryRead(idler, vftable) || vftable == 0) {
        return false;
    }

    uint32_t target = 0;
    if (!Mem::tryRead(vftable + Slots::CENTRE_ON_PROVINCE * 4, target) || target == 0) {
        return false;
    }

    // The province is read by the game before anything is moved, so a pointer that is
    // not one would fault inside it rather than here. Checked for the same reason the
    // vftable is: this is a raw call into the game.
    uint32_t provinceVftable = 0;
    if (!Mem::tryRead(province, provinceVftable) || provinceVftable == 0) {
        return false;
    }

    // thiscall: the idler in ecx, the province pushed. Exactly how the unit panel's
    // own location button calls it.
    __asm {
        mov ecx, idler
        mov eax, province
        push eax
        mov eax, target
        call eax
    }
    return true;
}
