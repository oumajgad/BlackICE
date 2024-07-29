#include <CasualLibrary.hpp>

namespace CCountry {
    static void traverseFlagsAndVarTreeDepthFirst(Memory::External& external, std::vector<std::uintptr_t>* res, uintptr_t nodePtr) {
        if (nodePtr == 0) {
            return;
        }
        uintptr_t element = external.read<uintptr_t>(nodePtr);
        char character = external.read<char>(nodePtr + 0x4);
        uintptr_t sibling = external.read<uintptr_t>(nodePtr + 0xC);
        uintptr_t child = external.read<uintptr_t>(nodePtr + 0x10);
        //std::cout << "nodePtr: " << Memory::n2hexstr(nodePtr) 
        //    << " char: " << character 
        //    << " element: " << Memory::n2hexstr(element) 
        //    << " sibling: " << Memory::n2hexstr(sibling) 
        //    << " child: " << Memory::n2hexstr(child) << std::endl;
        if (element != 0) {
            //std::cout << "element" << std::endl;
            res->push_back(element);
        }
        if (child != 0) {
            //std::cout << "child" << std::endl;
            traverseFlagsAndVarTreeDepthFirst(external, res, child);
        }
        if (sibling != 0) {
            //std::cout << "sibling " << sibling << std::endl;
            traverseFlagsAndVarTreeDepthFirst(external, res, sibling);
        }
    }

    std::vector<std::string>* getFlags(Memory::External& external, uintptr_t nodePtr) {
        std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;
        traverseFlagsAndVarTreeDepthFirst(external, ptrs, nodePtr);
        //std::cout << "ptrs->size(): " << ptrs->size() << std::endl;
        std::vector<std::string>* res = new std::vector<std::string>;
        for (auto& i : *ptrs) {
            std::string x = external.readStringMaybePtr(i);
            res->push_back(x);
            //std::cout << n2hexstr(i) << " - " << x << std::endl;
        }
        delete ptrs;
        return res;
    }

    struct CVariable
    {
        std::string name;
        int32_t value;
    };
    std::vector<CVariable>* getVars(Memory::External& external, uintptr_t nodePtr) {
        std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;
        traverseFlagsAndVarTreeDepthFirst(external, ptrs, nodePtr);
        //std::cout << "ptrs->size(): " << ptrs->size() << std::endl;
        std::vector<CVariable>* res = new std::vector<CVariable>;
        for (auto& i : *ptrs) {
            CVariable x;
            x.name = external.readStringMaybePtr(i);
            x.value = external.read<int32_t>(i + 0x1C);
            res->push_back(x);
            //std::cout << Memory::n2hexstr(i) << " - " << x.name << " - " << x.value << std::endl;
        }
        delete ptrs;
        return res;
    }
}