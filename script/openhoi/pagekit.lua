-- What the pages of the mod's own windows for OpenHOI3 share (script/openhoi/windows, docs/openhoi/README.md):
-- the filter box, a table and a list that a filter narrows, a box of text that can be copied, and the two panes
-- of a page that lists things on the left and shows the chosen one on the right.
--
-- Not a page itself, which is why it stands beside the windows folder and not in it: OpenHOI3 takes every file
-- below script/openhoi/windows for a page. A page takes it with  local Kit = require('openhoi/pagekit').
--
-- Everything here only draws. It asks the game nothing, so it may be called from a page's Draw.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise

local Kit = {}

-- The height of one line of text with its spacing, for sharing a pane's height out.
Kit.LINE = 24

-- Whether a text holds the filter, whatever the case of either. An empty filter keeps everything.
function Kit.Matches(text, filter)
	if filter == nil or filter == "" then
		return true
	end
	return string.find(string.lower(tostring(text)), string.lower(filter), 1, true) ~= nil
end

-- A text with its $NAME$ places filled in.
function Kit.Filled(key, values)
	local text = L(key)
	for name, value in pairs(values) do
		text = string.gsub(text, "%$" .. name .. "%$", function() return tostring(value) end)
	end
	return text
end

-- The filter box. state.filter holds what is typed and is kept by the page between frames.
function Kit.FilterBox(state, width)
	if state.filter == nil then
		state.filter = ""
	end
	if width ~= nil then
		ImGui.SetNextItemWidth(width)
	end
	local changed, typed = ImGui.InputText(L("OPENHOI_WIN_FILTER"), state.filter)
	if changed then
		state.filter = typed
	end
	-- While the box is typed into, Home and End are its own and not the list's below it.
	state.typing = ImGui.IsItemActive()
end

-- Two panes side by side with a divider between them that is dragged. The left pane begins at the width given.
--   if Kit.BeginPanes("traits", 280) then  <left pane>  Kit.NextPane()  <right pane>  Kit.EndPanes() end
--   Kit.BeginPanes("traits", 280)  <left pane>  Kit.NextPane()  <right pane>  Kit.EndPanes()
-- Where the panes cannot be drawn - the window too small to show them - the two follow each other on one line.
local panes = {}

function Kit.BeginPanes(id, width)
	local open = ImGui.BeginPanes(id, 2)
	panes[#panes + 1] = open
	if open then
		ImGui.TableSetupColumn("left", width)
		ImGui.TableSetupColumn("right")
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
	end
end

function Kit.NextPane()
	if panes[#panes] then
		ImGui.TableNextColumn()
	else
		ImGui.SameLine()
	end
end

function Kit.EndPanes()
	if table.remove(panes) then
		ImGui.EndTable()
	end
end

-- A table of rows under a filter box with its "shown/all" counter.
--   rows     a list of tables
--   columns  a list of { title = <localisation key>, field = <the row's field> }; the filter looks at the first
function Kit.FilteredTable(id, state, rows, columns)
	Kit.FilterBox(state, 260)
	local shown = {}
	for _, row in ipairs(rows) do
		if Kit.Matches(row[columns[1].field], state.filter) then
			shown[#shown + 1] = row
		end
	end
	ImGui.SameLine()
	ImGui.TextDisabled(#shown .. "/" .. #rows)

	if ImGui.BeginChild(id .. "_rows", 0, 0) then
		if ImGui.BeginTable(id, #columns) then
			for _, column in ipairs(columns) do
				ImGui.TableSetupColumn(L(column.title))
			end
			ImGui.TableHeadersRow()
			for _, row in ipairs(shown) do
				ImGui.TableNextRow()
				for _, column in ipairs(columns) do
					ImGui.TableNextColumn()
					ImGui.Text(tostring(row[column.field]))
				end
			end
			ImGui.EndTable()
		end
	end
	ImGui.EndChild()
end

-- A list of texts under a filter box, one of which is chosen by a click or by the keyboard. state.selected holds
-- the chosen text and is kept though the filter hides it. Answers true in the frame another row is chosen.
--   label  optional: a function giving the text shown for an item, where that is not the item itself
--
-- While the list was the last thing clicked and the filter is not being typed into, Down chooses the next row
-- shown and Up the one before, Home the first and End the last, stopping at either end; the row chosen is
-- scrolled to the middle.
function Kit.FilteredList(id, state, items, width, height, label)
	local chosen = false
	if ImGui.BeginChild(id, width or 0, height or 0) then
		Kit.FilterBox(state, -50)
		local shown, at = {}, nil
		for index, item in ipairs(items) do
			local text = label and label(item) or item
			if Kit.Matches(text, state.filter) then
				shown[#shown + 1] = item
				if state.selected == item then
					at = #shown
				end
				-- The index keeps two rows of one text apart.
				if ImGui.Selectable(text .. "##" .. index, state.selected == item) then
					state.selected = item
					chosen = true
				end
				if state.scrollTo == item then
					ImGui.SetScrollHereY(0.5)
					state.scrollTo = nil
				end
			end
		end

		if #shown > 0 and not state.typing and ImGui.IsWindowFocused() then
			local to = nil
			if ImGui.IsKeyPressed("DownArrow") then
				to = at and math.min(at + 1, #shown) or 1
			elseif ImGui.IsKeyPressed("UpArrow") then
				to = at and math.max(at - 1, 1) or #shown
			elseif ImGui.IsKeyPressed("Home") then
				to = 1
			elseif ImGui.IsKeyPressed("End") then
				to = #shown
			end
			if to ~= nil and to ~= at then
				state.selected = shown[to]
				-- Scrolled to as it is next drawn.
				state.scrollTo = shown[to]
				chosen = true
			end
		end
	end
	ImGui.EndChild()
	return chosen
end

-- A box of text that can be selected and copied but not changed. A height of nought takes the room left.
function Kit.TextBox(id, text, height)
	if text == nil or text == "" then
		text = L("OPENHOI_WIN_NONE")
	end
	ImGui.InputTextMultiline("##" .. id, text, -1, height or -1, true)
end

-- The answer of one of the mod's own data functions (BiceLibGui...), which says { available = false, reason = }
-- where it has nothing. Draws the reason and answers false then.
function Kit.Available(answer)
	if answer == nil then
		ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
		return false
	end
	if answer.available == false then
		ImGui.TextDisabled(tostring(answer.reason or L("OPENHOI_WIN_UNAVAILABLE")))
		return false
	end
	return true
end

-- The mod's data functions are loaded by autoexec.lua (gui-imgui.lua) where the utility is switched on. Answers
-- that table's part of the given name, or draws why there is none and answers nil.
function Kit.Data(name)
	if BiceLibGui == nil or BiceLibGui[name] == nil then
		return nil
	end
	return BiceLibGui[name]
end

return Kit
