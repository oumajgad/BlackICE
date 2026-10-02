# Naval detection, positioning and fleet disengagement

`ShouldStartNavalCombat` read end to end, the naval positioning number found and followed
from the roll that creates it to the cap it creeps towards, and `CNavalCombat::Tick`'s
disengage chance written out in full. All of it is static, off `hoi3_tfh.exe`; **no game
was running for any of it** and the places where that matters are called out.

Addresses are **virtual** unless written `rva`. Image base `0x400000`.

## The three headline results

1. **`ShouldStartNavalCombat` is a spotting roll**, per (their ship x our ship) pair, over
   `surface_detection` / `sub_detection` against `visibility`, scaled by the leader's
   `spotting_chance` trait effect, mission efficiency, the province's rain and cloud, and
   the intel level our country has on the sea zone. It has six short-circuits that say
   *yes* before any roll and six gates that say *no*.
2. **`CNavy +0x370` and `+0x374` are not CNavy fields at all.** They are
   `CMapProvince.intel_by_country_ptr` and `intel_country_count`, already named in
   `project.json`, reached through `CUnit +0x130` (`current_province_ptr`). The flag at
   `+0x31` is not on `CNavy` either — it is `CSubUnitDefinition.is_sub`.
3. **The four unread globals are all weather defines**, cached into statics at startup:
   `0x01A86F90` = `SPOTTINGCLOUDMODIFIER`, `0x01A8702C` = `SPOTTINGRAINMODIFIER`,
   `0x01A87058` = `NAVALWINDSPEEDMODIFIER`, `0x01A86FFC` = `NAVALRAINMODIFIER`.

## Corrections to what was recorded before

- **`ShouldStartNavalCombat` returns a bool, not a code.** The function has exactly two
  exits: `mov al, 1` at `0x00431A85` and `xor al, al` at `0x004320B0`, both `ret 8`. The
  `cmp al, 1` at the `StartCombat` call site is how MSVC compares a `bool` against `true`;
  the other three call sites use a plain `test al, al`. `FINDINGS-airnaval.md` reads a
  third value into it that does not exist.
- **Its arguments are the other way round from the obvious reading.** `ret 8`, no use of
  `ecx`, `edi = [ebp+8]` and `ebx = [ebp+0xC]`. At `0x00430861` the pushes are
  `push edi; push eax`, so **`ours` is the second push** (`ebp+8`) and `theirs` the first.
  Signature: `bool __stdcall ShouldStartNavalCombat(CUnit* ours, CUnit* theirs)`.
- **It has four callers, not one.** `0x00430415` (inside `0x004302A0`), `0x00430861`
  (`CCombatManager::StartCombat`), `0x0059A85E` (inside `0x0059A740`) and `0x0059D12C`
  (inside `0x0059CE10`) — the last two in the naval-order block, so naval orders ask the
  question themselves as well as the combat manager. Both call sites in the manager guard
  it with `CProvinceTemplate.is_land (+0x22)`, so it only ever runs for a sea zone.
- **`carrying` is a `CNavy` field, not a `CUnit` field.** `project.json` puts
  `carrying CList<CUnit*>` at `CUnit +0x2E4`. `CNavy::CNavy` (`0x005CEE20`) is what
  initialises `+0x2E4`, `+0x2E8`, `+0x2EC`, `+0x2F0`, `+0x2F4` and `+0x2F8`, immediately
  after calling the `CUnit` base constructor at `0x005B5010` — so `CUnit` ends before
  `+0x2E4` and all six belong to `CNavy`, which is `0x2FC` bytes. I have not moved the
  existing entry; the evidence is the six stores between `0x005CEE39` and `0x005CEE5F`.
- **`image.functionStart` walks past `CNavy`'s slot 31.** It reports `0x005CFBD0` for
  `0x005CFDD0`; `image.retsBefore(0x5CFBD0, 0x5CFDD0)` finds a `ret 4` at `0x005CFDCD`,
  so the slot-31 override really is its own function. Exactly trap 2.

## `ShouldStartNavalCombat` (rva `0x31840`, VA `0x00431840`), in full

`bool __stdcall (CUnit* ours@stack:8, CUnit* theirs@stack:0xC)`, `ret 8`, 0x880 bytes,
`0x00431840` to `0x004320BD` inclusive. `edi` holds `ours` and `ebx` holds `theirs`
throughout, both reloaded from the frame after every helper that clobbers them.

### The six gates that answer *no*

| # | where | test |
| --- | --- | --- |
| 1 | `0x00431862` | `theirs->regiments.count (+0x40) < 1` — the other unit has no ships |
| 2 | `0x00431889` | `ours->IsNaval() && ours->AsNavy()->+0x2F8 > 0` — our fleet's post-combat cooldown has not expired |
| 3 | `0x004318A3` | `ours->order->GetTypeId() == convoy_raid (0x6E9)` |
| 4 | `0x0043194B` | our owner is **AI** (`gameState->played_countries_array[ours->owner_id] == 0`) **and** our order is one of `rebase (0x6DE)`, `invasion (0x3A5)`, `transport (0x3A8)` or `none (0x18D)` |
| 5 | `0x00431A11` | both sides naval and `ours.submarines > 0` and `theirs.screens > ours.submarines / 3` |
| 6 | `0x00431A58` | both sides naval, our order is `patrol (0x42E)`, `ours->order->GetStance() != 0`, and `5 * (ours.carriers + ours.capitals) < 3 * (theirs.carriers + theirs.capitals)` |

Gate 4's owner test is the only use of the country tag copied to `[esp+0x40]` at
`0x00431941`; the slot is later reused for a 64-bit temporary, so nothing else reads it.

Gates 5 and 6 both need the **fleet census** below. Gate 6's stance test matters: slot 19
of `COrder` is `0x004944C0`, which is `return this->+0x20` — `stance` — and no order class
overrides it. `FINDINGS-airnaval.md` records that `stance` reads 1 on every order in a
running game, so **in practice a patrol is always subject to the capital-ship comparison**:
it will not engage unless its own carriers plus capitals are at least 60% of the enemy's.

### The fleet census, `0x005CF640`

`void __fastcall CountShipsByRole(CUnit* unit@ECX, int out[5]@EAX)`, bare `ret`, 0x60
bytes. It zeroes five ints and walks `unit->regiments (+0x38)`, classifying each ship by
its `CSubUnitDefinition` (`CSubUnit +0x58`) in this order:

```
def->is_capital  (+0x2F)       -> out[4]  (+0x10)
def->is_transport(+0x30)       -> out[1]  (+0x04)
def->is_sub      (+0x31)       -> out[0]  (+0x00)
def->carrier_size(+0x190) > 0  -> out[3]  (+0x0C)
otherwise                      -> out[2]  (+0x08)   the screens
```

All four definition fields are already named in `project.json`; this is the first place
that shows what they are *for*. The order is exclusive, so a capital ship that also has a
`carrier_size` counts as a capital.

### The six short-circuits that answer *yes*, in order

```
0x00431A6E  prov = ours->current_province_ptr (+0x130);  cid = ours->owner_id (+0x128)
            if (prov->intel_country_count (+0x374) > cid
                && prov->intel_by_country_ptr (+0x370)[cid] >= 9)   return true;
0x00431A9B  if (theirs->combats.count (+0x11C) > 0)                 return true;
0x00431AA4  if (theirs->current_combat (+0x110) != 0)               return true;
0x00431AAD  if (g_FogOfWar (byte at 0x0170AD30) == 0)               return true;
0x00431AE0  if (theirs->IsNaval())
              for (u in theirs->AsNavy()->carrying (+0x2E4))
                if (u->movement_remaining (+0x140) > 0
                    || u->combats.count (+0x11C) > 0)               return true;
```

So: **intel level 9 on the sea zone, an enemy already in a battle, fog of war switched
off, or a loaded fleet whose cargo is moving or fighting** all skip the roll entirely.

The intel byte's meaning is already recorded on `CMapProvince.intel_by_country_ptr`:
"one intel byte per country index (0 unseen, 3 partial, 9 own)". This function uses the
thresholds 2, 6, 7, 8 and 9, which is the first evidence that the scale has more steps
than those three.

`0x0170AD30` is the **fog-of-war flag**. Its writer is the console command handler at
`0x00441846`: it matches the literal `"fow"` at `0x015B84E0`, prints
`"Fog of war turned OFF"` / `"Fog of war turned ON"`, and stores the inverted flag with
`mov byte ptr [0x170AD30], cl` at `0x0044191B`. The byte's image value is 1.

### The four scale factors

Computed once, before the double loop.

**`A`, mission efficiency, `[esp+0x10]`.** Starts at 1000.

```
0x00431B10  if (ours->order->GetTypeId() == convoy_escort (0x6E8)
                && theirs->order->GetTypeId() == convoy_raid (0x6E9))
                A = 1000 + MissionEfficiency(ours->order) - MissionEfficiency(theirs->order)
0x00431B97  else if (ours->order->GetTypeId() == patrol (0x42E)
                && theirs->order->GetTypeId() == convoy_raid)
                A = (1000 + MissionEfficiency(ours->order) - MissionEfficiency(theirs->order)) * A / 1000
```

The two branches are the same arithmetic written twice; the second folds in the current
`A`, which is still 1000, so both come to the same thing. The first uses
`__allmul`/`__alldiv` by 1000 and 1000 — a hand-written `muldiv(x, ONE, ONE)` that is the
identity, worth knowing before reading it as a scaling.

`MissionEfficiency` is `0x005879B0`,
`int* __fastcall COrder::GetMissionEfficiency(COrder* order@ESI, int* out@EDI)`, bare
`ret`:

```
m       = 0x00584410(order->GetTypeId())        ; a binary-search switch, order token -> small index
unit    = order->unit (+0x08)
country = g_CCountryDataBase[0x01A855A4]->+0x16C [ unit->owner_id ]
*out    = *(int*)( country->+0xDF8 + 0xE0 + m*4 )
if (m != 0)
    *out += country->modifiers (+0xDA8) [ table[0x0174DA00 + m*4] * 8 ]
```

The second term is a **country modifier** — 8 bytes an entry, value in the low dword,
exactly trap 5 — selected through a runtime table at `0x0174DA00`. That table is past the
end of the raw `.data` in the file, so it is filled at startup and I could not read it
statically; **which modifier ids it holds is not established.**

**`B`, the after-a-raid bonus, `[esp+0x14]`.** Starts at 1000.

```
0x00431C3C  if (theirs->IsNaval()) {
              gs   = g_CCurrentGameState
              last = theirs->current_province_ptr->last_convoy_attack (+0x1C)
              if ((unsigned)(GetDays(&gs->tick) - GetDays(&last)) <= 1)
                  B = GetDefines()->military->+0x270 = NAVAL_INTERCEPTION_AFTER_ATTACK_FACTOR
            }
```

`GetDays` is `0x0042EF70`, `int __fastcall (const int* date@ECX)`: `(*date - 43800000) / 24`
with a float round-trip through `g_DaysPerYear` (`0x0120A550`, the double **365.0**) that
cancels exactly, so the whole body reduces to the day count. **This is the only reader of
`CMapProvince.last_convoy_attack` I found**, and it means the key is a live mechanic:
a sea zone raided today or yesterday gets the interception factor applied to every
spotting roll in it.

Note that `B` reads **`theirs`**' province while the intel terms read **`ours`**' — in a
sea battle they are the same province, but the code does not assume it.

**`C`, the spotting trait, `[esp+0x28]`.**

```
0x00431D1F  C = 1000 + *CUnit::GetTraitEffect(ours, &tmp, 0xE)
```

`0x005D1120` is `CUnit::GetTraitEffect` / `CommandEffect`, already recorded, and effect
**`0xE` is `spotting_chance`** — entry 14 of the `CTrait::Effect` enum in
`BiceLib/GameClasses/CTrait.hpp`. So the whole leader-trait chain, HQ contributions
included, feeds naval detection through this one term.

**`D`, the roll's denominator, `[esp+0x18]`.**

```
0x00431C0D  D = ours->IsAir() ? 1000 : 10000
```

An air unit's rolls are against 1000 and a fleet's against 10000, so **the same numbers
make an air unit ten times as likely to find a fleet as another fleet is.**

### The double loop and the roll

`0x00431D2F` bails (`return false`) if `theirs->regiments.first` is null. Then:

- outer loop over `theirs->regiments` (`CUnit +0x38`), `edi` = **their** ship;
- inner loop over `ours->regiments`, via
  `0x005BE630` (`CList* __fastcall CUnit::GetRegimentList(CUnit*@EAX)`, which is
  `unit ? &unit->regiments : nullptr`), `esi` = **our** subunit.

Per pair, everything in thousandths:

```
V = our->IsAir()            ? our->def->surface_detection (+0x150)
  : their->def->is_sub      ? our->def->sub_detection (+0x158) / 2
  :                           our->def->surface_detection
S = max(1000, their->def->visibility (+0x15C))

v  = V * S / 1000
v  = v * C / 1000                                   ; 1000 + spotting_chance
v  = v * A / 1000                                   ; mission efficiency
v  = v * B / 1000                                   ; after-a-raid factor
v  = v * 1000 / (theirs->movement_remaining (+0x140) > 0 ? 3000 : 2000)
if (theirs->+0x95) v = v * 2

intel = prov->intel_by_country_ptr[cid]             ; only while intel_country_count > cid
if (intel >= 2) v = v * 1250 / 1000
if (intel >= 6) v = v * 2
if (intel >= 7) v = v * 2
if (intel >= 8) v = v * 2

v = v * (1000 - prov->rain (+0x80)  * SPOTTINGRAINMODIFIER  / 1000
              - prov->cloud (+0x8C) * SPOTTINGCLOUDMODIFIER / 1000) / 1000
if (v < 1000) v = 1000

if (rand() % D < v / 1000) return true
```

`our->IsAir()` is `CSubUnit` slot 11 — the base is the shared `xor al,al` at `0x00592360`
and only `CWing` overrides it with the shared `mov al,1` at `0x00A92590` (slots 9, 10 and
11 are `IsLand`, `IsNaval`, `IsAir`, overridden by `CRegiment`, `CShip` and `CWing`
respectively). So **aircraft use `surface_detection` even against submarines**;
`sub_detection` is a ships-only stat, and it is **halved** when it is used.

Five things worth pulling out of that:

- **A moving fleet is harder to see, not easier**: the divisor is 3000 rather than 2000.
- **The minimum is a hard floor of 1000**, so `v / 1000 >= 1` always and there is always
  some chance. With `D = 10000` the floor is 1 in 10000 per pair per call.
- **The intel ladder is multiplicative and cumulative**: level 8 gives
  `1.25 x 2 x 2 x 2 = 10x`, and level 9 never reaches here because it short-circuits to
  `true` far above.
- **`v / 1000` truncates before the comparison**, so every factor below a full 1000 of
  detection is thrown away. A pair whose `v` comes to 1999 rolls exactly as well as one at
  1000.
- The `1250` is not a define. It is `(int)floor(1250.5f)`, the compiler's rendering of a
  hardcoded `1.25` — see *And a fourth kind of constant* below.

The four weather globals are all reached with no `call GetDefines` anywhere near them,
which is trap 8 in a third form — see *How a define becomes a bare absolute address*.

### `CNavy +0x2F8`, the post-combat cooldown

Gate 2's field. `CNavy::CNavy` (`0x005CEE20`) zeroes it; `CNavy::LoadKey`
(`0x005CF6A0`) does not read it, so it is runtime-only and never saved.

- **Set** at `0x005C80E7`, inside `0x005C7E10` (3 callers, one of them at `0x0057B01B` in
  the combat block): `navy->+0x2F8 = 8 + (rand() % 8)`, the `% 8` written with the signed
  `and 0x80000007 / dec / or 0xFFFFFFF8 / inc` idiom.
- **Decremented** by `CNavy`'s own slot 31, below.
- **Cleared** at `0x005BF2C3`, inside `CUnit::EnterProvince` (`0x005BEFD0`) — so moving
  into a new sea zone cancels the cooldown.

Those four sites are every reference to the offset in the image.

## `CNavy`'s overrides

`CNavy` overrides `CUnit` slots 1, 11, 12, 18, 28, 30, 31, 34, 36 and 37. Slots 11 and 12
are the pair `CNavy` claims out of the six cast slots 9-14: each pair is the shared
`mov eax, ecx; ret` at `0x005B4EC0` for the owning class and the shared
`xor eax, eax; ret` at `0x00A80690` everywhere else, so **slot 11 is `AsNavy()`** —
`this` for a `CNavy`, null for anything else. `CArmy` takes 9 and 10, `CAir` 13 and 14.

**`CNavy::CheckOrderAndCombat`, slot 31, rva `0x1CFDD0`**, is 0x34 bytes and is the whole
of the difference from `CUnit`'s `0x005BA2F0`:

```
void __thiscall CNavy::CheckOrderAndCombat(CNavy* this)
{
    if (this->+0x2F8 > 0) this->+0x2F8 -= 1;              ; the cooldown ticks here
    if (this->combats.count > 0 || this->current_combat != 0)
        0x005C7C70(this);
    CUnit::CheckOrderAndCombat(this);                     ; tail jmp 0x005BA2F0
}
```

So the cooldown's unit of time is *one slot-31 call*, and
`FINDINGS-airnaval.md`'s open question — how often slot 31 runs and on which thread — is
now also the question of how long a fleet's 8-to-15 tick cooldown lasts. **Still not
established.**

## Naval positioning

`CNavalCombatant +0x10B4` is `positioning` (save key `0x39B`), which `FINDINGS-combat.md`
already had from the loader. What is new is where the number comes from. It is **not**
computed in `ShouldStartNavalCombat`; it is rolled once when the combat starts and then
creeps upward every tick.

### Rolled at combat start: `CNavalCombat` slot 13, rva `0x17B910`

`CCombat` slot 13 is `0x00572580` and `CNavalCombat` overrides it with `0x0057B910`, which
ends in a tail `jmp` back to the base. `CCombatManager::Tick` calls slot 13 exactly once
per combat, the first time it sees it (`if (!c->byte[0x29]) c->slot13()`), so this is the
combat's begin hook. `image.retsBefore(0x57B770, 0x57B9E0)` puts a `ret` at `0x0057B908`,
confirming `0x0057B910` as a function start.

```
void __thiscall CNavalCombat::slot13(CNavalCombat* this)
{
    att = this->attacker (+0x10);  def = this->defender (+0x14)
    att->+0x10B8 = (rand() % 20) * 10          ; via the round-to-thousandths idiom
    def->+0x10B8 = (rand() % 20) * 10
    UpdatePositioning(att);                     ; 0x00566E70
    UpdatePositioning(def);
    CCombat::slot13(this);                      ; jmp 0x00572580
}
```

So **`CNavalCombatant +0x10B8` is the positioning die**: `0..190` thousandths, one per
side, rolled once and never re-rolled. `FINDINGS-combat.md` records `+0x10B8` as zeroed
beside `+0x10B4` with nothing known about it; this is it.

### `CNavalCombatant::UpdatePositioning`, `0x00566E70`

`void __fastcall (CNavalCombatant* this@EDI)`, bare `ret`, not in any vftable — a plain
helper called from slot 13 and from slot 12 (`0x00566F20`, the "a unit joined this side"
hook).

```
pos = 400                                                   ; [0x01A88170]
leader = GetHighestRankedLeader(this)                       ; 0x00565F20
if (leader->slot8())                                        ; false for g_NullLeader
    pos += leader->skill (+0x70) * 100                      ; [0x01A882E8]
NavalStackingPositionPenalty(&this->units (+0x40), &penalty) ; 0x005D5B80
this->positioning = this->+0x10B8 + pos - penalty
if (this->positioning < 0) this->positioning = 0
```

`0x00565F20` is
`CLeader* __stdcall CCombatant::GetHighestRankedLeader(CCombatant* this)`, `ret 4`: it
walks `this->units (+0x40)`, takes each unit's `leader_ptr (+0x12C)`, keeps the one with
the largest `rank (+0x6C)` whose slot 8 answers true, and falls back to the lazily built
`g_NullLeader` singleton at `0x01A855E0` (0xD0 bytes).

### The stacking penalty, `0x005D5B80`

`int* __stdcall NavalStackingPositionPenalty(CList<CUnit*>* units, int* out@ESI)`, `ret 4`.
Three defines, all named, and one unit-definition stat:

```
hull = sum over every ship in the fleet of def->hull (CSubUnitDefinition +0x178)
p    = max(0, hull - NAVAL_STACK_POS_HULL_LIMIT)            ; military +0x1DC
p    = p * NAVAL_STACK_POS_PENALTY_HULL_MULT / 1000         ; military +0x1E0
p    = min(p, NAVAL_STACK_POS_PENALTY_MAX)                  ; military +0x268
```

`hull` is read off `CUnit->CSubUnitDefinitionPtr (+0xC8)`, i.e. the unit's own definition,
once per **unit** in the combatant's list — not per ship — which is worth a live check.

### Creeping up: `CNavalCombatant::Attack`, slot 15, `0x00567930`

The tail of the attack, `0x00567980`-`0x00567A28`, recomputes the same cap without the die
and nudges positioning towards it:

```
cap = 400                                                   ; [0x01A88170]
leader = GetHighestRankedLeader(this)
if (leader->slot8()) cap += leader->skill * 100             ; [0x01A881AC]
cap -= NavalStackingPositionPenalty(&this->units)
if (cap < 100) cap = 100                                    ; [0x01A881AC] again
if (this->positioning < cap) this->positioning += 20         ; [0x01A88174]
```

So, end to end and in thousandths:

```
start   positioning = clamp0( roll(0..190) + 400 + leaderSkill*100 - stackPenalty )
cap     max(100, 400 + leaderSkill*100 - stackPenalty)
tick    positioning += 20 while positioning < cap
```

A good roll can start a side **above** its own cap, in which case it simply stops moving.
With no leader and no stacking penalty a side starts between 0.400 and 0.590 and the cap
is 0.400, so the creep never fires; the creep only matters for fleets that the stacking
penalty pushed below their cap.

**What positioning is then multiplied into is not established** — that is in
`CNavalCombatant::Attack`'s body above `0x00567980`, which I did not read.

## The disengage chance, `CNavalCombat::Tick` (rva `0x17BA00`)

The whole function is `0x0057BA00` to `0x0057BB3E`, 0x141 bytes, and ends in `int3`
padding, so there is no abutting-function question here.

```
bool __thiscall CNavalCombat::Tick(CNavalCombat* this, int unused)
{
    if (CCombat::Tick(this, unused) == 1) return true;       ; 0x0056EBE0, direct call

    prov = this->province (+0x18);
    base = prov->byte[0x2C] ? 11000 : 1000;
    weather = 10000
            + prov->wind_speed (+0x78) * NAVALWINDSPEEDMODIFIER / 1000
            + prov->rain       (+0x80) * NAVALRAINMODIFIER      / 1000;

    hours = this->duration (+0x20);
    if (hours <= 2) return false;                            ; no disengage in the first three hours

    if (rand() % 1000 >= (hours * 1000 + weather + base) / 1000) return false;

    for (side in { this->attacker, this->defender })
        for (u in side->units (+0x40)) {
            u->disengage (+0xA8) += 1;
            if (WantsToDisengage(u)) return true;             ; 0x005C9A60
        }
    return false;
}
```

`0x005C9A60` is `bool __fastcall WantsToDisengage(CUnit* unit@ESI)`, bare `ret`:

```
limit = 5 * (1000 + *CUnit::GetTraitEffect(unit, &tmp, 0xC)) / 1000
return unit->disengage >= limit
```

and effect **`0xC` is `disengage_timer`**, entry 12 of `CTrait::Effect` — which is what
confirms `CUnit +0xA8` really is the disengage counter the save key names, and gives the
trait its exact arithmetic. With no trait the limit is **5**.

So the mechanic is: **the combat rolls once per hour; when the roll passes, every unit on
both sides has its disengage counter bumped, and the first unit to reach
`5 * (1 + disengage_timer)` ends the whole combat.** The counter is not per-roll — it
accumulates — so what sets the battle's length is *how many times the roll passes*, not
the size of any single chance.

Reading the terms at face value:

| term | thousandths | what moves it |
| --- | --- | --- |
| `hours * 1000` | 3000 upward | one per hour |
| constant | 10000 | nothing |
| `base` | 1000, or 11000 | `CMapProvince` byte `+0x2C`, the **night flag** |
| wind | `wind * NAVALWINDSPEEDMODIFIER / 1000` | weather |
| rain | `rain * NAVALRAINMODIFIER / 1000` | weather |

Divided by 1000 that is a threshold of `hours + 11` out of 1000 in the plain case, rising
by 1 an hour — so a nominal 1.4% at hour three and 3.5% at a day. The province byte at
`+0x2C` doubles it. The two `NAVAL*MODIFIER` weather defines are the only mod-facing
levers here besides those, and neither the hours term nor the weather can move the
threshold far: **the constant 10000 is the dominant term all the way out to four days of
battle.**

`CMapProvince +0x2C` is a byte immediately after `suppression (+0x28)`; `CProvince`'s
loader places no key there, so it is runtime state.

**It is the night flag, and that was settled by the weather survey in the same wave.**
At `0x67B204` a `call 0x4A7390` (`IsNight`) is followed immediately by
`mov byte ptr [esi+0x2c], al`. So **a naval battle is about eleven times more likely to
break off at night than by day** - the largest single lever in the disengage chance turns
out to be the clock, not the weather, and not anything a mod can set. See
`FINDINGS-weather.md`.

## A sign question I could not close, and it changes both formulas

`rand()` here is `0x00AA2F80`: it lazily creates a 4-byte holder, bumps
`g_random_draws (0x0134DA8C)`, and tail-jumps to `0x00AA2B90` with `g_random_seed
(0x01310F80)` in `eax`. `0x00AA2B90` is Mersenne-Twister — 624-word state at
`seed + 0x9C0`, tempering with the masks pre-shifted for the `<< 7` step — and its
last two instructions are

```
0x00AA2BD7  sar  eax, 0x12
0x00AA2BDA  xor  eax, ecx
0x00AA2BE4  ret
```

so it returns the **full 32-bit tempered word, with no mask and no `abs`**. Every one of
the 61 call sites in the image reduces it with `cdq; idiv`, which is a *signed* remainder,
and both of the comparisons above are signed (`jl` at `0x00432086`, `jge` at
`0x0057BABA`).

Taken literally that means a negative remainder always passes: roughly **half** of all
naval spotting rolls and **half** of all naval disengage rolls would succeed regardless of
the numbers computed for them. That would make the disengage threshold nearly irrelevant
(a unit would accumulate its five counts in about ten hours whatever the weather) and make
detection near-certain for any fleet with a ship on each side, which is at least
consistent with what players report about both. It also means `+0x10B8` can be negative
(down to -190) and the `CNavy` cooldown can be 1..15 rather than 8..15.

**I am not asserting it.** I read the bytes and they say what they say, but this is an
engine-wide claim resting on one function, and the uniformity of the 61 call sites is as
easily read as evidence that the generator is expected to be non-negative. Settling it
needs the running game: read `g_random_seed`'s state, or hook `0x00AA2F80` and count the
sign of a few thousand draws. Until then, treat the thousandths formulas above as the
*nominal* chance and this as an open multiplier on both.

## How a define becomes a bare absolute address

Trap 8 says a `call GetDefines` scan is not exhaustive because `GetDefines` gets inlined.
There is a **third** route, and it is what hid all four of this task's unknown globals:
for the `weather` block the game copies every entry into an individual static once, and
reads the static forever after.

`0x004B54F0` does it, entry by entry, 56 times:

```
mov ecx, [eax + 0xEC]        ; eax is the CDefines*, +0xEC is the weather block
mov edx, [ecx + <offset>]
mov [<absolute>], edx
```

`scratchpad/naval/definecache.py` reads that pattern across the whole image and recovers
**49 such globals**, spread over the `military` and `weather` blocks. The four this task
asked about:

| global | block | define |
| --- | --- | --- |
| `0x01A86F90` | weather `+0xB4` | **`SPOTTINGCLOUDMODIFIER`** |
| `0x01A8702C` | weather `+0xB8` | **`SPOTTINGRAINMODIFIER`** |
| `0x01A87058` | weather `+0x88` | **`NAVALWINDSPEEDMODIFIER`** |
| `0x01A86FFC` | weather `+0x8C` | **`NAVALRAINMODIFIER`** |

and, because the same three globals appear in `CNavalCombat::Tick` against province
fields, that names three `CMapProvince` weather fields at the same time:
`+0x78` is wind speed (multiplied by `NAVALWINDSPEEDMODIFIER`), `+0x80` is rain
(`NAVALRAINMODIFIER` at `0x0057BA5C`, `SPOTTINGRAINMODIFIER` at `0x00432029`) and `+0x8C`
is cloud cover (`SPOTTINGCLOUDMODIFIER`). All three sit inside the `CWeather` the province
holds by value at `+0x68`, i.e. `CWeather +0x10`, `+0x18` and `+0x24`.

**The consequence for the mod is direct**: `SPOTTINGCLOUDMODIFIER` and
`SPOTTINGRAINMODIFIER` are the only weather levers on naval detection, and
`NAVALWINDSPEEDMODIFIER` and `NAVALRAINMODIFIER` are the only two on naval disengagement —
and none of the four does anything else anywhere in the image.

## And a fourth kind of constant: `(int)floor(x)` statics

`0x01A88170`, `0x01A88174`, `0x01A881A0`, `0x01A881AC` and `0x01A882E8` look exactly like
cached defines in the disassembly — `imul dword ptr [0x01A88170]` — and they are not. Each
is filled by a one-line CRT dynamic initialiser:

```
0x00CC00B0  movss xmm0, [0x0160A6DC]     ; the float 400.5
            push ecx / movss [esp], xmm0
            call 0x00401FD0              ; floor(float) -> float
            add esp, 4
            call 0x00C08870              ; __ftol2
            mov [0x01A88170], eax
            ret
```

`0x00401FD0` wraps `0x00C084B0`, which is the CRT's `floor` — it reaches `_except1` with
the fp opcode `0xB`, `_FpCodeFloor`. The float literals are all `N + 0.5`, so this is the
source's `(int)floor(value * 1000 + 0.5)` rounding idiom with `value * 1000 + 0.5`
constant-folded and `floor` left behind. **`scratchpad/naval/floorconsts.py` finds 7299 of
these globals in the image**, which makes it a general trap: a bare
`imul dword ptr [<0x1Axxxxx>]` in this executable is as likely to be a hardcoded literal
as a define.

The ones this task needed:

| global | value | used as |
| --- | --- | --- |
| `0x01A88170` | 400 | the naval positioning base, 0.400 |
| `0x01A88174` | 20 | positioning gained per combat tick, 0.020 |
| `0x01A881A0` | 10 | 0.010; the `+0x10B8` die's step, and ~10 other combat sites |
| `0x01A881AC` | 100 | 0.100; leader skill's weight and the positioning floor |
| `0x01A882E8` | 100 | 0.100; leader skill's weight in `UpdatePositioning` |
| `0x0160A7C0` | 1250.5 -> 1250 | the intel-level-2 detection bonus, 1.25x, folded inline |

**So the positioning base, the per-tick gain and the leader-skill weight are hardcoded and
a mod cannot touch them.** Only the three `NAVAL_STACK_POS_*` defines are mod-facing.

## What is not established

- ~~**`CMapProvince +0x2C`**, the byte that decides whether the naval disengage constant
  is 1000 or 11000.~~ **Closed 2026-10-01: it is the night flag**, written at `0x67B204`
  out of `IsNight` (`0x4A7390`), by the weather survey in the same wave. The original note
  is kept because the *reason* it resisted this survey is still worth knowing:
  `CProvince::LoadKey` places
  nothing there, so it is runtime state; a byte displacement is `disp8` and cannot be
  found by the byte scan that worked for the others, and a linear sweep of the 9 MB
  `.text` desynchronises, so this needed either a narrow sweep of the province methods or a
  live watch.
- **`CUnit +0x95`**, the byte on the *target* that doubles its spotting value. `CUnit`'s
  constructor zeroes it as part of a merged dword store at `0x005B50D6`, and I found no
  writer anywhere. Do not confuse it with `CCountry +0x95`, which the supply code reads at
  `0x005BEDAC` to pick between the national pool at `+0x9F8` and the capital's — a
  different class and a different field at the same offset.
- **Which modifier ids the table at `0x0174DA00` holds**, and so what
  `COrder::GetMissionEfficiency`'s second term actually is. The table is past the end of
  the file's `.data`, so it has to come out of a running game.
- **What `positioning` is then multiplied into.** `CNavalCombatant::Attack`
  (`0x00567930`) was read only from `0x00567980` down; the body above that, which is where
  the damage is decided, is untouched.
- **`0x005C7E10`** — the function that sets the `CNavy` cooldown to 8..15. Its three
  callers (`0x00500F22`, `0x00565D99`, `0x0057B01B`) place it in the combat-exit path, but
  I did not read it and it is unnamed.
- **`0x005C7C70`**, the function `CNavy`'s slot 31 calls when the fleet is in a combat.
- **The cadence of `CUnit` slot 31**, still. It is now load-bearing twice: it is the clock
  for the `CNavy` cooldown as well as the only driver of `COrder` slot 14.
- **Nothing here was watched in a running game.** Every number above is read off the
  image. The two that would most repay a live check are the RNG's sign and whether
  `NavalStackingPositionPenalty` really sums one `hull` per *unit* rather than per ship.
