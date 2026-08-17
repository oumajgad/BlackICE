// LS Sliders AI: the thresholds the mod's custom leadership AI produces officers,
// spies and diplomats between.
//
// Same form shape as the other two AI pages. The provider clamps what the engine will
// not take and reports what it changed, which is folded back into the fields here so
// the page never shows a value the game did not get.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.LsSliders.Collect";
    const char* SET_VALUE = "BiceLibGui.LsSliders.SetValue";
    const char* DISCARD = "BiceLibGui.LsSliders.Discard";
    const char* COMMIT = "BiceLibGui.LsSliders.Commit";
    const char* SET_ACTIVE = "BiceLibGui.LsSliders.SetActive";

    struct Row
    {
        std::string key;
        std::string name;
        double maximum = 0.0; // 0 means no cap
        double lower = 0.0;
        double upper = 0.0;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    bool active = false;
    bool configured = false;

    std::vector<Row> rows;
    bool bufferNco = true;

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

        bufferNco = Gui::Lua::boolField("bufferNco", true);
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
            row.maximum = Gui::Lua::numberField("maximum");
            row.lower = Gui::Lua::numberField("lower");
            row.upper = Gui::Lua::numberField("upper");
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

    /**@brief writes a value the provider clamped back into the field it came from*/
    void applyCorrection(const std::string& field, double value) {
        for (Row& row : rows) {
            if (field == row.key + "Lower") {
                row.lower = value;
                return;
            }
            if (field == row.key + "Upper") {
                row.upper = value;
                return;
            }
        }
    }

    bool apply() {
        status.clear();
        statusIsError = false;

        Gui::Lua::call(DISCARD);

        for (const Row& row : rows) {
            if (!stage(row.key + "Lower", row.lower) ||
                !stage(row.key + "Upper", row.upper)) {
                return false;
            }
        }
        if (!stage("bufferProdNco", bufferNco ? 1 : 0)) {
            return false;
        }

        if (!Gui::Lua::beginTableCall(COMMIT)) {
            valid = false;
            return false;
        }
        const bool ok = Gui::Lua::boolField("ok");
        if (ok) {
            const int count = Gui::Lua::arrayLength("corrections");
            for (int i = 0; i < count; i++) {
                if (!Gui::Lua::pushArrayElement("corrections", i)) {
                    continue;
                }
                applyCorrection(Gui::Lua::stringField("field"), Gui::Lua::numberField("value"));
                Gui::Lua::popArrayElement();
            }

            status = (count > 0) ? "Applied, with values corrected to fit the limits"
                                 : "Applied";
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

    void drawLsSliders() {
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
        if (!ImGui::BeginTable("categories", 3, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            return;
        }

        ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 0.8f);
        ImGui::TableSetupColumn("Lower", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableSetupColumn("Upper", ImGuiTableColumnFlags_WidthStretch, 1.0f);
        ImGui::TableHeadersRow();

        for (Row& row : rows) {
            ImGui::TableNextRow();
            ImGui::PushID(row.key.c_str());

            ImGui::TableNextColumn();
            ImGui::TextUnformatted(row.name.c_str());
            if (row.maximum > 0.0) {
                ImGui::SetItemTooltip("The engine will not take more than %.0f", row.maximum);
            }

            ImGui::TableNextColumn();
            ImGui::SetNextItemWidth(-FLT_MIN);
            if (ImGui::InputDouble("##lower", &row.lower, 0.0, 0.0, "%.0f")) {
                markEdited();
            }

            ImGui::TableNextColumn();
            ImGui::SetNextItemWidth(-FLT_MIN);
            if (ImGui::InputDouble("##upper", &row.upper, 0.0, 0.0, "%.0f")) {
                markEdited();
            }

            ImGui::PopID();
        }
        ImGui::EndTable();

        ImGui::Spacing();
        if (ImGui::Checkbox("Buffer NCOs", &bufferNco)) {
            markEdited();
        }
        ImGui::SetItemTooltip("Keeps producing officers for 10 more days, "
            "for a buffer of around 500");

        ImGui::Spacing();
        ImGui::TextWrapped("This only takes effect with \"Slider AI\" selected in the "
            "technology window. The numbers are resource amounts rather than slider "
            "positions: once a resource falls below its lower threshold the AI produces "
            "it until the upper threshold is reached, and how much leadership that "
            "takes is its own decision.");
        ImGui::Spacing();
        ImGui::TextWrapped("Officers cannot be set above 110, which is an engine limit. "
            "Diplomacy takes influences already running into account. Leadership is "
            "handed out to officers first, then spies, then diplomacy, and research "
            "takes whatever is left.");
        ImGui::Spacing();
        ImGui::TextColored(ImVec4(0.85f, 0.55f, 0.35f, 1.0f), "Warning:");
        ImGui::SameLine();
        ImGui::TextWrapped("with the slider AI on, the game stops automatically "
            "continuing research once a level finishes.");
    }

    class LsSlidersAiPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "LS Sliders AI"; }
        const char* group() const override { return "Main"; }
        int order() const override { return 120; }
        void draw() override { drawLsSliders(); }
    };
}

REGISTER_GUI_PAGE(LsSlidersAiPage);
