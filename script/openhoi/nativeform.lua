-- What the AI settings pages share where they are windows of the game's own interface on OpenHOI3 (Prod. Sliders
-- AI and LS Sliders AI under script/openhoi/windows/country_info): the form of script/openhoi/pageform.lua, its
-- values edited in the window and sent to the game only by Apply, over OpenHOI3.Gui in place of OpenHOI3.ImGui.
--
-- Not a page itself; a page takes it with  local Native = require('openhoi/nativeform').
--
-- The window is expected to have, by name: the buttons enable, apply and reload, and the texts state, tag and
-- message. A number is an edit box; a tick is a button that shows an X while it is on.

local Gui = OpenHOI3.Gui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')
local Form = require('openhoi/pageform')

local Native = {}

-- A number as its box shows it: whole where it is whole.
local function shown(value, decimals)
	value = tonumber(value) or 0
	if (decimals or 0) > 0 then
		return string.format("%." .. decimals .. "f", value)
	end
	return string.format("%d", math.floor(value + 0.5))
end

-- A value as a box of whole numbers holds it: rounded to the nearest.
function Native.Whole(value)
	return math.floor((tonumber(value) or 0) + 0.5)
end

-- An edit box of the form: values[field]. What is typed is taken as it is typed - made whole where the box has no
-- decimals - else the box shows the value.
function Native.Number(form, element, values, field, decimals)
	if Gui.Edited(element) then
		local typed = tonumber(Gui.Text(element)) or 0
		if (decimals or 0) <= 0 then
			typed = Native.Whole(typed)
		end
		values[field] = typed
		Form.Edited(form)
	else
		Gui.SetText(element, shown(values[field], decimals))
	end
end

-- A tick of the form: values[field], true or false. A press turns it over.
function Native.Check(form, element, values, field)
	if Gui.Pressed(element) then
		values[field] = not values[field]
		Form.Edited(form)
	end
	Gui.SetText(element, values[field] and "X" or "")
end

-- Whether there is a form to fill: the mod's data is loaded and answered. Where not, the message says why.
function Native.Ready(form, data)
	if data == nil then
		return false
	end
	if data.missing then
		Gui.SetText("message", L("OPENHOI_WIN_NO_DATA"))
		return false
	end
	local answer = data.answer
	if answer == nil or answer.available == false then
		Gui.SetText("message", tostring(answer and answer.reason or L("OPENHOI_WIN_UNAVAILABLE")))
		return false
	end
	return form.values ~= nil
end

-- The form's own row: Enable or Disable with the state, Apply, Reload, the country, and what became of the last
-- Apply. fields() answers the list of { field, value } to send, in the page's order.
function Native.Top(form, fields)
	local active, waiting = Kit.Shown(form.key, form.active and true or false)
	Gui.SetText("enable", L(active and "OPENHOI_WIN_FORM_DISABLE" or "OPENHOI_WIN_FORM_ENABLE"))
	if Gui.Pressed("enable") then
		if active then
			Kit.Pend(form.key, false)
			Kit.Ask(function() Kit.Data(form.name).SetActive(0) end)
		else
			local list = fields()
			Kit.Ask(function()
				if Form.Apply(form, list) then
					Kit.Pend(form.key, true)
					Kit.Data(form.name).SetActive(1)
				end
			end)
		end
	end
	local state = L(active and "OPENHOI_WIN_FORM_ACTIVE" or "OPENHOI_WIN_FORM_INACTIVE")
	if waiting then
		Gui.SetText("state", state .. " ...")
	elseif active then
		Gui.SetText("state", "\167G" .. state .. "\167W")
	else
		Gui.SetText("state", state)
	end

	if Gui.Pressed("apply") then
		local list = fields()
		Kit.Ask(function() Form.Apply(form, list) end)
	end
	if Gui.Pressed("reload") then
		form.reload = true
		form.result = nil
		OpenHOI3.Refresh()
	end
	Gui.SetTooltip("reload", L("OPENHOI_WIN_FORM_RELOAD_TIP"))
	Gui.SetText("tag", tostring(form.tag or ""))

	local message = ""
	if form.result ~= nil then
		if form.result.ok then
			message = "\167G" .. L(form.result.corrected and "OPENHOI_WIN_FORM_CORRECTED" or "OPENHOI_WIN_FORM_APPLIED") .. "\167W"
		else
			message = "\167R" .. tostring(form.result.reason) .. "\167W"
		end
	elseif form.edited then
		message = "\167Y" .. L("OPENHOI_WIN_FORM_EDITED") .. "\167W"
	elseif not form.configured then
		message = "\167Y" .. L("OPENHOI_WIN_FORM_NEVER") .. "\167W"
	end
	Gui.SetText("message", message)
end

return Native
