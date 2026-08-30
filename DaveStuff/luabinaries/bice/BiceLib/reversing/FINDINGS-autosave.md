# How the game decides to autosave

Worked out for the Custom Auto-Saves feature. Read statically out of `hoi3_tfh.exe`
and then checked against the running game; what was checked and what was not is marked
on each claim.

Addresses are absolute against an image base of `0x400000`, the way the RTTI export
writes them. Subtract `0x400000` for a module relative address.

## The short version

Deciding and doing are two different functions, one frame apart, joined by a single
byte on `CInGameIdler`:

```
CInGameIdler::dailyUpdate  0x661CA0   virtual, slot 53; repaints, then always checks
  -> autosaveCheck         0x661D20   decides, and writes [idler+0xAB0]
CInGameIdler::update       0x6559D0   runs every frame
  -> autosaveWrite         0x64FF80   reads [idler+0xAB0] and writes the file
```

**`0x66202D` - `mov byte ptr [edi+0xAB0], 1` - is the only place in the executable that
raises the flag** (**read**: the byte pattern for a `0xAB0` displacement appears 31
times, and this is the only one that stores a 1). That makes it the choke point: set
that byte and the game autosaves, clear it and it does not.

## The decision, `0x661D20`

One argument, the `CInGameIdler*`, pushed on the stack; `ret 4`.

```
1  ensure CCurrentGameState exists      global 0x1A89790  (module + 0x1689790)
2  tick = gameState[0xBDC]              the current tick
3  idler[0xAB0] = 0                     clear first, every time
4  if (gameState[0xD9D] != 0) return    a gate, meaning not established
5  debugSaves = settings[0x158]
   if (debugSaves != 0) -> the debug path below, the frequency is not consulted
6  switch (settings[0x15C])             the autosave frequency
7  if the date matches -> idler[0xAB0] = 1
```

Step 3 is worth noticing: the flag is cleared at the top of every check, so it is only
ever live for the part of a frame between the decision and the write.

### Where the two settings live

`0x45FF30` is the settings singleton's getter - `[0x1A863F8]`, `module + 0x16863F8`,
`0x18C` bytes, the same object `settings+0xF4` in `FINDINGS-mapmode.md` belongs to.

| Field | Is | |
| --- | --- | --- |
| `settings + 0x158` | `debug_saves` from `settings.txt` | **seen**: 0 live, and the file says `debug_saves=0` |
| `settings + 0x15C` | the autosave frequency, as the enum below | **seen**: 3 live, and the file says `autosave="HALFYEAR"` |

`0x45FFB0` turns the string into the number and `0x4600C0` turns it back; the parser at
`0x460383` is what stores it (**read**).

| Value | `settings.txt` | Fires on |
| --- | --- | --- |
| 0 | `NEVER` | never - `dec eax; cmp eax,4; ja` sends 0 straight out |
| 1 | `WEEKLY` | `(days - 1) % 7 == 0` |
| 2 | `MONTHLY` | the 1st of any month |
| 3 | `HALFYEAR` | the 1st of January and the 1st of July |
| 4 | `YEARLY` | the 1st of January |
| 5 | `FIVE_YEAR` | the 1st of January of a year divisible by 5 |

The default the constructor writes is 4, `YEARLY` (`0x45FB7E`, **read**).

`debug_saves = N` is not a boolean: with it set the frequency is ignored entirely and
the game saves on the 1st of every Nth month (`idiv edi` at `0x661FDB`, **read**).

### The date helpers

All four take the tick and start with `(tick - 0x29C55C0) / 24`, which is
`(tick - 43800000) / 24` - days since the epoch `CLASSES.md` already records. The year
is 365 days with no leap day, and the month lengths are the table at `0x1713294`:
31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 (**read**).

| | Returns |
| --- | --- |
| `0xAAABA0` | `(days - 1) % 7`, the day of the week |
| `0x44C5C0` | the day of the month, 0 based |
| `0x42EEF0` | the day of the year, 0 based |
| `0x42EF40` | the year, absolute - 1937 in the running game, not an offset from 1936 |

### The two gates before the flag is set

Reached at `0x661E19` once the date matches:

```
if (idler[0x68] == 0)          -> set the flag
else if (vf[0x48]()[0x34] == 0) -> set the flag
else                            -> allocate 0x40 bytes and send something instead
```

`idler[0x68]` is **0 in the running single player game** (**seen**), so the first
branch is the one that runs. The third branch builds an object and makes a virtual
call, which looks like telling the other end of a multiplayer session to save, but that
is inference and has not been tested.

### `0x661CA0` is not a timer dispatch

Recorded as one at first, on the strength of `[this+0xD34]` being compared against 4,
`0x12` and `0x13` with each branch calling the autosave check. That was wrong, and the
map mode work already had the answer: **`+0xD34` is the current map mode**, and 4, 18
and 19 are Supply, Air and Naval - the three modes whose colours change with the day.
The branch for mode 4 calls `0x666EE0`, which `mapmode.py` already lists as mode 4's
colouring routine.

So the function is a daily update: repaint the map if it is showing one of the three
that go stale, then check the autosave. The check is **not** conditional on the map
mode - the fallthrough at `0x661D0C` calls it too, so it runs on every call whatever is
on screen.

Nothing was built on the wrong reading, because the hook is on the check itself and
that is reached the same way either way. It is written down because a false "this only
runs in three map modes" would have been very hard to find later.

## The write, `0x64FF80`

Called once per frame from `0x6559D0` with the idler as its only argument.

```
if (idler[0xAB0] == 0) return
if (idler[0xAB1] == 0) { idler[0xAB1] = 1; return }   ; one frame of delay
...build the name and write...
```

So a raised flag costs one extra frame before anything is written. `0x675090` is the
virtual setter for the pair (slot 92 of `CInGameIdler`'s vftable) and clears `0xAB1`
whenever `0xAB0` is set to 0.

The name depends on `debug_saves` (**read**, and the files on disk agree):

- `debug_saves == 0` - three rotating files, `autosave.hoi3`, `oldautosave.hoi3`,
  `olderautosave.hoi3`, shifted along on each save.
- otherwise - `<gameState+0xC30>` + `autosave_` + ... + `.hoi3`, one file per save.

`0x671370` also writes a save and also owns the string `Failed to write save file `,
but it takes the save dialog rather than a name, so it is not a usable "save as this
name" entry point.

## The class

`CInGameIdler`, vftable `0x15CEB54`, 111 slots (**RTTI**). One live instance
(**seen**). Fields that matter here:

| Offset | Holds | |
| --- | --- | --- |
| +0x68 | 0 in single player; the multiplayer branch reads it | seen |
| +0xAB0 | **autosave requested** | read, and it is the choke point |
| +0xAB1 | the write has already waited its frame | read |
| +0xD34 | **the current map mode**, not a timer - see the correction below | read |

## What is not established

- `gameState + 0xD9D`, the gate at step 4. It is 0 in a running game, so it is not
  "a game is loaded"; more likely "the game is over" or "a save or load is in
  progress". Nothing depends on it yet.
- `idler + 0x68` as multiplayer. It fits, it has not been tested.
- What calls `0x661CA0`. It is virtual, slot 53 of `CInGameIdler`, and nothing reaches
  it directly, so the caller has not been traced.

## What BiceLib does with it

Custom Auto-Saves, on the Options page. It adds one save a month, a configurable
number of days before the month turns, because the game evaluates event trigger
conditions on the month change and only then: a save made after that moment has
already had its evaluation, so loading it fires nothing for that month.

It sits alongside the game's own autosave. The frequency in `settings.txt` keeps
working untouched, and switching the feature off leaves the game deciding on its own.

Two stubs, in `Hooks/AutoSaveHooks.cpp`:

**The decision**, standing in for `mov byte ptr [eax+0xAB0], bl` at `0x661DBA` - the
clear at step 3. Six bytes, so five of jump and one nop. Standing there rather than at
the entry is what makes it work: the flag can be raised without the decision that runs
immediately afterwards wiping it, and the game's own decision still runs, so its
schedule is untouched. eax is the idler and esi is the tick, both put there by the two
instructions above.

**The name**, standing in for `mov eax, [eax+0x158]` at `0x6500EB` - the writer's read
of `debug_saves`. It is both the branch that picks the naming and the last point
before the names are built, which is why one stub can do both jobs. A save of ours is
answered with zero, whatever `debug_saves` actually says, so it takes the three file
rotation branch.

The three names that rotation works on are repointed at buffers in the DLL, as the
immediates that load them rather than by editing the strings:

| Immediate | Was |
| --- | --- |
| `0x65010B` | `autosave.hoi3` |
| `0x650159` | `oldautosave.hoi3` |
| `0x65018D` | `olderautosave.hoi3` |

The buffers hold the game's own names except during a save of ours, so the game's
autosave is untouched and ours gets `autosave_premonth.hoi3`,
`oldautosave_premonth.hoi3` and `olderautosave_premonth.hoi3`. Two independent sets of
three: neither pushes the other out, and the rotation itself - `0x6501C0` onwards,
delete the oldest, rename the middle to the oldest, rename the newest to the middle -
is the game's own code, unchanged.

Rotating means the files are renamed as they age, so the name cannot carry the date
the save was taken on. An earlier version did name them for their date, and made too
many saves; the date is on the save itself and the load menu shows it.

While the feature is off both stubs reproduce, in assembly, exactly the instruction
they replaced and call nothing in BiceLib.

### Two things that had to be got right

**The flag is cleared on every decision, which cancels a save not yet written.** The
writer takes a frame of delay before it writes, so a decision landing in between
throws the request away. The claim on the name has to be given up with it or it lands
on whichever save the game writes next, months later. `releaseClaim()` does that at
the top of every decision, and says whether there was one, so the day is allowed to
ask again.

**The writer clears both bytes at once**, `mov word ptr [esi+0xAB0], bx` at `0x650005`,
just before it writes. So one request is one save, and nothing has to clear the flag
afterwards.

### What the buffers have to be left holding

The immediates point at the buffers for as long as the patch is in place, which is for
the rest of the session. So whatever the buffers hold is what the *game's* own autosave
is called too, and they have to be left holding the game's names: they are filled with
them at install, put back on every save that is not ours, and put back again when the
feature is switched off, because the stub goes inert and nothing would restore them
afterwards.
