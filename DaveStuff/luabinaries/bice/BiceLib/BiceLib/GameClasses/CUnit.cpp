#include <GameClasses/CUnit.hpp>
#include <utils.hpp>

namespace CUnit {
    void pushCUnitToStack(lua_State* L, uintptr_t unitPtr) {
        DEBUG_OUT(printf("unitPtr: %#010x\n", unitPtr));
        DEBUG_OUT(printf("nameOffset: %#010x\n", unitPtr + CUnit::Offsets::name));

        auto name = utils::getCString((DWORD*) (unitPtr + CUnit::Offsets::name));
        lua_pushstring(L, "name");
        lua_pushstring(L, name);
        lua_settable(L, -3);
	    return;
    }
}
