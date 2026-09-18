"""A snapshot of every country's 23 goods pools, for telling the unnamed ones apart.

    python poolSnapshot.py out.json

Writes the tick, and for each country its tag and 23 x 7 figures. Take several while the
game runs and compare them with poolCompare.py: what moves together, what only ever grows,
and what one country loses while another gains.
"""
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hoi3

POOL0, STRIDE, COUNT = 0x74C, 0x24, 23
TAG, TICK = 0xCA4, 0xBDC
GOODS = ["supplies", "fuel", "money", "crude_oil", "metal", "energy", "rare_materials"]


def take(pm):
    state = struct.unpack("<I", hoi3.readBytes(pm, pm.base_address + 0x1689790, 4))[0]
    tick = struct.unpack("<i", hoi3.readBytes(pm, state + TICK, 4))[0]
    out = {"tick": tick, "date": hoi3.tickToDate(tick), "countries": {}}
    for country in hoi3.instances(pm, "CCountry"):
        body = hoi3.readBytes(pm, country + POOL0, STRIDE * COUNT)
        tag = hoi3.readBytes(pm, country + TAG, 4)
        if body is None or tag is None:
            continue
        tag = tag[:3].decode("latin-1", "replace")
        out["countries"][tag] = [[struct.unpack_from("<i", body, i * STRIDE + 8 + g * 4)[0]
                                  for g in range(7)] for i in range(COUNT)]
    return out


if __name__ == "__main__":
    pm = hoi3.attach()
    snapshot = take(pm)
    path = sys.argv[1] if len(sys.argv) > 1 else "pools.json"
    json.dump(snapshot, open(path, "w"), indent=0)
    print("%s: tick %d, %s, %d countries" % (path, snapshot["tick"], snapshot["date"],
                                             len(snapshot["countries"])))
