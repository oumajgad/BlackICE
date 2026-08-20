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
    { module = 'imgui_countryinfo', key = 'CountryInfo' },
    { module = 'imgui_puppets', key = 'Puppets' },
    { module = 'imgui_stratresources', key = 'StratResources' },
    { module = 'imgui_trades', key = 'Trades' },
    { module = 'imgui_natfocus', key = 'NatFocus' },
    { module = 'imgui_ministerbuildings', key = 'MinisterBuildings' },
    { module = 'imgui_tradeai', key = 'TradeAi' },
    { module = 'imgui_prodsliders', key = 'ProdSliders' },
    { module = 'imgui_lssliders', key = 'LsSliders' },
    { module = 'imgui_misc', key = 'Misc' },
    { module = 'imgui_options', key = 'Options' },
    { module = 'imgui_help', key = 'Help' },
    { module = 'imgui_stats', key = 'Stats' },
    { module = 'imgui_console', key = 'Console' },
    { module = 'imgui_warmup', key = 'Warmup' },
    { module = 'imgui_traits',   key = 'Traits' },
    { module = 'imgui_generals',  key = 'Generals' },
    { module = 'imgui_modifiers', key = 'Modifiers' },
    { module = 'imgui_techs',     key = 'Techs' },
    { module = 'imgui_units',      key = 'Units' },
    { module = 'imgui_unitmodels', key = 'UnitModels' },
    { module = 'imgui_provincebuildings', key = 'ProvinceBuildings' },
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

-- Installs the D3D9 hooks. Done here rather than in bicelib_lua.lua so that turning
-- G_ImguiUtilityEnabled off skips the hooks as well as the pages. The overlay starts
-- hidden; INSERT shows it.
if BiceLib ~= nil and BiceLib.Overlay ~= nil then
    BiceLib.Overlay.enable()
end
