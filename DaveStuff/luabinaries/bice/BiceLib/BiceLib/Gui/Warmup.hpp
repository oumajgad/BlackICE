#pragma once

#include <string>

/**
 * Parses the pages' data before a page is opened and has to wait for it.
 *
 * Providers parse lazily, so the first page looked at pays for whatever it needs -
 * seconds of it, for the ones reading unit models, leaders, units or technologies. The
 * work has to happen somewhere; doing it while the game sits at the menu means nobody
 * is watching a frozen overlay when it does.
 *
 * One dataset per frame, driven from the Present hook rather than from drawAll, so it
 * runs whether or not the overlay is being shown.
 */
namespace Gui {
    struct WarmupState
    {
        bool enabled = true;
        bool finished = false;
        bool started = false;
        int done = 0;
        int total = 0;
        std::string last;   // the dataset parsed most recently
        double lastMs = 0.0;
        double totalMs = 0.0;
    };

    /**@brief parses at most one dataset; call once per frame*/
    void warmupStep();

    const WarmupState& warmupState();

    /**@brief parses everything still outstanding, in one go*/
    void warmupNow();
}
