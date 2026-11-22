-- The OOB Browser page: the country's order of battle as a tree, with one unit's details beside it. It only
-- reads, and is apart from the game's own order of battle browser.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); what it shares with
-- the OOB Report is in script/openhoi/pageoob.lua. A province's name comes from the mod's own data,
-- BiceLibGui.Oob.ProvinceName, as on the original engine.
--
-- The whole tree is read when Refresh is pressed and when the country is another - not on a timer, a whole
-- order of battle being thousands of units.
--
-- Not carried over from the overlay: "Move to", which centres the game's map on the unit - OpenHOI3 gives a
-- page no way to move the map yet - the Auto box, and the colours of a unit without a commander, which is
-- marked with "!" here.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')
local Oob = require('openhoi/pageoob')

-- The order of battle as last read, the tag it was read for, and whether it is to be read again.
local oob = nil
local reread = true
-- Which formations are open, the unit chosen, its province's name, and the filter.
local open = {}
local chosen = nil
local provinceName = ""
local filter = {}
local scrollTo = nil

-- Whether a unit or anything below it has the filter's text in its name.
local function matches(unit, wanted, memo)
	if memo[unit.id] == nil then
		local found = Kit.Matches(unit.name, wanted)
		for _, child in ipairs(unit.children) do
			if matches(child, wanted, memo) then
				found = true
			end
		end
		memo[unit.id] = found
	end
	return memo[unit.id]
end

-- The rows on screen, in order: every unit whose formations above it are open and which the filter keeps.
local function visible()
	local rows, memo = {}, {}
	local function walk(unit, depth)
		if filter.filter ~= nil and filter.filter ~= "" and not matches(unit, filter.filter, memo) then
			return
		end
		rows[#rows + 1] = { unit = unit, depth = depth }
		if open[unit.id] then
			for _, child in ipairs(unit.children) do
				walk(child, depth + 1)
			end
		end
	end
	for _, root in ipairs(oob.roots) do
		walk(root, 0)
	end
	return rows
end

local function choose(unit)
	if chosen ~= unit.id then
		chosen = unit.id
		provinceName = ""
		OpenHOI3.Refresh()
	end
end

-- The chosen unit's details as rows of label and value.
local function detailRows(unit)
	local rows = {
		{ L("OPENHOI_WIN_OOB_KIND"), unit.kind },
		{ L("OPENHOI_WIN_OOB_ID"), tostring(unit.id) },
		{ L("OPENHOI_WIN_OOB_COMMANDER"), unit.leader and string.format("%s (skill %d of %d)",
			unit.leader.name ~= "" and unit.leader.name or "?", unit.leader.skill, unit.leader.max_skill) or L("OPENHOI_WIN_OOB_NO_COMMANDER") },
	}
	if (unit.province or 0) > 0 then
		rows[#rows + 1] = { L("OPENHOI_WIN_OOB_PROVINCE"), provinceName ~= "" and string.format("%s (%d)", provinceName, unit.province)
			or tostring(unit.province) }
	end
	rows[#rows + 1] = { L("OPENHOI_WIN_OOB_SUPPLY"), Oob.Percent(unit.supply) }
	rows[#rows + 1] = { L("OPENHOI_WIN_OOB_FUEL"), Oob.Percent(unit.fuel) }
	if #unit.regiments > 0 then
		rows[#rows + 1] = { L("OPENHOI_WIN_OOB_SUPPLY_USED"), string.format("%.2f", unit.supply_used) }
		rows[#rows + 1] = { L("OPENHOI_WIN_OOB_FUEL_USED"), string.format("%.2f", unit.fuel_used) }
	end
	rows[#rows + 1] = { L("OPENHOI_WIN_OOB_DUG_IN"), string.format("%.1f", unit.dug_in) }
	rows[#rows + 1] = { L("OPENHOI_WIN_OOB_COMBINED"), Oob.Percent(unit.combined_arms) }
	if unit.cooldown > 0 then
		rows[#rows + 1] = { L("OPENHOI_WIN_OOB_COOLDOWN"), string.format("%d hours", math.floor(unit.cooldown)) }
	end
	rows[#rows + 1] = { L("OPENHOI_WIN_OOB_ORDERS"), unit.orders ~= "" and unit.orders or "-" }
	return rows
end

-- What stands below a unit, as lines.
local function belowLines(unit)
	local below = unit.below
	if below == nil or below.units == 0 then
		return nil
	end
	return {
		Oob.Branches(below),
		string.format("%d subordinate formations, %d levels deep", #unit.children, below.depth),
		string.format("%d regiments below", below.regiments),
		string.format("%d without a commander", below.leaderless),
		string.format("Supply %s average, fuel %s average", Oob.Percent(below.supply / below.units), Oob.Percent(below.fuel / below.units)),
		string.format("Consumes %.2f supply, %.2f fuel", below.supply_used + unit.supply_used, below.fuel_used + unit.fuel_used),
	}
end

-- The details as text for the clipboard, lines ended as Windows ends them.
local function copyText(unit)
	local lines = { unit.name }
	for _, row in ipairs(detailRows(unit)) do
		lines[#lines + 1] = string.format("  %-16s %s", row[1], row[2])
	end
	local below = belowLines(unit)
	if below ~= nil then
		lines[#lines + 1] = ""
		lines[#lines + 1] = L("OPENHOI_WIN_OOB_BELOW")
		for _, line in ipairs(below) do
			lines[#lines + 1] = "  " .. line
		end
	end
	if #unit.regiments > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = L("OPENHOI_WIN_OOB_REGIMENTS")
		for _, regiment in ipairs(unit.regiments) do
			lines[#lines + 1] = string.format("  %-40s%6.1f strength%6.1f org", regiment.name, regiment.strength, regiment.organisation)
		end
	end
	return table.concat(lines, "\r\n") .. "\r\n"
end

return {
	title = "OPENHOI_WIN_OOBBROWSER",
	order = 15,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		local tag = Kit.Selected(player)
		if reread or oob == nil or oob.tag ~= tag then
			reread = false
			oob = Oob.Read(tag)		end
		local unit = chosen and oob.byId[chosen] or nil
		if unit ~= nil and (unit.province or 0) > 0 and provinceName == "" and Kit.Data("Oob") ~= nil then
			local answer = Kit.Data("Oob").ProvinceName(unit.province)
			provinceName = answer.available ~= false and tostring(answer.name or "") or ""
		end
		return { tag = tag }
	end,

	Draw = function(data, player)
		if data == nil or oob == nil then
			return
		end
		if ImGui.Button(L("OPENHOI_WIN_REFRESH")) then
			reread = true
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		ImGui.TextDisabled(tostring(data.tag))
		ImGui.SameLine()
		ImGui.Text(string.format("%d units: %s, in %d regiments", oob.totals.units, Oob.Branches(oob.totals), oob.totals.regiments))
		if #oob.units == 0 then
			return
		end

		if ImGui.Button(L("OPENHOI_WIN_OOB_EXPAND")) then
			for _, unit in ipairs(oob.units) do
				open[unit.id] = #unit.children > 0 or nil
			end
		end
		ImGui.SameLine()
		if ImGui.Button(L("OPENHOI_WIN_OOB_COLLAPSE")) then
			open = {}
		end
		ImGui.SameLine()
		Kit.FilterBox(filter, 200)

		Kit.BeginPanes("oob_panes", 460)
		if ImGui.BeginChild("tree", 0, 0) then
			local rows = visible()
			local at = nil
			for index, row in ipairs(rows) do
				local unit = row.unit
				if unit.id == chosen then
					at = index
				end
				ImGui.PushID(tostring(unit.id))
				-- The arrow opens and closes a formation; the name chooses the unit.
				local indent = string.rep("    ", row.depth)
				if #unit.children > 0 then
					ImGui.Text(indent)
					ImGui.SameLine()
					if ImGui.SmallButton(open[unit.id] and "v" or ">") then
						open[unit.id] = not open[unit.id] or nil
					end
				else
					ImGui.Text(indent .. "     ")
				end
				ImGui.SameLine()
				local label = unit.name
				if unit.leader == nil then
					label = label .. " !"
				end
				if unit.below ~= nil and unit.below.units > 0 then
					label = label .. string.format("  (%d)", unit.below.units)
				end
				if ImGui.Selectable(label, unit.id == chosen) then
					choose(unit)
				end
				if ImGui.IsItemHovered() and unit.below ~= nil and unit.below.units > 0 then
					ImGui.SetTooltip(Oob.Branches(unit.below) .. " below"
						.. (unit.below.leaderless > 0 and string.format("\n%d of them without a commander", unit.below.leaderless) or ""))
				end
				if scrollTo == unit.id then
					ImGui.SetScrollHereY(0.5)
					scrollTo = nil
				end
				ImGui.PopID()
			end

			-- The arrow keys while the tree was the last thing clicked and the filter is not typed into.
			if #rows > 0 and not filter.typing and ImGui.IsWindowFocused() then
				local to = nil
				local unit = at and rows[at].unit or nil
				if ImGui.IsKeyPressed("DownArrow") then
					to = at and math.min(at + 1, #rows) or 1
				elseif ImGui.IsKeyPressed("UpArrow") then
					to = at and math.max(at - 1, 1) or 1
				elseif ImGui.IsKeyPressed("RightArrow") and unit ~= nil then
					if #unit.children > 0 and not open[unit.id] then
						open[unit.id] = true
					else
						to = math.min(at + 1, #rows)
					end
				elseif ImGui.IsKeyPressed("LeftArrow") and unit ~= nil then
					if #unit.children > 0 and open[unit.id] then
						open[unit.id] = nil
					elseif unit.over ~= nil then
						choose(unit.over)
						scrollTo = unit.over.id
					end
				end
				if to ~= nil and rows[to] ~= nil and to ~= at then
					choose(rows[to].unit)
					scrollTo = rows[to].unit.id
				end
			end
		end
		ImGui.EndChild()

		Kit.NextPane()
		if ImGui.BeginChild("unit", 0, 0) then
			local unit = chosen and oob.byId[chosen] or nil
			if unit == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_OOB_SELECT"))
			else
				ImGui.Text(unit.name)
				ImGui.SameLine()
				if ImGui.SmallButton(L("OPENHOI_WIN_COPY")) then
					ImGui.SetClipboardText(copyText(unit))
				end
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip(L("OPENHOI_WIN_OOB_COPY_TIP"))
				end
				Kit.LabelTable("details", detailRows(unit))

				ImGui.SeparatorText(L("OPENHOI_WIN_OOB_BELOW"))
				local below = belowLines(unit)
				if below == nil then
					ImGui.TextDisabled(L("OPENHOI_WIN_OOB_BOTTOM"))
				else
					for index, line in ipairs(below) do
						if index == 4 and unit.below.leaderless > 0 then
							Kit.Coloured(Kit.ERROR, line)
						else
							ImGui.Text(line)
						end
					end
				end

				ImGui.SeparatorText(L("OPENHOI_WIN_OOB_REGIMENTS"))
				if #unit.regiments == 0 then
					ImGui.TextDisabled(L("OPENHOI_WIN_OOB_NO_REGIMENTS"))
				elseif ImGui.BeginTable("regiments", 3) then
					ImGui.TableSetupColumn(L("OPENHOI_WIN_OOB_REGIMENT"))
					ImGui.TableSetupColumn(L("OPENHOI_WIN_OOB_STRENGTH"), 90)
					ImGui.TableSetupColumn(L("OPENHOI_WIN_OOB_ORG"), 90)
					ImGui.TableHeadersRow()
					for _, regiment in ipairs(unit.regiments) do
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						ImGui.Text(regiment.name ~= "" and regiment.name or "(unnamed)")
						ImGui.TableNextColumn()
						ImGui.Text(string.format("%.1f", regiment.strength))
						ImGui.TableNextColumn()
						ImGui.Text(string.format("%.1f", regiment.organisation))
					end
					ImGui.EndTable()
				end
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
