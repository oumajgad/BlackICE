-- Country info tab.
--
-- The values, including the technology contributions the game's API does not expose,
-- live in BiceData.CountryInfo and are shared with the ImGui utility. This keeps the wx
-- half: which control shows which value, and in what format.
--
-- The provider hands back both a formatted string and the raw number per row. The raw
-- one is used here because these controls sit beside labels that already carry the
-- unit, so a "%" in the value would be printed twice.

-- Which control shows which row, by the provider's label. A row it does not know about
-- is left alone rather than cleared, so a provider gaining a value cannot blank a
-- control here.
local CONTROLS = {
    ["Base IC"] = { control = "m_textCtrl_baseIc", format = '%.0f' },
    ["Offmap IC"] = { control = "m_textCtrl_offmapIc", format = '%.0f' },
    ["IC modifier"] = { control = "m_textCtrl_icModifier", format = '%.02f', scale = 100 },
    ["IC efficiency"] = { control = "m_textCtrl_IcEff", format = '%.02f' },
    ["Supplies per IC"] = { control = "m_textCtrl_suppliesPerIc", format = '%.2f' },
    ["Research efficiency"] = { control = "m_textCtrl_ResEff", format = '%.02f' },
    ["Supply throughput"] = { control = "m_textCtrl_SuppThrou", format = '%.02f' },
    ["Repair efficiency"] = { control = "m_textCtrl_RepairEff", format = '%.02f', scale = 100 },
    ["Starting experience"] = { control = "m_textCtrl_StartingExp", format = '%.02f' },
    ["Org regain"] = { control = "m_textCtrl_orgRegain", format = '%.02f', scale = 100 },
    ["Attack delay"] = { control = "m_textCtrl_attackDelay", format = '%.0f' },
    ["Trickleback"] = { control = "m_textCtrl_trickleback", format = '%.02f', scale = 100,
                        missing = "Failed to load" },
    ["Monthly"] = { control = "m_textCtrl_WarExhaustion", format = '%.02f' },
    ["Current"] = { control = "m_textCtrl_currentWarExhaustion", format = '%.1f' },
}

-- Called each refresh
function GetPlayerModifiers()
    local rows = BiceData.CountryInfo.ByLabel()
    if rows == nil then
        return
    end

    for label, target in pairs(CONTROLS) do
        local control = UI[target.control]
        local row = rows[label]

        if control ~= nil and row ~= nil then
            if row.raw == nil then
                -- The provider could not work it out; trickleback needs BiceLib.
                control:SetValue(target.missing or "unavailable")
            else
                control:SetValue(string.format(target.format, row.raw * (target.scale or 1)))
            end
        end
    end
end
