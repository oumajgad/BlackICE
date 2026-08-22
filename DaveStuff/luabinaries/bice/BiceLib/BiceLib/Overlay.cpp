#include <Overlay.hpp>

#include <Windows.h>
#include <d3d9.h>

#include <string>

#include <imgui.h>
#include <backends/imgui_impl_dx9.h>
#include <backends/imgui_impl_win32.h>

#include <Diagnostics.hpp>
#include <Gui/GuiPage.hpp>
#include <Combat/CombatStore.hpp>
#include <Gui/TextureStats.hpp>
#include <MemScan.hpp>
#include <Gui/Warmup.hpp>
#include <utils.hpp>

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

namespace {
    // Indices into the IDirect3DDevice9 vtable. The first three slots belong to
    // IUnknown, so Reset/Present land at 16 and 17 respectively, and CreateTexture
    // at 23 - counted off the interface declaration in d3d9.h, because patching the
    // wrong slot would call SetDialogBoxMode with a texture's arguments.
    constexpr int VTABLE_RESET = 16;
    constexpr int VTABLE_PRESENT = 17;
    constexpr int VTABLE_CREATE_TEXTURE = 23;

    typedef HRESULT(APIENTRY* PresentFn)(IDirect3DDevice9*, const RECT*, const RECT*, HWND, const RGNDATA*);
    typedef HRESULT(APIENTRY* ResetFn)(IDirect3DDevice9*, D3DPRESENT_PARAMETERS*);
    typedef HRESULT(APIENTRY* CreateTextureFn)(IDirect3DDevice9*, UINT, UINT, UINT,
        DWORD, D3DFORMAT, D3DPOOL, IDirect3DTexture9**, HANDLE*);

    // IUnknown's own three slots come first in every COM vtable, so Release is 2.
    constexpr int VTABLE_RELEASE = 2;
    typedef ULONG(APIENTRY* TextureReleaseFn)(IDirect3DTexture9*);
    TextureReleaseFn originalTextureRelease = nullptr;

    // 0 until a thread claims the job of patching the texture vtable. Claimed with an
    // interlocked exchange because two loading threads can create their first texture
    // at the same moment, and the loser reading the slot after the winner wrote it
    // would take our own hook for the original and recurse for ever.
    volatile LONG textureVTableClaimed = 0;

    PresentFn originalPresent = nullptr;
    ResetFn originalReset = nullptr;
    CreateTextureFn originalCreateTexture = nullptr;
    WNDPROC originalWndProc = nullptr;

    HWND gameWindow = nullptr;
    IDirect3DDevice9* renderDevice = nullptr;

    // The probe device whose vtable was read, kept alive on purpose: on the native
    // runtime that table is the device's own memory and dies with it.
    IDirect3DDevice9* probeVTableOwner = nullptr;

    // Whether every device shares one vtable, which decides how the game's device can
    // be reached at all. DXVK shares; the native runtime gives each device its own,
    // where patching a table only ever reaches the device it came from.
    bool sharedDeviceVTable = false;
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

    /**
    @brief shows or hides the overlay, leaving no input behind on either side of it

    ImGui takes input as a queue and empties it in NewFrame, which only runs while the
    overlay is drawing. So a hidden overlay that still accepted messages would pile up
    every key pressed at the game, and play the lot into whatever had keyboard focus
    the moment it was opened again - arrows scrolled across the map arriving as arrows
    in a list.

    Nothing is fed to ImGui while hidden, and both the queue and the held keys are
    dropped on the way through here, so neither side inherits the other's input.
    */
    void setVisible(bool show) {
        visible = show;
        if (!imguiReady) {
            return;
        }

        ImGuiIO& io = ImGui::GetIO();
        io.ClearEventsQueue();
        io.ClearInputKeys();
        io.ClearInputMouse();
    }

    LRESULT CALLBACK hookedWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        if (msg == WM_KEYDOWN && wParam == VK_INSERT) {
            setVisible(!visible);
            return 0;
        }

        // Only while it is on screen. A hidden overlay has no use for input, and
        // queueing it would only mean replaying it later.
        if (imguiReady && visible) {
            ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam);

            ImGuiIO& io = ImGui::GetIO();
            if ((io.WantCaptureMouse && isMouseMessage(msg)) ||
                (io.WantCaptureKeyboard && isKeyboardMessage(msg))) {
                return 1; // Don't let the game react to input meant for the overlay
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

        if (imguiReady) {
            // Before the visibility check: the datasets the pages need are parsed
            // whether or not anyone is looking, which is the whole point of doing it
            // while the game sits at the menu.
            Gui::warmupStep();

            // Files finished combats away. Like the warm up, this happens whether or
            // not the overlay is showing: the record is of the campaign, not of the
            // time someone spent looking at it.
            Combat::Store::update();

            if (visible) {
                renderOverlay(device);
            }
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

    bool patchVTableEntry(void** vtable, int index, void* replacement) noexcept;

    /**
    @brief notices a texture's last reference going, so it leaves the live totals

    Only the pointer is used, and only as a key: by the time this returns zero the
    object is gone and touching it would be a use after free.
    */
    ULONG APIENTRY hookedTextureRelease(IDirect3DTexture9* texture) {
        const ULONG remaining = originalTextureRelease(texture);
        if (remaining == 0) {
            Gui::TextureStats::noteDestroyed(texture);
        }
        return remaining;
    }

    /**
    @brief patches Release on the shared IDirect3DTexture9 vtable, once

    d3d9.dll gives every texture of a kind the same vtable, so one patch covers all
    of them - including the textures that already existed before this ran, which is
    fine: they are not in the live table and releasing them does nothing.
    */
    void hookTextureVTable(IDirect3DTexture9* texture) {
        // The same table-per-object question as the device's, and here it is not worth
        // solving: where each texture has its own table, patching one would only count
        // that texture, and the table would die with it - leaving the saved Release
        // pointing at freed memory. Live counts are a nicety; that is not.
        if (!sharedDeviceVTable) {
            return;
        }

        if (InterlockedCompareExchange(&textureVTableClaimed, 1, 0) != 0) {
            return;
        }

        void** vtable = *reinterpret_cast<void***>(texture);

        // Written before the slot is patched, so the hook always has somewhere to
        // forward to no matter when another thread first reaches it.
        originalTextureRelease = reinterpret_cast<TextureReleaseFn>(vtable[VTABLE_RELEASE]);

        if (patchVTableEntry(vtable, VTABLE_RELEASE, hookedTextureRelease)) {
            Gui::TextureStats::setReleaseHooked();
        }
        else {
            ERROR_OUT(printf("Overlay: could not hook texture Release\n"));
        }
    }

    /**
    @brief counts every texture the game creates, then gets out of the way

    D3DX builds its textures through the device like anything else, so this sees the
    format a .dds ends up with rather than the one it was stored in - which is the
    only way to tell whether a compressed file stays compressed in memory.

    The level count is read back from the texture instead of taken from the argument:
    a request of zero means "however many it takes", and the difference is a third of
    the size.
    */
    HRESULT APIENTRY hookedCreateTexture(IDirect3DDevice9* device, UINT width, UINT height,
        UINT levels, DWORD usage, D3DFORMAT format, D3DPOOL pool,
        IDirect3DTexture9** texture, HANDLE* sharedHandle) {
        const HRESULT result = originalCreateTexture(device, width, height, levels, usage,
            format, pool, texture, sharedHandle);

        if (SUCCEEDED(result)) {
            UINT actualLevels = levels;
            if (texture != nullptr && *texture != nullptr) {
                actualLevels = (*texture)->GetLevelCount();
                hookTextureVTable(*texture);
            }
            Gui::TextureStats::note(texture != nullptr ? *texture : nullptr,
                width, height, actualLevels,
                static_cast<unsigned int>(usage), static_cast<unsigned int>(format),
                static_cast<unsigned int>(pool));
        }
        return result;
    }

    /**
    @brief redirects a function itself, for when patching a vtable cannot reach it

    Microsoft builds its DLLs ready for this: every function starts with a two byte
    `mov edi, edi` that does nothing, and sits behind five bytes of padding. So a five
    byte jump goes in the padding, the do-nothing instruction becomes a two byte jump
    back into it, and the original is still there from its third byte on - which is
    what callers of the original then call.

    Nothing has to be disassembled and nothing is copied, which is why this is worth
    preferring over a trampoline wherever the padding is there. Where it is not - a
    DLL built by anything but MSVC, DXVK among them - this refuses rather than
    guessing at instruction boundaries.

    @param original set to the function as it was, two bytes in
    */
    bool hotPatchFunction(void* target, void* replacement, void** original) noexcept {
        unsigned char* code = reinterpret_cast<unsigned char*>(target);

        if (code[0] != 0x8B || code[1] != 0xFF) {
            return false; // not the mov edi, edi a hot patchable function begins with
        }
        for (int i = -5; i < 0; i++) {
            if (code[i] != 0x90 && code[i] != 0xCC) {
                return false; // the padding is in use, so there is nowhere to jump from
            }
        }

        DWORD protection;
        if (!VirtualProtect(code - 5, 7, PAGE_EXECUTE_READWRITE, &protection)) {
            return false;
        }

        // jmp rel32, counted from the end of the jump itself, into our function.
        const long relative = static_cast<long>(
            reinterpret_cast<unsigned char*>(replacement) - (code - 5) - 5);
        code[-5] = 0xE9;
        memcpy(code - 4, &relative, sizeof(relative));

        // jmp rel8 back seven bytes: two for this jump, five for the one above.
        code[0] = 0xEB;
        code[1] = 0xF9;

        DWORD trash;
        VirtualProtect(code - 5, 7, protection, &trash);
        FlushInstructionCache(GetCurrentProcess(), code - 5, 7);

        *original = code + 2;
        return true;
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
    @brief creates a device just to read the vtable d3d9.dll gives the ones it hands out

    The device is **kept**, not released. Its vtable is only guaranteed to outlive it
    where the vtable is static data in the module, which is true of DXVK and not of
    the native runtime: there the table lives in memory the device owns, so releasing
    it and then reading Present out of the table is a read of freed memory. That is
    exactly what used to happen, and why the game would not start without DXVK.

    So the probe stays alive for as long as the process does, along with the window it
    was given. A null reference device costs almost nothing to keep; a hardware one is
    only ever the fallback.
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

        // Hardware first, because the game's device is a hardware one and only devices
        // of the same kind are guaranteed to share an implementation - and therefore a
        // vtable to patch.
        //
        // A null reference device was tried here first, on the grounds that it owns no
        // adapter and so cannot disturb anything. It launched and never drew: DXVK
        // gives every device the same vtable whatever its type, but the native runtime
        // gives a null reference device its own, so the patch went somewhere the game
        // never looked. It stays as the fallback, where a table that is never used
        // beats no overlay at all.
        const D3DDEVTYPE kinds[] = { D3DDEVTYPE_HAL, D3DDEVTYPE_NULLREF };

        void** vtable = nullptr;
        for (int i = 0; i < 2 && vtable == nullptr; i++) {
            IDirect3DDevice9* probeDevice = nullptr;
            const HRESULT hr = d3d->CreateDevice(D3DADAPTER_DEFAULT, kinds[i],
                probeWindow, D3DCREATE_SOFTWARE_VERTEXPROCESSING | D3DCREATE_NOWINDOWCHANGES,
                &presentParams, &probeDevice);

            if (SUCCEEDED(hr) && probeDevice != nullptr) {
                vtable = *reinterpret_cast<void***>(probeDevice);

                // Held, not released - see above. Nothing else needs it, so it is
                // only remembered to make the leak deliberate rather than accidental.
                probeVTableOwner = probeDevice;
                INFO_OUT(printf("Overlay: device vtable read from a %s probe\n",
                    kinds[i] == D3DDEVTYPE_NULLREF ? "null reference" : "hardware"));

                // Whether patching this table can reach the game's device at all.
                //
                // The whole approach rests on one vtable being shared by every device
                // of a kind. A second device of the same kind either points at the
                // same table, in which case so does the game's, or it does not, in
                // which case nothing patched here will ever be called and the log
                // should say so rather than leaving an overlay that quietly does
                // nothing.
                IDirect3DDevice9* second = nullptr;
                if (SUCCEEDED(d3d->CreateDevice(D3DADAPTER_DEFAULT, kinds[i],
                    probeWindow, D3DCREATE_SOFTWARE_VERTEXPROCESSING | D3DCREATE_NOWINDOWCHANGES,
                    &presentParams, &second)) && second != nullptr) {
                    void** other = *reinterpret_cast<void***>(second);
                    sharedDeviceVTable = (other == vtable);

                    if (sharedDeviceVTable) {
                        INFO_OUT(printf("Overlay: devices share one vtable, so patching "
                            "it reaches the game's device\n"));
                    }
                    else {
                        // Two tables, but they should still name the same functions -
                        // and those can be patched instead. If even the entries differ
                        // there is nothing left that every device goes through.
                        const bool sameEntries =
                            other[VTABLE_PRESENT] == vtable[VTABLE_PRESENT] &&
                            other[VTABLE_RESET] == vtable[VTABLE_RESET] &&
                            other[VTABLE_CREATE_TEXTURE] == vtable[VTABLE_CREATE_TEXTURE];

                        INFO_OUT(printf("Overlay: every device has its own vtable "
                            "(%p vs %p), %s\n", vtable, other,
                            sameEntries ? "but they hold the same functions - hooking those"
                                        : "and they hold different functions"));

                        if (!sameEntries) {
                            vtable = nullptr; // nothing here can reach the game
                        }
                    }
                    second->Release();
                }
            }
            else {
                ERROR_OUT(printf("Overlay: %s CreateDevice failed (%#010x)\n",
                    kinds[i] == D3DDEVTYPE_NULLREF ? "null reference" : "hardware", hr));
            }
        }

        // The interface can go; the device holds its own reference to what it needs.
        // The window and its class stay, because the device was given that window and
        // outliving its own window is not something a device has to tolerate.
        d3d->Release();

        // A vtable that cannot be read is not a vtable. Better to find that out here,
        // where the answer is a message, than three instructions later where it is an
        // access violation inside the game.
        void* entries[VTABLE_CREATE_TEXTURE + 1] = {};
        if (vtable != nullptr &&
            !Mem::tryReadBytes(reinterpret_cast<uintptr_t>(vtable), entries,
                sizeof(entries))) {
            ERROR_OUT(printf("Overlay: the device vtable at %p could not be read\n",
                vtable));
            vtable = nullptr;
        }

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

const std::string& Overlay::gameDirectory() {
    static std::string path;
    static bool resolved = false;
    if (resolved) {
        return path;
    }
    resolved = true;

    // The executable, not this module: nullptr means the process image.
    char buffer[MAX_PATH] = {};
    if (GetModuleFileNameA(nullptr, buffer, MAX_PATH) != 0) {
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
    originalCreateTexture = reinterpret_cast<CreateTextureFn>(vtable[VTABLE_CREATE_TEXTURE]);

    bool textureHooked = false;
    if (sharedDeviceVTable) {
        // One table for every device, so redirecting it is enough and leaves the
        // runtime's own code untouched.
        if (!patchVTableEntry(vtable, VTABLE_PRESENT, hookedPresent) ||
            !patchVTableEntry(vtable, VTABLE_RESET, hookedReset)) {
            ERROR_OUT(printf("Overlay: could not patch the device vtable\n"));
            return false;
        }
        textureHooked = patchVTableEntry(vtable, VTABLE_CREATE_TEXTURE, hookedCreateTexture);
    }
    else {
        // A table each, so the functions they all point at are what to redirect.
        if (!hotPatchFunction(originalPresent, hookedPresent,
                reinterpret_cast<void**>(&originalPresent)) ||
            !hotPatchFunction(originalReset, hookedReset,
                reinterpret_cast<void**>(&originalReset))) {
            ERROR_OUT(printf("Overlay: could not hook Present and Reset\n"));
            return false;
        }
        textureHooked = hotPatchFunction(originalCreateTexture, hookedCreateTexture,
            reinterpret_cast<void**>(&originalCreateTexture));
    }

    // Accounting only, so a failure here is not worth refusing to start over: the
    // overlay works without it and the Memory page says the numbers are missing.
    if (textureHooked) {
        Gui::TextureStats::setHooked();
    }
    else {
        ERROR_OUT(printf("Overlay: could not hook CreateTexture\n"));
    }

    installed = true;
    INFO_OUT(printf("Overlay: D3D9 hooks installed\n"));
    return true;
}

void Overlay::toggle() {
    setVisible(!visible);
}

bool Overlay::isVisible() {
    return visible;
}
