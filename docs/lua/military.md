# Units, production and technology

<!-- Every name, argument and return type on this page was read out of
     hoi3_tfh.exe by reversing/ghidra/luabindExtract.py, which emulates the
     game's own luabind registration and then asks each function for its
     signature. See docs/lua/README.md for how to read it. -->

What a country builds and what it knows. The distinction to keep hold of is between a *definition* - the brigade type out of `units/`, shared by everyone - and an *instance*, one division on the map or one item in the production queue.

Types are written the way a script sees them, so the object the colon supplies is not in the argument list. **Calls in the mod** counts by method name across every `.lua` file under `script/`, so a name several classes share - `GetKey`, `IsValid`, `Create` - carries the total for all of them.

### CUnit

One formation on the map. Thin here: most of what a unit is lives on the C++ side and is not exposed to Lua.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CUnitList`](types.md#cunitlist) | `GetChildren()` | 4 |
| [`CString`](types.md#cstring) | `GetName()` |  |
| `boolean` | `IsMoving()` |  |

### CSubUnitDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `CSubUnitDataBase.GetNumberOfSubUnits()` |  |
| [`CSubUnitDefinition`](#csubunitdefinition) | `CSubUnitDataBase.GetSubUnit(string)` | 31 |
| [`CSubUnitDefinition`](#csubunitdefinition) | `CSubUnitDataBase.GetSubUnitByIndex(number)` |  |
| list of [`CSubUnitDefinition`](#csubunitdefinition) | `CSubUnitDataBase.GetSubUnitList()` | 2 |

### CSubUnitDefinition

A brigade type as declared in `units/` - `infantry_brigade` and the rest. One of these is shared by every brigade of that type.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `CanParadrop()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBuildCostIC()` | 12 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBuildCostMP()` | 12 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetBuildTime()` | 1 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCombatWidth()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCompletionSize()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDefaultStrength()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDefensivness()` |  |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| [`CString`](types.md#cstring) | `GetName()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetSoftness()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetToughness()` |  |
| `boolean` | `IsBomber()` |  |
| `boolean` | `IsBuildable()` |  |
| `boolean` | `IsCag()` | 1 |
| `boolean` | `IsCapitalShip()` | 1 |
| `boolean` | `IsCarrier()` |  |
| `boolean` | `IsRegiment()` | 1 |
| `boolean` | `IsSecondRank()` |  |
| `boolean` | `IsShip()` |  |
| `boolean` | `IsSub()` |  |
| `boolean` | `IsTransport()` | 1 |
| `boolean` | `IsValid()` | 20 |

### CBrigadeConstructionDefinition

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CSubUnitDefinition`](#csubunitdefinition) | `GetType()` | 1 |

### CSubUnitConstructionEntry

**Constructors**

- `CSubUnitConstructionEntry(CSubUnitDefinition, number, number)`

**Properties** - read as `obj.Name`, no call.

| Property | Type | Writable |
| --- | --- | --- |
| `pUnit` | [`CSubUnitDefinition`](#csubunitdefinition) | no |
| `nPrio` | `number` | no |
| `nSequence` | `number` | no |

### CConstruction

An item in the production queue.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCost()` | 5 |
| [`CMilitaryConstruction`](#cmilitaryconstruction) | `GetMilitary()` | 1 |
| `number` | `GetSize()` | 4 |
| `boolean` | `IsBuilding()` |  |
| `boolean` | `IsConvoy()` |  |
| `boolean` | `IsMilitary()` | 1 |

### CMilitaryConstruction

Inherits [`CConstruction`](#cconstruction) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| list of [`CBrigadeConstructionDefinition`](#cbrigadeconstructiondefinition) | `GetBrigades()` | 1 |
| `boolean` | `IsAir()` | 1 |
| `boolean` | `IsLand()` | 1 |
| `boolean` | `IsNaval()` | 1 |

### CConvoy

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetDesiredEscorts()` |  |
| `number` | `GetDesiredTransports()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetEfficiency()` |  |
| `boolean` | `IsForTradeRoute()` |  |

### CBuildingDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CBuilding`](#cbuilding) | `CBuildingDataBase.GetBuilding(string)` | 99 |
| [`CBuilding`](#cbuilding) | `CBuildingDataBase.GetBuildingFromIndex(number)` |  |

### CBuilding

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetName()` |  |

### CProvinceBuilding

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCurrent()` | 6 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetMax()` | 40 |

### CDistributionSetting

**Constants** - written `CDistributionSetting._PRODUCTION_LENDLEASE_` and so on.

| Constant | Value |
| --- | --- |
| `_PRODUCTION_LENDLEASE_` | 0 |
| `_PRODUCTION_CONSUMER_` | 1 |
| `_PRODUCTION_PRODUCTION_` | 2 |
| `_PRODUCTION_SUPPLY_` | 3 |
| `_PRODUCTION_REINFORCEMENT_` | 4 |
| `_PRODUCTION_UPGRADE_` | 5 |
| `_PRODUCTION_numof_` | 6 |
| `_LEADERSHIP_NCO_` | 0 |
| `_LEADERSHIP_DIPLOMACY_` | 1 |
| `_LEADERSHIP_ESPIONAGE_` | 2 |
| `_LEADERSHIP_RESEARCH_` | 3 |
| `_LEADERSHIP_numof_` | 4 |

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| [`CFixedPoint64`](types.md#cfixedpoint64) | `GetNeeded()` | 7 |  |
| [`CFixedPoint64`](types.md#cfixedpoint64) | `GetPercentage()` | 11 | Bound to `GetBasePercentage`: the share of what is currently assigned, not of what is needed. The real `GetPercentage` is not exposed. |

### CTechnologyDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| list of [`CTechnologyCategory`](#ctechnologycategory) | `CTechnologyDataBase.GetCategories()` |  |
| `number` | `CTechnologyDataBase.GetFolderIndex(string)` |  |
| `number` | `CTechnologyDataBase.GetLatestTechYear()` | 1 |
| list of [`CTechnology`](#ctechnology) | `CTechnologyDataBase.GetTechnologies()` | 2 |
| [`CTechnology`](#ctechnology) | `CTechnologyDataBase.GetTechnology(string)` | 10 |

### CTechnology

One technology from `technologies/`.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `CanResearch(CCountryTag, number)` | 1 |
| `boolean` | `CanUpgrade()` |  |
| `number` | `GetDifficulty()` |  |
| [`CTechnologyFolder`](#ctechnologyfolder) | `GetFolder()` | 2 |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| [`CTechnologyCategory`](#ctechnologycategory) | `GetOnCompletion()` |  |
| list of [`CResearchBonus`](#cresearchbonus) | `GetResearchBonus()` |  |
| `boolean` | `IsOneLevelOnly()` |  |
| `boolean` | `IsValid()` | 20 |

Operators: `__eq`.

### CNullTechnology

Inherits [`CTechnology`](#ctechnology) - everything on it works here too.

### CTechnologyStatus

What a country has researched and how far along it is.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `CanResearch(CTechnology, number)` | 1 |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetCost(CTechnology)` | 5 |
| `number` | `GetEffectiveYear(CTechnology)` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetIcModifier()` | 1 |
| `number` | `GetLevel(CTechnology)` | 22 |
| `number` | `GetYear(CTechnology, number)` | 18 |
| `boolean` | `IsBuildingAvailable(CBuilding)` | 18 |
| `boolean` | `IsSubUnitAvailable(number)` |  |
| `boolean` | `IsUnitAvailable(CSubUnitDefinition)` | 24 |

### CTechnologyFolder

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| `boolean` | `IsValid()` | 20 |

### CTechnologyCategory

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |

Operators: `__eq`.

### CResearchBonus

**Properties** - read as `obj.Name`, no call.

| Property | Type | Writable |
| --- | --- | --- |
| `_pCategory` | [`CTechnologyCategory`](#ctechnologycategory) | no |
| `_vWeight` | [`CFixedPoint`](types.md#cfixedpoint) | no |
