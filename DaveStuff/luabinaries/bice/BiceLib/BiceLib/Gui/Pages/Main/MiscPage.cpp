// Misc: the switches that did not belong anywhere else - whether the mod's own
// decisions are offered to the player.
//
// The wx page had a pair of On/Off buttons and a state box per switch; a checkbox says
// the same thing in one control.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <string>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Misc.Collect";
    const char* SET_TRADE = "BiceLibGui.Misc.SetTradeHidden";
    const char* SET_MINES = "BiceLibGui.Misc.SetMinesHidden";

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;

    bool tradeHidden = false;
    bool minesHidden = false;

    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    /**
     * Toggles asked for but not applied yet, -1 when nothing is outstanding.
     *
     * Both switches go through CCurrentGameState.Post, which queues rather than
     * applies, so reading one straight back returns the old value and the checkbox
     * would snap back for a second.
     */
    int pendingTrade = -1;
    int pendingMines = -1;

    void readSnapshot() {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        tag = Gui::Lua::stringField("tag");

        if (!available) {
            return;
        }

        tradeHidden = Gui::Lua::boolField("tradeHidden");
        minesHidden = Gui::Lua::boolField("minesHidden");

        if (pendingTrade >= 0 && pendingTrade == (tradeHidden ? 1 : 0)) {
            pendingTrade = -1;
        }
        if (pendingMines >= 0 && pendingMines == (minesHidden ? 1 : 0)) {
            pendingMines = -1;
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

    void set(const char* path, bool value) {
        if (!Gui::Lua::beginTableCallWithNumber(path, value ? 1 : 0)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    /**@brief a switch whose new value has to survive until the game reports it back*/
    void drawPendingCheckbox(const char* label, const char* path, bool actual, int* pending) {
        const bool isPending = (*pending >= 0);
        bool shown = isPending ? (*pending == 1) : actual;

        if (ImGui::Checkbox(label, &shown)) {
            // Recorded before the call, so readSnapshot does not clear it against the
            // value the game has yet to change.
            *pending = shown ? 1 : 0;
            set(path, shown);
        }

        if (isPending) {
            ImGui::SameLine();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "waiting...");
            ImGui::SetItemTooltip("Waiting for the game to apply this");
        }
    }

    void drawMisc() {
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

        ImGui::SeparatorText("Decisions");
        drawPendingCheckbox("Hide the resource trading decisions", SET_TRADE,
            tradeHidden, &pendingTrade);
        drawPendingCheckbox("Hide the mine expansion decisions", SET_MINES,
            minesHidden, &pendingMines);
        ImGui::TextWrapped("Hiding a decision only takes it out of your own decision "
            "list. The AI carries on using it either way, so this is about a tidy list "
            "rather than about how the game plays.");
    }

    class MiscPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Misc"; }
        const char* group() const override { return "Main"; }
        int order() const override { return 130; }
        void draw() override { drawMisc(); }
    };
}

REGISTER_GUI_PAGE(MiscPage);
