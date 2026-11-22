-- The Help tab's National Focus page: what each of the mod's seven national focuses gives at each of its three
-- tiers, a row a focus and a column a tier.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.NatFocus.Effects, which reads the mod's
-- modifier files. That takes a moment, so it is read when Load is pressed and kept.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- What was read: the focuses in the data's order, each with its name and its effects by tier, and the tiers' labels.
local focuses = nil
local labels = {}
local failed = nil
local load = false

local function read(source)
	local answer = source.Effects()
	if answer.available == false then
		failed = tostring(answer.reason or L("OPENHOI_WIN_UNAVAILABLE"))
		return
	end
	failed = nil
	focuses = {}
	local byKey = {}
	for _, row in ipairs(answer.rows or {}) do
		local focus = byKey[row.key]
		if focus == nil then
			focus = { name = row.name, tiers = { {}, {}, {} } }
			byKey[row.key] = focus
			focuses[#focuses + 1] = focus
		end
		-- A tier that is none of the three is passed over.
		if focus.tiers[row.tier] ~= nil then
			table.insert(focus.tiers[row.tier], tostring(row.label) .. "  " .. tostring(row.value))
		end
	end
	labels = answer.tierLabels or {}
end

return {
	title = "OPENHOI_WIN_NATFOCUS",
	order = 30,
	group = "OPENHOI_WIN_GROUP_HELP",
	group_order = 70,

	Collect = function(player)
		return Kit.Gather("NatFocus", function(source)
			if load then
				load = false
				read(source)
			end
			return { answer = { available = true } }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		if focuses == nil then
			if ImGui.Button(L("OPENHOI_WIN_HELP_LOAD")) then
				load = true
				OpenHOI3.Refresh()
			end
			ImGui.SameLine()
			ImGui.TextDisabled(failed or L("OPENHOI_WIN_HELP_LOAD_NOTE"))
			return
		end

		ImGui.TextWrapped(L("OPENHOI_WIN_HELP_NATFOCUS"))
		local numerals = { "I", "II", "III" }
		if ImGui.BeginChild("focuses", 0, 0) then
			if ImGui.BeginTable("tiers", 4) then
				ImGui.TableSetupColumn(L("OPENHOI_WIN_NATFOCUS_FOCUS"), 160)
				for tier = 1, 3 do
					ImGui.TableSetupColumn(Kit.Filled("OPENHOI_WIN_HELP_LEVEL", { N = numerals[tier], LABEL = tostring(labels[tier] or "") }))
				end
				ImGui.TableHeadersRow()
				for _, focus in ipairs(focuses) do
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(tostring(focus.name))
					for tier = 1, 3 do
						ImGui.TableNextColumn()
						if #focus.tiers[tier] == 0 then
							ImGui.TextDisabled("-")
						else
							for _, line in ipairs(focus.tiers[tier]) do
								ImGui.Text(line)
							end
						end
					end
				end
				ImGui.EndTable()
			end
		end
		ImGui.EndChild()
	end,
}
