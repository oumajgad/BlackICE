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

**You never write `project.json`.** Write one file into `incoming/`, in the shape
`ghidra/mergeFindings.py` documents. That file has hand-kept formatting and a
hand-compacted block in it, and several writers would wreck it.

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

## Traps that have actually cost time here

- **Virtual address against rva.** The disassembler prints virtual addresses, based at
  `0x400000`; `project.json` wants the rva. **Magnitude does not tell you which is
  which** - `.text` runs to about `0x970000`, so an rva here is routinely larger than the
  image base. The tools take virtual addresses and accept `rva:0x...` for the other kind;
  `image.both()` prints both, use it in anything you report. This trap ate an afternoon
  once and then reappeared inside the tooling written to avoid it.
- **A `__thiscall` name needs a `::`.** Without a class, Ghidra invents a `this` and
  shifts every argument along.
- **Do not decode from a guess.** x86 decodes happily from the middle of an instruction
  and produces confident nonsense - a plain `mov` has read out here as `fisttp`. Start
  from a function or from an address a tool printed.
- **A displacement alone is not evidence.** `+0x38`, `+0x5C`, `+0xBCC` are each hundreds
  of unrelated hits. Use `fieldchain.py --holder` so the register is tied to a known
  pointer, and treat bare `--field` output as candidates.
- **Read control flow off the graph.** `cfg.py` lists every edge into a block. One jump
  read in isolation said troop rotation was gated on being at war; the edge list said it
  was not, and the edge list was right.
- **Check what already exists before naming it.** `CCountry +0xBCC` was named `Manpower`
  by the Lua API long before this work added a duplicate for it.

## The tools

In `reversing/`, and they reproduce the results in `FINDINGS-manpower.md` exactly:

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

    python checkSignatures.py                   your signature against the ret
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
