-- Called each refresh and once at country selection
function GetMinisterBuildingsProgress()
    local buildings = {
        ["hospital"] = 40,
        ["rail_terminous"] = 30,
        ["resource_buildings"] = 54,
        ["automotive_factory"] = 54,
        ["radar_station"] = 40,
        ["artillery_factory"] = 65,
        ["military_college"] = 50,
        ["research_lab"] = 42,
        ["supplies_factory"] = 30,
        ["heavy_industry"] = 70,
        ["submarine_shipyard"] = 110,
        ["capital_ship_shipyard"] = 80,
        ["medium_ship_shipyard"] = 54,
        ["small_ship_shipyard"] = 30,
        ["heavy_aircraft_factory"] = 110,
        ["medium_aircraft_factory"] = 110,
        ["light_aircraft_factory"] = 110,
        ["tank_factory"] = 110,
        ["smallarms_factory"] = 80
    }
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    local playerVariables = playerCountryTag:GetCountry():GetVariables()
    for building, trigger in pairs(buildings) do
        local count = playerVariables:GetVariable(CString(building .. "_variable_count_minister")):Get()
        if count > 0 then
            local percent = (count / trigger) * 100
            SetMinisterBuildingsProgressText(building, string.format('%.01f', percent))
        else
            SetMinisterBuildingsProgressText(building, "0")
        end
    end
end

-- Called from internal
function SetMinisterBuildingsProgressText(building, progress)
    if building == "hospital" then
        UI.m_textCtrl_Hospital:SetValue(progress .. "%")
    end
    if building == "rail_terminous" then
        UI.m_textCtrl_RailTerminus:SetValue(progress .. "%")
    end
    if building == "resource_buildings" then
        UI.m_textCtrl_ResourceBuildings:SetValue(progress .. "%")
    end
    if building == "automotive_factory" then
        UI.m_textCtrl_AutomotiveFactory:SetValue(progress .. "%")
    end
    if building == "radar_station" then
        UI.m_textCtrl_RadarStation:SetValue(progress .. "%")
    end
    if building == "artillery_factory" then
        UI.m_textCtrl_ArtilleryFactory:SetValue(progress .. "%")
    end
    if building == "military_college" then
        UI.m_textCtrl_TrainingCenters:SetValue(progress .. "%")
    end
    if building == "research_lab" then
        UI.m_textCtrl_ResearchCenters:SetValue(progress .. "%")
    end
    if building == "supplies_factory" then
        UI.m_textCtrl_SupplyFactory:SetValue(progress .. "%")
    end
    if building == "heavy_industry" then
        UI.m_textCtrl_HeavyIndustry:SetValue(progress .. "%")
    end
    if building == "submarine_shipyard" then
        UI.m_textCtrl_SubmarineShipyard:SetValue(progress .. "%")
    end
    if building == "capital_ship_shipyard" then
        UI.m_textCtrl_CapitalShipyard:SetValue(progress .. "%")
    end
    if building == "medium_ship_shipyard" then
        UI.m_textCtrl_MediumShipyard:SetValue(progress .. "%")
    end
    if building == "small_ship_shipyard" then
        UI.m_textCtrl_SmallShipyard:SetValue(progress .. "%")
    end
    if building == "heavy_aircraft_factory" then
        UI.m_textCtrl_HeavyAircraftFactory:SetValue(progress .. "%")
    end
    if building == "medium_aircraft_factory" then
        UI.m_textCtrl_MediumAircraftFactory:SetValue(progress .. "%")
    end
    if building == "light_aircraft_factory" then
        UI.m_textCtrl_LightAircraftFactory:SetValue(progress .. "%")
    end
    if building == "tank_factory" then
        UI.m_textCtrl_TankFactory:SetValue(progress .. "%")
    end
    if building == "smallarms_factory" then
        UI.m_textCtrl_SmlArmsFactory:SetValue(progress .. "%")
    end
end
