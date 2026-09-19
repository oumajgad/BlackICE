#include <GameClasses/GameString.hpp>

#include <HoiDataStructures.hpp>
#include <MemScan.hpp>

#include <cstring>

namespace {
    // `std::string::assign(const char*, size_t)`: thiscall, both arguments pushed,
    // `ret 8`. And the free every string destructor in the executable calls, as
    // `if (capacity > 15) free(pointer)`.
    const uintptr_t STRING_ASSIGN = 0xA160;
    const uintptr_t FREE = 0x795F9B;

    typedef void (__thiscall* AssignFn)(void* self, const char* text, size_t length);
    typedef void (__cdecl* FreeFn)(void* block);

    AssignFn assign = nullptr;
    FreeFn freeBlock = nullptr;
    bool looked = false;

    /**@brief finds the two the long strings need, once*/
    void setUp() {
        if (looked) {
            return;
        }
        looked = true;
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0) {
            return;
        }
        assign = reinterpret_cast<AssignFn>(base + STRING_ASSIGN);
        freeBlock = reinterpret_cast<FreeFn>(base + FREE);
    }
}

// The whole reason the class exists. If this ever fails, every call that hands one to
// the game is reading the length out of the wrong place.
static_assert(sizeof(Game::String) == 24, "a game string is sixteen characters, a length and a capacity");

Game::String::String() {
    data_[0] = 0;
    length_ = 0;
    capacity_ = 15;
}

Game::String::String(const char* text) {
    data_[0] = 0;
    length_ = 0;
    capacity_ = 15;
    set(text);
}

Game::String::~String() {
    clear();
}

const char* Game::String::text() const {
    return capacity_ > 15 ? *reinterpret_cast<const char* const*>(data_) : data_;
}

void Game::String::set(const char* text) {
    clear();
    if (text == nullptr) {
        return;
    }
    const size_t size = strlen(text);
    // Up to fifteen the characters go in the object itself, which is what the game
    // does and what keeps a short string out of the allocator entirely.
    if (size < 16) {
        memcpy(data_, text, size + 1);
        length_ = static_cast<int>(size);
        capacity_ = 15;
        return;
    }
    setUp();
    if (assign != nullptr) {
        assign(this, text, size);
    }
}

void Game::String::clear() {
    if (capacity_ > 15) {
        setUp();
        if (freeBlock != nullptr) {
            freeBlock(*reinterpret_cast<void**>(data_));
        }
    }
    data_[0] = 0;
    length_ = 0;
    capacity_ = 15;
}

const char* Game::rawChars(uintptr_t address) {
    int capacity = 0;
    if (!Mem::tryRead(address + HDS::StringOffsets::capacity, capacity)) {
        return "";
    }
    if (capacity > 15) {
        uintptr_t characters = 0;
        if (!Mem::tryRead(address + HDS::StringOffsets::text, characters) || characters == 0) {
            return "";
        }
        return reinterpret_cast<const char*>(characters);
    }
    return reinterpret_cast<const char*>(address + HDS::StringOffsets::text);
}
