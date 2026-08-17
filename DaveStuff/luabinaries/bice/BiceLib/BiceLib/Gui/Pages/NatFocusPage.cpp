// National Focus: which focus the country is running, how many days each has banked,
// and switching between them.
//
// The bonus is tiered by how long a focus has been active, so the days matter as much
// as the choice itself - dropping a focus a fortnight before a tier lands wastes the
// whole run up to it.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <cfloat>
#include <cstdio>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.NatFocus.Collect";
    const char* SET_FOCUS = "BiceLibGui.NatFocus.Set";

    struct Focus
    {
        int index = 0;
        std::string key;
        std::string name;
        double days = 0.0;
        int tier = 0;
        double nextTier = 0.0;
        bool active = false;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    int activeFocus = 0;
    std::vector<Focus> focuses;

    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    /**
     * A focus that has been asked for but not applied yet.
     *
     * CCurrentGameState.Post queues the command rather than running it, so reading the
     * variable straight after posting still returns the old focus and the highlight
     * would jump back to it. -1 means nothing is outstanding.
     */
    int pendingFocus = -1;

    /**@brief reads the table any of the Lua calls leaves on the stack*/
    void readSnapshot() {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        tag = Gui::Lua::stringField("tag");
        activeFocus = static_cast<int>(Gui::Lua::numberField("active"));
        focuses.clear();

        if (!available) {
            return;
        }

        const int count = Gui::Lua::arrayLength("rows");
        focuses.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("rows", i)) {
                continue;
            }
            Focus focus;
            focus.index = static_cast<int>(Gui::Lua::numberField("index"));
            focus.key = Gui::Lua::stringField("key");
            focus.name = Gui::Lua::stringField("name");
            focus.days = Gui::Lua::numberField("days");
            focus.tier = static_cast<int>(Gui::Lua::numberField("tier"));
            focus.nextTier = Gui::Lua::numberField("nextTier");
            focus.active = Gui::Lua::boolField("active");
            focuses.push_back(focus);
            Gui::Lua::popArrayElement();
        }

        // The game has caught up with what was asked for.
        if (pendingFocus >= 0 && pendingFocus == activeFocus) {
            pendingFocus = -1;
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

    void setFocus(int index) {
        // Recorded before the read, so readSnapshot does not immediately clear it
        // against the focus the game has yet to change.
        pendingFocus = index;

        if (!Gui::Lua::beginTableCallWithNumber(SET_FOCUS, index)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    const char* focusName(int index) {
        if (index <= 0) {
            return "None";
        }
        for (const Focus& focus : focuses) {
            if (focus.index == index) {
                return focus.name.c_str();
            }
        }
        return "Unknown";
    }

    void drawNatFocus() {
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
        ImGui::TextDisabled("%s (%s)", tag.c_str(), Gui::Selection::source().c_str());

        ImGui::TextWrapped("The focus can be changed at any time, but the effects are "
            "not instant: a new focus takes about 90 days before it gives anything, and "
            "the old one wears off over as long as it was active for. Bonuses come in "
            "three tiers, reached after 90, 360 and 720 days.");
        ImGui::Spacing();

        // What the page shows as current: the request while one is outstanding, so the
        // highlight does not snap back for the second or two the game takes.
        const int shown = (pendingFocus >= 0) ? pendingFocus : activeFocus;

        ImGui::Text("Current focus:");
        ImGui::SameLine();
        if (pendingFocus >= 0) {
            ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f), "%s...", focusName(shown));
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("Waiting for the game to apply this");
            }
        }
        else {
            ImGui::TextUnformatted(focusName(shown));
        }
        ImGui::SameLine();
        ImGui::BeginDisabled(shown == 0);
        if (ImGui::Button("Clear")) {
            setFocus(0);
            ImGui::EndDisabled();
            return; // setFocus refilled the vector; draw the new one next frame
        }
        ImGui::EndDisabled();

        ImGui::Spacing();

        if (!ImGui::BeginTable("focuses", 6, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingFixedFit)) {
            return;
        }

        const float daysWidth = ImGui::CalcTextSize("00000").x;
        const float tierWidth = ImGui::CalcTextSize("Tier").x;
        const float buttonWidth = ImGui::CalcTextSize("Active").x + ImGui::GetStyle().FramePadding.x * 4.0f;

        ImGui::TableSetupColumn("Focus", ImGuiTableColumnFlags_WidthStretch, 0.30f);
        ImGui::TableSetupColumn("Days", ImGuiTableColumnFlags_WidthFixed, daysWidth);
        ImGui::TableSetupColumn("Tier", ImGuiTableColumnFlags_WidthFixed, tierWidth);
        ImGui::TableSetupColumn("Next tier", ImGuiTableColumnFlags_WidthStretch, 0.35f);
        ImGui::TableSetupColumn("Effect", ImGuiTableColumnFlags_WidthStretch, 0.35f);
        ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthFixed, buttonWidth);
        ImGui::TableHeadersRow();

        for (const Focus& focus : focuses) {
            const bool isShown = (focus.index == shown);

            ImGui::TableNextRow();
            ImGui::PushID(focus.key.c_str());

            ImGui::TableNextColumn();
            if (isShown) {
                ImGui::TextColored(ImVec4(0.45f, 0.85f, 0.45f, 1.0f), "%s", focus.name.c_str());
            }
            else {
                ImGui::TextUnformatted(focus.name.c_str());
            }

            ImGui::TableNextColumn();
            ImGui::Text("%.0f", focus.days);

            ImGui::TableNextColumn();
            ImGui::Text("%d", focus.tier);

            ImGui::TableNextColumn();
            if (focus.nextTier > 0.0) {
                const float fraction = static_cast<float>(focus.days / focus.nextTier);
                char overlay[64];
                sprintf_s(overlay, "%.0f / %.0f", focus.days, focus.nextTier);
                ImGui::ProgressBar(fraction, ImVec2(-FLT_MIN, ImGui::GetTextLineHeight()), overlay);
            }
            else {
                ImGui::TextDisabled("max");
            }

            ImGui::TableNextColumn();
            // Placeholder. The bonuses are triggered modifiers in
            // common/triggered_modifiers.txt, named Nat_focus_<focus>_<tier>. A tier is
            // split across _I/_II variants where it has more than five effects, because
            // that is all the game's own modifier tooltip shows - they all apply at
            // once, so a focus effects table has to merge them rather than choose. Once
            // it exists, the row's current tier goes here and the full per tier
            // breakdown into the tooltip.
            ImGui::TextDisabled("-");
            ImGui::SetItemTooltip("The focus effects are not read yet");

            ImGui::TableNextColumn();
            if (isShown) {
                ImGui::TextDisabled(pendingFocus >= 0 ? "..." : "Active");
            }
            else if (ImGui::Button("Set")) {
                setFocus(focus.index);
                ImGui::PopID();
                break; // setFocus refilled the vector; stop iterating it
            }

            ImGui::PopID();
        }
        ImGui::EndTable();
    }

    class NatFocusPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "National Focus"; }
        const char* group() const override { return "Main"; }
        int order() const override { return 80; }
        void draw() override { drawNatFocus(); }
    };
}

REGISTER_GUI_PAGE(NatFocusPage);
