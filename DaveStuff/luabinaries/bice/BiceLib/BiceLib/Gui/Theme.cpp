#include <Gui/Theme.hpp>

#include <Settings.hpp>

#include <cstring>
#include <string>

#include <imgui.h>

namespace {
    const char* THEME_SETTING = "gui.theme";

    /**@brief a colour written the way the game's own files write one*/
    ImVec4 rgb(int r, int g, int b, float alpha = 1.0f) {
        return ImVec4(r / 255.0f, g / 255.0f, b / 255.0f, alpha);
    }

    ImVec4 fade(const ImVec4& colour, float alpha) {
        return ImVec4(colour.x, colour.y, colour.z, alpha);
    }

    /**
    @brief \p amount of the way from \p from to \p to, opaque

    Used to tint a surface with the theme's accent. Mixing rather than fading, because
    a faded accent lets whatever is behind the window show through, and these are the
    parts of the window that have to look solid.
    */
    ImVec4 mix(const ImVec4& from, const ImVec4& to, float amount) {
        return ImVec4(
            from.x + (to.x - from.x) * amount,
            from.y + (to.y - from.y) * amount,
            from.z + (to.z - from.z) * amount,
            1.0f);
    }

    /**
     * Everything a theme needs to say, in eleven colours.
     *
     * The whole ImGui style is worked out from these by paintPalette, so a theme does
     * not have to have an opinion about scrollbar grabs or docking previews - only
     * about what a panel looks like, what sits on one, and what wants reading first.
     */
    struct Palette
    {
        ImVec4 deep;        // behind everything
        ImVec4 panel;       // a panel's own ground
        ImVec4 raised;      // a control sitting on a panel
        ImVec4 hover;
        ImVec4 active;
        ImVec4 edge;        // the lines between things

        ImVec4 text;
        ImVec4 textDim;
        ImVec4 accent;      // headings, and anything that wants reading first
        ImVec4 accentDim;
        ImVec4 positive;    // a bar that is filling up
    };

    /**
    @brief works the whole style out from a palette

    One place, so every theme is consistent about which colour plays which part and a
    new one cannot forget a control.

    **Every ImGuiCol_ is written here.** That is what lets a theme be nothing but a
    palette: there is no base style underneath holding leftovers, so applying one
    cannot leave a colour behind from the one before.
    */
    void paintPalette(ImGuiStyle& style, const Palette& p) {
        ImVec4* c = style.Colors;

        c[ImGuiCol_Text] = p.text;
        c[ImGuiCol_TextDisabled] = p.textDim;
        c[ImGuiCol_TextSelectedBg] = fade(p.accent, 0.45f);

        c[ImGuiCol_WindowBg] = p.panel;
        c[ImGuiCol_ChildBg] = fade(p.deep, 0.35f);
        c[ImGuiCol_PopupBg] = p.deep;
        c[ImGuiCol_MenuBarBg] = p.deep;

        c[ImGuiCol_Border] = p.edge;
        c[ImGuiCol_BorderShadow] = ImVec4(0, 0, 0, 0);

        c[ImGuiCol_FrameBg] = p.deep;
        c[ImGuiCol_FrameBgHovered] = p.raised;
        c[ImGuiCol_FrameBgActive] = p.active;

        // The title bar of the window that has focus carries the accent, the way
        // ImGui's own styles do. It is what tells you which window you are typing
        // into when several are open.
        c[ImGuiCol_TitleBg] = mix(p.deep, p.accent, 0.20f);
        c[ImGuiCol_TitleBgActive] = mix(p.panel, p.accent, 0.45f);
        c[ImGuiCol_TitleBgCollapsed] = fade(p.deep, 0.75f);

        c[ImGuiCol_ScrollbarBg] = fade(p.deep, 0.60f);
        c[ImGuiCol_ScrollbarGrab] = p.raised;
        c[ImGuiCol_ScrollbarGrabHovered] = p.hover;
        c[ImGuiCol_ScrollbarGrabActive] = p.active;

        c[ImGuiCol_CheckMark] = p.accent;
        c[ImGuiCol_SliderGrab] = p.accentDim;
        c[ImGuiCol_SliderGrabActive] = p.accent;

        c[ImGuiCol_Button] = p.raised;
        c[ImGuiCol_ButtonHovered] = p.hover;
        c[ImGuiCol_ButtonActive] = p.active;

        c[ImGuiCol_Header] = fade(p.accent, 0.28f);
        c[ImGuiCol_HeaderHovered] = fade(p.accent, 0.42f);
        c[ImGuiCol_HeaderActive] = fade(p.accent, 0.58f);

        c[ImGuiCol_Separator] = p.edge;
        c[ImGuiCol_SeparatorHovered] = p.accentDim;
        c[ImGuiCol_SeparatorActive] = p.accent;

        c[ImGuiCol_ResizeGrip] = fade(p.accent, 0.22f);
        c[ImGuiCol_ResizeGripHovered] = fade(p.accent, 0.50f);
        c[ImGuiCol_ResizeGripActive] = p.accent;

        // Tabs are tinted with the accent too, and the selected one most of all, so a
        // dock's tab bar reads as a row of tabs rather than as more panel.
        c[ImGuiCol_Tab] = mix(p.deep, p.accent, 0.30f);
        c[ImGuiCol_TabHovered] = mix(p.hover, p.accent, 0.55f);
        c[ImGuiCol_TabSelected] = mix(p.panel, p.accent, 0.55f);
        c[ImGuiCol_TabSelectedOverline] = p.accent;
        c[ImGuiCol_TabDimmed] = mix(p.deep, p.accent, 0.15f);
        c[ImGuiCol_TabDimmedSelected] = mix(p.raised, p.accent, 0.25f);

        c[ImGuiCol_DockingPreview] = fade(p.accent, 0.40f);
        c[ImGuiCol_DockingEmptyBg] = p.deep;

        c[ImGuiCol_PlotLines] = p.accent;
        c[ImGuiCol_PlotLinesHovered] = p.text;
        c[ImGuiCol_PlotHistogram] = p.positive;
        c[ImGuiCol_PlotHistogramHovered] = p.accent;

        c[ImGuiCol_TableHeaderBg] = p.raised;
        c[ImGuiCol_TableBorderStrong] = p.edge;
        c[ImGuiCol_TableBorderLight] = p.raised;
        c[ImGuiCol_TableRowBg] = ImVec4(0, 0, 0, 0);
        c[ImGuiCol_TableRowBgAlt] = fade(p.text, 0.035f);

        c[ImGuiCol_NavCursor] = p.accent;
        c[ImGuiCol_NavWindowingHighlight] = fade(p.text, 0.70f);
        c[ImGuiCol_NavWindowingDimBg] = fade(p.deep, 0.20f);
        c[ImGuiCol_DragDropTarget] = p.accent;
        c[ImGuiCol_DragDropTargetBg] = fade(p.accent, 0.25f);
        c[ImGuiCol_ModalWindowDimBg] = fade(p.deep, 0.55f);

        c[ImGuiCol_CheckboxSelectedBg] = fade(p.accent, 0.35f);
        c[ImGuiCol_InputTextCursor] = p.text;
        c[ImGuiCol_TabDimmedSelectedOverline] = p.accentDim;
        c[ImGuiCol_TextLink] = p.accent;
        c[ImGuiCol_TreeLines] = p.edge;
        c[ImGuiCol_UnsavedMarker] = p.text;

        // Squarer than ImGui's default, and with an edge on every frame, which is how
        // a palette themed panel reads as a panel.
        style.FrameRounding = 2.0f;
        style.GrabRounding = 2.0f;
        style.TabRounding = 2.0f;
        style.ScrollbarRounding = 2.0f;
        style.PopupRounding = 2.0f;
        style.ChildRounding = 0.0f;
        style.FrameBorderSize = 1.0f;
    }

    /**
     * Dark grey surfaces with ImGui's blue for the accent, which is what the utility
     * has always looked like. It is a palette like any other; being the one an
     * install falls back to is the only thing that sets it apart.
     */
    const Palette DARK = {
        rgb(16, 16, 18),        // deep
        rgb(26, 26, 28),        // panel
        rgb(44, 44, 48),        // raised
        rgb(58, 58, 64),        // hover
        rgb(74, 74, 82),        // active
        rgb(10, 10, 12),        // edge
        rgb(236, 236, 236),     // text
        rgb(128, 128, 132),     // textDim
        rgb(66, 150, 250),      // accent, ImGui's own blue
        rgb(44, 100, 168),      // accentDim
        rgb(96, 180, 110),      // positive
    };

    /**
     * The game's own palette, read off its production screen: olive drab for anything
     * that holds something, amber for headings, and a cream rather than a pure white
     * for text - the game never uses white.
     */
    const Palette ARMY_GREEN = {
        rgb(45, 45, 31),        // deep
        rgb(74, 74, 51),        // panel
        rgb(96, 96, 66),        // raised
        rgb(122, 122, 84),      // hover
        rgb(146, 146, 100),     // active
        rgb(32, 32, 22),        // edge
        rgb(232, 232, 216),     // text
        rgb(150, 150, 128),     // textDim
        rgb(226, 162, 38),      // accent
        rgb(150, 108, 26),      // accentDim
        rgb(122, 176, 74),      // positive
    };

    /**
     * Mid grey: the dark theme's readability without its weight, for anyone who finds
     * the dark one heavy and the light one glaring.
     */
    const Palette GREY = {
        rgb(58, 60, 64),        // deep
        rgb(78, 80, 85),        // panel
        rgb(98, 101, 107),      // raised
        rgb(118, 122, 129),     // hover
        rgb(138, 142, 150),     // active
        rgb(44, 46, 49),        // edge
        rgb(232, 234, 237),     // text
        rgb(160, 164, 170),     // textDim
        rgb(104, 160, 220),     // accent
        rgb(70, 110, 155),      // accentDim
        rgb(110, 180, 120),     // positive
    };

    /**
     * Paper rather than a lit panel: the overlay as a document over the map, for
     * anyone playing in daylight or finding the dark styles hard to read.
     */
    const Palette LIGHT = {
        rgb(226, 226, 222),     // deep
        rgb(244, 244, 240),     // panel
        rgb(214, 214, 208),     // raised
        rgb(198, 202, 212),     // hover
        rgb(176, 184, 202),     // active
        rgb(178, 178, 172),     // edge
        rgb(28, 28, 26),        // text
        rgb(122, 122, 116),     // textDim
        rgb(28, 96, 168),       // accent
        rgb(120, 156, 200),     // accentDim
        rgb(38, 132, 62),       // positive
    };

    /**
     * What a page means, in this theme's colours. Same order as Gui::Theme::Mark.
     *
     * Separate from the Palette because the palette is about surfaces and these are
     * about meaning: a theme can keep ImGui's own style entirely and still need to
     * say what "wrong" looks like on it.
     */
    struct Marks
    {
        ImVec4 warning;
        ImVec4 error;
        ImVec4 errorDim;
        ImVec4 errorFill;
        ImVec4 success;
        ImVec4 successFill;
        ImVec4 info;
        ImVec4 strong;
    };

    // The values the pages held as literals before the themes existed, so the dark
    // style says the same things in the same colours it always has.
    const Marks DARK_MARKS = {
        rgb(204, 153, 51),      // warning
        rgb(217, 89, 89),       // error
        rgb(158, 87, 87),       // errorDim
        rgb(115, 38, 38),       // errorFill
        rgb(115, 217, 115),     // success
        rgb(66, 150, 89),       // successFill
        rgb(140, 179, 230),     // info
        rgb(255, 255, 255),     // strong
    };

    // Mid tones: bright enough to carry against grey, without the glare the dark
    // set's colours have on a lighter panel.
    const Marks GREY_MARKS = {
        rgb(230, 180, 70),      // warning
        rgb(232, 110, 105),     // error
        rgb(180, 95, 90),       // errorDim
        rgb(96, 52, 50),        // errorFill
        rgb(130, 210, 130),     // success
        rgb(80, 140, 95),       // successFill
        rgb(150, 190, 235),     // info
        rgb(255, 255, 255),     // strong
    };

    // Darker and more saturated, because these sit on paper. The dark set's amber on
    // a white panel is what made this necessary.
    const Marks LIGHT_MARKS = {
        rgb(158, 100, 0),       // warning
        rgb(180, 30, 30),       // error
        rgb(140, 60, 60),       // errorDim
        rgb(248, 214, 214),     // errorFill, a wash rather than a colour
        rgb(20, 118, 48),       // success
        rgb(96, 168, 112),      // successFill
        rgb(20, 84, 160),       // info
        rgb(0, 0, 0),           // strong
    };

    // The game's own signal colours: its amber, the red of a close button, the green
    // of a bar that is filling.
    const Marks ARMY_GREEN_MARKS = {
        rgb(226, 162, 38),      // warning
        rgb(196, 74, 62),       // error
        rgb(146, 62, 54),       // errorDim
        rgb(74, 34, 30),        // errorFill
        rgb(140, 196, 88),      // success
        rgb(100, 146, 62),      // successFill
        rgb(150, 178, 214),     // info
        rgb(255, 250, 232),     // strong
    };

    /**
     * A theme, whole. Every one is a palette and a set of marks - there is no base
     * style and no optional part, so no theme is a special case of another.
     */
    struct Definition
    {
        Gui::Theme::Info info;
        const Palette* palette;
        const Marks* marks;
    };

    // ==================================================================
    // The themes. Add one by adding a row.
    // ==================================================================
    const Definition THEMES[] = {
        {
            { "dark", "Dark",
              "Dark grey panels with a blue accent, which the utility has\n"
              "always used. Easiest to pick out over a busy map." },
            &DARK, &DARK_MARKS,
        },
        {
            { "grey", "Grey",
              "Mid grey panels: the dark theme's readability without its\n"
              "weight, if the dark one is heavy and the light one glares." },
            &GREY, &GREY_MARKS,
        },
        {
            { "light", "Light",
              "Paper: the overlay as a document over the map. For playing\n"
              "in daylight, or if the dark styles are hard to read." },
            &LIGHT, &LIGHT_MARKS,
        },
        {
            { "army_green", "Army green",
              "Olive panels, amber headings."},
            &ARMY_GREEN, &ARMY_GREEN_MARKS,
        },
    };
    const int THEME_COUNT = static_cast<int>(sizeof(THEMES) / sizeof(THEMES[0]));

    // What an install with no setting, or one naming a theme that no longer exists,
    // ends up with. The only thing that makes the first row different from the rest.
    const int FALLBACK = 0;

    int currentValue = 0;
    bool loaded = false;

    /**@brief the theme a stored id means, or the fallback when it means nothing*/
    int idToIndex(const std::string& id) {
        for (int i = 0; i < THEME_COUNT; i++) {
            if (id == THEMES[i].info.id) {
                return i;
            }
        }
        return FALLBACK;
    }

    void load() {
        if (loaded) {
            return;
        }
        loaded = true;
        currentValue = idToIndex(
            Settings::getString(THEME_SETTING, THEMES[FALLBACK].info.id));
    }
}

int Gui::Theme::count() {
    return THEME_COUNT;
}

Gui::Theme::Info Gui::Theme::at(int index) {
    if (index < 0 || index >= THEME_COUNT) {
        return THEMES[FALLBACK].info;
    }
    return THEMES[index].info;
}

int Gui::Theme::currentIndex() {
    load();
    return currentValue;
}

void Gui::Theme::setCurrent(int index) {
    load();
    if (index < 0 || index >= THEME_COUNT) {
        return;
    }
    currentValue = index;
    Settings::setString(THEME_SETTING, THEMES[index].info.id);
    apply();
}

void Gui::Theme::apply() {
    load();

    if (ImGui::GetCurrentContext() == nullptr) {
        return;     // nothing to paint yet; initImGui applies this once there is
    }

    // One path, whichever theme it is: paintPalette writes every colour, so there is
    // nothing to reset first and nothing left over from the theme before.
    ImGuiStyle& style = ImGui::GetStyle();
    paintPalette(style, *THEMES[currentValue].palette);

    // Whatever the theme says, a detached window is its own OS window.
    if (ImGui::GetIO().ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
        style.WindowRounding = 0.0f;
        style.Colors[ImGuiCol_WindowBg].w = 1.0f;
    }
}

ImVec4 Gui::Theme::mark(Mark which) {
    load();
    const Marks& m = *THEMES[currentValue].marks;

    switch (which) {
    case Mark::Warning:     return m.warning;
    case Mark::Error:       return m.error;
    case Mark::ErrorDim:    return m.errorDim;
    case Mark::ErrorFill:   return m.errorFill;
    case Mark::Success:     return m.success;
    case Mark::SuccessFill: return m.successFill;
    case Mark::Info:        return m.info;
    case Mark::Strong:      return m.strong;
    }
    return m.strong;
}
