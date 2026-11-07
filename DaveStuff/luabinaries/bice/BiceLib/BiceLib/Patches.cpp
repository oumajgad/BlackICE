#include <Patches.hpp>

#include <Hooks/Hooks.hpp>
#include <utils.hpp>

#include <cstdio>

namespace {
    /**@brief one run of bytes a patch changes: what vanilla holds there and what it becomes*/
    struct Site
    {
        uintptr_t rva;
        const BYTE* vanilla;
        const BYTE* patched;
        int length;
    };

    /**
    @brief applies every site of one patch, or none of them

    Each site has to hold its vanilla or its patched bytes before anything is written; the
    sites still vanilla are then written. See Patches.hpp.
    */
    bool apply(uintptr_t base, const char* name, const Site* sites, int count) {
        if (base == 0) {
            ERROR_OUT(printf("%s: hoi3_tfh.exe is not loaded\n", name));
            return false;
        }
        for (int i = 0; i < count; i++) {
            const uintptr_t at = base + sites[i].rva;
            if (!Hooks::bytesAre(at, sites[i].vanilla, sites[i].length)
                && !Hooks::bytesAre(at, sites[i].patched, sites[i].length)) {
                ERROR_OUT(printf("%s: rva %#08x is not what this build holds there\n",
                    name, static_cast<unsigned>(sites[i].rva)));
                return false;
            }
        }
        for (int i = 0; i < count; i++) {
            const uintptr_t at = base + sites[i].rva;
            if (Hooks::bytesAre(at, sites[i].patched, sites[i].length)) {
                continue;
            }
            if (!Patches::patchBytes(reinterpret_cast<void*>(at), sites[i].patched, sites[i].length)) {
                ERROR_OUT(printf("%s: could not make rva %#08x writable\n",
                    name, static_cast<unsigned>(sites[i].rva)));
                return false;
            }
        }
        return true;
    }
}

bool Patches::patchBytes(void* address, const BYTE values[], int len) {
    if (address == nullptr || len <= 0) {
        return false;
    }
    DWORD protection = 0;
    if (!VirtualProtect(address, len, PAGE_EXECUTE_READWRITE, &protection)) {
        return false;
    }
    BYTE* const target = static_cast<BYTE*>(address);
    for (int i = 0; i < len; i++) {
        target[i] = values[i];
    }
    DWORD unused = 0;
    VirtualProtect(address, len, protection, &unused);
    FlushInstructionCache(GetCurrentProcess(), address, len);
    return true;
}

/**
 * Keeps the ministers' share of each category's technology decay modifier.
 *
 * `CCountry::RebuildStaticModifiers` (`0xDDD80`) zeroes `CCountry +0x1174[category]`
 * (`0xDDFBA`), adds every minister's figure for each category into it (`0xDE37B`), and then
 * walks the categories once more and **stores** the technology's own figure over the top -
 * `mov [ecx+esi], eax` at `0xDE3ED`. So the ministers' figures never survived the rebuild.
 * This makes that last write `add [ecx+esi], eax` - one byte, the opcode - so the total is
 * the ministers' plus the technology's. The zeroing at the top is why it cannot accumulate
 * from one rebuild to the next.
 */
bool Patches::fixMinisterTechDecay(uintptr_t moduleBase) {
    static const BYTE vanilla[3] = { 0x89, 0x04, 0x31 };   // mov [ecx+esi], eax
    static const BYTE patched[3] = { 0x01, 0x04, 0x31 };   // add [ecx+esi], eax
    const Site sites[] = { { 0xDE3ED, vanilla, patched, 3 } };
    return apply(moduleBase, "fixMinisterTechDecay", sites, 1);
}

/**
 * Stops war exhaustion being paid out into neutrality and reset.
 *
 * Vanilla adds the month's war exhaustion to `CCountry +0xAD0`, floors it at 0, caps it, and
 * when it is above 0 hands it to `0x4FBF80` and zeroes it. The first site stores 0 instead
 * of adding, so the hand-over at `0x4DCC09` never has anything to hand over; the second
 * nops the reset after it.
 *
 * **A third site was dropped on 2026-11-07.** The patch also wrote `0x01` to the ModRM byte
 * at `0xDCC12`, making the hand-over's `mov [ecx], ?` read `eax` - which is the byte vanilla
 * already holds there, so the write never changed anything. An exe patched on disk was once
 * found holding `0x19` (`ebx`) at that byte; that is unreachable too, because the first site
 * leaves nothing above 0 to hand over.
 */
bool Patches::disableWarExhaustionNeutralityReset(uintptr_t moduleBase) {
    // add [esi+0xAD0], eax; jns +6; mov [esi+0xAD0], ebx
    static const BYTE storeVanilla[14] = {
        0x01, 0x86, 0xD0, 0x0A, 0x00, 0x00, 0x79, 0x06, 0x89, 0x9E, 0xD0, 0x0A, 0x00, 0x00 };
    // mov dword ptr [esi+0xAD0], 0; four nops
    static const BYTE storePatched[14] = {
        0xC7, 0x86, 0xD0, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x90 };
    // mov [esi+0xAD0], ebx
    static const BYTE resetVanilla[6] = { 0x89, 0x9E, 0xD0, 0x0A, 0x00, 0x00 };
    static const BYTE resetPatched[6] = { 0x90, 0x90, 0x90, 0x90, 0x90, 0x90 };
    const Site sites[] = {
        { 0xDCBD3, storeVanilla, storePatched, 14 },
        { 0xDCC18, resetVanilla, resetPatched, 6 },
    };
    return apply(moduleBase, "disableWarExhaustionNeutralityReset", sites, 2);
}

/**
 * Turns two conditional jumps in the AI's expeditionary force logic into plain ones.
 *
 * `0F 85`/`0F 84 rel32` (jne/je) become `90 E9 rel32` - a nop and a jmp with the same
 * displacement, which lands on the same target since both end at the same byte.
 */
bool Patches::disableInterAiExpeditionaries(uintptr_t moduleBase) {
    static const BYTE firstVanilla[6] = { 0x0F, 0x85, 0x91, 0x05, 0x00, 0x00 };   // jne
    static const BYTE firstPatched[6] = { 0x90, 0xE9, 0x91, 0x05, 0x00, 0x00 };
    static const BYTE secondVanilla[6] = { 0x0F, 0x84, 0x32, 0x02, 0x00, 0x00 };  // je
    static const BYTE secondPatched[6] = { 0x90, 0xE9, 0x32, 0x02, 0x00, 0x00 };
    const Site sites[] = {
        { 0x4B348A, firstVanilla, firstPatched, 6 },
        { 0x4B37E5, secondVanilla, secondPatched, 6 },
    };
    return apply(moduleBase, "disableInterAiExpeditionaries", sites, 2);
}

/**
 * Stops a unit being given a model it has not researched.
 *
 * `CHistoricalModel::PickBestModel` (`0x183230`) chooses which model a unit is built
 * with: for every model it adds up, over the technologies that model asks for,
 * `|researched level - asked for level| * 1000`, and takes the model with the smallest
 * total. The **absolute value is the bug**: a model that wants more than the country has
 * scores exactly as well as one that wants less by the same amount, so a country can be
 * handed a model it cannot field.
 *
 * The patch replaces the two byte `neg ecx` that makes the difference positive with a
 * jump into the padding after the function, where six bytes put a flat `0x100000` in ecx
 * and two more jump back. So **a model that asks for more than is researched takes a
 * fixed, enormous penalty** instead of a small one, and loses to any model that does not.
 *
 * | | |
 * | --- | --- |
 * | `0x1832A8` | `neg ecx` becomes `jmp +0x2A`, into the padding |
 * | `0x1832D4` | six bytes of padding become `mov ecx, 0x100000` |
 * | `0x1832DA` | two more become `jmp -0x32`, back to the `add eax, ecx` |
 *
 * See GameClasses/CHistoricalModel.hpp for the class and the picker.
 */
bool Patches::historicalModelLogicFix(uintptr_t moduleBase) {
    static const BYTE negVanilla[2] = { 0xF7, 0xD9 };                     // neg ecx
    static const BYTE negPatched[2] = { 0xEB, 0x2A };                     // jmp 0x1832D4
    static const BYTE padVanilla[8] = { 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC };
    static const BYTE padPatched[8] = {
        0xC7, 0xC1, 0x00, 0x00, 0x10, 0x00,                               // mov ecx, 0x100000
        0xEB, 0xCE };                                                     // jmp 0x1832AA
    const Site sites[] = {
        { 0x1832A8, negVanilla, negPatched, 2 },
        { 0x1832D4, padVanilla, padPatched, 8 },
    };
    return apply(moduleBase, "historicalModelLogicFix", sites, 2);
}

/**
 * Makes the Simplified Terrain map mode colour the sea as well as the land.
 *
 * That map mode's colouring loop already visits all 3,547 sea provinces and works out
 * a colour for each. The water ignores those colours, because the water is drawn by a
 * shader of its own that comes in two forms: water.fx compiles every technique twice,
 * once plainly and once with PROVINCE_COLOR defined, and only the second samples the
 * province colour textures and mixes them into the water.
 *
 * Which of the two is used comes down to a single style number the map mode setter
 * writes to the graphics settings at +0xF4. The renderer tests it in two places - once
 * to decide whether to refill the sea's colour texture at all, and once to pick
 * WaterNearColor over WaterNear - and both accept only 16, 18 and 19. Air writes 18
 * and Naval writes 19, which is why the sea is coloured in those two modes. Simplified
 * Terrain writes 8.
 *
 * Changing that 8 is the whole patch. Any of 16, 18 and 19 produces a coloured sea;
 * 18 is the air map mode's value. Only this map mode's setter is touched, so
 * Infrastructure, which writes the same 8 from a setter of its own, keeps plain water.
 *
 * reversing/findings/FINDINGS-mapmode.md traces the path from the colour store to the shader.
 */
bool Patches::seaTerrainColourInSimplifiedMapMode(uintptr_t moduleBase) {
    // mov dword ptr [eax+0xF4], 8 - the last of three settings the Simplified Terrain
    // setter writes. The field is GameSettings::Offsets::map_style; it is a literal here
    // because this is the game's own instruction being matched byte for byte.
    static const BYTE vanilla[10] = { 0xC7, 0x80, 0xF4, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00 };
    // the same with 18, the number the air map mode uses
    static const BYTE patched[10] = { 0xC7, 0x80, 0xF4, 0x00, 0x00, 0x00, 0x12, 0x00, 0x00, 0x00 };
    const Site sites[] = { { 0x266E74, vanilla, patched, 10 } };
    return apply(moduleBase, "seaTerrainColourInSimplifiedMapMode", sites, 1);
}
