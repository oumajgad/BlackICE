# Adding a utility page

Each page is up to three files that share a name: one `.cpp` in the folder for its
dock group, one `.lua` under `script/utility_imgui` shaping data for it, and, where
the page needs game state, one provider under `script/utility_data`. Nothing else
needs editing except the project file and the two Lua loaders, so pages stay
independent of each other.

The folders here mirror `group()`, minus the space: `Main`, `CountryInfo`, `GameInfo`,
`Inspector`, `Stats`, `Options`, `Help`, `Debug`. They are for finding things only -
nothing reads them, and moving a file between them changes nothing until `group()`
changes with it.

The provider layer is where reading and writing game state belongs: it holds no UI of
any kind, so the old wx utility can be moved onto the same code later instead of
keeping a second copy of the logic.

## Steps

1. Copy `PageTemplate.cpp.template` to `<Group>/<Name>Page.cpp` and replace
   `Template`.
2. Copy `script/utility_imgui/imgui_template.lua.template` to
   `script/utility_imgui/imgui_<name>.lua` and replace `Template`.
3. Write `script/utility_data/bicedata_<name>.lua` if the page reads game state, and
   require it from `script/bicedata.lua`.
4. Add the `.cpp` to `BiceLib.vcxproj` next to the other pages of its group, and to
   `BiceLib.vcxproj.filters` under `Source Files\Gui\Pages\<Group>` so it lands in
   the right place in Solution Explorer too.
5. Register the module in `script/gui-imgui.lua`:
   `{ module = 'imgui_<name>', key = '<Name>' }`

The page registers itself via `REGISTER_GUI_PAGE`, so there is no central list of
pages to edit and no merge conflicts between pages.

## Rules that are easy to get wrong

**The Lua module file must start with `imgui_`.** Lua's `require` caches by module
name and the old wx utility already claims `ic_days`, `country_info`, `misc`, `setup`,
`puppets`, `techs`, `traits`, `units`, `modifiers`, `flags`, `vars`, `generals`,
`stats`, `options` and `help`. Without the prefix, `require` returns the old cached
module, the page file never executes, and **no error is raised anywhere**. The loader
in `gui-imgui.lua` checks that the expected `BiceLibGui` key appeared, which is what
turns this into a visible failure.

**Never call the game's Lua API outside a running session.** `CCurrentGameState`,
`CCountryDataBase` and friends fault inside the game's own C++ at the main menu, and
`lua_pcall` cannot catch that. `Gui::Lua::available()` already gates every call on
`sessionActive()`, so as long as page data is fetched through the bridge this is
handled - do not add a code path that reaches Lua another way.

**Collect() returns plain data only.** Numbers, strings, booleans, and arrays of
those or of flat tables. No userdata: the C++ side cannot read it.

**Don't refresh per frame.** Most of this data changes once a game day. The template
refreshes on a timer with a manual override; raise the interval for anything
expensive.

## Shared code

Don't hand roll what these already do:

- `BiceData.Country` - resolving the selected country, reading a variable, posting a
  change. Providers should not reach for `CCountryDataBase` or `GetVariables`.
- `Page.Guard` in `imgui_page` - the pcall wrapper every page call needs, so a Lua
  error arrives as text on the page instead of a blank panel.
- `BiceData.AiSettings` and `imgui_form` - staging, committing and activating a block
  of AI settings variables. Shared by the three AI pages; a fourth would reuse them.

## Groups and order

`group()` must be one of `Gui::GROUP_ORDER` (`Main`, `Country Info`, `Game Info`,
`Inspector`, `Stats`, `Options`, `Help`, `Debug`) or it sorts last, and the file
belongs in the matching folder. `group()` only decides where a page starts, on a
first launch with no `BiceLibImGui.ini`; after that the player's layout wins, so
changing it moves nothing on an install that has already run. `order()` sets position
within the group; pages
without one sort alphabetically after those that have one. This matters because
registration order is static initialisation order, which is link order and changes
when files are added.
