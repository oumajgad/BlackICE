# How an event option's effect text is built

Worked out for the extra variables on `kill_leader`. Read statically out of
`hoi3_tfh.exe`; what was checked in a running game and what was not is marked on each
claim.

Addresses are module relative, as everywhere in BiceLib. The disassembly scripts in
`scratchpad` print them against an image base of `0x400000`; take that off.

## The short version

An option's tooltip asks each effect for a sentence. `kill_leader` builds its own at
**`0x5ADD30`**, which is the only function in the executable that names the
localisation string `KILL_LEADER_EFFECT` (**read**: the string sits at `0x11F3C50` and
one instruction points at it, `0x5ADDD5`).

```
0x5ADD30  the kill_leader effect's text
  -> 0x5ADBF0                resolve the effect's value into a leader
  -> CCountryTag::GetCountry, then walk country + 0xE00, the active leaders
  -> 0x682490                GetText("KILL_LEADER_EFFECT") - a text object, not text
  -> 0x65B150 / 0x65B0D0     build "§Y" + the leader's name + "§W"
  -> 0x682F40                put that in place of $NAME$
```

The effect holds its value at `+0x20` as a thousandth, so the leader id in the event
file is read as `value / 1000` (**read**, `0x5ADBF0`). The list at `country + 0xE00` is
the country's active leaders, walked as `{data, ?, next}` nodes, and the match is on the
leader pointer.

**The leader is in esi** from the moment the walk finds him until `0x5ADE6E`, where the
register is reused. `0x5ADE4F` - `lea eax, [esi+0x4c]` - is the leader's name, which
agrees with `CLeader::Offsets::name` already being `0x4C`.

## The machinery, and what it hands back

| | Is |
| --- | --- |
| `0x682490` | **`TextObject* GetText(TextObject* out, const std::string* key)`** - the localisation lookup. Both arguments pushed, callee cleans - `ret 8` (**read**). |
| `0x682E40` | **`Render(this, out, colours)`** - a text object to characters. `ret 0x10` (**read**). |
| `0x687020` | Destroys a text object's replacements, the vector's three pointers in **edi** (**read**). |
| `0x682F40` | **`text.Replace(key, value)`** - the whole variable mechanism. `ret 4` (**read**). |
| `0xA160` | `std::string::assign(const char*, size_t)`, thiscall, `ret 8` (**read**). |

### The lookup does not answer with text

**This cost a wrong first version**, so it is worth saying plainly: `0x682490` hands back
a sixteen byte **text object**, not a `std::string`.

```
TextObject {           // 16 bytes
    const Entry* entry;                  // what the key found, or the one it just made
    Replacement *begin, *end, *capacity; // a vector: the $VARIABLE$ substitutions, 0x20 each
}
```

Read as a string it is four bytes of pointer and then whatever the stack held, which is
exactly what it looks like on screen - the first version of this feature put that in the
tooltip. A key that is **not** found is not an error either: the lookup creates an empty
entry for it (`0xA84D30`) so the renderer can say `NO_TEXT_FOR_KEY <key>`, and writes
`{that entry, 0, 0, 0}` without touching the caller's length or capacity at all.

Getting characters out takes the second call. `0x682E40` is `thiscall` on the object and
takes **sixteen bytes of colour settings by value** - `settings + 0x6C`, copied verbatim
- and hands the built string back in **esi**, the same register trick as the key in
`Replace`. Then the object is let go in two steps: `0x687020` destroys the replacements
with the vector in edi, and the caller frees the block they sat in.

The entries are polymorphic - the renderer calls slot 3 of the entry's own table - so
reading an entry's text as a field is not a shortcut that works.

`Localisation::text()` in BiceLib is that whole sequence, and province names come through
it under `PROV<id>` (the game builds the same key with the format string at `0x11BE118`).

### The replacement takes its key in esi

`0x682F40` takes the text in ecx and the value on the stack, and **reads the key out of
esi** - the compiler left it in a register variable and the callee uses it from there.
It is visible twice: at `0xA82F7A` (`mov edx, esi` right before the call that builds the
object) and on the other path at `0xA82F90`, where esi is pushed outright.

Without that, the `"NAME"` string the caller builds at `[ebp-0x3c]` is never read by
anything, which is what gave it away.

The object it builds is `0x40` bytes: a vftable, the text it belongs to at `+4`, then
the key as a `std::string` at `+8` and the value as another at `+0x24`, both **copied**
(`0x1BD0`, `assign(str, 0, npos)`). So a value handed to it need not outlive the call -
which is what makes it safe to pass a string BiceLib owns.

## What BiceLib does with it

Three more variables on that one effect, in `Hooks/EffectText/KillLeaderText.cpp`:

| | |
| --- | --- |
| `$UNIT$` | the unit the leader commands, empty in the officer pool |
| `$LOCATION$` | the province that unit is in, from its `PROV<id>` localisation |
| `$WHERE$` | ` (§Yunit§W, §Yprovince§W)` ready made, and empty rather than ` ()` |

`$WHERE$` is the one a sentence should use, because the other two leave an empty bracket
behind on a leader with no command. `localisation/misc.csv` uses it:
`Leader §Y$NAME$§W$WHERE$ will be removed.`

Two stubs, both standing in for a five byte `call` and both reproducing it, so a jump
fits exactly and there is nothing to pad:

**`0x5ADE62`**, the call that formats the leader's name, only to catch esi - the last
instruction that still holds the leader.

**`0x5ADE8A`**, the game's own `$NAME$` replacement. Ours go in first, which changes
nothing since each is a different variable, and the stack is left exactly as the game's
own call found it.

Both sites are checked by **reading the call and resolving its target**, rather than by
comparing five fixed bytes: that survives the image moving and refuses anything else.

Neither is written until Lua asks:
`BiceLib.EffectTexts.activateKillLeaderVariables()`, in `script/bicelib_lua.lua`.

### Two things that had to be got right

**The text handed back has to stay Windows-1252.** `HDS::readString` converts to UTF-8
for ImGui and Lua; anything going the other way must not, or every umlaut in a unit name
comes back as a fallback glyph. `Game::rawChars` is the raw reader.

**A string the game is given has to be one the game could have made.** Up to fifteen
characters they live in the object, which is what `HDS::Hoi3CString` already describes
and what every key this builds fits inside. Past that the game's own `assign` allocates
and the game's own `free` gives it back, because the allocator in the DLL is not the
allocator in the executable. `Game::String` is that, owning, and is the reusable half of
this work.

A localisation that asks for a variable nothing fills shows the `$WHERE$` as it stands,
so a failed install is visible in the tooltip rather than silent.

## load_oob, which had nothing to fill in

`CLoadOOBEffect::GetText` is **`0x5BBE40`** - slot 9 of `0x11F4490`, the same slot the
kill_leader one introduces, and the class derives from `CStringEffect`, which keeps its
string at **`+0x20`**. For this effect that string is the file path.

What it does with it is the surprise: it hands **the path itself** to `GetText` as a
localisation key, renders whatever comes back and shows that. No key, no variables, and
nothing worth substituting into - so BiceLib writes the whole string instead, over the
one already built.

```
0x5BBE40  CLoadOOBEffect::GetText
  -> 0x682490   GetText(this + 0x20)      the path, used as a key
  -> 0x682E40   RenderText                into the out string at [ebp+8]
  -> 0x687020   ReleaseTextReplacements   the last call before it returns
```

`CLoadOOBEffect::Execute` is `0x5BBD00`. It writes the path onto the country -
**`CCountry + 0x58`**, through the one line setter at `0x1EC9E0` - and then calls
**`0xFFED0`** on that country, which is what does the work. The country is the scope's:
the id at **scope + 0x14**, the id half of the `CCountryTag` the kill_leader builder
reads at scope + 0x10.

### The file is read when the effect fires, not before

Worth establishing, because it decides how a tooltip can be built at all. `0xFFED0`
builds `<base>/units/<path>` - the base chosen by `[0x1685558 + 0x50]`, which has three
values - and then calls, in order (**read**, from its own call list):

| | |
| --- | --- |
| `0x66B3A0` | `FileExists`, the same one the `common/` loader uses to let a mod's copy win |
| `0x669990` | `Tokenizer::Tokenizer` |
| `0x67A460` | `CParseContext::CParseContext` |

That is the same pair of parts `CLASSES.md` records for every `.txt` the game reads, so
the effect opens and parses the file at the moment it fires. Startup only **lists** the
folder: `history/units` is handed to `0xAB3E00` alongside `history/countries`,
`history/provinces` and the rest, and that is a directory walk - it is the function that
knows to skip `.svn`.

So there is nothing in memory to read a tooltip out of, and `GameState/OobFile.cpp`
reads the same file the effect will, counting the blocks that carry a `location` of
their own.

Two stubs again, five bytes each:

**`0x5BBE40`**, the function's own first three instructions - `push ebp; mov ebp, esp;
push -1` - taken together because they come to exactly five bytes. All the stub wants is
ecx, the effect, which three instructions later has become a pointer into it. Those
three are reproduced exactly, which is safe because a stub reached by a jump sees the
stack the function's own entry saw.

**`0x5BBEB1`**, the call to `ReleaseTextReplacements`. By there the string the effect
will show is built and sits at `[ebp+8]`, with the scope at `[ebp+0xC]` - **ebp is still
the builder's frame**, which is what makes both reachable from a stub that holds nothing
of its own.

The entry is checked as five fixed bytes, since a prologue is not a call to resolve.

### The rank warning is a choice, not a finding

The tooltip marks a leader whose rank is below the level he is being given - division 1,
corps 2, and everything above them 3. **The engine has no such rule**: its only rank
defines are `AIR_RANK_1..4` and `NAVAL_RANK_1..4`, which are how many units a rank may
command, not what it may command.

Nor do the mod's own files imply one. Every leader assignment in `history/units` against
that leader's starting rank in `history/leaders`:

| block | rank 1 | rank 2 | rank 3 | rank 4 |
| --- | --- | --- | --- | --- |
| division | 2302 | 509 | 95 | 56 |
| corps | 613 | 154 | 51 | 26 |
| army | 90 | 51 | 55 | 2 |
| armygroup | 22 | 13 | 38 | 34 |
| theatre | 9 | 8 | 6 | 16 |

So the rule is David's, chosen with those numbers in front of him, and it is meant to
fire on the 613. It lives in one table, `rankFor` in `Hooks/EffectText/LoadOobText.cpp`.

### What this does not cover

Two effects. Every other one builds its sentence in its own function, and whichever of
the two shapes fits - fill in a variable, or write the line - would work on any of them,
because the machinery above is shared.
