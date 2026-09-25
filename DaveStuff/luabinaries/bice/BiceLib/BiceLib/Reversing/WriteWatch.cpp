#include <Reversing/WriteWatch.hpp>

#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <Overlay.hpp>
#include <Hooks/Tooltips/CombatUnitStats.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <tlhelp32.h>

#include <fstream>
#include <map>
#include <string>

namespace {
    const char* const OUTPUT_FILE = "BiceLibWrites.csv";

    /**
     * **One writer is the answer; a thousand rows of it are not.** A field the game
     * touches every tick would otherwise fill the file with the same address, so each
     * distinct instruction is reported once and counted after that. Past this many
     * distinct ones something is wrong with the watch rather than interesting about the
     * field, and it disarms itself rather than grow without bound inside an exception
     * handler.
     */
    const size_t MOST_WRITERS = 64;

    PVOID handler = nullptr;
    uintptr_t watched = 0;
    int watchedSize = 0;
    uintptr_t base = 0;
    std::string outputPath;
    std::string watchLabel;
    const char* message = "not armed";

    /** eip -> how often, and what was in the field when it was seen */
    std::map<uintptr_t, unsigned> seen;
    std::map<uintptr_t, uintptr_t> valueAt;

    /**@brief the LEN bits DR7 wants: 1 byte 00, 2 bytes 01, 4 bytes 11*/
    bool lengthBits(int size, DWORD& bits) {
        switch (size) {
        case 1: bits = 0; return true;
        case 2: bits = 1; return true;
        case 4: bits = 3; return true;
        default: return false;
        }
    }

    /**
    @brief put the watch in, or take it out, on one thread

    **The current thread is not suspended.** Suspending yourself never returns, and the
    debug registers are one of the few parts of a context that can be read and written on
    a running thread without the usual caveats - which matters here, because the game may
    well do its combat on the same thread that ran the Lua that armed this.
    */
    bool setOn(HANDLE thread, bool current, uintptr_t address, int size) {
        DWORD bits = 0;
        if (address != 0 && !lengthBits(size, bits)) {
            return false;
        }
        if (!current) {
            if (SuspendThread(thread) == static_cast<DWORD>(-1)) {
                return false;
            }
        }

        CONTEXT context;
        ZeroMemory(&context, sizeof context);
        context.ContextFlags = CONTEXT_DEBUG_REGISTERS;
        bool ok = GetThreadContext(thread, &context) != 0;
        if (ok) {
            // DR0 is ours; L0 enables it, RW0 = 01 traps writes, LEN0 is the width.
            context.Dr7 &= ~0x000F0003UL;       // clear L0, G0, RW0 and LEN0
            context.Dr6 = 0;
            if (address == 0) {
                context.Dr0 = 0;
            }
            else {
                context.Dr0 = address;
                context.Dr7 |= 1UL;                   // L0
                context.Dr7 |= (1UL << 16);           // RW0 = write
                context.Dr7 |= (bits << 18);          // LEN0
            }
            context.ContextFlags = CONTEXT_DEBUG_REGISTERS;
            ok = SetThreadContext(thread, &context) != 0;
        }

        if (!current) {
            ResumeThread(thread);
        }
        return ok;
    }

    /**
    @brief every thread of this process, because a debug register is per thread

    The write being looked for happens on whichever thread runs the combat, and the watch
    is armed from whichever thread runs Lua. Arming only the caller's would answer "nothing
    ever writes it" for the commonest reason of all - looking in the wrong place.
    */
    int onEveryThread(uintptr_t address, int size) {
        const DWORD process = GetCurrentProcessId();
        const DWORD self = GetCurrentThreadId();
        HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
        if (snapshot == INVALID_HANDLE_VALUE) {
            return 0;
        }

        int done = 0;
        THREADENTRY32 entry;
        entry.dwSize = sizeof entry;
        if (Thread32First(snapshot, &entry)) {
            do {
                if (entry.th32OwnerProcessID != process) {
                    continue;
                }
                if (entry.th32ThreadID == self) {
                    if (setOn(GetCurrentThread(), true, address, size)) {
                        ++done;
                    }
                    continue;
                }
                HANDLE thread = OpenThread(
                    THREAD_GET_CONTEXT | THREAD_SET_CONTEXT | THREAD_SUSPEND_RESUME,
                    FALSE, entry.th32ThreadID);
                if (thread == nullptr) {
                    continue;
                }
                if (setOn(thread, false, address, size)) {
                    ++done;
                }
                CloseHandle(thread);
            } while (Thread32Next(snapshot, &entry));
        }
        CloseHandle(snapshot);
        return done;
    }

    void record(uintptr_t eip) {
        const size_t before = seen.size();
        unsigned& hits = seen[eip];
        ++hits;
        if (hits != 1) {
            return;
        }

        uintptr_t value = 0;
        if (!Mem::tryRead(watched, value)) {
            value = 0;
        }
        valueAt[eip] = value;

        // Reporting happens on the first sighting only, which is also the only time this
        // does anything slow inside an exception handler.
        INFO_OUT(printf("WriteWatch: %s written from rva %#010x (the store is just above "
            "it), field now %#010x\n", watchLabel.c_str(),
            static_cast<unsigned>(eip - base), static_cast<unsigned>(value)));

        if (before + 1 >= MOST_WRITERS) {
            ERROR_OUT(printf("WriteWatch: %u distinct writers, which is not an answer - "
                "disarming\n", static_cast<unsigned>(seen.size())));
            onEveryThread(0, 0);
            watched = 0;
        }
    }

    /**
    @brief catches the trap, records where it came from, and lets the game carry on

    **Only ever claims a trap that is ours.** DR6's low four bits say which debug register
    fired; anything else - the game's own single stepping, a breakpoint from a debugger
    attached alongside - goes back to the chain untouched. The handler is at the front of
    the chain, so being wrong here would break the game's exception handling rather than
    merely lose a row.
    */
    LONG CALLBACK onException(EXCEPTION_POINTERS* info) {
        if (info == nullptr || info->ExceptionRecord == nullptr
            || info->ExceptionRecord->ExceptionCode != EXCEPTION_SINGLE_STEP) {
            return EXCEPTION_CONTINUE_SEARCH;
        }
        CONTEXT* context = info->ContextRecord;
        if (context == nullptr || (context->Dr6 & 0x1UL) == 0 || watched == 0) {
            return EXCEPTION_CONTINUE_SEARCH;
        }

        record(static_cast<uintptr_t>(context->Eip));
        context->Dr6 = 0;
        return EXCEPTION_CONTINUE_EXECUTION;
    }

    void writeFile() {
        if (outputPath.empty()) {
            return;
        }
        std::ofstream file(outputPath.c_str(), std::ios::trunc);
        if (!file) {
            return;
        }
        file << "watched,size,label,eip_rva,after_rva,value,hits\n";
        for (std::map<uintptr_t, unsigned>::const_iterator it = seen.begin();
             it != seen.end(); ++it) {
            const unsigned rva = static_cast<unsigned>(it->first - base);
            file << "0x" << std::hex << static_cast<unsigned>(watched) << std::dec
                 << "," << watchedSize
                 << "," << watchLabel
                 << ",0x" << std::hex << rva
                 << ",0x" << rva << std::dec
                 << ",0x" << std::hex << static_cast<unsigned>(valueAt[it->first]) << std::dec
                 << "," << it->second << "\n";
        }
    }
}

bool Reversing::WriteWatch::arm(uintptr_t address, int size, const char* label) {
    DWORD bits = 0;
    if (address == 0 || !lengthBits(size, bits)) {
        message = "the address is null or the size is not 1, 2 or 4";
        return false;
    }
    if ((address % static_cast<uintptr_t>(size)) != 0) {
        message = "a hardware watchpoint has to be aligned to its own size";
        return false;
    }

    base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        message = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (outputPath.empty()) {
        const std::string& directory = Overlay::directory();
        if (!directory.empty()) {
            outputPath = directory + OUTPUT_FILE;
        }
    }

    // Rearming on a different address starts a fresh answer rather than mixing two.
    disarm();
    seen.clear();
    valueAt.clear();

    handler = AddVectoredExceptionHandler(1, &onException);
    if (handler == nullptr) {
        message = "could not install the exception handler";
        return false;
    }

    watched = address;
    watchedSize = size;
    watchLabel = label == nullptr ? "field" : label;

    const int threads = onEveryThread(address, size);
    if (threads == 0) {
        disarm();
        message = "no thread would take the watchpoint";
        return false;
    }

    message = "armed";
    INFO_OUT(printf("WriteWatch: watching %d bytes at %#010x (%s) on %d threads\n",
        size, static_cast<unsigned>(address), watchLabel.c_str(), threads));
    return true;
}

bool Reversing::WriteWatch::armCombatModifiers(uintptr_t offset) {
    const uintptr_t unit = Hooks::Tooltips::CombatUnitStats::lastUnit();
    if (unit == 0) {
        message = "no unit yet - hover a unit in a battle first, so the tooltip hook "
            "records which one, then arm";
        ERROR_OUT(printf("WriteWatch: %s\n", message));
        return false;
    }
    char label[64];
    _snprintf_s(label, sizeof label, _TRUNCATE, "CUnit+%#x",
        static_cast<unsigned>(offset));
    // The unit is printed so a run that catches nothing can be told apart from one whose
    // unit was freed and its memory reused underneath the watch.
    INFO_OUT(printf("WriteWatch: the unit is %#010x\n", static_cast<unsigned>(unit)));
    return arm(unit + offset, 4, label);
}

bool Reversing::WriteWatch::armSubunit(uintptr_t offset) {
    const uintptr_t unit = Hooks::Tooltips::CombatUnitStats::lastUnit();
    if (unit == 0) {
        message = "no unit yet - hover a unit in a battle first, so the tooltip hook "
            "records which one, then arm";
        ERROR_OUT(printf("WriteWatch: %s\n", message));
        return false;
    }

    uintptr_t node = 0;
    uintptr_t regiment = 0;
    if (!Mem::tryRead(unit + CUnit::Offsets::regiments + HDS::ListOffsets::first, node)
        || node == 0
        || !Mem::tryRead(node + HDS::NodeOffsets::data, regiment)
        || regiment == 0) {
        message = "that unit has no first subunit to watch";
        ERROR_OUT(printf("WriteWatch: %s\n", message));
        return false;
    }

    char label[64];
    _snprintf_s(label, sizeof label, _TRUNCATE, "CSubUnit+%#x",
        static_cast<unsigned>(offset));
    // Both are logged because the interesting write may well be a clear rather than an
    // add, and a run that catches only adds has to be told from one watching the wrong
    // object.
    INFO_OUT(printf("WriteWatch: the unit is %#010x, its first subunit %#010x\n",
        static_cast<unsigned>(unit), static_cast<unsigned>(regiment)));
    return arm(regiment + offset, 4, label);
}

void Reversing::WriteWatch::disarm() {
    if (watched != 0) {
        onEveryThread(0, 0);
        writeFile();
    }
    if (handler != nullptr) {
        RemoveVectoredExceptionHandler(handler);
        handler = nullptr;
    }
    watched = 0;
    watchedSize = 0;
    message = "not armed";

    // The next run has to hover its own unit. Otherwise a kind of combat whose tooltip
    // never reaches the hook would arm on the last one that did, and answer for it.
    Hooks::Tooltips::CombatUnitStats::forgetUnit();
}

bool Reversing::WriteWatch::armed() {
    return watched != 0;
}

const char* Reversing::WriteWatch::status() {
    return message;
}
