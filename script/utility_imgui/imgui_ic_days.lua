-- IC Days page for the in-game ImGui utility.
--
-- The overlay calls Collect() from the render thread once a second, so this must
-- stay cheap and must never touch wx. Actions post commands exactly as the old
-- wxWidgets page did, so multiplayer behaviour is unchanged.

BiceLibGui = BiceLibGui or {}
BiceLibGui.ICDays = {}

-- The old page only worked once a player was picked on its Setup tab. Falling back
-- to the actual player makes the page useful without that step.
local function targetTag()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return nil
    end
    return CCountryDataBase.GetTag(tag)
end

local function collect()
    local tag = targetTag()
    if tag == nil then
        return { available = false, reason = "No player country" }
    end

    local country = tag:GetCountry()
    if country == nil then
        return { available = false, reason = "No country for tag" }
    end

    local variables = country:GetVariables()
    local daysLeft = variables:GetVariable(CString("IC_days_spent")):Get()
    local baseIc = variables:GetVariable(CString("BaseIC")):Get()
    local investment = variables:GetVariable(CString("event_unit_investment")):Get()

    return {
        available = true,
        tag = tostring(tag),
        ic_days_left = math.max(daysLeft, 0),
        base_ic = baseIc,
        investment = investment,
        daily_reduction = Utils.Round((baseIc * investment) / 100),
    }
end

-- Wrapped so a Lua level error (no session, missing variable) shows up as text on
-- the page instead of an error the overlay can only report generically. Note this
-- cannot catch a fault inside the game's own code, which is why the page does not
-- refresh until asked.
function BiceLibGui.ICDays.Collect()
    local ok, result = pcall(collect)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

function BiceLibGui.ICDays.SetInvestment(investmentMult)
    local tag = targetTag()
    if tag == nil then
        return
    end

    local command = CSetVariableCommand(tag, CString("event_unit_investment"), CFixedPoint(investmentMult))
    CCurrentGameState.Post(command)
end
