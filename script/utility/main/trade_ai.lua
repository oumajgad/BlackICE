-- Trade AI tab.
--
-- The variable names, the defaults and the staging live in BiceData.TradeAi, shared
-- with the ImGui utility. This keeps the wx half: which control holds which field.
--
-- The provider takes fields one at a time and posts them as one set on Commit, so a
-- half applied edit cannot reach the AI.

-- Provider resource key -> the word the controls are named after. They do not match
-- everywhere: the control for CRUDE_OIL is called Oil.
local RESOURCE_CONTROLS = {
    MONEY = "Money",
    FUEL = "Fuel",
    ENERGY = "Energy",
    METAL = "Metal",
    RARE_MATERIALS = "Rares",
    CRUDE_OIL = "Oil",
}

local function control(name)
    return UI[name]
end

local function resourceControl(resourceKey, suffix)
    return control("m_textCtrl_customTradeAi_" .. RESOURCE_CONTROLS[resourceKey] .. "_" .. suffix)
end

local function readNumber(widget, fallback)
    if widget == nil then
        return fallback
    end
    return tonumber(widget:GetValue()) or fallback
end

function SetCustomTradeAiStatusText(status)
    UI.m_textCtrl_customTradeAi1:SetValue(status and "Active" or "Inactive")
end

function DetermineCustomTradeAiStatus()
    local data = BiceData.TradeAi.Collect()
    if data == nil then
        return
    end
    SetCustomTradeAiStatusText(data.active)
end

--- Sends every control's value to the provider and asks it to apply them.
function SetCustomTradeAiValues()
    local data = BiceData.TradeAi.Collect()
    if data == nil then
        return
    end

    BiceData.TradeAi.Discard() -- anything staged by an abandoned attempt
    BiceData.TradeAi.SetValue("MaxDailySell",
        readNumber(control("m_textCtrl_CustomTradeAi_MaxDailySell"), data.maxDailySell))

    for _, row in ipairs(data.rows) do
        BiceData.TradeAi.SetValue(row.key .. "_Buffer",
            readNumber(resourceControl(row.key, "Buffer"), row.buffer))

        if row.hasCaps then
            BiceData.TradeAi.SetValue(row.key .. "_BufferSaleCap",
                readNumber(resourceControl(row.key, "BufferSaleCap"), row.saleCap))
            -- One control drives both the cancel and the buy cap, as it always has.
            BiceData.TradeAi.SetValue(row.key .. "_BufferCancelCap",
                readNumber(resourceControl(row.key, "BufferCancelCap"), row.cancelCap))
        end
    end

    BiceData.TradeAi.Commit()
end

function SetCustomTradeAiStatus()
    local data = BiceData.TradeAi.Collect()
    if data == nil then
        return
    end

    if data.active then
        BiceData.TradeAi.SetActive(false)
        SetCustomTradeAiStatusText(false)
        return
    end

    -- Switching on adopts what is on screen, as this page always did.
    SetCustomTradeAiValues()
    BiceData.TradeAi.SetActive(true)
    SetCustomTradeAiStatusText(true)
end

--- Fills the controls from the game, or from the defaults if it has never been set up.
function ReadCustomTradeAiValues()
    local data = BiceData.TradeAi.Collect()
    if data == nil or not data.configured then
        -- Unconfigured leaves the designer defaults the controls start with, exactly as
        -- before: writing zeros in would stop the AI trading at all.
        return
    end

    control("m_textCtrl_CustomTradeAi_MaxDailySell"):SetValue(
        string.format('%.0f', data.maxDailySell))

    for _, row in ipairs(data.rows) do
        resourceControl(row.key, "Buffer"):SetValue(string.format('%.2f', row.buffer))
        if row.hasCaps then
            resourceControl(row.key, "BufferSaleCap"):SetValue(string.format('%.0f', row.saleCap))
            resourceControl(row.key, "BufferCancelCap"):SetValue(string.format('%.0f', row.cancelCap))
        end
    end
end
