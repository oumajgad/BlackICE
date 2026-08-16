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

        /**@brief stable identifier, also the ImGui window name (e.g. "Inspector")*/
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

    /**@brief adds a page to the registry. Use REGISTER_GUI_PAGE rather than calling this.*/
    void registerPage(GuiPage* page);

    /**@brief every registered page, sorted by group then order then title*/
    const std::vector<GuiPage*>& pages();

    /**
    @brief draws the host window, its dockspace and every open page

    Builds a default layout on first use where all pages are tabs of a single node.
    */
    void drawAll();

    /**@brief the menu entries used to reopen closed pages*/
    void drawPageMenu();
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
