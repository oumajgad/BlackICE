# Traps

Every one of these has cost real time here, and most have put a **wrong claim into the record**
at least once. They are numbered so the findings files can cite them; the numbers are stable and
nothing is renumbered, so a new trap goes on the end even when it belongs with an earlier one.

This is the canonical list. `findings/README.md` used to carry a shorter unnumbered version and
now points here.

Read trap 3 first if you are short of time. It is the most expensive one in the folder: it has
produced a wrong vftable slot attribution, a wrong function extent and a **false negative about
a game mechanic**, which is the worst failure available here because a negative looks like a
finding.

---

## 1. Virtual address against rva

The image base is `0x400000`. Disassemblers and Ghidra print **virtual** addresses;
`ghidra/project.json` and the `GameClasses/*.hpp` offsets are **rvas** (the headers call the same
thing "module relative"). `CLASSES.md` declares at its head that its own addresses are rvas, and
all 57 vftable addresses in it are correct read that way.

**Magnitude does not tell you which is which.** `.text` runs to about `0x970000`, so an rva here
is routinely larger than the image base.

*The check:* `image.both()` prints both forms - use it in anything you report.

*It has bitten:* a check of `RunHourlyAITrade` (rva `0xDC410`) run against VA `0x5DC410` instead
of `0x4DC410`, which found no string references and nearly became "no references". And an agent
recording the shared stub `0xA806D0` - a **virtual** address - as an rva, which pointed at
`0xE806D0`. The second was caught by `buildFindings.py` rather than by review, which is the
argument for running the pipeline before believing a batch of entries.

## 2. Abutting functions

`image.functionStart` walks backwards to the previous padding. Where two functions abut with a
single `int3` or none, it lands in the **previous** function and every offset computed from that
entry is wrong.

*The check:* `image.retsBefore(candidate, address)`. A `ret` in between means look - it is either
an abutting function or trap 3.

*Known pairs:* **`0x565FD0`/`0x5662F0`** (`CCombatant::ApplyLosses` ends `ret 4` at
`0x5662ED` and slot 11's prologue is the very next byte — this one produced a wrong finding, see
trap 3), `0x8B5210`/`0x8B60F0` (one `int3` between, so a scan looking for a *run* of padding
misses it), `0x5A8540`/`0x5A8690`, `0x682630`/`0x682C20`, `0x9C0520`/`0x9C0A40`,
`0x4C3B10`/`0x4C3C00`,
`0x52E3A0`/`0x52EBE0`, `0x49DD00`/`0x49DE80`, `0x4BFE70`/`0x4BFED0`, `0x8D5510`/`0x8D5530`,
`0x8BA05C`/`0x8BA060`, `0x68EBA0`/`ProcessUnitFunctor::execute`, `0x8ACD00`/`0x8ACD50`, `0x893C80`/`0x893E70` (the first ends `ret 8` at `0x893E6D` with no padding at all, so `functionStart(0x893E70)` answers `0x893C80` - and `0x893E70` is the AI's real landing-province chooser, so losing it loses the end of the invasion chain).

Getting `0x4BFE70` wrong would have made `0x4C0430`'s whole argument list wrong, which is most of
a section of `FINDINGS-revolt.md`.

**The same symptom has a second cause, and it is not abutment.** `functionStart` only accepts a
candidate whose first byte is in its prologue set, so a function that opens with anything else is
walked straight past *even when it is properly padded*. Two have been found this way in one day:
rva `0x963F0` opens `push ecx` (`0x51`, added) and rvas `0xA9B70` and `0xA9BE0` both open
`cmp byte ptr [eax+0x22], 0` (`0x80`, added) - the second pair has an `int3` between them, so
abutment was not the problem at all. The set is now
`55 53 56 57 8B 83 81 6A 68 51 52 50 80`.

Widening it is safe in a way worth knowing, because widening a heuristic usually is not: the byte
is only ever tested at a position immediately **after** an `int3`, so a new byte cannot make the
walk stop inside a function - only at a real boundary it was crossing before. If a function's
opening byte is not in that list, `functionStart` will quietly return something earlier, and the
only symptom is that `retsBefore` reports a `ret` you cannot explain. **An unexplained `ret` is
sometimes the tool's fault rather than the image's.**

## 3. A `ret` is not the end of a function

The converse of trap 2, and the expensive one. A cold path or an exception-handling funclet sits
**after** the function's `ret`, in the same frame, reached by a jump from inside. Stopping at the
`ret` silently drops it.

*The checks, in order of cost:*
- Does anything jump to the block? One scan of the function for a branch target past the `ret`
  settles it.
- Do the stack offsets fit the same frame? A `[esp+0x1B4]` under a `sub esp, 0x1A0` cannot be a
  new frame.
- Is the next address a vftable entry? If the following slot's body starts there, the `ret`
  really was the end.

*Known cases:*

| function | the `ret` | what is past it |
| --- | --- | --- |
| `CPersistent::Load` `0xA7C050` | `0xA7C11A` | the error path, exits again at `0xA7C39F` |
| `ProcessAI` `0x8894E0` | `0x889618` | second exit at `0x88986A` |
| `CAIUnit` slot 78 | `0x8B32AC` | an EH funclet to `0x8B32DF` |
| `ResolveConvoyRaid` `0x5D1250` | `0x5D201C` | the success path at `0x5D201F` |
| `CCombatant` slot 11 `0x5662F0` | `0x566452` (`ret 4`) | **the branch that reads `CSubUnit +0x54`**, at `0x566455`. *Corrected 2026-10-01: this row said `CCombatant::ApplyLosses 0x565FD0`, which was trap 2 inside trap 3's own example — see below* |
| `CAIUnit` slot 83 `0x8C0790` | `0x8C177A` (bare `ret`) | two `_CxxThrowException` arms out to `0x8C178E`; slot 84 starts at `0x8C1790` |

Two of those rows are failures this folder actually made. Reading `CAIUnit` slot 78 as
running to `0x8B3A46` swallowed the whole of **slot 79**, which put `CDetachUnitCommand` and
`CSendExpeditionCommand` in the wrong slot in `FINDINGS-aiunit.md`'s command table. And treating
a `ret 4` as the end of the function made `CSubUnit +0x54` look like it had **no reader anywhere
in the image**, from which `FINDINGS-combatmods.md` concluded that every defence-side naval, air
and bombing modifier might be inert. It is read, at `0x56645E`, in that block.

**And then this table got the fix wrong, which is the lesson worth keeping.** The row above said
the block was in `CCombatant::ApplyLosses` (`0x565FD0`) past a `ret` at `0x566452`. It is not:
`ApplyLosses` ends with its own `ret 4` at `0x5662ED`, and `0x5662F0` — `CCombatant` slot 11, held
at slot 11 by all seven vftables in that family — begins at the very next byte with no padding.
The `ret` at `0x566452` and the cold block at `0x566455` are **slot 11's**. Trap 3 still applies;
it applies to a different function.

The cause was using `image.functionStart(0x56645E)`, which answers `0x565FD0`, and **not** running
`image.retsBefore(0x565FD0, 0x56645E)` — which returns three `ret`s and says plainly that
something is wrong. So: **trap 2 was sitting inside trap 3's worked example, and the check for
trap 2 is the same check trap 3's own entry tells you to run.** When a cold block turns up past a
`ret`, settle which function owns it before writing anything about it: a fresh prologue
immediately after a `ret` is a boundary, and a vftable lookup names the owner for free.

The lesson from the slot 78 case is narrower than "look for funclets": **a slot's extent is the
wrong tool for attributing a call site at all.** The vftable gives the next slot's entry for
free, and `findRefs.py --callers` attributes by caller instead.

## 4. A shared stub is not the class's own function

A body sitting in many vftables is a compiler-folded stub, usually an empty `ret 4`. Naming it
after the class you were reading puts that class's name on 900 other classes' slots.

*The check:* `scratchpad/aitheatre/whoslot.py` - which vftables hold a function, and at which
slot - from the RTTI export. Count the holders **before** naming a slot body.

**`image.findValue` is not that check.** It scans `.text` only, so it answers "0 references" for a
function that seven vftables hold, because vftables live in `.rdata`. That nearly reversed a
correct correction on 2026-10-01. To test a slot by hand, read `vftable + slot * 4` directly.

*Known stubs:* `0xA80690` (189 slots across 81 classes), `0xABF890` (1691 / 916), `0xA7C050`
(748, all at slot 3), `0x45BB10` (749), `0x60CD50` (1420), `0xA806D0` (336).

**A fold can be as small as two, and those are the dangerous ones**, because two holders look like a coincidence rather than a pattern. `0x791940` is `lea eax,[ecx+0x54]` and sits in `CAIInvasion` slot 60 *and* `CGraphicalTableLedger` slot 17 - naming it `CAIInvasion::GetLandForce` would put that name on a table ledger. `0xA438F0` is `mov eax,0x64; ret` and sits in `CEmbargoAction` and `CAddWarGoalAction` slot 17; there the two holders *are* one family, so the fold is benign and the body is still recorded class-free, as `ReturnOneHundred`.

**But a high count is not by itself disqualifying.** `COrder::GetStance` is in 37 slots, 36 of
them slot 19 of a `COrder` subclass - that is inheritance, not folding, and the name is right.
Ask whether the holders are one family before rejecting a name.

## 5. A modifier entry is 8 bytes, so the offset is `id * 8`

Country and static modifier arrays are indexed `base + id * 8`, value in the low dword. An
offset computed as `id * 4` lands halfway through the previous entry and reads a plausible
number.

## 6. Absolutes in the image are relocated at load

A hardcoded address in `.text` is relocated when Windows places the module, so the value you
read statically is only correct relative to the image base. Everything on the C++ side is
module relative for this reason.

## 7. Numbers are thousandths

`237964731` is `237964.731`. This is true of nearly every quantity in the simulation, and the
savegame is plain text, which makes it the cheapest check available: find the value in a save and
compare. The combat and weather formulas are full of `x / 1000` for this reason, usually through
the 64-bit helpers `0xB99980` and `0xB99AF0`.

## 8. Defines hide from a `GetDefines` scan three ways

Scanning for `call GetDefines (0x445D90)` followed by `[reg + <block>]` turns a name in
`defines.lua` straight into a reader. **A negative result from it is not evidence**, because:

1. **`GetDefines` can be inlined** - the same body, the same `push 0x11C` and
   `call 0x4452E0`, the same singleton `[0x1A86040]`, but no `call 0x445D90` to anchor on.
   `CCountry::UpdateMonthly` reads `BASE_TECH_DECAY` this way at `0x4DCA62`, and the record
   carried "exactly one reader" of that define until the function was found another way.
2. **A whole block can be cached into globals at startup.**
   `CWeatherManager::InitialiseWeatherState` (`0x4B54F0`) copies 49 of the 56 `weather` entries
   into individual globals with one `mov ecx,[eax+0xEC]; mov edx,[ecx+N]; mov [global],edx`
   apiece, and every consumer afterwards reads a bare absolute. A scan finds **zero** readers of
   a block that 56 live values come out of. `scratchpad/naval/definecache.py` recovers them by
   that three-instruction shape - 51 globals across the `military` and `weather` blocks.
3. **The value may never have been a define.** `(int)floor(N.5f)` statics are written by their
   own `.CRT$XCU` initialisers; there are 7299 of them. Two are the combat-modifier clamp floors,
   which is why no `defines.lua` entry can move them.

*The check for case 1:* `findValue(0x1A86040)` finds the singleton directly.

## 9. Never linear-sweep `.text`, and never decode from a guess

x86 decodes happily from the middle of an instruction and produces confident nonsense - a plain
`mov` has read out here as `fisttp`, and `0x56C780` once decoded as `add byte ptr [ebx], bh`. A
linear sweep of the 9 MB `.text` desynchronises and then **silently drops instructions**, which
has caused two false negatives.

*The rule:* decode from a function entry, or from an address a tool printed. To cover the image,
iterate over known entries and decode each body forward, stopping at an `int3` run - that stays
synchronised and respects trap 2.

## 10. The RTTI export gives slot counts, not slot contents

It carries each class's vftable address and its **number** of slots. It does not say what is in
them, and its `introduces` list is not the answer to "which slots does this class supply":
`CAIUnit` supplies 37 and `introduces` says 34.

## 11. A `__thiscall` name needs a `::`

Without a class qualifier Ghidra invents a `this` and shifts every argument along. A free
function that really does take its receiver in a register is `__fastcall` with an explicit
`@ECX`, not a `__thiscall`.

## 12. A displacement alone is not evidence

`+0x38`, `+0x54`, `+0x5C`, `+0xBCC` are each hundreds of unrelated hits across dozens of
classes. `+0x50`/`+0x54` is a product pair on `CSubUnit` **and** on `CCombatant` **and** a
vftable slot 20/21 dispatch, all in the same combat module.

*The check:* `fieldchain.py --holder`, so the register is tied to a known pointer. Treat bare
`--field` output as candidates. Failing that, identify the object by its **distinctive
neighbours** - a register used with `+0x58`, `+0x5C` and `+0xA8` is a `CSubUnit`, whatever else
it is used with.

## 13. Read control flow off the graph, not off one jump

`cfg.py` lists every edge into a block. One jump read in isolation said troop rotation was gated
on being at war; the edge list said it was not, and the edge list was right.

## 14. Check what already exists before naming it

`CCountry +0xBCC` was named `Manpower` by the Lua API long before this work added a duplicate.
The pipeline refuses to overwrite an existing name, so a collision is a signal to compare
readings rather than an obstacle - twice it has turned out that two surveys agreed and the
"conflict" was convergence.

Also: **a name that fits one reader may not fit twelve.** `CCurrentGameState +0xD9D` was called
`autosave_blocked` after the autosave gate at `0x661DC9`. There are twelve readers, the only two
writers are `CTutorialScreen` button handlers, and it is `tutorial_active`.

**And the check belongs before an item goes *on* the queue, not only before a name goes in.** This
has now cost work twice, both times the same way. `CDistributionSetting +8` was queued as an open
question when it had been `base_percentage` since `FINDINGS-production.md`. Then on 2026-10-01 a
survey brief was written out of six findings files' "What is not established" sections, and **four
of its six fields were already named** in `project.json` - `CMapProvince +0x5C` (`ai_front_value`),
`CMapProvince +0x304` (`ai_param_building`), `CArmy +0x2FC` (`army_role`) and `CCountry
+0x618`/`+0x628` (`ministers`/`laws`, fully settled by three agreeing readings). The agent was
redirected mid-run.

The lesson is specifically about **open-item lists**: a "What is not established" section is a
claim about the record *as it stood when that file was written*, and the next wave's work is what
invalidates it. So a findings file's open list is a lead, never a statement of what is open now.
`grep` the offset in `ghidra/project.json` first - it costs one command, and it is the same command
whether you are naming a field or deciding to look at one.

**And `project.json` is only half the fact base. Grep the headers too.** On 2026-10-02 a survey
derived `convoyed_out` for `CCountry +0x7B8`, `traded_away` for `+0x7DC` and `traded_for` for
`+0x86C` off the goods-ledger tooltip, and the record was duly corrected from `unknown_pool_*`. All
three had been sitting in `BiceLib/GameClasses/CCountry.hpp` the whole time, named - its comment
says - from "the ones the game's own accessors name". `FINDINGS-forceneeds.md` had written that
"which is which was not established", and that was true of `project.json` and false of the project.
I then repeated the error one level up by writing "this settles which is which" into the record.

The two halves drift, and either one can be the stale one. So the check is **both**:

    grep -n 0x7B8 reversing/ghidra/project.json BiceLib/GameClasses/*.hpp

The derivation was still worth having - an independent reading from the display side that agreed
name for name, and that corroborated two header details nothing else had. But *independent
confirmation* and *first settlement* are different claims, and only one of them was true.

## 15. `instances()` can match a table of vftable pointers, not objects

`hoi3.instances` finds an object by its first four bytes being the class's vftable. **A table of
vftable *addresses* sitting in the data heap matches the same test.** On 2026-10-02 a survey
reported "one `CArmy`, one `CAir` and one `CNavy` at `plan_stance` 0" and the three were false
positives from such a table at `0x6ECF5C78`-`0x6ECF5CA8`, where the `CLandCombat`, `CAir`, `CArmy`
and `CNavy` vftables sit within 0x30 bytes of each other interleaved with code addresses. Three
`CUnit`s cannot be 4 and 0x1C bytes apart. Correcting it turned a 99.7% distribution into 100%,
i.e. the anomaly was the tool, not the game.

**A worked example of getting this wrong in my own tooling, 2026-10-02.** A live snapshot script reported combat counts from `instances()` without applying the spacing check - it printed the min gap but did not act on it. At the **main menu**, where no combat can exist, it reported 87 `CCombat`, 21 `CNavalCombat` and 9 `CLandCombat`, with min gaps of 0x50 to 0x74 - far below any of those objects' real size. So every combat count that script printed, in game as well as at the menu, was contaminated. The lesson is not the trap, which was already written down here: it is that **printing the discriminator is not the same as applying it**, and a count that cannot possibly be right (combats at a main menu) is the cheapest sanity check there is.

**The discriminator is the spacing, and it is quick.** Real instances of one class are spread with
a stride that is at least the object's size and usually its exact size; a pointer table packs them
a word or two apart and the addresses in between resolve to code. Checked this way on the same day,
`CUnitBaseProvince`'s 900 hits showed a 0x30 stride in 876 of 899 gaps across a 0x97 MB span, with
valid code in vftable slot 0 for every one sampled - real objects. So:

    gaps = [a[i+1] - a[i] for i in range(len(a) - 1)]
    # many gaps smaller than the object: suspect a table, not instances

Two related points. **A zero from `instances()` is not absence**: it finds a class only by its own
vftable, so a base class whose derived classes carry their own returns nothing - `CUnit` finds zero
while `CUnitBaseProvince` finds hundreds. And **hitting the `limit` means only that there are more
than the limit**, which is not evidence either way about whether they are real.

## 16. A fit against a key that never varies means nothing

`is_armor = yes` on 76 types and absent everywhere else fits *any* byte that happens to be 1 on
those types. Count the **distinct** values a key takes before trusting an offset fitted from it.

## 17. capstone: `X86_OP_IMM` is 2

Writing `1` asks for a register instead and fails **silently**. That cost two attempts at the
same scan.

---

## The habit all of these point at

Every entry above except 5, 6 and 7 is a case of a search that could not see something and was
read as proof the thing was absent. So:

**A negative needs a positive control.** When a scan reports that nothing reads a field, run the
same scan against a field you already know is read, in the same code, and check it finds it. If
the method cannot see the known case, its silence about the unknown one means nothing. The
`CSubUnit +0x54` question was settled this way: `+0x50` has a known reader, so a scan that
reported "no reads of `+0x54`" while also missing `+0x50` was the thing at fault.

Confidence vocabulary for `project.json` is `confirmed` / `likely` / `inferred` - not `read`,
`partial` or `inference`, all of which have been written by mistake and rejected by the
validator.
