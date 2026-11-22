-- The Combat Reports page: the country's finished battles counted over a period of the player's choosing - by
-- land, air, sea and bombing - with what they cost each side, and its last sixteen battles. It only reads.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). On the original engine
-- BiceLib catches every battle as it ends and keeps them in files beside the DLL, a campaign and its sessions
-- told apart by variables of OMG. OpenHOI3 keeps the record itself, in the game and in its save: a page reads it
-- with OpenHOI3.CombatTally and OpenHOI3.LastCombats. So there are no campaign numbers, sessions or files here,
-- and a savegame loaded has its own record with it. A province's name comes from the mod's own data,
-- BiceLibGui.Oob.ProvinceName, as on the original.
--
-- The record begins with the first battle that ends in a game played on an OpenHOI3 that keeps it.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The periods: their names and their days; the last is the player's own range.
local PERIODS = {
	{ "OPENHOI_WIN_COMBAT_DAY", 1 }, { "OPENHOI_WIN_COMBAT_WEEK", 7 }, { "OPENHOI_WIN_COMBAT_MONTH", 30 },
	{ "OPENHOI_WIN_COMBAT_HALF_YEAR", 182 }, { "OPENHOI_WIN_COMBAT_YEAR", 365 }, { "OPENHOI_WIN_COMBAT_CUSTOM", 0 },
}
local CUSTOM = #PERIODS
local period = 2

-- The player's own range, as the numbers of its first and last day, and what stands in its two boxes.
local from, to = nil, nil
local fromText, toText = "", ""
local unreadable = false

-- Province names as the mod has them, kept: names[id] = text, "" for none.
local names = {}

local KINDS = {
	land = "OPENHOI_WIN_GENERALS_LAND", air = "OPENHOI_WIN_GENERALS_AIR", naval = "OPENHOI_WIN_OOBREPORT_NAVAL",
	ground_bombing = "OPENHOI_WIN_COMBAT_GROUND_BOMBING", land_bombing = "OPENHOI_WIN_COMBAT_LAND_BOMBING",
	naval_bombing = "OPENHOI_WIN_COMBAT_NAVAL_BOMBING",
}

-- A whole number with a full stop between its groups of three digits: 1234567 as 1.234.567.
local function grouped(number)
	local digits = string.format("%d", math.floor((tonumber(number) or 0) + 0.5))
	local sign = ""
	if string.sub(digits, 1, 1) == "-" then
		sign, digits = "-", string.sub(digits, 2)
	end
	local out = string.gsub(string.reverse(digits), "(%d%d%d)", "%1.")
	out = string.reverse(out)
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return sign .. out
end

-- A day's number as "year.month.day".
local function written(day)
	local year, month, dayOfMonth = OpenHOI3.DateOf(day)
	return string.format("%d.%d.%d", year, month, dayOfMonth)
end

-- "year.month.day" as a day's number, or nil where it is no date.
local function read(text)
	local year, month, day = string.match(text or "", "^%s*(%d+)%.(%d+)%.(%d+)%s*$")
	if year == nil then
		return nil
	end
	return OpenHOI3.DayNumber(tonumber(year), tonumber(month), tonumber(day))
end

local function setRange(first, last)
	from, to = first, last
	fromText, toText = written(first), written(last)
	unreadable = false
	OpenHOI3.Refresh()
end

-- A column's figures added up: the three kinds of bombing as one, and every kind as the total.
local function columns(tally)
	local function sum(kinds)
		local total = { combats = 0, won = 0, lost = 0, as_attacker = 0, as_defender = 0, kills = 0, losses = 0 }
		for _, kind in ipairs(kinds) do
			local one = tally[kind]
			if one ~= nil then
				for key in pairs(total) do
					total[key] = total[key] + (one[key] or 0)
				end
			end
		end
		return total
	end
	return {
		sum({ "land" }), sum({ "air" }), sum({ "naval" }), sum({ "ground_bombing", "land_bombing", "naval_bombing" }),
		sum({ "land", "air", "naval", "ground_bombing", "land_bombing", "naval_bombing" }),
	}
end

return {
	title = "OPENHOI_WIN_COMBAT",
	order = 17,
	group = "OPENHOI_WIN_GROUP_INSPECTOR",
	group_order = 40,

	Collect = function(player)
		local tag = Kit.Selected(player)
		local today = OpenHOI3.Today()
		if today == nil then
			return nil
		end
		-- The range counted: so many days back from today, or the player's own.
		local first, last = today.day_number - PERIODS[period][2], today.day_number
		if period == CUSTOM then
			if from == nil then
				from, to = today.day_number - 30, today.day_number
				fromText, toText = written(from), written(to)
			end
			first, last = from, to
		end
		local last16 = OpenHOI3.LastCombats(tag, 16)
		if Kit.Data("Oob") ~= nil then
			for _, battle in ipairs(last16) do
				if (battle.province or 0) > 0 and names[battle.province] == nil then
					local answer = Kit.Data("Oob").ProvinceName(battle.province)
					names[battle.province] = answer.available ~= false and tostring(answer.name or "") or ""
				end
			end
		end
		return {
			tag = tag, today = today.day_number, first = math.max(first, 0), last = last,
			tally = OpenHOI3.CombatTally(tag, math.max(first, 0), last),
			battles = last16,
		}
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end

		-- The period.
		local labels = {}
		for index, one in ipairs(PERIODS) do
			labels[index] = L(one[1])
		end
		ImGui.SetNextItemWidth(140)
		local changed, picked = ImGui.Combo("##period", period, labels)
		if changed and picked ~= period then
			period = picked
			OpenHOI3.Refresh()
		end
		if period == CUSTOM and from ~= nil then
			ImGui.SameLine()
			ImGui.SetNextItemWidth(110)
			local typedFrom, text = ImGui.InputText("##from", fromText, 12)
			if typedFrom then
				fromText = text
			end
			ImGui.SameLine()
			ImGui.Text(L("OPENHOI_WIN_STATS_TO"))
			ImGui.SameLine()
			ImGui.SetNextItemWidth(110)
			local typedTo, other = ImGui.InputText("##to", toText, 12)
			if typedTo then
				toText = other
			end
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(L("OPENHOI_WIN_COMBAT_DATES_TIP"))
			end
			-- Both boxes read: where both are dates they are the range, the earlier first.
			if typedFrom or typedTo then
				local first, last = read(fromText), read(toText)
				unreadable = first == nil or last == nil
				if not unreadable then
					if first > last then
						first, last = last, first
					end
					if first ~= from or last ~= to then
						from, to = first, last
						OpenHOI3.Refresh()
					end
				end
			end
			for _, button in ipairs({
				{ "-", "OPENHOI_WIN_COMBAT_END_BACK", function() setRange(from, math.max(from, to - 1)) end },
				{ "+", "OPENHOI_WIN_COMBAT_END_ON", function() setRange(from, to + 1) end },
				{ "<", "OPENHOI_WIN_COMBAT_BOTH_BACK", function() setRange(math.max(0, from - 1), math.max(0, to - 1)) end },
				{ ">", "OPENHOI_WIN_COMBAT_BOTH_ON", function() setRange(from + 1, to + 1) end },
				{ L("OPENHOI_WIN_COMBAT_NOW"), "OPENHOI_WIN_COMBAT_NOW_TIP", function() setRange(data.today - 30, data.today) end },
			}) do
				ImGui.SameLine()
				if ImGui.SmallButton(button[1] .. "##range" .. button[2]) then
					button[3]()
				end
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip(L(button[2]))
				end
			end
		end
		ImGui.SameLine()
		if period == CUSTOM and unreadable then
			Kit.Coloured(Kit.WARNING, Kit.Filled("OPENHOI_WIN_COMBAT_NOT_A_DATE", { FROM = written(data.first), TO = written(data.last) }))
		elseif period == CUSTOM then
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_COMBAT_DAYS", { N = data.last - data.first + 1 }) .. " | " .. tostring(data.tag))
		else
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_COMBAT_LAST_DAYS", { N = PERIODS[period][2] }) .. " | " .. tostring(data.tag))
		end

		-- The figures: a row a count, a column a kind of battle.
		local cols = columns(data.tally)
		local rows = {
			{ "OPENHOI_WIN_COMBAT_COMBATS", "combats" }, { "OPENHOI_WIN_COMBAT_WON", "won" }, { "OPENHOI_WIN_COMBAT_LOST", "lost" },
			{ "OPENHOI_WIN_COMBAT_AS_ATTACKER", "as_attacker" }, { "OPENHOI_WIN_COMBAT_AS_DEFENDER", "as_defender" },
			{ "OPENHOI_WIN_COMBAT_ENEMY_CASUALTIES", "kills", true }, { "OPENHOI_WIN_COMBAT_OWN_CASUALTIES", "losses", true },
		}
		if ImGui.BeginTable("figures", 6) then
			-- The labels keep their width; the five columns of figures share the rest.
			ImGui.TableSetupColumn("##label", 150)
			for _, key in ipairs({ "OPENHOI_WIN_GENERALS_LAND", "OPENHOI_WIN_GENERALS_AIR", "OPENHOI_WIN_OOBREPORT_NAVAL",
				"OPENHOI_WIN_COMBAT_BOMBING", "OPENHOI_WIN_COMBAT_TOTAL" }) do
				ImGui.TableSetupColumn(L(key))
			end
			ImGui.TableHeadersRow()
			for _, row in ipairs(rows) do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text(L(row[1]))
				for _, col in ipairs(cols) do
					ImGui.TableNextColumn()
					-- Casualties are kept in thousandths.
					ImGui.Text(grouped(row[3] and col[row[2]] / 1000 or col[row[2]]))
				end
			end
			ImGui.EndTable()
		end
		ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_COMBAT_RECORDED", { N = grouped(data.tally.recorded) }))
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(L("OPENHOI_WIN_COMBAT_RECORDED_TIP"))
		end

		-- The last battles, the newest first, whatever the period.
		ImGui.SeparatorText(L("OPENHOI_WIN_COMBAT_LAST"))
		if #data.battles == 0 then
			ImGui.TextDisabled(Kit.Filled("OPENHOI_WIN_COMBAT_NOTHING", { TAG = tostring(data.tag) }))
			return
		end
		if ImGui.BeginChild("battles", 0, 0) then
			if ImGui.BeginTable("last", 10) then
				for _, key in ipairs({ "OPENHOI_WIN_COMBAT_ENDED", "OPENHOI_WIN_OOB_KIND", "OPENHOI_WIN_COMBAT_RESULT", "OPENHOI_WIN_COMBAT_ROLE",
					"OPENHOI_WIN_COMBAT_AGAINST", "OPENHOI_WIN_COMBAT_ENEMY_CASUALTIES", "OPENHOI_WIN_COMBAT_OF", "OPENHOI_WIN_COMBAT_OWN_CASUALTIES",
					"OPENHOI_WIN_COMBAT_OF", "OPENHOI_WIN_OOB_PROVINCE" }) do
					ImGui.TableSetupColumn(L(key))
				end
				ImGui.TableHeadersRow()
				for _, battle in ipairs(data.battles) do
					-- How many a side had is a count of men only in a battle on land or at sea.
					local counted = battle.kind == "land" or battle.kind == "naval"
					local function men(count)
						if counted and (count or 0) > 0 then
							ImGui.Text(grouped(count))
						else
							ImGui.TextDisabled("---")
						end
					end
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(tostring(battle.ended))
					ImGui.TableNextColumn()
					ImGui.Text(KINDS[battle.kind] and L(KINDS[battle.kind]) or "?")
					ImGui.TableNextColumn()
					if battle.result == "won" then
						Kit.Coloured(Kit.SUCCESS, L("OPENHOI_WIN_COMBAT_WON"))
					elseif battle.result == "lost" then
						Kit.Coloured(Kit.ERROR, L("OPENHOI_WIN_COMBAT_LOST"))
					else
						ImGui.TextDisabled("-")
					end
					ImGui.TableNextColumn()
					ImGui.Text(L(battle.role == "attacker" and "OPENHOI_WIN_COMBAT_ATTACKER" or "OPENHOI_WIN_COMBAT_DEFENDER"))
					ImGui.TableNextColumn()
					ImGui.Text(tostring(battle.against))
					ImGui.TableNextColumn()
					ImGui.Text(grouped((battle.enemy_losses or 0) / 1000))
					ImGui.TableNextColumn()
					men(battle.enemy_men)
					ImGui.TableNextColumn()
					ImGui.Text(grouped((battle.own_losses or 0) / 1000))
					ImGui.TableNextColumn()
					men(battle.own_men)
					ImGui.TableNextColumn()
					local name = names[battle.province]
					if name ~= nil and name ~= "" then
						ImGui.Text(string.format("%s (%d)", name, battle.province))
					else
						ImGui.Text(tostring(battle.province))
					end
				end
				ImGui.EndTable()
			end
		end
		ImGui.EndChild()
	end,
}
