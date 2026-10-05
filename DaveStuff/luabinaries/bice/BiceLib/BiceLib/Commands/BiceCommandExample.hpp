#pragma once
#include <cstdint>

/**
 * The worked example of `CBiceCommands`: a "ping" command, and what adding one looks like.
 *
 * This **is** the MVP that was tested in single player and multiplayer on 2026-10-05. It used
 * to be a `CCommand` subclass of its own, spending a whole save token to carry nothing. Now it
 * is a kind number and a handler, it carries arguments, and it cost no token at all - which is
 * the entire point of the framework and the reason this file is short.
 *
 * ## Everything it takes to add a command
 *
 * 1. a kind number, from the list in `Kinds` below - ours, not the game's
 * 2. a handler, which must read **only** its arguments
 * 3. one `registerKind` call at load
 * 4. something that posts it
 *
 * No reversing, no vftable, no save token, no serialisation. Compare `CBiceCommands.hpp`'s
 * header comment for what that is standing on.
 *
 * ## The one rule a handler must obey
 *
 * **A handler runs on every machine in the game**, inside the session's ordered command pump,
 * so it must do the same thing everywhere. Everything it needs has to arrive in its
 * arguments. Reading the pressed key, `CInGameIdler`'s selection or `played_country_id`
 * *inside* a handler makes it do something different on each peer, which is a desync and no
 * test inside the handler can repair it.
 *
 * The division is: **a local input may choose which command to post; it may never change what
 * a command does when it runs.** So read the keyboard in the GUI handler that only the
 * clicking player runs, and post a command that names its own targets. BiceLib's Ctrl-unassign
 * feature is the worked example of getting that wrong first and then right -
 * `BiceLib/Hooks/UnassignSelected.hpp` and point 5 of
 * `reversing/findings/FINDINGS-commands.md`.
 *
 * ## What ping proves
 *
 * In single player the object that runs is the factory's clone of the registered prototype -
 * not the object that was posted - so an `Execute` line at all means the type id, the
 * prototype, the serialiser, the tokenizer, the factory and the clone are all correct. With
 * arguments it proves the payload survives that round trip too.
 *
 * In multiplayer, every peer should log the **same** line for the same post: the handler reads
 * nothing but its arguments, so two machines' logs agreeing line for line is the test.
 */
namespace BiceCommandExample {

    /**
     * Kind numbers are **ours**, in our own space, and cost nothing - there is no token and
     * no registry behind them. Allocate them here, in one list, so two features cannot pick
     * the same number.
     *
     * **The number is what travels**, so it has to mean the same thing in every build playing
     * together: renumbering an existing kind breaks multiplayer against an older DLL, while
     * adding a new one at the end is safe. Treat this list as append-only.
     */
    namespace Kinds {
        /**@brief the example: logs whatever it was given. Args: any, echoed*/
        constexpr uint16_t Ping = 1;
    }

    /**
    @brief register the example's kind with the framework

    Separate from `CBiceCommands::Register`, which puts the one prototype in the game's
    registry. This is the half a feature owns: the framework knows nothing about kinds until
    something declares one.

    @return whether the kind is registered
    */
    bool install();

    /**
    @brief post one ping carrying \p count arguments

    @param args may be null when \p count is 0
    @param count 0 to `CBiceCommands::MAX_ARGS`
    @return whether it was posted
    */
    bool post(const int32_t* args, int count);
}
