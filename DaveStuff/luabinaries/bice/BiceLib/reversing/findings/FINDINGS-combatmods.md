# Combat modifiers: the whole census, and what decides each value

## 1. Two adders, sixty-nine call sites, one dead id and one that is computed but never added

```
CUnit::AddCombatModifier      0x5C3040  (rva 0x1C3040)  -> CUnit    +0xDC   21 sites
CSubUnit::AddCombatModifier   0x5AC300  (rva 0x1AC300)  -> CSubUnit +0x40   48 sites
```

Both are byte-for-byte the same function against a different object:

```
record = new(12);  record[0] = id;  record[4] = attack;  record[8] = defence
node   = new(16);  node[0] = record; node[4] = old last; node[8] = 0; node[12] = 0
last = node;  ++count;  first = node only when count was 0
a = max(attack  + 1000, floor)          floor = 10
d = max(defence + 1000, floor)
attackProduct = (int64)attackProduct * a / 1000
defendProduct = (int64)defendProduct * d / 1000
```

| | CUnit | CSubUnit |
| --- | --- | --- |
| list first / last / count | `+0xDC` / `+0xE0` / `+0xE4` | `+0x40` / `+0x44` / `+0x48` |
| attack product | `+0xEC` | `+0x50` |
| defend product | `+0xF0` | `+0x54` |
| clamp floor global | `0x1A8873C` (rva `0x168873C`) | `0x1A8868C` (rva `0x168868C`) |

**Both floors are 10.** Each is a separate `(int)floor(10.5f)` static written by its own `.CRT$XCU` initialiser — `0xCC3EB0` for the `CUnit` one, `0xCC36F0` for the `CSubUnit` one, both off the float `10.5` at `0x160A680`. So a product can never fall below 1% however many −100% entries pile up, and **neither is a define**; a mod cannot move it. This closes `project.json`'s open "zero in the image, so presumably set at load".

> *Correction.* `FINDINGS-combat.md`'s *Not settled* list calls `0x1A8868C` an **rva**. It is a virtual address; its rva is `0x168868C`. The same global is the clamp floor here *and* the scale on pending damage in the naval shot loop (`0x567C86`), which is why it shows up twice.

### The census

| pushes to | function | slot | ids |
| --- | --- | --- | --- |
| `CUnit+0xDC` | `CCombatant::AddTerrainModifier` `0x565530` | 20 | `BM_TERRAIN` |
| `CUnit+0xDC` | `CLandCombatant::AddAssaultModifiers` `0x569750` | 27 | `BM_RIVER_PENALTY`, `BM_PARATROOP_PENALTY`, `BM_AMPH_PENALTY`, `BM_FORT_MODIFIER` |
| `CUnit+0xDC` | `CLandCombatant::ApplyCombatModifiers` `0x569B50` | 19 | 16 more (the land set) |
| `CSubUnit+0x40` | `CNavalCombatant::ApplyCombatModifiers` `0x566480` | 19 | 10 |
| `CSubUnit+0x40` | `CAirCombatant::ApplyCombatModifiers` `0x56C6F0` | 19 | 14 sites, 13 ids (`BM_INTERCEPT` twice) |
| `CSubUnit+0x40` | `CBomberCombatant::ApplyCombatModifiers` `0x561680` | 19 | 13 |
| `CSubUnit+0x40` | `CBombTargetCombatant::ApplyCombatModifiers` `0x5627D0` | 19 | 11, shared by all three target combatants. **Renamed 2026-10-02**: `CTargetCombatant` is not a name in this image's RTTI export. The shared base is `CBombTargetCombatant`, which carries **no vftable** (it is abstract and never instantiated), so this body is held at slot 19 by the three concrete target classes directly. `reversing/findings/FINDINGS-slot11.md` §5 |

**Land puts its modifiers on the division (`CUnit`); naval, air and both sides of a bombing put theirs on the individual ship, wing or brigade (`CSubUnit`).**

| id | name | goes to |
| --- | --- | --- |
| 0x00 | BM_DISSENT | both |
| 0x01 | BM_LEADER_BONUS | both |
| 0x02 | BM_DIFFICULTY | both |
| 0x03 | BM_ENCIRCLEMENT_PENALTY | CUnit |
| 0x04 | BM_ENVELOPMENT_PENALTY | CUnit |
| 0x05 | BM_DIVISION_PENALTY | both |
| 0x06 | BM_EXPERIENCE | both |
| 0x07 | BM_MISSION_EFFICIENCY | both |
| 0x08 | BM_TERRITORIAL_PRIDE | CUnit |
| 0x09 | BM_RADIO | CSubUnit (air, bomber, target) |
| 0x0A | BM_DUGIN_MODIFIER | CUnit |
| 0x0B | BM_AMPH_PENALTY | CUnit |
| 0x0C | BM_FORT_MODIFIER | both |
| 0x0D | BM_PARATROOP_PENALTY | CUnit |
| 0x0E | BM_RIVER_PENALTY | CUnit |
| 0x0F | BM_SHORE_BOMBARD | CUnit |
| 0x10 | BM_LACK_OF_SUPPLIES | both |
| 0x11 | BM_MULTIPLE | CUnit |
| 0x12 | BM_COMBINED_ARMS | CUnit |
| **0x13** | **BM_ARMOR_ADVANTAGE** | **no adder site**, but the flag byte *is* set (`0x56AD8D`) — see §1 |
| 0x14 | BM_BASE_PROXIMITY | CSubUnit (air only) |
| 0x15 | BM_POOR_SCREEN_PENALTY | CSubUnit (naval, bombing target) |
| 0x16 | BM_RADAR_STATION | CSubUnit (air, bomber) |
| 0x17 | BM_INTERCEPT | CSubUnit (air only) |
| 0x18 | BM_AIRCOMBAT | CSubUnit (bomber only) |
| 0x19 | BM_TERRAIN | CUnit |
| 0x1A | BM_WEATHER | both |
| 0x1B | BM_NIGHT_MODIFIER | both |
| **0x1C** | **BM_SURPRISE_PENALTY** | **nothing, anywhere** |
| 0x1D | BM_SURPRISE_BONUS | CSubUnit (naval, bomber) |

**`BM_SURPRISE_PENALTY` (0x1C) is dead. `BM_ARMOR_ADVANTAGE` (0x13) is not quite.** Neither has a site to either adder, and for both the only reader of the id is `CombatModifierKey` (`0x564060`) for the localisation key — so neither ever becomes an entry in a modifier list, and the practical conclusion below holds for both. But the claim that *both* per-side flag bytes (§2) go unwritten is wrong: **`0x13`'s flag is written, at `0x56AD8D`**, in the same register and the same idiom as its neighbours. So armour advantage is computed, and the side it favours is flagged; it is only the *modifier* that is never added. `0x1C`'s byte (`+0x24`) really is never touched. *(Corrected 2026-10-01.)* The mod should not be tuning either. `BM_HQ_NEARBY` in the localisation is a third name with no id at all. (Land combat *does* read the `surprise_chance` trait, at `0x56A330`, for the attacker on a combat under 24 ticks old with no dug-in unit — but it feeds something other than a `BM_*` entry, and what was not established.)

> *Correction.* `FINDINGS-combat.md` says `CUnit::AddCombatModifier` "is called 21 times" and that "nine ids have no call site at all" and "the modifier list is land only". The first is right about that adder and wrong about the model; the other two are artefacts of scanning one adder. `project.json`'s `CSubUnit::AddCombatModifier` entry already corrects the conclusion but the site count going round is 22 — **it is 48**, counted directly, in four functions, every one with the id as an immediate and zero `ret`s between function start and call.

### Why the id reads statically and the values do not

Every site pushes a *register* (the old tool reported `['ecx','ecx','<id>']`). The compiler materialises each value into a one-dword stack slot and pushes the slot's **address**, then overwrites the slot. `BM_DISSENT` is the clean trace; let `E` be `esp` before it:

```
0x56A68E  push ecx            ; S1 at E-4
0x56A68F  mov  ecx, esp       ; ecx = &S1
0x56A695  mov  [ecx], 0
0x56A69B  neg  eax
0x56A69D  push ecx            ; S2 at E-8, holding &S1 for one instruction
0x56A69E  mov  [ecx], eax     ; S1 = value
0x56A6A0  mov  ecx, esp       ; ecx = &S2
0x56A6A6  mov  [ecx], 0
0x56A6AC  push 0              ; S3 = the id
0x56A6AE  mov  [ecx], eax     ; S2 = value
0x56A6B0  call AddCombatModifier
```

The `call` pushes the return address, so inside the callee `[ebp+8] = S3 = id`, `[ebp+0xC] = S2 = attack`, `[ebp+0x10] = S1 = defence`. **S2 is the attack side and S1 the defence side**, and reading that backwards is the one way to get §3 wrong.

Most sites pass the same number twice. The ones that do not are all on the sub-unit adder:

| site | id | attack | defence |
| --- | --- | --- | --- |
| `0x566756` naval, `0x5629FE` bombing target | BM_POOR_SCREEN_PENALTY | 0 | `-penalty` |
| `0x562A69` bombing target | BM_FORT_MODIFIER | 0 | `+100 per level` |
| `0x566BC4`, `0x56D147`, `0x562174` | BM_WEATHER | `-penalty` | 0 |
| `0x566CA7`, `0x56D24B`, `0x562EF5` | BM_NIGHT_MODIFIER | `penalty` | 0 |
| `0x566791`, `0x561BCD` | BM_SURPRISE_BONUS | `bonus` | 0 |
| `0x56CC3F`, `0x56CCED` air | BM_INTERCEPT | `bonus` | 0 |

**Naval and air weather and night cost attack only; a capital ship's poor-screen penalty and a bombing target's fort bonus are defence only.** `AIR_SUP_DEFEND_BONUS` lands in the **attack** slot at `0x56CCED` despite its name — recorded as what the bytes do.

---

## 2. `CCombatant + 0x08 + id` is one bool per modifier id

`CCombatant::CCombatant` zeroes `+0x08..+0x25` with three `movq`, a dword and a word and `FINDINGS-combat.md` records them as "all unnamed". `CCombatant::ApplyCombatModifiers` (`0x565590`) zeroes the same 30 bytes at its top, and **every one of the 69 sites sets `this->[8 + id] = 1` immediately after its `call`.** Thirty ids, thirty bytes: `+0x08` BM_DISSENT through `+0x25` BM_SURPRISE_BONUS, checked on all 24 distinct ids that have a site with no exception. `+0x24` (id `0x1C`, `BM_SURPRISE_PENALTY`) is never written — independent confirmation that that id is dead. *(Corrected 2026-10-01: this originally said `+0x1B` goes unwritten too. It does not; it is written at `0x56AD8D`. `BM_ARMOR_ADVANTAGE` is computed and flagged and only its modifier entry is missing, so the flag array is **not** a second witness for it — see §1.)*

A per-side "which modifiers were in play this tick" bitmap, reset every tick, almost certainly what the battle UI reads to choose rows.

---

## 3. The shared top of every tick: `CCombatant::ApplyCombatModifiers` (`0x565590`)

`ret 8`, `this` in ECX, `(CCombatant* other, bool flag)`. All five slot-19 overrides call it first (`0x5616C2`, `0x562801`, `0x5664B8`, `0x569B80`, `0x56C721`). It:

1. zeroes the 30 flag bytes at `+0x08..+0x25`;
2. per `CUnit` on `units` (`+0x40`): `CUnit::ResetCombatModifiers` (`0x5C2FE0` — frees the `+0xDC` list, writes 1000 into `+0xEC`, `+0xF0`, `+0xF4`, `+0xF8`), then **`unit->+0x15C = 0`** at `0x5655D3`;
3. per `CSubUnit` on `unit->regiments` (`+0x38`): frees every node of the `CList` at `+0x40/+0x44/+0x48`, zeroes the three, writes **1000 into `+0x50` and `+0x54`**, zeroes `+0xC4`.

**`CUnit::defences_used` is reset here** — `0x5655D3`, once per unit per tick per side. `FINDINGS-combat.md` lists that as not settled.

> *Correction, and the one worth arguing about.* `FINDINGS-combat.md` says `CUnit::ResetCombatModifiers` "has exactly two callers — the land slot 19 and `CUnit::~CUnit`", and concludes a ship's or wing's `CUnit+0xDC` is "never filled **and never cleared**", citing a hardware write watchpoint on `+0xE4` that fired zero times through a whole naval and a whole air battle.
>
> The count is two, but the caller is the **base** `0x565590`, not the land override, and every kind runs the base. Byte evidence: callers of `0x5C2FE0` are `{0x5655CE, 0x5B5621}`; callers of `0x565590` are all five slot-19 overrides; `0x5C2FE0` writes `[unit+0xDC] = [unit+0xE0] = [unit+0xE4] = 0` at `0x5C3015..0x5C301A`. So in a naval or air battle the fleet's or air unit's `CUnit+0xDC` **is** cleared and `+0xE4` **is** written, once per side per tick. "Never filled" survives; "never cleared" does not, and the live watch needs re-siting onto a `CUnit` that is actually a node of `CCombatant+0x40` in that battle.

**Slot 21 is a stub.** Land, naval, air, bomber and target all call `this->slot 21(unit, other)` just before their night block. `CCombatant` slot 21 is `0xA806D0` — one of the shared no-op stubs (336 slots) — and nobody overrides it. **Slot 20 (`AddTerrainModifier`) is on the shared base but only the land slot 19 calls it** (`0x56A960`), so `BM_TERRAIN` is land-only in practice even though the function is not.

---

## 4. The vocabulary these formulas are written in

**Leader trait effect kinds are a 0-based enum in the order `common/traits.txt`'s own header comment lists them.** `CUnit::GetTraitEffect` (`0x5D1120`) takes the kind as its second argument; the modifier code pushes eight where the meaning is not in doubt, each agreeing with the comment's position — `7 river_attack` (`0x569840`), `8 fort_attack` (`0x569AE9`), `24 fort_defence` (`0x569B19`), `25 amph_attack` (`0x5698D7`), `27 paradrop_mission` (`0x569881`), `29 terrain_attack` (`0x56AAA2`), `30 terrain_defence` (`0x56AAE8`), plus the already-known `0 xp_gain` and `2 supply_consumption`. That settles all 31:

```
 0 xp_gain              8 fort_attack            16 strategic_attack   24 fort_defence
 1 surprise_chance      9 combined_arms_bonus    17 naval_attack       25 amph_attack
 2 supply_consumption  10 out_of_supply_modifier 18 night_attack       26 digin_bonus
 3 defence_modifier    11 submarine_attack       19 tactical_attack    27 paradrop_mission
 4 offence_modifier    12 disengage_timer        20 dissent_impact     28 terrain_speed
 5 combat_move_speed   13 spread_out             21 encirclement_bonus 29 terrain_attack
 6 winter_attrition    14 spotting_chance        22 envelopment_bonus  30 terrain_defence
 7 river_attack        15 defender_softness      23 experience_bonus
```

`0x5D0F80` is the extended sibling, `(int* out, int kind, int subType)`, for the three kinds that take a type.

**A province's modifier values are at `CMapProvince + 0x114`, a country's at `CCountry + 0xDA8`, offset `id * 8`.** Fixed by four independently-known reads: `+0x50` = id 10 `FORT_LEVEL`, `+0x58` = id 11 `COASTAL_FORT_LEVEL` (`0x569A8B`, `0x569AB4`); `+0x180` = id 48 `MODIFIER_RADAR_LEVEL` (`0x56C7DC`); `+0x138` = id 39 `MODIFIER_TERRITORIAL_PRIDE` and `+0x320` = id 100 `MODIFIER_LEADER_DEFENCE` (`0x56ACF7`, `0x56AB1D`).

**`ProvinceEdge::kind` is 1 for a sea crossing and 2 for a river crossing** — `AddAssaultModifiers` tests `== 2` at `0x569812` for the river branch and `== 1` at `0x569818` for amphibious. That is the engine's own definition of "crossing a river".

**`CUnit + 0xC8`'s adjusters are brigade sums.** `CSubUnitDefinition::Add` (`0x5A7FC0`) is a field-by-field `+=`, and its tail at `0x5A8288..0x5A82CD` loops over `(dst->+0x58 − dst->+0x54) / 0x18` entries adding each source terrain adjuster's `attack`, `defence`, `movement` and `attrition`; `0x5A8300` onward does the same for `other_adjusters` at `+0xC4`. Its only caller is `0x5B5ED0`, once per regiment with `ecx = regiment->+0x58`, `esi = unit->+0xC8`; the only field averaged afterwards is `+0x188`, and `+0x108`, `+0x12C`, `+0x13C`, `+0x148` take a max. **So a three-brigade division's terrain / night / fort / river / amphibious adjuster is three times one brigade's**, and that is what `BM_TERRAIN`, `BM_NIGHT_MODIFIER`, `BM_FORT_MODIFIER`, `BM_RIVER_PENALTY` and `BM_AMPH_PENALTY` read on land. **Read out of the code and not checked against a running game** — see the end.

`0x5B5ED0` also builds `CUnit+0x1D0` (a bitmap of the combined-arms groups the division contains) and `CUnit+0x1CC` (`base_ca_bonus` = the sum of each present group's `+0x28`, when at least one group with its `+0x24` byte set is present).

---

## 5. What decides each modifier, land

`CLandCombatant::ApplyCombatModifiers` (`0x569B50`) walks `this->units` and runs these per `CUnit`. `unit` = the division, `def` = `unit->+0xC8` (the **summed** definition), `country` = `unit->+0x290 ? unit->+0x28C : unit->+0x124` through `0x402610`, `combat` = `this->+0x3C`, `prov` = `combat->+0x18`. Thousandths; `trait(n)` = `CUnit::GetTraitEffect(unit, n)`. Every land site passes the same number for attack and defence.

Before the loop it also does the amphibious-invasion interpolation already in `FINDINGS-combat.md`, writing `CUnit+0xF4`/`+0xF8` — a different pair of fields, not a list entry.

**BM_SHORE_BOMBARD (0x0F)**, `0x56A36C` — computed once per side at `0x569D37..0x569FFE`:
```
shore = 0
for each edge of prov: n = the neighbour
    if n is water and n->units (+0x2B8) is non-empty:
        for each enemy unit u in n with u->+0x140 > 0 and a hostile owner (or either side REB):
            shore += u->+0xC8->shore_bombardment (+0x170) * SHORE_BOMBARDMENT_MOD / 1000
if shore > SHORE_BOMBARDMENT_CAP: shore = SHORE_BOMBARDMENT_CAP     ; a floor on a negative
if shore != 0: add(BM_SHORE_BOMBARD, shore, shore)
```
Both defines are negative in this mod (`-0.007`, `-0.75`), so the "cap" clamps magnitude. Nothing checks whether *this* side has a fleet.

**BM_MULTIPLE (0x11)**, `0x56A422`: `if !is_attacker and unit->combats.count (+0x11C) > 1: add(-MULTIPLE_COMBATS_PENALTY)`. **Flat** — it does not scale with how many combats.

**BM_DIFFICULTY (0x02)**, `0x56A451` — `0x4DF9B0`, `int* __stdcall (int* out@[ebp+8], CCountry* country@EDI)`, shared by all five kinds:
```
settings = [0x1A89790]                  ; lazy singleton, 0xDA8 bytes, vftable 0x15CF674
if settings->+0xBCC[country->+0xCA8] == 0: *out = 0        ; not a human-played country
else: bonus = one of { 0, +2000, +1000, -1000, -2000 } by settings->+0xC98 (the difficulty)
      *out = bonus * COMBAT_DIFFICULTY_IMPACT / 1000
```
So it applies **only to the player's own countries**. The jump table is `0x4DFADC`; the arms are `0x7D0`, `0x3E8`, `-0x3E8`, `-0x7D0` and a fall-through zero, but **which setting index maps to which arm was not read**.

**BM_EXPERIENCE (0x06)**, `0x56A4BD`:
```
base = unit->slot 22 () * 10 / 1000              ; the division's average experience
if base: add(base * (1000 + trait(23 experience_bonus)) / 1000)
```
The `10` is the `(int)floor(10.5f)` static at `0x1A881A0`, not a define. A unit at 100 experience contributes **+100%** before the trait.

**BM_MISSION_EFFICIENCY (0x07)**, `0x56A559`:
```
i = OrderTypeToMissionIndex(unit->order(+0xB0)->slot 16 ())              ; 0x584410
v = order->unit(+0x8)'s country->CTechnologyStatus(+0xDF8)->[0xE0 + i*4]
if i != 0: v += country->modifiers(+0xDA8)[ 0x174DA00[i] ]
if v: add(v, v)
```
**`0x174DA00` is zero in the image** — the index-to-modifier-id table is filled at startup, so reading it needs a running game. Naval, air and target add `if order->slot16() == 0x255: skip`.

**BM_COMBINED_ARMS (0x12)**, `0x56A591`: only when `unit->+0x1CC > 0`; `CUnit::GetCombinedArmsBonus` (`0x5B6240`) returns `trait(9 combined_arms_bonus) + Σ(country->CTechnologyStatus->+0x5C[g] over every group g set in unit->+0x1D0) + unit->+0x1CC`.

**BM_DISSENT (0x00)**, `0x56A6B0`:
```
d = country->dissent (+0x10B4)
if d: v = COMBAT_DISSENT_IMPACT * (d * 10 / 1000) / 1000
      v = v * (1000 + trait(20 dissent_impact)) / 1000
      add(-v, -v)
```

**BM_LACK_OF_SUPPLIES (0x10)**, `0x56A7B4`:
```
s = unit->supply_received (+0xFC)
if s != 1000 and !unit->+0x97:
   v = COMBAT_SUPPLY_LACK_IMPACT * (1000 - s) / 1000 * (1000 + trait(10 out_of_supply_modifier)) / 1000
   add(-v, -v)
```

**BM_DUGIN_MODIFIER (0x0A)**, `0x56A89C`: `if !is_attacker and unit->dig_in (+0x1C8) > 0: add(dig_in * DIG_IN_FACTOR / 1000 * (1000 + trait(26 digin_bonus)) / 1000)`.

**BM_DIVISION_PENALTY (0x05)**, `0x56A952` — the stacking penalty, computed once per side at `0x56A1CE..0x56A25B`:
```
pen = 1000 + BASE_STACKING_PENALTY
n   = (units on this->reserves (+0xC0) whose slot 33 answers true)
      + this->front_line.count (+0xB8)
      - 3 * (distinct provinces the enemy attacks from)
f   = 1000; for i in 1 .. min(n-1, 99): f = f * pen / 1000
raw = 1000 - f
per unit:
  v = raw - country->CTechnologyStatus(+0xDF8)->+0x6C
  walk up unit->+0x1E0 to the unit whose oob_level (+0x1F4) is 0
  if found: v -= floor((theatreLeader->skill(+0x70) + 0.0005) * 1000) * 10 / 1000
  if v > 0: add(-v, -v)
```
`BASE_STACKING_PENALTY` is `-0.025`, so the factor is `0.975^(n-1)`. **The exponent falls by 3 for each extra province the enemy attacks from.** The doubles are `0.0005` (`0x160A460`) and `1000.0` (`0x160A300`) — the engine's `int_thousandths(float)` idiom.

**BM_WEATHER (0x1A)**, `0x56A9B7`: calls slot 20 (`AddTerrainModifier`) first, then `v = CWeather::LandCombatEffect(&prov->+0x68, &out, unit->owner)` (`0x4B4000`, already in `project.json`, answers a positive penalty); `add(-v, -v)`.

**BM_NIGHT_MODIFIER (0x1B)**, `0x56AA1B`: calls slot 21 (the no-op stub) first, then
```
if prov->is_night (+0x2C):
   v = BASE_NIGHT_PENALTY + def->night.attack (+0x6C) + trait(18 night_attack)
   if v < 0: add(v, v)
```
Land uses `night.attack` for **both** sides, unlike naval and air; and `def` is the summed definition, so the brigades' `night` blocks add up.

**BM_LEADER_BONUS (0x01)**, `0x56AB59`:
```
if 0x5CD960(unit) and leader->skill (+0x70) > 0:
   base = skill * 1000 * COMBAT_LEADER_IMPACT / 1000
   t = prov->template(+0xD4)->terrain(+0xC)->slot 7 ()
   if is_attacker: v = 0x5D0F80(unit, &out, 29 terrain_attack, t) + trait(4 offence_modifier) + base
   else:           v = (trait(3 defence_modifier) + 0x5D0F80(unit, &out, 30 terrain_defence, t) + base)
                       * (1000 + country->modifiers[100 MODIFIER_LEADER_DEFENCE]) / 1000
   add(v, v)
```
`0x5CD960` (`this` in EAX) is a jump table on `unit->oob_level` over the leader's **rank** (`CLeader+0x6C`, not skill): 3 at the top two levels, 2 at the next, 1 below, one arm deferring to `0x5CD920`. **A leader of insufficient rank contributes nothing at all.** `MODIFIER_LEADER_DEFENCE` applies on defence only.

**BM_ENVELOPMENT_PENALTY (0x04)**, `0x56AC14`:
```
directions = distinct provinces the enemy's units sit in        ; built 0x56A02F/0x56A0CD
if !is_attacker and directions > 2 and !0x4A9BE0(prov->template):
   v = (directions - 2) * 1000 * ENVELOPMENT_PENALTY / 1000 * (1000 + trait(22 envelopment_bonus)) / 1000
   if v < 0: v = 0
   add(-v, -v)
```
`0x4A9BE0` (`this` in EAX) answers true for a land province **every one of whose neighbours is water** — an island with no land border — and that case is exempt.

**BM_ENCIRCLEMENT_PENALTY (0x03)**, `0x56ACAB`: `if prov->template->is_land and !is_attacker and 0x4A6850(prov@EDI, &unit->owner): v = ENCIRCLED_PENALTY * (1000 + trait(21 encirclement_bonus)) / 1000; if v < 0: v = 0; add(-v, -v)`. `0x4A6850` was not read through — "the province is encircled for this owner" is a reading of its use.

**BM_TERRITORIAL_PRIDE (0x08)**, `0x56AD19`: only where the combat province is a **core** of the unit's owner (a walk of `prov->cores` at `+0x344` for a node whose `+4` matches the owner id); then the whole value is `country->modifiers[39 MODIFIER_TERRITORIAL_PRIDE]` — no define.

**BM_TERRAIN (0x19)**, `0x56557D` in `CCombatant::AddTerrainModifier` (`0x565530`, `ret 8`, `this` in ECX, `CUnit*` at `[ebp+8]`, no direct callers):
```
terrain = this->combat(+0x3C)->terrain(+0x24)
adj     = unit->+0xC8->terrain_adjusters(+0x54)[terrain->id(+0x8)]      ; 0x18 bytes each
if is_attacker: v = terrain->attack  (+0x50) + adj->attack  (+0x8)
else:           v = terrain->defence (+0x4C) + adj->defence (+0xC)
if v != 0: this->+0x21 = 1; add(BM_TERRAIN, v, v)
```
The stride is `lea eax,[eax+eax*2]` then `lea eax,[edi+eax*8]` = 24, confirming the vector is indexed by terrain id. **No define enters at all** — the value is `map/terrain.txt` plus the unit file's per-terrain block, summed over brigades.

### `CLandCombatant::AddAssaultModifiers` (`0x569750`), slot 27 — attacker only (from `0x56A347`)
```
amph = false
if the unit's own province is water:  amph = true, unless the owner tag is "REB"
else: find the ProvinceEdge from the unit's province to the combat's;
      kind 2 -> the river branch;  kind 1 -> amph = true
```
**BM_RIVER_PENALTY (0x0E)**, `0x569864`: `v = RIVER_CROSSING_PENALTY + def->river.attack (+0x9C) + trait(7 river_attack)`; added only when negative; sets `+0x16`.

**BM_PARATROOP_PENALTY (0x0D)**, `0x5698A5`: when `unit->+0x97`, `v = PARADROP_PENALTY + trait(27 paradrop_mission)`, negative only, sets `+0x15`, and **clears `amph`**.

**BM_AMPH_PENALTY (0x0B)**, `0x569A63`:
```
v = AMPHIBIOUS_LANDING_PENALTY + def->amphibious.attack (+0xB4) + trait(25 amph_attack)
if v < 0 and 0x5C2E80(unit, 0) and the province has a naval base (+0x300):
    cap = AMPHIBIOUS_INVADE_LANDING_PENALTY_DECREASE
    s   = 1000 + Σ over the division's regiments of
                 lookup(base->+0xC8->+0x218.., regiment->def->type_index)->+0x10
    r   = min(s * base->+0xC8->+0x18C / 1000, cap)
    v   = v * (1010 - r * 1000 / cap) / 1000
v = max(v, -990)
if v < 0: this->+0x13 = 1; add(v, v)
```
`1010` and `-990` are inline `floorf` of the literals `1010.5` (`0x160A7C8`) and `-989.5` (`0x160A7C4`) — compiled in, not defines. At full landing-craft technology the penalty is multiplied by `10/1000`, i.e. all but cancelled. The `+0x218`/`+0x21C` map and `+0x18C` were not identified.

**BM_FORT_MODIFIER (0x0C)**, `0x569B3D`:
```
level = prov->modifiers[amph ? 11 COASTAL_FORT_LEVEL : 10 FORT_LEVEL] / 1000 * 1000
if level > 0:
   if is_attacker: v = level * BASE_FORT_PENALTY / 1000 + trait(8 fort_attack) + def->fort.attack (+0x84)
                   if v > 0: v = 0
   else:           v = trait(24 fort_defence)
   if v != 0: this->+0x14 = 1; add(v, v)
```
Truncated to whole levels. **The defender's side is the `fort_defence` trait and nothing else** — the fort reaches land combat only as the attacker's penalty.

---

## 6. Naval (`0x566480`)

Per **fleet**, then per **ship**. The modifier goes on the ship; `sdef = ship->+0x58` — **that one ship's own definition**, not a sum. The fleet supplies the traits and the supply figure.

```
capitals = ships with sdef->is_capital (+0x2F)
subs     = ships with sdef->is_sub (+0x31)
screens  = ships with sdef->is_ship (+0x2E) and not sdef->is_transport (+0x30)
poorScreen = capitals > 0 && screens < capitals
             ? (1000 - screens*1000*1000/(capitals*1000)) * 1000 / 3000 : 0
subSurprise = (flag == 0 && is_attacker && combat->day (+0x1C) < 1 && subs > 0
               && Random() % 100 < NAVAL_COMBAT_SUB_SURPRISE_CHANCE/1000
               && combat->day < NAVAL_COMBAT_SUB_SURPRISE_ROUNDS/1000)
              ? NAVAL_COMBAT_SUB_SURPRISE_BONUS : 0
```

| id | site | formula |
| --- | --- | --- |
| BM_POOR_SCREEN_PENALTY 0x15 | `0x566756` | capitals only; `add(0, -poorScreen)` — **defence only** |
| BM_SURPRISE_BONUS 0x1D | `0x566791` | subs only; `add(subSurprise, 0)` — **attack only** |
| BM_DIFFICULTY 0x02 | `0x5667CA` | the same `0x4DF9B0`, both sides |
| BM_EXPERIENCE 0x06 | `0x5668C2` | `e = max(ship->experience (+0x3C), 0); if ship->pride (+0xA5): e += PRIDE_BONUS_EXP; v = e*10/1000 * (1000 + trait(23))/1000` — **the ship's own experience, not a fleet average** |
| BM_MISSION_EFFICIENCY 0x07 | `0x566975` | as land, plus `if order->slot16() == 0x255: skip` |
| BM_DISSENT 0x00 | `0x566A4E` | `-(COMBAT_DISSENT_IMPACT * (dissent*10/1000) / 1000)` — **no `dissent_impact` trait, unlike land** |
| BM_LACK_OF_SUPPLIES 0x10 | `0x566B4C` | as land, **without** the paradrop gate |
| BM_WEATHER 0x1A | `0x566BC4` | inline off `prov+0x68`: `windspeed(+0x10)*NAVALWINDSPEEDMODIFIER/1000 + precipitation(+0x18)*NAVALRAINMODIFIER/1000`; `add(-v, 0)` — **attack only, and no `CWeather::` helper** |
| BM_NIGHT_MODIFIER 0x1B | `0x566CA7` | `BASE_NIGHT_PENALTY + (is_attacker ? sdef->night.attack(+0x6C) : sdef->night.defence(+0x70)) + trait(18)`; negative only; `add(v, 0)` — **attack only, though it picks the side's own adjuster** |
| BM_LEADER_BONUS 0x01 | `0x566E18` | the rank ladder inlined, then `skill * 1000 * COMBAT_LEADER_IMPACT / 1000`, both sides. **No traits, no terrain, no `MODIFIER_LEADER_DEFENCE`** |

Both weather defines come from cached globals (`0x1A87058`, `0x1A86FFC`), which is why a `GetDefines` scan finds no reader.

---

## 7. Air (`0x56C6F0`)

Per **air unit**, then per **wing**; `wdef = wing->+0x58`.
```
wings    = Σ over this->units of unit->regiments.count (+0x40)
airStack = max((wings*1000 - 1000) * AIR_STACKING_PENALTY / 1000, AIR_STACKING_PENALTY_MAX)
radar    = best of prov->modifiers[48 MODIFIER_RADAR_LEVEL] and every neighbour's,
           over provinces whose controller passes 0x4EF7C0
```

| id | site | formula |
| --- | --- | --- |
| BM_DIFFICULTY 0x02 | `0x56C954` | as land |
| BM_EXPERIENCE 0x06 | `0x56CA4B` | as naval, on the wing's own experience and pride |
| BM_BASE_PROXIMITY 0x14 | `0x56CB84` | `BASE_PROXIMITY_BONUS` when the combat province is the unit's home-base (`+0x98`) province or adjacent to it |
| BM_INTERCEPT 0x17 | `0x56CC3F` | `!wdef->+0x37 && order->slot16() == 0x718` → `add(INTERCEPT_ATTACK_BONUS, 0)` — attack only |
| BM_INTERCEPT 0x17 | `0x56CCED` | `order->slot16() == 0x6FA` → `add(AIR_SUP_DEFEND_BONUS, 0)` — **attack only, despite the name** |
| BM_MISSION_EFFICIENCY 0x07 | `0x56CD9F` | as naval |
| BM_LACK_OF_SUPPLIES 0x10 | `0x56CE95` | as naval |
| BM_RADIO 0x09 | `0x56CEE3` | `v = country->CTechnologyStatus(+0xDF8)->+0xA4; if v: add(v, v)` — a pure technology figure, no define |
| BM_DISSENT 0x00 | `0x56CFD5` | as naval |
| BM_DIVISION_PENALTY 0x05 | `0x56CFFB` | `if airStack < 0: add(airStack, airStack)` — **not the exponential land formula** |
| BM_RADAR_STATION 0x16 | `0x56D0EC` | `radar * RADAR_COMBAT_IMPACT / 1000 * (1000 + wing's country->CTechnologyStatus->+0xC0) / 1000` |
| BM_WEATHER 0x1A | `0x56D147` | `CWeather::AirCombatEffect(prov+0x68@EDI, &out@ESI, wing->+0x94/+0x98)`; `add(-v, 0)` — attack only |
| BM_NIGHT_MODIFIER 0x1B | `0x56D24B` | `BASE_NIGHT_PENALTY + (is_attacker ? wdef->night.attack : wdef->night.defence) + trait(18 night_attack) + wdef->air_detection (+0x154) * 10 / 1000`; negative only; `add(v, 0)` |
| BM_LEADER_BONUS 0x01 | `0x56D389` | as naval |

**`air_detection` is what buys back the night penalty** — `10/1000` of it, flat, with the `10` a compiled-in `(int)floor(10.5f)` rather than a define. The only read of `air_detection` in the modifier code. Note the radar and weather blocks resolve the **wing's own** `CCountryTag` at `CSubUnit+0x94/+0x98`, not the unit's owner.

---

## 8. Bombing

### `CBomberCombatant::ApplyCombatModifiers` (`0x561680`) — the air set with three differences
```
stack = max( Σ over wings of (wdef->+0x32 && the target province is water
                              ? CAG_STACKING_PENALTY : 1000) * AIR_STACKING_PENALTY / 1000,
             AIR_STACKING_PENALTY_MAX )                                    -> BM_DIVISION_PENALTY 0x562021
navSurprise = (other->slot 9 () && flag == 0 && is_attacker && combat->day < 1
               && Random() % 100 < AIR_COMBAT_NAV_SURPRISE_CHANCE/1000
               && combat->day < AIR_COMBAT_NAV_SURPRISE_ROUNDS/1000)
              ? AIR_COMBAT_NAV_SURPRISE_BONUS : 0                          -> BM_SURPRISE_BONUS 0x561BCD, attack only
```
**BM_AIRCOMBAT (0x18)**, `0x561C34` — the cost of being intercepted while bombing:
```
v = 0
for each air unit u on this side:
  for each combat c on u->combats (+0x114) whose kind (slot 11) is 3:
     defenders = Σ subunit->strength (+0x5C) over every regiment of every unit of c->defender (+0x14)
     attackers = the same over c->attacker (+0x10)
     v += (max(attackers,1000) * 1000 / max(defenders,1000)) * AIR_COMBAT_ON_BOMBING / 1000
if v != 0: add(v, v)
```
`AIR_COMBAT_ON_BOMBING` is `-0.4`. The penalty grows with the air combat's attacker-to-defender strength ratio, summed over every air combat the bombing units are also in. Which of those two is the interceptor was not established.

### `CTargetCombatant::ApplyCombatModifiers` (`0x5627D0`) — one body for all three target combatants
`BM_DIFFICULTY` (`0x5629C3`), `BM_EXPERIENCE` (`0x562B4D`), `BM_MISSION_EFFICIENCY` (`0x562BE0`), `BM_LACK_OF_SUPPLIES` (`0x562CD6`), `BM_RADIO` (`0x562D05`), `BM_DISSENT` (`0x562DD6`), `BM_NIGHT_MODIFIER` (`0x562EF5`) and `BM_LEADER_BONUS` (`0x56305E`) are the naval/air formulas. Its own three:

| id | site | formula |
| --- | --- | --- |
| BM_POOR_SCREEN_PENALTY 0x15 | `0x5629FE` | the naval screens/capitals fraction; `add(0, -penalty)` — **defence only** |
| BM_FORT_MODIFIER 0x0C | `0x562A69` | `level = prov->modifiers[10 FORT_LEVEL] / 1000; v = level * 1000 * 100 / 1000; if v: add(0, v)` — **defence only, +100 (10%) per whole fort level, and the 100 is the `(int)floor(100.5f)` static at `0x1A88110`, not `BASE_FORT_PENALTY` or any other define** |
| BM_DIVISION_PENALTY 0x05 | `0x562E12` | `n = Σ unit->regiments.count * 1000 * 10 / 1000; v = n - country->CTechnologyStatus->+0x6C; if v > 0: add(-v, -v)` |

The hardcoded fort bonus is probably the single most useful line here for a rebalance: **a bombing target's fort defence cannot be tuned from `defines.lua` at all.**

---

## 9. `CNavalCombatant::Attack` (slot 15, `0x567930`) — read through

### The positioning creep is at the *head*, not the tail
```
0x56795E  0x564890(&this->units)                      ; not identified
0x567963  NAVAL_DOCTRINE_INCREASE into a local
0x567987  0x565430(this, GetDefines()+0x2C)           ; refresh the doctrine figures
0x56798D  leader = 0x565F20(this)
          cap = 400                                   ; (int)floor(400.5f), 0x1A88170
          if leader->slot 8 (): cap += floor((leader->+0x70 + 0.0005) * 1000) * 100 / 1000
          cap -= NavalStackingPositionPenalty(&this->units)        ; 0x5D5B80
          cap = max(cap, 100)                         ; 0x1A881AC
          if this->positioning (+0x10B4) < cap: this->positioning += 20   ; 0x1A88174
0x567A28  if other->slot 7 (): otherPenalty = 0x5D5B80(&other->units) else 0
0x567A56  0x5D6AC0(&this->units, &out)                ; not identified
```
`FINDINGS-combat.md` and `project.json` have the arithmetic right and the location wrong — this is the function's first forty instructions. The positioning **die** at `+0x10B8` is not read here at all.

### Positioning is multiplied into target selection, not into damage
`+0x10B4` has exactly two readers in `Attack` and both are the creep. The consumer is `CNavalCombatant::PickTarget` (`0x5675D0`), `(CSubUnit* attacker@ECX, CNavalCombatant* side@[ebp+8], CCombatant* other@[ebp+0xC])`:
```
country = resolve(attacker->unit(+0xB0)'s expeditionary owner or owner)
p = attacker->+0x58->positioning (+0x184) + side->positioning (+0x10B4)
p = p * 100000 / 1000                                      ; x100
p = p * (1000 + country->CTechnologyStatus(+0xDF8)->+0x70) / 1000
p = p / 1000
if the combat's province is at night: p = p / 2
```
and `p` then gates the search over the enemy's list, with `Random` (`0xAA2F80`) drawn at five points. **So positioning buys a better choice of target, not a bigger hit** — the definition field `positioning`, the side's accumulated `+0x10B4`, a naval technology figure at `CTechnologyStatus+0x70`, and half of all of it at night. The selection rule past the gate was not read; `attacker->+0xB8/+0xBC`, which the search walks, is unidentified.

### A ship's attack becomes damage
Per fleet, per ship (`attacker`), `def = attacker->+0x58`:
```
if def->sea_attack (+0x168) == 0: skip
if attacker->organisation (+0x60) <= 0: skip
target = CNavalCombatant::PickTarget(attacker, this, other); if none: skip

a = def->sea_attack (+0x168)
if combat->+0x2B and this->is_attacker:  a = def->convoy_attack (+0x164)
if target->+0x58->is_sub (+0x31):
    a = def->sub_attack (+0x16C) * (1000 + GetTraitEffect(attacker->unit, 11 submarine_attack)) / 1000

shots = a * attacker->+0x50 / 1000          ; the SHIP's combat attack product
whole = shots / 1000;  frac = shots - whole*1000
one more shot with probability frac/1000    ; MT19937 at 0x1710F80, index 0x1711940
```
**That settles what `CSubUnit+0x50` is for**: the product of every `BM_*` attack side on that ship multiplies its shot count, exactly as `CUnit+0xEC * CUnit+0xF4` does for a division. `CSubUnit+0x54` is the defence side.

**`+0x54`'s consumer was found on 2026-10-01, and this said "no reader was found anywhere" until then.** It is read at `0x56645E`, inside **`CCombatant` slot 11 (`0x5662F0`)**, in that function's per-sub-unit loop. *(Corrected the same day: this first said `CCombatant::ApplyLosses` (`0x565FD0`). It is not - `ApplyLosses` ends with its own `ret 4` at `0x5662ED` and slot 11's prologue is the next byte, with no padding; all seven `CCombatant`-family vftables hold `0x5662F0` at slot 11. The address of the read is right, the owning function was wrong, and the cause was trusting `functionStart` without running `retsBefore`.)*

```
0x566356  mov eax,[esi] ; mov edx,[eax+0x24] ; mov ecx,esi ; call edx   ; slot 9
0x566361  je   0x566455                        ; slot 9 false -->
...
0x566455  mov eax,[esi] ; mov edx,[eax+0x28] ; mov ecx,esi ; call edx   ; slot 10
0x56645E  mov eax,[esi+0x54]                   ; the DEFENCE product
0x566461  imul dword ptr [esi+0x50]            ; x the ATTACK product
0x56646D  call 0xB99980                        ; /1000 -> [ebp-4]
0x566475  jmp  0x566420                        ; rejoin the accumulate
```

`esi` is a `CSubUnit`, established from slot 11's own body: it multiplies `[esi+0x60]` by `[esi+0x5c]` (organisation by strength) at `0x56633C` and reads `[esi+0x58]` (the definition). *The first version argued this from `+0x58`/`+0x5C`/`+0xA8` reads at `0x566237` and `0x566267`, which are in `ApplyLosses` - a **different** function - so that reasoning was void even though the conclusion holds.* `[ebp-4]` is the per-sub-unit loss factor, which the block at `0x566420` multiplies into `[ebp-0x14]` and accumulates through `[edi]`. **So the defence-side product is read** - but not by the loss calculation. *(Corrected 2026-10-01, see `FINDINGS-combat3.md` §3: slot 11 sums strength, and its only two invocations in the image are inside `CCombat` slot 17 (`0x57B050`), whose only consumer is the `combat_status` window's per-tick refresh. `[ebp-4]` is a per-sub-unit strength term, not a loss factor - the word 'loss' came from the wrong owner, `ApplyLosses`, and survived the owner being corrected. On this reading a defence-side naval, air or bombing modifier, including the two defence-only ids, changes a percentage on screen and nothing in the simulation. The attack side is different: `+0x50` multiplies the shot count in `CNavalCombatant::Attack`.)*

**What slot 11 actually computes**, read in full by the negatives survey, reframes this: **both** arms multiply an attack side by a defence side. The land arm uses all four of `CUnit +0xEC`, `+0xF0`, `+0xF4`, `+0xF8` and never touches the sub-unit's pair; the naval and air arm uses `(CSubUnit +0x54 x +0x50) / 1000` and never touches the `CUnit` fields. So on a ship or wing the two products are used **together** - a stronger result than "the defence side is read somewhere". See `FINDINGS-negatives.md` §4.

The other arm of that `je` - taken when slot 9 answers true - uses the **division's** `+0xEC`/`+0xF0` products together with `+0xF4`/`+0xF8` and the definition's `+0x134`/`+0x138` and `+0x11C`/`+0x120` instead. Since the `CUnit`-level products are the land model, **slot 9 true is land and slot 9 false is a ship or a wing**, which is the symmetry this section expected and could not locate. That last step is *inferred* from the field set rather than read out of slot 9's bodies, and what the `+0xF4`/`+0xF8` amphibious pair is doing in the land arm was not chased.

**Why the negative happened: trap 3.** The block lives at `0x566455`, *past* a `ret 4` at `0x566452` (slot 11's own), reached only by the `je` from inside the loop. Any search that stops at the `ret` cannot see it. The function really runs to the `int3` at `0x566477`, so its extent is **`0x187` bytes**. (**Corrected 2026-10-02**: this said `0x4A7`, which is `0x566477 - 0x565FD0` - measured from `CCombatant::ApplyLosses`, the abutting function this paragraph is otherwise about. The arithmetic outlived the trap-2 misattribution it came from. `reversing/findings/FINDINGS-slot11.md` §4, re-checked by hand.)

Per shot:
```
remaining = target->strength (+0x5C) - target->pending_strength_damage (+0xA8)
            (or - pending * 10 / 1000, the 0x1A8868C static, when the target answers slot 9 or 11)
if remaining < 0: the target is finished, stop
orgDice = NAVAL_COMBAT_ORG_DICE_SIZE / 1000 + floor(5000.5) * theENEMYsStackingPositionPenalty / 1000 / 1000
strDice = NAVAL_COMBAT_STR_DICE_SIZE / 1000 + the same term
... a hit roll against CHANCE_TO_AVOID_HIT_AT_NO_DEF, clamped at 0x182B8 (99,000) ...
if Random() % 100 < NAVAL_COMBAT_CRITICAL_HIT_DAMAGE_CHANCE / 1000:
    strDamage = strDamage * NAVAL_COMBAT_CRITICAL_HIT_DAMAGE_MUL / 1000
hull = target->+0x58->hull (+0x178)
if hull > 0: strDamage = strDamage * 1000 / hull;  orgDamage = orgDamage * 1000 / hull
strDamage = strDamage * NAVAL_COMBAT_STR_DAMAGE_MODIFIER / 1000
orgDamage = orgDamage * NAVAL_COMBAT_ORG_DAMAGE_MODIFIER / 1000
```
Three things worth having: **`hull` divides both kinds of damage**, so it is the naval armour and acts as a straight divisor, not as the land model's deflection threshold; the **enemy's** naval stacking penalty widens *both* dice (a crowded formation is easier to hit); and the critical hit is a flat `Random() % 100` against the chance define with no ship attribute in it. The hit roll between `0x5680E5` and `0x568390` is a long run of inlined MT19937 and was **not** followed instruction by instruction — the two constants are off the bytes, but whether naval has the land model's "defences_used buys a number of shots" structure is not established.

---

## 10. Air and naval attack, and what is not established

`CAirCombatant::Attack` (`0x56D750`) and `CBomberCombatant::Attack` (`0x5615C0`) were **not read** — the budget went on the census and the naval body. Slot 15 is `CLandCombatant 0x56B340`, `CNavalCombatant 0x567930`, `CAirCombatant 0x56D750`, `CBomberCombatant 0x5615C0`, base `0xB961D5` (a stub).

Not established, in the order a rebalance would care:

- **Whether `CUnit+0xC8`'s summed adjusters behave as a sum in a running game.** The code is unambiguous; the consequence — three brigades get three times one brigade's terrain modifier — is odd enough to be worth one `dumpStruct.py` against a division whose brigades' unit files are known. Everything in §5 that reads `def->` depends on it.
- **`0x174DA00`**, the mission-index-to-modifier-id table: zero in the image, needs a running game.
- **Which difficulty setting maps to which of `{0, +2000, +1000, -1000, -2000}`** in `0x4DF9B0`'s jump table at `0x4DFADC`.
- ~~**`CSubUnit+0x54`'s consumer.**~~ **Closed 2026-10-01: it has one**, at `0x56645E` in **`CCombatant` slot 11 (`0x5662F0`)**, in a cold block past that function's `ret 4` at `0x566452` (trap 3) - and **not** in `CCombatant::ApplyLosses`, which is the abutting function before it and ends at `0x5662ED` (trap 2; see §9). ~~The defence-side modifiers are live.~~ **STRUCK 2026-10-02 by
`reversing/findings/FINDINGS-slot11.md`, and replaced - this is the one real subtraction from this file.**
That sentence was earned only against the weaker claim that `+0x54` had no reader at all. It has
exactly one, and **everything that reader reaches is a display quantity**: `CSubUnit +0x54` ->
`CCombatant` slot 11's naval/air arm -> `CCombat` slot 17 -> `0x57BD70` -> the `combat_status`
billboard's frame and percentage. Slot 11 has exactly two invocations in the image, both inside
`CCombat` slot 17, established by four sweeps each with its own positive control, plus the facts
that neither slot-11 body's address appears anywhere in `.text`, that there is **no
`imul [reg+0x54]` in the image at all** (so no inlined copy), and that the subclass closure holds
only two distinct bodies. So:

**Confirmed live 2026-10-02 by a hook on slot 11** - 39,414 calls in a 1942 war save, three return addresses, all of them CCombat slot 17 or CLandCombatant's forwarder into the same body, and the unclosable vcall-thunk route never fired. **For naval, air and bombing, the defence side of this census is cosmetic in this build** -
including both defence-only ids, `BM_POOR_SCREEN_PENALTY` and the bombing target's
`BM_FORT_MODIFIER`. **A mod cannot reach the simulation through either.** The attack side is
untouched: `+0x50` multiplies the shot count in `CNavalCombatant::Attack`.

**For land it survives, and that is why this is half a subtraction.** Slot 11's land arm multiplies
`CUnit +0xEC`/`+0xF0`, and `+0xF0` has a second reader outside the combat module that is **not** a
display: the AI's land-attack-odds estimator (`0x8D93B0`) multiplies `+0xF0` by `+0xF8` at
`0x8D9825` and `0x8D9C3A`, and its result decides whether the AI commits a unit to an attack and
whether it aborts one. `likely` rather than `confirmed` - `esi`'s identity rests on the
distinctive `+0xF0`/`+0xF8` pair and `0x8D93B0`'s body is still unread.

**The bound on the negative**, because it is a negative: slot 11 can also be reached through the
vcall thunk at `0x549E00` from a runtime-filled listener table, and 1.80% of non-padding `.text`
is outside the decode. `confirmed` of what the sweeps see, `likely` of the whole image.

What remains open is narrower: **which kinds answer slot 9 true**, read out of the slot bodies rather than inferred from the field set, and what the `CUnit+0xF4`/`+0xF8` amphibious pair contributes to the land arm. See §9.
- **`0x4A6850`** (encirclement), **`0x4EF7C0`** (friendly controller), **`0x564890`**, **`0x5D6AC0`**, **`0x565F20`**, **`0x5D5B80`** — used and named by their use, bodies unread.
- **The `+0x218`/`+0x21C` map and `+0x18C`** on a naval base's `CSubUnitDefinition`, which decide how much landing-craft technology cancels `BM_AMPH_PENALTY`.
- **`CSubUnit+0xB8/+0xBC`**, and whether `CSubUnit+0x94/+0x98` is the owner or the controller.
- **Whether the naval hit roll has the land model's defence-slot structure.**
- What the land `surprise_chance` trait read at `0x56A330` feeds, given `BM_SURPRISE_PENALTY` is dead. `BM_ARMOR_ADVANTAGE` poses the same question with a narrower starting point: its flag byte is set at `0x56AD8D`, so whatever reads that byte is the consumer to find.

### Five corrections to `FINDINGS-combat.md`, collected
1. "21 call sites" → 69, across two adders.
2. "nine ids have no call site" / "the modifier list is land only" → 7 of the 9 go through the sub-unit adder; **only `BM_SURPRISE_PENALTY` (0x1C) is dead**, and `BM_ARMOR_ADVANTAGE` (0x13) is computed and flagged at `0x56AD8D` but never added as a modifier.
3. `CUnit::ResetCombatModifiers`' caller is the **base** slot 19, which all five kinds run — so a ship's/wing's parent `CUnit+0xDC` *is* cleared every tick, and the live `+0xE4` watchpoint was on the wrong object.
4. `0x1A8868C` is a **VA**, not an rva (rva `0x168868C`), and it is the `(int)floor(10.5f)` = 10 clamp floor.
5. `CNavalCombatant::Attack`'s positioning arithmetic is its **head**, not its tail, and positioning is consumed by `CNavalCombatant::PickTarget`, not by the damage path.

Confidence: §1, §2, §3, §5–§8 and the §9 set-up are **confirmed** against the bytes (and the trait-kind enum and the flag array each have 8+ and 24 independent agreements respectively). The `CUnit+0xC8` sum consequence, the names I coined for `0x5CD960`, `0x4A9BE0` and the `CTechnologyStatus` fields, and the naval shot-resolution middle are **likely** — read, but not cross-checked twice or against a game.
