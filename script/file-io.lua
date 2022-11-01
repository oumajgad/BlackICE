function ReadFileAsArray(path, delimiter)
    local file = io.open(path, "r")
    local ret = {}
    if file ~= nil then
        for line in file:lines() do
            -- Utils.LUA_DEBUGOUT(line)
            local t = {}
            for str in string.gmatch(line, "([^" .. delimiter .."]+)") do
                -- Utils.LUA_DEBUGOUT(str)
                table.insert(t, str)
            end
            ret[t[1]] = t[2]
        end
        file:close()
        return ret
    end
end

function ReadHex(file, offset, length)
    local f_open = io.open(file, "rb")
    if f_open ~= nil then
        local bytes_string = ""
        f_open:seek("set", tonumber(offset))
        local bytes = f_open:read(length)
        for b in string.gfind(bytes, ".") do
            local t = string.format("%02X ", string.byte(b))
            bytes_string = bytes_string .. t
        end
        f_open:close()
        return bytes_string:sub(1, -2) -- Remove space at end of string
    end
end

function WriteHex(file, offset, str)
    local f_open = io.open(file, "rb+")
    if f_open ~= nil then
        f_open:seek("set", tonumber(offset))
        for byte in str:gmatch'%x%x' do
            f_open:write(string.char(tonumber(byte,16)))
        end
        f_open:close()
        return
    end
end