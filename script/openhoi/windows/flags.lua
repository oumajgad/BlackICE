-- The Active Flags page: every flag the player's country holds, by name, with a filter.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). OpenHOI3 lists
-- script/openhoi/windows/ and takes every file there as a page; the original never opens this folder. The Insert
-- key shows the menu of pages. The file returns a table:
--   title    the localisation key of the page's name, on the menu and on its window
--   order    its place on the menu, lower first
--   Collect  reads the game and answers whatever the page will show. Called when the page opens and every two
--            seconds while it is open - never while the game is working through its hours.
--   Draw     draws the page from what Collect answered, with OpenHOI3.ImGui. Called every frame. It is given no
--            game to ask: anything of the game it needs, Collect has to have put into the data.
--
-- Every text comes from the localisation (localisation/openhoi/windows.csv), through OpenHOI3.Localise.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise

-- The page's own state, kept between frames: what is typed into the filter.
local filter = ""

return {
	title = "OPENHOI_WIN_FLAGS",
	order = 20,

	Collect = function(player)
		return {
			tag = player,
			-- Sorted by name by the engine; a flag that was set and cleared again is not among them.
			flags = OpenHOI3.CountryFlags(player),
		}
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end

		ImGui.Text(L("OPENHOI_WIN_FLAGS_COUNTRY") .. ": " .. data.tag)

		local changed, typed = ImGui.InputText(L("OPENHOI_WIN_FILTER"), filter)
		if changed then
			filter = typed
		end

		-- The rows the filter keeps: a flag whose name holds the text typed, whatever its case.
		local wanted = string.lower(filter)
		local shown = {}
		for _, name in ipairs(data.flags) do
			if wanted == "" or string.find(string.lower(name), wanted, 1, true) then
				shown[#shown + 1] = name
			end
		end
		ImGui.SameLine()
		ImGui.TextDisabled(#shown .. "/" .. #data.flags)

		if ImGui.BeginTable("flags", 1) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_NAME"))
			ImGui.TableHeadersRow()
			for _, name in ipairs(shown) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(name)
			end
			ImGui.EndTable()
		end
	end,
}
