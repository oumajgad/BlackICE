#include <GameState/CombatStore.hpp>
#include <GameClasses/CCurrentGameState.hpp>

#include <Gui/LuaBridge.hpp>
#include <Hooks/CCombatHooks.hpp>
#include <MemScan.hpp>
#include <Overlay.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    const char* CAMPAIGN_CALL = "BiceLibGui.Combat.Campaign";
    const char* FOLDER = "combat_reports\\";

    // A line per combat, and a first line saying what the lines are. Text rather than
    // anything cleverer: it is appended to a few times a day, read once, and being
    // able to look at it in an editor is worth more than the bytes.
    // A line whose fields are not all there is skipped, so changing the format makes
    // existing records unreadable rather than half readable. That is deliberate: the
    // alternative is carrying every past shape of the line forever, and this file is
    // written by one program and read by the same one.
    const char* HEADER = "# BiceLib combat record: tick;branch;province;"
        "attackerTag;attackerId;attackerLosses;attackerMen;"
        "defenderTag;defenderId;defenderLosses;defenderMen;winner\n"
        "# branch: L land, A air, N naval, and a bombing raid in lower case - g on a "
        "province, l on the land units in one, n on ships\n";

    int campaignId = 0;
    std::string filePath;
    std::string failure = "waiting for a campaign";
    std::vector<Combat::Entry> loaded;
    bool fileRead = false;
    unsigned int nextSequence = 0;
    unsigned int lostRecords = 0;
    ULONGLONG lastAskMs = 0;
    ULONGLONG lastStepMs = 0;

    // A bombing raid takes the lower case of what it was aimed at, so the letters stay
    // one character and nothing already written changes meaning.
    char branchLetter(Combat::Branch branch) {
        switch (branch) {
        case Combat::Branch::Land: return 'L';
        case Combat::Branch::Air: return 'A';
        case Combat::Branch::Naval: return 'N';
        case Combat::Branch::GroundBombing: return 'g';
        case Combat::Branch::LandBombing: return 'l';
        case Combat::Branch::NavalBombing: return 'n';
        default: return '?';
        }
    }

    char winnerLetter(Combat::Outcome winner) {
        switch (winner) {
        case Combat::Outcome::AttackerWon: return 'A';
        case Combat::Outcome::DefenderWon: return 'D';
        default: return '?';
        }
    }

    Combat::Outcome winnerFromLetter(char letter) {
        switch (letter) {
        case 'A': return Combat::Outcome::AttackerWon;
        case 'D': return Combat::Outcome::DefenderWon;
        default: return Combat::Outcome::Unknown;
        }
    }

    Combat::Branch branchFromLetter(char letter) {
        switch (letter) {
        case 'L': return Combat::Branch::Land;
        case 'A': return Combat::Branch::Air;
        case 'N': return Combat::Branch::Naval;
        case 'g': return Combat::Branch::GroundBombing;
        case 'l': return Combat::Branch::LandBombing;
        case 'n': return Combat::Branch::NavalBombing;
        default: return Combat::Branch::Unknown;
        }
    }

    /**@brief asks Lua which campaign this is; 0 while the answer is still queued*/
    int askCampaign() {
        if (!Gui::Lua::beginTableCall(CAMPAIGN_CALL)) {
            failure = std::string("Lua unavailable: ") + Gui::Lua::unavailableReason();
            return 0;
        }

        int id = 0;
        if (Gui::Lua::boolField("available")) {
            id = static_cast<int>(Gui::Lua::numberField("id"));
            failure = (id == 0) ? "claiming a campaign number" : std::string();
        }
        else {
            failure = Gui::Lua::stringField("reason", "no campaign");
        }
        Gui::Lua::endCall();
        return id;
    }

    void readFile() {
        loaded.clear();
        fileRead = true;

        FILE* file = nullptr;
        if (fopen_s(&file, filePath.c_str(), "r") != 0 || file == nullptr) {
            return; // a campaign with no combats yet, which is not a problem
        }

        char line[512];
        while (fgets(line, sizeof(line), file) != nullptr) {
            if (line[0] == '#' || line[0] == '\n') {
                continue;
            }

            Combat::Entry entry;
            char branch = '?';
            char winner = '?';
            unsigned int tick = 0;
            if (sscanf_s(line, "%u;%c;%d;%7[^;];%d;%d;%d;%7[^;];%d;%d;%d;%c",
                &tick, &branch, 1, &entry.provinceId,
                entry.attackerTag, static_cast<unsigned>(sizeof(entry.attackerTag)),
                &entry.attackerId, &entry.attackerLosses, &entry.attackerMen,
                entry.defenderTag, static_cast<unsigned>(sizeof(entry.defenderTag)),
                &entry.defenderId, &entry.defenderLosses, &entry.defenderMen,
                &winner, 1) < 12) {
                continue; // a line we cannot read is skipped, not fatal
            }

            entry.tick = tick;
            entry.branch = branchFromLetter(branch);
            entry.winner = winnerFromLetter(winner);
            loaded.push_back(entry);
        }
        fclose(file);
    }

    void appendToFile(const Combat::Entry& entry) {
        FILE* file = nullptr;
        if (fopen_s(&file, filePath.c_str(), "a") != 0 || file == nullptr) {
            failure = "could not write " + filePath;
            return;
        }

        // The header goes in once, when the file is new. Appending does not move the
        // position to the end until something is written, so the size has to be asked
        // for rather than read off ftell - which is what put a header on every line.
        fseek(file, 0, SEEK_END);
        if (ftell(file) == 0) {
            fputs(HEADER, file);
        }

        fprintf(file, "%u;%c;%d;%s;%d;%d;%d;%s;%d;%d;%d;%c\n",
            entry.tick, branchLetter(entry.branch), entry.provinceId,
            entry.attackerTag, entry.attackerId, entry.attackerLosses, entry.attackerMen,
            entry.defenderTag, entry.defenderId, entry.defenderLosses, entry.defenderMen,
            winnerLetter(entry.winner));
        fclose(file);
    }

    /**@brief true if this combat is already in the record*/
    bool known(const Combat::Entry& entry) {
        // A combat is identified by when and where it finished, which is enough
        // because two combats cannot end in the same province in the same hour
        // between the same countries.
        //
        // What this guards against is going back: loading an earlier save re-fights
        // the battles between that point and where the game had got to, and they
        // arrive with the same tick, province and tags as the ones already written
        // down. Without this, save-scumming a bad battle would count it twice.
        //
        // Loading a save is not itself thought to fire the hook - the game appears to
        // rebuild its history through the serialisation path at 0x00434140 rather than
        // through the function hooked here - but that has not been tested, and this
        // covers it either way.
        for (size_t i = 0; i < loaded.size(); i++) {
            if (loaded[i].tick == entry.tick &&
                loaded[i].provinceId == entry.provinceId &&
                strcmp(loaded[i].attackerTag, entry.attackerTag) == 0 &&
                strcmp(loaded[i].defenderTag, entry.defenderTag) == 0) {
                return true;
            }
        }
        return false;
    }
}

void Combat::Store::update() {
    // Driven from the Present hook, so it runs whether or not the page is open - a
    // record that only accumulates while someone is looking at it is no record at all.
    // Once a second is far more often than combats finish.
    const ULONGLONG stepNow = GetTickCount64();
    if (lastStepMs != 0 && stepNow - lastStepMs < 1000) {
        return;
    }
    lastStepMs = stepNow;

    // Patching the game is left until there is a game: the address is only meaningful
    // once the module is loaded, and there is nothing to record at the main menu.
    if (Combat::recording() && !Hooks::Combat::installed() && currentTick() != 0) {
        Combat::setRecording(true);
    }

    // Nothing below may touch Lua until a game is genuinely running.
    //
    // Asking which campaign this is reaches CCurrentGameState through Lua, and the
    // game's own API faults inside its C++ when there is no game - lua_pcall cannot
    // catch that, so it takes the process with it. This runs from Present, which is
    // frame one of the main menu, long before any game exists. Every other page gets
    // away with calling Lua because pages only run when someone is looking at them.
    //
    // A captured combat is the proof that is wanted here: combats only finish in a
    // running game. Until one has been caught there is also nothing to file, so
    // waiting for one costs nothing.
    if (Combat::written() == 0) {
        return;
    }

    if (campaignId == 0) {
        // Asking costs a Lua call, and the answer only changes when a campaign starts
        // or the claim comes back, so this is paced rather than done every frame.
        const ULONGLONG now = GetTickCount64();
        if (lastAskMs != 0 && now - lastAskMs < 2000) {
            return;
        }
        lastAskMs = now;

        campaignId = askCampaign();
        if (campaignId == 0) {
            return;
        }

        char name[64];
        sprintf_s(name, "campaign_%d.txt", campaignId);
        const std::string folder = Overlay::directory() + FOLDER;
        CreateDirectoryA(folder.c_str(), nullptr);
        filePath = folder + name;
    }

    if (!fileRead) {
        readFile();
    }

    // Whatever the hook has caught since last time. It captures into a ring and never
    // writes files itself, because it runs on the game's own thread in the middle of
    // finishing a combat.
    const unsigned int captured = Combat::written();

    // If the ring wrapped before this got here, those combats are gone. Saying so is
    // the point: a silently short record would be worse than a visibly short one.
    const unsigned int oldest = Combat::oldestKept();
    if (nextSequence < oldest) {
        lostRecords += oldest - nextSequence;
        nextSequence = oldest;
    }

    for (unsigned int i = nextSequence; i < captured; i++) {
        Combat::Record record;
        if (!Combat::copySequence(i, record)) {
            continue;
        }

        Entry entry;
        entry.tick = record.tick;
        entry.branch = record.branch;
        entry.provinceId = record.provinceId;
        entry.winner = record.winner;
        strncpy_s(entry.attackerTag, record.attacker.tag, _TRUNCATE);
        entry.attackerId = record.attacker.countryId;
        entry.attackerLosses = record.attacker.losses;
        entry.attackerMen = record.attacker.men;
        strncpy_s(entry.defenderTag, record.defender.tag, _TRUNCATE);
        entry.defenderId = record.defender.countryId;
        entry.defenderLosses = record.defender.losses;
        entry.defenderMen = record.defender.men;

        if (!known(entry)) {
            loaded.push_back(entry);
            appendToFile(entry);
        }
    }
    nextSequence = captured;
}

int Combat::Store::campaign() {
    return campaignId;
}

const std::string& Combat::Store::path() {
    return filePath;
}

const std::string& Combat::Store::reason() {
    return failure;
}

unsigned int Combat::Store::lost() {
    return lostRecords;
}

int Combat::Store::count() {
    return static_cast<int>(loaded.size());
}

const std::vector<Combat::Entry>& Combat::Store::entries() {
    return loaded;
}

Combat::Tally Combat::Store::tally(const std::string& tag, unsigned int fromTick,
    unsigned int toTick, Branch branch) {
    Tally result;
    if (tag.empty()) {
        return result;
    }

    for (size_t i = 0; i < loaded.size(); i++) {
        const Entry& entry = loaded[i];
        if (entry.tick < fromTick || entry.tick > toTick) {
            continue;
        }
        if (branch != Branch::Unknown && entry.branch != branch) {
            continue;
        }

        const bool attacked = (tag == entry.attackerTag);
        const bool defended = (tag == entry.defenderTag);
        if (!attacked && !defended) {
            continue;
        }

        result.combats++;

        // A combat whose beaten side stayed "---" is in neither of these, because
        // nothing in it says which country lost it.
        const bool wonIt = (attacked && entry.winner == Outcome::AttackerWon) ||
            (defended && entry.winner == Outcome::DefenderWon);
        const bool lostIt = (attacked && entry.winner == Outcome::DefenderWon) ||
            (defended && entry.winner == Outcome::AttackerWon);
        if (wonIt) {
            result.won++;
        }
        if (lostIt) {
            result.lost++;
        }

        if (attacked) {
            result.asAttacker++;
            result.losses += entry.attackerLosses;
            result.kills += entry.defenderLosses;
        }
        else {
            result.asDefender++;
            result.losses += entry.defenderLosses;
            result.kills += entry.attackerLosses;
        }
    }
    return result;
}

unsigned int Combat::Store::currentTick() {
    return static_cast<unsigned int>(CCurrentGameState::currentTick());
}
