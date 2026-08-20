-- Minister buildings tab.
--
-- The counters and their triggers live in BiceData.MinisterBuildings, shared with the
-- ImGui utility. What is left here is the wx half: which control shows which building.

-- Called each refresh and once at country selection
function GetMinisterBuildingsProgress()
    local data = BiceData.MinisterBuildings.Collect()
    if data == nil then
        return
    end

    for _, row in ipairs(data.rows) do
        -- Nothing built towards yet reads as a plain 0, as it always did, rather than
        -- as "0.0".
        local progress = (row.count > 0) and string.format('%.01f', row.percent) or "0"
        SetMinisterBuildingsProgressText(row.key, progress)
    end
end

-- Called from internal
function SetMinisterBuildingsProgressText(building, progress)
    if building == "hospital" then
        UI.m_textCtrl_Hospital:SetValue(progress .. "%")
    elseif building == "rail_terminus" then
        UI.m_textCtrl_RailTerminus:SetValue(progress .. "%")
    elseif building == "resource_buildings" then
        UI.m_textCtrl_ResourceBuildings:SetValue(progress .. "%")
    elseif building == "automotive_factory" then
        UI.m_textCtrl_AutomotiveFactory:SetValue(progress .. "%")
    elseif building == "radar_station" then
        UI.m_textCtrl_RadarStation:SetValue(progress .. "%")
    elseif building == "artillery_factory" then
        UI.m_textCtrl_ArtilleryFactory:SetValue(progress .. "%")
    elseif building == "military_college" then
        UI.m_textCtrl_TrainingCenters:SetValue(progress .. "%")
    elseif building == "research_lab" then
        UI.m_textCtrl_ResearchCenters:SetValue(progress .. "%")
    elseif building == "supplies_factory" then
        UI.m_textCtrl_SupplyFactory:SetValue(progress .. "%")
    elseif building == "heavy_industry" then
        UI.m_textCtrl_HeavyIndustry:SetValue(progress .. "%")
    elseif building == "submarine_shipyard" then
        UI.m_textCtrl_SubmarineShipyard:SetValue(progress .. "%")
    elseif building == "capital_ship_shipyard" then
        UI.m_textCtrl_CapitalShipyard:SetValue(progress .. "%")
    elseif building == "medium_ship_shipyard" then
        UI.m_textCtrl_MediumShipyard:SetValue(progress .. "%")
    elseif building == "small_ship_shipyard" then
        UI.m_textCtrl_SmallShipyard:SetValue(progress .. "%")
    elseif building == "heavy_aircraft_factory" then
        UI.m_textCtrl_HeavyAircraftFactory:SetValue(progress .. "%")
    elseif building == "medium_aircraft_factory" then
        UI.m_textCtrl_MediumAircraftFactory:SetValue(progress .. "%")
    elseif building == "light_aircraft_factory" then
        UI.m_textCtrl_LightAircraftFactory:SetValue(progress .. "%")
    elseif building == "tank_factory" then
        UI.m_textCtrl_TankFactory:SetValue(progress .. "%")
    elseif building == "smallarms_factory" then
        UI.m_textCtrl_SmlArmsFactory:SetValue(progress .. "%")
    end
end
