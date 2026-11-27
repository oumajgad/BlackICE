-- The Engine Fixes page: every fix of OpenHOI3's enhanced mode with a tick box that switches it on or off in the game
-- being played.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); the original never opens
-- it, and there is nothing like it there. It is for trying a fix against the game without it: a tick changes the
-- running game's rules through an order of the engine's, OpenHOI3.SetFix(name, on), and the change is saved with
-- the game. common/openhoi_enhanced.txt is untouched - it says what a NEW game starts with.
--
-- OpenHOI3.Rules() answers, where a game is on:
--   enhanced      whether the game is an enhanced one; a faithful game has no fixes
--   may_change    whether this machine may switch one: between several machines only the host's may
--   fixes         every fix in the order of the names: { name, on, at_load } - at_load marks a fix that acts only as
--                 the files are read, which a running game cannot switch
--
-- It stands under the Debug tab by its group, below. Its folder is not called "debug" because the repository's
-- .gitignore leaves every folder of that name out.
--
-- Every text comes from the localisation (localisation/openhoi/windows.csv), through OpenHOI3.Localise. A fix is
-- named as the engine and common/openhoi_enhanced.txt name it, and described by the text OPENHOI_FIX_<NAME> where
-- the localisation has one.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The page's own state, kept between frames.
local state = {}        -- what is typed into the filter
local asked = {}        -- a fix just ticked and not yet seen changed: its name -> what was asked for

-- What a fix does, in a line: the localisation's text for it, or nothing where there is none.
local function Description(name)
	local key = "OPENHOI_FIX_" .. string.upper(name)
	local text = L(key)
	if text == nil or text == key then
		return ""
	end
	return text
end

local function Row(fix, may_change)
	-- What was asked for stands until the game is seen to have it.
	local on = fix.on
	if asked[fix.name] ~= nil then
		if asked[fix.name] == fix.on then
			asked[fix.name] = nil
		else
			on = asked[fix.name]
		end
	end

	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.BeginDisabled(fix.at_load or not may_change)
	local changed, ticked = ImGui.Checkbox("##" .. fix.name, on)
	ImGui.EndDisabled()
	if changed and OpenHOI3.SetFix(fix.name, ticked) then
		asked[fix.name] = ticked
	end
	ImGui.TableNextColumn()
	ImGui.Text(fix.name)
	ImGui.TableNextColumn()
	if fix.at_load then
		ImGui.TextDisabled(L("OPENHOI_WIN_FIXES_AT_LOAD"))
	end
	local description = Description(fix.name)
	if description ~= "" then
		ImGui.TextWrapped(description)
	end
end

return {
	title = "OPENHOI_WIN_FIXES",
	order = 20,
	group = "OPENHOI_WIN_GROUP_DEBUG",
	group_order = 80,

	Collect = function(player)
		Kit.RunAsked()
		return OpenHOI3.Rules()
	end,

	Draw = function(data, player)
		if data == nil then
			ImGui.TextDisabled(L("OPENHOI_WIN_FIXES_NO_GAME"))
			return
		end
		if not data.enhanced then
			ImGui.TextWrapped(L("OPENHOI_WIN_FIXES_FAITHFUL"))
			return
		end
		ImGui.TextWrapped(L("OPENHOI_WIN_FIXES_HELP"))
		if not data.may_change then
			ImGui.TextColored(1.0, 0.6, 0.2, 1.0, L("OPENHOI_WIN_FIXES_HOST_ONLY"))
		end

		local on = 0
		for _, fix in ipairs(data.fixes) do
			if fix.on then
				on = on + 1
			end
		end
		ImGui.Text(Kit.Filled("OPENHOI_WIN_FIXES_COUNT", { ON = on, ALL = #data.fixes }))
		Kit.FilterBox(state, 260)

		ImGui.BeginChild("fixes_list")
		if ImGui.BeginTable("fixes", 3) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_FIXES_COL_ON"), 40)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_FIXES_COL_NAME"), 230)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_FIXES_COL_WHAT"))
			ImGui.TableHeadersRow()
			for _, fix in ipairs(data.fixes) do
				if Kit.Matches(fix.name, state.filter) or Kit.Matches(Description(fix.name), state.filter) then
					Row(fix, data.may_change)
				end
			end
			ImGui.EndTable()
		end
		ImGui.EndChild()
	end,
}
