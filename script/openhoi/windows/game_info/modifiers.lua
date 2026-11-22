-- The Modifiers page: every event modifier and triggered modifier the mod defines, with its effects and the
-- conditions it stands under.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); traits.lua beside this
-- file explains the shape. The data is the mod's own, shared with the overlay on the original engine:
-- BiceLibGui.Modifiers, which reads common/event_modifiers.txt and common/triggered_modifiers.txt.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local list = {}

return {
	title = "OPENHOI_WIN_MODIFIERS",
	order = 70,
	group = "OPENHOI_WIN_GROUP_GAME",
	group_order = 30,

	Collect = function(player)
		local source = Kit.Data("Modifiers")
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
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_MODIFIERS_COUNT", { N = #data.list.modifiers }))

		Kit.BeginPanes("modifier_panes", 320)
		if Kit.FilteredList("modifiers", list, data.list.modifiers, 0, 0) then
			OpenHOI3.Refresh()
		end
		Kit.NextPane()
		if ImGui.BeginChild("modifier", 0, 0) then
			if list.selected == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_MODIFIERS_SELECT"))
			elseif data.chosen ~= list.selected then
				ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			elseif Kit.Available(data.details) then
				ImGui.Text(data.details.key)
				ImGui.SameLine()
				-- "Event" or "Triggered", by the file it stands in.
				ImGui.TextDisabled("(" .. L("OPENHOI_WIN_MODIFIERS_KIND_" .. string.upper(tostring(data.details.kind))) .. ")")
				ImGui.Separator()
				local _, height = ImGui.GetContentRegionAvail()
				local half = math.max(60, (height - 2 * Kit.LINE) / 2)
				ImGui.Text(L("OPENHOI_WIN_EFFECTS"))
				Kit.TextBox("effects", data.details.effects, half)
				ImGui.Text(L("OPENHOI_WIN_CONDITIONS"))
				Kit.TextBox("conditions", data.details.triggers, -1)
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
