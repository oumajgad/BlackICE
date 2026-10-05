#include <Hooks/UnassignSelected.hpp>

#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CInGameIdler.hpp>
#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <vector>

namespace {

    /**
     * The command post at the end of `CConfirmRemoveAll`'s confirm handler, which is its
     * override of `CEU3Dialog` slots 5 and 6 (rva 0x348840). Eleven bytes, five
     * instructions:
     *
     *     0x7489A0  8B 48 38   mov ecx, [eax+0x38]     ; eax is the dispatcher
     *     0x7489A3  8B 01      mov eax, [ecx]          ; ecx is the command queue
     *     0x7489A5  8B 50 18   mov edx, [eax+0x18]     ; slot 6, the post
     *     0x7489A8  57         push edi                ; edi is the command
     *     0x7489A9  FF D2      call edx
     *
     * The whole sequence is replaced because the decision is "post this, or post something
     * else instead", which is the call itself. Eleven bytes is room for the jump and six
     * nops. `eax` and `edi` are the two things the stub needs and both are live here.
     *
     * Four instructions earlier, at 0x748904, the handler built the command with
     * `CRemoveAllLeadersCommand::CRemoveAllLeadersCommand(new(0x44), playerTag, playerId)`.
     */
    const uintptr_t POST_SITE = 0x3489A0;
    const int POST_LENGTH = 11;

    const unsigned char EXPECTED_POST[POST_LENGTH] = {
        0x8B, 0x48, 0x38,           // mov ecx, [eax+0x38]
        0x8B, 0x01,                 // mov eax, [ecx]
        0x8B, 0x50, 0x18,           // mov edx, [eax+0x18]
        0x57,                       // push edi
        0xFF, 0xD2                  // call edx
    };

    /**
     * `CAssignLeaderCommand`'s constructor, rva 0x1D7430. `ret 0x10` - four stack
     * arguments, callee cleaned, the object back in eax:
     *
     *     CAssignLeaderCommand* ctor(void* obj, CUnit* unit, CLeader* leader, bool flag)
     *
     * `unit` becomes the persistent reference at +0x3C/+0x40/+0x44 through 0x42DD70 and
     * `leader` the one at +0x64/+0x68/+0x6C through 0x7C9530, which is why the command
     * survives a save and resolves on every client. `flag` lands on the byte at +0x8C.
     *
     * The object is 0x90 bytes - both GUI call sites `push 0x90` before `operator new`.
     *
     * **This is the game's own way to unassign one unit's leader.** The site at rva
     * 0x36955C builds exactly `ctor(obj, unit, CLeader::null(), 1)`, and
     * `CRemoveAllLeadersCommand::Execute` does the same thing by hand, per unit, with
     * `CUnit::SetLeader(CLeader::null(), 1, 0)`.
     */
    const uintptr_t ASSIGN_LEADER_CTOR = 0x1D7430;
    const unsigned int ASSIGN_LEADER_SIZE = 0x90;

    /**@brief the lazily built empty leader, rva 0x17F510 - bare `ret`, no arguments*/
    const uintptr_t CLEADER_NULL = 0x17F510;

    /**@brief `operator new`, rva 0x79602F*/
    const uintptr_t OPERATOR_NEW = 0x79602F;

    /**
     * `CRemoveAllLeadersCommand`'s virtual table. Checked before the unused command is
     * destroyed, so a build where the dialog hands us something else leaks 0x44 bytes
     * instead of calling a destructor through the wrong table.
     */
    const uintptr_t REMOVE_ALL_VFTABLE = 0x11C8A1C;

    /**
     * The flag the per-unit command carries at +0x8C. **What it does is not established**;
     * 1 is what rva 0x36955C passes, which is the site that builds the same command this
     * does - an assign-the-empty-leader - while the two swap sites pass 0. Tested working
     * in single player and multiplayer with 1. Queued in `reversing/CANDIDATES.md` under
     * "Open, not scheduled".
     */
    const int ASSIGN_FLAG = 1;

    // The stub is naked assembly, where a displacement has to be written as a literal.
    static_assert(CUnit::Offsets::leader_ptr == 0x12C, "selectedOwnUnits reads +0x12C");
    static_assert(CUnit::Offsets::owner + CCountryTag::Offsets::id == 0x128,
        "selectedOwnUnits reads the owner id at +0x128");
    static_assert(CUnit::Offsets::expeditionary_owner + CCountryTag::Offsets::id == 0x290,
        "selectedOwnUnits reads the expeditionary owner id at +0x290");

    typedef void* (__cdecl* OperatorNew)(unsigned int size);
    typedef uintptr_t(__cdecl* NullLeader)();
    typedef void* (__stdcall* AssignLeaderCtor)(void* obj, uintptr_t unit, uintptr_t leader,
        int flag);
    typedef void(__thiscall* PostCommand)(uintptr_t queue, uintptr_t command);
    typedef void(__thiscall* DeleteCommand)(uintptr_t command, int freeIt);

    DWORD jumpBack = 0;             // absolute, the instruction after the post

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the stub before anything else. While this is clear the stub reproduces, in
    // assembly, exactly the instructions it replaced.
    unsigned char activeFlag = 0;

    /**
    @brief whether either Ctrl is down right now

    `GetAsyncKeyState`, the same way the Alt hint in `EffectText/LoadOobText.cpp` reads
    its key. `VK_CONTROL` is both Ctrl keys; the high bit is "down now" and the low bit,
    "pressed since last asked", is deliberately not used - it would latch a tap from
    somewhere else entirely.

    This is read in the **dialog's own handler**, on the machine whose player clicked the
    button, which is the one place a local keypress may be read: what leaves this function
    is a list of units, not a decision another client has to reproduce.
    */
    bool ctrlHeld() {
        return (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
    }

    /**
    @brief the selected units whose leader the remove-all command would have stripped

    The selection is a list on the in game screen whose nodes point straight at the
    selected objects, so a unit is recognised by its own virtual table and a province in
    the selection simply never matches.

    The three filters are the ones `CRemoveAllLeadersCommand::Execute` itself applies, so
    Ctrl removes leaders from a subset of exactly what the button would have done and
    never from anything outside it:

    - a unit on loan to another country is skipped (`expeditionary_owner`'s id set), which
      is that loop's own and only skip;
    - a unit that is not the played country's is skipped;
    - a unit with no leader is skipped, because assigning the empty leader to it would be
      a command that does nothing.
    */
    std::vector<uintptr_t> selectedOwnUnits(uint32_t playedId) {
        std::vector<uintptr_t> units;
        const uintptr_t idler = CInGameIdler::current();
        if (idler == 0) {
            return units;
        }
        uintptr_t node = 0;
        if (!Mem::tryRead(idler + CInGameIdler::Offsets::selection + HDS::ListOffsets::first,
                node)) {
            return units;
        }
        const uintptr_t base = Hooks::MODULE_BASE;
        const uintptr_t unitTables[3] = {
            base + CUnit::VFTable::CArmy,
            base + CUnit::VFTable::CNavy,
            base + CUnit::VFTable::CAir,
        };
        const uintptr_t emptyLeader =
            reinterpret_cast<NullLeader>(base + CLEADER_NULL)();

        // Walked as offsets, so nothing is dereferenced that was not read through tryRead
        // first. Bounded because this runs inside the game's own click handler.
        for (int guard = 0; node != 0 && guard < 4096; guard++) {
            uintptr_t unit = 0;
            uintptr_t next = 0;
            if (!Mem::tryRead(node + HDS::NodeOffsets::data, unit)
                || !Mem::tryRead(node + HDS::NodeOffsets::next, next)) {
                break;
            }
            node = next;

            uintptr_t vftable = 0;
            if (unit == 0 || !Mem::tryRead(unit, vftable)) {
                continue;
            }
            bool isUnit = false;
            for (int i = 0; i < 3; i++) {
                if (vftable == unitTables[i]) {
                    isUnit = true;
                }
            }
            if (!isUnit) {
                continue;               // a province, or something else selectable
            }

            uint32_t expeditionary = 0;
            uint32_t owner = 0;
            uintptr_t leader = 0;
            if (!Mem::tryRead(unit + CUnit::Offsets::expeditionary_owner
                    + CCountryTag::Offsets::id, expeditionary)
                || !Mem::tryRead(unit + CUnit::Offsets::owner + CCountryTag::Offsets::id,
                    owner)
                || !Mem::tryRead(unit + CUnit::Offsets::leader_ptr, leader)) {
                continue;
            }
            if (expeditionary != 0 || owner != playedId) {
                continue;
            }
            if (leader == 0 || leader == emptyLeader) {
                continue;               // nothing to take off it
            }
            units.push_back(unit);
        }
        return units;
    }

    /**@brief post a command through the queue the handler had already resolved*/
    void post(uintptr_t dispatcher, uintptr_t command) {
        uintptr_t queue = 0;
        if (!Mem::tryRead(dispatcher + 0x38, queue) || queue == 0) {
            return;
        }
        uintptr_t vftable = 0;
        uintptr_t slot6 = 0;
        if (!Mem::tryRead(queue, vftable) || vftable == 0
            || !Mem::tryRead(vftable + 0x18, slot6) || slot6 == 0) {
            return;
        }
        reinterpret_cast<PostCommand>(slot6)(queue, command);
    }

    /**
    @brief give back the country-wide command the dialog built and we are not posting

    Through its own virtual slot 0 with the free flag set, which is how the game disposes
    of a command everywhere else (`mov edx,[ecx]; mov eax,[edx]; push 1; call eax`).

    **The table is checked first.** If the object is not what this expects, 0x44 bytes
    leak once per Ctrl-click, which is nothing; calling a destructor through a table that
    is not a `CRemoveAllLeadersCommand`'s would not be.
    */
    void destroyUnused(uintptr_t command) {
        uintptr_t vftable = 0;
        if (!Mem::tryRead(command, vftable)
            || vftable != Hooks::MODULE_BASE + REMOVE_ALL_VFTABLE) {
            ERROR_OUT(printf("UnassignSelected: unexpected command table %#010x, leaked\n",
                static_cast<unsigned>(vftable)));
            return;
        }
        uintptr_t slot0 = 0;
        if (!Mem::tryRead(vftable, slot0) || slot0 == 0) {
            return;
        }
        reinterpret_cast<DeleteCommand>(slot0)(command, 1);
    }

    /**
    @brief build one `CAssignLeaderCommand(unit, CLeader::null(), 1)`

    @return the command, or 0 if it could not be built
    */
    uintptr_t buildUnassign(uintptr_t unit) {
        const uintptr_t base = Hooks::MODULE_BASE;
        void* storage = reinterpret_cast<OperatorNew>(base + OPERATOR_NEW)(ASSIGN_LEADER_SIZE);
        if (storage == 0) {
            return 0;               // operator new throws rather than returning null, but
        }                           // the check costs nothing and documents the contract
        const uintptr_t emptyLeader = reinterpret_cast<NullLeader>(base + CLEADER_NULL)();
        void* built = reinterpret_cast<AssignLeaderCtor>(base + ASSIGN_LEADER_CTOR)(
            storage, unit, emptyLeader, ASSIGN_FLAG);
        return reinterpret_cast<uintptr_t>(built);
    }

    /**
    @brief the C side of the stub: post the country-wide command, or one command per unit

    Called only with the feature switched on. Falls back to posting exactly what the
    dialog built - which is what the button has always done - whenever Ctrl is up or the
    game state cannot be read.

    **Ctrl held with nothing eligible selected posts nothing at all.** That is the safe
    way round rather than the obvious one: the alternative is to fall back to the
    country-wide command, which would unassign every leader in the country at the moment
    the player's intent was plainly a subset, and that is not something a click should do
    by accident. A button that appears to do nothing is recoverable; this is not. If the
    other behaviour is ever wanted, it is the one `post` call this comment sits above.
    */
    void __cdecl decidePost(uintptr_t dispatcher, uintptr_t removeAllCommand) {
        if (!ctrlHeld()) {
            post(dispatcher, removeAllCommand);
            return;
        }
        const uintptr_t state = CCurrentGameState::current();
        uint32_t playedId = 0;
        if (state == 0
            || !Mem::tryRead(state + CCurrentGameState::Offsets::player_tag
                + CCountryTag::Offsets::id, playedId)) {
            post(dispatcher, removeAllCommand);
            return;
        }
        const std::vector<uintptr_t> units = selectedOwnUnits(playedId);
        if (units.empty()) {
            // See above: deliberately not a fall back to the country-wide command.
            destroyUnused(removeAllCommand);
            INFO_OUT(printf("UnassignSelected: Ctrl held with nothing eligible selected,"
                " nothing unassigned\n"));
            return;
        }
        for (size_t i = 0; i < units.size(); i++) {
            const uintptr_t command = buildUnassign(units[i]);
            if (command != 0) {
                post(dispatcher, command);
            }
        }
        destroyUnused(removeAllCommand);
        INFO_OUT(printf("UnassignSelected: %u selected units, %u commands posted\n",
            static_cast<unsigned>(units.size()), static_cast<unsigned>(units.size())));
    }
}

__declspec(naked) void Hooks::UnassignSelected::postHook() {
    __asm {
        cmp activeFlag, 0
        jne takeOver

        // Exactly the five instructions this replaced, and nothing else.
        mov ecx, dword ptr [eax + 0x38]
        mov eax, dword ptr [ecx]
        mov edx, dword ptr [eax + 0x18]
        push edi
        call edx
        jmp [jumpBack]

    takeOver:
        // eax is the dispatcher and edi the command the dialog built. decidePost does the
        // posting itself, either of that command or of one per selected unit, so nothing
        // is posted here. The code after the jump back reloads eax from its own frame and
        // uses ebx, both of which popad restores.
        pushad
        pushfd
        push edi
        push eax
        call decidePost
        add esp, 8
        popfd
        popad

        jmp [jumpBack]
    }
}

bool Hooks::UnassignSelected::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    void* site = reinterpret_cast<void*>(base + POST_SITE);

    // Everything is checked before anything is written, so a build this does not fit
    // leaves the game untouched rather than half patched.
    if (!Hooks::bytesAre(reinterpret_cast<uintptr_t>(site), EXPECTED_POST, POST_LENGTH)) {
        statusText = "the unassign-all dialog is not what this build expects";
        ERROR_OUT(printf("UnassignSelected: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + POST_SITE)));
        return false;
    }

    jumpBack = static_cast<DWORD>(base + POST_SITE + POST_LENGTH);

    // Eleven bytes replaced: five of jump and six nops.
    if (!Hooks::hook(site, Hooks::UnassignSelected::postHook, 5, POST_LENGTH - 5)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("UnassignSelected hook installed at %#010x\n",
        static_cast<unsigned>(base + POST_SITE)));
    return true;
}

bool Hooks::UnassignSelected::installed() {
    return installedFlag;
}

const char* Hooks::UnassignSelected::status() {
    return statusText;
}

void Hooks::UnassignSelected::setActive(bool on) {
    activeFlag = on ? 1u : 0u;
}

bool Hooks::UnassignSelected::active() {
    return activeFlag != 0;
}
