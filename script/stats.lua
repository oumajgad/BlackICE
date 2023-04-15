G_StatsIdent = nil
function GetCurrentIdent()
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
function SetUpStatisticsFolders()
	if G_StatsIdent == nil then
		G_StatsIdent = GetCurrentIdent()
	end
	if not CheckFileExists("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. G_StatsIdent .. "/zzSetup") then
		os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. G_StatsIdent .. '"')
		WriteString("tfh/mod/BlackICE " .. UI.version .. "/stats/" .. G_StatsIdent .. "/zzSetup", "Setup complete")
		for tag, countryTag in pairs(CountryIterCacheDict) do
			if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
				-- os.execute('mkdir "tfh\\mod\\BlackICE ' .. UI.version .. '\\stats\\' .. G_StatsIdent .. '\\' .. tag .. '"')
				WriteString("tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_BaseIC", "Date,BaseIC")
				WriteString("tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_EffectiveIC", "Date,EffectiveIC")
				WriteString("tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_ICEfficiency", "Date,ICEfficiency")
				WriteString("tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_ResEfficiency", "Date,ResEfficiency")
				WriteString("tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_LsSlidersPercentage", "Date,Research,Spies,Diplo,Officers")
				WriteString("tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_LsSlidersFlat", "Date,Research,Spies,Diplo,Officers")
			end
		end
	end
	statsSetupDone = true
end

function AddStat(tag, statname, value)
	if not statsSetupDone then
		SetUpStatisticsFolders()
	end
	local date = CCurrentGameState.GetCurrentDate():GetTotalDays() - 706640
	if G_StatsIdent == nil then
		G_StatsIdent = GetCurrentIdent()
	end
	local file = "tfh\\mod\\BlackICE " .. UI.version .. "\\stats\\" .. G_StatsIdent .. "\\" .. tag .. "_" .. statname
	AppendLine(file, "\n" .. tostring(date) .. "," .. value)
end

function CollectStatistics()
	if G_StatsIdent == nil then
		G_StatsIdent = GetCurrentIdent()
	end
	SetUpStatisticsFolders()
	for tag, countryTag in pairs(CountryIterCacheDict) do
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			local country = countryTag:GetCountry()
			local variables = country:GetVariables()

			local BaseIC = country:GetMaxIC()
			local EffectiveIC = country:GetTotalIC()
			local ICEfficiency = variables:GetVariable(CString("IcEffVariable")):Get()
			local ResEfficiency = variables:GetVariable(CString("ResEffVariable")):Get()

			AddStat(tag, "BaseIC", tostring(BaseIC))
			AddStat(tag, "EffectiveIC", tostring(EffectiveIC))
			AddStat(tag, "ICEfficiency", tostring(ICEfficiency))
			AddStat(tag, "ResEfficiency", tostring(ResEfficiency))
		end
	end
end
