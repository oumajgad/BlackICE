#pragma once

/**
 * Stands in `CInGameIdler::Update` so queued messages are raised where the game raises
 * its own.
 *
 * **Why a message cannot simply be raised where it is wanted.** One raised from inside the
 * overlay's `Present` hook - the utility's GUI, its Lua console, anything drawn - is built
 * correctly and posts without complaint, and comes up as an **empty window**. One raised
 * from a game tick comes up right. That was measured three ways, and Lua turned out to
 * have nothing to do with it; see reversing/findings/FINDINGS-messages.md.
 *
 * There is a second trap. `CCountry::BuildMessageVariables` does not allocate its list, it
 * clears and refills the **country's own** at `+0x24`, and the message constructor
 * releases it. So a raise nested inside another raise for the same country frees the outer
 * one's variables - which crashed the game when tried from inside
 * `CCountry::ShatterUnit`.
 *
 * Both go away if nothing raises a message directly. `Game::Message::queue` copies what it
 * needs, and this raises the lot once a frame from the idler's own update: out of
 * `Present`, and never inside another raise.
 *
 * **Per frame rather than per day** deliberately, so a message queued while the game is
 * paused still appears - the idler updates whether the clock runs or not.
 */
namespace Hooks {
    namespace MessageQueue {
        /**
        @brief patches CInGameIdler::Update to flush the queue each frame

        Installed by Game::Message::queue the first time anything is queued, so a session
        that raises nothing pays nothing. Safe to call again.
        */
        bool install();

        /**@brief whether the patch is in*/
        bool installed();

        /**@brief what happened, for a caller that wants to say so*/
        const char* status();
    }
}
