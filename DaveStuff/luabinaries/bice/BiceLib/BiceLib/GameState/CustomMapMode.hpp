#pragma once

#include <cstdint>
#include <string>
#include <vector>

/**
 * A map mode added by BiceLib, painted by taking over the VP map mode.
 *
 * It shades provinces by one thing a province has: the level of a building, or the
 * amount of a resource. The hook it rests on decides the colour of every province, so
 * anything a province knows can be shown - adding a kind of source is a list and a way
 * of reading one value, and everything from there to the colour is shared.
 *
 * Nothing in the game's data is changed. The colour is replaced at the last moment,
 * after the game has worked out what it would have drawn, so turning this off gives
 * the VP map mode back exactly as it was.
 *
 * See reversing/FINDINGS-mapmode.md for how the colouring loop was found.
 */
namespace CustomMapMode {
    /**@brief how many shades a value is drawn in; the brightest is the top one*/
    constexpr int TOP_LEVEL = 10;

    /**@brief what a source reads: a building's level, or a resource's amount*/
    enum class Kind
    {
        Building,
        Resource,
    };

    /**@brief one thing the map can be shaded by*/
    struct Source
    {
        // Where the value is. For a building, its slot in the province's building
        // array; for a resource, the field's offset on the province.
        uintptr_t where = 0;
        std::string name;      // the key, "air_base" or "energy"
        std::string label;     // what the game calls it, "Air Base" or "Energy"
    };

    /**
    @brief every building the game knows, read off the definitions in the array

    Empty until a session is running. Read once and kept, because the set cannot
    change while the game is running.
    */
    const std::vector<Source>& buildings();

    /**@brief the resources a province holds; a fixed list, since they are fields on it*/
    const std::vector<Source>& resources();

    /**@brief buildings() or resources()*/
    const std::vector<Source>& sources(Kind kind);

    /**@brief drops what buildings() cached, so the next call reads the game again*/
    void forget();

    /**@brief whether the VP map mode is currently painting this instead*/
    bool enabled();

    /**
    @brief whether the mode has been switched on, whatever else is missing

    Not the same as enabled(), which is also false when nothing is chosen. A checkbox
    has to show what was clicked rather than what came of it, or ticking it with
    nothing selected looks like it did not take.
    */
    bool requested();

    /**
    @brief turns the takeover on or off

    Turning it on installs the hook the first time. The map only changes when the game
    next rebuilds its colours, which is what switching map mode does.
    */
    void setEnabled(bool on);

    /**
     * How much intel a province needs before its real value is shown.
     *
     * Below it a province is drawn at the lowest shade and a darker grey, so the map
     * never claims to know more about somewhere than the player does.
     *
     * Six is the game's own threshold for buildings: at six the province window shows
     * what is built there, and below six it does not. It is applied to resources as
     * well, which is an assumption - whether the game hides a foreign province's
     * resources the same way has not been checked.
     */
    constexpr int INTEL_FOR_REAL_LEVEL = 6;

    /**
     * Which colours the shades are drawn in.
     *
     * Green is a single hue, dark at shade 1 and bright at TOP_LEVEL. Heat runs red,
     * orange, yellow, green across the same range, so a low value reads as something
     * to deal with and a high one as plenty.
     */
    enum class Palette
    {
        Green,
        Heat,
    };

    /**@brief which ramp colourFor() draws with*/
    Palette palette();

    /**@brief changes the ramp and repaints, so the map follows at once*/
    void setPalette(Palette which);

    /**@brief which kind of source is being shown*/
    Kind kind();

    /**@brief which source is shown, as an index into sources(kind()); -1 for none*/
    int selected();

    /**
    @brief shows \p index of \p kind

    Each kind remembers its own selection, so switching from buildings to resources
    and back returns to the building that was shown.
    */
    void select(Kind kind, int index);

    /**@brief switches kind, keeping whatever was last chosen of that kind*/
    void showKind(Kind kind);

    /**
     * How a resource's amounts are folded onto TOP_LEVEL shades.
     *
     * **Logarithmically, between the 1st and the 99th percentile** of the provinces
     * that have any, with everything below the one in the bottom shade and everything
     * above the other in the top. Worked out from the game's own values each time a
     * resource is chosen, so it fits whatever the map actually holds.
     *
     * Chosen against the mod's province history rather than guessed:
     *
     * - **Linear to the largest** puts two thirds to three quarters of the provinces
     *   that have any in the bottom shade. A handful of big producers dwarf the rest -
     *   leadership has one province at 100 against a 99th percentile of 3.2.
     * - **An equal share in each shade** fails on ties. Amounts are mostly whole
     *   numbers, so the cuts land on the same value: energy's first three are all 1,
     *   which leaves a third of it in the bottom shade and two shades empty.
     * - **Log to the largest** has no empty shades but lets the one biggest producer
     *   stretch the top, crowding nearly everything into the middle.
     *
     * Log between the percentiles leaves no shade empty for any resource but oil, which
     * has only a hundred producers, and each shade starts at roughly 1.7 times the one
     * below it, so the legend reads as amounts rather than ranks. Starting at the 1st
     * percentile rather than the smallest changes nothing for the four raw materials
     * and fills the bottom shades for manpower and leadership, whose smallest amounts
     * are outliers of their own.
     */
    struct Scale
    {
        bool valid = false;
        int producing = 0;          // provinces with any at all

        // Raw values, as the province holds them. starts[0] is the 1st percentile and
        // starts[TOP_LEVEL - 1] the 99th; a value is in the highest shade whose start
        // it reaches.
        int starts[TOP_LEVEL] = {};
    };

    /**@brief the scale the selected resource is shaded on; invalid for a building*/
    const Scale& scale();

    /**
    @brief what one unit of a resource is, as the province holds it: thousandths

    Checked live: every province read holds exactly its history file's value times a
    thousand - metal 3 as 3000, energy 14 as 14000 - and the spread across all 14,000
    provinces matches the history files province for province. The shading does not
    depend on it, since the scale is built from the values themselves; the amounts the
    legend prints do.
    */
    constexpr int RESOURCE_SCALE = 1000;

    /**@brief the level in one province, 0 when it has none of that building*/
    int levelIn(uintptr_t province, int buildingIndex);

    /**@brief the selected source's value in \p province, raw; 0 or less when it has none*/
    int valueIn(uintptr_t province);

    /**@brief which shade, 1 to TOP_LEVEL, a value of the selected source is drawn in*/
    int shadeFor(int value);

    /**
    @brief the colour of one shade in the current palette, 0xAARRGGBB

    What colourFor() paints with, and what the page's legend draws, so the two can
    never disagree.
    */
    uint32_t shadeColour(int shade);

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

    - none of the chosen source: light grey where the player can see it, darker where not
    - the player knows the province: the shade for its value
    - the player does not: the bottom shade, whatever the value

    Which ramp is drawn is palette().

    @param province       the CMapProvince being painted
    @param viewingCountry the country whose map this is, which the loop carries in edi
    */
    uint32_t colourFor(uintptr_t province, int viewingCountry);

    /**@brief whether the hook is in place, so the page can say when it is not*/
    bool hooked();
    const char* status();
}
