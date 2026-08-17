// Puppets: the country's vassals and the production focus each has been given.
//
// Every action posts a command and returns the refreshed state, so the page never has
// to guess what took effect - the focus shown is always what the game reports back.

#include <Gui/GuiPage.hpp>
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
        if (!Gui::Lua::beginTableCallWithString(SELECT, tag.c_str())) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setFocus(int focusIndex) {
        if (!Gui::Lua::beginTableCallWithNumber(SET_FOCUS, focusIndex)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setDecisionEnabled(bool enabled) {
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
        bool enabled = decisionEnabled;
        if (ImGui::Checkbox("Available in game", &enabled)) {
            setDecisionEnabled(enabled);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Whether the decision for setting a puppet's focus is\n"
                "offered in game. Turning it off hides the decision.");
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
                ImGui::TextUnformatted(puppet.focus.c_str());
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        if (selected.empty()) {
            ImGui::TextDisabled("Select a puppet to set its focus.");
            return;
        }

        ImGui::Text("Set focus for %s", selected.c_str());
        for (int i = 0; i < static_cast<int>(focusNames.size()); i++) {
            const int focusIndex = i + 1; // The variable is 1 based
            if (i > 0 && (i % 4) != 0) {
                ImGui::SameLine();
            }

            const bool isCurrent = (focusIndex == selectedFocus);
            if (isCurrent) {
                ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.26f, 0.59f, 0.35f, 1.0f));
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
        const char* group() const override { return "Main"; }
        int order() const override { return 40; }
        void draw() override { drawPuppets(); }
    };
}

REGISTER_GUI_PAGE(PuppetsPage);
