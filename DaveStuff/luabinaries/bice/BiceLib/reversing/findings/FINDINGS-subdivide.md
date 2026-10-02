# `CAIUnit` slot 83 — how an area is sliced, and the proof that nobody ever asks for it

`FINDINGS-setarea.md` found the mechanism by which a parent agent's operations area reaches its subordinates — slot 83 slices the area and writes straight into each child agent's `+0x90` — and then found that nothing dispatches slot 83, by one method with one control. This is that question attacked four more ways, and the scoring middle of slot 83 (`0x8C0D60`–`0x8C13A0`) read end to end.

Read statically off `hoi3_tfh.exe` on 2026-10-01; the game was not running, so nothing here is marked *seen*. Addresses are **virtual** (image base `0x400000`) unless written `rva`.

## In one line

Slot 83 is **unreachable in this build**, and the proof is now structural rather than statistical: `CAIUnit`'s vftable is the only one in the image that holds `0x8C0790`, it is the only table in the `CAIAgent` family that even *has* a slot 83 (`CAIAgent` and the five ministers have 73 slots, `CAIInvasion` 74, `CAIUnit` 90), and **the only references anywhere in the image to any of the 90 addresses inside that table are the two writes of its base — the constructor at `0x8AF56A` and the destructor at `0x8AFC51`** — so nothing takes the table, indexes it, or points into it. The one call site in the whole image whose convention matches slot 83's (`__thiscall`, no stack arguments, `bool` in `al`) dispatches on `CCurrentGameState +0xBE8`, the `CInGameIdler`, whose own slot 83 is the folded `ReturnFalse`. Meanwhile the body it guards is complete and coherent: per owner area the parent's ops area touches, it weighs each subordinate by its division count, apportions that owner area's province count among them by the **largest-remainder method with a carried fraction**, and grows each subordinate's slice one province at a time — contiguously, choosing at each step the province with the lowest **mean distance from the subordinate's own brigades** (`0x8C1FC0`), with `+1000` for a province another subordinate already took, `÷100` for a province that has only one neighbour inside the area, and `+500`/`+1000` for leaving the subordinate's own owner area.

---

## 1. How slot 83 is entered: a load-bearing negative

`FINDINGS-negatives.md`'s `CWeatherManager +0x14` section is the model here: a negative is only evidence if the same method finds a positive it was supposed to find. Five methods, each with its control.

| # | method | what it found for slot 83 | the positive control, and what it found |
| --- | --- | --- | --- |
| 1 | `vtable.py --holding 0x8C0790` over every vftable in the RTTI export | **one** holder: `CAIUnit` slot 83 | the same run for `0x592360` finds 836 slots in 407 classes, so the scan does see folds; `0x8C0550` is in **no** table, which is the complementary control |
| 2 | the four-byte value `0x8C0790` in **every section**, not just `.text` | **one** hit, `.rdata` `0x15EC200` = `0x15EC0B4 + 0x14C` | `0x8C0600` (slot 82) → `0x15EC1FC`, `0x8DABD0` (slot 76) → `0x15EC1E4`, `0x8C1790` (slot 84) → `0x15EC204`; `0x8C0550` and `0x8BE1C0`, which are called directly, → nothing |
| 3 | every `e8` call **and** `e9`/`eb` jump in `.text` resolved against the target | **0 calls, 0 jumps** | the same scan: `0x8BE1C0` → 10 callers, `CAIUnit::SetArea` → 5, `0x8BBB50` → 3, `0x8BD270` → 4, `0x8C0550` → 1 (`0x8C156C`). Every count matches the record |
| 4 | displacement `0x14C` over **the whole of `.text`** (`0x401000`–`0xD2B000`), not the `0x880000`–`0x8E0000` window | 30 dispatch-shaped sites, 464 other uses, **0 `call [reg+0x14C]`**, **0 `jmp [reg+0x14C]`** | the same scan at `0x148` finds all three known slot-82 dispatches — `0x8B099B`, `0x8BBA07`, `0x8DCAAF` — among 25 |
| 5 | every four-byte value in every section landing **inside** `0x15EC0B4`–`0x15EC218` | **2**, both `0x015EC0B4` itself: `0x8AF56A` and `0x8AFC53` | the same question for `CAIInvasion`'s table (`0x15EBAE4`, 74 slots) → 2, both its base, at `0x89F936` and `0x89F9BC` |

### Method 4, site by site

The scan's 30 dispatch-shaped sites are the same 30 `slotcalls.py 83` reports, now established over the whole image rather than a window. **Slot 83's body ends in a bare `ret`**, which `project.json` already records as `bool __thiscall CAIUnit::DistributeOpsAreaToSubordinates(CAIUnit* this)` — zero stack arguments, receiver in `ECX`, result in `al`. That is a decidable test on a call site, and it disposes of 29 of the 30:

- **`0x480CEA`** is not a dispatch at all. It is `mov eax,[edi+0x14c]` where `edi` is a `CMapProvince` and `+0x14C`/`+0x150` is a `vector` begin/end pair (`sub ebx,[edi+0x14c]; sar ebx,2` two instructions earlier); the `call eax` the heuristic latched onto at `0x480D00` is `province->area->vf[0]()`. The containing function is unnamed, `0x480C00`, in the map/area module `0x31C0` past `CollectAreaFrontsForCountry`.
- **The other 28** — `0x83FEAA`, `0x840362`, `0x840664`, `0x8413BA`, `0x8415D9`, `0x844312`, `0x84E273`, `0x86008C`, `0x860189`, `0x86029C`, `0x860682`, `0x86077F`, `0x860892`, `0x87F0F7`, `0xAA3726`, `0xAC7038`, `0xAC7148`, `0xAFD521`, `0xAFD697`, `0xAFF4E1`, `0xB0E9BE`, `0xB0EA5C`, `0xB10438`, `0xB1A82C`, `0xB1FEE7`, `0xB276F4`, `0xB413BE`, `0xB5642E` — are all one renderer interface, called with four or five arguments on the stack and the receiver **pushed** rather than in `ECX`. The recurring shape is `push 0x14; lea edx,[esp+N]; push edx; push 2; push 6; push eax; mov eax,[ecx+0x14c]; call eax`, with sibling slots `0x100`, `0x104`, `0x108`, `0x10C`, `0x110`, `0x114`, `0x15C` and `0x164` used the same way a few instructions either side, and the object reached as `something->+0x64`. A `CAIUnit` handed to any of them would be a type error, not a dispatch of slot 83.
- **`0x881733`** is the only site in the image with slot 83's convention:

      0x8812B..  (esi reloaded from [0x1A89790] at 0x8814ED)
      0x88172B  mov ecx, [esi + 0xBE8]
      0x881731  mov edx, [ecx]
      0x881733  mov eax, [edx + 0x14C]
      0x881739  call eax
      0x88173B  movss xmm0, [esp+0x40]
      0x881741  test al, al
      0x881743  jne 0x881CF4

  `0x1A89790` is `g_CCurrentGameState` (rva `0x1689790`, already in the record), and `CCurrentGameState +0xBE8` is already named `in_game_screen (CInGameIdler*)` in both `project.json` and `BiceLib/GameClasses/CCurrentGameState.hpp`. Reading `CInGameIdler`'s own table (`0x15CEB54`, 111 slots) at slot 83 gives **`0x592360`**, which is `xor al,al; ret` — the record's `ReturnFalse`, in 836 slots across 407 classes. So this site is positively accounted for: it is an idler asking a predicate that is constant false for it, and the `test al,al` is reading that constant.

  The containing function is `0x8813C0` (`esi = [ebp+8]`, SEH, `sub esp,0x128`), and `0x881733` sits in a cold block **past** that function's `ret 4` at `0x8814DF` which reuses the same frame — trap 3 again, and `image.retsBefore(0x8813C0, 0x881733)` reports exactly that one `ret`, which is how it was spotted rather than mis-attributed.

### The routes method 4 cannot see, and why they are closed too

- **A member-function pointer to a virtual** compiles in MSVC32 to a thunk `mov eax,[ecx]; jmp [eax+0x14C]`. There is **no `jmp [reg+0x14C]` anywhere in `.text`** (and none at `0x148` either, as the control confirms), and method 3 found no `e9`/`eb` jump to `0x8C0790`.
- **A runtime slot index** would be `mov eax,[obj]; call [eax+idx*4]`. There are 138 `call [base+index*scale]` byte patterns in `.text`; the four inside `0x880000`–`0x8E0000` (`0x8A757D`, `0x8CFC02`, `0x8D2BC1`, `0x8DD96D`) are all mid-instruction decode artefacts — decoded from a synchronised point each is an ordinary `call rel32` or a `mov`. **Control: 7716 absolute indirect calls (`call [abs]`) do exist in `.text`, so the scan sees that family; none of the 7716 lands inside `CAIUnit`'s vftable.**
- **An adjustor thunk or a base-class pointer at a shifted slot index** needs multiple inheritance. The RTTI export says every class in the family is single-inheritance with exactly **one** vftable at object offset 0: `CAISubscriber` ← `CAIAgent` (73 slots) ← `CAIUnit` (90 slots), and `CAIInvasion` (74) and the five ministers (73 each) beside it. Slot 83 is inside the range `CAIUnit` introduces, so **a `CAIAgent*` cannot reach it at all** — through a base pointer the highest reachable slot is 72. Only code whose static type is `CAIUnit*` could dispatch it.
- **An RTTI-stripped sibling table overlapping `CAIUnit`'s** would not need its own copy of `0x8C0790`, which is the one gap method 2 leaves. Method 5 closes it: no value anywhere in the image points into the interior of that table, so no second table can share its cells, and no constructor can be writing a shifted base.

### So, stated as a claim

**`CAIUnit::DistributeOpsAreaToSubordinates` (slot 83, `0x8C0790`, rva `0x4C0790`) is never called in this build.** Confidence `confirmed` for the static fact; the mechanism it implements is therefore dead, and **no subordinate agent ever receives an operations area by this route.** A subordinate's `CAIUnit +0x90` can still be written by `CAIUnit::SetArea` (`0x8BA5A0`) on the agent's own behalf — but `SetArea` refuses any unit whose `oob_level` is not 0, and slot 76 refuses to compute an area for a subordinate, so **a subordinate land agent's `+0x90` should be permanently empty.**

What would falsify it, cheapest first:

1. **`census.py`-style live check, no hook needed**: read `+0x90`/`+0x94` on every live `CAIUnit` whose `unit->oob_level != 0`. If any is non-empty, something reaches slot 83 or `0x8C0550` and this whole section is wrong. This needs only `findInstances.py CAIUnit --dump 0xA0`, so it is the one to run first.
2. A BiceLib counter hook on `0x8C0790`. Worker-thread code (`ProcessAI` runs under `ProcessAIFunctor::execute` on a TBB worker), so it must do nothing but `InterlockedIncrement` — no Lua, no message, no ImGui frame.
3. A hook on `0x8C0550` instead, which is 165 bytes and has exactly one caller; counting it is the same test one frame further out and is just as safe.

### A second, independent reason to think it never runs

Slot 83 contains a **reachable null dereference**. At `0x8C1006` it tests the resolved subordinate `CUnit*` at `[esp+0x10]` for null and takes a branch that substitutes the constant score `1000000.0f` (`0x160A598`) — so a child whose object id fails to resolve is expected. But `0x8C1085`, unconditionally downstream of both arms, does

    0x8C1085  mov ecx, [esp+0x10]
    0x8C1089  mov eax, [ecx + 0x130]
    0x8C108F  mov eax, [eax + 0x2B4]

which reads address `0x130` when that pointer is null. The function also calls `0x8C1FC0` with the same pointer in `ECX`, which would fault inside `CUnit::CollectSubtree`. A branch that handles null and then dereferences it twelve instructions later is what unexercised code looks like. This is weak evidence on its own — plenty of live code has latent faults — but it points the same way as the dispatch scan, and it is worth knowing before anyone decides to *enable* slot 83 by hooking something into it.

---

## 2. Slot 83, end to end

`bool __thiscall CAIUnit::DistributeOpsAreaToSubordinates(CAIUnit* this)`, `0x8C0790` (rva `0x4C0790`) to the bare `ret` at `0x8C177A`, with an early `ret` at `0x8C07F9` and the two `_CxxThrowException` arms past the end out to `0x8C178E`; slot 84 begins at `0x8C1790`. 1148 instructions off `cfg.py`. The throw arms are reached from inside, which is what makes them part of the body: `0x8C0CFE` branches to `0x8C177B` (`"list<T> too long"`, the string at `0x15C1AD4`) and `0x8C12DC`/`0x8C1337` to `0x8C1785` (`"vector<T> too long"`, `0x15B4F5C`).

### The entry test, exactly

    0x8C07B5  unit = this->+0x64
    0x8C07C3  if (unit && unit->oob_level (CUnit +0x1F4) != 0)   -> body
    0x8C07CB  noArea = (this->+0x68 == 0 && this->+0x6C == 0)
    0x8C07DA  if (noArea)                                        -> body
    0x8C07E3  return false
    0x8C07FA  if (((this->+0x94 - this->+0x90) & ~3) == 0) return false

`FINDINGS-setarea.md`'s account of this is right; the only thing to add is that the ops-area emptiness test is spelled `test eax, 0xFFFFFFFC` rather than a plain compare, and that the return value byte `[esp+0x1F]` is zeroed at `0x8C0A76`, *after* the guards, so the two early returns return false by `xor al,al` instead.

### Step 1 — the census, and the one-link list (`0x8C080D`–`0x8C0A6B`)

A local ordered container is constructed at `[esp+0xA4]` by `0x8DD000`; `[esp+0xA8]` is its sentinel node and `[esp+0xAC]` its size. It is **not** an MSVC `std::map`: the iteration at `0x8C1699` advances with `node = [node]` and stops when the node equals the sentinel, and the teardown at `0x8C16FA` writes `[sentinel] = sentinel` and `[sentinel+4] = sentinel`, so it is a circular doubly-linked ordered list with node layout `{next, prev, key, value}` — `+8` the key, `+0xC` the value. `0x8DCF30` is its `operator[]` (returns `&value`, and the caller does `inc [eax]`), `0x8DD130` its `find` (`map@EAX, &outIterator, &key`), `0x8DD980` its insert fixup and `0x5147D0` its node allocator.

Then, for each province `p` of `this->+0x90`:

- `0x8C0881` if `p->area (+0x2B4)->vf[0]()` is true, `++map[p->area]`. So **the map is a census: owner area → how many of the parent's ops-area provinces lie in it.**
- `0x8C08B1` walk the 20-byte adjacency records at `p->template (+0xD4) + 0x90`, count `(template+0x94 − template+0x90) / 20`:
  - skip a record whose first dword is `3` (edge kind 3);
  - the neighbour id is record `+4`, resolved through `gamestate->provinces_begin (+0xB8C)`;
  - require the neighbour's template `+0x22` and `+0x13D`;
  - `0x8C09D0` `std::find` the neighbour **in the parent's own ops area**, and count it when it *is* there.
  These are the same three adjacency gates `SetArea` uses, so the record needs no new fields for them.
- `0x8C09F5` when that count is **exactly 1**, allocate a 0x10-byte node `{province, prev, next=0, byte=0}` and append it to a CList at `[esp+0x94]`/`[esp+0x98]`/`[esp+0x9C]`.

`FINDINGS-setarea.md` called that last list "the chokepoints". Read exactly, it is the list of **ops-area provinces joined to the rest of the area by a single link** — the leaves and dead ends of the area's internal adjacency graph, not necessarily its chokepoints. They are the provinces the fill will prefer, which makes sense: a leaf is where a contiguous slice can start without cutting the area in two.

### Step 2 — one pass per owner area (`0x8C0A6D`–`0x8C16C2`)

The whole remainder is a loop over the census map. `[esp+0x24]` holds the current `COwnerArea*` (the node's `+8`), and the loop is skipped entirely when the map is empty (`0x8C0A81`). Everything below happens **once per owner area the parent's ops area touches**, which is the structural fact `FINDINGS-setarea.md` did not have: the area is not sliced globally, it is sliced owner area by owner area.

#### 2a — the weight list (`0x8C0A90`–`0x8C0BE3`)

A local CList is cleared at `[esp+0x48]`/`[esp+0x4C]`/`[esp+0x50]` with its byte at `[esp+0x54]`, and `[esp+0x14]` is the running total. Then for each child on `this->unit->+0x1E4` (`CUnit::children`):

    0x8C0AD5  if (!child->vf[15]())                  skip this child
    0x8C0AEF  if (this->unit->oob_level >= 4)        skip the whole loop
    0x8C0AFC  p = Unit_GetAnchorProvince(child@EDI, true)      ; 0x8BE1C0
    0x8C0B0F  if (!p->area->vf[0]())                 skip
    0x8C0B1F  if (p->area != currentOwnerArea)
                  and currentOwnerArea is not in p->area->+0x34 (neighbour areas)
                                                     skip
    0x8C0B4F  divisions  = (child->vf[15]() && child->oob_level >= 4) ? 1 : 0
    0x8C0B70  for each grandchild on child->+0x1E4
                  divisions += CUnit::CountDivisions(grandchild@ECX, 1, 0, 0, 1)   ; 0x5BDB00
    0x8C0B88  node = new CIDValue { 0x15EC094, 0x18D,
                                    child->+0x10, child->+0x14,
                                    divisions * 1000 }
    0x8C0BC0  weights.push_back(node)                ; 0x8DD670
    0x8C0BD3  total += divisions

Two corrections of detail to `FINDINGS-setarea.md`'s step 2 here. The `oob_level >= 4` test is on **the parent's** unit, not the child's — it is read as `[esp+0x38]->+0x64` then `+0x1F4`, so a division-level agent distributes nothing. And the `CIDValue +0x10` is not simply `CUnit::CountDivisions` of the child: for a child at `oob_level >= 4` (a division, or a navy at 5) it is `1 +` the sum over the child's own children, and for a corps or higher it is just that sum. `CountDivisions` is called on the **grandchildren**, one per child of the child.

`CUnit +0x10`/`+0x14` is the object id pair, `0x18D` goes in `CIDValue +4` (its type tag) and `0x15EC094` is `CIDValue`'s vftable — all as the earlier reading had it.

#### 2b — the quotas: largest remainder with a carried fraction (`0x8C0BE7`–`0x8C0DEB`)

This is what the brief asked for. `[esp+0x60]` is zeroed once, before the loop, and is the carried fraction. Then for each `CIDValue` on the weight list, in order:

    0x8C0C04  resolve the CIDValue's id pair to a CUnit* (see 2c below); null is tolerated here
    0x8C0C6F  n = (this->+0x94 - this->+0x90) >> 2            ; the whole ops area, as the default
    0x8C0C7A  p = Unit_GetAnchorProvince(child@EDI, true)
    0x8C0C8B  if (p->area->vf[0]()) {
    0x8C0CB3      it = census.find(p->area)
    0x8C0CC8      if (it == end) { insert p->area with value 0; it = the new node }
    0x8C0D44      n = it->value
              }
    0x8C0D47  weight  = cidValue->+0x10 / 1000                ; = its division count
              exact   = (float)n * ((float)weight / (float)total)
              quota   = (int)exact
              carry  += exact - quota
    0x8C0DC4  if (carry >= 1.0f) { carry -= 1.0; ++quota; }
    0x8C0DDD  cidValue->+0x10 = quota * 1000

So the share is `weight / total` of **`n`**, and `n` is **the census count for the owner area of that child's own anchor province** — not the size of the parent's whole ops area, which is only the fallback used when the anchor province has no valid owner area. When the child's anchor area is one the parent's ops area does not touch at all, `find` misses, a node with value 0 is inserted, `n` is 0 and the quota comes out 0 — and step 2c then raises a zero quota to 1, so such a child still gets exactly one province.

The rounding is the classic **Hare / largest-remainder** split: the fractional part of every child's exact share is accumulated in `carry`, and whenever the accumulator reaches one whole province that child is given an extra one. The constants are the float `1.0` at `0x171DBAC` and the double `1.0` at `0x160A248`; the `/1000` is `imul 0x10624DD3; sar edx,6` and the `*1000` is `imul eax,eax,0x3E8`. **The `*1000`/`/1000` round trip means the `CIDValue +0x10` field is reused: division count going in, province quota coming out.** The division by `total` is done in double precision and the multiply by `n` in double, with the truncation in `cvttss2si`.

#### 2c — the greedy contiguous fill (`0x8C0DF1`–`0x8C138B`)

`[esp+0x64]`/`[esp+0x68]`/`[esp+0x6C]` is a `vector<CMapProvince*>` of everything already handed to an earlier subordinate in this owner-area pass; it starts empty. Then, while the weight list is non-empty, take its **front** node:

    0x8C0E11  cid = weights.front();  idType = cid->+8;  idSerial = cid->+0xC
    0x8C0E2D  child = FindPersistentById-inlined(idType, idSerial)       ; null tolerated
    0x8C0EE3  quota = cid->+0x10 / 1000
    0x8C0EF9  if (quota == 0) quota = 1
    0x8C0F04  slice = {} at [esp+0x28]/[esp+0x2C]/[esp+0x30]
              do {
    0x8C0F30      best = 10000000.0f  (the float at 0x160A7CC);  pick = 0
                  for each province q of the PARENT's ops area {
    0x8C0FF1          if (q is already in slice) continue
    0x8C1013          s = child ? CUnit::MeanDistanceToProvince(child@ECX, q->id)   ; 0x8C1FC0
                                : 1000000.0f                                        ; 0x160A598
    0x8C1035          if (q is in `taken`)              s += 1000.0                 ; 0x160A300
    0x8C1050          else if (q is in the one-link list) s /= 100.0                 ; 0x160A358
    0x8C1085          if (child->current_province->area != q->area)
                          s += q->CanUnitReach(child, 1, 1) ? 500.0 : 1000.0        ; 0x160A538 / 0x160A300
    0x8C10D4          if (slice is empty)   { if (s < best) { best = s; pick = q; } }
    0x8C10FE          else                  { if (s < best
                                                  && q is adjacent to some member of slice)
                                                   { best = s; pick = q; } }
                  }
    0x8C129F      if (!pick) break
    0x8C12AB      slice.push_back(pick)                     ; grow helper 0x4C0700, limit 0x3FFFFFFE
    0x8C1387  } while (slice.size() < quota)

Four things worth stating plainly:

- **The slice is contiguous by construction.** The first province is free, every later one must be adjacent (same three gates: edge kind ≠ 3, template `+0x22` and `+0x13D`) to a province already in the slice. A subordinate therefore gets a connected blob, not the *n* nearest provinces.
- **Lower is better and the comparison is strict** (`comisd best, s; jbe reject`), so ties go to the province the parent's ops-area vector lists first.
- **The penalties are plain floats, not thousandths.** `+1000.0` for a province another subordinate already took, `÷100.0` for a one-link province, `+500.0`/`+1000.0` for leaving the subordinate's own owner area, against a score that is a map distance. Trap 7 cuts both ways and this is a case of it: nothing here is fixed point.
- **A province can be given to two subordinates.** Being in `taken` is a penalty of 1000, not an exclusion. With a mean distance that can easily exceed 1000 on a large map, overlapping slices are reachable.

Also: slot 83 **never re-applies the `CMapProvince +0x5C >= 200` floor** that `SetArea` applies to every province before it puts one in an ops area. A province that got into the parent's area is eligible without being re-tested.

The id resolution at `0x8C0C1F`/`0x8C0E2D` and its two siblings at `0x8C0E67`/`0x8C0F6C` is an **inlined copy of `FindPersistentById` (`0xA9DA00`)**, written out four times: `table = (idType > 0x1268) ? [0x1A857F0] : [0x1A857F4]`, `bucket = ((idType << 16) + idSerial) % table->+4`, chain through `table->+8[bucket]` with `next` at node `+4` and the pair at `+8`/`+0xC`, and the object is the found payload **minus 8**, because `CReferenceObject` sits at `CUnit +8`. That is the same pair of tables and the same `−8` as `RunHourlyTick`'s unit-removal drain (`0x68227D`/`0x68228E`), which `FINDINGS-schedule.md` already documents.

#### 2d — the output, and the one thing that is actually posted (`0x8C1391`–`0x8C164B`)

    0x8C13A8  already = count of slice members found in child->+0x214 (plan_ops_area list)
    0x8C13D3  if (already != 0 && already == child->+0x21C (plan_ops_area_count)) skip to the merge
    0x8C13E7  ids = CList of slice[i]->id (+0xD0), 0x10-byte nodes
    0x8C1470  cmd = new CSetPlanOpsAreaCommand(0x78 bytes, ctor 0x5E60B0)(child, &ids)
    0x8C152B  gamestate->in_game_screen (+0xBE8)->vf[18]()->+0x38->vf[6](cmd)      ; post it
    0x8C1549  [esp+0x1F] = 1                                                      ; the return value
    0x8C1543  agent = child->+0x198
    0x8C1552  if (agent && agent->vf[65]())
    0x8C156C      CAIUnit::SetOpsAreaAndReplan(agent, &slice)                      ; 0x8C0550
    0x8C15A1  taken = taken.empty() ? assign(slice) : append(slice)                ; 0x8DD860 / 0x482190
    0x8C15E0  pop the weight node (or, when the list's byte at [esp+0x54] is set,
              only mark the node's +0xC = 1 instead of unlinking it)
    0x8C1616  cidValue->vf[0](1)                                                   ; delete it
    0x8C164B  loop while the weight list is non-empty

So the "skip if unchanged" brake `FINDINGS-setarea.md` describes is real but has a quirk: the test is `already != 0 && already == count`, so a subordinate whose plan ops area currently holds **none** of the slice is always posted to, even when the slice is identical to nothing. And `vf[65]` is the type-tag slot — `mov al,1` on `CAIUnit`, false on `CAIInvasion` — so the direct write is gated on the subordinate's agent being a unit agent rather than an invasion agent, not on anything about the area.

**The return value**: `[esp+0x1F]`, zeroed at `0x8C0A76`, set to 1 only at `0x8C1549`. So slot 83 answers **true iff it posted at least one `CSetPlanOpsAreaCommand`** — which is the shape of a "did anything change" answer, and is consistent with a caller that would have used it to decide whether to recurse.

---

## 3. `0x8BE1C0` — the anchor province, and what `CArmy::ai_param_a` is

The brief called this "probably the key" to the middle, and it is, though not in the way expected: it is not scoring, it is the one-line question *where is this unit*.

`CMapProvince* __stdcall Unit_GetAnchorProvince(CUnit* unit@EDI, bool preferAiTarget)` — `0x8BE1C0` (rva `0x4BE1C0`) to the `ret 4` at `0x8BE2BA`, 250 bytes, read end to end; `int3` padding then a fresh prologue at `0x8BE2C0`, so the extent is clean. The receiver arrives in **EDI** and is never loaded from the frame, so it is not a `__thiscall`; the single stack argument is tested as a byte (`cmp byte ptr [ebp+8], bl`). Ten callers: `0x8B8178`, `0x8C0AFE`, `0x8C0C7A`, `0x8C5E95`, `0x8C5ED0`, `0x8C5F65`, `0x8C6262`, `0x8C635A`, `0x8C718F`, `0x8C7244`.

    if (preferAiTarget && unit->vf[15]() && unit->vf[9]()->+0x2E8 != 0)
        return gamestate->provinces_begin[ unit->vf[9]()->+0x2E8 ];
    p = CUnit::GetMovementDestinationProvince(unit@ECX);          ; 0x89AF00
    return p ? p : unit->current_province_ptr (+0x130);

Slot 15 is the land predicate — `ReturnTrue` (`0xA92590`) on `CArmy` only, `ReturnFalse` (`0x592360`) on `CUnit`, `CNavy` and `CAir` — and slot 9 is `mov eax,ecx; ret` (`0x5B4EC0`) on `CArmy` and the shared null stub `0xA80690` on the other three. So the first arm is reachable only for an army, and `unit->vf[9]()->+0x2E8` is `CArmy +0x2E8`.

**That is what `CArmy +0x2E8` is.** `project.json` has it as `ai_param_a` with "What it means was not established", written by `CSetAIParamCommand::Execute` from the command's `+0x64` and read-and-passed-back by slot 78. Here it is used as **an index into `CGameState +0xB8C`, the province vector indexed by id** — so it is a province id, and the function treats it as the unit's preferred anchor, taking precedence over the unit's actual movement destination. `likely` that it is specifically a *target*; `confirmed` that it is a province id, because nothing else can be indexed into that array.

Note the asymmetry with its sibling: `ai_param_b` (`CArmy +0x2E4`) is zeroed by slot 78 while `ai_param_a` is preserved, which fits a field holding a standing target rather than a per-pass scratch value.

---

## 4. `0x8C1FC0` — the score is a mean distance over the subordinate's own brigades

`float __thiscall CUnit::MeanDistanceToProvince(CUnit* this, int provinceId)` — `0x8C1FC0` (rva `0x4C1FC0`) to the `ret 4` at `0x8C20B8`, 249 bytes, read end to end; slot 85 begins at `0x8C20C0`. One caller: `0x8C1022`, in slot 83.

    list = {}
    CUnit::CollectSubtree(this@ECX, &list)                    ; 0x5BDA90
    total = 0.0f
    for each u in list
        if (u->vf[15]() && u->current_province_ptr)
            total += CMap::DistanceBetweenProvinces(u->current_province->id@EAX,
                                                    provinceId@EDX, g_CMap)   ; 0x492030
    if (list.count) total /= list.count
    free the list
    return total                                              ; in XMM0, not ST0

`CUnit::CollectSubtree` (`0x5BDA90`, rva `0x1BDA90`, `ret 4`, 101 bytes, 4 callers) appends `this` to the CList it is handed and then recurses into every child on `CUnit +0x1E4`, so the list is the unit and its whole OOB subtree. The land filter is slot 15 again, so only army-side members count, and the divisor is the **whole** list length including the non-land members and the ones with no province — so a mixed or partially-unplaced subtree drags the mean down. `g_CMap` is `0x1A8557C` (rva `0x118557C`, already in the record).

The float return in `XMM0` rather than `ST0` is non-standard for 32-bit MSVC and the one caller reads it with `movss`, so anyone writing a signature for this must not assume the usual convention.

So the slicing metric is: **give a subordinate the provinces nearest to where its own brigades actually stand, averaged over all of them.** Combined with the contiguity requirement and the leaf bonus, the intended behaviour is clear enough: each subordinate ends up with a connected piece of the parent's area, anchored where its troops already are, preferring the ends of the area to its middle, avoiding its siblings' ground and avoiding ground it cannot path to.

---

## 5. The thresholds: what is in thousandths and what is not

### `CDiplomacyStatus +0x5C` — already answered, and `FINDINGS-setarea.md` read the site wrong

Trap 14 applies: the record already names it. `project.json` has `CDiplomacyStatus +0x5C = threat (int)`, "How much threat the array's owner feels from the other country, thousandths. Two independent readers agree: the alignment threat term takes the maximum of this over a faction's members, and `0x4E21E0` scans it to cache the worst offender in `CCountry +0x11D8`/`+0x11DC`". So the `40000` in `SetArea`'s `wideOpen` test is **40.0 threat**, on a scale two existing readers establish. The open item is closed by looking rather than by reading more bytes.

But the pseudo-code in `FINDINGS-setarea.md` attributes that site to the wrong object. It says

    country->strategy.threat[front->enemyId] >= 40000        ; 0x8BAD15

and the bytes at `0x8BACD9`–`0x8BAD1D` say:

    edx = [0x1A855A4]                       ; the country database holder
    eax = agent (SetArea's first argument)
    ecx = agent->+0x38                      ; CAIAgent::country_id, our own
    eax = [edx + 0x16C]                     ; the country array
    ecx = countryArray[ourId]->+0xE28       ; the CDiplomacyStatus array
    ecx = ecx[enemyId * 4]
    ecx = ecx->+0x5C                        ; threat
    eax = countryArray[enemyId]->+0xA90     ; effective_neutrality
    if (threat >= 0x9C40 && neutrality <= 0x4E20) wideOpen = 1

So it is `ourCountry->diplomacy[enemyId]->threat`, read through `CCountry +0xE28`, **not** the `threat` hash embedded in `CAIStrategy` at `CCountry +0x48C`. The two are different stores and `FINDINGS-setarea.md` conflated them in that one line (its own field table has the right object). With `CCountry +0xA90 = effective_neutrality` also already in the record, in thousandths, the test reads: **widen the front when we feel at least 40.0 threat from them and their effective neutrality is at most 20.0.**

### `CCountry +0xCC` — the 150 and 50 are thresholds on a *ratio*, so the field's own scale cancels

The arithmetic in `0x8BD270`, at `0x8BD782`–`0x8BD8BC`:

    for each 8-byte CCountryTag entry of a list (count at [ebp-0x14])
        total += CCountryTag::GetCountry(tag)->+0xCC            ; 0x402610
    mean = __alldiv(__allmul(total, 1000), count * 1000)        ; = total / count
    ours = ourTag.GetCountry()->+0xCC                           ; our tag is agent->+0x34
    if (ours > 0) {
        r = mean * 1000 / ours                                  ; thousandths
        if (r <= 150) {                                         ; floorf(150.5f), 0x160A83C
            value = max(r * 1000 / 150, 50)                     ; floorf(50.5f),  0x160A7B4
            ...
        }
    }

Both constants are the `(int)floorf(N.5f)` idiom inlined — `movss xmm0,[const]; push ecx; movss [esp],xmm0; call floorf; call _ftol2_sse` — which is trap 8 case 3, so no `defines.lua` entry can move them. And the point for the open item: **`r` is already a thousandths ratio, so `150` and `50` mean 0.15 and 0.05 and `+0xCC`'s own scale cancels out of the comparison entirely.** The guess that "all three look like thousandths, which would make them 40.0, 150.0 and 50.0" is right for the 40000 and wrong for these two. The `*1000 / (count*1000)` in the mean is a compiler artefact of a fixed-point divide macro and is an identity.

What `+0xCC` *is* remains open, and two checks narrow it:

- **`CCountry::LoadKey` never writes it.** `fieldmap.py CCountry` places `officers` at `+0xC4` and nothing at `+0xC8` or `+0xCC`, so it is live or derived and **the savegame is not an oracle for it** — which is the oracle this folder reaches for first.
- **It has exactly one reader in the image through the `GetCountry` idiom, and it is `0x8BD270`.** Scanning all 1295 `call CCountryTag::GetCountry` sites for a `[EAX + D]` access within 0x30 bytes, with the base register pinned to `EAX` so the hit has to be on the returned country: `+0xCC` → 1 function, against controls `+0xC4 (officers)` → 3, `+0xBCC (Manpower)` → 2, `+0xA90 (effective_neutrality)` → 6. The method sees known fields, and for this one it sees only the AI.

  Pinning the register matters and is a trap-12 lesson in miniature: without it the same scan reports three readers, and the other two (`0x6C22CF`, `0x6C300E`) are `[ebx+0xCC]` and `[esi+0xCC]` on UI objects that have nothing to do with the country the call just returned.

  The limitation to state: this method sees only countries reached through `GetCountry`, not through `[db+0x16C][id]` or a cached pointer, so "one reader" is a strong result and not a closed one.

The cheapest check is live, and it is cheap: `dumpStruct.py` a handful of `CCountry` with `--length 0x100` and compare `+0xC4` and `+0xCC` across a major and a minor. A field the AI averages across a set of countries and compares with its own is a strength or capacity measure; one live read of three countries would probably settle which.

---

## 6. `0x895140` — which areas may widen the front search

`bool __cdecl AreaMayWidenFrontSearch(CCountry* us, COwnerArea* area, bool* outIsOwnFocusArea, bool acceptAnyUnplayed)` — `0x895140` (rva `0x495140`), true exits at `0x895394` and `0x8953AE`, false exit at `0x895524`, all bare `ret` with four stack arguments. Read end to end. Five callers: `CAIUnit::SetArea` at `0x8BA8B8`, two inside slot 79 (`0x8B3480`, `0x8B37DB`) and two at `0x898923`/`0x8989F3`.

1. `0x89516A` false unless `area->vf[0]()` — `COwnerArea` slot 0, the validity test that keeps `CNullOwnerArea` out.
2. `0x895178` the controlling country: when `area->provinces_count (+0x2C)` is zero, the tag is the literal `"---"` (`0x2D2D2D`) and the id 0; otherwise it is taken from the area's first province (`COwnerArea +0x24`, node payload) at `+0x334`/`+0x338`. False when the id is 0, and false when the tag is `REB`.
3. `0x8951CB` `CCountry::IsSameSide(us@ECX, &tag@EAX)` — if that says no, then both of: `us->diplomacy[id]->+0x58` must be set, and `CCountry::IsEnemyTag(us, &tag)` must say no.
4. `0x8951FB` **`us->government_in_exile (+0x95)` short-circuits to true.**
5. `0x895208` if `us->ai (+0x1D8)` exists and `ai->+0x2C` is set (an AI-run country, the flag `FINDINGS-setarea.md` traced to both ends), walk `ai->+0x118` — the focus province list the record already knows adds 100 to an objective's priority. For each listed province: if its area **is** this area, set `*out = true` and return true (`0x89537B`); otherwise, if this area is among that province's area's neighbours (`COwnerArea +0x34`) and `CCountry::IsEnemy` holds against that neighbour's owner, likewise set `*out = true` and return true (`0x895395`).
6. `0x8953DD` false when the controller is human-played (`gamestate->played_countries_array`, `+0xBCC`).
7. `0x89540B` true when `acceptAnyUnplayed` (the fourth argument — `SetArea` passes 0, so this arm is never taken from there).
8. `0x895448` true when the controller's `faction_leader_id (CCountry +0xF3C)` equals our own id (`+0xCA8`) — we lead their faction, or they are our puppet.
9. `0x895454` otherwise, for each neighbour area: take its controller's `CDiplomacyStatus`, require `+0x20` (`war`) non-null, require the neighbour area to hold **more than five** provinces, and then true when either `gamestate->scenario (+0xD0C)` is non-null, or `CountryTagVector_Contains` finds our tag in the war's attackers (`CWar +0x2C`) or defenders (`+0x3C`) **and** that side's first entry — the war's leader — is not human-played.
10. Otherwise false.

So the return value and the out-parameter answer two different questions, which is worth knowing before anyone reads `SetArea`'s pass B again: **the return value is "am I allowed to look for a front here", and `*out` is "this is one of my own AI focus areas".** `SetArea` uses the out-byte, which means the areas that widen its search are the ones its own focus list points at.

The `gamestate->scenario` test at step 9 is odd and I am reporting it rather than explaining it: `CCurrentGameState +0xD0C` is named `scenario` in the record, "the scenario, or null in a loaded save", so the relaxation applies when the game was started from a scenario file and not when it was loaded from a save. `0x8BDF30` reads the same field. If that reading of `+0xD0C` is right then this is a behavioural difference between a fresh start and a reloaded save, which is the sort of thing a live check would settle quickly and nothing static will.

Two small functions fall out of it, both recorded: `CountryTagVector_Contains` (`0x421D00`, rva `0x21D00`) — nine instructions, bare `ret`, both arguments in registers, matching on the **id half** of each 8-byte tag entry, 40 callers across the war and diplomacy code — and `CMapProvince::CanUnitReach` (`0x5C7710`, rva `0x1C7710`, `ret 0xC`, 18 callers, thirteen of them in `CAIUnit`), whose receiver is the **province** and whose first argument is the unit, which answers true at once when the unit is already there and otherwise ends by constructing a `CPathFind` in its own argument slot (one of two vftables, `0x15C884C` or `0x15BE414`, chosen by its second argument) and calling the already-recorded `CPathFind::Find(finder, unit, from, to, path)`. Its middle is unread and the meaning of its two bool arguments is not established.

---

## Corrections to the record

1. **`SetArea`'s `wideOpen` 40000 test reads `CCountry +0xE28`, not the `CAIStrategy` threat hash.** `FINDINGS-setarea.md`'s pseudo-code line `country->strategy.threat[front->enemyId] >= 40000 ; 0x8BAD15` should be `ourCountry->diplomacy[enemyId]->threat (CDiplomacyStatus +0x5C) >= 40000`. The bytes are at `0x8BACD9`–`0x8BAD1D` and are quoted in section 5. Its own field table has the right object, so this is the pseudo-code only — but the two stores are different and the distinction matters to anyone looking for a writer.
2. **`CDiplomacyStatus +0x5C` is not unresolved.** `project.json` names it `threat`, in thousandths, with two independent readers. `FINDINGS-setarea.md`'s open item 5 and its field table entry "compared against 40000 in SetArea's wideOpen test. Unresolved" should both point at that entry instead. The threshold is 40.0.
3. **`CMapProvince +0x5C` is not unresolved either.** `project.json` has it as `ai_front_value`, an int in thousandths. `FINDINGS-setarea.md`'s open item 3 can be closed by reading the record. Worth adding there: **slot 83 does not apply the 200 floor** that `SetArea` applies, so the filter is a gate on entering an area, not on staying in one.
4. **`CArmy +0x2E8 (ai_param_a)` is a province id.** `project.json` says "What it means was not established"; `0x8BE1C0` indexes `CGameState +0xB8C` with it. Suggested amendment to that field's comment: *"A **province id**: `Unit_GetAnchorProvince` (`0x4BE1C0`) indexes the game state's province vector at `+0xB8C` with it at `0x4BE295`, in preference to the unit's real movement destination, so it is the AI's standing target province for the army. Slot 78 preserves it while zeroing `ai_param_b`, which fits a standing value rather than a per-pass scratch one."*
5. **The slot-83 "chokepoint" list is a one-link list.** `FINDINGS-setarea.md` step 1 calls it "the ops-area provinces with exactly one usable neighbour outside the area". It is the provinces with exactly one usable neighbour **inside** the area: the `std::find` at `0x8C09D0` searches the agent's own `+0x90` vector and the counter is incremented when the neighbour **is** found.
6. **Slot 83 step 2's `oob_level >= 4` test is on the parent, not the child.** `0x8C0AEF` reads `[esp+0x38]->+0x64` — the agent's own unit — and skips the whole distribution; the child's own `oob_level >= 4` is tested separately at `0x8C0B55` and only seeds its division count with 1.
7. **Slot 83's structure is per owner area.** `FINDINGS-setarea.md` presents steps 1–4 as one pass. Everything from step 2 on is inside a loop over the census map built in step 1, so the weight list, the quotas, the fill and the posting all happen **once per owner area the parent's ops area touches**.
8. **`project.json`'s `0x4C0790` comment should gain the middle.** It currently stops at "It builds a std::map<COwnerArea*,int> of the…". Suggested continuation: *"…ops area keyed by owner area, plus a list of the ops-area provinces with exactly one neighbour inside the area, and then for each owner area in that census: weighs each child unit anchored in or next to it by its division count into a `CIDValue` list; apportions that owner area's census count among them by the largest-remainder method with a carried fraction (`0x4C0D47`); and grows each subordinate's slice one province at a time, contiguously, choosing the lowest `CUnit::MeanDistanceToProvince` with +1000 for a province a sibling took, ÷100 for a one-link province and +500/+1000 for leaving the subordinate's own owner area. Posts one `CSetPlanOpsAreaCommand` per subordinate unless the subordinate's plan already holds exactly that set, then calls `CAIUnit::SetOpsAreaAndReplan` on its agent. Returns true iff it posted anything. **Nothing dispatches it — see `FINDINGS-subdivide.md` section 1.** It also contains a reachable null dereference at `0x4C1089` on the path its own `0x4C1006` test admits."*
9. **`FINDINGS-setarea.md`'s open item 1 can be restated as settled.** It says "Either slot 83 is dead in this build, or it is entered by a route this scan cannot see. The first is not claimed." Section 1 claims it, by five methods with controls, and identifies the one ambiguous site positively as `CInGameIdler`'s.

---

## Field and layout notes

```
CArmy
  +0x2E8  int    ai_param_a is a PROVINCE ID - the AI's standing target province for the army.
                 Read that way by Unit_GetAnchorProvince at 0x8BE295 (index into CGameState +0xB8C)

CDiplomacyStatus
  +0x58   byte   military access: the one extra condition AreaMayWidenFrontSearch (0x8951DD) and
                 CAIUnit::RebuildAreaNeighbourProvinces (0x8BC860) both require on the branch where
                 CCountry::IsSameSide has already said no. NEW

CUnit
  +0x1E4  CUnitList  children - walked by slot 83 (0x8C0ACE), by CUnit::CollectSubtree (0x5BDAD7)
                 and by slot 83's division count (0x8C0B70). Already in the record
  +0x214/+0x21C  the plan's ops-area province CList and its count. Slot 83 compares its slice
                 against both at 0x8C13AC and 0x8C13DB to decide whether to post

CIDValue  (20 bytes, vftable 0x15EC094)
  +0x00  vftable        +0x04  0x18D, its type tag
  +0x08  int   the subordinate CUnit's object id type half  (CUnit +0x10)
  +0x0C  int   the serial half                              (CUnit +0x14)
  +0x10  int   REUSED: divisions * 1000 when built (0x8C0BB9), then quota * 1000 after the
               apportionment overwrites it (0x8C0DE8)

the AI's ordered map (local in slot 83 at [esp+0xA4]; the same shape as CAIUnit +0x294/+0x2D0/+0x30C)
  +0x00  byte  comparator        +0x04  sentinel node     +0x08  size
  node:  +0x00 next   +0x04 prev   +0x08 key   +0x0C value
  0x8DD000 ctor, 0x8DCF30 operator[], 0x8DD130 find(map@EAX, &out, &key),
  0x8DD980 insert fixup, 0x5147D0 node allocator. Circular with a sentinel, not an MSVC _Tree

constants slot 83 uses, none of them thousandths
  0x171DBAC  float  1.0        the largest-remainder carry test
  0x160A248  double 1.0        subtracted when the carry pays out
  0x160A7CC  float  1e7        the best-score seed (the same 10,000,000 SetArea pass E seeds with)
  0x160A598  float  1e6        the score when the subordinate's id does not resolve
  0x160A300  double 1000.0     penalty: a sibling already took this province / cannot reach it
  0x160A358  double 100.0      divisor: a province with only one neighbour inside the area
  0x160A538  double 500.0      penalty: outside the subordinate's own owner area but reachable
  0x160A83C  float  150.5      floorf'd to 150 in 0x8BD270
  0x160A7B4  float  50.5       floorf'd to 50 in 0x8BD270
```

## Functions this named

| address | rva | name | how sure |
| --- | --- | --- | --- |
| `0x8BE1C0` | `0x4BE1C0` | `Unit_GetAnchorProvince(unit@EDI, bool)` | read end to end |
| `0x8C1FC0` | `0x4C1FC0` | `CUnit::MeanDistanceToProvince` | read end to end |
| `0x5BDA90` | `0x1BDA90` | `CUnit::CollectSubtree` | read end to end |
| `0x5C7710` | `0x1C7710` | `CMapProvince::CanUnitReach` | head and tail; name is inference |
| `0x421D00` | `0x21D00` | `CountryTagVector_Contains` | read end to end |
| `0x895140` | `0x495140` | `AreaMayWidenFrontSearch` | read end to end; name is inference |
| `0x8C0D47` | `0x4C0D47` | slot 83's largest-remainder apportionment | read |
| `0x1A857F0` | `0x16857F0` | `g_PersistentIdTable_HighTypes` | from `FindPersistentById`'s use |
| `0x1A857F4` | `0x16857F4` | `g_PersistentIdTable_LowTypes` | the same |
| `0x8AFC30` | `0x4AFC30` | already recorded as `CAIUnit::~CAIUnit` — confirmed here as the **second and last** writer of the vftable, which is what closes section 1's method 5 | read |

## What is not established

1. **Whether slot 83 is dead *at runtime* as well as statically.** The static case is as strong as this folder can make it, but the claim that no subordinate ever gets an area is a claim about a running game. **Cheapest check, and it needs no hook:** `findInstances.py CAIUnit --dump 0xA0` and look at `+0x90`/`+0x94` on every agent whose `unit->oob_level != 0`. All empty confirms it; one non-empty refutes it.
2. **What `CCountry +0xCC` is.** One reader in the image through the `GetCountry` idiom (controls: 3, 2 and 6 for `officers`, `Manpower` and `effective_neutrality`), and `CCountry::LoadKey` never writes it, so there is no save oracle. Cheapest check: `dumpStruct.py` three or four countries of different sizes and compare `+0xC4` with `+0xCC`.
3. **The rest of `0x8BD270`'s middle.** The `+0xCC` ratio section (`0x8BD780`–`0x8BD8BC`) is read and so is the head; what the resulting `[ebp-0x3C]` is *used for*, and which list of `CCountryTag` the mean is taken over, are not. The tag list is at `[ebp-0x5C]` with stride 8 and its count at `[ebp-0x14]`; identifying it is the next step and wants `fieldchain.py --holder` from the top of the function.
4. **`0x8BBB50`'s middle**, still 3.3 KB unread — the largest unread body in the replan chain, and the one `project.json` carries an `inferred` name for.
5. **`0x8ADE10` and `0x8A9390`**, the other two `CAIStrategy` methods in `SetArea`'s front gate. Not touched here.
6. **`0x5C7710`'s middle**, and what its two bool arguments select. The second chooses between the `CPathFind` vftables `0x15C884C` and `0x15BE414`; identifying those two classes would name the two cost models, and `vtable.py --holding` on their slot 0 bodies is the cheap way in.
7. **Whether a province can really end up in two subordinates' slices.** The `+1000` for an already-taken province is a penalty and not an exclusion, and the score it is added to is a map distance that can exceed 1000. Static reading cannot say how often; it is moot while slot 83 is unreachable, and it is the first thing to check if anyone ever makes it reachable.
8. **Which kinds of object live in which of the two id tables.** The `0x1268` split is read and the pairing with `FindPersistentById` is read; the partition is not.
9. **`CCurrentGameState +0xD0C`'s role in `0x895140` step 9.** The record names it `scenario`, null in a loaded save, which would make that step behave differently in a fresh game and a reloaded one. Not verified, and a live read of the field in both situations is the whole check.
10. **Nothing was watched in a running game.** Besides item 1, two cheap falsifiers: `CArmy +0x2E8` should hold a plausible province id (1..the province count) on AI armies and zero on most others, which `dumpStruct.py` settles in one look; and `CAIUnit +0x90` should be non-empty on exactly the theatre-level agents.
