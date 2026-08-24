// OOB Browser: the selected country's order of battle as a tree, with one unit's
// details beside it.
//
// The tree is read whole on refresh - a country's units are thousands of small reads,
// which is fine on a timer but not every frame. Regiments are left out of that and
// read only for the unit being looked at, since they would multiply the work by ten
// for something only one unit at a time ever shows.

#include <Gui/GuiPage.hpp>
#include <Gui/CountrySelection.hpp>
#include <Gui/LuaBridge.hpp>
#include <GameState/OrderOfBattle.hpp>

#include <GameClasses/CCountry.hpp>

#include <Windows.h>
#include <cstdio>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    // Red for a unit with nobody commanding it, plain white for none of them: a
    // count of zero is good news and should not be dressed as a warning.
    const ImVec4 LEADERLESS = ImVec4(0.85f, 0.35f, 0.35f, 1.0f);
    const ImVec4 NONE_MISSING = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);

    // The same red, dimmed, for a formation that is only red because of something
    // underneath it. One unled division turns its whole chain of command red, and
    // without the difference in shade there is no telling the culprit from the trail
    // leading to it.
    const ImVec4 LEADERLESS_BELOW = ImVec4(0.62f, 0.34f, 0.34f, 1.0f);

    Oob::Tree tree;
    std::string readTag;
    ULONGLONG lastReadMs = 0;
    bool autoRefresh = false;

    // Kept by address rather than by index so a refresh that reorders the units does
    // not quietly move the selection onto a different one.
    uintptr_t selectedAddress = 0;
    std::vector<Oob::Regiment> selectedRegiments;
    uintptr_t regimentsFor = 0;

    // Province names are not in memory - they are localisation - so this is the one
    // thing on the page that has to come from Lua. Fetched with the regiments when
    // the selection changes, since only the selected unit ever shows one.
    std::string selectedProvinceName;
    const char* PROVINCE_NAME = "BiceLibGui.Oob.ProvinceName";

    // -1 does nothing, 0 collapses every node for one frame, 1 opens them.
    int forceOpenState = -1;

    char filter[64] = {};

    // What the tree looked like on the frame just drawn: which units were on screen,
    // top to bottom, and which were open. Arrow keys work off this rather than off
    // the tree itself, because what is on screen depends on what is open and what
    // the filter hid, and this already accounts for both.
    std::vector<int> visibleOrder;
    std::vector<char> openState;

    // ImGui owns whether a node is open, so changing one is a request left for the
    // next frame rather than something done here.
    int pendingOpenIndex = -1;
    bool pendingOpenValue = false;
    bool scrollToSelected = false;

    void refresh() {
        const std::string& tag = Gui::Selection::tag();
        readTag = tag;
        selectedRegiments.clear();
        regimentsFor = 0;

        // These are all indices into the tree about to be replaced.
        visibleOrder.clear();
        openState.clear();
        pendingOpenIndex = -1;

        if (tag.empty()) {
            tree = Oob::Tree();
            tree.reason = Gui::Selection::reason();
            return;
        }

        tree = Oob::read(CCountry::findByTag(tag));
        lastReadMs = GetTickCount64();
    }

    /**@brief "34%" style text for the game's x10 percentages*/
    const char* percentText(int value, char* buffer, size_t size) {
        sprintf_s(buffer, size, "%.0f%%", value / 10.0);
        return buffer;
    }

    bool matchesFilter(const Oob::Unit& unit) {
        if (filter[0] == '\0') {
            return true;
        }

        // Case insensitive contains, done by hand to keep the page free of locale
        // surprises with the game's names.
        const std::string& name = unit.name;
        const size_t needle = strlen(filter);
        if (needle > name.size()) {
            return false;
        }
        for (size_t start = 0; start + needle <= name.size(); start++) {
            size_t i = 0;
            while (i < needle &&
                tolower(static_cast<unsigned char>(name[start + i])) ==
                tolower(static_cast<unsigned char>(filter[i]))) {
                i++;
            }
            if (i == needle) {
                return true;
            }
        }
        return false;
    }

    /**@brief true if this unit or anything below it matches, so filtering keeps paths*/
    bool subtreeMatches(int index) {
        const Oob::Unit& unit = tree.units[index];
        if (matchesFilter(unit)) {
            return true;
        }
        for (size_t i = 0; i < unit.children.size(); i++) {
            if (subtreeMatches(unit.children[i])) {
                return true;
            }
        }
        return false;
    }

    void drawNode(int index) {
        const Oob::Unit& unit = tree.units[index];
        if (!subtreeMatches(index)) {
            return;
        }

        ImGuiTreeNodeFlags flags = ImGuiTreeNodeFlags_OpenOnArrow |
            ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_SpanAvailWidth;
        if (unit.children.empty()) {
            flags |= ImGuiTreeNodeFlags_Leaf | ImGuiTreeNodeFlags_NoTreePushOnOpen;
        }
        if (unit.address == selectedAddress) {
            flags |= ImGuiTreeNodeFlags_Selected;
        }

        ImGui::PushID(index);
        if (forceOpenState >= 0 && !unit.children.empty()) {
            ImGui::SetNextItemOpen(forceOpenState == 1);
        }
        else if (pendingOpenIndex == index && !unit.children.empty()) {
            ImGui::SetNextItemOpen(pendingOpenValue);
        }

        const char* label = unit.name.empty() ? "(unnamed)" : unit.name.c_str();

        // Red for a unit nobody is commanding, dimmer red for every formation above
        // it: the tree opens collapsed, so a missing commander four levels down would
        // otherwise only be visible to someone who already went looking for it. The
        // dim shade marks the path, the bright one marks what is at the end of it.
        const bool unled = unit.leaderMissing || unit.leaderlessBelow > 0;
        if (unled) {
            ImGui::PushStyleColor(ImGuiCol_Text,
                unit.leaderMissing ? LEADERLESS : LEADERLESS_BELOW);
        }
        const bool open = ImGui::TreeNodeEx("node", flags, "%s", label);
        if (unled) {
            ImGui::PopStyleColor();
        }

        visibleOrder.push_back(index);
        if (index < static_cast<int>(openState.size())) {
            openState[index] = open ? 1 : 0;
        }

        // Keeps the selection on screen when the arrow keys walked it off the edge.
        if (scrollToSelected && unit.address == selectedAddress) {
            ImGui::SetScrollHereY(0.5f);
        }

        if (ImGui::IsItemClicked() && !ImGui::IsItemToggledOpen()) {
            selectedAddress = unit.address;
            ImGui::SetWindowFocus(); // so the arrow keys go to the tree from here on
        }

        // What is underneath, so the shape of the formation is readable without
        // opening it. Only where there is something underneath.
        if (unit.landBelow + unit.airBelow + unit.navalBelow > 0) {
            ImGui::SameLine();
            ImGui::TextDisabled("(%d)", unit.landBelow + unit.airBelow + unit.navalBelow);
            if (ImGui::IsItemHovered()) {
                // Says why a formation is red when it has a commander of its own.
                if (unit.leaderlessBelow > 0) {
                    ImGui::SetTooltip("%d land, %d air, %d naval below\n"
                        "%d of them without a commander",
                        unit.landBelow, unit.airBelow, unit.navalBelow,
                        unit.leaderlessBelow);
                }
                else {
                    ImGui::SetTooltip("%d land, %d air, %d naval below",
                        unit.landBelow, unit.airBelow, unit.navalBelow);
                }
            }
        }

        if (open && !unit.children.empty()) {
            for (size_t i = 0; i < unit.children.size(); i++) {
                drawNode(unit.children[i]);
            }
            ImGui::TreePop();
        }
        ImGui::PopID();
    }

    void select(int index) {
        selectedAddress = tree.units[index].address;
        scrollToSelected = true;
    }

    bool isOpen(int index) {
        return index < static_cast<int>(openState.size()) && openState[index] != 0;
    }

    /**
    @brief arrow keys over the tree, the way every other tree behaves

    Up and down step through what is on screen. Right opens a closed formation and
    steps into an open one; left closes an open one and climbs out of a closed one.
    Because children are drawn directly beneath their parent, stepping into a
    formation is just moving down one, whatever the filter has hidden in between.

    Acts on the frame after the tree was drawn, so it is working from a list of what
    is genuinely on screen rather than from what should be.
    */
    void handleTreeKeys() {
        if (!ImGui::IsWindowFocused()) {
            return;
        }

        // Claimed for as long as the tree has focus, rather than once a key arrives.
        // Whether the game also sees a key is decided in the window procedure at the
        // moment it arrives, so claiming in response to the first arrow is already a
        // frame too late - that one would still scroll the map underneath.
        //
        // Game hotkeys are inert while the tree has focus, which is the bargain any
        // focused list makes. Clicking elsewhere gives them back.
        ImGui::SetNextFrameWantCaptureKeyboard(true);

        if (visibleOrder.empty()) {
            return;
        }

        const bool down = ImGui::IsKeyPressed(ImGuiKey_DownArrow);
        const bool up = ImGui::IsKeyPressed(ImGuiKey_UpArrow);
        const bool left = ImGui::IsKeyPressed(ImGuiKey_LeftArrow);
        const bool right = ImGui::IsKeyPressed(ImGuiKey_RightArrow);
        if (!down && !up && !left && !right) {
            return;
        }

        int at = -1;
        for (size_t i = 0; i < visibleOrder.size(); i++) {
            if (tree.units[visibleOrder[i]].address == selectedAddress) {
                at = static_cast<int>(i);
                break;
            }
        }
        if (at < 0) {
            select(visibleOrder[0]); // nothing selected yet: start at the top
            return;
        }

        const int index = visibleOrder[at];
        const Oob::Unit& unit = tree.units[index];
        const bool hasChildren = !unit.children.empty();
        const int last = static_cast<int>(visibleOrder.size()) - 1;

        if (down) {
            if (at < last) {
                select(visibleOrder[at + 1]);
            }
        }
        else if (up) {
            if (at > 0) {
                select(visibleOrder[at - 1]);
            }
        }
        else if (right) {
            if (hasChildren && !isOpen(index)) {
                pendingOpenIndex = index;
                pendingOpenValue = true;
            }
            else if (hasChildren && at < last) {
                select(visibleOrder[at + 1]);
            }
        }
        else if (left) {
            if (hasChildren && isOpen(index)) {
                pendingOpenIndex = index;
                pendingOpenValue = false;
            }
            else if (unit.parent >= 0) {
                select(unit.parent);
            }
        }
    }

    struct DetailRow
    {
        const char* label;
        std::string value;
    };

    /**@brief the unit's stats as label and value, so the table and the clipboard
              cannot drift apart by being formatted twice*/
    std::vector<DetailRow> buildRows(const Oob::Unit& unit) {
        std::vector<DetailRow> rows;
        char line[128];
        char scratch[32];

        sprintf_s(line, "%s %s", Oob::branchName(unit.branch),
            Oob::levelName(unit.level, unit.branch));
        rows.push_back(DetailRow{ "Kind", line });

        sprintf_s(line, "%d", unit.id);
        rows.push_back(DetailRow{ "Id", line });

        if (unit.leader != 0) {
            sprintf_s(line, "%s (skill %d of %d)",
                unit.leaderName.empty() ? "?" : unit.leaderName.c_str(),
                unit.leaderSkill, unit.leaderMaxSkill);
            rows.push_back(DetailRow{ "Commander", line });
        }
        else {
            rows.push_back(DetailRow{ "Commander", "none" });
        }

        if (unit.provinceId != 0) {
            // Built as a string rather than into the scratch buffer: a province name
            // is short, but nothing here has promised that.
            sprintf_s(line, "%d", unit.provinceId);
            const std::string location = selectedProvinceName.empty()
                ? std::string(line)
                : selectedProvinceName + " (" + line + ")";
            rows.push_back(DetailRow{ "Province", location });
        }

        rows.push_back(DetailRow{ "Supply", percentText(unit.supplyPercent, scratch, sizeof(scratch)) });
        rows.push_back(DetailRow{ "Fuel", percentText(unit.fuelPercent, scratch, sizeof(scratch)) });

        // Only for a unit that has regiments of its own. Everything above division
        // consumes through what is under it, which the section below this reports.
        if (unit.regimentCount > 0) {
            sprintf_s(line, "%.2f", unit.supplyConsumption / 1000.0);
            rows.push_back(DetailRow{ "Supply used", line });
            sprintf_s(line, "%.2f", unit.fuelConsumption / 1000.0);
            rows.push_back(DetailRow{ "Fuel used", line });
        }

        sprintf_s(line, "%.1f", unit.digIn / 1000.0);
        rows.push_back(DetailRow{ "Dug in", line });

        sprintf_s(line, "%.0f%%", unit.combatArmsBonus / 10.0);
        rows.push_back(DetailRow{ "Combined arms", line });

        if (unit.combatCooldown > 0) {
            sprintf_s(line, "%.0f hours", unit.combatCooldown / 1000.0);
            rows.push_back(DetailRow{ "Combat cooldown", line });
        }

        // Joined rather than concatenated with trailing spaces, so whichever of them
        // is last does not leave one behind.
        std::string orders;
        if (unit.upgradePriority) {
            orders += "priority";
        }
        if (unit.reinforcementsActive) {
            orders += orders.empty() ? "reinforcing" : " reinforcing";
        }
        if (unit.upgradeActive) {
            orders += orders.empty() ? "upgrading" : " upgrading";
        }
        rows.push_back(DetailRow{ "Orders", orders.empty() ? "-" : orders });

        return rows;
    }

    /**@brief everything the panel shows, as text worth pasting somewhere*/
    std::string detailsAsText(const Oob::Unit& unit, const std::vector<DetailRow>& rows) {
        std::string out;
        char line[256];

        sprintf_s(line, "%s\r\n", unit.name.empty() ? "(unnamed)" : unit.name.c_str());
        out += line;

        for (size_t i = 0; i < rows.size(); i++) {
            sprintf_s(line, "  %-16s %s\r\n", rows[i].label, rows[i].value.c_str());
            out += line;
        }

        if (!unit.children.empty()) {
            out += "\r\nBelow this unit\r\n";
            sprintf_s(line, "  %-16s %d land, %d air, %d naval\r\n", "Units",
                unit.landBelow, unit.airBelow, unit.navalBelow);
            out += line;
            sprintf_s(line, "  %-16s %d, %d levels deep\r\n", "Formations",
                static_cast<int>(unit.children.size()), unit.depthBelow);
            out += line;
            sprintf_s(line, "  %-16s %d\r\n", "Regiments", unit.regimentsBelow);
            out += line;
            sprintf_s(line, "  %-16s %d\r\n", "No commander", unit.leaderlessBelow);
            out += line;
            sprintf_s(line, "  %-16s %.0f%% supply, %.0f%% fuel\r\n", "Average",
                unit.supplyAverageBelow / 10.0, unit.fuelAverageBelow / 10.0);
            out += line;
            sprintf_s(line, "  %-16s %.2f supply, %.2f fuel\r\n", "Consumes",
                (unit.supplyConsumptionBelow + unit.supplyConsumption) / 1000.0,
                (unit.fuelConsumptionBelow + unit.fuelConsumption) / 1000.0);
            out += line;
        }

        if (!selectedRegiments.empty()) {
            out += "\r\nRegiments\r\n";
            for (size_t i = 0; i < selectedRegiments.size(); i++) {
                const Oob::Regiment& regiment = selectedRegiments[i];
                sprintf_s(line, "  %-40s %6.1f strength %6.1f org\r\n",
                    regiment.name.empty() ? "(unnamed)" : regiment.name.c_str(),
                    regiment.strength / 1000.0, regiment.organisation / 1000.0);
                out += line;
            }
        }
        return out;
    }

    void drawDetails() {
        const Oob::Unit* unit = nullptr;
        for (size_t i = 0; i < tree.units.size(); i++) {
            if (tree.units[i].address == selectedAddress) {
                unit = &tree.units[i];
                break;
            }
        }

        if (unit == nullptr) {
            ImGui::TextDisabled("Select a unit on the left.");
            return;
        }

        if (regimentsFor != unit->address) {
            selectedRegiments = Oob::regiments(unit->address);
            regimentsFor = unit->address;

            // Left empty when Lua cannot be reached, at the main menu or before the
            // page module loaded; the row then shows the id on its own.
            selectedProvinceName.clear();
            if (unit->provinceId != 0 &&
                Gui::Lua::beginTableCallWithNumber(PROVINCE_NAME, unit->provinceId)) {
                if (Gui::Lua::boolField("available")) {
                    selectedProvinceName = Gui::Lua::stringField("name");
                }
                Gui::Lua::endCall();
            }
        }

        // Built before anything is drawn, so the Copy button can hand over exactly
        // what is on screen rather than a second rendering of the same numbers.
        const std::vector<DetailRow> rows = buildRows(*unit);

        ImGui::SeparatorText(unit->name.empty() ? "(unnamed)" : unit->name.c_str());
        if (ImGui::SmallButton("Copy")) {
            ImGui::SetClipboardText(detailsAsText(*unit, rows).c_str());
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Puts this unit's details, and its regiments,\n"
                "on the clipboard as text");
        }

        if (ImGui::BeginTable("unitStats", 2, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.55f);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.45f);

            for (size_t i = 0; i < rows.size(); i++) {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(rows[i].label);
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(rows[i].value.c_str());
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Below this unit");
        if (unit->children.empty()) {
            ImGui::TextDisabled("Nothing - this is the bottom of the tree.");
        }
        else {
            ImGui::Text("%d land, %d air, %d naval",
                unit->landBelow, unit->airBelow, unit->navalBelow);
            ImGui::Text("%d subordinate formations, %d levels deep",
                static_cast<int>(unit->children.size()), unit->depthBelow);
            ImGui::Text("%d regiments below", unit->regimentsBelow);
            ImGui::TextColored(unit->leaderlessBelow > 0 ? LEADERLESS : NONE_MISSING,
                "%d without a commander", unit->leaderlessBelow);
            ImGui::Text("Supply %.0f%% average, fuel %.0f%% average",
                unit->supplyAverageBelow / 10.0, unit->fuelAverageBelow / 10.0);
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Averaged over the %d units below this one, each\n"
                    "counting the same whatever its size.", unit->unitsBelow);
            }

            ImGui::Text("Consumes %.2f supply, %.2f fuel",
                (unit->supplyConsumptionBelow + unit->supplyConsumption) / 1000.0,
                (unit->fuelConsumptionBelow + unit->fuelConsumption) / 1000.0);
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("What the game itself works out for each unit,\n"
                    "so the leader and country effects are included -\n"
                    "not the sum of the unit types' base figures.");
            }
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Regiments");
        if (selectedRegiments.empty()) {
            ImGui::TextDisabled("None of its own.");
            return;
        }

        // The rest of the panel, less the line of explanation underneath it, so the
        // regiment list grows with the window like everything above it.
        const float footer = ImGui::GetTextLineHeightWithSpacing() * 2.0f;
        const float left = ImGui::GetContentRegionAvail().y - footer;
        const float regimentHeight = (left > 120.0f) ? left : 120.0f;

        if (ImGui::BeginTable("regiments", 3, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp |
            ImGuiTableFlags_ScrollY, ImVec2(0.0f, regimentHeight))) {
            ImGui::TableSetupColumn("Regiment", ImGuiTableColumnFlags_WidthStretch, 1.4f);
            ImGui::TableSetupColumn("Strength", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableSetupColumn("Org", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableHeadersRow();

            for (size_t i = 0; i < selectedRegiments.size(); i++) {
                const Oob::Regiment& regiment = selectedRegiments[i];
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(regiment.name.empty() ? "(unnamed)" : regiment.name.c_str());
                ImGui::TableNextColumn();
                ImGui::Text("%.1f", regiment.strength / 1000.0);
                ImGui::TableNextColumn();
                ImGui::Text("%.1f", regiment.organisation / 1000.0);
            }
            ImGui::EndTable();
        }
        ImGui::TextDisabled("Strength and organisation are the game's thousandths, "
            "shown as the numbers it displays.");
    }

    void drawOobBrowser() {
        if (ImGui::Button("Refresh")) {
            refresh();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &autoRefresh);
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Re-reads every five seconds. Reading a whole order of\n"
                "battle is thousands of small reads, so this is off by default.");
        }

        if (autoRefresh && GetTickCount64() - lastReadMs >= 5000) {
            refresh();
        }
        if (readTag != Gui::Selection::tag()) {
            refresh();
        }

        ImGui::SameLine();
        ImGui::TextDisabled("%s (%s)", Gui::Selection::tag().c_str(),
            Gui::Selection::source().c_str());

        if (!tree.available) {
            ImGui::TextDisabled("%s", tree.reason.empty()
                ? "Press Refresh to read the order of battle."
                : tree.reason.c_str());
            return;
        }

        ImGui::Text("%d units: %d land, %d air, %d naval, in %d regiments",
            static_cast<int>(tree.units.size()), tree.landTotal, tree.airTotal,
            tree.navalTotal, tree.regimentTotal);
        if (tree.truncated > 0) {
            ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f),
                "Stopped after %d units; the rest were not read.",
                static_cast<int>(tree.units.size()));
        }

        if (ImGui::SmallButton("Expand all")) {
            forceOpenState = 1;
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("Collapse all")) {
            forceOpenState = 0;
        }
        ImGui::SameLine();
        ImGui::SetNextItemWidth(200.0f);
        ImGui::InputTextWithHint("##filter", "filter by name", filter, sizeof(filter));

        ImGui::Spacing();

        // Whatever is left of the window, so making the window taller makes both
        // panels taller. Measured before the table is begun, because inside a cell
        // there is no "rest of the window" to ask for - the row is as tall as what
        // goes in it, so a child asking to fill the row would collapse to nothing.
        //
        // The floor keeps them usable in a short window; past that the page scrolls.
        const float remaining =
            ImGui::GetContentRegionAvail().y - ImGui::GetStyle().ItemSpacing.y;
        const float panelHeight = (remaining > 200.0f) ? remaining : 200.0f;

        if (ImGui::BeginTable("oobSplit", 2, ImGuiTableFlags_Resizable |
            ImGuiTableFlags_BordersInnerV)) {
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 1.0f);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 1.0f);

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            if (ImGui::BeginChild("tree", ImVec2(0.0f, panelHeight))) {
                visibleOrder.clear();
                openState.resize(tree.units.size(), 0);

                for (size_t i = 0; i < tree.roots.size(); i++) {
                    drawNode(tree.roots[i]);
                }

                // After drawing, so it knows what ended up on screen. Whatever it
                // changes takes effect on the next frame.
                pendingOpenIndex = -1;
                scrollToSelected = false;
                handleTreeKeys();
            }
            ImGui::EndChild();

            ImGui::TableNextColumn();
            if (ImGui::BeginChild("details", ImVec2(0.0f, panelHeight))) {
                drawDetails();
            }
            ImGui::EndChild();

            ImGui::EndTable();
        }

        // Applied for exactly one frame, so the player can still open and close
        // individual nodes afterwards.
        forceOpenState = -1;
    }

    class OobBrowserPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "OOB Browser"; }
        const char* group() const override { return "Inspector"; }
        int order() const override { return 15; }
        void draw() override { drawOobBrowser(); }
    };
}

REGISTER_GUI_PAGE(OobBrowserPage);
