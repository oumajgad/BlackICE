#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <vector>
#include <utils.hpp>
#include <HoiDataStructures.hpp>

namespace CCountry {
    namespace Offsets {
        /**@brief head of the country's list of units, at every level rather than the
                  top one - the shape of an order of battle is not in here*/
        constexpr uintptr_t units_linked_list_first_ptr = 0xBAC;
    }

    extern uintptr_t CountryPtrs[300]; // Array of countries, index = country id

    void traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>& res, uintptr_t nodePtr);
    std::vector<std::pair<std::string, std::string>> getActiveEventModifiers(uintptr_t listNodePtr);
    std::vector<std::pair<std::string, int>> getGeneralModifiers(uintptr_t listNodePtr);
    /**@brief the country's flags, by value: the caller owns nothing*/
    std::vector<std::string> getFlags(uintptr_t nodePtr);
    /**@brief the country's non zero variables, by value*/
    std::vector<HDS::CVariable> getVars(uintptr_t nodePtr);

    /**@brief cached CCountry instance for a tag ("GER"), 0 if the cache has no entry
       @note the cache is filled by cacheCountries() and the CCountry constructor hook*/
    uintptr_t findByTag(const std::string& tag);
}