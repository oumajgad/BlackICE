"""Name a vftable's class from the MSVC complete object locator at vftable-4."""
import struct, sys
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import image

def u32(va):
    return struct.unpack("<I", image.read(va, 4))[0]

def asciiz(va, n=200):
    raw = image.read(va, n)
    i = raw.find(b"\0")
    return raw[:i if i >= 0 else n].decode("latin-1")

def name(vf):
    try:
        col = u32(vf - 4)                 # complete object locator
        sig, off, cdoff, td, chd = struct.unpack("<IIIII", image.read(col, 20))
        return asciiz(td + 8), off, chd, td
    except Exception as ex:
        return "<%s>" % ex, None, None, None

def hierarchy(chd):
    """the base class names, from the class hierarchy descriptor"""
    try:
        sig, attr, numBase, arr = struct.unpack("<IIII", image.read(chd, 16))
        out = []
        raw = image.read(arr, numBase * 4)
        for i in range(numBase):
            bcd = struct.unpack_from("<I", raw, i * 4)[0]
            td = u32(bcd)
            out.append(asciiz(td + 8))
        return out
    except Exception as ex:
        return ["<%s>" % ex]

for a in sys.argv[1:]:
    vf = int(a, 16)
    nm, off, chd, td = name(vf)
    print("0x%08x  %-34s  thisOffset=%s" % (vf, nm, off))
    if chd:
        print("            bases: %s" % " < ".join(hierarchy(chd)))
