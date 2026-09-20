#pragma once
#include <cstdint>

/**
 * CHistoricalModel - one model of one unit type, as `historical_model = N` names it.
 *
 * **Its loader has no keys of its own.** `CHistoricalModel::LoadKey` (`0x1828D0`) takes
 * **every key as a technology's name**: it looks the name up in the technology database,
 * walks that technology's effects (`CTechnology::Offsets::effects`) for the one whose
 * `CSubUnitDefinition::Offsets::index` matches this model's own unit type, and applies it
 * (`0x111D90`). A name that is not a technology, or a technology with nothing for this
 * unit type, is logged against `model.cpp` with both names in the message.
 *
 * So a model is a **list of technologies a unit was built with**, and what it holds is
 * the result of applying them.
 *
 * **The mod declares them in `units/models`** - 683 files, **122,421 blocks** - and the
 * file says the same thing the loader does: a block is `<unit type>.<index> = { ... }`
 * and every key inside is a technology with a level:
 *
 *     interceptor.0 = { single_engine_fighter_design = 1 }
 *     interceptor.7 = { single_engine_fighter_design = 8 }
 *
 * `historical_model = 7` in an order of battle is that `.7`. Most of the files are named
 * for a country - `AFG_Aircraft.txt` - and none of them says so inside, so the tag at
 * `country` below must come from the file rather than from a key.
 *
 * ## Who holds them, and what they cost
 *
 * **A country holds one CHistoricalModelSet per unit type**, in the array at
 * `CCountry::Offsets::historical_models` (`+0x48`) indexed by
 * `CSubUnitDefinition::Offsets::type_index`. The set carries the country's tag, the
 * definition, and a vector of that type's models - and those vectors hold **every**
 * CHistoricalModel in the process:
 *
 *     108 countries  x  1643 unit types  x  14 models  =  2,484,216
 *
 * which is the exact live count. The 14 is `HISTORICAL_MODEL_MAX` from
 * `common/defines.lua`, lowered from 30 on 2026-08-22; walking these containers is what
 * turned "the count happens to factorise" into a structural fact, because a set's vector
 * is exactly that long whether the mod declared that many models or not. So **a unit
 * type costs about 72 KB of address space for every country in the game**, declared or
 * not, and the define is the only lever on it.
 *
 * At 2.48 million objects and 114 MB this is the single biggest block of unit data in the
 * process - `CSubUnitDefinition` is 60,487 objects and 34 MB. See the memory note in
 * reversing/ and `Gui/Pages/Debug/MemoryPage.cpp`.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CHistoricalModel {
    /**
     * **One unit type's models for one country**, the object a country's
     * `historical_models` array holds and the one PickBestModel takes in `ecx`. Its own
     * first three words are the model vector, which is why a set and a bare vector are
     * easy to confuse in a decompile. The name is BiceLib's - the game does not say.
     */
    namespace Set {
        constexpr uintptr_t SIZE = 0x1C;

        namespace Offsets {
            /**@brief the type's models in index order - begin, end, end of storage*/
            constexpr uintptr_t models = 0x0;
            constexpr uintptr_t models_end = 0x4;
            constexpr uintptr_t models_capacity = 0x8;

            /**@brief **the unit type**, and the same pointer every model in the vector
                      carries. **Read live**: 25 of 25, and its `type_index` is the slot
                      this set sits in*/
            constexpr uintptr_t definition = 0x10;

            /**@brief **whose models these are**, a CCountryTag by value. **Read live**:
                      the id half is the owning country's index on 1296 of 1296, and the
                      letters are the country's - GER, SWE*/
            constexpr uintptr_t country = 0x14;
        }
    }

    /**@brief 0x30 bytes: the gap between neighbours is 48 in 2.16 million of the pairs*/
    constexpr uintptr_t SIZE = 0x30;

    namespace Offsets {
        /**
         * A CCountryTag held by value, and **the null tag `---` with id 0 on all 20,000
         * sampled** - a model does not know its country. The tag that matters is on the
         * CHistoricalModelSet holding it, which is how the loader knows that
         * `AFG_Aircraft.txt` is Afghanistan's.
         */
        constexpr uintptr_t country = 0x8;

        /**@brief **the unit type this is a model of**, a CSubUnitDefinition - the same
                  pointer the holding set carries*/
        constexpr uintptr_t definition = 0x10;

        /**
         * **What this model was built with**: a vector of `CSubUnitTechnology`, the same
         * 12 byte {technology, level, progress} entries a regiment carries at
         * `CSubUnit +0x84`. That is what lets PickBestModel compare a model against a
         * regiment entry for entry.
         *
         * **Read live**: non-empty on 1677 of 4000 models, always a whole number of
         * entries, `progress` always zero, and in this mod every entry's level is the
         * model's own `index` - `interceptor.7` asks for level 7 of each of its 41
         * technologies.
         */
        constexpr uintptr_t technologies = 0x14;
        constexpr uintptr_t technologies_end = 0x18;
        constexpr uintptr_t technologies_capacity = 0x1C;

        /**
         * **Which model this is**, and what `historical_model = N` in an order of battle
         * picks by. **Read live**: every definition's models carry a small distinct
         * number, and the numbers an OOB file uses fall in that range.
         */
        constexpr uintptr_t index = 0x24;
    }

    namespace GameFunction {
        /**@brief slot 4: every key is a technology's name*/
        constexpr uintptr_t LoadKey = 0x1828D0;

        /**
         * **Which of a type's models a country would build.** Two arguments, and `ret 4`
         * settles that it is two rather than three:
         *
         * | | |
         * | --- | --- |
         * | `ecx` | the CHistoricalModelSet whose vector the models come from |
         * | `[esp+4]` | a CSubUnit, read only for its `technologies` list at `+0x84` |
         *
         * It scores every model and answers the lowest, starting from 999,999,000 and
         * answering null for an empty set:
         *
         *     score = sum over the model's technologies, where change is set, of
         *                 |the regiment's level - the level the model wants| * 1000
         *
         * **Only technologies whose `CTechnology::Offsets::change` is set count** - 789 of
         * 1175 in this mod - so the 386 that change nothing about a unit cannot pull a
         * model one way or the other.
         *
         * **`Patches::historicalModelLogicFix` changes this function**, which is where
         * the absolute value above comes from - see Patches.cpp.
         */
        constexpr uintptr_t PickBestModel = 0x183230;

        /**
         * **Builds the throwaway regiment PickBestModel is given.** From the set's
         * definition it news a CRegiment, a ship or an air unit, calls `CSubUnit::SetType`,
         * walks the definition's own technology vector (`+0x44..+0x48`) and writes each
         * one's researched level - straight out of
         * `CTechnologyStatus::Offsets::level_by_technology` for the country the set's tag
         * names - into the matching node of the new regiment's list, then calls
         * `CSubUnit::ApplyTechnologies`. One stack argument, `ret 4`.
         */
        constexpr uintptr_t MakeSubUnit = 0x183060;

        /**
         * **The model a country would build right now**: MakeSubUnit, PickBestModel, then
         * delete the regiment. Takes the set in `eax` and answers in `eax`, an LTCG
         * convention with no stack arguments at all.
         */
        constexpr uintptr_t PickCurrentModel = 0x1831F0;
    }

    namespace VFTable {
        constexpr uintptr_t CHistoricalModel = 0x11C52F8;   // module relative, RTTI, 6 slots
    }
}
