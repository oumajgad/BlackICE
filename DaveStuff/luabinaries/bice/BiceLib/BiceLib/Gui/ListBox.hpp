#pragma once

#include <string>
#include <vector>

#include <imgui.h>

namespace Gui {
    /**
    @brief a filterable, keyboard navigable list of strings in its own child window

    Draws a filter box and the matching items as selectables. Once the list has focus
    the arrow keys move the selection, Home/End jump to the ends, and the selection is
    scrolled into view. While navigating it claims the keyboard, otherwise the arrows
    would also pan the game map.

    @param id      child window id, unique within the page
    @param size    child size; 0 for either axis means "fill"
    @param items   every item; filtering is applied here rather than by the caller
    @param filter  caller owned filter buffer, so the text survives between frames
    @param selected in/out, the selected item. Cleared if it is filtered out.
    @returns true if the selection changed this frame
    */
    bool filteredList(const char* id, const ImVec2& size,
        const std::vector<std::string>& items,
        char* filter, size_t filterSize,
        std::string& selected);

    /**
    @brief draggable divider that resizes the pane to its left

    Place between the two panes, after the left one's EndChild. Handles the drag, the
    resize cursor and drawing the divider, and issues the SameLine calls on both
    sides, so the caller just draws pane, splitter, pane.

    @param id     unique within the page
    @param width  in/out, the left pane's width. Clamped so neither side can be
                  dragged away entirely.
    @param minWidth     smallest the left pane may become
    @param minRemaining smallest the right pane may become
    @returns true while being dragged
    */
    bool verticalSplitter(const char* id, float* width,
        float minWidth = 120.0f, float minRemaining = 200.0f);
}
