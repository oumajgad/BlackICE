-- Unit models tab.
--
-- The model list, the tech requirements and working out which sprite the game will
-- actually draw live in BiceData.UnitModels, shared with the ImGui utility. This keeps
-- the wx half: the choice control, its filter, the tech list box and the bitmap.

local P = {}

P.UnitModelsChoices = {}
P.UnitModelsChoicesFiltered = {}

local gc_counter = 100
local function updateImage(path)
    UI.m_bitmap_GameInfo_UnitModels_Selected:SetBitmap(wx.wxBitmap(path, wx.wxBITMAP_TYPE_ANY))
    UI.m_bitmap_GameInfo_UnitModels_Selected:Refresh()
    UI.m_bitmap_GameInfo_UnitModels_Selected:Update()

    -- Every bitmap loaded here is a new wx object, and a few hundred of them add up.
    if gc_counter < 0 then
        collectgarbage()
        collectgarbage()
        gc_counter = 100
    else
        gc_counter = gc_counter - 1
    end
    UI.m_panel_GameInfo_UnitModels:Layout()
end

local function showChoices(choices)
    UI.m_choice_GameInfo_UnitModels_1:Freeze()
    UI.m_choice_GameInfo_UnitModels_1:Clear()
    UI.m_choice_GameInfo_UnitModels_1:Append(choices)
    UI.m_choice_GameInfo_UnitModels_1:Thaw()
end

function P.FillData()
    -- Parsed on demand by the provider. Kept because the utility calls it.
    BiceData.UnitModels.Choices(G_PlayerCountry)
end

function P.BuildCountryChoices(playerTag)
    P.UnitModelsChoices = BiceData.UnitModels.Choices(playerTag)
    showChoices(P.UnitModelsChoices)
end

function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_UnitModels_1:GetString(
        UI.m_choice_GameInfo_UnitModels_1:GetSelection())
    local modelIdent = BiceData.Translations.KeyFromChoice(selectionString)
    if modelIdent == nil then
        return
    end

    local techlist = {}
    for _, entry in ipairs(BiceData.UnitModels.TechList(G_PlayerCountry, modelIdent)) do
        table.insert(techlist, entry.label)
    end
    UI.m_listBox_GameInfo_UnitModels_Techs:Clear()
    UI.m_listBox_GameInfo_UnitModels_Techs:Append(techlist)

    -- The provider says which sprite the game would use and why, including the fall
    -- back to an earlier model when a level has no image of its own.
    local path, status = BiceData.UnitModels.Image(G_PlayerCountry, modelIdent)
    if path ~= nil then
        updateImage(path)
    end
    UI.m_textCtrl_GameInfo_UnitModels_Status:SetValue(status or "No Image")
end

function P.HandleFilter()
    P.ClearText()

    local filterString = UI.m_textCtrl_GameInfo_UnitModels_Filter:GetValue()
    if filterString == nil or filterString == "" then
        showChoices(P.UnitModelsChoices)
        if UI.m_choice_GameInfo_UnitModels_1:GetCount() >= 1 then
            UI.m_choice_GameInfo_UnitModels_1:SetSelection(0)
            P.HandleSelection()
        end
        return
    end

    P.UnitModelsChoicesFiltered = {}
    for _, choice in pairs(P.UnitModelsChoices) do
        if string.find(string.lower(choice), string.lower(filterString)) then
            table.insert(P.UnitModelsChoicesFiltered, choice)
        end
    end

    showChoices(P.UnitModelsChoicesFiltered)
    if UI.m_choice_GameInfo_UnitModels_1:GetCount() >= 1 then
        UI.m_choice_GameInfo_UnitModels_1:SetSelection(0)
        P.HandleSelection()
    end
end

function P.ClearText()
    UI.m_panel_GameInfo_UnitModels:Freeze()
    UI.m_listBox_GameInfo_UnitModels_Techs:Clear()
    UI.m_textCtrl_GameInfo_UnitModels_Status:Clear()
    UI.m_panel_GameInfo_UnitModels:Thaw()
end

return P
