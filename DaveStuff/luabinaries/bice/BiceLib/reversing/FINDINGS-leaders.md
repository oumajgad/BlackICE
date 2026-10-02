# Leaders: experience, skill, traits, promotion

Static reading of `hoi3_tfh.exe` (image base `0x400000`). **Every address is given as
`rva (VA)`.** Nothing here needed the game running.

This builds on what `BiceLib/GameClasses/CLeader.hpp`, `CTrait.hpp` and
`Hooks/CLeaderHooks.cpp` already assume. Where it contradicts them, it says so.

---

## The verdict first: there is no skill loss on promotion

**`CPromoteLeaderCommand::Execute` (`0x1D7C70`, VA `0x5D7C70`, slot 6) does not touch
`skill`.** Its whole body:

```
0x5D7C92  eax = this->+0x40 ; ecx = this->+0x44        the leader's object-id pair
0x5D7CBE  edi = resolveObjectId(&pair)                 0xA9DA00
0x5D7CC9  this->+0x3c = edi                            the resolved CLeader*
0x5D7CCC  eax = leader->+0x6c                          rank
0x5D7CCF  if (this->+0x64 == 0)  eax += this->+0x68
          else                   eax -= this->+0x68
0x5D7CDC  leader->+0x6c = eax                          <-- the only write to the leader
0x5D7CDF  if (leader->+0x68 != 0) return               land leaders only (type)
0x5D7CE8  if (leader->+0x40 == 0) return               only if he commands a unit
0x5D7CF1  ... CCurrentGameState; if the unit's country is the player's, poke the
          interface (0x739BC0)
0x5D7D9A  SetLeader(leader->unit, CLeader::null(), 0, 0)    0x1BFC10 with 0x17F510
0x5D7DBD  ret
```

`0x5D7CDC` is exactly where BiceLib's `Hook_LeaderRankChange` sits (`project.json` already
records that instruction). There is **no read of `+0x70` (skill), `+0x74` (max_skill) or
`+0x78` (current_experience)** and no resource deduction anywhere in the function.

**It is not only this function.** A robust linear sweep of the whole `.text` (skipping
undecodable bytes - the naive sweep stops at about `0x45E8CB` and silently truncates, which
is worth knowing before trusting any scan in this folder) finds **no `dec`, `sub`, `neg`,
`shr`, `sar` or `imul` against any `[reg + 0x70]`** outside the MSVC runtime's iostream flag
code (`and [reg+0x70], 0xFFFFFFFD`, 100+ sites, all above `0xB96000`). Every write to
`CLeader +0x70` in the image is:

| rva (VA) | what writes it | value |
|---|---|---|
| `0x17F695` (`0x57F695`) | the `CLeader` constructor | 0 |
| `0x17FA04` (`0x57FA04`) | `CLeader::LoadKey`, the `skill` key | the file's value |
| `0x180046`/`0x18004D` (`0x580046`) | `CLeader::PostLoad` (`0x17FF60`) | the skill the experience has earned - **never below the loaded one** |
| `0x181DF0`/`0x181DF7` (`0x581DF0`) | `CLeader::AddExperience` | `skill + 1` |
| `0x181E26` (`0x581E26`) | `CLeader::ResetToStarting` | `starting_skill` (`+0xC8`) |
| `0x1D6D0D` (`0x5D6D0D`) | a runtime-created leader | `1` |
| `0x1D71AB` (`0x5D71AB`) | a leader-to-leader field copy (`+0x68`..`+0x80`) | the source's skill |

**So `activateLeaderPromotionSkillLoss` should stay disabled as a reproduction of an engine
mechanic, because there is no engine mechanic to reproduce - this build has none.** The
mod's own memory ("the mechanic is from a predecessor game") is right. If David wants the
behaviour it has to be the mod's own invention, which is what `CLeaderHooks.cpp` already
implements, and nothing in the executable will fight it.

### What promotion does cost

Nothing, in resources. `CPromoteLeaderCommand::IsValid` (**slot 14**, `0x1D8060`, VA
`0x5D8060`) is the only gate:

```
leader = resolveObjectId(this->+0x40, this->+0x44); this->+0x3c = leader
if (!leader) return false
if (!leader->vslot8()) return false                   not the null leader
newRank = leader->rank  +/- this->+0x68   (sign from this->+0x64)
return (unsigned)(newRank - 1) <= 3                   i.e. newRank in 1..4
```

No leadership, no officer ratio, no money, no dissent. The only constraint is that the
resulting rank stays in **1..4**; rank 0 is what the constructor leaves and what the daily
pass replaces, so it is not reachable through this command.

The real effect beyond the rank number is at `0x1D7D9A`: **a land leader who commands a unit
is taken off that unit** (his unit's leader becomes the shared empty `CLeader`). Sea and air
leaders, and land leaders with no command, keep everything.

### The command's own fields

`CPromoteLeaderCommand` is `0x6C` bytes (slot 13, `0x1D7F70`, allocates `0x6C` to clone
itself).

| offset | meaning | evidence |
|---|---|---|
| `+0x3c` | the resolved `CLeader*` | written by `Execute` and `IsValid`; `LoadKey` reads `leader` into it |
| `+0x40`, `+0x44` | the leader's object-id pair, `+0x40` first (it is the one compared against `0x1268` to pick the id pool) | `0x5D7C92`, `0x5D8070` |
| `+0x64` | direction: **0 adds, non-zero subtracts** | `0x5D7CCF`, `0x5D80BD`; already in `project.json` as `direction` |
| `+0x68` | the rank delta. The default constructor (`0x1D7AC0`) writes `+0x64 = 0` at `0x5D7BA0` and `+0x68 = 1` at `0x5D7BA3`; the parameterised constructor (`0x1D7BC0`) takes both from its arguments (`0x5D7C4D`, `0x5D7C53`) | |

`CLeaderHooks.cpp`'s `// 0 = Higher Rank ; 1 = Lower Rank` is consistent with the code as
long as "higher rank" means a **larger** `rank` number.

---

## 1. Experience: where it comes from, and the whole chain

### The only source is combat

`CLeader::AddExperience` (`0x181CE0`, already named) is called from **exactly two sites**,
both inside one function: `0x1C46E7` and `0x1C4776`, in
**`GrantCombatExperience` (`0x1C4200`, VA `0x5C4200`)**,
`void __stdcall (CUnit* unit, bool convoyRaid)`, `ret 8`.

That function has two callers:

| call site | arg2 | context |
|---|---|---|
| `0x1BA555` (VA `0x5BA555`) | `0` | inside the large unit routine entered at `0x1B9C50`; guarded by `unit->+0x11C > 0` or `unit->+0x110 != 0` - the unit is in, or has just been in, a combat |
| `0x1D243C` (VA `0x5D243C`) | `1` | inside `0x1D2330`, the convoy path; `arg2` selects `EXP_GAIN_CONVOY_MODIFIER` |

**Nothing else in the image gives a leader experience.** No daily pass, no exercise, no
theatre, no leadership spending. A leader who never fights never gains a point.

### The amount, read off `0x1C4200`

Fixed point is the game's 48.15 (32768 == 1.0). Two idioms recur: `(x << 30) / 0x1F40000`
converts a thousandths int into 48.15 (`0x1F40000` is `1000 << 15`), and `allmul`
(`0xB99AF0`) / `alldiv` (`0xB99980`) are the 64-bit helpers.

```
K = (int64)328.18                      ; the double at rva 0x120A7B8 (VA 0x160A7B8).
                                       ; 327.68 + 0.5, truncating to 328 = 0.01 in 48.15 -
                                       ; the same +0.5 trick as RANK_FACTOR's 32768.5
A = 0
-- for each CCombat in unit->combats (+0x114):
     pick the side the unit's country is NOT on
     A += weightedAverage(thatSide) * totalOf(u->+0x40 over thatSide)   ; 0x1D6710, 0x1D6670
-- if unit->+0x110 (its current combat) and the unit is NOT land (vslot 15 false):
     the same against that combat's attacker side
A *= K                                 ; 0x5C43F0
if (A == 0) return
A /= 4                                 ; alldiv by 0x20000
A = clamp(A, 0, 6.0)                   ; 0x60000
v = (rand() % 6 + 1) + A / 3           ; 0xAA2F80, alldiv by 0x18000
v *= EXP_GAIN_LAND | EXP_GAIN_NAVAL | EXP_GAIN_AIR      ; vslot 15 / 16 / 17 pick which
v *= 1 + CUnit::GetTraitEffect(0) / 1000               ; effect 0 == xp_gain
if (convoyRaid) v *= EXP_GAIN_CONVOY_MODIFIER
v *= K                                 ; 0x5C45FE - the SECOND 0.01
```

Two things worth saying plainly:

- **The die dominates.** `A` (the enemy's size) is clamped to 6 and then divided by 3, so it
  contributes at most `2` against a `1..6` roll. A huge battle is worth at most about twice
  a tiny one, and the roll matters more than the enemy.
- **`K` is applied twice**, at `0x5C43F0` and again at `0x5C45FE`. Both sites are
  unambiguous. I have not found a reason and am not calling it a bug.

Then the split, which `defines.lua`'s own comments (`--was 0.55 unit/25 leader`) already
name:

```
regimentGain = v * 1000 * EXP_GAIN_DIV              ; 0x5C4613..0x5C4646, thousandths
for each regiment in unit->regiments (+0x38):
    if (vslot10(regiment) && regiment->+0xC0 == 0) skip
    regiment->+0x3C += regimentGain, capped at 0x186A0 (100000 == 100%)

leaderGain = v * EXP_GAIN_LEADER                    ; military +0x64, 0x5C4688
if (unit->leader is real)  AddExperience(unit->leader, leaderGain)

hq = unit->+0x1E0
while (hq) {
    if (vslot15(hq) != vslot15(unit)) break         ; same domain only
    n = clamp(hq->+0x1EC, 2, 5)                     ; +0x1EC is the COUNT of `children`,
                                                    ; the CList at +0x1E4
    leaderGain /= n
    if (hq->leader is real) AddExperience(hq->leader, leaderGain)
    hq = hq->+0x1E0
}
```

**The HQ chain earns too**, each level dividing by its own child count clamped to 2..5,
compounding upwards. BlackICE's `EXP_GAIN_LEADER = 50.0` against `EXP_GAIN_DIV = 1.65` makes
the leader's share about 30x the division's, before the HQ division.

Defines read, from `definesMap.py`'s `military` block (`CDefines +0xAC`):
`EXP_GAIN_LAND +0x50`, `EXP_GAIN_NAVAL +0x54`, `EXP_GAIN_CONVOY_MODIFIER +0x58`,
`EXP_GAIN_AIR +0x5C`, `EXP_GAIN_DIV +0x60`, `EXP_GAIN_LEADER +0x64`.

### Experience into skill

`AddExperience` (`0x181CE0`) is `void __stdcall (CLeader* leader@ESI, long long amount)`,
`ret 8` - **one 64-bit argument**, pushed by the caller as `sub esp, 8` then two stores
(`0x5C46D7`-`0x5C46E1`), not two ints.

```
if (leader->skill >= 12) return                       ; never fires - see below
f = 1 + (max_skill - skill)^2 / 5                     ; alldiv by 0x28000 (5<<15), then +0x8000
if (skill >= max_skill) f /= 3                        ; alldiv by 0x18000 (3<<15)
f *= RANK_FACTOR[rank]                                ; all five slots are 1.0
current_experience (+0x78, 64-bit) += f * amount
if (current_experience >= (SKILL_THRESHOLDS[skill] << 15))  skill = skill + 1
```

`RANK_FACTOR` and `SKILL_THRESHOLDS` are already fully documented in `CLeader.hpp` and
`CLASSES.md`. I re-derived both and confirm them, including that the `skill >= 12` guard
never fires because `SKILL_THRESHOLDS[10] == 100000000` is unreachable.

**The cap is the table, and `max_skill` is not a cap at all.** `max_skill` only sets the
learning speed: far below it a leader learns up to `1 + 25/5 == 6x` faster, and **at or past
it** he learns at a third of the rate. `skill` can and does pass `max_skill` - which is
exactly why `activateLeaderListShowMaxSkill` is useful, and consistent with the 1117 live
leaders `CLeader.hpp` records above their starting skill.

### Skill on load: `CLeader::PostLoad` (`0x17FF60`, VA `0x57FF60`, slot 5)

New. `CLeader`'s slot 5, and it runs after `LoadKey`:

```
if (this->+0xC4 == 0) { this->+0xC4 = new CTraitGainTracker(0x24); Init(tracker, this); }
prev = SKILL_THRESHOLDS[skill - 1]          ; [esi*4 + 0x170AEE0]; the dword at rva
                                            ; 0x130AEE0 is 0, so skill 0 reads 0 - by design
if (current_experience < (prev << 15))  current_experience = prev << 15
if (skill >= 12) return
if (current_experience == 0)
    current_experience = (starting_experience << 30) / 0x1F40000    ; +0xCC, whole points
s = skill
while (s < 12 && current_experience >= (SKILL_THRESHOLDS[s] << 15))  s++
skill = s                                   ; clamped at >= 0
```

Two consequences for the mod:

- **The save's `skill` is a floor, not the value.** Load raises `current_experience` to the
  threshold the saved `skill` implies, then raises `skill` to whatever the experience has
  actually earned. It never lowers either.
- **Every leader gets a `CTraitGainTracker` on load** even if the save had none, and the
  tracker is pre-populated (below).

### The interface figures

`CLeader::GetExperiencePercent` (`0x181C50`, already named, already called by
`CLeaderHooks.cpp`) is the progress bar:

```
if (skill >= 12) { *out = 0; return; }
prev = SKILL_THRESHOLDS[skill - 1]   ; 0 for skill 0
cur  = SKILL_THRESHOLDS[skill]
*out = (current_experience - (prev<<15)) * 1000 / ((cur<<15) - (prev<<15))
```

so `1000 == 100%`, exactly as `CLeaderHooks.cpp` assumes.

`skill` is `+0x70`, `max_skill` is `+0x74`, and the two UI sites BiceLib patches
(`0x365688`, `0x3679D4`) print only `+0x70`. `max_skill` is written in four places only:
the constructor (0), `LoadKey`'s `max_skill` key (`0x17FBB2`), a runtime-created leader
(`0x1D6D14`, **hard-coded `5`**, beside `skill = 1`, `loyalty = 1000` and the name
`Mr Generic`), and the field-copy block at `0x1D71B1`. **Nothing changes `max_skill` during
play** - it is whatever the history file said, for the life of the game.

---

## 2. Traits

### How a trait's effects reach a unit or a combat

**`CUnit::GetTraitEffect` (`0x1D1120`, VA `0x5D1120`)**,
`int* __thiscall (CUnit* this, int* out, int effectKind)`, `ret 8`, returns `out` in `eax`.
`CLASSES.md` line 477 already has the row; this is the body:

```
*out = 0
hq = this->+0x1E0
if (hq) {
    hqValue = GetTraitEffect(hq, &tmp, effectKind)          ; recursive, 0x5D114E
    if (hqValue) {
        f = radioProximityFactor(this, &tmp2, hq)            ; 0x5B67B0
        *out += max(f, 0) * hqValue / 1000 / 2               ; the /2 is alldiv by 0x7D0
    }
}
if (this->leader is real)
    for each CTrait* t in leader->traits (+0x30)
        for i in 0 .. t->+0x2A8 - 1                          ; effect_count
            if (t->+0xA8 + i*4 == effectKind)                ; effect_kinds
                *out += t->+0x68 + i*4                       ; effect_values, thousandths
```

So a trait's effects reach the game **through the three parallel arrays `CTrait.hpp` already
documents**, at the offsets it already records. `0x1D1120` has **63 call sites**, which is
how the 31 `Effect` kinds reach combat, movement and supply; `FINDINGS-combat.md`'s
`CUnit::AddCombatModifier` family is a subset of those callers, and `0x1C457E` inside
`GrantCombatExperience` is the `xp_gain` one.

**The HQ chain contributes at half strength times a proximity factor, recursively**, so a
theatre commander's traits reach a division through every HQ between them, halved at each
step.

### What makes a leader gain a trait

Three routes; only one is a mechanic.

1. **The history file / the save.** `CLeader::LoadKey` calls `CLeader::AddTrait`
   (`0x181A60`) from `0x17FB32` and `0x17FD2D` - the `trait` and `add_trait` keys.
2. **Script.** `CAddTraitEntry` slot 7 = `0x1FC9C0` (VA `0x5FC9C0`),
   `void __thiscall (this, bool set)`, `ret 4`, with the `CLeader*` at `this->+0xC` and the
   `CTrait*` at `this->+0x10`: `set` true adds, `set` false removes it from the leader's
   list. `CRemoveTraitEntry` slot 7 (`0x1FCA80`) is the mirror image and calls `AddTrait` on
   its undo branch (`0x1FCABF`).
3. **The gainable-trait mechanic**, below.

### The gainable-trait mechanic, end to end

Every piece `CTrait.hpp` names is confirmed; the loop that drives them is new.

**(a) The database.** `0x73930` (VA `0x473930`, bare `ret`, no arguments) is a lazily built
singleton of `0x30` bytes cached in the global at **VA `0x1A8556C` (rva `0x168556C`)** and
built by `0x739A0`. It holds two nested `std::map`s. The lookup is `0x73F30`
(VA `0x473F30`), `ret 8`, with **the database in `edi`** - it is called immediately after
`0x473930` and reuses that return value *and the caller's two surviving pushes*, an unusual
but real convention:

```
key1 = the CCombat's own save token          vslot 10 on combatant->+0x3c
key2 = the leader's type                     CLeader +0x68
-> a std::vector<CGainableTrait*>
```

`key1` is confirmed against the classes that produce it, each in **exactly one** vftable slot
(checked, per trap 4 - count the holders before naming a slot body):

| class | slot 10 | value | `gainable_traits.txt` name |
|---|---|---|---|
| `CLandCombat` | `0x17B6D0` | `0x2D3` = 723 | `land_combat` |
| `CNavalCombat` | `0x17B840` | `0x2D4` = 724 | `naval_combat` |
| `CAirCombat` | `0x17BC90` | `0x520` = 1312 | `air_combat` |
| `CGroundBombing` | `0x163E50` | `0x523` = 1315 | `ground_bombing` |
| `CLandBombing` | `0x163F20` | `0x524` = 1316 | `land_bombing` |
| `CNavalBombing` | `0x163FF0` | `0x525` = 1317 | `naval_bombing` |

Those are exactly the six numbers `CGainableTrait.hpp` lists, now tied to the classes that
emit them.

**(b) The tracker is per leader and pre-filled.**
`CTraitGainTracker::Init` (`0x741C0`, VA `0x4741C0`),
`void __stdcall (CTraitGainTracker* tracker, CLeader* leader@EAX)`, `ret 4`:

```
if (tracker->+0x18 != 0) return
tracker->+0x18 = leader                                      ; <-- the owning CLeader*
for each vector in database[leader->type]                     ; the second map, db+0x20/+0x24
    for each CGainableTrait* g in it
        tracker->map[g->trait] = 0
```

**`CTraitGainTracker +0x18` is the owning `CLeader*`** - confirmed twice, here and at
`0x4745D1` where it is the first argument to `AddTrait`. The tracker is reached from the
leader as **`CLeader +0xC4`**, which is the same four bytes as `CLeaderHistory +0x40` that
`CTraitGainTracker.hpp` already records (`0x84 + 0x40 == 0xC4`). Callers of `Init`:
`0x17F4C3`, `0x17FFC2` (`PostLoad`) and `0x1D6DC2` (leader creation).

Because the map is pre-filled with a zero for every trait the leader's type could earn, the
tooltip has to filter: `CTraitGainTracker::BuildProgressTooltip` (`0x74240`, VA `0x474240`),
`Hoi3CString* __stdcall (tracker, Hoi3CString* out)`, `ret 8`, skips any entry that is `<= 0`
or `>= 0x186A0` and formats the rest through `TRAIT_GAIN_PROGRESS` with `$TRAIT$`/`$PROG$`.

**(c) Hours accumulate on the combat tick.**
**`AccumulateLeaderCombatHours` (`0x164890`, VA `0x564890`)**,
`void __stdcall (CList<CUnit*>* units)`, `ret 4`, called from **seven** sites in the combat
module (`0x1615D0`, `0x1630EA`, `0x16321D`, `0x1637FD`, `0x16795E`, `0x16B36A`, `0x16D777`),
each passing `&combatant->units` (`+0x40`):

```
for each CUnit* u in *units:
    if (!u->leader->vslot8()) continue
    t = u->leader->+0xC4                                     ; the tracker
    h = (CCurrentGameState->tick(+0xBDC) - 0x29C55C0) % 24    ; 0x564965..0x564970
    if (h != t->current(+0x20)) { t->duration(+0x1C)++; t->current = h; }
```

So **`duration` is a count of distinct game hours**, and the `% 24` guard means the routine
can be called as often as the tick likes without double counting. It also means
`CCurrentGameState +0xBDC` (`project.json`'s `tick`) is counted in **hours**.

**(d) Progress is credited in bursts, not continuously.**
**`CTraitGainTracker::Update` (`0x74430`, VA `0x474430`)**,
`void __stdcall (CTraitGainTracker* tracker, CCombatant* side)`, `ret 8`.

Note: `0x474430` is **abutting** - `0x47442D` is the tooltip's `ret 8` and `0x474430` is a
fresh prologue with **no `int3` padding between them**, so an int3-based function scan
mis-attributes this call site to `0x74240`. That is trap 2 again.

```
if (tracker->map.size(+0x10) == 0) { tracker->duration = 0; return; }
if (tracker->duration == 0) return                            ; nothing banked, nothing to do
for each CGainableTrait* g in database[side->combat's token][leader->type]:
    if (leader already holds g->trait) continue               ; walks leader->traits (+0x30)
    node = tracker->map[g->trait]
    if (node->value >= 100000) continue                       ; already complete
    if (g->has_trigger(+0x54) && !g->trigger(+0x14).Evaluate(scope of side, leader)) continue
    if (g->hours_required(+0xC) <= 0)  step = 100000
    else                               step = 100000 * (duration * 1000 / hours_required) / 1000
    node->value += step
    if (node->value >= 100000) { node->value = 100000; AddTrait(leader, g->trait); }
tracker->duration = 0
```

`100000` is the completion mark; `(int)100000.5` comes from the float at rva `0x120A718`
(the same `+0.5` truncation trick again). **So the value in `hours_by_trait` is progress on
a 0..100000 scale, not hours** - which is what lets the tooltip divide by 1000 and print
`100.00`.

**(e) When `Update` runs.** Only two callers, and neither is a tick:

- **`CCombatant::RemoveUnit` (`0x165310`, VA `0x565310`) - `CCombatant` slot 13**, shared by
  all seven combatant classes. It flushes every unit's leader first (`0x565348`), then
  erases the unit from `+0x40` and rebuilds the side's country list at `+0x54`.
- **`CCombatant::DetachAllUnits` (`0x165CC0`, VA `0x565CC0`)**, `ret 4`, called twice from
  the `CCombat` method at `0x17AB00` (once per side). It flushes each leader (`0x565CFC`),
  clears `unit->+0x110`, removes the combat from `unit->combats (+0x114)`, and finally
  empties the side's unit list.

**The practical consequence for the mod:** banked hours only become trait progress when the
unit leaves the battle or the battle ends. A single unbroken year-long battle credits
nothing until it finishes. And **`CUnit::SetLeader` (`0x1BFC10`) zeroes the incoming leader's
`duration` and sets `current = -1`** (`0x1BFCCF`-`0x1BFCDC`), so swapping a leader mid-battle
throws his banked hours away.

`CTraitGainTracker::Reset` (`0x74140`, VA `0x474140`), tracker in **`edi`**, bare `ret`,
zeroes every map entry and sets `duration = 0`, `current = -1`. Its only caller is
`0x181E7B`, inside `CLeader::ResetToStarting`.

### `allowed_leader` is a warning, not a rule

`CLeader::AddTrait` (`0x181A60`, `void __stdcall (CLeader*, CTrait*)`, `ret 8`) opens with

```
0x581A85  eax = leader->+0x68                       type
0x581A8C  cmp byte [trait + eax + 0x2B0], 0         allowed_land / allowed_sea / allowed_air
0x581A95  jne 0x581BDE                              allowed -> go add it
          ... build "Assigning <trait> trait to leader that should not get it
              (leader name=<name>)" and log it (leader.cpp:10) ...
0x581BCE  esi = [ebp+0xC]                           reload the trait
0x581BDE  ... and add it anyway
```

The disallowed path **falls through into the add** (the strings are at rva `0x1C5210`
`'Assigning '` and `0x1C51D8` `' trait to leader that should not get it (leader name='`). So
`CTrait.hpp`'s `allowed_land`/`allowed_sea`/`allowed_air` only produce a log line here. They
*are* enforced earlier, as the second map key of the gainable-trait database, so the gainable
route respects them and the `trait` / `add_trait` / script routes do not.

`AddTrait` also does no duplicate check of its own - the `Update` loop does that for the
gainable route, and nothing does it for the other two.

---

## 3. Leaders on the tick

| when | where | what it does |
|---|---|---|
| every combat tick | `AccumulateLeaderCombatHours` (`0x164890`), 7 sites | `tracker->duration++`, once per game hour per leader in the fight |
| a unit leaves a side | `CCombatant::RemoveUnit` (`0x165310`, slot 13) | `CTraitGainTracker::Update` for every leader on that side |
| a combat ends | `CCombatant::DetachAllUnits` (`0x165CC0`) from `0x17AB00` | the same, both sides |
| a unit's own routine, when it is in a combat | `GrantCombatExperience` (`0x1C4200`) from `0x1BA555` | regiment experience + `AddExperience` for the unit's leader and every HQ above it |
| the convoy path | `GrantCombatExperience` from `0x1D243C`, `convoyRaid = 1` | the same, scaled by `EXP_GAIN_CONVOY_MODIFIER` |
| the country's daily pass | `0xDAA51`..`0xDAB2A` inside `RunCountryDailyPass` (`0xDA530`) | **leader activation only** |

### The leader part of the daily pass

`RunCountryDailyPass` touches `CCountry +0xE10` (`leaders`) at exactly **one** instruction,
`0xDAA51` (VA `0x4DAA51`), and the block runs to `0xDAB2A`:

```
today = CCurrentGameState->tick (+0xBDC)                      ; read once at 0xDA5CD
for each CLeader* l in country->leaders (+0xE10):
    due = *(rva 0x130C2B8)                                    ; a global date
    for each entry in l->+0x90 (CLeaderHistory +0xC):
        if (entry->vslot6() == 0x10A)                         ; 0x10A is the `rank` save token
            { due = entry->+8; break }                        ; that entry's date
    if (today != due) continue
    if (l is already in country->active_leaders (+0xE00)) continue   ; matched on the id pair
    l->rank (+0x6C) = 1
    append l to active_leaders
```

**It gives no experience and changes no skill.** Its whole job is to move a leader from
`rank 0` (what the constructor leaves) to `rank 1` and put him in `active_leaders` on the day
his history says so. That the `rank` save token is `0x10A` comes from `fieldmap.py` on
`CLeader::LoadKey`; that `entry->+8` is the entry's date is **inference** from the equality
test against `tick`.

---

## Corrections to the existing record

1. **`CTraitGainTracker.hpp` calls the map "trait to hours".** It holds **progress on a
   0..100000 scale**. The hours live in `duration` (`+0x1C`) and are consumed and zeroed by
   `Update`; the tooltip divides the map value by 1000 and prints two decimals, so 100000
   reads as `100.00`.
2. **`project.json`'s `CLeader::AddExperience` signature**
   (`void __stdcall AddExperience(CLeader* leader@ESI, int factor@stack:4, int amount@stack:8)`)
   describes two ints where the caller pushes **one `long long`**: `0x5C46D7`-`0x5C46E1` is
   `sub esp, 8; mov [eax], esi; mov [eax+4], ebx`, and `AddExperience` multiplies
   `([ebp+8], [ebp+0xC])` as a 64-bit pair at `0x581DAC`-`0x581DBD`. The rva and the `@ESI`
   convention are right; only the argument list misleads. **Not changed** - flagged here per
   the rules.
3. **`CTrait.hpp`'s `allowed_land`/`allowed_sea`/`allowed_air`** read as a restriction on
   `AddTrait`. In `AddTrait` they are a log line only; the trait is added regardless.
4. **`CTrait.hpp`'s open question** - whether a trait's effects reach the `CModifier` base's
   value array - is still open, but the consumer that matters (`CUnit::GetTraitEffect`,
   `0x1D1120`, 63 call sites) reads the three parallel arrays directly, so nothing is blocked
   on it.
5. Nothing in `CLeader.hpp` or `CLASSES.md` about experience, `RANK_FACTOR`,
   `SKILL_THRESHOLDS`, `starting_skill` or `ResetToStarting` contradicts what I read. I
   re-derived all of it and it holds.

---

## What is not established

- **The two inputs to `A` in `GrantCombatExperience`.** `0x1D6710` (VA `0x5D6710`) walks a
  combatant's unit list computing `sum(u->+0x40 * vslot20(u)) / totalOf(u->+0x40)` - a
  weighted average of *something* - and `0x1D6670` sums `u->+0x40` over the same list.
  `CUnit +0x40` is very likely a brigade count (it is the weight) and `vslot20` very likely a
  strength or experience getter, but **I did not read `vslot20`**, so "the enemy's size" above
  describes the shape, not the units. The clamp to 6 and the `/3` cap this term at `2`
  against a `1..6` die whatever it measures, which is why I stopped.
- **Why `K` (`0.01`) is applied twice.** Both sites are unambiguous; the reason is not.
- **`CRegiment` slot 10 and `CRegiment +0xC0`**, the pair that can deny a regiment its
  experience at `0x5C4661`-`0x5C466C`.
- **The global at rva `0x130C2B8`**, the fallback activation date in the daily pass. 234
  references across the image; I did not identify it and am not guessing "campaign start".
- **`CUnit::SetLeader` (`0x1BFC10`)'s argument list.** The unit is in `ecx` and the new leader
  is `[ebp+8]`; the call at `0x1D7D9F` pushes two extra zeros first, which suggests three
  stack arguments, but I did not read its `ret`, so it is not in the JSON fragment.
- **The `CCombat` method at `0x17AB00`** that ends a combat (sets `this->+0x2A = 1`, calls
  slot 10 on both combatants, then `DetachAllUnits` on each). Left unnamed on purpose.
- **`0x17F4C3`**, the third caller of `CTraitGainTracker::Init`; it sits in the function just
  before `CLeader::null` and I did not identify it.
- **Whether `rank` does anything else at all.** `RANK_FACTOR`'s five identical slots make it
  irrelevant to learning speed, and I found no other read of `CLeader +0x6C` in the experience
  or combat paths. `AIR_RANK_1..4` / `NAVAL_RANK_1..4` (`military +0x1F0`..`+0x20C`) exist and
  I did not chase where they are read.
- **Nothing here was read live.** The game was not running; every figure comes out of the
  executable. Live readings quoted from `CLeader.hpp` are the mod's own, not mine.
