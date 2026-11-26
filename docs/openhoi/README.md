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

## Rules that are the mod's choice

A fix is how the enhanced mode behaves. A **rule** is a choice of the mod's, and is written as data in the file
that already holds its subject - a define, a kind of modifier - so that it is in the save and the checksum and no
script has to set figures day by day.

**How many units a command may hold.** On the original this is BiceLib's `setCorpsUnitLimit` and its two
siblings, fed by `CheckOobUnitLimitTechnologyStatus`. On OpenHOI3:

| what | where |
| --- | --- |
| the base of each level | `common/defines.lua`, section `military`: `OPENHOI_CORPS_UNIT_LIMIT`, `OPENHOI_ARMY_UNIT_LIMIT`, `OPENHOI_ARMY_GROUP_UNIT_LIMIT`. Five where one is not given, which is the original's |
| what raises or lowers it | three kinds of modifier: `corps_unit_limit`, `army_unit_limit`, `army_group_unit_limit`. From anything a modifier comes from - a triggered modifier, a law, a minister, a strategic resource - and from a technology, which gives its figure a level |
| a division of one brigade takes no place | `OPENHOI_LONE_BRIGADE_TAKES_NO_PLACE = 1` in the same section |

A country's limit is the base and the **whole part** of what it has of the kind, and never less than one. The
country asked is the commander's. A theatre has no limit. Nothing is detached when a limit falls. **The AI's own
sorting of its units into commands counts five to a command as the original does, on both engines** - BiceLib does
not change it either.

BlackICE's steps are at set levels of seven doctrine technologies, which a figure a level cannot say, so they are
twelve triggered modifiers, `unit_limit_...`, at the end of `common/triggered_modifiers.txt` with the mod's others -
there is no file of the engine's own for them. The original reads them too: it logs the three kinds as unknown
modifiers and drops them, so there each is a row of the Strategic Effects window with its name and its condition
and no effect, while BiceLib sets the same figures from Lua. Their names are in `localisation/zDD-Flags.csv`, where
the original finds them. **While a release plays on both engines the table is kept twice** - there and in
`script/ai_variable.lua` - and the base twice, in `defines.lua` and as `G_BASE_COC_LIMIT`.

**Two more, each one define** - not given, the original's rule:

| define | section | at 0 | on the original |
| --- | --- | --- | --- |
| `OPENHOI_AI_LENDS_UNITS` | `military` | an AI country lends no unit to whoever holds the ground it stands on. A unit on loan is still given back | `BytePatches.disableInterAiExpeditionaries`, which stops the giving back too |
| `OPENHOI_WAR_EXHAUSTION_TO_NEUTRALITY` | `diplomacy` | a month of peace hands no war exhaustion to neutrality; the figure goes back to nought all the same. At war it gathers under `max_war_exhaustion` as always | `BytePatches.disableWarExhaustionNeutralityReset`, which sets the figure to nought every month |

## Lines the engine writes, in the mod's words

What BiceLib adds to the original's tooltips in hard-coded English, OpenHOI3's enhanced mode writes from
`localisation/openhoi/texts.csv`. **A line is switched on by its text being there**: take a key out and the
original's text shows. So these are no fixes and are not named in `common/openhoi_enhanced.txt`.

| what | keys | on the original |
| --- | --- | --- |
| a leader's skill with his highest, in the leader window | `OPENHOI_LEADER_SKILL` (`$SKILL$`, `$MAX$`) | `Leaders.activateLeaderListShowMaxSkill` |
| what a `load_oob` file would do, in an option's tooltip | `OPENHOI_LOAD_OOB_...`, about twenty-five; `OPENHOI_LOAD_OOB_UNITS` switches it on. A kind of unit with its article is a key each, `OPENHOI_LOAD_OOB_KIND_CORPS` | `EffectTexts.activateLoadOobDetails` |
| a land unit's summed figures and its damage, in a battle's tooltip | `OPENHOI_BATTLE_STATS_...` and `OPENHOI_BATTLE_DAMAGE_...`, twelve; `OPENHOI_BATTLE_STATS_HEAD` switches it on | `Tooltips.activateCombatUnitStats` |
| whether a design may be dropped by parachute, in the division designer | `OPENHOI_DESIGNER_PARADROP_YES`, `_NO` (`$WEIGHT$`), `_BLOCKER` (`$NAME$`) | `Tooltips.activateParadropLine` |
| what a combined arms group gives, on its icon | `OPENHOI_DESIGNER_CA_BONUS` (`$VALUE$`), `_BONUS_TECH` (`$TECH$`), `_BASE`, `_NOT_BASE` | `Tooltips.activateCombinedArmsLine` |
| the two lines of a scrolled tooltip | `OPENHOI_TOOLTIP_MORE_ABOVE`, `OPENHOI_TOOLTIP_MORE_BELOW` (`$COUNT$`); a yellow `...` without them | `EffectTexts.activateTriggerScroll` |

Two more need no key of their own, because BlackICE's texts already ask: `KILL_LEADER_EFFECT` is filled with
`$UNIT$`, `$LOCATION$` and `$WHERE$`, and `MANPOWER_DETAILS_IRO` with `$LAND$`, `$AIR$`, `$NAVY$`, `$ROTATION$`,
`$ROTATIONCOST$`, `$ATTRITION$` and `$TRICKLEBACK$`, as BiceLib fills them on the original.

Where they differ from BiceLib's: the `load_oob` text counts off the engine's own reading of the file; a battle's
damage is what was really taken off a unit, for strength as for organisation, and is kept in the save with the
manpower figures; a tooltip of any kind scrolls and says what is left below as well.

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
| the page | a `.lua` file in `script/openhoi/windows/` or a folder below it - OpenHOI3 takes every file there |
| its texts | a `.csv` in `localisation/openhoi/` |

**The pages are kept in a folder for each tab**: `script/openhoi/windows/country_info/`, `.../inspector/`, and so
on as tabs gain pages. The folders are for our own order only - OpenHOI3 walks them all and reads nothing from a
folder's name; the tab a page stands under is the `group` its table gives. A submod replaces a page by shipping a
file at the same path, and two folders may each hold a file of the same name.

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
`SliderFloat`, `Combo`, `InputTextMultiline` (a box of text that can be copied), `GetContentRegionAvail`,
`BeginPanes` (columns with a divider to drag, ended by `EndTable`), `ImageSize` / `Image`, `IsItemActive`,
`IsWindowFocused`, `IsKeyPressed`, `SetScrollHereY`, `SetClipboardText`,
`BeginDisabled` / `EndDisabled`,
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

What OpenHOI3 gives a page to read the game with, beyond the game's own Lua classes: `OpenHOI3.CountryFlags(tag)`,
`OpenHOI3.GlobalFlags()`, `OpenHOI3.CountryVariables(tag)`, `OpenHOI3.CountryModifiers(tag)` and
`OpenHOI3.Conversion(tag)`. More will come page by page.

**A page that lists things and shows the chosen one** notes the choice in a `local` while drawing and calls
`OpenHOI3.Refresh()`: OpenHOI3 then runs its `Collect` again at once, where the chosen thing's figures are read.
Until the answer is for the choice now made, the page draws a "Loading..." line. `game_info/traits.lua` is the
commented example.

**The pages share `script/openhoi/pagekit.lua`** - the filter box, a filtered table, a filtered list with a chosen
row, a box of text - taken with `local Kit = require('openhoi/pagekit')`. It stands beside the `windows` folder and
not in it, because every file below `windows` is taken for a page.

**The data behind the pages is the same on both engines.** `BiceLibGui.<Page>.<Function>` in
`script/utility_imgui/` and `BiceData` in `script/utility_data/` parse the mod's files and ask the game's Lua
classes; on the original BiceLib's overlay draws what they answer, on OpenHOI3 a page under `script/openhoi/windows`
does. So a change to what a page shows is made once, there, and a page file holds only its drawing. Where such a
function needs what BiceLib reads out of the running game, it asks OpenHOI3 for the same thing in the same shape
when `OpenHOI3` is there: `BiceLibGui.Generals.Details` asks `OpenHOI3.LeaderDetails(id)` for a leader's unit and
province, and `BiceLib.Leaders.getLeaderDetails` on the original.

| tab | pages on OpenHOI3 so far |
| --- | --- |
| Country Info | Country Modifiers, IC Days, Puppets, Strategic Res., Resource Conversion, Strategic Trades, Global Market, National Focus, Minister Buildings, Trade AI, Prod. Sliders AI, LS Sliders AI |
| Game Info | Traits, Generals, Modifiers, Techs, Units, Unit Models |
| Inspector | OOB Browser, OOB Report, Combat Reports, Active Flags, Global Flags, Active Variables, Active Event Modifiers, Province Buildings |
| Setup | Country, Misc |
| Stats | Setup, Statistics |
| Options | Utility Options |
| Help | Misc, Ministers + Buildings, National Focus |
| Debug | Engine Profiler |

**Engine Profiler** (`script/openhoi/windows/engine/profiler.lua`) is a page for OpenHOI3 alone, with nothing like
it on the original: how long the game's hours take, step by step - an ordinary hour, an hour that turns a day, the
last 240 hours as a line, every step of the engine's hour by the engine's own name with its parts under it - a
table sorted by the heading clicked (`BeginSortedTable`), the steps among themselves and each step's parts - the
orders the hours run by kind - and what the program says of itself: frames a second, memory, what is drawn. It
reads `OpenHOI3.Profile.Read()`; the timing starts when the page is first opened and runs until its Stop. Its
folder is `engine` and not `debug` because the repository's `.gitignore` leaves every folder called `Debug` out.

**The Inspector's larger pages.** On the original BiceLib reads these out of the game's memory; on OpenHOI3 the
engine gives the same things to the mod's Lua:

- `OpenHOI3.ProvinceDetails(id)` answers what `BiceLib.GameInfo.getProvinceDetails` answers, in the same shape and
  scale, and `BiceData.ProvinceBuildings.Details` asks whichever is there. Province Buildings is otherwise the
  mod's own data, as on the original.
- `OpenHOI3.OrderOfBattle(tag)` answers every unit of a country with the unit over it, its leader, what it gets
  and uses of supplies and fuel, and its regiments. `script/openhoi/pageoob.lua` makes the tree and the counts
  from it, for the OOB Browser and the OOB Report. It is read on Refresh and when the selected country is
  another, not on a timer.

Not carried over on those pages: the browser's "Move to" (a page cannot move the map), the Auto boxes, and the
red of a unit without a commander, which is marked with `!` in the tree instead.

**The Inspector's last three pages, as decided on 2026-11-22** (OpenHOI3's `docs/enhanced.md`, *Interface*):

- **Combat Reports** stays a page of the utility, and is built. On the original BiceLib catches every battle as
  it ends and keeps them in files under `script/combat_reports`, a campaign and its sessions told apart by the
  variables `bice_combat_campaign` and `bice_combat_session` of OMG. **OpenHOI3 keeps the record itself, in the
  game and in its save**, so the page needs none of that: it reads `OpenHOI3.CombatTally(tag, from_day, to_day)`
  and `OpenHOI3.LastCombats(tag, count)`, and a savegame loaded has its own record with it. Both sides of a battle
  are always named there, so the overlay's note on battles that "name only their winner" has nothing to say. The
  record begins with the first battle that ends in a game played on an OpenHOI3 that keeps it; the DLL's files
  are not read. The two OMG variables and `BiceLibGui.Combat` serve the original engine alone.
- **Unit Inspector** is not a page. On OpenHOI3 a click on the ribbon over a selected unit's brigades ("5
  Brigades") opens the brigade card's window with the figures of the entire unit. Its texts are the
  `OPENHOI_UNITCARD_*` keys of `localisation/openhoi/windows.csv`.
- **Statistics.** OpenHOI3 keeps the statistics itself, in the game and its save: every country's figures a value
  a day, where the lobby's rule "Collect statistics" is on (`interface/openhoi/lobbyrules.gui`). The Statistics
  page reads that record through `OpenHOI3.Statistics` and can write it out as the files the plotting tool reads;
  the Setup page is gone, and `script/utility/stats/stats.lua` collects nothing on OpenHOI3. The rules are
  OpenHOI3's `docs/mechanics/statisticsrecord.md`.
- **Native pages.** A page that names a `window` fills a window of the game's own interface with `OpenHOI3.Gui` in
  place of drawing itself: `script/openhoi/windows/country_info/prodsliders.lua` and `lssliders.lua` over
  `interface/openhoi/sliders.gui`, opened by the "Sliders AI" buttons on the production and technology screens,
  and `tradeai.lua` over `interface/openhoi/tradeai.gui`, opened by "Trade AI" under it on the production
  screen, with `script/openhoi/nativeform.lua` the form they share. They are no longer in the utility's menu on OpenHOI3.
  The rules are OpenHOI3's `docs/mechanics/nativepages.md`.
- **Built-in elements.** A `.gui` file of `interface/openhoi/` may give an icon or a button
  `built_in = { style = panel size = { x = 300 y = 120 } color = { r = 0 g = 255 b = 0 } }` in place of a
  `spriteType`: OpenHOI3 paints it, with no texture and no `.gfx` entry. The styles are `flat`, `panel`, `button`,
  `row`, `header`, `divider`, `frame` and `field`; `interface/openhoi/builtin_styles.txt` may change them or add
  more. `interface/openhoi/builtin_sample.gui` shows every one (`--window=openhoi_builtin_sample`). The rules are in
  OpenHOI3's `docs/mechanics/builtin.md`.
- **Custom Mapmode** is not a page. On OpenHOI3 a right click on the Infrastructure, Resources or Supply map mode
  button opens a list of what that mode can shade by instead; the windows are `interface/openhoi/mapmodes.gui`, the
  texts the `OPENHOI_MAPMODE_*` keys of `localisation/openhoi/windows.csv`, the rules OpenHOI3's
  `docs/mechanics/custommapmodes.md`. What stood here before:
- **Custom Mapmode** will not be a page either. It goes into the engine: a right click on a map mode's button
  opens a small list to choose from, as the unit upgrade selection does.

**The Options tab is one page on OpenHOI3.** Utility Options sets the window itself, through `OpenHOI3.Window`
while the page draws: `Key()` / `CaptureKey()` / `CancelCapture()` / `Capturing()` for the key that opens it,
`Theme()` / `Themes()` / `SetTheme(name)` for its look, `Scale()` / `SetScale(factor)` for its text size and
`ResetLayout()`. OpenHOI3 keeps the key and the look in `openhoi_settings.txt`; the text size is not kept. The
looks are the drawing library's three - dark, light, classic - and Army green, which OpenHOI3 draws in colours of
its own after the overlay's (olive panels, amber headings); the overlay's Grey is not there. The rest of the overlay's Options tab is elsewhere or not there:

- **Game Settings** (edge scrolling, where event popups appear) and **Custom Auto-Saves** are rows of the game's
  own Options window on OpenHOI3, declared in `interface/openhoi/gameoptions.gui`.
- **Crash reports** and the **debug console** are BiceLib's.

**The Help tab** draws the mod's own text (`BiceData.Help`) with `Kit.HelpPage`, and the national focuses' effects
by tier from `BiceLibGui.NatFocus.Effects`.

**The Stats tab.** Setup switches the mod's collection of statistics and edits its list of countries, through
`BiceLibGui.Stats` as the overlay does. Statistics reads the run's files itself - `<path>/<run>/<TAG>/<statistic>`
below the game's folder - and draws a line for each series ticked, with `ImGui.PlotLines`. Not carried over from
the overlay: every series in one plot, the dates under the mouse, and the button that starts
`visualizeStatisticCLI.exe`. A line goes from reading to reading at even steps, so days with nothing collected
take no room on it. **The collection itself (`script/utility/stats/stats.lua`, run from the ministers'
ticks) does not work on OpenHOI3**, so the Statistics page has nothing to read there. It is set aside, not mended:
see below.

**After the port, some pages move closer into the engine** (decided 2026-11-22; OpenHOI3's `docs/enhanced.md`,
*Interface*). The pages above bring the utility to OpenHOI3 as it stands on the original. Once that is done:

- **The custom sliders and the trade AI** - Prod. Sliders AI, LS Sliders AI, Trade AI - are to be part of the
  game's own production, technology and trade screens, not pages of a utility window.
- **Statistics** are to come from a record OpenHOI3 keeps itself, not from text files the mod's Lua writes a
  statistic a country a day.

Neither is designed yet. Until then those pages stay as ported.

**The country the pages report on is the one chosen on Setup > Country** - the Lua global `G_PlayerCountry`, as on
the original: this machine's alone, not saved, and following the country played until another is chosen. A page
takes it in its `Collect` with `player = Kit.Selected(player)`; the mod's data functions resolve it themselves.

Left out of the Setup tab on OpenHOI3:

- **Special**, the page that moves the 3D unit sprites of `gfx\anims` aside. It exists for the original's 32-bit
  address space, which loads them though the mod draws none; OpenHOI3 never loads them, and a page of a mod does
  not write into the game's folder.
- **Country's "BiceLib setup" section**, which reports BiceLib's own daily job and the HQ unit limits it sets in the
  original's memory. There is no such job on OpenHOI3.

As in the overlay: the divider between a list and its details is dragged (`Kit.BeginPanes`), and in a list that
was the last thing clicked Up, Down, Home and End choose a row. A picture is drawn with `ImGui.Image(path, width,
height)`, its size asked with `ImGui.ImageSize(path)`, the path below the game's folder as the mod's Lua has it.
Not carried over: the scrollbar across a sprite wider than its pane - "Fit" scales it down instead.

**A page that sets something through the mod's data functions** - a national focus, a puppet's focus, the three AI
forms - leaves the setting to them, as the overlay does: they post the game's own `CSetVariableCommand` through
`CCurrentGameState.Post`. That needs the game, which a page has only in its `Collect`. So the press is noted while
drawing and done at the next `Collect`, which is asked for at once:

```lua
if ImGui.SmallButton(L("OPENHOI_WIN_NATFOCUS_SET")) then
    Kit.Pend("natfocus", index)                       -- show what was asked for until the game answers the same
    Kit.Ask(function() source.Set(index) end)         -- done in Collect; Kit.Gather runs it
end
```

What is posted there OpenHOI3 sends as an order of the player's - it does not go straight into the game - so it
reaches the host in multiplayer. `Kit.Shown(name, actual)` answers the value to show and whether it is still on
its way. The three AI forms share `script/openhoi/pageform.lua`: values edited on the page, sent by Apply alone.

Not carried over on Country Info: the Refresh and Auto row (every page re-reads every two seconds while it is
shown, Global Market only when asked), a button's or a box's own colour (the focus a puppet has is greyed, a
priority used twice is marked with a red `!`). The two figures of Country Modifiers that BiceLib reads on the
original come from the engine here: Offmap IC from `OpenHOI3.OffmapIc` - what the country's own `ic` modifier adds
under the fix `offmap_ic` - and Trickleback from `OpenHOI3.Trickleback`, the share a battle applies.

**A page changes the game by giving an order**, as the player does - never by setting something itself. An order is
a function under `OpenHOI3` that OpenHOI3 names; the first is
`OpenHOI3.SetConversion(tag, which, own, per_day, keep, target)`. It asks the game nothing, so it is given from
`Draw`, on a button's press; OpenHOI3 posts it once the page is drawn and the game runs it with its other orders -
on every machine in multiplayer, and in a replay. The page gathers again a moment later and shows what came of it.
Keep what is typed in the page's own `local`s until a button sends it, so that half a number is never an order.

`script/openhoi/windows/inspector/flags.lua`, the Active Flags page, is the worked example, and is commented;
`globalflags.lua` beside it is a second page under the same tab, and `country_info/conversion.lua`, Resource
Conversion under Country Info, is the example of a page that gives orders.

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

**BiceValidator checks for the original alone.** A key of OpenHOI3's in a file both engines read is a warning there:
the twelve `unit_limit_...` entries of `common/triggered_modifiers.txt` give twelve BV308, "`corps_unit_limit` is not
a key of ...", which is true of the original and meant. An OpenHOI3 switch for the validator, which knows the
engine's own keys, is on the list for later (2026-11-26); until then those twelve stand and are not in the baseline.

## Removal candidates

What serves the original engine alone and has a replacement on OpenHOI3. Each stays for as long as a release still
plays on the original, and goes with the first release that does not. Each is also marked where it stands.

| what | where | replaced on OpenHOI3 by |
| --- | --- | --- |
| the resource conversion's events and covert operation | events 1553 to 1555 in `events/covert_ops_events.txt`; `set_resource_conversion` in `common/covert_ops.txt`; their texts in `localisation/BiceLib_conversion.csv` | the Resource Conversion page, `script/openhoi/windows/country_info/conversion.lua` |
| the unit limits' Lua | `CheckOobUnitLimitTechnologyStatus` in `script/ai_variable.lua` and its calls; `G_BASE_COC_LIMIT` in `script/ai_globals.lua`; the three `set...UnitLimit` calls in `script/bicelib_lua.lua` | `OPENHOI_..._UNIT_LIMIT` in `common/defines.lua` and the `unit_limit_...` entries of `common/triggered_modifiers.txt` |
| eight of BiceLib's switches | in `script/bicelib_lua.lua`: `historicalModelLogicFix`, `fixQueuedHistoricalModel`, `enablePlacingNonResearchedBuildings`, `activateOobLeaderRanks`, `activateHistoryLeaderRanks`, `disableWarExhaustionNeutralityReset`, `disableInterAiExpeditionaries`; `Events.rebuildCandidates` in `script/ai_omg_handlers.lua` | the fixes `historical_model_choice`, `queued_historical_model`, `place_unresearched_building`, `oob_leader_ranks`, `history_leader_ranks` and `saved_event_candidates`, and the defines `OPENHOI_WAR_EXHAUSTION_TO_NEUTRALITY` and `OPENHOI_AI_LENDS_UNITS` |
| ten of BiceLib's display switches | in `script/bicelib_lua.lua`: `activateLeaderListShowMaxSkill`, `activateCtrlUnassignSelected`, `activateKillLeaderVariables`, `activateLoadOobDetails`, `activateTriggerScroll`, `activateManpowerBreakdown`, `activateCombatUnitStats`, `activateParadropLine`, `activateCombinedArmsLine` | `localisation/openhoi/texts.csv`, and the fixes `ctrl_unassign_selected` and `tooltip_scroll` |
| the two start-up warnings | "Failed to load BiceLib.dll." and "You should delete sprites.": events 1108 and 1109 in `events/omg_events.txt`, the decisions `bicelib_load_status` and `sprite_deletion_status` in `decisions/OMG_Decisions.txt`, `DetermineBiceLibLoadStatus` and `DetermineSpriteDeletionStatus` in `script/utility-extras.lua` with their two calls in `script/ai_omg_handlers.lua`, and the texts `EVTDESC1108` and `EVTDESC1109` | nothing: OpenHOI3 needs no DLL and loads no sprite models. Both functions return at once where `G_OPENHOI` is set, so neither event comes up there |

On OpenHOI3 the events still come up and their options change nothing: the `zzDsafe_...` conversion variables they
set are not read there. They cannot be hidden on one engine until a gate exists (rule 6 above).
