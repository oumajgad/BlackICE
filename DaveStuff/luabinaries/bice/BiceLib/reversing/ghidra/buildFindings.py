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
    sizes = {k: v[0] for k, v in KNOWN_SIZES.items()}
    for c in lua["classes"]:
        if c["size"]:
            sizes[c["rtti"] or c["cpp"]] = c["size"]

    functions, labels, problems = {}, [], []

    def add_function(rva, namespace, name, confidence, evidence, signature=None, extra_labels=(), proven=False):
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
            return
        functions[rva] = {"rva": rva, "namespace": namespace, "name": name, "confidence": confidence,
                          "evidence": evidence, "signature": signature, "labels": list(extra_labels)}

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
    for a in project["addresses"]:
        rva = int(a["rva"], 16)
        conf = CONFIDENCE.get(a["confidence"], "TENTATIVE")
        evidence = "%s\n(%s)" % (a["comment"], a["source"])
        ns, name = split_name(a["name"])
        if a["kind"] == "function":
            add_function(rva, ns, name, conf, evidence, parse_prototype(a.get("signature")),
                         [{"namespace": split_name(x)[0], "name": split_name(x)[1]} for x in a.get("aliases", [])])
        else:
            va = rva + IMAGE_BASE
            if not checker.check(a["kind"], va):
                problems.append("does not check out as a %s, left out: %08X %s" % (a["kind"], va, a["name"]))
                continue
            if a["kind"] == "vftable":
                ns, name = checker.vftable_class(va), "vftable"
            labels.append({"rva": rva, "namespace": ns, "name": name, "kind": a["kind"], "confidence": conf,
                           "evidence": evidence, "type": a.get("type")})

    # ---- structures ----
    structs = collections.OrderedDict()

    def struct(name):
        return structs.setdefault(name, {"name": name, "size": None, "fields": []})

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
        lists = {f["type"] for s in structs.values() for f in s["fields"]}
        for text in lists:
            base = LX.parse_type(re.sub(r"\[\d+\]$", "", text).replace(" &", "&").replace(" *", "*"), enums)["base"]
            if base != "CList" and (re.match(r"^CList<.*>$", base) or base == "CUnitList"):
                s = struct(base)
                s["size"] = shape["size"]
                if not s["fields"]:
                    s["fields"] = [dict(f) for f in shape["fields"]]
                # A list of pointers gets a node type of its own, so a walk reads
                # `node->data->field` rather than stopping at an untyped word. Only for
                # pointer elements: where the element is a class held by value the node
                # is wider than one word and where prev and next then sit is not known.
                element = "CUnit*" if base == "CUnitList" else base[len("CList<"):-1]
                if not element.endswith("*"):
                    continue
                node = struct("CListNode<%s>" % element)
                if not node["fields"]:
                    node["fields"] = [
                        {"offset": 0, "name": "data", "type": element, "priority": 2,
                         "comment": "what the node holds (%s)" % shape["fields"][0]["comment"].split(" (")[-1].rstrip(")")},
                        {"offset": 4, "name": "prev", "type": "CListNode<%s>*" % element, "priority": 2,
                         "comment": "the previous node"},
                        {"offset": 8, "name": "next", "type": "CListNode<%s>*" % element, "priority": 2,
                         "comment": "the next node"}]
                for f in s["fields"]:
                    if f["name"] in ("first", "last"):
                        f["type"] = "CListNode<%s>*" % element
    TYPE_MAP = {"pointer": "undefined4", "uintptr_t": "undefined4", "uint8_t": "unsigned char", "int8_t": "signed char",
                "uint16_t": "unsigned short", "int16_t": "short", "uint32_t": "unsigned int", "int32_t": "int",
                "DWORD": "unsigned int", "BYTE": "unsigned char", "WORD": "unsigned short"}
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

    vftables = virtual_tables(checker, structs, functions, labels, project.get("vftable_slots"))

    out = {"about": "Built by buildFindings.py from luabind.json and project.json. Applied by ApplyBiceLibFindings.java.",
           "image_base": IMAGE_BASE,
           "enums": list(enum_out.values()),
           "structs": embedded_first([s for s in structs.values() if s["fields"] or s["size"]], enums),
           "functions": sorted(functions.values(), key=lambda f: f["rva"]),
           "labels": sorted(labels, key=lambda l: l["rva"]),
           "vftables": vftables}
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
    A slot whose function the findings name takes that name; the rest are `vf_<slot>`, which
    still says which slot a call went through. Only classes the findings already describe -
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
        entries, taken = [], collections.Counter()
        for i, target in enumerate(targets):
            known = known_functions.get(target) or known_labels.get(target)
            # A name goes on a slot only when it can only mean this class: a method of the
            # class or one it derives from, or a name of ours that fills a slot in no other
            # table. The linker folds identical bodies together - every `mov al,1; ret` in
            # the game is one address - so anything else would say something false here.
            mine = bool(known) and (known.get("namespace") in family
                                    or (not known.get("namespace") and appearances[target] == 1))
            slot_name = by_slot.get(str(i)) or (split_name(known["name"])[1] if mine else "vf_%d" % i)
            taken[slot_name] += 1
            if taken[slot_name] > 1:                    # one body filling several slots
                slot_name = "%s_%d" % (slot_name, i)
            comment = "slot %d, %08X" % (i, target + IMAGE_BASE)
            if str(i) in by_slot:
                comment += " - named by BiceLib"
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
            entries.append({"slot": i, "rva": target, "name": slot_name,
                            "named": mine or str(i) in by_slot, "typed": mine,
                            "own": inherited_only(target, tables, rtti),
                            "comment": comment})
        out.append({"name": struct_name, "class": name, "rva": rva,
                    "objectOffset": at, "slots": entries})
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
                "__int64": 8, "unsigned __int64": 8, "undefined4": 4, "undefined1": 1}


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
    out.sort(key=lambda x: (x["priority"], x["offset"]))
    for f in out:
        del f["priority"]
    return out


def embedded_first(struct_list, enums):
    """
    The structures ordered so any one held by value - a field, or an array of them - comes
    before the structures that hold it. The script lays them out in this order, and a
    structure has no size until it has been laid out, so an embedding placed first would
    have nothing to measure.
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

    for s in struct_list:
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
