#include <Hooks/Slot11Probe.hpp>

#include <Hooks/Hooks.hpp>
#include <utils.hpp>

#include <cstdio>

DWORD Hooks::Slot11Probe::jumpBack = 0;
volatile LONG Hooks::Slot11Probe::recording = 0;

namespace {
    // Module relative, like every address in BiceLib; the module is relocated, so this is
    // added to its base at install time.
    //
    //   0x1662F0     push ebp          55           1 byte
    //   0x1662F1     mov  ebp, esp     8B EC        2 bytes
    //   0x1662F3     sub  esp, 0x14    83 EC 14     3 bytes
    //
    // Six bytes over three instructions. The jump takes five and the sixth is blanked so
    // nothing half decodes, and the stub puts all three back before resuming at 0x1662F6,
    // where the body reads `[ecx+0x40]` - so `ecx` must still be the CCombatant. Nothing
    // below touches it: the off path never writes a register, and the recording path is
    // bracketed by pushad/popad.
    const DWORD SLOT11_BODY = 0x1662F0;
    const DWORD RESUME_AT = 0x1662F6;
    const int JUMP_BYTES = 5;
    const int SPARE_BYTES = 1;

    const unsigned char PROLOGUE[] = { 0x55, 0x8B, 0xEC, 0x83, 0xEC, 0x14 };

    // The two return addresses reversing/findings/FINDINGS-slot11.md predicts, module relative: the instruction
    // after each of CCombat slot 17's two calls at 0x17B083 and 0x17B091.
    const DWORD EXPECTED_A = 0x17B085;
    const DWORD EXPECTED_B = 0x17B093;

    // **And the third legitimate one, which the first version of this probe wrongly flagged as
    // UNKNOWN.** CLandCombatant overrides slot 11 with a pure forwarder at 0x168EE0 that calls the
    // base body non-virtually at 0x168EE8, so a land combatant's dispatch returns into the
    // forwarder at 0x168EED rather than into CCombat slot 17. reversing/findings/FINDINGS-slot11.md section 5 says so
    // in as many words - the expected list was built from the two *external* call sites and forgot
    // that the override lands in the same body. It is not a caller: the forwarder's address appears
    // only in CLandCombatant's vftable +0x2C.
    //
    // Live, this is the overwhelming majority of calls - 39,222 against 96 and 96 - because almost
    // every combat in a land war is a land combat.
    const DWORD EXPECTED_C = 0x168EED;

    // Fixed size on purpose. This runs inside a combat tick, and the honest answer to "how
    // many distinct callers are there" is "two or the file is wrong", so a table that cannot
    // allocate is better than one that can. Overflow is counted rather than hidden.
    const int SITE_LIMIT = 32;

    volatile LONG siteAddress[SITE_LIMIT] = { 0 };
    volatile LONG siteCount_[SITE_LIMIT] = { 0 };
    volatile LONG calls = 0;
    volatile LONG overflow = 0;

    bool hookInstalled = false;
    const char* reason = "not installed yet";

    /**
    @brief records one return address

    **Interlocked rather than plain, because the thread this runs on is not known.** The two
    callers the record knows about are reached from `CCombat::UpdateCombatStatusWindow`, which
    is interface code on the render thread - but the whole point of the probe is the callers
    the record does *not* know about, and this project has already found engine work on TBB
    workers (`CCountry::RecountUnitTotals` writes `army_combat_value` on one). A probe that
    assumed one thread could lose exactly the call it was built to catch.

    Two threads can still both claim a slot for the same address and leave a duplicate row.
    That is harmless - the page sums them - and it is cheaper than a lock in a combat tick.
    */
    void note(DWORD absoluteReturn) {
        ::InterlockedIncrement(&calls);

        const LONG relative = static_cast<LONG>(absoluteReturn - Hooks::MODULE_BASE);

        for (int i = 0; i < SITE_LIMIT; i++) {
            if (siteAddress[i] == relative) {
                ::InterlockedIncrement(&siteCount_[i]);
                return;
            }
            if (siteAddress[i] == 0) {
                if (::InterlockedCompareExchange(&siteAddress[i], relative, 0) == 0
                    || siteAddress[i] == relative) {
                    ::InterlockedIncrement(&siteCount_[i]);
                    return;
                }
                // Lost the race to another thread for a different address; keep scanning.
            }
        }

        ::InterlockedIncrement(&overflow);
    }
}

/**
@brief runs at the top of CCombatant slot 11, on whatever thread called it

**The off path runs no C and writes no register.** `Present` and the combat tick both reach
this function and it is entered once per combatant per refresh, so a probe that set up a frame
and called into C on every call would be a performance change rather than a measurement - and
the house rule learned the hard way is that "off" has to mean the stub does nothing at all.
Off costs one `cmp` against a byte and the three instructions the patch displaced.

The stack at entry is the game's, untouched: `[esp]` is the return address and `[esp+4]` the
out pointer. After `pushad` (0x20) and `push ebp` (4) and with `ebp` set to `esp`, the return
address is at `[ebp+0x24]`.
*/
__declspec(naked) void Hooks::Slot11Probe::probeHook() {
    DWORD caller;

    _asm {
        cmp Hooks::Slot11Probe::recording, 0
        jne doRecord

        // Off: exactly the three instructions the jump replaced, and straight back.
        push ebp
        mov ebp, esp
        sub esp, 0x14
        jmp [Hooks::Slot11Probe::jumpBack]

    doRecord:
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov eax, [ebp + 0x24]
        mov [caller], eax
    }

    note(caller);

    _asm {
        mov esp, ebp
        pop ebp
        popad

        // the three instructions the jump landed on
        push ebp
        mov ebp, esp
        sub esp, 0x14

        jmp [Hooks::Slot11Probe::jumpBack]
    }
}

bool Hooks::Slot11Probe::install() {
    if (hookInstalled) {
        return true;
    }
    if (Hooks::MODULE_BASE == 0) {
        reason = "the game module has not been found yet";
        return false;
    }

    // The site is a prologue, not a call, so there is nothing to resolve and the bytes
    // themselves are what must hold. If this build is not the one the finding was read from,
    // refuse rather than patch something else.
    if (!Hooks::bytesAre(Hooks::MODULE_BASE + SLOT11_BODY, PROLOGUE, sizeof(PROLOGUE))) {
        reason = "the six bytes at 0x1662F0 are not the prologue this was written for";
        return false;
    }

    jumpBack = Hooks::MODULE_BASE + RESUME_AT;

    if (!Hooks::hook(reinterpret_cast<void*>(Hooks::MODULE_BASE + SLOT11_BODY),
        probeHook, JUMP_BYTES, SPARE_BYTES)) {
        reason = "the patch could not be written";
        return false;
    }

    hookInstalled = true;
    reason = "installed, not recording";
    INFO_OUT(printf("Slot11Probe: installed at %#010x, recording off\n",
        Hooks::MODULE_BASE + SLOT11_BODY));

    return true;
}

bool Hooks::Slot11Probe::installed() {
    return hookInstalled;
}

const char* Hooks::Slot11Probe::status() {
    return reason;
}

void Hooks::Slot11Probe::setRecording(bool on) {
    ::InterlockedExchange(&recording, on ? 1 : 0);
    if (hookInstalled) {
        reason = on ? "installed, recording" : "installed, not recording";
    }
}

bool Hooks::Slot11Probe::isRecording() {
    return recording != 0;
}

long Hooks::Slot11Probe::callCount() {
    return calls;
}

int Hooks::Slot11Probe::siteCount() {
    int used = 0;
    for (int i = 0; i < SITE_LIMIT; i++) {
        if (siteAddress[i] != 0) {
            used++;
        }
    }
    return used;
}

Hooks::Slot11Probe::Site Hooks::Slot11Probe::site(int index) {
    Site out = { 0, 0, false };

    int seen = 0;
    for (int i = 0; i < SITE_LIMIT; i++) {
        if (siteAddress[i] == 0) {
            continue;
        }
        if (seen == index) {
            out.moduleRelative = static_cast<DWORD>(siteAddress[i]);
            out.count = siteCount_[i];
            out.expected = (out.moduleRelative == EXPECTED_A
                || out.moduleRelative == EXPECTED_B
                || out.moduleRelative == EXPECTED_C);
            return out;
        }
        seen++;
    }
    return out;
}

long Hooks::Slot11Probe::overflowCount() {
    return overflow;
}

const char* Hooks::Slot11Probe::writeReport() {
    static char path[MAX_PATH] = { 0 };
    char folder[MAX_PATH] = { 0 };
    if (::GetTempPathA(MAX_PATH, folder) == 0) {
        return nullptr;
    }
    ::sprintf_s(path, "%sbicelib-slot11.txt", folder);

    FILE* out = nullptr;
    if (::fopen_s(&out, path, "w") != 0 || out == nullptr) {
        return nullptr;
    }

    ::fprintf(out, "BiceLib slot-11 probe\n");
    ::fprintf(out, "module base 0x%08lx\n", static_cast<unsigned long>(Hooks::MODULE_BASE));
    ::fprintf(out, "status %s\n", reason);
    ::fprintf(out, "calls %ld\n", calls);
    ::fprintf(out, "overflow %ld\n", overflow);
    ::fprintf(out, "expected 0x%06lx 0x%06lx\n",
        static_cast<unsigned long>(EXPECTED_A), static_cast<unsigned long>(EXPECTED_B));

    // Every slot, claimed or not, so the shape of the table is visible rather than inferred - a
    // zero row is information too, and a run of them is what says the display never walked off
    // the end of the array into whatever sits after it.
    long summed = 0;
    for (int i = 0; i < SITE_LIMIT; i++) {
        const long address = siteAddress[i];
        const long count = siteCount_[i];
        summed += count;
        const char* kind = (address == 0) ? "empty"
            : (address == static_cast<long>(EXPECTED_A)
                || address == static_cast<long>(EXPECTED_B)) ? "known (CCombat slot 17)"
            : (address == static_cast<long>(EXPECTED_C)) ? "known (CLandCombatant forwarder)"
            : "UNKNOWN";
        ::fprintf(out, "slot %2d rva 0x%08lx calls %ld %s\n", i,
            static_cast<unsigned long>(address), count, kind);
    }
    ::fprintf(out, "sum of slot counts %ld (should equal calls minus overflow %ld)\n",
        summed, calls - overflow);

    ::fclose(out);
    return path;
}

void Hooks::Slot11Probe::reset() {
    for (int i = 0; i < SITE_LIMIT; i++) {
        ::InterlockedExchange(&siteCount_[i], 0);
        ::InterlockedExchange(&siteAddress[i], 0);
    }
    ::InterlockedExchange(&overflow, 0);
    ::InterlockedExchange(&calls, 0);
}
