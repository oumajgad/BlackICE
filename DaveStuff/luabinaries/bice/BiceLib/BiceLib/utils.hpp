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
	char* getCString(DWORD* addr);
	void logInLua(lua_State* state, const char* toLog);
	std::string gameTickToDate(int gameTick);
}