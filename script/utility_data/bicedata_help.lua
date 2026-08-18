-- The help pages' text.
--
-- Lifted verbatim out of gui-utility-help.lua, where every paragraph was a wxStaticText
-- and the layout was the document. Here it is data, so the same text can be rendered by
-- the ImGui pages and can be corrected without touching either UI.
--
-- Entry kinds:
--   heading  a section title, bold in the wx version
--   text     a paragraph
--   item     one line of a list, laid out in two columns in the wx version
--
-- The National Focus help page is not here: it is a table built from the mod's own
-- triggered modifiers, so it lives with the rest of that in BiceData.NatFocus.

BiceData = BiceData or {}
BiceData.Help = {}

local SECTIONS = {
    misc = {
        { kind = "heading", text = "Strategic Resources" },
        { kind = "text", text = "Strategic Resources are crucial for the military production of any nation. If you do not have access to these resources other nations may be open to selling them for a price, if you have them there is much money to be made as an exporter of them. \nTrade deals last for 1 year. \nEach 200 IC requires a resource level to avoid maluses, below 100IC there are no maluses. Puppets give their excess resource to the master, who can also decide to sell it.\nEach trade costs the player 2000 money, between allies the price is halved.\n" },
        { kind = "heading", text = "Airdroppable Units" },
        { kind = "item", text = "Garrision detachment" },
        { kind = "item", text = "Motorcycle Recon" },
        { kind = "item", text = "Light Transport" },
        { kind = "item", text = "Gurkhas" },
        { kind = "item", text = "Elite Light Infantry Battalion" },
        { kind = "item", text = "Airborne Engineers" },
        { kind = "item", text = "Airborne Mixed Support" },
        { kind = "item", text = "Commandos" },
        { kind = "item", text = "Airlanding Infantry" },
        { kind = "item", text = "Paratroopers" },
        { kind = "item", text = "Player Unit (\"YOU\" brigade)" },
        { kind = "item", text = "Political Leader" },
        { kind = "item", text = "Battle Commander" },
        { kind = "item", text = "Division HQs" },
        { kind = "heading", text = "Unit Training" },
        { kind = "text", text = "In BlackICE, unit training level has been reworked slightly. \nSame as in Vanilla, Training Laws are responsible for how much starting experience unit has, but what was changed is the speed at which units reinforce.\nPenalties (or bonuses) are now much higher, resulting in much slower Strength regain with Advanced or Specialist Training. As in reality - it takes far longer to get highly trained reinforcements. It might not be possible to keep Specialised or even Advanced Training on for extensive periods of time during war, expecially during long periods of combat." },
        { kind = "heading", text = "Event Spawned Units" },
        { kind = "text", text = "Due to game engine limitations, event spawned units are spawned directly on the map instead of in the production queue. " },
        { kind = "text", text = "Each unit adds its cost to the ICDays variable, which, if it is greater than 1, will activate an IC penalty.\nThat IC penalty represents your countries investment into building those units and each week the ICDays variable gets counted down, scaled to your IC and investment value, until it reaches 0.\nAt that point the penalty will disappear." },
        { kind = "heading", text = "\nUnits that will be removed by events have yellow coloured names.\n" },
    },

    ministers = {
        { kind = "heading", text = "In BlackICE, ministers don't only give flat effects, but they are now also responsible for your country's civilian and war economy." },
        { kind = "text", text = "Depending on your choice of ministers for each position you will gain different types of buildings from time to time which are not normally buildable.\nYou only need one type of minister to get the matching building, but having multiple ministers for the same building increases the amount gained.\nSome ministers also give 2x for certain buildings.\nIf the selected national focus matches the minister the building speed will be doubled." },
        { kind = "item", text = "---Smallarms Factory---\n--Army focus--\n2x Infantry Proponent\n2x School of mass combat\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine" },
        { kind = "item", text = "---Artillery Factory---\n--Army focus--\n2x School of fire support\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine" },
        { kind = "item", text = "---Tank Factory---\n--Army focus--\n2x Tank Proponent\n2x Armoured Spearhead Doctrine" },
        { kind = "item", text = "---Automotive Factory---\n--Army focus--\n2x School of Manoeuvre\n1x Logistics Specialist" },
        { kind = "item", text = "---Light Aircraft Factory---\n--Air focus--\n2x Single Engine Aircraft Proponent\n2x Air Superiority Doctrine\n1x Old Air Marshal\n1x Air Superiority Proponent\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine" },
        { kind = "item", text = "---Medium Aircraft Factory---\n--Air focus--\n2x Twin Engine Aircraft Proponent\n2x Vertical Envelopment Doctrine\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine" },
        { kind = "item", text = "---Heavy Aircraft Factory---\n--Air focus--\n2x Strategic Air Proponent\n2x Carpet Bombing Doctrine" },
        { kind = "item", text = "---Radar Station---\n--Air focus--\n2x Air Superiority Proponent" },
        { kind = "item", text = "---Capital Shipyard---\n--Navy focus--\n2x Decisive Naval Battle Doctrine\n1x Old Admiral\n1x Battle fleet proponent" },
        { kind = "item", text = "---Medium Shipyard---\n--Navy focus--\n1x Open Seas Doctrine\n1x Old Admiral\n1x Battle fleet proponent" },
        { kind = "item", text = "---Small Shipyard---\n--Navy focus--\n1x Open Seas Doctrine" },
        { kind = "item", text = "---Submarine Shipyard---\n--Navy focus--\n2x Submarine Proponent\n2x Indirect Approach Doctrine" },
        { kind = "item", text = "---Heavy Industry---\n--Economic focus--\n2x Silent Workhorse\n2x Administrative Genius" },
        { kind = "item", text = "---Manufacturing Plant---\n--Economic focus--\n1x Military Entrepreneur\n1x Logistics Specialist" },
        { kind = "item", text = "---Rail Terminous---\n--Economy focus--\n2x Logistics Specialist" },
        { kind = "item", text = "---Research Lab---\n--Science focus--\n2x Theoretical Scientist\n1x Biased Intellectual\n1x Silent Lawyer\n1x Technical Specialist\n3x Research Specialist (only focus)" },
        { kind = "item", text = "---Training Base---\n--Health + Education focus--\n2x General Staffer\n2x School of Psychology" },
        { kind = "item", text = "---Hospital---\n--Health + Education focus--\n2x Man of the People\n1x School of Psychology" },
        { kind = "item", text = "---Resource buildings---\n--Resource focus--\n2x Resource Industrialist" },
    },
}

--- Recognises the minister/building blocks and gives them their structure back.
---
--- They were written as one lump of text per grid cell:
---     ---Smallarms Factory---
---     --Army focus--
---     2x Infantry Proponent
---     ...
--- which reads as a card in a grid and as a mess anywhere else. Split up here so the
--- page can lay them out as a table rather than reproduce a wxWidgets grid.
local function asCard(text)
    local title = string.match(text, "^%-%-%-(.-)%-%-%-")
    if title == nil then
        return nil
    end

    local card = { kind = "card", title = title, subtitle = "", lines = {} }
    for line in string.gmatch(text, "[^\n]+") do
        if string.sub(line, 1, 3) == "---" then
            -- the title, already taken
        elseif string.sub(line, 1, 2) == "--" then
            card.subtitle = string.match(line, "^%-%-(.-)%-%-") or ""
        else
            table.insert(card.lines, line)
        end
    end
    return card
end

local parsed = {}

--- The entries for one help page, or an empty list for an unknown one.
function BiceData.Help.Section(name)
    if parsed[name] ~= nil then
        return parsed[name]
    end

    local source = SECTIONS[name]
    if source == nil then
        return {}
    end

    local entries = {}
    for _, entry in ipairs(source) do
        -- Only the list items are ever cards; headings and paragraphs pass through.
        table.insert(entries, (entry.kind == "item" and asCard(entry.text)) or entry)
    end

    parsed[name] = entries
    return entries
end
