// The three help pages.
//
// Two of them are the mod's own text, which lives in BiceData.Help rather than here so
// it can be corrected without a rebuild. The third is the national focus table, built
// from the mod's triggered modifiers - the same data the National Focus page uses for
// its Effect column, fetched through one call for both.
//
// All of it is static once the mod's files are parsed, so each page fetches once and
// then draws from what it has.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>

#include <Windows.h>
#include <map>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* SECTION = "BiceLibGui.Help.Section";
    const char* EFFECTS = "BiceLibGui.NatFocus.Effects";

    struct Entry
    {
        std::string kind;
        std::string text;

        // "card" entries only: a building, the focus that speeds it up, and the
        // ministers that bring it.
        std::string title;
        std::string subtitle;
        std::vector<std::string> lines;
    };

    /**
     * One page's worth of text, fetched on first draw.
     *
     * Held per section rather than in one shared block so opening one help page does
     * not pay for the others.
     */
    struct Section
    {
        std::vector<Entry> entries;
        bool loaded = false;
        std::string error;

        void load(const char* name) {
            if (!Gui::Lua::beginTableCallWithString(SECTION, name)) {
                error = Gui::Lua::unavailableReason();
                return;
            }

            entries.clear();
            const int count = Gui::Lua::arrayLength("entries");
            entries.reserve(static_cast<size_t>(count));
            for (int i = 0; i < count; i++) {
                if (!Gui::Lua::pushArrayElement("entries", i)) {
                    continue;
                }
                Entry entry;
                entry.kind = Gui::Lua::stringField("kind");
                entry.text = Gui::Lua::stringField("text");

                if (entry.kind == "card") {
                    entry.title = Gui::Lua::stringField("title");
                    entry.subtitle = Gui::Lua::stringField("subtitle");
                    const int lineCount = Gui::Lua::arrayLength("lines");
                    for (int line = 0; line < lineCount; line++) {
                        entry.lines.push_back(Gui::Lua::arrayStringAt("lines", line));
                    }
                }

                entries.push_back(entry);
                Gui::Lua::popArrayElement();
            }

            Gui::Lua::endCall();
            loaded = true;
            error.clear();
        }

        void draw(const char* name) {
            if (!loaded) {
                load(name);
                if (!loaded) {
                    ImGui::TextDisabled("%s", error.empty() ? "Loading..." : error.c_str());
                    return;
                }
            }

            // Cards are gathered into one table rather than drawn where they fall: the
            // wx page put them in a grid, and a run of them read as a table already.
            bool inTable = false;

            for (const Entry& entry : entries) {
                if (entry.kind != "card" && inTable) {
                    ImGui::EndTable();
                    inTable = false;
                    ImGui::Spacing();
                }

                if (entry.kind == "card") {
                    if (!inTable) {
                        if (!ImGui::BeginTable("cards", 3, ImGuiTableFlags_RowBg |
                            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
                            continue;
                        }
                        inTable = true;
                        ImGui::TableSetupColumn("Building", ImGuiTableColumnFlags_WidthStretch, 0.8f);
                        ImGui::TableSetupColumn("Focus", ImGuiTableColumnFlags_WidthStretch, 0.7f);
                        ImGui::TableSetupColumn("Ministers", ImGuiTableColumnFlags_WidthStretch, 1.5f);
                        ImGui::TableHeadersRow();
                    }

                    ImGui::TableNextRow();
                    ImGui::TableNextColumn();
                    ImGui::TextUnformatted(entry.title.c_str());
                    ImGui::TableNextColumn();
                    ImGui::TextDisabled("%s", entry.subtitle.c_str());
                    ImGui::TableNextColumn();
                    for (const std::string& line : entry.lines) {
                        ImGui::TextUnformatted(line.c_str());
                    }
                }
                else if (entry.kind == "heading") {
                    // Some of these are a whole sentence in bold rather than a title,
                    // and a separator through the middle of one looks like a mistake.
                    if (entry.text.size() > 60) {
                        ImGui::Spacing();
                        ImGui::TextWrapped("%s", entry.text.c_str());
                    }
                    else {
                        ImGui::SeparatorText(entry.text.c_str());
                    }
                }
                else if (entry.kind == "item") {
                    ImGui::Bullet();
                    ImGui::TextWrapped("%s", entry.text.c_str());
                }
                else {
                    ImGui::TextWrapped("%s", entry.text.c_str());
                    ImGui::Spacing();
                }
            }

            if (inTable) {
                ImGui::EndTable();
            }
        }
    };

    Section miscSection;
    Section ministerSection;

    // Focus name -> effects at tier 1, 2, 3.
    struct FocusEffects
    {
        std::string name;
        std::vector<std::string> tiers[3];
    };

    std::vector<FocusEffects> focuses;
    std::vector<std::string> tierLabels;
    bool focusesLoaded = false;
    std::string focusError;

    void loadFocuses() {
        if (!Gui::Lua::beginTableCall(EFFECTS)) {
            focusError = Gui::Lua::unavailableReason();
            return;
        }

        focuses.clear();
        tierLabels.clear();

        const int labelCount = Gui::Lua::arrayLength("tierLabels");
        for (int i = 0; i < labelCount; i++) {
            tierLabels.push_back(Gui::Lua::arrayStringAt("tierLabels", i));
        }

        const int count = Gui::Lua::arrayLength("rows");
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("rows", i)) {
                continue;
            }
            const std::string name = Gui::Lua::stringField("name");
            const int tier = static_cast<int>(Gui::Lua::numberField("tier"));
            const std::string label = Gui::Lua::stringField("label");
            const std::string value = Gui::Lua::stringField("value");
            Gui::Lua::popArrayElement();

            if (tier < 1 || tier > 3) {
                continue;
            }

            // The rows arrive grouped by focus, so the last one is nearly always the
            // right one; only a new focus appends.
            if (focuses.empty() || focuses.back().name != name) {
                FocusEffects entry;
                entry.name = name;
                focuses.push_back(entry);
            }
            focuses.back().tiers[tier - 1].push_back(label + "  " + value);
        }

        Gui::Lua::endCall();
        focusesLoaded = true;
        focusError.clear();
    }

    void drawFocusHelp() {
        if (!focusesLoaded) {
            if (ImGui::Button("Load")) {
                loadFocuses();
            }
            ImGui::SameLine();
            ImGui::TextDisabled("%s", focusError.empty()
                ? "Reads the mod's modifier files, which takes a moment."
                : focusError.c_str());
            if (!focusesLoaded) {
                return;
            }
        }

        ImGui::TextWrapped("What each national focus gives once it has been active long "
            "enough. A tier includes everything from the tiers before it only where the "
            "mod repeats it, so read each column on its own.");
        ImGui::Spacing();

        if (!ImGui::BeginTable("focuses", 4, ImGuiTableFlags_RowBg | ImGuiTableFlags_Borders |
            ImGuiTableFlags_SizingStretchProp | ImGuiTableFlags_ScrollY)) {
            return;
        }

        ImGui::TableSetupColumn("Focus", ImGuiTableColumnFlags_WidthStretch, 0.7f);
        for (int tier = 0; tier < 3; tier++) {
            char header[64];
            sprintf_s(header, "Level %s (%s)", (tier == 0) ? "I" : (tier == 1) ? "II" : "III",
                (static_cast<size_t>(tier) < tierLabels.size()) ? tierLabels[tier].c_str() : "");
            ImGui::TableSetupColumn(header, ImGuiTableColumnFlags_WidthStretch, 1.0f);
        }
        ImGui::TableSetupScrollFreeze(1, 1);
        ImGui::TableHeadersRow();

        for (const FocusEffects& focus : focuses) {
            ImGui::TableNextRow();

            ImGui::TableNextColumn();
            ImGui::TextUnformatted(focus.name.c_str());

            for (int tier = 0; tier < 3; tier++) {
                ImGui::TableNextColumn();
                if (focus.tiers[tier].empty()) {
                    ImGui::TextDisabled("-");
                    continue;
                }
                for (const std::string& effect : focus.tiers[tier]) {
                    ImGui::TextUnformatted(effect.c_str());
                }
            }
        }
        ImGui::EndTable();
    }

    class HelpMiscPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Misc"; }
        const char* group() const override { return "Help"; }
        int order() const override { return 10; }
        void draw() override { miscSection.draw("misc"); }
    };

    class HelpMinistersPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Ministers + Buildings"; }
        const char* group() const override { return "Help"; }
        int order() const override { return 20; }
        void draw() override { ministerSection.draw("ministers"); }
    };

    class HelpNatFocusPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "National Focus"; }
        const char* group() const override { return "Help"; }
        int order() const override { return 30; }
        void draw() override { drawFocusHelp(); }
    };
}

REGISTER_GUI_PAGE(HelpMiscPage);
REGISTER_GUI_PAGE(HelpMinistersPage);
REGISTER_GUI_PAGE(HelpNatFocusPage);
