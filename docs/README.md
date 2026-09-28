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
which is where the trigger and effect lists above came from.

## Still to write

- Lua documentation. The old wiki held a class reference copied from the
  hoi3-ai-improvement-pack Google Code wiki; it was in Google Code markup and has been
  removed. It is still recoverable from the wiki's history at commit `9a7254d` if it turns
  out to be a useful starting point.
