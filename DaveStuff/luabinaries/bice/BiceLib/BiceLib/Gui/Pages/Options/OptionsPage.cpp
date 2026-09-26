// Utility Options: how this overlay opens, how big it draws, what it looks like, and
// the two things BiceLib itself owns - its crash reports and its log console.
//
// Nothing here changes the game. What does is on the Game Settings page beside it.
//
// They differ in how long they last, which is worth knowing before changing one:
//   - the toggle key and the theme are in BiceLib's own settings file and outlive the
//     session;
//   - the font size is this overlay's own and lasts only as long as the game does.
//
// The wx page's font buttons resized wxWidgets controls and have no counterpart; ImGui
// scales its font instead, which is the same intent by different means.

#include <CrashReport.hpp>
#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Overlay.hpp>
#include <Settings.hpp>

#include <Windows.h>
#include <string>

#include <imgui.h>

namespace {
    const char* START_CONSOLE = "BiceLib.startConsole";
    const char* STOP_CONSOLE = "BiceLib.stopConsole";

    /**@brief what the last button pressed did, shown beside the ones that set it*/
    std::string status;
    bool statusIsError = false;

    /**@brief the status line, where the button that wrote it can be seen next to it*/
    void drawStatus() {
        if (status.empty()) {
            return;
        }
        ImGui::SameLine();
        ImGui::TextColored(statusIsError ? Gui::Theme::mark(Gui::Theme::Mark::Error)
                                         : Gui::Theme::mark(Gui::Theme::Mark::Success),
            "%s", status.c_str());
    }

    void drawOptions() {
        ImGui::SeparatorText("This overlay");

        ImGui::Text("Open and close with");
        ImGui::SameLine();
        if (Overlay::capturingToggleKey()) {
            // Not a real button: it is the prompt, and the key that answers it is
            // taken by the window procedure rather than by anything on this page.
            ImGui::BeginDisabled();
            ImGui::Button("press a key...##togglekey");
            ImGui::EndDisabled();
            ImGui::SameLine();
            if (ImGui::Button("Cancel##togglekey")) {
                Overlay::cancelToggleKeyCapture();
            }
        }
        else {
            const std::string label = Overlay::toggleKeyName() + "###togglekey";
            if (ImGui::Button(label.c_str())) {
                Overlay::beginToggleKeyCapture();
            }
        }
        ImGui::TextWrapped("Click it, then press the key to use. Escape cancels. "
            "A letter still types normally into a text box, so only a key pressed "
            "outside one opens the overlay.");

        ImGuiIO& io = ImGui::GetIO();
        ImGui::SetNextItemWidth(200.0f);
        // AlwaysClamp: a number typed into a Ctrl+clicked slider is otherwise not
        // held to its ends, and a font scale of 50 leaves nothing on screen to undo
        // it with.
        ImGui::SliderFloat("Font size", &io.FontGlobalScale, 0.6f, 2.0f, "%.2fx",
            ImGuiSliderFlags_AlwaysClamp);
        ImGui::SameLine();
        if (ImGui::Button("Reset##font")) {
            io.FontGlobalScale = 1.0f;
        }
        ImGui::TextWrapped("Scales the whole overlay's text. The wx utility's font "
            "buttons did the same for its own windows. This one is not saved: it goes "
            "back to normal size when the game restarts.");

        if (!Overlay::canDetachPages()) {
            ImGui::Spacing();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Pages cannot be dragged out of the game window.");
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip(
                    "A page dragged out becomes a window of its own, which needs a\n"
                    "second Direct3D swap chain - and the game running in exclusive\n"
                    "fullscreen does not allow one.\n\n"
                    "Run the game in windowed or borderless mode and pages can be put\n"
                    "on a second monitor or hung over the edge of the game.");
            }
        }

        ImGui::Spacing();
        if (ImGui::Button("Reset layout...")) {
            ImGui::OpenPopup("Reset layout?");
        }
        ImGui::SameLine();
        ImGui::TextDisabled("Puts every window back where the code puts it");

        // Behind a confirmation: it throws away an arrangement that took a while to
        // get right, and there is no undo for it.
        if (ImGui::BeginPopupModal("Reset layout?", nullptr,
            ImGuiWindowFlags_AlwaysAutoResize)) {
            ImGui::TextUnformatted(
                "Every page goes back to being a tab of its own group, every window\n"
                "forgets its position and size, and what is open goes back to the\n"
                "defaults.\n\n"
                "The building and map mode settings are not touched.");
            ImGui::Spacing();
            if (ImGui::Button("Reset", ImVec2(120.0f, 0.0f))) {
                Gui::requestLayoutReset();
                ImGui::CloseCurrentPopup();
            }
            ImGui::SameLine();
            if (ImGui::Button("Cancel", ImVec2(120.0f, 0.0f))) {
                ImGui::CloseCurrentPopup();
            }
            ImGui::EndPopup();
        }

        if (!Settings::path().empty()) {
            ImGui::Spacing();
            ImGui::TextDisabled("Saved settings: %s", Settings::path().c_str());
        }

        ImGui::SeparatorText("Theme");
        // Driven by the list rather than naming any theme, so one added in Theme.cpp
        // appears here without this page changing.
        for (int i = 0; i < Gui::Theme::count(); i++) {
            const Gui::Theme::Info info = Gui::Theme::at(i);
            if (i > 0) {
                ImGui::SameLine();
            }
            if (ImGui::RadioButton(info.name, Gui::Theme::currentIndex() == i)) {
                Gui::Theme::setCurrent(i);
            }
            if (ImGui::IsItemHovered()) {
                ImGui::SetTooltip("%s", info.description);
            }
        }
        ImGui::TextWrapped("Takes effect at once, and is remembered.");

        ImGui::SeparatorText("Crash reports");
        ImGui::TextWrapped(
            "If BiceLib crashes, it writes what happened into a numbered pair of "
            "files instead of leaving you to find a Windows dump. Send the whole "
            "folder, or the lowest numbered pair in it - the first crash is usually "
            "the one that caused the rest.");

        if (ImGui::Button("Write a test report")) {
            CrashReport::writeTestReport();
            status = "Test report written";
            statusIsError = false;
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Writes a report for an exception raised on purpose, so\n"
                "the file can be found and sent before a real crash\n"
                "happens. Nothing is broken by pressing this.");
        }
        ImGui::SameLine();
        if (ImGui::Button("Copy folder path")) {
            ImGui::SetClipboardText(CrashReport::folder());
            status = "Folder path copied";
            statusIsError = false;
        }
        drawStatus();
        ImGui::TextDisabled("%s", CrashReport::folder());
        if (CrashReport::written() > 0) {
            ImGui::Text("%d written this session, the last being %s",
                CrashReport::written(), CrashReport::lastReport());
        }

        ImGui::SeparatorText("Debug console");
        if (ImGui::Button("Open")) {
            // BiceLib's own exports, exactly as the wx page called them.
            Gui::Lua::call(START_CONSOLE);
            status = "Console opened";
            statusIsError = false;
        }
        ImGui::SameLine();
        if (ImGui::Button("Detach")) {
            Gui::Lua::call(STOP_CONSOLE);
            status = "Console detached";
            statusIsError = false;
        }
        drawStatus();
        ImGui::TextWrapped("The separate console window BiceLib writes its log to. Not "
            "to be confused with the Lua Console on the Debug dock, which runs script.");
    }

    class OptionsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Utility Options"; }
        const char* group() const override { return "Options"; }
        // After the two that change the game, since this one changes only the utility.
        int order() const override { return 30; }
        void draw() override { drawOptions(); }
    };
}

REGISTER_GUI_PAGE(OptionsPage);
