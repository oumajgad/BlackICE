-- The Units page: every unit type's figures with the technologies that improve it applied, and a what-if: each
-- technology's level can be raised or lowered to see the figures and the unit's model string that result.
-- Nothing in the game changes; the assumed levels are the mod's own, kept while the game runs.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); traits.lua beside this
-- file explains the shape. The data is the mod's own, shared with the overlay on the original engine:
-- BiceLibGui.Units.
--
-- The data functions keep the unit chosen and the assumed levels themselves, and ask the game for the levels
-- researched. So what a button asks for is noted while drawing and done in Collect, which may read the game.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local list = {}
local techs = {}

-- What the last press asks of the data, done at the next Collect: { kind = "select" | "change" | "reset", ... }.
local asked = nil
-- The unit's figures as the data last answered them, kept between two gatherings.
local unit = nil

local WARNING = { 1.0, 0.75, 0.3, 1.0 }

local function ask(what)
	asked = what
	OpenHOI3.Refresh()
end

-- The technology of a row "<level> - Name [key]" found again in a new list: the first row holding its key.
local function sameTech(rows, key)
	for _, row in ipairs(rows) do
		if string.find(row, "[" .. key .. "]", 1, true) then
			return row
		end
	end
	return nil
end

return {
	title = "OPENHOI_WIN_UNITS",
	order = 90,
	group = "OPENHOI_WIN_GROUP_GAME",
	group_order = 30,

	Collect = function(player)
		local source = Kit.Data("Units")
		if source == nil then
			return { missing = true }
		end
		if asked ~= nil then
			if asked.kind == "select" then
				unit = source.Select(asked.choice)
			elseif asked.kind == "change" then
				unit = source.ChangeTechLevel(asked.tech, asked.delta)
			elseif asked.kind == "reset" then
				unit = source.ResetTechLevels()
			end
			asked = nil
		end

		-- The technologies as rows - the data's labels, "<assumed level> - Name [key]" - and each row's technology.
		local rows, byRow = {}, {}
		if unit ~= nil and unit.available ~= false and unit.techs ~= nil then
			for _, tech in ipairs(unit.techs) do
				local row = tostring(tech.label)
				rows[#rows + 1] = row
				byRow[row] = tech
			end
		end
		-- After a level changed the rows are new texts: the technology chosen is found again by its key.
		if techs.key ~= nil then
			techs.selected = sameTech(rows, techs.key)
		end
		local tech = techs.selected and byRow[techs.selected] or nil
		return {
			list = source.Collect(),
			unit = unit,
			rows = rows,
			tech = tech,
			techDetails = tech and source.TechDetails(tech.label) or nil,
		}
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end
		if data.missing then
			ImGui.TextDisabled(L("OPENHOI_WIN_NO_DATA"))
			return
		end
		if not Kit.Available(data.list) then
			return
		end
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_UNITS_COUNT", { N = #data.list.units }))

		Kit.BeginPanes("unit_panes", 300)
		if Kit.FilteredList("units", list, data.list.units, 0, 0) then
			techs.selected, techs.key = nil, nil
			ask({ kind = "select", choice = list.selected })
		end
		Kit.NextPane()
		if ImGui.BeginChild("unit", 0, 0) then
			if list.selected == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_UNITS_SELECT"))
			elseif asked ~= nil or data.unit == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			elseif Kit.Available(data.unit) then
				ImGui.Text(data.unit.key)
				-- The model string, in a box so that it can be selected, and a button that copies it.
				local model = tostring(data.unit.model or "")
				ImGui.SetNextItemWidth(-140)
				ImGui.InputText(L("OPENHOI_WIN_UNITS_MODEL"), model)
				ImGui.SameLine()
				if ImGui.Button(L("OPENHOI_WIN_COPY")) then
					ImGui.SetClipboardText(model)
				end
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip(L("OPENHOI_WIN_UNITS_COPY_TIP"))
				end

				local _, height = ImGui.GetContentRegionAvail()
				ImGui.SeparatorText(L("OPENHOI_WIN_UNITS_STATS"))
				Kit.TextBox("stats", data.unit.stats, math.max(80, height * 0.45))

				ImGui.SeparatorText(L("OPENHOI_WIN_UNITS_TECHS"))
				if #data.rows == 0 then
					ImGui.TextDisabled(L("OPENHOI_WIN_UNITS_NO_TECHS"))
				else
					local tech = data.tech
					ImGui.BeginDisabled(tech == nil)
					if ImGui.SmallButton("-") and tech ~= nil and tech.level > 0 then
						ask({ kind = "change", tech = tech.label, delta = -1 })
					end
					ImGui.SameLine()
					if ImGui.SmallButton("+") and tech ~= nil then
						ask({ kind = "change", tech = tech.label, delta = 1 })
					end
					ImGui.EndDisabled()
					ImGui.SameLine()
					if ImGui.SmallButton(L("OPENHOI_WIN_UNITS_RESET_ALL")) then
						ask({ kind = "reset" })
					end
					ImGui.SameLine()
					local details = data.techDetails
					if tech == nil or details == nil or details.available == false then
						ImGui.TextDisabled(L("OPENHOI_WIN_UNITS_SELECT_TECH"))
					elseif details.level ~= details.researched then
						ImGui.TextColored(WARNING[1], WARNING[2], WARNING[3], WARNING[4], Kit.Filled("OPENHOI_WIN_UNITS_ASSUMED",
							{ KEY = details.key, LEVEL = details.level, RESEARCHED = details.researched }))
					else
						ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_UNITS_AS_RESEARCHED", { KEY = details.key, LEVEL = details.level }))
					end

					Kit.BeginPanes("unittech_panes", 320)
					if Kit.FilteredList("unittechs", techs, data.rows, 0, 0) then
						-- Kept by its key, the row's text changing with its level.
						techs.key = string.match(techs.selected, ".*%[(.-)%]")
						OpenHOI3.Refresh()
					end
					Kit.NextPane()
					if ImGui.BeginChild("unittech", 0, 0) then
						if details == nil then
							ImGui.TextDisabled(L("OPENHOI_WIN_TECHS_SELECT"))
						elseif Kit.Available(details) then
							if details.applied == false then
								ImGui.TextColored(WARNING[1], WARNING[2], WARNING[3], WARNING[4], L("OPENHOI_WIN_UNITS_NOT_APPLIED"))
							end
							Kit.TextBox("techeffects", details.effects, -1)
						end
					end
					ImGui.EndChild()
					Kit.EndPanes()
				end
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
