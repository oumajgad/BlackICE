#include <Gui/GuiPage.hpp>

#include <Windows.h>
#include <psapi.h>
#include <cfloat>
#include <cstdio>

#include <imgui.h>

namespace {
    struct MemoryStats
    {
        unsigned __int64 privateBytes = 0;      // Commit charge, what usually hits the wall first
        unsigned __int64 workingSet = 0;        // Physical RAM currently held
        unsigned __int64 addressSpaceUsed = 0;  // Committed + reserved
        unsigned __int64 largestFreeBlock = 0;  // Biggest single allocation still possible
        unsigned __int64 addressSpaceLimit = 0;
        bool largeAddressAware = false;
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
        ImVec4 barColor = ImVec4(0.26f, 0.59f, 0.35f, 1.0f);
        if (fraction >= 0.85f) {
            barColor = ImVec4(0.75f, 0.22f, 0.22f, 1.0f);
        }
        else if (fraction >= 0.60f) {
            barColor = ImVec4(0.80f, 0.60f, 0.20f, 1.0f);
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
            "so the largest free block can matter more than the totals.");
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
