-- The Misc page: two switches that take groups of the mod's decisions out of the country's decision list.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Misc. Each switch is a variable of the
-- country - disable_resource_trade_decision, disable_mines_expansion_decision - set by the game's own command,
-- which the mod's decisions read.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- One switch: a checkbox that shows what was asked for until the game answers the same.
local function switch(name, label, hidden, set)
	local shown, waiting = Kit.Shown(name, hidden and true or false)
	local changed, ticked = ImGui.Checkbox(L(label), shown)
	if changed then
		Kit.Pend(name, ticked)
		Kit.Ask(function() set(ticked and 1 or 0) end)
	end
	if waiting then
		ImGui.SameLine()
		Kit.PendingText(L("OPENHOI_WIN_MISC_WAITING"), true)
	end
end

return {
	title = "OPENHOI_WIN_MISC",
	order = 130,
	group = "OPENHOI_WIN_GROUP_SETUP",
	group_order = 10,

	Collect = function(player)
		return Kit.Gather("Misc", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		local source = Kit.Data("Misc")
		ImGui.TextDisabled(tostring(answer.tag))

		ImGui.SeparatorText(L("OPENHOI_WIN_MISC_DECISIONS"))
		switch("misc_trade", "OPENHOI_WIN_MISC_HIDE_TRADE", answer.tradeHidden, source.SetTradeHidden)
		switch("misc_mines", "OPENHOI_WIN_MISC_HIDE_MINES", answer.minesHidden, source.SetMinesHidden)
		ImGui.TextWrapped(L("OPENHOI_WIN_MISC_HELP"))
	end,
}
