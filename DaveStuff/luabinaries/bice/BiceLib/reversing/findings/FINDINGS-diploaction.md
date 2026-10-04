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
- **Slot 7, the per-class effect**, was not read in any class. It is the agreement actually
  happening and it is the single biggest thing left here: `0x00A352F0` for `CTradeAction`,
  `0x00A2B090` for `CNapAction`, `0x00A435F0` for the war-goal base, and twenty-one more.
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
