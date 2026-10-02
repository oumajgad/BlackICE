# The map camera, and what moves it

Worked out to give BiceLib an option that stops the map scrolling when the mouse reaches
the edge of the screen. The patch is `BiceLib/GameState/MapEdgeScroll.cpp`; this is how it
was found and why it lands where it does.

**The game has no setting for it.** `settings.txt` carries `scroll_speed`, but that is the
speed of *all* scrolling - turn it down and the arrow keys and the middle button drag slow
with it. There is no key for the edge on its own, in the game's settings or the mod's.

## Where the camera is

`CInGameIdler::CentreOnProvince` (`0x24C0E0`, virtual slot 48) is what the unit panel's
`unit_location_button` calls, and it was the way in: it takes a province and writes a
camera. The camera it writes comes from slot 28, whose whole body is

    lea eax, [ecx + 0x1938]
    ret

so **the camera is held by value inside the idler**, at `CInGameIdler + 0x1938`, and that
getter hands back its address. It has no vftable, so the RTTI export does not name it;
`MapCamera` is a name given here for what it holds.

| Offset | Holds | |
| --- | --- | --- |
| `+0x324` .. `+0x330` | the screen rectangle the map is drawn in: left, top, right, bottom | read |
| `+0x334`, `+0x338` | where the camera looks, in map coordinates - what all scrolling adds to | read |
| `+0x33C`, `+0x340` | a second copy of the pair above | read, meaning inferred |

The second pair is written by copying the first straight into it, by both
`CentreOnProvince` and the camera's own setup (`0x25CEC1`). Both of those are moves that
should happen at once rather than be eased into, which reads as the settled position
against the one being headed for - **but which of the two the renderer takes has not been
checked**, so nothing should be built on the direction.

Finding it took `--holder` style narrowing rather than a plain search: `+0x334` alone has
610 operands in the image, while `+0x1938`, the camera inside the idler, has twelve.

## What moves it

`UpdateMapCamera` (`0x23C520`) runs once a frame and does all of it. ESI is the camera,
EDI the object the mouse position is asked of, and the first stack argument the one key
states are asked of. In order:

1. dragging with the middle button, which works through the map projection rather than the
   screen;
2. the arrow keys - VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN, each `[keys]->vf_0x24(vk)`;
3. **the four screen edge tests**, below;
4. clamping the result to the camera's limits.

It ends `ret 0x10` but also takes two objects in registers, so it is left without a
signature in `project.json` rather than given a half-placed one - see the entry.

## The four edge tests

From `0x23CE97` to `0x23CFB5`, one per edge, each the same shape:

    mov  edx, [edi]              ; the mouse object's vftable
    mov  edx, [edx + 0x4C]       ; its "where is the mouse"
    lea  eax, [esp + 0x24]
    push eax
    mov  ecx, edi
    call edx
    mov  ecx, [esi + 0x328]      ; edge_top, then bottom, left, right
    add  ecx, 6                  ; the band that counts as "at the edge"
    cmp  [eax + 4], ecx          ; the mouse's y, or x for the other two
    jge  <past it>
    ...                          ; camera y += speed

Six pixels, and the mouse position arrives as a pair of ints with x at `+0` and y at `+4`.

**Nothing else is in that range**, so a five byte jump from the first byte to `0x23CFB5`
removes all four and leaves the keyboard and the drag untouched. The two instructions it
replaces - `mov edx,[edi]; mov edx,[edx+0x4C]` - are exactly five bytes, so nothing is
left half overwritten and no NOP is needed.

**The check that makes jumping over a range safe** is that nothing enters it partway.
`cfg.py --lands-in 0x63ce97 0x63cfb5` says every branch into it targets the first byte:

    0x0063CD01  je  -> 0x0063CE97      0x0063CEB1  jge -> 0x0063CEDF   (a test skipping itself)
    0x0063CD14  jne -> 0x0063CE97      0x0063CEF9  jle -> 0x0063CF27
    0x0063CD25  jne -> 0x0063CE97      0x0063CF40  jge -> 0x0063CF6E
    0x0063CD3D  je  -> 0x0063CE97      0x0063CF87  jle -> 0x0063CFB5   (the end)
    0x0063CE91  jne -> 0x0063CE97

Five ways in, all to the same byte; everything else is one of the four skipping its own
body. That is the fact the whole approach rests on, and it is worth re-running if the
range is ever revisited.

## What is still open

The zoom and rotation arithmetic in the same function, and the two unidentified stack
arguments it takes. Neither matters to the scrolling.
