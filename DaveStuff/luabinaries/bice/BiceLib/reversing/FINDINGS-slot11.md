# Does anything outside `CCombat` slot 17 call `CCombatant` slot 11?

Read statically off `hoi3_tfh.exe` on 2026-10-02; the game was not running, so nothing here is
marked *seen*. Addresses are **virtual** (image base `0x400000`) with the rva beside them wherever
a finding depends on it. The question comes from `FINDINGS-combat3.md` §3 and its *What is not
established* item 1. Scripts are in `scratchpad/slot11/`.

> **Three claims re-derived independently before anything in the record was changed on their
> strength** (2026-10-02). (a) **No `imul [reg+0x54]` exists anywhere in the image** - a scan from
> 1,507 known function entries found 7 one-operand `imul` sites at the six product offsets and
> **zero** at `+0x54`, which is the claim the demotion in §6 rests on. That scan's entry set is far
> narrower than this file's 35,819, so it found 7 of the 11 sites rather than all of them - a
> weaker check that agrees, not a second full census. (b) The AI estimator's pair decodes exactly as
> reported at both sites: `mov eax,[esi+0xF8]; imul dword ptr [esi+0xF0]` at `0x8D981F`/`0x8D9825`
> and `0x8D9C34`/`0x8D9C3A`, each followed by `cvtdq2ps`, so it really is producing a float.
> (c) The extent arithmetic in §4's correction: `0x566477 - 0x5662F0 = 0x187` and
> `0x566477 - 0x565FD0 = 0x4A7`.
>
> **One claim in the original report was wrong and is struck here.** It said
> `reversing/fieldchain.py --holder` "still raises `TypeError` on every invocation". It does not -
> that bug was fixed on 2026-10-01, and `--holder 0xDA8 --index 50 --stride 8` reproduces the
> documented single reader at `0x1BB171`. The workaround the report describes was unnecessary.

## Confirmed live: 39,414 calls, three return addresses, all accounted for

**Added 2026-10-02, after the static work, by hooking the slot-11 body in a running game** (GER,
1942, 54 land combats and one naval). The probe recorded **39,414 calls with overflow 0**, its
slot counts summing exactly to the call total, and **exactly three distinct return addresses**:

| return address (rva) | calls | what it is |
| --- | --- | --- |
| `0x168EED` | 39,222 | **`CLandCombatant`'s own slot-11 forwarder**, the instruction after its `call 0x5662F0` at `0x168EE8` |
| `0x17B085` | 96 | `CCombat` slot 17, the attacker leg |
| `0x17B093` | 96 | `CCombat` slot 17, the defender leg |

**So the answer below is confirmed rather than overturned.** The first row looked like a fourth
caller when the probe first ran, and it is not: section 5 of this file already describes that
forwarder - ten instructions, `ecx` untouched, calling the base non-virtually, with its address in
exactly one place, `CLandCombatant`'s vftable `+0x2C`. It is the same two `CCombat` slot 17 call
sites arriving by way of the override whenever the combatant is a land one, which is why it carries
almost all the traffic: 39,222 against 192 in a land war. The probe's "expected" list had been
built from the two *external* sites and omitted it, which was a defect in the probe and not a
finding.

**What the live run adds to the static answer:** the one route the sweeps said they could not close
- the vcall thunk at `0x149E00` dispatched from the runtime-filled listener table - **did not fire
once in 39,414 calls**. That does not make it impossible, but it is the only evidence obtainable
without enumerating the listener registrations, and it points the same way as everything else.

**Coverage, stated honestly:** the session covered land and naval combat (the two known legs fired
96 times each, so non-land dispatches did happen). Bombing was not separately confirmed, and a kind
that never ran cannot be ruled on. `confirmed` for land and naval; the bombing arm rests on the
static reading alone.

---

## The caller is player-gated, which strengthens the conclusion

**Added 2026-10-02, after the sweeps.** `CCombat::UpdateCombatStatusWindow`'s one caller is
`CCombat::Tick` at `0x56F34C`, and that call is **conditional**:

```
0x56F2E9  mov eax, [edi + 0xC30]        ; edi is the game state - player tag
0x56F2EF  mov ecx, [edi + 0xC34]        ; player id
0x56F2F7  mov [esp+0x18], eax           ; into the local the gate is handed
0x56F2FE  mov [esp+0x1C], ecx
...
0x56F326  mov eax, [esi+0x14]           ; the DEFENDER combatant
0x56F329  add eax, 0x54                 ; CCombatant::countries
0x56F330  call 0x4A8630                 ; CountryIdListContains
0x56F337  jne 0x56F34C                  ; contains the player -> refresh
0x56F339  mov eax, [esi+0x10]           ; else the ATTACKER combatant
0x56F343  call 0x4A8630
0x56F34A  je  0x56F351                  ; neither -> skip the refresh entirely
0x56F34C  call 0x57BD70                 ; UpdateCombatStatusWindow
```

So the whole chain runs **only for combats the human player is a belligerent in**. An AI-vs-AI
battle never calls slot 17, never calls slot 11, and therefore **never reads `CSubUnit +0x54` at
all**.

Two consequences, and the first is the more important:

1. **The naval/air/bombing defence-side modifiers are not merely display-only, they are
   player-only.** They cannot be part of a symmetric simulation even in principle, because for
   every battle the player is not in they are never computed. That is a stronger claim than §6
   makes and it is `confirmed` from the instructions above.
2. **A live probe on slot 11 sees nothing unless the player is fighting.** An observer country
   gives zero calls, which must not be read as a negative result. `confirmed`.

---

## The answer, and the bound, first

**No. `CCombatant` slot 11 has exactly two invocations in the image, `0x57B083` and `0x57B091`,
both inside `CCombat` slot 17 (`0x57B050`), whose only call site is `0x57C15C` in
`CCombat::UpdateCombatStatusWindow` (`0x57BD70`).** `confirmed` of everything four sweeps can
see; `likely` as a statement about the whole executable, for the reasons in *What is not
established*.

**The bound, stated before the evidence because it is the part that matters.** The sweeps cannot
see:

1. **The observer route, and it is real rather than hypothetical.** `0x549E00` (rva `0x149E00`) is
   `mov eax,[ecx]; jmp dword ptr [eax+0x2C]` - MSVC's vcall thunk for a pointer-to-virtual-member
   at slot 11. It sits in **no** vftable and has **zero** direct callers, but its address appears
   six times in `.text`, every time as `push <subject>; push 0x549E00; xor eax,eax; call 0x8A2D70`.
   `0x8A2D70` (rva `0x4A2D70`) broadcasts over the doubly linked listener list at
   `0x1B14DC0 + channel*16` (rva `0x1714DC0`), calling `handler(subject)` with `ecx` set to each
   listener's target. **That table is filled at runtime.** A `CCombatant` registered as a listener
   target on that channel would have its slot 11 called with no `call [reg+0x2C]` anywhere to find.
   The six sites that exist are excluded below, but the general route is not closeable statically.
2. **1.80% of non-padding `.text`.** Measured, not quoted: `.text` is 9,609,216 bytes of which
   351,883 are `0xCC`; of the 9,257,333 non-padding bytes the decode reaches 9,091,159 (**98.20%**)
   and misses 166,174. (`FINDINGS-negatives.md` measured 6.7% for a smaller entry set; this entry
   set is 35,819 strong entries against that construction's 28,430, which is where the improvement
   comes from.)
3. **A receiver arriving in a register from a helper whose own caller got it from somewhere the
   sweep does not model.** The sweeps below cover the *argument* and the *calling convention* as
   well as the receiver, which is what makes them see argument-passed and helper-supplied
   receivers - 4 of the 14 final survivors had argument receivers - but there is no
   interprocedural points-to analysis here and I am not claiming one.
4. **Anything that happens only in a running game**, including a vftable patched at runtime.

Everything else in the question is closed:

* **Function pointers and thunks.** `image.findBytes` on the little-endian dword of each slot-11
  body returns **seven** addresses for `0x5662F0`, all in `.rdata` and all exactly `vftable+0x2C`
  (`CBomberCombatant`, `CGroundTargetCombatant`, `CNavalTargetCombatant`, `CLandTargetCombatant`,
  `CCombatant`, `CNavalCombatant`, `CAirCombatant`), and **one** for `0x568EE0`
  (`CLandCombatant`'s). **Nothing in `.text` holds either address.** There is no `jmp rel32` and no
  `jmp rel8` to either, and the only `call rel32` to either is `0x568EE8`, the forwarder calling
  the base. So neither body's address is ever taken.
* **Subclass overrides.** `CCombatant`'s derivation closure is **nine** classes, eight of which
  carry a vftable, and there are exactly **two** distinct slot-11 bodies in it.
* **Inlining.** The body is 391 bytes and the distinctive arithmetic occurs nowhere else.

---

## 0. Method, and the positive control the brief asked for first

### The entry set

`scratchpad/slot11/entries.py`, rebuilt from scratch because `scratchpad/combat3/entries2.py` is
gone, to the construction `FINDINGS-combat3.md` §0 describes: `V` a slot of a vftable in the RTTI
export read as `vftable + slot*4` **out of the image** rather than from `introduces` (trap 10),
`P` the first byte after a run of **two or more** `int3`, `C` the target of a `call rel32` decoded
from a `V` or `P` entry. The `p` source (first byte after a *single* `0xCC`) is left out, because
`8b cc` is `mov ecx, esp` and its `cc` makes the next byte look like an entry - combat3's own
false-positive generator.

```
vftables read: 2707
V 6002   P 33191   C 12189   strong union 35819
```

Attribution takes the nearest strong entry at or below an address. The three controls combat3
used all pass:

```
owner(0x0056645E) = 0x005662F0   (slot 11, not ApplyLosses - traps 2 and 3)
owner(0x0056AD8D) = 0x00569B50   (CLandCombatant::ApplyCombatModifiers)
owner(0x0057B083) = 0x0057B050   (CCombat slot 17)
```

### Sweep A: the two-field signature, which is the method the brief proposed

`scratchpad/slot11/slotsweep.py` decodes every strong entry forward to the first run of two `int3`
and runs a one-pass register taint over the decode, so each virtual call's **receiver** is tied to
where it came from rather than to a bare displacement (trap 12). Both MSVC forms are recognised -
`mov r,[vt+0x2C]; … ; call r` and `call dword [vt+0x2C]` - and a `+0x2C` load whose base's own
provenance is unknown is tagged `opaquevt` and **kept**, because a dropped site is a false negative
and this scan's whole value is its silence.

```
slot 11 (+0x2C): 1033 call sites over 35819 strong entries
bodies using both +0x10 and +0x14: 7143 of 31985 decoded bodies
```

(combat3's linear scan found 1,157; the difference is that this one decodes from entries rather
than sweeping `.text` - trap 9 - and invalidates a register on any write to it.)

The signature as proposed: keep only sites whose **receiver register was loaded from `+0x10` or
`+0x14`** in a body that uses **both**.

**It leaves 22 sites, and both known invocations are among them. The positive control passes.**

```
0x004D9896  owner 0x004D94A0  +0x14   afterLoad=0 back=0
0x004E8B8E  owner 0x004E7B00  +0x14   afterLoad=0 back=0
0x004E99E8  owner 0x004E9220  +0x14   afterLoad=0 back=0
0x0057B083  owner 0x0057B050  +0x10   afterLoad=1 back=1   <- the known control
0x0057B091  owner 0x0057B050  +0x14   afterLoad=1 back=1   <- the known control
0x0069A1CD  owner 0x00699CD0  +0x10   afterLoad=0 back=0
0x007CB485  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x007CB532  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x007CB67A  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x007CB77C  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x007CB880  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x007CB985  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x007CBA35  owner 0x007CB1C0  +0x14   afterLoad=2 back=2
0x009B79AF  owner 0x009B7930  +0x14   afterLoad=0 back=0   CLeaveAllianceEffect slot 11
0x00A12216  owner 0x00A12030  +0x14   afterLoad=0 back=0   CDeclareWarAction slot 7
0x00A19A96  owner 0x00A18D70  +0x14   afterLoad=0 back=0   CAllianceAction slot 7
0x00A2853B  owner 0x00A27BA0  +0x14   afterLoad=0 back=0   CCallAllyAction slot 7
0x00A29716  owner 0x00A27BA0  +0x14   afterLoad=0 back=0   CCallAllyAction slot 7
0x00A31B60  owner 0x00A30E70  +0x14   afterLoad=0 back=0   CFactionAction slot 7
0x00A49719  owner 0x00A48B20  +0x14   afterLoad=0 back=0
0x00BF270D  owner 0x00BF26B0  +0x10   afterLoad=2 back=2
0x00BF2786  owner 0x00BF2720  +0x10   afterLoad=2 back=2
```

**The 20 others are excluded on the calling convention, and the exclusion is sound in one
direction.** `CCombatant` slot 11 is `int* __thiscall (int* out)`: both bodies end `ret 4`, so a
call to either pushes exactly one dword. Eleven of the twenty push **none** and nine push **two**.
The count `afterLoad` - pushes strictly between the `mov reg,[vt+0x2C]` and the `call` - is a
**sound lower bound** on the argument count, because nothing between the slot load and the call can
be building anyone else's call; so `afterLoad >= 2` excludes a `ret 4` callee outright. The other
count, `back` (walking back to the previous `call`, `add esp` or the body start), is the usual
argument-region heuristic and is not sound in either direction on its own. **Both counts agree on
all 22.**

**The signature's entire false-positive population is diplomacy and GUI code, and that is trap 12
in a form worth writing down: `+0x10`/`+0x14` is a pair on at least three other classes in this
image.** Seven of the eleven zero-argument sites load the receiver from
`country->diplomacy_status (+0xE28)[id]->+0x14` - the `+0xE28` array `project.json` already
names - and all five owner classes that RTTI identifies are alliance or faction diplomacy
(`CDeclareWarAction`, `CAllianceAction`, `CCallAllyAction`, `CFactionAction`,
`CLeaveAllianceEffect`). `CDiplomacyStatus` has `+0x10` (`occupation_policy`) and `+0x14`, and the
`nap` at `+0x28` is a `CRelation` whose own `+0x10`/`+0x14` is the `second` party. And
`CUnit +0x10`/`+0x14` is `type`/`id`. The signature is selective because a `CCombatant` pointer is
only ever produced at `CCombat +0x10`/`+0x14`, not because the displacement pair is rare.

### What the signature cannot see - stated explicitly, because the answer is bounded by it

The signature reads the **receiver's** provenance, so it is blind to:

* a receiver **passed in as an argument** (`[ebp+8]`, `[esp+N]`);
* a receiver arriving **in a register from a helper** (the `ret` of a previous call);
* a receiver whose vftable pointer was spilled and reloaded, so its own provenance is lost;
* a call through a **function pointer** or a **thunk**, which is not a `call [reg+0x2C]` at all;
* a **tail call** (`jmp`), which has no `call` instruction in it.

Three further sweeps were run precisely because of that list, and they do not share the blind spot.

---

## 1. Sweep B: the calling convention, independent of the receiver

Over all 1,033 sites:

```
afterLoad >= 2  (soundly NOT a one-dword call) : 201
afterLoad <= 1                                 : 832
   of those, back == 1 (a one-dword call)      :  55
```

Of the 55 one-dword sites, exactly **two** have a receiver loaded from `+0x10` or `+0x14` - the
control pair. Only four of the 55 are anywhere in `0x550000..0x5F0000`:

| site | owner | what it is |
| --- | --- | --- |
| `0x5613F3` | `0x560B90` | `test al,al; je` right after - `CSubUnit::IsAir`, one of the five calls combat3 §4 documents in this body. `back` over-counted a `push ecx` belonging to the other arm of a `jmp` at `0x5613E7`, which is that heuristic's failure mode caught in the act |
| `0x57B083`, `0x57B091` | `0x57B050` | the control |
| `0x5CC1A9` | `0x5CB980` | see §2 |
| `0x5E3B94` | `0x5E3AD0` | `CLoadArmyCommand` slot 6; the pushed dword is an **object** pointer (`esi`), not a stack address, and the following instruction is `call 0x5CF040` |

---

## 2. Sweep C: the out-pointer, also independent of the receiver

`CCombatant` slot 11 returns a `CFixedPoint` by value through a hidden out parameter. Read from
the body:

```
0x005662F0  push ebp; mov ebp,esp; sub esp,0x14
0x005662F6  mov eax,[ecx+0x40]        ; this->units
0x005662FA  mov edi,[ebp+8]           ; the out pointer
0x00566300  mov dword ptr [edi], 0    ; <- it ZEROES what it is given, immediately
...
0x00566434  add dword ptr [edi], eax  ; one dword, accumulated
0x0056644C  mov eax, edi              ; returned in eax as well
0x00566452  ret 4
```

So a caller always pushes the address of a local. `scratchpad/slot11/outptr.py` keeps every site
that pushes a stack address (`lea reg,[ebp±N]` / `lea reg,[esp+N]`, then `push reg`) within twelve
instructions of the call:

```
sites that push a stack address: 374 of 1033
control (0x57B083, 0x57B091) survives: yes
```

(combat3's equivalent filter left 362 of 1,157, so the two agree.)

**Sweep B and Sweep C together leave fourteen sites in the whole image**, and the two controls are
among them. The other twelve, each read by hand:

| site | owner | why it is not slot 11 |
| --- | --- | --- |
| `0x4381F7` | `0x4355B0` | the out's **two** dwords are read - `add esi,[eax]; mov eax,[eax+4]` - and slot 11 writes only `[out]` |
| `0x453237` | `0x4505F0` | identical idiom |
| `0x454CD0` | `0x4534A0` | identical idiom |
| `0xA55E70` | `0xA54640` | identical idiom |
| `0x5CC1A9` | `0x5CB980` | the **same** `[esi]+0x2C` slot is called at `0x5CB9B5` with no argument and the result's `+0x2EC` is read, which is `CProvince::combats`; so that class's slot 11 returns a province. The stack address pushed at `0x5CC1A3` belongs to the following `call 0x5D00A0` (`movd xmm0,[eax]; cvtdq2ps`), which is this filter's false positive caught in the act |
| `0x603D68` | `0x601DE0` | the frame slot is bracketed by unwind-state writes (`mov byte [esp+0x116C], 0x5D` -> `0x5E`) and preceded by `call 0x40A160`, so the hidden return is a class with a destructor - a `std::string`. A four-byte `CFixedPoint` out slot needs no unwind entry |
| `0x604045` | `0x601DE0` | same |
| `0x8270D0` | `0x826F40` | same (`mov byte [ebp-4], 0xA` -> `0xB`) |
| `0xA8FC10` | `0xA8F9B0` | the out is read as `movzx edi, word ptr [eax+2]` - a pair of 16-bit fields - beside GUI margins at `+0x144`/`+0x148`/`+0x178`/`+0x17C` |
| `0xA8FC35` | `0xA8F9B0` | same |
| `0xA90087` | `0xA8FEA0` | same |
| `0xA900AC` | `0xA8FEA0` | same |

Two more out-pointer survivors sit in the combat and unit modules but failed Sweep B, and both are
clear: `0x5595FD` (`0x5594D0`) pushes two dwords and its receiver is `lea ecx,[edi+0x28]`, the
address of an embedded sub-object rather than a pointer; `0x5CFD81` (`0x5CFBD0`) pushes nothing
between the slot load and the call - the two pushes before belong to `call 0x68DA00` - and the
result is used as an object base (`add eax,0x2E4; call 0x5D6690`).

---

## 3. Sweep D: tail calls, which a `call`-only scan cannot see - and the one real hole

MSVC turns `return this->slot11(out);` into `mov reg,[vt+0x2C]; jmp reg` or
`jmp dword [vt+0x2C]`. That is a virtual call with no `call` in it, and **this image does it**:
`0x66329F` is `mov eax,[edx+0x30]; … ; jmp eax`, a tail call through slot 12.

`scratchpad/slot11/tailcall.py` finds **15** `jmp`-form dispatches through `+0x2C`, and the control
at slot 12 (`0x66329F`) is present, so the scan works. None of the 15 is in
`0x550000..0x5F0000`, and none of their owners sits in a `CCombatant`-family vftable. Fourteen are
small forwarders inside real functions, reachable only as vftable slots or by direct call
(`CCgmBar`/`CCgmDiploSlider` slot 5/4, `CTheatreView` slot 2, a 50-table slot 9 body at
`0x63D8D0`, `CFrontEnd` slot 87, `CBrigadePicker` slot 2, the `CSideMenu` family slot 5, a
128-table slot 20 body at `0xA8BE40`, and `0xBF0EE0` which has no references at all).

**The fifteenth is the hole.** `0x549E00` (rva `0x149E00`) is two instructions:

```
0x00549E00  mov eax, dword ptr [ecx]
0x00549E02  jmp dword ptr [eax + 0x2c]
```

It is in **no** vftable and has **zero** direct callers, but `image.findValue(0x549E00)` returns
six `.text` references and every one is the same shape:

```
0x00547ED8  add  esp, 8
0x00547EDB  mov  ecx, edi
0x00547EDD  call eax                 ; eax = edi->slot 9 ()
0x00547EDF  push eax                 ; the subject
0x00547EE0  push 0x549e00            ; the handler, as a function pointer
0x00547EE5  xor  eax, eax            ; channel 0
0x00547EE7  call 0x8a2d70
```

| push site | owner | owner is |
| --- | --- | --- |
| `0x547EE0` (rva `0x147EE0`) | `0x547930` | `CCreateUnitCommand` slot 6 |
| `0x57DF60` (rva `0x17DF60`) | `0x57D480` | `CUnitDeployment` slot 9 |
| `0x5DFF9E` (rva `0x1DFF9E`) | `0x5DF600` | `CCreateHigherCommand` slot 6 |
| `0x5E11C5` (rva `0x1E11C5`) | `0x5E0BB0` | `CCreateNewHQCommand` slot 6 |
| `0x5EBCD1` (rva `0x1EBCD1`) | `0x5EB970` | in no vftable |
| `0x63DFEA` (rva `0x23DFEA`) | `0x63DE70` | in no vftable, and here the thunk is one of a long run of pushes into a constructor-like call at `0x63EAF0` |

`0x8A2D70` (rva `0x4A2D70`), read end to end, is a broadcast:

```
void __cdecl BroadcastToListeners(handler, subject, channel@EAX)   ; bare ret at 0x8A2DF1
    ecx = subject->+0x198
    if (ecx) handler(subject)                        ; call [ebp+8] with subject pushed
    node = *(0x1B14DC0 + channel*16)
    for (; node; node = node->+8)
        ecx = node->+0                               ; the listener's target
        if (ecx) handler(subject)
        ... unlink nodes marked dead at +0xC ...
```

So `0x549E00` means "the handler is **slot 11 of the listener's target**, with the subject as its
single stack argument". That is exactly a call through a function pointer, and `vtable.py
--holding` and `findRefs.py --callers` both say nothing about it.

**Why it is not these six, and why the general route stays open.** Slot 11's *first* act is
`mov dword ptr [arg], 0`. At all six sites the argument is an object pointer - the result of
`subject->slot 9()` - so a `CCombatant` registered on channel 0 would zero that object's vftable
pointer on the first unit creation. These are the ordinary unit-creation command paths, so that
cannot be what happens. But **the listener table at `0x1B14DC0` is written at runtime**
(`0x8A2E9D`/`0x8A2EA4` are the add/remove side), so which classes ever register, and on which
channel, is not in the bytes. **This is the one route by which the answer could still be wrong, and
it is why the claim is `likely` rather than `confirmed` of the whole image.** Note also trap 4:
`0x549E00` is a compiler-emitted vcall thunk for a slot *index*, so it is class-free and must not
be named after `CCombatant`.

---

## 4. Sweep E: inlining - the body is too big, and its arithmetic occurs nowhere else

**Size.** `0x5662F0` is **133 instructions, 0x187 bytes** (`0x5662F0` to the `int3` at `0x566477`),
with a nested double loop over `units` (`+0x40`) and each unit's `regiments` (`+0x38`), two virtual
calls and three calls to the 64-bit `/1000` helper `0xB99980`. It is not an inlining candidate.

> **Correction to `FINDINGS-combatmods.md` §9.** That file says "the function really runs to the
> `int3` at `0x566477`, so its extent is `0x4A7` bytes." `0x566477 - 0x5662F0` is `0x187`. `0x4A7`
> is `0x566477 - 0x565FD0`, i.e. measured from `CCombatant::ApplyLosses` - the last surviving
> residue of the trap-2 misattribution that the rest of that paragraph corrects. **Both figures
> re-checked by hand 2026-10-02.**

**And the arithmetic is not duplicated.** `scratchpad/slot11/inlinetest.py` scans for the
distinctive instruction: a **one-operand `imul` with a memory operand** at a combat-modifier
product offset. MSVC emits that form only for a widening 32x32->64 multiply, which is what the
`/1000` helper needs, so it is far more selective than a displacement scan. Image-wide there are
450 one-operand `imul <mem>` sites; **eleven** are at `+0x50`/`+0x54`/`+0xEC`/`+0xF0`/`+0xF4`/`+0xF8`:

| site | owner | what |
| --- | --- | --- |
| `0x56637C` (rva `0x16637C`) | slot 11 | `imul [ebx+0xf0]` - the **land** arm, defence product. *Control* |
| `0x566399` (rva `0x166399`) | slot 11 | `imul [ebx+0xec]` - the land arm, attack product. *Control* |
| `0x566461` (rva `0x166461`) | slot 11 | `imul [esi+0x50]` - the naval/air arm. *Control* |
| `0x5AC388` (rva `0x1AC388`) | `CSubUnit::AddCombatModifier` | the adder's own product update |
| `0x5C30D7` (rva `0x1C30D7`) | `CUnit::AddCombatModifier` | the adder's own product update |
| `0x56AED2` (rva `0x16AED2`) | `CLandCombatant::FireUnit` | `imul [esi+0xf4]` |
| `0x51D2F6` | `0x51CE60` | `imul [esp+0x50]`, a stack local, irrelevant |
| `0x72AE90` (rva `0x32AE90`) | `0x729D40` | the battle unit tooltip - see §6 |
| `0x72AED5` (rva `0x32AED5`) | `0x729D40` | the battle unit tooltip - see §6 |
| `0x8D9825` (rva `0x4D9825`) | `0x8D93B0` | **the AI land-attack-odds estimator** - see §6 |
| `0x8D9C3A` (rva `0x4D9C3A`) | `0x8D93B0` | the same, second site |

Slot 11's own three are all present, which is the control. **There is no `imul [reg+0x54]` anywhere
in the image**, and no second `imul [reg+0x50]` outside the two adders and slot 11. So there is no
inlined copy of slot 11's naval/air arm.

---

## 5. The subclasses, enumerated from RTTI - and one class the export carries with no vftable

`scratchpad/slot11/family.py` walks the derivation closure and reads every slot 11 as
`vftable + 0x2C` out of the image (trap 10):

```
CCombatant closure: 9 classes
CCombatant               table 0 0x015C4CA4 (26 slots)  slot 11 = 0x005662F0
CAirCombatant            table 0 0x015C4E74 (26 slots)  slot 11 = 0x005662F0
CBombTargetCombatant     NO VFTABLE IN THE EXPORT
CBomberCombatant         table 0 0x015C45DC (26 slots)  slot 11 = 0x005662F0
CLandCombatant           table 0 0x015C4DFC (28 slots)  slot 11 = 0x00568EE0
CNavalCombatant          table 0 0x015C4D8C (26 slots)  slot 11 = 0x005662F0
CGroundTargetCombatant   table 0 0x015C464C (26 slots)  slot 11 = 0x005662F0
CLandTargetCombatant     table 0 0x015C472C (26 slots)  slot 11 = 0x005662F0
CNavalTargetCombatant    table 0 0x015C46BC (26 slots)  slot 11 = 0x005662F0

distinct slot-11 bodies in the closure: 2
```

**`CBombTargetCombatant` has zero vftables in the export, and that is not the same as being
absent** - it derives from `CCombatant`, the three target combatants derive from *it*, and it
`introduces` nothing. It is the abstract base, never instantiated, so no table was emitted. Three
checks say the export is not simply missing one: the two bodies' dwords appear exactly 8 times in
the image and all 8 are accounted for above; the `.rdata` gap between the target-combatant run
(ending `0x15C4794`) and `CCombatant`'s table (`0x15C4CA4`) holds the `BM_*` localisation key
strings and no code pointers; and every class with a table in that region is in the export.

> **A naming note for `FINDINGS-combatmods.md`.** Its census table has a row
> "`CTargetCombatant::ApplyCombatModifiers 0x5627D0` … shared by all three target combatants".
> `CTargetCombatant` is not a name in the RTTI export. The shared base is
> **`CBombTargetCombatant`**, and because it has no vftable, `0x5627D0` is held at slot 19 by the
> three concrete target classes directly.

`CLandCombatant`'s `0x568EE0` is the only override and it is a pure forwarder - ten instructions,
`ecx` never touched, `call 0x5662F0` non-virtually, `ret 4` - with no direct callers and its address
in exactly one place, `CLandCombatant`'s vftable `+0x2C`. So the override adds no caller the base
does not have.

---

## 6. What this does to `FINDINGS-combatmods.md` - and the half that survives

### `CSubUnit +0x54`: demote

`project.json` already says `+0x54` is "read at `0x56645E` and nowhere else". Two checks here
corroborate it from different directions:

* **The pair scan.** `scratchpad/slot11/productscan.py` finds every site where `[R+0x54]` and
  `[R+0x50]` are used on the same register within six instructions, excluding `esp`/`ebp` bases:
  **435 sites, and exactly one is a multiply** - `0x56645E`/`0x566461`. Its control is that the
  same scan finds the known **write** pair, `0x565640`/`0x565643`
  (`mov [esi+0x50], 0x3E8; mov [esi+0x54], 0x3E8`) inside `CCombatant::ApplyCombatModifiers`
  (`0x565590`, the base slot 19), which is a `CSubUnit +0x50`/`+0x54` pair in the same module - so
  the method can see this field.
* **A neighbour scan that is honestly too weak to use.** `scratchpad/slot11/sub54.py` looks for
  every read of `[R+0x54]` where `R` is also used with two or more of `+0x58`/`+0x5C`/`+0x60`,
  which is trap 12's distinctive-neighbour fallback. It returns **194 candidates** and finds the
  control, but it is not selective, and the reason is itself a trap-12 instance: **`CCombatant
  +0x50` is `dice` and `CCombatant +0x54` is `countries`**, with the `CCountryTag` triple at
  `+0x54`/`+0x58`/`+0x5C` - so `0x56522B` (`CCombatant` slot 12) and `0x565375`/`0x5653B8`
  (`CCombatant` slot 13) match the filter while reading a completely different field. The pair scan
  is the evidence; this one is only consistent with it.

So the chain is: the 48 `CSubUnit::AddCombatModifier` sites -> `CSubUnit +0x54` -> `CCombatant`
slot 11's naval/air arm -> `CCombat` slot 17 -> `0x57BD70` -> the `combat_status` billboard's frame
and percentage.

**`FINDINGS-combatmods.md` §9 and its *Not established* list say "The defence-side modifiers are
live." That sentence should be struck and replaced**, because "live" was earned only against the
claim that `+0x54` had no reader at all. The replacement: *`CSubUnit +0x54` has exactly one reader,
and everything it reaches is a display quantity, so the defence side of every naval, air and
bombing combat modifier - including the two defence-only ids - is cosmetic in this build.* The two
defence-only ids named by the census are `BM_POOR_SCREEN_PENALTY` (sites `0x566756` naval and
`0x5629FE` bombing target, attack 0 / defence `-penalty`) and the bombing target's
`BM_FORT_MODIFIER` (`0x562A69`, attack 0 / defence `+100` per level). **A mod cannot reach the
simulation through either.** The attack side is unaffected: `+0x50` multiplies the shot count in
`CNavalCombatant::Attack`.

### `CUnit +0xF0`: do **not** demote. There is a second reader, and it is the AI

This is the part that stops the subtraction from going too far, and the census did not have it.
Slot 11's **land** arm multiplies `CUnit +0xEC`/`+0xF0` - and `+0xF0` (`combat_defend_product`) is
read in two places outside the combat module:

* `0x729D40` (rva `0x329D40`), which `project.json` already names **"the tooltip for a unit hovered
  in a battle"** and whose fields include `BATTLE_ATTACKMOD` and `BATTLE_DEFENDMOD`. It reads
  `+0xEC`, `+0xF0`, `+0xF4` and `+0xF8` and multiplies two pairs at `0x72AE90` and `0x72AED5`.
  Display again.
* **`0x8D93B0` (rva `0x4D93B0`), the AI's land-attack-odds estimator**, which `project.json`
  records with "the body was NOT read" and whose returned float is compared against
  `LandAttackOddsThresholdForStance` and the 3.0 / 1.5 / 1.1 attack bars and the 0.8 abort bar in
  `CAIUnit_ManageLandUnits`. It reads `[esi+0xF8]` and multiplies by `[esi+0xF0]` at **two** places,
  `0x8D9825` and `0x8D9C3A`, and reads **none** of `+0xEC`, `+0xF4`, `+0xDC` or `+0xE4`.

So the **land** defence product reaches a decision the AI acts on - whether to commit a unit to an
attack and whether to call the attack off - and not only a number on screen. `likely`, not
`confirmed`: that `esi` is a `CUnit` rests on the distinctive-neighbour test (`+0xF0` with `+0xF8`
is the `CUnit` defend pair and nothing else in the record pairs those two), the register is not
tied by `fieldchain.py --holder`, and `0x8D93B0`'s body is recorded as unread, so *when* the
products are non-neutral at that point - they are reset to 1000 every tick by slot 19 - was not
established.

**The headline therefore halves rather than disappears.** The census's defence side is cosmetic for
naval, air and bombing; for land it is read by the AI.

### Two small completions

* `FINDINGS-combat3.md` §3 says slot 17 is held by "`CCombat`, `CLandCombat`, `CAirCombat`,
  `CNavalCombat`, `CGroundBombing`, `CLandBombing` and one more". **The seventh is
  `CNavalBombing`** (table `0x15B6A24`). The `CCombat` closure is eight classes with one distinct
  slot-17 body; the eighth is **`CBombing`**, the abstract base of the three bombings, which like
  `CBombTargetCombatant` carries no vftable in the export.
* `findRefs.py --callers 0x57B050` -> 0; `--callers 0x57BD70` -> 1, at `0x56F34C`. Both as recorded.

---

## 7. Why the same method does *not* close `FINDINGS-combat3.md`'s open item 1

combat3 proposed the two-field signature for **`CCombat` slot 17** (`+0x44`). It was run, with the
same two filters:

```
slot 17 (+0x44): 1871 call sites
afterLoad >= 2 (soundly not a one-dword call):  32
one-dword on the usual heuristic:              731
pushes a stack address:                        797
both:                                          573
control 0x0057C15C in both: True
```

**573 survivors is not an answer.** The control passes, but the filters that cut slot 11 from 1,033
to 14 cut slot 17 only from 1,871 to 573 - and the reason is worth recording, because it says when
the method works. The discriminating power came from the **receiver's production site**, not from
the filters: a `CCombatant` pointer exists only at `CCombat +0x10`/`+0x14`, written by
`CreateCombatants`, so "receiver loaded from `+0x10`/`+0x14`" is nearly a complete description of
how one is obtained. A `CCombat` pointer is reachable from the manager's list, from
`CMapProvince +0x2EC` and `+0x2FC`, and from every combat's own `this`, so no two-field signature
exists for it.

The one useful thing the slot-17 run does say: **of the 573, exactly one is in
`0x550000..0x5F0000`, and it is `0x57C15C`, the control.** So combat3's statement that the combat
module's `+0x44` sites contain exactly one `CCombat` receiver reproduces under a completely
different scan. The UI and AI regions remain un-enumerated for slot 17, and this file does not close
them.

---

## What is not established

1. **The observer route.** `0x549E00`'s listener table at `0x1B14DC0` (rva `0x1714DC0`) is filled
   at runtime by `0x8A2E9D`/`0x8A2EA4`, so which classes register as handler targets, and on which
   of the 16-byte-strided channels, is not in the bytes. **This is the single thing that could
   overturn the answer.** *Cheapest check:* `findRefs.py --callers` on the registration function
   and a look at what each caller's target object is - a static enumeration of registrants may be
   possible, and it was not attempted. A live check is cheaper still: a breakpoint on `0x549E00`
   with `ecx`'s vftable logged.
2. **1.80% of non-padding `.text`** is outside the decode - 166,174 bytes. Every negative above is
   bounded by it.
3. **`back`, the second argument count, is not sound in either direction.** It over-counted at
   `0x5613F3` (a push belonging to the other arm of a `jmp`) and it would under-count a push more
   than a few instructions back. The sound half is `afterLoad >= 2`, which excludes 201 of the
   1,033 sites and nothing more.
4. **The out-pointer filter's window is twelve instructions**, and it does not see an out slot
   lea'd much earlier, nor one that is not a stack address at all. Its false-positive behaviour is
   demonstrated at `0x5CC1A9`, where the pushed address belongs to the *next* call.
5. **`CDiplomacyStatus +0x14` is a pointer to a polymorphic object whose slot 11 takes no stack
   argument**, read by `CDeclareWarAction` slot 7, `CAllianceAction` slot 7, `CCallAllyAction`
   slot 7, `CFactionAction` slot 7 and `CLeaveAllianceEffect` slot 11. Those five names make
   "the pair's alliance" the obvious guess and that is **not enough to name it**:
   `CDiplomacyStatus::LoadKey` (rva `0x648190`) stores only `+0x10`, so there is no loader key and
   no writer. Deliberately left unnamed; it is a by-product of this sweep, not its subject.
   *Cheapest check:* read one of the five slot-7 bodies, or find the writer.
6. **Whether `esi` in `0x8D93B0` is a `CUnit`**, and whether the products are ever non-neutral when
   that function runs. `likely` on the `+0xF0`/`+0xF8` pair; the body is recorded as unread.
   *Cheapest check:* read `0x8D93B0`, which `CANDIDATES.md` already wants read.
7. **Slot 17's 573 dual-filter survivors outside the combat module were not read**, so
   `FINDINGS-combat3.md`'s open item 1 is *not* closed by this file. What is added is that the
   proposed method cannot close it, and why.
8. **Nothing was watched in a running game.** Three live checks, in order of value: (a) break on
   `0x5662F0` and confirm the only return addresses are `0x57B085` and `0x57B093` - one battle
   settles the whole of this file; (b) break on `0x549E00` and log `[ecx]` to see whether a
   `CCombatant` vftable ever appears, which is the only way to close item 1; (c) give a ship a
   large defence-only modifier (`BM_POOR_SCREEN_PENALTY` through a screen shortage) and confirm the
   `combat_status` percentage moves while the naval damage does not - that is §6's prediction and
   it is directly testable.
