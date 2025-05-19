local P = {}


local properties = {
    ["air_attack"] = {          factor = 0.001, unit = "", translation = nil },
    ["air_defence"] = {         factor = 0.001, unit = "", translation = nil },
    ["air_detection"] = {       factor = 0.001, unit = "", translation = nil },
    ["armor"] = {               factor = 0.001, unit = "", translation = "Armor" },
    ["convoy_attack"] = {       factor = 0.001, unit = "", translation = nil },
    ["defensiveness"] = {       factor = 0.001, unit = "", translation = nil },
    ["firing_distance"] = {     factor = 0.001, unit = " km", translation = "Firing Distance" },
    ["fuel_consumption"] = {    factor = 0.001, unit = "", translation = nil },
    ["hard_attack"] = {         factor = 0.001, unit = "", translation = nil },
    ["hull"] = {                factor = 0.001, unit = "", translation = nil },
    ["max_organisation"] = {    factor = 0.001, unit = "", translation = "Max Organisation" },
    ["manpower"] = {            factor = 0.001, unit = "", translation = "Manpower" },
    ["max_speed"] = {           factor = 0.001, unit = " kph", translation = "Max Speed" },
    ["max_strength"] = {        factor = 0.001, unit = "", translation = nil },
    ["morale"]  = {             factor = 0.1, unit = "%", translation = nil },
    ["officers"] = {            factor = 0.001, unit = "", translation = "Officers" },
    ["piercing_attack"] = {     factor = 0.001, unit = "", translation = "Piercing Attack" },
    ["positioning"] = {         factor = 0.001, unit = "", translation = nil },
    ["range"] = {               factor = 0.001, unit = " km", translation = nil },
    ["sea_attack"] = {          factor = 0.001, unit = "", translation = nil },
    ["sea_defence"] = {         factor = 0.001, unit = "", translation = nil },
    ["shore_bombardment"] = {   factor = 0.001, unit = "", translation = nil },
    ["soft_attack"] = {         factor = 0.001, unit = "", translation = nil },
    ["softness"] = {            factor = 0.1, unit = "%", translation = nil },
    ["strategic_attack"] = {    factor = 0.001, unit = "", translation = nil },
    ["sub_attack"] = {          factor = 0.001, unit = "", translation = nil },
    ["sub_unit_amount"] = {     factor = 1, unit = "", translation = "Sub Units" },
    ["supply_consumption"] = {  factor = 0.001, unit = "", translation = nil },
    ["suppression"] = {         factor = 0.001, unit = "", translation = nil },
    ["surface_defence"] = {     factor = 0.001, unit = "", translation = nil },
    ["surface_detection"] = {   factor = 0.001, unit = "", translation = nil },
    ["toughness"] = {           factor = 0.001, unit = "", translation = nil },
    ["transport_capacity"] = {  factor = 0.001, unit = "", translation = "Transport Capacity" },
    ["visibility"] = {          factor = 0.001, unit = "", translation = nil },
    ["weight"] = {              factor = 0.001, unit = "", translation = "Weight" },
    ["width"] = {               factor = 0.001, unit = "", translation = "Width" },
}

local blacklists = {
    ["Army"] = {
        "type", "name",
        "air_detection", "convoy_attack", "firing_distance", "hull", "positioning", "range", "sea_attack", "sea_defence",
        "shore_bombardment", "strategic_attack", "sub_attack", "sub_unit_amount", "surface_defence", "surface_detection", "transport_capacity",
        "visibility",
    },
    ["Navy"] = {
        "type", "name",
        "armor", "defensiveness", "hard_attack", "piercing_attack", "soft_attack", "softness", "strategic_attack",
        "suppression", "surface_defence", "toughness", "weight", "width"
    },
    ["Air"] = {
        "type", "name",
        "armor", "convoy_attack", "defensiveness", "firing_distance", "hull", "piercing_attack", "positioning", "sea_defence",
        "shore_bombardment", "softness", "sub_attack", "suppression", "toughness", "visibility", "weight", "width"
    }
}

P.ActiveWindows = {}

local function getTargetFontSize()
    return UI.MyFrame1:GetChildren():Item(1):GetData():DynamicCast("wxWindow"):GetFont():GetPointSize()
end

local function createDetailsPage(unitName, unitType, unitData)
    local UI = {}

    -- Start of generated code

    UI.UnitDetailsTemplate = wx.wxFrame (wx.NULL, wx.wxID_ANY, "UnitDetails: " .. unitName, wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxDEFAULT_FRAME_STYLE+wx.wxTAB_TRAVERSAL )
	UI.UnitDetailsTemplate:SetSizeHints( wx.wxSize( -1,-1 ), wx.wxDefaultSize )
	UI.UnitDetailsTemplate.m_mgr = wxaui.wxAuiManager()
	UI.UnitDetailsTemplate.m_mgr:SetManagedWindow( UI.UnitDetailsTemplate )

	UI.m_panel_UnitDetails = wx.wxPanel( UI.UnitDetailsTemplate, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.m_panel_UnitDetails:SetForegroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_WINDOW ) )
	UI.m_panel_UnitDetails:SetBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_WINDOW ) )
	UI.UnitDetailsTemplate.m_mgr:AddPane( UI.m_panel_UnitDetails, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):PinButton( True ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.bSizer_UnitDetails1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_textCtrl_UnitDetails_Name = wx.wxTextCtrl( UI.m_panel_UnitDetails, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_UnitDetails_Name:Enable( False )

	UI.bSizer_UnitDetails1:Add( UI.m_textCtrl_UnitDetails_Name, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_UnitDetails_Data = wx.wxTextCtrl( UI.m_panel_UnitDetails, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 130,-1 ), wx.wxTE_MULTILINE )
	UI.bSizer_UnitDetails1:Add( UI.m_textCtrl_UnitDetails_Data, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )


	UI.m_panel_UnitDetails:SetSizer( UI.bSizer_UnitDetails1 )
	UI.m_panel_UnitDetails:Layout()
	UI.bSizer_UnitDetails1:Fit( UI.m_panel_UnitDetails )

	UI.UnitDetailsTemplate .m_mgr:Update()
	UI.UnitDetailsTemplate:Centre( wx.wxBOTH )

    -- End of generated code

    UI.m_textCtrl_UnitDetails_Name:SetValue(unitName)

    local s = P.dumpUnitData(unitType, unitData)

    UI.m_textCtrl_UnitDetails_Data:SetValue(s)
    UI.UnitDetailsTemplate:Show(true)

    -- Insert into table for future font size changes
    table.insert(P.ActiveWindows, UI.UnitDetailsTemplate)

    -- change font size to match current setting
    local currentSize = UI.UnitDetailsTemplate:GetChildren():Item(1):GetData():DynamicCast("wxWindow"):GetFont():GetPointSize()
    local targetSize = getTargetFontSize()
    ApplyFontRecursivelyToWxWindows(UI.UnitDetailsTemplate, targetSize - currentSize)
end

local function convertValue(key, val)
    local numberVal = tonumber(val)
    if numberVal == nil then
        return val
    end

    local convertedNumberVal = numberVal * properties[key].factor

    return string.format('%.02f', convertedNumberVal) .. properties[key].unit
end

function P.dumpUnitData(unitType, data)
    local translated = {}
    for k, v in pairs(data) do
        if table.getIndex(blacklists[unitType], k) == nil then
            local trans = properties[k].translation

            if trans == nil then
            trans = Parsing.GetTranslation(string.upper(k))
            end
            if trans == nil then
                trans = Parsing.GetTranslation(string.lower(k))
            end
            if trans == nil then
                trans = k
            end

            translated[trans] = convertValue(k, v)
        end
    end
    return Utils.DumpByMetatableOrder(Utils.PushTablesToEndAndSort(translated))
end

function P.createDetailsPageForSelection()
    if BiceLib == nil then
        return
    end

    local entities = BiceLib.Inspector.getSelectedEntity()
    Utils.INSPECT_TABLE(entities)
    if entities == nil then
        return
    end

    for i, entity in ipairs(entities) do
        if entity["type"] ~= "Province" then
            createDetailsPage(entity["name"], entity["type"], entity)
        end
    end

end


return P