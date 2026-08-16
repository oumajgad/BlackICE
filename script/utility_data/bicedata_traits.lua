-- Trait definitions, effects and triggers.
--
-- Port of the pure logic in utility/gameinfos/traits.lua, with the wx calls removed.
-- Parsed lazily and cached for the session: the files do not change at runtime.

BiceData = BiceData or {}
BiceData.Traits = {}

local function modPath(relative)
    return "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\" .. relative
end

local traits = nil     -- key -> raw definition
local choices = nil    -- sorted "Translated name [key]"
local triggers = nil   -- key -> list of gainable_trait blocks

-- The game's own names for these do not read well in a utility, so they are mapped.
local terrainEffectNames = {
    terrain_speed = "Speed",
    terrain_attack = "Attack",
    terrain_defence = "Defence",
}

local function translateTerrainEffects(terrainEffects)
    local res = {}
    for _, effect in pairs(terrainEffects) do
        table.insert(res, {
            type = BiceData.Translations.Get(effect["type"]) or effect["type"],
            value = string.format("%.2f", effect["value"] * 100) .. "%",
        })
    end
    table.sort(res, function(a, b)
        return string.upper(a["type"]) < string.upper(b["type"])
    end)
    return res
end

local function translateTraitEffects(trait)
    local res = {}
    for key, value in pairs(trait) do
        if key ~= "allowed_leader" then
            if type(value) ~= "table" then
                local translated = BiceData.Translations.Get(string.upper(key), "TRAIT_") or key
                res[translated] = BiceData.Translations.ConvertEffect(key, value)
            else
                -- A single terrain block parses as one table rather than a list of them.
                local list = value
                for _, entry in pairs(value) do
                    if type(entry) ~= "table" then
                        list = { value }
                        break
                    end
                end
                res[terrainEffectNames[key]] = translateTerrainEffects(list)
            end
        end
    end
    return res
end

local function fillData()
    if traits ~= nil then
        return
    end

    traits = PdxParser.parseFile(modPath("common\\traits.txt"))

    choices = {}
    for key in pairs(traits) do
        table.insert(choices, BiceData.Translations.Choice(key))
    end
    table.sort(choices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)

    triggers = {}
    local parsed = PdxParser.parseFile(modPath("common\\gainable_traits.txt"))
    local list = parsed ~= nil and parsed["gainable_trait"] or nil
    if list ~= nil then
        for _, entry in pairs(list) do
            local name = entry["trait"]
            if name ~= nil then
                if triggers[name] == nil then
                    triggers[name] = {}
                end
                table.insert(triggers[name], entry)
                -- Removed so the trait name isn't repeated inside every trigger dump.
                table.removeEntryByKey(entry, "trait")
            end
        end
    end
end

--- Sorted "Translated name [key]" for every trait.
function BiceData.Traits.Choices()
    fillData()
    return choices
end

--- Raw definition for a trait key, or nil.
function BiceData.Traits.Get(key)
    fillData()
    return traits[key]
end

--- Formatted effect text for a trait key.
--- @param noAllowedLeader skip the allowed_leader list, which is noise when the
---        leader is already known.
function BiceData.Traits.DumpEffects(key, noAllowedLeader)
    fillData()
    local trait = traits[key]
    if trait == nil then
        return ""
    end

    local translated = { allowed_leader = trait["allowed_leader"] }
    for effect, value in pairs(translateTraitEffects(trait)) do
        translated[effect] = value
    end

    local sorted = Utils.PushTablesToEndAndSort(translated)

    -- PushTablesToEndAndSort orders alphabetically; allowed_leader is pulled back to
    -- the front because it is the thing you look at first.
    local order = getmetatable(sorted)["order"]
    for _, name in ipairs(order) do
        if name == "allowed_leader" then
            order[name] = nil
        end
    end
    if noAllowedLeader then
        sorted["allowed_leader"] = nil
    else
        table.insert(order, 1, "allowed_leader")
    end

    return Utils.DumpByMetatableOrder(sorted)
end

--- Formatted trigger text for a trait key, empty when it has none.
function BiceData.Traits.DumpTriggers(key)
    fillData()
    if triggers[key] == nil then
        return ""
    end

    local sorted = {}
    for name, value in Utils.OrderedTable(triggers[key]) do
        sorted[name] = value
    end
    return Utils.Dump(sorted)
end
