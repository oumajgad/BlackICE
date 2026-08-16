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

    const char* HOST_WINDOW = "BiceLib Utility";
    const char* DOCKSPACE_ID = "BiceLibDockspace";

    bool layoutBuilt = false;

    /**@brief docks every page into one node so they start life as tabs of one window*/
    void buildDefaultLayout(ImGuiID dockspaceId) {
        ImGui::DockBuilderRemoveNode(dockspaceId);
        ImGui::DockBuilderAddNode(dockspaceId, ImGuiDockNodeFlags_DockSpace);
        ImGui::DockBuilderSetNodeSize(dockspaceId, ImGui::GetMainViewport()->Size);

        // Docked in sorted order, so the tab bar comes out grouped and ordered.
        for (Gui::GuiPage* page : Gui::pages()) {
            ImGui::DockBuilderDockWindow(page->title(), dockspaceId);
        }

        ImGui::DockBuilderFinish(dockspaceId);
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

    ImGui::SetNextWindowSize(ImVec2(760, 560), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(60, 60), ImGuiCond_FirstUseEver);

    const bool hostVisible = ImGui::Begin(HOST_WINDOW, nullptr, ImGuiWindowFlags_MenuBar);

    // Must be read while the host window is current, so after Begin() and regardless
    // of what it returned: Begin() pushes the window either way, which is why End()
    // is unconditional.
    const ImGuiID dockspaceId = ImGui::GetID(DOCKSPACE_ID);

    if (hostVisible) {
        if (ImGui::BeginMenuBar()) {
            if (ImGui::BeginMenu("Pages")) {
                drawPageMenu();
                ImGui::EndMenu();
            }
            ImGui::EndMenuBar();
        }

        if (!layoutBuilt) {
            layoutBuilt = true;
            // Only build a layout when there isn't one already: the saved ini restores
            // the previous arrangement, and rebuilding would throw it away every launch.
            if (ImGui::DockBuilderGetNode(dockspaceId) == nullptr) {
                buildDefaultLayout(dockspaceId);
            }
        }
        ImGui::DockSpace(dockspaceId);
    }
    else {
        // Collapsed, so Begin() returned false and the dockspace is not submitted.
        // A node that goes unsubmitted counts as gone and every page docked into it
        // gets expelled into its own floating window, so keep the node alive.
        ImGui::DockSpace(dockspaceId, ImVec2(0.0f, 0.0f), ImGuiDockNodeFlags_KeepAliveOnly);
    }
    ImGui::End();

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
