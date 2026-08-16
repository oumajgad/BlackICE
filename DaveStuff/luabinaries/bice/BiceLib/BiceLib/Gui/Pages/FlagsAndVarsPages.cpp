// Active Flags / Active Variables / Active Event Modifiers.
//
// Three pages in one file because they are the same widget over different data: a
// filterable, sortable list of rows for the selected country.
//
// No Lua involved. All three read country state straight out of BiceLib's own
// CCountry code - going out to Lua only to have Lua call back into this DLL would be
// a pointless round trip. The only thing that needs Lua is *which* country to report
// on, and Gui::Selection polls that centrally for every page.

#include <Gui/GuiPage.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>
#include <vector>

#include <imgui.h>

#include <GameClasses/CCountry.hpp>
#include <TextEncoding.hpp>
#include <HoiDataStructures.hpp>

namespace {
    struct Row
    {
        std::string name;
        std::string text;    // Second column when the page shows text
        double value = 0.0;
        bool hasValue = false;
    };

    enum class Source { Flags, Variables, EventModifiers };

    /** Per page state, so the three keep independent filters and refresh timers. */
    struct ListPage
    {
        Source source;
        const char* valueColumn;  // nullptr for a single column list

        bool available = false;
        std::string reason;
        std::string tag;
        std::vector<Row> rows;

        ULONGLONG lastSampleMs = 0;
        bool autoRefresh = true;
        char filter[64] = {};
    };

    void sortRowsByName(std::vector<Row>& rows) {
        std::sort(rows.begin(), rows.end(), [](const Row& a, const Row& b) {
            return _stricmp(a.name.c_str(), b.name.c_str()) < 0;
        });
    }

    void refresh(ListPage& page) {
        page.rows.clear();
        page.available = false;

        page.tag = Gui::Selection::tag();
        if (page.tag.empty()) {
            page.reason = Gui::Selection::reason();
            return;
        }

        const uintptr_t country = CCountry::findByTag(page.tag);
        if (country == 0) {
            page.reason = "No cached country for " + page.tag + " (run cacheCountries)";
            return;
        }

        switch (page.source) {
        case Source::Flags: {
            // getFlags allocates; we own it.
            std::vector<std::string>* flags = CCountry::getFlags(country);
            if (flags != nullptr) {
                for (const std::string& flag : *flags) {
                    Row row;
                    row.name = Text::toUtf8(flag);
                    page.rows.push_back(row);
                }
                delete flags;
            }
            break;
        }
        case Source::Variables: {
            std::vector<HDS::CVariable>* vars = CCountry::getVars(country);
            if (vars != nullptr) {
                for (const HDS::CVariable& variable : *vars) {
                    Row row;
                    row.name = Text::toUtf8(variable.name);
                    // Fixed point: the game stores 12.05 as 12050.
                    row.value = (variable.value != 0) ? variable.value / 1000.0 : 0.0;
                    row.hasValue = true;
                    page.rows.push_back(row);
                }
                delete vars;
            }
            break;
        }
        case Source::EventModifiers: {
            for (const auto& entry : CCountry::getActiveEventModifiers(country)) {
                Row row;
                row.name = Text::toUtf8(entry.first);
                row.text = Text::toUtf8(entry.second);
                page.rows.push_back(row);
            }
            break;
        }
        }

        sortRowsByName(page.rows);
        page.available = true;
    }

    bool matchesFilter(const std::string& haystack, const char* needle) {
        if (needle == nullptr || needle[0] == '\0') {
            return true;
        }
        const size_t length = strlen(needle);
        const auto it = std::search(haystack.begin(), haystack.end(), needle, needle + length,
            [](char a, char b) { return std::tolower(static_cast<unsigned char>(a)) ==
                                        std::tolower(static_cast<unsigned char>(b)); });
        return it != haystack.end();
    }

    void draw(ListPage& page) {
        if (ImGui::Button("Refresh")) {
            Gui::Selection::invalidate();
            Gui::Selection::refreshIfStale();
            refresh(page);
            page.lastSampleMs = GetTickCount64();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &page.autoRefresh);

        if (page.autoRefresh) {
            const ULONGLONG now = GetTickCount64();
            if (now - page.lastSampleMs >= 2000) {
                refresh(page);
                page.lastSampleMs = now;
            }
        }

        ImGui::SameLine();
        if (!page.available) {
            ImGui::TextDisabled("%s", page.reason.c_str());
            return;
        }
        ImGui::TextDisabled("%s (%s)", page.tag.c_str(), Gui::Selection::source().c_str());

        ImGui::SetNextItemWidth(-120.0f);
        ImGui::InputTextWithHint("##filter", "Filter", page.filter, sizeof(page.filter));
        ImGui::SameLine();

        int shown = 0;
        for (const Row& row : page.rows) {
            if (matchesFilter(row.name, page.filter)) {
                shown++;
            }
        }
        ImGui::TextDisabled("%d/%d", shown, static_cast<int>(page.rows.size()));

        const int columns = (page.valueColumn != nullptr) ? 2 : 1;
        const ImGuiTableFlags flags = ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner |
            ImGuiTableFlags_ScrollY | ImGuiTableFlags_SizingStretchProp;

        if (!ImGui::BeginTable("rows", columns, flags)) {
            return;
        }
        ImGui::TableSetupScrollFreeze(0, 1);
        ImGui::TableSetupColumn("Name", ImGuiTableColumnFlags_WidthStretch, 0.65f);
        if (page.valueColumn != nullptr) {
            ImGui::TableSetupColumn(page.valueColumn, ImGuiTableColumnFlags_WidthStretch, 0.35f);
        }
        ImGui::TableHeadersRow();

        for (const Row& row : page.rows) {
            if (!matchesFilter(row.name, page.filter)) {
                continue;
            }
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(row.name.c_str());

            if (page.valueColumn != nullptr) {
                ImGui::TableNextColumn();
                if (row.hasValue) {
                    ImGui::Text("%.0f", row.value);
                }
                else {
                    ImGui::TextUnformatted(row.text.c_str());
                }
            }
        }
        ImGui::EndTable();
    }

    ListPage flagsPage{ Source::Flags, nullptr };
    ListPage variablesPage{ Source::Variables, "Value" };
    ListPage modifiersPage{ Source::EventModifiers, "Expires" };

    class FlagsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Active Flags"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 20; }
        void draw() override { ::draw(flagsPage); }
    };

    class VariablesPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Active Variables"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 30; }
        void draw() override { ::draw(variablesPage); }
    };

    class EventModifiersPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Active Event Modifiers"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 40; }
        void draw() override { ::draw(modifiersPage); }
    };
}

REGISTER_GUI_PAGE(FlagsPage);
REGISTER_GUI_PAGE(VariablesPage);
REGISTER_GUI_PAGE(EventModifiersPage);
