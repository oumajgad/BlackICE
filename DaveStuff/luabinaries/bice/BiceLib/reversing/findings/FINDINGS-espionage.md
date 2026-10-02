# Spies, intelligence, and what the espionage sliders buy

Read out of `hoi3_tfh.exe` on 2026-09-30 with the game **not running**. Addresses are
virtual, based at `0x400000`, with the rva beside them where a finding names one. Nothing
below was watched happening; every number is the image's.

**In one line.** `CSpyPresence` is a `0xF8`-byte record held one per country in a
`std::vector` at `CCountry +0x1160`, it carries **nine mission allocations and their
normalised shares**, the nine missions are resolved once a game day from
`RunCountryDailyPass` on the tick thread (not on a worker), the roll is the game's MT19937
at rva `0x1310F80`, and **three of the twenty-two espionage defines have no reader at
all** - `SPY_MISSION_CHANGE_DAYS`, `SPY_CONNECTION_DETECTION_CHANCE` and
`SPY_BASE_CONNECTION_DETECTION_CHANCE`. The two intel TBB fan-outs are a **different
subject from spies**: they rebuild every province's per-country fog of war, both from one
function that `RunDailyPass` calls last, and both bodies run on TBB workers.

## `CSpyPresence`, field by field

**The anchor.** The class has no vftable and so no RTTI record, but the name is the game's
own: luabind registers `CSpyPresence` (`.?AVCSpyPresence@@` at `0x1747B64`) with
`GetLevel`, `GetPriority`, `GetLastMissionChangeDate`, `GetMission` and `GetSpyPresence`.
The layout is anchored on

- **`CCountry::GetSpyPresence`, `0x444920 / 0x44920`** - six instructions, `ret 4`, `this`
  in ecx: `return (char*)this->espionage[+0x1160] + tag->id * 0xF8`. That fixes the stride
  at `0xF8` and the indexing at the country id.
- **the constructor, `0x52D380 / 0x12D380`**, `ret 0xC`, which writes every field below and
  whose two `mov dword ptr [reg], 0x15BC568` writes (`0x52D3D6` and `0x52D3F8`) prove the
  two embedded subobjects. The RTTI export names `0x15BC568` **`CStaticModifier`**.
- **`CCountry::SaveContents`**, whose espionage block (`0x4D1D60`-`0x4D1F35`) walks the
  vector and writes six keys, and **`CCountry::LoadKey`** (`0x4CCDA0`), which reads them
  back. `(this->+0x1164 - this->+0x1160) / 0xF8` is the count, at `0x4D1D71` and four more
  places - the `0x84210843` magic with `sar edx, 7` is division by 248.

| offset | name | save key | |
| --- | --- | --- | --- |
| `+0x00` | `level` | `spy_allocation` | spies present, **x1000** - 10 spies is 10000. Clamped to `[0, MAX_SPY_LEVEL]` by the setter |
| `+0x04` | `priority` | `spy_priority` | a plain int, 0..3 |
| `+0x08` .. `+0x28` | `missions[9]` | `spy_mission` | plain ints, one per `SpyMission` - how many spies are put on each |
| `+0x2C` .. `+0x4C` | `mission_share[9]` | - | **derived, x1000**: `missions[k] * 1000 / sum(missions)`. Never saved |
| `+0x50` | `last_mission_change` | `spy_date` | a tick; the constructor sets it to `[0x170C2B8]` (43800000, the epoch) |
| `+0x54` | `lower_unity_modifier` | - | a `CStaticModifier` **held by value**, `0x48` bytes |
| `+0x9C` | `raise_unity_modifier` | - | the second one, same size |
| `+0xE4`, `+0xE8` | `target` | - | a `CCountryTag`: the country the record is *about* |
| `+0xEC`, `+0xF0` | `owner` | - | a `CCountryTag`: the country whose vector this is |
| `+0xF4` | `covert_ops_points` | `covert_ops_points` | x1000, capped at `SPY_COVERT_OPS_MAX` |
| | | | `0xF8` bytes in all |

Which tag is which is read off the construction site, not guessed:
`0x4D5017` calls the constructor with `(out, &otherCountryTag, &ownerTag)` inside a loop
over the country database, so `+0xE4` takes the second argument and `+0xEC` the third.
`CSpyPresence::IsHostileMission` bears it out - it resolves `+0xE4` to a country and asks
*that* country whether it is allied with `+0xEC`.

`+0x54` and `+0x9C` are `0x48` apart and `0x54 + 0x48 = 0x9C`, which is what fixes the
`CStaticModifier`'s size; each has a values array pointer at its own `+0x18` and a
`std::string` at its own `+0x2C` (capacity `0xF`, size 0, first byte 0 - an empty MSVC
short string).

**The two writers are lists of ints and lists of thousandths, and the save says which.**
`spy_priority` and `spy_mission` go through `0x4608D0`, which formats each element with a
plain `%d`; `spy_allocation` and `covert_ops_points` go through `0x4C8050`, which converts
each element with `0xA694C0` - a divide by 1000 and a `%d.%03d`. So the priority and the
mission counts are whole numbers and the level and the covert ops points are thousandths.

### The owner is `CCountry`, and the vector is one record per country

`CCountry +0x1160` / `+0x1164` / `+0x1168` is a `std::vector<CSpyPresence>` - begin, end,
capacity. The constructor (`0x4C8A40`) zeroes all three at `0x4C9ABF`, `0x4C9AC5` and
`0x4C9ACB`, and the country's teardown (`0x4CA740`) destroys the range at `0x4CA982` and
zeroes them again.

**It is sized once, from the country count.** `0x4D4FC9`, inside `0x4D4C50`, calls
`0x50EB70` with `ecx = &country->espionage` and the country count (`countryDB[+0x168]`),
then loops the whole country database building one record per country through the
constructor. So the index into the vector is the country id, which is also the index into
`CCurrentGameState +0xBBC` - both the daily pass and `GetSpyPresence` rely on that.

### How a presence grows and shrinks

Four things move `+0x00`, and no others were found:

| | |
| --- | --- |
| **up** | `CDistributeEspionage::Distribute` (below) hands out whole spies from the country's pool |
| **up/down** | `CSpyPresence::SetLevel` (`0x52D4A0 / 0x12D4A0`), `this` in **EAX**, `ret 4`: store, floor at 0, cap at `[0x170D164]` (= 10000, `MAX_SPY_LEVEL`, ten spies). `modify_spies` uses this - see `FINDINGS-script.md` |
| **down** | a spy caught by counter-espionage costs the perpetrator exactly `1000` - one whole spy - at `0x52E74F`, `add ecx, 0xFFFFFC18`, then floored at 0 and re-capped |
| **reset** | the constructor, at zero |

**`[0x170D164]` (rva `0x130D164`) is `MAX_SPY_LEVEL` and no instruction writes it** - it
holds 10000 in `.data` and is only ever read, by eight sites, all espionage. That agrees
with what `FINDINGS-script.md` already says about `modify_spies`. **`MAX_NUMBER_OF_SPIES`
is a different thing** and does not clamp the level: it is read only by
`CDistributeEspionage::Distribute` (`0x51ED2E`) and by the espionage view (`0x62890A`).

### `mission_share` is recomputed, not stored

**`CSpyPresence::SetMissionAllocation`, `0x52D4D0 / 0x12D4D0`** - `this` in ecx, the
mission index on the stack, the value in **EAX**, `ret 4`:

```
missions[mission] = value
total = missions[0] + ... + missions[8]
if (total == 0) { mission_share[0..8] = 0; return }
for k in 0..8:  mission_share[k] = missions[k] * 1000 / total
```

so `mission_share` is each mission's share of the country's spies in that target, in
thousandths, and every mission effect below is scaled by it. It is not written to the save
and does not need to be: **`CCountry::LoadKey` calls the same setter** (`0x4CE583`) for
every one of the nine values it reads, dividing the flat index by 9 to get the country
(`0x38E38E39`, then `shr ecx, 1`) and taking the remainder as the mission. So a loaded game
has the shares right.

## The nine missions, and which function resolves each

`SpyMission` is a luabind-registered enum (`.?AW4SpyMission@@`) and the nine localisation
keys sit consecutively in `.rdata` from `0x15EC590`, with `SPYMISSION_NONE` and
`SPYMISSION_MAX` beside them at `0x15C2CC0`/`0x15EF4D0`. The order there matches the order
the dispatcher tests the nine dwords in, and each handler reads exactly the define its name
would predict - which is what makes the mapping safe rather than a guess.

| # | offset | `SpyMission` | resolved by | its define | its share |
| --- | --- | --- | --- | --- | --- |
| 0 | `+0x08` | `COUNTER_ESPIONAGE` | `0x52E3A0 / 0x12E3A0` | `SPY_DETECTION_CHANCE` (`country +0x20`) | `+0x2C` |
| 1 | `+0x0C` | `MILITARY` | `0x52FD40 / 0x12FD40` | `SPY_MILITARY_INTEL_TIME_BASE` (`+0x9C`), `MILITARY_ESPIONAGE_DETECTION_CHANCE` (`+0xA0`), `MILITARY_ESPIONAGE_AT_BASE_CHANCE` (`+0xA4`) | `+0x30` |
| 2 | `+0x10` | `TECH` | `0x52EBE0 / 0x12EBE0` | `TECH_ESPIONAGE_BASE_CHANCE` (`+0x94`), `TECH_ESPIONAGE_TECH_PICK_FACTOR` (`+0x98`) | `+0x34` |
| 3 | `+0x14` | `BOOST_RULING_PARTY` | inline, `0x53010C`-`0x53017C` | `SPY_PARTY_ORGANIZATION_BOOST` (`+0x38`) | `+0x38` |
| 4 | `+0x18` | `BOOST_OUR_PARTY` | inline, `0x530182`-`0x5301F7` | `SPY_PARTY_ORGANIZATION_BOOST` | `+0x3C` |
| 5 | `+0x1C` | `LOWER_NATIONAL_UNITY` | `0x530340 / 0x130340`, first half | none - a modifier | `+0x40` |
| 6 | `+0x20` | `INCREASE_THREAT` | inline, `0x5301F7`-`0x530281` | `SPY_THREAT_INCREASE_ACTION` (`+0x54`) | `+0x44` |
| 7 | `+0x24` | `RAISE_NATIONAL_UNITY` | `0x530340`, second half | none - a modifier | `+0x48` |
| 8 | `+0x28` | `COVERT_OPS` | inline, `0x530281`-`0x53032C` | `SPY_COVERT_OPS_GAIN` (`+0x80`), `SPY_COVERT_OPS_MAX` (`+0x84`) | `+0x4C` |

### The two entry points

**`CCountry::DailyEspionagePass`, `0x4FFD10 / 0xFFD10`** - `0x4FFD10` to the `ret 4` at
`0x4FFEBD`, one `CCountry*`. Its **one caller is `0x4DB93E`, inside `RunCountryDailyPass`**
(`0x4DA530`-`0x4DC239`), which `RunDailyPass` calls in its *serial* country loop at
`0x682E1A`. So espionage is resolved **once per country per game day, on the thread that
runs the tick** - not on a TBB worker.

```
for (i = 0; i < gamestate->countryCount; ++i) {
    target = gamestate->countries[+0xBBC][i]
    if (target->ownedProvinces (+0xCF8) <= 0) continue
    presence = me->espionage + i * 0xF8
    if (presence->level <= 0) continue
    RunDailyMissions(presence, me->tag, target->tag)       // 0x5300A0
}
own = me->espionage + me->tagId * 0xF8
if (own->missions[0] != 0) CatchSpies(own, &me->tag, &me->tag)   // 0x52E3A0
```

The second call is the one that matters for detection: a country's **own** record is where
its counter-espionage sits, and the pass runs that arm directly rather than through the
dispatcher.

**`CSpyPresence::RunDailyMissions`, `0x5300A0 / 0x1300A0`** - `0x5300A0` to the `ret 0x10`
at `0x530331`, `this` in **ESI**, and two `CCountryTag`s **by value** on the stack
(`actorTag`, `actorId`, `targetTag`, `targetId` - which is what `ret 0x10` counts). It
tests each of the nine dwords in turn and does nothing for a zero. **Mission 5 and mission
7 are not here**: they are modifiers rather than daily effects, and `0x530340` applies them
from somewhere else entirely (below).

**Mission 1 is throttled to one day in eight.** `0x5300D6`:
`0x44C5C0(&gamestate->tick[+0xBDC]) + targetId`, `and 0x80000007`, with the usual
negative fix-up, and the handler runs only when that is zero. So military intel resolves on
the day where `(day + targetId) mod 8 == 0`, which spreads the eight-day cycle across the
countries.

### The arithmetic, in thousandths

Every mission effect has the same first two terms. Writing `L` for `level` (x1000) and
`S[k]` for `mission_share[k]` (x1000):

    effect = L * DEFINE / 1000 * S[k] / 1000

**Mission 3, boost ruling party** (`0x53010C`): the amount goes to the **target's own**
ruling ideology - `target->ideology (+0x1140)`, index `[ideology + 0x4C]` - added into
`target->+0x10C4[index]` and, unless the total would go negative, also into
`[target->+0x10D4 + index*16] + 0xC`. **Mission 4, boost our party** (`0x530182`) is the
same code with the **actor's** ideology index instead. What `CCountry +0x10C4` and `+0x10D4`
are is **not established** here; the define's name says party organisation and that is as
far as this goes.

**Mission 6, increase threat** (`0x5301F7`): `SPY_THREAT_INCREASE_ACTION`, then
`x * 1000 / 10000` - a divide by ten - then `0x42F100` on the target country and
`0x4F4E80(target@EDI, &amount, &1000)`. Neither of those two was read.

**Mission 8, covert ops** (`0x530281`): `SPY_COVERT_OPS_GAIN`, then a range test
(`-1607028 .. 2147483` in thousandths) picking a 32-bit or 64-bit path, then
`covert_ops_points (+0xF4) += x`, capped at `SPY_COVERT_OPS_MAX` (`0x530326`). The cap is a
hard store, not a refusal.

**Mission 2, tech espionage** (`0x52EBE0`, `ret 0xC`):

    chance = L * TECH_ESPIONAGE_BASE_CHANCE / 1000
    chance = chance * S[2] / 1000
    percent = chance / 1000
    if (MT19937() % 100 > percent) return                     ; 0x52EC4B..0x52EC5A
    ... both countries' CTechnologyStatus (+0xDF8), then 0x540D60 ...

so the chance is read as **whole percent**, and the comparison is `>` - a computed 0%
still succeeds when the draw's remainder is 0, i.e. one day in a hundred. The tech pick
itself uses `TECH_ESPIONAGE_TECH_PICK_FACTOR` at `0x52EEED` and was not read.

**Mission 1, military intel** (`0x52FD40`, `ret 0xC`), as far as its chance:

    timeBase = SPY_MILITARY_INTEL_TIME_BASE / 1000
    chance   = MILITARY_ESPIONAGE_DETECTION_CHANCE * 10000 / 1000     ; ten times the define
    chance   = chance * L / 1000 * S[1] / 1000
    landFactor  = 1000 + actor->modifiers[+0x1D8]                     ; modifier 59, MODIFIER_OFFMAP_LAND_INTEL
    navalFactor = 1000 + actor->modifiers[+0x1E0]                     ; modifier 60, MODIFIER_OFFMAP_NAVAL_INTEL
    atBase   = MILITARY_ESPIONAGE_AT_BASE_CHANCE
    ... then a walk of the target's list at +0xBAC ...

The modifier offsets are `id * 8`, so `+0x1D8` is 59 and `+0x1E0` is 60 - the trap that says
a modifier offset is not `id * 4`. The walk over `+0xBAC` was not read.

### Missions 5 and 7 are modifiers, and they are applied from the modifier rebuild

**`0x530340 / 0x130340`**, `0x530340` to the `ret 0x18` at `0x5305A5`. Six dwords of
arguments: the presence, a modifier accumulator, and the two tags by value. For mission 5
it builds a `CStaticModifier` **in the presence's own `+0x54`** from the template
`[0x1A86208] + 0x98`, then adds its values into the accumulator's `+0x18` array and appends
the object to the accumulator's vector at `+0x8`. For mission 7 it does the same into
`+0x9C` from the template `[0x1A86208] + 0x9C`. The two values it puts in are the
presence's `level` and its `mission_share[5]` (respectively `mission_share[7]`), through
`0x45A080`.

**The templates are named in the image.** `0x45B520`-`0x45B660` registers four modifier
definitions and stores each in the registry at `[0x1A86208]`:

| slot | name | |
| --- | --- | --- |
| `+0x98` | `spy_lower_national_unity` | id `0x3A` at registration |
| `+0x9C` | `spy_raise_national_unity` | `0x3B` |
| `+0xA0` | `spy_lower_neutrality` | `0x3C` |
| `+0xA4` | `spy_support_resistance` | `0x3D` |

So mission 5 is the `spy_lower_national_unity` modifier and mission 7 is
`spy_raise_national_unity`. **`spy_lower_neutrality` and `spy_support_resistance` are
registered and no mission uses them** - nothing in `0x530340` or `0x5300A0` reaches `+0xA0`
or `+0xA4`, and they are not in the nine.

**Its one caller is `0x4DEE93`, inside `0x4DDD80 / 0xDDD80`** - the function
`FINDINGS-production.md` lists as "called with the country after anything in the queue
completes and at the end of the espionage distribute. Not read." Part of it is now read:

```
for (i = 0; i < countryCount; ++i) {
    other = gamestate->countries[i]
    if (other->ownedProvinces (+0xCF8) <= 0) continue
    presence = other->espionage + me->tagId * 0xF8      ; THEIR spies in ME
    if (presence->level <= 0) continue
    0x530340(presence, accumulator, other->tag, me->tag)
}
```

so `0x4DDD80` is the country's static-modifier rebuild, and **the national unity a spy
mission moves is a modifier the rebuild re-derives from every foreign presence, not a
number anybody adds to daily.** That is why `CDistributeEspionage::Distribute` calls
`0x4DDD80` after each spy it places (`0x51F11D`) - a new spy changes the modifier at once.

## Detection, and `spiescaught`

**`0x52E3A0 / 0x12E3A0`**, `0x52E3A0` to the `ret 0xC` at `0x52EBDD`. `(CSpyPresence*,
CCountryTag* actor, CCountryTag* target)`.

**A fresh instance of the abutting-function trap.** `0x52EBE0` - the tech mission - starts
immediately after that `ret` with **no `int3` between them**: a fresh `push ebp; mov ebp,
esp` and its own SEH handler push `0xC8B2B4`. `image.functionStart(0x52EC11)` answers
`0x52EBE0` correctly, but a padding-based scan for the *end* of `0x52E3A0` runs 4.4 KB past
it into `0x52FD32`. That is the seventh pair this folder has found; the known list should
gain `0x52E3A0`/`0x52EBE0`.

The chance, all in thousandths:

```
base = SPY_DETECTION_CHANCE                                  ; country +0x20
if (actor == target) base += actor->modifiers[+0x1B8]         ; modifier 55, MODIFIER_COUNTER_ESPIONAGE
p   = actorCountry->espionage[target->id]                     ; the same record
c   = p->level * base / 1000
c   = c * p->mission_share[0] / 1000
if (actor == target)                                          ; the home-defence arm
    c = c * (1000 - 800 * (1000 - p->mission_share[0]) / 1000) / 1000
```

where **800** is `floorf(800.5f)` off the float at `0x160AADC` - the same
`floorf(N.5f)`-into-a-global shape as `Define10` and `Define50` in `CLASSES.md`, except
that here the float is inline and the value is used once. So a country that puts *all* its
home spies on counter-espionage gets the full chance and one that puts none there keeps a
fifth of it.

Then, per foreign country `other` (skipping the actor itself and anything with no
provinces):

```
q = other->espionage[target->id]                              ; THEIR spies in the target
if (q->level < 1000) continue                                 ; fewer than one whole spy
chance = c
if (actorCountry->0x4EF7C0(other->tag, 1)) {                   ; an ally, by the look of it
    if (target != actor) continue
    if (!IsHostileMission(q)) continue
    chance += 1000000                                          ; certainty
}
chance = chance * (1000 - targetCountry->modifiers[+0x150]) / 1000     ; modifier 42, MODIFIER_ESPIONAGE_BONUS
if (none of q->missions[0..8] is > 0)
    chance = chance * NO_MISSION_SPY_DETECTION_MULTIPLIER / 1000       ; country +0x3C
if ((MT19937() % 1000) >= chance) continue                     ; 0xAA2FD0
if ((MT19937() % 100) >= 10)      continue                     ; 0xAA2F80, a flat 1-in-10
q->level -= 1000 ; floor 0 ; cap MAX_SPY_LEVEL
if (target == actor) actorCountry->spiescaught (+0x11D4)++
if (player == actor) ... raise the message ...
```

**That increment at `0x52E779`/`0x52E780` is the only writer of `+0x11D4` that is not a
reset.** A displacement-exact sweep finds nine sites on a country: the constructor's zero
(`0x4C9B6D`), `CCountry::LoadKey` (`0x4CE5F1`), `CCountry::SaveContents` (`0x4D08A4`),
`0x4D2BA7`, the monthly reset in `CCountry::UpdateMonthly` (`0x4DC8D3`), this
read-increment-write pair, and two reads in the espionage view (`0x6202DF`, `0x62849E`).

**So `spiescaught` has no gameplay consequence at all.** Nothing reads it but the save
writer and the two UI sites, and the UI strings beside them are
`value_spies_caught` / `ESP_SPIES_CAUGHT` and `foreign_spy_actions_indicator` /
`DETECTED_SPY_ACTIONS`. It is a counter for the player's espionage screen, reset every
month, and a mod cannot make anything hang off it without new code.

**Two surprises, both read twice.**

- **`MODIFIER_ESPIONAGE_BONUS` is read off the *target*, and it *lowers* the chance.** In
  the home-defence arm the target is the catcher itself, so a country's own
  `espionage_bonus` makes it worse at catching spies in its own territory. The instruction
  is `mov ecx, [eax + 0x150]` with `eax = [ebp-0x2C]`, and `[ebp-0x2C]` is set at
  `0x52E3D3`-`0x52E3D8` from the third argument. Reported, not explained.
- **`IsHostileMission` gates the ally case the other way round from what the shape
  suggests.** `CSpyPresence::IsHostileMission` (`0x52E340 / 0x12E340`, presence in **EAX**,
  bare `ret`) answers 1 when any of missions 1, 2, 4, 5, 6 or 8 is set - so
  `COUNTER_ESPIONAGE`, `BOOST_RULING_PARTY` and `RAISE_NATIONAL_UNITY` are the three
  benign ones, and for mission 0 it additionally asks whether the record's target is allied
  with its owner. An ally's benign spies are skipped entirely; an ally's hostile spies get
  `+1000000` on the chance, which the `% 1000` roll cannot beat.

### The rolls are the MT19937 at rva `0x1310F80`, and they are not signed

Both helpers end in `0xAA2B90` with `eax = 0x1710F80`, which is rva `0x1310F80` - the
generator state the rest of the folder already names.

| | |
| --- | --- |
| `0xAA2FD0 / 0x6A2FD0` | out pointer in **ESI**, returns it. `*out = ((r % 1000) * 1000) * 1000 / 1000000`, which is `r % 1000` - a random fraction in thousandths |
| `0xAA2F80 / 0x6A2F80` | returns the raw draw in eax |
| `0xAA2B90 / 0x6A2B90` | the tempering: `y ^= y>>11; y ^= (y<<7)&0x9D2C5680; y ^= (y<<15)&0xEFC60000; y ^= y>>18`, state in **EAX**, index at `+0x9C0`, reload through `0xAA2C80` |

**The shifts are `sar`, not `shr`** - an arithmetic right shift where MT19937 specifies a
logical one - so this is not a canonical MT19937. It matters for one reason and only one:
the **last** step is `mov eax, ecx; sar eax, 0x12; xor eax, ecx`, and the top bit of an
arithmetic shift of `ecx` equals the top bit of `ecx`, so the xor clears it. **Every draw
is therefore in `[0, 2^31)` and non-negative**, which is why the `cdq; idiv 100` in the
second gate and in the tech mission is safe. A first reading here had it the other way
round and would have reported a 55% catch rate; the sign is worth checking before anyone
writes a formula from an `idiv` in this image.

## The espionage leadership slider

**`CDistributeEspionage::Distribute`, `0x51ED00 / 0x11ED00`**, slot 0, the shape
`FINDINGS-production.md` fixes for all ten siblings. Three phases.

**1. The pool.** In fixed 15 (32768 is 1), with `available` the slider's allocation:

    x = basePercentage(+0x8) * factor(+0x10) * available * 1000
    country->spy_pool (+0x1170) += (x >> 15) * LEADERSHIP_TO_SPIES / 1000

`LEADERSHIP_TO_SPIES` is `economy +0x24`, read at `0x51ED9C`; `MAX_NUMBER_OF_SPIES` is
`country +0x1C`, read at `0x51ED2E` and divided by 1000 straight away, so it is a **count of
spies**, not thousandths. `+0x1170` is the field the save writes as `spies`.

**2. Count the priority bands.** For every country whose presence is not already at
`maxSpies`:

    band = presence->priority
    if (presence->level >= (int)(maxSpies * 0.7 + 0.01) * 1000) band--
    clamp band to [0, 3]
    buckets[band]++

The 0.7 and the 0.01 are the doubles at `0x160A600` and `0x160A5F8`. So **a presence that
has already reached 70% of `MAX_NUMBER_OF_SPIES` drops a priority band**, which is how the
game stops one target soaking up everything.

**3. Spend, highest band first.**

```
for (band = 3; band > 0; --band) {
    if (spy_pool / 1000 < 1) break
    if (buckets[band] == 0) continue
    perTarget = max(1, (spy_pool / 1000) / buckets[band])
    for (i = *cursor; i < countryCount; ++i) {
        ... recompute band for presence i, skip unless it equals this band ...
        if (presence->level >= maxSpies * 1000) continue
        if (spy_pool / 1000 < 1) break
        give = min(maxSpies - presence->level / 1000, perTarget)
        if (give <= 0) continue
        *cursor = i + 1
        presence->level += give * 1000    (floor 0, cap MAX_SPY_LEVEL)
        spy_pool -= give * 1000
        0x4DDD80(country)                 // rebuild the static modifiers
    }
    if (nothing was placed or *cursor >= countryCount) *cursor = 1
}
out = 0
```

Two things this settles.

- **Priority band 0 never receives a spy.** The loop is `while (band > 0)`
  (`test esi, esi; jg` at `0x51F15E`), so 0 means "none here" and the usable bands are 1, 2
  and 3.
- **The class carries a round-robin cursor per band.** `edi` starts at `this + 0x34` and
  drops by 4 each band, so `+0x34`, `+0x30` and `+0x2C` are the three cursors and `+0x28`
  is untouched by this body. `CDistributeEspionage` is therefore at least `0x38` bytes,
  against `CDistributeProduction`'s `0x30`. The cursor is why the slider does not always
  favour the first country in the list.

`Distribute` returns zero, like production's.

## The two intel fan-outs: province fog of war, not spies

`ClearIntelFunctor` and `UpdateIntelFunctor` have nothing to do with `CSpyPresence`.
Both are launched from **one** function.

**`0x688D40 / 0x288D40`** takes a `CCurrentGameState*`. `FINDINGS-aisched.md` has its
callers right - six, of which `0x683056` is the **last call in `RunDailyPass`** - and got
one thing wrong that is worth correcting: it reports `0x689278`, the `UpdateIntel`
launcher's call site, without saying where it is, and `image.functionStart(0x689278)`
answers `0x689201`, which is not a function at all (`add dword ptr [ebp - 0x18], 0xC`).
**Both launchers are called from inside `0x688D40`**, `0x688DD8` and `0x689278`, with a
serial country loop between them.

    esi   = (state->+0xB90 - state->+0xB8C) / 4          ; the PROVINCE count
    _alloca(esi * 12)                                    ; 0x688D7D, a 12-byte-per-province scratch
    grain = max(1, esi / ([0x170ABB0] == 1 ? 1 : 32))
    range = { end = esi, begin = 0, grain }              ; ECX
    0x68E510(range, 0x6880B0())                          ; ClearIntel
    ... a serial loop over the countries, gated on [c+0x44] and [c+0xD60] ...
    grain = max(1, provinceCount / ([0x170ABB0] == 1 ? 1 : 32))
    0x68E5E0(range, 0x6882D0(&state->countries, &state->provinces))   ; UpdateIntel

So **both iterate provinces, not countries**, and both take the same grain: a
**thirty-second** of the province count, where the AI fan-out takes a sixteenth. Both save
`[0x1A857BF]`, set it to 1 and restore it, the same as the other fan-outs.

**What `ClearIntel` does per element** - `0x68F170`'s serial body is `0x688170 / 0x288170`,
range in **EAX**, functor at `[ebp+8]`:

```
for (i = begin; i != end; ++i) {
    prov = functor->provinces[i]
    memset(prov->+0x370, [0x170AD30] ? 0 : 9, prov->+0x374)
    h = prov->+0xD4
    h->+0x278 = 0
    h->+0x13C = 1
    scratch[i].byte8 = (h->+0x13D && h->+0x22) ? 1 : 0
    if (that byte) ... prov->+0x334 (the owner tag) and the country database ...
}
```

`+0x370` / `+0x374` is the per-country intel array and its length, which
`FINDINGS-mapmode.md` already names, and 9 is the level that file records for a country's
own provinces. So **`ClearIntel` wipes the whole fog-of-war table to "everybody sees
everything" when `[0x170AD30]` (rva `0x130AD30`) is zero and to "nobody sees anything" when
it is set** - that global is the fog-of-war switch, and `0x689280` tests it again right
after the second fan-out. What `prov + 0xD4` is was not established.

**`UpdateIntel`'s per-element body** is `0x6883B0 / 0x2883B0`, range in **ECX**, functor at
`[ebp+8]`. It also indexes `functor->provinces[i]`, gates on `prov->+0xD4->+0x13D`, reads
the province's owner (`+0x334`) and controller (`+0x338`), compares the controller against
`functor->+0x10`, and resolves tags to countries through `0x402610`. It is 2.4 KB long and
was **not read past `0x688480`**; what it writes back into `+0x370` is not established here.

**The thread, exactly.** `RunDailyPass` runs on the tick thread; `0x688D40` runs there;
the `start_for::execute` bodies - and therefore `0x688170` and `0x6883B0` - run wherever
TBB schedules them. `parallel_for` is `spawn_root_and_wait`, so the calling thread
participates too: **some elements run on the tick thread and the rest on workers, and which
is which is not decidable statically.** For a BiceLib hook that means the same constraint
`FINDINGS-aisched.md` states for `ProcessAI`: no main Lua state, no message, no ImGui
frame - and here also no assumption that the hook is *off* the tick thread either.

`[0x170ABB0]` (rva `0x130ABB0`) making the grain the whole range when it is 1 is the same
unresolved global `FINDINGS-aisched.md` flags; if it is 1 in a normal game these fan-outs
are a single chunk and effectively serial.

## Which defines feed espionage, and the three that feed nothing

Twenty-two entries of the `country` block (`CDefines + 0xCC`) are espionage or intel. The
readers below come from a displacement-exact sweep: find every `mov reg, [reg2 + 0xCC]` in
`.text` by locating the four-byte displacement and decoding backwards, then follow that
register - and any register it is copied into - forward 160 instructions, recording every
memory read through it. That finds inlined `GetDefines` as well as the call, which is
trap 8's blind spot; every reader listed was then checked in the disassembly, and the
false positives from unrelated `+0xCC` fields (`0x793A95`, `0x608A90`, `0x693E02`,
`0x7AA2CD`, `0x6C25BD`, `0x593DC7` among them) were dropped.

| offset | define | readers |
| --- | --- | --- |
| `+0x1C` | `MAX_NUMBER_OF_SPIES` | `0x51ED2E` slider, `0x62890A` espionage view |
| `+0x20` | `SPY_DETECTION_CHANCE` | `0x52E473` |
| **`+0x24`** | **`SPY_MISSION_CHANGE_DAYS`** | **none** |
| **`+0x28`** | **`SPY_CONNECTION_DETECTION_CHANCE`** | **none** |
| **`+0x2C`** | **`SPY_BASE_CONNECTION_DETECTION_CHANCE`** | **none** |
| `+0x30` | `SPY_UNIT_DETECTION_CHANCE` | `0x89F55A` |
| `+0x34` | `SPY_INTEL_MISSION_BONUS` | `0x624C55` espionage view, `0x89F503` |
| `+0x38` | `SPY_PARTY_ORGANIZATION_BOOST` | `0x530117`, `0x53018D` |
| `+0x3C` | `NO_MISSION_SPY_DETECTION_MULTIPLIER` | `0x52E700` |
| `+0x54` | `SPY_THREAT_INCREASE_ACTION` | `0x53020C` |
| `+0x74` | `COUP_CHANCE_PER_POSITION` | `0x4F7AE9`, `0x66A0C7`, `0x7D156B`, `0x80AC16` |
| `+0x7C` | `SPY_BASE_PRODUCTION_DETECTION_CHANCE` | `0x62BDD8`, `0x69EDB4`, `0x69EFAB`, `0x69F190` |
| `+0x80` | `SPY_COVERT_OPS_GAIN` | `0x530296` |
| `+0x84` | `SPY_COVERT_OPS_MAX` | `0x530318`, `0x4A35CE`, `0x80B2A1`, `0x80BCC8` |
| `+0x88` | `COUP_COVERT_OPS_COST` | `0x4F7D42`, `0x4F7F53`, `0x61F6E5` |
| `+0x94` | `TECH_ESPIONAGE_BASE_CHANCE` | `0x52EC11` |
| `+0x98` | `TECH_ESPIONAGE_TECH_PICK_FACTOR` | `0x52EEED` |
| `+0x9C` | `SPY_MILITARY_INTEL_TIME_BASE` | `0x52FD68` |
| `+0xA0` | `MILITARY_ESPIONAGE_DETECTION_CHANCE` | `0x52FD8D` |
| `+0xA4` | `MILITARY_ESPIONAGE_AT_BASE_CHANCE` | `0x52FE0C` |
| `+0xA8` | `SPY_MILITARY_INTEL_LOCAL_TIME_BASE` | `0x9BE41E` |

Plus `LEADERSHIP_TO_SPIES` (`economy +0x24`), whose two readers `FINDINGS-production.md`
already has.

**The three dead ones are worth the mod's attention.** `SPY_MISSION_CHANGE_DAYS` is
particularly striking: `CSpyPresence +0x50` records the tick the mission last changed, the
save carries it as `spy_date` and Lua exposes it as `GetLastMissionChangeDate`, but the
define that would make it mean anything is read by nothing, so **there is no cooldown on
changing a spy mission**. The two connection-detection defines are read by nothing either;
`SPY_BASE_PRODUCTION_DETECTION_CHANCE`, which sits beside them in `defines.lua` and looks
like a sibling, *is* read, four times.

The blind spot in the method: a reader that stashes the block pointer in a stack slot and
reloads it more than 160 instructions later, or that indexes the block through a computed
offset, would be missed. Neither shape appears in any of the readers that were found.

## Corrections to the existing record

- **`FINDINGS-aisched.md` leaves `0x689278`'s container unattributed** and
  `image.functionStart` answers `0x689201`, which is not a function. Both intel launchers
  are called from inside `0x688D40`.
- **`FINDINGS-aisched.md` says the intel fan-outs' period and iteration are unknown.** They
  iterate the **province** vector, the grain is a thirty-second of it, and the daily call is
  `RunDailyPass`'s last (which that file does say for `ClearIntel`).
- **`FINDINGS-production.md` lists `0x4DDD80` as "not read".** Its espionage arm is now
  read: it walks every foreign country's presence in this one and applies the two national
  unity modifiers through `0x530340`. The rest of it is still unread.
- **`CLASSES.md` describes `CCountry +0x1160` as "`0xF8` an entry, one per country: `+4` is
  the priority the `spy_priority` key sets, `+0xF4` the covert ops points".** That is
  right as far as it goes; it is now a full layout. **`+0x1164` is the vector's `end`, and
  `+0x1168` its capacity** - the entry calls `+0x1164` `_end`, which is correct.
- **Add `0x52E3A0`/`0x52EBE0` to the abutting-function list** in `image.py`'s docstring and
  in `CLASSES.md`.

## What is not established

- **Everything live.** The game was not running. No presence was read out of memory, no
  save was fitted against these offsets, and no spy was watched being caught.
- **`CSpyPresence +0x54` and `+0x9C` are `CStaticModifier` by value, and that is all.** The
  class's own 14 slots were not read and neither was `0x4593F0`, its constructor, beyond
  the vftable write and the empty string it leaves.
- **`CCountry +0x10C4` and `+0x10D4`**, which the two party-boost missions write. The
  define is `SPY_PARTY_ORGANIZATION_BOOST` and the index is an ideology's `+0x4C`, so
  "party organisation per ideology" is the obvious reading and is recorded here as a
  reading, not a finding. `+0x10D4`'s stride-16 indirection is not explained at all.
- **`0x4EF7C0`**, the two-argument predicate on a country that decides the ally case, and
  `0x42F100`, `0x4F4E80` (the threat pair), `0x540D60` (the tech steal) and `0x44C5C0` (the
  tick-to-days helper). All named as callees only.
- **The bodies of `0x52EBE0` past `0x52EC60` and `0x52FD40` past `0x52FE28`** - what tech
  is actually stolen, and what the military-intel walk over the target's `+0xBAC` does.
  Only their chances were read.
- **`UpdateIntelFunctor`'s per-element body past `0x688480`.** What it writes into a
  province's intel array is not read, so "UpdateIntel recomputes what ClearIntel wiped" is
  inference from the pairing and the names.
- **`prov + 0xD4`**, which `ClearIntel` and `UpdateIntel` both dereference, and the
  12-byte-per-province scratch array `0x688D40` allocates for them.
- **`[0x170AD30]` being the fog-of-war switch** is inference from what `ClearIntel` fills
  with (9 when clear, 0 when set) and from `0x689280` testing it again after
  `UpdateIntel`. Nothing names it.
- **The two messages `CDistributeEspionage::Distribute` raises.** The brief says two; the
  arithmetic above is what was read, and the message text was not chased.
- **`CDistributeEspionage +0x28`.** Three of the four dwords at `+0x28`..`+0x34` are the
  band cursors; `+0x28` would be band 0's and the loop never reaches it, so whether it is
  that or something else is open.
- **Which of the five non-tick callers of `0x688D40`** matter, so "intel is rebuilt daily"
  remains a floor, exactly as `FINDINGS-aisched.md` says.
- **`spy_lower_neutrality` and `spy_support_resistance`**, the two registered modifier
  definitions no spy mission uses. Something else may build them; nothing in the espionage
  path does.
