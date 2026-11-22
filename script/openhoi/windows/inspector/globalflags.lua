-- The Global Flags page: every flag the game itself holds, by name, with a filter.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode; flags.lua beside this file is the commented example
-- of how a page is written (docs/openhoi/README.md).

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise

local filter = ""

return {
	title = "OPENHOI_WIN_GLOBALFLAGS",
	order = 25,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		return { flags = OpenHOI3.GlobalFlags() }
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end

		local changed, typed = ImGui.InputText(L("OPENHOI_WIN_FILTER"), filter)
		if changed then
			filter = typed
		end

		local wanted = string.lower(filter)
		local shown = {}
		for _, name in ipairs(data.flags) do
			if wanted == "" or string.find(string.lower(name), wanted, 1, true) then
				shown[#shown + 1] = name
			end
		end
		ImGui.SameLine()
		ImGui.TextDisabled(#shown .. "/" .. #data.flags)

		if ImGui.BeginTable("globalflags", 1) then
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
