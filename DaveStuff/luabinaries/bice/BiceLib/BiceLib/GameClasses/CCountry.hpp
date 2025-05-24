#include <CasualLibrary.hpp>
#include <utils.hpp>
#include <HoiDataStructures.hpp>

namespace CCountry {
    extern uintptr_t CountryPtrs[300]; // Array of countries, index = country id

    void traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>* res, uintptr_t nodePtr);
    std::vector<std::pair<std::string, std::string>> getActiveEventModifiers(uintptr_t listNodePtr);
    std::vector<std::string>* getFlags(uintptr_t nodePtr);
    std::vector<HDS::CVariable>* getVars(uintptr_t nodePtr);
}