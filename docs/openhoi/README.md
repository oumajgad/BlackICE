# One mod, two engines

From version 16 BlackICE plays on two engines out of one set of files:

| | the original | OpenHOI3 |
| --- | --- | --- |
| what runs | `hoi3_tfh.exe`, with `script/BiceLib.dll` injected | the engine in the mod's own `engine/` folder |
| who fixes the game's faults | BiceLib, switched on in `script/bicelib_lua.lua` | the engine's **enhanced mode** |
| saves | `save games/` | `save games/openhoi/` |

Version 16 is the last made for both. Until then **every file in the mod has to stay valid for the original**,
whatever it adds for OpenHOI3. This page is how.

The danger is the one the [script guide](../script/README.md) opens with: the original swallows what it does not
understand. It does not report a file made for the other engine - it quietly does something else with it.

## What turns the enhanced mode on

`common/openhoi_enhanced.txt`. Its being there makes every game OpenHOI3 plays from this mod an enhanced one; the
original never opens it. Every fix the engine has is then on, unless the file names it:

```
without = { minister_tech_decay }
```

The file's own comments list the fixes by name. A fix named here that the engine does not know is reported in
OpenHOI3's log.

The `.mod` file of a release also carries `engine = "openhoi3-<x>"`, which names the engine release the mod ships
(`releaseCommon.ENGINE_VERSION`; see [the installer](../../installer/README.md)). The working copy's `.mod` has no
such line, so a developer plays it on whatever engine they have built.

## Where things for OpenHOI3 go

Anything that exists for OpenHOI3 is either **in a subfolder of its own** or **carries the prefix `openhoi_`**, so it
is always plain which engine a file is for, and nothing of it is mistaken for the original's:

| what | where |
| --- | --- |
| the file that turns the mode on | `common/openhoi_enhanced.txt` |
| other data files for the engine | `common/openhoi_*.txt` |
| Lua for the engine | `script/openhoi/`, required with a slash: `require('openhoi/x')` |
| interface elements for the engine | `interface/openhoi/*.gui` |
| their texts | `localisation/openhoi/*.csv` |
| an enhanced game's saves | `save games/openhoi/` (the player's folder) |
| the player's settings for it | `openhoi_settings.txt` (the player's folder, beside `settings.txt`) |
| the engine and its launcher | `engine/` and `launcher/` in the mod's folder (installed, never committed) |

The one thing with neither is a key added to a file the original already reads - see the next section.

## Interface elements and their texts

What OpenHOI3 draws for its enhanced mode, the mod declares - elements in `.gui` files, words in localisation. The
engine supplies neither: an element that is not declared is not there, and a text with no entry shows as its key.

- **`.gui` files for the engine go in `interface/openhoi/`.** OpenHOI3 reads that folder after `interface/*.gui`, and
  only in the enhanced mode. They do **not** go in the files the original reads: a new sub-window added to
  `settings.gui`, say, the original would draw, and never hide.
- **The original never opens a subfolder of `interface/`, `localisation/` or `script/`.** Read off the executable
  (`reversing/findings/FINDINGS-guifolders.md`): it lists one folder and drops the directories in it, and `script/` it
  does not list at all - a Lua file there is opened only by a `require` that names it. That is what makes the three
  `openhoi` subfolders safe, whatever is in them. A `require` of a file in one is written with a slash,
  `require('openhoi/x')`; with a dot the original would not find it.
- **Never a new element kind in a `.gfx` file the original reads.** An element kind it does not know inside
  `spriteTypes`, `objectTypes` or `lightTypes` makes it write through a null pointer while it loads. In a `.gui` file
  an unknown kind at the top of `guiTypes` is stepped over, but one inside a window breaks that window. New kinds
  belong in `interface/openhoi/` only.
- **Element names are the contract**, as in the original's own files: OpenHOI3 finds an element by its name. Where it
  stands, its font and its sprite are the mod's to change; its name is not.
- **Texts go in `localisation/openhoi/*.csv`**, in the form of every other table. OpenHOI3 reads that folder after
  `localisation/*.csv`, and only in the enhanced mode; the original does not read it. Keys carry the prefix
  `OPENHOI_`.

The first of them is the game options: `interface/openhoi/gameoptions.gui` declares the window `openhoi_game_options`,
which OpenHOI3 makes as a part of the Game tab of the options window - four rows below the autosave interval, for a
save before the month ends, a save on a timer, scrolling at the screen's edge and where event windows come up - and
`localisation/openhoi/options.csv` holds their words. The file's own comments list the element names. What the player
chooses is kept in `openhoi_settings.txt`, not in `settings.txt`, which the original reads and rewrites.

## Windows of the mod's own (the utility)

On OpenHOI3 the utility is windows drawn with **Dear ImGui**, as BiceLib's overlay is - but by the mod's own Lua,
with nothing compiled. The **Insert** key shows one window: a tab along its top for each group of pages, the
tab's pages listed down its left side, and the page chosen there on the rest of it. Nothing lists the pages or the
tabs in one place: **a page is there because its file is**, and a tab is there because a page names it - so a submod
adds a page, or a whole tab, by adding its own file.

| | where |
| --- | --- |
| the page | a `.lua` file in `script/openhoi/windows/` - OpenHOI3 takes every file there |
| its texts | a `.csv` in `localisation/openhoi/` |

The page's file returns a table:

```lua
local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise

return {
	title = "OPENHOI_WIN_FLAGS",             -- localisation key of its name, in its tab's list
	order = 20,                              -- its place in that list, lower first
	group = "OPENHOI_WIN_GROUP_INSPECTOR",   -- localisation key of the tab it stands under
	group_order = 40,                        -- where that tab stands among the tabs, lower first

	Collect = function(player)      -- reads the game; answers whatever the page will show
		return { flags = OpenHOI3.CountryFlags(player) }
	end,

	Draw = function(data, player)   -- draws it, every frame
		if data == nil then return end
		for _, name in ipairs(data.flags) do
			ImGui.Text(name)
		end
	end,
}
```

Pages naming the same `group` key share a tab. The tabs stand in the order of the lowest `group_order` any of
their pages gives, as the overlay's do: Setup 10, Country Info 20, Game Info 30, Inspector 40, Stats 50, Options 60,
Help 70, Debug 80. Only the page being looked at runs.

**`Collect` reads the game; `Draw` only draws.** That split is the one rule to keep in mind:

- `Collect(player)` is called when the page is chosen and every two seconds while it is shown, and never while the game
  is working through its hours. Whatever it returns is kept and handed to `Draw`.
- `Draw(data, player)` is called every frame. It is given **no game to ask** - calling one of the game's classes
  there is a Lua error, which the page's window then shows in place of the page until the next `Collect`. Anything
  of the game a page shows has to be in `data`.

What is declared `local` at the top of the file is the page's own state and is kept between frames: the text of a
filter box, a ticked checkbox.

**The widgets** are under `OpenHOI3.ImGui`, by the names Dear ImGui gives them: `Text`, `TextDisabled`,
`TextWrapped`, `TextColored`, `Separator`, `SeparatorText`, `SameLine`, `Spacing`, `NewLine`, `SetNextItemWidth`,
`Button`, `SmallButton`, `Selectable`, `CollapsingHeader`, `Checkbox`, `InputText`, `InputInt`, `SliderInt`,
`SliderFloat`, `Combo`, `BeginDisabled` / `EndDisabled`,
`IsItemHovered`, `SetTooltip`, `BeginTable` / `TableSetupColumn` / `TableHeadersRow` / `TableNextRow` /
`TableNextColumn` / `EndTable`, `BeginTabBar` / `BeginTabItem` / `EndTabItem` / `EndTabBar`, `BeginChild` /
`EndChild`, `TreeNode` / `TreePop`, `PushID` / `PopID`. A widget that holds a value answers `changed, value`:

```lua
local changed, typed = ImGui.InputText(L("OPENHOI_WIN_FILTER"), filter)
if changed then filter = typed end
```

More are added as pages need them. The window itself - title bar, close box, where it stands, its size - is the
engine's; a page draws what is inside. If a page forgets an `EndTable`, or fails half way through one, OpenHOI3
closes what was left open, so a mistake shows as an error in the page's window and not as a crash.

**Every text comes from the localisation**, through `OpenHOI3.Localise(key)`; the window's own title is the key
`OPENHOI_WINDOWS_MENU`.

What OpenHOI3 gives a page to read the game with, beyond the game's own Lua classes: `OpenHOI3.CountryFlags(tag)`
`OpenHOI3.GlobalFlags()` and `OpenHOI3.Conversion(tag)`. More will come page by page.

**A page changes the game by giving an order**, as the player does - never by setting something itself. An order is
a function under `OpenHOI3` that OpenHOI3 names; the first is
`OpenHOI3.SetConversion(tag, which, own, per_day, keep, target)`. It asks the game nothing, so it is given from
`Draw`, on a button's press; OpenHOI3 posts it once the page is drawn and the game runs it with its other orders -
on every machine in multiplayer, and in a replay. The page gathers again a moment later and shows what came of it.
Keep what is typed in the page's own `local`s until a button sends it, so that half a number is never an order.

`script/openhoi/windows/flags.lua`, the Active Flags page, is the worked example, and is commented;
`globalflags.lua` beside it is a second page under the same tab, and `conversion.lua`, Resource Conversion under
Country Info, is the example of a page that gives orders.

**Resource conversion on OpenHOI3 is a setting of the country's own**, kept by the engine and in its save - not the
`zzDsafe_...` country variables BiceLib reads on the original (`docs/bicelib/features.md`). The rule is the same:
for each of the two conversions, whether the player sets it, how much a day, how much of the source to keep and the
level of the product to stop at, within what IC and technology allow. A country nobody plays converts as the game
always has.

## What a file read by both engines may hold

Read off the original's own parser (`reversing/findings/FINDINGS-unknownkeys.md`, in the reverse engineering repository). The rules are not style:
each one is a way the original breaks.

1. **A new key in a file the original reads is `key = value`, never a block.** The original steps over an unknown
   `key = value` cleanly. It does **not** step over an unknown `key = { ... }`: the block's contents are read as if
   they belonged to the enclosing object, and its closing brace ends that object early. Everything after it in the
   object is lost, with no message.

   ```
   # safe in an event, a technology, a unit, a minister, a law, a .mod file
   new_engine_key = 3

   # breaks the object it sits in, on the original
   new_engine_key = { a = 1 }
   ```

2. **A new file under `common/` is safe.** The original opens the files there that it asks for by name and no
   others. That is why whole new tables for OpenHOI3 go in `common/openhoi_*.txt`, where they may use blocks freely.

3. **`common/defines.lua` takes new entries and new sections.** It is fetched by name through Lua, so an entry the
   original never asks for is never seen.

4. **Nothing new in a country's or a province's history.** There an unknown key is not dropped: it is taken for the
   name of something - a building, a technology - and acted on.

5. **A new key must not be the name of anything the mod declares.** Before the original gives up on a key it tries it
   as a building, a technology, a unit type, a terrain and more. A new key called like one of those is that thing.

6. **A new condition needs a gate.** A condition the original does not know is dropped, and a dropped condition is
   an *absent* one: an `AND` holding only it is true. So script that leans on a new condition would fire on the
   original where it must not. It has to stand beside a condition the original answers false and the enhanced mode
   answers true - a gate. **OpenHOI3 does not give one yet**, so until it does, no script in the mod may use a
   condition the original does not know.

   The same goes for a new effect inside an option the original also runs: it is dropped there, so the option must
   make sense without it.

When in doubt, put it in a file of its own under `common/`.

## Lua

`script/autoexec.lua` sets two globals at its top, and they are the only thing to ask:

```lua
G_OPENHOI           -- true on OpenHOI3, false on the original
G_OPENHOI_ENHANCED  -- true on OpenHOI3 in its enhanced mode
```

- **Something done through BiceLib** is for the original: it is already inside `if OpenHOI3 == nil` in
  `script/bicelib_lua.lua`, because OpenHOI3 cannot load the DLL at all. What BiceLib adds, the enhanced mode has
  natively.
- **Something only the enhanced mode can do** goes behind `if G_OPENHOI_ENHANCED then`, in a module under
  `script/openhoi/`, required from inside that `if`. A `require` that is never reached on the original cannot hurt
  it.
- **Something a fix already does** - a workaround in script for a fault the enhanced mode mends - is skipped by
  asking for that fix: `OpenHOI3.Fixes.minister_tech_decay` is `true` when it is on. Ask it only behind
  `G_OPENHOI_ENHANCED`; `OpenHOI3` is nil on the original.
- A parameter both engines need may be **declared twice** for as long as both are served: once for BiceLib in Lua,
  once for the enhanced mode in data. That duplication ends with version 16.

OpenHOI3 runs the mod's Lua on LuaJIT; `pairs` walks a table in another order than the original's Lua 5.1.4. Code
whose result depends on that order was already fragile, and differs between the engines.

## Checking a change on both

- **The original**: as always - move the files across and start the game.
- **OpenHOI3**: start its launcher, tick the mod, Play. Its log, in the mod's folder under Documents, reports every
  key it did not recognise - the original's silent drops included - which makes it the quicker place to find a typo
  in either engine's files.

A file meant for OpenHOI3 alone that the original would trip over is the mistake to look for: check the six rules
above before adding a key to a file that is not under an `openhoi` name.
