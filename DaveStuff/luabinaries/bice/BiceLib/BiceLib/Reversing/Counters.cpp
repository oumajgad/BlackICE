#include <Reversing/Counters.hpp>

#include <GameState/GameClock.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <Overlay.hpp>

#include <Windows.h>

#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace {
    const char* SOURCE_FILE = "BiceLibCounters.txt";
    const char* OUTPUT_FILE = "BiceLibCounters.csv";

    const int MAX_COUNTERS = 64;
    const int MIN_BYTES = 5;        // what a jmp rel32 needs to overwrite
    const int MAX_BYTES = 32;

    // pushad, pushfd, push imm32, call rel32, popfd, popad, the copied bytes, jmp rel32
    const int THUNK_FIXED = 19;
    const int THUNK_STRIDE = 64;    // THUNK_FIXED + MAX_BYTES, rounded up

    struct Counter {
        std::string label;
        uintptr_t site;             // absolute, once the module base is known
        int length;                 // how many bytes the thunk replays
        unsigned char bytes[MAX_BYTES];
        volatile LONG hits;
    };

    Counter counters[MAX_COUNTERS];
    int installed = 0;
    std::string message = "not installed";
    std::string outputPath;

    unsigned char* thunks = nullptr;

    int lastDay = -1;
    int lastSession = 0;
    bool headerWritten = false;

    /**
    @brief what the thunks call

    __stdcall so it cleans up the index the thunk pushed. Interlocked because a hook
    fires on whatever thread reached the instruction, and nothing here says that is
    only ever the one.
    */
    void __stdcall tally(int index) {
        if (index >= 0 && index < MAX_COUNTERS) {
            InterlockedIncrement(&counters[index].hits);
        }
    }

    /**
    @brief whether a byte could begin a relative branch

    A copied `jmp`, `call` or `jcc` keeps the displacement it had at the original
    address, so replayed from a thunk it goes somewhere meaningless. There is no
    disassembler in here to say which bytes are opcodes, so this reads every copied byte
    and is deliberately over-eager: a displacement that happens to be 0x74 looks exactly
    like a `je`, and 0x0F is far more often `movzx` than a long `jcc`. A false refusal
    costs a line in a file; a false pass costs the game. The `!` prefix is the way out.
    */
    bool looksRelative(unsigned char byte) {
        return byte == 0xE8 || byte == 0xE9 || byte == 0xEB
            || (byte >= 0x70 && byte <= 0x7F)       // jcc rel8
            || (byte >= 0xE0 && byte <= 0xE3)       // loop, loope, loopne, jecxz
            || byte == 0x0F;                        // possibly a jcc rel32
    }

    std::string trim(const std::string& text) {
        const size_t first = text.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) {
            return std::string();
        }
        const size_t last = text.find_last_not_of(" \t\r\n");
        return text.substr(first, last - first + 1);
    }

    /**
    @brief one line of the file into \p out

    Returns false with \p why set when the line is there but wrong, which is worth
    reporting; a blank or commented line is neither parsed nor an error, and leaves
    \p parsed false.
    */
    bool readLine(const std::string& line, Counter& out, bool& parsed, std::string& why) {
        parsed = false;
        std::string text = trim(line);
        if (text.empty() || text[0] == '#') {
            return true;
        }

        bool forced = false;
        if (text[0] == '!') {
            forced = true;
            text = trim(text.substr(1));
        }

        const size_t first = text.find(';');
        const size_t second = text.find(';', first + 1);
        if (first == std::string::npos || second == std::string::npos) {
            why = "a line wants three fields: rva ; bytes ; label";
            return false;
        }

        const std::string address = trim(text.substr(0, first));
        const std::string bytes = trim(text.substr(first + 1, second - first - 1));
        std::string label = trim(text.substr(second + 1));

        if (label.empty()) {
            why = "a counter needs a label";
            return false;
        }
        // the label becomes a csv heading, so it cannot carry the separator
        for (size_t i = 0; i < label.size(); i++) {
            if (label[i] == ',') {
                label[i] = ' ';
            }
        }

        char* end = nullptr;
        const unsigned long rva = strtoul(address.c_str(), &end, 0);
        if (end == address.c_str() || (end != nullptr && *end != '\0') || rva == 0) {
            why = "the first field is not an rva";
            return false;
        }

        int length = 0;
        std::istringstream stream(bytes);
        std::string token;
        while (stream >> token) {
            if (length >= MAX_BYTES) {
                why = "too many bytes for one counter";
                return false;
            }
            char* byteEnd = nullptr;
            const unsigned long value = strtoul(token.c_str(), &byteEnd, 16);
            if (byteEnd == token.c_str() || *byteEnd != '\0' || value > 0xFF) {
                why = "the second field wants hex bytes, as disasm.py --bytes prints them";
                return false;
            }
            const unsigned char byte = static_cast<unsigned char>(value);
            if (!forced && looksRelative(byte)) {
                why = "a byte there could begin a relative branch, which cannot be "
                      "replayed from a thunk - check it and prefix the line with ! if "
                      "it is not one";
                return false;
            }
            out.bytes[length] = byte;
            length++;
        }

        if (length < MIN_BYTES) {
            why = "a counter needs at least five bytes of whole instructions, since "
                  "that is what the jump overwrites";
            return false;
        }

        out.label = label;
        out.site = rva;             // made absolute once the base is known
        out.length = length;
        out.hits = 0;
        parsed = true;
        return true;
    }

    /**
    @brief writes one counter's thunk and points the site at it

    The thunk counts, then replays exactly the bytes the jump displaced, then returns to
    the instruction after them - the same shape as every hand written stub in Hooks/,
    built at runtime because each counter needs its own index and its own bytes.
    */
    void buildThunk(int index) {
        Counter& counter = counters[index];
        unsigned char* thunk = thunks + index * THUNK_STRIDE;
        int at = 0;

        thunk[at++] = 0x60;                                     // pushad
        thunk[at++] = 0x9C;                                     // pushfd

        thunk[at++] = 0x68;                                     // push index
        *reinterpret_cast<int*>(thunk + at) = index;
        at += 4;

        thunk[at++] = 0xE8;                                     // call tally
        *reinterpret_cast<intptr_t*>(thunk + at) =
            reinterpret_cast<intptr_t>(&tally)
            - reinterpret_cast<intptr_t>(thunk + at + 4);
        at += 4;

        thunk[at++] = 0x9D;                                     // popfd
        thunk[at++] = 0x61;                                     // popad

        for (int i = 0; i < counter.length; i++) {              // what the jump displaced
            thunk[at++] = counter.bytes[i];
        }

        thunk[at++] = 0xE9;                                     // jmp back
        *reinterpret_cast<intptr_t*>(thunk + at) =
            static_cast<intptr_t>(counter.site + counter.length)
            - reinterpret_cast<intptr_t>(thunk + at + 4);
        at += 4;
    }
}

bool Reversing::Counters::install() {
    // The game runs the mod's bootstrap once per lua_State and BiceLib holds several, so
    // this is called more than once a session. A second pass would find its own jumps
    // where it expects the game's instructions and report the build as wrong - it writes
    // nothing, because every site is checked before any is hooked, but the message would
    // send whoever read it looking for a problem that is not there.
    if (installed > 0) {
        return true;
    }

    const std::string& directory = Overlay::directory();
    if (directory.empty()) {
        message = "no directory to read the counter file from";
        return false;
    }
    outputPath = directory + OUTPUT_FILE;

    std::ifstream file((directory + SOURCE_FILE).c_str());
    if (!file) {
        // the ordinary case: this is a workbench tool and the file is not shipped
        message = "no BiceLibCounters.txt, so nothing to count";
        installed = 0;
        return true;
    }

    // Read and check every line before writing anything. A file with one bad line
    // installs nothing at all, rather than leaving the game half hooked by a tool whose
    // whole purpose is to be trusted about what ran.
    std::vector<Counter> wanted;
    std::string line;
    int number = 0;
    while (std::getline(file, line)) {
        number++;
        Counter counter;
        bool parsed = false;
        std::string why;
        if (!readLine(line, counter, parsed, why)) {
            std::ostringstream text;
            text << SOURCE_FILE << " line " << number << ": " << why;
            message = text.str();
            return false;
        }
        if (parsed) {
            if (static_cast<int>(wanted.size()) >= MAX_COUNTERS) {
                message = "more counters than there is room for";
                return false;
            }
            wanted.push_back(counter);
        }
    }

    if (wanted.empty()) {
        message = "BiceLibCounters.txt names no counters";
        installed = 0;
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        message = "the game module was not found";
        return false;
    }

    for (size_t i = 0; i < wanted.size(); i++) {
        wanted[i].site += base;
        if (!Hooks::bytesAre(wanted[i].site, wanted[i].bytes, wanted[i].length)) {
            std::ostringstream text;
            text << "'" << wanted[i].label << "' is not at that address in this build";
            message = text.str();
            return false;
        }
    }

    if (thunks == nullptr) {
        thunks = static_cast<unsigned char*>(VirtualAlloc(
            nullptr, MAX_COUNTERS * THUNK_STRIDE,
            MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE));
        if (thunks == nullptr) {
            message = "no executable memory for the thunks";
            return false;
        }
    }

    for (size_t i = 0; i < wanted.size(); i++) {
        counters[i] = wanted[i];
        buildThunk(static_cast<int>(i));
        if (!Hooks::hook(reinterpret_cast<void*>(counters[i].site),
                         thunks + i * THUNK_STRIDE, 5, counters[i].length - 5)) {
            std::ostringstream text;
            text << "'" << counters[i].label << "' could not be hooked";
            message = text.str();
            installed = static_cast<int>(i);
            return false;
        }
        installed = static_cast<int>(i) + 1;
    }

    std::ostringstream text;
    text << installed << " counters installed";
    message = text.str();
    headerWritten = false;
    return true;
}

const char* Reversing::Counters::status() {
    return message.c_str();
}

int Reversing::Counters::count() {
    return installed;
}

void Reversing::Counters::update() {
    if (installed == 0 || outputPath.empty()) {
        return;
    }
    if (!GameClock::movedInPlay()) {
        return;
    }

    // A load or a new game restarts the campaign but not the totals, which go on
    // climbing from whatever the last one left. Writing the heading again is what marks
    // the break in the file.
    const int session = GameClock::session();
    if (session != lastSession) {
        lastSession = session;
        lastDay = -1;
        headerWritten = false;
    }

    const int day = GameClock::day();
    if (day == lastDay) {
        return;
    }
    lastDay = day;

    std::ofstream file(outputPath.c_str(), std::ios::app);
    if (!file) {
        return;
    }

    if (!headerWritten) {
        headerWritten = true;
        file << "day,hour";
        for (int i = 0; i < installed; i++) {
            file << "," << counters[i].label;
        }
        file << "\n";
    }

    file << day << "," << GameClock::hour();
    for (int i = 0; i < installed; i++) {
        file << "," << counters[i].hits;
    }
    file << "\n";
}
