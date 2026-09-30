# Values and containers

<!-- Every name, argument and return type on this page was read out of
     hoi3_tfh.exe by reversing/ghidra/luabindExtract.py, which emulates the
     game's own luabind registration and then asks each function for its
     signature. See docs/lua/README.md for how to read it. -->

The small types every other call hands you or asks for. None of them is a plain Lua value: a number out of the game is a `CFixedPoint`, a string is a `CString`, and a country is a `CCountryTag`. Getting those conversions wrong is the most common way a piece of AI script silently does nothing.

Types are written the way a script sees them, so the object the colon supplies is not in the argument list. **Calls in the mod** counts by method name across every `.lua` file under `script/`, so a name several classes share - `GetKey`, `IsValid`, `Create` - carries the total for all of them.

### CFixedPoint

The game's own number type: a fixed point value, not a Lua number. Arithmetic between one of these and a bare number does not work - use `:Get()` to come out, `CFixedPoint(n)` to go in.

**Constructors**

- `CFixedPoint()`
- `CFixedPoint(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `Get()` | 474 |
| `number` | `GetTruncated()` | 12 |

Operators: `__add`, `__div`, `__eq`, `__le`, `__lt`, `__mul`, `__sub`, `__tostring`.

### CFixedPoint64

A wider `CFixedPoint`, used where the value can outgrow 32 bits.

**Constructors**

- `CFixedPoint64()`
- `CFixedPoint64(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `Get()` | 474 |
| `number` | `GetRounded()` |  |
| `number` | `GetTruncated()` | 12 |

Operators: `__add`, `__div`, `__eq`, `__le`, `__lt`, `__mul`, `__sub`, `__tostring`.

### CString

The game's string. `tostring()` on one gives a Lua string; going the other way needs `CString(...)`, which is why so many calls are wrapped in it.

**Constructors**

- `CString(string)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `string` | `GetCharPtr()` |  |
| `string` | `GetString()` | 23 |

Operators: `__eq`, `__tostring`.

### CID

An object id. Rarely built by hand.

**Constructors**

- `CID()`

### CEU3Date

A date in the game's calendar.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| - | `AddDays(number)` |  |
| `number` | `GetDayOfMonth()` | 20 |
| `number` | `GetMonthOfYear()` | 5 |
| `number` | `GetTotalDays()` | 10 |
| `number` | `GetYear()` | 18 |

### CSimpleRandom

The game's random generator. Using this rather than Lua's `math.random` keeps a multiplayer session in step.

**Constructors**

- `CSimpleRandom()`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](#cfixedpoint) | `GetFixedPoint()` |  |
| `number` | `GetInteger()` |  |
| `number` | `GetNumber()` |  |
| - | `Seed(number)` |  |

### CCountryTag

A country, as the three letter tag. This is the handle almost every country level call takes - not the `CCountry` itself.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountry`](world.md#ccountry) | `GetCountry()` | 381 |
| `number` | `GetIndex()` | 26 |
| `string` | `GetTag()` | 344 |
| `boolean` | `IsReal()` | 4 |
| `boolean` | `IsValid()` | 20 |

Operators: `__eq`, `__tostring`.

### CNullTag

The tag that means no country. Compare against it rather than against nil.

Inherits [`CCountryTag`](#ccountrytag) - everything on it works here too.

**Constructors**

- `CNullTag()`

### CArrayInt

**Constructors**

- `CArrayInt(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetAt(number)` | 7 |
| `number` | `GetSize()` | 4 |
| - | `SetAt(number, number)` | 2 |

### CArrayFloat

**Constructors**

- `CArrayFloat(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `number` | `GetAt(number)` | 7 |
| `number` | `GetSize()` | 4 |
| - | `SetAt(number, number)` | 2 |

### CArrayFix

**Constructors**

- `CArrayFix(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](#cfixedpoint) | `GetAt(number)` | 7 |
| `number` | `GetSize()` | 4 |
| - | `SetAt(number, CFixedPoint)` | 2 |

### CArrayFix64

**Constructors**

- `CArrayFix64(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint64`](#cfixedpoint64) | `GetAt(number)` | 7 |
| `number` | `GetSize()` | 4 |
| - | `SetAt(number, CFixedPoint64)` | 2 |

### CArrayCountryTag

**Constructors**

- `CArrayCountryTag(number)`

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CCountryTag`](#ccountrytag) | `GetAt(number)` | 7 |
| `number` | `GetSize()` | 4 |
| - | `SetAt(number, CCountryTag)` | 2 |

### CUnitList

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| `number` | `GetCount(CSubUnitDefinition)` | 18 | **Does not work.** Use `GetSize` instead. |
| `number` | `GetTotalAmountOfArmies()` |  |  |
| `number` | `GetTotalAmountOfDivisions()` | 3 |  |
| `number` | `GetTotalNumOfPlanes()` | 1 |  |
| `number` | `GetTotalNumOfRegiments()` | 1 |  |
| `number` | `GetTotalNumOfShips()` | 1 |  |
| `number` | `GetTotalNumOfTransports()` |  |  |
| `number` | `GetTotalNumOfWarShips()` |  |  |
| [`CFixedPoint`](#cfixedpoint) | `GetTotalStrength()` |  |  |

### CCountryList

Inherits [`CCountryList`](#ccountrylist) - everything on it works here too.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `IsEnemy(CCountryTag)` | 2 |

### CCountryTagList

### SubUnitList

**Constructors**

- `SubUnitList()`

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| - | `SubUnitList.Append(list of CSubUnitDefinition, CSubUnitDefinition)` | 39 | Bound to `AppendSubUnit`. |
| `number` | `GetSize()` | 4 |  |
| `boolean` | `IsEmpty()` |  |  |
| - | `SubUnitList.RemoveAll(list of CSubUnitDefinition)` |  | Bound to `RemoveSubUnits`. |

### CList_CSubUnitConstructionEntry

| Returns | Method | Calls in the mod | Notes |
| --- | --- | --- | --- |
| [`CSubUnitConstructionEntry`](military.md#csubunitconstructionentry) | `GetHeadData()` |  |  |
| `number` | `GetSize()` | 4 |  |
| [`CSubUnitConstructionEntry`](military.md#csubunitconstructionentry) | `GetTailData()` |  |  |
| `boolean` | `IsEmpty()` |  |  |
| `boolean` | `Remove(CSubUnitConstructionEntry)` |  | Bound to `RemoveData`. |
| `boolean` | `RemoveHead()` |  |  |
| `boolean` | `RemoveTail()` |  |  |

### CGoodsPool

What a country has in store of each resource, and what it is earning and spending per day.

**Constants** - written `CGoodsPool._SUPPLIES_` and so on.

| Constant | Value |
| --- | --- |
| `_SUPPLIES_` | 0 |
| `_FUEL_` | 1 |
| `_MONEY_` | 2 |
| `_CRUDE_OIL_` | 3 |
| `_METAL_` | 4 |
| `_ENERGY_` | 5 |
| `_RARE_MATERIALS_` | 6 |
| `_GC_NUMOF_` | 7 |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](#cfixedpoint) | `Get(GoodsCategory)` | 474 |
| `number` | `GetFloat(GoodsCategory)` | 36 |

### CGoodsValues

**Constructors**

- `CGoodsValues()`

**Properties** - read as `obj.Name`, no call.

| Property | Type | Writable |
| --- | --- | --- |
| `vMoney` | `number` | yes |
| `vFuel` | `number` | yes |
| `vCrudeOil` | `number` | yes |
| `vMetal` | `number` | yes |
| `vEnergy` | `number` | yes |
| `vSupplies` | `number` | yes |
| `vRareMaterials` | `number` | yes |

### CResourceValues

**Constructors**

- `CResourceValues()`

**Properties** - read as `obj.Name`, no call.

| Property | Type | Writable |
| --- | --- | --- |
| `vDailyExpense` | `number` | yes |
| `vDailyHome` | `number` | yes |
| `vConvoyedIn` | `number` | yes |
| `vPool` | `number` | yes |
| `vDailyIncome` | `number` | yes |
| `vDailyBalance` | `number` | yes |

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| - | `GetResourceValues(CCountry, GoodsCategory)` | 9 |

### CVariables

A country's script variables - the same ones `set_variable` and `check_variable` reach from an event.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| [`CFixedPoint`](#cfixedpoint) | `GetVariable(CString)` | 117 |

### CFlags

A country's flags, as `set_country_flag` sets them.

| Returns | Method | Calls in the mod |
| --- | --- | --- |
| `boolean` | `IsFlagSet(string)` | 35 |
