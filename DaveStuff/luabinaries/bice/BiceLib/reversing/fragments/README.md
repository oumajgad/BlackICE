# Working in parallel: the contract

Several agents can read this executable at once because there is an **oracle**. Most
reverse engineering cannot be parallelised safely - there is no way to check one
person's answer without redoing their work. Here `buildFindings.py` checks every entry
against `hoi3_tfh.exe` and the headless apply either reports `failed: 0` or does not, so
an agent's output can be machine-checked before anyone reads the reasoning.

Everything below exists to keep that oracle meaningful.

## The rules

**Whatever you are given, it comes with something you can be wrong about.** Two kinds of
task, and they differ only in where that comes from.

A *question* - "what is the byte at province-info `+0x22`" - carries its own.

A *function* - "reverse `0x1C7530` and report what it calls" - is where breadth comes
from, because hand-picked questions are a byproduct of reversing already done and run
out, while `frontier.py` does not. Its acceptance is fixed instead:

- the signature and calling convention, read off the `ret` and the call sites
- every field access on a class already in `project.json` either matches a named field
  or is reported as unnamed
- **every function it calls, named or listed** in `frontier` in your output file - that
  list is what the next wave works from, so the queue feeds itself
- a name, **or** a plain statement that it cannot be named yet and why

That last one is not a failure. Recording that a function is `__thiscall`, cleans eight
bytes, reads these three fields and calls those five is real progress and fully
checkable. Say so and stop; the pressure to produce a name is where invented ones come
from.

Either way: if you finish early, do not wander - say what you found and stop.

**Finish the function, do not just label it.** A name on its own leaves the job half
done. Rename it, *move* it - a method's name carries its class, `CUnit::UpdateDaily`,
which is what puts it in that namespace and gives its `this` the right type - and give it
a **signature**: return type, calling convention, parameters, read off the `ret` and the
call sites. Where the compiler used a register convention and no signature can be
written, say so in `no_signature` rather than leaving the field empty. The merge refuses
a function that has neither.

**Keep the virtual tables current.** The moment a function turns out to be a virtual,
`vtable.py --holding <address>` says which classes hold it and at which slot. Record that
slot under `vftable_slots` for the class whose body it is, and look at the neighbours:
siblings that share the body and derived classes that inherit it get the name too - one
record on a base names the slot in every table below it. Otherwise the next person opens
three tables that all read `vf_32` and all point at something already named. The merge
refuses a function that sits in a table it has no record for.

Two things that bite here. A body the linker folded across many tables - `xor eax,eax;
ret` is in 189 of them - belongs to no one class and must not be named for one; the merge
refuses that too. And a slot a class leaves pure virtual points at `_purecall`, which
says nothing about the call, so it takes a record rather than a name.

**You never write `project.json`.** Write one file into `fragments/incoming/`, in the shape
`ghidra/mergeFindings.py` documents. That file has hand-kept formatting and a
hand-compacted block in it, and several writers would wreck it.

**Name it after the topic, not the wave** - `faction.json`, `command-loadkey.json`,
`setflag-expedition.json`. Lower case, hyphens between words, no wave number and no agent letter.
`merged/` is one flat archive of every fragment ever landed, and you look in it for *the faction
one*, not for *wave 15's third*: a `wave15-` prefix sorts the folder by something you can already
get from the merge log or from git, and buries the one thing you cannot. **This was written down on
2026-10-07 because it had not been**, and six of the sixty files had drifted - one in wave 14 and all
five of wave 15, each agent having reasonably invented its own scheme in the absence of a rule.
Those six are renamed; nothing referenced them by name.

**Every key in an address entry must be *present*, even when it is empty.** The check is
`if key not in entry`, over a fixed list that includes **`no_signature`** - so an entry with a
perfectly good `signature` is still refused, with the unhelpful message "no no_signature", until it
carries `"no_signature": null` as well. Three of the four wave 9 agents hit this independently.
The field list is spelled **`struct_fields`**, not `fields`; `fields` is read by nothing and a
fragment using it passes `--check` reporting zero fields and lands nothing. And `confidence` takes
only `confirmed` or `inferred` - the validator has no `likely`, although this README, `TRAPS.md`,
`CLAUDE.md` and `project.json` itself all use the three-word vocabulary. Where the honest strength
is "likely", write `inferred` and say "likely, and why" in the comment.

**Every entry carries `evidence`**: what you checked, and *what would show it wrong*.
That second half is the one that matters and the one people skip. It is not copied into
`project.json` - it is the reviewer's handle.

**`confirmed` means a machine could have checked it.** Bytes compared, a scan that
returned exactly one hit, a field already named by the Lua API agreeing with you. A
reading that hangs together but rests on what the code seems to be for is `inferred`,
and saying so costs nothing. Wrong entries are long-lived: they poison every later
decompilation and are hard to notice. `ResetBiceLibOrphans` exists because five classes
were once named off the wrong virtual table.

**Say what you could not settle.** A finding that names its own gap is worth more than
one that quietly rounds up.

**A name without a signature untypes everything downstream of it, silently.** Ghidra's
RTTI pass names constructors and virtuals that `project.json` has never heard of, so
`checkSignatures.py` cannot see them - it only audits what is recorded. A call to one
comes back as `int *`, and then every field reached through that pointer is an anonymous
offset, however well the structure is typed.

`CBuildingDataBase`'s role ladder sat unreadable through two waves for exactly this
reason: `CModifier::id` was typed as an enum and `CBuilding::effect` as a `CModifier*`,
and the comparisons still printed bare hex, because the building came out of
`CBuilding::CBuilding` - named by RTTI, recorded nowhere - as an `int *`. One signature
fixed the whole function. **If a decompilation is unreadable and the types look right,
check what the pointers came out of.**

**Your signature has to survive `checkSignatures.py`.** It reads the `ret` and works out
what the convention implies: `__cdecl` leaves the arguments to the caller and ends in a
bare `ret`, `__stdcall` and `__thiscall` clean their own and end in `ret N`. So the
signature you write is a prediction the executable can refuse, and it refused six that
were already in `project.json` - `ParseObjectId` was recorded `__cdecl` and does `ret 8`.
Run it once your file is written; a disagreement means one of the two is wrong and it is
usually the signature.

Two conventions it knows about, which yours should use. A register argument is written
`unit@ESI` and a stack one `out@stack:4`, and a register argument costs no stack. Where
the compiler used a register convention no ordinary signature can express, that is what
`no_signature` is for - do not invent stack parameters to make the arithmetic close.

## You can declare a struct, as of 2026-10-06

The merge used to refuse a `struct_fields` entry for a struct `project.json` did not already hold, so
a class with no record could not be contributed at all. It now reads a **`structs`** key beside
`struct_fields`:

    "structs": [
     {"name": "CRelation", "size": "0x24", "inherits": "CPersistent",
      "vftable_rva": "0x11FBB00", "comment": "...", "evidence": "..."}
    ]

`name` and `evidence` are required; `size`, `inherits`, `vftable_rva`, `comment` and `source` are
optional. **Fields still go in `struct_fields`** - put a `fields` key inside a declaration and it is
refused, because that is where the duplicate-offset and cross-fragment checks live. A field may name a
struct **another fragment in the same wave declares**; declarations are collected before the per-file
pass for exactly that reason.

Four things it refuses, each of which has already caught something real:

- **`inherits` at any offset but 0.** `buildFindings.py` lays a base's fields in at face value, so a
  base at `+8` would place all of them eight bytes early. Checked against the RTTI export,
  transitively.
- **a `vftable_rva` that is not the start of a table** - this found two wrong values already in
  `project.json` - or that only resolves when read as a VA (trap 1, caught by name).
- **a redeclaration that differs** from what the record holds. The key is **create-only**: changing a
  struct's `size` or `inherits` is a hand edit, because `size` may sit on either side of the `fields`
  array in that file and there is no one textual header to rewrite.
- **`revises` on a field of a struct this wave creates**, which cannot be revising anything.

**Omit `size` rather than guess it.** A declared `size` is now authoritative **downward** as well as
upward - the apply shrinks a type Ghidra holds longer than the record says - so a guessed size silently
drops whatever Ghidra had past it.

**Two things worth checking before you declare a class at all** (both cost a wave 14 agent real time):

- **A class with a Lua registration may already have its fields**, through `luabind.json`, at a
  priority higher than anything a `project.json` record gets. Eighteen classes and 44 fields looked
  blocked and were already in `bicelib_findings.json` and in Ghidra; landing them would have created
  44 duplicate `(struct, offset)` records. **Grep the generated file, not just the record** - and
  remember it stores offsets in **decimal**. A `structs` declaration for a Lua-named class is worth
  making only to add a `size`, an `inherits` or a `comment`, never to restate its fields.
- **An id-half field is folded, not placed.** A field lying inside a larger typed one is removed from
  the generated output and its text appended to the host's comment, so it never reaches the apply.
  `ghidra/README.md` has the measurement; the practical consequence is that **a field overlapping a
  struct member is not the apply-cycle bug it looks like**, and you should not propose deleting one on
  those grounds.

### Checking a signature you have just written

`python scripts/checkSignatures.py --candidates fragments/incoming/<yours>.json` reads `addresses` out
of your fragment instead of out of `project.json`, so you get the `ret` check, the class check, the
storage check and the constructor check on entries the record has never seen. Added 2026-10-06; before
it, the only way was to write your own checker, which wave 13's agent C did.

The whole-image baseline for the bare command is **1,582 entries checked, none disagree** (2026-10-06;
it was 1,517 three waves earlier, and it grows as the record does). **"none disagree" is the pass
mark, not the count** - if you see a disagreement, it is one of yours.

## Traps

**They are in `../TRAPS.md`**, numbered, with the case that cost time and the cheap check for
each. The findings files cite them by number - "exactly trap 2" means the entry numbered 2 there.

This section used to carry its own shorter unnumbered version, which was worse than having none:
the citations follow `TRAPS.md`'s numbering, so counting the bullets here resolved them to the
wrong trap. Add a new trap to `TRAPS.md` and nowhere else.

## The tools

In `reversing/scripts/`, and they reproduce the results in
`../findings/FINDINGS-manpower.md` exactly. Run them from `reversing/`:

| | |
| --- | --- |
| `image.py` | the executable, decoded; VA/rva conversion, `functionStart` |
| `disasm.py` | a range, with strings named |
| `cfg.py` | basic blocks and every edge; `--lands-in` before hooking anything |
| `fieldchain.py` | who reads a field, through the pointer that leads to it |
| `slotcalls.py` | where a virtual slot is called from |
| `frontier.py` | what named functions call that nobody has named - the queue |
| `findRefs.py` | references to an address, and callers of a function |
| `vtable.py` | classes' tables side by side; `--holding` for which hold a function |
| `ghidra/DecompileAt.java` | headless decompilation of an address |

**Decompile against the applied findings.** A named program is far more readable than a
bare one - `CUnit::UpdateDaily` was nearly unreadable until its fields had names. Use
your own copy of the Ghidra project: concurrent headless runs fight over the lock.

## Typing a local the function builds itself

A value that never comes out of a class field - a queue, a scratch list, a buffer built with
`operator new` - has nothing to propagate a type from, so every read through it decompiles as
`*(iVar3 + 0x4c)` while the same field a line away reads `province->supply_depot_distance`.
Say so on the address record:

    "locals": [{"at": "stack:-0x30", "name": "frontier",
                "type": "CListNode<CMapProvince*>*",
                "comment": "head of the queue of provinces still to relax"}]

**`at` is Ghidra's own offset, the number in the `local_30` the decompiler prints** - four
below the `[ebp - 0x2c]` in the disassembly on a normal frame. Stack only: a register local is
a variable over a range of the function and one register holds several, so `EBX` names nothing.
You rarely need them anyway - typing the stack slot carries the type into every register the
value is read into.

For a list, use the `CListNode<T>` name the build already generates rather than inventing a
node; `reversing/ghidra/README.md` has the rest.

## Landing it

    python scripts/checkSignatures.py           your signature against the ret
    python ghidra/mergeFindings.py --check      what would land, changing nothing
    python ghidra/mergeFindings.py              land it
    python ghidra/buildFindings.py              the oracle - it validates against the exe
    ...headless ApplyBiceLibFindings            and this must say failed: 0

`--check` is the one to run yourself. The merge and the apply are for whoever is
collecting the wave, because they touch shared state.

## Why waves rather than continuous sync

Two agents landing on the same function is rare and, when they agree, harmless. What is
worth sharing is not who is working on what but the **names**, because each wave
decompiles against a better program than the last. So: run a wave, merge, apply, run the
next. Re-syncing mid-flight buys little and costs a great deal of machinery.
