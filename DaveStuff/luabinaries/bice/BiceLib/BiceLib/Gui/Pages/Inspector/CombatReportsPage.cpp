// Combat Reports: what the selected country's fighting has cost and won, over the
// last day, week, month, half year and year, split by land, air and naval.
//
// The report is fed by a hook on the game's own combat recording: a finished combat
// leaves a CCombatHistoryEntry holding a date, a province and one country tag, the game
// prunes those after a few days, and no casualties are in them at all. So each combat
// is caught as it ends, when the CCombat and both its combatants are still alive, and
// written to a file belonging to the campaign - see Combat/CombatStore.
//
// The game names only the winner of a combat - it reads a side's tag out of the country
// list a beaten side no longer has - so the loser's name is taken from a second list
// the beaten side keeps. A combat where even that could not be read names nobody who
// lost, and so counts for nobody: the report says how many of those a period holds
// rather than quietly showing a short total.
//
// The men each side had in a fight are read the way the game reads them for its own
// battle message, out of a tally kept per subunit type - so the losses beside them are
// a share of something rather than a number on their own.
//
// How all of that was worked out is in the reversing folder beside the solution.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/CountrySelection.hpp>
#include <Gui/LuaBridge.hpp>
#include <GameState/CombatLog.hpp>
#include <GameState/CombatStore.hpp>

#include <utils.hpp>

#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    // The windows the page reports over. Days, because that is the unit the game
    // counts in: a Clausewitz year is 365 days with no leap day.
    struct Period
    {
        const char* label;
        int days;
    };
    const Period PERIODS[] = {
        { "Day", 1 },
        { "Week", 7 },
        { "Month", 30 },
        { "Half year", 182 },
        { "Year", 365 },
    };
    const int PERIOD_COUNT = static_cast<int>(sizeof(PERIODS) / sizeof(PERIODS[0]));

    // A range typed in by hand sits one past the fixed periods, which are all "the
    // last so many days" and so cannot answer a question about a particular war.
    const int CUSTOM_PERIOD = PERIOD_COUNT;

    int selectedPeriod = 1; // Week, as the one most likely to be looked at

    // Dates as gameTickToDate writes them, year.month.day. Filled from the last month
    // the first time the custom range is picked, so it starts somewhere sensible.
    char customFrom[32] = {};
    char customTo[32] = {};
    bool customFilled = false;

    // The range those two last read as, kept so a date in the middle of being typed
    // does not take the figures with it.
    unsigned int customFromTick = 0;
    unsigned int customToTick = 0;

    // The three kinds of bombing raid share a column: what a raid is aimed at matters
    // less in a report than that it was a raid, and three more columns of mostly
    // nothing would cost more than they say. The capture list still names each one.
    const char* const BRANCHES[] = { "Land", "Air", "Naval", "Bombing" };
    const int BRANCH_COUNT = 4;
    const int BOMBING_COLUMN = 3;

    // In the order drawFigure reads them.
    const char* const FIGURES[] = {
        "Combats",
        "Won",
        "Lost",
        "As attacker",
        "As defender",
        "Enemy casualties",
        "Own casualties",
    };
    const int FIGURE_COUNT = static_cast<int>(sizeof(FIGURES) / sizeof(FIGURES[0]));

    const Combat::Branch BRANCH_OF[] = {
        Combat::Branch::Land, Combat::Branch::Air, Combat::Branch::Naval,
    };

    const Combat::Branch BOMBING_BRANCHES[] = {
        Combat::Branch::GroundBombing,
        Combat::Branch::LandBombing,
        Combat::Branch::NavalBombing,
    };
    const int BOMBING_KINDS =
        static_cast<int>(sizeof(BOMBING_BRANCHES) / sizeof(BOMBING_BRANCHES[0]));

    /**@brief adds \p from into \p into, for the column that is three kinds at once*/
    void addTally(Combat::Tally& into, const Combat::Tally& from) {
        into.combats += from.combats;
        into.won += from.won;
        into.lost += from.lost;
        into.asAttacker += from.asAttacker;
        into.asDefender += from.asDefender;
        into.losses += from.losses;
        into.kills += from.kills;
    }

    /**@brief 1234567 as "1.234.567", since a war's casualties run to seven digits*/
    std::string grouped(int64_t value) {
        char digits[32];
        sprintf_s(digits, "%lld", value < 0 ? -value : value);

        std::string out;
        const int length = static_cast<int>(strlen(digits));
        for (int i = 0; i < length; i++) {
            // A stop every three digits, counted from the right rather than the left.
            if (i > 0 && ((length - i) % 3) == 0) {
                out += '.';
            }
            out += digits[i];
        }
        return (value < 0) ? ("-" + out) : out;
    }

    /**@brief a tick as a date alone, without the hour gameTickToDate adds*/
    std::string dateOnly(unsigned int tick) {
        const std::string text = utils::gameTickToDate(static_cast<int>(tick));
        const size_t space = text.find(' ');
        return (space == std::string::npos) ? text : text.substr(0, space);
    }

    /**
    @brief reads a date the way the page writes them, year.month.day

    @param hourOfDay 0 to start a day, 23 to take the whole of it
    @returns false if that is not a date, leaving \p tick alone
    */
    bool parseDate(const char* text, unsigned int& tick, int hourOfDay) {
        int year = 0;
        int month = 0;
        int day = 0;
        if (sscanf_s(text, "%d.%d.%d", &year, &month, &day) != 3) {
            return false;
        }

        const int result = utils::dateToGameTick(year, month, day, hourOfDay);
        if (result <= 0) {
            return false;
        }
        tick = static_cast<unsigned int>(result);
        return true;
    }

    /**@brief writes the range's ticks back into the two boxes*/
    void writeRange() {
        strncpy_s(customFrom, dateOnly(customFromTick).c_str(), _TRUNCATE);
        strncpy_s(customTo, dateOnly(customToTick).c_str(), _TRUNCATE);
    }

    /**@brief moves the end of the range by \p days, never past the start*/
    void moveEnd(int days) {
        const long long moved =
            static_cast<long long>(customToTick) + static_cast<long long>(days) * 24;
        if (moved < static_cast<long long>(customFromTick)) {
            return;
        }
        customToTick = static_cast<unsigned int>(moved);
        writeRange();
    }

    /**@brief slides the whole range a day, keeping its length*/
    void slideRange(int direction) {
        const long long step = static_cast<long long>(direction) * 24;
        if (static_cast<long long>(customFromTick) + step < 0) {
            return;
        }

        customFromTick = static_cast<unsigned int>(customFromTick + step);
        customToTick = static_cast<unsigned int>(customToTick + step);
        writeRange();
    }

    void drawFigure(const char* label, const Combat::Tally* byBranch,
        const Combat::Tally& total, int which) {
        ImGui::TableNextRow();
        ImGui::TableNextColumn();
        ImGui::TextUnformatted(label);

        for (int b = 0; b <= BRANCH_COUNT; b++) {
            const Combat::Tally& tally = (b < BRANCH_COUNT) ? byBranch[b] : total;
            ImGui::TableNextColumn();

            switch (which) {
            case 0: ImGui::TextUnformatted(grouped(tally.combats).c_str()); break;
            case 1: ImGui::TextUnformatted(grouped(tally.won).c_str()); break;
            case 2: ImGui::TextUnformatted(grouped(tally.lost).c_str()); break;
            case 3: ImGui::TextUnformatted(grouped(tally.asAttacker).c_str()); break;
            case 4: ImGui::TextUnformatted(grouped(tally.asDefender).c_str()); break;
            // Whole men, the way the game itself reports a battle: it divides the
            // same thousandths by a thousand to say "20 casualties".
            case 5: ImGui::TextUnformatted(grouped(tally.kills / 1000).c_str()); break;
            case 6: ImGui::TextUnformatted(grouped(tally.losses / 1000).c_str()); break;
            default: ImGui::TextDisabled("-"); break;
            }
        }
    }

    void drawReport() {
        const std::string& tag = Gui::Selection::tag();
        const unsigned int now = Combat::Store::currentTick();

        for (int i = 0; i < PERIOD_COUNT; i++) {
            if (i > 0) {
                ImGui::SameLine();
            }
            if (ImGui::RadioButton(PERIODS[i].label, selectedPeriod == i)) {
                selectedPeriod = i;
            }
        }
        ImGui::SameLine();
        if (ImGui::RadioButton("Custom", selectedPeriod == CUSTOM_PERIOD)) {
            selectedPeriod = CUSTOM_PERIOD;
        }

        unsigned int from = 0;
        unsigned int to = now;
        bool readable = true;

        if (selectedPeriod == CUSTOM_PERIOD) {
            // The last month, as a starting point that shows something rather than an
            // empty table asking to be filled in before it says anything.
            if (!customFilled && now != 0) {
                const unsigned int month = 30u * 24u;
                strncpy_s(customFrom, dateOnly(now > month ? now - month : 0u).c_str(),
                    _TRUNCATE);
                strncpy_s(customTo, dateOnly(now).c_str(), _TRUNCATE);
                customFilled = true;
            }

            // Wide enough for 1936.12.31 and no wider.
            const float dateWidth = ImGui::CalcTextSize("1936.12.31").x +
                ImGui::GetStyle().FramePadding.x * 2.0f + 4.0f;

            ImGui::SameLine();
            ImGui::SetNextItemWidth(dateWidth);
            ImGui::InputText("##from", customFrom, sizeof(customFrom));
            ImGui::SameLine();
            ImGui::TextUnformatted("to");
            ImGui::SameLine();
            ImGui::SetNextItemWidth(dateWidth);
            ImGui::InputText("##to", customTo, sizeof(customTo));
            if (ImGui::IsItemHovered() || ImGui::IsItemActive()) {
                ImGui::SetTooltip("Dates as the game counts them: year.month.day, the\n"
                    "way they are written in the list below. Both ends are\n"
                    "included, the last one for the whole of its day.");
            }

            // Held down, these repeat - a month is thirty clicks otherwise. They run
            // before the boxes are read, so a press shows in the same frame.
            ImGui::PushItemFlag(ImGuiItemFlags_ButtonRepeat, true);

            ImGui::SameLine();
            if (ImGui::Button("-##endDay")) {
                moveEnd(-1);
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("A day off the end");
            }

            ImGui::SameLine();
            if (ImGui::Button("+##endDay")) {
                moveEnd(1);
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("A day onto the end");
            }

            ImGui::SameLine();
            if (ImGui::Button("<##slide")) {
                slideRange(-1);
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Both ends back a day");
            }

            ImGui::SameLine();
            if (ImGui::Button(">##slide")) {
                slideRange(1);
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Both ends on a day");
            }

            ImGui::PopItemFlag();

            // A half typed date is not a date, and the figures should not follow it
            // into a year nobody asked for. So the range only moves when both ends
            // read, and otherwise stays where it was, with a note saying why.
            unsigned int typedFrom = customFromTick;
            unsigned int typedTo = customToTick;
            readable = parseDate(customFrom, typedFrom, 0) &&
                parseDate(customTo, typedTo, 23);
            if (readable) {
                if (typedFrom > typedTo) {
                    const unsigned int swap = typedFrom;
                    typedFrom = typedTo;
                    typedTo = swap;
                }
                customFromTick = typedFrom;
                customToTick = typedTo;
            }

            from = customFromTick;
            to = customToTick;
        }
        else {
            // Ticks are hours, and a Clausewitz day is twenty four of them.
            const unsigned int span =
                static_cast<unsigned int>(PERIODS[selectedPeriod].days) * 24u;
            from = (now > span) ? (now - span) : 0u;
        }

        ImGui::SameLine();
        if (selectedPeriod == CUSTOM_PERIOD) {
            if (readable) {
                ImGui::TextDisabled("%u days | %s (%s)", (to - from) / 24u + 1u,
                    tag.c_str(), Gui::Selection::source().c_str());
            }
            else {
                ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                    "not a date - write it as 1936.1.1 | showing %s to %s",
                    dateOnly(from).c_str(), dateOnly(to).c_str());
            }
        }
        else {
            ImGui::TextDisabled("last %d days | %s (%s)", PERIODS[selectedPeriod].days,
                tag.c_str(), Gui::Selection::source().c_str());
        }

        Combat::Tally byBranch[BRANCH_COUNT];
        for (int b = 0; b < BRANCH_COUNT; b++) {
            if (b == BOMBING_COLUMN) {
                for (int k = 0; k < BOMBING_KINDS; k++) {
                    addTally(byBranch[b],
                        Combat::Store::tally(tag, from, to, BOMBING_BRANCHES[k]));
                }
                continue;
            }
            byBranch[b] = Combat::Store::tally(tag, from, to, BRANCH_OF[b]);
        }
        const Combat::Tally total =
            Combat::Store::tally(tag, from, to, Combat::Branch::Unknown);

        ImGui::Spacing();
        if (ImGui::BeginTable("combatReports", BRANCH_COUNT + 2, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 1.2f);
            for (int b = 0; b < BRANCH_COUNT; b++) {
                ImGui::TableSetupColumn(BRANCHES[b], ImGuiTableColumnFlags_WidthStretch, 0.8f);
            }
            ImGui::TableSetupColumn("Total", ImGuiTableColumnFlags_WidthStretch, 0.8f);
            ImGui::TableHeadersRow();

            for (int f = 0; f < FIGURE_COUNT; f++) {
                drawFigure(FIGURES[f], byBranch, total, f);
            }
            ImGui::EndTable();
        }

        // What the figures are, and are not, worth saying plainly: the record only
        // holds what has been watched, so a year's row is a year old at the earliest.
        // Combats whose beaten side never got a name belong to nobody, so they are in
        // no country's figures. Saying how many there are is the only honest way to
        // show a total that is quietly short.
        int nameless = 0;
        const std::vector<Combat::Entry>& all = Combat::Store::entries();
        for (size_t i = 0; i < all.size(); i++) {
            if (all[i].tick < from || all[i].tick > to) {
                continue;
            }
            if (strcmp(all[i].attackerTag, "---") == 0 ||
                strcmp(all[i].defenderTag, "---") == 0) {
                nameless++;
            }
        }

        ImGui::Spacing();
        if (nameless > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "%d combats in this period name only their winner.", nameless);
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip(
                    "The game takes a side's tag from a country list that the beaten\n"
                    "side no longer has by the time the combat is recorded, so only\n"
                    "the winner is named. The loser's name comes from a second\n"
                    "list it keeps, at +0x64, instead.\n\n"
                    "Where that could not be read either, the combat belongs to nobody\n"
                    "and is counted for neither side. See Capture below.");
            }
            ImGui::Spacing();
        }
        if (Combat::Store::campaign() == 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "No campaign yet: %s",
                Combat::Store::reason().c_str());
        }
        else {
            ImGui::TextDisabled("Campaign %d, %d combats recorded",
                Combat::Store::campaign(), Combat::Store::count());
            if (ImGui::IsItemHovered() && !Combat::Store::path().empty()) {
                ImGui::SetTooltip("%s", Combat::Store::path().c_str());
            }
        }
        if (!Combat::recording()) {
            ImGui::SameLine();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "- not recording, so nothing is being added");
        }
    }

    // The last few battles, not a war diary: the figures above are for reading a
    // campaign, and this is for seeing what just happened.
    const int MAX_BATTLE_ROWS = 16;

    // Province names are localisation rather than anything in memory, so they have to
    // come from Lua - and are kept once asked for, because the table would otherwise
    // ask for the same handful of names every frame.
    //
    // One row can want one name, so the cache never needs to be bigger than the table
    // and the work per frame is bounded by the same number. When the visible battles
    // change enough to want a seventeenth, the whole thing goes: at sixteen entries
    // that is cheaper than tracking which one has gone stale, and the next frame
    // fills it again.
    std::map<int, std::string> provinceNames;
    const char* PROVINCE_NAME = "BiceLibGui.Oob.ProvinceName";

    /**@brief "Kiel (256)", or the id alone where there is no name for it*/
    std::string provinceLabel(int id) {
        char number[32];
        sprintf_s(number, "%d", id);
        if (id == 0) {
            return std::string(number);
        }

        const std::map<int, std::string>::const_iterator found = provinceNames.find(id);
        if (found != provinceNames.end()) {
            return found->second.empty()
                ? std::string(number)
                : found->second + " (" + number + ")";
        }

        if (static_cast<int>(provinceNames.size()) >= MAX_BATTLE_ROWS) {
            provinceNames.clear();
        }

        std::string name;
        if (Gui::Lua::beginTableCallWithNumber(PROVINCE_NAME, id)) {
            if (Gui::Lua::boolField("available")) {
                name = Gui::Lua::stringField("name");
            }
            Gui::Lua::endCall();

            // Remembered even when it comes back empty: a province with no
            // localisation will not grow one, and asking again every frame is the
            // thing this is here to avoid. A failed call is not remembered, since
            // that is Lua being unavailable rather than an answer.
            provinceNames[id] = name;
        }
        return name.empty() ? std::string(number) : name + " (" + number + ")";
    }

    /**
    @brief the headcount beside a casualty figure, or "---" where it is not one

    The tally the men come from only holds men in a land or naval battle, which is
    also where the game itself prints them as troops. An air combat counts subunits in
    it while its losses stay a fraction of strength, so the two do not belong on one
    line, and a bombing raid leaves it empty altogether. Showing nothing beats showing
    a number that means something else.
    */
    void drawMen(int men, Combat::Branch branch) {
        const bool meaningful = (branch == Combat::Branch::Land ||
            branch == Combat::Branch::Naval);
        if (meaningful && men > 0) {
            ImGui::TextUnformatted(grouped(men).c_str());
        }
        else {
            ImGui::TextDisabled("---");
        }
    }

    /**
    @brief the battles this country has fought, most recent first

    The figures above say how a war is going; this says which battles made it go that
    way. Only this country's, because a list of everyone's battles is a list nobody
    is looking for.
    */
    void drawBattles(const std::string& tag) {
        ImGui::Spacing();
        ImGui::SeparatorText("Last battles");

        if (tag.empty()) {
            ImGui::TextDisabled("No country selected.");
            return;
        }

        // Newest first, and only as many as anyone will scroll through.
        const std::vector<Combat::Entry>& all = Combat::Store::entries();
        std::vector<const Combat::Entry*> mine;
        for (size_t i = all.size(); i > 0; i--) {
            const Combat::Entry& entry = all[i - 1];
            if (tag == entry.attackerTag || tag == entry.defenderTag) {
                mine.push_back(&entry);
            }
            if (static_cast<int>(mine.size()) >= MAX_BATTLE_ROWS) {
                break;
            }
        }

        if (mine.empty()) {
            ImGui::TextDisabled("Nothing recorded for %s yet. Battles are added as "
                "they finish.", tag.c_str());
            return;
        }

        // Tall enough for the battles there are, and no taller. A fixed height either
        // scrolls a table that had room to be shown whole, or leaves empty rows under
        // a short one; this grows with the window until the sixteenth battle, which is
        // the last one there can be, and stops there.
        const float rowHeight = ImGui::GetTextLineHeightWithSpacing();
        const float wanted = ImGui::GetFrameHeight() +
            rowHeight * static_cast<float>(mine.size()) +
            ImGui::GetStyle().CellPadding.y * 2.0f;

        // Except when the window is too small to hold that, where scrolling what is
        // there beats spilling out of the bottom of it.
        const float available = ImGui::GetContentRegionAvail().y;
        const float height = (available > rowHeight * 3.0f && available < wanted)
            ? available
            : wanted;

        if (ImGui::BeginTable("battles", 10, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp |
            ImGuiTableFlags_ScrollY, ImVec2(0.0f, height))) {
            ImGui::TableSetupColumn("Ended", ImGuiTableColumnFlags_WidthStretch, 1.2f);
            ImGui::TableSetupColumn("Kind", ImGuiTableColumnFlags_WidthStretch, 0.9f);
            ImGui::TableSetupColumn("Result", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupColumn("Role", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            ImGui::TableSetupColumn("Against", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            // The two casualty columns are named and sized alike: each is the men one
            // side lost, and the "Of" after it is the men that side brought.
            ImGui::TableSetupColumn("Enemy casualties", ImGuiTableColumnFlags_WidthStretch, 1.1f);
            ImGui::TableSetupColumn("Of", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            ImGui::TableSetupColumn("Own casualties", ImGuiTableColumnFlags_WidthStretch, 1.1f);
            ImGui::TableSetupColumn("Of", ImGuiTableColumnFlags_WidthStretch, 0.7f);
            ImGui::TableSetupColumn("Province", ImGuiTableColumnFlags_WidthStretch, 1.4f);
            ImGui::TableHeadersRow();

            for (size_t i = 0; i < mine.size(); i++) {
                const Combat::Entry& entry = *mine[i];
                const bool attacked = (tag == entry.attackerTag);

                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(
                    utils::gameTickToDate(static_cast<int>(entry.tick)).c_str());
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(Combat::branchName(entry.branch));

                // Nobody wins a bombing raid, so it gets a dash rather than a verdict.
                ImGui::TableNextColumn();
                const bool won = attacked
                    ? (entry.winner == Combat::Outcome::AttackerWon)
                    : (entry.winner == Combat::Outcome::DefenderWon);
                if (entry.winner == Combat::Outcome::Unknown) {
                    ImGui::TextDisabled("-");
                }
                else if (won) {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success), "Won");
                }
                else {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error), "Lost");
                }

                ImGui::TableNextColumn();
                ImGui::TextUnformatted(attacked ? "Attacker" : "Defender");
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(attacked ? entry.defenderTag : entry.attackerTag);

                // One side's losses are the casualties it inflicted on the other, so
                // both come from the pair - and each is shown against the men that
                // side had in the fight, since a number of casualties says little on
                // its own.
                const int theirCasualties = attacked ? entry.defenderLosses : entry.attackerLosses;
                const int ourCasualties = attacked ? entry.attackerLosses : entry.defenderLosses;
                const int theirMen = attacked ? entry.defenderMen : entry.attackerMen;
                const int ourMen = attacked ? entry.attackerMen : entry.defenderMen;

                ImGui::TableNextColumn();
                ImGui::TextUnformatted(grouped(theirCasualties / 1000).c_str());
                ImGui::TableNextColumn();
                drawMen(theirMen, entry.branch);
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(grouped(ourCasualties / 1000).c_str());
                ImGui::TableNextColumn();
                drawMen(ourMen, entry.branch);
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(provinceLabel(entry.provinceId).c_str());
            }
            ImGui::EndTable();
        }

        if (Combat::Store::lost() > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error),
                "%u combats were caught but could not be filed, so they are missing "
                "from all of this.", Combat::Store::lost());
        }
    }

    void drawCombatReports() {
        drawReport();
        drawBattles(Gui::Selection::tag());
    }

    class CombatReportsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Combat Reports"; }
        const char* group() const override { return "Inspector"; }
        int order() const override { return 17; } // right behind the OOB Report
        void draw() override { drawCombatReports(); }
    };
}

REGISTER_GUI_PAGE(CombatReportsPage);
