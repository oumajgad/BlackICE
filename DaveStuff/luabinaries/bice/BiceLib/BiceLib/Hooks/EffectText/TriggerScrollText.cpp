#include <Hooks/EffectText/TriggerScrollText.hpp>

#include <GameClasses/GameString.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <string>
#include <vector>

namespace {
    // **The last instruction of `CAndTrigger::GetBlockText` before its epilogue**:
    // `mov ecx, [esp + 0xE4]`, which picks up the SEH link the epilogue then restores.
    // Seven bytes, and the one place every path through the function converges - two
    // branches inside it land exactly here.
    //
    // Standing here rather than over the epilogue itself is deliberate. The epilogue
    // writes `fs:[0]`, and reproducing that from inline assembly makes MSVC warn that
    // a handler is being registered unsafely (C4733) - it cannot tell that apart from
    // a chain being put back. One instruction earlier, the unlink stays the game's.
    //
    // At this point `esi` is the finished text and `ebp` is still the frame, so the
    // depth is where every renderer keeps it, at `[ebp + 0x14]`.
    const uintptr_t AND_EXIT_SITE = 0x5D0CB0;
    const unsigned char AND_EXIT_BYTES[7] =
        { 0x8B, 0x8C, 0x24, 0xE4, 0x00, 0x00, 0x00 };
    const uintptr_t AND_EXIT_RESUME = 0x5D0CB7;

    /**@brief read by the naked stub, so a plain word*/
    DWORD andExitResume = 0;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    /**
     * How long a key has to be held before it starts repeating, and how fast.
     *
     * The text is rebuilt far more often than once a frame, so without this a single
     * press would scroll by however many times the tooltip happened to be built while
     * the key was down.
     */
    const ULONGLONG REPEAT_MS = 130;

    /**@brief how much has to stay on screen, so scrolling cannot empty the tooltip*/
    const int KEEP_VISIBLE = 3;

    /**
     * How many lines mean the tooltip is about to run off the screen.
     *
     * **A guess, and only about when to offer**: roughly what fits at the resolutions
     * this is played at. Getting it wrong costs a line of advice on a tooltip that did
     * not need one, or none on a tooltip that did - scrolling itself works at any
     * length, and the count of what is hidden above appears the moment anything is.
     *
     * The line it adds counts towards the overflow it is warning about, so a list of
     * exactly this many loses its last line to the notice. That is the right way round:
     * a line nobody can see is worth less than knowing the rest is reachable.
     */
    const int HINT_FROM_LINES = 50;

    int offset = 0;             // how many lines are hidden above
    std::string lastWhole;      // the untrimmed text, to notice the tooltip changing

    /**
     * How long after a render a requirement tooltip still counts as being on screen.
     *
     * The text is rebuilt far more often than once a frame while one is hovered, so
     * this only has to outlast the gap between two rebuilds. Short, because every
     * millisecond of it is a millisecond in which the wheel could be taken from the map
     * for a tooltip that has just gone.
     */
    const ULONGLONG ON_SCREEN_MS = 250;

    /**@brief lines per notch, the usual three*/
    const int WHEEL_LINES = 3;

    long pendingWheel = 0;          // notches taken but not yet applied
    ULONGLONG lastRenderAt = 0;     // when a requirement tree was last built
    bool scrollableNow = false;     // ...and whether that one was long enough to scroll

    bool held(int key) {
        return (GetAsyncKeyState(key) & 0x8000) != 0;
    }

    /**
    @brief the game's string as its own bytes, with nothing converted

    Not `HDS::readString`, which turns Windows-1252 into UTF-8 for showing in the
    overlay. This goes straight back to the game, so it has to stay exactly the bytes
    the game produced - colour codes and umlauts alike.
    */
    std::string rawText(const void* gameString) {
        const char* bytes = reinterpret_cast<const char*>(gameString);
        const int length = *reinterpret_cast<const int*>(bytes + 0x10);
        const int capacity = *reinterpret_cast<const int*>(bytes + 0x14);
        if (length <= 0 || capacity < 15 || length > capacity) {
            return std::string();
        }
        const char* data = capacity > 15
            ? *reinterpret_cast<const char* const*>(bytes) : bytes;
        if (data == nullptr) {
            return std::string();
        }
        return std::string(data, static_cast<size_t>(length));
    }

    /**
    @brief moves the scroll on, and says where it ended up

    Alt has to be down for either arrow to mean anything here, so nothing is taken away
    from whatever the arrows do elsewhere. Held keys repeat; a key that is merely still
    down between two rebuilds of the same tooltip does not.
    */
    void readKeys(int lines) {
        static bool wasUp = false;
        static bool wasDown = false;
        static ULONGLONG lastStep = 0;

        const bool alt = held(VK_MENU);
        const bool down = alt && held(VK_DOWN);
        const bool up = alt && held(VK_UP);
        const ULONGLONG now = GetTickCount64();

        // The wheel has already been turned into lines; take whatever has arrived
        // since the last render, whether or not a key is also down.
        offset += pendingWheel;
        pendingWheel = 0;

        if (down && (!wasDown || now - lastStep >= REPEAT_MS)) {
            offset++;
            lastStep = now;
        }
        else if (up && (!wasUp || now - lastStep >= REPEAT_MS)) {
            offset--;
            lastStep = now;
        }
        wasDown = down;
        wasUp = up;

        const int most = lines - KEEP_VISIBLE;
        if (offset > most) {
            offset = most;
        }
        if (offset < 0) {
            offset = 0;
        }
    }

    /**
    @brief drops the scrolled-off lines from the front of the finished tree

    Called with the whole requirement text, once it is built and before the tooltip
    sees it.

    @param text  the game string the renderer filled
    @param depth what the renderer was called with; 0 is the whole tree
    */
    void __cdecl scrollRoot(void* text, int depth) {
        if (text == nullptr || depth != 0) {
            return;
        }

        const std::string whole = rawText(text);
        if (whole.empty()) {
            return;
        }

        // A different tooltip - or the same one rebuilt with different contents -
        // starts again from the top. Compared against the text *before* trimming, which
        // is the same every time for as long as one thing is hovered.
        if (whole != lastWhole) {
            lastWhole = whole;
            offset = 0;
            pendingWheel = 0;   // and nothing the wheel did to the last one carries over
        }

        int lines = 1;
        for (size_t i = 0; i < whole.size(); i++) {
            if (whole[i] == '\n') {
                lines++;
            }
        }
        // What the wheel needs to know, and the only way it can: while a tooltip is
        // hovered this runs over and over, so a recent render means one is on screen.
        lastRenderAt = GetTickCount64();
        scrollableNow = lines > KEEP_VISIBLE;

        if (lines <= KEEP_VISIBLE) {
            offset = 0;
            pendingWheel = 0;
            return;         // nothing to scroll; leave the text exactly as it was
        }

        readKeys(lines);

        // Nothing scrolled away yet: say that it can be, but only once the list is
        // long enough that some of it is likely off the screen.
        if (offset <= 0) {
            if (lines < HINT_FROM_LINES) {
                return;     // it fits; leave the text exactly as the game built it
            }
            const std::string hinted =
                std::string("\xA7Y... hold Alt and scroll, "
                    "with the wheel or the arrow keys\xA7W\n") + whole;
            Game::assignTo(text, hinted.c_str());
            return;
        }

        size_t from = 0;
        for (int i = 0; i < offset && from != std::string::npos; i++) {
            from = whole.find('\n', from);
            if (from != std::string::npos) {
                from++;
            }
        }
        if (from == std::string::npos || from >= whole.size()) {
            return;
        }

        char marker[80];
        const int written = _snprintf(marker, sizeof(marker) - 1,
            "\xA7Y... %d more above (Alt + wheel or Up/Down)\xA7W\n", offset);
        if (written <= 0) {
            return;
        }
        marker[written] = '\0';

        const std::string shown = std::string(marker) + whole.substr(from);
        Game::assignTo(text, shown.c_str());
    }

    /**
    @brief trims the finished tree, on the way out of the `and` renderer

    The text is in `esi` and the frame is still up, so this happens before a single
    register is restored. Everything a call could disturb is saved around it, and then
    the one instruction this replaced is done here - after `esp` is back, because it
    reads through it.
    */
    __declspec(naked) void andExit() {
        __asm {
            pushad
            pushfd
            push dword ptr [ebp + 0x14]     // the depth it was called with
            push esi                        // the finished text
            call scrollRoot
            add esp, 8
            popfd
            popad

            mov ecx, dword ptr [esp + 0xE4] // exactly the instruction this replaced
            jmp [andExitResume]
        }
    }
}

bool Hooks::EffectText::TriggerScroll::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    if (!Hooks::bytesAre(base + AND_EXIT_SITE, AND_EXIT_BYTES, 7)) {
        statusText = "the and renderer's exit is not what this build expects";
        ERROR_OUT(printf("TriggerScroll: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + AND_EXIT_SITE)));
        return false;
    }

    andExitResume = static_cast<DWORD>(base + AND_EXIT_RESUME);

    // Five of jump and two of nop, over one instruction the stub does itself.
    if (!Hooks::hook(reinterpret_cast<void*>(base + AND_EXIT_SITE), &andExit, 5, 2)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("TriggerScroll: hold Alt and press Up or Down over a "
        "requirement tooltip\n"));
    return true;
}

bool Hooks::EffectText::TriggerScroll::takeWheel(int delta) {
    if (!installedFlag || !scrollableNow || delta == 0) {
        return false;
    }

    // **Alt, the same as the arrow keys.** A decision or a triggered modifier puts its
    // conditions in a tooltip over a list that scrolls, and the pointer is on the
    // tooltip the whole time it is being read - so taking the wheel on sight took it
    // from the list underneath, which is the one the player was trying to move.
    if (!held(VK_MENU)) {
        return false;
    }
    if (GetTickCount64() - lastRenderAt > ON_SCREEN_MS) {
        return false;       // no requirement tooltip is up; leave the wheel alone
    }

    // Forward is positive and means "towards the top of the list", which is a smaller
    // offset - so the sign turns over on the way in.
    const int notches = delta / WHEEL_DELTA;
    if (notches == 0) {
        return false;       // a fraction of a notch; nothing to do, and not ours to eat
    }
    pendingWheel -= notches * WHEEL_LINES;
    return true;
}

bool Hooks::EffectText::TriggerScroll::installed() {
    return installedFlag;
}

const char* Hooks::EffectText::TriggerScroll::status() {
    return statusText;
}
