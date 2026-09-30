# Government, laws and ministers

<!-- Every name, argument and return type on this page was read out of
     hoi3_tfh.exe by reversing/ghidra/luabindExtract.py, which emulates the
     game's own luabind registration and then asks each function for its
     signature. See docs/lua/README.md for how to read it. -->

The domestic side: who is in the cabinet, what the laws are set to, and where the country sits ideologically.

Types are written the way a script sees them, so the object the colon supplies is not in the argument list. **Calls in the mod** counts by method name across every `.lua` file under `script/`, so a name several classes share - `GetKey`, `IsValid`, `Create` - carries the total for all of them.

### CGovernment

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `IsValid()` | 20 |

Operators: `__eq`.

### CGovernmentPositionDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CGovernmentPosition`](#cgovernmentposition) | `CGovernmentPositionDataBase.GetGovernmentPosition(string)` |  |
| [`CGovernmentPosition`](#cgovernmentposition) | `CGovernmentPositionDataBase.GetGovernmentPositionByIndex(number)` | 2 |
| list of [`CGovernmentPosition`](#cgovernmentposition) | `CGovernmentPositionDataBase.GetGovernmentPositionList()` |  |
| `number` | `CGovernmentPositionDataBase.GetNumberOfGovernmentPositions()` |  |

### CGovernmentPosition

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| `boolean` | `IsChangeable()` |  |

### CMinisterTypeDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CMinisterType`](#cministertype) | `CMinisterTypeDataBase.GetMinisterType(string)` |  |
| list of [`CMinisterType`](#cministertype) | `CMinisterTypeDataBase.GetMinisterTypeList()` | 1 |
| `number` | `CMinisterTypeDataBase.GetNumberOfMinisterTypes()` |  |

### CMinisterType

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetDecay(number)` |  |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |

### CMinister

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `CanTakePosition(CGovernmentPosition)` | 1 |
| [`CIdeology`](#cideology) | `GetIdeology()` | 1 |
| [`CMinisterType`](#cministertype) | `GetPersonality(CGovernmentPosition)` | 2 |
| `boolean` | `IsValid()` | 20 |

Operators: `__eq`.

### CLawDataBase

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| list of [`CLawGroup`](#clawgroup) | `CLawDataBase.GetGroups()` | 1 |
| [`CLaw`](#claw) | `CLawDataBase.GetLaw(number)` | 21 |
| [`CLawGroup`](#clawgroup) | `CLawDataBase.GetLawGroup(number)` |  |
| list of [`CLaw`](#claw) | `CLawDataBase.GetLawList()` |  |
| `number` | `CLawDataBase.GetNumberOfLawGroups()` |  |
| `number` | `CLawDataBase.GetNumberOfLaws()` | 5 |

### CLawGroup

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| `boolean` | `IsValid()` | 20 |

### CLaw

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CLawGroup`](#clawgroup) | `GetGroup()` | 36 |
| `number` | `GetIndex()` | 26 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| `boolean` | `IsValid()` | 20 |
| `boolean` | `ValidFor(CCountryTag)` | 8 |

### CIdeologyData

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](types.md#cfixedpoint) | `CalculateTotalSum()` |  |
| [`CFixedPoint`](types.md#cfixedpoint) | `GetValue(CIdeology)` | 48 |

### CIdeologyGroup

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFaction`](world.md#cfaction) | `GetFaction()` | 228 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
| `CPoint<CFixedPoint>` | `GetPosition()` |  |

Operators: `__eq`.

### CIdeology

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CIdeologyGroup`](#cideologygroup) | `GetGroup()` | 36 |
| [`CString`](types.md#cstring) | `GetKey()` | 32 |
