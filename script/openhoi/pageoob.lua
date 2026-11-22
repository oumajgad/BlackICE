-- What the two order-of-battle pages of the mod's own windows for OpenHOI3 share (OOB Browser and OOB Report
-- under script/openhoi/windows/inspector): a country's units read whole from OpenHOI3.OrderOfBattle, made into
-- a tree, and counted.
--
-- Not a page itself; a page takes it with  local Oob = require('openhoi/pageoob').
--
-- On the original engine BiceLib reads the order of battle out of the game's memory. Here OpenHOI3 gives it: a
-- list of units, each with its parent's number, its leader, what it gets and uses of supplies and fuel, and its
-- regiments. Reading asks the game, so Oob.Read is for a page's Collect.

local Oob = {}

local function byName(a, b)
	local left, right = string.lower(a.name), string.lower(b.name)
	if left ~= right then
		return left < right
	end
	return a.id < b.id
end

-- What stands below a unit, itself left out, worked out from its children upward.
local function count(unit)
	local below = { land = 0, air = 0, naval = 0, units = 0, regiments = 0, leaderless = 0, supply = 0, fuel = 0,
		supply_used = 0, fuel_used = 0, depth = 0 }
	for _, child in ipairs(unit.children) do
		local under = count(child)
		below[child.branch] = below[child.branch] + 1
		below.units = below.units + 1 + under.units
		below.land, below.air, below.naval = below.land + under.land, below.air + under.air, below.naval + under.naval
		below.regiments = below.regiments + #child.regiments + under.regiments
		below.leaderless = below.leaderless + (child.leader == nil and 1 or 0) + under.leaderless
		below.supply = below.supply + child.supply + under.supply
		below.fuel = below.fuel + child.fuel + under.fuel
		below.supply_used = below.supply_used + child.supply_used + under.supply_used
		below.fuel_used = below.fuel_used + child.fuel_used + under.fuel_used
		below.depth = math.max(below.depth, 1 + under.depth)
	end
	unit.below = below
	return below
end

-- A country's order of battle: units (every unit), byId, roots (the formations that report to nobody, by name),
-- and totals over all of it.
function Oob.Read(tag)
	local units = OpenHOI3.OrderOfBattle(tag)
	local byId, roots = {}, {}
	for _, unit in ipairs(units) do
		unit.children = {}
		unit.name = (unit.name ~= nil and unit.name ~= "") and unit.name or "(unnamed)"
		byId[unit.id] = unit
	end
	for _, unit in ipairs(units) do
		local parent = byId[unit.parent]
		if parent ~= nil and parent ~= unit then
			parent.children[#parent.children + 1] = unit
			unit.over = parent
		else
			roots[#roots + 1] = unit
		end
	end
	table.sort(roots, byName)
	local totals = { land = 0, air = 0, naval = 0, units = #units, regiments = 0, leaderless = 0, supply = 0, fuel = 0,
		supply_used = 0, fuel_used = 0 }
	for _, unit in ipairs(units) do
		table.sort(unit.children, byName)
		totals[unit.branch] = totals[unit.branch] + 1
		totals.regiments = totals.regiments + #unit.regiments
		totals.leaderless = totals.leaderless + (unit.leader == nil and 1 or 0)
		totals.supply, totals.fuel = totals.supply + unit.supply, totals.fuel + unit.fuel
		totals.supply_used, totals.fuel_used = totals.supply_used + unit.supply_used, totals.fuel_used + unit.fuel_used
	end
	for _, root in ipairs(roots) do
		count(root)
	end
	return { tag = tag, units = units, byId = byId, roots = roots, totals = totals }
end

-- A share as a whole percentage.
function Oob.Percent(share)
	return string.format("%d%%", math.floor((share or 0) * 100 + 0.5))
end

-- "L land, A air, V naval".
function Oob.Branches(counts)
	return string.format("%d land, %d air, %d naval", counts.land, counts.air, counts.naval)
end

return Oob
