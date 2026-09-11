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
    moved = steadySteps >= STEPS_FOR_PROOF;
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
