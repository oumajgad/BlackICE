-- Miscellaneous switches: whether the mod's own decisions are offered to the player.
--
-- Port of utility/main/misc.lua, with the wx text controls removed.

BiceData = BiceData or {}
BiceData.Misc = {}

-- Both are inverted: 1 hides the decision.
local TRADE_DECISION = "disable_resource_trade_decision"
local MINES_DECISION = "disable_mines_expansion_decision"

--- The state of every switch on the page.
function BiceData.Misc.Collect()
    local vars, tag = BiceData.Country.Variables()
    if vars == nil then
        return nil, "No country selected"
    end

    return {
        tag = tag,
        tradeHidden = BiceData.Country.Get(vars, TRADE_DECISION) == 1,
        minesHidden = BiceData.Country.Get(vars, MINES_DECISION) == 1,
    }, nil
end

--- Hides or shows the strategic resource trade decisions.
function BiceData.Misc.SetTradeHidden(hidden)
    BiceData.Country.Set(BiceData.Players.CurrentTag(), TRADE_DECISION, hidden and 1 or 0)
end

--- Hides or shows the mine expansion decisions.
function BiceData.Misc.SetMinesHidden(hidden)
    BiceData.Country.Set(BiceData.Players.CurrentTag(), MINES_DECISION, hidden and 1 or 0)
end
