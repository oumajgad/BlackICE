"""Reconciles the three halves of the fact base: project.json, the Lua half, the headers.

    python scripts/reconcileFacts.py                  the summary - start here
    python scripts/reconcileFacts.py --extras         every field the Lua half has that project.json has not
    python scripts/reconcileFacts.py --disagree       every offset the two give different names
    python scripts/reconcileFacts.py --accessors      the tiny accessors, re-derived from the bytes
    python scripts/reconcileFacts.py --grep 0xF88     the three-path lookup trap 14 asks for
    python scripts/reconcileFacts.py --json out.json  the same, machine readable

**Why this exists.** `ghidra/project.json` is hand-maintained, the `GameClasses/*.hpp`
headers are the C++ side, and `ghidra/luabind.json` -> `ghidra/bicelib_findings.json` is the
**Lua half**: every field the game's own luabind registrations give away, merged by
`buildFindings.py` and therefore **already showing in Ghidra** while absent from the file
everybody greps. The three drift, and any one of them can be the stale one.

`buildFindings.py` resolves a collision by *priority*: a name the game gives itself wins
(0 for `def_readwrite`, 1 for an accessor) over BiceLib's own (2 for a header, 3 for
everything else), and the loser is demoted into the comment as `BiceLib: <name> ...`. So
**where the two disagree it is the Lua name Ghidra shows**, and a wrong one reaches the
decompilation without `project.json` recording anything wrong at all. That is what
`--disagree` is for.

**The Lua half stores offsets as decimal integers.** `grep 0xF88` over
`bicelib_findings.json` finds nothing; what is there is `{"offset": 3976, "name": "Allies"}`.
A hex grep is a silent false negative, and that one gap kept `CCountry +0xF88` an open
question for a whole wave with `CCountry::GetAllies` sitting in the repository. `--grep`
takes either spelling and looks in all three places.

**What this tool does not do.** It compares records; it does not read the game. A field it
calls *free and trustworthy* is one whose accessor body it re-derived from
`hoi3_tfh.exe` - two instructions, the whole function being the offset - which settles the
offset and nothing else. The *name* is the one the Lua API registered and the *class* is
the one the registration named; what is never safe is putting that class on the **function**,
because the linker folds identical two-instruction bodies (trap 4). `--accessors` prints
the holder count beside each one for exactly that reason.
"""

import argparse
import collections
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)
GHIDRA = os.path.join(REVERSING, "ghidra")
HEADERS = os.path.join(REVERSING, "..", "BiceLib", "GameClasses")

sys.path.insert(0, HERE)
sys.path.insert(0, GHIDRA)

IMAGE_BASE = 0x400000


def load(path):
    return json.load(io.open(path, encoding="utf-8"))


def offsetOf(value):
    """project.json spells an offset "0x604"; the Lua half spells the same thing 1540."""
    if isinstance(value, str):
        return int(value, 16)
    return value


# ---------------------------------------------------------------- the three halves

def handFields(project):
    """project.json's own struct records: name -> {offset: field}"""
    out = {}
    for struct in project.get("structs", []):
        out[struct["name"]] = {offsetOf(f["offset"]): f for f in struct.get("fields", [])}
    return out


def luaFields(lua):
    """the Lua half's own: name -> {offset: field}, keyed by the RTTI class name

    `buildFindings.py` files a registration under `rtti or cpp`, so this does too -
    otherwise a class luabind knows by a different name lands in a struct of its own and
    every field in it looks new.
    """
    out = collections.defaultdict(dict)
    for record in lua["classes"]:
        name = record["rtti"] or record["cpp"]
        for field in record["fields"]:
            out[name][field["offset"]] = field
    return out


def generatedFields(generated):
    """what the build actually lays down, after inheritance, CList plumbing and folding"""
    return {s["name"]: {f["offset"]: f for f in s["fields"]} for s in generated["structs"]}


def headerText():
    """every GameClasses header, concatenated - the third half, and it is prose not JSON"""
    chunks = []
    if not os.path.isdir(HEADERS):
        return chunks
    for name in sorted(os.listdir(HEADERS)):
        if name.endswith(".hpp") or name.endswith(".cpp"):
            path = os.path.join(HEADERS, name)
            chunks.append((os.path.join("BiceLib", "GameClasses", name),
                           io.open(path, encoding="utf-8", errors="replace").read()))
    return chunks


# ---------------------------------------------------------------- provenance

GENERATED_LIST = re.compile(r"^(CList<|CListNode<|CUnitList$|CCountryList$)")


def provenance(struct, offset, field, lua, hand):
    """where a field the generated record has and project.json has not came from

    Four answers, and only two of them are facts about the game:

    `lua def_readwrite`  the registration carried a member pointer - the offset is a
                         constant in the image, which is as strong as evidence gets
    `lua accessor`       luabindExtract read it out of a two-instruction accessor body
    `inherited`          `buildFindings.py` copied a base's field onto a derived struct,
                         because Ghidra has no inheritance between structures. Nothing
                         new is being claimed and nothing is there to record.
    `generated CList`    the one recorded `CList` shape stamped onto an instantiation, or
                         a `CListNode<T>` the build makes so a node's `data` has a type.
    """
    if offset in lua.get(struct, {}):
        evidence = lua[struct][offset]["evidence"]
        return "lua def_readwrite" if evidence.startswith("luabind def_") else "lua accessor"
    comment = field.get("comment") or ""
    if "inherited from" in comment:
        return "inherited"
    if GENERATED_LIST.match(struct):
        return "generated CList"
    return "other"


def extras(hand, lua, gen):
    """(struct, offset, field, provenance) for every generated field project.json lacks"""
    out = []
    for struct, fields in gen.items():
        known = hand.get(struct, {})
        for offset, field in sorted(fields.items()):
            if offset not in known:
                out.append((struct, offset, field,
                            provenance(struct, offset, field, lua, hand)))
    return out


def disagreements(hand, gen):
    """(struct, offset, project.json's field, the generated one) where the names differ"""
    out = []
    for struct, fields in sorted(gen.items()):
        known = hand.get(struct, {})
        for offset, field in sorted(fields.items()):
            mine = known.get(offset)
            if mine is not None and mine["name"] != field["name"]:
                out.append((struct, offset, mine, field))
    return out


def duplicateFields(project):
    """(struct, offset, [field, ...]) where project.json holds two records for one offset

    `mergeFindings --check` refuses this now, but four pairs predate the check. They are
    not harmless: `merge_fields` keeps one and demotes the other into its comment, so the
    *first* record's type is what Ghidra lays down. `CDiplomacyStatus +0x14` has a `void*`
    record and a `CAlliance*` record, and the decompilation gets the `void*`.
    """
    out = []
    for struct in project.get("structs", []):
        seen = collections.defaultdict(list)
        for field in struct.get("fields", []):
            seen[offsetOf(field["offset"])].append(field)
        for offset, records in sorted(seen.items()):
            if len(records) > 1:
                out.append((struct["name"], offset, records))
    return out


def luaFolds(project, lua):
    """names in project.json whose body another luabind registration also claims

    **Trap 4's holder count has only ever been run against the virtual tables.** The
    luabind registrations are a second, independent source of claimants on one address,
    and a two-instruction getter is exactly what the linker folds. A body with two
    registrations naming two unrelated classes cannot carry either class's name, however
    many vftables it is absent from - and `image.findValue` cannot see this either,
    because a Lua accessor is reached through a registration table, not a call.
    """
    byAddress = collections.defaultdict(set)
    for function in lua["functions"]:
        if function.get("address"):
            byAddress[function["address"]].add(function["cpp"])
    recorded = {int(a["rva"], 16): a["name"] for a in project["addresses"]}
    out = []
    for va, names in sorted(byAddress.items()):
        rva = va - IMAGE_BASE
        mine = recorded.get(rva)
        if mine is None or "::" not in mine:
            continue                       # unrecorded, or already class-free: nothing to fix
        claimants = {n.split("::")[0] for n in names if "::" in n}
        if claimants - {mine.split("::")[0]}:
            out.append((rva, mine, sorted(names)))
    return out


def spelling(a, b):
    """whether two names are the same word differently spelled

    `cost`/`Cost`, `country_tag`/`CountryTag`, `mobilised`/`isMobilized`,
    `is_ship`/`isShip` - the overwhelming majority of the disagreements, and inflating
    them hides the handful that are about the field rather than the wording. British and
    American spellings of the same word count as the same word.
    """
    def norm(text):
        text = re.sub(r"[^a-z0-9]", "", text.lower())
        text = re.sub(r"^(is|has|use|can)", "", text)
        text = text.replace("ised", "ized").replace("isation", "ization")
        return text
    return norm(a) == norm(b)


# ---------------------------------------------------------------- the bytes

def accessorCheck(addresses):
    """{virtual address: (offset, how)} re-derived from the executable

    Imported lazily: the comparison above needs no executable, and this does.
    """
    import luabindExtract as LX                      # noqa: E402  (lazy on purpose)
    # `LX.accessor_field` wants luabindExtract's own Image, not `scripts/image.py` - the
    # two are different objects and only this one has `body()`. Passing the wrong one
    # raises on every address, which looks exactly like "no accessor is what it claims".
    exe = LX.Image(LX.EXE)
    out = {}
    for va in addresses:
        try:
            out[va] = LX.accessor_field(exe, va)
        except Exception as problem:                 # a bad address is a result, not a crash
            out[va] = ("error", str(problem))
    return out


def holders(addresses):
    """{virtual address: [(class, slot)]} - which virtual tables hold each body

    This is trap 4's check and it has to run before a class name goes on a function.
    `image.findValue` is **not** this check: it scans `.text`, and virtual tables live in
    `.rdata`.
    """
    import mergeFindings as MF                       # noqa: E402  (lazy: it loads the image)
    tables = MF.inTables()
    return {va: tables.get(va, []) for va in addresses}


# ---------------------------------------------------------------- reporting

def report(args):
    project = load(os.path.join(GHIDRA, "project.json"))
    lua = load(os.path.join(GHIDRA, "luabind.json"))
    generated = load(os.path.join(GHIDRA, "bicelib_findings.json"))

    hand, luaf, gen = handFields(project), luaFields(lua), generatedFields(generated)
    extra = extras(hand, luaf, gen)
    differ = disagreements(hand, gen)

    counts = collections.Counter(kind for _, _, _, kind in extra)
    byStruct = collections.Counter(struct for struct, _, _, _ in extra)
    actionable = [row for row in extra if row[3].startswith("lua")]
    landable = [row for row in actionable if row[0] in hand]

    print("project.json      %d structs, %d fields"
          % (len(hand), sum(len(v) for v in hand.values())))
    print("generated record  %d structs, %d fields"
          % (len(gen), sum(len(v) for v in gen.values())))
    print("the Lua half      %d classes, %d fields"
          % (len(luaf), sum(len(v) for v in luaf.values())))
    print()
    print("fields the generated record has and project.json has no field for: %d, across %d structs"
          % (len(extra), len(byStruct)))
    for kind, n in counts.most_common():
        print("   %-20s %4d" % (kind, n))
    print()
    print("   of those, %d are facts about the game (the two `lua` rows) and %d of those"
          % (len(actionable), len(landable)))
    print("   are on a struct project.json records, so `struct_fields` can land them.")
    print("   The other %d need a struct record first - mergeFindings refuses a field on"
          % (len(actionable) - len(landable)))
    print("   a struct it has never heard of, and a fragment cannot add one.")
    print()
    print("the biggest clusters, which is the part that misleads:")
    for struct, n in byStruct.most_common(10):
        kinds = collections.Counter(k for s, _, _, k in extra if s == struct)
        print("   %-30s %3d  %s" % (struct, n,
                                    ", ".join("%d %s" % (v, k) for k, v in kinds.most_common())))
    print()
    same = [row for row in differ if spelling(row[2]["name"], row[3]["name"])]
    print("offsets where the two give different names: %d" % len(differ))
    print("   %d are the same word spelled differently; %d are worth reading"
          % (len(same), len(differ) - len(same)))

    duplicates = duplicateFields(project)
    print("\nproject.json's own duplicate field records: %d" % len(duplicates))
    for struct, offset, records in duplicates:
        print("   %-20s 0x%-6X %s  <- the first is what Ghidra gets"
              % (struct, offset,
                 " / ".join("%s %s" % (r["type"], r["name"]) for r in records)))

    folds = luaFolds(project, lua)
    print("\nproject.json names that sit on a body another luabind registration claims: %d"
          % len(folds))
    print("   (trap 4, from the source it has never been run against - see luaFolds)")
    for rva, mine, names in folds:
        print("   rva 0x%-8X %-42s also %s" % (rva, mine, ", ".join(names)))

    if args.extras:
        print("\n==== every extra field, by struct")
        for struct in sorted({s for s, _, _, _ in extra}):
            rows = [r for r in extra if r[0] == struct]
            print("\n-- %s  (%s)" % (struct, "in project.json" if struct in hand
                                     else "NO STRUCT RECORD - a field here cannot land"))
            for _, offset, field, kind in rows:
                print("   0x%-6X %-32s %-34s %s"
                      % (offset, field["name"], field["type"], kind))

    if args.disagree:
        print("\n==== the disagreements (project.json | the generated record, which is what Ghidra shows)")
        for struct, offset, mine, theirs in differ:
            mark = "spelling" if spelling(mine["name"], theirs["name"]) else "READ IT  "
            print("   %s %-26s 0x%-6X %-28s %-22s | %-28s %s"
                  % (mark, struct, offset, mine["name"], mine["type"],
                     theirs["name"], theirs["type"]))

    if args.accessors:
        print("\n==== the Lua half's accessors, re-derived from hoi3_tfh.exe")
        print("`lea`/`mov` is the whole body, so the function *is* the offset. `holders` is")
        print("trap 4: a body in more than one of them was folded by the linker and cannot")
        print("carry any one class's name, however safe the field it proves is.\n")
        wanted = {}
        for struct, offsets in luaf.items():
            for offset, field in offsets.items():
                match = re.search(r" at ([0-9A-Fa-f]{6,8})$", field["evidence"])
                if match:
                    wanted.setdefault(int(match.group(1), 16), []).append((struct, offset, field))
        checked = accessorCheck(sorted(wanted))
        held = holders(sorted(wanted))
        registered = collections.Counter()
        for function in lua["functions"]:
            if function.get("address"):
                registered[function["address"]] += 1
        recorded = {int(a["rva"], 16): a["name"] for a in project["addresses"]}
        for va in sorted(wanted):
            derived = checked.get(va)
            for struct, offset, field in wanted[va]:
                agrees = derived and derived[0] == offset
                print("   %s rva 0x%-7X %-24s +0x%-5X %-28s holders: %d lua, %d vftable%s"
                      % ("ok " if agrees else "!! ", va - IMAGE_BASE, struct, offset,
                         field["name"], registered[va], len(held.get(va, [])),
                         "" if (va - IMAGE_BASE) not in recorded
                         else "   [project.json: %s]" % recorded[va - IMAGE_BASE]))

    if args.grep:
        text = args.grep
        try:
            number = int(text, 16) if text.lower().startswith("0x") else int(text)
        except ValueError:
            number = None
        print("\n==== %s, in all three halves%s"
              % (text, "" if number is None else " (0x%X == %d)" % (number, number)))
        if number is not None:
            for struct, fields in sorted(hand.items()):
                if number in fields:
                    print("   project.json   %s +0x%X = %s (%s)"
                          % (struct, number, fields[number]["name"], fields[number]["type"]))
            for struct, fields in sorted(luaf.items()):
                if number in fields:
                    print("   the Lua half   %s +0x%X = %s (%s) - %s"
                          % (struct, number, fields[number]["name"], fields[number]["type"],
                             fields[number]["evidence"]))
            for entry in project["addresses"]:
                if int(entry["rva"], 16) == number:
                    print("   project.json   rva 0x%X is %s" % (number, entry["name"]))
            needles = ("0x%X" % number, "0x%x" % number, str(number))
            for entry in project["addresses"]:
                blob = entry.get("comment") or ""
                if any(n in blob for n in needles[:2]):
                    print("   a comment      %s mentions it" % entry["name"])
        for path, blob in headerText():
            if text in blob or (number is not None and "0x%X" % number in blob.upper()):
                print("   the headers    %s mentions it" % path)

    if args.json:
        out = {
            "project": {"structs": len(hand), "fields": sum(len(v) for v in hand.values())},
            "generated": {"structs": len(gen), "fields": sum(len(v) for v in gen.values())},
            "extras": [{"struct": s, "offset": "0x%X" % o, "name": f["name"],
                        "type": f["type"], "provenance": k} for s, o, f, k in extra],
            "disagreements": [{"struct": s, "offset": "0x%X" % o,
                               "project": {"name": a["name"], "type": a["type"]},
                               "generated": {"name": b["name"], "type": b["type"]},
                               "spelling": spelling(a["name"], b["name"])}
                              for s, o, a, b in differ],
        }
        with io.open(args.json, "w", encoding="utf-8") as handle:
            json.dump(out, handle, indent=1, ensure_ascii=True)
        print("\nwrote %s" % args.json)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--extras", action="store_true",
                        help="every field the generated record has that project.json has not")
    parser.add_argument("--disagree", action="store_true",
                        help="every offset where the two give different names")
    parser.add_argument("--accessors", action="store_true",
                        help="re-derive each Lua accessor's offset from the executable")
    parser.add_argument("--grep", metavar="OFFSET",
                        help="one offset, hex or decimal, looked up in all three halves")
    parser.add_argument("--json", metavar="PATH", help="write the comparison as JSON")
    report(parser.parse_args())


if __name__ == "__main__":
    main()
