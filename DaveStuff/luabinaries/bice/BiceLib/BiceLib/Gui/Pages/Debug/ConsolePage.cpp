// Lua console: paste a script, run it in the game's own Lua context, read what it
// printed or returned.
//
// The engine is in script/utility_imgui/imgui_console.lua; this is the terminal around
// it. Nothing here needs a new bridge call shape - the script goes out as the string
// argument and the transcript comes back as a field on the result table.
//
// Two hazards are worth knowing about while using it, both handled where they can be:
//   - the script runs on the render thread, so the game is frozen until it returns. The
//     engine installs an instruction limit that turns a runaway loop into an error.
//   - a script that reaches into the game's C++ at the main menu faults, and no pcall
//     catches that. The session gate is therefore left on unless deliberately lifted.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>
#include <Overlay.hpp>

#include <Windows.h>
#include <algorithm>
#include <cfloat>
#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* RUN = "BiceLibGui.Console.Run";
    const char* RESET = "BiceLibGui.Console.Reset";

    struct Entry
    {
        std::string source;
        std::string output;
        std::string error;
        double elapsed = 0.0;
        bool ok = true;
    };

    // Big enough for a pasted script rather than a one liner. ImGui edits it in place,
    // so it has to be a fixed buffer.
    char source[32768] = {};

    std::vector<Entry> transcript;
    std::vector<std::string> history;

    float inputHeight = 180.0f;
    bool sessionRequired = true;
    bool scrollToEnd = false;

    /**
     * Restores the bridge's session gate however the call returns.
     *
     * Leaving it lifted would let every other page reach for game state at the main
     * menu, which is the fault the gate exists to prevent - so it is tied to the scope
     * of one call rather than left as a mode.
     */
    struct SessionGate
    {
        explicit SessionGate(bool required) { Gui::Lua::setSessionRequired(required); }
        ~SessionGate() { Gui::Lua::setSessionRequired(true); }
    };

    /**
     * Saved scripts, as plain .lua files in BiceLibScripts next to the DLL.
     *
     * A directory of real files rather than one blob: a script worth keeping is usually
     * one worth editing in a proper editor, and this way the same file can be opened
     * there, dropped in by hand, or kept in version control.
     */
    namespace Scripts {
        char name[64] = {};
        std::vector<std::string> saved;
        std::string status;
        bool statusIsError = false;
        std::string pendingOverwrite; // name awaiting the replace confirmation

        const std::string& directory() {
            static std::string path;
            if (path.empty()) {
                path = Overlay::directory() + "BiceLibScripts\\";
            }
            return path;
        }

        std::string pathFor(const std::string& scriptName) {
            return directory() + scriptName + ".lua";
        }

        /**
        @brief whether a name is safe to turn into a file name

        Deliberately strict rather than escaping cleverly: the name is pasted straight
        into a path, so anything that could climb out of the directory is refused
        outright instead of being sanitised into something the user did not ask for.
        */
        bool validName(const std::string& scriptName) {
            if (scriptName.empty() || scriptName.size() > 48) {
                return false;
            }
            for (const char character : scriptName) {
                const bool allowed = (character >= 'a' && character <= 'z') ||
                    (character >= 'A' && character <= 'Z') ||
                    (character >= '0' && character <= '9') ||
                    character == ' ' || character == '-' || character == '_';
                if (!allowed) {
                    return false;
                }
            }
            return true;
        }

        /**@brief authoritative check, for deciding what a click should do*/
        bool exists(const std::string& scriptName) {
            return GetFileAttributesA(pathFor(scriptName).c_str()) != INVALID_FILE_ATTRIBUTES;
        }

        /**
        @brief the same question answered from the cached listing

        Drawing asks this every frame, and a file system call per frame for the sake of
        greying out a button is not worth making. Case insensitively, because the file
        system the listing came from is.
        */
        bool listedAlready(const std::string& scriptName) {
            for (const std::string& entry : saved) {
                if (_stricmp(entry.c_str(), scriptName.c_str()) == 0) {
                    return true;
                }
            }
            return false;
        }

        void refresh() {
            saved.clear();

            WIN32_FIND_DATAA found = {};
            const HANDLE search = FindFirstFileA((directory() + "*.lua").c_str(), &found);
            if (search == INVALID_HANDLE_VALUE) {
                return;
            }
            do {
                if ((found.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
                    continue;
                }
                std::string file = found.cFileName;
                if (file.size() > 4) {
                    saved.push_back(file.substr(0, file.size() - 4)); // drop ".lua"
                }
            } while (FindNextFileA(search, &found) != 0);
            FindClose(search);

            std::sort(saved.begin(), saved.end(), [](const std::string& a, const std::string& b) {
                return _stricmp(a.c_str(), b.c_str()) < 0;
            });
        }

        void save(const std::string& scriptName, const char* text) {
            if (!validName(scriptName)) {
                status = "Names may hold letters, digits, spaces, - and _ only";
                statusIsError = true;
                return;
            }

            // Created on demand: an install that never saves a script never gets the
            // directory.
            CreateDirectoryA(directory().c_str(), nullptr);

            std::ofstream file(pathFor(scriptName).c_str(), std::ios::binary | std::ios::trunc);
            if (!file) {
                status = "Could not write " + pathFor(scriptName);
                statusIsError = true;
                return;
            }
            file << text;
            file.close();

            refresh();
            status = "Saved " + scriptName;
            statusIsError = false;
        }

        void load(const std::string& scriptName, char* buffer, size_t size) {
            std::ifstream file(pathFor(scriptName).c_str(), std::ios::binary);
            if (!file) {
                status = "Could not read " + scriptName;
                statusIsError = true;
                return;
            }

            const std::string text((std::istreambuf_iterator<char>(file)),
                std::istreambuf_iterator<char>());

            if (text.size() >= size) {
                // Truncating silently would mean running only part of a script, which
                // could do something quite different from the whole of it.
                status = "Too big for the editor (" + std::to_string(text.size()) +
                    " bytes); not loaded";
                statusIsError = true;
                return;
            }

            strncpy_s(buffer, size, text.c_str(), size - 1);
            strncpy_s(name, scriptName.c_str(), sizeof(name) - 1);
            status = "Loaded " + scriptName;
            statusIsError = false;
        }

        void remove(const std::string& scriptName) {
            if (!validName(scriptName)) {
                return;
            }
            if (DeleteFileA(pathFor(scriptName).c_str()) == 0) {
                status = "Could not delete " + scriptName;
                statusIsError = true;
                return;
            }
            refresh();
            status = "Deleted " + scriptName;
            statusIsError = false;
        }

        void openFolder() {
            CreateDirectoryA(directory().c_str(), nullptr);
            ShellExecuteA(nullptr, "open", directory().c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        }
    }

    void record(const Entry& entry) {
        // Old runs are dropped rather than kept forever: the transcript holds every
        // string it ever produced, and some of those are 60 KB.
        const size_t LIMIT = 60;
        if (transcript.size() >= LIMIT) {
            transcript.erase(transcript.begin());
        }
        transcript.push_back(entry);
        scrollToEnd = true;
    }

    void run() {
        Entry entry;
        entry.source = source;
        if (entry.source.empty()) {
            return;
        }

        {
            const SessionGate gate(sessionRequired);

            if (!Gui::Lua::beginTableCallWithString(RUN, source)) {
                entry.ok = false;
                entry.error = std::string("Cannot reach Lua: ") + Gui::Lua::unavailableReason();
                record(entry);
                return;
            }

            entry.ok = Gui::Lua::boolField("ok");
            entry.output = Gui::Lua::stringField("output");
            entry.error = Gui::Lua::stringField("error");
            entry.elapsed = Gui::Lua::numberField("elapsed");
            Gui::Lua::endCall();
        }

        // Kept for recall even when it failed - a script that errored is usually the
        // one you want back.
        if (history.empty() || history.back() != entry.source) {
            history.push_back(entry.source);
            if (history.size() > 40) {
                history.erase(history.begin());
            }
        }

        record(entry);
    }

    void reset() {
        const SessionGate gate(sessionRequired);

        Entry entry;
        entry.source = "(reset)";
        if (!Gui::Lua::beginTableCall(RESET)) {
            entry.ok = false;
            entry.error = std::string("Cannot reach Lua: ") + Gui::Lua::unavailableReason();
            record(entry);
            return;
        }
        entry.output = Gui::Lua::stringField("output");
        Gui::Lua::endCall();
        record(entry);
    }

    void copyTranscript() {
        std::string all;
        for (const Entry& entry : transcript) {
            all += "> ";
            all += entry.source;
            all += "\n";
            if (!entry.output.empty()) {
                all += entry.output;
                all += "\n";
            }
            if (!entry.error.empty()) {
                all += entry.error;
                all += "\n";
            }
        }
        ImGui::SetClipboardText(all.c_str());
    }

    // Enough to show what a script has to work with, and to be a starting point for
    // editing rather than a demonstration.
    struct Example
    {
        const char* label;
        const char* source;
    };

    const Example* examples(int* count) {
        static const Example ENTRIES[] = {
            { "Selected country", "return BiceData.Players.CurrentTag()" },
            { "Read a country variable",
              "local vars = BiceData.Country.Variables()\n"
              "return BiceData.Country.Get(vars, \"national_focus\")" },
            { "List the human players",
              "for index, tag in ipairs(BiceData.Players.Determine()) do\n"
              "    print(index, tag)\n"
              "end" },
            { "Whole page snapshot", "return BiceLibGui.StratResources.Collect()" },
            { "Search the globals",
              "-- Anything matching a name, to find what is loaded.\n"
              "local found = {}\n"
              "for name in pairs(_G) do\n"
              "    if string.find(string.lower(name), \"bice\") then\n"
              "        table.insert(found, name)\n"
              "    end\n"
              "end\n"
              "table.sort(found)\n"
              "return found" },
            { "Post a variable (writes!)",
              "-- Queued, not immediate: read it back a second later.\n"
              "BiceData.Country.Set(BiceData.Players.CurrentTag(), \"zz_console_test\", 42)" },
        };
        *count = static_cast<int>(sizeof(ENTRIES) / sizeof(ENTRIES[0]));
        return ENTRIES;
    }

    void drawConsole() {
        // Ctrl+Enter runs from anywhere on the page, including from inside the editor,
        // where a plain Enter has to stay a newline.
        const bool runShortcut = ImGui::IsWindowFocused(ImGuiFocusedFlags_RootAndChildWindows) &&
            ImGui::GetIO().KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_Enter, false);

        if (ImGui::Button("Run") || runShortcut) {
            run();
        }
        ImGui::SetItemTooltip("Ctrl+Enter");
        ImGui::SameLine();
        if (ImGui::Button("Clear input")) {
            source[0] = '\0';
        }
        ImGui::SameLine();
        if (ImGui::Button("Clear output")) {
            transcript.clear();
        }
        ImGui::SameLine();
        if (ImGui::Button("Copy output")) {
            copyTranscript();
        }
        ImGui::SameLine();
        if (ImGui::Button("Reset scratch")) {
            reset();
        }
        ImGui::SetItemTooltip("Forgets variables left behind by previous runs");

        ImGui::SameLine();
        ImGui::SetNextItemWidth(160.0f);
        int exampleCount = 0;
        const Example* entries = examples(&exampleCount);
        if (ImGui::BeginCombo("##examples", "Examples")) {
            for (int i = 0; i < exampleCount; i++) {
                if (ImGui::Selectable(entries[i].label)) {
                    // Replaces the editor contents; the old text is still in history if
                    // it was ever run.
                    strncpy_s(source, entries[i].source, sizeof(source) - 1);
                }
            }
            ImGui::EndCombo();
        }

        ImGui::SameLine();
        if (ImGui::Checkbox("Needs a session", &sessionRequired)) {
            // Nothing to do: read when a call is made.
        }
        ImGui::SetItemTooltip("Off lets scripts run at the main menu. The mod's own Lua "
            "is fine there; touching game state faults and takes the game with it.");

        if (!history.empty()) {
            ImGui::SameLine();
            ImGui::SetNextItemWidth(120.0f);
            if (ImGui::BeginCombo("##history", "History")) {
                // Newest first: that is the one being iterated on.
                for (int i = static_cast<int>(history.size()) - 1; i >= 0; i--) {
                    // One line of it is enough to recognise, and a script can be long.
                    std::string label = history[i].substr(0, history[i].find('\n'));
                    if (label.size() > 60) {
                        label = label.substr(0, 60) + "...";
                    }
                    ImGui::PushID(i);
                    if (ImGui::Selectable(label.c_str())) {
                        strncpy_s(source, history[i].c_str(), sizeof(source) - 1);
                    }
                    if (ImGui::IsItemHovered()) {
                        ImGui::SetTooltip("%s", history[i].c_str());
                    }
                    ImGui::PopID();
                }
                ImGui::EndCombo();
            }
        }

        // Saved scripts. Listed once and after every change rather than every frame:
        // this touches the file system.
        static bool listed = false;
        if (!listed) {
            listed = true;
            Scripts::refresh();
        }

        ImGui::SetNextItemWidth(160.0f);
        ImGui::InputTextWithHint("##name", "Script name", Scripts::name, sizeof(Scripts::name));

        ImGui::SameLine();
        const std::string scriptName = Scripts::name;
        ImGui::BeginDisabled(scriptName.empty() || source[0] == '\0');
        if (ImGui::Button("Save")) {
            if (Scripts::exists(scriptName)) {
                // Overwriting a script someone kept is worth one question.
                Scripts::pendingOverwrite = scriptName;
                ImGui::OpenPopup("Replace script?");
            }
            else {
                Scripts::save(scriptName, source);
            }
        }
        ImGui::EndDisabled();

        ImGui::SameLine();
        ImGui::SetNextItemWidth(150.0f);
        if (ImGui::BeginCombo("##saved", Scripts::saved.empty() ? "(none saved)" : "Saved")) {
            // Refreshed on open, so a file dropped in from outside the game shows up
            // without a restart.
            Scripts::refresh();
            for (const std::string& entry : Scripts::saved) {
                if (ImGui::Selectable(entry.c_str())) {
                    Scripts::load(entry, source, sizeof(source));
                }
            }
            if (Scripts::saved.empty()) {
                ImGui::TextDisabled("Nothing saved yet");
            }
            ImGui::EndCombo();
        }

        ImGui::SameLine();
        ImGui::BeginDisabled(!Scripts::listedAlready(scriptName));
        if (ImGui::Button("Delete")) {
            ImGui::OpenPopup("Delete script?");
        }
        ImGui::EndDisabled();

        ImGui::SameLine();
        if (ImGui::Button("Folder")) {
            Scripts::openFolder();
        }
        ImGui::SetItemTooltip("Opens %s, so scripts can be edited outside the game",
            Scripts::directory().c_str());

        if (!Scripts::status.empty()) {
            ImGui::SameLine();
            ImGui::TextColored(Scripts::statusIsError ? ImVec4(0.85f, 0.35f, 0.35f, 1.0f)
                                                      : ImVec4(0.45f, 0.85f, 0.45f, 1.0f),
                "%s", Scripts::status.c_str());
        }

        if (ImGui::BeginPopupModal("Replace script?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
            ImGui::Text("\"%s\" already exists. Replace it with what is in the editor?",
                Scripts::pendingOverwrite.c_str());
            if (ImGui::Button("Replace")) {
                Scripts::save(Scripts::pendingOverwrite, source);
                ImGui::CloseCurrentPopup();
            }
            ImGui::SameLine();
            if (ImGui::Button("Cancel")) {
                ImGui::CloseCurrentPopup();
            }
            ImGui::EndPopup();
        }

        if (ImGui::BeginPopupModal("Delete script?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
            ImGui::Text("Delete \"%s\"? The file goes for good, not to the recycle bin.",
                scriptName.c_str());
            if (ImGui::Button("Delete")) {
                Scripts::remove(scriptName);
                ImGui::CloseCurrentPopup();
            }
            ImGui::SameLine();
            if (ImGui::Button("Cancel")) {
                ImGui::CloseCurrentPopup();
            }
            ImGui::EndPopup();
        }

        ImGui::InputTextMultiline("##source", source, sizeof(source),
            ImVec2(-FLT_MIN, inputHeight), ImGuiInputTextFlags_AllowTabInput);

        Gui::horizontalSplitter("##split", &inputHeight, 60.0f, 80.0f);

        ImGui::BeginChild("transcript", ImVec2(0, 0), ImGuiChildFlags_Borders);
        if (transcript.empty()) {
            ImGui::TextDisabled("An expression is printed on its own, so \"1 + 1\" or "
                "\"BiceData.Players.CurrentTag()\" is enough. Statements run as written, "
                "and print() goes here. Variables you set stay set until Reset scratch.");
        }
        for (const Entry& entry : transcript) {
            // The echo keeps the transcript readable once several runs are stacked up.
            ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.55f, 0.70f, 0.90f, 1.0f));
            ImGui::TextUnformatted("> ");
            ImGui::SameLine(0.0f, 0.0f);
            ImGui::TextUnformatted(entry.source.c_str());
            ImGui::PopStyleColor();

            if (!entry.output.empty()) {
                ImGui::TextUnformatted(entry.output.c_str());
            }
            if (!entry.error.empty()) {
                ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.90f, 0.40f, 0.40f, 1.0f));
                ImGui::TextUnformatted(entry.error.c_str());
                ImGui::PopStyleColor();
            }
            if (entry.ok && entry.elapsed >= 0.01) {
                // Only worth saying when it was slow enough to have been felt as a
                // stutter in the game.
                ImGui::TextDisabled("(%.2f s)", entry.elapsed);
            }
            ImGui::Spacing();
        }
        if (scrollToEnd) {
            ImGui::SetScrollHereY(1.0f);
            scrollToEnd = false;
        }
        ImGui::EndChild();
    }

    class ConsolePage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Lua Console"; }
        const char* group() const override { return "Debug"; }
        int order() const override { return 30; }
        void draw() override { drawConsole(); }
    };
}

REGISTER_GUI_PAGE(ConsolePage);
