#pragma once

/**
 * **Prints the arguments of every message the game posts**, so one raised by hand can be
 * compared against one the game raised itself.
 *
 * `PostMessage` takes five arguments and the middle one is a `0x78` byte object by value,
 * which makes it the wrong thing to reason about from a disassembly alone: two separate
 * misreadings of that frame produced a crash and then an empty popup, and neither showed
 * which field was wrong. This prints the frame instead.
 *
 * The useful comparison is two frames from one session: let the game shatter a division,
 * then raise one through Game::Message, and diff what comes out. The return address on
 * each line says which is which - `0x100ED5` is CCountry::ShatterUnit's own call.
 *
 * Diagnostic only, and armed by hand: it stands in front of a function the game calls,
 * and nothing about it belongs in a normal session.
 */
namespace Reversing {
    namespace MessageProbe {
        /**@brief patches PostMessage so the next few posts print their arguments*/
        bool arm();

        /**@brief puts the five bytes back; safe to call when it was never armed*/
        void disarm();

        const char* status();

    }
}
