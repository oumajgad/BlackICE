# The Lua API

Everything in [`docs/script/`](../script/README.md) is data: a file of `key = value` that
the engine reads and acts on. The country AI is not data. It is Lua, it lives in `script/`,
and it is real code - 193 files and about 1.4 MB of it in BlackICE.

This page is how that code is wired into the game. The pages beside it are the reference:
every class the game exposes, with what each method takes and what it gives back.

| Page | Classes | Methods | What is on it |
| --- | --- | --- | --- |
| [types.md](types.md) | 23 | 97 | `CFixedPoint`, `CString`, tags, dates, arrays and lists |
| [world.md](world.md) | 19 | 257 | the game state, countries, provinces, diplomacy, war |
| [military.md](military.md) | 19 | 87 | units, the production queue, buildings, technology |
| [politics.md](politics.md) | 12 | 42 | government, laws, ministers, ideologies |
| [ai.md](ai.md) | 11 | 88 | the AI objects a tick function is handed |
| [commands.md](commands.md) | 41 | 49 | everything you can post, and every diplomatic offer |

## The API is fixed, and this is all of it

**125 classes and 620 functions.** That is not a selection - it is the whole of what
`hoi3_tfh.exe` hands to Lua, and no mod can add to it or take away from it. There is no
hidden call that a better-informed modder knows about.

The list is not folklore either. `script/LUA API.txt` is the game's own registration code,
and [`luabindExtract.py`](../../../hoi3-reversing/ghidra/luabindExtract.py)
in the fact base repository recovers each function's signature by emulating that registration
and then asking luabind to write the signature out - the same text the game would put in an
error message. So the argument lists and return types on these pages are the running game's
own account of itself.

## Registered, but not what it says

A handful of entries are not what their name suggests, because the registration binds the
Lua name to a differently named C++ function, or because the line is commented out in the
game's own source. Each is noted where it appears, but these are the ones worth knowing
before you go looking:

| What you write | What actually happens |
| --- | --- |
| `CDistributionSetting:GetPercentage()` | bound to `GetBasePercentage` - the share of what is assigned, not of what is needed. The real one is commented out |
| `CTechnology:GetEnableUnit()` | does not exist. Commented out in the registration |
| `CConstructSingleUnitCommand(...)` | does not exist. Commented out, and nothing hands you one either - see [commands.md](commands.md#cconstructsingleunitcommand) |
| `CUnitList:GetCount()` | does not work. Use `GetSize` |
| `war:GetStartDate()` | always 365 days after day 0; `GetCurrentRunningTimeInMonths` always 0. An `active_war` carries no dates in the save |
| `country:GetCapital()` | bound to `GetActingCapital`, so it moves when the real capital is lost |
| `country:IsPuppet()` | bound to `IsSubject` - true for any subject, not only puppets |

## How the files load

`script/autoexec.lua` runs once when the game starts. It sets `package.path`, then
`require`s each module in turn: the shared ones first, then one file per country from
`script/country/`.

**A single error takes out everything after it.** `require` of a file that does not exist,
or that has a syntax error, stops the whole of autoexec - so every module listed after the
broken one never loads, and the countries that depend on them quietly fall back to doing
nothing. The comment in the file says as much, and it is why the country requires are
ordered majors first and defaults last.

Nothing announces this. The game starts, the menu appears, and the AI is simply absent.

## Where the engine calls in

The engine calls a fixed set of function names. Define one and it runs; misspell it and
nothing happens.

| Function | When |
| --- | --- |
| `ForeignMinister_Tick(minister)` | the foreign minister's turn to act |
| `ProductionMinister_Tick(minister)` | the production minister's turn |
| `TechMinister_Tick(minister, sliders, research)` | the technology minister's turn |
| `PoliticsMinister_Tick(minister)` | the politics minister's turn |
| `IntelligenceMinister_Tick(minister)` | the intelligence minister's turn |
| `ForeignMinister_OnWar(agent, tag1, tag2, war)` | a war starts |
| `ForeignMinister_EvaluateDecision(minister, decisions, scope)` | the AI is choosing among decisions |
| `AI_GenerateNonHistoricalRelation(country, target)` | a non-historical game is setting up relations |
| `DiploScore_<Action>(ai, actor, recipient, observer, ...)` | someone is weighing a diplomatic offer |

There are eighteen `DiploScore_` callbacks, one per kind of offer - alliance, non-aggression,
military access, lend-lease, trade, expeditionary force and the rest. Each is handed the
action and answers with a number: higher means more willing. The action classes themselves
are on [commands.md](commands.md).

BlackICE adds handlers of its own on top, in `script/ai_omg_handlers.lua`, driven by the OMG
country rather than by the engine.

## Nothing is a plain Lua value

This is the thing that catches people first. What comes out of the game is a game object,
not a Lua number or string:

```lua
local unity = country:GetNationalUnity()   -- a CFixedPoint, not a number
if unity > 50 then end                     -- does not work
if unity:Get() > 50 then end               -- works
```

Not every number is one, which is the awkward part: `GetNationalUnity` gives a
`CFixedPoint` and `GetMaxIC` gives a plain `number`. The Returns column on each reference
page is the only way to know which.

- **Numbers** are [`CFixedPoint`](types.md#cfixedpoint). `:Get()` gives a Lua number,
  `CFixedPoint(n)` goes the other way. The class has its own `+`, `-`, `*`, `/` and
  comparisons, so fixed point against fixed point is fine; fixed point against a bare
  number is not.
- **Strings** are [`CString`](types.md#cstring). `tostring()` comes out, `CString("...")`
  goes in - which is why calls all over the mod's Lua are written
  `GetVariable(CString("name"))`.
- **Countries** are [`CCountryTag`](types.md#ccountrytag), not
  [`CCountry`](world.md#ccountry). The tag is the handle nearly everything takes;
  `tag:GetCountry()` gets you the country object when you need the detail.

## Colon or dot

Most calls are on an object and take a colon, which passes the object itself:

```lua
local date = CCurrentGameState.GetCurrentDate()     -- static, a dot
local country = CCountryDataBase.GetTag("GER"):GetCountry()
local ic = country:GetMaxIC()                       -- a method, a colon
```

In the reference, a method is written `GetMaxIC()` and a static is written with its class in
front, `CCurrentGameState.GetCurrentDate()`. The object the colon supplies is never in the
argument list.

## Nothing happens until you post it

The API reads freely and changes almost nothing. To make something happen you build a
command and hand it to the game:

```lua
local command = CSetVariableCommand(tag, CString("ExampleVariable"), CFixedPoint(1))
CCurrentGameState.Post(command)
```

Every class on [commands.md](commands.md) works this way. The command is queued, not run
where you post it, so nothing you read on the next line reflects it yet.

## When something goes wrong, nothing is said

There is no error box and no console. An error inside a tick function ends that tick and the
game carries on.

The way to see anything is `Utils.LUA_DEBUGOUT(...)`, which appends to **`lua_output.txt`**
in the game folder. BiceLib writes to the same file through `BiceLibLuaLog(...)`, and opens
a real console when it loads.

## What BiceLib adds

`BiceLib.dll` is loaded from `script/bicelib_lua.lua` and puts a `BiceLib` global beside the
engine's own classes - byte patches, tooltips, extra GUI, the custom map modes. It is not
part of the API on these pages and it is not something the base game has; if the DLL fails
to load, `BiceLib` is nil and the file says so in `lua_output.txt`.
