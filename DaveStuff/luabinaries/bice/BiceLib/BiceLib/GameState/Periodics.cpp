#include <GameState/Periodics.hpp>
#include <GameState/GameClock.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <Gui/LuaBridge.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>

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
        if (country == 0 || !Mem::tryRead(country + CCountry::Offsets::tag + CCountryTag::Offsets::id, id)
            || id < 0 || id >= 300) {
            return;
        }
        current.limitsKnown = true;
        current.corpsLimit = Hooks::CArmy::corpsUnitLimitPerCountry[id];
        current.armyLimit = Hooks::CArmy::armyUnitLimitPerCountry[id];
        current.armyGroupLimit = Hooks::CArmy::armyGroupUnitLimitPerCountry[id];
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

    // Busy, or not the render thread: the next frame the clock moves tries again. A
    // call that is made counts for the day even if the script fails - the bridge logs
    // the error, and once a day is enough to read it.
    if (!Gui::Lua::available()) {
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

    if (!Gui::Lua::beginTableCallWithNumber(DAILY_PERIODICS, firstDay ? 1.0 : 0.0)) {
        current.lastRunOk = false;
        current.lastError = Gui::Lua::unavailableReason();
        return;
    }
    const bool limitsChecked = Gui::Lua::boolField("oob_limits_checked");
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
