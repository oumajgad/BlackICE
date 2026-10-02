#pragma once

#include <GameClasses/GameString.hpp>

#include <cstdint>
#include <string>
#include <vector>

/**
 * Raising one of the game's own message popups, with variables of our own.
 *
 * A message is what the player sees when a division shatters or a province is lost: a
 * window, a line in the log, a marker on the map, each switched on per type by
 * `interface/messagetypes.txt` and written in the localisation. **The type registry is
 * built from that file rather than compiled in** - it carries `LEADERDIED`, `SHIPSUNK`,
 * `MINISTER_DEATH` and `RETURN_EXILE_US`, none of which appears anywhere in the
 * executable - so a type the mod declares is a type this can raise.
 *
 * A name the registry does not hold is not a crash: the game logs
 * `Failed to find message type: <name>` and nothing appears.
 *
 * ## What it builds
 *
 * `CCountry::ShatterUnit` is the worked example this follows. Raising one takes four
 * game functions and two objects built by hand:
 *
 *     0x0D75F0  the country's standard variables, as a list to add to
 *     0x298E80  the message handler, a lazy singleton
 *     0x299480  the type, looked up by name
 *     0x29AA70  the message itself, twelve arguments, constructed into a 0x78 buffer
 *     0x110A50  posting it, which takes that buffer **by value**
 *
 * Each variable is a `0x44` byte node holding two `std::string`s - the key at `+0`, the
 * value at `+0x1C` - linked into a `{first, last, count}` list by `prev` at `+0x38` and
 * `next` at `+0x3C`. The game builds those inline; this reproduces it.
 *
 * ## Two things a caller has to know
 *
 * **The game only shows a message to the player.** `ShatterUnit` compares the country
 * against `CCurrentGameState`'s player tag and skips the whole block when they differ.
 * Nothing here does that for you: raise it for every country and every AI division lost
 * anywhere pops a window. `Message::forPlayer` is the test.
 *
 * **The nodes are given away.** The constructor takes the variable list and walks it,
 * releasing as it goes, so nothing here frees them and `raise` must not be called twice
 * on the same object.
 */
namespace Game {
    /**
    @brief the CCountry the player is running, or 0 where there is no game

    The country every message raised for the player wants, looked up the way the engine
    does: the player's id off CCurrentGameState, then the country database's array by that
    id.
    */
    [[nodiscard]] uintptr_t playerCountry();

    class Message
    {
    public:
        /**
        @param type a name from `interface/messagetypes.txt`, such as `BICE_UNITDESTROYED`
        */
        explicit Message(const char* type);

        /**
        @brief adds a `$KEY$` the message's localisation can use

        The key is written without the dollars - `with("UNIT", "3rd Infantry")` fills
        `$UNIT$`. Adding one the text never mentions is harmless.
        */
        Message& with(const char* key, const char* value);

        /**
        @brief raises it now, for \p country, pointed at \p province

        **Only from something the game drives**: a hook in a tick, an event effect, an AI
        handler. From anywhere else, and by preference everywhere, use queue().

        A message raised from inside the overlay's `Present` hook - the utility's GUI, its
        Lua console, anything drawn - is built correctly, posts without complaint, and
        comes up as **an empty window**. Measured three ways: blank from the console, right
        from `CInGameIdler::DailyUpdate`, and right from that same daily update *through
        Lua*, so it is `Present` that matters and Lua that does not. Nothing else about the
        two raises differs - the bytes, the type object, the handler, the province and
        every variable were printed side by side against one the game raised itself and
        matched. See reversing/findings/FINDINGS-messages.md.

        **And never while another message is part-built for the same country.**
        CCountry::BuildMessageVariables does not allocate its list, it clears and refills
        the country's own at `+0x24`, and the constructor releases it - so a raise nested
        inside another frees the outer one's variables. Tried from inside
        CCountry::ShatterUnit, it crashed the game mid-substitution of `$MONARCHTITLE$`.

        @param country whose message it is; its own variables are added first
        @param province what the message points at, and what its Goto button goes to
        @returns false where the game's own functions could not be found, in which case
                 nothing was built and nothing leaked
        */
        bool raise(uintptr_t country, uintptr_t province);

        /**
        @brief leaves it for the next frame to raise, which is safe from anywhere

        **The one to reach for.** Copies what the message needs and hands it to
        `CInGameIdler::Update`, so the raise happens where the game raises its own: out of
        `Present`, and never inside another raise. Both traps described on raise() are the
        caller's problem there and nobody's here - including for a hook in a tick, which
        may still be nested inside a raise it cannot see.

        The flush hook is installed the first time anything is queued, so a session that
        raises nothing pays nothing.

        @returns false where the queue is full or the hook could not be installed
        */
        bool queue(uintptr_t country, uintptr_t province);

        /**@brief whether this country is the one the player is running*/
        static bool forPlayer(uintptr_t country);

        /**@brief false where the addresses did not check out and nothing can be raised*/
        static bool available();

        /**@brief what happened, for a caller that wants to say so*/
        static const char* status();

        /**
        @brief raises everything queued, oldest first, and answers how many went out

        **Called from the per-frame hook and not otherwise.** It takes the whole queue
        before raising any of it, so a message queued by one being raised waits for the
        next frame instead of growing the list underfoot.
        */
        static int flushQueue();

        /**@brief how many are waiting; a frame with none costs this and nothing else*/
        static int queued();

    private:
        std::string type_;
        std::vector<std::pair<std::string, std::string> > variables_;
    };
}
