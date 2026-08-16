// Modifiers: event and triggered modifiers, with their effects and the conditions
// under which they apply.
//
// Same shape as Traits - static file-parsed data, so the list loads once and details
// are fetched only when the selection changes.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Modifiers.Collect";
    const char* DETAILS = "BiceLibGui.Modifiers.Details";

    std::vector<std::string> modifiers;
    bool listLoaded = false;
    bool triedOnce = false;
    std::string listError;

    std::string selectedChoice;
    std::string detailKey;
    std::string detailKind;
    std::string detailEffects;
    std::string detailTriggers;
    std::string detailError;

    char filter[64] = {};

    void loadList() {
        modifiers.clear();
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

        const int count = Gui::Lua::arrayLength("modifiers");
        modifiers.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            modifiers.push_back(Gui::Lua::arrayStringAt("modifiers", i));
        }

        Gui::Lua::endCall();
        listLoaded = true;
        listError.clear();
    }

    void loadDetails(const std::string& choice) {
        detailKey.clear();
        detailKind.clear();
        detailEffects.clear();
        detailTriggers.clear();
        detailError.clear();

        if (!Gui::Lua::beginTableCallWithString(DETAILS, choice.c_str())) {
            detailError = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            detailKey = Gui::Lua::stringField("key");
            detailKind = Gui::Lua::stringField("kind");
            detailEffects = Gui::Lua::stringField("effects");
            detailTriggers = Gui::Lua::stringField("triggers");
        }
        else {
            detailError = Gui::Lua::stringField("reason", "unavailable");
        }

        Gui::Lua::endCall();
    }

    /**@brief read only multiline box, so the text stays selectable and copyable
       @param height pixels, or -FLT_MIN to fill the remaining height (0 would mean
              ImGui's default of 8 lines, which never grows with the pane)*/
    void drawTextBox(const char* id, const std::string& text, float height) {
        ImGui::InputTextMultiline(id,
            const_cast<char*>(text.c_str()), text.size() + 1,
            ImVec2(-FLT_MIN, height), ImGuiInputTextFlags_ReadOnly);
    }

    void drawModifiers() {
        if (ImGui::Button("Reload")) {
            loadList();
            if (!selectedChoice.empty()) {
                loadDetails(selectedChoice);
            }
        }
        ImGui::SameLine();

        if (!listLoaded) {
            ImGui::TextDisabled("%s", listError.empty() ? "Loading..." : listError.c_str());
            // One automatic attempt; after that it is on the Reload button so a
            // failure doesn't re-parse the files every frame.
            if (!triedOnce) {
                triedOnce = true;
                loadList();
            }
            return;
        }

        ImGui::TextDisabled("%d modifiers", static_cast<int>(modifiers.size()));

        if (Gui::filteredList("list", ImVec2(300.0f, 0), modifiers,
            filter, sizeof(filter), selectedChoice)) {
            loadDetails(selectedChoice);
        }

        ImGui::SameLine();

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedChoice.empty()) {
            ImGui::TextDisabled("Select a modifier.");
        }
        else if (!detailError.empty()) {
            ImGui::TextDisabled("%s", detailError.c_str());
        }
        else {
            ImGui::Text("%s", detailKey.c_str());
            if (!detailKind.empty()) {
                ImGui::SameLine();
                ImGui::TextDisabled("(%s)", detailKind.c_str());
            }
            ImGui::Separator();

            const float half = ImGui::GetContentRegionAvail().y * 0.5f - ImGui::GetTextLineHeightWithSpacing();

            ImGui::TextUnformatted("Effects");
            drawTextBox("##effects", detailEffects, half);

            ImGui::TextUnformatted("Conditions");
            drawTextBox("##triggers",
                detailTriggers.empty() ? std::string("(none)") : detailTriggers, -FLT_MIN);
        }
        ImGui::EndChild();
    }

    class ModifiersPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Modifiers"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 70; }
        void draw() override { drawModifiers(); }
    };
}

REGISTER_GUI_PAGE(ModifiersPage);
