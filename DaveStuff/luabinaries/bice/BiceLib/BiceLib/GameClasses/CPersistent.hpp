#pragma once
#include <cstdint>

/**
 * CPersistent - the base of everything that goes into a save, and how it gets there.
 *
 * 754 classes in this build derive from it, `CCountry` among them. It has **six virtuals**,
 * and the save and load of every one of those classes is slots 1 to 5. The names below are
 * BiceLib's, not the game's: the only thing the executable says out loud is the source file,
 * `persistent.cpp`, in the error path of slot 3.
 *
 *     slot  base implementation   what it does
 *     0     per class             the scalar deleting destructor
 *     1     0x5BB10  Save         writes `{`, calls slot 2, writes `}`
 *     2     0x20CD50 `ret 4`      the class writes its own keys here - what to override
 *     3     0x67C050 Load         reads keys until `}`, calling slot 4 for each
 *     4     per class             one key: its value is the parse state's value token
 *     5     0x6BF890 `ret`        after the block has been read, to fix up what it lacked
 *
 * The caller writes the key and then calls `Save`, so `flags={ ... }` is
 * `SaveWriteKey(0x37F)` followed by `flags_object->Save(writer)`. Slot 1 is the whole of the
 * braces and the indenting; a class that overrides slot 2 only ever writes key and value
 * pairs. `CCountry::SaveContents` (`0xCFCE0`) is the worked example.
 *
 * **A key is never written as text.** It is a token id - `mov ecx, 0x5A6; call SaveWriteKey`
 * for `usage` - and `Tokens` below is how to turn one into the key it stands for. That is
 * what lets a field be named from the key the game saves it under even where the Lua API
 * never exposes it.
 *
 * The findings name all five on every class that writes its own - 568 bodies, from the RTTI
 * export's account of which class introduced which implementation - so a call reads
 * `CBuilding::LoadKey(this, parse, key)` rather than an address.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CPersistent {
    namespace Offsets {
        constexpr uintptr_t vftable = 0x0;

        /**
         * **A SaveToken every CPersistent carries, and nothing has been found that reads
         * it.** The constructor sets it to `none` (397) and is inlined everywhere: of 714
         * inlined constructors that write this word and then a vftable, **697 write
         * `none`**. **Read live**: still `none` on every instance of CSubUnitDefinition,
         * CTechnology, CRegiment, CCombat, CAIStrategy, CLeader, CTheatre and CConvoy in a
         * running game.
         *
         * So it is *not* a class id, however much a constant at +4 looks like one - every
         * class holds the same value. Nothing in the executable compares this word against
         * `none`, and no class was seen setting it to another token, so what it was meant
         * for is open. It is recorded here because a derived class's first own field starts
         * at +0x8, not +0x4.
         *
         * On a class that reaches CPersistent at an offset - CUnit and CProvinceBuilding at
         * +8, CGameSetup at +12 - this sits that much further in.
         */
        constexpr uintptr_t token = 0x4;
    }

    /**@brief the six virtuals every CPersistent has, by slot*/
    namespace Slots {
        constexpr int DESTRUCTOR = 0;
        constexpr int SAVE = 1;            // void Save(CSaveWriter*)
        constexpr int SAVE_CONTENTS = 2;   // void SaveContents(CSaveWriter*)
        constexpr int LOAD = 3;            // void Load(CParseContext*)
        constexpr int LOAD_KEY = 4;        // void LoadKey(CParseContext*, int key)
        constexpr int AFTER_LOAD = 5;      // void AfterLoad()
    }

    namespace GameFunction {
        /**@brief `CPersistent::Save`, slot 1 - the braces around slot 2's contents*/
        constexpr uintptr_t Save = 0x5BB10;

        /**@brief `CPersistent::Load`, slot 3 - the key loop that drives slot 4*/
        constexpr uintptr_t Load = 0x67C050;

        /**@brief writes `<key>=` (token id in ECX, writer on the stack)*/
        constexpr uintptr_t SaveWriteKey = 0x67A1B0;

        /**@brief writes a token's own text as the value - `yes`, `{`, a newline*/
        constexpr uintptr_t SaveWriteToken = 0x61360;

        /**@brief writes one CToken, text or binary as the writer is set*/
        constexpr uintptr_t SaveWriteValue = 0x6797A0;

        /**@brief the key's text for a token id (id in EDI, a std::string to fill in ESI)*/
        constexpr uintptr_t TokenText = 0x66A230;

        /**@brief fills Tokens::first from the registered tokens; runs once, on first use*/
        constexpr uintptr_t BuildTokenTable = 0x66A050;

        /**@brief opens an object: a newline, the indent, `{`, and one more level of depth*/
        constexpr uintptr_t SaveBeginBlock = 0x679750;

        /**@brief writes that many tabs; not called for a binary save*/
        constexpr uintptr_t SaveWriteIndent = 0x67A110;

        /**@brief reads one `key = value` into the parse state, ahead of every slot 4*/
        constexpr uintptr_t ParseReadKeyValue = 0x67ACB0;

        /**@brief steps over the value of a key the class does not handle, whole block and all*/
        constexpr uintptr_t ParseSkipValue = 0x67AC60;
    }

    /**
     * A token: what the parser hands back and what the writer puts out.
     *
     * `type` is itself a token id, so a token names its own kind. Punctuation is its own
     * type - 1 `=`, 3 `{`, 4 `}`, 0x10 a newline, 0x11 a tab, 0x12 a space - and the kinds a
     * value takes are ids the table has no string for, which `SaveWriteValue`'s binary half
     * tells apart:
     *
     *     0x0C  an integer        written "%d", read back with atoi
     *     0x0D  a fixed point     a whole part, a dot, a fraction, into thousandths
     *     0x0E  a yes or no      the word itself; the binary half compares it to "yes"
     *     0x0F  a bare word       what SaveWriteKey gives the key itself
     *     0x13  the end of input  CPersistent::Load stops on it
     *     0x14  an integer        written "%u"
     *     0x18F long_float        the one kind the table does name
     *
     * **In a binary save the type is the whole of what is written**, two bytes, with the
     * payload after it and whitespace dropped; in a text save the id is looked up and the
     * text written instead.
     */
    namespace CToken {
        constexpr uintptr_t type = 0x0;      // int, a token id
        constexpr uintptr_t text = 0x4;      // char[256]
        constexpr uintptr_t SIZE = 0x104;
    }

    /**
     * The object `Save` writes through. BiceLib's name for it; it has no RTTI.
     */
    namespace CSaveWriter {
        /**@brief how deep in braces, starting at -1 so the outermost block writes none*/
        constexpr uintptr_t depth = 0x4;

        /**@brief the stream, whose vftable holds write-text at +0x14 and write-bytes at +0x20*/
        constexpr uintptr_t stream = 0x8;

        /**@brief set for a binary save: token ids go out raw and the indenting is skipped*/
        constexpr uintptr_t binary = 0xC;
    }

    /**
     * The object `Load` reads through, and the one argument slot 4 gets. BiceLib's name.
     *
     * The three CToken in a row are one `key = value` as it was read, which is why slot 4
     * needs no more than this and the key: `CCountry::LoadKey` reads its numbers straight
     * out of `value + 4`.
     */
    namespace CParseContext {
        constexpr uintptr_t tokenizer = 0x1C;   // +0xC is its current CToken, +0x110 a ready flag
        constexpr uintptr_t key = 0x20;         // a CToken; its type is the id slot 4 switches on
        constexpr uintptr_t separator = 0x124;  // a CToken, the `=`
        constexpr uintptr_t value = 0x228;      // a CToken
    }

    /**
     * The token table: id -> key, as a `std::vector<std::string>` indexed by the id.
     *
     * Built on first use by `GameFunction::BuildTokenTable`, so **it only exists in a
     * running game**, and out of two sources that are worth telling apart:
     *
     *  - `compiled`, a `CToken[2138]` in the image, each carrying its own id. Together with
     *    the punctuation the tokenizer holds at ids 1 to 21 these are **the executable's
     *    own, and their ids are fixed** - 2149 of them.
     *  - everything the loaded mod defines: its resources, cultures, decorations and so on,
     *    about as many again, as heap objects **numbered in load order**. Those ids say
     *    nothing about the executable and change with the mod.
     *
     * `reversing/saveTokens.py` reads the table; `--compiled` takes only the first kind,
     * which is what `ghidra/saveTokens.json` holds and what the findings turn into the
     * `SaveToken` enum.
     */
    namespace Tokens {
        constexpr uintptr_t first = 0x17165B4;     // std::string*, 0x1C each, index = id
        constexpr uintptr_t end = 0x17165B8;
        constexpr uintptr_t count = 0x16857B8;
        constexpr uintptr_t built = 0x16857BC;     // set once the table has been made
        constexpr uintptr_t compiled = 0x168CCA0;  // CToken[2138], the executable's own
    }
}
