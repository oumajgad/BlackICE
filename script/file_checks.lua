-- A collection of one time scripts I use for debugging and stuff

local P = {}

local units_to_ranks = {
    ["theatre"] = 4,
    ["armygroup"] = 4,
    ["army"] = 3,
    ["corps"] = 2,
    ["division"] = 1,
}
local assignments = {}
local function getAssignmentsFromOob(oob)
    for key, values in pairs(oob) do
        if units_to_ranks[key] ~= nil then
            if values["leader"] ~= nil then
                local leader_data = Parsing.Generals.GeneralsData[values["leader"]]
                local leader_rank = nil
                local wrong_rank = false
                if leader_data ~= nil then
                    leader_rank = leader_data["rank"]
                    if tostring(units_to_ranks[key]) ~= leader_rank then
                        wrong_rank = true
                    end
                end
                local assignment = {
                    unit_name = values["name"],
                    leader_id = values["leader"],
                    leader_rank = leader_rank,
                    unit_type = key,
                    wrong_rank = wrong_rank
                }
                table.insert(assignments, assignment)
            end
        end
        if type(values) == "table" then
            getAssignmentsFromOob(values)
        end
    end
end

function P.checkAssignedLeaderRanks()
    Parsing.Generals.FillData()

    assignments = {}
    -- local file_contents = {}

    local base_folder = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\history\\units"
    local subfolders = {
        "","\\AST","\\CAN","\\CHI","\\ENG","\\FIN","\\FRA","\\GER","\\HUN","\\ITA","\\JAP",
        "\\Johnson","\\MarneMod","\\POL","\\ROM","\\SOV","\\SPA","\\SPR","\\USA","\\Vichy"
    }
    for i, subfolder in ipairs(subfolders) do
        for j, file in pairs(GetFilesFromPath(base_folder .. subfolder)) do
            -- Utils.LUA_DEBUGOUT(base_folder .. subfolder .. "\\" .. file)
            local res = PdxParser.parseFile(base_folder .. subfolder .. "\\" .. file)
            Utils.LUA_DEBUGOUT("Inspecting assignments for: " .. subfolder .. "\\" .. file)
            getAssignmentsFromOob(res)
            -- table.insert(file_contents, res)
        end
    end
    local wrong_ranks = {}
    for i, assignment in ipairs(assignments) do
        if assignment.wrong_rank then
            table.insert(wrong_ranks, assignment)
        end
    end
    Utils.INSPECT_TABLE(wrong_ranks)
    Utils.LUA_DEBUGOUT("Done")
end

return P