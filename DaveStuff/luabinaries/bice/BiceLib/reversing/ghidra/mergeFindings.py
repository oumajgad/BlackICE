"""Folds what an agent found into project.json, or says why it will not.

    python mergeFindings.py --check      what would land, changing nothing
    python mergeFindings.py              land it, and move the files to merged/

**Only this script writes project.json.** Agents write one file each into
`reversing/findings/incoming/`, which is what keeps several of them off a file with
hand-kept formatting and a hand-compacted block in it. Insertion here is textual for the
same reason: re-dumping the JSON reformats hundreds of lines and buries the real change.

## What an incoming file looks like

    {
     "agent": "who produced it",
     "question": "the question it was asked",
     "source": "reversing/FINDINGS-<topic>.md",
     "addresses": [
      {"rva": "0x1BB171", "kind": "instruction", "name": "...", "signature": null,
       "comment": "...", "confidence": "confirmed",
       "evidence": "what was checked, and what would show it wrong"}
     ],
     "struct_fields": [
      {"struct": "CUnit", "offset": "0x2E4", "name": "carrying",
       "type": "CList<CUnit*>", "comment": "...", "evidence": "..."}
     ],
     "vftable_slots": {"CUnit": {"32": "UpdateDaily"}},
     "frontier": ["0x1BB950", "0x1BD240"],
     "slots_noted": "only where a virtual is deliberately left unrecorded"
    }

`frontier` is what the function calls that nobody has named - the next wave's queue.

`evidence` is required and is **not** written into project.json - it is the reviewer's
handle, kept in the merge log. `source` must name a findings document that exists, so
every entry leads back to the reasoning behind it.

## What it refuses

- a name project.json already gives to a different address, or an address it already
  gives a different name - the two ways a second agent's work contradicts the first
- two incoming files disagreeing with each other
- `confirmed` without evidence, or a confidence that is neither of the two words
- a `__thiscall` signature whose name carries no `::`, which makes Ghidra invent a
  `this` and shift every argument along
- a function with no `signature` and no `no_signature` saying why it has none - a
  function you reversed gets renamed, moved into its class and given its signature, not
  just labelled
- a function that sits in a class's virtual table whose name carries no class, or whose
  file records no `vftable_slots` for it - **the tables stay current**, or the next
  person reads `vf_32` on three tables that all point at something already named
- a body the linker folded across many tables, which cannot be named for any one class

An entry that repeats something already recorded, identically, is skipped rather than
refused: two agents reaching the same answer is a good sign, not a conflict.

**This is not the last check.** `buildFindings.py` validates every entry against the
executable afterwards and the headless apply has to report `failed: 0`. Run both.
"""

import argparse
import glob
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import hoi3
import image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.join(HERE, "project.json")
ROOT = os.path.dirname(os.path.dirname(HERE))
INCOMING = os.path.join(HERE, "..", "findings", "incoming")
MERGED = os.path.join(HERE, "..", "findings", "merged")

ADDRESS_KEYS = ("rva", "kind", "name", "signature", "comment", "confidence", "source")
FIELD_KEYS = ("offset", "name", "type", "comment", "source")
KINDS = ("function", "instruction", "vftable", "global", "string", "jumptable")
CONFIDENCES = ("confirmed", "inferred")

# past this many tables a body is one the linker folded - `xor eax,eax; ret` is in 189 of
# them - and naming it for any one class would say something false about all the others
FOLDED = 8

_inTables = None


def inTables():
    """function virtual address -> [(class, slot)], built once"""
    global _inTables
    if _inTables is not None:
        return _inTables
    _inTables = {}
    for name, record in hoi3.classes().items():
        for table in record.get("vftables", []):
            start = int(table["address"], 16)
            slots = table.get("slots", 0)
            raw = image.read(start, slots * 4)
            for slot in range(len(raw) // 4):
                value = int.from_bytes(raw[slot * 4:slot * 4 + 4], "little")
                _inTables.setdefault(value, []).append((name, slot))
    return _inTables


def load():
    return json.load(io.open(PROJECT, encoding="utf-8"))


def problems(document, files):
    """every reason not to land this, as a list of sentences"""
    said = []
    byName = {e["name"]: int(e["rva"], 16) for e in document["addresses"]}
    byRva = {int(e["rva"], 16): e["name"] for e in document["addresses"]}
    structs = {s["name"]: {f["offset"].lower(): f for f in s.get("fields", [])}
               for s in document.get("structs", [])}
    claimedName = {}
    claimedRva = {}

    for path, incoming in files:
        who = os.path.basename(path)
        source = incoming.get("source")
        if not source:
            said.append("%s: no source" % who)
        elif not os.path.exists(os.path.join(ROOT, source)):
            said.append("%s: source %s does not exist" % (who, source))

        for entry in incoming.get("addresses", []):
            name = entry.get("name", "?")
            where = "%s / %s" % (who, name)
            for key in ADDRESS_KEYS:
                if key not in entry and key != "source":
                    said.append("%s: no %s" % (where, key))
            if entry.get("kind") not in KINDS:
                said.append("%s: kind %r is not one of %s"
                            % (where, entry.get("kind"), ", ".join(KINDS)))
            if entry.get("confidence") not in CONFIDENCES:
                said.append("%s: confidence must be confirmed or inferred" % where)
            if not entry.get("evidence"):
                said.append("%s: no evidence" % where)
            signature = entry.get("signature") or ""
            if "__thiscall" in signature and "::" not in name:
                said.append("%s: a __thiscall name needs a class, or Ghidra invents a "
                            "this and shifts the arguments" % where)

            # rename, move and give it a signature - not just a name
            if entry.get("kind") == "function" and not signature \
                    and not entry.get("no_signature"):
                said.append("%s: a function needs a signature, or no_signature saying "
                            "why it cannot have one" % where)
            try:
                rva = int(entry["rva"], 16)
            except (KeyError, ValueError):
                said.append("%s: rva is not hexadecimal" % where)
                continue
            # Only where it cannot be an rva: magnitude says nothing here, because
            # .text runs well past the image base and 0x680690 is a perfectly good rva.
            # Where both readings land in the image, leave it to buildFindings, which
            # checks the entry against the executable itself.
            if not image.read(image.toVa(rva), 1) and image.read(rva, 1):
                said.append("%s: 0x%X is only inside the image read as a virtual "
                            "address - subtract the image base" % (where, rva))

            # the virtual tables stay current
            tables = inTables().get(image.toVa(rva), [])
            if tables and len(tables) <= FOLDED:
                owners = sorted({owner for owner, _ in tables})
                if "::" not in name:
                    said.append("%s: that address is slot %d of %s, so the name wants "
                                "the class on it" % (where, tables[0][1],
                                                     ", ".join(owners)))
                covered = incoming.get("vftable_slots", {})
                wanted = set(owners) - set(covered)
                if wanted and not incoming.get("slots_noted"):
                    said.append("%s: it is in %d virtual table%s (%s) - record the slot "
                                "under vftable_slots, or say why not in slots_noted"
                                % (where, len(tables), "" if len(tables) == 1 else "s",
                                   ", ".join("%s slot %d" % (o, sl)
                                             for o, sl in sorted(tables))))
            elif len(tables) > FOLDED:
                said.append("%s: that body is in %d virtual tables, so the linker folded "
                            "it - it cannot be named for any one class" % (where, len(tables)))

            if name in byName and byName[name] != rva:
                said.append("%s: project.json already gives that name to 0x%X"
                            % (where, byName[name]))
            if rva in byRva and byRva[rva] != name:
                said.append("%s: project.json already calls 0x%X %s"
                            % (where, rva, byRva[rva]))
            if name in claimedName and claimedName[name] != (rva, who):
                said.append("%s: %s also names it, at 0x%X"
                            % (where, claimedName[name][1], claimedName[name][0]))
            if rva in claimedRva and claimedRva[rva][0] != name:
                said.append("%s: %s calls 0x%X %s instead"
                            % (where, claimedRva[rva][1], rva, claimedRva[rva][0]))
            claimedName[name] = (rva, who)
            claimedRva[rva] = (name, who)

        for field in incoming.get("struct_fields", []):
            where = "%s / %s.%s" % (who, field.get("struct"), field.get("name"))
            for key in FIELD_KEYS:
                if key not in field and key != "source":
                    said.append("%s: no %s" % (where, key))
            if not field.get("evidence"):
                said.append("%s: no evidence" % where)
            known = structs.get(field.get("struct"))
            if known is None:
                said.append("%s: no such struct in project.json" % where)
                continue
            have = known.get(str(field.get("offset", "")).lower())
            if have is not None and have["name"] != field["name"]:
                said.append("%s: that offset is already %s" % (where, have["name"]))
    return said


def alreadyThere(document, entry):
    for have in document["addresses"]:
        if have["name"] == entry["name"] and int(have["rva"], 16) == int(entry["rva"], 16):
            return True
    return False


def indent(entry, spaces):
    text = json.dumps(entry, indent=1, ensure_ascii=True)
    return "\n".join(" " * spaces + line for line in text.split("\n"))


def land(files):
    raw = io.open(PROJECT, encoding="utf-8").read()
    document = load()
    addresses = []
    fields = []

    for path, incoming in files:
        for entry in incoming.get("addresses", []):
            if alreadyThere(document, entry):
                continue
            clean = {k: entry.get(k) for k in ADDRESS_KEYS}
            clean["source"] = entry.get("source") or incoming["source"]
            addresses.append(clean)
        for field in incoming.get("struct_fields", []):
            clean = {k: field.get(k) for k in FIELD_KEYS}
            clean["source"] = field.get("source") or incoming["source"]
            fields.append((field["struct"], clean))

    slots = {}
    for path, incoming in files:
        for klass, entries in incoming.get("vftable_slots", {}).items():
            slots.setdefault(klass, {}).update({str(k): v for k, v in entries.items()})

    for klass, entries in slots.items():
        anchor = '  "%s": {\n' % klass
        if raw.count(anchor) != 1:
            raise SystemExit("vftable_slots for %s is not in the plain shape this can "
                             "edit - add it by hand" % klass)
        added = "".join('   "%s": "%s",\n' % (slot, name)
                        for slot, name in sorted(entries.items(), key=lambda kv: int(kv[0])))
        raw = raw.replace(anchor, anchor + added, 1)

    if addresses:
        close = "\n ],\n \"structs\": ["
        assert raw.count(close) == 1, "could not find the end of the addresses array"
        raw = raw.replace(
            close, ",\n" + ",\n".join(indent(e, 2) for e in addresses) + close, 1)

    for struct, field in fields:
        anchor = '  {\n   "name": "%s",\n' % struct
        assert raw.count(anchor) == 1, "could not find struct %s" % struct
        opening = anchor + '   "fields": [\n'
        if raw.count(opening) != 1:                 # a size or a vftable sits between
            at = raw.index(anchor)
            opening = raw[at:raw.index('"fields": [\n', at) + len('"fields": [\n')]
        raw = raw.replace(opening, opening + indent(field, 4) + ",\n", 1)

    io.open(PROJECT, "w", encoding="utf-8", newline="\n").write(raw)
    json.loads(io.open(PROJECT, encoding="utf-8").read())      # it still parses
    return len(addresses), len(fields)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="say what would land")
    args = parser.parse_args()

    paths = sorted(glob.glob(os.path.join(INCOMING, "*.json")))
    files = [(p, json.load(io.open(p, encoding="utf-8"))) for p in paths]
    if not files:
        print("nothing in findings/incoming")
        return

    document = load()
    said = problems(document, files)
    if said:
        print("refused, %d problem%s:" % (len(said), "" if len(said) == 1 else "s"))
        for line in said:
            print("   " + line)
        raise SystemExit(1)

    counts = sum(len(i.get("addresses", [])) for _, i in files)
    print("%d file%s, %d addresses, %d struct fields - no conflicts"
          % (len(files), "" if len(files) == 1 else "s", counts,
             sum(len(i.get("struct_fields", [])) for _, i in files)))
    if args.check:
        return

    landed, fields = land(files)
    os.makedirs(MERGED, exist_ok=True)
    for path, _ in files:
        os.replace(path, os.path.join(MERGED, os.path.basename(path)))
    print("landed %d addresses and %d struct fields" % (landed, fields))
    print("now: python buildFindings.py, then apply, and check failed: 0")


if __name__ == "__main__":
    main()
