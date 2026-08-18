-- Strategic resource trades: the country's own buys and sales, and the global market
-- of who has spare capacity to sell.
--
-- Port of utility/main/strat_trades.lua and the grid logic in strat_global_market.lua.
--
-- Both read GlobalTradesData, which ai_variable.lua maintains. That module loads
-- regardless of which utility is enabled, so nothing here depends on the wx one.

BiceData = BiceData or {}
BiceData.Trades = {}

local function currentDay()
    return CCurrentGameState.GetCurrentDate():GetTotalDays()
end

--- The selected country's active trades, split into what it buys and what it sells.
--- Both lists are ordered by how soon they expire.
function BiceData.Trades.ForPlayer()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return nil, "No country selected"
    end
    if GlobalTradesData == nil then
        return nil, "Trade data not available yet"
    end

    local today = currentDay()
    local buys, sales = {}, {}

    for _, country in pairs(GlobalTradesData) do
        for _, trade in pairs(country["trades"] or {}) do
            local row = {
                buyer = tostring(trade["buyer"]),
                seller = tostring(trade["seller"]),
                resource = tostring(trade["resource"]),
                expires_in = (trade["expiryDate"] or 0) - today,
            }
            if trade["buyer"] == tag then
                table.insert(buys, row)
            end
            if trade["seller"] == tag then
                table.insert(sales, row)
            end
        end
    end

    local bySoonest = function(a, b) return a.expires_in < b.expires_in end
    table.sort(buys, bySoonest)
    table.sort(sales, bySoonest)

    return { tag = tag, buys = buys, sales = sales }, nil
end

--- The trade for a seller and resource, used to report when its sales next free up.
local function findTrade(sellerTag, resource)
    for _, country in pairs(GlobalTradesData or {}) do
        for _, trade in pairs(country["trades"] or {}) do
            if trade["seller"] == sellerTag and trade["resource"] == resource then
                return trade
            end
        end
    end
    return nil
end

--- Every country with spare production of one resource, most capacity first.
function BiceData.Trades.Market(resource)
    if resource == nil or resource == "" then
        return nil, "No resource selected"
    end

    local today = currentDay()
    local rows = {}

    for tag, countryTag in pairs(GetCountryIterCacheDict()) do
        local variables = countryTag:GetCountry():GetVariables()
        -- Offset by 1000 like the other balances, and includes the country's puppets.
        local potential = BiceData.Country.Get(variables, resource .. "_building_balance") - 1000
        local sales = BiceData.Country.Get(variables, resource .. "_trade_sell")

        if potential > 0 then
            local nextExpiry = -1
            if sales > 0 then
                local trade = findTrade(tag, resource)
                if trade ~= nil then
                    nextExpiry = (trade["expiryDate"] or 0) - today
                end
            end

            table.insert(rows, {
                tag = tostring(tag),
                potential = potential,
                sales = sales,
                available = potential - sales,
                next_expiry = nextExpiry,
            })
        end
    end

    table.sort(rows, function(a, b) return a.potential > b.potential end)
    return { resource = resource, rows = rows }, nil
end
