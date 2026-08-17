#include <Gui/GuiPage.hpp>
#include <Gui/CountrySelection.hpp>

#include <algorithm>
#include <cstring>

#include <imgui.h>
#include <imgui_internal.h> // DockBuilder, for the default layout

const char* const Gui::GROUP_ORDER[] = {
    "Main",
    "Game Info",
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
        bool open = true;
        bool layoutBuilt = false;

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

    const char* CONTROL_WINDOW = "BiceLib";

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
            window.layoutBuilt = false;
            // The group name alone could collide with a page title, and the prefix
            // makes the windows recognisable once they are floating separately.
            sprintf_s(window.title, "BiceLib - %s", page->group());
            window.dockspaceId = ImHashStr("dockspace", 0, ImHashStr(window.title));

            if (groupWindowCount >= static_cast<int>(sizeof(groupWindows) / sizeof(groupWindows[0]))) {
                break;
            }
        }
        groupWindowsReady = true;
    }

    /**@brief docks a group's pages into that group's own dockspace*/
    void buildGroupLayout(const GroupWindow& window, ImGuiID dockspaceId) {
        ImGui::DockBuilderRemoveNode(dockspaceId);
        ImGui::DockBuilderAddNode(dockspaceId, ImGuiDockNodeFlags_DockSpace);
        ImGui::DockBuilderSetNodeSize(dockspaceId, ImGui::GetMainViewport()->Size);

        // Sorted order, so the tab bar comes out in the order pages declare.
        for (Gui::GuiPage* page : Gui::pages()) {
            if (std::strcmp(page->group(), window.group) == 0) {
                ImGui::DockBuilderDockWindow(page->title(), dockspaceId);
            }
        }

        ImGui::DockBuilderFinish(dockspaceId);
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

        const bool visible = ImGui::Begin(window.title, &window.open);

        if (visible) {
            if (!window.layoutBuilt) {
                window.layoutBuilt = true;
                // Only when there is no saved node, otherwise the ini's arrangement
                // would be thrown away on every launch.
                if (ImGui::DockBuilderGetNode(window.dockspaceId) == nullptr) {
                    buildGroupLayout(window, window.dockspaceId);
                }
            }
            ImGui::DockSpace(window.dockspaceId);
        }
        else {
            // Collapsed: same reasoning as the closed case above.
            ImGui::DockSpace(window.dockspaceId, ImVec2(0.0f, 0.0f), ImGuiDockNodeFlags_KeepAliveOnly);
        }
        ImGui::End();
    }
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
        ImGui::MenuItem(page->title(), nullptr, &page->open);
    }
}

void Gui::drawAll() {
    // Polled here rather than by the Setup page: ImGui only calls draw() on the
    // visible tab, so pages reading the tag would go stale whenever Setup is hidden.
    Selection::refreshIfStale();

    ensureGroupWindows();

    // Small control window, so there is always a way back to a group window that has
    // been closed. The group windows themselves carry no menu.
    ImGui::SetNextWindowPos(ImVec2(40, 40), ImGuiCond_FirstUseEver);
    if (ImGui::Begin(CONTROL_WINDOW, nullptr,
        ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoDocking)) {

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

        for (int i = 0; i < groupWindowCount; i++) {
            if (i > 0) {
                ImGui::SameLine();
            }
            if (ImGui::SmallButton(groupWindows[i].group)) {
                groupWindows[i].open = !groupWindows[i].open;
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
        if (ImGui::Begin(page->title(), &page->open)) {
            page->draw();
        }
        ImGui::End();
    }
}
