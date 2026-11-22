-- The Utility Options page: settings of this window itself - the key that opens it, its text size, its look and
-- where it stands. Nothing here changes the game.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The settings are the
-- window's own and OpenHOI3 keeps them: a page reads and sets them through OpenHOI3.Window while it draws. The
-- key and the look are remembered in openhoi_settings.txt; the text size is not.
--
-- What the overlay's Options tab holds besides, on the original engine, is elsewhere or not there on OpenHOI3:
-- scrolling at the screen's edge, where an event's window comes up and the two extra autosaves are rows of the
-- game's own options window; crash reports and the debug console are BiceLib's.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Window = OpenHOI3.Window
local Kit = require('openhoi/pagekit')

return {
	title = "OPENHOI_WIN_UTILOPT",
	order = 30,
	group = "OPENHOI_WIN_GROUP_OPTIONS",
	group_order = 60,

	Draw = function(data, player)
		ImGui.SeparatorText(L("OPENHOI_WIN_UTILOPT_WINDOW"))

		-- The key: a button named by it. Pressed, the next key pressed becomes it; Escape gives that up.
		ImGui.Text(L("OPENHOI_WIN_UTILOPT_KEY"))
		ImGui.SameLine()
		if Window.Capturing() then
			ImGui.BeginDisabled(true)
			ImGui.Button(L("OPENHOI_WIN_UTILOPT_PRESS"))
			ImGui.EndDisabled()
			ImGui.SameLine()
			if ImGui.Button(L("OPENHOI_WIN_CANCEL")) then
				Window.CancelCapture()
			end
		elseif ImGui.Button(Window.Key() .. "##key") then
			Window.CaptureKey()
		end
		ImGui.TextDisabled(L("OPENHOI_WIN_UTILOPT_KEY_HELP"))

		-- The text size, as a factor.
		ImGui.SetNextItemWidth(260)
		local changed, scale = ImGui.SliderFloat(L("OPENHOI_WIN_UTILOPT_SIZE"), Window.Scale(), 0.6, 2.0)
		if changed then
			Window.SetScale(scale)
		end
		ImGui.SameLine()
		if ImGui.Button(L("OPENHOI_WIN_RESET") .. "##size") then
			Window.SetScale(1)
		end

		if ImGui.Button(L("OPENHOI_WIN_UTILOPT_LAYOUT")) then
			Window.ResetLayout()
		end
		ImGui.SameLine()
		ImGui.TextDisabled(L("OPENHOI_WIN_UTILOPT_LAYOUT_NOTE"))

		ImGui.SeparatorText(L("OPENHOI_WIN_UTILOPT_THEME"))
		local now = Window.Theme()
		for _, theme in ipairs(Window.Themes()) do
			local key = "OPENHOI_WIN_UTILOPT_THEME_" .. string.upper(theme)
			if ImGui.Selectable(L(key) .. "##theme" .. theme, theme == now) and theme ~= now then
				Window.SetTheme(theme)
			end
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(L(key .. "_TIP"))
			end
		end

		ImGui.SeparatorText(L("OPENHOI_WIN_UTILOPT_GAME"))
		ImGui.TextWrapped(L("OPENHOI_WIN_UTILOPT_GAME_NOTE"))
	end,
}
