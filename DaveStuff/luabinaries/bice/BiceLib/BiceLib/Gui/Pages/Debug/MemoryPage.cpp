#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/TextureStats.hpp>
#include <GameState/CrashSave.hpp>
#include <GameState/OutOfMemory.hpp>
#include <GameState/PureCall.hpp>
#include <Settings.hpp>

#include <Windows.h>
#include <psapi.h>
#include <cfloat>
#include <cstdio>
#include <string>

#include <imgui.h>

namespace {
    /**
     * One kind of address space, split the way the process pays for it.
     *
     * The three kinds answer different questions. Private is the game's own
     * allocations - its heap, its data, everything it built. Mapped is files and
     * shared memory, which for this process is largely what the graphics driver
     * maps in. Image is the DLLs themselves, which is a fixed cost nobody can do
     * anything about. Only the first is worth chasing.
     */
    struct RegionClass
    {
        unsigned __int64 committed = 0;
        unsigned __int64 reserved = 0;
        unsigned int regions = 0;
    };

    struct MemoryStats
    {
        unsigned __int64 privateBytes = 0;      // Commit charge, what usually hits the wall first
        unsigned __int64 workingSet = 0;        // Physical RAM currently held
        unsigned __int64 addressSpaceUsed = 0;  // Committed + reserved
        unsigned __int64 largestFreeBlock = 0;  // Biggest single allocation still possible
        unsigned __int64 addressSpaceLimit = 0;
        bool largeAddressAware = false;

        RegionClass privateRegions;
        RegionClass mappedRegions;
        RegionClass imageRegions;
        unsigned __int64 largestPrivateRegion = 0;
    };

    MemoryStats memoryStats;
    ULONGLONG lastMemorySampleMs = 0;

    /**
    @brief refreshes memoryStats

    Walking the whole address space costs a VirtualQuery per region, so this is
    thottled rather than run every frame.
    */
    void sampleMemory() {
        PROCESS_MEMORY_COUNTERS_EX counters = {};
        counters.cb = sizeof(counters);
        if (GetProcessMemoryInfo(GetCurrentProcess(),
            reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&counters), sizeof(counters))) {
            memoryStats.privateBytes = counters.PrivateUsage;
            memoryStats.workingSet = counters.WorkingSetSize;
        }

        SYSTEM_INFO sysInfo;
        GetSystemInfo(&sysInfo);

        // The kernel reports the real ceiling here, so this stays correct whether or
        // not the exe is patched large address aware (2 GB vs 4 GB).
        const uintptr_t maxAddress = reinterpret_cast<uintptr_t>(sysInfo.lpMaximumApplicationAddress);
        memoryStats.addressSpaceLimit = static_cast<unsigned __int64>(maxAddress) + 1;
        memoryStats.largeAddressAware = memoryStats.addressSpaceLimit > 0x80000000ull;

        unsigned __int64 used = 0;
        unsigned __int64 largestFree = 0;
        MEMORY_BASIC_INFORMATION info;

        memoryStats.privateRegions = RegionClass();
        memoryStats.mappedRegions = RegionClass();
        memoryStats.imageRegions = RegionClass();
        memoryStats.largestPrivateRegion = 0;

        unsigned char* address = nullptr;
        while (reinterpret_cast<uintptr_t>(address) < maxAddress &&
            VirtualQuery(address, &info, sizeof(info)) == sizeof(info)) {
            if (info.State == MEM_FREE) {
                if (info.RegionSize > largestFree) {
                    largestFree = info.RegionSize;
                }
            }
            else {
                used += info.RegionSize; // MEM_COMMIT and MEM_RESERVE both consume address space

                // Type only means anything once a region is spoken for, which is why
                // this sits on the not-free side.
                RegionClass* group = nullptr;
                if (info.Type == MEM_IMAGE) {
                    group = &memoryStats.imageRegions;
                }
                else if (info.Type == MEM_MAPPED) {
                    group = &memoryStats.mappedRegions;
                }
                else if (info.Type == MEM_PRIVATE) {
                    group = &memoryStats.privateRegions;
                }

                if (group != nullptr) {
                    group->regions++;
                    if (info.State == MEM_COMMIT) {
                        group->committed += info.RegionSize;
                    }
                    else {
                        group->reserved += info.RegionSize;
                    }
                }

                if (info.Type == MEM_PRIVATE && info.State == MEM_COMMIT &&
                    info.RegionSize > memoryStats.largestPrivateRegion) {
                    memoryStats.largestPrivateRegion = info.RegionSize;
                }
            }

            unsigned char* next = address + info.RegionSize;
            if (next <= address) {
                break; // Wrapped around the top of the address space
            }
            address = next;
        }

        memoryStats.addressSpaceUsed = used;
        memoryStats.largestFreeBlock = largestFree;
    }

    const char* formatBytes(unsigned __int64 bytes, char* buffer, size_t bufferSize) {
        const double megabytes = static_cast<double>(bytes) / (1024.0 * 1024.0);
        if (megabytes >= 1024.0) {
            sprintf_s(buffer, bufferSize, "%.2f GB", megabytes / 1024.0);
        }
        else {
            sprintf_s(buffer, bufferSize, "%.0f MB", megabytes);
        }
        return buffer;
    }

    void drawUsageBar(const char* label, unsigned __int64 used, unsigned __int64 limit) {
        const float fraction = limit > 0 ? static_cast<float>(static_cast<double>(used) / static_cast<double>(limit)) : 0.0f;

        // Green below 60%, amber past that, red once we're near the 32 bit ceiling.
        ImVec4 barColor = Gui::Theme::mark(Gui::Theme::Mark::SuccessFill);
        if (fraction >= 0.85f) {
            barColor = Gui::Theme::mark(Gui::Theme::Mark::ErrorDim);
        }
        else if (fraction >= 0.60f) {
            barColor = Gui::Theme::mark(Gui::Theme::Mark::Warning);
        }

        char usedText[32];
        char limitText[32];
        char overlayText[80];
        sprintf_s(overlayText, "%s / %s (%.0f%%)",
            formatBytes(used, usedText, sizeof(usedText)),
            formatBytes(limit, limitText, sizeof(limitText)),
            fraction * 100.0f);

        ImGui::Text("%s", label);
        ImGui::PushStyleColor(ImGuiCol_PlotHistogram, barColor);
        ImGui::ProgressBar(fraction, ImVec2(-FLT_MIN, 0.0f), overlayText);
        ImGui::PopStyleColor();
    }

    /**
    @brief splits the address space into what each kind of allocation holds

    The totals alone cannot say whether the game is using the space or the graphics
    driver is, and the answer decides where to look next.
    */
    void drawBreakdown() {
        ImGui::Spacing();
        ImGui::SeparatorText("Where the address space goes");

        if (!ImGui::BeginTable("addressSpace", 4, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            return;
        }
        ImGui::TableSetupColumn("Kind", ImGuiTableColumnFlags_WidthStretch, 1.2f);
        ImGui::TableSetupColumn("Committed", ImGuiTableColumnFlags_WidthStretch, 0.8f);
        ImGui::TableSetupColumn("Reserved", ImGuiTableColumnFlags_WidthStretch, 0.8f);
        ImGui::TableSetupColumn("Regions", ImGuiTableColumnFlags_WidthStretch, 0.6f);
        ImGui::TableHeadersRow();

        struct Line
        {
            const char* label;
            const RegionClass* group;
            const char* tip;
        };
        const Line lines[] = {
            { "Private (the game's own)", &memoryStats.privateRegions,
              "Everything the game allocated for itself: its heap, the parsed\n"
              "mod, the AI, the Lua states. The only one worth attacking." },
            { "Mapped (files, driver)", &memoryStats.mappedRegions,
              "File mappings and shared memory. Under DXVK this is largely the\n"
              "graphics driver's, and it is not the game's to give back." },
            { "Image (DLLs)", &memoryStats.imageRegions,
              "The executable and every DLL loaded into it. Fixed." },
        };

        char scratch[32];
        for (const Line& line : lines) {
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(line.label);
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("%s", line.tip);
            }
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(formatBytes(line.group->committed, scratch, sizeof(scratch)));
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(formatBytes(line.group->reserved, scratch, sizeof(scratch)));
            ImGui::TableNextColumn();
            ImGui::Text("%u", line.group->regions);
        }
        ImGui::EndTable();

        ImGui::Text("Largest single private block: %s",
            formatBytes(memoryStats.largestPrivateRegion, scratch, sizeof(scratch)));
    }

    /**
    @brief what the game's Lua interpreters hold

    The game opens a state per AI context and never closes one, and every state runs
    autoexec.lua, which pulls in the country AI modules, the data provider and the
    utility. This is what that repetition costs.
    */
    void drawLua() {
        const Gui::Lua::StateMemory lua = Gui::Lua::stateMemory();

        ImGui::Spacing();
        ImGui::SeparatorText("Lua");

        if (lua.states == 0) {
            ImGui::TextDisabled("No Lua state has loaded BiceLib yet.");
            return;
        }

        char scratch[32];
        ImGui::Text("States: %d", lua.states);
        if (lua.distinct != lua.states) {
            ImGui::SameLine();
            ImGui::TextDisabled("(%d independent, the rest are coroutines)", lua.distinct);
        }

        ImGui::Text("Total:   %s", formatBytes(lua.bytes, scratch, sizeof(scratch)));
        ImGui::Text("Largest: %s", formatBytes(lua.largest, scratch, sizeof(scratch)));
        if (lua.distinct > 0) {
            ImGui::Text("Average: %s",
                formatBytes(lua.bytes / lua.distinct, scratch, sizeof(scratch)));
        }

        ImGui::Spacing();
        ImGui::TextWrapped("Lua's own accounting, so it covers what the interpreter "
            "allocated and not what BiceLib or the game allocated around it. The game "
            "never closes a state, so this only ever grows.");
    }

    /**
    @brief every texture the game has created since the hook went in, by format

    Whether a compressed .dds stays compressed once loaded cannot be read off the
    game's disassembly - the format argument comes out of a register - so it is read
    off the textures themselves instead. DXT rows here mean the files keep their
    format; A8R8G8B8 rows covering the same art would mean the loader expands it and
    compressing the files buys nothing.
    */
    void drawTextures() {
        const Gui::TextureStats::Summary summary = Gui::TextureStats::summary();

        ImGui::Spacing();
        ImGui::SeparatorText("Textures created");

        if (!summary.hooked) {
            ImGui::TextDisabled("CreateTexture is not hooked, so nothing is counted.");
            return;
        }
        if (summary.count == 0) {
            ImGui::TextDisabled("Nothing created yet.");
            return;
        }

        char scratch[32];
        char scratch2[32];
        ImGui::Text("Alive: %u textures, %s", summary.liveCount,
            formatBytes(summary.liveBytes, scratch, sizeof(scratch)));
        ImGui::SameLine();
        if (ImGui::SmallButton("Reset")) {
            Gui::TextureStats::reset();
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Clears the created totals. What is alive stays,\n"
                "because it has not gone anywhere.");
        }

        ImGui::Text("Created: %u textures, %s  (%s released since)",
            summary.count, formatBytes(summary.bytes, scratch, sizeof(scratch)),
            formatBytes(summary.bytes > summary.liveBytes
                ? summary.bytes - summary.liveBytes : 0, scratch2, sizeof(scratch2)));

        if (!summary.releaseHooked) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Release is not hooked, so nothing ever leaves the live totals.");
        }

        ImGui::Spacing();
        ImGui::Text("Compressed:   %s", formatBytes(summary.liveCompressedBytes, scratch, sizeof(scratch)));
        ImGui::SameLine();
        ImGui::TextDisabled("(DXT, as stored)");
        ImGui::Text("Uncompressed: %s", formatBytes(summary.liveUncompressedBytes, scratch, sizeof(scratch)));
        ImGui::Text("Managed pool: %s", formatBytes(summary.liveManagedBytes, scratch, sizeof(scratch)));
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("D3DPOOL_MANAGED keeps a system memory copy as well as\n"
                "the one the driver holds, so these bytes are spent twice -\n"
                "and the system copy is the half that competes for the\n"
                "32 bit address space.");
        }

        ImGui::Spacing();
        if (ImGui::BeginTable("textureFormats", 6, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("Format", ImGuiTableColumnFlags_WidthStretch, 1.1f);
            ImGui::TableSetupColumn("Alive", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupColumn("Size", ImGuiTableColumnFlags_WidthStretch, 0.8f);
            ImGui::TableSetupColumn("Managed", ImGuiTableColumnFlags_WidthStretch, 0.8f);
            ImGui::TableSetupColumn("Created", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableHeadersRow();

            Gui::TextureStats::Row rows[32];
            const int count = Gui::TextureStats::snapshot(rows, 32);
            for (int i = 0; i < count; i++) {
                const Gui::TextureStats::Row& row = rows[i];
                ImGui::TableNextRow();

                ImGui::TableNextColumn();
                ImGui::TextUnformatted(row.name);
                ImGui::TableNextColumn();
                ImGui::Text("%u", row.liveCount);
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(formatBytes(row.liveBytes, scratch, sizeof(scratch)));
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(formatBytes(row.liveManagedBytes, scratch, sizeof(scratch)));
                ImGui::TableNextColumn();
                if (row.count != row.liveCount) {
                    ImGui::Text("%u", row.count);
                }
                else {
                    ImGui::TextDisabled("%u", row.count);
                }
                ImGui::TableNextColumn();
                if (row.compressed) {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success), "compressed");
                }
                else if (row.liveBytes == 0 && row.bytes == 0) {
                    ImGui::TextDisabled("unsized");
                }
                else {
                    ImGui::TextDisabled("-");
                }
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::TextWrapped("Alive means the last reference has not gone yet. Anything "
            "created before the overlay's hooks went in is missing from both columns, "
            "and the overlay's own textures are in them. Sizes are worked out from the "
            "format and the mip chain, so they are what the pixels cost rather than "
            "what the driver rounded them up to.");
    }

    /**
    @brief what the new handler has caught, and the button that provokes it

    Instrumentation rather than a feature: it says whether the game's own allocator is
    where out of memory actually arrives, which is the one thing a crash-save on out of
    memory would rest on. Nothing here writes a save.
    */
    /**
    @brief the crash save: what it will do, and the button that does it now

    The part of this page that is a feature rather than an experiment. Everything
    below it exists to find out whether the game's allocator can be caught; this
    does not wait to find out - it watches the free address space and acts while
    there is still some.
    */
    void drawCrashSave() {
        ImGui::SeparatorText("Crash save");

        char scratch[32];
        char other[32];
        const unsigned __int64 free = OutOfMemory::freeNow();
        const unsigned __int64 largest = OutOfMemory::largestBlock();
        const unsigned __int64 trigger = OutOfMemory::triggerAt();

        // The largest block first, because it is the one that decides: two deaths were
        // measured with tens of MB free and nothing big enough to put anything in.
        ImGui::Text("Largest block it can still get: %s",
            formatBytes(largest, scratch, sizeof(scratch)));
        if (largest != 0 && largest <= trigger * 2) {
            ImGui::SameLine();
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.3f, 1.0f), "- getting close");
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Measured by asking for one and giving it straight back,\n"
                "twice a second. This is what the trigger watches.\n"
                "\n"
                "The total below is not: a process with 30 MB free in\n"
                "small pieces and nothing bigger than 244 KB is already\n"
                "finished, and that is exactly how two runs died.");
        }
        ImGui::TextDisabled("Free in total: %s", formatBytes(free, other, sizeof(other)));

        bool watching = OutOfMemory::watching();
        if (ImGui::Checkbox("Save and close the game when it runs out", &watching)) {
            OutOfMemory::setWatching(watching);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Below the threshold the game is saved as \"crashsave\",\n"
                "told why in a message box, and closed.\n"
                "\n"
                "Closing somebody's game is a large thing to do, so it is\n"
                "this one checkbox. Off, the game is left to die however\n"
                "it would have.");
        }

        int triggerMb = static_cast<int>(trigger / (1024 * 1024));
        ImGui::SetNextItemWidth(120.0f);
        if (ImGui::InputInt("Fire below this block size, MB", &triggerMb, 1, 5)) {
            if (triggerMb < 1) {
                triggerMb = 1;
            }
            if (triggerMb > 512) {
                triggerMb = 512;
            }
            OutOfMemory::setTriggerAt(
                static_cast<unsigned __int64>(triggerMb) * 1024u * 1024u);
        }

        ImGui::Spacing();
        if (ImGui::Button("Save and close now")) {
            OutOfMemory::trigger();
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("The same path the threshold takes, so this tests the\n"
                "real thing - including the message box and closing the\n"
                "game. Hold the ballast below first to try it under the\n"
                "pressure it is meant for.");
        }

        ImGui::Spacing();
        ImGui::Text("Pure virtual call handler: %s", PureCall::status());
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("The other way the game dies where nothing can be done\n"
                "about it: a virtual call through a slot with no\n"
                "implementation, which the CRT answers by aborting.\n"
                "\n"
                "Installed into the game's own handler slot, which was\n"
                "empty. Nothing is patched. It saves on the spot, because\n"
                "there is no next frame to wait for.");
        }
        if (PureCall::installed()) {
            ImGui::SameLine();
            if (ImGui::SmallButton("Provoke one")) {
                PureCall::provoke();
            }
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Calls the game's own _purecall, which is the exact\n"
                "address sitting in 510 of its vftable slots - so this is\n"
                "the same call a real pure virtual would make, not an\n"
                "imitation of one.\n"
                "\n"
                "It saves and closes the game. Save first.");
        }

        if (CrashSave::stage() != CrashSave::Stage::Idle) {
            ImGui::Text("Last attempt: the game %s - %s (%s free before, %s after)",
                CrashSave::reason(), CrashSave::stageText(),
                formatBytes(CrashSave::roomBefore(), scratch, sizeof(scratch)),
                formatBytes(CrashSave::roomAfter(), other, sizeof(other)));
        }
    }

    /**@brief the crash save, and the ballast that is how it gets tested*/
    void drawOutOfMemory() {
        drawCrashSave();

        char scratch[32];

        // Held across frames rather than given straight back, so the game meets the
        // wall while doing its own work. This is how the crash save above is tested
        // without playing a whole session to get there.
        ImGui::Spacing();
        ImGui::SeparatorText("Ballast - play the game to death");

        static int leaveFreeMb =
            static_cast<int>(OutOfMemory::DEFAULT_LEAVE_FREE / (1024 * 1024));
        const unsigned __int64 held = OutOfMemory::ballastHeld();

        if (held == 0) {
            ImGui::SetNextItemWidth(120.0f);
            ImGui::InputInt("MB to leave the game", &leaveFreeMb, 10, 50);
            if (leaveFreeMb < 8) {
                leaveFreeMb = 8;
            }
            if (leaveFreeMb > 1024) {
                leaveFreeMb = 1024;
            }
            if (ImGui::Button("Hold everything else")) {
                OutOfMemory::hold(
                    static_cast<unsigned __int64>(leaveFreeMb) * 1024u * 1024u);
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Takes the address space and keeps it, so the game runs\n"
                    "with almost none and the crash save above fires at\n"
                    "whatever it tries next.\n"
                    "\n"
                    "Nothing gives it back except the release button, so\n"
                    "what it holds is what the game has to do without.\n"
                    "Save first.");
            }
        }
        else {
            ImGui::Text("Holding %s in %d reservations",
                formatBytes(held, scratch, sizeof(scratch)),
                OutOfMemory::ballastReservations());
            if (ImGui::Button("Release the ballast")) {
                OutOfMemory::releaseBallast();
            }
        }

        ImGui::Spacing();
        ImGui::TextWrapped("Every crash save is appended to OutOfMemory.log beside the "
            "DLL, with how much room there was before and after it - because a save "
            "taken as the game dies has to leave a record of whether it worked.");
    }

    void drawMemoryMeter() {
        const ULONGLONG now = GetTickCount64();
        if (now - lastMemorySampleMs >= 500 || lastMemorySampleMs == 0) {
            sampleMemory();
            lastMemorySampleMs = now;
        }

        ImGui::SeparatorText("Memory (32 bit process)");

        drawUsageBar("Private bytes (commit)", memoryStats.privateBytes, memoryStats.addressSpaceLimit);
        ImGui::Spacing();
        drawUsageBar("Address space (committed + reserved)", memoryStats.addressSpaceUsed, memoryStats.addressSpaceLimit);

        ImGui::Spacing();

        char scratch[32];
        ImGui::Text("Working set:       %s", formatBytes(memoryStats.workingSet, scratch, sizeof(scratch)));
        ImGui::Text("Largest free block: %s", formatBytes(memoryStats.largestFreeBlock, scratch, sizeof(scratch)));
        ImGui::Text("Limit:             %s (%s)",
            formatBytes(memoryStats.addressSpaceLimit, scratch, sizeof(scratch)),
            memoryStats.largeAddressAware ? "large address aware" : "not large address aware");

        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("A 32 bit process gets 2 GB of user address space,\n"
                "or 4 GB on 64 bit Windows when the exe is flagged\n"
                "large address aware.");
        }

        ImGui::Spacing();
        ImGui::TextWrapped("Out of memory happens when no single free block is large enough, "
            "so the largest free block can matter more than the totals - though what "
            "matters is whether it still clears the largest single allocation the game "
            "makes, not how far it has fallen.");
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("A shrinking free block cannot be recovered while the game\n"
                "runs: an allocation cannot be moved, because everything\n"
                "pointing at it holds its address. Compacting the heaps was\n"
                "tried and changed nothing - see the largest private region\n"
                "below for what actually has to fit.");
        }

        drawBreakdown();
        drawLua();
        drawTextures();
        drawOutOfMemory();
    }
}

namespace {
    class MemoryPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Memory"; }
        const char* group() const override { return "Debug"; }
        int order() const override { return 20; }
        void draw() override { drawMemoryMeter(); }
    };
}

REGISTER_GUI_PAGE(MemoryPage);
