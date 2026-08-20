#include <Gui/Warmup.hpp>

#include <Gui/LuaBridge.hpp>

#include <Windows.h>

namespace {
    const char* STEP = "BiceLibGui.Warmup.Step";
    const char* STATE = "BiceLibGui.Warmup.State";

    Gui::WarmupState state;

    /**
     * Frames to leave alone before starting.
     *
     * The overlay's hooks are in place well before the game has finished its own
     * loading, and a two second parse competing with that would only make the wait
     * longer overall. A few seconds is enough to be past it.
     */
    const ULONGLONG QUIET_MS = 5000;
    ULONGLONG firstFrameMs = 0;

    double milliseconds() {
        static LARGE_INTEGER frequency = {};
        if (frequency.QuadPart == 0) {
            QueryPerformanceFrequency(&frequency);
        }

        LARGE_INTEGER counter = {};
        QueryPerformanceCounter(&counter);
        return (frequency.QuadPart == 0)
            ? 0.0
            : (static_cast<double>(counter.QuadPart) * 1000.0) /
              static_cast<double>(frequency.QuadPart);
    }

    /**@brief runs one step; false if Lua could not be reached at all*/
    bool step() {
        const double started = milliseconds();
        if (!Gui::Lua::beginTableCall(STEP)) {
            return false;
        }

        const bool available = Gui::Lua::boolField("available");
        const bool finished = Gui::Lua::boolField("done");
        const int remaining = static_cast<int>(Gui::Lua::numberField("remaining"));
        const std::string name = Gui::Lua::stringField("name");
        Gui::Lua::endCall();

        const double elapsed = milliseconds() - started;

        if (!available) {
            // The module is missing or a step threw. Either way it will not start
            // working on the next frame, so stop rather than stall every frame.
            state.finished = true;
            return true;
        }

        state.started = true;
        state.finished = finished;
        state.last = name;
        state.lastMs = elapsed;
        state.totalMs += elapsed;
        if (state.total > 0) {
            state.done = state.total - remaining;
        }
        return true;
    }

    /**
    @brief asks how many datasets there are, without parsing any of them

    Also the one point where the player's setting is read. It is applied once, on the
    first frame that reaches Lua: the Timing page's checkbox may turn it off or on
    afterwards, and a setting read every frame would fight it.
    */
    void readTotal() {
        if (!Gui::Lua::beginTableCall(STATE)) {
            return;
        }
        if (Gui::Lua::boolField("available")) {
            state.total = static_cast<int>(Gui::Lua::numberField("total"));
            state.finished = Gui::Lua::boolField("done");
            state.enabled = Gui::Lua::boolField("enabled", true);
        }
        Gui::Lua::endCall();
    }
}

const Gui::WarmupState& Gui::warmupState() {
    return state;
}

void Gui::warmupStep() {
    if (!state.enabled || state.finished) {
        return;
    }

    const ULONGLONG now = GetTickCount64();
    if (firstFrameMs == 0) {
        firstFrameMs = now;
    }
    if (now - firstFrameMs < QUIET_MS) {
        return;
    }

    if (!Gui::Lua::available()) {
        return; // not on a frame where Lua can be reached; try the next one
    }

    if (state.total == 0) {
        readTotal();
        return; // one call per frame, so the count never shares a frame with a parse
    }

    step();
}

void Gui::warmupNow() {
    if (state.finished) {
        return;
    }
    if (state.total == 0) {
        readTotal();
    }

    // Bounded rather than "until done": a step that cannot run reports finished, but a
    // bound means a bug here can never lock the game up.
    for (int guard = 0; guard < 32 && !state.finished; guard++) {
        if (!step()) {
            return;
        }
    }
}
