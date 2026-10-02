#include <GameState/GameClock.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <utils.hpp>

namespace {
    // Forward steps of under a day seen in a row before a frame counts as in play.
    const int STEPS_FOR_PROOF = 2;

    int currentTick = 0;
    int steadySteps = 0;
    bool moved = false;
    int sessionCount = 0;
}

void GameClock::update() {
    const int tick = CCurrentGameState::currentTick();
    const int previous = currentTick;
    currentTick = tick;
    moved = false;

    const int step = tick - previous;
    if (step == 0) {
        return;
    }

    // Moving forward by less than a day is play; jumping or going back is a load, or a
    // new game, and starts the count again.
    if (tick == 0 || previous == 0 || step < 0 || step >= TICKS_PER_DAY) {
        steadySteps = 0;
        sessionCount++;
        INFO_OUT(printf("GameClock: jumped from tick %d to %d - session %d, not in play "
            "until it has moved %d more times\n", previous, tick, sessionCount,
            STEPS_FOR_PROOF));
        return;
    }
    if (steadySteps < STEPS_FOR_PROOF) {
        steadySteps++;
        if (steadySteps == STEPS_FOR_PROOF) {
            INFO_OUT(printf("GameClock: in play from tick %d (day %d, hour %d)\n",
                tick, tick / TICKS_PER_DAY, tick % TICKS_PER_DAY));
        }
    }
    // The steady-step count answers "is the clock running normally", which is what the
    // once-a-day callers need. The game's own in_game byte answers "is a game on screen",
    // which the count could only ever infer. Both, because neither covers the other.
    //
    // in_game is NOT set during a load - that was the reason given here until 2026-10-02 and
    // it was wrong (reversing/FINDINGS-session.md). The byte has six writers in the whole
    // image and only one writes a one, in CInGameIdler::Enter; the savegame loader contains
    // none of them, and it can only be reached from the pre-game lobby or the tutorial
    // screen, neither of which is the in-game screen.
    //
    // The window this guard really excludes is narrower. That single write sits 0x4A92 bytes
    // from the end of CInGameIdler::Enter, and everything after it builds the in-game
    // interface - so there is a stretch where in_game is 1, the session exists, and the GUI
    // does not. The clock cannot have stepped there either, because AdvanceClock is only
    // reached from CInGameIdler::Update, which has not run yet. Hence both halves.
    // The clock alone also cannot tell a paused game from the menu.
    moved = steadySteps >= STEPS_FOR_PROOF && CCurrentGameState::inGame();
}

bool GameClock::movedInPlay() {
    return moved;
}

int GameClock::tick() {
    return currentTick;
}

int GameClock::day() {
    return currentTick / TICKS_PER_DAY;
}

int GameClock::hour() {
    return currentTick % TICKS_PER_DAY;
}

int GameClock::session() {
    return sessionCount;
}
