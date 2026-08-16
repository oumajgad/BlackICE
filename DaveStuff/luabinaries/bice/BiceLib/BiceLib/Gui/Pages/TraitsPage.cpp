// Traits: a filterable list of traits on the left, the selected trait's effects and
// triggers on the right.
//
// The trait data is parsed out of common/traits.txt once per session, so the list is
// fetched on demand rather than polled. Details are fetched only when the selection
// changes, because building them runs the effect translation in Lua.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>

#include <Windows.h>
#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Traits.Collect";
    const char* DETAILS = "BiceLibGui.Traits.Details";

    std::vector<std::string> traits;
    bool listLoaded = false;
    std::string listError;

    std::string selectedChoice;
    std::string detailKey;
    std::string detailEffects;
    std::string detailTriggers;
    std::string detailError;

    char filter[64] = {};
    bool scrollToSelected = false;

    bool matchesFilter(const std::string& haystack, const char* needle) {
        if (needle == nullptr || needle[0] == '\0') {
            return true;
        }
        const size_t length = strlen(needle);
        const auto it = std::search(haystack.begin(), haystack.end(), needle, needle + length,
            [](char a, char b) { return std::tolower(static_cast<unsigned char>(a)) ==
                                        std::tolower(static_cast<unsigned char>(b)); });
        return it != haystack.end();
    }

    void loadList() {
        traits.clear();
        listLoaded = false;

        if (!Gui::Lua::beginTableCall(COLLECT)) {
            listError = Gui::Lua::unavailableReason();
            return;
        }

        if (!Gui::Lua::boolField("available")) {
            listError = Gui::Lua::stringField("reason", "unavailable");
            Gui::Lua::endCall();
            return;
        }

        const int count = Gui::Lua::arrayLength("traits");
        traits.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            traits.push_back(Gui::Lua::arrayStringAt("traits", i));
        }

        Gui::Lua::endCall();
        listLoaded = true;
        listError.clear();
    }

    void loadDetails(const std::string& choice) {
        detailEffects.clear();
        detailTriggers.clear();
        detailKey.clear();
        detailError.clear();

        if (!Gui::Lua::beginTableCallWithString(DETAILS, choice.c_str())) {
            detailError = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            detailKey = Gui::Lua::stringField("key");
            detailEffects = Gui::Lua::stringField("effects");
            detailTriggers = Gui::Lua::stringField("triggers");
        }
        else {
            detailError = Gui::Lua::stringField("reason", "unavailable");
        }

        Gui::Lua::endCall();
    }

    void select(const std::string& choice) {
        selectedChoice = choice;
        loadDetails(choice);
    }

    /**@brief read only multiline box, so the text stays selectable and copyable*/
    void drawTextBox(const char* id, const std::string& text, float height) {
        // InputTextMultiline needs a mutable buffer even when read only.
        ImGui::InputTextMultiline(id,
            const_cast<char*>(text.c_str()), text.size() + 1,
            ImVec2(-FLT_MIN, height), ImGuiInputTextFlags_ReadOnly);
    }

    void drawTraits() {
        if (ImGui::Button("Reload")) {
            loadList();
            if (!selectedChoice.empty()) {
                loadDetails(selectedChoice);
            }
        }
        ImGui::SameLine();

        if (!listLoaded) {
            if (listError.empty()) {
                ImGui::TextDisabled("Press Reload to parse traits.txt.");
            }
            else {
                ImGui::TextDisabled("%s", listError.c_str());
            }
            // Try once automatically; after that it is on the Reload button so a
            // failure doesn't re-parse the files every frame.
            static bool triedOnce = false;
            if (!triedOnce) {
                triedOnce = true;
                loadList();
            }
            return;
        }

        ImGui::TextDisabled("%d traits", static_cast<int>(traits.size()));

        const float listWidth = 260.0f;

        ImGui::BeginChild("list", ImVec2(listWidth, 0), ImGuiChildFlags_Borders);
        ImGui::SetNextItemWidth(-FLT_MIN);
        ImGui::InputTextWithHint("##filter", "Filter", filter, sizeof(filter));
        const bool filterHasFocus = ImGui::IsItemActive();

        // The visible subset, so arrow keys step through what is on screen rather
        // than through hidden entries.
        std::vector<const std::string*> visible;
        visible.reserve(traits.size());
        int current = -1;
        for (const std::string& choice : traits) {
            if (!matchesFilter(choice, filter)) {
                continue;
            }
            if (choice == selectedChoice) {
                current = static_cast<int>(visible.size());
            }
            visible.push_back(&choice);
        }

        // Only while the list itself has focus, and not while the filter box is
        // taking input - there the arrows belong to the text cursor.
        const bool listHasFocus = ImGui::IsWindowFocused() && !filterHasFocus;
        if (listHasFocus && !visible.empty()) {
            const int last = static_cast<int>(visible.size()) - 1;
            int next = current;

            if (ImGui::IsKeyPressed(ImGuiKey_DownArrow)) {
                next = (current < 0) ? 0 : current + 1;
            }
            else if (ImGui::IsKeyPressed(ImGuiKey_UpArrow)) {
                next = (current < 0) ? last : current - 1;
            }
            else if (ImGui::IsKeyPressed(ImGuiKey_Home)) {
                next = 0;
            }
            else if (ImGui::IsKeyPressed(ImGuiKey_End)) {
                next = last;
            }

            next = (next < 0) ? 0 : (next > last ? last : next);
            if (next != current) {
                select(*visible[next]);
                current = next;
                scrollToSelected = true;
            }

            // Arrow keys also scroll the game map, so claim the keyboard while the
            // list is driving. Applies from the next frame, which is what the WndProc
            // hook already keys off via io.WantCaptureKeyboard.
            ImGui::SetNextFrameWantCaptureKeyboard(true);
        }

        for (int i = 0; i < static_cast<int>(visible.size()); i++) {
            const std::string& choice = *visible[i];
            if (ImGui::Selectable(choice.c_str(), i == current)) {
                select(choice);
            }
            if (i == current && scrollToSelected) {
                ImGui::SetScrollHereY(0.5f);
            }
        }
        scrollToSelected = false;
        ImGui::EndChild();

        ImGui::SameLine();

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedChoice.empty()) {
            ImGui::TextDisabled("Select a trait.");
        }
        else if (!detailError.empty()) {
            ImGui::TextDisabled("%s", detailError.c_str());
        }
        else {
            ImGui::Text("%s", detailKey.c_str());
            ImGui::Separator();

            const float half = ImGui::GetContentRegionAvail().y * 0.5f - ImGui::GetTextLineHeightWithSpacing();

            ImGui::TextUnformatted("Effects");
            drawTextBox("##effects", detailEffects, half);

            ImGui::TextUnformatted("Triggers");
            drawTextBox("##triggers",
                detailTriggers.empty() ? std::string("(none)") : detailTriggers, half);
        }
        ImGui::EndChild();
    }

    class TraitsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Traits"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 50; }
        void draw() override { drawTraits(); }
    };
}

REGISTER_GUI_PAGE(TraitsPage);
