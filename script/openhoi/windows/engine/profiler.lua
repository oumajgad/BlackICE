-- The Engine Profiler page: how long the engine takes over the game's hours, step by step, and what the program
-- says of itself - frames a second, memory, what is drawn.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md); the original never opens
-- it, and there is nothing like it there. The figures are OpenHOI3's own: OpenHOI3.Profile.Read() answers
--   seconds                       how long the timing has run, in real seconds
--   hours, hour_ms, hour_most     the hours that turned no day: how many, their milliseconds together, the longest
--   days, day_ms, day_most        the same of the hours that turned a day
--   last                          the last 240 hours' milliseconds, the oldest first
--   steps                         every step of the game's hours, the longest first: { name, ms, calls, part,
--                                 parent } - a part is a piece of the step its parent names, timed inside it
--   engine                        the program's own figures by key: fps, frame_ms, draw_calls, primitives, nodes,
--                                 memory_mb, video_memory_mb, managed_mb, collections, collections_full, threads
-- Asking starts the timing, and it runs on while the page is closed, until Stop. It changes nothing of the game.
--
-- It stands under the Debug tab by its group, below. Its folder is not called "debug" because the repository's
-- .gitignore leaves every folder of that name out.
--
-- Every text comes from the localisation (localisation/openhoi/windows.csv), through OpenHOI3.Localise. A step's
-- name is the engine's own name for it and is shown as it is.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The page's own state, kept between frames.
local running = true     -- whether the timing is kept; Stop ends it and Start begins it again
local previous = nil     -- the gathering before this one, for the speed between the two
local state = {}         -- what is typed into the filter
local parts = true       -- whether the parts of steps are listed

-- The program's figures in the order they are shown, each with the number of decimals it is written to.
local FIGURES = {
	{ "fps", 0 }, { "frame_ms", 2 }, { "draw_calls", 0 }, { "primitives", 0 }, { "nodes", 0 },
	{ "memory_mb", 0 }, { "video_memory_mb", 0 }, { "managed_mb", 0 }, { "collections", 0 },
	{ "collections_full", 0 }, { "threads", 0 },
}

local function Number(value, decimals)
	return string.format("%." .. decimals .. "f", value or 0)
end

-- A row of the hours' table: what it is, how often it ran, its average, its longest and all of it.
local function HourRow(label, runs, total, most)
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text(label)
	ImGui.TableNextColumn()
	ImGui.Text(Number(runs, 0))
	ImGui.TableNextColumn()
	ImGui.Text(runs > 0 and Number(total / runs, 2) or "-")
	ImGui.TableNextColumn()
	ImGui.Text(most ~= nil and Number(most, 2) or "-")
	ImGui.TableNextColumn()
	ImGui.Text(Number(total, 0))
end

local function DrawHours(data)
	ImGui.SeparatorText(L("OPENHOI_WIN_PROFILE_GAME"))
	ImGui.Text(Kit.Filled("OPENHOI_WIN_PROFILE_MEASURED", {
		SECONDS = Number(data.seconds, 0), HOURS = Number(data.hours + data.days, 0), DAYS = Number(data.days, 0),
	}))
	if data.hours + data.days == 0 then
		ImGui.TextDisabled(L("OPENHOI_WIN_PROFILE_NOTHING"))
		return
	end
	if data.rate ~= nil then
		ImGui.Text(Kit.Filled("OPENHOI_WIN_PROFILE_SPEED", {
			HOURS = Number(data.rate, 1), DAYS = Number(data.rate * 60 / 24, 1),
		}))
	end
	if ImGui.BeginTable("profile_hours", 5) then
		ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_WHAT"))
		ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_RUNS"))
		ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_AVERAGE"))
		ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_LONGEST"))
		ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_TOTAL"))
		ImGui.TableHeadersRow()
		HourRow(L("OPENHOI_WIN_PROFILE_ROW_HOUR"), data.hours, data.hour_ms, data.hour_most)
		HourRow(L("OPENHOI_WIN_PROFILE_ROW_DAY"), data.days, data.day_ms, data.day_most)
		-- A whole game day: all the hours measured, shared out over the days that turned.
		HourRow(L("OPENHOI_WIN_PROFILE_ROW_WHOLE_DAY"), data.days, data.hour_ms + data.day_ms, nil)
		ImGui.EndTable()
	end
	if #data.last > 1 then
		local width = ImGui.GetContentRegionAvail()
		ImGui.PlotLines("##profile_last", data.last, width, 70,
			Kit.Filled("OPENHOI_WIN_PROFILE_LAST", { COUNT = #data.last }))
	end
end

local function DrawProgram(data)
	ImGui.SeparatorText(L("OPENHOI_WIN_PROFILE_PROGRAM"))
	local rows = {}
	for _, figure in ipairs(FIGURES) do
		local value = data.engine[figure[1]]
		if value ~= nil then
			rows[#rows + 1] = { L("OPENHOI_WIN_PROFILE_FIG_" .. string.upper(figure[1])), Number(value, figure[2]) }
		end
	end
	Kit.LabelTable("profile_program", rows)
end

-- What a row is sorted by under each heading: its name, its time - which the share follows - how often it ran,
-- and its time a run. A row with no count of runs stands below every row that has one.
local function SortKey(row, column)
	if column == 1 then
		return string.lower(row.name)
	elseif column == 4 then
		return row.calls or -1
	elseif column == 5 then
		return row.calls ~= nil and row.calls > 0 and row.ms / row.calls or -1
	end
	return row.ms
end

-- The rows in the order the table is sorted by; with no heading to go by, as the engine gives them, which is
-- the longest first. Rows that are equal under a heading stand by their names.
local function Sorted(rows, column, largest)
	if column == 0 or #rows < 2 then
		return rows
	end
	local list = {}
	for i, row in ipairs(rows) do
		list[i] = row
	end
	table.sort(list, function(a, b)
		local x, y = SortKey(a, column), SortKey(b, column)
		if x ~= y then
			if largest then
				return x > y
			end
			return x < y
		end
		return a.name < b.name
	end)
	return list
end

local function DrawSteps(data)
	ImGui.SeparatorText(L("OPENHOI_WIN_PROFILE_STEPS"))
	Kit.FilterBox(state, 260)
	ImGui.SameLine()
	local changed, ticked = ImGui.Checkbox(L("OPENHOI_WIN_PROFILE_PARTS"), parts)
	if changed then
		parts = ticked
	end
	ImGui.TextDisabled(L("OPENHOI_WIN_PROFILE_STEPS_HELP"))

	-- A step's share is of all the time the hours took. What the steps do not come to is whatever is not timed;
	-- a part is counted in its step, so the parts are left out of that sum. The orders the hours drain - the
	-- players' and the AI's - are a step of their own, "the orders drained", each kind of order a part of it.
	local all = data.hour_ms + data.day_ms
	local timed = 0
	for _, step in ipairs(data.steps) do
		if not step.part then
			timed = timed + step.ms
		end
	end

	if ImGui.BeginChild("profile_steps_rows", 0, 0) then
		-- A click on a heading sorts by it: the steps among themselves, and each step's parts under it. It starts
		-- by the time, the longest first, and a first click on a column of figures puts its largest first.
		if ImGui.BeginSortedTable("profile_steps", 5) then
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_STEP"))
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_TOTAL"), 0, "start largest")
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_SHARE"), 0, "largest")
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_RUNS"), 0, "largest")
			ImGui.TableSetupColumn(L("OPENHOI_WIN_PROFILE_COL_PER_RUN"), 0, "largest")
			ImGui.TableHeadersRow()
			local column, largest = ImGui.TableSort()
			local function Row(name, ms, calls, part)
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				if part then
					ImGui.TextDisabled("    " .. name)
				else
					ImGui.Text(name)
				end
				ImGui.TableNextColumn()
				ImGui.Text(Number(ms, 1))
				ImGui.TableNextColumn()
				ImGui.Text(all > 0 and Number(ms * 100 / all, 1) .. " %" or "-")
				ImGui.TableNextColumn()
				ImGui.Text(calls ~= nil and Number(calls, 0) or "-")
				ImGui.TableNextColumn()
				ImGui.Text(calls ~= nil and calls > 0 and Number(ms / calls, 3) or "-")
			end
			-- Each step with its parts under it, both in the table's order. A part timed in no step stands at the
			-- end. What is not timed is a row among the steps, with no runs to count.
			local steps, under, loose = {}, {}, {}
			for _, step in ipairs(data.steps) do
				if not step.part then
					steps[#steps + 1] = step
				else
					if step.parent ~= nil and step.parent ~= "" then
						under[step.parent] = under[step.parent] or {}
						table.insert(under[step.parent], step)
					else
						loose[#loose + 1] = step
					end
				end
			end
			if all - timed > 0 then
				steps[#steps + 1] = { name = L("OPENHOI_WIN_PROFILE_REST"), ms = all - timed }
			end
			for _, step in ipairs(Sorted(steps, column, largest)) do
				local own = parts and under[step.name] and Sorted(under[step.name], column, largest) or {}
				-- A step is shown where its name, or the name of a part of it, holds what is typed.
				local shown = Kit.Matches(step.name, state.filter)
				for _, part in ipairs(own) do
					shown = shown or Kit.Matches(part.name, state.filter)
				end
				if shown then
					Row(step.name, step.ms, step.calls, false)
					for _, part in ipairs(own) do
						Row(part.name, part.ms, part.calls, true)
					end
				end
			end
			if parts then
				for _, part in ipairs(Sorted(loose, column, largest)) do
					if Kit.Matches(part.name, state.filter) then
						Row(part.name, part.ms, part.calls, true)
					end
				end
			end
			ImGui.EndTable()
		end
	end
	ImGui.EndChild()
end

return {
	title = "OPENHOI_WIN_PROFILE",
	order = 10,
	group = "OPENHOI_WIN_GROUP_DEBUG",
	group_order = 80,

	Collect = function(player)
		-- Reset and Stop are pressed while the page draws and done here, where the game may be asked.
		Kit.RunAsked()
		if not running then
			return { stopped = true }
		end
		local data = OpenHOI3.Profile.Read()
		if data == nil then
			return nil
		end
		-- The speed between this gathering and the one before: game hours a real second.
		local hours = data.hours + data.days
		if previous ~= nil and data.seconds > previous.seconds and hours >= previous.hours then
			data.rate = (hours - previous.hours) / (data.seconds - previous.seconds)
		end
		previous = { seconds = data.seconds, hours = hours }
		return data
	end,

	Draw = function(data, player)
		if ImGui.Button(L("OPENHOI_WIN_PROFILE_RESET")) then
			previous = nil
			Kit.Ask(function() OpenHOI3.Profile.Reset() end)
		end
		ImGui.SameLine()
		if running then
			if ImGui.Button(L("OPENHOI_WIN_PROFILE_STOP")) then
				running = false
				previous = nil
				Kit.Ask(function() OpenHOI3.Profile.Stop() end)
			end
		elseif ImGui.Button(L("OPENHOI_WIN_PROFILE_START")) then
			running = true
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		ImGui.TextDisabled(L("OPENHOI_WIN_PROFILE_HELP"))

		if data == nil then
			return
		end
		if data.stopped then
			ImGui.Text(L("OPENHOI_WIN_PROFILE_STOPPED"))
			return
		end
		DrawHours(data)
		DrawProgram(data)
		DrawSteps(data)
	end,
}
