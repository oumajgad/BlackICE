#pragma once
#include <cstdint>

/**
 * CPathFind - the game's route finder, and the variants that change one decision each.
 *
 * Every route a unit takes comes out of one of these. They are small objects built on
 * the stack by whoever needs a route, handed to Find, and thrown away. The variants add
 * no data: each is CPathFind with one or two of its four virtual slots replaced, so a
 * different finder is nothing more than a different vftable pointer in the object.
 *
 *     slot 0   the cost of one step            CSafeNavalPathFind replaces it
 *     slot 1   whether this unit may use it    CPlannedPathFind replaces it
 *     slot 2   whether a step may be taken     Safe, VerySafe, Planned replace it
 *     slot 3   not worked out
 *
 * **Slot 0 looks like the cost of a step**, from its structure: CSafeNavalPathFind's
 * version calls the base version first and then adds to what it returns, which is what a
 * cost with a danger surcharge looks like. The base returns the edge's distance scaled by
 * one of two constants, chosen from the destination's controller and how much intel is
 * held on them. **Not confirmed by behaviour** - replacing it for strategic redeployment
 * changed nothing about the route taken; see reversing/FINDINGS-redeploy.md.
 *
 * **Slot 2 looks like whether a step is allowed**, answering a bool. Safe and VerySafe
 * both call the base and then refuse more.
 *
 * CVerySafePathFind is built in two places: CStrategicRedeploymentOrder's re-route and
 * CMoveCommand's slot 6.
 *
 * Only valid for this build of hoi3_tfh.exe. Addresses are module relative; the exe is
 * built with DYNAMIC_BASE, so it can load anywhere and every one of these needs the
 * module base added.
 */
namespace CPathFind {
    namespace VFTable {
        constexpr uintptr_t CPathFind = 0x11BE414;
        constexpr uintptr_t CSafePathFind = 0x11C884C;
        constexpr uintptr_t CVerySafePathFind = 0x11C5B6C;
        constexpr uintptr_t CPlannedPathFind = 0x11C8860;
        constexpr uintptr_t CSafeNavalPathFind = 0x11C7304;

        /**
        @brief how many slots, not counting the RTTI locator one entry before the first

        MSVC puts a pointer to the class's RTTI immediately before slot 0. A copy of a
        table has to carry it too, or anything asking the object what it is - a
        dynamic_cast, a typeid - reads whatever sat in front of the copy.
        */
        constexpr int SLOT_COUNT = 4;
    }

    namespace Slots {
        constexpr int STEP_COST = 0;
        constexpr int MAY_USE = 1;
        constexpr int MAY_STEP = 2;
    }

    namespace GameFunction {
        /**
        @brief finds a route: Find(finder, unit, from, to, out path), answering a bool

        The finder is passed on the stack, not in ecx.
        */
        constexpr uintptr_t Find = 0x1A12B0;

        /**
        @brief the base step cost, CPathFind slot 0

        __thiscall with the result returned through a hidden pointer, which comes first
        on the stack: cost(out, graph, edge, map, unit), cleaning twenty bytes. `this`
        is left in ecx and **not read** - the first thing the function does with ecx is
        load a stack argument into it - so it can be called as __stdcall with the same
        five arguments. CSafeNavalPathFind calls it without setting ecx at all.

        The result is a CFixedPoint, thousandths in an int32.
        */
        constexpr uintptr_t StepCost = 0x1A2A00;
    }

    /**
     * The graph the step cost is handed as its second argument: **not a province, but
     * the province's path node**, at CMapProvince::Offsets::path_node_ptr. The province
     * itself has something else at +0x90 - which is how this was nearly got wrong.
     *
     * Its edges are a vector - begin and end - of Edge, one per neighbour. Checked live:
     * of 35 edges read off seven provinces, all 35 led to a real province and all 35 were
     * linked back from it, which is what a neighbour graph looks like and nothing else
     * does. The same layout is read by the base cost and by CSafeNavalPathFind's.
     */
    namespace GraphOffsets {
        constexpr uintptr_t edges_begin = 0x90;   // Edge*
        constexpr uintptr_t edges_end = 0x94;
        constexpr uintptr_t edges = edges_begin;
    }

    /**@brief one edge of that graph: a way out of a province into its neighbour*/
    namespace EdgeOffsets {
        constexpr uintptr_t SIZE = 20;
        constexpr uintptr_t to_province = 0x04;   // province id, index into CMap::provinces
        constexpr uintptr_t distance = 0x0C;      // thousandths; 8700 to 34500 seen live
    }
}
