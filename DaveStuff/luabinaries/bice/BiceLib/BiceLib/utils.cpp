#include <wtypes.h>
#include <lua.hpp>
#include <utils.hpp>
#include <Hooks/Hooks.hpp>
#include <format>

lua_State* utils::LUA_STATE;
void utils::logInLua(lua_State* state, const char* toLog) {
    lua_getglobal(state, "BiceLibLuaLog");
    lua_pushstring(state, toLog);
    lua_pcall(state, 1, 0, 0);
    return;
}
utils::GameDate utils::gameTickToParts(int gameTick) {
    const int daysPerMonth[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
    const int hours = gameTick - 43800000;
    const int totalDays = hours / 24;

    GameDate date;
    date.hourOfDay = hours % 24;

    // A Clausewitz year is 365 days with no leap day, which is why nothing from a
    // calendar library will do here.
    date.year = totalDays / 365;
    int dayOfYear = totalDays - (date.year * 365);

    // Walk the months off, leaving the day within the one it lands in. December takes
    // whatever is left rather than being counted off, so the index cannot run past it.
    int month = 0;
    while (month < 11 && dayOfYear >= daysPerMonth[month]) {
        dayOfYear -= daysPerMonth[month];
        month += 1;
    }

    // Both count from one, the way a date is written.
    date.month = month + 1;
    date.dayOfMonth = dayOfYear + 1;
    date.daysInMonth = daysPerMonth[month];
    return date;
}

std::string utils::gameTickToDate(int gameTick) {
    const GameDate date = gameTickToParts(gameTick);
    return std::format("{}.{}.{} {}:00",
        date.year, date.month, date.dayOfMonth, date.hourOfDay);
}

int utils::dateToGameTick(int year, int month, int dayOfMonth, int hourOfDay) {
    const int daysPerMonth[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
    if (month < 1 || month > 12 || dayOfMonth < 1) {
        return 0;
    }

    // Putting back what gameTickToDate walked off: the months before this one, and the
    // day within it. Both are written counting from one and counted here from zero.
    int dayOfYear = dayOfMonth - 1;
    for (int i = 0; i < month - 1; i++) {
        dayOfYear += daysPerMonth[i];
    }

    return 43800000 + ((year * 365) + dayOfYear) * 24 + hourOfDay;
}
