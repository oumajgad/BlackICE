-- Combat reporting: the identity of the campaign being played.
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

BiceData = BiceData or {}
BiceData.Combat = {}

local VARIABLE = "bice_combat_campaign"
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
