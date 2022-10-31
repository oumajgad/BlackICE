--- File operations defined in here

function ReadTechsIcEffValues()
    local filePath = "tfh\\mod\\BlackICE " .. UI.version .. "\\utility\\TechsIcEffValues.txt"
    local file = io.open(filePath, "r")
    if file ~= nil then
        for line in file:lines() do
            -- Utils.LUA_DEBUGOUT(line)
            local t = {}
            for str in string.gmatch(line, "([^=]+)") do
                -- Utils.LUA_DEBUGOUT(str)
                table.insert(t, str)
            end
            G_TechsIcEffValues[t[1]] = t[2]
        end
        file:close()
    end
end

function ReadTechsResEffValues()
    local filePath = "tfh\\mod\\BlackICE " .. UI.version .. "\\utility\\TechsResEffValues.txt"
    local file = io.open(filePath, "r")
    if file ~= nil then
        for line in file:lines() do
            -- Utils.LUA_DEBUGOUT(line)
            local t = {}
            for str in string.gmatch(line, "([^=]+)") do
                -- Utils.LUA_DEBUGOUT(str)
                table.insert(t, str)
            end
            G_TechsResEffValues[t[1]] = t[2]
        end
        file:close()
    end
end

function ReadHex(file, offset, length)
    local f_open = io.open(file, "rb")
    local bytes_string = ""
    f_open:seek("set", tonumber(offset))
    local bytes = f_open:read(length)
    for b in string.gfind(bytes, ".") do
        local t = string.format("%02X ", string.byte(b))
        bytes_string = bytes_string .. t
    end
    f_open:close()
    return bytes_string
end

function WriteHex(file, offset, str)
    local f_open = io.open(file, "rb+")
    f_open:seek("set", tonumber(offset))
    for byte in str:gmatch'%x%x' do
        f_open:write(string.char(tonumber(byte,16)))
    end
    f_open:close()
    return
end