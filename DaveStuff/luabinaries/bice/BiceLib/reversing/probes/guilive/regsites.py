"""Where does .text form `reg + <off>` for each of a window's six registries?"""
import sys, struct
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import image

OFFS = [0x324, 0x348, 0x36c, 0x390, 0x3b4, 0x3d8]

def sites(off):
    out = []
    imm = off.to_bytes(4, "little")
    # add reg, imm32 : 81 /0 (C0..C7)
    for b in range(0xC0, 0xC8):
        out += [(a, "add") for a in image.findBytes(bytes([0x81, b]) + imm, ".text")]
    # lea reg, [reg+imm32] : 8D modrm(10) ...
    for modrm in range(0x80, 0xC0):
        out += [(a, "lea") for a in image.findBytes(bytes([0x8D, modrm]) + imm, ".text")]
    # mov reg, [reg+imm32]
    for modrm in range(0x80, 0xC0):
        out += [(a, "mov r,[]") for a in image.findBytes(bytes([0x8B, modrm]) + imm, ".text")]
    return sorted(set(out))

for off in OFFS:
    s = sites(off)
    print("== +0x%x : %d sites" % (off, len(s)))
    for a, kind in s[:14]:
        try:
            ins = image.decode(a, 0x20, count=4)
            txt = "; ".join("%s %s" % (i.mnemonic, i.op_str) for i in ins)
        except Exception:
            txt = "?"
        print("   0x%08x (fn 0x%08x) %-8s %s" % (a, image.functionStart(a), kind, txt[:120]))
    print()
