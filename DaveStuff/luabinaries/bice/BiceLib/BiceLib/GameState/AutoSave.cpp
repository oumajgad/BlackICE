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
    const char* SAVE_NAME_KEY = "autoSave.saveName";
    const char* LEGACY_SUFFIX_KEY = "autoSave.suffix";   // what the setting was called
    const char* DEFAULT_SAVE_NAME = "autosave_premonth";

    // Where the request flag sits on the CInGameIdler, and the epoch every tick
    // counts hours from. Both are in reversing/FINDINGS-autosave.md.
    const uintptr_t IDLER_AUTOSAVE_REQUESTED = 0xAB0;
    const int TICK_EPOCH = 43800000;

    bool loaded = false;
    bool enabledFlag = false;
    int daysBeforeValue = AutoSave::DEFAULT_DAYS_BEFORE;
    std::string saveNameValue = DEFAULT_SAVE_NAME;

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
        // The setting was called a suffix while the saves were named for their date;
        // the value means the same thing now, so an install that has one keeps it.
        const std::string legacy = Settings::getString(LEGACY_SUFFIX_KEY, DEFAULT_SAVE_NAME);
        saveNameValue = Settings::getString(SAVE_NAME_KEY, legacy.c_str());

        // The hooks are only installed once something asks for them, but the name has
        // to be right before the first save rather than after it.
        Hooks::AutoSave::setSaveName(saveNameValue.c_str());
        if (enabledFlag) {
            Hooks::AutoSave::install();
            Hooks::AutoSave::setActive(Hooks::AutoSave::installed());
        }
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

const std::string& AutoSave::saveName() {
    load();
    return saveNameValue;
}

void AutoSave::setSaveName(const std::string& text) {
    load();
    saveNameValue = text;
    Settings::setString(SAVE_NAME_KEY, saveNameValue);
    Hooks::AutoSave::setSaveName(saveNameValue.c_str());
}

std::string AutoSave::fileName(int slot) {
    load();
    return std::string(Hooks::AutoSave::saveName(slot));
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

bool AutoSave::hooked() {
    return Hooks::AutoSave::installed();
}

const char* AutoSave::status() {
    return Hooks::AutoSave::status();
}
