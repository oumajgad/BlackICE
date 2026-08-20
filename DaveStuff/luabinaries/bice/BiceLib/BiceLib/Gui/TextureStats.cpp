#include <Gui/TextureStats.hpp>

#include <Windows.h>
#include <algorithm>
#include <cstdio>
#include <cstring>
#include <unordered_map>
#include <vector>

namespace {
    // D3DFORMAT values, spelled out rather than including d3d9.h: this file only
    // needs the numbers, and the hook that supplies them already has the header.
    const unsigned int FMT_A8R8G8B8 = 21;
    const unsigned int FMT_X8R8G8B8 = 22;
    const unsigned int FMT_R5G6B5 = 23;
    const unsigned int FMT_X1R5G5B5 = 24;
    const unsigned int FMT_A1R5G5B5 = 25;
    const unsigned int FMT_A4R4G4B4 = 26;
    const unsigned int FMT_R3G3B2 = 27;
    const unsigned int FMT_A8 = 28;
    const unsigned int FMT_R8G8B8 = 20;
    const unsigned int FMT_A8R3G3B2 = 29;
    const unsigned int FMT_X4R4G4B4 = 30;
    const unsigned int FMT_A2B10G10R10 = 31;
    const unsigned int FMT_A8B8G8R8 = 32;
    const unsigned int FMT_P8 = 41;
    const unsigned int FMT_L8 = 50;
    const unsigned int FMT_A8L8 = 51;
    const unsigned int FMT_V8U8 = 60;
    const unsigned int FMT_L16 = 81;

    unsigned int fourcc(char a, char b, char c, char d) {
        return static_cast<unsigned int>(a) |
            (static_cast<unsigned int>(b) << 8) |
            (static_cast<unsigned int>(c) << 16) |
            (static_cast<unsigned int>(d) << 24);
    }

    bool isCompressed(unsigned int format, unsigned int* blockBytes) {
        if (format == fourcc('D', 'X', 'T', '1')) { *blockBytes = 8; return true; }
        if (format == fourcc('D', 'X', 'T', '2')) { *blockBytes = 16; return true; }
        if (format == fourcc('D', 'X', 'T', '3')) { *blockBytes = 16; return true; }
        if (format == fourcc('D', 'X', 'T', '4')) { *blockBytes = 16; return true; }
        if (format == fourcc('D', 'X', 'T', '5')) { *blockBytes = 16; return true; }
        if (format == fourcc('A', 'T', 'I', '1')) { *blockBytes = 8; return true; }
        if (format == fourcc('A', 'T', 'I', '2')) { *blockBytes = 16; return true; }
        return false;
    }

    /**@brief bytes per pixel, or 0 for a format this does not know*/
    unsigned int pixelBytes(unsigned int format) {
        switch (format) {
        case FMT_A8R8G8B8:
        case FMT_X8R8G8B8:
        case FMT_A8B8G8R8:
        case FMT_A2B10G10R10:
            return 4;
        case FMT_R8G8B8:
            return 3;
        case FMT_R5G6B5:
        case FMT_X1R5G5B5:
        case FMT_A1R5G5B5:
        case FMT_A4R4G4B4:
        case FMT_X4R4G4B4:
        case FMT_A8L8:
        case FMT_V8U8:
        case FMT_L16:
        case FMT_A8R3G3B2:
            return 2;
        case FMT_A8:
        case FMT_L8:
        case FMT_P8:
        case FMT_R3G3B2:
            return 1;
        default:
            return 0;
        }
    }

    void describe(unsigned int format, char* out, size_t size) {
        switch (format) {
        case FMT_A8R8G8B8: strcpy_s(out, size, "A8R8G8B8"); return;
        case FMT_X8R8G8B8: strcpy_s(out, size, "X8R8G8B8"); return;
        case FMT_A8B8G8R8: strcpy_s(out, size, "A8B8G8R8"); return;
        case FMT_R8G8B8: strcpy_s(out, size, "R8G8B8"); return;
        case FMT_R5G6B5: strcpy_s(out, size, "R5G6B5"); return;
        case FMT_X1R5G5B5: strcpy_s(out, size, "X1R5G5B5"); return;
        case FMT_A1R5G5B5: strcpy_s(out, size, "A1R5G5B5"); return;
        case FMT_A4R4G4B4: strcpy_s(out, size, "A4R4G4B4"); return;
        case FMT_X4R4G4B4: strcpy_s(out, size, "X4R4G4B4"); return;
        case FMT_A8: strcpy_s(out, size, "A8"); return;
        case FMT_L8: strcpy_s(out, size, "L8"); return;
        case FMT_A8L8: strcpy_s(out, size, "A8L8"); return;
        case FMT_P8: strcpy_s(out, size, "P8 (paletted)"); return;
        case FMT_V8U8: strcpy_s(out, size, "V8U8"); return;
        case FMT_L16: strcpy_s(out, size, "L16"); return;
        default: break;
        }

        // Anything else is either a FourCC (DXT1 and friends) or a number worth
        // seeing as it is.
        const char a = static_cast<char>(format & 0xFF);
        const char b = static_cast<char>((format >> 8) & 0xFF);
        const char c = static_cast<char>((format >> 16) & 0xFF);
        const char d = static_cast<char>((format >> 24) & 0xFF);
        if (a >= 32 && a < 127 && b >= 32 && b < 127 &&
            c >= 32 && c < 127 && d >= 32 && d < 127) {
            sprintf_s(out, size, "%c%c%c%c", a, b, c, d);
            return;
        }
        sprintf_s(out, size, "format %u", format);
    }

    /**
    @brief what the pixels occupy, mip chain included

    @param levels the real level count, which the caller reads back from the created
                  texture: a request of zero means "as many as it takes", and the
                  answer decides whether this is a third larger than the top level.
    */
    unsigned __int64 estimateBytes(unsigned int width, unsigned int height,
        unsigned int levels, unsigned int format) {
        unsigned int blockBytes = 0;
        const bool compressed = isCompressed(format, &blockBytes);
        const unsigned int perPixel = compressed ? 0 : pixelBytes(format);
        if (!compressed && perPixel == 0) {
            return 0; // not a format this can size; counted, but not in the totals
        }

        // Not std::max: Windows.h defines max as a macro, and this file wants the
        // header more than it wants the algorithm.
        const unsigned int levelCount = (levels < 1u) ? 1u : levels;

        unsigned __int64 total = 0;
        unsigned int w = width;
        unsigned int h = height;
        for (unsigned int level = 0; level < levelCount; level++) {
            if (compressed) {
                total += static_cast<unsigned __int64>((w + 3) / 4) *
                    ((h + 3) / 4) * blockBytes;
            }
            else {
                total += static_cast<unsigned __int64>(w) * h * perPixel;
            }
            if (w == 1 && h == 1) {
                break;
            }
            w = (w > 1u) ? (w / 2) : 1u;
            h = (h > 1u) ? (h / 2) : 1u;
        }
        return total;
    }

    const unsigned int POOL_MANAGED = 1;

    struct Bucket
    {
        unsigned int format = 0;

        unsigned int liveCount = 0;
        unsigned __int64 liveBytes = 0;
        unsigned __int64 liveManagedBytes = 0;

        unsigned int count = 0;
        unsigned __int64 bytes = 0;
        unsigned int managedCount = 0;
        unsigned __int64 managedBytes = 0;
    };

    /**@brief what a live texture is worth, kept so Release can undo exactly what
              CreateTexture added without touching the freed object*/
    struct Record
    {
        unsigned int format = 0;
        unsigned __int64 bytes = 0;
        bool managed = false;
    };

    // CreateTexture is called from whichever thread is loading, and the page reads
    // this from the render thread, so everything here is behind the lock.
    CRITICAL_SECTION lock;
    bool lockReady = false;
    std::vector<Bucket> buckets;
    std::unordered_map<const void*, Record> liveTextures;
    bool hooked = false;
    bool releaseHooked = false;

    /**@brief the bucket for \p format, created if this is the first of its kind.
              Caller holds the lock.*/
    Bucket& bucketFor(unsigned int format) {
        for (Bucket& candidate : buckets) {
            if (candidate.format == format) {
                return candidate;
            }
        }
        buckets.push_back(Bucket());
        buckets.back().format = format;
        return buckets.back();
    }

    /**@brief takes a texture off the live totals. Caller holds the lock.*/
    void forget(const void* texture) {
        const std::unordered_map<const void*, Record>::iterator found =
            liveTextures.find(texture);
        if (found == liveTextures.end()) {
            return;
        }

        Bucket& bucket = bucketFor(found->second.format);
        if (bucket.liveCount > 0) {
            bucket.liveCount--;
        }
        if (bucket.liveBytes >= found->second.bytes) {
            bucket.liveBytes -= found->second.bytes;
        }
        if (found->second.managed && bucket.liveManagedBytes >= found->second.bytes) {
            bucket.liveManagedBytes -= found->second.bytes;
        }
        liveTextures.erase(found);
    }

    void ensureLock() {
        // Overlay::install runs long before anything can draw, and the first note()
        // cannot race the hook that enables it, so a plain flag is enough here.
        if (!lockReady) {
            InitializeCriticalSection(&lock);
            lockReady = true;
        }
    }
}

void Gui::TextureStats::note(const void* texture, unsigned int width, unsigned int height,
    unsigned int levels, unsigned int usage, unsigned int format, unsigned int pool) {
    (void)usage;

    ensureLock();
    const unsigned __int64 bytes = estimateBytes(width, height, levels, format);
    const bool managed = (pool == POOL_MANAGED);

    EnterCriticalSection(&lock);

    // The allocator reuses addresses, so an address turning up again means the last
    // texture at it went away without the Release hook seeing it. Drop the old one
    // rather than let both sit in the live totals for ever.
    if (texture != nullptr) {
        forget(texture);
    }

    Bucket& bucket = bucketFor(format);
    bucket.count++;
    bucket.bytes += bytes;
    if (managed) {
        bucket.managedCount++;
        bucket.managedBytes += bytes;
    }

    bucket.liveCount++;
    bucket.liveBytes += bytes;
    if (managed) {
        bucket.liveManagedBytes += bytes;
    }

    if (texture != nullptr) {
        Record record;
        record.format = format;
        record.bytes = bytes;
        record.managed = managed;
        liveTextures[texture] = record;
    }

    LeaveCriticalSection(&lock);
}

void Gui::TextureStats::noteDestroyed(const void* texture) {
    if (texture == nullptr) {
        return;
    }
    ensureLock();

    EnterCriticalSection(&lock);
    forget(texture);
    LeaveCriticalSection(&lock);
}

void Gui::TextureStats::setReleaseHooked() {
    ensureLock();
    EnterCriticalSection(&lock);
    releaseHooked = true;
    LeaveCriticalSection(&lock);
}

void Gui::TextureStats::setHooked() {
    ensureLock();
    EnterCriticalSection(&lock);
    hooked = true;
    LeaveCriticalSection(&lock);
}

int Gui::TextureStats::snapshot(Row* out, int capacity) {
    ensureLock();
    EnterCriticalSection(&lock);
    std::vector<Bucket> copy = buckets;
    LeaveCriticalSection(&lock);

    // Sorted by what is alive, since that is the column worth reading first.
    std::sort(copy.begin(), copy.end(), [](const Bucket& a, const Bucket& b) {
        return a.liveBytes > b.liveBytes;
        });

    int written = 0;
    for (const Bucket& bucket : copy) {
        if (written >= capacity) {
            break;
        }
        Row& row = out[written];
        row.format = bucket.format;
        describe(bucket.format, row.name, sizeof(row.name));
        row.liveCount = bucket.liveCount;
        row.liveBytes = bucket.liveBytes;
        row.liveManagedBytes = bucket.liveManagedBytes;
        row.count = bucket.count;
        row.bytes = bucket.bytes;
        unsigned int blockBytes = 0;
        row.compressed = isCompressed(bucket.format, &blockBytes);
        written++;
    }
    return written;
}

Gui::TextureStats::Summary Gui::TextureStats::summary() {
    ensureLock();
    Summary result;

    EnterCriticalSection(&lock);
    result.hooked = hooked;
    result.releaseHooked = releaseHooked;
    result.formats = static_cast<unsigned int>(buckets.size());
    for (const Bucket& bucket : buckets) {
        result.count += bucket.count;
        result.bytes += bucket.bytes;

        result.liveCount += bucket.liveCount;
        result.liveBytes += bucket.liveBytes;
        result.liveManagedBytes += bucket.liveManagedBytes;

        unsigned int blockBytes = 0;
        if (isCompressed(bucket.format, &blockBytes)) {
            result.liveCompressedBytes += bucket.liveBytes;
        }
        else {
            result.liveUncompressedBytes += bucket.liveBytes;
        }
    }
    LeaveCriticalSection(&lock);
    return result;
}

void Gui::TextureStats::reset() {
    ensureLock();
    EnterCriticalSection(&lock);
    buckets.clear();

    // Only the history is being thrown away. The live totals are rebuilt from the
    // textures that are still alive, because Reset should not claim they went away.
    for (std::unordered_map<const void*, Record>::const_iterator entry = liveTextures.begin();
        entry != liveTextures.end(); ++entry) {
        Bucket& bucket = bucketFor(entry->second.format);
        bucket.liveCount++;
        bucket.liveBytes += entry->second.bytes;
        if (entry->second.managed) {
            bucket.liveManagedBytes += entry->second.bytes;
        }
    }
    LeaveCriticalSection(&lock);
}
