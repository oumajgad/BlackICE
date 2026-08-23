#include <GameClasses/CLeader.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace CLeader {
    CLeader Make(uintptr_t addr) {
        //DEBUG_OUT(printf("Making %#010x\n", addr));
        CLeader res = CLeader{};
        res._address = addr;
        res.id = *(int*)(addr + Offsets::id);
        res.trait_ll_start = *(uintptr_t*)(addr + Offsets::trait_ll_start);
        res.trait_ll_end = *(uintptr_t*)(addr + Offsets::trait_ll_end);
        res.number_of_traits = *(int*)(addr + Offsets::number_of_traits);
        res.unit_ptr = *(uintptr_t*)(addr + Offsets::unit_ptr);
        res.rank = *(int*)(addr + Offsets::rank);
        res.skill = *(int*)(addr + Offsets::skill);
        res.experience = *(int*)(addr + Offsets::experience);
        res.name = utils::getCString((DWORD*)(addr + Offsets::name));
        //res.name = (char*) "Test";

        //DEBUG_OUT(printf("res.id: %d\n", res.id));
        //DEBUG_OUT(printf("Finished %#010x\n", addr));
        return res;
    }

    std::unordered_map<unsigned int, uintptr_t>* leaderCache = new std::unordered_map<unsigned int, uintptr_t>;
    void CacheLeaders() {
        uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
        uintptr_t CLeaderVFTable = moduleBase + 0x11C5220;
        auto res = Mem::findPointers(moduleBase + 0x12F5000, CLeaderVFTable, 99999);
        for (auto& leaderAddr : res) {
            int magicNumber = *(int*)(leaderAddr + 0x4); // for some reason there are some false hits, but we can check the magic number
            if (magicNumber == 397) {
                CLeader x = Make(leaderAddr);
                leaderCache->insert(std::make_pair(x.id, leaderAddr));
            }
        }
        return;
    }

    CLeader GetLeaderById(unsigned int id) {
        if (leaderCache->size() == 0) {
            CacheLeaders();
            DEBUG_OUT(printf("leaderCache->size(): %d\n", leaderCache->size()));
        }
        if (leaderCache->find(id) != leaderCache->end()) {
            CLeader x = Make(leaderCache->at(id));
            DEBUG_OUT(printf("Found Leader\n"));
            return x;
        }

        DEBUG_OUT(printf("Did not find leader with id: %d\n", id));
        return CLeader{};
    }

    void PushCLeaderToStack(lua_State* L, CLeader leader) {
        DEBUG_OUT(printf("leader.id: %i \n", leader.id));
        lua_newtable(L);
        lua_pushstring(L, "id");
        lua_pushinteger(L, leader.id);
        lua_settable(L, -3);
        lua_pushstring(L, "name");
        lua_pushstring(L, leader.name);
        lua_settable(L, -3);

        lua_pushstring(L, "province_id");
        if (leader.unit_ptr != 0) {
            uintptr_t currentProvincePtr = *(uintptr_t*)(leader.unit_ptr + CUnit::Offsets::current_province_ptr);
            if (currentProvincePtr != 0) {
                auto currentProvince = CMapProvince::Make(currentProvincePtr);
                lua_pushinteger(L, currentProvince.id);
            }
            else {
                lua_pushnil(L);
            }
        }
        else {
            lua_pushnil(L);
        }
        lua_settable(L, -3);

        lua_pushstring(L, "unit_name");
        if (leader.unit_ptr != 0) {
            char* unit_name = utils::getCString((DWORD*)(leader.unit_ptr + CUnit::Offsets::name));
            lua_pushstring(L, unit_name);
        }
        else {
            lua_pushnil(L);
        }
        lua_settable(L, -3);
    }
}
