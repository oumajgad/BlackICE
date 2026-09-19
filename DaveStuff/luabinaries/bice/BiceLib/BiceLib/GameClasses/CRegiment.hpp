#pragma once
#include <cstdint>

/**
 * CRegiment - one regiment, brigade or ship inside a unit.
 *
 * The unit holds them in the list at CUnit::Offsets::regiments.
 *
 * **The layout is CSubUnit's**, the game's own base class: CRegiment, CShip and CWing all
 * derive from it at offset 0 and CRegiment and CWing do not override a single one of its
 * virtuals, so everything below holds for all three. That is why the order of battle has
 * always read air and naval sub units through these offsets without anything looking
 * wrong. CShip overrides the save path only to add its carrier wings, and uses two fields
 * past the end of a CRegiment.
 *
 * Everything here is named from what `CSubUnit::SaveContents` (`0x1A92A0`) writes and
 * `CSubUnit::LoadKey` (`0x1A8BF0`) reads back - see CPersistent.hpp for how that works -
 * and checked against a `regiment=` block in a save and against the running game.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CRegiment {
    namespace Offsets {
        /**
         * **The regiment's object id**, saved as `id = { id=... type=... }`. The type half
         * comes first in memory and second in the save.
         *
         * **Read live**: type 41 on the regiments a scenario started with and 4713 on the
         * ones the game has built since.
         */
        constexpr uintptr_t id_type = 0x08;
        constexpr uintptr_t id = 0x0C;

        /**
         * **What the regiment has left**, in the same scale as its definition's
         * max_strength: x10 on a land regiment, x1000 on an air or naval one, which
         * Oob::strengthOf() applies. Saved as `strength`.
         *
         * Read off the game (**read**): what a unit's supply consumption is scaled by
         * against `CSubUnitDefinition::max_strength` (`0x1BB6CB`), what a new regiment is
         * given when it is built, and what the unit's own average strength
         * (CUnit::Slots::AVERAGE_STRENGTH) is the average of.
         */
        constexpr uintptr_t strength = 0x5C;

        /**
         * **A ceiling rather than what it has**: set to the regiment's strength when it is
         * built and afterwards only ever raised to it, never lowered (**read**, the
         * builder at `0x484F7E`). CUnit's slot 24 adds this up over a unit's regiments
         * without averaging it. Saved as `highest`, which is the game's own name for it.
         *
         * BiceLib read this as the strength until 2026-09-16. For a regiment at full
         * strength the two are the same, which is why nothing looked wrong.
         */
        constexpr uintptr_t strength_ceiling = 0x30;

        /**@brief who built it, a CCountryTag, saved as `builder`; written only where its
           id half is set*/
        constexpr uintptr_t builder = 0x34;

        constexpr uintptr_t experience = 0x3C;   // x1000, saved as `experience`
        constexpr uintptr_t organisation = 0x60; // x1000
        constexpr uintptr_t name = 0x68;
        constexpr uintptr_t sub_unit_definition_ptr = 0x58;

        /**@brief where it was raised, a CMapProvince*, saved as `home` by writing that
           province's id; null on a regiment that was never given one*/
        constexpr uintptr_t home = 0x64;

        /**
         * **The technology levels this regiment was raised with**, a list of nodes: the
         * CTechnology at +0, the level at +4, how far it is towards the next level at +8
         * (x1000), the previous node at +0xC and the next at +0x10. The save writes one
         * line per node, keyed by the technology's own name -
         * `infantry_activation={5 0.000}` - and the loader looks the key up in the
         * technology database, which is what says these are technologies. **Read live**:
         * every node's first word is a CTechnology; none on a CWing, 9 to 52 on a
         * regiment, 43 on a destroyer, and about 3% of all nodes are part way to the next
         * level.
         *
         * `CSubUnit::SetType` (`0x1ABF30`) builds the list when the regiment is given its
         * definition, one node per entry of `CSubUnitDefinition::technologies`, all at
         * level zero.
         *
         * **This is what gives a regiment stats of its own.** `sub_unit_definition_ptr` is
         * not the shared type but a copy this regiment owns (**read live**: 4000
         * regiments, 4000 distinct definitions), and `CSubUnit::ApplyTechnologies`
         * (`0x1ABFC0`) rebuilds it:
         *
         *     definition = the type's template
         *                + sum over this list of (the technology's effect for this type
         *                                        x the level in the node)
         *
         * then clamps `strength` and `organisation` to the maxima that come out of it and
         * raises `strength_ceiling` to the strength. So **a regiment keeps the stats it was
         * raised with while its country's technology moves on**, and that is what `highest`
         * is a ceiling against. See CTechnology.hpp for what an effect is.
         */
        constexpr uintptr_t technologies = 0x84;
        constexpr uintptr_t technologies_last = 0x88;
        constexpr uintptr_t technologies_count = 0x8C;

        /**@brief what sank this ship, an object id like the one at +0x08, saved as
           `sunk_by`; written only where it is not the game's "no object" pair. **Read
           live**: set on 1123 of 3736 ships*/
        constexpr uintptr_t sunk_by_type = 0x9C;
        constexpr uintptr_t sunk_by_id = 0xA0;

        /**@brief in reserve, saved as `is_reserve`; `CRegiment::GetMaxStrength` scales the
           definition's max_strength by RESERVES_PENALTY_SIZE where it is set. **Read
           live**: 1184 of 4000 regiments*/
        constexpr uintptr_t is_reserve = 0xA4;

        /**@brief the pride of the fleet, saved as `pride`. **Read live**: 31 of 3736
           ships*/
        constexpr uintptr_t pride = 0xA5;

        /**@brief the CUnit this regiment belongs to

           How the game's per regiment supply and fuel functions reach the unit's order and
           the order of battle above it, rather than being passed either (**read**).*/
        constexpr uintptr_t unit_ptr = 0xB0;

        /**
         * **How far the regiment is from the enemy in its battle**, x1000, saved as
         * `current_distance`. The writer only writes it where the unit is fighting: the
         * guard is the list at `CUnit::Offsets::combats`. **Read live**: zero on all 4000
         * regiments, and every `current_distance` in a save is 0.000 as well.
         */
        constexpr uintptr_t current_distance = 0xC8;

        /**
         * **Every point here is another 1% of supply and fuel** for this regiment: the
         * consumption functions add `extra_consumption x 10` to a potency whose base is
         * 1000, then scale the definition's figure by it (**read**, `0x1BB7A0` and
         * `0x1AD300`). The 10 is a define at `0x168873C` whose name is not known and which
         * nine other places read for unrelated things; see `reversing/CLASSES.md`.
         *
         * A cached total: **the levels in the `technologies` list added up**, which
         * `CSubUnit::ApplyTechnologies` (`0x1ABFC0`) recomputes at the end of its walk.
         * **Read live**: it is that sum on all 10254 regiments, ships and wings in a
         * running game, without one exception. At 84 to 95 points on the regiments
         * measured that is close to double what the definition asks for, so it is not a
         * small correction.
         */
        constexpr uintptr_t extra_consumption = 0xCC;

        /**@brief which historical model it was raised as, saved as `historical_model`;
           -1 where it is none. **Read live**: -1 on 3940 of 4000 regiments*/
        constexpr uintptr_t historical_model = 0xD0;

        /**@brief CShip only, past the end of a CRegiment: the carrier's air wings, saved
           as `air`. A list whose nodes hold the wing at +0 and the next node at +8. **Read
           live**: 79 of 3736 ships have one, and what it holds is a CAir*/
        constexpr uintptr_t air = 0xDC;
    }

    /**@brief the whole object, from the allocation its builders make (`0x84D56`, **read**).
       A CShip is larger: it uses +0xD8 and +0xDC as well*/
    constexpr uintptr_t SIZE = 0xD8;

    namespace VFTable {
        constexpr uintptr_t CSubUnit = 0x11C79F4;  // module relative, RTTI, the base
        constexpr uintptr_t CRegiment = 0x11BDD7C;
        constexpr uintptr_t CShip = 0x11C7A74;
        constexpr uintptr_t CWing = 0x11BDDC4;
    }

    namespace GameFunction {
        // CSubUnit's, shared by CRegiment and CWing; CShip overrides the first two to add
        // its carrier wings and calls these for the rest.
        constexpr uintptr_t SaveContents = 0x1A92A0;      // slot 2
        constexpr uintptr_t LoadKey = 0x1A8BF0;           // slot 4
        constexpr uintptr_t AfterLoad = 0x1A9130;         // slot 5
        constexpr uintptr_t SetType = 0x1ABF30;           // builds the technologies list
        constexpr uintptr_t ApplyTechnologies = 0x1ABFC0; // and totals extra_consumption
    }
}
