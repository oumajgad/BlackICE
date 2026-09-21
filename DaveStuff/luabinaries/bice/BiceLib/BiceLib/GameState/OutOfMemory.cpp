#include <GameState/OutOfMemory.hpp>

#include <GameClasses/CInGameIdler.hpp>
#include <Hooks/AutoSaveHooks.hpp>
#include <MemScan.hpp>
#include <Overlay.hpp>
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
    unsigned __int64 freeAtTriggerValue = 0;
    unsigned __int64 freeAfterSaveValue = 0;
    int framesSinceProbe = 0;

    OutOfMemory::Stage stageValue = OutOfMemory::Stage::Watching;
    const char* stageTextValue = "watching";

    uintptr_t savingIdler = 0;
    int savingFrames = 0;
    int settleFrames = 0;

    /**
     * How often the probe is taken.
     *
     * Twice a second is far finer than a process falls apart, and a probe that
     * succeeds on its first try is one call - so this is about not making a habit of
     * it rather than about the cost.
     */
    const int PROBE_EVERY_FRAMES = 30;

    /**
     * How long the game is given to write the save before this gives up on it.
     *
     * The writer takes one frame to notice the request and one more to spend its own
     * delay, so three would do it in a healthy game. This is a game that is failing,
     * and the save itself is a long synchronous write, so the allowance is generous -
     * it is only ever spent when something has gone wrong.
     */
    const int SAVE_FRAME_LIMIT = 600;

    // ---- the log ---------------------------------------------------------------------
    //
    // A raw handle rather than a FILE, and opened on first use: this is written at the
    // moment the process is out of room, so nothing here should want any. Shared all
    // three ways, so the file can be read - and deleted - while the game has it open.

    HANDLE logFile = INVALID_HANDLE_VALUE;
    bool logTried = false;

    void logLine(const char* text) {
        if (!logTried) {
            logTried = true;
            const std::string& directory = Overlay::directory();
            if (!directory.empty()) {
                const std::string path = directory + "OutOfMemory.log";
                logFile = CreateFileA(path.c_str(), FILE_APPEND_DATA,
                    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                    OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
            }
        }
        if (logFile == INVALID_HANDLE_VALUE) {
            return;
        }
        DWORD written = 0;
        WriteFile(logFile, text, static_cast<DWORD>(strlen(text)), &written, nullptr);
        FlushFileBuffers(logFile);
    }

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

    // ---- closing ---------------------------------------------------------------------

    /**
    @brief says what happened, and closes the game

    TerminateProcess rather than an orderly exit: the process is out of address space,
    and every destructor between here and a clean shutdown is another chance to fault
    before the user has read anything. The save is already on disk by this point, which
    is the only thing that had to survive.
    */
    void tellAndClose(bool saved) {
        char message[640];
        if (saved) {
            _snprintf(message, sizeof(message) - 1,
                "Hearts of Iron 3 has run out of memory and cannot carry on.\n"
                "\n"
                "Your game was saved first, as \"crashsave\" - load it from the save "
                "game list as usual.\n"
                "\n"
                "This is the 32 bit game running out of room for addresses rather "
                "than your PC running out of memory, so a restart is all that is "
                "needed.\n"
                "\n"
                "The game will close when you press OK.");
        }
        else {
            _snprintf(message, sizeof(message) - 1,
                "Hearts of Iron 3 has run out of memory and cannot carry on.\n"
                "\n"
                "The save could not be written: %s.\n"
                "\n"
                "The game will close when you press OK.", stageTextValue);
        }
        message[sizeof(message) - 1] = '\0';

        MessageBoxA(reinterpret_cast<HWND>(Overlay::window()), message,
            "BlackICE - out of memory",
            MB_OK | MB_ICONERROR | MB_TOPMOST | MB_SETFOREGROUND);
        TerminateProcess(GetCurrentProcess(), 0);
    }

    /**@brief one frame of waiting for the game to write the save it was asked for*/
    void pumpSave() {
        savingFrames++;

        // The writer clears both flags together with one word sized store the moment
        // it commits to writing, and the whole write is inside that one call - so by
        // the time a frame ends with the flag down, the file is on disk. The extra
        // frames after it are margin, not necessity.
        unsigned char requested = 1;
        if (!Mem::tryRead(savingIdler + CInGameIdler::Offsets::autosave_requested, requested)) {
            stageValue = OutOfMemory::Stage::Failed;
            stageTextValue = "the game state could not be read";
            tellAndClose(false);
            return;
        }

        if (requested == 0) {
            if (settleFrames < 2) {
                settleFrames++;
                return;
            }
            freeAfterSaveValue = freeAddressSpace();
            stageValue = OutOfMemory::Stage::Done;
            stageTextValue = "saved";

            char line[256];
            const int written = _snprintf(line, sizeof(line) - 1,
                "--- crash save written after %d frames, %u KB free before, "
                "%u KB after ---\n",
                savingFrames, static_cast<unsigned>(freeAtTriggerValue / 1024),
                static_cast<unsigned>(freeAfterSaveValue / 1024));
            if (written > 0) {
                line[written] = '\0';
                logLine(line);
            }
            tellAndClose(true);
            return;
        }

        if (savingFrames > SAVE_FRAME_LIMIT) {
            stageValue = OutOfMemory::Stage::Failed;
            stageTextValue = "the game never wrote it";
            logLine("--- crash save: the game never wrote it ---\n");
            tellAndClose(false);
        }
    }
}

// ---- the watch -------------------------------------------------------------------------

void OutOfMemory::update() {
    readSettings();
    freeNowValue = freeAddressSpace();

    if (stageValue == Stage::Saving) {
        pumpSave();
        return;
    }
    if (stageValue != Stage::Watching) {
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
    if (stageValue != Stage::Watching) {
        return;     // once, whatever asked
    }

    freeAtTriggerValue = freeAddressSpace();

    char line[256];
    const int written = _snprintf(line, sizeof(line) - 1,
        "--- crash save: largest block %u KB, %u KB free in total, "
        "asking the game to save ---\n",
        static_cast<unsigned>(largestValue / 1024),
        static_cast<unsigned>(freeAtTriggerValue / 1024));
    if (written > 0) {
        line[written] = '\0';
        logLine(line);
    }

    const uintptr_t idler = CInGameIdler::current();
    if (idler == 0) {
        stageValue = Stage::Failed;
        stageTextValue = "no game is running, so there was nothing to save";
        logLine("--- crash save: no game running ---\n");
        tellAndClose(false);
        return;
    }

    // Named through the same machinery the scheduled saves use, so a crash save gets
    // its own three rotating files instead of ageing out an autosave. If the hooks
    // will not install, the game names it and rotates it as its own autosave, which is
    // worse but is still a save.
    if (Hooks::AutoSave::install()) {
        Hooks::AutoSave::setActive(true);
        Hooks::AutoSave::claimNextSave(Hooks::AutoSave::Kind::Crash);
    }

    // The whole of how a save is asked for: the writer runs every frame and does
    // nothing until this byte is set. Written rather than requested through
    // AutoSave::request because that one belongs to the scheduled saves and keeps
    // their timers.
    *reinterpret_cast<unsigned char*>(
        idler + CInGameIdler::Offsets::autosave_requested) = 1;

    savingIdler = idler;
    savingFrames = 0;
    settleFrames = 0;
    stageValue = Stage::Saving;
    stageTextValue = "saving";
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

OutOfMemory::Stage OutOfMemory::stage() {
    return stageValue;
}

const char* OutOfMemory::stageText() {
    return stageTextValue;
}

unsigned __int64 OutOfMemory::freeAtTrigger() {
    return freeAtTriggerValue;
}

unsigned __int64 OutOfMemory::freeAfterSave() {
    return freeAfterSaveValue;
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
        logLine(line);
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
        logLine("--- ballast released ---\n");
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
