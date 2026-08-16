#include <TextEncoding.hpp>

#include <Windows.h>

#include <vector>

namespace {
    // Paradox data files and the game's in memory strings are Windows-1252. Fixed
    // rather than CP_ACP so the result doesn't depend on the machine's locale.
    constexpr UINT GAME_CODEPAGE = 1252;

    /**
    @brief whether \p text is already well formed UTF-8

    Windows-1252 text with accented characters almost never forms valid UTF-8 by
    accident, so this reliably separates the two. Pure ASCII passes, and is identical
    in both encodings.
    */
    bool isValidUtf8(const char* text, size_t length) {
        size_t i = 0;
        while (i < length) {
            const unsigned char byte = static_cast<unsigned char>(text[i]);

            int trailing = 0;
            if (byte <= 0x7F) {
                i++;
                continue;
            }
            else if ((byte & 0xE0) == 0xC0) {
                if (byte < 0xC2) {
                    return false; // Overlong encoding
                }
                trailing = 1;
            }
            else if ((byte & 0xF0) == 0xE0) {
                trailing = 2;
            }
            else if ((byte & 0xF8) == 0xF0) {
                if (byte > 0xF4) {
                    return false; // Beyond U+10FFFF
                }
                trailing = 3;
            }
            else {
                return false; // Lone continuation byte or invalid lead
            }

            if (i + trailing >= length) {
                return false;
            }
            for (int t = 1; t <= trailing; t++) {
                if ((static_cast<unsigned char>(text[i + t]) & 0xC0) != 0x80) {
                    return false;
                }
            }
            i += static_cast<size_t>(trailing) + 1;
        }
        return true;
    }
}

std::string Text::toUtf8(const char* text, size_t length) {
    if (text == nullptr || length == 0) {
        return std::string();
    }
    if (isValidUtf8(text, length)) {
        return std::string(text, length);
    }

    const int wideLength = MultiByteToWideChar(GAME_CODEPAGE, 0, text,
        static_cast<int>(length), nullptr, 0);
    if (wideLength <= 0) {
        return std::string(text, length);
    }

    std::vector<wchar_t> wide(static_cast<size_t>(wideLength));
    MultiByteToWideChar(GAME_CODEPAGE, 0, text, static_cast<int>(length), wide.data(), wideLength);

    const int utf8Length = WideCharToMultiByte(CP_UTF8, 0, wide.data(), wideLength,
        nullptr, 0, nullptr, nullptr);
    if (utf8Length <= 0) {
        return std::string(text, length);
    }

    std::string result(static_cast<size_t>(utf8Length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide.data(), wideLength, result.data(), utf8Length,
        nullptr, nullptr);
    return result;
}

std::string Text::toUtf8(const std::string& text) {
    return toUtf8(text.c_str(), text.size());
}
