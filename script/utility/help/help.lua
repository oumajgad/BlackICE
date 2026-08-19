-- Help tab: the national focus table.
--
-- Which effects a focus grants at each tier lives in BiceData.NatFocus.Effects, shared
-- with the ImGui utility. It knows that a tier is split across _I and _II modifiers
-- where it has more than five effects, and merges them. This keeps the wx half: laying
-- the result out in the grid.

local setup = false

local FOCUS_HEADERS = {
    { column = 1, text = "Level I\n90 Days" },
    { column = 3, text = "Level II\n360 Days" },
    { column = 5, text = "Level III\n720 Days" },
}

--- Where an effect sits in the final tier, so the same effect keeps one row across all
--- three columns and can be read across.
local function rowInFinalTier(finalTier, key)
    for index, effect in ipairs(finalTier) do
        if effect.key == key then
            return index
        end
    end
    return nil
end

local function tallestTier(tiers)
    local size = 0
    for _, tier in ipairs(tiers) do
        if #tier > size then
            size = #tier
        end
    end
    return size
end

local function setupTable()
    local base_font_bold = wx.wxFont(wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT,
        wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "")
    local header_bg_colour = wx.wxColour(230, 145, 56)
    local levels_bg_colour = wx.wxColour(246, 178, 107)

    UI.m_grid_nat_focuses:ClearGrid()
    UI.m_grid_nat_focuses:DeleteRows(0, UI.m_grid_nat_focuses:GetNumberRows(), true)

    -- Title row
    UI.m_grid_nat_focuses:AppendRows(1, true)
    UI.m_grid_nat_focuses:SetCellSize(0, 0, 1, 7)
    UI.m_grid_nat_focuses:SetCellValue(0, 0, "National Focus")
    UI.m_grid_nat_focuses:SetCellBackgroundColour(0, 0, header_bg_colour)

    local header_font = wx.wxFont(base_font_bold)
    header_font:SetPointSize(header_font:GetPointSize() + 6)
    UI.m_grid_nat_focuses:SetCellFont(0, 0, header_font)

    -- Levels row
    UI.m_grid_nat_focuses:AppendRows(1, true)
    local levels_font = wx.wxFont(base_font_bold)
    levels_font:SetPointSize(levels_font:GetPointSize() + 3)
    UI.m_grid_nat_focuses:SetCellBackgroundColour(1, 0, levels_bg_colour)

    for _, header in ipairs(FOCUS_HEADERS) do
        UI.m_grid_nat_focuses:SetCellSize(1, header.column, 1, 2)
        UI.m_grid_nat_focuses:SetCellValue(1, header.column, header.text)
        UI.m_grid_nat_focuses:SetCellFont(1, header.column, levels_font)
        UI.m_grid_nat_focuses:SetCellBackgroundColour(1, header.column, levels_bg_colour)
    end

    local focuses = BiceData.NatFocus.Effects()
    local row = 2
    local focus_header_rows = {}

    for index, focus in ipairs(focuses) do
        local tiers = focus.tiers
        local maxSize = tallestTier(tiers)

        UI.m_grid_nat_focuses:AppendRows(maxSize, true)
        UI.m_grid_nat_focuses:SetCellSize(row, 0, maxSize, 1)
        UI.m_grid_nat_focuses:SetCellValue(row, 0, focus.name)
        UI.m_grid_nat_focuses:SetCellBackgroundColour(row, 0, levels_bg_colour)
        table.insert(focus_header_rows, row)

        for tierIndex, tier in ipairs(tiers) do
            local column = 1 + (tierIndex - 1) * 2
            for effectIndex, effect in ipairs(tier) do
                -- Lined up with the same effect in the final tier where there is one,
                -- so a row can be read across the three levels.
                local finalRow = rowInFinalTier(tiers[3], effect.key)
                local target = (finalRow ~= nil) and (row + finalRow - 1) or (row + effectIndex - 1)

                UI.m_grid_nat_focuses:SetCellValue(target, column, effect.label)
                UI.m_grid_nat_focuses:SetCellValue(target, column + 1, effect.value)
            end
        end

        row = row + maxSize + 1

        if index ~= #focuses then
            -- A spacing row between focuses, but not after the last one.
            UI.m_grid_nat_focuses:AppendRows(1, true)
            for column = 0, 7, 1 do
                UI.m_grid_nat_focuses:SetCellBackgroundColour(row - 1, column, levels_bg_colour)
            end
        end
    end

    UI.m_grid_nat_focuses:AutoSize()

    -- The focus names are made bold after the autosize, or their larger font would
    -- stretch the first row of every focus.
    for _, headerRow in ipairs(focus_header_rows) do
        UI.m_grid_nat_focuses:SetCellFont(headerRow, 0, levels_font)
    end
end

function SetupNationalFocusTable()
    if setup ~= true then
        setupTable()
        setup = true
    end
end
