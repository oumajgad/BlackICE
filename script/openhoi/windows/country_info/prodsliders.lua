-- The Prod. Sliders AI page: hands the country's production sliders to the mod's own AI and sets how it shares
-- the IC out - each category's priority, its amount as a share of its need or as flat IC, and the extras.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); a form, as
-- script/openhoi/pageform.lua explains. The data is the mod's own, shared with the overlay on the original
-- engine: BiceLibGui.ProdSliders, over the variables zzDsafe_CustomProductionSliders_...

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')
local Form = require('openhoi/pageform')

local form = Form.New("ProdSliders")

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
	order = 110,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Form.Gather(form)
	end,

	Draw = function(data, player)
		if not Form.Ready(form, data) then
			return
		end
		Form.Top(form, fields)
		local rows = form.values.rows or {}
		local modes = { L("OPENHOI_WIN_PRODSLIDERS_PERCENT"), L("OPENHOI_WIN_PRODSLIDERS_FLAT") }

		-- How many categories use each priority: one used twice is marked, and Apply refuses it.
		local used = {}
		for _, row in ipairs(rows) do
			local priority = math.floor(tonumber(row.prio) or 0)
			used[priority] = (used[priority] or 0) + 1
		end

		if ImGui.BeginTable("prodsliders", 5) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PRODSLIDERS_CATEGORY"), 150)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PRODSLIDERS_PRIORITY"), 110)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PRODSLIDERS_AMOUNT"), 90)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PRODSLIDERS_MODE"), 130)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PRODSLIDERS_EXTRA"))
			ImGui.TableHeadersRow()
			for _, row in ipairs(rows) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(tostring(row.name))

				ImGui.TableNextColumn()
				local twice = (used[math.floor(tonumber(row.prio) or 0)] or 0) > 1
				Form.Number(form, row.key .. "_prio", row, "prio", 0, twice and 60 or -1)
				if twice then
					ImGui.SameLine()
					Kit.Coloured(Kit.ERROR, "!")
					if ImGui.IsItemHovered() then
						ImGui.SetTooltip(L("OPENHOI_WIN_PRODSLIDERS_TWICE"))
					end
				end

				ImGui.TableNextColumn()
				Form.Number(form, row.key .. "_amount", row, "amount", 0)

				ImGui.TableNextColumn()
				if row.fixedMode then
					ImGui.TextDisabled(modes[2])
				else
					ImGui.SetNextItemWidth(-1)
					local changed, picked = ImGui.Combo("##" .. row.key .. "_mode", (tonumber(row.mode) or 0) + 1, modes)
					if changed then
						row.mode = picked - 1
						Form.Edited(form)
					end
				end

				ImGui.TableNextColumn()
				ImGui.PushID(tostring(row.key))
				if row.extra == "limit" then
					Form.Check(form, L("OPENHOI_WIN_PRODSLIDERS_LIMIT"), row, "limitActive")
					ImGui.SameLine()
					Form.Number(form, "limit", row, "limit", 0, 90)
				elseif row.extra == "goal" then
					Form.Check(form, L("OPENHOI_WIN_PRODSLIDERS_GOAL"), row, "goalActive")
					ImGui.SameLine()
					Form.Number(form, "goal", row, "goal", 0, 90)
				elseif row.extra == "dissent" then
					Form.Check(form, L("OPENHOI_WIN_PRODSLIDERS_DISSENT"), row, "reduceDissent")
				end
				ImGui.PopID()
			end
			ImGui.EndTable()
		end
		ImGui.TextWrapped(L("OPENHOI_WIN_PRODSLIDERS_HELP"))
		ImGui.TextWrapped(L("OPENHOI_WIN_PRODSLIDERS_HELP2"))
	end,
}
