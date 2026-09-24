"""Builds bicelib_findings.json, which ApplyBiceLibFindings.java applies to a Ghidra program.

    python buildFindings.py                        # luabind.json + project.json -> bicelib_findings.json
    python buildFindings.py --import harvest.json  # check a harvest and write it as project.json first

Two sources:

- **luabind.json**, from luabindExtract.py: every C++ function behind the Lua API, with the
  type it was registered with, and the class fields and sizes that fall out of it.
- **project.json**: everything else the project has worked out - functions, hook sites,
  globals, vftables and class layouts from GameClasses, Hooks and the FINDINGS files.
  Add new findings there by hand; `rva` is module relative, as everywhere in BiceLib.

**Every address is checked against the executable before it goes out.** A function has
to start where a function can start, an instruction has to be on an instruction
boundary, a vftable has to carry a real RTTI locator. The project's notes do not always
say an address the same way - some are written as the disassembler's VA - so on import
both readings are tried and the one that checks out is kept, and anything that fits
neither is left out and reported.
"""

import argparse
import collections
import json
import os
import re
import struct
import sys

import luabindExtract as LX

HERE = os.path.dirname(os.path.abspath(__file__))
LUABIND = os.path.join(HERE, "luabind.json")
PROJECT = os.path.join(HERE, "project.json")
OUT = os.path.join(HERE, "bicelib_findings.json")
SAVE_TOKENS = os.path.join(HERE, "saveTokens.json")
MODIFIER_IDS = os.path.join(HERE, "modifierIds.json")

IMAGE_BASE = LX.IMAGE_BASE

# Classes passed by value whose size is established, so a signature that takes one can
# be laid out on the stack. Anything else passed by value leaves its parameters unset.
KNOWN_SIZES = {
    "CCountryTag": (8, "three characters, a NUL and the country id; CWarGoal keeps three of them 8 bytes apart, and ends 4 bytes after the last at its luabind size of 0x2C"),
    "CFixedPoint": (4, "returned by value through a hidden pointer that receives exactly one dword, e.g. CTheatre::GetPriority"),
    "fpml::fixed_point<__int64,48,15>": (8, "a 64 bit fixed point number"),
    "CGoodsPool": (0x24, "GameClasses/CGoodsPool.hpp; CCountry's goods pools sit 0x24 apart"),
}
BUILTIN = LX.BUILTINS | {"void"}


# --- checking addresses against the executable -------------------------------------------------

class Checker:
    def __init__(self):
        self.image = image = LX.Image(LX.EXE)
        text = image.read(image.text[0], image.text[1] - image.text[0])
        self.calls = set()
        for m in re.finditer(b"\xE8", text):
            o = m.start()
            if o + 5 <= len(text):
                self.calls.add((image.text[0] + o + 5 + struct.unpack_from("<i", text, o + 1)[0]) & 0xFFFFFFFF)
        rdata = image.read(image.rdata[0], (image.rdata[1] - image.rdata[0]) & ~3)
        self.code_pointers = {v for (v,) in struct.iter_unpack("<I", rdata) if image.text[0] <= v < image.text[1]}
        self.data = [(s[0], s[0] + s[1]) for s in image.sections if s[3] == ".data"][0]

    def starts_function(self, va):
        """Called, pointed at from data, or straight after a ret and its int3 padding."""
        im = self.image
        if not im.is_code(va):
            return False
        if va in self.calls or va in self.code_pointers:
            return True
        before = im.read(va - 16, 16)
        k = len(before)
        while k > 0 and before[k - 1] == 0xCC:
            k -= 1
        return (k >= 1 and before[k - 1] == 0xC3) or (k >= 3 and before[k - 3] == 0xC2) \
            or len(before) - k >= 3             # a run of int3 is alignment between functions

    def instruction_fit(self, va):
        """2 on an instruction boundary, 1 inside an instruction, 0 not in code.

        Decoded forward from the nearest proven function start, so the stream is aligned.
        Inside counts for less: nearly any code address is inside some instruction, and it
        is only the right answer for a patched operand, which is recorded by its own byte.
        """
        im = self.image
        if not im.is_code(va):
            return 0
        best = 0
        starts = [s for s in range(va, max(im.text[0], va - 0x6000), -1) if s in self.calls or s in self.code_pointers]
        for start in starts[:3]:
            for address, size, _, _ in im.cs.disasm_lite(im.read(start, va - start + 16), start):
                if address == va:
                    return 2
                if address < va < address + size:
                    best = 1
                if address > va:
                    break
        return best

    def on_instruction(self, va):
        return self.instruction_fit(va) > 0

    def is_vftable(self, va):
        im = self.image
        if not (im.rdata[0] <= va < im.rdata[1]):
            return False
        locator = im.u32(va - 4)
        if not (im.rdata[0] <= locator < im.rdata[1]) or im.u32(locator) != 0:
            return False
        name = im.cstr(im.u32(locator + 0xC) + 8) if im.rdata[0] <= im.u32(locator + 0xC) < self.data[1] else None
        return bool(name and name.startswith(".?A")) and im.is_code(im.u32(va))

    def check(self, kind, va):
        im = self.image
        if kind == "function":
            return self.starts_function(va)
        if kind == "instruction":
            return self.on_instruction(va)
        if kind == "vftable":
            return self.is_vftable(va)
        if kind == "global":
            return self.data[0] <= va < self.data[1]
        if kind == "string":
            s = im.cstr(va)
            return bool(s and len(s) >= 3)
        if kind == "jumptable":
            return im.is_code(im.u32(va)) and im.is_code(im.u32(va + 4))
        return False

    def vftable_class(self, va):
        im = self.image
        return LX.demangle_type(im.cstr(im.u32(im.u32(va - 4) + 0xC) + 8))


# --- import: a harvest becomes project.json --------------------------------------------------------

PATCHED_OPERAND = re.compile(r"Immediate|Byte|Operand|Patch", re.I)


def readings_of(a, checker, anchors):
    """
    Both readings of a harvested address, each scored on what the executable says:
    [(score, convention, rva, kind, why)], best first, only those that fit at all.

    Scored rather than decided by one rule, because each rule alone gets some wrong:
    a VA-reading can happen to start another function, and nearly any code address is
    inside some instruction.
    """
    written = int(a["rva_as_written"], 16)
    disassembler_style = bool(re.match(r"^0x00[0-9a-fA-F]{6}$", a["rva_as_written"]))
    out = []
    for convention, va in (("rva", written + IMAGE_BASE), ("va", written)):
        if not (0x401000 <= va < 0x2000000):
            continue
        kind, score, why = a["kind"], 0, []
        if kind == "function":
            if va in checker.calls or va in checker.code_pointers:
                score, why = 3, ["called or pointed at"]
            elif checker.starts_function(va):
                score, why = 2, ["starts after padding"]
            elif checker.instruction_fit(va) == 2:
                kind, score, why = "instruction", 2, ["inside a function"]
        elif kind == "instruction":
            fit = checker.instruction_fit(va)
            if fit == 2:
                score, why = 2, ["on an instruction"]
            elif fit == 1 and PATCHED_OPERAND.search(a["name"]):
                score, why = 2, ["a patched operand"]
            elif fit == 1:
                score, why = 1, ["inside an instruction"]
        elif checker.check(kind, va):
            score, why = 3, ["a %s" % kind]
        if score == 0:
            continue
        if a["convention"] == convention:
            score += 1
            why.append("as the notes say")
        if disassembler_style and convention == "va":
            score += 1
            why.append("written the disassembler's way")
        if any(0 <= va - f < 0x1000 for f in anchors) and va not in anchors:
            score += 1
            why.append("near a function the notes name")
        out.append((score, convention, va - IMAGE_BASE, kind, ", ".join(why)))
    # On a tie the notes' own word decides; the executable could not.
    return sorted(out, key=lambda r: (r[0], r[1] == a["convention"]), reverse=True)


def import_harvest(path, checker):
    harvest = json.load(open(path, encoding="utf-8"))
    kept, report = {}, []

    # Function entries that fit exactly one way and are called: fixed points to judge
    # the rest by.
    anchors = set()
    for a in harvest["addresses"]:
        if a["kind"] == "function":
            written = int(a["rva_as_written"], 16)
            fits = [va for va in (written + IMAGE_BASE, written) if va in checker.calls]
            if len(fits) == 1:
                anchors.add(fits[0])

    for a in harvest["addresses"]:
        found = readings_of(a, checker, anchors)
        if not found:
            report.append("left out, fits neither reading: %s %s %s (%s)" % (a["kind"], a["rva_as_written"], a["name"], a["source"]))
            continue
        best = found[0]
        if len(found) > 1:
            if found[1][0] == best[0]:
                report.append("could not tell the readings apart, took the %s (%s): %s %s (%s)" % (
                    best[1].upper(), best[4], a["rva_as_written"], a["name"], a["source"]))
            elif best[1] != a["convention"]:
                report.append("took the %s (%s): %s %s (%s)" % (best[1].upper(), best[4], a["rva_as_written"], a["name"], a["source"]))
        elif a["convention"] != "unclear" and best[1] != a["convention"]:
            report.append("written as %s but only the %s fits (%s): %s %s (%s)" % (
                a["convention"].upper(), best[1].upper(), best[4], a["rva_as_written"], a["name"], a["source"]))
        if best[3] != a["kind"]:
            report.append("not a function entry, kept as a label inside one: %s %s (%s)" % (a["rva_as_written"], a["name"], a["source"]))
        rva, kind = best[2], best[3]
        key = (rva, kind)
        entry = {"rva": "0x%X" % rva, "kind": kind, "name": a["name"], "signature": a.get("signature"),
                 "comment": a.get("comment", ""), "confidence": a.get("confidence", "inferred"), "source": a["source"]}
        if key in kept:
            other = kept[key]
            if other["name"] != entry["name"]:
                other.setdefault("aliases", []).append(entry["name"])
            if entry["comment"] and entry["comment"] not in other["comment"]:
                other["comment"] += " " + entry["comment"]
            other["source"] += "; " + entry["source"]
        else:
            kept[key] = entry
    structs = []
    for s in harvest["structs"]:
        fields, seen = [], {}
        for f in s["fields"]:
            off = int(f["offset"], 16)
            if off in seen:
                # The header is the maintained description of a class, the notes are how it was found.
                if seen[off]["source"].split(":")[0].endswith(".hpp") and not f["source"].split(":")[0].endswith(".hpp"):
                    continue
                fields.remove(seen[off])
            entry = {"offset": "0x%X" % off, "name": f["name"], "type": f["type"], "comment": f.get("comment", ""), "source": f["source"]}
            fields.append(entry)
            seen[off] = entry
        record = {"name": s["name"], "fields": fields}
        if s.get("vftable_rva"):
            record["vftable_rva"] = s["vftable_rva"]
        structs.append(record)
    out = {"about": "Findings about hoi3_tfh.exe from BiceLib's headers, hooks and reversing notes. "
                    "rva is module relative. Checked against the executable by buildFindings.py.",
           "addresses": sorted(kept.values(), key=lambda e: int(e["rva"], 16)), "structs": structs}
    json.dump(out, open(PROJECT, "w", encoding="utf-8"), indent=1)
    print("wrote %s: %d addresses, %d structs" % (PROJECT, len(kept), len(structs)))
    for line in report:
        print("  " + line)


# --- building the output -----------------------------------------------------------------------

CONFIDENCE = {"confirmed": "CERTAIN", "inferred": "TENTATIVE"}


def split_name(qualified):
    """'CGregorianDate::GetYear' -> ('CGregorianDate', 'GetYear'), splitting outside templates"""
    depth, cut = 0, -1
    for i, ch in enumerate(qualified):
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth -= 1
        elif depth == 0 and qualified.startswith("::", i):
            cut = i
    return (qualified[:cut], qualified[cut + 2:]) if cut >= 0 else ("", qualified)


def type_category(text, enums):
    t = LX.parse_type(text.replace(" &", "&").replace(" *", "*"), enums)
    return t


def class_size(name, sizes):
    base = name.strip()
    return sizes.get(base)


def build_signature(ftype, enums, sizes):
    """The signature the script applies, or None; and the reason parts were left out."""
    ret = type_category(ftype["return"], enums)
    hidden = ret["category"] == "class"
    params, untyped = [], []
    for i, p in enumerate(ftype["params"]):
        t = type_category(p, enums)
        if t["category"] == "class" and class_size(t["base"], sizes) is None:
            untyped.append(p)
        params.append({"name": None, "type": p})
    sig = {"convention": ftype["convention"], "return": ftype["return"], "hiddenReturn": hidden,
           "params": None if untyped else params}
    note = ("parameters not set: the size of %s passed by value is not known" % ", ".join(sorted(set(untyped)))) if untyped else ""
    return sig, note


# A body of one or two instructions is a folding magnet: `xor al,al; ret` and
# `mov eax,[ecx+0x24]; ret` are written once each in the whole executable however many
# classes declare such a method, so the one address ends up in hundreds of virtual tables.
# A Lua registration still names one of them, and that name would be a lie everywhere else,
# so these are named for what the body does. Every method registered there stays as a label.
TRIVIAL_BODIES = [
    (re.compile(r"^mov al, 1$"), "ReturnTrue"),
    (re.compile(r"^xor al, al$"), "ReturnFalse"),
    (re.compile(r"^mov eax, (0x[0-9a-f]+|\d+)$"), "Return_%s"),
    (re.compile(r"^xor eax, eax$"), "Return_0"),
    (re.compile(r"^mov eax, ecx$"), "ReturnThis"),
    (re.compile(r"^mov eax, dword ptr \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "GetDword_%s"),
    (re.compile(r"^mov eax, dword ptr \[ecx\]$"), "GetDword_0"),
    (re.compile(r"^mov al, byte ptr \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "GetByte_%s"),
    (re.compile(r"^lea eax, \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "FieldAt_%s"),
    (re.compile(r"^lea eax, \[ecx\]$"), "FieldAt_0"),
    (re.compile(r"^fld dword ptr \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "GetFloat_%s"),
]


SETTER_ARGUMENT = re.compile(r"^mov (\w+), (?:dword|byte) ptr \[ebp \+ 8\]$")
SETTER_STORE = re.compile(r"^mov (dword|byte) ptr \[ecx \+ (0x[0-9a-f]+|\d+)\], (\w+)$")


def trivial_name(image, va):
    """
    What a body too small to be about any one class does, as a name - or None when the body
    says more than that. A frame around it is not part of what it does, so it is dropped.
    """
    seen = []
    for address, _, mnemonic, operands in image.cs.disasm_lite(image.read(va, 48) or b"", va):
        if mnemonic.startswith("ret"):
            break
        seen.append(("%s %s" % (mnemonic, operands)).strip())
        if len(seen) > 6:
            return None
    if seen[:2] == ["push ebp", "mov ebp, esp"]:
        seen = seen[2:]
    while seen and seen[-1] in ("pop ebp", "mov esp, ebp"):
        seen.pop()
    if len(seen) == 1:
        for pattern, shape in TRIVIAL_BODIES:
            m = pattern.match(seen[0])
            if m:
                return shape % m.group(1) if "%s" in shape else shape
    if len(seen) == 2:
        argument, store = SETTER_ARGUMENT.match(seen[0]), SETTER_STORE.match(seen[1])
        if argument and store and argument.group(1) == store.group(3):
            return "Set%s_%s" % (store.group(1).capitalize(), store.group(2))
    return None


def vftable_holders(image, rtti):
    """Every address any class's virtual table points at, and which classes those are."""
    holders = collections.defaultdict(set)
    for name, cls in rtti.items():
        for vft in cls.get("vftables") or []:
            address, slots = int(vft["address"], 16), vft["slots"]
            if slots <= 0 or slots > 1024:
                continue
            for i in range(slots):
                target = image.u32(address + 4 * i)
                if target:
                    holders[target].add(name)
    return holders


def folded_across_classes(holders, rtti, va):
    """
    Whether this body fills slots in classes with nothing to do with each other.

    One line of descent is not folding - that is an implementation the derived classes
    inherit, and the class that introduced it may rightly name it.
    """
    owners = holders.get(va) or set()
    if len(owners) < 2:
        return False
    return not any(all(candidate in ancestors_of(rtti, owner) for owner in owners)
                   for candidate in owners)


def base_offset(rtti, name, target, seen=None, at=0):
    """Where target sits inside name, or None when it is not a base of it at all."""
    if name == target:
        return at
    seen = seen if seen is not None else set()
    if name in seen or name not in rtti:
        return None
    seen.add(name)
    for b in rtti[name].get("bases", []):
        found = base_offset(rtti, b["name"], target, seen, at + b.get("offset", 0))
        if found is not None:
            return found
    return None


def ancestors_of(rtti, name, seen=None):
    seen = seen if seen is not None else set()
    if name in seen or name not in rtti:
        return seen
    seen.add(name)
    for b in rtti[name]["bases"]:
        ancestors_of(rtti, b["name"], seen)
    return seen


PURECALL = 0x7961D5
"""
The CRT's `_purecall`, which is what a class's own vftable holds for a method it leaves
pure virtual. Following such a slot lands here rather than on any implementation, so a
name taken from the method would put one class's name on the stub every abstract class in
the game shares. Checked against the executable by `is_purecall` before it is relied on.
"""


def is_purecall(image, rva=PURECALL):
    """Whether that address is the CRT stub: the installed handler if there is one, and
    `_amsg_exit(_RT_PUREVIRT)` - the R6025 message, then the process ends - if there is not."""
    b = image.read(rva + IMAGE_BASE, 20) or b""
    return (len(b) == 20 and b[0:2] == b"\xff\x35" and b[6:8] == b"\xff\x15"
            and b[12:14] == b"\x85\xc0" and b[16:18] == b"\xff\xd0" and b[18:20] == b"\x6a\x19")


# Ids the table has no string for. They are real all the same - the writer puts one in a
# CToken's type field to say what the value is - and without a member Ghidra spells the
# constant as an OR of the members that happen to add up to it: 0xC came out as
# `tok_comma|tok_close`. The ones with a name here were read off the code, the rest are the
# id in hex.
UNREGISTERED_TOKENS = {
    0x00: "tok_none",
    0x0C: "tok_int",     # written with "%d", and read back with atoi
    0x0D: "tok_fixed",   # a whole part, a dot and a fraction, into thousandths
    0x0E: "tok_bool",    # written as the word yes or no, and read back by comparing to "yes"
    0x0F: "tok_word",    # a bare word: what SaveWriteKey gives the key itself
    0x13: "tok_end",     # nothing left to read; CPersistent::Load stops on it
    0x14: "tok_uint",    # written with "%u"
}

PUNCTUATION_NAMES = {
    "=": "equals", '"': "quote", "{": "open", "}": "close", "(": "lparen", ")": "rparen",
    ",": "comma", "#": "hash", "\n": "newline", "\t": "tab", " ": "space", ";": "semicolon",
    ":": "colon", "<": "less", ">": "greater", "!": "bang", "|": "pipe",
}


def modifier_enum():
    """
    Every modifier the executable knows, by id, so that a comparison against one reads as
    its name. `CBuildingDataBase_RoleByModifierId` is five such comparisons in a row, and
    without this they are 0x2E, 0x2D, 0x4B, 0x66 and 0x0F.

    `reversing/modifierIds.py` writes the file, reading the global initialiser that builds
    all 107 of them - the names exist nowhere else in the image, only as the literal each
    one is constructed with.

    Every id from 0 to the last gets a member. A value with no member is one Ghidra writes
    as an OR of the members that reach it, which is a lie about what the code compares.
    """
    if not os.path.exists(MODIFIER_IDS):
        return None
    found = {int(k): v for k, v in json.load(
        open(MODIFIER_IDS, encoding="utf-8")).items()}
    values, taken = [], set()
    for ident in range(max(found) + 1):
        name = found.get(ident) or "MODIFIER_%d" % ident
        # Two modifiers really are built from the same literal: ids 3 and 4 both push
        # 'MANPOWER' and differ only in the save token they load under, 0x2C1 and 0x2C0.
        # An enum cannot hold the name twice, so the second carries its id.
        if name in taken:
            name = "%s_%d" % (name, ident)
        taken.add(name)
        values.append({"name": name, "value": ident})
    return {"name": "ModifierId", "size": 4, "values": values,
            "comment": "Which modifier, as the game numbers them: %d of them, read out of "
                       "the global initialiser that constructs them. From "
                       "reversing/modifierIds.py." % len(values)}


def save_token_enum():
    """
    Every save key the executable itself knows, as an enum, so that `SaveWriteKey(0x5a6,
    writer)` decompiles as `SaveWriteKey(usage, writer)` and a class's LoadKey reads as a
    list of keys rather than a list of numbers. Typing a parameter as this enum is all it
    takes - the decompiler does the rest.

    `reversing/saveTokens.py --compiled` writes the file, off a running game, since the
    table is built at startup and nothing in the image holds it. **Only the executable's own
    tokens go in**: the loaded mod registers about as many again for its resources, cultures
    and decorations, and those are numbered in load order, so their ids say nothing about
    the executable.

    Every id below the last one gets a member even where the table has no string for it,
    because an enum value with no member is one Ghidra writes as an OR of the members that
    reach it - `tok_comma|tok_close` for 0xC, which is a lie about what the code does.
    """
    if not os.path.exists(SAVE_TOKENS):
        return None
    tokens = {int(k): v for k, v in json.load(open(SAVE_TOKENS, encoding="utf-8")).items()}
    # Every id up to the last one the executable knows gets a member, gaps included, or the
    # decompiler makes up an OR of other members to reach the value.
    gaps = {i: UNREGISTERED_TOKENS.get(i, "tok_%02X" % i)
            for i in range(max(tokens) + 1) if i not in tokens}
    values, taken = [], {}
    for ident, key in sorted(tokens.items()):
        if ident in gaps:
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
            name = key
        elif all(c in PUNCTUATION_NAMES for c in key):
            name = "tok_" + "_".join(PUNCTUATION_NAMES[c] for c in key)
        else:
            name = re.sub(r"[^A-Za-z0-9_]", "_", key)
            name = name if re.match(r"^[A-Za-z_]", name) else "_" + name
        if name in taken:                       # never seen, but a name must be unique
            name = "%s_%d" % (name, ident)
        taken[name] = ident
        values.append({"name": name, "value": ident})
    for ident, name in sorted(gaps.items()):
        values.append({"name": name, "value": ident})
    values.sort(key=lambda v: v["value"])
    return {"name": "SaveToken", "size": 4, "values": values,
            "comment": "A save key, as the game writes it: the id, not the string. %d of them, "
                       "the ones built into this executable - what the loaded mod registers on "
                       "top is numbered in load order and left out. From reversing/saveTokens.py."
                       % len(values)}


# CPersistent's virtuals, and the shape each one takes on a class of its own. Slot 0 is the
# destructor, which is not ours to name.
PERSISTENT_SLOTS = {
    1: ("Save", "void __thiscall %s::Save(%s* this, CSaveWriter* writer)"),
    2: ("SaveContents", "void __thiscall %s::SaveContents(%s* this, CSaveWriter* writer)"),
    3: ("Load", "void __thiscall %s::Load(%s* this, CParseContext* parse)"),
    4: ("LoadKey", "void __thiscall %s::LoadKey(%s* this, CParseContext* parse, SaveToken key)"),
    5: ("AfterLoad", "void __thiscall %s::AfterLoad(%s* this)"),
}

# The same five where CPersistent sits at a non-zero offset. `this` is that subobject, not
# the class, and __thiscall will not say so - Ghidra gives a method in a class namespace a
# `this` of its own type whatever the findings write - so the place goes in by hand. The
# type is void*, not CPersistent*: a CPersistent is four bytes here, and Ghidra would index
# the pointer as an array of them rather than showing the offsets.
PERSISTENT_SLOTS_AT = {
    1: ("Save", "void __stdcall %s::Save(void* base@ECX, CSaveWriter* writer@stack:4)"),
    2: ("SaveContents",
        "void __stdcall %s::SaveContents(void* base@ECX, CSaveWriter* writer@stack:4)"),
    3: ("Load", "void __stdcall %s::Load(void* base@ECX, CParseContext* parse@stack:4)"),
    4: ("LoadKey", "void __stdcall %s::LoadKey(void* base@ECX, "
                   "CParseContext* parse@stack:4, SaveToken key@stack:8)"),
    5: ("AfterLoad", "void __stdcall %s::AfterLoad(void* base@ECX)"),
}

# The bodies CPersistent itself provides: named once, under CPersistent, and the two empty
# ones are shared with hundreds of classes that have nothing to do with each other.
PERSISTENT_BASE = {0x45BB10, 0x60CD50, 0xA7C050, 0xABF890, PURECALL + IMAGE_BASE}

# A class whose name Ghidra can hold as a namespace: no templates, no library mangling.
VALID_CLASS = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


STACK_AT = re.compile(r"^stack:(-?0[xX][0-9a-fA-F]+)$")


def parse_locals(item, problems):
    """the `locals` of one address record, checked

    **Stack storage only.** A register local in Ghidra is a variable over a *range* of the
    function, and one register holds several unrelated ones in a function of any size, so
    `EBX` does not name a variable the way `stack:-0x30` does. Nothing stops the decompiler
    propagating into them: type the stack slot a register local is read from and the type
    follows the assignment, which is the whole reason this is worth having.

    The offset is Ghidra's, not the frame pointer's, and the decompiler prints it: the local
    it calls `local_30` is at `stack:-0x30`. On a function with the usual `push ebp; mov
    ebp,esp` that is four less than the `[ebp - 0x2c]` in the disassembly, and taking the
    disassembly's number is the mistake to expect.
    """
    out = []
    for v in item.get("locals", []):
        where = STACK_AT.match(v.get("at", ""))
        if not where:
            problems.append("local %s on %s %s: `at` must be stack:<offset>, e.g. "
                            "stack:-0x30 (Ghidra's offset, the number in its local_30)"
                            % (v.get("name"), item["rva"], item["name"]))
            continue
        if not v.get("name") or not v.get("type"):
            problems.append("local at %s on %s %s: needs both a name and a type"
                            % (v.get("at"), item["rva"], item["name"]))
            continue
        out.append({"at": int(where.group(1), 16), "name": v["name"], "type": v["type"]})
    seen = collections.Counter(v["at"] for v in out)
    for at, n in seen.items():
        if n > 1:
            problems.append("%s %s: two locals at stack:%#x" % (item["rva"], item["name"], at))
    return sorted(out, key=lambda v: v["at"])


def parse_prototype(text):
    """
    'int* __stdcall SupplyCapacity(CMapProvince* province, int* out)' -> signature dict.

    A parameter, or the return, may say where it is passed: `CCountry* country@ESI`, or
    `@stack:4`. That is for a function the compiler kept to itself and gave a convention of
    its own; Ghidra reads such a call as a standard one and shows the wrong arguments unless
    it is told. The return's place goes after the parameter list: `...) @AL`.
    """
    m = re.match(r"^\s*(.+?)\s+(__\w+)\s+([\w:~<>]+)\s*\((.*)\)\s*(?:@\s*([\w:]+))?\s*;?\s*$", text or "")
    if not m:
        return None
    params = []
    for p in [x.strip() for x in LX.split_top(m.group(4)) if x.strip() and x.strip() != "void"]:
        storage = None
        at = re.match(r"^(.*?)@\s*([\w:]+)$", p)
        if at:
            p, storage = at.group(1).strip(), at.group(2)
        pm = re.match(r"^(.*?[\s*&])(\w+)$", p)
        entry = {"name": pm.group(2), "type": pm.group(1).strip()} if pm and pm.group(1).strip() \
            else {"name": None, "type": p}
        if storage:
            entry["storage"] = storage
        params.append(entry)
    out = {"convention": m.group(2), "return": m.group(1).strip(), "hiddenReturn": False, "params": params}
    if m.group(5):
        out["returnStorage"] = m.group(5)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--import", dest="harvest", help="check a harvest file and write it as project.json")
    args = ap.parse_args()
    checker = Checker()
    if args.harvest:
        import_harvest(args.harvest, checker)

    lua = json.load(open(LUABIND))
    project = json.load(open(PROJECT, encoding="utf-8"))
    enums = set(lua["enum_types"])
    save_tokens = save_token_enum()
    if save_tokens:
        enums.add("SaveToken")
    modifier_ids = modifier_enum()
    if modifier_ids:
        enums.add("ModifierId")
    sizes = {k: v[0] for k, v in KNOWN_SIZES.items()}
    for c in lua["classes"]:
        if c["size"]:
            sizes[c["rtti"] or c["cpp"]] = c["size"]

    rtti = LX.load_rtti()
    holders = vftable_holders(checker.image, rtti)

    functions, labels, problems = {}, [], []
    if not is_purecall(checker.image):
        problems.append("%08X is not the _purecall stub any more - pure virtual slots will be "
                        "named after whatever Lua method resolves to them" % (PURECALL + IMAGE_BASE))

    def add_function(rva, namespace, name, confidence, evidence, signature=None, extra_labels=(),
                     proven=False, variables=()):
        va = rva + IMAGE_BASE
        # A luabind registration proves its target is an entry point; the start heuristic
        # is only for addresses that come from notes.
        if not checker.image.is_code(va) or (not proven and not checker.starts_function(va)):
            problems.append("not a function start, left out: %08X %s::%s" % (va, namespace, name))
            return
        if rva in functions:
            f = functions[rva]
            if (f["namespace"], f["name"]) != (namespace, name):
                f["labels"].append({"namespace": namespace, "name": name})
            f["evidence"] += "\n\n" + evidence
            if f["signature"] is None and signature is not None:
                f["signature"] = signature
            if variables and not f.get("locals"):
                f["locals"] = list(variables)
            return
        functions[rva] = {"rva": rva, "namespace": namespace, "name": name, "confidence": confidence,
                          "evidence": evidence, "signature": signature, "labels": list(extra_labels)}
        # Only when there are some. A `"locals": []` on all 901 functions would put a line of
        # noise per function in every diff of the built file, which is what the ordering rules
        # above exist to avoid.
        if variables:
            functions[rva]["locals"] = list(variables)

    # ---- the Lua API ----
    for f in lua["functions"]:
        lua_name = "%s.%s" % (f["class"], f["lua_name"])
        ftype = f.get("function_type")
        if f["kind"] == "operator":
            if f["pointer"]:
                add_function(f["pointer"] - IMAGE_BASE, f["rtti_class"] or f["cpp_class"], "luabind_op" + f["lua_name"].strip("_"),
                             "LIKELY", "luabind's wrapper for the Lua operator %s on %s: not game code, the comparison it "
                             "makes is usually inlined here.\nluabind signature: %s" % (f["lua_name"], f["cpp_class"], f["signature"]), proven=True)
            continue
        owner = (ftype or {}).get("owner") or split_name(f["cpp"])[0] or ""
        name = split_name(f["cpp"])[1]
        evidence = ["Lua: %s:%s   (script/LUA API.txt, %s)" % (f["class"], f["lua_name"], f["cpp"]),
                    "Registered as: %s" % (f.get("registered_as") or "?"),
                    "luabind signature: %s" % f["signature"]]
        if f.get("policy"):
            evidence.append("Lua policy: %s" % f["policy"])
        evidence.append("Recovered by emulating SetupAI (0x%X): the registration object luabind builds for this def "
                        "holds this address." % LX.SETUP_AI)
        sig, note = build_signature(ftype, enums, sizes) if ftype else (None, "")
        if note:
            evidence.append(note)
        confidence = "CERTAIN"
        if f.get("vcall_thunk"):
            # One thunk per vftable offset, shared by every class that calls through it, so
            # it is named for the offset, as MSVC names it (`vcall'{12}), not for one caller.
            offset = f["vtable_slot"] * 4
            add_function(f["vcall_thunk"] - IMAGE_BASE, "", "vcall_0x%X" % offset, "CERTAIN",
                         "MSVC vcall thunk: jumps through offset 0x%X of the vftable of whatever object is in "
                         "ecx. Registered to Lua through it: %s::%s (%s:%s)."
                         % (offset, owner, name, f["class"], f["lua_name"]), proven=True)
            if not f["address"]:
                continue
            evidence.append("Virtual: slot %d of %s's vftable." % (f["vtable_slot"], f["rtti_class"]))
            if f.get("introduced_by"):
                owner = f["introduced_by"]
            else:
                confidence = "TENTATIVE"
                evidence.append("Which class introduced this implementation is not in the RTTI export; named after "
                                "the declaring class.")
        folded = f["address"] and folded_across_classes(holders, rtti, f["address"]) \
            and trivial_name(checker.image, f["address"])
        if folded:
            # The body is one instruction and the linker gave every class that declares such
            # a method the same copy of it. Whose method it is belongs in the labels, not in
            # the name a call site shows.
            evidence.append("The whole body is one instruction, which the linker folds: this "
                            "address fills virtual table slots in %d classes (%s and others), "
                            "so it is named for what it does. The methods registered here are "
                            "labels on it."
                            % (len(holders[f["address"]]),
                               ", ".join(sorted(holders[f["address"]])[:3])))
            add_function(f["address"] - IMAGE_BASE, "", folded, "LIKELY", "\n".join(evidence),
                         None, [{"namespace": owner, "name": name}], proven=True)
            continue
        if f["address"] and f["address"] - IMAGE_BASE == PURECALL:
            # Pure virtual: the slot holds _purecall, so there is no implementation here to
            # name. The derived classes that fill the slot are named from their own tables.
            problems.append("pure virtual, nothing to name at the stub: %s::%s (%s:%s)"
                            % (owner, name, f["class"], f["lua_name"]))
            continue
        if f.get("shared_with") and len(set(f["shared_with"])) > 1:
            names = sorted(set(u.split("::")[-1] for u in f["shared_with"]))
            shared_name = names[0] if len(names) == 1 else "Shared_" + "_".join(names[:3])
            evidence.append("Identical code folded by the linker; the same address is registered as: %s. Named "
                            "generically so no one caller's name misleads the others." % ", ".join(f["shared_with"]))
            add_function(f["address"] - IMAGE_BASE, "", shared_name, "LIKELY", "\n".join(evidence),
                         sig if len(set(u.split("::")[-1] for u in f["shared_with"])) == 1 else None, proven=True)
            continue
        add_function(f["address"] - IMAGE_BASE, owner, name, confidence, "\n".join(evidence), sig, proven=True)

    add_function(LX.SETUP_AI - IMAGE_BASE, "", "SetupAI", "CERTAIN",
                 "void SetupAI(lua_State*): registers the whole AI Lua API with luabind (script/LUA API.txt is its source).",
                 {"convention": "__cdecl", "return": "void", "hiddenReturn": False, "params": [{"name": "L", "type": "lua_State*"}]}, proven=True)
    for va, name, what in ((LX.CLASS_BASE_CTOR, "class_base::class_base", "constructor, takes the Lua class name"),
                           (LX.CLASS_BASE_INIT, "class_base::init", "type ids and class ids of the class and its base"),
                           (LX.ADD_MEMBER, "class_base::add_member", "adds a .def registration to a class"),
                           (LX.ADD_DEFAULT_MEMBER, "class_base::add_default_member", "adds a constructor registration"),
                           (LX.ADD_INNER_SCOPE, "class_base::add_inner_scope", "adds a .scope[...] block"),
                           (LX.REGISTRATION_CTOR, "registration::registration", "base constructor of every registration object"),
                           (LX.GET_CLASS_NAME, "get_class_name", "std::string get_class_name(lua_State*, type_id const&)"),
                           (LX.ADD_ENUM_VALUE, "class_base::add_enum_value", "value(name, number) inside .enum_(...)")):
        ns, n = split_name(name)
        add_function(va - IMAGE_BASE, "luabind::detail::" + ns if ns else "luabind::detail", n, "CERTAIN",
                     "luabind runtime: %s. Identified from its use in SetupAI." % what, proven=True)

    # ---- the rest of the project ----
    # A name written out by hand wins over anything worked out here, but it is worth saying
    # when one of them sits on a body the linker folded: the name is then about one of the
    # classes sharing the address and misleading about the rest.
    for a in project["addresses"]:
        if a["kind"] == "function" and "::" in a["name"]:
            va = int(a["rva"], 16) + IMAGE_BASE
            if folded_across_classes(holders, rtti, va) and trivial_name(checker.image, va):
                problems.append("%s names a body folded into %d classes; %s is what it does"
                                % (a["name"], len(holders[va]), trivial_name(checker.image, va)))
    # Ghidra gives a __thiscall function a `this` of its own unless the function sits in a
    # class namespace, and everything written here shifts one place behind it - so what the
    # code puts in ECX reads as the argument after it. Say ECX outright in those.
    for a in project["addresses"]:
        if "__thiscall" in (a.get("signature") or "") and "::" not in (a.get("name") or ""):
            problems.append("__thiscall outside a class, so Ghidra adds a this of its own "
                            "and the arguments shift: %s %s" % (a["rva"], a["name"]))
    for a in project["addresses"]:
        rva = int(a["rva"], 16)
        conf = CONFIDENCE.get(a["confidence"], "TENTATIVE")
        evidence = "%s\n(%s)" % (a["comment"], a["source"])
        ns, name = split_name(a["name"])
        if a["kind"] == "function":
            add_function(rva, ns, name, conf, evidence, parse_prototype(a.get("signature")),
                         [{"namespace": split_name(x)[0], "name": split_name(x)[1]} for x in a.get("aliases", [])],
                         variables=parse_locals(a, problems))
        else:
            va = rva + IMAGE_BASE
            if not checker.check(a["kind"], va):
                problems.append("does not check out as a %s, left out: %08X %s" % (a["kind"], va, a["name"]))
                continue
            if a["kind"] == "vftable":
                ns, name = checker.vftable_class(va), "vftable"
            labels.append({"rva": rva, "namespace": ns, "name": name, "kind": a["kind"], "confidence": conf,
                           "evidence": evidence, "type": a.get("type")})

    # ---- CPersistent's five, wherever a class writes its own ----
    # The slot records name the slot; this names the body behind it, which is what a call
    # site reads. The RTTI export says which implementation each class introduced, so a body
    # inherited from a base is left to the base and a body shared with an unrelated class -
    # the empty defaults - is left alone.
    for name, cls in sorted(rtti.items()):
        if not VALID_CLASS.match(name):
            continue
        # Which table the five sit in depends on where CPersistent sits in the object. A
        # class that reaches it through a base at a non-zero offset - CUnit gets there
        # through CReferenceObject at +8 - keeps them in that base's table, and the primary
        # table's slots 1 to 5 are something else entirely.
        at = base_offset(rtti, name, "CPersistent")
        if at is None:
            continue
        for i in cls.get("introduces", []):
            slot, va = i["slot"], int(i["address"], 16)
            if i.get("vftable_offset", 0) != at or slot not in PERSISTENT_SLOTS                or va in PERSISTENT_BASE:
                continue
            method, shape = (PERSISTENT_SLOTS if at == 0 else PERSISTENT_SLOTS_AT)[slot]
            # Where CPersistent sits at a non-zero offset the call hands over that
            # subobject, not the class - `this` is `<class> + at` - so typing the parameter
            # as the class would read every field eight or twelve bytes early.
            this = name if at == 0 else "CPersistent"
            note = ("Slot %d of CPersistent, this class's own: the RTTI export says %s "
                    "introduced the implementation at this address. See "
                    "GameClasses/CPersistent.hpp for what the five do." % (slot, name))
            if at:
                note += (" **`this` is the CPersistent subobject, %s + %d**, because that is "
                         "where CPersistent sits in this class; add %d to any offset here to "
                         "get a %s one." % (name, at, at, name))
            prototype = shape % ((this, this) if at == 0 else (name,))
            add_function(va - IMAGE_BASE, name, method, "CERTAIN", note,
                         parse_prototype(prototype), proven=True)

    # ---- structures ----
    structs = collections.OrderedDict()

    def struct(name):
        return structs.setdefault(name, {"name": name, "size": None, "fields": []})

    def list_node(element, where):
        """the CListNode<element> struct, made if it is not there yet

        Returns False for an element whose width is unknown, since the links sit after it and
        nothing can be laid out without that. The allocations say the size: CGovernment's
        ideology nodes are `new(0x10)` for a 4 byte element and CMinister's postings
        `new(0x14)` for an 8 byte one - the element, two links and a byte, padded to four.
        """
        if element.endswith("*"):
            width = 4
        elif element in SCALAR_WIDTHS:
            width = SCALAR_WIDTHS[element]
        else:
            width = structs.get(element, {}).get("size")
        if not width:
            return False
        width = (width + 3) // 4 * 4
        node = struct("CListNode<%s>" % element)
        if not node["fields"]:
            node["fields"] = [
                {"offset": 0, "name": "data", "type": element, "priority": 2,
                 "comment": "what the node holds (%s)" % where},
                {"offset": width, "name": "prev", "type": "CListNode<%s>*" % element, "priority": 2,
                 "comment": "the previous node"},
                {"offset": width + 4, "name": "next", "type": "CListNode<%s>*" % element, "priority": 2,
                 "comment": "the next node"},
                {"offset": width + 8, "name": "flag", "type": "uint8_t", "priority": 2,
                 "comment": "a byte the node is made with cleared, like CList's own"}]
            node["size"] = width + 12
        return True

    for name, (size, why) in KNOWN_SIZES.items():
        struct(name)["size"] = size
    tag = struct("CCountryTag")
    tag["fields"] += [{"offset": 0, "name": "tag", "type": "char[4]", "comment": "three characters and a NUL", "priority": 0},
                      {"offset": 4, "name": "id", "type": "int", "comment": "the country's index", "priority": 0}]
    # Field priority: what the game names wins, BiceLib's own name and notes go into the
    # comment. 0 declared to Lua with def_readwrite, 1 read by a game accessor, 2 a BiceLib
    # header, 3 BiceLib's other notes.
    for c in lua["classes"]:
        s = struct(c["rtti"] or c["cpp"])
        if c["size"]:
            s["size"] = c["size"]
        for fld in c["fields"]:
            declared = fld["evidence"].startswith("luabind def_")
            s["fields"].append({"offset": fld["offset"], "name": fld["name"], "type": fld["type"].replace(" &", "&"),
                                "comment": ("declared to Lua" if declared else "read by %s" % fld["evidence"].split(" at ")[0].replace("accessor ", "")),
                                "priority": 0 if declared else 1})
    for p in project["structs"]:
        s = struct(p["name"])
        if p.get("size"):
            s["size"] = int(p["size"], 16)
        for fld in p["fields"]:
            header = fld["source"].split(":")[0].endswith(".hpp")
            s["fields"].append({"offset": int(fld["offset"], 16), "name": fld["name"], "type": fld["type"],
                                "comment": "%s (%s)" % (fld["comment"], fld["source"]), "priority": 2 if header else 3})
    # Every instantiation of the game's CList has the one layout, recorded once in
    # project.json as "CList"; CUnitList is a CList with nothing added (RTTI: its only
    # base, at 0, and no vftable). Lay each one the Lua API names out the same way.
    if "CList" in structs:
        shape = structs["CList"]
        SCALAR_WIDTHS = {"int": 4, "uint": 4, "unsigned int": 4, "float": 4, "undefined4": 4,
                         "bool": 1, "char": 1, "uint8_t": 1, "short": 2, "uint16_t": 2,
                         "int64_t": 8, "double": 8}
        lists = {f["type"] for s in structs.values() for f in s["fields"]}
        for text in lists:
            base = LX.parse_type(re.sub(r"\[\d+\]$", "", text).replace(" &", "&").replace(" *", "*"), enums)["base"]
            if base != "CList" and (re.match(r"^CList<.*>$", base) or base == "CUnitList"):
                s = struct(base)
                s["size"] = shape["size"]
                if not s["fields"]:
                    s["fields"] = [dict(f) for f in shape["fields"]]
                # Each instantiation gets a node type of its own, so a walk reads
                # `node->data->field` rather than stopping at an untyped word. **A node
                # holds its element at 0 and links at the end of it**: prev at the
                # element's width, rounded up to a pointer, and next four bytes after.
                # Read out of CHistoricalModelSet::MakeSubUnit for CList<CSubUnitTechnology>,
                # whose element is 0xC and whose next is at 0x10, and confirmed live by
                # walking first to last in `count` steps - unanimous on 288
                # CList<CSubUnitTechnology> and 827 CList<int>, which is the same rule the
                # pointer lists already followed at two more widths. An element whose width
                # we do not know is left alone.
                element = "CUnit*" if base == "CUnitList" else base[len("CList<"):-1]
                where = shape["fields"][0]["comment"].split(" (")[-1].rstrip(")")
                if not list_node(element, where):
                    continue
                for f in s["fields"]:
                    if f["name"] in ("first", "last"):
                        f["type"] = "CListNode<%s>*" % element
    # **A local can ask for a list node no field does.** A list built inside a function - a
    # queue of provinces, say - is nobody's member, so nothing in the CList pass above ever
    # reaches it; without this the type in the finding resolves to an empty struct and the
    # apply lays down nothing. Same generator, so such a node is identical to one a field
    # asked for and the two share a definition when both exist.
    for f in sorted(functions.values(), key=lambda f: f["rva"]):
        for v in f.get("locals", []):
            for element in sorted(set(re.findall(r"CListNode<(.+?)>", v["type"]))):
                if not list_node(element, "a local of %s" % f["name"]):
                    problems.append("%s %s: CListNode<%s> - the element's width is unknown, so "
                                    "the node cannot be laid out" % (f["rva"], f["name"], element))

    # Ghidra has no inheritance between structures: a derived class only reads well if its
    # base's fields are laid out on it too. `"inherits"` in project.json names a base that
    # sits at offset 0, and its fields are copied in - a field the derived class declares
    # itself always wins.
    inherits = {p["name"]: p["inherits"] for p in project["structs"] if p.get("inherits")}
    inherited = set()

    def inherit(name, seen=()):
        if name in inherited or name in seen:
            return
        base = inherits.get(name)
        if base:
            inherit(base, seen + (name,))
        inherited.add(name)
        if base is None:
            return
        if base not in structs:
            print("! %s inherits %s, which nothing lays out" % (name, base))
            return
        s = struct(name)
        taken = {f["offset"] for f in s["fields"]}
        for f in structs[base]["fields"]:
            if f["offset"] not in taken:
                s["fields"].append(dict(f, comment="%s, inherited from %s" % (f["comment"], base)))

    for name in list(inherits):
        inherit(name)
    TYPE_MAP = {"pointer": "undefined4", "uintptr_t": "undefined4", "uint8_t": "unsigned char", "int8_t": "signed char",
                "uint16_t": "unsigned short", "int16_t": "short", "uint32_t": "unsigned int", "int32_t": "int",
                "DWORD": "unsigned int", "BYTE": "unsigned char", "WORD": "unsigned short",
                # The compiler's own name for the game's 64 bit fixed point, from RTTI: 48
                # integer bits and 15 fractional ones, so 32768 is 1. A structure of that
                # name would only get in the way of reading it.
                "fpml::fixed_point<__int64,48,15>": "longlong"}
    struct_sizes = dict(sizes)
    for s in structs.values():
        if s["size"]:
            struct_sizes[s["name"]] = s["size"]
        for fld in s["fields"]:
            # One spelling per type, the one structures are named by: `CList<CConvoy *>` and
            # `CList<CConvoy*>` would otherwise be two names, one of them never laid out.
            spelled = re.sub(r"\s+([*&])", r"\1", fld["type"])
            fld["type"] = TYPE_MAP.get(spelled, spelled)
    # How far a structure reaches when no size is recorded: to the end of its furthest
    # field. Only for folding a field into the one that contains it - the script lays a
    # structure out to at least that extent, so what lies inside it is already there.
    extents = dict(struct_sizes)
    for s in structs.values():
        if s["name"] not in extents and s["fields"]:
            extents[s["name"]] = max(f["offset"] + (field_size(f["type"], enums, struct_sizes) or 1)
                                     for f in s["fields"])
    for s in structs.values():
        s["fields"] = merge_fields(s["fields"], enums, extents)
    # Two fields that overlap are placed in turn, each clearing the other, so an apply never
    # settles and `overwrite` flip-flops the pair for ever. Nothing downstream can spot it.
    for s in structs.values():
        laid = sorted(s["fields"], key=lambda f: f["offset"])
        for first, second in zip(laid, laid[1:]):
            width = field_size(first["type"], enums, extents)
            if width and first["offset"] + width > second["offset"]:
                print("! %s: %s (%s, %d bytes at +%#x) runs into %s at +%#x - they will fight "
                      "on every apply" % (s["name"], first["name"], first["type"], width,
                                          first["offset"], second["name"], second["offset"]))

    # ---- enums ----
    enum_out = {}
    api = {c["lua"]: c for c in LX.parse_api(LX.API_FILE)}
    groups = parse_enum_groups(LX.API_FILE)
    norm = lambda s: re.sub(r"[^a-z]", "", s.lower())
    for cls, group, values in groups:
        target = None
        first = norm(values[0][0]) if values else ""
        for e in enums:
            leaf = split_name(e)[1]
            if first.startswith(norm(leaf)) or (leaf.startswith("E") and first.startswith(norm(leaf[1:]))):
                target = e
        if target is None:
            target = next((e for e in enums if split_name(e)[1] == group), None)
        if target is None and group != "constants":
            target = group
        if target is None:
            continue
        lua_values = {n: v for n, v in ((x["name"], x["value"]) for c in lua["classes"] if c["lua"] == cls for x in c["enums"])}
        enum_out[target] = {"name": target, "size": 4, "comment": "values registered to Lua on %s as enum_(\"%s\")" % (cls, group),
                            "values": [{"name": n, "value": lua_values[n]} for n, _ in values if n in lua_values]}
    for e in enums:
        enum_out.setdefault(e, {"name": e, "size": 4, "comment": "an enum the Lua API passes; values not registered", "values": []})
    if save_tokens:
        enum_out["SaveToken"] = save_tokens
    if modifier_ids:
        enum_out["ModifierId"] = modifier_ids

    vftables = virtual_tables(checker, structs, functions, labels, project.get("vftable_slots"))

    out = {"about": "Built by buildFindings.py from luabind.json and project.json. Applied by ApplyBiceLibFindings.java.",
           "image_base": IMAGE_BASE,
           # Every list in the file is ordered by something of its own, so two runs over the
           # same inputs produce the same bytes. The structures are the exception that
           # proves it: they have to be laid out in embedding order, so they are sorted
           # inside that walk rather than here.
           "enums": sorted(enum_out.values(), key=lambda e: e["name"]),
           "structs": embedded_first([s for s in structs.values() if s["fields"] or s["size"]], enums),
           "functions": sorted(functions.values(), key=lambda f: (f["rva"], f["name"])),
           "labels": sorted(labels, key=lambda l: (l["rva"], l["name"])),
           "vftables": sorted(vftables, key=lambda v: v["name"]),
           # Straight through from project.json: an equate names one constant at one
           # instruction, and there is nothing to derive or check against the image
           # that the apply does not check better when it looks at the operand.
           # rva as a number, the way every other section carries it: the apply
           # reads it with getAsLong(), which does not parse "0x...".
           "equates": [dict(e, rva=int(e["rva"], 16))
                       for e in project.get("equates", [])]}
    json.dump(out, open(OUT, "w", encoding="utf-8"), indent=1)
    counts = collections.Counter(f["confidence"] for f in functions.values())
    print("wrote %s: %d functions %s, %d with signatures, %d labels, %d structs (%d fields), %d enums" % (
        OUT, len(functions), dict(counts), sum(1 for f in functions.values() if f["signature"]), len(labels),
        len(out["structs"]), sum(len(s["fields"]) for s in out["structs"]), len(enum_out)))
    for p in problems:
        print("  " + p)


def virtual_tables(checker, structs, functions, labels, overrides=None):
    """
    One structure per virtual table, so a call through one reads as a name rather than an
    offset: `unit->vftable->GetAverageOrganisation(...)` instead of `(**(*unit + 0x50))()`.

    The tables are read out of the executable and their length comes from the RTTI export.
    A class whose own table the compiler never wrote - an abstract base such as CPersistent -
    still gets one, out of its `vftable_slots` records alone, since calls on a pointer to it
    go through a table all the same.

    A slot whose function the findings name takes that name; the rest are `vf_<slot>`, which
    still says which slot a call went through. An override in `vftable_slots` may be a name
    on its own, or `{"name": ..., "signature": ...}` where the signature is what the slot is
    typed from. A record written against a base class names that slot in every table below
    it - CPersistent's six virtuals reach all 754 classes that derive from it this way - and
    is weaker than a name read off the slot's own body. Only classes the findings already describe -
    a structure, or a vftable of their own - are laid out, since those are the ones anyone
    is reading.
    """
    rtti = LX.load_rtti()
    known_functions = {f["rva"]: f for f in functions.values()}
    known_labels = {l["rva"]: l for l in labels}
    wanted = set(structs) | {l.get("namespace") for l in labels if l["kind"] == "vftable"}

    def ancestors(name, seen=None):
        """The class and everything it derives from: whose methods its table may hold."""
        seen = seen if seen is not None else set()
        if name in seen or name not in rtti:
            return seen
        seen.add(name)
        for b in rtti[name]["bases"]:
            ancestors(b["name"], seen)
        return seen

    tables = []
    for name, cls in sorted(rtti.items()):
        if name not in wanted or not cls["vftables"]:
            continue
        for vft in cls["vftables"]:
            rva = int(vft["address"], 16) - IMAGE_BASE
            slots = vft["slots"]
            if slots <= 0 or not checker.is_vftable(rva + IMAGE_BASE):
                continue
            targets = [checker.image.u32(rva + IMAGE_BASE + 4 * i) - IMAGE_BASE for i in range(slots)]
            tables.append((name, vft["object_offset"], rva, targets))
    # How many of these tables each body fills: more than one and it is folded or inherited.
    appearances = collections.Counter(t for _, _, _, targets in tables for t in set(targets))

    out = []
    for name, at, rva, targets in tables:
        family = ancestors(name)
        struct_name = "%s_vftable" % name if at == 0 else "%s_vftable_at%X" % (name, at)
        by_slot = (overrides or {}).get(name, {})
        # A base class's slots are its descendants' slots too, so a record written once
        # against the base names that slot in every table below it. It is the weaker claim
        # of the two: a name read off the slot's own body wins, since that body is the
        # override the class actually wrote.
        from_base = {}
        for ancestor in sorted(family - {name}):
            for slot, record in ((overrides or {}).get(ancestor) or {}).items():
                from_base.setdefault(slot, (ancestor, record))
        entries, taken = [], collections.Counter()
        for i, target in enumerate(targets):
            known = known_functions.get(target) or known_labels.get(target)
            # A name goes on a slot only when it can only mean this class: a method of the
            # class or one it derives from, or a name of ours that fills a slot in no other
            # table. The linker folds identical bodies together - every `mov al,1; ret` in
            # the game is one address - so anything else would say something false here.
            mine = bool(known) and (known.get("namespace") in family
                                    or (not known.get("namespace") and appearances[target] == 1))
            # An override is a name, or a record with a name and the signature to type the
            # slot from - for a slot the class leaves pure virtual, where the body at the
            # address is _purecall and says nothing about the call.
            override = by_slot.get(str(i))
            override = {"name": override} if isinstance(override, str) else override
            base_class, inherited = from_base.get(str(i), (None, None))
            inherited = {"name": inherited} if isinstance(inherited, str) else inherited
            # A body too small to belong to anyone is named for what it does, and the
            # classes that declare such a method are kept on it as labels. One of those
            # labels may be this class's, and in this table that name is right - it is
            # only the address that cannot carry it.
            declared = next((l for l in (known or {}).get("labels") or []
                             if l.get("namespace") in family), None)
            slot_name = ((override or {}).get("name")
                         or (split_name(known["name"])[1] if mine
                             else declared["name"] if declared
                             else (inherited or {}).get("name") or "vf_%d" % i))
            taken[slot_name] += 1
            if taken[slot_name] > 1:                    # one body filling several slots
                slot_name = "%s_%d" % (slot_name, i)
            comment = "slot %d, %08X" % (i, target + IMAGE_BASE)
            if override:
                comment += " - named by BiceLib"
            elif inherited and not mine and not declared:
                comment += " - %s's slot, named by BiceLib" % base_class
            elif declared:
                comment += (" - a body the linker folded, named for this class from %s::%s"
                            % (declared["namespace"], declared["name"]))
            elif known and not mine:
                comment += " - a body shared with %s, so not named here" % qualified_name(known)
            # Only a body that is this class's own gets its signature put on the slot: a
            # folded body carries whatever signature the class it was named for has, and
            # typing the slot from that would read as a call on the wrong class.
            #
            # `own` says the body belongs to this class alone or to the family it was
            # inherited through, so a name you give it in Ghidra means the same thing in
            # this slot and the script may take it. A folded body fills slots in classes
            # with nothing in common, and gets neither its name nor its signature.
            entry = {"slot": i, "rva": target, "name": slot_name,
                     "named": mine or bool(override) or bool(declared) or bool(inherited), "typed": mine,
                     "own": inherited_only(target, tables, rtti),
                     "comment": comment}
            written = override if override and override.get("signature") else (
                inherited if inherited and not mine and not declared else None)
            if written and written.get("signature"):
                entry["signature"] = parse_prototype(written["signature"])
                entry["named"] = True
                entry["comment"] += ", typed from the findings"
            entries.append(entry)
        out.append({"name": struct_name, "class": name, "rva": rva,
                    "objectOffset": at, "slots": entries})

    # A base class may have no table of its own - CPersistent is never instantiated, so the
    # compiler wrote none - and yet every call inside its own methods goes through one, and
    # so does every call on a pointer to it. Its slot records are enough to write the table
    # out, which is what turns `(**(*this + 8))(writer)` into
    # `this->vftable->SaveContents(writer)`. Where the base has a body of its own for a slot
    # the slot points at it, the same as a real table's would.
    by_qualified = {(f.get("namespace"), f["name"]): f for f in functions.values()}
    for name, by_slot in sorted((overrides or {}).items()):
        if name.startswith("_") or name not in rtti or rtti[name]["vftables"]:
            continue
        records = {int(k): v for k, v in by_slot.items() if k.isdigit()}
        if not records:
            continue
        entries = []
        for i in range(max(records) + 1):
            record = records.get(i)
            record = {"name": record} if isinstance(record, str) else record
            slot_name = (record or {}).get("name") or "vf_%d" % i
            impl = by_qualified.get((name, slot_name))
            # Zero rather than nothing where the base has no body of its own: the address is
            # never read for such a slot, and a null would make an older apply script throw.
            entry = {"slot": i, "rva": impl["rva"] if impl else 0, "name": slot_name,
                     "named": bool(record), "typed": bool(impl and impl["signature"]),
                     "own": bool(impl),
                     "comment": "slot %d of %s, which has no table of its own - written from "
                                "the findings" % (i, name)}
            if impl:
                entry["comment"] += ", pointing at %s::%s" % (name, slot_name)
            else:
                entry["comment"] += "; no body at this level, so no address"
                if record and record.get("signature"):
                    entry["signature"] = parse_prototype(record["signature"])
                    entry["comment"] += ", typed from the signature there"
            entries.append(entry)
        out.append({"name": "%s_vftable" % name, "class": name, "rva": 0,
                    "objectOffset": 0, "slots": entries})
    return out


def qualified_name(item):
    ns = item.get("namespace")
    return "%s::%s" % (ns, item["name"]) if ns else item["name"]


def inherited_only(target, tables, rtti):
    """
    Whether every table holding this body belongs to one line of descent - so the body is
    the class's own, or inherited from the class the others derive from.

    That tells an inherited implementation, which `CArmy`, `CNavy` and `CUnit` rightly
    share, from a body the linker folded, which turns up in classes with nothing to do
    with each other.
    """
    owners = {name for name, _, _, targets in tables if target in targets}
    if len(owners) == 1:
        return True

    def ancestors(name, seen=None):
        seen = seen if seen is not None else set()
        if name in seen or name not in rtti:
            return seen
        seen.add(name)
        for b in rtti[name]["bases"]:
            ancestors(b["name"], seen)
        return seen

    return any(all(candidate in ancestors(owner) for owner in owners) for candidate in owners)


SCALAR_SIZES = {"bool": 1, "char": 1, "signed char": 1, "unsigned char": 1, "short": 2, "unsigned short": 2,
                "int": 4, "unsigned int": 4, "long": 4, "unsigned long": 4, "float": 4, "double": 8,
                "__int64": 8, "unsigned __int64": 8, "undefined4": 4, "undefined1": 1,
                # Ghidra's own spellings, which is what TYPE_MAP hands back: without these a
                # 64-bit field has no size, nothing folds into it, and a field inside it
                # survives to fight with it on every apply.
                "longlong": 8, "ulonglong": 8, "long long": 8, "unsigned long long": 8,
                "undefined8": 8, "undefined2": 2, "byte": 1, "word": 2, "dword": 4, "qword": 8}


def field_size(type_text, enums, struct_sizes):
    """The size a field of this type takes, or None when it is a class of unknown size."""
    m = re.match(r"^(.*)\[(\d+)\]$", type_text.strip())
    if m:
        element = field_size(m.group(1), enums, struct_sizes)
        return element * int(m.group(2)) if element else None
    t = LX.parse_type(type_text.replace(" &", "&").replace(" *", "*"), enums)
    if t["category"] == "pointer":
        return 4
    if t["category"] == "enum":
        return 4
    base = re.sub(r"\s+const$", "", t["base"])
    return SCALAR_SIZES.get(base) or struct_sizes.get(base)


def merge_fields(fields, enums, struct_sizes):
    """
    One field per offset, the most authoritative, with the others' names and notes kept
    in its comment; and a field that falls inside a larger typed one folded into it, so
    the script has nothing to refuse.
    """
    by_offset = collections.OrderedDict()
    for f in sorted(fields, key=lambda x: (x["offset"], x["priority"])):
        by_offset.setdefault(f["offset"], []).append(f)
    merged = []
    for offset, group in by_offset.items():
        winner = dict(group[0])
        for other in group[1:]:
            if other["name"].lower() == winner["name"].lower() and other["type"] == winner["type"]:
                continue
            if field_size(winner["type"], enums, struct_sizes) is None and field_size(other["type"], enums, struct_sizes) \
                    and other["type"] not in ("undefined4", "undefined1"):
                winner["type"] = other["type"]         # a concrete type beats a class of unknown size
            winner["comment"] += "\nBiceLib: %s (%s) - %s" % (other["name"], other["type"], other["comment"])
        merged.append(winner)
    out = []
    for f in merged:
        host = next((h for h in reversed(out)
                     if h["offset"] < f["offset"] < h["offset"] + (field_size(h["type"], enums, struct_sizes) or 0)
                     and h["priority"] <= f["priority"]), None)
        if host:
            host["comment"] += "\n+0x%X inside it: %s (%s) - %s" % (f["offset"] - host["offset"], f["name"], f["type"], f["comment"])
            continue
        out.append(f)
    out.sort(key=lambda x: (x["priority"], x["offset"], x["name"]))
    for f in out:
        del f["priority"]
    return out


def embedded_first(struct_list, enums):
    """
    The structures ordered so any one held by value - a field, or an array of them - comes
    before the structures that hold it. The script lays them out in this order, and a
    structure has no size until it has been laid out, so an embedding placed first would
    have nothing to measure.

    **Seeded by name**, which is what makes the built file the same every time: the walk
    below only constrains a structure against the ones it embeds, so everything else keeps
    whatever order it arrived in - and that order comes off dicts and sets upstream, which
    moved between runs and put a few hundred lines of pure noise in every diff.
    """
    by_name = {s["name"]: s for s in struct_list}
    ordered, state = [], {}

    def embeds(s):
        for f in s["fields"]:
            t = re.sub(r"\[\d+\]$", "", f["type"].strip())
            parsed = LX.parse_type(t.replace(" &", "&").replace(" *", "*"), enums)
            if parsed["category"] == "class" and parsed["base"] in by_name and parsed["base"] != s["name"]:
                yield by_name[parsed["base"]]

    def visit(s):
        if state.get(s["name"]) == "done":
            return
        if state.get(s["name"]) == "visiting":
            return                                  # a cycle cannot be embedded by value; leave it
        state[s["name"]] = "visiting"
        for inner in embeds(s):
            visit(inner)
        state[s["name"]] = "done"
        ordered.append(s)

    for s in sorted(struct_list, key=lambda x: x["name"]):
        visit(s)
    return ordered


def parse_enum_groups(path):
    text = re.sub(r"//[^\n]*", "", open(path).read())
    groups, cls = [], None
    for m in re.finditer(r'class_<[^"]*?>\s*\(\s*"([^"]+)"\s*\)|\.enum_\(\s*"([^"]+)"\s*\)\s*\[(.*?)\]', text, re.S):
        if m.group(1):
            cls = m.group(1)
        else:
            values = re.findall(r'value\(\s*"([^"]+)"\s*,\s*([^)]+)\)', m.group(3))
            groups.append((cls, m.group(2), values))
    return groups


if __name__ == "__main__":
    main()
