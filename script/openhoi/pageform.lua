-- What the three AI settings pages of the mod's own windows for OpenHOI3 share (Trade AI, Prod. Sliders AI, LS
-- Sliders AI under script/openhoi/windows/country_info): a form whose values are edited on the page and sent to
-- the game only by Apply.
--
-- Not a page itself; a page takes it with  local Form = require('openhoi/pageform').
--
-- Behind each form stand five data functions of the mod's own, shared with the overlay on the original engine
-- (BiceLibGui.<name>): Collect, SetValue(field, value), Discard, Commit and SetActive(n). Apply empties the
-- staging table, stages every field in the page's order, and commits, which posts the game's own command for
-- each variable. Enable applies first, so that the AI starts on what is on screen.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

local Form = {}

-- A form over the data table BiceLibGui.<name>.
function Form.New(name)
	return { name = name, key = "form_" .. name }
end

-- The form's Collect. The values are taken whole the first time, on Reload, and when the country is another;
-- otherwise only whether the AI is active and configured, so that what is being edited is left alone.
function Form.Gather(form)
	return Kit.Gather(form.name, function(source)
		local answer = source.Collect()
		if answer.available ~= false then
			if form.values == nil or form.reload or form.tag ~= answer.tag then
				form.values = answer
				form.tag = answer.tag
				form.reload = false
				form.edited = false
			end
			form.active = answer.active and true or false
			form.configured = answer.configured and true or false
		end
		return { answer = answer }
	end)
end

-- A value was changed on the page.
function Form.Edited(form)
	form.edited = true
	form.result = nil
end

-- Sends the fields to the game; run in Collect. Answers whether the game took them.
local function apply(form, fields)
	local source = Kit.Data(form.name)
	source.Discard()
	for _, field in ipairs(fields) do
		local staged = source.SetValue(field[1], field[2])
		if staged ~= nil and staged.ok == false then
			form.result = { ok = false, reason = staged.reason }
			return false
		end
	end
	local committed = source.Commit()
	if committed == nil or committed.ok ~= true then
		form.result = { ok = false, reason = committed and committed.reason or L("OPENHOI_WIN_UNAVAILABLE") }
		return false
	end
	local corrections = committed.corrections or {}
	if #corrections > 0 and form.correct ~= nil then
		form.correct(corrections)
	end
	form.result = { ok = true, corrected = #corrections > 0 }
	form.edited = false
	return true
end

-- A box a number of the form is typed into: values[field], to that many decimals.
function Form.Number(form, id, values, field, decimals, width)
	ImGui.SetNextItemWidth(width or -1)
	local changed, typed = ImGui.InputFloat("##" .. id, tonumber(values[field]) or 0, decimals or 0)
	if changed then
		values[field] = typed
		Form.Edited(form)
	end
end

-- A checkbox of the form: values[field], true or false.
function Form.Check(form, label, values, field)
	local changed, ticked = ImGui.Checkbox(label, values[field] and true or false)
	if changed then
		values[field] = ticked
		Form.Edited(form)
	end
end

-- The form's first rows: Enable or Disable with the state, Apply, Reload, the country, and what became of the
-- last Apply. fields() answers the list of { field, value } to send, in the page's order.
function Form.Top(form, fields)
	local active, waiting = Kit.Shown(form.key, form.active and true or false)
	if active then
		if ImGui.Button(L("OPENHOI_WIN_FORM_DISABLE")) then
			Kit.Pend(form.key, false)
			Kit.Ask(function() Kit.Data(form.name).SetActive(0) end)
		end
	elseif ImGui.Button(L("OPENHOI_WIN_FORM_ENABLE")) then
		local list = fields()
		Kit.Ask(function()
			if apply(form, list) then
				Kit.Pend(form.key, true)
				Kit.Data(form.name).SetActive(1)
			end
		end)
	end
	ImGui.SameLine()
	if waiting then
		Kit.PendingText(L(active and "OPENHOI_WIN_FORM_ACTIVE" or "OPENHOI_WIN_FORM_INACTIVE"), true)
	elseif active then
		Kit.Coloured(Kit.SUCCESS, L("OPENHOI_WIN_FORM_ACTIVE"))
	else
		ImGui.TextDisabled(L("OPENHOI_WIN_FORM_INACTIVE"))
	end
	ImGui.SameLine()
	if ImGui.Button(L("OPENHOI_WIN_APPLY")) then
		local list = fields()
		Kit.Ask(function() apply(form, list) end)
	end
	ImGui.SameLine()
	if ImGui.Button(L("OPENHOI_WIN_FORM_RELOAD")) then
		form.reload = true
		form.result = nil
		OpenHOI3.Refresh()
	end
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip(L("OPENHOI_WIN_FORM_RELOAD_TIP"))
	end
	ImGui.SameLine()
	ImGui.TextDisabled(tostring(form.tag or ""))

	if not form.configured then
		Kit.Coloured(Kit.WARNING, L("OPENHOI_WIN_FORM_NEVER"))
	end
	if form.result ~= nil then
		if form.result.ok then
			Kit.Coloured(Kit.SUCCESS, L(form.result.corrected and "OPENHOI_WIN_FORM_CORRECTED" or "OPENHOI_WIN_FORM_APPLIED"))
		else
			Kit.Coloured(Kit.ERROR, tostring(form.result.reason))
		end
	elseif form.edited then
		Kit.Coloured(Kit.WARNING, L("OPENHOI_WIN_FORM_EDITED"))
	end
end

-- At the head of a form page's Draw: whether there is a form to draw.
function Form.Ready(form, data)
	if not Kit.Ready(data, data and data.answer) then
		return false
	end
	return form.values ~= nil
end

-- The same sending for a page that fills a window of the game's own interface (script/openhoi/nativeform.lua).
Form.Apply = apply

return Form
