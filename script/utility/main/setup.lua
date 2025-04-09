-- Called once at start
function DeterminePlayers()
    G_PlayerCountries = {} -- Reset this each time so we don't grow the list each time GetPlayers is pressed
    local playercount = 0
    for tag, countryTag in pairs(GetCountryIterCacheDict()) do
        if CCurrentGameState.IsPlayer( countryTag ) then
            -- Utils.LUA_DEBUGOUT("Player --- " .. playercount .. " --- " .. tag )
            playercount = playercount + 1
            table.insert(G_PlayerCountries, tag)
        end
    end
    UI.player_choice:Clear()
    UI.player_choice:Append(G_PlayerCountries)
end

-- Function to check if a player has disabled the hosts ability to check out his country during a MP game
-- will return false if disabled
function CheckPlayerAllowsSelection(player)
    local playerCountry = CCountryDataBase.GetTag(player)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_gui_access")):Get() == 1 then
        G_PlayerCountry = nil
        return false
    end

    return true
end
