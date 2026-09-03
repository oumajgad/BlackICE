#pragma once

#include <Windows.h>

/**
 * What BiceLib writes when it crashes, so a report can be asked for instead of a
 * Windows dump.
 *
 * Windows' own local dumps are switched off unless somebody has added the LocalDumps
 * keys to the registry beforehand, so asking a player for one means asking them to
 * change the registry, reproduce the crash and then send tens of megabytes. This
 * writes both halves itself, into a `crash_reports` folder beside the DLL:
 *
 *  - `BiceLibCrash_001.txt` - the exception, where it happened as `module+offset`,
 *    the registers, and what the overlay was doing. Small enough to paste into a chat.
 *  - `BiceLibCrash_001.dmp` - a minidump, for `reversing/crashdump.py` and
 *    `reversing/symbolize.py`. Only stacks and module lists, so a few megabytes
 *    rather than the ~37 MB of a full Windows dump.
 *
 * The text alone is usually enough: it names the module and offset, which
 * `symbolize.py` turns into a function and line against the pdb beside the build.
 *
 * **Every crash gets its own number, and nothing already written is touched.** One
 * crash often causes the next, and the first is the one worth reading; an earlier
 * version overwrote, and the report that mattered was lost exactly that way. The
 * numbering continues past whatever the folder already holds, so reports from an
 * earlier session survive too.
 */
namespace CrashReport {
    /**
    @brief arms the reporter

    Installs an unhandled exception filter and remembers the one already there, which
    is called afterwards - so the game's own crash handling still happens and this
    only adds to it.
    */
    void install();

    /**
    @brief writes a report for an exception that has already been caught

    Used by the guard around the overlay, which catches its own crashes rather than
    letting them reach the filter. Safe to call from an exception handler: it opens
    files with the Win32 calls directly and allocates nothing.

    @param pointers the exception, as an __except filter receives it
    @param what where it was caught, reading after "caught in" - e.g. "the overlay"
    */
    void write(EXCEPTION_POINTERS* pointers, const char* what);

    /**
    @brief writes a report for an exception raised on purpose

    So a player can be asked to produce the file and send it before anything has gone
    wrong, which is how a crash nobody can reproduce gets its first evidence. The
    report is marked as a test, and nothing else about it differs - same path, same
    dump, same code that a real crash goes through.
    */
    void writeTestReport();

    /**
    @brief notes which page is being drawn, for the report to name

    Costs a pointer assignment per page per frame. The string has to outlive the
    call, which a page title does - they are literals.
    */
    void notePage(const char* pageTitle);

    /**@brief notes that a frame is being drawn, and that one finished*/
    void noteFrameStart();
    void noteFrameEnd();

    /**@brief how many reports have been written this session*/
    int written();

    /**@brief the folder the reports are written into, for a page that wants to say so*/
    const char* folder();

    /**@brief the newest report written this session, empty if there has been none*/
    const char* lastReport();
}
