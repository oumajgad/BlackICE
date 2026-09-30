--- Check for sprite deletion
function DetermineSpriteDeletionStatus()
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
    if BiceLib or biceLibLoadStatusAlreadyFired then
        return
    end
    local omgTag = CCountryDataBase.GetTag("OMG")
    local command = CSetVariableCommand(omgTag, CString("OmgBiceLibLoadStatusTrigger"), CFixedPoint(1))
    CCurrentGameState.Post(command)
    biceLibLoadStatusAlreadyFired = true
end