local P = {}
Stats = P

P.CollectStats = false
P.MajorOnly = true	-- Only collect stats from majors


-- Checks if country is a major incase we only want to collect from majors
-- Takes either of the 3 arguments. Only send the one that is most readily available and set the others to nil
function P.MajorCheck(isMajor, ministerCountry, countryTag)
	if P.MajorOnly ~= true then
		return true
	end

	if isMajor ~= nil then
		return isMajor
	end
	if ministerCountry ~= nil then
		return ministerCountry:IsMajor()
	end
	if countryTag ~= nil then
		return countryTag:GetCountry():IsMajor()
	end
	return false
end


local statsIdent = nil
local function getCurrentIdent()
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
	if statsIdent == nil then
		statsIdent = getCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. statsIdent .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. statsIdent .. '"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. statsIdent .. "/zzSetup", "Setup complete")
	end
	statsSetupDone = true
end

local countryStatsFoldersDone = {}
local function setUpCountryStatisticsFolder(tag)
	if statsIdent == nil then
		statsIdent = getCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. statsIdent .. "/" .. tag .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. statsIdent .. "\\" .. tag .. '"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. statsIdent .. "/" .. tag .. "/zzSetup", "Setup complete")
		countryStatsFoldersDone[tag] = true
	end
end

local function setUpStat(tag, statname)
	if statsIdent == nil then
		statsIdent = getCurrentIdent()
	end
	if not countryStatsFoldersDone[tag] then
		setUpCountryStatisticsFolder(tag)
	end
	local filename = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. statsIdent .. "\\" .. tag .. "\\" .. statname
	if not CheckFileExists(filename) then
		WriteString(filename, "Date," .. statname)
	end
end

function P.AddStat(tag, statname, value)
	local date = CCurrentGameState.GetCurrentDate():GetTotalDays() - 706640
	if statsIdent == nil then
		statsIdent = getCurrentIdent()
	end
	if not statsSetupDone then
		setUpBaseStatisticsFolder()
	end
	setUpStat(tag, statname)
	local file = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. statsIdent .. "\\" .. tag .. "\\" .. statname
	AppendLine(file, "\n" .. tostring(date) .. "," .. value)
end
