#include <CCountry.hpp>
#include <Hooks/Hooks.hpp>

void CCountry::traverseFlagsAndVarTreeDepthFirst(Memory::External& external, std::vector<std::uintptr_t>* res, uintptr_t nodePtr) {
    if (nodePtr == 0) {
        return;
    }
    uintptr_t element = external.read<uintptr_t>(nodePtr);
    char character = external.read<char>(nodePtr + 0x4);
    uintptr_t parent = external.read<uintptr_t>(nodePtr + 0x8);
    uintptr_t sibling = external.read<uintptr_t>(nodePtr + 0xC);
    uintptr_t child = external.read<uintptr_t>(nodePtr + 0x10);
    //std::cout << "nodePtr: " << Memory::n2hexstr(nodePtr) 
    //    << " char: " << character 
    //    << " element: " << Memory::n2hexstr(element) 
    //    << " parent: " << Memory::n2hexstr(parent) 
    //    << " sibling: " << Memory::n2hexstr(sibling) 
    //    << " child: " << Memory::n2hexstr(child) << std::endl;
    if (parent != 0) {
        //std::cout << "parent" << std::endl;
        CCountry::traverseFlagsAndVarTreeDepthFirst(external, res, parent);
    }

    if (element != 0) {
        //std::cout << "element" << std::endl;
        res->push_back(element);
    }
    if (child != 0) {
        //std::cout << "child" << std::endl;
        CCountry::traverseFlagsAndVarTreeDepthFirst(external, res, child);
    }
    if (sibling != 0) {
        //std::cout << "sibling " << sibling << std::endl;
        CCountry::traverseFlagsAndVarTreeDepthFirst(external, res, sibling);
    }
}

std::vector<std::pair<std::string, std::string>> CCountry::getActiveEventModifiers(Memory::External& external, uintptr_t listNodePtr) {
    std::vector<std::pair<std::string,std::string>> res;
    while (listNodePtr != 0) {
        HDS::LinkedListNodeSingle* listNode = (HDS::LinkedListNodeSingle*)listNodePtr;

        auto modifierPtr = listNode->data;
        auto staticModifier = external.read<uintptr_t>(modifierPtr + 0x8);

        auto name = std::string(utils::getCString((DWORD*)(staticModifier + 0x2c)));

        int expiryDateTick = external.read<int>(modifierPtr + 0xC);
        auto expiryDate = utils::gameTickToDate(expiryDateTick);

        res.push_back(std::make_pair(name, expiryDate));

        listNodePtr = listNode->next;
    }
    return res;
}

std::vector<std::string>* CCountry::getFlags(Memory::External& external, uintptr_t nodePtr) {
    std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;
    CCountry::traverseFlagsAndVarTreeDepthFirst(external, ptrs, nodePtr);
    //std::cout << "ptrs->size(): " << ptrs->size() << std::endl;
    std::vector<std::string>* res = new std::vector<std::string>;
    for (auto& i : *ptrs) {
        std::string x = std::string(utils::getCString((DWORD*)i));
        res->push_back(x);
        //std::cout << n2hexstr(i) << " - " << x << std::endl;
    }
    delete ptrs;
    return res;
}

std::vector<HDS::CVariable>* CCountry::getVars(Memory::External& external, uintptr_t nodePtr) {
    std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;
    CCountry::traverseFlagsAndVarTreeDepthFirst(external, ptrs, nodePtr);
    //std::cout << "ptrs->size(): " << ptrs->size() << std::endl;
    std::vector<HDS::CVariable>* res = new std::vector<HDS::CVariable>;
    for (auto& i : *ptrs) {
        HDS::CVariable x;
        x.name = std::string(utils::getCString((DWORD*)i));
        x.value = external.read<int32_t>(i + 0x1C);
        if (x.value != 0) {
            res->push_back(x);
            //std::cout << Memory::n2hexstr(i) << " - " << x.name << " - " << x.value << std::endl;
        }
    }
    delete ptrs;
    return res;
}
