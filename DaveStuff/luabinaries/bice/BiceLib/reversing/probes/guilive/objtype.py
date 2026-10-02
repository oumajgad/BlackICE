"""For every live gui object in CGui+0x5C, find where it points back at its CGuiType."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

# ---- types, from types.txt produced by tst.py
typeByPtr = {}
typeVf = {}
with open("types.txt") as f:
    for line in f:
        parts = line.split()
        nm = parts[0]; ptr = int(parts[1], 16)
        typeByPtr[ptr] = nm
        typeVf[ptr] = parts[2] if len(parts) > 2 else ""

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
raw = hoi3.readBytes(pm, b, n * 4)
objs = struct.unpack("<%dI" % n, raw)

def vfname(vf):
    nm = hoi3.classNameForVftable(pm, vf)
    if nm:
        return nm
    if vf and base < vf < base + 0x2000000:
        return "vf 0x%x" % (vf - base + 0x400000)
    return "?"

# find the offset at which each object holds a pointer to a known CGuiType
offCount = collections.Counter()
pairs = collections.Counter()
examples = {}
for o in objs:
    raw = hoi3.readBytes(pm, o, 0x120)
    if raw is None:
        continue
    words = struct.unpack("<%dI" % (len(raw) // 4), raw)
    ovf = words[0]
    for i, w in enumerate(words):
        if w in typeByPtr:
            offCount[i * 4] += 1
            pairs[(vfname(ovf), typeVf[w], i * 4)] += 1
            examples.setdefault((vfname(ovf), typeVf[w]), (o, typeByPtr[w], i * 4))

print("objects: %d" % len(objs))
print("offsets at which a CGuiType pointer appears:")
for off, c in offCount.most_common(12):
    print("   +0x%-4x %d" % (off, c))
print()
print("object vftable -> type vftable, at offset:")
for (ov, tv, off), c in pairs.most_common(30):
    ex = examples.get((ov, tv))
    print("  %-18s -> %-18s +0x%-4x  %5d   e.g. %s @0x%x" % (ov, tv, off, c, ex[1], ex[0]))
