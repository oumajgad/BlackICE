-- Strategic resources tab.
--
-- The resource list, the balance offset and the inverted sales variable live in
-- BiceData.StratResources, shared with the ImGui utility. This keeps the wx half:
-- three or four controls per resource, named after it.

-- The control names follow the resource name with its first letter capitalised, so the
-- four per resource are built rather than listed. Only chromite breaks nothing here -
-- if a future resource does, give it an entry of its own.
local function controlName(resource, suffix)
    return "m_textCtrl" .. string.upper(string.sub(resource, 1, 1)) ..
        string.sub(resource, 2) .. suffix
end

local function setControl(resource, suffix, value)
    local control = UI[controlName(resource, suffix)]
    if control ~= nil then
        control:SetValue(value)
    end
end

-- Called each update
function GetStratResourceValues()
    local data = BiceData.StratResources.Collect()
    if data == nil then
        return
    end

    for _, row in ipairs(data.rows) do
        setControl(row.key, "Balance", tostring(row.balance))
        setControl(row.key, "Sales", tostring(row.sell))
        setControl(row.key, "Buys", tostring(row.buy))
    end
end

-- Called from button press
function DeactivateResourceSelling(desiredState, resource)
    if desiredState ~= true and desiredState ~= false then
        return
    end

    -- The provider takes "may sell", which is the opposite of what this button says.
    BiceData.StratResources.SetSelling(resource, not desiredState)
    -- Shown at once rather than read back: the command is only queued, so the game
    -- still reports the old state for a moment.
    SetResourceSaleStatesText(desiredState and "Stopped" or "Selling", resource)
end

-- Called each refresh and once at country selection
function GetAndSetResourceSaleStates()
    local data = BiceData.StratResources.Collect()
    if data == nil then
        return
    end

    for _, row in ipairs(data.rows) do
        SetResourceSaleStatesText(row.selling and "Selling" or "Stopped", row.key)
    end
end

-- Called from internal
function SetResourceSaleStatesText(state, resource)
    setControl(resource, "SaleActive", state)
end
