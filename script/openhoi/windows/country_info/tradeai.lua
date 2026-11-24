-- The Trade AI page: hands the country's trading to the mod's own trade AI and sets its limits - how much of each
-- resource to keep coming in, above what stockpile to sell and above what to stop buying.
--
-- A native page of OpenHOI3's enhanced mode (docs/openhoi/README.md): it fills the window
-- openhoi_blackice_tradeai of interface/openhoi/tradeai.gui, which a button on the production screen opens.
-- A form, as script/openhoi/nativeform.lua explains. The data is the mod's own, shared with the overlay on the
-- original engine: BiceLibGui.TradeAi, over the variables zzDsafe_TradeAi_...

local Gui = OpenHOI3.Gui
local L = OpenHOI3.Localise
local Form = require('openhoi/pageform')
local Native = require('openhoi/nativeform')

local form = Form.New("TradeAi")

-- The rows the window declares.
local ROWS = 6

-- The fields Apply sends, in order: the deficit, then each resource's surplus and, where it has them, its caps.
local function fields()
	local values = form.values
	local list = { { "MaxDailySell", values.maxDailySell or 0 } }
	for _, row in ipairs(values.rows or {}) do
		-- The daily surplus is a whole number: what is sent is what the box shows.
		list[#list + 1] = { row.key .. "_Buffer", Native.Whole(row.buffer) }
		if row.hasCaps then
			list[#list + 1] = { row.key .. "_BufferSaleCap", row.saleCap or 0 }
			list[#list + 1] = { row.key .. "_BufferCancelCap", row.cancelCap or 0 }
		end
	end
	return list
end

return {
	title = "OPENHOI_WIN_TRADEAI",
	window = "openhoi_blackice_tradeai",
	host = "production",
	opener = "openhoi_blackice_tradeai_opener",

	Collect = function(player)
		return Form.Gather(form)
	end,

	Fill = function(data, player)
		Gui.SetText("title", L("OPENHOI_WIN_TRADEAI"))
		Gui.SetTooltip("help", L("OPENHOI_WIN_TRADEAI_HELP"))
		Gui.SetText("deficit_label", L("OPENHOI_WIN_TRADEAI_DEFICIT"))
		Gui.SetTooltip("deficit_label", L("OPENHOI_WIN_TRADEAI_DEFICIT_TIP"))
		if not Native.Ready(form, data) then
			return
		end
		Native.Top(form, fields)
		local values = form.values
		Native.Number(form, "deficit", values, "maxDailySell")

		local rows = values.rows or {}
		for index = 1, ROWS do
			local row = rows[index]
			local n = tostring(index)
			for _, element in ipairs({ "row_", "name_", "surplus_bg_", "surplus_" }) do
				Gui.SetVisible(element .. n, row ~= nil)
			end
			-- A resource with no caps - money - shows a dash in their place.
			local caps = row ~= nil and row.hasCaps and true or false
			for _, element in ipairs({ "sale_bg_", "sale_", "cancel_bg_", "cancel_" }) do
				Gui.SetVisible(element .. n, caps)
			end
			Gui.SetVisible("sale_none_" .. n, row ~= nil and not caps)
			Gui.SetVisible("cancel_none_" .. n, row ~= nil and not caps)
			if row ~= nil then
				Gui.SetText("name_" .. n, tostring(row.name))
				Native.Number(form, "surplus_" .. n, row, "buffer")
				if caps then
					Native.Number(form, "sale_" .. n, row, "saleCap")
					Native.Number(form, "cancel_" .. n, row, "cancelCap")
				end
			end
		end
	end,
}
