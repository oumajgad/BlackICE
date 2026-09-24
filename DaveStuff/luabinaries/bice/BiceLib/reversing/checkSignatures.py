"""Checks what `project.json` claims about a function against what the function does.

    python checkSignatures.py                  everything, summarised
    python checkSignatures.py --verbose        and say why each one was skipped
    python checkSignatures.py --only 0x67B250  one entry

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
import io
import json
import os
import re

import capstone

import cfg
import hoi3
import image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.join(HERE, "ghidra", "project.json")

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

    if convention == "__thiscall":
        # `this` travels in ecx. It is written out as a parameter here by convention, so
        # drop it when it is named that and count everything otherwise - both spellings
        # appear in the findings and each is right about its own entry.
        if parts and re.search(r"\bthis\b", parts[0]):
            parts = parts[1:]
    elif convention == "__fastcall":
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
    arguments = parser.parse_args()

    project = json.load(io.open(PROJECT, encoding="utf-8"))
    tables = vftables()

    wrong = []
    constructors = []
    unsigned = []
    freeFloating = []
    skipped = []
    checked = 0

    for record in project.get("addresses", []):
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

        # An address that is not a function start makes the walk meaningless: it begins
        # inside somebody else's body and reports whatever `ret` it reaches first. That is
        # worth saying next to a disagreement, but only as a hint, because the test for it
        # is weak. `functionStart` walks backwards looking for a prologue, and a function
        # like `CBombRunwayOrder::GetTypeId` - `mov eax, N; ret`, no prologue, one of a
        # row of them - has nothing to stop the walk, so it runs into its neighbour and
        # reports a start that is not its own. Gating on this hid 97 entries, against the
        # 8 that buildFindings actually rejects.
        hint = ""
        try:
            start = image.functionStart(entry)
            if start is not None and start != entry:
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
