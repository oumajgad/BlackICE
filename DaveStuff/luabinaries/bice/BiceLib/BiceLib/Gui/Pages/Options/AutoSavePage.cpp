// Custom Auto-Saves: two extra autosaves, one a few days before the month turns so
// there is always a save left with that month's event evaluation still ahead of it,
// and one on a wall clock so a crash can only cost so many minutes of play. See
// reversing/FINDINGS-autosave.md.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <GameState/AutoSave.hpp>

#include <cstring>
#include <string>

#include <imgui.h>

namespace {

    // Edited in place by the inputs and only handed on when editing finishes, so the
    // settings file is not rewritten on every keystroke.
    char monthlyNameBuffer[40] = {};
    char timedNameBuffer[40] = {};
    bool namesLoaded = false;

    /**@brief keeps a file name a file name, whatever was typed*/
    bool isNameSafe(const char* text) {
        for (const char* at = text; *at != 0; at++) {
            const char c = *at;
            const bool allowed = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                || (c >= '0' && c <= '9') || c == '_' || c == '-';
            if (!allowed) {
                return false;
            }
        }
        return true;
    }

    /**@brief half the width of what is left, so the label beside it still fits*/
    float inputWidth() {
        return ImGui::GetContentRegionAvail().x * 0.5f;
    }

    /**
    @brief the file name box, which both halves have one of

    @param buffer what is being edited, which is not handed on until editing finishes
    @param apply where a finished, safe name goes
    */
    void drawNameInput(char* buffer, int size, void (*apply)(const std::string&)) {
        ImGui::SetNextItemWidth(inputWidth());
        ImGui::InputText("File name", buffer, static_cast<size_t>(size));
        const bool safe = isNameSafe(buffer);
        if (ImGui::IsItemDeactivatedAfterEdit() && safe) {
            apply(std::string(buffer));
        }
        if (!safe) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Letters, digits, - and _ only.\nNot saved while it says this.");
        }
    }

    /**@brief the three files one of the saves rotates between*/
    void drawFileList(std::string (*fileName)(int)) {
        ImGui::TextDisabled("Rotating between, newest first:");
        for (int slot = 0; slot < 3; slot++) {
            ImGui::BulletText("%s", fileName(slot).c_str());
        }
    }

    /**@brief the left half: one save a month, just before the change*/
    void drawMonthly() {
        ImGui::TextWrapped(
            "The game works out which events can fire when the month changes, and only "
            "then. A save made after that moment has already had its turn, so loading "
            "it fires nothing for that month. This takes an extra save shortly before "
            "the change, which leaves one to go back to that still has the whole month "
            "ahead of it.");

        ImGui::Spacing();

        bool on = AutoSave::enabled();
        if (ImGui::Checkbox("Save before every month change", &on)) {
            AutoSave::setEnabled(on);
        }

        ImGui::Spacing();
        ImGui::SeparatorText("When");

        int days = AutoSave::daysBefore();
        ImGui::SetNextItemWidth(inputWidth());
        if (ImGui::SliderInt("Days before the 1st", &days,
            AutoSave::MIN_DAYS_BEFORE, AutoSave::MAX_DAYS_BEFORE, "%d",
            ImGuiSliderFlags_AlwaysClamp)) {
            AutoSave::setDaysBefore(days);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Counted back from the 1st of the next month, so every\n"
                "month is measured from its own end:\n\n"
                "  2 days  ->  the 30th of a 31 day month, the 26th of February\n"
                "  1 day   ->  the last day of the month");
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Name");

        drawNameInput(monthlyNameBuffer, sizeof(monthlyNameBuffer), &AutoSave::setSaveName);
        drawFileList(&AutoSave::fileName);

        ImGui::Spacing();
        ImGui::SeparatorText("This session");

        if (AutoSave::requestedCount() == 0) {
            ImGui::TextDisabled("None asked for yet.");
        }
        else {
            ImGui::Text("%d asked for, the last on %s",
                AutoSave::requestedCount(), AutoSave::lastRequested().c_str());
        }
    }

    /**@brief the right half: one save every so many minutes*/
    void drawTimed() {
        ImGui::TextWrapped(
            "A save on the clock rather than on the calendar. However fast the game is "
            "running, and whatever is happening in it, this keeps the most a crash can "
            "cost down to the interval below.");

        ImGui::Spacing();

        bool on = AutoSave::timedEnabled();
        if (ImGui::Checkbox("Save every so often", &on)) {
            AutoSave::setTimedEnabled(on);
        }

        ImGui::Spacing();
        ImGui::SeparatorText("How often");

        int minutes = AutoSave::minutes();
        ImGui::SetNextItemWidth(inputWidth());
        if (ImGui::SliderInt("Minutes", &minutes,
            AutoSave::MIN_MINUTES, AutoSave::MAX_MINUTES, "%d",
            ImGuiSliderFlags_AlwaysClamp | ImGuiSliderFlags_Logarithmic)) {
            AutoSave::setMinutes(minutes);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Real minutes, not game time.\n\n"
                "The save is taken on the first day change after the interval\n"
                "is up, which is the only moment the game asks. A paused game\n"
                "never gets there, so nothing is saved while it is paused - and\n"
                "nothing has happened to save.");
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Name");

        drawNameInput(timedNameBuffer, sizeof(timedNameBuffer), &AutoSave::setTimedSaveName);
        drawFileList(&AutoSave::timedFileName);

        ImGui::Spacing();
        ImGui::SeparatorText("This session");

        const int due = AutoSave::secondsUntilDue();
        if (due > 0) {
            ImGui::Text("Next in %d:%02d", due / 60, due % 60);
        }
        else if (due == 0) {
            ImGui::Text("Due on the next day change.");
        }
        else if (on) {
            ImGui::TextDisabled("Waiting for a game to be playing.");
        }

        if (AutoSave::timedRequestedCount() == 0) {
            ImGui::TextDisabled("None asked for yet.");
        }
        else {
            ImGui::Text("%d asked for, the last on %s",
                AutoSave::timedRequestedCount(), AutoSave::lastTimedRequested().c_str());
        }
    }

    void drawAutoSave() {
        if (!namesLoaded) {
            strncpy_s(monthlyNameBuffer, sizeof(monthlyNameBuffer),
                AutoSave::saveName().c_str(), _TRUNCATE);
            strncpy_s(timedNameBuffer, sizeof(timedNameBuffer),
                AutoSave::timedSaveName().c_str(), _TRUNCATE);
            namesLoaded = true;
        }

        ImGui::TextWrapped(
            "Two extra saves, each switched on by itself. Both sit alongside the game's "
            "own autosave: the frequency in settings.txt keeps working exactly as it "
            "did, and each of these keeps three rotating files of its own, so no set "
            "ever pushes another out.");

        // One patch serves both, so a failed install is said once rather than twice.
        if ((AutoSave::enabled() || AutoSave::timedEnabled()) && !AutoSave::hooked()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Not hooked: %s", AutoSave::status());
        }

        ImGui::Spacing();

        if (!ImGui::BeginTable("autosaveHalves", 2,
            ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_SizingStretchSame)) {
            return;
        }
        ImGui::TableNextRow();

        ImGui::TableNextColumn();
        ImGui::PushID("monthly");
        ImGui::SeparatorText("Before the month changes");
        drawMonthly();
        ImGui::PopID();

        ImGui::TableNextColumn();
        ImGui::PushID("timed");
        ImGui::SeparatorText("On a timer");
        drawTimed();
        ImGui::PopID();

        ImGui::EndTable();
    }

    class AutoSavePage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Custom Auto-Saves"; }
        const char* group() const override { return "Options"; }
        int order() const override { return 20; }
        void draw() override { drawAutoSave(); }
    };
}

REGISTER_GUI_PAGE(AutoSavePage);
