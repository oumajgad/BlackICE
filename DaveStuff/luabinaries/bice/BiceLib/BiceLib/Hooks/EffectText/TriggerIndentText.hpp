#pragma once

/**
 * Indents the inside of an `and` or an `or` block in a requirement tooltip.
 *
 * A technology's requirements are a tree of triggers, and the game renders one line per
 * trigger with three spaces of indent for every level it is deep. **It gets the depth
 * wrong for everything inside an `and` or an `or`**, so a nested condition is drawn
 * flush against the left edge as though it were top level:
 *
 *     One of the following must be true:
 *       All of the below:
 *     Have the country flag '1__Cond__A'      <- should be two levels in
 *     Have the country flag '1__Cond__B'
 *
 * ## Where it goes wrong
 *
 * Every trigger has two text methods on its vftable: **slot 9** renders a whole block -
 * the `AND_TRIGGER_STARTS` or `OR_TRIGGER_STARTS` header and everything under it - and
 * **slot 8** (`GetText`) renders one line. Both take the depth to indent to as their
 * last argument, and both use it: the block renderer opens by appending three spaces
 * that many times.
 *
 * `CAndTrigger` and `COrTrigger` each render their own header at the depth they were
 * given, correctly, and then **pass a constant for their children instead of one more
 * than their own depth**. The game is not even consistent about which constant:
 *
 * | site | child's depth |
 * | --- | --- |
 * | `CAndTrigger` slot 9 -> child's slot 9 | `0` |
 * | `CAndTrigger` slot 9 -> child's GetText | `0` |
 * | `COrTrigger` slot 9 -> child's slot 9 | `1` |
 * | `COrTrigger` slot 9 -> child's GetText | `0` |
 *
 * So a nested block under an `or` is indented one level whatever depth it is really at,
 * a nested block under an `and` is not indented at all, and **a plain condition inside
 * either is never indented**, which is the part that shows.
 *
 * ## What this does
 *
 * Four stubs, one per site. Each reproduces the two instructions it stands in for -
 * fetching the child's method out of its vftable - then pushes `depth + 1` in place of
 * the constant and rejoins the game's code just after the push it replaced. The depth
 * is the call's own fourth argument at `[ebp + 0x14]`, which neither function ever
 * writes to, so it is still the depth at the point the stub reads it.
 *
 * Nothing else changes: the header, the text of each line, and the order are the game's.
 *
 * **Switched on from Lua**: `BiceLib.EffectTexts.activateTriggerIndent()`.
 */
namespace Hooks {
    namespace EffectText {
        namespace TriggerIndent {
            /**@brief patches the four sites, all or none; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
