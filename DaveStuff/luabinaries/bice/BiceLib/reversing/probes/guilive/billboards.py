import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing\scripts")
import hoi3

pm = hoi3.attach()
base = pm.base_address

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return struct.unpack("<I", b)[0] if b else None

addr = base + 0x16010d0 - 0x400000
h = addr.to_bytes(4, "little").hex()
pat = "".join("\\x" + h[i:i + 2] for i in range(0, 8, 2))
r = sorted(p for p in pm.pattern_scan_all(pattern=pat.encode(), return_multiple=True)
           if p >= base + hoi3.DATA_SECTION_START)
print("objects: %d" % len(r))

kinds = collections.Counter()
caps = 0
for p in r:
    t = u32(p + 0x138)
    nm = hoi3.readString(pm, t + 8) if t else None
    tvf = u32(t) if t else None
    kinds[(nm, "0x%x" % ((tvf - base + 0x400000) if tvf and tvf > base else 0))] += 1
    s = hoi3.readString(pm, p + 0xb2c)
    if s:
        caps += 1
        if caps <= 12:
            print("   caption %r on 0x%x type=%s" % (s, p, nm))
print("with a non-empty caption at +0xB2C: %d" % caps)
for k, v in kinds.most_common(20):
    print("   %-40s %s  %d" % (k[0], k[1], v))
