local P = {}

CsvParser = P

local function parseCSVLine(line,sep)
    local res = {}
    local pos = 1
    sep = sep or ';'
    while true do
        -- We only care about the english translation so exit early after we have it
        if #res >= 2 then
            return res
        end

        local c = string.sub(line,pos,pos)
        -- ignore commented lines
        if c == "#" then
            return nil
        end
        local startp,endp = string.find(line,sep,pos)
        if (startp) then
            table.insert(res,string.sub(line,pos,startp-1))
            pos = endp + 1
        else
            -- no separator found -> use rest of string and terminate
            table.insert(res,string.sub(line,pos))
            break
        end
    end
    return res
end


function P.parseFile(filePath)
    local res = {}
    local file, err = io.open(filePath, "r")
    if err ~= nil then
        print(err)
    else
        for line in file:lines() do
            local tbl = parseCSVLine(line)
            if tbl ~= nil then
                res[tbl[1]] = tbl[2]
            end
        end
        file:close()
        return res
    end
end

return CsvParser
