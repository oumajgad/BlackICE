-- The Prod. Sliders AI page: hands the country's production sliders to the mod's own AI and sets how it shares
-- the IC out - each category's priority, its amount as a share of its need or as flat IC, and the extras.
--
-- A native page of OpenHOI3's enhanced mode (docs/openhoi/README.md): it fills the window
-- openhoi_blackice_prodsliders of interface/openhoi/sliders.gui, which a button on the production screen opens.
-- A form, as script/openhoi/nativeform.lua explains. The data is the mod's own, shared with the overlay on the
-- original engine: BiceLibGui.ProdSliders, over the variables zzDsafe_CustomProductionSliders_...

local Gui = OpenHOI3.Gui
local L = OpenHOI3.Localise
local Form = require('openhoi/pageform')
local Native = require('openhoi/nativeform')

local form = Form.New("ProdSliders")

-- The rows the window declares.
local ROWS = 6

-- A category's priority a step up or down, held between one and how many categories there are. The category that
-- had the number it comes to takes the one it leaves, so that no two share one.
local function step(rows, row, by)
	local from = math.floor(tonumber(row.prio) or 0)
	local to = from + by
	if to < 1 or to > #rows then
		return
	end
	for _, other in ipairs(rows) do
		if other ~= row and math.floor(tonumber(other.prio) or 0) == to then
			other.prio = from
		end
	end
	row.prio = to
	Form.Edited(form)
end

-- The fields Apply sends, in order: each category's priority, amount and mode, then the extras.
local function fields()
	local list = {}
	local rows = form.values.rows or {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { row.key .. "Prio", row.prio or 0 }
		list[#list + 1] = { row.key .. "Amount", row.amount or 0 }
		list[#list + 1] = { row.key .. "InvestMode", row.mode or 0 }
	end
	for _, row in ipairs(rows) do
		if row.extra == "limit" then
			list[#list + 1] = { row.key .. "Limit", row.limit or 0 }
			list[#list + 1] = { row.key .. "Limit_active", row.limitActive and 1 or 0 }
		elseif row.extra == "goal" then
			list[#list + 1] = { "supplyGoal", row.goal or 0 }
			list[#list + 1] = { "supplyGoal_active", row.goalActive and 1 or 0 }
		elseif row.extra == "dissent" then
			list[#list + 1] = { "reduceDissent", row.reduceDissent and 1 or 0 }
		end
	end
	return list
end

return {
	title = "OPENHOI_WIN_PRODSLIDERS",
	window = "openhoi_blackice_prodsliders",
	host = "production",
	opener = "openhoi_blackice_prodsliders_opener",

	Collect = function(player)
		return Form.Gather(form)
	end,

	Fill = function(data, player)
		Gui.SetText("title", L("OPENHOI_WIN_PRODSLIDERS"))
		Gui.SetTooltip("help", L("OPENHOI_WIN_PRODSLIDERS_HELP") .. "\n\n" .. L("OPENHOI_WIN_PRODSLIDERS_HELP2"))
		if not Native.Ready(form, data) then
			return
		end
		Native.Top(form, fields)
		local rows = form.values.rows or {}

		-- How many categories use each priority: one used twice is marked.
		local used = {}
		for _, row in ipairs(rows) do
			local priority = math.floor(tonumber(row.prio) or 0)
			used[priority] = (used[priority] or 0) + 1
		end

		for index = 1, ROWS do
			local row = rows[index]
			local n = tostring(index)
			for _, element in ipairs({ "row_", "name_", "prio_bg_", "prio_", "prio_up_", "prio_down_", "amount_bg_", "amount_", "mode_" }) do
				Gui.SetVisible(element .. n, row ~= nil)
			end
			local ticked = row ~= nil and row.extra ~= nil and row.extra ~= ""
			local numbered = row ~= nil and (row.extra == "limit" or row.extra == "goal")
			Gui.SetVisible("check_" .. n, ticked)
			Gui.SetVisible("check_label_" .. n, ticked)
			Gui.SetVisible("extra_bg_" .. n, numbered)
			Gui.SetVisible("extra_" .. n, numbered)
			if row ~= nil then
				Gui.SetText("name_" .. n, tostring(row.name))
				-- The priority is moved a step at a time by its two arrows, and shown. Up is a higher priority, which is
				-- a lower number: 1 is served first.
				if Gui.Pressed("prio_up_" .. n) then
					step(rows, row, -1)
				end
				if Gui.Pressed("prio_down_" .. n) then
					step(rows, row, 1)
				end
				local priority = math.floor(tonumber(row.prio) or 0)
				Gui.SetText("prio_" .. n, tostring(priority))
				Gui.SetEnabled("prio_up_" .. n, priority > 1)
				Gui.SetEnabled("prio_down_" .. n, priority < #rows)
				local twice = (used[math.floor(tonumber(row.prio) or 0)] or 0) > 1
				if twice then
					Gui.SetColour("prio_bg_" .. n, 255, 150, 150)
					Gui.SetTooltip("prio_bg_" .. n, L("OPENHOI_WIN_PRODSLIDERS_TWICE"))
				else
					Gui.SetColour("prio_bg_" .. n, 255, 255, 255)
					Gui.SetTooltip("prio_bg_" .. n, "")
				end
				Native.Number(form, "amount_" .. n, row, "amount")

				-- The mode is a button that turns between the two; a category with one mode only has it greyed.
				if row.fixedMode then
					Gui.SetText("mode_" .. n, L("OPENHOI_WIN_PRODSLIDERS_FLAT"))
					Gui.SetEnabled("mode_" .. n, false)
				else
					if Gui.Pressed("mode_" .. n) then
						row.mode = (tonumber(row.mode) or 0) == 0 and 1 or 0
						Form.Edited(form)
					end
					Gui.SetText("mode_" .. n, L((tonumber(row.mode) or 0) == 0 and "OPENHOI_WIN_PRODSLIDERS_PERCENT" or "OPENHOI_WIN_PRODSLIDERS_FLAT"))
					Gui.SetEnabled("mode_" .. n, true)
				end

				if row.extra == "limit" then
					Gui.SetText("check_label_" .. n, L("OPENHOI_WIN_PRODSLIDERS_LIMIT"))
					Native.Check(form, "check_" .. n, row, "limitActive")
					Native.Number(form, "extra_" .. n, row, "limit")
				elseif row.extra == "goal" then
					Gui.SetText("check_label_" .. n, L("OPENHOI_WIN_PRODSLIDERS_GOAL"))
					Native.Check(form, "check_" .. n, row, "goalActive")
					Native.Number(form, "extra_" .. n, row, "goal")
				elseif row.extra == "dissent" then
					Gui.SetText("check_label_" .. n, L("OPENHOI_WIN_PRODSLIDERS_DISSENT"))
					Native.Check(form, "check_" .. n, row, "reduceDissent")
				end
			end
		end
	end,
}
