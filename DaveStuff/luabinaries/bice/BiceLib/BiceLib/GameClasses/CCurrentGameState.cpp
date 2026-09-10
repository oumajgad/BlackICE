#include <GameClasses/CCurrentGameState.hpp>

#include <MemScan.hpp>

uintptr_t CCurrentGameState::current() {
    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        return 0;
    }
    uint32_t state = 0;
    if (!Mem::tryRead(base + GLOBAL_POINTER, state)) {
        return 0;
    }
    return state;
}

namespace {
    // Far past any map, so a count above it means the vector did not read as one rather
    // than that the map is enormous. The game's own map has 14190.
    const int MAX_SANE_PROVINCES = 100000;
}

int CCurrentGameState::provinceCount() {
    const uintptr_t state = current();
    if (state == 0) {
        return 0;
    }
    uint32_t begin = 0;
    uint32_t end = 0;
    if (!Mem::tryRead(state + Offsets::provinces_begin, begin)
        || !Mem::tryRead(state + Offsets::provinces_end, end)
        || begin == 0 || end < begin) {
        return 0;
    }
    const uint32_t count = (end - begin) / 4;
    return (count > static_cast<uint32_t>(MAX_SANE_PROVINCES)) ? 0 : static_cast<int>(count);
}

uintptr_t CCurrentGameState::province(int id) {
    if (id < 0 || id >= provinceCount()) {
        return 0;
    }
    uint32_t begin = 0;
    uint32_t entry = 0;
    if (!Mem::tryRead(current() + Offsets::provinces_begin, begin)
        || !Mem::tryRead(begin + static_cast<uint32_t>(id) * 4, entry)) {
        return 0;
    }
    return entry;
}

int CCurrentGameState::currentTick() {
    const uintptr_t state = current();
    if (state == 0) {
        return 0;
    }
    int32_t tick = 0;
    if (!Mem::tryRead(state + Offsets::tick, tick)) {
        return 0;
    }
    return tick;
}
