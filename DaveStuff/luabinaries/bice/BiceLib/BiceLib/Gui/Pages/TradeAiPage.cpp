// Trade AI: the buffers and caps the mod's custom trade AI trades against.
//
// A form rather than a report, so it does not refresh its values on a timer - that
// would overwrite whatever is half typed. The values are loaded once, edited locally,
// and written as one set by Apply. Only the status line is polled.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.TradeAi.Collect";
    const char* SET_VALUE = "BiceLibGui.TradeAi.SetValue";
    const char* DISCARD = "BiceLibGui.TradeAi.Discard";
    const char* COMMIT = "BiceLibGui.TradeAi.Commit";
    const char* SET_ACTIVE = "BiceLibGui.TradeAi.SetActive";

    struct Row
    {
        std::string key;
        std::string name;
        bool hasCaps = false;
        double buffer = 0.0;
        double saleCap = 0.0;
        double cancelCap = 0.0;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    bool active = false;
    bool configured = false;

    std::vector<Row> rows;
    double maxDailySell = 0.0;

    bool loaded = false;
    bool dirty = false;
    std::string status;
    bool statusIsError = false;

    // -1 when nothing is outstanding. CCurrentGameState.Post queues rather than
    // applies, so the toggle would otherwise flip back for a second or two.
    int pendingActive = -1;

    ULONGLONG lastPollMs = 0;

    /**
    @brief reads the table a Lua call left on the stack

    @param takeValues false to keep what is being edited and update only the status,
                      which is what the poll wants
    */
    void readSnapshot(bool takeValues) {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");

        const std::string newTag = Gui::Lua::stringField("tag");
        // A different country's settings have nothing to do with the ones on screen.
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

        maxDailySell = Gui::Lua::numberField("maxDailySell");
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
            row.hasCaps = Gui::Lua::boolField("hasCaps");
            row.buffer = Gui::Lua::numberField("buffer");
            row.saleCap = Gui::Lua::numberField("saleCap");
            row.cancelCap = Gui::Lua::numberField("cancelCap");
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

    /**@brief stages one field; false means the call itself failed*/
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

    /**@brief stages every field and asks the provider to post them as one set*/
    bool apply() {
        status.clear();
        statusIsError = false;

        // Anything left over from an abandoned attempt would be posted along with this
        // one, so the staging area starts empty.
        Gui::Lua::call(DISCARD);

        if (!stage("MaxDailySell", maxDailySell)) {
            return false;
        }
        for (const Row& row : rows) {
            if (!stage(row.key + "_Buffer", row.buffer)) {
                return false;
            }
            if (row.hasCaps) {
                if (!stage(row.key + "_BufferSaleCap", row.saleCap) ||
                    !stage(row.key + "_BufferCancelCap", row.cancelCap)) {
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
            // Deliberately not re-reading the values: the commands are still queued, so
            // the game would hand back the settings from before this Apply.
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
        // Switching it on adopts what is on screen, as the wx page did - otherwise the
        // AI would start on whatever was last committed.
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

    void drawNumber(const char* id, double* value, const char* format) {
        ImGui::SetNextItemWidth(-FLT_MIN);
        if (ImGui::InputDouble(id, value, 0.0, 0.0, format)) {
            markEdited();
        }
    }

    void drawTradeAi() {
        // The status is polled, the values are not: poll() leaves the edit buffers
        // alone. Until the first load succeeds the same timer paces the retries, so a
        // page opened at the main menu does not call Lua every frame.
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
        ImGui::SetNextItemWidth(120.0f);
        if (ImGui::InputDouble("Max daily deficit", &maxDailySell, 0.0, 0.0, "%.0f")) {
            markEdited();
        }
        ImGui::SetItemTooltip("The largest daily money deficit the AI may run "
            "to pay for its purchases");

        ImGui::Spacing();
        if (!ImGui::BeginTable("resources", 4, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            return;
        }

        ImGui::TableSetupColumn("Resource", ImGuiTableColumnFlags_WidthStretch, 0.8f);
        ImGui::TableSetupColumn("Daily surplus", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableSetupColumn("Sell above", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableSetupColumn("Stockpile", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableHeadersRow();

        for (Row& row : rows) {
            ImGui::TableNextRow();
            ImGui::PushID(row.key.c_str());

            ImGui::TableNextColumn();
            ImGui::TextUnformatted(row.name.c_str());

            ImGui::TableNextColumn();
            // Fractions matter here: the oil default is a quarter a day.
            drawNumber("##buffer", &row.buffer, "%.2f");

            ImGui::TableNextColumn();
            if (row.hasCaps) {
                drawNumber("##sale", &row.saleCap, "%.0f");
            }
            else {
                ImGui::TextDisabled("-");
            }

            ImGui::TableNextColumn();
            if (row.hasCaps) {
                drawNumber("##cancel", &row.cancelCap, "%.0f");
            }
            else {
                ImGui::TextDisabled("-");
            }

            ImGui::PopID();
        }
        ImGui::EndTable();

        ImGui::Spacing();
        ImGui::TextWrapped("Daily surplus is how much of a resource the AI keeps coming "
            "in each day beyond what the country actually needs. It only sells once the "
            "stockpile is above \"Sell above\", and cancels its own purchases once the "
            "stockpile is above \"Stockpile\". Supplies are left to the AI's own "
            "judgement.");
    }

    class TradeAiPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Trade AI"; }
        const char* group() const override { return "Main"; }
        int order() const override { return 100; }
        void draw() override { drawTradeAi(); }
    };
}

REGISTER_GUI_PAGE(TradeAiPage);
