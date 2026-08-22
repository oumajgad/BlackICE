#include <Combat/CombatLog.hpp>

#include <Hooks/CCombatHooks.hpp>
#include <MemScan.hpp>

#include <Windows.h>
#include <cstring>

namespace {
    // Offsets read off the constructor of CCombatHistoryEntry at 0x0042f340, which
    // fills every field of an entry from the combat it is given. See
    // reversing/FINDINGS-combat.md.
    const uintptr_t GAME_STATE_POINTER = 0x1689790; // the global sessionActive() reads
    const uintptr_t GAME_STATE_TICK = 0xBDC;

    const uintptr_t COMBAT_ATTACKER = 0x10;
    const uintptr_t COMBAT_DEFENDER = 0x14;
    const uintptr_t COMBAT_PROVINCE = 0x18;
    const uintptr_t COMBAT_FLAG = 0x2B;

    const uintptr_t PROVINCE_ID = 0xD0;

    // A combatant's countries: a pointer at +0x54 and how many at +0x5c. The game
    // writes "---" into an entry when the count is zero, which is how a beaten side
    // ends up nameless - and, confirmed in game, that empty side is the one that lost.
    const uintptr_t COMBATANT_COUNTRIES = 0x54;
    const uintptr_t COMBATANT_COUNTRY_COUNT = 0x5C;

    // A second list of the same shape, holding this side's own countries and keeping
    // them when the one at +0x54 is emptied. That is where the beaten side's name
    // comes from, since by the time a combat is recorded it has no other.
    //
    // Found by scanning a combatant for anything shaped like a country tag. It was
    // first read as the countries on the *other* side, which a battle disproved: ITA
    // attacked ETH and retreated, and the winning ETH combatant had ETH at +0x64.
    const uintptr_t COMBATANT_OWN_COUNTRIES = 0x64;

    // Strength this side lost, in thousandths. Found by capturing a battle and
    // searching for the figure the game reported: 21 losses read back as 21900.
    const uintptr_t COMBATANT_LOSSES = 0x84;

    // The men on this side, kept per subunit type: a vector of counts at +0x74,
    // ending at +0x78, each a thousandth-scaled headcount.
    //
    // Read off the message the game writes when a battle ends, at 0x005745f4, which
    // walks every subunit type there is and sums this array over a thousand to print
    // "out of 25700 troops". Doing the same here rather than hooking that function,
    // because it only runs for battles the player is told about.
    const uintptr_t COMBATANT_MEN_BEGIN = 0x74;
    const uintptr_t COMBATANT_MEN_END = 0x78;
    const int MAX_SUBUNIT_TYPES = 4096;
    const int MEN_CHUNK = 256;

    // The vftable is what separates the kinds of combat - they are different classes
    // rather than one class with a type field. Addresses from the RTTI export,
    // relative to the module.
    //
    // The game numbers them itself, in the virtual at slot 11 that every one of these
    // overrides with a constant: 1 land, 2 naval, 3 air, 4 ground bombing, 5 land
    // bombing, 6 naval bombing. Comparing vftables comes to the same thing and costs
    // no call.
    const uintptr_t VFTABLE_LAND_COMBAT = 0x11C4EE4;
    const uintptr_t VFTABLE_AIR_COMBAT = 0x11C4FD4;
    const uintptr_t VFTABLE_NAVAL_COMBAT = 0x11C4F5C;
    const uintptr_t VFTABLE_GROUND_BOMBING = 0x11B6934;
    const uintptr_t VFTABLE_LAND_BOMBING = 0x11B69AC;
    const uintptr_t VFTABLE_NAVAL_BOMBING = 0x11B6A24;

    CRITICAL_SECTION lock;
    bool lockReady = false;

    Combat::Record records[Combat::MAX_RECORDS];

    // Numbered rather than counted: this only ever goes up, and where a record sits is
    // its number modulo the size of the ring.
    unsigned int writtenTotal = 0;

    // On by default. The point of the feature is a record of the whole campaign, and
    // one that only covers the stretches someone remembered to switch on is not one.
    bool capturing = true;
    const char* reason = "waiting for the hook";

    void ensureLock() {
        if (!lockReady) {
            InitializeCriticalSection(&lock);
            lockReady = true;
        }
    }

    uintptr_t moduleBase() {
        static uintptr_t base = 0;
        if (base == 0) {
            base = Mem::moduleBase("hoi3_tfh.exe");
        }
        return base;
    }

    unsigned int currentTick() {
        const uintptr_t base = moduleBase();
        if (base == 0) {
            return 0;
        }

        uint32_t state = 0;
        if (!Mem::tryRead(base + GAME_STATE_POINTER, state) || state == 0) {
            return 0;
        }

        uint32_t tick = 0;
        if (!Mem::tryRead(state + GAME_STATE_TICK, tick)) {
            return 0;
        }
        return tick;
    }

    /**@brief true if \p address holds a country tag: three characters and an id*/
    bool readTagAt(uintptr_t address, char tag[8], int& id) {
        if (address < 0x10000 || address > 0xFFFF0000) {
            return false;
        }

        unsigned char block[8] = {};
        if (!Mem::tryReadBytes(address, block, sizeof(block))) {
            return false;
        }

        for (int i = 0; i < 3; i++) {
            const unsigned char c = block[i];
            const bool letter = (c >= 'A' && c <= 'Z');
            const bool digit = (c >= '0' && c <= '9');
            if (!letter && !digit) {
                return false; // "---" fails here too, which is what we want
            }
        }
        if (block[3] != 0) {
            return false;
        }

        uint32_t value = 0;
        memcpy(&value, block + 4, sizeof(value));
        if (value >= 1024) {
            return false; // an id, not an arbitrary neighbouring dword
        }

        memcpy(tag, block, 3);
        tag[3] = 0;
        id = static_cast<int>(value);
        return true;
    }

    /**
    @brief how many men this side had in the fight

    The same sum the game itself makes to say what a battle was fought with, so the
    losses beside it can be read as a share of something. Both are in the same
    currency: a loss of 27200 against 25700 men is the 27 casualties of 25700 troops
    the game reports.
    */
    void readMen(uintptr_t combatant, Combat::Side& side) {
        if (combatant == 0) {
            return;
        }

        uint32_t begin = 0;
        uint32_t end = 0;
        if (!Mem::tryRead(combatant + COMBATANT_MEN_BEGIN, begin) ||
            !Mem::tryRead(combatant + COMBATANT_MEN_END, end)) {
            return;
        }
        if (begin == 0 || end < begin || ((end - begin) % 4) != 0) {
            return;
        }

        const uint32_t entries = (end - begin) / 4;
        if (entries > MAX_SUBUNIT_TYPES) {
            return; // not the vector it was taken for
        }

        int total = 0;
        int32_t chunk[MEN_CHUNK] = {};
        for (uint32_t at = 0; at < entries; at += MEN_CHUNK) {
            const uint32_t take = (entries - at < MEN_CHUNK)
                ? (entries - at)
                : static_cast<uint32_t>(MEN_CHUNK);
            if (!Mem::tryReadBytes(begin + at * 4, chunk, take * sizeof(int32_t))) {
                return;
            }

            // A thousandth at a time, the way the game divides each entry before
            // adding it rather than dividing the sum.
            for (uint32_t i = 0; i < take; i++) {
                if (chunk[i] > 0) {
                    total += chunk[i] / 1000;
                }
            }
        }
        side.men = total;
    }

    /**@brief the tag and id of a side, by the same rule the game itself applies*/
    void readSide(uintptr_t combatant, Combat::Side& side) {
        side.address = combatant;
        strcpy_s(side.tag, "---");
        if (combatant == 0) {
            return;
        }

        uint32_t losses = 0;
        if (Mem::tryRead(combatant + COMBATANT_LOSSES, losses)) {
            side.losses = static_cast<int>(losses);
        }

        uint32_t countryCount = 0;
        if (!Mem::tryRead(combatant + COMBATANT_COUNTRY_COUNT, countryCount)) {
            return;
        }
        // Read for both sides. On the loser it is the only thing left naming it; on
        // the winner it can be checked against a name already known.
        uint32_t own = 0;
        if (Mem::tryRead(combatant + COMBATANT_OWN_COUNTRIES, own)) {
            readTagAt(own, side.retainedTag, side.retainedId);
        }

        side.countryCount = static_cast<int>(countryCount);
        side.standing = (countryCount > 0);
        if (countryCount == 0) {
            return; // no country left in the fight, which is what "---" means
        }

        uint32_t countries = 0;
        if (!Mem::tryRead(combatant + COMBATANT_COUNTRIES, countries) || countries == 0) {
            return;
        }

        char tag[4] = {};
        if (Mem::tryReadBytes(countries, tag, 3)) {
            strncpy_s(side.tag, tag, 3);
        }

        uint32_t id = 0;
        if (Mem::tryRead(countries + 4, id)) {
            side.countryId = static_cast<int>(id);
        }
    }

    Combat::Branch branchOf(uintptr_t vftable) {
        const uintptr_t base = moduleBase();
        if (base == 0 || vftable == 0) {
            return Combat::Branch::Unknown;
        }
        if (vftable == base + VFTABLE_LAND_COMBAT) {
            return Combat::Branch::Land;
        }
        if (vftable == base + VFTABLE_AIR_COMBAT) {
            return Combat::Branch::Air;
        }
        if (vftable == base + VFTABLE_NAVAL_COMBAT) {
            return Combat::Branch::Naval;
        }
        if (vftable == base + VFTABLE_GROUND_BOMBING) {
            return Combat::Branch::GroundBombing;
        }
        if (vftable == base + VFTABLE_LAND_BOMBING) {
            return Combat::Branch::LandBombing;
        }
        if (vftable == base + VFTABLE_NAVAL_BOMBING) {
            return Combat::Branch::NavalBombing;
        }
        return Combat::Branch::Unknown;
    }
}

const char* Combat::outcomeName(Outcome outcome) {
    switch (outcome) {
    case Outcome::AttackerWon: return "Attacker";
    case Outcome::DefenderWon: return "Defender";
    default: return "?";
    }
}

const char* Combat::branchName(Branch branch) {
    switch (branch) {
    case Branch::Land: return "Land";
    case Branch::Air: return "Air";
    case Branch::Naval: return "Naval";
    case Branch::GroundBombing: return "Ground bombing";
    case Branch::LandBombing: return "Land bombing";
    case Branch::NavalBombing: return "Naval bombing";
    default: return "?";
    }
}

bool Combat::isBombing(Branch branch) {
    return branch == Branch::GroundBombing ||
        branch == Branch::LandBombing ||
        branch == Branch::NavalBombing;
}

bool Combat::setRecording(bool on) {
    ensureLock();

    if (!on) {
        EnterCriticalSection(&lock);
        capturing = false;
        reason = "stopped";
        LeaveCriticalSection(&lock);
        return true;
    }

    // The hook stays in place once installed; only the flag turns capture on and off,
    // so stopping and starting again costs nothing and patches nothing twice.
    if (!Hooks::Combat::install()) {
        EnterCriticalSection(&lock);
        capturing = false;
        reason = Hooks::Combat::status();
        LeaveCriticalSection(&lock);
        return false;
    }

    EnterCriticalSection(&lock);
    capturing = true;
    reason = "recording";
    LeaveCriticalSection(&lock);
    return true;
}

bool Combat::recording() {
    return capturing;
}

const char* Combat::status() {
    return reason;
}

void Combat::note(uintptr_t combat) {
    if (!capturing || combat == 0) {
        return;
    }
    ensureLock();

    // Everything is read before the lock is taken: this runs on the game's own thread,
    // in the middle of it finishing a combat, and holding a lock across a dozen reads
    // is a worse idea than copying into a local first.
    Record record;
    record.combat = combat;
    record.tick = currentTick();

    uint32_t vftable = 0;
    if (Mem::tryRead(combat, vftable)) {
        record.vftable = vftable;
        record.branch = branchOf(vftable);
    }

    uint8_t flag = 0;
    if (Mem::tryRead(combat + COMBAT_FLAG, flag)) {
        record.flag = flag;
    }

    uint32_t province = 0;
    if (Mem::tryRead(combat + COMBAT_PROVINCE, province) && province != 0) {
        uint32_t id = 0;
        if (Mem::tryRead(province + PROVINCE_ID, id)) {
            record.provinceId = static_cast<int>(id);
        }
    }

    uint32_t attacker = 0;
    uint32_t defender = 0;
    if (!Mem::tryRead(combat + COMBAT_ATTACKER, attacker)) {
        attacker = 0;
    }
    if (!Mem::tryRead(combat + COMBAT_DEFENDER, defender)) {
        defender = 0;
    }
    readSide(attacker, record.attacker);
    readSide(defender, record.defender);
    readMen(attacker, record.attacker);
    readMen(defender, record.defender);

    // Who won, which is simply who still had a country in the fight. The game's own
    // recording asks the same question to decide whether to write a tag or "---", so
    // this is its rule rather than one of ours.
    if (record.attacker.standing != record.defender.standing) {
        record.winner = record.attacker.standing
            ? Outcome::AttackerWon
            : Outcome::DefenderWon;

        // And give the beaten side back the name the game left out, from the second
        // list it still holds at +0x64.
        //
        // Only where the winner's own +0x64 names the winner, though. That answer is
        // already known, from the list the winner still has at +0x54, so it costs
        // nothing to ask and it is the difference between reading a field and hoping
        // about one - this offset has been misread once already. Failing leaves the
        // loser "---" and the combat counted for nobody, which beats a wrong country
        // in a record that is never checked again.
        Side& winner = record.attacker.standing ? record.attacker : record.defender;
        Side& loser = record.attacker.standing ? record.defender : record.attacker;
        if (loser.retainedTag[0] != 0 &&
            strcmp(winner.retainedTag, winner.tag) == 0) {
            strncpy_s(loser.tag, loser.retainedTag, _TRUNCATE);
            loser.countryId = loser.retainedId;
        }
    }

    EnterCriticalSection(&lock);
    records[writtenTotal % MAX_RECORDS] = record;
    writtenTotal++;
    LeaveCriticalSection(&lock);
}

unsigned int Combat::written() {
    return writtenTotal;
}

unsigned int Combat::oldestKept() {
    const unsigned int total = writtenTotal;
    return (total > MAX_RECORDS) ? (total - MAX_RECORDS) : 0u;
}

bool Combat::copySequence(unsigned int sequence, Record& out) {
    ensureLock();
    bool ok = false;

    EnterCriticalSection(&lock);
    const bool tooNew = sequence >= writtenTotal;
    const bool overwritten = (writtenTotal - sequence) > MAX_RECORDS;
    if (!tooNew && !overwritten) {
        out = records[sequence % MAX_RECORDS];
        ok = true;
    }
    LeaveCriticalSection(&lock);
    return ok;
}

void Combat::clear() {
    ensureLock();
    EnterCriticalSection(&lock);
    writtenTotal = 0;
    LeaveCriticalSection(&lock);
}
