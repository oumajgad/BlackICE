// Custom Mapmode: replaces what the VP map mode draws. It shades provinces by the
// level of a building, the amount of a resource, or their supply; the hook underneath
// decides the colour of every province, so the page has room to grow. See
// reversing/FINDINGS-mapmode.md.

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

    // One filter per kind, so switching kind and back finds the list as it was left.
    char buildingFilter[64] = {};
    char resourceFilter[64] = {};
    char supplyFilter[64] = {};
    std::string selectedName;
    // Wide enough for the longest building name with its key after it, since the key
    // is what separates the two entries both named "Air Base".
    float listWidth = 380.0f;

    ImVec4 toImGui(uint32_t argb) {
        return ImVec4(((argb >> 16) & 0xFF) / 255.0f, ((argb >> 8) & 0xFF) / 255.0f,
            (argb & 0xFF) / 255.0f, 1.0f);
    }

    /**
    @brief "0.33", "8.35", "42" - an amount read off the scale, about three figures

    Fixed decimals chosen by size rather than %g, which switches to exponent form at a
    thousand and printed "4.2e+04". Nothing here is ever written that way, whatever the
    size: a thousand prints as "1000".
    */
    std::string amount(int raw) {
        const double value = static_cast<double>(raw) / CustomMapMode::RESOURCE_SCALE;
        const int decimals = (value >= 100.0) ? 0 : (value >= 10.0) ? 1 : (value >= 1.0) ? 2 : 3;

        char text[32];
        sprintf_s(text, "%.*f", decimals, value);
        std::string out(text);

        // "42.0" and "0.050" read better as "42" and "0.05".
        if (out.find('.') != std::string::npos) {
            while (!out.empty() && out.back() == '0') {
                out.pop_back();
            }
            if (!out.empty() && out.back() == '.') {
                out.pop_back();
            }
        }
        return out;
    }

    /**@brief the start of a shade as the legend prints it, in the source's unit*/
    std::string startText(const CustomMapMode::Source& source, int raw) {
        switch (source.unit) {
        case CustomMapMode::Unit::Amount:
            return amount(raw);
        case CustomMapMode::Unit::Days:
            return amount(raw * (CustomMapMode::RESOURCE_SCALE / CustomMapMode::DAYS_SCALE));
        case CustomMapMode::Unit::Steps:
            return (raw >= CustomMapMode::CUT_OFF) ? "cut off" : std::to_string(raw);
        case CustomMapMode::Unit::Percent:
            return std::to_string(raw / 10) + "%";
        default:
            return std::to_string(raw);
        }
    }

    /**
    @brief what each shade means, in the colours the map draws them in

    Drawn from CustomMapMode::shadeColour, the same function colourFor paints with, so
    a swatch here cannot drift from the province it describes.

    A building's shade is its level. Anything else sits on a scale - worked out from the
    map, or fixed bands - so under each swatch is the value that shade starts at, which
    is the only way such a shade can be read as a quantity. Where a higher value is the
    worse one the shades run the other way, and so do the values under them.
    */
    void drawLegend() {
        const CustomMapMode::Source* source = CustomMapMode::shownSource();
        if (source == nullptr) {
            return;
        }
        const bool level = source->scaling == CustomMapMode::Scaling::Level;
        const bool fromMap = source->scaling == CustomMapMode::Scaling::Map;
        const CustomMapMode::Scale& scale = CustomMapMode::scale();

        ImGui::Spacing();
        ImGui::SeparatorText("Shades");

        if (!level && !scale.valid) {
            ImGui::TextDisabled("No province has any of this.");
            return;
        }

        const float size = ImGui::GetFrameHeight();
        if (ImGui::BeginTable("legend", CustomMapMode::TOP_LEVEL,
            ImGuiTableFlags_SizingFixedFit)) {
            for (int shade = 1; shade <= CustomMapMode::TOP_LEVEL; shade++) {
                ImGui::TableNextColumn();
                ImGui::PushID(shade);
                ImGui::ColorButton("##shade", toImGui(CustomMapMode::shadeColour(shade)),
                    ImGuiColorEditFlags_NoTooltip | ImGuiColorEditFlags_NoDragDrop,
                    ImVec2(size * 1.6f, size));
                ImGui::PopID();
            }
            ImGui::TableNextRow();
            for (int shade = 1; shade <= CustomMapMode::TOP_LEVEL; shade++) {
                ImGui::TableNextColumn();
                if (level) {
                    ImGui::TextDisabled("%d", shade);
                    continue;
                }
                const int band = source->higherIsWorse
                    ? CustomMapMode::TOP_LEVEL - shade : shade - 1;
                ImGui::TextDisabled("%s", startText(*source, scale.starts[band]).c_str());
            }
            ImGui::EndTable();
        }

        // The prose under the swatches wraps at the window's edge. TextDisabled and
        // TextColored do not wrap on their own - only TextWrapped does - so without
        // this the grey lines ran off the side. Pushed after the table rather than
        // before it: inside a cell it would wrap the amounts under the swatches too.
        ImGui::PushTextWrapPos(0.0f);
        if (!source->explanation.empty()) {
            ImGui::TextWrapped("%s", source->explanation.c_str());
        }
        if (fromMap) {
            ImGui::TextWrapped("Each shade starts at the amount under it. %d provinces "
                "have any; the scale runs from the 1%% with the least to the 1%% with the "
                "most, so everything above %s shares the top shade.",
                scale.producing,
                startText(*source, scale.starts[CustomMapMode::TOP_LEVEL - 1]).c_str());
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip(
                    "Logarithmic, so each shade covers about the same step up rather than\n"
                    "the same amount. Amounts like these are lopsided: a scale running\n"
                    "evenly to the largest puts most provinces that have any in the bottom\n"
                    "shade. Worked out from the map when chosen, and for supply again\n"
                    "every day.");
            }
        }
        else if (level) {
            ImGui::TextDisabled("Levels 1 to %d, the same ladder the game's infrastructure map climbs.",
                CustomMapMode::TOP_LEVEL);
        }
        if (CustomMapMode::kind() == CustomMapMode::Kind::Supply) {
            ImGui::TextDisabled("Grey: nothing to show. Only provinces you have the intel "
                "for - your own and your allies' - show any supply; the rest are dark grey.");
        }
        else {
            ImGui::TextDisabled("Grey: none here - light where you can see the province, dark where not.");
        }
        ImGui::PopTextWrapPos();
    }

    void drawCustomMapMode() {
        const std::vector<CustomMapMode::Source>& buildings = CustomMapMode::buildings();

        // Buildings are read off the game, so an empty list means there is no game yet -
        // and resources need one too, to be read at all.
        if (buildings.empty()) {
            ImGui::TextDisabled("Nothing read yet - load a game first.");
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
            ImGui::SetTooltip("While this is on, the VP map mode shows what is chosen\n"
                "below instead of victory points.\n\n"
                "Switch map mode away and back for the map to redraw.");
        }

        // Wrapped for the same reason as the legend's prose: TextColored does not.
        ImGui::PushTextWrapPos(0.0f);
        if (on && !CustomMapMode::hooked()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "Not hooked: %s", CustomMapMode::status());
        }
        else if (on) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Reselect the VP map mode in game to redraw the map.");
        }
        ImGui::PopTextWrapPos();

        ImGui::Spacing();

        // One button rather than a pair of radios: there are two ramps, so the label
        // can name the one in use and a click is enough to get the other.
        const bool heat = CustomMapMode::palette() == CustomMapMode::Palette::Heat;
        if (ImGui::Button(heat ? "Palette: red to green" : "Palette: green shades")) {
            CustomMapMode::setPalette(heat ? CustomMapMode::Palette::Green
                : CustomMapMode::Palette::Heat);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Green shades: one colour, brighter with the value.\n"
                "Red to green: red at the bottom shade, through orange and yellow,\n"
                "to green at the top.");
        }

        // What the map is shaded by. Radios rather than tabs: this changes what the map
        // shows, not just what the page lists, and a radio reads as a setting.
        ImGui::SameLine(0.0f, ImGui::GetStyle().ItemSpacing.x * 4.0f);
        ImGui::TextUnformatted("Shade by");
        ImGui::SameLine();
        const CustomMapMode::Kind kind = CustomMapMode::kind();
        if (ImGui::RadioButton("Buildings", kind == CustomMapMode::Kind::Building)
            && kind != CustomMapMode::Kind::Building) {
            CustomMapMode::showKind(CustomMapMode::Kind::Building);
        }
        ImGui::SameLine();
        if (ImGui::RadioButton("Resources", kind == CustomMapMode::Kind::Resource)
            && kind != CustomMapMode::Kind::Resource) {
            CustomMapMode::showKind(CustomMapMode::Kind::Resource);
        }
        ImGui::SameLine();
        if (ImGui::RadioButton("Supply", kind == CustomMapMode::Kind::Supply)
            && kind != CustomMapMode::Kind::Supply) {
            CustomMapMode::showKind(CustomMapMode::Kind::Supply);
        }

        const CustomMapMode::Kind shown = CustomMapMode::kind();
        const std::vector<CustomMapMode::Source>& sources = CustomMapMode::sources(shown);
        const bool resource = shown == CustomMapMode::Kind::Resource;
        const bool supply = shown == CustomMapMode::Kind::Supply;

        ImGui::Spacing();
        ImGui::SeparatorText(supply ? "Supply" : resource ? "Resource" : "Building");

        // The names the game itself uses, so the list matches what is in the province
        // window rather than what the mod files happen to be called - with the key in
        // brackets after it.
        //
        // The key is not decoration. Two buildings share the display name "Air Base",
        // and the selection comes back as the text that was clicked, so identical
        // labels would always resolve to the first of the two and leave the other
        // unreachable. Keys are unique, which makes these labels unique.
        std::vector<std::string> labels;
        labels.reserve(sources.size());
        for (size_t i = 0; i < sources.size(); i++) {
            const std::string& name = sources[i].label.empty()
                ? sources[i].name : sources[i].label;
            labels.push_back(name + " [" + sources[i].name + "]");
        }

        // The model can change the selection on its own, which it does when the mode
        // is switched on or the kind changes with nothing chosen, so the highlight
        // follows the model rather than the model following the highlight.
        const int chosen = CustomMapMode::selected();
        if (chosen >= 0 && chosen < static_cast<int>(labels.size())) {
            selectedName = labels[chosen];
        }
        else {
            selectedName.clear();
        }

        char* filter = supply ? supplyFilter : resource ? resourceFilter : buildingFilter;
        const size_t filterSize = sizeof(buildingFilter);
        static_assert(sizeof(buildingFilter) == sizeof(resourceFilter)
            && sizeof(buildingFilter) == sizeof(supplyFilter), "the filters share one size");

        // Height of zero, so the list takes whatever is left of the window rather
        // than a fixed height with empty space under it.
        if (Gui::filteredList(supply ? "supply" : resource ? "resources" : "buildings",
            ImVec2(listWidth, 0.0f), labels, filter, filterSize, selectedName)) {
            for (size_t i = 0; i < labels.size(); i++) {
                if (labels[i] == selectedName) {
                    CustomMapMode::select(shown, static_cast<int>(i));
                    break;
                }
            }
        }

        ImGui::SameLine();
        ImGui::BeginGroup();
        const int selected = CustomMapMode::selected();
        if (selected >= 0 && selected < static_cast<int>(sources.size())) {
            const CustomMapMode::Source& source = sources[selected];
            ImGui::Text("%s", source.label.empty() ? source.name.c_str()
                : source.label.c_str());
            ImGui::TextDisabled("%s", source.name.c_str());
            drawLegend();
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
