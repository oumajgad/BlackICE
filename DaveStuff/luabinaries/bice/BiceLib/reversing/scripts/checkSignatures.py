"""Checks what `project.json` claims about a function against what the function does.

    python scripts/checkSignatures.py                  everything, summarised
    python scripts/checkSignatures.py --verbose        and say why each one was skipped
    python scripts/checkSignatures.py --only 0x67B250  one entry
    python scripts/checkSignatures.py --candidates     the fragments, before they land

`--candidates` reads `addresses` out of `fragments/incoming/*.json` - or out of the files
named after it - instead of out of `project.json`, which is what an agent needs: the whole
point of the check is to run it on a signature you have just written, and until 2026-10-06
`--only` could only reach one that was already recorded. Wave 13's agent C wrote its own
checker for want of this.

Two claims in the findings are decidable by machine, and both have already been wrong:

**The calling convention against the `ret`.** A `__cdecl` function leaves its arguments
for the caller and ends in a bare `ret`; `__stdcall` and `__thiscall` clean their own and
end in `ret N`, where N is the stack argument bytes. So the signature predicts the exact
immediate on the return instruction, and the executable either agrees or it does not.
`ParseObjectId` was recorded `__cdecl` and ends `ret 8`.

**A constructor against the vftable it writes.** `X::X` writes `X`'s own virtual table
into the object. `0x27D070` was recorded as `CCurrentGameState::CCurrentGameState` and
writes `CGameState`'s table, because it is the base constructor and the derived one is
inlined at all 2773 call sites.

Neither error was a careless one. Both entries were marked `confirmed`, and both cite a
`FINDINGS-*.md` - an earlier write-up - rather than anything checked against the image.
554 of the 756 confirmed entries cite prose that way, which is far too many to re-read
and exactly the right number to check by script.

**A mismatch is a question, not a verdict.** A function can end in a tail `jmp` with no
`ret` of its own, take an argument in a register the signature cannot express, or hold a
struct by value whose size this cannot know. Every one of those is reported as skipped,
with the reason, rather than counted as wrong - and the point of `--verbose` is to let
you see whether a skip is hiding something.
"""

import argparse
import glob
import io
import json
import os
import re

import capstone

import cfg
import hoi3
import image

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)
PROJECT = os.path.join(REVERSING, "ghidra", "project.json")

# generous: walk() only decodes what it can reach, so this bounds runaway rather than
# describing any real function. The largest named one here is about 0x7900 bytes.
EXTENT = 0x8000

CONVENTIONS = ("__thiscall", "__stdcall", "__fastcall", "__cdecl")

# on 32 bit x86 everything on the stack is promoted to a multiple of four
EIGHT = ("__int64", "long long", "double", "unsigned __int64", "int64_t", "uint64_t")


def parameters(signature):
    """the text of each parameter, or None when the parentheses do not parse"""
    # The last `)`, not the end of the string: a signature may carry a trailing `@EAX`
    # or `@AL` saying which register the return value comes back in. Requiring the text
    # to end in `)` read every one of those as unparseable - 22 entries skipped, and a
    # dozen more reported as member functions that never mention their class.
    open_at = signature.find("(")
    close_at = signature.rfind(")")
    if open_at < 0 or close_at < open_at:
        return None
    inner = signature[open_at + 1:close_at].strip()
    if not inner or inner == "void":
        return []

    parts = []
    depth = 0
    current = ""
    for character in inner:
        if character in "<([":
            depth += 1
        elif character in ">)]":
            depth -= 1
        if character == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += character
    if current.strip():
        parts.append(current.strip())
    return parts


# Types the findings use that are not spelled like scalars but take one stack slot. The
# evidence for each is that assuming it unblocks a mass of entries which then *agree*
# with their own `ret` - `SaveToken` is 287 of them, every `LoadKey` in the image, and
# they went from unknown to matching in one step. A wrong guess here would have shown up
# immediately as 287 new disagreements instead.
KNOWN = {
    "savetoken": 4,             # the interned key each LoadKey switches on
    "productioncategory": 4,
    "_locale_t": 4,             # a pointer typedef
    "va_list": 4,               # a char* into the caller's frame
    # 8, from `project.json`'s own struct record - `char tag[4]` then `int id`, size
    # 0x8 - and corroborated by the `int tagChars, int tagId` pairs the findings write
    # wherever one is passed as two words (`CTheatre::CTheatre`,
    # `CSendExpeditionCommand::CSendExpeditionCommand`). It was unsized until
    # 2026-10-02, which skipped 16 entries on this parameter alone; sizing it took the
    # run from 1301 entries checked to 1321, of which 18 agree with their own `ret` and
    # 2 do not - and both of those two spell the tag's `id` half a second time as a
    # trailing `int`. That is the same argument the `SaveToken` row above rests on: a
    # wrong size would have arrived as 20 new disagreements, not 2.
    "ccountrytag": 8,
    # **By value it is 0x1C, and this said 0x18 until 2026-10-02.** The old reading was
    # that the three recorded fields - `char[16]`, `length`, `maxLength` - are the whole
    # object and the 0x1C stride between string members is padding the classes add. They
    # cannot be: that layout has alignment 4, so MSVC inserts nothing between two of
    # them, and four classes put a *named* non-string field at exactly
    # `string + 0x1C` with nothing in the gap - `CMessageVariable` (`key` 0x0,
    # `value` 0x1C, `previous` 0x38, size 0x44), `GuiTooltipText` (0x0, 0x1C, 0x38,
    # then `int number` at 0x54), `CTechnologyCategory` (0x8, 0x24, 0x40, then
    # `int index` at 0x5C) and `CBuilding` (`name` 0x1C, `displayName` 0x38, then
    # `int index` at 0x54). So the type has a fourth 4-byte member at +0x18 - MSVC's
    # `_String_val` keeps its allocator as a data member - and `project.json`'s
    # `Hoi3CString` struct is a field short.
    #
    # **And the decisive case was already written down on the C++ side** (trap 14, the
    # headers are the other half of the fact base): `BiceLib/GameClasses/CTrait.hpp`
    # records `CTrait +0xE8` as a `Hoi3CString[16]` with `EFFECT_TYPE_STRIDE = 0x1C` and
    # checks it as `0xE8 + 16 * 0x1C == 0x2A8`. That is an **array**, not a run of class
    # members, and an array of a type has no padding between its elements - the stride
    # *is* the size. The header's own note, "a string is 0x18 bytes and the stride is
    # 0x1C, so four bytes go spare", describes something an array cannot do.
    #
    # The old 0x18 rested on `CKillLeaderEffect::GetText` and `CLoadOOBEffect::GetText`
    # doing `ret 40` "against a sibling shape of 16", the sibling being
    # `CAndTrigger::GetText`. That subtraction compares two different virtuals - a
    # `CEffect`'s GetText against a `CTrigger`'s - so it never established the 24. Read
    # with 0x1C, each of those two lists carries one invented trailing `int` too many,
    # and `CBuilding::CBuilding`'s `int unread` is the string's own fourth dword.
    #
    # Net effect on the run: `CTerrain::CTerrain` and `AppendStatisticsSample` go from
    # disagreeing to matching exactly, and those three go the other way. Their frames
    # fit either size, which is why the in-class stride is what settles it.
    "hoi3cstring": 0x1C,
}


def parameterBytes(text):
    """how many stack bytes one parameter takes, or None when it cannot be known"""
    if "*" in text or "&" in text:
        return 4
    for word in text.split():
        if word.lower() in KNOWN:
            return KNOWN[word.lower()]
    lowered = " " + text.lower() + " "
    for name in EIGHT:
        if " " + name + " " in lowered or lowered.strip().startswith(name):
            return 8
    # a bare word is a type this cannot size - an enum and a struct by value look alike
    words = [w for w in re.split(r"[\s]+", text.strip()) if w]
    scalars = ("int", "unsigned", "bool", "char", "short", "long", "float", "byte",
               "uint8_t", "int8_t", "uint16_t", "int16_t", "uint32_t", "int32_t",
               "size_t", "dword", "word", "uintptr_t", "intptr_t", "wchar_t")
    for word in words:
        if word.lower().strip("*&") in scalars:
            return 4
    return None


def expected(signature):
    """(bytes the callee should pop, why not) for one signature"""
    convention = None
    for name in CONVENTIONS:
        if name in signature:
            convention = name
            break
    if convention is None:
        return None, "no calling convention in the signature"

    parts = parameters(signature)
    if parts is None:
        return None, "the parameter list does not parse"

    if any(part.strip() == "..." for part in parts):
        if convention == "__cdecl":
            return 0, None
        return None, "variadic, and not __cdecl"

    # Whether the signature places any parameter itself. That changes what the
    # convention's own implicit register assignment is allowed to do, below.
    placed = [part for part in parts if "@" in part]

    if convention == "__thiscall":
        # **The receiver goes in ecx by position, not by being called `this`.** This is
        # Ghidra's own rule - a __thiscall's first parameter is assigned to ecx whatever
        # it is named - and the image agrees: `GuiTypeTree_Find` (rva 0x67DEE0) opens
        # `cmp dword ptr [ecx + 4], 0` and ends `ret 4`, with its signature's first
        # parameter spelled `void* tree`. Matching on the word `this` instead counted
        # seven receivers as stack arguments and predicted a `ret` four bytes too large:
        # `OwnerAreaCost_NoEnemy`, `OwnerAreaCost_Accessible`, `CList::FreeNodes`,
        # `ChecksumFile`, `CNavalCombatant::PickTarget`, `GuiTypeTree_Find` and
        # `GuiTypeTree_FindByString`.
        #
        # A first parameter that places *itself* is the exception and it is a real one:
        # `CPersistent::Load` is `__thiscall` with `(CParseContext* parse@stack:4)` and
        # no receiver spelled at all, so dropping it by position would lose the only
        # argument it has. An `@` on the first parameter wins over the convention.
        if parts and "@" not in parts[0]:
            parts = parts[1:]
    elif convention == "__fastcall" and not placed:
        # Only where the signature places *nothing* does the convention get to assign
        # ecx and edx by itself. Dropping the first two four-byte parameters by size
        # alone swallowed an `out@stack:4` as though it were a register argument, and
        # consumed a bare parameter the author had clearly left on the stack - the
        # findings use `__fastcall` as "register arguments, callee cleans" and then spell
        # the registers out, so once one parameter says where it lives the rest are
        # described by hand. `CMap::CollectCacheStampFiles(CMap* map@ESI, out)` does
        # `ret 4`: the bare `out` is the stack argument, not a second register one.
        taken = 0
        remaining = []
        for part in parts:
            size = parameterBytes(part)
            if taken < 2 and size == 4:
                taken += 1
                continue
            remaining.append(part)
        parts = remaining

    total = 0
    for part in parts:
        # The findings spell a mixed convention out on the parameter: `unit@ESI` travels
        # in a register and costs no stack, `out@stack:4` says where on the stack it
        # sits. Ignoring that reads a register argument as a stack one and predicts a
        # `ret` four bytes too large, which is most of what the first run of this
        # complained about.
        if "@" in part:
            where = part.rsplit("@", 1)[1].strip().lower()
            if not where.startswith("stack"):
                continue
            part = part.rsplit("@", 1)[0].strip()

        size = parameterBytes(part)
        if size is None:
            return None, "cannot size the parameter '%s'" % part
        total += size

    if convention == "__cdecl":
        return 0, None
    return total, None


_classNames = None


def storageComplaint(signature):
    """what is wrong with this signature's storage, or None

    **All or nothing, and the return counts.** Ghidra reads a signature as CUSTOM_STORAGE
    as soon as one parameter says where it lives, and from then on everything needs a
    place: a parameter without one is dropped from the call, and a non-void return without
    one comes back as `undefined4` however it is declared. Neither shows up against the
    `ret`, so this is the only thing that looks for them.
    """
    parts = parameters(signature)
    if parts is None:
        return None

    placed = [p for p in parts if "@" in p]
    if not placed:
        return None                       # no custom storage, nothing to be consistent about
    bare = [p for p in parts if "@" not in p]
    if bare:
        return ("places %d of %d parameters, so the rest have nowhere to live: %s"
                % (len(placed), len(parts), ", ".join(repr(b) for b in bare)))

    # the return's place goes after the parameter list, as `...) @EAX`
    close_at = signature.rfind(")")
    trailer = signature[close_at + 1:].strip()
    returned = signature[:signature.find("(")].strip()
    isVoid = returned.split()[0] == "void" if returned.split() else True
    # a void that is really a pointer return is still void to the caller
    if not isVoid and not trailer.startswith("@"):
        # **Softer than the rule above, because it does not always bite.**
        # CCombatant::PickTarget decompiled as `undefined4` until it was given `) @EAX`;
        # CCountry::GetCategoryBuildDiscount returns an `int*` perfectly well without one.
        # Both place every parameter, so what separates them is not in the signature - so
        # this reports rather than accuses, and the fix is harmless either way.
        return ("MAYBE: returns %s and places its parameters. Some such signatures come back "
                "as undefined4 at every call site until the return is placed too - add "
                "`) @EAX` (or @AL) if it does" % returned.split()[0])
    return None


def isClass(name):
    """whether this qualifier names something with a layout, rather than a namespace"""
    global _classNames
    if _classNames is None:
        _classNames = set(hoi3.classes())
        document = json.load(io.open(PROJECT, encoding="utf-8"))
        _classNames |= {s["name"] for s in document.get("structs", [])}
        # the findings spell std::string as Hoi3CString, so the qualifier `std::string`
        # does name a layout even though nothing is recorded under that spelling
        _classNames.add("std::string")
    return name in _classNames


def carriesClass(name, signature):
    """whether a Class::Method signature actually takes a Class

    The `ret` check cannot see this. A signature can predict the exact right immediate
    and still declare a free function - and then Ghidra gives the method an untyped
    `this`, and every field access through it decompiles as an offset into nothing.

    Three spellings are accepted, all of which appear in the findings and all of which
    are honest: `__thiscall Class::Method(Class* this, ...)`, a `Class*` as the first
    parameter of a __stdcall that takes it on the stack, and a register one like
    `Class* unit@EAX`. What is not accepted is a signature that never mentions the class
    at all.
    """
    klass = name.rsplit("::", 1)[0]
    if not klass or klass == name:
        return True

    # A `::` says qualified, not member. `std::uncaught_exception` and
    # `std::iostream_category` are free functions in a namespace and have no receiver to
    # take, so demanding one of them is asking for a parameter that does not exist. Only
    # a qualifier that names something with a layout - a class from the RTTI, or a struct
    # the findings hold - can be a receiver.
    if not isClass(klass):
        return True

    parts = parameters(signature)
    if not parts:
        # `__thiscall Class::Method(void)` is complete as it stands: the name puts it in
        # the class's namespace and Ghidra supplies a `this` typed from there. It is only
        # the other conventions that have to spell the receiver out.
        return "__thiscall" in signature and "::" in signature
    # a pointer to the class, or to one of its bases, anywhere in the parameters
    family = ancestors(klass) if klass in hoi3.classes() else {klass}
    # The findings spell std::string as Hoi3CString, so a std::string method taking a
    # Hoi3CString* does carry its class - it just does not spell it the same way.
    if klass == "std::string":
        family = family | {"Hoi3CString"}
    for part in parts:
        for base in family:
            if base in part and "*" in part:
                return True
    return False


def ancestors(name, seen=None):
    """a class and everything it derives from"""
    seen = seen if seen is not None else set()
    if name in seen:
        return seen
    seen.add(name)
    for base in (hoi3.classes().get(name) or {}).get("bases") or []:
        ancestors(base["name"], seen)
    return seen


def returns(entry):
    """every distinct immediate on a ret in the function, walking its branches"""
    decoded, _ = cfg.walk(entry, EXTENT)
    found = set()
    for at in sorted(decoded):
        instruction = decoded[at]
        if not instruction.mnemonic.startswith("ret"):
            continue
        if instruction.operands and instruction.operands[0].type == capstone.CS_OP_IMM:
            found.add(instruction.operands[0].imm)
        else:
            found.add(0)
    return found, decoded


def vftables():
    """class name -> the addresses of its own virtual tables"""
    tables = {}
    for name, record in hoi3.classes().items():
        tables[name] = [int(t["address"], 16) for t in record.get("vftables", [])]
    return tables


def checkConstructor(name, decoded, tables):
    """(complaint, skip reason) for an entry named X::X"""
    parts = name.split("::")
    if len(parts) != 2 or parts[0] != parts[1]:
        return None, None
    klass = parts[0]
    if klass not in tables or not tables[klass]:
        return None, "no virtual table recorded for %s" % klass

    written = set()
    for at in sorted(decoded):
        raw = bytes(decoded[at].bytes)
        for other, addresses in tables.items():
            for address in addresses:
                if address.to_bytes(4, "little") in raw:
                    written.add(other)

    if not written:
        return None, "%s writes no virtual table at all" % name
    if klass in written:
        return None, None
    return ("%s writes no table of its own - it writes %s"
            % (name, ", ".join(sorted(written)))), None


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verbose", action="store_true",
        help="also list what was skipped, and why")
    parser.add_argument("--only", help="check one rva")
    parser.add_argument("--candidates", nargs="*", metavar="FILE",
        help="check the addresses of fragment files instead of project.json; with no "
             "path, everything in fragments/incoming")
    arguments = parser.parse_args()

    project = json.load(io.open(PROJECT, encoding="utf-8"))
    tables = vftables()

    entries = project.get("addresses", [])
    if arguments.candidates is not None:
        paths = arguments.candidates or sorted(glob.glob(
            os.path.join(REVERSING, "fragments", "incoming", "*.json")))
        if not paths:
            print("nothing in fragments/incoming")
            return
        entries = []
        for path in paths:
            entries += json.load(io.open(path, encoding="utf-8")).get("addresses", [])
        print("%d address%s from %d fragment file%s: %s"
              % (len(entries), "" if len(entries) == 1 else "es", len(paths),
                 "" if len(paths) == 1 else "s",
                 ", ".join(os.path.basename(p) for p in paths)))

    wrong = []
    constructors = []
    unsigned = []
    freeFloating = []
    storage = []
    skipped = []
    checked = 0

    for record in entries:
        if record.get("kind") != "function":
            continue
        rva = str(record.get("rva") or "")
        if arguments.only and int(rva, 16) != int(arguments.only, 16):
            continue
        name = record.get("name") or "?"
        signature = record.get("signature") or ""
        entry = image.toVa(int(rva, 16))

        want, why = (None, "no signature") if not signature else expected(signature)

        # A member function has to say so. Checked before the ret, because a function
        # with no signature at all fails this whether or not the ret agrees.
        if record.get("kind") == "function" and "::" in name:
            if not signature:
                unsigned.append((rva, name, record.get("no_signature") or ""))
            elif not carriesClass(name, signature):
                freeFloating.append((rva, name, signature))

        # Independent of the class check, and of the ret: this is about where the
        # arguments live rather than how many of them there are.
        if signature:
            complaint = storageComplaint(signature)
            if complaint:
                storage.append((rva, name, complaint, signature))

        # An address that is not a function start makes the walk meaningless: it begins
        # inside somebody else's body and reports whatever `ret` it reaches first. That is
        # worth saying next to a disagreement, but only as a hint, because the test for it
        # is weak. `functionStart` walks backwards looking for a prologue, and a function
        # like `CBombRunwayOrder::GetTypeId` - `mov eax, N; ret`, no prologue, one of a
        # row of them - has nothing to stop the walk, so it runs into its neighbour and
        # reports a start that is not its own. Gating on this hid 97 entries, against the
        # 8 that buildFindings actually rejects.
        #
        # **And it is noisy in the one direction trap 2 describes.** All five entries it
        # flagged on 2026-10-02 - `ConcurrentQueue_TryPop`, `CSpyPresence::RunTechEspionage`,
        # `CCountry::CollectCountriesWeCanOperateIn`, `FindRebelFactionForProvince` and
        # `CGoodsPool::ClampEach` - open `55 8b ec` with a `ret` tail (`c3`, or `c2 N 00`)
        # in the bytes immediately before, so each is a real boundary that `functionStart`
        # walked past because the previous function abuts it with no `int3` at all. The
        # genuine case looks different: rva 0x450AB0 is `e8` - a `call` - with no `ret`
        # between it and the candidate, and it really does sit mid-function.
        #
        # So the hint now needs both halves: a `ret` in between *and* a prologue byte at
        # the entry means abutment, and nothing is said.
        hint = ""
        try:
            start = image.functionStart(entry)
            if start is not None and start != entry:
                abutting = bool(image.retsBefore(start, entry)) and \
                    image.read(entry, 1)[0] in (0x55, 0x53, 0x56, 0x57, 0x8B, 0x83,
                                                0x81, 0x6A, 0x68, 0x51, 0x52, 0x50, 0x80)
                if not abutting:
                    hint = "   (may not be a function start: %s looks like the start)" \
                           % image.both(start)
        except Exception:
            pass

        try:
            found, decoded = returns(entry)
        except Exception as problem:               # a bad address should not stop the run
            skipped.append((rva, name, "could not be walked: %s" % problem))
            continue

        complaint, reason = checkConstructor(name, decoded, tables)
        if complaint:
            constructors.append((rva, name, complaint))
        elif reason and arguments.verbose:
            skipped.append((rva, name, reason))

        if want is None:
            if arguments.verbose:
                skipped.append((rva, name, why))
            continue
        if not found:
            skipped.append((rva, name, "no ret reached - a tail jmp, or it does not "
                                       "return"))
            continue
        if len(found) > 1:
            skipped.append((rva, name, "rets disagree with each other: %s"
                            % ", ".join(str(v) for v in sorted(found))))
            continue

        checked += 1
        actual = found.pop()
        if actual != want:
            wrong.append((rva, name, signature, want, actual, hint))

    print("%d entries checked against their ret" % checked)

    if wrong:
        print("")
        print("%d disagree with the executable:" % len(wrong))
        for rva, name, signature, want, actual, hint in wrong:
            print("   %-10s %s" % (rva, name))
            print("      %s" % signature)
            print("      signature wants ret %d, the function does ret %d%s"
                  % (want, actual, hint))
    else:
        print("   none disagree")

    if freeFloating:
        print("")
        print("%d member functions whose signature never mentions their class:"
              % len(freeFloating))
        for rva, name, signature in freeFloating:
            print("   %-10s %s" % (rva, name))
            print("      %s" % signature)

    if storage:
        print("")
        broken = [x for x in storage if not x[2].startswith("MAYBE")]
        print("%d signatures whose custom storage is incomplete (%d certainly wrong):"
              % (len(storage), len(broken)))
        for rva, name, complaint, signature in storage:
            print("   %-10s %s" % (rva, name))
            print("      %s" % complaint)
            print("      %s" % signature)

    if unsigned:
        print("")
        print("%d member functions with no signature at all:" % len(unsigned))
        for rva, name, why in unsigned:
            print("   %-10s %-44s %s" % (rva, name[:44], why[:60] or "and no reason given"))

    if constructors:
        print("")
        print("%d constructors write another class's table:" % len(constructors))
        for rva, name, complaint in constructors:
            print("   %-10s %s" % (rva, complaint))

    if skipped:
        print("")
        print("%d skipped%s" % (len(skipped), ":" if arguments.verbose else
                                " - run with --verbose to see why"))
        if arguments.verbose:
            for rva, name, reason in skipped:
                print("   %-10s %-44s %s" % (rva, name[:44], reason))


if __name__ == "__main__":
    main()
