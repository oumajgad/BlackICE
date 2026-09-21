#include <GameState/CrashSave.hpp>

#include <GameClasses/CInGameIdler.hpp>
#include <Hooks/AutoSaveHooks.hpp>
#include <MemScan.hpp>
#include <Overlay.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>
#include <string>

namespace {
    /**
     * `CInGameIdler::AutosaveWrite`, the game's own save writer.
     *
     * One argument, the idler, and the callee cleans the stack - `ret 4`. It reads
     * `[idler+0xAB0]`, spends one frame on `[idler+0xAB1]`, and then builds the name
     * and writes the file, all inside this one call. Calling it directly is therefore
     * a save, synchronously, by the time it returns.
     */
    const uintptr_t AUTOSAVE_WRITE = 0x24FF80;

    /**@brief `push ebp; mov ebp,esp; push -1; push <scope table>`*/
    const unsigned char AUTOSAVE_WRITE_HEAD[6] = { 0x55, 0x8B, 0xEC, 0x6A, 0xFF, 0x68 };
    const int AUTOSAVE_WRITE_SCOPE_AT = 6;
    const uintptr_t AUTOSAVE_WRITE_SCOPE = 0x85732D;

    typedef void(__stdcall* AutosaveWrite)(uintptr_t idler);

    /**
     * How long the game is given to write a save asked for from the frame loop.
     *
     * The writer takes one frame to notice the request and one more to spend its own
     * delay, so three would do it in a healthy game. This is a game that is failing,
     * and the save itself is a long synchronous write, so the allowance is generous -
     * it is only ever spent when something has gone wrong.
     */
    const int SAVE_FRAME_LIMIT = 600;

    CrashSave::Stage stageValue = CrashSave::Stage::Idle;
    const char* stageTextValue = "nothing has gone wrong";
    const char* reasonValue = "";
    const char* caveatValue = nullptr;

    uintptr_t savingIdler = 0;
    int savingFrames = 0;
    int settleFrames = 0;
    unsigned __int64 roomBeforeValue = 0;
    unsigned __int64 roomAfterValue = 0;
    DWORD savingThread = 0;

    // ---- the log ---------------------------------------------------------------------
    //
    // A raw handle rather than a FILE, and opened on first use: this can be written at
    // the moment the process is out of room, so nothing here should want any. Shared
    // all three ways, so the file can be read - and deleted - while the game has it
    // open.

    HANDLE logFile = INVALID_HANDLE_VALUE;
    bool logTried = false;

    unsigned __int64 freeAddressSpace() {
        MEMORYSTATUSEX status;
        status.dwLength = sizeof(status);
        if (!GlobalMemoryStatusEx(&status)) {
            return 0;
        }
        return status.ullAvailVirtual;
    }

    /**@brief the game's live CInGameIdler, or 0 when no game is running*/
    uintptr_t idler() {
        return CInGameIdler::current();
    }

    /**
    @brief puts our name on the save the game is about to write

    Through the same machinery the scheduled saves use, so a crash save keeps three
    rotating files of its own. If the hooks will not install, the game names it and
    rotates it as its own autosave - worse, but still a save, so this never stops the
    save happening.
    */
    void claimTheName() {
        if (Hooks::AutoSave::install()) {
            Hooks::AutoSave::setActive(true);
            Hooks::AutoSave::claimNextSave(Hooks::AutoSave::Kind::Crash);
        }
    }

    /**
    @brief says what happened, and closes the game

    TerminateProcess rather than an orderly exit: whatever brought us here has left the
    process in a state where every destructor between now and a clean shutdown is
    another chance to fault before the user has read anything. The save is already on
    disk by this point, which is the only thing that had to survive.
    */
    void tellAndClose(bool saved) {
        char message[1024];
        if (saved) {
            _snprintf(message, sizeof(message) - 1,
                "Hearts of Iron 3 %s and cannot carry on.\n"
                "\n"
                "Your game was saved first, as \"crashsave\" - load it from the save "
                "game list as usual.\n"
                "%s"
                "\n"
                "The game will close when you press OK.",
                reasonValue, caveatValue != nullptr ? caveatValue : "");
        }
        else {
            _snprintf(message, sizeof(message) - 1,
                "Hearts of Iron 3 %s and cannot carry on.\n"
                "\n"
                "The save could not be written: %s.\n"
                "\n"
                "The game will close when you press OK.", reasonValue, stageTextValue);
        }
        message[sizeof(message) - 1] = '\0';

        MessageBoxA(reinterpret_cast<HWND>(Overlay::window()), message,
            "BlackICE", MB_OK | MB_ICONERROR | MB_TOPMOST | MB_SETFOREGROUND);
        TerminateProcess(GetCurrentProcess(), 0);
    }

    void finish(bool saved, const char* how) {
        roomAfterValue = freeAddressSpace();
        stageValue = saved ? CrashSave::Stage::Done : CrashSave::Stage::Failed;
        stageTextValue = how;

        char line[320];
        const int written = _snprintf(line, sizeof(line) - 1,
            "--- crash save (%s): %s, %u KB free before, %u KB after ---\n",
            reasonValue, how,
            static_cast<unsigned>(roomBeforeValue / 1024),
            static_cast<unsigned>(roomAfterValue / 1024));
        if (written > 0) {
            line[written] = '\0';
            CrashSave::log(line);
        }
        tellAndClose(saved);
    }

    /**@brief the shared opening: record why, say so, and claim the name*/
    bool begin(const char* why, const char* caveat) {
        if (stageValue != CrashSave::Stage::Idle) {
            return false;       // once, whoever asks
        }
        reasonValue = why != nullptr ? why : "has stopped working";
        caveatValue = caveat;
        roomBeforeValue = freeAddressSpace();
        savingThread = GetCurrentThreadId();

        char line[320];
        const int written = _snprintf(line, sizeof(line) - 1,
            "\n--- crash save asked for: the game %s, %u KB free ---\n",
            reasonValue, static_cast<unsigned>(roomBeforeValue / 1024));
        if (written > 0) {
            line[written] = '\0';
            CrashSave::log(line);
        }
        return true;
    }
}

void CrashSave::log(const char* text) {
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

void CrashSave::requestFromFrameLoop(const char* why) {
    if (!begin(why, nullptr)) {
        return;
    }

    const uintptr_t live = idler();
    if (live == 0) {
        stageTextValue = "no game is running, so there was nothing to save";
        finish(false, stageTextValue);
        return;
    }

    claimTheName();

    // The whole of how a save is asked for. Written directly rather than through
    // AutoSave::request, which belongs to the scheduled saves and keeps their timers.
    *reinterpret_cast<unsigned char*>(
        live + CInGameIdler::Offsets::autosave_requested) = 1;

    savingIdler = live;
    savingFrames = 0;
    settleFrames = 0;
    stageValue = Stage::Saving;
    stageTextValue = "saving";
}

void CrashSave::update() {
    if (stageValue != Stage::Saving) {
        return;
    }
    savingFrames++;

    // The writer clears both flags together with one word sized store the moment it
    // commits to writing, and the whole write is inside that one call - so by the time
    // a frame ends with the flag down, the file is on disk. The extra frames after it
    // are margin, not necessity.
    unsigned char requested = 1;
    if (!Mem::tryRead(savingIdler + CInGameIdler::Offsets::autosave_requested, requested)) {
        finish(false, "the game state could not be read");
        return;
    }

    if (requested == 0) {
        if (settleFrames < 2) {
            settleFrames++;
            return;
        }
        char note[64];
        _snprintf(note, sizeof(note) - 1, "written after %d frames", savingFrames);
        note[sizeof(note) - 1] = '\0';
        finish(true, note);
        return;
    }

    if (savingFrames > SAVE_FRAME_LIMIT) {
        finish(false, "the game never wrote it");
    }
}

void CrashSave::saveNowAndClose(const char* why, const char* caveat) {
    if (!begin(why, caveat)) {
        if (savingThread == GetCurrentThreadId()) {
            // Re-entered on the thread that is already saving, so whatever is saving
            // is above us on the stack and will never come back to finish. There is
            // nothing to wait for, and waiting would turn a crash into a hang.
            TerminateProcess(GetCurrentProcess(), 0);
            return;
        }

        // Another thread is saving and has a message box up that nobody has read yet.
        // Wait for it rather than racing it to the exit: it ends the process itself.
        // Returning is not an option either - the caller cannot carry on.
        while (true) {
            Sleep(100);
        }
    }

    const uintptr_t live = idler();
    if (live == 0) {
        finish(false, "no game is running, so there was nothing to save");
        return;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    uint32_t scope = 0;
    const unsigned char* writer =
        reinterpret_cast<const unsigned char*>(base + AUTOSAVE_WRITE);
    if (base == 0
        || !Mem::tryRead(base + AUTOSAVE_WRITE + AUTOSAVE_WRITE_SCOPE_AT, scope)
        || scope != base + AUTOSAVE_WRITE_SCOPE
        || memcmp(writer, AUTOSAVE_WRITE_HEAD, sizeof(AUTOSAVE_WRITE_HEAD)) != 0) {
        finish(false, "the game's save writer is not what this build expects");
        return;
    }

    claimTheName();

    // Both flags, not just the request: the second is the writer's own one frame of
    // delay, and there is no next frame to spend it in. With both set it goes straight
    // through to building the name and writing the file.
    *reinterpret_cast<unsigned char*>(
        live + CInGameIdler::Offsets::autosave_requested) = 1;
    *reinterpret_cast<unsigned char*>(
        live + CInGameIdler::Offsets::autosave_delayed) = 1;

    stageValue = Stage::Saving;
    reinterpret_cast<AutosaveWrite>(base + AUTOSAVE_WRITE)(live);

    // The writer clears the request as it commits, so a flag still up means it decided
    // not to write - which is the only way to tell from here.
    unsigned char requested = 1;
    if (!Mem::tryRead(live + CInGameIdler::Offsets::autosave_requested, requested)
        || requested != 0) {
        finish(false, "the game's writer declined it");
        return;
    }
    finish(true, "written on the spot");
}

CrashSave::Stage CrashSave::stage() {
    return stageValue;
}

const char* CrashSave::stageText() {
    return stageTextValue;
}

const char* CrashSave::reason() {
    return reasonValue;
}

unsigned __int64 CrashSave::roomBefore() {
    return roomBeforeValue;
}

unsigned __int64 CrashSave::roomAfter() {
    return roomAfterValue;
}
