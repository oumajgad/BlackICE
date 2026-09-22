#pragma once

/**
 * Lets a requirement tooltip that runs off the screen be scrolled, with Alt and the
 * arrow keys.
 *
 * A technology with a long `allow` block produces more lines than the tooltip can
 * show, and the game neither shrinks it nor scrolls it - the rest is simply off the
 * bottom of the screen and there is no way to reach it.
 *
 * ## Scrolled by rewriting the text, not by touching the GUI
 *
 * **The game rebuilds a tooltip's text continuously while it is hovered**, which is
 * what makes this possible at all: the same fact behind the `load_oob` tooltip growing
 * the moment Alt goes down. So holding Alt and turning the wheel, or pressing Down,
 * drops lines off the *front* of the text the next time it is built - the tooltip is
 * that much shorter, and what was below the screen moves up into view. Scrolling back
 * puts them on again.
 *
 * **Alt is required for the wheel as well as the keys.** A decision or a triggered
 * modifier shows its conditions in a tooltip over a list that scrolls, and the pointer
 * sits on the tooltip for as long as it is being read - so a wheel taken on sight is
 * taken from the list the player is trying to move.
 *
 * Nothing about the game's tooltip window is patched, measured or resized. As far as
 * it is concerned the requirement text simply got shorter.
 *
 * A list long enough to be in danger of running off the screen says so on its first
 * line, so the keys are discoverable without having to be told about them. Once
 * anything has been scrolled away that line says how much instead.
 *
 * ## Where it hooks
 *
 * `CAndTrigger::GetBlockText`, on its way out (rva 0x5D0CB0), and only when the depth
 * it was called with is 0 - the whole tree rather than a block inside it. A
 * technology's `allow` is an implicit `and`, so that is the one call that has the
 * finished text in hand.
 *
 * **One instruction before the epilogue rather than over it.** The epilogue writes
 * `fs:[0]` to unlink the function's SEH frame, and reproducing that from inline
 * assembly makes MSVC warn that a handler is being registered unsafely (C4733) - it
 * cannot tell that apart from a chain being put back. Standing earlier leaves the
 * unlink to the game and replaces seven bytes instead of eighteen.
 *
 * ## What it deliberately does not do
 *
 * **Counting lines the way the screen does.** The game wraps a long condition across
 * two rows; this counts the newlines in the string, so scrolling one step can move the
 * text by more than one row. The text still walks past reliably in both directions,
 * which is what the feature is for.
 */
namespace Hooks {
    namespace EffectText {
        namespace TriggerScroll {
            /**
            @brief patches the exit of the `and` renderer, once; safe to call again

            Checks the eighteen bytes it replaces before writing anything, so a build
            this does not fit is left alone.
            */
            bool install();

            /**
            @brief offers one turn of the mouse wheel to a requirement tooltip

            Called from the window procedure, before the game sees the message.

            **Taken only with Alt held, and only while a scrollable requirement
            tooltip is actually on screen.** The second is known without asking the GUI
            anything: the text is rebuilt continuously while one is hovered, so a render
            within the last fraction of a second means one is up. Outside those two the
            wheel is not touched, and whatever was going to have it - the map, or a list
            under the tooltip - still does.

            @param delta WHEEL_DELTA units, as WM_MOUSEWHEEL gives them; forward is
                   positive and scrolls towards the top of the list
            @returns true if it was used, in which case the game should not see it
            */
            bool takeWheel(int delta);

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
