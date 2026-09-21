#include <GameState/OutOfMemory.hpp>

#include <GameState/CrashSave.hpp>
#include <Settings.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>
#include <string>

namespace {
    const char* const WATCH_KEY = "outOfMemory.watch";
    const char* const TRIGGER_KEY = "outOfMemory.triggerAtKb";

    bool settingsRead = false;
    bool watchingFlag = true;
    unsigned __int64 triggerAtValue = OutOfMemory::DEFAULT_TRIGGER_AT;

    unsigned __int64 freeNowValue = 0;
    unsigned __int64 largestValue = 0;
    int framesSinceProbe = 0;

    /**
     * How often the probe is taken.
     *
     * Twice a second is far finer than a process falls apart, and a probe that
     * succeeds on its first try is one call - so this is about not making a habit of
     * it rather than about the cost.
     */
    const int PROBE_EVERY_FRAMES = 30;

    // ---- measuring -------------------------------------------------------------------

    void readSettings() {
        if (settingsRead) {
            return;
        }
        settingsRead = true;
        watchingFlag = Settings::getInt(WATCH_KEY, 1) != 0;
        const int kb = Settings::getInt(TRIGGER_KEY,
            static_cast<int>(OutOfMemory::DEFAULT_TRIGGER_AT / 1024));
        triggerAtValue = static_cast<unsigned __int64>(kb > 0 ? kb : 1) * 1024u;
    }

    /**@brief free address space, in one call and without walking anything*/
    unsigned __int64 freeAddressSpace() {
        MEMORYSTATUSEX status;
        status.dwLength = sizeof(status);
        if (!GlobalMemoryStatusEx(&status)) {
            return 0;
        }
        return status.ullAvailVirtual;
    }

    /**
     * The sizes the probe asks for, and the sizes the ballast takes, largest first.
     *
     * The probe stops at the first one it gets, so a healthy process costs exactly one
     * call and only a starved one walks down the list. The ballast works down the same
     * list so it closes the big holes before the small ones.
     */
    const size_t BLOCK_SIZES[] = {
        64u << 20, 32u << 20, 16u << 20, 8u << 20, 4u << 20,
        2u << 20, 1u << 20, 512u << 10, 256u << 10,
    };
    const int BLOCK_SIZE_COUNT = 9;

    /**
    @brief the largest block the process can still be given, or 0 if even 256 KB fails

    **This is the number that says the game is finished**, and the total free space is
    not: two deaths were measured with 16 and 30 MB free and nothing bigger than 244 KB
    to put anything in.

    Asked rather than calculated. Reserving costs no physical memory and is given back
    immediately, so the measurement does not disturb what it is measuring - and unlike
    walking the address space it answers the question directly instead of inferring it
    from a list of holes.
    */
    unsigned __int64 largestReservable() {
        for (int i = 0; i < BLOCK_SIZE_COUNT; i++) {
            void* probe = VirtualAlloc(nullptr, BLOCK_SIZES[i], MEM_RESERVE, PAGE_NOACCESS);
            if (probe != nullptr) {
                VirtualFree(probe, 0, MEM_RELEASE);
                return BLOCK_SIZES[i];
            }
        }
        return 0;
    }

    /**
    @brief how much address space is left, and the largest single piece of it

    A VirtualQuery per region and nothing else. Used by the ballast, which needs the
    total to know when to stop; the watch uses the probe above instead, which answers
    the question it cares about in one call.
    */
    void measureSpace(unsigned __int64& largestFree, unsigned __int64& totalFree) {
        largestFree = 0;
        totalFree = 0;

        SYSTEM_INFO info;
        GetSystemInfo(&info);
        uintptr_t address = reinterpret_cast<uintptr_t>(info.lpMinimumApplicationAddress);
        const uintptr_t limit = reinterpret_cast<uintptr_t>(info.lpMaximumApplicationAddress);

        MEMORY_BASIC_INFORMATION region;
        while (address < limit) {
            if (VirtualQuery(reinterpret_cast<void*>(address), &region, sizeof(region)) == 0) {
                break;
            }
            if (region.State == MEM_FREE) {
                totalFree += region.RegionSize;
                if (region.RegionSize > largestFree) {
                    largestFree = region.RegionSize;
                }
            }
            const uintptr_t next = address + region.RegionSize;
            if (next <= address) {
                break;
            }
            address = next;
        }
    }

    // ---- the ballast -----------------------------------------------------------------
    //
    // Room for every reservation it makes, standing ready before it starts: by the time
    // it needs to remember a pointer there is nothing left to remember it in.

    const int MAX_BALLAST_CHUNKS = 8192;
    void* ballastChunks[MAX_BALLAST_CHUNKS];
    size_t ballastSizes[MAX_BALLAST_CHUNKS];
    volatile long ballastCount = 0;

}

// ---- the watch -------------------------------------------------------------------------

void OutOfMemory::update() {
    readSettings();
    freeNowValue = freeAddressSpace();

    // Whatever asked for it - this watch, or the purecall handler - a crash save in
    // progress is pumped from here, and nothing else happens until it is finished.
    if (CrashSave::stage() != CrashSave::Stage::Idle) {
        CrashSave::update();
        return;
    }

    // Taken whether or not the watch is on, because the number is worth showing on the
    // page either way - it is the one that says how close the process is.
    framesSinceProbe++;
    if (framesSinceProbe >= PROBE_EVERY_FRAMES || largestValue == 0) {
        framesSinceProbe = 0;
        largestValue = largestReservable();
    }

    if (watchingFlag && largestValue < triggerAtValue) {
        trigger();
    }
}

void OutOfMemory::trigger() {
    char line[160];
    const int written = _snprintf(line, sizeof(line) - 1,
        "--- out of memory: largest block %u KB ---\n",
        static_cast<unsigned>(largestValue / 1024));
    if (written > 0) {
        line[written] = '\0';
        CrashSave::log(line);
    }

    // From the frame loop, not on the spot: there is a next frame, so the game's own
    // writer can do it on its own thread rather than being called into from here.
    CrashSave::requestFromFrameLoop("has run out of memory");
}

unsigned __int64 OutOfMemory::freeNow() {
    return freeNowValue;
}

unsigned __int64 OutOfMemory::largestBlock() {
    return largestValue;
}

bool OutOfMemory::watching() {
    readSettings();
    return watchingFlag;
}

void OutOfMemory::setWatching(bool on) {
    readSettings();
    watchingFlag = on;
    Settings::setInt(WATCH_KEY, on ? 1 : 0);
}

unsigned __int64 OutOfMemory::triggerAt() {
    readSettings();
    return triggerAtValue;
}

void OutOfMemory::setTriggerAt(unsigned __int64 bytes) {
    readSettings();
    triggerAtValue = bytes > 0 ? bytes : 1024u;
    Settings::setInt(TRIGGER_KEY, static_cast<int>(triggerAtValue / 1024));
}

// ---- the ballast -----------------------------------------------------------------------

int OutOfMemory::hold(unsigned __int64 leaveFree) {
    releaseBallast();

    unsigned __int64 largest = 0;
    unsigned __int64 free = 0;
    measureSpace(largest, free);

    // Falling sizes, so the big holes go first and the game is left with small ones -
    // which is the state a game running out of memory is actually in. The running
    // total is kept by subtraction rather than by walking the address space again
    // every time round, which would make this quadratic on a fragmented process.
    int taken = 0;
    for (int size = 0; size < BLOCK_SIZE_COUNT && taken < MAX_BALLAST_CHUNKS; size++) {
        while (free > leaveFree && taken < MAX_BALLAST_CHUNKS) {
            if (BLOCK_SIZES[size] > free - leaveFree) {
                break;      // this size would cut into what the game is being left
            }
            void* held = VirtualAlloc(nullptr, BLOCK_SIZES[size], MEM_RESERVE, PAGE_NOACCESS);
            if (held == nullptr) {
                break;
            }
            ballastChunks[taken] = held;
            ballastSizes[taken] = BLOCK_SIZES[size];
            taken++;
            free -= BLOCK_SIZES[size];
        }
    }

    InterlockedExchange(&ballastCount, taken);

    measureSpace(largest, free);
    char line[256];
    const int written = _snprintf(line, sizeof(line) - 1,
        "--- ballast: %d reservations, %u MB held, %u MB left free "
        "(largest block %u KB) ---\n",
        taken, static_cast<unsigned>(OutOfMemory::ballastHeld() / (1024 * 1024)),
        static_cast<unsigned>(free / (1024 * 1024)),
        static_cast<unsigned>(largest / 1024));
    if (written > 0) {
        line[written] = '\0';
        CrashSave::log(line);
    }
    return taken;
}

void OutOfMemory::releaseBallast() {
    const long count = ballastCount;
    InterlockedExchange(&ballastCount, 0);
    for (long i = 0; i < count; i++) {
        if (ballastChunks[i] != nullptr) {
            VirtualFree(ballastChunks[i], 0, MEM_RELEASE);
            ballastChunks[i] = nullptr;
        }
    }
    if (count > 0) {
        CrashSave::log("--- ballast released ---\n");
    }
}

unsigned __int64 OutOfMemory::ballastHeld() {
    unsigned __int64 total = 0;
    const long count = ballastCount;
    for (long i = 0; i < count; i++) {
        if (ballastChunks[i] != nullptr) {
            total += ballastSizes[i];
        }
    }
    return total;
}

int OutOfMemory::ballastReservations() {
    const long count = ballastCount;
    return count > 0 ? static_cast<int>(count) : 0;
}
