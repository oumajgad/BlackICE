local P = {}

PdxParser = P

local DEBUG = false
local CURRENT_FILE = ""
local CURRENT_FILE_CONTENT = ""

local function debug_out(message, idx, throw)
    if throw then
        local sub = CURRENT_FILE_CONTENT:sub(1, idx)
        local _, line = sub:gsub("\n", "")
        line = line - 1
        local temp_current = Utils.SplitString(sub, "\n")
        local temp_full_line = Utils.SplitString(CURRENT_FILE_CONTENT, "\n")
        local full_line = temp_full_line[#temp_current]
        local msg = CURRENT_FILE .. ": "
            .. "line=" .. tostring(line) .. ": "
            .. message .. " --- full line:" .. full_line
        Utils.LUA_DEBUGOUT(msg)
        error(msg)
    end
    if DEBUG then
        Utils.LUA_DEBUGOUT(CURRENT_FILE .. ": " .. message)
    end
end


local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")

local function next_char(str, idx)
    local i = idx
    while i <= #str do
        local chr = str:sub(i, i)
        if (chr == "#") then
            -- Skip until a new line begins
            local x = string.find(str, "\n", i)
            if x then
                i = x
            end
        elseif space_chars[chr] == nil then
            debug_out("chr: " .. chr, i, false)
            return chr, i
        else
            i = i + 1
        end
    end
    debug_out("Failed to find next char", idx, true)
end

local types = {
    object = 0, pair = 1, list = 2
}

local function determine_type(str, i)
    local chr, j = next_char(str, i)
    if chr == "=" then
        chr, j = next_char(str, j + 1)
        if chr == "{" then
            local closing = string.find(str, "}", j)
            if not closing then
                debug_out("Closing bracket not found", i, true)
            end
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

local function parse_list(str, idx)
    local res = {}
    local i = idx
    local x = 0
    local chr
    while x < 10000 do
        x = x + 1
        chr, i = next_char(str, i)
        if (chr == "{") then
            chr, i = next_char(str, i + 1)
        end
        if (chr == "}") then
            i = i + 1
            return res, i
        end
        local value
        value, i = parse_string(str, i)
        debug_out("parse_list: " .. value, i, false)
        table.insert(res, value)
    end
    debug_out("parse_list exceeded limit", idx, true)
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

local function is_list(val)
    if type(val) == "table" and val[1] ~= nil then
        return true
    end
    return false
end

local function _insert(res, key, val)
    if res[key] ~= nil then
        if is_list(res[key]) then
            table.insert(res[key], val)
        else
            local temp = res[key]
            res[key] = {temp, val}
        end
    else
        res[key] = val
    end
end

local function parse_object(str, i, doAsList, level)
    local res = {}
    local chr
    while true do
        local key, val
        chr, i = next_char(str, i)
        if (chr == "{") then
            -- makes sure we enter the object
            chr, i = next_char(str,i + 1)
        end
        if (chr == "}") then
            -- object has ended, return it
            debug_out("chr == }: " .. tostring(level), i, false)
            return res, i + 1
        end

        key, i = parse_string(str, i)

        if caseOverrides[string.lower(key)] ~= nil then
            key = caseOverrides[string.lower(key)]
        end

        debug_out("key: " .. key, i, false)
        local value_type = determine_type(str, i)
        debug_out("value_type: " .. tostring(value_type), i, false)
        chr, i = next_char(str, i)    -- should be '=' at all times

        if chr ~= "=" then
            debug_out("Expected '=' but got '" .. chr .. "'", i, true)
        end

        i = i + 1
        if (value_type == types.object) then
            chr, i = next_char(str, i)
            val, i = parse_object(str, i, false, level + 1)
            if doAsList then
                table.insert(res, {[key]=val})
            else
                _insert(res, key, val)
            end
        elseif (value_type == types.list) then
            chr, i = next_char(str, i)
            val, i = parse_list(str, i)
            _insert(res, key, val)
        elseif (value_type == types.pair) then
            chr, i = next_char(str, i)
            val, i = parse_string(str, i)
            debug_out("val: " .. val, i, false)
            _insert(res, key, val)
        end
        -- debug_out(Utils.TABLE_TO_STRING(res))
    end
end

--- Decodes a PdxScript object-string into a LUA table
--- Make sure the string is wrapped by "{\n" and "\n}"
function P.parse(str, asList)
    return parse_object(str, 1, asList, 0)
end

function P.parseFile(filePath, asList)
	local file, err = io.open(filePath, "r")
    -- debug_out(filePath)
    local temp = Utils.SplitString(filePath, "\\")
    CURRENT_FILE = temp[#temp-1] .. "\\" .. temp[#temp]
	if file ~= nil then
        CURRENT_FILE_CONTENT = "{ \n" .. file:read("*a") .. "\n }"
        local linesString = CURRENT_FILE_CONTENT
        local decoded = PdxParser.parse(linesString, asList)
		file:close()
        return decoded
	end
	if err ~= nil then
		error(err)
	end
end



return PdxParser