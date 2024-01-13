local modifiers = {}
local setup = false

local function mapFocusModifiers()
    local function insert(orig, new)
        for k, v in pairs(new) do
            if k ~= "potential" and k ~= "trigger" and k ~= "icon" then
                orig[k] = v
            end
        end
    end

    local result = {
        ["ground_forces"] = {},
        ["air_force"] = {},
        ["navy"] = {},
        ["economy"] = {},
        ["science"] = {},
        ["health_and_education"] = {},
        ["natural_resources"] = {},
    }
    for k, v in pairs(result) do
        result[k] = {
            [1] = {},
            [2] = {},
            [3] = {}
        }
    end

    for modifier_name, modifier_values in pairs(Parsing.Modifiers.ModifierData) do
        for focus_name, _ in pairs(result) do
            if string.find(modifier_name, "Nat_focus_" .. focus_name) then
                if string.find(modifier_name, "_one") then
                    insert(result[focus_name][1], modifier_values)
                elseif string.find(modifier_name, "_two") then
                    insert(result[focus_name][2], modifier_values)
                elseif string.find(modifier_name, "_three") then
                    insert(result[focus_name][3], modifier_values)
                end
            end
        end
    end

    -- Utils.INSPECT_TABLE(result)
    modifiers = result
end

local function setupTable()
    local function getMaxSize(focus_levels)
        local size = 0
        for i, level in ipairs(focus_levels) do
            local l = table.getLength(level)
            if l > size then
                size = l
            end
        end
        return size
    end
    -- Get the row in which an effect will be positioned at level 3, so that we can position it there at level 1
    local function getFinalRow(final_level, key)
        local i = 0
        for effect_key, effect in spairs(final_level, SortAscending) do
            i = i + 1
            if effect_key == key then
                return i
            end
        end
        return nil
    end

    local order = {
        "ground_forces",
        "air_force",
        "navy",
        "economy",
        "science",
        "health_and_education",
        "natural_resources"
    }
    local focus_translations = {
        ["ground_forces"] = "Army",
        ["air_force"] = "Air",
        ["navy"] = "Navy",
        ["economy"] = "Economy",
        ["science"] = "Science",
        ["health_and_education"] = "Health & Education",
        ["natural_resources"] = "Resources"
    }

    local base_font_bold = wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" )
    local header_bg_colour = wx.wxColour( 230, 145, 56 )
    local levels_bg_colour = wx.wxColour( 246, 178, 107 )
    local focus_header_bg_colour = levels_bg_colour

    UI.m_grid_nat_focuses:ClearGrid()
    UI.m_grid_nat_focuses:DeleteRows(0, UI.m_grid_nat_focuses:GetNumberRows(), true )

    -- Add title row
    UI.m_grid_nat_focuses:AppendRows(1, true)
    UI.m_grid_nat_focuses:SetCellSize(0,0,1,7)
    UI.m_grid_nat_focuses:SetCellValue(0,0,"National Focus")
    UI.m_grid_nat_focuses:SetCellBackgroundColour(0,0, header_bg_colour)
    -- set font
    local header_font = wx.wxFont(base_font_bold)
    header_font:SetPointSize(header_font:GetPointSize() + 6)
    UI.m_grid_nat_focuses:SetCellFont(0,0,header_font)

    -- Add Levels Row
    UI.m_grid_nat_focuses:AppendRows(1, true)
    UI.m_grid_nat_focuses:SetCellSize(1,1,1,2)
    UI.m_grid_nat_focuses:SetCellValue(1,1,"Level I\n90 Days")
    UI.m_grid_nat_focuses:SetCellSize(1,3,1,2)
    UI.m_grid_nat_focuses:SetCellValue(1,3,"Level II\n360 Days")
    UI.m_grid_nat_focuses:SetCellSize(1,5,1,2)
    UI.m_grid_nat_focuses:SetCellValue(1,5,"Level III\n720 Days")
    -- set font
    local levels_font = wx.wxFont(base_font_bold)
    levels_font:SetPointSize(levels_font:GetPointSize() + 3)
    UI.m_grid_nat_focuses:SetCellFont(1,1,levels_font)
    UI.m_grid_nat_focuses:SetCellFont(1,3,levels_font)
    UI.m_grid_nat_focuses:SetCellFont(1,5,levels_font)
    UI.m_grid_nat_focuses:SetCellBackgroundColour(1,0,levels_bg_colour)
    UI.m_grid_nat_focuses:SetCellBackgroundColour(1,1,levels_bg_colour)
    UI.m_grid_nat_focuses:SetCellBackgroundColour(1,3,levels_bg_colour)
    UI.m_grid_nat_focuses:SetCellBackgroundColour(1,5,levels_bg_colour)


    local row = 2
    local focus_header_font = levels_font
    for i, focus in ipairs(order) do
        local levels = modifiers[focus]
        local maxSize = getMaxSize(levels)
        -- Append needed amount of rows
        UI.m_grid_nat_focuses:AppendRows(maxSize, true)
        -- Create leftside header cell with focus name
        UI.m_grid_nat_focuses:SetCellSize(row,0,maxSize,1)
        UI.m_grid_nat_focuses:SetCellValue(row,0,focus_translations[focus])
        UI.m_grid_nat_focuses:SetCellFont(row,0,focus_header_font)
        UI.m_grid_nat_focuses:SetCellBackgroundColour(row,0,focus_header_bg_colour)

        local column = 1
        for j, level in ipairs(levels) do
            local row_inner = row
            for effect_key, effect in spairs(level, SortAscending) do
                -- get the row in which the effect will sit at in the final level
                local final_row = getFinalRow(levels[3], effect_key)
                if final_row == nil then
                    final_row = row_inner -- if none found proceed with the normal counted way
                else
                    final_row = row + final_row - 1 -- use 'row' because 'final_row' is offset from that, -1 because wx.Grid is 0 based
                end
                -- Utils.LUA_DEBUGOUT(effect_key .. " - " .. final_row)

                UI.m_grid_nat_focuses:SetCellValue(final_row,column,Parsing.Modifiers.GetTranslation(effect_key))
                UI.m_grid_nat_focuses:SetCellValue(final_row,column+1,Parsing.UnitConversions.GetAndConvertEffect(effect_key, effect))
                row_inner = row_inner + 1
            end
            column = column + 2
        end

        row = row + maxSize + 1

        if i ~= #order then
            -- add spacing row between focuses, but not for the last one
            UI.m_grid_nat_focuses:AppendRows(1, true)
            for z=0,7,1 do
                UI.m_grid_nat_focuses:SetCellBackgroundColour(row-1,z,levels_bg_colour)
            end
        end
    end



    UI.m_grid_nat_focuses:AutoSize()
end

function SetupNationalFocusTable()
    if setup ~= true then
        mapFocusModifiers()
        setupTable()
        setup = true
    end
end
