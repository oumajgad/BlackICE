#include <GameState/Periodics.hpp>
#include <GameState/GameClock.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <Gui/LuaBridge.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <string>

// Needs DWORD and std::string before it, and has no include guard of its own.
#include <Hooks/CArmyHooks.hpp>

namespace {
    const char* DAILY_PERIODICS = "BiceLibDailyPeriodics";

    // After the host's own scheduled scripts, which run at one o'clock.
    const int RUN_FROM_HOUR = 1;

    int ranDay = -1;
    int ranSession = -1;

    // What update() has done, for the session in ranSession.
    Periodics::Status current;

    /**@brief notes the HQ unit limits BiceLib now holds for the country being played*/
    void notePlayerLimits() {
        current.limitsKnown = false;

        const uintptr_t state = CCurrentGameState::current();
        if (state == 0) {
            return;
        }
        current.playerTag = HDS::readTag(state + CCurrentGameState::Offsets::player_tag);
        const uintptr_t country = CCountry::findByTag(current.playerTag);
        int32_t id = -1;
        if (country == 0 || !Mem::tryRead(country + CCountry::Offsets::id, id)
            || id < 0 || id >= 300) {
            INFO_OUT(printf("Periodics: no country found for the player tag '%s'\n",
                current.playerTag.c_str()));
            return;
        }
        current.limitsKnown = true;
        current.corpsLimit = Hooks::CArmy::corpsUnitLimitPerCountry[id];
        current.armyLimit = Hooks::CArmy::armyUnitLimitPerCountry[id];
        current.armyGroupLimit = Hooks::CArmy::armyGroupUnitLimitPerCountry[id];
        INFO_OUT(printf("Periodics: %s (id %d) now has corps %d, army %d, army group %d\n",
            current.playerTag.c_str(), id, current.corpsLimit, current.armyLimit,
            current.armyGroupLimit));
    }
}

void Periodics::update() {
    if (!GameClock::movedInPlay()) {
        return;
    }

    const int day = GameClock::day();
    if (day == ranDay || GameClock::hour() < RUN_FROM_HOUR) {
        return;
    }
    INFO_OUT(printf("Periodics: day %d due at tick %d (hour %d)\n", day, GameClock::tick(),
        GameClock::hour()));

    // Busy, or not the render thread: the next frame the clock moves tries again. A
    // call that is made counts for the day even if the script fails - the bridge logs
    // the error, and once a day is enough to read it.
    if (!Gui::Lua::available()) {
        INFO_OUT(printf("Periodics: Lua not available (%s), trying again next hour\n",
            Gui::Lua::unavailableReason()));
        return;
    }

    // The first day after a load sets everything up at once rather than waiting for
    // the days the scripts would otherwise pick: what this game was set up with
    // before belongs to whatever was loaded before.
    const bool firstDay = GameClock::session() != ranSession;
    if (firstDay) {
        current = Status();
    }
    ranDay = day;
    ranSession = GameClock::session();
    current.lastRunTick = GameClock::tick();

    INFO_OUT(printf("Periodics: calling %s(%d)\n", DAILY_PERIODICS, firstDay ? 1 : 0));
    if (!Gui::Lua::beginTableCallWithNumber(DAILY_PERIODICS, firstDay ? 1.0 : 0.0)) {
        current.lastRunOk = false;
        current.lastError = Gui::Lua::unavailableReason();
        INFO_OUT(printf("Periodics: the call failed: %s\n", current.lastError.c_str()));
        return;
    }
    const bool limitsChecked = Gui::Lua::boolField("oob_limits_checked");
    INFO_OUT(printf("Periodics: Lua says BiceLib loaded %s, first day %s, day of month %d, "
        "OOB unit limits checked %s\n",
        Gui::Lua::boolField("bicelib_loaded") ? "yes" : "no",
        Gui::Lua::boolField("first_day") ? "yes" : "no",
        static_cast<int>(Gui::Lua::numberField("day_of_month", -1)),
        limitsChecked ? "yes" : "no"));
    Gui::Lua::endCall();

    current.lastRunOk = true;
    current.lastError.clear();
    if (limitsChecked) {
        current.limitsCheckedTick = current.lastRunTick;
    }
    notePlayerLimits();
}

Periodics::Status Periodics::status() {
    // Kept until the first call after a load replaces it, so a load has to be noticed
    // here too, or the page would show the last game's runs until the next one.
    if (ranSession != GameClock::session()) {
        return Status();
    }
    return current;
}
