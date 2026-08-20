#include <Gui/CountrySelection.hpp>
#include <Gui/LuaBridge.hpp>

#include <Windows.h>

namespace {
    const char* CURRENT_TAG = "BiceLibGui.Setup.CurrentTag";

    std::string currentTag;
    std::string currentSource;
    std::string currentReason = "not read yet";
    ULONGLONG lastSampleMs = 0;
}

const std::string& Gui::Selection::tag() {
    return currentTag;
}

const std::string& Gui::Selection::source() {
    return currentSource;
}

const std::string& Gui::Selection::reason() {
    return currentReason;
}

void Gui::Selection::invalidate() {
    lastSampleMs = 0;
}

void Gui::Selection::refreshIfStale(int intervalMs) {
    const ULONGLONG now = GetTickCount64();
    if (lastSampleMs != 0 && now - lastSampleMs < static_cast<ULONGLONG>(intervalMs)) {
        return;
    }
    lastSampleMs = now;

    if (!Gui::Lua::beginTableCall(CURRENT_TAG)) {
        currentTag.clear();
        currentSource.clear();
        currentReason = Gui::Lua::unavailableReason();
        return;
    }

    if (Gui::Lua::boolField("available")) {
        currentTag = Gui::Lua::stringField("tag");
        currentSource = Gui::Lua::stringField("source");
        currentReason.clear();
    }
    else {
        currentTag.clear();
        currentSource.clear();
        currentReason = Gui::Lua::stringField("reason", "unknown");
    }

    Gui::Lua::endCall();
}
