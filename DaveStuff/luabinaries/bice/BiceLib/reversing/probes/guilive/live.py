"""Every live gui object in CGui+0x5C, with the name of the CGuiType at +0x24."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def vfname(vf):
    nm = hoi3.classNameForVftable(pm, vf)
    if nm:
        return nm
    if vf and base < vf < base + 0x2000000:
        return "vf 0x%x" % (vf - base + 0x400000)
    return "?0x%x" % (vf or 0)

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4))

# the type vftables, learned from the TST walk
TYPEVF = set()
with open("types.txt") as f:
    for line in f:
        p = line.split()
        vf = u32(int(p[1], 16))
        TYPEVF.add(vf)

rows = []
noType = collections.Counter()
for o in objs:
    t = u32(o + 0x24)
    tv = u32(t) if t else None
    tname = hoi3.readString(pm, t + 8) if (tv in TYPEVF) else None
    if tname is None:
        noType[vfname(u32(o))] += 1
    rows.append((o, vfname(u32(o)), tname, vfname(tv) if tv else "-"))

print("live gui objects: %d ; with a resolvable type name: %d" %
      (len(rows), sum(1 for r in rows if r[2])))
print()
byclass = collections.Counter((r[1], r[3]) for r in rows)
for (ov, tv), c in byclass.most_common(40):
    ex = next(r for r in rows if r[1] == ov and r[3] == tv)
    print("  %-18s type %-18s %5d   e.g. %s" % (ov, tv, c, ex[2]))

with open("liveobjects.txt", "w") as f:
    for o, ov, tn, tv in rows:
        f.write("0x%08x  %-18s  %-18s  %s\n" % (o, ov, tv, tn))
print("\nwrote liveobjects.txt")
if noType:
    print("objects with no resolvable type:", dict(noType))
