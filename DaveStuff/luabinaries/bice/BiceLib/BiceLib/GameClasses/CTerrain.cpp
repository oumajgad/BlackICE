#include <GameClasses/CTerrain.hpp>
#include <GameClasses/CMap.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace CTerrain {
    CTerrain* Make(uintptr_t addr) {
        CTerrain* res = new CTerrain;
        res->id = *(int*)(addr + Offsets::id);
        res->is_water = *(bool*)(addr + Offsets::is_water);
        res->defence = *(int*)(addr + Offsets::defence);
        res->attack = *(int*)(addr + Offsets::attack);
        res->attrition = *(int*)(addr + Offsets::attrition);
        res->name = HDS::readString(addr + Offsets::name);

        DEBUG_OUT(printf("Made Terrain:\n"));
        DEBUG_OUT(printf("  name: %s \n", res->name.c_str()));
        DEBUG_OUT(printf("  is_water: %d \n", res->is_water));
        DEBUG_OUT(printf("  defence: %i \n", res->defence));
        DEBUG_OUT(printf("  attack: %i \n", res->attack));
        DEBUG_OUT(printf("  attrition: %i \n", res->attrition));
        return res;
    }

    std::vector<CTerrain*>* Terrains = new std::vector<CTerrain*>;
    void CacheTerrains() {
        // The map owns them. Its own loader parses map/terrain.txt and pushes every
        // CTerrain it builds into this vector, so reading it gives exactly the set
        // the game has, in the game's own order - where the index is the terrain id.
        //
        // This used to scan every committed page for the vftable and sift the hits
        // with a magic number, because the scan turned up things that were not
        // terrains. Reading the list needs neither.
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
            uint32_t terrain = 0;
            if (!Mem::tryRead(begin + i * sizeof(uint32_t), terrain) || terrain == 0) {
                continue;
            }
            Terrains->push_back(Make(terrain));
        }
        DEBUG_OUT(printf("CacheTerrains: %i terrains from the map\n",
            static_cast<int>(Terrains->size())));
    }
}
