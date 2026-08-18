-- Trade AI page for the in-game ImGui utility.
--
-- The bodies are shared with the other two AI settings pages; see imgui_form.

local Form = require('imgui_form')

BiceLibGui = BiceLibGui or {}
BiceLibGui.TradeAi = {}

function BiceLibGui.TradeAi.Collect()
    return Form.Collect(BiceData.TradeAi)
end

function BiceLibGui.TradeAi.SetValue(field, value)
    return Form.SetValue(BiceData.TradeAi, field, value)
end

function BiceLibGui.TradeAi.Discard()
    Form.Discard(BiceData.TradeAi)
end

function BiceLibGui.TradeAi.Commit()
    return Form.Commit(BiceData.TradeAi)
end

function BiceLibGui.TradeAi.SetActive(enabled)
    return Form.SetActive(BiceData.TradeAi, enabled)
end
