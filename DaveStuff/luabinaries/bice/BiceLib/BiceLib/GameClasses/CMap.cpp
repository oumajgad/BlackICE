#include <GameClasses/CMap.hpp>

#include <MemScan.hpp>

uintptr_t CMap::current() {
    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        return 0;
    }

    uint32_t map = 0;
    if (!Mem::tryRead(base + GLOBAL_POINTER, map) || map == 0) {
        return 0;
    }

    // The global holds whatever was there before a map is loaded, so the vftable is
    // what says this is really a CMap.
    uint32_t vftable = 0;
    if (!Mem::tryRead(map, vftable) || vftable != base + VFTable::CMap) {
        return 0;
    }
    return map;
}
