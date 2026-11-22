-- The IC Days page: the country's debt of IC days and the share of its base IC it pays the debt off with, which
-- the player sets here.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.ICDays. Setting the investment posts the
-- game's own command for the variable event_unit_investment, as the overlay does - noted while drawing and done
-- in Collect (pagekit.lua, "A page that changes something").

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local LEAST, MOST = 20, 90

-- The slider's place, and whether it is held: while it is not, it follows the game.
local slider = LEAST
local held = false

return {
	title = "OPENHOI_WIN_ICDAYS",
	order = 30,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Kit.Gather("ICDays", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		ImGui.TextDisabled(tostring(answer.tag))

		local investment, waiting = Kit.Shown("icdays", math.floor(answer.investment or 0))
		Kit.LabelTable("icdays", {
			{ L("OPENHOI_WIN_ICDAYS_LEFT"), string.format("%.2f", math.max(answer.ic_days_left or 0, 0)) },
			{ L("OPENHOI_WIN_ICDAYS_BASE"), string.format("%d", answer.base_ic or 0) },
			{ L("OPENHOI_WIN_ICDAYS_INVESTMENT"), function() Kit.PendingText(string.format("%d%%", investment), waiting) end },
			{ L("OPENHOI_WIN_ICDAYS_DAILY"), function()
				if waiting then
					ImGui.TextDisabled("...")
				else
					ImGui.Text(string.format("%d", answer.daily_reduction or 0))
				end
			end },
		})

		ImGui.SeparatorText(L("OPENHOI_WIN_ICDAYS_SET"))
		if not held then
			slider = math.max(LEAST, math.min(MOST, investment))
		end
		ImGui.SetNextItemWidth(260)
		local changed, value = ImGui.SliderInt("%##investment", slider, LEAST, MOST)
		if changed then
			slider = math.max(LEAST, math.min(MOST, value))
		end
		held = ImGui.IsItemActive()
		-- Sent once, as the slider is let go, and not while it is dragged.
		if ImGui.IsItemDeactivatedAfterEdit() then
			local wanted = slider
			Kit.Pend("icdays", wanted)
			Kit.Ask(function() Kit.Data("ICDays").SetInvestment(wanted) end)
		end
		ImGui.TextWrapped(L("OPENHOI_WIN_ICDAYS_HELP"))
	end,
}
