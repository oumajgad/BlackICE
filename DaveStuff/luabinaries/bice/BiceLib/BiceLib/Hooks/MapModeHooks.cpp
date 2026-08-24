#include <Hooks/MapModeHooks.hpp>

#include <GameState/CustomMapMode.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>

namespace {
    // Two places inside the VP map mode's colouring loop.
    //
    // The victory point read is answered with zero, which sends every province down
    // the branch for one that has none. That does two things: it stops the loop from
    // giving a province the owner's colour, and it stops the second colour conversion
    // further down from ever running - so there is exactly one place left where a
    // colour is decided.
    //
    // That place is the call below, which every province now reaches, and which is
    // where all of the deciding happens.
    const uintptr_t VICTORY_POINT_SITE = 0x4666B6;
    const uintptr_t COLOUR_CALL_SITE = 0x4666B1;
    const uintptr_t COLOUR_CONVERTER = 0x6628B0;

    // mov ecx, [esi+0x34] / test ecx, ecx - five bytes, so a call fits exactly.
    const unsigned char EXPECTED_VICTORY_POINTS[5] = { 0x8B, 0x4E, 0x34, 0x85, 0xC9 };
    const unsigned char EXPECTED_COLOUR_CALL[5] = { 0xE8, 0xFA, 0xC1, 0x1F, 0x00 };

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the stubs before anything else. Off, and they do in assembly exactly
    // what the instructions they replaced did - no call into our code, so nothing of
    // ours can disturb a register, a flag or the floating point state.
    unsigned char active = 0;

    uintptr_t originalConverter = 0;

    /**@brief what the loop should think this province's victory points are*/
    int __cdecl victoryPointsFor(uintptr_t province) {
        return CustomMapMode::victoryPointsFor(province);
    }

    /**@brief the colour for the province being painted, or 0 to keep the game's*/
    uint32_t __cdecl decideColour(uintptr_t province, int viewingCountry) {
        return CustomMapMode::colourFor(province, viewingCountry);
    }

    /**
    @brief stands in for `mov ecx,[esi+0x34]` and the `test` after it

    esi is the province here. Two things have to come out exactly as those two
    instructions left them: ecx, and the flags, which the `jle` further down reads.
    And one thing has to come out untouched - eax, which is carrying the colour from
    the conversion five bytes back and which the branch this feeds goes on to store.
    A call would otherwise land its return value in it.
    */
    __declspec(naked) void hookedVictoryPoints() {
        __asm {
            cmp active, 0
            jne takeOver

            mov ecx, [esi + 0x34]   // exactly the instructions this replaced
            test ecx, ecx
            ret

        takeOver:
            push eax

            push esi
            call victoryPointsFor
            add esp, 4
            mov ecx, eax

            pop eax                 // leaves the flags alone, so the test still counts
            test ecx, ecx
            ret
        }
    }

    /**
    @brief stands in for the game's CColor to dword conversion

    Called with ecx pointing at the CColor, exactly as the original was, and has to
    leave the packed colour in eax.

    The province is worked out the way the loop itself does: the argument at [ebp+8],
    its array at +0x2C, indexed by the loop counter in ebx, and the province at +0xC of
    that. esi holds it here too, but not everywhere in the loop, so the longer route is
    the one that keeps working if this ever has to move.

    edi is the country the map is being drawn for, and nothing in the loop writes it -
    the game uses it for the fog of war the same way we use it to tell whose provinces
    are whose.
    */
    __declspec(naked) void hookedPackColour() {
        __asm {
            cmp active, 0
            jne takeOver

            mov eax, originalConverter   // ecx is the CColor, as the call expected
            jmp eax                      // its return value and ret become ours

        takeOver:
            push ebx
            push esi
            push edi

            mov eax, [ebp + 8]
            mov eax, [eax + 0x2C]
            mov eax, [eax + ebx * 4]
            mov eax, [eax + 0x0C]

            push ecx                    // decideColour may clobber it
            push edi                    // the country the map is drawn for
            push eax                    // the province
            call decideColour
            add esp, 8
            pop ecx

            test eax, eax
            jnz keepOurs

            mov eax, originalConverter  // ecx is still the CColor
            call eax

        keepOurs:
            pop edi
            pop esi
            pop ebx
            ret
        }
    }

    /**@brief refuses unless the bytes are exactly what this build should have there*/
    bool bytesMatch(unsigned char* site, const unsigned char* expected) {
        for (int i = 0; i < 5; i++) {
            unsigned char byte = 0;
            if (!Mem::tryRead(reinterpret_cast<uintptr_t>(site + i), byte)
                || byte != expected[i]) {
                return false;
            }
        }
        return true;
    }

    /**@brief writes a five byte call, whatever was there before*/
    bool writeCall(unsigned char* site, void* target) {
        const uintptr_t relative = reinterpret_cast<uintptr_t>(target)
            - reinterpret_cast<uintptr_t>(site) - 5;

        DWORD protection = 0;
        if (!VirtualProtect(site, 5, PAGE_EXECUTE_READWRITE, &protection)) {
            return false;
        }
        site[0] = 0xE8;
        *reinterpret_cast<uint32_t*>(site + 1) = static_cast<uint32_t>(relative);
        DWORD ignored = 0;
        VirtualProtect(site, 5, protection, &ignored);
        FlushInstructionCache(GetCurrentProcess(), site, 5);
        return true;
    }
}

bool Hooks::MapMode::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    unsigned char* victoryPoints = reinterpret_cast<unsigned char*>(base + VICTORY_POINT_SITE);
    unsigned char* colourCall = reinterpret_cast<unsigned char*>(base + COLOUR_CALL_SITE);

    // Both are checked before either is written, so a build this does not fit leaves
    // the game untouched rather than half patched.
    if (!bytesMatch(victoryPoints, EXPECTED_VICTORY_POINTS)
        || !bytesMatch(colourCall, EXPECTED_COLOUR_CALL)) {
        statusText = "the code is not what this build expects";
        ERROR_OUT(printf("MapMode hook: the map mode code at %#010x is not what was "
            "expected\n", static_cast<unsigned>(base + VICTORY_POINT_SITE)));
        return false;
    }

    originalConverter = base + COLOUR_CONVERTER;

    // The colour call sits five bytes before the victory point read, so it goes first
    // and neither write lands inside the other.
    if (!writeCall(colourCall, &hookedPackColour)
        || !writeCall(victoryPoints, &hookedVictoryPoints)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("MapMode hooks installed at %#010x and %#010x\n",
        static_cast<unsigned>(base + VICTORY_POINT_SITE),
        static_cast<unsigned>(base + COLOUR_CALL_SITE)));
    return true;
}

void Hooks::MapMode::setActive(bool on) {
    active = on ? 1 : 0;
}

bool Hooks::MapMode::installed() {
    return installedFlag;
}

const char* Hooks::MapMode::status() {
    return statusText;
}
