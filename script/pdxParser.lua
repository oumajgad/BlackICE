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
    local j = i
    local k = j
    if (str:sub(i,i) == '"') then
        j = i + 1
        hasQuote = true
    end
    while j <= #str do
        local chr = str:sub(j,j)
        if (space_chars[chr] == true and hasQuote == false)
                or (chr == "}" and hasQuote == false)
                or (chr == '"' and hasQuote == true)
                or (chr == "#") then -- End of string variations
            if (hasQuote) then
                -- with qoutes start 1 character later and return the index 1 character later
                res = res .. str:sub(k + 1, j - 1)
                return res , j + 1
            else
                res = res .. str:sub(k, j - 1)
                return res, j
            end
        end
        j = j + 1
    end
end

local function parse_list(str, i)
    local res = {}
    while true do
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i,i)
        if (chr == "}") then
            i = i - 1
            return res, i
        end
        local value
        value, i = parse_string(str, i)
        table.insert(res, value)
    end
end

local function parse_object(str, i, doAsList)
    local res = {}
    while true do
        local key, val
        i = next_char(str, i + 1, space_chars, true)
        local chr = str:sub(i,i)
        if (chr == "{") then
            i = next_char(str,i + 1, space_chars, true)
        end
        if (chr == "}") then
            return res, i
        end

        key, i = parse_string(str, i)
        local value_type = determine_type(str, i)
        i = next_char(str, i, space_chars, true)

        if (value_type == types.object) then
            i = next_char(str, i + 1, space_chars, true)
            val, i = parse_object(str, i)
            if doAsList then
                table.insert(res, val)
            else
                if res[key] ~= nil then
                    local temp = res[key]
                    res[key] = {}
                    table.insert(res[key], temp)
                    table.insert(res[key], val)
                else
                    res[key] = val
                end
            end

        elseif (value_type == types.list) then
            i = next_char(str, i, space_chars, true)
            val, i = parse_list(str, i)
            table.insert(val, key)
            res = val

        elseif (value_type == types.pair) then
            i = next_char(str, i + 1, space_chars, true)
            val, i = parse_string(str, i)
            -- Create a list when keys are repeated
            if res[key] ~= nil then
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
    end
end

local function parse_list_objects(str, i)
    local res = {}
    while true do
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i,i)
        if (chr == "}") then
            i = i - 1
            return res, i
        end
        local value
        value, i = parse_object(str, i, true)
        table.insert(res, value)
    end
end

--- Decodes a PdxScript object-string into a LUA table
--- Make sure the string is wrapped by "{\n" and "\n}"
function P.parse(str)
    return parse_object(str, 1)
end

function P.parseFile(filePath)
	local file, err = io.open(filePath, "r")
	if file ~= nil then
        local linesString = "{\n" .. file:read("*a") .. "\n}"
        local decoded = PdxParser.parse(linesString)
		file:close()
        return decoded
	end
	if err ~= nil then
		Utils.LUA_DEBUGOUT(err)
	end
end


function P.parseListOfObjects(str)
    return parse_list_objects(str, 1)
end

function P.parseFileWithList(filePath)
    local file, err = io.open(filePath, "r")
    if file ~= nil then
        local linesString = "{\n" .. file:read("*a") .. "\n}"
        local decoded = PdxParser.parseListOfObjects(linesString)
        file:close()
        return decoded
    end
    if err ~= nil then
        Utils.LUA_DEBUGOUT(err)
    end
end

return PdxParser