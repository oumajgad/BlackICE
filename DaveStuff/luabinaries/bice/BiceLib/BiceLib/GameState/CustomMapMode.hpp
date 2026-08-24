#pragma once

#include <cstdint>
#include <string>
#include <vector>

/**
 * A map mode of our own, painted by taking over the VP map mode.
 *
 * It shades provinces by the level of one building today; the name is deliberately
 * broader than that, because the hook it rests on decides the colour of every province
 * and could show anything a province knows.
 *
 * Nothing in the game's data is changed. The colour is replaced at the last moment,
 * after the game has worked out what it would have drawn, so turning this off gives
 * the VP map mode back exactly as it was.
 *
 * See reversing/FINDINGS-mapmode.md for how the colouring loop was found.
 */
namespace CustomMapMode {
    /**@brief the level that gets the brightest shade; the scale never moves*/
    constexpr int TOP_LEVEL = 10;

    struct Building
    {
        int index = 0;         // into the province's building array
        std::string name;      // the key, "air_base"
        std::string label;     // what the game calls it, "Air Base"
    };

    /**
    @brief every building the game knows, read off the definitions in the array

    Empty until a session is running. Read once and kept, because the set cannot
    change while the game is running.
    */
    const std::vector<Building>& buildings();

    /**@brief drops what buildings() cached, so the next call reads the game again*/
    void forget();

    /**@brief whether the VP map mode is currently painting this instead*/
    bool enabled();

    /**
    @brief turns the takeover on or off

    Turning it on installs the hook the first time. The map only changes when the game
    next rebuilds its colours, which is what switching map mode does.
    */
    void setEnabled(bool on);

    /**@brief which building is shown, as an index into buildings(); -1 for none*/
    int selected();
    void select(int buildingIndex);

    /**@brief the level in one province, 0 when it has none of that building*/
    int levelIn(uintptr_t province, int buildingIndex);

    /**
    @brief what the loop should read as this province's victory points

    Zero while the mode is on. That keeps every province on the branch for one with
    no victory points, so the game never gives it an owner colour and never runs its
    second colour conversion - which leaves one place where a colour is decided.
    */
    int victoryPointsFor(uintptr_t province);

    /**
    @brief the colour to draw a province, 0xAARRGGBB, or 0 to leave the game's alone

    Every province the map paints comes through here while the mode is on, so this is
    the whole of the appearance:

    - no building of the chosen kind: light grey
    - the player controls it: green, brighter the higher the level
    - somebody else controls it: green at the lowest shade, whatever the level

    Somebody else's level is not the player's business, so it is not shown; that the
    building is there at all is.

    @param province       the CMapProvince being painted
    @param viewingCountry the country whose map this is, which the loop carries in edi
    */
    uint32_t colourFor(uintptr_t province, int viewingCountry);

    /**@brief whether the hook is in place, so the page can say when it is not*/
    bool hooked();
    const char* status();
}
