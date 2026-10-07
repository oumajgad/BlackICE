# Ghidra: applying what BiceLib knows

`ApplyBiceLibFindings.java` names, types and comments a Ghidra program of `hoi3_tfh.exe`
from `bicelib_findings.json`, which sits next to it.

| file | what it is |
| --- | --- |
| `ApplyBiceLibFindings.java` | the Ghidra script |
| `ResetBiceLibFunction.java` | hands one function back to it, when your own edit of it should give way |
| `ResetBiceLibOrphans.java` | clears names it put down and has since withdrawn |
| `RepairFunctionBody.java` | when the decompiler stops mid function: finds the truncated body and repairs it |
| `bicelib_findings.json` | what it applies; built, do not edit |
| `luabindExtract.py` | recovers the Lua API's C++ functions from the executable -> `luabind.json` |
| `project.json` | everything else BiceLib has found; **add new findings here** |
| `buildFindings.py` | checks both against the executable and builds `bicelib_findings.json` |

## Running it

1. Script Manager -> *Manage Script Directories* -> add this folder.
2. Run `ReconstructClassesFromRtti` first if the program has not had it, so the class
   namespaces exist. This script creates missing ones the same way.
3. Run `ApplyBiceLibFindings` (category C++). The console lists everything it left alone.

It never replaces a name or signature set by hand, only replaces other scripts' names
when they are placeholders (`FUN_...`, `vf_NN`), and only places struct fields where the
structure is still undefined. Re-running is safe.

**An enum it made is its own to rewrite.** There is nowhere to mark one member, so the whole
enum is judged by where it sits: under `/BiceLib` it is the script's and a rebuild replaces
it, which is what lets an enum already in the program gain members. Anywhere else it is
yours and the console says it was left alone. The count in the summary is enums that
actually changed, so a settled run reports none.

**Re-run it after every rebuild of the findings**, since that is where everything new
lands - the script itself hardly changes.

**The built file is byte for byte the same every time it is built from the same inputs**,
so a diff of it is only what actually changed. Every list in it is ordered by something of
its own: functions and labels by address, enums and virtual tables by name, a structure's
fields by priority and offset. The structures themselves have to be in embedding order -
one held by value has to be laid out before whatever holds it - so they are sorted by name
inside that walk rather than after it. It used to come out in whatever order the dicts and
sets upstream happened to have, which put a few hundred lines of noise in every diff and
hid the real change. **Anything new in the output needs a key of its own for the same
reason.**

The first run after the findings gain new classes settles in two passes - a class that only
gets a structure because its virtual table gave it one is typed on the next run - so a
second run reporting a handful of fields is expected. A third changes nothing.

Struct fields it places are marked `[BiceLib]` in their comment, so a later run can tell
its own work from yours. Its own it retypes freely, which is what a rebuild needs: a class
that had no layout gets one, a list learns what its nodes hold. **Yours it leaves**, and
says so in the console, naming the type you have and the one the findings hold. A field
from before the marker existed is recognised by its comment, which always cites where the
finding came from.

## Where Ghidra is, and which project

Both of these are easy to lose an hour to, so they are written down rather than elided.

**The installs are under `%USERPROFILE%\Documents\Ghidra\`** - five of them, `ghidra_10.2.2`
through `ghidra_12.1.2_PUBLIC`, each with `support\analyzeHeadless.bat`. They are at **depth six**
from the drive root, so a `find /c -maxdepth 4` finds nothing and says so convincingly; one session
concluded from exactly that search that Ghidra was not installed on this machine.

**The current project is `Hoi3_v12.1.2`**, in `%USERPROFILE%\GhidraProjects\`, 1.7 GB, and it
pairs with the 12.1.2 install. `Hoi3.gpr` beside it is from 2023 and is not the one.

**Run against your own copy, never the maintainer's.** Theirs is usually open in the GUI - a live
`Hoi3_v12.1.2.lock` next to it and a `javaw.exe` holding over a gigabyte - and a headless run would
fight the lock. A copy is a plain directory copy plus an empty `.gpr`; `project.prp` records only the
owner, so nothing inside it needs renaming:

    cp -r "$USERPROFILE/GhidraProjects/Hoi3_v12.1.2.rep" "<scratch>/hl/Check.rep"
    : > "<scratch>/hl/Check.gpr"

Then, from `reversing/`:

    "$USERPROFILE/Documents/Ghidra/ghidra_12.1.2_PUBLIC/support/analyzeHeadless.bat" \
        "<scratch>/hl" Check -process hoi3_tfh.exe -noanalysis \
        -scriptPath "<repo>/DaveStuff/luabinaries/bice/BiceLib/reversing/ghidra" \
        -postScript ApplyBiceLibFindings.java overwrite

`-noanalysis` matters: the program in the project is already analysed and a second pass would both
waste minutes and move boundaries the findings are written against. Grep the output for `'!'` to see
the failures, and **`failed: 0` is the pass mark** as of 2026-10-04. Any failure is a real one.

This said `failed: 2` until then, excusing `MT19937Next` and `TernarySearchTreeFind` as "over-long
bodies". They are not: their predecessors are **thunks that tail-jump into them**, Ghidra had merged
each thunk with its target, and in the current project all four are proper entries. `CLAUDE.md` has
the bytes. If the pair ever comes back, repair the **thunk**, not the target.

**Applying to the maintainer's own project is their step**, the same division as `Deploy.ps1` and the game
folder: the headless run against a copy proves the record lands clean, and they take it from there.

**To hand back one function you edited yourself** - the findings have since learned what
your edit stood in for - put the cursor in it and run `ResetBiceLibFunction`, then
`ApplyBiceLibFindings` again. It lowers that function's name and signature from yours to a
script's and clears custom storage, and touches nothing else in the program. Headless:
`-postScript ResetBiceLibFunction.java 0x0042f210`.

**Deleting the function is not enough**, which is what makes this script worth having: the
name stays behind as a label of yours, the next function made there takes it up again, and
the script goes on deferring to it. Run this on the address instead - with the function
already gone it removes that label, and the next run makes the function and names it.

**A name the findings withdraw does not clear itself.** The apply script only ever writes,
so when a name turns out to be wrong and the build stops making it, the old one and its
`[BiceLib]` plate stay in the program saying something false. `ResetBiceLibOrphans` finds
them by comparing the program against the findings - every function carrying a `[BiceLib]`
plate that the findings no longer name - and puts each back to `FUN_...`, lowering the
signature and taking out the script's block while keeping anything you wrote around it. A
name you set yourself is left alone and reported.

    ResetBiceLibOrphans list          what would be cleared, changing nothing
    ResetBiceLibOrphans               do it
    ResetBiceLibOrphans 0x005c0540    clear exactly these, claimed or not

Then run `ApplyBiceLibFindings` to name whatever the findings now put there. It was written
for the day five classes were named off the wrong virtual table; it found all twenty without
being told which.

**To have the findings win instead**, run `ApplyBiceLibFindingsOverwrite` (it asks once
before it starts), or headless `-postScript ApplyBiceLibFindings.java overwrite`. Every name
and signature the findings cover is replaced whoever set it, struct fields are replaced
even where a field of the same name holds a type you gave it, conflicting neighbours are
cleared to make room, and enums take the recorded values. Comments are kept either way:
the script only ever replaces its own `[BiceLib]` text. Tested headless on Ghidra 12.1.2, run
twice on a fresh import: nothing failed, and the second run changed nothing.

## Typing a function's own locals

A value a function builds for itself reaches no struct field, so nothing can type it and every
read through it comes out raw. `CSupply::SpreadFromDepot` builds its search frontier as a
`CList` on the stack with nodes from `operator new`, and the same province read
`province->supply_depot_distance` through the typed province vector and `*(iVar3 + 0x4c)` two
lines earlier through the queue.

`locals` on an address record fixes that:

    {"rva": "0x289BE0", "kind": "function", "name": "CSupply::SpreadFromDepot",
     "locals": [
      {"at": "stack:-0x30", "name": "frontier",
       "type": "CListNode<CMapProvince*>*", "comment": "head of the queue"}]}

**`at` is Ghidra's stack offset, which the decompiler prints**: the local it calls `local_30`
is `stack:-0x30`. On a normal `push ebp; mov ebp,esp` frame that is four *below* the
`[ebp - 0x2c]` in the disassembly, and copying the disassembly's number is the mistake to
expect - the apply says so by name when an offset names no local.

**Type the stack slot and the registers follow.** The decompiler carries a type across
`province = node->data`, so three lines here retyped a dozen reads and the whole edge walk with
them. That is also why only stack storage is addressable: a register local in Ghidra is a
variable over a *range* of the function, and one register holds several unrelated ones, so
`EBX` does not name anything the way an offset does.

**A list of a known class wants its own node type.** The generic `LinkedListNode` holds an
`undefined4` - it has to, since different lists hold different things - so a pointer to it
leaves the reads as untyped as before. `buildFindings` already generates a `CListNode<T>` for
every `CList<T>` a class holds, and it now generates one for an element only a local asks for,
so **use that name** (`CListNode<CMapProvince*>`) rather than writing a node of your own; a
second name for the same 16 bytes is the thing to avoid.

Your own retyping wins, the way a name or a signature does, and `overwrite` takes it. A settled
run reports `locals: 0`.

## When the decompiler stops mid function

The listing has more code, the decompilation ends anyway, and nothing says why. Ghidra
decompiles a function's **body** - a set of address ranges settled when the function was made -
not the bytes between its entry and the next function, so a body that stops early takes the
decompilation with it.

What truncates one is a call the program believes never comes back, and it is recorded in two
separate places: the callee's **No Return** mark, and a **`CALL_RETURN` flow override** on the
call site, which the listing shows as `Flow Override: CALL_RETURN (CALL_TERMINATOR)`. Clearing
one does not clear the other. Ghidra's "Non-Returning Functions - Discovered" analyzer lays
both down by guessing from the shape of a function, and on this executable it guesses wrong
about `free` (rva `0x795F9B`), whose five-byte thunk `mov edi,edi; push ebp; mov ebp,esp; pop
ebp; jmp <body>` is exactly the shape it looks for. `free` has 35868 call sites, so one wrong
guess can hide a large part of the program.

    RepairFunctionBody                        the function under the cursor
    RepairFunctionBody fix 0x00689be0         repair it
    RepairFunctionBody sweep                  every function in the program this happens to
    RepairFunctionBody sweep fix 0x00b95f9b   repair them all, for the callees named

It reports before it changes anything, and clears nothing until told which callee, because
**some of these marks are right** - a real `abort` or `_CxxThrowException` truncates its
callers correctly and there is nothing in the shape of a function that tells the two apart.
The repair keeps the function's name, signature and comments; only its range set changes.

**A GUI script cannot use `ghidra.app.cmd.*`.** The natural way to write the repair is
`DisassembleCommand` and `CreateFunctionCmd.fixupFunctionBody`; both compile, and both run
fine headless, but in the GUI the script's bundle is not wired to that package and it dies at
run time with `NoClassDefFoundError: ghidra/app/cmd/disassemble/DisassembleCommand`. So
headless is not a test of whether a script works in the Script Manager. Stay inside
`GhidraScript`'s own methods and `ghidra.program.model.*`: `disassemble(Address)` replaces the
first, and a flow walk from the entry point replaces the second - it produces the same body,
byte for byte, on the case this was written for.

**Dropping an import needs Ghidra restarted.** Every script in this folder compiles into one
OSGi bundle, and its manifest lists the packages it imports. Removing the last use of a
package changes that manifest, and Ghidra will not re-wire a bundle that is already active -
so the fixed script recompiles, the old class keeps running, and the same stack trace comes
back with the same line numbers. The tell is a trace blaming a line that holds no code in the
file on disk. A restart clears it; so does toggling the folder in the Bundle Manager.

Two things it was worth getting wrong first. **Do not ask what follows the body's last byte** -
that reports the alignment padding behind every `ret` as lost code; ask where the flow goes
from each instruction *inside* the body and which of those the body fails to cover. And **do
not find the callers through references**: `getReferencesTo` returns at most 4096 and the
reference manager stops recording at 8191 to one address, so on `free` that route saw a fifth
of the call sites and reported the function this was written for as untruncated. One pass over
the listing takes about ten seconds and is right.

## What it applies

**The Lua API** (`script/LUA API.txt`): every function behind it, 517 methods and 59 free
functions, named as the source names them - `CWarGoal::IsValid`,
`CCurrentGameState_GetPlayer`, with the declaring class where a method is inherited
(`CEU3Date::GetYear` is `CGregorianDate::GetYear`).

The signatures come from the compiler, not from guessing: each registration's own RTTI
name holds the exact member function pointer type, e.g.
`bool (__thiscall CWarGoal::*)(void)const`. Where a class is returned by value, the
hidden return pointer is written out as a parameter, because that is what the code does
(`CFixedPoint* __thiscall GetPriority(CTheatre* this, CFixedPoint* result)`).
Parameters are only set when every class passed by value has a known size; otherwise
the return type and convention are set and the parameters left alone, since typing some
would shift the rest onto the wrong stack slots.

Also: 188 class fields (the `def_readwrite` ones and every one-instruction accessor,
`lea eax,[ecx+N]; ret`), 14 enums with their values - `SaveToken`, the save keys, being by
far the largest - and class sizes where luabind constructs the object.

**Save keys as names.** A constant reads as a name as soon as the parameter carrying it is
typed as an enum, so `saveTokens.json` (the executable's own 2149 save keys, from
`reversing/scripts/saveTokens.py --compiled`) becomes the `SaveToken` enum and
`SaveWriteKey(0x5a6, writer)` decompiles as `SaveWriteKey(usage, writer)`. The same enum on
`CPersistent::LoadKey`'s key turns a class's loader into `if (key == unit_names)`. Worth
doing for any id a function switches on.

**Give the enum a member for every value in range**, gaps included. A value with no member is
one Ghidra writes as an OR of the members that add up to it: `token.type = 0xC` came out as
`tok_comma|tok_close`, which reads as flags being combined and is a lie about what the code
does. The build fills every gap below the highest id, naming what it can and using the id
otherwise.

**A run of `_DAT_` globals in one function is often a local static.** MSVC gives every
function-local static a one-byte construction guard next to it, so the shape is
`test byte ptr [flag], 1; jne past; ...build...; or [flag], 1`. Everything the build writes
belongs to that one function however global it looks, and the decompiler cannot tell you so -
`CLeader::AddExperience` reads as five unrelated `_DAT_01beb6e8` globals when it is one
`static` array of five. Two things follow: name them after the function that owns them, and
**check what the constructor actually stores** - in that case all five slots get 1.0, so the
rank the code indexes by makes no difference at all.

**Two fields that overlap flip-flop for ever**, and `overwrite` is where you see it: each
run places one, clearing the other, and the next run puts the other back. The symptom is an
apply that reports `struct fields: 1` and a `replaced` line naming the same pair every time,
alternating direction.

It happened because a 64-bit field did not know its own width. **Both sides have their own
type table** - `SCALAR_SIZES` in `buildFindings.py` decides whether a field covers the next
one, and `builtin()` in `ApplyBiceLibFindings.java` decides what Ghidra actually lays down -
and neither knew `longlong`, which is the name `TYPE_MAP` hands back for the game's 64-bit
fixed point. So the build could not fold the second half into it, and the apply resolved the
type to an empty structure one byte wide. Add a name to one table and add it to the other.
The build now also prints `! <struct>: <a> runs into <b>` for any overlap that survives the
merge, which is the check that would have caught it in the first place.

**The overlap warning does not always fire, so do not lean on it** (2026-09-25). The build
prints `! <struct>: <a> runs into <b>` for a field covered by the one before it, which is the
guard against an apply that never settles. It missed a real one: `CCombatant + 0xB0` typed as
`CList` (declared size `0x10`) with a separate `front_line_count` at `+0xB8`, two adjacent
fields where the first plainly covers the second. `field_size` resolves a struct's size
through `struct_sizes`, and `CList` is in there, so something about the ordering or the
lookup is not doing what it reads as doing. **Not diagnosed.** Until it is, an overlap has to
be caught by looking at the offsets, and the symptom to watch for is the one below: an apply
reporting the same `struct fields: 1` for ever with a `replaced` line naming the same pair.

**Five live instances of exactly that, the mechanism, and the fix - all 2026-10-05.**
**It is fixed: a second run now reports `struct fields: 0` and `replaced: 0`.** The history is
kept because the symptom is worth recognising again. Before the fix, a second headless run did
**not** settle; it ran in a **period-2 cycle**, measured over four consecutive applies of an
unchanged record:

    pass 1   struct fields: 6   replaced: 5
    pass 2   struct fields: 5   replaced: 11
    pass 3   struct fields: 6   replaced: 5
    pass 4   struct fields: 5   replaced: 11

**Phase A** (odd passes) writes the six sub-object members, clearing the five parents that
cover them - 5 conflicts, all of the form `replaced 'flags' with flags_persistent`.
**Phase B** (even passes) writes the five parent by-value fields back, clearing the members
and then refusing all six - 11 conflicts, 5 clears plus 6 `holds '<parent>', not placing
<member>`. Each phase destroys exactly what the other needs, so there is no fixed point and
`struct fields: 0` is unreachable while both declarations exist.

**What that means in practice, and it is not cosmetic: the layout Ghidra holds depends on
whether you ran the apply an odd or an even number of times.** End on phase A and
`CCurrentGameState+0xC4` is not named `flags` at all while `+0xE8` is `flags_persistent`; end
on phase B and `+0xC4` is `flags` and `+0xE8` does not exist. Anything decompiled against
those five structs reads differently in the two states.

The six declarations and the five parents they fight over:

    CCurrentGameState+0xE8  'flags'   -> flags_persistent
    CGameState+0xE8         'flags'   -> flags_persistent
    CMapProvince+0xC4       'flags'   -> flags_persistent
    CProvince+0xC4          'flags'   -> flags_persistent
    CLeader+0xA8            'history' -> picture
    CLeader+0xC4            'history' -> trait_gain_tracker

**There are six, not five** (2026-10-05). The sixth was missing from this list: `CLeader+0xC4
trait_gain_tracker` is blocked by `CLeader`'s `history` for exactly the same reason `+0xA8
picture` is, and the apply names all six in its `holds '<x>', not placing '<y>'` notes. So the
arithmetic this section and `CLAUDE.md` carried since 2026-10-04 - "struct fields: 6: five
fields that overlap" - was counting six declarations and listing five names.

*The explanation first offered here for that mismatch, "six are blocked and five are placed",
is true of phase B only and is not why the numbers disagreed; the cycle above is. Left visible
rather than deleted, because reaching for a static explanation of a number that was actually
alternating is the mistake worth seeing.*

**And it alternates 6, 5, 6, 5** - see the cycle above, which supersedes this note. An
earlier reading of it here said "6, 5, 5, 5"; those four numbers came from four runs with
*different* record states between them, not from four passes over one, so three of them were
phase B and the sequence looked like it was converging. One `-postScript` repeated four times
over an unchanged record is what shows the cycle.

**The shape is: a field held by value, plus a second field that lands inside its extent.**
`project.json` has no duplicate offsets, so this is not a double definition; it is two
declarations that Ghidra cannot both honour. `CCurrentGameState+0xC4` is a `CFlags` *by value*
and `+0xE8` is, by its own comment, "the `CPersistent` second base of `flags` (+0xC4)" - which
is to say **a member of the object at `+0xC4`, declared as a sibling of it**. Placing the
`CFlags` covers `+0xE8`; naming `+0xE8` carves it back out; next run, repeat. `CLeader` is the
same thing one step less obvious: `history` is a `CLeaderHistory` recorded as `0x24` bytes, so
`0x84 + 0x24` lands exactly on `picture` at `+0xA8` and the two are adjacent rather than
overlapping *in the record* - but the type Ghidra actually holds for `CLeaderHistory` is what
decides it, and `CFlags` and `CPersistent` both carry `size: None` here, so the record is not
the authority on how far either reaches.

Four of the five arrived with a correction on 2026-10-04 that moved `flags` to where the
`CFlags` really begins (`0xE8` -> `0xC4` on the game state, `0xC4` -> `0xA0` on the province).
That correction was right about the offset; what it left behind was the old offset still
declared as a parent field.

### How it was fixed, 2026-10-05

**First, measure what Ghidra actually holds** - which nothing here had done, and which is why
this section could only guess at `CFlags`'s extent. `ghidra/PrintStructs.java` was written for
it and prints a structure's length and components:

    CFlags            0x28   +0x0 vftable, +0x4 root, +0x24 vftable_at24
    CPersistent       0x8
    CLeaderHistory    0x44   ... +0x20 leader, +0x40 trait_gain
    CTraitGainTracker 0x24

That split the five instances into **two different causes**, where this section had assumed
one.

**The four `flags` instances were a redundant declaration.** `CFlags` is 0x28 and Ghidra's own
RTTI pass *already* names the second base's vftable at `CFlags+0x24` - which is precisely what
the four `flags_persistent` fields were saying one level up. A `CPersistent` (0x8) at
parent+0x24 runs to +0x2C, overlapping the 0x28-byte `CFlags` at parent+0, so the two could
never both be placed. **The four sibling fields are deleted**, and what they established - that
the second base is 0x24 in and is the sub-object `SaveContents` calls slot 1 on - now sits in
the `flags` comment on the same struct, where it cannot collide. `CFlags` carries its measured
`size: 0x28`. **Nothing is declared at `CFlags+0x24`**: the vftable pass owns that offset, and
a field there would start a fresh flip-flop for the reason the next note gives.

**The `CLeader` instance was the opposite problem** - not a field too many, but a *type too
long*. `CLeaderHistory`'s own fields stop at `+0x20`, the record declares `0x24`, and Ghidra
held `0x44` because of a `trait_gain` component at `+0x40`. A 0x44-byte member at `CLeader+0x84`
therefore covered `picture` (+0xA8) and `trait_gain_tracker` (+0xC4). The record is right: a
history object does not contain the leader's portrait name, `picture` is read live on a real
leader, and the engine reaches the tracker as `[leader + 0xC4]`. So **the apply now enforces a
declared `size` downward as well as upward** (`shrinkToDeclared`), naming every component it
drops. Of the 41 sized structures in the record exactly one was longer in Ghidra, so this is
surgical rather than blunt - that comparison is worth re-running with `PrintStructs.java` if a
future `size` is added.

**The result**, three consecutive applies after the change:

    pass 1   struct fields: 7   replaced: 0   failed: 0
    pass 2   struct fields: 0   replaced: 0   failed: 0
    pass 3   struct fields: 0   replaced: 0   failed: 0

with one note on the first pass, `CLeaderHistory: record declares 0x24, Ghidra holds 0x44 ->
shrunk, dropping +0x40 trait_gain`, and **no conflict lines at all**.

So: **the pass mark is `failed: 0` and `struct fields: 0` on a second run**, as it was always
meant to be. A non-zero second run now means something real, and the first thing to do with it
is `PrintStructs.java` on whatever structure the notes name.

**Do not declare a `vftable` field at +0 in `project.json`.** The script places that pointer
itself, typed as the class's own virtual table structure, so a field of your own there is
overwritten by the vftable pass on every run and put back by the field pass on the next -
two writes a run, for ever. The symptom is an apply that never settles to `struct fields: 0`
however often it is run. Leave +0 alone and the class still gets its pointer.

**Ghidra has no inheritance between structures**, so a derived class reads as a wall of
`field_0x30` however well its base is laid out. `"inherits"` on a `project.json` struct
names a base that sits at offset 0 and copies its fields in, and a field the derived class
declares itself always wins. `CRegiment`, `CShip` and `CWing` take `CSubUnit`'s that way,
and `CArmy`, `CNavy` and `CAir` take `CUnit`'s, which is what makes a decompiled `CArmy`
read like the unit it is. The base has to be a base **at offset 0**: where it sits further
in, its fields are at their own offsets on the derived class and copying them would put
every one of them in the wrong place.

**Virtual tables**: a structure per table, and a pointer to it on the class, so a call
through one reads as `unit->vftable->GetAverageOrganisation()` rather than
`(**(*unit + 0x50))()`. The tables are read out of the executable and their length comes
from the RTTI export; a slot whose function is the class's own takes that function's name
and a pointer to its definition, which is what gives the call its arguments. The rest are
`vf_<slot>`, because **the linker folds identical bodies together** - every `mov al,1; ret`
in the game is one address - so a name from elsewhere would say something false about this
class. What BiceLib knows but cannot read off a folded slot (`isLand`, `isNaval`, `isAir`
and the rest) is named in `project.json` under `vftable_slots`.

A slot its own class leaves **pure virtual** points at `_purecall`, which says nothing
about the call, so neither its name nor its type can come from there. `vftable_slots` takes
a record instead of a name for those - `{"name": "GetTypeId", "signature": "int __thiscall
GetTypeId(COrder* this)"}` - and the slot is typed from the signature. `COrder`'s slot 16,
the order type id, is the one that needed it.

**A record on a base class names that slot everywhere below it.** `CPersistent` has no
virtual table of its own, but 754 classes derive from it and its six slots mean the same
thing in every one, so writing them once under `CPersistent` in `vftable_slots` puts `Save`,
`SaveContents`, `Load`, `LoadKey` and `AfterLoad` on 144 tables. It is the weaker of the two
claims: a name read off the slot's own body still wins, so a class that overrides slot 2 is
named for its own function and only the ones sharing the empty default fall back to the
inherited name. A record on the class itself still beats both.

**`CPersistent`'s five are named on every class that writes its own**, not just on the slot:
568 bodies, `CBuilding::LoadKey`, `CPromoteLeaderCommand::SaveContents` and so on, typed so
the call reads `LoadKey(this, parse, key)`. Which class owns which body comes from the RTTI
export - a class's `introduces` list is the implementations it wrote itself - so a body it
inherited is left to the base it came from, and the empty defaults `CPersistent` supplies are
left alone, since hundreds of unrelated classes share those. The names are built, not
written out: `buildFindings.py` walks the export.

**Where the base sits matters.** A class reaches CPersistent through a base at a non-zero
offset in five cases here - `CUnit` and `CProvinceBuilding` at +8, `CGameSetup` at +12,
`CEU3Gui` and `CEU3Graphics` at +4 - and then the five virtuals are in *that* base's table,
not the primary one, and `this` is the subobject rather than the class. The build follows the
offset, and writes those signatures as `__stdcall` with `void* base@ECX`: a method in a class
namespace has its `this` forced to the class's own type by Ghidra, so saying it any other way
does not survive. Add the offset to anything read off `base` to get a class offset.

**A class the compiler wrote no table for still gets one.** `CPersistent` is never
instantiated, so there is no table of its own anywhere in the image - but its own methods
call through one, and so does anything holding a `CPersistent*`. Its `vftable_slots` records
are enough to write the structure out, and slots it has a body for point at it, so
`CPersistent::Save` decompiles as `this->vftable->SaveContents(this, writer)` rather than
`(**(*this + 8))(writer)`. A slot the base has no body for carries a zero address, which the
script never reads; **not a null**, because a null throws in any copy of the script older
than this and the findings should stay readable by the one you already have.

**A slot the findings cannot name takes the name you gave the function**, and its signature
with it, so naming a virtual in the listing and re-running puts that name in every table
holding it - `CUnit`, `CArmy` and `CNavy` share one implementation of slot 19, and all three
follow. Only where the body is the class's own or inherited through one line of descent; a
folded body is left as `vf_<slot>` however it is named, since the name would be about
another class. Rename the function again and the next run follows again.

**The rest of BiceLib**: functions, hook sites, globals, vftables and class layouts from
`GameClasses`, `Hooks` and the `FINDINGS` files. A global with a `type` in `project.json`
is given that type, which is what makes the decompiler read through it -
`g_CCountryDataBase->countries_first[this->id]` rather than an offset. Where BiceLib and the game name the same
field, the game's name wins and BiceLib's name and notes go into the field comment.

Every function gets a plate comment marked `[BiceLib]`, with a confidence -
CERTAIN, LIKELY or TENTATIVE - and the evidence.

## Things to know

- **Conventions of the compiler's own.** A function the compiler kept private - never
  exported, its address never taken - is given whatever convention suited it, often with
  arguments in registers. Ghidra reads such a call as a standard one and prints whatever
  happened to be in the usual places, which is wrong in a way that looks plausible:
  `CCountry::IsEnemy` came out taking the *first* country in the database's array rather
  than the province's controller. Write the places into the signature in `project.json` -
  `bool __stdcall IsEnemy(CCountry* country@ESI, CCountryTag* tag@EDX, CMapProvince* province@EDI) @AL`,
  and `@stack:4` for a stack slot - and the script lays the function out with custom
  storage, so every call to it decompiles with the right values. **Write a place for every
  argument, not just the odd one**: custom storage is all or nothing, and an argument left
  without one is dropped from the call. `SaveWriteKey(int token@ECX, CSaveWriter* writer)`
  decompiled as `SaveWriteKey()`; with `writer@stack:4` it reads `SaveWriteKey(0x5a6, writer)`.
  **And do not write one where the convention already puts the argument there.** Added
  2026-10-05. Any `storage` at all flips the apply from `DYNAMIC_STORAGE_ALL_PARAMS` to
  `CUSTOM_STORAGE`, and on that path a `void` return does not survive - Ghidra keeps whatever
  return it had inferred. `CBomberCombatant::FireUnit` was written
  `void __stdcall FireUnit(CBomberCombatant* side@stack:4, CSubUnit* wing@stack:8)`, which is
  exactly where `__stdcall` puts two stack arguments anyway; the parameters landed, and the
  function still decompiled as `CBomberCombatant * FireUnit(...)`, which then typed the shot
  counter as a `CBomberCombatant*` and produced `shots = (int)&pCVar10->vftable + 1` for
  `shots = n + 1`. Dropping both annotations - same convention, same layout - gave
  `void CBomberCombatant::FireUnit(...)` and a clean counter. So: **annotate storage only
  where the convention is wrong**, which is the register cases above, and never as
  belt-and-braces on a stack slot the convention already describes.
- **`__thiscall` only works inside a class.** Ghidra gives a `__thiscall` function a `this`
  parameter of its own unless the function sits in a class namespace, and everything the
  findings write shifts one place behind it - so what the code passes in ECX reads as the
  argument after it. `SaveWriteValue(CToken* value, CSaveWriter* writer)` became
  `SaveWriteValue(void* this, CToken* value, CSaveWriter* writer)`, and every call to it
  showed three arguments with the wrong values in them. For a free function that takes
  something in ECX, write `__stdcall` and the place instead:
  `void __stdcall SaveWriteValue(CToken* value@ECX, CSaveWriter* writer@stack:4)`.
  `buildFindings.py` now says when a signature has that shape.
- **Shared code.** The linker folds identical functions into one, so one address can be
  `CMinister::IsValid`, `CLaw::IsValid` and five more. Those get a neutral name
  (`IsValid`, or `Shared_GetKey_GetReqProdQueue`) and a comment listing all of them.
- **Bodies too small to belong to anyone.** `xor al,al; ret` is written once in the whole
  executable, and that one address fills a virtual table slot in 407 classes; `mov al,1; ret`
  in 259, `mov eax,[ecx+0x24]; ret` in 155. A Lua registration still names one of them, and
  `CSubUnitDefinition::IsSecondRank` on the address would be a lie about the other 406. Those
  are named for what the body does - `ReturnFalse`, `ReturnTrue`, `GetDword_0x24`,
  `FieldAt_0x30`, `SetByte_0x4d`, `ReturnThis` - and every method registered there is kept as
  a label on the address. **In a class's own table the real name comes back**: a slot takes
  the label whose class this table belongs to, so `CMinister`'s slot 8 still reads `IsValid`
  while the other 258 read `vf_<slot>`. A name written out in `project.json` is left alone,
  and `buildFindings.py` says when one of them sits on a folded body.
- **`_purecall` is not shared code either.** A method a class leaves pure virtual has the CRT
  stub in that class's own vftable, so a Lua registration followed through the table lands
  there; three of them do. Naming the stub after them put `Shared_GetAIAcceptance_IsValid` on
  the address 26 vftable slots point at. Registrations that resolve to it are now left unnamed
  and listed by `buildFindings.py`, and the address is named `_purecall`.
- **Virtual methods** are registered through MSVC vcall thunks, which every class using
  that vftable slot shares: the thunk is named for the slot (`vcall_0xC`), and the
  implementation is looked up in the class's vftable from the RTTI export.
- **Addresses are checked** before they go out, against the executable rather than the
  notes. When the harvest was imported the notes did not all write addresses the same
  way, so both readings were tried and the one the code supports was kept; the notes
  have since been converted to module relative addresses throughout.

## A field inside another field is folded, not placed - and that is invisible in `project.json`

**Added 2026-10-06, after two of wave 14's four agents independently predicted a period-2 apply cycle
that cannot happen.** Both were reading the record correctly and reasoning from it correctly; the
thing neither could see is in `buildFindings.py`.

`merge_fields` ends with a fold: a field that lies **inside** a larger typed field is removed from the
generated output and its text appended to the host's comment as `+0xN inside it: ...`. So the record
may declare a field that **never reaches the apply at all**, and the apply therefore cannot report it,
cannot conflict over it, and cannot cycle on it.

The live case is the **id half of a `CCountryTag`**. `CCountryTag` is `0x8` bytes - `tag char[4]` at
`+0`, `id int` at `+4` - and the record holds **twelve** `int` fields sitting four bytes after a
`CCountryTag` field:

    CCountry +0xCA4 tag / +0xCA8 id            CMapProvince +0x32C owner / +0x330 owner_id
    CCountry +0xF38 Overlord / +0xF3C overlord_id   CMapProvince +0x334 controller / +0x338 controller_id
    CCountry +0x11D8 HighestThreat / +0x11DC ...    CUnit +0x124 owner / +0x128 owner_id
    CTheatre, CAIAgent, CEU3AI, CTradeRoute x3      CUnit +0x28C expeditionary_owner / +0x290 ...

Read off `project.json` alone, each of those is a 4-byte `int` overlapping the back half of an 8-byte
struct member - exactly the shape that produced the 2026-10-05 cycle. **Measured, none of them
overlaps anything**, because none of them is generated: a `scope: files` check of the generated file
shows `CMapProvince +0x330`, `+0x338`, `CUnit +0x128`, `CCountry +0xF3C` and `+0xCA8` all **absent**,
and `PrintStructs.java` shows Ghidra holding `CMapProvince +0x334 controller` as one `0x8`-byte
`CCountryTag` with **nothing at `+0x338`**. Three consecutive applies over them report
`struct fields: 0` and no conflicts.

So, three things follow.

- **An id-half field record is documentation, not a placement.** In the decompiler you reach it as
  `owner.id`. The record keeps it because the fold copies its comment into the host, which is where a
  reader actually sees it - so **deleting one loses a reading and gains nothing**. Wave 14's agent D
  recommended deleting `CCountry +0xF3C` on cycle grounds; that recommendation was declined on this
  evidence, and the field was **renamed** instead (`faction_leader_id` -> `overlord_id`, wave 13
  having renamed its tag half without touching it).
- **`struct fields: 0` does not mean "the whole record landed".** It means nothing new was *placed*.
  A folded field is outside what that number can see, which is worth remembering before reading the
  pass mark as a completeness check.
- **The fold is not reported anywhere.** `buildFindings.py` prints a `!` line for two fields that
  *overlap* - but that loop runs on the **post-fold** list, so a folded field is already gone and is
  never mentioned. Printing the folds, even once per struct, would have saved two agents the
  reasoning; it is queued in `CANDIDATES.md` rather than done here, because the output is noisy and
  the decision about its shape is the maintainer's.

## Declaring a struct from a fragment

**Added 2026-10-06 (wave 14).** `mergeFindings.py` used to refuse a `struct_fields` entry for a
struct `project.json` did not already hold, and a fragment had no way to add one - so a whole class's
layout could only reach the record by hand, and the queue had accumulated 27 of them. It now reads a
**`structs`** key beside `struct_fields`:

    "structs": [
     {"name": "CRelation", "size": "0x24", "inherits": "CPersistent",
      "vftable_rva": "0x11FBB00", "comment": "...", "evidence": "..."}
    ]

`name` and `evidence` are required; `size`, `inherits`, `vftable_rva`, `comment` and `source` are
optional and are written in the order `project.json` already uses. **Fields still go in
`struct_fields`** - a declaration carrying a `fields` key is refused, because that is where the
duplicate-offset and cross-fragment checks live.

Four checks, three of which have already caught something:

- **`inherits` is offset 0 only.** `buildFindings.py` copies the base's fields in at face value, so a
  base at `+8` would place every one of them eight bytes early. The merge walks the RTTI export
  transitively and refuses any other offset by name, and refuses a base RTTI does not give the class
  at all.
- **`vftable_rva` is checked against RTTI**, and this found **two wrong values already in the
  record**: `CBuildingConstruction`'s is `0x11BDCD4` where the table starts at `0x11BDCAC` (ten slots
  in), and `CConvoyConstruction`'s is `0x11BDD34` against `0x11BDD04` (twelve slots in). The RTTI
  complete-object-locator pointers sit at `0x15BDCA8` and `0x15BDD00`, so each table begins at the
  next dword. Both classes have exactly one table in RTTI, so there is no second table to explain it.
  Queued as a hand fix of two strings. A name RTTI does not know (`Session`, `CommandChannel`) is
  exempt, which is why the check is a refusal rather than a warning.
- **Trap 1 is caught directly**: a `vftable_rva` that only resolves when read as a VA is refused with
  "subtract the image base".
- **It is create-only.** A struct the record already holds, declared again with nothing different, is
  skipped the way a repeated address entry is; declared with something different it is refused and the
  message says why a revision is a hand edit. The reason it is not more than create-only: **`size` can
  sit on either side of the `fields` array in that file** - `CBomberCombatant` has `fields` then
  `size`, `CRegiment` has `size` then `fields` - so there is no single textual header to rewrite
  safely.

Insertion is textual, against the `\n ],\n "equates": [` anchor, mirroring the addresses insertion;
and `land()` now asserts after writing that the structs and addresses arrays grew by **exactly** what
was declared. That assertion is trap 18's JSON corollary and is the check that would have caught the
2026-10-05 accident where a struct object was spliced into the `addresses` array because the anchor
matched a class's vftable entry first.

## The Lua API census, 2026-10-06 - and the seven abandoned classes

**The maintainer's hypothesis, and it holds:** parts of the Lua API are unfinished, so the Lua half of
the fact base cannot be trusted uniformly. `buildFindings.py` gave every Lua registration **priority
0** - "what the game names wins" - which is right for a live registration and wrong for an abandoned
one, because nothing ever exercised it and its name and type were never checked against reality by
anybody, including whoever wrote it.

`scripts/luacensus.py` measures it. Two questions, deliberately kept apart:

- **Reachable** - can a script obtain an instance? Constructible from Lua, or returned by a member of
  a reachable class, or by a free function. Computed to a fixpoint.
- **Used** - does any script name it? A text census over both Lua corpora the engine loads: **106
  vanilla files** and **194 mod files**, by the idiom the scripts really use - a method is
  `obj:GetX()`, so the Lua-visible name is the accessor's own name out of `evidence`, while a
  `def_readwrite` member is `obj.name`.

    classes registered           125
      reachable from script       96    (68 used, 28 reachable but nothing calls them)
      engine-pushed               22    not obtainable, yet scripts use them
      DEAD                         7    unreachable AND nothing names them
    members registered           227    (153 used)

**The middle row is a correction to the first version of this census**, which had 29 "unreachable"
classes and was wrong: it put `CEU3AI`, `CUnit`, `CCurrentGameState` and the five AI ministers in that
bucket, all of which are plainly live - `GetOwnerAI` and `GetCountryTag` are called constantly. They
arrive as the **`self` of an engine-called entry point**, which reachability-by-construction cannot
see. So a class that is unreachable *and* used is evidence the engine hands it in; only unreachable
*and* unused is dead.

**The seven dead classes:** `CAISubscriber`, `CConstructSingleUnitCommand`, `CConvoy`, `CEventScope`,
`CList<CCountryTag>`, `CNullTechnology`, `CResearchBonus`. Between them they carry seven members, none
of which any script names. `CEventScope` is the clearest case: **no constructor, nothing returns one**,
and the only two mentions of it in the whole API are as an *argument* -
`bool IsPotential(CDecision&, CEventScope&)` and `bool IsAllowed(CDecision&, CEventScope&)` - on
`CDecision`, which is **itself** unconstructible and returned by nothing. Two classes that can only be
reached through each other and through nothing else.

The negative carries its control: `CEventScope`, `CDecision`, `IsPotential`, `IsAllowed` and
`_nProvince` match **0** files in either corpus under a word-boundary grep, while the same search
finds `GetCountryTag` in 66 vanilla and 22 mod files, `PostAction` in 23 and 4, `CString` in 12 and
12. (A single `IsAllowed` hit in the repo is in `tools/wxWidget/.../controls.wx.lua`, a bundled
wxWidgets sample, which is why the corpus is `script/` and `common/` rather than the whole tree.)

### What changed in the generator, and it is two rules, not one

The tempting story is that deadness caused the bad type. **It did not** - checking all twenty
`def_readwrite` members shows the correlation is a coincidence of small numbers, and the real cause is
mechanical:

| the four class-typed `def_readwrite` members | type | |
| --- | --- | --- |
| `CResearchBonus._pCategory`, `CSubUnitConstructionEntry.pUnit` | `T const*` | **genuine pointers** - and the game's own naming agrees, both carrying the `p` |
| `CEventScope._Country`, `CResearchBonus._vWeight` | `T&` | **by-value members**; luabind's `def_readwrite` getter returns a reference, so the `&` is the accessor's and not the member's |

So two independent rules now apply, and each fixes something the other does not:

1. **A trailing `&` on a `def_readwrite` field is stripped.** The member is a `T` by value. Keyed on
   the `evidence` string, so the six **accessor-derived** `T&` fields are untouched - the five
   `OwnerAI CEU3AI&` back-references and `CList<…>.TailData` - where a `T&` return legitimately means
   a pointer member. Without this, `CResearchBonus +0x4` stays a spurious pointer, because
   `project.json` holds no `CResearchBonus` to outrank it.
2. **A field on a dead class drops to priority 4**, below `project.json`'s own notes, so the record
   wins the name and type. Without this, `CEventScope +0x10` would land as an 8-byte by-value
   `CCountryTag` - defensible, but it would fold `country_id` and leave the struct reading differently
   from the identical `from_country_tag`/`from_country_id` pair four bytes later.

Both are driven by `ghidra/luausage.json`, **generated** by `scripts/luacensus.py` and consumed by
`buildFindings.py` if present - absent, the build degrades to the old behaviour rather than failing.
Each affected field's comment now says which verdict applied and why, so the Lua name and type are
preserved as information rather than discarded.

**Measured blast radius**, by building with and without the census and diffing field by field:
**six changes, all on dead classes, nothing live touched.**

    CConvoy     +0x90  DesiredTransports -> transports_wanted   (the record's own name wins)
    CConvoy     +0x94  DesiredEscorts    -> escorts_wanted
    CConvoy     +0xA0  isForTradeRoute   -> is_trade
    CEventScope +0x10  _Country CCountryTag -> country_tag char[4]
    CEventScope +0x28  _nProvince        -> province
    CEventScope +0x14  country_id reappears, no longer folded

Three applies after: `struct fields: 40`, then `0`, then `0`, with `replaced: 0` and `failed: 0`.

### What this is good for beyond the one bug

`scripts/luacensus.py --unreachable` splits the no-constructor classes into engine-pushed and dead,
and `--class CUnit` prints one class with its per-member usage counts. **The 28 reachable-but-unused
classes are not a problem** - the API is wider than any one mod, and a modder may reach for them
tomorrow. The seven dead ones are different: no mod can use them however much it wants to, so a
disagreement between those registrations and the record should always be settled in the record's
favour.

### The three limits, and why none of them reaches the verdict

**"Used" is an upper bound**, because this is a text census and not a call graph. Two collisions
inflate it: a member name matching a script's own local function, and a member name registered on
several classes. Ten names are shared that way - `GetCountryTag`, `GetType`, `GetSize`, `GetIndex`,
`GetKey`, `GetGroup`, `GetOwnerAI`, `GetPriority` and two more - and **11 classes rest on nothing
else**: `CBuilding`, `CCountryTag`, `CDiplomaticAction`, `CIdeology`, `CIdeologyGroup`, `CLaw`,
`CLawGroup`, `CMinisterType`, `CRegion`, `CTechnologyCategory`, `CTechnologyFolder`. `CWarGoal` is the
plainest: marked used only because `GetCountry` matches 134 files, which will be `CCountry` work on
other classes. **So read "68 used" as "at most 68".**

**That cannot touch either verdict this feeds.** A collision only ever *adds* matches, so a class with
zero on its own name and zero on every member genuinely has none - which is the whole DEAD set and the
whole reachable-but-unused set. And `buildFindings.py` demotes a field only when its class is
unreachable **and** unmatched, so the soft number is not load-bearing anywhere.

**The engine-pushed route is bounded by the corpus, not by the bytes.** A class arriving as a callback
argument would have to be received by a function in one of these 300 files and used without ever being
named - in a type check, a constructor call or a comment. For the seven, nothing names them at all.

## Organising the type tree - the `organise` flag, 2026-10-06

The data type tree had drifted to **203 categories over 6406 types**, with classes at the root,
classes in `/BiceLib`, vftables outside the folder named after them, and categories like
`/VCCountry/__CMessageDialog` and `/_A0x1e0c5124`. Measured with `ghidra/PrintTypeTree.java`
(`--all` for every category, `--dump` for `name<TAB>kind<TAB>category` to join against the record
offline), the mess turned out to have four causes and only two of them ours.

### What was wrong

| cause | size before | |
| --- | --- | --- |
| `/BiceLib/vftables` | 3250 types, **0 structs** | **It held no vftable.** These are the per-slot *function definitions* that let a virtual call decompile with a real signature. The folder's name meant the opposite of what it said |
| `/` root | 1761 types, 1047 structs | **266 of the 309 recorded class structures were here** |
| `/BiceLib` | 734 types, 379 structs | where the apply *created* a struct - only 42 of our classes, plus all 320 vftable structs |
| demangler artefacts | 113 categories / 116 types, plus 43 `_A0x...` / 69 types | Ghidra parsing mangled RTTI and template names |

**The root cause was one line of this script.** `structFor` creates a new structure in `/BiceLib`,
but `findType` finds an existing one **wherever it already lives** and then edits it in place.
Ghidra's RTTI pass runs first and creates most game classes at the root, so we were adding fields
to them and never moving them. It was not chaos so much as two tools disagreeing in silence.

### The scheme

    /                              Ghidra's own; nothing we claim
    /BiceLib/classes/              the recorded game classes
    /BiceLib/classes/containers/   the generated CList/CListNode/CArray instantiations
    /BiceLib/vftables/             the vftable structures
    /BiceLib/vftables/slots/       the slot function definitions
    /BiceLib/enums/                the enums

`organise` sets the category on **every** run rather than only on the run that creates the type,
which is the only way this survives the next analysis pass inventing a type at the root. **It moves
nothing whose name the findings do not carry**, so what you made by hand stays where you put it -
the same courtesy the field and signature rules already give.

**Two kinds are deliberately left alone**, both for the same reason: the SDK and CRT categories are
correct and not ours, and the demangler's own (`_A0x...`, `/VCCountry/__CMessageDialog`) are
**recreated from mangled names by a pass that would undo the move**, so emptying them is a fight
rather than a fix.

### The result, measured on a fresh copy of the maintainer's project

    before                                  after
    /                1761 / 1047 structs    /                       1211 /  729 structs
    /BiceLib          734 /  379 structs    /BiceLib                 129 /   71
                                            /BiceLib/classes         714 /  370
                                            /BiceLib/classes/containers 88 /  55
    /BiceLib/vftables 3250 /    0 structs   /BiceLib/vftables       1972 /  320 structs
                                            /BiceLib/vftables/slots 5592
                                            /BiceLib/enums            17 /   16 enums

**The first `organise` takes three runs to settle**, then is idempotent: `moved: 2273`, then 393,
then 0, with `struct fields: 0` and `failed: 0` from the third on. The sweep runs before the
vftable pass and that pass creates definitions after it, which is where the tail comes from. A
plain `overwrite` run afterwards changes nothing, and the two can be interleaved freely.

### Running it

**In the GUI**, where the Script Manager cannot pass a script arguments, run
**`ApplyBiceLibFindingsOrganise.java`**. It asks once, then runs the apply **three times by
itself** and prints `=== organise pass N of 3 ===` between them, so there is no question of
having run it enough; the last line tells you what the final pass should read. It is the same
relation `ApplyBiceLibFindingsOverwrite.java` has to `overwrite`, and like that one it exists
only because of the arguments limitation.

**Headless**, `-postScript ApplyBiceLibFindings.java overwrite organise`, three times - or
`-postScript ApplyBiceLibFindingsOrganise.java` once, which does the three internally and works
headless too.

Either way the pass mark is the same as everywhere else here: the last run reading
`struct fields: 0, moved: 0, failed: 0`. Three `!` notes are expected and are the duplicate-name
guard working rather than a problem - `bad_alloc` and `fixed_point___int64_48_15_` exist in both
`/std`//`fpml` and our folder, so they are left where they are instead of being merged into
something that would then describe the wrong object.

### Four things this cost, each worth knowing before touching it again

- **`instanceof FunctionDefinitionDataType` is false for every definition in the manager.** A type
  resolved into a `DataTypeManager` comes back as Ghidra's own DB-backed implementation, so the
  first sweep matched nothing while reporting success. Test the **interface**, `FunctionDefinition`.
- **Never delete a slot definition to tidy a duplicate.** A structure field points at it through a
  pointer, so removing it turns the pointer and the field into `-BAD-`; the vftable pass then
  re-places the field, resolving a fresh pointer that re-anchors a definition in the old folder,
  and the next run sweeps it again. That churned **666 fields on every run and never converged**.
  The sweep now moves what it can and leaves a duplicate alone; Ghidra's own *Remove Unused Data
  Types* clears the ~666 dead definitions and their stale pointers.
- **`organise` adds, it does not toggle.** An earlier version swept back when the flag was absent,
  so a plain `overwrite` silently undid the organisation and alternating the two moved thousands
  of types each way. And `slotType` must **reuse an existing definition wherever it lives** and let
  the flag decide only where a *new* one is created - looking only in the flag's folder made a
  plain run recreate every definition in the old one and retype all 1918 vftable fields.
- **Match container names after `sanitize`, not before.** Ghidra names cannot hold `<`, `>` or `*`,
  so `CList<CAir*>` is the type `CList_CAir__`. A pattern written against the C++ spelling matched
  nothing and left all 55 containers in `classes`.

### Why there is no subsystem split

Grouping the classes by area was measured and rejected twice. **Name prefixes** leave 88 of 365 in
"other" and need a hand-kept mapping that drifts as classes are added. **The findings file that is
the plurality source of a struct's fields** - already in the record and self-maintaining - gives
**91 keys, 68 of them holding one or two structs**, with 97 structs carrying no source at all. Both
reproduce the problem they were meant to solve, so the scheme has no subsystem axis: six folders,
every placement derivable from the generated record, and nothing to maintain by hand.

## Rebuilding

    python ghidra/luabindExtract.py      # only if the executable changes; needs pefile, capstone, unicorn
    python ghidra/buildFindings.py       # after editing project.json

`luabindExtract.py` explains how the recovery works: it emulates the game's own
registration function and luabind's signature formatter rather than pattern matching.
