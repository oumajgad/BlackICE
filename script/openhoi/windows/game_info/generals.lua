-- The Generals page: every leader the mod defines for the player's country, in service or not, with his
-- definition and his traits.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); traits.lua beside this
-- file explains the shape. The data is the mod's own, shared with the overlay on the original engine:
-- BiceLibGui.Generals, which reads history/leaders, and BiceLibGui.Traits for a trait's effects.
--
-- Where the running game has a leader - his province and unit - the data asks of OpenHOI3.LeaderDetails here and
-- of BiceLib on the original. A leader who commands no unit has neither, and the two lines are left out.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local list = {}
local traits = {}

-- The branch the list is narrowed to: 1 all, then land, sea, air.
local branch = 1
local BRANCHES = { false, "land", "sea", "air" }
local BRANCH_KEYS = { "OPENHOI_WIN_ALL", "OPENHOI_WIN_GENERALS_LAND", "OPENHOI_WIN_GENERALS_SEA", "OPENHOI_WIN_GENERALS_AIR" }

-- The key of a choice string "Name [key]": what stands between the last pair of brackets.
local function keyOf(choice)
	return string.match(choice, ".*%[(.-)%]") or choice
end

return {
	title = "OPENHOI_WIN_GENERALS",
	order = 60,
	group = "OPENHOI_WIN_GROUP_GAME",
	group_order = 30,

	Collect = function(player)
		local source = Kit.Data("Generals")
		if source == nil then
			return { missing = true }
		end
		local answer = source.Collect(player)		-- A label names its leader's id in its last brackets.
		local chosen = list.selected
		local trait = traits.selected
		local effects = nil
		if chosen ~= nil and trait ~= nil and Kit.Data("Traits") ~= nil then
			effects = Kit.Data("Traits").EffectsForKey(keyOf(trait))
		end
		return {
			tag = player,
			list = answer,
			chosen = chosen,
			details = chosen and source.Details(keyOf(chosen)) or nil,
			trait = trait,
			effects = effects,
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
		ImGui.TextDisabled(data.tag)
		ImGui.SameLine()
		local names = {}
		for index, key in ipairs(BRANCH_KEYS) do
			names[index] = L(key)
		end
		ImGui.SetNextItemWidth(160)
		local changed, picked = ImGui.Combo("##branch", branch, names)
		if changed then
			branch = picked
		end
		if not Kit.Available(data.list) then
			return
		end

		local labels = {}
		for _, general in ipairs(data.list.generals) do
			if not BRANCHES[branch] or general.branch == BRANCHES[branch] then
				labels[#labels + 1] = general.label
			end
		end
		ImGui.SameLine()
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_GENERALS_COUNT", { N = #labels, ALL = #data.list.generals }))

		Kit.BeginPanes("general_panes", 360)
		if Kit.FilteredList("generals", list, labels, 0, 0) then
			-- Another leader: the trait chosen was the last one's.
			traits.selected = nil
			OpenHOI3.Refresh()
		end
		Kit.NextPane()
		if ImGui.BeginChild("general", 0, 0) then
			if list.selected == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_GENERALS_SELECT"))
			elseif data.chosen ~= list.selected then
				ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			elseif Kit.Available(data.details) then
				local details = data.details
				if details.location ~= nil and details.location ~= "unknown" then
					ImGui.SeparatorText(L("OPENHOI_WIN_GENERALS_IN_GAME"))
					ImGui.Text(Kit.Filled("OPENHOI_WIN_GENERALS_LOCATION", { NAME = details.location, ID = details.location_id }))
					ImGui.Text(Kit.Filled("OPENHOI_WIN_GENERALS_UNIT", { NAME = details.unit_name }))
				end

				ImGui.SeparatorText(L("OPENHOI_WIN_GENERALS_DEFINITION"))
				local _, height = ImGui.GetContentRegionAvail()
				Kit.TextBox("definition", details.dump, math.max(80, height * 0.4))

				ImGui.SeparatorText(L("OPENHOI_WIN_TRAITS"))
				if details.traits == nil or #details.traits == 0 then
					ImGui.TextDisabled(L("OPENHOI_WIN_GENERALS_NO_TRAITS"))
				else
					-- The traits above and the chosen one's effects below: the pane is too narrow for them side by side.
					local _, left = ImGui.GetContentRegionAvail()
					if Kit.FilteredList("generaltraits", traits, details.traits, 0, math.max(80, left * 0.45)) then
						OpenHOI3.Refresh()
					end
					if traits.selected == nil then
						ImGui.TextDisabled(L("OPENHOI_WIN_TRAITS_SELECT"))
					elseif data.trait ~= traits.selected then
						ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
					elseif Kit.Available(data.effects) then
						Kit.TextBox("traiteffects", data.effects.effects, -1)
					end
				end
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
