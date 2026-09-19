#pragma once
#include <cstdint>
#include <lua.hpp>

/**
 * A province holds several objects by value - its goods pools, its modifier, its weather
 * and the tags of its owner and controller. For those the offset here is where the
 * object starts, and what is inside it is a second offset from that object's header.
 */
namespace CMapProvince {
    namespace Offsets {
        // No terrain offset here: the CTerrain is at +0xC of the province's template,
        // path_node_ptr below. reversing/FINDINGS-mapmode.md covers it.

        /**
         * **The province's local modifiers**, a CProvinceModifier held by value: one
         * value per CModifier::ModifierType, behind the pointer at
         * CModifier::Offsets::values. The province's constructor builds it in place
         * (`0x94848`: CModifier's constructor on `province + 0xFC`, then the
         * CProvinceModifier vftable). These change what a province produces -
         * `LOCAL_IC`, `LOCAL_METAL` and the rest - and are not what it has.
         */
        constexpr uintptr_t modifier = 0xFC;

        /**
         * **Everything the save writes out of a province**, named from the key
         * `CProvince::SaveContents` (`0x95020`) writes each one under and `CProvince::LoadKey`
         * (`0x95880`) reads it back into. The two agree with what was already here -
         * `weather` at `+0x68`, `pool` at `+0x15C`, `current_producing` and `max_producing`,
         * both throughput pointers and both drawn pointers all carry the name the save
         * gives them.
         */
        constexpr uintptr_t strategic_resource = 0x18;    // saved as "strategic_resource"
        constexpr uintptr_t last_convoy_attack = 0x1C;    // a date; only saved once it is set
        constexpr uintptr_t out_of_supply_days = 0x20;    // only saved above zero
        constexpr uintptr_t nationalism = 0x24;
        constexpr uintptr_t flags = 0xC4;                 // a CPersistent of its own
        constexpr uintptr_t history = 0xD8;               // a CPersistent; +0xEC is its count
        constexpr uintptr_t history_count = 0xEC;

        /**
         * The province's active modifiers, a linked list: head here, tail at `+0x140` and
         * the count at `+0x144`. One `modifier` key per node. Not the same thing as
         * `modifier` at `+0xFC`, which is the CProvinceModifier held by value.
         */
        constexpr uintptr_t modifiers = 0x13C;
        constexpr uintptr_t modifiers_last = 0x140;
        constexpr uintptr_t modifiers_count = 0x144;

        /**@brief the countries holding a core here, a linked list; one `core` key per node*/
        constexpr uintptr_t cores = 0x344;

        /**@brief a CCountryTag: who owns the underground here. Saved as `underground_owner`*/
        constexpr uintptr_t underground_owner = 0x38C;

        /**@brief the buildings, a pointer to an array of CProvinceBuilding*, see there*/
        constexpr uintptr_t CProvinceBuilding_array_ptr = 0x310;

        constexpr uintptr_t id = 0xD0;

        /**
         * The province's CProvinceTemplate: the map's fixed description of it, holding
         * its edges to its neighbours (see CPathFind::GraphOffsets) and its terrain.
         * The daily supply pass walks the same edges, and skips a province whose
         * template has a zero byte at +0x13D; that byte has only been seen as 1, and
         * what it means is not known.
         */
        constexpr uintptr_t path_node_ptr = 0xD4;
        constexpr uintptr_t victory_points = 0x34;

        /**
         * **The supply depot the province draws from**, as a province id, and **how many
         * steps away it is**. A depot is its own depot at distance 0; a province cut off
         * from every depot has distance 100000. The daily supply pass only lets a
         * province take from a neighbour with the same depot and a smaller distance.
         */
        constexpr uintptr_t supply_depot_id = 0x48;
        constexpr uintptr_t supply_depot_distance = 0x4C;

        /**@brief a CWeather, embedded; the province writer saves it under `weather`*/
        constexpr uintptr_t weather = 0x68;

        /**
         * What each country knows about this province: a pointer to one byte per
         * country, and how many of them there are.
         *
         * Index it by the country's id, the one a CCountryTag holds and the same one
         * the map is drawn for. Check the count first - it is the number of
         * countries in the game, 108 in BlackICE, and a country index past it means
         * there is nothing to read.
         *
         * The values that occur in a running game are 0 for somewhere never seen, 3
         * for partial intel, and 9 for a province the country owns.
         *
         * Two thresholds matter, both the game's own: at two or more a province counts
         * as seen and is painted at full brightness rather than dimmed, and at six or
         * more the province window shows what is built there. The first is read out of
         * the colouring loop; the second comes from observing the game.
         *
         */
        constexpr uintptr_t intel_by_country_ptr = 0x370;
        constexpr uintptr_t intel_country_count = 0x374;

        /*
         * **The nine goods pools every province carries**, each a CGoodsPool embedded in
         * the province.
         * 
         * These are where the pools start. A good within one is a second offset, from
         * CGoodsPool::Goods: the supplies in the province are at
         * `pool + CGoodsPool::Goods::supplies`.
         *
         * Seven of them are saved, and the save names them: the province writer
         * (`0x95020`, CProvince slot 2) writes each under its key, and skips any pool
         * that is all zero - which is why a save's province block has some and not others.
         * Two are working state, rebuilt every day and never saved.
         *
         * Most of what they mean comes from **the daily supply pass**, `0x2872D0`. It runs
         * once a day over every province, in the order of
         * CCurrentGameState::Offsets::provinces_by_supply_order - farthest from the depot
         * first - and for each one:
         *
         *   1. works out what the units there need, and how far the pool falls short of
         *      `SUPPLYPOOL_DAYS` of that (the define, read from CDefines + 0xAC, + 0x3C)
         *   2. asks for the shortfall: adds it to its own `drawn`, then takes it from the
         *      neighbours one step closer to the depot, as much as each can give
         *   3. passes whatever it could not get on to those neighbours' `drawn`, so they
         *      ask for it in turn when their own go comes
         *   4. records its pool as it now stands in `last_pool`
         *
         * A good taken from a neighbour counts on that neighbour as both drawn and
         * throughput, so the gap between the two is demand it could not meet.
         *
         * The pass's per province figures come in as four arrays by province id, which its
         * caller fills just before and throws away after, so nothing keeps them:
         *
         *   capacity      `0x9DD00`, __stdcall(province, int* out): how much a province
         *                 can pass on in a day. A single pull from it is capped at this,
         *                 and demand passed on to it is only accepted up to it. Worked
         *                 out from the local modifiers (`modifier`: `INFRASTRUCTURE`,
         *                 scaled by `LOCAL_INFRASTRUCTURE` and `GLOBAL_INFRASTRUCTURE`,
         *                 which is where the offsets +0x60, +0x68 and +0x70 it reads
         *                 fall), two defines (CDefines + 0xAC, + 0x220 and
         *                 + 0x224), and the controller's modifiers; unlimited where the
         *                 byte at `capital` is set. It only reads.
         *   supply need   `0x9E020`
         *   loss          `0x9DE80`, what is lost per step on the way
         *   fuel need     filled in the same loop, not traced
         *
         * Only the capacity function has been read through; the other two are named by
         * the argument they fill.
         */

        /**
         * **What is physically in the province**, save key `pool`: supplies and fuel
         * where there are depots and units, resources where they wait for a convoy.
         *
         * **In the capital it is the country's national stockpile**: `CCountry:GetPool()`
         * (`0xF4DE0`) answers `&capital->pool`, unless the country is a government in
         * exile (CCountry::Offsets::is_government_in_exile), when it answers a pool held
         * on the country instead.
         */
        constexpr uintptr_t pool = 0x15C;

        /**
         * The pool as it stood when the daily pass last finished with the province. Not
         * saved. Step 2 caps what a province further from the depot may take from this
         * one at this figure, so a day's outflow is limited by what was there at the last
         * pass rather than by what has arrived since. It can go negative.
         */
        constexpr uintptr_t last_pool = 0x180;

        /**
         * **Double buffered: read these through the pointers, never by offset.**
         *
         * `drawn` and `throughput` each have two pools, and two pointers that say which
         * is today's. At the start of the day the pass swaps each pair, so the pool that
         * held today's figures becomes `last_` unchanged, and the other is zeroed and
         * filled afresh. Neither changes during the rest of the day.
         *
         * `drawn` is what was asked of the province: its own shortfall plus what
         * provinces further from the depot passed on to it (steps 2 and 3). Supplies and
         * fuel only.
         *
         * `throughput` is what moved on through it. Something besides the pass adds to it
         * shortly after, which is how it can exceed `drawn`: resources on their way to the
         * capital along a connected network, including the capital itself, where the whole
         * day's resource income lands; and supplies and fuel arriving at depots that are
         * not the capital, presumably by convoy. That code is not traced.
         *
         * A network cut off from its capital never carries resources: its production
         * waits in a port for a convoy - see CConvoy.
         */
        constexpr uintptr_t last_drawn_ptr = 0x1A4;        // -> one of the two below, save key `last_drawn`
        constexpr uintptr_t drawn_ptr = 0x1A8;             // save key `drawn`
        constexpr uintptr_t drawn_buffer_a = 0x1AC;
        constexpr uintptr_t drawn_buffer_b = 0x1D0;

        constexpr uintptr_t last_throughput_ptr = 0x1F4;   // save key `last_throughput`
        constexpr uintptr_t throughput_ptr = 0x1F8;        // save key `throughput`
        constexpr uintptr_t throughput_buffer_a = 0x1FC;
        constexpr uintptr_t throughput_buffer_b = 0x220;

        /**
         * **What the units in the province need today**, supplies and fuel only. Not
         * saved: the pass zeroes it and writes it first thing (step 1). A need under one
         * unit is rounded up to one where the pool holds less than five. The name is
         * inferred from how the pass uses it, not taken from the game.
         */
        constexpr uintptr_t need = 0x244;

        /**
         * **What the province yields now**, save key `current_producing`: crude oil,
         * metal, energy and rare materials, before national modifiers.
         *
         * It recovers towards `max_producing` by a fixed step a day where it has been cut
         * back; what cuts it is not known.
         *
         * **Read the supply and fuel slots as zero.** They are only non-zero during the
         * midnight processing, when something puts a local source there for the pass to
         * read (`+0x270`, against the day's need); not traced.
         */
        constexpr uintptr_t current_producing = 0x268;

        /**
         * **What it could yield**, save key `max_producing`: the ceiling
         * `current_producing` recovers towards.
         */
        constexpr uintptr_t max_producing = 0x28C;

        /**
         * A byte, and **the game saves it as `capital`** - `CProvince::SaveContents` writes
         * the key and `CProvince::LoadKey` sets this from a `yes`. So this is a capital
         * province, which is what decides it; BiceLib had it as
         * `unlimited_supply_capacity`, named for its one known effect - while it is set,
         * the game's supply capacity for the province (see the pools above) is unlimited.
         */
        constexpr uintptr_t capital = 0x2B0;

        constexpr uintptr_t manpower = 0x320;
        constexpr uintptr_t leadership = 0x324;

        /**
         * **The units standing in the province**, a CUnitList (HDS::ListOffsets) - the
         * address the game's `CProvince::GetUnits` answers, with `GetNumberOfUnits` reading
         * its count. The enemy strength counters walk it; BiceLib does not.
         */
        constexpr uintptr_t units = 0x2B8;

        /**@brief CCountryTags, the game's `CProvince::GetOwner` and `GetController`*/
        constexpr uintptr_t owner = 0x32C;
        constexpr uintptr_t controller = 0x334;
    }

    /**
     * **Two vftables, and the one named CMapProvince is the second.**
     *
     * CMapProvince derives from CProvince and carries a table at object +0x0 and another
     * at +0x8, for a base subobject. `CMapProvince` below is the +0x8 one - which is what
     * its only user, the selection in bice.cpp, reads, since the selection holds its
     * pointer to that subobject rather than to the start of the province.
     *
     * So checking **the first dword of a province pointer** against it never matches.
     * Everything that hands out a whole province - the game state's array, the map's -
     * points at the start, where the table is `Primary`. That mismatch looked for a
     * moment like the map's province array held something other than provinces.
     *
     * Both from RTTI, and the primary confirmed live against the arrays.
     */
    namespace VFTable {
        constexpr uintptr_t CMapProvince = 0x11BEC1C;   // module relative, at object +0x8
        constexpr uintptr_t Primary = 0x11BEBF8;        // module relative, at object +0x0
    }

    // Every province by id is CCurrentGameState::Offsets::provinces_begin - a vector, read
    // through CCurrentGameState::province() so nothing walks past its end.

    struct CMapProvince
    {
        uintptr_t modifier;
        uintptr_t CProvinceBuilding_array_ptr;
        int id;
        int supply_pool;
        int fuel_pool;
        int oil;
        int metal;
        int energy;
        int rares;
        int manpower;
        int leadership;
        //char* owner_tag;
        //int owner_id;
        //char* controller_tag;
        //int controller_id;
    };

    CMapProvince Make(uintptr_t addr);
    CMapProvince GetMapProvinceById(int id);
    void PushCMapProvinceToStack(lua_State* L, CMapProvince province);

}