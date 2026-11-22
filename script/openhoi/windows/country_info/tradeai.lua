-- The Trade AI page: hands the country's trading to the mod's own trade AI and sets its limits - how much of each
-- resource to keep coming in, above what stockpile to sell and above what to stop buying.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); a form, as
-- script/openhoi/pageform.lua explains. The data is the mod's own, shared with the overlay on the original
-- engine: BiceLibGui.TradeAi, over the variables zzDsafe_TradeAi_...

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Form = require('openhoi/pageform')

local form = Form.New("TradeAi")

-- The fields Apply sends, in order: the deficit, then each resource's surplus and, where it has them, its caps.
local function fields()
	local values = form.values
	local list = { { "MaxDailySell", values.maxDailySell or 0 } }
	for _, row in ipairs(values.rows or {}) do
		list[#list + 1] = { row.key .. "_Buffer", row.buffer or 0 }
		if row.hasCaps then
			list[#list + 1] = { row.key .. "_BufferSaleCap", row.saleCap or 0 }
			list[#list + 1] = { row.key .. "_BufferCancelCap", row.cancelCap or 0 }
		end
	end
	return list
end

return {
	title = "OPENHOI_WIN_TRADEAI",
	order = 100,
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

		Form.Number(form, "deficit", values, "maxDailySell", 0, 120)
		ImGui.SameLine()
		ImGui.Text(L("OPENHOI_WIN_TRADEAI_DEFICIT"))
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_TRADEAI_DEFICIT_TIP"))
		end

		if ImGui.BeginTable("tradeai", 4) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_RESOURCE"))
			ImGui.TableSetupColumn(L("OPENHOI_WIN_TRADEAI_SURPLUS"), 130)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_TRADEAI_SELL_ABOVE"), 130)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_TRADEAI_STOCKPILE"), 130)
			ImGui.TableHeadersRow()
			for _, row in ipairs(values.rows or {}) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(tostring(row.name))
				ImGui.TableNextColumn()
				Form.Number(form, row.key .. "_buffer", row, "buffer", 2)
				ImGui.TableNextColumn()
				if row.hasCaps then
					Form.Number(form, row.key .. "_sale", row, "saleCap", 0)
				else
					ImGui.TextDisabled("-")
				end
				ImGui.TableNextColumn()
				if row.hasCaps then
					Form.Number(form, row.key .. "_cancel", row, "cancelCap", 0)
				else
					ImGui.TextDisabled("-")
				end
			end
			ImGui.EndTable()
		end
		ImGui.TextWrapped(L("OPENHOI_WIN_TRADEAI_HELP"))
	end,
}
