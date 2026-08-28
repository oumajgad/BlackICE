// Custom Auto-Saves: an extra autosave a few days before the month turns, so there is
// always a save left with that month's event evaluation still ahead of it. See
// reversing/FINDINGS-autosave.md.

#include <Gui/GuiPage.hpp>
#include <GameState/AutoSave.hpp>

#include <cstring>
#include <string>

#include <imgui.h>

namespace {
    const ImVec4 AMBER = ImVec4(0.80f, 0.60f, 0.20f, 1.0f);

    // Edited in place by the input and only handed on when editing finishes, so the
    // settings file is not rewritten on every keystroke.
    char suffixBuffer[48] = {};
    bool suffixLoaded = false;

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

    void drawAutoSave() {
        if (!suffixLoaded) {
            const std::string& current = AutoSave::suffix();
            strncpy_s(suffixBuffer, sizeof(suffixBuffer), current.c_str(), _TRUNCATE);
            suffixLoaded = true;
        }

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
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Adds a save. The autosave setting in settings.txt keeps\n"
                "working exactly as it did; this does not replace it.");
        }

        if (on && !AutoSave::hooked()) {
            ImGui::TextColored(AMBER, "Not hooked: %s", AutoSave::status());
        }

        ImGui::Spacing();
        ImGui::SeparatorText("When");

        int days = AutoSave::daysBefore();
        ImGui::SetNextItemWidth(220.0f);
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

        ImGui::SetNextItemWidth(220.0f);
        if (ImGui::InputText("Suffix", suffixBuffer, sizeof(suffixBuffer))) {
            // Left alone until editing finishes; only the look of it is checked here.
        }
        const bool safe = isNameSafe(suffixBuffer);
        if (ImGui::IsItemDeactivatedAfterEdit() && safe) {
            AutoSave::setSuffix(std::string(suffixBuffer));
        }
        if (!safe) {
            ImGui::TextColored(AMBER,
                "Letters, digits, - and _ only. Not saved while it says this.");
        }

        ImGui::TextDisabled("Next one would be called:");
        ImGui::SameLine();
        const std::string example = AutoSave::exampleName();
        ImGui::TextUnformatted(example.c_str());

        ImGui::TextWrapped(
            "These sit outside the game's three file autosave rotation, so they do not "
            "push each other out and nothing deletes them. They accumulate in the save "
            "games folder until removed by hand.");

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
