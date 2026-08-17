-- Strategic Trades and Global Market pages for the in-game ImGui utility.
--
-- One module for both: they read the same trade data, and the market page is only
-- useful alongside the country's own trades. In the wx utility the market was a
-- separate top level window; here it is simply another page.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Trades = {}

function BiceLibGui.Trades.Collect()
    local ok, result = pcall(function()
        local data, reason = BiceData.Trades.ForPlayer()
        if data == nil then
            return { available = false, reason = reason or "unavailable" }
        end
        return { available = true, tag = data.tag, buys = data.buys, sales = data.sales }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

--- The resource keys the market page can show, with display names.
function BiceLibGui.Trades.Resources()
    local ok, result = pcall(function()
        local rows = {}
        for _, key in ipairs(BiceData.StratResources.Names()) do
            table.insert(rows, { key = key, name = BiceData.StratResources.DisplayName(key) })
        end
        return { available = true, resources = rows }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

--- Countries with spare production of one resource.
function BiceLibGui.Trades.Market(resource)
    local ok, result = pcall(function()
        local data, reason = BiceData.Trades.Market(resource)
        if data == nil then
            return { available = false, reason = reason or "unavailable" }
        end
        return { available = true, resource = data.resource, rows = data.rows }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
