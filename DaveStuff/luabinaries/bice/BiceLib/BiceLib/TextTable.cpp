#include <TextTable.hpp>

#include <Overlay.hpp>
#include <utils.hpp>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>

namespace {
    /**
     * **The font tooltips are drawn in**: `interface/core.gui` has
     * `textBoxType { name = "ToolTip" font = "Arial14" }`, in the base game, `tfh` and the
     * mod alike.
     *
     * **Not `garamond_16`**, which `core.gfx` names as `ToolTip_Font`: that `bitmapfont`
     * belongs to `console_text`. The two names are easy to mistake for each other, and
     * `reversing/FINDINGS-text.md` records how the tooltip's was confirmed against the
     * game's own measurements.
     *
     * This is only what the first tooltip of a session is laid out with; from the second
     * on the game does the measuring and this is not consulted. It is worth being right
     * anyway, since that first tooltip is one somebody sees.
     */
    const char* const TOOLTIP_FONT = "gfx\\fonts\\Arial14.fnt";

    /**@brief the colour escape: this byte and the one after it select a colour and draw
       nothing*/
    const unsigned char ESCAPE = 0xA7;

    /**@brief what an unmeasured font gives every glyph, so a table still lines up by
       character count*/
    const int ONE_UNIT = 1;

    /**
     * **The game's own measuring, once there is one.** Everything below consults this
     * first: the descriptor is only what gets used until a font has been caught, and
     * after that it is not used at all.
     */
    Text::Measure gameMeasure = nullptr;
    int gameSpace = 0;

    /**@brief the value of `<key>=` on a descriptor line, or -1 if it is not there*/
    int valueOf(const std::string& line, const char* key) {
        const size_t at = line.find(key);
        if (at == std::string::npos) {
            return -1;
        }
        return atoi(line.c_str() + at + strlen(key));
    }
}

void Text::useGameMeasure(Measure measure) {
    gameMeasure = measure;
    // A space is the unit padding is built from, so it is taken once here rather than
    // measured through the game on every pad.
    gameSpace = measure == nullptr ? 0 : measure(" ", 1);
    if (measure != nullptr && gameSpace <= 0) {
        // Without a space there is nothing to pad with, so the descriptor stays in charge
        // rather than the table dividing by zero.
        WARNING_OUT(printf("Text::Font: the game measures a space as %d pixels, which "
            "cannot be padded with - staying on the descriptor\n", gameSpace));
        gameMeasure = nullptr;
        gameSpace = 0;
    }
}

Text::Font::Font() : space(ONE_UNIT), real(false), message("not loaded") {
    assumeMonospaced();
}

int Text::Font::spaceWidth() const {
    return gameMeasure != nullptr ? gameSpace : space;
}

void Text::Font::assumeMonospaced() {
    for (int i = 0; i < 256; ++i) {
        advance[i] = ONE_UNIT;
    }
    kerning.clear();
    space = ONE_UNIT;
    real = false;
}

bool Text::Font::load(const std::string& path) {
    std::ifstream file(path.c_str());
    if (!file) {
        return false;
    }

    // Everything starts at zero rather than at one unit: a glyph the descriptor does not
    // list is one the font cannot draw, and the game adds nothing for it.
    for (int i = 0; i < 256; ++i) {
        advance[i] = 0;
    }
    kerning.clear();

    int glyphs = 0;
    std::string line;
    while (std::getline(file, line)) {
        // "chars count=189" is not a glyph; "char " with the space is.
        if (line.compare(0, 5, "char ") == 0) {
            const int id = valueOf(line, "id=");
            const int width = valueOf(line, "xadvance=");
            if (id >= 0 && id <= 255 && width >= 0) {
                advance[id] = width;
                ++glyphs;
            }
            continue;
        }
        if (line.compare(0, 8, "kerning ") == 0) {
            const int first = valueOf(line, "first=");
            const int second = valueOf(line, "second=");
            const int amount = valueOf(line, "amount=");
            // amount is nearly always negative, so it cannot be told from "missing" by
            // its sign; a pair is taken only when both of its characters parsed.
            if (first >= 0 && first <= 255 && second >= 0 && second <= 255
                && line.find("amount=") != std::string::npos) {
                kerning[(static_cast<unsigned>(first) << 8) | static_cast<unsigned>(second)]
                    = amount;
            }
        }
    }

    if (glyphs == 0 || advance[' '] <= 0) {
        // A descriptor with no space in it cannot be padded with one, which is the only
        // thing this is for.
        assumeMonospaced();
        return false;
    }

    space = advance[' '];
    real = true;
    return true;
}

const Text::Font& Text::Font::toolTip() {
    static Font font;
    static bool resolved = false;
    if (resolved) {
        return font;
    }
    resolved = true;

    // The game's own order, highest first: the mod overrides the expansion, which
    // overrides the base game. The DLL sits in the mod's script folder, so the mod's root
    // is one level up from it.
    static std::string chosen;
    std::string places[3];
    places[0] = Overlay::directory() + "..\\" + TOOLTIP_FONT;
    places[1] = Overlay::gameDirectory() + "tfh\\" + TOOLTIP_FONT;
    places[2] = Overlay::gameDirectory() + TOOLTIP_FONT;

    for (int i = 0; i < 3; ++i) {
        if (font.load(places[i])) {
            chosen = places[i];
            font.message = chosen.c_str();
            INFO_OUT(printf("Text::Font: the first tooltip will be measured from %s - a "
                "space is %d pixels, %u kerning pairs\n", chosen.c_str(), font.space,
                static_cast<unsigned>(font.kerning.size())));
            return font;
        }
    }

    font.message = "Arial14.fnt was not found; columns line up by character count";
    WARNING_OUT(printf("Text::Font: %s\n", font.message));
    return font;
}

int Text::Font::kerningBetween(unsigned char first, unsigned char second) const {
    const std::map<unsigned, int>::const_iterator found =
        kerning.find((static_cast<unsigned>(first) << 8) | static_cast<unsigned>(second));
    return found == kerning.end() ? 0 : found->second;
}

int Text::Font::width(const char* text, size_t length) const {
    if (text == nullptr) {
        return 0;
    }
    if (gameMeasure != nullptr) {
        // The game's own, which is the whole point of having it: no assumption about
        // which font, and the escapes and icons handled by the code that draws them.
        return gameMeasure(text, static_cast<int>(length));
    }

    // A newline ends a line rather than the string, and the width is the widest of them -
    // which is what the game returns, so a cell that somehow held one measures the same
    // here as it draws.
    int widest = 0;
    int line = 0;
    for (size_t i = 0; i < length; ++i) {
        const unsigned char glyph = static_cast<unsigned char>(text[i]);
        if (glyph == ESCAPE) {
            // The escape and the character it selects with; a trailing escape with
            // nothing after it is simply dropped.
            ++i;
            continue;
        }
        if (glyph == '\n') {
            if (line > widest) {
                widest = line;
            }
            line = 0;
            continue;
        }
        line += advance[glyph];
        // The partner is the next byte as it stands, escape or not. That is the game's
        // own rule, and matching it matters more than tidying it.
        if (i + 1 < length) {
            line += kerningBetween(glyph, static_cast<unsigned char>(text[i + 1]));
        }
    }
    return line > widest ? line : widest;
}

int Text::Font::width(const std::string& text) const {
    return width(text.c_str(), text.size());
}

Text::Table::Table(const Font& metrics)
    : font(&metrics), columnGap(metrics.spaceWidth() * 2) {
}

Text::Table& Text::Table::gap(int pixels) {
    columnGap = pixels < 0 ? 0 : pixels;
    return *this;
}

Text::Table& Text::Table::indent(const char* text) {
    prefix = text == nullptr ? "" : text;
    return *this;
}

Text::Table& Text::Table::align(size_t column, Align how) {
    if (alignments.size() <= column) {
        alignments.resize(column + 1, LEFT);
    }
    alignments[column] = how;
    return *this;
}

Text::Table& Text::Table::cell(const char* text) {
    building.push_back(text == nullptr ? "" : text);
    return *this;
}

Text::Table& Text::Table::cell(const std::string& text) {
    building.push_back(text);
    return *this;
}

Text::Table& Text::Table::row() {
    rows.push_back(building);
    building.clear();
    return *this;
}

bool Text::Table::empty() const {
    return rows.empty() && building.empty();
}

int Text::Table::widthOf(const std::string& cell) const {
    return font->width(cell);
}

int Text::Table::pad(std::string& line, int from, int to, bool anySpace) const {
    int spaces = 0;
    if (to > from) {
        const int step = font->spaceWidth();
        // Nearest rather than fewest: half a space of overshoot reads better than a
        // column that is always a little short of where it was asked for.
        spaces = (to - from + step / 2) / step;
    }
    if (anySpace && spaces < 1) {
        spaces = 1;
    }
    line.append(static_cast<size_t>(spaces), ' ');
    return from + spaces * font->spaceWidth();
}

std::string Text::Table::text() const {
    // A row still being built is rendered rather than dropped; forgetting the last row()
    // should cost nothing.
    std::vector<std::vector<std::string> > all = rows;
    if (!building.empty()) {
        all.push_back(building);
    }
    if (all.empty()) {
        return std::string();
    }

    size_t columns = 0;
    for (size_t r = 0; r < all.size(); ++r) {
        if (all[r].size() > columns) {
            columns = all[r].size();
        }
    }

    std::vector<int> widths(columns, 0);
    for (size_t r = 0; r < all.size(); ++r) {
        for (size_t c = 0; c < all[r].size(); ++c) {
            const int width = widthOf(all[r][c]);
            if (width > widths[c]) {
                widths[c] = width;
            }
        }
    }

    // Where each column is meant to begin, measured from the start of the line.
    std::vector<int> starts(columns, 0);
    int at = font->width(prefix);
    for (size_t c = 0; c < columns; ++c) {
        starts[c] = at;
        at += widths[c] + columnGap;
    }

    std::string out;
    for (size_t r = 0; r < all.size(); ++r) {
        if (r != 0) {
            out += '\n';
        }
        const std::vector<std::string>& cells = all[r];
        if (cells.empty()) {
            continue;
        }

        std::string line = prefix;
        int x = font->width(prefix);
        for (size_t c = 0; c < cells.size(); ++c) {
            const int cellWidth = widthOf(cells[c]);
            const Align how = c < alignments.size() ? alignments[c] : LEFT;
            int target = starts[c];
            if (how == RIGHT) {
                target += widths[c] - cellWidth;
            }
            // Two cells must never run together, so every column past the first gets at
            // least one space even where rounding would have given none.
            x = pad(line, x, target, c != 0);
            line += cells[c];
            x += cellWidth;
        }
        out += line;
    }
    return out;
}
