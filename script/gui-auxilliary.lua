
function GuiRefreshLoop()
    if wx ~= nil then
        NotifySaveLoaded()
    end
end

function NotifySaveLoaded()
    if SaveLoaded == true and NotifySaveLoadedFlag ~= true then
        Utils.LUA_DEBUGOUT("SAVELOADED")
        UI.m_textCtrl3:SetValue("Save Loaded")
        NotifySaveLoadedFlag = true
    end
end



function DeterminePlayer()
    local playercount = 0
    for tag, countryTag in pairs(CountryIterCacheDict) do
        if CCurrentGameState.IsPlayer( countryTag ) then
            playercount = playercount + 1
            PlayerCountry = tag
        end
        if playercount > 1 then
            PlayerCountry = nil
        end
    end
end

