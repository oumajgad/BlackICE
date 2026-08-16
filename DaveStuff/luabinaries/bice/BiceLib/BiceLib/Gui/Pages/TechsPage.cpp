// Techs: every technology, its effects scaled to a chosen level, and its research
// requirements.
//
// Unlike Traits and Modifiers, the details depend on more than the selection: tech
// effects are per level values, so the level being shown is part of the request. It
// defaults to the player's researched level (or 1 when they have none) and is
// re-fetched whenever either the selection or the level changes.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Techs.Collect";
    const char* DETAILS = "BiceLibGui.Techs.Details";

    std::vector<std::string> techs;
    bool listLoaded = false;
    bool triedOnce = false;
    std::string listError;

    std::string selectedChoice;
    std::string detailKey;
    std::string detailEffects;
    std::string detailRequirements;
    std::string detailError;
    int playerLevel = 0;
    int shownLevel = 0;

    char filter[64] = {};
    float listWidth = 300.0f; // Drag the divider to change

    void loadList() {
        techs.clear();
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

        const int count = Gui::Lua::arrayLength("techs");
        techs.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            techs.push_back(Gui::Lua::arrayStringAt("techs", i));
        }

        Gui::Lua::endCall();
        listLoaded = true;
        listError.clear();
    }

    /**
    @brief fetches details at \p level
    @param level 0 asks Lua to pick: the player's researched level, or 1 if none.
           Lua reports back which it chose, so the control always shows the truth.
    */
    void loadDetails(const std::string& choice, int level) {
        detailKey.clear();
        detailEffects.clear();
        detailRequirements.clear();
        detailError.clear();

        if (!Gui::Lua::beginTableCallWithStringAndNumber(DETAILS, choice.c_str(), level)) {
            detailError = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            detailKey = Gui::Lua::stringField("key");
            playerLevel = static_cast<int>(Gui::Lua::numberField("player_level"));
            shownLevel = static_cast<int>(Gui::Lua::numberField("shown_level"));
            detailEffects = Gui::Lua::stringField("effects");
            detailRequirements = Gui::Lua::stringField("requirements");
        }
        else {
            detailError = Gui::Lua::stringField("reason", "unavailable");
        }

        Gui::Lua::endCall();
    }

    /**@brief read only multiline box, so the text stays selectable and copyable
       @param height pixels, or -FLT_MIN to fill the remaining height (0 would mean
              ImGui's default of 8 lines, which never grows with the pane)*/
    void drawTextBox(const char* id, const std::string& text, float height) {
        ImGui::InputTextMultiline(id,
            const_cast<char*>(text.c_str()), text.size() + 1,
            ImVec2(-FLT_MIN, height), ImGuiInputTextFlags_ReadOnly);
    }

    void drawLevelControls() {
        ImGui::Text("Level %d", shownLevel);
        ImGui::SameLine();

        if (ImGui::SmallButton("-") && shownLevel > 1) {
            loadDetails(selectedChoice, shownLevel - 1);
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("+")) {
            loadDetails(selectedChoice, shownLevel + 1);
        }

        ImGui::SameLine();
        if (playerLevel > 0) {
            ImGui::TextDisabled("| researched: %d", playerLevel);
            ImGui::SameLine();
            if (ImGui::SmallButton("Reset") && shownLevel != playerLevel) {
                loadDetails(selectedChoice, playerLevel);
            }
        }
        else {
            ImGui::TextDisabled("| not researched");
        }
    }

    void drawTechs() {
        if (ImGui::Button("Reload")) {
            loadList();
            if (!selectedChoice.empty()) {
                loadDetails(selectedChoice, shownLevel);
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

        ImGui::TextDisabled("%d technologies", static_cast<int>(techs.size()));

        if (Gui::filteredList("list", ImVec2(listWidth, 0), techs,
            filter, sizeof(filter), selectedChoice)) {
            // 0: let Lua default the level to whatever the player has researched.
            loadDetails(selectedChoice, 0);
        }

        Gui::verticalSplitter("##split", &listWidth);

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedChoice.empty()) {
            ImGui::TextDisabled("Select a technology.");
        }
        else if (!detailError.empty()) {
            ImGui::TextDisabled("%s", detailError.c_str());
        }
        else {
            ImGui::Text("%s", detailKey.c_str());
            drawLevelControls();
            ImGui::Separator();

            const float half = ImGui::GetContentRegionAvail().y * 0.55f - ImGui::GetTextLineHeightWithSpacing();

            ImGui::TextUnformatted("Effects at this level");
            drawTextBox("##effects", detailEffects, half);

            ImGui::TextUnformatted("Requirements");
            drawTextBox("##requirements",
                detailRequirements.empty() ? std::string("(none)") : detailRequirements, -FLT_MIN);
        }
        ImGui::EndChild();
    }

    class TechsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Techs"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 80; }
        void draw() override { drawTechs(); }
    };
}

REGISTER_GUI_PAGE(TechsPage);
