#include <GameClasses/CLeader.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <HoiDataStructures.hpp>
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
        res.name = HDS::readString(addr + Offsets::name);

        //DEBUG_OUT(printf("res.id: %d\n", res.id));
        //DEBUG_OUT(printf("Finished %#010x\n", addr));
        return res;
    }

    std::unordered_map<unsigned int, uintptr_t>* leaderCache = new std::unordered_map<unsigned int, uintptr_t>;
    /**
    @brief fills the cache from the countries, which is where the leaders actually are

    Every leader belongs to exactly one country's list, so walking all of them finds
    them all. This used to scan every committed page for the vftable and sift the hits
    with a magic number - `397`, which is the value CLASSES.md records as sitting at
    +0x04 on nearly every object, so it rejected almost nothing.

    Walking is also the more correct set: the scan additionally turns up a leader with
    the null tag `---` that no country owns, built by the file parser rather than
    belonging to a game.
    */
    void CacheLeaders() {
        const std::vector<uintptr_t> countries = CCountry::all();
        for (uintptr_t country : countries) {
            const std::vector<uintptr_t> leaders =
                HDS::walkList(country + CCountry::Offsets::leaders_list_first_ptr);
            for (uintptr_t leaderAddr : leaders) {
                CLeader x = Make(leaderAddr);
                // insert, not assign: where two leaders share an id the first one
                // wins, which is what the old cache did as well.
                leaderCache->insert(std::make_pair(x.id, leaderAddr));
            }
        }
        DEBUG_OUT(printf("CacheLeaders: %d leaders from %d countries\n",
            static_cast<int>(leaderCache->size()), static_cast<int>(countries.size())));
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
        lua_pushstring(L, leader.name.c_str());
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
            const std::string unitName = HDS::readString(leader.unit_ptr + CUnit::Offsets::name);
            lua_pushstring(L, unitName.c_str());
        }
        else {
            lua_pushnil(L);
        }
        lua_settable(L, -3);
    }
}
