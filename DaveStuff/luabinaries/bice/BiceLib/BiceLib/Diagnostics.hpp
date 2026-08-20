#pragma once

#include <Windows.h>

struct lua_State;

/**
 * Phase 0 check for the ImGui utility port.
 *
 * The overlay draws from the D3D9 Present hook and wants to read game state through
 * the HoI3 Lua API. Whether that is safe depends on two separate things:
 *
 *  1. Does Present run on a thread that also runs Lua? (If so, that thread's
 *     lua_State is the one holding the utility's globals.)
 *  2. Do the game's other Lua threads run *at the same time*, and do they share a
 *     lua_State with it? Independent states can be used concurrently; coroutines of
 *     one state cannot.
 *
 * A "same thread" answer alone is not enough, so this records per thread state
 * pointers and actual temporal overlap.
 */
namespace Diagnostics {
    constexpr int MAX_THREAD_RECORDS = 8;

    struct ThreadRecord
    {
        DWORD threadId;
        const void* luaState;
        unsigned calls;
    };

    /**@brief RAII marker placed at the top of a lua_CFunction body*/
    struct LuaScope
    {
        explicit LuaScope(lua_State* state) noexcept;
        ~LuaScope() noexcept;
    };

    /**@brief called from the Present hook, once per frame*/
    void notePresentThread() noexcept;

    DWORD presentThreadId() noexcept;

    /**@brief number of distinct threads seen entering Lua (capped at MAX_THREAD_RECORDS)*/
    int threadRecordCount() noexcept;
    ThreadRecord threadRecord(int index) noexcept;

    /**@brief total lua_CFunction entries across all threads*/
    unsigned luaCallCount() noexcept;

    /**
    @brief frames where a Lua call was in flight on a thread other than the renderer

    This is the number that decides the port's design. Zero means the game never runs
    Lua while it is rendering, so the overlay can call into the render thread's state
    without locking. Above zero means concurrent access is real.
    */
    unsigned presentDuringOtherThreadLua() noexcept;

    /**@brief frames where the render thread itself was already inside a Lua call*/
    unsigned presentDuringOwnLua() noexcept;

    /**@brief highest number of threads observed inside Lua at the same time*/
    unsigned maxConcurrentLuaThreads() noexcept;

    /**@brief true if the render thread has been seen running Lua*/
    bool presentThreadRunsLua() noexcept;

    /**@brief lua_State most recently used by the render thread, null if never*/
    const void* presentThreadLuaState() noexcept;

    /**
    @brief whether the calling thread is currently inside a BiceLib lua_CFunction

    Guard for calling back into Lua: re-entering the interpreter while a call is
    already on this thread's stack is the one case the Phase 0 measurement cannot
    rule out.
    */
    bool luaInFlightHere() noexcept;
}
