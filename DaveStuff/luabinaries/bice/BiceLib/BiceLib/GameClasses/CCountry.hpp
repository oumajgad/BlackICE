#include <cstdint>
#include <string>
#include <utility>
#include <vector>
#include <utils.hpp>
#include <HoiDataStructures.hpp>

namespace CCountry {
    extern uintptr_t CountryPtrs[300]; // Array of countries, index = country id

    void traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>* res, uintptr_t nodePtr);
    std::vector<std::pair<std::string, std::string>> getActiveEventModifiers(uintptr_t listNodePtr);
    std::vector<std::pair<std::string, int>> getGeneralModifiers(uintptr_t listNodePtr);
    std::vector<std::string>* getFlags(uintptr_t nodePtr);
    std::vector<HDS::CVariable>* getVars(uintptr_t nodePtr);

    /**@brief cached CCountry instance for a tag ("GER"), 0 if the cache has no entry
       @note the cache is filled by cacheCountries() and the CCountry constructor hook*/
    uintptr_t findByTag(const std::string& tag);
}