#include "External.hpp"
#include <Sysinfoapi.h>
#include <functional>


template <typename I> std::string Memory::n2hexstr(I w, size_t hex_len) {
    static const char* digits = "0123456789ABCDEF";
    std::string rc(hex_len, '0');
    for (size_t i = 0, j = (hex_len - 1) * 4; i < hex_len; ++i, j -= 4)
        rc[i] = digits[(w >> j) & 0x0f];
    return rc;
}
std::string Memory::toSignature(std::string& str) {
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
std::string Memory::ptrToSignature(uintptr_t ptr) {
    std::string x = Memory::n2hexstr(_byteswap_ulong(ptr));
    return Memory::toSignature(x);
}

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

[[nodiscard]] std::string Memory::External::readStringMaybePtr(uintptr_t addToBeRead, std::size_t size) noexcept {
    std::vector<uint8_t> firstFour(4);
    if (!ReadProcessMemory(handle, reinterpret_cast<LPBYTE*>(addToBeRead), firstFour.data(), 4, NULL) && debug) {
        std::cout << "firstFour: " << addToBeRead << std::endl;
        std::cout << getLastErrorAsString() << std::endl;
    };
    //std::cout << "PRE addToBeRead: " << addToBeRead << std::endl;
    for (int i = 0; i < 4; ++i) {
        auto x = firstFour.at(i);
        if (!(x > 32 && x < 127)) { // Check for ascii
            //std::cout << "isPointer!" << std::endl;
            addToBeRead = read<uintptr_t>(addToBeRead);
            //std::cout << "POST addToBeRead: " << addToBeRead << std::endl;;
            break;
        }
    }

    bool oneWord = size == 0;
    if (oneWord)
        size = 100;

    std::vector<char> chars(size);

    if (!ReadProcessMemory(handle, reinterpret_cast<LPBYTE*>(addToBeRead), chars.data(), size, NULL) && debug) {
        std::cout << "readStringMaybePtr: " << addToBeRead << std::endl;
        std::cout << getLastErrorAsString() << std::endl;
    };

    std::string name(chars.begin(), chars.end());

    if (oneWord)
        return name.substr(0, name.find('\0'));

    return name;
}

char* readCString(DWORD* addr) {
    DWORD stringLength = *(addr + (0x10 / 4));
    char* res;
    if (stringLength > 15) {
        res = (char*)*addr;
    }
    else {
        res = (char*)addr;
    }
    return res;
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


[[nodiscard]] uintptr_t Memory::External::findCountryInstance(const uintptr_t start, std::string searchTag) {
    SYSTEM_INFO sys_info;
    GetSystemInfo(&sys_info);
    size_t chunk_size = sys_info.dwPageSize;
    //std::cout << "chunk_size: " << chunk_size << std::endl;
    size_t signature_size = 4;

    //auto modulePtr = getModule("hoi3_tfh.exe");
    uintptr_t CCountryVFTableAddr = getModule("hoi3_tfh.exe").get() + 0x11C1BA8;

    std::vector<int>patternBytes = patternToBytes(ptrToSignature(CCountryVFTableAddr).c_str());
    BYTE* data = new BYTE[chunk_size];

    auto regions = heapWalkExternal(this->handle);
    for (auto& region : *regions) {
        auto region_end = region.start + region.size;
        //std::cout << "Region: " << n2hexstr(region.start) << " - " << n2hexstr(region.size) << " - " << n2hexstr(region_end) << std::endl;
        if (region.start < start) {
            continue;
        }
        for (uintptr_t cur = region.start; cur <= region_end - chunk_size; cur += chunk_size) {
            //std::cout << "Reading at: " << n2hexstr(cur) << std::endl;
            if (!ReadProcessMemory(handle, reinterpret_cast<LPVOID>(cur), data, chunk_size, nullptr)) {
                if (debug) {
                    std::cout << "Region: " << n2hexstr(region.start) << std::endl;
                    std::cout << getLastErrorAsString() << std::endl;
                }
                continue;
            }
            for (uintptr_t i = 0; i <= chunk_size - signature_size; i += 4) { // i += 4 - data should be aligned
                //std::cout << "Check at: " << cur + i << std::endl;
                if (memoryCompare(static_cast<const BYTE*>(data + i), patternBytes)) {
                    auto curTag = this->readString(cur + i + 0x1E4, 3);
                    //std::cout << "Found at: " << n2hexstr(cur + i) << " - " << curTag << std::endl;
                    if (strcmp(curTag.c_str(), searchTag.c_str()) == 0) {
                        //std::cout << "Correct instance found!" <<  std::endl;
                        delete[] data;
                        delete regions;
                        return cur + i;
                    }
                }
            }
        }
    }
    return 0;
}

[[nodiscard]] uintptr_t Memory::External::findTraitInstance(const uintptr_t start, std::string traitName) {
    SYSTEM_INFO sys_info;
    GetSystemInfo(&sys_info);
    size_t chunk_size = sys_info.dwPageSize;
    //std::cout << "chunk_size: " << chunk_size << std::endl;
    size_t signature_size = 4;

    //auto modulePtr = getModule("hoi3_tfh.exe");
    uintptr_t CTraitVFTableAddr = getModule("hoi3_tfh.exe").get() + 0x11C7DC0;

    std::vector<int>patternBytes = patternToBytes(ptrToSignature(CTraitVFTableAddr).c_str());
    BYTE* data = new BYTE[chunk_size];

    auto regions = heapWalkExternal(this->handle);
    for (auto& region : *regions) {
        auto region_end = region.start + region.size;
        //std::cout << "Region: " << n2hexstr(region.start) << " - " << n2hexstr(region.size) << " - " << n2hexstr(region_end) << std::endl;
        if (region.start < start) {
            continue;
        }
        for (uintptr_t cur = region.start; cur <= region_end - chunk_size; cur += chunk_size) {
            //std::cout << "Reading at: " << n2hexstr(cur) << std::endl;
            if (!ReadProcessMemory(handle, reinterpret_cast<LPVOID>(cur), data, chunk_size, nullptr)) {
                if (debug) {
                    std::cout << "Region: " << n2hexstr(region.start) << std::endl;
                    std::cout << getLastErrorAsString() << std::endl;
                }
                continue;
            }
            for (uintptr_t i = 0; i <= chunk_size - signature_size; i += 4) { // i += 4 - data should be aligned
                //std::cout << "Check at: " << cur + i << std::endl;
                if (memoryCompare(static_cast<const BYTE*>(data + i), patternBytes)) {
                    auto curName = std::string(readCString((DWORD*)(cur + i + 0x2C)));
                    //std::cout << "Found at: " << n2hexstr(cur + i) << " - " << curTag << std::endl;
                    if (strcmp(curName.c_str(), traitName.c_str()) == 0) {
                        //std::cout << "Correct instance found!" <<  std::endl;
                        delete[] data;
                        delete regions;
                        return cur + i;
                    }
                }
            }
        }
    }
    return 0;
}


[[nodiscard]] uintptr_t Memory::External::findLeaderInstance(const uintptr_t start, unsigned int leaderId) {
    SYSTEM_INFO sys_info;
    GetSystemInfo(&sys_info);
    size_t chunk_size = sys_info.dwPageSize;
    //std::cout << "chunk_size: " << chunk_size << std::endl;
    size_t signature_size = 4;

    //auto modulePtr = getModule("hoi3_tfh.exe");
    uintptr_t CLeaderVFTableAddr = getModule("hoi3_tfh.exe").get() + 0x11C5220;

    std::vector<int>patternBytes = patternToBytes(ptrToSignature(CLeaderVFTableAddr).c_str());
    BYTE* data = new BYTE[chunk_size];

    auto regions = heapWalkExternal(this->handle);
    for (auto& region : *regions) {
        auto region_end = region.start + region.size;
        //std::cout << "Region: " << n2hexstr(region.start) << " - " << n2hexstr(region.size) << " - " << n2hexstr(region_end) << std::endl;
        if (region.start < start) {
            continue;
        }
        for (uintptr_t cur = region.start; cur <= region_end - chunk_size; cur += chunk_size) {
            //std::cout << "Reading at: " << n2hexstr(cur) << std::endl;
            if (!ReadProcessMemory(handle, reinterpret_cast<LPVOID>(cur), data, chunk_size, nullptr)) {
                if (debug) {
                    std::cout << "Region: " << n2hexstr(region.start) << std::endl;
                    std::cout << getLastErrorAsString() << std::endl;
                }
                continue;
            }
            for (uintptr_t i = 0; i <= chunk_size - signature_size; i += 4) { // i += 4 - data should be aligned
                //std::cout << "Check at: " << cur + i << std::endl;
                if (memoryCompare(static_cast<const BYTE*>(data + i), patternBytes)) {
                    auto curId = *((unsigned int*) (cur + i + 0xC));
                    //std::cout << "Found at: " << n2hexstr(cur + i) << " - " << curTag << std::endl;
                    if (curId == leaderId) {
                        //std::cout << "Correct instance found!" <<  std::endl;
                        delete[] data;
                        delete regions;
                        return cur + i;
                    }
                }
            }
        }
    }
    return 0;
}


[[nodiscard]] std::vector<uintptr_t>* Memory::External::findSignatures(const uintptr_t start, const char* signature, size_t signature_size, int expected_results) noexcept {
    SYSTEM_INFO sys_info;
    GetSystemInfo(&sys_info);
    size_t chunk_size = sys_info.dwPageSize;
    //std::cout << "chunk_size: " << chunk_size << std::endl;

    std::vector<uintptr_t>* results = new std::vector<uintptr_t>;
    results->reserve(expected_results);

    std::vector<int>patternBytes = patternToBytes(signature);
    BYTE* data = new BYTE[chunk_size];

    auto regions = heapWalkExternal(this->handle);

    for (auto &region : *regions) {
        auto region_end = region.start + region.size;
        //std::cout << "Region: " << n2hexstr(region.start) << " - " << n2hexstr(region.size) << " - " << n2hexstr(region_end) << std::endl;
        if (region.start < start) {
            continue;
        }
        for (uintptr_t cur = region.start; cur <= region_end - chunk_size; cur += chunk_size) {
            //std::cout << "Reading at: " << n2hexstr(cur) << std::endl;
            if (!ReadProcessMemory(handle, reinterpret_cast<LPVOID>(cur), data, chunk_size, NULL)) {
                if (debug) {
                    std::cout << "Region: " << n2hexstr(region.start) << std::endl;
                    std::cout << getLastErrorAsString() << std::endl;
                }
                continue;
            }
            for (uintptr_t i = 0; i <= chunk_size - signature_size; i += 4) { // i += 4 - data should be aligned
                //std::cout << "Check at: " << cur + i << std::endl;
                if (memoryCompare(reinterpret_cast<BYTE*>(data + i), patternBytes)) {
                    results->push_back(cur + i);
                    //std::cout << "Found at: " << n2hexstr(cur + i) << " " << results->size() << std::endl;
                }
            }
            if (results->size() >= expected_results) {
                //std::cout << "Early exit inner!" << std::endl;
                break;
            }
        }
        if (results->size() >= expected_results) {
            //std::cout << "Early exit outer!" << std::endl;
            break;
        }
    }
    delete[] data;
    delete regions;
    return results;
}
