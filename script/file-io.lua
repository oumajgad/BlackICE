package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("lfs")

function ReadFileAsArray(path, delimiter)
    local f_open, err = io.open(path, "r")
    local ret = {}
    if f_open ~= nil then
        for line in f_open:lines() do
            -- Utils.LUA_DEBUGOUT(line)
            local t = {}
            for str in string.gmatch(line, "([^" .. delimiter .."]+)") do
                -- Utils.LUA_DEBUGOUT(str)
                table.insert(t, str)
            end
            ret[t[1]] = t[2]
        end
        f_open:close()
        return ret
    else
        Utils.LUA_DEBUGOUT(err)
        return nil
    end
end

function ReadHex(file, offset, length)
    local f_open, err = io.open(file, "rb")
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
    else
        Utils.LUA_DEBUGOUT(err)
    end
end

function WriteHex(file, offset, str)
    local f_open, err = io.open(file, "r+b")
    if f_open ~= nil then
        f_open:seek("set", tonumber(offset))
        for byte in str:gmatch'%x%x' do
            f_open:write(string.char(tonumber(byte,16)))
        end
        f_open:close()
        return
    else
        Utils.LUA_DEBUGOUT(err)
    end
end

function ReadLine(file, index)
    local f, err = io.open(file, "r")
    local lines = {}
    if f ~= nil then
        for line in f:lines() do
            table.insert(lines, line)
        end
        io.close(f)
        if index > #lines then
            return false
        else
            return lines[index]
        end
    else
        Utils.LUA_DEBUGOUT(err)
    end
    return false
end

function AppendLine(file, str)
    local f, err = io.open(file, "a")
    if f ~= nil then
        f:write(str)
        io.close(f)
        return true
    else
        Utils.LUA_DEBUGOUT(err)
    end
    return false
end

function WriteString(file, str)
    local f, err = io.open(file, "w")
    if f ~= nil then
        f:write(str)
        io.close(f)
        return true
    else
        Utils.LUA_DEBUGOUT(err)
    end
    return false
end

function CheckFileExists(file)
    local f, err = io.open(file, "r")
    if f ~= nil then
        -- Utils.LUA_DEBUGOUT("true")
        io.close(f)
        return true
    else
        Utils.LUA_DEBUGOUT(err)
    end    -- Utils.LUA_DEBUGOUT("false")
    return false
end

function ReplaceLineAtCommentMark(filename, commentMark, newLine)
    local f1, err1 = io.open(filename, "r")
    local lines = {}
    if f1 ~= nil then
        for line in f1:lines() do
            if string.find(line, commentMark) then
                table.insert(lines, newLine)
            else
                table.insert(lines, line)
            end
        end
        f1:close()
    end
    if err1 then
        Utils.LUA_DEBUGOUT(err1)
        return err1
    end
    local f2, err2 = io.open(filename, 'w')
    if f2 ~= nil then
        for i, v in ipairs(lines) do
            f2:write(v..'\n')
        end
        io.close(f2)
    end
    if err2 then
        Utils.LUA_DEBUGOUT(err2)
        return err2
    end
    return "Edited: " .. filename
end

function GetFilesFromPath(path)
    local res = {}
    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            local full_path = path..'\\'..entry
            -- Utils.LUA_DEBUGOUT("absolute_path: " .. absolute_path)
            local attr = lfs.attributes(full_path)
            if (type(attr) ~= "table") then
                Utils.LUA_DEBUGOUT("attrs not table: " .. type(attr))
            end
            if attr.mode == "directory" then
                -- Utils.LUA_DEBUGOUT("directory: " .. entry)
            else
                -- Utils.LUA_DEBUGOUT("file: " .. entry)
                table.insert(res, entry)
            end
        end
    end
    return res
end
