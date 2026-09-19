#include <GameClasses/CLeader.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace CLeader {
    const char* typeName(int type) {
        switch (type) {
            case static_cast<int>(Type::Land): return "land";
            case static_cast<int>(Type::Sea): return "sea";
            case static_cast<int>(Type::Air): return "air";
            default: return "unknown";
        }
    }

    CLeader Make(uintptr_t addr) {
        //DEBUG_OUT(printf("Making %#010x\n", addr));
        CLeader res = CLeader{};
        res._address = addr;
        res.id = *(int*)(addr + Offsets::id);
        res.trait_ll_start = *(uintptr_t*)(addr + Offsets::traits + HDS::ListOffsets::first);
        res.trait_ll_end = *(uintptr_t*)(addr + Offsets::traits + HDS::ListOffsets::last);
        res.number_of_traits = *(int*)(addr + Offsets::traits + HDS::ListOffsets::count);
        res.unit_ptr = *(uintptr_t*)(addr + Offsets::unit_ptr);
        res.country = HDS::readTag(addr + Offsets::country + CCountryTag::Offsets::tag);
        res.country_id = *(int*)(addr + Offsets::country + CCountryTag::Offsets::id);
        res.name = HDS::readString(addr + Offsets::name);
        res.picture = HDS::readString(addr + Offsets::picture);
        res.type = *(int*)(addr + Offsets::type);
        res.rank = *(int*)(addr + Offsets::rank);
        res.skill = *(int*)(addr + Offsets::skill);
        res.max_skill = *(int*)(addr + Offsets::max_skill);
        res.starting_skill = *(int*)(addr + Offsets::starting_skill);
        // One 64-bit read, not two words: see CLeader.hpp. Reading only the low half would
        // hold until a leader parked at skill 10 accrues past 2^31, which the game has no
        // ceiling against.
        res.experience = *(long long*)(addr + Offsets::current_experience);
        res.starting_experience = *(int*)(addr + Offsets::starting_experience);
        res.loyalty = *(int*)(addr + Offsets::loyalty);

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
                HDS::walkList(country + CCountry::Offsets::leaders);
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
        lua_pushstring(L, "country");
        lua_pushstring(L, leader.country.c_str());
        lua_settable(L, -3);
        lua_pushstring(L, "picture");
        lua_pushstring(L, leader.picture.c_str());
        lua_settable(L, -3);
        lua_pushstring(L, "type");
        lua_pushstring(L, typeName(leader.type));
        lua_settable(L, -3);
        lua_pushstring(L, "rank");
        lua_pushinteger(L, leader.rank);
        lua_settable(L, -3);
        lua_pushstring(L, "skill");
        lua_pushinteger(L, leader.skill);
        lua_settable(L, -3);
        lua_pushstring(L, "max_skill");
        lua_pushinteger(L, leader.max_skill);
        lua_settable(L, -3);
        lua_pushstring(L, "starting_skill");
        lua_pushinteger(L, leader.starting_skill);
        lua_settable(L, -3);
        // As a Lua number rather than an integer: the total is 64-bit and a career one can
        // outgrow what lua_pushinteger takes. A double holds it exactly to 2^53, which is
        // far past anything the game can reach.
        lua_pushstring(L, "experience");
        lua_pushnumber(L, static_cast<lua_Number>(leader.experience));
        lua_settable(L, -3);
        lua_pushstring(L, "loyalty");
        lua_pushinteger(L, leader.loyalty);
        lua_settable(L, -3);
        lua_pushstring(L, "number_of_traits");
        lua_pushinteger(L, leader.number_of_traits);
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
