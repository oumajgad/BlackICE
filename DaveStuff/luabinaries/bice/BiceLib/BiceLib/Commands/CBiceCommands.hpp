#pragma once
#include <cstdint>

/**
 * CBiceCommands - one game-level command class carrying **our own** payload format, so any
 * number of mod actions can be multiplayer correct without asking the game for anything.
 *
 * ## Why a payload format instead of more type ids
 *
 * Multiplayer is synchronised by broadcasting `CCommand`s and draining them in one ordered
 * loop, so a mod action that is decided from client-local state inside an `Execute` desyncs
 * (`CLAUDE.md`, "four things about running inside the process"). The fix is to add a command
 * - and the first one, `CBiceCommand`, proved the round trip end to end, tested in single
 * player and multiplayer on 2026-10-05.
 *
 * But it cost a **save token**, and tokens are the scarce resource. A command's type id
 * travels as the first token of its serialised form and comes back through `TokenText`
 * (`0x66A230`), which is `begin + id * 0x1C` with **no bounds check**, so an id has to be one
 * the table really covers. Inside the built-in range only three ids are both unclaimed and
 * routed as ordinary keys by the binary tokenizer: `0x7`, `0xA` and `0x13`. Registering new
 * tokens is not the way out either - mod tokens are numbered in **load order**, so their ids
 * depend on what content is loaded and in what sequence, and a type id that differs between
 * peers is silently dropped on the peers that do not know it.
 *
 * Three ids is not a framework. So this spends **two, once, for ever**:
 *
 * | token | what it carries |
 * | --- | --- |
 * | `0x13` | the type id of the single class. Every BiceCommand is this class |
 * | `0x7` | the one key inside it, whose value is the whole payload as a string |
 *
 * `0xA` is left spare. Everything else - which action, and its arguments - lives **inside**
 * the payload in a format of our own, where ids cost nothing and we are the only authority.
 * Adding a command is `registerKind` plus a handler; it needs no reversing and no token.
 *
 * ## The payload format, version "B1"
 *
 * Fixed-width uppercase hex, no delimiters, no quotes, no NULs, nothing outside `[0-9A-FB]`:
 *
 *     "B1"  <kind:4>  <count:2>  <arg:8> * count
 *
 * so the whole string is `8 + 8 * count` characters and its length alone validates it.
 * Arguments are `int32` two's complement. Fixed width rather than delimited is deliberate:
 * there is no separator to disagree about, no locale in the formatting, and a corrupt payload
 * fails the length check rather than parsing into something plausible.
 *
 * Why hex text rather than raw bytes: the value goes through `SaveWriteString` and comes back
 * through `ParseString`, which quote it in a text save and copy it raw in a binary one. An
 * alphabet with no quote, no backslash, no whitespace and no `\xA7` colour marker survives
 * both without escaping, and stays readable in a log.
 *
 * `int32` arguments are enough for what commands actually carry: ids, enums and flags. A
 * `CPersistent` reference is an id pair, which is two of them - which is how
 * `CAssignLeaderCommand` keeps its unit and its leader, and the reason it means the same thing
 * on every peer. Strings would need an escaping rule and are deliberately not in "B1".
 *
 * ## The object
 *
 * | off | holds |
 * | --- | --- |
 * | `+0x00` .. `+0x3C` | the `CCommand` base, built by the game's own constructor |
 * | `+0x3C` | `char payload[PAYLOAD_CAPACITY]`, NUL terminated, ours |
 *
 * **The payload may not live in the base's string at `+0x8`.** That was the tidier plan -
 * the base already constructs and destroys one there - but `CCommand::LoadKey` reads it:
 * `0x67BC80` compares `+0x8` against the empty string and, when it is empty, assigns it from
 * the parse context's `+0x32C`. `+0x8` is the object's `identity`, not spare space.
 *
 * ## Which slots are ours
 *
 * Built by copying `CIncreaseGameSpeedCommand`'s whole 15-slot table - a **payload-free**
 * command, meaning its slot 2 *is* `CCommand::SaveContents` - and overriding five:
 *
 * | slot | ours? | what it is |
 * | --- | --- | --- |
 * | 0 | inherited | `CCommand`'s deleting destructor, `0x14E1E0`. **Size-agnostic**: it frees `+0x8` if long then `free(this)`, no size passed, so it is still correct for an object bigger than the base's |
 * | 1 | inherited | `CPersistent::Save` - writes the braces and calls slot 2 |
 * | 2 | **ours** | chains to `CCommand::SaveContents`, then writes the payload key and string |
 * | 3 | inherited | `CPersistent::Load` - reads keys and calls slot 4 for each |
 * | 4 | **ours** | the payload key, else chain to `CCommand::LoadKey` |
 * | 5, 8-11 | inherited | identical in `CCommand` and the donor, so they are the base's |
 * | 6 | **ours** | `Execute`: decode, then dispatch to the kind's handler |
 * | 7 | **ours** | the type id |
 * | 12 | inherited | `ReturnFalse` - "do not record me after Execute" |
 * | 13 | **ours** | clone |
 * | 14 | inherited | `ReturnTrue` - "may I be posted" |
 *
 * **Slot 13 is a full clone here, not a delegation.** `CBiceCommand` could hand the work to
 * the donor's own clone and fix one dword, because it was exactly the base's `0x3C` bytes.
 * This object is larger and the donor's clone allocates `0x3C`, so ours allocates, initialises
 * the base through the game's constructor, copies the base scalars the game's copy constructor
 * copies, **copies the payload**, and destroys its by-value string argument the way the donor
 * does. The payload has to survive it: the loopback pump clones every item off the queue and
 * it is the clone that executes.
 *
 * Slot 13's argument is an `std::string` **by value** - `ret 0x1C` - and the callee owns it.
 * Confirmed from the body and from both callers: `CreatePersistentByTypeId` at `0xA7BED4` and
 * the pump at `0xB3BFE3` each `sub esp, 0x1C`, build an empty string there and call through
 * `[vftable+0x34]`.
 *
 * ## What every peer has to agree about
 *
 * The type id is a hard constant, so that part is free. **The kind numbers are ours and must
 * mean the same thing in every build in the game**: a peer whose DLL does not know a kind logs
 * it and does nothing, which is a divergence rather than a crash. Same mod, same BiceLib -
 * already true in practice, and now a stated requirement. The format version gives a clean
 * way to break compatibility on purpose: a "B2" payload is refused by a "B1" peer instead of
 * being misread.
 *
 * Read statically out of hoi3_tfh.exe on 2026-10-05; see
 * `reversing/findings/FINDINGS-commands.md`. Only valid for this build. Module relative.
 */
namespace CBiceCommands {

    /**
     * The game-level type id of the one class, and the registry key.
     *
     * A gap in the built-in save-token range, so it is a valid `TokenText` index with an
     * empty name. Identical in every process that runs this executable, which a
     * mod-registered token would not be.
     */
    constexpr uint32_t TYPE_ID = 0x13;

    /**
     * The single key the object serialises, whose value is the whole payload.
     *
     * The other built-in gap routed as an ordinary key; `0xA` remains spare. It only has to
     * be a valid token index and not collide with a key the base's `LoadKey` handles
     * (`identity`, `istargetasynchronous` `0xC8`, `tickstamp` `0xC3`).
     */
    constexpr uint32_t PAYLOAD_TOKEN = 0x7;

    /**@brief how many `int32` arguments one command may carry*/
    constexpr int MAX_ARGS = 32;

    /**@brief room for `8 + 8 * MAX_ARGS` characters and a NUL, rounded up*/
    constexpr int PAYLOAD_CAPACITY = 0x110;

    /**@brief the base is 0x3C; the payload follows it*/
    constexpr uint32_t PAYLOAD_OFFSET = 0x3C;
    constexpr uint32_t OBJECT_SIZE = PAYLOAD_OFFSET + PAYLOAD_CAPACITY;

    /**
     * The payload field has to hold the longest payload the encoder can produce, plus its
     * NUL: `"B1"` + 4 for the kind + 2 for the count + 8 per argument.
     *
     * Asserted here rather than tested, because this is the one mistake in the codec's
     * arithmetic that would be **silent**: too small a field and a full argument list is
     * truncated on the way out and refused on the way in, on every peer at once, looking
     * like a game bug rather than an off-by-one. Every other way the format can go wrong
     * fails loudly and locally, and the example command carrying arguments end to end is
     * what shows it round-trips at all.
     */
    static_assert(PAYLOAD_CAPACITY >= 8 + 8 * MAX_ARGS + 1,
        "PAYLOAD_CAPACITY must hold 8 + 8 * MAX_ARGS characters and a NUL");

    namespace VFTable {
        /**@brief `CCommand`'s own table. Abstract: `_purecall` in slots 6, 7, 12, 13, 14*/
        constexpr uintptr_t CCommand = 0x11B4F74;

        /**@brief `CIncreaseGameSpeedCommand` - payload free and concrete, so its table is
                  a complete working one to copy*/
        constexpr uintptr_t Donor = 0x11D362C;
    }

    namespace Slots {
        constexpr int SAVE = 1;
        constexpr int SAVE_CONTENTS = 2;
        constexpr int LOAD = 3;
        constexpr int LOAD_KEY = 4;
        constexpr int EXECUTE = 6;
        constexpr int TYPE_ID_SLOT = 7;
        constexpr int CLONE = 13;
        constexpr int COUNT = 15;

        /**@brief on the in-game screen: gives the session. `[vftable+0x48]`*/
        constexpr int SCREEN_SESSION = 18;
        /**@brief on a command channel: post. `[vftable+0x18]`*/
        constexpr int CHANNEL_POST = 6;
    }

    namespace Offsets {
        constexpr uintptr_t class_id = 0x04;        // 0x18D on every command read so far
        constexpr uintptr_t identity = 0x08;        // a Hoi3CString. NOT spare - see above
        constexpr uintptr_t type_id_a = 0x2C;
        constexpr uintptr_t type_id_b = 0x30;       // the one the registry hashes
        constexpr uintptr_t tickstamp = 0x34;       // word. 0xFFFF until posted
        constexpr uintptr_t istargetasynchronous = 0x36;   // word. 0 takes the loopback path
        constexpr uintptr_t serial = 0x38;          // dword, per-channel and monotonic

        // The two the base's copy constructor carries over that the CCommand layout in the
        // findings does not list. What they hold was not read; that they are copied says
        // they travel with a command, so our clone copies them too.
        constexpr uintptr_t copied_24 = 0x24;
        constexpr uintptr_t copied_28 = 0x28;       // word
    }

    namespace GameFunction {
        /**@brief the donor's default constructor. `ret 4`, storage on the stack, object in EAX*/
        constexpr uintptr_t DonorConstruct = 0x2DA530;
        /**@brief `operator new`, `__cdecl`*/
        constexpr uintptr_t OperatorNew = 0x79602F;
        /**@brief the `free` every string destructor in the image calls, `__cdecl`*/
        constexpr uintptr_t Free = 0x795F9B;

        /**@brief slot 2 of the base. `__thiscall(this, writer)`, `ret 4`*/
        constexpr uintptr_t CommandSaveContents = 0x67BB80;
        /**@brief slot 4 of the base. `__thiscall(this, parse, key)`, `ret 8`*/
        constexpr uintptr_t CommandLoadKey = 0x67BC80;

        /**@brief writes `<key>=`. **Token in ECX**, writer on the stack, `ret 4`*/
        constexpr uintptr_t SaveWriteKey = 0x67A1B0;
        /**@brief writes a quoted string value and a newline, no key. **String in ECX**, `ret 4`*/
        constexpr uintptr_t SaveWriteString = 0x678FB0;
        /**@brief reads a string value. **Parse context in ECX**, out and a flag on the stack,
                  `ret 8`. Register confirmed from three call sites*/
        constexpr uintptr_t ParseString = 0x67AFB0;

        /**@brief what the donor's slot 1 is, checked before the table is copied*/
        constexpr uintptr_t PersistentSave = 0x5BB10;
        /**@brief the donor's slot 7, `mov eax, 0x292; ret`*/
        constexpr uintptr_t DonorTypeId = 0x2DA680;
    }

    namespace Global {
        /**
         * The prototype registry `CreatePersistentByTypeId` looks in: 511 buckets of 8-byte
         * nodes `{ object +0, next +4 }`, built by `PersistentRegistryInit` from a CRT
         * dynamic initialiser and freed at `atexit`. All three are zero-fill `.data`, so the
         * file carries no value for them - expected, not a failed read.
         */
        constexpr uintptr_t registry_count = 0x1716640;
        constexpr uintptr_t registry_bucket_count = 0x1716644;
        constexpr uintptr_t registry_buckets = 0x1716648;

        /**@brief the save-token vector, indexed by id without a bounds check*/
        constexpr uintptr_t tokens_begin = 0x17165B4;
        constexpr uintptr_t tokens_end = 0x17165B8;
        constexpr uintptr_t TOKEN_STRIDE = 0x1C;
    }

    constexpr uint32_t REGISTRY_BUCKETS = 511;

    /**
    @brief what runs, on every peer, when a command of one kind is executed

    **Everything it is given came off the command.** That is the contract and the whole point:
    `Execute` runs on every machine, so a handler that reads the pressed key, the local
    selection or `played_country_id` does something different on each one, which is a desync
    no test inside the handler can repair. A local input may choose which command to post; it
    may never change what the command does when it runs.

    @param args the command's arguments, exactly as posted
    @param count how many there are - always check it before indexing
    */
    typedef void (*Handler)(const int32_t* args, int count);

    /**
    @brief put our prototype in the game's persistent registry

    **No game need be running, and none of this may ever come to depend on one.** The registry
    is built by a CRT dynamic initialiser before any game code runs and cleared only at
    `atexit`, so this is once per **process**: `PersistentRegistryInit` (`0x67BFA0`) has one
    caller and it is a pointer in the initialiser array, and `PersistentRegistryClear`'s one
    caller is `call clear; free(buckets); ret`.

    Register as early as possible. The **receive** path calls `CreatePersistentByTypeId`
    whenever bytes arrive and an unregistered id answers 0, which silently drops the command -
    so every moment before this runs is a window in which a peer's command is ignored here.

    Idempotent, and everything is checked before anything is written: a build whose donor
    command is not what is expected, or a type id something else already claims, leaves the
    game's registry untouched. "Cannot reach Lua: no game session" is not this refusing - that
    is the overlay console's own gate, which has a "Needs a session" checkbox.

    @return whether the prototype is registered
    */
    bool Register();

    /**@brief whether \ref Register has succeeded*/
    bool registered();

    /**@brief one line for the log and the overlay: registered, or why not*/
    const char* status();

    /**
    @brief declare a kind and what it does

    Call it once per kind, at load, before anything can post that kind. The name is for the
    log only; the **number** is what travels, so it has to mean the same thing in every build
    playing together.

    @param kind our own id, free of the game's token space entirely
    @param name for the log; must outlive the process, so a literal
    @param handler what runs on every peer
    @return false if the kind is already taken, the table is full, or an argument is null
    */
    bool registerKind(uint16_t kind, const char* name, Handler handler);

    /**@brief the name a kind was registered under, or null*/
    const char* kindName(uint16_t kind);

    /**
    @brief build one command of \p kind and post it to the session's command channel

    `CCurrentGameState + 0xBE8` -> slot 18 -> the session -> `+0x38` -> the channel -> slot 6,
    which is the idiom all 337 post sites in the image use.

    **The channel takes ownership**: it deletes the object once it has serialised it, so there
    is nothing to free here and nothing to keep.

    Refuses unless the prototype is registered, a game is on screen, the kind is registered -
    posting a kind nothing handles is a bug worth catching on the machine that made it rather
    than a silent nothing on all of them - and the payload encodes.

    @param args may be null when \p count is 0
    @param count 0 to \ref MAX_ARGS
    @return whether a command was posted
    */
    bool post(uint16_t kind, const int32_t* args, int count);

    /**@brief \ref post with no arguments*/
    bool post(uint16_t kind);
}

// The codec is internal. It was briefly public so a Lua self test could round-trip it, and
// that test is gone: the example command posting arguments and getting them back is the same
// check end to end, through the real serialiser rather than past it, and a shipped export for
// pure arithmetic is surface area for nothing. What the codec could get silently wrong is
// asserted above instead.
