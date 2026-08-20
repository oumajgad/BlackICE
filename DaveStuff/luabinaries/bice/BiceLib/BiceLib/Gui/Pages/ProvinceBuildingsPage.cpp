// Province Buildings: for a chosen building, every province the country controls that
// has it, and what the selected province produces.
//
// Unlike the rest of Game Info this is live game state rather than parsed files, so it
// has an explicit Refresh. Auto refresh is off by default: building the province list
// walks every controlled province and queries each one, which is far too much to do on
// a timer for a country with hundreds of them.

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
    const char* COLLECT = "BiceLibGui.ProvinceBuildings.Collect";
    const char* PROVINCES = "BiceLibGui.ProvinceBuildings.Provinces";
    const char* DETAILS = "BiceLibGui.ProvinceBuildings.Details";

    struct Province
    {
        std::string id;
        std::string name;
        int level = 0;
        bool occupied = false;
        std::string label;
    };

    struct Field
    {
        std::string label;
        std::string value;
    };

    std::vector<std::string> buildings;
    bool listLoaded = false;
    bool triedOnce = false;
    std::string listError;

    std::string selectedBuilding;
    std::vector<Province> provinces;
    std::vector<std::string> provinceLabels;
    std::string provinceError;

    std::string selectedProvince;
    std::string detailId;
    std::string detailError;
    std::vector<Field> detailValues;
    std::vector<Field> detailModifiers;

    // Level by default: the useful question is usually "where is this building
    // highest", not "what are these provinces called".
    int sortMode = 1; // 0 name, 1 level
    const char* const SORT_MODES[] = { "Name", "Level" };

    char buildingFilter[64] = {};
    char provinceFilter[64] = {};
    float buildingWidth = 220.0f;
    float provinceWidth = 260.0f;

    void rebuildProvinceLabels() {
        // Owned first, then occupied, each sorted by the chosen key. That grouping is
        // what makes the list useful: you build in what you own.
        std::stable_sort(provinces.begin(), provinces.end(),
            [](const Province& a, const Province& b) {
                if (a.occupied != b.occupied) {
                    return !a.occupied;
                }
                if (sortMode == 1 && a.level != b.level) {
                    return a.level > b.level;
                }
                return _stricmp(a.name.c_str(), b.name.c_str()) < 0;
            });

        provinceLabels.clear();
        provinceLabels.reserve(provinces.size());
        for (const Province& province : provinces) {
            provinceLabels.push_back(province.label);
        }
    }

    void loadDetails(const std::string& label) {
        detailId.clear();
        detailError.clear();
        detailValues.clear();
        detailModifiers.clear();

        // The label is "level - Name [id]"; the id is what Lua wants.
        const size_t open = label.find_last_of('[');
        const size_t close = label.find_last_of(']');
        if (open == std::string::npos || close == std::string::npos || close <= open + 1) {
            return;
        }
        const std::string id = label.substr(open + 1, close - open - 1);

        if (!Gui::Lua::beginTableCallWithString(DETAILS, id.c_str())) {
            detailError = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            detailId = Gui::Lua::stringField("id");

            const int valueCount = Gui::Lua::arrayLength("values");
            for (int i = 0; i < valueCount; i++) {
                if (!Gui::Lua::pushArrayElement("values", i)) {
                    continue;
                }
                Field field;
                field.label = Gui::Lua::stringField("label");
                field.value = Gui::Lua::stringField("value");
                detailValues.push_back(field);
                Gui::Lua::popArrayElement();
            }

            const int modifierCount = Gui::Lua::arrayLength("modifiers");
            for (int i = 0; i < modifierCount; i++) {
                if (!Gui::Lua::pushArrayElement("modifiers", i)) {
                    continue;
                }
                Field field;
                field.label = Gui::Lua::stringField("label");
                field.value = Gui::Lua::stringField("value");
                detailModifiers.push_back(field);
                Gui::Lua::popArrayElement();
            }
        }
        else {
            detailError = Gui::Lua::stringField("reason", "unavailable");
        }

        Gui::Lua::endCall();
    }

    void loadProvinces() {
        provinces.clear();
        provinceLabels.clear();
        provinceError.clear();

        if (selectedBuilding.empty()) {
            return;
        }

        if (!Gui::Lua::beginTableCallWithString(PROVINCES, selectedBuilding.c_str())) {
            provinceError = Gui::Lua::unavailableReason();
            return;
        }
        if (!Gui::Lua::boolField("available")) {
            provinceError = Gui::Lua::stringField("reason", "unavailable");
            Gui::Lua::endCall();
            return;
        }

        const int count = Gui::Lua::arrayLength("provinces");
        provinces.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("provinces", i)) {
                continue;
            }
            Province province;
            province.id = Gui::Lua::stringField("id");
            province.name = Gui::Lua::stringField("name");
            province.level = static_cast<int>(Gui::Lua::numberField("level"));
            province.occupied = Gui::Lua::boolField("occupied");

            char label[192];
            sprintf_s(label, "%d - %s%s [%s]", province.level, province.name.c_str(),
                province.occupied ? " (occupied)" : "", province.id.c_str());
            province.label = label;

            provinces.push_back(province);
            Gui::Lua::popArrayElement();
        }

        Gui::Lua::endCall();
        rebuildProvinceLabels();
    }

    void loadList() {
        buildings.clear();
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

        const int count = Gui::Lua::arrayLength("buildings");
        buildings.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            buildings.push_back(Gui::Lua::arrayStringAt("buildings", i));
        }

        Gui::Lua::endCall();
        listLoaded = true;
        listError.clear();
    }

    void drawFieldTable(const char* id, const std::vector<Field>& fields) {
        if (fields.empty()) {
            ImGui::TextDisabled("(none)");
            return;
        }
        if (!ImGui::BeginTable(id, 2, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInnerV |
            ImGuiTableFlags_SizingStretchProp)) {
            return;
        }
        ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.6f);
        ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.4f);

        for (const Field& field : fields) {
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(field.label.c_str());
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(field.value.c_str());
        }
        ImGui::EndTable();
    }

    void drawProvinceBuildings() {
        const std::string& tag = Gui::Selection::tag();

        if (ImGui::Button("Refresh")) {
            loadList();
            loadProvinces();
            if (!selectedProvince.empty()) {
                loadDetails(selectedProvince);
            }
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%s", tag.empty() ? "no country" : tag.c_str());
        ImGui::SameLine();
        ImGui::SetNextItemWidth(120.0f);
        if (Gui::wheelCombo("##sort", &sortMode, SORT_MODES, IM_ARRAYSIZE(SORT_MODES))) {
            rebuildProvinceLabels();
        }

        if (!listLoaded) {
            ImGui::TextDisabled("%s", listError.empty() ? "Loading..." : listError.c_str());
            if (!triedOnce) {
                triedOnce = true;
                loadList();
            }
            return;
        }

        if (Gui::filteredList("buildings", ImVec2(buildingWidth, 0), buildings,
            buildingFilter, sizeof(buildingFilter), selectedBuilding)) {
            selectedProvince.clear();
            detailValues.clear();
            detailModifiers.clear();
            loadProvinces();
        }

        Gui::verticalSplitter("##split1", &buildingWidth, 120.0f, 260.0f);

        ImGui::BeginChild("middle", ImVec2(provinceWidth, 0));
        if (selectedBuilding.empty()) {
            ImGui::TextDisabled("Select a building.");
        }
        else if (!provinceError.empty()) {
            ImGui::TextDisabled("%s", provinceError.c_str());
        }
        else {
            ImGui::TextDisabled("%d provinces", static_cast<int>(provinces.size()));
            if (Gui::filteredList("provinces", ImVec2(0, 0), provinceLabels,
                provinceFilter, sizeof(provinceFilter), selectedProvince)) {
                loadDetails(selectedProvince);
            }
        }
        ImGui::EndChild();

        Gui::verticalSplitter("##split2", &provinceWidth, 150.0f, 200.0f);

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedProvince.empty()) {
            ImGui::TextDisabled("Select a province.");
        }
        else if (!detailError.empty()) {
            ImGui::TextDisabled("%s", detailError.c_str());
        }
        else {
            ImGui::Text("Province %s", detailId.c_str());

            ImGui::SeparatorText("Base production");
            drawFieldTable("values", detailValues);

            ImGui::SeparatorText("Local modifiers");
            drawFieldTable("modifiers", detailModifiers);

            ImGui::Spacing();
            ImGui::TextWrapped("Base values only. These modifiers are local; national "
                "and global ones are not included here.");
        }
        ImGui::EndChild();
    }

    class ProvinceBuildingsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Province Buildings"; }
        const char* group() const override { return "Inspector"; }
        int order() const override { return 50; }
        void draw() override { drawProvinceBuildings(); }
    };
}

REGISTER_GUI_PAGE(ProvinceBuildingsPage);
