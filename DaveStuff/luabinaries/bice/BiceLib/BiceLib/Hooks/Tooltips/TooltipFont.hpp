#pragma once

/**
 * Catching the font a tooltip is really drawn in.
 *
 * `CEU3BitmapFont::GetStringWidth` (`0x6FD700`) is patched for as long as it takes one
 * tooltip to be measured. The `this` it is called with is the font that tooltip draws in,
 * and from then on `Text::Font` measures by calling that object rather than by adding up a
 * descriptor - so there is no font to be wrong about, the measuring being done by the same
 * code that places the glyphs.
 *
 * **Nothing here has to be told which font that is**, which is the point of taking it from
 * the game. A tooltip's font is named in a `textBoxType` - `{ name = "ToolTip" font =
 * "Arial14" }` in `interface/core.gui` - and a mod is free to change it. `ToolTip_Font` in
 * `core.gfx` is a different thing that belongs to the console, and is not it.
 *
 * **The patch does not stay.** It sits on a function the interface calls for every string
 * it lays out, so it is armed when a tooltip is about to be built and taken out again as
 * soon as a font has been caught - one tooltip's worth of overhead, once per session.
 */
namespace Hooks {
    namespace Tooltips {
        namespace TooltipFont {
            /**
            @brief patches GetStringWidth until a tooltip containing \p marker is measured

            Safe to call when already armed or already answered; both do nothing.

            **\p marker only has to belong to a tooltip**, not to any particular one:
            what is wanted is the font tooltips are drawn in, so whichever one is being
            measured answers the question. A short word is better than a long phrase,
            because a string the interface has already broken up for wrapping arrives
            here one piece at a time.
            */
            bool watchFor(const char* marker);

            /**
            @brief takes the patch out, and wires the caught font into Text::Font

            Called from outside the patched function rather than from inside it: restoring
            the bytes a thread might be standing on is the one part of this worth being
            careful about, and doing it from the tooltip builder keeps it on the thread
            that armed it.
            */
            void stopWatching();

            /**@brief true once a font has been caught and Text::Font is measuring with it*/
            bool known();

            /**
            @brief armed, caught, or why not

            Nothing reads this yet. It is here because the hook modules beside this one
            all carry one, and because without it the messages set along the way would be
            written and never read.
            */
            const char* status();
        }
    }
}
