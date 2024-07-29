#include "Memory.hpp"

//Returns the last Win32 error, in string format. Returns an empty string if there is no error.
[[nodiscard]] std::string Memory::getLastErrorAsString(void) noexcept
{
    //Get the error message, if any.
    DWORD errorMessageID = GetLastError();
    if (errorMessageID == 0)
        return std::string(); //No error message has been recorded

    LPSTR messageBuffer = nullptr;
    size_t size = FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, errorMessageID, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), reinterpret_cast<LPSTR>(&messageBuffer), 0, NULL);

    std::string message(messageBuffer, size);

    //Free the buffer.
    LocalFree(messageBuffer);

    return message;
}

[[nodiscard]] std::string Memory::convertToString(char* a, int size) noexcept
{
    int i;
    std::string s = "";
    for (i = 0; i < size; i++) {
        s = s + a[i];
    }
    return s;
}

[[nodiscard]] std::vector<int> Memory::patternToBytes(const char* pattern) noexcept 
{
    std::vector<int> bytes{};
    bytes.reserve(strlen(pattern));
            
    std::string patternString(pattern);
            
    char* const start = &patternString[0];
    char* const end = &patternString[strlen(pattern)];

    for (char* current = start; current < end; ++current) {
        if (*current == '?') {
            current++;

            if (*current == '?')
                current++;

            bytes.emplace_back(-1);
        }
        else {
            bytes.emplace_back(static_cast<int>(strtoul(current, &current, 16)));
        }
    }
    return bytes;
}

[[nodiscard]] std::vector<MemoryRegion>* Memory::heapWalkExternal(HANDLE process) {
    unsigned char* p = NULL;
    MEMORY_BASIC_INFORMATION info;
    std::vector<MemoryRegion>* mappedRegions = new std::vector<MemoryRegion>;

    for (p = NULL;
        VirtualQueryEx(process, p, &info, sizeof(info)) == sizeof(info);
        p += info.RegionSize)
    {
        if (info.State & MEM_COMMIT && info.Type & MEM_PRIVATE && info.Protect & PAGE_READWRITE && !(info.Protect & PAGE_GUARD)) {
            MemoryRegion x;
            x.start = (uintptr_t)info.BaseAddress;
            x.size = info.RegionSize;
            //std::cout << x.start << " - " << x.size << std::endl;
            mappedRegions->push_back(x);
        }
    }
    // std::cout << mappedRegions->size() << std::endl;
    return mappedRegions;
}

[[nodiscard]] std::vector<MemoryRegion>* Memory::heapWalkInternal() {
    unsigned char* p = NULL;
    MEMORY_BASIC_INFORMATION info;
    std::vector<MemoryRegion>* mappedRegions = new std::vector<MemoryRegion>;

    for (p = NULL;
        VirtualQuery(p, &info, sizeof(info)) == sizeof(info);
        p += info.RegionSize)
    {
        if (info.State & MEM_COMMIT && info.Type & MEM_PRIVATE && info.Protect & PAGE_READWRITE && !(info.Protect & PAGE_GUARD)) {
            MemoryRegion x;
            x.start = (uintptr_t)info.BaseAddress;
            x.size = info.RegionSize;
            //std::cout << x.start << " - " << x.size << std::endl;
            mappedRegions->push_back(x);
        }
    }
    // std::cout << mappedRegions->size() << std::endl;
    return mappedRegions;
}
