local P = {}

PdxParser = P

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")

local function next_char(str, idx, set, negate)
    for i = idx, #str do
        local chr = str:sub(i, i)
        if (chr == "#") then
            -- Skip until a new line begins
            local x = string.find(str, "\n", i)
            return next_char(str, x, set, negate)
        elseif set[chr] ~= negate then
            return i
        end
    end
    return #str + 1
end

local types = {
    object = 0, pair = 1, list = 2
}

local function determine_type(str, i)
    local j = next_char(str, i, space_chars, true)
    local chr = str:sub(j,j)
    if chr == "=" then
        j = next_char(str, j + 1 , space_chars, true)
        chr = str:sub(j,j)
        if chr == "{" then
            local closing = string.find(str, "}", j)
            if not string.find(str:sub(j, closing), "=") then
                return types.list
            end
            return types.object
        else
            return types.pair
        end
    else
        return types.list
    end
end

local function parse_string(str, i)
    local res = ""
    local hasQuote = false
    local current = i
    local start = current
    if (str:sub(i,i) == '"') then
        current = i + 1
        hasQuote = true
    end
    while current <= #str do
        local chr = str:sub(current,current)
        if (space_chars[chr] == true and hasQuote == false)
                or (chr == "}" and hasQuote == false)
                or (chr == "=" and hasQuote == false)
                or (chr == '"' and hasQuote == true)
                or (chr == "#") then -- End of string variations
            if (hasQuote) then
                -- with quotes start 1 character later and return the index 1 character later
                res = res .. str:sub(start + 1, current - 1)
                return res , current + 1
            else
                res = res .. str:sub(start, current - 1)
                return res, current
            end
        end
        current = current + 1
    end
end

local function parse_list(str, i)
    local res = {}
    while true do
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i,i)
        if (chr == "{") then
            i = next_char(str, i + 1, space_chars, true)
            chr = str:sub(i,i)
        end
        if (chr == "}") then
            i = i + 1
            return res, i
        end
        local value
        value, i = parse_string(str, i)
        table.insert(res, value)
    end
end

-- some keys can be lower or uppercase -> use this table to normalize them
local caseOverrides = {
    ["not"] = "NOT",
    ["or"] = "OR",
    ["and"] = "AND",
    ["tag"] = "TAG",
    ["this"] = "THIS",
    ["from"] = "FROM",
    ["limit"] = "LIMIT",
}

local function parse_object(str, i, doAsList, level)
    local res = {}
    while true do
        -- print("level: " .. level .. "\n")
        -- print(Utils.TABLE_TO_STRING(res))

        local key, val
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i,i)
        -- print("i: " .. i .. " = " .. "'" .. str:sub(i,i) .. "'")
        if (chr == "{") then
            -- makes sure we enter the object
            i = next_char(str,i + 1, space_chars, true)
            chr = str:sub(i,i)
        end
        -- print("i: " .. i .. " = " .. "'" .. str:sub(i,i) .. "'")
        if (chr == "}") then
            -- object has ended, return it
            return res, i + 1
        end

        key, i = parse_string(str, i)

        if caseOverrides[string.lower(key)] ~= nil then
            key = caseOverrides[string.lower(key)]
        end

        -- local chr = str:sub(i,i)
        -- print(key)
        -- print("i: " .. i .. " = " .. "'" .. chr .. "'")
        local value_type = determine_type(str, i)
        i = next_char(str, i, space_chars, true)    -- should be '=' at all times
        -- print("value_type: " .. value_type)
        -- local chr = str:sub(i,i)
        -- print("i: " .. i .. " = " .. "'" .. chr .. "'")

        if (value_type == types.object) then
            i = next_char(str, i + 1, space_chars, true)    -- i + 1 so we move on to the opening '{' of the object
            val, i = parse_object(str, i, false, level + 1)
            if doAsList then
                table.insert(res, {[key]=val})
            else
                -- print("\n")
                -- print(key)
                -- print("val: " .. Utils.TABLE_TO_STRING(val))
                -- print("res[key]: " .. Utils.TABLE_TO_STRING(res[key]))
                if res[key] ~= nil then
                    local temp = res[key]
                    -- print("temp: " .. Utils.TABLE_TO_STRING(temp))
                    res[key] = {}
                    table.insert(res[key], val)
                    -- check if this "table" is an array of objects or a single object
                    -- arrays will not be nil
                    if temp[1] == nil then
                        table.insert(res[key], temp)
                    else
                        for k, v in pairs(temp) do
                            table.insert(res[key], v)
                        end
                    end
                else
                    res[key] = val
                end
                -- print("res[key]: " .. Utils.TABLE_TO_STRING(res[key]))
            end

        elseif (value_type == types.list) then
            i = next_char(str, i + 1, space_chars, true)    -- i + 1 so we move on to the opening '{' of the list
            val, i = parse_list(str, i)
            res[key] = val

        elseif (value_type == types.pair) then
            i = next_char(str, i + 1, space_chars, true)    -- i + 1 so we move on to the first character of the value
            val, i = parse_string(str, i)
            if res[key] ~= nil then             -- At many points keys can be repeated to create a list of values, so this turns our key-value into key-list
                local temp = res[key]
                res[key] = {}
                table.insert(res[key], val)
                if type(temp) == "table" then
                    for k, v in pairs(temp) do
                        table.insert(res[key], v)
                    end
                else
                    table.insert(res[key], temp)
                end
            else
                res[key] = val
            end
        end
        -- print(Utils.TABLE_TO_STRING(res))
    end
end

--- Decodes a PdxScript object-string into a LUA table
--- Make sure the string is wrapped by "{\n" and "\n}"
function P.parse(str, asList)
    return parse_object(str, 1, asList, 0)
end

function P.parseFile(filePath, asList)
	local file, err = io.open(filePath, "r")
    -- Utils.LUA_DEBUGOUT(filePath)
	if file ~= nil then
        local linesString = "{\n" .. file:read("*a") .. "\n}"
        local decoded = PdxParser.parse(linesString, asList)
		file:close()
        return decoded
	end
	if err ~= nil then
		Utils.LUA_DEBUGOUT(err)
	end
end



return PdxParser