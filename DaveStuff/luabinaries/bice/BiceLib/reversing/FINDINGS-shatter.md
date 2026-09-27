# Shattering, and being removed from the game

Two different things happen to a land unit that loses badly: it **shatters** and reappears
under its theatre, or it is **removed from the game** outright. They are decided in
different places, on different grounds, at different moments - which is why a surrounded
unit is not reliably destroyed.

## Shattering is a strength check, and nothing else

`CUnit::SettleCombatDamage` (`0x1C3820`) is where a unit takes the damage a combat tick
dealt it. After walking its regiments through `CSubUnit::SettleDamage`, adding the
casualty trickleback and charging the officer loss, it does this:

    strength = sum(regiment->strength)              // +0x5C over CUnit::regiments
    fraction = strength * 1000 / GetTotalStrengthCeiling()
    if (fraction < CUnit::ShatterThreshold(unit))
        CCountry::ShatterUnit(owner, unit)

**It never looks at where the unit is**, who controls the province, or whether anything
has it surrounded. A unit that crosses the threshold shatters at that moment, wherever it
is standing.

### The threshold

`CUnit::ShatterThreshold` (`0x1C3140`), in per mille of full strength:

    t  = min(1000 - 500 * national / 1000, 500)     // national = CCountry +0xD4
    t -= leader->skill * 10                          // CLeader +0x70
    t -= unitStat * 3 / 1000                         // CUnit virtual slot 22

So with no national modifier the base is **50%**, and every point of leader skill lowers
it by one percentage point.

**The 500, 3 and 10 are baked into the executable, not `defines.lua`.** They are three
globals at `0x16887AC`, `0x1688794` and `0x1688760`, each filled by a static initialiser
of the shape `_ftol2_sse(floorf(500.5))`, `floorf(3.5)`, `floorf(10.5)`. Nothing a mod
does can move them - the only lever it has on shattering is the national modifier at
`CCountry +0xD4`, **which has not been identified**, and the leader's skill.

`ShatterThreshold` reads `leader_ptr` (`CUnit +0x12C`) and dereferences `+0x70` with **no
null check**, so either every unit always has a leader object or there is a guard further
up that has not been found.

### What shattering does

`CCountry::ShatterUnit` (`0x1007B0`) picks the unit's new home: the country's acting
capital, or - if the unit's current province has a supply depot whose controller is not an
enemy - that depot's province. It then walks `oob_level` up the order of battle, which is
what puts the unit back under its theatre command.

## Removal is a retreat with nowhere to go

`CUnit::RetreatFromCombat` (`0x165760`) runs when a combat ends and this unit has to fall
back. It is called from three places in the combat code.

    push edi                          ; the unit
    call 0x1C5D50                     ; FindRetreatProvince -> eax
    mov  esi, [ebp+8]                 ; the combatant
    mov  ecx, [esi+0x3C]              ; its combat
    mov  eax, [edi+0x130]             ; unit->current_province_ptr
    cmp  [ecx+0x18], eax              ; is the combat in the unit's own province?
    je   ...
    mov  [esp+0x10], eax              ; if not, fall back to where it already is
    ...
    cmp  [esp+0x10], ebx              ; ebx is 0 - is there a destination at all?
    je   0x165B3C                     ; no -> a message, then the unit is removed

With a destination it records it, sets `disengage` and sets `retreat`. **Without one the
unit is removed from the game** (`CGameState::RemoveUnit`, `0x284E40`), after a block that
builds the notification. Both of this function's two removal sites are that same ending;
they differ only in which message is shown.

### The search

`CUnit::FindRetreatProvince` (`0x1C5D50`) walks the provinces adjacent to the unit's own,
over the path node's edge array, and keeps the **best scoring** one. A candidate has to be
passable and to pass the unit's virtual slot 13; its score is then built from *its* own
neighbours:

| the candidate's neighbour is | |
| --- | --- |
| under the unit owner's control | **+1000** |
| under nobody's enemy control | **+500** (`g_RetreatNeutralNeighbourScore`) |
| under an enemy's control | **the running total is halved** |

The highest score wins, and it has to clear a floor. **Nothing qualifying means null**, and
the unit is destroyed - which is the shape of the observed behaviour: lose the province you
are in and the one you were heading for, and what is left either fails the filter or scores
too low.

Rebels come first and separately: an owner tag of `REB` returns null outright unless
`0x286C10` finds them somewhere with a flag set, so a rebel division with nowhere to belong
is removed rather than retreated.

### What makes a province unavailable

`CUnit::CanMoveTo` (`0x1C2BA0`, virtual slot 35) refuses a province outright when it is
controlled by an enemy **and** the unit's strength fraction is below the same
`ShatterThreshold`. `CPathFind::MayStep` (`0x1A2700`) applies the same test, and the two
messages the interface shows for it are `UTM_MAY_SHATTER` and `UTM_NOT_LEGAL_RETREAT`.

So the threshold does two jobs: below it a unit shatters when hurt, and below it a unit
may not push into enemy ground.

## Why a surrounded unit shatters rather than being destroyed

The two tests run at different times:

| | when | on what |
| --- | --- | --- |
| shatter | every damage settlement | strength fraction alone |
| removal | only when the unit must retreat | whether any destination exists |

A surrounded unit is still taking damage, so the shatter test runs against it every tick.
If its strength crosses the threshold it shatters **there and then** - it never reaches the
retreat code that would have destroyed it. Being surrounded only removes a unit if it
survives the combat with strength to spare and *then* has nowhere to go.

That is the whole of the answer to "logically, a surrounded unit should be completely
removed": the game agrees, but only ever asks the question after the strength check has
already had its chance to take the unit off the map.

## A decompiler artifact worth knowing about

Ghidra decompiles `0x165760` with a local `CProvince *unaff_ESI` and tests
`unaff_ESI == 0`, which reads exactly like "the retreat destination is null" - the right
conclusion for the wrong reason. At the call site `mov ecx, esi` makes ESI the **unit**,
not a province. The destination is in `[esp+0x10]` and only the disassembly shows it.

## And a padding trap, hit twice now

`RetreatFromCombat` was first written down as leaving its stack argument for the caller to
clean, on the strength of a `ret` with no immediate. **That `ret` belongs to the next
function.** `CCombatant::RetreatAllUnits` follows it with no `int3` between the two, so
scanning forward for the next padding run walks straight past the end and reports the
wrong function's return. It is an ordinary `__thiscall` ending `ret 4`, on five paths.

The give-away was in the caller all along: `RetreatAllUnits` pushes the side inside a loop
and never adjusts `esp`, so the callee must be cleaning - anything else would walk the
stack up by four bytes per unit.

This is the same trap as `CEU3BitmapFont::Load` and `LoadGlyphs` in `FINDINGS-text.md`.
**Two functions with no padding between them are normal, and `reversing/image.py`'s
`functionStart` and any hand-rolled padding scan both lie about where such a function
ends.** Check the `ret` the callers imply.

## Removal really is destruction

`CGameState::RemoveUnit` (`0x284E40`) unlinks the unit from everything holding it - its
country's units, its province, its parent's `Children` in the order of battle, plans and
orders, the interface's selection - takes its regiments off it through
`RemoveRegimentFromUnit`, and then calls **the unit's own scalar deleting destructor**,
`unit->vftable->vf_0(1)`. The object is freed, not handed anywhere.

## What is still open

- **`CCountry +0xD4`**, the national value that scales the shatter threshold's base.
  Everything else in that formula is named.
- The virtual at slot 13 that filters retreat candidates, and the test at `0x0EFA00` that
  lets a neighbour score the full 1000 without being the owner's.
- What `CGameState::RemoveUnit`'s two flag arguments select.
