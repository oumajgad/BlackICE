G_TechsIcModValues = ReadFileAsArray("tfh\\mod\\BlackICE " .. UI.version .. "\\utility\\TechsIcModValues.txt", "=")
G_TechsIcEffValues = ReadFileAsArray("tfh\\mod\\BlackICE " .. UI.version .. "\\utility\\TechsIcEffValues.txt", "=")
G_TechsResEffValues = ReadFileAsArray("tfh\\mod\\BlackICE " .. UI.version .. "\\utility\\TechsResEffValues.txt", "=")
G_TechsSuppThrouValues = ReadFileAsArray("tfh\\mod\\BlackICE " .. UI.version .. "\\utility\\TechsSuppThrouValues.txt", "=")
-- Utils.INSPECT_TABLE(G_TechsIcEffValues)
-- Utils.INSPECT_TABLE(G_TechsResEffValues)

--- Minister tech decay doesn't work because a "+=" is actually a "=" in the source. This fixes it.
-- function PatchMinisterTechDecay()
--     --print(ReadHex("hoi3_tfh.exe", 0xDD7EC, 10))
--     WriteHex("hoi3_tfh.exe", 0xDD7ED, "0x01")
--     --print(ReadHex("hoi3_tfh.exe", 0xDD7EC, 10))
-- end
function IsPatchMinisterTechDecayApplied()
    local fixed_hex = "01"
    local current = ReadHex("hoi3_tfh.exe", 0xDD7ED, 1)
    return fixed_hex == current
end

--- When a country switches from war to peace all the War Exhaustion gets added to neutrality
--- WE is not used in events, instead its mirrored as a country variable.
--- To keep the minister tooltip they need to use it, so to avoid neutrality gain we disable that part with these bytes
-- function PatchMinisterWarExhaustionNeutralityReset()
--     local hex = "0x3BC37E1153518BCC8919E868F3010090909090909083BF6801"
--     --print(ReadHex("hoi3_tfh.exe", 0xDC009, 25))
--     WriteHex("hoi3_tfh.exe", 0xDC009, hex)
--     --print(ReadHex("hoi3_tfh.exe", 0xDC009, 25))
-- end
function IsPatchMinisterWarExhaustionNeutralityResetApplied()
    local fixed_hex = "3B C3 7E 11 53 51 8B CC 89 19 E8 68 F3 01 00 90 90 90 90 90 90 83 BF 68 01"
    local current = ReadHex("hoi3_tfh.exe", 0xDC009, 25)
    return fixed_hex == current
end

--- Podcats LAA patch
-- function PatchLargeAddressAware()
--     WriteHex("hoi3_tfh.exe", 0x138, "0x9165E5")
--     WriteHex("hoi3_tfh.exe", 0x146, "0x22")
--     WriteHex("hoi3_tfh.exe", 0x188, "0x67B1")
--     WriteHex("hoi3_tfh.exe", 0x1180524, "0x9165E5")
--     WriteHex("hoi3_tfh.exe", 0x11FB60D, "0x313A35363A3436")
--     WriteHex("hoi3_tfh.exe", 0x11FB618, "0x4A616E202033")
--     WriteHex("hoi3_tfh.exe", 0x11FB622, "0x33")
--     WriteHex("hoi3_tfh.exe", 0x120D77C, "0x6E68DAD73DE05F4394C72CD557D09411")
--     WriteHex("hoi3_tfh.exe", 0x12F34B4, "0x4C64E5")
-- end
function IsPatchLargeAddressAwareApplied()
    local fixed_hex = "91 65 E5"
    local current = ReadHex("hoi3_tfh.exe", 0x138, 3)
    return fixed_hex == current
end

--- Check for EXE patch status and set a variable to fire an ingame event
function DetermineExePatchStatus()
    -- Utils.LUA_DEBUGOUT(tostring(IsPatchLargeAddressAwareApplied()))
    -- Utils.LUA_DEBUGOUT(tostring(IsPatchMinisterTechDecayApplied()))
    -- Utils.LUA_DEBUGOUT(tostring(IsPatchMinisterWarExhaustionNeutralityResetApplied()))
    if not IsPatchLargeAddressAwareApplied() or not IsPatchMinisterTechDecayApplied() or not IsPatchMinisterWarExhaustionNeutralityResetApplied() then
        local omgTag = CCountryDataBase.GetTag("OMG")
        local alreadyFired = omgTag:GetCountry():GetVariables():GetVariable(CString("OmgExePatchStatusTrigger")):Get()
        if alreadyFired ~= 2 then
            for i, player in pairs(PlayerCountries) do -- fire it for everybody so people in MP can shame the one who fucked up
                local countryTag = CCountryDataBase.GetTag(player)
                local command = CSetVariableCommand(countryTag, CString("ExePatchStatus"), CFixedPoint(1))
                CCurrentGameState.Post(command)
            end
            local command = CSetVariableCommand(omgTag, CString("OmgExePatchStatusTrigger"), CFixedPoint(1))
            CCurrentGameState.Post(command)
        end
    end
end

--- Check for sprite deletion
function DetermineSpriteDeletionStatus()
    if CheckFileExists("gfx\\anims\\A7Vidle.xsm") then
        local omgTag = CCountryDataBase.GetTag("OMG")
        local alreadyFired = omgTag:GetCountry():GetVariables():GetVariable(CString("OmgSpriteDeletionStatusTrigger")):Get()
        if alreadyFired ~= 2 then
            for i, player in pairs(PlayerCountries) do -- fire it for everybody so people in MP can shame the one who fucked up
                local countryTag = CCountryDataBase.GetTag(player)
                local command = CSetVariableCommand(countryTag, CString("SpriteDeletionStatus"), CFixedPoint(1))
                CCurrentGameState.Post(command)
            end
            local command = CSetVariableCommand(omgTag, CString("OmgSpriteDeletionStatusTrigger"), CFixedPoint(1))
            CCurrentGameState.Post(command)
        end
    end
end
