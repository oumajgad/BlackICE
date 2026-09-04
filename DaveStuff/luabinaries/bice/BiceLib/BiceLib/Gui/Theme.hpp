#pragma once

#include <imgui.h>

/**
 * How the overlay is coloured.
 *
 * A list rather than a choice between two: each theme is one row of a table in
 * Theme.cpp, and everything here works off the count and the index. Nothing in the
 * interface names a particular theme, so adding one is a change to that table and to
 * nothing else.
 *
 * **To add a theme**, see the table at the bottom of Theme.cpp. Every theme is the
 * same two things: a palette of eleven colours, which the whole ImGui style is worked
 * out from, and eight marks, which are the colours a page uses to mean something. No
 * theme is a special case of another - the first row is only the one an install falls
 * back to when the setting is missing or names something that no longer exists.
 *
 * The choice is kept in BiceLibSettings.ini by its id, so the file stays readable and
 * reordering the table cannot change what an install is set to.
 */
namespace Gui {
    namespace Theme {
        /**@brief what a theme is called, for the interface and the settings file*/
        struct Info
        {
            // Written to the settings file. An install set to an id that is no longer
            // in the table falls back to the first row, so changing one costs anybody
            // using that theme their choice - which is cheap enough to be worth it
            // for a name that has become wrong.
            const char* id = "";

            const char* name = "";
            const char* description = "";
        };

        /**@brief how many themes there are*/
        int count();

        /**@brief one theme's names, by index; index 0 for an index out of range*/
        Info at(int index);

        /**@brief which theme is in use, read from the settings file on the first call*/
        int currentIndex();

        /**@brief switches theme, applies it now, and remembers it*/
        void setCurrent(int index);

        /**
        @brief paints the current theme onto the live ImGui style

        Called once while ImGui is being set up, and again whenever the theme changes.
        Safe to call at any point between frames.

        It also puts back the two things multi viewport needs whatever the theme says:
        square corners and an opaque window background. A detached window is its own
        OS window, so rounded corners would show the desktop through the gaps and a
        translucent background would show whatever is behind it rather than the game.
        */
        void apply();

        /**
         * The colours pages use to mean something rather than to decorate.
         *
         * Pages held these as literals, which is why a warning that read clearly on
         * the dark styles was almost invisible on the light one - amber on white. A
         * page now asks for the meaning and the theme decides the colour.
         *
         * **Never call these at file scope.** They read the theme, which is not
         * chosen until the settings file has been read, so a `const ImVec4` built at
         * load time would hold whatever the first theme happened to be. Ask inside
         * the draw call, which costs nothing.
         */
        enum class Mark {
            Warning,     // amber: worth noticing
            Error,       // red: wrong, or missing
            ErrorDim,    // the same, said more quietly
            ErrorFill,   // behind a control whose value is wrong
            Success,     // green: it worked
            SuccessFill, // a bar that is filling up healthily
            Info,        // a hint, or an aside
            Strong,      // the most contrast the theme has, for text that must stand out
        };

        /**@brief the colour this theme uses for that meaning*/
        ImVec4 mark(Mark which);
    }
}
