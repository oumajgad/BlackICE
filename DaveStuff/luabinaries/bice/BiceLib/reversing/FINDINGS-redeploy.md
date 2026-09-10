# Strategic redeployment and the route finder

**Status: abandoned.** The aim was a strategic redeployment that prefers good
infrastructure. Two attempts were built and tested in the game, and **neither changed the
route a redeploying unit took** - so the model of how that route is decided, below, is
wrong or incomplete somewhere. The person testing it judged that the approach had misread
the problem; what the right reading is was not established.

What survives is the layout, most of it checked against a running game, and it is worth
keeping for its own sake: the route finder, the province graph, the move command. It is in
`GameClasses/CPathFind.hpp`, `CMoveCommand.hpp`, `CStrategicRedeploymentOrder.hpp`,
`CMapProvince.hpp` (`path_node_ptr`, and the two vftables) and `CMap.hpp` (`provinces`).

Each fact below says how it is known. "Static" means read off the executable; "live"
means checked against the running game.

The hook itself was never committed and has been deleted. "What was tried" describes it
closely enough to rebuild.

Addresses are the RTTI export's, based at `0x400000`. **The exe is built with
`DYNAMIC_BASE` and does get relocated** - it was loaded at `0x00A00000` when checked (live)
- so anything that patches it has to add the module base to everything.

## The route finders - static

RTTI names five classes: `CPathFind`, and four that derive from it without adding data -
`CSafePathFind`, `CVerySafePathFind`, `CPlannedPathFind`, `CSafeNavalPathFind`. A finder
object is nothing but its vftable pointer, so a different finder is a different vftable,
and they are built on the stack by whoever wants a route. Four virtual slots; each variant
overrides only the ones it changes:

| class | slot 0 | slot 1 | slot 2 |
|---|---|---|---|
| `CPathFind` | `0x5A2A00` | `0x5A25B0` | `0x5A2700` |
| `CSafePathFind` | | | `0x5A2AE0` |
| `CVerySafePathFind` | | | `0x5A2C40` |
| `CPlannedPathFind` | | `0x5A2D20` | `0x5A2D30` |
| `CSafeNavalPathFind` | `0x5A2E00` | | |

What the slots are for is **inferred from their shape, not confirmed by behaviour**:

- **Slot 0 looks like the cost of a step.** `CSafeNavalPathFind`'s version calls the base
  and adds to what it returns, the shape of a cost with a danger surcharge. The base
  returns the edge's distance scaled by one of two float constants chosen from the
  destination's controller (`+0x334/+0x338`) and the intel held on them
  (`+0x370/+0x374`). **Replacing it for strategic redeployment changed nothing** - which
  is the first thing to doubt.
- **Slot 1 looks like "may this finder be used"** - `CPlannedPathFind`'s is `mov al,1`.
- **Slot 2 looks like "may this step be taken"**, a bool; the safe variants call the base
  and refuse more.

`Find` is `0x5A12B0`, called as `Find(finder, unit, from, to, out path)` with the finder
on the stack, answering a bool.

## Slot 0's arguments - static, and live for the graph

`__thiscall`, result through a hidden pointer that comes first on the stack, `ret 0x14`:

    cost(CFixedPoint* out, node* from, int edge, CMap* map, CUnit* unit)

`this` is left in ecx and never read - the first use of ecx loads a stack argument into it,
and `CSafeNavalPathFind` calls the base without setting ecx at all - so it can be called,
and was replaced, as `__stdcall` with the same five arguments.

**`from` is not a province but the province's path node**, at `CMapProvince + 0xD4`. The
province has something unrelated at `+0x90`: reading edges off it gave a "vector" of 43
million entries. The node holds a vector at `+0x90/+0x94` of 20 byte edges - the
neighbour's id at `+0x4`, the distance at `+0xC`. **Live:** of 35 edges read off seven
provinces, all 35 led to a real province and all 35 were linked back from it; neighbours'
ids sat numerically close; distances ran 8,700 to 34,500 thousandths.

The neighbour's id indexes `CMap + 0x2200`. **Live:** it holds the same `CMapProvince*`
pointers as the game state's own array at `+0xB8C`, pointer for pointer.

Infrastructure is building slot 21 of a province's building array (`CMapProvince + 0x310`),
found by the name `infra` - **live**, and it matches "building no.21" in
`common/buildings.txt`. Levels are thousandths.

## CMapProvince has two vftables - RTTI, and live

`0x11BEBF8` at object `+0x0`, `0x11BEC1C` at `+0x8` for a base subobject.
`CMapProvince::VFTable::CMapProvince` was the `+0x8` one, so checking a province pointer's
first dword against it never matches - which for a while looked like `CMap + 0x2200` held
something other than provinces. The header now carries both.

## Where the very safe finder is built - static

The executable writes `CVerySafePathFind`'s vftable in exactly two places.

**`CMoveCommand` slot 6 (`0x5D88C0`)** routes a unit when the command runs. It puts all
three finders on the stack side by side:

    0x5D8A96   C7 44 24 20 <imm32>    CPathFind
    0x5D8A9E   C7 44 24 1C <imm32>    CSafePathFind
    0x5D8AA6   C7 44 24 18 <imm32>    CVerySafePathFind

and picks one from bytes on the command: `+0x6A` very safe, `+0x69` safe, neither plain.
`+0x68` picks between two ways of routing that choose among the same three objects and
end at the same `Find` (`0x5D8F08`) and `SetUnitPath` (`0x5D8F1C`). The bytes are set by
the constructor (`0x5D87F0`, `ret 0x14`: `a, target, mode68, safe, verySafe`) and copied
by the copy constructor (`0x5D93F0`).

**`CStrategicRedeploymentOrder`'s re-route (`0x588700`)**, called from the order's own
slots 13 and 14, taking the order in edi (unit at `+8`, target province at `+0xC`). It
returns early when the unit's path begins at the province it is going to; only otherwise
does it build a very safe finder, route, and hand the result over (`0x5C9AC0`):

    0x5887FE   C7 44 24 14 6C 5B 5C 01    mov dword ptr [esp+14h], offset CVerySafePathFind::vftable

That early return is what keeps a route the player painted by hand, and is wanted.

## Who asks the move command for very safe - static, not settled

The interface reaches `CMoveCommand` through `0x89A840` (`ret 0x18`), which hardcodes
`mode68 = 1` and forwards its fourth and fifth arguments as safe and very safe. Of its 26
callers, 13 pass very safe = 1, always together with safe = 1; 2 pass safe alone; 11 pass
neither. The constructor's other callers pass zero. Which order types those 13 are was not
traced.

## What was tried, and what it came to

Both attempts replaced `CVerySafePathFind`'s slot 0 and left everything else alone:

- Copy the very safe vftable at run time, **including the RTTI locator one entry before
  slot 0**, so anything asking the object what it is still gets a true answer.
- Swap slot 0 for a `__stdcall` function of the same five arguments that calls the
  game's own cost, then scales the result by `1 + weight x (10 - infrastructure)`,
  reading infrastructure off the province the step enters: `from + 0x90` for the edges,
  `edges[edge] + 0x4` for its id, `CMap + 0x2200` for the province, building slot 21.
  Integer throughout, weight in thousandths, each step capped at `INT_MAX / 500` so a
  route summed in thirty two bits could not wrap. Unreadable infrastructure left the
  game's cost untouched.
- Repoint the immediate at the site, after checking its opcode bytes and that it held the
  very safe table, relocated.
- **Checked in the linked DLL**, by finding the function through the PDB and
  disassembling it: it returned with `ret 0x14`, pushed the game's arguments in the game's
  order, and preserved esi, edi, ebx. With link time code generation the compiler can
  change a convention for a function it sees every caller of; being address-taken kept
  this one `__stdcall`.

**Attempt one** repointed only the re-route. At the heaviest weight, a redeploying unit
still took a lower infrastructure province - one level lower - to save about 3 km. The
reading then was that the re-route's early return meant it never ran, and that routes
came from the move command.

**Attempt two** repointed both, each at its own copy of the table so a counter per site
could say which computed a route. **It changed nothing either.** The counters' values
were not reported, so it is not known whether the replacement was reached at all.

## If this is picked up again

Unverified, in the order worth checking:

1. **Was the replacement called?** A counter per site answers it in one redeployment.
   If neither moved, the route comes from somewhere these two sites do not reach.
2. **Is slot 0 the cost that decides the route?** Its shape says so; its effect did not
   show. It could be a heuristic, or one term among several.
3. **Is the route decided by a finder at all?** Strategic redeployment moves by rail and
   road, and may be routed by a mechanism of its own.

## Still useful elsewhere

- **The order window's list is not in `orders.gui`.** `orders_list` in `land_unit_order`
  is a listbox the engine fills at run time from an `order_entry` template (line 834) - so
  a new entry in it means hooking the code that fills it and the code that acts on it,
  not editing the `.gui`. Not looked at further.
- **Multiplayer.** Every machine works a unit's route out itself, so anything that changes
  routing has to be decided identically on all of them; a switch held in BiceLib's memory
  is not. `CMoveCommand`'s mode bytes are copied by its copy constructor, which suggests
  they travel with the command, and the finder only tests very safe for nonzero - so a
  second value could carry a choice the game would not notice. Whether serialisation sends
  the whole byte was not checked.
