# BlackICE documentation

## Modding

- **[The Paradox script language](script/README.md)** - how the game's text files work,
  with a worked event, and the one trap worth knowing before anything else: a key the
  engine does not recognise is dropped in silence.
  - [Scopes](script/scopes.md) - who a block is about
  - [Triggers](script/triggers.md) - all 152 conditions
  - [Effects](script/effects.md) - all 91 effects
  - [Modifiers](script/modifiers.md) - the named values a modifier can change
  - [Orders of battle](script/oob.md) - the unit files in `history/units/`

- **[The Lua API](lua/README.md)** - the country AI is code, not data. How the files load,
  where the engine calls in, and why nothing that comes out of the game is a plain Lua
  value.
  - [Values and containers](lua/types.md) - `CFixedPoint`, `CString`, tags, lists
  - [The world](lua/world.md) - game state, countries, provinces, diplomacy, war
  - [Units, production and technology](lua/military.md)
  - [Government, laws and ministers](lua/politics.md)
  - [The AI objects](lua/ai.md) - what a tick function is handed
  - [Commands and diplomatic actions](lua/commands.md) - the only way to change anything

## Playing

- [Keyboard shortcuts](../Shortcuts.txt)

## Releasing

- [The installer](../installer/README.md) - how the setup exe is built, and why it does
  what it does
- [Install instructions for players](../installer/installInstructions.txt) - the text that
  goes on the forum post

## Digging into the engine

The mod ships a DLL, BiceLib, built from work that reverse engineered parts of the game.
Those notes are extensive and live with the code, in
[`DaveStuff/luabinaries/bice/BiceLib/reversing/`](../DaveStuff/luabinaries/bice/BiceLib/reversing/).
The one most relevant to modding is
[`FINDINGS-script.md`](../DaveStuff/luabinaries/bice/BiceLib/reversing/FINDINGS-script.md),
which is where the trigger and effect lists above came from. The Lua pages come from the
same place: `luabindExtract.py` recovers every exported function's signature out of the exe.
