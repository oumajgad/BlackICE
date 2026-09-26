#include <Hooks/Tooltips/CombatUnitDamage.hpp>

#include <GameClasses/CCombat.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CRegiment.hpp>
#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    /**
     * **Where a landed shot's damage is worked out**: the `call CUnit::TakeDamage` at rva
     * `0x16B312`, inside CLandCombatant::FireUnit. Five bytes, and a five byte jump stands
     * in for them exactly; the stub makes the call itself.
     *
     * It is the one instruction where the shot is complete and nothing has been spent yet.
     * A hook on TakeDamage's own entry would have the target and the amount but not the
     * unit that fired, which is in ESI here and in no argument anywhere.
     */
    const uintptr_t SITE = 0x16B312;
    const uintptr_t CALL = 0x1CD360;
    const uintptr_t RESUME = 0x16B317;

    /**
     * **Where a tick's damage is actually spent**: the two `sub`s at rva `0x1ABAE4` in
     * CSubUnit::SettleDamage, six bytes between them, with EDI the strength being spent
     * and EBX the organisation **after** the clamp two instructions above has capped it at
     * what the subunit still has.
     *
     * Strength is spent whole, so it is counted at the shot. Organisation is not: the
     * pending total is damage *attempted*, and the clamp throws away whatever exceeds the
     * subunit's organisation - which in a one-sided fight is most of it.
     */
    const uintptr_t SETTLE_SITE = 0x1ABAE4;
    const unsigned char SETTLE_BYTES[6] = { 0x29, 0x7E, 0x5C, 0x29, 0x5E, 0x60 };
    const uintptr_t SETTLE_RESUME = 0x1ABAEA;

    /**
     * How many units are tracked at once, and how far a lookup probes before it gives up
     * and takes somebody else's slot.
     *
     * **Nothing is ever cleared wholesale.** Emptying the table when it fills would take
     * the figures of every unit in every battle at once, with nothing on screen to explain
     * why they had gone. A newcomer evicts **one** unit instead - whoever holds the slot
     * it lands on after probing - so the window slides over the divisions fighting most
     * recently and a stale one falls off the back unnoticed.
     */
    const size_t CAPACITY = 2048;
    const size_t PROBES = 8;

    /**
     * How many separate attackers one unit's organisation damage is split between in a
     * tick. Past this the rest still counts towards the total - so everybody else's share
     * stays right - it simply is not credited to anyone.
     */
    const int MOST_ATTACKERS = 16;

    DWORD takeDamage = 0;
    DWORD resumeAt = 0;
    DWORD settleResume = 0;
    bool installedFlag = false;
    bool saidEvicted = false;
    const char* statusText = "not installed";

    struct Tally
    {
        uintptr_t combat;
        int dealt;
        int taken;

        /**
         * Organisation dealt, in **thousandths of a thousandth**.
         *
         * Taken can be summed raw and divided by this unit's own brigade count when it is
         * read, because every part of it came off this unit. Dealt cannot: each part came
         * off a *different* target with its own brigade count, so it is scaled as it
         * arrives. Scaling by a thousand first keeps that division from truncating a small
         * share to nothing.
         */
        long long dealtOrganisation;
        int takenOrganisation;

        /**
         * The same four figures for **one combat round**, and the tick they belong to.
         *
         * A round is an hour, so damage arriving under a later tick clears these rather
         * than adding to them - which is what keeps them a round's worth instead of a
         * second running total.
         *
         * The tick is read from the game state at the moment the damage lands, not from
         * GameClock: that caches one value a frame, and at high speed the game runs
         * several hours between two frames, which would fold those rounds into one.
         */
        int tick;
        int tickDealt;
        int tickTaken;
        long long tickDealtOrganisation;
        int tickTakenOrganisation;
    };

    /**
     * **Who asked for how much of a unit's organisation this tick.**
     *
     * The two halves arrive in different places: a shot knows the attacker and what it
     * asked for, the settle knows only what was actually spent. Keeping the asks here is
     * what lets the spend be handed back out in proportion, so an attacker that asked for
     * a third of a tick's damage is credited a third of what landed.
     */
    struct Attempt
    {
        uintptr_t attackers[MOST_ATTACKERS];
        int asked[MOST_ATTACKERS];
        int count;
        long long total;
        bool settling;              // a settle has happened, so the next shot starts a tick
    };

    /**
     * One unit's everything, in a fixed table, keyed by the unit's **id** rather than its
     * address.
     *
     * **The id is the safer key, not just the better hash.** A division's `CUnit` is freed
     * when it dies and the allocator hands the same address out again, so a table keyed by
     * pointer silently merges the figures of two different divisions - a new one inherits
     * whatever the dead one had. Ids do not come back. They are also dense small integers,
     * which folds into a bucket far more evenly than a heap pointer whose low bits are
     * alignment.
     *
     * `type` is kept and compared alongside because the id is only unique within it - the
     * game identifies a saved object by the pair, not by the number alone.
     *
     * **Allocated once and never grown**, 2048 of them; the install log prints what
     * that comes to, from `sizeof`, rather than a number here that would go stale. The
     * attempt is most of each entry; it sits beside the tally rather than in a table of
     * its own because a unit being shot at is exactly a unit worth tracking.
     */
    struct Entry
    {
        int type;
        int id;
        bool used;
        Tally tally;
        Attempt attempt;
    };

    Entry entries[CAPACITY];

    /**@brief a unit's (type, id), or false when they cannot be read*/
    bool identify(uintptr_t unit, int& type, int& id) {
        return unit != 0
            && Mem::tryRead(unit + CUnit::Offsets::type, type)
            && Mem::tryRead(unit + CUnit::Offsets::id, id);
    }

    /**
    @brief the slot for a unit, making one if asked

    A bounded-probe hash: eight slots from the id's own, and if all eight belong to someone
    else the first of them is taken over. **That is the only way an entry is ever lost**,
    and it costs one division its figures rather than all of them.
    */
    Entry* entryFor(uintptr_t unit, bool create) {
        int type = 0;
        int id = 0;
        if (!identify(unit, type, id)) {
            return nullptr;
        }

        const size_t start = static_cast<size_t>(static_cast<unsigned>(id)) % CAPACITY;
        size_t free = CAPACITY;
        for (size_t i = 0; i < PROBES; ++i) {
            const size_t at = (start + i) % CAPACITY;
            Entry& entry = entries[at];
            if (entry.used && entry.id == id && entry.type == type) {
                return &entry;
            }
            if (!entry.used && free == CAPACITY) {
                free = at;
            }
        }
        if (!create) {
            return nullptr;
        }

        Entry& entry = entries[free == CAPACITY ? start : free];
        if (free == CAPACITY && !saidEvicted) {
            saidEvicted = true;
            INFO_OUT(printf("CombatUnitDamage: the table is busy enough to be reusing slots; "
                "a division that has not fought lately may lose its figures\n"));
        }
        memset(&entry, 0, sizeof entry);
        entry.type = type;
        entry.id = id;
        entry.used = true;
        return &entry;
    }

    /**
    @brief the unit's tally for this battle, cleared if its last was a different one

    A unit that fought this morning and is fighting again this afternoon should read as the
    afternoon's, not the sum. The combat pointer is the whole test.
    */
    Tally* tallyFor(uintptr_t unit, uintptr_t combat) {
        Entry* entry = entryFor(unit, true);
        if (entry == nullptr) {
            return nullptr;
        }
        if (entry->tally.combat != combat) {
            memset(&entry->tally, 0, sizeof entry->tally);
            entry->tally.combat = combat;
        }
        return &entry->tally;
    }

    /**
    @brief starts this tally's round over when the clock has moved past it

    The round's figures only describe the tick named in `tick`, so the first damage of a
    later one clears them. A tick of zero means the game state could not be read; the
    round then never rolls and reads the same as the battle total, which is wrong in a way
    that shows rather than one that misleads.
    */
    void openRound(Tally& tally, int now) {
        if (tally.tick == now) {
            return;
        }
        tally.tick = now;
        tally.tickDealt = 0;
        tally.tickTaken = 0;
        tally.tickDealtOrganisation = 0;
        tally.tickTakenOrganisation = 0;
    }

    /**
    @brief counts one landed shot, and remembers what it asked of the target's organisation

    `side` is the combatant that fired, and its `combat` (+0x3C) is what tells one battle
    from the next. A shot whose side cannot be read is counted with a combat of zero rather
    than dropped - the figures stay right, only the "which battle" test goes soft.
    */
    void landed(uintptr_t attacker, uintptr_t target, int strength, int organisation,
                uintptr_t side) {
        uintptr_t combat = 0;
        if (side != 0) {
            (void)Mem::tryRead(side + CCombatant::Offsets::combat, combat);
        }

        const int now = CCurrentGameState::currentTick();

        Tally* dealt = tallyFor(attacker, combat);
        if (dealt != nullptr) {
            openRound(*dealt, now);
            dealt->dealt += strength;
            dealt->tickDealt += strength;
        }
        Tally* taken = tallyFor(target, combat);
        if (taken != nullptr) {
            openRound(*taken, now);
            taken->taken += strength;
            taken->tickTaken += strength;
        }

        // Organisation is only *asked for* here. What the target actually loses is decided
        // by the clamp in CSubUnit::SettleDamage and handed back out by `settled`.
        if (organisation <= 0) {
            return;
        }
        Entry* entry = entryFor(target, true);
        if (entry == nullptr) {
            return;
        }
        Attempt& attempt = entry->attempt;
        if (attempt.settling) {
            attempt.count = 0;
            attempt.total = 0;
            attempt.settling = false;
        }
        attempt.total += organisation;
        for (int i = 0; i < attempt.count; ++i) {
            if (attempt.attackers[i] == attacker) {
                attempt.asked[i] += organisation;
                return;
            }
        }
        if (attempt.count < MOST_ATTACKERS) {
            attempt.attackers[attempt.count] = attacker;
            attempt.asked[attempt.count] = organisation;
            ++attempt.count;
        }
    }

    /**@brief how many brigades a division has, or 1 when it cannot be read*/
    int brigadesOf(uintptr_t unit) {
        int brigades = 0;
        if (!Mem::tryRead(unit + CUnit::Offsets::regiments + HDS::ListOffsets::count, brigades)
            || brigades < 1) {
            return 1;
        }
        return brigades;
    }

    /**
    @brief hands the organisation a subunit actually lost back to whoever asked for it

    `organisation` is what the clamp left, for one brigade. Each attacker that asked for
    part of this tick's damage is credited the same part of what landed.

    **The raw per-brigade amount is what is stored.** A division's organisation is the
    average over its brigades, so a total summed a brigade at a time has to be divided by
    the count somewhere - and doing it here, on every settle, truncates every time: a tick
    worth 20 thousandths over seven brigades became 2 rather than 2.86, and a ladder
    measured that way tracked the real drop at 0.96 rather than 1.00. Dividing when the
    figure is read costs one truncation for the whole battle. That is only safe because
    **brigades are never destroyed on their own - a division is lost whole** - so the count
    cannot change under the total.
    */
    void settled(uintptr_t subunit, int organisation) {
        if (subunit == 0 || organisation <= 0) {
            return;
        }
        uintptr_t unit = 0;
        if (!Mem::tryRead(subunit + CRegiment::Offsets::unit_ptr, unit) || unit == 0) {
            return;
        }
        Entry* entry = entryFor(unit, false);
        if (entry == nullptr) {
            return;
        }
        const int now = CCurrentGameState::currentTick();
        openRound(entry->tally, now);
        entry->tally.takenOrganisation += organisation;
        entry->tally.tickTakenOrganisation += organisation;

        Attempt& attempt = entry->attempt;
        if (attempt.total <= 0) {
            return;
        }
        attempt.settling = true;

        // The shares are organisation off *this* target, so they carry its brigade count
        // with them rather than the attacker's.
        const int brigades = brigadesOf(unit);
        for (int i = 0; i < attempt.count; ++i) {
            const long long share =
                static_cast<long long>(organisation) * attempt.asked[i] / attempt.total;
            Entry* who = entryFor(attempt.attackers[i], false);
            if (who != nullptr) {
                const long long scaled = share * 1000 / brigades;
                openRound(who->tally, now);
                who->tally.dealtOrganisation += scaled;
                who->tally.tickDealtOrganisation += scaled;
            }
        }
    }

    /**
    @brief reads the shot off the frame, then makes the call it replaced

    **The stack offsets are the stub's own.** `pushad` and `pushfd` put 36 bytes between
    the stub and what the caller set up, so the two arguments TakeDamage is about to read
    at `[esp]` and `[esp + 4]` are at `[esp + 36]` and `[esp + 40]` here.

    `ebp` is still FireUnit's, so `[ebp + 8]` is the side that fired.
    */
    __declspec(naked) void shotLanded() {
        __asm {
            pushad
            pushfd
            mov ecx, dword ptr [esp + 36]   // the strength damage
            mov edx, dword ptr [esp + 40]   // the organisation asked for
            push dword ptr [ebp + 8]        // the side that fired
            push edx
            push ecx
            push eax                        // the unit being hit
            push esi                        // the unit that fired
            call landed
            add esp, 20
            popfd
            popad

            call [takeDamage]               // exactly the call this replaced
            jmp [resumeAt]
        }
    }

    /**
    @brief does the two subtractions it replaced, counting the organisation on the way

    EDI is the strength being spent and EBX the organisation **after** the clamp; ESI is
    the subunit. Both subtractions are reproduced exactly, in their original order.
    */
    __declspec(naked) void damageSettled() {
        __asm {
            pushad
            pushfd
            push ebx                        // the organisation actually lost
            push esi                        // the subunit losing it
            call settled
            add esp, 8
            popfd
            popad

            sub dword ptr [esi + 0x5c], edi // exactly the two instructions this replaced
            sub dword ptr [esi + 0x60], ebx
            jmp [settleResume]
        }
    }
}

bool Hooks::Tooltips::CombatUnitDamage::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::isCallTo(base + SITE, base + CALL)) {
        statusText = "land combat does not apply damage where this build expects";
        ERROR_OUT(printf("CombatUnitDamage: %#010x is not the call expected\n",
            static_cast<unsigned>(base + SITE)));
        return false;
    }
    if (!Hooks::bytesAre(base + SETTLE_SITE, SETTLE_BYTES, 6)) {
        statusText = "a subunit does not settle its damage where this build expects";
        ERROR_OUT(printf("CombatUnitDamage: %#010x is not the instructions expected\n",
            static_cast<unsigned>(base + SETTLE_SITE)));
        return false;
    }

    memset(entries, 0, sizeof entries);
    takeDamage = static_cast<DWORD>(base + CALL);
    resumeAt = static_cast<DWORD>(base + RESUME);
    settleResume = static_cast<DWORD>(base + SETTLE_RESUME);

    // Six bytes at the settle, so the five byte jump leaves one over as a NOP.
    if (!Hooks::hook(reinterpret_cast<void*>(base + SITE), &shotLanded, 5, 0)
        || !Hooks::hook(reinterpret_cast<void*>(base + SETTLE_SITE), &damageSettled, 5, 1)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("CombatUnitDamage: counting what each unit deals and takes in a land battle, "
        "%u units in %u KB\n", static_cast<unsigned>(CAPACITY),
        static_cast<unsigned>(sizeof entries / 1024)));
    return true;
}

bool Hooks::Tooltips::CombatUnitDamage::installed() {
    return installedFlag;
}

const char* Hooks::Tooltips::CombatUnitDamage::status() {
    return statusText;
}

int Hooks::Tooltips::CombatUnitDamage::dealtBy(uintptr_t unit) {
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : entry->tally.dealt;
}

int Hooks::Tooltips::CombatUnitDamage::takenBy(uintptr_t unit) {
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : entry->tally.taken;
}

int Hooks::Tooltips::CombatUnitDamage::dealtOrganisationBy(uintptr_t unit) {
    // Already scaled per target as it arrived; only the thousand it was kept in comes off.
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : static_cast<int>(entry->tally.dealtOrganisation / 1000);
}

int Hooks::Tooltips::CombatUnitDamage::takenOrganisationBy(uintptr_t unit) {
    // Summed a brigade at a time off this very unit, so one division at the end is both
    // correct and the only place it can truncate.
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : entry->tally.takenOrganisation / brigadesOf(unit);
}

int Hooks::Tooltips::CombatUnitDamage::dealtLastTickBy(uintptr_t unit) {
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : entry->tally.tickDealt;
}

int Hooks::Tooltips::CombatUnitDamage::takenLastTickBy(uintptr_t unit) {
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : entry->tally.tickTaken;
}

int Hooks::Tooltips::CombatUnitDamage::dealtOrganisationLastTickBy(uintptr_t unit) {
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr
        ? 0 : static_cast<int>(entry->tally.tickDealtOrganisation / 1000);
}

int Hooks::Tooltips::CombatUnitDamage::takenOrganisationLastTickBy(uintptr_t unit) {
    const Entry* entry = entryFor(unit, false);
    return entry == nullptr ? 0 : entry->tally.tickTakenOrganisation / brigadesOf(unit);
}

bool Hooks::Tooltips::CombatUnitDamage::known(uintptr_t unit) {
    return entryFor(unit, false) != nullptr;
}
