#pragma once

#include <Windows.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

/**
 * Minimal in-process memory helpers.
 *
 * BiceLib is injected into hoi3_tfh.exe, so everything here operates on the current
 * process and game structures can simply be dereferenced. Page reads still go through
 * ReadProcessMemory so that a region unmapped or reprotected by another game thread
 * after the VirtualQuery fails gracefully instead of raising an access violation.
 */
namespace Mem {
    /**@brief base address of an already loaded module ("hoi3_tfh.exe"), 0 if not loaded*/
    [[nodiscard]] uintptr_t moduleBase(const char* modName) noexcept;

    /**@brief zero padded uppercase hex without prefix, e.g. 0x11CEB54 -> "011CEB54"*/
    [[nodiscard]] std::string toHex(uint32_t value) noexcept;

    /**
    @brief scans committed private memory for 4 byte aligned occurrences of \p needle
    @param start regions starting below this address are skipped
    @param needle the pointer value to search for (usually a vftable address)
    @param maxResults stop scanning once this many hits were collected
    */
    [[nodiscard]] std::vector<uintptr_t> findPointers(uintptr_t start, uint32_t needle, size_t maxResults);

    /**
    @brief like findPointers, but stops at the first hit \p accept returns true for
    @returns the matching address, or 0 if there was none
    */
    [[nodiscard]] uintptr_t findPointerIf(uintptr_t start, uint32_t needle, const std::function<bool(uintptr_t)>& accept);

    /**
    @brief reads \p size bytes from \p address, failing instead of crashing

    Goes through ReadProcessMemory so the kernel validates the range: following a
    wild pointer returns false rather than raising an access violation. Use this
    whenever walking game structures that might not be what we assume they are.
    */
    [[nodiscard]] bool tryReadBytes(uintptr_t address, void* destination, size_t size) noexcept;

    /**@brief typed convenience wrapper around tryReadBytes*/
    template <typename T>
    [[nodiscard]] bool tryRead(uintptr_t address, T& out) noexcept {
        return tryReadBytes(address, &out, sizeof(T));
    }
}
