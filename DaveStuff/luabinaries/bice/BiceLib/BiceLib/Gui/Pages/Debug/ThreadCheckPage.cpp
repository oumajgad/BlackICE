#include <Gui/GuiPage.hpp>
#include <Gui/Theme.hpp>

#include <Windows.h>

#include <imgui.h>

#include <Diagnostics.hpp>

namespace {
    /////////////////////////////////////
    //      PHASE 0 THREAD CHECK       //
    /////////////////////////////////////

    void drawThreadCheck() {
        ImGui::SeparatorText("Lua / render thread check");

        const DWORD presentThread = Diagnostics::presentThreadId();
        const int threads = Diagnostics::threadRecordCount();

        ImGui::Text("Render thread: %lu", presentThread);

        if (threads == 0) {
            ImGui::TextDisabled("No Lua calls seen yet.");
            ImGui::TextWrapped("Load a save, or open the old utility and hit Refresh.");
            return;
        }

        if (ImGui::BeginTable("luathreads", 3,
            ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInner | ImGuiTableFlags_SizingStretchProp)) {
            ImGui::TableSetupColumn("Thread");
            ImGui::TableSetupColumn("lua_State");
            ImGui::TableSetupColumn("Calls");
            ImGui::TableHeadersRow();

            for (int i = 0; i < threads; i++) {
                const Diagnostics::ThreadRecord record = Diagnostics::threadRecord(i);
                const bool isRenderThread = (record.threadId == presentThread);

                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                if (isRenderThread) {
                    ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success), "%lu (render)", record.threadId);
                }
                else {
                    ImGui::Text("%lu", record.threadId);
                }
                ImGui::TableNextColumn();
                ImGui::Text("%#010x", static_cast<unsigned>(reinterpret_cast<uintptr_t>(record.luaState)));
                ImGui::TableNextColumn();
                ImGui::Text("%u", record.calls);
            }
            ImGui::EndTable();
        }

        ImGui::Spacing();
        ImGui::Text("Max threads inside Lua at once: %u", Diagnostics::maxConcurrentLuaThreads());
        ImGui::Text("Frames with another thread in Lua: %u", Diagnostics::presentDuringOtherThreadLua());
        ImGui::Text("Frames inside our own Lua call:    %u", Diagnostics::presentDuringOwnLua());

        ImGui::Spacing();

        if (!Diagnostics::presentThreadRunsLua()) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Error),
                "The render thread has never run Lua - snapshot bridge needed.");
            return;
        }

        if (Diagnostics::presentDuringOtherThreadLua() == 0) {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Success),
                "The render thread runs Lua and never renders while another thread is\n"
                "inside Lua - direct calls look safe.");
        }
        else {
            ImGui::TextColored(Gui::Theme::mark(Gui::Theme::Mark::Warning),
                "The render thread runs Lua, but other threads are in Lua during frames.\n"
                "Safe only if those threads use a different lua_State (compare above).");
        }
    }
}

namespace {
    class ThreadCheckPage : public Gui::GuiPage
    {
    public:
        const char* title() const override { return "Thread Check"; }
        const char* group() const override { return "Debug"; }
        int order() const override { return 10; }
        void draw() override { drawThreadCheck(); }
    };
}

REGISTER_GUI_PAGE(ThreadCheckPage);
