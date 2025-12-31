#include <GameClasses/CLeader.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <utils.hpp>

namespace CLeader {
    namespace Offsets {
        uintptr_t id = 0xC;
        uintptr_t trait_ll_start = 0x30;
        uintptr_t trait_ll_end = 0x34;
        uintptr_t number_of_traits = 0x38;
        uintptr_t unit_ptr = 0x40;
        // uintptr_t country_tag = 0x44;
        // uintptr_t country_id = 0x48;
        uintptr_t name = 0x4C;
        // uintptr_t type = 0x68;
        uintptr_t rank = 0x6C;
        uintptr_t skill = 0x70;
        uintptr_t max_skill = 0x74;
        uintptr_t experience = 0x78;
        // uintptr_t experience_2 = 0x7C;
        // uintptr_t loyalty = 0x80;
        // uintptr_t CLeaderHistoryOffset = 0x84;
    }

    CLeader Make(uintptr_t addr) {
        //DEBUG_OUT(printf("Making %#010x\n", addr));
        CLeader res = CLeader{};
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
    void CacheLeaders(Memory::External& external) {
        Address modulePtr = external.getModule("hoi3_tfh.exe");
        uintptr_t moduleBase = modulePtr.get();
        uintptr_t CLeaderVFTable = moduleBase + 0x11C5220;
        std::string sig = Memory::ptrToSignature(CLeaderVFTable);
        auto res = external.findSignatures(moduleBase + 0x12F5000, sig.c_str(), 4, 99999);
        if (res->size() != 0) {
            for (int i = 0; i < res->size(); i++) {
                int magicNumber = *(int*)(res->at(i) + 0x4); // for some reason there are some false hits, but we can check the magic number
                if (magicNumber == 397) {
                    CLeader x = Make(res->at(i));
                    leaderCache->insert(std::make_pair(x.id, res->at(i)));
                }
            }
            delete res;
        }
        return;
    }

    CLeader GetLeaderById(Memory::External& external, unsigned int id) {
        if (leaderCache->size() == 0) {
            CacheLeaders(external);
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
    }
}
