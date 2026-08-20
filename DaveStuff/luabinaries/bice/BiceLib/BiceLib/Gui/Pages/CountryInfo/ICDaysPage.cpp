#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>

#include <Windows.h>
#include <string>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.ICDays.Collect";
    const char* SET_INVESTMENT = "BiceLibGui.ICDays.SetInvestment";

    const int INVESTMENT_STEPS[] = { 20, 30, 40, 50, 60 };

    struct Snapshot
    {
        bool valid = false;
        bool available = false;
        std::string reason;
        std::string tag;
        double icDaysLeft = 0.0;
        double baseIc = 0.0;
        double investment = 0.0;
        double dailyReduction = 0.0;
    };

    Snapshot snapshot;
    ULONGLONG lastSampleMs = 0;

    // Safe to leave on: Gui::Lua::available() refuses to call anything outside a
    // running session, so nothing happens at the main menu.
    bool autoRefresh = true;

    /**
     * Investment the game has been asked for but has not applied yet, 0 for none.
     *
     * CCurrentGameState.Post queues a command rather than executing it, so reading the
     * variable straight after posting still returns the old value and the highlight
     * would not move until the next automatic refresh.
     */
    int pendingInvestment = 0;

    /**
    @brief pulls a fresh snapshot from Lua

    The underlying values change once per game day, so this is called on a timer
    rather than per frame: a Lua call every frame would be pure waste.
    */
    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            snapshot.valid = false;
            return;
        }

        snapshot.valid = true;
        snapshot.available = Gui::Lua::boolField("available");
        snapshot.reason = Gui::Lua::stringField("reason");
        snapshot.tag = Gui::Lua::stringField("tag");
        snapshot.icDaysLeft = Gui::Lua::numberField("ic_days_left");
        snapshot.baseIc = Gui::Lua::numberField("base_ic");
        snapshot.investment = Gui::Lua::numberField("investment");
        snapshot.dailyReduction = Gui::Lua::numberField("daily_reduction");

        // A request the game has now applied is no longer pending.
        if (pendingInvestment != 0 && static_cast<int>(snapshot.investment) == pendingInvestment) {
            pendingInvestment = 0;
        }

        Gui::Lua::endCall();
    }

    void drawICDays() {
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

        ImGui::Separator();

        if (ImGui::BeginTable("icdays", 2,
            ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_SizingFixedFit)) {
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch);
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthFixed,
                ImGui::CalcTextSize("000000").x);

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted("IC days left");
            ImGui::TableNextColumn();
            ImGui::Text("%.2f", snapshot.icDaysLeft);

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted("Base IC");
            ImGui::TableNextColumn();
            ImGui::Text("%.0f", snapshot.baseIc);

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted("Current investment");
            ImGui::TableNextColumn();
            if (pendingInvestment != 0) {
                ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f), "%d%%...", pendingInvestment);
            }
            else {
                ImGui::Text("%.0f%%", snapshot.investment);
            }

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted("Daily IC days reduction");
            ImGui::TableNextColumn();
            if (pendingInvestment != 0) {
                // Derived from the investment, so it lags with it.
                ImGui::TextDisabled("...");
            }
            else {
                ImGui::Text("%.0f", snapshot.dailyReduction);
            }

            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Set investment");

        for (int i = 0; i < static_cast<int>(sizeof(INVESTMENT_STEPS) / sizeof(INVESTMENT_STEPS[0])); i++) {
            const int step = INVESTMENT_STEPS[i];
            if (i > 0) {
                ImGui::SameLine();
            }

            char label[16];
            sprintf_s(label, "%d%%", step);

            const int shownInvestment = (pendingInvestment != 0)
                ? pendingInvestment : static_cast<int>(snapshot.investment);
            const bool isCurrent = (shownInvestment == step);
            if (isCurrent) {
                ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.26f, 0.59f, 0.35f, 1.0f));
            }
            if (ImGui::Button(label, ImVec2(56.0f, 0.0f))) {
                pendingInvestment = step; // Before the read, which cannot see it yet
                Gui::Lua::callWithNumber(SET_INVESTMENT, step);
                refresh();
            }
            if (isCurrent) {
                ImGui::PopStyleColor();
            }
        }

        ImGui::Spacing();
        ImGui::TextWrapped("Investment converts base IC into IC days at the shown daily rate.");
    }

    class ICDaysPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "IC Days"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 30; }
        void draw() override { drawICDays(); }
    };
}

REGISTER_GUI_PAGE(ICDaysPage);
