#pragma once

#include <vector>

/**
 * One page of the in-game utility.
 *
 * Every page lives in its own translation unit under Gui/Pages and registers itself
 * with the REGISTER_GUI_PAGE macro, so adding a page means adding one file: there is
 * no central list to edit and pages can be dropped by excluding the file.
 *
 * Pages are drawn as individual ImGui windows docked into a shared dockspace. That
 * gives one tabbed window by default while still letting a tab be torn off and
 * arranged separately.
 */
namespace Gui {
    class GuiPage
    {
    public:
        virtual ~GuiPage() = default;

        /**
        @brief what the page is called on its tab (e.g. "Inspector")

        Not necessarily unique: the Help group repeats Misc and National Focus from
        Main, as the wxWidgets utility did. Use windowName() for anything ImGui
        identifies by name.
        */
        virtual const char* title() const = 0;

        /**
        @brief group the page belongs to, e.g. "Main" or "Game Info"

        Groups are listed in the order given by Gui::GROUP_ORDER; anything not named
        there sorts last, so a new group shows up without breaking the build.
        */
        virtual const char* group() const { return "Main"; }

        /**
        @brief sort key within the group, low first

        Registration order is static initialization order across translation units,
        which is unspecified, so pages that care about their position must say so.
        Leave the default to sort alphabetically after the ones that do.
        */
        virtual int order() const { return 1000; }

        /**@brief draws the page body. Called between Begin() and End().*/
        virtual void draw() = 0;

        /**@brief whether the page is currently open as a tab or floating window*/
        bool open = true;
    };

    /**@brief group names in display order. Mirrors the old wx window split.*/
    extern const char* const GROUP_ORDER[];
    extern const int GROUP_COUNT;

    /**
     * How long a page has spent drawing.
     *
     * The first draw is the interesting one: a page loads and parses whatever it needs
     * the first time it is looked at, so that call carries the whole cost of opening it
     * while every later one is just drawing. Kept for every page so the Timing page can
     * say where the wait on first opening the overlay actually went.
     */
    struct PageTiming
    {
        double firstMs = 0.0;
        double lastMs = 0.0;
        double worstMs = 0.0;
        int calls = 0;
    };

    /**@brief timings for one page; calls is 0 until it has been drawn once*/
    const PageTiming& timing(const GuiPage* page);

    /**@brief forgets every measurement, so the next draws are recorded as firsts again*/
    void resetTimings();

    /**@brief adds a page to the registry. Use REGISTER_GUI_PAGE rather than calling this.*/
    void registerPage(GuiPage* page);

    /**@brief every registered page, sorted by group then order then title*/
    const std::vector<GuiPage*>& pages();

    /**
    @brief the page's ImGui window name: unique, unlike its title

    ImGui identifies a window, a tab and a menu item by name, so two pages sharing a
    title are one window as far as it is concerned - they fight over the same dock, the
    same open flag and the same saved position.

    A page keeps its plain title while nothing else uses it, and only a clash appends
    "##<group>", which ImGui hides from the label. Doing it that way rather than always
    appending leaves the layouts saved under the old names alone.
    */
    const char* windowName(const GuiPage* page);

    /**
    @brief draws the host window, its dockspace and every open page

    Builds a default layout on first use where all pages are tabs of a single node.
    */
    void drawAll();

    /**@brief the menu entries used to reopen closed pages*/
    void drawPageMenu();

    /**
    @brief throws the saved arrangement away and rebuilds the one the code describes

    Takes effect at the start of the next frame rather than immediately, so nothing is
    torn down underneath a window that has already been submitted this frame. Pages go
    back to being tabs of their own group, every window forgets where it was, and what
    is open goes back to its defaults.
    */
    void requestLayoutReset();
}

/**
 * Registers a page type. Put this at the bottom of the page's .cpp:
 *     REGISTER_GUI_PAGE(ICDaysPage);
 */
#define REGISTER_GUI_PAGE(TYPE)                          \
    namespace {                                          \
        struct TYPE##Registrar                           \
        {                                                \
            TYPE##Registrar() {                          \
                static TYPE instance;                    \
                ::Gui::registerPage(&instance);          \
            }                                            \
        };                                               \
        TYPE##Registrar TYPE##RegistrarInstance;         \
    }
