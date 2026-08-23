#include <HoiDataStructures.hpp>

#include <MemScan.hpp>
#include <TextEncoding.hpp>

#include <set>

namespace {
    // A name the game holds is short; anything claiming to be longer than this is a
    // structure we have misread rather than a string.
    const uint32_t MAX_STRING_LENGTH = 512;

    // Past fifteen characters a Hoi3CString holds a pointer instead of the characters.
    const uint32_t INLINE_CAPACITY = 15;
}

std::string HDS::readString(uintptr_t address) {
    if (address == 0) {
        return std::string();
    }

    uint32_t length = 0;
    if (!Mem::tryRead(address + offsetof(Hoi3CString, length), length)
        || length == 0 || length > MAX_STRING_LENGTH) {
        return std::string();
    }

    uintptr_t characters = address;
    if (length > INLINE_CAPACITY) {
        uint32_t pointer = 0;
        if (!Mem::tryRead(address, pointer) || pointer == 0) {
            return std::string();
        }
        characters = pointer;
    }

    std::string text(length, '\0');
    if (!Mem::tryReadBytes(characters, &text[0], length)) {
        return std::string();
    }

    // The game is not always tidy about what follows the length.
    const size_t terminator = text.find('\0');
    if (terminator != std::string::npos) {
        text.resize(terminator);
    }
    return Text::toUtf8(text);
}

std::string HDS::readChars(uintptr_t address, size_t size) {
    if (address == 0 || size == 0 || size > MAX_STRING_LENGTH) {
        return std::string();
    }

    std::string text(size, '\0');
    if (!Mem::tryReadBytes(address, &text[0], size)) {
        return std::string();
    }

    const size_t terminator = text.find('\0');
    if (terminator != std::string::npos) {
        text.resize(terminator);
    }
    return Text::toUtf8(text);
}

std::string HDS::readTag(uintptr_t address) {
    // Three characters and the NUL that follows them.
    return readChars(address, 4);
}

std::vector<uintptr_t> HDS::walkList(uintptr_t listField, int maxSteps) {
    std::vector<uintptr_t> found;

    uint32_t node = 0;
    if (!Mem::tryRead(listField, node)) {
        return found;
    }

    std::set<uintptr_t> visited;
    int steps = 0;
    while (node != 0 && steps < maxSteps) {
        steps++;
        if (!visited.insert(node).second) {
            break; // been here before: the list loops
        }

        uint32_t data = 0;
        if (Mem::tryRead(node + NodeOffsets::data, data) && data != 0) {
            found.push_back(data);
        }

        uint32_t next = 0;
        if (!Mem::tryRead(node + NodeOffsets::next, next)) {
            break;
        }
        node = next;
    }
    return found;
}
