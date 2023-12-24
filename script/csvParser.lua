local P = {}

CsvParser = P

local function parseCSVLine(line,sep,limit)
    if limit == nil then
        limit = 999
    end

    local res = {}
    local pos = 1
    sep = sep or ';'
    while true do
        -- only parse the first X entries
        if #res >= limit then
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


function P.parseFile(filePath, sep, limit)
    local res = {}
    local file, err = io.open(filePath, "r")
    if err ~= nil then
        print(err)
    else
        if file ~= nil then
            for line in file:lines() do
                local tbl = parseCSVLine(line, sep, limit)
                if tbl ~= nil then
                    res[tbl[1]] = tbl
                    table.remove(tbl, 1) -- removes the key from the result
                end
            end
            file:close()
            return res
        end
    end
end

return CsvParser
