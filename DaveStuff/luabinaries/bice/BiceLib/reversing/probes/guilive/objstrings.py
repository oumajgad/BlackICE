"""Every std::string-shaped field in an object, by offset, with its contents."""
import struct, sys
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def scan(obj, length=0x200):
    raw = hoi3.readBytes(pm, obj, length)
    if raw is None:
        print("unreadable"); return
    out = []
    for off in range(0, length - 20, 4):
        ln, cap = struct.unpack_from("<II", raw, off + 16)
        if cap == 15 and 0 < ln <= 15:
            s = raw[off:off + ln]
            try:
                t = s.decode("latin-1")
            except Exception:
                continue
            if all(32 <= c < 127 for c in s):
                out.append((off, t, "sso"))
        elif cap > 15 and 15 < ln <= cap and ln < 4096:
            p = struct.unpack_from("<I", raw, off)[0]
            d = hoi3.readBytes(pm, p, ln) if p else None
            if d and all(32 <= c < 127 or c in (10, 13, 9) for c in d):
                out.append((off, d.decode("latin-1"), "heap"))
    for off, t, k in out:
        print("   +0x%-4x %-4s %r" % (off, k, t))

for a in sys.argv[1:]:
    obj = int(a, 16)
    vf = u32(obj)
    nm = hoi3.classNameForVftable(pm, vf) or ("vf 0x%x" % (vf - base + 0x400000))
    t = u32(obj + 0x24)
    print("== 0x%x  %s  type=%s" % (obj, nm, hoi3.readString(pm, t + 8) if t else None))
    scan(obj)
    print()
