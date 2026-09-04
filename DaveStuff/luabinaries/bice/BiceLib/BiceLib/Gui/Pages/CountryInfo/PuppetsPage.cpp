// Puppets: the country's vassals and the production focus each has been given.
//
// Actions post a command and re-read, but the game applies commands on its own
// schedule, so a fresh read still shows the old value. Requests are therefore held as
// pending and displayed as asked for until the game confirms them.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Puppets.Collect";
    const char* SELECT = "BiceLibGui.Puppets.Select";
    const char* SET_FOCUS = "BiceLibGui.Puppets.SetFocus";
    const char* SET_DECISION = "BiceLibGui.Puppets.SetDecisionEnabled";

    struct Puppet
    {
        std::string tag;
        std::string focus;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::vector<Puppet> puppets;
    std::vector<std::string> focusNames;
    std::string selected;
    int selectedFocus = 0;
    bool decisionEnabled = false;

    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    /**
     * Values the game has been asked for but has not applied yet.
     *
     * CCurrentGameState.Post queues a command rather than executing it, so reading
     * straight after posting still returns the old value and the UI would appear to
     * ignore the click. The request is shown, flagged, and dropped once the game
     * reports the same thing. 0 means nothing pending.
     */
    int pendingFocus = 0;
    int pendingDecision = -1; // -1 none, 0 disabled, 1 enabled

    /**@brief reads the state table any of the Lua calls leaves on the stack*/
    void readSnapshot() {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        puppets.clear();
        focusNames.clear();

        if (!available) {
            return;
        }

        const int count = Gui::Lua::arrayLength("puppets");
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("puppets", i)) {
                continue;
            }
            Puppet puppet;
            puppet.tag = Gui::Lua::stringField("tag");
            puppet.focus = Gui::Lua::stringField("focus");
            puppets.push_back(puppet);
            Gui::Lua::popArrayElement();
        }

        const int focusCount = Gui::Lua::arrayLength("focus_names");
        for (int i = 0; i < focusCount; i++) {
            focusNames.push_back(Gui::Lua::arrayStringAt("focus_names", i));
        }

        selected = Gui::Lua::stringField("selected");
        selectedFocus = static_cast<int>(Gui::Lua::numberField("selected_focus"));
        decisionEnabled = Gui::Lua::boolField("decision_enabled");

        // Requests the game has now applied are no longer pending.
        if (pendingFocus != 0 && pendingFocus == selectedFocus) {
            pendingFocus = 0;
        }
        if (pendingDecision >= 0 && (pendingDecision != 0) == decisionEnabled) {
            pendingDecision = -1;
        }
    }

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void selectPuppet(const std::string& tag) {
        pendingFocus = 0; // Belongs to the puppet being left behind
        if (!Gui::Lua::beginTableCallWithString(SELECT, tag.c_str())) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setFocus(int focusIndex) {
        pendingFocus = focusIndex; // Before the read, which cannot see it applied yet
        if (!Gui::Lua::beginTableCallWithNumber(SET_FOCUS, focusIndex)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setDecisionEnabled(bool enabled) {
        pendingDecision = enabled ? 1 : 0;
        if (!Gui::Lua::beginTableCallWithNumber(SET_DECISION, enabled ? 1 : 0)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void drawPuppets() {
        if (ImGui::Button("Refresh")) {
            refresh();
            lastSampleMs = GetTickCount64();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &autoRefresh);

        if (autoRefresh) {
            const ULONGLONG now = GetTickCount64();
            if (now - lastSampleMs >= 2000) {
                refresh();
                lastSampleMs = now;
            }
        }

        ImGui::SameLine();
        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return;
        }
        ImGui::TextDisabled("%s", Gui::Selection::tag().c_str());

        ImGui::SeparatorText("Puppet focus decision");
        bool enabled = (pendingDecision >= 0) ? (pendingDecision != 0) : decisionEnabled;
        if (ImGui::Checkbox("Available in game", &enabled)) {
            setDecisionEnabled(enabled);
        }
        // Checked here, while the checkbox is still the last item.
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Whether the decision for setting a puppet's focus is\n"
                "offered in game. Turning it off hides the decision.");
        }
        if (pendingDecision >= 0) {
            ImGui::SameLine();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "(pending)");
        }

        ImGui::SeparatorText("Vassals");
        if (puppets.empty()) {
            ImGui::TextDisabled("This country has no puppets.");
            return;
        }

        if (ImGui::BeginTable("puppets", 2, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner |
            ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("Puppet", ImGuiTableColumnFlags_WidthStretch, 0.4f);
            ImGui::TableSetupColumn("Focus", ImGuiTableColumnFlags_WidthStretch, 0.6f);
            ImGui::TableHeadersRow();

            for (const Puppet& puppet : puppets) {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                if (ImGui::Selectable(puppet.tag.c_str(), puppet.tag == selected,
                    ImGuiSelectableFlags_SpanAllColumns)) {
                    selectPuppet(puppet.tag);
                }

                ImGui::TableNextColumn();
                // The row for the selected puppet has to show a pending focus too,
                // otherwise the buttons below say one thing and the table another.
                const bool rowPending = (pendingFocus != 0 && puppet.tag == selected);
                if (rowPending && pendingFocus - 1 < static_cast<int>(focusNames.size())) {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "%s...",
                        focusNames[pendingFocus - 1].c_str());
                }
                else {
                    ImGui::TextUnformatted(puppet.focus.c_str());
                }
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        if (selected.empty()) {
            ImGui::TextDisabled("Select a puppet to set its focus.");
            return;
        }

        if (pendingFocus != 0) {
            ImGui::Text("Set focus for %s", selected.c_str());
            ImGui::SameLine();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "(waiting for the game)");
        }
        else {
            ImGui::Text("Set focus for %s", selected.c_str());
        }
        for (int i = 0; i < static_cast<int>(focusNames.size()); i++) {
            const int focusIndex = i + 1; // The variable is 1 based
            if (i > 0 && (i % 4) != 0) {
                ImGui::SameLine();
            }

            const int shownFocus = (pendingFocus != 0) ? pendingFocus : selectedFocus;
            const bool isCurrent = (focusIndex == shownFocus);
            if (isCurrent) {
                ImGui::PushStyleColor(ImGuiCol_Button, Gui::Theme::mark(Gui::Theme::Mark::SuccessFill));
            }
            if (ImGui::Button(focusNames[i].c_str(), ImVec2(84.0f, 0.0f))) {
                setFocus(focusIndex);
            }
            if (isCurrent) {
                ImGui::PopStyleColor();
            }
        }
    }

    class PuppetsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Puppets"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 40; }
        void draw() override { drawPuppets(); }
    };
}

REGISTER_GUI_PAGE(PuppetsPage);
