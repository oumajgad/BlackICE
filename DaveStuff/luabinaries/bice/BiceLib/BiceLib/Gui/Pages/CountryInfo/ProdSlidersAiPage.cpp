// Prod. Sliders AI: how the mod's custom production AI splits IC between the
// production categories.
//
// Same shape as the Trade AI page: a form, loaded once and written as one set, with
// only the status polled. The priority rule is enforced by the provider - this page
// just marks the clash so it is visible before Apply is pressed.

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
    const char* COLLECT = "BiceLibGui.ProdSliders.Collect";
    const char* SET_VALUE = "BiceLibGui.ProdSliders.SetValue";
    const char* DISCARD = "BiceLibGui.ProdSliders.Discard";
    const char* COMMIT = "BiceLibGui.ProdSliders.Commit";
    const char* SET_ACTIVE = "BiceLibGui.ProdSliders.SetActive";

    const char* const MODES[] = { "Percentage", "Flat IC" };

    struct Row
    {
        std::string key;
        std::string name;
        std::string extra;
        bool fixedMode = false;

        int prio = 0;
        double amount = 0.0;
        int mode = 0;

        double limit = 0.0;
        bool limitActive = false;
        double goal = 0.0;
        bool goalActive = false;
        bool reduceDissent = false;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    bool active = false;
    bool configured = false;

    std::vector<Row> rows;

    bool loaded = false;
    bool dirty = false;
    std::string status;
    bool statusIsError = false;
    int pendingActive = -1;
    ULONGLONG lastPollMs = 0;

    void readSnapshot(bool takeValues) {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");

        const std::string newTag = Gui::Lua::stringField("tag");
        const bool countryChanged = (newTag != tag);
        tag = newTag;

        if (!available) {
            return;
        }

        active = Gui::Lua::boolField("active");
        configured = Gui::Lua::boolField("configured");

        if (pendingActive >= 0 && pendingActive == (active ? 1 : 0)) {
            pendingActive = -1;
        }

        if (!takeValues && !countryChanged) {
            return;
        }

        rows.clear();
        const int count = Gui::Lua::arrayLength("rows");
        rows.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("rows", i)) {
                continue;
            }
            Row row;
            row.key = Gui::Lua::stringField("key");
            row.name = Gui::Lua::stringField("name");
            row.extra = Gui::Lua::stringField("extra");
            row.fixedMode = Gui::Lua::boolField("fixedMode");
            row.prio = static_cast<int>(Gui::Lua::numberField("prio"));
            row.amount = Gui::Lua::numberField("amount");
            row.mode = static_cast<int>(Gui::Lua::numberField("mode"));
            row.limit = Gui::Lua::numberField("limit");
            row.limitActive = Gui::Lua::boolField("limitActive");
            row.goal = Gui::Lua::numberField("goal");
            row.goalActive = Gui::Lua::boolField("goalActive");
            row.reduceDissent = Gui::Lua::boolField("reduceDissent");
            rows.push_back(row);
            Gui::Lua::popArrayElement();
        }

        loaded = true;
        dirty = false;
    }

    void reload() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot(true);
        Gui::Lua::endCall();
    }

    void poll() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot(false);
        Gui::Lua::endCall();
    }

    bool stage(const std::string& field, double value) {
        if (!Gui::Lua::beginTableCallWithStringAndNumber(SET_VALUE, field.c_str(), value)) {
            valid = false;
            return false;
        }
        const bool ok = Gui::Lua::boolField("ok");
        if (!ok) {
            status = Gui::Lua::stringField("reason", "rejected");
            statusIsError = true;
        }
        Gui::Lua::endCall();
        return ok;
    }

    bool apply() {
        status.clear();
        statusIsError = false;

        Gui::Lua::call(DISCARD);

        for (const Row& row : rows) {
            if (!stage(row.key + "Prio", row.prio) ||
                !stage(row.key + "Amount", row.amount) ||
                !stage(row.key + "InvestMode", row.mode)) {
                return false;
            }

            if (row.extra == "limit") {
                if (!stage(row.key + "Limit", row.limit) ||
                    !stage(row.key + "Limit_active", row.limitActive ? 1 : 0)) {
                    return false;
                }
            }
            else if (row.extra == "goal") {
                if (!stage("supplyGoal", row.goal) ||
                    !stage("supplyGoal_active", row.goalActive ? 1 : 0)) {
                    return false;
                }
            }
            else if (row.extra == "dissent") {
                if (!stage("reduceDissent", row.reduceDissent ? 1 : 0)) {
                    return false;
                }
            }
        }

        if (!Gui::Lua::beginTableCall(COMMIT)) {
            valid = false;
            return false;
        }
        const bool ok = Gui::Lua::boolField("ok");
        if (ok) {
            status = "Applied";
            statusIsError = false;
            dirty = false;
        }
        else {
            status = Gui::Lua::stringField("reason", "rejected");
            statusIsError = true;
        }
        Gui::Lua::endCall();
        return ok;
    }

    void setActive(bool enabled) {
        if (enabled && !apply()) {
            return;
        }

        pendingActive = enabled ? 1 : 0;

        if (!Gui::Lua::beginTableCallWithNumber(SET_ACTIVE, enabled ? 1 : 0)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot(false);
        Gui::Lua::endCall();
    }

    /**
    @brief records that the form no longer matches the game

    Clears the result of the last Apply along with it: "Applied" describes the values
    as they were when the button was pressed, so leaving it up next to a changed field
    would claim something that is no longer true.
    */
    void markEdited() {
        dirty = true;
        status.clear();
        statusIsError = false;
    }

    /**@brief true if another category already claims this row's priority*/
    bool priorityClashes(const Row& row) {
        for (const Row& other : rows) {
            if (other.key != row.key && other.prio == row.prio) {
                return true;
            }
        }
        return false;
    }

    void drawProdSliders() {
        const ULONGLONG now = GetTickCount64();
        if (lastPollMs == 0 || now - lastPollMs >= 2000) {
            if (loaded) {
                poll();
            }
            else {
                reload();
            }
            lastPollMs = now;
        }

        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return;
        }

        const bool shownActive = (pendingActive >= 0) ? (pendingActive == 1) : active;

        if (ImGui::Button(shownActive ? "Disable" : "Enable")) {
            setActive(!shownActive);
        }
        ImGui::SameLine();
        if (pendingActive >= 0) {
            ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f),
                shownActive ? "Active..." : "Inactive...");
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Waiting for the game to apply this");
            }
        }
        else if (shownActive) {
            ImGui::TextColored(ImVec4(0.45f, 0.85f, 0.45f, 1.0f), "Active");
        }
        else {
            ImGui::TextDisabled("Inactive");
        }

        ImGui::SameLine();
        if (ImGui::Button("Apply")) {
            apply();
        }
        ImGui::SameLine();
        if (ImGui::Button("Reload")) {
            reload();
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Reads the settings back from the game, discarding edits");
        }

        ImGui::SameLine();
        ImGui::TextDisabled("%s (%s)", tag.c_str(), Gui::Selection::source().c_str());

        if (!configured) {
            ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f),
                "Never configured - showing defaults. Apply to adopt them.");
        }
        if (!status.empty()) {
            ImGui::TextColored(statusIsError ? ImVec4(0.85f, 0.35f, 0.35f, 1.0f)
                                             : ImVec4(0.45f, 0.85f, 0.45f, 1.0f),
                "%s", status.c_str());
        }
        else if (dirty) {
            ImGui::TextDisabled("Edited - press Apply to send it to the game");
        }

        ImGui::Spacing();
        if (!ImGui::BeginTable("categories", 5, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            return;
        }

        ImGui::TableSetupColumn("Category", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableSetupColumn("Priority", ImGuiTableColumnFlags_WidthStretch, 0.6f);
        ImGui::TableSetupColumn("Amount", ImGuiTableColumnFlags_WidthStretch, 0.7f);
        ImGui::TableSetupColumn("Mode", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableSetupColumn("Extra", ImGuiTableColumnFlags_WidthStretch, 1.4f);
        ImGui::TableHeadersRow();

        for (Row& row : rows) {
            ImGui::TableNextRow();
            ImGui::PushID(row.key.c_str());

            ImGui::TableNextColumn();
            ImGui::TextUnformatted(row.name.c_str());

            ImGui::TableNextColumn();
            const bool clash = priorityClashes(row);
            if (clash) {
                ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.45f, 0.15f, 0.15f, 1.0f));
            }
            ImGui::SetNextItemWidth(-FLT_MIN);
            if (ImGui::InputInt("##prio", &row.prio, 0, 0)) {
                markEdited();
            }
            if (clash) {
                ImGui::PopStyleColor();
                ImGui::SetItemTooltip("Another category already uses this priority");
            }

            ImGui::TableNextColumn();
            ImGui::SetNextItemWidth(-FLT_MIN);
            if (ImGui::InputDouble("##amount", &row.amount, 0.0, 0.0, "%.0f")) {
                markEdited();
            }

            ImGui::TableNextColumn();
            if (row.fixedMode) {
                // Lend lease is IC only, as it was in the wx page.
                ImGui::TextDisabled("Flat IC");
            }
            else {
                ImGui::SetNextItemWidth(-FLT_MIN);
                if (Gui::wheelCombo("##mode", &row.mode, MODES, IM_ARRAYSIZE(MODES))) {
                    markEdited();
                }
            }

            ImGui::TableNextColumn();
            if (row.extra == "limit") {
                if (ImGui::Checkbox("Limit", &row.limitActive)) {
                    markEdited();
                }
                ImGui::SameLine();
                ImGui::SetNextItemWidth(-FLT_MIN);
                if (ImGui::InputDouble("##limit", &row.limit, 0.0, 0.0, "%.0f")) {
                    markEdited();
                }
            }
            else if (row.extra == "goal") {
                if (ImGui::Checkbox("Goal", &row.goalActive)) {
                    markEdited();
                }
                ImGui::SameLine();
                ImGui::SetNextItemWidth(-FLT_MIN);
                if (ImGui::InputDouble("##goal", &row.goal, 0.0, 0.0, "%.0f")) {
                    markEdited();
                }
            }
            else if (row.extra == "dissent") {
                if (ImGui::Checkbox("Reduce dissent", &row.reduceDissent)) {
                    markEdited();
                }
            }

            ImGui::PopID();
        }
        ImGui::EndTable();

        ImGui::Spacing();
        ImGui::TextWrapped("This only takes effect with \"Prioritize Upgrades/Custom\" "
            "selected in the production window. IC is handed out in priority order, "
            "starting at 1, and each priority may only be used once. A category that "
            "cannot be paid for in full takes whatever is left and the ones after it "
            "get nothing; anything still unspent goes to production. Amount is read "
            "either as a share of what the category needs or as a flat IC figure, "
            "depending on its mode.");
        ImGui::Spacing();
        ImGui::TextWrapped("Upgrades and reinforcement can be capped so an emergency "
            "cannot swallow the whole budget. Supply can be given a stockpile goal, "
            "which it puts a little extra IC towards until it is reached. Consumer "
            "goods can take 50%% more IC while there is dissent.");
    }

    class ProdSlidersAiPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Prod. Sliders AI"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 110; }
        void draw() override { drawProdSliders(); }
    };
}

REGISTER_GUI_PAGE(ProdSlidersAiPage);
