"""The live widget tree: windows at CGui+0x5C, children at window+0x4C, and the back pointer."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing\scripts")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]
WINDOW_VF = base + 0x1602058 - 0x400000

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def st(v):
    return "0x%x" % (v - base + 0x400000) if v and base < v < base + 0x2000000 else "?"

def tname(o):
    t = u32(o + 0x24)
    return hoi3.readString(pm, t + 8) if t else None

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = list(struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4)))
objset = set(objs)

parent = {}
childCount = {}
for o in objs:
    if u32(o) != WINDOW_VF:
        continue
    cb, ce = u32(o + 0x4c), u32(o + 0x50)
    if not cb or not ce or ce <= cb:
        childCount[o] = 0
        continue
    cnt = (ce - cb) // 4
    raw = hoi3.readBytes(pm, cb, cnt * 4)
    if raw is None:
        continue
    kids = struct.unpack("<%dI" % cnt, raw)
    childCount[o] = cnt
    for k in kids:
        if k in objset:
            parent.setdefault(k, o)

print("windows: %d  total children claimed: %d  distinct children: %d  objects: %d"
      % (len(childCount), sum(childCount.values()), len(parent), len(objs)))
roots = [o for o in objs if o not in parent]
print("objects with no parent window: %d" % len(roots))
print()
# where does a child hold its parent?
offs = collections.Counter()
for k, p in list(parent.items())[:600]:
    raw = hoi3.readBytes(pm, k, 0x100)
    if raw is None:
        continue
    w = struct.unpack("<%dI" % (len(raw) // 4), raw)
    for i, v in enumerate(w):
        if v == p:
            offs[i * 4] += 1
print("offsets in a child that equal its parent window:")
for off, c in offs.most_common(8):
    print("   +0x%-4x %d" % (off, c))
print()
print("top windows by child count:")
for o, c in sorted(childCount.items(), key=lambda x: -x[1])[:15]:
    print("   0x%08x %-34s %d children  parent=%s" %
          (o, tname(o), c, tname(parent[o]) if o in parent else "-"))
print()
print("root objects (no parent):")
for o in roots[:40]:
    print("   0x%08x %-11s %s" % (o, st(u32(o)), tname(o)))
