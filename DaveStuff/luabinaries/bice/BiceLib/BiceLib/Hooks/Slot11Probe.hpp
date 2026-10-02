#pragma once

#include <Windows.h>

/**
 * Answers one question, and then it should be deleted.
 *
 * **Who calls `CCombatant` slot 11?** `reversing/findings/FINDINGS-slot11.md` says: nothing but
 * `CCombat` slot 17, at the two sites `0x17B083` and `0x17B091`, so the return addresses
 * should only ever be `0x17B085` and `0x17B093` (module relative). That answer came from
 * four static sweeps, each with a positive control, and it is `confirmed` of what those
 * sweeps can see and only `likely` of the whole executable. Two things bound it: 1.80% of
 * non-padding `.text` is outside the decode, and slot 11 can also be reached through the
 * vcall thunk at `0x149E00` from a listener table that is filled at runtime, which no static
 * reading can enumerate.
 *
 * **One battle closes both holes**, because a hook sees every real call however it arrived.
 * If the only return addresses after a few minutes of fighting are those two, the file's
 * claim is settled live. If a third appears, the claim is wrong and the address names the
 * caller.
 *
 * What rides on it: if nothing else calls slot 11 then the defence side of every naval, air
 * and bombing combat modifier - `CSubUnit +0x54`, including `BM_POOR_SCREEN_PENALTY` and a
 * bombing target's `BM_FORT_MODIFIER` - reaches the `combat_status` billboard and nothing
 * else, so a mod cannot touch the simulation through any of them. The land side is already
 * known to survive: `CUnit +0xF0` is read by the AI's land-attack-odds estimator.
 *
 * **It is off by default and the stub runs no C while it is off** - see the note in the .cpp
 * on why that matters for a function this hot.
 */
namespace Hooks {
    namespace Slot11Probe {
        extern DWORD jumpBack;

        /**@brief the byte the naked stub tests. Not for direct use - call setRecording*/
        extern volatile LONG recording;

        /**@brief writes the patch, once. False if it could not be done*/
        bool install();
        bool installed();

        /**@brief why install() failed, when it did*/
        const char* status();

        /**
        @brief start or stop recording

        The patch stays in place either way; this only flips the byte the stub tests, so
        turning it off costs the game one compare per call and nothing else.
        */
        void setRecording(bool on);
        bool isRecording();

        /**@brief how many times slot 11 has been entered since the last reset*/
        long callCount();

        /**@brief distinct return addresses seen, at most SITE_LIMIT of them*/
        int siteCount();

        struct Site {
            DWORD moduleRelative;   ///< the return address, module relative, as the record writes them
            long count;             ///< how many calls came back to it
            bool expected;          ///< one of the two CCombat slot 17 sites
        };
        Site site(int index);

        /**@brief calls that arrived after the table filled up. Nonzero means sites were lost*/
        long overflowCount();

        /**@brief forget everything seen so far*/
        void reset();

        /**
        @brief writes the whole table to %TEMP%\bicelib-slot11.txt and returns the path

        The console `printf` goes to cannot be read from outside the process, and reading an
        address off a screen and retyping it is exactly how a one-byte error gets into a findings
        file. So the table goes to a file instead, on demand from a button - **never from the hook**,
        because file I/O inside a combat tick would be a performance change rather than a
        measurement. Returns null if the file could not be written.
        */
        const char* writeReport();

        void probeHook();
    }
}
