-- Combat reporting: the identity of the campaign being played, and of the timeline
-- within it.
--
-- The game keeps its own combat history for a few days and then prunes it, so a report
-- covering a year has to be accumulated as the game is played and kept in a file. That
-- file belongs to one campaign, and campaigns need telling apart: two games started as
-- the same country on the same date are otherwise indistinguishable.
--
-- So a campaign claims a number the first time anyone asks, and keeps it in a variable
-- on OMG - the housekeeping country the mod already uses for things that belong to the
-- game rather than to any nation. It survives a save and load because country
-- variables do.
--
-- A campaign is not one timeline, though. Load a save from a year ago and play on, and
-- the battles of that year are fought again, differently; go back to the later save and
-- the record now holds both, and counting a month adds the two together. So the
-- campaign also carries a *session* number, replaced every time a savegame is loaded.
-- The one it replaces becomes its parent, and because a savegame carries whichever
-- session was live when it was written, loading it links the new session to the branch
-- that save belongs to. The chain of parents is the timeline being played; a session
-- that is not in it belongs to a branch that was abandoned.
--
-- The C++ side keeps the chain and decides what counts - see GameState/CombatStore.

BiceData = BiceData or {}
BiceData.Combat = {}

local VARIABLE = "bice_combat_campaign"
local SESSION_VARIABLE = "bice_combat_session"
local HOUSEKEEPING = "OMG"

--- The campaign's number, or 0 when it does not have one yet.
function BiceData.Combat.Id()
    local vars = BiceData.Country.VariablesOf(HOUSEKEEPING)
    if vars == nil then
        return 0
    end

    local value = BiceData.Country.Get(vars, VARIABLE) or 0
    return math.floor(value + 0.5)
end

--- Picks a number for this campaign, from whatever varies between two runs.
---
--- os.clock is the time this process has spent running, which differs with how long
--- loading took; the date differs between start dates; the tag differs between games;
--- and math.random has had the mod's own AI drawing from it since startup. None of
--- them is unique on its own. Together a collision is unlikely, and its only cost is
--- two campaigns sharing a file.
local function pickId(tag)
    local mixed = math.floor((os.clock() or 0) * 1000) + math.random(999999)

    for i = 1, string.len(tag or "") do
        mixed = mixed + string.byte(tag, i) * i * 7919
    end

    mixed = mixed + CCurrentGameState.GetCurrentDate():GetTotalDays()

    return 1 + (math.floor(mixed) % 999999)
end

--- The campaign's number, claiming one if it has none.
---
--- Returns 0 while the claim is in flight: CCurrentGameState.Post queues rather than
--- applies, so the number only becomes readable a moment later. Callers ask again.
function BiceData.Combat.EnsureId()
    local existing = BiceData.Combat.Id()
    if existing > 0 then
        return existing
    end

    -- Nothing to claim a campaign for until the game knows who is playing it.
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return 0
    end

    BiceData.Country.Set(HOUSEKEEPING, VARIABLE, pickId(tag))
    return 0
end

--- The session the loaded savegame belongs to, 0 for one saved before sessions existed.
function BiceData.Combat.SessionId()
    local vars = BiceData.Country.VariablesOf(HOUSEKEEPING)
    if vars == nil then
        return 0
    end

    local value = BiceData.Country.Get(vars, SESSION_VARIABLE) or 0
    return math.floor(value + 0.5)
end

--- Reads the stored session, re-queueing `expected` if the game does not hold it.
---
--- Setting a variable queues rather than applies, so a session claimed a moment ago is
--- not readable yet and this returns the old number - the caller waits rather than
--- claiming again. The re-queue covers the other case: a post that never landed would
--- leave the next savegame carrying the wrong session, which would silently attach the
--- next branch to the wrong parent. Cheap enough to keep asking until it sticks.
function BiceData.Combat.HoldSession(expected)
    local stored = BiceData.Combat.SessionId()

    if expected ~= nil and expected > 0 and stored ~= expected then
        BiceData.Country.Set(HOUSEKEEPING, SESSION_VARIABLE, expected)
    end
    return stored
end

--- Starts a session: what is stored becomes its parent, a fresh number takes its place.
---
--- Returns the new number and the parent. The new one is returned rather than read
--- back, because the post that stores it has not landed yet; the caller files its
--- combats under it at once and confirms later through HoldSession.
function BiceData.Combat.NewSession()
    local previous = BiceData.Combat.SessionId()

    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return 0, previous
    end

    local id = pickId(tag)

    -- A session that is its own parent is a cycle in the chain, and the walk that
    -- reads it would never reach the root. Unlikely enough to never happen and cheap
    -- enough to rule out.
    if id == previous then
        id = 1 + (id % 999999)
    end

    BiceData.Country.Set(HOUSEKEEPING, SESSION_VARIABLE, id)
    return id, previous
end
