-- The Statistics page: reads the files the mod's collection has written for this game's run and draws chosen
-- series, a line each.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). BiceLibGui.Stats, the
-- mod's own data shared with the overlay on the original engine, says which run this game is and where its
-- files are; the files themselves are read here: <path>/<run>/<TAG>/<statistic>, a header line and then a line
-- "<day>,<value>" for each day collected, day 0 being 1 January 1936.
--
-- Reading files asks no game, but it is slow work for a frame: the folders are looked through and the series
-- read in Collect, when a button asked for it.
--
-- Not carried over from the overlay: every series drawn into one plot, the dates under the mouse, and the
-- button that starts the mod's external plotting tool. A line here goes from reading to reading at even steps:
-- days on which nothing was collected take no room on it. The dates under a plot are its first and last day.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- What the run's folder holds, as last looked through: the countries with a folder and every statistic's name.
local found = nil
-- What is to be done at the next Collect: look through the folders, read the ticked series.
local rescan = true
local plot = false
-- The countries and statistics ticked, the filter over the statistics, and the series read.
local countries, statistics = {}, {}
local filter = {}
local series = nil

local COLOURS = {
	{ 0.47, 0.75, 1.00, 1 }, { 1.00, 0.67, 0.35, 1 }, { 0.51, 0.86, 0.55, 1 }, { 0.94, 0.51, 0.78, 1 },
	{ 0.90, 0.86, 0.47, 1 }, { 0.71, 0.59, 1.00, 1 }, { 0.47, 0.90, 0.86, 1 }, { 1.00, 0.51, 0.51, 1 },
}

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- A day's date: years of 365 days with no leap day, day 0 being 1 January 1936.
local function date(day)
	local year = 1936 + math.floor(day / 365)
	local left = day - math.floor(day / 365) * 365
	for month = 1, 12 do
		if left < DAYS[month] then
			return string.format("%d %s %d", left + 1, MONTHS[month], year)
		end
		left = left - DAYS[month]
	end
	return tostring(day)
end

local function sortedKeys(set)
	local list = {}
	for key in pairs(set) do
		list[#list + 1] = key
	end
	table.sort(list, function(a, b) return string.lower(a) < string.lower(b) end)
	return list
end

-- The run's folder looked through: a country is one whose folder is there, a statistic a file in any of them.
local function scan(answer)
	found = { countries = {}, statistics = {}, folder = nil }
	if (answer.ident or 0) <= 0 then
		return
	end
	found.folder = tostring(answer.path) .. "/" .. string.format("%d", answer.ident)
	local names = {}
	for _, tag in ipairs(answer.countries or {}) do
		local folder = found.folder .. "/" .. tag
		-- OpenHOI3 keeps a folder's listing once asked for: forgotten here, so that new files are seen.
		rawset(OpenHOI3.Files, folder, nil)
		local files = OpenHOI3.Files[folder]
		if files ~= nil then
			found.countries[#found.countries + 1] = tag
			for _, name in ipairs(files) do
				if name ~= "zzSetup" then
					names[name] = true
				end
			end
		end
	end
	found.statistics = sortedKeys(names)
end

-- One file read: its points in the order of their days. The files are only ever added to, so a game loaded from
-- an earlier save, or a day written twice, leaves older readings behind the newer: those are dropped.
local function read(country, statistic)
	local file = io.open(found.folder .. "/" .. country .. "/" .. statistic, "r")
	if file == nil then
		return nil
	end
	local days, values, dropped = {}, {}, 0
	local first = true
	for line in file:lines() do
		if first then
			first = false
		else
			local day, value = string.match(line, "^%s*(-?%d+)%s*,%s*(-?[%d%.eE+-]+)")
			day, value = tonumber(day), tonumber(value)
			if day ~= nil and value ~= nil then
				while #days > 0 and days[#days] >= day do
					days[#days], values[#values] = nil, nil
					dropped = dropped + 1
				end
				days[#days + 1], values[#values + 1] = day, value
			end
		end
	end
	file:close()
	if #days == 0 then
		return nil
	end
	local least, most = values[1], values[1]
	for _, value in ipairs(values) do
		least, most = math.min(least, value), math.max(most, value)
	end
	return { country = country, statistic = statistic, days = days, values = values, dropped = dropped, least = least, most = most }
end

local function count(set)
	local n = 0
	for _, on in pairs(set) do
		if on then
			n = n + 1
		end
	end
	return n
end

return {
	title = "OPENHOI_WIN_STATISTICS",
	order = 20,
	group = "OPENHOI_WIN_GROUP_STATS",
	group_order = 50,

	Collect = function(player)
		return Kit.Gather("Stats", function(source)
			local answer = source.Collect()
			if answer.available ~= false then
				if rescan then
					rescan = false
					scan(answer)
				end
				if plot and found ~= nil and found.folder ~= nil then
					plot = false
					series = {}
					for _, country in ipairs(found.countries) do
						for _, statistic in ipairs(found.statistics) do
							if countries[country] and statistics[statistic] then
								series[#series + 1] = read(country, statistic)
							end
						end
					end
				end
			end
			return { answer = answer }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		if ImGui.Button(L("OPENHOI_WIN_STATS_RESCAN")) then
			rescan = true
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		if found == nil then
			ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			return
		elseif found.folder == nil then
			ImGui.TextDisabled(L("OPENHOI_WIN_STATS_NOTHING"))
		elseif #found.countries == 0 then
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_STATS_NO_DATA", { FOLDER = found.folder }))
		else
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_STATS_FOUND", { N = #found.countries, M = #found.statistics }))
		end
		if #found.countries == 0 then
			ImGui.TextWrapped(L("OPENHOI_WIN_STATS_HELP"))
			return
		end

		-- Ticking anything takes the plots away: they are of what was ticked before.
		local function tick(set, name, label)
			local changed, ticked = ImGui.Checkbox(label, set[name] and true or false)
			if changed then
				set[name] = ticked
				series = nil
			end
		end

		if ImGui.BeginChild("countries", 190, 220) then
			ImGui.Text(L("OPENHOI_WIN_STATS_COUNTRIES"))
			for _, country in ipairs(found.countries) do
				tick(countries, country, country .. "##country")
			end
		end
		ImGui.EndChild()
		ImGui.SameLine()
		if ImGui.BeginChild("statistics", 340, 220) then
			ImGui.Text(L("OPENHOI_WIN_STATS_STATISTICS"))
			Kit.FilterBox(filter, -50)
			for _, statistic in ipairs(found.statistics) do
				-- By the letters as they stand, capitals and all: the names differ by them.
				if filter.filter == "" or string.find(statistic, filter.filter, 1, true) then
					tick(statistics, statistic, statistic .. "##statistic")
				end
			end
		end
		ImGui.EndChild()
		ImGui.SameLine()
		if ImGui.BeginChild("actions", 200, 220) then
			local chosenCountries, chosenStatistics = count(countries), count(statistics)
			ImGui.Text(Kit.Filled("OPENHOI_WIN_STATS_N_COUNTRIES", { N = chosenCountries }))
			ImGui.Text(Kit.Filled("OPENHOI_WIN_STATS_N_STATISTICS", { N = chosenStatistics }))
			ImGui.BeginDisabled(chosenCountries == 0 or chosenStatistics == 0)
			if ImGui.Button(L("OPENHOI_WIN_STATS_PLOT")) then
				plot = true
				OpenHOI3.Refresh()
			end
			ImGui.EndDisabled()
			if ImGui.Button(L("OPENHOI_WIN_STATS_CLEAR")) then
				countries, statistics, series = {}, {}, nil
			end
		end
		ImGui.EndChild()

		if series == nil then
			return
		end
		ImGui.SeparatorText(L("OPENHOI_WIN_STATS_PLOTS"))
		if #series == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_STATS_NO_POINTS"))
		end
		for index, one in ipairs(series) do
			Kit.Coloured(COLOURS[(index - 1) % #COLOURS + 1], "--")
			ImGui.SameLine()
			ImGui.Text(one.country .. " - " .. one.statistic)
			ImGui.SameLine()
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_STATS_POINTS", { N = #one.values }))
			if one.dropped > 0 then
				ImGui.SameLine()
				ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_STATS_DROPPED", { N = one.dropped }))
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip(L("OPENHOI_WIN_STATS_DROPPED_TIP"))
				end
			end
			if #one.values < 2 then
				ImGui.TextDisabled(L("OPENHOI_WIN_STATS_TOO_FEW"))
			else
				ImGui.PlotLines("##plot" .. index, one.values, 0, 90)
				ImGui.TextDisabled(string.format("%.2f %s %.2f, %s %s %s", one.least, L("OPENHOI_WIN_STATS_TO"), one.most,
					date(one.days[1]), L("OPENHOI_WIN_STATS_TO"), date(one.days[#one.days])))
			end
		end
	end,
}
