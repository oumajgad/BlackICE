-- The OOB Report page: the country's order of battle counted - in all, by kind of unit, by top level formation
-- and by type of regiment. It only reads.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); what it shares with
-- the OOB Browser is in script/openhoi/pageoob.lua. A regiment type's name comes from the mod's own data,
-- BiceLibGui.Oob.TypeNames, as on the original engine.
--
-- The whole order of battle is read when Refresh is pressed and when the country is another.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')
local Oob = require('openhoi/pageoob')

local report = nil
local reread = true
-- The regiment types' names as the mod has them, asked once a key and kept: names[key] = text, "" for none.
local names = {}
-- Which branch the table of types shows: 1 all, then land, air, naval.
local show = 1
local BRANCHES = { false, "land", "air", "naval" }

-- The kinds down the chain of command: land from theatre to division, then air, then naval.
local RANK = { ["Theatre"] = 1, ["Army group"] = 2, ["Army"] = 3, ["Corps"] = 4, ["Division"] = 5, ["Air wing"] = 6, ["Fleet"] = 7 }

-- The order of battle counted: by kind, and by type of regiment and branch.
local function build(oob)
	local kinds, byKind = {}, {}
	local types, byType = {}, {}
	for _, unit in ipairs(oob.units) do
		local kind = byKind[unit.kind]
		if kind == nil then
			kind = { kind = unit.kind, units = 0, regiments = 0 }
			byKind[unit.kind] = kind
			kinds[#kinds + 1] = kind
		end
		kind.units = kind.units + 1
		kind.regiments = kind.regiments + #unit.regiments
		for _, regiment in ipairs(unit.regiments) do
			if regiment.type ~= nil and regiment.type ~= "" then
				local id = unit.branch .. "/" .. regiment.type
				local one = byType[id]
				if one == nil then
					one = { key = regiment.type, branch = unit.branch, count = 0 }
					byType[id] = one
					types[#types + 1] = one
				end
				one.count = one.count + 1
			end
		end
	end
	table.sort(kinds, function(a, b)
		local left, right = RANK[a.kind] or 99, RANK[b.kind] or 99
		if left ~= right then
			return left < right
		end
		return a.kind < b.kind
	end)
	-- The most numerous first; equal counts by key.
	table.sort(types, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.key < b.key
	end)
	return { oob = oob, kinds = kinds, types = types }
end

local function typeName(one)
	local name = names[one.key]
	if name ~= nil and name ~= "" then
		return name .. " [" .. one.key .. "]"
	end
	return one.key
end

-- The whole report as text for the clipboard.
local function copyText()
	local oob, totals = report.oob, report.oob.totals
	local lines = {
		"Order of battle - " .. tostring(oob.tag), "",
		string.format("%d units: %s", totals.units, Oob.Branches(totals)),
		string.format("%d regiments in %d formations that report to nobody", totals.regiments, #oob.roots),
		string.format("%d units without a commander", totals.leaderless),
		string.format("%s supply, %s fuel on average", Oob.Percent(totals.supply / math.max(totals.units, 1)), Oob.Percent(totals.fuel / math.max(totals.units, 1))),
		string.format("consumes %.2f supply and %.2f fuel a day", totals.supply_used, totals.fuel_used), "",
		"By kind",
	}
	for _, kind in ipairs(report.kinds) do
		lines[#lines + 1] = string.format("  %-24s%5d units, %5d regiments", kind.kind, kind.units, kind.regiments)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Top level formations"
	for _, root in ipairs(oob.roots) do
		local below = root.below
		lines[#lines + 1] = string.format("  %-40s%4d land %4d air %4d naval %5d regiments %8.2f supply %8.2f fuel", root.name,
			below.land, below.air, below.naval, below.regiments + #root.regiments, below.supply_used + root.supply_used, below.fuel_used + root.fuel_used)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = BRANCHES[show] and ("By type (" .. BRANCHES[show] .. " only)") or "By type"
	for _, one in ipairs(report.types) do
		if not BRANCHES[show] or one.branch == BRANCHES[show] then
			lines[#lines + 1] = string.format("  %-48s%5d", typeName(one), one.count)
		end
	end
	return table.concat(lines, "\r\n") .. "\r\n"
end

return {
	title = "OPENHOI_WIN_OOBREPORT",
	order = 16,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		local tag = Kit.Selected(player)
		if reread or report == nil or report.oob.tag ~= tag then
			reread = false
			report = build(Oob.Read(tag))
			-- The names of the types not asked before, in one call.
			local asked = {}
			for _, one in ipairs(report.types) do
				if names[one.key] == nil then
					asked[#asked + 1] = one.key
					names[one.key] = ""
				end
			end
			if #asked > 0 and Kit.Data("Oob") ~= nil then
				local answer = Kit.Data("Oob").TypeNames(table.concat(asked, ";"))
				if answer.available ~= false then
					for index, key in ipairs(asked) do
						names[key] = tostring((answer.names or {})[index] or "")
					end
				end
			end
		end
		return { tag = tag }
	end,

	Draw = function(data, player)
		if data == nil or report == nil then
			return
		end
		local oob, totals = report.oob, report.oob.totals
		if ImGui.Button(L("OPENHOI_WIN_REFRESH")) then
			reread = true
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		ImGui.TextDisabled(tostring(data.tag))
		ImGui.SameLine()
		if ImGui.Button(L("OPENHOI_WIN_COPY")) then
			ImGui.SetClipboardText(copyText())
		end
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_OOBREPORT_COPY_TIP"))
		end
		if totals.units == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_OOBREPORT_NONE"))
			return
		end

		Kit.BeginPanes("totals_panes", 520)
		ImGui.Text(string.format("%d units: %s", totals.units, Oob.Branches(totals)))
		ImGui.Text(string.format("%d regiments across %d formations that report to nobody", totals.regiments, #oob.roots))
		local without = string.format("%d units without a commander", totals.leaderless)
		if totals.leaderless > 0 then
			Kit.Coloured(Kit.ERROR, without)
		else
			ImGui.Text(without)
		end
		ImGui.Text(string.format("Supply %s average, fuel %s average", Oob.Percent(totals.supply / totals.units), Oob.Percent(totals.fuel / totals.units)))
		ImGui.Text(string.format("Consumes %.2f supply and %.2f fuel a day", totals.supply_used, totals.fuel_used))
		Kit.NextPane()
		if ImGui.BeginTable("kinds", 3) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_OOB_KIND"))
			ImGui.TableSetupColumn(L("OPENHOI_WIN_OOBREPORT_UNITS"), 80)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_OOB_REGIMENTS"), 100)
			ImGui.TableHeadersRow()
			for _, kind in ipairs(report.kinds) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(kind.kind)
				ImGui.TableNextColumn()
				ImGui.Text(string.format("%d", kind.units))
				ImGui.TableNextColumn()
				if kind.regiments > 0 then
					ImGui.Text(string.format("%d", kind.regiments))
				else
					ImGui.TextDisabled("-")
				end
			end
			ImGui.EndTable()
		end
		Kit.EndPanes()

		ImGui.SeparatorText(L("OPENHOI_WIN_OOBREPORT_TOP"))
		if ImGui.BeginChild("top", 0, 8 * Kit.LINE + 30) then
			if ImGui.BeginTable("formations", 7) then
				ImGui.TableSetupColumn(L("OPENHOI_WIN_OOBREPORT_FORMATION"))
				for _, key in ipairs({ "OPENHOI_WIN_GENERALS_LAND", "OPENHOI_WIN_GENERALS_AIR", "OPENHOI_WIN_OOBREPORT_NAVAL",
					"OPENHOI_WIN_OOB_REGIMENTS", "OPENHOI_WIN_OOB_SUPPLY", "OPENHOI_WIN_OOB_FUEL" }) do
					ImGui.TableSetupColumn(L(key), 80)
				end
				ImGui.TableHeadersRow()
				for _, root in ipairs(oob.roots) do
					local below = root.below
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(root.name)
					if ImGui.IsItemHovered() then
						ImGui.SetTooltip(root.kind)
					end
					for _, figure in ipairs({ below.land, below.air, below.naval, below.regiments + #root.regiments }) do
						ImGui.TableNextColumn()
						ImGui.Text(string.format("%d", figure))
					end
					ImGui.TableNextColumn()
					ImGui.Text(string.format("%.2f", below.supply_used + root.supply_used))
					ImGui.TableNextColumn()
					ImGui.Text(string.format("%.2f", below.fuel_used + root.fuel_used))
				end
				ImGui.EndTable()
			end
		end
		ImGui.EndChild()
		ImGui.TextDisabled(L("OPENHOI_WIN_OOBREPORT_TOP_NOTE"))

		ImGui.SeparatorText(L("OPENHOI_WIN_OOBREPORT_BY_TYPE"))
		ImGui.SetNextItemWidth(120)
		local changed, picked = ImGui.Combo(L("OPENHOI_WIN_OOBREPORT_SHOW"), show,
			{ L("OPENHOI_WIN_ALL"), L("OPENHOI_WIN_GENERALS_LAND"), L("OPENHOI_WIN_GENERALS_AIR"), L("OPENHOI_WIN_OOBREPORT_NAVAL") })
		if changed then
			show = picked
		end
		local shown = {}
		for _, one in ipairs(report.types) do
			if not BRANCHES[show] or one.branch == BRANCHES[show] then
				shown[#shown + 1] = one
			end
		end
		ImGui.SameLine()
		ImGui.TextDisabled(string.format("%d of %d types", #shown, #report.types))
		if #shown == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_OOBREPORT_NO_TYPES"))
			return
		end
		if ImGui.BeginChild("types", 0, 0) then
			if ImGui.BeginTable("bytype", 2) then
				ImGui.TableSetupColumn(L("OPENHOI_WIN_OOBREPORT_TYPE"))
				ImGui.TableSetupColumn(L("OPENHOI_WIN_OOBREPORT_COUNT"), 90)
				ImGui.TableHeadersRow()
				for _, one in ipairs(shown) do
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(typeName(one))
					if ImGui.IsItemHovered() then
						ImGui.SetTooltip(one.branch)
					end
					ImGui.TableNextColumn()
					ImGui.Text(string.format("%d", one.count))
				end
				ImGui.EndTable()
			end
		end
		ImGui.EndChild()
	end,
}
