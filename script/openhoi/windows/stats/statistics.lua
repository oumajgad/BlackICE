-- The Statistics page: draws chosen series of the game's statistics record, a line each.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The record is the
-- engine's own (OpenHOI3.Statistics): every country's figures, a value a day, kept in the game and its save where
-- the lobby's rule "Collect statistics" is on. Nothing of the mod's collects on OpenHOI3 - the files the mod's
-- Lua writes day by day on the original engine are not written here - and there is no Setup page: the rule is
-- the lobby's, and every country is kept.
--
-- The record is the game's, so it is asked in Collect: what there is when the page opens or Rescan is pressed,
-- and the ticked series when Plot is.
--
-- Every plot has its axes - the date across, the statistic up, "mixed" where one frame holds several - and
-- says under the mouse the day's date and each line's value on it. Export writes the whole record out as the
-- files the mod's plotting tool reads.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- What the record holds, as last asked: the countries kept and every series' name.
local found = nil
-- What is to be done at the next Collect: ask what there is, read the ticked series, write the files.
local rescan = true
local plot = false
local export = false
-- What became of the last export: the folder and how many files, or why not.
local exported = nil
-- The countries and statistics ticked, the filter over the statistics, and the series read.
local countries, statistics = {}, {}
local filter = {}
-- The filter over the countries: it only hides rows, a country ticked stays ticked while it is out of sight.
local countryFilter = {}
local series = nil
-- Whether every series is drawn into one frame, in place of a frame each.
local onePlot = false

local COLOURS = {
	{ 0.47, 0.75, 1.00, 1 }, { 1.00, 0.67, 0.35, 1 }, { 0.51, 0.86, 0.55, 1 }, { 0.94, 0.51, 0.78, 1 },
	{ 0.90, 0.86, 0.47, 1 }, { 0.71, 0.59, 1.00, 1 }, { 0.47, 0.90, 0.86, 1 }, { 1.00, 0.51, 0.51, 1 },
}

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- A day's date by its number, as the game counts its days.
local function date(number)
	local year, month, day = OpenHOI3.DateOf(number)
	return string.format("%d %s %d", day or 0, MONTHS[month or 1] or "?", year or 0)
end

-- One series of the record: its values, their least and most, and the days it runs from and to.
local function read(country, statistic)
	local kept = OpenHOI3.Statistics.Series(country, statistic)
	if kept == nil or #kept.values == 0 then
		return nil
	end
	local least, most = kept.values[1], kept.values[1]
	for _, value in ipairs(kept.values) do
		least, most = math.min(least, value), math.max(most, value)
	end
	return { country = country, statistic = statistic, values = kept.values, least = least, most = most,
		first = kept.first_day, from = date(kept.first_day), to = date(kept.first_day + #kept.values - 1) }
end

-- A value as it is said: whole where it is whole, else to two places.
local function said(value)
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return string.format("%.2f", value)
end

-- One frame of the given lines, { one = <a series read>, colour = }, with its axes; and under the mouse the
-- day's date and every line's value on that day. A line that has no such day is left out.
local function frame(id, lines, height)
	local drawn = {}
	local first, last, statistic = nil, nil, nil
	for index, line in ipairs(lines) do
		local one = line.one
		drawn[index] = { first = one.first, colour = line.colour, values = one.values }
		local ends = one.first + #one.values - 1
		first = (first == nil or one.first < first) and one.first or first
		last = (last == nil or ends > last) and ends or last
		if statistic == nil then
			statistic = one.statistic
		elseif statistic ~= one.statistic then
			statistic = L("OPENHOI_WIN_STATS_AXIS_MIXED")
		end
	end
	local day = ImGui.PlotMany(id, drawn, height, { x = L("OPENHOI_WIN_STATS_AXIS_DATE"), y = statistic or "",
		from = first and date(first) or "", to = last and date(last) or "" })
	if day == nil then
		return
	end
	ImGui.BeginTooltip()
	ImGui.Text(date(day))
	ImGui.Separator()
	for _, line in ipairs(lines) do
		local one = line.one
		local value = one.values[day - one.first + 1]
		if value ~= nil then
			Kit.Coloured(line.colour, "--")
			ImGui.SameLine()
			ImGui.Text(one.country .. " - " .. one.statistic .. ": " .. said(value))
		end
	end
	ImGui.EndTooltip()
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
		-- Asked again by itself for as long as there is nothing: the first day has yet to be kept.
		if rescan or found == nil or #found.countries == 0 then
			rescan = false
			found = { collecting = OpenHOI3.Statistics.Collecting(), countries = OpenHOI3.Statistics.Countries(),
				statistics = OpenHOI3.Statistics.Names() }
			table.sort(found.statistics, function(a, b) return string.lower(a) < string.lower(b) end)
		end
		if plot and found ~= nil then
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
		if export then
			export = false
			local folder, files = OpenHOI3.Statistics.Export()
			exported = { folder = folder, files = files }
		end
		return {}
	end,

	Draw = function(data, player)
		if ImGui.Button(L("OPENHOI_WIN_STATS_RESCAN")) then
			rescan = true
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		if found == nil then
			ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			return
		elseif #found.countries == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_STATS_NOTHING"))
		else
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_STATS_FOUND", { N = #found.countries, M = #found.statistics }))
		end
		if not found.collecting then
			Kit.Coloured(Kit.WARNING, L("OPENHOI_WIN_STATS_OFF"))
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
			Kit.FilterBox(countryFilter, -50)
			local wanted = string.upper(countryFilter.filter or "")
			for _, country in ipairs(found.countries) do
				-- Whatever the case typed: a tag is capitals.
				if wanted == "" or string.find(string.upper(country), wanted, 1, true) then
					tick(countries, country, country .. "##country")
				end
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
		if ImGui.BeginChild("actions", 220, 220) then
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
			ImGui.Spacing()
			if ImGui.Button(L("OPENHOI_WIN_STATS_EXPORT")) then
				export = true
				exported = nil
				OpenHOI3.Refresh()
			end
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(L("OPENHOI_WIN_STATS_EXPORT_TIP"))
			end
			if exported ~= nil then
				if exported.folder ~= nil then
					ImGui.TextWrapped(Kit.Filled("OPENHOI_WIN_STATS_EXPORTED", { N = exported.files, FOLDER = exported.folder }))
				else
					Kit.Coloured(Kit.ERROR, tostring(exported.files))
				end
			end
		end
		ImGui.EndChild()

		if series == nil then
			return
		end
		ImGui.SeparatorText(L("OPENHOI_WIN_STATS_PLOTS"))
		local changed, ticked = ImGui.Checkbox(L("OPENHOI_WIN_STATS_ONE_PLOT"), onePlot)
		if changed then
			onePlot = ticked
		end
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_STATS_ONE_PLOT_TIP"))
		end
		if #series == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_STATS_NO_POINTS"))
		end
		if onePlot and #series > 0 then
			-- Every series in one frame, each in its colour and standing at its own days, and a line of the legend each.
			local lines = {}
			for index, one in ipairs(series) do
				lines[index] = { one = one, colour = COLOURS[(index - 1) % #COLOURS + 1] }
			end
			frame("##oneplot", lines, 260)
			for index, one in ipairs(series) do
				Kit.Coloured(COLOURS[(index - 1) % #COLOURS + 1], "--")
				ImGui.SameLine()
				ImGui.Text(one.country .. " - " .. one.statistic)
				ImGui.SameLine()
				ImGui.TextDisabled(string.format("(%.2f %s %.2f, %s %s %s)", one.least, L("OPENHOI_WIN_STATS_TO"), one.most,
					one.from, L("OPENHOI_WIN_STATS_TO"), one.to))
			end
			return
		end
		for index, one in ipairs(series) do
			Kit.Coloured(COLOURS[(index - 1) % #COLOURS + 1], "--")
			ImGui.SameLine()
			ImGui.Text(one.country .. " - " .. one.statistic)
			ImGui.SameLine()
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_STATS_POINTS", { N = #one.values }))
			if #one.values < 2 then
				ImGui.TextDisabled(L("OPENHOI_WIN_STATS_TOO_FEW"))
			else
				frame("##plot" .. index, { { one = one, colour = COLOURS[(index - 1) % #COLOURS + 1] } }, 90)
			end
		end
	end,
}
