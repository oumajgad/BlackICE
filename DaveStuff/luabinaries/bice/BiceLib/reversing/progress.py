"""Writes PROGRESS.md: every class the game has, and how far each one is read.

    python progress.py                  # rewrites PROGRESS.md
    python progress.py --check          # says whether it is out of date, writes nothing

Everything in the document is derived, so it cannot drift from the findings:

    the RTTI export      every class, its bases, its vftables and how many slots
    the executable       which loader each class has and how many bytes of grammar
    project.json         the fields and functions **we** named, and the sizes
    luabind.json         the accessors recovered from the Lua API, which are free
    GameClasses/*.hpp    which classes BiceLib has written up
    ghidra/census.json   how many of each live, if a census has been taken

The one hand-written part is NOTES below - a line on why a class is worth reading. Add
one when you learn something a count cannot say. Everything else regenerates.

Take the census with `python census.py --json ghidra/census.json` while a game is
running; the document says when it was taken and works without it.
"""

import argparse
import collections
import datetime
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ghidra"))
import luabindExtract as LX

HERE = os.path.dirname(os.path.abspath(__file__))
GHIDRA = os.path.join(HERE, "ghidra")
CLASSES = os.path.join(HERE, "..", "BiceLib", "GameClasses")
OUT = os.path.join(HERE, "PROGRESS.md")

# The three shared stubs that say a class does not do that thing itself.
EMPTY_SAVE_CONTENTS = 0x60CD50
BASE_LOAD_KEY = 0xA9D050
EMPTY_AFTER_LOAD = 0xABF890

# What a class is for, which decides the section it lands in. First match wins.
KINDS = [
    ("null", re.compile(r"^CNull")),
    ("script", re.compile(r"(Effect|Trigger|Command|Change$|Option$|^CCgm|^CCGM|"
                          r"^CAiAction|^CDecision)")),
    ("interface", re.compile(r"(^CGui|^C2d|Window$|Page$|Dialog$|^CBattlePlanTool|"
                             r"^CMapMode|^CSprite|^CFont|^CText[A-Z]|Listbox|Button)")),
]

# Why a class is worth reading, where a count cannot say it. Hand-written; the only
# part of this document that is.
NOTES = {
    "CSubUnitDefinition": "**the unit files**, and the most used class in the mod. The stat "
                          "block is done; nine keys are still unplaced, most of them moved by "
                          "technology",
    "CTechnology": "the technology files: a dozen keys of its own, and every other key read as "
                   "a unit type's name, which is how an effect is written",
    "CGovernment": "`governments.txt`, a CModifier. Where the **null at index 0** of a name "
                   "database was found",
    "CTrait": "`traits.txt`: 31 effects and a count that stops at sixteen. `gainable_traits.txt` "
              "is a different class, `CGainableTrait`, still unread",
    "CHistoricalModel": "the unit models. **2.48 million objects, 114 MB** - every country keeps "
                        "a set per unit type. The picker they feed is where "
                        "`historicalModelLogicFix` patches",
    "CMinister": "a person, from `common/countries/<Country>.txt` - **not** `minister_types.txt`, "
                 "which is CMinisterType",
    "CBuilding": "`buildings.txt`, the worked example the method came from",
    "CTerrain": "mostly done; `movement_cost`, `temperature` and `precipitation` went in last",
    "CRebelType": "`rebel_types.txt`; partisan behaviour",
    "CCasusBelliType": "`cb_types.txt`",
    "CCombatTactic": "`combat_tactics.txt`; ties into the combat work already done",
    "CCounterType": "the map counters",
    "CDefines": "every constant the game reads; BiceLib has a handful in CDefines.hpp",
    "CIdeologyGroup": "`ideologies.txt`, and it holds a `CList<CIdeology*>` at +8 by RTTI",
    "CModifier": "one loader shared by `CProvinceModifier`, `CStaticModifier`, "
                 "`CFactionModifier` and two more - `static_modifiers.txt` and "
                 "`event_modifiers.txt`, which reach everything",
    "CScenario": "the scenario load rather than a `common/` file",
    "CMap": "the map load rather than a `common/` file",
    "CDirectorySettings": "the path table the loader fills",
    "CGainableTrait": "`gainable_traits.txt`; its trigger grammar belongs to CTrigger, unread",
    "CMinisterType": "`minister_types.txt`, a CModifier",
    "CIdeology": "one ideology, a CModifier; its key and index are read",
    "CGovernmentPosition": "one government position, a CModifier; its key and index are read",
    "CTrigger": "**the trigger grammar**, inherited by every trigger class there is - "
                "including the one `CGainableTrait` needs",
    "CEffect": "**the effect grammar**, inherited by every effect class - the other half of "
               "what an event script can say",
    "CTechStatistics": "the technology statistics the ledger draws",
    "CTutorialChapter": "the tutorial script; plumbing",
    "CRule": "plumbing",
    "CTerrainGraphical": "how terrain is drawn, not what it does - `CTerrain` is that",
    "CEU3SoundConfigurator": "plumbing",
    "CMeanTimeToHappen": "**the MTTH grammar** that events and decisions are timed by",
    "CSelectionGroupReader": "plumbing",
    "CEU3Application": "plumbing: the settings file",
}


def ancestors(rtti, name, seen=None):
    seen = set() if seen is None else seen
    for base in rtti.get(name, {}).get("bases") or []:
        if base["name"] not in seen:
            seen.add(base["name"])
            ancestors(rtti, base["name"], seen)
    return seen


def loaderSize(image, address):
    """How many bytes of grammar a loader carries: up to its trailing int3 padding."""
    data = image.read(address, 0x2600)
    match = re.search(b"\xcc\xcc\xcc\xcc", data)
    return match.start() if match else 0x2600


def documented():
    """Which classes a BiceLib header opens a namespace for."""
    out = {}
    for name in sorted(os.listdir(CLASSES)):
        if not name.endswith(".hpp"):
            continue
        text = io.open(os.path.join(CLASSES, name), encoding="utf-8").read()
        for match in re.finditer(r"^namespace\s+([A-Za-z_]\w*)\s*\{", text, re.M):
            out.setdefault(match.group(1), name)
    return out


def collect():
    image = LX.Image(LX.EXE)
    rtti = LX.load_rtti()
    project = json.load(open(os.path.join(GHIDRA, "project.json"), encoding="utf-8"))
    luabind = json.load(open(os.path.join(GHIDRA, "luabind.json"), encoding="utf-8"))
    findings = json.load(open(os.path.join(GHIDRA, "bicelib_findings.json"), encoding="utf-8"))

    ours = {s["name"]: s for s in project["structs"]}
    lua = collections.Counter()
    for record in luabind["classes"]:
        if record.get("rtti"):
            lua[record["rtti"]] += len(record.get("fields") or [])
    merged = {s["name"]: len(s.get("fields") or []) for s in findings["structs"]}

    functions = collections.Counter()
    for entry in project["addresses"]:
        name = entry.get("name") or ""
        if entry.get("kind") == "function" and "::" in name:
            functions[name.split("::")[0]] += 1

    headers = documented()
    census = {}
    censusTaken = None
    path = os.path.join(GHIDRA, "census.json")
    if os.path.exists(path):
        census = json.load(open(path, encoding="utf-8"))["counts"]
        censusTaken = datetime.date.fromtimestamp(os.path.getmtime(path)).isoformat()

    rows = []
    for name, record in rtti.items():
        if "::" in name or name.startswith("luabind") or record.get("library"):
            continue

        kind = None
        for label, pattern in KINDS:
            if pattern.search(name):
                kind = label
                break

        tables = [v for v in record.get("vftables") or [] if v["object_offset"] == 0]
        slots = tables[0]["slots"] if tables else 0
        loader, grammar = None, 0
        persistent = "CPersistent" in ancestors(rtti, name)
        if kind is None:
            kind = "live"
        if persistent and tables and slots >= 5:
            address = int(tables[0]["address"], 16)
            saveContents, loadKey = image.u32(address + 8), image.u32(address + 16)
            if loadKey not in (BASE_LOAD_KEY, EMPTY_SAVE_CONTENTS, EMPTY_AFTER_LOAD):
                loader = loadKey - 0x400000
                grammar = loaderSize(image, loadKey)
            if kind == "live":
                kind = "file" if saveContents == EMPTY_SAVE_CONTENTS else "save"
        elif persistent and kind == "live":
            kind = "save"

        entry = ours.get(name) or {}
        mine = len(entry.get("fields") or [])
        rows.append({
            "name": name,
            "kind": kind,
            "bases": [b["name"] for b in record.get("bases") or []],
            "size": entry.get("size"),
            "slots": slots,
            "mine": mine,
            "lua": lua.get(name, 0),
            "fields": merged.get(name, 0),
            "functions": functions.get(name, 0),
            "loader": loader,
            "grammar": grammar,
            "header": headers.get(name),
            "live": census.get(name, 0),
        })
    rows.sort(key=lambda r: r["name"])
    for row in rows:
        row["ancestors"] = ancestors(rtti, row["name"])
    return rows, censusTaken


# Five fields named by hand is the line between an account of a class and a toe-hold in
# it. It is a count, not a judgement: whether a header opens a namespace for the class is
# too weak a signal on its own - CCasusBelliType has one field and a namespace in CWar.hpp,
# while CGameState has 96 fields and lives in CCurrentGameState.hpp - so the header is a
# column of its own instead.
ENOUGH = 5


def status(row):
    """The marks CLASSES.md already uses, so the two documents say the same thing."""
    if row["mine"] >= ENOUGH:
        return "read"
    if row["mine"]:
        return "part"
    if row["lua"]:
        return "named"
    return "RTTI"


def table(rows, withNote=True):
    out = ["| class | derives from | size | fields | fn | doc | live | state | notes |",
           "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for row in rows:
        # What was named *for this class*, not what Ghidra ends up showing on it: a
        # derived class inherits its base's fields and counting those twice would say
        # CCurrentGameState and CGameState each have 48 when the 48 are CGameState's.
        fields = "%d" % row["mine"] if row["mine"] else ""
        if row["lua"]:
            fields = "%s%s%d lua" % (row["mine"] or "", " + " if row["mine"] else "",
                                     row["lua"])
        note = NOTES.get(row["name"], "") if withNote else ""
        out.append("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            row["name"],
            " ".join("`%s`" % b for b in row["bases"]) or "",
            row["size"] or "",
            fields,
            row["functions"] or "",
            row["header"] or "",
            "{:,}".format(row["live"]) if row["live"] else "",
            status(row),
            note))
    return out


def write(rows, censusTaken):
    counts = collections.Counter(status(r) for r in rows)
    kinds = collections.Counter(r["kind"] for r in rows)
    lines = [
        "# Where each class stands",
        "",
        "Every class the RTTI export names that is the game's own, and how far each one has",
        "been read. **Generated by `progress.py`** - edit that, not this. The prose account of",
        "what the read ones mean is CLASSES.md; this is only the scoreboard.",
        "",
        "| mark | means |",
        "| --- | --- |",
        "| `read` | at least %d of its fields have been named by hand - an account of the "
        "class rather than a toe-hold. It does **not** mean every field is known |" % ENOUGH,
        "| `part` | one to %d fields named by hand |" % (ENOUGH - 1),
        "| `named` | only what the Lua API gave away - an accessor per field, free and certain "
        "about the offset, silent about the meaning |",
        "| `RTTI` | nothing but the name, its bases and its vftable |",
        "",
        "`fields` is how many were named **on this class**, by hand and then by the Lua API -",
        "a derived class does not count its base's; `fn` is how many of its functions carry a name",
        "we chose; `doc` is the header that writes the class up, where there is one. `live` is",
        "how many objects a census found%s." % (
            " (taken %s)" % censusTaken if censusTaken
            else ", and no census has been taken, so the column is empty"),
        "",
        "## In one line",
        "",
        "| | classes |",
        "| --- | --- |",
    ]
    for mark in ("read", "part", "named", "RTTI"):
        lines.append("| `%s` | %d |" % (mark, counts.get(mark, 0)))
    lines += ["| **all** | **%d** |" % len(rows), ""]

    lines += [
        "## What to read next",
        "",
        "**A `LoadKey` is a grammar**, so reading one documents whatever it parses - a `.txt`",
        "under `common/` for the classes that never write a savegame, and a piece of the event",
        "script language for the rest. It is inherited, so one loader can belong to 157 classes",
        "and reading it is still one job.",
        "",
        "Ranked by the bytes of the loader, which is a rough count of keys, with the ones whose",
        "owner is already read left out:",
        "",
    ]
    # One row per loader, not per class. A LoadKey is inherited, so 157 trigger classes
    # share one and the five CModifier kinds share another: reading a shared loader is the
    # grammar for every class under it, which is one job rather than 157. The group is
    # every class that inherits the loader, whatever section it lands in, and it is named
    # for the base the others derive from.
    groups = collections.OrderedDict()
    for row in sorted((r for r in rows if r["loader"]),
                      key=lambda r: (-r["grammar"], r["name"])):
        groups.setdefault(row["loader"], []).append(row)

    KIND_WORD = {"file": "a file", "script": "event script", "save": "a save block",
                 "live": "-", "null": "-", "interface": "interface"}
    lines += ["| loader | bytes | owner | reads | classes | fields | why |",
              "| --- | --- | --- | --- | --- | --- | --- |"]
    shown = 0
    for loader, here in groups.items():
        names = {r["name"] for r in here}
        roots = [r for r in here if not (r["ancestors"] & names)]
        owner = min(roots or here, key=lambda r: (len(r["name"]), r["name"]))
        # The owner is what says whether this loader has been read. Its CNull sibling
        # shares the loader and will never be read, so judging the whole group would put
        # every finished class back on the list.
        if status(owner) == "read" or owner["kind"] in ("interface", "null"):
            continue
        note = next((NOTES[r["name"]] for r in here if r["name"] in NOTES), "")
        if not note and len(here) > 10:
            note = ("one loader inherited by all of them, so reading it once is the grammar "
                    "for every one")
        lines.append("| `0x%X` | %d | `%s` | %s | %s | %s | %s |"
                     % (loader, owner["grammar"], owner["name"],
                        KIND_WORD.get(owner["kind"], owner["kind"]),
                        len(here) if len(here) > 1 else "",
                        sum(r["fields"] for r in here) or "", note))
        shown += 1
        if shown == 22:
            break
    lines += ["",
              "The method is in README.md, *How to read one*, with the five traps that cost the",
              "most time.", ""]

    SECTIONS = [
        ("save", "Written to the savegame",
         "These carry a game in progress. Their `LoadKey` is the grammar of a save block."),
        ("file", "Read from a file, never saved",
         "Definitions out of `common/` and the rest of the mod. Their `LoadKey` is the grammar "
         "of a `.txt`, which is why reading one documents a file."),
        ("live", "Neither - live only",
         "Objects the game makes and never persists: managers, caches, the AI."),
        ("null", "The null objects",
         "One per name database, sitting at index 0 so that a lookup can fail without a null "
         "pointer. **They are why an index out of a database is 1-based against the mod's "
         "files.**"),
        ("script", "Event script plumbing",
         "One class per effect, trigger, command and decision the event scripts can use. Each "
         "is tiny and there are hundreds; they are listed for completeness."),
        ("interface", "Interface",
         "Windows, pages, sprites and the map's own drawing."),
    ]
    lines += ["## The classes", ""]
    for kind, title, blurb in SECTIONS:
        here = [r for r in rows if r["kind"] == kind]
        lines += ["### %s (%d)" % (title, len(here)), "", blurb, ""]
        lines += table(here)
        lines += [""]

    lines += ["---", "",
              "Regenerate with `python progress.py`; `--check` says whether it is stale.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="say whether PROGRESS.md is out of date and write nothing")
    args = parser.parse_args()

    rows, censusTaken = collect()
    text = write(rows, censusTaken)
    if args.check:
        current = io.open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        print("PROGRESS.md is %s" % ("up to date" if current == text else "OUT OF DATE"))
        return 0 if current == text else 1
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(text)
    counts = collections.Counter(status(r) for r in rows)
    print("wrote %s: %d classes, %d read, %d part, %d from the Lua API alone"
          % (OUT, len(rows), counts["read"], counts["part"], counts["named"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
