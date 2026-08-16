-- Generals page for the in-game ImGui utility.
--
-- Leader parsing lives in BiceData.Generals, so this page works with the wxWidgets
-- utility disabled. Branch and name filtering happen on the C++ side, so typing in
-- the filter costs no Lua calls.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Generals = {}

-- Every general for one country, highest starting skill first.
function BiceLibGui.Generals.Collect(tag)
    local ok, result = pcall(function()
        local rows = {}
        for _, general in ipairs(BiceData.Generals.ForCountry(tag)) do
            table.insert(rows, {
                id = tostring(general.id),
                branch = tostring(general.type),
                label = general.starting_skill .. " (" .. general.max_skill .. ")  " ..
                        general.type .. "  '" .. general.name .. "'  " ..
                        tostring(general.available_date) .. " [" .. general.id .. "]",
            })
        end
        return { available = true, tag = tag, generals = rows }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Definition plus whatever the running game knows about the leader.
function BiceLibGui.Generals.Details(id)
    local ok, result = pcall(function()
        local general = BiceData.Generals.Get(id)
        if general == nil then
            return { available = false, reason = "Unknown leader: " .. tostring(id) }
        end

        local location, locationId, unitName = "unknown", "unknown", "unknown"
        if BiceLib ~= nil then
            local live = BiceLib.Leaders.getLeaderDetails(tonumber(id))
            if live ~= nil then
                local provinceId = live["province_id"]
                if provinceId ~= nil then
                    locationId = tostring(provinceId)
                    location = BiceData.Translations.Get(tostring(provinceId), "PROV") or "unknown"
                end
                unitName = live["unit_name"] or "unknown"
            end
        end

        return {
            available = true,
            id = tostring(id),
            dump = Utils.Dump(general),
            traits = general.traits,
            location = location,
            location_id = locationId,
            unit_name = unitName,
        }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
