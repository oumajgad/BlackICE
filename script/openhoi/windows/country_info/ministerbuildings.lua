-- The Minister Buildings page: how far each kind of minister building is towards the next one the country's
-- ministers will place. The counters are kept by the mod's decisions and events; nothing here can be set.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.MinisterBuildings.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- How the rows are sorted: 1 by progress, 2 by name, 3 in the data's own order, by category.
local sort = 1
local SORTS = { "OPENHOI_WIN_MINBUILD_BY_PROGRESS", "OPENHOI_WIN_MINBUILD_BY_NAME", "OPENHOI_WIN_MINBUILD_BY_CATEGORY" }

local function sorted(rows)
	local list = {}
	for index, row in ipairs(rows) do
		list[index] = row
	end
	if sort == 1 then
		-- The furthest first; two equally far in their category's order.
		table.sort(list, function(a, b)
			if (a.percent or 0) ~= (b.percent or 0) then
				return (a.percent or 0) > (b.percent or 0)
			end
			return (a.order or 0) < (b.order or 0)
		end)
	elseif sort == 2 then
		table.sort(list, function(a, b) return string.lower(tostring(a.name)) < string.lower(tostring(b.name)) end)
	else
		table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
	end
	return list
end

return {
	title = "OPENHOI_WIN_MINBUILD",
	order = 90,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Kit.Gather("MinisterBuildings", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		local names = {}
		for index, key in ipairs(SORTS) do
			names[index] = L(key)
		end
		ImGui.SetNextItemWidth(140)
		local changed, picked = ImGui.Combo("##sort", sort, names)
		if changed then
			sort = picked
		end
		ImGui.SameLine()
		ImGui.TextDisabled(tostring(answer.tag))
		ImGui.TextWrapped(L("OPENHOI_WIN_MINBUILD_HELP"))

		if ImGui.BeginChild("buildings", 0, 0) then
			if ImGui.BeginTable("rows", 3) then
				ImGui.TableSetupColumn(L("OPENHOI_WIN_MINBUILD_BUILDING"))
				ImGui.TableSetupColumn(L("OPENHOI_WIN_MINBUILD_COUNT"), 110)
				ImGui.TableSetupColumn(L("OPENHOI_WIN_MINBUILD_PROGRESS"), 220)
				ImGui.TableHeadersRow()
				for _, row in ipairs(sorted(answer.rows or {})) do
					local count = math.max(row.count or 0, 0)
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(tostring(row.name))
					ImGui.TableNextColumn()
					ImGui.Text(string.format("%d / %d", count, row.trigger or 0))
					ImGui.TableNextColumn()
					-- The bar is full at the most; the figure over it is not held back.
					ImGui.ProgressBar(math.min(1, math.max(0, (row.percent or 0) / 100)), 0, string.format("%.1f%%", row.percent or 0))
				end
				ImGui.EndTable()
			end
		end
		ImGui.EndChild()
	end,
}
