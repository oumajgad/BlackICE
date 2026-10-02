"""A live window's seven child vectors and six name registries, classified."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]
WVF = base + 0x1602058 - 0x400000
VECS = [0x244, 0x264, 0x284, 0x2a4, 0x2c4, 0x2e4, 0x304]
REGS = [0x324, 0x348, 0x36c, 0x390, 0x3b4, 0x3d8]
LISTS = [0x40c, 0x41c, 0x42c, 0x43c, 0x44c, 0x45c]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return struct.unpack("<I", b)[0] if b else None

def st(v):
    return "0x%x" % (v - base + 0x400000) if v and base < v < base + 0x2000000 else "?"

def tname(o):
    t = u32(o + 0x24)
    return (hoi3.readString(pm, t + 8) if t else None) or "?"

def walk(node, prefix, out, seen=None, d=0):
    if seen is None:
        seen = set()
    if not node or node in seen or d > 300:
        return
    seen.add(node)
    raw = hoi3.readBytes(pm, node, 0x14)
    if raw is None:
        return
    v, ch, lo, hi, eq = struct.unpack("<IIIII", raw)
    walk(lo, prefix, out, seen, d)
    c = ch & 0xff
    if c == 0:
        if v:
            out.append((prefix, v))
    else:
        if v:
            out.append((prefix + chr(c), v))
        walk(eq, prefix + chr(c), out, seen, d + 1)
    walk(hi, prefix, out, seen, d)

sys.setrecursionlimit(100000)
b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = list(struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4)))
objset = set(objs)
wins = [o for o in objs if u32(o) == WVF]

vecKinds = [collections.Counter() for _ in VECS]
vecTotal = [0] * len(VECS)
for w in wins:
    for i, off in enumerate(VECS):
        lo, hi = u32(w + off), u32(w + off + 4)
        if not lo or not hi or hi <= lo:
            continue
        cnt = (hi - lo) // 4
        if cnt > 5000:
            continue
        raw = hoi3.readBytes(pm, lo, cnt * 4)
        if raw is None:
            continue
        for p in struct.unpack("<%dI" % cnt, raw):
            vecTotal[i] += 1
            vecKinds[i][st(u32(p))] += 1

print("child vectors (begin/end at these offsets on the live window):")
for i, off in enumerate(VECS):
    print("  +0x%-5x %-5d elements   %s" % (off, vecTotal[i], vecKinds[i].most_common(4)))

print()
print("name registries, and the name list that feeds each:")
for i, off in enumerate(REGS):
    kinds = collections.Counter()
    total = 0
    nlist = 0
    for w in wins:
        out = []
        walk(u32(w + off + 4), "", out)
        total += len(out)
        for nm, v in out:
            kinds[st(u32(v))] += 1
        h = u32(w + LISTS[i])
        while h:
            nlist += 1
            h = u32(h + 0x20)
            if nlist > 20000:
                break
    print("  registry +0x%-5x list +0x%-5x  entries %-5d  list nodes %-5d  %s"
          % (off, LISTS[i], total, nlist, kinds.most_common(3)))
