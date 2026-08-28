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
    // settings object the read is against.
    const uintptr_t DEBUG_SAVES_SITE = 0x2500EB;
    const unsigned char EXPECTED_DEBUG_SAVES[6] = { 0x8B, 0x80, 0x58, 0x01, 0x00, 0x00 };

    // The two string constants the dated name is built from, as the four byte
    // immediates of the mov that loads each. Repointing an immediate changes only
    // this one use; the strings themselves are shared and stay as they are.
    //
    // The name is directory + prefix + tag + "_" + date + extension, so emptying the
    // prefix and putting the suffix on the front of the extension gives
    // IRE_1937_02_27_14_premonth.hoi3.
    const uintptr_t PREFIX_IMMEDIATE = 0x2502E6;    // was "autosave_"
    const uintptr_t EXTENSION_IMMEDIATE = 0x250245; // was ".hoi3"
    const uintptr_t EXPECTED_PREFIX = 0x11CDD1C;    // module relative, as read back
    const uintptr_t EXPECTED_EXTENSION = 0x11CDD28;

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
    // place, so they outlive every call that reads them.
    char prefixBuffer[2] = "";
    char extensionBuffer[64] = ".hoi3";

    /**@brief the C side of the decision stub, kept out of the asm*/
    void __cdecl decide(uintptr_t idler, int tick) {
        AutoSave::onDecision(idler, tick);
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

    Answers with the real setting unless a save of ours is waiting to be named, in
    which case it answers one, which is what sends the writer down the dated name
    branch. The flag is cleared as it is read, so it names one save and not the next.

    No call, on either path. The flags are put back because the instruction this
    replaced did not set any, even though what reads them next sets its own.
    */
    __declspec(naked) void hookedDebugSavesRead() {
        __asm {
            pushfd
            mov eax, dword ptr [eax + 0x158]  // the instruction this replaced

            cmp pending, 0
            je done

            mov byte ptr pending, 0
            mov eax, 1                        // one dated file, not the rotation

        done:
            popfd
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
    void* prefixSite = reinterpret_cast<void*>(base + PREFIX_IMMEDIATE);
    void* extensionSite = reinterpret_cast<void*>(base + EXTENSION_IMMEDIATE);

    // Everything is checked before anything is written, so a build this does not fit
    // leaves the game untouched rather than half patched. The two immediates are
    // checked as well: they are what says the name is still built the way this
    // expects, and repointing the wrong instruction would corrupt a file name rather
    // than fail.
    uint32_t prefixNow = 0;
    uint32_t extensionNow = 0;
    if (!bytesMatch(clearSite, EXPECTED_CLEAR, 6)
        || !bytesMatch(debugSite, EXPECTED_DEBUG_SAVES, 6)
        || !Mem::tryRead(base + PREFIX_IMMEDIATE, prefixNow)
        || !Mem::tryRead(base + EXTENSION_IMMEDIATE, extensionNow)
        || prefixNow != base + EXPECTED_PREFIX
        || extensionNow != base + EXPECTED_EXTENSION) {
        statusText = "the autosave code is not what this build expects";
        ERROR_OUT(printf("AutoSave hook: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + CLEAR_REQUEST_SITE)));
        return false;
    }

    jumpBackClear = static_cast<DWORD>(base + CLEAR_REQUEST_SITE + 6);
    jumpBackDebugSaves = static_cast<DWORD>(base + DEBUG_SAVES_SITE + 6);

    // Six byte instructions, so five bytes of jump and one nop each.
    if (!Hooks::hook(clearSite, &hookedClearRequest, 5, 1)
        || !Hooks::hook(debugSite, &hookedDebugSavesRead, 5, 1)
        || !writeDword(prefixSite, reinterpret_cast<uint32_t>(prefixBuffer))
        || !writeDword(extensionSite, reinterpret_cast<uint32_t>(extensionBuffer))) {
        statusText = "could not make the code writable";
        return false;
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
        pending = 0;    // nothing of ours is waiting to be named
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

void Hooks::AutoSave::setNameSuffix(const char* text) {
    // Built here rather than in the stub, so the game's frame only ever reads it.
    // The extension is fitted last and the suffix cut to make room, so what comes out
    // always ends in .hoi3 however long the text is.
    const char* extension = ".hoi3";
    const size_t extensionLength = strlen(extension);
    const size_t room = sizeof(extensionBuffer) - extensionLength - 2;

    size_t length = (text == nullptr) ? 0 : strlen(text);
    if (length > room) {
        length = room;
    }

    size_t at = 0;
    if (length > 0) {
        extensionBuffer[at++] = '_';
        memcpy(extensionBuffer + at, text, length);
        at += length;
    }
    memcpy(extensionBuffer + at, extension, extensionLength + 1);
}

bool Hooks::AutoSave::installed() {
    return installedFlag;
}

const char* Hooks::AutoSave::status() {
    return statusText;
}
