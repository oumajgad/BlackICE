// Unit Models: a country's unit models, the technologies each requires against what
// the country has researched, and the sprite the game will draw for it.
//
// The sprite is a .tga from the mod's gfx folder, decoded and uploaded by
// Gui::Textures. Which file to draw is decided in Lua, since that is file lookup with
// the game's fallback rules rather than rendering.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>
#include <Gui/TextureCache.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <cfloat>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.UnitModels.Collect";
    const char* DETAILS = "BiceLibGui.UnitModels.Details";

    struct TechRow
    {
        std::string label;
        int required = 0;
        int researched = 0;
    };

    std::vector<std::string> models;
    bool listLoaded = false;
    std::string listError;
    std::string loadedTag;

    std::string selectedModel;
    std::string detailKey;
    std::string imagePath;
    std::string imageStatus;
    std::string detailError;
    std::vector<TechRow> techs;

    char filter[64] = {};
    float listWidth = 280.0f; // Drag the divider to change

    // Fixed ladder rather than a free multiplier: whole number steps keep the pixel
    // art crisp at the sizes people actually want to look at.
    const float ZOOM_STEPS[] = { 0.5f, 1.0f, 2.0f, 3.0f, 4.0f, 6.0f, 8.0f };
    int zoomIndex = 1;      // 1.0f
    bool fitToPane = true;  // Shrink oversized sprites to fit, never enlarge

    void loadDetails(const std::string& choice) {
        detailKey.clear();
        imagePath.clear();
        imageStatus.clear();
        detailError.clear();
        techs.clear();

        if (!Gui::Lua::beginTableCallWithString(DETAILS, choice.c_str())) {
            detailError = Gui::Lua::unavailableReason();
            return;
        }

        if (Gui::Lua::boolField("available")) {
            detailKey = Gui::Lua::stringField("key");
            imagePath = Gui::Lua::stringField("image_path");
            imageStatus = Gui::Lua::stringField("image_status");

            const int count = Gui::Lua::arrayLength("techs");
            techs.reserve(static_cast<size_t>(count));
            for (int i = 0; i < count; i++) {
                if (!Gui::Lua::pushArrayElement("techs", i)) {
                    continue;
                }
                TechRow row;
                row.label = Gui::Lua::stringField("label");
                row.required = static_cast<int>(Gui::Lua::numberField("required"));
                row.researched = static_cast<int>(Gui::Lua::numberField("researched"));
                techs.push_back(row);
                Gui::Lua::popArrayElement();
            }
        }
        else {
            detailError = Gui::Lua::stringField("reason", "unavailable");
        }

        Gui::Lua::endCall();
    }

    void loadList(const std::string& tag) {
        models.clear();
        selectedModel.clear();
        listLoaded = false;
        loadedTag = tag;

        if (!Gui::Lua::beginTableCall(COLLECT)) {
            listError = Gui::Lua::unavailableReason();
            return;
        }
        if (!Gui::Lua::boolField("available")) {
            listError = Gui::Lua::stringField("reason", "unavailable");
            Gui::Lua::endCall();
            return;
        }

        const int count = Gui::Lua::arrayLength("models");
        models.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            models.push_back(Gui::Lua::arrayStringAt("models", i));
        }

        Gui::Lua::endCall();
        listLoaded = true;
        listError.clear();
    }

    void drawSprite() {
        ImGui::SeparatorText("Sprite");

        if (imagePath.empty()) {
            ImGui::TextDisabled("%s", imageStatus.empty() ? "No image" : imageStatus.c_str());
            return;
        }

        const ImTextureID texture = Gui::Textures::get(imagePath);
        if (texture == 0) {
            ImGui::TextDisabled("Could not load %s", imagePath.c_str());
            return;
        }

        const ImVec2 size = Gui::Textures::size(imagePath);
        const int lastZoom = static_cast<int>(sizeof(ZOOM_STEPS) / sizeof(ZOOM_STEPS[0])) - 1;

        if (ImGui::SmallButton("-")) {
            fitToPane = false;
            zoomIndex = (zoomIndex > 0) ? zoomIndex - 1 : 0;
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("+")) {
            fitToPane = false;
            zoomIndex = (zoomIndex < lastZoom) ? zoomIndex + 1 : lastZoom;
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("Fit")) {
            fitToPane = true;
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("1:1")) {
            fitToPane = false;
            zoomIndex = 1;
        }
        ImGui::SameLine();

        float scale = ZOOM_STEPS[zoomIndex];
        if (fitToPane) {
            // Shrink to fit but never enlarge, which is the sensible default for
            // sprites that are already small.
            const float available = ImGui::GetContentRegionAvail().x;
            scale = (size.x > available && size.x > 0.0f) ? available / size.x : 1.0f;
        }
        if (fitToPane) {
            ImGui::TextDisabled("fit (%.0f%%)  |  %.0fx%.0f  |  %s",
                scale * 100.0f, size.x, size.y, imageStatus.c_str());
        }
        else {
            ImGui::TextDisabled("%.0f%%  |  %.0fx%.0f  |  %s",
                scale * 100.0f, size.x, size.y, imageStatus.c_str());
        }

        // Scrollable so an enlarged sprite can be panned rather than clipped.
        ImGui::BeginChild("sprite", ImVec2(0, 0), ImGuiChildFlags_Borders,
            ImGuiWindowFlags_HorizontalScrollbar);
        ImGui::Image(texture, ImVec2(size.x * scale, size.y * scale));
        ImGui::EndChild();
    }

    void drawUnitModels() {
        const std::string& tag = Gui::Selection::tag();

        // The country is owned by Setup, so reload when it changes.
        if (tag != loadedTag) {
            loadList(tag);
        }

        if (ImGui::Button("Reload")) {
            loadList(tag);
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%s", tag.empty() ? "no country" : tag.c_str());

        if (!listLoaded) {
            ImGui::TextDisabled("%s", listError.empty() ? "No models loaded." : listError.c_str());
            return;
        }

        ImGui::SameLine();
        ImGui::TextDisabled("| %d models", static_cast<int>(models.size()));

        if (Gui::filteredList("list", ImVec2(listWidth, 0), models,
            filter, sizeof(filter), selectedModel)) {
            loadDetails(selectedModel);
        }

        Gui::verticalSplitter("##split", &listWidth);

        ImGui::BeginChild("details", ImVec2(0, 0));
        if (selectedModel.empty()) {
            ImGui::TextDisabled("Select a model.");
        }
        else if (!detailError.empty()) {
            ImGui::TextDisabled("%s", detailError.c_str());
        }
        else {
            ImGui::Text("%s", detailKey.c_str());

            ImGui::SeparatorText("Required technologies");
            if (techs.empty()) {
                ImGui::TextDisabled("No technology requirements.");
            }
            else if (ImGui::BeginTable("techs", 3,
                ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner |
                ImGuiTableFlags_ScrollY | ImGuiTableFlags_SizingFixedFit,
                ImVec2(0.0f, ImGui::GetContentRegionAvail().y * 0.45f))) {

                // Level columns sized to their content; the name column takes the rest.
                const float levelWidth = ImGui::CalcTextSize("Needs").x;

                ImGui::TableSetupScrollFreeze(0, 1);
                ImGui::TableSetupColumn("Technology", ImGuiTableColumnFlags_WidthStretch);
                ImGui::TableSetupColumn("Needs", ImGuiTableColumnFlags_WidthFixed, levelWidth);
                ImGui::TableSetupColumn("Has", ImGuiTableColumnFlags_WidthFixed, levelWidth);
                ImGui::TableHeadersRow();

                for (const TechRow& row : techs) {
                    ImGui::TableNextRow();
                    ImGui::TableNextColumn();
                    ImGui::TextUnformatted(row.label.c_str());
                    ImGui::TableNextColumn();
                    ImGui::Text("%d", row.required);
                    ImGui::TableNextColumn();
                    // Red when the country cannot field this model yet.
                    if (row.researched < row.required) {
                        ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error), "%d", row.researched);
                    }
                    else {
                        ImGui::Text("%d", row.researched);
                    }
                }
                ImGui::EndTable();
            }

            drawSprite();
        }
        ImGui::EndChild();
    }

    class UnitModelsPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Unit Models"; }
        const char* group() const override { return "Game Info"; }
        int order() const override { return 100; }
        void draw() override { drawUnitModels(); }
    };
}

REGISTER_GUI_PAGE(UnitModelsPage);
