#include <CrashReport.hpp>

#include <Overlay.hpp>

#include <DbgHelp.h>
#include <cstdio>
#include <cstring>

namespace {
    const char* TEXT_NAME = "BiceLibCrash.txt";
    const char* DUMP_NAME = "BiceLibCrash.dmp";

    LPTOP_LEVEL_EXCEPTION_FILTER previousFilter = nullptr;
    bool installed = false;

    // Read by the handler after a crash, so they are plain values written from the
    // render thread and never anything that has to be locked or freed.
    const char* drawingPage = nullptr;
    volatile LONG framesStarted = 0;
    volatile LONG framesFinished = 0;
    int reportsWritten = 0;

    std::string textPathValue;
    std::string dumpPathValue;

    /**@brief the name of an exception code, for the ones worth naming*/
    const char* exceptionName(DWORD code) {
        switch (code) {
        case EXCEPTION_ACCESS_VIOLATION:         return "ACCESS_VIOLATION";
        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:    return "ARRAY_BOUNDS_EXCEEDED";
        case EXCEPTION_DATATYPE_MISALIGNMENT:    return "DATATYPE_MISALIGNMENT";
        case EXCEPTION_FLT_DIVIDE_BY_ZERO:       return "FLT_DIVIDE_BY_ZERO";
        case EXCEPTION_ILLEGAL_INSTRUCTION:      return "ILLEGAL_INSTRUCTION";
        case EXCEPTION_INT_DIVIDE_BY_ZERO:       return "INT_DIVIDE_BY_ZERO";
        case EXCEPTION_PRIV_INSTRUCTION:         return "PRIV_INSTRUCTION";
        case EXCEPTION_STACK_OVERFLOW:           return "STACK_OVERFLOW";
        case EXCEPTION_IN_PAGE_ERROR:            return "IN_PAGE_ERROR";
        case EXCEPTION_BREAKPOINT:               return "BREAKPOINT";
        case EXCEPTION_SINGLE_STEP:              return "SINGLE_STEP";
        case EXCEPTION_INVALID_HANDLE:           return "INVALID_HANDLE";
        case EXCEPTION_NONCONTINUABLE_EXCEPTION: return "NONCONTINUABLE";
        case EXCEPTION_FLT_INVALID_OPERATION:    return "FLT_INVALID_OPERATION";
        case EXCEPTION_FLT_OVERFLOW:             return "FLT_OVERFLOW";
        case EXCEPTION_FLT_STACK_CHECK:          return "FLT_STACK_CHECK";
        case EXCEPTION_INT_OVERFLOW:             return "INT_OVERFLOW";
        case 0xC0000374:                         return "HEAP_CORRUPTION";
        case 0xE06D7363:                         return "a C++ exception";
        default:                                 return "unknown";
        }
    }

    /**
    @brief the module an address is in, and how far into it

    Written with GetModuleHandleEx rather than a module list walk: it is one call, it
    works from an exception handler, and module+offset is exactly what symbolize.py
    takes.
    */
    bool moduleFor(uintptr_t address, char* nameOut, size_t nameSize, uintptr_t& offset) {
        HMODULE module = nullptr;
        if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
            | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCSTR>(address), &module) || module == nullptr) {
            return false;
        }

        char full[MAX_PATH] = {};
        if (GetModuleFileNameA(module, full, MAX_PATH) == 0) {
            return false;
        }

        const char* leaf = strrchr(full, '\\');
        strncpy_s(nameOut, nameSize, leaf ? leaf + 1 : full, _TRUNCATE);
        offset = address - reinterpret_cast<uintptr_t>(module);
        return true;
    }

    /**@brief writes the file, replacing whatever was there*/
    void writeText(const char* path, const char* text) {
        HANDLE file = CreateFileA(path, GENERIC_WRITE, FILE_SHARE_READ, nullptr,
            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) {
            return;
        }
        DWORD written = 0;
        WriteFile(file, text, static_cast<DWORD>(strlen(text)), &written, nullptr);
        CloseHandle(file);
    }

    /**
    @brief writes the minidump, if dbghelp can be had

    Loaded by name rather than linked, so a machine without dbghelp still gets the
    text report instead of failing to start.
    */
    typedef BOOL(WINAPI* WriteDumpFn)(HANDLE, DWORD, HANDLE, MINIDUMP_TYPE,
        PMINIDUMP_EXCEPTION_INFORMATION, PMINIDUMP_USER_STREAM_INFORMATION,
        PMINIDUMP_CALLBACK_INFORMATION);

    // Resolved while arming rather than while crashing. LoadLibrary takes the loader
    // lock, and a crash that happened while something else held it would deadlock
    // instead of producing a report.
    WriteDumpFn writeDumpFn = nullptr;

    void loadDbgHelp() {
        if (writeDumpFn != nullptr) {
            return;
        }
        HMODULE dbghelp = LoadLibraryA("dbghelp.dll");
        if (dbghelp != nullptr) {
            writeDumpFn = reinterpret_cast<WriteDumpFn>(
                GetProcAddress(dbghelp, "MiniDumpWriteDump"));
        }
    }

    void writeDump(const char* path, EXCEPTION_POINTERS* pointers) {
        if (writeDumpFn == nullptr) {
            return;     // no dbghelp, so the text report is all there is
        }

        HANDLE file = CreateFileA(path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) {
            return;
        }

        MINIDUMP_EXCEPTION_INFORMATION info = {};
        info.ThreadId = GetCurrentThreadId();
        info.ExceptionPointers = pointers;
        info.ClientPointers = FALSE;

        // Stacks and the module list, and nothing else. The game is a 32 bit process
        // carrying gigabytes; a full dump would be tens of megabytes to send, and
        // crashdump.py only wants the frames and the modules.
        const MINIDUMP_TYPE type = static_cast<MINIDUMP_TYPE>(
            MiniDumpNormal | MiniDumpWithThreadInfo | MiniDumpWithUnloadedModules);

        writeDumpFn(GetCurrentProcess(), GetCurrentProcessId(), file, type,
            &info, nullptr, nullptr);
        CloseHandle(file);
    }

    void ensurePaths() {
        if (!textPathValue.empty()) {
            return;
        }
        const std::string& directory = Overlay::directory();
        if (directory.empty()) {
            return;
        }
        textPathValue = directory + TEXT_NAME;
        dumpPathValue = directory + DUMP_NAME;
    }

    LONG WINAPI onUnhandled(EXCEPTION_POINTERS* pointers) {
        CrashReport::write(pointers, "the unhandled exception filter");

        // The game's own handler still runs. This adds a report; it does not take
        // over what the game does about crashing.
        if (previousFilter != nullptr) {
            return previousFilter(pointers);
        }
        return EXCEPTION_CONTINUE_SEARCH;
    }
}

void CrashReport::install() {
    if (installed) {
        return;
    }
    installed = true;

    // Both done now, so that writing a report later needs no allocation and no
    // loader lock: the paths are built and dbghelp is already resolved.
    ensurePaths();
    loadDbgHelp();

    previousFilter = SetUnhandledExceptionFilter(onUnhandled);
}

void CrashReport::write(EXCEPTION_POINTERS* pointers, const char* what) {
    ensurePaths();
    if (textPathValue.empty() || pointers == nullptr
        || pointers->ExceptionRecord == nullptr) {
        return;
    }

    reportsWritten++;

    const EXCEPTION_RECORD* record = pointers->ExceptionRecord;
    const CONTEXT* context = pointers->ContextRecord;
    const uintptr_t at = reinterpret_cast<uintptr_t>(record->ExceptionAddress);

    char moduleName[MAX_PATH] = "unknown";
    uintptr_t moduleOffset = 0;
    const bool known = moduleFor(at, moduleName, sizeof(moduleName), moduleOffset);

    char biceName[MAX_PATH] = {};
    uintptr_t biceBase = 0;
    HMODULE self = nullptr;
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
        | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        reinterpret_cast<LPCSTR>(&CrashReport::write), &self) && self != nullptr) {
        biceBase = reinterpret_cast<uintptr_t>(self);
        GetModuleFileNameA(self, biceName, MAX_PATH);
    }

    SYSTEMTIME now = {};
    GetLocalTime(&now);

    char text[4096];
    int n = snprintf(text, sizeof(text),
        "\r\n"
        "=====================================================================\r\n"
        " BiceLib crash report %d, caught in %s\r\n"
        " %04d-%02d-%02d %02d:%02d:%02d   BiceLib built %s %s\r\n"
        "=====================================================================\r\n"
        " exception   %s (0x%08lX)\r\n"
        " at          0x%08zX",
        reportsWritten, what,
        now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond,
        __DATE__, __TIME__,
        exceptionName(record->ExceptionCode),
        static_cast<unsigned long>(record->ExceptionCode),
        at);

    if (known) {
        n += snprintf(text + n, sizeof(text) - n, "  =  %s+0x%zX", moduleName, moduleOffset);
    }
    n += snprintf(text + n, sizeof(text) - n, "\r\n");

    if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION
        && record->NumberParameters >= 2) {
        const char* kind = (record->ExceptionInformation[0] == 0) ? "reading"
            : (record->ExceptionInformation[0] == 1) ? "writing" : "executing";
        n += snprintf(text + n, sizeof(text) - n,
            " while      %s 0x%08zX\r\n", kind,
            static_cast<size_t>(record->ExceptionInformation[1]));
    }

    if (context != nullptr) {
        n += snprintf(text + n, sizeof(text) - n,
            " registers  eip=%08lX esp=%08lX ebp=%08lX\r\n"
            "            eax=%08lX ebx=%08lX ecx=%08lX edx=%08lX\r\n"
            "            esi=%08lX edi=%08lX\r\n",
            context->Eip, context->Esp, context->Ebp,
            context->Eax, context->Ebx, context->Ecx, context->Edx,
            context->Esi, context->Edi);
    }

    n += snprintf(text + n, sizeof(text) - n,
        " overlay    %s, frames started %ld, finished %ld\r\n"
        " last page  %s\r\n"
        " BiceLib    %s loaded at 0x%08zX\r\n"
        " thread     %lu%s\r\n",
        Overlay::isVisible() ? "open" : "closed",
        framesStarted, framesFinished,
        drawingPage ? drawingPage : "(not inside a page)",
        biceName[0] ? biceName : "(unknown)", biceBase,
        GetCurrentThreadId(),
        known && _stricmp(moduleName, "BiceLib.dll") == 0
            ? "  <-- the fault is inside BiceLib" : "");

    writeText(textPathValue.c_str(), text);
    writeDump(dumpPathValue.c_str(), pointers);
}

namespace {
    /**@brief the filter half of the test, which keeps the exception from going further*/
    int testFilter(EXCEPTION_POINTERS* pointers) {
        CrashReport::write(pointers, "a test, not a crash");
        return EXCEPTION_EXECUTE_HANDLER;
    }
}

void CrashReport::writeTestReport() {
    // A real exception rather than a hand built record, so this exercises the same
    // path a crash does: the same filter, the same context, the same dump.
    __try {
        RaiseException(EXCEPTION_BREAKPOINT, 0, 0, nullptr);
    }
    __except (testFilter(GetExceptionInformation())) {
        // Caught on purpose. Nothing is wrong and nothing is switched off.
    }
}

void CrashReport::notePage(const char* pageTitle) {
    drawingPage = pageTitle;
}

void CrashReport::noteFrameStart() {
    InterlockedIncrement(&framesStarted);
    drawingPage = nullptr;
}

void CrashReport::noteFrameEnd() {
    InterlockedIncrement(&framesFinished);
    drawingPage = nullptr;
}

int CrashReport::written() {
    return reportsWritten;
}

const char* CrashReport::textPath() {
    ensurePaths();
    return textPathValue.c_str();
}
