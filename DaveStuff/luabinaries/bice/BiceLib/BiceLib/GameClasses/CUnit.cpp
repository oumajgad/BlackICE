#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <utils.hpp>

namespace CUnit {
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
