# -*- coding: utf-8 -*-
r"""Every class `CTrigger::LoadKey` builds, with the size of its allocation.

    python scripts/triggersizes.py                      all 157, one per line
    python scripts/triggersizes.py --sizes              the distribution as well
    python scripts/triggersizes.py --class CDissentTrigger

**Why this exists.** A trigger leaf's own data starts at `+0x40`, and whether a leaf has
one field there or two is the difference between a `size` that can be declared and one
that must be omitted - a declared size is authoritative *downward* in Ghidra, so guessing
`0x44` silently drops whatever Ghidra holds past it. The allocation is the only honest
answer, and `CTrigger::LoadKey` has one per keyword.

Every arm of that switch that makes a leaf does the same four things:

    push <size>            ; the object's size, as an immediate
    call operator_new
    push eax
    call <constructor>     ; **not** inlined

so the size is readable straight off the immediate, and the class is readable out of the
constructor, which stores its own vftable - and the RTTI export maps a vftable address to
a class name for free.

Three things that each cost time here:

  * **The last vftable store wins.** A derived constructor has its base's inlined ahead of
    it, so the body stores `CTrigger`'s vftable first and its own over the top. Taking the
    first match answers `CTrigger` for all 157.
  * **capstone stops silently** (trap 9's third form): `disasm` halts at the first byte it
    cannot decode and returns what it had, with no error and no marker. This resumes one
    byte past every stop. Over `CTrigger::LoadKey` that is one resume; without it the
    sweep ends early and the short answer looks healthy.
  * **The function's extent is read off its `ret`, not guessed** - 0x5C8D10 to the single
    `ret 8` at 0x5CAFA2 - because the trigger constructors sit immediately below it and a
    longer window picks their allocations up as if they were LoadKey's.

Addresses printed are **rvas** against an image base of 0x400000 (trap 1). The constants
below are VAs, as everything `image.py` takes is.

The distribution, 2026-10-06: `0x44` x111, `0x48` x16, `0x40` x10, `0x5C` x9, `0x4C` x5,
`0x60` x2, and one each of `0x10`, `0x50`, `0x64`, `0x150`. So **a leaf that is not 0x44
has a second field**, and there are 46 of them.

**Two of the 157 pairs print `None`, and they are honest misses rather than unnamed
classes**: for those two arms the `call` immediately after `operator_new` is not a
constructor at all but a helper that takes the fresh object - `std::string::fromCString`
(rva 0x65A7A0, the `0x60` one) and the unrecorded `0x12A710` (the `0x10` one, the by-name
region lookup on `CMap +0x2A50`). Neither allocation is a trigger, so neither size belongs
to this family. Read a `None` as "look at that arm by hand", not as "a class with no RTTI".
"""

import argparse
import collections
import sys

import capstone

import hoi3
import image

LOADKEY = 0x9C8D10          # VA; rva 0x5C8D10, CTrigger::LoadKey
LOADKEY_LENGTH = 0x2296     # to the single `ret 8` at rva 0x5CAFA2
OPERATOR_NEW = 0xB9602F     # VA; rva 0x79602F, recorded as operator_new
IMAGE_BASE = 0x400000


def decodeAll(start, length):
    """every instruction in [start, start + length), resuming past each silent stop"""
    blob = image.read(start, length)
    engine = image.engine()
    out = []
    offset = 0
    resumes = 0
    while offset < length:
        got = list(engine.disasm(blob[offset:], start + offset))
        if got:
            out.extend(got)
            last = got[-1]
            offset = (last.address - start) + last.size
        else:
            offset += 1
            resumes += 1
    return out, resumes


def vftables():
    """vftable VA -> (class name, object offset), out of the RTTI export"""
    table = {}
    for name, record in hoi3.classes().items():
        for vft in record.get("vftables") or []:
            table[int(vft["address"], 16)] = (name, vft["object_offset"])
    return table


def constructorClass(entry, byVftable, limit=0x200):
    """the class a constructor at this VA builds - the **last** vftable it stores"""
    body, _ = decodeAll(entry, limit)
    answer = (None, None)
    for insn in body:
        if insn.mnemonic.startswith("ret"):
            break
        if insn.mnemonic != "mov":
            continue
        ops = insn.operands
        if len(ops) != 2 or ops[0].type != capstone.x86.X86_OP_MEM:
            continue
        if ops[1].type != capstone.x86.X86_OP_IMM:          # trap 17: IMM is 2
            continue
        hit = byVftable.get(ops[1].imm)
        if hit and ops[0].mem.disp == hit[1]:
            answer = (hit[0], insn.address)
    return answer


def built():
    """[(class or None, size, constructor VA, push VA, vftable store VA)] in switch order"""
    byVftable = vftables()
    body, resumes = decodeAll(LOADKEY, LOADKEY_LENGTH)
    print("# CTrigger::LoadKey rva 0x%X, %d instructions, %d capstone resumes"
          % (LOADKEY - IMAGE_BASE, len(body), resumes), file=sys.stderr)
    pending = None
    waiting = None
    found = []
    for insn in body:
        ops = insn.operands
        if insn.mnemonic == "push" and ops and ops[0].type == capstone.x86.X86_OP_IMM:
            pending = (ops[0].imm, insn.address)
            continue
        if insn.mnemonic != "call" or not ops or ops[0].type != capstone.x86.X86_OP_IMM:
            continue
        target = ops[0].imm
        if target == OPERATOR_NEW:
            waiting = pending
            continue
        if waiting:
            size, at = waiting
            name, storedAt = constructorClass(target, byVftable)
            found.append((name, size, target, at, storedAt))
            waiting = None
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sizes", action="store_true", help="print the distribution too")
    parser.add_argument("--class", dest="klass", help="one class only")
    args = parser.parse_args()

    found = built()
    for name, size, ctor, at, storedAt in found:
        if args.klass and name != args.klass:
            continue
        print("%-36s 0x%-5X ctor rva 0x%-8X push at rva 0x%-8X vftable store rva %s"
              % (name, size, ctor - IMAGE_BASE, at - IMAGE_BASE,
                 ("0x%X" % (storedAt - IMAGE_BASE)) if storedAt else "-"))
    if args.sizes:
        print()
        for size, n in sorted(collections.Counter(s for _, s, _, _, _ in found).items()):
            print("0x%-5X %d" % (size, n))
    unnamed = [f for f in found if f[0] is None]
    print("# %d new/constructor pairs, %d distinct classes, %d whose constructor stores no "
          "known vftable" % (len(found), len({f[0] for f in found if f[0]}), len(unnamed)),
          file=sys.stderr)


if __name__ == "__main__":
    main()
