#pragma once

#include <string>

/**
 * The country every page reports on.
 *
 * Which country that is lives in Lua (G_PlayerCountry, set on the Setup page, else
 * the actual player), so it needs one small Lua call. Polling it centrally rather
 * than per page means pages that read their data straight out of BiceLib never touch
 * Lua at all, and the tag stays current even while the Setup tab is hidden - ImGui
 * only calls draw() for the visible tab.
 */
namespace Gui {
    namespace Selection {
        /**@brief the tag, e.g. "GER". Empty when unknown.*/
        const std::string& tag();

        /**@brief where the tag came from, for display ("Setup" or "current player")*/
        const std::string& source();

        /**@brief why tag() is empty*/
        const std::string& reason();

        /**@brief re-reads from Lua if the cached value is older than \p intervalMs*/
        void refreshIfStale(int intervalMs = 2000);

        /**@brief forces the next refreshIfStale to re-read, after the selection changes*/
        void invalidate();
    }
}
