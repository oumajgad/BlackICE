# The AI's trade predicates, the two gates, and the byte that decides who counts as a neighbour

**In one line:** the two mangled `bool CEU3AI::(const CTradeRoute&)` names are *template
instantiations* and not registrations - the non-const one serves three predicates through a
parameterised factory and the const one belongs to a sixth predicate nobody had,
`HasTradeGoneStale`; goods index 2 is **money** and the engine treats it as the price of the other
six, which is why `AlreadyTradingResourceOtherWay` skips it; `CTradeAction`'s two gates are
`IsValid` (slot 13, and slot 13 is `IsValid` for the whole `CDiplomaticAction` family, named by the
game) and `IsConvoyPossible`; `CDiplomacyStatus +0x58` is the **co-belligerent** flag, written by
`CWar::AddAttacker` and `CWar::AddDefender`; `CTradeRoute +0x54` is `inactive`, not `disabled`, and
has exactly one writer; and `CTradeRoute +0x34`/`+0x44` are swapped in the record on four further
independent readings, one of which is the engine's own registered accessor.

Read out of the executable on 2026-10-01. Nothing here needed the game running. Addresses are
**virtual**, based `0x400000`, with the rva beside them where a finding names one. This file is the
second pass over `FINDINGS-survivors.md`'s leftovers; it closes six of its seven open trade items,
leaves the seventh (`CDistributionSetting +0x10`) *more* open than it was by showing the scan that
produced it cannot see what it claimed to, and **corrects eight things already in the record**.

The single most useful thing in it is not a finding but a method: **luabind's RTTI names a virtual
slot for free.** MSVC emits one `memfun_registration<Class, Signature, Policies>` per *signature*,
with a type descriptor carrying the mangled signature; where the registered member is virtual the
member-function pointer is a two-instruction thunk `mov eax,[ecx]; jmp [eax+N]`, and `N/4` is the
slot. That is how three pure slots of `CDiplomaticAction` got names in five minutes after two
surveys had left them open. `scratchpad/luabindmap.py` does it for any class.

---

## 1. The two `bool CEU3AI::(const CTradeRoute&)` registrations, and why there are three functions

### Where the mangled names actually are

`FINDINGS-convoys.md` cites "the mangled names at `0x15F02C8` and `0x15F02E8`". Those two addresses
are real but they are not names. Read as virtual addresses they land in a table of 16-byte records
in `.rdata` starting around `0x15F0200 (rva 0x11F0200)` whose third column is the constant
`0x939ED0` at every row - and `0x15F02C8` and `0x15F02E8` are both that constant. (Read as rvas
they are VA `0x19F02C8`, outside every section: `image.read` returns nothing, so the VA reading is
the only possible one. Trap 1, settled before anything was built on it.)

The mangled names are MSVC **type descriptors**, found by `image.findBytes(b'CTradeRoute')` over the
whole image:

| type descriptor | VA | rva | mangled name |
| --- | --- | --- | --- |
| non-const | `0x01725548` | `0x1325548` | `.?AU?$memfun_registration@VCEU3AI@@P81@AE_NABVCTradeRoute@@@ZUnull_type@detail@luabind@@@detail@luabind@@` |
| const | `0x01725638` | `0x1325638` | `.?AU?$memfun_registration@VCEU3AI@@P81@BE_NABVCTradeRoute@@@ZUnull_type@detail@luabind@@@detail@luabind@@` |

`AE` is a non-const `__thiscall` member and `BE` a const one; `_N` is `bool`; `ABVCTradeRoute@@` is
`const CTradeRoute&`. So the two are **the same signature differing only in constness**, which is
already most of the answer: there is one instantiation per signature, not one per function.

Each descriptor was walked to its class the standard MSVC way - find the dword equal to the
descriptor address (two hits each, the complete object locator's `pTypeDescriptor` and the base
class descriptor's), take the locator, find the dword equal to the locator, and the vftable is four
bytes past it:

| | locator | vftable | rva | `register` body |
| --- | --- | --- | --- | --- |
| non-const | `0x0162B344` | `0x015F2E7C` | `0x11F2E7C` | `0x90B370` |
| const | `0x0162B2AC` | `0x015F2E94` | `0x11F2E94` | `0x90B510` |

Each vftable is two slots: `{0x920100 scalar deleting destructor, <register>}`.

### The non-const instantiation is parameterised, and three functions share it

Each vftable is written at **exactly one place in `.text`** (`image.findValue`), and that place is
the `def` factory that builds the registration object:

| vftable | factory | VA | rva | `ret` | name and function |
| --- | --- | --- | --- | --- | --- |
| `0x15F2E7C` | non-const | `0x008F65D0` | `0x4F65D0` | `ret 8` | **arguments**: `mov eax,[ebp+8]` / `mov ecx,[ebp+0xC]` at `0x8F660B`/`0x8F660E`, stored to `+8`/`+0xC` at `0x8F6617`/`0x8F661A` |
| `0x15F2E94` | const | `0x008F66D0` | `0x4F66D0` | `ret 0` | **baked in**: `mov [esi+8], 0x15ECA38` ('HasTradeGoneStale'), `mov [esi+0xC], 0x89B640` at `0x8F6711`/`0x8F6718` |

That is the whole of it. The non-const factory takes the Lua name and the member-function pointer
**on the stack**, so one instantiation serves every non-const `bool(const CTradeRoute&)` predicate,
and `findRefs.py --callers 0x008F65D0` reports **exactly three** callers: `0x8EFD23`, `0x8EFD2A`,
`0x8EFD31`. Three callers, three predicates. The const factory bakes its name and function in and
has one caller, `0x8EFD3F`.

So the brief's premise - "only two registrations carry that exact mangled signature, so either the
third takes something else or it is registered under a signature nobody looked for" - resolves a
third way: **the third takes a `CTradeRoute` and shares an instantiation with the other two.**
Counting mangled signatures counts signatures.

### The pairing, settled by stack accounting rather than by convention

`FINDINGS-survivors.md` pinned the `(name, function)` order in the registration call at
`0x8EFC58..0x8EFCB3` with three arguments (no orphan, the `GetNeeded`/`0x414F70` cross-check, and
the three bodies matching). That reading is right, and it can now be made airtight: **every one of
the seventeen pushed dwords is consumed, in order, by a chain of factories whose `ret` immediates
account for them exactly.**

The pushes, in program order (`disasm.py 0x008EFC58 0x60`):

    0x8EFC58  push 0x7918C0                                   (a)
    0x8EFC5D  push 0x15ECAC0  'GetTheatreSubUnitNeedCounts'    (b)
    0x8EFC62  push 0x8E8190                                   (c)
    0x8EFC67  push 0x15ECAA4  'GetProductionSubUnitCounts'     (d)
    0x8EFC6C  push 0x8E8180                                   (e)
    0x8EFC71  push 0x15ECA88  'GetDeployedSubUnitCounts'       (f)
    0x8EFC76  push 0x89B790                                   (g)
    0x8EFC7B  push 0x15ECA64  'IsInfluencing'                  (h)
    0x8EFC80  push 0x89B730                                   (i)
    0x8EFC8F  push 0x15ECA4C  'CanTradeFreeResources'          (j)
    0x8EFC94  push 0x89B480                                   (k)
    0x8EFC99  push 0x15ECA08  'IsTradeingAwayNeededResource'   (l)
    0x8EFC9E  push 0x89B3E0                                   (m)
    0x8EFCA3  push 0x15EC9E8  'AlreadyTradingDisabledResource' (n)
    0x8EFCA8  push 0x89B310                                   (o)
    0x8EFCAD  push 0x15EC9C8  'AlreadyTradingResourceOtherWay' (p)
    0x8EFCB2  push ecx        ; movzx ecx, byte [0x174DA85]    (q)

Arguments are the reverse of pushes, so the stack from `esp` upward is
`q p o n m l k j i h g f e d c b a`. Then the chain, with each factory's own `ret` read by decoding
from its entry and stopping at the first `ret`:

| # | call site | factory | `ret` | consumes |
| --- | --- | --- | --- | --- |
| 1-3 | `0x8EFCB3`, `0x8EFCBA`, `0x8EFCC1` | `0x8F5DC0` `GetCountry`, `0x8F5E40` `MoveUnit`, `0x8F5EC0` `GetReqProdQueue` | 0 | nothing (all baked in) |
| 4 | `0x8EFCC8` | `0x8F5F40` `GetReqProdQueueIter` | **4** | `q`, the byte at `[0x174DA85]` |
| 5-16 | `0x8EFCCF`..`0x8EFD1C` | twelve baked-in factories, `GetCurrentDate` through `GetAmountTradedFrom` | 0 | nothing |
| 17 | `0x8EFD23` | `0x8F65D0` | **8** | `p`, `o` → `AlreadyTradingResourceOtherWay` = `0x89B310` |
| 18 | `0x8EFD2A` | `0x8F65D0` | **8** | `n`, `m` → `AlreadyTradingDisabledResource` = `0x89B3E0` |
| 19 | `0x8EFD31` | `0x8F65D0` | **8** | `l`, `k` → `IsTradeingAwayNeededResource` = `0x89B480` |
| 20 | `0x8EFD38` | `0x8F6650` `GetSpamPenalty` | 0 | nothing |
| 21 | `0x8EFD3F` | `0x8F66D0` `HasTradeGoneStale` | 0 | nothing |
| 22 | `0x8EFD46` | `0x8F6750` | **8** | `j`, `i` → `CanTradeFreeResources` = `0x89B730` |
| 23 | `0x8EFD4B`-ish | `0x8F6750` | **8** | `h`, `g` → `IsInfluencing` = `0x89B790` |
| 24 | | `0x8F67D0` `HasFilledProdQueue` | 0 | nothing |
| 25-27 | | `0x8F6850` x3 | **8** each | `f`/`e`, `d`/`c`, `b`/`a` → the three `*SubUnitCounts` |
| 28 | | `0x8F68D0` `EvaluateCancelTrades` | 0 | nothing |

Seventeen dwords pushed, seventeen consumed, nothing left over, and `[ebp+8]` is the name at every
parameterised factory. **The five names in `project.json` are confirmed, not just `likely`-paired.**

### What the ten instantiations say about the five predicates' real signatures

Each factory's vftable gives its type descriptor, and the descriptor gives the C++ signature the
compiler saw. That is worth more than any amount of reading the bodies:

| Lua name | function | rva | signature from RTTI |
| --- | --- | --- | --- |
| `AlreadyTradingResourceOtherWay` | `0x89B310` | `0x49B310` | `bool (const CTradeRoute&)` |
| `AlreadyTradingDisabledResource` | `0x89B3E0` | `0x49B3E0` | `bool (const CTradeRoute&)` |
| `IsTradeingAwayNeededResource` | `0x89B480` | `0x49B480` | `bool (const CTradeRoute&)` |
| `CanTradeFreeResources` | `0x89B730` | `0x49B730` | `bool (const CCountryTag&, const CCountryTag&) const` |
| `IsInfluencing` | `0x89B790` | `0x49B790` | `bool (const CCountryTag&, const CCountryTag&) const` |
| **`HasTradeGoneStale`** | **`0x89B640`** | **`0x49B640`** | `bool (const CTradeRoute&) const` |
| `GetSpamPenalty` | `0x89B530` | `0x49B530` | `float (const CCountryTag&)` |
| `CanDeclareWar` | `0x89B110` | `0x49B110` | `bool (CCountryTag, CCountryTag) const` |
| `GetAmountTradedFrom` | `0x89B270` | `0x49B270` | `CFixedPoint (GoodsCategory, const CCountryTag&, const CCountryTag&) const` |
| `EvaluateCancelTrades` | `0x89B810` | `0x49B810` | `float (float, GoodsCategory)` |

`0x15F2EA0`'s descriptor is `.?AU?$memfun_registration@VCEU3AI@@P81@BE_NABVCCountryTag@@0@Z...` -
`0` is MSVC's back-reference to the previous argument, so `(const CCountryTag&, const CCountryTag&)`.
**`CanTradeFreeResources` and `IsInfluencing` do not take a `CTradeRoute` at all**, which is the
other half of why only three signatures mention one.

### `CEU3AI::HasTradeGoneStale` - `0x89B640` / rva `0x49B640`

New. `0x89B640` to the `ret 4` at `0x89B71F`, with a second `ret 4` at `0x89B70A`; `this` is never
read. With the route at `[ebp+8]`:

    if (route->inactive (+0x54) == 0)                      return false    ; 0x89B65C, 0x89B666
    if (route->last_inactive (+0x84) == [0x170C2B8])       return false    ; 0x89B66C, 0x89B678
    edi = last_inactive + 0x150                                            ; 0x89B684
    ... inlined lazy g_CCurrentGameState on [0x1A89790], 0xDA8 bytes ...
    return edi < gameState->tick (+0xBDC)                                  ; 0x89B6F0, jge -> false

`CCurrentGameState +0xBDC` is hours (the record: "current tick: **hours**, counted from an epoch
43800000 hours earlier"), so **`0x150` = 336 hours = exactly 14 days**. `[0x170C2B8]` holds
`0x29C55C0` = 43800000, i.e. the epoch itself used as a null date.

So: **a trade route is "stale" once it has been inactive for a fortnight**, and the number is an
immediate, not a define. Nothing in the engine calls this function - it exists only for Lua, which
means BlackICE's `ai_trade.lua` can ask it and currently does not. Put beside
`CEU3AI::EvaluateCancelTrades` and `CEU3AI::GetAmountTradedFrom`, the engine hands the mod a
complete toolkit for pruning dead routes.

---

## 2. `CanTradeFreeResources` and `IsInfluencing`, read

Both were `likely` in `project.json` on the registration alone. Both bodies confirm their names, and
both are `ret 8` with `this` unused, matching the `(const CCountryTag&, const CCountryTag&) const`
signature the RTTI gives. Throughout, `countries` is
`[0x1A855A4] + 0x16C` - `g_CCountryDataBase::countries_first`, already in the record.

### `CEU3AI::CanTradeFreeResources` - `0x89B730` / rva `0x49B730`

`0x89B730` to the `ret 8`s at `0x89B778` and `0x89B780`, 22 instructions:

    a = countries[ ((CCountryTag*)[ebp+8])->id ]
    if (a->+0xDEC == 0) return false                       ; 0x89B753
    b = countries[ ((CCountryTag*)[ebp+0xC])->id ]
    if (b->+0xDEC == 0) return false                       ; 0x89B767
    return true

That is the entire function: **a single byte on each country, both required.** `CCountry +0xDEC`
is new to the record and section 3 below shows what the engine does with it.

### `CEU3AI::IsInfluencing` - `0x89B790` / rva `0x49B790`

`0x89B790` to the `ret 8`s at `0x89B7FA` and `0x89B802`:

    a = countries[ tagA->id ]
    modifier = FindStaticModifierByName(a->faction (+0xD8) + 0xBC)      ; call 0x523560 at 0x89B7BA
    if (modifier == 0) return false
    b = countries[ tagB->id ]
    for (node = b->active_modifiers (+0x648); node; node = node->+8)    ; 0x89B7DD..0x89B7F3
        if (node->item->+8 == modifier) return true
    return false

Three things name every piece of that, and all three are already in the record:

- **`CCountry +0xD8` is `faction` (`CFaction*`), never null** - `project.json`.
- **`CFaction +0xBC` is `influence`, an `Hoi3CString`** saved as `influence`, read live as
  `align_towards_axis` / `align_towards_allies` / `align_towards_comintern` - `project.json`.
- **`CCountry +0x648` is `active_modifiers`, a list** - `project.json`; the nodes are
  `{item, prev, next}` with `next` at `+8`.

And `0x523560` is pinned by a second, independent caller: `CAlignment::GetAlignTowardsTerm`
(`0x4C3790`) calls `0x527140` on the faction to get `&influence`, hands it to `0x523560` at
`0x4C381A`, and then reads the result's values array at `+0x18` - the shape `project.json` already
records for a `CStaticModifier` off the `static_modifiers.txt` database at `[0x1A86208]`.

**The loop is not even original to this function.** `0x4D8040` is twelve instructions that are
byte-for-byte the same loop with both arguments in registers (country in `EAX`, modifier in `EDX`),
eight callers, no vftable holder - recorded here class-free as `CountryHasModifier` per trap 11,
since the receiver is `EAX` and not `ECX`. `GetAlignTowardsTerm` calls it at `0x4C382C`;
`IsInfluencing` has it inlined.

So **`IsInfluencing(a, b)` means "is `b` currently carrying the static modifier named by `a`'s
faction's `influence` string"** - i.e. is `a`'s faction pulling `b` toward it. The name is the
game's and the body is exactly it. Mod consequence: the AI's notion of "influencing" is the
presence of the `align_towards_*` country modifier, so an event or decision that applies that
modifier by any route makes `IsInfluencing` true, and one that drifts a country by other means does
not.

---

## 3. Goods index 2 is `money`, and `CCountry +0x808` / `+0x898` are two pools' value arrays

### The skip

`CEU3AI::AlreadyTradingResourceOtherWay` (`0x89B310`, rva `0x49B310`, three `ret 4`s at
`0x89B37A`/`0x89B385`/`0x89B3CF`) is:

    edi = &this->+0x20                                  ; the AI's own CCountryTag, id at +0x24
    if (route->from_id (+0x28) == this->+0x24)          ; we are the `from` side - 0x89B32E
        for (g = 0; g < 7; g++) {
            if (g == 2) continue                                            ; 0x89B333
            if ((*(route->+0x44))[g] > 0) {                                 ; we give g away
                if (GetCountry(ourTag)->+0x898[g] > 0) return true          ; 0x89B348
            } else if ((*(route->+0x34))[g] > 0) {                          ; we receive g
                if (GetCountry(ourTag)->+0x808[g] > 0) return true          ; 0x89B362
            }
        }
    else                                                 ; we are the `to` side
        for (g = 0; g < 7; g++) {
            if (g == 2) continue                                            ; 0x89B388
            if ((*(route->+0x34))[g] > 0) { if (+0x898[g] > 0) return true } ; 0x89B39D
            else if ((*(route->+0x44))[g] > 0) { if (+0x808[g] > 0) return true } ; 0x89B3B7
        }
    return false

### The two arrays

`CCountry`'s goods pools are 0x24 bytes apart: `+0x7DC TradedAway`, `+0x800
TradedAwaySansAlliedSupply`, `+0x824`, `+0x848`, `+0x86C TradedFor`, `+0x890
TradedForSansAlliedSupply`, `+0x8B4 conversion_made`, `+0x8D8`, `+0x8FC`, `+0x920` (`CLASSES.md`
and `project.json`). `0x24` is `8 + 7*4`, so **a `CGoodsPool` has an 8-byte header and its seven
values at `+0x8`**. Three readings agree:

- the 0x24 stride itself;
- `project.json`'s own note on `CConvoy::RunDelivery`: "the convoy's `daily` pool (the seven dwords
  at `+0x40..+0x58`)" with `daily` at `+0x38` - and `0x38 + 8 = 0x40`;
- the indexing above: `[country + g*4 + 0x808]` and `[country + g*4 + 0x898]` for `g` in 0..6, and
  `0x800 + 8 = 0x808`, `0x890 + 8 = 0x898`.

So `+0x808` is **`TradedAwaySansAlliedSupply.values`** and `+0x898` is
**`TradedForSansAlliedSupply.values`**, and the predicate reads: *am I already buying a good this
route would have me sell, or selling one it would have me buy?* The **SansAlliedSupply** choice is
deliberate - free allied supply shipments do not count as "already trading".

### Index 2 is money, and the engine computes it rather than trading it

`FINDINGS-convoys.md` established the order from a savegame - `ship={ 1 1 0 0 0 0 0 }` for a supply
convoy against `CGoodsPool`'s `supplies, fuel, money, crude_oil, metal, energy, rare_materials` -
so index 2 is `money`. What is new is **what the engine does with it**, and it answers the skip
outright.

`TradeRouteSetTradedOf` (`0xA4CA90`, rva `0x64CA90`, `ret 0xC` at `0xA4CB94`; route in `EAX`,
category in `EDX`, so recorded class-free per trap 11) is the one function that writes a route's
goods. After it has put the value in the right block it does this, and only when its `chargeMoney`
argument is set (`cmp byte [ebp+0x10], 0; je 0xA4CB8E` at `0xA4CAF6`):

    (*targetBlock)[2] = 0                              ; 0xA4CB05
    (*otherBlock)[2]  = 0                              ; 0xA4CB0E
    for (g = 0; g < 7; g++) {                          ; 0xA4CB17..0xA4CB8C
        (*targetBlock)[2] += *TradeRouteValueOneGood(&out1, g, (*otherBlock)[g],  from, to, ...)
        (*otherBlock)[2]  += *TradeRouteValueOneGood(&out2, g, (*targetBlock)[g], from, to, ...)
    }

**Money is not a traded good; it is the price of the other six, zeroed and recomputed from scratch
every time a route's contents change.** That is the whole answer to the skip: the two `cmp esi, 2;
je` at `0x89B333` and `0x89B388` step over the column that is not a resource. The same reading
explains three other things that looked unrelated:

- `CTradeRoute::GetConvoyResponsible` (`0xA4D6A0`, rva `0x64D6A0`) returns the `to` tag when
  `(*(this->+0x34))[2] != 0` and the `from` tag otherwise - **whoever pays runs the convoy.**
- `CTradeAction::IsConvoyPossible` picks which end to path from the same way
  (`this->+0x5C[2]`, at `0xA3910E`).
- `CCountry::RunDailyTradeRoutes` tests `[ebx+0x34]`'s `[eax+8]` at `0x4FEFDE` before choosing which
  tag to record on a failed route - the same expression again.

`TradeRouteSetOneGood` (`0xA4C880`, rva `0x64C880`, bare `ret`, two callers both inside
`TradeRouteSetTradedOf`) adds one more rule: when the value written is positive it **zeroes the same
category in the opposite direction's block** (`mov [eax + esi*4], 0` at `0xA4C8AB`), so a route can
never move one good both ways. `TradeRouteValueOneGood` (`0xA4C9A0`, rva `0x64C9A0`) is the price
itself; it opens by taking the absolute values of the pair of globals `[0x1710CD0]` (= 200000) and
`[0x1710CD4]` (= -200000) and summing them to 400000, then indexes the country database and the
pair's `CDiplomacyStatus`. In thousandths those are ±200.000; what they are was not established.

### `CCountry +0xDEC`, and what "free resources" means

`chargeMoney` above is computed by `CTradeAction::SetTrading` as the **negation of
`CanTradeFreeResources`'s test**:

    0xA38E16  cl = countries[this->+0xC]->+0xDEC                ; the actor
    0xA38E2E  cmp byte [countries[this->+0x14] + 0xDEC], 0      ; the recipient
    0xA38E37  bl = both set
    ...       flag = !bl, passed to TradeRouteSetTradedOf       ; sete al at 0xA38EAF

and the same pair appears a third time at the very top of `CTradeRoute::IsValid` (`0xA4CEE0`, rva
`0x64CEE0`, bare `ret`s at `0xA4D031`/`0xA4D03A`), where **both set means `return true`
immediately** (`0xA4CF06`, `0xA4CF16`, then `jne 0xA4D029` which is `mov al,1; ret`), skipping the
entire float validation that starts at `0xA4CF2A`.

So all three readers agree: **`CCountry +0xDEC` is "this country may move goods without payment"**,
and it takes both parties. Recorded `inferred` and named `can_trade_free_resources` after the
registered predicate's own word, because what *sets* it was not found - see section 9.

---

## 4. `CTradeAction`'s two gates, and slot 13 across the family

### Slot 13 is `IsValid`, and the game says so

This is the result that matters most, and it came out of the registrations rather than out of the
bodies. `CDiplomaticAction` has exactly five luabind method registrations
(`scratchpad/luabindmap.py CDiplomaticAction`), and the two that resolve to thunks name their slots:

| Lua name | member pointer | body | slot |
| --- | --- | --- | --- |
| `GetValue` | `0xA0E990` | `mov al,[ecx+0x24]; ret` | - (non-virtual) |
| `SetValue` | `0xA0E980` | `this->+0x24 = arg` | - (non-virtual) |
| `GetType` | `0x416000` | `mov eax,[ecx+0x18]; ret` | - (non-virtual) |
| **`IsValid`** | **`0x998420`** | `mov eax,[ecx]; jmp [eax+0x34]` | **13** |
| **`IsSelectable`** | **`0xA788D0`** | `mov eax,[ecx]; jmp [eax+0x38]` | **14** |
| **`GetAIAcceptance`** | **`0x8A3120`** | `mov eax,[ecx]; jmp [eax+0x44]` | **17** |

`0x34/4 = 13`, `0x38/4 = 14`, `0x44/4 = 17`. The pairing is the same stack accounting as section 1:
the chain at `0x8ED403`..`0x8ED426` is `0x8FD990` (`GetValue`, baked), `0x8FDA10` (`SetValue`,
baked), `0x8FDA90` (`GetType`, baked), `0x8FDB10` **twice** (`ret 8` each, consuming the two pairs
pushed at `0x8ED3EF`..`0x8ED3FE`: `('IsValid', 0x998420)` then `('IsSelectable', 0xA788D0)`), then
`0x8FDB90` (`GetAIAcceptance`, baked, `mov [esi+0xC], 0x8A3120` at `0x8FDBD8`). Four pushes, two
`ret 8`s, nothing left over.

All three thunk bodies are **folds** and are recorded class-free (trap 4): `0x8A3120` has eight
references including a `CGovernment` registration at `0x8FAB08`, `0x998420` has twelve, `0xA788D0`
has ten. The *registration object* is what carries the class, and its type descriptor says
`memfun_registration<CDiplomaticAction, int (CDiplomaticAction::*)(), null_type>` for
`GetAIAcceptance` and `bool (CDiplomaticAction::*)()` for the other two.

### The family, slot by slot

`scratchpad/family.py 13 17 11 12`, walking the RTTI export's `bases` transitively from
`CDiplomaticAction` - 24 classes, which agrees with `FINDINGS-survivors.md`'s correction:

| class | vftable | slot 13 `IsValid` | slot 17 `GetAIAcceptance` |
| --- | --- | --- | --- |
| `CDiplomaticAction` | `0x15FB1D4` | `_purecall` | `_purecall` |
| `CWarGoalBaseAction` | `0x15FB2D4` | `0xA43520` | `_purecall` |
| `CAddWarGoalAction` | `0x15FB454` | `0xA43900` | `ReturnOneHundred` |
| `CAllianceAction` | `0x15FB514` | `0xA1AD70` | `0xA1BA70` |
| `CCallAllyAction` | `0x15FB6F4` | `0xA2A3C0` | `0xA2AC80` |
| `CDebtAction` | `0x15FB9F4` | `0xA3EAF0` | `0xA3F330` |
| `CDeclareWarAction` | `0x15FB3F4` | `0xA15D20` | `ReturnZero` |
| `CEmbargoAction` | `0x15FB814` | `0xA30160` | `ReturnOneHundred` |
| `CFactionAction` | `0x15FB874` | `0xA33BF0` | `0xA34860` |
| `CGuaranteeAction` | `0x15FB574` | `0xA1DAE0` | `ReturnZero` |
| `CInfluenceAllianceLeader` | `0x15FB7B4` | `0xA22780` | `ReturnZero` |
| `CInfluenceNation` | `0x15FB5D4` | `0xA204E0` | `ReturnZero` |
| `CJoinFactionGoalAction` | `0x15FB4B4` | `0xA43520` (base's) | `0xA43DD0` |
| `CLicenceTechnologyAction` | `0x15FB994` | `0xA3D2C0` | `0xA3D3F0` |
| `CMilitaryAccessAction` | `0x15FB634` | `0xA24E80` | `0xA25610` |
| `CNapAction` | `0x15FB754` | `0xA2D5F0` | `0xA2E3D0` |
| `CNullDiplomaticAction` | `0x15FB274` | `0x592360` | `ReturnZero` |
| `COfferLendLeaseAction` | `0x15FB394` | `0xA116F0` | `0xA116C0` |
| `COfferMilitaryAccessAction` | `0x15FB694` | `0xA27230` | `0xA278E0` |
| `CPeaceAction` | `0x15FBA54` | `0xA41330` | `0xA41D50` |
| `CRequestLendLeaseAction` | `0x15FB334` | `0xA116F0` (shared) | `0xA0FE20` |
| `CSendExpeditionaryForceAction` | `0x15FB934` | `0xA3AD90` | `0xA3AF90` |
| `CShareTechnologyAction` | `0x15FBCD4` | `0xA4BDA0` | `ReturnZero` |
| `CTradeAction` | `0x15FB8D4` | **`0xA38770`** | `0xA38B00` |

**Slot 13 is the opposite of slot 17 in shape.** Slot 17 has six classes pointing at `ReturnZero`
and two at `ReturnOneHundred`; slot 13 is overridden with a real body by **every concrete class**,
with only two shares - `COfferLendLeaseAction`/`CRequestLendLeaseAction` on `0xA116F0` (one
mechanic, two directions) and `CJoinFactionGoalAction` inheriting `CWarGoalBaseAction`'s
`0xA43520`. Notably `CDeclareWarAction` has a real `IsValid` even though its `GetAIAcceptance` is a
hard zero: the engine checks whether a war can be declared and then never asks the AI's opinion.

Mod consequence: **`CDiplomaticAction:IsValid()` is registered to Lua**, so `ai_diplomacy.lua` can
ask the engine whether any action it is about to post is even legal, for all 22 concrete kinds,
without reimplementing a single rule.

### `CTradeAction::IsValid` - `0xA38770` / rva `0x638770`

One vftable holds it (`whoslot.py`: 1 holder, `CTradeAction` slot 13 - no fold). `0xA38770` to the
three `ret`s at `0xA388EB`, `0xA38916` and `0xA3891E`, no stack arguments, `this` in `ecx`. With
`A = countries[this->+0xC]` (the actor) and `B = countries[this->+0x14]` (the recipient):

    status = A->+0xE28[this->+0x14]                                   ; 0xA38798..0xA387A3
    if (A->NumberOfOwnedProvinces (+0xCF8) <= 0)  return false         ; 0xA387B3
    if (B->NumberOfOwnedProvinces       <= 0)     return false         ; 0xA387CD
    if (this->value (+0x24) == 0)  goto cancellation                   ; 0xA387DA
    if (A->government_in_exile (+0x95))                                ; 0xA387F1
        if (GetActingCapitalLocation(A)->owner_id (+0x330) != A's id) return false
    if (B->government_in_exile (+0x95))                                ; 0xA3883B
        if (GetActingCapitalLocation(B)->owner_id != B's id) return false
    if (status->war (+0x20) != 0)                 return false         ; 0xA3885E
    if (A->+0xF34 && A->+0xF3C != B's id)         return false         ; 0xA38881..0xA388AA
    if (B->+0xF34 && B->+0xF3C != A's id)         return false         ; 0xA388B9..0xA388E2
    return true
    cancellation:                                                      ; 0xA388EC
    return FindMatchingTradeRoute(status, &this->trade_route)           ; 0xA38906

Every field in it is already named: `+0xCF8 NumberOfOwnedProvinces`, `+0x95 government_in_exile`,
`+0xE28 diplomacy_status_array`, `+0x20 war`, `+0xF34`/`+0xF3C` the has-overlord byte and the
overlord/faction-leader id, `0x42F100 CCountry::GetActingCapitalLocation`.

Two things fall out:

- **The action's `value` byte decides which test it runs.** `CDiplomaticAction +0x24` is the bool a
  script sets with `SetValue`; set, this validates a *new* offer, and clear, it instead demands that
  an identical route already exist on the pair. So `value` is the propose/cancel polarity, and a
  cancellation with no matching route is simply invalid.
- **`+0xF34`/`+0xF3C` must be the overlord, not the faction leader** - see the corrections below.

`FindMatchingTradeRoute` (`0xA4A750`, rva `0x64A750`, `ret 4`s at `0xA4A7B9`/`0xA4A7D6`, receiver in
`EAX` so class-free per trap 11) walks `status->+0x60` and returns true for the first route matching
the candidate in `+0xC`, `+0x14` **and both goods blocks**, compared as
`for (i = 0; i < 0x1C; i += 4)` over `*(route->+0x44) + i` and `*(route->+0x34) + i`. The `0x1C`
bound and the double dereference are by themselves proof that `+0x34` and `+0x44` are vector headers
over exactly seven four-byte values - the shape `FINDINGS-survivors.md` deduced from
`GetAIAcceptance`, here confirmed from a second function.

### `CTradeAction::IsConvoyPossible` - `0xA390D0` / rva `0x6390D0`

The second gate, and it is not virtual at all: `whoslot.py` reports **0 holders**, and the name comes
from the registration at `0x8ED29E`/`0x8ED2A3` whose instantiation is `bool CTradeAction::
IsConvoyPossible() const` - matching the bare `ret` and the absence of stack arguments.
`0xA390D0` to `0xA3925D`:

    A = countries[this->+0xC]
    if (!CCountry::NeedConvoyToTradeWith(A, recipientTag))  return true    ; 0xA39101, je -> true
    if ((*(this->+0x5C))[2] != 0)  side = this->+0x54/+0x58  (the route's `to`)   ; 0xA39111
    else                           side = this->+0x4C/+0x50  (the route's `from`)
    if (this->+0xC != side.id)  swap the pair                              ; 0xA39141
    cap   = CCountry::GetCapitalLocation(countries[side.id])                ; 0xA39168
    port  = cap->area (+0x2B4)->+0x50 ? (*(area->+0x48))->+0xD0 : 0
    dest  = CCountry::GetActingCapitalLocation(countries[other.id])->+0x2B4 ; 0xA391A4
    p1    = provinces[ 0x47E5E0(port, dest, ...) ]                         ; 0xA391BB
    ... the same again with the ends swapped, giving p2 ...
    return p1 and p2 each have +0x330 != 0, +0x354 != 0, and (*(+0x300))->+0x20 > 0

`+0x330` is a province's `owner_id` and `+0x300`/`+0x20` is a building and its `level_max` - the
same `+0x20` `CConvoy::GetDesiredTransports` reads for the naval base. So: **a trade needs no
convoy check at all when `NeedConvoyToTradeWith` says no sea leg is involved; otherwise both ends of
the sea route must be owned provinces with a port that was built**, level_max rather than current,
so a bombed-out port still counts as possible.

`this->+0x4C/+0x50` and `+0x54/+0x58` are `0x28 + 0x24` and `0x28 + 0x2C`, i.e. the embedded route's
`from` and `to` tags, and `this->+0x5C`/`+0x6C` are `0x28 + 0x34` and `0x28 + 0x44` - all consistent
with `FINDINGS-survivors.md`'s `CTradeAction +0x28` finding.

### `CTradeAction`'s five registered methods, with their bodies

The same stack accounting, the chain at `0x8ED335`..`0x8ED358`, five parameterised factories with
five `ret 8`s against the five pairs pushed at `0x8ED29E`..`0x8ED2CF`. **Every one of the five
instantiation signatures matches its body's `ret` immediate and its field reads**, which is the
third independent confirmation of the `(name, function)` convention:

| Lua name | body | rva | RTTI signature | checked against |
| --- | --- | --- | --- | --- |
| `GetRoute` | `0xA38F90` | `0x638F90` | `const CTradeRoute& GetTradeRoute() const` | `lea eax,[ecx+0x28]; ret` |
| `GetTrading` | `0xA38EE0` | `0x638EE0` | `const CFixedPoint& Get(GoodsCategory, const CCountryTag&) const` | `ret 8`, two stack args |
| `SetTrading` | `0xA38DF0` | `0x638DF0` | `void Set(const CFixedPoint&, GoodsCategory)` | `ret 8` |
| `SetRoute` | `0xA39000` | `0x639000` | `void SetRoute(const CTradeRoute&)` | `ret 4` |
| `IsConvoyPossible` | `0xA390D0` | `0x6390D0` | `bool IsConvoyPossible() const` | bare `ret` |

`0xA38F90` is **not** recorded as `CTradeAction::GetTradeRoute`: `whoslot.py` puts it in
`CTableLedgerItem` slot 2 and `CTerrain` slot 7 as well, so it is a two-holder fold of
`lea eax,[ecx+0x28]` - trap 4's `0x791940` case exactly. It is recorded class-free as
`LeaThisPlus28`, and the registration is cited as the evidence for the embedded route rather than as
a name for the body.

`CTradeAction::GetTrading` is eleven instructions and worth printing because it settles section 8
on its own:

    0xA38EE3  eax = [ebp+0xC]            ; the side's CCountryTag
    0xA38EE9  if (eax->id (+4) == this->+0xC)        ; the actor, i.e. the route's `from`
    0xA38EEE      return &this->+0x6C[category]      ; = route +0x44
    0xA38EFB  else return &this->+0x5C[category]     ; = route +0x34

---

## 5. `CDiplomacyStatus +0x58` is the co-belligerent flag

`FINDINGS-theatre2.md` left this as the first of its open items: not a save key, read only in
`CCountry::RebuildNeighbours`, not `military_access` (that is `+0x4C`), and "the cheapest live check
is to dump the whole `CDiplomacyStatus` array for one country". It did not need a live check.

### How it was found

`+0x58` is a disp8, so a byte search for the displacement cannot see it. What can be searched is the
**holder**: a `CDiplomacyStatus` is only ever reached as `country->+0xE28[id]`, and `0xE28` is a
disp32. `scratchpad/status58.py` collects every function containing those four bytes (105 byte
matches, 51 distinct `functionStart` results across the image), decodes each from its entry forward
stopping at an `int3` - never a linear sweep, trap 9 - and lists every store to `[reg+0x58]`. 177
candidates. All but two are stack locals or other classes, and the two that are not are a pair:

    0x00A51C40 (rva 0x651C40)  ret 0xC   xor bl, bl   -> writes 0
    0x00A51CB0 (rva 0x651CB0)  ret 0xC   mov bl, 1    -> writes 1

instruction for instruction identical apart from that one byte, and **each writes both directions of
a pair**:

    void __stdcall (CCountryTag* members, CCountryTag who)
      for (t = members->begin; t < members->end; t += 8) {
          GetCountry(t)   ->+0xE28[who.id]->+0x58 = value;    ; 0xA51C7D / 0xA51CED
          GetCountry(&who)->+0xE28[t.id]  ->+0x58 = value;    ; 0xA51C91 / 0xA51D01
      }

Symmetric per-pair writes with a set/clear sibling is the shape of a membership flag, and the
callers say which membership.

### The callers name it

| writer | called from | VA | the vector it is passed |
| --- | --- | --- | --- |
| set 1 | **`CWar::AddAttacker`** (`0x64F220`) | `0xA4FFE9` | `&war->attackers` (`+0x2C`) |
| set 1 | **`CWar::AddDefender`** (`0x6506B0`) | `0xA5157C` | `&war->defenders` (`+0x3C`) |
| clear | `CWar::RemoveAttacker` (`0x650440`) | `0xA504E3` | `lea esi,[ebx+0x2c]` at `0xA504B1` |
| clear | `CWar::RemoveDefender` (`0x651710`) | `0xA517B3` | `lea esi,[ebx+0x3c]` at `0xA51781` |

**`CWar::AddAttacker` and `CWar::AddDefender` were already named in `project.json`**, which is the
part that makes this confirmed rather than likely: the identification did not come from reading two
thousand-byte functions, it came from two names the record already held. The two Remove siblings are
new and are recorded `likely`; they carry the literal `'war.cpp'` (`0x15FBD9C`) and `'REB'`, their
`lea`s name their vectors, and `CWar +0x2C/+0x30/+0x34` attackers and `+0x3C/+0x40/+0x44` defenders
are in the record. Both clear the flag **after** the leaver has been erased from the vector
(`0xB4A260` at `0xA504D5`/`0xA517A5`), so the loop runs over the countries that remain.

So: **`CDiplomacyStatus +0x58` is set between two countries while they are on the same side of the
same war.** Co-belligerence. That is why it is not a save key - it is derived from the `CWar`
objects the save does carry, and rebuilt as those are loaded.

### What that makes `CCountry +0xF98`

`FINDINGS-theatre2.md` read the membership walk as

    if (status->+0x58 == 0)            skip
    if (edi == us->+0xCA8)             append          ; ourselves, unconditionally
    else if (us->+0xE28[edi]->+0x20)   skip            ; `war`
    else if (other is REB or we are)   skip
    append to +0xF98 / +0xF9C / +0xFA0

With `+0x58` named, `CCountry +0xF98` is **us plus every country we are co-belligerent with, minus
anyone we are also at war with**. The record's `non_hostile_countries` is not wrong but it is weaker
than the truth; the rule is "our war allies". And it explains the one reader that was followed:
`0x89FBC0` iterating it "looking for a port to load troops in" is looking for **an ally's port**,
which is exactly what a seaborne invasion needs and exactly why belligerents are excluded and we are
always a member. Reported rather than overwritten, per trap 14.

One engine quirk worth recording because a mod could trip over it: **the clear is not reference
counted.** A country that leaves one war has `+0x58` cleared against everyone on that side,
including countries it is still co-belligerent with in a different, concurrent war. So after a
separate peace the AI's `+0xF98` can under-report allies until something adds them again.

---

## 6. `CTradeRoute +0x54` is `inactive`, and it has exactly one writer

The record calls it `disabled` "on the strength of a registered function's own word and nothing
else". The registered function's word is actually **`IsInactive`**, and the word matters.

`CTradeRoute::IsInactive` is `0xA4D540` (rva `0x64D540`) and is two instructions,
`mov al, byte ptr [ecx+0x54]; ret`. One reference in the whole image, no vftable holds it
(`whoslot.py`: 0 holders). Its name comes from the registration at `0x8ED459`/`0x8ED45E`, whose
instantiation is `bool CTradeRoute::IsInactive() const`.

Four bytes later, `0xA4D550` (rva `0x64D550`) is **the writer** - `TradeRouteSetInactive`, receiver
in `EDI` so recorded class-free per trap 11, `ret 4`s at `0xA4D5B0` and `0xA4D659`:

    if (route->+0x54 != 0) { route->+0x54 = arg; return; }              ; 0xA4D56F, 0xA4D644
    if (arg) {
        if (route->last_inactive (+0x84) == g_NullDate [0x170C2B8])     ; 0xA4D57F, 0xA4D585
            route->+0x84 = gameState->tick (+0xBDC)                     ; 0xA4D598
        else if (route->+0x84 + 0x228 < gameState->tick)                ; 0xA4D5B3, 0xA4D630
            route->+0x84 = gameState->tick                              ; 0xA4D639
    }
    route->+0x54 = arg                                                  ; 0xA4D59E

`0x228` = 552 hours = **23 days**, so the "went inactive" stamp is deliberately sticky: a route that
flaps on and off does not keep resetting it. `CTradeRoute +0x84` is `last_inactive` on the
registration's own word too - `CTradeRoute::GetLastInactive` (`0x887F80`, rva `0x487F80`, baked in at
`0x8FD931`, RTTI `CEU3Date CTradeRoute::GetLastInactive() const`) is seven instructions that copy
`[ecx+0x84]` to the out-parameter.

Three callers, and `findRefs.py --callers 0x00A4D550` reports no others. All three are inside
`CCountry::RunDailyTradeRoutes` (`0x4FEE70`, rva `0xFEE70`, already named):

| site | argument | the path |
| --- | --- | --- |
| `0x4FEFD4` | `push 1` | `path_count < 2`, `transports == 0` or `CConvoy::IsRouteUsable` false - the `TRADE_INACTIVE_CONVOY` message at `0x4FEFFB` |
| `0x4FFB06` | `push 1` | the seller has none of the good - `TRADE_INACTIVE_NO_RES` at `0x4FF8D5` |
| `0x4FF623` | `push 0` | reached after the seven-category transfer loop completes (`cmp esi, 7; jl` at `0x4FF616`) |

So **`+0x54` is daily state, recomputed every day: set when the route cannot run, cleared when it
delivers.** It is not a player switch and nothing persistent; `disabled` suggests an authored state
that does not exist. The record should say `inactive`, which is the engine's own word.

That has a knock-on for a function the record already describes. `project.json` says
`CEU3AI::AlreadyTradingDisabledResource` "only examines a route whose byte at `+0x54` is set
(`cmp byte [edx+0x54], 0; je next` at `0x89B425`) - hence 'disabled'". With `+0x54` named, that
function examines only the pair's **currently broken** routes, and its purpose is clearer than the
record makes it: *do not offer a second trade in a good we already have a failing route for.*

At all three sites the function also writes a `CCountryTag` into the route at `+0x58`/`+0x5C`
(`mov [ebx+0x5c], ecx; mov [ebx+0x58], eax` at `0x4FEFF3`/`0x4FF006`, and again at `0x4FF8C1` and
`0x4FFAD1`), and the value is exactly the expression `CTradeRoute::GetConvoyResponsible` computes.
So `+0x58`/`+0x5C` records which side owed the convoy when the route failed. No reader was found,
and the reason is honest: a read of `+0x58` is a disp8 and the method used here cannot see one.

---

## 7. `CDistributionSetting +0x10`: the scan was widened, and it still says nothing

`FINDINGS-survivors.md`: "a scan for writers of `+0x10` across the distribution and IC modules found
only those ten, and a bare displacement scan is trap 12, so that silence is not evidence." That is
the right caution. The scan was widened and the answer is worse than unresolved - **the method is
provably blind here**, so even the widened silence is worth nothing.

### What the ten sites actually are

They are not ten copies of one class. `0x4C9C64` (reached from `CCountry`'s constructor `0x4C8A40`)
allocates ten objects and writes ten different vftables, each a `CDistributionSetting` subclass:

| site | `+0x10 = 0x8000` at | vftable | class |
| --- | --- | --- | --- |
| 1 | `0x4C9D42` | `0x15C216C` | `CDistributeLendLease` |
| 2 | `0x4C9D71` | `0x15C21A0` | `CDistributeConsumerGoods` |
| 3 | `0x4C9DA1` | `0x15C21D4` | `CDistributeProduction` |
| 4 | `0x4C9DDD` | `0x15C2208` | `CDistributeSupply` |
| 5 | `0x4C9E0D` | `0x15C223C` | `CDistributeReinforcement` |
| 6 | `0x4C9E3D` | `0x15C2270` | `CDistributeUpgrade` |
| 7 | `0x4C9F0D` | `0x15C22A4` | `CDistributeNCO` |
| 8 | `0x4C9F42` | `0x15C22D8` | `CDistributeDiplomacy` |
| 9 | `0x4C9F78` | `0x15C230C` | `CDistributeEspionage` |
| 10 | `0x4C9FBF` | `0x15C2340` | `CDistributeResearch` |

The first six are the IC sliders at `CCountry +0x5F4` and the last four the leadership sliders at
`+0x5E4`, in the order `CLASSES.md` already records from a running game. `CDistributionSetting` is
their RTTI base and has no vftable of its own.

### The widened scan, and a false positive worth recording

`scratchpad/distfactor.py` takes as its candidate set every function that mentions the disp32
`0x5F4` (105 byte matches, 51 functions) **plus all 120 vftable slots of the ten classes** - 112
distinct functions - and lists every store to `[reg+0x10]` with a non-`esp`/`ebp` base. Result: the
only writes of a 64-bit fixed-point value into `+0x10` are the ten `mov dword [eax+0x10], 0x8000`
above.

An intermediate result looked like a find and was not, and it is exactly trap 12. Slot 5 of all ten
classes writes `[eax+0x10]` and `[eax+0x14]`:

    0x51D5EA  mov dword ptr [eax + 0x10], ebx       ; CDistributeUpgrade slot 5
    0x51D5F4  mov dword ptr [eax + 0x14], edi       ; edi = 0xF

`[eax+0x14] = 0xF` is an MSVC `std::string`'s capacity and `[eax+0x10]` its size: `eax` is the
tooltip out-parameter, which the same function initialises as four strings at `+0`, `+0x1C`,
`+0x38` and `+0x48`. `FINDINGS-production.md` already says slot 5 is "a second, longer tooltip, with
SEH" - the record had the answer and the scan did not consult it. **A 64-bit store into `+0x10`/
`+0x14` is indistinguishable from a `std::string` header at the same offsets**, which is worth
knowing before anyone repeats this.

### Why the negative is worth nothing: the control fails

The control for "nothing writes `+0x10`" is to ask the same scan who writes **`+0x8`**, which is
certainly written: the constructor sets `base_percentage` to **zero** at `0x4C9D39`/`0x4C9D3C`
(`mov [eax+8], edi; mov [eax+0xC], edi` with `edi = 0`), while `CLASSES.md` records, from a running
game, four leadership shares summing to one in all 108 countries, Luxembourg running 0.85 officers
and 0.15 espionage.

**The scan finds no writer of `+0x8` either, outside the same constructor.** So it cannot see the
writer of a field that must have one, and its silence about `+0x10` means nothing at all.

The reason is structural and now identifiable:

- The two accessors that produce a `CDistributionSetting*` - `0x4E06A0`
  (`[ecx+0x5F4][i]`, 7 instructions) and `CCountry::GetLeadershipDistributionAt` `0x4E06C0`
  (`[ecx+0x5E4][i]`) - have **zero direct callers** (`findRefs.py --callers`). They exist only for
  luabind. So a pointer to a setting is handed around, and a function that writes one need not
  mention `0x5F4` anywhere.
- `FINDINGS-fieldmap.md` records `CCountry::LoadKey`'s `distribution` key (save token `0x229`) and
  `leadership` (`0x49B`) as placing "nothing - a base class, or a call that keeps the value
  elsewhere", i.e. **the loader passes its destination in a register.** That is the writer of `+0x8`,
  and it is invisible to a displacement scan by construction.

So the question stands exactly where `FINDINGS-techdecay.md` left it, and the cheapest check is
live and short: **dump the six settings at `CCountry +0x5F4` and the four at `+0x5E4` for several
countries and read `+0x10`/`+0x14` directly.** If every one is `0x8000`/`0`, the monthly decay's
slack term is exactly `1000 x (upgrade share + reinforcement share)`; if any is not, it is that sum
scaled, per setting.

---

## 8. `CTradeRoute +0x34` / `+0x44` - four more readings, all the same way, and no game needed

`FINDINGS-survivors.md` found two static readings that the record has `trade_from` at `+0x34` and
`trade_to` at `+0x44` the wrong way round, and declined to change it because "the decisive check is
a savegame against a live route". The brief asks for a third independent static reading. There are
four, and one of them is the engine's own accessor named after the field.

**(1) `CTradeRoute::GetTradedFromOf` reads `+0x44`.** `0x887F40` (rva `0x487F40`) is nine
instructions:

    0x887F43  eax = [ecx + 0x44]
    0x887F46  ecx = [ebp + 0xC]            ; the GoodsCategory
    0x887F49  edx = [eax + ecx*4]
    0x887F4F  *(int*)[ebp+8] = edx         ; the CFixedPoint return slot

Its Lua name comes from the registration at `0x8ED48B`/`0x8ED490` and its instantiation is
`CFixedPoint CTradeRoute::GetTradedFromOf(GoodsCategory) const`, matching the `ret 8`. **The
accessor the engine itself calls `TradedFrom` reads `+0x44`.** Its sibling `GetTradedToOf`
(`0x887F60`, rva `0x487F60`) is the same nine instructions on `[ecx+0x34]`.

The pairing in that registration is not taken on trust either. The chain at `0x8ED49B`..`0x8ED4CC`
is `0x8FD6F0` twice, `0x8FD770` twice, `0x8FD7F0` twice, then two baked-in factories - six `ret 8`s
against the six pairs pushed at `0x8ED459`..`0x8ED490`, nothing left over. And two of the six bodies
are self-identifying: `GetFrom` is `0xB33760` = `lea eax,[ecx+0x24]` and `GetTo` is `0x7F13A0` =
`lea eax,[ecx+0x2c]`, which agree with the record's `from` at `+0x24` and `to` at `+0x2C`. If the
pairing were shifted by one, those two would be wrong.

**(2) `TradeRouteSetTradedOf` writes `+0x34` for the `to` side.** `0xA4CA90`:

    if (side->id == route->to_id (+0x30))   target = route->+0x34, other = route->+0x44   ; 0xA4CAA5
    else                                    target = route->+0x44, other = route->+0x34   ; 0xA4CACF

The `from` side writes `+0x44`.

**(3) `CTradeAction::GetTrading` returns `+0x44` for the actor.** `0xA38EE0`, printed in section 4:
when the requested side is the action's actor - which is the route's `from`, since
`CTradeAction::IsValid` builds the status as `countries[actor]->+0xE28[recipient]` and
`IsConvoyPossible` reads `this->+0x4C/+0x50` as the route's `from` - it returns `&this->+0x6C`,
which is `route + 0x44`.

**(4) `CEU3AI::AlreadyTradingResourceOtherWay`'s own arithmetic only makes sense that way.** On the
branch taken when the AI is the `from` side (`route->+0x28 == this->+0x24`), a positive entry in
`+0x44` is tested against the AI's `TradedForSansAlliedSupply` - "I would be giving this away but I
already buy it". Read the other way round the function tests whether a good it *receives* conflicts
with a good it already *buys*, which is not a conflict and not what the name says.

Add the two readings `FINDINGS-survivors.md` already had - `IsTradeingAwayNeededResource`'s branch
split, and `GetAIAcceptance` handing `+0x44` to Lua as `voTradedFrom` - and that is **six
independent readings, all one way**:

> `CTradeRoute +0x34` is `trade_to` and `+0x44` is `trade_from`.

Reported rather than changed, because `buildFindings.py` refuses to overwrite an existing name and
the collision is the point. But **the correction no longer needs a running game**: a registered
accessor named `GetTradedFromOf` that reads `+0x44` is as direct as evidence gets, and the savegame
check would only confirm what six readings already say.

While there: `FindMatchingTradeRoute` compares `+0xC` and `+0x14` to decide two routes are between
the same parties. Those sit 8 bytes apart in the same tag/id shape as `+0x24`/`+0x28` and
`+0x2C`/`+0x30`, and the save block carries `first="HON" second="POL"`, so `CTradeRoute +0x8`/`+0xC`
is `first` and `+0x10`/`+0x14` is `second` - the `CRelation` base. Recorded `likely`, placed by
shape and by that use rather than by a store.

---

## 9. How the negatives were controlled

Three negative or near-negative results appear above. Each was run against a known positive by the
same method first, and **one of them failed its control and is therefore not claimed.**

- **"No writer sets `CCountry +0xDEC` to 1."** `scratchpad/dispscan.py` searches `.text` for the
  four bytes of a disp32, then decodes from up to ten bytes before each hit and keeps only
  instructions that *contain* those bytes and carry that displacement. For `0xDEC`: 8 decoded
  instructions of 9 byte matches - one writer, `mov byte [ebx+0xdec], 0` at `0x4D3E29`, and seven
  reads. *The control:* the same scan on `CCountry +0xF34` finds **`mov byte [edi+0xf34], 1` at
  `0x4EDE10`** among 90 decoded of 322 matches, and on `CCountry +0x580` finds four
  `mov byte [reg+0x580], 1`. So the method can see a `set to 1` on a `CCountry` byte, and the
  negative is real **for that encoding**. Its limit is stated rather than hidden: a store through a
  base pointing inside the object - `+0xDEC` is `+0xD90 + 0x5C`, inside the embedded
  `global_modifier` - would be a disp8 and invisible. `+0xDD4`, `+0xDDC` and `+0xDE4` are cleared by
  the same four instructions at `0x4D3E14`..`0x4D3E29` and behave identically, which is itself a hint
  that the four are set together by something the scan cannot see.
- **"`TradeRouteSetInactive` is the only writer of `CTradeRoute +0x54`."** Reached a different way,
  because `+0x54` is a disp8: `findRefs.py --callers 0x00A4D550` gives three callers and no others,
  and the three are the three transitions `RunDailyTradeRoutes` makes. *The control:* the same tool
  on `CCountry::HasModifier` (`0x4D8040`) returns eight callers including `0x4C382C`, which was then
  confirmed in the disassembly, and on `0x8F65D0` returns exactly the three that stack accounting
  independently predicts. The limit: `+0x54` could in principle be written by a disp8 store through
  some other base, which no scan here covers.
- **"Nothing writes `CDistributionSetting +0x10` but the ten constructor sites." NOT CLAIMED.** The
  control is the same scan asked for `+0x8`, which must be written, and it finds nothing outside the
  same constructor. The method is blind, the reason is identified (section 7), and the negative is
  withdrawn rather than repeated.

Two further checks worth recording as method:

- **`whoslot.py` was run before every slot-body name.** Its own control is `0xA80690`, where it
  reproduces `TRAPS.md`'s figure exactly - 189 slots across 81 classes. It caught three folds that
  would have gone into the record as class methods: `0xA38F90` (`CTableLedgerItem` slot 2 and
  `CTerrain` slot 7), `0xA0E990` (five slots across four `CDiplomaticAction` subclasses, at **two
  different slot numbers**, 18 and 21), and the three virtual thunks. It also cleared ten bodies as
  safe: `0xA4D540`, `0xA4D550`, `0xA4D6A0`, `0xA4CEE0`, `0x887F40`, `0x887F60`, `0x887F80`,
  `0xA38DF0`, `0xA38EE0`, `0xA390D0` all have 0 holders.
- **`image.findValue` is `.text` only.** `0xB33760` has one `.text` reference and 0 vftable holders,
  so it is safe to call `CTradeRoute::GetFrom`; `0x7F13A0` has two references in two different
  registrations and is therefore recorded class-free as `LeaThisPlus2C` even though its registered
  name is `CTradeRoute::GetTo`. The two checks are not interchangeable and both were run - trap 4's
  own note on exactly this.

One decode in this work started from a guessed address and desynchronised into confident nonsense
(trap 9): `0x4FEFA0` printed `add byte ptr [ebx + 0x8c483f0], cl`. It was only ever used as a window
onto an address `image.findValue` had printed, and every reading above was redone by decoding
forward from a function entry or from a call target. And one trap-1 near miss: `image.findValue`
printed `0x008FD8B4 (rva 0x4FD8B4)` for the `'GetConvoyResponsible'` literal and the rva was read as
the address, which decoded as garbage; `image.both`'s own formatting is what caught it.

---

## 10. Corrections to the record

Eight, reported and not overwritten.

1. **`CDiplomaticAction` slot 17 is `GetAIAcceptance` - confirmed, not inferred - and slot 13 and
   slot 14 are named too.** `FINDINGS-diplomacy.md`: "because the method is pure virtual in the class
   that declares it the registration resolves to `_purecall` ... Which of the ten pure slots it is
   cannot be read from the registration, since all ten resolve to the same address. Slot 17 is it by
   behaviour." That is wrong on the mechanism. The registration resolves to `0x8A3120`, a
   pointer-to-virtual-member thunk `mov eax,[ecx]; jmp [eax+0x44]`, and `0x44/4` is 17. The same
   file's last open item - "Which of the ten pure slots the other nine names belong to.
   `CDiplomaticAction::IsValid` is also registered with luabind and also resolves to `_purecall`" -
   is wrong the same way: `IsValid` resolves to `0x998420` = `jmp [eax+0x34]` = **slot 13**, and
   `IsSelectable` to `0xA788D0` = `jmp [eax+0x38]` = **slot 14**.
2. **`CTradeRoute +0x54` is `inactive`, not `disabled`.** The registered name is `IsInactive`
   (`0xA4D540`), the only writer is `TradeRouteSetInactive`, and it is set and cleared every day by
   `RunDailyTradeRoutes`. Nothing authors it. `project.json`'s field name and
   `AlreadyTradingDisabledResource`'s comment ("hence 'disabled'") both want the word changed.
3. **`CTradeRoute +0x34` is `trade_to` and `+0x44` is `trade_from`**, on six independent readings,
   including the engine's own `GetTradedFromOf`. `project.json` has them swapped and
   `FINDINGS-survivors.md`'s "the decisive check is live" can be retired.
4. **`CCountry +0xF34`/`+0xF38`/`+0xF3C` is the overlord, not the faction leader.** `project.json`
   names them `has_faction` / `faction_leader_tag` / `faction_leader_id` while its own comment on
   `CCountry::IsSameSide` hedges "the faction leader **or** overlord", and `CLASSES.md` already
   calls `+0xF38` the overlord on live evidence (the subject/overlord tribute pools at `+0x920` and
   `+0x8FC` match to the thousandth against `+0xF38` on each giver). `CTradeAction::IsValid` is a
   third reading and it only makes sense as the overlord: it refuses the trade when either side's
   `+0xF3C` names anyone other than the other party. **"A puppet may only trade with its overlord"
   is a HoI3 rule; "a faction member may only trade with its faction leader" is not** - and HoI3
   keeps faction membership separately, in `CCountry +0xD8`. `FINDINGS-convoys.md` reads these fields
   as the overlord throughout ("a puppet keeps 1000.000 of everything ... `C->overlord_id (+0xF3C)`")
   and is consistent with this; only the `project.json` field names are not.
5. **`CCountry +0xF98` is us plus our co-belligerents**, not just "countries whose `+0x58` is set".
   The name `non_hostile_countries` was taken from the membership rule when `+0x58` was unknown;
   with `+0x58` named it can be sharpened. The one reader anybody followed, `0x89FBC0`, is looking
   for a war ally's port, which the sharper name explains.
6. **`FINDINGS-convoys.md`'s citation of the mangled names is at the wrong addresses.**
   `0x15F02C8` and `0x15F02E8` both hold the constant `0x939ED0` inside a 16-byte-record table in
   `.rdata`; the mangled names are the RTTI type descriptors at `0x1725548` (rva `0x1325548`) and
   `0x1725638` (rva `0x1325638`). Recorded because the next person will go to the addresses the file
   gives.
7. **`FINDINGS-survivors.md`'s "ten construction sites" are ten different classes.** `0x4C9C64`
   builds one of each of `CDistributeLendLease`, `CDistributeConsumerGoods`, `CDistributeProduction`,
   `CDistributeSupply`, `CDistributeReinforcement`, `CDistributeUpgrade`, `CDistributeNCO`,
   `CDistributeDiplomacy`, `CDistributeEspionage` and `CDistributeResearch`, all deriving from
   `CDistributionSetting`. The ten `+0x10 = 0x8000` stores are one per class, not ten of one.
8. **`FINDINGS-survivors.md`'s "a scan found no other writer of `CDistributionSetting +0x10`" should
   be struck rather than caveated.** The scan cannot find the writer of `+0x8` either, and `+0x8` is
   certainly written; see section 7.

A ninth that is a sharpening rather than a correction: `FINDINGS-survivors.md` says the five Lua
names were paired to functions by "three separate arguments rather than by locality alone". They can
now be paired by **complete stack accounting** - seventeen pushed dwords, seventeen consumed in order
by factories whose `ret` immediates are read off the image - and the same accounting independently
verifies the `CTradeRoute`, `CTradeAction` and `CDiplomaticAction` chains, where five of the five
`CTradeAction` instantiation signatures match their bodies' `ret` immediates and field reads exactly.
The five names are `confirmed`.

---

## 11. What is not established

- **What sets `CCountry +0xDEC`.** All three readers require it on both parties and all three make
  it mean "these two can move goods without money changing hands". The only write found in `.text`
  is to zero, in `CCountry`'s reset `0x4D2B60` at `0x4D3E29`, alongside three sibling bytes at
  `+0xDD4`, `+0xDDC` and `+0xDE4` cleared in the same four instructions; the positive control passes,
  so the negative is real for a disp32 encoding, but `+0xDEC` is `+0xD90 + 0x5C` inside the embedded
  `global_modifier`, so a store through that base would be a disp8 and invisible. **Cheapest check:
  live.** `dumpStruct` `CCountry +0xDD0..+0xDF0` for a faction leader and a faction member, or for
  two countries that have a working trade with money on it and two that do not, and see whether any
  of the four bytes is ever 1. If they are always 0, `CanTradeFreeResources` is dead code, every
  trade is priced, and `CTradeRoute::IsValid` always runs its full validation.
- **What the other three bytes at `+0xDD4`, `+0xDDC` and `+0xDE4` are.** They are cleared in the
  same breath as `+0xDEC` and read only in diplomacy and interface code - `+0xDDC` at `0x4E40D5`
  (in `0x4E3FE0`) and `0x89D9A1`, `+0xDE4` at `0xA1BDF4`, `0xA1DE77` and `0xA28CA0`, `+0xDD4` by
  nothing at all outside the clear. **Cheapest check:** read the three readers of `+0xDE4`, two of
  which are inside `CGuaranteeAction` slot 12 (`0xA1DC10`) and `CCallAllyAction` slot 7
  (`0xA27BA0`); a per-action permission byte should name itself from which action tests it.
- **`CDistributionSetting +0x10`**, unchanged and now known to be unreachable by displacement
  scanning. **Cheapest check:** live, as in section 7. A static route exists but is longer: read
  `CCountry::LoadKey`'s `distribution` (save token `0x229`) and `leadership` (`0x49B`) handlers,
  which pass their destination in a register, and see whether either touches `+0x10` as well as
  `+0x8`.
- **The two globals `[0x1710CD0]` (= 200000) and `[0x1710CD4]` (= -200000)** that scale
  `TradeRouteValueOneGood`, and therefore set the price of every good in every trade. A symmetric
  ±200.000 pair looks like a define cached into globals at startup, which is trap 8's second case.
  **Cheapest check:** `scratchpad/naval/definecache.py`, which recovers exactly that
  three-instruction caching shape and already found 51 such globals.
- **The body of `TradeRouteValueOneGood` (`0xA4C9A0`) past its first fifteen instructions** - i.e.
  what a good is actually worth, and whether relations, distance or stockpiles enter the price. It
  indexes the country database and the pair's `CDiplomacyStatus` (`+0xE28`, `+0x60`), so it is not a
  pure function of the goods. This is the single highest-value thing left in this subject for a
  modder, because it is the engine's price list.
- **No reader of `CTradeRoute +0x58`/`+0x5C`.** Three writers, all in `RunDailyTradeRoutes`, all
  writing `GetConvoyResponsible`'s answer. A read would be a disp8 and no scan here can see one.
  **Cheapest check:** `fieldchain.py --holder 0x60 --field 0x58` over `CDiplomacyStatus`'s route
  list, which ties the register to the list the routes hang off.
- **The bodies of `CEU3AI::EvaluateCancelTrades` (`0x89B810`), `GetSpamPenalty` (`0x89B530`) past
  its early exit, `GetAmountTradedFrom` (`0x89B270`) past its first fifteen instructions, and
  `CanDeclareWar` (`0x89B110`).** All four are named and signed from the compiler's own RTTI, so
  nothing about the names is at risk; only what they compute is open. `GetSpamPenalty`'s early exit
  is already worth something on its own: it returns `0.0f` unless
  `CCurrentGameState::played_countries_array (+0xBCC)` is non-zero for the argument's id, so **the AI
  applies a spam penalty only to proposals from a human-played country**.
- **`CTradeRoute::IsValid`'s real validation**, `0xA4CF2A`..`0xA4D031`, which works in floats against
  `[0x17179AC]` and calls `0x401FD0` and `0xC08870`. Only its `+0xDEC` short-circuit was read.
- **The remaining seven pure slots of `CDiplomaticAction`** - 7, 11, 12, 15, 16, 18, 19, 20 less the
  three now named. The method that named three is cheap and general: `luabindmap.py` over every class
  in the family will catch any registered virtual, and `0x8FAB08` already shows the same slot-17
  thunk serving `CGovernment`, so the technique scales past this family.
- **Whether `CWar::RemoveAttacker` (`0x650440`) and `CWar::RemoveDefender` (`0x651710`) are named
  the right way round.** The attribution rests on `lea esi,[ebx+0x2c]` versus `lea esi,[ebx+0x3c]`
  feeding the flag clear, and on the record's already-named `CWar::AddAttacker` and
  `CWar::AddDefender` using the matching vectors. Both are recorded `likely`. **Cheapest check:**
  read the `'war.cpp'` assert at `0x15FBD9C`'s reference site, which will carry a line number and
  very likely a function name.
- **The fifth argument of `CWar::AddDefender` and its Remove sibling.** `0xA506B0` is `ret 0x14`
  where `0xA50440` is `ret 0x10`, so one side's pair takes an extra dword that the other does not.
- **Nothing in this file was checked against a running game.** It is all static reading, and the two
  items above that want a live look say so and say what to look at.
