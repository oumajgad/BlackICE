# Ghidra: applying what BiceLib knows

`ApplyBiceLibFindings.java` names, types and comments a Ghidra program of `hoi3_tfh.exe`
from `bicelib_findings.json`, which sits next to it.

| file | what it is |
| --- | --- |
| `ApplyBiceLibFindings.java` | the Ghidra script |
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

**To have the findings win instead**, run `ApplyBiceLibFindingsOverwrite` (it asks once
before it starts), or headless `-postScript ApplyBiceLibFindings.java overwrite`. Every name
and signature the findings cover is replaced whoever set it, conflicting struct fields are
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

**The rest of BiceLib**: functions, hook sites, globals, vftables and class layouts from
`GameClasses`, `Hooks` and the `FINDINGS` files. A global with a `type` in `project.json`
is given that type, which is what makes the decompiler read through it -
`g_CCountryDataBase->countries_first[this->id]` rather than an offset. Where BiceLib and the game name the same
field, the game's name wins and BiceLib's name and notes go into the field comment.

Every function gets a plate comment marked `[BiceLib]`, with a confidence -
CERTAIN, LIKELY or TENTATIVE - and the evidence.

## Things to know

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
