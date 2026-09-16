#include <GameState/CombatLog.hpp>
#include <GameClasses/CCombat.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <HoiDataStructures.hpp>

#include <Hooks/CCombatHooks.hpp>
#include <MemScan.hpp>

#include <Windows.h>
#include <cstring>

namespace {
    // Bounds on the per subunit type vector of men (CCombatant::Offsets::men_begin),
    // which is summed here the way the game's end of battle message sums it, rather
    // than hooking that message: it only runs for battles the player is told about.
    const int MAX_SUBUNIT_TYPES = 4096;
    const int MEN_CHUNK = 256;

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
        return static_cast<unsigned int>(CCurrentGameState::currentTick());
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
        if (!Mem::tryRead(combatant + CCombatant::Offsets::men_begin, begin) ||
            !Mem::tryRead(combatant + CCombatant::Offsets::men_end, end)) {
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
        if (Mem::tryRead(combatant + CCombatant::Offsets::losses, losses)) {
            side.losses = static_cast<int>(losses);
        }

        const uintptr_t countryList = combatant + CCombatant::Offsets::countries;
        uint32_t countryCount = 0;
        if (!Mem::tryRead(countryList + HDS::ListOffsets::count, countryCount)) {
            return;
        }
        // Read for both sides. On the loser it is the only thing left naming it; on
        // the winner it can be checked against a name already known.
        //
        // Found by scanning a combatant for anything shaped like a country tag. It was
        // first read as the countries on the *other* side, which a battle disproved: ITA
        // attacked ETH and retreated, and the winning ETH combatant had ETH in this list.
        uint32_t own = 0;
        if (Mem::tryRead(combatant + CCombatant::Offsets::own_countries + HDS::ListOffsets::first, own)) {
            readTagAt(own + CCountryTag::Offsets::tag, side.retainedTag, side.retainedId);
        }

        side.countryCount = static_cast<int>(countryCount);
        side.standing = (countryCount > 0);
        if (countryCount == 0) {
            return; // no country left in the fight, which is what "---" means
        }

        // The first node, whose CCountryTag is where the game's own history entry takes
        // the side's tag from.
        uint32_t countries = 0;
        if (!Mem::tryRead(countryList + HDS::ListOffsets::first, countries) || countries == 0) {
            return;
        }

        char tag[4] = {};
        if (Mem::tryReadBytes(countries + CCountryTag::Offsets::tag, tag, 3)) {
            strncpy_s(side.tag, tag, 3);
        }

        uint32_t id = 0;
        if (Mem::tryRead(countries + CCountryTag::Offsets::id, id)) {
            side.countryId = static_cast<int>(id);
        }
    }

    Combat::Branch branchOf(uintptr_t vftable) {
        const uintptr_t base = moduleBase();
        if (base == 0 || vftable == 0) {
            return Combat::Branch::Unknown;
        }
        // The kinds are classes of their own rather than one class with a type field,
        // and comparing vftables answers what CCombat::Slots::KIND would without a call.
        if (vftable == base + CCombat::VFTable::CLandCombat) {
            return Combat::Branch::Land;
        }
        if (vftable == base + CCombat::VFTable::CAirCombat) {
            return Combat::Branch::Air;
        }
        if (vftable == base + CCombat::VFTable::CNavalCombat) {
            return Combat::Branch::Naval;
        }
        if (vftable == base + CCombat::VFTable::CGroundBombing) {
            return Combat::Branch::GroundBombing;
        }
        if (vftable == base + CCombat::VFTable::CLandBombing) {
            return Combat::Branch::LandBombing;
        }
        if (vftable == base + CCombat::VFTable::CNavalBombing) {
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
    if (Mem::tryRead(combat + CCombat::Offsets::flag, flag)) {
        record.flag = flag;
    }

    uint32_t province = 0;
    if (Mem::tryRead(combat + CCombat::Offsets::province, province) && province != 0) {
        uint32_t id = 0;
        if (Mem::tryRead(province + CMapProvince::Offsets::id, id)) {
            record.provinceId = static_cast<int>(id);
        }
    }

    uint32_t attacker = 0;
    uint32_t defender = 0;
    if (!Mem::tryRead(combat + CCombat::Offsets::attacker, attacker)) {
        attacker = 0;
    }
    if (!Mem::tryRead(combat + CCombat::Offsets::defender, defender)) {
        defender = 0;
    }
    readSide(attacker, record.attacker);
    readSide(defender, record.defender);
    readMen(attacker, record.attacker);
    readMen(defender, record.defender);

    // Who won, which is who still had a country in the fight. The game's own
    // recording asks the same question to decide whether to write a tag or "---", so
    // this is the game's rule rather than one imposed here.
    if (record.attacker.standing != record.defender.standing) {
        record.winner = record.attacker.standing
            ? Outcome::AttackerWon
            : Outcome::DefenderWon;

        // Give the beaten side back the name the game left out, from the second
        // list it still holds (CCombatant::Offsets::own_countries).
        //
        // Only where the winner's own list names the winner, though. That answer is
        // already known, from the countries list the winner still has, so it costs
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
