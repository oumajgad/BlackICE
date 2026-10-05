#include <Commands/CBiceCommands.hpp>

#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/GameString.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <cstdint>
#include <cstring>

namespace {

    /**
     * Slot 13's by-value argument.
     *
     * The game's `std::string` is **0x18** bytes - buffer at `+0`, size at `+0x10`, capacity
     * at `+0x14`, as `ParseString` builds one of its own on the stack at `0xA7AFCF` - but
     * slot 13 is `ret 0x1C` and both of its callers reserve `sub esp, 0x1C`, so the argument
     * occupies 0x1C. Declared as opaque bytes of that width, because what matters here is the
     * stack footprint: ours and the game's `ret` immediate have to agree or the stack is
     * corrupted on every command that arrives.
     */
    struct ByValueString {
        unsigned char bytes[0x1C];
    };
    static_assert(sizeof(ByValueString) == 0x1C, "slot 13 is ret 0x1C");

    constexpr uintptr_t STRING_CAPACITY_OFFSET = 0x14;
    constexpr uint32_t STRING_SHORT_CAPACITY = 0xF;

    /**
     * `__fastcall` is how a `__thiscall` is spelled for a free function here, and how the
     * game's own ECX-plus-stack conventions are spelled at all.
     *
     * A `__thiscall` with no stack arguments is: receiver in ECX, bare `ret`. A `__fastcall`
     * whose first two parameters are register-eligible is: first in ECX, second in EDX, and
     * the rest on the stack, cleaned by the callee. So the second parameter is a placeholder
     * that soaks up EDX and is never read, and anything after it lands exactly where the game
     * put it. `SaveWriteKey`, `SaveWriteString` and `ParseString` all take their interesting
     * argument in ECX and the rest on the stack, which is the same shape.
     */
    typedef void* (__stdcall* DonorConstructFn)(void* storage);
    typedef void* (__cdecl* OperatorNewFn)(unsigned int size);
    typedef void (__cdecl* FreeFn)(void* block);
    typedef void (__fastcall* SaveContentsFn)(void* self, int edx, void* writer);
    typedef void (__fastcall* LoadKeyFn)(void* self, int edx, void* parse, int key);
    typedef void (__fastcall* SaveWriteKeyFn)(uint32_t token, int edx, void* writer);
    typedef void (__fastcall* SaveWriteStringFn)(void* value, int edx, void* writer);
    typedef void (__fastcall* ParseStringFn)(void* parse, int edx, void* out, int flag);
    typedef uintptr_t (__thiscall* ScreenSessionFn)(uintptr_t screen);
    typedef void (__thiscall* ChannelPostFn)(uintptr_t channel, uintptr_t command);

    /**
     * Our virtual table: the donor's, copied at registration, with five slots replaced. It
     * lives in this DLL for the rest of the process, because the prototype in the game's
     * registry points at it and that registry is cleared only at `atexit`. There is
     * deliberately no unregister; if BiceLib were unloaded the registry would hold a dangling
     * prototype, and the DLL is injected and stays.
     */
    uintptr_t vftable[CBiceCommands::Slots::COUNT] = { 0 };

    /**
     * Registered once per **process**, not per game and not per Lua state.
     *
     * `script/bicelib_lua.lua` calls the registration from its top-level block, and that block
     * runs once per Lua state - the game opens one per AI context and never closes one. Every
     * call after the first returns early.
     *
     * **Neither this flag nor the bucket insert is atomic, and that is sound rather than
     * overlooked.** The game launches one main Lua state at startup and creates the others
     * lazily as the ticks progress (the maintainer's account of the lifecycle, 2026-10-05; the
     * code shows only that many states exist, not when they are made). So the main state
     * registers before any other exists: one writer ever, and every later call reads a flag
     * that was already true and never flips back. What would invalidate that is states being
     * created concurrently, or a first call from somewhere other than the main state's load.
     */
    bool registeredFlag = false;
    const char* statusText = "not registered yet";

    /**
    @brief the game module, resolved here rather than taken on trust

    `Hooks::MODULE_BASE` is a hint: it is set when Lua calls `setModuleBase` and zero until
    then, so a registration ahead of that would fail for a reason that has nothing to do with
    the registry. `CCurrentGameState::current` does the same thing and for the same reason,
    including the part worth repeating - **zero is never cached**, because a first call can
    precede the module and must not poison later ones.
    */
    uintptr_t moduleBase() {
        if (Hooks::MODULE_BASE != 0) {
            return Hooks::MODULE_BASE;
        }
        static uintptr_t cached = 0;
        if (cached == 0) {
            cached = Mem::moduleBase("hoi3_tfh.exe");
        }
        return cached;
    }

    // ------------------------------------------------------------------ kinds

    struct KindEntry {
        uint16_t kind;
        const char* name;
        CBiceCommands::Handler handler;
        bool used;
    };
    constexpr int MAX_KINDS = 64;
    KindEntry kinds[MAX_KINDS] = {};

    KindEntry* findKind(uint16_t kind) {
        for (int i = 0; i < MAX_KINDS; i++) {
            if (kinds[i].used && kinds[i].kind == kind) {
                return &kinds[i];
            }
        }
        return nullptr;
    }

    // ------------------------------------------------------------------ the codec
    //
    // Internal: nothing outside needs it, and the thing it could get silently wrong is the
    // static_assert on PAYLOAD_CAPACITY in the header. Defined here, above the slots, because
    // executeSlot decodes and post encodes.

    constexpr char VERSION_HI = 'B';
    constexpr char VERSION_LO = '1';
    constexpr int HEADER_LENGTH = 8;        // "B1" + 4 kind + 2 count
    constexpr int ARG_LENGTH = 8;

    char hexDigit(unsigned value) {
        return static_cast<char>(value < 10 ? ('0' + value) : ('A' + (value - 10)));
    }

    /**@brief -1 for anything that is not an uppercase hex digit*/
    int hexValue(char c) {
        if (c >= '0' && c <= '9') {
            return c - '0';
        }
        if (c >= 'A' && c <= 'F') {
            return c - 'A' + 10;
        }
        return -1;
    }

    void writeHex(char* out, uint32_t value, int digits) {
        for (int i = 0; i < digits; i++) {
            out[digits - 1 - i] = hexDigit((value >> (4 * i)) & 0xF);
        }
    }

    /**@brief \p digits hex characters as a value, or false on the first bad one*/
    bool readHex(const char* in, int digits, uint32_t* out) {
        uint32_t value = 0;
        for (int i = 0; i < digits; i++) {
            const int digit = hexValue(in[i]);
            if (digit < 0) {
                return false;
            }
            value = (value << 4) | static_cast<uint32_t>(digit);
        }
        *out = value;
        return true;
    }

    /**@brief `"B1" <kind:4> <count:2> <arg:8>*count`, or false if it will not fit*/
    bool encodePayload(uint16_t kind, const int32_t* args, int count, char* out, int outSize) {
        if (out == nullptr || count < 0 || count > CBiceCommands::MAX_ARGS
            || (count > 0 && args == nullptr)) {
            return false;
        }
        if (outSize < HEADER_LENGTH + ARG_LENGTH * count + 1) {
            return false;
        }
        out[0] = VERSION_HI;
        out[1] = VERSION_LO;
        writeHex(out + 2, kind, 4);
        writeHex(out + 6, static_cast<uint32_t>(count), 2);
        for (int i = 0; i < count; i++) {
            writeHex(out + HEADER_LENGTH + ARG_LENGTH * i,
                static_cast<uint32_t>(args[i]), ARG_LENGTH);
        }
        out[HEADER_LENGTH + ARG_LENGTH * count] = 0;
        return true;
    }

    /**
    @brief the inverse, strict about everything

    Rejects a wrong version, a length that disagrees with the count, a character outside the
    alphabet, or a count above MAX_ARGS. A corrupt payload is the same corruption on every
    peer, so refusing is consistent; parsing it into something plausible would not be.

    @param args at least MAX_ARGS entries
    */
    bool decodePayload(const char* text, uint16_t* kind, int32_t* args, int* count) {
        if (text == nullptr || kind == nullptr || args == nullptr || count == nullptr) {
            return false;
        }
        const size_t length = strlen(text);
        if (length < static_cast<size_t>(HEADER_LENGTH)) {
            return false;
        }
        if (text[0] != VERSION_HI || text[1] != VERSION_LO) {
            return false;           // a version this build does not speak, refused not guessed
        }
        uint32_t kindValue = 0;
        uint32_t countValue = 0;
        if (!readHex(text + 2, 4, &kindValue) || !readHex(text + 6, 2, &countValue)) {
            return false;
        }
        if (countValue > static_cast<uint32_t>(CBiceCommands::MAX_ARGS)) {
            return false;
        }
        // The length has to agree with the count exactly. This is what makes a truncated or
        // padded payload a refusal rather than a plausible misreading.
        if (length != static_cast<size_t>(HEADER_LENGTH) + ARG_LENGTH * countValue) {
            return false;
        }
        for (uint32_t i = 0; i < countValue; i++) {
            uint32_t value = 0;
            if (!readHex(text + HEADER_LENGTH + ARG_LENGTH * i, ARG_LENGTH, &value)) {
                return false;
            }
            args[i] = static_cast<int32_t>(value);
        }
        *kind = static_cast<uint16_t>(kindValue);
        *count = static_cast<int>(countValue);
        return true;
    }

    // ------------------------------------------------------------------ the object

    char* payloadOf(uintptr_t command) {
        return reinterpret_cast<char*>(command + CBiceCommands::PAYLOAD_OFFSET);
    }

    /**
    @brief one object of ours, built by the game and then restamped

    The donor's own default constructor initialises every base field, including the
    `Hoi3CString` at `+0x8` and the two the record does not list; we then overwrite the vftable
    and the type id and clear the payload. Allocated with the **game's** `operator new`,
    because the destructor we inherit frees with the game's `free`.

    @return the object, or 0
    */
    uintptr_t buildObject() {
        const uintptr_t base = moduleBase();
        if (base == 0 || vftable[0] == 0) {
            return 0;
        }
        void* storage = reinterpret_cast<OperatorNewFn>(
            base + CBiceCommands::GameFunction::OperatorNew)(CBiceCommands::OBJECT_SIZE);
        if (storage == 0) {
            return 0;       // operator new throws rather than answering null, but the check
        }                   // costs nothing and documents the contract
        reinterpret_cast<DonorConstructFn>(
            base + CBiceCommands::GameFunction::DonorConstruct)(storage);

        const uintptr_t object = reinterpret_cast<uintptr_t>(storage);
        *reinterpret_cast<uintptr_t*>(object) = reinterpret_cast<uintptr_t>(vftable);
        *reinterpret_cast<uint32_t*>(object + CBiceCommands::Offsets::type_id_a) =
            CBiceCommands::TYPE_ID;
        *reinterpret_cast<uint32_t*>(object + CBiceCommands::Offsets::type_id_b) =
            CBiceCommands::TYPE_ID;
        payloadOf(object)[0] = 0;
        return object;
    }

    // ------------------------------------------------------------------ our five slots

    /**@brief slot 7: the type id, which is also the registry key*/
    int __fastcall typeIdSlot(void*, int) {
        return static_cast<int>(CBiceCommands::TYPE_ID);
    }

    /**
    @brief slot 2: the base's fields, then ours

    `CPersistent::Save` has already written the `{`; this writes the keys inside it. The base's
    walker goes first, which is the convention every `CPersistent` subclass follows, and then
    one key and one string value - `SaveWriteString` writes no key of its own, so the pair is
    `SaveWriteKey` then it.
    */
    void __fastcall saveContentsSlot(void* self, int, void* writer) {
        const uintptr_t base = moduleBase();
        if (base == 0 || self == nullptr || writer == nullptr) {
            return;
        }
        reinterpret_cast<SaveContentsFn>(
            base + CBiceCommands::GameFunction::CommandSaveContents)(self, 0, writer);

        // A Game::String is the game's own layout, so a game function takes it as its
        // std::string. SaveWriteString only reads it.
        Game::String value(payloadOf(reinterpret_cast<uintptr_t>(self)));
        reinterpret_cast<SaveWriteKeyFn>(base + CBiceCommands::GameFunction::SaveWriteKey)(
            CBiceCommands::PAYLOAD_TOKEN, 0, writer);
        reinterpret_cast<SaveWriteStringFn>(
            base + CBiceCommands::GameFunction::SaveWriteString)(value.raw(), 0, writer);
    }

    /**
    @brief slot 4: our key, else the base's

    Called once per key inside our braces. Anything that is not ours is chained to
    `CCommand::LoadKey`, which handles `identity`, `istargetasynchronous` and `tickstamp` and
    drops anything else in silence - so chaining is both correct and necessary: the base's own
    three keys arrive here too.
    */
    void __fastcall loadKeySlot(void* self, int, void* parse, int key) {
        const uintptr_t base = moduleBase();
        if (base == 0 || self == nullptr || parse == nullptr) {
            return;
        }
        if (static_cast<uint32_t>(key) != CBiceCommands::PAYLOAD_TOKEN) {
            reinterpret_cast<LoadKeyFn>(
                base + CBiceCommands::GameFunction::CommandLoadKey)(self, 0, parse, key);
            return;
        }

        // An out parameter has to be given an empty string or what it held is leaked; a
        // fresh Game::String is empty, and its destructor gives back anything the game's
        // assign allocated.
        Game::String value;
        reinterpret_cast<ParseStringFn>(base + CBiceCommands::GameFunction::ParseString)(
            parse, 0, value.raw(), 0);

        char* payload = payloadOf(reinterpret_cast<uintptr_t>(self));
        const char* text = value.text();
        const size_t length = strlen(text);
        if (length >= static_cast<size_t>(CBiceCommands::PAYLOAD_CAPACITY)) {
            // Longer than anything encodePayload can produce, so it is not ours. Left empty,
            // and Execute will refuse it - on every peer identically, because they all got the
            // same bytes.
            payload[0] = 0;
            ERROR_OUT(printf("CBiceCommands: a payload of %u characters is too long,"
                " dropped\n", static_cast<unsigned>(length)));
            return;
        }
        memcpy(payload, text, length + 1);
    }

    /**
    @brief slot 6: decode, then dispatch

    **Everything this reads comes off the command.** `Execute` runs on every machine, so
    reading the pressed key, the local selection or `played_country_id` here would make it do
    something different on each one - a desync no test inside this function could repair. The
    payload is the ordered path; the machine it happens to be running on is not.
    */
    void __fastcall executeSlot(void* self, int) {
        if (self == nullptr) {
            return;
        }
        const uintptr_t command = reinterpret_cast<uintptr_t>(self);

        uint16_t kind = 0;
        int32_t args[CBiceCommands::MAX_ARGS] = {};
        int count = 0;
        const char* payload = payloadOf(command);
        if (!decodePayload(payload, &kind, args, &count)) {
            ERROR_OUT(printf("CBiceCommands::Execute: payload '%.64s' is not one this build"
                " understands\n", payload));
            return;
        }

        const KindEntry* entry = findKind(kind);
        if (entry == nullptr) {
            // Not a crash and not nothing: this peer is about to diverge from one that does
            // know the kind, so it is worth saying loudly even though nothing counts it.
            ERROR_OUT(printf("CBiceCommands::Execute: kind %u is not registered in this"
                " build - this machine is diverging from one that has it\n",
                static_cast<unsigned>(kind)));
            return;
        }

        // The turn and the serial are the game's own stamps, logged so two machines' lines can
        // be matched up. They are not needed to dispatch, so a failed read loses the label and
        // not the command - but it is said rather than passed off as a zero.
        uint16_t tickstamp = 0;
        uint32_t serial = 0;
        const bool stamped =
            Mem::tryRead(command + CBiceCommands::Offsets::tickstamp, tickstamp)
            && Mem::tryRead(command + CBiceCommands::Offsets::serial, serial);
        if (stamped) {
            INFO_OUT(printf("CBiceCommands::Execute: %s (kind %u), %d arg(s), turn %u,"
                " serial %u\n", entry->name, static_cast<unsigned>(kind), count,
                static_cast<unsigned>(tickstamp), static_cast<unsigned>(serial)));
        }
        else {
            INFO_OUT(printf("CBiceCommands::Execute: %s (kind %u), %d arg(s), stamps"
                " unreadable\n", entry->name, static_cast<unsigned>(kind), count));
        }

        entry->handler(count > 0 ? args : nullptr, count);
    }

    /**
    @brief slot 13: the clone the factory and the pump both make objects with

    A full clone rather than a delegation to the donor's, because the donor's allocates `0x3C`
    and this object is larger. It mirrors what the donor's does - allocate, initialise the base
    through the game's constructor, carry the base scalars across, destroy the string argument
    - and adds the payload.

    **The payload has to survive this.** The loopback pump clones every item off the queue and
    it is the clone that executes, so a clone that lost the payload would execute an empty one.

    The by-value string argument is ours to destroy: free its buffer when its capacity says it
    has one, exactly as the donor's clone does.

    @return the new object, or 0 - which the factory's caller already handles, because it
            tests the answer before loading into it
    */
    void* __fastcall cloneSlot(void* self, int, ByValueString context) {
        const uintptr_t base = moduleBase();
        uintptr_t made = 0;
        if (base != 0 && self != nullptr) {
            made = buildObject();
            if (made != 0) {
                const uintptr_t source = reinterpret_cast<uintptr_t>(self);
                // Exactly the fields CCommand's copy constructor (0xB530) carries over.
                *reinterpret_cast<uint32_t*>(made + CBiceCommands::Offsets::copied_24) =
                    *reinterpret_cast<const uint32_t*>(source + CBiceCommands::Offsets::copied_24);
                *reinterpret_cast<uint16_t*>(made + CBiceCommands::Offsets::copied_28) =
                    *reinterpret_cast<const uint16_t*>(source + CBiceCommands::Offsets::copied_28);
                *reinterpret_cast<uint16_t*>(made + CBiceCommands::Offsets::tickstamp) =
                    *reinterpret_cast<const uint16_t*>(source + CBiceCommands::Offsets::tickstamp);
                *reinterpret_cast<uint8_t*>(made + CBiceCommands::Offsets::istargetasynchronous) =
                    *reinterpret_cast<const uint8_t*>(source + CBiceCommands::Offsets::istargetasynchronous);
                *reinterpret_cast<uint32_t*>(made + CBiceCommands::Offsets::serial) =
                    *reinterpret_cast<const uint32_t*>(source + CBiceCommands::Offsets::serial);
                memcpy(payloadOf(made), payloadOf(source), CBiceCommands::PAYLOAD_CAPACITY);
            }
        }

        // The argument, destroyed the way every string destructor in the image does it.
        unsigned char* raw = context.bytes;
        const uint32_t capacity = *reinterpret_cast<const uint32_t*>(raw + STRING_CAPACITY_OFFSET);
        if (capacity > STRING_SHORT_CAPACITY && base != 0) {
            void* block = *reinterpret_cast<void**>(raw);
            if (block != nullptr) {
                reinterpret_cast<FreeFn>(base + CBiceCommands::GameFunction::Free)(block);
            }
        }
        return reinterpret_cast<void*>(made);
    }

    // ------------------------------------------------------------------ registration helpers

    /**
    @brief copy the donor's table and override our five slots

    The donor's slots 1, 2 and 7 are checked against what this build is known to hold first.
    That is a cheap fingerprint, and slot 2 being `CCommand::SaveContents` is also precisely
    the property that makes the donor payload free - so the check and the assumption it guards
    are the same fact.
    */
    bool buildVftable() {
        const uintptr_t base = moduleBase();
        if (base == 0) {
            statusText = "the game module is not loaded";
            return false;
        }
        uintptr_t slots[CBiceCommands::Slots::COUNT] = { 0 };
        for (int i = 0; i < CBiceCommands::Slots::COUNT; i++) {
            if (!Mem::tryRead(base + CBiceCommands::VFTable::Donor + i * 4, slots[i])
                || slots[i] == 0) {
                statusText = "the donor command's virtual table could not be read";
                return false;
            }
        }
        const bool fingerprint =
            slots[CBiceCommands::Slots::SAVE]
                == base + CBiceCommands::GameFunction::PersistentSave
            && slots[CBiceCommands::Slots::SAVE_CONTENTS]
                == base + CBiceCommands::GameFunction::CommandSaveContents
            && slots[CBiceCommands::Slots::TYPE_ID_SLOT]
                == base + CBiceCommands::GameFunction::DonorTypeId;
        if (!fingerprint) {
            statusText = "the donor command is not what this build expects";
            ERROR_OUT(printf("CBiceCommands: donor table slots 1/2/7 are %#010x/%#010x/%#010x\n",
                static_cast<unsigned>(slots[CBiceCommands::Slots::SAVE]),
                static_cast<unsigned>(slots[CBiceCommands::Slots::SAVE_CONTENTS]),
                static_cast<unsigned>(slots[CBiceCommands::Slots::TYPE_ID_SLOT])));
            return false;
        }

        for (int i = 0; i < CBiceCommands::Slots::COUNT; i++) {
            vftable[i] = slots[i];
        }
        vftable[CBiceCommands::Slots::SAVE_CONTENTS] =
            reinterpret_cast<uintptr_t>(saveContentsSlot);
        vftable[CBiceCommands::Slots::LOAD_KEY] = reinterpret_cast<uintptr_t>(loadKeySlot);
        vftable[CBiceCommands::Slots::EXECUTE] = reinterpret_cast<uintptr_t>(executeSlot);
        vftable[CBiceCommands::Slots::TYPE_ID_SLOT] = reinterpret_cast<uintptr_t>(typeIdSlot);
        vftable[CBiceCommands::Slots::CLONE] = reinterpret_cast<uintptr_t>(cloneSlot);
        return true;
    }

    /**
    @brief whether anything in the registry already claims our type id

    The static search that picked the id can only see classes whose slot 7 is a constant body,
    so it chooses a number rather than proving one. This is the proof: walk the bucket the
    factory would walk and compare the same `+0x30` it compares. A collision would be quiet
    and nasty - our node is prepended, so *we* would win the lookup and the other class would
    stop deserialising.
    */
    bool typeIdIsFree(uintptr_t buckets, uint32_t bucketCount) {
        const uint32_t bucket = CBiceCommands::TYPE_ID % bucketCount;
        uintptr_t node = 0;
        if (!Mem::tryRead(buckets + bucket * 4, node)) {
            statusText = "the registry bucket could not be read";
            return false;
        }
        // Bounded: a bucket of 511 holding more than this is not a bucket.
        for (int guard = 0; node != 0 && guard < 4096; guard++) {
            uintptr_t object = 0;
            uintptr_t next = 0;
            if (!Mem::tryRead(node, object) || !Mem::tryRead(node + 4, next)) {
                statusText = "the registry bucket did not walk as a list";
                return false;
            }
            uint32_t claimed = 0;
            if (object != 0
                && Mem::tryRead(object + CBiceCommands::Offsets::type_id_b, claimed)
                && claimed == CBiceCommands::TYPE_ID) {
                statusText = "another class already claims our type id";
                ERROR_OUT(printf("CBiceCommands: type id %#x is already registered by the"
                    " prototype at %#010x - pick another\n",
                    static_cast<unsigned>(CBiceCommands::TYPE_ID),
                    static_cast<unsigned>(object)));
                return false;
            }
            node = next;
        }
        return true;
    }

    /**
    @brief whether both our token ids are inside the save-token vector

    `TokenText` indexes that vector by token id with no bounds check, so an id past its end is
    an out-of-bounds read on the receiving side rather than an error. The vector is built
    lazily, so an empty one means "cannot check yet" - not a failure, because both ids are
    inside the built-in range, which is always present once the table exists.
    */
    bool tokensAreInTable(uintptr_t base) {
        uintptr_t begin = 0;
        uintptr_t end = 0;
        if (!Mem::tryRead(base + CBiceCommands::Global::tokens_begin, begin)
            || !Mem::tryRead(base + CBiceCommands::Global::tokens_end, end)) {
            return true;            // unreadable globals are not evidence of a bad id
        }
        if (begin == 0 || end <= begin) {
            return true;            // not built yet
        }
        const uint32_t count =
            static_cast<uint32_t>((end - begin) / CBiceCommands::Global::TOKEN_STRIDE);
        if (CBiceCommands::TYPE_ID >= count || CBiceCommands::PAYLOAD_TOKEN >= count) {
            statusText = "a token id is past the end of the save-token table";
            return false;
        }
        return true;
    }
}

// ---------------------------------------------------------------------- kinds

bool CBiceCommands::registerKind(uint16_t kind, const char* name, Handler handler) {
    if (name == nullptr || handler == nullptr) {
        return false;
    }
    const KindEntry* taken = findKind(kind);
    if (taken != nullptr) {
        ERROR_OUT(printf("CBiceCommands: kind %u is already registered as '%s'\n",
            static_cast<unsigned>(kind), taken->name));
        return false;
    }
    for (int i = 0; i < MAX_KINDS; i++) {
        if (!kinds[i].used) {
            kinds[i].kind = kind;
            kinds[i].name = name;
            kinds[i].handler = handler;
            kinds[i].used = true;
            return true;
        }
    }
    ERROR_OUT(printf("CBiceCommands: no room for kind %u, %d is the limit\n",
        static_cast<unsigned>(kind), MAX_KINDS));
    return false;
}

const char* CBiceCommands::kindName(uint16_t kind) {
    const KindEntry* entry = findKind(kind);
    return entry != nullptr ? entry->name : nullptr;
}

// ---------------------------------------------------------------------- registration

bool CBiceCommands::Register() {
    if (registeredFlag) {
        return true;
    }
    const uintptr_t base = moduleBase();
    if (base == 0) {
        statusText = "the game module is not loaded";
        return false;
    }

    // Everything is read and checked before the first write, so a build or a moment this does
    // not fit leaves the game's registry exactly as it was.
    uint32_t bucketCount = 0;
    uintptr_t buckets = 0;
    if (!Mem::tryRead(base + Global::registry_bucket_count, bucketCount)
        || !Mem::tryRead(base + Global::registry_buckets, buckets)) {
        statusText = "the persistent registry globals could not be read";
        return false;
    }
    if (bucketCount != REGISTRY_BUCKETS || buckets == 0) {
        // The registry is filled from a CRT dynamic initialiser, so this means we are earlier
        // than that - which should be impossible, and is worth saying rather than working
        // around.
        statusText = "the persistent registry is not initialised";
        ERROR_OUT(printf("CBiceCommands: registry bucket count is %u and the array is"
            " %#010x; expected %u and non-zero\n", static_cast<unsigned>(bucketCount),
            static_cast<unsigned>(buckets), static_cast<unsigned>(REGISTRY_BUCKETS)));
        return false;
    }
    if (!tokensAreInTable(base) || !typeIdIsFree(buckets, bucketCount)) {
        return false;               // both set statusText themselves
    }
    if (!buildVftable()) {
        return false;
    }

    const uintptr_t prototype = buildObject();
    if (prototype == 0) {
        statusText = "the prototype could not be built";
        return false;
    }
    void* node = reinterpret_cast<OperatorNewFn>(base + GameFunction::OperatorNew)(8);
    if (node == 0) {
        statusText = "the registry node could not be allocated";
        return false;               // the prototype leaks OBJECT_SIZE bytes, once
    }

    // The insert `RegisterCommandTypes` makes, in the same order: node first, then the bucket
    // head, then the count. The head is the last write, so the list is never reachable in a
    // half-built state.
    const uint32_t bucket = TYPE_ID % bucketCount;
    uintptr_t head = 0;
    if (!Mem::tryRead(buckets + bucket * 4, head)) {
        statusText = "the registry bucket could not be re-read";
        return false;
    }
    uintptr_t* entry = reinterpret_cast<uintptr_t*>(node);
    entry[0] = prototype;
    entry[1] = head;
    *reinterpret_cast<uintptr_t*>(buckets + bucket * 4) = reinterpret_cast<uintptr_t>(node);
    *reinterpret_cast<uint32_t*>(base + Global::registry_count) += 1;

    registeredFlag = true;
    statusText = "registered";
    INFO_OUT(printf("CBiceCommands: registered type id %#x in bucket %u, payload token %#x,"
        " object %u bytes, prototype %#010x\n", static_cast<unsigned>(TYPE_ID),
        static_cast<unsigned>(bucket), static_cast<unsigned>(PAYLOAD_TOKEN),
        static_cast<unsigned>(OBJECT_SIZE), static_cast<unsigned>(prototype)));
    return true;
}

bool CBiceCommands::registered() {
    return registeredFlag;
}

const char* CBiceCommands::status() {
    return statusText;
}

// ---------------------------------------------------------------------- posting

bool CBiceCommands::post(uint16_t kind) {
    return post(kind, nullptr, 0);
}

bool CBiceCommands::post(uint16_t kind, const int32_t* args, int count) {
    if (!registeredFlag) {
        // Posting without the prototype registered is not a no-op: the single player post
        // serialises, the factory answers 0 for an id it does not know, and the caller skips
        // the Load and carries on. Refusing here is the only clean place to stop.
        ERROR_OUT(printf("CBiceCommands::post: not registered (%s)\n", statusText));
        return false;
    }
    if (findKind(kind) == nullptr) {
        // A kind nothing handles would travel, arrive everywhere and do nothing anywhere.
        // Better to fail on the machine that has the bug.
        ERROR_OUT(printf("CBiceCommands::post: kind %u is not registered here\n",
            static_cast<unsigned>(kind)));
        return false;
    }
    char payload[PAYLOAD_CAPACITY] = {};
    if (!encodePayload(kind, args, count, payload, PAYLOAD_CAPACITY)) {
        ERROR_OUT(printf("CBiceCommands::post: kind %u with %d args does not encode\n",
            static_cast<unsigned>(kind), count));
        return false;
    }
    if (!CCurrentGameState::inGame()) {
        ERROR_OUT(printf("CBiceCommands::post: no game is on screen\n"));
        return false;
    }
    const uintptr_t base = moduleBase();
    const uintptr_t state = CCurrentGameState::current();
    if (base == 0 || state == 0) {
        return false;
    }

    // The idiom all 337 post sites use. Read at CConfirmRemoveAll::OnConfirm, 0x748993:
    //     mov ecx, [eax+0xBE8]   ; the in-game screen
    //     mov eax, [ecx]         ; its vftable
    //     mov edx, [eax+0x48]    ; slot 18
    //     call edx               ; -> the session
    //     mov ecx, [eax+0x38]    ; the channel
    //     mov eax, [ecx]
    //     mov edx, [eax+0x18]    ; slot 6
    //     push <command>; call edx
    uintptr_t screen = 0;
    uintptr_t screenVftable = 0;
    uintptr_t sessionOf = 0;
    if (!Mem::tryRead(state + CCurrentGameState::Offsets::in_game_screen, screen)
        || screen == 0
        || !Mem::tryRead(screen, screenVftable) || screenVftable == 0
        || !Mem::tryRead(screenVftable + Slots::SCREEN_SESSION * 4, sessionOf)
        || sessionOf == 0) {
        ERROR_OUT(printf("CBiceCommands::post: could not reach the in-game screen\n"));
        return false;
    }
    const uintptr_t session = reinterpret_cast<ScreenSessionFn>(sessionOf)(screen);

    uintptr_t channel = 0;
    uintptr_t channelVftable = 0;
    uintptr_t postFn = 0;
    if (session == 0
        || !Mem::tryRead(session + 0x38, channel) || channel == 0
        || !Mem::tryRead(channel, channelVftable) || channelVftable == 0
        || !Mem::tryRead(channelVftable + Slots::CHANNEL_POST * 4, postFn) || postFn == 0) {
        ERROR_OUT(printf("CBiceCommands::post: could not reach the command channel\n"));
        return false;
    }

    const uintptr_t command = buildObject();
    if (command == 0) {
        ERROR_OUT(printf("CBiceCommands::post: could not build the command\n"));
        return false;
    }
    memcpy(payloadOf(command), payload, strlen(payload) + 1);

    // The channel owns it from here. The post deletes the object once it has serialised it,
    // so there is nothing to free and nothing worth keeping a pointer to.
    reinterpret_cast<ChannelPostFn>(postFn)(channel, command);
    INFO_OUT(printf("CBiceCommands::post: %s (kind %u), %d arg(s), payload '%s'\n",
        kindName(kind), static_cast<unsigned>(kind), count, payload));
    return true;
}
