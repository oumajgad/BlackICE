-- The Techs page: every technology the mod defines, with what it gives at a level of the player's choosing and
-- what researching it asks.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); traits.lua beside this
-- file explains the shape. The data is the mod's own, shared with the overlay on the original engine:
-- BiceLibGui.Techs, which reads the technologies folder and asks the game for the level researched.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local list = {}

-- The level whose effects are shown; 0 leaves it to the data: the level researched, or 1 where there is none.
local level = 0

local function show(wanted)
	level = wanted
	OpenHOI3.Refresh()
end

return {
	title = "OPENHOI_WIN_TECHS",
	order = 80,
	group = "OPENHOI_WIN_GROUP_GAME",
	group_order = 30,

	Collect = function(player)
		local source = Kit.Data("Techs")
		if source == nil then
			return { missing = true }
		end
		local chosen = list.selected
		return {
			list = source.Collect(),
			chosen = chosen,
			level = level,
			details = chosen and source.Details(chosen, level) or nil,
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
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_TECHS_COUNT", { N = #data.list.techs }))

		Kit.BeginPanes("tech_panes", 320)
		if Kit.FilteredList("techs", list, data.list.techs, 0, 0) then
			-- A technology newly chosen is shown at the level researched.
			show(0)
		end
		Kit.NextPane()
		if ImGui.BeginChild("tech", 0, 0) then
			if list.selected == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_TECHS_SELECT"))
			elseif data.chosen ~= list.selected or data.level ~= level then
				ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			elseif Kit.Available(data.details) then
				local details = data.details
				ImGui.Text(details.key)

				ImGui.Text(Kit.Filled("OPENHOI_WIN_TECHS_LEVEL", { LEVEL = details.shown_level }))
				ImGui.SameLine()
				if ImGui.SmallButton("-") and details.shown_level > 1 then
					show(details.shown_level - 1)
				end
				ImGui.SameLine()
				if ImGui.SmallButton("+") then
					show(details.shown_level + 1)
				end
				ImGui.SameLine()
				if details.player_level > 0 then
					ImGui.TextDisabled("| " .. Kit.Filled("OPENHOI_WIN_TECHS_RESEARCHED", { LEVEL = details.player_level }))
					ImGui.SameLine()
					if ImGui.SmallButton(L("OPENHOI_WIN_RESET")) and details.shown_level ~= details.player_level then
						show(details.player_level)
					end
				else
					ImGui.TextDisabled("| " .. L("OPENHOI_WIN_TECHS_NOT_RESEARCHED"))
				end

				ImGui.Separator()
				local _, height = ImGui.GetContentRegionAvail()
				ImGui.Text(L("OPENHOI_WIN_TECHS_EFFECTS"))
				Kit.TextBox("effects", details.effects, math.max(60, (height - 2 * Kit.LINE) * 0.55))
				ImGui.Text(L("OPENHOI_WIN_TECHS_REQUIREMENTS"))
				Kit.TextBox("requirements", details.requirements, -1)
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
