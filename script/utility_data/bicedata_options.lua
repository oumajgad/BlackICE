-- Where the game puts its popup windows.
--
-- Port of the pure logic in utility/options/options.lua. The font size buttons are not
-- here: they resized the wxWidgets controls, which the ImGui overlay has no equivalent
-- of - it scales its own font instead, entirely on the C++ side.
--
-- These settings are not variables or saved game state: they are lines in the mod's own
-- interface files, rewritten in place at a comment mark the mod puts there for exactly
-- this purpose. So the change survives a restart, applies to every save, and is undone
-- by reinstalling the mod.

BiceData = BiceData or {}
BiceData.Options = {}

local function interfaceFile(name)
    -- Relative to the game's working directory, as the wx page had it.
    return "tfh/mod/BlackICE " .. tostring(G_MOD_VERSION) .. "/interface/" .. name
end

local DIALOG = "eu3dialog.gui"
local EVENTS = "eventwindow.gui"

-- Each entry is one line to rewrite, keyed by the mark that identifies it. Written out
-- in full rather than patched piecemeal, which is what the mark is for.
local MESSAGE_POPUPS = {
    center = {
        { file = DIALOG, mark = "# _UtilityMark_DefaultPopup_position",
          line = "\t\tposition = { x=-250 y=-450 } # _UtilityMark_DefaultPopup_position" },
        { file = DIALOG, mark = "# _UtilityMark_DefaultPopup_orientation",
          line = "\t\torientation=\"CENTER\" # _UtilityMark_DefaultPopup_orientation" },
        { file = DIALOG, mark = "# _UtilityMark_CombatStartPopup_position",
          line = "\t\tposition = { x=-250 y=-280 } # _UtilityMark_CombatStartPopup_position" },
        { file = DIALOG, mark = "# _UtilityMark_CombatStartPopup_orientation",
          line = "\t\torientation=\"CENTER\" # _UtilityMark_CombatStartPopup_orientation" },
    },
    left = {
        { file = DIALOG, mark = "# _UtilityMark_DefaultPopup_position",
          line = "\t\tposition = { x=50 y=100 } # _UtilityMark_DefaultPopup_position" },
        { file = DIALOG, mark = "# _UtilityMark_DefaultPopup_orientation",
          line = "\t\torientation=\"CENTER_RIGHT\" # _UtilityMark_DefaultPopup_orientation" },
        { file = DIALOG, mark = "# _UtilityMark_CombatStartPopup_position",
          line = "\t\tposition = { x=50 y=100 } # _UtilityMark_CombatStartPopup_position" },
        { file = DIALOG, mark = "# _UtilityMark_CombatStartPopup_orientation",
          line = "\t\torientation=\"CENTER_RIGHT\" # _UtilityMark_CombatStartPopup_orientation" },
    },
}

local EVENT_POPUPS = {
    center = {
        { file = EVENTS, mark = "# _UtilityMark_EventPopup_position",
          line = "\t\tposition = { x=700 y=255 } # _UtilityMark_EventPopup_position" },
    },
    left = {
        { file = EVENTS, mark = "# _UtilityMark_EventPopup_position",
          line = "\t\tposition = { x=0 y=255 } # _UtilityMark_EventPopup_position" },
    },
}

local function markedLine(file, mark)
    local handle = io.open(interfaceFile(file), "r")
    if handle == nil then
        return nil
    end

    for line in handle:lines() do
        if string.find(line, mark, 1, true) ~= nil then
            handle:close()
            return line
        end
    end
    handle:close()
    return nil
end

--- Which of a setting's known states the file is currently in.
---
--- "custom" covers a hand edited file, and nil means the mark was not found at all -
--- usually a mod version whose interface files this utility has never seen.
local function currentMode(settings)
    local probe = settings.center[1]
    local line = markedLine(probe.file, probe.mark)
    if line == nil then
        return nil
    end

    for mode, entries in pairs(settings) do
        if line == entries[1].line then
            return mode
        end
    end
    return "custom"
end

local function apply(entries)
    if ReplaceLineAtCommentMark == nil then
        return false, "file-io.lua is not loaded"
    end

    for _, entry in ipairs(entries) do
        -- Returns an error string on failure and something harmless otherwise.
        local result = ReplaceLineAtCommentMark(interfaceFile(entry.file), entry.mark, entry.line)
        if type(result) == "string" and result ~= "" then
            return false, result
        end
    end
    return true, nil
end

--- Where message and event popups are currently placed.
function BiceData.Options.Collect()
    return {
        messagePopups = currentMode(MESSAGE_POPUPS) or "unknown",
        eventPopups = currentMode(EVENT_POPUPS) or "unknown",
        dialogFile = interfaceFile(DIALOG),
        eventFile = interfaceFile(EVENTS),
    }, nil
end

--- Moves the message and combat popups. mode is "center" or "left".
function BiceData.Options.SetMessagePopups(mode)
    local entries = MESSAGE_POPUPS[mode]
    if entries == nil then
        return false, "Unknown mode: " .. tostring(mode)
    end
    return apply(entries)
end

--- Moves the event popup. mode is "center" or "left".
function BiceData.Options.SetEventPopups(mode)
    local entries = EVENT_POPUPS[mode]
    if entries == nil then
        return false, "Unknown mode: " .. tostring(mode)
    end
    return apply(entries)
end
