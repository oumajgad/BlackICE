-- The Unit Models page: the player's country's unit models, and for a chosen one the technology levels it asks
-- beside the levels the country has.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); traits.lua beside this
-- file explains the shape. The data is the mod's own, shared with the overlay on the original engine:
-- BiceLibGui.UnitModels, which reads units/models and asks the game for the levels researched.
--
-- Below the levels stands the sprite file the game would use for the model, drawn to fit the pane or at a zoom
-- of the player's choosing.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local list = {}

-- The sprite's zoom, shared by all models: fitted to the pane's width, or one of the steps.
local ZOOMS = { 0.5, 1, 2, 3, 4, 6, 8 }
local fit = true
local zoom = 2

-- The sprite of a model: the zoom buttons, a line of its size, and the picture.
local function sprite(path, status)
	local width, height = ImGui.ImageSize(path)
	if width <= 0 or height <= 0 then
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_UNITMODELS_NO_LOAD", { PATH = path }))
		return
	end
	if ImGui.SmallButton("-") then
		fit = false
		zoom = math.max(1, zoom - 1)
	end
	ImGui.SameLine()
	if ImGui.SmallButton("+") then
		fit = false
		zoom = math.min(#ZOOMS, zoom + 1)
	end
	ImGui.SameLine()
	if ImGui.SmallButton(L("OPENHOI_WIN_UNITMODELS_FIT")) then
		fit = true
	end
	ImGui.SameLine()
	if ImGui.SmallButton("1:1") then
		fit = false
		zoom = 2
	end

	-- Fitted: scaled down to the pane's width where it is wider, and never enlarged.
	local room = ImGui.GetContentRegionAvail()
	local scale = ZOOMS[zoom]
	if fit then
		scale = math.min(1, room / width)
	end
	ImGui.SameLine()
	ImGui.TextDisabled(string.format("%s%d%%  |  %dx%d  |  %s", fit and (L("OPENHOI_WIN_UNITMODELS_FIT") .. " ") or "",
		math.floor(scale * 100 + 0.5), width, height, tostring(status or "")))
	if ImGui.BeginChild("sprite", 0, 0) then
		ImGui.Image(path, width * scale, height * scale)
	end
	ImGui.EndChild()
end

local ERROR = { 0.85, 0.35, 0.35, 1.0 }

return {
	title = "OPENHOI_WIN_UNITMODELS",
	order = 100,
	group = "OPENHOI_WIN_GROUP_GAME",
	group_order = 30,

	Collect = function(player)
		player = Kit.Selected(player)
		local source = Kit.Data("UnitModels")
		if source == nil then
			return { missing = true }
		end
		local chosen = list.selected
		return {
			tag = player,
			list = source.Collect(),
			chosen = chosen,
			details = chosen and source.Details(chosen) or nil,
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
		ImGui.TextDisabled(data.tag)
		if not Kit.Available(data.list) then
			return
		end
		ImGui.SameLine()
		ImGui.TextDisabled("| " .. Kit.Filled("OPENHOI_WIN_UNITMODELS_COUNT", { N = #data.list.models }))

		Kit.BeginPanes("model_panes", 300)
		if Kit.FilteredList("models", list, data.list.models, 0, 0) then
			OpenHOI3.Refresh()
		end
		Kit.NextPane()
		if ImGui.BeginChild("model", 0, 0) then
			if list.selected == nil then
				ImGui.TextDisabled(L("OPENHOI_WIN_UNITMODELS_SELECT"))
			elseif data.chosen ~= list.selected then
				ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			elseif Kit.Available(data.details) then
				local details = data.details
				ImGui.Text(details.key)

				ImGui.SeparatorText(L("OPENHOI_WIN_UNITMODELS_REQUIRED"))
				if details.techs == nil or #details.techs == 0 then
					ImGui.TextDisabled(L("OPENHOI_WIN_UNITMODELS_NO_TECHS"))
				elseif ImGui.BeginTable("required", 3) then
					ImGui.TableSetupColumn(L("OPENHOI_WIN_UNITMODELS_TECH"))
					ImGui.TableSetupColumn(L("OPENHOI_WIN_UNITMODELS_NEEDS"))
					ImGui.TableSetupColumn(L("OPENHOI_WIN_UNITMODELS_HAS"))
					ImGui.TableHeadersRow()
					for _, tech in ipairs(details.techs) do
						local required = tonumber(tech.required) or 0
						local researched = tonumber(tech.researched) or 0
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						ImGui.Text(tostring(tech.label))
						ImGui.TableNextColumn()
						ImGui.Text(string.format("%d", required))
						ImGui.TableNextColumn()
						if researched < required then
							ImGui.TextColored(ERROR[1], ERROR[2], ERROR[3], ERROR[4], string.format("%d", researched))
						else
							ImGui.Text(string.format("%d", researched))
						end
					end
					ImGui.EndTable()
				end

				ImGui.SeparatorText(L("OPENHOI_WIN_UNITMODELS_SPRITE"))
				if details.image_path ~= nil and details.image_path ~= "" then
					sprite(tostring(details.image_path), details.image_status)
				else
					ImGui.TextDisabled(tostring(details.image_status or L("OPENHOI_WIN_NONE")))
				end
			end
		end
		ImGui.EndChild()
		Kit.EndPanes()
	end,
}
