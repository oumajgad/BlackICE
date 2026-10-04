# The history subsystem: containers, entries, and whether anything reads them

Wave 11 agent B, 2026-10-03. Static only; the game was not running. Live counts are the
2026-09-20 census in `ghidra/census.json`, which is the mod's own reading.

All addresses are **rvas** unless marked `VA` (trap 1). Virtual tables are quoted as VAs,
following `CCombatHistoryEntry`'s precedent in `project.json`.

## The short answer

**The brief's premise was wrong, and in a useful direction.** The engine keeps every leader's,
country's and province's history for the whole session, and **it is read after load, three
different ways**:

| who | when | what it reads |
|---|---|---|
| `ExecuteHistory` (`0x1F4C20`) through `CHistoryContainer::ApplyRange` (`0x1F47C0`) | startup, and every change of the scenario date in the lobby | **every entry of every container**, applying or undoing each |
| `RunCountryDailyPass` (`0xDA530`) at `0xDAA80`..`0xDAAFE` | **every day, for every leader of every country** | each leader's entry list, until it finds the `rank` token |
| `CCountry::GetOriginalCapital` (`0xDDB30`), plus two inlined copies at `0xBF973` and `0xC1632` | whenever a caller wants the pre-war capital | the country's entry list, until it finds the `capital` token |

and written out again by `CLeaderHistory::SaveContents` (`0x1F28E0`) and the
country/province writer at `0x1FCDA0` on every save.

So the daily pass walks **24,547 `CRankChange`** objects' worth of list every game day.
That is the hot read, and it is one virtual call per leader per day.

And the retention is cheap: **~2.21 MB of payload, ~3.02 MB with heap headers** — 0.15% of a 2 GB
address space and about 1/80th of what the historical models cost. So the memory question answers
itself in the negative. The interesting findings are the *mechanism*, which is a full do/undo replay
engine, and that **one of the five leader history keys is inert**.

## 1. `CHistoryContainer` is 0x20 bytes, and the constructor is the whole layout

`CHistoryContainer::CHistoryContainer` (`0x1F45A0`) is eight stores, receiver in EAX,
bare `ret`:

| offset | what |
|---|---|
| `+0x0` | vftable (VA `0x15C88F4`) |
| `+0x4` | the CPersistent meta, `0x18D` |
| `+0x8` | **date** - the date the container has been executed to; defaulted to `g_NullDate` (`0x130C2B8`) |
| `+0xC` | **a `CList`** - head `+0xC`, tail `+0x10`, count `+0x14`, flag byte `+0x18` |
| `+0x1C` | a dword zeroed by the constructor and **read by nothing** |

`project.json` already types `CLeaderHistory +0xC` as `CList`, and `CList` is already
recorded as 0x10 bytes `{first, last, count, flag}` - which is exactly what accounts for
the byte at `+0x18`. Two independent corroborations of the count at `+0x14`:
`CMapProvince.hpp` records `history = 0xD8` with `history_count = 0xEC`, and `0xD8 + 0x14
== 0xEC`; and `CProvince`'s save writer gates the whole `history` key on `+0xEC` being
positive.

The nodes are `operator new(0x10)` and match `HoiDataStructures.hpp`'s
`LinkedListNodeSingle` - `{data +0, prev +4, next +8}` with a trailing byte.

**The derived classes' own fields start at `+0x20`, and on all three that is the owner.**
`CLeader::CLeader` writes `[leader+0xA4] = leader` (`0x17F665`, and `0x84 + 0x20 == 0xA4`);
`CProvinceHistory::CProvinceHistory` (`0x1FCBE0`) stores its one argument at `+0x20`; and
`0x1EC730` is the non-virtual getter that reads it back. `CLeaderHistory::LoadEntry` reads
`this->+0x20` as the `CLeader*` it stamps on every entry it builds.

**So `CLeaderHistory` is 0x24 bytes, and `CLeaderHistory +0x40 trait_gain` in the record is
not a field of it.** `CLeader::CLeader` builds `picture` at `CLeader+0xA8`, which is
`CLeaderHistory+0x24`, and writes `[esi+0xC4] = 0` separately afterwards. The four bytes
`+0x40` named are `CLeader +0xC4`, which the record **already** holds as
`trait_gain_tracker` with five `[leader+0xC4]` readers (trap 14: both halves had it, and
one half had it in the wrong place).

### The container's complete interface

Ten vftable slots and six free helpers - and because the container is a subobject with no
other way in, **that is the whole of the code that can touch the list**:

| | | |
|---|---|---|
| slot 0 | `0x200220` / `0x1ECA60` | `Release` - Clear, then free |
| slot 2 | `0x1F28E0` (leader/diplomacy/war) / `0x1FCDA0` (country/province) | `SaveContents` |
| slot 4 | `0x1FC400` (leader/war) / `0x1FCC10` (country/province) / `0x1F2810` (diplomacy) | `LoadKey` - dates only |
| slot 6 | `0x1F4660`, **all six tables** | `AddEntry` |
| slot 7 | `0x1F4830`, **all six tables** | `ApplyAll` |
| slot 8 | `ReturnFalse` on the base, `ReturnTrue` / `0x1EC720` on all five subclasses | an unnamed predicate |
| slot 9 | `0x1FC4E0` / `0x1FCED0` / `0x1ECA90` / `0x1F2A80` / `0x200250` | `LoadEntry`, the per-class grammar |
| - | `0x1F45A0`, `0x1F45E0`, `0x1F4730`, `0x1F4780`, `0x1F47C0`, `0x1FAEE0` | ctor, Clear, Reset, SetDate, ApplyRange, sorted insert |

Two things fall out of that table:

- **`0x1FC400`, which the record calls `CWarHistory::LoadKey`, is slot 4 of `CLeaderHistory`
  too** - two holders, both `CHistoryContainer` subclasses, so the name singles out one of
  them. The body is the leader/war twin of `CHistoryContainer::LoadKey`: atoi the key, and
  if it is a date, parse it and send every key/value pair in the block that follows to slot
  9. Its comment said "what it does with a key instead has not been read"; it has been now.
- **`SetDate`'s entry-restamping branch is dead.** It stamps the new date into every entry
  only when slot 8 answers false, and slot 8 is `ReturnTrue` (or the equivalent at
  `0x1EC720`) in every one of the five concrete classes. Only the abstract base returns
  false.

## 2. An entry is 0x18 bytes, and slots 6 and 7 are the whole interface

`CHistoryEntry`'s own table (VA `0x15C9E8C`) has **`_purecall` at slots 6 and 7**, so every
entry class must supply both. That is the contract:

- **slot 6 returns the save token naming the key the entry carries.** Five bytes:
  `mov eax, <token>; ret`. The five leader classes sit 0x10 apart at `0x1FC3B0`/`C0`/`D0`/
  `E0`/`F0` and return `0x10A`, `0x43C`, `0x28F`, `0x488`, `0x489` - `rank`, `loyalty`,
  `skill`, `add_trait`, `remove_trait`, matching their class names one for one. This is the
  getter `RunCountryDailyPass` and `CCountry::GetOriginalCapital` call through.
- **slot 7 is `Apply(bool)` - the do/undo.** `CRankChange::Apply` (`0x1FC7F0`): with the
  flag set, save `leader->rank` into `this->+0x14` and write `this->+0x10` over it; with it
  clear, put `+0x14` back. Then, for a **land** leader only (`type == 0`) that has a unit,
  call the unit's leader setter (`0x1BFC10`) with `CLeader::null` - so applying or undoing a
  rank change takes a land leader off his unit. `CLoyaltyChange::Apply` (`0x1FC8A0`) is the
  same against `loyalty` (`+0x80`).

So a `CLeaderHistoryEntry` is:

| offset | what |
|---|---|
| `+0x0` | vftable |
| `+0x4` | `0x18D` |
| `+0x8` | the entry's date, defaulted to `g_NullDate` |
| `+0xC` | **the owning `CLeader*`**, taken from the container's `+0x20` |
| `+0x10` | **the new value** - the only field `SaveContents` writes |
| `+0x14` | **the previous value, saved by Apply so Apply can undo it** - runtime scratch, never saved |

0x18 bytes for `CRankChange`, `CSkillChange` and `CLoyaltyChange`; 0x14 for
`CAddTraitEntry` and `CRemoveTraitEntry`, which have no `+0x14` to restore.

### `skill` in a leader's history block does nothing

`CSkillChange`'s slot 7 is the **1420-holder empty stub at `0x20CD50`**, where all four of
its siblings have a real body. So a dated `skill = N` in `history/leaders/*.txt` is
tokenised, allocated, filed in the list and written back out on save - and never applied to
`CLeader +0x70`. There are zero live `CSkillChange` in the census, and the mod's 124 leader
files use the key nowhere inside a `history` block.

That matters directly to the dormant no-leader-skill-loss feature: **the history route to a
leader's skill is a dead end in this build.** `rank`, `loyalty`, `add_trait` and
`remove_trait` all work; `skill` does not. `CLeader::PostLoad` reads the top-level `skill`
key as a *floor*, which is the only path that moves it.

## 3. The replay engine, and when it runs

`CHistoryContainer::ApplyRange` (`0x1F47C0`) is the heart: container in EAX, from-date in
EDI, to-date on the stack. Forwards (`*to > *from`) it walks head to tail and calls each
entry's slot 7 with 1 for every entry dated in `(*from, *to]`; backwards it walks tail to
head and calls slot 7 with 0 for every entry in `(*to, *from]`. **The history is a
reversible transaction log over the world state.**

`ExecuteHistory` (`0x1F4C20`) drives it over a vector of containers and logs
`Executing History from <a> to <b>` on `history.cpp:11`. Its only caller is
`ExecuteHistoryToDate` (`0x1F52A0`), which has eleven call sites:

- `0x232882` and `0x2328EF` inside `CEU3Application::LoadEverything` - the `history execute`
  stage, once per process;
- `0x23A75E` and `0x23A825` inside `ResetGameStateToStartDate` (`0x23A460`), itself reached
  from the lobby, from `CTutorialScreen::OnTutorialButtonPressed` and from
  `ProcessSessionEndRequests` via `CInGameIdler::Update`;
- `0x2D619C` inside `CSetHistoryDate` slot 6 (`0x2D60C0`);
- the lobby/scenario-setup date handlers at `0x2F4361`, `0x2F49B1`, `0x2F4FB1`, `0x2F5611`,
  `0x307E18`, `0x31D9AC` - the same six functions `RunSetupPass` is called from.

**None of them is on the tick.** Replay happens at startup and whenever the start date is
moved before play; during play only the daily and capital readers touch the history.

## 4. Is the history read after load? Yes. The search, and its control

`+0xC` is a disp8 shared by hundreds of classes (trap 12), so the list head was reached
**through its owner**, where every spelling is a disp32 and can be byte-searched with a
decode at each hit:

| owner | container | head | tail | count |
|---|---|---|---|---|
| `CLeader` | `+0x84` | `+0x90` | `+0x94` | `+0x98` |
| `CProvince` | `+0xD8` | `+0xE4` | `+0xE8` | `+0xEC` |
| `CCountry` | `+0xCCC` | `+0xCD8` | `+0xCDC` | `+0xCE0` |

The scan byte-searches the four-byte displacement in `.text`, decodes at every start in the
15 bytes before each hit and keeps only a decode whose memory operand really carries it;
then it keeps only loads into a register that is immediately used with `[R]`, `[R+4]`,
`[R+8]` or `[R+0xC]` - the list-walk shape - and then only where the *same base register*
also carries a displacement distinctive of the owning class.

**The positive control.** `+0x90` returns 2,394 decodable references, 112 of which are
followed by a list-walk read. `RunCountryDailyPass` (`0xDA530`) is among them, at the
instruction the record already cites. So the method finds the one reader of a leader's
history that was already known. Every other survivor was read and none is a `CLeader`: the
strong hits turn out to be a leader-id pair compared against `0x1268` (`0x485046`), a
destructor freeing an unrelated pointer (`0xA892FD`), and - at `0x5C304A` - *the same
append idiom on a different class*, whose list sits at `+0x88`/`+0x8C`/`+0x90`.

**Countries.** `+0xCD8` has ten decodable references, five with a real base. Two are
`CGameState`, not `CCountry`. The other three are genuine and all three are the same loop:
`CCountry::GetOriginalCapital` (`0xDDB30`), and the loop inlined at `0xBF973` and `0xC1632`.
`0xDDB30` is 0x40 bytes end to end: walk the list, ask each entry's slot 6, return
`entry->+0x10` for the first `capital` (`0x1F9`), else fall back to the live
`capital_province_id` (`+0xE20`). Four callers - `0xBF7C5`, `0xC1430`, `0xE0B80`, `0x14BD00`
- none of which is named yet. The 21 `[country+0xCCC]` sites are the *writers*: the
`mov edx,[c+0xCCC]; lea ecx,[c+0xCCC]; call [edx+0x18]` idiom, which is `AddEntry`.
`CCountry::ChangeNeutrality` is one of them. `+0xCE0` (the count) has **no** non-stack
reader at all.

**Provinces.** `+0xE4` has 610 loads with a real base, 176 followed by a list walk, and only
one survivor whose base carries a province's distinctive neighbours (`+0x2B0`, `+0x310`,
`+0x320`, `+0x32C`, `+0x334`, `+0x344`): `0x96C30`, which is a **reset** - it frees every
node, zeroes head/tail/count and puts `g_NullDate` back at `province+0xE0`. So the province
history has no runtime reader outside the load/save/reset path and `ExecuteHistory`.

**And `CHistoryContainer +0x1C` has no reader anywhere.** Six references to `+0xCE8`, four
with a real base, and all four are `CGameState`. None of the container's own sixteen
functions touches `+0x1C` on the receiver. The control is the `+0xCD8` scan above, which
found three real readers in the same code with the same method. (Only the country spelling
was scanned; the leader `+0xA0` and province `+0xF4` spellings were not.)

## 5. What it costs

Entry sizes are the `push N` before `operator new` at each class's construction site; counts
are the 2026-09-20 census.

| class | live | size | payload | + 8-byte header |
|---|---|---|---|---|
| `CRankChange` | 24,547 | 0x18 | 589,128 | 785,504 |
| `CCountryDecisionChange` | 15,755 | 0x2C | 693,220 | 882,280 |
| `CControllerChange` | 4,011 | 0x20 | 128,352 | 160,440 |
| `COwnerChange` | 2,107 | 0x20 | 67,424 | 84,280 |
| `CAddCoreChange` | 1,559 | 0x18 | 37,416 | 49,888 |
| `CHistoryEntry` | 420 | 0x14 | 8,400 | 13,440 |
| `CNeutralityChange` | 202 | 0x18 | 4,848 | 6,464 |
| `CRemoveCoreChange` | 185 | 0x18 | 4,440 | 5,920 |
| 10 more classes | 212 | 0x18 assumed | 5,088 | 6,784 |
| **list nodes** | 48,998 | 0x10 | 783,968 | 1,175,952 |
| | **48,998 entries** | | **2,322,284 (2.21 MB)** | **3,170,952 (3.02 MB)** |

**The containers cost nothing extra.** They are subobjects, and the counts prove it:
`CLeader` 24,137 against `CLeaderHistory` 24,138; `CCountry` 108 against `CCountryHistory`
108; `CProvinceHistory` 14,190 at `CProvince+0xD8`. Only 271 of the 38,707 containers are
separately allocated (the bare `CHistoryContainer`s, `CWarHistory` and `CDiplomaticHistory`,
0x20-0x24 each) - about 11 KB.

Assumptions, stated: the 212 small-class objects are costed at 0x18 because their
constructors are standalone functions whose `operator new` is in the caller and only the big
six were read; and the header column assumes the Windows heap's 8-byte header with 8-byte
granularity, which is the right model for a 32-bit MSVC CRT `malloc` but was **not
measured**.

**So: about 3 MB.** 0.15% of a 2 GB user address space, and about 1/80th of the 255 MB the
historical models cost. The 48,998 entries are a real retention, they are read, and they are
not a memory problem.

The scale check: the mod's `history/leaders/*.txt` define **23,378 leaders** with 23,379
`history` blocks between them, and roughly 21,500 `rank` lines. One `CRankChange` per leader
is exactly what the census shows, and exactly what the daily pass is looking for.

## 6. `g_NullDate` corroborated from a second subsystem

`0x130C2B8` was already recorded, `likely`, off two trade uses. The history subsystem is an
independent confirmation and promotes it: it is the default date of **every** `CHistoryEntry`
(the base constructor writes the immediate `0x29C55C0` and then the static over it), the
default date of **every** `CHistoryContainer`, what `Reset` puts back, and the fallback
`RunCountryDailyPass` uses when a leader's history has no `rank` entry. A scan of all 234
`.text` references, decoding at each hit, found **zero writers**, so it is a read-only
constant; the bytes at `0x170C2B0`..`0x170C2BF` are a run of `0x029C55C0`.

`CHistoryEntry::DateIsUnset` (`0x1EC6E0`) settles what the value means: it is
`year(date) < 2`, where `0x2EF40` computes `(date - 0x29C55C0) / 24 / 365.0` with 365.0 read
out of VA `0x160A550`. So `g_NullDate` is **year zero on the engine's own calendar**, the
save writer omits the date header for an entry still holding it, and
`43800000 / 24 / 365 == 5000` exactly - the epoch is 5000 years of 365 days before year
zero. A leader whose history carries no `rank` entry therefore has an activation date no
live tick can equal, and **is never activated**. That closes
`FINDINGS-leaders.md`'s open item about this global without guessing "campaign start".

## What is not established

- **Which stack argument of `ExecuteHistoryToDate` (`0x1F52A0`) is which.** `ret 8` on both
  exits and EDX read before any write are pinned; the two stack slots' identity is not,
  which is why that entry is `inferred`.
- **What slot 8 of a container means.** It gates `SetDate`'s entry-restamping branch, it is
  false on the abstract base and true on all five concrete classes, and that is all. Three
  bodies: `ReturnFalse`, `ReturnTrue`, and a third framed `mov al,1; ret` at `0x1EC720`
  held only by `CCountryHistory` and `CProvinceHistory`. Left unnamed.
- **`CHistoryContainer +0x1C`.** Written zero, read by nothing found. Only the `CCountry`
  spelling was scanned.
- **`0x1FAEE0`, the sorted insert** `AddEntry` falls back to when an entry arrives out of
  date order. One caller, body not read.
- **`0x1FCDA0` and `0x1ECA60`**, the country/province save writer and release. Identified
  from the tables, not read.
- **The four callers of `CCountry::GetOriginalCapital`** - `0xBF7C5`, `0xC1430`, `0xE0B80`,
  `0x14BD00`. None named, so *why* the game wants the original capital is not established.
- **`0x1F1F40`**, the five-times caller of `SetDate` and a constructor of bare
  `CHistoryEntry`s. Not read.
- **Nothing here was read live.** Every figure comes out of the executable or out of the
  mod's own 2026-09-20 census.

## For the mod

- **`skill` inside a leader's `history` block is inert in this build** (`CSkillChange` slot 7
  is the empty stub). The dormant no-leader-skill-loss feature cannot use that route.
  `rank`, `loyalty`, `add_trait` and `remove_trait` all have working apply/undo bodies.
- **`CRankChange::Apply` clears a land leader off his unit** when it fires, in both
  directions. Anything that re-executes history mid-session will unassign land commanders.
- The whole subsystem is a reversible transaction log keyed on dates, with `AddEntry`
  (container slot 6) the single public way in. `CCountry::ChangeNeutrality` already uses it
  to log a change; the same idiom would let BiceLib log one.

## Frontier

`0x1FAEE0`, `0x1FCDA0`, `0x1ECA60`, `0x1EC730`, `0x1F1F40`, `0x1F4A50`, `0x27DCE0`, `0xD2B60`,
`0x1F2A80`, `0x200250`, `0x946F0`, `0xBF7C5`, `0xC1430`, `0xE0B80`, `0x14BD00`, `0x2D60C0`,
`0x2F4250`, `0x2F48A0`, `0x2F4EA0`, `0x2F5500`, `0x307BF0`, `0x1FA840`, `0x44CDA0`, `0x2EF40`,
`0x1D49D0`, `0x17F510`.

Separately: **`0x1BFC10` (`CUnit::SetLeader`)** — `FINDINGS-leaders.md` identifies it but
`project.json` still does not record it, and `CRankChange::Apply` is a fifth call site for it.

---

## Transcription note

Read and written by wave 11's agent B; transcribed by the session that collected the wave, because
an agent's `Write` is refused for this path. Spot-checked independently before transcription, all
confirming:

- **The daily read**, which is what refutes the brief's premise: VA `0x4DAA80` walks a list
  (`[esi]` payload, `[esi+8]` next), calls slot 6 through `[vftable+0x18]`, compares the result to
  `0x10a`, and on no match falls through to `mov edi, [0x170c2b8]` — `g_NullDate`.
- **The five slot-6 getters** at VA `0x5FC3B0`/`C0`/`D0`/`E0`/`F0`, each five bytes
  `mov eax, <token>; ret`, returning `0x10a`/`0x43c`/`0x28f`/`0x488`/`0x489`; and those tokens
  resolving through `saveTokens.json` to `rank`, `loyalty`, `skill`, `add_trait`, `remove_trait`,
  with `0x1f9` = `capital`.
- **`CSkillChange` slot 7**: `vtable.py` across the five classes shows four adjacent bodies
  (`0x5FC7F0`, `0x5FC8A0`, `0x5FC9C0`, `0x5FCA80`) and `CSkillChange` pointing at VA `0x60CD50`,
  which disassembles to a bare `ret 4` and is held by **1,420** tables.
- **The misattribution**, which the record had already contradicted itself about: `CLeader +0xC4
  trait_gain_tracker`'s own comment reads *"These are the same four bytes as CLeaderHistory +0x40
  (0x84 + 0…"* — so the record knew the two were the same bytes and carried both. `CLeader +0x84`
  was additionally commented "leader history (disabled in source, unverified)".

One trap-1 slip to record on the collecting side, not the agent's: the first attempt to verify the
five getters added the image base to `0x5FC3B0` (already a VA) instead of to the rva `0x1FC3B0`, and
decoded garbage. The agent's addresses were right.
