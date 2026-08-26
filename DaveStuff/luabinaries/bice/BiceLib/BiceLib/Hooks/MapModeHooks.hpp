#pragma once

/**
 * Takes over the colour the VP map mode gives each province.
 *
 * The game's colouring loop finishes by turning a CColor into a packed 0xAARRGGBB and
 * storing it on the province. That conversion is a five byte call, so a call to this
 * hook fits exactly in its place. The hook answers with a replacement colour while the
 * building map mode is on, and with what the game itself would have produced while it
 * is off.
 *
 * Nothing is written to the game's data, so the VP map mode behaves normally the
 * moment the mode is switched off. The patch is written once and left in place:
 * repeatedly patching code in a running process carries more risk than leaving an
 * inert hook installed.
 *
 * The addresses and why this is the right place are in reversing/FINDINGS-mapmode.md.
 */
namespace Hooks {
    namespace MapMode {
        /**@brief patches the call, once; safe to call again*/
        bool install();

        /**
        @brief whether the hooks do anything at all

        While this is false both stubs reproduce, in assembly, exactly the
        instructions they replaced, without calling into BiceLib at all. Switching the
        mode off therefore restores the game's own behaviour completely rather than
        approximately.
        */
        void setActive(bool on);

        /**
        @brief makes the game colour the map again, now

        Calls the routine the game runs when the VP map mode is picked, so a change of
        building shows up without the player switching map mode by hand. Does nothing
        unless the VP map mode is the one on screen; no other map mode is BiceLib's to
        repaint.

        @returns whether it found everything it needed and made the call
        */
        bool repaint();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
