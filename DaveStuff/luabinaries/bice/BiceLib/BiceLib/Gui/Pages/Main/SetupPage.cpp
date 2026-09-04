#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/CountrySelection.hpp>
#include <Gui/LuaBridge.hpp>

#include <Windows.h>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Setup.Collect";
    const char* REFRESH_PLAYERS = "BiceLibGui.Setup.RefreshPlayers";
    const char* SELECT_PLAYER = "BiceLibGui.Setup.SelectPlayer";

    struct Snapshot
    {
        bool valid = false;
        bool available = false;
        std::string reason;
        std::string selected;
        std::string actualPlayer;
        std::vector<std::string> players;
    };

    Snapshot snapshot;
    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    // A tag typed in by hand. The wx utility let one be written straight into its
    // choice control, and a list of human players is no use for looking at Germany's
    // production in a game where nobody is playing Germany.
    char typedTag[8] = {};
    std::string selectFailure;

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            snapshot.valid = false;
            return;
        }

        snapshot.valid = true;
        snapshot.available = Gui::Lua::boolField("available");
        snapshot.reason = Gui::Lua::stringField("reason");
        snapshot.selected = Gui::Lua::stringField("selected");
        snapshot.actualPlayer = Gui::Lua::stringField("actual_player");

        snapshot.players.clear();
        const int count = Gui::Lua::arrayLength("players");
        for (int i = 0; i < count; i++) {
            snapshot.players.push_back(Gui::Lua::arrayStringAt("players", i));
        }

        Gui::Lua::endCall();
    }

    /**
    @brief points every page at \p tag, and says so when the game will not have it

    Any tag, not only a human player's. The game refuses one that is not a country and
    one whose player has opted out of being inspected, and it cannot tell the two
    apart - so neither can the message.
    */
    void selectTag(const char* tag) {
        selectFailure.clear();

        if (!Gui::Lua::beginTableCallWithString(SELECT_PLAYER, tag)) {
            selectFailure = std::string("Lua unavailable: ") +
                Gui::Lua::unavailableReason();
            return;
        }
        if (!Gui::Lua::boolField("available")) {
            selectFailure = std::string(tag) + ": " +
                Gui::Lua::stringField("reason", "not accepted");
        }
        Gui::Lua::endCall();

        // Every page reads the tag through one cached poll, which would otherwise take
        // a couple of seconds to notice.
        Gui::Selection::invalidate();
        refresh();
    }

    void drawSetup() {
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
        if (!snapshot.valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!snapshot.available) {
            ImGui::TextDisabled("%s", snapshot.reason.c_str());
            return;
        }
        ImGui::NewLine();

        ImGui::SeparatorText("Country");

        if (snapshot.selected.empty()) {
            ImGui::TextDisabled("No country selected - pages fall back to the actual player.");
        }
        else {
            ImGui::Text("Selected: %s", snapshot.selected.c_str());
        }
        if (!snapshot.actualPlayer.empty()) {
            ImGui::Text("You are playing: %s", snapshot.actualPlayer.c_str());
            ImGui::SameLine();
            if (ImGui::SmallButton("Select")) {
                selectTag(snapshot.actualPlayer.c_str());
            }
        }

        ImGui::Spacing();
        ImGui::SetNextItemWidth(70.0f);
        const bool entered = ImGui::InputText("##tag", typedTag, sizeof(typedTag),
            ImGuiInputTextFlags_CharsUppercase | ImGuiInputTextFlags_AutoSelectAll |
            ImGuiInputTextFlags_EnterReturnsTrue);
        ImGui::SameLine();
        const bool pressed = ImGui::Button("Set");
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Any country's tag, whether anyone is playing it or not.");
        }
        ImGui::SameLine();
        ImGui::TextDisabled("or type a tag");

        if ((entered || pressed) && typedTag[0] != 0) {
            selectTag(typedTag);
        }
        if (!selectFailure.empty()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "%s",
                selectFailure.c_str());
        }

        ImGui::Spacing();
        ImGui::SeparatorText("Human players");

        if (ImGui::Button("Get players")) {
            Gui::Lua::call(REFRESH_PLAYERS);
            refresh();
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%d found", static_cast<int>(snapshot.players.size()));

        if (snapshot.players.empty()) {
            ImGui::TextWrapped("Press Get players to scan. In single player this lists only you.");
            return;
        }

        for (size_t i = 0; i < snapshot.players.size(); i++) {
            const std::string& tag = snapshot.players[i];
            const bool isSelected = (tag == snapshot.selected);

            ImGui::PushID(static_cast<int>(i));
            if (ImGui::RadioButton(tag.c_str(), isSelected) && !isSelected) {
                selectTag(tag.c_str());
            }
            ImGui::PopID();
        }

        ImGui::Spacing();
        ImGui::TextWrapped("A player can block the host from selecting their country; "
            "the selection silently stays put in that case.");
    }

    class SetupPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Setup"; }
        const char* group() const override { return "Main"; }
        int order() const override { return 10; }
        void draw() override { drawSetup(); }
    };
}

REGISTER_GUI_PAGE(SetupPage);
