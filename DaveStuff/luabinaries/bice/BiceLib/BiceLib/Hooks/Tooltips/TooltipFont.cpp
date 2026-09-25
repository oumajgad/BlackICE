#include <Hooks/Tooltips/TooltipFont.hpp>

#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <TextTable.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    /**
     * **`CEU3BitmapFont::GetStringWidth`**, the function the game measures a string with.
     * `this` is the font, the text is the first stack argument and its length the second,
     * negative meaning "to the NUL".
     *
     * Its first three instructions are `push ebp; mov ebp, esp; sub esp, 0x10` - six
     * bytes, so the five byte jump takes one NOP after it, and the stub reproduces all
     * three before resuming.
     */
    const uintptr_t SITE = 0x6FD700;
    const unsigned char SITE_BYTES[6] = { 0x55, 0x8B, 0xEC, 0x83, 0xEC, 0x10 };
    const uintptr_t RESUME = 0x6FD706;

    /**@brief the slot GetStringWidth sits in, so the call goes through the object's own
       table rather than to a fixed address*/
    const int WIDTH_SLOT = 10;
    typedef int(__thiscall* GetStringWidth)(void* self, const char* text, int length);

    /**
     * **How far into a string the marker is looked for.** The text belongs to the game and
     * may be given with an explicit length rather than a NUL, so the search is bounded
     * both ways: it stops at a NUL, and it stops here regardless. A tooltip is a few
     * hundred characters.
     */
    const int MOST_TEXT = 8192;

    /**
     * **How many tooltips to try before giving up.** A marker that never matches would
     * otherwise put the patch back for every tooltip for the rest of the session, which
     * is the one way this could end up costing something. Three is enough to rule out a
     * tooltip that happened to be measured oddly.
     */
    const int MOST_ATTEMPTS = 3;
    int attempts = 0;

    DWORD measureResume = 0;
    uintptr_t base = 0;

    void* caught = nullptr;
    const char* wanted = nullptr;
    bool installedFlag = false;
    const char* statusText = "not watching";

    /**@brief the text, in the length the caller gave, contains the marker*/
    bool carries(const char* text, int length) {
        if (text == nullptr || wanted == nullptr) {
            return false;
        }
        const size_t markerLength = strlen(wanted);
        if (markerLength == 0) {
            return false;
        }
        const int limit = (length < 0 || length > MOST_TEXT) ? MOST_TEXT : length;
        for (int i = 0; i + static_cast<int>(markerLength) <= limit; ++i) {
            if (text[i] == '\0') {
                return false;
            }
            if (memcmp(text + i, wanted, markerLength) == 0) {
                return true;
            }
        }
        return false;
    }

    /**
    @brief remembers the font, and nothing else

    **Deliberately does no work beyond the compare.** It runs on every string the
    interface lays out for as long as the patch is in, and it must not call back into the
    game while the patch is in - measuring anything here would re-enter the very function
    this is standing in front of.
    */
    void __cdecl noteFont(const char* text, int length, void* font) {
        if (caught != nullptr || font == nullptr || text == nullptr) {
            return;
        }
        if (!carries(text, length)) {
            return;
        }
        caught = font;
        statusText = "caught the font a tooltip was measured with";
    }

    /**
    @brief passes the call on, having noted whose font it was

    `ecx` is the font and survives `pushad` untouched, which is what lets it be handed on
    as an argument. The three instructions the jump displaced are done here rather than
    trampolined, so nothing else needs allocating.
    */
    __declspec(naked) void measuringText() {
        __asm {
            pushad
            pushfd

            mov eax, [esp + 40]         // the text; 32 for pushad, 4 for pushfd, 4 for the return
            mov edx, [esp + 44]         // its length, negative for "to the NUL"
            push ecx                    // the font this was called on
            push edx
            push eax
            call noteFont
            add esp, 12

            popfd
            popad

            push ebp                    // exactly the three instructions this replaced
            mov ebp, esp
            sub esp, 0x10
            jmp [measureResume]
        }
    }

    /**@brief the caught font's own GetStringWidth, for Text::Font to measure through*/
    int measureWithGameFont(const char* text, int length) {
        if (caught == nullptr) {
            return 0;
        }
        void** vftable = *reinterpret_cast<void***>(caught);
        if (vftable == nullptr) {
            return 0;
        }
        GetStringWidth width = reinterpret_cast<GetStringWidth>(vftable[WIDTH_SLOT]);
        return width(caught, text, length);
    }

    /**@brief puts the six bytes back*/
    void unpatch() {
        DWORD protection = 0;
        void* site = reinterpret_cast<void*>(base + SITE);
        if (!VirtualProtect(site, sizeof SITE_BYTES, PAGE_EXECUTE_READWRITE, &protection)) {
            return;
        }
        memcpy(site, SITE_BYTES, sizeof SITE_BYTES);
        DWORD unused = 0;
        VirtualProtect(site, sizeof SITE_BYTES, protection, &unused);
        installedFlag = false;
    }
}

bool Hooks::Tooltips::TooltipFont::watchFor(const char* marker) {
    if (caught != nullptr || installedFlag) {
        return true;
    }
    if (marker == nullptr || *marker == '\0') {
        statusText = "no marker to watch for";
        return false;
    }
    if (attempts >= MOST_ATTEMPTS) {
        return false;
    }
    ++attempts;

    base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof SITE_BYTES)) {
        statusText = "GetStringWidth does not begin where this build expects";
        ERROR_OUT(printf("TooltipFont: %#010x is not the prologue expected\n",
            static_cast<unsigned>(base + SITE)));
        return false;
    }

    wanted = marker;
    measureResume = static_cast<DWORD>(base + RESUME);
    if (!Hooks::hook(reinterpret_cast<void*>(base + SITE), &measuringText, 5, 1)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "watching for a tooltip being measured";
    INFO_OUT(printf("TooltipFont: watching GetStringWidth for a tooltip carrying \"%s\"\n",
        marker));
    return true;
}

void Hooks::Tooltips::TooltipFont::stopWatching() {
    if (installedFlag) {
        unpatch();
    }
    if (caught == nullptr) {
        if (attempts >= MOST_ATTEMPTS) {
            statusText = "no tooltip carrying the marker was measured; still on the "
                "descriptor";
            ERROR_OUT(printf("TooltipFont: %s\n", statusText));
        }
        return;
    }

    // Wired up only now, with the patch out: the first thing Text::Font does with this is
    // measure a space, and doing that while the patch was still in would re-enter it.
    Text::useGameMeasure(&measureWithGameFont);
    INFO_OUT(printf("TooltipFont: measuring with the game's own font %#010x - a space is "
        "%d pixels\n", static_cast<unsigned>(reinterpret_cast<uintptr_t>(caught)),
        measureWithGameFont(" ", 1)));
}

bool Hooks::Tooltips::TooltipFont::known() {
    return caught != nullptr && !installedFlag;
}

const char* Hooks::Tooltips::TooltipFont::status() {
    return statusText;
}
