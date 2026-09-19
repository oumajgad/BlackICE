#include <GameState/Localisation.hpp>

#include <GameClasses/GameString.hpp>
#include <GameClasses/GameSettings.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>

namespace {
    // `TextObject* GetText(TextObject* out, const std::string* key)`: both arguments
    // pushed, callee cleans (`ret 8`). What it answers with is the object below, not a
    // string.
    const uintptr_t GET_TEXT = 0x682490;

    // `Render(this = the text object, out = esi, <16 bytes of colours by value>)`,
    // `ret 0x10`. The out string is handed in **esi**, which the compiler chose - see
    // the stub below. It constructs over whatever the out string held.
    const uintptr_t RENDER = 0x682E40;

    // Destroys the replacements a text object collected, with the vector's three
    // pointers handed in **edi**. A lookup that adds no variables collects none, so for
    // this use it is a loop that runs no times - but it is what the game does with one,
    // and a text object that grew replacements would leak without it.
    const uintptr_t RELEASE_REPLACEMENTS = 0x687020;

    const uintptr_t FREE = 0x795F9B;

    /**
     * What the lookup answers with: the entry it found, then a vector of the
     * replacements to apply. Sixteen bytes, and the caller owns the vector.
     */
    struct TextObject
    {
        const void* entry;
        void* begin;
        void* end;
        void* capacityEnd;
    };

    typedef void* (__stdcall* GetTextFn)(void* out, const void* key);
    typedef void (__cdecl* FreeFn)(void* block);

    GetTextFn getText = nullptr;
    FreeFn freeBlock = nullptr;
    DWORD renderAddress = 0;
    DWORD releaseAddress = 0;

    bool looked = false;
    bool ready = false;

    bool setUp() {
        if (looked) {
            return ready;
        }
        looked = true;
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0) {
            return false;
        }
        getText = reinterpret_cast<GetTextFn>(base + GET_TEXT);
        freeBlock = reinterpret_cast<FreeFn>(base + FREE);
        renderAddress = static_cast<DWORD>(base + RENDER);
        releaseAddress = static_cast<DWORD>(base + RELEASE_REPLACEMENTS);
        ready = true;
        return true;
    }

    /**
    @brief turns a text object into characters

    Three arguments in three places, which is why this is assembly: the object in ecx,
    the string to build in esi, and sixteen bytes of colour settings by value, which the
    callee takes off the stack itself.

    @param object the text object the lookup answered with
    @param out an **empty** game string, which the callee constructs over
    @param colours sixteen bytes copied out of the settings, exactly as the game passes
    */
    __declspec(naked) void renderText(void* /*object*/, void* /*out*/, const void* /*colours*/) {
        __asm {
            push ebp
            mov ebp, esp
            push esi

            mov eax, [ebp + 0x10]           // the colours
            push dword ptr [eax + 0x0C]     // pushed backwards, so they land in order
            push dword ptr [eax + 8]
            push dword ptr [eax + 4]
            push dword ptr [eax]
            mov esi, [ebp + 0x0C]           // where the characters go
            mov ecx, [ebp + 8]              // the text object
            call [renderAddress]            // takes the sixteen bytes off itself

            pop esi
            pop ebp
            ret
        }
    }

    /**@brief destroys a text object's replacements, which it takes in edi*/
    __declspec(naked) void releaseReplacements(void* /*the vector's three pointers*/) {
        __asm {
            push ebp
            mov ebp, esp
            push edi

            mov edi, [ebp + 8]
            call [releaseAddress]

            pop edi
            pop ebp
            ret
        }
    }

    /**
    @brief the sixteen bytes of colour settings the render is given

    Copied verbatim rather than understood: the game reads them straight out of its
    settings object and hands them over, and what they mean does not change what comes
    back for a line with no colour codes in it. Zeroes where the settings are not up
    yet, which is what the object would have held then anyway.
    */
    void readColours(unsigned char* into) {
        memset(into, 0, 16);
        uintptr_t settings = 0;
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0 || !Mem::tryRead(base + GameSettings::GLOBAL_POINTER, settings) || settings == 0) {
            return;
        }
        if (!Mem::tryReadBytes(settings + GameSettings::Offsets::text_colours, into, 16)) {
            memset(into, 0, 16);    // half of them would be worse than none of them
        }
    }
}

std::string Localisation::text(const char* key) {
    if (!setUp() || key == nullptr || key[0] == 0) {
        return "";
    }

    const Game::String keyString(key);
    TextObject object = { nullptr, nullptr, nullptr, nullptr };
    getText(&object, keyString.raw());

    unsigned char colours[16] = {};
    readColours(colours);

    // Empty going in, because the render constructs over it without looking at what is
    // there; owning on the way out, so its destructor gives back anything allocated.
    Game::String out;
    renderText(&object, out.raw(), colours);

    // The game frees a text object in two steps, and so does this: the replacements
    // first, then the block the vector itself sat in.
    releaseReplacements(&object.begin);
    if (object.begin != nullptr && freeBlock != nullptr) {
        freeBlock(object.begin);
    }

    return std::string(out.text(), static_cast<size_t>(out.length()));
}

std::string Localisation::textForId(const char* prefix, int id) {
    char key[64] = {};
    _snprintf_s(key, sizeof(key), _TRUNCATE, "%s%d", prefix == nullptr ? "" : prefix, id);
    return text(key);
}

bool Localisation::available() {
    return setUp();
}
