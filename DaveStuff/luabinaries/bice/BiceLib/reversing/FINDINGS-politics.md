# Alignment, and the country's daily pass

Why a country drifts Axis/Allies/Comintern, when a faction may invite it, and what the
game does to every country once a day. Read out of the executable on 2026-09-30;
addresses are virtual, based at `0x400000`, with the rva beside them where a finding
names one. Nothing here needed the game running.

**In one line.** `0x4DA530` is not a politics pass - it is **everything a country does in a
day**, and politics is five of its phases. Alignment is a **2-D position on a political
compass**, one `CIdeologyGroup` per corner; every `ALIGNMENT_INTERVAL` days an unaligned
country's position moves by the sum of unit vectors toward each group, each scaled by a
seven-term weight; a country that is *in* a faction does not drift at all - it is snapped
onto its faction leader's position. A faction may invite a country only while the
straight-line distance between the two positions is under `FACTION_JOIN_DIST`.

---

## 1. The classes the compass is made of

`CAlignment` (vftable `0x15C0CC0`, 6 slots, derives `CPersistent`, persistent type id
`0x18D`) is **embedded in `CCountry` at `+0xDC`** - that is where `CCountry::LoadKey`'s
`alignment` key reads (`FINDINGS-fieldmap.md`), and every caller in this document passes
`country + 0xDC`. Its layout, from the constructor `0x4C3050` (rva `0xC3050`, `__stdcall`,
`ret 4`, the object on the stack):

| offset | |
| --- | --- |
| `+0x0` | vftable |
| `+0x4` | `0x18D`, the `CPersistent` type id |
| `+0x8`, `+0xC` | **the position**, x and y, thousandths. `CAlignment::LoadKey` (`0xC31B0`) reads the `position` key into `+0x8` through `ParsePoint` |
| `+0x10`, `+0x14` | zeroed by the constructor; not otherwise read here |
| `+0x18` / `+0x1C` / `+0x20` | a `vector<int>` - **one weight per ideology group**, sized in the constructor to the group count and freed in the destructor (`0x4C3130`) |
| `+0x28` .. `+0x44` | the bounding box of all group positions, rebuilt by `0x4C46C0` and used by `0x4C4B00` to clamp a move |

The corners are `CIdeologyGroup` (vftable `0x15C2728`, 7 slots). `CIdeologyGroup::LoadKey`
(`0x526E60`) settles two of its fields, and this is the evidence for the whole geometry:

- key `position` (token `0x4B`) -> `ParsePoint(this + 0x58)` at `0x5270E4`, so
  **`CIdeologyGroup +0x58` / `+0x5C` is the group's x / y**.
- key `faction` (token `0x6BB`) -> allocates `0xD8` bytes, calls the `CFaction`
  constructor `0x5224B0(faction, this)` and stores it at `+0x54`.

`CIdeologyGroup +0x50` is the group's index into `CAlignment +0x18` (`0x4C4E60` is
`values[group->+0x50]`, three instructions long).

**`CFaction +0x8` is the `CIdeologyGroup` that owns it.** The constructor's second argument
lands there (`mov [esi+8], eax`, `0x5224E3`), and the only caller is the `faction` case
above. This is what the two distance predicates dereference.

**`CFaction +0xB4` is the index of that faction's `suseptibility_<tag>` modifier**, and this
is read, not guessed. Straight after loading the faction block, `CIdeologyGroup::LoadKey`
builds the string `"suseptibility_" + faction->tag` (the literal `'suseptibility_'` is at
`0x15C2690`, pushed at `0x526FEF`), takes the current length of the global
modifier-definition vector - `([0x1A86198] - [0x1A86194]) / 4` - writes it to
`CFaction +0xB4` at `0x527032`, and then registers a new `CModifier` under that name.
`CModifier.hpp` already records entries 140/141/142 as `suseptibility_axis` / `_allies` /
`_comintern`, which is the same three.

**`CCountry +0xD8` is the country's `CFaction*`, and it is never null.** A country in no
faction points at a shared singleton at `0x1A855A8`, lazily built with the same `0x5224B0`
constructor and then given a *different* vftable, `0x15C248C`. Every alignment term begins by
comparing `country->+0xD8` against that singleton and returning zero when they differ - so
**every alignment term is zero for a country that is already in a faction.**

The groups themselves live in a manager singleton at `0x1A878BC` (0x40 bytes, getter
`0x527280`), whose vector runs `+0x1C`..`+0x20`. Slot 6 on a group gates whether it counts
at all.

## 2. The three distance functions

All three fetch one `alignment` define through `GetDefines` (`0x445D90`) -> `CDefines +0xDC`,
square it, and divide by 1000 - which in HoI3's thousandths is exactly "square the define".
They compare it against a **squared** distance, so nothing takes a square root.

`0x4C4660` (rva `0xC4660`) is the shared distance: `this` in `ecx` is the `CAlignment`, the
second stack argument is the other position-bearing object, and it writes
`((a.x-b.x)^2 + (a.y-b.y)^2)` in thousandths through the first stack argument and returns
that pointer. Seven callers.

**`0x4C4CD0` / rva `0xC4CD0` - `FACTION_JOIN_DIST` (`+0x1C`).** `ret 8`, two stack
arguments: the country's `CAlignment` (`country + 0xDC`) and a `CFaction*`, whose `+0x8`
gives the group. Returns a bool in `al` via `setl`:

    joinable  <=>  distance(country.alignment, faction.group.position) < FACTION_JOIN_DIST

**This is the gate on faction invitations, and the game names it itself.** At `0xA3386A`,
inside the faction-action code, the call is followed on the false branch by a push of the
localisation key **`'FACTION_DISTANCE'`** (`0x15FACF4`) - the reason string the UI shows.
Five call sites: `0x6047C3`, and `0xA3386A` / `0xA339FF` / `0xA33E1A` / `0xA33E42` in the
two faction-action validity functions `0xA32FD0` and `0xA33CD0`.

**`0x4C4D20` / rva `0xC4D20` - `FACTION_STRAT_BONUS_DIST` (`+0x20`).** Byte-for-byte the same
function with a different define offset. Two callers: `0x4FAC8C` (inside `0x4FA0B0`, the
function that recomputes all seven alignment terms - the AI's or the tooltip's copy) and
`0x68BFBC`.

**`0x4C4D70` / rva `0xC4D70` - `FACTION_THREAT_DIST` (`+0x24`).** Not a predicate. `ret 0xC`,
three stack arguments - the `CAlignment`, an `int*` out, and a `CIdeologyGroup*` - returning
the out pointer:

    *out = distance^2 * 1000 / FACTION_THREAT_DIST^2      (thousandths)
    *out = -1                                            if the define is zero

Two callers, `0x4F54B9` and `0x4FBE00`. Note the second argument slot is reused as scratch by
the inner call, so the value is read back out of the caller's own stack.

## 3. The seven alignment terms

`0x4C3200` / rva `0xC3200` is the aggregator. `ret 0xC`; arguments `(CAlignment* this,
Point* out, CCountry* country)`. For each ideology group *i* whose slot 6 returns true it
fills `this->values[i]`:

    values[i]  =   Relation(i)        0x4C3950   (the first one assigns)
                 + Ideology(i)        0x4C3B10
                 + Proximity(i)       0x4C3C00
                 + AlignTowards(i)    0x4C3790
                 - Revanchism(i)      0x4C3E40   } only when the group is
                 - Threat(i)          0x4C4120   } within distance 200 of
                 - Repulsion(i)       0x4C4380   } the country's position

The distance gate is at `0x4C3361`: `cmp eax, 0x9C40` on the squared distance in whole units,
i.e. `dist^2 < 40000`, i.e. `dist < 200`. A group whose slot 6 is false gets `values[i] = 0`.

Then, in a second pass, it turns each group into a **unit vector** toward it - length rounded
to thousandths with `sqrtf` (`0x402000`), the `+0.0005` at `0x160A460` and a `1000000/len`
reciprocal - and returns

    *out = SUM over i of  unitVector(country -> group_i) * values[i] / 1000

`CAlignment::UpdateDaily`, `0x4C3620` / rva `0xC3620`, applies it. **Register convention:
`esi` is the `CAlignment`, `edi` is the `CCountry`, no stack arguments, plain `ret`.**

    if the country is in a real faction (slot 7 on CCountry+0xD8):
        if it is the faction leader (members.head->id == country->+0xCA8):  do nothing
        else:  alignment.position = leader->+0xE4, leader->+0xE8       # snapped
    else:
        drift = 0x4C3200(this, &drift, country)
        0x4C4B00(this, &clamped, &drift)        # clamp inside the group bounding box
        position += clamped

`leader->+0xE4` / `+0xE8` is the leader's own `CAlignment` position (`0xDC + 0x8`), which is
the same field by another name.

### Every term, in the units a modder types

Throughout, `mod[X]` is the country's modifier value `X` from the array at `CCountry +0xDA8`
(entry *n* at byte offset *n* x 8), as a fraction - so `(1 + mod[X])` is the code's
`(1000 + value)/1000`. `S = suseptibility_<factiontag>`, the modifier `CFaction +0xB4` names.
`faction(i)` is `CIdeologyGroup::GetFaction` (`0x527140`: `+0x54`, or the null-faction
singleton).

**Relation** - `0x4C3950`, `RELATION_WEIGHT` (`+0x4`). Zero if the faction has no members.

    mean over m in faction(i).members of  relation(country, m)
        x RELATION_WEIGHT
        x (1 + mod[SUSEPTIBILITY])
        x (1 + mod[S])

`relation(a, b)` is `a->+0xE28[b.id]->+0x38` - the pair's `CDiplomacyStatus`, field `+0x38`.
That `+0x38` is relation by position rather than by proof; see *What is not established*.

**Ideology** - `0x4C3B10`, `IDEOLOGY_WEIGHT` (`+0x8`). `ret 8`; the out pointer arrives in
**`edi`**, the group and the country on the stack. A flat term:

    if country.ideology (CCountry +0x1140) exists, passes its slot 17,
       and its group (CIdeology +0x50) is this group:
            IDEOLOGY_WEIGHT x (1 + mod[DRIFT_SPEED])
    else    0

**Proximity** - `0x4C3C00`, `PROXIMITY_WEIGHT` (`+0xC`). Zero if the faction has no members.

    max over m in faction(i).members of
        (10 - capitalDistance(country, m) / 500)        floored at [0x1A87334]
        x floor(m.maxIC / country.maxIC)                 <- integer division
      x PROXIMITY_WEIGHT
      x (1 + mod[SUSEPTIBILITY])
      x (1 + mod[S])

The distance term is literally `(5000000 - 1000*d) * 1000 / 500000`, which is
`2*(5000 - d)` thousandths. The IC ratio is `CCountry +0x60C` (`GetMaxIC`) and is an
**integer** divide before being scaled to thousandths, so a faction member smaller than the
country contributes exactly nothing. `capitalDistance` is `0x492030` on the two acting-capital
provinces (`CCountry +0xE24` via `0x42F100`).

**AlignTowards** - `0x4C3790`. Reads no `alignment` define; it reads the faction's own
`ALIGN_TOWARDS` modifier (entry 47, at `[modifier+0x18] + 0x178`, through `0x523560`) - which
is what `CFaction`'s `influence` string `align_towards_axis` names.

    (1 - leaderEffectiveNeutrality/100)
      x faction.ALIGN_TOWARDS
      x ((1 - countryEffectiveNeutrality/100) + [0x1A8732C])

Both neutralities are `CCountry +0xA90`; the leader's is clamped at zero, the country's is
not. `ret 8`; the group arrives in **`edi`**.

**Revanchism** - `0x4C3E40`, `REVANCHISM_WEIGHT` (`+0x10`). Subtracted.

    s = faction(i).progress / total world victory points      (0x522CC0)
    if s >= 0.5:  0
    else:
        (number of the country's claimed provinces (CCountry +0xD10) whose current
         owner is in faction(i))
          x (0.5 - s) x 5
          x REVANCHISM_WEIGHT
          x (1 + mod[SUSEPTIBILITY])
          x (1 + mod[S])

`0x522CC0` sums `province->+0x34` (victory points) over every province and divides the
faction's `progress` (`CFaction +0xAC`) by it. The 0.5 threshold is `floor(500.50003f)` -
the float at `0x160A5E8` put through `0x401FD0` (a truncating libm call) and `0xC08870`
(`_ftol`). The claim loop reads the province's owner tag at `+0x32C` and its id at `+0x330`.

**Threat** - `0x4C4120`, `THREAT_WEIGHT` (`+0x14`) and `LARGE_COUNTRY_IC` (`+0x2C`).
Subtracted. Zero if no member is found.

    t = max over m in faction(i).members of  country->+0xE28[m.id]->+0x5C
    t x THREAT_WEIGHT
      x (1 + mod[SUSEPTIBILITY])
      x (1 + mod[S])
      x min(country.baseIC / LARGE_COUNTRY_IC, 1)

The mod's own comment on `LARGE_COUNTRY_IC` - *"used to scale threat impact with country
IC"* - is exactly this clamp. `country.baseIC` is `CCountry +0x604`.

**One dead branch.** The loop also tracks whether any member's status has `+0x20` set (the
hostile flag `CCountry::IsEnemy` tests) and calls `GetDefines` at `0x4C41EE` on the first
hit - and then discards both the flag and the result. Nothing downstream reads either. This
is very likely where `WAR_THREAT` (`alignment +0x28`) used to be read; **`WAR_THREAT` has no
reader left in the image.**

**Repulsion** - `0x4C4380`, `REPULSION_WEIGHT` (`+0x18`) and `REPULSION_IC_FACTOR` (`+0x30`).
Subtracted. This one is a `thiscall`-alike: `ecx` is the `CAlignment`, `ret 0xC`.

    base = REPULSION_WEIGHT x (200 - distance(country.position, group.position))
    if base <= 0:  base
    if the country's ruling ideology belongs to this group:  base
    else:
        w = faction.leader.maxIC + (sum of all members' maxIC - leader.maxIC) / 4
        r = (country.maxIC x REPULSION_IC_FACTOR) / w
        if r > 1:  base x r
        else:      base

The distance here is a genuine integer square root, done by Newton's method at
`0x4C4480`-`0x4C4494`. The mod's comment on `REPULSION_IC_FACTOR` - *"If a country is of
another ideology, the repulsion factor is modified by this value times its max IC, divided
by the faction IC"* - matches the code term for term, including that it is **max** IC
(`+0x60C`) and not base IC.

### The schedule

The drift is **not** daily. Inside the country's daily pass, at `0x4DB864`:

    if today (gameState +0xBDC) > country->+0x124:
        CAlignment::UpdateDaily()
        country->+0x124 = today + (ALIGNMENT_INTERVAL / 1000) * 24

The tick is hours (`FINDINGS-tick.md`), so `ALIGNMENT_INTERVAL` is **days** and
`CCountry +0x124` is the next-due tick. BlackICE sets it to 24, so an unaligned country's
position moves once every 24 days - and every weight above is a move per *interval*, not
per day.

`0x4FA0B0` recomputes all seven terms from a second set of call sites (`0x4FA8E6`,
`0x4FA8FB`, `0x4FA911`, `0x4FA924`, `0x4FA937`, `0x4FA950`, `0x4FA962`) and also calls the
`FACTION_STRAT_BONUS_DIST` predicate. It is not read here; it is the obvious place to look
for the game's own alignment tooltip.

---

## 4. `0x4DA530` is `CCountry`'s daily pass, not a politics pass

`0x4DA530` to the `ret 4` at `0x4DC239`, one stack argument, the `CCountry*`. Everything from
`0x4DC242` to `0x4DC3F8` is SEH unwind funclets, not part of the body. The address is in **no
vftable** (`findRefs --address` finds zero references), and its one caller is `RunDailyPass`
at `0x682E1A` looping the country vector.

It is not confined to politics: convoys, lend-lease, IC, leaders, the underground and the AI
all get a phase. Calling it "the daily politics pass" (as `CANDIDATES.md` does) understates it
by a lot.

### Phase 1 - neutrality, at `0x4DA5CD`

    0x4DD8D0(country)                    unread
    0x4D8070(country)                    unread
    0x4DDD80(country)                    unread
    Neutrality (+0xA8C) clamped to [0, 100000]
    EffectiveNeutrality (+0xA90) = clamp(Neutrality - threatFromWorstEnemy, 0, 100000)

where `threatFromWorstEnemy` is `country->+0xE28[country->+0x11DC]->+0x5C`.
**`CCountry +0x11D8` / `+0x11DC` are the tag and the id of the country this one feels the most
threat from**, a cache written by `0x4E21E0` - which scans for the maximum of that same
`+0x5C` and starts from `'---'` / 0 (`0x4E23FC`, `0x4E34F4`). That function has **65 callers**
and is not called from the daily pass, so the pass reads a value someone else maintains.

The identical clamp-and-derive appears again inside `0x4FBF80`, so it is the canonical
formula, not a one-off. **This is the answer to "what writes EffectiveNeutrality": it is
Neutrality minus the threat from one single country, floored at zero.**

### Phase 2 - the neutrality drift, at `0x4DAE83`

    0x4FBF80(country@ESI, delta = mod[NEUTRALITY_CHANGE], logHistory = false)

`0x4FBF80` (rva `0xFBF80`) is `CCountry::ChangeNeutrality`: `esi` is the country, `ret 8`,
`+0xA8C += delta` floored at zero, then EffectiveNeutrality recomputed as above. With
`logHistory` set it also allocates a 0x18-byte history entry (`0x5F11F0`), stamps it with
today and appends it to the country's `history` (`+0xCCC`) - the daily call passes false, so
drift is silent. `mod[NEUTRALITY_CHANGE]` is entry 78, read as `[country+0xDA8] + 0x270`.
`0x4FC0E0` beside it is the plain setter.

So: **neutrality moves by exactly the country's `NEUTRALITY_CHANGE` modifier per day.** The
`NEUT_INCREASE_DIFF_CONTINENT` and `NEUT_REDUCTION_AT_CLAIMS` defines are not read here;
whatever feeds that modifier is elsewhere.

### Phase 3 - influence upkeep and the rebels' dissent, at `0x4DB671`

    0x503E90(country@ESI)                the daily influence upkeep
    if tag == 'REB':  country->+0x10B4 = 0

`0x503E90` (rva `0x103E90`), no stack arguments, `esi` the country:

    upkeep = INFLUENCE_UPKEEP                          (diplomacy +0xD0)
    for every country o:
        if o->+0xE28[us.id]->+0x2C != 0:               an influence is running
            diplo_influence (+0xA88) -= upkeep
            if diplo_influence < 0:
                diplo_influence = 0
                0x503F90(us, o.tag)                    cancel it - we cannot pay

`0x503D90` (rva `0x103D90`) is the matching read-only total: `(country, int* out)`, `*out` =
`INFLUENCE_UPKEEP` times the number of such countries. `0x4FBF00` counts the same `+0x2C`
flag and returns the count in `eax` (`ecx` the country, no arguments).

The dissent zeroing is bytes `0x4DB676`-`0x4DB691`: three byte compares of `+0xCA4`/`+0xCA5`/
`+0xCA6` against `'R'`,`'E'`,`'B'` and then `mov dword [ebx+0x10B4], 0`. It runs immediately
after `0x503E90`, so the rebel country pays upkeep and then has its dissent wiped
unconditionally, every day.

### Phase 4 - elections, at `0x4DBBC7`

    if country->+0xDFC->+0x7C == 0:  no elections at all
    due = last_election (+0xAB0)
    if due != [0x170C2B8]:                              a "never" sentinel
        due = AddMonths(due, country->+0x98 ? country->+0x98 : country->+0xDFC->+0x2C)
    if due <= today  or  [0x1BEA40C] != 0:
        0x4FC100(country, country is the player)        hold the election

`CCountry +0xDFC` is the `government` key's target; `+0x7C` on it is the "has elections" flag
and `+0x2C` the default term. `CCountry +0x98` is the `duration` key and overrides it.
`0x4B8C90(int* date @EAX, int months)` is the date-add helper, shared with the NAP rule below,
so **the term is in months.** `[0x1BEA40C]` forces an election regardless and is unidentified.

Straight after, at `0x4DBCA1`: if the ruling ideology (`+0x1140`) passes slot 17 and its
`+0x4C` entry of the array at `CCountry +0x112C` is zero, `0x4F72F0(country)` runs - read as
"the ruling party has no support left", unconfirmed.

### Phase 5 - surrender, at `0x4DBCCC`

    if country->+0xCF8 > 0:                             it still owns provinces
        v = 0x4FCB80(country, &out)
        if *v >= 1000 and isAtWar (+0xACC) != 0:
            if daysBetween(today, last_surrender (+0xAC8)) >= 30:
                0x4E8E80(country)
    else if country->+0x95:
        if it is in a real faction and is that faction's leader:
            0x4F6B20(country, 0);  0x502BC0(country, 0)

The 30-day gate is the same epoch arithmetic as `RunHourlyTick` - subtract `0x29C55C0`,
divide by 24, then 365 - applied to both dates. What `0x4FCB80` measures was not read; it is
a thousandths value compared against 1.0.

### The rest of the pass, in order

Listed so nobody re-derives the order. **Unread** means exactly that.

| at | call | what, where known |
| --- | --- | --- |
| `0x4DA5D7`/`DD`/`E3` | `0x4DD8D0`, `0x4D8070`, `0x4DDD80` | unread |
| `0x4DA722` | `0x50C0B0` | unread; gated on `gameState +0xD0C == 0`, `country +0x95`, and the country not sharing a faction with someone |
| `0x4DA734`-`51` | `0x530950` x3, `0x530CA0` | unread |
| `0x4DA83F` | `0x46C2E0` | unread |
| `0x4DA890`/`9A` | `0x4F8B80`, `0x4E1DA0` | unread; result accumulates into `+0xBCC` |
| `0x4DA940`-`0x4DAE80` | `0x4C7A10`, `0x4C6C30`, `0x4C7670`, `0x4C6930` | the **convoy** phase: erases from the vectors at `+0xA0`/`+0xA4`/`+0xA8` and `active_leaders` (`+0xE00`), adds `LL_CONVOY_EFF_REGAIN` (`economy +0x50`, the pass's only other define read, at `0x4DABB4`) to each convoy's `+0xAC`, and touches `convoys` `+0xB0` / `escorts` `+0xB4` |
| `0x4DAE9B` | `0x4FBF80` | neutrality drift - phase 2 above |
| `0x4DAEA2` | `0x507DF0` (`edi` = country) | unread |
| `0x4DAEA7` | `0x4D9170` | reads `SHARE_TECH_LEADERSHIP_COST` - the tech-sharing leadership drain |
| `0x4DAF35` | `0xA48B20` | unread, in a loop over countries that own provinces |
| `0x4DAFC0`-`0x4DB180` | - | erases from the vectors at `+0xA0`.. and `+0xF24`..; gated on `+0x1D8` (the AI) and `+0xF30` |
| `0x4DB2C0` | `0x5BB950` | unread |
| `0x4DB3D9` | `0x49DE80` | reads `military +0x330` |
| `0x4DB418`-`49` | `0x5020E0`, `0x4F1F50`, `0x4FEE70`, `0x4F0CC0`, `0x4F19F0` | the **economy** block. `0x4F0CC0` is the IC calculation: it writes `+0x604`, `+0x608`, `+0x60C` and `+0x610` (see `FINDINGS-ic.md`). `0x4F1F50` writes `+0x754`..`+0x790` and accumulates `+0x164`..`+0x17C` |
| `0x4DB671` | `0x503E90` | influence upkeep - phase 3 |
| `0x4DB691` | - | `dissent = 0` for `REB` |
| `0x4DB78C`-`AA` | `0x4FDF40`, `0x4FE7E0`, `0x4FD750` | unread |
| `0x4DB7C4` | `0x8A5C90` | unread |
| `0x4DB7EE` | `0x4EE860` | unread; gated on owning provinces and not being `REB` |
| `0x4DB87E` | `0x4C3620` | **alignment drift**, every `ALIGNMENT_INTERVAL` days |
| `0x4DB93E` | `0x4FFD10` | unread |
| `0x4DBB5E`/`64` | `0x507630`, `0x50A110` | the **underground**: `0x50A110` reads `UNDERGROUND_STRENGTH_GAIN` and `UNDERGROUND_DETECT_CHANCE` |
| `0x4DBBC2` | `0x4C07C0` | unread; every non-`REB` country that owns provinces |
| `0x4DBC9C` | `0x4FC100` | **elections** - phase 4 |
| `0x4DBCC7` | `0x4F72F0` | ruling-party support, unread |
| `0x4DBCDE` / `0x4DBE1D` | `0x4FCB80`, `0x4E8E80` | **surrender** - phase 5 |
| `0x4DBE67`/`6E` | `0x4F6B20`, `0x502BC0` | a provinceless faction leader |
| `0x4DBE8C` | `0x49DD00` | unread |
| `0x4DBEA3` | `0x4DCD70` | unread; reads a `military` define at `0x4DCE17` |
| `0x4DC138` | `0x685F00` | unread |
| `0x4DC1BA`-`0x4DC20B` | `0x8EACA0`, `0x510160`, `0x50D570` | unread; guarded on `+0x1D8`, the country's `CEU3AI` |

---

## 5. The NAP-break rule - `0x4EFCA0` / rva `0xEFCA0`

`__thiscall`-alike: `ecx` the `CCountry`, `ret 8`, and the other country's **id** in the
second stack slot. Returns a bool in `al`. Nine callers, all in the diplomatic-action region
(`0xA14C43`, `0xA14C94`, `0xA14CE1`, `0xA14D39`, `0xA16000`, `0xA16050`, `0xA16090`,
`0xA160DC`, `0xA2D8A0`).

    nap = this->+0xE28[otherId]->+0x28
    if (!nap) return false

    d = nap.start_date (+0x18)
    d = AddMonths(d, NAP_UNBREAKABLE_MONTHS)            diplomacy +0xE4
    if (d > today) return false

    ratio = nap->+0x24
    if (this->id == nap->+0x14) ratio = 1000000 / ratio      we are the 'second' party

    d = AddMonths(d, NAP_FORCE_BALANCE_RULE_MONTHS)     +0xE8
    if (d > today) return ratio >= NAP_BREAK_FORCE_BALANCE_1     +0xEC
    d = AddMonths(d, NAP_FORCE_BALANCE_RULE_MONTHS)
    if (d > today) return ratio >= NAP_BREAK_FORCE_BALANCE_2     +0xF0
    d = AddMonths(d, NAP_FORCE_BALANCE_RULE_MONTHS)
    if (d > today) return ratio >= NAP_BREAK_FORCE_BALANCE_3     +0xF4
    return true

So the rule is **three successive windows of `NAP_FORCE_BALANCE_RULE_MONTHS`**, starting when
the unbreakable period ends, each with its own force-balance floor; once all three have
elapsed the NAP is always breakable. `CDiplomacyStatus +0x28` is the NAP object, deriving
`CRelation` (`+0x10`/`+0x14` `second`, `+0x18` `start_date`) and adding `+0x24`, the force
balance stored as *first : second*. BlackICE's own comments on the three defines
("3-1 brigades along the border required to break NAP") say what that ratio counts.

`0x4B8C90(int* date @EAX, int months)` is the shared date-add, also used by the election
phase. Every define here is divided by 1000 before being passed to it, so all four are read
as whole months.

---

## 6. `CCountry +0x628` is the laws, not the ministers

`CLASSES.md` records `+0x628` as "an array of `CMinister*` the loader writes ... what it is
for has not been established". That is wrong, and three independent readings agree:

1. **`CChangeLawCommand::Execute` (`0x54EF60`)** does
   `countries[cmd->+0x40]->+0x628[cmd->+0x48->+0x50] = cmd->+0x44`, and `CChangeLawCommand`'s
   loader puts the key **`law`** at `+0x44` and `position` at `+0x48`. The value stored is the
   law.
2. **`CChangeMinisterCommand::Execute` (`0x54E2D0`)** does the same shape into **`+0x618`** at
   `cmd->+0x48->+0x4C`, with its own `+0x44` from the key `id`.
3. **The slot counts settle the element types.** In `CCountry::LoadKey` the `+0x628` loop calls
   slot **16** on each element (`0x4D1169`: `[vft+0x40]`) and `CLaw`'s vftable has exactly 17
   slots; the `+0x618` loop calls slot **8** (`0x4D103A`: `[vft+0x20]`) and `CMinister`'s has
   exactly 9. Each is the class's last slot, so neither can be the other's class.

So:

- **`CCountry +0x618`** - `CMinister*` per cabinet post, indexed by `CGovernmentPosition +0x4C`.
- **`CCountry +0x628`** - `CLaw*` per law group, indexed by `CLawGroup +0x50`.

Three tiny accessors sit together: `0x4F0510` (`+0x628[index]`, `ret 4`), `0x4F0530`
(`+0x628[group->+0x50]`, `ret 4`) and `0x4F0550` (the setter, with the country in `edx` and
the group in `eax`). Their two databases are the singletons at `0x1A878C8` (law, vector at
`+0x28`) and `0x1A87990` (minister, vector at `+0xC`).

---

## What is not established

- **`CDiplomacyStatus +0x38` is relation by position, not by proof.** It is what the Relation
  term averages and scales by `RELATION_WEIGHT`, which leaves little room for anything else,
  but no loader key and no second reader were checked. `+0x5C` is threat on two agreeing
  readings (the Threat term, and the max-threat cache at `0x4E21E0`); `+0x2C` is "an influence
  is running" from the upkeep and the count function; `+0x20` hostile, `+0x24` war and
  `+0x4C` access come from the existing record, not from here.
- **Which side of `+0xE28` a status belongs to.** The upkeep reads `other->+0xE28[us]` while
  the alignment terms read `us->+0xE28[other]`. Whether the array is symmetric (one object
  shared by the pair) or directional was not tested, and it changes what "we are paying"
  means.
- **The two globals in the formula.** `[0x1A87334]` floors the proximity distance term and
  `[0x1A8732C]` is added to the AlignTowards neutrality factor. Both are in uninitialised
  data, so their values cannot be read statically and no writer was found. Until they are
  known, the proximity and align-towards terms are correct in shape but not in magnitude.
- **`WAR_THREAT` (`alignment +0x28`) has no reader.** The only candidate is the discarded
  `GetDefines` call at `0x4C41EE`, inside the Threat term, whose result is overwritten two
  instructions later. That the define is unread is fact; that it *used* to feed the hostile
  branch there is inference.
- **`CIdeology` slot 17 and `CIdeologyGroup` slot 6.** Both are used as boolean gates (slot 17
  on the country's ruling ideology in the Ideology and Repulsion terms, slot 6 on the group in
  the aggregator and the nearest-group search). Neither body was read, so "is valid" is a
  guess about what they test.
- **`CCountry +0x95`.** Split-tests the surrender phase and gates three other phases. Not
  identified. `+0xCF8` is the owned-province count and is the other half of most of those
  gates.
- **`0x4FCB80`**, the surrender trigger's measurement, and **`0x4E8E80`**, what happens when it
  fires. Likewise `0x4FC100` (the election itself), `0x4F6B20` / `0x502BC0` (a provinceless
  faction leader) and `0x503F90` (cancelling an unaffordable influence).
- **Nineteen of the daily pass's helpers are unread**, as marked in the table. The convoy
  phase and the economy block were identified by the fields they write, not by reading them.
- **`0x4FA0B0`**, the second site that computes all seven alignment terms. If it is the
  tooltip, it is the cheapest confirmation of every formula above that exists.
- **Whether `CCountry +0x124` is saved.** If it is not, loading a game resets the alignment
  schedule; if it is, it does not. Not checked, and it matters for the mod.
- `0x1BEA40C`, which forces an election, and `0x170C2B8`, the "no election yet" sentinel date.
- `[0x1A878C8]`'s and `[0x1A87990]`'s class names. Their element types are settled (above);
  the managers' own classes were not looked up.
