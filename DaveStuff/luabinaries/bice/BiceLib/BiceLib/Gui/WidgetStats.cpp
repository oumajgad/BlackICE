#include <Gui/WidgetStats.hpp>

#include <GameClasses/CInGameIdler.hpp>
#include <Hooks/Hooks.hpp>
#include <utils.hpp>

#include <Windows.h>

#include <set>
#include <string>

namespace {
    // Module relative. CEU3Gui's first vftable; the object also carries CPersistent's at +4 and
    // CFactory's at +0xC, which is what the pair check below uses to avoid matching a stray dword
    // that happens to equal the first one.
    const uintptr_t GUI_VFTABLE = 0x11CD754;
    const uintptr_t GUI_VFTABLE_PERSISTENT = 0x11CD7D8;

    // CGui's own fields: the widget vector's three pointers.
    const uintptr_t WIDGETS_BEGIN = 0x5C;
    const uintptr_t WIDGETS_END = 0x60;
    const uintptr_t WIDGETS_CAPACITY = 0x64;

    // CGuiObject +0x24 is the widget's CGuiType*, and that type's +8 is its name.
    const uintptr_t OBJECT_TYPE = 0x24;
    const uintptr_t TYPE_NAME = 0x8;

    uintptr_t cachedGui = 0;

    bool readable(uintptr_t address, size_t length) {
        MEMORY_BASIC_INFORMATION info = {};
        if (::VirtualQuery(reinterpret_cast<void*>(address), &info, sizeof(info)) == 0) {
            return false;
        }
        if (info.State != MEM_COMMIT) {
            return false;
        }
        if ((info.Protect & (PAGE_NOACCESS | PAGE_GUARD)) != 0) {
            return false;
        }
        const uintptr_t end = reinterpret_cast<uintptr_t>(info.BaseAddress) + info.RegionSize;
        return address + length <= end;
    }

    uint32_t dword(uintptr_t address) {
        return readable(address, 4) ? *reinterpret_cast<uint32_t*>(address) : 0;
    }

    /**
    @brief whether this address looks like the one live CEU3Gui

    Two vftables rather than one, because a single dword comparison over the whole heap finds
    the constant wherever it happens to sit - the same mistake that once made a pair of
    *constants* in a DLL look like a live table. A CEU3Gui carries CPersistent's vftable at +4,
    and the widget vector's three pointers have to be ordered, which together is specific
    enough.
    */
    bool looksLikeGui(uintptr_t candidate) {
        if (dword(candidate) != Hooks::MODULE_BASE + GUI_VFTABLE) {
            return false;
        }
        if (dword(candidate + 4) != Hooks::MODULE_BASE + GUI_VFTABLE_PERSISTENT) {
            return false;
        }
        const uint32_t begin = dword(candidate + WIDGETS_BEGIN);
        const uint32_t end = dword(candidate + WIDGETS_END);
        const uint32_t capacity = dword(candidate + WIDGETS_CAPACITY);
        return begin != 0 && end >= begin && capacity >= end;
    }

    /**
    @brief find the gui object, cheaply when it is already known

    The validated cache is the point: resolving walks committed private memory, which is not
    something to do on a frame, but checking a known pointer is one read. The game constructs
    exactly one CEU3Gui and keeps it, so after the first success this never scans again.
    */
    // CInGameIdler +0x1790 is the CEU3Application, and the application holds the gui at +0x120.
    // Verified live on 2026-10-02 by walking it and comparing against the process's only CEU3Gui:
    // state +0xBE8 -> CInGameIdler -> +0x1790 -> CEU3Application -> +0x120 -> CEU3Gui, and the
    // RTTI names every step. Three reads, so it is the cheap path and the scan below is only the
    // fallback - needed because at the main menu +0xBE8 holds a CFrontEnd instead of the idler.
    const uintptr_t IDLER_APPLICATION = 0x1790;
    const uintptr_t APPLICATION_GUI = 0x120;

    uintptr_t guiFromApplication() {
        const uintptr_t idler = CInGameIdler::current();
        if (idler == 0) {
            return 0;
        }
        const uint32_t application = dword(idler + IDLER_APPLICATION);
        if (application == 0) {
            return 0;
        }
        const uint32_t gui = dword(application + APPLICATION_GUI);
        return looksLikeGui(gui) ? gui : 0;
    }

    uintptr_t resolveGui() {
        if (cachedGui != 0 && looksLikeGui(cachedGui)) {
            return cachedGui;
        }
        cachedGui = 0;
        if (Hooks::MODULE_BASE == 0) {
            return 0;
        }

        // The cheap route first; it works whenever there is a session.
        const uintptr_t viaApplication = guiFromApplication();
        if (viaApplication != 0) {
            cachedGui = viaApplication;
            return cachedGui;
        }

        MEMORY_BASIC_INFORMATION info = {};
        uintptr_t address = 0x10000;
        const uintptr_t limit = 0x7FFF0000;
        while (address < limit && ::VirtualQuery(reinterpret_cast<void*>(address), &info,
            sizeof(info)) == sizeof(info)) {
            const uintptr_t regionBase = reinterpret_cast<uintptr_t>(info.BaseAddress);
            const size_t regionSize = info.RegionSize;

            const bool worthScanning = info.State == MEM_COMMIT
                && info.Type == MEM_PRIVATE
                && (info.Protect & (PAGE_NOACCESS | PAGE_GUARD)) == 0
                && (info.Protect == PAGE_READWRITE || info.Protect == PAGE_READONLY
                    || info.Protect == PAGE_EXECUTE_READWRITE);

            if (worthScanning && regionSize >= 0x100) {
                const uint32_t want = static_cast<uint32_t>(Hooks::MODULE_BASE + GUI_VFTABLE);
                const uint32_t* start = reinterpret_cast<const uint32_t*>(regionBase);
                const size_t words = (regionSize - 0x68) / 4;
                for (size_t i = 0; i < words; i++) {
                    if (start[i] != want) {
                        continue;
                    }
                    const uintptr_t candidate = regionBase + i * 4;
                    if (looksLikeGui(candidate)) {
                        cachedGui = candidate;
                        INFO_OUT(printf("WidgetStats: CEU3Gui found at %#010x\n",
                            static_cast<unsigned>(candidate)));
                        return cachedGui;
                    }
                }
            }

            const uintptr_t next = regionBase + regionSize;
            if (next <= address) {
                break;
            }
            address = next;
        }
        return 0;
    }

    // The history ring. Sized for a long session at one sample every two seconds: 1800 samples
    // is an hour of wall clock, which is the scale the question is about.
    const int HISTORY = 1800;
    uint32_t history[HISTORY] = { 0 };
    int historyUsed = 0;
    int historyHead = 0;
    uint32_t peakSeen = 0;
    uint32_t baselineSeen = 0;
    bool haveBaseline = false;
    uintptr_t baselineBegin = 0;
    bool bufferMoved = false;
}

Gui::WidgetStats::Sample Gui::WidgetStats::sample() {
    Sample out;
    const uintptr_t gui = resolveGui();
    if (gui == 0) {
        return out;
    }
    const uint32_t begin = dword(gui + WIDGETS_BEGIN);
    const uint32_t end = dword(gui + WIDGETS_END);
    const uint32_t capacity = dword(gui + WIDGETS_CAPACITY);
    if (begin == 0 || end < begin || capacity < end) {
        return out;
    }
    out.valid = true;
    out.begin = begin;
    out.inUse = (end - begin) / 4;
    out.capacity = (capacity - begin) / 4;
    return out;
}

void Gui::WidgetStats::note(const Sample& taken) {
    if (!taken.valid) {
        return;
    }
    if (!haveBaseline) {
        haveBaseline = true;
        baselineSeen = taken.inUse;
        baselineBegin = taken.begin;
        peakSeen = taken.inUse;
    }
    if (taken.inUse > peakSeen) {
        peakSeen = taken.inUse;
    }
    if (taken.begin != baselineBegin) {
        bufferMoved = true;
    }
    history[historyHead] = taken.inUse;
    historyHead = (historyHead + 1) % HISTORY;
    if (historyUsed < HISTORY) {
        historyUsed++;
    }
}

uint32_t Gui::WidgetStats::peak() { return peakSeen; }
uint32_t Gui::WidgetStats::baseline() { return baselineSeen; }
bool Gui::WidgetStats::reallocated() { return bufferMoved; }
int Gui::WidgetStats::historyCount() { return historyUsed; }
int Gui::WidgetStats::historyCapacity() { return HISTORY; }

uint32_t Gui::WidgetStats::historyAt(int index) {
    if (index < 0 || index >= historyUsed) {
        return 0;
    }
    const int oldest = (historyUsed == HISTORY) ? historyHead : 0;
    return history[(oldest + index) % HISTORY];
}

void Gui::WidgetStats::resetBaseline() {
    historyUsed = 0;
    historyHead = 0;
    haveBaseline = false;
    peakSeen = 0;
    baselineSeen = 0;
    baselineBegin = 0;
    bufferMoved = false;
}

Gui::WidgetStats::DeepScan Gui::WidgetStats::deepScan() {
    DeepScan out;
    const Sample taken = sample();
    if (!taken.valid) {
        return out;
    }

    std::set<std::string> names;
    const uintptr_t begin = taken.begin;
    for (uint32_t i = 0; i < taken.inUse; i++) {
        const uint32_t object = dword(begin + i * 4);
        if (object == 0) {
            out.nulls++;
            continue;
        }
        const uint32_t type = dword(object + OBJECT_TYPE);
        if (type == 0) {
            continue;
        }
        const uint32_t text = dword(type + TYPE_NAME);
        if (text == 0 || !readable(text, 1)) {
            continue;
        }
        // The name is a plain C string inside a Hoi3CString; cap it rather than trust it.
        char buffer[64] = { 0 };
        for (int c = 0; c < 63; c++) {
            if (!readable(text + c, 1)) {
                break;
            }
            const char ch = *reinterpret_cast<const char*>(text + c);
            if (ch == '\0') {
                break;
            }
            buffer[c] = ch;
        }
        if (buffer[0] == '\0') {
            continue;
        }
        out.walked++;
        const std::string name(buffer);
        names.insert(name);
        if (name == "outliner_header") {
            out.outlinerHeader++;
        }
        else if (name == "outliner_header_entry") {
            out.outlinerHeaderEntry++;
        }
        else if (name == "entry_text") {
            out.entryText++;
        }
    }
    out.distinctNames = static_cast<uint32_t>(names.size());
    out.valid = true;
    return out;
}
