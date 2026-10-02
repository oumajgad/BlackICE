# The message system

A message is what the player sees when a division shatters or a province is lost: a popup,
a line in the log, a marker on the map. Worked out to give BiceLib one of its own -
`BiceLib/GameClasses/GameMessage.hpp`.

## The registry is data, not code

`interface/messagetypes.txt` is what the engine registers, and **a type the mod declares is
a type the engine knows**. The proof is four names in that file that appear nowhere in the
executable - `LEADERDIED`, `SHIPSUNK`, `MINISTER_DEATH` and `RETURN_EXILE_US` - which all
survive into `messagetypes_custom.txt`, the dump the game writes by walking the live
registry. `SHIPSUNK` even has full localisation. A type nothing raises is normal here.

What *is* compiled in is the 180 names the engine raises itself, each a literal at its own
raise site.

**A name the registry does not hold costs nothing**: `CMessageHandler::FindType` logs
`Failed to find message type: <name>` and returns null.

A type's text follows `SHATTERED`'s scheme: `_SETUP` for the settings screen, `_HEADER` for
who reports it, `_1` to `_6` for the popup's lines (`*` for an unused one), `_LOG`, `_BTN1`
to `_BTN3`, and `_MAP`.

## Raising one

| | |
| --- | --- |
| `0x0D75F0` | `CCountry::BuildMessageVariables` - the list every message starts with, `$COUNTRY$` first |
| `0x298E80` | `GetMessageHandler` - a lazy singleton at `0x1689A8C`, **no arguments** |
| `0x299480` | `CMessageHandler::FindType` - by name, `__fastcall(ecx = name, edx = handler)` |
| `0x29AA70` | `CMessage::CMessage` - twelve arguments, built into a `0x80` buffer |
| `0x110A50` | `PostMessage` - handler, province, the message **by value**, and a pair above it |
| `0x0A6040` | `MessagePopupCallback` - the same pointer at every raise site; **not** the text |
| `0x0355B0` | `BuildMessagePopupText` - `Header`, `Line1`..`Line6`, the buttons; **this** is the text |

`GetMessageHandler` taking nothing is worth knowing: `CCountry::ShatterUnit` calls it in
the middle of pushing another call's arguments, which reads like an eight argument call and
is not. Mistaking it for one made the whole system look far harder than it is.

### The variables

Each is a `CMessageVariable`, `0x44` bytes: the key at `+0`, the value at `+0x1C`, both
`std::string`, then `previous` at `+0x38` and `next` at `+0x3C`. They hang off a
`{first, last, count}` list.

**The game builds them inline**, not through a function, so anything raising a message
reproduces the steps: `0x44` bytes from the game's allocator, both strings made empty,
assigned, then linked. The nodes must come from the **executable's** allocator, because
`CMessage::CMessage` takes the list and releases it.

`CCountry::BuildMessageVariables` returns fourteen, and what it returns is **the
country's own list at `country + 0x24`** - its first act is to clear that member
(`0x33F60`) and refill it. It allocates nothing, so every caller is handed the same list.

**Which makes two raises for one country impossible to overlap.** Raising one from inside
`CCountry::ShatterUnit`, which was holding that list in `edi`, cleared it and then let
`CMessage::CMessage` release it - freeing nodes the game's own message still pointed at.
It crashed at `0x67ACE7`, a virtual call through a stale vftable, with `"MONA"` in `ecx`:
it was substituting `$MONARCHTITLE$` out of a freed node. Anything BiceLib raises has to
happen where no other message is part-built. `Game::Message::queue` is the answer to both
that and the Present rule: it copies the message and a hook on `CInGameIdler::Update` raises
the batch once a frame, out of `Present` and never nested.

### The argument order

`CMessage::CMessage`, in the order `ShatterUnit` pushes them:

    1      the 0x78 buffer to build into
    2      the type                                  -> +0x20
    3      the variable list, walked and released
    4      the province                              -> +0x44
    5      a head string, which `ShatterUnit` passes **empty**
    6      zero                                      -> +0x70
    7,8    the game state's player tag and id        -> +0x34, +0x38
    9,10   the country's +0xCA4 and +0xCA8           -> +0x3C, +0x40
    11,12  two zeroes                                -> +0x68, +0x6C

Arguments 11 and 12 are not pushed: they are eight bytes reserved below the ten that are.

The head was read as `MESSAGE_HEAD_MARS` at first. It is not: `0x100DB5` builds that
string from a **zero length**, and the pointer it builds it from is the padding after
`sinh`. The string is empty, and the localisation key that name came from belongs
somewhere else entirely.

### `ret 0x88` is five arguments, not three

    +0x08   the handler
    +0x0C   the province
    +0x10   the message, 0x78 bytes by value
    +0x88   the popup builder
    +0x8C   zero

8 + 0x78 + 8 = 0x88, and the post reads `[ebp+0x88]` and `[ebp+0x8C]` where that puts
them. **The two above the message are pushed before the message is reserved** - at
`0x100DFA` and `0x100DFF`, a good sixty bytes before the call - so at a raise site they
read as stray pushes with nothing to do with the post.

Getting this wrong twice cost two builds, in two different ways:

- reading the pair as coming **before** the message shifted every field by two words and
  crashed the post at `0x110B8C`, where it takes the type from `+0x20` and dereferences it

      0x00C20B8C  cmp byte ptr [esi+0xE]     esi = 0x1F, reading 0x2D

- dropping the pair entirely and calling the message 0x80 bytes did not crash, and
  produced **an empty popup**, because the builder was then null

Both calls pass things by value, so `GameMessage.cpp` writes the sequence out as
instructions rather than declaring C++ function pointers, and restores `esp` from `ebp`
afterwards so a mismatch cannot unwind into the caller.

### The builder, and where the text really comes from

`0xA6040` takes the message as its argument, reads the type's name out of it at `+0x20`
and dispatches on that name - `AIRATTACKTHEM`, `AIRATTACKUS` and the rest. **Every raise
site passes the same pointer**, loaded as a bare immediate (`mov esi, 0x4A6040` at
`0x100DBE`, `mov eax, 0x4A6040` at `0x173A31`), so it is a constant rather than a choice.
The post tests it at `0x1112DA` and hands it to whichever popup it builds.

It reads like the text builder and **it is not one.** A probe standing on it printed
nothing at all for a message that renders correctly, so it is never called while the
popup is up - a button's callback, most likely. The guess that a null one explains an
empty window went with it.

**`0x355B0` is the function that fills a popup in**: `_HEADER`, `Header`, `Line1` to
`Line6`, `AgreeButton`, `DeclineButton`, `CenterOK`, the spacing from
`popup_textline_dist`, and the combat popups' two columns. `ret 4`, the popup its one
argument, and ten callers - none of them `PostMessage`, so it runs from the popup's own
update rather than from the raise.

## Only the player is told

`ShatterUnit` compares the country's `+0xCA8` against the game state's player id at
`+0xC34` and jumps past the entire message block when they differ (`0x1008FD`). **The
engine never raises a message for an AI country.** Anything BiceLib raises has to make the
same test, or every division lost anywhere pops a window.

## Borrowing the game's own message

`CCountry::ShatterUnit` names its type at `0x100DDC` - `push 9`, `push "SHATTERED"` - and
those seven bytes are the only thing deciding which message comes out. Patching them raises
a type of your own through machinery that is otherwise untouched, with `$UNIT$` and
`$LOCATION$` already filled in.

**Worth knowing as a technique rather than as code**: BiceLib did this for a while, to prove
a mod-declared type could be raised at all before anything was built by hand, and it is the
cheapest way to separate "the type and its localisation are fine" from "our raise is wrong".
The code is gone; `Game::Message` does the whole job now.

**That site cannot be checked by matching its bytes.** The pushed pointer is an absolute
address carrying a relocation, so only `6A 09 68` is fixed and the immediate has to be
resolved against the module base. Matching all seven failed against an image loaded at
`0xB10000`.

## Where a message can be raised from

**Not from inside the overlay's Present hook.** A message raised there is built
correctly, posts without complaint, and comes up as **an empty window**: no header, no
lines, no buttons. The same message raised from a game tick comes up right.

Three call sites were needed to say that, because the obvious two differ in two ways at
once:

| raised from | through Lua | inside Present | result |
| --- | --- | --- | --- |
| the overlay's Lua console | yes | yes | **empty** |
| `CInGameIdler::DailyUpdate`, in C | no | no | renders |
| `CInGameIdler::DailyUpdate`, through Lua | yes | no | renders |

The third settles it: **Lua has nothing to do with it.** Anything the game drives - an
event effect, an AI handler, a hook in a tick - can raise a message. Anything running
inside `Present` cannot, so a message wanted from the utility's own GUI has to be left
for the game thread to raise.

What it is about being inside `Present` is not known. The popup is created by the post
and its text is built later by `BuildMessagePopupText`, from the popup's own update, so
the candidates are that the update never runs for a popup created mid-frame, or that it
runs and the text goes nowhere. `Reversing::MessageProbe` stands on that function and on
the post and prints the thread of each, which is what would tell them apart.

**What this is not.** It was called a thread problem first, on no evidence: `Present` and
Lua share a thread in this game and the tick is largely the same one, so "the render
thread" named a thread when the thing that actually varied was the point in the frame.
The three rows above are the measurement; the label was a guess.

### What was ruled out getting here

Every one of these was checked by printing both messages' innards side by side rather
than by reading the disassembly again, and every one of them matched:

- the message's bytes, field by field, across the whole `0x78`
- the type: the *same object*, `FindType` returning the very pointer the game uses
- the message handler, the popup callback, the trailing word
- the province: a genuine `CMapProvince`, reporting its own id at `+0xD0` and carrying
  the same vftable as the game's
- the variable list: all sixteen entries, keys and values, including every `$KEY$` the
  type's own localisation asks for
- the localisation and the type declaration, proven by raising `SHATTERED` itself through
  BiceLib's path - which was **also** empty

That last one is the cheapest check of the lot and worth remembering: raising the game's
own type through your own code separates the raise from the text in one step.

## What is still open

Neither `CCountry +0xCA4` nor `+0xCA8` has been identified; they are read and passed on.

`$UNIT$` and `$LOCATION$` are added by `ShatterUnit` itself at `0x100A75` and `0x100B8D`,
not by the type, so the variables a message needs are the raising code's business and a
type declared in `messagetypes.txt` says nothing about them.
