-- The Strategic Trades page: the trades in the mod's strategic resources the country buys in and sells in, the
-- one running out soonest first.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Trades, which reads the table the mod's daily
-- scripts keep of the trades. It only reads.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- One of the two lists: who the other side is, the resource and the days left, amber in the last week.
local function list(id, trades, other, heading)
	ImGui.SeparatorText(L(heading))
	if trades == nil or #trades == 0 then
		ImGui.TextDisabled(L("OPENHOI_WIN_TRADES_NONE"))
		return
	end
	if ImGui.BeginTable(id, 3) then
		ImGui.TableSetupColumn(L(other == "seller" and "OPENHOI_WIN_TRADES_SELLER" or "OPENHOI_WIN_TRADES_BUYER"))
		ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_RESOURCE"))
		ImGui.TableSetupColumn(L("OPENHOI_WIN_EXPIRES"))
		ImGui.TableHeadersRow()
		for _, trade in ipairs(trades) do
			ImGui.TableNextRow()
			ImGui.TableNextColumn()
			ImGui.Text(tostring(trade[other]))
			ImGui.TableNextColumn()
			ImGui.Text(tostring(trade.resource))
			ImGui.TableNextColumn()
			local days = string.format("%dd", trade.expires_in or 0)
			if (trade.expires_in or 0) <= 7 then
				Kit.Coloured(Kit.WARNING, days)
			else
				ImGui.Text(days)
			end
		end
		ImGui.EndTable()
	end
end

return {
	title = "OPENHOI_WIN_TRADES",
	order = 60,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Kit.Gather("Trades", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		ImGui.TextDisabled(tostring(data.answer.tag))
		list("buys", data.answer.buys, "seller", "OPENHOI_WIN_TRADES_BUYING")
		list("sales", data.answer.sales, "buyer", "OPENHOI_WIN_TRADES_SELLING")
	end,
}
