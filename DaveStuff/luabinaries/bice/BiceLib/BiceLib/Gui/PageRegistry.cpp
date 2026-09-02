#include <Gui/GuiPage.hpp>
#include <Gui/CountrySelection.hpp>
#include <CrashReport.hpp>
#include <Settings.hpp>

#include <Windows.h>
#include <algorithm>
#include <cfloat>
#include <cstring>
#include <map>
#include <string>

#include <imgui.h>
#include <imgui_internal.h> // DockBuilder, and the dock node behind each group

const char* const Gui::GROUP_ORDER[] = {
    "Main",         // the utility itself: who it reports on, and what it can do to the install
    "Country Info", // one country's state, live
    "Game Info",    // the mod's definitions, the same in every game
    "Inspector",    // what the running game says about a particular thing
    "Stats",
    "Options",
    "Help",
    "Debug",
};
const int Gui::GROUP_COUNT = static_cast<int>(sizeof(GROUP_ORDER) / sizeof(GROUP_ORDER[0]));

namespace {
    /**
     * Function local rather than a namespace scope vector: pages register from static
     * initializers, which run in unspecified order across translation units, so the
     * container has to be constructed on first use.
     */
    std::vector<Gui::GuiPage*>& registry() {
        static std::vector<Gui::GuiPage*> pages;
        return pages;
    }

    bool registrySorted = false;

    /**@brief position of \p group in GROUP_ORDER, or GROUP_COUNT for unknown groups*/
    int groupRank(const char* group) {
        for (int i = 0; i < Gui::GROUP_COUNT; i++) {
            if (std::strcmp(Gui::GROUP_ORDER[i], group) == 0) {
                return i;
            }
        }
        return Gui::GROUP_COUNT;
    }

    // Page -> the name ImGui knows its window by. Held here rather than built on demand
    // because ImGui wants a pointer that outlives the call.
    std::map<const Gui::GuiPage*, std::string> windowNames;

    std::map<const Gui::GuiPage*, Gui::PageTiming> timings;

    /**@brief the performance counter in milliseconds; a frame is far too coarse here*/
    double milliseconds() {
        static LARGE_INTEGER frequency = {};
        if (frequency.QuadPart == 0) {
            QueryPerformanceFrequency(&frequency);
        }

        LARGE_INTEGER counter = {};
        QueryPerformanceCounter(&counter);
        return (frequency.QuadPart == 0)
            ? 0.0
            : (static_cast<double>(counter.QuadPart) * 1000.0) /
              static_cast<double>(frequency.QuadPart);
    }

    /**@brief gives every page a unique window name, disturbing as few as possible*/
    void buildWindowNames() {
        std::map<std::string, int> titleUses;
        for (const Gui::GuiPage* page : registry()) {
            titleUses[page->title()]++;
        }

        windowNames.clear();
        for (const Gui::GuiPage* page : registry()) {
            std::string name = page->title();
            if (titleUses[name] > 1) {
                // ImGui hides everything from ## onwards, so the tab still reads as the
                // title while the window, its dock and its menu item stay distinct.
                name += "##";
                name += page->group();
            }
            windowNames[page] = name;
        }
    }

    /**@brief sorts by group, then by the page's own order, then alphabetically*/
    void sortRegistry() {
        std::stable_sort(registry().begin(), registry().end(),
            [](const Gui::GuiPage* a, const Gui::GuiPage* b) {
                const int groupA = groupRank(a->group());
                const int groupB = groupRank(b->group());
                if (groupA != groupB) {
                    return groupA < groupB;
                }
                if (a->order() != b->order()) {
                    return a->order() < b->order();
                }
                return std::strcmp(a->title(), b->title()) < 0;
            });
        registrySorted = true;
        buildWindowNames();
    }

    /**
     * One dockable window per group, mirroring the five windows the wxWidgets utility
     * used. A single shared tab bar would be unusable once every page is ported:
     * thirty tabs in one row cannot be read, let alone clicked.
     *
     * Each group window owns its own dockspace, so its pages tab within it, and any
     * page can still be dragged between groups or floated on its own.
     */
    struct GroupWindow
    {
        const char* group = nullptr;
        char title[64] = {};

        // Open to begin with. ImGui only settles a page into its dock once the page
        // and its host have both been submitted for a few frames, so the windows have
        // to exist first; they are hidden again by the auto hide below.
        bool open = true;

        /**
         * Computed rather than read with GetID() inside the window, because the node
         * must be kept alive on frames where the window is closed and therefore never
         * begun. GetID() hashes against the current window's id stack, so outside the
         * window it would return a different id every time.
         *
         * This reproduces what GetID("dockspace") yields inside the window: a window's
         * id is the hash of its title, and GetID seeds the child hash with it.
         */
        ImGuiID dockspaceId = 0;
    };

    GroupWindow groupWindows[Gui::GROUP_COUNT + 1]; // +1 for pages with an unknown group
    int groupWindowCount = 0;
    bool groupWindowsReady = false;

    /**
     * What was open last time, restored after everything has had a chance to settle.
     *
     * The windows cannot simply start in their saved state: a page only takes up its
     * dock position once it and its host have been submitted together, and a page with
     * no dock yet is a loose floating window. So everything opens, settles for a few
     * frames, and is then put into the state that was saved.
     *
     * ImGui's ini cannot carry this. It saves where a window is and what it is docked
     * into, but whether it is open is the application's own flag - the bool handed to
     * Begin - and ImGui never writes it. Without this, every page came back open and
     * every group window came back closed on each launch.
     *
     * The defaults match what the utility did before anything was saved: group windows
     * closed, so the overlay comes up showing only the control window, and pages open.
     */
    /**
     * Which page was the visible tab of each dock node, so it can be put back.
     *
     * Nothing of the overlay is submitted while it is hidden, so ImGui takes the pages
     * out of their nodes and the selection is decided afresh when they come back. It
     * is decided by whichever window holds the focus: DockNodeUpdateTabBar writes that
     * window's tab into the node on every frame, so a node whose focused page is not
     * the one that was showing opens on the wrong page and stays there.
     *
     * That is also why this was only ever seen in one group. Only one window can be
     * the focused one, so only that window's node can be dragged onto the wrong tab;
     * every other group came back correctly on its own.
     *
     * Keyed by dock node rather than by group, so a page moved into a node of its own
     * is remembered where it actually sits.
     */
    std::map<ImGuiID, const Gui::GuiPage*> selectedInNode;

    /**
     * Frames left in which the remembered tab may still be put back.
     *
     * The pages have to be submitted before a tab can be selected, so this cannot be
     * done in one frame. It stops as soon as the node reports the remembered tab for
     * two frames running, which with the focus moved as well is immediate.
     *
     * The cap is a backstop and nothing more: if some future change fights this the
     * way the focus rule did, a tab that can never be clicked would be a worse bug
     * than a tab that opens on the wrong page.
     */
    const int SETTLE_FRAME_CAP = 30;
    int reselectFramesLeft = 0;
    bool reselectSettled = true;
    int reselectHeldFrames = 0;

    int framesBeforeRestore = 3;
    bool visibilityRestored = false;

    const char* GROUP_SETTING_PREFIX = "groups.";
    const char* PAGE_SETTING_PREFIX = "pages.";

    // What was last written, so a click writes one key rather than every frame writing
    // all of them.
    std::map<std::string, bool> savedVisibility;

    std::string groupKey(const char* group) {
        return std::string(GROUP_SETTING_PREFIX) + group;
    }

    std::string pageKey(const Gui::GuiPage* page) {
        return std::string(PAGE_SETTING_PREFIX) + Gui::windowName(page);
    }

    void restoreVisibility() {
        for (int i = 0; i < groupWindowCount; i++) {
            const std::string key = groupKey(groupWindows[i].group);
            groupWindows[i].open = Settings::getInt(key.c_str(), 0) != 0;
            savedVisibility[key] = groupWindows[i].open;
        }
        for (Gui::GuiPage* page : Gui::pages()) {
            const std::string key = pageKey(page);
            page->open = Settings::getInt(key.c_str(), 1) != 0;
            savedVisibility[key] = page->open;
        }
    }

    /**@brief writes the ones that changed, which is normally none*/
    void saveVisibilityIfChanged() {
        for (int i = 0; i < groupWindowCount; i++) {
            const std::string key = groupKey(groupWindows[i].group);
            if (savedVisibility[key] != groupWindows[i].open) {
                savedVisibility[key] = groupWindows[i].open;
                Settings::setInt(key.c_str(), groupWindows[i].open ? 1 : 0);
            }
        }
        for (Gui::GuiPage* page : Gui::pages()) {
            const std::string key = pageKey(page);
            if (savedVisibility[key] != page->open) {
                savedVisibility[key] = page->open;
                Settings::setInt(key.c_str(), page->open ? 1 : 0);
            }
        }
    }

    const char* CONTROL_WINDOW = "BiceLib";

    /**@brief docks a group's pages into that group's own dockspace*/
    void buildGroupLayout(const GroupWindow& window, ImGuiID dockspaceId) {
        ImGui::DockBuilderRemoveNode(dockspaceId);
        ImGui::DockBuilderAddNode(dockspaceId, ImGuiDockNodeFlags_DockSpace);
        ImGui::DockBuilderSetNodeSize(dockspaceId, ImGui::GetMainViewport()->Size);

        // Sorted order, so the tab bar comes out in the order pages declare.
        for (Gui::GuiPage* page : Gui::pages()) {
            if (std::strcmp(page->group(), window.group) == 0) {
                ImGui::DockBuilderDockWindow(windowName(page), dockspaceId);
            }
        }

        ImGui::DockBuilderFinish(dockspaceId);
    }

    // Where a page sits is the player's choice, not the code's. group() decides only
    // starts, on the first launch with no ini to go by; after that the saved layout
    // wins, including for a page whose group changed in a later build. Deleting
    // BiceLibImGui.ini is how to take the code's arrangement again.

    /**@brief builds one window per group that actually has pages*/
    void ensureGroupWindows() {
        if (groupWindowsReady) {
            return;
        }
        groupWindowCount = 0;

        const char* previous = nullptr;
        for (Gui::GuiPage* page : Gui::pages()) {
            if (previous != nullptr && std::strcmp(previous, page->group()) == 0) {
                continue;
            }
            previous = page->group();

            GroupWindow& window = groupWindows[groupWindowCount++];
            window.group = page->group();
            window.open = true;
            // The group name alone could collide with a page title, and the prefix
            // makes the windows recognisable once they are floating separately.
            sprintf_s(window.title, "BiceLib - %s", page->group());
            window.dockspaceId = ImHashStr("dockspace", 0, ImHashStr(window.title));

            // Built up front rather than when the group is first shown. Pages are
            // submitted from the very first frame whether or not their group window is
            // open, so a page with no dock assignment yet appears as a loose floating
            // window until it gets one. DockBuilderDockWindow works on windows that do
            // not exist yet - it writes the dock id into their settings - so this does
            // not need the group window to be visible.
            //
            // Skipped when the ini already described this group, which would otherwise
            // be overwritten on every launch. Testable only here: submitting a node
            // with KeepAliveOnly creates it, so from the next frame on a node always
            // exists and its presence no longer means "restored from the ini".
            if (ImGui::DockBuilderGetNode(window.dockspaceId) == nullptr) {
                buildGroupLayout(window, window.dockspaceId);
            }

            if (groupWindowCount >= static_cast<int>(sizeof(groupWindows) / sizeof(groupWindows[0]))) {
                break;
            }
        }
        groupWindowsReady = true;
    }

    /**
    @brief asks for the next window's own OS window not to take focus when it appears

    Only matters for a page that has been dragged out of the game, which ImGui gives an
    OS window of its own. Those windows are destroyed when the overlay is put away and
    built again when it comes back, and a window appearing is normally shown with
    SW_SHOW, which activates it - so opening the utility took focus away from the game.
    The flag turns that into SW_SHOWNA: the window appears, and the game keeps focus
    until the window is actually clicked.

    Set per window rather than globally because it travels through the window class,
    which has no global equivalent. Everything else about the class is left at its
    default, so windows still dock together as before.
    */
    void noFocusOnAppearing() {
        ImGuiWindowClass windowClass;
        windowClass.ViewportFlagsOverrideSet = ImGuiViewportFlags_NoFocusOnAppearing;
        ImGui::SetNextWindowClass(&windowClass);
    }

    bool layoutResetRequested = false;

    /**
    @brief the whole of the reset, run before any window has been submitted this frame

    Clearing a window's settings undocks it and forgets its position, so the dock
    layout has to be rebuilt afterwards rather than before. What is open is put back to
    its defaults by way of the settings file, and then the ordinary startup sequence
    applies it: everything opens, settles into the new docks over a few frames, and is
    then set to what was saved. Going through that path rather than setting the flags
    here is what stops the pages coming back as loose floating windows.
    */
    void performLayoutReset() {
        for (Gui::GuiPage* page : Gui::pages()) {
            ImGui::ClearWindowSettings(Gui::windowName(page));
        }
        for (int i = 0; i < groupWindowCount; i++) {
            ImGui::ClearWindowSettings(groupWindows[i].title);
        }
        ImGui::ClearWindowSettings(CONTROL_WINDOW);

        for (int i = 0; i < groupWindowCount; i++) {
            buildGroupLayout(groupWindows[i], groupWindows[i].dockspaceId);
        }

        // Only the ones that are not already at their default, so a reset writes the
        // settings file a handful of times rather than once per page.
        for (int i = 0; i < groupWindowCount; i++) {
            const std::string key = groupKey(groupWindows[i].group);
            if (Settings::getInt(key.c_str(), 0) != 0) {
                Settings::setInt(key.c_str(), 0);
            }
            groupWindows[i].open = true;
        }
        for (Gui::GuiPage* page : Gui::pages()) {
            const std::string key = pageKey(page);
            if (Settings::getInt(key.c_str(), 1) != 1) {
                Settings::setInt(key.c_str(), 1);
            }
            page->open = true;
        }

        savedVisibility.clear();
        // The nodes are being rebuilt, so what was selected in the old ones means
        // nothing.
        selectedInNode.clear();
        reselectFramesLeft = 0;
        reselectSettled = true;
        framesBeforeRestore = 3;
        visibilityRestored = false;
    }

    void drawGroupWindow(GroupWindow& window, int index) {
        // Closed, so the window is never begun. The node still has to be submitted or
        // it counts as gone and every page docked into it is expelled into its own
        // floating window - and since that rewrites the layout, reopening would not
        // bring them back. KeepAliveOnly submits nothing and may be called from
        // anywhere, which is why the id is precomputed rather than read from GetID().
        if (!window.open) {
            ImGui::DockSpace(window.dockspaceId, ImVec2(0.0f, 0.0f), ImGuiDockNodeFlags_KeepAliveOnly);
            return;
        }

        // Staggered so the group windows do not land exactly on top of each other on
        // a first run. After that the saved layout decides.
        ImGui::SetNextWindowSize(ImVec2(720, 520), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(
            ImVec2(80.0f + index * 28.0f, 80.0f + index * 28.0f), ImGuiCond_FirstUseEver);

        noFocusOnAppearing();
        const bool visible = ImGui::Begin(window.title, &window.open);

        if (visible) {
            ImGui::DockSpace(window.dockspaceId);
        }
        else {
            // Collapsed: same reasoning as the closed case above.
            ImGui::DockSpace(window.dockspaceId, ImVec2(0.0f, 0.0f), ImGuiDockNodeFlags_KeepAliveOnly);
        }
        ImGui::End();
    }
}

namespace {
    /**
    @brief makes each node show the page it was showing before the overlay was hidden

    Written straight onto the node instead of going through SetNextWindowFocus,
    which would also raise the window - and for a group torn off into a window of its
    own that means taking the foreground off the game, which is a bug that has already
    been fixed once.
    */
    bool reselectRememberedTabs() {
        bool allHolding = true;
        for (std::map<ImGuiID, const Gui::GuiPage*>::const_iterator it = selectedInNode.begin();
            it != selectedInNode.end(); ++it) {
            ImGuiDockNode* node = ImGui::DockBuilderGetNode(it->first);
            if (node == nullptr) {
                continue;
            }
            ImGuiWindow* window = ImGui::FindWindowByName(Gui::windowName(it->second));
            if (window == nullptr) {
                continue;
            }

            // Both ids are read from ImGui rather than hashed here: its string hash is
            // CRC32-C, and computing one by hand has produced a confident wrong answer
            // in this codebase before.
            const ImGuiID showing = (node->TabBar != nullptr) ? node->TabBar->SelectedTabId
                : node->SelectedTabId;

            // The focused window decides the tab, every frame. DockNodeUpdateTabBar
            // ends with
            //
            //     if (g.NavWindow && g.NavWindow->RootWindow->DockNode == node)
            //         tab_bar->SelectedTabId = g.NavWindow->RootWindow->TabId;
            //
            // unconditionally, so while the focus sits on another page of this node
            // the tab written here is taken straight back. That is the whole bug, and
            // it is why only one group ever showed it: only one window can be the
            // focused one, so only that window's node is affected.
            //
            // SetNavWindow moves the focus and nothing else. FocusWindow would also
            // raise the window, which for a group torn off into a viewport of its own
            // means taking the foreground off the game.
            ImGuiContext& g = *ImGui::GetCurrentContext();
            if (g.NavWindow != nullptr && g.NavWindow->RootWindow != nullptr
                && g.NavWindow->RootWindow->DockNode == node
                && g.NavWindow->RootWindow->TabId != window->TabId) {
                ImGui::SetNavWindow(window);
            }

            if (showing == window->TabId) {
                continue;   // already showing it, so nothing to write
            }
            allHolding = false;

            node->SelectedTabId = window->TabId;
            if (node->TabBar != nullptr) {
                node->TabBar->SelectedTabId = window->TabId;
                node->TabBar->NextSelectedTabId = window->TabId;
            }
        }
        return allHolding;
    }
}

void Gui::onOverlayShown() {
    // Two seconds at sixty frames. Not a guess at when the tab is taken away, but a
    // cap: the writing stops as soon as the selection holds by itself.
    reselectFramesLeft = SETTLE_FRAME_CAP;
    reselectSettled = false;
    reselectHeldFrames = 0;
}

void Gui::registerPage(GuiPage* page) {
    registry().push_back(page);
    registrySorted = false; // Re-sorted lazily, registration happens before main()
}

const std::vector<Gui::GuiPage*>& Gui::pages() {
    if (!registrySorted) {
        sortRegistry();
    }
    return registry();
}

void Gui::drawPageMenu() {
    const char* currentGroup = nullptr;

    for (GuiPage* page : pages()) {
        if (currentGroup == nullptr || std::strcmp(currentGroup, page->group()) != 0) {
            if (currentGroup != nullptr) {
                ImGui::Separator();
            }
            currentGroup = page->group();
            ImGui::TextDisabled("%s", currentGroup);
        }
        ImGui::MenuItem(windowName(page), nullptr, &page->open);
    }
}

void Gui::drawAll() {
    // Polled here rather than by the Setup page: ImGui only calls draw() on the
    // visible tab, so pages reading the tag would go stale whenever Setup is hidden.
    Selection::refreshIfStale();

    ensureGroupWindows();

    // Before anything is submitted: the reset undocks windows and removes dock nodes,
    // which is not something to do to a window already begun this frame.
    if (layoutResetRequested) {
        layoutResetRequested = false;
        performLayoutReset();
    }

    // Small control window, so there is always a way back to a group window that has
    // been closed. The group windows themselves carry no menu.
    ImGui::SetNextWindowPos(ImVec2(40, 40), ImGuiCond_FirstUseEver);
    // Sized rather than auto-sized: AlwaysAutoResize would fit the window to the one
    // row of buttons, and a window that always fits its contents cannot be dragged
    // any narrower. A width on the first run keeps the compact look it used to have;
    // after that the saved layout decides, like every other window here.
    ImGui::SetNextWindowSize(ImVec2(520.0f, 0.0f), ImGuiCond_FirstUseEver);

    // Enough for the menu bar and one button. Below that the title bar is all that
    // would be left, and it would be a nuisance to grab hold of again.
    ImGui::SetNextWindowSizeConstraints(ImVec2(160.0f, 0.0f), ImVec2(FLT_MAX, FLT_MAX));

    noFocusOnAppearing();
    if (ImGui::Begin(CONTROL_WINDOW, nullptr,
        ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_NoDocking)) {

        if (ImGui::BeginMenuBar()) {
            if (ImGui::BeginMenu("Windows")) {
                for (int i = 0; i < groupWindowCount; i++) {
                    ImGui::MenuItem(groupWindows[i].group, nullptr, &groupWindows[i].open);
                }
                ImGui::Separator();
                if (ImGui::MenuItem("Show all")) {
                    for (int i = 0; i < groupWindowCount; i++) {
                        groupWindows[i].open = true;
                    }
                }
                ImGui::EndMenu();
            }
            if (ImGui::BeginMenu("Pages")) {
                drawPageMenu();
                ImGui::EndMenu();
            }
            ImGui::EndMenuBar();
        }

        // Wrapped by hand, because ImGui has no flow layout: after each button, ask
        // whether the next one still fits before putting it on the same line. The
        // widths have to be worked out rather than measured, since the next button
        // has not been submitted yet - SmallButton is its label plus the horizontal
        // frame padding, with no vertical padding.
        const ImGuiStyle& style = ImGui::GetStyle();
        const float rightEdge = ImGui::GetWindowPos().x + ImGui::GetWindowContentRegionMax().x;

        for (int i = 0; i < groupWindowCount; i++) {
            if (ImGui::SmallButton(groupWindows[i].group)) {
                groupWindows[i].open = !groupWindows[i].open;
            }

            if (i + 1 >= groupWindowCount) {
                continue;
            }

            const float nextWidth = ImGui::CalcTextSize(groupWindows[i + 1].group).x +
                style.FramePadding.x * 2.0f;
            if (ImGui::GetItemRectMax().x + style.ItemSpacing.x + nextWidth < rightEdge) {
                ImGui::SameLine();
            }
        }
    }
    ImGui::End();

    for (int i = 0; i < groupWindowCount; i++) {
        drawGroupWindow(groupWindows[i], i);
    }

    for (GuiPage* page : pages()) {
        if (!page->open) {
            continue;
        }
        // Recorded so a crash report can name the page that was drawing.
        CrashReport::notePage(page->title());

        noFocusOnAppearing();
        if (ImGui::Begin(windowName(page), &page->open)) {
            // Begin only returns true for the tab that is actually showing, so this
            // is the selection, recorded without asking ImGui for it. Not while the
            // selection is being put back: ImGui's wrong answer is still on screen
            // for those frames and would overwrite what is being restored.
            if (reselectSettled && ImGui::IsWindowDocked()) {
                selectedInNode[ImGui::GetWindowDockID()] = page;
            }

            // Timed around draw() only, which is where a page loads what it needs the
            // first time it is looked at. Begin and End are ImGui's own bookkeeping and
            // would only blur the number.
            const double started = milliseconds();
            page->draw();
            const double elapsed = milliseconds() - started;

            PageTiming& timing = timings[page];
            if (timing.calls == 0) {
                timing.firstMs = elapsed;
            }
            timing.lastMs = elapsed;
            timing.worstMs = (elapsed > timing.worstMs) ? elapsed : timing.worstMs;
            timing.calls++;
        }
        ImGui::End();
    }

    // Cleared once the pages are done, so a crash in what follows - ImGui's own
    // rendering, or the detached windows - is not blamed on whichever page happened
    // to be drawn last.
    CrashReport::notePage(nullptr);

    // After the pages, so the tabs exist to be selected. Kept up until the selection
    // holds on its own for two frames running, because something was seen taking the
    // tab back the moment writing stopped.
    if (!reselectSettled && reselectFramesLeft > 0) {
        reselectFramesLeft--;
        reselectHeldFrames = reselectRememberedTabs() ? (reselectHeldFrames + 1) : 0;
        if (reselectHeldFrames >= 2) {
            reselectSettled = true;
        }
    }
    else if (!reselectSettled) {
        reselectSettled = true;     // gave up; a tab must stay clickable
    }

    // Everything has been submitted at least once by now, so the pages are settled
    // into their docks and what was open last time can be put back.
    if (!visibilityRestored) {
        if (framesBeforeRestore > 0) {
            framesBeforeRestore--;
        }
        else {
            restoreVisibility();
            visibilityRestored = true;
        }
    }
    else {
        saveVisibilityIfChanged();
    }
}

void Gui::requestLayoutReset() {
    layoutResetRequested = true;
}

const char* Gui::windowName(const GuiPage* page) {
    pages(); // sorts the registry and fills the table on the first call
    const auto it = windowNames.find(page);
    return (it != windowNames.end()) ? it->second.c_str() : page->title();
}

const Gui::PageTiming& Gui::timing(const GuiPage* page) {
    static const PageTiming none;
    const auto it = timings.find(page);
    return (it != timings.end()) ? it->second : none;
}

void Gui::resetTimings() {
    timings.clear();
}
