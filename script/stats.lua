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
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/identcounter") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/identcounter", "1")
	end

	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local ident = omgCountry:GetVariables():GetVariable(CString("StatisticsIdent")):Get()
	if ident == 0 then
		ident = ReadLine("tfh/mod/BlackICE " .. UI.version .. "/stats/identcounter", 1)
		Utils.LUA_DEBUGOUT(ident)
		local command = CSetVariableCommand(omgTag, CString("StatisticsIdent"), CFixedPoint(tonumber(ident)))
		CCurrentGameState.Post(command)
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/identcounter", tostring(ident + 1))
	end
	return ident
end

local statsSetupDone = false
local function setUpBaseStatisticsFolder()
	if P.StatsIdent == nil then
		P.StatsIdent = P.GetCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. P.StatsIdent .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. P.StatsIdent .. '"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. P.StatsIdent .. "/zzSetup", "Setup complete")
	end
	statsSetupDone = true
end

local countryStatsFoldersDone = {}
local function setUpCountryStatisticsFolder(tag)
	if P.StatsIdent == nil then
		P.StatsIdent = P.GetCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. P.StatsIdent .. "/" .. tag .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. P.StatsIdent .. "\\" .. tag .. '"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. P.StatsIdent .. "/" .. tag .. "/zzSetup", "Setup complete")
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
	local filename = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. P.StatsIdent .. "\\" .. tag .. "\\" .. statname
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
	local file = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. P.StatsIdent .. "\\" .. tag .. "\\" .. statname
	AppendLine(file, "\n" .. tostring(date) .. "," .. value)
end

return Stats