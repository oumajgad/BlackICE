-- The Active Variables page: every variable of the player's country that is not nought, with its value.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode; flags.lua beside this file is the commented example
-- of how a page is written (docs/openhoi/README.md).

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local state = {}

local COLUMNS = {
	{ title = "OPENHOI_WIN_NAME", field = "name" },
	{ title = "OPENHOI_WIN_VALUE", field = "shown" },
}

return {
	title = "OPENHOI_WIN_VARIABLES",
	order = 30,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		local rows = {}
		-- Sorted by name by the engine. A variable at nought is left out, as a save leaves it out.
		for _, variable in ipairs(OpenHOI3.CountryVariables(player)) do
			if variable.value ~= 0 then
				-- Whole where it is whole, else to three places.
				local shown = string.format("%.3f", variable.value)
				shown = string.gsub(string.gsub(shown, "0+$", ""), "%.$", "")
				rows[#rows + 1] = { name = variable.name, shown = shown }
			end
		end
		return { tag = player, rows = rows }
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end
		ImGui.Text(L("OPENHOI_WIN_FLAGS_COUNTRY") .. ": " .. data.tag)
		Kit.FilteredTable("variables", state, data.rows, COLUMNS)
	end,
}
