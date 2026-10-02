# `CAIUnit` — how the AI commands its armies

The largest class in the image that anyone had pointed at and nobody had read: 90 vftable slots,
37 of which `CAIUnit` supplies itself. This is the layer between the AI's ministers and the
orders that actually move units.

Read statically off `hoi3_tfh.exe` on 2026-09-30, game not running. Addresses are **virtual**
(base `0x400000`) unless marked rva.

## Two premises this work was started on were false

**There are no `CAIUnit` subclasses, and there is no class hierarchy of theatres and fronts.**
RTTI gives `CAIAgent` exactly seven subclasses - the five ministers, `CAIInvasion` and
`CAIUnit` - and `CAIUnit` has none of its own. Checked the other way too: five of `CAIUnit`'s
distinctive slot bodies each appear at exactly one `.rdata` address, all inside
`0x15EC0B4`-`0x15EC218`, so there is no RTTI-stripped sibling either.

**The theatre/front structure is a tree of identical `CAIUnit` objects.** An agent's place in
the tree, not its type, is what makes it a theatre agent or a corps agent:

- `CAIAgent::SetParent`, slot 48 (`0x89C690`), writes `[this+0x40]` from its argument.
- `CAIAgent::Update`, slot 9 (`0x89CA90`), walks the children at `[this+0x44]` through node
  `+8`, calling each child's slot 9. Slot 49 (`0x89C8A0`) empties that same list.
- `CAIUnit::GetArea` (`0x8BBAE0`) and `CEU3AI::CreateAgentsForTheatres` (`0x88AA80`) both climb
  `while ([esi+0x40]) esi = [esi+0x40]` to reach the root.

So **the AI's structure mirrors the player's OOB**: a `CAIUnit` holds a `CUnit*` at `+0x64`, the
unit points back at the agent through `CUnit +0x198`, the agent tree parallels the unit tree, and
the root agent is the one carrying a `CTheatre`. `CAIAgent`'s own base is `CAISubscriber`, which
is the other half of the story - see the observer channels below.

## The AI never asks the mod's Lua where to send its armies

This was the most-wanted answer, and it is a clean negative, established three independent ways.

1. **`0x8EACA0`, the per-thread `lua_State` holder that every AI Lua call in the image goes
   through, has exactly 21 callers** - `0x446237`, `0x4D71A6`, `0x4D734B`, `0x4DC1BA`,
   `0x4DC29C`, `0x4DC724`, `0x8059B7`, `0x805DC8`, `0x89CF15`, `0x89D682`, `0x89DD7A`,
   `0x89E4B3`, `0x8A1ACA`, `0x8A2483`, `0x8AEC42`, `0xA0DD32`, `0xA0DEB2`, `0xA44752`,
   `0xA448D2`, `0xA44A52`, `0xA44C22`. **Not one is inside `0x8AF4D0`-`0x8DCA6A`**, which is all
   of `CAIUnit`'s code.
2. A sweep for the `LUA_GLOBALSINDEX` immediate `0xFFFFD8EE` finds 34 sites in 15 functions. The
   AI ones are seven known global pushers, each with exactly one caller, all inside a minister's
   slot 10. There is no pusher for a `CAIUnit`-shaped global name. (`0x8AF280` -
   `TechMinister_Tick`'s pusher - sits immediately *before* `CAIUnit`'s code, so anyone scanning
   by address range rather than by function will mistake it for one.)
3. A call-graph walk from all 37 slot bodies to depth 4 reaches neither `0x8EACA0` nor any
   `GetDiploScoreFromLua`-shaped bridge.

**So `ai_country.lua` and the five `*Minister_Tick` functions are the whole of the Lua contract,
and none of them is the unit AI.** The mod has no scripted lever on unit-level AI decisions.

### The one lever that is Lua-adjacent

`CAI.MoveUnit` is registered in luabind at `0x89A840` -
`void MoveUnit(CEU3AI&, CUnit*, int, int, bool, bool, CAIAgent*)` - and **`CAIUnit` slot 32
(`0x8B0E60`) calls exactly that function.** So the mod's Lua can move a unit through the same
entry point the unit agent uses, even though the agent never calls back into Lua. `project.json`
recorded that address as `CMoveCommand::IssueFromInterface`; it has been renamed
`CEU3AI::MoveUnit` with the old name kept as an alias, because the luabind table is authoritative
here and the old comment had already noticed its receiver was not a `CMoveCommand`. Also
registered and unused by the mod: `CAI.GetTheatreSubUnitNeedCounts` (`0x7918C0`).

## Every AI unit decision goes through the command queue

The AI does **not** write a `CUnitPlan` directly. It issues the same commands the player's UI
does, which means the mod's existing command-level hooks already see every AI unit decision.

| command | constructor | reached from |
| --- | --- | --- |
| `CActivateUnitPlanCommand` | `0x5E5350` | slots 49, 54, 63, 64 |
| `CSetPlanAttributesCommand` | `0x5E7710` | slots 76, 77 |
| `CSetPlanOpsAreaCommand` | `0x5E60B0` | slots 76, 83 |
| `CSetPlanAxisCommand` | `0x5E7FC0` | slot 76's subtree |
| `CSetPlanForcesCommand` | `0x5E87E0` | slot 76's subtree |
| `CAttachUnitCommand` | `0x5DE890` | slots 17/18/19, 85 |
| `CDetachUnitCommand` | `0x5DE1D0` | slot **79** (one site, `0x8B34D1`) |
| `CTransferSubUnitCommand` | `0x5DCA90` | **neither 78 nor 79** - three unnamed bodies (`0x8CE90E`, `0x8D1341`, `0x8D1BEB`) |
| `CSendExpeditionCommand` | `0x5E95B0` | slot **79** (`0x8B35C5`, `0x8B3973`) |
| `CSetAIParamCommand` | `0x5E90B0` | slots 63, 64, 78 - and `0x8B24CB` is the **only** command slot 78 issues |
| `CCancelMovementCommand` | `0x5D96D0` | subtree |
| `CSetCommandLevel` | `0x5E1870` | slot 82 |

**Corrected 2026-10-01.** This table originally put `CDetachUnitCommand` and
`CSendExpeditionCommand` in "slots 78, 79" and `CTransferSubUnitCommand` in "slot 78's
subtree". Counted the other way round - by caller, with `findRefs.py --callers`, instead
of by a slot's assumed extent - **slot 78 issues exactly one command,
`CSetAIParamCommand`**, and the detach and expedition logic is **slot 79's**. The cause is
trap 3 in reverse: slot 78's `ret` at `0x8B32AC` is *not* the end of it, because an EH
funclet runs on to `0x8B32DF` - but slot 79 begins at `0x8B32E0`, so reading slot 78 as
`0x8B1D10`-`0x8B3A46` swallowed the whole of slot 79. The lesson is narrower than "check
for funclets": **a slot's extent is the wrong tool for attributing a call site at all**,
when the vftable gives the next slot's entry for free. See `FINDINGS-aiplans.md`.

## Where a `CAIUnit` comes from, and when it updates

The object is **`0x374` bytes**; all four allocation sites `push 0x374` (`0x88A96E`, `0x88AB7C`,
`0x88BF78`, `0x89A1D3`). The constructor is `0x8AF530` (rva `0x4AF530`, `ret 0x10`), `this` on
the stack, returned in EAX: `(this, CEU3AI* owner, CCountryTag tag, int countryId)`. It writes
vftable `0x15EC0B4` at `0x8AF568`, then zero-fills to `+0x370` with these seeds: `+0x5C = 1`,
`+0x60 = owner`, `+0x80 = 0x100`, `+0x84 = 0x10101`, `+0x88 = 1`, `+0x366 = 1`.

**It zeroes `+0x54`**, where `CAIAgent` keeps the owner AI for the five ministers and where the
luabind getter `GetOwnerAI` (`0x8E90A0`, `mov eax,[ecx+0x54]`) reads. A `CAIUnit` keeps its owner
at `+0x60` instead, so **`GetOwnerAI` called on one answers null.** Worth knowing before anyone
scripts against it.

Four creation paths:

| function | `this` | called from | thread |
| --- | --- | --- | --- |
| `CEU3AI::CreateAgentsForPlannedUnits` `0x88BEF0` | stack | `ProcessAI` at `0x8897D5` | **worker** |
| `CEU3AI::CreateAgentsForTheatres` `0x88AA80` | stack | `ProcessAI` at `0x889A61` | **worker** |
| `CEU3AI::EnsureAgentForArea` `0x88A880` | stack | `0x8ABAEF`, `0x8ABC38`, `0x8ABE8F`, `0x8ABFAE` | **tick** |
| `CEU3AI::CreateUnitAgent` `0x89A1B0` | EDI | `0x74FB7B`, in `CObjectivesEntry` slot 22 | interface |

**All four `EnsureAgentForArea` callers reach it from `RunCountryHourlyPass`, so it is on the tick thread** (theatre survey, 2026-10-01; this row said "not traced"). That makes **three of `CAIUnit`'s four construction paths tick-thread**, not one: this, `CreateUnitAgent` from `CObjectivesEntry` slot 22, and the observer slots. Only the hourly *ticking* of an agent is on a worker. See `FINDINGS-aitheatre.md`.

`0x88BEF0` is how a **human's delegated AI** picks up the plans he has drawn: it walks
`CCountry +0xBAC`, takes any unit whose battle plan is on (`CUnit +0x204`) and which has no agent
yet (`CUnit +0x198 == 0`), climbs `higher_oob_unit_ptr` while each ancestor's plan is also active
to find the topmost planned unit, makes the agent, enables it, and calls slot 63 then slot 76.
`ProcessAI` gates it on the country being the player's (`ai->id == gamestate[+0xC34]`).

`0x88AA80` walks `CCountry +0x570`, the theatre list, and for each theatre looks for an existing
agent whose recorded object id resolves to it, creating one if there is none and writing the
theatre's id pair into `+0x68`/`+0x6C`.

`FindTheatreForUnit` (`0x8ACD00`, unit in EAX) climbs to the top unit then matches its id pair
against entries at `manager[+0xE4]`, whose `+0x74`/`+0x78` is a `CTheatre`'s `unit` key - so the
answer is **the theatre whose HQ is the root of this unit's OOB**. Only a unit with `oob_level`
(`CUnit +0x1F4`) of 0 records an area.

### The update entry

`ProcessAI` (`0x8894E0`) ticks **three** agent families per country:

    0x8896C8   for (node = ai[+0x74]; node; node = node[+8])    ; the five ministers
                   if (node[0] && byte[node[0]+0x3C]) node[0]->vf[9]()
    0x88986D   for (node = ai[+0x40]; node; node = node[+8])    ; the CAIUnit agents
                   node[0]->vf[9]()
    0x889887   for (node = ai[+0x50]; node; node = node[+8])    ; the CAIInvasion agents
                   node[0]->vf[9]()

Both new lists are new record: **`CEU3AI +0x40/+0x44/+0x48` is the unit-agent `CList`** (all four
creation paths push_back onto it) and **`+0x50/+0x54/+0x58` the invasion-agent list** (push_back
at `0x893B34`-`0x893B5D`). The two new loops do not test `+0x3C` themselves; slot 9 does, through
slot 8.

`ProcessAI` has two early `ret 4` exits, at `0x889618` and `0x88986A`, and the agent loops sit
**after** the second one, reached by a jump and sharing its frame - so they are part of the
function, not a separate one. That is the cold-path trap, not the abutting-function trap.

**So every `CAIUnit` is updated from `ProcessAI`, under `ProcessAIFunctor::execute`, on a TBB
worker thread, once per game hour.** A BiceLib hook anywhere in `0x8AF4D0`-`0x8DCA6A` is
worker-thread code: it must not touch the Lua state, raise a message, or assume the ImGui frame.

### This closes `FINDINGS-ai.md`'s "single biggest hole"

**`CAIAgent::Enable` is slot 52, `0x89C8E0`, and it is one instruction:
`mov byte [ecx+0x3C], 1; ret`.** That is the flag the constructor leaves at zero, that
`IsEnabled` (slot 8) tests, that `CAIAgent::Update` gates on, and that `ProcessAI`'s minister
loop gates on. `CAIUnit` overrides it at `0x8B0360`, and all four creation paths call it through
`[vftable+0xD0]` immediately after construction. Slot 49 (`0x89C8A0`) is the counterpart: it
clears `+0x3C` and disbands the children. *Somebody calling slot 52* is how any agent becomes
live; for the ministers that caller is still unfound, but the mechanism is no longer a mystery.

### The schedule inside slot 73

Slot 10 (`0x8B0710`) is six instructions: call slot 73, then set `+0x30 = 1` to ask to be ticked
again. All the gating is in **slot 73 (`0x8B0730`-`0x8B0D17`)**, which derives `days` and
`hourOfDay` from `tick - 0x29C55C0` and then staggers on the country id at `CAIAgent +0x38` with
**four** different offsets:

| stagger | drives |
| --- | --- |
| `id % 24` | `0x8C3330`, and slot 82's every-ninth-day flag |
| `(id + 3) % 24` | slot 85 |
| `(id + 6) % 24` | part of slot 78's gate |
| `(id + 9) % 24` | `0x8B0D20`, and part of slot 78's gate |

Plus: a weekly re-anchor to the theatre at hour 1 when `dayOfYear % 7 == 0` (or at once if
`+0x87` is set) through `GetArea` then `SetArea` (`0x8BA5A0`); slot 82 **every hour**; and, for a
land unit only, a copy of the plan's objectives from `CUnit +0x234` into `CArmy +0x2EC` through
`CopyObjectiveList`. That last is guarded by `unit->slot9()`, which is `mov eax,ecx; ret` on
`CArmy` and the shared null stub `0xA80690` on `CUnit`, `CNavy` and `CAir`.

Since the pass is hourly, each stagger fires once a game day, spread across the day by country
id - the same shape as the ministers' `(id + K) mod 24`, with four K's instead of one.

## Objectives

`CObjective` (vftable `0x15C8BE0`) is **`0x24` bytes and is its own list node**.
`CopyObjectiveList` (`0x8DD350`, `dest@EDI`, `src@EAX`) allocates `0x24` per objective, copies
`+4`, `+8`, `+0xC`, `+0x10` and the byte `+0x14`, and links `prev` at `+0x18`, `next` at `+0x1C`.
`CObjective::LoadKey` (`0x8E33D0`) names the payload from the save keys:

| key | token | offset |
| --- | --- | --- |
| `province` | `0x1EE` | `+0x8` |
| `priority` | `0x8A` | `+0xC` |
| `invasion` | `0x3A5` | `+0x10` - **a number, not a flag** |
| `hold` | `0x715` | `+0x14` |

`+0x2EC` belongs to **`CArmy`, not `CUnit`**, twice over: the copy sits behind the `CArmy`-only
slot 9, and `+0x2EC`/`+0x2F0`/`+0x2F4` is past the end of a `CAir` (`0x2F4` bytes) and a `CNavy`
(`0x2FC`), fitting only a `CArmy` (`0x308`).

## The `defines.lua` entries the unit AI reads — five, and that is all

**Slot 85 (`0x8C20C0`) is the command-range calculation:**

    radius = unit->regiments.first->definition[+0x180]
             * RADIO_<x>_LEADER_DISTANCE / 1000

with `<x>` chosen from `CUnit::oob_level` (`+0x1F4`) through a four-way jump table -
`0x8C2CB0` (via `jmp [eax*4+0x8C2CB0]` at `0x8C2886`) and a second copy `0x8C2CC0` at `0x8C2A43`.
The arms read the `military` block (`GetDefines()[+0xAC]`) at `+0x21C`, `+0x218`, `+0x214`,
`+0x210`: `RADIO_THEATHRE_`, `RADIO_ARMYGROUP_`, `RADIO_ARMY_` and `RADIO_CORPS_LEADER_DISTANCE`,
confirmed against `definesMap.py --block military`.

**So those four defines bound where the AI is willing to put a unit, not only how much supply
reaches it.** `CLASSES.md` presents their names as *inferred* from block alignment; a second
independent consumer reading them in an `oob_level`-indexed switch, in
theatre/army-group/army/corps order, is strong corroboration.

`0x8D42D0` (from slot 69 at `0x8D5527`, and from `0x8C745B`) reads
`military.STRAT_REDEP_BASE_SPEED` (`+0x1E4`) / 1000.0, but only where a virtual it has just
called answers the save token `0x5A4`, the id `CStrategicRedeploymentOrder` carries - so it
estimates travel time with the redeployment speed where the unit would redeploy rather than
march.

Nothing else in the class touches `CDefines`, and nothing references the `0x1A86040` singleton
directly.

## Slots, in brief

`CAIUnit`'s vftable is `0x15EC0B4` (rva `0x11EC0B4`), 90 slots. **It supplies its own body in 37
slots, not the 34 the RTTI export's `introduces` list reports**: twenty overrides in `0..72` and
seventeen new slots `73..89`. The three missing from `introduces` are the ones whose bodies are
folded or shared - slot 65 (`mov al,1; ret`, in 440 vftables), slot 74
(`mov eax,[ecx+0x64]; ret`, in 2) and slot 81 (the shared empty `0xABF890`, in 1691). **So
`introduces` is not the same question as "which slots does this class supply".**

The ones that matter:

| slot | body | what it is |
| --- | --- | --- |
| 10 | `0x8B0710` | six instructions: call slot 73, set `+0x30` |
| 17, 18, 19 | `0x8D5320` | **one body in three observer slots** |
| 32 | `0x8B0E60` | calls `CEU3AI::MoveUnit`, the Lua-exposed mover |
| 49 | `0x8B05B0` | frees the `+0x1EC` list, tail-jumps to `CAIAgent`'s |
| 52 | `0x8B0360` | **Enable** - sets `+0x3C` and subscribes to eight channels |
| 54 | `0x8B0600` | issues `CActivateUnitPlanCommand` |
| 63, 64 | `0x8B9EB0`, `0x8BA060` | SetUnit / ClearUnit |
| 65 | `0xA92590` | **a type tag**: `mov al,1`. `CAIInvasion` keeps false here and returns true at slot 66 - the same `isLand`/`isNaval`/`isAir` idiom the record knows from `CArmy`/`CNavy`/`CAir` |
| 73 | `0x8B0730` | **the real tick**, 1512 bytes |
| 74 | `0x8AF4D0` | the unit getter |
| 76 | `0x8DABD0` | **the plan builder, 7835 bytes** |
| 78 | `0x8B1D10` | **subordinate management, ~5.5 KB** |
| 82 | `0x8C0600` | runs every hour; issues `CSetCommandLevel` |
| 85 | `0x8C20C0` | the command-range / `RADIO_*` slot - and it issues **`CCreateHigherCommand`** (`0x5DF320`, called at `0x8C31AF`), so the AI creates a theatre through the same button the player uses |

Slots 1 and 3 are `CPersistent::Save` and `CPersistent::Load` - inherited, in 749 and 748
vftables, and **not** `CAIUnit`'s. Slots 11-16, 23, 24, 26-29, 34, 35 are the empty `ret 4`
(`0x60CD50`, in 1420); slots 5, 50, 81 the empty `0xABF890` (1691); 30, 33, 36-47 `0xA806D0`
(336); 60-62 `0xA80690` (189).

**Both extent traps occur inside this class.** Slot 69 (`0x8D5510`) ends `ret 4` at `0x8D552D`
and slot 71 begins at `0x8D5530` with a fresh prologue and SEH push and **no `int3` between
them**. Conversely slot 78's `ret` at `0x8B32AC` is followed by an EH funclet reusing the same
frame out to `0x8B32DF`, so that `ret` is *not* a boundary. The same pair recurs at
`0x8C177A`/`0x8C1790` and `0x8BA05C`/`0x8BA060`.

## The observer channels, and the only openings on the tick thread

`CAIUnit::Enable` (slot 52) subscribes each agent to **eight process-wide observer channels** -
`0x1B14E50`, `0x1B14E70`, `0x1B14E60`, `0x1B14E30`, `0x1B14E20`, `0x1B14E40`, `0x1B14F30`,
`0x1B14E90`, each a `{first, last, count}` triple of `0x10`-byte nodes. That is why `CAIUnit` is
the only `CAIAgent` subclass overriding any observer slot (17-25, 69-72), and it means **those
slots can run off the AI pass entirely**, driven by whatever raises the event.

So there are two ways into this code on the tick thread rather than a worker:

1. `CEU3AI::CreateUnitAgent` (`0x89A1B0`), and slot 76 through it, from `CObjectivesEntry`
   slot 22 - the battle-plan objectives panel.
2. Any of the observer slots, whenever its channel is notified.

**Which dispatcher calls which slot is not established.** `slotcalls.py 20` returns 2325 sites in
880 functions. One data point: a byte-exact sweep of `0x1B14E50` finds only two references in the
whole image - the push_back and the destructor's unhook - so that channel is never notified;
`0x1B14F30` has eight, three inside the espionage and foreign ministers, so the channels are
shared and not uniformly dead.

## Field layout

    CAIUnit  (0x374 bytes; vftable 0x15EC0B4; ctor 0x8AF530 writes it at 0x8AF568)
      +0x5C  byte    1 at construction; unread
      +0x60  CEU3AI* the owner  (NOT +0x54)
      +0x64  CUnit*  the unit it commands; slot 74 is its getter
      +0x68  int     area object id, type half   } always a CTheatre
      +0x6C  int     area object id, serial half }
      +0x80..+0x88   nine flag bytes, seeded 0,1,0,0,1,1,1,0,1
      +0x87  byte    area_dirty: set by 0x88A880, cleared by SetArea, tested by the tick
      +0xB0  COrder* 0x8AF4E0 asks it slot 16 and compares 0x4E5 / 0x56C
      +0x1EC/+0x1F0/+0x1F4  a list slot 49 frees
      +0x294, +0x2D0, +0x30C  three 0x3C-byte containers built in place
      +0x368  float   written from 0x8DCAE0 each tick

    CAIAgent  (vftable 0x15EB674; ctor 0x89C720, `this` in EAX; base CAISubscriber)
      +0x34 CCountryTag  +0x38 country id  +0x3C byte enabled
      +0x40 CAIAgent*    parent
      +0x44/+0x48/+0x4C  children CList
      +0x54 CEU3AI*      owner, for the ministers; zero on a CAIUnit

    CEU3AI   +0x40/+0x44/+0x48  the CAIUnit agents
             +0x50/+0x54/+0x58  the CAIInvasion agents
    CUnit    +0x198  CAIUnit*  the unit's agent
             +0x234  CList     plan.objectives
    CArmy    +0x2EC/+0x2F0/+0x2F4  the AI's copy of them

## What is not established

1. **Slot 76 (`0x8DABD0`, 7835 bytes), the plan builder** - the highest-value unread body left.
   It turns a theatre into an ops area, a stance and a set of objectives.
2. **Slot 78 (`0x8B1D10`-`0x8B32DF`), subordinate management** - reads more of `CUnit` than
   anything else here and issues the detach, expedition and AI-param commands.
3. Slots 75, 79, 80, 83, 84, 86, 87, 88, 89 - read as call lists and field displacements only.
4. **Which observer slot answers which channel, and who dispatches them.** This is what decides
   whether any of `CAIUnit` is reachable from the tick thread.
5. **`CCountry +0x48C`**, the object whose `+0xE4` is a list of `CTheatre*`, and **`CCountry
   +0x570`**, the other theatre list. Naming these two and how they differ would name the AI's
   whole theatre layer.
6. `0x8BA550`, `0x8C3330`, `0x8B0D20`, `0x8DCAE0`, `0x8B1820`, `0x8B4740` - slot 73's callees,
   known only as addresses.
7. The flag bytes `+0x80`-`+0x88`. Their seeds are read and four are gates in slot 73, but only
   `+0x87` has a defensible meaning.
8. **Nothing was watched in a running game.** Three cheap live checks would falsify this if it
   were wrong: `CUnit +0x198` should be non-null on exactly the units whose `+0x204` is set and
   which the AI has taken up; `CEU3AI +0x48` should count about one per theatre plus one per
   planned unit; and `census.py CAIUnit` should scale with theatres, not countries.
9. **`CAIInvasion`** - 74 slots, 9 introduced, one creation site at `0x893B18`, ticked from the
   same `ProcessAI` loop family. A much smaller job than this was.
