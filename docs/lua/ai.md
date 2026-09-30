# The AI objects

<!-- Every name, argument and return type on this page was read out of
     hoi3_tfh.exe by reversing/ghidra/luabindExtract.py, which emulates the
     game's own luabind registration and then asks each function for its
     signature. See docs/lua/README.md for how to read it. -->

What the engine hands a `_Tick` function. `CAI` is the AI as a whole, one per game; an agent is one minister of one country. See [the overview](README.md#where-the-engine-calls-in) for when each is called.

Types are written the way a script sees them, so the object the colon supplies is not in the argument list. **Calls in the mod** counts by method name across every `.lua` file under `script/`, so a name several classes share - `GetKey`, `IsValid`, `Create` - carries the total for all of them.

### CAI

The AI as a whole, one per game. Registered in C++ as `CEU3AI`, which is the name that turns up in its own signatures.

**Constants** - written `CAI._DIPLOMACY_` and so on.

| Constant | Value |
| --- | --- |
| `_DIPLOMACY_` | 0 |
| `_PRODUCTION_` | 1 |
| `_TECHNOLOGY_` | 2 |
| `_POLITICS_` | 3 |
| `_INTELLIGENCE_` | 4 |

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| `boolean` | `AlreadyTradingDisabledResource(CTradeRoute)` | 2 |  |
| `boolean` | `AlreadyTradingResourceOtherWay(CTradeRoute)` |  |  |
| `boolean` | `CalculateFriendOfFaction(CCountry, CFaction)` |  |  |
| `boolean` | `CanDeclareWar(CCountryTag, CCountryTag)` | 1 |  |
| `boolean` | `CanTradeFreeResources(CCountryTag, CCountryTag)` | 1 |  |
| `number` | `EvaluateCancelTrades(number, GoodsCategory)` | 1 |  |
| `number` | `CAI.FastNormalizeByPriority(lua_State, SLIDER_AUTOMATION_LEVEL, number, number, number, number, number, number)` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetAmountTradedFrom(GoodsCategory, CCountryTag, CCountryTag)` |  |  |
| [`CString`](types.md#cstring) | `CAI.GetCommonModDirectory()` |  |  |
| [`CCountry`](world.md#ccountry) | `GetCountry()` | 381 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCountryAlignmentDistance(CCountry, CCountry)` | 7 |  |
| [`CEU3Date`](types.md#ceu3date) | `GetCurrentDate()` | 51 |  |
| [`CArrayInt`](types.md#carrayint) | `GetDeployedSubUnitCounts()` | 2 |  |
| [`CString`](types.md#cstring) | `CAI.GetModDirectory()` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetNormalizedAlignmentDistance(CCountry, CFaction)` |  |  |
| `number` | `GetNumberOfOwnedProvinces(CCountryTag)` | 3 |  |
| [`CArrayInt`](types.md#carrayint) | `GetProductionSubUnitCounts()` | 1 |  |
| [`CDiplomacyStatus`](world.md#cdiplomacystatus) | `GetRelation(CCountryTag, CCountryTag)` | 98 |  |
| [`CList_CSubUnitConstructionEntry`](types.md#clist_csubunitconstructionentry) | `GetReqProdQueue()` |  |  |
| [`CList_CSubUnitConstructionEntry`](types.md#clist_csubunitconstructionentry) | `GetReqProdQueueIter()` |  |  |
| `number` | `GetSpamPenalty(CCountryTag)` | 2 |  |
| [`CArrayInt`](types.md#carrayint) | `GetTheatreSubUnitNeedCounts()` | 1 |  |
| `boolean` | `CAI.HasCommonExtension()` |  |  |
| `boolean` | `HasFilledProdQueue()` |  |  |
| `boolean` | `HasTradeGoneStale(CTradeRoute)` | 2 |  |
| `boolean` | `CAI.HasUserExtension()` |  |  |
| `boolean` | `CAI.IsAIControlledForPlayer(CHuman::AUTOMATIONTYPE)` |  | Bound to `IsAIControlled`. |
| `boolean` | `IsInfluencing(CCountryTag, CCountryTag)` |  |  |
| `boolean` | `IsTradeingAwayNeededResource(CTradeRoute)` |  |  |
| - | `MoveUnit(CUnit, number, number, boolean, boolean, CAIAgent)` |  |  |
| - | `Post(CCommand)` | 127 |  |
| - | `PostAction(CDiplomaticAction)` | 19 |  |
| - | `PrintConsole(string)` |  |  |
| - | `RequestSubUnit(CSubUnitDefinition, number, number)` |  |  |

### CAISubscriber

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `WantTicks()` |  |

### CAIAgent

One minister of one country - the object a `_Tick` function is handed.

Inherits [`CAISubscriber`](#caisubscriber) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountry`](world.md#ccountry) | `GetCountry()` | 381 |
| [`CCountryTag`](types.md#ccountrytag) | `GetCountryTag()` | 61 |

### CAIForeignMinister

Inherits [`CAIAgent`](#caiagent) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| - | `ClearWarProposal()` |  |
| - | `ExecuteDiploDecisions()` | 1 |
| [`CAI`](#cai) | `GetOwnerAI()` | 37 |
| [`CCountryTag`](types.md#ccountrytag) | `GetProposedWarTarget()` |  |
| `number` | `PercOccupied(CCountryTag)` |  |
| - | `Propose(CDiplomaticAction, number)` | 15 |
| - | `ProposeWar(CCountryTag, number)` |  |

### CAIProductionMinister

Inherits [`CAIAgent`](#caiagent) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `CountEscortsUnderConstruction()` | 1 |
| `number` | `CountTotalDesiredEscorts()` |  |
| `number` | `CountTransportsUnderConstruction()` | 1 |
| `number` | `GetDesperation()` |  |
| [`CAI`](#cai) | `GetOwnerAI()` | 37 |
| - | `PrioritizeBuildQueue()` | 1 |

### CAITechMinister

Inherits [`CAIAgent`](#caiagent) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `CanResearch(CTechnology)` | 1 |
| [`CArrayFloat`](types.md#carrayfloat) | `GetFolderModifers()` |  |
| [`CAI`](#cai) | `GetOwnerAI()` | 37 |
| [`CArrayFloat`](types.md#carrayfloat) | `GetTechModifers()` |  |

### CAIPoliticsMinister

Inherits [`CAIAgent`](#caiagent) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CAI`](#cai) | `GetOwnerAI()` | 37 |
| `boolean` | `IsCapitalSafeToLiberate(CCountryTag)` | 3 |

### CAIEspionageMinister

Inherits [`CAIAgent`](#caiagent) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CAI`](#cai) | `GetOwnerAI()` | 37 |
| `boolean` | `IsAligningToFaction()` |  |

### CAIStrategy

A country's AI file from `common/ai/`: its personality and its stances toward other countries.

**Constants** - written `CAIStrategy._AI_UNDEFINED_` and so on.

| Constant | Value |
| --- | --- |
| `_AI_UNDEFINED_` | 0 |
| `_AI_MILITARIST_` | 1 |
| `_AI_INDUSTRIALIST_` | 2 |
| `_AI_DIPLOMAT_` | 3 |
| `_AI_BALANCED_` | 4 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| - | `AddSubUnit(CSubUnitDefinition, number)` |  |
| - | `CancelPrepareWar(CCountryTag)` |  |
| `number` | `GetAccessScore(CCountryTag)` |  |
| `number` | `GetAntagonism(CCountryTag)` | 8 |
| [`CCountry`](world.md#ccountry) | `GetCountry()` | 381 |
| [`CCountryTag`](types.md#ccountrytag) | `GetCountryTag()` | 61 |
| `number` | `GetFriendliness(CCountryTag)` | 8 |
| [`AIPersonality` constant](#caistrategy) | `GetPersonality()` | 2 |
| `number` | `GetProtectionism(CCountryTag)` | 1 |
| list of [`CTheatre`](world.md#ctheatre) | `GetTheatres()` |  |
| `number` | `GetThreat(CCountryTag)` | 15 |
| `number` | `GetWantedSubUnits(CSubUnitDefinition)` |  |
| `number` | `GetWarScoreWith(CCountryTag)` |  |
| `CCountryWarTargetValue` | `GetWarTarget(CCountryTag)` |  |
| `list of CCountryWarTargetValue` | `GetWarTargets()` |  |
| `boolean` | `IsBalanced()` |  |
| `boolean` | `IsDiplomat()` |  |
| `boolean` | `IsIndustrialist()` |  |
| `boolean` | `IsMilitarist()` | 1 |
| `boolean` | `IsPreparingWar()` | 5 |
| `boolean` | `IsPreparingWarWith(CCountryTag)` | 4 |
| - | `PrepareLimitedWar(CCountryTag, number)` | 15 |
| - | `PrepareWar(CCountryTag, number)` | 6 |
| - | `PrepareWarDecision(CCountryTag, number, CDecision, boolean)` | 7 |

### CAIIntel

What one country believes about another, rather than what is true.

**Constructors**

- `CAIIntel(CCountryTag, CCountryTag)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `CalculateOurMilitaryStrength()` | 2 |
| `number` | `CalculateTheirPercievedMilitaryStrengh()` | 2 |
| `number` | `GetFactor()` | 2 |
| `number` | `GetTheirFactor()` |  |
| `number` | `GetUncertaintyFactor()` |  |
| `boolean` | `HasNoIntel()` |  |

### SpyMission

**Constants** - written `SpyMission.SPYMISSION_COUNTER_ESPIONAGE` and so on.

| Constant | Value |
| --- | --- |
| `SPYMISSION_COUNTER_ESPIONAGE` | 0 |
| `SPYMISSION_MILITARY` | 1 |
| `SPYMISSION_TECH` | 2 |
| `SPYMISSION_BOOST_RULING_PARTY` | 3 |
| `SPYMISSION_BOOST_OUR_PARTY` | 4 |
| `SPYMISSION_LOWER_NATIONAL_UNITY` | 5 |
| `SPYMISSION_INCREASE_THREAT` | 6 |
| `SPYMISSION_RAISE_NATIONAL_UNITY` | 7 |
| `SPYMISSION_COVERT_OPS` | 8 |
| `SPYMISSION_MAX` | 9 |
