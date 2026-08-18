-- LS Sliders AI page for the in-game ImGui utility.
--
-- The bodies are shared with the other two AI settings pages; see imgui_form.

local Form = require('imgui_form')

BiceLibGui = BiceLibGui or {}
BiceLibGui.LsSliders = {}

function BiceLibGui.LsSliders.Collect()
    return Form.Collect(BiceData.LsSliders)
end

function BiceLibGui.LsSliders.SetValue(field, value)
    return Form.SetValue(BiceData.LsSliders, field, value)
end

function BiceLibGui.LsSliders.Discard()
    Form.Discard(BiceData.LsSliders)
end

function BiceLibGui.LsSliders.Commit()
    return Form.Commit(BiceData.LsSliders)
end

function BiceLibGui.LsSliders.SetActive(enabled)
    return Form.SetActive(BiceData.LsSliders, enabled)
end
