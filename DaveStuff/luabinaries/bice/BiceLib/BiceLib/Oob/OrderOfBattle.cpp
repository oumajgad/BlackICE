#include <Oob/OrderOfBattle.hpp>

#include <MemScan.hpp>
#include <TextEncoding.hpp>

#include <Windows.h>
#include <algorithm>
#include <map>
#include <set>
#include <vector>

namespace {
    // Offsets into the game's own structures. Every one of them came from the memory
    // map in DaveStuff/mem and is only valid for this build of hoi3_tfh.exe - which
    // is already true of every address in BiceLib.
    namespace UnitOffset {
        const uintptr_t selected = 0x4;
        const uintptr_t type = 0x10;
        const uintptr_t id = 0x14;
        const uintptr_t regimentsFirst = 0x38;
        const uintptr_t regimentCount = 0x40;
        const uintptr_t upgradePriority = 0xA4;
        const uintptr_t upgradeActive = 0xA5;
        const uintptr_t reinforcementsActive = 0xA6;
        const uintptr_t combatCooldown = 0xD4;
        const uintptr_t supplyPercent = 0xFC;
        const uintptr_t fuelPercent = 0x100;
        const uintptr_t leader = 0x12C;
        const uintptr_t province = 0x130;
        const uintptr_t name = 0x16C;
        const uintptr_t digIn = 0x1C8;
        const uintptr_t combatArmsBonus = 0x1CC;
        const uintptr_t higher = 0x1E0;
        const uintptr_t lowerFirst = 0x1E4;
        const uintptr_t level = 0x1F4;
    }

    namespace RegimentOffset {
        const uintptr_t strength = 0x30;
        const uintptr_t organisation = 0x60;
        const uintptr_t name = 0x68;
    }

    namespace LeaderOffset {
        const uintptr_t name = 0x4C;
        const uintptr_t skill = 0x70;
        const uintptr_t maxSkill = 0x74;
    }

    const uintptr_t COUNTRY_UNITS_LIST = 0xBAC;
    const uintptr_t PROVINCE_ID = 0xD0;

    // oob_level for a division, which is also what a lone brigade is held as.
    const int LEVEL_DIVISION = 4;

    // A linked list node: what it holds, then the two links.
    const uintptr_t NODE_DATA = 0x0;
    const uintptr_t NODE_NEXT = 0x8;

    // The vtables that say what a unit is - CArmy, CNavy and CAir, the three classes
    // an order of battle is made of. A unit whose vtable is none of these is not a
    // unit at all, which is the check that keeps a stale pointer from being read as
    // though it were one.
    //
    // Each of them has a second vtable as well, for the base it inherits at object
    // offset 8. Those are not these and never appear at the start of a unit, so there
    // is nothing to compare against them here.
    const uintptr_t VFTABLE_LAND = 0x11BDE0C;  // CArmy
    const uintptr_t VFTABLE_NAVAL = 0x11C869C; // CNavy
    const uintptr_t VFTABLE_AIR = 0x11C8774;   // CAir

    // A country can field thousands of units; these bound the damage if a list turns
    // out to be circular or simply is not a list.
    const int MAX_UNITS = 20000;
    const int MAX_LIST_STEPS = 25000;

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

    /**
    @brief reads a std::string the way the game's compiler laid it out

    Sixteen bytes that are either the characters themselves or a pointer to them,
    then the length. Past fifteen characters it is a pointer.

    Converted to UTF-8 on the way out, because the game's text is Windows-1252 and
    ImGui draws anything else as its fallback glyph - which turns every German unit
    name into a row of question marks. This is the boundary, so it happens here once
    rather than at each place a name is drawn.
    */
    std::string readString(uintptr_t address) {
        if (address == 0) {
            return std::string();
        }

        uint32_t length = 0;
        if (!Mem::tryRead(address + 0x10, length) || length == 0 || length > 512) {
            return std::string();
        }

        uintptr_t characters = address;
        if (length > 15) {
            uint32_t pointer = 0;
            if (!Mem::tryRead(address, pointer) || pointer == 0) {
                return std::string();
            }
            characters = pointer;
        }

        std::string text(length, '\0');
        if (!Mem::tryReadBytes(characters, &text[0], length)) {
            return std::string();
        }

        // The game is not always tidy about what follows the length.
        const size_t terminator = text.find('\0');
        if (terminator != std::string::npos) {
            text.resize(terminator);
        }
        return Text::toUtf8(text);
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

        if (vftable == base + VFTABLE_LAND) {
            return Oob::Branch::Land;
        }
        if (vftable == base + VFTABLE_NAVAL) {
            return Oob::Branch::Naval;
        }
        if (vftable == base + VFTABLE_AIR) {
            return Oob::Branch::Air;
        }
        return Oob::Branch::Unknown;
    }

    /**
    @brief follows a linked list whose head pointer sits at \p listField

    @returns what each node held, which for these lists is a unit or a regiment
    */
    std::vector<uintptr_t> walkList(uintptr_t listField) {
        std::vector<uintptr_t> found;

        uint32_t node = 0;
        if (!Mem::tryRead(listField, node)) {
            return found;
        }

        std::set<uintptr_t> visited;
        int steps = 0;
        while (node != 0 && steps < MAX_LIST_STEPS) {
            steps++;
            if (!visited.insert(node).second) {
                break; // been here before: the list loops
            }

            uint32_t data = 0;
            if (Mem::tryRead(node + NODE_DATA, data) && data != 0) {
                found.push_back(data);
            }

            uint32_t next = 0;
            if (!Mem::tryRead(node + NODE_NEXT, next)) {
                break;
            }
            node = next;
        }
        return found;
    }

    void readLeader(uintptr_t leader, Oob::Unit& unit) {
        if (leader == 0) {
            return;
        }
        unit.leaderName = readString(leader + LeaderOffset::name);
        unit.leaderSkill = readValue<int32_t>(leader + LeaderOffset::skill);
        unit.leaderMaxSkill = readValue<int32_t>(leader + LeaderOffset::maxSkill);

        // An unled unit still has something in the leader slot; the game calls it
        // "(no leader)". So a pointer is not enough to go on.
        unit.hasLeader = unit.leaderName.find("(no leader)") == std::string::npos;
    }

    /**@brief fills in everything one unit knows about itself*/
    Oob::Unit readUnit(uintptr_t address, Oob::Branch branch) {
        Oob::Unit unit;
        unit.address = address;
        unit.branch = branch;
        unit.name = readString(address + UnitOffset::name);
        unit.id = readValue<int32_t>(address + UnitOffset::id);
        unit.type = readValue<int32_t>(address + UnitOffset::type);
        unit.level = readValue<int32_t>(address + UnitOffset::level);
        unit.selected = readValue<uint8_t>(address + UnitOffset::selected) != 0;

        unit.supplyPercent = readValue<int32_t>(address + UnitOffset::supplyPercent);
        unit.fuelPercent = readValue<int32_t>(address + UnitOffset::fuelPercent);
        unit.digIn = readValue<int32_t>(address + UnitOffset::digIn);
        unit.combatArmsBonus = readValue<int32_t>(address + UnitOffset::combatArmsBonus);
        unit.combatCooldown = readValue<int32_t>(address + UnitOffset::combatCooldown);

        unit.upgradePriority = readValue<uint8_t>(address + UnitOffset::upgradePriority) != 0;
        unit.upgradeActive = readValue<uint8_t>(address + UnitOffset::upgradeActive) != 0;
        unit.reinforcementsActive =
            readValue<uint8_t>(address + UnitOffset::reinforcementsActive) != 0;

        unit.regimentCount = readValue<int32_t>(address + UnitOffset::regimentCount);
        if (unit.regimentCount < 0 || unit.regimentCount > 1000) {
            unit.regimentCount = 0;
        }

        unit.leader = readValue<uint32_t>(address + UnitOffset::leader);
        readLeader(unit.leader, unit);

        unit.province = readValue<uint32_t>(address + UnitOffset::province);
        if (unit.province != 0) {
            unit.provinceId = readValue<int32_t>(unit.province + PROVINCE_ID);
        }

        // A division made of a single brigade takes no commander, so it is not
        // missing one. Exactly one regiment, not "one or fewer": a count we failed to
        // read comes back as zero, and that should show up as a unit worth looking at
        // rather than quietly excuse itself.
        const bool takesNoLeader = (unit.level == LEVEL_DIVISION) && (unit.regimentCount == 1);
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
    case 0: return "Theatre";
    case 1: return "Army Group";
    case 2: return "Army";
    case 3: return "Corps";
    case 4: return "Division";
    case 5: return "Navy";
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
    const std::vector<uintptr_t> topLevel = walkList(country + COUNTRY_UNITS_LIST);
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

        const std::vector<uintptr_t> below = walkList(address + UnitOffset::lowerFirst);
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
    // back pointer is preferred, since it is the game's answer rather than ours; the
    // list it was found under stands in when that pointer leads nowhere we know, as
    // it will for a unit attached from another country. A unit with neither is at the
    // top of the tree, which is how the top level is arrived at rather than assumed.
    for (size_t i = 0; i < tree.units.size(); i++) {
        Unit& unit = tree.units[i];
        int parent = foundUnder[i];

        const uintptr_t higher = readValue<uint32_t>(unit.address + UnitOffset::higher);
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

std::vector<Oob::Regiment> Oob::regiments(uintptr_t unit) {
    std::vector<Regiment> found;
    if (unit == 0) {
        return found;
    }

    const std::vector<uintptr_t> addresses = walkList(unit + UnitOffset::regimentsFirst);
    found.reserve(addresses.size());

    for (size_t i = 0; i < addresses.size(); i++) {
        Regiment regiment;
        regiment.name = readString(addresses[i] + RegimentOffset::name);
        regiment.strength = readValue<int32_t>(addresses[i] + RegimentOffset::strength);
        regiment.organisation = readValue<int32_t>(addresses[i] + RegimentOffset::organisation);
        found.push_back(regiment);
    }
    return found;
}
