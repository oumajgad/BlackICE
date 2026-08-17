-- LS Sliders AI page for the in-game ImGui utility.

BiceLibGui = BiceLibGui or {}
BiceLibGui.LsSliders = {}

local function snapshot()
    local data, reason = BiceData.LsSliders.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return {
        available = true,
        tag = data.tag,
        active = data.active,
        configured = data.configured,
        bufferNco = data.bufferNco,
        rows = data.rows,
    }
end

function BiceLibGui.LsSliders.Collect()
    local ok, result = pcall(snapshot)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

--- Stages one field. The page sends them one at a time, then calls Commit.
function BiceLibGui.LsSliders.SetValue(field, value)
    local ok, result, reason = pcall(BiceData.LsSliders.SetValue, field, value)
    if not ok then
        return { ok = false, reason = tostring(result) }
    end
    return { ok = result == true, reason = reason or "" }
end

function BiceLibGui.LsSliders.Discard()
    pcall(BiceData.LsSliders.Discard)
end

--- Applies the staged set. Values the provider had to clamp come back as corrections,
--- so the page can show what was applied rather than what was typed.
function BiceLibGui.LsSliders.Commit()
    local called, ok, reason, corrections = pcall(BiceData.LsSliders.Commit)
    if not called then
        return { ok = false, reason = tostring(ok) }
    end
    if not ok then
        return { ok = false, reason = reason or "rejected" }
    end

    local result = BiceLibGui.LsSliders.Collect()
    result.ok = true

    result.corrections = {}
    for field, value in pairs(corrections or {}) do
        table.insert(result.corrections, { field = field, value = value })
    end
    return result
end

function BiceLibGui.LsSliders.SetActive(enabled)
    local ok, result = pcall(function()
        BiceData.LsSliders.SetActive(enabled ~= 0)
        return snapshot()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
