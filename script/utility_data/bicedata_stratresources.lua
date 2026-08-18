-- Strategic resources: stockpile balance, trade flows and whether the AI is allowed
-- to sell each one.
--
-- Port of utility/main/strat_resources.lua, with the wx text controls removed. The wx
-- page had three hand written controls per resource; here it is one table.

BiceData = BiceData or {}
BiceData.StratResources = {}

-- The mod's strategic resources, held in country variables rather than as real game
-- resources. Sorted rather than listed alphabetically by hand, so anything added later
-- lands in the right place on its own.
local RESOURCES = {
    "chromite", "aluminium", "rubber", "tungsten", "nickel",
    "copper", "zinc", "manganese", "molybdenum",
}
table.sort(RESOURCES)

--- The stockpile balance is stored offset by 1000 so it can hold negative values.
local BALANCE_OFFSET = 1000

local function displayName(resource)
    return string.upper(string.sub(resource, 1, 1)) .. string.sub(resource, 2)
end

--- The strategic resource keys, sorted. Shared with the Global Market page.
function BiceData.StratResources.Names()
    return RESOURCES
end

--- "chromite" -> "Chromite"
function BiceData.StratResources.DisplayName(resource)
    return displayName(resource)
end

--- Balance, sales, purchases and sale state for every strategic resource.
function BiceData.StratResources.Collect()
    local vars, tag = BiceData.Country.Variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local rows = {}
    for _, resource in ipairs(RESOURCES) do
        table.insert(rows, {
            key = resource,
            name = displayName(resource),
            balance = BiceData.Country.Get(vars, resource .. "_ActualBalance") - BALANCE_OFFSET,
            sell = BiceData.Country.Get(vars, resource .. "_trade_sell"),
            buy = BiceData.Country.Get(vars, resource .. "_trade_buy"),
            -- The variable is inverted: 1 means selling is switched off.
            selling = BiceData.Country.Get(vars, resource .. "_deactivate_sales") ~= 1,
        })
    end

    return { tag = tag, rows = rows }, nil
end

--- Allows or blocks the AI selling one resource.
function BiceData.StratResources.SetSelling(resource, enabled)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil or resource == nil then
        return
    end

    BiceData.Country.Set(tag, resource .. "_deactivate_sales", enabled and 0 or 1)
end
