#include <GameClasses/CTerrain.hpp>
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
        uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
        uintptr_t CTerrainVFTable = moduleBase + VFTable::CTerrain;
        auto res = Mem::findPointers(moduleBase + 0x12F5000, CTerrainVFTable, 999);
        DEBUG_OUT(printf("res.size(): %i \n", res.size()));
        for (auto& terrainAddr : res) {
            int magicNumber = * (int *) (terrainAddr + 0x4); // for some reason there are some false hits, but we can check the magic number
            if (magicNumber == 397) {
                CTerrain* x = Make(terrainAddr);
                Terrains->push_back(x);
            }
        }
    }
}