import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def name(vf):
    n = hoi3.classNameForVftable(pm, vf)
    if n:
        return n
    if vf and vf > base and vf < base + 0x2000000:
        return "vf 0x%x" % (vf - base + 0x400000)
    return "?0x%x" % (vf or 0)

def vec(label, off):
    b, e, c = u32(gui + off), u32(gui + off + 4), u32(gui + off + 8)
    if not b or not e:
        print("%s @+0x%x: empty/null  (0x%x 0x%x 0x%x)" % (label, off, b or 0, e or 0, c or 0))
        return []
    n = (e - b) // 4
    print("%s @+0x%x: 0x%x..0x%x cap 0x%x -> %d elements" % (label, off, b, e, c or 0, n))
    raw = hoi3.readBytes(pm, b, min(n, 4000) * 4)
    if raw is None:
        print("  unreadable")
        return []
    ptrs = struct.unpack("<%dI" % (len(raw) // 4), raw)
    kinds = collections.Counter(name(u32(p)) if p else "null" for p in ptrs)
    for k, v in kinds.most_common(20):
        print("   %6d  %s" % (v, k))
    return ptrs

vec("vecA", 0x44)
a = vec("vecB", 0x5c)
vec("vecC", 0x6c)
vec("vec+0x7c", 0x7c)
vec("vec+0xa4", 0xa4)
print()
print("first 12 of vecB:", ["0x%x" % p for p in a[:12]])
