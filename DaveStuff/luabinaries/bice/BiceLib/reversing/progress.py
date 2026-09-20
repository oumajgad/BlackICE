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
    "CModifier": "one loader shared by `CProvinceModifier`, `CStaticModifier`, "
                 "`CFactionModifier` and two more - `static_modifiers.txt` and "
                 "`event_modifiers.txt`, which reach everything",
    "CMap": "the map load rather than a `common/` file",
    "CGainableTrait": "`gainable_traits.txt`; its trigger grammar belongs to CTrigger, unread",
    "CMinisterType": "`minister_types.txt`, a CModifier",
    "CIdeology": "one ideology, a CModifier; its key and index are read",
    "CCountryHistory": "**read**: `history/countries`, where a date is a key. See "
                       "GameClasses/CCountryHistory.hpp",
    "CProvinceHistory": "**read**: `history/provinces`, the same date-block shape as "
                        "CCountryHistory. Its handler names four keys; the rest are buildings",
    "CCombatTactic": "**read**: `combat_tactics.txt`, 9 keys and the file uses exactly those. "
                     "See FINDINGS-definitions.md",
    "CCasusBelliType": "**read**: `cb_types.txt`, 28 keys - the `po_*` peace options among them",
    "CRebelType": "**read**: `rebel_types.txt`, 17 keys. `unit_transfer` is not one, though the "
                  "file uses it - see the mod's bugs.md",
    "CIdeologyGroup": "**read**: `ideologies.txt`. Two keys of its own; every other key in a "
                      "group is an ideology's name",
    "CBookmark": "**read**: `bookmarks.txt`, 7 keys",
    "CCounterType": "**read**: how a map counter is drawn, 18 keys",
    "CDefines": "**read**: the nine top-level blocks of `defines.lua`",
    "CScenario": "**read**: a scenario - selectable countries, camera, victory conditions",
    "CMeanTimeToHappen": "**read**: the MTTH grammar every event and decision is timed by",
    "CDiplomacy": "**read**: the save's diplomacy block, one key per kind of agreement",
    "CUnitPlan": "**read**: a battle plan as the save keeps it",
    "CWeatherFront": "**read**: a weather system - where it is and where it is going",
    "CTerrainGraphical": "**read**: how a terrain type is drawn. `CTerrain` is what it does",
    "CDirectorySettings": "**read**: the path table; `replace` and `extend` are how a mod says "
                          "whether its folder replaces the base game's",
    "CUndeclaredWar": "**read**: the save's record of a war nobody declared",
    "CRelationTrigger": "**read**: the `relation` trigger's own grammar",
    "CGovernmentPosition": "one government position, a CModifier; its key and index are read",
    "CTrigger": "**read**: 152 keywords, one class each - the whole trigger half of the event "
                "script language. See FINDINGS-script.md",
    "CEffect": "**read**: 91 keywords, one class each - the effect half. See FINDINGS-script.md",
    "CTechStatistics": "**read**: the 47 country-wide effects a technology can have, one "
                       "case each. See GameClasses/CCountryHistory.hpp",
    "CTutorialChapter": "the tutorial script; plumbing",
    "CRule": "plumbing",
    "CEU3SoundConfigurator": "plumbing",
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


def primaryChain(rtti, name):
    """
    The classes a class shares its first vftable with.

    **A CPersistent slot only means what it means on this chain.** CGameSetup reaches
    CPersistent through a secondary base and is really a CFrontEndView, so slot 4 of its
    first vftable is a view's method, not LoadKey - and reading it as a loader put a UI
    function at the top of the ranked list as the biggest unread grammar in the game.
    """
    chain = [name]
    while len(chain) < 16:
        bases = [b for b in rtti.get(chain[-1], {}).get("bases") or [] if b["offset"] == 0]
        if not bases:
            break
        chain.append(bases[0]["name"])
    return chain


def loaderSize(image, address):
    """
    How many bytes of grammar a loader carries: up to its trailing int3 padding.

    **A rough figure, and it can be far too big.** Where the next function follows with no
    padding between them the scan runs straight on into it - `CHistoryContainer::LoadKey`
    measures 4596 bytes and is about sixty lines. Use it to rank, never to conclude.
    """
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
    loadersRead = set()
    for entry in project["addresses"]:
        name = entry.get("name") or ""
        if entry.get("kind") == "function" and "::" in name:
            owner, member = name.split("::")[0], name.split("::")[-1]
            functions[owner] += 1
            # A loader we chose to name and comment is one somebody read through.
            # LoadEntry counts too: the two histories keep their grammar there, because
            # their LoadKey is CHistoryContainer's and only handles the dates.
            if member in ("LoadKey", "LoadEntry") and entry.get("source"):
                loadersRead.add(owner)

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
        persistent = "CPersistent" in primaryChain(rtti, name)
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
        elif "CPersistent" in ancestors(rtti, name) and kind == "live":
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
            "loader_read": name in loadersRead,
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
    # **Knowing a class's grammar is not knowing its layout.** definitions.py reads the
    # keys out of a loader's switch for 263 classes, which says exactly what a file may
    # contain and nothing at all about where any of it lands in the object. That deserves
    # its own mark rather than being folded into `read`, which would claim 274 classes
    # were understood when a dozen of them have not one named field.
    if row["loader_read"]:
        return "keys"
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
        "object's layout. It does **not** mean every field is known |" % ENOUGH,
        "| `keys` | **its loader's grammar is known** - every key the file or save block may "
        "contain, out of the switch that parses them - but its fields are not. See "
        "FINDINGS-definitions.md |",
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
    for mark in ("read", "keys", "part", "named", "RTTI"):
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
        "**Every one of them has been read.** The keys are in FINDINGS-definitions.md, and the",
        "two big ones - `CTrigger` and `CEffect` - in FINDINGS-script.md. Anything that turns up",
        "here again is a loader `switchmap.py` has newly learned to see, or one somebody has",
        "since un-named; it is ranked by the bytes of the loader, which is a rough figure and",
        "only that, because where a loader abuts the next function the count runs into it.",
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
        if status(owner) in ("read", "keys") or owner["kind"] in ("interface", "null"):
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
    if not shown:
        lines += ["*(nothing - every loader the game has is read.)*", ""]
    lines += ["",
              "**What is left is layout, not grammar.** Knowing every key a file may contain",
              "says nothing about where any of it lands in the object, and that is what the",
              "`keys` mark below means. The classes worth taking further are the ones with a",
              "big `live` count and no fields named - those are where the memory is.",
              "",
              "The method is in README.md, *How to read one*, with the traps that cost the",
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
    print("wrote %s: %d classes, %d read, %d with their grammar known, %d part"
          % (OUT, len(rows), counts["read"], counts["keys"], counts["part"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
