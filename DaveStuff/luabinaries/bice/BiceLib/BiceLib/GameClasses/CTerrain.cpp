#include <GameClasses/CTerrain.hpp>
#include <GameClasses/CMap.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace CTerrain {
    std::vector<CTerrain> Terrains;

    CTerrain Make(uintptr_t addr) {
        CTerrain res;
        res.id = Mem::readOr<int32_t>(addr + Offsets::id);
        res.is_water = Mem::readOr<uint8_t>(addr + Offsets::is_water) != 0;
        res.defence = Mem::readOr<int32_t>(addr + Offsets::defence);
        res.attack = Mem::readOr<int32_t>(addr + Offsets::attack);
        res.attrition = Mem::readOr<int32_t>(addr + Offsets::attrition);
        res.name = HDS::readString(addr + Offsets::name);
        return res;
    }

    void CacheTerrains() {
        if (!Terrains.empty()) {
            return;
        }

        // The map owns them. Its own loader parses map/terrain.txt and pushes every
        // CTerrain it builds into this vector, so reading it gives exactly the set the
        // game has, in the game's own order - where the index is the terrain id.
        const uintptr_t map = CMap::current();
        if (map == 0) {
            DEBUG_OUT(printf("CacheTerrains: no map loaded\n"));
            return;
        }

        uint32_t begin = 0;
        uint32_t end = 0;
        if (!Mem::tryRead(map + CMap::Offsets::terrains_begin, begin)
            || !Mem::tryRead(map + CMap::Offsets::terrains_end, end)
            || begin == 0 || end < begin) {
            DEBUG_OUT(printf("CacheTerrains: the terrain list is not readable\n"));
            return;
        }

        const size_t count = (end - begin) / sizeof(uint32_t);
        if (count == 0 || count > MAX_TERRAINS) {
            DEBUG_OUT(printf("CacheTerrains: %i is not a sane terrain count\n",
                static_cast<int>(count)));
            return;
        }

        for (size_t i = 0; i < count; i++) {
            const uintptr_t terrain = Mem::readOr<uint32_t>(begin + i * sizeof(uint32_t));
            if (terrain != 0) {
                Terrains.push_back(Make(terrain));
            }
        }
        DEBUG_OUT(printf("CacheTerrains: %i terrains from the map\n",
            static_cast<int>(Terrains.size())));
    }
}
