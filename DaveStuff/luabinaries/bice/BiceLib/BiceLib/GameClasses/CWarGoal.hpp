#pragma once

#include <GameClasses/GameString.hpp>

/**
 * One war goal: who wants what from whom, and on what pretext.
 *
 * A war goal is what a country is fighting *for* - it is what the peace conference pays
 * out on and what the AI steers a war towards. The mod's own are declared in
 * `common/casus_belli.txt` and handed out by events; `barbarossa_war_goal` is one.
 *
 * **Read out of `CWarGoal::LoadKey` (`0x479A90`)**, whose five cases each store to a
 * fixed offset, and then checked against a running 1936 game. Of the 233 objects the
 * vftable scan finds, **5 name a real country** and 3 of those are the live goals -
 * `GER -> SOV` on `barbarossa_war_goal`, `JAP -> CHI` on `conquer`, `GER -> ENG` on
 * `uk_war_goal_2`. The rest are templates carrying the null tag `---` in all three
 * country slots, and two are junk the scan picked up rather than objects.
 *
 * ## A country slot is a tag and an index
 *
 * `country`, `actor` and `receiver` are each **eight bytes**: the four-character tag
 * first, then an index into the country database. An empty slot reads `---`, which is
 * why a live object shows `0x002d2d2d`. Read the tag with Text::fromTag; the index is
 * only meaningful against the database that issued it.
 */
namespace GameClasses {

    /**@brief a country as a war goal names one: the tag, then its database index*/
    struct CountryRef {
        char tag[4];        /**<@brief four characters, `---` when the slot is empty*/
        int index;          /**<@brief into the country database*/
    };

    /**@brief one war goal in progress*/
    struct CWarGoal {
        void* vftable;                  /**< 0x00 */
        int persistentId;               /**<@brief 0x04, 397 on every live one - a
                                            CPersistent field, not CWarGoal's own*/
        int unknown08;                  /**< 0x08, no key writes it */
        void* casusBelli;               /**<@brief 0x0C, a CCasusBelliType*; its name is
                                            the std::string at that object's +0x14*/
        CountryRef country;             /**<@brief 0x10, `---` even on the live goals*/
        CountryRef actor;               /**<@brief 0x18, who wants it*/
        CountryRef receiver;            /**<@brief 0x20, who is to give it up*/
        int region;                     /**<@brief 0x28, the region wanted, 0 when none*/
    };

    namespace WarGoal {
        const int VFTABLE_RVA = 0x11BDB34;
        const int LOAD_KEY = 0x79A90;

        /**@brief what each key of a save block writes*/
        namespace Offset {
            const int CASUS_BELLI = 0x0C;   /**< key `casus_belli`, token 0x2A5 */
            const int COUNTRY = 0x10;       /**< key `country`, token 0x24D */
            const int ACTOR = 0x18;         /**< key `actor`, token 0x2E9 */
            const int RECEIVER = 0x20;      /**< key `receiver`, token 0xC2 */
            const int REGION = 0x28;        /**< key `region`, token 0x414 */
        }
    }

    /**
     * The kind of pretext a war goal rests on, and the trigger that makes it available.
     *
     * Only partly read - the name and the trigger are certain, the three numbers before
     * the name are not.
     */
    struct CCasusBelliType {
        void* vftable;                  /**< 0x00 */
        int persistentId;               /**< 0x04, 397 */
        int index;                      /**<@brief 0x08, its place in the database*/
        int unknown0C;                  /**< 0x0C */
        int unknown10;                  /**< 0x10 */
        Hoi3CString name;               /**<@brief 0x14, `conquer`,
                                            `barbarossa_war_goal`, `uk_war_goal_2`*/
        // 0x30: a CAndTrigger, the condition under which this pretext may be used.
    };
}
