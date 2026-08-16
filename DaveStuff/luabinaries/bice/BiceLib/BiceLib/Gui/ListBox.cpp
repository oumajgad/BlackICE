#include <Gui/ListBox.hpp>

#include <algorithm>
#include <cfloat>
#include <cctype>
#include <cstring>

namespace {
    bool matchesFilter(const std::string& haystack, const char* needle) {
        if (needle == nullptr || needle[0] == '\0') {
            return true;
        }
        const size_t length = strlen(needle);
        const auto it = std::search(haystack.begin(), haystack.end(), needle, needle + length,
            [](char a, char b) { return std::tolower(static_cast<unsigned char>(a)) ==
                                        std::tolower(static_cast<unsigned char>(b)); });
        return it != haystack.end();
    }
}

bool Gui::verticalSplitter(const char* id, float* width, float minWidth, float minRemaining) {
    const float thickness = 6.0f;

    ImGui::SameLine(0.0f, 0.0f);

    // Measured before the button is placed: afterwards the cursor has moved on and
    // these would describe the next row instead.
    const float remaining = ImGui::GetContentRegionAvail().x;
    const float height = ImGui::GetContentRegionAvail().y;

    ImGui::InvisibleButton(id, ImVec2(thickness, height > 0.0f ? height : 1.0f));

    const bool active = ImGui::IsItemActive();
    const bool hovered = ImGui::IsItemHovered();
    if (active || hovered) {
        ImGui::SetMouseCursor(ImGuiMouseCursor_ResizeEW);
    }
    if (active) {
        *width += ImGui::GetIO().MouseDelta.x;
    }

    // The left pane has already been drawn at the old width, so this takes effect on
    // the next frame - which is what makes the drag feel continuous rather than jumpy.
    const float maxWidth = *width + remaining - thickness - minRemaining;
    if (*width > maxWidth) {
        *width = maxWidth;
    }
    if (*width < minWidth) {
        *width = minWidth;
    }

    const ImU32 color = ImGui::GetColorU32(
        active ? ImGuiCol_SeparatorActive : (hovered ? ImGuiCol_SeparatorHovered : ImGuiCol_Separator));
    ImGui::GetWindowDrawList()->AddRectFilled(ImGui::GetItemRectMin(), ImGui::GetItemRectMax(), color);

    ImGui::SameLine(0.0f, 0.0f);
    return active;
}

bool Gui::filteredList(const char* id, const ImVec2& size,
    const std::vector<std::string>& items,
    char* filter, size_t filterSize,
    std::string& selected) {

    bool changed = false;

    ImGui::BeginChild(id, size, ImGuiChildFlags_Borders);

    ImGui::SetNextItemWidth(-FLT_MIN);
    ImGui::InputTextWithHint("##filter", "Filter", filter, filterSize);
    const bool filterHasFocus = ImGui::IsItemActive();

    // Arrow keys should step through what is on screen, not through hidden entries.
    std::vector<const std::string*> visible;
    visible.reserve(items.size());
    int current = -1;
    for (const std::string& item : items) {
        if (!matchesFilter(item, filter)) {
            continue;
        }
        if (item == selected) {
            current = static_cast<int>(visible.size());
        }
        visible.push_back(&item);
    }

    bool scrollToSelected = false;

    // Not while the filter box is taking input: there the arrows are the text cursor.
    const bool listHasFocus = ImGui::IsWindowFocused() && !filterHasFocus;
    if (listHasFocus && !visible.empty()) {
        const int last = static_cast<int>(visible.size()) - 1;
        int next = current;

        if (ImGui::IsKeyPressed(ImGuiKey_DownArrow)) {
            next = (current < 0) ? 0 : current + 1;
        }
        else if (ImGui::IsKeyPressed(ImGuiKey_UpArrow)) {
            next = (current < 0) ? last : current - 1;
        }
        else if (ImGui::IsKeyPressed(ImGuiKey_Home)) {
            next = 0;
        }
        else if (ImGui::IsKeyPressed(ImGuiKey_End)) {
            next = last;
        }

        next = (next < 0) ? 0 : (next > last ? last : next);
        if (next != current) {
            selected = *visible[next];
            current = next;
            scrollToSelected = true;
            changed = true;
        }

        // The game also uses the arrow keys, so claim them while the list is driving.
        ImGui::SetNextFrameWantCaptureKeyboard(true);
    }

    for (int i = 0; i < static_cast<int>(visible.size()); i++) {
        const std::string& item = *visible[i];
        if (ImGui::Selectable(item.c_str(), i == current)) {
            selected = item;
            changed = true;
        }
        if (i == current && scrollToSelected) {
            ImGui::SetScrollHereY(0.5f);
        }
    }

    ImGui::EndChild();
    return changed;
}
