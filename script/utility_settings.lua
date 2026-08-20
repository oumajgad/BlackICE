-- Utility settings.
--
-- The switches a player is meant to change, kept in one file so they can be found
-- without reading autoexec.lua. Edit the values below; nothing else here needs touching.
--
-- Loaded before either utility, so everything downstream sees the same answers.

-- The wxWidgets utility: the separate windows opened from the game's menu.
G_UtilityEnabled = false

-- The in-game utility drawn over the game itself, opened with INSERT.
--
-- On its own switch rather than sharing one with the wx utility, so either can be run
-- without the other. Turning it off also skips installing the Direct3D hooks, so the
-- game runs exactly as it would without BiceLib's overlay.
G_ImguiUtilityEnabled = true

-- Whether the in-game utility reads the mod's files up front.
--
-- Its pages parse what they need the first time each is opened, which is why the first
-- page looked at used to stall for several seconds. With this on, the overlay parses one
-- of those sets per frame while the game sits at the menu, so nothing is left to do by
-- the time a page is opened.
--
-- Turn it off to keep that memory unspent until a page actually asks for it - worth it
-- if the overlay is installed but rarely opened. It does not save anything if the pages
-- are used: the same work then happens on first open instead. The Timing page on the
-- Debug window can also turn it off for one session, and shows what it costs.
--
-- Irrelevant when G_ImguiUtilityEnabled is false: nothing is loaded to parse anything.
G_ImguiWarmupEnabled = true

-- RAM Usage of the different utility cases, measured before the two utilities shared
-- their data provider. Both together should now cost less than the sum.
--                           Main menu - country selected - 7 days passed
-- No utility               :   2170   -      2322        -    2538
-- old utility              :   2172   -      2322        -    2624
-- new utility              :   2288   -      2437        -    2626
-- both w. new data provider:   2275   -      2423        -    2613
