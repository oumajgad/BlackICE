# Combat: what is known so far

From one session with a land battle fought and finished. Offsets are for this build of
`hoi3_tfh.exe`. Anything marked **unconfirmed** matched once and has not been seen
twice, which is not yet a fact.

## The shape of it

There is exactly one `CCombatManager`, and `CCombatHistory` is **embedded inside it at
+0x18** rather than being allocated separately - the standalone instance a vftable scan
finds is that embedded one. Both then use the same list layout:

```
CCombatManager
  +0x00  vftable
  +0x04  397            see "the 397 field" below
  +0x08  first node     live combats, going on right now
  +0x0c  last node
  +0x10  count          2 while two battles were running
  +0x18  CCombatHistory (embedded)
         +0x00  vftable
         +0x04  397
         +0x08  first node    finished combats
         +0x0c  last node
         +0x10  count         1 after one battle finished
```

**The two lists are not the same shape**, which cost an hour of reading a vftable as an
entry. The live combats hang off separate `{ data, previous, next }` nodes, the way
most lists in this game do. The history holds its **entries directly** - `+0x08` is a
`CCombatHistoryEntry`, not a node - and links them through themselves. Which field is
the link cannot be seen with only one entry in the list; `combatHistory.py` finds it by
looking for the field pointing at another entry, so it will report the offset the first
time two exist at once.

**One `CCombatHistoryEntry` appears when a combat ends**, not when it starts - watched
live: zero instances during the battle, one the moment it finished.

## CCombatHistoryEntry

Small; the readable fields stop around +0x30 and what follows is other heap contents.

| Offset | Value seen | Reading |
| --- | --- | --- |
| Offset | Reading |
| --- | --- |
| +0x00 | vftable |
| +0x04 | base metadata, see below |
| +0x08 | **the game tick the combat ended** |
| +0x0c | **the kind of combat**: 1 land, 2 naval, 3 air - see "Land, air or naval" |
| +0x10 | a country tag, or `---` |
| +0x14 | the id for it, 0 when the tag is `---` |
| +0x18 | a second country tag, or `---` |
| +0x1c | the id for it |
| +0x20 | 0 or 256 - **unconfirmed**. Does not track which tag slot is used |
| +0x24 | **the province fought over** |
| +0x28 | previous entry |
| +0x2c | next entry |

The entry is **0x30 bytes**: +0x2c is the last field, and +0x30 varies with whatever
allocation follows it.

### Read off the constructor, not guessed

`0x2F340` fills the entry, and it is short enough to read in full. With `esi` as the
new entry, `edi` as the combat and `eax` as the game clock:

```
[esi+0x04] = 0x18d                        a literal, the metadata constant
[esi+0x08] = [gameState + 0xbdc]          the current tick
[esi+0x0c] = combat->virtual slot 11 ()   a property of the combat
[esi+0x20] = byte [combat + 0x2b]         a flag
[esi+0x24] = [combat->province + 0xd0]    the province id

eax = combat->attacker                    (combat + 0x10)
if (attacker[0x5c] == 0)   [esi+0x10] = "---",  [esi+0x14] = 0
else                       [esi+0x10] = [attacker[0x54]],      tag
                           [esi+0x14] = [attacker[0x54] + 4]   id

edi = combat->defender                    (combat + 0x14)
if (defender[0x5c] == 0)   [esi+0x18] = "---",  [esi+0x1c] = 0
else                       [esi+0x18] = [defender[0x54]],      tag
                           [esi+0x1c] = [defender[0x54] + 4]   id
```

So the slots are settled and were not a guess after all:

- **+0x10/+0x14 is the attacker**, +0x18/+0x1c **the defender**.
- Each is `---` when that combatant's list at +0x54, counted at +0x5c, is **empty**.

Which explains the `---` in every entry without needing to know who won: by the time a
combat is recorded, the losing side has no countries left in its list, because its units
are gone from the fight. **The filled slot is the side still standing, and its position
says whether that was the attacker or the defender.** The ITA-ETH battle recorded ETH in
the defender slot, meaning ETH held.

Two more things fall out of it:

- **The current tick is at `[gameState + 0xbdc]`**, where `gameState` is the pointer at
  `[MODULE_BASE + 0x1689790]` that `sessionActive()` already reads. That is a date for
  any page that wants one, not just this feature.
- **+0x0c comes from a virtual call on the combat, slot 11**, which is the kind: each
  of the three classes overrides it with a constant. Read out of the executable, so
  it needed no air or naval battle to settle.

### Only one country per entry

Across nine entries, **exactly one of the two tag slots ever holds a country** and the
other is `---`. Which slot varies:

```
1936-02-01 11:00   ---   CHC   province 4517
1936-02-01 22:00   SPR   ---   province 3879
1936-02-04 04:00   SPR   ---   province 4706
1936-02-04 07:00   CHC   ---   province 9202
1936-02-04 08:00   ---   CHC   province 7209
1936-02-04 11:00   SPR   ---   province 4538
1936-02-04 13:00   SPR   ---   province 4419
1936-02-05 13:00   ITA   ---   province 9987
1936-02-05 17:00   SPR   ---   province 4656
```

So an entry does not record who fought whom. It records **one country, a province and a
time**, and the slot it sits in must be what says something about it - most likely
attacker or defender, naming the winner and leaving the loser out.

That reading fits the one battle whose belligerents are known: ITA attacked ETH at
province 9987, and the entry from it had **ETH in the second slot**. Five weeks later
province 9987 produced another entry with **ITA in the first slot**. A defender winning
and then an attacker winning at the same province is exactly how that province would be
expected to go.

**Confirmed since.** The entry names the winner - see "Who won: the side still
standing" below. The empty side is the beaten one, which is why only ever one
country appears in an entry.

**No casualty figures are in here.** The player reported 13 enemy and 9 friendly for
the battle that produced this entry, and neither number appears anywhere in it, in
whole units or in thousandths. Whatever the entry is for, it is not the losses.

What is left open here is only the other half of it: an entry says who won, and
nothing at all about who lost.

## CLandCombat

| Offset | Reading |
| --- | --- |
| +0x00 | vftable |
| +0x04 | 397 |
| +0x08 | second vftable - the `CSelectable` base RTTI says it also inherits at offset 8 |
| +0x10 | attacker, a `CLandCombatant` |
| +0x14 | defender, a `CLandCombatant` |
| +0x18 | `CMapProvince` the battle is in |
| +0x1c, +0x20 | `day` and `duration`, **settled**: CCombat::SaveContents (`0x16E210`) writes them under those keys and CCombat::LoadKey reads them back. They track each other closely - 3 and 3 in one battle, 2 and 2 in another - which is what made them look like something else |
| +0x24 | `CTerrain` |

`CLandCombatant+0x3c` points back at its `CLandCombat`, which confirms the one offset
`../../../../mem` already had for it.

## Dates are game ticks

A tick is an hour, counted from an epoch 5000 years before the calendar starts:

```
totalDays = (tick - 43800000) / 24        hour = (tick - 43800000) % 24
year      = totalDays / 365               dayOfYear = totalDays - year * 365
```

which is `utils::gameTickToDate` in BiceLib, and `hoi3.tickToDate` here. A year is 365
days with no leap day, so nothing from a calendar library will do. `60759360` is
1936-01-01 00:00 exactly, which is the check that this is right.

`hoi3.describe` now labels any value in that range as a date, so ticks announce
themselves in every dump.

## The 397 field is not a date

Every object carries 397 at +0x04 - manager, history, entry, combat, combatant, and
unrelated neighbours like `CNullOrder` and `CEventScope`. It is metadata belonging to
the shared base rather than anything about the object, and the game was at the 1936
start when it was read, so it cannot be a day count either. Ignore it.

## Corrections to `../../../../mem`

| That says | Actually |
| --- | --- |
| `CCombat` vftable `0x11C4EE4` | `CLandCombat`. `CCombat`'s own are `0x11C4D14` and `0x11C4D64` |
| `CCombatant` vftable `0x11C4DFC` | `CLandCombatant` |
| `CCombat.day = 0x1C`, `duration = 0x20` | right after all - the save code names them |

## The history does not go back far

The first battle watched produced an entry dated 1936-01-01 05:00. By 1936-02-05 the
list held nine entries, the oldest dated 1936-02-01 - **that entry was gone**. So the
game prunes its history, keeping something like the last few days or the last N
entries; which of the two is not yet known.

This is the thing that decides how the page gets built. It is asked for a day, a week,
a month, a half year and a year, and the game keeps days. So the page cannot read the
answer out of the game on demand:

- BiceLib has to **watch the history and copy new entries into its own store**, keyed
  by tick so nothing is counted twice, and keep that store itself.
- That store has to **survive a save and reload**, or every reload starts the year's
  figures from nothing.
- Which means the shorter periods are readable from the game almost immediately, while
  the longer ones only become true after the mod has been running that long.

Worth deciding before any of it is built, because it is the difference between reading
a number and maintaining a record.

## The code, and where to hook it

Found by searching the executable for the vftable address - only a constructor writes
one - and then for calls to what that turned up. `findRefs.py` does both. Addresses are
module relative, like everywhere else in BiceLib; `findRefs.py` prints them based at
0x400000, so take that off.

```
0x2F340      CCombatHistoryEntry::CCombatHistoryEntry
             writes the vftable, and writes 0x18d to +0x04 as a literal
             called only from 0x2F9FE, inside:

0x2F960      records an entry into the history
             fetches the game state from [module + 0x1689790] - the same global BiceLib's
             sessionActive() reads - then operator new(0x34) and copies the fields
             of a source entry into the new one
             called from exactly two places: 0x3170B and 0x1D2904

0x34140      builds an entry on the stack and calls a virtual through its vftable,
             and further in, from 0x341C8, builds a second one the same way
             reached from CCombatHistory's own virtual at 0x2FAD0, so these are
             almost certainly save and load rather than gameplay
```

**`0x2F960` is the hook, and its second argument is the combat itself.**

```
0x2F960(arg1 = the list to append to, arg2 = the CCombat that just ended)
```

`arg2` reaches the constructor as `ecx` and is where every field of the entry comes
from. Hooking the function's first instruction therefore hands us the whole combat
object **while it is still alive** - both combatants, their units, and whatever
casualty counters they carry - which the entry itself does not record. One hook, every
finished combat, everything in scope.

The prologue is `push ebp` / `mov ebp, esp` / `mov eax, fs:[0]`, so the first five bytes
a jump needs land inside a nine byte run that has to be re-executed in the trampoline.
Nothing subtle, but the `fs:[0]` is the function's exception frame and must be preserved
exactly.

The two callers are worth identifying anyway: two call sites for three kinds of combat
suggests land and something else, and knowing which is which may be how the page's
three columns get filled.

Note the allocation is **0x34 bytes**, not the 0x30 the fields suggested - the last few
are padding or something not yet seen used.

## The casualties

**`combatant + 0x84` is the strength that side lost, in thousandths.** 21 losses as the
game reported them read back as 21900. Found by capturing a battle with the hook and
searching the captured block for the figure on screen.

One side's losses are the other side's kills, so a single combat yields every number
the report wants:

```
country was the attacker:  lost = attacker[0x84],  killed = defender[0x84]
country was the defender:  lost = defender[0x84],  killed = attacker[0x84]
```

### Ships sunk, brigades destroyed

The strength figure cannot say how many ships went down, because it counts damage to the
survivors in the same number. The game keeps that separately, and **read** off its loss
accounting at `0x166267`:

```
for each unit on this side, for each subunit in it:
    destroyed outright ->  [combatant+0x88][type] += 1000
                           [combatant+0x84]       += 1000
    damaged            ->  [combatant+0x98][type] += the damage
```

`+0x88` is a vector with an entry per subunit type the mod defines, `+0x8c` its end.
**Nothing but a whole loss ever lands in it**, so the sum of it over a thousand is the
number of ships, brigades or planes that side actually lost. `+0x98` is the same shape
for damage short of destruction.

The type index is `[[subunit+0x58]+0x24]`, so the same vector could say *which* ships
were sunk, not only how many. Nothing reads it that way yet.

**Nothing reads this.** It was built and taken out again: the report counts losses the
way the game states them, and a second currency beside that one earned less than it
cost. Recorded here because it is worth knowing and was read out of the code rather
than guessed.

Naming the ships that went down is a different matter and does **not** work: the wrecks
are already detached from their unit by the time a combat is recorded, so walking the
units at capture time finds nothing to name. Catching a name would mean hooking the
destruction itself, earlier.

## Land, air or naval

Not a field on the object - they are **different classes**, told apart by the combat's
vftable. Each also has a second vftable for its `CSelectable` base at object offset 8.

| Class | vftable | at +8 | combatant it builds |
| --- | --- | --- | --- |
| `CLandCombat` | `0x11C4EE4` | `0x11C4F34` | `CLandCombatant` `0x11C4DFC` |
| `CNavalCombat` | `0x11C4F5C` | `0x11C4FAC` | `CNavalCombatant` `0x11C4D8C` |
| `CAirCombat` | `0x11C4FD4` | `0x11C5024` | `CAirCombatant` `0x11C4E74` |

Both sides of an air combat are a `CAirCombatant` and both sides of a naval one a
`CNavalCombatant` - read off each combat's **slot 6**, which is where a combat builds
its two combatants (`0x17B4D0` land, `0x17B770` naval, `0x17BBA0` air). The
`CBomberCombatant` and `C*TargetCombatant` classes in the RTTI export are something
else's; `CAirCombat` does not make them.

### The kind is slot 11

`CCombat`'s slot 11 is `_purecall`, and every kind overrides it with a constant:

```
CLandCombat    0x7F9B90     mov eax, 1 ; ret
CNavalCombat   0x8037D0     mov eax, 2 ; ret
CAirCombat     0x17BC80     mov eax, 3 ; ret
CGroundBombing 0x163E60     mov eax, 4 ; ret
CLandBombing   0x163F30     mov eax, 5 ; ret
CNavalBombing  0x164000     mov eax, 6 ; ret
```

So **1 is land, 2 naval, 3 air** and 4 to 6 are the bombings, and that settles what a
history entry's +0x0c is: the
constructor fills it from slot 11, and it was 1 in every land combat seen. Comparing
vftables and asking the object come to the same thing; BiceLib compares vftables.

`python vtable.py CCombat CLandCombat CAirCombat CNavalCombat --all` prints this.

### The fields are on the base, so they are the same for all three

The important one, because it says the capture should work for air and naval unchanged.
Everything BiceLib reads off a combatant is initialised by the **base** `CCombatant`
constructor at `0x164550`, which every kind runs:

```
[edi+0x54] [edi+0x58] [edi+0x5c]   the country list the game reads a tag from
[edi+0x64] [edi+0x68] [edi+0x6c]   the list the beaten side keeps
[edi+0x84]                         strength lost
```

They are laid out as groups of three pointers and a byte - `0x28`, `0x40`, `0x54`,
`0x64` all have that shape - which suggested begin/end/capacity rather than the
begin/count the offsets were first read as. **Corrected since:** three words and a byte is
the game's `CList` (first, last, count, byte; see `CLASSES.md`, *Held by value*), so
`+0x5c` is a count after all. `+0x74` is different: the constructor pushes into it with a
grow call when `+0x78` reaches `+0x7c`, which is a real vector, and so are `+0x88` and
`+0x98`.

Combat-level offsets are base fields too, by the same argument: the history entry's
constructor reads the attacker, defender, province and flag off a plain `CCombat*`
without dispatching on anything.

`CLandCombatant` is the odd one out in **behaviour** - 28 slots against 26, fifteen of
them its own - while air and naval combatants take most of the base's. That is code,
not layout.

`CNavalCombatant` objects are at least `0x10b8` bytes: its constructor writes `+0x10b4`.

### What is not known

- **Whether the hook fires for them at all.** `0x2F960` has two callers: `0x3170B`,
  in the combat manager's own code, and `0x1D2904`, which sits among the `CArmy`,
  `CNavy` and `CAir` virtuals - unit code. Both fetch the game state and append to the
  same history. Which kinds of combat reach which caller has not been traced.
- **What losses mean for them.** `+0x84` is strength in thousandths for a land
  combatant, checked against the figure the game reported. Ships and planes are not
  brigades, so the scale and the meaning both want checking before the report's Air and
  Naval columns are believed.
- **Whether the loser's country list empties the same way.** The winner rule and the
  loser's name both hang on that, and both have only ever been watched on land.

One air battle and one naval battle with recording on settle all three: the Kind column
should read Air and Naval, Winner and Loser should fill, and the losses should match
what the game reports.

## Bombing raids are combats too

`CCombat` has a fourth subclass, `CBombing`, with three kinds of its own. They finish
into the same history and the same hook catches them.

| Class | vftable | at +8 | target combatant it builds | kind |
| --- | --- | --- | --- | --- |
| `CGroundBombing` | `0x11B6934` | `0x11B6984` | `CGroundTargetCombatant` | 4 |
| `CLandBombing` | `0x11B69AC` | `0x11B69FC` | `CLandTargetCombatant` | 5 |
| `CNavalBombing` | `0x11B6A24` | `0x11B6A74` | `CNavalTargetCombatant` | 6 |

`CBombing` itself is abstract - no vftable in the export. **read**, from each class's
slot 6 and slot 11.

So the game's own numbering, across every kind of combat there is:

```
1 land   2 naval   3 air   4 ground bombing   5 land bombing   6 naval bombing
```

**Nobody wins a bombing.** Both sides keep their countries - watched on an ITA raid on
ETH, where both combatants had one country each and both were named. The winner rule
finds neither side emptied and leaves the outcome unknown, which is right: the report
counts the raid, who flew it and what it cost, and neither wins nor loses it.

**What the target loses is not known to be strength.** The same raid had the attacker
losing 2.2 and the target 289.8. For `CLandBombing` the target is land units, so it may
well be strength in thousandths like everything else; for `CGroundBombing` it is a
province, and infrastructure or industry damage is not a currency that belongs in a
total with a division's losses. Nothing has been checked against a figure the game
displayed. **The report keeps all three in a Bombing column of their own**, which is
also why the Total column should be read with that in mind.

## Who won: the side still standing

**Confirmed in game.** A combatant's country list at +0x54, counted at +0x5c, is empty
for exactly one side by the time the combat is recorded, and that side is the one that
**lost**. So:

```
attacker[0x5c] != 0  ->  the attacker won
defender[0x5c] != 0  ->  the defender won
```

which is the same test the entry constructor makes to decide between writing a tag and
writing `---`. It needed no further reversing - the winner was already being captured,
under another name.

That also settles what the entries meant: an entry names **the winner, and the slot it
sits in says whether that was the attacker or the defender**. The ITA-ETH entry with ETH
in the defender slot was ETH holding, as guessed.

BiceLib records this as `Combat::Outcome` and writes it as the last field of each line
in the campaign file - `A`, `D` or `?`. The store does not read older shapes of that
line: a line missing a field is skipped, so changing the format means the existing
`script/combat_reports/` files have to go.

## The loser's tag

Only the winner is named, because the game takes a side's tag from a country list the
beaten side no longer has. **A combatant keeps a second list of its own countries at
+0x64**, though, and that one survives, so the beaten side is still named there.

```
CCombatant
  +0x54  countries, begin    what the game reads a tag from - emptied on the loser
  +0x5c  countries, count    zero for the beaten side, which is why it has no tag
  +0x64  countries, begin    the same side's own countries, kept
  +0x84  strength lost, in thousandths
```

Both lists point at the same shape: three characters and a NUL, then the country id.

### It was read wrong once

+0x64 was first taken for **the other side's** countries, on the strength of one battle
where the winner showed its own tag at +0x54 and the loser's at +0x64 - two readings that
turned out to be on two different combatants, not one. A battle settled it: ITA attacked
ETH and retreated, so ETH won, and the winning ETH combatant had **ETH** at +0x64.

So BiceLib takes the loser's name from the **loser's own** +0x64, and only where the
**winner's** +0x64 names the winner. That second read has a known answer - the winner's
tag is right there at +0x54 - so it costs nothing and it is what would have caught the
mistake above on the first battle rather than the second. Where it fails the loser stays
`---`, the combat counts for neither country, and the report says how many of those a
period holds.

`+0x40` and `+0x44` are the units on a side, a vector of `CUnit*`, and `CUnit+0x124` is
the owner, a `CCountryTag` - both from `../../../../mem`. That was the other way
at the loser's name and it is not needed, so nothing in BiceLib reads them; noted here
because they are worth knowing.

### Still open

- Whether `CAirCombat` and `CNavalCombat` lay their combatants out the same way. Only
  land combats have ever been captured.
- What a combatant holding several countries records - allies fighting together should
  put more than one tag in a list, and only the first is read.

## What to do next

1. **Fight an air and a naval battle.** `CAirCombat` and `CNavalCombat` are named from
   the RTTI export and have never been seen, so two of the report's three columns are
   untested - as is whether their combatants carry losses at +0x84 and their lists at
   +0x54 and +0x64 the way land ones do.
2. **Check the country statistics screen.** The game shows losses per country
   somewhere. If that is persistent it is a second source to check the accumulated
   record against, which nothing currently does.

## How a combat is set up: `CreateCombatants`, slot 6

Read out of the executable, whole; no game was running for any of it.

### The slot, and when it runs

`CCombat` slot 6 is `_purecall` (`0xABF890`) and each kind implements it:

```
CLandCombat::CreateCombatants    0x17B4D0
CNavalCombat::CreateCombatants   0x17B770
CAirCombat::CreateCombatants     0x17BBA0
```

Nothing calls any of the three directly - `findRefs --callers` returns zero for each.
Both call sites go through the slot, `mov edx, [eax+0x18]; mov ecx, edi; call edx`, and
they are the only two:

```
0x2FCC5   the combat loader, a switch on the save key: land_combat 0x2D3 at 0x2FCA3,
          naval_combat 0x2D4 at 0x2FC8C, air_combat 0x520 at 0x2FCF4
0x3142B   the live factory at 0x31370, a jump table on the kind 1..6
```

Both do the same three things in the same order: `operator new(0x44)`, the kind's own
constructor, `0x2FFC0` to put the combat on the manager's list, **then slot 6**, and only
then the combat's own contents - `[eax+0xC]` (load) or `[eax+0x40]` (set the province).
So **the combatants exist before anything is known about the combat**, which is why
`CreateCombatants` reads nothing off it.

The factory at `0x31370` goes on to call slot 12 on `combat+0x10` with the attacking
unit and on `combat+0x14` with the defending one, so the units arrive *after* this.
`ret 0x14` - five stack arguments, `(manager, province, kind, attacker, defender)`,
the last optional. Not reversed further; it is the obvious next function.

### What each one does

All three are `void __thiscall (this)`, bare `ret`, an SEH frame whose only job is to
free the first combatant if the second allocation throws. Each allocates twice, builds
the attacker with the bool `true` and the defender with `false`, and stores them at
`+0x10` and `+0x14`. A failed `operator new` stores a null and skips the constructor,
which is the only branching in any of them.

| | land | naval | air |
| --- | --- | --- | --- |
| allocation | `0xE4` | `0x10BC` | `0x10B4` |
| constructor | a real one, `0x168DB0` | inlined | inlined |
| vftable written | by that constructor | `0x11C4D8C` here | `0x11C4E74` here |
| extra fields zeroed | `+0xB0`..`+0xE0`, in the constructor | `+0x10B4`, `+0x10B8` | none |

**That is the whole of the difference.** The three are the same function with a
different size, a different vftable and a different tail; nothing about terrain, sea
zones or air bases enters here.

`CLandCombatant` is the only one with a constructor of its own because it is the only
one with anything to construct - three lists at `+0xB0`, `+0xC0`, `+0xD0`, whose nodes
its destructor (`0x168E40`) walks and frees. `CLandCombatant::LoadKey` names all three:

```
+0xB0   front       save key `front`    (0x396)
+0xC0   reserves    save key `reserves` (0x398)
+0xD0   retreat     save key `retreat`  (0x1A6)
+0xE0   byte, set to 1 by every LoadKey call
```

`CNavalCombatant +0x10B4` is `positioning` (key `0x39B`), a plain `int` - its `LoadKey`
does `lea edi, [ecx+0x10B4]` and `0x67B540` writes a `%d` through `edi`. `+0x10B8` is
zeroed beside it and nothing here says what it is.

**`CAirCombatant` accepts `positioning` and throws it away.** Its `LoadKey`
(`0x16DED0`) compares the key against `0x39B` and, on a match, returns without reading
anything. Naval and air combatants are both `0x10B4`-ish objects whose constructors
initialise only the `CCombatant` base - **about `0x1000` bytes in each of them is never
written at construction and nothing found here says what it holds.** That is the one
thing this pass could not settle.

### `CCombatant::CCombatant` (`0x164550`)

`ret 8`, two stack arguments and a third in `ecx`, returns `this` in `eax`:

```
CCombatant* __stdcall CCombatant::CCombatant(CCombatant* this@stack:4,
                                             bool attacker@stack:8,
                                             CCombat* combat@ECX) @EAX
```

The `ecx` argument is not an artefact - `[edi+0x3C] = ecx` at `0x5645F9`, which is the
back-pointer to the combat `../../../../mem` already had. `CLandCombat::CreateCombatants`
sets `ecx` before calling the `CLandCombatant` constructor, which never touches it and
lets it fall through.

What it writes, in order:

```
+0x04 = 0x18D                     the CPersistent constant
+0x00 = 0x11C4CA4                 CCombatant's own vftable
+0x28 +0x2C +0x30 byte +0x34      sunk_ships, a CList
+0x40 +0x44 +0x48 byte +0x4C      units, a CList
+0x54 +0x58 +0x5C byte +0x60      countries, a CList
+0x64 +0x68 +0x6C byte +0x70      own_countries, a CList
+0x74 +0x78 +0x7C                 men, a vector (begin, end, capacity)
+0x84 = 0                         losses
+0x88 +0x8C +0x90                 destroyed, a vector
+0x98 +0x9C +0xA0                 damage, a vector
+0xAC = 0                         tactic
+0x50 = 0                         dice
+0x38 = the bool argument         **is_attacker**
+0x3C = ecx                       combat
+0xA8 = 0                         a byte, unnamed
+0x08..+0x25 = 0                  three movq, a dword and a word, all unnamed
```

and then, before any of the zeroing at `+0x08`, a loop that **sizes the three vectors
to the subunit database**:

```
for (i = 0; i < ([g_CSubUnitDataBase+0x20] - [g_CSubUnitDataBase+0x1C]) / 4; ++i) {
    push_back(0) into +0x74;  push_back(0) into +0x88;  push_back(0) into +0x98;
}
```

`+0x1C` and `+0x20` are `definitions_begin` and `definitions_end`, so the count is the
number of subunit definitions the mod loaded. That settles by construction what
`FINDINGS-combat.md` had read off the loss accounting: **`+0x74`, `+0x88` and `+0x98`
are indexed by subunit type**, and the index is the one at
`[[subunit+0x58]+0x24]` - `CSubUnitDefinition::type_index`.

The loop also **creates `g_CSubUnitDataBase` if it is null**, inline, with a 511-bucket
table; that is a lazy singleton getter the compiler inlined, not something the combatant
does.

`+0x38` is the useful new field. It is `1` for the object stored at `combat+0x10` and
`0` for the one at `combat+0x14`, in all three `CreateCombatants` and in the three
bombings' equivalents, so **a combatant knows which side it is without asking the
combat**. That is a cheaper attacker/defender test than comparing pointers, and it is
the one the game itself uses.

### The `CCombat` constructors, for completeness

`0x17B480`, `0x17B720`, `0x17BB50` - land, naval, air. Each takes `this` in `eax`, has a
bare `ret`, and is the `CCombat` base constructor inlined plus the class's own two
vftables. They are how `CCombat`'s size and starting state are known:

```
new(0x44)                         so CCombat is 0x44 bytes
+0x04 = 0x18D                     persistent_meta
+0x08 = 0x11C0694, then the class's CSelectable table
byte +0x0C = 0
+0x10 = +0x14 = +0x18 = 0         attacker, defender, province - all null here
+0x1C = -1                        day starts at -1, not 0
+0x20 .. +0x40 = 0
```

### The three bombings do the same thing

`CGroundBombing::CreateCombatants` (`0x163DA0`), `CLandBombing::CreateCombatants`
(`0x163E70`) and `CNavalBombing::CreateCombatants` (`0x163F40`) are slot 6 of their own
classes and the same function again:

```
attacker  new(0x10E8), CBomberCombatant::CBomberCombatant (0x15DBC0), which hardwires
          the bool to 1                              ->  combat+0x10
defender  new(0x10B4), CCombatant::CCombatant inlined with the bool 0, then the target
          class's vftable                            ->  combat+0x14
```

with the target vftable the only thing that varies: `0x11C464C` ground, `0x11C472C`
land, `0x11C46BC` naval. That accounts for all nine callers of
`CCombatant::CCombatant`: two here per bombing, two each in naval and air, one in
`CBomberCombatant`'s constructor and one in `CLandCombatant`'s.

So **`+0x38` is `1` for `combat+0x10` and `0` for `combat+0x14` in all six kinds of
combat**, with no exception anywhere in the image.

`CBomberCombatant` is `0x10E8` bytes and writes `+0x10B4` onwards, the same boundary
`CNavalCombatant` and `CAirCombatant` sit on. Three sibling classes ending their base
part at `0x10B4` is a strong hint at a shared layout the RTTI does not show - every one
of them derives from `CCombatant` directly - but it is a hint and nothing more. Its
constructor has a lazy-singleton loop of its own and was not read.
