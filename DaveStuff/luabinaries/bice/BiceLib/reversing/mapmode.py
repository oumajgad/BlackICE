"""Which map mode the game is showing, by its own numbering.

    python mapmode.py            # once
    python mapmode.py --watch    # keep printing as it changes

The numbers on the buttons are not the numbers the game uses: the VP button is
`mapmode_10` in the gui files but mode 7 inside. This is how to find out what any of
them really is - select it in game and look.

The mode is on the map, which hangs off the game state; the same dispatch that reads it
picks the routine that colours the map for that mode:

    mode 1 -> 0x266220    mode 5 -> 0x2670F0    mode 8 -> 0x267920
    mode 2 -> 0x2668C0    mode 6 -> 0x267510    mode 9 -> 0x267B50
    mode 4 -> 0x266EE0    mode 7 -> 0x267710 (victory points)

A mode that is not in that list is coloured by the generic path instead, which is worth
knowing before going looking for a routine that does not exist.
"""

import argparse
import sys
import time

import hoi3

GAME_STATE_POINTER = 0x1689790
GAME_STATE_MAP = 0xBE8
MAP_CURRENT_MODE = 0xD34

# What the buttons are called in the gui files and the localisation, which is not the
# same numbering - kept here so the two can be lined up once they are known.
MODE_NAMES = {
    0: "Terrain (mapmode_1)",            1: "Political (mapmode_2)",
    2: "Diplomatic (mapmode_6)",         3: "mapmode_7, which has no localisation",
    4: "Supply (mapmode_8)",             5: "Infrastructure (mapmode_9)",
    6: "Intel (mapmode_4)",              7: "VP (mapmode_10)",
    8: "Theatre (mapmode_11)",           9: "Strength (mapmode_12)",
    10: "Resources (mapmode_13)",        11: "Weather (mapmode_3)",
    12: "Revoltrisk (mapmode_5)",        13: "Simplified Terrain (mapmode_14)",
    18: "Air (mapmode_15)",              19: "Naval (mapmode_16)",
}

COLOURING_ROUTINE = {
    1: 0x266220, 2: 0x2668C0, 4: 0x266EE0, 5: 0x2670F0,
    6: 0x267510, 7: 0x267710, 8: 0x267920, 9: 0x267B50,
}


def currentMode(pm, base):
    """(mode, map address), or (None, 0) when there is no session"""
    state = pm.read_uint(base + GAME_STATE_POINTER)
    if state == 0:
        return None, 0
    mapObject = pm.read_uint(state + GAME_STATE_MAP)
    if mapObject == 0:
        return None, 0
    return pm.read_int(mapObject + MAP_CURRENT_MODE), mapObject


def describe(mode):
    routine = COLOURING_ROUTINE.get(mode)
    where = ("coloured by 0x%06X" % routine) if routine else "coloured by the generic path"
    return "mode %-3s %-36s %s" % (mode, MODE_NAMES.get(mode, "?"), where)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--watch", action="store_true",
                        help="keep printing, so map modes can be clicked through")
    args = parser.parse_args()

    pm = hoi3.attach()
    base = pm.base_address
    print("hoi3_tfh.exe at 0x%08X" % base)

    if not args.watch:
        mode, mapObject = currentMode(pm, base)
        if mode is None:
            sys.exit("no session is running - load a save first")
        print("map at 0x%08X" % mapObject)
        print(describe(mode))
        return

    print("watching - switch map modes in game, ctrl+c to stop\n")
    last = object()
    while True:
        try:
            mode, _ = currentMode(pm, base)
        except Exception:
            mode = None
        if mode != last:
            print("   %s" % (describe(mode) if mode is not None else "no session"))
            last = mode
        time.sleep(0.25)


if __name__ == "__main__":
    main()
