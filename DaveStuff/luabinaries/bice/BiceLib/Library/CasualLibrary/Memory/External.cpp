#include "External.hpp"
#include <Sysinfoapi.h>

Memory::External::External(int procID, const bool debug) noexcept {
    if (!init(procID)) {
        std::cerr << "Could not init Memory object.\n";
        std::cerr << getLastErrorAsString() << std::endl;
    }
    else if (!Helper::matchingBuilt(this->handle)) {
        std::cerr << "x64/x86-bit missmatch! Make sure to match the target." << std::endl;
    };
    this->debug = debug;
}

Memory::External::~External(void) noexcept {
    CloseHandle(handle);
}

[[nodiscard]] std::string Memory::External::readString(const uintptr_t addToBeRead, std::size_t size) noexcept {
    bool oneWord = size == 0;

    if (oneWord)
        size = 200;

    std::vector<char> chars(size);

    if (!ReadProcessMemory(handle, reinterpret_cast<LPBYTE*>(addToBeRead), chars.data(), size, NULL) && debug) {
        std::cout << getLastErrorAsString() << std::endl;
    };

    std::string name(chars.begin(), chars.end());

    if (oneWord)
        return name.substr(0, name.find('\0'));

    return name;
}

bool Memory::External::init(int procID, const DWORD access) noexcept {
    this->processID = procID;
    this->handle = OpenProcess(access, false, this->processID);
    if (!this->handle && debug) {
        std::cout << getLastErrorAsString() << std::endl;
    }

    return this->handle != NULL;
}

[[nodiscard]] DWORD Memory::External::getProcessID(void) noexcept {
    return this->processID;
}

[[nodiscard]] Address Memory::External::getModule(const char* modName) noexcept {
    HANDLE hModule = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, this->processID);
    MODULEENTRY32 mEntry;
    mEntry.dwSize = sizeof(mEntry);

    do {
        if (!strcmp(modName, static_cast<char*> (mEntry.szModule))) {
            CloseHandle(hModule);
            return reinterpret_cast<uintptr_t>(mEntry.hModule);
        }
    } while (Module32Next(hModule, &mEntry));
    return nullptr;
}

[[nodiscard]] Address Memory::External::getAddress(uintptr_t addr, const std::vector<uintptr_t>& vect) noexcept {
    for (size_t i = 0; i < vect.size(); i++) {
        if (!ReadProcessMemory(handle, reinterpret_cast<BYTE*>(addr), &addr, sizeof(addr), 0) && debug) {
            std::cout << getLastErrorAsString() << std::endl;
        }
        addr += vect[i];
    }
    return addr;
}

[[nodiscard]] Address Memory::External::getAddress(const Address& addr, const std::vector<uintptr_t>& vect) noexcept {
    return getAddress(addr.get(), vect);
}

[[nodiscard]] bool Memory::External::memoryCompare(const BYTE* bData, const std::vector<int>& signature) noexcept {
    for (size_t i = 0; i < signature.size(); i++) {
        if (signature[i] != -1 && signature[i] != bData[i])
            break;
        if (i + 1 == signature.size())
            return true;
    }
    return false;
}

[[nodiscard]] Address Memory::External::findSignature(const uintptr_t start, const char* signature, const size_t size) noexcept {
    std::vector<int> patternBytes = patternToBytes(signature);
    BYTE* data = new BYTE[size];

    if (!ReadProcessMemory(handle, reinterpret_cast<LPVOID>(start), data, size, nullptr) && debug) {
        std::cout << getLastErrorAsString() << std::endl;
    }

    for (std::size_t i = 0; i < size; ++i) {
        if (memoryCompare(static_cast<const BYTE*>(data + i), patternBytes)) {
            delete[] data;
            return start + i;
        }
    }

    delete[] data;

    return nullptr;
}

[[nodiscard]] Address Memory::External::findSignature(const Address& start, const char* sig, const size_t size) noexcept {
    return findSignature(start.get(), sig, size);
}


template <typename I> std::string n2hexstr(I w, size_t hex_len = sizeof(I) << 1) {
    static const char* digits = "0123456789ABCDEF";
    std::string rc(hex_len, '0');
    for (size_t i = 0, j = (hex_len - 1) * 4; i < hex_len; ++i, j -= 4)
        rc[i] = digits[(w >> j) & 0x0f];
    return rc;
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
            x.start = (uintptr_t)info.BaseAddress;
            x.size = info.RegionSize;
            //std::cout << x.start << " - " << x.size << std::endl;
            mappedRegions->push_back(x);
        }
    }
    std::cout << mappedRegions->size() << std::endl;
    return mappedRegions;
}


[[nodiscard]] std::vector<uintptr_t>* Memory::External::findSignatures(const uintptr_t start, const char* signature, size_t signature_size, int expected_results) noexcept {
    //size_t chunk_size = 1024 * 1024; // read 1 MibiByte chunks
    size_t chunk_size = 1024;

    //SYSTEM_INFO sys_info;
    //GetSystemInfo(&sys_info);
    //size_t chunk_size = sys_info.dwPageSize;
    std::cout << "chunk_size: " << chunk_size << std::endl;
    //std::vector<uintptr_t> results(1024 * 1024/4); // 1MiBi in size, space for 260k pointers

    std::vector<uintptr_t>* results = new std::vector<uintptr_t>;
    results->reserve(expected_results);

    std::vector<int>patternBytes = patternToBytes(signature);
    BYTE* data = new BYTE[chunk_size];

    auto regions = heapWalkExternal(this->handle);

    for (uintptr_t cur = start; cur < 0xffffffff - chunk_size - signature_size; cur += chunk_size - signature_size) {
        //std::cout << "Read at: " << cur << std::endl;
        if (!ReadProcessMemory(handle, reinterpret_cast<LPVOID>(cur), data, chunk_size, nullptr)) {
            if (debug) {
                std::cout << getLastErrorAsString() << std::endl;
            }
            continue;
        }

        for (uintptr_t i = 0; i < chunk_size - signature_size; ++i) {
            //std::cout << "Check at: " << cur + i << std::endl;
            if (memoryCompare(static_cast<const BYTE*>(data + i), patternBytes)) {
                results->push_back(cur + i);
                //std::cout << "Found at: " << n2hexstr(cur + i) << " " << results->size() << std::endl;
                std::cout << n2hexstr(cur + i) << std::endl;
            }
        }
        if (results->size() >= expected_results) {
            std::cout << "Early exit!" << std::endl;
            delete[] data;
            return results;
        }
    }

    return results;
}
