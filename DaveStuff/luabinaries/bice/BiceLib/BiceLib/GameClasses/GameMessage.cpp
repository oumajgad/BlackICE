#include <GameClasses/GameMessage.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <Hooks/Hooks.hpp>
#include <Hooks/MessageQueueHooks.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    /**@brief the country's standard variables, as a list to add to; `ret 4`*/
    const uintptr_t BUILD_VARIABLES = 0xD75F0;
    typedef void* (__stdcall* BuildVariables)(uintptr_t country);

    /**@brief the message handler, made on first use; takes nothing and ends in a bare `ret`*/
    const uintptr_t GET_HANDLER = 0x298E80;
    typedef void* (__cdecl* GetHandler)();

    /**
    @brief the type, by name: `this` is the name and the handler arrives in edx

    Returns null and logs `Failed to find message type` when the registry has no such
    name, which is the whole of what a misspelt or undeclared type costs.
    */
    const uintptr_t FIND_TYPE = 0x299480;
    typedef void* (__fastcall* FindType)(void* name, void* handler);

    /**@brief the game's allocator, so the nodes are freed by the heap that frees them*/
    const uintptr_t OPERATOR_NEW = 0x79602F;
    typedef void* (__cdecl* OperatorNew)(unsigned size);

    /**@brief the message, built into \p out; twelve arguments, `ret 0x30`*/
    const uintptr_t CONSTRUCT = 0x29AA70;

    /**
    @brief posts it: logs it, puts it on the map and pops it up, as its type asks

    Five arguments, `ret 0x88`, and the whole of that shape is worth spelling out
    because two of them sit **above** a struct passed by value and are easy to miss:

        4      the handler
        4      the province
        0x78   the message itself
        4      the popup builder below
        4      zero

    The builder is not optional. The post tests it (`0x1112DA`) and skips a whole
    branch when it is null, and hands it to every popup it builds, so a message posted
    without one appears as an empty window.

    Neither this nor the constructor is called through a C++ function pointer, because
    both pass things by value and the sizes have to be the game's exactly: `raiseThrough`
    lays the stack out by hand.
    */
    const uintptr_t POST = 0x110A50;

    /**
    @brief what fills a popup in, and the same pointer at every raise site in the game

    A member function taking the message as its argument, which reads the type's name
    out of it at `+0x20` and builds the localisation keys from there. **This is where
    the text comes from**, which is why a null one leaves the window blank.
    */
    const uintptr_t POPUP_BUILDER = 0xA6040;

    /**
     * **One variable of a message**, as the game builds them inline. The two gaps are
     * left as the compiler left them and zeroed rather than guessed at.
     */
    const unsigned NODE_BYTES = 0x44;
    const unsigned NODE_KEY = 0x00;
    const unsigned NODE_VALUE = 0x1C;
    const unsigned NODE_PREVIOUS = 0x38;
    const unsigned NODE_NEXT = 0x3C;

    /**@brief a std::string's own header, which has to be a valid empty one before assigning*/
    const unsigned STRING_LENGTH = 0x10;
    const unsigned STRING_CAPACITY = 0x14;
    const int SHORT_CAPACITY = 0xF;

    /**@brief `{first, last, count}`, the shape every list in the game has*/
    const unsigned LIST_FIRST = 0x00;
    const unsigned LIST_LAST = 0x04;
    const unsigned LIST_COUNT = 0x08;

    /**@brief the player's tag on the game state, the pair ShatterUnit compares against*/
    const uintptr_t STATE_PLAYER_TAG = 0xC30;
    const uintptr_t STATE_PLAYER_ID = 0xC34;

    /**@brief two words off the country the constructor keeps; not identified, only passed on*/
    const uintptr_t COUNTRY_A = 0xCA4;
    const uintptr_t COUNTRY_B = 0xCA8;

    /**
     * **How many messages may wait at once.** The queue is drained every frame, so
     * reaching this means something is producing them faster than the game can show them
     * and the excess is better dropped loudly than accumulated.
     */
    const size_t MOST_QUEUED = 64;

    /**@brief a queued message, holding its own copies of everything it needs*/
    struct Request
    {
        std::string type;
        std::vector<std::pair<std::string, std::string> > variables;
        uintptr_t country;
        uintptr_t province;
    };

    std::vector<Request> waiting;

    /**
     * Guards the queue. Everything measured so far runs on one thread - the posts, the
     * popup fills and the idler all reported the same id - but a queue written by the
     * overlay and read by the game's update is exactly the shape that stops being true
     * quietly, and a critical section costs nothing per frame.
     */
    struct Guard
    {
        CRITICAL_SECTION section;
        Guard() { InitializeCriticalSection(&section); }
        ~Guard() { DeleteCriticalSection(&section); }
    };
    Guard guard;

    /**@brief the count, read without the lock so an empty frame costs one load*/
    volatile LONG waitingCount = 0;

    uintptr_t base = 0;
    bool resolved = false;
    bool ok = false;
    const char* statusText = "not resolved yet";

    BuildVariables buildVariables = nullptr;
    GetHandler getHandler = nullptr;
    FindType findType = nullptr;
    OperatorNew gameNew = nullptr;
    DWORD constructAt = 0;
    DWORD postAt = 0;
    DWORD popupBuilder = 0;

    /**@brief what raiseThrough pushes; set immediately before it and read by it*/
    void* argVariables = nullptr;
    uintptr_t argProvince = 0;
    void* argHead = nullptr;
    int argPlayerTag = 0;
    int argPlayerId = 0;
    int argCountryA = 0;
    int argCountryB = 0;
    void* argType = nullptr;
    void* argHandler = nullptr;

    /**
    @brief builds the message and posts it, laid out the way the game lays it out

    **Written out rather than called through a function pointer** because both calls pass
    things by value on the stack and the sizes have to match the game's exactly - a
    mistake there is a crash inside the game, not a wrong argument.

        push 0           the post's last two arguments, which sit above the message
        push builder
        sub esp, 0x78    the message
        sub esp, 8       the constructor's last two arguments
        10 pushes        its first ten
        call construct   cleans 0x30, leaving esp on the message
        push province
        push handler
        call post        cleans 0x88 - 8, the 0x78 message, and the pair above it

    The two arguments above the message have to be in place before the message is,
    which is the whole reason the order here is not the order the post reads them in.

    esp is restored from ebp at the end regardless, so a callee that cleans a different
    amount than expected cannot unwind into the caller.
    */
    __declspec(naked) void raiseThrough() {
        __asm {
            push ebp
            mov ebp, esp
            push ebx
            push esi
            push edi

            push 0
            push [popupBuilder]         // above the message, so pushed before it

            sub esp, 0x78
            mov ebx, esp                // the message
            mov edi, esp
            mov ecx, 0x1E
            xor eax, eax
            rep stosd                   // a message the constructor does not fill is zero

            sub esp, 8
            mov dword ptr [esp], 0
            mov dword ptr [esp + 4], 0

            push [argCountryB]
            push [argCountryA]
            push [argPlayerId]
            push [argPlayerTag]
            push 0
            push [argHead]
            push [argProvince]
            push [argVariables]
            push [argType]
            push ebx
            call [constructAt]

            push [argProvince]
            push [argHandler]
            call [postAt]

            lea esp, [ebp - 12]
            pop edi
            pop esi
            pop ebx
            mov esp, ebp
            pop ebp
            ret
        }
    }

    bool resolve() {
        if (resolved) {
            return ok;
        }
        resolved = true;

        base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0) {
            statusText = "hoi3_tfh.exe is not loaded";
            return false;
        }
        buildVariables = reinterpret_cast<BuildVariables>(base + BUILD_VARIABLES);
        getHandler = reinterpret_cast<GetHandler>(base + GET_HANDLER);
        findType = reinterpret_cast<FindType>(base + FIND_TYPE);
        gameNew = reinterpret_cast<OperatorNew>(base + OPERATOR_NEW);
        constructAt = static_cast<DWORD>(base + CONSTRUCT);
        postAt = static_cast<DWORD>(base + POST);
        popupBuilder = static_cast<DWORD>(base + POPUP_BUILDER);

        ok = true;
        statusText = "ready";
        return true;
    }

    /**@brief makes an empty std::string of the game's shape where one has to exist already*/
    void emptyStringAt(unsigned char* at) {
        memset(at, 0, 0x18);
        *reinterpret_cast<int*>(at + STRING_CAPACITY) = SHORT_CAPACITY;
        *reinterpret_cast<int*>(at + STRING_LENGTH) = 0;
    }

    /**
    @brief links one variable onto the end of the list

    The game does this inline at every message it raises; this is the same steps. The
    node is taken from the **game's** allocator, because the list is handed to the
    constructor and freed by the executable's heap, which is not this DLL's.
    */
    bool appendVariable(void* list, const char* key, const char* value) {
        unsigned char* node = static_cast<unsigned char*>(gameNew(NODE_BYTES));
        if (node == nullptr) {
            return false;
        }
        memset(node, 0, NODE_BYTES);

        emptyStringAt(node + NODE_KEY);
        Game::assignTo(node + NODE_KEY, key);
        emptyStringAt(node + NODE_VALUE);
        Game::assignTo(node + NODE_VALUE, value);

        unsigned char* head = static_cast<unsigned char*>(list);
        void** first = reinterpret_cast<void**>(head + LIST_FIRST);
        void** last = reinterpret_cast<void**>(head + LIST_LAST);
        int* count = reinterpret_cast<int*>(head + LIST_COUNT);

        *reinterpret_cast<void**>(node + NODE_PREVIOUS) = *last;
        *reinterpret_cast<void**>(node + NODE_NEXT) = nullptr;
        if (*count != 0 && *last != nullptr) {
            *reinterpret_cast<void**>(static_cast<unsigned char*>(*last) + NODE_NEXT) = node;
        }
        else {
            *first = node;
        }
        *last = node;
        *count = *count + 1;
        return true;
    }
}

Game::Message::Message(const char* type) : type_(type == nullptr ? "" : type) {
}

Game::Message& Game::Message::with(const char* key, const char* value) {
    if (key != nullptr && *key != '\0') {
        variables_.push_back(std::make_pair(std::string(key),
            std::string(value == nullptr ? "" : value)));
    }
    return *this;
}

uintptr_t Game::playerCountry() {
    const uintptr_t state = CCurrentGameState::current();
    int playerId = 0;
    if (state == 0 || !Mem::tryRead(state + STATE_PLAYER_ID, playerId)) {
        return 0;
    }
    // Through findById rather than indexing the array by id: it walks, on the grounds
    // that nothing established the array is in id order, and there is no reason for this
    // to assume what that does not.
    return CCountry::findById(playerId);
}

bool Game::Message::forPlayer(uintptr_t country) {
    const uintptr_t state = CCurrentGameState::current();
    int player = 0;
    int owner = 0;
    if (state == 0 || country == 0
        || !Mem::tryRead(state + STATE_PLAYER_ID, player)
        || !Mem::tryRead(country + COUNTRY_B, owner)) {
        return false;
    }
    return player == owner;
}

bool Game::Message::available() {
    return resolve();
}

const char* Game::Message::status() {
    return statusText;
}

bool Game::Message::raise(uintptr_t country, uintptr_t province) {
    if (!resolve() || country == 0 || type_.empty()) {
        return false;
    }
    const uintptr_t state = CCurrentGameState::current();
    if (state == 0) {
        statusText = "there is no game state to raise a message in";
        return false;
    }

    // The country's own variables first, which is the list everything else is added to.
    void* variables = buildVariables(country);
    if (variables == nullptr) {
        statusText = "the country's message variables could not be built";
        return false;
    }
    for (size_t i = 0; i < variables_.size(); ++i) {
        appendVariable(variables, variables_[i].first.c_str(), variables_[i].second.c_str());
    }

    // The type is looked up through the handler; a name the registry does not hold comes
    // back null, having logged itself, and the message is dropped rather than built.
    Game::String name(type_.c_str());
    void* handler = getHandler();
    void* type = findType(name.raw(), handler);
    if (handler == nullptr || type == nullptr) {
        statusText = "the message type is not one the game knows";
        ERROR_OUT(printf("Game::Message: the game has no message type '%s' - check "
            "interface/messagetypes.txt\n", type_.c_str()));
        return false;
    }

    int playerTag = 0;
    int playerId = 0;
    int countryA = 0;
    int countryB = 0;
    (void)Mem::tryRead(state + STATE_PLAYER_TAG, playerTag);
    (void)Mem::tryRead(state + STATE_PLAYER_ID, playerId);
    (void)Mem::tryRead(country + COUNTRY_A, countryA);
    (void)Mem::tryRead(country + COUNTRY_B, countryB);

    // CCountry::ShatterUnit builds this one from a zero length, so it goes in empty.
    Game::String head;
    argVariables = variables;
    argProvince = province;
    argHead = head.raw();
    argPlayerTag = playerTag;
    argPlayerId = playerId;
    argCountryA = countryA;
    argCountryB = countryB;
    argType = type;
    argHandler = handler;
    raiseThrough();

    statusText = "raised";
    return true;
}

bool Game::Message::queue(uintptr_t country, uintptr_t province) {
    if (country == 0 || type_.empty()) {
        statusText = "nothing to queue";
        return false;
    }
    // Installed here rather than at startup: a session that never raises a message never
    // patches the idler, and the first queue is always early enough - the flush only has
    // to happen before the next frame ends.
    if (!Hooks::MessageQueue::install()) {
        statusText = Hooks::MessageQueue::status();
        ERROR_OUT(printf("Game::Message: nothing will be raised - %s\n", statusText));
        return false;
    }

    bool room = false;
    EnterCriticalSection(&guard.section);
    if (waiting.size() < MOST_QUEUED) {
        Request request;
        request.type = type_;
        request.variables = variables_;
        request.country = country;
        request.province = province;
        waiting.push_back(request);
        waitingCount = static_cast<LONG>(waiting.size());
        room = true;
    }
    LeaveCriticalSection(&guard.section);

    if (!room) {
        statusText = "the message queue is full";
        WARNING_OUT(printf("Game::Message: %u already waiting, dropping '%s'\n",
            static_cast<unsigned>(MOST_QUEUED), type_.c_str()));
        return false;
    }
    statusText = "queued";
    return true;
}

int Game::Message::queued() {
    return static_cast<int>(waitingCount);
}

int Game::Message::flushQueue() {
    // Taken whole before anything is raised, so a message queued by one being raised
    // waits for the next frame rather than extending the walk.
    std::vector<Request> batch;
    EnterCriticalSection(&guard.section);
    batch.swap(waiting);
    waitingCount = 0;
    LeaveCriticalSection(&guard.section);

    int raised = 0;
    for (size_t i = 0; i < batch.size(); ++i) {
        Message message(batch[i].type.c_str());
        for (size_t v = 0; v < batch[i].variables.size(); ++v) {
            message.with(batch[i].variables[v].first.c_str(),
                batch[i].variables[v].second.c_str());
        }
        if (message.raise(batch[i].country, batch[i].province)) {
            ++raised;
        }
    }
    return raised;
}
