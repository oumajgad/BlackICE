-- Prod. Sliders AI page for the in-game ImGui utility.

BiceLibGui = BiceLibGui or {}
BiceLibGui.ProdSliders = {}

local function snapshot()
    local data, reason = BiceData.ProdSliders.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return {
        available = true,
        tag = data.tag,
        active = data.active,
        configured = data.configured,
        rows = data.rows,
    }
end

function BiceLibGui.ProdSliders.Collect()
    local ok, result = pcall(snapshot)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

--- Stages one field. The page sends them one at a time, then calls Commit.
function BiceLibGui.ProdSliders.SetValue(field, value)
    local ok, result, reason = pcall(BiceData.ProdSliders.SetValue, field, value)
    if not ok then
        return { ok = false, reason = tostring(result) }
    end
    return { ok = result == true, reason = reason or "" }
end

function BiceLibGui.ProdSliders.Discard()
    pcall(BiceData.ProdSliders.Discard)
end

--- Applies the staged set, or reports why it was refused - a priority used twice
--- leaves the game untouched rather than half applied.
function BiceLibGui.ProdSliders.Commit()
    local called, ok, reason = pcall(BiceData.ProdSliders.Commit)
    if not called then
        return { ok = false, reason = tostring(ok) }
    end
    if not ok then
        return { ok = false, reason = reason or "rejected" }
    end

    local result = BiceLibGui.ProdSliders.Collect()
    result.ok = true
    return result
end

function BiceLibGui.ProdSliders.SetActive(enabled)
    local ok, result = pcall(function()
        BiceData.ProdSliders.SetActive(enabled ~= 0)
        return snapshot()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
