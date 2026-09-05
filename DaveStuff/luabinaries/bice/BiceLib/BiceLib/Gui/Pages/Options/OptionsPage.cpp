// Options: where the game puts its event popups, how this overlay is opened and how
// big it draws, and the debug console.
//
// Unrelated things the wx page had in one grid of buttons, kept together here but
// separated on the page. They differ in where the setting actually lives:
//   - the event popup position is a line in the mod's interface files, rewritten in
//     place, so it outlives the session and applies to every save;
//   - the toggle key is in BiceLib's own settings file and outlives the session too;
//   - the font size is this overlay's own, and lasts as long as the game does;
//   - the console buttons are BiceLib's, unchanged from the wx page.
//
// The message and combat popup position was here as well and has been dropped: the mod
// no longer uses it. BiceData.Options.SetMessagePopups still exists, because the wx
// utility's own options page calls it.
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
    const char* COLLECT = "BiceLibGui.Options.Collect";
    const char* SET_EVENT_POPUPS = "BiceLibGui.Options.SetEventPopups";
    const char* START_CONSOLE = "BiceLib.startConsole";
    const char* STOP_CONSOLE = "BiceLib.stopConsole";

    const double LEFT = 0.0;
    const double CENTER = 1.0;

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string eventPopups = "unknown";
    std::string eventFile;

    std::string status;
    bool statusIsError = false;
    bool loaded = false;

    void readSnapshot() {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        if (!available) {
            return;
        }
        // Collect also returns messagePopups and dialogFile, which nothing here
        // reads any more.
        eventPopups = Gui::Lua::stringField("eventPopups", "unknown");
        eventFile = Gui::Lua::stringField("eventFile");
        loaded = true;
    }

    /**@brief reads the interface files; on demand only, never on a timer*/
    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setPopups(const char* path, double mode, const char* what) {
        if (!Gui::Lua::beginTableCallWithNumber(path, mode)) {
            valid = false;
            return;
        }
        valid = true;

        const bool ok = Gui::Lua::boolField("ok");
        const std::string failure = Gui::Lua::stringField("reason");
        readSnapshot();
        Gui::Lua::endCall();

        statusIsError = !ok;
        status = ok ? (std::string(what) + " moved") : ("Could not write the file: " + failure);
    }

    /**
    @brief one setting's current state and the two buttons that change it

    The button for the state the file is already in is disabled rather than hidden, so
    the pair reads as a choice with one of them selected.
    */
    void drawChoice(const char* label, const std::string& current, const char* path) {
        ImGui::TextUnformatted(label);
        ImGui::SameLine(220.0f);

        ImGui::BeginDisabled(current == "left");
        if (ImGui::Button((std::string("Left##") + label).c_str())) {
            setPopups(path, LEFT, label);
        }
        ImGui::EndDisabled();

        ImGui::SameLine();
        ImGui::BeginDisabled(current == "center");
        if (ImGui::Button((std::string("Center##") + label).c_str())) {
            setPopups(path, CENTER, label);
        }
        ImGui::EndDisabled();

        ImGui::SameLine();
        if (current == "custom") {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "edited by hand");
            ImGui::SetItemTooltip("The line is there but holds neither of the two known "
                "positions, so it was changed outside this utility.");
        }
        else if (current == "unknown") {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error), "not found");
            ImGui::SetItemTooltip("The marked line is missing from the interface file. "
                "Check that the mod version matches this utility.");
        }
        else {
            ImGui::TextDisabled("currently %s", current.c_str());
        }
    }

    void drawOptions() {
        if (!loaded) {
            refresh();
        }

        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }

        ImGui::SeparatorText("Popup positions");
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
        }
        else {
            drawChoice("Event popups", eventPopups, SET_EVENT_POPUPS);

            ImGui::Spacing();
            if (ImGui::Button("Re-read the files")) {
                refresh();
                status.clear();
            }
            ImGui::SameLine();
            if (!status.empty()) {
                ImGui::TextColored(statusIsError ? Gui::Theme::mark(Gui::Theme::Mark::Error)
                                                 : Gui::Theme::mark(Gui::Theme::Mark::Success),
                    "%s", status.c_str());
            }
            else {
                ImGui::TextDisabled("Restart the game for a change to take effect");
            }

            ImGui::TextWrapped("This rewrites a marked line in the mod's own interface "
                "file, so the setting outlives the session and applies to every save - "
                "and reinstalling the mod undoes it.");
            ImGui::TextDisabled("%s", eventFile.c_str());
        }

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
        ImGui::TextWrapped("The separate console window BiceLib writes its log to. Not "
            "to be confused with the Lua Console on the Debug dock, which runs script.");
    }

    class OptionsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Actions"; }
        const char* group() const override { return "Options"; }
        int order() const override { return 10; }
        void draw() override { drawOptions(); }
    };
}

REGISTER_GUI_PAGE(OptionsPage);
