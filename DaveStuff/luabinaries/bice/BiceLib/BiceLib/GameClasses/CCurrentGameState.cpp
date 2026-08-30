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
