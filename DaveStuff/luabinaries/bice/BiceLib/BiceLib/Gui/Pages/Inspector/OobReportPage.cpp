// OOB Report: the same order of battle as the browser, counted rather than walked.
//
// The browser answers "what is in this corps"; this answers "what does this country
// have, and where is it". Both read the tree themselves rather than sharing one, so
// neither can leave the other holding a stale read - the cost is one extra pass over
// the units when both are open, and only when refreshed.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/CountrySelection.hpp>
#include <Gui/LuaBridge.hpp>
#include <GameState/OrderOfBattle.hpp>

#include <GameClasses/CCountry.hpp>

#include <Windows.h>
#include <algorithm>
#include <cstdio>
#include <map>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    Oob::Tree tree;
    std::string readTag;
    bool read = false;
    bool autoRefresh = false;
    ULONGLONG lastReadMs = 0;

    struct LevelRow
    {
        std::string kind;
        int rank = 0;
        int count = 0;
        int regiments = 0;
    };
    std::vector<LevelRow> levels;

    const char* TYPE_NAMES = "BiceLibGui.Oob.TypeNames";

    /**@brief one kind of regiment, brigade or ship, and how many the country has*/
    struct TypeRow
    {
        // The key exactly as the mod's files spell it - "artillery_brigade".
        std::string type;

        // "Artillery [artillery_brigade]", or the key on its own where the
        // localisation has no name for it. Both, because the two answer different
        // questions: the name is what the game calls it, and the key is what to
        // search the mod's files for.
        std::string display;

        Oob::Branch branch = Oob::Branch::Unknown;
        int count = 0;
    };
    std::vector<TypeRow> types;

    // key -> what the localisation calls it, empty for a key it has no name for.
    // Kept for as long as the game runs: localisation is read from files at startup
    // and cannot change afterwards, so a key asked about once is never asked about
    // again - which also means looking at a second country only costs a call for the
    // kinds of regiment the first one did not have.
    std::map<std::string, std::string> typeNames;

    // Which branch the By type table is showing, and nothing else on the page. It
    // sits under that table's own heading so its reach is obvious from the layout:
    // a filter above everything would look like it changed everything.
    const char* const BRANCH_FILTERS[] = { "All", "Land", "Air", "Naval" };
    const Oob::Branch BRANCH_FILTER_OF[] = {
        Oob::Branch::Unknown, Oob::Branch::Land, Oob::Branch::Air, Oob::Branch::Naval,
    };
    const int BRANCH_FILTER_COUNT = 4;
    int branchFilter = 0;

    /**@brief whether a row survives the filter; Unknown as the filter means all of them*/
    bool passesFilter(Oob::Branch branch) {
        const Oob::Branch wanted = BRANCH_FILTER_OF[branchFilter];
        return wanted == Oob::Branch::Unknown || branch == wanted;
    }


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

    /**
    @brief counts the country's regiments by what kind of regiment they are

    The one part of the report that the tree does not already hold. Oob::read walks
    units and takes each one's regiment *count* from a field, never the regiments
    themselves - a country has thousands of them, and the browser only ever needs the
    handful inside the unit somebody clicked on.

    So this walks them, once per refresh, which is why refreshing is a button and not
    a timer. A regiment's own name is historical and unique to it; the type comes from
    the definition it points at. Its branch comes from the unit holding it, because a
    regiment does not know its own.
    */
    void rebuildTypes() {
        types.clear();

        for (size_t i = 0; i < tree.units.size(); i++) {
            const Oob::Unit& unit = tree.units[i];
            if (unit.regimentCount <= 0) {
                continue; // every level above division holds none
            }

            const std::vector<Oob::Regiment> held = Oob::regiments(unit.address);
            for (size_t r = 0; r < held.size(); r++) {
                const std::string& key = held[r].type;
                if (key.empty()) {
                    continue; // a definition that could not be read names no type
                }

                // Keyed by branch as well as by name. No type is expected to appear
                // in two branches, and if one ever does it is worth seeing as two
                // rows rather than being quietly added together.
                TypeRow* row = nullptr;
                for (size_t t = 0; t < types.size(); t++) {
                    if (types[t].type == key && types[t].branch == unit.branch) {
                        row = &types[t];
                        break;
                    }
                }
                if (row == nullptr) {
                    types.push_back(TypeRow());
                    row = &types.back();
                    row->type = key;
                    row->branch = unit.branch;
                }
                row->count++;
            }
        }

        // Most numerous first, which is the question the table exists to answer.
        std::sort(types.begin(), types.end(),
            [](const TypeRow& a, const TypeRow& b) {
                if (a.count != b.count) {
                    return a.count > b.count;
                }
                return a.type < b.type;
            });
    }

    /**
    @brief asks Lua what the localisation calls each kind, and builds the labels

    The one thing on this page that does not come out of memory. A type's name is
    localisation, which the game reads from the mod's csv files and which nothing in
    the order of battle knows about; BiceData.Translations already holds every one of
    those files merged into a key to text map, so this asks rather than parsing them
    again.

    In one call for the whole set rather than one per kind. The keys are known by the
    time this runs, a country fields a few dozen of them, and one call costs what one
    call costs whatever is in it.

    Safe from here: this runs from refresh(), which happens inside the page's own draw
    - the render thread, with a game running, which is what Gui::Lua requires. A call
    that cannot be made leaves every row showing its key, which is what the page
    showed before it had names at all.
    */
    void resolveTypeNames() {
        std::vector<std::string> asked;
        std::string joined;

        for (size_t i = 0; i < types.size(); i++) {
            if (typeNames.find(types[i].type) != typeNames.end()) {
                continue; // already known, from this country or an earlier one
            }
            // Guarded against a type appearing twice in one batch, which cannot
            // happen while rows are keyed by type and branch but would put the
            // answers out of step with the questions if it ever did.
            bool alreadyAsked = false;
            for (size_t a = 0; a < asked.size(); a++) {
                if (asked[a] == types[i].type) {
                    alreadyAsked = true;
                    break;
                }
            }
            if (alreadyAsked) {
                continue;
            }

            if (!joined.empty()) {
                joined += ';';
            }
            joined += types[i].type;
            asked.push_back(types[i].type);
        }

        if (!asked.empty() &&
            Gui::Lua::beginTableCallWithString(TYPE_NAMES, joined.c_str())) {
            if (Gui::Lua::boolField("available")) {
                const int count = Gui::Lua::arrayLength("names");
                for (int i = 0; i < count && i < static_cast<int>(asked.size()); i++) {
                    // Remembered even when it comes back empty: a key the
                    // localisation does not have will not grow one, and asking again
                    // on every refresh is what the cache is here to avoid.
                    typeNames[asked[i]] = Gui::Lua::arrayStringAt("names", i);
                }
            }
            Gui::Lua::endCall();
        }

        for (size_t i = 0; i < types.size(); i++) {
            const std::map<std::string, std::string>::const_iterator found =
                typeNames.find(types[i].type);
            const bool named = (found != typeNames.end() && !found->second.empty());

            // The key alone when there is no name, rather than an empty pair of
            // brackets: a kind the mod has not localised should read as itself and
            // be obvious to whoever has to add the line.
            types[i].display = named
                ? (found->second + " [" + types[i].type + "]")
                : types[i].type;
        }
    }

    void refresh() {
        const std::string& tag = Gui::Selection::tag();
        readTag = tag;
        read = true;
        lastReadMs = GetTickCount64();

        if (tag.empty()) {
            tree = Oob::Tree();
            tree.reason = Gui::Selection::reason();
            levels.clear();
            types.clear();
            return;
        }

        tree = Oob::read(CCountry::findByTag(tag));
        rebuildLevels();
        rebuildTypes();
        resolveTypeNames();
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
        sprintf_s(line, "%d units without a commander\r\n", tree.leaderlessTotal);
        out += line;
        sprintf_s(line, "%.0f%% supply, %.0f%% fuel on average\r\n",
            tree.supplyAverage / 10.0, tree.fuelAverage / 10.0);
        out += line;
        sprintf_s(line, "consumes %.2f supply and %.2f fuel a day\r\n\r\n",
            tree.supplyConsumptionTotal / 1000.0, tree.fuelConsumptionTotal / 1000.0);
        out += line;

        // In the order the page shows them, and the By type table honouring its
        // filter: what is copied is what is being looked at.
        out += "By kind\r\n";
        for (size_t i = 0; i < levels.size(); i++) {
            sprintf_s(line, "  %-24s %5d units, %5d regiments\r\n",
                levels[i].kind.c_str(), levels[i].count, levels[i].regiments);
            out += line;
        }

        out += "\r\nTop level formations\r\n";
        for (size_t i = 0; i < tree.roots.size(); i++) {
            const Oob::Unit& unit = tree.units[tree.roots[i]];
            sprintf_s(line,
                "  %-40s %4d land %4d air %4d naval %5d regiments %8.2f supply %8.2f fuel\r\n",
                unit.name.empty() ? "(unnamed)" : unit.name.c_str(),
                unit.landBelow, unit.airBelow, unit.navalBelow,
                unit.regimentsBelow + unit.regimentCount,
                (unit.supplyConsumptionBelow + unit.supplyConsumption) / 1000.0,
                (unit.fuelConsumptionBelow + unit.fuelConsumption) / 1000.0);
            out += line;
        }

        if (branchFilter == 0) {
            out += "\r\nBy type\r\n";
        }
        else {
            sprintf_s(line, "\r\nBy type (%s only)\r\n", BRANCH_FILTERS[branchFilter]);
            out += line;
        }
        for (size_t i = 0; i < types.size(); i++) {
            if (!passesFilter(types[i].branch)) {
                continue;
            }
            sprintf_s(line, "  %-48s %5d\r\n", types[i].display.c_str(), types[i].count);
            out += line;
        }
        return out;
    }

    void drawOobReport() {
        if (ImGui::Button("Refresh")) {
            refresh();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &autoRefresh);
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Re-reads every five seconds. Reading a whole order of\n"
                "battle is thousands of small reads, so this is off by default.");
        }

        // Only once it has been read at all: the first read stays deliberate, so
        // opening the page does not set thousands of reads going on its own.
        if (autoRefresh && read && GetTickCount64() - lastReadMs >= 5000) {
            refresh();
        }
        if (readTag != Gui::Selection::tag()) {
            refresh();
        }

        ImGui::SameLine();
        ImGui::TextDisabled("%s", Gui::Selection::tag().c_str());

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

        // Totals and By kind side by side. Both are short and fixed - five lines
        // against a table with a row per level, which is seven for a country with all
        // three branches - so stacking them spent a third of the page on two things
        // that fit next to each other.
        //
        // Laid out with a borderless table rather than SameLine, so the two keep their
        // share of a window whatever its width instead of the right hand one landing
        // wherever the longest line on the left happens to end.
        ImGui::Spacing();
        if (ImGui::BeginTable("summary", 2, ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("##totals", ImGuiTableColumnFlags_WidthStretch, 1.1f);
            ImGui::TableSetupColumn("##kind", ImGuiTableColumnFlags_WidthStretch, 1.0f);
            ImGui::TableNextRow();

            ImGui::TableNextColumn();
            ImGui::SeparatorText("Totals");
            ImGui::Text("%d units: %d land, %d air, %d naval",
                static_cast<int>(tree.units.size()), tree.landTotal, tree.airTotal,
                tree.navalTotal);
            ImGui::Text("%d regiments across %d formations that report to nobody",
                tree.regimentTotal, static_cast<int>(tree.roots.size()));

            // Red when there are any, plain white when there are none: nothing missing
            // is good news and should not look like a warning.
            ImGui::TextColored(tree.leaderlessTotal > 0
                ? Gui::Theme::mark(Gui::Theme::Mark::Error)
                : Gui::Theme::mark(Gui::Theme::Mark::Strong),
                "%d units without a commander", tree.leaderlessTotal);

            ImGui::Text("Supply %.0f%% average, fuel %.0f%% average",
                tree.supplyAverage / 10.0, tree.fuelAverage / 10.0);
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Averaged over every unit, each counting the same\n"
                    "whatever its size.");
            }

            ImGui::Text("Consumes %.2f supply and %.2f fuel a day",
                tree.supplyConsumptionTotal / 1000.0, tree.fuelConsumptionTotal / 1000.0);
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Asked of the game for each unit rather than added up\n"
                    "from the unit types, so the leader and country effects\n"
                    "are in it - the same figure the game's own tooltip shows.");
            }

            ImGui::TableNextColumn();
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

            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Top level formations");
        // Eight rows and then a scrollbar. A country has a handful of these and a
        // fixed height keeps the table below it in the same place from country to
        // country, which a table that grew with the count would not.
        const float formationHeight = ImGui::GetFrameHeight() +
            ImGui::GetTextLineHeightWithSpacing() * 8.0f;

        if (ImGui::BeginTable("formations", 7, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp |
            ImGuiTableFlags_ScrollY, ImVec2(0.0f, formationHeight))) {
            ImGui::TableSetupColumn("Formation", ImGuiTableColumnFlags_WidthStretch, 1.8f);
            ImGui::TableSetupColumn("Land", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Air", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Naval", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Regiments", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            ImGui::TableSetupColumn("Supply", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupColumn("Fuel", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupScrollFreeze(0, 1);
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
                ImGui::TableNextColumn();
                ImGui::Text("%.2f", (unit.supplyConsumptionBelow + unit.supplyConsumption) / 1000.0);
                ImGui::TableNextColumn();
                ImGui::Text("%.2f", (unit.fuelConsumptionBelow + unit.fuelConsumption) / 1000.0);
            }
            ImGui::EndTable();
        }
        ImGui::TextWrapped("Counts below a formation exclude the formation itself, so a "
            "theatre's land count is the units under its command rather than a count "
            "that includes it.");

        ImGui::Spacing();
        ImGui::SeparatorText("By type");
        if (types.empty()) {
            ImGui::TextDisabled("No regiment named a type it could be counted under.");
            return;
        }

        // Under this table's heading and nowhere else, so what it reaches is the one
        // table it is standing in.
        ImGui::TextUnformatted("Show");
        for (int i = 0; i < BRANCH_FILTER_COUNT; i++) {
            ImGui::SameLine();
            ImGui::RadioButton(BRANCH_FILTERS[i], &branchFilter, i);
        }

        int shown = 0;
        for (size_t i = 0; i < types.size(); i++) {
            if (passesFilter(types[i].branch)) {
                shown++;
            }
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%d of %d types", shown, static_cast<int>(types.size()));

        // Said rather than left as an empty table: a country with no navy filtered to
        // Naval looks the same as a table that failed to fill.
        if (shown == 0) {
            ImGui::TextDisabled("This country has no %s regiments.",
                BRANCH_FILTERS[branchFilter]);
            return;
        }

        // Last on the page, so it takes whatever height is left - the one table here
        // whose length is worth giving a taller window to, since a country has as many
        // rows as it has kinds of regiment.
        const float typeLeft = ImGui::GetContentRegionAvail().y;
        const float typeHeight = (typeLeft > 120.0f) ? typeLeft : 120.0f;

        if (ImGui::BeginTable("byType", 2, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp |
            ImGuiTableFlags_ScrollY, ImVec2(0.0f, typeHeight))) {
            ImGui::TableSetupColumn("Type", ImGuiTableColumnFlags_WidthStretch, 2.0f);
            ImGui::TableSetupColumn("Count", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupScrollFreeze(0, 1);
            ImGui::TableHeadersRow();

            for (size_t i = 0; i < types.size(); i++) {
                if (!passesFilter(types[i].branch)) {
                    continue;
                }
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(types[i].display.c_str());
                if (ImGui::IsItemHovered()) {
                    ImGui::SetTooltip("%s", Oob::branchName(types[i].branch));
                }
                ImGui::TableNextColumn();
                ImGui::Text("%d", types[i].count);
            }
            ImGui::EndTable();
        }
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
