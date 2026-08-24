#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace {
    uintptr_t moduleBase() {
        static uintptr_t base = 0;
        if (base == 0) {
            base = Mem::moduleBase("hoi3_tfh.exe");
        }
        return base;
    }

    /**
    @brief is this address really a unit

    The consumption functions below dereference what they are given without checking
    any of it, so the vftable is checked here first: a stale pointer that no longer
    holds a unit takes the game down otherwise.
    */
    bool isUnit(uintptr_t unit) {
        const uintptr_t base = moduleBase();
        if (unit == 0 || base == 0) {
            return false;
        }
        uint32_t vftable = 0;
        if (!Mem::tryRead(unit, vftable)) {
            return false;
        }
        return vftable == base + CUnit::VFTable::CArmy
            || vftable == base + CUnit::VFTable::CNavy
            || vftable == base + CUnit::VFTable::CAir;
    }
}

namespace CUnit {
    int supplyConsumption(uintptr_t unit, bool withoutLeaders) {
        if (!isUnit(unit)) {
            return 0;
        }

        // int __stdcall f(CUnit* unit, int* out, bool withoutLeaders), which writes
        // the answer through that pointer and hands it back. Arguments right to
        // left, and it clears its own twelve bytes off the stack.
        const uintptr_t function = moduleBase() + GameFunction::supplyConsumption;
        const int flag = withoutLeaders ? 1 : 0;
        int consumed = 0;

        __asm {
            push flag
            lea eax, consumed
            push eax
            push unit
            mov eax, function
            call eax
        }
        return consumed;
    }

    int fuelConsumption(uintptr_t unit, bool withoutLeaders) {
        if (!isUnit(unit)) {
            return 0;
        }

        // The same, except that this one takes the unit in eax and only the other
        // two arguments on the stack. Nothing in MSVC spells that convention, so the
        // call is written out: `call function` reads the address out of memory and
        // leaves eax alone, which is the point.
        const uintptr_t function = moduleBase() + GameFunction::fuelConsumption;
        const int flag = withoutLeaders ? 1 : 0;
        int consumed = 0;

        __asm {
            push flag
            lea ecx, consumed
            push ecx
            mov eax, unit
            call function
        }
        return consumed;
    }

    void pushCUnitToStack(lua_State* L, uintptr_t unitPtr) {
        DEBUG_OUT(printf("unitPtr: %#010x\n", unitPtr));
        DEBUG_OUT(printf("nameOffset: %#010x\n", unitPtr + CUnit::Offsets::name));

        const std::string name = HDS::readString(unitPtr + CUnit::Offsets::name);
        lua_pushstring(L, "name");
        lua_pushstring(L, name.c_str());
        lua_settable(L, -3);
	    return;
    }
}
