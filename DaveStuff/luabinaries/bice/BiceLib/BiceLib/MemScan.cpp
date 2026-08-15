#include <MemScan.hpp>

namespace {
    struct Region
    {
        uintptr_t start;
        size_t size;
    };

    size_t pageSize() noexcept {
        SYSTEM_INFO sysInfo;
        GetSystemInfo(&sysInfo);
        return sysInfo.dwPageSize;
    }

    /**@brief committed, private, readable regions of this process at or above \p minAddress*/
    std::vector<Region> committedRegions(uintptr_t minAddress) {
        std::vector<Region> regions;
        MEMORY_BASIC_INFORMATION info;

        for (unsigned char* p = nullptr;
            VirtualQuery(p, &info, sizeof(info)) == sizeof(info);
            p += info.RegionSize)
        {
            const bool readable =
                info.Protect & PAGE_EXECUTE_READ ||
                info.Protect & PAGE_EXECUTE_READWRITE ||
                info.Protect & PAGE_READWRITE ||
                info.Protect & PAGE_READONLY;
            const bool blocked = info.Protect & (PAGE_GUARD | PAGE_WRITECOMBINE | PAGE_NOACCESS);
            const uintptr_t base = reinterpret_cast<uintptr_t>(info.BaseAddress);

            if ((info.State & MEM_COMMIT) && (info.Type & MEM_PRIVATE) && readable && !blocked && base >= minAddress) {
                regions.push_back({ base, info.RegionSize });
            }
        }
        return regions;
    }

    /**
    @brief walks every 4 byte aligned slot of every readable region at or above \p start
           and calls \p onHit for each slot holding \p needle. Stops when it returns false.
    */
    template <typename OnHit>
    void scan(uintptr_t start, uint32_t needle, OnHit onHit) {
        const size_t chunkSize = pageSize();
        std::vector<uint8_t> page(chunkSize);

        for (const auto& region : committedRegions(start)) {
            const uintptr_t regionEnd = region.start + region.size;

            for (uintptr_t cur = region.start; cur + chunkSize <= regionEnd; cur += chunkSize) {
                if (!ReadProcessMemory(GetCurrentProcess(), reinterpret_cast<LPCVOID>(cur), page.data(), chunkSize, nullptr)) {
                    continue; // Region went away or got reprotected since the VirtualQuery
                }

                for (size_t i = 0; i + sizeof(uint32_t) <= chunkSize; i += 4) { // i += 4 - data should be aligned
                    if (*reinterpret_cast<const uint32_t*>(page.data() + i) == needle) {
                        if (!onHit(cur + i)) {
                            return;
                        }
                    }
                }
            }
        }
    }
}

[[nodiscard]] uintptr_t Mem::moduleBase(const char* modName) noexcept {
    return reinterpret_cast<uintptr_t>(GetModuleHandleA(modName));
}

[[nodiscard]] std::string Mem::toHex(uint32_t value) noexcept {
    static const char* digits = "0123456789ABCDEF";
    std::string res(8, '0');
    for (size_t i = 0, shift = 28; i < 8; ++i, shift -= 4) {
        res[i] = digits[(value >> shift) & 0xF];
    }
    return res;
}

[[nodiscard]] std::vector<uintptr_t> Mem::findPointers(uintptr_t start, uint32_t needle, size_t maxResults) {
    std::vector<uintptr_t> results;
    results.reserve(maxResults < 1024 ? maxResults : 1024);

    scan(start, needle, [&results, maxResults](uintptr_t hit) {
        results.push_back(hit);
        return results.size() < maxResults;
    });

    return results;
}

[[nodiscard]] uintptr_t Mem::findPointerIf(uintptr_t start, uint32_t needle, const std::function<bool(uintptr_t)>& accept) {
    uintptr_t found = 0;

    scan(start, needle, [&found, &accept](uintptr_t hit) {
        if (!accept(hit)) {
            return true;
        }
        found = hit;
        return false;
    });

    return found;
}
