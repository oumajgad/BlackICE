#include <wtypes.h>
#include <lua.hpp>
#include <utils.hpp>
#include <Hooks/Hooks.hpp>
#include <format>

char* utils::getCString(DWORD* addr) {
    DWORD stringLength = *(addr + (0x10/4));
    char* res;
    if (stringLength > 15) {
        res = (char*)*addr;
    }
    else {
        res = (char*)addr;
    }
    return res;
}

lua_State* utils::LUA_STATE;
void utils::logInLua(lua_State* state, const char* toLog) {
    lua_getglobal(state, "BiceLibLuaLog");
    lua_pushstring(state, toLog);
    lua_pcall(state, 1, 0, 0);
    return;
}
std::string utils::gameTickToDate(int gameTick) {
    int daysPerMonth[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
    int totalDays = (gameTick + -43800000) / 24;
    int hourOfDay = (gameTick + -43800000) % 24;
    int year = totalDays / 365.0;
    int dayOfYear = totalDays - (year * 365.0);
    int dayOfMonth = dayOfYear;

    int month = 0;
    dayOfYear -= daysPerMonth[month];
    while (dayOfYear > 0) {
        dayOfMonth = dayOfYear;
        dayOfYear -= daysPerMonth[month];
        month += 1;
    }
    month += 1; // human months begin counting at 1

    return std::format("{}.{}.{} {}:00", year, month, dayOfMonth, hourOfDay);
}
