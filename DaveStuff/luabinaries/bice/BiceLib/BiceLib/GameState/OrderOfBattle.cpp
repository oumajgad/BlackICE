#include <GameState/OrderOfBattle.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CRegiment.hpp>
#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <MemScan.hpp>
#include <TextEncoding.hpp>

#include <Windows.h>
#include <algorithm>
#include <map>
#include <set>
#include <vector>

namespace {
    // What the game's structures look like is in GameClasses, a header per class, so
    // that a field is described in one place and everything that reads it agrees.
    // Reading its strings and lists is HDS. Only the limit below belongs here.

    // A country can field thousands of units; this bounds the damage when the thing
    // being read is not a country after all.
    const int MAX_UNITS = 20000;

    uintptr_t moduleBase() {
        static uintptr_t base = 0;
        if (base == 0) {
            base = Mem::moduleBase("hoi3_tfh.exe");
        }
        return base;
    }

    template <typename T>
    T readValue(uintptr_t address, T fallback = T()) {
        T value = fallback;
        if (!Mem::tryRead(address, value)) {
            return fallback;
        }
        return value;
    }

    Oob::Branch branchOf(uintptr_t unit) {
        const uintptr_t base = moduleBase();
        if (base == 0) {
            return Oob::Branch::Unknown;
        }

        uint32_t vftable = 0;
        if (!Mem::tryRead(unit, vftable) || vftable == 0) {
            return Oob::Branch::Unknown;
        }

        if (vftable == base + CUnit::VFTable::CArmy) {
            return Oob::Branch::Land;
        }
        if (vftable == base + CUnit::VFTable::CNavy) {
            return Oob::Branch::Naval;
        }
        if (vftable == base + CUnit::VFTable::CAir) {
            return Oob::Branch::Air;
        }
        return Oob::Branch::Unknown;
    }

    void readLeader(uintptr_t leader, Oob::Unit& unit) {
        if (leader == 0) {
            return;
        }
        unit.leaderName = HDS::readString(leader + CLeader::Offsets::name);
        unit.leaderSkill = readValue<int32_t>(leader + CLeader::Offsets::skill);
        unit.leaderMaxSkill = readValue<int32_t>(leader + CLeader::Offsets::max_skill);

        // An unled unit still has something in the leader slot; the game calls it
        // "(no leader)". So a pointer is not enough to go on.
        unit.hasLeader = unit.leaderName.find("(no leader)") == std::string::npos;
    }

    /**@brief fills in everything one unit knows about itself*/
    Oob::Unit readUnit(uintptr_t address, Oob::Branch branch) {
        Oob::Unit unit;
        unit.address = address;
        unit.branch = branch;
        unit.name = HDS::readString(address + CUnit::Offsets::name);
        unit.id = readValue<int32_t>(address + CUnit::Offsets::id);
        unit.type = readValue<int32_t>(address + CUnit::Offsets::type);
        unit.level = readValue<int32_t>(address + CUnit::Offsets::oob_level);
        unit.selected = readValue<uint8_t>(address + CUnit::Offsets::is_selected) != 0;

        unit.supplyPercent = readValue<int32_t>(address + CUnit::Offsets::supply_received_percentage);
        unit.fuelPercent = readValue<int32_t>(address + CUnit::Offsets::fuel_received_percentage);
        unit.digIn = readValue<int32_t>(address + CUnit::Offsets::dig_in_level);
        unit.combatArmsBonus = readValue<int32_t>(address + CUnit::Offsets::base_ca_bonus);
        unit.combatCooldown = readValue<int32_t>(address + CUnit::Offsets::combat_cooldown);

        unit.upgradePriority = readValue<uint8_t>(address + CUnit::Offsets::upgrade_prio) != 0;
        unit.upgradeActive = readValue<uint8_t>(address + CUnit::Offsets::upgrade_active) != 0;
        unit.reinforcementsActive =
            readValue<uint8_t>(address + CUnit::Offsets::reinforcements_active) != 0;

        unit.regimentCount = readValue<int32_t>(address + CUnit::Offsets::regiments_amount);
        if (unit.regimentCount < 0 || unit.regimentCount > 1000) {
            unit.regimentCount = 0;
        }

        // Asked of the game rather than worked out here, so that the leader and
        // country effects are the ones the game's own tooltip shows. Only worth
        // asking for a unit that has regiments: the answer is zero otherwise.
        if (unit.regimentCount > 0) {
            unit.supplyConsumption = CUnit::supplyConsumption(address);
            unit.fuelConsumption = CUnit::fuelConsumption(address);
        }

        unit.leader = readValue<uint32_t>(address + CUnit::Offsets::leader_ptr);
        readLeader(unit.leader, unit);

        unit.province = readValue<uint32_t>(address + CUnit::Offsets::current_province_ptr);
        if (unit.province != 0) {
            unit.provinceId = readValue<int32_t>(unit.province + CMapProvince::Offsets::id);
        }

        // A division made of a single brigade takes no commander, so it is not
        // missing one. Exactly one regiment, not "one or fewer": a count that failed
        // to read comes back as zero, and that should show up as a unit worth looking
        // at rather than quietly excuse itself.
        const bool takesNoLeader = (unit.level == CUnit::Level::Division) && (unit.regimentCount == 1);
        unit.leaderMissing = !unit.hasLeader && !takesNoLeader;

        return unit;
    }

    /**
    @brief compares two names the way someone reading a list would

    Case insensitive, and only for the ASCII range: the game's text is converted to
    UTF-8 on the way in, so an umlaut is two bytes and sorts by the first of them.
    Good enough for putting a list in order, and it does not need a locale to do it.
    */
    int compareNames(const std::string& a, const std::string& b) {
        const size_t shorter = (a.size() < b.size()) ? a.size() : b.size();
        for (size_t i = 0; i < shorter; i++) {
            const int left = tolower(static_cast<unsigned char>(a[i]));
            const int right = tolower(static_cast<unsigned char>(b[i]));
            if (left != right) {
                return (left < right) ? -1 : 1;
            }
        }
        if (a.size() == b.size()) {
            return 0;
        }
        return (a.size() < b.size()) ? -1 : 1;
    }

    /**@brief orders unit indices by name, falling back on the game's id so that two
              formations sharing a name keep a stable order between refreshes*/
    struct ByName
    {
        const std::vector<Oob::Unit>* units;

        bool operator()(int a, int b) const {
            const int order = compareNames((*units)[a].name, (*units)[b].name);
            if (order != 0) {
                return order < 0;
            }
            return (*units)[a].id < (*units)[b].id;
        }
    };

    /**
    @brief adds up what sits below every unit, deepest first

    Iterative rather than recursive: an order of battle is only five or six levels
    deep in practice, but nothing here has checked that, and a corrupt parent chain
    should not be able to overflow the stack.
    */
    void accumulate(Oob::Tree& tree) {
        // Children always come after their parent in a breadth first walk, so walking
        // the units backwards means a unit's children are already totalled.
        std::vector<int> order;
        order.reserve(tree.units.size());
        for (size_t i = 0; i < tree.roots.size(); i++) {
            order.push_back(tree.roots[i]);
        }
        for (size_t at = 0; at < order.size(); at++) {
            const Oob::Unit& unit = tree.units[order[at]];
            for (size_t c = 0; c < unit.children.size(); c++) {
                order.push_back(unit.children[c]);
            }
        }

        // Running totals for the averages, kept aside rather than on the unit: they
        // are working state, and a sum of percentages is not a thing worth handing
        // out afterwards.
        std::vector<long long> supplySum(tree.units.size(), 0);
        std::vector<long long> fuelSum(tree.units.size(), 0);

        for (size_t at = order.size(); at > 0; at--) {
            const int self = order[at - 1];
            Oob::Unit& unit = tree.units[self];
            for (size_t c = 0; c < unit.children.size(); c++) {
                const Oob::Unit& child = tree.units[unit.children[c]];

                unit.unitsBelow += child.unitsBelow + 1;
                supplySum[self] += supplySum[unit.children[c]] + child.supplyPercent;
                fuelSum[self] += fuelSum[unit.children[c]] + child.fuelPercent;

                unit.landBelow += child.landBelow;
                unit.airBelow += child.airBelow;
                unit.navalBelow += child.navalBelow;
                unit.regimentsBelow += child.regimentsBelow + child.regimentCount;
                unit.supplyConsumptionBelow +=
                    child.supplyConsumptionBelow + child.supplyConsumption;
                unit.fuelConsumptionBelow +=
                    child.fuelConsumptionBelow + child.fuelConsumption;
                unit.leaderlessBelow += child.leaderlessBelow + (child.leaderMissing ? 1 : 0);

                switch (child.branch) {
                case Oob::Branch::Land: unit.landBelow++; break;
                case Oob::Branch::Air: unit.airBelow++; break;
                case Oob::Branch::Naval: unit.navalBelow++; break;
                default: break;
                }

                if (child.depthBelow + 1 > unit.depthBelow) {
                    unit.depthBelow = child.depthBelow + 1;
                }
            }

            if (unit.unitsBelow > 0) {
                unit.supplyAverageBelow =
                    static_cast<int>(supplySum[self] / unit.unitsBelow);
                unit.fuelAverageBelow =
                    static_cast<int>(fuelSum[self] / unit.unitsBelow);
            }
        }
    }
}

const char* Oob::branchName(Branch branch) {
    switch (branch) {
    case Branch::Land: return "Land";
    case Branch::Air: return "Air";
    case Branch::Naval: return "Naval";
    default: return "Unknown";
    }
}

const char* Oob::levelName(int level, Branch branch) {
    if (branch == Branch::Naval || branch == Branch::Air) {
        // Only land units use the full theatre to division ladder; the others are
        // held at one level and named for what they are.
        return branch == Branch::Naval ? "Fleet" : "Wing";
    }

    switch (level) {
    case CUnit::Level::Theatre: return "Theatre";
    case CUnit::Level::ArmyGroup: return "Army Group";
    case CUnit::Level::Army: return "Army";
    case CUnit::Level::Corps: return "Corps";
    case CUnit::Level::Division: return "Division";
    case CUnit::Level::Navy: return "Navy";
    default: return "Unit";
    }
}

Oob::Tree Oob::read(uintptr_t country) {
    Tree tree;

    if (moduleBase() == 0) {
        tree.reason = "hoi3_tfh.exe is not loaded";
        return tree;
    }
    if (country == 0) {
        tree.reason = "no country selected";
        return tree;
    }

    // The country's list holds units from any level, not just the top, so it says
    // nothing about where any of them sits - the shape has to come from the units
    // themselves. Walking down from each one and remembering what it was found under
    // gives a second opinion for the cases where a unit's own back pointer does not
    // lead anywhere useful.
    struct Pending
    {
        uintptr_t address;
        int foundUnder; // index into tree.units, -1 when it came off the country's list
    };

    std::vector<Pending> pending;
    const std::vector<uintptr_t> topLevel = HDS::walkList(country + CCountry::Offsets::units_linked_list_first_ptr);
    for (size_t i = 0; i < topLevel.size(); i++) {
        pending.push_back(Pending{ topLevel[i], -1 });
    }

    std::map<uintptr_t, int> indexOf;
    std::vector<int> foundUnder;

    for (size_t at = 0; at < pending.size(); at++) {
        const uintptr_t address = pending[at].address;

        const std::map<uintptr_t, int>::const_iterator existing = indexOf.find(address);
        if (existing != indexOf.end()) {
            // Known already - but if this is the first time it has turned up as
            // somebody's subordinate, that is worth keeping. A unit can come off the
            // country's list before anything is known about where it belongs.
            if (pending[at].foundUnder >= 0 && foundUnder[existing->second] < 0) {
                foundUnder[existing->second] = pending[at].foundUnder;
            }
            continue;
        }

        const Branch branch = branchOf(address);
        if (branch == Branch::Unknown) {
            continue; // not a unit, so not something to read fields out of
        }

        if (static_cast<int>(tree.units.size()) >= MAX_UNITS) {
            tree.truncated++;
            continue;
        }

        const int index = static_cast<int>(tree.units.size());
        indexOf[address] = index;
        tree.units.push_back(readUnit(address, branch));
        foundUnder.push_back(pending[at].foundUnder);

        const std::vector<uintptr_t> below = HDS::walkList(address + CUnit::Offsets::lower_oob_unit_linked_list_first_ptr);
        for (size_t c = 0; c < below.size(); c++) {
            pending.push_back(Pending{ below[c], index });
        }
    }

    if (tree.units.empty()) {
        tree.available = true;
        tree.reason = "this country has no units";
        return tree;
    }

    // Where each unit belongs, and with it which units are at the top. The unit's own
    // back pointer is preferred, since it is the game's own answer; the list the unit
    // was found under stands in when that pointer leads somewhere unrecognised, as it
    // does for a unit attached from another country. A unit with neither is at the
    // top of the tree, which is how the top level is arrived at rather than assumed.
    for (size_t i = 0; i < tree.units.size(); i++) {
        Unit& unit = tree.units[i];
        int parent = foundUnder[i];

        const uintptr_t higher = readValue<uint32_t>(unit.address + CUnit::Offsets::higher_oob_unit_ptr);
        const std::map<uintptr_t, int>::const_iterator found = indexOf.find(higher);
        if (higher != 0 && found != indexOf.end() && found->second != static_cast<int>(i)) {
            parent = found->second;
        }

        if (parent >= 0) {
            unit.parent = parent;
            tree.units[parent].children.push_back(static_cast<int>(i));
        }
        else {
            tree.roots.push_back(static_cast<int>(i));
        }
    }

    for (size_t i = 0; i < tree.units.size(); i++) {
        const Unit& unit = tree.units[i];
        switch (unit.branch) {
        case Branch::Land: tree.landTotal++; break;
        case Branch::Air: tree.airTotal++; break;
        case Branch::Naval: tree.navalTotal++; break;
        default: break;
        }
        tree.regimentTotal += unit.regimentCount;
        tree.supplyConsumptionTotal += unit.supplyConsumption;
        tree.fuelConsumptionTotal += unit.fuelConsumption;
        if (unit.leaderMissing) {
            tree.leaderlessTotal++;
        }
    }

    if (!tree.units.empty()) {
        long long supplySum = 0;
        long long fuelSum = 0;
        for (size_t i = 0; i < tree.units.size(); i++) {
            supplySum += tree.units[i].supplyPercent;
            fuelSum += tree.units[i].fuelPercent;
        }
        tree.supplyAverage = static_cast<int>(supplySum / tree.units.size());
        tree.fuelAverage = static_cast<int>(fuelSum / tree.units.size());
    }

    // Alphabetical at every level. The game holds units in whatever order it built
    // them, which is not an order anybody can find a formation in. Regiments are left
    // alone: their order inside a division is the order the division is made of.
    const ByName byName = { &tree.units };
    std::sort(tree.roots.begin(), tree.roots.end(), byName);
    for (size_t i = 0; i < tree.units.size(); i++) {
        std::sort(tree.units[i].children.begin(), tree.units[i].children.end(), byName);
    }

    accumulate(tree);
    tree.available = true;
    return tree;
}

/**
 * Land regiments hold strength in hundredths, air and naval in thousandths. Taken from
 * how the game reports the same regiments rather than measured here.
 */
double Oob::strengthOf(const Regiment& regiment, Branch branch) {
    const double scale = (branch == Branch::Land) ? 10.0 : 1000.0;
    return regiment.strength / scale;
}

std::vector<Oob::Regiment> Oob::regiments(uintptr_t unit) {
    std::vector<Regiment> found;
    if (unit == 0) {
        return found;
    }

    const std::vector<uintptr_t> addresses = HDS::walkList(unit + CUnit::Offsets::regiments_linked_list_first_ptr);
    found.reserve(addresses.size());

    for (size_t i = 0; i < addresses.size(); i++) {
        Regiment regiment;
        regiment.name = HDS::readString(addresses[i] + CRegiment::Offsets::name);
        // Left as the game holds it. What that number means depends on the branch,
        // which a regiment does not know on its own, so the scaling is strengthOf()'s
        // job and not this one's.
        regiment.strength = readValue<int32_t>(addresses[i] + CRegiment::Offsets::strength);
        regiment.organisation = readValue<int32_t>(addresses[i] + CRegiment::Offsets::organisation);
        found.push_back(regiment);
    }
    return found;
}
