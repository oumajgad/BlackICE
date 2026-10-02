"""object vftable x type vftable x declared .gui keyword, over the 2305 live gui objects."""
import struct, sys, json, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]
names = json.load(open("guinames.json"))["all"]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def st(vf):
    if vf and base < vf < base + 0x2000000:
        return "0x%x" % (vf - base + 0x400000)
    return "?"

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4))

tab = collections.Counter()
ex = {}
unnamed = []
for o in objs:
    ovf = st(u32(o))
    t = u32(o + 0x24)
    tvf = st(u32(t)) if t else "-"
    nm = hoi3.readString(pm, t + 8) if t else None
    kw = names.get(nm, ["(not in mod .gui)"])[0] if nm else "(no name)"
    tab[(ovf, tvf, kw)] += 1
    ex.setdefault((ovf, tvf, kw), nm)
    if nm is None:
        unnamed.append((o, ovf, tvf))

print("%-12s %-12s %-26s %6s  example" % ("object vf", "type vf", "keyword", "n"))
for (ovf, tvf, kw), c in sorted(tab.items(), key=lambda x: -x[1]):
    print("%-12s %-12s %-26s %6d  %s" % (ovf, tvf, kw, c, ex[(ovf, tvf, kw)]))
print()
print("objects whose type has no readable name: %d" % len(unnamed))
for o, ovf, tvf in unnamed[:20]:
    print("  0x%08x obj %s type %s" % (o, ovf, tvf))
