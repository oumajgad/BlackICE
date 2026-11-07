#include <GameClasses/CLeader.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameState/GameClock.hpp>
#include <Hooks/Hooks.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <unordered_map>

namespace {
    // id -> leader, and the session it was filled in. See GetLeaderById in the header.
    std::unordered_map<unsigned int, uintptr_t> cache;
    int cacheSession = -1;

    void rebuild() {
        cache.clear();
        cacheSession = GameClock::session();
        for (uintptr_t leader : CLeader::all()) {
            // insert, not assign: where two leaders share an id the first one wins
            cache.insert(std::make_pair(
                Mem::readOr<uint32_t>(leader + CLeader::Offsets::id), leader));
        }
        DEBUG_OUT(printf("CLeader cache: %d leaders, session %d\n",
            static_cast<int>(cache.size()), cacheSession));
    }

    /**@brief whether \p leader still reads as a CLeader with that id*/
    bool stillThere(uintptr_t leader, unsigned int id) {
        const uintptr_t vftable = Hooks::MODULE_BASE + CLeader::VFTable::CLeader;
        return Mem::readOr<uint32_t>(leader) == vftable
            && Mem::readOr<uint32_t>(leader + CLeader::Offsets::id) == id;
    }

    /**@brief the cached leader with that id, or 0 - after the hit has been checked*/
    uintptr_t lookUp(unsigned int id) {
        const auto found = cache.find(id);
        if (found == cache.end()) {
            return 0;
        }
        return stillThere(found->second, id) ? found->second : 0;
    }
}

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
        CLeader res = CLeader{};
        res._address = addr;
        res.id = Mem::readOr<uint32_t>(addr + Offsets::id);
        res.trait_ll_start = Mem::readOr<uint32_t>(addr + Offsets::traits + HDS::ListOffsets::first);
        res.trait_ll_end = Mem::readOr<uint32_t>(addr + Offsets::traits + HDS::ListOffsets::last);
        res.number_of_traits = Mem::readOr<int32_t>(addr + Offsets::traits + HDS::ListOffsets::count);
        res.unit_ptr = Mem::readOr<uint32_t>(addr + Offsets::unit_ptr);
        res.country = HDS::readTag(addr + Offsets::country + CCountryTag::Offsets::tag);
        res.country_id = Mem::readOr<int32_t>(addr + Offsets::country + CCountryTag::Offsets::id);
        res.name = HDS::readString(addr + Offsets::name);
        res.picture = HDS::readString(addr + Offsets::picture);
        res.type = Mem::readOr<int32_t>(addr + Offsets::type);
        res.rank = Mem::readOr<int32_t>(addr + Offsets::rank);
        res.skill = Mem::readOr<int32_t>(addr + Offsets::skill);
        res.max_skill = Mem::readOr<int32_t>(addr + Offsets::max_skill);
        res.starting_skill = Mem::readOr<int32_t>(addr + Offsets::starting_skill);
        // One 64-bit read, not two words: see CLeader.hpp. Reading only the low half would
        // hold until a leader parked at skill 10 accrues past 2^31, which the game has no
        // ceiling against.
        res.experience = Mem::readOr<long long>(addr + Offsets::current_experience);
        res.starting_experience = Mem::readOr<int32_t>(addr + Offsets::starting_experience);
        res.loyalty = Mem::readOr<int32_t>(addr + Offsets::loyalty);
        return res;
    }

    std::vector<uintptr_t> all() {
        std::vector<uintptr_t> leaders;
        for (uintptr_t country : CCountry::all()) {
            const std::vector<uintptr_t> own = HDS::walkList(country + CCountry::Offsets::leaders);
            leaders.insert(leaders.end(), own.begin(), own.end());
        }
        return leaders;
    }

    CLeader GetLeaderById(unsigned int id) {
        if (cacheSession != GameClock::session() || cache.empty()) {
            rebuild();
        }
        uintptr_t leader = lookUp(id);
        if (leader == 0 && cache.count(id) != 0) {
            // In the cache and no longer there: a load the clock has not seen yet
            rebuild();
            leader = lookUp(id);
        }
        if (leader == 0) {
            DEBUG_OUT(printf("Did not find leader with id: %u\n", id));
            return CLeader{};
        }
        return Make(leader);
    }

    void PushCLeaderToStack(lua_State* L, CLeader leader) {
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

        const uintptr_t province = (leader.unit_ptr != 0)
            ? Mem::readOr<uint32_t>(leader.unit_ptr + CUnit::Offsets::current_province_ptr) : 0;
        lua_pushstring(L, "province_id");
        if (province != 0) {
            lua_pushinteger(L, CMapProvince::Make(province).id);
        }
        else {
            lua_pushnil(L);
        }
        lua_settable(L, -3);

        lua_pushstring(L, "unit_name");
        if (leader.unit_ptr != 0) {
            lua_pushstring(L, HDS::readString(leader.unit_ptr + CUnit::Offsets::name).c_str());
        }
        else {
            lua_pushnil(L);
        }
        lua_settable(L, -3);
    }
}
