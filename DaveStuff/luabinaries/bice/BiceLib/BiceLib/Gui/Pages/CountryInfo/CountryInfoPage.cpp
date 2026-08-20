// Country Info: the effective industry, research and combat values for the selected
// country, with technology contributions folded in.
//
// Live data, so it refreshes on a timer. The cost is a handful of Lua API reads plus
// a walk over the tech modifier table, which is cheap enough for a two second poll.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.CountryInfo.Collect";

    struct Row
    {
        std::string label;
        std::string value;
    };

    struct Section
    {
        std::string name;
        std::vector<Row> rows;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    std::vector<Section> sections;

    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }

        valid = true;
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        tag = Gui::Lua::stringField("tag");
        sections.clear();

        if (available) {
            const int sectionCount = Gui::Lua::arrayLength("sections");
            for (int s = 0; s < sectionCount; s++) {
                if (!Gui::Lua::pushArrayElement("sections", s)) {
                    continue;
                }

                Section section;
                section.name = Gui::Lua::stringField("name");

                // The field readers act on whatever table is on top of the stack, so
                // a section's rows can be read while the section itself is pushed.
                const int rowCount = Gui::Lua::arrayLength("rows");
                for (int r = 0; r < rowCount; r++) {
                    if (!Gui::Lua::pushArrayElement("rows", r)) {
                        continue;
                    }
                    Row row;
                    row.label = Gui::Lua::stringField("label");
                    row.value = Gui::Lua::stringField("value");
                    section.rows.push_back(row);
                    Gui::Lua::popArrayElement();
                }

                sections.push_back(section);
                Gui::Lua::popArrayElement();
            }
        }

        Gui::Lua::endCall();
    }

    void drawCountryInfo() {
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
        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return;
        }
        ImGui::TextDisabled("%s (%s)", tag.c_str(), Gui::Selection::source().c_str());

        for (const Section& section : sections) {
            ImGui::SeparatorText(section.name.c_str());

            if (!ImGui::BeginTable(section.name.c_str(), 2,
                ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInnerV |
                ImGuiTableFlags_SizingStretchProp)) {
                continue;
            }
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.62f);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.38f);

            for (const Row& row : section.rows) {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(row.label.c_str());
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(row.value.c_str());
            }
            ImGui::EndTable();
        }
    }

    class CountryInfoPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Country Modifiers"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 20; }
        void draw() override { drawCountryInfo(); }
    };
}

REGISTER_GUI_PAGE(CountryInfoPage);
