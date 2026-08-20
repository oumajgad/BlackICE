-- Puppets tab.
--
-- The vassal list, the focus names and the variables behind them live in
-- BiceData.Puppets, shared with the ImGui utility. This keeps the wx half: the two
-- choice controls and which puppet is selected in them.
--
-- SelectedPuppet stays a global, as the wx event handlers read it.

-- Called from button press
function TogglePuppetFocusDecision(desiredState)
    if desiredState ~= true and desiredState ~= false then
        return
    end

    -- The variable is inverted, and the provider owns that: true here means the
    -- decision is available to the player.
    BiceData.Puppets.SetFocusDecisionEnabled(desiredState)
end

-- Called each refresh
function GetAndAddPuppets()
    local puppets = BiceData.Puppets.List()
    if #puppets == 0 then
        return
    end

    UI.puppet_choice:Clear()
    UI.puppet_choice:Append(puppets)
end

-- Called from button press
function SetPuppetSelection()
    if UI.puppet_choice:GetSelection() >= 0 then
        SelectedPuppet = UI.puppet_choice:GetString(UI.puppet_choice:GetSelection())
        UI.set_puppet_text:SetValue(SelectedPuppet)
        SetPuppetFocusText(99)
    end
end

-- Called from button press
function SetPuppetFocus()
    if UI.puppet_focus_choice:GetSelection() >= 0 and SelectedPuppet ~= nil then
        -- The control lists the focuses in the order the game numbers them, from 1.
        local selectedFocusIndex = UI.puppet_focus_choice:GetSelection() + 1
        BiceData.Puppets.SetFocus(SelectedPuppet, selectedFocusIndex)
        SetPuppetFocusText(selectedFocusIndex)
    end
end

-- Called from internal. 99 means "whatever the puppet is set to now".
function SetPuppetFocusText(selection)
    if SelectedPuppet == nil then
        return
    end
    if selection == 99 then
        selection = BiceData.Puppets.Focus(SelectedPuppet)
    end

    UI.m_textCtrl4:SetValue(BiceData.Puppets.FocusName(selection))
end
