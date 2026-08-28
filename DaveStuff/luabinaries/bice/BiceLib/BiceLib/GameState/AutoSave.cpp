#include <GameState/AutoSave.hpp>

#include <Hooks/AutoSaveHooks.hpp>
#include <MemScan.hpp>
#include <Settings.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>

namespace {
    const char* ENABLED_KEY = "autoSave.enabled";
    const char* DAYS_KEY = "autoSave.daysBeforeMonthEnd";
    const char* SUFFIX_KEY = "autoSave.suffix";
    const char* DEFAULT_SUFFIX = "premonth";

    // Where the request flag sits on the CInGameIdler, and the epoch every tick
    // counts hours from. Both are in reversing/FINDINGS-autosave.md.
    const uintptr_t IDLER_AUTOSAVE_REQUESTED = 0xAB0;
    const int TICK_EPOCH = 43800000;

    // For the example name only. The tag the game puts in a save name is the three
    // characters at the head of the player's tag, on the game state.
    const uintptr_t GAME_STATE_POINTER = 0x1689790;
    const uintptr_t GAME_STATE_TICK = 0xBDC;
    const uintptr_t GAME_STATE_TAG = 0xC30;

    bool loaded = false;
    bool enabledFlag = false;
    int daysBeforeValue = AutoSave::DEFAULT_DAYS_BEFORE;
    std::string suffixValue = DEFAULT_SUFFIX;

    // The decision runs on more than one of the game's timers, so it can be asked the
    // same question twice on the same day. This is what keeps that from becoming two
    // saves.
    int lastRequestedDay = -1;

    std::string lastRequestedText;
    int requestedCountValue = 0;

    int clampDays(int days) {
        if (days < AutoSave::MIN_DAYS_BEFORE) {
            return AutoSave::MIN_DAYS_BEFORE;
        }
        if (days > AutoSave::MAX_DAYS_BEFORE) {
            return AutoSave::MAX_DAYS_BEFORE;
        }
        return days;
    }

    /**@brief reads the settings file, once*/
    void load() {
        if (loaded) {
            return;
        }
        loaded = true;

        enabledFlag = Settings::getInt(ENABLED_KEY, 0) != 0;
        daysBeforeValue = clampDays(Settings::getInt(DAYS_KEY, AutoSave::DEFAULT_DAYS_BEFORE));
        suffixValue = Settings::getString(SUFFIX_KEY, DEFAULT_SUFFIX);

        // The hooks are only installed once something asks for them, but the name has
        // to be right before the first save rather than after it.
        Hooks::AutoSave::setNameSuffix(suffixValue.c_str());
        if (enabledFlag) {
            Hooks::AutoSave::install();
            Hooks::AutoSave::setActive(Hooks::AutoSave::installed());
        }
    }

    /**@brief the player's tag, or a placeholder when there is no session to read*/
    std::string playerTag() {
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        uint32_t state = 0;
        if (base == 0 || !Mem::tryRead(base + GAME_STATE_POINTER, state) || state == 0) {
            return "TAG";
        }

        // Three characters and a terminator, which is how a tag is held everywhere.
        char tag[4] = {};
        if (!Mem::tryReadBytes(state + GAME_STATE_TAG, tag, 3)) {
            return "TAG";
        }
        for (int i = 0; i < 3; i++) {
            if (tag[i] < 'A' || tag[i] > 'Z') {
                return "TAG";
            }
        }
        return std::string(tag);
    }

    /**@brief the current tick, or 0 when there is no session*/
    int currentTick() {
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        uint32_t state = 0;
        if (base == 0 || !Mem::tryRead(base + GAME_STATE_POINTER, state) || state == 0) {
            return 0;
        }
        int32_t tick = 0;
        if (!Mem::tryRead(state + GAME_STATE_TICK, tick)) {
            return 0;
        }
        return tick;
    }
}

void AutoSave::restore() {
    load();
}

bool AutoSave::enabled() {
    load();
    return enabledFlag;
}

void AutoSave::setEnabled(bool on) {
    load();
    enabledFlag = on;
    Settings::setInt(ENABLED_KEY, on ? 1 : 0);

    if (on) {
        Hooks::AutoSave::install();
    }
    // Never active without the patch in place, so a failed install leaves the game
    // deciding on its own rather than half hooked.
    Hooks::AutoSave::setActive(on && Hooks::AutoSave::installed());
}

int AutoSave::daysBefore() {
    load();
    return daysBeforeValue;
}

void AutoSave::setDaysBefore(int days) {
    load();
    daysBeforeValue = clampDays(days);
    Settings::setInt(DAYS_KEY, daysBeforeValue);

    // The day has moved, so a request already made for this month should not stop a
    // request on the new day.
    lastRequestedDay = -1;
}

const std::string& AutoSave::suffix() {
    load();
    return suffixValue;
}

void AutoSave::setSuffix(const std::string& text) {
    load();
    suffixValue = text;
    Settings::setString(SUFFIX_KEY, suffixValue);
    Hooks::AutoSave::setNameSuffix(suffixValue.c_str());
}

bool AutoSave::isSaveDay(int tick) {
    const utils::GameDate date = utils::gameTickToParts(tick);

    // Counting back from the 1st of the next month: one day before it is the last day
    // of this one, two days before it is the day before that. Every month is measured
    // from its own end, so February lands as early as its length demands.
    return date.dayOfMonth == date.daysInMonth - daysBeforeValue + 1;
}

void AutoSave::onDecision(uintptr_t idler, int tick) {
    load();

    // The game has just cleared its own request flag, which cancels any save asked
    // for and not yet written. A claim on the name has to be given up with it - and
    // if there was one, the save it belonged to never happened, so today is allowed
    // to ask again.
    if (Hooks::AutoSave::releaseClaim()) {
        lastRequestedDay = -1;
    }

    if (!enabledFlag || idler == 0) {
        return;
    }

    const int day = (tick - TICK_EPOCH) / 24;
    if (day == lastRequestedDay) {
        return;
    }
    if (!isSaveDay(tick)) {
        return;
    }
    lastRequestedDay = day;

    // Written directly rather than through a checked read: this is the same address
    // the instruction the hook replaced has just written to, so it was valid a few
    // instructions ago or the game would already have faulted.
    *reinterpret_cast<unsigned char*>(idler + IDLER_AUTOSAVE_REQUESTED) = 1;
    Hooks::AutoSave::claimNextSave();

    lastRequestedText = utils::gameTickToDate(tick);
    requestedCountValue += 1;
    INFO_OUT(printf("AutoSave: asked for a save on %s\n", lastRequestedText.c_str()));
}

const std::string& AutoSave::lastRequested() {
    return lastRequestedText;
}

int AutoSave::requestedCount() {
    return requestedCountValue;
}

std::string AutoSave::exampleName() {
    load();

    // The date of the next save this would ask for, so the example is the name that
    // is actually coming rather than today's.
    const int tick = currentTick();
    utils::GameDate date = utils::gameTickToParts(tick == 0 ? TICK_EPOCH : tick);
    date.dayOfMonth = date.daysInMonth - daysBeforeValue + 1;

    char text[128] = {};
    snprintf(text, sizeof(text), "%s_%d_%02d_%02d_%02d%s%s.hoi3",
        playerTag().c_str(), date.year, date.month, date.dayOfMonth, date.hourOfDay,
        suffixValue.empty() ? "" : "_", suffixValue.c_str());
    return std::string(text);
}

bool AutoSave::hooked() {
    return Hooks::AutoSave::installed();
}

const char* AutoSave::status() {
    return Hooks::AutoSave::status();
}
