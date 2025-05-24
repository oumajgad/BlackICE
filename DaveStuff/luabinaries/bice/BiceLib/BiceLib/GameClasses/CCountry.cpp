#include <GameClasses/CCountry.hpp>
#include <Hooks/Hooks.hpp>


uintptr_t CCountry::CountryPtrs[300];

void CCountry::traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>* res, uintptr_t nodePtr) {
    if (nodePtr == 0) {
        return;
    }
    uintptr_t element = *(uintptr_t*)(nodePtr);
    char character = *(char*)(nodePtr + 0x4);
    uintptr_t parent = *(uintptr_t*)(nodePtr + 0x8);
    uintptr_t sibling = *(uintptr_t*)(nodePtr + 0xC);
    uintptr_t child = *(uintptr_t*)(nodePtr + 0x10);
    //std::cout << "nodePtr: " << Memory::n2hexstr(nodePtr) 
    //    << " char: " << character 
    //    << " element: " << Memory::n2hexstr(element) 
    //    << " parent: " << Memory::n2hexstr(parent) 
    //    << " sibling: " << Memory::n2hexstr(sibling) 
    //    << " child: " << Memory::n2hexstr(child) << std::endl;
    if (parent != 0) {
        //std::cout << "parent" << std::endl;
        CCountry::traverseFlagsAndVarTreeDepthFirst(res, parent);
    }

    if (element != 0) {
        //std::cout << "element" << std::endl;
        res->push_back(element);
    }
    if (child != 0) {
        //std::cout << "child" << std::endl;
        CCountry::traverseFlagsAndVarTreeDepthFirst(res, child);
    }
    if (sibling != 0) {
        //std::cout << "sibling " << sibling << std::endl;
        CCountry::traverseFlagsAndVarTreeDepthFirst(res, sibling);
    }
}

std::vector<std::pair<std::string, std::string>> CCountry::getActiveEventModifiers(uintptr_t countryPtr) {
    std::vector<std::pair<std::string,std::string>> res;
    uintptr_t listNodePtr = *(uintptr_t*)(countryPtr + 0x648);
    while (listNodePtr != 0) {
        HDS::LinkedListNodeSingle* listNode = (HDS::LinkedListNodeSingle*)listNodePtr;

        auto modifierPtr = listNode->data;
        auto staticModifier = *(uintptr_t*)(modifierPtr + 0x8);

        auto name = std::string(utils::getCString((DWORD*)(staticModifier + 0x2c)));

        int expiryDateTick = *(int*)(modifierPtr + 0xC);
        auto expiryDate = utils::gameTickToDate(expiryDateTick);

        res.push_back(std::make_pair(name, expiryDate));

        listNodePtr = listNode->next;
    }
    return res;
}

std::vector<std::string>* CCountry::getFlags(uintptr_t countryPtr) {
    std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;

    uintptr_t flagsOffset = countryPtr + 0x180 + 0x4; // CFlagsVFTable + Flag Tree beginning
    uintptr_t flagsPtr = *(uintptr_t*)(flagsOffset);

    CCountry::traverseFlagsAndVarTreeDepthFirst(ptrs, flagsPtr);
    std::vector<std::string>* res = new std::vector<std::string>;
    for (auto& i : *ptrs) {
        std::string x = std::string(utils::getCString((DWORD*)i));
        res->push_back(x);
    }
    delete ptrs;
    return res;
}

std::vector<HDS::CVariable>* CCountry::getVars(uintptr_t countryPtr) {
    std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;

    uintptr_t varsOffset = countryPtr + 0x1AC + 0x4; // CVariablesVFTable + Vars Tree beginning
    uintptr_t varsPtr = *(uintptr_t*)varsOffset;

    CCountry::traverseFlagsAndVarTreeDepthFirst(ptrs, varsPtr);
    std::vector<HDS::CVariable>* res = new std::vector<HDS::CVariable>;
    for (auto& i : *ptrs) {
        HDS::CVariable x;
        x.name = std::string(utils::getCString((DWORD*)i));
        x.value = *(int32_t*)(i + 0x1C);
        if (x.value != 0) {
            res->push_back(x);
        }
    }
    delete ptrs;
    return res;
}
