-- Trade AI page for the in-game ImGui utility.

BiceLibGui = BiceLibGui or {}
BiceLibGui.TradeAi = {}

local function snapshot()
    local data, reason = BiceData.TradeAi.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return {
        available = true,
        tag = data.tag,
        active = data.active,
        configured = data.configured,
        maxDailySell = data.maxDailySell,
        rows = data.rows,
    }
end

function BiceLibGui.TradeAi.Collect()
    local ok, result = pcall(snapshot)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

--- Stages one field. The page sends them one at a time, then calls Commit.
function BiceLibGui.TradeAi.SetValue(field, value)
    local ok, result, reason = pcall(BiceData.TradeAi.SetValue, field, value)
    if not ok then
        return { ok = false, reason = tostring(result) }
    end
    return { ok = result == true, reason = reason or "" }
end

function BiceLibGui.TradeAi.Discard()
    pcall(BiceData.TradeAi.Discard)
end

--- Applies the staged set and reports back the state that follows it.
function BiceLibGui.TradeAi.Commit()
    local called, ok, reason = pcall(BiceData.TradeAi.Commit)
    if not called then
        return { ok = false, reason = tostring(ok) }
    end
    if not ok then
        return { ok = false, reason = reason or "rejected" }
    end

    local result = BiceLibGui.TradeAi.Collect()
    result.ok = true
    return result
end

function BiceLibGui.TradeAi.SetActive(enabled)
    local ok, result = pcall(function()
        BiceData.TradeAi.SetActive(enabled ~= 0)
        return snapshot()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
