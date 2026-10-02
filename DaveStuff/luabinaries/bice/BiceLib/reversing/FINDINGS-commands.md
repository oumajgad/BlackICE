# The command queue

Where every `CCommand` is posted, where it is executed, and what of it goes to a
multiplayer peer. Read statically out of `hoi3_tfh.exe` on 2026-09-30; the game was not
running, so nothing here is marked *seen*. Addresses are virtual, based at `0x400000`,
with the rva beside anything a finding names. **Everything under "what the code does" was
read off the disassembly. The section on what it means for multiplayer is a reading of
that, and is marked as one.**

## In one line

A command is posted to a **session** (`session.cpp`), which owns one **command channel**.
The channel stamps the command with the session's turn number and a serial, serialises it,
and puts it on a lock-free queue - a loopback queue in single player, the network for a
multiplayer host. The session's pump drains the channel and calls `CCommand::Execute` at
**one site**, `0x00A89940` (rva `0x689940`). The byte `+0x34` on the session says whether
this machine is allowed to post at all, and the modes that clear it are the ones that
carry a remote address.

## The three objects behind `in_game_screen` slot 18

`CInGameIdler` slot 18 is `0x0064D800` (rva `0x24D800`), three instructions:

    mov eax, [ecx + 0x1790]
    mov eax, [eax + 0x12C]
    ret

So it is a two-hop accessor and there are two objects to name.

**`CInGameIdler + 0x1790` is the network/session manager.** It is the constructor's fourth
argument. The chain, all of it read:

| | |
| --- | --- |
| `0x006087C0` (rva `0x2087C0`) | makes a `CBackEndIdler` and writes its own `this` into `idler+0xB8`; one caller, `0x00654518`, which passes `[CInGameIdler+0x1790]` in `ecx` |
| `0x0060BAF0` (rva `0x20BAF0`) | makes a `CFrontEnd` from `[this+0xB4]`, `[this+0xB0]`, `[this+0xB8]` |
| `0x006ED660` (rva `0x2ED660`) | `CFrontEnd::CFrontEnd` - `[this+0x20C] = arg2`, `[this+0x210] = arg4` (vftable `0x15D458C`, RTTI) |
| `0x006F07A0` (rva `0x2F07A0`) | `CFrontEnd` launches the game: constructs `CCurrentGameState` into `0x1A89790`, then `CInGameIdler`, passing `[this+0x20C]` and `[this+0x210]` |
| `0x006474A0` (rva `0x2474A0`) | `CInGameIdler::CInGameIdler` - `[this+0x178C] = arg2`, **`[this+0x1790] = arg4`** at `0x00648418` |

`0x00648418` is the **only** write to a `+0x1790` displacement in the image (32 instructions
use the displacement, 31 of them reads). So `CBackEndIdler+0xB8`, `CFrontEnd+0x210` and
`CInGameIdler+0x1790` are the same object, and it outlives both idlers.

`0x006F07A0` is also where `CFrontEnd+0x68` is tested and, when set, the log line
`'\n\n\t\t[[ Launching MULTIPLAYER-game ]]\n'` is written (`0x006F081A`) - which is
independent support for `CInGameIdler+0x68` already being named `multiplayer`.

The manager's class has no RTTI record. Its constructor is `0x0062F080` (rva `0x22F080`),
which carries the strings `'HoI3 v4.02'`, `'HoI3 1.0'`, `'NoAdress'` and
`'InitialSession'`, and at `0x0062F375` writes `[this+0x12C]`.

**`manager + 0x12C` is a session.** It is constructed in place by `0x00A887A0`
(rva `0x6887A0`), vftable `0x15FE5E8` (8 slots, no RTTI), and `0x00A89600` - the function
that executes commands - carries the string `'session.cpp'` at `0x00A89869`. The
`'InitialSession'` name and mode `2` are passed from `0x0062F30F`.

`CInGameIdler` slot 19 (`0x0064D810`, rva `0x24D810`) is the matching setter: it releases
the old `[0x1790]+0x12C` and stores a new one. Slot 14 (`0x0064D7C0`) is the same two-hop
accessor for `[0x1790]+0x124`, and slot 17 (`0x0064D7D0`) returns `[this+0x178C]`.

## `+0x34` on the session: may this machine post?

`0x00A88D70` (rva `0x688D70`) binds a channel to a session. Called with `ecx` = the channel,
`edx` = the session, and a **mode** at `[ebp+0x24]`:

    [session+0x38]  = channel          0x00A88DB9
    [channel+0x1C]  = session          0x00A88E1A   (the back pointer the channel uses)
    [session+0x230] = 0x64             the executed-serial history cap, 100
    mode == 1 || mode == 2  ->  [session+0x34] = 1        0x00A88DDE
    otherwise               ->  [session+0x34] = 0        0x00A88DD9

The mode also picks which channel class the session constructor builds, in `0x00A887A0`:

| mode | channel constructed | at | takes | vftable |
| --- | --- | --- | --- | --- |
| 0 | `0x00B37100` (rva `0x737100`), `0x10C` bytes | `0x00A88CD2` | the address at `session+0xAC` | `0x1607530` |
| 1 | `0x00B34550` (rva `0x734550`), `0xB0` bytes | `0x00A88C25` | the address at `session+0xAC` | `0x1607490` |
| 2 | `0x00B3BE00` (rva `0x73BE00`), `0x8C` bytes | `0x00A88A07` | nothing but the session | `0x16075A8` |
| other; 3 also sets `session+0x30 = 4` | `0x00B3C4D0` (rva `0x73C4D0`), `0x94` bytes | `0x00A88D3C` | a timeout of `0x2710` | `0x1607620` |

So `+0x34` is **not** "a channel exists" - modes 0 and 3 get a channel too, and mode 0's
channel has a post function of its own. It is set for exactly the two modes that are
allowed to *originate* commands.

`0x00A8ADA0` (rva `0x68ADA0`) also sets `[session+0x34] = 1` at `0x00A8AE25`; that function
is reached from the session pump's state machine and was not read further.

## The four channel classes

Six constructors call the shared channel base `0x00B33A60` (rva `0x733A60`) - two overloads
each for the first two classes, one each for the others. **The base has a vftable of its
own**, `0x01607418`, written by `mov dword ptr [edi], 0x1607418` at `0x00B33A80` before it
touches any field, and it is the root: it calls no other constructor. All five tables are
**29 slots** (0 to 28), packed one after another in `.rdata`, and they are related the way a
base and its subclasses should be - 9 slots hold the identical function in all five, and the
base holds `_purecall` (`0x00B961D5`) in **slots 6, 7 and 9**, which are exactly the slots the
subclasses fill in. So post and pump are declared on the base and defined nowhere else:

| class | ctor rva | own vftable | written at | slot 6 (post) | slot 7 (pump) | strings inside them |
| --- | --- | --- | --- | --- | --- | --- |
| base | `0x733A60` | `0x01607418` | `0x00B33A80` | `_purecall` | `_purecall` | - |
| mode 1 | `0x734550`, `0x734710` | `0x01607490` | `0x00B34584`, `0x00B34740` | `0x00B369E0` | `0x00B352C0` | see below |
| mode 0 | `0x737100`, `0x737370` | `0x01607530` | `0x00B3712D`, `0x00B3739D` | `0x00B3A670` | `0x00B3A8C0` | see below |
| mode 2 | `0x73BE00` | `0x016075A8` | `0x00B3BE32` | `0x00B3C0A0` | `0x00B3BF90` | none |
| other | `0x73C4D0` | `0x01607620` | `0x00B3C503` | `0x00B3D500` | `0x00B3C750` | not read |

Each subclass constructor also writes `0x1607518` and then `0x1607504` - but through a
register loaded with `this + 0x7C` or `this + 0x9C`, so those two are the **embedded TBB queue
member's** vftables and not the channel's. The channel's own is always the first of the three
and is written through the register holding `this`.

The same four, by what is in their post and pump:

| vftable | slot 6 (post) | slot 7 (pump) | strings inside them |
| --- | --- | --- | --- |
| `0x1607490` | `0x00B369E0` (rva `0x7369E0`) | `0x00B352C0` (rva `0x7352C0`) | `'Sending targeted asynchronous command: '`, `'New Command to all: '`, `'COMMAND LOST! '`, `'server.cpp'` |
| `0x1607530` | `0x00B3A670` (rva `0x73A670`) | `0x00B3A8C0` (rva `0x73A8C0`) | `'Failed to post order!'`, `'Tick reset to '` |
| `0x16075A8` | `0x00B3C0A0` (rva `0x73C0A0`) | `0x00B3BF90` (rva `0x73BF90`) | none |
| `0x1607620` | `0x00B3D500` (rva `0x73D500`) | `0x00B3C750` (rva `0x73C750`) | not read |

Channel slot 8 returns `[this+0x54]`, the list of commands waiting to execute:
`0x008E90A0`, `mov eax,[ecx+0x54]; ret`. It is **the base's** slot 8 and three of the four
subclasses inherit it unchanged (only the mode 1 class overrides, with `0x00B36CD0`). That
three-byte body sits in 4 table slots, so it is described here and not named.

**Which fields belong to the base.** The base constructor writes `[this+0x1C] = arg2` at
`0x00B33B28` - so the session back pointer is a base field, filled in at construction and
then written again by `Session::BindChannel` - and `[this+0x54]` at `0x00B33B25`, with the
`0x10` bytes for the first list node allocated just above it. It also owns a `0x1FF`-entry
ring at `+0x58/+0x5C/+0x60`. Everything from `+0x7C` up is the subclass's, and `+0x7C` means
**different things in different subclasses**: the TBB queue in the mode 2 class, a second
ring in the mode 1 class. `+0x7C` must not be recorded on the base.

`0x16075A8`'s constructor builds an **Intel TBB `concurrent_queue`** at `this+0x7C`:
`0x00B3BE4E` calls the TBB import at `0xD2B564` for `0x220` bytes of queue representation,
then sets `items_per_page = 0x20` at `rep+0x100` and `item_size = 4` at `rep+0x104`. The
`0x1607490` class does the same at `this+0x9C`, plus a `0x1FF`-entry ring at `this+0x84`.
So the queue holds pointers, and the push is a `lock xadd` on the rep's tail counter at
`rep+0x80` with the micro-queue array at `rep+0x180`.

## The post, `0x00B3C0A0`, step by step

`__thiscall`, `ret 4`, `ecx` = the channel, the command on the stack. This is the one
`CCurrentGameState::AdvanceClock` reaches in a single player game.

1. `0x00B3C0D7`: **command slot 14**, a bool. If false the command is deleted (slot 0 with
   `1`) and the post returns having done nothing else.
2. `0x00B3C105`: `ax = [channel+0x1C]->[0x54]`, zeroed if above `0x7FFF`, stored as a
   **word** at `command+0x34`. `[channel+0x1C]` is the session, so `session+0x54` is a
   turn counter and `command+0x34` is **the turn the command was issued in**.
3. `0x00B3C117`: if `command+0x36` is zero, `lock xadd dword [channel+0x88], 1` and the old
   value goes to `command+0x38`. So `command+0x38` is a **per-channel monotonic serial**.
4. `0x00B3C166`-`0x00B3C208`: a serialisation pass into a writer built by `0x00AD0050` and
   torn down by `0x00AD0180`, with the visitor vftable `0x15FD940`. It writes the command's
   type id (**slot 7**) and then calls **slot 1** with the writer.
5. `0x00B3C22A`-`0x00B3C43D`: a loop over the global array `0x01BEA1A8` (begin) to
   `0x01BEA1AC` (end), a vector of channel pointers. For each element: serialise again
   (visitor vftable `0x15FD968`), hand the bytes to a factory (`[factory+8]`, by type id,
   then **slot 3** on the result to read the fields back), and push the resulting pointer
   into that element's `concurrent_queue` at `element+0x7C`
   (`0x00B3C38A`-`0x00B3C3C7`).
6. `0x00B3C446`: the **original command is deleted**.

So this post round-trips every command through the same serialiser and deserialiser a save
or a wire would use, and the caller never keeps the object it allocated. That matters for
hooking: the pointer `AdvanceClock` passes in is gone by the time the post returns.

`0x00B3DEE0` (rva `0x73DEE0`) is a linear search of that same global array;
`0x00B3EA60`, `0x00B3EC10`, `0x00B3ED60` and `0x00B3EFA0` also touch it. Which of them
registers a channel was not read.

## The post, `0x00B369E0`

Same first two steps (`0x00B36A01`-`0x00B36A17` writes the turn word to `command+0x34`,
`0x00B36A37` takes the serial from `lock xadd [channel+0xA8]`). Then it splits on
`command+0x36`:

- `+0x36 == 0`: the command pointer is pushed straight into this channel's own queue at
  `channel+0x9C` (`0x00B36A85`). No serialisation, no delete.
- `+0x36 != 0`: a `0x3C`-byte record is built and the log line at `0x00B36BEE` is
  `'Sending targeted asynchronous command: '`.

The broadcast is in this class's **pump**, `0x00B352C0`, which is `server.cpp`. At
`0x00B36334`-`0x00B36359`:

    edx = [command]; eax = [edx+0x1C]            ; slot 7, the type id
    call eax
    push &writer; ecx = eax; call 0x00A7A1B0     ; write the type id
    edx = [command]; edx = [edx+4]               ; slot 1
    push &writer; ecx = command; call edx        ; serialise the command
    ...then log 'New Command to all: ' <type id>   server.cpp line 0x37E

That is the same pair of virtual calls, in the same order, as the other post makes at
`0x00B3C1B5`/`0x00B3C1CA`. **One serialiser serves both paths.**

## The drain, `0x00B3BF90`

Loops `try_pop` (`0x00B3E660`) on `channel+0x7C` until it comes back empty. For each item:
call the item's **slot 13**, copy `[item+0x38]` into `[result+0x38]`, append the result to
the list at `channel+0x54`, and delete the item. Slot 13 on a command allocates a fresh
object of the command's own size (`CHourlyTickCommand`'s slot 13 is `0x006DA430` and it asks
`operator new` for `0x4C` bytes, which is exactly what `AdvanceClock` allocates), so slot 13
is a **clone** and the serial is carried across it by hand. On the way out the drain does
`inc dword [channel+0x1C + 0x54]` at `0x00B3C08C` - the session's turn counter advances once
per drain, which is what makes `command+0x34` a turn number rather than a timestamp.

## Where `Execute` is called: `0x00A89940` (rva `0x689940`)

Inside `0x00A89600` (rva `0x689600`), the session's command pump, from `session.cpp`:

    0x00A89659  switch on [session+0x2C]      the session state; 7, 3, then 4/2/0xB/0xC/0xA
    0x00A897B7  [session+0x38] slot 7         pump the channel
    0x00A897C3  bail out if [session+0x234] or [session+0x25E] is set
    0x00A897EB  [session+0x38] slot 8         the pending list, channel+0x54
    0x00A89800  move that list into the vector at session+0x44
    0x00A89844  command slot 14               skip the command if false
    0x00A8985C  [session+0x234] = 1           "a command is executing"
    0x00A89869  log 'Executing command ' <type id> <serial>, gated on byte [0x1A857BE]
    0x00A89940  call [command_vftable + 0x18] *** CCommand::Execute ***
    0x00A89942  [session+0x234] = 0
    0x00A8994E  append [command+0x38] to the list at session+0x220/0x224/0x228,
                trimmed to [session+0x230] (100) entries
    0x00A899F2  command slot 12               if true, slot 13 and a second list at session+0xDC

The same function holds `'Atempted to execute invalid order with stamp '`,
`'Atempted to execute invalid order with token '` and `'Command double! Skipping.'`, and
reads `word [command+0x34]` at `0x00A89CD7`. So the turn stamp and the 100-entry serial
history are both checked here, and the history is what "command double" is decided against.

`0x00A89600` has **23 direct callers**, among them `0x00608B17`/`0x00608B2E`
(`CBackEndIdler`), `0x0064FBD7`/`0x0064FBEE`, `0x00654387`/`0x006545C5`/`0x00654824`
(`CInGameIdler`), `0x006EE14B`/`0x006EE162` (the `CFrontEnd` launch path), and four of the
session's own methods.

## What a `CCommand` is

From `CHourlyTickCommand`'s constructor `0x006DA2C0` (rva `0x2DA2C0`) and a vftable
comparison across `CCommand`, `CHourlyTickCommand`, `CClientPingCommand`, `CAddPlayer` and
`CReopenLobby`:

| Offset | Holds |
| --- | --- |
| `+0x00` | vftable |
| `+0x04` | a class id - `0x18D` for `CHourlyTickCommand` |
| `+0x08` | a `Hoi3CString`, empty at construction |
| `+0x2C`, `+0x30` | the type id, `0x28D` for `CHourlyTickCommand`, written to both |
| `+0x34` | **word**, the issuing turn; `0xFFFF` until posted |
| `+0x36` | **word**, 0 for an ordinary command; non-zero takes the "targeted asynchronous" path |
| `+0x38` | **dword**, the channel serial |
| `+0x3C` | where the subclass's own fields start |

The vftable is 15 slots. The ones used above:

| slot | disp | is | |
| --- | --- | --- | --- |
| 0 | `0x00` | scalar deleting destructor | per class |
| 1 | `0x04` | **`CPersistent::Save`** - `0x0045BB10`, already named in `project.json` at rva `0x5BB10`, and in **865** table slots | shared |
| 2 | `0x08` | the per-class field walker `Save` calls; `CCommand`'s body is `0x00A7BB80`, in only 4 slots | per class |
| 3 | `0x0C` | the `Load` counterpart - `0x00A7C050`, in **870** slots, paired with slot 1 in all of them | shared |
| 4 | `0x10` | `LoadKey` - `0x00A7BC80` is `CCommand::LoadKey` in `project.json` | per class |
| 6 | `0x18` | **`Execute`** - pure in `CCommand` | per class |
| 7 | `0x1C` | the type id, a constant body: `CHourlyTickCommand`'s is `mov eax, 0x28D; ret` | per class |
| 12 | `0x30` | bool, "record me after Execute". `CHourlyTickCommand` and `CClientPingCommand` return false, `CAddPlayer` and `CReopenLobby` true | per class |
| 13 | `0x34` | clone | per class |
| 14 | `0x38` | bool, "may I be posted and executed". Default true; `CAddPlayer` overrides at `0x006D6F50` | per class |

Slots 12 and 14 fall back on the two generic stubs `0x00592360` (`xor al,al; ret`, **1058**
table slots) and `0x00A92590` (`mov al,1; ret`, **611** table slots). Neither is named here,
per the rule about shared stubs.

### The post idiom is universal

The two-instruction pattern `mov r,[x+0x38]; mov r2,[r]; mov r3,[r2+0x18]; call r3` occurs
**337 times** in the image. `[x+0x38]` reaches a virtual call 482 times in total and slot 6
is 337 of those; the next most common slot is 25 sites. With about 105 command subclasses,
several of which post from more than one place, that is the right order of magnitude for
"this is how every command is posted". Functions already named in `project.json` among the
337 include `PostMessage` (rva `0x110A50`), `CInGameIdler::AutosaveCheck` (rva `0x261D20`),
`CCurrentGameState::AdvanceClock` (rva `0x281130`) and `RunHourlyTick` (rva `0x2813F0`, two
sites).

## What is in a posted `CHourlyTickCommand`

`CHourlyTickCommand`'s field walker, slot 2, is `0x006DA4D0` (rva `0x2DA4D0`), and its whole
body is:

    call 0x00A7BB80        ; the CCommand base fields
    esi = this + 0x3C
    call 0x006DB4A0        ; with the visitor and this+0x3C

The constructor at `0x006DA2C0` zeroes `this+0x3C/+0x40/+0x44` and then calls `0x008DD860`
with `CCurrentGameState + 0xC58`; the destructor `0x006DA260` `free`s `[this+0x3C]`. So
**`CHourlyTickCommand+0x3C` is a `std::vector` copy of `CCurrentGameState+0xC58`**
(`random_snapshot` in `project.json`), and it is part of the command's serialised form,
because slot 1 calls slot 2 and slot 2 writes it.

That is the code-level answer to the `+0xC58` question: **the snapshot is not a save-only
field.** It is copied into the command, and the command's serialiser writes it - on the
loopback path as well as on the broadcast path, because both use slot 1.

## What it means for multiplayer - this section is a reading, not a reading-off

1. **The snapshot is in what a peer would be sent.** The `server.cpp` pump serialises
   commands with the same slot 1 that writes `+0x3C`, and logs `'New Command to all: '`.
   *What is not established* is the path from that writer's buffer to `send()`. `WS2_32.dll`
   is imported (26 functions - `socket`, `bind`, `listen`, `accept`, `connect`, `send`,
   `recv`, `select`, `WSASendTo`, `WSARecvFrom`, so TCP and UDP both). `send` is reached
   from only two functions, `0x00B460F0` and `0x00B47760`, both of which are virtual slots
   (of the vftable running from `0x01607F74`, next to `'ladderacculator.cpp'`) with no
   direct callers. I did not link a channel to either step by step.
2. **The gate byte and who drives the clock.** `[session+0x34]` is 1 only for modes 1 and 2,
   and `CCurrentGameState::AdvanceClock` tests exactly that byte at `0x006811E5` before it
   allocates a `CHourlyTickCommand`. Modes 0 and 1 are the two that carry a remote address;
   mode 1's channel is the `server.cpp` one that broadcasts, mode 0's channel logs
   `'Tick reset to '` in its pump. The reading is **mode 2 = single player loopback,
   mode 1 = host, mode 0 = client**, so on a client the hour is advanced by the host's tick
   command arriving rather than by the client's own frame loop, and the same byte gating the
   autosave's third branch in `FINDINGS-autosave.md` fits: a client does not decide to save
   either. *This mapping is inference from the strings and from which modes take an address.*
   Nothing was run.
3. **The practical rule for a mod.** Everything a player or the AI does becomes a command,
   the commands are serialised, turn-stamped, serialised again on the wire and executed in
   one ordered loop. Anything a mod does that changes game state or draws from the
   generator *outside* a `CCommand::Execute` is outside that ordered path. The two places
   worth watching rather than guessing are `0x00A89940` (rva `0x689940`) for "a command is
   about to run", and a channel's slot 6 for "a command has been posted". Both are on the
   thread that owns the session; the TBB functors in `FINDINGS-tick.md` are not.
4. **What is not shown** is that a mod's own draw from the generator desyncs a session. The
   generator bookkeeping travelling with the tick means peers have a way to notice a
   divergence, or to be corrected by it; which of the two, this document does not establish,
   because nothing here read the receiving side's use of `command+0x3C`.

## Which classes are network-related

From the RTTI export. None of these were named in `project.json` before:

- Commands (all with 15-slot vftables, so all `CCommand` subclasses): `CAddPlayer`,
  `CPlayerConnected`, `CReopenLobby`, `CResetGame`, `CStartGame`, `CLobbyStartGame`,
  `CPauseGame`, `CSetGamePlayOptions`, `CChatBuffer::CWriteToChatBuffer`.
- Infrastructure: `CMetaserverInterface`, `CServerInterface`, `CServerMessagehandler`,
  `CChatMessagehandler`, `CMessageHandlerInterface`, `CSessionConfiguration`,
  `CSessionInfoObserver`, `CMultiplayerHandler`, `CIngameLobby`, `CLobbyInterface`,
  `CGameList`, `CEU3GameLauncher`, `CGameSetup`, `CLobbyHumanItem`, `CGameHandlerInterface`,
  `CGameLaunchInterface`.
- `CClientPingCommand` has its loader named in `project.json` but no RTTI record under that
  name; its slot 6 is `0x006DAA30` and its slot 7 is `0x006DB2E0`.

The command and network machinery itself has **no RTTI at all** - the session, the four
channels and the socket layer are vftables with no type descriptor - which is why this
document names them by what they do and by the `.cpp` their log lines quote.

The string tables in those two regions are worth having written down, because they say what
the layer does better than any inference:

- `session.cpp` region (`0x00A88000`-`0x00A90000`): `'Executing command '`,
  `'Atempted to execute invalid order with stamp '`, `'...with token '`,
  `'Command double! Skipping.'`, `'REQUESTING SYNCH'`, `'Machine id '`,
  `'Accepted hotjoin, sending message'`, `'Connected with previously empty gamestate'`.
- channel region (`0x00B33000`-`0x00B40000`): `'New Command to all: '`,
  `'Sending targeted asynchronous command: '`, `'COMMAND RECEIVED'`,
  `'EARLY COMMAND RECEIVED'`, `'COMMAND LOST! '`, `'Failed to post order!'`,
  `'Error while sending orders.'`, `'Tick reset to '`, `' on tick '`, `' commands'`,
  `'WAITING FOR SYNCHCOMPLETE'`, `'ASYNCHRONOUSLY_CONNECTED'`, `'Failed to send gamestate to '`,
  `'Reading Game State'`, `'New Client Connected'`, `'Banned client attempt'`,
  `'Bad bad version'`, `'server.cpp'`, `'localhost'`.

## What is not established

- **The class names.** `session.cpp` and `server.cpp` are the file names the log lines
  carry; the classes have no RTTI, so "session" and "channel" here are descriptions, not
  recovered names.
- **The link from a channel to `send()`.** See point 1 above.
- **Which of the pump's 23 callers runs per frame in a live game.**
  `CInGameIdler::Update` (`0x006559D0`) does not call `0x00A89600` directly; at `0x00656558`
  it calls `0x00739CA0` with the frame delta and `[manager+0xE4]`, and that was not
  followed. So "commands execute once a frame" is *not* shown here - only that they execute
  in `0x00A89600`.
- **Whether `0x00A89940` is the only `Execute` call site.** Slot 6 is displacement `0x18`
  like any other; `slotcalls.py 6` finds 1523 sites in 959 functions, so uniqueness cannot
  be scanned for. It is the site in the queue path, and the one the hourly tick reaches.
- **Mode 3 and the fourth channel** (`0x1607620`, post `0x00B3D500`, pump `0x00B3C750`).
  Not read. Its `0x2710` argument looks like a ten-second timeout, which would fit a
  metaserver or lobby channel.
- **Which function registers a channel in the global array** at `0x01BEA1A8`, and so how
  many entries it has in a real game. One in single player is the obvious answer and has
  not been checked.
- **`session+0x2C`, the state.** Values 0, 2, 3, 4, 7, 0xA, 0xB, 0xC are branched on in the
  pump and the bind writes 4. That 4 is the in-game value is inferred only from the bind
  setting it for modes 1 and 2.
- **`session+0x68 = 2` and `session+0x6C = 1`**, both written by the bind. Unknown.
- **`0x01A857BE`**, the byte that gates the `'Executing command '` log. That is the switch
  that would make the game write every command it runs to its own log file, which would be
  worth having.
- **`CInGameIdler+0x178C`** (`CFrontEnd+0x20C`, `CBackEndIdler+0xB4`), returned by idler
  slot 17, and `[manager+0x124]`, returned by slot 14. Neither identified.
- **`0x0174DA90`**, a lazily created singleton with vftable `0x15FDF60` whose slot 1 result
  is stored at `manager+0x128`. It sits **between** `g_random_draws` (`0x174DA8C`) and the
  still-unidentified `0x174DA94` that the hourly snapshot records. That the three are
  adjacent may mean nothing; it may also mean the two dwords in the snapshot are not both
  about the generator. Not investigated.

## One thing that contradicts the existing record

`project.json` names rva `0x67C050` **`CParseContext::ReportMessages`**. That address is
`CCommand` slot 3, and it sits in **870** table slots, paired in every one of them with
slot 1 = `0x0045BB10`, which the same file already names `CPersistent::Save` (865 slots).
Slot 1 and slot 3 are the Save and Load pair of the persistence framework. The existing
name looks like a misattribution to one of its many callers. Nothing is redefined here.

`FINDINGS-tick.md` lists, under what it does not establish, "whether the `+0xC58` snapshot
is actually sent to peers, or only kept for the save". The code half of that is now
answered: the snapshot is copied into the command and the command's serialiser writes it,
on both the loopback and the broadcast path. That document's caution - "nothing here traced
the command onto a socket" - still stands for the socket half, and still stands after this
one.
