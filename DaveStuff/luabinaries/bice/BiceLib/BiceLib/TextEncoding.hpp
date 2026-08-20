#pragma once

#include <string>

/**
 * Text coming out of the game is Windows-1252: Paradox's data files are, and so are
 * the strings the game keeps in memory. ImGui requires UTF-8 and draws anything it
 * cannot decode as its fallback glyph, which is why German names full of umlauts
 * turn into a row of '?'.
 *
 * Convert at the boundary, once, rather than per widget.
 */
namespace Text {
    /**
    @brief converts game text to UTF-8

    Strings that already are valid UTF-8 are returned unchanged, so this is safe to
    apply twice and safe on sources that are already UTF-8. Pure ASCII is valid UTF-8
    and therefore untouched.
    */
    std::string toUtf8(const char* text, size_t length);
    std::string toUtf8(const std::string& text);
}
