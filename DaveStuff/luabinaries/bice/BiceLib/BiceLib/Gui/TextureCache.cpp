#include <Gui/TextureCache.hpp>
#include <Overlay.hpp>

#include <Windows.h>
#include <d3d9.h>

#include <cstdio>
#include <map>
#include <vector>

namespace {
    struct Entry
    {
        IDirect3DTexture9* texture = nullptr;
        int width = 0;
        int height = 0;
    };

    std::map<std::string, Entry> cache;

#pragma pack(push, 1)
    struct TgaHeader
    {
        uint8_t idLength;
        uint8_t colourMapType;
        uint8_t imageType;      // 2 = uncompressed true colour, 10 = RLE true colour
        uint8_t colourMapSpec[5];
        uint16_t originX;
        uint16_t originY;
        uint16_t width;
        uint16_t height;
        uint8_t bitsPerPixel;
        uint8_t descriptor;     // bit 5 set means the first row is the top one
    };
#pragma pack(pop)

    bool readFile(const std::string& path, std::vector<uint8_t>& out) {
        FILE* file = nullptr;
        if (fopen_s(&file, path.c_str(), "rb") != 0 || file == nullptr) {
            return false;
        }

        fseek(file, 0, SEEK_END);
        const long size = ftell(file);
        fseek(file, 0, SEEK_SET);

        if (size <= 0) {
            fclose(file);
            return false;
        }

        out.resize(static_cast<size_t>(size));
        const size_t read = fread(out.data(), 1, out.size(), file);
        fclose(file);
        return read == out.size();
    }

    /**
    @brief decodes an uncompressed or RLE true colour TGA into BGRA

    Only the two types the mod's model sprites actually use are handled; anything else
    is rejected rather than decoded incorrectly. Output is BGRA because that is what
    D3DFMT_A8R8G8B8 expects, which is the same byte order TGA already stores.
    */
    bool decodeTga(const std::vector<uint8_t>& file, std::vector<uint8_t>& pixels, int& width, int& height) {
        if (file.size() < sizeof(TgaHeader)) {
            return false;
        }

        TgaHeader header;
        memcpy(&header, file.data(), sizeof(header));

        const bool uncompressed = (header.imageType == 2);
        const bool runLength = (header.imageType == 10);
        if ((!uncompressed && !runLength) || (header.bitsPerPixel != 24 && header.bitsPerPixel != 32)) {
            return false;
        }

        width = header.width;
        height = header.height;
        if (width <= 0 || height <= 0) {
            return false;
        }

        const int bytesPerPixel = header.bitsPerPixel / 8;
        size_t offset = sizeof(TgaHeader) + header.idLength;
        if (offset > file.size()) {
            return false;
        }

        const size_t pixelCount = static_cast<size_t>(width) * static_cast<size_t>(height);
        pixels.assign(pixelCount * 4, 0);

        size_t written = 0;
        while (written < pixelCount) {
            if (uncompressed) {
                if (offset + bytesPerPixel > file.size()) {
                    return false;
                }
                pixels[written * 4 + 0] = file[offset + 0];
                pixels[written * 4 + 1] = file[offset + 1];
                pixels[written * 4 + 2] = file[offset + 2];
                pixels[written * 4 + 3] = (bytesPerPixel == 4) ? file[offset + 3] : 255;
                offset += bytesPerPixel;
                written++;
            }
            else {
                if (offset >= file.size()) {
                    return false;
                }
                const uint8_t packet = file[offset++];
                const int count = (packet & 0x7F) + 1;

                if (packet & 0x80) { // Run: one pixel repeated
                    if (offset + bytesPerPixel > file.size()) {
                        return false;
                    }
                    for (int i = 0; i < count && written < pixelCount; i++, written++) {
                        pixels[written * 4 + 0] = file[offset + 0];
                        pixels[written * 4 + 1] = file[offset + 1];
                        pixels[written * 4 + 2] = file[offset + 2];
                        pixels[written * 4 + 3] = (bytesPerPixel == 4) ? file[offset + 3] : 255;
                    }
                    offset += bytesPerPixel;
                }
                else { // Literal run
                    for (int i = 0; i < count && written < pixelCount; i++, written++) {
                        if (offset + bytesPerPixel > file.size()) {
                            return false;
                        }
                        pixels[written * 4 + 0] = file[offset + 0];
                        pixels[written * 4 + 1] = file[offset + 1];
                        pixels[written * 4 + 2] = file[offset + 2];
                        pixels[written * 4 + 3] = (bytesPerPixel == 4) ? file[offset + 3] : 255;
                        offset += bytesPerPixel;
                    }
                }
            }
        }

        // TGA stores bottom-up unless bit 5 of the descriptor says otherwise.
        if ((header.descriptor & 0x20) == 0) {
            const size_t stride = static_cast<size_t>(width) * 4;
            std::vector<uint8_t> row(stride);
            for (int y = 0; y < height / 2; y++) {
                uint8_t* top = pixels.data() + static_cast<size_t>(y) * stride;
                uint8_t* bottom = pixels.data() + static_cast<size_t>(height - 1 - y) * stride;
                memcpy(row.data(), top, stride);
                memcpy(top, bottom, stride);
                memcpy(bottom, row.data(), stride);
            }
        }
        return true;
    }

    Entry load(const std::string& path) {
        Entry entry;

        IDirect3DDevice9* device = Overlay::device();
        if (device == nullptr) {
            return entry;
        }

        std::vector<uint8_t> file;
        std::vector<uint8_t> pixels;
        if (!readFile(path, file) || !decodeTga(file, pixels, entry.width, entry.height)) {
            entry.width = 0;
            entry.height = 0;
            return entry;
        }

        // Managed pool so the texture survives a device reset without being reloaded.
        if (FAILED(device->CreateTexture(entry.width, entry.height, 1, 0,
            D3DFMT_A8R8G8B8, D3DPOOL_MANAGED, &entry.texture, nullptr))) {
            entry.texture = nullptr;
            return entry;
        }

        D3DLOCKED_RECT locked;
        if (FAILED(entry.texture->LockRect(0, &locked, nullptr, 0))) {
            entry.texture->Release();
            entry.texture = nullptr;
            return entry;
        }

        const size_t stride = static_cast<size_t>(entry.width) * 4;
        for (int y = 0; y < entry.height; y++) {
            memcpy(static_cast<uint8_t*>(locked.pBits) + static_cast<size_t>(y) * locked.Pitch,
                pixels.data() + static_cast<size_t>(y) * stride, stride);
        }
        entry.texture->UnlockRect(0);

        return entry;
    }

    const Entry& entryFor(const std::string& path) {
        auto it = cache.find(path);
        if (it == cache.end()) {
            it = cache.emplace(path, load(path)).first;
        }
        return it->second;
    }
}

ImTextureID Gui::Textures::get(const std::string& path) {
    if (path.empty()) {
        return 0;
    }
    return reinterpret_cast<ImTextureID>(entryFor(path).texture);
}

ImVec2 Gui::Textures::size(const std::string& path) {
    if (path.empty()) {
        return ImVec2(0.0f, 0.0f);
    }
    const Entry& entry = entryFor(path);
    return ImVec2(static_cast<float>(entry.width), static_cast<float>(entry.height));
}

void Gui::Textures::releaseAll() {
    for (auto& pair : cache) {
        if (pair.second.texture != nullptr) {
            pair.second.texture->Release();
        }
    }
    cache.clear();
}
