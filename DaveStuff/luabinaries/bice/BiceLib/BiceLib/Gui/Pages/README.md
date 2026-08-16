# Adding a utility page

Each page is two files that share a name: one `.cpp` here and one `.lua` under
`script/utility_imgui`. Nothing else needs editing except the project file and the
Lua loader, so pages stay independent of each other.

## Steps

1. Copy `PageTemplate.cpp.template` to `<Name>Page.cpp` and replace `Template`.
2. Copy `script/utility_imgui/imgui_template.lua.template` to
   `script/utility_imgui/imgui_<name>.lua` and replace `Template`.
3. Add the `.cpp` to `BiceLib.vcxproj` under the existing `Gui\Pages\` entries.
4. Register the module in `script/gui-imgui.lua`:
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

## Groups and order

`group()` must be one of `Gui::GROUP_ORDER` (`Main`, `Game Info`, `Stats`, `Options`,
`Help`, `Debug`) or it sorts last. `order()` sets position within the group; pages
without one sort alphabetically after those that have one. This matters because
registration order is static initialisation order, which is link order and changes
when files are added.
