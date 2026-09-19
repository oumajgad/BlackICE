# Ghidra: applying what BiceLib knows

`ApplyBiceLibFindings.java` names, types and comments a Ghidra program of `hoi3_tfh.exe`
from `bicelib_findings.json`, which sits next to it.

| file | what it is |
| --- | --- |
| `ApplyBiceLibFindings.java` | the Ghidra script |
| `ResetBiceLibFunction.java` | hands one function back to it, when your own edit of it should give way |
| `ResetBiceLibOrphans.java` | clears names it put down and has since withdrawn |
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
`reversing/saveTokens.py --compiled`) becomes the `SaveToken` enum and
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

## Rebuilding

    python luabindExtract.py      # only if the executable changes; needs pefile, capstone, unicorn
    python buildFindings.py       # after editing project.json

`luabindExtract.py` explains how the recovery works: it emulates the game's own
registration function and luabind's signature formatter rather than pattern matching.
