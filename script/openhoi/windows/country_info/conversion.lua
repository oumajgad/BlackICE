-- The Resource Conversion page: the player's own say in turning energy into crude oil and crude oil into fuel.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode; inspector/flags.lua is the commented example
-- of how a page is written (docs/openhoi/README.md). This one is the example of a page that changes the game.
--
-- On OpenHOI3 the conversion is a setting of the country's own, kept by the engine and in its save - not the
-- zzDsafe_... country variables BiceLib reads on the original. A page reads it with OpenHOI3.Conversion(tag) and
-- changes it with OpenHOI3.SetConversion(tag, which, own, per_day, keep, target), which is an order like any the
-- player gives: it may be given while drawing, and takes effect when the game next runs its orders.
--
-- The page keeps what is typed until Apply is pressed, so half a number is never sent.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise

-- What is being edited, for each of the two conversions: "energy" and "crude_oil".
local edits = {}

-- How long after Apply the page goes on showing what was sent, in seconds, while the game takes the order.
local SETTLE = 1.0

local WARNING = { 1.0, 0.75, 0.3, 1.0 }

local function whole(number)
	return math.floor((tonumber(number) or 0) + 0.5)
end

-- A text with its $NAME$ places filled in.
local function filled(key, values)
	local text = L(key)
	for name, value in pairs(values) do
		text = string.gsub(text, "%$" .. name .. "%$", function() return tostring(value) end)
	end
	return text
end

local function tooltip(key)
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip(L(key))
	end
end

-- One number of a setting, with its label and tooltip. Never below nought.
local function number(edit, field, label, tip)
	ImGui.SetNextItemWidth(180)
	local changed, value = ImGui.InputInt(L(label), edit[field])
	if changed then
		edit[field] = math.max(0, value)
		edit.dirty = true
	end
	tooltip(tip)
end

-- One conversion: the checkbox, its three numbers and Apply.
local function section(player, which, setting, texts)
	local edit = edits[which]
	local settling = edit ~= nil and edit.sent ~= nil and os.clock() - edit.sent < SETTLE
	if edit == nil or not (edit.dirty or settling) then
		-- Nothing typed and nothing on its way: show what the game holds.
		edit = {
			own = setting.own,
			per_day = whole(setting.per_day),
			keep = whole(setting.keep),
			target = whole(setting.target),
			dirty = false,
		}
		edits[which] = edit
	end

	ImGui.SeparatorText(L(texts.title))
	ImGui.PushID(which)

	local changed, ticked = ImGui.Checkbox(L("OPENHOI_WIN_CONV_OWN"), edit.own)
	if changed then
		edit.own = ticked
		edit.dirty = true
	end
	tooltip(texts.own_tip)

	ImGui.BeginDisabled(not edit.own)
	number(edit, "per_day", texts.per_day, texts.per_day_tip)
	number(edit, "keep", "OPENHOI_WIN_CONV_KEEP", texts.keep_tip)
	number(edit, "target", texts.target, texts.target_tip)
	ImGui.EndDisabled()

	ImGui.BeginDisabled(not edit.dirty)
	if ImGui.Button(L("OPENHOI_WIN_APPLY")) then
		OpenHOI3.SetConversion(player, which, edit.own, edit.per_day, edit.keep, edit.target)
		edit.dirty = false
		edit.sent = os.clock()
	end
	ImGui.EndDisabled()

	ImGui.PopID()
end

return {
	title = "OPENHOI_WIN_CONV",
	order = 55,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return OpenHOI3.Conversion(player)
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end

		ImGui.TextDisabled(filled("OPENHOI_WIN_CONV_HELD", {
			ENERGY = whole(data.energy), CRUDE = whole(data.crude_oil), FUEL = whole(data.fuel),
		}))

		section(player, "energy", data.energy_conversion, {
			title = "OPENHOI_WIN_CONV_ENERGY",
			own_tip = "OPENHOI_WIN_CONV_ENERGY_OWN_TIP",
			per_day = "OPENHOI_WIN_CONV_ENERGY_PER_DAY",
			per_day_tip = "OPENHOI_WIN_CONV_ENERGY_PER_DAY_TIP",
			keep_tip = "OPENHOI_WIN_CONV_ENERGY_KEEP_TIP",
			target = "OPENHOI_WIN_CONV_ENERGY_TARGET",
			target_tip = "OPENHOI_WIN_CONV_ENERGY_TARGET_TIP",
		})
		if data.oil_rate <= 0 then
			-- BlackICE keeps this conversion shut until a synthetic industry is developed.
			-- A short line in the warning colour, and the long explanation wrapped to the window below it.
			ImGui.TextColored(WARNING[1], WARNING[2], WARNING[3], WARNING[4], L("OPENHOI_WIN_CONV_ENERGY_SHUT_TITLE"))
			ImGui.TextWrapped(filled("OPENHOI_WIN_CONV_ENERGY_SHUT", { RATE = string.format("%.2f", data.oil_rate) })
				.. " " .. L("OPENHOI_WIN_CONV_ENERGY_SHUT_HOW"))
		else
			ImGui.TextDisabled(filled("OPENHOI_WIN_CONV_ENERGY_TODAY", {
				CAP = string.format("%.2f", data.energy_cap),
				RATE = string.format("%.2f", data.oil_rate),
				FLOOR = whole(data.energy_floor),
			}))
		end

		section(player, "crude_oil", data.crude_oil_conversion, {
			title = "OPENHOI_WIN_CONV_CRUDE",
			own_tip = "OPENHOI_WIN_CONV_CRUDE_OWN_TIP",
			per_day = "OPENHOI_WIN_CONV_CRUDE_PER_DAY",
			per_day_tip = "OPENHOI_WIN_CONV_CRUDE_PER_DAY_TIP",
			keep_tip = "OPENHOI_WIN_CONV_CRUDE_KEEP_TIP",
			target = "OPENHOI_WIN_CONV_CRUDE_TARGET",
			target_tip = "OPENHOI_WIN_CONV_CRUDE_TARGET_TIP",
		})
		ImGui.TextDisabled(filled("OPENHOI_WIN_CONV_CRUDE_TODAY", { CAP = whole(data.crude_cap) }))

		ImGui.Spacing()
		ImGui.TextWrapped(L("OPENHOI_WIN_CONV_NOTE"))
	end,
}
