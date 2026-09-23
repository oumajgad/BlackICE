# Manpower: what the drain is made of

Written while splitting the manpower tooltip into land, air and naval, and then chasing
what "manpower rotation" actually is. Both are in `BiceLib/Hooks/Tooltips/ManpowerText.hpp`;
this is the reversing behind them.

Addresses are rvas, the way `project.json` wants them. The disassembler prints virtual
addresses, which are these plus `0x400000` - a trap this work fell into once already.

## The three counters

`CCountry` carries three figures that the reinforcement pass rebuilds from nothing every
day:

| offset | what | where it shows |
| --- | --- | --- |
| `+0xA98` | `reinforcement_cost`, the IC | already named, the `_REINFORCEMENT_` pool |
| `+0xA9C` | manpower **needed** to bring every subunit back to strength | `$NEED$` |
| `+0xAA0` | manpower **spent** doing it today | `$USED$` |

`+0xBCC` is the pool the spending comes out of: the pass does
`country->Manpower -= used` and floors it at zero, which is the only write to it in the
function. **That field was already named** - the Lua API's `CCountry::GetManpower`
gives it - which this work found out only after adding a second name for it. The
duplicate has been taken out.

## The reinforcement pass

`CDistributeReinforcement::Distribute` (`0x11BA60`), slot 0 of its virtual table. The
class derives from `CDistributionSetting`, so this is the reinforcement **slider**
spending what it has been allocated - and every sibling distributor (supply, upgrade,
production, research...) has its own body at the same three slots.

    zero the three counters at +0xA98, +0xA9C, +0xAA0        0x11BBF0..0x11BBFC
    build a list of the country's units wanting reinforcement, priority first
    for each unit
        for each subunit                                     0x11BF8D
            missing = maximum - strength
            if missing <= 0: next
            ...work out the manpower and the IC...
            country->manpower -= used, floored at 0          0x11C5C7
            country->reinforcement_cost += ic                0x11C5FC
            country->reinforcement_manpower_used += used     0x11C5EB
            country->reinforcement_manpower_needed += need   0x11C60C

**The subunit the share belongs to is at `[esp + 0x44]`** from `0x11BF98` to the end of
the loop body - written on the way in, read back three times after, the last at
`0x11C43D`, with the stack unmoved. That is what makes a single hook on `0x11C60C`
enough to split the total by `CRegiment` / `CWing` / `CShip`.

### What a point of strength costs in manpower

Worth writing down, because the arithmetic looks worse than it is. The pass computes

    scale = maximum x 1000 / definition->max_strength
    need  = (missing x 1000 / maximum) x (definition->build_cost_manpower x scale / 1000) / 1000

and `maximum` cancels out of it completely, leaving

    need = missing x build_cost_manpower / max_strength

**Refilling all of a subunit costs exactly what building it cost.** Both fields are on
the definition the subunit *owns* rather than on the shared type, so they already have
its technology in them.

## Troop rotation

`peacetime_manpower_rotation` is a law modifier - conscription and training laws set it -
and its name is misleading twice over.

It is read in exactly **one** place in the executable: `0x1BB171`, inside
`CUnit::UpdateDaily` - virtual slot 32, at `0x1BAF70`. Checked by pairing every fetch of
a country's modifier array (`+0xDA8`, 153 of them) with a read of entry 50 within the next
0x200 bytes; nothing else comes back.

    if (!this->IsLand()) goto the rest of the tick           0x1BB091
    ...dig in, if at war and standing still...               0x1BB097..0x1BB145
    rotation = owner->modifier.PEACETIME_MANPOWER_ROTATION   0x1BB171
    if (this->supply_received_percentage < 1000)
        rotation x= 1 + (1 - supply) x PEACETIME_MANPOWER_ROTATION_LOW_SUPPLY_FACTOR
    for each subunit
        strength = clamp(strength - maximum x rotation / 365000, 0, maximum)   0x1BB25D

The `/365000` is a thousandth-scaled rate over a year.

### Why the slot is called UpdateDaily, and what that claims

`CArmy` and `CNavy` share `0x1BAF70` and `CAir` overrides it at `0x1D0B60`; nothing else
derives from `CUnit`, so those three tables are all of it.

**The period in the name is inference, not something read off a caller.** What the code
shows is the work: rotation divides an annual rate by 365000 and applies it once a call,
and dig-in advances by exactly one level a call. Both only make sense once a day.

The caller would settle it and was not found. The slot is reached through a virtual
table, and `+0x80` as a call displacement is 150 sites in 119 functions - of the three
that also walk units, one is a cleanup whose `+0x80` is on another object, one is the
country's economic pass reached through a different class, and neither leads here.
`CInGameIdler::DailyUpdate` (`0x261CA0`) is the GUI's daily hook - map repaint and the
autosave check - and never reaches a unit.

So `Update` is the part to rely on, and `Daily` is the part to check if a caller ever
turns up.

### It costs no manpower directly

Rotation takes **strength**. The manpower only appears a step later, when the
reinforcement pass puts that strength back - so it is the reason a quiet army still
bleeds manpower, and it can be priced exactly with the formula above.

### It is land only

**`IsLand` at `0x1BB091` is the single gate**, and all three unit classes reach it.
`CArmy` and `CNavy` share `0x1BAF70`; `CAir` overrides slot 32 with `0x1D0B60`, which
does its own air-specific work and then **ends by calling `CUnit::UpdateDaily` on
every path**. So an air unit is not spared rotation by skipping the function - it
runs it and fails the test, exactly as a navy does.

Worth stating carefully because the first reading here was that `CAir` replaced the
base entirely. It does not, and the decompiler is what showed it: the tail call is
the last statement of the override.

### It is not gated on war, though it reads as though it were

The `isAtWar` test at `0x1BB0F7` belongs to the **dig-in** block above, not to rotation.
Read off the flow graph rather than off one jump: `0x1BB146` has seven incoming edges,
six of them branches taken to skip digging in -

    0x1BB146  <- 0x1BB09F(taken), 0x1BB0AC(taken), 0x1BB0B9(taken),
                 0x1BB0CF(taken), 0x1BB0F7(taken), 0x1BB13A(taken), 0x1BB13C(flow)

and the decompiler agrees: the dig-in conditions are one nested `if` whose whole body is
`dig_in_level += 1000`. Digging in needs a unit that is at war, stationary
(`movement_order_remaining_provinces_count < 1`), out of combat (`combats.count < 1`) and
two further conditions; rotation runs whichever way every one of them goes.

## Attrition

`ApplyAttrition` (`0x1C7530`), which `CUnit::UpdateDaily` calls.

    if (unit->combats.count > 0) return          // not while fighting
    if (!unit->IsLand()) return                  // 0x1C756C, the same gate rotation has
    for each subunit
        lost = province attrition x a global x maximum strength / 30000
        strength = clamp(strength - lost, 0, maximum)     0x1C76E2
        total += lost

The `/30000` makes it a monthly rate applied daily, where rotation's `/365000` is an
annual one. The attrition itself comes off the **province's** modifier, not the
country's - `[province + 0xFC + 0x18]`, entry 7 - which is why the country-modifier scan
that found rotation and trickleback finds nothing for it.

**The store at `0x1C76E2` is the same shape as rotation's** at `0x1BB25D`: the clamp, the
write through `[reg + 0x5C]`, the ceiling at `+0x30` raised after. So it is hooked the
same way and priced with the same formula. The one difference is that the unit is not in
a register - it comes off the frame at `[ebp + 8]`.

## What an overloaded fleet does to its cargo

`CheckTransportOverload` (`0x1CFBD0`), the last thing `CUnit::UpdateDaily` does and only
for a fleet. **It throws cargo overboard until the load fits**, re-measuring each pass:

    do
        for each unit in fleet->carrying
            if (its province's info byte +0x22 is set)
                RemoveFromTransport(...)          # writes CUnit::carrying
                unit->EnterProvince(province)     # writes current_province_ptr
            else
                RemoveRegimentFromUnit(its first regiment)   # clears regiment->unit_ptr
                delete that regiment
                if that was its last, post {unit->type, unit->id} into the game
                    state's message ring at +0xBF8, through an interlocked slot
    while (carried weight > capacity)

So a unit that **can** be put ashore is put ashore, and one that cannot is taken apart a
regiment at a time until the fleet is within its `transport_capacity`.

The two writes are what settle it and neither is a guess: `0x1CF19F` writes
`CUnit::carrying` and `0x1BF4D3` writes `current_province_ptr`. Which units are eligible
turns on a byte of the province's info object at `+0x22`; 246 places in the image read
it, so it is something fundamental - most likely land against sea - but nothing read here
says which way round.

## Casualty trickleback

`AddCasualtyTrickleback` (`0x1C3F30`), the only reader of the `casualty_trickleback`
modifier in the executable.

    manpower = casualties x build_cost_manpower / max_strength
             x (trickleback + a technology bonus) / 100000
    country->Manpower += manpower, floored at 0       0x1C3FF2

The first half is the reinforcement pass's own pricing, so a casualty is valued at what
replacing it costs and the modifier decides how much of that comes home. It credits the
**expeditionary owner** where the unit has one (`+0x28C`), the owner otherwise.

**Nothing to price at the hook**: unlike attrition and rotation, the game hands over a
manpower figure already.

No signature is recorded for it. The compiler gave it a register convention - the unit in
`eax`, the casualties on the stack - so it cannot be written as an ordinary function, the
same reason `CCountry::IsEnemy`'s second overload has none.

### Attrition may never run in this build

`ApplyAttrition` has **exactly one caller**, and it is behind
`if (g_CCurrentGameState->field_0xDA4)` at `0x1BB3E8` in `CUnit::UpdateDaily`. That byte
is zeroed when the game state is constructed and nothing was found that sets it.

The search is not conclusive - `+0xDA4` is a common displacement and the global is loaded
in thousands of places, so it cannot be scanned cleanly - but the shape is exactly a
leftover development switch, zeroed at construction and gating a whole mechanic. The same
byte also gates the transport overload check, so if it is a switch it is one over the
end-of-day unit upkeep rather than over attrition alone.

**Settle it in a game, not here**: if `$ATTRITION$` never leaves zero for an army sitting
in hostile or unsupplied territory, the gate is never opened and whatever attrition
players see comes from somewhere else entirely - the supply system is the obvious
candidate.

### Why these two are averaged rather than projected

Rotation is a rate, so one day of it projects honestly over a month. These two are not:
attrition depends on where the army is standing, and trickleback only happens when
somebody is being shot at. BiceLib keeps 30 days of each and reports the average day
times a month, which starts rough and settles.

## The `country` block of defines.lua

`CDefines +0xCC` points at it, one dword per entry in file order, x1000 - the same shape
as the `economy` block at `+0x9C`.

**Anchored at both ends rather than counted from one.** Pairing each fetch of `+0xCC`
with the read that follows it names **38 of the block's 43 entries**, from `CORE_LOSE` at
`+0x0` to `SPY_MILITARY_INTEL_LOCAL_TIME_BASE` at `+0xA8`, with the stride holding all the
way through. `PEACETIME_MANPOWER_ROTATION_LOW_SUPPLY_FACTOR` is entry 30 at `+0x78`, read
at `0x1BB184`, which is what tied rotation's low-supply scaling to the comment the mod's
own `defines.lua` puts on that line. The five with no reader found (4, 9, 10, 11, 35) are
named from their place in the file alone.

## The tooltip

`0x2D0540`, `__cdecl`, taking the string to build and the country's tag. The only
reference to `MANPOWER_DETAILS_IRO` in the image.

It reads `+0xA9C` and `+0xAA0`, formats each with `FormatFixedPoint` (`0x65ACA0`,
`__stdcall`, `ret 0xC`: the value over a thousand with as many decimals as asked for, no
separators), and replaces `$NEED$` and `$USED$`. **The whole thing exists twice**, once
with two decimals and once with one, chosen at `0x2D0639` by whether the need reaches
10000 - which is why `0x2D0885`, the first call after both halves converge, is where
BiceLib adds its own variables.
