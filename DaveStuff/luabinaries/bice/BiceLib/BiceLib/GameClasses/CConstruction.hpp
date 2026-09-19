#pragma once
#include <cstdint>

/**
 * CConstruction - one item in a country's production queue, and the base of the three kinds.
 *
 * `CMilitaryConstruction`, `CBuildingConstruction` and `CConvoyConstruction` all derive from
 * it at offset 0. **CConstruction has no virtual table of its own** - it is abstract, so RTTI
 * records no table for it and the family pass over CPersistent's slots never sees it. Each
 * derived class has its own `LoadKey` and calls **`CConstruction::LoadKey` (`0x83200`)** for
 * the keys below; that function had no name and was not even a function in the program until
 * this pass.
 *
 * A `military_construction=` block in a save carries the base's keys first:
 *
 *     military_construction={ id={...} size=1 cost=2.588 duration=118.000 progress=104.161
 *                             status=1.000 country="GER" builder="GER" unit={...}
 *                             manpower=0.100 multi_role={ id name model }
 *                             accumulated_experiance=26.038 accumulated_progress=0.794 }
 *
 * **Read live**: 831 military, 89 building and 68 convoy items in a 1942 game.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CConstruction {
    namespace Offsets {
        /**@brief the item's object id, saved as `id`; type first in memory, second in the
           save*/
        constexpr uintptr_t id_type = 0x8;
        constexpr uintptr_t id = 0xC;

        constexpr uintptr_t cost = 0x30;       // x1000, saved as `cost`
        constexpr uintptr_t duration = 0x34;   // x1000, saved as `duration`
        constexpr uintptr_t progress = 0x38;   // x1000, saved as `progress`

        /**@brief saved as `status`, x1000. **Read live**: 1.0 on most items and 0 on the
           rest, with a handful in between - it looks like a fraction, not a flag. **A
           CConvoyConstruction does not use this**: it keeps its own `status` byte at +0x58*/
        constexpr uintptr_t status = 0x3C;

        constexpr uintptr_t size = 0x40;       // saved as `size`; 1 on almost everything

        /**@brief where it is being built, a CMapProvince*, saved as `location`. **Read
           live**: a CMapProvince on all 89 building items and null on military and convoy
           ones, which are not placed*/
        constexpr uintptr_t location = 0x44;

        /**@brief who it is for, a CCountryTag, saved as `country`*/
        constexpr uintptr_t country = 0x48;

        /**@brief who is building it, a CCountryTag, saved as `builder`. **Read live**: the
           same as `country` on every military item, and the no-country tag `---` on every
           building and convoy one*/
        constexpr uintptr_t builder = 0x50;
    }

    namespace GameFunction {
        /**@brief the shared loader all three kinds fall back to*/
        constexpr uintptr_t LoadKey = 0x83200;
    }
}

/**
 * CMilitaryConstruction - a division or wing being built.
 *
 * **Its block is keyed by unit type.** Anything its loader does not recognise it looks up in
 * the sub unit database, and a key that names a type becomes a CBrigadeConstructionDefinition
 * on the `brigades` list - which is why a queued division reads
 * `multi_role={ id=... name=... model={...} }`. **Read live**: 1 brigade on 536 of the 831
 * items and 6 or 7 on most of the rest.
 */
namespace CMilitaryConstruction {
    namespace Offsets {
        /**@brief the unit being built, an object id, saved as `unit`*/
        constexpr uintptr_t unit_type = 0x58;
        constexpr uintptr_t unit_id = 0x5C;

        /**@brief the name it will be given, a std::string, saved as `name`*/
        constexpr uintptr_t name = 0x60;

        /**@brief the brigades, a CList of CBrigadeConstructionDefinition*, one per unit type
           line in the block*/
        constexpr uintptr_t brigades_first = 0x7C;
        constexpr uintptr_t brigades_last = 0x80;
        constexpr uintptr_t brigades_count = 0x84;

        /**@brief a byte, saved as `is_reserve`; what fills `reserves_factor`. **Read live**:
           set on 43 of 831 items*/
        constexpr uintptr_t is_reserve = 0x8C;

        /**@brief what the item is aimed at, an object id, saved as `target`*/
        constexpr uintptr_t target_type = 0x90;
        constexpr uintptr_t target_id = 0x94;

        /**@brief x1000, saved as `manpower`*/
        constexpr uintptr_t manpower = 0x98;

        /**
         * **1000 plus the owner's RESERVES_PENALTY_SIZE modifier where `is_reserve` is set**,
         * 1000 otherwise, filled at `0x84A3A` and `0x85211` and then kept rather than looked
         * up again - so an item keeps the factor it was given.
         *
         * **It is saved as `factor`**, which is what settles that: the number travels with
         * the item through a save rather than being recomputed on load. **Read live**: 1000
         * on 788 items, 800 on 27 and 900 on 8, so the penalty is negative and differs by
         * country.
         */
        constexpr uintptr_t reserves_factor = 0x9C;

        /**@brief x1000, saved as `accumulated_experiance` - the game's own spelling*/
        constexpr uintptr_t accumulated_experience = 0xA4;

        /**@brief x1000, saved as `accumulated_progress`*/
        constexpr uintptr_t accumulated_progress = 0xA8;
    }

    namespace VFTable {
        constexpr uintptr_t CMilitaryConstruction = 0x11BDC34;  // 21 slots
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x843F0;
        constexpr uintptr_t LoadKey = 0x840C0;
        constexpr uintptr_t AfterLoad = 0x848A0;
    }
}

/**@brief CBuildingConstruction - a building being put up in a province*/
namespace CBuildingConstruction {
    namespace Offsets {
        /**@brief which building, a CBuilding*, saved as `building` by its index into the
           building database. **Read live**: a CBuilding on all 89*/
        constexpr uintptr_t building = 0x58;

        /**@brief saved as `count`. **Read live**: zero on all 89*/
        constexpr uintptr_t count = 0x5C;
    }

    namespace VFTable {
        constexpr uintptr_t CBuildingConstruction = 0x11BDCD4;
    }
}

/**@brief CConvoyConstruction - convoys or escorts being built*/
namespace CConvoyConstruction {
    namespace Offsets {
        /**@brief a byte, and **its own `status` key rather than CConstruction's at +0x3C**:
           the loader takes the key before the base sees it and sets this only where the
           value is `yes`. **Read live**: set on 20 of 68*/
        constexpr uintptr_t status = 0x58;
    }

    namespace VFTable {
        constexpr uintptr_t CConvoyConstruction = 0x11BDD34;
    }
}

/**
 * CBrigadeConstructionDefinition - one brigade inside a queued division, saved under the
 * unit type's own name.
 */
namespace CBrigadeConstructionDefinition {
    namespace Offsets {
        /**@brief a second string the name setter fills, through a lookup*/
        constexpr uintptr_t display_name = 0x8;

        /**@brief the brigade's object id, saved as `id`*/
        constexpr uintptr_t id_type = 0x10;
        constexpr uintptr_t id = 0x14;

        /**@brief the name, a std::string, saved as `name`. **Read live**: `IV/SG 136`,
           `IV./StG 410`, `II/KG 42 (leicht)`*/
        constexpr uintptr_t name = 0x18;

        /**@brief the unit type, a CSubUnitDefinition*, which is also the key the whole block
           is saved under. **Read live**: `multi_role`, `cas`, `light_bomber`*/
        constexpr uintptr_t type = 0x34;

        /**@brief x1000, saved as `experience`*/
        constexpr uintptr_t experience = 0x40;

        /**@brief the model numbers, saved as `model={ 6 2 1 1 ... }`; a vector of ints*/
        constexpr uintptr_t model = 0x44;
    }

    namespace VFTable {
        constexpr uintptr_t CBrigadeConstructionDefinition = 0x11BDC8C;
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x83080;
        constexpr uintptr_t LoadKey = 0x82DD0;
    }
}
