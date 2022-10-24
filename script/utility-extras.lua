G_TechsIcEffValues = {}

function ReadTechsIcEffValues()
    local filePath = "tfh\\mod\\BlackICE-utility-resources\\" .. UI.version .. "\\TechsIcEffValues.txt"
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

ReadTechsIcEffValues()
-- Utils.INSPECT_TABLE(G_TechsIcEffValues)