-- Leader definitions from history/leaders.
--
-- Port of the pure logic in utility/gameinfos/generals.lua, with the wx calls and the
-- radio button reads removed. Filtering is left to the caller.

BiceData = BiceData or {}
BiceData.Generals = {}

local leaders = nil -- id -> general

-- Availability comes from the leader's history blocks, and the base game ships
-- several start dates, so the earliest block is the one that matters.
local function earliestDateAndRank(leader)
    local earliestDate, earliestRank = nil, nil
    if leader["history"] == nil then
        return earliestDate, earliestRank
    end

    for currentDate, rankValue in pairs(leader["history"]) do
        if earliestDate == nil then
            earliestDate, earliestRank = currentDate, rankValue["rank"]
        else
            local current = Utils.SplitString(currentDate, ".")
            local best = Utils.SplitString(earliestDate, ".")
            if current[1] < best[1]
                or (current[1] == best[1] and current[2] < best[2])
                or (current[1] == best[1] and current[2] == best[2] and current[3] < best[3])
            then
                earliestDate, earliestRank = currentDate, rankValue["rank"]
            end
        end
    end
    return earliestDate, earliestRank
end

local function translateTraits(traits)
    if traits == nil then
        return {}
    end
    if type(traits) == "string" then
        traits = { traits }
    end

    local res = {}
    for _, key in pairs(traits) do
        table.insert(res, BiceData.Translations.Choice(key))
    end
    return res
end

local function fillData()
    if leaders ~= nil then
        return
    end

    leaders = {}
    local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\history\\leaders"
    for _, file in pairs(GetFilesFromPath(path)) do
        for id, values in pairs(PdxParser.parseFile(path .. "\\" .. file)) do
            local availableDate, rank = earliestDateAndRank(values)
            leaders[id] = {
                id = id,
                name = values["name"],
                starting_skill = values["skill"],
                max_skill = values["max_skill"],
                traits = translateTraits(values["add_trait"]),
                available_date = availableDate,
                rank = rank,
                type = values["type"],
                country = values["country"],
            }
        end
    end
end

--- Every leader of a country, highest starting skill first.
function BiceData.Generals.ForCountry(tag)
    fillData()

    local matching = {}
    for _, general in pairs(leaders) do
        -- Leaders without a skill are malformed entries; the wx page logged and
        -- skipped them, so do the same rather than crash the sort.
        if general.country == tag and general.starting_skill ~= nil then
            table.insert(matching, general)
        end
    end

    table.sort(matching, function(a, b)
        if a.starting_skill ~= b.starting_skill then
            return a.starting_skill > b.starting_skill
        end
        return tostring(a.name) < tostring(b.name)
    end)
    return matching
end

--- One leader by id, or nil.
function BiceData.Generals.Get(id)
    fillData()
    return leaders[id]
end
