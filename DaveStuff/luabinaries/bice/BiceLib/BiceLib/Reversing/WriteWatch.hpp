#pragma once

#include <cstdint>

/**
 * Which instruction writes a field, asked of the running game.
 *
 * The third of the reversing probes, and the one to reach for when the other two and a
 * static search have all run out. `Counters.hpp` answers "does the game reach this
 * address"; `Watch.hpp` answers "what does this field hold"; this answers **"who put that
 * there"**, which is the question a byte search cannot answer when nothing in the image
 * stores to that displacement at all.
 *
 * It exists for `CUnit + 0xDC`, the list of combat modifiers a battle tooltip walks.
 * `reversing/fieldchain.py` finds no dword store to `[reg + 0xDC]` anywhere in the combat
 * code, and no `lea reg, [reg + 0xDC]` either, so whatever builds that list reaches it by
 * a pointer computed somewhere this cannot see. A hardware watchpoint does not care how
 * the address was worked out.
 *
 * ## What it does
 *
 * Sets a **hardware data breakpoint** - one of the CPU's four debug registers - to trap
 * on writes to one address, and catches the trap in a vectored exception handler that
 * records the instruction pointer and lets the game carry on.
 *
 * **This is not in the same safety class as the other two probes.** Watch touches nothing
 * and Counters patches instructions it has checked byte for byte; this writes the debug
 * registers of every thread in the process and installs an exception handler in front of
 * the game's own. It is off unless armed, it disarms itself cleanly, and it is a
 * workbench tool - nothing in the mod calls it.
 *
 * **The reported address is one instruction past the store.** A data breakpoint traps
 * *after* the access completes, so the recorded EIP is the instruction that follows the
 * write, not the write itself. The log says so on every row; in Ghidra, go to the address
 * and read the instruction above it.
 *
 * ## Using it
 *
 * The list lives on a `CUnit`, and the only place BiceLib is handed one is the battle
 * tooltip - so the workflow is: have a combat running, hover a unit in it so the tooltip
 * hook records which unit, then arm.
 *
 *     BiceLib.Reversing.watchCombatModifiers()
 *
 * That arms on `lastUnit() + 0xDC` and refuses, with a message saying why, if no tooltip
 * has been built yet. Then let the combat tick and watch the log. The general form is
 * there too, for a field reached some other way:
 *
 *     BiceLib.Reversing.watchWrite(0x1234ABCD, 4)   -- an absolute address
 *     BiceLib.Reversing.stopWatching()
 *
 * ## The output
 *
 * `BiceLibWrites.csv`, beside the DLL, and the same lines through the log:
 *
 *     watched,size,eip_rva,after_rva,value,hits
 *     0x1F2A40DC,4,0x1AC3F7,0x1AC3FD,0x1F2B1180,1
 *
 * **One row per distinct writer, not per write.** A field written every tick would
 * otherwise bury the answer in thousands of identical rows; what is wanted is the *set*
 * of instructions, which is usually one or two. `hits` counts how often each was seen.
 *
 * `after_rva` is what the CPU reported and `eip_rva` is the guess at the store itself -
 * the same address, since the length of the previous instruction is not known here. Both
 * columns are kept so the file never implies a precision it has not got.
 *
 * **The file is written when the watch is taken out**, not as it goes, because writing one
 * inside an exception handler is a good way to turn a probe into a crash. The live log is
 * the primary output; `stopWatching()` is what produces the csv.
 *
 * The one thing it does do in the handler is print, and only the first time each
 * instruction is seen. That is a small risk of its own - a trap taken while the CRT's own
 * lock is held would deadlock on it - and it is accepted rather than designed around,
 * because the alternative is a probe whose output you cannot see until you stop it.
 */
namespace Reversing {
    namespace WriteWatch {
        /**@brief trap writes to `address`; size must be 1, 2 or 4 and the address aligned to it*/
        bool arm(uintptr_t address, int size, const char* label);

        /**
         * @brief the **first subunit** of the battle tooltip's last unit, plus an offset
         *
         * Defaults to `0xAC`, the field CUnit::TakeDamage accumulates into beside the
         * strength damage at `+0xA8`. Nothing found by reading consumes it, so the write
         * that matters is the one that **clears** it: whatever spends a pending total
         * has to zero it afterwards, and that zero is a write like any other.
         */
        bool armSubunit(uintptr_t offset = 0xAC);

        /**
         * @brief the battle tooltip's last unit, plus an offset into it
         *
         * Defaults to `0xDC`, the head of the combat modifier list. **`0xE4`, the count,
         * is usually the better target**: the head is only written by a push when the
         * list is empty, so a run that resets and refills can write it once or not at
         * all, while every addition has to touch the count.
         */
        bool armCombatModifiers(uintptr_t offset = 0xDC);

        /**@brief clear the debug registers on every thread and take the handler out*/
        void disarm();

        bool armed();

        /**@brief why the last arm failed, when it did*/
        const char* status();
    }
}
