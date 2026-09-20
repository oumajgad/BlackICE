"""Writes FINDINGS-definitions.md: the grammar of every loader in the game.

    python definitions.py
    python definitions.py --findings    # and put them all into ghidra/project.json

Most of the game's classes load from a file or a save block through one `LoadKey` that is
a switch over the save tokens, with a case per key. The case list therefore **is** the
grammar - there is nothing else that loader will accept, and anything a mod writes that is
not in it is dropped in silence.

`switchmap.py` reads one switch; this walks every loader `progress.py` knows about and
collects the lot. A handful of classes are hand-annotated below with what they are and the
file to check them against; the rest are listed as they come.

Needs a running game, for the save token table.
"""

import argparse
import collections
import glob
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progress
import switchmap

MOD = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
OUT = os.path.join(HERE, "FINDINGS-definitions.md")
PROJECT = os.path.join(HERE, "ghidra", "project.json")
OWN_SOURCE = "reversing/FINDINGS-definitions.md"

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z_0-9]*$")

# `switchmap.py` can invent a low-numbered case; see its note. The identifier test below
# removes the punctuation tokens it produces (`=`, `"`, `{`, `}`), and this removes the
# one case that survives it - `fontName`, token 33, in a loader that has no fonts.
SPURIOUS = {("CTechStatistics", "fontName")}

# class -> what it is, and the file to check its keys against. Everything not here is
# still listed, just without the commentary.
NOTES = {
    "CCombatTactic": ("One tactic a land combat can pick. `attacker` and `defender` are the "
                      "unit types it favours, `countered_by` names the tactic that beats it.",
                      "common/combat_tactics.txt", 1),
    "CCasusBelliType": ("One war goal. The `po_*` keys are the peace options it unlocks; "
                        "`is_valid` and `prerequisites` are triggers, `on_add` and "
                        "`on_completion` effects, each parsed by a sub-object of its own.",
                        "common/cb_types.txt", 1),
    "CRebelType": ("One kind of uprising - what spawns it, what it demands, what it leaves "
                   "behind.", "common/rebel_types.txt", 1),
    "CIdeologyGroup": ("A group of ideologies - fascism, democracy, communism. Two keys of its "
                       "own; every other key in the block is an ideology's name.",
                       "common/ideologies.txt", 1),
    "CBookmark": ("One entry on the scenario select screen.", "common/bookmarks.txt", 1),
    "CCounterType": ("How a map counter is drawn - textures, offsets, fonts, the shield.",
                     None, 0),
    "CDefines": ("The top-level blocks of `common/defines.lua`; each holds the constants of "
                 "one part of the game.", None, 0),
    "CScenario": ("A scenario: selectable countries, where the camera starts, the victory "
                  "conditions.", None, 0),
    "CMeanTimeToHappen": ("**The MTTH grammar** every event and decision is timed by: a base "
                          "in `days`, `months` or `years`, then `modifier` blocks with a "
                          "`factor` each.", None, 0),
    "CDiplomacy": ("The save's diplomacy block - one key per kind of standing agreement.",
                   None, 0),
    "CUnitPlan": ("A battle plan as the save keeps it: objectives, path, stances, and both "
                  "sides' power estimates.", None, 0),
    "CWeatherFront": ("A weather system: where it is, which way it is going, how fast.",
                      None, 0),
    "CTerrainGraphical": ("How a terrain type is drawn. What it *does* is CTerrain.", None, 0),
    "CDirectorySettings": ("The path table the loader fills. `replace` and `extend` are how a "
                           "mod says whether its folder replaces the base game's or adds to "
                           "it.", None, 0),
    "CUndeclaredWar": ("The save's record of a war nobody declared.", None, 0),
    "CRelationTrigger": ("The `relation` trigger's own grammar - whose relation, with whom, "
                         "and the value.", None, 0),
    "CSettings": ("The player's settings as the game writes them back.", None, 0),
    "CWarGoal": ("One war goal in progress: who wants what from whom.", None, 0),
    "CDiplomacyStatus": ("What two countries have between them - access, debt, threat, the "
                         "occupation policy.", None, 0),
    "CEventScope": ("The scope an event fires in - the country, province or rebel faction it "
                    "is about, and the seed for its random numbers.", None, 0),
    "CTutorialChapter": ("One chapter of the tutorial script.", None, 0),
}


def keysUsed(path, depth):
    used = collections.Counter()
    for name in glob.glob(os.path.join(MOD, path)):
        here = 0
        for line in open(name, encoding="latin-1"):
            line = line.split("#")[0]
            if here == depth:
                for key in re.findall(r"(?<![\w.\"])([A-Za-z_][A-Za-z_0-9]*)\s*=", line):
                    used[key] += 1
            here += line.count("{") - line.count("}")
    return used


def collect():
    """owner row -> its keywords, for every loader that yields any."""
    names = switchmap.tokenNames()
    rows, _ = progress.collect()
    groups = {}
    for row in sorted((r for r in rows if r["loader"]),
                      key=lambda r: (-r["grammar"], r["name"])):
        groups.setdefault(row["loader"], []).append(row)

    out = []
    for loader, here in groups.items():
        hereNames = {r["name"] for r in here}
        roots = [r for r in here if not (r["ancestors"] & hereNames)]
        owner = min(roots or here, key=lambda r: (len(r["name"]), r["name"]))
        if owner["kind"] in ("interface", "null"):
            continue
        try:
            found = switchmap.cases(loader + 0x400000)
        except Exception:
            continue
        keywords = sorted(k for k in {names[t] for t in found if names.get(t)}
                          if IDENTIFIER.match(k) and (owner["name"], k) not in SPURIOUS)
        if keywords:
            out.append((owner, loader, len(here), keywords))
    out.sort(key=lambda entry: (-len(entry[3]), entry[0]["name"]))
    return out


KIND_WORD = {"file": "a file", "save": "a save block", "script": "an event script",
             "live": "not persisted"}


def writtenElsewhere():
    """loader rva -> where its own account lives, for the ones not generated here."""
    doc = json.load(open(PROJECT, encoding="utf-8"))
    return {int(a["rva"], 16): a["source"] for a in doc["addresses"]
            if (a.get("name") or "").endswith("::LoadKey")
            and a.get("source") not in (None, OWN_SOURCE)}


def write(entries):
    elsewhere = writtenElsewhere()
    lines = [
        "# Every loader's grammar, key by key",
        "",
        "Most of the game's classes read themselves through one `LoadKey` that is a switch over",
        "the save tokens, a case per key. **The case list is the grammar** - there is nothing",
        "else that loader accepts, and a key it does not know is dropped in silence.",
        "",
        "**Generated by `definitions.py`** from `switchmap.py`, which reads the switch itself",
        "rather than the decompiler's C. `FINDINGS-script.md` has the shapes a switch comes in",
        "and what each one costs if you miss it, and holds the two big ones - `CTrigger` with",
        "153 keywords and `CEffect` with 91.",
        "",
        "**%d loaders**, listed longest first. Where a class has a `common/` file of its own"
        % len(entries),
        "the keys are checked against it - anything the file uses that the loader does not know",
        "is a bug, and those are collected in the mod's `bugs.md`.",
        "",
    ]

    pointed = [e for e in entries if e[1] in elsewhere]
    annotated = [e for e in entries if e[0]["name"] in NOTES and e[1] not in elsewhere]
    rest = [e for e in entries
            if e[0]["name"] not in NOTES and e[1] not in elsewhere]

    lines += ["## Written up in full elsewhere", "",
              "These have an account of their own, because their grammar is more than the",
              "switch - a database lookup, a base class, a sub-object. The key count here is",
              "only what the switch itself carries.", "",
              "| class | LoadKey | switch keys | where |", "| --- | --- | --- | --- |"]
    for owner, loader, shared, keywords in sorted(pointed, key=lambda e: e[0]["name"]):
        lines.append("| `%s` | `0x%X` | %d | %s |"
                     % (owner["name"], loader, len(keywords), elsewhere[loader]))
    lines.append("")

    lines += ["## The ones worth a sentence", ""]
    for owner, loader, shared, keywords in annotated:
        blurb, path, depth = NOTES[owner["name"]]
        lines += ["### `%s`" % owner["name"], "", blurb, "",
                  "`LoadKey` at `0x%X`, reads %s, **%d keys**:"
                  % (loader, KIND_WORD.get(owner["kind"], owner["kind"]), len(keywords)), ""]
        lines += ["```"]
        for i in range(0, len(keywords), 3):
            lines.append("    " + "  ".join("%-30s" % k for k in keywords[i:i + 3]).rstrip())
        lines += ["```", ""]
        if path:
            used = keysUsed(path, depth)
            missing = sorted(((n, k) for k, n in used.items() if k not in keywords),
                             reverse=True)
            unused = [k for k in keywords if k not in used]
            lines += ["Against `%s`:" % path, "", "| | |", "| --- | --- |"]
            lines.append("| in the file but **not a key** | %s |"
                         % (", ".join("`%s` (%d)" % (k, n) for n, k in missing) or "none"))
            lines.append("| a key the file never uses | %s |"
                         % (", ".join("`%s`" % k for k in unused) or "none"))
            lines.append("")

    lines += ["## Everything else", "",
              "One row per loader. **classes** is how many share it, because a `LoadKey` is",
              "inherited - reading one of these reads all of them.", "",
              "| class | LoadKey | reads | classes | keys |",
              "| --- | --- | --- | --- | --- |"]
    for owner, loader, shared, keywords in rest:
        lines.append("| `%s` | `0x%X` | %s | %s | %s |"
                     % (owner["name"], loader, KIND_WORD.get(owner["kind"], owner["kind"]),
                        shared if shared > 1 else "",
                        " ".join("`%s`" % k for k in keywords)))
    lines.append("")
    io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote %s: %d loaders, %d of them annotated"
          % (OUT, len(entries), len(annotated)))


def findings(entries):
    doc = json.load(open(PROJECT, encoding="utf-8"),
                    object_pairs_hook=collections.OrderedDict)
    by = {a["rva"].upper(): a for a in doc["addresses"]}
    added = 0
    kept = 0
    for owner, loader, shared, keywords in entries:
        rva = "0x%X" % loader
        entry = by.get(rva.upper())
        # **Never overwrite something written by hand.** A generated sentence is worse than
        # a considered one, and for a loader whose grammar is not only its switch it is also
        # wrong - CGovernment's says "the whole grammar, 2 keys" when two databases and a
        # base class handle the rest. Anything sourced elsewhere is left exactly as it is.
        if entry is not None and entry.get("source") not in (None, OWN_SOURCE):
            kept += 1
            continue
        if entry is None:
            entry = collections.OrderedDict([("rva", rva), ("kind", "function")])
            doc["addresses"].append(entry)
            added += 1
        name = owner["name"]
        blurb = NOTES.get(name, ("", None, 0))[0]
        entry["name"] = "%s::LoadKey" % name
        entry["signature"] = ("void __thiscall %s::LoadKey(%s* this, CParseContext* parse, "
                              "SaveToken key)" % (name, name))
        entry["comment"] = (
            "%s**The keys its switch names**, %d of them, one case each: %s.%s Read from the "
            "switch by reversing/definitions.py. A loader may resolve further keys as names "
            "out of a database - CGovernment and CMinister both do - but anything that is "
            "neither is dropped in silence."
            % (blurb + " " if blurb else "", len(keywords),
               ", ".join("`%s`" % k for k in keywords),
               "" if shared == 1 else
               " Inherited by %d classes in all." % shared))
        entry["confidence"] = "confirmed"
        entry["source"] = OWN_SOURCE
    doc["addresses"].sort(key=lambda e: int(e["rva"], 16))
    io.open(PROJECT, "w", encoding="utf-8", newline="\n").write(
        json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    print("project.json: %d loaders, %d new, %d left to their own comment"
          % (len(entries), added, kept))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--findings", action="store_true",
                        help="also write every loader into ghidra/project.json")
    args = parser.parse_args()
    entries = collect()
    write(entries)
    if args.findings:
        findings(entries)


if __name__ == "__main__":
    main()
