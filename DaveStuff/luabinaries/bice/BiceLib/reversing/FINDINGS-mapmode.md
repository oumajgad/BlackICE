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
