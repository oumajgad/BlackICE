#pragma once

#include <cstddef>
#include <cstdint>

/**
 * A string in the shape the game's own compiler produced, owned by BiceLib.
 *
 * `HDS::Hoi3CString` describes that shape for **reading** one out of the game.
 * This is for **handing one back**: the characters in place up to fifteen, a pointer
 * past that, then the length and the capacity - the layout every string in
 * `hoi3_tfh.exe` has, so a game function takes one of these as its own `std::string`.
 *
 * Past fifteen characters the game's own `assign` allocates and the game's own `free`
 * gives it back, because **the allocator in this DLL is not the allocator in the
 * executable**. Up to fifteen nothing is allocated at all, which is why short strings -
 * a variable's name, a localisation key - cost nothing and cannot fail.
 *
 * The layout is the entire point of the class, so nothing may go before the three
 * fields and nothing virtual may be added to it.
 */
namespace Game {
    class String
    {
    public:
        String();
        explicit String(const char* text);
        ~String();

        void set(const char* text);

        /**@brief back to empty, giving up anything allocated the way the game does*/
        void clear();

        /**@brief the characters, wherever they are; never null*/
        const char* text() const;
        int length() const { return length_; }
        bool empty() const { return length_ == 0; }

        /**
        @brief the object itself, to pass where a game function wants a `std::string`

        A function that **constructs** into it - an out parameter - must be given an
        empty one, or what it was holding is leaked: the game writes the length and the
        capacity over whatever was there without looking.
        */
        void* raw() { return this; }
        const void* raw() const { return this; }

    private:
        char data_[16];
        int length_;
        int capacity_;

        // Owning. Nothing here wants a second copy of one, and a shallow copy would
        // free the same block twice.
        String(const String&);
        String& operator=(const String&);
    };

    /**
    @brief the characters of a string the game owns, in the game's own encoding

    Not `HDS::readString`, which converts to UTF-8 for ImGui and Lua. What comes out of
    here is for going straight back into the game, so it stays Windows-1252.

    @returns a pointer into the game's own memory, or "" if there is nothing there
    */
    const char* rawChars(uintptr_t address);
}
