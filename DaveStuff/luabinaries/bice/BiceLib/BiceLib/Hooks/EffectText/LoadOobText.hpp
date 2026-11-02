#pragma once

/**
 * What `load_oob` shows in an event option's tooltip, which was a file path and nothing
 * else.
 *
 * The effect looks its own path up as though it were a localisation key, finds nothing,
 * and shows the path. **There is no key to fill in**, so this writes the whole line
 * instead: how many units appear and where, what they are made of, and which leaders
 * the file takes - with what each of those commands now, which is the part a player
 * cannot find out any other way.
 *
 * Nothing about the file is in memory until the effect fires - it opens and parses it
 * there and then - so the file is read off disk the same way the game will read it. See
 * GameState/OobFile.hpp.
 *
 * ## Holding Alt shows the whole thing
 *
 * Long lists are cut - four places and ten leaders - because that covers all but the
 * largest orders of battle and a tooltip has to fit on the screen. **Holding either Alt
 * lifts both limits**, and a tooltip that left anything out says so on its last line.
 * The line only appears when something really was cut, so a tooltip that already fits
 * does not advertise a key that would change nothing.
 *
 * It answers the key while the tooltip is up, because the game rebuilds one every frame
 * the mouse is over it. The built text is kept for a second to save re-reading the file,
 * and **Alt is part of what that text is of** - keyed on the path alone, the key would
 * look broken for up to a second at a time.
 *
 * **A leader whose rank is not the job's gets a line saying so.** The rule is the game's
 * own exact rank for each land level, from `CUnit::MayTakeLeader` - division 1, corps 2,
 * army 3, army group and theatre 4 - which is what a player or the automatic choice may put
 * on such a unit (reversing/findings/FINDINGS-leaderassign.md, section 6). Fleets and air
 * units take any rank, so they are left out.
 *
 * Where Hooks/OobLeaderRanks.hpp is switched on the line says what rank he will be made,
 * since loading the file fits him; otherwise it is red. A leader of the wrong arm stays red
 * either way, because the hook leaves him alone.
 *
 * **This was the maintainer's own rule until 2026-11-01** - everything above a corps at
 * rank 3, rank 4 an honour rather than a job - chosen against the mod's numbers before the
 * game's own rule had been read. It was changed to the game's when the hook that fits
 * leaders was written, so the two cannot disagree.
 *
 * Two stubs: one at the text builder's entry to catch the effect, and one at the last
 * call before it returns, where the built string is in hand and can be replaced. See
 * EffectText.hpp for the shared parts, and reversing/findings/FINDINGS-effecttext.md for the
 * addresses.
 *
 * **Switched on from Lua**: `BiceLib.EffectTexts.activateLoadOobDetails()`.
 */
namespace Hooks {
    namespace EffectText {
        namespace LoadOob {
            /**@brief patches the effect's two sites, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
