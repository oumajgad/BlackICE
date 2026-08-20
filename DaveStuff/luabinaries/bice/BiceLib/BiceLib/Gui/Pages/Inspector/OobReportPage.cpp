// OOB Report: the same order of battle as the browser, counted rather than walked.
//
// The browser answers "what is in this corps"; this answers "what does this country
// have, and where is it". Both read the tree themselves rather than sharing one, so
// neither can leave the other holding a stale read - the cost is one extra pass over
// the units when both are open, and only when refreshed.

#include <Gui/GuiPage.hpp>
#include <Gui/CountrySelection.hpp>
#include <Oob/OrderOfBattle.hpp>

#include <GameClasses/CCountry.hpp>

#include <Windows.h>
#include <algorithm>
#include <cstdio>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    Oob::Tree tree;
    std::string readTag;
    bool read = false;

    struct LevelRow
    {
        std::string kind;
        int rank = 0;
        int count = 0;
        int regiments = 0;
    };
    std::vector<LevelRow> levels;

    /**
    @brief where a kind belongs in the list: down the land chain, then air, then sea

    Ranked rather than sorted by name, because the useful order is the chain of
    command - theatre down to division - and alphabetically that comes out as army,
    army group, corps, division, theatre, which tells a reader nothing.
    */
    int rankOf(Oob::Branch branch, int level) {
        switch (branch) {
        case Oob::Branch::Land:
            return (level >= 0 && level <= 9) ? level : 9;
        case Oob::Branch::Air:
            return 10;
        case Oob::Branch::Naval:
            return 11;
        default:
            return 20;
        }
    }

    void rebuildLevels() {
        levels.clear();
        for (size_t i = 0; i < tree.units.size(); i++) {
            const Oob::Unit& unit = tree.units[i];
            const std::string kind =
                std::string(Oob::branchName(unit.branch)) + " " +
                Oob::levelName(unit.level, unit.branch);

            LevelRow* row = nullptr;
            for (size_t r = 0; r < levels.size(); r++) {
                if (levels[r].kind == kind) {
                    row = &levels[r];
                    break;
                }
            }
            if (row == nullptr) {
                levels.push_back(LevelRow());
                row = &levels.back();
                row->kind = kind;
                row->rank = rankOf(unit.branch, unit.level);
            }
            row->count++;
            row->regiments += unit.regimentCount;
        }

        std::sort(levels.begin(), levels.end(),
            [](const LevelRow& a, const LevelRow& b) {
                if (a.rank != b.rank) {
                    return a.rank < b.rank;
                }
                return a.kind < b.kind;
            });
    }

    void refresh() {
        const std::string& tag = Gui::Selection::tag();
        readTag = tag;
        read = true;

        if (tag.empty()) {
            tree = Oob::Tree();
            tree.reason = Gui::Selection::reason();
            levels.clear();
            return;
        }

        tree = Oob::read(CCountry::findByTag(tag));
        rebuildLevels();
    }

    /**@brief the whole report as plain text, for pasting somewhere it can be kept*/
    std::string asText() {
        std::string out;
        char line[256];

        sprintf_s(line, "Order of battle - %s\r\n\r\n", readTag.c_str());
        out += line;

        sprintf_s(line, "%d units: %d land, %d air, %d naval\r\n",
            static_cast<int>(tree.units.size()), tree.landTotal, tree.airTotal,
            tree.navalTotal);
        out += line;
        sprintf_s(line, "%d regiments in %d formations that report to nobody\r\n",
            tree.regimentTotal, static_cast<int>(tree.roots.size()));
        out += line;
        sprintf_s(line, "%d units without a commander\r\n\r\n", tree.leaderlessTotal);
        out += line;

        out += "By kind\r\n";
        for (size_t i = 0; i < levels.size(); i++) {
            sprintf_s(line, "  %-24s %5d units, %5d regiments\r\n",
                levels[i].kind.c_str(), levels[i].count, levels[i].regiments);
            out += line;
        }

        out += "\r\nTop level formations\r\n";
        for (size_t i = 0; i < tree.roots.size(); i++) {
            const Oob::Unit& unit = tree.units[tree.roots[i]];
            sprintf_s(line, "  %-40s %4d land %4d air %4d naval %5d regiments\r\n",
                unit.name.empty() ? "(unnamed)" : unit.name.c_str(),
                unit.landBelow, unit.airBelow, unit.navalBelow,
                unit.regimentsBelow + unit.regimentCount);
            out += line;
        }
        return out;
    }

    void drawOobReport() {
        if (ImGui::Button("Refresh")) {
            refresh();
        }
        if (readTag != Gui::Selection::tag()) {
            refresh();
        }

        ImGui::SameLine();
        ImGui::TextDisabled("%s (%s)", Gui::Selection::tag().c_str(),
            Gui::Selection::source().c_str());

        if (!read) {
            ImGui::TextDisabled("Press Refresh to read the order of battle.");
            return;
        }
        if (!tree.available) {
            ImGui::TextDisabled("%s", tree.reason.c_str());
            return;
        }

        ImGui::SameLine();
        if (ImGui::Button("Copy")) {
            ImGui::SetClipboardText(asText().c_str());
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Puts the whole report on the clipboard as text");
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Totals");
        ImGui::Text("%d units: %d land, %d air, %d naval",
            static_cast<int>(tree.units.size()), tree.landTotal, tree.airTotal,
            tree.navalTotal);
        ImGui::Text("%d regiments across %d formations that report to nobody",
            tree.regimentTotal, static_cast<int>(tree.roots.size()));

        // Red when there are any, plain white when there are none: nothing missing is
        // good news and should not look like a warning.
        ImGui::TextColored(tree.leaderlessTotal > 0
            ? ImVec4(0.85f, 0.35f, 0.35f, 1.0f)
            : ImVec4(1.0f, 1.0f, 1.0f, 1.0f),
            "%d units without a commander", tree.leaderlessTotal);

        ImGui::Spacing();
        ImGui::SeparatorText("By kind");
        if (ImGui::BeginTable("byKind", 3, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("Kind", ImGuiTableColumnFlags_WidthStretch, 1.4f);
            ImGui::TableSetupColumn("Units", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupColumn("Regiments", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            ImGui::TableHeadersRow();

            for (size_t i = 0; i < levels.size(); i++) {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(levels[i].kind.c_str());
                ImGui::TableNextColumn();
                ImGui::Text("%d", levels[i].count);
                ImGui::TableNextColumn();
                if (levels[i].regiments > 0) {
                    ImGui::Text("%d", levels[i].regiments);
                }
                else {
                    ImGui::TextDisabled("-");
                }
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Top level formations");
        // The rest of the page, less the note underneath. The by-kind table above is
        // left to size itself: it has one row per kind and never needs to scroll, so
        // giving the spare height to this one is what a taller window is for.
        const float footer = ImGui::GetTextLineHeightWithSpacing() * 3.0f;
        const float left = ImGui::GetContentRegionAvail().y - footer;
        const float formationHeight = (left > 140.0f) ? left : 140.0f;

        if (ImGui::BeginTable("formations", 5, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp |
            ImGuiTableFlags_ScrollY, ImVec2(0.0f, formationHeight))) {
            ImGui::TableSetupColumn("Formation", ImGuiTableColumnFlags_WidthStretch, 1.8f);
            ImGui::TableSetupColumn("Land", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Air", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Naval", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Regiments", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            ImGui::TableHeadersRow();

            for (size_t i = 0; i < tree.roots.size(); i++) {
                const Oob::Unit& unit = tree.units[tree.roots[i]];
                ImGui::TableNextRow();

                ImGui::TableNextColumn();
                ImGui::TextUnformatted(unit.name.empty() ? "(unnamed)" : unit.name.c_str());
                if (ImGui::IsItemHovered()) {
                    ImGui::SetTooltip("%s %s", Oob::branchName(unit.branch),
                        Oob::levelName(unit.level, unit.branch));
                }
                ImGui::TableNextColumn();
                ImGui::Text("%d", unit.landBelow);
                ImGui::TableNextColumn();
                ImGui::Text("%d", unit.airBelow);
                ImGui::TableNextColumn();
                ImGui::Text("%d", unit.navalBelow);
                ImGui::TableNextColumn();
                ImGui::Text("%d", unit.regimentsBelow + unit.regimentCount);
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::TextWrapped("Counts below a formation exclude the formation itself, so a "
            "theatre's land count is the units under its command rather than a count "
            "that includes it.");
    }

    class OobReportPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "OOB Report"; }
        const char* group() const override { return "Inspector"; }
        int order() const override { return 16; }
        void draw() override { drawOobReport(); }
    };
}

REGISTER_GUI_PAGE(OobReportPage);
