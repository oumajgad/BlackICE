-- Setup tab.
--
-- Who is playing, and whether a player will let the host look at their country, both
-- live in BiceData.Players and are shared with the ImGui utility. G_PlayerCountries is
-- still a global because the rest of this utility reads it; Determine fills it.

-- Called once at start
function DeterminePlayers()
    local players = BiceData.Players.Determine()

    UI.player_choice:Clear()
    UI.player_choice:Append(players)
end

-- Function to check if a player has disabled the hosts ability to check out his country
-- during a MP game. Will return false if disabled.
function CheckPlayerAllowsSelection(player)
    if BiceData.Players.AllowsSelection(player) then
        return true
    end

    -- Cleared as this page always did, so the refresh loop stops working on a country
    -- it is no longer allowed to read.
    G_PlayerCountry = nil
    return false
end
