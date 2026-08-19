-- Parses the heavy datasets before a page asks for them.
--
-- Every provider parses its files the first time something needs them, which is why
-- opening the overlay for the first time stalls: the page that happens to be looked at
-- first pays for the parse. Country Info is the least obvious of them - it reads tech
-- modifier values, so it carries the whole technology parse without mentioning it.
--
-- The overlay steps through this one entry per frame while the game is sitting at the
-- menu, so the cost is paid where nobody is waiting on it. Nothing here needs a game
-- session: it is all file parsing.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Warmup = {}

-- Worst first, so the longest stall is over soonest. A step calls whatever forces that
-- provider to parse; the arguments are deliberately empty, since the parse happens
-- before any filtering by country.
local STEPS = {
    { name = "Unit models", run = function() BiceData.UnitModels.Choices(nil) end },
    { name = "Generals", run = function() BiceData.Generals.ForCountry(nil) end },
    { name = "Units", run = function() BiceData.Units.Choices() end },
    { name = "Technologies", run = function() BiceData.Techs.ModifierValues() end },
    { name = "Traits", run = function() BiceData.Traits.Choices() end },
    { name = "Modifiers", run = function() BiceData.Modifiers.Choices() end },
    { name = "Province buildings", run = function() BiceData.ProvinceBuildings.Choices() end },
}

local nextStep = 1

--- Parses the next dataset. One call is one dataset, and one frame's worth of stall.
function BiceLibGui.Warmup.Step()
    return Page.Guard(function()
        if nextStep > #STEPS then
            return { available = true, done = true, remaining = 0, name = "" }
        end

        local step = STEPS[nextStep]
        -- Counted before it runs: a step that throws is one that will keep throwing,
        -- and retrying it every frame would stall the game rather than the parse.
        nextStep = nextStep + 1

        step.run()
        return {
            available = true,
            done = nextStep > #STEPS,
            remaining = #STEPS - nextStep + 1,
            name = step.name,
        }
    end)
end

--- How far along it is, and whether the player wants it at all, without doing any of
--- the work. The overlay asks once, before the first step.
function BiceLibGui.Warmup.State()
    return Page.Guard(function()
        return {
            available = true,
            done = nextStep > #STEPS,
            remaining = #STEPS - nextStep + 1,
            total = #STEPS,
            -- Set in utility_settings.lua. Only an explicit false turns it off, so a
            -- player with an older settings file still gets the parsing.
            enabled = G_ImguiWarmupEnabled ~= false,
        }
    end)
end
