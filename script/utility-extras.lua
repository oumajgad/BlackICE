--- Check for sprite deletion
function DetermineSpriteDeletionStatus()
    -- OpenHOI3 draws counters only and never loads the 3d sprite models, so there is no memory to win back there:
    -- the reminder (event 1109) is for the original alone.
    if G_OPENHOI then
        return
    end
    if CheckFileExists("gfx\\anims\\A7Vidle.xsm") then
        local omgTag = CCountryDataBase.GetTag("OMG")
        local alreadyFired = omgTag:GetCountry():GetVariables():GetVariable(CString("OmgSpriteDeletionStatusTrigger")):Get()
        if alreadyFired ~= 2 then
            for i, player in pairs(G_PlayerCountries) do -- fire it for everybody so people in MP can shame the one who fucked up
                local countryTag = CCountryDataBase.GetTag(player)
                local command = CSetVariableCommand(countryTag, CString("SpriteDeletionStatus"), CFixedPoint(1))
                CCurrentGameState.Post(command)
            end
            local command = CSetVariableCommand(omgTag, CString("OmgSpriteDeletionStatusTrigger"), CFixedPoint(1))
            CCurrentGameState.Post(command)
        end
    end
end

local biceLibLoadStatusAlreadyFired = false
function DetermineBiceLibLoadStatus()
    -- OpenHOI3 cannot load the DLL and does not need it - what BiceLib adds its enhanced mode has itself - so the
    -- warning (event 1108) is for the original alone.
    if G_OPENHOI then
        return
    end
    if BiceLib or biceLibLoadStatusAlreadyFired then
        return
    end
    local omgTag = CCountryDataBase.GetTag("OMG")
    local command = CSetVariableCommand(omgTag, CString("OmgBiceLibLoadStatusTrigger"), CFixedPoint(1))
    CCurrentGameState.Post(command)
    biceLibLoadStatusAlreadyFired = true
end