#pragma once

/**
 * Adds a rule to the game's autosave decision, and names what it produces.
 *
 * Two stubs, in two different functions, a frame apart:
 *
 * The first stands in for the instruction that clears the game's autosave request
 * flag, at the top of the decision. Standing there means the flag can be raised
 * without the game's own decision, which runs immediately afterwards, wiping it -
 * and the game's decision still runs, so its own schedule is untouched.
 *
 * The second stands in for the read of `debug_saves` inside the writer. Answering it
 * with a one for one save sends that save down the game's own dated name branch,
 * which is already written and already correct, instead of the three file rotation.
 * Two string constants in that branch are pointed at buffers here so the name can be
 * shaped without building a std::string in the game's frame.
 *
 * While inactive both stubs reproduce, in assembly, exactly the instruction they
 * replaced and call nothing in BiceLib.
 *
 * Addresses and the reasoning are in reversing/FINDINGS-autosave.md.
 */
namespace Hooks {
    namespace AutoSave {
        /**@brief patches the two sites, once; safe to call again*/
        bool install();

        /**
        @brief whether the decision stub does anything at all

        The name stub is not gated by this: it is gated by whether a save is pending,
        which only becomes true through the decision stub.
        */
        void setActive(bool on);

        /**
        @brief claims the naming of the next save the game writes

        Cleared by the writer as it reads it, so it names one save and not the next.
        */
        void claimNextSave();

        /**
        @brief gives up a claim that was never written, and says whether there was one

        The decision clears the game's request flag every time it runs, which cancels
        a save asked for but not yet written. The claim on the name has to go the same
        way or it lands on whichever save the game writes next, months later.
        */
        bool releaseClaim();

        /**
        @brief what goes between the date and the extension

        Stored as `_<text>.hoi3`, or `.hoi3` when the text is empty. Anything longer
        than the buffer is cut, so the name always ends in the extension.
        */
        void setNameSuffix(const char* text);

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
