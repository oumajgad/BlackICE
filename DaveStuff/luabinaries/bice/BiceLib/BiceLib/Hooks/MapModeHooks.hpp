#pragma once

/**
 * Takes over the colour the VP map mode gives each province.
 *
 * The game's colouring loop finishes by turning a CColor into a packed 0xAARRGGBB and
 * storing it on the province. That conversion is a five byte call, so it can be
 * replaced with a call of our own: we hand back either a colour of our own or,
 * whenever the building map mode is off, exactly what the game would have produced.
 *
 * Nothing is written to the game's data, so the VP map mode behaves normally the
 * moment the mode is switched off. The hook stays installed once put in - patching
 * code repeatedly while the game runs is the riskier of the two.
 *
 * The addresses and why this is the right place are in reversing/FINDINGS-mapmode.md.
 */
namespace Hooks {
    namespace MapMode {
        /**@brief patches the call, once; safe to call again*/
        bool install();

        /**
        @brief whether the hooks do anything at all

        While this is false both stubs behave exactly as the instructions they
        replaced, in assembly, without calling into any of our code. That is what
        makes turning the mode off give the game back unchanged rather than merely
        nearly unchanged.
        */
        void setActive(bool on);

        /**
        @brief makes the game colour the map again, now

        Calls the routine the game runs when the VP map mode is picked, so a change of
        building shows up without the player switching map mode by hand. Does nothing
        unless the VP map mode is the one on screen - repainting any other would be
        meddling with a mode we have nothing to do with.

        @returns whether it found everything it needed and made the call
        */
        bool repaint();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
