-- Loader for the in-game ImGui utility pages.
--
-- One require per page, mirroring the one .cpp per page on the C++ side. Each page
-- owns a table under BiceLibGui and the overlay calls into it by dotted path, so
-- pages stay independent of each other and of the old wxWidgets utility.
--
-- autoexec.lua runs once per Lua context, so this file runs once per context too and
-- BiceLibGui ends up defined in each of them. That matters: the overlay calls into
-- whichever context the render thread uses.
--
-- Module files MUST keep the imgui_ prefix. Lua's require caches by module name and
-- the old utility already claims the obvious ones (ic_days, country_info, misc,
-- setup, puppets, techs, traits, units, modifiers, flags, vars, generals, stats,
-- options, help). Without the prefix require returns the old module from the cache
-- and the page file never runs, with no error raised.

BiceLibGui = BiceLibGui or {}

-- module = file under utility_imgui, key = table it must define on BiceLibGui
local pages = {
    { module = 'imgui_setup',   key = 'Setup' },
    { module = 'imgui_ic_days', key = 'ICDays' },
}

local loaded = {}
local failed = {}

for _, page in ipairs(pages) do
    -- pcall so one broken page cannot abort autoexec and take the rest of the mod
    -- down with it.
    local ok, err = pcall(require, page.module)
    if not ok then
        table.insert(failed, page.module .. ": " .. tostring(err))
    elseif BiceLibGui[page.key] == nil then
        -- Loaded without error but registered nothing: almost always a module name
        -- collision serving a cached module instead of ours.
        table.insert(failed, page.module .. ": did not define BiceLibGui." .. page.key)
    else
        table.insert(loaded, page.module)
    end
end

if BiceLibLuaLog ~= nil then
    BiceLibLuaLog("gui-imgui loaded pages: " .. table.concat(loaded, ", "))
    if #failed > 0 then
        BiceLibLuaLog("gui-imgui FAILED pages: " .. table.concat(failed, " | "))
    end
end
