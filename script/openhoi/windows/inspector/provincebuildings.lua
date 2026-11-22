-- The Province Buildings page: for a building chosen from a list, every province the country holds with the
-- building's level there; and for a province chosen from those, what it makes and its own modifiers. It only reads.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.ProvinceBuildings. The province's raw figures
-- come from OpenHOI3.ProvinceDetails here and from BiceLib on the original.
--
-- Three panes: buildings, provinces, details. Nothing is read on a timer: the buildings once, the provinces when
-- a building is chosen, the details when a province is chosen, and all three again on Refresh.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local buildings = {}
local provinces = {}

-- What has been read: the buildings, the provinces of the building chosen, the details of the province chosen.
local list = nil
local found = nil
local details = nil
-- What is to be read at the next Collect.
local wantList, wantProvinces, wantDetails = true, false, false

-- How the provinces are sorted: 1 by level, 2 by name.
local sort = 1

-- A province's row: "<level> - <name>[ (occupied)] [<id>]".
local function row(province)
	return string.format("%d - %s%s [%s]", math.floor(tonumber(province.level) or 0), tostring(province.name),
		province.occupied and (" " .. L("OPENHOI_WIN_PROVBUILD_OCCUPIED")) or "", tostring(province.id))
end

-- The provinces in the page's order: those owned before those only held; then by level where that is the sort,
-- the highest first; then by name.
local function ordered(all)
	local sorted = {}
	for index, province in ipairs(all) do
		sorted[index] = province
	end
	table.sort(sorted, function(a, b)
		if (a.occupied and true or false) ~= (b.occupied and true or false) then
			return not a.occupied
		end
		if sort == 1 and (a.level or 0) ~= (b.level or 0) then
			return (a.level or 0) > (b.level or 0)
		end
		return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
	end)
	return sorted
end

local function figures(id, rows)
	if rows == nil or #rows == 0 then
		ImGui.TextDisabled(L("OPENHOI_WIN_NONE"))
		return
	end
	local pairs = {}
	for _, one in ipairs(rows) do
		pairs[#pairs + 1] = { one.label, one.value }
	end
	Kit.LabelTable(id, pairs)
end

return {
	title = "OPENHOI_WIN_PROVBUILD",
	order = 50,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		return Kit.Gather("ProvinceBuildings", function(source)
			if wantList then
				wantList = false
				list = source.Collect()
			end			if wantProvinces and buildings.selected ~= nil then
				wantProvinces = false
				found = source.Provinces(buildings.selected)
			end			if wantDetails and provinces.id ~= nil then
				wantDetails = false
				details = source.Details(provinces.id)
			end
			return { tag = Kit.Selected(player) }
		end)
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end
		if data.missing then
			ImGui.TextDisabled(L("OPENHOI_WIN_NO_DATA"))
			return
		end

		if ImGui.Button(L("OPENHOI_WIN_REFRESH")) then
			wantList, wantProvinces, wantDetails = true, buildings.selected ~= nil, provinces.id ~= nil
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		ImGui.TextDisabled(tostring(data.tag))
		ImGui.SameLine()
		ImGui.SetNextItemWidth(120)
		local changed, picked = ImGui.Combo("##sort", sort, { L("OPENHOI_WIN_PROVBUILD_BY_LEVEL"), L("OPENHOI_WIN_NAME") })
		if changed then
			sort = picked
		end
		if not Kit.Available(list) then
			return
		end

		Kit.BeginPanes("buildings_panes", 240)
		if Kit.FilteredList("buildings", buildings, list.buildings or {}, 0, 0) then
			-- Another building: the provinces and the details were the last one's.
			found, details = nil, nil
			provinces.selected, provinces.id = nil, nil
			wantProvinces = true
			OpenHOI3.Refresh()
		end
		Kit.NextPane()
		if ImGui.BeginChild("provinces_and_details", 0, 0) then
			Kit.BeginPanes("provinces_panes", 280)
			if ImGui.BeginChild("provinces", 0, 0) then
				if buildings.selected == nil then
					ImGui.TextDisabled(L("OPENHOI_WIN_PROVBUILD_SELECT_BUILDING"))
				elseif found == nil then
					ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
				elseif Kit.Available(found) then
					local all = ordered(found.provinces or {})
					ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_PROVBUILD_COUNT", { N = #all }))
					local rows, byRow = {}, {}
					for _, province in ipairs(all) do
						local text = row(province)
						rows[#rows + 1] = text
						byRow[text] = province
					end
					if Kit.FilteredList("provincelist", provinces, rows, 0, 0) and byRow[provinces.selected] ~= nil then
						provinces.id = byRow[provinces.selected].id
						details = nil
						wantDetails = true
						OpenHOI3.Refresh()
					end
				end
			end
			ImGui.EndChild()
			Kit.NextPane()
			if ImGui.BeginChild("details", 0, 0) then
				if provinces.id == nil then
					ImGui.TextDisabled(L("OPENHOI_WIN_PROVBUILD_SELECT_PROVINCE"))
				elseif details == nil then
					ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
				elseif Kit.Available(details) then
					ImGui.Text(Kit.Filled("OPENHOI_WIN_PROVBUILD_PROVINCE", { ID = tostring(details.id) }))
					ImGui.SeparatorText(L("OPENHOI_WIN_PROVBUILD_BASE"))
					figures("values", details.values)
					ImGui.SeparatorText(L("OPENHOI_WIN_PROVBUILD_LOCAL"))
					figures("modifiers", details.modifiers)
					ImGui.TextWrapped(L("OPENHOI_WIN_PROVBUILD_NOTE"))
				end
			end
			ImGui.EndChild()
			Kit.EndPanes()
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
