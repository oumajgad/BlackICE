"""Every keyword a dispatching loader knows, and the class each one builds.

    python switchmap.py 0x999CA0            # CEffect::LoadKey
    python switchmap.py 0x9C8D10 --md       # CTrigger::LoadKey, as a markdown table

`CTrigger::LoadKey` and `CEffect::LoadKey` are each one switch over the save tokens with a
case per keyword of the event script language, and each case builds the class that
implements it. Reading the switch is therefore the whole keyword list, exactly.

**Do not parse the decompiler's C for this.** It renders part of a switch this wide as
nested ifs and puts cases into shapes a regex misses - a first attempt at CEffect found 77
of its 86 keywords and silently dropped `kill_leader`. The switch itself cannot lie.

MSVC compiles one as a binary tree of comparisons whose leaves are either a single token

    cmp eax, K / jg elsewhere / je target
    cmp eax, K / jne default            (the body is the fall-through, not the target)

or a run of them through a pair of tables

    sub eax, base / cmp eax, n / ja default /
    movzx ecx, byte ptr [eax + byteTable] / jmp dword ptr [ecx*4 + jumpTable]

where the base may be applied with `lea eax, [edi - base]` instead of `sub`, and the byte
table is left out entirely when the run is short enough that no two tokens share a case.

Two things to get right. **The default has to be dropped**: the byte table sends every
token in the gaps to it, so keeping it makes hundreds of tokens look like cases and gives
them all the default's class. And the case body's class is the **last** vftable it writes,
because a derived constructor lets its base write first - taking the first names every
trigger `CTrigger`.

**A few low-numbered cases can be spurious.** The subtract-and-test reader tracks what
eax would have had to hold, and on a path where eax was loaded from something other than
the token it invents a case - on `CTechStatistics::LoadKey` that produced `fontName`
(token 33), token 19 and `}` among 47, where 44 are real. Sanity-check any keyword that
makes no sense for the loader you are reading; the jump-table cases, which are most of
them, cannot be wrong this way.

Addresses are absolute, the way the RTTI export writes them. Token ids only become
keywords in a running game, so this reads the live table through saveTokens.py; without a
game it falls back to the compiled ones and the dynamic keywords go unnamed.
"""

import argparse
import collections
import json
import os
import sys

import capstone

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ghidra"))
import luabindExtract as LX
import saveTokens

img = LX.Image(LX.EXE)
VFTABLES = {}
for _name, _record in LX.load_rtti().items():
    for _table in _record.get("vftables") or []:
        VFTABLES[int(_table["address"], 16)] = _name

engine = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
engine.detail = True

ALLOCATOR = 0x00B9602F      # operator new, which a case calls before its constructor
IMM = capstone.x86.X86_OP_IMM
MEM = capstone.x86.X86_OP_MEM
REG = capstone.x86.X86_OP_REG


def instructions(start, length):
    return list(engine.disasm(img.read(start, length), start))


def functionEnd(start, limit=0x3000):
    data = img.read(start, limit)
    at = data.find(b"\xcc\xcc\xcc\xcc")
    return start + (at if at > 0 else limit)


def classAt(address, depth=0, seen=None):
    """The class the code at `address` builds: the last vftable it writes."""
    seen = set() if seen is None else seen
    if depth > 3 or address in seen:
        return None
    seen.add(address)
    found, calls = None, []
    for insn in instructions(address, 0x300):
        if insn.mnemonic in ("mov", "push"):
            for operand in insn.operands:
                if operand.type == IMM and (operand.imm & 0xFFFFFFFF) in VFTABLES:
                    found = VFTABLES[operand.imm & 0xFFFFFFFF]
        if insn.mnemonic == "call" and insn.operands[0].type == IMM:
            if insn.operands[0].imm != ALLOCATOR:
                calls.append(insn.operands[0].imm)
        if insn.mnemonic in ("ret", "jmp"):
            break
    if found:
        return found
    for target in calls:
        deeper = classAt(target, depth + 1, seen)
        if deeper:
            return deeper
    return None


def keySlot(code):
    """
    Where a loader keeps the key, when it keeps it on the stack rather than in a register.

    `CCountryHistory::LoadEntry` takes its key as the fourth argument and never loads it
    into a register to test it - the whole tree is `cmp dword ptr [ebp - 0x67c], 0x1f9`.
    Reading only register compares misses every one of those, which is how `capital`,
    `government` and `ideology` came to look as though the handler did not know them.

    One slot is compared far more than any other, and that is the key; anything else at
    that address is a local the tree happens to touch.
    """
    counts = collections.Counter()
    for index, insn in enumerate(code):
        if (insn.mnemonic == "cmp" and insn.operands[0].type == MEM
                and insn.operands[1].type == IMM
                and index + 2 < len(code)
                and any(code[index + k].mnemonic in ("je", "jg", "ja")
                        for k in (1, 2))):
            counts[(insn.operands[0].mem.base, insn.operands[0].mem.disp)] += 1
    if not counts:
        return None
    slot, seen = counts.most_common(1)[0]
    return slot if seen >= 3 else None


def cases(start):
    """token -> where its case body begins, with the default branch left out."""
    end = functionEnd(start)
    code = instructions(start, end - start)
    out, defaults = {}, set()
    running = {}
    slot = keySlot(code)
    keyRegister = None

    for index, insn in enumerate(code):
        # A run of tokens through a jump table. The scaled index sits in whichever
        # register the compiler chose - CEffect uses eax, CTrigger ecx.
        if (insn.mnemonic == "jmp" and insn.operands[0].type == MEM
                and insn.operands[0].mem.scale == 4 and insn.operands[0].mem.base == 0):
            jumpTable = insn.operands[0].mem.disp & 0xFFFFFFFF
            indexRegister = insn.operands[0].mem.index
            byteTable = count = base = fallback = None
            for other in code[max(0, index - 8):index]:
                if (other.mnemonic == "movzx" and other.operands[0].reg == indexRegister
                        and other.operands[1].type == MEM):
                    byteTable = other.operands[1].mem.disp & 0xFFFFFFFF
                elif other.mnemonic == "cmp" and other.operands[1].type == IMM:
                    count = other.operands[1].imm
                elif other.mnemonic in ("add", "sub") and other.operands[1].type == IMM:
                    value = other.operands[1].imm & 0xFFFFFFFF
                    base = (0x100000000 - value) if other.mnemonic == "add" else value
                elif (other.mnemonic == "lea" and other.operands[1].type == MEM
                      and other.operands[1].mem.index == 0):
                    # `lea eax, [edi - 0x78d]` does the same job as `sub` without touching
                    # the register the token arrived in. CCasusBelliType::LoadKey writes it
                    # this way, and missing it loses that loader's whole jump table - 19 of
                    # its 24 keys.
                    base = -other.operands[1].mem.disp & 0xFFFFFFFF
                elif other.mnemonic in ("ja", "jae"):
                    # **Unsigned only.** A switch's bounds check is always unsigned, because
                    # the compiler leans on wraparound to catch tokens below the base; the
                    # signed `jg` and `jge` belong to the comparison tree around it. Taking
                    # those as the default marked real case bodies as unreachable and threw
                    # away CCountryHistory's `decision` and `government_in_exile`.
                    fallback = other.operands[0].imm
            # Without a byte table there is nothing to confirm the site was read right,
            # so only a short run is trusted: the compiler reaches for a byte table
            # precisely when the run is long or sparse, and a "direct" table of a hundred
            # entries is a misreading. Allowing them cost CCountryHistory `decision` and
            # `government_in_exile`, which a later comparison would have named correctly.
            if count is not None and base is not None                     and (byteTable or count <= 32) and count < 0x400:
                # A byte table only pays for itself when several tokens share a case. Where
                # the run is short the compiler indexes the jump table straight off the
                # adjusted token - `jmp dword ptr [eax*4 + table]` with no `movzx` - and
                # requiring the byte table misses those whole.
                #
                # **Every target has to land inside this function.** Without the byte table
                # there is nothing else to say the site was read correctly, and a
                # misreading writes bogus cases that `setdefault` then locks in ahead of
                # the real ones: it cost CCountryHistory two of its keys before this check
                # went in. If any target is out of range the whole site is dropped.
                targets = []
                for k in range(count + 1):
                    # Not `slot`: that name holds the stack slot the key is compared in,
                    # and shadowing it here made every later memory compare fail to match,
                    # which is how CCountryHistory lost two keys that were plainly there.
                    where = img.read(byteTable + k, 1)[0] if byteTable else k
                    targets.append(img.u32(jumpTable + where * 4))
                inside = [start <= target < end for target in targets]
                # Most targets landing inside is what says the site was read right; a case
                # may still tail-jump out of the function, so those are dropped one at a
                # time rather than taking the whole table with them.
                if sum(inside) >= max(1, int(len(targets) * 0.8)):
                    if fallback:
                        defaults.add(fallback)
                    for k, target in enumerate(targets):
                        if inside[k]:
                            out.setdefault(base + k, target)

        # A single token, compared either in a register or in the key's stack slot. The
        # `je` is not always the next instruction: the tree writes `cmp K / jg elsewhere /
        # je target`, and looking only one ahead loses those.
        isKey = (insn.mnemonic == "cmp" and insn.operands[1].type == IMM
                 and (insn.operands[0].type == REG
                      or (slot is not None and insn.operands[0].type == MEM
                          and (insn.operands[0].mem.base,
                               insn.operands[0].mem.disp) == slot)))
        if isKey:
            for step in (1, 2):
                if index + step >= len(code):
                    break
                following = code[index + step]
                if following.mnemonic == "je":
                    out.setdefault(insn.operands[1].imm, following.operands[0].imm)
                    break
                # `cmp K / jne default` is the same case written the other way round:
                # the body is what follows, not what is jumped to.
                if following.mnemonic == "jne" and index + step + 1 < len(code):
                    # **The jump is not the default.** `cmp K / jne X` only says "not this
                    # one"; X is usually the next test in the tree, and marking it as the
                    # default deletes whatever case begins there - it cost CCountryHistory
                    # `decision` and `government_in_exile`. Only the jump table's `ja`
                    # names a real default.
                    out.setdefault(insn.operands[1].imm, code[index + step + 1].address)
                    break

        # A subtract-and-test chain, which is how the tree spends its last few tokens:
        #   sub edi, 0x674 / je threat / sub edi, 0x2e / je always
        # Each step leaves the register at zero for one token more, so tracking what it
        # must have held names them. **It is not always eax**: CCasusBelliType::LoadKey
        # runs its chain in edi, and watching only eax loses those keys. Anything else
        # written to a register gives up on it rather than guess.
        if insn.operands and insn.operands[0].type == REG:
            target = insn.operands[0].reg
            if insn.mnemonic == "mov" and insn.op_str.endswith("[ebp + 0xc]"):
                running[target] = 0
                keyRegister = target
            elif insn.mnemonic == "mov" and insn.operands[1].type == REG:
                source = running.get(insn.operands[1].reg)
                running[target] = source
            elif insn.mnemonic == "sub" and insn.operands[1].type == IMM:
                if running.get(target) is not None:
                    running[target] += insn.operands[1].imm
            elif insn.mnemonic == "add" and insn.operands[1].type == IMM:
                if running.get(target) is not None:
                    running[target] -= insn.operands[1].imm
            elif insn.mnemonic == "dec":
                if running.get(target) is not None:
                    running[target] += 1
            elif insn.mnemonic not in ("cmp", "test"):
                running[target] = None
        # **A case body is not on the path the tree is on.** Walking the function from end
        # to end runs straight through bodies that `pop edi` before returning, which loses
        # the key register for every comparison after the first one - in
        # CCasusBelliType::LoadKey that hid `threat` and `always`. A `ret` ends a path, so
        # whatever follows is reached from the tree again with the key still in place.
        if insn.mnemonic == "ret" and keyRegister is not None:
            running[keyRegister] = 0

        if index and code[index - 1].mnemonic in ("sub", "dec", "add") \
                and code[index - 1].operands and code[index - 1].operands[0].type == REG:
            token = running.get(code[index - 1].operands[0].reg)
            if token is not None:
                if insn.mnemonic == "je":
                    out.setdefault(token, insn.operands[0].imm)
                # The chain's last step is written as a `jne` to the default, which leaves
                # the case body as the fall-through - `sub eax, 0x2b1 / je / dec eax / jne
                # out` in CCombatTactic::LoadKey, where the body after the jne is 0x2b2.
                # Missing it loses one key per chain, and it is always the last one.
                elif insn.mnemonic == "jne" and index + 1 < len(code):
                    out.setdefault(token, code[index + 1].address)

    return {token: target for token, target in out.items() if target not in defaults}


def tokenNames():
    try:
        return {int(k): v for k, v in saveTokens.live().items()}
    except Exception as problem:
        print("# no running game (%s), falling back to the compiled tokens" % problem,
              file=sys.stderr)
        here = os.path.dirname(os.path.abspath(__file__))
        with open(os.path.join(here, "ghidra", "saveTokens.json"), encoding="utf-8") as f:
            return {int(k): v for k, v in json.load(f).items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("address", help="the loader, absolute (0x999CA0)")
    parser.add_argument("--md", action="store_true", help="a markdown table instead")
    args = parser.parse_args()

    names = tokenNames()
    rows = []
    for token, target in sorted(cases(int(args.address, 16)).items()):
        rows.append((names.get(token), token, target, classAt(target)))
    good = sorted(r for r in rows if r[0] and r[3])

    if args.md:
        print("| keyword | token | class |")
        print("| --- | --- | --- |")
        for name, token, _target, klass in good:
            print("| `%s` | %d | `%s` |" % (name, token, klass))
    else:
        print("%-36s %-7s %s" % ("keyword", "token", "class"))
        for name, token, _target, klass in good:
            print("%-36s %-7d %s" % (name, token, klass))

    print("\n%d cases, %d with both a keyword and a class" % (len(rows), len(good)),
          file=sys.stderr)
    for label, subset in (("whose token the table does not name",
                           [r[1] for r in rows if not r[0] and r[3]]),
                          ("that build no object of their own",
                           [r[0] for r in rows if r[0] and not r[3]])):
        if subset:
            print("%d cases %s: %s" % (len(subset), label, subset[:14]), file=sys.stderr)
    duplicates = collections.Counter(r[3] for r in good)
    many = sorted((c, n) for c, n in duplicates.items() if n > 1)
    if many:
        print("classes reached by more than one keyword: %s" % many, file=sys.stderr)


if __name__ == "__main__":
    main()
