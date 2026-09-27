#include <Hooks/MessageQueueHooks.hpp>

#include <GameClasses/GameMessage.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>

namespace {
    /**
     * **`CInGameIdler::Update`**, the idler's per-frame update and virtual slot 1. Its
     * first three instructions are `push ebp; mov ebp, esp; and esp, -8` - six bytes, so
     * the five byte jump takes one NOP after it and the stub reproduces all three.
     *
     * **The alignment is one of the three.** The rest of the function is built on
     * `esp` being eight byte aligned, so leaving `and esp, -8` out would corrupt it.
     */
    const uintptr_t SITE = 0x2559D0;
    const unsigned char SITE_BYTES[6] = { 0x55, 0x8B, 0xEC, 0x83, 0xE4, 0xF8 };
    const uintptr_t RESUME = 0x2559D6;

    DWORD resumeAt = 0;
    uintptr_t base = 0;
    bool installedFlag = false;
    const char* statusText = "not installed";

    /**
    @brief raises whatever is waiting

    **Runs every frame, so the empty case has to cost nothing** - and it does: a count
    read and a return. Game::Message::flushQueue takes the queue whole before raising
    anything, so this cannot be re-entered into a growing list.
    */
    void __cdecl flushMessages() {
        if (Game::Message::queued() == 0) {
            return;
        }
        (void)Game::Message::flushQueue();
    }

    /**@brief flushes the queue, then does the three instructions it displaced*/
    __declspec(naked) void idlerUpdate() {
        __asm {
            pushad
            pushfd
            call flushMessages
            popfd
            popad

            push ebp                    // exactly the three instructions this replaced
            mov ebp, esp
            and esp, 0xFFFFFFF8
            jmp [resumeAt]
        }
    }
}

bool Hooks::MessageQueue::install() {
    if (installedFlag) {
        return true;
    }

    base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof SITE_BYTES)) {
        statusText = "CInGameIdler::Update does not begin where this build expects";
        ERROR_OUT(printf("MessageQueue: %#010x is not the prologue expected\n",
            static_cast<unsigned>(base + SITE)));
        return false;
    }

    resumeAt = static_cast<DWORD>(base + RESUME);
    if (!Hooks::hook(reinterpret_cast<void*>(base + SITE), &idlerUpdate, 5, 1)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "flushing queued messages once a frame";
    INFO_OUT(printf("MessageQueue: queued messages will be raised from "
        "CInGameIdler::Update\n"));
    return true;
}

bool Hooks::MessageQueue::installed() {
    return installedFlag;
}

const char* Hooks::MessageQueue::status() {
    return statusText;
}
