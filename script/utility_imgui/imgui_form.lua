-- Shared shaping for the three AI settings pages.
--
-- Trade AI, Prod. Sliders AI and LS Sliders AI present the same five calls to the
-- overlay, differing only in which provider they drive, so the bodies live here once
-- and each page file states its own surface in terms of them.
--
-- Everything is wrapped in pcall: a page erroring here would otherwise raise inside
-- lua_pcall on the render thread, and the overlay would only be able to report that
-- something went wrong, not what.

local Form = {}

-- A page whose provider never loaded would otherwise fault on the first call, and the
-- overlay would report nothing more useful than a blank panel.
local function missing(provider, name)
    return provider == nil or provider[name] == nil
end

local function unavailable(name)
    return { available = false, ok = false, reason = "Data provider missing: " .. name }
end

--- The provider's current state, shaped for the page.
function Form.Collect(provider)
    if missing(provider, 'Collect') then
        return unavailable('Collect')
    end

    local ok, data, reason = pcall(provider.Collect)
    if not ok then
        return { available = false, reason = tostring(data) }
    end
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end

    data.available = true
    return data
end

--- Stages one field. The page sends them one at a time, then calls Commit.
function Form.SetValue(provider, field, value)
    if missing(provider, 'SetValue') then
        return unavailable('SetValue')
    end

    local ok, staged, reason = pcall(provider.SetValue, field, value)
    if not ok then
        return { ok = false, reason = tostring(staged) }
    end
    return { ok = staged == true, reason = reason or "" }
end

--- Throws away a staged set the page decided not to send.
function Form.Discard(provider)
    if missing(provider, 'Discard') then
        return
    end
    pcall(provider.Discard)
end

--- Applies the staged set, or reports why it was refused - a refused set leaves the
--- game untouched rather than half applied.
---
--- Values the provider had to clamp come back as corrections, so the page can show
--- what was applied rather than what was typed.
function Form.Commit(provider)
    if missing(provider, 'Commit') then
        return unavailable('Commit')
    end

    local called, committed, reason, corrections = pcall(provider.Commit)
    if not called then
        return { ok = false, reason = tostring(committed) }
    end
    if not committed then
        return { ok = false, reason = reason or "rejected" }
    end

    local result = Form.Collect(provider)
    result.ok = true

    result.corrections = {}
    for field, value in pairs(corrections or {}) do
        table.insert(result.corrections, { field = field, value = value })
    end
    return result
end

--- Switches the AI on or off, reporting the state that follows.
function Form.SetActive(provider, enabled)
    if missing(provider, 'SetActive') then
        return unavailable('SetActive')
    end

    local ok, err = pcall(provider.SetActive, enabled ~= 0)
    if not ok then
        return { available = false, reason = tostring(err) }
    end
    return Form.Collect(provider)
end

return Form
