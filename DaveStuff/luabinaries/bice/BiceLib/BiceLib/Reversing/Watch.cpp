#include <Reversing/Watch.hpp>

#include <GameClasses/CCurrentGameState.hpp>
#include <GameState/GameClock.hpp>
#include <MemScan.hpp>
#include <Overlay.hpp>

#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace {
    const char* SOURCE_FILE = "BiceLibWatch.txt";
    const char* OUTPUT_FILE = "BiceLibWatch.csv";

    const int MAX_FIELDS = 32;

    // CCurrentGameState is 0xDA8 bytes, and refusing an offset past that is the whole
    // reason this cannot read anything it should not: the pointer is the game's and the
    // window is the object.
    const uintptr_t OBJECT_SIZE = 0xDA8;

    struct Field {
        std::string label;
        uintptr_t offset;
        int size;               // 1, 2 or 4
        unsigned int value;     // what it last held
        bool known;             // whether it could be read at all last time
    };

    Field fields[MAX_FIELDS];
    int watched = 0;
    std::string message = "not installed";
    std::string outputPath;

    bool headerWritten = false;
    bool everSampled = false;
    int lastPointer = -1;

    std::string trim(const std::string& text) {
        const size_t first = text.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) {
            return std::string();
        }
        const size_t last = text.find_last_not_of(" \t\r\n");
        return text.substr(first, last - first + 1);
    }

    bool readLine(const std::string& line, Field& out, bool& parsed, std::string& why) {
        parsed = false;
        const std::string text = trim(line);
        if (text.empty() || text[0] == '#') {
            return true;
        }

        const size_t first = text.find(';');
        const size_t second = text.find(';', first + 1);
        if (first == std::string::npos || second == std::string::npos) {
            why = "a line wants three fields: offset ; size ; label";
            return false;
        }

        const std::string offsetText = trim(text.substr(0, first));
        const std::string sizeText = trim(text.substr(first + 1, second - first - 1));
        std::string label = trim(text.substr(second + 1));

        if (label.empty()) {
            why = "a watch needs a label";
            return false;
        }
        for (size_t i = 0; i < label.size(); i++) {
            if (label[i] == ',') {
                label[i] = ' ';      // it becomes a csv heading
            }
        }

        char* end = nullptr;
        const unsigned long offset = strtoul(offsetText.c_str(), &end, 0);
        if (end == offsetText.c_str() || *end != '\0') {
            why = "the first field is not an offset";
            return false;
        }

        end = nullptr;
        const unsigned long size = strtoul(sizeText.c_str(), &end, 0);
        if (end == sizeText.c_str() || *end != '\0'
            || (size != 1 && size != 2 && size != 4)) {
            why = "the size wants to be 1, 2 or 4";
            return false;
        }

        if (offset + size > OBJECT_SIZE) {
            why = "that offset is past the end of CCurrentGameState";
            return false;
        }

        out.label = label;
        out.offset = offset;
        out.size = static_cast<int>(size);
        out.value = 0;
        out.known = false;
        parsed = true;
        return true;
    }
}

bool Reversing::Watch::install() {
    const std::string& directory = Overlay::directory();
    if (directory.empty()) {
        message = "no directory to read the watch file from";
        return false;
    }
    outputPath = directory + OUTPUT_FILE;

    std::ifstream file((directory + SOURCE_FILE).c_str());
    if (!file) {
        message = "no BiceLibWatch.txt, so nothing to watch";
        watched = 0;
        return true;
    }

    std::vector<Field> wanted;
    std::string line;
    int number = 0;
    while (std::getline(file, line)) {
        number++;
        Field field;
        bool parsed = false;
        std::string why;
        if (!readLine(line, field, parsed, why)) {
            std::ostringstream text;
            text << SOURCE_FILE << " line " << number << ": " << why;
            message = text.str();
            return false;
        }
        if (parsed) {
            if (static_cast<int>(wanted.size()) >= MAX_FIELDS) {
                message = "more fields than there is room for";
                return false;
            }
            wanted.push_back(field);
        }
    }

    if (wanted.empty()) {
        message = "BiceLibWatch.txt names no fields";
        watched = 0;
        return true;
    }

    // The game runs the mod's bootstrap once per lua_State and BiceLib holds several, so
    // this is called more than once a session. Starting over would reset everSampled and
    // put a fresh header and a forced row in the file each time, which is exactly what
    // the first in_game run recorded: what survives has to be the state, not the parse.
    bool same = (watched == static_cast<int>(wanted.size()));
    for (int i = 0; same && i < watched; i++) {
        same = fields[i].offset == wanted[i].offset
            && fields[i].size == wanted[i].size
            && fields[i].label == wanted[i].label;
    }
    if (same) {
        std::ostringstream text;
        text << "already watching " << watched << " fields";
        message = text.str();
        return true;
    }

    for (size_t i = 0; i < wanted.size(); i++) {
        fields[i] = wanted[i];
    }
    watched = static_cast<int>(wanted.size());
    headerWritten = false;
    everSampled = false;
    lastPointer = -1;

    std::ostringstream text;
    text << watched << " fields watched";
    message = text.str();
    return true;
}

const char* Reversing::Watch::status() {
    return message.c_str();
}

int Reversing::Watch::count() {
    return watched;
}

void Reversing::Watch::update() {
    if (watched == 0 || outputPath.empty()) {
        return;
    }

    const uintptr_t state = CCurrentGameState::current();
    const int pointer = (state != 0) ? 1 : 0;

    unsigned int sampled[MAX_FIELDS];
    bool got[MAX_FIELDS];
    bool changed = !everSampled || pointer != lastPointer;

    for (int i = 0; i < watched; i++) {
        sampled[i] = 0;
        got[i] = false;
        if (state != 0) {
            const uintptr_t at = state + fields[i].offset;
            if (fields[i].size == 1) {
                unsigned char byte = 0;
                got[i] = Mem::tryRead(at, byte);
                sampled[i] = byte;
            }
            else if (fields[i].size == 2) {
                unsigned short half = 0;
                got[i] = Mem::tryRead(at, half);
                sampled[i] = half;
            }
            else {
                unsigned int word = 0;
                got[i] = Mem::tryRead(at, word);
                sampled[i] = word;
            }
        }
        if (got[i] != fields[i].known || (got[i] && sampled[i] != fields[i].value)) {
            changed = true;
        }
    }

    if (!changed) {
        return;
    }

    for (int i = 0; i < watched; i++) {
        fields[i].value = sampled[i];
        fields[i].known = got[i];
    }
    everSampled = true;
    lastPointer = pointer;

    std::ofstream file(outputPath.c_str(), std::ios::app);
    if (!file) {
        return;
    }

    if (!headerWritten) {
        headerWritten = true;
        file << "tick,day,hour,inplay,pointer";
        for (int i = 0; i < watched; i++) {
            file << "," << fields[i].label;
        }
        file << "\n";
    }

    // The clock is context, not a trigger: it moves constantly, and a change in it must
    // not put a row in the file or there would be one every frame. It is here so that a
    // file of rows all reading tick 0 is recognisable as sampling that never reached a
    // game, rather than as a field that never moved.
    file << GameClock::tick() << "," << GameClock::day() << "," << GameClock::hour()
         << "," << (GameClock::movedInPlay() ? 1 : 0) << "," << pointer;
    for (int i = 0; i < watched; i++) {
        if (got[i]) {
            file << "," << sampled[i];
        }
        else {
            file << ",-";
        }
    }
    file << "\n";
}
