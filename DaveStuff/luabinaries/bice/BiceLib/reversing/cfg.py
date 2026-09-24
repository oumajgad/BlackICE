"""A function's control flow, and whether a patch would land on top of a branch target.

    python cfg.py 0x005BAF70 0x450                 the blocks and every edge into them
    python cfg.py 0x005BAF70 0x450 --lands-in 0x005BB25E 0x005BB262

**Read control flow off the graph, not off one jump.** The `isAtWar` test in
`CUnit::UpdateDaily` reads as though it gates troop rotation and does not: the block it
appears to guard has seven incoming edges and six of them are branches taken to skip the
block *above* it. One jump cannot tell you that; the edge list can.

`--lands-in` is the check to run before hooking anything. Five bytes of jump cover more
than the instruction being replaced, and a branch into the middle of that lands in the
displacement. Give it the bytes the jump would cover **after** the first one - a branch
to the first byte is fine, because that is where the jump starts.

Walking follows both sides of every branch from the entry, so a block is not called
unreachable because the only path to it was a conditional nobody looked at.
"""

import argparse

import capstone

import image


def walk(entry, length):
    """address -> instruction, and address -> [(kind, destination)] for the edges out"""
    engine = image.engine()
    end = entry + length
    decoded = {}
    edges = {}
    pending = [entry]

    while pending:
        at = pending.pop()
        while entry <= at < end and at not in decoded:
            window = list(engine.disasm(image.read(at, 16), at, count=1))
            if not window:
                break
            instruction = window[0]
            decoded[at] = instruction
            after = at + instruction.size

            if instruction.mnemonic.startswith("ret"):
                edges[at] = []
                break

            jump = capstone.CS_GRP_JUMP in instruction.groups
            if not jump:
                at = after
                continue

            target = None
            if instruction.operands and instruction.operands[0].type == 2:
                target = instruction.operands[0].imm
            if target is not None and entry <= target < end:
                pending.append(target)

            if instruction.mnemonic == "jmp":
                edges[at] = [("jmp", target)]
                break
            edges[at] = [("taken", target), ("fall", after)]
            at = after

    return decoded, edges


def incoming(decoded, edges):
    """address -> who reaches it, and how"""
    out = {}
    for at, outgoing in edges.items():
        for kind, target in outgoing:
            if target is not None:
                out.setdefault(target, []).append((at, kind))
    for at, instruction in decoded.items():
        after = at + instruction.size
        if at not in edges and after in decoded:
            out.setdefault(after, []).append((at, "flow"))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("entry", type=image.address)
    parser.add_argument("length", nargs="?", default="0x400", type=lambda v: int(v, 0))
    parser.add_argument("--lands-in", nargs=2, type=image.address,
                        metavar=("LOW", "HIGH"),
                        help="report branches into this range and print nothing else")
    args = parser.parse_args()

    entry = args.entry
    decoded, edges = walk(entry, args.length)

    if args.lands_in:
        low, high = args.lands_in
        hits = []
        for at in sorted(edges):
            for kind, target in edges[at]:
                if target is not None and low <= target <= high:
                    hits.append((at, decoded[at].mnemonic, target))
        print("branches landing in 0x%08X..0x%08X:" % (low, high))
        for at, mnemonic, target in hits:
            print("   0x%08X  %s -> 0x%08X" % (at, mnemonic, target))
        if not hits:
            print("   none - nothing lands inside those bytes")
        return

    reached = incoming(decoded, edges)
    print("%s, %d instructions" % (image.both(entry), len(decoded)))
    for at in sorted(decoded):
        instruction = decoded[at]
        if at == entry or at in reached and len(reached[at]) > 0 and (
                at in [t for outs in edges.values() for _, t in outs if t is not None]):
            who = reached.get(at, [])
            print("\n%-12s <- %s" % ("0x%08X:" % at,
                  ", ".join("0x%X(%s)" % (a, k) for a, k in who) or "entry"))
        print("   0x%08X  %-7s %s" % (at, instruction.mnemonic, instruction.op_str))


if __name__ == "__main__":
    main()
