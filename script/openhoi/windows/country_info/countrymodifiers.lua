-- The Country Modifiers page: the player's country's figures that the game shows nowhere in one place - industry,
-- research and supply, military, war exhaustion - each a section of labels and values.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.CountryInfo, which answers the sections and
-- their rows ready to draw. This file only draws them.

local ImGui = OpenHOI3.ImGui
local Kit = require('openhoi/pagekit')

return {
	title = "OPENHOI_WIN_COUNTRYMODIFIERS",
	order = 20,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		player = Kit.Selected(player)
		return Kit.Gather("CountryInfo", function(source)
			return { tag = player, answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		ImGui.TextDisabled(data.tag)
		for index, section in ipairs(data.answer.sections or {}) do
			ImGui.SeparatorText(tostring(section.name))
			local rows = {}
			for _, row in ipairs(section.rows or {}) do
				rows[#rows + 1] = { row.label, row.value }
			end
			Kit.LabelTable("section" .. index, rows)
		end
	end,
}
