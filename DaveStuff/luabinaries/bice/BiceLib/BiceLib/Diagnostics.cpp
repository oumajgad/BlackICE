#include <Diagnostics.hpp>

namespace {
    using Diagnostics::MAX_THREAD_RECORDS;
    using Diagnostics::ThreadRecord;

    CRITICAL_SECTION recordLock;
    bool recordLockReady = false;

    ThreadRecord records[MAX_THREAD_RECORDS] = {};
    int recordCount = 0;

    volatile LONG presentThread = 0;
    volatile LONG totalCalls = 0;

    // Threads currently inside a BiceLib lua_CFunction.
    volatile LONG activeLuaThreads = 0;
    volatile LONG maxConcurrent = 0;

    volatile LONG overlapOtherThread = 0;
    volatile LONG overlapOwnThread = 0;

    // Nesting depth for *this* thread only.
    thread_local int localDepth = 0;

    void ensureLock() noexcept {
        // DLL_PROCESS_ATTACH would be neater, but this file has no DllMain and the
        // first entry is always from a single thread during require().
        if (!recordLockReady) {
            InitializeCriticalSection(&recordLock);
            recordLockReady = true;
        }
    }

    void recordCall(DWORD threadId, const void* state) noexcept {
        ensureLock();
        EnterCriticalSection(&recordLock);

        for (int i = 0; i < recordCount; i++) {
            if (records[i].threadId == threadId) {
                records[i].luaState = state; // Track the most recent state for this thread
                records[i].calls++;
                LeaveCriticalSection(&recordLock);
                return;
            }
        }

        if (recordCount < MAX_THREAD_RECORDS) {
            records[recordCount].threadId = threadId;
            records[recordCount].luaState = state;
            records[recordCount].calls = 1;
            recordCount++;
        }

        LeaveCriticalSection(&recordLock);
    }
}

Diagnostics::LuaScope::LuaScope(lua_State* state) noexcept {
    recordCall(GetCurrentThreadId(), state);
    InterlockedIncrement(&totalCalls);

    localDepth++;
    if (localDepth == 1) {
        const LONG active = InterlockedIncrement(&activeLuaThreads);
        if (active > maxConcurrent) {
            InterlockedExchange(&maxConcurrent, active);
        }
    }
}

Diagnostics::LuaScope::~LuaScope() noexcept {
    localDepth--;
    if (localDepth == 0) {
        InterlockedDecrement(&activeLuaThreads);
    }
}

void Diagnostics::notePresentThread() noexcept {
    InterlockedExchange(&presentThread, static_cast<LONG>(GetCurrentThreadId()));

    // Anything this thread is itself inside doesn't count as concurrent access.
    const LONG ownDepth = (localDepth > 0) ? 1 : 0;
    if (ownDepth > 0) {
        InterlockedIncrement(&overlapOwnThread);
    }

    if (activeLuaThreads - ownDepth > 0) {
        InterlockedIncrement(&overlapOtherThread);
    }
}

DWORD Diagnostics::presentThreadId() noexcept {
    return static_cast<DWORD>(presentThread);
}

int Diagnostics::threadRecordCount() noexcept {
    return recordCount;
}

ThreadRecord Diagnostics::threadRecord(int index) noexcept {
    if (index < 0 || index >= recordCount) {
        return ThreadRecord{};
    }
    return records[index];
}

unsigned Diagnostics::luaCallCount() noexcept {
    return static_cast<unsigned>(totalCalls);
}

unsigned Diagnostics::presentDuringOtherThreadLua() noexcept {
    return static_cast<unsigned>(overlapOtherThread);
}

unsigned Diagnostics::presentDuringOwnLua() noexcept {
    return static_cast<unsigned>(overlapOwnThread);
}

unsigned Diagnostics::maxConcurrentLuaThreads() noexcept {
    return static_cast<unsigned>(maxConcurrent);
}

bool Diagnostics::presentThreadRunsLua() noexcept {
    return presentThreadLuaState() != nullptr;
}

bool Diagnostics::luaInFlightHere() noexcept {
    return localDepth > 0;
}

const void* Diagnostics::presentThreadLuaState() noexcept {
    const DWORD thread = presentThreadId();
    for (int i = 0; i < recordCount; i++) {
        if (records[i].threadId == thread) {
            return records[i].luaState;
        }
    }
    return nullptr;
}
