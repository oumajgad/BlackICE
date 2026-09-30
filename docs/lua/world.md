# The world

<!-- Every name, argument and return type on this page was read out of
     hoi3_tfh.exe by reversing/ghidra/luabindExtract.py, which emulates the
     game's own luabind registration and then asks each function for its
     signature. See docs/lua/README.md for how to read it. -->

The game state itself - the countries, the map, and the relations between them. `CCurrentGameState` is the way in: almost every script starts by asking it for a date, a country or a province.

Types are written the way a script sees them, so the object the colon supplies is not in the argument list. **Calls in the mod** counts by method name across every `.lua` file under `script/`, so a name several classes share - `GetKey`, `IsValid`, `Create` - carries the total for all of them.

### CCurrentGameState

The game itself. Static, so it is called with a dot rather than a colon: `CCurrentGameState.GetCurrentDate()`. This is where a script starts.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `CCurrentGameState.GetAIRand()` | 6 |
| list of [`CCountry`](#ccountry) | `CCurrentGameState.GetCountries()` | 11 |
| [`CEU3Date`](types.md#ceu3date) | `CCurrentGameState.GetCurrentDate()` | 51 |
| [`CFaction`](#cfaction) | `CCurrentGameState.GetFaction(string)` | 228 |
| list of [`CFaction`](#cfaction) | `CCurrentGameState.GetFactions()` | 4 |
| [`CCurrentGameState`](#ccurrentgamestate) | `GetInstance()` |  |
| [`CCountryTag`](types.md#ccountrytag) | `CCurrentGameState.GetPlayer()` | 12 |
| [`CProvince`](#cprovince) | `CCurrentGameState.GetProvince(number)` | 56 |
| `boolean` | `CCurrentGameState.IsGlobalFlagSet(CString)` |  |
| `boolean` | `CCurrentGameState.IsPlayer(CCountryTag)` | 5 |
| - | `CCurrentGameState.Post(CCommand)` | 127 |

### CCountryDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountryTag`](types.md#ccountrytag) | `CCountryDataBase.GetTag(string)` | 344 |

### CCountry

One country, and by far the largest class here. A `CCountryTag` is turned into one of these with `tag:GetCountry()`.

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| `number` | `AICalculateExpense(GoodsCategory)` |  |  |
| list of [`CTradeRoute`](#ctraderoute) | `AIGetTradeRoutes()` | 2 |  |
| [`CIdeologyData`](politics.md#cideologydata) | `AccessIdeologyOrganization()` |  |  |
| [`CIdeologyData`](politics.md#cideologydata) | `AccessIdeologyPopularity()` | 3 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `CalcDesperation()` | 4 |  |
| `boolean` | `CalculateIsAllied(CCountryTag)` | 1 |  |
| `number` | `CalculateNumberOfActiveInfluences()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `CalculateReinforcementMultiplier()` | 1 |  |
| `boolean` | `CanBreakNAPWith(CCountryTag)` |  |  |
| `boolean` | `CanCreatePuppet()` | 1 | Bound to `MayReleaseVassals`. |
| `number` | `CountMaxUnitsStillBuildable(CSubUnitDefinition)` | 1 |  |
| `boolean` | `Exists()` | 21 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetAbility(CTechnologyCategory)` |  |  |
| [`CProvince`](#cprovince) | `GetActingCapitalLocation()` | 17 |  |
| list of [`CProvince`](#cprovince) | `GetAirBases()` |  |  |
| [`CAlignment`](#calignment) | `GetAlignment()` |  |  |
| `CPoint<CFixedPoint>` | `GetAlignmentCord()` |  |  |
| [`CCountryList`](types.md#ccountrylist) | `GetAllies()` | 6 |  |
| `number` | `GetAllowedResearchSlots()` | 1 |  |
| `boolean` | `GetAreActingCapitalsOnSameContinent(CCountry)` |  |  |
| `number` | `GetAvailableIC()` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBuildCost(CBuilding)` | 5 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBuildCostIC(CSubUnitDefinition, number, boolean)` | 12 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBuildCostMP(CSubUnitDefinition, boolean)` | 12 |  |
| `number` | `GetBuildTime(CSubUnitDefinition, number)` | 1 |  |
| `number` | `GetCapital()` |  | Bound to `GetActingCapital`, so it follows the capital when the real one is lost. |
| [`CProvince`](#cprovince) | `GetCapitalLocation()` | 9 |  |
| list of [`CConstruction`](military.md#cconstruction) | `GetConstructions()` | 1 |  |
| `list of number` | `GetControlledProvinces()` | 9 |  |
| [`CCountryList`](types.md#ccountrylist) | `GetControllerNeighbours()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetConvoyBuildCost()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetConvoyBuildTime()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetConvoyedIn()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetConvoyedOut()` |  |  |
| list of [`CConvoy`](military.md#cconvoy) | `GetConvoys()` |  |  |
| `list of number` | `GetCoreProvinces()` |  |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetCountryTag()` | 61 |  |
| [`CCountryList`](types.md#ccountrylist) | `GetCurrentAtWarWith()` | 3 |  |
| list of [`CTechnology`](military.md#ctechnology) | `GetCurrentResearch()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDailyBalance(GoodsCategory)` | 16 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDailyExpense(GoodsCategory)` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDailyIncome(GoodsCategory)` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDailyNeed(GoodsCategory)` |  |  |
| list of [`CDiplomacyStatus`](#cdiplomacystatus) | `GetDiplomacy()` | 10 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDiplomaticDistance(CCountryTag)` | 3 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDiplomaticInfluence()` | 2 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDissent()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetEffectiveNeutrality()` | 6 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetEscortBuildCost()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetEscortBuildTime()` |  |  |
| `number` | `GetEscorts()` | 1 |  |
| [`CFaction`](#cfaction) | `GetFaction()` | 228 |  |
| [`CFlags`](types.md#cflags) | `GetFlags()` | 35 |  |
| [`CModifier`](#cmodifier) | `GetGlobalModifier()` | 7 |  |
| [`CGovernment`](politics.md#cgovernment) | `GetGovernment()` | 2 |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetHighestThreat()` |  |  |
| list of [`CMinister`](politics.md#cminister) | `GetHistoricalMinisters()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetHomeProduced()` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetICPart(ProductionCategory)` | 2 |  |
| [`CLaw`](politics.md#claw) | `GetLaw(CLawGroup)` | 21 |  |
| [`CLaw`](politics.md#claw) | `GetLawFromIndex(number)` |  | Bound to `GetLaw`. |
| [`CDistributionSetting`](military.md#cdistributionsetting) | `GetLeadershipDistributionAt(number)` | 5 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetManpower()` | 4 |  |
| `number` | `GetMaxIC()` | 10 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMaxLendLease()` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMaxLendLeaseFraction()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMaxNeutralityForWarWith(CCountryTag)` | 3 |  |
| [`CMinister`](politics.md#cminister) | `GetMinister(CGovernmentPosition)` | 1 |  |
| list of [`CMinister`](politics.md#cminister) | `GetMinisters()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMoneyBalanceAverage()` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetNationalUnity()` | 1 |  |
| list of [`CProvince`](#cprovince) | `GetNavalBases()` |  |  |
| [`CCountryList`](types.md#ccountrylist) | `GetNeighbours()` | 8 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetNeutrality()` | 7 |  |
| `number` | `GetNumOfAirfields()` | 2 |  |
| `number` | `GetNumOfAllies()` | 1 |  |
| `number` | `GetNumOfPorts()` | 2 |  |
| `number` | `GetNumberOfControlledProvinces()` | 5 |  |
| `number` | `GetNumberOfCurrentResearch()` | 1 |  |
| `number` | `GetNumberOfFreeSpies()` | 3 |  |
| `number` | `GetNumberOfOwnedProvinces()` | 3 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetOfficerRatio()` | 2 |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetOverlord()` | 6 |  |
| `list of number` | `GetOwnedProvinces()` | 1 |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetPool()` | 23 |  |
| [`CCountryList`](types.md#ccountrylist) | `GetPossibleLiberations()` | 3 |  |
| list of [`CMinister`](politics.md#cminister) | `GetPossibleMinisters()` | 1 |  |
| [`CCountryList`](types.md#ccountrylist) | `GetPossiblePuppets()` | 2 | Bound to `GetPossibleVassals`. |
| [`CDistributionSetting`](military.md#cdistributionsetting) | `GetProductionDistributionAt(number)` | 13 |  |
| `number` | `GetRandomUnderGroundTarget()` | 1 |  |
| [`CDiplomacyStatus`](#cdiplomacystatus) | `GetRelation(CCountryTag)` | 98 |  |
| [`CRule`](#crule) | `GetRules()` |  |  |
| [`CIdeology`](politics.md#cideology) | `GetRulingIdeology()` | 26 |  |
| [`CSpyPresence`](#cspypresence) | `GetSpyPresence(CCountryTag)` | 7 |  |
| [`CCountryList`](types.md#ccountrylist) | `GetSpyingOnUs()` | 1 |  |
| [`CStrategicWarfare`](#cstrategicwarfare) | `GetStrategicWarfare()` |  |  |
| [`CAIStrategy`](ai.md#caistrategy) | `GetStrategy()` | 10 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetSupplyBalanceAverage()` |  |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetSurrenderLevel()` | 4 |  |
| [`CTechnologyStatus`](military.md#ctechnologystatus) | `GetTechnologyStatus()` | 15 |  |
| `number` | `GetTotalConvoyTransports()` | 1 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetTotalCoreBuildingLevels(number)` | 3 |  |
| `number` | `GetTotalIC()` | 15 |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetTotalLeadership()` | 2 |  |
| `number` | `GetTotalNeededConvoyTransports()` | 1 |  |
| `number` | `GetTotalNeededTransports()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetTotalProduced()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetTradedAway()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetTradedAwaySansAlliedSupply()` | 3 |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetTradedFor()` |  |  |
| [`CGoodsPool`](types.md#cgoodspool) | `GetTradedForSansAlliedSupply()` | 5 |  |
| `number` | `GetTransports()` | 1 |  |
| [`CUnitList`](types.md#cunitlist) | `GetUnits()` | 6 |  |
| [`CUnitList`](types.md#cunitlist) | `GetUnitsIterator()` |  | Bound to `GetUnits`. |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetUsedIC()` | 1 |  |
| [`CVariables`](types.md#cvariables) | `GetVariables()` | 71 |  |
| [`CCountryList`](types.md#ccountrylist) | `GetVassals()` | 2 |  |
| `boolean` | `HasActiveLendLeaseFrom(CCountryTag)` | 1 |  |
| `boolean` | `HasActiveLendLeaseFromAnyone()` |  |  |
| `boolean` | `HasActiveLendLeaseToAnyone()` | 1 |  |
| `boolean` | `HasConstruction()` |  |  |
| `boolean` | `HasDiplomatEnroute(CCountryTag)` | 4 |  |
| `boolean` | `HasExtraManpowerLeft()` | 1 |  |
| `boolean` | `HasFaction()` | 21 |  |
| `boolean` | `HasIncomingTradeOffer()` |  |  |
| `boolean` | `HasNeighborInFaction(CFaction)` | 1 |  |
| `boolean` | `IsAtWar()` | 50 |  |
| `boolean` | `IsBuildingAllowed(CBuilding, CProvince)` |  |  |
| `boolean` | `IsEnemy(CCountryTag)` | 2 |  |
| `boolean` | `IsFactionLeader()` |  |  |
| `boolean` | `IsFriend(CCountryTag, boolean)` | 18 |  |
| `boolean` | `IsGivingLendLeaseToTarget(CCountryTag)` | 1 |  |
| `boolean` | `IsGovernmentInExile()` | 11 |  |
| `boolean` | `IsLandSafeToJoin(CFaction)` | 1 |  |
| `boolean` | `IsMajor()` | 14 |  |
| `boolean` | `IsMobilized()` | 2 |  |
| `boolean` | `IsNeighbour(CCountryTag)` | 2 |  |
| `boolean` | `IsNeighbourToFactionHostile(CFaction, boolean)` |  |  |
| `boolean` | `IsNonExileNeighbour(CCountryTag)` | 12 |  |
| `boolean` | `IsPuppet()` | 22 | Bound to `IsSubject` - true for any subject, not only puppets. |
| `boolean` | `IsSubject()` | 1 |  |
| `boolean` | `IsUnitsAvailable(CSubUnitDefinition, number)` |  |  |
| `boolean` | `MayLiberateCountries()` | 3 |  |
| `boolean` | `NeedConvoyToTradeWith(CCountryTag)` | 1 |  |

### CProvince

One province on the map.

**Constants** - written `CProvince.UNDERGROUND_ACTION_PARTISAN` and so on.

| Constant | Value |
| --- | --- |
| `UNDERGROUND_ACTION_PARTISAN` | 0 |
| `UNDERGROUND_ACTION_SPREAD` | 1 |
| `UNDERGROUND_ACTION_NONE` | 2 |
| `MAX_UNDERGROUND_ACTION` | 3 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CProvinceBuilding`](military.md#cprovincebuilding) | `GetBuilding(CBuilding)` | 99 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCachedTotalSuppression()` |  |
| `number` | `GetCoastalFortLevel()` |  |
| [`CContinent`](#ccontinent) | `GetContinent()` | 25 |
| [`CCountryTag`](types.md#ccountrytag) | `GetController()` | 43 |
| `number` | `GetCurrentConstructionLevel(CBuilding)` | 24 |
| `number` | `GetFortLevel()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetInfrastructure()` |  |
| [`IntelLevel` constant](#cspypresence) | `GetIntelLevel(CCountryTag)` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMaxInfrastructure()` |  |
| `number` | `GetNumberOfUnits()` | 1 |
| [`CCountryTag`](types.md#ccountrytag) | `GetOwner()` | 9 |
| `number` | `GetProvinceID()` | 1 |
| [`EUndergroundAction` constant](#cprovince) | `GetUnderGroundAction()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetUndergroundLevel()` |  |
| [`CUnitList`](types.md#cunitlist) | `GetUnits()` | 6 |
| `boolean` | `HasAdjacentEnemyOrCB(CCountryTag)` |  |
| `boolean` | `HasBuilding(CBuilding)` | 3 |
| `boolean` | `HasUnderGround()` |  |
| `boolean` | `IsFrontProvince(boolean)` | 1 |

### CRegion

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |  |
| [`CArrayInt`](types.md#carrayint) | `GetProvinceIter()` |  | Iterates province ids, not provinces. |
| `boolean` | `UseForPeace()` |  |  |

### CContinent

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CString`](types.md#cstring) | `GetName()` |  |
| [`CString`](types.md#cstring) | `GetTag()` | 344 |

Operators: `__eq`.

### CTheatre

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetPriority()` | 2 |

### CFaction

An alliance - Allies, Axis, Comintern, or one made during the game.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountryTag`](types.md#ccountrytag) | `GetFactionLeader()` | 19 |
| [`CIdeologyGroup`](politics.md#cideologygroup) | `GetIdeologyGroup()` |  |
| [`CCountryList`](types.md#ccountrylist) | `GetMembers()` | 1 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetNormalizedProgress()` |  |
| `number` | `GetNumberOfMembers()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetProgress()` |  |
| [`CString`](types.md#cstring) | `GetTag()` | 344 |
| `boolean` | `IsValid()` | 20 |

Operators: `__eq`.

### CAlignment

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDistanceFrom(CIdeologyGroup)` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetLastDrift(CIdeologyGroup)` |  |

### CWar

One war, with its participants on each side.

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| [`CArrayCountryTag`](types.md#carraycountrytag) | `GetAttackers()` |  |  |
| `number` | `GetCurrentRunningTimeInMonths()` |  | Always 0 - an `active_war` carries no dates in the save. |
| [`CArrayCountryTag`](types.md#carraycountrytag) | `GetDefenders()` |  |  |
| [`CEU3Date`](types.md#ceu3date) | `GetStartDate()` |  | Always 365 days after day 0 - an `active_war` carries no dates in the save. |
| `boolean` | `IsLimited()` | 4 |  |
| `boolean` | `IsPartOfWar(CCountryTag)` |  |  |

### CWarGoal

A claim one country has on another: who, against whom, and under which casus belli. One of the few classes a script builds itself.

**Constructors**

- `CWarGoal()`
- `CWarGoal(CCountryTag, CCountryTag, CString)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountryTag`](types.md#ccountrytag) | `GetActor()` |  |
| [`CString`](types.md#cstring) | `GetCBTypeTag()` |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetCountry()` | 381 |
| [`CCountryTag`](types.md#ccountrytag) | `GetRecipient()` |  |
| [`CRegion`](#cregion) | `GetRegion()` |  |
| `boolean` | `HasRegion()` |  |
| `boolean` | `IsCivilWar()` |  |
| `boolean` | `IsValid()` | 20 |
| `boolean` | `IsValidWithTrigger()` |  |
| - | `SetCountry(CCountryTag)` |  |
| - | `SetRegion(CRegion)` |  |

Operators: `__eq`.

### CDiplomacyStatus

Everything between two countries - relations, access, guarantees, trade agreements.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `AllowDebts()` | 5 |
| `number` | `GetFloatValue()` |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetTarget()` | 10 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetThreat()` | 15 |
| list of [`CTradeRoute`](#ctraderoute) | `GetTradeRoutes()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetValue()` | 48 |
| [`CWar`](#cwar) | `GetWar()` | 3 |
| `boolean` | `HasAlliance()` | 7 |
| `boolean` | `HasAnyAgreement()` | 10 |
| `boolean` | `HasEmbargo()` | 5 |
| `boolean` | `HasFriendlyAgreement()` | 4 |
| `boolean` | `HasHostileAgreement(CCountryTag, CCountryTag)` |  |
| `boolean` | `HasMilitaryAccess()` | 5 |
| `boolean` | `HasNap()` | 2 |
| `boolean` | `HasTruce()` | 1 |
| `boolean` | `HasWar()` | 70 |
| `boolean` | `IsAligning()` | 2 |
| `boolean` | `IsBeingInfluenced()` | 2 |
| `boolean` | `IsFightingWarTogether()` | 2 |
| `boolean` | `IsGuaranteed()` | 4 |
| `boolean` | `IsGuaranting()` | 1 |

### CTradeRoute

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountryTag`](types.md#ccountrytag) | `GetConvoyResponsible()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `CTradeRoute.GetCost(GoodsCategory, CFixedPoint, CCountryTag, CCountryTag)` | 5 |
| [`CCountryTag`](types.md#ccountrytag) | `GetFrom()` | 13 |
| [`CEU3Date`](types.md#ceu3date) | `GetLastInactive()` |  |
| [`CCountryTag`](types.md#ccountrytag) | `GetTo()` | 13 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetTradedFromOf(GoodsCategory)` | 14 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetTradedToOf(GoodsCategory)` | 15 |
| `boolean` | `IsInactive()` | 2 |
| `boolean` | `IsValid()` | 20 |

### CStrategicWarfare

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetAlliesImpact()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBombingImpact()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetConvoyImpact()` |  |

### CSpyPresence

**Constants** - written `CSpyPresence.MAX_SPY_PRIORITY` and so on.

| Constant | Value |
| --- | --- |
| `MAX_SPY_PRIORITY` | 3 |
| `MAX_SPY_LEVEL` | 10 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CEU3Date`](types.md#ceu3date) | `GetLastMissionChangeDate()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetLevel()` | 22 |
| `number` | `GetMissionPriority(SpyMission)` | 1 |
| [`SpyMission`](ai.md#spymission) | `GetPrimaryMission()` | 3 |
| `number` | `GetPriority()` | 2 |
| `boolean` | `CSpyPresence.MissionAllowed(SpyMission, CCountryTag, CCountryTag)` |  |

### CModifier

**Constants** - written `CModifier._MODIFIER_MINIMUM_REVOLT_RISK_` and so on.

| Constant | Value |
| --- | --- |
| `_MODIFIER_MINIMUM_REVOLT_RISK_` | 0 |
| `_MODIFIER_LOCAL_REVOLT_RISK_` | 1 |
| `_MODIFIER_GLOBAL_REVOLT_RISK_` | 2 |
| `_MODIFIER_LOCAL_MANPOWER_` | 3 |
| `_MODIFIER_GLOBAL_MANPOWER_` | 4 |
| `_MODIFIER_LOCAL_MANPOWER_MODIFIER_` | 5 |
| `_MODIFIER_GLOBAL_MANPOWER_MODIFIER_` | 6 |
| `_MODIFIER_ATTRITION_` | 7 |
| `_MODIFIER_WAR_EXHAUSTION_` | 8 |
| `_MODIFIER_MAX_WAR_EXHAUSTION_` | 9 |
| `_MODIFIER_FORT_LEVEL_` | 10 |
| `_MODIFIER_COASTAL_FORT_LEVEL_` | 11 |
| `_MODIFIER_INFRASTRUCTURE_` | 12 |
| `_MODIFIER_LOCAL_INFRASTRUCTURE_` | 13 |
| `_MODIFIER_GLOBAL_INFRASTRUCTURE_` | 14 |
| `_MODIFIER_IC_` | 15 |
| `_MODIFIER_LOCAL_IC_` | 16 |
| `_MODIFIER_GLOBAL_IC_` | 17 |
| `_MODIFIER_LOCAL_CRUDE_OIL_` | 18 |
| `_MODIFIER_GLOBAL_CRUDE_OIL_` | 19 |
| `_MODIFIER_LOCAL_ENERGY_` | 20 |
| `_MODIFIER_GLOBAL_ENERGY_` | 21 |
| `_MODIFIER_LOCAL_METAL_` | 22 |
| `_MODIFIER_GLOBAL_METAL_` | 23 |
| `_MODIFIER_LOCAL_RARE_MATERIALS_` | 24 |
| `_MODIFIER_GLOBAL_RARE_MATERIALS_` | 25 |
| `_MODIFIER_LOCAL_SUPPLIES_` | 26 |
| `_MODIFIER_GLOBAL_SUPPLIES_` | 27 |
| `_MODIFIER_LOCAL_FUEL_` | 28 |
| `_MODIFIER_GLOBAL_FUEL_` | 29 |
| `_MODIFIER_LOCAL_MONEY_` | 30 |
| `_MODIFIER_GLOBAL_MONEY_` | 31 |
| `_MODIFIER_LOCAL_LEADERSHIP_` | 32 |
| `_MODIFIER_GLOBAL_LEADERSHIP_` | 33 |
| `_MODIFIER_LOCAL_LEADERSHIP_MODIFIER_` | 34 |
| `_MODIFIER_GLOBAL_LEADERSHIP_MODIFIER_` | 35 |
| `_MODIFIER_DRIFT_SPEED_` | 36 |
| `_MODIFIER_SUSEPTIBILITY_` | 37 |
| `_MODIFIER_INCORPORATE_COST_` | 38 |
| `_MODIFIER_TERRITORIAL_PRIDE_` | 39 |
| `_MODIFIER_WAR_CONSUMER_GOODS_DEMAND_` | 40 |
| `_MODIFIER_PEACE_CONSUMER_GOODS_DEMAND_` | 41 |
| `_MODIFIER_ESPIONAGE_BONUS_` | 42 |
| `_MODIFIER_DISSENT_` | 43 |
| `_MODIFIER_NATIONAL_UNITY_` | 44 |
| `_MODIFIER_NAVAL_CAPACITY_` | 45 |
| `_MODIFIER_AIR_CAPACITY_` | 46 |
| `_MODIFIER_ALIGN_TOWARDS_` | 47 |
| `_MODIFIER_RADAR_LEVEL_` | 48 |
| `_MODIFIER_SUPPLY_CONSUMPTION_` | 49 |
| `_MODIFIER_PEACETIME_MANPOWER_ROTATION_` | 50 |
| `_MODIFIER_UNIT_RECRUITMENT_TIME_` | 51 |
| `_MODIFIER_UNIT_START_EXPERIENCE_` | 52 |
| `_MODIFIER_UNIT_REPAIR_` | 53 |
| `_MODIFIER_COUNTER_INTELLIGENCE_` | 54 |
| `_MODIFIER_COUNTER_ESPIONAGE_` | 55 |
| `_MODIFIER_THREAT_IMPACT_` | 56 |
| `_MODIFIER_PEACE_OFFMAP_INTEL_` | 58 |
| `_MODIFIER_OFFMAP_LAND_INTEL_` | 59 |
| `_MODIFIER_OFFMAP_NAVAL_INTEL_` | 60 |
| `_MODIFIER_OFFMAP_INDUSTRY_INTEL_` | 61 |
| `_MODIFIER_OFFMAP_POLITICAL_INTEL_` | 62 |
| `_MODIFIER_COMBAT_MOVEMENT_SPEED_` | 63 |
| `_MODIFIER_ATTACK_REINFORCE_CHANCE_` | 64 |
| `_MODIFIER_DEFEND_REINFORCE_CHANCE_` | 65 |
| `_MODIFIER_COMBAT_WIDTH_` | 66 |
| `_MODIFIER_ORG_REGAIN_` | 67 |
| `_MODIFIER_NATIONAL_UNITY_EFFECT_` | 68 |
| `_MODIFIER_RULING_PARTY_SUPPORT_` | 69 |
| `_MODIFIER_LAND_ORGANISATION_` | 70 |
| `_MODIFIER_AIR_ORGANISATION_` | 71 |
| `_MODIFIER_NAVAL_ORGANISATION_` | 72 |
| `_MODIFIER_RESEARCH_EFFICIENCY_` | 73 |
| `_MODIFIER_INDUSTRIAL_EFFICIENCY_` | 74 |
| `_MODIFIER_LOCAL_ANTI_AIR_` | 75 |
| `_MODIFIER_LOCAL_PARTISAN_SUPPORT_` | 76 |
| `_MODIFIER_RESERVES_PENALTY_SIZE_` | 77 |
| `_MODIFIER_NEUTRALITY_CHANGE_` | 78 |
| `_MODIFIER_PARTISAN_EFFICENCY_` | 79 |
| `_MODIFIER_NAVAL_BASE_EFFICIENCY_` | 80 |
| `_MODIFIER_SUPPLY_THROUGHPUT_` | 81 |
| `_MODIFIER_OFFICER_RECRUITMENT_` | 82 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetValue(ModifierType)` | 48 |

### CEventScope

The country and province an event or decision is being evaluated for, as handed to `ForeignMinister_EvaluateDecision`.

**Properties** - read as `obj.Name`, no call.

| Property | Type | Writable |
| --- | --- | --- |
| `_Country` | [`CCountryTag`](types.md#ccountrytag) | yes |
| `_nProvince` | `number` | yes |

### CDecision

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| `boolean` | `IsAllowed(CEventScope)` |  |
| `boolean` | `IsPotential(CEventScope)` |  |

### CRule

**Constants** - written `CRule._RULE_NONE_` and so on.

| Constant | Value |
| --- | --- |
| `_RULE_NONE_` | 0 |
| `_RULE_LIMITED_WAR_` | 1 |
| `_RULE_ALLIANCE_GUARANTEE_` | 2 |
| `_RULE_FREE_RESOURCE_GIFTS_` | 3 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `GetValue(RuleType)` | 48 |
