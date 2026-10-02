"""Find the window whose child vector holds a given widget, and at what offset."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]
TARGETS = set(int(a, 16) for a in sys.argv[1:])

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def st(v):
    return "0x%x" % (v - base + 0x400000) if v and base < v < base + 0x2000000 else "?"

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4))

# for every live gui object, treat every (ptr, ptr) pair in its first 0x520 bytes as a
# candidate vector and see whether the target is one of its elements.
hitsByOffset = collections.Counter()
for o in objs:
    raw = hoi3.readBytes(pm, o, 0x520)
    if raw is None:
        continue
    w = struct.unpack("<%dI" % (len(raw) // 4), raw)
    for i in range(len(w) - 1):
        lo, hi = w[i], w[i + 1]
        if not lo or hi <= lo or (hi - lo) % 4 or (hi - lo) > 0x4000:
            continue
        cnt = (hi - lo) // 4
        if cnt == 0 or cnt > 1000:
            continue
        d = hoi3.readBytes(pm, lo, cnt * 4)
        if d is None:
            continue
        els = set(struct.unpack("<%dI" % cnt, d))
        inter = els & TARGETS
        if inter:
            t = u32(o + 0x24)
            tn = hoi3.readString(pm, t + 8) if t else None
            hitsByOffset[(st(u32(o)), i * 4, cnt)] += 1
            print("0x%08x %-11s %-28s vector at +0x%-4x (%d elements) holds %s"
                  % (o, st(u32(o)), tn, i * 4, cnt,
                     " ".join("0x%x" % x for x in sorted(inter))))
print()
for k, v in hitsByOffset.most_common():
    print(k, v)
