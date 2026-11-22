-- The Active Event Modifiers page: the modifiers the player's country was given for a time (add_country_modifier),
-- each with the hour it ends at.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode; flags.lua beside this file is the commented example
-- of how a page is written (docs/openhoi/README.md).

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local state = {}

local COLUMNS = {
	{ title = "OPENHOI_WIN_NAME", field = "name" },
	{ title = "OPENHOI_WIN_EXPIRES", field = "shown" },
}

return {
	title = "OPENHOI_WIN_EVENTMODIFIERS",
	order = 40,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		player = Kit.Selected(player)
		local rows = {}
		-- In the order they were given; the same modifier given twice is two rows.
		for _, given in ipairs(OpenHOI3.CountryModifiers(player)) do
			rows[#rows + 1] = {
				name = given.name,
				-- One that never ends is kept by the game as a date in year one.
				shown = given.never and L("OPENHOI_WIN_NEVER") or given.expires,
			}
		end
		table.sort(rows, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
		return { tag = player, rows = rows }
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end
		ImGui.Text(L("OPENHOI_WIN_FLAGS_COUNTRY") .. ": " .. data.tag)
		Kit.FilteredTable("eventmodifiers", state, data.rows, COLUMNS)
	end,
}
