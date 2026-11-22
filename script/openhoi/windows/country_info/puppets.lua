-- The Puppets page: the country's puppets with the production focus of each, which the player sets here, and
-- whether the in-game decision for setting it is offered.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Puppets, which also keeps which puppet the
-- buttons act on. A focus is the variable puppet_focus_variable of the puppet, set by the game's own command.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

return {
	title = "OPENHOI_WIN_PUPPETS",
	order = 40,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		player = Kit.Selected(player)
		return Kit.Gather("Puppets", function(source)
			return { tag = player, answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		local source = Kit.Data("Puppets")
		ImGui.TextDisabled(data.tag)

		ImGui.SeparatorText(L("OPENHOI_WIN_PUPPETS_DECISION"))
		local offered, offering = Kit.Shown("puppets_decision", answer.decision_enabled and true or false)
		local changed, ticked = ImGui.Checkbox(L("OPENHOI_WIN_PUPPETS_OFFERED"), offered)
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_PUPPETS_OFFERED_TIP"))
		end
		if changed then
			Kit.Pend("puppets_decision", ticked)
			Kit.Ask(function() source.SetDecisionEnabled(ticked and 1 or 0) end)
		end
		if offering then
			ImGui.SameLine()
			Kit.Coloured(Kit.WARNING, L("OPENHOI_WIN_PENDING"))
		end

		ImGui.SeparatorText(L("OPENHOI_WIN_PUPPETS_VASSALS"))
		local puppets = answer.puppets or {}
		if #puppets == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_PUPPETS_NONE"))
			return
		end

		-- The focus of the puppet acted on, as a number: the one asked for while it is on its way.
		local acted = answer.selected or ""
		local focus, changing = Kit.Shown("puppets_focus_" .. acted, answer.selected_focus or 0)
		local names = answer.focus_names or {}

		if ImGui.BeginTable("puppets", 2) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PUPPETS_PUPPET"))
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PUPPETS_FOCUS"))
			ImGui.TableHeadersRow()
			for _, puppet in ipairs(puppets) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				if ImGui.Selectable(tostring(puppet.tag), puppet.tag == acted) then
					local tag = puppet.tag
					Kit.Ask(function() source.Select(tag) end)
				end
				ImGui.TableNextColumn()
				if puppet.tag == acted and changing then
					Kit.PendingText(tostring(names[focus] or names[8] or ""), true)
				else
					ImGui.Text(tostring(puppet.focus))
				end
			end
			ImGui.EndTable()
		end

		if acted == "" then
			ImGui.TextDisabled(L("OPENHOI_WIN_PUPPETS_SELECT"))
			return
		end
		ImGui.Text(Kit.Filled("OPENHOI_WIN_PUPPETS_SET", { TAG = acted }))
		if changing then
			ImGui.SameLine()
			Kit.Coloured(Kit.WARNING, L("OPENHOI_WIN_WAITING_SHORT"))
		end
		-- Any number that is none of the eight reads as the last, "None".
		if focus < 1 or focus > 8 then
			focus = 8
		end
		for index = 1, 8 do
			if index ~= 1 and index ~= 5 then
				ImGui.SameLine()
			end
			-- The focus it has is greyed: there is nothing to press.
			ImGui.BeginDisabled(index == focus)
			if ImGui.Button(tostring(names[index] or index) .. "##focus" .. index) then
				Kit.Pend("puppets_focus_" .. acted, index)
				Kit.Ask(function() source.SetFocus(index) end)
			end
			ImGui.EndDisabled()
		end
	end,
}
