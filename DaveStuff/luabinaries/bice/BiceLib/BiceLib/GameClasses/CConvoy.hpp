#pragma once
#include <cstdint>

/**
 * CConvoy - one convoy route: a port it loads at, a port it unloads at, the goods it
 * carries and how much of them it last took.
 *
 * Base CReferenceObject, vftable from RTTI. Every convoy belongs to one country and is
 * reached through that country's list, CCountry::Offsets::convoys_list_first_ptr.
 * Convoys are created and removed as the game runs.
 *
 * **The saved fields are read out of the convoy's save writer**, `0xC5600`; the names
 * below are its keys. The unsaved ones were worked out by watching them change.
 *
 * **Three kinds, told apart by the goods mask:**
 *
 *   supplies and fuel                    supply convoys, home port to an overseas depot
 *   oil, metal, energy and rares         resource convoys, overseas port to home
 *   money and one good                   trade, presumably
 *
 * **Resource convoys.** A network cut off from its capital never moves its production
 * across the map. Each day's production is put in the pool of the port its resource
 * convoy loads at - not always the network's own depot - and waits there. A sailing
 * takes everything waiting; the load then reaches the capital and counts towards
 * CCountry::Offsets::daily_resource_income.
 *
 * With a transport every day, the port holds exactly one day's load. **Without one, the
 * stock piles up, and the next sailing takes the whole backlog.** For a port producing
 * 3.46 a day whose convoy has no transport for four days, the port holds 6.92, 10.38,
 * 13.84, 17.3; when a transport comes, `daily` reads 17.3 and the port drops back to
 * the new day's 3.46.
 *
 * Every field that changes does so in the hour after midnight, from a daily convoy
 * routine that is not traced.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CConvoy {
    namespace VFTable {
        constexpr uintptr_t CConvoy = 0x11C0D44;   // module relative, RTTI, 8 slots
    }

    namespace Offsets {
        /**@brief the save's `id = { id type }`; the type is always 42*/
        constexpr uintptr_t id_type = 0x08;
        constexpr uintptr_t id = 0x0C;

        /**@brief the owner: three characters and a NUL, then the country id*/
        constexpr uintptr_t owner_tag = 0x30;
        constexpr uintptr_t owner_id = 0x34;

        /**
         * **What it carried at its last sailing**, a CGoodsPool - save key `daily`. One
         * day's load while it sails every day; the whole backlog after days without a
         * transport.
         */
        constexpr uintptr_t daily = 0x38;

        /**
         * **Which goods it carries**: a vector of seven ints, one per good in
         * CGoodsPool order, 1 where it carries it - save key `ship`. Begin, end and
         * capacity end; always seven long.
         */
        constexpr uintptr_t goods_mask_begin = 0x5C;
        constexpr uintptr_t goods_mask_end = 0x60;

        /**
         * **What the loading end produces in a day**, a CGoodsPool. Not saved; refreshed
         * by the daily routine, and the same on every convoy loading in the same network.
         *
         * The resource slots are the `current_producing` of the loading port's network -
         * the provinces with its depot that the owner controls - added up, before
         * modifiers. It can lag a day behind while that production is recovering. On
         * convoys loading in the home network the supply and fuel slots hold what is
         * presumably the country's daily supply and fuel production; not confirmed.
         */
        constexpr uintptr_t loading_production = 0x6C;

        /**
         * **Transports: wanted, and assigned.** `transports` is save key `convoys`;
         * `transports_wanted` is not saved. A new convoy starts with both at 0 and gets
         * both on its first day; after that, assigned can fall short of wanted.
         */
        constexpr uintptr_t transports_wanted = 0x90;
        constexpr uintptr_t transports = 0x98;

        /**
         * **Escorts** - save key `escorts`. `+0x94` sits where an escorts wanted would, in
         * the same layout as the transports, and it does change; not established.
         */
        constexpr uintptr_t escorts_wanted_maybe = 0x94;
        constexpr uintptr_t escorts = 0x9C;

        /**@brief bools, one byte each - save keys `trade` and `lend_lease`*/
        constexpr uintptr_t is_trade = 0xA0;
        constexpr uintptr_t is_lend_lease = 0xA1;

        /**
         * **The route**, save key `path`: a `{ first, last, count }` list of nodes
         * `{ province id, prev, next }`, from the start port to the end port.
         */
        constexpr uintptr_t path_first_ptr = 0xB0;
        constexpr uintptr_t path_last_ptr = 0xB4;
        constexpr uintptr_t path_count = 0xB8;

        /**@brief the ports, as province ids - save keys `start` and `end`*/
        constexpr uintptr_t start_province_id = 0xC0;
        constexpr uintptr_t end_province_id = 0xC4;

        /**@brief ticks - save keys `start_date` and `last_attack` ("1.1.1" for never)*/
        constexpr uintptr_t start_date = 0xC8;
        constexpr uintptr_t last_attack = 0xCC;
    }
}
