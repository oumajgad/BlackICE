#include <iostream>
#include <intrin.h>
#include <thread>
#include <windows.h>
#include <chrono>
#include <Heapapi.h>
#include <Minwinbase.h>

#include <CasualLibrary.hpp>
#include <processthreadsapi.h>

int DATA_SECTION_START = 0x12F5000;

inline const char* const BoolToString(bool b) {
    return b ? "OK" : "Failed";
}

template <typename I> std::string n2hexstr(I w, size_t hex_len = sizeof(I) << 1) {
    static const char* digits = "0123456789ABCDEF";
    std::string rc(hex_len, '0');
    for (size_t i = 0, j = (hex_len - 1) * 4; i < hex_len; ++i, j -= 4)
        rc[i] = digits[(w >> j) & 0x0f];
    return rc;
}

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

std::string ptrToSignature(uintptr_t ptr) {
    std::string x = n2hexstr(_byteswap_ulong(ptr));
    return toSignature(x);
}

void heapWalkInternal() {
    PROCESS_HEAP_ENTRY heapEntry;
    heapEntry.lpData = NULL;
    while (HeapWalk(GetProcessHeap(), &heapEntry) != FALSE) {
        if ((heapEntry.wFlags & PROCESS_HEAP_ENTRY_BUSY) != 0) {
            std::cout << "Allocated block" << std::endl;
        }
        else if ((heapEntry.wFlags & PROCESS_HEAP_REGION) != 0) {
            std::cout << "heapEntry.Region.dwCommittedSize " << heapEntry.Region.dwCommittedSize << std::endl;
            std::cout << "heapEntry.Region.dwUnCommittedSize " << heapEntry.Region.dwUnCommittedSize << std::endl;
            std::cout << "heapEntry.Region.lpFirstBlock " << heapEntry.Region.lpFirstBlock << std::endl;
            std::cout << "heapEntry.Region.lpLastBlock " << heapEntry.Region.lpLastBlock << std::endl;
        }
        else if ((heapEntry.wFlags & PROCESS_HEAP_UNCOMMITTED_RANGE) != 0) {
            std::cout << "Uncommitted range" << std::endl;
        }
        std::cout << "heapEntry.lpData " << heapEntry.lpData << std::endl;
        std::cout << "heapEntry.cbData " << heapEntry.cbData << std::endl;
        std::cout << "heapEntry.iRegionIndex " << heapEntry.iRegionIndex << std::endl;

        DWORD lastError = GetLastError();
        if (lastError != ERROR_NO_MORE_ITEMS && lastError != 0) {
            std::cout << "HeapWalk failed with LastError: " << lastError << std::endl;
        }
    }
}
struct MemoryRegion
{
    uintptr_t start;
    size_t size;
};

std::vector<MemoryRegion>* heapWalkExternal(HANDLE process) {
    unsigned long usage = 0;
    unsigned char* p = NULL;
    MEMORY_BASIC_INFORMATION info;
    std::vector<MemoryRegion>* mappedRegions = new std::vector<MemoryRegion>;

    for (p = NULL;
        VirtualQueryEx(process, p, &info, sizeof(info)) == sizeof(info);
        p += info.RegionSize)
    {

        if (info.State & MEM_COMMIT && info.Type & MEM_PRIVATE) {
            MemoryRegion x;
            x.start = (uintptr_t) info.BaseAddress;
            x.size = info.RegionSize;
            //std::cout << x.start << " - " << x.size << std::endl;
            mappedRegions->push_back(x);
        }
    }
    std::cout << mappedRegions->size() << std::endl;
    return mappedRegions;
}

int main() {
    std::cout << "Running tests ...\n\n";

    Memory::External external = Memory::External(4204, false);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << "modulePtr: " << n2hexstr(modulePtr.get()) << std::endl;

    heapWalkExternal(external.handle);

    /*
    uintptr_t mapProvinceVFTable = modulePtr.get() + 0x11BEBF8;
    std::cout << mapProvinceVFTable << std::endl;
    std::string mapProvinceSig = ptrToSignature(mapProvinceVFTable);
    std::cout << mapProvinceSig << std::endl;
    std::vector<uintptr_t>* provs = external.findSignatures(modulePtr.get() + DATA_SECTION_START, mapProvinceSig.c_str(), 4, 14190);
    std::cout << provs->size() << std::endl;
    */

    // std::cin.get();
}