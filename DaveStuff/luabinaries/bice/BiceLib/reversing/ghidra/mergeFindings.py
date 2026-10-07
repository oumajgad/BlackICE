"""Folds what an agent found into project.json, or says why it will not.

    python ghidra/mergeFindings.py --check      what would land, changing nothing
    python ghidra/mergeFindings.py              land it, and move the files to merged/

**Only this script writes project.json.** Agents write one file each into
`reversing/fragments/incoming/`, which is what keeps several of them off a file with
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
     "structs": [
      {"name": "CRelation", "size": "0x24", "inherits": "CPersistent",
       "vftable_rva": "0x11FBB00", "comment": "...", "evidence": "..."}
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

## `structs` - declaring one, which a fragment could not do before 2026-10-06

A `struct_fields` entry is refused for a struct `project.json` does not already hold, and
until this key existed a fragment had no way to create one - so a whole class's layout
could only be contributed by a hand edit, and the queue accumulated twelve diplomatic
classes and seven trigger classes waiting for one. `structs` declares the container; the
fields still go in `struct_fields`, and a declaration here is what makes them land.

A declaration carries `name` and `evidence`, and may carry:

- **`size`**, a hex string. Authoritative in Ghidra in both directions - see
  `ghidra/README.md` - so a guess here is worse than none.
- **`inherits`**, a base whose fields are laid out on this class too. **Offset 0 only**:
  `buildFindings.py` copies the base's fields in at face value, so a base at +8 would put
  every one of them eight bytes early. Checked against the RTTI export.
- **`vftable_rva`**, the class's own table. Checked against RTTI as well, which is how
  `CBuildingConstruction`'s and `CConvoyConstruction`'s were found to point ten and twelve
  slots *into* their tables rather than at the start of them.

It is deliberately **create-only**. A struct `project.json` already holds, declared again
with nothing different, is skipped the way a repeated address entry is; declared with
something different it is refused, because `size` can sit either side of the `fields`
array in the file and rewriting a header around it is a hand edit, not a merge.

## Naming one of a class's two virtual tables

`vftable_slots` is keyed by class, and a class with two tables has two slot 2s. Write
`"CVariables@0x24"` - the class, `@`, and the object offset the table sits at - to mean
one of them; a bare class name still means the table at offset 0, which is what every
record written before this meant.

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
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))

import hoi3
import image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.join(HERE, "project.json")
ROOT = os.path.dirname(os.path.dirname(HERE))
INCOMING = os.path.join(HERE, "..", "fragments", "incoming")
MERGED = os.path.join(HERE, "..", "fragments", "merged")

# `no_signature` is here because it was not: the merge demanded a reason and then
# dropped it, so project.json held functions with neither a signature nor any
# record of why. The reason is the finding, as much as the signature would be.
ADDRESS_KEYS = ("rva", "kind", "name", "signature", "no_signature", "comment",
                "confidence", "source")
# Optional, and **kept through a revision**. Everything the merge writes is rebuilt from
# ADDRESS_KEYS alone, so a key missing from both lists is dropped without a word - which is
# how `no_signature` was lost, and a revision of a function would otherwise quietly take its
# locals with it.
OPTIONAL_ADDRESS_KEYS = ("locals",)
STACK_AT = re.compile(r"^stack:-?0[xX][0-9a-fA-F]+$")
FIELD_KEYS = ("offset", "name", "type", "comment", "source")
# A struct declaration, in the order project.json already writes them, so an inserted
# block reads like the ones around it. `name` is the only one required; `fields` is not
# here because a declaration never carries fields - those go in `struct_fields`, which is
# where the duplicate and cross-fragment checks live.
STRUCT_KEYS = ("name", "vftable_rva", "size", "inherits", "comment", "source")
# "CVariables@0x24": the class, and the object offset of the table meant. A bare class
# name means the table at offset 0.
QUALIFIED_SLOTS = re.compile(r"^([A-Za-z_][\w:<>]*)@(0[xX][0-9a-fA-F]+|\d+)$")
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


def tableOffsets(klass):
    """the object offsets RTTI gives this class a virtual table at"""
    record = hoi3.classes().get(klass)
    if not record:
        return None
    return {v.get("object_offset", 0): int(v["address"], 16)
            for v in record.get("vftables", [])}


def baseOffset(name, target, seen=None, at=0):
    """where `target` sits inside `name`, or None when it is not a base of it

    The same walk buildFindings.base_offset does, repeated here because the merge has to
    refuse an `inherits` the build would only warn about - and because `inherits` is laid
    out at face value, so a base at any offset but 0 is a wrong answer and not a near one.
    """
    if name == target:
        return at
    seen = seen if seen is not None else set()
    record = hoi3.classes().get(name)
    if name in seen or not record:
        return None
    seen.add(name)
    for base in record.get("bases") or []:
        found = baseOffset(base["name"], target, seen, at + base.get("offset", 0))
        if found is not None:
            return found
    return None


def declaredStructs(files, said):
    """every struct the incoming files declare, checked - {name: declaration}

    A declaration is what lets `struct_fields` land for a class project.json has never
    held. It is create-only; see the module docstring for why a revision of one is a hand
    edit.
    """
    document = load()
    have = {s["name"]: s for s in document.get("structs", [])}
    out = {}
    for path, incoming in files:
        who = os.path.basename(path)
        for declaration in incoming.get("structs", []):
            name = declaration.get("name")
            where = "%s / struct %s" % (who, name or "?")
            if not name or not isinstance(name, str):
                said.append("%s: a struct declaration needs a name" % where)
                continue
            if "fields" in declaration:
                said.append("%s: a declaration carries no fields - put them in "
                            "struct_fields, which is where the duplicate and "
                            "cross-fragment checks are" % where)
            if not declaration.get("evidence"):
                said.append("%s: no evidence" % where)
            for key in declaration:
                if key not in STRUCT_KEYS and key not in ("evidence", "fields"):
                    said.append("%s: %r is not one of %s"
                                % (where, key, ", ".join(STRUCT_KEYS)))
            for key in ("size", "vftable_rva"):
                if declaration.get(key) is None:
                    continue
                try:
                    value = int(declaration[key], 16)
                except (TypeError, ValueError):
                    said.append("%s: %s must be a hex string, e.g. \"0x24\"" % (where, key))
                    continue
                if value <= 0:
                    said.append("%s: %s is not a size" % (where, key))
            tables = tableOffsets(name)
            if declaration.get("vftable_rva"):
                try:
                    rva = int(declaration["vftable_rva"], 16)
                except (TypeError, ValueError):
                    rva = None
                if rva is not None and not image.mapped(image.toVa(rva)):
                    said.append("%s: vftable_rva 0x%X is not in the image read as an rva "
                                "- these are rvas against 0x400000 (trap 1)" % (where, rva))
                elif rva is not None and tables and rva + 0x400000 not in set(tables.values()):
                    said.append("%s: RTTI puts %s's table%s at %s, not at 0x%X - a value "
                                "inside the table rather than at the start of it is how "
                                "two of these went wrong before"
                                % (where, name, "" if len(tables) == 1 else "s",
                                   ", ".join("0x%X" % (a - 0x400000)
                                             for a in sorted(tables.values())), rva))
            base = declaration.get("inherits")
            if base:
                at = baseOffset(name, base)
                if at is None and name in hoi3.classes() and base in hoi3.classes():
                    said.append("%s: RTTI says %s is not a base of %s"
                                % (where, base, name))
                elif at:
                    said.append("%s: %s sits at +%d inside %s, and `inherits` lays a "
                                "base out at face value - offset 0 only"
                                % (where, base, at, name))
            if name in out and out[name] != declaration:
                said.append("%s: another file declares %s differently" % (where, name))
            if name in have:
                mine = {k: have[name].get(k) for k in STRUCT_KEYS if k != "source"}
                theirs = {k: declaration.get(k) for k in STRUCT_KEYS if k != "source"}
                if mine == theirs:
                    continue                    # already there, identically: skip it
                said.append("%s: project.json already holds that struct, saying %s - "
                            "declaring one is create-only, and changing a header key is "
                            "a hand edit (`size` can sit either side of the fields array)"
                            % (where, json.dumps({k: v for k, v in mine.items()
                                                  if v is not None})))
                continue
            out[name] = declaration
    return out


def problems(document, files):
    """every reason not to land this, as a list of sentences"""
    said = []
    byName = {e["name"]: int(e["rva"], 16) for e in document["addresses"]}
    byRva = {int(e["rva"], 16): e["name"] for e in document["addresses"]}
    structs = {s["name"]: {f["offset"].lower(): f for f in s.get("fields", [])}
               for s in document.get("structs", [])}
    claimedName = {}
    claimedRva = {}
    # **And the same for fields, which was the hole.** The two above compare *address*
    # entries between incoming fragments; `struct_fields` were only ever compared against
    # project.json, so two agents naming one offset differently were neither refused nor
    # reported and both records landed for the one field. `buildFindings.py` then keeps
    # whichever comes first and demotes the other into its comment, which is worse than a
    # drop: the file holds two answers and nothing says so. project.json carries four such
    # pairs from before this existed - `scripts/reconcileFacts.py` lists them, and
    # `scripts/crossFragments.py` is the same check as a report, which also prints the
    # agreements. The type is compared as well as the name, for the reason the field check
    # below gives: a field that keeps its name and changes its type said nothing.
    claimedField = {}
    # Structs this wave creates. Collected before the loop, so a field may name a struct
    # another fragment in the same wave declares - which is how brief B's trigger fields
    # land on brief A's trigger structs.
    declared = declaredStructs(files, said)
    for name in declared:
        structs.setdefault(name, {})

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
            for local in entry.get("locals") or []:
                if not STACK_AT.match(local.get("at") or ""):
                    said.append("%s: local %r needs `at` as stack:<offset>, e.g. stack:-0x30 - "
                                "Ghidra's own offset, the number in the local_30 it prints, "
                                "which is four below the [ebp-0x2c] in the disassembly"
                                % (where, local.get("name")))
                if not local.get("name") or not local.get("type"):
                    said.append("%s: local at %s needs both a name and a type"
                                % (where, local.get("at")))
                if not local.get("comment"):
                    said.append("%s: local %r needs a comment saying what it is"
                                % (where, local.get("name")))

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
            # `mapped`, not `read`: a global in the zero-filled tail of .data has no bytes
            # in the file, so asking whether it is readable refuses every one of them -
            # including g_CCurrentGameState, which is the address this project is surest
            # of. It refused 20 entries project.json already holds.
            if not image.mapped(image.toVa(rva)) and image.mapped(rva):
                said.append("%s: 0x%X is only inside the image read as a virtual "
                            "address - subtract the image base" % (where, rva))

            # the virtual tables stay current
            tables = inTables().get(image.toVa(rva), [])
            if tables and len(tables) <= FOLDED:
                owners = sorted({owner for owner, _ in tables})
                if "::" not in name and not incoming.get("slots_noted"):
                    said.append("%s: that address is slot %d of %s, so the name wants "
                                "the class on it" % (where, tables[0][1],
                                                     ", ".join(owners)))
                # A key may name one of a class's tables - "CVariables@0x24" - and that
                # still covers the class.
                covered = {k.split("@")[0] for k in incoming.get("vftable_slots", {})}
                wanted = set(owners) - covered
                if wanted and not incoming.get("slots_noted"):
                    said.append("%s: it is in %d virtual table%s (%s) - record the slot "
                                "under vftable_slots, or say why not in slots_noted"
                                % (where, len(tables), "" if len(tables) == 1 else "s",
                                   ", ".join("%s slot %d" % (o, sl)
                                             for o, sl in sorted(tables))))
            elif len(tables) > FOLDED and not related({o for o, _ in tables}) \
                    and "::" in name:
                # A class-free name here is the right answer, not a problem: the point of
                # refusing was to stop one of the 38 classes being singled out.
                said.append("%s: that body is in %d virtual tables, so the linker folded "
                            "it - it cannot be named for any one class" % (where, len(tables)))

            # `revises` is how an entry says it means to change something already
            # recorded. Without it a name or address already spoken for is a collision;
            # with it, it is the point. Silently skipping - which this did - loses the
            # correction and says nothing, and both agents who hit it noticed only
            # because they went looking.
            have = existing(document, entry)
            if entry.get("revises"):
                if have is None:
                    said.append("%s: revises nothing - no entry has that name or address"
                                % where)
                elif not differs(have, entry):
                    said.append("%s: revises an entry it does not change" % where)
            else:
                if name in byName and byName[name] != rva:
                    said.append("%s: project.json already gives that name to 0x%X - say "
                                "revises to move it" % (where, byName[name]))
                if rva in byRva and byRva[rva] != name:
                    said.append("%s: project.json already calls 0x%X %s - say revises to "
                                "rename it" % (where, rva, byRva[rva]))
                if have is not None and differs(have, entry):
                    said.append("%s: project.json already records that, differently - say "
                                "revises, with why" % where)
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
            spot = (field.get("struct"), str(field.get("offset", "")).lower())
            answer = (field.get("name"), field.get("type"))
            if spot in claimedField and claimedField[spot][0] != answer:
                said.append("%s: %s calls %s +%s %s %s instead"
                            % (where, claimedField[spot][1], spot[0], spot[1],
                               claimedField[spot][0][1], claimedField[spot][0][0]))
            claimedField[spot] = (answer, who)
            if field.get("struct") in declared and field.get("revises"):
                said.append("%s: revises nothing - this wave is creating that struct"
                            % where)

            known = structs.get(field.get("struct"))
            if known is None:
                said.append("%s: no such struct in project.json, and no `structs` entry "
                            "in this wave declares it - see the `structs` key in "
                            "ghidra/mergeFindings.py's docstring" % where)
                continue
            have = known.get(str(field.get("offset", "")).lower())
            if have is not None:
                # Names alone were compared here. A field that keeps its name and
                # changes its type - `plan`, from void* to CUnitPlan - said nothing and
                # landed as a *second* record for the same offset, which is worse than
                # being dropped: the file then holds two answers and neither run
                # complains, because the apply reads whichever comes first.
                changed = any((have.get(key) or "") != (field.get(key) or "")
                              for key in ("name", "type", "comment"))
                if changed and not field.get("revises"):
                    said.append("%s: that offset already holds %s %s, saying something "
                                "else - say revises, with why"
                                % (where, have.get("type"), have.get("name")))
                elif not changed and field.get("revises"):
                    said.append("%s: revises a field it does not change" % where)
            elif field.get("revises"):
                said.append("%s: revises nothing - no field is recorded there" % where)

    # A `Class@0xNN` key has to name a table that exists, or the record lands nowhere and
    # nothing says so.
    for path, incoming in files:
        who = os.path.basename(path)
        for key in incoming.get("vftable_slots", {}):
            if "@" not in key:
                continue
            match = QUALIFIED_SLOTS.match(key)
            if not match:
                said.append("%s: vftable_slots key %r does not parse - it is the class, "
                            "`@`, and the object offset of the table, e.g. "
                            "CVariables@0x24" % (who, key))
                continue
            klass, at = match.group(1), int(match.group(2), 0)
            tables = tableOffsets(klass)
            if tables is None:
                said.append("%s: vftable_slots names %s, which RTTI does not have"
                            % (who, klass))
            elif at not in tables:
                said.append("%s: RTTI gives %s a table at %s, not at +0x%X"
                            % (who, klass,
                               ", ".join("+0x%X" % o for o in sorted(tables)) or "none",
                               at))
    return said


def existing(document, entry):
    """the entry in project.json this one would change

    By `replaces` where it says so, then by name, then by address. The first is for a
    correction that changes the name as well as the address - a folded body whose class
    name never belonged to it - where nothing else connects the two records.
    """
    named = entry.get("replaces")
    if named:
        for have in document["addresses"]:
            if have["name"] == named:
                return have
        return None
    for have in document["addresses"]:
        if have["name"] == entry["name"]:
            return have
    for have in document["addresses"]:
        if int(have["rva"], 16) == int(entry["rva"], 16):
            return have
    return None


def differs(have, entry):
    """whether an incoming entry says anything new about one already recorded"""
    for key in ("rva", "kind", "name", "signature", "comment", "confidence"):
        mine, theirs = have.get(key), entry.get(key)
        if key == "rva" and mine and theirs:
            if int(mine, 16) != int(theirs, 16):
                return True
            continue
        if (mine or "") != (theirs or ""):
            return True
    return False


def ancestors(name, seen=None):
    """a class and everything it derives from, transitively"""
    seen = seen if seen is not None else set()
    if name in seen:
        return seen
    seen.add(name)
    for base in (hoi3.classes().get(name) or {}).get("bases") or []:
        ancestors(base["name"], seen)
    return seen


def related(names):
    """whether every one of these classes shares an ancestor with the others

    A body in many tables is usually one the linker folded - `xor eax,eax; ret` is in 189
    of them - but a virtual a base declares is in its own table and every heir's, and
    that is inheritance rather than folding. CRelation's LoadKey is in nine: itself and
    its eight subclasses.
    """
    common = None
    for name in names:
        chain = ancestors(name)
        common = chain if common is None else (common & chain)
        if not common:
            return False
    return True


def indent(entry, spaces):
    text = json.dumps(entry, indent=1, ensure_ascii=True)
    return "\n".join(" " * spaces + line for line in text.split("\n"))


def replaceField(raw, struct, offset, text):
    """swap the field at `offset` of `struct` for `text`

    A field's keys sit five spaces in and an address entry's three, and the search
    is bounded to this struct's own block, because the same offset is recorded on
    dozens of other classes.
    """
    anchor = '  {\n   "name": "%s",\n' % struct
    assert raw.count(anchor) == 1, "could not find struct %s" % struct
    start = raw.index(anchor)
    end = raw.index("\n  },", start)
    marker = '     "offset": "%s",\n' % offset
    block = raw[start:end]
    assert block.count(marker) == 1, \
        "expected one field at %s of %s" % (offset, struct)
    at = start + block.index(marker)
    first = raw.rindex("\n    {\n", start, at) + 1
    last = raw.index("\n    }", at) + len("\n    }")
    return raw[:first] + text.lstrip("\n") + raw[last:]


def replaceEntry(raw, name, text):
    """swap the whole block of the address entry called `name` for `text`

    Keys sit three spaces in and a struct field's `name` sits five, so the marker below
    only ever matches an address entry.
    """
    marker = '   "name": "%s",\n' % name
    assert raw.count(marker) == 1, "expected exactly one entry named %s" % name
    at = raw.index(marker)
    start = raw.rindex("\n  {\n", 0, at) + 1
    end = raw.index("\n  }", at) + len("\n  }")
    return raw[:start] + text.lstrip("\n") + raw[end:]


def land(files):
    raw = io.open(PROJECT, encoding="utf-8").read()
    document = load()
    addresses = []
    revisions = []
    fields = []
    # Only the ones problems() accepted as new: a declaration of a struct project.json
    # already holds is dropped there, identical or not.
    existingStructs = {s["name"] for s in document.get("structs", [])}
    accepted = declaredStructs(files, [])
    newStructs, seen = [], set()
    for path, incoming in files:
        for declaration in incoming.get("structs", []):
            name = declaration.get("name")
            if name in existingStructs or name in seen or accepted.get(name) is not declaration:
                continue
            seen.add(name)
            clean = {k: declaration[k] for k in STRUCT_KEYS
                     if declaration.get(k) is not None}
            clean["source"] = declaration.get("source") or incoming["source"]
            clean["fields"] = []
            newStructs.append({k: clean[k] for k in STRUCT_KEYS + ("fields",)
                               if k in clean})

    for path, incoming in files:
        for entry in incoming.get("addresses", []):
            clean = {k: entry.get(k) for k in ADDRESS_KEYS}
            clean["source"] = entry.get("source") or incoming["source"]
            have = existing(document, entry)
            for key in OPTIONAL_ADDRESS_KEYS:
                # Carried only when there is something to carry, so the file does not gain a
                # null for every address that has none - but carried through a revision, which
                # rebuilds the record from scratch and would otherwise drop it.
                carried = entry.get(key) or (have or {}).get(key)
                if carried:
                    clean[key] = carried
            if have is None:
                addresses.append(clean)
            elif entry.get("revises"):
                revisions.append((have["name"], clean))
            # anything else was refused by problems() before we got here
        for field in incoming.get("struct_fields", []):
            clean = {k: field.get(k) for k in FIELD_KEYS}
            clean["source"] = field.get("source") or incoming["source"]
            fields.append((field["struct"], clean, bool(field.get("revises"))))

    slots = {}
    for path, incoming in files:
        for klass, entries in incoming.get("vftable_slots", {}).items():
            slots.setdefault(klass, {}).update({str(k): v for k, v in entries.items()})

    for klass, entries in slots.items():
        anchor = '  "%s": {\n' % klass
        if raw.count(anchor) > 1:
            raise SystemExit("vftable_slots names %s more than once - fix that by hand"
                             % klass)
        # A slot is either a bare name or the richer {name, signature} that CPersistent
        # and CTrigger already use and that the apply script types the slot from. `"%s"`
        # on the second wrote a Python repr into the file as a string, which the apply
        # then used verbatim as the field name - and since Ghidra turns the spaces in it
        # into underscores, the name never compared equal to itself and the run re-placed
        # it forever. json.dumps spells both correctly.
        added = "".join('   "%s": %s,\n' % (slot, json.dumps(value, ensure_ascii=True))
                        for slot, value in sorted(entries.items(),
                                                  key=lambda kv: int(kv[0])))
        if raw.count(anchor) == 1:
            raw = raw.replace(anchor, anchor + added, 1)
        else:
            # First slot recorded for this class. Aborting the whole wave over a missing
            # block, which is what this did, punishes exactly the agent that did the
            # extra work of checking its function against the tables.
            opening = ' "vftable_slots": {\n'
            if raw.count(opening) != 1:
                raise SystemExit("could not find the vftable_slots block")
            # `added` ends in a comma, which is right when the block it joins already
            # has entries under it and invalid JSON when it is the whole of a new one.
            # That broke project.json on the first wave that recorded a slot for a class
            # with no block, which is the case this branch exists to handle.
            raw = raw.replace(opening,
                              opening + anchor + added.rstrip(",\n") + "\n  },\n", 1)

    for name, entry in revisions:
        raw = replaceEntry(raw, name, indent(entry, 2))

    if addresses:
        close = "\n ],\n \"structs\": ["
        assert raw.count(close) == 1, "could not find the end of the addresses array"
        raw = raw.replace(
            close, ",\n" + ",\n".join(indent(e, 2) for e in addresses) + close, 1)

    # Before the fields, which anchor on the struct's own block.
    if newStructs:
        close = "\n ],\n \"equates\": ["
        assert raw.count(close) == 1, "could not find the end of the structs array"
        blocks = []
        for s in newStructs:
            text = indent(s, 2)
            # json.dumps writes an empty array `[]`, and the field insertion below looks
            # for `"fields": [\n` - so a struct landed with no fields yet would send that
            # search into the *next* struct's array. Spell it open.
            assert text.count('"fields": []') == 1, "unexpected rendering of %s" % s["name"]
            blocks.append(text.replace('"fields": []', '"fields": [\n   ]'))
        raw = raw.replace(close, ",\n" + ",\n".join(blocks) + close, 1)

    for struct, field, revises in fields:
        if revises:
            raw = replaceField(raw, struct, field["offset"], indent(field, 4))
            continue
        anchor = '  {\n   "name": "%s",\n' % struct
        assert raw.count(anchor) == 1, "could not find struct %s" % struct
        opening = anchor + '   "fields": [\n'
        if raw.count(opening) != 1:                 # a size or a vftable sits between
            at = raw.index(anchor)
            opening = raw[at:raw.index('"fields": [\n', at) + len('"fields": [\n')]
        # The comma belongs after the new field only when something follows it. A struct
        # this wave created has an empty array, and `{...},\n   ]` is invalid JSON - which
        # is the same trailing-comma break the vftable_slots branch above exists for.
        at = raw.index(opening) + len(opening)
        separator = "" if raw[at:].lstrip().startswith("]") else ","
        raw = raw[:at] + indent(field, 4) + separator + "\n" + raw[at:]

    io.open(PROJECT, "w", encoding="utf-8", newline="\n").write(raw)
    after = json.loads(io.open(PROJECT, encoding="utf-8").read())   # it still parses
    # Trap 18's JSON corollary: after a structural edit, assert that what changed changed
    # and that the counts of everything else did not.
    assert len(after["structs"]) == len(document["structs"]) + len(newStructs), \
        "the structs array did not grow by the %d declared" % len(newStructs)
    assert len(after["addresses"]) == len(document["addresses"]) + len(addresses), \
        "the addresses array did not grow by the %d landed" % len(addresses)
    return len(addresses), len(fields), len(newStructs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="say what would land")
    args = parser.parse_args()

    paths = sorted(glob.glob(os.path.join(INCOMING, "*.json")))
    files = [(p, json.load(io.open(p, encoding="utf-8"))) for p in paths]
    if not files:
        print("nothing in fragments/incoming")
        return

    document = load()
    said = problems(document, files)
    if said:
        print("refused, %d problem%s:" % (len(said), "" if len(said) == 1 else "s"))
        for line in said:
            print("   " + line)
        raise SystemExit(1)

    counts = sum(len(i.get("addresses", [])) for _, i in files)
    print("%d file%s, %d addresses, %d structs declared, %d struct fields - no conflicts"
          % (len(files), "" if len(files) == 1 else "s", counts,
             sum(len(i.get("structs", [])) for _, i in files),
             sum(len(i.get("struct_fields", [])) for _, i in files)))
    if args.check:
        return

    landed, fields, structs = land(files)
    os.makedirs(MERGED, exist_ok=True)
    for path, _ in files:
        os.replace(path, os.path.join(MERGED, os.path.basename(path)))
    print("landed %d addresses, %d new structs and %d struct fields"
          % (landed, structs, fields))
    print("now: python ghidra/buildFindings.py, then apply, and check failed: 0")


if __name__ == "__main__":
    main()
