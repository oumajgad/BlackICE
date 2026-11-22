-- The LS Sliders AI page: hands the country's leadership sliders to the mod's own AI and sets the amounts of
-- officers, spies and diplomats between which it produces each.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); a form, as
-- script/openhoi/pageform.lua explains. The data is the mod's own, shared with the overlay on the original
-- engine: BiceLibGui.LsSliders, over the variables zzDsafe_CustomLeadershipSliders_...

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')
local Form = require('openhoi/pageform')

local form = Form.New("LsSliders")

-- The officers are kept for a while longer unless the data says not to.
local function buffering()
	return form.values.bufferNco ~= false
end

-- The fields Apply sends, in order: each row's two thresholds, then the buffer.
local function fields()
	local list = {}
	for _, row in ipairs(form.values.rows or {}) do
		list[#list + 1] = { row.key .. "Lower", row.lower or 0 }
		list[#list + 1] = { row.key .. "Upper", row.upper or 0 }
	end
	list[#list + 1] = { "bufferProdNco", buffering() and 1 or 0 }
	return list
end

-- Commit lowers a value above its row's maximum and a lower threshold above its upper one, and says which: the
-- boxes take what the game was sent.
form.correct = function(corrections)
	for _, correction in ipairs(corrections) do
		for _, row in ipairs(form.values.rows or {}) do
			if correction.field == row.key .. "Lower" then
				row.lower = correction.value
			elseif correction.field == row.key .. "Upper" then
				row.upper = correction.value
			end
		end
	end
end

return {
	title = "OPENHOI_WIN_LSSLIDERS",
	order = 120,
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
		local values = form.values

		if ImGui.BeginTable("lssliders", 3) then
			ImGui.TableSetupColumn("##name")
			ImGui.TableSetupColumn(L("OPENHOI_WIN_LSSLIDERS_LOWER"), 130)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_LSSLIDERS_UPPER"), 130)
			ImGui.TableHeadersRow()
			for _, row in ipairs(values.rows or {}) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(tostring(row.name))
				if (row.maximum or 0) > 0 and ImGui.IsItemHovered() then
					ImGui.SetTooltip(Kit.Filled("OPENHOI_WIN_LSSLIDERS_MAXIMUM", { N = row.maximum }))
				end
				ImGui.TableNextColumn()
				Form.Number(form, row.key .. "_lower", row, "lower", 0)
				ImGui.TableNextColumn()
				Form.Number(form, row.key .. "_upper", row, "upper", 0)
			end
			ImGui.EndTable()
		end

		local changed, ticked = ImGui.Checkbox(L("OPENHOI_WIN_LSSLIDERS_BUFFER"), buffering())
		if changed then
			values.bufferNco = ticked
			Form.Edited(form)
		end
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_LSSLIDERS_BUFFER_TIP"))
		end

		ImGui.TextWrapped(L("OPENHOI_WIN_LSSLIDERS_HELP"))
		ImGui.TextWrapped(L("OPENHOI_WIN_LSSLIDERS_HELP2"))
		Kit.Coloured(Kit.WARNING, L("OPENHOI_WIN_WARNING"))
		ImGui.SameLine()
		ImGui.TextWrapped(L("OPENHOI_WIN_LSSLIDERS_WARNING"))
	end,
}
