#include <Gui/LuaBridge.hpp>

#include <Windows.h>
#include <cstdarg>
#include <cstdio>
#include <lua.hpp>

#include <Diagnostics.hpp>
#include <MemScan.hpp>
#include <TextEncoding.hpp>
#include <utils.hpp>

namespace {
    const char* reason = "no Lua call made yet";

    // Holds the detailed message reason points at when a lookup fails.
    char reasonBuffer[256] = {};

    void setReason(const char* format, ...) {
        va_list args;
        va_start(args, format);
        vsnprintf(reasonBuffer, sizeof(reasonBuffer), format, args);
        va_end(args);
        reason = reasonBuffer;
    }

    lua_State* renderThreadState() {
        // The render thread's own state, not the global LUA_STATE: that global is
        // simply whichever state loaded BiceLib first, while this one is the state
        // holding the utility's globals (G_PlayerCountry, UI, ...).
        return const_cast<lua_State*>(
            static_cast<const lua_State*>(Diagnostics::presentThreadLuaState()));
    }

    /**
    @brief resolves "A.B.C" onto the stack, leaving the value or nothing
    @returns true if a function was pushed
    */
    bool pushDottedPath(lua_State* state, const char* dottedPath) {
        const char* segmentStart = dottedPath;
        bool first = true;

        for (const char* cursor = dottedPath; ; cursor++) {
            if (*cursor != '.' && *cursor != '\0') {
                continue;
            }

            const size_t length = static_cast<size_t>(cursor - segmentStart);
            if (length == 0) {
                if (!first) {
                    lua_pop(state, 1);
                }
                return false;
            }

            if (first) {
                lua_pushlstring(state, segmentStart, length);
                lua_gettable(state, LUA_GLOBALSINDEX);
                first = false;
            }
            else {
                if (!lua_istable(state, -1)) {
                    setReason("'%.*s' is not a table (state %#010x)",
                        static_cast<int>(segmentStart - dottedPath - 1), dottedPath,
                        static_cast<unsigned>(reinterpret_cast<uintptr_t>(state)));
                    lua_pop(state, 1);
                    return false;
                }
                lua_pushlstring(state, segmentStart, length);
                lua_gettable(state, -2);
                lua_remove(state, -2); // Drop the parent table, keep the child
            }

            if (lua_isnil(state, -1)) {
                // Naming the missing segment separates "the module never loaded" from
                // "it loaded into a different lua_State" from "the name is wrong".
                setReason("'%.*s' is nil (state %#010x)",
                    static_cast<int>(cursor - dottedPath), dottedPath,
                    static_cast<unsigned>(reinterpret_cast<uintptr_t>(state)));
                lua_pop(state, 1);
                return false;
            }

            if (*cursor == '\0') {
                break;
            }
            segmentStart = cursor + 1;
        }

        if (!lua_isfunction(state, -1)) {
            setReason("'%s' is not a function", dottedPath);
            lua_pop(state, 1);
            return false;
        }
        return true;
    }
}

bool Gui::Lua::sessionActive() {
    // Same pointer CMapProvince::GetMapProvinceById dereferences to reach the map.
    const uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
    if (moduleBase == 0) {
        return false;
    }

    uintptr_t gameState = 0;
    if (!Mem::tryRead(moduleBase + 0x1689790, gameState)) {
        return false;
    }
    return gameState != 0;
}

bool Gui::Lua::available() {
    if (!sessionActive()) {
        reason = "no game session";
        return false;
    }
    if (Diagnostics::presentThreadId() != GetCurrentThreadId()) {
        reason = "not on the render thread";
        return false;
    }
    if (renderThreadState() == nullptr) {
        reason = "the render thread has not run Lua yet";
        return false;
    }
    if (Diagnostics::luaInFlightHere()) {
        reason = "a Lua call is already in flight";
        return false;
    }
    return true;
}

const char* Gui::Lua::unavailableReason() {
    return reason;
}

bool Gui::Lua::beginTableCall(const char* dottedPath) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop); // pushDottedPath already set a specific reason
        return false;
    }

    if (lua_pcall(state, 0, 1, 0) != 0) {
        // The error object is on the stack; log it and clear so nothing leaks.
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    if (!lua_istable(state, -1)) {
        reason = "the Lua call did not return a table";
        lua_settop(state, baseTop);
        return false;
    }
    return true;
}

bool Gui::Lua::beginTableCallWithString(const char* dottedPath, const char* value) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop);
        return false;
    }

    lua_pushstring(state, value);
    if (lua_pcall(state, 1, 1, 0) != 0) {
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    if (!lua_istable(state, -1)) {
        reason = "the Lua call did not return a table";
        lua_settop(state, baseTop);
        return false;
    }
    return true;
}

bool Gui::Lua::beginTableCallWithNumber(const char* dottedPath, double value) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop);
        return false;
    }

    lua_pushnumber(state, value);
    if (lua_pcall(state, 1, 1, 0) != 0) {
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    if (!lua_istable(state, -1)) {
        reason = "the Lua call did not return a table";
        lua_settop(state, baseTop);
        return false;
    }
    return true;
}

bool Gui::Lua::beginTableCallWithStringAndNumber(const char* dottedPath, const char* text, double number) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop);
        return false;
    }

    lua_pushstring(state, text);
    lua_pushnumber(state, number);
    if (lua_pcall(state, 2, 1, 0) != 0) {
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    if (!lua_istable(state, -1)) {
        reason = "the Lua call did not return a table";
        lua_settop(state, baseTop);
        return false;
    }
    return true;
}

void Gui::Lua::endCall() {
    lua_State* state = renderThreadState();
    if (state != nullptr) {
        lua_pop(state, 1);
    }
}

double Gui::Lua::numberField(const char* key, double fallback) {
    lua_State* state = renderThreadState();
    if (state == nullptr) {
        return fallback;
    }

    lua_pushstring(state, key);
    lua_gettable(state, -2);
    const double value = lua_isnumber(state, -1) ? lua_tonumber(state, -1) : fallback;
    lua_pop(state, 1);
    return value;
}

bool Gui::Lua::boolField(const char* key, bool fallback) {
    lua_State* state = renderThreadState();
    if (state == nullptr) {
        return fallback;
    }

    lua_pushstring(state, key);
    lua_gettable(state, -2);
    const bool value = lua_isnil(state, -1) ? fallback : (lua_toboolean(state, -1) != 0);
    lua_pop(state, 1);
    return value;
}

std::string Gui::Lua::stringField(const char* key, const char* fallback) {
    lua_State* state = renderThreadState();
    if (state == nullptr) {
        return fallback;
    }

    lua_pushstring(state, key);
    lua_gettable(state, -2);
    size_t length = 0;
    const char* text = lua_tolstring(state, -1, &length);
    // Game text is Windows-1252; ImGui needs UTF-8.
    std::string value = (text != nullptr) ? Text::toUtf8(text, length) : std::string(fallback);
    lua_pop(state, 1);
    return value;
}

int Gui::Lua::arrayLength(const char* key) {
    lua_State* state = renderThreadState();
    if (state == nullptr) {
        return 0;
    }

    lua_pushstring(state, key);
    lua_gettable(state, -2);
    const int length = lua_istable(state, -1) ? static_cast<int>(lua_objlen(state, -1)) : 0;
    lua_pop(state, 1);
    return length;
}

std::string Gui::Lua::arrayStringAt(const char* key, int index) {
    lua_State* state = renderThreadState();
    if (state == nullptr) {
        return std::string();
    }

    lua_pushstring(state, key);
    lua_gettable(state, -2);
    if (!lua_istable(state, -1)) {
        lua_pop(state, 1);
        return std::string();
    }

    lua_rawgeti(state, -1, index + 1); // Lua arrays start at 1
    size_t length = 0;
    const char* text = lua_tolstring(state, -1, &length);
    // Game text is Windows-1252; ImGui needs UTF-8.
    std::string value = (text != nullptr) ? Text::toUtf8(text, length) : std::string();
    lua_pop(state, 2);
    return value;
}

bool Gui::Lua::pushArrayElement(const char* key, int index) {
    lua_State* state = renderThreadState();
    if (state == nullptr) {
        return false;
    }

    lua_pushstring(state, key);
    lua_gettable(state, -2);
    if (!lua_istable(state, -1)) {
        lua_pop(state, 1);
        return false;
    }

    lua_rawgeti(state, -1, index + 1);
    if (!lua_istable(state, -1)) {
        lua_pop(state, 2);
        return false;
    }

    lua_remove(state, -2); // Drop the array, leave the row on top
    return true;
}

void Gui::Lua::popArrayElement() {
    lua_State* state = renderThreadState();
    if (state != nullptr) {
        lua_pop(state, 1);
    }
}

bool Gui::Lua::call(const char* dottedPath) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop);
        return false;
    }

    if (lua_pcall(state, 0, 0, 0) != 0) {
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    lua_settop(state, baseTop);
    return true;
}

bool Gui::Lua::callWithString(const char* dottedPath, const char* value) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop);
        return false;
    }

    lua_pushstring(state, value);
    if (lua_pcall(state, 1, 0, 0) != 0) {
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    lua_settop(state, baseTop);
    return true;
}

bool Gui::Lua::callWithNumber(const char* dottedPath, double value) {
    if (!available()) {
        return false;
    }

    lua_State* state = renderThreadState();
    const int baseTop = lua_gettop(state);

    if (!pushDottedPath(state, dottedPath)) {
        lua_settop(state, baseTop); // pushDottedPath already set a specific reason
        return false;
    }

    lua_pushnumber(state, value);
    if (lua_pcall(state, 1, 0, 0) != 0) {
        const char* message = lua_tostring(state, -1);
        ERROR_OUT(printf("LuaBridge: %s failed: %s\n", dottedPath, message != nullptr ? message : "?"));
        reason = "the Lua call raised an error";
        lua_settop(state, baseTop);
        return false;
    }

    lua_settop(state, baseTop);
    return true;
}
