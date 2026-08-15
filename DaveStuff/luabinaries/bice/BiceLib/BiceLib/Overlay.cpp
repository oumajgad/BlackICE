#include <Overlay.hpp>

#include <Windows.h>
#include <d3d9.h>
#include <psapi.h>

#include <cfloat>
#include <cstdio>
#include <vector>

#include <imgui.h>
#include <backends/imgui_impl_dx9.h>
#include <backends/imgui_impl_win32.h>

#include <Inspector.hpp>
#include <utils.hpp>

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

namespace {
    // Indices into the IDirect3DDevice9 vtable. The first three slots belong to
    // IUnknown, so Reset/Present land at 16 and 17 respectively.
    constexpr int VTABLE_RESET = 16;
    constexpr int VTABLE_PRESENT = 17;

    typedef HRESULT(APIENTRY* PresentFn)(IDirect3DDevice9*, const RECT*, const RECT*, HWND, const RGNDATA*);
    typedef HRESULT(APIENTRY* ResetFn)(IDirect3DDevice9*, D3DPRESENT_PARAMETERS*);

    PresentFn originalPresent = nullptr;
    ResetFn originalReset = nullptr;
    WNDPROC originalWndProc = nullptr;

    HWND gameWindow = nullptr;
    bool installed = false;
    bool imguiReady = false;
    bool visible = true;

    bool isMouseMessage(UINT msg) noexcept {
        return (msg >= WM_MOUSEFIRST && msg <= WM_MOUSELAST) || msg == WM_MOUSEHOVER || msg == WM_MOUSELEAVE;
    }

    bool isKeyboardMessage(UINT msg) noexcept {
        return (msg >= WM_KEYFIRST && msg <= WM_KEYLAST);
    }

    LRESULT CALLBACK hookedWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        if (msg == WM_KEYDOWN && wParam == VK_INSERT) {
            visible = !visible;
            return 0;
        }

        if (imguiReady) {
            ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam);

            if (visible) {
                ImGuiIO& io = ImGui::GetIO();
                if ((io.WantCaptureMouse && isMouseMessage(msg)) ||
                    (io.WantCaptureKeyboard && isKeyboardMessage(msg))) {
                    return 1; // Don't let the game react to input meant for the overlay
                }
            }
        }

        return CallWindowProcW(originalWndProc, hWnd, msg, wParam, lParam);
    }

    /**@brief one time ImGui setup, done on the first frame so we know the real device*/
    void initImGui(IDirect3DDevice9* device) {
        D3DDEVICE_CREATION_PARAMETERS params;
        if (FAILED(device->GetCreationParameters(&params)) || params.hFocusWindow == nullptr) {
            return;
        }
        gameWindow = params.hFocusWindow;

        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO();
        io.IniFilename = nullptr; // Don't drop an imgui.ini into the game directory

        if (!ImGui_ImplWin32_Init(gameWindow) || !ImGui_ImplDX9_Init(device)) {
            ERROR_OUT(printf("Overlay: ImGui backend init failed\n"));
            return;
        }

        originalWndProc = reinterpret_cast<WNDPROC>(
            SetWindowLongPtrW(gameWindow, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(hookedWndProc)));

        imguiReady = true;
        INFO_OUT(printf("Overlay: ImGui ready - press INSERT to toggle\n"));
    }

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

    /////////////////////////////////////
    //          INSPECTOR BOX          //
    /////////////////////////////////////

    std::vector<Inspector::Entity> selection;
    ULONGLONG lastSelectionSampleMs = 0;
    bool showInspector = true;

    void drawStatTable(const char* id, const std::vector<Inspector::Stat>& stats) {
        if (stats.empty()) {
            return;
        }
        if (!ImGui::BeginTable(id, 2, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_SizingStretchProp)) {
            return;
        }
        ImGui::TableSetupColumn("Stat", ImGuiTableColumnFlags_WidthStretch, 0.62f);
        ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthStretch, 0.38f);

        for (const Inspector::Stat& stat : stats) {
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(stat.name);
            ImGui::TableNextColumn();
            ImGui::Text("%.2f%s", stat.rawValue * stat.factor, stat.unit);
        }
        ImGui::EndTable();
    }

    void drawTerrainTable(const char* id, const std::vector<Inspector::TerrainStat>& terrain) {
        if (terrain.empty()) {
            return;
        }
        if (!ImGui::BeginTable(id, 5, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            return;
        }
        ImGui::TableSetupColumn("Terrain");
        ImGui::TableSetupColumn("Att");
        ImGui::TableSetupColumn("Def");
        ImGui::TableSetupColumn("Move");
        ImGui::TableSetupColumn("Attr");
        ImGui::TableHeadersRow();

        for (const Inspector::TerrainStat& stat : terrain) {
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(stat.name != nullptr ? stat.name : "?");
            ImGui::TableNextColumn();
            ImGui::Text("%.1f%%", stat.attack * 0.1f);
            ImGui::TableNextColumn();
            ImGui::Text("%.1f%%", stat.defence * 0.1f);
            ImGui::TableNextColumn();
            ImGui::Text("%.1f%%", stat.movement * 0.1f);
            ImGui::TableNextColumn();
            ImGui::Text("%.2f%%", stat.attrition * 0.001f);
        }
        ImGui::EndTable();
    }

    void drawInspectorWindow() {
        if (!showInspector) {
            return;
        }

        // Reading the selection allocates, so don't do it every frame.
        const ULONGLONG now = GetTickCount64();
        if (now - lastSelectionSampleMs >= 250 || lastSelectionSampleMs == 0) {
            selection = Inspector::getSelection();
            lastSelectionSampleMs = now;
        }

        ImGui::SetNextWindowSize(ImVec2(460, 520), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(480, 40), ImGuiCond_FirstUseEver);

        if (ImGui::Begin("Inspector", &showInspector)) {
            const uintptr_t idler = Inspector::idlerAddress();

            if (ImGui::Button("Re-cache idler")) {
                Inspector::recacheIdler();
                lastSelectionSampleMs = 0; // Refresh the selection straight away
            }
            ImGui::SameLine();
            if (idler != 0) {
                ImGui::Text("CIngameIdler: %#010x", static_cast<unsigned>(idler));
            }
            else {
                ImGui::TextDisabled("CIngameIdler: not found");
            }

            if (idler == 0) {
                ImGui::Spacing();
                ImGui::TextWrapped("The idler only exists once a session is running. "
                    "Load or start a game, then press Re-cache idler.");
                ImGui::End();
                return;
            }

            ImGui::Separator();

            if (selection.empty()) {
                ImGui::TextDisabled("Nothing selected.");
            }
            else {
                ImGui::Text("%d selected", static_cast<int>(selection.size()));
                ImGui::Separator();
            }

            for (size_t i = 0; i < selection.size(); i++) {
                const Inspector::Entity& entity = selection[i];

                ImGui::PushID(static_cast<int>(i));

                char header[160];
                sprintf_s(header, "[%s] %s", entity.type,
                    entity.name.empty() ? "(unnamed)" : entity.name.c_str());

                if (ImGui::CollapsingHeader(header, i == 0 ? ImGuiTreeNodeFlags_DefaultOpen : 0)) {
                    ImGui::TextDisabled("address %#010x", static_cast<unsigned>(entity.address));

                    if (entity.stats.empty() && entity.terrain.empty()) {
                        ImGui::TextDisabled("No details for this entity type.");
                    }

                    drawStatTable("stats", entity.stats);

                    if (!entity.terrain.empty()) {
                        ImGui::Spacing();
                        if (ImGui::TreeNode("Terrain modifiers")) {
                            drawTerrainTable("terrain", entity.terrain);
                            ImGui::TreePop();
                        }
                    }
                }

                ImGui::PopID();
            }
        }
        ImGui::End();
    }

    void drawHelloWorld() {
        ImGui::SetNextWindowSize(ImVec2(420, 0), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(40, 40), ImGuiCond_FirstUseEver);

        if (ImGui::Begin("BiceLib")) {
            ImGui::Text("Hello world from inside hoi3_tfh.exe!");
            ImGui::Separator();
            ImGui::Text("ImGui %s", IMGUI_VERSION);
            ImGui::Text("%.1f FPS (%.3f ms/frame)", ImGui::GetIO().Framerate, 1000.0f / ImGui::GetIO().Framerate);
            ImGui::Spacing();
            ImGui::TextWrapped("INSERT toggles this overlay.");
            ImGui::Checkbox("Show inspector", &showInspector);

            drawMemoryMeter();
        }
        ImGui::End();
    }

    /**
    @brief draws one ImGui frame onto the back buffer

    The game builds parts of its UI (button caches, the country flag atlas) in
    offscreen render targets, each wrapped in its own BeginScene/EndScene pair.
    Drawing from an EndScene hook therefore bakes the overlay into those textures
    permanently. Present runs once per frame instead, but it makes no promise about
    which render target is bound, so bind the back buffer explicitly and put back
    whatever was there afterwards.
    */
    void renderOverlay(IDirect3DDevice9* device) {
        IDirect3DSurface9* previousTarget = nullptr;
        IDirect3DSurface9* backBuffer = nullptr;

        device->GetRenderTarget(0, &previousTarget);
        if (SUCCEEDED(device->GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, &backBuffer))) {
            device->SetRenderTarget(0, backBuffer);
        }

        // ImGui draws geometry, so it has to sit inside a scene of its own. The game
        // has already closed its scene by the time Present is called.
        if (SUCCEEDED(device->BeginScene())) {
            ImGui_ImplDX9_NewFrame();
            ImGui_ImplWin32_NewFrame();
            ImGui::NewFrame();

            drawHelloWorld();
            drawInspectorWindow();

            ImGui::EndFrame();
            ImGui::Render();
            ImGui_ImplDX9_RenderDrawData(ImGui::GetDrawData());
            device->EndScene();
        }

        if (backBuffer != nullptr) {
            backBuffer->Release();
        }
        if (previousTarget != nullptr) {
            device->SetRenderTarget(0, previousTarget);
            previousTarget->Release();
        }
    }

    HRESULT APIENTRY hookedPresent(IDirect3DDevice9* device, const RECT* sourceRect, const RECT* destRect,
        HWND destWindowOverride, const RGNDATA* dirtyRegion) {
        if (!imguiReady) {
            initImGui(device);
        }

        if (imguiReady && visible) {
            renderOverlay(device);
        }

        return originalPresent(device, sourceRect, destRect, destWindowOverride, dirtyRegion);
    }

    HRESULT APIENTRY hookedReset(IDirect3DDevice9* device, D3DPRESENT_PARAMETERS* presentationParameters) {
        // The device drops its resources here (alt-tab, resolution change), so ImGui's
        // vertex/index buffers and font texture have to be released and rebuilt.
        if (imguiReady) {
            ImGui_ImplDX9_InvalidateDeviceObjects();
        }

        HRESULT result = originalReset(device, presentationParameters);

        if (imguiReady && SUCCEEDED(result)) {
            ImGui_ImplDX9_CreateDeviceObjects();
        }
        return result;
    }

    bool patchVTableEntry(void** vtable, int index, void* replacement) noexcept {
        DWORD protection;
        if (!VirtualProtect(&vtable[index], sizeof(void*), PAGE_READWRITE, &protection)) {
            return false;
        }
        vtable[index] = replacement;

        DWORD trash;
        VirtualProtect(&vtable[index], sizeof(void*), protection, &trash);
        return true;
    }

    /**
    @brief creates a throwaway device just to read the vtable d3d9.dll shares
           between every device it hands out
    */
    void** acquireDeviceVTable() {
        IDirect3D9* d3d = Direct3DCreate9(D3D_SDK_VERSION);
        if (d3d == nullptr) {
            ERROR_OUT(printf("Overlay: Direct3DCreate9 failed\n"));
            return nullptr;
        }

        WNDCLASSEXW windowClass = {};
        windowClass.cbSize = sizeof(windowClass);
        windowClass.lpfnWndProc = DefWindowProcW;
        windowClass.hInstance = GetModuleHandleW(nullptr);
        windowClass.lpszClassName = L"BiceLibOverlayProbe";
        RegisterClassExW(&windowClass);

        HWND probeWindow = CreateWindowExW(0, windowClass.lpszClassName, L"", WS_OVERLAPPED,
            0, 0, 1, 1, nullptr, nullptr, windowClass.hInstance, nullptr);

        D3DPRESENT_PARAMETERS presentParams = {};
        presentParams.Windowed = TRUE;
        presentParams.SwapEffect = D3DSWAPEFFECT_DISCARD;
        presentParams.hDeviceWindow = probeWindow;
        presentParams.BackBufferFormat = D3DFMT_UNKNOWN;

        IDirect3DDevice9* probeDevice = nullptr;
        HRESULT hr = d3d->CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, probeWindow,
            D3DCREATE_SOFTWARE_VERTEXPROCESSING | D3DCREATE_NOWINDOWCHANGES,
            &presentParams, &probeDevice);

        void** vtable = nullptr;
        if (SUCCEEDED(hr) && probeDevice != nullptr) {
            vtable = *reinterpret_cast<void***>(probeDevice);
            probeDevice->Release();
        }
        else {
            ERROR_OUT(printf("Overlay: CreateDevice failed (%#010x)\n", hr));
        }

        d3d->Release();
        if (probeWindow != nullptr) {
            DestroyWindow(probeWindow);
        }
        UnregisterClassW(windowClass.lpszClassName, windowClass.hInstance);

        return vtable;
    }
}

bool Overlay::install() {
    if (installed) {
        return true;
    }

    void** vtable = acquireDeviceVTable();
    if (vtable == nullptr) {
        return false;
    }

    originalPresent = reinterpret_cast<PresentFn>(vtable[VTABLE_PRESENT]);
    originalReset = reinterpret_cast<ResetFn>(vtable[VTABLE_RESET]);

    if (!patchVTableEntry(vtable, VTABLE_PRESENT, hookedPresent) ||
        !patchVTableEntry(vtable, VTABLE_RESET, hookedReset)) {
        ERROR_OUT(printf("Overlay: could not patch the device vtable\n"));
        return false;
    }

    installed = true;
    INFO_OUT(printf("Overlay: D3D9 hooks installed\n"));
    return true;
}

void Overlay::toggle() {
    visible = !visible;
}

bool Overlay::isVisible() {
    return visible;
}
