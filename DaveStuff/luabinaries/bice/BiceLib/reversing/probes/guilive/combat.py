import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return struct.unpack("<I", b)[0] if b else None

for cls in ("CLandCombat", "CAirCombat", "CNavalCombat", "CCombat"):
    for c in hoi3.instances(pm, cls):
        prov = u32(c + 0x18)
        print("%s 0x%x  province 0x%x id=%s  +0x2C=0x%x  +0x30=0x%x"
              % (cls, c, prov or 0, u32(prov + 0xd0) if prov else None,
                 u32(c + 0x2c) or 0, u32(c + 0x30) or 0))
        for off in (0x2c, 0x30):
            b = u32(c + off)
            if not b:
                continue
            print("    billboard 0x%x vftable 0x%x  frame=%s  caption=%r"
                  % (b, (u32(b) or 0) - base + 0x400000,
                     struct.unpack("<h", hoi3.readBytes(pm, b + 0x4e, 2))[0],
                     hoi3.readString(pm, b + 0xb2c)))

# how big is a 0x16010D0 object, from allocation spacing
addr = base + 0x16010d0 - 0x400000
h = addr.to_bytes(4, "little").hex()
pat = "".join("\\x" + h[i:i + 2] for i in range(0, 8, 2))
r = sorted(p for p in pm.pattern_scan_all(pattern=pat.encode(), return_multiple=True)
           if p >= base + hoi3.DATA_SECTION_START)
d = collections.Counter(r[i + 1] - r[i] for i in range(len(r) - 1))
print("\nvftable 0x16010D0: %d objects, modal spacing %s"
      % (len(r), [("0x%x" % k, v) for k, v in d.most_common(4)]))
named = 0
for p in r[:4000]:
    s = hoi3.readString(pm, p + 0xb2c)
    if s:
        named += 1
        if named <= 10:
            print("   0x%x caption=%r frame=%d" % (p, s, struct.unpack("<h", hoi3.readBytes(pm, p + 0x4e, 2))[0]))
print("   of the first 4000, %d have a non-empty string at +0xB2C" % named)
