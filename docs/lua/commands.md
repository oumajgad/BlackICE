# Commands and diplomatic actions

<!-- Every name, argument and return type on this page was read out of
     hoi3_tfh.exe by reversing/ghidra/luabindExtract.py, which emulates the
     game's own luabind registration and then asks each function for its
     signature. See docs/lua/README.md for how to read it. -->

Nothing in the Lua API changes the world by itself. To make something happen you build a command and post it - see [the overview](README.md#nothing-happens-until-you-post-it). Diplomatic actions are the offers one country makes another; the `DiploScore_` callbacks are handed one and answer with a number.

Types are written the way a script sees them, so the object the colon supplies is not in the argument list. **Calls in the mod** counts by method name across every `.lua` file under `script/`, so a name several classes share - `GetKey`, `IsValid`, `Create` - carries the total for all of them.

### CDebtAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CDebtAction(CCountryTag, CCountryTag)`

### CLicenceTechnologyAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CLicenceTechnologyAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMoney()` | 1 |
| `number` | `GetParalell()` | 1 |
| `number` | `GetSerial()` | 1 |
| [`CSubUnitDefinition`](military.md#csubunitdefinition) | `GetSubunit()` | 1 |
| - | `SetMoney(CFixedPoint)` | 1 |
| - | `SetParallel(number)` | 1 |
| - | `SetSerial(number)` | 1 |
| - | `SetSubunit(CSubUnitDefinition)` | 1 |

### CSendExpeditionaryForceAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CSendExpeditionaryForceAction(CCountryTag, CCountryTag)`

**Constants** - written `CSendExpeditionaryForceAction.TAKE` and so on.

| Constant | Value |
| --- | --- |
| `TAKE` | 0 |
| `SEND` | 1 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`ClaimType` constant](#csendexpeditionaryforceaction) | `GetClaimType()` |  |
| [`CString`](types.md#cstring) | `GetTag()` | 344 |
| [`CUnit`](military.md#cunit) | `GetUnit()` |  |

### CPeaceAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CPeaceAction(CCountryTag, CCountryTag)`

### CChangeUndergroundMission

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeUndergroundMission(number, EUndergroundAction)`

### CConstructConvoyCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CConstructConvoyCommand(CCountryTag, boolean, number)`

### CToggleMobilizationCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CToggleMobilizationCommand(CCountryTag, boolean)`

### CCreateVassalCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CCreateVassalCommand(CCountryTag, CCountryTag)`

### CLiberateCountryCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CLiberateCountryCommand(CCountryTag, CCountryTag)`

### CChangeMinisterCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeMinisterCommand(CCountryTag, CMinister, CGovernmentPosition)`

### CChangeLawCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeLawCommand(CCountryTag, CLaw, CLawGroup)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| - | `SetEnablePostMessage(boolean)` | 1 |

### CStartResearchCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CStartResearchCommand(CCountryTag, CTechnology)`

### CChangeSpyMission

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeSpyMission(CCountryTag, CCountryTag, SpyMission, number)`

### CChangeSpyPriority

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeSpyPriority(CCountryTag, CCountryTag, number)`

### CConstructBuildingCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CConstructBuildingCommand(CCountryTag, CBuilding, number, number)`

### CChangeLeadershipCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeLeadershipCommand(CCountryTag, number, number, number, number)`

### CChangeInvestmentCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeInvestmentCommand(CCountryTag, number, number, number, number, number, number)`

### CSetVariableCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CSetVariableCommand(CCountryTag, CString, CFixedPoint)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CSetFlagCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CSetFlagCommand(CCountryTag, CString, boolean)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CChangeLendLeaseDistributionCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangeLendLeaseDistributionCommand(CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |
| - | `SetData(CArrayCountryTag, CArrayFix)` | 2 |

### CUpgradeRegimentCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CUpgradeRegimentCommand(CSubUnit, number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CChangePriorityCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CChangePriorityCommand(CCountryTag, CID, number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CCancelUnitConstructionCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CCancelUnitConstructionCommand(CCountryTag, CID)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CConstructUnitCommand

Inherits [`CCommand`](#ccommand) - everything on it works here too.

**Constructors**

- `CConstructUnitCommand(CCountryTag, list of CSubUnitDefinition, number, number, boolean, CCountryTag, CID)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CConstructSingleUnitCommand

**There is no way to make one.** Its constructor is commented out in the game's own registration, nothing returns one, and no call takes one - so `Clone`, the only method it has, can never be reached. Use [`CConstructUnitCommand`](#cconstructunitcommand), which takes the same arguments plus a trailing `CID`.

Inherits [`CCommand`](#ccommand) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCommand`](#ccommand) | `Clone(CString)` |  |

### CCommand

The base of everything that can be posted. See the note at the top of this page.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `IsValid()` | 20 |

### CFactionAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CFactionAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFactionAction`](#cfactionaction) | `CFactionAction.Create(CCountryTag, CCountryTag)` |  |

### CEmbargoAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CEmbargoAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CEmbargoAction`](#cembargoaction) | `CEmbargoAction.Create(CCountryTag, CCountryTag)` |  |

### CInfluenceAllianceLeader

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CInfluenceAllianceLeader(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CInfluenceAllianceLeader`](#cinfluenceallianceleader) | `CInfluenceAllianceLeader.Create(CCountryTag, CCountryTag)` |  |

### CNapAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CNapAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CNapAction`](#cnapaction) | `CNapAction.Create(CCountryTag, CCountryTag)` |  |

### COfferLendLeaseAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `COfferLendLeaseAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CRequestLendLeaseAction`](#crequestlendleaseaction) | `COfferLendLeaseAction.Create(CCountryTag, CCountryTag)` |  |

### CRequestLendLeaseAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CRequestLendLeaseAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CRequestLendLeaseAction`](#crequestlendleaseaction) | `CRequestLendLeaseAction.Create(CCountryTag, CCountryTag)` |  |

### CCallAllyAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CCallAllyAction(CCountryTag, CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCallAllyAction`](#ccallallyaction) | `CCallAllyAction.Create(CCountryTag, CCountryTag, CCountryTag)` |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetVersus()` |  |
| - | `SetVersus(CCountryTag)` |  |

### COfferMilitaryAccessAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `COfferMilitaryAccessAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`COfferMilitaryAccessAction`](#coffermilitaryaccessaction) | `COfferMilitaryAccessAction.Create(CCountryTag, CCountryTag)` |  |

### CAllianceAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CAllianceAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CAllianceAction`](#callianceaction) | `CAllianceAction.Create(CCountryTag, CCountryTag)` |  |

### CMilitaryAccessAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CMilitaryAccessAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CMilitaryAccessAction`](#cmilitaryaccessaction) | `CMilitaryAccessAction.Create(CCountryTag, CCountryTag)` |  |

### CInfluenceNation

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CInfluenceNation(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CInfluenceNation`](#cinfluencenation) | `CInfluenceNation.Create(CCountryTag, CCountryTag)` |  |

### CGuaranteeAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CGuaranteeAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CGuaranteeAction`](#cguaranteeaction) | `CGuaranteeAction.Create(CCountryTag, CCountryTag)` |  |

### CDeclareWarAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CDeclareWarAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CDeclareWarAction`](#cdeclarewaraction) | `CDeclareWarAction.Create(CCountryTag, CCountryTag)` |  |

### CTradeAction

Inherits [`CDiplomaticAction`](#cdiplomaticaction) - everything on it works here too.

**Constructors**

- `CTradeAction(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CTradeAction`](#ctradeaction) | `CTradeAction.Create(CCountryTag, CCountryTag)` |  |
| [`CTradeRoute`](world.md#ctraderoute) | `GetRoute()` | 3 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetTrading(GoodsCategory, CCountryTag)` | 2 |
| `boolean` | `IsConvoyPossible()` |  |
| - | `SetRoute(CTradeRoute)` | 7 |
| - | `SetTrading(CFixedPoint, GoodsCategory)` | 4 |

### CDiplomaticAction

The base of every offer one country makes another.

**Constants** - written `CDiplomaticAction.PROPOSE` and so on.

| Constant | Value |
| --- | --- |
| `PROPOSE` | 0 |
| `DECLINE` | 1 |
| `ACCEPT` | 2 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetAIAcceptance()` | 2 |
| [`EType` constant](#cdiplomaticaction) | `GetType()` | 1 |
| `boolean` | `GetValue()` | 48 |
| `boolean` | `IsSelectable()` | 32 |
| `boolean` | `IsValid()` | 20 |
| - | `SetValue(boolean)` | 156 |
