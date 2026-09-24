"""What the named functions call that nobody has named yet - the work queue.

    python frontier.py --top 40             the whole frontier, best first
    python frontier.py --from 0x1BAF70      just what one function reaches
    python frontier.py --from 0x1BAF70 --depth 2

**This is where breadth comes from.** Hand-picked questions are a byproduct of reversing
already done, so they run out; the call graph does not. Walking outwards from something
already understood also keeps every step anchored - a function reached from
`CUnit::UpdateDaily` is a function you already know something about, which is most of
what stops a name being invented rather than read.

Ranked by **how many named functions call it**, because a callee several named callers
share pays for itself in all of them, and because arriving with several contexts makes it
far easier to say what it is for.

Two limits, both deliberate:

- **direct calls only.** A virtual call through a table is not in here; `slotcalls.py`
  handles those, and a class's own table already names what it can.
- **a function's extent is guessed.** Decoding runs from a known entry until the int3
  padding after a `ret`, capped. That is reliable for the entry - it comes from
  `project.json` - but a jump table inside a function can cut the walk short, so a
  missing callee means "not found", never "not called".
"""

import argparse
import io
import json
import os

import capstone

import image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.join(HERE, "ghidra", "project.json")
CAP = 0x3000


def named():
    """rva -> name, for everything project.json calls a function"""
    document = json.load(io.open(PROJECT, encoding="utf-8"))
    return {int(e["rva"], 16): e["name"] for e in document["addresses"]
            if e["kind"] == "function"}


def callsFrom(entry):
    """every direct call target in the function at this virtual address"""
    engine = image.engine(detail=False)
    out = set()
    start, data = image.text()
    offset = entry - start
    if offset < 0 or offset >= len(data):
        return out

    sawReturn = False
    for instruction in engine.disasm(data[offset:offset + CAP], entry):
        if instruction.mnemonic == "call" and instruction.bytes[0] == 0xE8:
            target = int(instruction.op_str, 16) if instruction.op_str.startswith("0x") \
                else None
            if target is not None:
                out.add(target)
        elif instruction.mnemonic.startswith("ret"):
            sawReturn = True
        elif instruction.mnemonic == "int3" and sawReturn:
            break
    return out


def graph(names):
    """callee rva -> the named callers that reach it"""
    reached = {}
    for rva, name in names.items():
        for target in callsFrom(image.toVa(rva)):
            reached.setdefault(image.toRva(target), set()).add(name)
    return reached


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--from", dest="start", type=image.address,
                        help="only what this function reaches")
    parser.add_argument("--depth", type=int, default=1)
    parser.add_argument("--top", type=int, default=40)
    args = parser.parse_args()

    names = named()

    if args.start is not None:
        seen = set()
        level = {args.start}
        for step in range(args.depth):
            nextLevel = set()
            for rva in sorted(level):
                for target in callsFrom(rva):
                    nextLevel.add(target)
            level = nextLevel - seen
            seen |= level
            print("\n--- %d call%s away ---" % (step + 1, "" if step == 0 else "s"))
            for rva in sorted(level):
                print("   %-28s %s" % (image.both(rva),
                                       names.get(image.toRva(rva),
                                                 "-- unnamed --")))
        return

    reached = graph(names)
    frontier = [(len(callers), rva, callers)
                for rva, callers in reached.items() if rva not in names]
    frontier.sort(key=lambda row: (-row[0], row[1]))

    print("%d unnamed functions are called by named ones; %d named in all"
          % (len(frontier), len(names)))
    print("%-30s %-7s %s" % ("address", "callers", "called by"))
    for count, rva, callers in frontier[:args.top]:
        listed = ", ".join(sorted(callers)[:3])
        if count > 3:
            listed += ", ..."
        print("%-30s %-7d %s" % (image.both(image.toVa(rva)), count, listed))


if __name__ == "__main__":
    main()
