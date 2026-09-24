#pragma once

/**
 * Samples fields of the game state every frame and records when they change.
 *
 * The companion to Reversing/Counters.hpp, and the other half of the same problem.
 * Counters answer "does the game ever reach here", which needs code to run. This
 * answers "what does this field hold, and when does it change", which is the question
 * at the main menu, where nothing is running at all.
 *
 * It exists for `in_game`. `CCurrentGameState +0xDA4` was traced statically to a single
 * writer inside the routine that enters a running game, which makes it the flag that
 * says an actual session is on screen - a useful thing to have, because BiceLib has
 * never had a straight answer to that question and works around it by watching the
 * clock. A static trace of one instruction is not proof, so this watches the byte.
 *
 * **Nothing here hooks anything.** It reads through `CCurrentGameState::current()`,
 * which goes through `Mem::tryRead` and gives back zero when the pointer is not there,
 * and it refuses an offset outside the object. That is the whole safety argument: there
 * is no patched instruction, no thunk and no wild pointer, so the worst it can do is
 * write a wrong number into a csv.
 *
 * ## The file
 *
 * `BiceLibWatch.txt`, beside the DLL, one field per line. **It is not shipped**: a
 * template lives in `reversing/probes/`, and using this means copying that file into the
 * game's script folder. What it names is one developer's question of the moment rather
 * than anything the mod carries.
 *
 *     0xDA4 ; 1 ; in_game
 *
 * An offset into `CCurrentGameState`, a size of 1, 2 or 4 bytes, and a label. Blank
 * lines and `#` comments are ignored. The offset has to fall inside the object's `0xDA8`
 * bytes or the line is refused, which is what makes a bad line harmless.
 *
 * ## The output
 *
 * `BiceLibWatch.csv`, beside the DLL, **a row only when something changes**:
 *
 *     tick,day,hour,inplay,pointer,in_game
 *     0,0,0,0,0,-
 *     0,0,0,0,1,0
 *     43800024,1,0,0,1,1
 *
 * A campaign is therefore two or three rows, not a million. `pointer` is whether the
 * game state exists yet at all, a value of `-` means it could not be read, and the clock
 * columns are context rather than triggers - if a change in the tick counted as a
 * change, every frame would be a row.
 *
 * **The clock columns are how the instrument checks itself.** A watch that reports a
 * field never changing is indistinguishable from a watch that is not running, so every
 * row carries `tick` and `inplay` from GameClock, which are known to move. A file whose
 * rows all read `tick 0` is not evidence about the field; it is evidence the sampling
 * never reached a game.
 *
 * What would show `in_game` wrong: the byte reading 1 while still at the menu, or
 * staying 0 through a running game. What would confirm it: 0 for every frame of the
 * menu, then 1 from the frame the session comes up - and, since the write happens
 * before the in-game GUI is built, that 0 -> 1 should land *before* the clock first
 * reports being in play, not after.
 */
namespace Reversing {
    namespace Watch {
        /**
        @brief reads the file; call once. True when there is nothing to do.
        */
        bool install();

        /**@brief why install() failed, or what it is watching, for the caller to print*/
        const char* status();

        /**
        @brief samples the fields; call every frame

        **Deliberately not gated on the clock**, unlike everything else called from
        Present: the reading that matters is the one taken at the main menu, where the
        clock stands still by definition. Reads one pointer and up to a few bytes behind
        it, and writes nothing unless a value moved.
        */
        void update();

        /**@brief how many fields are watched, 0 when the file was absent*/
        int count();
    }
}
