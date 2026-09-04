// Timing: how long each page took the first time it was drawn.
//
// Opening the overlay for the first time in a session takes a noticeable moment, and
// the reason is that a page does its loading on its first draw - parsing the mod's
// files, asking Lua for a list, decoding a flag. Every later frame is just drawing. So
// the first call is the one worth measuring, and its total across the pages is very
// nearly the wait being complained about.
//
// The measurement lives in the registry, around the draw() call itself; this page only
// reports it.

#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>
#include <Gui/Warmup.hpp>

#include <algorithm>
#include <string>
#include <vector>

#include <imgui.h>

namespace {
    // Anything under this is indistinguishable from drawing, and colouring it would
    // only make the table harder to read.
    const double INTERESTING_MS = 5.0;

    int sortMode = 0; // 0 slowest first, 1 page order

    void drawTiming() {
        const std::vector<Gui::GuiPage*>& pages = Gui::pages();

        std::vector<Gui::GuiPage*> rows(pages.begin(), pages.end());
        if (sortMode == 0) {
            std::stable_sort(rows.begin(), rows.end(),
                [](const Gui::GuiPage* a, const Gui::GuiPage* b) {
                    return Gui::timing(a).firstMs > Gui::timing(b).firstMs;
                });
        }

        double total = 0.0;
        int drawn = 0;
        for (const Gui::GuiPage* page : rows) {
            const Gui::PageTiming& timing = Gui::timing(page);
            if (timing.calls > 0) {
                total += timing.firstMs;
                drawn++;
            }
        }

        ImGui::Text("%.0f ms across %d pages", total, drawn);
        ImGui::SameLine();
        ImGui::TextDisabled("(%d not drawn yet)", static_cast<int>(rows.size()) - drawn);
        ImGui::SetItemTooltip("A page is only drawn once its tab is looked at, so its "
            "cost has not been paid yet.");

        ImGui::SameLine();
        if (ImGui::RadioButton("Slowest", sortMode == 0)) {
            sortMode = 0;
        }
        ImGui::SameLine();
        if (ImGui::RadioButton("Page order", sortMode == 1)) {
            sortMode = 1;
        }
        ImGui::SameLine();
        if (ImGui::Button("Reset")) {
            Gui::resetTimings();
        }
        ImGui::SetItemTooltip("Clears every measurement. What is recorded afterwards is "
            "a first draw again, but not a cold one: whatever a page loaded the first "
            "time is still loaded.");

        ImGui::TextWrapped("First is the call that includes a page's loading, and is "
            "what the wait on opening the overlay is made of. Worst and last are the "
            "frames after that, where a large number means the page is doing work every "
            "frame rather than caching it.");

        ImGui::SeparatorText("Warm up");
        const Gui::WarmupState& warmup = Gui::warmupState();

        // Reported, not switched here: by the time this page can be looked at the
        // parsing has usually already happened, so a checkbox would only ever describe
        // the past. G_ImguiWarmupEnabled in script/utility_settings.lua decides it.
        ImGui::TextWrapped("Parses one dataset per frame while the game sits at the "
            "menu, so a page has nothing left to parse by the time it is opened. Set by "
            "G_ImguiWarmupEnabled in script/utility_settings.lua.");

        if (warmup.finished) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success),
                "done, %.0f ms spent up front", warmup.totalMs);
        }
        else if (warmup.started) {
            ImGui::Text("%d of %d - last: %s (%.0f ms)", warmup.done, warmup.total,
                warmup.last.c_str(), warmup.lastMs);
        }
        else if (warmup.enabled) {
            ImGui::TextDisabled("waiting to start");
        }
        else {
            ImGui::TextDisabled("off - pages will parse when first opened");
        }

        ImGui::SameLine();
        ImGui::BeginDisabled(warmup.finished);
        if (ImGui::Button("Parse now")) {
            // Freezes the game for as long as it takes, which is the honest cost of
            // asking for it all at once.
            Gui::warmupNow();
        }
        ImGui::EndDisabled();

        ImGui::Spacing();

        if (!ImGui::BeginTable("timings", 6, ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner |
            ImGuiTableFlags_SizingStretchProp | ImGuiTableFlags_ScrollY)) {
            return;
        }

        ImGui::TableSetupColumn("Page", ImGuiTableColumnFlags_WidthStretch, 1.2f);
        ImGui::TableSetupColumn("Group", ImGuiTableColumnFlags_WidthStretch, 0.8f);
        ImGui::TableSetupColumn("First", ImGuiTableColumnFlags_WidthStretch, 0.5f);
        ImGui::TableSetupColumn("Worst", ImGuiTableColumnFlags_WidthStretch, 0.5f);
        ImGui::TableSetupColumn("Last", ImGuiTableColumnFlags_WidthStretch, 0.5f);
        ImGui::TableSetupColumn("Draws", ImGuiTableColumnFlags_WidthStretch, 0.4f);
        ImGui::TableSetupScrollFreeze(0, 1);
        ImGui::TableHeadersRow();

        for (const Gui::GuiPage* page : rows) {
            const Gui::PageTiming& timing = Gui::timing(page);

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(page->title());
            ImGui::TableNextColumn();
            ImGui::TextDisabled("%s", page->group());

            if (timing.calls == 0) {
                ImGui::TableNextColumn();
                ImGui::TextDisabled("not drawn");
                ImGui::TableNextColumn();
                ImGui::TableNextColumn();
                ImGui::TableNextColumn();
                continue;
            }

            ImGui::TableNextColumn();
            // Only the expensive ones are coloured; a table where every row shouts says
            // nothing about which page to look at.
            if (timing.firstMs >= INTERESTING_MS) {
                ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "%.1f ms", timing.firstMs);
            }
            else {
                ImGui::Text("%.1f ms", timing.firstMs);
            }

            ImGui::TableNextColumn();
            ImGui::Text("%.1f ms", timing.worstMs);
            ImGui::TableNextColumn();
            ImGui::Text("%.2f ms", timing.lastMs);
            ImGui::TableNextColumn();
            ImGui::Text("%d", timing.calls);
        }
        ImGui::EndTable();
    }

    class TimingPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Timing"; }
        const char* group() const override { return "Debug"; }
        int order() const override { return 40; }
        void draw() override { drawTiming(); }
    };
}

REGISTER_GUI_PAGE(TimingPage);
