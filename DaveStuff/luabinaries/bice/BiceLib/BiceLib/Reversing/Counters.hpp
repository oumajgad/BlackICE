#pragma once

/**
 * Counts how often the game reaches an address, for reverse engineering.
 *
 * The disassembly says what code *would* do; it does not say whether the game ever goes
 * there. That gap has blocked this project more than once. `ApplyAttrition` has exactly
 * one caller behind a flag nothing appears to set, and a whole section of
 * FINDINGS-manpower.md was written up as "this mechanic is probably dead" when one game
 * day would have shown it running. The transport overload branch and the `IsNaval` arm
 * of `CUnit::UpdateDaily` are open in the same way.
 *
 * So: name some addresses, run the game, read how many times each was reached.
 *
 * Nothing here runs unless the file exists, and the file is not shipped. This is a
 * workbench tool, not a feature.
 *
 * ## The file
 *
 * `BiceLibCounters.txt`, beside the DLL, one counter per line. **It is not shipped**: a
 * template lives in `reversing/probes/`, and using this means copying that file into the
 * game's script folder. What it names is one developer's question of the moment rather
 * than anything the mod carries.
 *
 *     0x1BB3E8 ; 80 B8 A4 0D 00 00 ; attrition gate test
 *     0x1C76E2 ; 89 7E 5C 3B 7E 30 ; attrition applied
 *
 * An **rva**, the bytes that must be there, and a label. Blank lines and `#` comments
 * are ignored. The bytes come straight from `disasm.py <address> <len> --bytes`; they
 * are both the check that the address is what you think and the instructions the thunk
 * replays, so they must be whole instructions and there must be at least five bytes of
 * them.
 *
 * **Two things will crash the game if you get them wrong**, and neither can be checked
 * from in here:
 *
 * - The five byte jump covers more than one instruction. If anything branches into the
 *   bytes after it, that branch lands in the middle of a jump. `cfg.py <fn> <len>
 *   --lands-in <site> <site+n>` is the check, and it is not optional.
 * - The bytes must end on an instruction boundary. `disasm.py` prints boundaries; a
 *   guessed address does not have them. x86 decodes happily from the middle of an
 *   instruction and produces confident nonsense.
 *
 * What *is* checked: the bytes match before anything is written, and none of them looks
 * like a relative branch, since a copied `jmp`, `call` or `jcc` would keep its old
 * displacement and go somewhere meaningless from the thunk. That check reads every
 * copied byte rather than decoding, so it also refuses innocent ones - a displacement
 * that happens to be `0x74` looks exactly like a `je`. Prefix the line with `!` to say
 * you have checked the bytes yourself and force it through.
 *
 * ## The output
 *
 * `BiceLibCounters.csv`, beside the DLL, one row per game day, **cumulative**:
 *
 *     day,hour,attrition gate test,attrition applied
 *     2437,1,14237,0
 *
 * Cumulative rather than per day so a missed row costs nothing; subtract to get the
 * rate. A counter that stays at zero all campaign is the answer to "is this reachable",
 * and it is an answer the disassembly cannot give.
 */
namespace Reversing {
    namespace Counters {
        /**
        @brief reads the file and installs the hooks; call once

        @return false if the file named counters it could not install, which is a
                mistake worth seeing rather than one to carry on past. True when the
                file is absent - there is nothing to do and nothing wrong.
        */
        bool install();

        /**@brief why install() failed, for the caller to print*/
        const char* status();

        /**
        @brief appends a row once a game day; call every frame

        Only on a frame where GameClock::movedInPlay() says a game is running, so never
        at the menu. Does nothing when no counter is installed.
        */
        void update();

        /**@brief how many counters are installed, 0 when the file was absent*/
        int count();
    }
}
