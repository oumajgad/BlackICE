local P = {}
Stats = P

P.CollectStats = false
P.CustomCountryListActive = false
P.CustomCountryList = nil

function P.CustomListCheck(tag)
	-- early exit if not active
	if P.CustomCountryListActive ~= true then
		return true
	end
	-- set up list when not yet done
	if P.CustomCountryList == nil then
		local omgTag = CCountryDataBase.GetTag("OMG")
		local omgCountry = omgTag:GetCountry()
		local variables = omgCountry:GetVariables()
		P.CustomCountryList = {}
		for country in CCurrentGameState.GetCountries() do
			local countryTag = country:GetCountryTag()
			local _tag = tostring(countryTag)
			if variables:GetVariable(CString("zStatsCustomList_" .. _tag)):Get() == 1 then
				P.CustomCountryList[_tag] = true
			end
		end
	end
	-- actual check
	if P.CustomCountryList[tag] == true then
		return true
	end
	return false
end


P.StatsIdent = nil
function P.GetCurrentIdent()
	if not CheckFileExists("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/identcounter") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. G_MOD_VERSION .. '\\stats"')
		WriteString("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/identcounter", "1")
	end

	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local ident = omgCountry:GetVariables():GetVariable(CString("StatisticsIdent")):Get()
	if ident == 0 then
		ident = ReadLine("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/identcounter", 1)
		Utils.LUA_DEBUGOUT(ident)
		local command = CSetVariableCommand(omgTag, CString("StatisticsIdent"), CFixedPoint(tonumber(ident)))
		CCurrentGameState.Post(command)
		WriteString("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/identcounter", tostring(ident + 1))
	end
	return ident
end

local statsSetupDone = false
local function setUpBaseStatisticsFolder()
	if P.StatsIdent == nil then
		P.StatsIdent = P.GetCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/" .. P.StatsIdent .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. G_MOD_VERSION .. '\\stats\\' .. P.StatsIdent .. '"')
		WriteString("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/" .. P.StatsIdent .. "/zzSetup", "Setup complete")
	end
	statsSetupDone = true
end

local countryStatsFoldersDone = {}
local function setUpCountryStatisticsFolder(tag)
	if P.StatsIdent == nil then
		P.StatsIdent = P.GetCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/" .. P.StatsIdent .. "/" .. tag .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. G_MOD_VERSION .. '\\stats\\' .. P.StatsIdent .. "\\" .. tag .. '"')
		WriteString("tfh/mod/BlackICE " .. G_MOD_VERSION .. "/stats/" .. P.StatsIdent .. "/" .. tag .. "/zzSetup", "Setup complete")
		countryStatsFoldersDone[tag] = true
	end
end

local function setUpStat(tag, statname)
	if P.StatsIdent == nil then
		P.StatsIdent = P.GetCurrentIdent()
	end
	if not countryStatsFoldersDone[tag] then
		setUpCountryStatisticsFolder(tag)
	end
	local filename = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\stats\\" .. P.StatsIdent .. "\\" .. tag .. "\\" .. statname
	if not CheckFileExists(filename) then
		WriteString(filename, "Date," .. statname)
	end
end

function P.AddStat(tag, statname, value)
	local date = CCurrentGameState.GetCurrentDate():GetTotalDays() - 706640
	if P.StatsIdent == nil then
		P.StatsIdent = P.GetCurrentIdent()
	end
	if not statsSetupDone then
		setUpBaseStatisticsFolder()
	end
	setUpStat(tag, statname)
	local file = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\stats\\" .. P.StatsIdent .. "\\" .. tag .. "\\" .. statname
	AppendLine(file, "\n" .. tostring(date) .. "," .. value)
end

--- COUNTRY STAT ACQUISITION FUNCTIONS ---
--- ?????????????????????????????????? ---

local ideologyList = nil
local function setUpIdeologyList()
	if ideologyList == nil then
		ideologyList = {}
		for country in CCurrentGameState.GetCountries() do
			local ideology = country:GetRulingIdeology()
			local ideologyString = tostring(ideology:GetKey())
			ideologyList[ideologyString] = ideology
		end
	end
end


function P.HandleIntelligenceMinisterStats(countryTag, country)
	setUpIdeologyList()
	local groupPopularity = {}
	local tag = tostring(countryTag)
	if ideologyList == nil then
		return
	end
	for ideologyString, ideology in pairs(ideologyList) do
		local popularity = country:AccessIdeologyPopularity():GetValue(ideology):Get()
		local group = tostring(ideology:GetGroup():GetKey())
		if groupPopularity[group] == nil then
			groupPopularity[group] = popularity
		else
			groupPopularity[group] = groupPopularity[group] + popularity
		end
		-- Utils.LUA_DEBUGOUT(tostring(popularity))
		P.AddStat(tag, "pol_Popularity_Single_" .. ideologyString, string.format('%.02f', popularity))
	end
	for group, popularity in pairs(groupPopularity) do
		P.AddStat(tag, "pol_Popularity_Group_" .. group, string.format('%.02f', popularity))
	end
end


function P.HandleProductionMinisterGeneralStats(countryTag, country, stats)
	local tag = tostring(countryTag)
	P.AddStat(tag, "other_u_LandCountTotal", tostring(string.format('%.0f', stats.LandCountTotal)))
	P.AddStat(tag, "other_u_AirCountTotal", tostring(string.format('%.0f', stats.AirCountTotal)))
	P.AddStat(tag, "other_u_NavalCountTotal", tostring(string.format('%.0f', stats.NavalCountTotal)))
	P.AddStat(tag, "other_u_TotalDivisions", tostring(string.format('%.0f', stats.TotalDivisions)))
	P.AddStat(tag, "other_ManpowerTotal", tostring(string.format('%.0f', stats.ManpowerTotal)))
end


local function getIcEfficiency(ministerCountry)
	local icEffraw = ministerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_INDUSTRIAL_EFFICIENCY_):Get()
	for tech, effect in pairs(Parsing.Techs.GetTechModifierValues()["ic_efficiency"]) do
		local level = ministerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
		icEffraw = icEffraw + (effect*level)
	end
	local icEff = Utils.RoundDecimal(icEffraw, 3) * 100
	return icEff
end


function P.HandleProductionMinisterSliderStats(countryTag, country)
	local tag = tostring(countryTag)
	local totalIc = country:GetTotalIC()
	local assignedPercent = {
		upgrade = country:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_UPGRADE_):GetPercentage():Get(),
		reinforce = country:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_REINFORCEMENT_):GetPercentage():Get(),
		supply = country:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_SUPPLY_):GetPercentage():Get(),
		production = country:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_PRODUCTION_):GetPercentage():Get(),
		consumer = country:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_CONSUMER_):GetPercentage():Get(),
		lendLease = country:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_LENDLEASE_):GetPercentage():Get()
	}

	P.AddStat(tag, "prod__IcEff", tostring(string.format('%.0f', getIcEfficiency(country))))
	P.AddStat(tag, "prod__TotalIc", tostring(string.format('%.0f', totalIc)))
	P.AddStat(tag, "prod_LendLease_%", tostring(string.format('%.0f', assignedPercent.lendLease * 100)))
	P.AddStat(tag, "prod_LendLease_IC", tostring(string.format('%.0f', assignedPercent.lendLease * totalIc)))
	P.AddStat(tag, "prod_Consumer_%", tostring(string.format('%.0f', assignedPercent.consumer * 100)))
	P.AddStat(tag, "prod_Consumer_IC", tostring(string.format('%.0f', assignedPercent.consumer * totalIc)))
	P.AddStat(tag, "prod_Production_%", tostring(string.format('%.0f', assignedPercent.production * 100)))
	P.AddStat(tag, "prod_Production_IC", tostring(string.format('%.0f', assignedPercent.production * totalIc)))
	P.AddStat(tag, "prod_Supply_%", tostring(string.format('%.0f', assignedPercent.supply * 100)))
	P.AddStat(tag, "prod_Supply_IC", tostring(string.format('%.0f', assignedPercent.supply * totalIc)))
	P.AddStat(tag, "prod_Reinforce_%", tostring(string.format('%.0f', assignedPercent.reinforce * 100)))
	P.AddStat(tag, "prod_Reinforce_IC", tostring(string.format('%.0f', assignedPercent.reinforce * totalIc)))
	P.AddStat(tag, "prod_Upgrade_%", tostring(string.format('%.0f', assignedPercent.upgrade * 100)))
	P.AddStat(tag, "prod_Upgrade_IC", tostring(string.format('%.0f', assignedPercent.upgrade * totalIc)))
end

function P.HandleTechMinisterStats(countryTag, country)
	local tag = tostring(countryTag)
	local totalLeadership = country:GetTotalLeadership():Get()
	local percent_nco = country:GetLeadershipDistributionAt(CDistributionSetting._LEADERSHIP_NCO_):GetPercentage():Get()
	local percent_diplo = country:GetLeadershipDistributionAt(CDistributionSetting._LEADERSHIP_DIPLOMACY_):GetPercentage():Get()
	local percent_spies = country:GetLeadershipDistributionAt(CDistributionSetting._LEADERSHIP_ESPIONAGE_):GetPercentage():Get()
	local percent_research = country:GetLeadershipDistributionAt(CDistributionSetting._LEADERSHIP_RESEARCH_):GetPercentage():Get()
	local freeSpies = country:GetNumberOfFreeSpies()
	local domSpy = country:GetSpyPresence(countryTag):GetLevel():Get()
	local totalSpiesAbroad  = GetTotalSpiesAbroad(country, countryTag)
	local neutrality = country:GetNeutrality():Get()
	local effective_neutrality = country:GetNeutrality():Get()

	P.AddStat(tag, "ls_TotalLeadership", tostring(string.format('%.0f', totalLeadership)))
	P.AddStat(tag, "ls_Percent_Research", tostring(string.format('%.0f', percent_research * 100)))
	P.AddStat(tag, "ls_Percent_Espionage", tostring(string.format('%.0f', percent_spies * 100)))
	P.AddStat(tag, "ls_Percent_Diplomacy", tostring(string.format('%.0f', percent_diplo * 100)))
	P.AddStat(tag, "ls_Percent_NCO", tostring(string.format('%.0f', percent_nco * 100)))
	P.AddStat(tag, "intel_FreeSpies", tostring(string.format('%.0f', freeSpies)))
	P.AddStat(tag, "intel_DomesticSpies", tostring(string.format('%.0f', domSpy)))
	P.AddStat(tag, "intel_TotalSpiesAbroad", tostring(string.format('%.0f', totalSpiesAbroad)))
	P.AddStat(tag, "diplo_Neutrality", tostring(string.format('%.0f', neutrality)))
	P.AddStat(tag, "diplo_EffectiveNeutrality", tostring(string.format('%.0f', effective_neutrality)))
end

--- Remember to add the stat here when adding a new stat collect elsewhere!
function P.CollectPlayerStatistics()
	if P.CollectStats == true then
		for i, tag in pairs(G_PlayerCountries) do
			local countryTag = CCountryDataBase.GetTag(tag)
			local country = countryTag:GetCountry()
			P.HandleTechMinisterStats(countryTag, country)
			P.HandleProductionMinisterSliderStats(countryTag, country)
			P.HandleIntelligenceMinisterStats(countryTag, country)
		end
	end
end

-- Since there are multiple LUA threads the global vars need to be initialized in each thread seperately
function P.SetUpStatCollectionLuaVars()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
    local variables = omgCountry:GetVariables()
	local statisticsToggle = variables:GetVariable(CString("StatisticsToggle")):Get()
	local statisticsCustomList = variables:GetVariable(CString("StatisticsCustomList")):Get()
    if statisticsToggle == 1 then
        Stats.CollectStats = true
		if statisticsCustomList == 1 then
			Stats.CustomCountryListActive = true
		end
    end
end

function P.UpdateCustomCountryListInStatSelection()
	local count = UI.m_listBox_Statistics_country_list:GetCount()
	Utils.LUA_DEBUGOUT("count: " .. count)
	local countries = {}
	for i = 0, count - 1 do
		local _tag = UI.m_listBox_Statistics_country_list:GetString(i)
		table.insert(countries, _tag)
		Utils.LUA_DEBUGOUT("_tag: " .. _tag)
	end
	table.sort(countries)
	UI.m_comboBox_Statistics_main1:Clear()
	UI.m_comboBox_Statistics_main1:Append(countries)
end


function P.SetUpStatCollectionPage()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
    local variables = omgCountry:GetVariables()
	local statisticsToggle = variables:GetVariable(CString("StatisticsToggle")):Get()
	local statisticsCustomList = variables:GetVariable(CString("StatisticsCustomList")):Get()
    if statisticsToggle == 1 then
        UI.m_textCtrl_Statistics_setup_ident:SetValue(tostring(Stats.GetCurrentIdent()))
        Stats.CollectStats = true
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("on")
    else
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("off")
    end
    if statisticsCustomList == 1 then
        Stats.CustomCountryListActive = true
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("on")
    else
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("off")
    end
    local countries = {}
    local customCollectionCountries = {}
    for country in CCurrentGameState.GetCountries() do
        local countryTag = country:GetCountryTag()
        local tag = tostring(countryTag)
        if tag ~= "---" then
            table.insert(countries, tag)
            if variables:GetVariable(CString("zStatsCustomList_" .. tag)):Get() == 1 then
                table.insert(customCollectionCountries, tag)
            end
        end
    end
    table.sort(countries)
    table.sort(customCollectionCountries)
    UI.m_comboBox_Statistics_main1:Clear()
    if statisticsCustomList == 1 then
        UI.m_comboBox_Statistics_main1:Append(customCollectionCountries)
    else
        UI.m_comboBox_Statistics_main1:Append(countries)
    end
    UI.m_comboBox_Statistics_setup1:Clear()
    UI.m_comboBox_Statistics_setup1:Append(countries)
    UI.m_listBox_Statistics_country_list:Clear()
    UI.m_listBox_Statistics_country_list:Append(customCollectionCountries)
end

function P.ToggleStatCollection()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local statisticsToggle = omgCountry:GetVariables():GetVariable(CString("StatisticsToggle")):Get()
    if statisticsToggle == 1 then
        local command = CSetVariableCommand(omgTag, CString("StatisticsToggle"), CFixedPoint(0))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("off")
        Stats.CollectStats = false
    else
        UI.m_textCtrl_Statistics_setup_ident:SetValue(tostring(Stats.GetCurrentIdent()))
        local command = CSetVariableCommand(omgTag, CString("StatisticsToggle"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("on")
        Stats.CollectStats = true
    end
end

function P.ToggleStatCollectionCustomList()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local statisticsCustomList = omgCountry:GetVariables():GetVariable(CString("StatisticsCustomList")):Get()
    if statisticsCustomList == 1 then
        local command = CSetVariableCommand(omgTag, CString("StatisticsCustomList"), CFixedPoint(0))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("off")
        Stats.CustomCountryListActive = false
    else
        local command = CSetVariableCommand(omgTag, CString("StatisticsCustomList"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("on")
        Stats.CustomCountryListActive = true
    end
end

return Stats
