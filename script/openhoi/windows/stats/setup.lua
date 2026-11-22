-- The Stats tab's Setup page: switches the mod's collection of statistics on and off and edits the list of
-- countries it covers. The page collects nothing itself.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Stats, over variables of the country OMG -
-- StatisticsToggle, StatisticsCustomList, zStatsCustomList_<TAG> - each set by the game's own command.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The list of every country, whose chosen tag the two buttons act on.
local all = {}

-- Whether a tag is on the list, as last asked for and not yet answered by the game: wanted[tag] = true or false.
local wanted = {}

-- One of the two switches: a checkbox that shows what was asked for until the game answers the same.
local function switch(name, label, value, set)
	local shown, waiting = Kit.Shown(name, value and true or false)
	local changed, ticked = ImGui.Checkbox(L(label), shown)
	if changed then
		Kit.Pend(name, ticked)
		Kit.Ask(function() set(ticked and 1 or 0) end)
	end
	if waiting then
		ImGui.SameLine()
		Kit.PendingText(L("OPENHOI_WIN_MISC_WAITING"), true)
	end
end

return {
	title = "OPENHOI_WIN_STATS_SETUP",
	order = 10,
	group = "OPENHOI_WIN_GROUP_STATS",
	group_order = 50,

	Collect = function(player)
		return Kit.Gather("Stats", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		local source = Kit.Data("Stats")

		switch("stats_collecting", "OPENHOI_WIN_STATS_COLLECT", answer.collecting, source.SetCollecting)
		ImGui.SameLine()
		if (answer.ident or 0) > 0 then
			ImGui.Text(Kit.Filled("OPENHOI_WIN_STATS_RUN", { N = string.format("%d", answer.ident) }))
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(L("OPENHOI_WIN_STATS_RUN_TIP"))
			end
		else
			ImGui.TextDisabled(L("OPENHOI_WIN_STATS_NO_RUN"))
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(L("OPENHOI_WIN_STATS_NO_RUN_TIP"))
			end
		end
		switch("stats_custom", "OPENHOI_WIN_STATS_ONLY_LISTED", answer.customListActive, source.SetCustomListActive)
		ImGui.TextWrapped(L("OPENHOI_WIN_STATS_SETUP_HELP"))

		ImGui.SeparatorText(L("OPENHOI_WIN_STATS_COLLECTED"))
		if not answer.customListActive then
			ImGui.TextDisabled(L("OPENHOI_WIN_STATS_LIST_OFF"))
		end

		-- The list as the game has it, with what was asked for and not yet answered laid over it.
		local actual = {}
		for _, tag in ipairs(answer.custom or {}) do
			actual[tag] = true
		end
		for tag, on in pairs(wanted) do
			if (actual[tag] == true) == on then
				wanted[tag] = nil
			end
		end
		local function listed(tag)
			if wanted[tag] ~= nil then
				return wanted[tag]
			end
			return actual[tag] == true
		end
		local collected = {}
		for _, tag in ipairs(answer.countries or {}) do
			if listed(tag) then
				collected[#collected + 1] = tag
			end
		end
		local function set(tag, on)
			wanted[tag] = on
			Kit.Ask(function() source.SetCountryCollected(tag, on and 1 or 0) end)
		end

		if ImGui.BeginChild("all", 220, 260) then
			ImGui.Text(L("OPENHOI_WIN_STATS_ALL"))
			Kit.FilteredList("countries", all, answer.countries or {}, 0, 0)
		end
		ImGui.EndChild()
		ImGui.SameLine()
		if ImGui.BeginChild("buttons", 120, 260) then
			local tag = all.selected
			ImGui.NewLine()
			ImGui.NewLine()
			ImGui.BeginDisabled(tag == nil or listed(tag))
			if ImGui.Button(L("OPENHOI_WIN_STATS_ADD")) and tag ~= nil then
				set(tag, true)
			end
			ImGui.EndDisabled()
			ImGui.BeginDisabled(tag == nil or not listed(tag))
			if ImGui.Button(L("OPENHOI_WIN_STATS_REMOVE")) and tag ~= nil then
				set(tag, false)
			end
			ImGui.EndDisabled()
		end
		ImGui.EndChild()
		ImGui.SameLine()
		if ImGui.BeginChild("collected", 220, 260) then
			ImGui.Text(Kit.Filled("OPENHOI_WIN_STATS_COLLECTED_N", { N = #collected }))
			for _, tag in ipairs(collected) do
				-- One on its way is marked; a click makes it the tag the buttons act on.
				local label = tag .. (wanted[tag] ~= nil and " ..." or "")
				if ImGui.Selectable(label .. "##collected" .. tag, all.selected == tag) then
					all.selected = tag
				end
			end
		end
		ImGui.EndChild()
	end,
}
