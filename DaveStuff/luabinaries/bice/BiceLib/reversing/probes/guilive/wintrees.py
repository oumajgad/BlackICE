"""The six name registries a live window carries, at +0x324 +0x348 +0x36C +0x390 +0x3B4 +0x3D8."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]
WINDOW_VF = base + 0x1602058 - 0x400000
OFFS = [0x324, 0x348, 0x36c, 0x390, 0x3b4, 0x3d8]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def st(v):
    return "0x%x" % (v - base + 0x400000) if v and base < v < base + 0x2000000 else "?"

def tname(o):
    t = u32(o + 0x24)
    return (hoi3.readString(pm, t + 8) if t else None) or "?"

def walk(node, prefix, out, depth=0, seen=None):
    if seen is None:
        seen = set()
    if not node or node in seen or depth > 300:
        return
    seen.add(node)
    raw = hoi3.readBytes(pm, node, 0x14)
    if raw is None:
        return
    value, ch, low, high, eq = struct.unpack("<IIIII", raw)
    walk(low, prefix, out, depth, seen)
    c = ch & 0xFF
    if c == 0:
        if value:
            out.append((prefix, value))
    else:
        if value:
            out.append((prefix + chr(c), value))
        walk(eq, prefix + chr(c), out, depth + 1, seen)
    walk(high, prefix, out, depth, seen)

sys.setrecursionlimit(100000)

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = list(struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4)))
objset = set(objs)
windows = [o for o in objs if u32(o) == WINDOW_VF]

perSlot = [collections.Counter() for _ in OFFS]
totals = [0] * len(OFFS)
inVector = [0] * len(OFFS)
target = sys.argv[1] if len(sys.argv) > 1 else "topbar"

for w in windows:
    for i, off in enumerate(OFFS):
        cont = w + off
        cnt = u32(cont + 0xc)
        root = u32(cont + 4)
        out = []
        walk(root, "", out)
        totals[i] += len(out)
        for nm, v in out:
            perSlot[i][st(u32(v))] += 1
            if v in objset:
                inVector[i] += 1
        if tname(w) == target:
            if out:
                print("== %s  registry %d (+0x%x)  count field=%s  entries=%d"
                      % (target, i, off, cnt, len(out)))
                for nm, v in sorted(out)[:400]:
                    print("     %-40s 0x%08x %-11s inVector=%s"
                          % (nm, v, st(u32(v)), v in objset))

print()
print("across all %d windows:" % len(windows))
for i, off in enumerate(OFFS):
    print("  registry %d (+0x%-5x) entries %-6d in CGui vector %-6d  value classes %s"
          % (i, off, totals[i], inVector[i], perSlot[i].most_common(6)))
