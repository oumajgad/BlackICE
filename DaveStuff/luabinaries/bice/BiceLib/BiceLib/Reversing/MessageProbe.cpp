#include <Reversing/MessageProbe.hpp>

#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    /**
     * **`PostMessage`**, whose prologue is `push ebp; mov ebp, esp; push -1` - five bytes
     * exactly, so the jump needs no NOP after it and the stub reproduces all three.
     */
    const uintptr_t SITE = 0x110A50;
    const unsigned char SITE_BYTES[5] = { 0x55, 0x8B, 0xEC, 0x6A, 0xFF };
    const uintptr_t RESUME = 0x110A55;

    /**@brief how much of the message is passed by value*/
    const unsigned MESSAGE_BYTES = 0x78;

    /**
     * **`BuildMessagePopupText`**, the function that actually fills a popup in: `_HEADER`,
     * `Header`, `Line1` to `Line6`, the buttons, the line spacing. `ret 4`, the popup its
     * one stack argument.
     *
     * The probe stood on 0xA6040 first, on the strength of it being passed to every popup
     * the post builds. That was wrong - it printed nothing even for a message that
     * renders, so it is never called while a popup is up. This one has ten callers and
     * none of them is the post, so it runs from the popup's own update.
     *
     * `push ebp; mov ebp, esp; mov eax, fs:[0]` is nine bytes, so the jump takes four
     * NOPs and the stub reproduces all three - the `fs` load included, because half of it
     * would otherwise be left behind as the jump's tail.
     */
    const uintptr_t FILL_SITE = 0x355B0;
    const unsigned char FILL_BYTES[9] = {
        0x55, 0x8B, 0xEC, 0x64, 0xA1, 0x00, 0x00, 0x00, 0x00
    };
    const uintptr_t FILL_RESUME = 0x355B9;

    /**@brief the instruction after CCountry::ShatterUnit's own call, so its posts are
       named rather than left as a bare address*/
    const uintptr_t SHATTER_RETURN = 0x100EDA;

    /**
     * The message's own fields, as CMessage::CMessage writes them. Every `std::string`
     * here is `0x1C` bytes - sixteen of buffer, the length, the capacity, then four the
     * constructor never touches - which is why a message built on an un-zeroed stack
     * shows junk at `+0x1C` and `+0x64` and a zeroed one shows nothing.
     */
    const unsigned MESSAGE_DATE = 0x04;
    const unsigned MESSAGE_TYPE = 0x20;
    const unsigned MESSAGE_VARIABLES = 0x24;
    const unsigned MESSAGE_PLAYER_TAG = 0x34;
    const unsigned MESSAGE_PLAYER_ID = 0x38;
    const unsigned MESSAGE_COUNTRY_A = 0x3C;
    const unsigned MESSAGE_COUNTRY_B = 0x40;
    const unsigned MESSAGE_PROVINCE = 0x44;
    const unsigned MESSAGE_HEAD = 0x4C;

    /**@brief a province's own id, so a pointer claiming to be one can be checked
       against the id it was looked up by*/
    const unsigned PROVINCE_ID = 0xD0;

    /**@brief a variable, and where the type keeps the name the localisation is keyed on*/
    const unsigned NODE_KEY = 0x00;
    const unsigned NODE_VALUE = 0x1C;
    const unsigned NODE_NEXT = 0x3C;
    const unsigned TYPE_NAME = 0x14;

    /**
     * **How many posts to print, and how many variables of each.** A handful is enough for
     * the comparison this exists for, and the point of a limit is that an armed probe left
     * behind cannot fill the log. A country's own list is fourteen before anything is
     * added to it.
     */
    const int MOST_FRAMES = 8;
    const unsigned MOST_VARIABLES = 40;
    int frames = 0;

    DWORD postResume = 0;
    DWORD fillResume = 0;
    uintptr_t base = 0;
    bool installedFlag = false;
    int fills = 0;
    const char* statusText = "not armed";

    /**
    @brief reads one of the game's strings into \p out, whatever shape it is in

    Short strings live in the object and long ones behind a pointer, told apart by the
    capacity the way the game tells them apart. Anything unreadable comes back as a note
    rather than a crash, because this runs on the game's own data with a patch in.
    */
    void readString(uintptr_t at, char* out, unsigned size) {
        out[0] = '\0';
        int length = 0;
        int capacity = 0;
        if (!Mem::tryRead(at + 0x10, length) || !Mem::tryRead(at + 0x14, capacity)
            || length < 0 || length > 0x1000) {
            snprintf(out, size, "<unreadable>");
            return;
        }
        uintptr_t characters = at;
        if (capacity >= 0x10 && !Mem::tryRead(at, characters)) {
            snprintf(out, size, "<length %d, no characters>", length);
            return;
        }
        unsigned wanted = static_cast<unsigned>(length);
        if (wanted > size - 1) {
            wanted = size - 1;
        }
        for (unsigned i = 0; i < wanted; ++i) {
            char c = 0;
            if (!Mem::tryRead(characters + i, c)) {
                out[i] = '\0';
                return;
            }
            out[i] = (c >= 0x20 && c < 0x7F) ? c : '.';
        }
        out[wanted] = '\0';
    }

    /**
    @brief prints the `$KEY$` list the message's text is filled in from

    **This is what a message is, as far as its text goes**: the type names the lines and
    every `$SOMETHING$` in them is looked up here. A line whose variable is missing is the
    difference between a popup and an empty window, so the whole list is worth printing
    rather than the count.
    */
    void printVariables(const unsigned char* message) {
        const unsigned* list =
            reinterpret_cast<const unsigned*>(message + MESSAGE_VARIABLES);
        printf("[INFO]   variables %u\n", list[2]);

        uintptr_t node = list[0];
        for (unsigned i = 0; i < list[2] && i < MOST_VARIABLES && node != 0; ++i) {
            char key[64];
            char value[128];
            readString(node + NODE_KEY, key, sizeof key);
            readString(node + NODE_VALUE, value, sizeof value);
            printf("[INFO]     $%s$ = \"%s\"\n", key, value);
            if (!Mem::tryRead(node + NODE_NEXT, node)) {
                break;
            }
        }
    }

    /**
    @brief prints one post's whole argument frame

    \p frame points at the return address, so the arguments follow it: the handler, the
    province, the message itself and the two above it.

    **Does nothing that could raise a message.** It runs with the patch in, so calling
    back into the game here would re-enter the function this is standing in front of.
    Reading memory is all that happens.
    */
    void __cdecl noteFrame(const unsigned char* frame) {
        if (frames >= MOST_FRAMES || frame == nullptr) {
            return;
        }
        ++frames;

        const unsigned* words = reinterpret_cast<const unsigned*>(frame);
        const unsigned returnTo = words[0];
        const unsigned char* message = frame + 12;
        const unsigned* fields = reinterpret_cast<const unsigned*>(message);
        const unsigned* above =
            reinterpret_cast<const unsigned*>(message + MESSAGE_BYTES);

        // The thread as well as the caller: "the render thread" was a label put on this
        // before anything measured it, and Present and Lua share a thread in this game.
        printf("[INFO] MessageProbe frame %d, posted from %#010x on thread %lu%s\n",
            frames, returnTo, GetCurrentThreadId(),
            (returnTo == static_cast<unsigned>(base + SHATTER_RETURN))
                ? "  (CCountry::ShatterUnit)" : "");
        printf("[INFO]   handler  %#010x   province %#010x   builder %#010x\n",
            words[1], words[2], above[0]);
        printf("[INFO]   player   tag %#010x id %#010x   country %#010x / %#010x\n",
            fields[MESSAGE_PLAYER_TAG / 4], fields[MESSAGE_PLAYER_ID / 4],
            fields[MESSAGE_COUNTRY_A / 4], fields[MESSAGE_COUNTRY_B / 4]);

        char text[128];
        if (fields[MESSAGE_TYPE / 4] != 0) {
            readString(fields[MESSAGE_TYPE / 4] + TYPE_NAME, text, sizeof text);
            // The pointer as well as the name: two raises of one type must reach the
            // same object, or the lookup found something else that reads like a type.
            printf("[INFO]   type     \"%s\" at %#010x\n", text,
                fields[MESSAGE_TYPE / 4]);
        }
        readString(reinterpret_cast<uintptr_t>(message) + MESSAGE_DATE, text, sizeof text);
        printf("[INFO]   date     \"%s\"\n", text);
        readString(reinterpret_cast<uintptr_t>(message) + MESSAGE_HEAD, text, sizeof text);
        // The id it reports and the vftable it carries: a province that does not know
        // its own id is not a province, whatever it was looked up as.
        unsigned provinceId = 0;
        unsigned provinceVftable = 0;
        (void)Mem::tryRead(fields[MESSAGE_PROVINCE / 4] + PROVINCE_ID, provinceId);
        (void)Mem::tryRead(fields[MESSAGE_PROVINCE / 4], provinceVftable);
        printf("[INFO]   head     \"%s\"   province %#010x id %u vftable %#010x\n", text,
            fields[MESSAGE_PROVINCE / 4], provinceId, provinceVftable);

        printVariables(message);
    }


    /**
    @brief prints that a popup's text is being built, and which thread builds it

    **The whole question this answers**: a message raised from the overlay comes out as an
    empty window and the same message raised from CInGameIdler::DailyUpdate comes out
    right, with nothing in the raise path differing between them. Either this runs for the
    empty one - so the text is built and then lost - or it never runs, and the popup was
    created in a state whose update does not happen.
    */
    void __cdecl notePopupText(const unsigned char* popup, unsigned returnTo) {
        if (fills >= MOST_FRAMES || popup == nullptr) {
            return;
        }
        ++fills;
        printf("[INFO] MessageProbe fill %d, popup %#010x, built from %#010x on thread "
            "%lu\n", fills, reinterpret_cast<unsigned>(popup), returnTo,
            GetCurrentThreadId());
    }

    /**
    @brief prints the popup whose text is being built and passes the call on

    The popup is the one stack argument, so at entry it is above the return address and
    `pushad` plus `pushfd` put 36 bytes in front of both.
    */
    __declspec(naked) void fillingPopup() {
        __asm {
            pushad
            pushfd

            mov eax, [esp + 36]         // the return address
            push eax
            mov eax, [esp + 44]         // the popup
            push eax
            call notePopupText
            add esp, 8

            popfd
            popad

            push ebp                    // exactly the three instructions this replaced
            mov ebp, esp
            mov eax, dword ptr fs:[0]
            jmp [fillResume]
        }
    }
    /**
    @brief prints the frame and passes the call on

    The three instructions the jump displaced are done here rather than trampolined, so
    nothing else needs allocating. At entry `esp` still points at the return address, and
    `pushad` plus `pushfd` put 36 bytes in front of it.
    */
    __declspec(naked) void postingMessage() {
        __asm {
            pushad
            pushfd

            lea eax, [esp + 36]         // the return address, and the arguments after it
            push eax
            call noteFrame
            add esp, 4

            popfd
            popad

            push ebp                    // exactly the three instructions this replaced
            mov ebp, esp
            push -1
            jmp [postResume]
        }
    }


    /**@brief puts a patched site's original bytes back, however many it took*/
    void restore(uintptr_t at, const unsigned char* original, size_t length) {
        DWORD protection = 0;
        void* site = reinterpret_cast<void*>(at);
        if (!VirtualProtect(site, length, PAGE_EXECUTE_READWRITE, &protection)) {
            return;
        }
        memcpy(site, original, length);
        DWORD unused = 0;
        VirtualProtect(site, length, protection, &unused);
    }
}

bool Reversing::MessageProbe::arm() {
    if (installedFlag) {
        statusText = "already armed";
        return true;
    }

    base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof SITE_BYTES)) {
        statusText = "PostMessage does not begin where this build expects";
        ERROR_OUT(printf("MessageProbe: %#010x is not the prologue expected\n",
            static_cast<unsigned>(base + SITE)));
        return false;
    }

    if (!Hooks::bytesAre(base + FILL_SITE, FILL_BYTES, sizeof FILL_BYTES)) {
        statusText = "FillMessagePopup does not begin where this build expects";
        ERROR_OUT(printf("MessageProbe: %#010x is not the prologue expected\n",
            static_cast<unsigned>(base + FILL_SITE)));
        return false;
    }

    frames = 0;
    fills = 0;
    postResume = static_cast<DWORD>(base + RESUME);
    fillResume = static_cast<DWORD>(base + FILL_RESUME);
    if (!Hooks::hook(reinterpret_cast<void*>(base + SITE), &postingMessage, 5, 0)
        || !Hooks::hook(reinterpret_cast<void*>(base + FILL_SITE), &fillingPopup, 5, 4)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "armed";
    INFO_OUT(printf("MessageProbe: the next %d messages posted will print their "
        "arguments\n", MOST_FRAMES));
    return true;
}

void Reversing::MessageProbe::disarm() {
    if (!installedFlag) {
        return;
    }
    restore(base + SITE, SITE_BYTES, sizeof SITE_BYTES);
    restore(base + FILL_SITE, FILL_BYTES, sizeof FILL_BYTES);
    installedFlag = false;
    statusText = "not armed";
}

const char* Reversing::MessageProbe::status() {
    return statusText;
}
