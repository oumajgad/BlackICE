// Minister Buildings: how close each minister is to placing his next building.
//
// Every building type has a counter that the AI ticks up and a trigger it has to reach.
// Read only - the counters belong to the AI, and writing them would just be overwritten
// on the next pass.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <algorithm>
#include <cfloat>
#include <cstdio>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.MinisterBuildings.Collect";

    struct Building
    {
        std::string key;
        std::string name;
        int order = 0;
        double count = 0.0;
        double trigger = 0.0;
        double percent = 0.0;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    std::vector<Building> buildings;

    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    // Progress by default: the question this page answers is "what is about to be
    // built", not "where is the shipyard in the list".
    int sortMode = 0; // 0 progress, 1 name, 2 the order the wx page used
    const char* const SORT_MODES[] = { "Progress", "Name", "Category" };

    void applySort() {
        std::stable_sort(buildings.begin(), buildings.end(),
            [](const Building& a, const Building& b) {
                if (sortMode == 0 && a.percent != b.percent) {
                    return a.percent > b.percent;
                }
                if (sortMode == 1) {
                    return _stricmp(a.name.c_str(), b.name.c_str()) < 0;
                }
                return a.order < b.order;
            });
    }

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;

        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        tag = Gui::Lua::stringField("tag");
        buildings.clear();

        if (available) {
            const int count = Gui::Lua::arrayLength("rows");
            buildings.reserve(static_cast<size_t>(count));
            for (int i = 0; i < count; i++) {
                if (!Gui::Lua::pushArrayElement("rows", i)) {
                    continue;
                }
                Building building;
                building.key = Gui::Lua::stringField("key");
                building.name = Gui::Lua::stringField("name");
                building.order = static_cast<int>(Gui::Lua::numberField("order"));
                building.count = Gui::Lua::numberField("count");
                building.trigger = Gui::Lua::numberField("trigger");
                building.percent = Gui::Lua::numberField("percent");
                buildings.push_back(building);
                Gui::Lua::popArrayElement();
            }
            applySort();
        }

        Gui::Lua::endCall();
    }

    void drawMinisterBuildings() {
        if (ImGui::Button("Refresh")) {
            refresh();
            lastSampleMs = GetTickCount64();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &autoRefresh);

        if (autoRefresh) {
            const ULONGLONG now = GetTickCount64();
            if (now - lastSampleMs >= 2000) {
                refresh();
                lastSampleMs = now;
            }
        }

        ImGui::SameLine();
        ImGui::SetNextItemWidth(120.0f);
        if (Gui::wheelCombo("##sort", &sortMode, SORT_MODES, IM_ARRAYSIZE(SORT_MODES))) {
            applySort();
        }

        ImGui::SameLine();
        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return;
        }
        ImGui::TextDisabled("%s (%s)", tag.c_str(), Gui::Selection::source().c_str());

        ImGui::TextWrapped("Progress towards the next building each of your ministers "
            "will place. The counters are maintained by the AI, so nothing on this page "
            "can be set.");
        ImGui::Spacing();

        if (!ImGui::BeginTable("buildings", 3, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingFixedFit |
            ImGuiTableFlags_ScrollY)) {
            return;
        }

        const float countWidth = ImGui::CalcTextSize("000 / 000").x;

        ImGui::TableSetupColumn("Building", ImGuiTableColumnFlags_WidthStretch, 0.5f);
        ImGui::TableSetupColumn("Count", ImGuiTableColumnFlags_WidthFixed, countWidth);
        ImGui::TableSetupColumn("Progress", ImGuiTableColumnFlags_WidthStretch, 0.5f);
        ImGui::TableSetupScrollFreeze(0, 1);
        ImGui::TableHeadersRow();

        for (const Building& building : buildings) {
            ImGui::TableNextRow();

            ImGui::TableNextColumn();
            ImGui::TextUnformatted(building.name.c_str());

            ImGui::TableNextColumn();
            ImGui::Text("%.0f / %.0f", building.count, building.trigger);

            ImGui::TableNextColumn();
            char overlay[32];
            sprintf_s(overlay, "%.1f%%", building.percent);
            // Clamped: the counter can overshoot the trigger between AI passes, and a
            // bar wider than its own column looks like a drawing fault.
            const float fraction = static_cast<float>(building.percent / 100.0);
            ImGui::ProgressBar(fraction > 1.0f ? 1.0f : fraction,
                ImVec2(-FLT_MIN, ImGui::GetTextLineHeight()), overlay);
        }
        ImGui::EndTable();
    }

    class MinisterBuildingsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Minister Buildings"; }
        const char* group() const override { return "Main"; }
        int order() const override { return 90; }
        void draw() override { drawMinisterBuildings(); }
    };
}

REGISTER_GUI_PAGE(MinisterBuildingsPage);
