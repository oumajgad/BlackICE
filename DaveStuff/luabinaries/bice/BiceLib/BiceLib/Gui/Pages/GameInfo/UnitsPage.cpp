// Units: a unit's stats with every applicable technology applied, plus a what-if
// calculator - the assumed tech levels can be raised or lowered to see what the unit
// would look like with more research.
//
// Stats, model string and the tech list all depend on the assumed levels, so a level
// change re-fetches all three together rather than patching one of them.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Units.Collect";
    const char* SELECT = "BiceLibGui.Units.Select";
    const char* TECH_DETAILS = "BiceLibGui.Units.TechDetails";
    const char* CHANGE_LEVEL = "BiceLibGui.Units.ChangeTechLevel";
    const char* RESET_LEVELS = "BiceLibGui.Units.ResetTechLevels";

    std::vector<std::string> units;
    bool listLoaded = false;
    bool triedOnce = false;
    std::string listError;

    std::string selectedUnit;
    std::string unitKey;
    std::string unitModel;
    std::string unitStats;
    std::string unitError;
    std::vector<std::string> techLabels;

    std::string selectedTech;
    std::string techKey;
    std::string techEffects;
    int techLevel = 0;      // What the page is assuming
    int techResearched = 0; // What the country actually has
    bool techApplied = true;

    char unitFilter[64] = {};
    char techFilter[64] = {};
    float listWidth = 280.0f;   // Drag the dividers to change
    float techListWidth = 300.0f;

    /**@brief reads the unit detail table left on the stack by any of the Lua calls*/
    void readDetails() {
        unitKey.clear();
        unitModel.clear();
        unitStats.clear();
        techLabels.clear();
        unitError.clear();

        if (!Gui::Lua::boolField("available")) {
            unitError = Gui::Lua::stringField("reason", "unavailable");
            return;
        }

        unitKey = Gui::Lua::stringField("key");
        unitModel = Gui::Lua::stringField("model");
        unitStats = Gui::Lua::stringField("stats");

        const int count = Gui::Lua::arrayLength("techs");
        techLabels.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("techs", i)) {
                continue;
            }
            techLabels.push_back(Gui::Lua::stringField("label"));
            Gui::Lua::popArrayElement();
        }
    }

    void loadTechDetails(const std::string& techChoice) {
        techKey.clear();
        techEffects.clear();
        techLevel = 0;
        techResearched = 0;
        techApplied = true;

        if (techChoice.empty()) {
            return;
        }
        if (!Gui::Lua::beginTableCallWithString(TECH_DETAILS, techChoice.c_str())) {
            techEffects = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            techKey = Gui::Lua::stringField("key");
            techLevel = static_cast<int>(Gui::Lua::numberField("level"));
            techResearched = static_cast<int>(Gui::Lua::numberField("researched"));
            techApplied = Gui::Lua::boolField("applied", true);
            techEffects = Gui::Lua::stringField("effects");
        }
        else {
            techEffects = Gui::Lua::stringField("reason", "unavailable");
        }
        Gui::Lua::endCall();
    }

    void selectUnit(const std::string& choice) {
        selectedTech.clear();
        techKey.clear();
        techEffects.clear();

        if (!Gui::Lua::beginTableCallWithString(SELECT, choice.c_str())) {
            unitError = Gui::Lua::unavailableReason();
            return;
        }
        readDetails();
        Gui::Lua::endCall();
    }

    void changeTechLevel(int delta) {
        if (selectedTech.empty()) {
            return;
        }
        if (!Gui::Lua::beginTableCallWithStringAndNumber(CHANGE_LEVEL, selectedTech.c_str(), delta)) {
            unitError = Gui::Lua::unavailableReason();
            return;
        }
        readDetails();
        Gui::Lua::endCall();

        // The label carries the level, so the previous selection string is now stale.
        // Re-find it by key rather than by the old label.
        for (const std::string& label : techLabels) {
            if (label.find(techKey) != std::string::npos) {
                selectedTech = label;
                break;
            }
        }
        loadTechDetails(selectedTech);
    }

    void resetTechLevels() {
        if (!Gui::Lua::beginTableCall(RESET_LEVELS)) {
            unitError = Gui::Lua::unavailableReason();
            return;
        }
        readDetails();
        Gui::Lua::endCall();

        for (const std::string& label : techLabels) {
            if (!techKey.empty() && label.find(techKey) != std::string::npos) {
                selectedTech = label;
                break;
            }
        }
        loadTechDetails(selectedTech);
    }

    void loadList() {
        units.clear();
        listLoaded = false;

        if (!Gui::Lua::beginTableCall(COLLECT)) {
            listError = Gui::Lua::unavailableReason();
            return;
        }
        if (!Gui::Lua::boolField("available")) {
            listError = Gui::Lua::stringField("reason", "unavailable");
            Gui::Lua::endCall();
            return;
        }

        const int count = Gui::Lua::arrayLength("units");
        units.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            units.push_back(Gui::Lua::arrayStringAt("units", i));
        }

        Gui::Lua::endCall();
        listLoaded = true;
        listError.clear();
    }

    /**@brief read only multiline box, so the text stays selectable and copyable
       @param height pixels, or -FLT_MIN to fill the remaining height (0 would mean
              ImGui's default of 8 lines, which never grows with the pane)*/
    void drawTextBox(const char* id, const std::string& text, float height) {
        ImGui::InputTextMultiline(id,
            const_cast<char*>(text.c_str()), text.size() + 1,
            ImVec2(-FLT_MIN, height), ImGuiInputTextFlags_ReadOnly);
    }

    void drawTechSection() {
        ImGui::SeparatorText("Technologies");

        if (techLabels.empty()) {
            ImGui::TextDisabled("No technologies upgrade this unit.");
            return;
        }

        if (ImGui::SmallButton("-")) {
            changeTechLevel(-1);
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("+")) {
            changeTechLevel(1);
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("Reset all")) {
            resetTechLevels();
        }
        ImGui::SameLine();
        if (selectedTech.empty()) {
            ImGui::TextDisabled("select a tech to adjust");
        }
        else if (techLevel != techResearched) {
            // Highlighted so an assumed level is never mistaken for a real one.
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "%s: level %d (researched %d)", techKey.c_str(), techLevel, techResearched);
        }
        else {
            ImGui::TextDisabled("%s: level %d (researched)", techKey.c_str(), techLevel);
        }

        if (Gui::filteredList("techs", ImVec2(techListWidth, 0), techLabels,
            techFilter, sizeof(techFilter), selectedTech)) {
            loadTechDetails(selectedTech);
        }

        Gui::verticalSplitter("##techsplit", &techListWidth, 150.0f, 150.0f);

        ImGui::BeginChild("techeffects", ImVec2(0, 0));
        if (selectedTech.empty()) {
            ImGui::TextDisabled("Select a technology.");
        }
        else {
            if (!techApplied) {
                ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                    "Not researched. Showing level 1 for reference;\nit is not included in the stats above.");
            }
            drawTextBox("##techeffects", techEffects, -FLT_MIN);
        }
        ImGui::EndChild();
    }

    void drawUnits() {
        if (ImGui::Button("Reload")) {
            loadList();
            if (!selectedUnit.empty()) {
                selectUnit(selectedUnit);
            }
        }
        ImGui::SameLine();

        if (!listLoaded) {
            ImGui::TextDisabled("%s", listError.empty() ? "Loading..." : listError.c_str());
            // One automatic attempt; after that it is on the Reload button so a
            // failure doesn't re-parse the files every frame.
            if (!triedOnce) {
                triedOnce = true;
                loadList();
            }
            return;
        }

        ImGui::TextDisabled("%d units", static_cast<int>(units.size()));

        if (Gui::filteredList("list", ImVec2(listWidth, 0), units,
            unitFilter, sizeof(unitFilter), selectedUnit)) {
            selectUnit(selectedUnit);
        }

        Gui::verticalSplitter("##split", &listWidth);

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedUnit.empty()) {
            ImGui::TextDisabled("Select a unit.");
        }
        else if (!unitError.empty()) {
            ImGui::TextDisabled("%s", unitError.c_str());
        }
        else {
            ImGui::Text("%s", unitKey.c_str());

            // Selectable and copyable rather than a label: this string gets pasted
            // into event files to spawn a unit at these tech levels.
            ImGui::TextUnformatted("Model");
            ImGui::SameLine();
            ImGui::SetNextItemWidth(-60.0f);
            ImGui::InputText("##model",
                const_cast<char*>(unitModel.c_str()), unitModel.size() + 1,
                ImGuiInputTextFlags_ReadOnly);
            ImGui::SameLine();
            if (ImGui::Button("Copy")) {
                ImGui::SetClipboardText(unitModel.c_str());
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Copy the model string to the clipboard");
            }

            ImGui::Separator();

            ImGui::TextUnformatted("Stats with current tech levels");
            drawTextBox("##stats", unitStats, ImGui::GetContentRegionAvail().y * 0.45f);

            drawTechSection();
        }
        ImGui::EndChild();
    }

    class UnitsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Units"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 90; }
        void draw() override { drawUnits(); }
    };
}

REGISTER_GUI_PAGE(UnitsPage);
