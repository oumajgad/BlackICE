# TODOs for David
- research improving the combat screen with more information about the combat stats
- check if Hoi3CString class is actually needed (it appears the game uses the std::string implementation)
- use in_game field of GameState to replace current "is game running" logic
- research the rules which decide if a unit shatter, or is completely wiped out
    - If a unit is retreating and its current province is taken by the enenmy, aswell as the province it was retreating to, it is completely removed from the game
    - But sometimes units, even though surrounded, are shattered instead, and therefore reappear at the Theatre command
