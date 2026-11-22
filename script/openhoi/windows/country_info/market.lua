-- The Global Market page: for one of the mod's strategic resources, every country with production of it to
-- spare, the largest first. It has nothing to do with the player's own country.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The data is the mod's
-- own, shared with the overlay on the original engine: BiceLibGui.Trades.Resources and .Market.
--
-- The market reads a variable of every country in the game, which is too much to do every two seconds: it is
-- read when a resource is chosen and when Refresh is pressed, and kept in between.

local ImGui = OpenHOI3.ImGui
local L = OpenHOI3.Localise
local Kit = require('openhoi/pagekit')

-- The resources to choose from, read once, and the one chosen, counted from one.
local resources = nil
local chosen = 0
-- The market as last read, and whether it is to be read at the next Collect.
local market = nil
local read = false

return {
	title = "OPENHOI_WIN_MARKET",
	order = 70,
	group = "OPENHOI_WIN_GROUP_COUNTRY",
	group_order = 20,

	Collect = function(player)
		return Kit.Gather("Trades", function(source)
			if resources == nil then
				local answer = source.Resources()
				if answer.available ~= false then
					resources = answer.resources or {}
				end
			end
			if read and resources ~= nil and resources[chosen] ~= nil then
				market = source.Market(resources[chosen].key)
				read = false
			end
			return { loaded = resources ~= nil }
		end)
	end,

	Draw = function(data, player)
		if data == nil then
			return
		end
		if data.missing then
			ImGui.TextDisabled(L("OPENHOI_WIN_NO_DATA"))
			return
		end
		if resources == nil then
			ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
			return
		end

		if ImGui.Button(L("OPENHOI_WIN_REFRESH")) and chosen > 0 then
			read = true
			OpenHOI3.Refresh()
		end
		ImGui.SameLine()
		local names = {}
		for index, resource in ipairs(resources) do
			names[index] = tostring(resource.name)
		end
		ImGui.SetNextItemWidth(180)
		local changed, picked = ImGui.Combo(L("OPENHOI_WIN_STRATRES_RESOURCE"), chosen, names)
		if changed and picked ~= chosen then
			chosen = picked
			market = nil
			read = true
			OpenHOI3.Refresh()
		end

		if chosen == 0 then
			ImGui.TextDisabled(L("OPENHOI_WIN_MARKET_CHOOSE"))
		elseif market == nil then
			ImGui.TextDisabled(L("OPENHOI_WIN_LOADING"))
		elseif Kit.Available(market) then
			local rows = market.rows or {}
			if #rows == 0 then
				ImGui.TextDisabled(L("OPENHOI_WIN_MARKET_NONE"))
			else
				local _, height = ImGui.GetContentRegionAvail()
				if ImGui.BeginChild("market", 0, math.max(3 * Kit.LINE, height - 4 * Kit.LINE)) then
					if ImGui.BeginTable("rows", 5) then
						ImGui.TableSetupColumn(L("OPENHOI_WIN_MARKET_COUNTRY"))
						ImGui.TableSetupColumn(L("OPENHOI_WIN_MARKET_POTENTIAL"))
						ImGui.TableSetupColumn(L("OPENHOI_WIN_STRATRES_SALES"))
						ImGui.TableSetupColumn(L("OPENHOI_WIN_MARKET_AVAILABLE"))
						ImGui.TableSetupColumn(L("OPENHOI_WIN_MARKET_EXPIRY"))
						ImGui.TableHeadersRow()
						for _, row in ipairs(rows) do
							ImGui.TableNextRow()
							ImGui.TableNextColumn()
							ImGui.Text(tostring(row.tag))
							ImGui.TableNextColumn()
							ImGui.Text(string.format("%d", row.potential or 0))
							ImGui.TableNextColumn()
							ImGui.Text(string.format("%d", row.sales or 0))
							ImGui.TableNextColumn()
							local spare = string.format("%d", row.available or 0)
							if (row.available or 0) > 0 then
								Kit.Coloured(Kit.SUCCESS, spare)
							else
								ImGui.Text(spare)
							end
							ImGui.TableNextColumn()
							if (row.next_expiry or -1) < 0 then
								ImGui.TextDisabled("-")
							else
								ImGui.Text(string.format("%dd", row.next_expiry))
							end
						end
						ImGui.EndTable()
					end
				end
				ImGui.EndChild()
			end
		end
		ImGui.TextWrapped(L("OPENHOI_WIN_MARKET_NOTE"))
	end,
}
