#include <GameState/AutoSave.hpp>
#include <GameClasses/CInGameIdler.hpp>

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

    const char* TIMED_ENABLED_KEY = "autoSave.timed.enabled";
    const char* TIMED_MINUTES_KEY = "autoSave.timed.minutes";
    const char* TIMED_NAME_KEY = "autoSave.timed.saveName";
    const char* DEFAULT_TIMED_SAVE_NAME = "autosave_timed";

    // The epoch every tick counts hours from. The offsets it is read against are
    // in GameClasses; this is the one number that is not a field.
    const int TICK_EPOCH = 43800000;

    bool loaded = false;
    bool enabledFlag = false;
    int daysBeforeValue = AutoSave::DEFAULT_DAYS_BEFORE;
    std::string saveNameValue = DEFAULT_SAVE_NAME;

    bool timedEnabledFlag = false;
    int minutesValue = AutoSave::DEFAULT_MINUTES;
    std::string timedSaveNameValue = DEFAULT_TIMED_SAVE_NAME;

    // The decision runs on more than one of the game's timers, so it can be asked the
    // same question twice on the same day. This is what keeps that from becoming two
    // saves.
    int lastRequestedDay = -1;

    // When the interval is being counted from, by the system clock. It is not running
    // until the first decision of a session reaches it, because a clock started while
    // the game is at the main menu would be most of the way through by the time
    // anything is worth saving.
    bool timerRunning = false;
    ULONGLONG timerStartedAt = 0;

    // Where the timer was before the save that is currently claimed. A claim that is
    // dropped is a save that never happened, so the clock has to go back to where it
    // was rather than count the interval from a file that was never written.
    ULONGLONG timerBeforeClaim = 0;

    std::string lastRequestedText;
    int requestedCountValue = 0;
    std::string lastTimedRequestedText;
    int timedRequestedCountValue = 0;

    int clampDays(int days) {
        if (days < AutoSave::MIN_DAYS_BEFORE) {
            return AutoSave::MIN_DAYS_BEFORE;
        }
        if (days > AutoSave::MAX_DAYS_BEFORE) {
            return AutoSave::MAX_DAYS_BEFORE;
        }
        return days;
    }

    int clampMinutes(int value) {
        if (value < AutoSave::MIN_MINUTES) {
            return AutoSave::MIN_MINUTES;
        }
        if (value > AutoSave::MAX_MINUTES) {
            return AutoSave::MAX_MINUTES;
        }
        return value;
    }

    /**
    @brief installs the hooks if anything needs them, and says whether they may act

    Never active without the patch in place, so a failed install leaves the game
    deciding on its own rather than half hooked.
    */
    void applyActive() {
        const bool wanted = enabledFlag || timedEnabledFlag;
        if (wanted) {
            Hooks::AutoSave::install();
        }
        Hooks::AutoSave::setActive(wanted && Hooks::AutoSave::installed());
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

        timedEnabledFlag = Settings::getInt(TIMED_ENABLED_KEY, 0) != 0;
        minutesValue = clampMinutes(Settings::getInt(TIMED_MINUTES_KEY, AutoSave::DEFAULT_MINUTES));
        timedSaveNameValue = Settings::getString(TIMED_NAME_KEY, DEFAULT_TIMED_SAVE_NAME);

        // The hooks are only installed once something asks for them, but the names
        // have to be right before the first save rather than after it.
        Hooks::AutoSave::setSaveName(Hooks::AutoSave::Kind::Monthly, saveNameValue.c_str());
        Hooks::AutoSave::setSaveName(Hooks::AutoSave::Kind::Timed, timedSaveNameValue.c_str());
        applyActive();
    }

    /**
    @brief raises the game's own request flag and puts our name on what it writes

    The flag is written directly rather than through a checked read: this is the same
    address the instruction the hook replaced has just written to, so it was valid a
    few instructions ago or the game would already have faulted.
    */
    void request(uintptr_t idler, int tick, Hooks::AutoSave::Kind kind) {
        *reinterpret_cast<unsigned char*>(idler + CInGameIdler::Offsets::autosave_requested) = 1;
        Hooks::AutoSave::claimNextSave(kind);

        // A save is a save, whichever asked for it: the timer is promising that no
        // more than its interval of play goes unsaved, and this meets that promise.
        timerBeforeClaim = timerStartedAt;
        timerStartedAt = GetTickCount64();
        timerRunning = true;

        const std::string date = utils::gameTickToDate(tick);
        if (kind == Hooks::AutoSave::Kind::Monthly) {
            lastRequestedText = date;
            requestedCountValue += 1;
        }
        else {
            lastTimedRequestedText = date;
            timedRequestedCountValue += 1;
        }
        INFO_OUT(printf("AutoSave: asked for a %s save on %s\n",
            kind == Hooks::AutoSave::Kind::Monthly ? "pre-month" : "timed", date.c_str()));
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
    applyActive();
}

bool AutoSave::timedEnabled() {
    load();
    return timedEnabledFlag;
}

void AutoSave::setTimedEnabled(bool on) {
    load();
    timedEnabledFlag = on;
    Settings::setInt(TIMED_ENABLED_KEY, on ? 1 : 0);

    // Switched on, the first interval is counted from now rather than from whenever
    // the last session left the clock; switched off, nothing is being counted.
    timerRunning = false;
    applyActive();
}

int AutoSave::minutes() {
    load();
    return minutesValue;
}

void AutoSave::setMinutes(int value) {
    load();
    minutesValue = clampMinutes(value);
    Settings::setInt(TIMED_MINUTES_KEY, minutesValue);

    // The interval is measured from the last save, so a shorter one can be due
    // already and a longer one can put the next save off. Both are what was asked
    // for; nothing is reset here.
}

int AutoSave::secondsUntilDue() {
    load();
    if (!timedEnabledFlag || !timerRunning) {
        return -1;
    }
    const ULONGLONG due = timerStartedAt + static_cast<ULONGLONG>(minutesValue) * 60000ull;
    const ULONGLONG now = GetTickCount64();
    if (now >= due) {
        return 0;
    }
    return static_cast<int>((due - now + 999) / 1000);
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
    Hooks::AutoSave::setSaveName(Hooks::AutoSave::Kind::Monthly, saveNameValue.c_str());
}

const std::string& AutoSave::timedSaveName() {
    load();
    return timedSaveNameValue;
}

void AutoSave::setTimedSaveName(const std::string& text) {
    load();
    timedSaveNameValue = text;
    Settings::setString(TIMED_NAME_KEY, timedSaveNameValue);
    Hooks::AutoSave::setSaveName(Hooks::AutoSave::Kind::Timed, timedSaveNameValue.c_str());
}

std::string AutoSave::fileName(int slot) {
    load();
    return std::string(Hooks::AutoSave::saveName(Hooks::AutoSave::Kind::Monthly, slot));
}

std::string AutoSave::timedFileName(int slot) {
    load();
    return std::string(Hooks::AutoSave::saveName(Hooks::AutoSave::Kind::Timed, slot));
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
    // if there was one, the save it belonged to never happened, so the day is allowed
    // to ask again and the timer goes back to where it was before the claim.
    const int dropped = Hooks::AutoSave::releaseClaim();
    if (dropped >= 0) {
        timerStartedAt = timerBeforeClaim;
        if (dropped == static_cast<int>(Hooks::AutoSave::Kind::Monthly)) {
            lastRequestedDay = -1;
        }
    }

    if (idler == 0) {
        return;
    }

    const int day = (tick - TICK_EPOCH) / 24;
    if (enabledFlag && day != lastRequestedDay && isSaveDay(tick)) {
        lastRequestedDay = day;
        request(idler, tick, Hooks::AutoSave::Kind::Monthly);
        return;     // one request flag, so one save; the timer has been restarted
    }

    if (!timedEnabledFlag) {
        return;
    }
    if (!timerRunning) {
        // The first decision of a session: the interval is counted from a game that
        // is actually being played, not from whenever the DLL was loaded.
        timerRunning = true;
        timerStartedAt = GetTickCount64();
        return;
    }
    if (GetTickCount64() - timerStartedAt < static_cast<ULONGLONG>(minutesValue) * 60000ull) {
        return;
    }
    request(idler, tick, Hooks::AutoSave::Kind::Timed);
}

const std::string& AutoSave::lastRequested() {
    return lastRequestedText;
}

int AutoSave::requestedCount() {
    return requestedCountValue;
}

const std::string& AutoSave::lastTimedRequested() {
    return lastTimedRequestedText;
}

int AutoSave::timedRequestedCount() {
    return timedRequestedCountValue;
}

bool AutoSave::hooked() {
    return Hooks::AutoSave::installed();
}

const char* AutoSave::status() {
    return Hooks::AutoSave::status();
}
