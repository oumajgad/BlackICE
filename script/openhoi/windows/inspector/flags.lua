-- The Active Flags page: every flag the player's country holds, by name, with a filter.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). OpenHOI3 lists
-- script/openhoi/windows/ and its subfolders and takes every file there as a page; the original never opens them.
-- The folders are a folder a tab, for our own order: the tab a page stands under is its group, below. The Insert
-- key shows the utility window: a tab for each group of pages, the tab's pages listed down its left side. The file
-- returns a table:
--   title        the localisation key of the page's name, in its tab's list of pages
--   order        its place in that list, lower first
--   group        the localisation key of the tab it stands under; pages naming the same key share a tab
--   group_order  where that tab stands among the tabs, lower first (the lowest any of its pages gives):
--                Setup 10, Country Info 20, Game Info 30, Inspector 40, Stats 50, Options 60, Help 70, Debug 80
--   Collect  reads the game and answers whatever the page will show. Called when the page opens and every two
--            seconds while it is open - never while the game is working through its hours.
--   Draw     draws the page from what Collect answered, with OpenHOI3.ImGui. Called every frame. It is given no
--            game to ask: anything of the game it needs, Collect has to have put into the data.
--
-- Every text comes from the localisation (localisation/openhoi/windows.csv), through OpenHOI3.Localise.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
-- What the pages share (script/openhoi/pagekit.lua). Here only for the country chosen on the Setup tab.
local Kit = require('openhoi/pagekit')

-- The page's own state, kept between frames: what is typed into the filter.
local filter = ""

return {
	title = "OPENHOI_WIN_FLAGS",
	order = 20,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		-- The country chosen on the Setup tab's Country page, which is the one played until another is chosen.
		player = Kit.Selected(player)
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
