# The faction layer: one gateway, no alliances, and a leader you cannot set

Read 2026-10-06, wave 14. **Addresses here are rvas** against an image base of `0x400000`; where a
virtual address appears it is written as one and said to be one.

The question this was opened for had been on the queue since wave 12: **can a faction member lack a
bilateral alliance?** That decides whether `ally = { ... }` is genuinely wider than `alliance_with`,
which is a real difference to a mod. The answer is yes, overwhelmingly, and it falls out of a
function that had no record at all.

---

## 1. `CFaction::AddCountry` - rva `0xF5F30`

The faction membership change. **Wave 13 established where it is not:** `CFactionAction::Apply`'s
only country write in `0x2157` bytes is the influence charge, verified two independent ways, so the
mutation is not in slot 7. It is here.

`void __thiscall CFaction::AddCountry(CFaction* this, CCountry* country, bool recordInHistory, bool joinOngoingWars)`,
`ret 0xC`, VA `0x4F5F30` to the `ret 0xC` at `0x4F6760`, `0x833` bytes.

**Both ends verified**, and the entry is unambiguous: 17 `int3` above it (after an unrelated `ret` at
`0x4F5F1E`), 13 `int3` below the final `ret`, then a fresh SEH prologue at `0x4F6770`.

**Trap 3 is live here and it is expensive.** `retsBefore(0x4F5F30, 0x4F6761)` returns **two more**
`ret 0xC`, at `0x4F6494` and `0x4F64C3`. Both are early exits of the *same* frame - each unlinks the
SEH record from `[esp+0x24C]` and does `mov esp, ebp; pop ebp`. The two `Hoi3CString` diagnostic
paths at `0x4F6497` and `0x4F6632`, and the shared epilogue at `0x4F674C`, all sit **past** the first
of them, reached by `je` from inside the body. **A reading that stopped at `0x4F6494` loses `0x2CC`
bytes, including both log messages** - which are the two strings that name the function.

### Which register is which

`mov esi, ecx` / `mov edi, [ebp+8]` / `mov [edi+0xD8], esi`. `edi` is unambiguously a `CCountry`: it
is used with `+0xCA4`/`+0xCA8` (tag and id), `+0xF34` (`isSubject`), `+0x48C` (`strategy`) and
`+0xFD8` (`Neighbours`). `esi` is unambiguously a `CFaction`: it is compared against
`country->faction`, handed to `CFaction::AddMember`, and its slot 7 is `IsValid` - `CFaction`'s body
being the folded `mov al,1; ret` at `0xA92590` and `CNullFaction`'s the folded `xor al,al; ret` at
`0x592360`.

**It is nevertheless compiled into `country.cpp`** - both log paths push the literal `'country.cpp'`
at `0x15C0DE8` - while every other `CFaction` member sits together at `0x5224B0`-`0x5237B7`. That is
what a `CFaction` method needing the complete `CCountry` type looks like: defined in the other
translation unit to break the include cycle. Worth knowing before concluding from an address's
neighbourhood which class a body belongs to. The log strings are `' failed to join faction '`
(`0x15C1384`) and `' failed to join faction 0 faction'` (`0x15C13AC`), both prefixed `'CCountry: '`
plus the country's name.

### It is the gateway

`CFaction::AddMember` has **exactly one caller**, at `0x4F5FC6` inside this function, and the only
other way a tag reaches `Members (+0x28)` is the push-front helper `0x523770`, whose two callers are
`AddMember` itself and the leader promotion of section 3, which only reorders members it has just
removed.

What is **not** settled: whether `CCountry::faction (+0xD8)` is also written somewhere that does not
touch the list. `fieldchain --field 0xD8 --writes` returns 673 sites, which is trap 12 and no
evidence either way. Stated rather than papered over.

### What the two flags select

| flag | gates |
| --- | --- |
| `recordInHistory` (`[ebp+0xC]`) | `operator new(0x18)`, constructed by `0x5F0600(country)`, given the previous faction by `0x5F07C0`, stamped `+8 = CCurrentGameState->tick (+0xBDC)`, handed to `country->history (+0xCCC)` slot 6 |
| `joinOngoingWars` (`[ebp+0x10]`) | the war sweep of section 1.2 |

`CFaction::LoadKey`'s `country` case (save token `0x24D`, the call at `0x5228B4`) passes
**`(country, 0, 0)`** - loading a save moves members without writing history or touching wars, which
is why the save's `faction={axis={country="GER" ...}}` block restores the member order verbatim.

**The two `CFactionAction::Apply` call sites are *not* a join/leave pair**, which is what the wave 14
plan assumed from their existence. `xor ebx, ebx` at `0xA30E92` is the only write to `ebx` in the
function's whole `0x2157` bytes - the only other mentions are a `lea ebx,[ebx]` alignment nop at
`0xA30EFA` and the epilogue's `pop ebx` - so both calls pass **`(country, 0, 1)`**, and both were
read off the bytes as `push 1; push ebx; push <country>`. The difference is *which* country:

- `0xA319B2` - `[esp+0x8C]->faction` as receiver, `[esp+0x18]` as the country. The joiner.
- `0xA31AF5` - the same faction, inside a loop over the whole country array (`CCurrentGameState
  +0xBBC`, bounded by slot 6) that adds every country whose `+0xF3C` equals the joiner's id.
  `+0xF3C` is the id half of `Overlord (+0xF38)`, so **a country's subjects follow it into a
  faction.** The sweep reads the pair together at `0xA31ACE`-`0xA31ADE`, which is a third independent
  witness that `+0xF38`/`+0xF3C` is one tag and its index.

Which of the action's two parties is the joiner is chosen by `value` (`CDiplomaticAction +0x24`) at
`0xA314E0` - invite versus request. That last identification is **likely**, not confirmed; everything
else in this section is read off instructions.

### 1.1 What it does, in order

1. Marks entry `id*0x14 + 0x10` of the vector at `[0x1A8C388]` - a per-country display dirty byte,
   skipped when the vector is empty.
2. If the country already has a different faction: `CFaction::RemoveMember(old, &country->tag)`.
3. If `this->IsValid()` is **false**: `country->faction = CFaction::null()` and return.
   **Leaving a faction is calling this with the null faction.**
4. If it is valid but already the country's faction: log and return. A null `this` logs the
   `'0 faction'` variant.
5. Otherwise `country->faction = this` and `CFaction::AddMember(this, &country->tag, 0)` - at the
   **tail**.
6. The optional history entry.
7. The optional war sweep.
8. If `in_game` (`CCurrentGameState +0xDA4`): `0x4E70A0(country)`,
   `CCountry::RebuildStaticModifiers`, `0x4FBC10(country)`, then `CAIStrategy::Rebuild` and
   `CAIStrategy::BuildTheatres` on `country->strategy (+0x48C)` **and on every member of
   `Neighbours (+0xFD8)`**.

### 1.2 The war sweep, and the two rules in it

`0x4F6183`-`0x4F6355` walks `CCurrentGameState +0xC00` as a `CListNode<CWar*>` chain (payload at
`+0`, `next` at `+8`) and, for each war with at least one attacker and one defender, using
`CountryTagVector_Contains` throughout:

- skip if the joining country is already an attacker or a defender;
- if it `isSubject (+0xF34)`, skip any war its `Overlord` is not itself in - **a puppet only joins
  wars its overlord is already fighting**;
- if the **faction leader** (the first member) is an attacker **and the war is not `is_limited`
  (`CWar +0x70`)**: `CWar::AddAttacker(war, 0, 0, ourTag)`, then
  `CCountry::ChangeRelation(defender, ourTag, -delta)` for every defender;
- else if the leader is a defender: `CWar::AddDefender` and the same relation hit for every attacker.

The delta is `GetDefines()->diplomacy (+0xBC)[1]`, negated. Entry 1 of that block is
`WARDEC_WAR_DIPLOMACY_HIT` on `common/defines.lua`'s key order, so **-100 relations with each new
enemy** - marked **likely**, because it is the only claim here resting on the file's key ordering
rather than on an instruction.

**Two consequences a mod author can act on.** Joining a faction at war puts you in **all** of the
leader's wars at once, not just the ones you could reach. And **`is_limited` is an escape hatch on
the aggressor side only** - a limited war does not pull a new member in as an attacker, but a limited
war the leader is *defending* still does.

---

## 2. `CFaction::AddMember` - rva `0x122650`

`__stdcall`, everything on the stack, `ret 0xC`, three exits at `0x522694`/`0x5226E2`/`0x5226F2`.
Walks `Members` comparing each node's `+4` (the id half) against `member->+4` and does nothing but
set the dirty byte if the tag is already there. Otherwise `atFront` picks the end: zero appends in
place, non-zero tail-calls `0x523770`.

The node is **0x14 bytes, payload at 0, `prev` at +8, `next` at +0xC** - `CListNode<CCountryTag>`,
the same shape `CCountry::CalculateIsAllied` already witnesses - and the head at `+0x28`..`+0x34` is
`project.json`'s `CList` exactly: `first`, `last`, `count`, `flag`.

**Its only caller is `CFaction::AddCountry`, and it passes `atFront = 0`.**

---

## 3. Faction leadership is positional, and a join can never change it

`CFaction::GetFactionLeader` (rva `0x1235E0`) is the whole of
`cmp [ecx+0x30], 0; mov eax, 0x170CF48 /* '---' */; je; mov eax, [ecx+0x28]; ret`. The leader **is
the first member**, there is no leader field, and a joiner always arrives last. So **a join cannot
promote.**

`0x523770`'s *other* caller can. Inside the unnamed function at rva `0x102BC0` - which sets
`country->government_in_exile (+0x95) = 1` and scales `Manpower (+0xBCC)` and `officers (+0xC4)` by
the float at `0x160A684`, i.e. a country losing its homeland - a block runs only when the faction is
valid, the country's own id equals the leader's (`0x502E5F`), and `NumberOfMembers > 1`. It walks the
member list skipping anyone already in exile and skipping itself, keeps the one with the greatest
**`max_ic` (`CCountry +0x60C`)**, and promotes it by `CFaction::RemoveMember` followed by push-front.
Recorded as the instruction entry `FactionLeaderPromotion`, rva `0x102F34`; the enclosing function is
in the frontier.

**The savegames corroborate it independently.** Across all 45 saves on this machine, `axis`/`allies`/
`comintern` lead with GER/ENG/SOV - **except** `Ireland1945_01_22_02`, whose `axis` reads
`JAP, GER, SLO, MAN, ...` with Germany displaced exactly one place. That is precisely what removing
JAP and pushing it to the front produces, and nothing else in the member order moved.

**For a mod author:** faction leadership is not a field you can set and not something diplomacy
moves. It changes in exactly one circumstance - the leader goes into exile - and the successor is the
surviving member with the highest max IC.

---

## 4. A faction member usually has no alliance, and `ally` is far wider than `alliance_with`

Three strands, and they agree.

**From the bytes.** Listing every memory write in `AddCountry`'s body with its base register, the
only non-frame destinations are `country->faction`, the display dirty byte, `[historyEntry+8]`, the
`CCurrentGameState` lazy-singleton boilerplate, and the two one-dword stack allocas carrying
`ChangeRelation`'s by-value delta. **No `CDiplomacyStatus` field is written and no relation object is
allocated.** `AddMember` and `RemoveMember` were read in full and have none either. Wave 13 already
established the same of `CFactionAction::Apply`.

**From the record.** `CCountry::RebuildNeighbours` (rva `0xE21E0`, already `confirmed`) fills
`Allies (+0xF88)` from **two** sources: the database loop, gated on `CDiplomacyStatus +0x14`
(`alliance`) being non-null, *and* a second pass at `0x4E356C`-`0x4E360B` that walks
`country->faction->members` and appends every member but itself. **The second source never looks at
`+0x14`.**

**From the savegames**, which is the cheapest oracle here and the decisive one. Counting the global
`faction={...}` block's members against the top-level `diplomacy={...}` block's `alliance` records -
note that a raw grep for `alliance=` is **inflated by `strategic_warfare={ alliance={ } }` on every
country**, 114 hits in the 1945 save, so the diplomacy section has to be bounded by brace depth and
read on its own:

| save | faction sizes | alliances in world | intra-faction pairs | of which allied |
| --- | --- | --- | --- | --- |
| `Ireland1936_01_01_00` | 1 / 5 / 3 | 12 | 13 | 3 |
| `Ireland1941_07_30_08` | 9 / 16 / 3 | 19 | 159 | 4 |
| `Ireland1942_05_11_11` | 13 / 29 / 3 | 17 | 487 | 7 |
| `Ireland1945_01_22_02` | 13 / 35 / 2 | 7 | **674** | **5** |

In the 1945 save the entire world holds **7** bilateral alliances; 5 sit inside a faction
(`ENG-OMN`, `GER-HUN`, `GER-ROM`, `JAP-MEN`, `MON-SOV`) and **2 are between countries in no faction
at all** (`CHI-CXB`, `SWE-FIN`). **The implication fails in both directions.** These figures were
produced twice, by two independently written parsers, agreeing on every intersection.

### What a mod author can act on

- `alliance_with = X` tests `CDiplomacyStatus +0x14` - a genuine bilateral alliance object. In a
  mature BlackICE game there are **single digits of those in the whole world**.
- `ally = { ... }` draws from `Allies (+0xF88)`, which is **alliances union faction members**. In the
  1945 save that is roughly a hundred times as many relationships.
- So **`ally` is strictly and enormously wider than `alliance_with`.** A condition written as
  `alliance_with` to mean "on our side" will be false for almost every faction partner - including
  Germany and Japan for each other. Anything written over `ally` to mean "we signed something" will
  fire for every faction member.
- `is_in_faction` or the faction tag is the right test for "same side"; `alliance_with` is the right
  test for "we have a treaty". **They are not substitutes.**

---

## 5. `CFaction` layout

One new field: **`+0x38 members_changed`, `bool`.** The constructor clears it as a *byte* at
`0x522514` - between the byte at `+0x34` and the dword `icon` at `+0x3C`, so `+0x39`..`+0x3B` is
padding - and it is set to 1 by every mutator of the member list and nothing else: `AddMember` at all
three exits (`0x52268C`, `0x5226DA`, `0x5226EA`), `RemoveMember` (`0x522744`), and the promotion
(`0x502F39`).

**Its consumer was not identified**, and the negative carries its positive control:
`fieldchain --holder 0xD8 --field 0x38` finds two readers and **both are dword loads**, so neither is
this byte, while the same holder chain finds 66 readers of `+0x30` and 40 of `+0x28`. Whatever reads
it reaches the faction by some path other than `CCountry::faction`.

Also settled in passing: **`sizeof(CFaction) == 0xD8`**, from `CFaction::null`'s `operator new(0xD8)`.

**And `CFaction::null` is inlined about thirty-five times.** `findValue(0x1A855A8)` returns 71
references in matched test/store pairs; the two decoded (`0x4195A2`, `0x4C37B9`) are byte for byte
the same lazy construction as `0x523620`. So **a `call 0x523620` scan massively undercounts** who
asks for the null faction - trap 8's shape in a new place. A country with no faction holds this
object, **not a null pointer**, which is why `CCountry::HasFaction` cannot be a null test.

---

## 6. What the record got wrong, and what is still open

Two corrections to claims that were in circulation when this was read:

- **The wave 14 plan's "`CFaction` ... including `+0x28 Members` and `+0x30 NumberOfMembers`" is
  wrong, and `+0x30` must not become a field.** `CFaction` has 10 field records and none at `+0x2C`
  or `+0x30`; `Members` at `+0x28` is typed `CList<CCountryTag>` and `CList` is laid out at size
  `0x10`, so `+0x2C` and `+0x30` **already resolve** as `Members.last` and `Members.count`.
  (`0x63D780`, the folded `mov eax,[ecx+0x30]; ret` that luabind registers as
  `CFaction::GetNumberOfMembers`, is probably what the claim was remembering.)
- **`CCountry +0xF90` "the allies count" is not a field record either.** It is the `count` word of
  the `CList` head at `+0xF88`, and it is unreadable today because **`CCountryList` has no layout at
  all** - no struct record, and not special-cased beside `CUnitList` in `buildFindings.py`'s `CList`
  pass. So `Allies (+0xF88)`, `Vassals (+0xF78)` and the rest decompile as untyped blobs. Giving
  `CCountryList` the `CList` layout is the right fix; the three hand-added
  `non_hostile_countries_first/_last/_count` records at `+0xF98`/`+0xF9C`/`+0xFA0` are the same
  workaround and would have to go at the same time. **No id-half or count field was declared here**,
  deliberately, to avoid colliding with that fix.

Still open, and each is one function read rather than a guess:

- **`0x102BC0`**, the capitulation/exile function holding the promotion. Only the `~0x400` bytes
  around the promotion were read; it has 7 callers and four `ret`s between `0x50315F` and `0x5033AD`,
  so bounding it is real work. Worth a brief of its own.
- **The 0x18-byte faction-change history entry.** Its layout is inferable from the call sites (`+8`
  date, `+0xC` country, `+0x10` and `+0x14` two faction pointers - `0x5F083D` uses one arm and
  `0x5F0855` the other) but the class was not identified, so nothing was recorded.
- **`0x4E70A0` and `0x4FBC10`**, skimmed only. `0x4FBC10` clears and rebuilds `CCountry::Rules
  (+0xDBC)` from the faction. ~~**These two are the one hole in the "no alliance is created"
  claim**~~ - **closed 2026-10-06**: both were read end to end in wave 15, neither writes or reaches a
  `CDiplomacyStatus`, and §4's headline is now **confirmed** rather than likely. See §11.
- ~~**`CDeclareWarAction::Apply`'s call at `0xA121CE`** ... it looks like declaring war can eject a
  country from a faction.~~ **Refuted 2026-10-06, and it is the opposite: a *join*.** See §7. The
  reading went wrong in a way worth recording, because the error was not in the bytes read but in
  which object they were read against: **three different objects' factions are asked slot 7 in that
  one loop** - the declarer's, each enemy's, and the recipient's - and the `IsValid` that answers
  false is the **recipient's**, while the receiver handed to `AddCountry` is the **enemy faction
  leader's**, which the loop has already proved *valid*. So the call takes §1.1's step 5 and can never
  take step 3. The `[esp+0x24]` tag pair that "did not resolve cleanly" is not on the action at all;
  it is an enemy id out of `CCountry::enemies (+0x1008)`.
- **The AI.** `AddCountry` calls `CAIStrategy::Rebuild` and `CAIStrategy::BuildTheatres` on the joiner
  *and on every neighbour*, and `CCountry +0x48C` is the embedded `CAIStrategy`. Noted and left, per
  the standing steer.

## 7. Declaring war is a faction *join*, and it is the enemy's faction the victim joins

Read 2026-10-06, wave 15. §6 left this as "the most interesting single lead", read as an **ejection**.
**It is the opposite of an ejection.** Addresses in this section are **virtual** where written
`0xA1...` and said to be; the rvas are in the record.

The whole preamble of `CDeclareWarAction::Apply` (rva `0x612030`) is one guarded loop,
`0xA12030`-`0xA121D3`, with the `CFaction::AddCountry` call at `0xA121CE` on exactly one path
through it. `cfg.py` gives every edge, and the call's only predecessor is the fall-through of a
`jne`:

    if (!countries[this->actor.id]->faction->IsValid())   goto done;   // 0xA12089
    for (E in countries[this->actor.id]->enemies (+0x1008)) {          // 0xA120A7
        if (!countries[E.id]->faction->IsValid())         continue;    // 0xA120EF
        f = countries[E.id]->faction;
        if (f == 0 || f->Members.count (+0x30) <= 0)      continue;
        if (f->Members.first->id != countries[E.id]->id)  continue;    // 0xA12129
        rf = countries[this->recipient.id]->faction;                   // 0xA12140
        if (rf->IsValid() && rf != f)                     continue;    // 0xA12151/0xA12157
        war = countries[this->actor.id]->diplomacy[E.id]->war (+0x20);  // 0xA12199, kept
        if (rf->IsValid())                                goto done;   // 0xA1219F
        CFaction::AddCountry(f, countries[this->recipient.id], 0, 0);   // 0xA121CE
        goto done;
    }

Four things fall out, and each was an open question the day before.

**Whose faction is tested.** Three different objects' factions are asked slot 7 in this one loop,
which is why wave 14 could not place it: the outer gate is on the **declarer's**, the per-enemy test
on the **enemy's**, and the two at `0xA12151` and `0xA1219F` on the **recipient's** - the one whose
`false` lets the call happen. `esi` is loaded from `countries[this->+0x14]->+0xD8` at `0xA12140` and
is not written again before the call, so this is read rather than inferred.

**Whose membership changes, and in which direction.** `AddCountry`'s receiver at `0xA121C1` is
`countries[[esp+0x24]]->+0xD8` - **the enemy faction leader's** faction, which the loop has already
proved *valid*. So the call takes §1.1's **step 5** (`country->faction = this; AddMember`) and can
never take step 3. `[esp+0x24]` holds the enemies-node id stored at `0xA120C5` and nowhere else; the
action's own `+0x10`/`+0x14` is the recipient. **That is the arithmetic of the two tag pairs wave 14
could not resolve: one of them is not on the action at all.**

**It must be a faction *leader*.** `GetFactionLeader` is inlined at `0xA12112`-`0xA12129`, count test
and `'---'` arm included; the `'---'` arm at `0xA12119` is unreachable, because the `jle` above has
already taken the zero case. **Being at war with an ordinary faction member does nothing here.**

**The loop takes the first match and stops.** There is no back-edge from `0xA12167` onward; both
exits from that block land on `0xA121D3`.

### 7.1 Why no new war is declared, which is the other half of the rule

The frame slot at `[esp+0x2C]` is zeroed at `0xA12081` and tested at `0xA124C7`, and that test is the
fork:

- **zero** - no faction-leading enemy was found: `operator new(0xAC)`, constructed by `0xA4D6D0`,
  linked into the global war list at `CCurrentGameState +0xC00`, then `CWar::AddAttacker(war, 1, 0,
  actor)` at `0xA125ED` and `CWar::AddDefender(war, 1, 0, recipient)` at `0xA12601`. **A brand-new
  war.**
- **non-zero** - `0xA12611` instead: search the existing war's `attackers (+0x2C..+0x30)` in 8-byte
  steps for the **actor's** id; found -> `CWar::AddDefender` at `0xA12654`, not found ->
  `CWar::AddAttacker` at `0xA12641`. Either way **the victim lands on the side opposite the
  declarer**, and no new war object exists.

The war is stored at `0xA12199` *before* the second `IsValid`, so the "recipient was already in the
enemy faction" path keeps it too - which is what makes the war reuse independent of the faction
change.

### 7.2 The savegames refute the ejection reading outright

Across all **45** saves, parsed by brace depth: **183** `active_war` blocks with at least one
attacker and one defender, and **not one has a faction appearing on both sides.** The ejection
reading predicts the opposite - victims sitting outside every faction while at war - and it does not
happen. Only ten tags ever appear factionless opposite a factioned enemy, 103 times in all: `YUG` 29,
`LUX` 14, `CYN` 13, `CZE` 13, `CGX` 11, `CXB` 11, `CHC` 6, `CHI` 4, `USA` 1, `PHI` 1 - the Chinese
warlord cluster, whose wars come out of `history/` rather than from a declaration, plus three
countries that have been overrun.

**And the `USA`/`PHI` one is a positive control, not an exception.** In `Ireland1941_10_27_10`
Japan's only war is against the Chinese, whose defender list includes `CSX` - an `allies` **member
but not its leader**. Six days later, in `Ireland1941_11_02_07`, Japan declares war on the United
States. The rule predicts the loop finds nothing, so: a **separate** war and **no** faction change.
The save has exactly that - a new `2nd War of Japanese Aggression` with `JAP, MAN, MEN` against
`USA, PHI`, both in no faction - while on the German side the single `War of German Aggression`
accumulates 10 attackers against 36 defenders, every one `allies`, because Germany *is* at war with
ENG. **Two distinct predictions, both confirmed, in consecutive saves**, and reproduced by a second
parser written independently.

### 7.3 For a mod author

**Declaring war on a country that is in no faction, while you are in a faction and already at war
with the leader of another, puts that country into the enemy's faction and into the enemy's war.**

- it fires only when **you** are in a faction - a factionless aggressor drags nobody anywhere, which
  is why a neutral USA can fight the Axis for years without being in the Allies;
- it fires only when one of **your** enemies **leads** its faction. A rank-and-file member is not
  enough;
- it fires only on a **factionless** victim. A victim already in a faction is untouched;
- `recordInHistory` and `joinOngoingWars` are both **0** here, so the victim does *not* get §1.2's
  war sweep. It does not need it: the caller adds it to the one war that matters, by hand, on the
  opposite side;
- the war it joins is **the existing one**, so there is no new `active_war` block to test for and
  `is_limited` is inherited rather than decided by this declaration.

**The trap for a player** is the second clause: declaring on a minor while at war with a faction
leader hands that minor to your enemy, complete with its army and its IC. **The trap for a modder**
is the first: an event that makes a country declare war behaves completely differently depending on
whether that country is in a faction at the time.

## 8. Leaving a faction does not go through `CFaction::AddCountry`

§1 called `AddCountry` "the gateway" and the record said "every country that joins **or leaves** a
faction goes through here". **The joining half is still decidable and still true** -
`CFaction::AddMember` has exactly **one** caller, inside `AddCountry`, and that is the positive
control for the method used here. The leaving half is not: `CFaction::RemoveMember` has **seven**
callers and only two were accounted for (`AddCountry`'s own step 2 at `0x4F5F8C`, and the leader
promotion at `0x502F07`). Both claims are corrected in the record.

**`CCountry::LeaveFaction`, rva `0xF6B20`**, is the one that matters. `0x4F6B20` to the single
`ret 4` at `0x4F6C80`, `0x163` bytes, 10 `int3` above and 13 below, **no interior `ret`** - and it
sits immediately after `AddCountry`, which is where a `LeaveFaction` belongs in `country.cpp`. `this`
is a `CCountry` (it reads `+0xD8` and takes the address of `+0xCA4`) and the one argument is a bool:

    if (this->faction && this->faction->IsValid()) {
        CFaction::RemoveMember(this->faction, &this->tag);
        this->faction = CFaction::null();
        if (recordInHistory) { e = new CFactionLeave(this); ... }
    }

Its four callers are `0x4A37ED`, `0x4DBE67`, `CFactionLeave`'s own slot 7 at `0x5F0AA1`, and
`0x9A236E` in the event-effect module. **A fifth site open-codes the whole thing instead**: inside
the unnamed `0xD94A0` at `0x4D9657`-`0x4D9696` the same `RemoveMember` -> `faction = null()` ->
`0x4DDD80` -> `CCountry::RebuildRules` -> display dirty byte sequence appears inline, which is
`AddCountry` steps 2, 3 and part of 8 written out by hand.

**So `AddCountry`'s step 3 is a defensive arm, not the leave mechanism.** Of its 14 call sites the
only one that can reach it on purpose is `CFactionJoin::Apply`'s **reverse** arm at `0x5F0855`, which
passes `+0x14` unguarded and so may pass the null faction.

## 9. The faction-change history entry is `CFactionJoin` / `CFactionLeave`

§6's open item. The `0x18`-byte object is two classes, both derived from `CCountryHistoryEntry` at
offset 0, both 8 slots, both introducing slots 2, 6 and 7:

| | vftable | constructor | written by |
| --- | --- | --- | --- |
| `CFactionJoin` | `0x15C997C` | rva `0x1F0600` | `CFaction::AddCountry`, `recordInHistory` set |
| `CFactionLeave` | `0x15C99A0` | rva `0x1F08B0` | `CCountry::LeaveFaction`, `recordInHistory` set |

Each constructor calls the shared base constructor `0x5EEA40(country)`, writes its own vftable and
returns `this`; `+0xC` (the country) and `+0x8` (the tick) belong to the base. Slot 7 on each is a
direction-flagged replay, `void (bool forward)`, read end to end:

    CFactionJoin::Apply(forward)     forward: +0x14 = country->faction
                                              if (+0x10 && +0x10->IsValid())
                                                  AddCountry(+0x10, country, 0, 0)
                                     reverse: AddCountry(+0x14, country, 0, 0)        // unguarded

    CFactionLeave::Apply(forward)    forward: +0x14 = country->faction
                                              CCountry::LeaveFaction(country, 0)
                                     reverse: if (+0x14 && +0x14->IsValid())
                                                  AddCountry(+0x14, country, 0, 0)

So **`+0x10` is the faction the entry records and `+0x14` is the undo slot** - which settles the
roles of the two pointers §6 could only count. Both replays pass `recordInHistory = 0`, so replaying
history writes no history, the same discipline `CFaction::LoadKey`'s `country` case uses.

**One correction to §1.1.** It says the entry is "given the previous faction by `0x5F07C0`". It is
not: at `0x4F5FC0` `AddCountry` writes `country->faction = this`, and only afterwards, at `0x4F5FFF`,
loads `country->+0xD8` for `0x5F07C0`. **A `CFactionJoin` therefore records the *new* faction in
`+0x10`**, and a `CFactionLeave` - whose clear at `0x4F6B76` comes before its own `0x4F6BA7` -
records the **null** faction there and keeps the real one in `+0x14`. `0x5F07C0` has five callers
across different entry kinds, so it is left class-free and unrecorded (trap 4).

## 10. All six unidentified `AddCountry` callers

Wave 14 left six. **All six are joins**, and four are virtuals `vtable.py --holding` names for free:

| rva | what it is | the call |
| --- | --- | --- |
| `0x5A1C60` | `CJoinFactionEffect::Execute`, slot 11 | `AddCountry(this->faction (+0x20), scope->country, 0, **1**)` after checking the country is not already a member. **Read end to end** |
| `0x5AEBF0` | `CReleaseVassalEffect::Execute`, slot 11 | `AddCountry(releaser->faction, released, 0, **1**)` under an `IsValid` |
| `0x14BD00` | `CCreateVassalCommand::Execute`, slot 6 | `AddCountry(countries[+0x48]->faction, countries[+0x40], 0, **1**)` |
| `0x14C980` | `CLiberateCountryCommand::Execute`, slot 6 | `AddCountry(liberator->faction, liberated, 0, **1**)` |
| `0x19360` | the custom-game-setting applier | `AddCountry(setting->+0x58, country, 0, **0**)` for the country **and every one of its vassals**, copying `alignment_x (+0xE4)`/`alignment_y (+0xE8)` off the faction leader first. **Read end to end** |
| `0xD94A0` | unnamed, `__cdecl(CCountryTag, CCountryTag)`; 3 callers including `CCreateVassalEffect::Execute` | pulls the **second** country out of its own faction by hand (§8) then `AddCountry(first->faction, second, 0, **1**)`. **Deliberately not named** |

**The pattern worth stating: every scripted or commanded join passes `joinOngoingWars = 1`** and so
inherits §1.2's whole war sweep, while the two engine-internal joins - the savegame loader and the
lobby setting - pass `(0, 0)`. `CDeclareWarAction::Apply` is the only site that passes `(0, 0)`
*during* a game, and that is because it adds the country to the one war itself.

`CReleaseVassalEffect::Execute` also tests a tag against the literal `REB` at
`0x9AEC22`-`0x9AEC2B`, i.e. it refuses to operate on the rebel country.

## 11. The hole in "a faction join creates no alliance" is closed

§4's result rested on `0x4E70A0` and `0x4FBC10` having been skimmed only. Both are now read end to
end.

**`0xFBC10`, `CCountry::RebuildRules`.** `0x4FBC10` to the `ret 4` at `0x4FBC76`, `0x66` bytes, then
`CCountry::GetRules` (rva `0xFBC80`, `lea eax,[ecx+0xdbc]; ret`), which is what identifies the
object. It clears four bytes inside `Rules (+0xDBC)` at `+0x18`, `+0x20`, `+0x28`, `+0x30`, frees the
list chained through `Rules +0x8`, and then - only if `country->faction->IsValid()` - hands
`&faction->rule (CFaction +0x40)` to `0x45E340`. **It does not "rebuild Rules from the faction"
itself**, as §6 said; the repopulation is inside `0x45E340`.

**`0xE70A0`, `CCountry::OnDiplomacyChanged`.** `0x4E70A0` to the `ret 4` at `0x4E718D`, `0xEE` bytes.
**It abuts the function above it with zero padding** - the bytes before the entry are
`mov fs:[0],ecx; pop ebx; mov esp,ebp; pop ebp; ret` - so it is an entry only because twenty call
sites say so; one for trap 2's list. It does `0x430050(state + 0xB5C, country)`,
`0x5D6230(&country->units (+0xBAC))`, `CConvoy::ClearPath` on every node of `convoys (+0xA0)`,
`theatres_dirty (+0x580) = 1`, and, when `at_war (+0xACC)` is clear, `0x4D57D0(country)`. All twenty
callers are diplomacy state changes, which is where the name comes from - and clearing every convoy's
path is what a change in who you may pass through implies.

**Neither writes a `CDiplomacyStatus` field, and neither reaches one.** The only way from a `CCountry`
to a `CDiplomacyStatus` is the array at `+0xE28`, and a scan of the decoded body for that
displacement returns nothing for either function **or for any of the five functions they call** -
`0x430050`, `0x5D6230`, `CConvoy::ClearPath`, `0x4D57D0`, `0x45E340`. **The positive control:** the
same scan over `CDeclareWarAction::Apply` finds `+0xE28` at `0xA12184` and `0xA121F3`, and over
`CCreateVassalCommand::Execute` at `0x54C36F`. The exposure left is depth 2, and no argument list at
depth 1 carries a second country, which a relation write needs both ends of.

**So §4's headline - a faction join creates no bilateral alliance, and `ally` is union, not treaty -
may be read as `confirmed` rather than `likely`**, with that scope stated.

## 12. `0x102BC0` is bounded, and it is a new trap 2 pair

The capitulation/exile function holding the leader promotion. **`0x502BC0` to the `ret 8` at
`0x5033AD`, `0x7F0` bytes.** Two stack arguments and nothing in ECX: `[ebp+8]` and a bool at
`[ebp+0xC]` tested against 1 at `0x502BE6`. Ten `int3` above the entry. The four `ret 8` at
`0x50315F`, `0x503376`, `0x503393` and `0x5033AD` are arms of one frame.

**The lower boundary has no padding at all**, and what settles it is wave 12's rule rather than any
int3 count: the byte after the `ret 8` opens `mov ecx, [0x1A87818]`, a different function, which ends
in a **bare** `ret` at `0x503650` where every exit of this one cleans eight bytes, and which has a
caller of its own at `0x68F05F`. **An int3 scan runs `0x2A3` bytes past the real end; a scan stopping
at the first `ret` stops `0x24E` bytes short of it.** The seven callers check out: `0x47ADAF`,
`0x4DBE6E`, `0x50C228`, `0x54D8FE`, `0x5F1EDD`, `0x5F1EF9`, `0x9BB1AB`. The body outside the
promotion block is still unread and the function is still unnamed.

## Frontier

`0x102BC0`, `0x1F0600`, `0x1F07C0`, `0x1F07E0`, `0x1F0A70` (the history entry), `0xE70A0`,
`0xFBC10`, `0x122590` (`CFaction` slot 6, the name getter), `0x28B4C0` (`RemoveMember`'s tail call),
and the six unidentified callers of `AddCountry`: `0x19360`, `0xD94A0`, `0x14BD00`, `0x14C980`,
`0x5A1C60`, `0x5AEBF0`.
