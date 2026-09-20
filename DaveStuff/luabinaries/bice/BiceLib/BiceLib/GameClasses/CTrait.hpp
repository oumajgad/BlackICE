#pragma once
#include <cstdint>
#include <string>
#include <vector>

/**
 * CTrait - one leader trait, as the game holds it.
 *
 * **`common/traits.txt` and nothing else.** `gainable_traits.txt` is a different class,
 * `CGainableTrait` (RTTI, a CPersistent of six slots), whose grammar is a trait name and
 * the combat conditions for earning it - `trait`, `combat`, `trigger`, `hours_required` -
 * none of which CTrait::LoadKey knows.
 *
 * The game builds one instance per trait the mod defines and hands leaders pointers to
 * them. They are definitions: made once while the mod loads and alive for the rest of
 * the process. The class name is from RTTI.
 *
 * They are kept in a list of their own, reached through a lazily made object at
 * GLOBAL_POINTER - see all(). BiceLib used to find them by scanning every committed
 * page for the vftable and sifting the hits with a magic number; reading the list
 * needs neither, and it is the game's own set rather than whatever a scan turned up.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTrait {
    /**
     * **What a trait does**, as `CTrait::LoadKey` (`0x1B2A50`) numbers them.
     *
     * The numbers are the loader's own: its jump table sets one per key and hands it to
     * `AddEffect`, which is what lands in `Offsets::effect_kinds`. They run 0 to 30 in
     * **exactly the order the mod's own `traits.txt` header lists them in** - that
     * comment is the engine's enum, written out by whoever wrote the file.
     *
     * The last three take a `type` as well as a value, and the engine insists on that
     * order: `terrain_speed = { type = plains value = 0.1 }`.
     */
    /**
     * **Checked against the running game**: the 343 traits `traits.txt` declares are the
     * 343 in memory beside the CNullTrait, and reading `german_tag` back gives
     * `offence_modifier 40, combined_arms_bonus 20, combat_move_speed 30,
     * experience_bonus 50, terrain_speed 30 plains, terrain_speed 30 highlands` - the
     * file's own six, in its own order, in thousandths.
     */
    enum class Effect {
        xp_gain = 0,
        surprise_chance = 1,
        supply_consumption = 2,
        defence_modifier = 3,
        offence_modifier = 4,
        combat_move_speed = 5,
        winter_attrition = 6,
        river_attack = 7,
        fort_attack = 8,
        combined_arms_bonus = 9,
        out_of_supply_modifier = 10,
        submarine_attack = 11,
        disengage_timer = 12,
        spread_out = 13,
        spotting_chance = 14,
        defender_softness = 15,
        strategic_attack = 16,
        naval_attack = 17,
        night_attack = 18,
        tactical_attack = 19,
        dissent_impact = 20,
        encirclement_bonus = 21,
        envelopment_bonus = 22,
        experience_bonus = 23,
        fort_defence = 24,
        amph_attack = 25,
        digin_bonus = 26,

        /**@brief known to the loader and **used by nothing in the mod** - an unused lever*/
        paradrop_mission = 27,

        // These three carry a terrain type beside their value.
        terrain_speed = 28,
        terrain_attack = 29,
        terrain_defence = 30,
    };

    /**@brief how many effects a trait can hold; the loader drops anything past this*/
    constexpr int MAX_EFFECTS = 16;

    namespace Offsets {
        /**
         * **A trait is a CModifier**, which occupies everything before the name (RTTI:
         * its only base, at offset 0). Whether a trait's effects ever reach that
         * modifier's value array has not been established - the loader puts them in the
         * three arrays below instead.
         */
        constexpr uintptr_t name = 0x2C;

        /**
         * **The effects**, three parallel arrays of MAX_EFFECTS and a count. The loader
         * appends to all three at once (`AddEffect`, `0x1B2A00`) and refuses past
         * sixteen, so the arrays end exactly where the count begins:
         * `0xE8 + 16 * 0x1C == 0x2A8`.
         */
        constexpr uintptr_t effect_values = 0x68;   // int[16], thousandths
        constexpr uintptr_t effect_kinds = 0xA8;    // int[16], an Effect above
        constexpr uintptr_t effect_types = 0xE8;    // Hoi3CString[16] with a stride of 0x1C
        constexpr uintptr_t effect_count = 0x2A8;

        /**
         * A string is `0x18` bytes and the stride is `0x1C`, so **four bytes go spare
         * after each one**. They are padding rather than a field: **read live**, they
         * hold fragments of the parser's own buffer - `"ds ="`, `"  pl"` - and are zero
         * only where the heap happened to be. Nothing writes them.
         */
        constexpr uintptr_t EFFECT_TYPE_STRIDE = 0x1C;

        /**
         * **Which leaders may hold it**, from `allowed_leader = { land sea air }`. All
         * three are set when the key is absent, which the loader does outright.
         */
        constexpr uintptr_t allowed_land = 0x2B0;
        constexpr uintptr_t allowed_sea = 0x2B1;
        constexpr uintptr_t allowed_air = 0x2B2;
    }

    namespace GameFunction {
        /**@brief slot 4 of CPersistent: the grammar of `traits.txt`*/
        constexpr uintptr_t LoadKey = 0x1B2A50;

        /**
        @brief appends one effect, `(this, kind in ecx, value, type)`

        Silently drops the seventeenth, which is worth knowing before writing a trait
        with more than sixteen effects in it.
        */
        constexpr uintptr_t AddEffect = 0x1B2A00;
    }

    namespace VFTable {
        constexpr uintptr_t CTrait = 0x11C7DC0;      // module relative
        constexpr uintptr_t CNullTrait = 0x11C7DFC;  // what sits at index 0 of the list
    }

    /**
     * The object holding every trait, made on first use by the getter at `0x1B4640`
     * and kept in this global. `0x1C` bytes.
     *
     * It is not filled until the mod's traits are loaded, so before that the list is
     * empty - which is what the deferral in bice.cpp is waiting for.
     */
    constexpr uintptr_t GLOBAL_POINTER = 0x16855EC;

    namespace DataBaseOffsets {
        /**@brief the number of entries, the same as (end - begin) / 4*/
        constexpr uintptr_t count = 0x00;

        /**
         * The traits themselves: begin and end, four byte elements.
         *
         * **Index 0 is a CNullTrait**, the way index 0 of a province's building array
         * is "nobuilding", so the entry there is not a CTrait and all() leaves it out.
         */
        constexpr uintptr_t traits_begin = 0x0C;
        constexpr uintptr_t traits_end = 0x10;
    }

    /**
     * A bound on the list, so a begin/end pair that is not one is refused rather than
     * walked. The mod defines a few hundred.
     */
    constexpr size_t MAX_TRAITS = 8192;

    /**
    @brief every trait, in the game's own order; empty until the mod's traits are loaded

    The CNullTrait at index 0 is left out, so everything answered here carries the
    CTrait vftable and its name can be read at Offsets::name.
    */
    std::vector<uintptr_t> all();

    /**@brief how many traits are loaded, 0 before they are*/
    size_t count();

    /**@brief the trait with this name, or 0*/
    uintptr_t findByName(const std::string& name);
}

/**
 * CGainableTrait - one line of `common/gainable_traits.txt`: a trait, and what earning it
 * takes.
 *
 * A definition like CTrait, made while the mod loads and never saved (slot 2 is the
 * shared empty one). The file's own block is `gainable_trait = { ... }` and the whole
 * grammar is the four keys below - `CGainableTrait::LoadKey` (`0x73800`) knows nothing
 * else, which is why none of the keys inside `trigger` reach it: the trigger loads
 * itself.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CGainableTrait {
    namespace Offsets {
        /**
         * **Which kind of combat earns it**, kept as the token itself rather than an
         * index: `land_combat` 723, `naval_combat` 724, `air_combat` 1312,
         * `ground_bombing` 1315, `land_bombing` 1316, `naval_bombing` 1317. Those six
         * are what BlackICE uses; the loader takes whatever token the file names.
         */
        constexpr uintptr_t combat = 0x8;

        /**@brief `hours_required`, the hours of such combat a leader needs*/
        constexpr uintptr_t hours_required = 0xC;

        /**
         * **The CTrait this earns**, resolved as the file is read rather than by name
         * later: the loader asks the trait database and, where the name is not one,
         * makes an entry for it.
         */
        constexpr uintptr_t trait = 0x10;

        /**@brief a CTrigger held by value, which loads itself from the `trigger` block*/
        constexpr uintptr_t trigger = 0x14;

        /**@brief set when a `trigger` block was read at all*/
        constexpr uintptr_t has_trigger = 0x54;
    }

    namespace GameFunction {
        constexpr uintptr_t LoadKey = 0x73800;
    }

    namespace VFTable {
        constexpr uintptr_t CGainableTrait = 0x11BD654;   // module relative, RTTI, 6 slots
    }
}

/**
 * CTraitGainTracker - how far along a leader is towards the gainable traits.
 *
 * **This one is saved** - it has a SaveContents of its own (`0x74710`) rather than the
 * shared empty one - so it is game state, not a definition. It keeps a std::map of trait
 * to hours: the save writes one key per trait, and `CTraitGainTracker::LoadKey`
 * (`0x74610`) takes any key that is not `duration` or `current` as a trait's name and
 * puts the value on that trait's entry.
 *
 * **A leader's history owns one**: `CLeaderHistory + 0x40` points at it (**read live**:
 * of 400 histories in a running game, 399 point at one with this vftable, and the one
 * that does not is the empty template). A leader reaches his own through
 * `CLeader::Offsets::history`.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTraitGainTracker {
    namespace Offsets {
        /**
         * **Trait to hours**, a std::map: a red-black tree whose nodes carry left,
         * parent and right, the colour and nil flag at `+0x14`, and the value at `+0x10`.
         * The save walks it in order.
         */
        constexpr uintptr_t hours_by_trait = 0xC;

        /**@brief saved as `duration`, read with `%i`*/
        constexpr uintptr_t duration = 0x1C;

        /**@brief saved as `current`, read the same way*/
        constexpr uintptr_t current = 0x20;
    }

    namespace GameFunction {
        constexpr uintptr_t LoadKey = 0x74610;
        constexpr uintptr_t SaveContents = 0x74710;
    }

    namespace VFTable {
        constexpr uintptr_t CTraitGainTracker = 0x11BD638;   // module relative, RTTI, 6 slots
    }
}
