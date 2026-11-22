-- The Country page: chooses the country every other page reports on and writes to, and lists the human players.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Country. The choice is the Lua global
-- G_PlayerCountry, as on the original: it is this machine's alone, is not saved, and nothing of it is sent to
-- the game. Until one is chosen the pages follow the country played.
--
-- The overlay's third section, "BiceLib setup", reports BiceLib's own daily job on the original engine. There is
-- no such job here, so the section is left out.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The tag being typed, and why the last choice was refused.
local typed = ""
local refused = nil

-- Chooses a country at the next Collect, where the game can be asked whether it is one.
local function select(tag)
	if tag == nil or tag == "" then
		return
	end
	refused = nil
	Kit.Ask(function()
		local answer = Kit.Data("Country").SelectPlayer(tag)
		if answer == nil or answer.available == false then
			refused = string.upper(tostring(tag)) .. ": " .. tostring(answer and answer.reason or L("OPENHOI_WIN_UNAVAILABLE"))
		end
	end)
end

return {
	title = "OPENHOI_WIN_SETUP_COUNTRY",
	order = 10,
	group = "OPENHOI_WIN_GROUP_SETUP",
	group_order = 10,

	Collect = function(player)
		return Kit.Gather("Country", function(source)
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer

		ImGui.SeparatorText(L("OPENHOI_WIN_SETUP_COUNTRY"))
		if answer.selected == nil or answer.selected == "" then
			ImGui.TextDisabled(L("OPENHOI_WIN_SETUP_NO_COUNTRY"))
		else
			ImGui.Text(Kit.Filled("OPENHOI_WIN_SETUP_SELECTED", { TAG = answer.selected }))
		end
		if answer.actual_player ~= nil and answer.actual_player ~= "" then
			ImGui.Text(Kit.Filled("OPENHOI_WIN_SETUP_PLAYING", { TAG = answer.actual_player }))
			ImGui.SameLine()
			if ImGui.SmallButton(L("OPENHOI_WIN_SETUP_SELECT")) then
				select(answer.actual_player)
			end
		end

		-- A tag typed in: upper case, and sent by Enter or by the button.
		ImGui.SetNextItemWidth(90)
		local changed, text = ImGui.InputText("##tag", typed, 8)
		if changed then
			typed = string.upper(text)
		end
		local entered = ImGui.IsItemDeactivatedAfterEdit() and ImGui.IsKeyPressed("Enter")
		ImGui.SameLine()
		local pressed = ImGui.Button(L("OPENHOI_WIN_SETUP_SET"))
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_SETUP_SET_TIP"))
		end
		ImGui.SameLine()
		ImGui.TextDisabled(L("OPENHOI_WIN_SETUP_TYPE"))
		if (entered or pressed) and typed ~= "" then
			select(typed)
		end
		if refused ~= nil then
			Kit.Coloured(Kit.WARNING, refused)
		end

		ImGui.SeparatorText(L("OPENHOI_WIN_SETUP_PLAYERS"))
		local players = answer.players or {}
		if ImGui.Button(L("OPENHOI_WIN_SETUP_GET_PLAYERS")) then
			Kit.Ask(function() Kit.Data("Country").RefreshPlayers() end)
		end
		ImGui.SameLine()
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_SETUP_FOUND", { N = #players }))
		if #players == 0 then
			ImGui.TextWrapped(L("OPENHOI_WIN_SETUP_PLAYERS_HELP"))
			return
		end
		for _, tag in ipairs(players) do
			if ImGui.Selectable(tostring(tag) .. "##player", tag == answer.selected) and tag ~= answer.selected then
				select(tag)
			end
		end
		ImGui.TextWrapped(L("OPENHOI_WIN_SETUP_PLAYERS_NOTE"))
	end,
}
