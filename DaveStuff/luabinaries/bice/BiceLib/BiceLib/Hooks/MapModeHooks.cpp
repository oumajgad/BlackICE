#include <Hooks/MapModeHooks.hpp>

#include <GameState/CustomMapMode.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CInGameIdler.hpp>
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
    // That place is the call below. With the victory point read answered as zero,
    // every province reaches it, and every colour is decided there.
    const uintptr_t VICTORY_POINT_SITE = 0x4666B6;
    const uintptr_t COLOUR_CALL_SITE = 0x4666B1;
    const uintptr_t COLOUR_CONVERTER = 0x6628B0;

    // What the game calls to colour the map for the VP map mode, reached the way its
    // own dispatch reaches it: a switch on the current mode, where 7 is VP, calling
    // this with ecx pointing at the map. The map hangs off the game state, and the
    // mode it is showing is on it.
    const uintptr_t VP_RECOLOUR = 0x267710;

    // Inside the function that builds the tooltip for the province under the mouse. It
    // asks the map which mode is on screen - a virtual call, which answers
    // current_map_mode - and switches on the answer once to pick the mode's lines, so
    // changing the answer here changes which tooltip is shown and nothing else.
    const uintptr_t TOOLTIP_MODE_SITE = 0x98422;

    // mov ecx, [esi+0x34] / test ecx, ecx - five bytes, so a call fits exactly.
    const unsigned char EXPECTED_VICTORY_POINTS[5] = { 0x8B, 0x4E, 0x34, 0x85, 0xC9 };
    const unsigned char EXPECTED_COLOUR_CALL[5] = { 0xE8, 0xFA, 0xC1, 0x1F, 0x00 };

    // mov eax, [edx+0x164] / call eax - eight bytes, a call and three nops.
    const unsigned char EXPECTED_TOOLTIP_MODE[8] = { 0x8B, 0x82, 0x64, 0x01, 0x00, 0x00, 0xFF, 0xD0 };

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the stubs before anything else. While it is clear they reproduce, in
    // assembly, exactly what the instructions they replaced did, with no call into
    // BiceLib - so nothing here can disturb a register, a flag or the floating point
    // state.
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

    /**@brief the map mode whose tooltip the game should build*/
    int __cdecl tooltipMode(int mode) {
        return CustomMapMode::tooltipModeFor(mode);
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

    edi is the country the map is being drawn for, and nothing in the loop writes it.
    The game uses it for the fog of war; this hook uses it to tell whose provinces are
    whose.
    */
    __declspec(naked) void hookedPackColour() {
        __asm {
            cmp active, 0
            jne takeOver

            mov eax, originalConverter   // ecx is the CColor, as the call expected
            jmp eax                      // its return value and ret stand in for this one

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

    /**
    @brief stands in for `mov eax,[edx+0x164]` and the `call eax` after it

    edx is the map's vftable and ecx the map, as the game left them for the call. The
    game's code after it only reads eax, the mode, and the cmp there sets the flags
    afresh; ecx and edx are the callee's to clobber in any case.

    Off, the getter is jumped to rather than called, so its ret comes straight back to
    the site, as the original call would have.
    */
    __declspec(naked) void hookedTooltipMode() {
        __asm {
            mov eax, [edx + 0x164]      // the getter, as the replaced load had it
            cmp active, 0
            jne takeOver
            jmp eax

        takeOver:
            call eax                    // ecx is the map, as the call expected
            push eax
            call tooltipMode
            add esp, 4
            ret
        }
    }

    /**@brief refuses unless the bytes are exactly what this build should have there*/
    bool bytesMatch(unsigned char* site, const unsigned char* expected, int length = 5) {
        for (int i = 0; i < length; i++) {
            unsigned char byte = 0;
            if (!Mem::tryRead(reinterpret_cast<uintptr_t>(site + i), byte)
                || byte != expected[i]) {
                return false;
            }
        }
        return true;
    }

    /**@brief writes a five byte call, whatever was there before, and nops to fill length*/
    bool writeCall(unsigned char* site, void* target, int length = 5) {
        const uintptr_t relative = reinterpret_cast<uintptr_t>(target)
            - reinterpret_cast<uintptr_t>(site) - 5;

        DWORD protection = 0;
        if (!VirtualProtect(site, length, PAGE_EXECUTE_READWRITE, &protection)) {
            return false;
        }
        site[0] = 0xE8;
        *reinterpret_cast<uint32_t*>(site + 1) = static_cast<uint32_t>(relative);
        for (int i = 5; i < length; i++) {
            site[i] = 0x90;
        }
        DWORD ignored = 0;
        VirtualProtect(site, length, protection, &ignored);
        FlushInstructionCache(GetCurrentProcess(), site, length);
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
    unsigned char* tooltipSite = reinterpret_cast<unsigned char*>(base + TOOLTIP_MODE_SITE);

    // All are checked before any is written, so a build this does not fit leaves the
    // game untouched rather than half patched.
    if (!bytesMatch(victoryPoints, EXPECTED_VICTORY_POINTS)
        || !bytesMatch(colourCall, EXPECTED_COLOUR_CALL)
        || !bytesMatch(tooltipSite, EXPECTED_TOOLTIP_MODE, sizeof(EXPECTED_TOOLTIP_MODE))) {
        statusText = "the code is not what this build expects";
        ERROR_OUT(printf("MapMode hook: the map mode code at %#010x is not what was "
            "expected\n", static_cast<unsigned>(base + VICTORY_POINT_SITE)));
        return false;
    }

    originalConverter = base + COLOUR_CONVERTER;

    // The colour call sits five bytes before the victory point read, so it goes first
    // and neither write lands inside the other.
    if (!writeCall(colourCall, &hookedPackColour)
        || !writeCall(victoryPoints, &hookedVictoryPoints)
        || !writeCall(tooltipSite, &hookedTooltipMode, sizeof(EXPECTED_TOOLTIP_MODE))) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("MapMode hooks installed at %#010x, %#010x and %#010x\n",
        static_cast<unsigned>(base + VICTORY_POINT_SITE),
        static_cast<unsigned>(base + COLOUR_CALL_SITE),
        static_cast<unsigned>(base + TOOLTIP_MODE_SITE)));
    return true;
}

bool Hooks::MapMode::repaint() {
    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0 || !installedFlag) {
        return false;
    }

    const uintptr_t state = CCurrentGameState::current();
    if (state == 0) {
        return false;   // no session, so nothing to paint
    }

    uint32_t map = 0;
    if (!Mem::tryRead(state + CCurrentGameState::Offsets::in_game_screen, map)
        || map == 0) {
        return false;
    }

    // Only when the VP map mode is what is on screen. Should this field ever hold
    // something other than the mode, the repaint never happens and the player
    // switches map mode by hand instead, which is the behaviour without a repaint at
    // all.
    int32_t current = -1;
    if (!Mem::tryRead(map + CInGameIdler::Offsets::current_map_mode, current)
        || current != CInGameIdler::MapMode::VICTORY_POINTS) {
        return false;
    }

    const uintptr_t recolour = base + VP_RECOLOUR;
    __asm {
        mov ecx, map
        mov eax, recolour
        call eax
    }
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
