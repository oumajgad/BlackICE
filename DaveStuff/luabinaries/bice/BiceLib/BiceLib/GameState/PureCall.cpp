#include <GameState/PureCall.hpp>

#include <GameState/CrashSave.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstring>

namespace {
    // ---- where the CRT keeps the purecall handler ------------------------------------
    //
    // Module relative, as everywhere in BiceLib, and found the way the game finds it:
    // by reading the operands out of the instructions that use them, so a build this
    // was not written against is refused rather than half patched.

    /**@brief `_purecall`, which every pure virtual slot points at*/
    const uintptr_t PURECALL = 0x7961D5;

    /**@brief `push dword ptr [__pPurecall]`*/
    const unsigned char PURECALL_PUSH[2] = { 0xFF, 0x35 };
    const int PURECALL_GLOBAL_AT = 2;

    /**@brief `call dword ptr [DecodePointer]`*/
    const unsigned char PURECALL_CALL[2] = { 0xFF, 0x15 };
    const int PURECALL_CALL_AT = 6;
    const int PURECALL_IMPORT_AT = 8;

    /**
     * `test eax,eax; je +2; call eax; push 25`
     *
     * The tail is what says this really is `_purecall` and not another function that
     * happens to decode a pointer: **25 is `_RT_PUREVIRT`**, the CRT's runtime error
     * number for a pure virtual call, and it is pushed on the path taken when no
     * handler is installed.
     */
    const unsigned char PURECALL_TAIL[8] = {
        0x85, 0xC0, 0x74, 0x02, 0xFF, 0xD0, 0x6A, 0x19
    };
    const int PURECALL_TAIL_AT = 12;

    const uintptr_t PPURECALL = 0x134D238;
    const uintptr_t DECODE_POINTER_IAT = 0x92B040;

    bool installedFlag = false;
    const char* statusText = "not installed yet";
    void** handlerSlot = nullptr;
    void* previousHandler = nullptr;    // what the CRT had there, encoded
    uintptr_t purecallAddress = 0;

    volatile long inside = 0;

    /**
    @brief what `_purecall` calls instead of aborting

    No arguments and no return value - `call eax` with nothing pushed, and the CRT
    carries straight on to its abort path if this comes back. So it does not come back.

    Guarded against itself: a purecall raised while saving from a purecall would
    otherwise recurse until the stack ran out, which is a worse death than the one it
    was called to improve on.
    */
    void __cdecl onPureCall() {
        if (InterlockedCompareExchange(&inside, 1, 0) != 0) {
            return;     // already handling one; let the CRT abort as it would have
        }
        CrashSave::saveNowAndClose("hit an internal error (a pure virtual call)",
            "\n"
            "This kind of error means part of the game was already in a broken state "
            "when the save was taken, so it cannot be guaranteed to load correctly or "
            "to be complete.\n");
    }

    /**@brief writes one pointer sized global, making it writable if it is not*/
    bool writeGlobal(void* address, const void* value, size_t size) {
        DWORD protection = 0;
        if (!VirtualProtect(address, size, PAGE_READWRITE, &protection)) {
            return false;
        }
        memcpy(address, value, size);
        DWORD ignored = 0;
        VirtualProtect(address, size, protection, &ignored);
        return true;
    }
}

bool PureCall::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    purecallAddress = base + PURECALL;

    const unsigned char* code = reinterpret_cast<const unsigned char*>(purecallAddress);
    uint32_t handlerGlobal = 0;
    uint32_t decodeImport = 0;

    // Everything is checked before anything is written. The operands are read out of
    // the instructions rather than assumed, so the global is found the way the game
    // itself finds it, and the tail check is what says this is _purecall in particular.
    if (!Mem::tryRead(purecallAddress + PURECALL_GLOBAL_AT, handlerGlobal)
        || !Mem::tryRead(purecallAddress + PURECALL_IMPORT_AT, decodeImport)
        || memcmp(code, PURECALL_PUSH, sizeof(PURECALL_PUSH)) != 0
        || memcmp(code + PURECALL_CALL_AT, PURECALL_CALL, sizeof(PURECALL_CALL)) != 0
        || memcmp(code + PURECALL_TAIL_AT, PURECALL_TAIL, sizeof(PURECALL_TAIL)) != 0
        || handlerGlobal != base + PPURECALL
        || decodeImport != base + DECODE_POINTER_IAT) {
        statusText = "_purecall is not what this build expects";
        ERROR_OUT(printf("PureCall: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(purecallAddress)));
        return false;
    }

    handlerSlot = reinterpret_cast<void**>(handlerGlobal);

    // The CRT encodes a null into the slot at startup and nothing else in the
    // executable writes it. Anything else there is somebody else's handler, and taking
    // it over would break whatever put it there.
    previousHandler = *handlerSlot;
    if (DecodePointer(previousHandler) != nullptr) {
        statusText = "something already has the purecall handler";
        ERROR_OUT(printf("PureCall: a handler is already installed at %#010x\n",
            handlerGlobal));
        return false;
    }

    void* encoded = EncodePointer(reinterpret_cast<void*>(&onPureCall));
    if (!writeGlobal(handlerSlot, &encoded, sizeof(encoded))) {
        statusText = "could not write the handler";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("PureCall handler installed, slot %#010x\n", handlerGlobal));
    return true;
}

void PureCall::remove() {
    if (!installedFlag) {
        return;
    }
    writeGlobal(handlerSlot, &previousHandler, sizeof(previousHandler));
    installedFlag = false;
    statusText = "removed";
}

bool PureCall::installed() {
    return installedFlag;
}

const char* PureCall::status() {
    return statusText;
}

void PureCall::provoke() {
    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        return;
    }
    // Not a stand-in for a pure virtual call: a pure virtual slot holds this exact
    // address, so this is the same call the game would make.
    typedef void(__cdecl* PureCallFn)();
    reinterpret_cast<PureCallFn>(base + PURECALL)();
}
