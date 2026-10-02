"""The live widget tree, reading the window child array at +0x4C as 0x18-byte records."""
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
    return (hoi3.readString(pm, t + 8) if t else None) or "?"

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = list(struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4)))
objset = set(objs)

parent, kidsOf = {}, {}
bad = 0
for o in objs:
    if u32(o) != WINDOW_VF:
        continue
    cb, ce = u32(o + 0x4c), u32(o + 0x50)
    if not cb or not ce or ce <= cb:
        kidsOf[o] = []
        continue
    span = ce - cb
    if span % 0x18:
        bad += 1
    cnt = span // 0x18
    raw = hoi3.readBytes(pm, cb, cnt * 0x18)
    if raw is None:
        kidsOf[o] = []
        continue
    ks = [struct.unpack_from("<I", raw, i * 0x18)[0] for i in range(cnt)]
    kidsOf[o] = ks
    for k in ks:
        if k in objset:
            parent.setdefault(k, o)

claimed = sum(len(v) for v in kidsOf.values())
inset = sum(1 for v in kidsOf.values() for k in v if k in objset)
print("windows %d  records %d  of which live gui objects %d  distinct %d  (spans not a multiple of 0x18: %d)"
      % (len(kidsOf), claimed, inset, len(parent), bad))
print("objects with no parent: %d" % sum(1 for o in objs if o not in parent))
print()
print("kinds of thing in the child records:")
c = collections.Counter(st(u32(k)) for v in kidsOf.values() for k in v)
for k, v in c.most_common(12):
    print("   %-11s %d" % (k, v))
print()
roots = [o for o in objs if o not in parent]
print("root objects: %d" % len(roots))
wr = [o for o in roots if u32(o) == WINDOW_VF]
print("of which windows: %d" % len(wr))
for o in wr[:50]:
    print("   0x%08x %-34s %d children" % (o, tname(o), len(kidsOf.get(o, []))))
