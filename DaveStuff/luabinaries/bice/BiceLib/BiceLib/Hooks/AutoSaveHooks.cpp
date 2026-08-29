#include <Hooks/AutoSaveHooks.hpp>

#include <GameState/AutoSave.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstring>

namespace {
    // Inside the autosave decision, three instructions in: the clear of the request
    // flag, before the game has made its own mind up. Six bytes, so a five byte jump
    // and one nop stand in for it exactly.
    //
    // eax holds the CInGameIdler here and esi holds the tick, both put there by the
    // two instructions above; bl is the zero being written.
    const uintptr_t CLEAR_REQUEST_SITE = 0x261DBA;
    const unsigned char EXPECTED_CLEAR[6] = { 0x88, 0x98, 0xB0, 0x0A, 0x00, 0x00 };

    // Inside the writer: the read of debug_saves that picks between the three file
    // rotation and one dated file per save. Six bytes again, and eax holds the
    // settings object the read is against. Standing here means the answer can be
    // decided per save, and it is also the last point before the names are built.
    const uintptr_t DEBUG_SAVES_SITE = 0x2500EB;
    const unsigned char EXPECTED_DEBUG_SAVES[6] = { 0x8B, 0x80, 0x58, 0x01, 0x00, 0x00 };

    /**
     * The three names the rotation works on, as the immediates that load them.
     *
     * The game's own rotation is written just below the read above: if the newest
     * exists, and the middle one exists, the oldest is deleted, the middle renamed to
     * the oldest and the newest renamed to the middle - then the save is written to
     * the newest. Pointing those three names at buffers here gives that whole routine,
     * unchanged, working on a set of files of ours.
     *
     * In rotation order: newest first, oldest last.
     */
    const uintptr_t NAME_IMMEDIATES[3] = { 0x25010B, 0x250159, 0x25018D };
    const uintptr_t EXPECTED_NAMES[3] = { 0x11CDCE4, 0x11CDCF4, 0x11CDD08 };
    const char* const GAME_NAMES[3] = {
        "autosave.hoi3", "oldautosave.hoi3", "olderautosave.hoi3"
    };

    const char* const EXTENSION = ".hoi3";
    const char* const OLDER_PREFIXES[3] = { "", "old", "older" };

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the stubs before anything else. While these are clear the stubs
    // reproduce, in assembly, exactly the instructions they replaced, so nothing here
    // can disturb a register or a flag.
    unsigned char active = 0;
    unsigned char pending = 0;

    DWORD jumpBackClear = 0;
    DWORD jumpBackDebugSaves = 0;

    // Pointed at by the game's own name building for as long as the patch is in
    // place, so they outlive every call that reads them. They hold the game's own
    // names except while one of our saves is being written.
    char nameBuffers[3][64] = {};

    // What our three files are called, before the rotation prefixes and the
    // extension are put on.
    char saveBaseName[40] = "autosave_premonth";

    /**@brief puts either our names or the game's own into the buffers*/
    void applyNames(bool ours) {
        for (int i = 0; i < 3; i++) {
            if (!ours) {
                strncpy_s(nameBuffers[i], sizeof(nameBuffers[i]), GAME_NAMES[i], _TRUNCATE);
                continue;
            }
            // Built rather than formatted so the length is bounded by construction and
            // the result always ends in the extension.
            strncpy_s(nameBuffers[i], sizeof(nameBuffers[i]), OLDER_PREFIXES[i], _TRUNCATE);
            strncat_s(nameBuffers[i], sizeof(nameBuffers[i]), saveBaseName, _TRUNCATE);
            strncat_s(nameBuffers[i], sizeof(nameBuffers[i]), EXTENSION, _TRUNCATE);
        }
    }

    /**@brief the C side of the decision stub, kept out of the asm*/
    void __cdecl decide(uintptr_t idler, int tick) {
        AutoSave::onDecision(idler, tick);
    }

    /**
    @brief names the save about to be written, and answers the read that chose it

    Called in place of the writer's read of debug_saves, with what that read produced.
    A save of ours is answered with zero however debug_saves is set, because zero is
    the rotation branch and the rotation is the point; anything else is answered
    honestly and gets the game's own names back.

    @returns what the read should have produced
    */
    int __cdecl chooseSaveNames(int debugSaves) {
        if (pending != 0) {
            pending = 0;        // names one save, not the next
            applyNames(true);
            return 0;
        }
        applyNames(false);
        return debugSaves;
    }

    /**
    @brief stands in for the clear of the autosave request flag

    The clear happens on both paths, because the game relies on it: the flag is what
    the writer reads a frame later, and it has to start each decision down. Only once
    it is down does anything of ours run, and what it does is put it back up.

    Everything a call could disturb is saved around it.
    */
    __declspec(naked) void hookedClearRequest() {
        __asm {
            cmp active, 0
            jne takeOver

            mov byte ptr [eax + 0xAB0], bl   // exactly the instruction this replaced
            jmp [jumpBackClear]

        takeOver:
            mov byte ptr [eax + 0xAB0], bl   // the same clear, then our own decision

            pushad
            pushfd
            push esi                         // the tick
            push eax                         // the CInGameIdler
            call decide
            add esp, 8
            popfd
            popad

            jmp [jumpBackClear]
        }
    }

    /**
    @brief stands in for the read of debug_saves in the writer

    While the feature is off this is the instruction it replaced and nothing else.
    While it is on the read still happens, and its result is handed to chooseSaveNames,
    which decides both what the save is called and what the read answers - a call
    leaves its return value in eax, which is exactly where the read left its own.

    ecx and edx are not preserved: the instructions between here and the compare that
    reads eax touch neither, and the compare sets its own flags.
    */
    __declspec(naked) void hookedDebugSavesRead() {
        __asm {
            cmp active, 0
            jne takeOver

            mov eax, dword ptr [eax + 0x158]  // exactly the instruction this replaced
            jmp [jumpBackDebugSaves]

        takeOver:
            mov eax, dword ptr [eax + 0x158]  // the same read, then our own answer

            push eax
            call chooseSaveNames
            add esp, 4

            jmp [jumpBackDebugSaves]
        }
    }

    /**@brief refuses unless the bytes are exactly what this build should have there*/
    bool bytesMatch(const unsigned char* site, const unsigned char* expected, int length) {
        for (int i = 0; i < length; i++) {
            unsigned char byte = 0;
            if (!Mem::tryRead(reinterpret_cast<uintptr_t>(site + i), byte)
                || byte != expected[i]) {
                return false;
            }
        }
        return true;
    }

    /**@brief writes one four byte immediate, whatever was there before*/
    bool writeDword(void* site, uint32_t value) {
        DWORD protection = 0;
        if (!VirtualProtect(site, 4, PAGE_EXECUTE_READWRITE, &protection)) {
            return false;
        }
        *reinterpret_cast<uint32_t*>(site) = value;
        DWORD ignored = 0;
        VirtualProtect(site, 4, protection, &ignored);
        FlushInstructionCache(GetCurrentProcess(), site, 4);
        return true;
    }
}

bool Hooks::AutoSave::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    unsigned char* clearSite = reinterpret_cast<unsigned char*>(base + CLEAR_REQUEST_SITE);
    unsigned char* debugSite = reinterpret_cast<unsigned char*>(base + DEBUG_SAVES_SITE);

    // Everything is checked before anything is written, so a build this does not fit
    // leaves the game untouched rather than half patched. The name immediates are
    // checked as well: they are what says the rotation is still built the way this
    // expects, and repointing the wrong instruction would corrupt a file name rather
    // than fail.
    bool namesMatch = true;
    for (int i = 0; i < 3; i++) {
        uint32_t now = 0;
        if (!Mem::tryRead(base + NAME_IMMEDIATES[i], now) || now != base + EXPECTED_NAMES[i]) {
            namesMatch = false;
        }
    }
    if (!bytesMatch(clearSite, EXPECTED_CLEAR, 6)
        || !bytesMatch(debugSite, EXPECTED_DEBUG_SAVES, 6)
        || !namesMatch) {
        statusText = "the autosave code is not what this build expects";
        ERROR_OUT(printf("AutoSave hook: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + CLEAR_REQUEST_SITE)));
        return false;
    }

    // The game's own names, so a vanilla autosave written before ours is ever
    // requested is named exactly as it always was.
    applyNames(false);

    jumpBackClear = static_cast<DWORD>(base + CLEAR_REQUEST_SITE + 6);
    jumpBackDebugSaves = static_cast<DWORD>(base + DEBUG_SAVES_SITE + 6);

    // Six byte instructions, so five bytes of jump and one nop each.
    if (!Hooks::hook(clearSite, &hookedClearRequest, 5, 1)
        || !Hooks::hook(debugSite, &hookedDebugSavesRead, 5, 1)) {
        statusText = "could not make the code writable";
        return false;
    }
    for (int i = 0; i < 3; i++) {
        if (!writeDword(reinterpret_cast<void*>(base + NAME_IMMEDIATES[i]),
            reinterpret_cast<uint32_t>(nameBuffers[i]))) {
            statusText = "could not make the code writable";
            return false;
        }
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("AutoSave hooks installed at %#010x and %#010x\n",
        static_cast<unsigned>(base + CLEAR_REQUEST_SITE),
        static_cast<unsigned>(base + DEBUG_SAVES_SITE)));
    return true;
}

void Hooks::AutoSave::setActive(bool on) {
    active = on ? 1 : 0;
    if (!on) {
        pending = 0;        // nothing of ours is waiting to be named

        // The immediates still point here, and with the stub inert nothing will put
        // these back later, so the game's own names have to be what is left behind.
        applyNames(false);
    }
}

void Hooks::AutoSave::claimNextSave() {
    pending = 1;
}

bool Hooks::AutoSave::releaseClaim() {
    const bool had = pending != 0;
    pending = 0;
    return had;
}

void Hooks::AutoSave::setSaveName(const char* baseName) {
    if (baseName == nullptr || baseName[0] == 0) {
        baseName = "autosave_premonth";  // the files have to be called something
    }
    strncpy_s(saveBaseName, sizeof(saveBaseName), baseName, _TRUNCATE);

    // Only while one of ours is being written do the buffers hold our names, so there
    // is nothing to rewrite here: the next save of ours picks the new name up.
}

const char* Hooks::AutoSave::saveName(int slot) {
    if (slot < 0 || slot > 2) {
        return "";
    }
    // Built on demand rather than read out of the buffers, which hold the game's own
    // names except during one of our saves.
    static char text[3][64] = {};
    strncpy_s(text[slot], sizeof(text[slot]), OLDER_PREFIXES[slot], _TRUNCATE);
    strncat_s(text[slot], sizeof(text[slot]), saveBaseName, _TRUNCATE);
    strncat_s(text[slot], sizeof(text[slot]), EXTENSION, _TRUNCATE);
    return text[slot];
}

bool Hooks::AutoSave::installed() {
    return installedFlag;
}

const char* Hooks::AutoSave::status() {
    return statusText;
}
