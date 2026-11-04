#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>

#include <Windows.h>
#include <cmath>
#include <map>
#include <string>

#include <imgui.h>

/**
 * The player's own conversion of energy into crude oil and of crude oil into fuel - every
 * value BiceLib's customResourceConversion reads, and what the country may convert today.
 * The covert operation set_resource_conversion sets the same values from presets; this
 * sets any. See Hooks/ResourceConversion.hpp.
 */
namespace {
    const char* COLLECT = "BiceLibGui.ResourceConversion.Collect";
    const char* SET = "BiceLibGui.ResourceConversion.Set";

    /**@brief how long a posted value waits to show up before it is given up on*/
    const ULONGLONG PENDING_TIMEOUT_MS = 10000;

    struct Snapshot
    {
        bool valid = false;
        bool available = false;
        std::string reason;
        std::string tag;
        bool installed = false;
        bool played = false;
        std::map<std::string, double> values;   // by the provider's field name
        double oilRate = 0.0;
        double energyCap = 0.0;
        double energyFloor = 0.0;
        double crudeCap = 0.0;
    };

    // The provider's field names, which are what Set takes.
    const char* const FIELDS[] = {
        "usesOil", "energyPerDay", "energyKeep", "oilTarget",
        "usesFuel", "crudePerDay", "crudeKeep", "fuelTarget",
    };

    Snapshot snapshot;
    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    /**
     * Values posted and not yet applied. CCurrentGameState.Post queues a command, so the
     * variable reads as before until the game runs it; without this the field would jump
     * back to the old value for a moment after every edit.
     */
    struct Pending
    {
        double value = 0.0;
        ULONGLONG sinceMs = 0;
    };
    std::map<std::string, Pending> pending;

    // What each number box holds, and which one the player is typing in. While a box is
    // being typed in it is not refreshed from the game, which would fight the player.
    std::map<std::string, int> boxes;
    std::string editing;

    std::string status;

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            snapshot.valid = false;
            return;
        }

        snapshot.valid = true;
        snapshot.available = Gui::Lua::boolField("available");
        snapshot.reason = Gui::Lua::stringField("reason");
        snapshot.tag = Gui::Lua::stringField("tag");
        snapshot.installed = Gui::Lua::boolField("installed");
        snapshot.played = Gui::Lua::boolField("played");
        for (const char* field : FIELDS) {
            snapshot.values[field] = Gui::Lua::numberField(field);
        }
        snapshot.oilRate = Gui::Lua::numberField("oil_rate");
        snapshot.energyCap = Gui::Lua::numberField("energy_cap");
        snapshot.energyFloor = Gui::Lua::numberField("energy_floor");
        snapshot.crudeCap = Gui::Lua::numberField("crude_cap");
        Gui::Lua::endCall();

        const ULONGLONG now = GetTickCount64();
        for (auto it = pending.begin(); it != pending.end();) {
            const bool applied = std::fabs(snapshot.values[it->first] - it->second.value) < 0.0005;
            if (applied || now - it->second.sinceMs > PENDING_TIMEOUT_MS) {
                it = pending.erase(it);
            }
            else {
                ++it;
            }
        }
    }

    double shown(const std::string& field) {
        const auto it = pending.find(field);
        return it != pending.end() ? it->second.value : snapshot.values[field];
    }

    void send(const std::string& field, double value) {
        pending[field] = Pending{ value, GetTickCount64() };
        if (!Gui::Lua::beginTableCallWithStringAndNumber(SET, field.c_str(), value)) {
            status = "Could not reach Lua";
            return;
        }
        if (!Gui::Lua::boolField("ok")) {
            status = Gui::Lua::stringField("reason", "rejected");
            pending.erase(field);
        }
        else {
            status.clear();
        }
        Gui::Lua::endCall();
    }

    /**@brief a row with a whole-number box, sent when the player lets go of it*/
    void numberRow(const char* label, const std::string& field, const char* tooltip) {
        ImGui::TableNextRow();
        ImGui::TableNextColumn();
        ImGui::TextUnformatted(label);
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("%s", tooltip);
        }
        ImGui::TableNextColumn();

        int& box = boxes[field];
        if (editing != field) {
            box = static_cast<int>(std::lround(shown(field)));
        }
        ImGui::SetNextItemWidth(-FLT_MIN);
        ImGui::InputInt(("##" + field).c_str(), &box, 0, 0);
        if (ImGui::IsItemActive()) {
            editing = field;
        }
        else if (editing == field) {
            editing.clear();
        }
        if (ImGui::IsItemDeactivatedAfterEdit()) {
            if (box < 0) {
                box = 0;
            }
            send(field, box);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("%s", tooltip);
        }
        ImGui::TableNextColumn();
        if (pending.count(field) != 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "...");
        }
    }

    /**@brief one conversion: the switch, then its three values*/
    void drawConversion(const char* title, const char* uses, const char* switchTooltip,
        const char* perDayLabel, const char* perDay, const char* perDayTooltip,
        const char* keep, const char* keepTooltip,
        const char* targetLabel, const char* target, const char* targetTooltip) {
        ImGui::SeparatorText(title);

        bool on = shown(uses) != 0.0;
        if (ImGui::Checkbox((std::string("Set it myself##") + uses).c_str(), &on)) {
            send(uses, on ? 1.0 : 0.0);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("%s", switchTooltip);
        }
        if (pending.count(uses) != 0) {
            ImGui::SameLine();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "...");
        }

        ImGui::BeginDisabled(!on);
        if (ImGui::BeginTable(title, 3, ImGuiTableFlags_SizingFixedFit)) {
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthFixed,
                ImGui::CalcTextSize("Stop at crude oil").x + 8.0f);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthFixed,
                ImGui::CalcTextSize("0000000").x + 16.0f);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthFixed,
                ImGui::CalcTextSize("...").x);
            numberRow(perDayLabel, perDay, perDayTooltip);
            numberRow("Keep at least", keep, keepTooltip);
            numberRow(targetLabel, target, targetTooltip);
            ImGui::EndTable();
        }
        ImGui::EndDisabled();
    }

    void drawResourceConversion() {
        if (ImGui::Button("Refresh")) {
            refresh();
            lastSampleMs = GetTickCount64();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &autoRefresh);
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Re-read once a second while a game is running.");
        }
        if (autoRefresh) {
            const ULONGLONG now = GetTickCount64();
            if (now - lastSampleMs >= 1000) {
                refresh();
                lastSampleMs = now;
            }
        }

        ImGui::SameLine();
        if (!snapshot.valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!snapshot.available) {
            ImGui::TextDisabled("%s", snapshot.reason.c_str());
            return;
        }
        ImGui::TextDisabled("%s", snapshot.tag.c_str());

        if (!snapshot.installed) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error),
                "The conversion patch is not on, so nothing here takes effect.");
        }
        else if (!snapshot.played) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Nobody plays %s, so it converts as the game decides.", snapshot.tag.c_str());
        }
        if (!status.empty()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error), "%s", status.c_str());
        }

        drawConversion("Energy into crude oil", "usesOil",
            "Off: the game decides - it converts only while we hold more than twice as much "
            "energy as crude oil.\nOn: the values below decide, within what our IC allows.",
            "Energy a day", "energyPerDay",
            "Energy to spend each day. More than our IC allows is cut to it.",
            "energyKeep",
            "Never take energy below this. What industry needs today is never converted "
            "whatever this says.",
            "Stop at crude oil", "oilTarget",
            "Convert only while we hold less crude oil than this. 0: no limit.");
        if (snapshot.installed && snapshot.oilRate <= 0.0) {
            // BlackICE starts every country at -0.9 with hidden_coal_to_oil_base_counter, and
            // only hidden_coal_to_oil_activate - given by the synthetic industry events -
            // brings it back up. The game converts nothing at or below 0, and neither does
            // the patch, so the values above wait until then.
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "No energy can be turned into crude oil yet: technology puts the rate at %.2f, "
                "and nothing converts at 0 or below.", snapshot.oilRate);
            ImGui::TextDisabled("Developing a synthetic industry opens it. What is set above "
                "applies from then.");
        }
        else if (snapshot.installed) {
            ImGui::TextDisabled("Today: at most %.2f energy a day, each making %.2f crude oil. "
                "%.0f energy is kept for industry.",
                snapshot.energyCap, snapshot.oilRate, snapshot.energyFloor);
        }

        ImGui::Spacing();
        drawConversion("Crude oil into fuel", "usesFuel",
            "Off: the game decides - it refines until we hold more than a year of the crude "
            "oil coming in and more than twice our crude oil.\nOn: the values below decide, "
            "within what our IC allows.",
            "Crude oil a day", "crudePerDay",
            "Crude oil to refine each day. More than our IC allows is cut to it.",
            "crudeKeep",
            "Never take crude oil below this.",
            "Stop at fuel", "fuelTarget",
            "Refine only while we hold less fuel than this. 0: no limit. The game stops at "
            "99,000 whatever this says.");
        if (snapshot.installed) {
            ImGui::TextDisabled("Today: at most %.0f crude oil a day. How much fuel it makes "
                "is the game's: technology and laws.", snapshot.crudeCap);
        }

        ImGui::Spacing();
        ImGui::TextWrapped("All amounts are a day's, in stockpile units. Type a number and "
            "click away or press Enter to apply it. The covert operation in your capital, "
            "Resource conversion, sets the same values from presets.");
    }

    class ResourceConversionPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Resource Conversion"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 55; }
        void draw() override { drawResourceConversion(); }
    };
}

REGISTER_GUI_PAGE(ResourceConversionPage);
