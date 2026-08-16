// Generals: every leader of the selected country, filterable by branch and name,
// with the leader's definition, live in-game location, and trait effects.
//
// Leader definitions are parsed from history/leaders once per session, so the list is
// fetched only when the country changes. Branch and name filtering happen here rather
// than in Lua, so typing in the filter costs nothing.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Generals.Collect";
    const char* DETAILS = "BiceLibGui.Generals.Details";
    const char* TRAIT_EFFECTS = "BiceLibGui.Traits.EffectsForKey";

    struct General
    {
        std::string id;
        std::string branch;  // "land" / "sea" / "air"
        std::string label;
    };

    std::vector<General> allGenerals;      // As returned for the current country
    std::vector<std::string> visibleLabels; // After the branch filter

    std::string loadedTag;
    std::string listError;
    bool listLoaded = false;

    int branchIndex = 0; // 0 all, 1 land, 2 sea, 3 air
    const char* const BRANCHES[] = { "All", "Land", "Sea", "Air" };
    const char* const BRANCH_KEYS[] = { "", "land", "sea", "air" };

    std::string selectedLabel;
    std::string detailId;
    std::string detailDump;
    std::string detailLocation;
    std::string detailLocationId;
    std::string detailUnitName;
    std::string detailError;
    std::vector<std::string> detailTraits;

    std::string selectedTrait;
    std::string traitEffects;

    char nameFilter[64] = {};
    char traitFilter[64] = {};

    void applyBranchFilter() {
        visibleLabels.clear();
        for (const General& general : allGenerals) {
            if (branchIndex == 0 || general.branch == BRANCH_KEYS[branchIndex]) {
                visibleLabels.push_back(general.label);
            }
        }
    }

    const General* findByLabel(const std::string& label) {
        for (const General& general : allGenerals) {
            if (general.label == label) {
                return &general;
            }
        }
        return nullptr;
    }

    void loadTraitEffects(const std::string& traitChoice) {
        traitEffects.clear();
        if (traitChoice.empty()) {
            return;
        }

        // "Translated name [key]" -> key
        const size_t open = traitChoice.find_last_of('[');
        const size_t close = traitChoice.find_last_of(']');
        if (open == std::string::npos || close == std::string::npos || close <= open + 1) {
            return;
        }
        const std::string key = traitChoice.substr(open + 1, close - open - 1);

        if (!Gui::Lua::beginTableCallWithString(TRAIT_EFFECTS, key.c_str())) {
            traitEffects = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            traitEffects = Gui::Lua::stringField("effects");
        }
        else {
            traitEffects = Gui::Lua::stringField("reason", "unavailable");
        }
        Gui::Lua::endCall();
    }

    void loadDetails(const std::string& label) {
        detailId.clear();
        detailDump.clear();
        detailLocation.clear();
        detailLocationId.clear();
        detailUnitName.clear();
        detailTraits.clear();
        detailError.clear();
        selectedTrait.clear();
        traitEffects.clear();

        const General* general = findByLabel(label);
        if (general == nullptr) {
            return;
        }

        if (!Gui::Lua::beginTableCallWithString(DETAILS, general->id.c_str())) {
            detailError = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            detailId = Gui::Lua::stringField("id");
            detailDump = Gui::Lua::stringField("dump");
            detailLocation = Gui::Lua::stringField("location");
            detailLocationId = Gui::Lua::stringField("location_id");
            detailUnitName = Gui::Lua::stringField("unit_name");

            const int count = Gui::Lua::arrayLength("traits");
            for (int i = 0; i < count; i++) {
                detailTraits.push_back(Gui::Lua::arrayStringAt("traits", i));
            }
        }
        else {
            detailError = Gui::Lua::stringField("reason", "unavailable");
        }

        Gui::Lua::endCall();
    }

    void loadList(const std::string& tag) {
        allGenerals.clear();
        visibleLabels.clear();
        selectedLabel.clear();
        listLoaded = false;
        loadedTag = tag;

        if (tag.empty()) {
            listError = Gui::Selection::reason();
            return;
        }

        if (!Gui::Lua::beginTableCallWithString(COLLECT, tag.c_str())) {
            listError = Gui::Lua::unavailableReason();
            return;
        }

        if (!Gui::Lua::boolField("available")) {
            listError = Gui::Lua::stringField("reason", "unavailable");
            Gui::Lua::endCall();
            return;
        }

        const int count = Gui::Lua::arrayLength("generals");
        allGenerals.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("generals", i)) {
                continue;
            }
            General general;
            general.id = Gui::Lua::stringField("id");
            general.branch = Gui::Lua::stringField("branch");
            general.label = Gui::Lua::stringField("label");
            allGenerals.push_back(general);
            Gui::Lua::popArrayElement();
        }

        Gui::Lua::endCall();
        applyBranchFilter();
        listLoaded = true;
        listError.clear();
    }

    /**
    @brief read only multiline box, so the text stays selectable and copyable
    @param height pixels, or -FLT_MIN to fill the remaining height. Note 0 would mean
           ImGui's default height of 8 lines, not "fill", so it never grows with the pane.
    */
    void drawTextBox(const char* id, const std::string& text, float height) {
        ImGui::InputTextMultiline(id,
            const_cast<char*>(text.c_str()), text.size() + 1,
            ImVec2(-FLT_MIN, height), ImGuiInputTextFlags_ReadOnly);
    }

    void drawGenerals() {
        const std::string& tag = Gui::Selection::tag();

        // The country is owned by the Setup page, so reload when it changes.
        if (tag != loadedTag) {
            loadList(tag);
        }

        if (ImGui::Button("Reload")) {
            loadList(tag);
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%s", tag.empty() ? "no country" : tag.c_str());

        ImGui::SameLine();
        ImGui::SetNextItemWidth(160.0f);
        if (ImGui::Combo("##branch", &branchIndex, BRANCHES, IM_ARRAYSIZE(BRANCHES))) {
            applyBranchFilter();
        }

        if (!listLoaded) {
            ImGui::TextDisabled("%s", listError.empty() ? "No generals loaded." : listError.c_str());
            return;
        }

        ImGui::TextDisabled("%d of %d generals",
            static_cast<int>(visibleLabels.size()), static_cast<int>(allGenerals.size()));

        if (Gui::filteredList("list", ImVec2(420.0f, 0), visibleLabels,
            nameFilter, sizeof(nameFilter), selectedLabel)) {
            loadDetails(selectedLabel);
        }

        ImGui::SameLine();

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedLabel.empty()) {
            ImGui::TextDisabled("Select a general.");
        }
        else if (!detailError.empty()) {
            ImGui::TextDisabled("%s", detailError.c_str());
        }
        else {
            ImGui::SeparatorText("In game");
            ImGui::Text("Location: %s (%s)", detailLocation.c_str(), detailLocationId.c_str());
            ImGui::Text("Unit:     %s", detailUnitName.c_str());

            ImGui::SeparatorText("Definition");
            drawTextBox("##dump", detailDump, ImGui::GetContentRegionAvail().y * 0.4f);

            ImGui::SeparatorText("Traits");
            if (detailTraits.empty()) {
                ImGui::TextDisabled("No traits.");
            }
            else {
                if (Gui::filteredList("traits", ImVec2(240.0f, 0), detailTraits,
                    traitFilter, sizeof(traitFilter), selectedTrait)) {
                    loadTraitEffects(selectedTrait);
                }
                ImGui::SameLine();
                drawTextBox("##traiteffects",
                    traitEffects.empty() ? std::string("Select a trait.") : traitEffects, -FLT_MIN);
            }
        }
        ImGui::EndChild();
    }

    class GeneralsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Generals"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 60; }
        void draw() override { drawGenerals(); }
    };
}

REGISTER_GUI_PAGE(GeneralsPage);
