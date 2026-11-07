#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>

#include <Windows.h>

#include <imgui.h>

#include <string>

#include <Hooks/Slot11Probe.hpp>

namespace {
    /////////////////////////////////////////////////
    //   WHO CALLS CCombatant SLOT 11 - ONE TEST   //
    /////////////////////////////////////////////////

    std::string reportPath;

    void drawSlot11Probe() {
        ImGui::TextWrapped(
            "Who calls CCombatant slot 11? The static reading says nothing but CCombat slot 17, "
            "so the only return addresses should ever be 0x17B085 and 0x17B093 - plus 0x168EED, "
            "which is CLandCombatant's own slot-11 forwarder calling the base body, and is where "
            "almost every land combat arrives. That answer rests "
            "on four sweeps and is bounded by two holes no static reading can close: 1.8%% of "
            "non-padding .text is outside the decode, and slot 11 can also be reached through a "
            "vcall thunk from a listener table that is filled at runtime. A hook sees every real "
            "call however it arrived, so one battle settles it.");

        ImGui::Spacing();
        ImGui::TextWrapped(
            "If only those two appear, the defence side of every naval, air and bombing combat "
            "modifier is cosmetic in this build - a mod cannot reach the simulation through any of "
            "them. A third address means that claim is wrong, and names the caller.");

        ImGui::Spacing();
        ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
            "You have to be fighting. Observing is not enough.");
        ImGui::TextWrapped(
            "CCombat::Tick gates the refresh on the player's own country id appearing in the "
            "attacker's or defender's country list, so slot 11 never runs for an AI-vs-AI battle. "
            "Which is itself a finding - those modifiers are player-only, not just display-only - "
            "but it means an observer country records nothing at all.");

        ImGui::SeparatorText("Probe");

        if (!Hooks::Slot11Probe::installed()) {
            if (ImGui::Button("Install the hook")) {
                Hooks::Slot11Probe::install();
            }
            ImGui::SameLine();
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning), "%s",
                Hooks::Slot11Probe::status());
            return;
        }

        bool recording = Hooks::Slot11Probe::isRecording();
        if (ImGui::Checkbox("Recording", &recording)) {
            Hooks::Slot11Probe::setRecording(recording);
        }
        ImGui::SameLine();
        if (ImGui::Button("Reset")) {
            Hooks::Slot11Probe::reset();
        }
        ImGui::SameLine();
        if (ImGui::Button("Write report to file")) {
            const char* written = Hooks::Slot11Probe::writeReport();
            reportPath = written ? written : "could not be written";
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%s", Hooks::Slot11Probe::status());

        if (!reportPath.empty()) {
            ImGui::TextWrapped("Report: %s", reportPath.c_str());
        }

        if (!recording) {
            ImGui::TextWrapped(
                "While this is off the hook runs no code of ours at all - one compare per call - "
                "so it is safe to leave installed.");
        }

        const long calls = Hooks::Slot11Probe::callCount();
        const int sites = Hooks::Slot11Probe::siteCount();
        const long lost = Hooks::Slot11Probe::overflowCount();

        ImGui::Spacing();
        ImGui::Text("Calls seen: %ld   distinct return addresses: %d", calls, sites);
        if (lost > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error),
                "%ld calls arrived after the table filled - addresses were lost.", lost);
        }

        if (calls == 0) {
            if (recording) {
                ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                    "Nothing yet - and a zero here is NOT a result.");
                ImGui::TextWrapped(
                    "CCombat::Tick only refreshes the combat_status billboard when the player's "
                    "own country id is in the attacker's or the defender's country list. So slot "
                    "11 runs only for battles YOU are a belligerent in: watching someone else's "
                    "war as an observer produces zero calls, and that looks exactly like a broken "
                    "hook. Get into a fight before reading anything into this.");
            }
            else {
                ImGui::TextDisabled("Nothing yet - switch recording on.");
            }
            return;
        }

        if (ImGui::BeginTable("slot11sites", 3,
            ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("Return address");
            ImGui::TableSetupColumn("Calls");
            ImGui::TableSetupColumn("Known?");
            ImGui::TableHeadersRow();

            for (int i = 0; i < sites; i++) {
                const Hooks::Slot11Probe::Site site = Hooks::Slot11Probe::site(i);

                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::Text("%#010x", site.moduleRelative);
                ImGui::TableNextColumn();
                ImGui::Text("%ld", site.count);
                ImGui::TableNextColumn();
                if (site.expected) {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success),
                        "CCombat slot 17");
                }
                else {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error), "UNKNOWN");
                }
            }
            ImGui::EndTable();
        }

        // The verdict, stated so it cannot be misread either way round. Note that seeing only
        // one of the two expected sites is not a failure: the two calls are the attacker and
        // the defender, and a battle with one side empty would only reach one of them.
        int unknown = 0;
        for (int i = 0; i < sites; i++) {
            if (!Hooks::Slot11Probe::site(i).expected) {
                unknown++;
            }
        }

        ImGui::Spacing();
        if (unknown > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error),
                "%d caller(s) the static reading did not find.", unknown);
            ImGui::TextWrapped(
                "FINDINGS-slot11.md is wrong and this is the evidence. Add the address above to "
                "it - and note that the defence-side modifiers may not be cosmetic after all.");
        }
        else if (lost > 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "Only known callers so far, but the table overflowed - not conclusive.");
        }
        else {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success),
                "Only CCombat slot 17, over %ld calls.", calls);
            ImGui::TextWrapped(
                "This is evidence for the static answer, not proof of it: it says nothing about "
                "a caller that has not run yet. Fight land, air, naval and bombing battles, and "
                "with several kinds seen and no unknown address the claim is as settled as a live "
                "test can make it.");
        }
    }
}

namespace {
    class Slot11ProbePage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Slot 11 Probe"; }
        const char* group() const override { return "Debug"; }
        int order() const override { return 60; }
        void draw() override { drawSlot11Probe(); }
    };
}

REGISTER_GUI_PAGE(Slot11ProbePage);
