"""Compare goods pool snapshots, to tell the unnamed pools apart.

    python poolCompare.py snaps/*.json

Answers, for each of the 23 pools:
  - whether it moves at all, and whether it only ever grows or is reset;
  - which other pool it moves with, country by country;
  - whether what every country gains in it is what every country loses in another,
    which is what a pair like "sent" and "received" looks like from the outside.
"""
import collections
import itertools
import json
import sys

COUNT, GOODS = 23, 7
NAMES = {0: "total_produced", 1: "home_produced", 2: "convoyed_in", 3: "convoyed_out",
         4: "traded_away", 5: "traded_away_sans_allied", 8: "traded_for",
         9: "traded_for_sans_allied", 16: "usage", 17: "to", 18: "back", 19: "pool",
         20: "supply_drawn_at_capital", 21: "supply_drawn_own"}
GOOD = ["supplies", "fuel", "money", "oil", "metal", "energy", "rares"]


def name(i):
    return "%2d %-24s" % (i, NAMES.get(i, "-"))


def main(paths):
    snaps = [json.load(open(p)) for p in paths]
    snaps.sort(key=lambda s: s["tick"])
    print("%d snapshots, tick %d to %d (%s to %s)\n" % (
        len(snaps), snaps[0]["tick"], snaps[-1]["tick"], snaps[0]["date"], snaps[-1]["date"]))
    tags = sorted(set(snaps[0]["countries"]) & set(snaps[-1]["countries"]))

    moved, grew, fell = collections.Counter(), collections.Counter(), collections.Counter()
    for a, b in zip(snaps, snaps[1:]):
        for tag in tags:
            if tag not in a["countries"] or tag not in b["countries"]:
                continue
            for i in range(COUNT):
                for g in range(GOODS):
                    d = b["countries"][tag][i][g] - a["countries"][tag][i][g]
                    if d:
                        moved[i] += 1
                        (grew if d > 0 else fell)[i] += 1

    print("pool                          changes   up     down")
    for i in range(COUNT):
        print("  %s %6d %6d %6d" % (name(i), moved[i], grew[i], fell[i]))

    # what every country gains in one pool against what every country gains in another
    print("\nworld totals per good, first snapshot to last (thousandths):")
    for i in range(COUNT):
        row = []
        for g in range(GOODS):
            total = sum(snaps[-1]["countries"][t][i][g] - snaps[0]["countries"][t][i][g] for t in tags)
            row.append(total)
        if any(row):
            print("  %s %s" % (name(i), "  ".join("%12d" % v for v in row)))

    # pools whose movement matches another's, country by country and step by step
    print("\npools that move together (same country, same step, same amount):")
    pairs = collections.Counter()
    seen = collections.Counter()
    for a, b in zip(snaps, snaps[1:]):
        for tag in tags:
            if tag not in a["countries"] or tag not in b["countries"]:
                continue
            deltas = {}
            for i in range(COUNT):
                d = tuple(b["countries"][tag][i][g] - a["countries"][tag][i][g] for g in range(GOODS))
                if any(d):
                    deltas[i] = d
            for i in deltas:
                seen[i] += 1
            for i, j in itertools.combinations(sorted(deltas), 2):
                if deltas[i] == deltas[j]:
                    pairs[(i, j)] += 1
    for (i, j), n in pairs.most_common(14):
        print("  %s and %s: %d of %d / %d times" % (name(i), name(j), n, seen[i], seen[j]))


if __name__ == "__main__":
    main(sys.argv[1:])
