"""Which field each key of a loader lands in.

    python fieldmap.py 0x79A90              # CWarGoal::LoadKey
    python fieldmap.py CWarGoal             # the same, by class
    python fieldmap.py --all                # every loader, as markdown

`switchmap.py` reads a loader's switch and gives the **grammar** - every key a save block
or a `common/` file may contain. That says nothing about where any of it lands, which is
the difference between a class marked `keys` and one marked `read` in PROGRESS.md.

This walks each case body and records **every store to the object**, so a grammar becomes
a layout. The object arrives in `ecx` and every loader immediately parks it in a register
of its own - `mov edi, ecx` - so the stores read `mov [edi + 0x10], eax`. Following that
register through the body is the whole trick.

What comes out, for `CWarGoal`:

    country          0x24D   +0x10 dword, +0x14 dword     an object id pair
    casus_belli      0xC2    +0x8  dword

**A store is evidence, not proof.** Three things it can be other than the field:

- **A temporary.** A body that builds something on the stack first stores to `ebp - N`;
  those are dropped here, only stores through the object register are kept.
- **A sub-object.** `add ecx, 8` then a call means the key belongs to whatever lives at
  `+8`, not to a field of its own - it shows as a call target rather than a width.
- **A base class.** A loader that hands the key to its base stores nothing itself.

So the widths are read from the instruction - `mov` of a dword, `mov byte`, `movsd` of a
double - and the *meaning* still has to come from the key's name and from what a live
object holds there. `dumpStruct.py` against a running game is what settles it.
"""

import argparse
import collections
import os
import sys

import capstone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "ghidra"))
import switchmap
import hoi3

IMM = capstone.x86.X86_OP_IMM
MEM = capstone.x86.X86_OP_MEM
REG = capstone.x86.X86_OP_REG

WIDTH = {1: "byte", 2: "word", 4: "dword", 8: "qword"}


def objectRegister(code):
    """The register the loader parks `this` in, from the opening `mov <reg>, ecx`.

    The window is the prologue and a little after it. These run long - an SEH frame, a
    big `sub esp`, then the callee-saved pushes - and CCombatant parks `this` past the
    twelfth instruction, so a window that is too tight silently answers `ecx` and the
    whole class comes back with nothing placed.
    """
    for ins in code[:20]:
        if ins.mnemonic == "mov" and len(ins.operands) == 2:
            dst, src = ins.operands
            if (dst.type == REG and src.type == REG
                    and ins.reg_name(src.reg) == "ecx"
                    and ins.reg_name(dst.reg) not in ("ecx",)):
                return ins.reg_name(dst.reg)
    return "ecx"


STORE = ("mov", "movsd", "movss", "movsx", "movzx", "fstp", "or", "and", "add", "sub")


def storesIn(body, end, register):
    """Where one case body puts its value, as (offset, width, how).

    Two shapes, and the second is the commoner one in the big loaders:

    - a **store**, `mov [ebx + 0xbd4], eax` - the field is a number or a pointer;
    - a **field address handed to a reader**, `lea edi, [ebx + 0xbcc]` then a call - the
      field is a string, a list or a sub-object that knows how to read itself.

    Both say the key lands at that offset, so both are kept and the shape is recorded.
    """
    found = []
    stop = min(end, body + 0x300)
    code = switchmap.instructions(body, stop - body)
    live = {register}
    for ins in code:
        if ins.mnemonic == "ret":
            break
        # A body ends where it *leaves*. Running on past that reads the next case's
        # stores as this one's - three unrelated keys of CCountry all claimed +0xa4,
        # and several keys sharing one offset is the giveaway. But a jump within the
        # body is just control flow: CWarGoal's `country` case jumps around an
        # allocation and stores afterwards, so only an outward jump counts.
        if ins.mnemonic == "jmp":
            target = ins.operands[0].imm if ins.operands[0].type == IMM else None
            if target is None or not (body <= target < stop):
                break
            continue
        ops = ins.operands
        # A copy of the object pointer is the object pointer too.
        if ins.mnemonic == "mov" and len(ops) == 2:
            dst, src = ops
            if dst.type == REG and src.type == REG and ins.reg_name(src.reg) in live:
                live.add(ins.reg_name(dst.reg))
            elif dst.type == REG and ins.reg_name(dst.reg) in live:
                live.discard(ins.reg_name(dst.reg))    # clobbered, no longer the object
        # `lea <reg>, [object + N]` - the address of a field, about to be read into.
        if ins.mnemonic == "lea" and len(ops) == 2 and ops[1].type == MEM:
            mem = ops[1].mem
            base = ins.reg_name(mem.base) if mem.base else None
            if base in live and mem.index == 0 and 0 < mem.disp < 0x4000:
                found.append((mem.disp, "read into", "lea"))
            continue
        if ins.mnemonic not in STORE or not ops or ops[0].type != MEM:
            continue
        mem = ops[0].mem
        base = ins.reg_name(mem.base) if mem.base else None
        if base not in live or mem.index != 0 or mem.disp < 0:
            continue
        size = ops[0].size
        if ins.mnemonic == "fstp":
            size = 8
        found.append((mem.disp, WIDTH.get(size, "%d bytes" % size), ins.mnemonic))
    return found


def fields(loader):
    """key token -> the stores its case body makes."""
    end = switchmap.functionEnd(loader)
    code = switchmap.instructions(loader, end - loader)
    register = objectRegister(code)
    found = switchmap.cases(loader)
    starts = sorted(set(found.values()))
    out = {}
    for token, body in found.items():
        # A case body reaches at most to the next one. Several cases can share a body,
        # so the bound is the next *distinct* start.
        after = [s for s in starts if s > body]
        out[token] = storesIn(body, min(after[0], end) if after else end, register)
    return out, register


def describe(loader, names):
    out, register = fields(loader)
    rows = []
    for token, stores in sorted(out.items(),
                                key=lambda kv: (kv[1][0][0] if kv[1] else 1 << 30,
                                                names.get(kv[0], ""))):
        name = names.get(token, "?")
        if not stores:
            rows.append((name, token, None, "nothing - a base class, or a call that "
                                            "keeps the value elsewhere"))
            continue
        seen, parts = set(), []
        for offset, width, how in stores:
            if offset in seen:
                continue
            seen.add(offset)
            parts.append("+%#x %s" % (offset, width))
        rows.append((name, token, stores[0][0], ", ".join(parts[:4])))
    return rows, register


def writeAll(entries, names):
    """FINDINGS-fieldmap.md: every loader whose case bodies store somewhere."""
    done = []
    for owner, loader, shared, keywords in entries:
        try:
            rows, register = describe(loader + 0x400000, names)
        except Exception:
            continue
        placed = [r for r in rows if r[2] is not None]
        if placed:
            done.append((owner, loader, shared, rows, placed))
    done.sort(key=lambda d: (-len(d[4]), d[0]["name"]))

    print("# Which field each key lands in")
    print()
    print("**Generated by `fieldmap.py --all`.** `FINDINGS-definitions.md` says which keys")
    print("a loader accepts; this says where each one is kept, read out of the stores its")
    print("case body makes. That is the step from a class marked `keys` to one marked")
    print("`read` in PROGRESS.md.")
    print()
    print("**A store is evidence, not proof** - the head of `fieldmap.py` lists the three")
    print("things it can be instead of the field, and `dumpStruct.py` against a running")
    print("game is what settles any that matters.")
    print()
    print("**%d loaders place at least one key.**" % len(done))
    print()
    print("## Numbers are fixed point, scaled by 1000")
    print()
    print("**Read this before calling any numeric field wrong.** A HoI3 number that the")
    print("save writes with three decimals is held in memory as an `int` of thousandths.")
    print("`CCountry.officers` reads **237964731** where the savegame says")
    print("`officers=238282.966`. That is not a pointer and not a float - it is")
    print("237964.731, and the two differ only because the game ran on past the autosave.")
    print()
    print("This cost an hour. The field was called *unresolved* here on the grounds that")
    print("237964731 \"is no officer count as an int, a float or a double\" - which was")
    print("true, and beside the point, because nobody had tried dividing by 1000. When a")
    print("field looks like garbage, **check it against a savegame** before doubting the")
    print("offset: the save is plain text, every country is in it, and it names the value.")
    print()
    print("## What was checked against a running game")
    print()
    print("Read back out of a live 1941 game on 2026-09-20 and, where the save has the")
    print("same key, against `autosave_timed.hoi3` as well.")
    print()
    print("- **`CCountry` `major` at `+0x15c`** is set on **exactly 7 of the 108**")
    print("  countries. That is the seven majors, and it is the strongest single check")
    print("  here - a wrong offset could not land on that number.")
    print("- **`CCountry` `officers` at `+0xc4`**, thousandths, checked against the save")
    print("  for ten countries: GER 237964.731 against 238282.966, SOV 387840.935")
    print("  against 389189.167, USA 536020.642 against 535812.762, DEN 2773.575 against")
    print("  2752.207. Every one within a fraction of a percent.")
    print("- **`CCountry` `convoys` `+0xb0` and `escorts` `+0xb4`** are plain ints and")
    print("  match the save exactly - USA 924 convoys and 175 escorts, FIN 40 and 11.")
    print("- **`CWarGoal`** came out whole: `GER -> SOV` on `barbarossa_war_goal`,")
    print("  `JAP -> CHI` on `conquer`, `GER -> ENG` on `uk_war_goal_2`, with the three")
    print("  country slots holding the tag `---` where a goal names nobody.")
    print()
    print("**`+0xc8` is still open.** It holds whole thousandths - GER 2967.000, SOV")
    print("7021.000, FRA 104.000 - and it is *not* manpower, which the save puts at")
    print("4919.314 for GER. Dividing officers by it gives 80%% for GER, 55%% for SOV,")
    print("87%% for USA, 109%% for occupied France: the range an officer ratio lives in,")
    print("so it is plausibly the officer requirement. **That last step is inference, not")
    print("a measurement** - no key writes it, so it is a runtime figure.")
    print()
    for owner, loader, shared, rows, placed in done:
        print("### `%s`" % owner["name"])
        print()
        note = "" if shared == 1 else "  Inherited by %d classes." % shared
        print("`LoadKey` at `%#x`, **%d of %d keys placed**.%s"
              % (loader, len(placed), len(rows), note))
        print()
        print("| key | token | where it lands |")
        print("| --- | --- | --- |")
        for name, token, _, where in rows:
            print("| `%s` | `%#x` | %s |" % (name, token, where))
        print()


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", nargs="?", help="a loader address, or a class name")
    parser.add_argument("--all", action="store_true", help="every loader, as markdown")
    args = parser.parse_args()

    names = switchmap.tokenNames()

    if args.all:
        import definitions
        writeAll(definitions.collect(), names)
        return

    if args.what is None:
        parser.error("give a loader address or a class name")

    loader = None
    if args.what.startswith("0x"):
        loader = int(args.what, 16)
        if loader < 0x400000:
            loader += 0x400000
    else:
        import json
        with open(os.path.join(HERE, "ghidra", "project.json"), encoding="utf-8") as f:
            for a in json.load(f)["addresses"]:
                if a.get("name") == args.what + "::LoadKey":
                    loader = int(a["rva"], 16) + 0x400000
    if loader is None:
        sys.exit("no loader found for " + args.what)

    rows, register = describe(loader, names)
    print("# loader %#x, the object is in %s\n" % (loader, register))
    print("%-30s %-8s %s" % ("key", "token", "where it lands"))
    for name, token, _, where in rows:
        print("%-30s %-8s %s" % (name, hex(token), where))


if __name__ == "__main__":
    main()
