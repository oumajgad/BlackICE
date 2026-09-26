// Game Settings: options that change how the game itself behaves, as against the ones
// that change this utility.
//
// They differ in where the setting lives, which is worth knowing before changing one:
//   - the map's edge scrolling is a patch on the running executable, kept in BiceLib's
//     own settings file and put back at startup;
//   - the event popup position is a line in the mod's interface files, rewritten in
//     place, so it outlives the session, applies to every save, and is undone by
//     reinstalling the mod.
//
// The second needs Lua and the mod's files; the first does not, so the page shows what it
// can rather than going blank when Lua is unavailable.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/Theme.hpp>
#include <GameState/MapEdgeScroll.hpp>

#include <string>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Options.Collect";
    const char* SET_EVENT_POPUPS = "BiceLibGui.Options.SetEventPopups";

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
        // Collect also returns messagePopups and dialogFile, which nothing here reads
        // any more.
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

    void drawMap() {
        ImGui::SeparatorText("Map");

        bool edgeScroll = MapEdgeScroll::enabled();
        if (ImGui::Checkbox("Scroll the map when the mouse is at the screen edge",
            &edgeScroll)) {
            MapEdgeScroll::setEnabled(edgeScroll);
        }
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip(
                "Off stops the map moving when the cursor reaches the edge of the\n"
                "screen. The arrow keys and dragging with the middle mouse button\n"
                "still work.\n\n"
                "The game's own scroll_speed setting is the speed of all scrolling,\n"
                "so turning it down would have slowed those too. This patches out\n"
                "the four edge tests instead and leaves the rest alone.\n\n"
                "Takes effect at once, and is remembered.");
        }

        if (!MapEdgeScroll::enabled() && !MapEdgeScroll::available()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Not applied: %s", MapEdgeScroll::status());
        }
    }

    void drawPopups() {
        ImGui::SeparatorText("Popup positions");

        // Gated here rather than over the whole page: the map option above is a patch on
        // the executable and has something to offer even where the mod's files cannot be
        // read at all.
        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return;
        }

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

    void drawGameSettings() {
        if (!loaded) {
            refresh();
        }

        drawMap();
        ImGui::Spacing();
        drawPopups();
    }

    class GameSettingsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Game Settings"; }
        const char* group() const override { return "Options"; }
        int order() const override { return 10; }
        void draw() override { drawGameSettings(); }
    };
}

REGISTER_GUI_PAGE(GameSettingsPage);
