-- Lua console for the in-game ImGui utility.
--
-- Runs pasted script in the game's own Lua context and hands back whatever it printed
-- or returned. That context is the render thread's, the same one every page's Collect
-- runs on, so a script here sees exactly what the pages see: BiceData, the mod's
-- globals, and the game's own API.
--
-- Two things follow from where it runs, and both are guarded below:
--   - the render thread is blocked until the script returns, so a runaway loop would
--     freeze the game rather than just the console;
--   - the game's own C++ faults rather than raising a Lua error, and no pcall here can
--     catch that. Reaching for game state at the main menu is the usual way to find
--     out, which is why the page keeps the session gate on unless told otherwise.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Console = {}

-- Output is shaped for reading rather than completeness: a page full of one enormous
-- table is worse than a truncated one, and the whole string crosses to C++ every run.
local MAX_OUTPUT = 60000
local MAX_DEPTH = 4
local MAX_ENTRIES = 80
local MAX_STRING = 400

-- Roughly a second or two of work. A pasted "while true do end" hits this and comes
-- back as an error instead of a hung game.
local INSTRUCTION_LIMIT = 20000000

-- Scripts run in their own environment, which reads through to the globals but keeps
-- its own writes: x = 1 in one run is still there in the next, without a stray global
-- leaking into the mod. _G is still reachable for a deliberate global write.
local scratch = nil

local function environment()
    if scratch == nil then
        scratch = setmetatable({}, { __index = _G })
        scratch._G = _G
        scratch._SCRATCH = scratch
    end
    return scratch
end

local function truncated(text)
    if #text > MAX_STRING then
        return string.sub(text, 1, MAX_STRING) .. "..[" .. #text .. " chars]"
    end
    return text
end

local function scalar(value)
    if type(value) == "string" then
        return '"' .. truncated(value) .. '"'
    end
    -- Anything else - numbers, booleans, functions, userdata - is only worth what
    -- tostring says about it. Game objects are userdata, so an address is all there is.
    return tostring(value)
end

local dump

--- Renders a table's contents, one entry per line once it holds anything nested.
local function dumpTable(value, depth, seen, indent)
    local body = {}
    local shown = 0
    local nested = false
    local arrayLength = #value

    local function add(text, isNested)
        shown = shown + 1
        nested = nested or isNested
        table.insert(body, text)
    end

    for index = 1, arrayLength do
        if shown >= MAX_ENTRIES then
            break
        end
        local item = value[index]
        add(dump(item, depth - 1, seen, indent .. "  "), type(item) == "table")
    end

    local keys = {}
    for key in pairs(value) do
        local inArray = type(key) == "number" and key % 1 == 0
            and key >= 1 and key <= arrayLength
        if not inArray then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, key in ipairs(keys) do
        if shown >= MAX_ENTRIES then
            break
        end
        local item = value[key]
        add(tostring(key) .. " = " .. dump(item, depth - 1, seen, indent .. "  "),
            type(item) == "table")
    end

    if shown == 0 then
        return "{}"
    end
    if shown >= MAX_ENTRIES then
        table.insert(body, "...")
    end

    if not nested and shown <= 6 then
        return "{ " .. table.concat(body, ", ") .. " }"
    end
    return "{\n" .. indent .. "  " .. table.concat(body, ",\n" .. indent .. "  ")
        .. ",\n" .. indent .. "}"
end

--- A value as text: scalars as themselves, tables expanded to a bounded depth.
dump = function(value, depth, seen, indent)
    if type(value) ~= "table" then
        return scalar(value)
    end
    if seen[value] ~= nil then
        return "<seen above>"
    end
    if depth <= 0 then
        return "{...}"
    end

    seen[value] = true
    local text = dumpTable(value, depth, seen, indent or "")
    -- Cleared on the way out so the same table appearing twice side by side still
    -- prints, while a cycle still stops.
    seen[value] = nil
    return text
end

--- print's arguments, tab separated. Strings arrive as themselves rather than quoted,
--- which is what makes print worth using over returning the value.
local function printed(...)
    local parts = {}
    for index = 1, select('#', ...) do
        local value = select(index, ...)
        if type(value) == "string" then
            table.insert(parts, value)
        else
            table.insert(parts, dump(value, MAX_DEPTH, {}, ""))
        end
    end
    return table.concat(parts, "\t")
end

local function compile(source)
    if loadstring == nil then
        return nil, "loadstring is missing from this Lua build"
    end

    -- "What is this value" is the common case, so an expression on its own is tried as
    -- a return first, then the same text as statements.
    local chunk = loadstring("return " .. source, "=console")
    if chunk ~= nil then
        return chunk, nil
    end

    local err
    chunk, err = loadstring(source, "=console")
    if chunk == nil then
        return nil, err
    end
    return chunk, nil
end

local function traceback(err)
    if debug ~= nil and debug.traceback ~= nil then
        return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
end

local function limitInstructions()
    if debug == nil or debug.sethook == nil then
        return false
    end
    debug.sethook(function()
        error("stopped after " .. INSTRUCTION_LIMIT .. " instructions - is it looping?", 2)
    end, "", INSTRUCTION_LIMIT)
    return true
end

--- Runs one script, returning what it printed and what it evaluated to.
function BiceLibGui.Console.Run(source)
    return Page.Guard(function()
        if source == nil or source == "" then
            return { available = true, ok = true, output = "", error = "", elapsed = 0 }
        end

        local chunk, compileError = compile(source)
        if chunk == nil then
            return { available = true, ok = false, output = "",
                error = tostring(compileError), elapsed = 0 }
        end
        setfenv(chunk, environment())

        -- Wrapped so the result count survives: packing a call into a table loses a
        -- trailing nil, and "=> nil" is an answer worth showing rather than a blank.
        local function packed()
            local values = {}
            local function keep(...)
                for index = 1, select('#', ...) do
                    values[index] = select(index, ...)
                end
                return select('#', ...)
            end
            return keep(chunk()), values
        end

        -- Captured for the duration only, and restored on both paths: the mod's own
        -- code prints too, and it has to keep working once the console is done.
        local lines = {}
        local savedPrint = _G.print
        _G.print = function(...) table.insert(lines, printed(...)) end

        local hooked = limitInstructions()
        local clock = (os ~= nil and os.clock ~= nil) and os.clock or nil
        local started = clock and clock() or 0

        local returned = { xpcall(packed, traceback) }

        local elapsed = clock and (clock() - started) or 0
        if hooked then
            debug.sethook()
        end
        _G.print = savedPrint

        local output = table.concat(lines, "\n")

        if returned[1] ~= true then
            return { available = true, ok = false, output = output,
                error = tostring(returned[2]), elapsed = elapsed }
        end

        local count = returned[2] or 0
        local results = returned[3] or {}
        local values = {}
        for index = 1, count do
            table.insert(values, dump(results[index], MAX_DEPTH, {}, ""))
        end
        if #values > 0 then
            if #output > 0 then
                output = output .. "\n"
            end
            output = output .. "=> " .. table.concat(values, ", ")
        end

        if #output > MAX_OUTPUT then
            output = string.sub(output, 1, MAX_OUTPUT) .. "\n[output truncated]"
        end

        return { available = true, ok = true, output = output, error = "", elapsed = elapsed }
    end)
end

--- Throws away everything previous runs left behind.
function BiceLibGui.Console.Reset()
    scratch = nil
    return { available = true, ok = true, output = "scratch environment cleared",
        error = "", elapsed = 0 }
end
