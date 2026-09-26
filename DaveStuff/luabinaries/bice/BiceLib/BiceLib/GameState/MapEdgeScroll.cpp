#include <GameState/MapEdgeScroll.hpp>

#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <Settings.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    /**@brief the first of the four edge tests: `mov edx,[edi]; mov edx,[edx+0x4C]`*/
    const uintptr_t SITE = 0x23CE97;
    const unsigned char ORIGINAL[5] = { 0x8B, 0x17, 0x8B, 0x52, 0x4C };

    /**@brief the first instruction after all four, where the camera is clamped*/
    const uintptr_t RESUME = 0x23CFB5;

    const char* const SETTING = "map.edgeScroll";

    bool enabledFlag = true;
    bool availableFlag = false;
    bool loaded = false;
    const char* statusText = "not checked yet";
    uintptr_t base = 0;

    /**@brief the five bytes that skip the four tests: `jmp RESUME`*/
    void skipBytes(unsigned char* out) {
        const long relative = static_cast<long>(RESUME) - static_cast<long>(SITE) - 5;
        out[0] = 0xE9;
        memcpy(out + 1, &relative, 4);
    }

    /**@brief true where the site still holds what this build was written against*/
    bool check() {
        if (availableFlag) {
            return true;
        }
        base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0) {
            statusText = "hoi3_tfh.exe is not loaded";
            return false;
        }

        // Either shape is the site: the original, or this having already patched it.
        unsigned char skip[5];
        skipBytes(skip);
        if (!Hooks::bytesAre(base + SITE, ORIGINAL, 5)
            && !Hooks::bytesAre(base + SITE, skip, 5)) {
            statusText = "the camera does not test the screen edge where this build expects";
            ERROR_OUT(printf("MapEdgeScroll: %#010x is not the instructions expected\n",
                static_cast<unsigned>(base + SITE)));
            return false;
        }
        availableFlag = true;
        return true;
    }

    bool write(const unsigned char* bytes) {
        void* at = reinterpret_cast<void*>(base + SITE);
        DWORD protection = 0;
        if (!VirtualProtect(at, 5, PAGE_EXECUTE_READWRITE, &protection)) {
            statusText = "could not make the code writable";
            return false;
        }
        memcpy(at, bytes, 5);
        DWORD unused = 0;
        VirtualProtect(at, 5, protection, &unused);
        return true;
    }

    void load() {
        if (loaded) {
            return;
        }
        loaded = true;
        enabledFlag = Settings::getInt(SETTING, 1) != 0;
    }
}

bool MapEdgeScroll::enabled() {
    load();
    return enabledFlag;
}

bool MapEdgeScroll::available() {
    return availableFlag;
}

const char* MapEdgeScroll::status() {
    return statusText;
}

bool MapEdgeScroll::setEnabled(bool on) {
    load();
    if (!check()) {
        return false;
    }

    unsigned char bytes[5];
    if (on) {
        memcpy(bytes, ORIGINAL, 5);
    }
    else {
        skipBytes(bytes);
    }
    if (!write(bytes)) {
        return false;
    }

    enabledFlag = on;
    Settings::setInt(SETTING, on ? 1 : 0);
    statusText = on ? "the map scrolls at the screen edge"
        : "the map does not scroll at the screen edge";
    INFO_OUT(printf("MapEdgeScroll: %s\n", statusText));
    return true;
}

void MapEdgeScroll::restore() {
    load();
    // Only the off state needs writing: on is what the game already does, and checking
    // the site when nothing is being changed would report a failure nobody asked about.
    if (enabledFlag) {
        statusText = "the map scrolls at the screen edge";
        return;
    }
    setEnabled(false);
}
