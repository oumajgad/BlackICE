-- Country summary: the effective values behind the country's industry, research and
-- combat, with the technology contributions the game's Lua API does not expose folded
-- in.
--
-- Port of GetPlayerModifiers in utility/main/country_info.lua, with the wx text
-- controls replaced by returned rows. Live data, so nothing is cached.

BiceData = BiceData or {}
BiceData.CountryInfo = {}

--- Sums the per level contribution of every tech affecting one modifier.
local function techContribution(country, effectName)
    local total = 0
    local values = BiceData.Techs.ModifierValues()[effectName]
    if values == nil then
        return total
    end

    for tech, perLevel in pairs(values) do
        -- Through PlayerLevel so the nil technology guard applies: not every key that
        -- looks like a tech is one, and GetLevel(nil) faults inside the game.
        total = total + (perLevel * BiceData.Techs.PlayerLevel(tech))
    end
    return total
end

--- Everything the Country Info page shows, grouped for display.
function BiceData.CountryInfo.Collect()
    local country, tag = BiceData.Country.Selected()
    if country == nil then
        return nil, "No country selected"
    end

    local variables = country:GetVariables()
    local modifiers = country:GetGlobalModifier()

    local baseIc = country:GetMaxIC()

    local offmapIc = 0
    local generalModifiers = nil
    if BiceLib ~= nil then
        offmapIc = BiceLib.GameInfo.getCountryOffmapIc(tag) or 0
        -- The wx page passed a hardcoded "GER" here, so every country was shown
        -- Germany's trickleback. Uses the selected country now.
        generalModifiers = BiceLib.GameInfo.getCountryGeneralModifiers(tag)
    end

    local trickleback = nil
    if generalModifiers ~= nil and generalModifiers["MODIFIER_TRICKLEBACK"] ~= nil then
        trickleback = (generalModifiers["MODIFIER_TRICKLEBACK"] * 0.001)
            + techContribution(country, "casualty_trickleback")
    end

    local icModifier = modifiers:GetValue(CModifier._MODIFIER_GLOBAL_IC_):Get()
        + techContribution(country, "ic_modifier")
    local repairModifier = modifiers:GetValue(CModifier._MODIFIER_UNIT_REPAIR_):Get()
        + techContribution(country, "repair_rate")
    local orgRegain = modifiers:GetValue(CModifier._MODIFIER_ORG_REGAIN_):Get()
        + techContribution(country, "org_regain")

    -- Techs reduce the delay rather than add to it.
    local attackDelay = defines.military.UNIT_ATTACK_DELAY - techContribution(country, "attack_delay")

    local globalSupplies = modifiers:GetValue(CModifier._MODIFIER_GLOBAL_SUPPLIES_):Get()
    local supplyFactories = BiceData.Country.Get(variables, "supplies_factory_count") * 0.035
    local suppliesPerIc = (1 + globalSupplies + techContribution(country, "ic_to_supplies")
        + supplyFactories) * defines.economy.IC_TO_SUPPLIES

    local warExhaustionMonthly = modifiers:GetValue(CModifier._MODIFIER_WAR_EXHAUSTION_):Get()
    if country:IsAtWar() then
        warExhaustionMonthly = warExhaustionMonthly + 20
    end

    local function percent(value)
        return string.format('%.02f%%', value * 100)
    end
    local function number(value, decimals)
        return string.format('%.0' .. (decimals or 2) .. 'f', value)
    end

    -- Every row carries the number as well as the text. The ImGui page shows value and
    -- ignores raw; the wx page formats raw itself, because its labels already carry the
    -- unit that percent() writes into the string.
    local icEfficiency = BiceData.Country.Get(variables, "IcEffVariable")
    local researchEfficiency = BiceData.Country.Get(variables, "ResEffVariable")
    local supplyThroughput = BiceData.Country.Get(variables, "SuppThrouVariable")
    local startingExperience = modifiers:GetValue(CModifier._MODIFIER_UNIT_START_EXPERIENCE_):Get()
    local currentWarExhaustion = BiceData.Country.Get(variables, "war_exhaustion")

    return {
        tag = tag,
        sections = {
            {
                name = "Industry",
                rows = {
                    { label = "Base IC", value = number(baseIc, 0), raw = baseIc },
                    { label = "Offmap IC", value = number(offmapIc, 0), raw = offmapIc },
                    { label = "IC modifier", value = percent(icModifier), raw = icModifier },
                    { label = "IC efficiency", value = number(icEfficiency), raw = icEfficiency },
                    { label = "Supplies per IC", value = number(suppliesPerIc), raw = suppliesPerIc },
                },
            },
            {
                name = "Research and supply",
                rows = {
                    { label = "Research efficiency", value = number(researchEfficiency), raw = researchEfficiency },
                    { label = "Supply throughput", value = number(supplyThroughput), raw = supplyThroughput },
                },
            },
            {
                name = "Military",
                rows = {
                    { label = "Repair efficiency", value = percent(repairModifier), raw = repairModifier },
                    { label = "Org regain", value = percent(orgRegain), raw = orgRegain },
                    { label = "Attack delay", value = number(attackDelay, 0), raw = attackDelay },
                    { label = "Starting experience", value = number(startingExperience), raw = startingExperience },
                    -- nil raw where the game would not say, which the pages show as text.
                    { label = "Trickleback", value = trickleback ~= nil and percent(trickleback) or "unavailable",
                      raw = trickleback },
                },
            },
            {
                name = "War exhaustion",
                rows = {
                    { label = "Monthly", value = number(warExhaustionMonthly), raw = warExhaustionMonthly },
                    { label = "Current", value = string.format('%.1f', currentWarExhaustion),
                      raw = currentWarExhaustion },
                },
            },
        },
    }, nil
end

--- Every row from Collect, flattened to label -> row, for a UI with one control per
--- value rather than a list.
function BiceData.CountryInfo.ByLabel()
    local data, reason = BiceData.CountryInfo.Collect()
    if data == nil then
        return nil, reason
    end

    local rows = {}
    for _, section in ipairs(data.sections) do
        for _, row in ipairs(section.rows) do
            rows[row.label] = row
        end
    end
    return rows, nil
end
