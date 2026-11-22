-- The Strategic Res. page: the country's balance of each of the mod's ten strategic resources, how many trades
-- it sells and buys each in, and whether it sells at all - which the player sets here.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.StratResources. Stopping a resource's sales
-- sets the variable <key>_deactivate_sales by the game's own command.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

return {
	title = "OPENHOI_WIN_STRATRES",
	order = 50,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Kit.Gather("StratResources", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		local source = Kit.Data("StratResources")
		ImGui.TextDisabled(tostring(answer.tag))

		if ImGui.BeginTable("stratres", 5) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_RESOURCE"))
			ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_BALANCE"), 90)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_SELLING"), 90)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_BUYING"), 90)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_SALES"), 150)
			ImGui.TableHeadersRow()
			for _, row in ipairs(answer.rows or {}) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(tostring(row.name))
				ImGui.TableNextColumn()
				local balance = string.format("%d", row.balance or 0)
				if (row.balance or 0) < 0 then
					Kit.Coloured(Kit.ERROR, balance)
				else
					ImGui.Text(balance)
				end
				ImGui.TableNextColumn()
				ImGui.Text(string.format("%d", row.sell or 0))
				ImGui.TableNextColumn()
				ImGui.Text(string.format("%d", row.buy or 0))
				ImGui.TableNextColumn()
				-- A resource whose data does not say is sold.
				local selling, waiting = Kit.Shown("stratres_" .. tostring(row.key), row.selling ~= false)
				ImGui.PushID(tostring(row.key))
				local changed, ticked = ImGui.Checkbox("##sales", selling)
				ImGui.PopID()
				if changed then
					local key = row.key
					Kit.Pend("stratres_" .. tostring(key), ticked)
					Kit.Ask(function() source.SetSelling(key, ticked and 1 or 0) end)
				end
				ImGui.SameLine()
				Kit.PendingText(L(selling and "OPENHOI_WIN_STRATRES_ON" or "OPENHOI_WIN_STRATRES_OFF"), waiting)
			end
			ImGui.EndTable()
		end
	end,
}
