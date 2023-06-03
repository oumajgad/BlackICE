local P = {}
Utils = P

-- Keep this commented for release (prevent security patch problems)
--[[
--warpper to catch errors and print to file
function P.wrap(f, ...)
    local enabled = true --to disable all logging set to false
    --TODO: make this shit dynamic i mean jesus that just HAS to be possible
    local logPath = "C:\\Users\User\\Documents\\Paradox Interactive\\Hearts of Iron III\\BlackICE Test\\logs" -- Set this path to your log folder

    if enabled then
        local hasNotThrownError , returnedValue = pcall(f, ...)
        if hasNotThrownError == false then
            -- log error to file
            local file = io.open(logPath .. "\\luaErrors.txt", "a")
            file:write(returnedValue .. " \n");
            file:write(debug.traceback() .. " \n\n")
            file:close()
            -- throw error for .EXE
            error(returnedValue)
        end
        return returnedValue
    else
        return f(...)
    end
end
]]

-- Keep this commented for release (prevent security patch problems)
--[[
function P.resetLog()
  local file = io.open(logPath .. "\\luaErrors.txt", "w")
  file:write("");
  file:close()
end
]]

local times
function P.addTime(s, t, p)

  if times == nil then
    times = {}
  end

  if times[s] == nil then
    times[s] = 0
  end
  times[s] = times[s] + t

  if p then
    if s == "OMGVarHandler" then
      P.LUA_DEBUGOUT("---------------------------")
    end
    P.LUA_DEBUGOUT(string.format('%.05f',times[s]) .. " - " .. s)
    times[s] = 0
  end

end

function P.LUA_DEBUGOUT(s)
	local f = io.open("lua_output.txt", "a")
	f:write("LUA_DEBUG '" .. s .. "' \n")
  f:close()
end

-- Append table 2 to end of table 1
function P.Append(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

--===================================================
--=  Niklas Frykholm
-- basically if user tries to create global variable
-- the system will not let them!!
-- call GLOBAL_lock(_G)
--
--===================================================
function P.GLOBAL_lock(t)
  local mt = getmetatable(t) or {}
  mt.__newindex = lock_new_index
  setmetatable(t, mt)
end


-- returns a sorted iterator for the array;
-- give either "SortDescending" or "SortAscending" as order argument
function spairs(t, order)
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end

  if order then
      table.sort(keys, function(a,b) return order(t, a, b) end)
  else
      table.sort(keys)
  end

  local i = 0
  return function()
      i = i + 1
      if keys[i] then
          return keys[i], t[keys[i]]
      end
  end
end

SortDescending = function(t,a,b) return t[b] < t[a] end
SortAscending = function(t,a,b) return t[b] > t[a] end

--===================================================
-- call GLOBAL_unlock(_G)
-- to change things back to normal.
--===================================================
function P.GLOBAL_unlock(t)
  local mt = getmetatable(t) or {}
  mt.__newindex = unlock_new_index
  setmetatable(t, mt)
end

function P.lock_new_index(t, k, v)
  if (k~="_" and string.sub(k,1,2) ~= "__") then
    GLOBAL_unlock(_G)
    error("GLOBALS are locked -- " .. k ..
          " must be declared local or prefix with '__' for globals.", 2)
  else
    rawset(t, k, v)
  end
end

function P.unlock_new_index(t, k, v)
  rawset(t, k, v)
end
------------------------------------------------------

-----------------------------------------------------------------------------
-- calls specified function in country specific AI module if it exists
--
-- tag: country tag to load library for
-- funName: name of function to call if exists
-- currentScore - current score, returned if no module found
-- rest of args are passed to resolved funName and currentScore appended.
-----------------------------------------------------------------------------
function P.CallScoredCountryAI(tag, funName, currentScore, ...)
	local funRef = P.HasCountryAIFunction(tag, funName)
	if funRef then
		return funRef(currentScore, ...)
	end
	return currentScore
end

-- voScoreObj always assumes a Score field exists in the object
function P.CallGetScoreAI(tag, funName, voScoreObj)
	local funRef = P.HasCountryAIFunction(tag, funName)
	if funRef then
		return funRef(voScoreObj)
	else
		return voScoreObj.Score
	end
end

function P.CallCountryAI(tag, funName, ...)
	local funRef = P.HasCountryAIFunction(tag, funName)
	if funRef then
		return funRef(...)
	end
end

-- returns function ref if one exists, otherwise null
function P.HasCountryAIFunction(tag, funName)
	local countryModule = _G['AI_' .. tostring(tag)]
	if countryModule then
		local funRef = countryModule[funName]
		return funRef
	end
	return nil
end

-- Returns the Function Reference you are trying to call
function P.GetFunctionReference(voMinisterTag, vbIsNaval, vsFunName)
	local loFunRef = P.HasCountryAIFunction(voMinisterTag, vsFunName)
	if loFunRef then
		return loFunRef
	else
		if vbIsNaval then
			return P.HasCountryAIFunction("DEFAULT_MIXED", vsFunName)
		else
			return P.HasCountryAIFunction("DEFAULT_LAND", vsFunName)
		end
	end
end

-- Looks for country specific if none then defaults (function HAS TO exist somewhere if not return nil)
function P.CallBuildFunction(voMinisterTag, vbIsNaval, vsFunName, ...)
	local loFunRef = P.GetFunctionReference(voMinisterTag, vbIsNaval, vsFunName)

	if loFunRef then
		return loFunRef(...)
	end

	return nil
end

function P.CallLendLeaseWeights(voMinisterTag, vsFunName, ...)
	local loFunRef = P.HasCountryAIFunction(voMinisterTag, vsFunName)

	if loFunRef then
		return loFunRef(...)
	end

	return {}
end

function P.GetCountryUnitLimits(voMinisterTag)
	local loFunRef = P.HasCountryAIFunction(voMinisterTag, "CountryUnitLimits")

	if loFunRef then
		return loFunRef()
  else
    return nil
  end
end

-- Looks for country specific Function and if found calls it and returns the values
function P.CallFunction(voMinisterTag, vsFunName, ...)
	local loFunRef = P.HasCountryAIFunction(voMinisterTag, vsFunName)

	if loFunRef then
		return loFunRef(...)
	end

	return true
end

-- Organizes an Array so it can be searched on using the items
-- EXAMPLE // if items[vsSupportGroup] then
function P.Set (list)
	if not(list) then
		list = {}
	end

	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end


-- Keep this commented for release (prevent security patch problems)
--[[
-- returns list of files in a directory matching pattern
function P.ScanDir(dirname, pattern )
	local callit = os.tmpname()
	os.execute("dir /A-D /B "..dirname .. " >"..callit)
	local f = io.open(callit,"r")
	local rv = f:read("*all")
	f:close()
	os.remove(callit)

	tabby = {}
	local from  = 1
	local delim_from, delim_to = string.find( rv, "\n", from  )
	while delim_from do
		local subs = string.sub( rv, from , delim_from-1 )
		if string.match(subs, pattern) then
			table.insert( tabby, subs )
		end
		from  = delim_to + 1
		delim_from, delim_to = string.find( rv, "\n", from  )
	end
	return tabby
end
]]

-- Rounds a number greated than 0.5 high less than low
function P.Round(viNumber)
	return math.floor(viNumber + 0.5)
end

-- LuA dOeSnT nEeD iNtEgEr DaTaTyPeS bEcAuSe FlOaT iS pReCiSe EnOuGh
-- suck my balls LUA, How can you not print an even 0.2?
-- as soon as we get a number below 1 LUA can fuck off
-- which is only like every number in the Hoi3 exe
function P.RoundDecimal(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces)
  return math.floor(num * mult + 0.5) / mult
end

-- Splits a text string based on the delimiter passed
function P.Split(str, delim, maxNb)
    -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end


--[[
some nice debug helper code taken from http://lua-users.org/wiki/DataDumper

DataDumper.lua
Copyright (c) 2007 Olivetti-Engineering SA

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local dumplua_closure = [[
local closures = {}
local function closure(t)
  closures[#closures+1] = t
  t[1] = assert(loadstring(t[1]))
  return t[1]
end

for _,t in pairs(closures) do
  for i = 2,#t do
    debug.setupvalue(t[1], i-1, t[i])
  end
end
]]

local lua_reserved_keywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
  'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
  'return', 'then', 'true', 'until', 'while' }

local function keys(t)
  local res = {}
  local oktypes = { stringstring = true, numbernumber = true }
  local function cmpfct(a,b)
    if oktypes[type(a)..type(b)] then
      return a < b
    else
      return type(a) < type(b)
    end
  end
  for k in pairs(t) do
    res[#res+1] = k
  end
  table.sort(res, cmpfct)
  return res
end

local c_functions = {}
for _,lib in pairs{'_G', 'string', 'table', 'math',
    'io', 'os', 'coroutine', 'package', 'debug'} do
  local t = _G[lib] or {}
  lib = lib .. "."
  if lib == "_G." then lib = "" end
  for k,v in pairs(t) do
    if type(v) == 'function' and not pcall(string.dump, v) then
      c_functions[v] = lib..k
    end
  end
end

function P.DataDumper(value, varname, fastmode, ident)
  local defined, dumplua = {}
  -- Local variables for speed optimization
  local string_format, type, string_dump, string_rep =
        string.format, type, string.dump, string.rep
  local tostring, pairs, table_concat =
        tostring, pairs, table.concat
  local keycache, strvalcache, out, closure_cnt = {}, {}, {}, 0
  setmetatable(strvalcache, {__index = function(t,value)
    local res = string_format('%q', value)
    t[value] = res
    return res
  end})
  local fcts = {
    string = function(value) return strvalcache[value] end,
    number = function(value) return value end,
    boolean = function(value) return tostring(value) end,
    ['nil'] = function(value) return 'nil' end,
    ['function'] = function(value)
      return string_format("loadstring(%q)", string_dump(value))
    end,
    userdata = function() return 'userdata' end,
    thread = function() error("Cannot dump threads") end,
  }
  local function test_defined(value, path)
    if defined[value] then
      if path:match("^getmetatable.*%)$") then
        out[#out+1] = string_format("s%s, %s)\n", path:sub(2,-2), defined[value])
      else
        out[#out+1] = path .. " = " .. defined[value] .. "\n"
      end
      return true
    end
    defined[value] = path
  end
  local function make_key(t, key)
    local s
    if type(key) == 'string' and key:match('^[_%a][_%w]*$') then
      s = key .. "="
    else
      s = "[" .. dumplua(key, 0) .. "]="
    end
    t[key] = s
    return s
  end
  for _,k in ipairs(lua_reserved_keywords) do
    keycache[k] = '["'..k..'"] = '
  end
  if fastmode then
    fcts.table = function (value)
      -- Table value
      local numidx = 1
      out[#out+1] = "{"
      for key,val in pairs(value) do
        if key == numidx then
          numidx = numidx + 1
        else
          out[#out+1] = keycache[key]
        end
        local str = dumplua(val)
        out[#out+1] = str..","
      end
      if string.sub(out[#out], -1) == "," then
        out[#out] = string.sub(out[#out], 1, -2);
      end
      out[#out+1] = "}"
      return ""
    end
  else
    fcts.table = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      -- Table value
      local sep, str, numidx, totallen = " ", {}, 1, 0
      local meta, metastr = (debug or getfenv()).getmetatable(value)
      if meta then
        ident = ident + 1
        metastr = dumplua(meta, ident, "getmetatable("..path..")")
        totallen = totallen + #metastr + 16
      end
      for _,key in pairs(keys(value)) do
        local val = value[key]
        local s = ""
        local subpath = path
        if key == numidx then
          subpath = subpath .. "[" .. numidx .. "]"
          numidx = numidx + 1
        else
          s = keycache[key]
          if not s:match "^%[" then subpath = subpath .. "." end
          subpath = subpath .. s:gsub("%s*=%s*$","")
        end
        s = s .. dumplua(val, ident+1, subpath)
        str[#str+1] = s
        totallen = totallen + #s + 2
      end
      if totallen > 80 then
        sep = "\n" .. string_rep("  ", ident+1)
      end
      str = "{"..sep..table_concat(str, ","..sep).." "..sep:sub(1,-3).."}"
      if meta then
        sep = sep:sub(1,-3)
        return "setmetatable("..sep..str..","..sep..metastr..sep:sub(1,-3)..")"
      end
      return str
    end
    fcts['function'] = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      if c_functions[value] then
        return c_functions[value]
      elseif debug == nil or debug.getupvalue(value, 1) == nil then
        return string_format("loadstring(%q)", string_dump(value))
      end
      closure_cnt = closure_cnt + 1
      local res = {string.dump(value)}
      for i = 1,math.huge do
        local name, v = debug.getupvalue(value,i)
        if name == nil then break end
        res[i+1] = v
      end
      return "closure " .. dumplua(res, ident, "closures["..closure_cnt.."]")
    end
  end
  function dumplua(value, ident, path)
    return fcts[type(value)](value, ident, path)
  end
  if varname == nil then
    varname = "return "
  elseif varname:match("^[%a_][%w_]*$") then
    varname = varname .. " = "
  end
  if fastmode then
    setmetatable(keycache, {__index = make_key })
    out[1] = varname
    table.insert(out,dumplua(value, 0))
    return table.concat(out)
  else
    setmetatable(keycache, {__index = make_key })
    local items = {}
    for i=1,10 do items[i] = '' end
    items[3] = dumplua(value, ident or 0, "t")
    if closure_cnt > 0 then
      items[1], items[6] = dumplua_closure:match("(.*\n)\n(.*)")
      out[#out+1] = ""
    end
    if #out > 0 then
      items[2], items[4] = "local t = ", "\n"
      items[5] = table.concat(out)
      items[7] = varname .. "t"
    else
      items[2] = varname
    end
    return table.concat(items)
  end
end


function P.INSPECT_TABLE(...)
  P.LUA_DEBUGOUT( P.DataDumper(...) .. "\n---" )
end

function P.TABLE_TO_STRING(...)
  return P.DataDumper(...) .. "\n---"
end

--- Returns an alphabetically ordered table iterator
function P.OrderedTable(t)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function P.Dump(o, indent)
  if not indent then indent = 0 end
  if type(o) == 'table' then
    indent = indent
    local s = '{\n'
    for k,v in P.OrderedTable(o) do
      if type(k) ~= 'number' then k = '"'..k..'" = ' end
      if type(k) == "number" then k = "" end
      s = s .. string.rep("    ", indent + 1) .. k .. P.Dump(v, indent + 1) .. '\n'
    end
    return s .. string.rep("    ", indent) .. '}'
  else
    return tostring(o)
  end
end


function P.Trade_Dumper(trade)
  local from = tostring(trade:GetFrom())
  local to = tostring(trade:GetTo())

  local from_SUPPLIES_ = trade:GetTradedFromOf(CGoodsPool._SUPPLIES_):Get()
  local from_FUEL_ = trade:GetTradedFromOf(CGoodsPool._FUEL_):Get()
  local from_MONEY_ = trade:GetTradedFromOf(CGoodsPool._MONEY_):Get()
  local from_CRUDE_OIL_ = trade:GetTradedFromOf(CGoodsPool._CRUDE_OIL_):Get()
  local from_METAL_ = trade:GetTradedFromOf(CGoodsPool._METAL_):Get()
  local from_ENERGY_ = trade:GetTradedFromOf(CGoodsPool._ENERGY_):Get()
  local from_RARE_MATERIALS_ = trade:GetTradedFromOf(CGoodsPool._RARE_MATERIALS_):Get()

  local to_SUPPLIES_ = trade:GetTradedToOf(CGoodsPool._SUPPLIES_):Get()
  local to_FUEL_ = trade:GetTradedToOf(CGoodsPool._FUEL_):Get()
  local to_MONEY_ = trade:GetTradedToOf(CGoodsPool._MONEY_):Get()
  local to_CRUDE_OIL_ = trade:GetTradedToOf(CGoodsPool._CRUDE_OIL_):Get()
  local to_METAL_ = trade:GetTradedToOf(CGoodsPool._METAL_):Get()
  local to_ENERGY_ = trade:GetTradedToOf(CGoodsPool._ENERGY_):Get()
  local to_RARE_MATERIALS_ = trade:GetTradedToOf(CGoodsPool._RARE_MATERIALS_):Get()

  local f = string.format
  local out = [[ 
    ------------ %s ----- %s --
    ENERGY   |  %s  |  %s  |
    METAL    |  %s  |  %s  |
    RARES    |  %s  |  %s  |
    CRUDE    |  %s  |  %s  |
    SUPPLIES |  %s  |  %s  |
    FUEL     |  %s  |  %s  |
    MONEY    |  %s  |  %s  |
    ---------------------------
  ]]
  local formatted = string.format(
    out, from, to, f("%05.02f",from_ENERGY_ + 0.001), f("%05.02f",to_ENERGY_ + 0.001), f("%05.02f",from_METAL_ + 0.001), f("%05.02f",to_METAL_ + 0.001),
    f("%05.02f",from_RARE_MATERIALS_ + 0.001), f("%05.02f",to_RARE_MATERIALS_ + 0.001), f("%05.02f",from_CRUDE_OIL_ + 0.001), f("%05.02f",to_CRUDE_OIL_ + 0.001),
    f("%05.02f",from_SUPPLIES_ + 0.001), f("%05.02f",to_SUPPLIES_ + 0.001), f("%05.02f",from_FUEL_ + 0.001), f("%05.02f",to_FUEL_ + 0.001),
    f("%05.02f",from_MONEY_ + 0.001), f("%05.02f",to_MONEY_ + 0.001))
  Utils.LUA_DEBUGOUT(formatted)
end

function P.BoolToNumber(value)
  return value and 1 or 0
end

function P.NumberToBool(value)
  if value > 0 then
    return true
  else
    return false
  end
end

return Utils
