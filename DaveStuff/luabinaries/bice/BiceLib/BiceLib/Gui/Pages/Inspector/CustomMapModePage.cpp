// Custom Mapmode: paints the map with something of our own by taking over what the VP
// map mode draws. Today that is the level of one building; the hook decides the colour
// of every province, so there is room for more. See reversing/FINDINGS-mapmode.md.

#include <Gui/GuiPage.hpp>
#include <Gui/ListBox.hpp>
#include <GameState/CustomMapMode.hpp>

#include <Windows.h>
#include <cstdio>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const ImVec4 AMBER = ImVec4(0.80f, 0.60f, 0.20f, 1.0f);

    char buildingFilter[64] = {};
    std::string selectedName;
    // Wide enough for the longest name with its key after it, which is what makes
    // the two Air Bases tellable apart.
    float listWidth = 380.0f;

    void drawCustomMapMode() {
        const std::vector<CustomMapMode::Building>& buildings = CustomMapMode::buildings();

        if (buildings.empty()) {
            ImGui::TextDisabled("No buildings read yet - load a game first.");
            if (ImGui::Button("Try again")) {
                CustomMapMode::forget();
            }
            return;
        }

        bool on = CustomMapMode::enabled();
        if (ImGui::Checkbox("Paint the VP map mode with this instead", &on)) {
            CustomMapMode::setEnabled(on);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("While this is on, the VP map mode shows the level of\n"
                "the building below instead of victory points.\n\n"
                "Switch map mode away and back for the map to redraw.");
        }

        if (on && !CustomMapMode::hooked()) {
            ImGui::TextColored(AMBER, "Not hooked: %s", CustomMapMode::status());
        }
        else if (on && CustomMapMode::selected() < 0) {
            ImGui::TextColored(AMBER, "Pick a building below.");
        }
        else if (on) {
            ImGui::TextColored(AMBER,
                "Reselect the VP map mode in game to redraw the map.");
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Building");

        // The names the game itself uses, so the list matches what is in the province
        // window rather than what the mod files happen to be called - with the key in
        // brackets after it.
        //
        // Not decoration: two buildings share the name "Air Base", and the selection
        // is carried back as the text that was clicked. Without something to tell them
        // apart the first of the two always won, and picking the one that actually
        // carries the air capacity was impossible. Keys are unique, so this is too.
        std::vector<std::string> labels;
        labels.reserve(buildings.size());
        for (size_t i = 0; i < buildings.size(); i++) {
            const std::string& shown = buildings[i].label.empty()
                ? buildings[i].name : buildings[i].label;
            labels.push_back(shown + " [" + buildings[i].name + "]");
        }

        // Height of zero, so the list takes whatever is left of the window rather
        // than a fixed 240 pixels with empty space under it.
        if (Gui::filteredList("buildings", ImVec2(listWidth, 0.0f), labels,
            buildingFilter, sizeof(buildingFilter), selectedName)) {
            for (size_t i = 0; i < labels.size(); i++) {
                if (labels[i] == selectedName) {
                    CustomMapMode::select(static_cast<int>(i));
                    break;
                }
            }
        }

        ImGui::SameLine();
        ImGui::BeginGroup();
        const int selected = CustomMapMode::selected();
        if (selected >= 0 && selected < static_cast<int>(buildings.size())) {
            const CustomMapMode::Building& building = buildings[selected];
            ImGui::Text("%s", building.label.empty() ? building.name.c_str()
                : building.label.c_str());
            ImGui::TextDisabled("%s", building.name.c_str());
        }
        else {
            ImGui::TextDisabled("Nothing selected.");
        }
        ImGui::EndGroup();

    }

    class CustomMapModePage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Custom Mapmode"; }
        const char* group() const override { return "Inspector"; }
        int order() const override { return 55; }
        void draw() override { drawCustomMapMode(); }
    };
}

REGISTER_GUI_PAGE(CustomMapModePage);
