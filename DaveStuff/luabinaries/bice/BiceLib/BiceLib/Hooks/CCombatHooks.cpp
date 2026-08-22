#include <Hooks/CCombatHooks.hpp>

#include <Hooks/Hooks.hpp>
#include <Combat/CombatLog.hpp>
#include <utils.hpp>

DWORD Hooks::Combat::jumpBack = 0;

namespace {
    // Addresses in the executable are based at 0x400000, which is what the RTTI export
    // and the reversing scripts use; the module is relocated, so only the difference
    // is useful here.
    //
    //   0x0042f960  push ebp            1 byte
    //   0x0042f961  mov  ebp, esp       2 bytes
    //   0x0042f963  mov  eax, fs:[0]    6 bytes
    //
    // Nine bytes over three instructions, which is what the jump replaces and what the
    // trampoline has to put back. The fs:[0] read is the function setting up its
    // exception frame, so it has to happen exactly as it would have.
    const DWORD RECORD_FUNCTION = 0x0042F960 - 0x400000;
    const DWORD RESUME_AT = 0x0042F969 - 0x400000;
    const int JUMP_BYTES = 5;
    const int SPARE_BYTES = 4; // the rest of the nine, blanked so nothing half decodes

    bool hookInstalled = false;
    const char* reason = "not installed yet";
}

/**
@brief runs on the game's thread with the finished combat in hand

The stack at entry is the game's: the return address, then the two arguments. After
pushad and the frame set up below, the second argument - the CCombat - sits 0x2c above
ebp: four bytes of saved ebp, thirty two of pushad, four of return address, then the
first argument.
*/
__declspec(naked) void Hooks::Combat::combatRecordedHook() {
    DWORD combat;

    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov eax, [ebp + 0x2C]
        mov[combat], eax
    }

    ::Combat::note(combat);

    _asm {
        mov esp, ebp
        pop ebp
        popad

        // the three instructions the jump landed on
        push ebp
        mov ebp, esp
        mov eax, fs:[0]

        jmp[Hooks::Combat::jumpBack]
    }
}

bool Hooks::Combat::install() {
    if (hookInstalled) {
        return true;
    }
    if (Hooks::MODULE_BASE == 0) {
        reason = "the game module has not been found yet";
        return false;
    }

    jumpBack = Hooks::MODULE_BASE + RESUME_AT;

    if (!Hooks::hook(reinterpret_cast<void*>(Hooks::MODULE_BASE + RECORD_FUNCTION),
        combatRecordedHook, JUMP_BYTES, SPARE_BYTES)) {
        reason = "the patch could not be written";
        return false;
    }

    hookInstalled = true;
    reason = "installed";
    INFO_OUT(printf("Combat: recording hook installed at %#010x\n",
        Hooks::MODULE_BASE + RECORD_FUNCTION));

    return true;
}

bool Hooks::Combat::installed() {
    return hookInstalled;
}

const char* Hooks::Combat::status() {
    return reason;
}
