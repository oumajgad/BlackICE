#include <iostream>
#include <intrin.h>
#include <thread>
#include <windows.h>
#include <chrono>
#include <Heapapi.h>
#include <Minwinbase.h>
#include <processthreadsapi.h>

#include <CasualLibrary.hpp>

int DATA_SECTION_START = 0x12F5000;
int HOI3_PID = 23468;

inline const char* const BoolToString(bool b) {
    return b ? "OK" : "Failed";
}

/*
std::string toSignature(std::string &str) {
    std::string res(8 + 3, '0'); // 8 chars + 3 spaces
    int offset = 0;
    for (int i = 0; i < 8; i++) {
        res[i + offset] = str[i];
        if (i == 1 || i == 3 || i == 5) {
            res[i + offset + 1] = ' ';
            offset++;
        }
    }
    return res;
}


template <typename I> std::string n2hexstr(I w, size_t hex_len = sizeof(I) << 1) {
    static const char* digits = "0123456789ABCDEF";
    std::string rc(hex_len, '0');
    for (size_t i = 0, j = (hex_len - 1) * 4; i < hex_len; ++i, j -= 4)
        rc[i] = digits[(w >> j) & 0x0f];
    return rc;
}

std::string ptrToSignature(uintptr_t ptr) {
    std::string x = n2hexstr(_byteswap_ulong(ptr));
    return toSignature(x);
}
*/

void provinces() {
    Memory::External external = Memory::External(HOI3_PID, true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    uintptr_t mapProvinceVFTable = modulePtr.get() + 0x11BEBF8;
    std::cout << Memory::n2hexstr(mapProvinceVFTable) << std::endl;
    std::string mapProvinceSig = Memory::ptrToSignature(mapProvinceVFTable);
    std::cout << mapProvinceSig << std::endl;
    std::vector<uintptr_t>* provs = external.findSignatures(modulePtr.get() + DATA_SECTION_START, mapProvinceSig.c_str(), 4, 14190);
    std::cout << provs->size() << std::endl;
}

static void traverseFlagsAndVarTreeDepthFirst(Memory::External &external, std::vector<std::uintptr_t>* res, uintptr_t nodePtr) {
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
        //std::cout << Memory::n2hexstr(i) << " - " << x << std::endl;
    }
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
        std::cout << Memory::n2hexstr(i) << " - " << x.name << " - " << x.value << std::endl;
    }
    delete ptrs;
    return res;
}

void country() {
    Memory::External external = Memory::External(HOI3_PID, true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    //std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = "GER";
    //std::cout << "searchTag: " << searchTag << std::endl;


    auto ctr = external.findCountryInstance(modulePtr.get() + DATA_SECTION_START, searchTag);
    if (ctr == 0) {
        std::cout << "Country instance not found: " << searchTag << std::endl;
        return;
    }

    uintptr_t varsOffset = ctr + 0x1AC + 0x4; // CVariablesVFTable + Vars Tree beginning
    uintptr_t varsPtr = external.read<uintptr_t>(varsOffset);
    std::cout << "varsPtr: " << Memory::n2hexstr(varsPtr) << std::endl;

    auto vars = getVars(external, varsPtr);
    std::cout << "vars->size(): " << vars->size() << std::endl;
}

int main() {
    /*
    std::cout << "Running tests for PID: " << HOI3_PID << "\n\n";
    auto start1 = std::chrono::high_resolution_clock::now();
    country();
    auto stop1 = std::chrono::high_resolution_clock::now();
    auto duration1 = std::chrono::duration_cast<std::chrono::milliseconds>(stop1 - start1);
    std::cout << "A: " << duration1.count() << std::endl;
    */
    Memory::External external = Memory::External(34436, true);
    Address MODULE_BASE = external.getModule("hoi3_tfh.exe");

    uintptr_t CTraitVFTable = MODULE_BASE + 0x11C7DC0;
    //std::cout << "CTraitVFTable: " << Memory::n2hexstr(CTraitVFTable) << std::endl;
    std::string CTraitVFTableSig = Memory::ptrToSignature(CTraitVFTable);
    //std::cout << "CTraitVFTableSig: " << CTraitVFTableSig << std::endl;
    std::vector<uintptr_t>* traits;
    traits = external.findSignatures(MODULE_BASE + DATA_SECTION_START, CTraitVFTableSig.c_str(), 4, 99999);
    std::cout << "Done: "  << traits->size() << std::endl;


    std::cin.get();
}