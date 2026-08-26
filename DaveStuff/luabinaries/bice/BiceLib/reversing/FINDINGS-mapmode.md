# The VP map mode, and where to take it over

All addresses are module relative (what the debugger shows as `hoi3_tfh.exe+X`, and what
BiceLib adds `Mem::moduleBase` to). Only valid for this build.

## Where the colours are decided

`0x4665A0` is the function that colours provinces for the VP map mode. It was found by
watching a province's victory point field: exactly one instruction in the whole game
reads it, `0x4666B6`, and it sits in this loop.

The loop, per province:

```
esi = province                       ; [[arg+0x2c][ebx*4] + 0xC]
xmm1 = intel level >= 2 ? 1.0 : 0.5  ; [province+0x370][country], counted at +0x374
if ([province+0xD4 terrain] +0x13D) == 0: xmm1 = 0     ; water gets nothing
CColor at [esp+0x2C] = { r=g=b = xmm1 * 0.9, a = 1 }   ; the grey base
if ([province+0x34] victory points) > 0:
    brightness = clamp((points / 15) * 0.3 + 0.7, 1.0)
    ... blend with the colour of the controller ([province+0x334] tag, +0x338 id)
lea ecx, [esp+0x2C]
call 0x6628B0                        ; CColor -> packed 0xAARRGGBB in eax
mov [entry], eax                     ; and [entry+4]
```

## Two things that matter for reusing it

**The shading has two steps, not many.** `points / 15` is an integer divide (verified by
emulating the magic-number sequence), and the result is clamped at 1.0, so
`(points/15) * 0.3 + 0.7` gives **0.7 for 1-14 points and 1.0 for 15 or more**. Nothing
in the mod has more than 30. Feeding a building level 1-10 into the victory point field
would leave every province the same shade.

**It is not a green ramp.** The province is drawn in its *controller's* colour at one of
those two brightnesses. Hooking only the value read would give owner-coloured provinces,
not the green ramp that was wanted.

## The place to take it over

`0x46697D` - the `call 0x6628B0` that turns the finished `CColor` into the packed dword.
Five bytes, so it can be replaced with a call to our own function, which can hand back
whatever colour it likes. Everything else stays the game's: the loop, the storage, the
rendering, the map mode button.

Getting the province inside that hook: **not from esi**, which is clobbered at
`0x46682B` (`mov esi, [esi+0x338]`) on the path where a province has victory points.
Recover it the way the loop does two instructions later - `[ebp+8]` -> `+0x2C` ->
`[ebx*4]` -> `+0xC`. `ebx` is the loop counter and is live at the call.

`0x6628B0` is `__thiscall`, takes the `CColor` in ecx, returns the packed colour in eax,
and is worth calling from the hook for the provinces we do not want to recolour.

## Province fields used here

| Offset | Holds | How it is known |
| --- | --- | --- |
| +0x34 | victory points | 825 of 825 provinces match the `points` lines in `history/provinces`, and the 2,846 without one all read 0 |
| +0xD4 | `CTerrain` | already in `GameClasses/CMapProvince.hpp` |
| +0x310 | building array | 60 `CProvinceBuilding*`, `nobuilding` first - see below. +0x1C on an entry points back at the province |
| +0x334 / +0x338 | controller tag and id | already named |
| +0x370 / +0x374 | per country intel, and its length | used for the fog shading above |

## Building levels

Settled, and no Lua is needed - it is four pointer reads per province.

```
province +0x310         array of CProvinceBuilding*, 60 entries
entry    +0x18          the CBuilding definition
         +0x1C          its key, "infra"
         +0x38          what the game shows, "Infrastructure"
entry    +0x20 / +0x24  level max and level current, both x1000
```

**Index 0 is `nobuilding`**, so every real building sits one index later than its
position in `common/buildings.txt` - infrastructure is 21, not 20. That off by one is
what made an earlier attempt here look like the level field was wrong: it was reading
the wrong building. Read the name off the definition instead of counting lines in the
file, and the question does not arise.

Checked live: infrastructure came back non zero for 1,500 of 1,500 provinces, between 1
and 10. `history/provinces` is useless as ground truth for this in a long running game,
because bombing damages infrastructure - which is what sent the first attempt wrong.

The offsets came from `DaveStuff/mem/classes/CProvinceBuilding.py`, which had them all
along; the vftables there (`0x11C0A50` at +0, `0x11C0A78` at +8) match what the objects
actually carry. They are now in `GameClasses/CProvinceBuilding.hpp`.

## Intel, and what it gates

`CMapProvince +0x370` is a pointer to one byte per country and `+0x374` is how many
there are - the country count, 108 in BlackICE. Index it by country index, the same one
`controller_id` holds.

Measured over every province, for the player: **0** for somewhere never seen (13,655),
**3** for partial intel (82), **9** for the country's own provinces (262, all of them).

Two thresholds, both the game's:

- **2** - the VP map mode's colouring loop paints a province at full brightness at two
  or more and dims it below that.
- **6** - the province window starts showing what is built there. Found by testing, not
  read out of the code, so it is worth rechecking if building visibility ever looks
  wrong. `CustomMapMode` uses it to decide whether to show a real level.

## Every map mode, by its own number

The number on the button is not the number the game uses, and the two do not even run in
the same order. Read off a running game with `reversing/mapmode.py --watch`, by clicking
the buttons left to right; `mapmode_10` coming out as 7 is the check that the two lists
are lined up, because that one was already known from the disassembly.

| button | what it is called | mode | coloured by |
| --- | --- | --- | --- |
| `mapmode_1` | Terrain | **0** | generic path |
| `mapmode_2` | Political | **1** | `0x266220` |
| `mapmode_3` | Weather | **11** | generic path |
| `mapmode_4` | Intel | **6** | `0x267510` |
| `mapmode_5` | Revoltrisk | **12** | generic path |
| `mapmode_6` | Diplomatic | **2** | `0x2668C0` |
| `mapmode_7` | (no localisation) | **3** | generic path |
| `mapmode_8` | Supply | **4** | `0x266EE0` |
| `mapmode_9` | Infrastructure | **5** | `0x2670F0` |
| `mapmode_10` | VP | **7** | `0x267710` |
| `mapmode_11` | Theatre | **8** | `0x267920` |
| `mapmode_12` | Strength | **9** | `0x267B50` |
| `mapmode_13` | Resources | **10** | generic path |
| `mapmode_14` | Simplified Terrain | **13** | generic path |
| `mapmode_15` | Air | **18** | generic path |
| `mapmode_16` | Naval | **19** | generic path |

The dispatch that picks a routine only runs for a mode whose entry in the table at
`[map+0x30]` is 1; everything else takes the generic path. It also has a case for mode
17, which no button produces.

**Simplified Terrain is mode 13, and takes the generic path** - so there is no routine
of its own to change, and whatever it does about sea provinces it does somewhere shared.

## Simplified Terrain, and why the sea is not coloured

Mode 13. Driver at `0x266CE0`, which calls the colouring loop at `0x465B70` - and that
loop has exactly one caller, so anything done to it touches this map mode alone.

The loop reads the same intel pair the VP one does for brightness, then takes the
province's terrain and turns it into a colour:

```
eax = [province + 0xD4]      ; per province, vftable base+0x11C064C
      [eax + 0x13D]          ; a flag - 1 for every province in the save, so not a
                             ;   land/sea test, whatever it is
ecx = [eax + 0xC]            ; the CTerrain, vftable base+0x11C0764
call 0x44F290 / 0x243750     ; colour, then combined with the brightness
call 0x6628B0                ; CColor -> packed dword, the same converter the VP loop
                             ;   ends with and the one BiceLib already hooks
```

**Sea provinces are not skipped by this loop.** They are in it: it visits 14,189
provinces, which is exactly the number in `map/definition.csv`, and the 3,547 sea
provinces (`sea_starts` in `map/default.map`, ids 10500-14168) are among them. Sea
provinces have a `CTerrain` like any other - province 11000 resolves through the same
pair as province 2142.

What actually happens is further down: **the map does not draw sea from the province
colour at all.** BiceLib's own map mode proved it before this was looked at - painting
every province magenta through the colour hook turned every *land* province magenta and
left the sea exactly as it was.

So colouring the sea in the simplified terrain map mode is not a change to the map
mode. It needs whatever draws the sea to use the province colour, which has not been
found yet.

## What BiceLib does with all this

`GameState/CustomMapMode.*` and `Hooks/MapModeHooks.*`, shown on the Custom Mapmode
page under Inspector. It borrows the VP map mode: while it is on, that mode paints
building levels instead of victory points.

Two hooks, both five byte calls, installed once and never removed:

| where | was | ours does |
| --- | --- | --- |
| `0x4666B6` | `mov ecx,[esi+0x34]` + `test ecx,ecx` | answers 0 for the victory points |
| `0x4666B1` | `call 0x6628B0` | answers with a colour, or 0 to let the game convert its own |

Answering zero for the victory points keeps every province on the loop's no-VP branch,
which does two things at once: no province gets an owner colour, and the *second* colour
conversion at `0x46697D` never runs. That leaves `0x4666B1` as the only place a colour
is decided.

The colour rules, all in `CustomMapMode::colourFor`:

- no building of the chosen kind: light grey, or a darker grey below the intel threshold
- the player can see it (intel >= 6): green, brighter with the level, fixed 1 to 10
- below that: green at the lowest shade, so the map says a building is there without
  saying how much

`Hooks::MapMode::repaint()` calls `0x267710` on the map (from the game state at +0xBE8)
so a change of building shows immediately, and only when `[map+0xD34]` says the VP map
mode is the one on screen.

### Four things that cost a day between them

- **The loop converts a colour twice.** `0x4666B1` for every province, `0x46697D` only
  for one with victory points, and the `jle` after the victory point read jumps *past*
  the second to store the first one's result. Hooking only the second means hooking a
  call that mostly does not run.
- **Replacing an instruction with a call destroys eax.** `mov ecx,[esi+0x34]` left eax
  alone, and eax was carrying the colour the branch goes on to store. The stub has to
  push and pop it. This looked exactly like "the colour is wrong", for hours.
- **"A colour with red and blue at zero does not draw" was wrong.** Pure green once
  showed nothing while the same shade with 20-50 in the other channels drew fine, and
  that was written down as a rule. It is not one: the game's own infrastructure ramp
  ends on pure green, red and blue both zero, and draws it. Whatever went wrong that
  day was something else - most likely the eax clobber above, which was still present.
  BiceLib's green ramp keeps its floors only because it is tuned around them.
- **Off has to mean the hooks do nothing.** With the mode off they used to still call
  into our code, and something in that path corrupted the owner colours - fogged
  provinces came out blue instead of yellow. Both stubs now check a flag in assembly
  and run the original instructions when it is clear.

## The sea: found, and it is the water shader

**Solved.** The sea is not skipped by any map mode. `water.fx` draws it, and that
shader comes in two forms - `water_include.h` is included six times, three of them with
`PROVINCE_COLOR` defined, so every technique exists twice:

| plain | province colour |
| --- | --- |
| `WaterNear` | `WaterNearColor` |
| `WaterSimple` | `WaterSimpleColor` |
| `WaterFar` | `WaterFarColor` |

Under `PROVINCE_COLOR` the pixel shader samples `ColorTexture0` and `ColorTexture1` -
the same colour pair the colouring loop writes to `entry+0` and `entry+4` - blends them
by the stripes texture and does `color = lerp( color, ProvinceColor, 0.8f )`.

The six handles are looked up once and kept on the water object:

| field | technique |
| --- | --- |
| `+0x234` | the `water.fx` effect itself |
| `+0x240` / `+0x244` | `WaterFar` / `WaterFarColor` |
| `+0x248` / `+0x24C` | `WaterSimple` / `WaterSimpleColor` |
| `+0x250` / `+0x254` | `WaterNear` / `WaterNearColor` |

### One number decides, and it is tested twice

Every map mode setter writes a style number to `settings+0xF4`, where `settings` is the
singleton at `[hoi3_tfh+0x16863F8]` returned by `0x5FF30`. Two places test it, with the
same test written out both times:

```
mov eax, [settings + 0xF4]
cmp eax, 0x10
je  yes          ; 16
cmp eax, 0x11
jle no           ; 17 or less
cmp eax, 0x13
jle yes          ; 18 or 19
no: xor al, al
```

| where | what it gates |
| --- | --- |
| `0x480DA5` | whether the **WaterTexture update** runs - `0x4821D0`, which refills the sea's province colour texture. Its own error string is *"Locking a texture for WaterTexture update failed."* |
| `0x45FAE6` | whether the water draws with `WaterNearColor` or `WaterNear`, at `0x45FBF6` / `0x45FBFE` |

So only styles **16, 18 and 19** put province colours on the sea. What each map mode
writes, read out of its setter:

| style | modes |
| --- | --- |
| 0 | Terrain, Theatre |
| 2 | Political, Diplomatic, mode 3 |
| 6 | Supply |
| 8 | Infrastructure, **Simplified Terrain** |
| 9 | Intel, VP |
| 0xB, 0xC, 0xD, 0xF | Weather, Strength and friends |
| **0x12 (18)** | **Air** |
| **0x13 (19)** | **Naval** |
| 0x14 (20) | Resources |

Air and Naval are exactly the two modes where the sea is coloured in game, and they are
exactly the two that pass the test. That is the whole explanation.

A third place reads `+0xF4` - `0x480F1D`, inside the province colour texture builder -
but only ever compares it against 0, so 8 and 18 behave identically there. It is the
reason the land is unaffected.

### What BiceLib does

`Patches::seaTerrainColourInSimplifiedMapMode` changes one byte: the immediate of
`mov dword ptr [eax+0xF4], 8` at **`0x266E74`**, in the Simplified Terrain setter, from
8 to 18. The ten bytes are checked before the one is written. Infrastructure writes the
same 8 from its own setter at `0x266C5F` and is left alone.

Confirmed in a running game before the patch was written, by poking `settings+0xF4` to
18 while mode 13 was on screen: the sea took province colours and the land stayed
correct. The sea showed the *previous* mode's colours, because the WaterTexture update
is gated at mode set time and the poke came after it - which is precisely why the fix
belongs in the setter, before the update runs, rather than anywhere later.

### Two dead ends, recorded so they are not walked again

- **`[province+0xD4] + 0x13D` is not a land/sea flag.** The simplified terrain loop
  tests it and zeroes the brightness when it is clear, which reads like a sea skip. It
  is 1 for all 14,190 provinces in a running game. The tile updater at `0x45CA30` tests
  the same byte across a tile and looks like culling; same answer.
- **The layer mask at `settings+0xF0` is not it either.** Every setter writes one
  (`0xFFFF`, `0xFFBE`, `0xFFBA`, `0xFFBB`, `0xFFAA`, `0xFF9A`) and the renderer tests
  single bits of `[+0xF0] & [+0xEC]`. Air and Naval differ from the rest by bit 5, which
  made it look like the answer. Holding mode 13's mask at Naval's `0xFF9A` in a running
  game changed nothing at all. `+0xF4`, written by the same setters, was the real one.

## The infrastructure ramp, which is where the heat palette comes from

Mode 5, driver `0x2670F0`, colouring loop **`0x466F80`**. The loop reads
`[[province+0x114]+0x60]`, divides by 1000 and multiplies by 10 - so the infrastructure
level, 0 to 10 - then walks ten thresholds from the top down and picks a colour for
each. Blue is always zero and alpha always one; only two channels ever change.

The packer at `0x6628B0` takes a CColor and returns `0xAARRGGBB`: it reads the fields at
`+0x14`, `+0x8`, `+0xC`, `+0x10` into the bytes from most significant down, multiplies
each by 255.0 and **truncates** toward zero (it sets the x87 rounding control to 11
before each conversion). That confirms the byte order BiceLib's own `pack()` uses.

| level | float R / G | packed |
| --- | --- | --- |
| 1 | 0.10 / 0.00 | `25, 0, 0` |
| 2 | 0.60 / 0.00 | `153, 0, 0` |
| 3 | 0.80 / 0.10 | `204, 25, 0` |
| 4 | 1.00 / 0.30 | `255, 76, 0` |
| 5 | 1.00 / 1.00 | `255, 255, 0` |
| 6 | 0.65 / 0.75 | `165, 191, 0` |
| 7 | 0.10 / 0.40 | `25, 102, 0` |
| 8 | 0.20 / 0.50 | `51, 127, 0` |
| 9 | 0.25 / 0.73 | `63, 186, 0` |
| 10 | 0.00 / 1.00 | `0, 255, 0` |

Below 1 the loop leaves the colour alone entirely rather than choosing one.

Note the ladder is not monotonic in brightness: 6 is a bright yellow green and 7 a dark
one. Reproduced as is in `CustomMapMode`'s heat palette rather than smoothed.

