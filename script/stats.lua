local P = {}
Stats = P

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
local function setUpStatisticsFolder()
	if statsIdent == nil then
		statsIdent = getCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. statsIdent .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. statsIdent .. '"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. statsIdent .. "/zzSetup", "Setup complete")
	end
	statsSetupDone = true
end

local function setUpStat(tag, statname)
	if statsIdent == nil then
		statsIdent = getCurrentIdent()
	end
	local filename = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. statsIdent .. "\\" .. tag .. "_" .. statname
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
		setUpStatisticsFolder()
	end
	setUpStat(tag, statname)
	local file = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. statsIdent .. "\\" .. tag .. "_" .. statname
	AppendLine(file, "\n" .. tostring(date) .. "," .. value)
end
