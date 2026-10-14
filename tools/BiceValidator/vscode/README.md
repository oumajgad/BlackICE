# BlackICE Script

BICE Validator in VS Code, for Hearts of Iron 3 script files.

- **Findings while you type.** A bracket in the wrong place, a key the engine does not
  know, an effect where only conditions are read: underlined as you write, with the hint
  in the tooltip and in the Problems panel.
- **References after every save.** Events fired that do not exist, unknown tags and
  provinces, missing OOB files and modifiers, flags and variables nobody sets, missing
  localisation. These need the whole mod, so they are checked in the background after
  each save.
- **Windows-1252 by default.** Script files open and save in the encoding the game reads,
  so an umlaut can't turn into `Ã¶` by accident.
- **Colouring** for keys, conditions, effects, scopes, tags, numbers, dates and comments.
- **Hover and go to definition** for keywords, fired events, localisation keys,
  countries, provinces, technologies, units, buildings, modifiers, flags, variables and
  OOB files.
- **Event picture previews** on hover and in completion, from the mod's pictures and the
  game's.
- **Every kind of data file checked** against what its loader takes - orders of battle,
  histories, technologies, unit types, the files of `common/`, `map/` and `interface/` -
  with hover and completion for their keys.
- **Model lists explained**: each level of a `model = { ... }` list shows the technology it
  sets, hover tells what that technology does for the unit type, and a quick action writes
  the list one level a line with the names as comments. A queued brigade's
  `historical_model` hovers as the levels it is really built with, and one built with
  levels on the wrong technologies is reported. In `units/models`, a model hovers the same
  table and who queues it, and each of its lines that a production line builds on another
  technology says which.
- **Province and leader names** after their numbers - `location = 739`, `leader = 9721` -
  with a leader's rank in an order of battle, a hover with his country, skill, rank and
  traits, and completion of `leader =` by name. A leader below the rank his unit wants, of
  the wrong arm or country, or given to two units is reported.
- **The chain of events**: hovering an event says what fires it and what it fires, and
  *Show Call Hierarchy* (Shift+Alt+H) walks the chain as a tree in both directions. Events
  that can never happen - triggered only and fired by nothing that happens - are reported.
- **Where `load_oob` puts units**: hovering the file lists its provinces, each marked by
  whether something on the way to the load tests who holds it, and a load with untested
  provinces is reported.
- **Find all references** for events, flags, variables and modifiers.
- **An outline of events and decisions**, and Ctrl+T to find any of them by id or title.
- **Event titles** shown after `country_event = <id>`.
- **Quick fixes** for misspelt keys and a missing `=`.
- **Completion** that offers conditions or effects depending on the block, and event ids,
  countries, flags, variables and modifiers after the `=`.
- **Folding** by brackets, and *BlackICE: Insert the next free event id*.

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
| `eventTitles` | Show the title of each fired event at the end of its line (default on). |
| `modelTechnologies` | Show the technology after each level of a model list (default on). |
| `idNames` | Show the name after a province's or a leader's number (default on). |
| `gameFolder` | The game install, for event pictures the mod does not ship. Found by itself when empty. |
| `serverCommand` | Run the server from source instead of the bundled exe. |

The language server is BICE Validator's own, from `tools/BiceValidator` in the BlackICE
repository, bundled into the extension. Nothing else needs installing.
