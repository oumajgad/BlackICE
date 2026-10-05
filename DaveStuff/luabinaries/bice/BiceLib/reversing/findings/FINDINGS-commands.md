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

## The wire format: binary, and only on the broadcast path

Settled 2026-10-04, which closes half of open item 1 below: the question was never only
*how* a command is serialised but *into what*, and `CSaveWriter` has a `binary` byte that
changes the answer completely.

The broadcast builds its writer on the pump's own stack at `[ebp-0xA0]`: vftable
`0x015FD940`, `depth` from ESI, `stream` from a 0x3C-byte object out of `operator new`, and
**`binary` as `(stream->+0x13 != 0)`** at `0x00B36327` - not a constant. That stream comes
from `SaveStreamConstruct` (`0x00AD0050`, rva `0x6D0050`), whose fourth argument picks the
format: **0 sets `+0x13` and means binary, 1 clears it and means text.** The call at
`0x00B362FD` passes ESI, and the last write to ESI before it is `xor esi, esi` at
`0x00B362C5`.

**So a command goes onto the network in binary** - token ids two bytes each, the payload
after each, whitespace tokens dropped - and through exactly the same slot 1 / slot 2 pair
that writes a savegame. There is no command-specific format at all; the binary flag on the
writer is the whole difference.

### The two branches of the mode 1 post

Worth stating next to it, because the two are not variations on each other. **This table is
about `0x00B369E0` only** - the mode 1, host channel's post - and the column headings are
its own `+0x36` test:

| | `+0x36 == 0`, this host's own queue | `+0x36 != 0`, broadcast |
| --- | --- | --- |
| what is queued | **the command pointer** | its bytes |
| serialised | **never** | slot 7 type id, then slot 1 |
| on the way out | cloned through slot 13 | rebuilt on each peer |

**This table used to be headed "And only the broadcast serialises", with its first column
labelled "loopback", and that cost a session.** "Loopback" is the name of a *different
channel class* - the mode 2 one a single player session gets, whose post is `0x00B3C0A0`
and which **does serialise**, as the step-by-step above it says and as
`LoopbackCommandChannel::Post` in `project.json` has always said. Anyone reading the table
for "what happens in single player" got the opposite of the truth. The record was right and
the summary of it was wrong, which is the more dangerous way round.

So, the thing the old table was reaching for, stated without the ambiguity: **a command may
only carry what survives a round trip through this writer**, because on every path except
one branch of one channel's post it is torn down to bytes and rebuilt. That is why
`CAssignLeaderCommand` holds its unit and its leader as `CPersistent` id pairs rather than
as pointers - see point 5 of the multiplayer section.

Which channel serialises, in one place:

| channel | post | serialises? |
| --- | --- | --- |
| mode 0, client | `0x00B3A670` | not read |
| mode 1, host | `0x00B369E0` | only the `+0x36 != 0` branch |
| **mode 2, single player** | `0x00B3C0A0` | **always**, and round-trips through the factory |
| other | `0x00B3D500` | not read |

### The reading half - read 2026-10-04, and it is symmetric

The counterpart was found by asking which functions in the network region build a
`CParseContext` (`findRefs.py --callers 0xA7A460`): two do, and `slotcalls.py 3` filtered to
the same region gives a third, which is the command one. All three have the same shape, so
this is the house style rather than one path's trick:

    stream  = operator new(0x3C); SaveStreamConstruct(stream, bytes, 1, 0, 0)   ; format 0 = binary
    tok     = 0xA6A800(stream)                                                  ; the tokenizer
    CParseContext::CParseContext(&ctx, ..., tok)                                ; 0xA7A460
    ParseReadKeyValue(&ctx)                                                     ; 0xA7ACB0 - the type id

and then, at `0x00B3C338`-`0x00B3C36E`, the part that was missing:

    obj = factory->slot2(..., typeId)       ; 0xA7BDA0, below
    if (obj == 0) skip
    obj->slot3(&ctx)                        ; CPersistent::Load, then slot 4 LoadKey per key

**The factory is a registry of prototypes, and instantiating is cloning.**
`CreatePersistentByTypeId` (rva `0x67BDA0`) is slot 2 of the three-slot vftable at
`0x015FD968` - 0x28 past `CSaveWriter`'s `0x015FD940`, the same translation unit, and its
error path names the file: `'order.cpp'`. It hashes the type id into a table whose bucket
count and bucket array are the runtime-filled globals `[0x1B16644]` and `[0x1B16648]`, walks
the bucket comparing each entry's object at **`+0x30`** - the type id field the command
constructors write - and then clones the match through **slot 13** (`mov eax,[edx+0x34];
call eax` at `0xA7BEF9`).

So **slot 13 is not only the drain's clone: it is also how a command arrives off the wire.**
One mechanism, two uses, which is why every command has to have it.

The round trip entire:

| | out | in |
| --- | --- | --- |
| the type | slot 7, written by `SaveWriteKey` | `ParseReadKeyValue`, then the prototype table |
| the object | - | **slot 13**, cloned from the prototype |
| the fields | slot 1 `Save` -> slot 2 walker -> `SaveWrite*` | slot 3 `Load` -> slot 4 `LoadKey` -> `Parse*` |
| the format | `CSaveWriter::binary` | the stream's own `+0x13`, set the same way |

### Who fills the prototype table - read 2026-10-04

A startup pass, as guessed, and **unrolled**. Three globals, all zero in the file:
`[0x1B16640]` the entry count, `[0x1B16644]` the bucket count and `[0x1B16648]` the bucket
array.

`PersistentRegistryInit` (rva `0x67BFA0`) sets the bucket count to **511**, allocates and
zeroes `511 * 4` bytes for the array, and answers the address of the count - the MSVC shape
of a function-local static's initialiser. Its one caller is `0xD1E7A0`, in the CRT
initialiser range, so the table exists before any game code runs.
`PersistentRegistryClear` (rva `0x67BFF0`) is the teardown, one caller at `0xD283E0`, and it
settles the node layout: a bucket is a singly linked list of **8-byte heap nodes
`{ object +0, next +4 }`**, and it frees the nodes but not the prototypes.

`RegisterCommandTypes` (rva `0x485050`) is the filling - and it was **already in the record**,
as the function that "calls the default constructor of every command class in the game so the
command factory has a prototype of each", marked `likely`. That was right; this run upgrades it
and locates the factory it was pointing at. One block per class:

    proto = operator new(<size>); <ctor>(proto)
    bucket = proto->+0x30 / [0x1B16644]          ; div, remainder in EDX
    node = operator new(8)
    node->object = proto; node->next = buckets[bucket]
    buckets[bucket] = node
    ++[0x1B16640]

**The key is the prototype's own `+0x30`** - the type id both command constructors write -
so a class registers itself under the id its slot 7 returns and the table carries no
separate key. Read from the entry, the first block allocates `0x44` bytes and calls
`0x40B610`, which writes `CCommand`'s vftable then `CBattlePlanSendCommand`'s.

**66 registrations in that body and 68 image-wide** - the other two are at `0x884B43` and
`0x884B50` - counted by the byte encoding of `inc dword ptr [0x1B16640]` over the recorded
extent rather than by decoding. Two caveats, both load-bearing: it is a count of **one
encoding**, so read it as a floor; and the existing entry counts "about a hundred"
constructor pairs in the same body, so **not every class constructed there is necessarily
registered**, and which are not is unestablished.

*Two things here came from the record rather than from this run, and both matter.* Decoding
0x2200 bytes from the entry found no `ret` at all and I nearly wrote the function up as
unbounded - the entry already had `0x885050-0x887F37`, and the bare `ret` is at `0x887F36`,
which the full extent confirms. And naming it was a **duplicate**: rva `0x485050` was
already recorded, `grep 0x485050 ghidra/project.json` was one command, and I did not run it
before inserting. The duplicate has been withdrawn and the original revised. Trap 14,
committed by the session that writes trap 14 into everyone else's briefs.

*A method note, because the first attempt at this was a false negative.* A read/write
classifier over `findValue`'s hits reported "no writers anywhere" and then, fixed, reported
140 confident reads that were **all garbage**: `findValue` returns the displacement's
address, and walking back one byte to find the instruction happily decodes
`xor eax, 0x1B16644` out of the middle of a real instruction. Its positive control - a
hand-verified read inside the lookup - failed both times, which is the only reason the
output was thrown away rather than believed. What actually worked was `findBytes` on
specific encodings (`FF 05`, `A3`, `C7 05`), which cannot land mid-instruction because the
opcode is part of the pattern.

**Still not established**: slots 0 (`0xA6F290`) and 1 (`0xA7C3D0`) of the factory's vftable,
whether anything registers prototypes outside those 68 sites, and the path from the writer's
stream to `send()`.

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
5. **Being inside `Execute` is not enough: the decision's *inputs* have to be on the ordered
   path too.** This sharpens point 3, which on its own reads as "put your state change inside a
   `CCommand::Execute` and you are safe" - and that is only half of it. `Execute` runs on **every**
   peer, so anything it reads that exists on one machine only makes it do something different on
   each: a pressed key, `CInGameIdler`'s selection (it holds its own session's and nobody else's),
   `played_country_id`. The command's own fields are the ordered path; the machine it happens to be
   running on is not.

   **Worked example, and the first thing in this document that was actually run.** BiceLib's
   "hold Ctrl to unassign only the selected units" was first built by filtering inside
   `CRemoveAllLeadersCommand::Execute` (rva `0x1D8440`), whose loop strips the leader off every
   unit of one country. The filter read the Ctrl key and the local selection, so the client that
   pressed the button stripped three units and every other client stripped fifty. An owner check
   added in the belief that it guarded against this made it **worse**, not better: it limited the
   filter to the machine whose player owned the units, which is precisely the divergence.

   The fix was to move the choice to where the command is *built* - `CConfirmRemoveAll::OnConfirm`
   (rva `0x348840`), a GUI handler, which runs only on the machine whose player clicked. Reading
   the keyboard and the selection **there** is fine, because what leaves it is one
   `CAssignLeaderCommand` per unit, and that command keeps each end as a `CPersistent` id pair
   rather than a pointer - so every peer resolves the same objects. **Tested in multiplayer on
   2026-10-04: it works.** That is one observation and it does not settle section 302's other
   readings, but it is the first support any of them has had.

   So the rule, for a mod: **a local input may choose which commands to post, never what a
   command does when it runs.** If the thing you want is not expressible as a command that names
   its own targets, the honest options are to add the per-target command or to stay out of
   multiplayer - not to read local state in `Execute` and hope.

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

## Building one: read and written 2026-10-05

The implementation is `BiceLib/Commands/CBiceCommands.cpp` and its header carries
the design. This section is the reversing half - what had to be read, and the two places
the plan in `PLAN-customcommand.md` turned out to be wrong.

### The plan had the step order backwards

It sequenced "a payload-free command in single player" before "register the token", on the
strength of the summary table corrected above. Both are wrong the same way: **the single
player post serialises and rebuilds the command through the prototype registry**, so
registering a prototype is a prerequisite for single player, not a multiplayer refinement.
Decoded at `0x00B3C0A0`: `SaveStreamConstruct` with EBX as the format argument and
`xor ebx, ebx` at `0x00B3C0C7` (so **binary**, both of its streams), slot 7 then
`SaveWriteKey`, slot 1, then a second stream, the binary tokenizer,
`ParseReadKeyValue`, `CreatePersistentByTypeId` at `0x00B3C353`, and
`cmp eax, ebx; je 0x00B3C36E` at `0x00B3C355`.

That `je` is worth being precise about: **it skips the Load, not the post.** Execution falls
into the queue push either way. So an unregistered type id is not a clean no-op in single
player, and what reaches the execute queue in that case was not established - which is
reason enough for the DLL to refuse to post until it has registered.

### Three payload-free command classes exist, and they are the donor

A class whose virtual **slot 2 is `CCommand::SaveContents` itself** has no fields of its own
past `+0x3C`. Searching `.rdata` for that function's address finds four slots:

| table | class | type id |
| --- | --- | --- |
| `0x015B4F74` | `CCommand` - its own abstract table, slot 7 `_purecall` | - |
| `0x015D3094` | `CClearAllControllersCommand` | `0x38A` |
| `0x015D362C` | `CIncreaseGameSpeedCommand` | `0x292` |
| `0x015D366C` | `CDecreaseGameSpeedCommand` | `0x293` |

So a custom payload-free command does not need six slots written by hand: **copy one of
those tables and override three.** `Execute` (6), the type id (7) and the clone (13) are
ours; slot 0, 1, 2, 3, 4, 12, 14 and the five unexamined ones are the game's own working
implementations and cannot be got subtly wrong because they are not ours.

Why each of the three must be ours, and no others:

- **Slot 7** is the type id, and the whole point is that ours differs.
- **Slot 13** ends `mov dword ptr [esi], 0x15D362C` - it stamps *the donor's* vftable into
  the object it makes, so a borrowed clone hands back an object of the donor's class and our
  `Execute` never runs. Ours delegates to the donor's and rewrites that one dword. The type
  id needs no rewriting, because `CCommand::CCommand` (rva `0xB530`) copies `+0x2C`/`+0x30`
  from the source.
- **Slot 0 does *not* have to be ours**, which is the useful surprise. `CCommand::~CCommand`
  (rva `0x14E1E0`, 77 table slots) frees with a plain `free(this)` and is handed no size, so
  it is correct for a subclass of any size - provided the object came from the game's own
  `operator new`.

### Slot 13 takes an `std::string` by value

`ret 0x1C`, and both callers agree: `CreatePersistentByTypeId` at `0xA7BED4` and the
loopback drain at `0xB3BFE3` each `sub esp, 0x1C`, build an empty string in that space, and
call through `[vftable+0x34]`. The callee owns it - the donor frees its buffer when the
capacity at `+0x14` is `0x10` or more. Two callers agreeing is the check; one would not
have been. What the string holds, built from `factory+0x32C` or `session+0xBC`, was not read.

In MSVC this is expressible without assembly as a `__fastcall` with a placeholder second
parameter, because `__thiscall` and `__fastcall` are the same machine contract once the
receiver is in ECX. Verified on the built DLL rather than trusted: slot 7 compiled to
exactly `mov eax, 0x13; ret`, and slot 13's two exits both `ret 0x1C`, the live one
preceded by the single `mov dword ptr [eax], <our vftable>`.

### The type id: a built-in gap beats a registered token

The plan's step 2 was to register a save token, and the blocker was that
`BuildTokenTable`'s appender had not been read. **That step is not needed, and registering
a token would have been the worse choice anyway.**

A mod-registered token is numbered in **load order**, so its id depends on what content is
loaded and in what sequence. A command's type id has to be identical on every peer or the
factory answers 0 there and the command is silently dropped - so load-order numbering turns
a content difference into a desync. A gap inside the **built-in** range is the same number
in every process that runs this executable.

`0x13` is such a gap: one of `0x7`, `0xA` and `0x13`, the three ids the binary tokenizer
routes as ordinary keys while the built-in table holds a default-constructed empty string
for them. The index is valid, so `TokenText`'s unchecked `begin + id * 0x1C` is safe, and
there is no name to collide with.

Is it free? Of the 865 `.rdata` slots holding `CPersistent::Save`, **196 have a constant
`mov eax, imm32; ret` in slot 7**; the lowest id any of them claims is `0x8A`, and none
claims `0x7`, `0xA` or `0x13`. Positive control: `0x28D`, `CHourlyTickCommand`'s, turns up
exactly once. **The negative is a floor and not a proof** - 669 of those tables have no
constant slot 7, so a class computing its id another way would be missed, and the registry
holds every `CPersistent` prototype rather than only commands. So the DLL **walks the live
bucket at registration and refuses if anything already claims the id**: the static search
chooses the number, the runtime check is what makes it safe. A collision would be quiet and
nasty, since our node is prepended and would win the lookup, stopping the other class from
deserialising.

### The registry insert, and its globals

Four writes after the game's own init, mirroring `RegisterCommandTypes`: build the
prototype, allocate an 8-byte node, prepend it to bucket `id % 511`, bump the count. The
three globals are **virtual addresses** in the findings prose, which is how that document
writes everything; as the rvas a `GameClasses` header wants they are

| va | rva | holds |
| --- | --- | --- |
| `0x01B16640` | `0x1716640` | the entry count |
| `0x01B16644` | `0x1716644` | the bucket count, 511 once initialised |
| `0x01B16648` | `0x1716648` | the bucket array |

All three are zero-fill `.data`, so the executable file carries no value for them - the
expected answer, not a failed read, and `g_CCurrentGameState` behaves identically as a
positive control. The save-token vector's `begin`/`end` are `0x17165B4`/`0x17165B8` on the
same footing.

### What this still does not establish

- Whether a posted-but-unexecuted command can reach a savegame. Nothing was read about it.
- What reaches the execute queue when the factory answers 0, as above.
- `CCommand +0x24` and the word at `+0x28`: copied by the base copy constructor, so they
  travel with a command, but what they hold was not read. They are not in this document's
  `CCommand` layout table.
- `CIncreaseGameSpeedCommand::Execute` (rva `0x2DA5C0`) was deliberately **not** recorded.
  Its entry reads the game-state global and branches, and the branch taken when the state is
  absent constructs a `0xDA8`-byte object with `CCurrentGameState`'s vftable, which is not
  what an "increase game speed" command should plausibly do. The implementation did not need
  it, and half a reading is worse than none.

## A payload instead of more type ids - 2026-10-05

The first custom command worked but it does not scale, and the reason is arithmetic. A type id
has to be a token the table really covers, because it comes back through `TokenText`'s
unchecked `begin + id * 0x1C`; inside the built-in range only **three** ids are both unclaimed
and routed as ordinary keys by the binary tokenizer - `0x7`, `0xA` and `0x13`. Registering new
tokens is not an escape: mod tokens are numbered in **load order**, so their ids depend on what
content is loaded and in what sequence, and a type id that differs between peers is dropped on
the peers that do not know it.

Three ids is not a framework. So `CBiceCommands` spends **two, once, for ever**: `0x13` is the
type id of a single class and `0x7` is the one key inside it, whose value is the whole payload
as a string. `0xA` is left spare. Which action and its arguments live *inside* that string, in
a format of our own, where ids cost nothing.

Format "B1": fixed-width uppercase hex, `"B1" <kind:4> <count:2> <arg:8>*count`, so the whole
string is `8 + 8 * count` characters and its length alone validates it. Text rather than raw
bytes because the value goes out through `SaveWriteString` and comes back through
`ParseString`, which quote it in a text save and copy it raw in a binary one - an alphabet with
no quote, no backslash, no whitespace and no `\xA7` colour marker survives both unescaped.

### Where a payload may not live, and what that costs

**Not in the base's `Hoi3CString` at `+0x8`.** That was the tidier plan, because the base
already constructs and destroys one there and the object would have stayed exactly `0x3C`
bytes. But `CCommand::LoadKey` (`0x67BC80`) touches it **before its switch and for every
key**: it compares `+0x8` against the empty string and, when it is empty, assigns it from
`parse+0x32C`. `+0x8` is a field the base writes on the load path, not spare space.

That one reading is what makes the object bigger than the base, and that in turn is what makes
**slot 13 a full clone rather than a delegation**. `CBiceCommand` could hand the work to the
donor's own clone and rewrite one dword, because it was the base's size; the donor's clone
allocates `0x3C`, so anything larger has to allocate, construct, copy the base scalars and
destroy the by-value string argument itself. The payload must survive it: the loopback pump
clones every item off the queue and it is the clone that executes.

While it was being read, two entries in the record were corrected:

- **`ParseString`'s receiver is confirmed**, where the entry said "the register is inferred".
  The parse context is in **ECX**; three independent call sites agree, each inside a `LoadKey`
  doing `mov ecx, [ebp+8]` then pushing a destination and a flag - `0xB3208B`, `0xB45640`,
  `0xB57172`. `ret 8`.
- **The game's `std::string` is `0x18` bytes**, settled by `ParseString` building one of its
  own on the stack at `0xA7AFCF`: buffer at `+0`, size at `+0x10`, capacity at `+0x14`.
  BiceLib's `Game::String` asserts exactly that and has been right all along. Slot 13's
  `ret 0x1C` is that `0x18` plus four bytes of argument slack, not a bigger type.

### What the built DLL was checked for

Five slots, five different stack contracts, and a wrong `ret` immediate on any of them
corrupts the stack - slots 2 and 4 on every command serialised or loaded, slot 13 on every
command that arrives. So the compiler's output was fingerprinted rather than trusted:
slot 7 `mov eax, 0x13; ret`, slot 2 `ret 4`, slot 4 `ret 8`, slot 6 a bare `ret`, slot 13
`ret 0x1C`. Re-checked after the implementation was rewritten, because "it compiled" says
nothing about a `ret` immediate.

*A method note.* Searching the DLL for `mov ecx, 7` (`B9 07 00 00 00`) to prove the payload
token reaches `SaveWriteKey` found six sites, none near our code, and that looked for a moment
like a missing write. It was a failed guess at an encoding: the compiler had materialised the
constant as **`lea ecx, [edx + 7]`** in three bytes instead of five, having just zeroed EDX.
Reading the body settled in one pass what byte-pattern search had made look like a bug -
the same lesson as the read/write classifier that produced 140 confident rows of garbage.

### Still unestablished

- Whether a posted-but-unexecuted command can reach a savegame. Nothing read.
- What `ParseString`'s second argument selects; 0 at two of three sites.
- Which of `CCommand::LoadKey`'s three names belongs to which of `0xC3`, `0xC8`, `0xF3`. The
  ids and the `0xF3` arm's destination (`+0x38`, the serial) are read; the pairing is not.
- `CCommand +0x24` and the word at `+0x28`: carried by the base's copy constructor, so they
  travel with a command, but what they hold was not read. Our clone copies them because the
  game's does.
