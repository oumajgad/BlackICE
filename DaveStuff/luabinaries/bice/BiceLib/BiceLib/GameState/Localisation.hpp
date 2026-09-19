#pragma once

#include <string>

/**
 * What the game's localisation says for a key - `PROV1234`, `KILL_LEADER_EFFECT`, any
 * key in any of the mod's `.csv` files.
 *
 * **The game's own lookup does not answer with text.** It answers with a *text object*:
 * the entry it found, plus the list of `$VARIABLE$` replacements to apply when the
 * thing is finally drawn. Reading those sixteen bytes as a string gives four bytes of
 * pointer and then rubbish, which is exactly what it looks like on screen. Getting text
 * out of it means rendering it, which is a second call that takes a sixteen byte colour
 * block from the settings by value and hands the result back in a register the compiler
 * chose. This does all of that.
 *
 * **What comes out is Windows-1252**, the game's own encoding, because the first thing
 * that wanted it hands it straight back to the game. Anything that draws it in ImGui or
 * passes it to Lua has to put it through `Text::toUtf8` first - see the note on
 * `HDS::readString`, which is the reading side and converts for you.
 *
 * **Ask while a game is running.** The lookup creates the database if it is not there
 * yet, so asking at the main menu before the files are read would answer nothing and
 * leave an empty entry behind.
 *
 * Addresses and how the object was worked out are in reversing/FINDINGS-effecttext.md.
 */
namespace Localisation {
    /**
    @brief the text for a key, or "" where the game has no entry for it

    A missing key costs the game an empty entry of its own making - that is what its own
    lookup does with one - so this is for keys that are expected to exist.
    */
    std::string text(const char* key);

    /**@brief the same, for a key built from a prefix and a number, like `PROV1234`*/
    std::string textForId(const char* prefix, int id);

    /**@brief whether the machinery is where this build expects it*/
    bool available();
}
