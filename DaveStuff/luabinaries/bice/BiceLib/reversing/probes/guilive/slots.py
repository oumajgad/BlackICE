"""Dump a vftable's slots out of the executable, with the first instructions of each body."""
import sys, struct
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import image

def slots(va, n):
    raw = image.read(va, n * 4)
    return struct.unpack("<%dI" % n, raw)

def body(va, n=8):
    out = []
    try:
        for ins in image.decode(va, 48):
            out.append("%s %s" % (ins.mnemonic, ins.op_str))
            if len(out) >= n:
                break
            if ins.mnemonic in ("ret", "jmp"):
                break
    except Exception as ex:
        out.append("<%s>" % ex)
    return "; ".join(out)

for arg in sys.argv[1:]:
    va, n = arg.split(":")
    va = int(va, 16); n = int(n)
    print("=== vftable 0x%x (%d slots)" % (va, n))
    for i, s in enumerate(slots(va, n)):
        print("%3d  +0x%-4x 0x%08x  %s" % (i, i * 4, s, body(s)))
    print()
