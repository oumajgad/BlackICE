#pragma once

#include <cstdint>

/**
 * How many GUI widgets the game is holding, sampled over time.
 *
 * **Why this exists.** Every live widget in the process sits in one flat
 * `std::vector<CGuiObject*>` at `CGui +0x5C`, and on 2026-10-02 that vector was measured
 * growing permanently: **every open-and-close of a full-screen window leaks 30 widgets** -
 * ten each of `outliner_header`, `outliner_header_entry` and `entry_text` - because the
 * outliner's header widgets are not destroyed on hide and a fresh set is created on each
 * rebuild. Message popups, by contrast, tear down perfectly, so it is one broken path rather
 * than a broken mechanism. The capacity is 64,000 slots against about 4,300 in use in a
 * mid-game save, so it will not exhaust in an afternoon - but nobody has watched a long
 * game, and that is the question this answers.
 *
 * It matters beyond tidiness: a name lookup over this vector is how the DLL reads numbers the
 * UI has already computed, and duplicates make "the widget called X" ambiguous - the top bar
 * already has two `ic_number` widgets, one of which holds placeholder text. More copies make
 * that worse.
 *
 * **Cost.** The repeating sample is **three dword reads** - begin, end and capacity - so it is
 * safe on a timer. Counting nulls, distinct names and the three leaking names means walking
 * every widget and reading a string per widget, so that is a separate call behind a button and
 * must not be put on the timer.
 *
 * All of this is specific to this build of `hoi3_tfh.exe`.
 */
namespace Gui {
    namespace WidgetStats {
        struct Sample {
            bool valid = false;        ///< false when the gui object could not be resolved
            uint32_t inUse = 0;        ///< (end - begin) / 4
            uint32_t capacity = 0;     ///< (capacityEnd - begin) / 4
            uintptr_t begin = 0;       ///< the buffer itself; a change means it reallocated
        };

        /**
        @brief the cheap sample: three dword reads, safe to call on a timer

        Resolving the gui object the first time walks the process's committed private regions
        looking for its vftable, which is not cheap; every call after that validates the cached
        pointer with one read and re-resolves only if it has gone stale. So the first call from
        a page being opened may hitch, and no later one will.
        */
        Sample sample();

        /**@brief record a sample in the history ring. Call once per timer tick, not per frame*/
        void note(const Sample& taken);

        uint32_t peak();            ///< the highest inUse seen since the baseline
        uint32_t baseline();        ///< inUse when the baseline was last set
        bool reallocated();         ///< whether `begin` has ever moved since the baseline

        /**@brief forget the history and take the current count as the new baseline*/
        void resetBaseline();

        int historyCount();
        uint32_t historyAt(int index);   ///< oldest first, for a plot
        int historyCapacity();

        /**
         * The expensive walk, for a button rather than a timer.
         *
         * Reads every widget's `CGuiType*` and that type's name, so it costs one pointer chase
         * and one string read per widget - several thousand of each.
         */
        struct DeepScan {
            bool valid = false;
            uint32_t walked = 0;
            uint32_t nulls = 0;            ///< null slots; erase-and-compact leaves none
            uint32_t distinctNames = 0;
            uint32_t outlinerHeader = 0;        ///< the three names known to leak, ten per cycle
            uint32_t outlinerHeaderEntry = 0;
            uint32_t entryText = 0;
        };
        DeepScan deepScan();
    }
}
