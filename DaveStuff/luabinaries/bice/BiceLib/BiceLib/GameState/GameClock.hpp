#pragma once

/**
 * The game clock as the Present hook sees it, and the proof that a game is running.
 *
 * Present runs from the first frame of the main menu, where the game's own objects must
 * not be touched, and the game state object already exists there, so its pointer proves
 * nothing. The clock does: at the menu it stands still, and across a load or a new game
 * it jumps. So a frame counts as in play only when the clock has just moved forward by
 * less than a day, having done so at least once before since the last jump.
 *
 * The overlay calls update() once a frame, before anything that asks.
 */
namespace GameClock {
    constexpr int TICKS_PER_DAY = 24;   // a tick is an hour

    /**@brief reads the clock; once a frame, from the Present hook*/
    void update();

    /**
    @brief whether the clock moved this frame, in play

    True on exactly the frames where the game API may be used from Present. Never true
    at the menu or while paused, where the clock stands still, and not for the first
    step after a jump.
    */
    bool movedInPlay();

    /**@brief the tick read this frame, 0 without a game state*/
    int tick();

    int day();
    int hour();

    /**
    @brief a number that changes whenever the clock jumps

    A load or a new game makes the clock jump, so a caller that keeps the value it last
    saw can tell the first day of a session from the rest.
    */
    int session();
}
