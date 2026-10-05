# What a diplomatic offer is while it is in flight

`findings/FINDINGS-diplomacy.md` read the engine's side of `ai_diplomacy.lua` and
`findings/FINDINGS-trade2.md` named three of the family's virtual slots off luabind. Neither read
the **action object**. This is that object: its layout field by field, its three-valued `type`,
the units of `value`, the whole lifecycle from a Lua call to the entry sitting in a save, and what
the null action is for.

Read out of the executable on 2026-10-03, cross-checked against the 45 savegames on this machine.
Nothing here needed the game running. Addresses are **virtual**, based `0x400000`, with the rva
beside anything a finding names.

## In one line

`type` is not the kind of agreement - the kind is the C++ subclass and its name is slot 15's save
token - it is the **stage**, and the enum has **three** values (the record says two): PROPOSE 0,
DECLINE 1, **ACCEPT 2**; `value` is a plain bool written `yes`/`no` in the save and **not**
thousandths; the object is exactly `0x28` bytes with every field written in order by one
constructor; the lifecycle is Lua `Create` -> slot 6 `MakeCommand` -> the session channel ->
`CDiplomaticActionCommand::Execute` -> a clone queued on a country's pending list -> the hourly AI
pass flips it to ACCEPT and posts it back; `CCountry +0xF24` is **not** `declarewar` but the
country's **pending diplomatic actions, of any kind**, and `declarewar` is simply the one case in
`CCountry::LoadKey` the compiler emitted a literal for while eighteen other tokens `jmp` into it;
and the null action is a **static singleton at `0x01B15C60`** whose `IsValid()` is `xor al,al; ret`,
used by `CDiplomaticActionCommand::LoadKey` as literally "am I still empty".

---

## 1. The layout, read off one constructor

`CNullDiplomaticAction::CNullDiplomaticAction` (`0x00A0EAF0`, rva `0x60EAF0`, `__stdcall`, `ret 4`,
the object on the stack) writes **every** base field in order, which makes it the cheapest complete
statement of the layout there is:

| offset | field | type | the null's value |
| --- | --- | --- | --- |
| `+0x00` | vftable | | `0x15FB274` |
| `+0x04` | `persistent_id` | `int` | `0x18D` |
| `+0x08` | `actor` | `CCountryTag` | tag `"---"` (`0x2D2D2D`), id 0 |
| `+0x10` | `recipient` | `CCountryTag` | tag `"---"`, id 0 |
| `+0x18` | `type` | `int` | 0, PROPOSE |
| `+0x1C` | `date` | `int` (hours) | `[0x170C2B8]`, the 43,800,000-hour epoch used as a null date |
| `+0x20` | `last_command_date` | `int` (hours) | the same null date |
| `+0x24` | `value` | `uint8_t` | 1 |

`sizeof(CDiplomaticAction) == 0x28`: `CNapAction`'s clone (`0x00A2E360`) asks `operator new` for
`0x28` and copies exactly `+0x8` through `+0x24` plus the vftable, and `CNapAction` adds no fields
of its own. `CNullDiplomaticAction` is `0x44`, because it adds a `Hoi3CString` at `+0x28`, and
`CTradeAction` is `0xB0`.

Two things to notice. **`+0x4` is not a per-class discriminator** - `CCommand +0x4` is recorded as
"a class id" and holds the same `0x18D` - so what the engine does with it is unsettled; token
`0x18D` resolves to `none`. And **`CCountryTag` is 8 bytes**, `char tag[4]` then `int id`, which is
why the actor appears in the code sometimes as `+0x8` (the tag, by address) and sometimes as `+0xC`
(the id, as an index into `g_CCountryDataBase::countries_first`).

`CDiplomaticAction::LoadKey` (`0x00A0E690`, already in the record) confirms the same six fields from
the other end, one save key each: `type` 0xD9 -> `+0x18` through **`sscanf`**, `date` 0x1F8 ->
`+0x1C` and `last_command_date` 0x3EC -> `+0x20` through `Date_SetFromString`, `value` 0x2A6 ->
`+0x24` through **`ParseBool`**, `actor` 0x2E9 -> `+0x8`/`+0xC` and `recipient` 0x2EA ->
`+0x10`/`+0x14` through `CCountryDataBase::GetTag`.

## 2. `type` has three values, and it is a stage not a kind

**The record says two and that is wrong.** `findings/FINDINGS-trade2.md` and `project.json` both say
"the enum's own two values are registered beside it at `0x8ED397` from the stack pairs ('PROPOSE', 0)
and ('DECLINE', 1)". There is a third, eight instructions later:

    0x8ED37F  mov [ebp-0x24], 0x15CAF74   'DECLINE'
    0x8ED386  mov [ebp-0x20], 1
    0x8ED38D  mov [ebp-0x2C], 0x15EEB94   'PROPOSE'
    0x8ED394  mov [ebp-0x28], ebx                     ; ebx is 0
    0x8ED397  call 0x8E8070                           ; luabind operator, -> a value vector
    ...
    0x8ED3BB  mov [ebp-0x24], 0x15CAF6C   'ACCEPT'
    0x8ED3C2  mov [ebp-0x20], 2
    0x8ED3C9  call 0x883B30                           ; append to the same vector
    0x8ED3CE  ...loop over [esi+4]..[esi+8] in 8-byte steps, 0xB810E0 per element

`ebx` is zero: `xor ebx, ebx` at `0x8EAE68` is the only write to it between the enclosing
function's entry (`0x8EADD0`) and `0x8ED3D0`. The block is `CDiplomaticAction`'s because the
registration immediately after it (`0x8ED3EF`-`0x8ED426`) is the
`IsValid`/`IsSelectable`/`GetValue`/`SetValue`/`GetType`/`GetAIAcceptance` chain
`findings/FINDINGS-trade2.md` already attributes to `CDiplomaticAction`, and the type descriptor
spells `CDiplomaticAction::W4EType`.

**So 0 = PROPOSE, 1 = DECLINE, 2 = ACCEPT.** The savegame is the independent check: across the 45
saves here there are 56 pending action blocks, and `type` is **0 thirty times, 1 five times and 2
twenty-one times**. A two-valued enum cannot be right.

**And this is why the brief's framing had to be set aside.** The kind of agreement is not in
`type`; it is the **subclass**, and the subclass's own name is what slot 15 returns.

## 3. The kinds: slot 15 is `GetToken`

Every concrete class's slot 15 is two instructions, `mov eax, <token>; ret`, and the token is the
class's **save key**. Twenty-one of the twenty-four give one; the base and `CWarGoalBaseAction`
leave the slot pure, and `CNullDiplomaticAction` answers `ReturnZero`:

| class | token | key |
| --- | --- | --- |
| `CDeclareWarAction` | 757 | `declarewar` |
| `CAllianceAction` | 759 | `allianceaction` |
| `CGuaranteeAction` | 764 | `guaranteeaction` |
| `CMilitaryAccessAction` | 766 | `milaccess` |
| `COfferMilitaryAccessAction` | 767 | `offermilaccess` |
| `CCallAllyAction` | 777 | `callaction` |
| `CInfluenceNation` | 1185 | `influence` |
| `CNapAction` | 1741 | `nap` |
| `CInfluenceAllianceLeader` | 1744 | `influence_leaders` |
| `CEmbargoAction` | 1747 | `embargo_action` |
| `CFactionAction` | 1748 | `faction_action` |
| `CTradeAction` | 1754 | `trade_action` |
| `CSendExpeditionaryForceAction` | 1818 | `send_expedition` |
| `CLicenceTechnologyAction` | 1820 | `licence_technology` |
| `CDebtAction` | 1830 | `debtaction_action` |
| `CPeaceAction` | 1833 | `peace_action` |
| `CShareTechnologyAction` | 1885 | `share_technology` |
| `CAddWarGoalAction` | 1956 | `add_war_goal` |
| `CJoinFactionGoalAction` | 1983 | `join_with_war_goal` |
| `CRequestLendLeaseAction` | 2052 | `request_lendlease` |
| `COfferLendLeaseAction` | 2116 | `offer_lendlease` |

The family is **exactly 24 classes**, walked transitively from the RTTI export, which agrees with
`findings/FINDINGS-trade2.md`. Two names that look like members and are not:
**`CFormGovernmentInExileAction` is a `CEffect`**, not a diplomatic action (15 live in the census,
and the name invites the mistake), and `CDiplomaticActionItem` is a GUI listbox item.

## 4. `value` is a bool. It is not thousandths

Trap 7's question, answered two ways. The loader case for `value` (token 0x2A6) at `0xA0E6DF` calls
**`ParseBool`** (rva `0x67B410`) - four instructions away the `type` case calls `sscanf` instead,
and that contrast is what settles it. And the save writes it `value=yes` / `value=no`: 39 yes and 6
no across the corpus. The existing reading in `project.json` - the propose/cancel polarity that
`CTradeAction::IsValid` branches on at `0xA387DA` - is right, and now has its units stated.

Seven of the family also use the byte as their slot-18 answer, through the folded
`cmp byte ptr [ecx+0x24], 0; setne al; ret` at `0x00A0FE10` (4 tables) and the recorded
`ReturnByteAt24` at `0x00A0E990`.

## 5. The lifecycle, step by step

### Create

**From Lua.** A run of eleven `__cdecl` free functions at `0x008E83F0`, `0x8E8510`, `0x8E8630`,
`0x8E8770`, `0x8E8890`, `0x8E89B0`, `0x8E8AD0`, `0x8E8BF0`, `0x8E8D10`, `0x8E8E30` and `0x8E8F50`
(rvas `0x4E83F0` and so on). Each takes two `CCountryTag`s **by value**, allocates its class's
size, and sets `actor`, `recipient`, `type = 0`, `value = 1` and **both** dates to
`g_CCurrentGameState->tick` (`+0xBDC`). None has a caller in the engine: `findRefs --address`
finds one reference each, a luabind registration whose name pointer is `0x15EEBD8` = **`'Create'`**.
So a mod writes `CTradeAction.Create(actorTag, recipientTag)`. `CCallAllyAction::Create` is the only
one of the eleven that takes a **third** tag, into `+0x28`/`+0x2C`.

**From the save.** `CDiplomaticAction::Create` (`0x004E5800`, rva `0xE5800`, `__cdecl`) is the
family factory: a switch with **19 cases keyed on the save token**, each allocating its class, and
returning the **null singleton** `0x01B15C60` for an unknown token (`0x4E6002`).

### Gate

`IsValid()` is slot 13 and `GetAIAcceptance()` is slot 17, both named by the game through luabind
(`findings/FINDINGS-trade2.md`), both registered to Lua. The base's slot 14 `IsSelectable`
(`0x00A0EAE0`) is three instructions: `return actor_id != recipient_id`.

### Offer

**`CDiplomaticAction::MakeCommand`, slot 6, `0x00A0E890` / rva `0x60E890`** - the base's own body in
all 24 tables. `__thiscall`, bare `ret`, no arguments. It stamps `this->last_command_date` with the
current tick (`0xA0E92D`), asks for `0x40` bytes - `sizeof(CDiplomaticActionCommand)` - clones
itself through slot 16 (`0xA0E94F`) and hands the clone to `CDiplomaticActionCommand`'s
two-argument constructor (`0x00A0E090`), returning the command. It does not post it; its caller
does, onto the session's channel (`country->+0xF1C` slot 18 -> session `+0x38` slot 6, the post
`findings/FINDINGS-commands.md` reads).

A default-constructed command (`0x00A0DF70`) instead stores `+0x3C = 0x01B15C60`, the null
singleton.

### Execute

**`CDiplomaticActionCommand::Execute`, slot 6, `0x00A0E120` / rva `0x60E120`.** `__thiscall`, bare
`ret`, no arguments. With `a = this->+0x3C`:

1. `0xA0E135`: `a->IsValid()` (slot 13). **False and nothing at all happens** - this is how the
   null action makes an empty command a no-op.
2. `0xA0E142`: if `a->type == 0` (PROPOSE) **and** `a->GetToken()` (slot 15) is not `0x309`
   `callaction`, set the pair's `CDiplomacyStatus +0x50` to `a->date + 0xA8` - 168 hours, exactly
   seven days - through `0x00A4A550`. The status is `countries[a->actor_id]->+0xE28[a->recipient_id]`.
3. `0xA0E19E`: `a->slot 7` - the **per-class effect**, the agreement actually happening. Slot 7 is
   `_purecall` in the base and overridden with a real body by every concrete class.
4. `0xA0E1CA` / `0xA0E1F3`: clone the action (slot 16) and enqueue the clone on a country through
   `CCountry::AddPendingDiplomaticAction` - the **recipient** when `type` is PROPOSE, the **actor**
   otherwise.
5. For a reply only (`type != 0`): `CCountry::RebuildNeighbours` (`0x004E21E0`) and `0x004E39C0` on
   **both** countries.

**Step 4 is confirmed by the savegame, 56 times out of 56.** Scanning all 45 saves and resolving
each pending block's enclosing country: every one of the 30 blocks with `type=0` sits in the
**recipient's** country block, and every one of the 26 with `type=1` or `type=2` sits in the
**actor's**. A proposal goes out; a reply comes back.

### Pending

`CCountry::AddPendingDiplomaticAction` (`0x004E61C0`, rva `0xE61C0`, receiver in **EDI**, `ret 4`)
stamps `action->last_command_date` with the tick and appends a `0x10`-byte node (`+0x0` the action,
`+0x4` previous, `+0x8` next, `+0xC` a byte) to the list at `+0xF24`/`+0xF28`/`+0xF2C`. **Two gates
first:** a country with no `CEU3AI` (`+0x1D8 == 0`) only gets the action if it **is** the player
(`gameState->player +0xC34 == country->id +0xCA8`); otherwise the clone is dropped on the floor and
leaked, since nothing frees it.

### Reply

`RunHourlyPass`'s per-country loop at `0x00682B37` is the AI's answer. For every country whose entry
in `played_countries_array` (`+0xBCC`) is zero - i.e. **every AI country** - it walks `+0xF24` and
for each action:

    if (action->slot18() && action->type == 0) {
        action->type = 2;                  // ACCEPT, written at 0x682BB3
        cmd = action->MakeCommand();        // slot 6
        country->+0xF1C slot18 -> session; session->+0x38 slot6(cmd);   // post it
    }
    ...then CCountry::ClearPendingDiplomaticActions(country)            // 0x682BE5

So an offer an AI does not act on in the hour it arrives is **discarded**, not carried over.

**Slot 18 is the predicate that decides, and its split is striking.** Eight classes answer
`ReturnFalse` (`0x00592360`): `CAddWarGoalAction`, `CDeclareWarAction`, `CEmbargoAction`,
`CGuaranteeAction`, `CInfluenceAllianceLeader`, `CInfluenceNation`, `CShareTechnologyAction`,
`CNullDiplomaticAction`. Four answer `ReturnTrue`: `CFactionAction`, `CJoinFactionGoalAction`,
`CLicenceTechnologyAction`, `CPeaceAction`. Seven answer `value != 0`. `CCallAllyAction` answers
`type == 0`, and the two military-access classes share `0x00A278C0`.

**Those eight `ReturnFalse` classes are exactly the eight whose `GetAIAcceptance` is a compiled-in
constant** - the six at `ReturnZero` and the two at `ReturnOneHundred` from
`findings/FINDINGS-survivors.md`. Slot 18 is non-trivial precisely where slot 17 really asks the
mod's Lua. That is a clean structural fact; what it *means* is below, under what is not established.

### Destroy

`CDiplomaticActionCommand::~CDiplomaticActionCommand` (slot 0, `0x00A0E000`, rva `0x60E000`,
`ret 4`) deletes the held action **unless it is the singleton**:

    0xA0E02F  cmp ecx, 0x1B15C60
    0xA0E035  je  <skip>
    0xA0E037  test ecx, ecx / je <skip>
    0xA0E03B  action->slot0(1)

`CCountry::ClearPendingDiplomaticActions` (`0x004E63A0`, rva `0xE63A0`, receiver in EDI, bare `ret`)
deletes every action in the list, frees every node, and zeroes the head, tail and count.

## 6. `CCountry +0xF24` is not `declarewar`

The record calls `+0xF24`/`+0xF28`/`+0xF2C` `declarewar` / `declarewar_end` / `declarewar_count`,
in `project.json`, in `BiceLib/GameClasses/CCountry.hpp:342-344` and in `CLASSES.md:1559`, "named
from the key `CCountry::LoadKey` reads it from". The key is real. It is also **CDeclareWarAction's
own class token** (757 = `0x2F5`), and it is one of **nineteen** action tokens
`CCountry::LoadKey` accepts into the **same list**.

`switchmap.cases(0x4CCDA0)` gives token -> case body, and the nineteen reach exactly three bodies
that converge on one append:

| body | tokens | what it does |
| --- | --- | --- |
| `0x004CD393` | `declarewar` alone | `push 0x2F5; call CDiplomaticAction::Create; <slot 3 Load>; <append>` |
| `0x004CD5FB` | **sixteen** - allianceaction, guaranteeaction, milaccess, offermilaccess, callaction, nap, influence_leaders, embargo_action, faction_action, trade_action, send_expedition, licence_technology, debtaction_action, peace_action, share_technology, offer_lendlease | `push eax; jmp 0x4CD398` - two instructions, jumping into declarewar's own factory call |
| `0x004CDAE1` | `influence`, `request_lendlease` | `push eax; call Create; ...; jmp 0x4CD3AB` - its own call, the same append tail |

So `declarewar` is the name of **the one case the compiler emitted a literal for**, and the other
eighteen `jmp` into it. Exactly trap 16: a name fitted to a key that was never the only one.

Three further readings agree that the list is polymorphic:

- The append code in `CCountry::LoadKey` (`0x4CD3C3`-`0x4CD40A`) is **byte-identical** to the one in
  `CCountry::AddPendingDiplomaticAction` (`0x4E6302`-`0x4E6342`), which appends whatever slot 16
  handed it.
- **`CCountry::HasPendingTradeProposal`** (`0x004E6360`, rva `0xE6360`, `__thiscall`, bare `ret`)
  walks `+0xF24` and returns true for the first entry whose slot-15 token is `0x6DA`
  `trade_action` and whose `type` is 0. A reader of the list that only cares about trade offers.
- The save corpus holds `trade_action`, `licence_technology` and `debtaction_action` blocks as
  **direct country keys**, carrying the base's six fields, never nested under a `declarewar`
  wrapper. `declarewar` itself appears in **none** of the 45 saves - the AI pass empties the list
  every hour, so it is almost always empty when a save is written.

Renamed to `pending_diplomatic_actions`, `_end`, `_count`. Other readers of the list, for the next
wave: `CAIForeignMinister::DoWork` (`0x0089E05A`) and `CCountry::RunHourlyAITrade` (`0x004DC506`).

One real save entry, for the record:

    trade_action={
        type=0  actor="FRA"  recipient="USA"
        date="1938.1.5.2"  value=yes  last_command_date="1938.1.5.2"
        trade={ to="USA" from="FRA" trade_from={...} trade_to={...} }
    }

in **USA's** country block - the recipient, as `Execute` says it should be.

## 7. The null action

`CNullDiplomaticAction` is a **static singleton at `0x01B15C60`** (rva `0x1715C60`), `0x44` bytes of
`.data`, constructed by the CRT initialiser at `0x00D1B3A0` and torn down by the atexit handler at
`0x00D278A0`. The brief asked whether the `CNullOwnerArea` shape holds here. **It does, and more
exactly than that:** slots 13 `IsValid`, 14 `IsSelectable` and 18 all point at `0x00592360`,
`xor al, al; ret`.

And the engine uses it that way *as a test*. `CDiplomaticActionCommand::LoadKey` (`0x00A0E2A0`,
already in the record) is:

    if (!this->action->IsValid())            // slot 13
        this->action = CDiplomaticAction::Create(key);
    if (this->action->GetToken())            // slot 15
        this->action->Load(parse);           // slot 3
    else
        CCommand::LoadKey(parse, key);

`IsValid()` on this family is literally **"this is not the null object"**, and `GetToken() == 0` is
the second null test. Three more places lean on the singleton by identity: the default command
constructor stores it (`0xA0DFE6`), `CDiplomaticAction::Create` returns it for an unrecognised token
(`0x4E6002`), and the command destructor **refuses to delete it** (`0xA0E02F`).

### Why 13,669 of them - and why 22,113 is not an object count

**`CDiplomaticAction` is abstract.** Ten of its 22 slots are `_purecall`, so it cannot have 22,113
live instances, and the census number is therefore not an object count. The mechanism is in the
destructors: `CDiplomaticAction`'s own (`0x00A1BC50`) does `mov [esi], 0x15FB1D4` as it unwinds, and
so does `CNullDiplomaticAction`'s (`0x00A0EB90`) after resetting its string, and so does the static
destructor at `0x00D278A0`. **A destroyed-and-freed action holds the base vftable**, which is
precisely what `scripts/census.py`'s own docstring warns about: "freed memory that has not been
reused still holds the old value".

For the 13,669 nulls, the static side gives a hard ceiling on the sources and nothing more:
`findRefs --vftable CNullDiplomaticAction` finds **exactly one** write of `0x15FB274` in code, inside
the one constructor, and that constructor has **exactly three** callers - the CRT initialiser,
`CNullDiplomaticAction::Clone` (slot 16, `0x00A0DC10`) and `CDiplomaticActionCommand::Clone` (slot
13, `0x00A0E300`, reached for a command whose action pointer is null). Since the destructor writes
the *base* vftable over a null as it dies, every one of those 13,669 is an object whose last vftable
write was the null's constructor - i.e. **constructed and never destroyed**, and the only heap
sources are those two clone paths. The channel calls the command's slot 13 once per command per
channel hop (`findings/FINDINGS-commands.md`, the post and the drain), so a clone per hop is the
shape that would produce them.

**This could not be settled further statically, and it is said rather than rounded up.** What would
settle it: `instances()` on `CNullDiplomaticAction` in a live session with the **spacing
discriminator applied** (trap 15 - a `0x44` object cannot have neighbours `0x10` apart), plus the
`+0x4`/`+0x24` bytes of a sample, which would separate live singleton-plus-clones from stale heap.
The `--scales-with` option on `census.py` against the command count would be the cheap first look.

## 8. `GetAIAcceptance`

Nothing new, and the brief was right that it is the cheapest route into the class's semantics - it
is also already fully recorded, so this section is here only to say what the registration gives.
`findings/FINDINGS-trade2.md` resolved it off the luabind thunk `0x008A3120` = `mov eax,[ecx];
jmp [eax+0x44]`, so **slot 17**, and the registration object's type descriptor spells the signature
for free: `memfun_registration<CDiplomaticAction, int (CDiplomaticAction::*)(), null_type>`, i.e.

    int __thiscall CDiplomaticAction::GetAIAcceptance(CDiplomaticAction* this)

no arguments, `int` out. What it reads, per `findings/FINDINGS-diplomacy.md`: nine classes push their
own `DiploScore_*` literal and call `GetDiploScoreFromLua` (rva `0x60DC70`) with the actor tag by
address, the recipient tag by address and by value; four more reach the same bridge through a
name-specialised luabind clone; six return a hard zero and two a constant 100. The arguments come
from `+0x8` and `+0x10` - the two fields section 1 names - and the score comes straight back in
`eax` with no post-processing.

Its relevance to the lifecycle is that it is **not** called anywhere in the five steps above. The
one place a score is consulted on a path this file read is the `yesmen` short-circuit inside
`GetDiploScoreFromLua`, which fires for the **player's** own country - which only makes sense if
the score is asked on the *proposer's* side, before the command is posted. See below.

## 9. What is not established

- **Where the 13,669 live `CNullDiplomaticAction`s are.** Section 7 gives the ceiling on sources and
  the live measurement that would settle it. The companion figure, 22,113 `CDiplomaticAction`, is
  settled as **not an object count**: the class is abstract and every destructor in the family
  writes the base vftable into the object before it is freed.
- **Whether `GetAIAcceptance` gates the posting rather than the accepting.** Nothing in the five
  lifecycle steps calls slot 17, and the hourly AI pass flips a pending proposal to ACCEPT on slot
  18 alone. Two things point at the score being consulted on the **proposer's** side, before a
  command is ever posted: the `yesmen` short-circuit in `GetDiploScoreFromLua` fires for the player's
  own country, and slot 18 is `ReturnFalse` for exactly the eight classes whose `GetAIAcceptance`
  is a constant. That is a reading of structure, not an instruction, and it is marked as one. The
  cheap way to close it is `slotcalls.py 17` plus the diplomacy GUI's button handlers.
- **`CDiplomacyStatus +0x50` has one writer and no identified reader.** The search was a
  same-register-neighbour scan over every named function, requiring the register to also carry
  `+0x2C`, `+0x38`, `+0x58`, `+0x60` or `+0x68`. It returned 161 functions for `+0x50`,
  overwhelmingly `esp`-relative frame slots, and its positive control fails in the same way - it
  cannot tell a real reader of a known-read field from frame noise. **So its silence is not
  evidence**, which is why the field and its setter are `inferred`. The setter's own comparison
  against `tick + 0xA8` is dead - both arms store the same value - which is consistent with a
  cooldown that was reduced to an unconditional store.
- ~~**Slot 7, the per-class effect**, was not read in any class.~~ **Closed by wave 12 - see
  sections 11-20 below**, which supersede this list. Section 19 restates every item here with what
  changed. Two corrections it makes to this section: `0x00A435F0` is **not** "the war-goal base"
  (`CWarGoalBaseAction` slot 7 is `_purecall`; the body is its two derived classes', folded), and the
  class count is **21 tables holding 20 distinct bodies**, not twenty-four.
- **Slot 18 is unnamed on purpose.** Its shared body `0x00A0FE10` sits in four tables of one family,
  so it would have to be recorded class-free, and one call site is thin evidence for a name. Its
  behaviour is in section 5.
- `0x004E39C0`, the per-country recomputation `Execute` runs on both parties after a reply. `ret 4`
  at `0x4E3EA0`, **65 callers**, opens by rejecting id 0, the tag `REB` and a zero at `+0x44`. Too
  big and too far from this brief; a good standalone item.
- `CDiplomaticActionCommand::Clone` (slot 13, `0x00A0E300`) ends `ret 0x1C` - seven stack dwords,
  so it takes something by value that was not worked out. Left unnamed.
- `CDiplomaticActionCommand` and `CNullDiplomaticAction` have **no `structs` record**, so
  `CDiplomaticActionCommand +0x3C` (the action pointer) and `CNullDiplomaticAction +0x28` (its own
  `Hoi3CString`) are described here and recorded nowhere.

## 10. Frontier

`0xE39C0`, `0x282B14`, `0x60E300`, `0x60E3F0`, `0x60E250`, `0x60E480`, `0x60E9A0`, `0x61BC50`,
`0x60EB90`, `0x60FE10`, `0x62AC70`, `0x6278C0`, `0x6352F0`, `0x62B090`, `0x6435F0`.

---

## Transcription note

Read and written by wave 11's agent D; transcribed by the session that collected the wave, because
an agent's `Write` is refused for this path. Spot-checked independently before transcription, all
confirming:

- **`ACCEPT = 2`**: at VA `0x8ED3BB`, `mov [ebp-0x24], 0x15caf6c` / `mov [ebp-0x20], 2`, eight
  instructions after the DECLINE/PROPOSE pair, and `image.asString` gives the three literals as
  `'DECLINE'`, `'PROPOSE'`, `'ACCEPT'`.
- **The save corpus**, which is the independent half: across the 45 saves, `type=0` appears 30
  times, `type=1` five times and **`type=2` twenty-one times**. A two-valued enum cannot produce
  that.
- **The sixteen-token shared body** at VA `0x4CD5FB`: exactly `push eax; jmp 0x4cd398`, two
  instructions into `declarewar`'s own case.
- **The `declarewar` rename**, with a check agent D did not make: counting those keys as country
  keys across the corpus gives `debtaction_action` 1,000, `nap` 294, `trade_action` 45,
  `licence_technology` 6 — and `declarewar` **zero**. So the list was named after the one token that
  never appears in the data, while 1,345 blocks of other kinds do.

**The header half still needs the same change by hand** — `BiceLib/GameClasses/CCountry.hpp`
lines 342-344 and `CLASSES.md:1559` — which is trap 14's own lesson and the reason the agent flagged
it rather than assuming the fragment covered it.

---

# Slot 7: what accepting an agreement actually does

Section 9 of this file called slot 7 "the single biggest thing left here" and listed it as not read in
any class. This closes it. Read out of the executable on 2026-10-04 by wave 12's agent D,
cross-checked against the 45 savegames and against BlackICE's own `common/defines.lua`. Nothing here
needed the game running. Addresses in this half of the file are **virtual**, based `0x400000`, with
the rva beside anything a finding names.

## 11. In one line

Slot 7 is **not** one effect per class so much as **one shape** instantiated twenty times: each body
branches on `type` (`+0x18`) and `value` (`+0x24`), charges its own `*_INFLUENCE_COST` define off the
actor's `CCountry::diplo_influence` (`+0xA88`) **when the offer is proposed**, and on ACCEPT builds a
`CRelation` subclass — `CNap`, `CTradeRoute`, `CAlliance`, `CGuarantee`, `CEmbargo`, `CAlign`,
`CInfluence`, `CDependency`, `CCasusBelli` — stamps it with the action's `date`, calls its **slot 10**,
which hangs it on **both** parties' `CDiplomacyStatus`, appends it to the one global list of relations
at `CCurrentGameState +0xB2C`, and moves the pair's relation by its own `*_RELATION_CHANGE` define
through a function that had no identified writer until now. Then it raises `diplomaticsuccess` or
`diplomaticfailure` with three localisation keys — one for the actor, one for the recipient, one for
everybody else.

## 12. The call site and the signature

`CDiplomaticActionCommand::Execute` calls slot 7 at `0xA0E19E` (section 5 step 3). Every concrete class
overrides it; `CDiplomaticAction` and `CWarGoalBaseAction` leave it `_purecall` (`0x00B961D5`) and
`CNullDiplomaticAction` answers the 1,691-holder empty stub `0x00ABF890`. So there are **21 tables with
a body and 20 distinct bodies**, because `CAddWarGoalAction` and `CJoinFactionGoalAction` share one.

All twenty are the same signature — `this` in ECX, no stack arguments, bare `ret`:

    void __thiscall CTradeAction::Apply(CTradeAction* this)

`Apply` is **our** name. No string, no assert and no luabind registration names slot 7: the
`CDiplomaticAction` registration block at `0x8ED3EF` registers `IsValid` and `IsSelectable` and then
the `GetValue`/`SetValue`/`GetType`/`GetAIAcceptance` chain section 8 already accounts for, and slot 7
is not among them. The name is inference; the bodies are read.

## 13. The twenty bodies, their extents, and two trap 2 cases

Extents were bounded by the **next slot of the same class**, read straight out of the class's own
vftable, not by padding — which is what caught the two cases below. A `cfg.walk` from each entry also
confirms that the only `ret` reachable from the entry is the bare one, i.e. no trap 3 funclet and no
swallowed neighbour.

| class | slot 7 (VA / rva) | last byte | bytes | padding before the next slot |
| --- | --- | --- | --- | --- |
| `CRequestLendLeaseAction` | `0xA0ECC0` / `0x60ECC0` | `0xA0FC57` | 0xF98 | 8 |
| `COfferLendLeaseAction` | `0xA10870` / `0x610870` | `0xA11573` | 0xD04 | 12 |
| `CDeclareWarAction` | `0xA12030` / `0x612030` | `0xA147B2` | 0x2783 | 13 |
| `CAllianceAction` | `0xA18D70` / `0x618D70` | `0xA1A434` | 0x16C5 | 11 |
| `CGuaranteeAction` | `0xA1BCC0` / `0x61BCC0` | `0xA1D379` | 0x16BA | 6 |
| `CInfluenceNation` | `0xA1E420` / `0x61E420` | `0xA1FB4A` | 0x172B | 5 |
| `CInfluenceAllianceLeader` | `0xA20F70` / `0x620F70` | `0xA21EE1` | 0xF72 | 14 |
| **`CMilitaryAccessAction`** | `0xA231F0` / `0x6231F0` | `0xA247BF` | **0x5D0** | **0 — trap 2** |
| `COfferMilitaryAccessAction` | `0xA25830` / `0x625830` | `0xA26D05` | 0x14D6 | 10 |
| `CCallAllyAction` | `0xA27BA0` / `0x627BA0` | `0xA29D33` | 0x2194 | 12 |
| `CNapAction` | `0xA2B090` / `0x62B090` | `0xA2C8EA` | 0x185B | 5 |
| `CEmbargoAction` | `0xA2E5F0` / `0x62E5F0` | `0xA2F9F0` | 0x1401 | 15 |
| `CFactionAction` | `0xA30E70` / `0x630E70` | `0xA32FC6` | 0x2157 | 9 |
| `CTradeAction` | `0xA352F0` / `0x6352F0` | `0xA3751B` | 0x222C | 4 |
| `CSendExpeditionaryForceAction` | `0xA395B0` / `0x6395B0` | `0xA3A853` | 0x12A4 | 12 |
| **`CLicenceTechnologyAction`** | `0xA3B5A0` / `0x63B5A0` | `0xA3CD5D` | **0x17BE** | **2 — trap 2** |
| `CDebtAction` | `0xA3D8A0` / `0x63D8A0` | `0xA3E500` | 0xC61 | 15 |
| `CPeaceAction` | `0xA3F710` / `0x63F710` | `0xA40A9B` | 0x138C | 4 |
| `CAddWarGoalAction` + `CJoinFactionGoalAction` | `0xA435F0` / `0x6435F0` | `0xA43770` | 0x181 | 15 |
| `CShareTechnologyAction` | `0xA4B780` / `0x64B780` | `0xA4B849` | 0xCA | 6 |

**`CMilitaryAccessAction` is a fresh trap 2 pair, and a clean one.** Slot 7 ends `ret` at `0xA247BF`
and `CMilitaryAccessAction` **slot 11 begins at `0xA247C0`, with no padding at all**. An `int3` scan
gives slot 7 0x1C90 bytes instead of 0x5D0 and then attributes slot 11's tooltip strings —
`MILACCDESC`, `CANCELMILACCDESC`, `CANCELMILACCDESC_NOPES_TROOPS`, `DIP_NO_INFL`, `ISATWAR`,
`ENROUTE`, `DATE` — and two further `MILACCESS_INFLUENCE_COST` reads to the effect. The first pass of
this work did exactly that.

**`CLicenceTechnologyAction` is the same mistake one step subtler**: slot 11 is at `0xA3CD60` with
**two** `int3` before it, so the brief's own "require a run of at least three `int3`" rule walks
straight past the boundary. That rule protects against reading data as padding; it does not help here,
and the vftable is what settles it. The over-long extent picks up `BUYLICENCEDESC`, `SELLLICENCEDESC`,
`ACT_NO_SELF`, `DIP_NO_INFL` and a second `LICENCE_INFLUENCE_COST` read at `0xA3D13E`.

**Both are confirmed a second way, for free.** `cfg.walk` from each slot-7 entry reaches only bare
`ret`s. The `ret 4` at `0xA24E79` and the `ret 4` at `0xA3D2B6` are **not reachable** from the slot-7
entries, which is independent of the padding argument and says the same thing: those bytes are slot
11's. *A different stack immediate past the end is a cheap extra test for trap 2, and it is one this
folder has not used before.*

`CDeclareWarAction` looks like a third case and is not: the entry 13 `int3` after its `ret`, at
`0xA147C0`, is a helper **this body itself calls twice**, and `CDeclareWarAction` slot 11 is further on
at `0xA14BB0`.

## 14. The defines are the fingerprint

The cheapest and most decisive check in this whole reading. Every body resolves its constants through
`call GetDefines (0x445D90)` then `[eax+0xBC]` — the **diplomacy** block — then `[block + N]`, and
`scripts/definesMap.py --block diplomacy` turns every `N` into a name. **Each class reads exactly the
defines named after it and no others.** Twenty bodies, 34 distinct defines, not one crossing into
another class's group except where it obviously should.

| class | influence costs | relation changes | other |
| --- | --- | --- | --- |
| `CDeclareWarAction` | `WARDEC_INFLUENCE_COST` (+0x8) | `WARDEC_WAR_DIPLOMACY_HIT` (+0x4) | |
| `CAllianceAction` | `JOIN_ALLIANCE_INFLUENCE_COST` (+0xC), `LEAVE_ALLIANCE_INFLUENCE_COST` (+0x10) | `ALLIANCE_RELATION_CHANGE` (+0x40), `ALLIANCE_REJECT_RELATION_CHANGE` (+0x44) | |
| `CGuaranteeAction` | `GUARANTEE_INFLUENCE_COST` (+0x14), `REVOKE_GUARANTEE_INFLUENCE_COST` (+0x18) | `REVOKE_GUARANTEE_RELATION_CHANGE` (+0x70) | |
| `CCallAllyAction` | `CALLALLY_INFLUENCE_COST` (+0x1C) | `WARDEC_WAR_DIPLOMACY_HIT` (+0x4), `ALLIANCE_REJECT_RELATION_CHANGE` (+0x44) | |
| `CEmbargoAction` | `EMBARGO_INFLUENCE_COST` (+0x28) | `EMBARGO_RELATION_CHANGE` (+0x80) | |
| `CMilitaryAccessAction` | `MILACCESS_INFLUENCE_COST` (+0x2C) | `MILACC_ACCEPT_RELATION_CHANGE` (+0x64), `MILACC_DECLINE_RELATION_CHANGE` (+0x68) | |
| `CNapAction` | `NAP_JOIN_INFLUENCE_COST` (+0x54), `LEAVE_NAP_INFLUENCE_COST` (+0x5C) | `NAP_RELATION_CHANGE` (+0x4C), `LEAVE_NAP_RELATION_CHANGE` (+0x50), `NAP_REJECT_RELATION_CHANGE` (+0x58) | `LEAVE_NAP_THREAT_COST` (+0x60), **by address** |
| `CInfluenceNation` | — | `DAYS_OF_INFLUENCE_RELATION_CHANGE` (+0x74) | |
| `CInfluenceAllianceLeader` | `ALIGN_INFLUENCE_COST` (+0x7C) | `DAYS_OF_ALIGN_RELATION_CHANGE` (+0x78) | |
| `CFactionAction` | `JOIN_FACTION_INFLUENCE_COST` (+0x8C), `INVITE_FACTION_INFLUENCE_COST` (+0x90) | — | |
| `CTradeAction` | `TRADE_INFLUENCE_COST` (+0xA0) | `TRADE_RELATION_CHANGES` (+0x9C), `TRADE_CANCEL_RELATION_COST` (+0xA8) | |
| `CSendExpeditionaryForceAction` | `EXPEDITION_INFLUENCE_COST` (+0xAC) | — | `EXPEDITION_RETURN_TIME` (+0xB0) |
| `CLicenceTechnologyAction` | `LICENCE_INFLUENCE_COST` (+0xB8) | — | |
| `CShareTechnologyAction` | `SHARE_TECH_INFLUENCE_COST` (+0xBC) | — | |
| `CDebtAction` | `ALLOW_DEBT_INFLUENCE_COST` (+0xC4), `REVOKE_DEBT_INFLUENCE_COST` (+0xC8) | — | |
| `CRequestLendLeaseAction` | **`ALLOW_DEBT_INFLUENCE_COST`** (+0xC4) | — | |
| `COfferLendLeaseAction`, `COfferMilitaryAccessAction`, `CPeaceAction`, the war-goal body | none | none | |

Two of those rows are worth stopping on. **`CRequestLendLeaseAction` charges the debt define**, not a
lend-lease one — there is no `LEND_LEASE_*_INFLUENCE_COST` in the block at all, only
`LEND_LEASE_NEUTRALITY_LIMIT` and the two IC caps, none of which any slot 7 reads. And **`CNapAction`
reads `NAP_JOIN_INFLUENCE_COST` (+0x54), never `NAP_INFLUENCE_COST` (+0x20)**, which no slot 7 touches.

**A fourth way a define hides from a block scan, to go beside trap 8's three.** `LEAVE_NAP_THREAT_COST`
is never loaded. At `0xA2BFE3` the body does `add edi, 0x60` on the register already holding the
diplomacy block and hands the **address** to `0x4F50A0`, the threat adder. A scan looking for
`mov reg, [block + N]` cannot see that, and `EMBARGO_THREAT_COST` (+0x88) is almost certainly reached
the same way — `CEmbargoAction` calls `0x4F50A0` twice and never loads +0x88.

Of the diplomacy block's 67 entries, 34 are read by a slot 7 and 33 are not found there. **That second
number is a result from a method with a known blind spot**, not a statement that they are unread: it
cannot see an inlined `GetDefines` (trap 8 case 1 — `CInfluenceNation` contains one, `call 0x4452E0`),
a define cached into a global at startup (case 2), or a define passed by address (the new case above).
Its positive control is that it finds every other class's own defines in the same pass.

## 15. The ACCEPT path, and what it writes

### `CShareTechnologyAction` — the whole shape in 42 instructions

`0xA4B780`, 0xCA bytes, read end to end. It is the one member that raises no message and touches no
`CDiplomacyStatus`, which is exactly why it is the one to read first:

    if (!this->value) { 0x507C10(GetCountry(&recipient), GetCountry(&actor)@ECX); return; }
    if (!this->+0x28) return;                       // the shared technology
    actor = countries[this->actor_id];
    actor->diplo_influence -= GetDefines()->diplomacy->SHARE_TECH_INFLUENCE_COST;
    if (actor->diplo_influence < 0) actor->diplo_influence = 0;
    0x507B40(GetCountry(&actor), this->+0x28->+0x5C, GetCountry(&recipient)@EAX);

`0x507B40` and `0x507C10` are a matched add/remove pair over a 0xC-byte-strided vector at
`CCountry +0x6F0`, which is where a shared technology is recorded. Both are unnamed; they are in the
frontier.

### `CNapAction` — all four arms

`0xA2B090`. The arms, in the order the code tests them:

| arm | what it does |
| --- | --- |
| `type == PROPOSE && value` (`0xA2B9A0`) | `countries[actor]->diplo_influence -= NAP_JOIN_INFLUENCE_COST`, clamped at 0 (`0xA2B9D3`) |
| `type == ACCEPT` (`0xA2B9F2`) | `new(0x30)`; `CNap::CNap` (`0xA46F00`, vftable `0x15FBB68`); `nap->first = actor`, `nap->second = recipient`, `nap->start_date (+0x18) = action->date (+0x1C)`; `CNap::Activate()` (slot 10, `0xA471E0`); append to the relation list (`0xA2BAC8`); `CCountry::ChangeRelation(actor, &recipient, NAP_RELATION_CHANGE)` (`0xA2BB00`) |
| `type == DECLINE` (`0xA2C3F6`) | `ChangeRelation(..., NAP_REJECT_RELATION_CHANGE)` (`0xA2C40B`) |
| `value == 0` — breaking a pact | find the existing `CNap` in the relation list, `CList_RemoveNode` (`0xA2BF83`), delete it through slot 0 (`0xA2BF92`); `0x4F50A0(..., &LEAVE_NAP_THREAT_COST, ...)`; `ChangeRelation(..., LEAVE_NAP_RELATION_CHANGE)`; `diplo_influence -= LEAVE_NAP_INFLUENCE_COST` |

**The influence is charged on PROPOSE, not on ACCEPT.** That is true of every class with a cost: the
`type == 0 && value` test and the `+0xA88` subtraction sit together, above the ACCEPT branch, in
`CNapAction` at `0xA2B9A0`, in `CTradeAction` at `0xA35AE9` and in `CShareTechnologyAction` inline.
Offering costs; being refused does not refund.

### `CTradeAction`

`0xA352F0`, same four arms. `TRADE_INFLUENCE_COST` on propose (`0xA35B21`); on accept,
`CTradeRoute::IsValid(&this->+0x28)` gates it — `0xA4CEE0`, and **`IsValid` is the name the luabind
registration at `0x8ED468` gives that very address under the `CTradeRoute` class**, so
**`CTradeAction +0x28` is an embedded `CTradeRoute`** — then `operator new(0x88)` =
`sizeof(CTradeRoute)`, copy-constructed from `+0x28` through `0xA4C660`, `route->+0x18 = action->date`,
`CTradeRoute::Activate()`, append, and
`ChangeRelation(..., TRADE_RELATION_CHANGES)` at `0xA35F15`. Cancelling reads
`TRADE_CANCEL_RELATION_COST`.

### `CRelation` slot 10 — the step that writes the fields

**This is the answer to "which fields on which objects".** `CRelation` (vftable `0x15FBB00`) leaves
slot 10 `_purecall`; nine of its ten subclasses override it and `CWarning` answers the empty stub. The
body hangs a freshly made relation on the two countries it is between, through
`countries[id]->+0xE28[otherId]` — the `CDiplomacyStatus` array.

| class | slot 10 (VA / rva) | writes | directions | sets `+0x59` |
| --- | --- | --- | --- | --- |
| `CAlliance` | `0xA46A40` / `0x646A40` | `+0x14` **alliance** | both | yes |
| `CDependency` (and `CVassal`) | `0xA47760` / `0x647760` | `+0x18` **dependency** | both | yes |
| `CGuarantee` | `0xA46DB0` / `0x646DB0` | `+0x1C` **guarantee** | both | yes |
| `CNap` | `0xA471E0` / `0x6471E0` | `+0x28` `nap` *(already recorded)* | both | yes |
| `CInfluence` | `0xA4AAD0` / `0x64AAD0` | `+0x2C` `influence_running` *(already recorded)* | recipient→actor only | yes |
| `CAlign` | `0xA4B110` / `0x64B110` | `+0x30` **align** | actor→recipient only | **no** |
| `CEmbargo` | `0xA4B530` / `0x64B530` | `+0x34` **embargo** | both | **no** |
| `CCasusBelli` | `0xA47BB0` / `0x647BB0` | appends to `+0x3C`/`+0x40`/`+0x44` **casus_belli** | one | yes |
| `CTradeRoute` | `0xA4D2C0` / `0x64D2C0` | appends to `+0x60`/`+0x64`/`+0x68` `trade_routes` | both | yes |

So **five previously unnamed `CDiplomacyStatus` fields are named from their writers** — `+0x14`,
`+0x18`, `+0x1C`, `+0x30`, `+0x34` — plus the casus-belli list at `+0x3C`/`+0x40`/`+0x44` and the trade
list's tail at `+0x64`, which sat unrecorded between the recorded `+0x60` head and `+0x68` count.

Two of those have independent corroboration already in the record, which is trap 14's converging-readings
case rather than a collision. `project.json`'s account of `0x8A9390` says that predicate answers false
"if our own faction leader's `CDiplomacyStatus` toward them has `+0x14` set" — it reads `+0x14` as *they
are our ally*, which is what `CAlliance::Activate` makes it. And `+0x2C influence_running` is recorded
as "non-zero while a diplomatic influence is running between the pair"; it is **the `CInfluence*`
itself**, and only the influenced country's side of the pair carries it. The existing name is still
right, so it is refined here rather than revised.

`CGuarantee::Activate` is the whole mechanism in 17 instructions with no branch, and is the one to read
if only one is read:

    fwd = countries[this->first_id]->diplomacy[this->second_id];
    fwd->changed (+0x59) = 1;  fwd->guarantee (+0x1C) = this;
    rev = countries[this->second_id]->diplomacy[this->first_id];
    rev->changed = 1;          rev->guarantee = this;

### `CCountry::ChangeRelation` — rva `0xE65C0`, and the units

The function the `*_RELATION_CHANGE` defines go into. 24 instructions, read end to end, `ret 4`, with
the receiver in **EDI**, the other country's tag in **ECX** and the delta as the one stack argument —
so it has no ordinary convention and the storage is spelled out (trap 11):

    void __fastcall CCountry::ChangeRelation(CCountry* this@EDI, CCountryTag* other@ECX, int delta@stack:4)

    fwd = this->diplomacy[other->id];
    fwd->changed (+0x59) = 1;
    v = clamp(delta + fwd->relation (+0x38), [0x1710C38], [0x1710C34]);
    fwd->relation = v;
    rev = other->GetCountry()->diplomacy[this->id];     // CCountryTag::GetCountry, 0x402610
    rev->changed = 1;
    rev->relation = v;

**`CDiplomacyStatus +0x38 relation` had no identified writer** — `project.json` carries it as "the
pair's relation, thousandths. Inferred, not proven: the alignment relation term averages it." This is
the writer, and it settles three things at once:

- **Relation is symmetric by construction.** The delta is applied to the *forward* side's value and the
  single clamped result is written to both. The two can never diverge.
- **`[0x1710C34] = 200000` and `[0x1710C38] = -200000`**, so relation is **thousandths on a
  −200.000..+200.000 scale** — trap 7, and the range the diplomacy screen shows.
- **`EMBARGO_RELATION_CHANGE = -200.0` in BlackICE's `common/defines.lua:299` is `-200000` stored,
  which is the clamp floor exactly.** One embargo drops the pair to the bottom of the scale in a
  single step. Two numbers read from two different files landing on the same value is as good a
  thousandths proof as this project gets.

There are 18 call sites, every one inside a slot 7.

**A caveat on the save as an oracle here.** `CDiplomacyStatus` is written per partner inside each
country block, as `IRE={ ... GER={ value=10  threat=2.357  last_send_diplomat="1938.5.3.5" } ... }`. The
relation is the `value` key and it is written as a **bare integer** (`value=75`, `value=140`) while
`threat` beside it is written `2.357`. So the save does not show relation's thousandths directly — it
writes the whole points — and the scale claim rests on the clamp globals and the define, not on the
save. Said rather than rounded up.

### `CWarGoalBaseAction::Apply` — rva `0x6435F0`, and a correction to section 9

Section 9 lists `0x00A435F0` as "the war-goal base". **It is not: `CWarGoalBaseAction` slot 7 is
`_purecall`.** `0xA435F0` is slot 7 of `CAddWarGoalAction` **and** of `CJoinFactionGoalAction`, and of
nothing else in the image — two identical bodies the linker folded. `vtable.py --holding` prints both.
Because their common base leaves the slot pure, neither derived class can own the name without putting
it on the other (trap 4's two-holder case, the dangerous size), so the record puts it on the base,
where the code belongs, and notes the slot on both derived classes.

0x181 bytes, two exits in one frame. **`this->+0x28` is an embedded `CWarGoal`**: `0x47BBE0` is called
with `ECX = this+0x28` and reads `+0x18`, `+0x1C` and `+0xC`, which are `actor.tag`, `actor.index` and
`casusBelli` in the layout `BiceLib/GameClasses/CWarGoal.hpp` established independently from
`CWarGoal::LoadKey`. Three offsets agreeing with a reading made in another session, from another
function, is confirmation rather than coincidence.

    status = countries[actor_id]->diplomacy[recipient_id];
    0xA51FB0(status->war (+0x20), actor.tag, actor.id);     // the add itself, unnamed
    0x47BBE0(&this->warGoal);
    goal = &this->warGoal;                                  // this->+0x34 is its casusBelli
    walk status->casus_belli (+0x3C) for the entry whose +0x24 == goal->casusBelli->+8
      not found -> 0xA49EB0() must answer true, or return
      found     -> 0xA49F40(status, 0);
                   remove that CCasusBelli from the relation list; delete it through slot 0

Reading that tail as *adding the war goal consumes the casus belli it was justified by* is
**inference**; the removal and the delete are read. `WARGOAL_ADD_COOLDOWN` (diplomacy +0xFC) is not
read here.

## 16. `CCurrentGameState +0xB2C` — the one list every agreement goes into

`+0xB24` is already recorded as `diplomacy`, "a `CDiplomacy`", in `project.json` and in
`BiceLib/GameClasses/CCurrentGameState.hpp:57`. Its **list** is at its own `+8`/`+0xC`/`+0x10`, i.e.
`CCurrentGameState +0xB2C` head, `+0xB30` tail, `+0xB34` count, nodes 0x10 bytes
`{value, prev@+4, next@+8, byte@+0xC}`. That is why two helpers get two different pointers: the append
`0x493E10` is passed `state+0xB24` (the owner) and the recorded `CList_RemoveNode` is passed
`state+0xB2C` (the head field). Getting those two confused is how `+8` would be wrong, and they
cross-check each other.

Six slot-7 bodies append here: `0xA195DF` (alliance), `0xA1BDCA` (guarantee), `0xA21155` (align),
`0xA2BAC8` (nap), `0xA2EFB9` (embargo), `0xA35ED3` (trade).

**The savegame is the independent half, and it is decisive.** The single top-level `diplomacy=` block
is this list, and in `Ireland1939_01_03_02.hoi3` it holds **1,248 `trade`, 38 `guarantee`, 21
`alliance`, 21 `influence`, 8 `align`, 8 `nap` and 7 `vassal`** entries — seven of `CRelation`'s ten
subclasses, one key per class, with `CCasusBelli`, `CEmbargo` and `CWarning` simply absent from that
game. Each entry carries `first`, `second` and `start_date`, which are `CRelation +0x8`, `+0x10` and
`+0x18` — and `+0x18` is the field `CNapAction` and `CTradeAction` stamp from the action's own `date`.
A `nap` block reads:

    nap={ balance=1000.000  our_power=0  their_power=0
          first="CHI"  second="SOV"  start_date="1937.8.21.19" }

**`0x493E10` is not CDiplomacy-specific** — it has 12 callers, six of them outside this family
(`0x442F92`, `0x4A5ADC`, `0x4E67B4`, `0x5F31C6`, `0x9B6278`, `0x9B721C`) — so it is a generic
append-to-a-list-at-`+8` helper and is deliberately left unnamed here; naming it after this one use
would be exactly trap 14. It is in the frontier.

## 17. Who sees it: the message

Most of each body's bulk is the message, which is why the average slot 7 is 0x1600 bytes while
`CShareTechnologyAction`'s is 0xCA. Every message-raising body does the same three things: the inlined
`g_CCurrentGameState` get-or-create (`[0x1A89790]`, `new(0xDA8)`, vftable `0x15CF674` — the 2,772-copy
accessor the record already accounts for), `CCountry::BuildMessageVariables` (`0x4D75F0`), and
`GetMessageHandler` (`0x698E80`). The category is `diplomaticsuccess` or `diplomaticfailure`, and the
key is chosen on whether `state->played_country_id (+0xC34)` equals the actor's id, the recipient's, or
neither — the `WE…` / `THEY…` / `OTHER…` triple:

| class | accept | decline | cancel / revoke |
| --- | --- | --- | --- |
| `CNapAction` | `WENAP` / `THEYNAP` / `OTHERNAP` | `WEREJECTNAP` / `THEYREJECTNAP` / `OTHERREJECTNAP` | `WECANCELNAP` / `THEYCANCELNAP` / `OTHERCANCELNAP` |
| `CTradeAction` | `ACTRAWITHUS` / `WETRADEAG` / `OTHERTRADEAG` | `DETRAWITHUS` / `WEDETRA` / `DETRAWITHOTHER` | `WEBRKTRADE` / `BRKTRADEUS` / `BRKTRADEOTH` |
| `CAllianceAction` | `MILALLACCEPT` / `MILALLWEACCEPT` / `MILLALLINVACCEPTOTHER` | `MILALLREJECT` / `MILALLWEREJECT` / `MILLALLJOINREJECTOTHER` | `MILALLBAN` / `MILALLWEBAN` / `MILALLBANOTHER` |
| `CMilitaryAccessAction` | `ACCMILUS` / `WEACCMIL` / `ACCMILOTHER` | `DECMILUS` / `WEDECMIL` / `DECMILOTHER` | `CANCMILUS` / `WECANMIL` / `CANMILOTHE` |
| `COfferMilitaryAccessAction` | `OFFACCMILUS` / `WEOFFACCMIL` / `OFFACCMILOTHER` | `OFFDECMILUS` / `WEDECOFFMIL` / `DECOFFMILOTHER` | `CANCMILUS` / `WECANMIL` / `CANMILOTHE` |
| `CCallAllyAction` | `MILALLHONOUR` / `WEMILALLHONOUR` / `OTHERMILALLHONOUR` | `MILALLDISHONOUR` / `WEMILALLDISHONOUR` / `OTHERMILALLDISHONOUR` | — |
| `CFactionAction` | `FACTIONINVITEACCEPT`, `FACTIONJOINACCEPT` / `FACTIONJOINACCEPTOTHER` | `FACTIONJOINDECLINCE`, `FACTIONINVITEDECLINCE` | — |
| `CSendExpeditionaryForceAction` | `OUREXPACC` | `OUREXPDEC` | `EXPOTHER` |
| `CLicenceTechnologyAction` | `LICBUYACCEPT` | `LICBUYDECLINE` | — |
| `CDebtAction` | `DEBTALLOWACCEPT` | `DEBTALLOWDECLINE` | `DEBTREVOKE` |
| `CRequestLendLeaseAction` | `LENDACCEPT` | `LENDDECLINE` | `LENDOFFERREFUSED` |
| `COfferLendLeaseAction` | `LENDOFFERACCEPT` | `LENDOFFERREFUSED` | `LENDREVOKE` |
| `CDeclareWarAction` | `DECLWAR` / `WEDECLWAR` / `DECLWAROTHER`, `DECLWAR_LIMITED` | — | — |
| `CGuaranteeAction` | `WEGUARAT` / `GUARATOUS` / `GUARATOOTHER` | — | `GUARACANCELTOTHEM` / `GUARACANCELTOUS` |
| `CEmbargoAction` | `WEEMBARGO` / `THEYEMBARGO` / `OTHEREMBARGO` | — | `WECANCELEMBARGO` / `THEYCANCELEMBARGO` / `OTHERCANCELEMBARGO` |
| `CInfluenceNation` | `WEINFLUENCE` / `THEYINFLUENCE` / `OTHERINFLUENCE` | — | — |
| `CInfluenceAllianceLeader` | `WEALIGN` / `THEYALIGN` / `OTHERALIGN` | — | — |
| `CPeaceAction` | `PEACEACCEPT` | `PEACEDECLINE` | — |
| `CShareTechnologyAction`, the war-goal body | *(no message at all)* | | |

**The empty columns are a finding, not a gap.** `CGuaranteeAction` and `CEmbargoAction` have no
accept/decline pair, and `CGuaranteeAction`'s very first test is `this->value` with no `type` test
above the allocate-and-append at `0xA1BCF5`–`0xA1BDCA`: **a guarantee and an embargo take effect when
they are offered and are not answered.** `CPeaceAction` has only two keys and no third-party
perspective. `CDeclareWarAction` additionally builds `MESS_BADWORDS1`..`4`, which is the war-declaration
insult text.

## 18. Two one-line class facts worth having

`CFactionAction`'s first three tests, read straight off `0xA30E9D`–`0xA30EDF`: `value` must be set,
`countries[actor]->at_war (+0xACC)` must be **clear** — a country at war cannot run a faction action —
and `countries[recipient]->faction (+0xD8)->+0x28` must be non-null.

`CPeaceAction` reads no defines and instead calls `CWar::RemoveAttacker` (`0xA50440`) twice and
`CWar::RemoveDefender` (`0xA51710`) twice, both already named in the record, plus `0x4E70A0` and
`0x4E7190` on both countries. Peace costs no influence and moves no relation by a define.

## 19. What this section closes, and what it does not

Replacing section 9's list:

- ~~**Slot 7, the per-class effect**, was not read in any class.~~ **Closed, with a stated remainder.**
  Read end to end: `CShareTechnologyAction`, `CGuarantee::Activate`, `CCasusBelli::Activate`,
  `CCountry::ChangeRelation`, and the war-goal body. Read arm by arm: `CNapAction` (all four),
  `CTradeAction` (propose and accept). Read for extent, inputs, call set and message keys only, with
  the names marked inference: the other sixteen. **The remainder is: sixteen bodies whose
  `CDiplomacyStatus` and `CCountry` writes have not been enumerated**, and the four — `CDeclareWarAction`,
  `CCallAllyAction`, `CFactionAction`, `CLicenceTechnologyAction` — that reach into the war, faction and
  technology layers are where that matters most.
- ~~`0x00A435F0` is "the war-goal base".~~ **Corrected.** `CWarGoalBaseAction` slot 7 is `_purecall`;
  `0xA435F0` is slot 7 of its two derived classes, folded.
- **`CDiplomacyStatus +0x50` has one writer and no identified reader.** Untouched — no slot 7 reads it.
- **Whether `GetAIAcceptance` gates the posting rather than the accepting.** Untouched, and slightly
  narrowed: no slot 7 calls slot 17 either, so nothing on the *effect* path consults the score. The
  diplomacy GUI's button handlers remain the place to look.
- **Where the 13,669 live `CNullDiplomaticAction`s are.** Untouched.
- **Slot 18 is unnamed on purpose.** Unchanged.
- **`0x4E39C0`**, the per-country recomputation. Still open; eight of the twenty slot-7 bodies call it,
  21 call sites in all, which strengthens the case for it as a standalone item.
- **`CDiplomaticActionCommand::Clone` ends `ret 0x1C`.** Unchanged.
- ~~`CDiplomaticActionCommand` and `CNullDiplomaticAction` have no `structs` record.~~ Unchanged, and
  **the list is longer: `CRelation`, `CNap`, `CAlliance`, `CGuarantee`, `CEmbargo`, `CAlign`,
  `CInfluence`, `CDependency`, `CCasusBelli` and `CDiplomacy` have none either**, and
  `mergeFindings.py` will not create a struct. So this section's `CRelation` layout —
  `+0x8` first tag/id, `+0x10` second tag/id, `+0x18` start_date, `+0x1C` end_date, `+0x20` a byte,
  subclass fields from `+0x24` — is described here and recorded nowhere, and `CRelation` at least wants
  a hand-added struct.

New open items:

- **`CDiplomacyStatus +0x59` has eleven writers and no reader was looked for.** Every
  `CRelation::Activate` but `CAlign`'s and `CEmbargo`'s sets it, and so does `ChangeRelation` on both
  sides. It is recorded `changed`, `inferred`, on that basis alone — exactly the shape of the mistake
  trap 14 records for `tutorial_active`, and it should be read as provisional until somebody scans for
  a reader. **Why `CAlign` and `CEmbargo` do not set it** is its own small question.
- **Why the influence cost is charged on PROPOSE.** It means an AI that declines still costs the
  proposer; whether the GUI refunds it was not looked at.
- **`0xA51FB0`, `0xA49EB0`, `0xA49F40` and `0x47BBE0`** — the war-goal chain, all register-argument
  heavy and all unnamed. A wave of their own.
- **`0x4F50A0`**, the threat adder, four callers, which is where `LEAVE_NAP_THREAT_COST` and almost
  certainly `EMBARGO_THREAT_COST` land.
- **`0x507B40` / `0x507C10`**, the add/remove pair over `CCountry +0x6F0`, which is where a shared
  technology is recorded, and `CCountry +0x1144`, set to 1 by `CInfluence::Activate`.

## 20. Frontier

Ninety-three unnamed call targets out of the twenty slot-7 bodies and the nine slot-10 bodies, as rvas,
in `fragments/merged/diploaccept.json`. The ones worth a name first: `0x93E10` (the generic
append-at-`+8`, 12 callers), `0xE39C0` (21 calls), `0x118730` (49), `0x7BBE0`, `0x651FB0`, `0x649EB0`,
`0x649F40`, `0xF50A0`, `0x107B40`, `0x107C10`, `0x103F90`, `0x64C660`, `0x646F00`, `0x634CA0` (10
calls, inside `CTradeAction` only). The high-count entries `0x6AC690` (116), `0x709E20` (68),
`0x2F070` (65), `0x6ACC40` (60), `0x34290` (52) are string and container helpers, flagged by their
counts rather than by a reading.

---

## Transcription note, sections 11-20

Read and written by wave 12's agent D; transcribed by the session that collected the wave, because an
agent's `Write` is refused for this path. The agent flagged two judgement calls for the collecting
session to re-decide and both were checked and kept:

- **`CWarGoalBaseAction::Apply` is named for a class whose own slot 7 is `_purecall`.**
  `vtable.py --holding 0x00A435F0` confirms exactly two holders, `CAddWarGoalAction` and
  `CJoinFactionGoalAction`, both at slot 7. They are one family, so the fold is benign (trap 4's own
  "ask whether the holders are one family" test), and the fragment records `vftable_slots` on the two
  holders only — it does not claim the base holds the body. Kept.
- **`Apply` and `Activate` are this project's names, not the game's.** Sixteen of the twenty `Apply`
  entries are `inferred` for that reason: the behaviour in their comments is read, the name is not.

Spot-checked independently before transcription, all confirming:

- **`CCountry::ChangeRelation`** (rva `0xE65C0`) decoded instruction for instruction: `[edi+0xe28]`
  for the diplomacy array, the other's id from `[ecx+4]`, the delta from `[ebp+8]`, `+0x38` read and
  added, `+0x59` written 1, then `mov ebx, [0x1710c34]` and a `cmovg`. The convention is as reported.
- **The clamp globals**, which are the whole basis of the thousandths claim: `[0x1710C34]` is
  **200000** and `[0x1710C38]` is **-200000**, both statically present in `.data`, which makes relation
  thousandths on a ±200.000 scale. *Getting this wrong was this session's own trap 1: a first reading
  passed those two **virtual** addresses to `image.read`, which takes a VA, as though they were rvas,
  read `0x1310C34` in `.rdata` instead, got zero for both, and briefly had the agent's central claim
  down as unsupported. `image.read`, `image.decode` and `image.findValue` all take VAs; `image.both`
  takes a VA and prints the rva beside it.*
- **The `CMilitaryAccessAction` trap 2 pair**: slot 7's `ret` at `0xA247BF` and a fresh SEH prologue
  (`push ebp; mov ebp, esp; push -1; push 0xc62f06; mov eax, fs:[0]`) at `0xA247C0` — **zero** padding
  bytes between them, exactly as reported.

**A method note the agent proposed and this session adopted**, now trap 2's fourth check in
`TRAPS.md`: when a vftable gives a candidate boundary, a `ret` past it carrying a **different stack
immediate** and **unreachable from the entry** by `cfg.walk` confirms the split independently of any
padding argument. `CLicenceTechnologyAction` is the case that needs it — slot 11 sits **two** `int3`
after slot 7, so the "require a run of at least three `int3`" rule walks straight past the boundary.

One thing the agent noted and left alone, and it is still open: `image.decode(address, length)` takes
a **byte** count, not an instruction count, so `decode(addr, 1)` returns nothing at all. A throwaway
read/write classifier written in this session asked for 1 instruction, got silence for all 22
reference sites, and reported "no writers anywhere" — a false negative from the tool, which is the
habit `TRAPS.md`'s closing section is about. Its positive control caught it.

## 21. The war-goal chain, the threat spread, and the save grammar - in one line

Read out of the executable on 2026-10-05 by wave 13's agent C. Addresses here are **virtual**, based
`0x400000`, with the rva beside anything a finding names. Nothing needed the game running.

The war-goal chain is four functions and it is now read end to end: `CWarGoal::AddToWar` (rva
`0x651FB0`) appends the goal to the war and stamps a **one-month per-pair cooldown** from
`WARGOAL_ADD_COOLDOWN` - a define the record said this chain does not read; `CWarGoal::RunCasusBelliOnAdd`
(rva `0x7BBE0`) runs the casus belli type's **`on_add`** effect scoped to the actor;
`CCasusBelli::RemoveFromStatus` (rva `0x649F40`) is the consumption, and its own localisation key is
**`WELOSECB`**, which is the game's own word for what was previously an inference; and
`CasusBelliTypeIsAlways` (rva `0x649EB0`) is the casus belli type's **`always`** flag, which at its
one call site **cannot change what happens**.

`0xF50A0` is not a threat adder but a **breadth-first spread over the province graph** that writes
`CDiplomacyStatus::threat`, and `EMBARGO_THREAT_COST` does reach it by address, twice - plus a third
and worse witness for trap 8's fourth case, where the define at block offset 0 is passed as the
**bare block pointer** with no `add` at all.

And `CDiplomacyStatus::LoadKey` (rva `0x648190`) turns out to be the cheapest thing in this area: ten
save keys, ten offsets, which names `+0x4C`, `+0x70`, `+0x74`, `+0x78` and `+0x7C` outright and gives
`+0x50` and `+0x54` the game's own keys.

## 22. The war-goal chain

### `CWarGoal::AddToWar` - rva `0x651FB0`

`0xA51FB0` to the single `ret 0xC` at `0xA520E5`, 8 `int3`, then a properly prologued function at
`0xA520F0`. `retsBefore` over the body is empty: no trap 2, no trap 3 funclet. **The goal arrives in
EDI** and the three stack dwords are the `CWar*`, the actor's tag by value and the actor's id. Six
callers: `0x600193`, `0x9BC92F`, `0x9BC95B`, `0x9BD63F`, `CDeclareWarAction::Apply` at `0xA12675` and
`CWarGoalBaseAction::Apply` at `0xA43647`.

    if (!CWarGoal::IsValid(goal)) return;                           // 0x479950, the only gate
    bucket = 0xA52750(war + 0x9C, &actorId);                        // per-country war-goal bucket
    0x9BE8F0(bucket@ESI, goal@EAX);                                 // append
    status = countries[actorId]->diplomacy[goal->receiver.index (+0x24)];
    status->next_wargoal_date (+0x7C) = AddMonths(tick, WARGOAL_ADD_COOLDOWN / 1000);

**This corrects the record.** `project.json`'s entry for `CWarGoalBaseAction::Apply` says
"`WARGOAL_ADD_COOLDOWN`, diplomacy `+0xFC`, is not read here". True of that body, false of the chain:
it is read at `0xA52096`, divided by 1000 with the usual `imul 0x10624DD3; sar edx, 6` (2^38 /
0x10624DD3 = 1000.0 exactly), and spent as a **month** count through `AddMonths` (rva `0xB8C90`,
already named with a signature from two readers). BlackICE's own `common/defines.lua:330` reads
`WARGOAL_ADD_COOLDOWN = 1, -- 1 month`, which is a second, independent agreement that the unit is
months.

`CWar +0x9C` is therefore a map from country id to that country's war goals. Neither `0xA52750` nor
`0x9BE8F0` is named; both are in the frontier.

### `CWarGoal::IsValid` - rva `0x79950`, the gate

`0x479950` to two bare `ret`s in one frame (`mov al, 1` at `0x479A7B`, `xor al, al` at `0x479A82`), 13
`int3`, then `CWarGoal::LoadKey` at `0x479A90` - the extent `CWarGoal.hpp` already implies. `this` in
ECX. Two callers: `0xA51FD2` and `0x89DB95`, inside the AI.

Almost the whole body is the construction of **two** `CEventScope`s on the stack (vftable `0x15B8AEC`,
persistent id `0x18D`), each stamped with the goal's `actor` (`+0x18`/`+0x1C`) and `receiver`
(`+0x20`/`+0x24`) and a null `---` tag; only the one at `esp+0x58` is used. Then three tests:

    if (this->casusBelli (+0xC) == 0)   return false;
    if (!casusBelli->slot7())           return false;   // 0xA92590 `mov al,1; ret`; ReturnFalse on CNullCasusBelliType
    return casusBelli->slot6(scope);                    // CCasusBelliType::IsValid

So **a war goal may be added exactly when it names a real casus belli type whose `is_valid = { ... }`
block passes** for a scope built from the goal's own actor and receiver. Nothing about the casus belli
the actor *holds* is tested here, which matters below.

`CCasusBelliType::IsValid` is slot 6, rva `0x16950`, seven instructions:
`add ecx, 0x30; mov eax,[ecx]; mov eax,[eax+0x18]; pop ebp; jmp eax` - a tail call into `this->+0x30`'s
`CTrigger::Evaluate`. **`CCasusBelliType +0x30` is the `is_valid` key**, save token `0x797`.
`CWarGoal.hpp` already said "0x30: a CAndTrigger, the condition under which this pretext may be used";
this names it.

### `CWarGoal::RunCasusBelliOnAdd` - rva `0x7BBE0`

`0x47BBE0` to the bare `ret` at `0x47BC5D`, `0x7E` bytes. **Only two `int3` before the next function at
`0x47BC60`** - the trap 2 shape, and `functionStart` happens to get it right only because `0x47BC60`
opens `push ebp`; `retsBefore` is what settles it. `this` in ECX. Two callers:
`CDeclareWarAction::Apply` at `0xA1267C` and `CWarGoalBaseAction::Apply` at `0xA4364E`.

It builds a `CEventScope` on its own frame - vftable `0x15B8AEC` at `[ebp-0x50]`, persistent id
`0x18D`, the war goal's **actor** tag into scope `+0x10` and index into `+0x14`, a null `---` tag at
`+0x18` - and calls **slot 11 of the object at `this->casusBelli + 0x24C`**, passing the scope by
address.

**`CCasusBelliType +0x24C` is the `on_add` key** (token `0x796`, stored by `CCasusBelliType::LoadKey`
at `0x416812`), and slot 11 of a `CEffect` is `Execute(CEventScope*, int)`, already in
`vftable_slots`. So this is *run the casus belli's `on_add = { ... }` block, scoped to the country
that took the war goal* - which is how `common/casus_belli.txt` fires effects when a goal is claimed,
and it is a hook the mod can use.

The three fields it reads are exactly the three `CWarGoal.hpp` derived independently from
`CWarGoal::LoadKey`, and wave 13 agent A's fragment names `+0x18 Actor` and `+0x20 Recipient` off the
Lua API - a third agreement.

### `CasusBelliTypeIsAlways` - rva `0x649EB0`

`0xA49EB0` to the bare `ret` at `0xA49F34`, `0x85` bytes, 11 `int3`, then `0xA49F40`. **One caller in
the image.** The type index arrives in **EDI**; nothing on the stack. It lazily creates the
casus-belli-type database at `[0x1A85BD8]` - `new(0x1C)`, the 198-database shared init `0x45BD30`, the
registrar `0x417350`; the same singleton `GetCasusBelliTypes` (rva `0x16A40`) returns - indexes its
pointer vector at `+0xC`/`+0x10` with a fallback to element 0, and returns `type->+0x1F2 != 0`.

**`CCasusBelliType +0x1F2` is the `always` key**, token `0x6A2`, through `ParseBool`. Its neighbours
are `+0x1F0` `is_triggered_only` (0x61D), `+0x1F1` `mutual` (0x78D) and `+0x1F3` `handles_peace`
(0x7B0). The name is class-free on purpose: the receiver is an index, not a `CCasusBelliType*`.

### `CCasusBelli::RemoveFromStatus` - rva `0x649F40`, and the answer

`0xA49F40` to the single `ret 8` at `0xA4A3A5`, `0x466` bytes, 8 `int3`. The casus belli arrives in
**EDI**; the stack carries the `CDiplomacyStatus*` and a **bool**.

Its tail, at `0xA4A36A`, always runs:

    status->changed (+0x59) = 1;
    unlink the node whose payload is this casus belli from status->casus_belli (+0x3C);   // CList_RemoveNode

It does **not** delete the object - the caller does, after also unlinking it from the one `CDiplomacy`
relation list at `CCurrentGameState +0xB2C`.

The other `0x430` bytes are gated on the bool and raise a message. With it true the body reads the
casus belli as a `CRelation` and raises only when `first.id == gameState->played_country_id (+0xC34)`,
`in_game (+0xDA4)` is set and `countries[second.id]->NumberOfOwnedProvinces (+0xCF8) > 0`. The keys
are **`WELOSECB`**, with `ENEMY` and `CASUS` variables.

Three callers: `CDeclareWarAction::Apply` (`0xA126AF`), `CWarGoalBaseAction::Apply` (`0xA436B5`) -
**both with the bool false**, so neither tells the player - and `CCasusBelli` slot 11 at `0xA47D54`,
the only path that can raise the message.

### So: does adding a war goal consume the casus belli that justified it?

**Yes, and it is no longer inference.** Four supports, of which the first two are new:

1. The consume step is a named function whose own localisation key is `WELOSECB` - *we lose casus
   belli*. The game's word for this path is "lose", and the function that does the losing is the one
   `CWarGoalBaseAction::Apply` calls.
2. The casus belli consumed is specifically the one that justified the goal, not any: the search key
   is `warGoal->casusBelli->index (+0x8)` matched against `CCasusBelli +0x24`, and **`CCasusBelli
   +0x24` is the `type` key** - `CCasusBelli::LoadKey` (rva `0x647910`, its one key, token `0xD9`)
   resolves the type name through the same `[0x1A85BD8]` database and stores the index there, at
   `0xA479DB`.
3. The removal and the delete were already read.
4. `always` only makes sense in a design where a casus belli is normally spent.

**And three things the chain settles that were not asked.** First, `CWarGoalBaseAction::Apply` **adds
the war goal before testing anything about held casus belli** - the add is unconditional in that body,
and the only gate is `CWarGoal::IsValid` inside `AddToWar`, which tests the *type*, not the holding.
So a war goal does not require a casus belli to be held; holding one just gets it spent.

Second, **the `always` branch is behaviourally dead at its one call site.** The body searches
`status->casus_belli` for the matching entry; on *not* finding it, it calls `CasusBelliTypeIsAlways`
and returns if false - but if true it falls into a **second, byte-identical search of the same list
for the same key**, which must also fail, and nothing between the two searches touches the list (the
only call is `CasusBelliTypeIsAlways`, which reaches nothing but the type database). Both arms do
nothing. This is read as a structural fact about the compiled code, not as a claim about the source;
the likeliest source shape is `if (found || type->always) { ... }` with an inlined finder that the
optimiser duplicated. Marked `confirmed` as a statement about the binary and nothing more.

Third, the consumption is **silent**: `notify` is false from both action paths, so the `WELOSECB`
message belongs to `CCasusBelli` slot 11 (expiry) rather than to spending one on a war goal.

## 23. `SpreadThreat` - rva `0xF50A0`, and it is not an adder

`0x4F50A0` to the single `ret 0x10` at `0x4F55F8`, `0x55B` bytes, 5 `int3`, then a
register-convention function at `0x4F5600`. Four stack dwords, nothing in a register - plain
`__stdcall`:

    void __stdcall SpreadThreat(CCountry* feared, int* amount, int* scale, CMapProvince* origin)

**Seven call sites in six functions, not the four the record says:** `0x47B280`, `0x551565`,
`0x65B64C`, `CDeclareWarAction::Apply` at `0xA128FC`, `CNapAction::Apply` at `0xA2BFFB`, and
`CEmbargoAction::Apply` **twice**, at `0xA2F099` and `0xA2F57B`. (Attributed by the known slot-7
extents, not by `functionStart`, which lands in the wrong place for both `0xA2BFFB` and the two
embargo sites - trap 2.)

What it is:

1. the base magnitude is `*amount * (1000 + feared->+0xDA8->+0x1C0) / 1000`, **halved** when slot 7 of
   `feared->faction (+0xD8)` answers false, then scaled by a float at `[0x160A7B4]`;
2. `CMapProvince +0x10` is set to 99999 on all `g_CMap (0x1A8557C) +0x21FC` provinces and
   `CCountry +0x18` is cleared on every country - distance and visited scratch. **`CMapProvince +0x10`
   is the field already recorded as `weather_pressure_distance`** from
   `CWeatherManager::PropagateHighPressure`: it is a general breadth-first scratch slot and the
   existing name is narrower than the field. `CCountry +0x18` is the per-country visited mark, so a
   country with many nearby provinces gains the threat once; it is described here and **deliberately
   not recorded**, because `+0x18` is far too common a displacement to pin from one function (trap 12);
3. the walk runs out from `origin` over `CProvinceTemplate +0x90`/`+0x94` (0x14-byte edges), decaying
   by distance, by `(1000 - feared->+0xDA8->+0x1C8)/1000`, by `*scale/1000`, and by the per-edge cost
   `0x4C4D70` returns;
4. for each province reached whose controller is unmarked:
   `controller->diplomacy[feared->id (+0xCA8)]->threat (+0x5C) += amount`, clamped at 0 from below, at
   `0x4F551B`.

So threat is felt **by** whoever holds ground near `origin`, **toward** `feared`. `CDiplomacyStatus
+0x5C` is already recorded as `threat` in thousandths from two readers; this is its writer, and it
explains the geography of threat in HoI3 - distance from the *victim's* capital, not from the
aggressor.

### Trap 8's fourth case now has three witnesses, and the third is the worst

The record's new case was: the value is never loaded, the body does `add edi, 0x60` on the register
already holding the diplomacy block and passes the **address**. Confirmed, and extended:

| class | site | what is passed as `amount` |
| --- | --- | --- |
| `CNapAction::Apply` | `0xA2BFE3`/`0xA2BFF9` | `add edi, 0x60` -> `&LEAVE_NAP_THREAT_COST` |
| `CEmbargoAction::Apply` | `0xA2F082`/`0xA2F097` | `add esi, 0x88` -> `&EMBARGO_THREAT_COST` |
| `CEmbargoAction::Apply` | `0xA2F560`/`0xA2F579` | the same, a second time |
| `CDeclareWarAction::Apply` | `0xA128BE`/`0xA128FA` | `mov eax,[eax+0xBC]` -> **the bare block pointer**, i.e. `&WARDEC_BELIGERENCY` |

**So `EMBARGO_THREAT_COST` is confirmed, at two sites** - and the trap gets a worse sub-case than the
one it was written for: when the define is at **offset 0** of its block there is no `add` to scan for
either, so even a scan for "block pointer plus a displacement passed by address" misses it.
`WARDEC_BELIGERENCY` is 25.0 in BlackICE's `defines.lua:267`, `LEAVE_NAP_THREAT_COST` 5.0 and
`EMBARGO_THREAT_COST` 1 - the embargo's tiny threat beside its `-200.0` relation hit is itself worth
noticing.

`scale` is a pointer to a stack int, 1000 in all four, i.e. x1.0 - so the parameter exists for a
caller that scales and none of these four does.

## 24. `CDiplomacyStatus::LoadKey` - ten keys, ten offsets

rva `0x648190`. This is the cheapest and most decisive thing in the area, and it was never read. Every
one of the class's save keys, with the offset the case stores to:

| key | token | offset | parsed by |
| --- | --- | --- | --- |
| `value` | 0x2A6 | -> `0xA48160`, which writes `relation (+0x38)` both ways | int |
| `military_access` | 0x2F0 | **`+0x4C`** | `sete cl` on the value token being `yes` (0x1F6) |
| `last_send_diplomat` | 0x306 | **`+0x50`** | `Date_SetFromString` |
| `last_war` | 0x305 | **`+0x54`** | `Date_SetFromString` |
| `threat` | 0x674 | `+0x5C` | `TokenToFixedPoint` (0x669550) - thousandths, as recorded |
| `debt` | 0x727 | **`+0x70`** | int |
| `dailyrepay` | 0x728 | **`+0x74`** | int |
| `debtaction_action` | 0x726 | **`+0x78`** | `ParseBool` |
| `next_wargoal_date` | 0x7A7 | **`+0x7C`** | `Date_SetFromString` |
| `occupation_policy` | 0x57C | `+0x10` | name lookup |

The last row is the **positive control**: `+0x10` was already named from this very function in
`FINDINGS-occupation.md`, so the table reproduces a known answer in the same pass.

Four notes on it:

- **`+0x4C` and `+0x78`**: wave 13 agent A independently named these `hasMilitaryAccess` and
  `allowDebts` off the Lua API (`CDiplomacyStatus::HasMilitaryAccess` rva `0x64A3F0`,
  `CDiplomacyStatus::AllowDebts` rva `0x64A7E0`, each `mov al,[ecx+N]; ret`). **Two halves of the fact
  base converging offset for offset** - trap 14's good case. Agent C dropped its two field entries in
  favour of agent A's names and folded the save keys into the function comments instead; the merge
  collision that caught this is recorded in the fragment. If the keys are wanted on the fields too,
  they want adding to agent A's two comments by hand.
- **`+0x50`** is `last_send_diplomat` to the game and `next_offer_allowed` to the record, and the code
  is on the record's side: what is stored is a date seven days in the *future*. The key is noted and
  the behavioural name kept. This closes one of section 9's open items by at least giving it the
  game's name.
- **`+0x54`** is `last_war`, which **corroborates** `war_seen_tick` rather than contradicting it: the
  game calls it the last war and the writer keeps it current while the war runs.
- **`+0x7C` is `next_wargoal_date`** and `CWarGoal::AddToWar` is its one writer - the two halves of
  section 22 meeting in the middle.

## 25. The four slot-7 bodies: what accepting actually changes

Method, since all four are too large to read whole: a linear taint pass over each extent seeded on
`[reg + 0x16C]` (the country array), `[CCountry + 0xE28]` (the diplomacy array) and the indexed loads
off each, reporting stores through a tainted register; every hit then decoded in place. **Its positive
control is `CNapAction::Apply` and `CGuarantee::Activate`**, where it returns exactly the `+0xA88`
subtract-and-clamp and the two-direction `+0x59`/`+0x1C` writes the record already documents, and
nothing else. Being linear it is not flow-sensitive, so a false positive is possible and a write
through a register it could not follow would be missed - which is why every claim below is cited by
address.

### `CDeclareWarAction::Apply` - rva `0x612030`

| where | write |
| --- | --- |
| `0xA1239F` | `status->undeclared_war (+0x24) = 0`, after deleting the `CUndeclaredWar` through its slot 0 - the formal war **replaces** the undeclared one |
| `0xA12DB6`, `0xA12DE6` | `hasMilitaryAccess (+0x4C) = 0`, **both directions**, through `SetMilitaryAccess` |
| `0xA12E10`/`0xA12E14`, `0xA12E3E`/`0xA12E42` | `changed (+0x59) = 1` and `guarantee (+0x1C) = 0`, both directions - war cancels the pair's guarantee |
| `0xA12E69`, `0xA12E96` | `allowDebts (+0x78) = 0`, both directions - war cancels the debt agreement |
| `0xA1292A`, `0xA12938` | `countries[actor]->diplo_influence (+0xA88) -= WARDEC_INFLUENCE_COST`, clamped at 0 |

It also runs the whole war-goal chain (`0xA12675`, `0xA1267C`, `0xA126AF`) and **manufactures
`CCallAllyAction` proposals** at two sites - see section 26.

### `CCallAllyAction::Apply` - rva `0x627BA0`

| where | write |
| --- | --- |
| `0xA284A2`, `0xA284B4` | `diplo_influence -= CALLALLY_INFLUENCE_COST`, clamped at 0 |
| `0xA2871B` | `status->undeclared_war (+0x24) = 0`, byte for byte the shape at `0xA12390`-`0xA1239F` |
| `0xA28891`, `0xA288C4` | `hasMilitaryAccess (+0x4C) = 0`, two statuses |
| `0xA28958` | **`CDiplomacyStatus::ClearCasusBelli`** (rva `0x64A3B0`) on `countries[...]->diplomacy[this->+0x2C]` - the status against the **third** country the action names. Joining a war empties the whole casus-belli list between those two, rather than spending one |

That last row is the sharpest contrast in this section: `CWarGoalBaseAction::Apply` spends **one**
casus belli, of the matching type; being called into a war discards **all** of them.

`ClearCasusBelli` itself (`0xA4A3B0`, `0x39` bytes, receiver in EDI, one caller) sets `changed`, frees
every **node** of `casus_belli (+0x3C)` without touching the payloads - correct ownership, since the
`CCasusBelli`s belong to the `CDiplomacy` relation list - and zeroes head, tail and count.

### `CFactionAction::Apply` - rva `0x630E70`

Its gate is now read in full, `0xA30E9D`-`0xA30F09`: `value` set; `countries[actor]->at_war (+0xACC)`
**clear**; `countries[recipient]->faction (+0xD8)->+0x28` non-null; **and then it walks that faction's
member list and requires `countries[actor]->diplomacy[member]->war (+0x20)` to be null for every
member** - a country may not join a faction while at war with any of its members. That last clause is
new.

**Its only `CCountry`/`CDiplomacyStatus` write is the influence charge**, `0xA31545`/`0xA31553`, in
`0x2157` bytes. Every other store in the body is to its own frame or to the 0x44-byte
`CMessageVariable`s it builds (verified a second way, by listing *every* memory write with its base
register's provenance - the non-stack hits are all `+0x0`/`+0x10`/`+0x14`/`+0x1C`/`+0x38`/`+0x3C`/`+0x40`
of freshly allocated 0x44-byte objects, which is `CMessageVariable`'s recorded layout). **That is a
finding, not a gap: the faction membership change is not in slot 7.** It is in `0x4F5F30`, a
~0x950-byte `__thiscall` called twice (`0xA319B2`, `0xA31AF5`) with `ECX = country->faction (+0xD8)`
and `(CCountry*, 0, 1)` on the stack, `ret 0xC`. In the frontier, and the obvious next item for anyone
who wants factions.

### `CLicenceTechnologyAction::Apply` - rva `0x63B5A0`

| where | write |
| --- | --- |
| `0xA3C38A`, `0xA3C398` | on PROPOSE (gated at `0xA3C355`), `diplo_influence -= LICENCE_INFLUENCE_COST`, clamped at 0 |
| `0xA3C5A1` | on ACCEPT, **when the pair have a debt agreement** (`allowDebts`, `+0x78`): `countries[seller]->diplomacy[buyer]->debt (+0x70) += fee` |
| `0xA3C5DE`, `0xA3C61B` | otherwise the fee moves as **money**: `-fee` and `+fee` into `CGoodsPool +0x10` of each side's pool, chosen exactly the way `GetPool` chooses it - `country->pool_in_exile (+0x9F8)` when `government_in_exile (+0x95)` is set, else `CCountry::GetActingCapitalLocation(country)` -> `CMapProvince::pool (+0x15C)` |

**So a licence is paid in cash unless the buyer holds a debt agreement with the seller, in which case
it goes on the tab** - which is what `CDiplomacyStatus::debt` is for, and the first mechanic found for
it.

And the technology-layer reach is not a technology at all: it calls `CHistoricalModel::PickBestModel`
(rva `0x183230`) once and `CHistoricalModelSet::MakeSubUnit` (rva `0x183060`) **twice**, over a loop
bounded by `[edi+0x30]`, then `CList_FreeAndClear` on what it built, plus `0x181F70`, `0x182FA0` and
`0x145760`. **A licence hands over a brigade model**, not a tech entry. The loop itself was not read.

## 26. `CCallAllyAction::CCallAllyAction` - rva `0x627AD0`, and where calls to arms come from

`0xA27AD0` to the single `ret 0x1C` at `0xA27B19`, `0x4A` bytes, 4 `int3`. The object arrives in **EAX**
and seven stack dwords follow: the date plus three `CCountryTag`s by value, which is exactly `0x1C`. It
writes the base layout of section 1 in one go - `+0x4 = 0x18D`, `+0x8`/`+0xC` actor, `+0x10`/`+0x14`
recipient, `+0x18 = 0` (PROPOSE), `+0x1C` and `+0x20` both the date, `+0x24 = 1` (value), vftable
**`0x15FB6F4`**, and `+0x28`/`+0x2C` the third country - the extra pair section 5 notes only
`CCallAllyAction` has.

Three callers, and they are the whole mechanism: **`CDeclareWarAction::Apply` builds two** (one at
`0xA12BE4`, gated on `status->war (+0x20)` being null and on the target's guarantees, with the
`new(0x30)` four instructions above it) and **`CCallAllyAction::Apply` builds one**. The date passed is
`[0x170C2B8]`, the 43,800,000-hour null date.

So declaring war is what *manufactures* the call-to-arms offers, and an ally honouring one manufactures
the next - which is how a faction is dragged into a war one country at a time, and it closes the loop
between section 5's lifecycle and the `MILALLHONOUR`/`MILALLDISHONOUR` keys.

## 27. `CRelation` and the twelve absent structs - the layouts as prose

`ghidra/mergeFindings.py` will not create a struct, and `project.json` holds **none** of `CRelation`,
`CNap`, `CAlliance`, `CGuarantee`, `CEmbargo`, `CAlign`, `CInfluence`, `CDependency`, `CCasusBelli`,
`CDiplomacy`, `CDiplomaticActionCommand` or `CNullDiplomaticAction` - re-verified 2026-10-05. So these
are hand-adds.

**`CRelation`** (vftable `0x15FBB00`, 12 slots; slots 6, 7, 10 and 11 are `_purecall`). Section 15's
prose account is now **confirmed from the game's own save grammar**, not described:
`CRelation::LoadKey` (rva `0x6465D0`, the body nine of its ten subclasses inherit) has exactly five
cases, each storing to one offset -

| offset | field | type | key |
| --- | --- | --- | --- |
| `+0x00` | vftable | | |
| `+0x04` | `persistent_id` | `int` | - (`CPersistent`'s) |
| `+0x08` | `first` | `CCountryTag` | `first` - tag at `+0x8`, id at `+0xC` |
| `+0x10` | `second` | `CCountryTag` | `second` - tag at `+0x10`, id at `+0x14` |
| `+0x18` | `start_date` | `int` (hours) | `start_date` |
| `+0x1C` | `end_date` | `int` (hours) | `end_date` |
| `+0x20` | `cancel` | `uint8_t` | `cancel`, as a `yes`/`no` token |
| `+0x24` | *subclass fields begin* | | |

The writes are at `0xA46656`/`0xA4665C`, `0xA466BE`/`0xA466C4`, `0xA466F8`, `0xA4672D` and `0xA46753`,
each ending its own `ret 8`. `+0x18 start_date` is the field `CNapAction::Apply` and
`CTradeAction::Apply` stamp from the action's own `date`, and the savegame's `diplomacy=` entries write
`first`, `second` and `start_date` for every one of the seven subclasses that appear.

**`CCasusBelli`** (vftable `0x15FBB9C`, 12 slots; slot 4 `LoadKey` `0xA47910`, slot 10 `Activate`
`0xA47BB0`, slot 11 `0xA47D20`). `CRelation`'s seven fields, then `+0x24` `type`, an `int` - the index
into the casus-belli-type database at `[0x1A85BD8]`. `CCasusBelli::LoadKey` has exactly **one** key,
`type` (token `0xD9`): it builds the string, resolves it through `0x699AC0` against that database and
stores the result at `+0x24` (`0xA479DB`). This is the field `CWarGoalBaseAction::Apply` compares
against `warGoal->casusBelli->index (+0x8)`, so the match really is "this casus belli is of the pretext
the goal names".

**`CNap`** is `0x30` bytes (`CNapAction::Apply` asks `operator new` for `0x30`), vftable `0x15FBB68`,
constructor `0xA46F00`, `Activate` `0xA471E0` - so it adds at most three dwords past `+0x24` and none
was identified. **`CTradeRoute`** is `0x88` (`CTradeAction::Apply`'s `new`), copy-constructor
`0xA4C660`, and `CTradeAction +0x28` is one embedded by value. **`CAlliance`**, **`CGuarantee`**,
**`CEmbargo`**, **`CAlign`**, **`CInfluence`** and **`CDependency`** have `Activate` bodies at
`0x646A40`, `0x646DB0`, `0x64B530`, `0x64B110`, `0x64AAD0` and `0x647760`, all already recorded, and no
fields past `+0x24` were read for any of them. The `nap` block in a save carries `balance`,
`our_power` and `their_power` beside the three `CRelation` keys, which is three subclass fields looking
for offsets - a cheap item for whoever adds the struct.

**`CDiplomacy`** is `CCurrentGameState +0xB24`; its list is at its own `+0x8`/`+0xC`/`+0x10`, i.e. game
state `+0xB2C`/`+0xB30`/`+0xB34`, nodes `0x10` bytes `{value, prev@+4, next@+8, byte@+0xC}`.
**`CDiplomaticActionCommand +0x3C`** is the held action and **`CNullDiplomaticAction +0x28`** is its own
`Hoi3CString`, both from section 9 and both still recorded nowhere.

**`CCasusBelliType`** is not in the absent list - it has a struct with one field - but it now has
twenty-two more offsets known from its loader (rva `0x165F0`): `+0x30` `is_valid` (token 0x797),
`+0x70` `is_valid_join` (0x7A8), `+0xB0` `prerequisites` (0x1FC), `+0xF0` `allowed_regions` (0x78E),
`+0x130` `allowed_province` (0x7AC), `+0x170` `allowed_countries` (0x78F), `+0x1B8`
`peace_cost_factor` (0x790), `+0x1BC` `penalty_factor` (0x791), `+0x1C0` `threat` (0x674), `+0x1D0`
`truce_months`, `+0x1E0`/`+0x1E4`/`+0x1E8` the peace-option list the `po_*` tokens append to, `+0x1F0`
`is_triggered_only` (0x61D), `+0x1F1` `mutual` (0x78D), `+0x1F2` `always` (0x6A2), `+0x1F3`
`handles_peace` (0x7B0), `+0x1F4` `truce_months` (0x792), `+0x1F8` `war_name` (0x793), `+0x214`
`country_desc` (0x794), `+0x230` `prov_desc` (0x795), `+0x24C` `on_add` (0x796), `+0x26C`
`is_civil_war` (0x79D), `+0x270` `on_completion` (0x445). **None of these were recorded** - only
`+0x30` and `+0x24C`, through the two function comments that depend on them - because the struct holds
one field and a 22-row hand-add is the collecting session's call. The token-to-body table is
reproducible in one command: byte table at `0x416924`, jump table at `0x4168E0`, base token `0x78D`.

## 28. New traps and method notes from sections 21-27

**Trap 2's second cause gains `0xC6`.** `CDiplomacyStatus::ClearCasusBelli` (rva `0x64A3B0`) has
**eight immaculate `int3`** above it and `image.functionStart(0xA4A3B0)` still answers `0xA49F40`, the
function before it, because its first byte is `0xC6` - `mov byte ptr [edi+0x59], 1`. It opens with a
store rather than a prologue precisely because its receiver is already in a register, and this image is
full of that shape, so **expect more `0xC6`**. The prologue set should become
`55 53 56 57 8B 83 81 6A 68 51 52 50 80 8A 85 33 C6`.

**And a note on the register-argument family in this corner.** Six of the ten functions read here take
their receiver in a register that is not ECX - EDI four times (`0x651FB0`, `0x649EB0`, `0x649F40`,
`0x64A3B0`), EAX once (`0x627AD0`) and CL for a bool once (`0x64A400`). `project.json`'s `@REG`
convention expresses all of them and `checkSignatures` agrees with every `ret`, but the practical
consequence is that **`functionStart` is unreliable across this whole region** and the vftable or a
caller scan is what fixes an entry.

**`0x4F50A0`'s caller count was wrong in the record** (four, against seven sites in six functions), and
both the nap and the embargo sites are ones `functionStart` misattributes. A caller list derived from
`functionStart` in a dense region should be re-derived from known extents.

## 29. What sections 21-27 skipped, and what it would cost

- **The message construction in all four slot-7 bodies.** It is most of their bulk and section 17
  already has the keys; the gates and the keys were read, not the string building.
- **`0x4F5F30`**, the ~0x950-byte faction mutation, which is where `CFactionAction`'s real effect
  lives. Read only for its convention and its arguments. The single highest-value item left.
- **`CLicenceTechnologyAction`'s model loop** (`[edi+0x30]`, `PickBestModel`, `MakeSubUnit` x2) and the
  source of the `[esp+0xf]` byte that chooses debt against cash. The branch *condition* is therefore
  read by consequence rather than read, and the fragment says so.
- **The `CDeclareWarAction` call-ally gate** - which allies get a proposal, and the role of
  `countries[...]->+0xF38`/`+0xF3C` and `status->guarantee->+0x24` in deciding. Two sites, both
  identified, neither traced.
- **`CCountry +0x18`**, the threat walk's visited mark: described, not recorded, because one function is
  not enough for a `+0x18`.
- **`CCasusBelliType`'s 22 loader offsets**: table derived and given above, nothing recorded.
- **`CCasusBelli` slot 11 (`0x647D20`)**, the only caller of `RemoveFromStatus` with `notify` true -
  i.e. the path that actually shows the player `WELOSECB`. Nothing but the call site was read; it has
  **zero callers of its own**, so it is reached virtually and the question "when does a casus belli
  expire" is still open.
- The three non-diplomatic `SpreadThreat` callers (`0x47B280`, `0x551565`, `0x65B64C`) were looked at
  only far enough to read their argument lists; `0x47B280` passes a stack int set to 1000 and a value
  read off `[esi+0xc]->+0x1C0`, which is **not** a define, so the "amount is always a define" reading
  holds only for the diplomatic four.
