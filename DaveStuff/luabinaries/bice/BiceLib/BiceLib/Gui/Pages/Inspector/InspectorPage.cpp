#include <Gui/GuiPage.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>
#include <vector>

#include <imgui.h>

#include <GameState/Inspector.hpp>

namespace {
    /////////////////////////////////////
    //          INSPECTOR BOX          //
    /////////////////////////////////////

    std::vector<Inspector::Entity> selection;
    ULONGLONG lastSelectionSampleMs = 0;
    bool showInspector = true;

    /**@brief a unit rather than a province, which is what the stat table describes*/
    bool isUnitType(const char* type) {
        return type != nullptr
            && (strcmp(type, "Army") == 0 || strcmp(type, "Navy") == 0
                || strcmp(type, "Air") == 0);
    }

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
            ImGui::TextUnformatted(stat.name.empty() ? "?" : stat.name.c_str());
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

    void drawInspectorContents() {
        const uintptr_t idler = Inspector::idlerAddress();

        if (ImGui::Button("Re-cache idler")) {
            Inspector::recacheIdler();
            lastSelectionSampleMs = 0; // Refresh the selection straight away
        }

        const int count = Inspector::idlerCount();
        if (count == 0) {
            ImGui::SameLine();
            ImGui::TextDisabled("CIngameIdler: not found");
            ImGui::Spacing();
            ImGui::TextWrapped("The idler only exists once a session is running. "
                "Load or start a game, then press Re-cache idler.");
            return;
        }

        // The scan finds several objects sharing the vftable and only one of them is
        // the live idler, so let the candidates be cycled through until units show up.
        ImGui::SameLine();
        if (ImGui::Button("-")) {
            Inspector::selectIdlerIndex(Inspector::idlerIndex() - 1);
            lastSelectionSampleMs = 0;
        }
        ImGui::SameLine();
        if (ImGui::Button("+")) {
            Inspector::selectIdlerIndex(Inspector::idlerIndex() + 1);
            lastSelectionSampleMs = 0;
        }
        ImGui::SameLine();
        ImGui::Text("%d/%d  %#010x", Inspector::idlerIndex() + 1, count, static_cast<unsigned>(idler));

        if (idler == 0) {
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

                // The stats above come straight off the unit type, so they are what
                // one sub unit is before anything the game does to it. Worth saying
                // plainly: supply and fuel in particular read lower here than in the
                // game's own tooltip, and people notice that and assume a bug.
                if (!entity.stats.empty() && isUnitType(entity.type)) {
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f),
                        "Base values for the unit type.");
                    if (ImGui::IsItemHovered()) {
                        ImGui::SetTooltip(
                            "Per sub unit, and before the effects the game applies:\n"
                            "leader traits, the commanders above the unit, national\n"
                            "modifiers, terrain, and how much strength is left.\n\n"
                            "For what a whole unit actually consumes, the OOB Browser\n"
                            "asks the game itself and matches its tooltip.");
                    }
                }

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
}

namespace {
    /**@brief reading the selection allocates, so don't do it every frame*/
    void sampleSelection() {
        const ULONGLONG now = GetTickCount64();
        if (now - lastSelectionSampleMs >= 250 || lastSelectionSampleMs == 0) {
            selection = Inspector::getSelection();
            lastSelectionSampleMs = now;
        }
    }

    class InspectorPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Unit Inspector"; }
        const char* group() const override { return "Inspector"; }
        int order() const override { return 10; }
        void draw() override {
            sampleSelection();
            drawInspectorContents();
        }
    };
}

REGISTER_GUI_PAGE(InspectorPage);
