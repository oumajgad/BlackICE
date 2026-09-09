-- Prod. Sliders AI page for the in-game ImGui utility.
--
-- The bodies are shared with the other two AI settings pages; see imgui_form.

local Form = require('imgui_form')

BiceLibGui = BiceLibGui or {}
BiceLibGui.ProdSliders = {}

function BiceLibGui.ProdSliders.Collect()
    return Form.Collect(BiceData.ProdSliders)
end

function BiceLibGui.ProdSliders.SetValue(field, value)
    return Form.SetValue(BiceData.ProdSliders, field, value)
end

function BiceLibGui.ProdSliders.Discard()
    Form.Discard(BiceData.ProdSliders)
end

function BiceLibGui.ProdSliders.Commit()
    return Form.Commit(BiceData.ProdSliders)
end

function BiceLibGui.ProdSliders.SetActive(enabled)
    return Form.SetActive(BiceData.ProdSliders, enabled)
end
