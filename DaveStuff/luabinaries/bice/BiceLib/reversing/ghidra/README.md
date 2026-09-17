# Ghidra: applying what BiceLib knows

`ApplyBiceLibFindings.java` names, types and comments a Ghidra program of `hoi3_tfh.exe`
from `bicelib_findings.json`, which sits next to it.

| file | what it is |
| --- | --- |
| `ApplyBiceLibFindings.java` | the Ghidra script |
| `ResetBiceLibFunction.java` | hands one function back to it, when your own edit of it should give way |
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

**Re-run it after every rebuild of the findings**, since that is where everything new
lands - the script itself hardly changes.

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
`lea eax,[ecx+N]; ret`), 13 enums with their values, and class sizes where luabind
constructs the object.

**Virtual tables**: a structure per table, and a pointer to it on the class, so a call
through one reads as `unit->vftable->GetAverageOrganisation()` rather than
`(**(*unit + 0x50))()`. The tables are read out of the executable and their length comes
from the RTTI export; a slot whose function is the class's own takes that function's name
and a pointer to its definition, which is what gives the call its arguments. The rest are
`vf_<slot>`, because **the linker folds identical bodies together** - every `mov al,1; ret`
in the game is one address - so a name from elsewhere would say something false about this
class. What BiceLib knows but cannot read off a folded slot (`isLand`, `isNaval`, `isAir`
and the rest) is named in `project.json` under `vftable_slots`.

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
  storage, so every call to it decompiles with the right values.
- **Shared code.** The linker folds identical functions into one, so one address can be
  `CMinister::IsValid`, `CLaw::IsValid` and five more. Those get a neutral name
  (`IsValid`, or `Shared_GetKey_GetReqProdQueue`) and a comment listing all of them.
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
