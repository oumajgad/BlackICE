# Four load-bearing negatives, and what a positive control did to each

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is marked *seen*. Addresses are **virtual** (image base `0x400000`) with the rva beside them where a finding depends on it. The four questions came from `FINDINGS-aiplans.md`, `FINDINGS-weather.md`, `FINDINGS-weatherfront.md` and `FINDINGS-combatmods.md`; three of them were existing claims and two of those three turn out to need correcting. Scripts are in `scratchpad/negatives/`.

## In one line

`CObjective::priority` has exactly one consumer and it is a change detector, not a weighting; `CWeatherManager +0x14` is genuinely never set and that is now a proof rather than two surveys agreeing; the fallback's second ops-area command can only ever undo the first, so the behaviour is settled without a live check; and `CSubUnit` slot 9 answers true for a brigade and nothing else, read out of four vftables rather than inferred from a field set.

## 0. The method, and why three attempts failed their own control

Four scans were tried for question 1. The first three were discarded **because they could not see a read that is known to exist**, which is exactly the discipline the closing section of `TRAPS.md` asks for.

* A whole-body flow-insensitive displacement profile found 231 candidate bodies — too many to be useful, and when narrowed by "every displacement used with this register fits in `CObjective`'s `0x24` bytes" it **dropped `CAIUnit::DistributeObjectives`**, which demonstrably reads `+0x8` and `+0x10`. Register reuse within a large body defeats a body-wide containment test.
* A single forward taint pass found **nothing at all**, including in `CopyObjectiveList`, whose whole body is a list walk. The advance (`mov esi,[esi+0x1C]`) sits at the *bottom* of the loop and the reads at the top, so one forward pass can never see it. Every `CList` walk in this image has that shape.
* A loop-window heuristic — take the nearest backward branch after the advance as the loop — passed on `CopyObjectiveList` and slot 84 but **found no loop at all in slot 76**, because MSVC put the back edge eleven instructions away from the advance.
* What works is `cfgtaint.py`: real basic blocks, union at merges, iterate to a fixed point. It reports, for `CopyObjectiveList`, reads at `+0x4 +0x8 +0xC +0x10 +0x14`; for slot 84, `+0x4 +0x8 +0xC +0x10 +0x14`; for slot 76, `+0x8` and `+0x1C` only; for the generator, `+0x8 +0xC`; and **nothing** for `0x5F1F40`, the `std::string`-shaped false positive the cheaper scans produced. That is the control passing in five places at once.

Two rules the scans hold to throughout. **Nothing is decoded from a guess** (trap 9): entries come from the union of every `call rel32` target, every slot of every vftable in the RTTI export, and every post-`int3` address with a prologue byte — 35,388 of them — and each body is decoded forward from its entry. **A body runs to the first run of two `int3`**, not to its first `ret`, so a cold path past the `ret` stays inside the body it belongs to (trap 3); the price is over-reach into an abutting function (trap 2), which is the safe direction for a negative. Coverage: **8,639,316 of 9,257,333 non-padding `.text` bytes, 93.3%**. An independent recursive-descent closure reached 90.1% and agreed on every result below.

## 1. Does anything branch on `CObjective::priority`? Yes — once, and it only suppresses a command

`FINDINGS-aiplans.md` says: *"priority is written by the generator and the interface, carried through every copy, saved and loaded — and I found nothing in the AI that branches on it."* It flagged this as a negative rather than a fact, and named four unread UI bodies as the gap. **The negative is wrong in the letter, and the gap is closed.**

### What was read

`CEU3AI::GenerateUnitObjectives` (`0x8980E0`), after computing its candidate objectives, checks whether the agent's plan already holds the same ones:

```
for (each candidate c in the new list)                       ; 0x8986F0
    agent = <unit agent>                                      ; slot 74 at 0x898701
    for (o = agent->unit->plan.objectives (+0x234); o; o = o->next (+0x1C))
        if (o->province (+0x8) == c->province)                 ; 0x898715
            if (o->priority (+0xC) == c->priority) { matched++; break }   ; 0x89871A, 0x89871D, 0x898720
if (matched == <number of candidates>) skip the command entirely           ; 0x89872D
```

`0x89871A` (rva `0x49871A`) is **the only instruction in the image that branches on `priority`.** Everything else that touches `+0xC` on a `CObjective` moves it:

| where | what it does with `+0xC` |
| --- | --- |
| `CopyObjectiveList` `0x8DD350` | copies, at `0x8DD383` |
| `CAIUnit::DistributeObjectives` slot 84 `0x8C1790` | copies, at `0x8C1ABC` |
| `CList_CObjective_PushBackCopy` `0x5EBEA0` | copies, at `0x5EBED0` |
| `CSetPlanObjectivesCommand::LoadKey` `0x5E6AA0`, `CUnitPlan::LoadKey` `0x8DF720` | writes it from the save |
| `CTogglePlanObjectiveCommand::Execute` `0x5E6ED0` | writes `0x190` = 400, hardcoded at `0x5E701B` |
| `CEU3AI::GenerateUnitObjectives` `0x8980E0` | writes it from the formula, and **compares** it at `0x89871A` |
| `CAIUnit` slot 76 `0x8DABD0` | never reads it (reads `+0x8` and `+0x1C` only) |

**So the substance of the old negative survives: nothing weights, scores or orders anything by priority.** But the consequence for a mod is sharper than "the number may be inert". Because the dirty check compares priority as well as province, **a priority that differs from the AI's own `victory_points x 20 + bonuses` makes the check fail**, so the generator reposts its own objective list — with its own priorities — that hour. A hand-set priority does not change what the AI does; it changes only whether the AI bothers to overwrite it, and it makes the AI overwrite it.

### The searches, and the three controls

Three legs, because a `CObjective*` can reach a `[reg+0xC]` three ways: by walking a list, by being handed in, or by never being a `CObjective` at all.

**Leg 1 — the list walk.** A `CObjective` is its own `0x24`-byte node with the payload inlined and `next` at `+0x1C`, so a register that self-advances through `+0x1C` is walking a list of that shape. `cfgtaint.py` was run over every body in the image, seeded on that shape, and every memory access whose base may be the node was recorded. **Result: 30 reads of `+0xC` in 25 bodies.** Twenty of the twenty-five are false positives and each was read by hand: `0x8B9EA2`, `0x8D5C3B`, `0x8D5E0D`, `0x8E1C08` are all `mov ecx,[ecx+0xC]; jmp <loop top>` — a *different* list whose `next` is at `+0xC`; `0x613D21`, `0x616E0B` and `0x4E33B4` read a **country id** at `+0xC` and index `[0x1A855A4]+0x16C` and then `+0xE28`, i.e. the country database and the diplomacy array; the thirteen at `0xB9CDB5` and the three at `0xBDE6F4`/`0xBDEC8F`/`0xBDF3C3` are CRT. That leaves the five real ones in the table above. **Trap 12 in action: `+0xC` is three different things inside five instructions of each other.**

*Control:* the same scan for `+0x8` (province) found **34 reads in 24 bodies**, including slot 76 at `0x8DB17B`, slot 84 at `0x8C1A5B`/`0x8C1AB6`/`0x8C1B3E`, the generator at `0x89870D`, `CopyObjectiveList` at `0x8DD37D` and the toggle command at `0x5E6F37`. The same scan for `+0x10` (invasion) found **5 reads in 3 bodies**, including slot 84's `cmp dword [edi+0x10], 0` at `0x8C1A52` — the non-invasion filter the record describes. A run that could not see those could say nothing about `+0xC`; this one sees all of them.

**Leg 2 — handed in as an argument.** A function given a `CObjective*` need not walk anything. The same taint was reseeded on `ECX` at entry and on every load from a frame slot, and kept where the tainted register's footprint stays inside `0x0..0x20` and covers `+0xC` plus two of `+0x4/+0x8/+0x10/+0x14`. **On its own this leg is useless as a negative: 8,434 bodies pass the cheap pre-filter and 1,085 match, because a `0x24`-byte footprint describes every small struct accessor in the image.** It becomes useful when bounded. A `CObjective*` can only exist in the seven bodies that write its vftable, or be passed out of them, so the two-level direct-call closure of {the seven writers, slot 76, slot 84, `CSetPlanObjectivesCommand`'s constructor, `CEU3AI::RebuildPriorityProvinces`} — **219 functions** — is the whole universe. Intersecting: `0x5EBEA0` (the copy already in the table), `0x4EE110` (`CCountry::CollectCountriesWeCanOperateIn`, whose `+0xC` at `0x4EE13E` is the id half of a `CCountryTag`), `0x42DD70` (a UI body whose `+0xC` is a `std::string`, `lea ecx,[edi+0xC]` at `0x42DDDB` with `[edi+0x20] = 0xF`), and five CRT bodies at `0xB9Fxxxx`. **No consumer.**

*Control:* `0x5EBEA0`, which the record already identifies as a `CList<CObjective>` push-back-by-copy, is in the hit set with `+0x0 +0x4 +0x8 +0xC +0x10 +0x14`. The leg can see an objective handed in.

**Leg 3 — the creator set is complete.** `findRefs.py --vftable CObjective` gives **11 references in 7 bodies**, exactly the seven the record names. That bounds leg 2 and it independently confirms the record (trap 14: two surveys converging, not conflicting).

### The four UI bodies the record flagged as unread

`0x742AA0`, `0x743950`, `0x743B10` and `0x75EC40` were named as the gap. None of them is a priority reader, and none of them touches a `CObjective` at all:

* `0x742AA0`, `0x743950`, `0x743B10` read a `+0x2EC` that is **not** `CArmy +0x2EC`. At `0x742AC2`–`0x742AD5` the field holds a single pointer that is deleted through its own vftable slot 0, and at `0x742BAF` it is replaced with `0x583AA0`'s result, whose `+0x6C` is then written. It is a UI child object, not a `CList` head. Trap 12 again.
* `0x75EC40` touches `+0x38`/`+0x3C` only, and does no `+0x1C` advance anywhere in its 1,797 instructions.
* None of the four self-advances through `+0x1C`, so leg 1 could not have seen them even if they did hold objectives — which is why they were checked directly rather than trusted to the scan.

### `CCountry +0x4A8` is `conquer_prov`

The record lists `CCountry +0x4A8` and `CEU3AI +0x118` as the two unexplained additive terms. The first is now named, by arithmetic rather than by a search: **`CCountry +0x48C` is the country's live `CAIStrategy`, held by value, and `0x48C + 0x1C = 0x4A8`, which is `CAIStrategy +0x1C` — `conquer_prov`.** The walk at `0x898470`–`0x8984A3` confirms the shape: a standard `{data, prev, next, byte}` `CList` whose `data` is a record with the province id at `+0x8` and the value at `+0xC`, which is exactly how `CAIStrategy`'s `conquer_prov` entries are laid out.

So in a mod's AI strategy file, `conquer_prov = { id = <province> value = <N> }` adds `N` directly to that province's AI objective priority, on the same raw 0–1000 scale as `victory_points x 20`. **And because priority has no consumer, that lever is inert as well** — which is worth saying loudly, because it looks like the one place a mod can steer AI objectives and it is not.

The priority formula, re-read at `0x898440`–`0x8984AF` and agreeing with the record:

```
pri  = province->victory_points (CMapProvince +0x34) * 20     ; lea esi,[eax+eax*4] then two shifts
pri += <matching conquer_prov entry>->+0xC                     ; 0x8984A0, matched on +0x8 == province->id (+0xD0)
pri += 100 if province->id is on CEU3AI +0x118                 ; 0x8984A5
if (pri < 1) drop the province                                 ; 0x8984AC
```

### `CEU3AI +0x118` — the rebuilder found, the source not

`0x8976E0` (rva `0x4976E0`), `ret 4`, **one direct caller: `ProcessAI` at `0x889A93`, immediately before its call to `GenerateUnitObjectives` at `0x889AA8`.** Its first act, `0x897703`–`0x897731`, is to free every node of `ai->+0x118` and zero head, tail and count; it appends `{provinceId, prev, next, byte}` nodes back on at `0x8979D5`/`0x8979F9`. So **`+0x118` is per-hour scratch, rebuilt from nothing every AI pass** — which answers the record's "what fills it was not traced" halfway: whatever fills it, it is recomputed hourly and is not state a mod can set.

Where the ids come from is **not settled**. The function reaches the owner's country through `CCountryTag::GetCountry(&ai->+0x20)` (`0x897722`, `0x897777`), walks that country's faction (`CCountry +0xD8`) member list at `CFaction +0x28`, keeps members whose country id is not `ai->+0x24` and whose `CCountry +0xACC` byte is set, and then walks a per-index vector of `0x14`-byte records on `CGameState +0xBAC`, appending `[record+0]` where `[record+4]..[record+8]` — an int array — does not contain our own country id. `CGameState +0xBAC` is unnamed and what it holds was not established.

**A trap for the next reader of that body:** at `0x8978E9`–`0x897949` it allocates `0xDA8` bytes, calls `CGameState::CGameState` (`0x67D070`), stamps `CCurrentGameState`'s vftable `0x15CF674`, clears `+0xD9C`/`+0xDA0`/`+0xDA4` and swaps the result into `g_CCurrentGameState`. That is **not** an AI function building a game state — it is the inlined lazy singleton accessor, guarded by `test esi,esi; jne` at `0x8978E5`. The same shape is inlined at `0x8DBD3B` inside `CAIUnit` slot 76 and at `0x8DC8E0` in its epilogue. Anyone who finds it mid-function and reads it as construction will mis-identify the body.

## 2. `CWeatherManager +0x14` is never set, and this is now a proof

`FINDINGS-weather.md` says *"nothing was found that sets it"*; `FINDINGS-weatherfront.md` goes further — *"nothing sets it, the path is dead, and taking it would be a use-after-free"* — resting on there being eight instructions in the image touching `[reg+0xB00]` and only one of them a write. **Both are right. Two surveys agreeing is not a proof, so here are four closures, each with a control.**

**(a) There is exactly one `CWeatherManager` in the image.** `image.findValue(0x15CF5C0)` returns **one** address, `0x67D1C3`, inside `CGameState::CGameState`, which writes the vftable into `[ebx+0xAEC]`. A class is never instantiated except where its vftable is stored, so the manager is only ever `CGameState +0xAEC` and the byte is only ever `CGameState +0xB00`. No heap instance, no second copy, nothing to miss.

**(b) Every `[reg+0xB00]` instruction in `.text` is accounted for, and none is outside the decode.** The decode-from-entries scan over the window `+0xAEC..+0xB20` finds 116 instructions, of which eight carry displacement `0xB00` — matching the predecessor's count exactly, which is convergence rather than conflict (trap 14). Six are `esp`-relative stack locals (`0x4477D8`, `0x44AF12`, `0x468AD9`, `0x49AB32`, `0x7E96A9`, `0x7E96C8`). Two have an object base: `0x4C9470` (`mov byte [ebx+0xB00], 0`, a `std::string` in the body at `0x4C8A40` — the same displacement on an unrelated object) and **`0x67D1D9`** (`mov byte [ebx+0xB00], 0` in `CGameState::CGameState`, sixteen bytes after the vftable write). That is the only write, and it writes zero.

*The coverage control for (b), which is the part the earlier surveys could not supply:* the displacement `0xB00` needs a `disp32`, so any instruction encoding it contains the bytes `00 0B 00 00`. There are **83** such four-byte occurrences in `.text`, and **every one of them lies inside an instruction the decode saw** — zero fall in the 6.7% of non-padding `.text` that neither decode reached. So the eight are all of them, not just all the ones the scan could see. (The same check on `0xAF4` and `0xB1C`, the manager's other fields: 10 and 20 raw occurrences, 0 uncovered.)

*The positive control for the search itself:* the same scan sees the manager's **other** fields through a `CGameState` base, which is what makes its silence about `+0xB00` meaningful. It finds the vftable write at `0x67D1BD`, the front list seeded at `0x67D1C7`/`0x67D1CD`/`0x67D1D3`, the cooldown vector at `0x67D1E0`/`0x67D1E6`/`0x67D1EC`, the heading vector at `0x67D1F2`/`0x67D1F8`/`0x67D1FE`, and — in a different function — `0x67BAF0` reading `+0xAF4` at `0x67C003` and zeroing `+0xAF4`/`+0xAF8`/`+0xAFC` at `0x67C033`–`0x67C03F`. A search that can see nine of the manager's fields through a `CGameState` pointer and no write to the tenth is evidence about the tenth.

**(c) Every function that ever holds the manager as `this` was enumerated, and none writes `this+0x14`.** The manager's address can only be produced by `lea r,[x+0xAEC]`, and there are exactly seven such sites: `0x43DC83`, `0x67E19F`, `0x67F7D8`, `0x680205`, `0x68256B`, `0x6826ED`, `0x68CEA1`. Each hands it to a call. Together with the six vftable slots that is the complete receiver set:

| receiver | what it does with `this+0x14` |
| --- | --- |
| `CWeatherManager::Tick` `0x4B5A20` (from `0x43DC89`, `0x65C86A`, `0x6826F3`) | **reads it once**, `cmp byte [edi+0x14], 0` at `0x4B5CD7` |
| `0x4B59C0`, the per-zone reset (from `0x682571`) | no `+0x14` access at all |
| `InitialiseWeatherState` `0x4B54F0` | one `+0x14`, at `0x4B56E8`, on `[eax+0xEC]` — the **defines** block, cached to `[0x170CAA8]` (trap 8 case 2) |
| `CreateFront` `0x4B5D80` | one `+0x14`, at `0x4B5E0C`, on the **province** (`esi`, whose `+0x30` is the climate) |
| `SaveContents` slot 2 `0x4B5F60` | writes exactly one key, token `0x396`, walking `+0x8`. Never touches `+0x14` |
| `LoadKey` slot 4 `0x4B5FA0` | handles exactly one key, `0x396`. Its `mov dword [eax+0x14], ebx` at `0x4B5FDB` is **the new `CWeatherFront`'s `provinces_count`**, not the manager's byte |
| destructor path slot 0 `0x67DB60` → `0x67D980` | no `+0x14` |
| slot 1 `0x45BB10`, slot 3 `0xA7C050`, slot 5 `0xABF890` | folded shared stubs over 749/748/1691 holders; generic, no layout knowledge |

**So no save key can set it either** — which closes the one route a displacement scan would never find. The `LoadKey` line is worth keeping as a warning: that instruction looks exactly like a write to the manager's `+0x14` and is not (trap 12).

### What the branch would have done

`CWeatherManager::Tick`, `0x4B5CA4`–`0x4B5D10`:

```
node = <the front list cursor>
front = node->data                      ; ebx
next  = node->+0x8
if (CWeatherFront::Tick(front) == true)  continue            ; 0x4B5CB2
find the node n holding `front`, walking from this->+0x8      ; 0x4B5CBF-0x4B5CCF
if (!n) goto afterwards
if (this->+0x14 != 0)                                        ; 0x4B5CD7
    n->+0xC = 1                        ; mark the node, leave it on the list
else
    unlink n (prev->next, next->prev, head at +0x8, tail at +0xC)
    operator delete(n)
    --this->count (+0x10)
afterwards:
    clear the home zone's cooldown entry                      ; 0x4B5D17-0x4B5D51
    front->vf[0](1)                    ; delete the front object, unconditionally
```

So the byte chooses **only** whether the spent front's list node is unlinked and freed or just marked at `node+0xC`. The front object itself is deleted either way, at `0x4B5D57`–`0x4B5D5F`. Had the byte ever been set, the marked node would stay on the list with `node->data` pointing at freed memory, and the next hour's walk at `0x4B5CA4` does `mov ebx,[eax]` and hands it straight to `CWeatherFront::Tick` — a use-after-free on the hour. The count at `+0x10` would also stop being decremented, so the top-up loop that keeps the front population at `low_pressure_zones x MAXFROMEACHPRESSURE/1000` would stop creating new fronts. **Dead, and broken if it were alive.** Nothing reads `node+0xC` for this list, so marking has no other effect.

### Correction to `FINDINGS-weather.md`

That file says of the weather advance: *"Two calls, both out of `RunHourlyPass` (`0x282630`), and nowhere else."* `CWeatherManager::Tick` (rva `0xB5A20`) has **three** direct callers:

| caller | where |
| --- | --- |
| `0x6826F3` (rva `0x2826F3`) | `RunHourlyPass` — the one the record has |
| `0x65C86A` (rva `0x25C86A`) | inside **`CInGameIdler::Enter`** (rva `0x25A2B0`), in a loop counted off `[esp+0x50]` — this is the pre-roll, and it means the weather is advanced many times before the first game hour |
| `0x43DC89` (rva `0x3DC89`) | the unnamed body at rva `0x3DA80`, which installs a fresh game state into `g_CCurrentGameState` and then ticks the weather once |

Neither new caller writes `+0xB00` — neither body appears anywhere in the `0xB00` results — so the negative is unaffected. But "nowhere else" was wrong, and the pre-roll call is the interesting one for anyone reasoning about weather at game start.

## 3. The fallback's second `CSetPlanOpsAreaCommand`: settled from the bytes

`FINDINGS-aiplans.md` reports that `CAIUnit` slot 76's fallback posts a `CSetPlanOpsAreaCommand`, empties the list, and posts again; checked the frame offsets three times; and says plainly that both readings — a bug, or clearing-is-the-intent — are possible and that a live check is needed. **The control flow and the data flow are both decidable, and together they collapse the two readings into one behaviour.**

### The edge list, not one jump (trap 13)

`cfg.py 0x8DABD0 0x1EA0` gives:

```
0x8DBCD3:  <- 0x8DB6EB(taken), 0x8DBCCD(fall)
   edi = [esp+0x18]                     ; this
   edx = this->unit (+0x64)
   eax = unit->plan.ops_area_count (+0x21C)
   test eax,eax ; jg 0x8DBCFB
0x8DBCE4:  <- 0x8DBCE2(fall)
   eax = this->+0x94 - this->+0x90      ; the agent's own ops-area vector, in bytes
   test eax,0xFFFFFFFC ; jle 0x8DBE3E   ; -> skip the first post
0x8DBCFB:  new 0x78 ; CSetPlanOpsAreaCommand(cmd, unit, &[esp+0x7C])   ; 0x8DBD1F
           post it: GetCurrentGameState()->+0xBE8, slot 18, ->+0x38, slot 6   ; 0x8DBDBF-0x8DBDCF
           free CArmy +0x2EC; CopyObjectiveList(&army->+0x2EC, &unit->+0x234) ; 0x8DBE32
           CAIUnit::ReplanSubtree                                             ; 0x8DBE39
0x8DBE3E:  <- 0x8DBCF5(taken), 0x8DBE39(flow)
```

**`0x8DBE3E` has exactly two predecessors, and one of them is the fall-through out of the first post.** So the first post does not return; control continues into the teardown. That is the question the record could not close by reading jumps, and the edge list closes it.

### The list is provably empty at the second post

* `0x8DBE3E`–`0x8DBE56` frees every node of the `CList` at `[esp+0x7C]`.
* `0x8DBE58`–`0x8DBE70` frees every node of a second list at `[esp+0x68]`.
* `0x8DBE72`–`0x8DBE86`: `xor esi,esi`, then `[esp+0x7C] = 0`, `[esp+0x80] = 0`, `[esp+0x84] = 0`, `byte [esp+0x88] = 0` — head, tail, count and the trailing byte. **The list is empty.**
* `0x8DBE92`–`0x8DBEAC`: `std::vector::erase` (`0x4440B0`) over the agent's own ops-area vector at `+0x90`.
* `0x8DBEB4`: `cmp [unit->+0x21C], esi` with `esi` still zero — nothing between `0x8DBE72` and here writes it, and `0x4440B0` is a `__fastcall` that preserves the non-volatiles. So the guard is `unit->plan.ops_area_count > 0`.
* `0x8DBEC0`: `new 0x78`; `0x8DBEE1`: `lea edx,[esp+0x7C]` — **the same stack slot, now zeroed**; `0x8DBEE8`: the constructor. Between the zeroing and this `lea`, nothing writes `[esp+0x7C]`, `+0x80` or `+0x84`.
* `jmp 0x8DC8CF` into the shared epilogue, which posts `[esp+0x30]` through the same channel at `0x8DC956`–`0x8DC970`. `0x8DC977` is reached both from `0x8DBEBA(taken)` (guard false, nothing posted) and from `0x8DC972(flow)` (posted), so the post is genuinely conditional.

`CSetPlanOpsAreaCommand`'s `+0x74` byte is left zero by the constructor (`0x5E616B`), so `Execute` takes the `CUnitPlan::SetOpsArea` arm, not `SetFallbackLine`. An empty list through `SetOpsArea` is an empty ops area.

### Why the two readings are one behaviour

The second post's guard, `count > 0`, is a **strict subset** of the first post's guard, `count > 0 || the agent's vector is non-empty`. So:

* the second post can **never** happen without the first;
* whenever it happens, it executes after the first (same channel, FIFO);
* its payload is necessarily empty.

Therefore the second post's only possible effect is to undo the first, and the net result on the fallback path is the same in both readings: **a unit the AI could not find a front for ends the hour with an empty ops area.** If the fallback collected provinces, the first command sets them and the second clears them; if it collected none, both clear. The first post is dead work in every case.

What the bytes cannot say is whether the author meant that, and they do not need to: the two "possible readings" the record left open were two guesses about intent, not two behaviours. **No live observation is needed to settle what the game does.** If you still want intent: the fact that the first post's work is always discarded, and that `ReplanSubtree` runs twice for nothing, reads as a bug rather than as a deliberate clear — but that is an aesthetic judgement and is marked as one. The main path is unaffected; it posts once, at `0x8DC747`, and jumps straight to the epilogue.

## 4. `CSubUnit` slot 9 answers true for a brigade and nothing else

`FINDINGS-combatmods.md` records "slot 9 true is land, false is a ship or wing" as **inferred** from the field set. It is right, and it can be read directly.

### The vftables

```
slot   CSubUnit    CRegiment   CShip       CWing
  9    0x592360    0xA92590    0x592360    0x592360
 10    0x592360    0x592360    0xA92590    0x592360
 11    0x592360    0x592360    0x592360    0xA92590
```

`0x592360` is `xor al, al; ret` and `0xA92590` is `mov al, 1; ret`. So slots 9/10/11 are the **land / naval / air predicate triple**: the base answers false to all three and each derived class replaces exactly one with true. `CSubUnit` has **exactly three subclasses** in the RTTI export — `CRegiment`, `CShip`, `CWing`, with no deeper chain — so the matrix is exhaustive. **Slot 9 is true for a `CRegiment` and false for a `CShip`, a `CWing` and a bare `CSubUnit`.**

Both bodies are compiler-folded stubs and must not be named after a class (trap 4): `0x592360` sits in **836 slots across 407 classes** and `0xA92590` in **440 across 259**. The information is in the pattern, not the body.

*The positive control, and it is independent:* the `CUnit` family repeats the same shape at **slots 15/16/17** — `CUnit` holds `0x592360` at all three, `CArmy` replaces 15, `CNavy` 16, `CAir` 17 — and the record already names `CUnit`'s land predicate (slot 76 and slot 78 both call `unit->isLand()`). A method that reproduces a predicate triple the record arrived at another way, on the family one level up, is a method whose answer about `CSubUnit` can be believed. The reading is also a cross-check on the folded bodies: a "false at three slots on the base, true at exactly one on each of three derived classes" arrangement cannot arise by folding accident.

### Correction: the block is not in `CCombatant::ApplyLosses`

`TRAPS.md`'s trap 3 table and `FINDINGS-combatmods.md` both put the `CSubUnit +0x54` read at `0x56645E` inside `CCombatant::ApplyLosses` (`0x565FD0`), past that function's `ret 4` at `0x566452`. **The `ret 4` at `0x566452` is not `ApplyLosses`'. It belongs to a different function.**

```
0x5662ED   ret 4                      <- CCombatant::ApplyLosses ends here
0x5662F0   push ebp                   <- a fresh prologue, no int3 between them
0x5662F1   mov ebp, esp
0x5662F3   sub esp, 0x14
```

`0x5662F0` is **`CCombatant` slot 11**, held at slot 11 by `CCombatant` and six subclasses (`CAirCombatant` `0x15C4E74`, `CBomberCombatant` `0x15C45DC`, `CCombatant` `0x15C4CA4`, `CGroundTargetCombatant` `0x15C464C`, `CLandTargetCombatant` `0x15C472C`, `CNavalCombatant` `0x15C4D8C`, `CNavalTargetCombatant` `0x15C46BC`), with one direct caller at `0x568EE8` inside the pass-through `0x568EE0`. Its `this` is in **ECX**, not EDI, and it takes one stack argument — `project.json`'s own signature for `ApplyLosses` says `combatant@EDI`, which is a second, independent reason the two cannot be one body. The `ret 4` at `0x566452` is slot 11's, the cold block at `0x566455` is slot 11's, and `cfg.py 0x5662F0 0x190` gives `0x566455 <- 0x566361(taken)` — exactly one predecessor, the slot-9 branch — and `0x566420 <- 0x566475(jmp)`, where the cold block rejoins the hot path. **Trap 3 still applies; it applies to a different function. Trap 2 was sitting inside trap 3's worked example.** `project.json`'s instruction entries at rva `0x166361` and `0x16645E` are correct as addresses; only the prose owner was wrong, and both have been corrected.

For the record, `0x566267` (`CCombatant_LossAccounting` in `project.json`) *is* inside `ApplyLosses`: it reads `CSubUnit +0xA8` and `+0x5C` and writes `CCombatant +0x88`.

### What slot 11 computes, and the `+0xF4`/`+0xF8` question

```
int* __thiscall CCombatant::<slot 11>(CCombatant* this, int* out)
  *out = 0
  for (unit in this->units (+0x40))                 ; a CList<CUnit*>, already named
    for (sub in unit->regiments (+0x38))
      w = sub->organisation (+0x60) * sub->strength (+0x5C) / 1000        ; 0x56633C
      if (sub->vf[9]())                                                   ; 0x566356-0x566361
        defn = sub->+0x58
        attackSum = defn->hard_attack (+0x138) + defn->soft_attack (+0x134)
        m = unit->combat_defend_modifier_b (+0xF8) * unit->combat_defend_product (+0xF0) / 1000
        m = (unit->combat_attack_modifier_b (+0xF4) * unit->combat_attack_product (+0xEC) / 1000) * m / 1000
        base = this->is_attacker (+0x38) ? defn->toughness (+0x120) : defn->defensiveness (+0x11C)
        r = (base + attackSum) * 1000 / 10000                             ; = (base + attackSum) / 10
        if (r > 1000) m = m * r / 1000
      else
        sub->vf[10]()                   ; result discarded - see below
        m = sub->combat_defend_product (+0x54) * sub->combat_attack_product (+0x50) / 1000
      *out += w * m / 1000
  return out
```

`0xB99AF0` is `__allmul` and `0xB99980` is `__alldiv`, both already `confirmed` in `project.json`, which is what fixes the `x * 1000 / 10000` reading. Three things follow:

**Both arms multiply the attack side by the defence side.** The land arm uses all four of `CUnit +0xEC`, `+0xF0`, `+0xF4`, `+0xF8` — `(attack x attack_b x defend x defend_b) / 1000³` — and never touches the sub-unit's own `+0x50`/`+0x54`. The naval/air arm uses `(+0x54 x +0x50) / 1000` on the sub-unit and never touches the `CUnit` fields. So for this function, `+0x50` and `+0x54` on a ship or a wing are a **product pair, used together**, and the defence-side sub-unit modifier is not inert here on any reading. That is the direction `FINDINGS-combatmods.md`'s concern resolves in.

**`CUnit +0xF4`/`+0xF8` are not doing anything exotic here.** `FINDINGS-combatmods.md` notes them as the amphibious-invasion interpolation pair; in this arm they are plain second multipliers paired with `+0xEC`/`+0xF0`, which is what `project.json` already calls them ("the other attack multiplier" / "the other defend multiplier"). Both uses can be true — the same field written by one mechanic and read by another — but **nothing amphibious is involved at this site.**

**The two arms are not commensurable.** A brigade's contribution carries an extra `(defensiveness + soft_attack + hard_attack) / 10` factor whenever that figure exceeds `10.000`; a ship's or a wing's carries no attack-value term at all. Whether that is intended is outside what the bytes say; it is recorded because anyone using this function's output to compare a fleet against an army will be comparing different quantities.

**And the cold block opens with a call it throws away.** `0x56645C` is `call edx` on `[vftable+0x28]` — **slot 10**, the naval predicate. The very next instruction, `0x56645E`, overwrites `eax` with `[esi+0x54]`. Slot 10 is the folded `ReturnFalse` on `CSubUnit`, `CRegiment` and `CWing` and the folded `ReturnTrue` on `CShip`, so neither body has a side effect: **the call does nothing whatsoever.** It reads like the residue of an `if (isLand()) ... else if (isNaval()) ... else ...` whose third arm was folded away, or of an assertion; either way a mod hooking this site should know the dispatch is there and is inert.

### Which combat kinds, then

"Combat kind" is the wrong axis, and this is the part of the old note worth replacing. The branch is per **sub-unit class**, not per combat: a `CLandCombatant` whose front line includes an air unit will run the cold block for that unit's `CWing`s, because slot 11 walks every `CUnit` on `units` and every sub-unit on each unit's `regiments`. The hot block runs for brigades; the cold block runs for ships and wings, wherever they appear.

## Corrections to the existing record, collected

| file | what it said | what it should say |
| --- | --- | --- |
| `TRAPS.md`, trap 3 table | `CCombatant::ApplyLosses 0x565FD0`, `ret` at `0x566452`, the `+0x54` branch at `0x566455` past it | the `ret 4` at `0x566452` and the block at `0x566455` belong to **`CCombatant` slot 11, `0x5662F0`**, which abuts `ApplyLosses`' own `ret 4` at `0x5662ED` with no padding. Trap 3 holds, for that function. `0x565FD0`/`0x5662F0` is a new entry for trap 2's known-pairs list |
| `FINDINGS-combatmods.md` | the `+0x54` reader is in `ApplyLosses`' per-sub-unit loop | same correction; also, the site multiplies `+0x50` by `+0x54`, so neither is a one-sided value there |
| `FINDINGS-combatmods.md` | "slot 9 true is land, false is a ship or wing" — **inferred** | **confirmed**, out of the slot 9/10/11 matrix over `CSubUnit`, `CRegiment`, `CShip`, `CWing` |
| `FINDINGS-aiplans.md` | "I found nothing in the AI that branches on `priority`" | one instruction does, `0x89871A`, in the generator's own dirty check; nothing weights by it. The four UI bodies named as the gap do not touch a `CObjective` |
| `FINDINGS-aiplans.md` | `CCountry +0x4A8` unexplained | it is `CAIStrategy +0x1C`, `conquer_prov`, because `CCountry +0x48C` is the embedded strategy |
| `FINDINGS-aiplans.md` | "whether the fallback's second command is a bug — one game settles it" | the behaviour is settled statically: the second post's guard is a strict subset of the first's and its payload is provably empty, so the fallback always ends with an empty ops area. Only the intent is open, and the image cannot speak to intent |
| `FINDINGS-weather.md` | the weather advance is "two calls, both out of `RunHourlyPass`, and nowhere else" | `CWeatherManager::Tick` has three callers: `RunHourlyPass` `0x6826F3`, a loop in `CInGameIdler::Enter` `0x65C86A` (the pre-roll), and `0x43DC89` |
| `FINDINGS-weather.md` / `FINDINGS-weatherfront.md` | `CWeatherManager +0x14`: "nothing was found that sets it" | nothing **does** set it — one instance in the image, all eight `[reg+0xB00]` instructions accounted for with zero raw occurrences outside the decode, the complete receiver set enumerated, and no save key |
| `project.json` | `CWeatherManager +0x14` comment: "What sets it was not established" | nothing sets it; the only write is `CGameState::CGameState` at rva `0x27D1D9` seeding it to zero |

## A new trap worth numbering

**The inlined lazy singleton reads as a constructor.** `if (!g_CCurrentGameState) { new 0xDA8; CGameState::CGameState(p); p->vftable = 0x15CF674; p->+0xD9C = p->+0xDA0 = p->+0xDA4 = 0; release the old; g_CCurrentGameState = p; }` is inlined at `0x8976E0`, `0x8DBD3B` and `0x8DC8E0` among others. Finding it mid-function and reading it as "this function builds a game state" mis-identifies the body; it is `GetCurrentGameState()`. The guard is the `test r,r; jne` a few instructions above the `new`.

## What is not established

1. **Where `CEU3AI +0x118`'s province ids come from.** `0x8976E0` rebuilds the list every AI pass, traced as far as the owner's faction member list (`CFaction +0x28`), a `CCountry +0xACC` byte filter, and a per-index vector of `0x14`-byte records on **`CGameState +0xBAC`**, which is unnamed. Naming that field would finish it.
2. **`CCountry +0xACC`**, the byte `0x8976E0` tests on each faction member at `0x8977BB`. Position suggests something war-related (`+0xAC8` is `last_surrender`, `+0xAD0` is `war_exhaustion`) but it was not read.
3. **Whether `CSetPlanObjectivesCommand`'s own list field is ever read at `+0xC` outside its constructor and `LoadKey`.** The two-level call closure covers it, but `CSetPlanObjectivesCommand::Execute` was not read line by line.
4. **The name of `CCombatant` slot 11.** The arithmetic is read and the slot is confirmed; the name in `project.json` is descriptive of the arithmetic and is marked `likely` for that reason. What consumes its result — `0x568EE0`'s callers — was not followed.
5. **Why the cold block calls slot 10 and discards the answer.** Read, not explained.
6. **Whether slot 11's land and naval arms being on different scales is a bug.** Outside what the bytes say.
7. **6.7% of non-padding `.text` was reached by neither decode.** For `CWeatherManager +0x14` that gap is closed by the raw-byte cross-check (zero occurrences of the `disp32` outside the decode). For `CObjective::priority` it is closed differently — by reachability: a `CObjective*` can only arise in the seven bodies that write its vftable, and the two-level call closure of those is 219 functions, every one of which is a call target and therefore decoded. There is no equivalent byte-level check for a `disp8` of `0x0C`, so the reachability argument is what the negative rests on.
8. **Nothing was watched in a running game.** Three cheap live checks, in order of value: an AI objective's `priority` should be a multiple of 20 plus 0 or 100 unless the country's `conquer_prov` contributed; a land unit under AI control with an ops area and no reachable objective should be found with an **empty** ops area after the hour (item 3's prediction); and `CGameState +0xB00` should read 0 at every moment of every session (item 2's prediction — if it is ever 1, everything in section 2 is wrong).

---

# Five more claims that rested on writers only

Wave 13 agent D, 2026-10-05. Addresses are **rvas** where labelled and otherwise virtual, based
`0x400000`. Nothing here needed the game running; two of the five are settled by the savegame.

## 5. `CDiplomacyStatus +0x59 changed` - no reader exists, and two of the record's own facts were wrong

### The census

Not a scan for the displacement but the **complete universe** of it. `.text` split on runs of `int3`,
each chunk decoded from its own start - so no linear sweep (trap 9) and abutting functions are decoded
through rather than lost (trap 2) - collecting every instruction with a memory operand at displacement
`0x59` on a base register other than `esp`/`ebp`.

**60 sites in the whole image. 52 stores, 7 loads, 1 `lea`.**

### The positive control, in its strong form

The same census finds **every writer the record already names**: `0x4E65D8` and `0x4E660B` in
`CCountry::ChangeRelation`, `0xA46DDF`/`0xA46E05` in `CGuarantee::Activate`, `0xA47CB3` in
`CCasusBelli::Activate`, and so on. A method that sees all of the known writes of this exact byte at
this exact offset is a method whose silence about reads means something.

### The readers

There are none. All eight non-stores belong to other classes:

| site | owner |
| --- | --- |
| `0x547B9A`, `0x548145`, `0x5483EF` | `CCreateUnitCommand` - the cluster `0x547870` (ctor) / `0x547930` / `0x547FB0` / `0x548180` (LoadKey) / `0x5483B0`, whose ctor writes vftable `0x15C36D4` |
| `0x6D8060`, `0x6D822D`, `0x6D8362` | the `CSetRandomSeed`/`CPauseGame` command family, ctor vftable `0x15D3434` |
| `0x8364D2` | a refcounted SEH object (`dec [edi+0x5c]` right after) |
| `0xAF8DD0` (`lea`) | an MD5/SHA-style padding buffer in the save-stream code |

Three blind spots closed separately: an indexed `[reg+reg*n+0x59]` has three hits, all garbage decodes
(`ror byte`, `fcomp`) in chunks with no `0xE28`; a word or dword load spanning byte `0x59` has 34 hits
at disp `0x58`, every one a 32-bit pointer walk on another class (`CDiplomacyStatus +0x58` is a
recorded `uint8_t`); `movzx`/`cmp byte` at `+0x59` is inside the census and produced none on a status.

One census hit is a false positive and worth recording: `add byte ptr [edx+0x59], dl` at `0x4E608B`
sits inside `CDiplomaticAction::Create`'s **embedded jump table**.
`image.retsBefore(0x4E5800, 0x4E608B)` returns 25 `ret`s, which says so loudly. **A chunk-based decode
desynchronises on a jump table in `.text`**; the cheap tell is a nonsense mnemonic plus a loud
`retsBefore`.

### Two corrections to the record

**(a) It is six of the nine `CRelation::Activate` bodies, not seven. `CTradeRoute::Activate` does not
set it either.** There is no `[reg+0x59]` instruction anywhere between `0xA4AB48`
(`CInfluence::Activate`) and `0xAF8DD0`, so the census excludes `CTradeRoute::Activate`'s *whole body*,
not just the part a bounded decode reaches. The three that do not set it are **CAlign, CEmbargo and
CTradeRoute**. Per-body counts, each decoded from its entry:

| Activate | rva | `+0x59` writes | materialises `g_CCurrentGameState` |
| --- | --- | --- | --- |
| CAlliance | 0x646A40 | 2 | yes |
| CGuarantee | 0x646DB0 | 2 | no |
| CNap | 0x6471E0 | 2 | yes |
| CDependency | 0x647760 | 2 | no |
| CCasusBelli | 0x647BB0 | 1 | yes |
| CInfluence | 0x64AAD0 | 1 | yes |
| **CAlign** | 0x64B110 | **0** | yes |
| **CEmbargo** | 0x64B530 | **0** | yes |
| **CTradeRoute** | 0x64D2C0 | **0** | no |

**(b) "Why those two differ" has no answer, because the premise is wrong.** It is three bodies, not
two, and the table above kills both candidate rules: materialising the game state does not separate
them (four setters do it, two setters do not, and `CTradeRoute` does not either), and
one-direction-versus-both does not (`CEmbargo` writes `+0x34` on both sides and sets nothing;
`CInfluence` writes one side and sets it). With no reader, the three omissions have no consequence in
either direction. No rule was found, and that is said rather than a rule invented.

**(c) "eleven writers" was a count of nothing in particular.** There are **37 store sites on a
`CDiplomacyStatus`** - the stores whose chunk carries the disp32 `0xE28`, which is the only route to a
status - across about eighteen functions: `CCountry::ChangeRelation`, the six Activates,
`CCountry::UpdateUndeclaredWars`, `CCountry::AfterLoad`, `CCountryEventEffect::Execute`,
`CDiplomacyStatus::LoadKey`'s neighbourhood, `FindMatchingTradeRoute`, and several command `LoadKey`s.
The chain is explicit at most sites, e.g. at `0x4D72E1`:
`mov eax,[edx+0xe28]; mov ecx,[eax+ecx*4]; cmp [ecx+0x38],0; ... mov byte [ecx+0x59],1`.

**(d) Two helper setters nobody had**, both on the frontier:

- **`0x64A400`** - `__stdcall f(CDiplomacyStatus* status, bool flag@CL)`, `ret 4`. First two
  instructions: `status->+0x59 = 1; status->+0x4C = cl`. Then, lazily materialising
  `g_CCurrentGameState` and **only if its `in_game` byte at `+0xDA4` is set**, it ORs `0x100` into
  `[state->+0xBE8]->+0x84` - it marks the interface for refresh. **So the GUI refresh is done by the
  writer, not by any reader of this flag**, which is what makes `+0x59`'s deadness believable rather
  than suspicious. The hourly country passes call it.
- **`0x64A3B0`** - whose *first instruction* is `mov byte [edi+0x59], 1`, followed by freeing the
  casus-belli list and zeroing `+0x3C`/`+0x40`/`+0x44`. A register-argument `ClearCasusBelli`.

The name `changed` is kept. It describes the writers and nothing can falsify it further; a body with
no consumer offers no better name.

## 6. `surrender_progress` - **1000 means on the brink**, and the recorded arithmetic was upside down

### The divisor, `0xFCC60`, read end to end

Receiver in **EAX**, out pointer in **EDI**, no stack arguments, three bare `ret`. 43 instructions.

    owned = this->+0xBE0
    if (owned <= 0)  { *out = 0; return out }       ; 0x4FCCDF arm
    held  = this->+0xBE4
    *out = 1000 - clamp(held * 1000 / owned, 0, 1000)

The `jne` at `0x4FCC6D` and its `or eax,-1` arm are **dead**: the `jle` above already took everything
`<= 0`.

### What the two fields are - and they are new names

Both are written **only** by `CCountry::RebuildNeighbours` (rva `0xE21E0`): zeroed with that
function's counter block at `0x4E2305`-`0x4E2323`, then accumulated in one loop over the province-id
list at `CCountry +0xD10` at `0x4E3030`-`0x4E307E`:

    prov = gameState->+0xB8C[node->id]
    if (prov->owner.id      (+0x330) == country->id)  country->+0xBE0 += prov->victory_points (+0x34) * 1000
    if (prov->controller_id (+0x338) == country->id)  country->+0xBE4 += prov->victory_points (+0x34) * 1000

- **`CCountry +0xBE0` = `claimed_victory_points_owned`** (thousandths)
- **`CCountry +0xBE4` = `claimed_victory_points_controlled`** (thousandths)

So `0xFCC60` is **the share of the country's own claimed, owned victory points that it does not
control** - the occupied fraction of its national territory, in thousandths. Named
`CCountry::GetOccupiedVictoryPointShare`.

Trap 12 applies hard here: other classes carry fields at the same offsets (`CInGameIdler::Enter` and
`CGameState::LoadKey` write a `+0xBE0`; `CGameState` writes `+0xBE4` with `movss`, i.e. as a float).
The chain was taken through `RebuildNeighbours`, not off the displacement.

### The correction to `0xFCB80`

The recorded pseudocode read `v = national_unity * 1000 / 100000; v = v * 1000 / <0xFCC60's answer>` -
**unity in the numerator and `0xFCC60` in the denominator.** The bytes do the opposite.
`lea edi,[ebp-4]` at `0x4FCBBC` makes `[ebp-4]` the out slot handed to `0xFCC60`, and the
`__allmul`/`__alldiv` pair at `0x4FCC18`/`0x4FCC30` takes **`[ebp-4]` as the operand** and **`esi`
(the unity quotient computed at `0x4FCBE9`-`0x4FCC0B`) as the divisor**. Corrected:

    if (government_in_exile (+0x95))            *out = 0
    elif (province_count (+0xD08) == 0)         *out = 1000
    else { unity = national_unity (+0x10B8) * 1000 / 100000      ; i.e. /100, so 10..1000
           if (unity == 0)                      *out = 1000      ; shares the +0xD08 exit
           else *out = clamp(0xFCC60(this) * 1000 / unity, 0, 1000) }

Everything the old entry concluded about direction followed from the inversion. It said *"the main arm
rises with unity, which reads as 'how far from surrendering' rather than 'how close'"*. With the
fraction the right way up the main arm **falls** with unity. **High = about to surrender.**

Four corroborations, deliberately independent of each other:

1. the `province_count == 0` arm - no provinces left at all - answers the **maximum**;
2. the numerator rises as territory is occupied and the denominator falls as unity falls, both of which
   are the country losing;
3. `CAIUnit::EstimateTheatreNeed` reads the same two fields at `0x4B99FF` as
   `owned - controlled >= 0x7D0` (2 victory points) to conclude a country is losing real ground;
4. **the mod.** `decisions/l'ordre_nouveau_en_europe_decisions.txt` lets Germany open peace talks with
   the USSR on an ascending ladder - `SOV = { surrender_progress = 72 }`, then 74, 76, 78, 80, 82, 84,
   90, 95 - each paired with a rising `soviet_desperation`; and `decisions/scorched_earth_decision.txt`
   unlocks `sacrifice_the_homeland` at 0.25 (democracy) / 0.15 (fascism) / **0.05** (communism). Both
   read the same way round. Across the 58 uses in the mod the distinct values are 0.05 ... 95, and the
   three ladders all point the same way.

### Two things worth telling a mod author

- **`surrender_progress = 0.05` is not "always true"; it is "any loss at all".** With nothing occupied,
  `held == owned`, `0xFCC60` answers 0, and the trigger's `progress/10 >= 0.05` is false. It fires the
  moment the occupied share exceeds about 0.05% of the national victory points, scaled up as unity
  drops.
- **It is a measure of occupied *claimed* territory, not of territory.** When the list at `+0xD10`
  holds no province the country owns, `+0xBE0` is 0 and `0xFCC60`'s first arm answers **0** - so
  `surrender_progress` is 0 however much has been lost. Any mod-made country with an empty claims list
  can never surrender by this measure.

### Housekeeping that fell out of this

- **The prose was right and the entry was wrong**, which is trap 14's fourth question running the
  *opposite* way: `findings/FINDINGS-invasion.md` line 281 has the arithmetic correct
  (`clamp(0x4FCC60(this) * 1000 / (this->+0x10B8 / 100), 0, 1000)`, where
  `0x4FCC60(this@EAX, out@EDI)` is `1000 - clamp(this->+0xBE4 * 1000 / this->+0xBE0, 0, 1000)`) and
  `project.json` has it inverted. **Trap 14 says the entry is the likelier of the two; that is a
  tendency, not a rule, and it now has a counterexample.**
- `FINDINGS-invasion.md` also says `0xFCB80` has *nine* callers and `project.json` says *one*.
  `findRefs` agrees with `project.json` for direct calls. The nine in the invasion prose look like
  callers of something else. Not chased.
- **`0xFCB80` carries two names from two halves of the fact base.** The generated record has rva
  1035136 (= `0xFCB80`) as **`CCountry::GetSurrenderLevel`**, `CERTAIN`, recovered from the luabind
  registration (`CFixedPoint GetSurrenderLevel(CCountry const&)`). That is the **engine's own name**,
  and it is why the entry was raised to `confirmed`. Deliberately **not** renamed, because the
  keyword-derived name is referenced from `FINDINGS-numtriggers.md` and the trigger's own entry - but
  if one name is wanted, `GetSurrenderLevel` is the one with provenance. The inverted pseudocode had
  propagated into the generated record too; since `buildFindings` writes that file, fixing
  `project.json` fixes both.
- Also newly named: **`CCountry +0xD04` `province_ids_end`** and **`CCountry +0xD08` `province_count`**
  - the tail and count of the `+0xD00` list, from the triple zeroed at `0x4D4AC2`-`0x4D4ACE` and the
  append at `0x4DD215`-`0x4DD237`, with a one-instruction accessor at rva `0x1010C0`.

## 7. `check_variable`'s side effect - real, general, and **erased by the next save**

### What `0x76FB0` is

`CVariables::AddVariable`, `void* __stdcall (CVariables* variables@EDI, Hoi3CString* name, int value)`,
`ret 8`, 24 instructions. It asks `operator new` for **0x20 bytes** and lays out a variable:
`Hoi3CString` at **offset 0** (inline buffer zeroed, length `+0x10` = 0, capacity `+0x14` = 0xF - the
SSO shape), **value at `+0x1C`** from its second argument, the name assigned from its first, then an
insert through the registry's **slot 6** (`[[edi]+0x18]`, the object pushed twice). **It never looks
the name up first.**

The layout is confirmed twice over without reading this body: `CVariables::LoadKey` (rva `0x77080`)
writes the same four fields in the same order and fills the value through `TokenToFixedPoint`; and the
save walker hands the object straight to `SaveWriteNamedFixed(Hoi3CString* key@EAX, ...)`, which can
only work if the string is at offset 0.

### The side effect is not `check_variable`'s - it is the engine's

`findRefs --callers 0x476FB0` gives **six call sites in five functions**, and they are the whole of how
a script variable comes into existence:

| caller | what it does |
| --- | --- |
| `CVariableTrigger::Evaluate` rva `0x5F01D0`, at `0x5F0237` | `check_variable`: find; on a miss `AddVariable(&this->name, 0)` and answer `0 >= value` |
| `CSetVariableEffect` **slot 11**, rva `0x5AF7A0`, at `0x5AF7FE` | `set_variable`: find and write `+0x1C` in place; create only when the name is new |
| `CChangeVariableEffect` **slot 11**, rva `0x5AF810`, at `0x5AF874` and `0x5AF8C6` | `change_variable`: read, add `this->+0x3C`, write back - so on a new name it calls `AddVariable` twice, the second lookup now succeeding and updating in place, so still one object |
| `CSetVariableCommand` **slot 6**, rva `0x1532C0`, at `0x553313` | the same find-or-create, as a `CCommand` |
| `CVariables::GetValue` rva `0x76F60`, at `0x476F8E` | the generic accessor - **and it has no callers at all in this build** |

Both slot bodies attributed with `vtable.py --holding`: one table each, so no fold. **No caller leaks**:
every one has `test eax,eax; je <create>` straight after the slot-1 lookup, so `AddVariable`'s own
overwrite-and-leak behaviour (`TernarySearchTreeInsert` overwrites a duplicate payload and still
increments the count - already in its record) is never reached. That was checked specifically because
the opposite would have been a measurable drip.

`CVariables::GetValue` is recorded anyway, because it is the clearest statement of the intent: **in
this engine, reading a variable is what brings it into existence.** The trigger is not doing anything
unusual.

### Does it persist into the save? No - and here is the mechanism and the control

`CCountry::SaveContents` writes key `0x411` (`variables`, token 1041) at `0x4CFE2D` and calls slot 1 of
the object at `country+0x1D0` - the second-base adjustment, `CVariables` sitting at `CCountry +0x1AC`
as a tree and at `+0x1D0` as a `CPersistent` (`lea esi,[edi+0x1d0]` at `0x4CFE1D`; the ctor writes
`0x15BD700` to `+0x1AC` and `0x15BD724` to `+0x1D0`). That reaches `CPersistent::Save` -> slot 2 =
**`CVariables::SaveContents`** (rva `0x77060`), which is the whole of
`add ecx,-0x24; if (this->root) 0x77000(writer, root)`.

**`0x77000` is where the answer is.** `CVariables::SaveSubtree`,
`void __thiscall (CVariables*, CSaveWriter*, CTernaryNode*)`, `ret 8`, 36 instructions, an in-order
walk:

    for (node; node; node = node->high (+0xC)) {
        if (node->low (+8))     recurse(node->low)
        v = node->element (+0)
        if (v && v->value (+0x1C) != 0)          <<<< 0x477028: mov eax,[eax+0x1c]; test eax,eax; je
            SaveWriteNamedFixed(v, writer, v->value)
        if (node->equal (+0x10)) recurse(node->equal)
    }

**A variable whose value is exactly zero is skipped.**

The save corpus, with a control: across **45 saves and 4,815 `variables={}` blocks, 754 distinct
variable names appear and not one of them is ever `0.000`** - while the same parse happily finds
negatives (`Allies_Axis_help=-1.000`, `chromite_MaxSells=-2.000`, `aluminium_MaxSells=-4.000`), so the
writer is not dropping non-positives in general, it is dropping exactly zero, which is what the
`test`/`je` says.

**So the mod-facing consequence is narrower than the record implied.** The side effect is real - the
variable exists in the country's registry for the rest of the session - but it is **session-scoped and
self-erasing across a save/load**, it cannot accumulate, it cannot be observed from outside the
process, and it cannot change any answer (`check_variable` treats a missing name as zero anyway). The
one real cost is a `0x20`-byte allocation per `(country, never-set name)` per session, bounded because
the next lookup succeeds. The same holds for `set_variable = 0`: it exists in the tree and then
vanishes at the save, which is behaviourally identical to being absent.

### And one correction to the fact base that fell out of it - the ternary tree's links

Reading both halves of the tree to settle the save order gave a confirmed correction to
**`CTernaryNode`**, whose field names came from `BiceLib/GameClasses/CFlags.hpp` (whose own comment
admits "what the tree means by each link has not been worked out"):

| offset | was | **is** |
| --- | --- | --- |
| `+0x0` | `element`, type `undefined4` | `element`, type **`void*`** |
| `+0x8` | `parent` | **`low`** - keys whose current character sorts below this node's |
| `+0xC` | `sibling` | **`high`** - keys whose current character sorts above |
| `+0x10` | `child` | **`equal`** - the next character of a key that matched, the only link that advances the key |

Read off `TernarySearchTreeFind` (VA `0xA7E030`, 25 instructions: `sub eax,ecx`; `jne` ->
`lea esi,[edi+0xc]`; `test eax,eax; jg` keeps `+0xC`, falls through to `lea esi,[edi+8]`) and
`TernarySearchTreeInsert` (VA `0x44DA70`, 44 instructions, the same test mirrored at
`0x44DAEA`-`0x44DAF6`, node `0x14` bytes from `push 0x14`, all three links zeroed at
`0x44DAAE`-`0x44DAB4`). Third witness: `CVariables::SaveSubtree`'s low -> payload -> equal -> high
order, and **every `variables={}` block in all 45 saves is alphabetical**.

**This is trap 14 again, and the fixable half of it was walked into.** `TernarySearchTreeFind`'s own
`project.json` comment already states the layout word for word - *"Node layout
`{void* value; char key; Node* low; Node* high; Node* equal;}` at +0, +4, +8, +0xC, +0x10"* - and
already states *"The comparison is case-insensitive"*. Both were re-derived. The genuinely new thing is
that the **struct half of the record disagreed with the function half**, with the function right. A
`grep` for "TernarySearchTree" before reading would have saved the derivation and still left the
correction standing. **`CFlags.hpp`'s NodeOffsets block needs the same three renames**, since the
headers are a third of the fact base.

A free mod-facing fact from the same read: **variable names are case-insensitive.** Both the insert and
the find fold the key byte through `tolower` (`0xB96692`) and only the insert stores the folded form,
so `check_variable = { which = BaseIC }` and `which = baseic` are the same variable. That is the exact
opposite of section 8.

## 8. `remove_brigade` - every regiment has a name, so a type token can never match

### What an unnamed regiment holds in `CSubUnit +0x68`: there is no such thing

Every `regiment={}` block in the 45 saves was parsed and its **depth-1** `name=` collected (depth-1 so
a nested block's name cannot be miscounted):

- **788,880 regiment blocks. 788,880 of them carry a `name=`. Zero missing, zero empty.**
- 30,600 distinct names.
- **290,876 instances (7,133 distinct)** carry an engine-generated name of the shape
  `<ordinal> <abbrev> Regiment` - `1st HQ Regiment` (3,208), `2nd HQ Regiment` (3,054),
  `1st Art Regiment`, `1st Wagon Regiment`, `1st Mx-Sup Regiment` - matched with
  `^\d+(st|nd|rd|th) [A-Za-z-]+ Regiment$`.

So the engine generates a name for every regiment the order of battle did not name. `CSubUnit +0x68` is
always a non-empty string, and **never a subunit type token**. `remove_brigade = <a subunit type>` can
never match.

The earlier basis was weak and is now replaced: "a decode of `CSubUnit::SetType` found no write to
`+0x68`" is absence in one function. The savegame settles it positively instead. (A wing is a
`CSubUnit` too and carries its name here in the same way, so `remove_brigade` reaches air units as
well.)

**And the mod never tries.** Of the **6,132 distinct `remove_brigade` values** across **6,894 uses**,
**none** is one of the **1,427** subunit type tokens the mod's `units/*.txt` declare.

### Fifteen `remove_brigade` lines in the current mod are dead because of case

Since the comparison is case-sensitive (already in `CRemoveBrigadeEffect::Execute`'s record - memcmp
plus a length test), every value was checked against the mod's **own** declared regiment names rather
than against the saves, because the 45 saves are older than the mod tree and disagree with it for five
Japanese regiments. 69,344 distinct names declared in 122,510 declarations (both forms:
`regiment = { type = X name = "N" }` and the `<subunit_type> = { name = "N" }` form the OOB files also
use).

- matching exactly: **5,154 distinct / 5,887 uses**
- matching **only if case is ignored - therefore dead: 15**
- matching nothing at all, even ignoring case: 963 distinct / 992 uses

The fifteen:

| in the event file | the mod declares |
| --- | --- |
| `Kampfgruppe 1001 Nacht`, `Bock`, `Graf`, `Kempf`, `Knittel`, `Kummersdorf`, `Meyer`, `Mohnke`, `Nahring`, `Peiper`, `SS Polizei`, `Witt`, `von Luck`, `von Tettau` - all in `events/KampfGruppen.txt` | `KampfGruppe ...` in `history/units/GER/*.txt` (e.g. `history/units/GER/Bock.txt:5`) |
| `Thomas Mcguire` in `events/battlecommanders.txt:2740` | `Thomas McGuire` in `history/units/USA/thomas_mcguire_oob.txt:5` |

Fourteen are one systematic typo - `Kampfgruppe` for `KampfGruppe` - in a single file. Note
`events/KampfGruppen.txt:712` also has `brigade_in_combat = "Kampfgruppe Bock"`, which will have the
same problem if that trigger compares the same way; that trigger was not read.

The 963 that match nothing are a separate class of staleness, mostly `events/SpanishCivilWar.txt` -
e.g. `"1. 10a Milicia Falange"` appears in the whole mod exactly once, on its own `remove_brigade`
line, with no regiment ever declared under that name. Not audited individually; the count is an upper
bound because the declaration regex requires the `name=` inside the same brace group.

## 9. `CEffect +0x14` - live as a write, dead as a field

The family's base constructor is inlined everywhere and writes, in this order: `+8 = +0xC = +0x10 = 0`
(the `CList` base), **`mov byte ptr [reg+0x14], 0`**, `token (+4) = 0x18D`,
`mov word ptr [reg+0x1c], 0` (the `use_this`/`use_from` pair as one word), then the concrete vftable.
Worked example at `0x999D1E`:

    push 0x24; call operator_new
    mov [eax+8],edi / [eax+0xc],edi / [eax+0x10],edi
    mov byte ptr [eax+0x14], 0
    mov dword ptr [eax+4], 0x18d
    mov word ptr [eax+0x1c], di
    mov dword ptr [eax], 0x15f45a8

**So the record's claim is wrong in both halves of its statement of fact.**
`fragments/merged/effects.json`'s `slots_noted` and this document's own open list both said *"nothing
in the three destructors or in `CEffect::LoadKey` touches it"*. `CEffect::LoadKey` (rva `0x599CA0`) is
**where it is written - 41 times, once per switch case, the first at `0x999D35`** - and the width was
not known either: it is a **byte**, not a dword. The destructor half stands, and is useful:
`CEffect::~CEffect` (rva `0x59C540`) zeroes exactly `+0x8`, `+0xC` and `+0x10` at
`0x99C596`-`0x99C59B`, which is what proves the `CList` base is three dwords and that `+0x14` is
`CEffect`'s own rather than a fourth word of the list. (`+0x4` needs no new record: it is
`CPersistent::token`, and `0x18D` is the `none` token that 697 of 714 inlined constructors write.)

**And there is no reader.** The 247 distinct slot bodies held by the 109 RTTI classes whose name ends
in `Effect` were each decoded from the slot address - an entry by definition, so trap 2 cannot bite -
and every byte-sized `[reg+0x14]` collected: **44 sites, 41 of them `..., 0` in `0x599CA0` and the
other three the same initialisation with the zero in `al`/`cl`/`bl` (`0x99E277`, `0x9A26EE`,
`0x9AFF0D`). No byte read anywhere.**

**Positive control, same bodies, same scan.** Asked for `+0x1C` it returns 51 sites including
`mov byte ptr [ecx+0x1c], 1` in body `0x59CB50` and `mov byte ptr [esi+0x1c], 1` in body `0x59D4A0` -
precisely the two writers of `use_this` the record names - plus a dozen readers of the
`cmp byte ptr [edi+0x1c], 0` shape. Asked for `+0x18` as a dword it returns the single recorded writer
at `0x59B630` (`CEffect::LoadKey`'s common tail) and the recorded slot-6 reader at `0x416000`. The
method sees both writers *and* readers of the live bytes either side of this one.

A whole-image version was tried and discarded: `+0x14` chained to `+0x18` or `+0x1C` in the same
register matches **478** sites, nearly all `mov dword ptr [ecx+0x14], 0xf` - `Hoi3CString` capacity
initialisation. That is trap 12, and it is why the vftable chain is the right filter here.

Recorded as `CEffect +0x14` `unused`, `uint8_t`. It is a declared member rather than padding (a byte
with three bytes of slack before `keyword` at `+0x18`, exactly as `+0x1C`/`+0x1D` have two before
`+0x20`), but it is dead in this build and the name says only that. The bounded gap: the two places a
reader could still hide are `CEffect::GetBlockText` and the event-option dispatcher at rva `0x5BF3D0`,
neither of which is a slot body.

## What sections 5-9 skipped, deliberately

- The nine Activate bodies were counted and the three non-setters identified, but only `CGuarantee`,
  `CAlign` and `CEmbargo` were read instruction by instruction. The other six were decoded and
  scanned, not read.
- `CVariables::SaveContents` (rva `0x77060`) and `CVariables::LoadKey` (rva `0x77080`) are read and
  described inside other entries' comments but **not recorded as entries**, because they are slots 2
  and 4 of CVariables' *second* vftable (`0x11BD724`) and `project.json`'s `vftable_slots` is keyed by
  class with no way to say which of a class's two tables a slot number belongs to. Both are on the
  frontier, along with the two `+0x59` setters `0x64A3B0`/`0x64A400`, the CVariables destructor chain
  `0x76EA0`/`0x77100`/`0x771A0`/`0x771D0`, the `province_count` accessor `0x1010C0`, and the two
  non-diplomacy `+0x59` owners `0x4364B0`/`0x6F8D40`.
- The 963 `remove_brigade` values that match no declared name were counted, not audited.
  `events/SpanishCivilWar.txt` is where most of them are.
- `CCountry +0xA8C`'s and `+0x10B8`'s duplicate records, and the `0xFCB80` name collision between the
  two halves, are reported rather than changed.
