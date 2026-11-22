-- The National Focus page: which of the mod's seven national focuses is active - which the player sets here -
-- how many days each has been built up, the tier that gives and what the tier does.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.NatFocus. The focus is the variable
-- national_focus, set by the game's own command; the effects are read once from the mod's modifier files.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The effects of every focus at every tier, read once: effects[key][tier] is a list of { label, value }.
local effects = nil

local function readEffects(source)
	local answer = source.Effects()
	if answer.available == false then
		return
	end
	effects = {}
	for _, row in ipairs(answer.rows or {}) do
		effects[row.key] = effects[row.key] or {}
		effects[row.key][row.tier] = effects[row.key][row.tier] or {}
		table.insert(effects[row.key][row.tier], { label = row.label, value = row.value })
	end
end

-- A focus's effects at a tier on one line, and every tier's as a tooltip.
local function effectLine(key, tier)
	local list = effects and effects[key] and effects[key][tier]
	if list == nil or #list == 0 then
		return "-"
	end
	local parts = {}
	for _, effect in ipairs(list) do
		parts[#parts + 1] = tostring(effect.label) .. " " .. tostring(effect.value)
	end
	return table.concat(parts, ", ")
end

local function effectTip(name, key, tier)
	local lines = { tostring(name) }
	for index = 1, 3 do
		local list = effects and effects[key] and effects[key][index]
		if list ~= nil and #list > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = Kit.Filled("OPENHOI_WIN_NATFOCUS_TIER_N", { N = index })
				.. (index == tier and (" " .. L("OPENHOI_WIN_NATFOCUS_TIER_ACTIVE")) or "")
			for _, effect in ipairs(list) do
				lines[#lines + 1] = "  " .. tostring(effect.label) .. "  " .. tostring(effect.value)
			end
		end
	end
	return table.concat(lines, "\n")
end

return {
	title = "OPENHOI_WIN_NATFOCUS",
	order = 80,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Kit.Gather("NatFocus", function(source)
			if effects == nil then
				readEffects(source)
			end
			return { answer = source.Collect() }
		end)
	end,

	Draw = function(data, player)
		if not Kit.Ready(data, data and data.answer) then
			return
		end
		local answer = data.answer
		local source = Kit.Data("NatFocus")
		ImGui.TextDisabled(tostring(answer.tag))
		ImGui.TextWrapped(L("OPENHOI_WIN_NATFOCUS_HELP"))

		local active, waiting = Kit.Shown("natfocus", math.floor(answer.active or 0))
		local function set(index)
			Kit.Pend("natfocus", index)
			Kit.Ask(function() source.Set(index) end)
		end

		local name = L("OPENHOI_WIN_NATFOCUS_NONE")
		if active > 0 then
			name = L("OPENHOI_WIN_NATFOCUS_UNKNOWN")
			for _, row in ipairs(answer.rows or {}) do
				if row.index == active then
					name = tostring(row.name)
				end
			end
		end
		ImGui.Text(L("OPENHOI_WIN_NATFOCUS_CURRENT"))
		ImGui.SameLine()
		Kit.PendingText(name, waiting)
		ImGui.SameLine()
		ImGui.BeginDisabled(active <= 0)
		if ImGui.SmallButton(L("OPENHOI_WIN_NATFOCUS_CLEAR")) then
			set(0)
		end
		ImGui.EndDisabled()

		if ImGui.BeginTable("focuses", 6) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_NATFOCUS_FOCUS"), 170)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_NATFOCUS_DAYS"), 60)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_NATFOCUS_TIER"), 50)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_NATFOCUS_NEXT"), 150)
			ImGui.TableSetupColumn(L("OPENHOI_WIN_NATFOCUS_EFFECT"))
			ImGui.TableSetupColumn("##set", 70)
			ImGui.TableHeadersRow()
			for _, row in ipairs(answer.rows or {}) do
				local days = math.max(row.days or 0, 0)
				local tier = row.tier or 0
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				if row.index == active then
					Kit.Coloured(Kit.SUCCESS, tostring(row.name))
				else
					ImGui.Text(tostring(row.name))
				end
				ImGui.TableNextColumn()
				ImGui.Text(string.format("%d", days))
				ImGui.TableNextColumn()
				ImGui.Text(string.format("%d", tier))
				ImGui.TableNextColumn()
				if (row.nextTier or 0) <= 0 then
					ImGui.TextDisabled(L("OPENHOI_WIN_NATFOCUS_MAX"))
				else
					ImGui.ProgressBar(math.min(1, days / row.nextTier), 0, string.format("%d / %d", days, row.nextTier))
				end
				ImGui.TableNextColumn()
				if tier <= 0 then
					ImGui.TextDisabled(L("OPENHOI_WIN_NATFOCUS_BELOW"))
				else
					ImGui.Text(effectLine(row.key, tier))
				end
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip(effectTip(row.name, row.key, tier))
				end
				ImGui.TableNextColumn()
				if row.index == active then
					ImGui.TextDisabled(waiting and "..." or L("OPENHOI_WIN_NATFOCUS_ACTIVE"))
				else
					ImGui.PushID(tostring(row.key))
					if ImGui.SmallButton(L("OPENHOI_WIN_NATFOCUS_SET")) then
						set(row.index)
					end
					ImGui.PopID()
				end
			end
			ImGui.EndTable()
		end
	end,
}
