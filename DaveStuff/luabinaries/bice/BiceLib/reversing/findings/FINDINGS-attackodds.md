# The AI's land attack odds: what `CAIUnit::EstimateAttackOdds` computes

rva `0x4D93B0`, VA `0x8D93B0`. 2,682 bytes (`0x4D93B0`–`0x4D9E2A`), 705 instructions,
`ret 0x14`, answer in ST0. Read end to end 2026-10-02 by decoding from the entry and
taking the block graph off `scripts/cfg.py`. `project.json` said "**The body was NOT
read**"; this file is that reading.

The short answer: **it returns our side's estimated damage output divided by theirs.**
The name was inference off the call sites and the inference was correct. What the call
sites could not say is that the figure is a *damage ratio* rather than a strength ratio,
that half the body is about units that are busy somewhere else, and that `arg2` is not a
unit list at all.

## 1. Extent, exits and the trap-3 block

Two `ret 0x14`. The one at `0x4D9E0C` is the normal exit; the block at `0x4D9E0F`,
*past* it, is the `their damage <= 0 -> return 50.0f` arm, reached only by the `jbe` at
`0x4D9D7E` and reusing the same frame (`pop edi/esi/ebx; mov esp,ebp; pop ebp`). So
trap 3 applies in form, the recorded extent `0x4D93B0`–`0x4D9E2A` was already right, and
`cfg.py` finds no block at or past `0x4D9E2A` (the `int3`).

Three constant exits, all read out of the image:

| when | returns |
| --- | --- |
| `ourUnits->count < 1` (`0x4D93DA`) | `0.0f` (`fldz`) |
| `theirCache->list->count < 1` (`0x4D93F2`) | `100.0f` [`0x1717BFC`] |
| their estimated damage `<= 0` (`0x4D9D7E`) | `50.0f` [`0x15C0548`] |

`100.0` and `50.0` are both far above every bar the caller tests, so "no defenders" and
"defenders who cannot hurt us" both read as *attack*.

## 2. The convention, and why the recorded signature failed its own check

`this` arrives in ECX and all five arguments are on the stack; the callee cleans them.
That is plain `__thiscall`. The recorded signature spelled it

    float __fastcall CAIUnit_EstimateAttackOdds(CAIUnit* agent@ECX, void* ourUnitList,
          void** theirUnitList, CMapProvince* target, int arg5, int arg6)

and `scripts/checkSignatures.py` refuses it: "signature wants ret 16, the function does
ret 20", plus "places 1 of 6 parameters". `__fastcall` means ECX **and** EDX, and EDX is
not an argument here — it is loaded at `0x4D93BC` from the *first stack* argument. By
trap 11 a `__thiscall` needs its class on the name, so:

    float __thiscall CAIUnit::EstimateAttackOdds(CAIUnit* this, CUnitList* ourUnits,
          void* theirCache, CMapProvince* target, CMapProvince* excludeProvince,
          int followCombats)

which `checkSignatures` computes as `ret 20` with no storage complaint. The `CAIUnit_`
prefix is right for its sibling `CAIUnit_ManageLandUnits`, which really is `__stdcall`
with the agent on the stack, and wrong for this one.

**The receiver is never dereferenced.** ECX is stored at `0x4D93CC` and read back once,
at `0x4D99C2`, only to be forwarded to the recursive call. Nothing in the body depends on
the spelling; only Ghidra's typing of `this` does.

## 3. The formula, term by term

Both sides run the same four accumulators over their own unit list. Per unit `u`:

```
weight = GetAverageStrength(u)/100000            ; CUnit slot 21, 0x1C65F0
       * GetAverageOrganisation(u)/100000        ; CUnit slot 20, 0x1C6580
       * (engagement + helper(u))                ; §4 and §5

def   = u->CSubUnitDefinitionPtr        (CUnit +0xC8)
mods  = u->owner->modifier_values       (CCountry +0xDA8, eight bytes an entry, trap 5)

A += (1 + mods[MODIFIER_SOFT_ATTACK]/1000) * def->soft_attack/1000 * weight
B += (1 + mods[MODIFIER_HARD_ATTACK]/1000) * def->hard_attack/1000 * weight
C += def->softness/1000
D += def->toughness/1000      * u->combat_defend_modifier_b * u->combat_defend_product / 1e6
                              ; the defending side uses def->defensiveness (+0x11C) here
```

`A` and `B` are plain sums; `C` and `D` are then divided by the side's unit count
(`0x4D98D3`–`0x4D98E6` ours, `0x4D9CE2`–`0x4D9CE6` theirs). Then

```
theirDamage = (1 - D_ours  /100) * ( A_theirs * C_ours   + B_theirs * (1 - C_ours) )
ourDamage   = (1 - D_theirs/100) * ( A_ours   * C_theirs + B_ours   * (1 - C_theirs) )
return ourDamage / theirDamage
```

Four independent things make this a reading rather than a story:

- **The modifier ids pair with the definition keys.** `[[owner]+0xDA8]+0x2F8` is entry
  `0x2F8/8 = 95` = `MODIFIER_SOFT_ATTACK` and it multiplies `def->soft_attack`;
  `+0x2F0` is entry 94 = `MODIFIER_HARD_ATTACK` and it multiplies `def->hard_attack`.
  That was not assumed — the ids came out of `ghidra/modifierIds.json` after the
  offsets were read.
- **Softness splits the two attacks the way the game does.** Soft attack is weighted by
  the *enemy's* mean softness and hard attack by one minus it.
- **Toughness and defensiveness land on the right sides.** Our attackers contribute
  `toughness (+0x120)`, their defenders `defensiveness (+0x11C)` — which is the game's
  own meaning of the two unit-file keys, and the code puts each where the key says.
  This settles the question `FINDINGS-combatmods.md` §9 left open about the
  `+0x11C`/`+0x120` pair, at least for this consumer.
- **Strength and organisation are percent-in-thousandths.** Slots 20 and 21 answer the
  plain mean of the regiments' `+0x60`/`+0x5C` (their internal `* 1000` and `/ 1000`
  cancel). The caller turns that into a 0..1 fraction in two steps: an
  overflow-guarded integer `v * 1000 / 100000` and then `/ 1000.0` in floats. The
  overflow guard is the `±0x20C49B` pair at `0x4D95D4`/`0x4D95DB`, which is exactly
  `INT_MAX/1000` — the bound you need before multiplying by 1000 — and the magic
  multiply `0x14F8B589; sar edx,0xD` is `/100000`, since `ceil(2^45/100000) =
  0x14F8B589`. Out of range it goes through `__allmul` then `__alldiv`. That is four of
  the six helper calls `project.json` noticed.

One asymmetry worth recording because it is invisible in the formula: **our side does
that division in integers and theirs in doubles.** Theirs is `/1000.0` then `/100.0`
(`0x4D9A74`/`0x4D9A84` and `0x4D9AD6`/`0x4D9B08`), ours truncates. Same value, different
rounding, so the two sides are not bit-identical functions of their inputs.

## 4. The engagement terms, and what the recursion is for

This is the half the call sites could not show, and it is where the two sides differ.

**Ours — a unit pinned defending contributes almost nothing.** For each combat in
`u->combats (+0x114)` in which `u` appears in `combat->defender->units`
(`CCombat +0x14`, then `CCombatant +0x40`):

```
r        = combat->GetAttackerStrengthShare() / 1000     ; CCombat slot 17, rva 0x17B050
engage  *= (1 - r)
if ((1 - r) < 0.5)  engage *= (1 - r)                    ; squared when r > 0.5
```

starting from `1.0f` per unit. The squaring bar is the literal `0.5f` at `0x15AB304`.
`GetAttackerStrengthShare` is `confirmed` in the record as the attacker's share of the
two sides' summed strength, in thousandths — so a unit whose attacker holds most of the
strength is written down twice over. Note this is the **only** consumer of that slot
outside `CCombat::UpdateCombatStatusWindow`: the record says its "only call site found is
`0x17C15C`", and this one reaches it virtually through `[[ecx]+0x44]` at `0x4D9513`, so
slot 17 is not display-only either.

**Theirs — a defender committed to an attack elsewhere is discounted by how that attack
is going.** For the **first** combat in which `v` appears in `combat->attacker->units`
(`CCombat +0x10`):

```
o         = EstimateAttackOdds(&combat->attacker->units,
                               {&combat->defender->units}, combat->province,
                               target, 0)                ; the recursion, 0x4D99CE
elsewhere = (o == 0 ? 0.01f : min(o, 4.0f)) * 0.25
```

and then it breaks out of the combats walk. The constants are `4.0f` [`0x171DF34`],
`0.01f` [`0x160A378`] and the double `0.25` [`0x160A258`], so the factor lies in
`(0.0025, 1.0]` — it can only reduce, never raise, the seed of `1.0`. The `o == 0` arm is
the `ucomiss / lahf / test ah,0x44 / jp` idiom at `0x4D99F7`, which jumps on *not*
equal, so `0.01f` is substituted only for an exact zero.

*Do not read anything into the `4.0f` being the same literal as
`LandAttackOddsThresholdForStance`'s default arm.* They share a constant pool; there is
no instruction linking them.

**So the recursion asks "how is that enemy unit's own attack going?"** — it swaps the
roles, making the other combat's *attacker* the "our" side.

**It is one level deep and cannot be more.** The self-call passes `followCombats = 0`,
and both combat walks — the only routes to it — sit inside `if (followCombats)`
(`0x4D94DF` and `0x4D9960`). Both top-level call sites pass 1.

**`excludeProvince` is dead in this build.** Its only test is `cmp eax,[ebp+0x14]` at
`0x4D999A`, inside the `followCombats` block. At depth 0 the callers pass 0 and
`combat->province` has already been tested non-null two instructions earlier, so the
comparison is always true; at depth 1 the block is never entered. The argument is the
guard the author wanted against bouncing straight back into the combat you came from, and
in this build it never fires. (`int arg5`, `int arg6` in the old signature were these
two.)

## 5. `arg2` is a 0x20-byte cache, not a unit list

The old signature typed it `void**`. It is a small struct the caller keeps on its own
frame at `[ebp-0x110]`, identically at both call sites:

| offset | what |
| --- | --- |
| `+0x00` | `CUnitList*` — the defenders (head at `+0`, count at `+8`) |
| `+0x04` | `B` — their hard-attack sum |
| `+0x08` | `A` — their soft-attack sum |
| `+0x0C` | `C` — their mean softness |
| `+0x10` | `D` — their mean defensiveness term |
| `+0x14` | their total brigade count |
| `+0x18` | the number of **distinct** provinces our units stand in — the cache key |
| `+0x1C` | the valid byte |

Only `+0x00` and `+0x1C` are initialised by the caller (`0x4D735E` and `0x4D7367`), and
only `+0x00` and `+0x1C` are read when the byte is clear — which is why the uninitialised
middle is harmless. Written out at `0x4D9CF5`–`0x4D9D09`, read back at `0x4D9915`.

**The cache key is exactly right, and that is a check on the whole reading.** The whole
defending side is recomputed only when `+0x18` changes, because the defenders' figures
depend on our side through precisely one number: `theirBrigades - 3 * ourProvinceCount`
(`lea edx,[eax+eax*2]; sub esi,edx` at `0x4D9938`), which is the second argument of the
defensive helper. Nothing else about our side reaches them. So two candidate units from
the same province reuse the cache and two from different provinces do not — which is the
behaviour the key implies and the arithmetic requires.

The caller does **not** reset the byte between the trials of one target: it is cleared
once at `0x4D7367`, before the first call, and the candidate loop starts at `0x4D7404`.
So the expensive defending side is computed once per target and reused across every
candidate, which is the point of the thing.

## 6. Is `esi` a `CUnit`? Settled, by a chain

`project.json` recorded this as `likely` because it rested on the `+0xF0`/`+0xF8` pair
being distinctive — trap 12's neighbour fallback. It now rests on five independent ties,
and **`fieldchain.py --holder` works**: the note in `FINDINGS-slot11.md` saying it raises
a `TypeError` is stale and should be struck.

1. `scripts/fieldchain.py --holder 0xC8 --field 0x134 --window 0x200` puts **both** of
   this function's `soft_attack` reads (`0x4D96F6`, `0x4D9AF1`) behind a `[esi + 0xC8]`
   load, and `CUnit +0xC8` is `CSubUnitDefinitionPtr`. The same holder reaches `+0x11C`
   (`0x4D9C2C`), `+0x120` (`0x4D9817`), `+0x124` (`0x4D97EB`, `0x4D9C00`) and `+0x138`.
2. `esi` is the receiver of `[[esi]+0x50]` and `[[esi]+0x54]`, and
   `vtable.py --holding` says those are slots 20 and 21 of `CUnit`, `CArmy`, `CNavy` and
   `CAir` — `CUnit::GetAverageOrganisation` and `CUnit::GetAverageStrength`, both
   `confirmed`. A virtual call through the object's own table at a named slot is about as
   strong as static typing gets; strictly it says "`CUnit` or a subclass of it".
3. `esi` is written at exactly **two** places in the whole 705-instruction body —
   `0x4D94CC` and `0x4D994D` — each time from a unit-list node's payload, and never
   touched again inside either loop. So the register that does
   `imul dword ptr [esi+0xF0]` is the same register that reaches everything above.
4. `[esi+0x124]`/`[esi+0x128]` are used as `owner`/`owner_id`, and `owner_id` indexes
   `g_CCountryDataBase->+0x16C` — a country-array index, which only a real `owner_id`
   can be.
5. `[esi+0x40]` is summed as the brigade count (`regiments_count`) and `[esi+0x130]`
   dereferenced to `+0xD0` for a province id (`current_province_ptr`, `CMapProvince::id`).

**A note on the tool, because it nearly produced a false negative.** At `fieldchain.py`'s
default `--window 0x80` the `+0xC8` chain finds the `+0x134` pair and **misses** `+0x11C`,
`+0x120` and `+0x124`, which sit 0xFB to 0x127 bytes past the `[esi+0xC8]` load. The
window was raised until the known `+0x134` pair still appeared — a positive control — and
the other three came with it. Raise the window before believing anything this tool is
quiet about.

## 7. Are the products ever non-neutral when this runs?

Three facts, and together they answer it with one qualification nobody had noticed.

**The writer census.** An offset scan for stores to `[reg + 0xF0]` returns 461 candidates
and cannot be read (trap 12); co-occurrence with the sibling product fields in the same
function still leaves 152. Two *shape* scans settle it instead:

- a store of the literal 1000 into `[R+0xEC/0xF0/0xF4/0xF8]`, with the immediate either
  inline or in a register loaded within 0x20 bytes: **exactly one site per field**,
  all four in `CUnit::ResetCombatModifiers` (`0x1C3023`, `0x1C3029`, `0x1C302F`,
  `0x1C3035`, off the `mov eax,0x3E8` at `0x1C301D`);
- a store into the same offsets within 0x24 bytes after a call to `__alldiv` or
  `__allmul`: three sites at `+0xF0`, of which `0x1A7900` and `0x1A83DC` are
  `CSubUnitDefinition::Scale` and `::Divide` on a different class (`+0xF0` there is
  `max_organisation` — a textbook trap 12 near-miss) and `0x1C3108` is
  `CUnit::AddCombatModifier`.

The first version of the reset scan insisted the immediate be inline and found
**nothing**, because `ResetCombatModifiers` loads 1000 into EAX once and stores it four
times. That is a worked example of TRAPS.md's closing rule: the silence was the tool.

**The constructor zeroes them.** `CUnit::CUnit` (rva `0x1B5010`) writes `ebx = 0` into
`+0xDC`, `+0xE0`, `+0xE4`, `+0xEC`, `+0xF0`, `+0xF4` and `+0xF8` at
`0x1B5124`–`0x1B514E`. **Not 1000 — zero.**

**Both writers are reached only through `CCombatant` slot 19**, i.e. only for a unit that
is in a combat; and nothing clears the fields when a combat ends. So:

| the unit | `+0xF0` when the AI reads it | the term `(1 - D/100)` |
| --- | --- | --- |
| has never fought | **0** | `1` — no toughness or defensiveness benefit at all |
| is fighting now | its real land defend product, 1000 × every modifier the last combat tick folded in | the real reduction |
| has stopped fighting | the last combat tick's value, stale and never cleared | the stale reduction |

**So the reader is real and the value is not inert — but it is zero for exactly the units
the AI most often estimates against.** A garrison nobody has attacked yet contributes no
defensiveness to the AI's estimate, which systematically over-states our odds on the
first pass and corrects itself once the fight starts. That is a behaviour, not a bug
report: I have not watched it.

The magnitude is small and bounded. With neutral products (`+0xF0 = +0xF8 = 1000`) the
product term is exactly 1.0 and `D` is the mean `toughness/1000`, so a division of
toughness 2.0 gives `1 - 0.02` — a 2% reduction in the enemy's modelled output. A fort
or terrain product of 2.5 would make it 5%. It moves the figure; it does not dominate it.

## 8. The monotonicity claim, corrected

`project.json` and `FINDINGS-aiconsumer.md` say the figure "is monotone in our committed
strength against theirs". **It is not, and the function cannot be.** Adding a unit raises
`A` and `B`, which are sums, but it also moves `C` and `D`, which are **means** — a
low-toughness unit lowers `D` and so *raises* the enemy's modelled damage — and if the
unit comes from a province no committed unit is already in, `ourProvinceCount` goes up,
`theirBrigades - 3*ourProvinces` goes down, and the entire defending side is recomputed
against a different number.

Monotonicity is **enforced by the caller**, not produced by the callee:
`CAIUnit_ManageLandUnits` compares the new figure against the old at `0x4D78EE`/
`0x4D78F2` and backs the unit out when it fell. The call sites' behaviour is right; the
explanation of it was not.

## 9. What this does to `FINDINGS-combatmods.md`

That file's half-subtraction stands and its surviving half gets stronger. Written out:

- `CUnit +0xF0` (land) has a **non-display consumer**, `confirmed`: this function, whose
  result decides whether the AI commits a division to an attack and whether it aborts
  one. The `likely` caveat — "`esi`'s identity rests on the distinctive `+0xF0`/`+0xF8`
  pair and `0x8D93B0`'s body is still unread" — is discharged on both counts (§6, and
  this whole file).
- The qualification to add is §7's: live, but **zero on a unit that has never fought**,
  and stale on one that has stopped.
- Nothing here touches the naval/air/bombing subtraction. `CSubUnit +0x54` is not read
  by this function; it reads `CUnit +0xF0`/`+0xF8` only, and none of `+0xEC`, `+0xF4`,
  `+0xDC` or `+0xE4` — which is what `project.json` already said and which the full
  reading confirms.
- Separately: `CCombat` slot 17 (`CCombat::GetAttackerStrengthShare`) is **not**
  display-only either. Its record says "its only call site found is `0x17C15C`, in
  `CCombat::UpdateCombatStatusWindow`"; this function reaches it virtually at
  `0x4D9513`. That does **not** revive the naval/air/bombing claim — slot 17 calls
  `CCombatant` slot 11 on both sides, and on a ship or a wing it is still only the
  *display* path's `CSubUnit +0x54` arm that feeds it. But "slot 17's only consumer is
  the billboard" is now false, and anything built on that sentence should be re-read.

## 10. What is not established

- **The two helper bodies, and they are the bulk of the per-unit weight.** `0x4D8C50`
  (ours; `this` in ECX, arguments `target province`, `ourBrigades`,
  `ourProvinceCount`, caller cleans 0xC, SEH frame) and `0x4D8590` (theirs; `this` in
  **EAX**, arguments `theirBrigades - 3*ourProvinces` clamped to at most 100 at
  `0x4D8A93`, and `ourProvinceCount`, caller cleans 8). Both are large, both go through
  `GetDefines()+0xAC`, `CUnit::CommandEffect` (`0x1D1120`),
  `GetDifficultyCombatModifier` (`0xDF9B0`), `CUnit::LeaderHasRankForCommand`
  (`0x1CD960`), `CProvinceTemplate::IsIsolatedLand` (`0xA9BE0`) and the unnamed
  encirclement helper at `0xA6850` — i.e. the AI keeps its **own** copy of the combat
  modifier model rather than reading the combat module's. Until they are read, "damage
  ratio" is a description of the terms I can see; whether they garnish the answer or are
  swamped by `helper(u)` is open. They are the next thing to read in this area.
- **Whether the figure matches a hand-computed `ourDamage/theirDamage` in a live game.**
  One hook on the return value for one province would settle §3 outright. Needs a
  running game; there was none this session.
- **How often the helper caches are refreshed.** `CUnit::CheckOrderAndCombat` (slot 31,
  rva `0x1BA2F0`) sets both dirty bytes at `0x1BA313`/`0x1BA31A`, and that is the only
  invalidation found. Its own record says "how often it runs is not established", so
  that question is inherited, not answered.
- **A `+0xF0` writer of a shape neither scan looks for** — a `memset`, a `rep stosd`, a
  copy from another object — would be invisible to §7. The flat scan that would catch
  one returns 461 unreadable candidates. Likewise the `+0x2D4`/`+0x2DC` writer census
  leaves 15 and 16 unresolved `mov [reg+disp], reg` stores, one of them at rva
  `0x1CEC82`, inside the `CUnit` method range and not chased.
- **Whether the products survive a save/load.** No save key for `+0xEC`–`+0xF8` appears
  anywhere in the record, which would make them zero after a load until the first
  combat tick; I did not read the loader. One live read settles it.
- **The distinct-province array has no bound check.** The loop at `0x4D9419`–`0x4D944B`
  writes `[esp + ecx*4 + 0x78]` and bumps the count with no limit. The frame is
  `sub esp,0x16c` under an `and esp,-8`, so there is room for 63 or 64 ids before it
  walks into the frame above. 64 distinct attacking provinces is not reachable through
  either call site — the candidates are the target province's friendly neighbours — so
  this is an observation, not a crash. I have not tried to construct a case that
  reaches it.
- **`arg4`/`excludeProvince` being dead** is true of this build's two call sites plus
  the recursion, and `findRefs.py --callers` reports exactly three direct calls and
  `vtable.py --holding` no virtual table. A fourth caller would change it; there isn't
  one.

## 11. Corrections to the record

1. **`0x4D93B0`'s own comment cites `LandAttackOddsBarForStance` (`0x4C04C0`); the name
   recorded at `0x4C04C0` is `LandAttackOddsThresholdForStance`.** Same address, stale
   name inside the comment. `FINDINGS-aiconsumer.md` calls it "the bar" in prose too,
   which is fine as prose but reads as a name in the `project.json` comment.
2. "so it is monotone in our committed strength against theirs" — wrong, see §8.
3. The signature's convention — wrong, see §2.
4. `FINDINGS-slot11.md`'s note that `fieldchain.py --holder` raises a `TypeError` is
   stale; it works, and it is what settled §6.
5. `CCombat::GetAttackerStrengthShare`'s "only call site found is `0x17C15C`" — there is
   a second, at `0x4D9513`, through slot 17.

## Confidence

`confirmed`, in the sense that a machine could check it: the instruction-by-instruction
arithmetic of §1, §3, §4 and §5; every field name used (all already recorded and
`confirmed`); every float and double literal, read out of the image; the `ret 20` against
the signature; §6's chain; §7's writer census and the constructor's zeroes; §8's
comparison at `0x4D78EE`.

`likely` — recorded as `inferred` in the fragment only because `mergeFindings.py` takes
no third word: that the result is fairly called "odds", that the two helper terms are an
offensive and a defensive combat value, and the claim in §7 about what a never-fought
unit does to the estimate in practice.

Not claimed at all: anything about the helper bodies, and anything that needs the game
running.

---

## Checked on transcription, 2026-10-02

The two load-bearing tool claims were re-run before filing, and one of them is overstated
in the agent's own summary:

- **The recorded signature really does fail.** `python scripts/checkSignatures.py --only
  0x4D93B0` reports *"signature wants ret 16, the function does ret 20"* plus the storage
  complaint, exactly as §2 says. So the `__fastcall` spelling is wrong on the record's own
  terms, independently of anything read in the body.
- **The `checkSignatures.py` `__fastcall` bug is real, and smaller than claimed.** The
  mechanism is confirmed by reading the code: the `__fastcall` branch drops the first two
  4-byte parameters by **size alone**, never consulting whether a parameter already carries
  explicit `@` storage, so a mixed signature with `@ECX` plus `@stack:` annotations loses
  four bytes. But the affected population is **5** entries carrying `@stack`, not the 23 the
  report claims — and of those five, **three** actually disagree today, each by **exactly
  four bytes**, which is the bug's fingerprint: `ApplyTechCategoryDecay` (wants 4, does 8),
  `StringHashInsert` and `TernarySearchTreeFind` (want 0, do 4). `CGraphics::DestroyVisibleObject`
  and `CBillboardObject::CBillboardObject` come out right anyway. So the fix is worth making
  and would clear **3** of the 88 disagreements, not a large slice of them.

**Landed 2026-10-02.** The fragment merged into `../ghidra/project.json` and moved to `../fragments/merged/attackodds.json`, which is why the path above is `merged/` and not `incoming/`. The Ghidra apply has run, against a scratch copy of the `Hoi3_v12.1.2` project, and reported **failed: 2** - the documented pass mark, both failures being the two known over-long Ghidra bodies. So these names are in `project.json`, in `bicelib_findings.json` and in that Ghidra database. **the maintainer's own project was not written to**: Ghidra was open on it at the time.
