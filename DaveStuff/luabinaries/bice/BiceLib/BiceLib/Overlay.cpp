#include <Overlay.hpp>

#include <Windows.h>
#include <d3d9.h>

#include <string>

#include <imgui.h>
#include <backends/imgui_impl_dx9.h>
#include <backends/imgui_impl_win32.h>

#include <Diagnostics.hpp>
#include <Gui/GuiPage.hpp>
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
    IDirect3DDevice9* renderDevice = nullptr;
    bool installed = false;
    bool imguiReady = false;

    // Starts hidden so the overlay never covers the main menu or a loading screen.
    // ImGui is still initialised on the first Present, so the window subclass that
    // listens for INSERT is in place before anyone presses it.
    bool visible = false;

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

    /**
    @brief path for the layout file, kept next to BiceLib.dll

    ImGui stores the pointer rather than copying it, so this has to outlive the
    context. Writing it beside the DLL keeps it out of the game's root directory and
    puts it somewhere predictable per install.
    */
    const char* layoutFilePath() {
        static std::string path;
        if (path.empty()) {
            path = Overlay::directory() + "BiceLibImGui.ini";
        }
        return path.c_str();
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
        io.IniFilename = layoutFilePath(); // Window positions and dock layout persist here

        // Lets the utility pages live as tabs of one window while still allowing a
        // tab to be torn off and docked elsewhere. Docking only, not viewports: real
        // OS windows would mean extra swap chains inside a hooked game.
        io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;

        if (!ImGui_ImplWin32_Init(gameWindow) || !ImGui_ImplDX9_Init(device)) {
            ERROR_OUT(printf("Overlay: ImGui backend init failed\n"));
            return;
        }

        originalWndProc = reinterpret_cast<WNDPROC>(
            SetWindowLongPtrW(gameWindow, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(hookedWndProc)));

        imguiReady = true;
        INFO_OUT(printf("Overlay: ImGui ready - press INSERT to toggle\n"));
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

            Gui::drawAll();

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
        Diagnostics::notePresentThread();
        renderDevice = device;

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

const std::string& Overlay::directory() {
    // Resolved from this function's own address rather than a module name, so it is
    // still right if the DLL is ever renamed. Cached: ImGui keeps the pointer to the
    // layout path built from it for the life of the context.
    static std::string path;
    static bool resolved = false;
    if (resolved) {
        return path;
    }
    resolved = true;

    HMODULE self = nullptr;
    char buffer[MAX_PATH] = {};
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        reinterpret_cast<LPCWSTR>(&Overlay::directory), &self) &&
        GetModuleFileNameA(self, buffer, MAX_PATH) != 0) {
        path = buffer;
        const size_t slash = path.find_last_of("\\/");
        path = (slash == std::string::npos) ? std::string() : path.substr(0, slash + 1);
    }
    return path;
}

IDirect3DDevice9* Overlay::device() {
    return renderDevice;
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
