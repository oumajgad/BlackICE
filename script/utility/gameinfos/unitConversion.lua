P = {}


local data = nil
local function fillData()
    data = {}
    local path = "tfh\\mod\\BlackICE " .. UI.version .. "\\script\\utility\\gameinfos\\unitConversion.csv"
    local temp = CsvParser.parseFile(path, ";")
    for k, v in pairs(temp) do
        data[k] = {
            ["multiplier"] = v[1],
            ["unit"] = v[2]
        }
    end
end



function P.GetAndConvertEffect(key, value)
    if data == nil then
        fillData()
    end

    if data ~= nil and data[key] ~= nil then
        local val = tostring(value * data[key]["multiplier"])
        return string.format("%.2f", val) .. data[key]["unit"]
    end

    Utils.LUA_DEBUGOUT("Couldnt find unit conversion: " .. key)
    return tostring(value)
end

return P