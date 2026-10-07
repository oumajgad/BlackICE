# The Paradox script language

Hearts of Iron 3 is configured almost entirely in plain text files, and BlackICE is
mostly a very large collection of them. Events, decisions, units, technologies, orders of
battle and country histories are all written in the same small language.

This page is how that language works; the reference pages beside it list everything it accepts.

The country AI is *not* written in it - that is Lua, in `script/`. All these files hold is
`ai_chance` on an event option, and events whose paths were decided in advance. Where these
pages mention the AI, that is the weighting on an option, not a thinking opponent.

| Page | What is in it |
| --- | --- |
| [scopes.md](scopes.md) | who a block of conditions or effects is about |
| [triggers.md](triggers.md) | all 152 conditions, and five keys that look right but do nothing |
| [effects.md](effects.md) | all 91 effects |
| [modifiers.md](modifiers.md) | the named values a modifier can change |
| [oob.md](oob.md) | orders of battle: the unit files in `history/units/` |

## The shape of it

Everything is `key = value`, and a value is either a single item or a block in braces.

```
id = 48759                          # a number
title = "US BOMBERS ATTACK"         # a quoted string, for text with spaces
is_triggered_only = yes             # yes / no
option = {                          # a block, which holds more key = value pairs
    name = "American bastards!"
}
```

That is the whole syntax. A few things worth knowing:

- **`#` starts a comment**, to the end of the line. There is no block comment.
- **Quotes are only needed when the value contains a space.** `desc = "EVTDESC48752"`
  and `desc = EVTDESC48752` are the same thing.
- **Long text has to move to `localisation/`.** A short string can sit inline, but past a
  certain length the game will not take it and the value has to become a localisation key
  instead, with the real text in a `.csv`. That is why most events read
  `desc = "EVTDESC48752"` rather than carrying their paragraph directly. The exact cut-off
  is not established here; the longest inline string in the mod today is 255 characters,
  which is suggestive but only one data point. If a long `desc` renders as nothing in game,
  this is why.
- **A block with no `=` inside it is a list**, not a set of pairs - that is how the
  engine tells `model = { 0 0 1 }` from `option = { name = "..." }`.
- **Keys are not case sensitive.** The mod writes `not` 11,349 times and `NOT` 255 times,
  both in files that work.
- **Whitespace and newlines never matter.** `cost = 0.0 progress = 200 duration = 2` on
  one line is normal in OOB files.
- **The files are Windows-1252, not UTF-8.** German and Polish names are full of
  characters that are a single byte here and two in UTF-8. An editor that saves as UTF-8
  will turn `Göring` into `GÃ¶ring` in game. 34 of the event files currently have bytes
  that are not valid UTF-8 at all.
- **Some keys may appear more than once** in the same block, and every one applies -
  several `military_construction` blocks in one OOB file, several `modifier` blocks in one
  `mean_time_to_happen`, several `replace_path` lines in a `.mod`. This is per key, not a
  general rule: repeat something like `id` or `cost` and you are relying on whichever the
  loader happens to keep. If you have not seen a key repeated somewhere that works, assume
  it cannot be.

## Where the files are

| Folder | What lives there |
| --- | --- |
| `events/` | events - the bulk of what BlackICE adds |
| `decisions/` | decisions, which are events the player chooses to fire |
| `history/units/` | orders of battle: the units a country starts with, or that an event spawns |
| `history/provinces/` | what each province starts with |
| `common/` | countries, ministers, buildings, laws, unit definitions |
| `units/` | brigade and division types |
| `technologies/` | the tech trees |
| `map/` | regions, terrain, adjacencies |
| `localisation/` | every piece of text the player sees, as `KEY;English;...` |

## A worked example

This is a real event, from `events/Japan.txt`, complete:

```
country_event = {
    id = 48759                              # unique across the whole mod
    is_triggered_only = yes                 # only fires when something else fires it
    title = "US BOMBERS ATTACK"             # shown in the event box
    desc = "EVTDESC48752"                   # a localisation key, looked up in localisation/
    picture = "doolittle"                   # gfx/event pictures

    option = {                              # every event needs at least one option
        name = "American bastards!"
        dissent = 3                         # an effect: +3 dissent for this country

        random_owned = {                     # a scope: pick one province this country owns
            limit = {                        # ...but only one that matches these
                infra = 3                    #   infrastructure of at least 3
                is_core = CHI                #   and is Chinese core territory
            }
            create_revolt = 1                # the effect applies to that province
        }

        ai_chance = {                        # how likely the AI is to pick this option
            factor = 100
        }
    }
}
```

Read it as three layers. The **header** (`id`, `title`, `desc`, `picture`,
`is_triggered_only`) is about the event itself. **Effects** like `dissent` and
`create_revolt` change the world. **Scopes** like `random_owned` decide *what* they
change it for.

An event that is not `is_triggered_only` needs a `trigger = { ... }` block of conditions
saying when it may fire, and usually a `mean_time_to_happen` saying how soon after that.
`is_triggered_only = yes` instead means some other event or decision fires it by id with
`country_event = 48759`.

## Scopes change who the block is about

With no scope, a condition tests the country the event is firing for, and an effect
applies to it. A scope points both somewhere else:

```
any_country = {              # for every country in the game...
    limit = {                # ...that is in the Axis
        faction = axis
    }
    country_event = 500      # fire event 500 for it
}
```

`limit` is the important one and it is easy to get wrong: inside a scope that iterates
(`any_country`, `any_owned`, `random_owned`), `limit` filters which members the block
applies to. Without it, `any_country = { country_event = 500 }` fires for everybody.

Scopes nest as deep as you like. `owner`, `controller` and `capital_scope` move from a
province to a country; `any_owned` and `random_owned` move from a country to its
provinces. [scopes.md](scopes.md) lists them all.

`and`, `or` and `not` group conditions rather than changing scope. One catch inherited
from the engine: **`not` does not reliably imply an `and` inside it** - if you need more
than one condition under a `not`, write the `and` explicitly.

## When a key is wrong, nothing happens

This is the single most important thing on this page.

A condition or effect key is looked up against the keyword lists in
[triggers.md](triggers.md) and [effects.md](effects.md). If it is not there, the engine
tries a province id, then an ideology, then the technology database. If it is none of
those either, **the key is a parse error and the condition or effect is silently
dropped**. The game starts, the event fires, and the part you got wrong simply is not
there. Nothing is logged and nothing looks broken.

So a typo does not announce itself. It makes an event quietly do less than it says.

The old notes these pages replace contained five such keys, all of which read perfectly
reasonably and none of which does anything:

| Looks right | Actually works |
| --- | --- |
| `brigade_exists` | `brigade_exist` |
| `is_threatened` | `is_threatend` |
| `neighbor` | `neighbour` |
| `port = yes` | `naval_base = <level>`, or `num_of_ports` |
| `fuel = x` as a condition | nothing - it is a real effect, but there is no fuel condition |

Two of those are the engine's own spelling mistakes, kept because fixing them would break
every file that already uses them. The full table, with what to write instead, is at the
bottom of [triggers.md](triggers.md#keys-that-do-not-work).

### The other way round: keys that work without being keywords

The fall-through is why `industry = 3` works in an event even though `industry` is in
neither switch. It is a **building**, declared in `common/buildings.txt`, and the lookup
finds it there. The same is true of `divisonal_command_structure = 1` as a condition -
that one is a technology, misspelling and all.

So the rule is not "it must be a keyword". It is "it must be a keyword **or** the name of
something the game declares". That is a much larger set than any list here, and it is why
a typo is so easy to miss: `infantry_brigade` and `infanty_brigade` look equally plausible
and only one of them is a unit.

There is a tool for exactly this. From the `hoi3-reversing` repository beside this one:

```
python scripts/scriptcheck.py
```

It takes every key the events and decisions use, subtracts the keyword lists and every
name the mod declares anywhere, and shows what is left - which is the list of things that
are being silently ignored. It needs a running game, because part of the answer lives in
the technology database.

## Where these lists came from, and keeping them honest

The trigger and effect lists are not folklore. They were read out of the game: the two
loaders `CTrigger::LoadKey` and `CEffect::LoadKey` are each one giant switch over the save
token of a key, one case per keyword, and
[`findings/FINDINGS-script.md`](../../../hoi3-reversing/findings/FINDINGS-script.md)
in the fact base repository has all 243 with their token and the class that implements
each.

The lists are therefore complete and fixed: the switches are what the shipped game does,
and no future edit to the mod can add to them or take away.

Entries marked **(unverified)** are keywords the engine accepts but this mod never uses.
Their description is inferred from the name of the implementing class and has not been
confirmed in game - treat them as leads, not documentation.
