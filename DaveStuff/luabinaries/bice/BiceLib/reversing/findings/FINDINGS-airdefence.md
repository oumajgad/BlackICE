# The defence stats: parsed, stored, displayed - and never used to defend

**`air_defence`, `sea_defence` and `surface_defence`.** The file is named for the first because that is the question that started it; the naval pair was asked a few hours later and is in *`sea_defence` too*, below.

Read 2026-10-05, from `TODO.md`: *"Air defence stat is allegedly bugged. Allegedly it doesnt
use the fixed point system OR it is 1 magnitude too low (divided by 10 essentially). Figure
out what is going on."*

## In one line

**Both hypotheses are wrong, and the stat is worse off than either of them would make it.**
Air-to-ground and air-to-air alike: see *Air-to-air*, below, which was asked as a separate
question and needed a separate method.
`air_defence` is parsed by the same reader as its 43 sibling stats, stored in the same scale
and divided by the same 1000.0 for display. It has **no consumer in any combat path**: the
only combat function in the image that reads it is `CBomberCombatant::FireUnit`, which
multiplies it by the target's `combat_defend_product`, writes it back to its own frame slot,
and never reads it again. Every air and bombing shot is instead judged against a flat
`CHANCE_TO_AVOID_HIT_AT_NO_DEF` - 70% in BlackICE - while the land model's
`BASE_CHANCE_TO_AVOID_HIT` (88%) and its defence-slot mechanic are reached only through
`CUnit::RollToHit`, which has **exactly one caller in the image** and that caller is
`CLandCombatant::FireUnit`.

So an anti-air brigade's `air_defence = 25` does nothing at all; its `air_attack = 22` is the
live half of the pair. `confirmed` for the code paths named below, `likely` as a statement
about the whole image - the bound is in *What is not established*.

## The two hypotheses, answered off the bytes

### "It doesn't use the fixed point system" - no, and `air_attack` is the control

`CSubUnitDefinition::LoadKey` (`0x1A3C80`) parses `air_defence` with exactly the same four
instructions it uses for `air_attack`:

    air_defence (+0x128)                     air_attack (+0x140)
    0x1A42C5  mov eax, [ebp + 8]             0x1A439B  mov edx, [ebp + 8]
    0x1A42C8  lea edx, [esp + 0xC8]          0x1A439E  lea ecx, [esp + 0xD0]
    0x1A42CF  push edx                       0x1A43A5  push ecx
    0x1A42D0  add eax, 0x228                 0x1A43A6  add edx, 0x228
    0x1A42D5  push eax                       0x1A43AC  push edx
    0x1A42D6  call TokenToFixedPoint         0x1A43AD  call TokenToFixedPoint
    0x1A42DB  mov eax, [eax]                 0x1A43B2  mov eax, [eax]
    0x1A42DD  mov [edi + 0x128], eax         0x1A43B4  mov [edi + 0x140], eax

Same reader, same scale, no post-multiply on either. **43 of the 45 numeric stores in that block have
`TokenToFixedPoint` as the call immediately before them** - it is `atoi(text) * 1000 +
fraction` (`0x669550`, confirmed) - so `air_defence = 25` becomes 25000, exactly as `air_attack = 22` becomes 22000.

**The positive control for the scan that says so**: the same walk finds the two stores in
that block that are *not* a bare fixed point. `distance` (+0x14C) is
`__allmul(value, 100000)` then `__alldiv(..., 1000)`, so it is stored x100000 and not x1000
(`0x1A4607`, `0x1A4615`); `+0x194` uses `atoi` and no fraction at all (`0x1A3D53`). A scan
that can see those two differences and reports no difference for `air_defence` is not a scan
that was blind.

### "One magnitude too low" - no, and the display is uniform too

The unit stat panel's builder (the function that pushes `'Overview_Military'` at `0x3A9B15`)
converts every stat through one constant:

    mov  eax, [ebx + 0x58]            ; CSubUnit::sub_unit_definition_ptr
    movd xmm1, [eax + 0x128]          ; air_defence
    cvtdq2ps / cvtss2sd
    divsd xmm1, xmm0                  ; xmm0 = [0x160A300] = 1000.0
    cvtsd2ss
    movss [edi + 0x9EC], xmm1

`air_defence` at `0x3AA009` sits in a run of ten sibling stats that each reload `+0x58` and
divide by the same `xmm0` - `+0xE8`, `0x120`, `0x124`, `0x128`, `0x12C`, `0x130`, `0x134`,
`0x138`, `0x13C`, `0x140` - with a 0xBC stride in the destination (`+0x350`, `+0x40C`, ...,
`+0x9EC` for air defence, `+0xAA8`). Two sibling
builders do the same for the naval and air panels (`0x3ABE5C`, `0x3ADB42`). **There is no
per-stat divisor anywhere in the three**, so nothing here can be a factor of ten out.

`0x160A300` is a virtual address and reads as the double `1000.0`. (Reading it as an rva
gives `0.0`, which is trap 1 arriving in a place where it would have looked like a finding.)

## The census: who reads `CSubUnitDefinition + 0x128`

A bare `[reg + 0x128]` is **812 accesses in 450 functions** - because `CUnit + 0x128` is
`owner_id`, and comparing owner ids is something combat code does constantly. Two of the
three reads in `CBomberCombatant::ApplyCombatModifiers` that looked like air defence at first
(`0x1619EC`, `0x161E5E`) are exactly that: the second pairs `+0x124`/`+0x128` as tag letters
and id and indexes the country array with it.

So the census is by **provenance**: keep a read only where the **nearest write** to the
register loaded it from `CSubUnit + 0x58` or `CUnit + 0xC8`, the two definition pointers. That
leaves **7 sites**:

> *Corrected 2026-10-05, later the same day.* This first said 10, from a filter that accepted
> a `+0x58` load **anywhere** in the preceding 60 instructions without checking whether the
> register had been overwritten since. It had been, in three cases. See *The filter had a
> false-positive mode*, below; the negatives are untouched, because a filter that over-reports
> cannot hide a reader.

| rva of the read | in | what it is |
| --- | --- | --- |
| `0x160D44` | `CBomberCombatant::FireUnit` (`0x160B90`) | **the only combat read, and it is discarded** |
| `0x1D2D9C` | `CAir` slot 40 (`0x1D2D80`) | the air unit's defence getter, the sibling of `CArmy::GetDefenceValue` |
| `0x3AA009` | `'Overview_Military'` builder (`0x3A9B15`) | the land unit stat panel |
| `0x3ABE5C` | sibling builder (`0x3AB9E2`) | the naval panel |
| `0x3ADB42` | sibling builder (`0x3AD681`) | the air panel |
| `0x321B46`, `0x3242CD` | `BuildUnitStatsTooltip` (`0x31F460`, confirmed) | the unit stats tooltip; see the note below |

So: **one dead combat read, one slot-40 getter, five display sites.** Plus one the
provenance filter cannot see, already in the record: the AI's per-brigade power figure, where
an air brigade scores `air_attack + air_defence + 500`. That is the shape of read this filter
misses - **the definition arrives as an argument** - which is why the seven are a lower bound
and not a closed set. (It is also why the `CEU3AI` row that used to be in this table was
doubly wrong: the AI does read the stat, just not there.)

`functionStart` does not answer for the last two - it returns `0x3208E7` and `0x323CD1`,
neither of which is an entry (trap 2). They are both inside **`BuildUnitStatsTooltip`**,
which runs `0x31F460` to the `int3` run at `0x325994`, 0x6534 bytes: measured, not assumed.
So they are display as well.

**Only one census site is in the combat code at all.** The combat classes live in
`0x160000`-`0x180000`; one site falls in that range, and it is the dead one. Everything else
is a tooltip, a panel, a getter whose callers are not combat, or the AI.

## The one combat read, and why it does nothing

### Where it sits

`CBomberCombatant::Attack` is slot 15 of the `CBomberCombatant` vftable (`0x15C45DC`), rva
`0x1615C0`, 0xB8 bytes. It walks `this->units` (the CList at +0x40), and for each unit walks
that unit's regiments (`CUnit + 0x38`) calling **`FireUnit(this, wing)` at `0x161657`** -
the only call to `0x160B90` in the image.

`CBomberCombatant::FireUnit` (`0x160B90`, 0xA25 bytes, one `ret 8`) then:

1. draws one target uniformly from the attacker's own target array - `Random() %
   [this + 0xB0]`, element at `[this + 0xB4 + i*4]` (`0x160BD3`, `0x160BDE`). The elements
   are `CSubUnit*`: the code reads `+0x58`, `+0x5C` and `+0xA8` off them.
2. picks the attack stat by asking the firing wing's **order** (slot 33 on `CUnit + 0xB0`):
   the ground-attack arm splits `soft_attack`/`hard_attack` by the target's `softness`
   exactly as land combat does (`0x160C16`-`0x160C77`), another arm takes `hard_attack`
   alone, and the naval arm takes `sea_attack` scaled by command effect id 0x11.
3. reads **the target's `air_defence`** into the frame slot `[ebp - 0x10]`:
   `0x160D41 mov eax, [ebx + 0x58]` / `0x160D44 mov eax, [eax + 0x128]` /
   `0x160D4A mov [ebp - 0x10], eax`. The ground-attack arm reaches the same store through
   `CUnit + 0xC8` instead (`0x160CAC`), so both arms set it.
4. computes the shot count the land way - `attack * CSubUnit::combat_attack_product / 1000 /
   1000`, remainder as a chance at one more shot - and then, **once per shot**:

       0x160E58  mov  eax, [ebx + 0x54]        ; the target's combat_defend_product
       0x160E5B  imul dword ptr [ebp - 0x10]   ; x air_defence
       0x160E66  call __alldiv                 ; / 1000
       0x160E6B  mov  [ebp - 0x10], eax        ; and back into the slot

5. rolls: `Random() % 100 < CHANCE_TO_AVOID_HIT_AT_NO_DEF / 1000` -> the shot is avoided
   (`0x160F23` reads the define, clamped to 99000 at `0x160F26`; the compare and branch are
   `0x160FDE`/`0x160FE0`).
6. on a hit, rolls strength and organisation dice, scales a ship's by `hull`, and applies
   `BOMB_REGIMENT_DAMAGE_MODIFIER` / `BOMB_SHIP_DAMAGE_MODIFIER` /
   `BOMB_WING_DAMAGE_MODIFIER` by target kind (`0x161274`, `0x16138D`, `0x16141A`).

The air defence value computed at step 3 and rescaled at step 4 is **read by nothing but
step 4 itself**. It never reaches the roll in step 5, the damage in step 6, or any callee.

### Why that claim is not a decode artefact

A dead-store claim read off a linear sweep is worth nothing if the sweep desynchronised, so
four checks, each able to fail:

- **Accesses to the slot: exactly 5**, listed above - one init to zero, one arm's zero, the
  air defence store, the self-multiply, the store back.
- **No esp-form alias.** The function has `push ebp; mov ebp, esp` and **zero** `[esp...]`
  memory accesses in 830 instructions, so the four bytes cannot be reached under another
  name. (esp was tracked anyway: the slot is `esp + 0x40` at the store, and nothing
  references it.)
- **The decode is self-consistent.** 829 instructions between the entry and the single `ret`
  at `0x1615B2`; 72 intra-function branch targets, **all 72 on an instruction boundary**;
  recursive descent from the entry reaches **829 of 829** - so the sweep neither invented a
  block out of data nor missed one.
- **The extent is right.** `CBomberCombatant::Attack` begins at `0x1615C0`, immediately after
  the `int3` padding that follows the `ret`.

### Why the compiler kept it

Because it is not dead in the narrow sense: the store at `0x160E6B` has a reaching use - the
`imul` at `0x160E5B` on the *next* iteration of the shot loop. It is a loop-carried variable
whose only consumer is itself, and MSVC's dead-store elimination does not remove a store that
something reads. The cycle is useless; each individual store is not. That is what the source
looked like: a local assigned from the stat, rescaled per shot, and then simply left out of
the roll that was supposed to use it.

## What the air paths use instead of a defence value

| slot 15 `Attack` | rva | length | attack stat | its avoid chance |
| --- | --- | --- | --- | --- |
| `CBomberCombatant` | `0x1615C0` | 0xB8 | via `FireUnit` | `CHANCE_TO_AVOID_HIT_AT_NO_DEF` (`0x160F23`) |
| `CAirCombatant` | `0x16D750` | 0x779 | `air_attack` (`0x16D7F3`, `0x16D81F`) | `CHANCE_TO_AVOID_HIT_AT_NO_DEF` (`0x16DAEE`) |
| `CNavalTargetCombatant` | `0x1631E0` | 0xBB3 | `air_attack` (`0x163273`) | `CHANCE_TO_AVOID_HIT_AT_NO_DEF` (`0x1634D8`) |
| `CLandTargetCombatant` | `0x1637C0` | 0x5D3 | `air_attack` (`0x163831`) | `CHANCE_TO_AVOID_HIT_AT_NO_DEF` (`0x163AB2`) |
| `CGroundTargetCombatant` | `0x1630E0` | 0x23 | - | - (a forwarder; see below) |
| `CLandCombatant` | `0x16B340` | - | via `FireUnit` (`0x16ADC0`) | **`CUnit::RollToHit`** |

All four air-side reads of the define are the same five instructions - the defines singleton,
`+0xAC` for the `military` block, `+0xC`, and a clamp to 99000 (99%) - and **none of the four
reads `BASE_CHANCE_TO_AVOID_HIT` at `+0x8`**.

**`CUnit::RollToHit` (`0x1CD250`) has exactly one caller in the image**, at `0x16B0FD`, inside
`CLandCombatant::FireUnit`. That is the function that chooses between the two defines by
`CUnit::defences_used`, and it is the only place a defence stat buys anything. So the
mechanic the air stats would have fed is land-only by construction, not by a missing branch.

With BlackICE's `common/defines.lua` - `BASE_CHANCE_TO_AVOID_HIT = 88.0`,
`CHANCE_TO_AVOID_HIT_AT_NO_DEF = 70.0` - every unit under air attack sits permanently on the
worse of the two: **a flat 30% chance to be hit per shot**, whatever its air defence, and
whether it is a brigade, a ship or a wing.

`CGroundTargetCombatant::Attack` is 15 instructions: it resets its `units` list and forwards
to `0x163110` and `0x162370`. Neither reads a definition stat.

### The province's static AA is a third mechanic, and also not this stat

`0x162370` (0x445 bytes) is called from **all three** target-side `Attack` bodies -
`0x1630F9`, `0x163223`, `0x163803` - and is the only one of them that reads a define other
than the avoid chance: **`STATIC_AA_SCALE`** (`military + 0x22C`, read at `0x16245F`). It
takes a value from `[side + 0x114]` then `+0x258`, scales it by a `(1000 + modifier) / 1000`
term and then by `STATIC_AA_SCALE`, and adds the result to what the mobile units contribute.

So anti-air in this build has three channels and `air_defence` is in none of them: units fire
at aircraft with **`air_attack`**, the province fires through **`STATIC_AA_SCALE`** and its
own building value, and the target's **`air_defence`** is read once and dropped.

## Air-to-air: asked separately, and the answer is also no

The bombing answer does not settle this one, because in the bombing path the `air_defence`
read is **not** in `CBomberCombatant::Attack` - it is in the `FireUnit` helper one call down.
So the same question about air-to-air has to be asked of the **call closure**, not of one
function.

Closure from six recorded roots - `CAirCombat::Tick`, `CCombat::Tick`, `CAirCombatant`'s
slot 15, slot 19 and `CollectTargets`, and `CCombatant::ApplyLosses` - direct calls to depth
3, library helpers pruned: **529 functions**. Inside it, **56 accesses to `[reg + 0x128]`,
and not one of them is `air_defence`.** The four in the air path are all `CUnit::owner_id`,
and each says so the same way:

    0x16CD15  mov edx, [ecx + 0x124]          ; the owner tag's letters
    0x16CD1B  mov ecx, [ecx + 0x128]          ; the owner id
    0x16CD2B  mov edx, [edx + 0x16c]          ; [0x1A855A4] -> the country array
    0x16CD31  mov ecx, [edx + ecx*4]          ; and index it

The other four in `CAirCombatant::ApplyCombatModifiers` (`0x16C917`, `0x16CEBC`, `0x16CF06`)
and the rest of the closure are the same idiom or belong to unrelated classes. **So an
aircraft's `air_defence` is not read in air combat at all** - `CAirCombatant::Attack` does not
even compute it, where the bomber's `FireUnit` at least computes it before dropping it.

`confirmed` for the closure; the one gap is that it follows direct calls, so a virtual call is
a hole. The virtual worth naming is the only one that does read the stat - `CUnit` slot 40,
`CAir::GetDefenceValue` (`0x1D2D80`) - and `slotcalls.py 40` puts its 37 call sites in 31
functions, **none of them in the `0x160000`-`0x180000` combat range**.

### What an air fight does depend on

The positive half of the same sweep. `CAirCombatant::Attack` uses `air_attack` scaled by the
wing's `combat_attack_product` (+0x50, at `0x16D825`), `AIR_DOCTRINE_INCREASE` (`0x16D787`),
the flat avoid chance (`0x16DAEE`), and `AIR_COMBAT_ORG_DICE_SIZE` /
`AIR_COMBAT_STR_DICE_SIZE` (`0x16D9FD`, `0x16DA03`). Everything else that shapes the fight is
in **slot 19**, `CAirCombatant::ApplyCombatModifiers`, which reads nine named defines:

| define | at |
| --- | --- |
| `AIR_STACKING_PENALTY`, `AIR_STACKING_PENALTY_MAX` | `0x16C747`, `0x16C77B` |
| `BASE_PROXIMITY_BONUS` | `0x16CB70` |
| `INTERCEPT_ATTACK_BONUS` | `0x16CC27` |
| `AIR_SUP_DEFEND_BONUS` | `0x16CCD5` |
| `RADAR_COMBAT_IMPACT` | `0x16D080`, `0x16D34E` |
| `COMBAT_SUPPLY_LACK_IMPACT` | `0x16CE3A` |
| `COMBAT_DISSENT_IMPACT` | `0x16CFA4` |
| `PRIDE_BONUS_EXP` | `0x16C9F8` |
| `RIVER_CROSSING_PENALTY` | `0x16D1DB` - and that it is read at all in an air fight is odd enough to be worth a look |

**And there is a sting already in the record.** Those modifiers land on a wing's
`combat_attack_product` (+0x50) or `combat_defend_product` (+0x54), and `CSubUnit + 0x54`'s
entry establishes - `likely`, with a live hook behind it - that for naval, air and bombing the
**defence side of the product reaches nothing but the `combat_status` window**. Taken with
this section, air-to-air has no defensive term that changes the simulation at all: not the
stat, and not the defence half of its modifiers. An aircraft's survivability is its
organisation and strength pool plus whatever lands on the attack side of its own shots. That
pair of claims is worth one live battle to confirm, and the check is already written in
`findings/FINDINGS-combat3.md`.

One caveat on the define sweep itself: the detector pairs a `[... + 0xAC]` block load with the
next displacement read, and it mis-pairs once - `PARATROOP_DROP_ORG_MULT_PLANE` at `0x16DE80`
is really `add [eax + 0xa8], esi`, a write to `CSubUnit::pending_strength_damage`. Every
define named above was re-read in place.

## What this means for the mod's numbers

`units/anti_air_brigade.txt` carries `air_defence = 25` beside `air_attack = 22`. On this
reading the first number is inert and the second is the whole anti-air contribution: an AA
brigade shoots at aircraft through its own side's `*TargetCombatant::Attack` using
`air_attack`, and contributes nothing to how hard its stack is to hit.

The stat is not inert *everywhere*, which is exactly why it looks live: it is printed in the
unit panel, returned by `CAir`'s slot 40, and counted by the AI (`air_attack + air_defence +
500` for an air brigade). So raising it still changes what the AI builds and what the tooltip
says, and changes nothing about any battle. **Any mod balance reasoning that treats
`air_defence` as survivability against air attack is reasoning about a number the simulation
never reads.**

## What the `combat_defend_product` it is multiplied by is made of

Asked separately, because the discarded value is `air_defence x the target's
combat_defend_product / 1000` and the second factor is the part a mod can actually move.

**The mechanism was already recorded** - `CSubUnit::AddCombatModifier` (`0x1AC300`) appends a
12-byte `{id, attack, defence}` record to the CList at `CSubUnit + 0x40` and folds the two
halves into the two products, and `findings/FINDINGS-combatmods.md` §3 has the base slot 19
resetting both to 1000 every tick. Per term:

    product *= max(1000 + value, g_CombatModifierFloor) / 1000

with `g_CombatModifierFloor` = **10**, from `(int)floor(10.5f)` at `0x160A680`, initialised at
`0xCC36F0` - also already recorded, in `findings/FINDINGS-combat3.md` §5. So one term can
never take a product below x0.01, and the terms multiply rather than add.

**What was not recorded is which of the target side's terms carry a defence half at all.**
`CTargetCombatant::ApplyCombatModifiers` (`0x1627D0`) is one body shared by all three target
combatants and has eleven call sites; §8 of the census names every id and gives formulas, but
states the attack/defence split only for the three ids that body computes itself. Resolved
here by modelling the argument slots rather than the pushes - **the call does not push its
values**:

    push ecx            ; reserve slot A (esp = S-4)  -> DEFENCE, [ebp+0x10]
    mov  ecx, esp       ; ecx = &A
    mov  [ecx], 0       ; A = 0
    push ecx            ; reserve slot B (esp = S-8)  -> ATTACK,  [ebp+0xc]
    mov  [ecx], eax     ; ecx is STILL &A -> A = eax
    mov  eax, esp       ; eax = &B
    push 0x15           ; the id
    mov  [eax], 0       ; B = 0
    call CSubUnit::AddCombatModifier

The aliasing is the trick: between the two reservations `ecx` still points at the *first*
slot, which is why reading "the push furthest from the call" gives `ecx` every time and the
census file says the values cannot be read off the pushes. The model's control is the two ids
§8 derived independently - `BM_POOR_SCREEN_PENALTY` and `BM_FORT_MODIFIER` - and it returns
`attack=0` for both, matching.

| id | site | defence half |
| --- | --- | --- |
| `BM_DISSENT` 0x00 | `0x162DD6` | same value as attack: `-(COMBAT_DISSENT_IMPACT * dissent*10/1000)/1000`, both written from one `eax` |
| `BM_LEADER_BONUS` 0x01 | `0x16305E` | same as attack |
| `BM_DIFFICULTY` 0x02 | `0x1629C3` | same as attack |
| `BM_DIVISION_PENALTY` 0x05 | `0x162E12` | same as attack, `-(Σ regiments*10 - tech +0x6C)` |
| `BM_EXPERIENCE` 0x06 | `0x162B4D` | same as attack, the regiment's or wing's **own** experience |
| `BM_MISSION_EFFICIENCY` 0x07 | `0x162BE0` | same as attack |
| `BM_RADIO` 0x09 | `0x162D05` | same as attack, a pure technology figure |
| `BM_FORT_MODIFIER` 0x0C | `0x162A69` | **defence only** - `+100` per whole fort level, the 100 a compiled-in `(int)floor(100.5f)` |
| `BM_LACK_OF_SUPPLIES` 0x10 | `0x162CD6` | same as attack |
| `BM_POOR_SCREEN_PENALTY` 0x15 | `0x1629FE` | **defence only** - minus the screens/capitals fraction |
| `BM_NIGHT_MODIFIER` 0x1B | `0x162EF5` | **attack only** - `add(esi, 0)` at `0x162EE7`/`0x162EEF`; night does not protect a bombed unit |

Ten of the eleven move the defend product; night is the one that does not. For the bombing
side's own product the same model gives two attack-only terms, `BM_SURPRISE_BONUS`
(`0x161BCD`) and `BM_WEATHER` (`0x162162`), both agreeing with §6 and §7's naval and air
readings of the same ids.

**The consequence, and it is sharper than the air-defence one.** Two of those eleven are
*defence only*, so their entire contribution is to `+0x54` - and `+0x54`'s only reader in the
bombing code is the `imul` whose result is discarded. On this reading **a fort level does
nothing against bombing**, and neither does screen cover for a bombed fleet, while both still
append a modifier record to `CSubUnit + 0x40` and so still show up as a row in the battle
display. That is a tooltip line with no mechanic behind it, which is a more checkable claim
than anything about the stat itself.

### What I could not close: whether `+0x54` has a third reader

The whole paragraph above is conditional on `+0x54`'s readers being the two now known, and a
static census did **not** settle it. `+0x54` is a dense displacement, and every structural
filter I tried either kept pages of unrelated classes or failed its own control: requiring the
same register to be read at both `+0x50` and `+0x58` **excludes the known reader at
`0x160E58`**, because in `FireUnit` the defend product is read off the target while the attack
product is read off the firing wing - two different registers. A filter that drops a true
positive cannot be used to argue a negative (`TRAPS.md`'s closing section).

So the instrument is a hook, not a sweep - the same conclusion the census file reached for the
neighbouring question. A write watchpoint is no use here because the field is written every
tick; what is wanted is a **read** watchpoint on one bombed regiment's `+0x54` through a
bombing run, and the expected answer is two hits per shot-loop iteration plus the
`combat_status` refresh.

## `sea_defence` too, and `surface_defence` with it - reported by a player, confirmed

Asked on 2026-10-05 after the air result: another player thinks `sea_defence` is broken as
well. **They are right, and it is one step worse than `air_defence`** - that one is at least
read before being thrown away, where neither naval defence stat is read in a combat function
at all.

Generalising the census to any stat (`dvd_statcensus.py <displacement>`, one command) gives:

| stat | reads with a definition pointer in hand | of those, in the combat classes |
| --- | --- | --- |
| `air_defence` +0x128 | 7 | **1** - the dead one in `CBomberCombatant::FireUnit` |
| `sea_defence` +0x160 | 2 | **0** |
| `surface_defence` +0x174 | 2 | **0** |
| `hull` +0x178 | 11 | **5** - three in `CNavalCombatant::Attack`, two in the bomber's `FireUnit` |
| `sea_attack` +0x168 | 12 | **3** - two in `CNavalCombatant::Attack` |
| `positioning` +0x184 | 4 | **2** - `UpdatePositioning` and `CSubUnit::PickTarget` |
| `visibility` +0x15C | 2 | 0, and `ShouldStartNavalCombat` reads it - combat *initiation*, not the fight |

`sea_defence`'s two readers are `CNavy::GetDefenceValue` (slot 40, `0x1D2C5C`) and the naval
unit stats panel (`0x3ABE3A`). `surface_defence`'s are `BuildUnitStatsTooltip` (`0x324185`)
and the air panel (`0x3ADAFE`). Display, a getter, and nothing else - the same shape as
`air_defence`. *(Counts corrected after the filter fix below; they were 3 and 3.)*

The call closure from the naval roots - `CNavalCombat::Tick`, `CCombat::Tick`,
`CNavalCombatant`'s slot 15, slot 19, `CollectTargets` and `UpdatePositioning`,
`CSubUnit::PickTarget`, `CCombatant::ApplyLosses`, **654 functions** - agrees: it holds 52
`[reg + 0x160]` accesses and **not one inside rva `0x160000`-`0x180000`**. All 52 are
`CUnit::in_game_idler_ptr`, which is `CUnit + 0x160`.

### The positive control, which is what makes this a result rather than a silence

A negative from a provenance filter is worth nothing without showing the filter can see a
positive in the same place. **It can, three times over, in the same function**: on
`CNavalCombatant::Attack` the identical filter finds `sea_attack` twice and `hull` three
times, and on the naval path it finds `positioning` in two more bodies. So if
`CNavalCombatant::Attack` read `sea_defence` off the same `[+0x58]` pointer it uses for
`sea_attack` and `hull`, this would have seen it.

### What does protect a ship

From `findings/FINDINGS-combatmods.md` §9's reading of `CNavalCombatant::Attack`, now with the
defence stats ruled out:

- **`hull` is the naval armour**, and it is a straight divisor rather than the land model's
  deflection threshold: `strDamage = strDamage * 1000 / hull`, and the same for organisation.
- **`positioning`** shapes target selection and widens both dice - and it is the *enemy's*
  stacking position penalty that widens them, so a crowded formation is easier to hit.
- the **attack side** of the combat-modifier product (`CSubUnit + 0x50`) multiplies the shot
  count; the defence side (`+0x54`) is the cosmetic one.
- the hit roll is the same flat `CHANCE_TO_AVOID_HIT_AT_NO_DEF`, read at `0x168116`.

**And that closes an open question in the record.** §9 ends "whether naval has the land
model's 'defences_used buys a number of shots' structure is not established". It does not:
`CUnit::RollToHit` (`0x1CD250`) has exactly one caller in the image and it is
`CLandCombatant::FireUnit`. The defence-slot mechanic is land-only, which is why none of the
three non-land defence stats has anywhere to be read.

### So the pattern, across all four

`defensiveness` and `toughness` are consumed by `CUnit::RollToHit` on land. `air_defence`,
`sea_defence` and `surface_defence` have no consumer, and their three paths each substitute a
flat define. **Whatever was intended, this build has exactly one defence mechanic and it
belongs to land combat.** For a mod that means the `sea_defence` and `surface_defence` lines
in `units/*.txt` are documentation, `hull` is the ship survivability dial, and
`air_defence` is inert everywhere.

## Land, checked the same way - and it is the one that works

Asked on 2026-10-05 after the naval pair: land has been the positive control for three
negatives, which is a reason to check it rather than a reason to trust it.

**The land chain is live end to end, and the last link is the one that mattered.** By the
morning's logic it was not enough to show `CLandCombatant::FireUnit` *reads* `defensiveness`
and `toughness` and *passes* them on - `CBomberCombatant::FireUnit` reads `air_defence` and
passes it into an `imul`, and that goes nowhere. So `CUnit::RollToHit` (`0x1CD250`) was read
out, and it **consumes its argument**:

    ecx = defence                       ; [ebp+0xc]
    esi = defence / 1000                ; whole slots
    if (Random() % 100 < (defence % 1000) * 100 / 1000) esi++    ; the fraction buys one more
    esi -= unit->defences_used (+0x15C) ; 0x1CD2C3
    if (esi <= 0)  chance = CHANCE_TO_AVOID_HIT_AT_NO_DEF   (military +0xC, 0x1CD318)
    else           chance = BASE_CHANCE_TO_AVOID_HIT        (military +0x8, 0x1CD2DA)
                   if (unit->slot 15()) chance += country->CTechnologyStatus->+0x8
                   unit->defences_used++                     ; 0x1CD310
    chance = min(chance, 99000) / 1000
    return (Random() % 100) >= chance   ; setge at 0x1CD34D - true is a hit

So the defence value really does buy a number of shots, exactly as `FINDINGS-combat.md` says,
and it is the **only** thing in the game that selects `BASE_CHANCE_TO_AVOID_HIT` over the
no-defence one. Land also gets a technology addition to the avoid chance that no other arm
gets.

### The whole stat block at once

| read in a combat function | not read in any combat function |
| --- | --- |
| `defensiveness`, `toughness`, `softness`, `armor`, `soft_attack`, `hard_attack`, `piercing_attack`, `air_attack`, `sea_attack`, `sub_attack`, `convoy_attack`, `shore_bombardment`, `hull`, `positioning`, `distance`, `air_detection`, `sub_detection`, `maximum_speed` | **`air_defence`** (read once and discarded), **`sea_defence`**, **`surface_defence`**, `combat_width`, `max_strength`, `default_organisation`, `default_morale`, `strategic_attack`, `suppression`, `radio_strength`, `visibility`, `surface_detection`, `range`, `transport_capacity`, and the build/cost stats |

`max_strength`, `default_organisation` and `default_morale` being absent is **not** a finding:
the land shot count uses `CUnit + 0xEC` and `+0xF4`, the per-unit products, not the
definition's own figures.

Two of the absences are worth a second look, and neither is settled here:

- **`combat_width` has no reader in any combat function** (21 reads, none in the range). That
  bears on `CCombatant + 0xB0 front_line`'s standing question - "what puts a unit on the front
  line; combat width is the obvious candidate and is not yet evidence". It is still not
  evidence, and now there is evidence the other way, at least for a direct read inside the
  combat classes. The nearest thing to a width *sum* is `0x1D648D`,
  `mov ecx,[ecx+0x58]; add esi,[ecx+0xE8]` looping over a unit's regiments inside `0x1D6420`,
  which is in the unit layer rather than the combat one. A lead, not an answer.
- **`strategic_attack` has none either** (15 reads, none in the range), so strategic bombing's
  damage does not come from the combat classes. Unread.

### Three of the "combat" readers are display, not simulation

Worth separating, because the table above counts functions by address range and two things in
that range only draw:

- **`CCombatant::SumSubUnitStrength`** (slot 11, `0x1662F0`) reads `defensiveness`,
  `toughness`, `soft_attack` and `hard_attack`. Its only consumer is the `combat_status`
  window. The census attributes those reads to `CCombatant::ApplyLosses` because that is what
  `functionStart` answers - **trap 2, on the one pair of functions this record has already
  corrected for it**: `ApplyLosses` ends with `ret 4` at `0x1662ED` and slot 11 starts at
  `0x1662F0` with no padding, and `image.retsBefore(0x1662F0, 0x1663CD)` is empty while from
  `ApplyLosses`'s entry it is two. So the read is slot 11's.
- **`0x16C240` and `0x16C340`** read the same four stats off `CUnit + 0xC8`. Each has exactly
  one caller - `0x17D0D7` and `0x17D1A7` - and both callers are past
  `CCombat::UpdateCombatStatusWindow` (`0x17BD70`), in the combat *window* code.

So of `defensiveness`'s four combat-range readers, **one is the simulation** and three draw a
number. That does not weaken the land result - `CLandCombatant::FireUnit` is the one - but it
is the difference between "read in combat" and "read by combat".

### The filter had a false-positive mode, and fixing it corrected this file

The provenance test accepted a register whose **nearest** write was not the `+0x58` load: it
scanned the whole 60-instruction window for any such load and ignored anything that had
overwritten the register since. The worked example is `0x1672E3` in
`CNavalCombatant::CollectTargets`, which the scan reported as a combat reader of
`suppression`: `eax` is loaded from `[edx+0x58]` at `0x1672C0`, consumed at `0x1672C9`, and
**reloaded from `[edx+0xB0]`** - the sub-unit's `unit_ptr` - at `0x1672CF`, so `[eax+0x130]`
is `CUnit + 0x130`.

`scripts/statcensus.py` now takes the nearest write only. It removed five spurious
combat-range rows (`suppression`, `fuel_consumption`, `completion_size`, one `armor`, one
`sub_attack`) and trimmed every total. **No negative moved**, which is the point worth keeping:
a filter that over-reports can invent a reader but cannot hide one, so the zero columns for
`sea_defence` and `surface_defence` and the one-site column for `air_defence` were never at
risk. What was at risk, and wrong, were the counts and two reader lists this file and three
field comments had already stated - all corrected.

## Corrections to the record

### `CSubUnit + 0x54` (`combat_defend_product`) has a second reader - and it is dead

The field's entry says **"Read at 0x56645E and nowhere else"**, and builds a careful
conclusion on it: that the defence side of the naval/air/bombing combat modifier census is
cosmetic, because its one reader only feeds the `combat_status` window. The live hook that
confirmed it counted 39,414 calls into `CCombatant` slot 11 with zero unexplained return
addresses.

**The enumeration is wrong and the conclusion survives.** There is a second static reader, at
`0x160E5B`, in `CBomberCombatant::FireUnit` - the `imul` in step 4 above. The register is a
`CSubUnit` on independent evidence: the same `ebx` is read at `+0x58` (definition), `+0x5C`
(strength) and `+0xA8` (pending strength damage). The live check does not contradict this,
because it hooked slot 11's callers and not this field.

And the conclusion is untouched, for a reason the old text could not have given: the second
reader's result is the discarded air defence value. So the defence-side product is still read
in exactly one place that changes anything, and that place is a number on screen.

### `CCombatant + 0xB0` (`front_line`) belongs to the land family, not the base

The entry describes `+0xB0` as a `CList<CUnit*>` with its count at `+0xB8`, which is what
`CLandCombatant::Attack` (`lea esi, [ebx + 0xB0]`, then a `+8` node walk at `0x16B3B0`) and
`CCombatant::PickTarget` (`[edi + 0xB8]` as the count, `[edi + 0xB0]` walked) both do. Both
are correct, and both are **land**.

The air and bombing combatants use those bytes for a target array instead, and the
allocation sizes settle which reading belongs to whom:

| class | `operator new` size | at |
| --- | --- | --- |
| `CLandCombatant` | **0xE4** | `0x17B4EB`, `0x17B51E` (`CLandCombat::CreateCombatants`) |
| `CAirCombatant` | **0x10B4** | `0x17BBBB`, `0x17BBF5` |
| `CBombTargetCombatant` family | **0x10B4** | `0x163DEB`, `0x163EBB`, `0x163F8B` |
| `CBomberCombatant` | **0x10E8** | `0x163DBB`, `0x163E8B`, `0x163F5B` |

`0x10B4 - 0xB0 = 0x1004`, so these carry **1024 pointers and a count**, and
`sizeof(CCombatant)` is `0xB0`. A land combatant is 0xE4 and has no room for any of it.

**The 1024 is confirmed, not arithmetic** - corrected 2026-10-05, later the same day, while
giving the classes struct records. `CAirCombatant::CollectTargets` bounds the index with
`cmp eax, 0x400` at `0x16D4C9` immediately before the store.

**And the two layouts are the opposite way round**, which the first version of this section got
wrong by generalising from the bomber:

| | |
| --- | --- |
| `CBomberCombatant` (0x10E8) | `target_count` at **+0xB0**, `targets[1024]` at **+0xB4** - `Random() % [side+0xB0]` then `[side+0xB4+i*4]` (`0x160BD3`, `0x160BDE`) |
| `CAirCombatant` (0x10B4) | `targets[1024]` at **+0xB0**, `target_count` at **+0x10B0** - `[ebx+eax*4+0xB0]` with the count read from `+0x10B0` (`0x16D4C3`, `0x16D4D0`, `0x16D4D7`), and `add ecx, 0xB0` to walk it at `0x16D529` |

Nothing forces them to agree: RTTI gives `CBomberCombatant : CCombatant` and
`CGroundTargetCombatant : CBombTargetCombatant : CCombatant`, so both arrays are **derived**
fields over the same 0xB0-byte base and each class picked its own order. The earlier wording
here read the bomber's order onto the whole family, which would have put a count where
`CAirCombatant` keeps `targets[0]`.

Two consequences worth keeping. **The air and bombing sides fight at regiment granularity** -
their arrays hold `CSubUnit*`, where the land front line holds `CUnit*`. And `front_line`
should move from `CCombatant` to `CLandCombatant` in the record, which the pipeline cannot
do: `mergeFindings` will not create a struct, and `CLandCombatant` has no struct record. That
is wave 14 brief A's blocker, with a new instance.

## Making the body readable: the two structs it needed

`CBomberCombatant::FireUnit` decompiled unreadably for one reason - **neither bombing class had
a struct record**, so Ghidra used the 4-byte stub `ReconstructClassesFromRtti` leaves (a lone
`vftable` field) and every field access became array arithmetic on it:

| what it printed | what it is |
| --- | --- |
| `side[0x2c].vftable` | `side->target_count` (+0xB0) |
| `side[iVar6 % side[0x2c].vftable + 0x2d].vftable` | `side->targets[iVar6 % side->target_count]` |
| `side[0xf].vftable` | `side->combat` (+0x3C) |
| `side[0x439].vftable` | `side->strength_damage_dealt` (+0x10E4) |
| `pCVar17->vf_22`, `pCVar17->vf_21`, `pCVar17->vf_23` | the target's `sub_unit_definition_ptr` (+0x58), `combat_defend_product` (+0x54), `strength` (+0x5C) |
| `pCVar17[1].vf_16`, `pCVar17[1].vf_17`, `pCVar17[1].vf_18` | `pending_strength_damage` (+0xA8), `pending_organisation_damage` (+0xAC), `unit_ptr` (+0xB0) |

The `vf_NN` names are the giveaway: `vf_22` is simply offset 22*4 = 0x58 inside a vftable
struct that happens to be 0x68 long, which is why `pCVar17[1].vf_16` lands on 0x68 + 0x40 =
0xA8. Nothing was wrong with the analysis - the element had nowhere to get a type from.

**One typed array field fixes almost all of it**, because the element type propagates into
every use of the drawn target. What landed:

    CBomberCombatant (0x10E8, inherits CCombatant)
                                +0xB0   target_count           int
                                +0xB4   targets                CSubUnit*[1024]
                                +0x10E4 strength_damage_dealt  int  (saved as `strength`)
    CAirCombatant    (0x10B4, inherits CCombatant)
                                +0xB0   targets                CSubUnit*[1024]
                                +0x10B0 target_count           int

**Both use `"inherits": "CCombatant"`, which is the right tool and I nearly missed it.** The
first version of these two structs hand-copied the five `CCombatant` fields this body happens
to touch, on the reasoning that the base cannot be embedded at +0 because `CCombatant + 0xB0`
is `CLandCombatant`'s `front_line` and these classes use those bytes for the target array.
That reasoning was wrong about the tool: `ghidra/README.md` documents `"inherits"`, which
copies the base's fields in and lets a field the derived class declares itself **win**, and
`buildFindings.py` resolves the conflict **by exact offset** - `taken = {f["offset"] for f in
s["fields"]}`. `front_line` is the only base field at or past +0xB0 and both derived classes
declare something at precisely +0xB0, so it is dropped on both and nothing else collides. The
derived structs now carry all 22 of `CCombatant`'s fields rather than five copies with
nothing keeping them in step, and the body reads `side->combat->defender->units`,
`side->is_attacker` and `side->sunk_ships_count` as well as the two array fields.

`strength_damage_dealt` is named off its own save key: `fieldmap.py CBomberCombatant` maps
token 0x259, `strength`, to +0x10E4 through `CBomberCombatant::LoadKey`.

### The six `(int)floor(N.5f)` statics the damage arithmetic multiplies by

The other thing that read as noise was six bare `DAT_01a88...`. Each is a compiled-in static
with no `defines.lua` entry behind it, filled at startup from a float; the values can only be
had by finding the store inside the shared `.CRT$XCU` initialiser at `0x8BF6F0` and reading
the float it floors, because the globals are zero in the file.

| global (rva) | value | float | what reads it |
| --- | --- | --- | --- |
| `k_thousandths_10_combat` `0x1688104` | 10 | `10.5` | eight readers, so named for what it holds. In `FireUnit` it makes the regiment-count term `1000 + regiments * 10` - **1% more bombing strength damage per regiment on the defending side** |
| `g_BombRegimentStrengthFactor` `0x16880D4` | 400 | `400.5` | one reader: **x0.400** on strength damage to a land regiment |
| `g_BombRegimentOrgFactor` `0x1688130` | 800 | `800.5` | one reader: **x0.800** on organisation damage to a land regiment |
| `g_BombShipStrengthFactor` `0x168810C` | 300 | `300.5` | one reader: **x0.300** on strength damage to a ship |
| `k_thousandths_500` `0x1688120` | 500 | `500.5` | two readers, both here and for different things - ship **organisation** and wing **strength** - so it keeps a generic name |
| `g_BombWingOrgFactor` `0x1688160` | 700 | `700.5` | one reader: **x0.700** on organisation damage to a wing |

Naming follows this record's own rule (`findings/FINDINGS-combat3.md` §5): a static with many
readers is named for what it holds, because naming it for one part would be false about the
others; one with a single reader is named for that reader.

**The mod-facing fact in that table**: the split between strength and organisation damage per
target kind is **compiled in and cannot be tuned**. A bombing run costs a brigade twice as
much organisation as strength (0.8 vs 0.4), a ship 0.5 vs 0.3 and a wing 0.7 vs 0.5. Only the
overall per-kind multiplier - `BOMB_REGIMENT_DAMAGE_MODIFIER`, `BOMB_SHIP_DAMAGE_MODIFIER`,
`BOMB_WING_DAMAGE_MODIFIER` - is a define, and it scales both halves together.

### The locals, and the two that were deliberately left alone

Seven named, of thirteen frame slots:

| slot | name | |
| --- | --- | --- |
| `stack:-0x14` | `airDefenceDiscarded` | the dead value, which now says so in the C |
| `stack:-0x18` | `wingUnit` | the firing wing's `CUnit`, whose order picks the attack stat |
| `stack:-0x1c` | `target` | the drawn regiment, ship or wing |
| `stack:-0x20` | `shots` | the loop counter |
| `stack:-0x28` | `regimentCountTerm` | `1000 + regiments * 10` |
| `stack:-0x8` | `ehState` | MSVC's `__$EHRec$` try level, driven to 0/1/-1 around the lazy `CDefines` construction |
| `stack:-0x10` | `ehPrevRecord` | the saved SEH registration, restored at every return |

**`stack:-0x24` and `stack:-0x2c` are left unnamed on purpose.** They are slots MSVC reuses
for unrelated temporaries with non-overlapping lifetimes: `-0x24` holds the hard-attack half
of the soft/hard split, then the target's `hull`, then three different damage statics (11
accesses), and `-0x2c` holds a `CommandEffect` out-parameter, then the target's remaining
strength, then the `CDefines` pointer, then more statics (13 accesses). One name would be a
lie about the other uses, which is the same reason `k_thousandths_500` above keeps a generic
name. `dvd_frameslots.py`-style enumeration of every slot with every access is what makes that
call: four more slots (`-0x30` through `-0x40`) are the 64-bit halves of `__allmul`/`__alldiv`
temporaries and the decompiler already folds them into one `longlong`, so there is nothing
there to name either.



### The result

    void CBomberCombatant::FireUnit(CBomberCombatant *side, CSubUnit *wing)
      if (side->target_count < 1) return;
      target = side->targets[iVar6 % side->target_count];
      ...
      airDefenceDiscarded = pCVar8->air_defence;
      iVar6 = CUnitList::GetTotalNumOfRegiments(&side->combat->defender->units);
      ...
        if ((*target->vftable->vf_9)() == 0 && (*target->vftable->vf_11)() == 0)
          remaining = target->strength - target->pending_strength_damage;
        ...
        airDefenceDiscarded = target->combat_defend_product * airDefenceDiscarded / 1000;

**And one pipeline lesson, now in `ghidra/README.md`.** The signature was first written with
`side@stack:4, wing@stack:8` - which is exactly where `__stdcall` puts them anyway. Any
`storage` annotation flips the apply to `CUSTOM_STORAGE`, and on that path the `void` return
does not survive: the function kept decompiling as `CBomberCombatant *` and that typed the
shot counter as a pointer, giving `shots = (int)&pCVar10->vftable + 1`. Dropping both
annotations fixed the return and the counter.

## What is not established

- **Whether `air_defence` has a consumer outside the entry-set decode.** The census is a
  whole-image sweep that resumes past every byte capstone refuses (186 resumes), but the
  provenance filter only sees a definition pointer loaded into a register a few instructions
  earlier. A function taking the definition as an argument is invisible to it - the AI power
  figure is the known example. `likely`, not `confirmed`, for "no consumer anywhere".
- **Which function at `0x3208E7`/`0x323CD1`** `functionStart` means: both reads are inside
  `BuildUnitStatsTooltip`, measured, but the walk-back answers a non-entry, so the tooltip
  attribution is by extent rather than by `functionStart`.
- **Why the ground-attack arm of `FireUnit` reads the air defence off `CUnit + 0xC8`** - the
  unit's own definition - rather than the drawn regiment's. It makes no difference while the
  value is discarded; it would if it were ever wired up.
- **What `air_defence` was meant to buy.** By analogy with land it would be
  `CUnit::RollToHit`'s shot budget, which would also bring `BASE_CHANCE_TO_AVOID_HIT` into
  air combat. That is a guess about intent, `inferred` and nothing more.

## The live checks that would settle it

Two, both cheap in a running game, and both decisive against the static argument:

1. **Hook `0x160D44`** (the air defence read) and log the value and the target. It proves the
   path is reached in a real bombing run - the static read says it is, but "reached" is the
   one thing bytes cannot say.
2. **Hook `0x160FDE`** (the roll compare) and log both operands over a few hundred shots.
   The threshold should be exactly `CHANCE_TO_AVOID_HIT_AT_NO_DEF / 1000` every time, with no
   dependence on the target's air defence. One bombing raid against an AA-heavy stack and one
   against a stack with no AA at all, compared, is the whole experiment.

A third, from the mod side and needing no hook: set `air_defence = 0` on every unit in a
copy of the mod and fight the same bombing run twice. If the damage distribution is
unchanged, the stat is inert.
