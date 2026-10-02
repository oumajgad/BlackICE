"""Given an address, walk back looking for an object start: a dword that is a vftable."""
import struct, sys
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing\scripts")
import hoi3, image

pm = hoi3.attach()
base = pm.base_address

RDATA_LO = 0x1100000
RDATA_HI = 0x1800000

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def looksVftable(v):
    if not v or not (base + RDATA_LO <= v < base + RDATA_HI):
        return False
    # a vftable's first slot is a code pointer inside .text
    f = u32(v)
    return f is not None and base + 0x1000 <= f < base + 0xC00000

for a in sys.argv[1:]:
    addr = int(a, 16)
    print("== holder 0x%x" % addr)
    for back in range(0, 0x900, 4):
        p = addr - back
        v = u32(p)
        if looksVftable(v):
            sva = v - base + 0x400000
            nm = hoi3.classNameForVftable(pm, v)
            print("   object start 0x%x (-0x%x)  vftable 0x%x  %s" % (p, back, sva, nm or "(no RTTI)"))
            # if it is a gui object, name it
            t = u32(p + 0x24)
            if t:
                tn = hoi3.readString(pm, t + 8)
                if tn:
                    print("        type name: %s" % tn)
            break
    else:
        print("   no vftable within 0x900 bytes back")
