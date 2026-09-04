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
    const char* SESSION_CALL = "BiceLibGui.Combat.Session";
    const char* NEW_SESSION_CALL = "BiceLibGui.Combat.NewSession";
    const char* FOLDER = "combat_reports\\";

    // A line per combat, and a first line saying what the lines are. Text rather than
    // anything cleverer: it is appended to a few times a day, read once, and being
    // able to look at it in an editor is worth more than the bytes.
    // A line whose fields are not all there is skipped, so changing the format makes
    // existing records unreadable rather than half readable. That is deliberate: the
    // alternative is carrying every past shape of the line forever, and this file is
    // written by one program and read by the same one.
    //
    // Sessions are the one exception. They were added to a format already in use, as
    // a last field, so a line without one reads as a line of session zero rather than
    // as a line that cannot be read - which is what keeps a campaign already being
    // played from losing its history. Nothing else may be added this way.
    const char* HEADER = "# BiceLib combat record: tick;branch;province;"
        "attackerTag;attackerId;attackerLosses;attackerMen;"
        "defenderTag;defenderId;defenderLosses;defenderMen;winner;session\n"
        "# branch: L land, A air, N naval, and a bombing raid in lower case - g on a "
        "province, l on the land units in one, n on ships\n"
        "# a line with no session belongs to session 0, written before there were any\n";

    const char* SESSION_HEADER = "# BiceLib combat sessions: id;parent;startTick\n"
        "# one line per savegame load. The parents lead back to the start of the "
        "campaign, and that chain is the timeline being played.\n";

    // How far the clock may jump between two samples and still be play rather than a
    // savegame being loaded. The game does a handful of days a second at its fastest,
    // so three months is far beyond it - but a stalled render thread piles up real
    // days too, which is why this is not tighter. Guessing wrong costs one extra line
    // in the session file and nothing else: a session whose parent is the session it
    // just left, starting where that one stopped, describes the same timeline.
    const unsigned int MAX_ADVANCE_TICKS = 90 * 24;

    // A chain longer than this is a corrupt file rather than a long campaign - a
    // session is one savegame load.
    const int MAX_CHAIN = 512;

    struct Session
    {
        unsigned int id = 0;
        unsigned int parent = 0;
        unsigned int startTick = 0;
    };

    /**@brief one session of the timeline, and the tick its child branched off at*/
    struct Link
    {
        unsigned int id = 0;
        unsigned int bound = 0;
    };

    int campaignId = 0;
    std::string filePath;
    std::string sessionFilePath;
    std::string failure = "waiting for a campaign";

    // Everything in the file, and the part of it this timeline actually fought. The
    // page reads the second and never learns that the first exists.
    std::vector<Combat::Entry> records;
    std::vector<Combat::Entry> loaded;
    std::vector<Session> sessions;
    std::vector<Link> chain;

    bool fileRead = false;
    unsigned int nextSequence = 0;
    unsigned int lostRecords = 0;
    ULONGLONG lastAskMs = 0;
    ULONGLONG lastStepMs = 0;

    // The session combats are filed under, and the one whose claim has not been read
    // back out of the game yet. Filing goes on under a claim that is still in flight:
    // the number is ours either way, and waiting would drop the combats it is for.
    unsigned int sessionId = 0;
    unsigned int unconfirmed = 0;
    ULONGLONG lastSessionAskMs = 0;

    // Spotting a load, from the clock alone. This costs no Lua, so unlike everything
    // else here it runs from the first frame - which matters, because the tick a
    // session starts at is only readable in the moment the clock jumps. By the time a
    // combat gives us leave to ask Lua whose session it is, the jump is long past.
    unsigned int lastSampledTick = 0;
    unsigned int loadTick = 0;
    bool loadSeen = false;

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
        records.clear();
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
            unsigned int session = 0;
            const int fields = sscanf_s(line, "%u;%c;%d;%7[^;];%d;%d;%d;%7[^;];%d;%d;%d;%c;%u",
                &tick, &branch, 1, &entry.provinceId,
                entry.attackerTag, static_cast<unsigned>(sizeof(entry.attackerTag)),
                &entry.attackerId, &entry.attackerLosses, &entry.attackerMen,
                entry.defenderTag, static_cast<unsigned>(sizeof(entry.defenderTag)),
                &entry.defenderId, &entry.defenderLosses, &entry.defenderMen,
                &winner, 1, &session);
            if (fields < 12) {
                continue; // a line we cannot read is skipped, not fatal
            }

            entry.tick = tick;
            entry.branch = branchFromLetter(branch);
            entry.winner = winnerFromLetter(winner);
            // Twelve fields is a line from before sessions, which is session zero -
            // the root every timeline is descended from.
            entry.session = (fields >= 13) ? session : 0;
            records.push_back(entry);
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
        // A file started before sessions keeps its old header and gains lines with a
        // field the header does not mention. Left alone deliberately: rewriting a
        // file to correct a comment risks the record for nothing.
        fseek(file, 0, SEEK_END);
        if (ftell(file) == 0) {
            fputs(HEADER, file);
        }

        fprintf(file, "%u;%c;%d;%s;%d;%d;%d;%s;%d;%d;%d;%c;%u\n",
            entry.tick, branchLetter(entry.branch), entry.provinceId,
            entry.attackerTag, entry.attackerId, entry.attackerLosses, entry.attackerMen,
            entry.defenderTag, entry.defenderId, entry.defenderLosses, entry.defenderMen,
            winnerLetter(entry.winner), entry.session);
        fclose(file);
    }

    void readSessions() {
        sessions.clear();

        FILE* file = nullptr;
        if (fopen_s(&file, sessionFilePath.c_str(), "r") != 0 || file == nullptr) {
            return; // a campaign that has not loaded a savegame since sessions existed
        }

        char line[256];
        while (fgets(line, sizeof(line), file) != nullptr) {
            if (line[0] == '#' || line[0] == '\n') {
                continue;
            }

            Session session;
            if (sscanf_s(line, "%u;%u;%u", &session.id, &session.parent,
                &session.startTick) < 3) {
                continue;
            }
            if (session.id == 0) {
                continue; // zero is the root and is never a session of its own
            }
            sessions.push_back(session);
        }
        fclose(file);
    }

    void appendSession(const Session& session) {
        FILE* file = nullptr;
        if (fopen_s(&file, sessionFilePath.c_str(), "a") != 0 || file == nullptr) {
            failure = "could not write " + sessionFilePath;
            return;
        }

        fseek(file, 0, SEEK_END);
        if (ftell(file) == 0) {
            fputs(SESSION_HEADER, file);
        }

        fprintf(file, "%u;%u;%u\n", session.id, session.parent, session.startTick);
        fclose(file);
    }

    const Session* findSession(unsigned int id) {
        for (size_t i = 0; i < sessions.size(); i++) {
            if (sessions[i].id == id) {
                return &sessions[i];
            }
        }
        return nullptr;
    }

    /**
    @brief works out which sessions this timeline is made of, and how much of each

    Walking parent to parent from the session being played back to the root. Each one
    counts only up to where the next branched off it, because an ancestor went on
    being played after this timeline left it and those combats belong to the branch
    that was abandoned, not to this one.

    A bound is exclusive: a combat recorded in the same hour a savegame was written is
    given to the session that loaded it, and is counted when that session fights it
    again. Including it on both sides would be the worse mistake.
    */
    void buildChain() {
        chain.clear();

        unsigned int id = sessionId;
        unsigned int bound = 0xFFFFFFFFu; // the session being played has no end
        for (int depth = 0; depth < MAX_CHAIN; depth++) {
            Link link;
            link.id = id;
            link.bound = bound;
            chain.push_back(link);

            if (id == 0) {
                break; // the root
            }

            const Session* session = findSession(id);
            if (session == nullptr) {
                // The session file is missing or has lost a line. Rather than cut the
                // chain here - which would drop every combat older than this session,
                // the whole campaign in the usual case - fall back to counting
                // everything, which is what the record did before sessions existed.
                Link root;
                root.id = 0;
                root.bound = 0xFFFFFFFFu;
                chain.push_back(root);
                break;
            }

            bound = session->startTick;
            id = session->parent;
        }
    }

    /**@brief the part of the chain \p entry belongs to, or nothing*/
    bool inTimeline(const Combat::Entry& entry) {
        for (size_t i = 0; i < chain.size(); i++) {
            if (chain[i].id == entry.session) {
                return entry.tick < chain[i].bound;
            }
        }
        return false;
    }

    void rebuildTimeline() {
        buildChain();

        loaded.clear();
        for (size_t i = 0; i < records.size(); i++) {
            if (inTimeline(records[i])) {
                loaded.push_back(records[i]);
            }
        }
    }

    /**
    @brief true if this combat is already in the timeline being played

    A combat is identified by when and where it finished, which is enough because two
    combats cannot end in the same province in the same hour between the same
    countries.

    This used to be the whole defence against going back: loading an earlier savegame
    re-fights the battles between that point and where the game had got to, and they
    arrive with the same tick, province and tags as the ones already written down.
    Sessions do that job properly now - a replay is a new session, and the branch it
    left is set aside rather than matched against - so what is left here is a guard
    against the same combat reaching us twice within one session.

    It matters that this reads the timeline and not the whole record. A battle fought
    again on a new branch looks exactly like the one on the branch that was abandoned,
    and matching against that would throw the new one away and leave a hole where a
    battle was actually fought.
    */
    bool known(const Combat::Entry& entry) {
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

    /**
    @brief watches the game's clock for the jump that means a savegame was loaded

    Reading the clock is a memory read and is safe at the main menu, where it answers
    zero - which is the only reason a load can be timed at all. Everything else here
    has to wait for a combat before it may speak to Lua, and by then the game has been
    running for hours.

    A jump backwards is a load; nothing else moves the clock the wrong way. A jump
    forwards past what the game could have played in the time is a load as well, which
    catches going back to a *later* savegame. Reading that wrong is close to free -
    see MAX_ADVANCE_TICKS - so the threshold is set to be sure rather than to be tight.
    */
    void sampleTick() {
        const unsigned int tick = Combat::Store::currentTick();
        if (tick == 0) {
            lastSampledTick = 0; // at the menu; the next game is a load in its own right
            return;
        }

        const bool backwards = (tick < lastSampledTick);
        const bool leapt = (tick > lastSampledTick + MAX_ADVANCE_TICKS);
        if (lastSampledTick == 0 || backwards || leapt) {
            // Only the most recent one is kept. Two loads before a single combat has
            // been fought would lose the session in between, and with it whatever it
            // fought - which is nothing, or there would have been a combat.
            loadTick = tick;
            loadSeen = true;
        }
        lastSampledTick = tick;
    }

    /**@brief asks the game for the session it holds, and nudges it to hold ours*/
    unsigned int askSession(unsigned int expected) {
        if (!Gui::Lua::beginTableCallWithNumber(SESSION_CALL,
            static_cast<double>(expected))) {
            return 0;
        }

        unsigned int id = 0;
        if (Gui::Lua::boolField("available")) {
            id = static_cast<unsigned int>(Gui::Lua::numberField("id"));
        }
        Gui::Lua::endCall();
        return id;
    }

    /**
    @brief starts a session for the savegame that was loaded, and writes it down

    The session the game is holding becomes the parent: a savegame carries whichever
    session was live when it was written, so loading one says which branch it belongs
    to without anything having to be remembered between runs.
    */
    void claimSession() {
        if (!Gui::Lua::beginTableCall(NEW_SESSION_CALL)) {
            failure = std::string("Lua unavailable: ") + Gui::Lua::unavailableReason();
            return;
        }

        Session session;
        if (Gui::Lua::boolField("available")) {
            session.id = static_cast<unsigned int>(Gui::Lua::numberField("id"));
            session.parent = static_cast<unsigned int>(Gui::Lua::numberField("previous"));
        }
        else {
            failure = Gui::Lua::stringField("reason", "no session");
        }
        Gui::Lua::endCall();

        if (session.id == 0) {
            return; // asked too early; the next combat asks again
        }

        // Where the clock jumped, if that was seen, and otherwise where the clock is
        // now - which is the first combat of the session, and later than the load by
        // however long the world took to fight one.
        session.startTick = loadSeen ? loadTick : Combat::Store::currentTick();
        loadSeen = false;

        sessions.push_back(session);
        appendSession(session);

        sessionId = session.id;
        unconfirmed = session.id;
        failure.clear();
        rebuildTimeline();
    }

    /**@brief checks the claim landed in the game, since the savegame has to carry it*/
    void confirmSession() {
        const ULONGLONG now = GetTickCount64();
        if (lastSessionAskMs != 0 && now - lastSessionAskMs < 5000) {
            return;
        }
        lastSessionAskMs = now;

        // Asking re-posts the number if the game is not holding it, so a post that
        // was dropped is retried rather than left to corrupt the next savegame.
        if (askSession(unconfirmed) == unconfirmed) {
            unconfirmed = 0;
        }
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

    // Before every gate below, because it is the one thing here that reads memory
    // rather than Lua and so is the only thing that may run at the main menu. It is
    // also the only chance to see a savegame being loaded: the clock jumps once, in
    // that moment, and by the time a combat lets us ask Lua whose session it is the
    // jump is hours in the past.
    sampleTick();

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
        char sessionName[64];
        sprintf_s(sessionName, "campaign_%d_sessions.txt", campaignId);

        const std::string folder = Overlay::directory() + FOLDER;
        CreateDirectoryA(folder.c_str(), nullptr);
        filePath = folder + name;
        sessionFilePath = folder + sessionName;
    }

    if (!fileRead) {
        readFile();
        readSessions();
        rebuildTimeline();
    }

    // A session is claimed when there is none, and again whenever the clock says a
    // savegame has been loaded since the last one. Both go through the same path,
    // because entering a game from the menu is a load like any other.
    if (sessionId == 0 || loadSeen) {
        // Paced, so a claim that cannot be answered yet - no player country, which is
        // the same thing that holds up the campaign - does not ask once a second
        // forever. It also gives a claim that has just been posted time to land
        // before confirmSession starts looking for it.
        const ULONGLONG now = GetTickCount64();
        if (lastSessionAskMs == 0 || now - lastSessionAskMs >= 2000) {
            lastSessionAskMs = now;
            claimSession();
        }
    }
    else if (unconfirmed != 0) {
        confirmSession();
    }

    // Nothing may be filed until it is known which run of the campaign fought it.
    // The combats wait in the ring meanwhile, which is what the ring is for.
    if (sessionId == 0) {
        return;
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
        entry.session = sessionId;

        if (!known(entry)) {
            // Into both: the whole record, which is what the file holds, and the
            // timeline, which is what the page reads. A combat just fought is always
            // in the timeline that fought it.
            records.push_back(entry);
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

const std::string& Combat::Store::sessionPath() {
    return sessionFilePath;
}

unsigned int Combat::Store::session() {
    return sessionId;
}

int Combat::Store::timelineDepth() {
    return static_cast<int>(chain.size());
}

int Combat::Store::setAside() {
    return static_cast<int>(records.size() - loaded.size());
}

bool Combat::Store::sessionPending() {
    return loadSeen && sessionId != 0;
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
