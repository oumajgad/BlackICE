-- Custom trade AI: per resource buffers and the caps that decide when it sells.
--
-- Port of utility/main/trade_ai.lua, with the wx text controls removed.
--
-- Values are staged rather than posted one at a time: the caller sets each field, then
-- Commit posts the whole set followed by the flag that tells the AI to pick them up.
-- Half an edit reaching the game would have it trading on a mix of old and new limits.

BiceData = BiceData or {}
BiceData.TradeAi = {}

local PREFIX = "zzDsafe_TradeAi_"
local USES = "zzDsafe_usesCustomTradeAi"
local ACTIVE = "zzDsafe_CustomTradeAiActive"
local WANTS_CHANGE = "zzDsafe_WantsToChangeCustomTradeAi"

-- In the order the wx page listed them. The numbers are the defaults its controls
-- started with, used until the country has been configured once.
--
-- Money has no caps - it is never stockpiled - and supplies are left out entirely: the
-- wx page posted fixed values for them because the AI ignores them.
local RESOURCES = {
    { key = "MONEY",          name = "Money",     buffer = 1 },
    { key = "FUEL",           name = "Fuel",      buffer = 1,    saleCap = 30000, cancelCap = 20000 },
    { key = "ENERGY",         name = "Energy",    buffer = 5,    saleCap = 40000, cancelCap = 30000 },
    { key = "METAL",          name = "Metal",     buffer = 2.5,  saleCap = 20000, cancelCap = 15000 },
    { key = "RARE_MATERIALS", name = "Rares",     buffer = 1,    saleCap = 10000, cancelCap = 7500 },
    { key = "CRUDE_OIL",      name = "Crude Oil", buffer = 0.25, saleCap = 20000, cancelCap = 15000 },
}

local MAX_DAILY_SELL_DEFAULT = 50

-- Field name -> true. A whitelist rather than a free hand at the variable namespace, so
-- a mistyped field cannot quietly create a variable the AI never reads.
local fields = nil

local function knownFields()
    if fields ~= nil then
        return fields
    end

    fields = { MaxDailySell = true }
    for _, resource in ipairs(RESOURCES) do
        fields[resource.key .. "_Buffer"] = true
        if resource.saleCap ~= nil then
            fields[resource.key .. "_BufferSaleCap"] = true
            fields[resource.key .. "_BufferCancelCap"] = true
        end
    end
    return fields
end

local staged = {}

local function variables()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return nil, nil
    end

    local country = CCountryDataBase.GetTag(tag):GetCountry()
    if country == nil then
        return nil, nil
    end
    return country:GetVariables(), tag
end

--- The resource keys and their display names, in page order.
function BiceData.TradeAi.Resources()
    return RESOURCES
end

--- Current settings, or the wx defaults if this country has never been configured.
function BiceData.TradeAi.Collect()
    local vars, tag = variables()
    if vars == nil then
        return nil, "No country selected"
    end

    -- Before the first Commit the variables are all zero, and showing those would
    -- invite applying them - which stops the AI trading at all.
    local configured = vars:GetVariable(CString(USES)):Get() == 1

    local rows = {}
    for _, resource in ipairs(RESOURCES) do
        local row = {
            key = resource.key,
            name = resource.name,
            hasCaps = resource.saleCap ~= nil,
        }

        if configured then
            row.buffer = vars:GetVariable(CString(PREFIX .. resource.key .. "_Buffer")):Get()
            if row.hasCaps then
                row.saleCap = vars:GetVariable(CString(PREFIX .. resource.key .. "_BufferSaleCap")):Get()
                row.cancelCap = vars:GetVariable(CString(PREFIX .. resource.key .. "_BufferCancelCap")):Get()
            end
        else
            row.buffer = resource.buffer
            row.saleCap = resource.saleCap or 0
            row.cancelCap = resource.cancelCap or 0
        end

        table.insert(rows, row)
    end

    local maxDailySell = MAX_DAILY_SELL_DEFAULT
    if configured then
        maxDailySell = vars:GetVariable(CString(PREFIX .. "MaxDailySell")):Get()
    end

    return {
        tag = tag,
        active = vars:GetVariable(CString(ACTIVE)):Get() == 1,
        configured = configured,
        maxDailySell = maxDailySell,
        rows = rows,
    }, nil
end

--- Stages one field. Nothing reaches the game until Commit.
function BiceData.TradeAi.SetValue(field, value)
    if field == nil or not knownFields()[field] then
        return false, "Unknown field: " .. tostring(field)
    end
    staged[field] = value
    return true, nil
end

--- Posts everything staged, then asks the AI to reload it.
function BiceData.TradeAi.Commit()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return false, "No country selected"
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    for field, value in pairs(staged) do
        CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(PREFIX .. field), CFixedPoint(value)))

        -- The wx page drove BufferBuyCap from the same control as BufferCancelCap, so
        -- the two are kept equal here rather than exposing a field nothing sets.
        local resource = string.match(field, "^(.*)_BufferCancelCap$")
        if resource ~= nil then
            CCurrentGameState.Post(CSetVariableCommand(countryTag,
                CString(PREFIX .. resource .. "_BufferBuyCap"), CFixedPoint(value)))
        end
    end
    staged = {}

    -- Marks the country as configured, so Collect stops handing back defaults.
    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(USES), CFixedPoint(1)))
    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(WANTS_CHANGE), CFixedPoint(1)))
    return true, nil
end

--- Discards anything staged but not committed.
function BiceData.TradeAi.Discard()
    staged = {}
end

--- Switches the custom trade AI on or off.
function BiceData.TradeAi.SetActive(enabled)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    if enabled then
        CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(USES), CFixedPoint(1)))
    end
    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(ACTIVE),
        CFixedPoint(enabled and 1 or 0)))
end
