// Custom Mapmode: replaces what the VP map mode draws. It shades provinces by the
// level of one building; the hook underneath decides the colour of every province, so
// the page has room to grow. See reversing/FINDINGS-mapmode.md.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/ListBox.hpp>
#include <GameState/CustomMapMode.hpp>

#include <Windows.h>
#include <cstdio>
#include <string>
#include <vector>

#include <imgui.h>

namespace {

    char buildingFilter[64] = {};
    std::string selectedName;
    // Wide enough for the longest building name with its key after it, since the key
    // is what separates the two entries both named "Air Base".
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

        bool on = CustomMapMode::requested();
        if (ImGui::Checkbox("Paint the VP map mode with this instead", &on)) {
            CustomMapMode::setEnabled(on);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("While this is on, the VP map mode shows the level of\n"
                "the building below instead of victory points.\n\n"
                "Switch map mode away and back for the map to redraw.");
        }

        if (on && !CustomMapMode::hooked()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "Not hooked: %s", CustomMapMode::status());
        }
        else if (on) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Reselect the VP map mode in game to redraw the map.");
        }

        ImGui::Spacing();

        // One button rather than a pair of radios: there are two ramps, so the label
        // can name the one in use and a click is enough to get the other.
        const bool heat = CustomMapMode::palette() == CustomMapMode::Palette::Heat;
        if (ImGui::Button(heat ? "Palette: red to green" : "Palette: green shades")) {
            CustomMapMode::setPalette(heat ? CustomMapMode::Palette::Green
                : CustomMapMode::Palette::Heat);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Green shades: one colour, brighter with the level.\n"
                "Red to green: red at level 1, through orange and yellow,\n"
                "to green at level %d.", CustomMapMode::TOP_LEVEL);
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Building");

        // The names the game itself uses, so the list matches what is in the province
        // window rather than what the mod files happen to be called - with the key in
        // brackets after it.
        //
        // The key is not decoration. Two buildings share the display name "Air Base",
        // and the selection comes back as the text that was clicked, so identical
        // labels would always resolve to the first of the two and leave the other
        // unreachable. Keys are unique, which makes these labels unique.
        std::vector<std::string> labels;
        labels.reserve(buildings.size());
        for (size_t i = 0; i < buildings.size(); i++) {
            const std::string& shown = buildings[i].label.empty()
                ? buildings[i].name : buildings[i].label;
            labels.push_back(shown + " [" + buildings[i].name + "]");
        }

        // The model can change the selection on its own, which it does when the mode
        // is switched on with nothing chosen, so the highlight follows the model
        // rather than the model following the highlight.
        const int chosen = CustomMapMode::selected();
        if (chosen >= 0 && chosen < static_cast<int>(labels.size())
            && selectedName != labels[chosen]) {
            selectedName = labels[chosen];
        }

        // Height of zero, so the list takes whatever is left of the window rather
        // than a fixed height with empty space under it.
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
