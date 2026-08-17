// Strategic Resources: stockpile balance, trade flows and whether the AI may sell
// each of the mod's strategic resources.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <map>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.StratResources.Collect";
    const char* SET_SELLING = "BiceLibGui.StratResources.SetSelling";

    struct Resource
    {
        std::string key;
        std::string name;
        double balance = 0.0;
        double sell = 0.0;
        double buy = 0.0;
        bool selling = true;
    };

    bool valid = false;
    bool available = false;
    std::string reason;
    std::string tag;
    std::vector<Resource> resources;

    ULONGLONG lastSampleMs = 0;
    bool autoRefresh = true;

    /**
     * Toggles the game has been asked for but has not applied yet.
     *
     * CCurrentGameState.Post queues a command rather than executing it, so reading the
     * variable straight after posting still returns the old value - the checkbox would
     * snap back until the game got round to it. The requested value is shown instead,
     * marked as pending, and dropped once the game reports the same thing.
     */
    std::map<std::string, bool> pendingSelling;

    /**@brief reads the table any of the Lua calls leaves on the stack*/
    void readSnapshot() {
        available = Gui::Lua::boolField("available");
        reason = Gui::Lua::stringField("reason");
        tag = Gui::Lua::stringField("tag");
        resources.clear();

        if (!available) {
            return;
        }

        const int count = Gui::Lua::arrayLength("rows");
        resources.reserve(static_cast<size_t>(count));
        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement("rows", i)) {
                continue;
            }
            Resource resource;
            resource.key = Gui::Lua::stringField("key");
            resource.name = Gui::Lua::stringField("name");
            resource.balance = Gui::Lua::numberField("balance");
            resource.sell = Gui::Lua::numberField("sell");
            resource.buy = Gui::Lua::numberField("buy");
            resource.selling = Gui::Lua::boolField("selling", true);
            resources.push_back(resource);
            Gui::Lua::popArrayElement();
        }

        // A pending toggle the game has now applied is no longer pending.
        for (const Resource& resource : resources) {
            const auto it = pendingSelling.find(resource.key);
            if (it != pendingSelling.end() && it->second == resource.selling) {
                pendingSelling.erase(it);
            }
        }
    }

    void refresh() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void setSelling(const std::string& key, bool enabled) {
        // Recorded before the read, so readSnapshot does not immediately clear it
        // against the value the game has yet to change.
        pendingSelling[key] = enabled;

        if (!Gui::Lua::beginTableCallWithStringAndNumber(SET_SELLING, key.c_str(), enabled ? 1 : 0)) {
            valid = false;
            return;
        }
        valid = true;
        readSnapshot();
        Gui::Lua::endCall();
    }

    void drawStratResources() {
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
        if (!valid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!available) {
            ImGui::TextDisabled("%s", reason.c_str());
            return;
        }
        ImGui::TextDisabled("%s (%s)", tag.c_str(), Gui::Selection::source().c_str());

        if (!ImGui::BeginTable("resources", 5, ImGuiTableFlags_RowBg |
            ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingFixedFit)) {
            return;
        }

        // Numeric columns are sized to the widest value they can hold rather than
        // stretched: stretching gave four wide columns of whitespace and squeezed the
        // only column with anything long in it.
        const float numberWidth = ImGui::CalcTextSize("-000000").x;
        const float salesWidth = ImGui::CalcTextSize("Stopped...").x + ImGui::GetFrameHeight();

        ImGui::TableSetupColumn("Resource", ImGuiTableColumnFlags_WidthStretch);
        ImGui::TableSetupColumn("Balance", ImGuiTableColumnFlags_WidthFixed, numberWidth);
        ImGui::TableSetupColumn("Selling", ImGuiTableColumnFlags_WidthFixed, numberWidth);
        ImGui::TableSetupColumn("Buying", ImGuiTableColumnFlags_WidthFixed, numberWidth);
        ImGui::TableSetupColumn("Sales", ImGuiTableColumnFlags_WidthFixed, salesWidth);
        ImGui::TableHeadersRow();

        for (const Resource& resource : resources) {
            ImGui::TableNextRow();
            ImGui::PushID(resource.key.c_str());

            ImGui::TableNextColumn();
            ImGui::TextUnformatted(resource.name.c_str());

            ImGui::TableNextColumn();
            // A negative balance is a shortage, which is the thing worth spotting.
            if (resource.balance < 0.0) {
                ImGui::TextColored(ImVec4(0.85f, 0.35f, 0.35f, 1.0f), "%.0f", resource.balance);
            }
            else {
                ImGui::Text("%.0f", resource.balance);
            }

            ImGui::TableNextColumn();
            ImGui::Text("%.0f", resource.sell);

            ImGui::TableNextColumn();
            ImGui::Text("%.0f", resource.buy);

            ImGui::TableNextColumn();
            const auto pending = pendingSelling.find(resource.key);
            const bool isPending = (pending != pendingSelling.end());
            bool selling = isPending ? pending->second : resource.selling;

            if (ImGui::Checkbox("##selling", &selling)) {
                setSelling(resource.key, selling);
                ImGui::PopID();
                break; // setSelling refilled the vector; stop iterating it
            }
            ImGui::SameLine();
            if (isPending) {
                // Shown as asked for, but flagged until the game confirms it.
                ImGui::TextColored(ImVec4(0.80f, 0.60f, 0.20f, 1.0f),
                    selling ? "Selling..." : "Stopped...");
                if (ImGui::IsItemHovered()) {
                    ImGui::SetTooltip("Waiting for the game to apply this");
                }
            }
            else {
                ImGui::TextUnformatted(selling ? "Selling" : "Stopped");
            }

            ImGui::PopID();
        }
        ImGui::EndTable();
    }

    class StratResourcesPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Strategic Res."; }
        const char* group() const override { return "Main"; }
        int order() const override { return 50; }
        void draw() override { drawStratResources(); }
    };
}

REGISTER_GUI_PAGE(StratResourcesPage);
