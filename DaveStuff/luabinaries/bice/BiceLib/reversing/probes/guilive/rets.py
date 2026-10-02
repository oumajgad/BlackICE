"""The ret immediate of a function, which decides its calling convention."""
import sys
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing\scripts")
import image

for a in sys.argv[1:]:
    va = int(a, 16)
    found = []
    try:
        for ins in image.decode(va, 0x900):
            if ins.mnemonic == "ret":
                found.append((ins.address, ins.op_str or "0"))
            if ins.mnemonic == "int3":
                break
    except Exception as ex:
        found.append(("err", str(ex)))
    print("0x%08x  rets: %s" % (va, ["0x%x:%s" % (x, y) if isinstance(x, int) else str((x, y)) for x, y in found[:6]]))
