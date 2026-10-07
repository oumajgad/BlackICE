# -*- coding: utf-8 -*-
r"""Census of one `CSubUnitDefinition` stat: who reads it, narrowed by provenance.

    python scripts/statcensus.py 0x160          sea_defence
    python scripts/statcensus.py 0x128          air_defence, the control - should give 10 sites

Generalised out of the air-defence work so the next "stat X is broken" question costs one
command. The method, and its two known limits:

  * the sweep **resumes past every byte capstone refuses** (trap 9's third failure mode), so
    it covers `.text` rather than the first 4% of it;
  * a hit is kept only where the register was just loaded from `CSubUnit + 0x58` or
    `CUnit + 0xC8`, the two definition pointers, because a bare displacement is dense - and
    that makes the result a **lower bound**: a function receiving the definition as an
    *argument* is invisible to it. The AI's per-brigade power figure is the known example.

So a clean result here is "no reader with a definition pointer in hand", not "no reader".
Pair it with a call-closure check over the paths that matter, as the air work did.
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import image

record = json.load(io.open(os.path.join(REVERSING, "ghidra", "project.json"),
                           encoding="utf-8"))
byrva = {int(a["rva"], 16): a for a in record["addresses"]}

TARGET = int(sys.argv[1], 16)
MEM = re.compile(r"\[(e[a-z][a-z])(?:\s*\+\s*e[a-z][a-z](?:\*\d)?)?\s*\+\s*(0x[0-9a-f]+)\]")

start, blob = image.text()
cs = image.engine(False)
cands = []
pos = 0
resumes = 0
while pos < len(blob):
    got = 0
    for n in cs.disasm(bytes(blob[pos:]), start + pos):
        if ("0x%x]" % TARGET) in n.op_str:
            m = MEM.search(n.op_str)
            if m and m.group(1) not in ("esp", "ebp") and int(m.group(2), 16) == TARGET:
                cands.append(n.address)
        got = n.address + n.size - (start + pos)
    if got:
        pos += got
        resumes += 1
    else:
        pos += 1

print("+0x%X: %d accesses in .text (%d resumes)" % (TARGET, len(cands), resumes))

funcs = {}
for a in cands:
    try:
        f = image.functionStart(a)
    except Exception:
        f = None
    funcs.setdefault(f, []).append(a)
print("in %d functions\n" % len(funcs))

kept = []
for f, sites in sorted(funcs.items(), key=lambda kv: (kv[0] is None, kv[0])):
    if f is None:
        continue
    ins = image.decode(f, 0x2600)
    byaddr = {n.address: i for i, n in enumerate(ins)}
    for a in sites:
        i = byaddr.get(a)
        if i is None:
            continue
        m = MEM.search(ins[i].op_str)
        reg = m.group(1)
        # Walk back to the **nearest** write of this register and accept only that one.
        # Scanning the window for *any* +0x58 load gives false positives: at 0x1672E3 in
        # CNavalCombatant::CollectTargets, `eax` is reloaded from `[edx+0xB0]` (the sub-unit's
        # unit_ptr) after an earlier `mov eax,[edx+0x58]`, so `[eax+0x130]` is CUnit+0x130 and
        # not the definition's `suppression` - which this scan reported as a combat reader of
        # a stat until the site was read by hand.
        why = []
        for j in range(i - 1, max(-1, i - 60), -1):
            p = ins[j]
            dest = p.op_str.split(",")[0].strip()
            if dest != reg:
                continue
            if p.mnemonic.startswith("mov"):
                mm = MEM.search(p.op_str)
                if mm and int(mm.group(2), 16) in (0x58, 0xC8):
                    why.append("+0x%X@0x%X" % (int(mm.group(2), 16),
                                               p.address - image.IMAGE_BASE))
            break                       # nearest write only, whatever it was
        if why:
            kept.append((f, a, "%s %s" % (ins[i].mnemonic, ins[i].op_str), why))

print("reads with a definition pointer provably in hand: %d\n" % len(kept))
last = None
for f, a, text, why in kept:
    if f != last:
        e = byrva.get(f - image.IMAGE_BASE)
        print("== rva 0x%-8X %s"
              % (f - image.IMAGE_BASE,
                 ("%s [%s]" % (e.get("name"), e.get("confidence"))) if e else "UNRECORDED"))
        last = f
    print("     0x%-8X %-36s via %s" % (a - image.IMAGE_BASE, text, ", ".join(why)))

combat = [k for k in kept if 0x160000 <= (k[0] - image.IMAGE_BASE) < 0x180000]
print("\nof those, in the combat classes (rva 0x160000-0x180000): %d" % len(combat))
for f, a, text, why in combat:
    e = byrva.get(f - image.IMAGE_BASE)
    print("     0x%-8X in %s" % (a - image.IMAGE_BASE,
                                 (e.get("name") if e else "0x%X" % (f - image.IMAGE_BASE))))
