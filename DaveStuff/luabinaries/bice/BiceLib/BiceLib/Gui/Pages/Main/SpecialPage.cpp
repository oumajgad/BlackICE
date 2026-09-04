// Special: moves the 3D unit sprites the mod never draws out of the game's reach,
// which is worth around 300 MB of a 32 bit address space.
//
// Port of the wx page's two buttons, which shelled out to cmd:
//     move gfx\anims\*  ->  gfx\anims\backup\     (keeping five files)
//     move gfx\anims\backup\*  ->  gfx\anims\
//
// Done here with the Win32 API rather than os.execute: no cmd window flashes up, and
// the page can say what actually happened rather than leaving the player to guess.
// Nothing here touches Lua at all.
//
// It is meant to be used at the main menu, but that is advice rather than a rule:
// there is no dependable way to tell a menu from a running game. See inGame below.
//
// Nothing is ever deleted. Both directions are moves, so a mistake is undoable by
// pressing the other button.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Overlay.hpp>

#include <Windows.h>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    // The game still needs a fallback model, or units are drawn with nothing at all.
    // Thumbs.db is Explorer's and would only be recreated.
    const char* const KEEP[] = {
        "Thumbs.db",
        "GenericTankDiffuse.dds",
        "GenericTankSpecular.dds",
        "GenericTank.xac",
        "TankIdleA.xsm",
    };

    struct Folder
    {
        bool exists = false;
        int files = 0;
        unsigned long long bytes = 0;
    };

    Folder anims;   // counts only what may be moved, so the keep list is excluded
    Folder backup;
    bool scanned = false;

    std::string result;
    bool resultIsError = false;
    std::vector<std::string> failures;

    /**
     * Whether the game state object exists, refreshed each frame.
     *
     * Advisory only. It is not the same question as "is a save loaded": the object is
     * already there at the main menu, so gating on it disabled this page permanently.
     * The mod's own SaveLoaded flag is no better - it is only set from a handler that
     * returns early unless G_UtilityEnabled is on.
     *
     * The page therefore warns rather than refuses. Moving a file the game holds
     * open fails with a sharing violation, which is reported per file, and nothing is
     * deleted, so the worst case is a partly moved set that the other button puts
     * back.
     */
    bool inGame = false;

    const std::string& animsPath() {
        static const std::string path = Overlay::gameDirectory() + "gfx\\anims\\";
        return path;
    }

    const std::string& backupPath() {
        static const std::string path = Overlay::gameDirectory() + "gfx\\anims\\backup\\";
        return path;
    }

    bool kept(const char* name) {
        for (const char* keep : KEEP) {
            if (_stricmp(keep, name) == 0) {
                return true;
            }
        }
        return false;
    }

    /**
    @brief the files in \p directory, skipping subdirectories and optionally the keep list
    */
    Folder collect(const std::string& directory, bool skipKept, std::vector<std::string>* names) {
        Folder folder;

        WIN32_FIND_DATAA found = {};
        const HANDLE search = FindFirstFileA((directory + "*").c_str(), &found);
        if (search == INVALID_HANDLE_VALUE) {
            return folder;
        }
        folder.exists = true;

        do {
            if ((found.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
                continue; // including "." and ".." and the backup folder itself
            }
            if (skipKept && kept(found.cFileName)) {
                continue;
            }

            folder.files++;
            folder.bytes += (static_cast<unsigned long long>(found.nFileSizeHigh) << 32) |
                found.nFileSizeLow;
            if (names != nullptr) {
                names->push_back(found.cFileName);
            }
        } while (FindNextFileA(search, &found) != 0);

        FindClose(search);
        return folder;
    }

    void scan() {
        anims = collect(animsPath(), true, nullptr);
        backup = collect(backupPath(), false, nullptr);
        scanned = true;
    }

    std::string lastErrorText() {
        const DWORD code = GetLastError();
        char* buffer = nullptr;
        const DWORD length = FormatMessageA(
            FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
            nullptr, code, 0, reinterpret_cast<char*>(&buffer), 0, nullptr);

        std::string text = (length != 0 && buffer != nullptr) ? std::string(buffer, length)
                                                              : std::string("unknown error");
        if (buffer != nullptr) {
            LocalFree(buffer);
        }
        while (!text.empty() && (text.back() == '\n' || text.back() == '\r' || text.back() == ' ')) {
            text.pop_back();
        }
        return text + " (" + std::to_string(code) + ")";
    }

    /**
    @brief moves every named file from one directory to the other

    The listing is taken before anything moves rather than moved as it is walked:
    enumerating a directory that is being changed underneath is not something to rely
    on.
    */
    void moveAll(const std::string& from, const std::string& to, bool skipKept) {
        result.clear();
        failures.clear();
        resultIsError = false;

        std::vector<std::string> names;
        const Folder source = collect(from, skipKept, &names);
        if (!source.exists) {
            result = "Not found: " + from;
            resultIsError = true;
            return;
        }
        if (names.empty()) {
            result = "Nothing to move";
            return;
        }

        // Created only once there is something to put in it.
        CreateDirectoryA(to.c_str(), nullptr);

        int moved = 0;
        for (const std::string& name : names) {
            if (MoveFileA((from + name).c_str(), (to + name).c_str()) != 0) {
                moved++;
                continue;
            }
            // A sharing violation here means the game has the file open, which is the
            // whole reason this is a main menu only operation.
            if (failures.size() < 5) {
                failures.push_back(name + ": " + lastErrorText());
            }
        }

        const size_t failed = names.size() - static_cast<size_t>(moved);
        result = "Moved " + std::to_string(moved) + " of " + std::to_string(names.size()) + " files";
        if (failed > 0) {
            result += ", " + std::to_string(failed) + " failed";
            resultIsError = true;
        }
        scan();
    }

    std::string megabytes(unsigned long long bytes) {
        char text[32];
        sprintf_s(text, "%.0f MB", static_cast<double>(bytes) / (1024.0 * 1024.0));
        return text;
    }

    void drawSpecial() {
        if (!scanned) {
            scan();
        }
        inGame = Gui::Lua::sessionActive();

        ImGui::TextWrapped("The mod draws no 3D unit sprites, but the game loads them "
            "regardless - around 300 MB of an address space that only has 2 to 4 GB in "
            "it. Moving them aside is worth doing, and reversible: nothing is deleted, "
            "the files go to a backup folder and come back from it.");
        ImGui::Spacing();

        if (!anims.exists) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error), "Not found: %s",
                animsPath().c_str());
            ImGui::TextWrapped("This is looked up next to hoi3_tfh.exe. If the game "
                "lives somewhere else, nothing here can be done.");
            return;
        }

        if (ImGui::BeginTable("state", 3, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner |
            ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("", ImGuiTableColumnFlags_WidthStretch, 1.0f);
            ImGui::TableSetupColumn("Files", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableSetupColumn("Size", ImGuiTableColumnFlags_WidthStretch, 0.5f);
            ImGui::TableHeadersRow();

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted("In gfx\\anims (movable)");
            ImGui::TableNextColumn();
            ImGui::Text("%d", anims.files);
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(megabytes(anims.bytes).c_str());

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted("In the backup folder");
            ImGui::TableNextColumn();
            ImGui::Text("%d", backup.files);
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(megabytes(backup.bytes).c_str());
            ImGui::EndTable();
        }

        ImGui::Spacing();
        if (anims.files == 0 && backup.files > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success), "The sprites are moved aside.");
        }
        else if (backup.files > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Partly moved: there are sprites in both places.");
        }
        else {
            ImGui::TextDisabled("The sprites are in place.");
        }

        ImGui::Spacing();
        if (inGame) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "Best done at the main menu.");
            ImGui::TextWrapped("Once a game has been started the sprites may be open, "
                "and an open file cannot be moved. Nothing is lost if that happens - the "
                "files that fail are listed and stay where they are - but a set moved "
                "half way is not what you want mid game.");
        }

        // A greyed button with no explanation is a bug report waiting to happen, so
        // each one says on hover why it cannot be pressed.
        ImGui::BeginDisabled(anims.files == 0);
        if (ImGui::Button("Remove sprites")) {
            ImGui::OpenPopup("Move the sprites aside?");
        }
        ImGui::EndDisabled();
        if (anims.files == 0 && ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) {
            ImGui::SetTooltip("Nothing left to move: gfx\\anims holds only the files that stay behind");
        }

        ImGui::SameLine();
        ImGui::BeginDisabled(backup.files == 0);
        if (ImGui::Button("Restore sprites")) {
            ImGui::OpenPopup("Put the sprites back?");
        }
        ImGui::EndDisabled();
        if (backup.files == 0 && ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) {
            ImGui::SetTooltip(backup.exists ? "The backup folder is empty"
                                            : "No backup folder yet - nothing has been moved aside");
        }

        ImGui::SameLine();
        if (ImGui::Button("Rescan")) {
            scan();
        }

        if (ImGui::BeginPopupModal("Move the sprites aside?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
            ImGui::Text("Move %d files (%s) into", anims.files, megabytes(anims.bytes).c_str());
            ImGui::TextUnformatted(backupPath().c_str());
            ImGui::TextWrapped("The generic tank model stays behind as a fallback. The "
                "game will be frozen for a moment while the files move.");
            if (inGame) {
                // Repeated here because this is the click that does it, and the warning
                // higher up the page may well have scrolled out of sight.
                ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                    "A game is running: sprites it has open will refuse to move.");
            }
            if (ImGui::Button("Move them")) {
                moveAll(animsPath(), backupPath(), true);
                ImGui::CloseCurrentPopup();
            }
            ImGui::SameLine();
            if (ImGui::Button("Cancel")) {
                ImGui::CloseCurrentPopup();
            }
            ImGui::EndPopup();
        }

        if (ImGui::BeginPopupModal("Put the sprites back?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
            ImGui::Text("Move %d files (%s) back into", backup.files, megabytes(backup.bytes).c_str());
            ImGui::TextUnformatted(animsPath().c_str());
            ImGui::TextWrapped("Needed before playing vanilla or another mod.");
            if (ImGui::Button("Put them back")) {
                moveAll(backupPath(), animsPath(), false);
                ImGui::CloseCurrentPopup();
            }
            ImGui::SameLine();
            if (ImGui::Button("Cancel")) {
                ImGui::CloseCurrentPopup();
            }
            ImGui::EndPopup();
        }

        if (!result.empty()) {
            ImGui::Spacing();
            ImGui::TextColored(resultIsError ? Gui::Theme::mark(Gui::Theme::Mark::Error)
                                             : Gui::Theme::mark(Gui::Theme::Mark::Success),
                "%s", result.c_str());
            for (const std::string& failure : failures) {
                ImGui::TextWrapped("%s", failure.c_str());
            }
            if (!resultIsError) {
                ImGui::TextWrapped("Restart the game for this to take effect.");
            }
        }
    }

    class SpecialPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Special"; }
        const char* group() const override { return "Main"; }
        // Second, right after Setup: it is only usable at the main menu, so it wants to
        // be found before a game is loaded rather than sat at the end of the row.
        int order() const override { return 15; }
        void draw() override { drawSpecial(); }
    };
}

REGISTER_GUI_PAGE(SpecialPage);
