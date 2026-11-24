-- The LS Sliders AI page: hands the country's leadership sliders to the mod's own AI and sets the amounts of
-- officers, spies and diplomats between which it produces each.
--
-- A native page of OpenHOI3's enhanced mode (docs/openhoi/README.md): it fills the window
-- openhoi_blackice_lssliders of interface/openhoi/sliders.gui, which a button on the technology screen opens.
-- A form, as script/openhoi/nativeform.lua explains. The data is the mod's own, shared with the overlay on the
-- original engine: BiceLibGui.LsSliders, over the variables zzDsafe_CustomLeadershipSliders_...

local Gui = OpenHOI3.Gui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')
local Form = require('openhoi/pageform')
local Native = require('openhoi/nativeform')

local form = Form.New("LsSliders")

-- The rows the window declares.
local ROWS = 3

-- The fields Apply sends, in order: each row's two thresholds, then the buffer.
local function fields()
	local list = {}
	for _, row in ipairs(form.values.rows or {}) do
		list[#list + 1] = { row.key .. "Lower", row.lower or 0 }
		list[#list + 1] = { row.key .. "Upper", row.upper or 0 }
	end
	list[#list + 1] = { "bufferProdNco", form.values.bufferNco ~= false and 1 or 0 }
	return list
end

-- Commit lowers a value above its row's maximum and a lower threshold above its upper one, and says which: the
-- boxes take what the game was sent.
form.correct = function(corrections)
	for _, correction in ipairs(corrections) do
		for _, row in ipairs(form.values.rows or {}) do
			if correction.field == row.key .. "Lower" then
				row.lower = correction.value
			elseif correction.field == row.key .. "Upper" then
				row.upper = correction.value
			end
		end
	end
end

return {
	title = "OPENHOI_WIN_LSSLIDERS",
	window = "openhoi_blackice_lssliders",
	host = "technology",
	opener = "openhoi_blackice_lssliders_opener",

	Collect = function(player)
		return Form.Gather(form)
	end,

	Fill = function(data, player)
		Gui.SetText("title", L("OPENHOI_WIN_LSSLIDERS"))
		Gui.SetText("lower_header", L("OPENHOI_WIN_LSSLIDERS_LOWER"))
		Gui.SetText("upper_header", L("OPENHOI_WIN_LSSLIDERS_UPPER"))
		Gui.SetText("buffer_label", L("OPENHOI_WIN_LSSLIDERS_BUFFER"))
		Gui.SetTooltip("buffer_label", L("OPENHOI_WIN_LSSLIDERS_BUFFER_TIP"))
		Gui.SetTooltip("help", L("OPENHOI_WIN_LSSLIDERS_HELP") .. "\n\n" .. L("OPENHOI_WIN_LSSLIDERS_HELP2") .. "\n\n"
			.. L("OPENHOI_WIN_WARNING") .. " " .. L("OPENHOI_WIN_LSSLIDERS_WARNING"))
		if not Native.Ready(form, data) then
			return
		end
		Native.Top(form, fields)
		local values = form.values
		local rows = values.rows or {}
		for index = 1, ROWS do
			local row = rows[index]
			local n = tostring(index)
			for _, element in ipairs({ "row_", "name_", "lower_bg_", "lower_", "upper_bg_", "upper_" }) do
				Gui.SetVisible(element .. n, row ~= nil)
			end
			if row ~= nil then
				Gui.SetText("name_" .. n, tostring(row.name))
				Gui.SetTooltip("row_" .. n, (row.maximum or 0) > 0 and Kit.Filled("OPENHOI_WIN_LSSLIDERS_MAXIMUM", { N = row.maximum }) or "")
				Native.Number(form, "lower_" .. n, row, "lower")
				Native.Number(form, "upper_" .. n, row, "upper")
			end
		end

		-- The officers are kept for a while longer unless the data says not to.
		if values.bufferNco == nil then
			values.bufferNco = true
		end
		Native.Check(form, "buffer", values, "bufferNco")
	end,
}
