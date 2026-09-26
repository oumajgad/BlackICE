#pragma once

/**
 * Whether the map scrolls when the mouse sits against the edge of the screen.
 *
 * The game has no setting for it: `settings.txt` has `scroll_speed`, but that is the
 * speed of *all* scrolling, so turning it down takes the keyboard and the drag with it.
 * So this patches the four tests out instead, and leaves every other way of moving the
 * map alone.
 *
 * ## What is patched
 *
 * The camera's per-frame update (`0x23C520`) ends with four edge tests in a row, each of
 * the same shape - ask the input object for the mouse position, compare one coordinate
 * against a viewport edge give or take six pixels, and move the camera if it is past it:
 *
 *     mov  edx, [edi]              ; the input object's vftable
 *     mov  edx, [edx + 0x4C]       ; its "where is the mouse"
 *     lea  eax, [esp + 0x24]
 *     push eax
 *     mov  ecx, edi
 *     call edx
 *     mov  ecx, [esi + 0x328]      ; the viewport's top, then bottom, left, right
 *     add  ecx, 6
 *     cmp  [eax + 4], ecx
 *     jge  <past it>
 *     ...                          ; camera y += speed
 *
 * The four of them run from `0x23CE97` to `0x23CFB5` and nothing else is in between, so a
 * five byte jump from the first to the last takes out all four together. **Every branch
 * that enters that range lands on its first byte** - checked with `reversing/cfg.py
 * --lands-in` - so there is no path that starts in the middle of it and would run into
 * the jump's tail.
 *
 * The two instructions the jump replaces are exactly five bytes, so nothing is left
 * half overwritten and no NOP is needed.
 *
 * What is left alone: the arrow keys, which are tested earlier in the same function, and
 * dragging the map with the middle button, which is earlier still and works through the
 * map projection rather than the screen edge.
 *
 * The setting is remembered in `BiceLibSettings.ini` under `map.edgeScroll`, and put back
 * at startup by `restore()`.
 */
namespace MapEdgeScroll {
    /**@brief true when the map still scrolls from the screen edge, which is the game's own way*/
    bool enabled();

    /**
    @brief turns edge scrolling on or off, and remembers which

    Writes the bytes and the setting. Returns false where the site did not look the way
    this build expects, in which case nothing was written and `status` says so.
    */
    bool setEnabled(bool on);

    /**@brief false where the site did not look as expected and nothing can be patched*/
    bool available();

    /**@brief what happened, for a page to show*/
    const char* status();

    /**
    @brief puts the remembered setting back

    Called once at startup, because a setting has to hold whether or not the page that
    sets it is ever opened.
    */
    void restore();
}
