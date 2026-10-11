# BlackICE Script

BICE Validator in VS Code, for Hearts of Iron 3 script files.

- **Findings while you type.** A bracket in the wrong place, a key the engine does not
  know, an effect where only conditions are read: underlined as you write, with the hint
  in the tooltip and in the Problems panel.
- **References after every save.** Events fired that do not exist, unknown tags and
  provinces, missing OOB files and modifiers, flags nobody sets, missing localisation.
  These need the whole mod, so they are checked in the background after each save.
- **Windows-1252 by default.** Script files open and save in the encoding the game reads,
  so an umlaut can't turn into `Ã¶` by accident.
- **Colouring** for keys, conditions, effects, scopes, tags, numbers, dates and comments.

It works on any mod folder with `events`, `decisions` and `common` in it, such as a
checkout of the BlackICE repository or an installed copy under the game's `tfh/mod`.

## Settings

All of them are under `blackice.validator`:

| Setting | |
| --- | --- |
| `enable` | Show findings at all. |
| `disabledRules` | Rules never to show, e.g. `BV209`. |
| `minimumSeverity` | `error`, `warning` or `info`. |
| `references` | `onSave` (default) or `off`. |
| `scope` | `openFiles` (default) or `workspace`, for every file's findings in the Problems panel. |
| `hideKnownNoise` | Hide what `tools/BiceValidator/baseline.json` lists as known noise. |
| `serverCommand` | Run the server from source instead of the bundled exe. |

The language server is BICE Validator's own, from `tools/BiceValidator` in the BlackICE
repository, bundled into the extension. Nothing else needs installing.
