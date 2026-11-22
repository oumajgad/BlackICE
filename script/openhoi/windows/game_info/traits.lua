-- The Traits page: every leader trait the mod defines, with what it does and how it is gained.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Traits (script/utility_imgui/GameInfo), which
-- reads common/traits.txt and common/gainable_traits.txt. This file only draws it.
--
-- The page shows a list on the left and the chosen trait on the right. Choosing is done while drawing, reading is
-- done in Collect, so a click notes the choice and asks OpenHOI3 to gather again at once (OpenHOI3.Refresh).

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local list = {}

return {
	title = "OPENHOI_WIN_TRAITS",
	order = 50,
	group = "OPENHOI_WIN_GROUP_GAME",
	group_order = 30,

	Collect = function(player)
		local source = Kit.Data("Traits")
		if source == nil then
			return { missing = true }
		end
		local chosen = list.selected
		return {
			list = source.Collect(),
			chosen = chosen,
			details = chosen and source.Details(chosen) or nil,
		}
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end
		if data.missing then
			ImGui.TextDisabled(L("OPENHOI_WIN_NO_DATA"))
			return
		end
		if not Kit.Available(data.list) then
			return
		end
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_TRAITS_COUNT", { N = #data.list.traits }))

		Kit.BeginPanes("trait_panes", 280)
		if Kit.FilteredList("traits", list, data.list.traits, 0, 0) then
			OpenHOI3.Refresh()
		end
		Kit.NextPane()
		if ImGui.BeginChild("trait", 0, 0) then
			if list.selected == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_TRAITS_SELECT"))
			elseif data.chosen ~= list.selected then
				ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			elseif Kit.Available(data.details) then
				ImGui.Text(data.details.key)
				ImGui.Separator()
				local _, height = ImGui.GetContentRegionAvail()
				local half = math.max(60, (height - 2 * Kit.LINE) / 2)
				ImGui.Text(L("OPENHOI_WIN_EFFECTS"))
				Kit.TextBox("effects", data.details.effects, half)
				ImGui.Text(L("OPENHOI_WIN_TRIGGERS"))
				Kit.TextBox("triggers", data.details.triggers, -1)
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
