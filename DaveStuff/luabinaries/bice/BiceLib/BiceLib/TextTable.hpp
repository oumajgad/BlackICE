#pragma once

#include <cstddef>
#include <map>
#include <string>
#include <vector>

/**
 * Laying text out in columns, for text appended to the game's own tooltips.
 *
 * **The game's text is not monospaced**, so padding a label out to a fixed number of
 * characters does not line the next column up: a label of thirteen narrow letters is
 * barely half the width of thirteen wide ones. Columns are placed in pixels instead.
 *
 * **The measuring is the game's own.** `Hooks::Tooltips::TooltipFont` catches the font a
 * tooltip is drawn in and hands over its `GetStringWidth`, so nothing here has to be told
 * which font that is - which matters, because a tooltip's font is named in a
 * `textBoxType` and a mod can change it. Reading a descriptor off disk is only what the
 * first tooltip of a session gets.
 *
 * **A column lands on the grid a space makes.** Padding has to be made of characters, and
 * the only two glyphs that draw nothing - the space and the non-breaking space - are the
 * same width as each other. There is no thinner one, and no escape that moves the pen by
 * an arbitrary amount, so a column sits within half a space of where it was asked for:
 * one or two pixels. That is a property of the medium, not of this code, and better
 * measuring does not improve it.
 */
namespace Text {
    /**@brief measures text exactly as the game does, in pixels*/
    typedef int (*Measure)(const char* text, int length);

    /**
    @brief measure through the game from here on, rather than from a descriptor

    Once `Hooks::Tooltips::TooltipFont` has caught the font a tooltip is measured with,
    this hands its `GetStringWidth` over and every width below goes through it: kerning,
    escapes and icons included, because it is the same code that decides where the glyphs
    land.

    Passing null goes back to the descriptor.
    */
    void useGameMeasure(Measure measure);

    /**
    @brief the glyph advances of one of the game's bitmap fonts

    Parsed from the `.fnt` beside the texture, an AngelCode BMFont descriptor in plain
    text. **The game reads that same file, positionally**: `CEU3BitmapFont::Load`
    (`0x6F9EA0`) matches the first token of a line against `char`, then takes the seven
    numbers after it in file order - id, x, y, width, height, xoffset, yoffset, xadvance -
    without ever looking at the key names, which is why none of them appears in the
    executable. Each glyph becomes a record reached through `font + id * 4 + 0x94`, with
    the advance at `+0x18` and its kerning pairs from `+0x1c`.

    Only the 256 single byte codes are kept. Game text is Windows-1252 (see
    `Text::toUtf8`), so a byte is a glyph and there is nothing wider to index.
    */
    class Font
    {
    public:
        /**
        @brief the descriptor the first tooltip of a session is measured from

        `Arial14`, looked for in the mod first and the game underneath it, the way the
        game resolves its own content. **Established by measuring, not by reading**: see
        `TOOLTIP_FONT` in the .cpp for the three numbers that identify it, and
        `reversing/FINDINGS-text.md` for why `interface/core.gfx` cannot be taken at its
        word here.

        Only the first tooltip uses this. After that `useGameMeasure` has taken over and
        nothing in this class is consulted.

        If the descriptor cannot be found at all every glyph counts as one unit and a
        space as one, which turns this back into character counting - laid out, but only
        to the accuracy counting characters gives.
        */
        static const Font& toolTip();

        /**
        @brief how wide this text draws, in pixels

        Follows `CBitmapFont::GetStringWidth` (`0x6FD700`), which is what the game itself
        measures a string with:

        - a `\xA7` and the byte after it select a colour and are skipped entirely;
        - each glyph adds its advance, and a glyph the font does not list adds nothing;
        - **a kerning pair between a glyph and the byte that follows it adjusts the
          total**, which is the piece that made columns miss by a few pixels when it was
          left out. The partner is the literal next byte, not the next drawn one - that is
          how the game does it, escape or no escape;
        - a newline ends the line, and the result is the widest of them.

        The game's version also handles the `@`, `\xA3` and `\xA4` icon escapes by asking
        the font for an icon's width. Nothing here writes those, so they are left as
        ordinary glyphs; a cell containing one would measure short.
        */
        int width(const char* text, size_t length) const;
        int width(const std::string& text) const;

        /**@brief the width of the one character padding is built from*/
        int spaceWidth() const;

    private:
        Font();

        bool load(const std::string& path);
        void assumeMonospaced();
        int kerningBetween(unsigned char first, unsigned char second) const;

        int advance[256];

        /**@brief `(first << 8) | second` to the pixels that pair moves by, usually -1*/
        std::map<unsigned, int> kerning;

        int space;
        bool real;
        const char* message;
    };

    /**@brief which edge of its column a cell sits against*/
    enum Align
    {
        LEFT,
        RIGHT
    };

    /**
    @brief rows of cells, rendered into one string with the columns lined up

    Built a cell at a time and rendered at the end, because a column is only as wide as
    its widest cell and that is not known until the last row is in.

    Cells carry their own colour escapes; the table neither adds nor strips them, it just
    does not count them. A cell holding a trailing `\xA7W` leaves the colour reset where
    the caller put it rather than in the middle of the padding.

        Text::Table table;
        table.cell(label).cell(value).row();
        table.cell(other).cell(number).row();
        std::string text = table.text();

    Alignment is per column and defaults to LEFT. A ragged row - fewer cells than the
    widest row - is allowed and simply ends early; nothing is padded past the last cell
    on a line, so no line carries trailing spaces.
    */
    class Table
    {
    public:
        /**
        @param metrics the font the result will be drawn in
        */
        explicit Table(const Font& metrics = Font::toolTip());

        /**
        @brief the gap between one column and the next, in pixels

        Defaults to two spaces' worth. Set in pixels rather than characters for the same
        reason the columns are measured that way.
        */
        Table& gap(int pixels);

        /**@brief text put in front of every row, usually a couple of spaces*/
        Table& indent(const char* prefix);

        /**@brief how the given column sits in its width; columns count from zero*/
        Table& align(size_t column, Align how);

        /**@brief adds one cell to the row being built*/
        Table& cell(const char* text);
        Table& cell(const std::string& text);

        /**@brief ends the row being built; an empty row is a blank line*/
        Table& row();

        /**@brief true if nothing has been added, so a caller can skip an empty block*/
        bool empty() const;

        /**
        @brief the laid out text, rows joined by newlines

        There is no trailing newline: the caller decides what this is joined to. A row
        left unfinished - cells added without a closing `row()` - is rendered as the last
        line anyway rather than dropped.
        */
        std::string text() const;

    private:
        int widthOf(const std::string& cell) const;

        /**
        @brief spaces onto the end of the line until it reaches `to`, or as near as it can
        @returns the pixel the line actually ends at, which is what the next cell starts from

        The achieved position is returned rather than assumed so that rounding does not
        accumulate: every column is placed from where the line really is, not from where
        the one before it was meant to end.
        */
        int pad(std::string& line, int from, int to, bool anySpace) const;

        const Font* font;
        std::vector<std::vector<std::string> > rows;
        std::vector<std::string> building;
        std::vector<Align> alignments;
        std::string prefix;
        int columnGap;
    };
}
