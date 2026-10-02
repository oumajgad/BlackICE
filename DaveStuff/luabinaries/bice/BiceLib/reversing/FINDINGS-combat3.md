# Closing out the combat-modifier census: what the leftovers feed

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is
marked *seen*. Addresses are **virtual** (image base `0x400000`) with the rva beside them wherever
a finding depends on it. The seven questions came from `FINDINGS-combatmods.md`'s *Not established*
list and `FINDINGS-negatives.md` §4's open items. Scripts are in `scratchpad/combat3/`.

## In one line

Land surprise is a feature that was taken out and left its scaffolding behind — the `surprise_chance`
trait has exactly one read in the whole image and its answer is discarded, and `SURPRISE_BONUS` in
`defines.lua` has no reader at all; `BM_ARMOR_ADVANTAGE`'s flag byte **is** read, by a script trigger
and only by a script trigger, while the armour mechanic the tooltip describes is implemented
independently in `CLandCombatant::FireUnit`; `CCombatant` slot 11 is live after all and its consumer
is the combat-status window's odds readout, reached through a `CCombat` slot that nothing else calls;
the discarded slot-10 call in slot 11's cold block is two identical arms folded together, provable
because the same predicate's answer is tested five times a hundred bytes away; the two "defines" at
`CLASSES.md:453` are not defines but `.CRT$XCU` statics, and one of them is a global the record
already holds twice under two different stories; `CUnit +0xDC` on a ship is confirmed exactly as
stated; and `CSubUnit` slot 9 is independently confirmed, along with the discovery that the
`CCombatant` family carries the *same* predicate pattern at slots 6/7/8/9, which explains three
unexplained slot calls in the modifier code.

---

## 0. Method, and the three false zeroes it produced before it worked

Everything below rests on one entry list and two scans over it, and both scans produced a wrong
negative first. Recording how is the point of this section.

**The entry list.** `scratchpad/combat3/entries2.py` unions three sources and tags each entry with
its provenance: `V` a slot of a vftable in the RTTI export (read as `vftable + slot*4` out of the
image, not from the export's `introduces` list — trap 10), `P` the first byte after a run of **two**
`int3`, `p` the first byte after a **single** `0xCC`, and `C` the target of a `call rel32` decoded
from a `V` or `P` entry. 37,624 candidates, **28,430 strong** (`V`, `P` or `C`). Attribution takes
the nearest strong entry at or below an address.

*Why not `image.functionStart`.* It answers `0x565FD0` for `0x56645E`, which is wrong by two
functions, and trap 2's second half (added today) says it also walks past any function whose first
byte is outside its prologue set. The entry list is immune to both, because a vftable slot and a
validated `call` target each name the second function of an abutting pair for free. The control: it
attributes `0x56645E` (rva `0x16645E`) to `0x5662F0` (rva `0x1662F0`) and `0x56AD8D` (rva `0x16AD8D`)
to `0x569B50` (rva `0x169B50`), both of which the record arrived at another way.

*Its own limitation, which cost duplicate rows.* A body is decoded forward to the first run of **two**
`int3`, so where two functions abut with none (`0x565FD0`/`0x5662F0`) or with **one**
(`0x5D0F80` ends `ret 0xC` at `0x5D111C`, one `int3` at `0x5D111F`, `0x5D1120` begins) the decode
over-reaches into the next function and the same instruction is reported under two owners. That is
the safe direction for a negative and it is why some rows below appear twice. `0x5D0F80`/`0x5D1120`
is *not* a new trap 2 pair: `functionStart(0x5D114E)` answers `0x5D1120` correctly.

*The `p` source is a real false-positive generator.* `8b cc` is `mov ecx, esp`, so its `cc` byte makes
the following byte look like a post-padding entry. `0x56AD11` is one, and a first version of the list
that trusted it attributed `0x56AD8D` to `0x56AD11` instead of to `0x569B50`. Only `V`, `P` and `C`
entries are used for attribution.

**The three false zeroes.**

1. `fieldchain.py --holder` **does not run at all.** `main()` calls
   `chained(args.holder, displacement, args.window)` with `args.window` an int, and inside `chained`
   that parameter shadows the module-level `window()` helper, so `for back in window(starts)` raises
   `TypeError: 'int' object is not callable`. Every `--holder` invocation fails. The fix is one line
   (call the helper by a non-shadowed name); `scratchpad/combat3/chain.py` is a copy with it applied.
2. Once it ran, its default span of `WINDOW = 0x40` bytes reported **zero** readers of
   `LAND_COMBAT_STR_ARMOR_ON_SOFT_DICE_SIZE`. The real reader is `0x56B067` (rva `0x16B067`), `0x53`
   bytes past the block load at `0x56B014`. At `--span 0x100` it appears. **A define-reader scan with
   a window needs its window stated, and `0x40` is too small for this code.**
3. "The instruction after the call dereferences `eax`" is a good test for a live `GetTraitEffect` and
   a **bad** one in general: 64 of the image's 72 sites pass it, and of the 8 that fail, four are
   recursive self-calls inside `0x5D0F80`/`0x5D1120` and three are genuine uses through a stack slot
   (`0x5C457E`, `0x5B62FF` in `CUnit::GetCombinedArmsBonus`, `0x566FE7`). Applying the same test to
   `CCombatant` slot 11's callers **missed the only two that exist** (§3). It was caught by widening to
   "an out-pointer was pushed" and reading the survivors.

**The complete-enumeration scan** that replaces the windowed one is
`scratchpad/combat3/definereaders.py`: for a block offset `B` and an entry offset `D`, find every
decoded body that uses `[reg + D]` and report whether that same body anywhere loads `[reg + B]` and
whether it obtains the `CDefines` singleton (`call 0x445D90`, or the inlined `[0x1A86040]` form). A
body that uses `+D` but never gets the singleton is not a reader of that define however it is
written, which closes trap 8 cases 1 and 2 together.

---

## 1. Land surprise: the trait is read once in the image and the answer is thrown away

`FINDINGS-combatmods.md` records that land combat reads the `surprise_chance` trait at `0x56A330`
"for the attacker on a combat under 24 ticks old with no dug-in unit — but it feeds something other
than a `BM_*` entry, and what was not established." It feeds nothing. **Surprise is a half-removed
feature**: every guard survives and everything that used the values is gone.

### What is there

In `CLandCombatant::ApplyCombatModifiers` (`0x569B50`, rva `0x169B50`):

```
0x56A29F  cmp byte [ebx+0x38], 0        ; is_attacker
0x56A2A7  je  0x56A349                  ; defender -> skip
0x56A2AD  cmp byte [esp+0xE], 0
0x56A2B2  jne 0x56A335                  ; a byte local set earlier -> skip
0x56A2B8  mov eax, [ebx+0x3C]           ; the combat
0x56A2BB  cmp dword [eax+0x1C], 0x18    ; CCombat::day >= 24 ticks
0x56A2BF  jge 0x56A335                  ; -> skip
0x56A2C1  cmp dword [0x1A86040], 0      ; GetDefines(), inlined (trap 8 case 1)
0x56A2C8  jne 0x56A327                  ; ** the singleton already exists -> jump past it all **
   ...    push 0x11C; call 0xB9602F; ... ; mov [0x1A86040], edi
0x56A327  push 1                        ; kind 1 = surprise_chance
0x56A329  lea  ecx, [esp+0x44]          ; the out buffer
0x56A32D  push ecx
0x56A32E  mov  ecx, esi                 ; esi = the CUnit
0x56A330  call 0x5D1120                 ; CUnit::GetTraitEffect
0x56A335  cmp  byte [ebx+0x38], 0       ; <- eax is not read
```

The `[esp+0xE]` byte is the "a unit on this side is dug in" flag the record names; the 24 is a raw
immediate, not a define.

### That the answer is discarded — three independent checks

**The returned pointer is not used.** `cfg.py 0x569B50 0x1270 --lands-in 0x56A2B8 0x56A340` gives
every edge into the range: `0x56A2B2 jne -> 0x56A335`, `0x56A2BF jge -> 0x56A335`, and
`0x56A339 je -> 0x56A33B`. Nothing jumps between the `call` and `0x56A335`, and `eax` is clobbered
at `0x56A33B` by `mov eax,[ebp+8]` without being read on any path. (Trap 13: read off the edge list,
not off one jump.)

**The out buffer is never read.** `GetTraitEffect` writes through its `out` pointer, so the value
survives in the stack slot even though `eax` is dead. The `lea` is taken after the `push 1`, so the
buffer is at frame+0x40. Counting every `esp`-relative displacement in the function's 1,547
instructions: `esp+0x40` appears **zero** times, `esp+0x44` appears three times and all three are
`lea` (address-taking, never a value read), and the function has **no `[ebp - N]` locals at all** —
every local is `esp`-relative, so there is no second spelling the value could be read under.

**The positive control, in the same function.** There are twelve `CUnit::GetTraitEffect` call sites
in `CLandCombatant::ApplyCombatModifiers`. Eleven dereference the returned pointer on the very next
instruction:

| site | kind | next instruction |
| --- | --- | --- |
| `0x56A48D` | 23 experience_bonus | `mov eax,[eax]` |
| `0x56A658` | 10 out_of_supply_modifier | `mov eax,[eax]` |
| `0x56A75C` | 26 digin_bonus | `mov eax,[eax]` |
| `0x56A852` | 20 dissent_impact | `mov eax,[eax]` |
| `0x56A9F6` | 18 night_attack | `add edi,[eax]` |
| `0x56AA80` | 4 offence_modifier | `mov ecx,[eax]` |
| `0x56AAC6` | 3 defence_modifier | `mov eax,[eax]` |
| `0x56ABA6` | 22 envelopment_bonus | `mov eax,[eax]` |
| `0x56AC60` | 21 encirclement_bonus | `mov ecx,[eax]` |
| `0x56AAAB`, `0x56AAF1` | 29 / 30 terrain, via the typed sibling `0x5D0F80` | `mov eax,[eax]` |
| **`0x56A330`** | **1 surprise_chance** | **`cmp byte [ebx+0x38], 0`** |

and the compiler gave each call its own buffer — `esp+0x44`, `0x4C`, `0x50`, `0x54`, `0x58`, `0x60`,
`0x68`, `0x70`, `0x74`, each appearing exactly once and only as a `lea`. So in this function the
*only* way to consume a trait effect is through `eax`, eleven sites do it, and the surprise site does
not. **Confirmed.**

### The `GetDefines()` beside it is dead too

Nothing in `0x56A2C1..0x56A327` reads a field off the singleton, and the fast path at `0x56A2C8`
jumps straight past the whole block to the `push 1`, so on every call after the first the pointer is
not even loaded. The block's only effect is "ensure the singleton exists". That is exactly what an
optimiser leaves when the only consumer of a value is dead: `GetDefines()` allocates and writes a
global so it cannot be elided, `GetTraitEffect` is an out-of-line call so it cannot be elided, and
the arithmetic between them can. **A define *was* read here.** Which one cannot be recovered from the
bytes, because the read is gone.

### `surprise_chance` has no other reader in the image

`scratchpad/combat3/traitkinds.py` decodes every one of the 28,430 strong entries forward, finds every
`call` to `CUnit::GetTraitEffect` (`0x5D1120`, rva `0x1D1120`) and its typed sibling `0x5D0F80`
(rva `0x1D0F80`), and takes the kind from the last `push imm` before the call. **72 call sites. Every
one of the 31 trait kinds in `common/traits.txt`'s header order appears, and kind 1 appears exactly
once — `0x56A330`.** Counts: kind 0 ×1, 1 ×1, 2 ×5, 3 ×2, 4 ×2, 5 ×3, 6 ×2, 7 ×2, 8 ×1, 9 ×3, 10 ×7,
11 ×1, 12 ×1, 13 ×2, 14 ×1, 15 ×1, 16 ×2, 17 ×1, 18 ×5, 19 ×1, 20 ×3, 21 ×2, 22 ×2, 23 ×7, 24 ×2,
25 ×2, 26 ×2, 27 ×1, 28 ×2, 29 ×1, 30 ×1 (the three leftover rows are the two functions' recursive
self-calls, where the "last push imm" heuristic picks up an unrelated immediate). That the scan finds
every other kind, including the eight whose positions `FINDINGS-combatmods.md` fixed independently,
is its control.

So **`surprise_chance` on a leader trait has no effect on anything in this build.** BlackICE sets it
on roughly forty traits, up to `0.125`.

### `SURPRISE_BONUS` has no reader either

`defines.lua` has `SURPRISE_BONUS = 0.33`, and `definesMap.py` places it at **`military + 0x228`**
(the `military` block pointer is `CDefines + 0xAC`, 179 entries).

| define | block offset | readers found by `chain.py --span 0x100` | bodies that use `[reg+D]` **and** get the singleton |
| --- | --- | --- | --- |
| `CHANCE_TO_AVOID_HIT_AT_NO_DEF` | `+0x0C` | 8 | — |
| `BASE_NIGHT_PENALTY` | `+0x120` | 6 (the five slot-19 bodies + `0x7E6EDE`) | **18** |
| `LAND_COMBAT_STR_ARMOR_ON_SOFT_DICE_SIZE` | `+0x158` | 1 (`0x56B067`) | **23** |
| `LAND_COMBAT_ORG_ARMOR_ON_SOFT_DICE_SIZE` | `+0x15C` | 1 (`0x56B06D`) | **6** |
| **`SURPRISE_BONUS`** | **`+0x228`** | **0** | **0 of 228** |

228 decoded bodies use `[reg + 0x228]` somewhere — it is a `CSubUnitDefinition` field, a `CProvince`
field and a dozen other things (trap 12) — and **not one of them obtains the `CDefines` singleton at
all**, by `call 0x445D90` or by the inlined `[0x1A86040]` form. The two controls in the same block
return 18 and 23. Trap 8 case 3 does not apply: `SURPRISE_BONUS` *is* a `defines.lua` entry, so it is
parsed and stored; it is simply never read back. **Confirmed**, with the caveat in §0 that the decode
covers the 93.3% of non-padding `.text` that the entry set reaches.

### What this makes of `BM_SURPRISE_PENALTY`

`FINDINGS-combatmods.md` has it right and this adds nothing to it except company: id `0x1C` has no
site to either adder, its only reader is `CombatModifierKey` (`0x564060`) for the localisation key,
and `localisation/units.csv` still carries `BM_SURPRISE_PENALTY;Surprise Penalty` and its `_desc`.
I could **not** independently confirm "`+0x24` is never written": `+0x24` is one of the commonest
displacements in the image (517 byte-sized writes in the decode) and my scan cannot separate a
`CCombatant` from anything else at that offset. The claim stands on the census's own enumeration —
all 69 adder sites set `[this + 8 + id] = 1` and none passes `0x1C` — which is better evidence than
a displacement scan could be.

**So: the gate survives, the two side-effecting calls survive, and the modifier, the define and the
flag are all gone.** A mod cannot reach land surprise from `defines.lua`, from `traits.txt` or from a
modifier list.

---

## 2. `BM_ARMOR_ADVANTAGE`: the flag reaches script, and the mechanic is somewhere else

Two separate findings, and they answer the question in opposite directions.

### The flag's one reader is a script trigger

`CCombatant + 0x08 + id` is the per-id "this modifier was in play" array. A scan for byte accesses of
the shape `[base + index*1 + 8]` over the whole decoded image — `scratchpad/combat3/indexscan.py` —
finds **twelve instructions**, and exactly one of them is on a combatant:

```
0x00A07F53 (rva 0x607F53)   mov al, byte ptr [edx + eax + 8]
```

inside `0xA07E80` (rva `0x607E80`), which `vtable.py --holding` places in **one** table:
`CCombatModifierTrigger` **slot 6**. `CTrigger`'s own slot 6 is the pure-virtual stub `0xB961D5`, so
slot 6 is `Evaluate`. The class derives from `CStringTrigger`, which supplies the key as a
`std::string` at `+0x40`. The body:

```
bool __thiscall CCombatModifierTrigger::Evaluate(this, void* scope)
    for (id = 0; id < 0x1E; ++id)                   ; cmp eax,0x1e at 0xA07F2C -- thirty ids
        key = CombatModifierKey(id)                 ; 0x564060, at 0xA07EB6
        if (key == this->+0x40)  goto found         ; std::string compare through 0x415F70
    return false                                   ; 0xA07F37
found:
    combatant = scope->+0x40                       ; 0xA07F4D
    return combatant[8 + id]                       ; 0xA07F53
```

`scope->+0x40` being the `CCombatant*` has three independent witnesses, all slot 6 of a sibling
trigger: this one, `CCombatIsConvoyTrigger::Evaluate` (`0xA07F70`, rva `0x607F70`) which reads
`combatant->combat (+0x3C)->+0x2B`, and `CCombatIsWinnerTrigger::Evaluate` (`0xA07F90`, rva
`0x607F90`) which reads `combatant->combat->+0x2A` and then calls `CCombatant` slot 16. All three
`ret 4`. **Confirmed.**

**The control pair, which is what makes the negative mean anything.** The array is written by literal
displacement and read by computed index, so each needs its own method, and each method was shown to
work on *this* array:

* The literal-displacement scan (`scratchpad/combat3/flagscan.py`, every byte-sized `[reg+disp]` with
  `8 <= disp <= 0x25` over all 28,430 bodies) finds the flag **writes**, including `0x56AD8D`
  `mov byte [ebx+0x1B], 1` — the only write to `+0x1B` in the image — and `0x569A56`
  `mov byte [edx+0x13], 1`, which is `BM_AMPH_PENALTY`'s flag exactly where the census says. So the
  method can see this array.
* The same scan finds **no read of `+0x1B` on a combatant anywhere**. The 40 reads it does report are
  two instructions, `0xBAB056` and `0xBAB05A`, in one body at `0xBA9060`, repeated across rows by the
  over-reach described in §0.
* The index scan finds the one read. Twelve hits image-wide, one on a combatant.

**A trap worth stating: `BM_ARMOR_ADVANTAGE` is id `0x13` and its flag is at `+0x1B`, while `+0x13`
is `BM_AMPH_PENALTY`'s flag (id `0x0B`).** The off-by-eight invites exactly the wrong grep.

So the answer to "what reads `BM_ARMOR_ADVANTAGE`'s flag byte" is: **one script trigger, and nothing
in the simulation.** A mod can write that trigger and it will work. The engine cannot see the flag.

### What the flag is actually computed from

The tail of `CLandCombatant::ApplyCombatModifiers`, `0x56AD29..0x56AD8D`:

```
other = [ebp+8]
if (!other->slot 6())  skip                        ; 0x56AD33 -- true only for a CLandCombatant
best = 0
for (node = this->front_line (+0xB0); node; node = node->+8)       ; 0x56AD50..0x56AD68
    best = max(best, node->unit->+0xC8->armor (+0x12C))            ; cmovl
for (node = other->front_line (+0xB0); node; node = node->+8)      ; 0x56AD74..0x56AD89
    if (best > node->unit->+0xC8->piercing_attack (+0x13C))        ; 0x56AD7F, jg
        this->+0x1B = 1;  break                                    ; 0x56AD8D
```

`CSubUnitDefinition +0x12C` is `armor` and `+0x13C` is `piercing_attack` — both already named in
`project.json`, checked before reading (trap 14). `CCombatant +0xB0` is `front_line`, also already
named. Two things the bytes say that a reader would not guess: the test is over the **front lines**,
not `units`; and it is **existential** — it stops at the first enemy unit whose piercing is below our
best armour, so one weak brigade on the far side sets the flag. And `+0xC8` is the **summed**
definition, so a division's armour is the sum of its brigades'. **Confirmed** as read; whether the
existential form is intended is outside what the bytes say.

### The mechanic the localisation describes is live, in `CLandCombatant::FireUnit`

`localisation/tfh.csv` says of `BM_ARMOR_ADVANTAGE`: *"Units with stronger armor than their enemy can
penetrate will take reduced damage from their attacks, and do increased Organizational damage to them
in return."* That is a damage effect, and it exists — independently of the flag, in
`CLandCombatant::FireUnit` (`0x56ADC0`, rva `0x16ADC0`, already `confirmed`):

```
0x56B014  ecx = GetDefines()->military (+0xAC)
0x56B01F  ebx = ecx->LAND_COMBAT_ORG_DICE_SIZE (+0x150) / 1000
0x56B034  edi = ecx->LAND_COMBAT_STR_DICE_SIZE (+0x154) / 1000
0x56B044  target = [esp+8]
0x56B04E  eax = target->+0xC8->piercing_attack (+0x13C)
0x56B054  edx = attacker(ESI)->+0xC8
0x56B05A  cmp [edx+0x12C], eax          ; attacker armor  vs  target piercing
0x56B060  jle 0x56B08E
0x56B067  edi = ecx->LAND_COMBAT_STR_ARMOR_ON_SOFT_DICE_SIZE (+0x158) / 1000
0x56B06D  ebx = ecx->LAND_COMBAT_ORG_ARMOR_ON_SOFT_DICE_SIZE (+0x15C) / 1000
```

The `/1000` is the `imul 0x10624DD3; sar edx,6` idiom. `[esp+8]` is the target: the block immediately
after, at `0x56B08E`, reads `side->is_attacker (+0x38)` and then `[esp+8]->+0xC8`'s toughness or
defensiveness, which is the defence term the record already documents for this function.

**So when the attacker's armour exceeds the target's piercing, both land dice sizes are replaced by
the `*_ARMOR_ON_SOFT_*` pair.** In BlackICE that is ORG 7 → 7 and STR 3 → 4, i.e. armour advantage
currently buys only a wider strength die. `0x56B067` and `0x56B06D` are the **only** readers of those
two defines in the image. This is the counterpart of the deflection halving the record already notes
on `FireUnit` (`LAND_COMBAT_STR/ORG_ARMOR_DEFLECTION_FACTOR` when the attacker's piercing is below the
target's armor) — `FireUnit` has both halves of the armour mechanic and the record had one.

**Confirmed.** And note the consequence for the brief's framing: `BM_ARMOR_ADVANTAGE` is not a dead
feature. It is a **live mechanic with a dead modifier row**: the engine applies it per attacker/target
pair in the damage path, and separately computes a per-side flag, for script, by a different rule
(max-vs-any over front lines). The two can disagree, and nothing reconciles them.

---

## 3. `CCombatant` slot 11 is live, and its consumer is the combat-status window

`project.json` names `0x5662F0` (rva `0x1662F0`) `CCombatant::SumSubUnitStrength`, `likely`, and says
the name is descriptive of the arithmetic. `FINDINGS-negatives.md` lists "what consumes its result —
`0x568EE0`'s callers — was not followed" as open. Followed.

### `0x568EE0` is not a caller, it is `CLandCombatant`'s own slot 11

```
0x568EE0  push ebp; mov ebp,esp; push esi
0x568EE4  mov esi,[ebp+8]          ; out
0x568EE7  push esi
0x568EE8  call 0x5662F0            ; the base body, non-virtually
0x568EED  mov eax,esi
0x568EF1  ret 4
```

`findRefs.py --callers 0x568EE0` → **0 direct calls**. `vtable.py --holding 0x568EE0` → one table:
`CLandCombatant` slot 11. So `0x568EE0` (rva `0x168EE0`) is the eighth member of the slot-11 family —
`project.json`'s note on `0x1662F0` lists the seven vftables that hold the base, and this is the one
that does not — and it is a pure forwarder: `ecx` is never touched, so `this` passes straight through.
An override that only calls the base is what is left when a derived implementation is emptied.

A byte-level check settles the reachability question for both bodies.
`image.findBytes(struct.pack('<I', 0x5662F0))` returns **seven** addresses, `0x15C4608`, `0x15C4678`,
`0x15C46E8`, `0x15C4758`, `0x15C4CD0`, `0x15C4DB8`, `0x15C4EA0` — each exactly `vftable + 0x2C` of
`CBomberCombatant`, `CGroundTargetCombatant`, `CNavalTargetCombatant`, `CLandTargetCombatant`,
`CCombatant`, `CNavalCombatant`, `CAirCombatant`. `0x568EE0` returns **one**, `0x15C4E28` =
`CLandCombatant`'s vftable + `0x2C`. Nothing in `.text` holds either as a dword. **The only route into
either body is a virtual call through slot 11.**

### The two calls that exist

`scratchpad/combat3/slot11out2.py` decodes every strong entry and reports every `call` through
displacement `+0x2C`, invalidating the register holding the loaded slot on any write to it (a first
version did not, and reported 1072 hits where there are 1157 genuine ones plus a mass of
misattributions). Image-wide: **1,157 calls through `+0x2C`.** In the combat module
(`0x550000..0x5A0000`), **46**, and every one of them is `test al, al` — `CSubUnit::IsAir`, the third
leg of the predicate triple — or `cmp eax, N` for `CCombat::GetKind`, which shares the slot number.
`+0x2C` as a slot number is trap 12 in its purest form.

Filtering all 1,157 on "an out-pointer was pushed in the window" leaves 362; the two that matter are
in `0x57B050` (rva `0x17B050`):

```
0x0057B050   int* __thiscall  f(CCombat* this, int* out)
0x57B056  movss xmm0,[0x17179AC]           ; the float 1.5
0x57B068  call 0x401FD0                    ; floorf
0x57B070  call 0xC08870                    ; -> esi = (int)floor(1.5f) = 1
0x57B075  ecx = this->attacker (+0x10)
0x57B07C  eax = [ecx]->+0x2C               ; slot 11
0x57B07F  lea edx,[ebp-4]; push edx
0x57B083  call eax                         ; the ATTACKER's sum
0x57B085  ecx = this->defender (+0x14)
0x57B08A  edx = [ecx]->+0x2C
0x57B08D  lea eax,[ebp-8]; push eax
0x57B091  call edx                         ; the DEFENDER's sum
0x57B093  a = [ebp-4];  d = [ebp-8]
0x57B099  a = max(a, 1);  d = max(d, 1)    ; cmovl, twice
0x57B0A3  total = a + d
0x57B0A8  if (total == 0) { *out = -1; return out }        ; unreachable
0x57B0BA  *out = a * 1000 / total          ; plain imul/idiv when a+0x189373 <= 0x39580D,
0x57B0E0                                   ; otherwise __allmul/__alldiv
```

`vtable.py --holding 0x57B050` → **seven** tables, slot 17, in `CCombat`, `CLandCombat`,
`CAirCombat`, `CNavalCombat`, `CGroundBombing`, `CLandBombing` and one more; nobody overrides it. So
**`CCombat` slot 17 is the attacker's share of the two sides' total strength, in thousandths**, and it
is the only consumer of slot 11.

**Why my first pass said "dead".** The filter required the instruction after the call to dereference
`eax`; here both results are read back from `[ebp-4]`/`[ebp-8]` instead. Same shape of mistake as §0's
third false zero, caught the same way.

**The positive controls, two of them.** The same scan finds the two `CCombatant` **slot 19** calls at
`0x56F0F0` and `0x56F0FF` inside `CCombat::Tick` (`0x56EBE0`), each through `combat->+0x10`/`+0x14` —
calls the record already documents — and the `CCombatant` **slot 16** call at `0xA07FAA` in
`CCombatIsWinnerTrigger::Evaluate`, outside the combat module entirely. A method that finds both a
combat-module and a trigger-region `CCombatant` virtual call is a method whose silence is worth
something.

### Where the number goes

`findRefs.py --callers 0x57B050` → 0 direct calls; it is reached through slot 17. Enumerating every
`+0x44` call in the combat module (118 of them) leaves exactly one whose receiver is the `CCombat`
itself:

```
0x57C151  edx = [esi]              ; esi = this, the CCombat
0x57C153  edx = [edx+0x44]         ; slot 17
0x57C156  lea eax,[ebp-0x10]; push eax; mov ecx,esi
0x57C15C  call edx
```

inside **`0x57BD70`** (rva `0x17BD70`), 0x609 bytes, bare `ret` at `0x57C379`, receiver in **ESI** and
no stack argument at all. One caller: `0x56F34C`, at the very end of `CCombat::Tick`, guarded by

```
0x56F311  combat->GetKind() != 3        (and != 2 at 0x56F31F)
0x56F326  0x4A8630(&playerTag, &defender->countries (+0x54))   -> true: call
0x56F339  0x4A8630(&playerTag, &attacker->countries (+0x54))   -> false: skip
0x56F34C  call 0x57BD70
0x56F351  inc dword [esi+0x1C]          ; CCombat::day
```

so it runs **only for a combat the player's own country is in**. What it does:

* on its first call, looks up the GUI windows named **`combat_status`** (string at `0x15C4C78`) and
  **`combat_status_close`** (`0x15C4C88`) and caches them in **`CCombat +0x2C`** and **`+0x30`**; the
  function's first instruction (`cmp [esi+0x2C], ebx` at `0x57BD8F`) tests the cache and jumps to
  `0x57BF92` thereafter;
* reads `CCurrentGameState::player` (`+0xC30`/`+0xC34`, already named) and walks
  `defender->countries` for it;
* calls slot 17 at `0x57C15C` and compares the share against **660** (`0x1A8818C`, rva `0x168818C`)
  and **330** (`0x1A881E4`, rva `0x16881E4`), pushing one of `0`, `1`, `2` into
  `[combat+0x2C]`'s slot 24 — **with the order inverted when the player is the defender** (the
  `0x57C219` arm reuses the same two numbers, recomputed inline from the floats `660.5` at
  `0x160A654` and `330.5` at `0x160A6E0`);
* multiplies the share by 100000 and divides by 1000 and hands it to the string formatter `0xA5ACA0`.

Both thresholds are `(int)floor(N.5f)` statics with their own `.CRT$XCU` initialisers (`0xCC01A0`,
`0xCC0050`) — **66.0% and 33.0%, not tunable from `defines.lua`.**

### What this means, and the name

**Every combat modifier in the census reaches exactly one number, and that number is a display
quantity.** The chain is: the 69 adder sites → `CUnit +0xEC/+0xF0` and `CSubUnit +0x50/+0x54` →
`CCombatant` slot 11 per side → `CCombat` slot 17 → the `combat_status` window's icon state and
percentage. The modifiers reach the *simulation* by a completely different route (shot counts in
`FireUnit` and `CNavalCombatant::Attack`), which the record already has.

On the name: `CCombatant::SumSubUnitStrength` is accurate and I would **keep it** rather than churn
(trap 14 — the pipeline refuses to overwrite, and a collision here would be convergence). Its
confidence can go from `likely` to `confirmed` for the arithmetic; what was `likely` about it was the
purpose, and the purpose is now read. `CLandCombatant`'s forwarder is recorded under the same name.

---

## 4. The discarded slot-10 call is two identical arms folded together

`project.json` already records the site as `CombatLosses_DiscardedIsNavalCall` (rva `0x16645C`),
`confirmed`, with the correct observation that both possible bodies are side-effect-free folded stubs.
What was open is *why* it is there. It is the residue of

```
if (sub->IsLand())        { ...the brigade arm... }
else if (sub->IsNaval())  { m = sub->+0x54 * sub->+0x50 / 1000; }
else                      { m = sub->+0x54 * sub->+0x50 / 1000; }
```

with the second and third arms **identical**, which they must be: `+0x50` and `+0x54` are `CSubUnit`
fields, so a `CShip` and a `CWing` compute the same expression. MSVC folded the two blocks, which made
the conditional branch have one successor and deleted it, and left the `call` — an indirect call
through a vftable, which an optimiser may not remove because it cannot prove the callee pure. There is
no `test al, al` after `0x56645C`; `0x56645E` overwrites `eax` immediately.

**The two readings the brief asks to distinguish, and why it is folding and not a dead load.**

* It is a `call`, not a load. MSVC does not emit a dead *indirect call* as the residue of a dead load;
  it does leave one when the branch on its result becomes redundant.
* A release-build assertion leaves nothing at all — the macro expands away, call included.
* **The positive control: `CSubUnit` slot 10 is a live predicate whose answer is tested five times in
  one function a hundred bytes away.** `scratchpad/combat3/slotcall.py` with `SLOT=0x28` over
  `0x550000..0x5E0000` finds 65 calls. In `0x560B90` alone:

  | site | slot | after |
  | --- | --- | --- |
  | `0x5611E3` | 10 (`+0x28`) | `test al,al; je 0x561246` |
  | `0x56124D` | 9 (`+0x24`) | `test al,al; je 0x5612F7` |
  | `0x5612FE` | 10 | `test al,al; je 0x5613EC` |
  | `0x5613F3` | 11 (`+0x2C`) | `test al,al; je 0x56148D` |
  | `0x5614A9` | 10 | `test al,al; je 0x561593` |

  That is the un-folded `if (land) … else if (naval) … else if (air) …` shape with three *different*
  arms, in the same module, on the same class. So the dispatch at `0x56645C` is not a design decision
  about slot 10; it is what is left of a third arm that turned out to be a duplicate.

`0x560B90`, with `0x560600` and `0x5608A0`, are called exactly once each, from
`CBomberCombatant::Attack` (`0x5615C0`) at `0x56162A`, `0x561641` and `0x561657` — none of them is in
any vftable, and none is named in the record. **Confidence: `likely`.** The bytes fix what the code
does and rule out the assertion reading; "the source had three arms and two were identical" is the
simplest account that fits, not a thing the bytes state.

Practical consequence for BiceLib, which is the reason the record flagged it: **a hook at `0x56645C`
is safe to replace** — the call it makes has no effect on any of the four possible receivers.

---

## 5. The two combat constants at `CLASSES.md:453` are not defines

`CLASSES.md` says: *"Both constants are **defines whose names are not known**. `Define10` is 10 and
`Define50` is 50, each the floor of a float - 10.5 and 50.5 - taken at startup… Naming them for their
part in consumption would say more than the code does, so they are named for what they hold."*
`project.json` carries all three as `confirmed` globals with the comment "A define, …" and "Which
define it is has not been established."

**They are not defines, and "which define" has an answer: none.** Each is a compiled-in
`(int)floor(N.5f)` static with its own `.CRT$XCU` initialiser.

| global (rva) | value | initialiser | float | its pointer in the CRT table |
| --- | --- | --- | --- | --- |
| `Define10` `0x1A8873C` (rva `0x168873C`) | 10 | `0xCC3EB0` (rva `0x8C3EB0`) | `10.5` at `0x160A680` | `0xD40198`, once |
| `Define50` `0x1A8879C` (rva `0x168879C`) | 50 | `0xCC3F40` (rva `0x8C3F40`) | `50.5` at `0x160A7B4` | `0xD401A4`, once |
| `Define50_Regiment` `0x1A886E8` (rva `0x16886E8`) | 50 | `0xCC3780` (rva `0x8C3780`) | `50.5` at `0x160A7B4` | `0xD400E8`, once |
| `g_CombatModifierFloor` `0x1A8868C` (rva `0x168868C`) | 10 | `0xCC36F0` | `10.5` at `0x160A680` | `0xD400DC`, once |

Every initialiser has the same four instructions — `movss xmm0,[float]`, `push`/`movss` to the stack,
`call 0x401FD0` (`floorf`, already named), `call 0xC08870` (the double-to-int helper), `mov [global],
eax` — and each initialiser's address appears **exactly once** in the image, as a dword in the
contiguous pointer table at `0xD400DC..0xD401A4`, which is the `.CRT$XCU` static-initialiser array.
Reader counts agree with `CLASSES.md`'s own: `image.findValue` gives 11, 6 and 3 hits respectively,
each including the initialiser's own store, i.e. the "ten places", "five" and "two" the file states.
**Confirmed.**

**And one of them is a global the record already holds twice.** `Define10` (`0x1A8873C`) is read at
`0x5C30B8`, inside `CUnit::AddCombatModifier` — it is the clamp floor that
`FINDINGS-combatmods.md` §1 identified from the other end, writing "each a separate `(int)floor(10.5f)`
static written by its own `.CRT$XCU` initialiser — `0xCC3EB0` for the `CUnit` one". So the two surveys
converged on the same object and gave it two names and two stories: the `CUnit` floor is
`Define10` with the comment "A define, 10", and the `CSubUnit` floor is `g_CombatModifierFloor` whose
comment already says "the same value and the same trick as Define10_BuildCost". The record's own
convention for these — `k_thousandths_10`, `k_thousandths_100`, `g_WeatherMovementFloor`,
`g_IneffectiveStrength` ("A hardcoded `(int)floor(100.5f)` static, **not a define**") — is the right
one, and five entries have not been brought onto it.

The five are `Define10` (rva `0x168873C`), `Define50` (`0x168879C`), `Define50_Regiment`
(`0x16886E8`), `Define10_BuildCost` (`0x108746C`) and `Define50_BuildFloor` (`0x10874C0`). I verified
the first three. **The last two I did not**: `image.findValue` finds no `.text` reference to either
address, so their initialisers were not located, and the claim is only that they share the name
pattern and the same stated float. That is the cheapest remaining check in this section.

The practical statement for the mod: **no `defines.lua` entry can move `Define10` or `Define50`.** The
`0.010` per point of `CRegiment +0xCC` on supply consumption, the `0.050` on an army group
commander's skill, and the 1% floor on a combat-modifier product are compiled in.

---

## 6. `CUnit +0xDC` on a ship: confirmed as stated, with one thing added

The record's loose-ends table says `CUnit +0xDC` on a ship is cleared every tick and never filled,
because `CUnit::ResetCombatModifiers` is called from the **base** slot 19 that every kind runs while
naval and air modifiers go onto a different object. Checked piece by piece:

* **`CUnit::ResetCombatModifiers`** (`0x5C2FE0`, rva `0x1C2FE0`) is `ret 4` with the unit as a *stack*
  argument, not `__thiscall`. It does `lea esi,[ebx+0xDC]`, frees every node of the list
  (`0x481C80`, then a `[eax+8]`/`0xB95F9B` walk), writes zero to `[esi]`, `[esi+4]`, `[esi+8]` at
  `0x5C3015..0x5C301A` and `1000` into `+0xEC`, `+0xF0`, `+0xF4`, `+0xF8` at `0x5C3023..0x5C3035`.
* **Two callers**, `findRefs.py --callers`: `0x5655CE` and `0x5B5621`. `0x5655CE` is inside
  `CCombatant::ApplyCombatModifiers` (`0x565590`), the **base**, which all five slot-19 overrides call
  first. So in a naval or air battle the fleet's or air unit's `CUnit +0xDC` **is** emptied and
  `+0xE4` **is** written, once per side per tick.
* **The only writer of the list is `CUnit::AddCombatModifier`** (`0x5C3040`, rva `0x1C3040`), and its
  21 call sites are all in three land functions — `0x56557D` in `CCombatant::AddTerrainModifier`,
  `0x569864`/`0x5698A5`/`0x569A63`/`0x569B3D` in `CLandCombatant::AddAssaultModifiers`, and
  `0x56A36C`…`0x56AD19` in `CLandCombatant::ApplyCombatModifiers`.
* **Nothing else takes the list's address.** Across the whole image, `lea reg,[reg+0xDC]` (the "address
  of the `CList`" idiom, and far more selective than any store scan — `[reg+0xDC]` has 1,191 sites and
  `[reg+0xE4]` 938 written sites, trap 12) appears 37 times, and in `0x5B0000..0x5E0000` — the `CUnit`
  module — exactly once: `0x5C2FE8`, inside `ResetCombatModifiers` itself.

**Confirmed as stated.** Two refinements worth having:

1. "Never filled" is not a property of these functions. It is a property of whoever puts units on a
   `CLandCombatant`'s `units` list (`CCombat` slot 18, `AddUnit`), because
   `CLandCombatant::ApplyCombatModifiers` walks that list without checking any kind predicate and
   would happily push a land modifier onto a `CAir`'s `CUnit +0xDC` if one were on it. The bytes of the
   modifier code cannot settle that; `CCombat::AddUnit` can.
2. The four multipliers are not merely untouched on a ship's parent `CUnit` — they are **written to
   1000 every tick**. So anything that reads `CUnit +0xEC/+0xF0/+0xF4/+0xF8` off a `CNavy` or a `CAir`
   gets a neutral value, not a stale one. That matters for slot 11: its land arm multiplies all four,
   and it is reached only for a `CRegiment`, so a fleet's sub-units never take that path.

---

## 7. `CSubUnit` slot 9, independently confirmed — and the same pattern on `CCombatant`

`FINDINGS-negatives.md` §4 reports that `CSubUnit` slot 9 answers true for a brigade and nothing else.
Rechecked from the image, by the same primary source but not from that file's working:

```
python vtable.py CSubUnit CRegiment CShip CWing --all

slot  CSubUnit    CRegiment   CShip       CWing
   9  0x00592360  0x00A92590  =           =
  10  0x00592360  =           0x00A92590  =
  11  0x00592360  =           =           0x00A92590
```

(`=` means "the same as the reference column", `CSubUnit`.) `0x592360` is `xor al,al; ret` and
`0xA92590` is `mov al,1; ret`, read off the image. `vtable.py --holding` counts them at **836 tables**
and **440 tables** respectively, so neither may be named after a class (trap 4) and the information is
in the pattern. The RTTI export gives `CSubUnit` exactly three direct subclasses — `CRegiment`,
`CShip`, `CWing` — and **no class derives from any of those three**, so the matrix is exhaustive.
**`CSubUnit` slot 9 is true for a `CRegiment` and false for a `CShip`, a `CWing` and a bare
`CSubUnit`. Confirmed, independently.**

*The control, and it is now stronger than when that file was written.* The `CUnit` family repeats the
shape at slots 15/16/17 — `CUnit` holds `0x592360` at all three, `CArmy` replaces 15, `CNavy` 16,
`CAir` 17, and `CUnit` likewise has exactly three subclasses and nothing deeper — and
`project.json`'s `vftable_slots` **already names `CUnit` 15/16/17 as `IsLand`/`IsNaval`/`IsAir`**,
arrived at from call sites rather than from the table. So the method reproduces, on the family one
level up, names the record obtained another way.

### The `CCombatant` family has the same arrangement at slots 6/7/8/9

This is new, and it closes three "not identified" slot calls in the modifier code at once.

```
slot  CCombatant  CLandCombatant  CNavalCombatant  CAirCombatant  CBomberCombatant  CLandTarget  CNavalTarget  CGroundTarget
   6  ReturnFalse  ReturnTrue      =                =              =                 =            =             =
   7  ReturnFalse  =               ReturnTrue       =              =                 =            =             =
   8  ReturnFalse  =               =                ReturnTrue     =                 =            =             =
   9  ReturnFalse  =               =                =              =                 =            ReturnTrue    =
```

So slot 6 is true only for `CLandCombatant`, slot 7 only for `CNavalCombatant`, slot 8 only for
`CAirCombatant`, and slot 9 only for `CNavalTargetCombatant`. `CBomberCombatant`,
`CLandTargetCombatant` and `CGroundTargetCombatant` answer false to all four. Slot 10 is not part of
the set — its base is a different shared stub and `CBomberCombatant` overrides it with real code.
**Confirmed** by the same reasoning as above; a "false at four slots on the base, true at exactly one
on each of four classes" arrangement cannot arise by folding accident.

Three consequences, each resolving something the census left open:

* `other->slot 6()` at `0x56AD33` means **"the other side is a land combatant"**, so armour advantage
  is land-versus-land only (§2).
* `other->slot 7()` at `0x567A28` in `CNavalCombatant::Attack` means "the other side is naval", which
  is why the enemy's naval stacking-position penalty is only fetched then.
* `other->slot 9()` in `CBomberCombatant::ApplyCombatModifiers`' naval-surprise gate means **"the
  target side is a `CNavalTargetCombatant`"** — so `AIR_COMBAT_NAV_SURPRISE_*` applies exactly when
  naval bombers are bombing ships, which is what the define's own comment in `defines.lua` says. The
  census recorded the gate as `other->slot 9()` without knowing what it asked.

**And a naming hazard worth a line in `TRAPS.md`: "slot 9" means three different things inside this one
module.** `CSubUnit` slot 9 is `IsLand`; `CCombatant` slot 9 is `IsNavalTarget`; and the slot number
`+0x2C` alone is `CSubUnit::IsAir` in 46 places in the combat module and `CCombat::GetKind` in most of
the rest. Every slot claim here names its class.

---

## Corrections to the record

| file | what it says | what it should say |
| --- | --- | --- |
| `FINDINGS-combatmods.md` §1 and *Not established* | land combat reads `surprise_chance` at `0x56A330` but "it feeds something other than a `BM_*` entry, and what was not established" | It feeds **nothing**. The result is discarded (eleven of the twelve `GetTraitEffect` sites in that function dereference the answer; this one does not, its buffer at frame+0x40 is never read, and the function has no `ebp`-relative locals). It is the only read of trait kind 1 among the image's 72 `GetTraitEffect` sites, and `SURPRISE_BONUS` (`military+0x228`) has no reader at all. The `GetDefines()` inlined beside it is dead as well |
| `FINDINGS-combatmods.md` §1 / *Not established* | `BM_ARMOR_ADVANTAGE`'s flag byte is set at `0x56AD8D` and "whatever reads that byte is the consumer to find" | The byte's **only** reader is `CCombatModifierTrigger::Evaluate` (`0xA07E80`, slot 6), by computed index, so it reaches script and nothing else. The armour mechanic itself is live and independent, in `CLandCombatant::FireUnit` at `0x56B05A`, swapping both land dice sizes for the `LAND_COMBAT_*_ARMOR_ON_SOFT_DICE_SIZE` pair when the attacker's `armor` beats the target's `piercing_attack`. The flag's rule (max over our front line vs **any** enemy front-line unit) and the mechanic's rule (this attacker vs this target) are different computations and can disagree |
| `FINDINGS-negatives.md`, *What is not established* 4 | "What consumes [slot 11's] result — `0x568EE0`'s callers — was not followed" | `0x568EE0` has no callers: it **is** `CLandCombatant`'s slot 11, a pure forwarder to the base, and the eighth vftable in the family. Slot 11's two invocations in the whole image are `0x57B083` and `0x57B091` inside **`CCombat` slot 17** (`0x57B050`), which returns the attacker's share of total strength in thousandths; that number is consumed by `0x57BD70`, the `combat_status` window's per-tick refresh, called once from the end of `CCombat::Tick` and only for a combat the player is in |
| `FINDINGS-negatives.md`, *What is not established* 5 | "Why the cold block calls slot 10 and discards the answer. Read, not explained." | Two identical source arms folded: a `CShip` and a `CWing` compute the same `+0x54 × +0x50 / 1000`, so the branch had one successor and was deleted while the indirect call survived. Not an assertion (a release-build assert leaves no call) and not a dead load (it is a `call`). Control: `CSubUnit` slot 10's answer **is** tested, five times, in `0x560B90`, alongside slots 9 and 11 with three different arms |
| `CLASSES.md:453` | "Both constants are **defines whose names are not known**… Which define it is has not been established" | Neither is a define. `Define10` (rva `0x168873C`) and `Define50` (`0x168879C`) are `(int)floor(10.5f)` and `(int)floor(50.5f)` statics written by their own `.CRT$XCU` initialisers (`0xCC3EB0`, `0xCC3F40`), each initialiser's pointer appearing exactly once in the CRT table at `0xD400DC..0xD401A4`; same for `Define50_Regiment` (`0x16886E8`, initialiser `0xCC3780`). No `defines.lua` entry can move them |
| `project.json`, `Define10` / `Define50` / `Define50_Regiment` | "A define, 10 …" / "Which define it is has not been established" | As above. And `Define10` is the **same global** as `CUnit::AddCombatModifier`'s clamp floor (read at `0x5C30B8`), which `FINDINGS-combatmods.md` describes correctly from the other end — so the `CUnit` floor is filed as a define and the `CSubUnit` floor as `g_CombatModifierFloor`. The record's own `k_thousandths_N` / `g_<purpose>` convention and `g_IneffectiveStrength`'s "not a define" wording are the right treatment; five `DefineNN` entries have not been brought onto it |
| `FINDINGS-combatmods.md` §9 and the unexplained `other->slot 7()`/`slot 9()` calls | — | `CCombatant` slots 6/7/8/9 are `IsLand` / `IsNaval` / `IsAir` / `IsNavalTarget`, each true on exactly one class. So `other->slot 9()` in the bomber's naval-surprise gate asks whether the target side is a naval target |
| `reversing/fieldchain.py` | — | `--holder` raises `TypeError: 'int' object is not callable` on every invocation: `main()` passes `args.window` into `chained`'s `window` parameter, which shadows the module-level `window()` helper. Separately, the default `WINDOW = 0x40` is too small for the combat code and produced a false zero for `military+0x158`, whose reader is `0x53` bytes past the block load |

Nothing above contradicts `FINDINGS-negatives.md` §4's reading of slot 11's arithmetic, which I
re-read in full from `0x5662F0` and agree with instruction for instruction, including
`this->is_attacker ? toughness (+0x120) : defensiveness (+0x11C)` — which is also the correct HoI3
semantics, defensiveness on defence and toughness on attack.

---

## What is not established

1. **Whether anything other than `0x57C15C` calls `CCombat` slot 17.** The combat module's 118
   `+0x44` call sites were enumerated and only that one has a `CCombat` receiver; the UI and AI
   regions were not enumerated to the same standard, because `+0x44` has 6,507 call sites image-wide.
   *Cheapest check:* re-run `scratchpad/combat3/slotcall.py` with `SLOT=0x44` and keep only sites whose
   receiver register was itself loaded from a field that elsewhere in the same body is used with
   `+0x10` **and** `+0x14` — the `CCombat` attacker/defender pair is a two-field signature and far more
   selective than either alone.
2. **The classes of `CCombat +0x2C` and `+0x30`.** They are the cached `combat_status` and
   `combat_status_close` GUI objects and their slot 24 takes an icon state, which is why the field
   entries are `likely`. *Cheapest check:* the object is produced by `0x9C7D60` at `0x57BE56`; read
   that function's return type, or read `interface/*.gui` for the `combat_status` window's declared
   type.
3. **Which define used to be read at `0x56A2C1`.** The read is gone, so the bytes cannot say. *Cheapest
   check:* none statically. A Hearts of Iron 3 vanilla `defines.lua` from an earlier patch may still
   list a land surprise entry that this build's `CDefines` no longer reads; comparing the two files is
   cheaper than anything in the executable.
4. **Whether `Define10_BuildCost` (rva `0x108746C`) and `Define50_BuildFloor` (`0x10874C0`) are the
   same kind of `.CRT$XCU` static.** `image.findValue` finds no `.text` reference to either address, so
   their initialisers were not located and only the name pattern links them. *Cheapest check:*
   `image.findBytes` on the little-endian dword of each address to find the `mov [global], eax` in a
   `0xCC…` initialiser, then look that initialiser's own address up in the CRT table at
   `0xD400DC..0xD401A4`.
5. **Whether a `CAir` or `CNavy` can be on a `CLandCombatant`'s `units` list.** §6's "never filled"
   rests on it and the modifier code does not check. *Cheapest check:* read `CCombat` slot 18
   (`AddUnit`) for a kind predicate on the unit; `project.json` already names the slot.
6. **`CLandCombatant` slot 23 (`0x568F00`, rva `0x168F00`) — the obvious thing to read next.** It is
   slot 11's sibling and it is unnamed: for a combat whose `GetKind()` is not 1 it returns
   `*this->slot22() < 1000`; otherwise it averages `CUnit::GetAverageOrganisation` (slot 20, already
   named) over `front_line` (`+0xB0`) **and over a second unit list at `CCombatant +0xD0` that nothing
   in the record names**, and compares the mean against the global `1000` at `0x170D520` (five readers,
   all in slot 23 and its base `0x5656D0`). It reads as "has this side run out of organisation", i.e.
   the break-off test. *Cheapest check:* `fieldchain.py --field 0xD0` narrowed to the combat module,
   plus `CCombatant::CCombatant`, which will show whether `+0xD0/+0xD4/+0xD8` is a third `CList`
   beside `units` (`+0x40`), `front_line` (`+0xB0`) and `reserves` (`+0xC0`).
7. **Nothing was watched in a running game.** Three live checks, in order of value: (a) open the
   `combat_status` window on a battle whose two sides' strengths you can read and confirm the
   percentage is the attacker's share of the summed `org × strength × modifiers`, and that the icon
   changes at 66% and 33% — one battle settles §3 end to end; (b) give a leader a `surprise_chance`
   trait and confirm no combat tooltip or number moves, which is §1's prediction; (c) put a division
   whose `armor` exceeds the enemy's `piercing_attack` into a land battle and look for
   `BM_ARMOR_ADVANTAGE` **not** appearing in the modifier list while the strength damage runs hot —
   §2's prediction is precisely that the row never shows and the damage changes anyway.
8. **`6.7% of non-padding `.text`** is outside the entry set's reach, as `FINDINGS-negatives.md`
   measured for the same construction. Every negative above is bounded by that: the
   `SURPRISE_BONUS` zero, the `CCombatant +0x1B` zero, and "slot 11 has exactly two invocations". For
   `+0x1B` there is a byte-level backstop (the index-form scan found all twelve `[base+index+8]` byte
   accesses in the image); for the other two there is not, so both are `confirmed` as readings of what
   the decode contains and `likely` as statements about the whole image.
