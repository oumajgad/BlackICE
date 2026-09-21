# The event script language

Every condition an event, a decision or an AI file can test, and every effect it can
have - read out of the two loaders that parse them. **Generated in part**; regenerate
the tables with

```
python switchmap.py 0x9C8D10 --md     # the triggers
python switchmap.py 0x999CA0 --md     # the effects
python scriptcheck.py                 # what the mod says that none of it is
```

## How the two loaders work

`CTrigger::LoadKey` (`0x5C8D10`, 9728 bytes) and `CEffect::LoadKey` (`0x599CA0`, 8136
bytes) are the two biggest loaders in the game, and they have the same shape: **one switch
over the save token of the key**, a case per keyword, each case building the class that
implements it. There are 152 trigger keywords and 91 effect keywords, and every one gets a
class of its own - 243 classes in all, which is why the RTTI export is full of names like
`CAmountOfBrigadesTrigger`.

That also explains why `PROGRESS.md` ranks these two first and counts 157 and 74 classes
against them: **a `LoadKey` is inherited**, so every one of those classes has this same
loader and reading it once reads all of them.

A key that is not a keyword falls through to the default, which tries, in order: a
province id, an ideology, and then a lookup that ends in the technology database - which
is how `divisonal_command_structure = 1` works as a condition. Anything that is none of
those is a parse error, and **the condition or effect is dropped**. That is the failure
mode `scriptcheck.py` looks for.

## Reading a switch this wide

Worth knowing before doing this to another loader, because the first attempt got it wrong
twice:

- **Do not parse the decompiler's C.** Ghidra renders part of a switch this size as nested
  ifs and puts cases into shapes a regex misses. Parsing the C found 77 of the effect
  loader's 91 keywords and silently dropped `kill_leader`, which BiceLib already has a
  hook on. Reading the switch itself found all 91.
- **A case body's class is the last vftable it writes, not the first.** A derived
  constructor calls its base first and the base writes its own vftable before the derived
  one overwrites it. Taking the first match names all 152 triggers `CTrigger`.
- **The default branch has to be dropped.** MSVC's jump table sends every token in the
  gaps to the default, so keeping it turns 277 tokens into cases and gives them all the
  default's class.
- **A loader that keeps its key on the stack compares memory, not a register.**
  `CCountryHistory::LoadEntry` takes the key as its fourth argument and never loads it
  into a register: the whole tree is `cmp dword ptr [ebp - 0x67c], 0x1f9`. Reading only
  register compares found 23 of its 33 keys and made `capital`, `government` and
  `ideology` look as though the handler did not know them. One stack slot is compared far
  more than any other and that is the key.
- **A `jne` to the default leaves the case body as the fall-through.** `cmp eax, K / jne
  out` is a case for K written the other way round, and the body is what follows rather
  than what is jumped to. It is always the last case of a chain, so missing it loses one
  key per chain - `defender` in `CCombatTactic`, `port` in `CTrigger`.
- **The jump table's base may be applied with `lea`**: `lea eax, [edi - 0x78d]` does what
  `sub` does without touching the register the token arrived in. Missing it loses that
  whole table - 19 of `CCasusBelliType`'s 28 keys.
- **A case body is not on the path the tree is on.** Reading the function end to end runs
  straight through bodies that `pop edi` before returning, and after the first of those
  the key register is lost for every comparison that follows. A `ret` ends a path, so the
  key is live again after one; without that, `CCasusBelliType` hid `threat` and `always`.
- **A short run indexes the jump table directly**, with no byte table in front of it -
  `jmp dword ptr [eax*4 + table]` and nothing else. The byte table only pays for itself
  when several tokens share a case, so requiring one misses every small switch whole;
  `CRelation` and `CWeather` have nothing else.
- **Only an unsigned bounds check names the default.** A switch tests its range with `ja`,
  because the compiler leans on wraparound to catch anything below the base; the `jg` and
  `jge` around it belong to the comparison tree. Taking a signed one as the default marks
  real case bodies unreachable and deletes them.
- And one that is nobody's fault but the reader's: **do not shadow the variable holding
  the key's stack slot**. Reusing the name for a byte-table index made every later memory
  compare fail to match, and two grammars looked incomplete for it - the four province
  resources in `CProvinceHistory` were plainly in the switch the whole time.
- MSVC spends its last few cases as a **subtract-and-test chain** -
  `sub eax, 0x77 / je year / dec eax / je month` - rather than a table. Missing that shape
  loses whichever keywords land in it; here it was `year` and `month`. **The chain does not
  always run in eax** - `CCasusBelliType` runs its in edi.

## The primitives a loader is written in

Every loader is the same handful of calls, so naming them once makes all 266 readable.
Addresses are module-relative.

| | |
| --- | --- |
| `0x67A7B0` | **`ReportUnknownKey(parse@EDI)`** - where a key with no case goes. It does **not** log; see below |
| `0x67A960` | `ReportParseError(parse@ESI)` - a key that is known but whose value will not parse |
| `0x67B470` | `ParseInt(parse@ECX, int* out@EAX)` - `sscanf` with `%i` |
| `0x67B410` | `ParseBool(parse@EAX, bool* out)` - `yes` or `no`, anything else an error |
| `0x67B250` | `ParseObjectId(parse, int* pair)` - the `{ type id }` pair a save writes for a reference |
| `0x67B8D0` | `ParsePoint(parse@EAX, out)` - an `{ x y }` block |
| `0x67AFB0` | `ParseString(parse@ECX, Hoi3CString* out)` |

`ParseInt` and `ReportUnknownKey` are confirmed from call sites that set the register;
the rest have the convention **inferred** and are marked so in the findings.

### Nothing is written when a mod's file has a bad key

`ReportUnknownKey` builds the text `"Unexpected"` plus the key and **appends it to a list
on the parse context** - first at `+4`, last at `+8`, count at `+0xC`, nodes linked
through `+0x40`. That is all it does. Whether a line is ever written depends on somebody
asking the list for its contents afterwards:

```
ReportUnknownKey            0x67A7B0   queues the message
CParseContext::MessagesAsText 0x67AB40  joins them, one per line - the list's only reader
CParseContext::ReportMessages 0x67C050  the only caller of that, logs under persistent.cpp
CParseContext::FreeMessages   0x67BAF0  the destructor's, frees them without a word
```

**`ReportMessages` has seven callers and none of them loads a `common/` file**:
`CGameState::LoadKey` (a savegame), `CUnitPlan::LoadKey`,
`CSetPlanObjectivesCommand::LoadKey`, the bookmarks loader, and three DLC and
competitive-mode paths. The `common/` driver builds a parse context, runs the file
through it and destroys it, and the destructor frees the messages unread - checked on the
ideologies loader at `0x236800`.

So **a bad key in `common/`, `units/`, `history/`, `events/` or `decisions/` produces no
output at all**, anywhere, ever. Confirmed against a full load: no log in the game's `logs`
folder contains `persistent.cpp` or the word `Unexpected`.

The per-class lines that *do* appear - `[minister.cpp:186]`, `[building.cpp:429]`,
`[traits.cpp:358]` and the rest of what fills `setup.log` - are each loader's own logging,
nothing to do with this path.

### Where a message really lives or dies

`ReportUnknownKey` is not the only way a key is dropped, and hooking it is not enough to
see a mod's mistakes. **A loader that resolves a key as a name has its own failure path**:
an unknown key in a country file goes through four database lookups and ends at
`countryhistory.cpp:450`, `Unknown History Command ==>'<key>'`.

Every message in the game, that one included, is built into a **log record** - the sink at
`+0x50`, the source file at `+0x54`, the line at `+0x70`, the channel at `+0x74` - and
flushed by its destructor:

```
LogRecord::LogRecord   0x2464E0   builds the record with file, line and channel
LogRecord::Flush       0x24B0     the destructor, which hands it on
LogSink::Write         0x7082C0   sink->vftable[1](channel, file, line, message)
g_log_sink             0x17162A4  the sink, installed from main.cpp at 0x658D7F
```

**`LogSink::Write` is where they all meet**, with the four already pulled apart, and it is
the channel that decides whether a file is written. `eu3application.cpp` on `0x10000`
reaches `setup.log`. The fallback sink's writer, used before the real one is installed,
is `ret 0x10` and nothing else.

#### What hooking it answered, and why the hook is gone

On 2026-09-20 BiceLib hooked `0x7082C0` and copied a whole startup out - **20,098
messages**, from `eu3application.cpp:274  App Init` to `frontend.cpp:583  done frontend`.
The hook has since been **removed**, because what it measured is that it was redundant.
Everything below is what that run established; the code is in git history if it is ever
wanted back.

**The capture was exactly the game's own output, message for message.** Counting the same
run both ways:

| | hook | game's file |
| --- | --- | --- |
| `0x10000` / `setup.log` | 6529 | **6529** |
| `0x10002` / `game.log` | 3308 | **3308** |
| `3` / `system.log` | 158 | 199 (41 before the hook) |
| `0x10006` / `time.log` | 44 | 48 (4 before the hook) |

The two that begin after `autoexec.lua` match **exactly**, which settles the last open
question about the sink: **the filter it opens with drops nothing**. The hook added no
message the game's own four logs lack.

**45 lines preceded it** - 41 on `system.log` (`systemsettings.cpp`, `main.cpp:504/532/592`,
the first `graphicssettings.cpp`) and 4 on `time.log` (`main.cpp:519/522/523/589` -
text.csv, files, blob). A hook installed from `autoexec.lua` cannot reach them, and that
is the one thing it could not fix. **Catching those needs to be in the process before the
game is**, which is what a `dinput8.dll` shim would give; that is the route to take if
this is picked up again.

**The channel-to-file mapping, all four that fire**, each confirmed by finding one of its
messages in the file:

| channel | file | e.g. |
| --- | --- | --- |
| `3` | `system.log` | `eu3application.cpp:274  App Init` |
| `0x10000` | `setup.log` | `modifier.cpp:575  StaticModifier #120 tag = ...` |
| `0x10002` | `game.log` | `trigger.cpp:365  Fixed trigger dependency for ...` |
| `0x10006` | `time.log` | `eu3application.cpp:775  Initialising Graphical Map <3.48>` |

**Every channel produced reaches a file.** Nothing was being dropped in silence, so the
premise that a hook would reveal hidden messages was wrong - it revealed that there are
none. That, plus the exact line counts above, is why the hook was not kept: it cost a
flush per line and ~900 KB a run to reproduce four files the game already writes.

**`countryhistory.cpp:450` never fired**, and that is the finding. The site is real:

```
005ee7e6  push 0x10004          ; the channel
005ee7eb  push 0x1c2            ; line 450
005ee7f0  push <countryhistory.cpp>
005ee7fd  call 0x402410         ; build the record
```

with the same shape at `provincehistory.cpp:259` and `diplomatichistory.cpp:196`, all
three on channel `0x10004` - the one channel seen in the code and never in the log. Bug 9
in `bugs.md` would have fired the country one **219 times**.

It fired none because **those keys are not unknown to the engine**. Just above the log
block sits `005ee7b8  jmp 0x5ee8ad`, the success path jumping clean over it. A history key
that is not one of the loader's own is resolved as a *name*, and **a name that is not
found comes back as index 0** - a real index, holding that database's null object. The
loader is handed an object, takes the success branch, and never reaches the error. This is
the same null-at-index-0 that makes every name database 1-based.

So an unknown *key* would be logged; a key that is a **bad name** is not an error at all.
The mod's bugs are all the second kind, which is why no log has ever shown them and no log
setting ever will. Static analysis is the only way to find them.

**The dispatch itself is unconditional**, which is what makes that reasoning sound - a
message that was built could not have been missed. The record's destructor at `0xa6484f`
does

```
mov ecx, [edi - 0x28]   ; the sink
mov eax, [ecx]          ; its vftable
mov eax, [eax + 4]      ; slot 1
... push message, line, file, channel
call eax
```

with no test of any kind, and the hook sat on the writer's own prologue - ahead even of
the filter `LogSink::Write` opens with (`call 0x40C3C0` on a global at `0x16052F0`, which
drops the message when it answers true). So if a message was built, the hook saw it.

**One thing is still unknown**, and it no longer matters much: whether `0x10004` reaches
`error.log`. It is the only channel with no observed message. `error.log` is 0 bytes,
which is consistent either way.

Two classes turn out to have no grammar worth the name. **`CColor::LoadKey` is a single
tail call to `ReportUnknownKey`** - a colour is three numbers read positionally, and that
answer covers the 74 classes that inherit it. **`CReferenceObject::LoadKey` has one key**,
`id`, read as an object id pair into `this + 8`; its 19 heirs get `id_type` at 0x8 and
`id` at 0xC from it, which is exactly where CMinister keeps them.

## What the mod says that none of this is

`scriptcheck.py` takes every key in `events/` and `decisions/`, subtracts the two keyword
lists, every name the mod opens a block for anywhere, and the technologies and tags a
running game holds. What is left is **62 names in 508 uses that nothing declares**, and
each one is a condition or an effect the engine drops on the floor.

```
submarine_crew_training_hidden                      25  unique_unit_techs.txt
smallarms_technology_hidden                         25  unique_unit_techs.txt
light_infantry_brigade_activation_hidden            25  unique_unit_techs.txt
interservice_communication_hidden                   25  unique_unit_techs.txt
heavy_aa_guns_hidden                                25  unique_unit_techs.txt
aam_hidden                                          25  unique_unit_techs.txt
small_calibre_gun_design_hidden                     21  unique_unit_techs.txt
navalstrike_tactics_hidden                          21  unique_unit_techs.txt
medium_velocity_gun_hidden                          21  unique_unit_techs.txt
artillery_support_gun_design_hidden                 21  unique_unit_techs.txt
carrier_medium_anti_air_artillery_hidden            17  unique_unit_techs.txt
capital_ship_medium_anti_air_artillery_hidden       17  unique_unit_techs.txt
trade_interdiction_submarine_doctrine_hidden        13  unique_unit_techs.txt
submarine_construction_technolgies_hidden           13  unique_unit_techs.txt
political_integration_hidden                        13  unique_unit_techs.txt
encryption_machine_hidden                           13  unique_unit_techs.txt
Ship_Building_Technologies_hidden                   13  unique_unit_techs.txt
Corps_command_structure_hidden                      13  unique_unit_techs.txt
AI_multi_role_range_hidden                          13  unique_unit_techs.txt
AFV_AA_defense_hidden                               13  unique_unit_techs.txt
airborne_command_and_control                        12  unique_unit_techs.txt
aam                                                 12  unique_unit_techs.txt
change_owner                                        10  Japan.txt, OperationBritanniaRising.txt
has_naval_base                                       8  Australia.txt
carrier_medium_anti_air_artillery                    8  unique_unit_techs.txt
capital_ship_medium_anti_air_artillery               8  unique_unit_techs.txt
Ship_Building_Technologies                           8  unique_unit_techs.txt, zBI_GER_Events.txt
carrier_AAA_control_computer_hidden                  7  unique_unit_techs.txt
special_forces_increase                              5  JAP_new_events.txt, OMG_Decisions.txt
special_forces_decrease                              3  unique_unit_techs.txt
politics                                             3  broadcasting_decisions.txt
long_lance_hidden                                    3  unique_unit_techs.txt
heavy_planes_construction_hidden                     3  unique_unit_techs.txt
fleet_auxiliary_submarine_doctrine_hidden            3  unique_unit_techs.txt
fixed_torp_hidden                                    3  unique_unit_techs.txt
faulty_torp_hidden                                   3  unique_unit_techs.txt
carrier_AAA_control_computer                         3  unique_unit_techs.txt
active_sonar_sub_hidden                              3  unique_unit_techs.txt
AI_Naval_Command_Tech_hidden                         3  unique_unit_techs.txt
long_lance                                           2  Japan.txt, unique_unit_techs.txt
```

Three worth calling out:

**`events/unique_unit_techs.txt` is most of it** - 463 uses. It tests a long list of
`*_hidden` technologies that no longer exist, `aam` and `aam_hidden` among them. `aam` is
commented out in `technologies/Secret Weapons.txt` at line 529, so the whole branch of
that file that depends on it can never fire.

**`change_owner` is not an effect.** It is used ten times, in `events/Japan.txt` and
`events/OperationBritanniaRising.txt`, always beside a `change_controller` that *is* one:

```
9348 = {
    change_owner = TIB          # dropped
    change_controller = TIB     # works
}
```

so those provinces change hands on the map but keep their owner. The effect the engine has
for that is `secede_province`.

**`has_naval_base` is not a trigger** - eight uses in `events/Australia.txt`. The building
is tested by its own name, `naval_base`.

## CTrigger's virtual table, and where a condition is answered

A trigger is not only parsed, it is **run**, and that happens through its virtual table.
`CTrigger`'s has **12 slots**; 1 to 5 are `CPersistent`'s save and load, and the ones that
matter are its own:

| slot | name | what it is |
| --- | --- | --- |
| 6 | **`Evaluate`** | `bool Evaluate(CEventScope* scope)` - **the condition itself** |
| 8 | `GetText` | `Hoi3CString* GetText(out, scope, ...)` - the condition as the tooltip shows it |
| 10 | `WalkChildren` | forwards its four arguments to slot 10 of each child |
| 11 | `CountEvaluation` | calls its own `Evaluate`, then `++*passed` if true and `++*total` always |

**Slot 6 is the evaluate, and the proof is self-referential.** `CAndTrigger::Evaluate`
walks the child list at `this+8` and calls `[vftable+0x18]` - slot 6 - on each child with
the same scope. A trigger that ANDs its children by calling slot 6 on each *is* slot 6.
Two more confirmations: every one of the **163** triggers overrides it, all with `ret 4`,
so it takes one argument; and `CAlwaysTrigger::Evaluate` is the whole of

```
mov al, byte ptr [ecx + 0x40]
ret 4
```

- `always = yes` read straight back out of the object. `CTagTrigger` ends `sete al`.

Slots 6 and 8 are **pure virtual on CTrigger** - the base's table points at `_purecall` -
which is why the findings carry their signatures rather than reading them off a body.

`WalkChildren` and `CountEvaluation` are **BiceLib's names**, from what the bodies do;
the game's own are not known. Together they look like the machinery behind a tooltip that
says how many of a list of conditions are met.

**Slot 6 means something else on CEffect** (`mov eax, [ecx+0x18]; ret`, a plain getter),
so this is CTrigger's own slot and not something inherited from CPersistent.

### What that buys

`project.json` now carries a `CTrigger` structure and the four slot names, so
`ApplyBiceLibFindings` lays out a `CTrigger_vftable` and puts a typed `vftable` pointer on
the class. **A call through any `CTrigger*` in Ghidra now reads as
`trigger->vftable->Evaluate(scope)`** instead of `(**(code **)(*param_1 + 0x18))()`, which
is the thing that makes the script machinery readable.

A record on the base names that slot in **every table below it**, so this reaches all 163
triggers - but only classes the findings already describe get a table laid out at all.
`CTrigger` has one now because it has a structure; the individual triggers do not, and
giving `CAlwaysTrigger` its own table would mean a structure or a vftable label for it
too.

**CTrigger is `0x40` bytes.** Not from an allocation size - from its heirs: 129 of the 163
read `this+0x40` inside their own `Evaluate`, and that is where their own value sits
(`CAlwaysTrigger`'s bool, `CTagTrigger`'s tag pair at `0x40` and `0x44`). Its own data
before that is the `CList` of children at `0x8`, which is how `and`, `or` and `not` hold
what they wrap.

## How a requirement tooltip is drawn

`Evaluate` answers whether a condition holds; **slot 9, `GetBlockText`, is what draws the
whole tree** a technology's `allow` or a decision's conditions turn into. It is worth
having in full because BiceLib patches six places in it.

```
Hoi3CString* GetBlockText(Hoi3CString* out, CEventScope* scope, bool redWhen, int depth)
```

**Every line is the same three pieces:**

```
indent(depth) + icon + the child's content
```

The icon is `(§R*§W)` or `(§G*§W)` - a red or a green asterisk - chosen by calling the
child's `Evaluate` and comparing it against **`redWhen`**, the result that counts as
unmet. It is 0 normally, and `CNotTrigger::GetBlockText` is nothing but
`cmp byte [ebp+0x10], 0 / sete dl` and a hand-off to the base: **`not` renders by flipping
the polarity and standing aside**, so everything under it is green when false. That is the
proof of what the third argument is.

**The parent draws the line, icon and all.** A child contributes only its content. The
base walks the children and asks each for its one-line `GetText` (slot 8); a child that is
itself a block answers the empty string there, and the walk falls back to that child's own
slot 9. A trigger with no children answers empty too, which is what makes the fallback
work.

Two special cases that look like bugs and are not:

- **An `and` at depth 0 draws no header** (`0x5D0753`). It hands the call to the base
  renderer instead, which is why a technology's `allow` - an implicit `and` at the top -
  lists its conditions with no `All of the below:` over them.
- **An `or` draws an icon for its own header only at depth 0** (`0x5D0E03`), where
  nothing above it has drawn one.

### What it gets wrong, and what BiceLib does about it

Three sums, each wrong in both containers, and they compound:

| | the game | should be |
| --- | --- | --- |
| a header's own indent | `depth` | **0** - the parent already indented the line |
| the indent before each child's line | `depth` | **`depth + 1`** - children sit inside |
| the depth given to a child block | `0` from `and`, `1` from `or` | **`depth + 1`** |

The first is why the text of a nested block sat right of its own icon; the second is why a
plain condition sat level with the header above it; the third is why nothing got deeper
than one level however far it was nested. `Hooks::EffectText::TriggerIndent` fixes all
six - two one-byte changes turning a header's indent loop `jle` into a `jmp`, and four
five-byte stubs.

**The header fix has to be the jump, not the count.** The register holding the depth is
read twice: as the loop's counter, and again afterwards as the `or`'s "am I the top?"
test. Zeroing it satisfied the first and broke the second, and every nested `or` came out
with two asterisks.

### The string helpers it is built on

Shared across the whole executable, and the first two are easy to confuse:

| rva | what | sites |
| --- | --- | --- |
| `0x33B40` | `appendChars(const char*, length)` | 358 |
| `0x33E30` | `appendString(const string&, from, count)` | 1072 |
| `0x1BD0` | **`assignString`**(const string&, from, count) - replaces | 5489 |
| `0xA160` | `assign(const char*, length)` | 14075 |

`appendString` and `assignString` take the same three arguments and open with the same
bounds check on `from` against the source's length, so only what they do with the result
tells them apart. The names are BiceLib's: these are overloads the game keeps no names
for.

## The triggers

| keyword | token | class |
| --- | --- | --- |
| `active_mission` | 1628 | `CActiveMissionTrigger` |
| `ai` | 1516 | `CIsAiTrigger` |
| `air_battles_fought` | 1900 | `CAirBattlesFoughtTrigger` |
| `alliance_with` | 1522 | `CAllianceWithTrigger` |
| `always` | 1698 | `CAlwaysTrigger` |
| `and` | 806 | `CAndTrigger` |
| `any_core` | 1709 | `CAnyCoreTrigger` |
| `any_neighbor_country` | 884 | `CAnyNeighborCountryTrigger` |
| `any_neighbor_province` | 883 | `CAnyNeighborProvinceTrigger` |
| `any_owned_province` | 1631 | `CAnyOwnedProvinceTrigger` |
| `base_neutrality` | 1976 | `CBaseNeutralityTrigger` |
| `blockade` | 741 | `CBlockadeTrigger` |
| `brigade_exist` | 1919 | `CBrigadeExistsTrigger` |
| `brigade_in_combat` | 1912 | `CBrigadeInCombatTrigger` |
| `can_create_vassals` | 1518 | `CCanCreateVassalsTrigger` |
| `capital` | 505 | `CCapitalTrigger` |
| `casus_belli` | 677 | `CCasusBelliTrigger` |
| `check_variable` | 1038 | `CVariableTrigger` |
| `continent` | 779 | `CContinentTrigger` |
| `controlled_by` | 1556 | `CControlledByTrigger` |
| `controls` | 821 | `CControlsTrigger` |
| `country_units_in_province` | 1278 | `CCountryUnitsInProvinceTrigger` |
| `crude_oil` | 1131 | `CCrudeOilTrigger` |
| `date` | 504 | `CDateTrigger` |
| `dissent` | 1726 | `CDissentTrigger` |
| `empty` | 1047 | `CEmptyTrigger` |
| `enemy` | 2066 | `CEnemyScopeTrigger` |
| `enemy_ic_ratio` | 2087 | `CEnemyIcRatioTrigger` |
| `energy` | 1134 | `CEnergyTrigger` |
| `exists` | 858 | `CExistsTrigger` |
| `faction` | 1723 | `CFactionTrigger` |
| `faction_progress` | 1452 | `CFactionProgressTrigger` |
| `frontage_full` | 2068 | `CFrontageFullTrigger` |
| `government` | 534 | `CGovernmentTrigger` |
| `government_in_exile` | 1411 | `CIsGovernmentInExileTrigger` |
| `guarantee` | 661 | `CGuaranteeTrigger` |
| `has_armour_unit` | 2090 | `CCombatHasArmourUnitTrigger` |
| `has_building` | 950 | `CHasBuildingTrigger` |
| `has_cb` | 2117 | `CHasCasusBelliTrigger` |
| `has_combat_modifier` | 2081 | `CCombatModifierTrigger` |
| `has_combined_arms` | 2104 | `CHasCombinedArmsBonus` |
| `has_country_flag` | 892 | `CHasCountryFlagTrigger` |
| `has_country_modifier` | 1003 | `CHasCountryModifierTrigger` |
| `has_empty_adjacent_province` | 1513 | `CHasEmptyAdjacentProvinceTrigger` |
| `has_global_flag` | 1703 | `CHasGlobalFlagTrigger` |
| `has_hostile_spy_mission` | 2030 | `CHasHostileSpyMissionTrigger` |
| `has_leader` | 1515 | `CHasLeaderTrigger` |
| `has_province_flag` | 941 | `CHasProvinceFlagTrigger` |
| `has_province_modifier` | 1002 | `CHasProvinceModifierTrigger` |
| `has_removable_minister` | 1986 | `CHasRemovableMinisterTrigger` |
| `has_strategic_resource` | 1478 | `CHasStrategicResourceTrigger` |
| `has_wargoal` | 1969 | `CHasWarGoalTrigger` |
| `ideology` | 1080 | `CIsIdeologyEqualTrigger` |
| `ideology_group` | 1467 | `CIdeologyGroupTrigger` |
| `is_attacker` | 1197 | `CIsAttackerTrigger` |
| `is_blockaded` | 1058 | `CIsBlockadedTrigger` |
| `is_capital` | 1700 | `CIsCapitalTrigger` |
| `is_convoy` | 2082 | `CCombatIsConvoyTrigger` |
| `is_core` | 822 | `CIsCoreTrigger` |
| `is_in_any_faction` | 1435 | `CIsInAnyFactionTrigger` |
| `is_mission_country` | 1050 | `CIsMissionCountryTrigger` |
| `is_mission_province` | 1051 | `CIsMissionProvinceTrigger` |
| `is_possible_vassal` | 1519 | `CIsPossibleVassalTrigger` |
| `is_subject` | 1052 | `CIsSubjectTrigger` |
| `is_threatend` | 1277 | `CIsThreatendTrigger` |
| `is_winner` | 2083 | `CCombatIsWinnerTrigger` |
| `land_battles_fought` | 1899 | `CLandBattlesFoughtTrigger` |
| `last_air_battle_loser_losses` | 1864 | `CLastAirBattleLoserLossesTrigger` |
| `last_air_battle_winner_losses` | 1863 | `CLastAirBattleWinnerLossesTrigger` |
| `last_battle_loser_losses` | 1862 | `CLastBattleLoserLossesTrigger` |
| `last_battle_winner_losses` | 1861 | `CLastBattleWinnerLossesTrigger` |
| `last_mission` | 1704 | `CLastMissionTrigger` |
| `last_naval_battle_loser_losses` | 1866 | `CLastNavalBattleLoserLossesTrigger` |
| `last_naval_battle_winner_losses` | 1865 | `CLastNavalBattleWinnerLossesTrigger` |
| `leadership` | 1179 | `CLeadershipTrigger` |
| `lost_IC` | 1232 | `CLostICTrigger` |
| `lost_national` | 1231 | `CNationalProvinceTigger` |
| `manpower` | 490 | `CManpowerTrigger` |
| `manpower_percentage` | 815 | `CManpowerPercentTrigger` |
| `max_manpower` | 814 | `CMaxManpowerTrigger` |
| `max_manpower_greater_than` | 1505 | `CMaxManpowerGreaterThanTrigger` |
| `metal` | 1133 | `CMetalTrigger` |
| `military_access` | 752 | `CGrantsMilitaryAccessTrigger` |
| `minister_alive` | 1228 | `CIsMinisterAliveTrigger` |
| `money` | 1130 | `CMoneyTrigger` |
| `month` | 120 | `CMonthTrigger` |
| `national_unity` | 1727 | `CNationalUnityTrigger` |
| `nationalism` | 1605 | `CNationalismTrigger` |
| `naval_battles_fought` | 1901 | `CNavalBattlesFoughtTrigger` |
| `neighbour` | 972 | `CNeighbourTrigger` |
| `neutrality` | 1732 | `CNeutralityTrigger` |
| `non_aggression_pact` | 1318 | `CNonAgggressionPactTrigger` |
| `not` | 808 | `CNotTrigger` |
| `num_in_faction` | 1434 | `CNumInFactionTrigger` |
| `num_of_allies` | 832 | `CNumOfAlliesTrigger` |
| `num_of_cities` | 826 | `CNumOfCitiesTrigger` |
| `num_of_convoys` | 1453 | `CNumOfConvoysTrigger` |
| `num_of_ports` | 827 | `CNumOfPortsTrigger` |
| `num_of_revolts` | 824 | `CNumOfRevoltsTrigger` |
| `num_of_vassals` | 834 | `CNumOfVassalsTrigger` |
| `or` | 807 | `COrTrigger` |
| `organisation` | 1224 | `CRulingOrganisationTrigger` |
| `out_of_supply_days` | 1867 | `COutOfSupplyDaysTrigger` |
| `owned_by` | 937 | `COwnedByTrigger` |
| `owns` | 820 | `COwnsTrigger` |
| `popularity` | 1275 | `CRulingPopularityTrigger` |
| `province_id` | 1520 | `CProvinceIdTrigger` |
| `province_temperature` | 2080 | `CCombatTemperatureTrigger` |
| `pure_revolt_risk` | 1033 | `CPureRevoltRiskTrigger` |
| `rare_materials` | 1135 | `CRareMaterialsTrigger` |
| `region` | 1044 | `CRegionTrigger` |
| `relation` | 885 | `CRelationTrigger` |
| `remove_fow` | 1699 | `CFoWRemovedTrigger` |
| `reserves` | 920 | `CReservesTrigger` |
| `revolt_percentage` | 825 | `CNumOfRevoltsFractionTrigger` |
| `revolt_risk` | 519 | `CRevoltRiskTrigger` |
| `skill` | 655 | `CSkillTrigger` |
| `skill_advantage` | 2065 | `CSkillAdvantageTrigger` |
| `spies` | 626 | `CSpyCountTrigger` |
| `spy_mission_count` | 2028 | `CSpyMissionCountTrigger` |
| `strat_allies_impact` | 1458 | `CStratAlliesImpactTrigger` |
| `strat_bomb_impact` | 1459 | `CStatBombImpactTrigger` |
| `strat_convoy_impact` | 1457 | `CStratConvoyImpactTrigger` |
| `strategic_resource` | 1477 | `CStrategicResourceTrigger` |
| `supplies` | 1129 | `CSuppliesTrigger` |
| `surrender_progress` | 1988 | `CSurrenderProgressTrigger` |
| `tag` | 955 | `CTagTrigger` |
| `terrain` | 523 | `CCombatTerrainTrigger` |
| `threat` | 1652 | `CThreatTrigger` |
| `total_amount_of_brigades` | 1898 | `CAmountOfBrigadesTrigger` |
| `total_amount_of_divisions` | 1227 | `CAmountOfDivisionsTrigger` |
| `total_amount_of_planes` | 1451 | `CTotalAmountOfPlanesTrigger` |
| `total_amount_of_ships` | 1450 | `CTotalAmountOfShipsTrigger` |
| `total_defensives` | 1463 | `CTotalDefensivesTrigger` |
| `total_ic` | 1456 | `CTotalICTrigger` |
| `total_num_of_ports` | 1676 | `CTotalNumOfPortsTrigger` |
| `total_of_ours_sunk` | 1455 | `CTotalOfOursSunkTrigger` |
| `total_offensives` | 1461 | `CTotalOffensivesTrigger` |
| `total_sea_battles` | 1460 | `CTotalSeaBattlesTrigger` |
| `total_sunk_by_us` | 1454 | `CTotalSunkByUsTrigger` |
| `total_we_bomb` | 1462 | `CTotalWeBombTrigger` |
| `trait` | 2067 | `CTraitTrigger` |
| `truce_with` | 1575 | `CTruceWithTrigger` |
| `undeclared_war_with` | 1978 | `CUndeclaredWarWithTrigger` |
| `unit_has_leader` | 1013 | `CUnitHasLeaderTrigger` |
| `unit_in_battle` | 1010 | `CUnitInBattleTrigger` |
| `units_in_province` | 1007 | `CUnitsInProvinceTrigger` |
| `vassal_of` | 1521 | `CVassalOfTrigger` |
| `war` | 845 | `CAtWarTrigger` |
| `war_exhaustion` | 775 | `CWarexhaustionTrigger` |
| `war_with` | 1009 | `CWarWithTrigger` |
| `year` | 119 | `CYearTrigger` |

## The effects

| keyword | token | class |
| --- | --- | --- |
| `add_ai_strategy` | 1713 | `CAddAIStrategyEffect` |
| `add_casus_belli` | 964 | `CReversedCasusBelliEffect` |
| `add_core` | 514 | `CAddCoreEffect` |
| `add_country_modifier` | 865 | `CAddCountryModifierEffect` |
| `add_division` | 1920 | `CAddDivisionEffect` |
| `add_province_modifier` | 864 | `CAddProvinceModifierEffect` |
| `add_wargoal` | 1977 | `CWarGoal` |
| `any_controlled` | 2122 | `CAnyControlledEffect` |
| `any_country` | 968 | `CAnyCountryEffect` |
| `any_nearby_province` | 2039 | `CAnyNearbyProvinceEffect` |
| `any_neighbor_country` | 884 | `CAnyNeighborCountryEffect` |
| `any_neighbor_province` | 883 | `CAnyNeighborProvinceEffect` |
| `any_owned` | 1568 | `CAnyOwnedEffect` |
| `capital` | 505 | `CCapitalEffect` |
| `casus_belli` | 677 | `CCasusBelliEffect` |
| `change_controller` | 1016 | `CChangeControllerEffect` |
| `change_manpower` | 953 | `CChangeManpowerEffect` |
| `change_province_name` | 1553 | `CRenameProvinceEffect` |
| `change_variable` | 1040 | `CChangeVariableEffect` |
| `clr_country_flag` | 894 | `CClrCountryFlagEffect` |
| `clr_global_flag` | 1702 | `CClrGlobalFlagEffect` |
| `clr_province_flag` | 940 | `CClrProvinceFlagEffect` |
| `country_event` | 881 | `CCountryEventEffect` |
| `coup_by` | 1992 | `CCoupEffect` |
| `create_alliance` | 1529 | `CCreateAllianceEffect` |
| `create_revolt` | 947 | `CCreateRevoltEffect` |
| `create_vassal` | 1319 | `CCreateVassalEffect` |
| `crude_oil` | 1131 | `COilPoolEffect` |
| `dissent` | 1726 | `CDissentEffect` |
| `do_election` | 1971 | `CElectionEffect` |
| `end_guarantee` | 1322 | `CEndGuaranteeEffect` |
| `end_military_access` | 1323 | `CRevokeMilitaryAccessEffect` |
| `end_non_aggression_pact` | 1325 | `CEndNonAggressionEffect` |
| `end_war` | 1320 | `CEndWarEffect` |
| `energy` | 1134 | `CEnergyPoolEffect` |
| `fixed_ai_strategy` | 1714 | `CFixedAIStrategyEffect` |
| `form_government_in_exile` | 1410 | `CFormGovernmentInExileAction` |
| `fuel` | 1132 | `CFuelPoolEffect` |
| `government` | 534 | `CGovernmentEffect` |
| `guarantee` | 661 | `CGuaranteeEffect` |
| `inherit` | 961 | `CInheritEffect` |
| `join_faction` | 1721 | `CJoinFactionEffect` |
| `kill_leader` | 1532 | `CKillLeaderEffect` |
| `leadership` | 1179 | `CLeadershipEffect` |
| `leave_alliance` | 1321 | `CLeaveAllianceEffect` |
| `leave_faction` | 1722 | `CLeaveFactionEffect` |
| `load_oob` | 1476 | `CLoadOOBEffect` |
| `local_intel_boost` | 2119 | `CLocalIntelBoost` |
| `manpower` | 490 | `CManpowerEffect` |
| `metal` | 1133 | `CMetalPoolEffect` |
| `military_access` | 752 | `CGrantMilitaryAccessEffect` |
| `modify_spies` | 2031 | `CModifySpiesEffect` |
| `money` | 1130 | `CMoneyPoolEffect` |
| `national_unity` | 1727 | `CNationalUnityEffect` |
| `neutrality` | 1732 | `CNeutralityEffect` |
| `non_aggression_pact` | 1318 | `CStartNonAggressionEffect` |
| `officer_pool` | 1903 | `COfficerPoolEffect` |
| `organisation` | 1224 | `COrganisationEffect` |
| `popularity` | 1275 | `CPopularityEffect` |
| `practical` | 1883 | `CPracticalEffect` |
| `province_event` | 882 | `CProvinceEventEffect` |
| `random` | 1558 | `CRandomEffect` |
| `random_country` | 969 | `CRandomCountryEffect` |
| `random_empty_neighbor_province` | 1547 | `CRandomEmptyNeighborProvinceEffect` |
| `random_list` | 1042 | `CRandomListEffect` |
| `random_neighbor_province` | 971 | `CRandomNeighborProvinceEffect` |
| `random_owned` | 970 | `CRandomOwnedEffect` |
| `rare_materials` | 1135 | `CRareMaterialsPoolEffect` |
| `relation` | 885 | `CRelationEffect` |
| `release` | 962 | `CReleaseEffect` |
| `release_vassal` | 1546 | `CReleaseVassalEffect` |
| `remove_brigade` | 1911 | `CRemoveBrigadeEffect` |
| `remove_core` | 515 | `CRemCoreEffect` |
| `remove_country_modifier` | 1534 | `CRemoveCountryModifierEffect` |
| `remove_fow` | 1699 | `CRemoveFoWEffect` |
| `remove_minister` | 1324 | `CRemoveMinisterEffect` |
| `remove_province_modifier` | 1533 | `CRemoveProvinceModifierEffect` |
| `revolt_risk` | 519 | `CRevoltRiskEffect` |
| `secede_province` | 960 | `CSecedeProvinceEffect` |
| `set_country_flag` | 893 | `CSetCountryFlagEffect` |
| `set_global_flag` | 1701 | `CSetGlobalFlagEffect` |
| `set_province_flag` | 939 | `CSetProvinceFlagEffect` |
| `set_variable` | 1039 | `CSetVariableEffect` |
| `split_troops` | 1464 | `CSplitTroopsEffect` |
| `strategic_resource` | 1477 | `CStrategicResourceEffect` |
| `supplies` | 1129 | `CSuppliesPoolEffect` |
| `surrender_inherit` | 1891 | `CSurrenderInheritEffect` |
| `threat` | 1652 | `CThreatEffect` |
| `undeclared_war` | 1972 | `CUndeclaredWarRegionEffect` |
| `war` | 845 | `CWarEffect` |
| `war_exhaustion` | 775 | `CWarexhaustionEffect` |
