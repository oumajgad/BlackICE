// Strategic Trades and Global Market.
//
// Two pages in one file because they share a data source: the country's own trades and
// the market of who has spare capacity to sell into it.
//
// The wx utility opened the market as a separate top level window. Here it is another
// page, so it docks and tabs alongside everything else.

#include <Gui/GuiPage.hpp>
#include <Gui/LuaBridge.hpp>
#include <Gui/ListBox.hpp>
#include <Gui/CountrySelection.hpp>

#include <Windows.h>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    const char* COLLECT = "BiceLibGui.Trades.Collect";
    const char* RESOURCES = "BiceLibGui.Trades.Resources";
    const char* MARKET = "BiceLibGui.Trades.Market";

    struct Trade
    {
        std::string buyer;
        std::string seller;
        std::string resource;
        int expiresIn = 0;
    };

    struct MarketRow
    {
        std::string tag;
        double potential = 0.0;
        double sales = 0.0;
        double available = 0.0;
        int nextExpiry = -1;
    };

    // --- Strategic Trades ---
    bool tradesValid = false;
    bool tradesAvailable = false;
    std::string tradesReason;
    std::string tradesTag;
    std::vector<Trade> buys;
    std::vector<Trade> sales;
    ULONGLONG tradesSampleMs = 0;
    bool tradesAuto = true;

    // --- Global Market ---
    std::vector<std::string> resourceKeys;
    std::vector<std::string> resourceNames;
    int resourceIndex = 0;
    bool marketValid = false;
    bool marketAvailable = false;
    std::string marketReason;
    std::vector<MarketRow> marketRows;
    ULONGLONG marketSampleMs = 0;
    bool marketAuto = false; // Walks every country, so not on a timer by default

    void readTradeList(const char* key, std::vector<Trade>& out) {
        out.clear();
        const int count = Gui::Lua::arrayLength(key);
        out.reserve(static_cast<size_t>(count));

        for (int i = 0; i < count; i++) {
            if (!Gui::Lua::pushArrayElement(key, i)) {
                continue;
            }
            Trade trade;
            trade.buyer = Gui::Lua::stringField("buyer");
            trade.seller = Gui::Lua::stringField("seller");
            trade.resource = Gui::Lua::stringField("resource");
            trade.expiresIn = static_cast<int>(Gui::Lua::numberField("expires_in"));
            out.push_back(trade);
            Gui::Lua::popArrayElement();
        }
    }

    void refreshTrades() {
        if (!Gui::Lua::beginTableCall(COLLECT)) {
            tradesValid = false;
            return;
        }
        tradesValid = true;
        tradesAvailable = Gui::Lua::boolField("available");
        tradesReason = Gui::Lua::stringField("reason");
        tradesTag = Gui::Lua::stringField("tag");

        if (tradesAvailable) {
            readTradeList("buys", buys);
            readTradeList("sales", sales);
        }
        else {
            buys.clear();
            sales.clear();
        }
        Gui::Lua::endCall();
    }

    void loadResources() {
        if (!Gui::Lua::beginTableCall(RESOURCES)) {
            return;
        }
        if (Gui::Lua::boolField("available")) {
            resourceKeys.clear();
            resourceNames.clear();
            const int count = Gui::Lua::arrayLength("resources");
            for (int i = 0; i < count; i++) {
                if (!Gui::Lua::pushArrayElement("resources", i)) {
                    continue;
                }
                resourceKeys.push_back(Gui::Lua::stringField("key"));
                resourceNames.push_back(Gui::Lua::stringField("name"));
                Gui::Lua::popArrayElement();
            }
        }
        Gui::Lua::endCall();
    }

    void refreshMarket() {
        if (resourceKeys.empty()) {
            loadResources();
        }
        if (resourceIndex < 0 || resourceIndex >= static_cast<int>(resourceKeys.size())) {
            return;
        }

        if (!Gui::Lua::beginTableCallWithString(MARKET, resourceKeys[resourceIndex].c_str())) {
            marketValid = false;
            return;
        }
        marketValid = true;
        marketAvailable = Gui::Lua::boolField("available");
        marketReason = Gui::Lua::stringField("reason");
        marketRows.clear();

        if (marketAvailable) {
            const int count = Gui::Lua::arrayLength("rows");
            marketRows.reserve(static_cast<size_t>(count));
            for (int i = 0; i < count; i++) {
                if (!Gui::Lua::pushArrayElement("rows", i)) {
                    continue;
                }
                MarketRow row;
                row.tag = Gui::Lua::stringField("tag");
                row.potential = Gui::Lua::numberField("potential");
                row.sales = Gui::Lua::numberField("sales");
                row.available = Gui::Lua::numberField("available");
                row.nextExpiry = static_cast<int>(Gui::Lua::numberField("next_expiry"));
                marketRows.push_back(row);
                Gui::Lua::popArrayElement();
            }
        }
        Gui::Lua::endCall();
    }

    /**@brief one of the buys/sales tables. \p partnerLabel names the other side.*/
    void drawTradeTable(const char* id, const char* partnerLabel,
        const std::vector<Trade>& trades, bool showSeller) {

        if (trades.empty()) {
            ImGui::TextDisabled("None.");
            return;
        }

        if (!ImGui::BeginTable(id, 3, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner |
            ImGuiTableFlags_SizingFixedFit)) {
            return;
        }

        // Wide enough for the header as well as the values: the headers here are
        // longer than anything in the columns, so sizing to the numbers clips them.
        const float padding = ImGui::GetStyle().CellPadding.x * 2.0f;
        ImGui::TableSetupColumn(partnerLabel, ImGuiTableColumnFlags_WidthFixed,
            ImGui::CalcTextSize(partnerLabel).x + padding);
        ImGui::TableSetupColumn("Resource", ImGuiTableColumnFlags_WidthStretch);
        ImGui::TableSetupColumn("Expires", ImGuiTableColumnFlags_WidthFixed,
            ImGui::CalcTextSize("Expires").x + padding);
        ImGui::TableHeadersRow();

        for (const Trade& trade : trades) {
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(showSeller ? trade.seller.c_str() : trade.buyer.c_str());
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(trade.resource.c_str());
            ImGui::TableNextColumn();
            // Expiring within a week is worth noticing before it lapses.
            if (trade.expiresIn <= 7) {
                ImGui::TextColored(ImVec4(0.85f, 0.60f, 0.20f, 1.0f), "%dd", trade.expiresIn);
            }
            else {
                ImGui::Text("%dd", trade.expiresIn);
            }
        }
        ImGui::EndTable();
    }

    void drawTrades() {
        if (ImGui::Button("Refresh")) {
            refreshTrades();
            tradesSampleMs = GetTickCount64();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &tradesAuto);

        if (tradesAuto) {
            const ULONGLONG now = GetTickCount64();
            if (now - tradesSampleMs >= 2000) {
                refreshTrades();
                tradesSampleMs = now;
            }
        }

        ImGui::SameLine();
        if (!tradesValid) {
            ImGui::TextDisabled("Lua unavailable: %s", Gui::Lua::unavailableReason());
            return;
        }
        if (!tradesAvailable) {
            ImGui::TextDisabled("%s", tradesReason.c_str());
            return;
        }
        ImGui::TextDisabled("%s (%s)", tradesTag.c_str(), Gui::Selection::source().c_str());

        ImGui::SeparatorText("Buying");
        drawTradeTable("buys", "Seller", buys, true);

        ImGui::Spacing();
        ImGui::SeparatorText("Selling");
        drawTradeTable("sales", "Buyer", sales, false);
    }

    void drawMarket() {
        if (resourceKeys.empty()) {
            loadResources();
        }

        if (ImGui::Button("Refresh")) {
            refreshMarket();
            marketSampleMs = GetTickCount64();
        }
        ImGui::SameLine();
        ImGui::Checkbox("Auto", &marketAuto);
        if (ImGui::IsItemHovered()) {
            ImGui::SetTooltip("Off by default: this reads a variable from every\n"
                "country in the game, which is too much for a timer.");
        }

        ImGui::SameLine();
        ImGui::SetNextItemWidth(160.0f);
        std::vector<const char*> names;
        names.reserve(resourceNames.size());
        for (const std::string& name : resourceNames) {
            names.push_back(name.c_str());
        }
        if (!names.empty() && Gui::wheelCombo("##resource", &resourceIndex,
            names.data(), static_cast<int>(names.size()))) {
            refreshMarket();
        }

        if (marketAuto) {
            const ULONGLONG now = GetTickCount64();
            if (now - marketSampleMs >= 5000) {
                refreshMarket();
                marketSampleMs = now;
            }
        }

        if (!marketValid) {
            ImGui::TextDisabled("%s", Gui::Lua::unavailableReason());
            return;
        }
        if (!marketAvailable) {
            ImGui::TextDisabled("%s", marketReason.c_str());
            return;
        }

        const char* note = "A trade decision can be unavailable even when a country has "
            "resources spare: each trade applies a two day cooldown that blocks the buy "
            "decision while it is handled. Wait and watch your decisions.";

        // A ScrollY table with no explicit height takes everything that is left, which
        // pushed the note off the bottom at any window size. Measure the note first and
        // hand the table the rest.
        const ImGuiStyle& style = ImGui::GetStyle();
        const float noteHeight =
            ImGui::CalcTextSize(note, nullptr, false, ImGui::GetContentRegionAvail().x).y;
        float tableHeight = ImGui::GetContentRegionAvail().y - noteHeight - style.ItemSpacing.y * 3.0f;
        if (tableHeight < ImGui::GetTextLineHeightWithSpacing() * 3.0f) {
            tableHeight = ImGui::GetTextLineHeightWithSpacing() * 3.0f;
        }

        if (marketRows.empty()) {
            ImGui::TextDisabled("No country has spare production of this resource.");
        }
        else {
            const float numberWidth = ImGui::CalcTextSize("000000").x;
            if (ImGui::BeginTable("market", 5, ImGuiTableFlags_RowBg |
                ImGuiTableFlags_BordersInner | ImGuiTableFlags_ScrollY |
                ImGuiTableFlags_SizingFixedFit, ImVec2(0.0f, tableHeight))) {

                ImGui::TableSetupScrollFreeze(0, 1);
                ImGui::TableSetupColumn("Country", ImGuiTableColumnFlags_WidthStretch);
                ImGui::TableSetupColumn("Potential", ImGuiTableColumnFlags_WidthFixed, numberWidth);
                ImGui::TableSetupColumn("Sales", ImGuiTableColumnFlags_WidthFixed, numberWidth);
                ImGui::TableSetupColumn("Available", ImGuiTableColumnFlags_WidthFixed, numberWidth);
                ImGui::TableSetupColumn("Next expiry", ImGuiTableColumnFlags_WidthFixed,
                    ImGui::CalcTextSize("Next expiry").x);
                ImGui::TableHeadersRow();

                for (const MarketRow& row : marketRows) {
                    ImGui::TableNextRow();
                    ImGui::TableNextColumn();
                    ImGui::TextUnformatted(row.tag.c_str());
                    ImGui::TableNextColumn();
                    ImGui::Text("%.0f", row.potential);
                    ImGui::TableNextColumn();
                    ImGui::Text("%.0f", row.sales);
                    ImGui::TableNextColumn();
                    // What can actually be bought right now.
                    if (row.available > 0.0) {
                        ImGui::TextColored(ImVec4(0.35f, 0.80f, 0.40f, 1.0f), "%.0f", row.available);
                    }
                    else {
                        ImGui::Text("%.0f", row.available);
                    }
                    ImGui::TableNextColumn();
                    if (row.nextExpiry < 0) {
                        ImGui::TextDisabled("-");
                    }
                    else {
                        ImGui::Text("%dd", row.nextExpiry);
                    }
                }
                ImGui::EndTable();
            }
        }

        ImGui::Spacing();
        ImGui::TextWrapped("%s", note);
    }

    class TradesPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Strategic Trades"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 60; }
        void draw() override { drawTrades(); }
    };

    class MarketPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Global Market"; }
        const char* group() const override { return "Country Info"; }
        int order() const override { return 70; }
        void draw() override { drawMarket(); }
    };
}

REGISTER_GUI_PAGE(TradesPage);
REGISTER_GUI_PAGE(MarketPage);
