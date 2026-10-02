# The three leads that kept surviving

The last three items of `CANDIDATES.md`'s *What those left behind*: how five diplomatic
actions reach the mod's Lua, whether `0x4FA0B0` agrees with the alignment formulas, and what
`CDistributionSetting +8` is. Read out of the executable on 2026-10-01; nothing here needed the
game running. Addresses are virtual, based `0x400000`, with the rva beside them where a finding
names one. All three are closed, and closing them **corrected four things already in the
record** - the shape of the diplomatic-action family, the consequence of the `return 100`
short-circuit, `CTradeRoute`'s two goods blocks, and the state of `CDistributionSetting +8`,
which was never open.

Three of this file's load-bearing claims were re-checked independently against the bytes before
it was accepted into the folder, because each overturns something recorded: the `yesmen`
identification (the toggle at `0x4419D8` and the message at `0x15B8598`), `0xA438F0` being
`mov eax, 0x64; ret`, and `CDistributionSetting +0x8` already carrying a name. All three hold.

---

## 1. The five actions, and why the route looked untraceable

### The route

`FINDINGS-diplomacy.md` had the five slot-17 bodies right and concluded they "neither push a
literal nor call `0xA0DC70` within their own bodies". True. What they do instead is call a
**clone of `GetDiploScoreFromLua` with the Lua function name baked in**:

| class | slot 17 | calls | Lua function |
| --- | --- | --- | --- |
| `CRequestLendLeaseAction` | `0xA0FE20` (rva `0x60FE20`) | `0xA44690` (rva `0x644690`) | `DiploScore_RequestLendLease` |
| `CCallAllyAction` | `0xA2AC80` (rva `0x62AC80`) | `0xA44810` (rva `0x644810`) | `DiploScore_CallAlly` |
| `CLicenceTechnologyAction` | `0xA3D3F0` (rva `0x63D3F0`) | `0xA44990` (rva `0x644990`) | `DiploScore_LicenceTechnology` |
| `CJoinFactionGoalAction` | `0xA43DD0` (rva `0x643DD0`) | `0xA44B60` (rva `0x644B60`) | `DiploScore_JoinFactionGoal` |
| `CTradeAction` | `0xA38B00` (rva `0x638B00`) | `0xA0DDF0` (rva `0x60DDF0`) | `DiploScore_OfferTrade` |
| `CEmbargoAction` | `0xA438F0` (rva `0x6438F0`) | nothing | **none - returns 100** |

`CJoinFactionGoalAction` is not one of the five `CANDIDATES.md` named. It is the owner of the
fifth untraced literal, and it was invisible because it derives from `CWarGoalBaseAction`
rather than from `CDiplomaticAction` directly - see *The family is 24, not 20* below.

`CCallAllyAction`'s whole body, 0x23 bytes, is the pattern:

    mov  edx, [ecx+0x14]      push edx          the recipient tag's id
    lea  eax, [ecx+0x10]      push [eax]        the recipient tag's first dword
    push ecx                                    `this`, the action
    push eax                                    the recipient tag, by address
    push eax                                    again, as the observer
    add  ecx, 8               push ecx          the actor tag, by address
    call 0xA44810
    add  esp, 0x18

Set beside `CNapAction`'s, which `FINDINGS-diplomacy.md` prints in full, the difference is
exactly two things: the name literal is gone, and `this` has been inserted as the fourth
argument. `CJoinFactionGoalAction` pushes `this+0x28` there instead of `this`
(`lea edx, [ecx+0x28]` at `0xA43DE0`).

### Why there are clones at all, and how the match was proved

The clones are not compiler folding. Each is instruction for instruction the bridge
(`0xA0DC70`) - the same inlined lazy `CCurrentGameState` singleton on `[0x1A89790]`, the same
`return 100` short-circuit, the same three-tag `CEU3AI` lookup through `CCountryTag::GetCountry`
(`0x402610`) then `+0x1D8` - and they exist because **the Lua call takes a different number of
arguments**, so luabind's call proxy is a different template instantiation. That instantiation
is where the literal sits:

| proxy builder | literal | its one caller |
| --- | --- | --- |
| `0xA445B0` (rva `0x6445B0`) | *name is a parameter* | `0xA0DD8F`, inside the bridge |
| `0xA45510` (rva `0x645510`) | `DiploScore_RequestLendLease` | `0xA447AF`, inside `0xA44690` |
| `0xA45580` (rva `0x645580`) | `DiploScore_CallAlly` | `0xA4492F`, inside `0xA44810` |
| `0xA455F0` (rva `0x6455F0`) | `DiploScore_LicenceTechnology` | `0xA44AAF`, inside `0xA44990` |
| `0xA45660` (rva `0x645660`) | `DiploScore_JoinFactionGoal` | `0xA44C7F`, inside `0xA44B60` |
| `0xA44610` (rva `0x644610`) | `DiploScore_OfferTrade` | `0xA0DF17`, inside `0xA0DDF0` |

Those five caller addresses are the ones `FINDINGS-diplomacy.md` recorded as "exactly one
caller" of the wrappers. They are not callers of anything; each is the `call` *to* the proxy
builder from inside the clone. Read that way they lead straight home.

A proxy builder does two things: `lua_pushstring(L, name)` through `[0xD2B4E8]`, then a get on
`LUA_GLOBALSINDEX` (`0xFFFFD8EE` = -10002) through `[0xD2B45C]`; then it fills an argument list
in the proxy object starting at `+0xC` and writes a zero terminator byte after the last one.
**The argument count is readable off that terminator**, as `(offset - 0xC) / 4`, and it is the
check that proved the whole matching:

| proxy | terminator | arguments | the mod's declaration |
| --- | --- | --- | --- |
| `0xA445B0` | `+0x1C` | 4 | `DiploScore_NonAgression(voAI, voActorTag, voRecipientTag, voObserverTag)` |
| `0xA45580` | `+0x20` | 5 | `DiploScore_CallAlly(voAI, voActorTag, voRecipientTag, voObserverTag, action)` |
| `0xA44610` | `+0x28` | 7 | `DiploScore_OfferTrade(voAI, voFromTag, voToTag, voObserverTag, voTradeAction, voTradedFrom, voTradedTo)` |

Four, five and seven, against four, five and seven parameters in `ai_diplomacy.lua` and
`ai_trade.lua`. The two `_LicenceTechnology` and `_JoinFactionGoal` proxies are five-argument
like `_CallAlly`, and the mod declares five parameters for both - `voCommand` and `voWarGoal`
respectively. `DiploScore_RequestLendLease` is also passed five and declares three; Lua drops
the extras.

### `CEmbargoAction` asks nobody, and it answers yes

`0xA438F0` is `mov eax, 0x64; ret`. It sits in **two** vftable slots across two classes, and
both are slot 17 of a `CDiplomaticAction` subclass: `CEmbargoAction` (`0x15FB814`) and
`CAddWarGoalAction` (`0x15FB454`). Trap 4 says count the holders before naming a slot body, and
also says a high count is not by itself disqualifying if the holders are one family. Here the
count is two and they are one family, so the fold is narrow - but the body is still shared, so
it is recorded class-free as `ReturnOneHundred` rather than as either class's method.

The consequence is as load bearing as the hard-zero one `FINDINGS-diplomacy.md` already
records: **an embargo's and an added war goal's AI acceptance is a constant 100.** Nothing is
asked, nothing can refuse. That is why there is no `DiploScore_Embargo` literal anywhere in the
image even though the mod defines the function, and why `ai_foreign_minister.lua` has to drive
embargo decisions itself.

### `CTradeAction`, in full

The one with real logic, and the one `FINDINGS-convoys.md` got a step into. Slot 19 of
`CTradeAction` begins at `0xA38D20`, so the body is `0xA38B00`..`0xA38D1F` and the two `ret`s
inside it are early exits in the same frame, not a boundary (trap 3; the next slot's entry is
the cheap check and it was used).

    if (this->+0xC == this->+0x14)            return 100     both sides the same country
    if (!slot13(this))                        return 0       the can-offer gate
    if (!0xA390D0(this))                      return 0
    ai = countries[this->+0x14]->+0x1D8                      the *recipient's* CEU3AI
    if (ai->AlreadyTradingDisabledResource(&this->+0x28))  return 0
    copy 7 ints from [this->+0x6C] and 7 from [this->+0x5C] to floats, each / 1000.0
    return GetOfferTradeScoreFromLua(&this->+8, &this->+0x10, &this->+0x10, this,
                                     &block(0x6C), &block(0x5C), this->+0x10 by value)

Two things fall out of the second gate. **Slot 13 runs inside slot 17**, at least for this
action - `mov edx,[esi]; mov eax,[edx+0x34]; call eax` at `0xA38B20`, and vftable offset `0x34`
is slot 13. `FINDINGS-diplomacy.md` lists "whether slot 13's can-offer gate runs before or
after" as open; for `CTradeAction` it runs before, from within. And `1000.0` is the double at
`0x160A300`, so the goods values are thousandths like everything else (trap 7).

### The two `CEU3AI` trade predicates, named out of the registration

`FINDINGS-convoys.md` found two `CEU3AI` methods taking a `CTradeRoute&` and returning `bool`
and called them "the shape of the untraced route". They are not the route - they are **gates in
front of it**. Their Lua names come out of one registration call at `0x8EFC58`..`0x8EFCB3`:

| rva | virtual | the game's own Lua name |
| --- | --- | --- |
| `0x49B310` | `0x89B310` | `AlreadyTradingResourceOtherWay` |
| `0x49B3E0` | `0x89B3E0` | `AlreadyTradingDisabledResource` |
| `0x49B480` | `0x89B480` | `IsTradeingAwayNeededResource` (the misspelling is the game's) |
| `0x49B730` | `0x89B730` | `CanTradeFreeResources` |
| `0x49B790` | `0x89B790` | `IsInfluencing` |

**The pairing had to be settled, because a one-slot shift gives five different names.** The
registration pushes function and name alternately, so in argument order the list reads
`(flag, name, fn, name, fn, ...)`. Three things agree on that reading and nothing supports the
other: the alternative leaves an orphan at each end of the list; the same registration function
elsewhere pairs `'GetNeeded'` with `0x414F70`, which is nothing but `jmp [vftable+0xC]` - slot
3, which the record already says `GetNeeded` is; and the three bodies read below each do what
the name the convention gives them says.

`AlreadyTradingDisabledResource` (`0x89B3E0`) is the one `CTradeAction` calls. It fetches the
pair's `CDiplomacyStatus` as `countries[route->from_id]->+0xE28[route->to_id]`, walks the trade
routes at `CDiplomacyStatus +0x60` - a field the record already has, independently confirmed
here - and **examines only routes whose byte at `+0x54` is set** (`cmp byte [edx+0x54], 0; je`
at `0x89B425`). For each, it compares both goods blocks against the candidate's, category by
category, against the global at `[0x1B148A0]`. True makes the trade's acceptance zero.

`IsTradeingAwayNeededResource` (`0x89B480`) works out which side of the route the AI is on and
checks each good that side gives away against the country's own balance for it, returning true
when the balance is below `-[0x1B148A0]`. It is the function that settles section 3 below.

`AlreadyTradingResourceOtherWay` (`0x89B310`) compares the route's `from_id` against the AI's
own id and walks the seven goods **skipping index 2**, looking for a category the route moves
one way while the country's own tables at `CCountry +0x808` / `+0x898` already move it the
other. Why index 2 is skipped is not established.

### The family is 24, not 20

`FINDINGS-diplomacy.md` lists the 20 classes deriving from `CDiplomaticAction` directly and
notes that `CWarGoalBaseAction` is itself a base, but never enumerates its children. There are
three, and they matter. Every slot 17 in the family, read straight out of the vftables:

| slot 17 holds | classes |
| --- | --- |
| the bridge `0xA0DC70` | `CAllianceAction`, `CDebtAction`, `CFactionAction` (two sites), `CMilitaryAccessAction`, `CNapAction`, `COfferLendLeaseAction`, `COfferMilitaryAccessAction`, `CPeaceAction`, `CSendExpeditionaryForceAction` - 9 |
| a name-specialised clone | `CCallAllyAction`, `CLicenceTechnologyAction`, `CRequestLendLeaseAction`, `CJoinFactionGoalAction`, `CTradeAction` - 5 |
| `ReturnOneHundred` `0xA438F0` | `CEmbargoAction`, **`CAddWarGoalAction`** - 2 |
| `ReturnZero` `0xA80690` | `CGuaranteeAction`, `CInfluenceNation`, `CInfluenceAllianceLeader`, `CShareTechnologyAction`, `CNullDiplomaticAction`, **`CDeclareWarAction`** - 6 |
| `_purecall` `0xB961D5` | `CDiplomaticAction`, `CWarGoalBaseAction` - the two abstract bases |

22 concrete classes, 9 + 5 + 2 + 6. **The hard-zero list is six, not five**: `CDeclareWarAction`
joins it. `project.json`'s `ReturnZero` comment says five and names the five; it should say six.

And the accounting is now complete. There are exactly 14 `DiploScore_*` literals in the image;
nine reach the bridge (ten sites, `CFactionAction` pushes `DiploScore_InviteToFaction` twice)
and five reach the clones. Every one has an owner.

### What this means for the mod

`ai_diplomacy.lua`, `ai_license.lua` and `ai_trade.lua` really do decide call-ally, licence,
lend-lease requests, faction-goal joins and trade offers. The four BlackICE defines the engine
never asks for are `DiploScore_Guarantee`, `DiploScore_InfluenceNation`, `DiploScore_Embargo`
and `DiploScore_BreakAlliance` - the first two because their slot 17 is `ReturnZero`, the third
because `CEmbargoAction`'s is a constant 100, and the fourth because no action class carries
that name at all.

### The `return 100` short-circuit fires only under a cheat

`FINDINGS-diplomacy.md`: "If the acting country's id equals `g_CCurrentGameState +0xC34`
(`player`) *and* the byte at `0x1A8562F` is set, it returns **100** without calling Lua at all.
So a script's opinion of what the player is offering is never consulted down this path; what
that byte is has not been established."

The condition is right. **The byte is the `yesmen` console cheat**, rva `0x168562F`. The command
handler compares the typed word against `'yesmen'` (`0x15B8590`), tests the byte at `0x4419CA`,
toggles it with `sete al; mov byte [0x1A8562F], al` at `0x4419D8` (rva `0x419D8`), and prints
`'AI now always responds favorably'` (`0x15B8598`). Eight readers in the image; that is the only
writer. Its neighbours in the same handler are the other cheat flags - `0x1A8554F` is
`nopopup`, `0x1A855F4` is `spy`, and `0x170AD30` is the one `project.json` already names
`g_FogOfWarEnabled`, which is a useful cross-check that this is the cheat handler.

So the conclusion inverts: **in any game nobody has cheated in, the short-circuit never fires**,
and the mod's Lua is asked about the human player's offers exactly as it is about an AI's. The
sentence in `FINDINGS-diplomacy.md` should be corrected rather than just annotated, because as
written it tells a modder their script is being ignored.

### One other correction to `project.json`

`GetDiploScoreFromLua`'s recorded signature ends `CCountryTag recipient_value, int extra`.
Arguments five and six are the two dwords of one `CCountryTag` passed by value: the bridge does
`lea ecx, [ebp+0x18]; call CCountryTag::GetCountry` at `0xA0DD39`, which needs the whole eight
bytes. There is no sixth argument. The name `recipient_value` is right - `CNapAction` pushes
`[this+0x14]` then `[this+0x10]`, which is the recipient tag.

---

## 2. `0x4FA0B0` is the alignment tooltip, and it agrees

`0x4FA0B0` (rva `0xFA0B0`) runs to the `ret 8` at `0x4FBBD6`. `__stdcall`, two arguments -
`[ebp+8]` the `CCountry*` and `[ebp+0xC]` an out text object - returning the out pointer. One
caller, `0x7853FE`, which fetches the country with `CCountryTag::GetCountry` first and destroys
a local string afterwards. It is the game's own drift tooltip, and it is the second independent
derivation `FINDINGS-politics.md` wanted.

It first calls the aggregator once:

    0x4FA108  lea eax, [ecx+0xDC]            the CAlignment, embedded in CCountry
    0x4FA123  call 0x4C3200(&alignment, &point[ebp-0x108], country)

which confirms both `CAlignment` at `CCountry +0xDC` and `ComputeDrift`'s recorded
`(CAlignment*, Point*, CCountry*)` with `ret 0xC`, from a caller the politics survey never
looked at. It then recomputes each term into its own slot, and the register conventions the
record flagged as odd all reappear:

| term | called at | out slot | register convention |
| --- | --- | --- | --- |
| Relation `0x4C3950` | `0x4FA8E6` | `[ebp-0x100]` | out on the stack |
| Ideology `0x4C3B10` | `0x4FA8FB` | `[ebp-0x104]` | **out in `edi`** |
| Proximity `0x4C3C00` | `0x4FA911` | `[ebp-0xFC]` | out on the stack |
| Revanchism `0x4C3E40` | `0x4FA924` | `[ebp-0xA4]` | out on the stack |
| Threat `0x4C4120` | `0x4FA937` | `[ebp-0xD8]` | out on the stack |
| Repulsion `0x4C4380` | `0x4FA950` | `[ebp-0xDC]` | **`ecx` = `country+0xDC`** |
| AlignTowards `0x4C3790` | `0x4FA962` | `[ebp-0xA8]` | **group in `edi`** |

Then the distance gate, and the sum:

    0x4FA972  dx = group->+0x58 - country->+0xE4      the group's x minus the position's x
    0x4FA975  dy = group->+0x5C - country->+0xE8
    0x4FA98B  d2 = (dx*dx)/1000 + (dy*dy)/1000, then /1000     __allmul / __alldiv
    0x4FA9CC  call IntegerSqrt (0x46C2E0), argument in edi
    0x4FA9D1  cmp eax, 0xC8  ; jl
    0x4FA9D8      Threat     = 0      } only when the group is 200 or further away
    0x4FA9DE      Revanchism = 0      }
    0x4FA9E4      Repulsion  = 0      }
    0x4FA9EA  total =  Relation + Ideology + Proximity
    0x4FAA02          - Revanchism - Threat - Repulsion
    0x4FAA15          + AlignTowards

Every sign is the record's. The gate is the record's too, written the other way round: the
aggregator compares `dist^2 < 0x9C40` on whole units at `0x4C3361`, the tooltip takes a real
square root and compares `< 200`, and `200^2 = 40000`, so the two are the same threshold
reached by different arithmetic. `0x46C2E0` is a Newton's-method integer square root taking its
argument in `edi`, eleven callers, no vftable - the same loop `CAlignment::GetRepulsionTerm`
inlines at `0x4C4480`.

**And the tooltip names all seven terms**, with the game's own localisation keys. Each key block
is immediately preceded by a `mov edi, [ebp-X]` loading exactly the slot that term's function
wrote, so the mapping is read and not guessed:

| term | key |
| --- | --- |
| Relation | `FACTION_DRIFT_RELATIONS` (loaded at `0x4FAE4E`) |
| Proximity | `FACTION_DRIFT_PROXIMITY` (`0x4FAF33`) |
| Ideology | `FACTION_DRIFT_IDEOLOGY` (`0x4FB018`) |
| Revanchism | `FACTION_DRIFT_REVANCH_NEW` (`0x4FB0FD`) |
| Threat | `FACTION_DRIFT_THREAT` (`0x4FB26E`) |
| Repulsion | `FACTION_DRIFT_REPULSION` (`0x4FB353`) |
| AlignTowards | **`FACTION_DRIFT_INFLUENCE`** (`0x4FB438`) |
| the total | `FACTION_DRIFT_INSTANT`, with `FACTION_DRIFT_TOP_INSTANT` as the header |

The seventh is the useful one. `FINDINGS-politics.md` had to name that term from
`CFaction`'s `influence` string `align_towards_axis` and from the `ALIGN_TOWARDS` modifier it
reads; the game calls it **influence**, which settles it. The tooltip also calls the
`FACTION_STRAT_BONUS_DIST` predicate at `0x4FAC8C` and ends with a section keyed
`CAN_GIVE_STRAT_BONUS` / `CAN_GIVE_STRAT_BONUS_BUT_NONE`, plus a
`RESOURCE_BONUS_ALIGNMENT_TT` block at `0x4FA71F`.

The tooltip calling `ComputeDrift` and then recomputing every term by hand is a second
implementation of the same arithmetic, written by the same people against the same functions.
It is weaker evidence than a second *independent* implementation would be - it shares the seven
term functions - but the signs, the gate and the term-to-name mapping are the tooltip's own and
those are what was unchecked.

---

## 3. `CDistributionSetting +8` was never open

It is already named. `project.json` has `CDistributionSetting +0x8` as `base_percentage`,
sourced to `reversing/findings/FINDINGS-production.md`, and `CLASSES.md`'s *Leadership, and the four
sliders* says the same: the slider's share, the game's `GetBasePercentage`, registered to Lua as
`GetPercentage`, an `fpml::fixed_point<__int64,48,15>` so `32768` is 1. Three documents are
stale against that - `CANDIDATES.md`'s *What those left behind*, `FINDINGS-research.md`'s open
questions and `FINDINGS-techdecay.md`'s. This is trap 14 from the other direction: the check for
what already exists should be run before an item goes on the queue as well as before a name goes
in.

Checked independently rather than taken on trust. `0x4C8920` (rva `0xC8920`) is nine
instructions - copy the eight bytes at `this+8` to `*out`, return - and it is what the
registration at `0x8EC702` exposes as `GetPercentage`. No vftable holds it and nothing calls it
directly, so Lua is its only consumer, which is why the record could only name it from the
registration. The same registration call pairs `'GetNeeded'` with `0x414F70`, a bare
`jmp [vftable+0xC]` on slot 3, which is where the record independently puts `GetNeeded`.

### What was still open: requested or spent

`FINDINGS-techdecay.md` asks "which slider state the product represents - the share actually
spent, or the share requested". **Requested.** `CCountry::GetSpareICIn` (`0x4F4B90`) computes

    alloc = base_percentage(+8) x factor(+0x10) x baseIC(CCountry +0x604)
    spare = max(alloc - GetNeeded(category), 0)

so the `+8 x +0x10` product is the allocation the slider asks for, formed before need is
consulted at all, with the same `0x1F40000` and `>> 30` that turns a `1.0 = 0x8000` fixed point
into thousandths that the decay's slack term uses. The monthly decay's `slack` is therefore

    slack (thousandths) = 1000 x (upgrade share + reinforcement share)

the **positions of the Upgrade and Reinforcement sliders**, not spare capacity and not spending.
That makes `FINDINGS-techdecay.md`'s name for the term misleading: practical decay is reduced in
proportion to how much IC a country *allocates* to upgrading and reinforcing, whether or not any
of it is used, and whether or not any is needed. Since the six production shares sum to one,
`slack <= 1000` and the step can never turn positive from this term.

The ten construction sites at `0x4C9D42`..`0x4C9FBF` each set `+0x10` to `0x8000` and its high
dword to zero, so every setting starts with `factor = 1`. Whether anything ever changes it is
**not** established - a scan for writers of `+0x10` across the distribution and IC modules found
only those ten, and a bare displacement scan is trap 12, so that silence is not evidence.

---

## 4. `CTradeRoute +0x34` and `+0x44` are the wrong way round

`project.json` and `FINDINGS-convoys.md` record `CTradeRoute +0x34` as `trade_from` and `+0x44`
as `trade_to`, both explicitly **"Inferred, not proven"**, placed by the order of the keys in
`CTradeRoute::LoadKey` and of the two blocks the constructor zeroes. The convoys note adds a
doubt: "three dwords is the shape of a vector header, not of seven values, so either this is a
`std::vector<CFixedPoint>` of seven or the values sit elsewhere."

Both halves of that are now settled, and the second one says the names are swapped.

**The shape.** `+0x34` and `+0x44` are vector headers; the first dword of each is a pointer to
**exactly seven** four-byte values, one per goods category, thousandths.
`CTradeAction::GetAIAcceptance` dereferences both and reads indices 0..6 at four-byte stride
(`0xA38B70`..`0xA38C16` and `0xA38C1B`..`0xA38CD4`), dividing each by `1000.0`, and
`CEU3AI::IsTradeingAwayNeededResource` indexes them the same way.

**The direction.** Two independent readings, both pointing the other way:

- `CEU3AI::IsTradeingAwayNeededResource` splits on which side of the route the AI is. On the
  branch where the AI is the `from` side (`route->+0x28 == this->+0x24`, tested at `0x89B4A2`)
  the goods it is giving away come from **`+0x44`** (`0x89B4A9`). On the branch where it is the
  `to` side (`route->+0x30`, `0x89B4EC`) they come from **`+0x34`** (`0x89B4F3`). What the
  `from` side gives away is what `trade_from` means.
- `CTradeAction::GetAIAcceptance` hands Lua the `+0x44` block as the sixth argument and the
  `+0x34` block as the seventh, and `ai_trade.lua` declares those parameters
  `voTradedFrom, voTradedTo`.

So `+0x34` is `trade_to` and `+0x44` is `trade_from`. Reported here rather than changed:
`buildFindings.py` refuses to overwrite an existing name, and in this case the collision is the
point. The confirmation worth having is live and cheap - a savegame's `trade={...}` block names
`trade_from` and `trade_to` in plain text, so one `dumpStruct.py` against a live `CTradeRoute`
whose save entry is known decides it in a minute.

The same two functions give three fields that were not recorded. `CTradeAction +0x28` is the
`CTradeRoute`, **embedded rather than pointed at**: the action passes `this+0x28` as the
`const CTradeRoute&` argument at `0xA38B60`, and reads the route's two blocks as `this+0x5C` and
`this+0x6C`, which are `0x28 + 0x34` and `0x28 + 0x44`. `CTradeRoute +0x54` is the byte flag
`AlreadyTradingDisabledResource` filters on. `CEU3AI +0x20` is the AI's own `CCountryTag` with
the id at `+0x24`, read by both predicates.

---

## 5. How the negatives were controlled

Three scans produced negative or near-negative results here, and each was run against a known
positive in the same code first.

- **The caller scan** (`scratchpad/survivors/callers.py`, every `call rel32` whose target
  matches) reports zero callers for all six slot-17 bodies. That is the right answer - they are
  reached through the vftable - but the scan has to be shown able to see a call at all. Against
  `GetDiploScoreFromLua` it finds **ten** sites in nine functions, which is exactly the nine
  actions `FINDINGS-diplomacy.md` lists with `CFactionAction` counted twice, and it finds one
  caller for each of the six proxy builders and five clones, every one of which was then
  confirmed in the disassembly.
- **The vftable-slot scan** (`whoslot.py`, over the RTTI export) reports two holders for
  `0xA438F0`. Run against `0xA80690` it reproduces `TRAPS.md`'s own figure, 189 slots across 81
  classes, exactly.
- **The Lua-name scan** found no registration helper baking in `0x89B3E0`, which is why the name
  had to come from a push sequence instead. The same scan finds `'GetCountry'` for `0x8888B0`,
  so its silence was about the shape of the registration, not about the function - and the push
  sequence was then pinned by three separate arguments rather than by locality alone.

Two decodes in this work started from guessed addresses and desynchronised into confident
nonsense (trap 9) - `0x8EFC60` printed `retf 0x15e` out of a `push`, and `0x4FA860` printed
`add byte ptr [ebx + 0x3059390F]`. Both were redone by decoding forward from the function entry,
and the second reading is the one used above. Nothing in this file rests on a decode that did
not start at a function entry or at an address a tool printed.

---

## What is not established

- **Which of the two `bool CEU3AI::(const CTradeRoute&)` luabind registrations is which
  function.** Three of the five trade predicates take a route by const reference and `ret 4`
  (`0x89B310`, `0x89B3E0`, `0x89B480`), but only two registrations carry that exact mangled
  signature. The third takes something else or is registered under a signature not looked for.
- **The bodies of `CanTradeFreeResources` (`0x89B730`) and `IsInfluencing` (`0x89B790`).** Named
  from the registration only, and recorded `likely` for that reason.
- **Why `AlreadyTradingResourceOtherWay` skips goods index 2** (`cmp esi, 2; je` at `0x89B333`
  and `0x89B388`), and what `CCountry +0x808` and `+0x898` are - two per-goods arrays it reads
  that nothing in the record names.
- **`CTradeAction` slot 13 (`0xA38770`) and `0xA390D0`**, the two gates ahead of the Lua call.
  Both were read far enough to see they return bool and that a false answer stops the trade;
  neither was read through. Slot 13's identity across the family is still open - this only shows
  that `CTradeAction`'s slot 17 calls it.
- **`CTradeRoute +0x34` / `+0x44`'s direction, finally.** Two static readings agree they are
  swapped in the record; the decisive check is a savegame against a live route and was not run.
- **Whether `CDistributionSetting +0x10` is ever anything but 1.** Ten construction sites set it
  to 1 and a bounded scan for writers found nothing else, which under trap 12 is not evidence.
  If it is always 1, the decay's slack term is exactly the sum of two slider positions; if not,
  it is that sum scaled.
- **What sets `CDiplomacyStatus +0x60`'s routes' `+0x54` flag.** No writer was looked for, so the
  name `disabled` rests on the registered function's own word.
- **The out object `CAlignment::BuildDriftTooltip` fills** (`[ebp+0xC]`, 0x5C bytes, three
  0x1C-byte string slots), and which screen reads it. Its one caller, inside the function that
  begins somewhere before `0x7853C0`, was not identified - `functionStart` lands at `0x784E30`
  with two `ret`s in between, so that boundary wants the trap-2 check before anything is said
  about it.
- **The remaining nine slot-17 names.** `CDiplomaticAction::IsValid` is also registered with
  luabind and also resolves to `_purecall`, so which of the ten pure slots the other nine names
  belong to is as open as it was.
- Nothing in this file was checked against a running game. It is all static reading.
