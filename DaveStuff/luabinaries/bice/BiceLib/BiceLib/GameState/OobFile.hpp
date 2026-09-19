#pragma once

#include <string>
#include <vector>

/**
 * What a `history/units` file would put on the map, read from the file itself.
 *
 * `load_oob = "GER/GER_Kriegsmarine_Creation.txt"` shows a player nothing but that
 * path, because **nothing about the file is in memory until the effect fires** - the
 * game opens it, spawns what is in it and forgets the file. So the only way to say
 * what an option is about to do is to read the file the same way the game will.
 *
 * What comes back is a count of the units by province, the leaders the file assigns,
 * and what it adds to the production queue. Who those leaders currently command is a
 * question about the running game, not about the file, so it is answered elsewhere.
 *
 * **Parsed once per path and kept.** A tooltip is rebuilt on every frame the mouse is
 * over it, and these files run to tens of thousands of lines.
 */
namespace OobFile {
    /**
     * A leader the file takes, and what it puts him on.
     *
     * The kind is the block he sits in - `division`, `corps`, `army`, `armygroup`,
     * `theatre`, `navy`, `air` - which is what says whether his rank suits the job.
     */
    struct Assignment
    {
        int leaderId = 0;
        std::string kind;
    };

    /**@brief one province, and how many of the file's units appear there*/
    struct Place
    {
        int provinceId = 0;
        std::string name;   // Windows-1252, as the localisation has it; "" if unnamed
        int units = 0;
    };

    struct Summary
    {
        /**@brief false where neither the mod nor the game has such a file*/
        bool found = false;

        /**
         * **Units**: every block that carries a `location` of its own - a theatre, an
         * army group, a corps, a division, a fleet, an air wing. Each one of those is
         * something that appears on the map, which is what a player wants counted.
         */
        int units = 0;

        /**
         * What is inside those units, counted apart because a file is usually one
         * kind: an army OOB has brigades, a naval one ships, an air one wings.
         */
        int brigades = 0;
        int ships = 0;
        int wings = 0;

        /**@brief `military_construction` entries, which go to the production queue*/
        int constructions = 0;

        /**@brief the provinces the units appear in, most first*/
        std::vector<Place> places;

        /**@brief the leaders the file assigns, in the order the file has them*/
        std::vector<Assignment> leaders;
    };

    /**
    @brief what the file at \p relativePath holds, parsed once and kept

    @param relativePath what the effect carries, relative to `history/units`, exactly
                        as `load_oob` writes it
    */
    const Summary& of(const std::string& relativePath);
}
