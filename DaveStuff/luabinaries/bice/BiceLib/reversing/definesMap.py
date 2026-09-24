"""Where each `defines.lua` entry lands in memory - read out of the executable.

    python definesMap.py                       every block, name -> offset
    python definesMap.py --block military      one block
    python definesMap.py --check               against project.json's CDefines* structs
    python definesMap.py --lua <defines.lua>   against a mod's file; defaults to the
                                               BlackICE one this folder sits inside

**The engine reads defines.lua by name, not by position.** That is the whole point of
this script. `CDefines::Load` (`0x446210`) is one long unrolled run of

    mov   esi, [ebx + <block>]          ; ebx is the CDefines*, <block> picks the struct
    push  <"SOME_DEFINE">               ; the key, as a literal in .rdata
    call  0x445F40                      ; look it up in the parsed table, x1000
    mov   [esi + <offset>], eax         ; and the offset is **compiled in**

so a define's offset is fixed by the exe and nothing a mod does to the *order* of
`common/defines.lua` can move it. A name the exe does not push is never read, however
neatly it sits in the file - the mod's `WHITESEA` / `WHITESEA_BLOCKER` are exactly that -
and a name the exe pushes that the file does not define falls back to whatever the
getter returns for a missing key.

This matters because it is easy to believe the opposite. Both files list `country` and
`economy` in the same order the engine stores them, so anchoring positionally reproduces
those two blocks exactly and looks confirmed; `military` is where it comes apart, because
BlackICE adds `PRIDE_SUNK_DISSENT_IMPACT`, which the engine has never heard of, and
because the engine's own order is not the file's (`UNIT_ATTACK_DELAY_MODIFY` is stored
at `+0x98` and `UNIT_ATTACK_DELAY_PERIOD` at `+0x9C`, the other way round from the file).

So: **when the mod's defines change, nothing here moves.** Run `--lua` anyway, which is
the check that is actually worth doing - it says which of the engine's keys the mod file
no longer provides, and which of the mod's entries the engine ignores.

## How the pairing is done

A push of a string literal is held until the next call to a getter, which pins it to that
getter; the name then waits in a queue until the next store through a block pointer.
The queue is needed because the compiler interleaves - the push for entry *n+1* is
routinely emitted before the store for entry *n*. `--verify` reports any store that ran
out of names, which is what would show the pairing wrong.
"""

import argparse
import collections
import io
import json
import os

import capstone

import image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.join(HERE, "ghidra", "project.json")
# reversing/ sits at <repo>/DaveStuff/luabinaries/bice/BiceLib/reversing
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
DEFAULT_LUA = os.path.join(REPO, "common", "defines.lua")

LOAD_START = 0x446210        # CDefines::Load, the only writer of these structs
LOAD_END = 0x44B42C          # its ret

# the two accessors it reads an entry with. 0x445F40 returns a pointer to the value,
# already scaled by 1000 - every numeric define. 0x4460D0 returns a plain int and is
# used only for the `map` block, whose entries are province ids.
GETTERS = {0x445F40: "x1000", 0x4460D0: "int"}

# CDefines field -> the block in defines.lua it is filled from, by the keys stored
# through it. Nothing here is guessed: `--check` prints the first and last key of each.
BLOCKS = {
    0x9C: "economy",
    0xAC: "military",
    0xBC: "diplomacy",
    0xCC: "country",
    0xDC: "alignment",
    0xEC: "weather",
    0xFC: "map",
    0x10C: "goods_cost",
}

# what project.json calls the struct behind each block pointer, where it names one
STRUCTS = {
    "economy": "CDefinesEconomy",
    "military": "CDefinesSupply",
    "country": "CDefinesCountry",
}


def cstring(va, limit=96):
    """the NUL-terminated ASCII string at a virtual address, or None"""
    for start, data, _ in image.sections():
        if start <= va < start + len(data):
            raw = data[va - start:va - start + limit]
            end = raw.find(b"\x00")
            if end < 0:
                return None
            text = raw[:end]
            if not text or not all(32 <= c < 127 for c in text):
                return None
            return text.decode("ascii")
    return None


def scan():
    """
    [(block offset, field offset, name, getter, store address)] in code order.

    Read straight off `CDefines::Load` - no defines.lua is consulted and none is needed.
    """
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    start, data = image.text()
    code = data[LOAD_START - start:LOAD_END - start]

    holder = {}                     # register -> the CDefines offset it was loaded from
    literal = None                  # the last string literal pushed
    pending = collections.deque()   # names pinned to a getter, awaiting their store
    rows = []
    unpaired = []
    reg = capstone.x86.X86_OP_REG
    mem = capstone.x86.X86_OP_MEM
    imm = capstone.x86.X86_OP_IMM

    for ins in md.disasm(code, LOAD_START):
        ops = ins.operands
        if ins.mnemonic == "push" and ops and ops[0].type == imm:
            text = cstring(ops[0].imm)
            if text:
                literal = text
        elif ins.mnemonic == "call":
            if ops and ops[0].type == imm and ops[0].imm in GETTERS and literal:
                pending.append((literal, GETTERS[ops[0].imm]))
                literal = None
            for volatile in ("eax", "ecx", "edx"):
                holder.pop(volatile, None)
        elif ins.mnemonic == "mov" and len(ops) == 2:
            dst, src = ops
            if dst.type == reg and src.type == mem:
                name = ins.reg_name(dst.reg)
                base = ins.reg_name(src.mem.base) if src.mem.base else None
                if base == "ebx" and not src.mem.index:
                    holder[name] = src.mem.disp
                else:
                    holder.pop(name, None)
            elif dst.type == mem and src.type == reg:
                base = ins.reg_name(dst.mem.base) if dst.mem.base else None
                if base in holder and not dst.mem.index:
                    if pending:
                        text, kind = pending.popleft()
                        rows.append((holder[base], dst.mem.disp, text, kind,
                                     ins.address))
                    else:
                        unpaired.append((holder[base], dst.mem.disp, ins.address))
            elif dst.type == reg:
                holder.pop(ins.reg_name(dst.reg), None)
        elif ins.mnemonic == "lea" and ops and ops[0].type == reg:
            holder.pop(ins.reg_name(ops[0].reg), None)

    return rows, unpaired


def byBlock(rows):
    """block name -> [(field offset, define name, getter)] in code order"""
    out = collections.OrderedDict()
    for holderOffset, offset, name, kind, _ in rows:
        block = BLOCKS.get(holderOffset, "CDefines+0x%X" % holderOffset)
        out.setdefault(block, []).append((offset, name, kind))
    return out


def luaBlocks(path):
    """
    block name -> [key] in file order, for a defines.lua.

    Deliberately crude: it is only used to ask which keys are present, and the engine
    does not care what order they come in.
    """
    text = io.open(path, encoding="utf-8", errors="replace").read()
    out = collections.OrderedDict()
    stack = []
    for line in text.split("\n"):
        line = line.split("--")[0]
        while True:
            line = line.strip()
            if not line:
                break
            if line[0] in ",{":
                line = line[1:]
                continue
            if line[0] == "}":
                if stack:
                    stack.pop()
                line = line[1:]
                continue
            head = ""
            for char in line:
                if char.isalnum() or char == "_":
                    head += char
                else:
                    break
            rest = line[len(head):].lstrip()
            if head and rest.startswith("="):
                rest = rest[1:].lstrip()
                if rest.startswith("{"):
                    stack.append(head)
                    out.setdefault(head, [])
                    line = rest[1:]
                    continue
                if stack:
                    out[stack[-1]].append(head)
                cut = len(line)
                for index, char in enumerate(line):
                    if char in ",}":
                        cut = index
                        break
                line = line[cut:]
                continue
            break
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--block", help="only this block of defines.lua")
    parser.add_argument("--check", action="store_true",
                        help="against project.json's CDefines* structs")
    parser.add_argument("--lua", nargs="?", const=DEFAULT_LUA,
                        help="against a mod's defines.lua (default: %s)" % DEFAULT_LUA)
    parser.add_argument("--verify", action="store_true",
                        help="report stores the pairing could not name")
    args = parser.parse_args()

    rows, unpaired = scan()
    blocks = byBlock(rows)

    if args.verify or unpaired:
        print("%d stores through a CDefines block pointer, %d without a name"
              % (len(rows) + len(unpaired), len(unpaired)))
        for holderOffset, offset, address in unpaired:
            print("  CDefines+0x%X field +0x%X at %s"
                  % (holderOffset, offset, image.both(address)))
        print()

    if not args.check and args.lua is None:
        for block, entries in blocks.items():
            if args.block and block != args.block:
                continue
            print("== %s  (CDefines+0x%X, %d entries)"
                  % (block, [k for k, v in BLOCKS.items() if v == block][0],
                     len(entries)))
            for offset, name, kind in sorted(entries):
                print("   +0x%-5X %-46s %s" % (offset, name, kind))
        return

    if args.check:
        project = json.load(io.open(PROJECT, encoding="utf-8"))
        recorded = {s["name"]: s for s in project["structs"]}
        for block, entries in blocks.items():
            if args.block and block != args.block:
                continue
            struct = STRUCTS.get(block)
            print("== %s  CDefines+0x%X  %s..%s  %d entries  %s"
                  % (block, [k for k, v in BLOCKS.items() if v == block][0],
                     entries[0][1], entries[-1][1], len(entries),
                     struct or "(no struct recorded)"))
            if not struct or struct not in recorded:
                continue
            engine = {}
            for offset, name, _ in entries:
                engine.setdefault(offset, name)
            for field in recorded[struct].get("fields", []):
                offset = int(field["offset"], 16)
                want = engine.get(offset)
                if want is None:
                    print("   +0x%-5X %-46s NOT READ by CDefines::Load"
                          % (offset, field["name"]))
                elif want != field["name"]:
                    print("   +0x%-5X %-46s engine reads %s"
                          % (offset, field["name"], want))
            print()

    if args.lua is not None:
        path = args.lua
        print("against %s" % path)
        lua = luaBlocks(path)
        for block, entries in blocks.items():
            if args.block and block != args.block:
                continue
            wanted = [name for _, name, _ in entries]
            have = lua.get(block, [])
            missing = [n for n in wanted if n not in have]
            extra = [n for n in have if n not in wanted]
            print("== %s  engine %d, file %d" % (block, len(set(wanted)), len(have)))
            for name in missing:
                print("   engine reads %s - the file does not define it" % name)
            for name in extra:
                print("   file defines %s - the engine never reads it" % name)


if __name__ == "__main__":
    main()
