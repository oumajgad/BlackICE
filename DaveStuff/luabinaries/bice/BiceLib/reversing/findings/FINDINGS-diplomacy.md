# How the engine asks the mod's Lua whether the AI accepts

`script/ai_diplomacy.lua` has been part of BlackICE for years and nothing in this folder
mentioned the engine side of it. This is that side. Read out of the executable on 2026-09-30;
addresses are virtual, based `0x400000`, with the rva where a finding names one.

## `CDiplomaticAction` is an interface with ten pure virtuals

Vftable `0x15FB1D4`, 22 slots, of which **ten are `_purecall` in the base**: 7, 11, 12, 13, 15,
16, 17, 18, 19 and 20. Twenty classes derive from it directly:

    CAllianceAction        CCallAllyAction       CDebtAction         CEmbargoAction
    CFactionAction         CGuaranteeAction      CInfluenceAllianceLeader
    CInfluenceNation       CLicenceTechnologyAction                  CMilitaryAccessAction
    CNapAction             CNullDiplomaticAction COfferLendLeaseAction
    COfferMilitaryAccessAction                   CPeaceAction        CRequestLendLeaseAction
    CSendExpeditionaryForceAction                CShareTechnologyAction
    CTradeAction           CWarGoalBaseAction

Nineteen of them fill all ten slots. `CNullDiplomaticAction` is the null-object of the set, and
`CWarGoalBaseAction` leaves slot 17 pure - it is itself a base, for the war-goal actions.

## Slot 17 is `GetAIAcceptance`

**The name is the game's own.** `CDiplomaticAction::GetAIAcceptance` is registered with luabind,
and because the method is pure virtual in the class that declares it the registration resolves
to `_purecall` - which is why `project.json` records the name against that stub rather than
against any code. Which of the ten pure slots it is cannot be read from the registration, since
all ten resolve to the same address. **Slot 17 is it by behaviour**: the slot computes an
integer opinion of a proposed action by asking Lua, which is what the name says. Treat the slot
number as a strong inference and the name as certain.

## The bridge - `GetDiploScoreFromLua`, `0xA0DC70` / rva `0x60DC70`

Six arguments, `cdecl` (each caller does `add esp, 0x18`), returning the score in `eax`. The
first argument is the name of a Lua function; the rest are the tags involved.

After the usual lazy creation of the `CCurrentGameState` singleton, it does three things.

**It short-circuits for the human player, but only under a cheat.** If the acting country's
id equals `g_CCurrentGameState +0xC34` (`player`) *and* the byte at `0x1A8562F` is set, it
returns **100** without calling Lua at all.

**`0x1A8562F` is the `yesmen` console cheat** (rva `0x168562F`), identified 2026-10-01 and
re-checked against the bytes. The console handler compares the typed word against `'yesmen'`
(`0x15B8590`), tests the byte at `0x4419CA`, toggles it with
`sete al; mov byte ptr [0x1A8562F], al` at `0x4419D8`, and prints
*'AI now always responds favorably'* (`0x15B8598`). Eight readers in the image and that is the
only writer; its neighbours in the same handler are the other cheat flags, including the one
`project.json` already names `g_FogOfWarEnabled`.

**So this paragraph used to say the opposite of the truth.** It read "a script's opinion of what
the player is offering is never consulted down this path". In any game nobody has cheated in the
short-circuit never fires, and the mod's Lua is asked about a human's offers exactly as it is
about an AI's. See `FINDINGS-survivors.md`.

**It finds an AI to hand to the script**, as `CCountry +0x1D8`, trying three tags in turn and
taking the first non-null: the recipient, then the actor, then the recipient again through its
other pointer. Each lookup is `CCountryTag::GetCountry` (`0x402610`, already named) followed by
`+0x1D8`.

**Then it calls Lua** - `0xA445B0` with the AI pointer, the tags and the function name, and
`0xA44080` to turn the result into an int. Neither of those two is named yet.

`CCountry +0x1D8` is the country's `CEU3AI*` on two independent lines of evidence: this
function hands it to Lua where every `DiploScore_*` function's first parameter is `voAI`, and
`0x66196F` passes the same field to the AI agent update loop at `0x8894E0`.

## Which actions actually ask, and which do not

The nine that ask push their own literal and call the bridge inside slot 17:

| class | slot 17 | Lua function |
| --- | --- | --- |
| `CAllianceAction` | `0xA1BA70` | `DiploScore_Alliance` |
| `CDebtAction` | `0xA3F330` | `DiploScore_Debt` |
| `CFactionAction` | `0xA34860` | `DiploScore_InviteToFaction`, pushed at two sites |
| `CMilitaryAccessAction` | `0xA25610` | `DiploScore_DemandMilitaryAccess` |
| `CNapAction` | `0xA2E3D0` | `DiploScore_NonAgression` |
| `COfferLendLeaseAction` | `0xA116C0` | `DiploScore_OfferLendLease` |
| `COfferMilitaryAccessAction` | `0xA278E0` | `DiploScore_OfferMilitaryAccess` |
| `CPeaceAction` | `0xA41D50` | `DiploScore_PeaceAction` |
| `CSendExpeditionaryForceAction` | `0xA3AF90` | `DiploScore_SendExpeditionaryForce` |

**Five share one function that returns zero.** `CGuaranteeAction`, `CInfluenceNation`,
`CInfluenceAllianceLeader`, `CShareTechnologyAction` and `CNullDiplomaticAction` all point slot
17 at `0xA80690`, whose entire body is `xor eax, eax; ret`.

That is **not** a diplomacy function: it appears in **189 vftable slots across 81 classes**, so
it is the shared stub the compiler folds every trivial `return 0` onto. But the consequence for
these five is real - their AI acceptance is a hard zero and no script is consulted.

**It explains something on the Lua side.** The mod defines four `DiploScore_*` functions the
engine never names: `DiploScore_Guarantee` and `DiploScore_InfluenceNation` - two of exactly
these five - plus `DiploScore_Embargo` and `DiploScore_BreakAlliance`. All four are called from
`ai_foreign_minister.lua` rather than by the engine, and their signatures differ accordingly
(`voForeignMinisterData` instead of an actor/recipient/observer triple). So the mod drives those
decisions itself, which is the only way it could: asking the engine would always return zero.

**Five more have real bodies that do not reach the bridge directly.** `CCallAllyAction`
(`0xA2AC80`), `CEmbargoAction` (`0xA438F0`), `CLicenceTechnologyAction` (`0xA3D3F0`),
`CRequestLendLeaseAction` (`0xA0FE20`) and `CTradeAction` (`0xA38B00`) neither push a literal
nor call `0xA0DC70` within their own bodies. The remaining five literals -
`DiploScore_CallAlly`, `DiploScore_JoinFactionGoal`, `DiploScore_LicenceTechnology`,
`DiploScore_RequestLendLease` and `DiploScore_OfferTrade` - are pushed from a cluster of small
wrappers in the luabind glue region around `0xA444xx`-`0xA44Cxx`, each with exactly one caller
(`0xA4492F`, `0xA44C7F`, `0xA44AAF`, `0xA447AF` and a site inside `0xA4462B`). **How those
wrappers are reached from the actions has not been traced** and is the obvious next step.

## The literal census

Exactly **14** `DiploScore_*` strings exist in the image, and all 14 are defined in the mod:
twelve in `script/ai_diplomacy.lua`, `DiploScore_OfferTrade` in `ai_trade.lua` and
`DiploScore_LicenceTechnology` in `ai_license.lua`. Nothing the engine asks for is missing - a
worthwhile thing to have checked, since a missing one would fail silently.

## One action's slot 17, in full

`CNapAction::GetAIAcceptance`, 0x27 bytes, which is the whole pattern:

    mov  edx, [ecx+0x14]        push  edx            the recipient tag, by value
    lea  eax, [ecx+0x10]        push  [eax]          "
    push eax                                         the recipient tag, by address
    push eax                                         again
    add  ecx, 8                 push  ecx            the actor tag, by address
    push 0x15FAB54                                   'DiploScore_NonAgression'
    call 0xA0DC70
    add  esp, 0x18

So the action's own layout is `+0x8` the actor tag and `+0x10` the recipient tag, matching what
the loader places, and the score comes straight back in `eax` with no post-processing.

## What is not established

- Which of the ten pure slots the other nine names belong to. `CDiplomaticAction::IsValid` is
  also registered with luabind and also resolves to `_purecall`.
- ~~How `CCallAllyAction`, `CEmbargoAction`, `CLicenceTechnologyAction`,
  `CRequestLendLeaseAction` and `CTradeAction` reach their Lua wrappers.~~ **Closed
  2026-10-01** (`FINDINGS-survivors.md`): four of them call a **name-specialised clone** of
  `GetDiploScoreFromLua` with the Lua function name baked into luabind's call proxy, which is
  why no literal appears in the slot body. `CEmbargoAction` calls nothing - its slot 17 is
  `mov eax, 0x64; ret`, a **constant 100**, shared with `CAddWarGoalAction`. A fifth clone
  belongs to `CJoinFactionGoalAction`, which this file never enumerated because it derives from
  `CWarGoalBaseAction` rather than from `CDiplomaticAction` directly - **the family is 24
  classes, not 20**, and the hard-zero list is **six**, not five: `CDeclareWarAction` joins it.
- ~~The byte at `0x1A8562F` that gates the `return 100` short-circuit.~~ **Closed: it is the
  `yesmen` cheat** - see above.
- `0xA445B0` and `0xA44080`, the luabind call and the result conversion.
- What the engine does with the score - the thresholds an action is accepted at, and whether
  slot 13's can-offer gate runs before or after.
- Slot 11 reads the diplomacy defines, per the survey that found this; not confirmed here.
