# The in-game utility

BiceLib draws an ImGui overlay inside `hoi3_tfh.exe` itself. It is the replacement
for the wxWidgets utility that opened separate windows, and it does the same job
without leaving the game: read the mod's data and the running game's state, and change
the things a player or a developer is allowed to change.

Both utilities still exist and can be run together or separately. See
`README.md` next to this file for the Lua API BiceLib exposes to the mod, which is a
different thing from the overlay described here.

## Turning it on

Everything is switched in `script/utility_settings.lua`:

| Setting | What it does |
| --- | --- |
| `G_UtilityEnabled` | the old wxWidgets utility, in its own windows |
| `G_ImguiUtilityEnabled` | this overlay. Off also means the Direct3D hooks are never installed |
| `G_ImguiWarmupEnabled` | parse the mod's files at startup rather than when a page first asks |

**Press INSERT** in game to show and hide it. It starts hidden, so it never covers a
loading screen or the main menu.

## How it gets on screen

`Overlay::install()` patches the `IDirect3DDevice9` vtable that `d3d9.dll` shares
between every device it hands out, so hooking it through a throwaway device also
catches the device the game is drawing with. Three slots are taken:

- **Present (17)** - draws the overlay, once per frame.
- **Reset (16)** - recreates the ImGui device objects after a resolution change.
- **CreateTexture (23)** - accounting only, for the Memory page's texture inventory.

Present rather than EndScene, because the game wraps its offscreen render targets in
their own BeginScene/EndScene pairs; an EndScene hook draws the overlay into cached UI
textures instead of onto the screen.

Input arrives through a subclass on the game window. Messages ImGui wants are
swallowed so the game does not also act on them.

## Where the data comes from

Three layers, and the layer a thing belongs in is decided by what it is rather than
where it is convenient:

1. **`script/utility_data/bicedata_*.lua`** - providers. They read and write game
   state and parse the mod's files, and hold no UI of any kind. Both utilities use
   them, which is why there is only one copy of the rules.
2. **`script/utility_imgui/imgui_*.lua`** - one per page. They shape a provider's data
   into the flat tables the overlay can read, and nothing more.
3. **`BiceLib/Gui/Pages/*.cpp`** - one per page, grouped into folders by dock. They
   draw, and they hold the state that belongs to being on screen.

A page that reads the game's memory directly skips Lua entirely - see `Oob/` for the
order of battle, which reads unit structures itself. Offsets for that come from the
memory map in `DaveStuff/mem`, and anything learned about those structures should go
back there.

`Gui/LuaBridge.cpp` is the only file that touches a `lua_State`. Pages call Lua by
dotted path (`BiceLibGui.Techs.Collect`) and read plain fields back.

## Windows and layout

Pages declare a `group()`, and each group gets its own dockable window: `Main`,
`Country Info`, `Game Info`, `Inspector`, `Stats`, `Options`, `Help`, `Debug`. A single
tab bar would be unusable with thirty pages on it.

`group()` only decides where a page *starts*, on a first run with no layout to go by.
After that the player's layout wins, including for a page whose group changed in a
later build. The layout lives in `BiceLibImGui.ini` next to the DLL, and deleting it is
how to take the code's arrangement again.

## Things that are easy to get wrong

**Never call the game's Lua API outside a running session.** `CCurrentGameState` and
friends fault inside the game's own C++ at the main menu and `lua_pcall` cannot catch
it. The bridge gates every call on `sessionActive()`; note that this means "a game
state object exists", which is already true at the main menu.

**Game text is Windows-1252.** ImGui needs UTF-8 and draws anything else as its
fallback glyph, so German names arrive as a row of `?`. Everything read from the game
goes through `Text::toUtf8`, at the point it is read rather than at each widget.

**`CCurrentGameState.Post` is asynchronous.** A change does not take effect by the time
the call returns, which is why pages that write show a pending state and wait to see
the value come back.

**Lua runs on the render thread.** Present and the game's Lua share a thread, so the
overlay can call into Lua directly from its draw. It also means slow Lua costs frames.

**Anything read out of memory goes through `Mem::tryRead`.** A pointer that turns out
not to be what we assumed then fails instead of taking the process down.

## The Debug window

- **Timing** - what each page cost to build the first time, and the warm-up's progress.
- **Memory** - private, mapped and image address space; the game's Lua states and what
  they hold; every texture created and still alive, by format.
- **Lua Console** - run Lua in the game's own state, with saved scripts.
- **Thread Check** - which thread the overlay is on.

## Adding a page

`BiceLib/Gui/Pages/README.md` covers it: a `.cpp` in the folder for its dock group, a
`.lua` wrapper, a provider if it needs game state, and the two places they have to be
registered.

## Building and deploying

Build **the solution**, not the project: `BiceLib.vcxproj` on its own leaves
`$(SolutionDir)` empty and writes the DLL somewhere useless.

```
msbuild BiceLib.sln /p:Configuration=Debug /p:Platform=win32
```

That maps to the `ReleaseDebug|Win32` profile and produces `ReleaseDebug/BiceLib.dll`.
Copy that over `script/BiceLib.dll` in the mod repository.
