#include <string>
#include <wtypes.h>
#include <cstdio>
#include <lua.hpp>

#ifdef BICE_LIB_DEBUG
#define DEBUG_OUT(x) {printf("[DEBUG] [%s:%d] ", __func__, __LINE__) ; x;}
#else 
#define DEBUG_OUT(x)
#endif
#define INFO_OUT(x) {printf("[INFO] ") ; x;}
#define WARNING_OUT(x) {printf("[WARNING] ") ; x;}
#define ERROR_OUT(x) {printf("[ERROR] ") ; x;}

namespace utils {
	extern lua_State* LUA_STATE;
	void logInLua(lua_State* state, const char* toLog);
	std::string gameTickToDate(int gameTick);

	/**
	@brief the tick a date falls on, the exact inverse of gameTickToDate

	Takes the date the way that function prints it - year.month.day, month counting
	from one - so a tick turned into text and back comes out unchanged.

	@param hourOfDay 0 for the start of the day
	@returns the tick, or 0 if the month is not a month
	*/
	int dateToGameTick(int year, int month, int dayOfMonth, int hourOfDay);
}