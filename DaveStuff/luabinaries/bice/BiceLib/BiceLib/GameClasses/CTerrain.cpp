#include <GameClasses/CTerrain.hpp>
#include <utils.hpp>

namespace CTerrain {
    namespace Offsets {
        uintptr_t id = 0x8;
        uintptr_t name = 0x28;
        uintptr_t is_water = 0x48;
        uintptr_t defence = 0x4C;
        uintptr_t attack = 0x50;
        uintptr_t attrition = 0x5C;
    }

    CTerrain* Make(uintptr_t addr) {
        CTerrain* res = new CTerrain;
        res->id = *(int*)(addr + Offsets::id);
        res->is_water = (bool) *(int*)(addr + Offsets::is_water);
        res->defence = *(int*)(addr + Offsets::defence);
        res->attack = *(int*)(addr + Offsets::attack);
        res->attrition = *(int*)(addr + Offsets::attrition);
        res->name = utils::getCString((DWORD*)(addr + Offsets::name));
        return res;
    }

    std::vector<CTerrain*>* Terrains = new std::vector<CTerrain*>;
    void CacheTerrains(Memory::External& external) {
        Address modulePtr = external.getModule("hoi3_tfh.exe");
        uintptr_t moduleBase = modulePtr.get();
        uintptr_t CTerrainVFTable = moduleBase + 0x11C0764;
        std::string sig = Memory::ptrToSignature(CTerrainVFTable);
        auto res = external.findSignatures(moduleBase + 0x12F5000, sig.c_str(), 4, 999);
        DEBUG_OUT(printf("res->size(): %i \n", res->size()));
        if (res->size() != 0) {
            for (int i = 0; i < res->size(); i++) {
                int magicNumber = * (int *) (res->at(i) + 0x4); // for some reason there are some false hits, but we can check the magic number
                if (magicNumber == 397) {
                    CTerrain* x = Make(res->at(i));
                    Terrains->push_back(x);
                }
            }
            delete res;
        }
    }
}