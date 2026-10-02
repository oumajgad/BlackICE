#include <GameState/EventCandidates.hpp>
#include <GameState/GameClock.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <string.h>

namespace {
    // RebuildCountryEventCandidates, rva 0x5C0050: `__stdcall`, one argument, the event
    // list. Pass 1 frees every country's candidate list, with no filter; pass 2 refills
    // them from the event list, skipping an event with no options, one that is
    // is_triggered_only, and one that is fire_only_once and has already fired.
    const uintptr_t REBUILD = 0x5C0050;

    // `push ebp; mov ebp, esp; push -1; push <SEH handler>`. Only the six opcode bytes can
    // be compared literally.
    //
    // **The operand of that push must not be**, and comparing it as a literal is what made
    // the first working version of this fail every time. It is an absolute address, the
    // image has a type-3 relocation sitting exactly on it (rva 0x5C0056) and is built
    // DYNAMIC_BASE, so the loader rewrites it whenever the module lands anywhere other
    // than 0x400000 - which it usually does; a crash dump from this month had the game at
    // 0x380000. The bytes on disk are not the bytes in memory. Checked against
    // `base + rva` instead, the way CrashSave.cpp checks the save writer.
    const unsigned char REBUILD_HEAD[] = { 0x55, 0x8B, 0xEC, 0x6A, 0xFF, 0x68 };

    // The handler the push refers to, as an rva: VA 0xC2A8D1 at the preferred base.
    const uintptr_t REBUILD_SEH_HANDLER = 0x82A8D1;

    // g_event_list, rva 0x1715670: the CList of every CEvent the scenario loaded, and the
    // argument the rebuild takes. The monthly pass creates it if it is null; this does
    // not - a null one means the scenario has not finished loading, and there is nothing
    // to filter yet.
    const uintptr_t EVENT_LIST = 0x1715670;

    // The candidate list on a CCountry: a CList, first at +0x8, last at +0xC, count at
    // +0x10. Reading the count is the cheapest way to see the bug and the fix - it is 0
    // for every country after a load and in the hundreds once the lists are built.
    const uintptr_t CANDIDATE_COUNT = 0x10;

    typedef void(__stdcall* Rebuild)(uintptr_t eventList);

    EventCandidates::Status current;

    /**@brief the rebuild, guarded; false if the call itself faulted*/
    bool callRebuild(Rebuild function, uintptr_t eventList) {
        __try {
            function(eventList);
            return true;
        }
        __except (EXCEPTION_EXECUTE_HANDLER) {
            return false;
        }
    }

    /**@brief how many candidate events the country being played has, or -1 if unknown*/
    int playerCandidateCount(std::string& tagOut) {
        const uintptr_t state = CCurrentGameState::current();
        if (state == 0) {
            return -1;
        }
        tagOut = HDS::readTag(state + CCurrentGameState::Offsets::player_tag);
        const uintptr_t country = CCountry::findByTag(tagOut);
        int32_t count = 0;
        if (country == 0 || !Mem::tryRead(country + CANDIDATE_COUNT, count)) {
            return -1;
        }
        return count;
    }

    /**@brief records that the call was asked for and could not be made*/
    bool refuse(const char* why) {
        current.ran = true;
        current.ok = false;
        current.lastError = why;
        ERROR_OUT(printf("EventCandidates: not rebuilding the event lists - %s\n", why));
        return false;
    }
}

bool EventCandidates::rebuildNow() {
    current = EventCandidates::Status();

    // The game's own flag, which is the one it asks itself before touching live data.
    if (!CCurrentGameState::inGame()) {
        return refuse("no game is on screen");
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        return refuse("the game module could not be found");
    }

    const unsigned char* head = reinterpret_cast<const unsigned char*>(base + REBUILD);
    uint32_t handler = 0;
    const bool headOk = memcmp(head, REBUILD_HEAD, sizeof(REBUILD_HEAD)) == 0;
    const bool handlerOk =
        Mem::tryRead(base + REBUILD + sizeof(REBUILD_HEAD), handler)
        && handler == base + REBUILD_SEH_HANDLER;
    if (!headOk || !handlerOk) {
        ERROR_OUT(printf("EventCandidates: head %s, handler %s (read 0x%08X, wanted "
            "0x%08X)\n", headOk ? "ok" : "wrong", handlerOk ? "ok" : "wrong", handler,
            (uint32_t)(base + REBUILD_SEH_HANDLER)));
        return refuse("the engine's rebuild is not what this build expects");
    }

    uintptr_t eventList = 0;
    if (!Mem::tryRead(base + EVENT_LIST, eventList) || eventList == 0) {
        return refuse("the scenario's event list does not exist yet");
    }

    // The same byte the monthly pass gates its own call on, and it is the tutorial flag -
    // not "a save or a load is in progress", which is what this check claimed until
    // 2026-09-30. The only writers in the executable are two CTutorialScreen button
    // handlers, and while it is set the engine deliberately runs with the event system
    // off: the daily pass skips the event pass and the monthly pass skips this very
    // rebuild. So matching the engine means refusing here too, and the reason is that a
    // tutorial is meant to have no events rather than that anything is busy.
    //
    // It is zero in every ordinary game, loaded ones included, so this has never actually
    // stopped a rebuild. Kept because following the engine's own gate is the point.
    const uintptr_t state = CCurrentGameState::current();
    uint8_t tutorial = 0;
    if (state == 0) {
        return refuse("no game state");
    }
    if (!Mem::tryRead(state + CCurrentGameState::Offsets::tutorial_active, tutorial)
        || tutorial != 0) {
        return refuse("a tutorial is running, which the engine runs without events");
    }

    // Measured either side of the call, because it tests the diagnosis as well as the
    // fix: if `before` is already in the hundreds then a load does build these lists
    // after all and the barrage has some other cause.
    std::string tag;
    const int before = playerCandidateCount(tag);

    const bool ok = callRebuild(reinterpret_cast<Rebuild>(base + REBUILD), eventList);
    current.ran = true;
    current.ok = ok;
    current.ranTick = GameClock::tick();
    current.playerTag = tag;
    current.countBefore = before;
    if (!ok) {
        current.lastError = "the rebuild faulted";
        ERROR_OUT(printf("EventCandidates: the rebuild faulted at tick %d\n", current.ranTick));
        return false;
    }

    current.lastError.clear();
    current.countAfter = playerCandidateCount(tag);
    INFO_OUT(printf("EventCandidates: rebuilt every country's candidate event list at tick "
        "%d (day %d, hour %d); %s went from %d candidates to %d\n", current.ranTick,
        GameClock::day(), GameClock::hour(), tag.c_str(), before, current.countAfter));
    return true;
}

EventCandidates::Status EventCandidates::status() {
    return current;
}
