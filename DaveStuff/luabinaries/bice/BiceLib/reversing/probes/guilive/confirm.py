import struct, sys
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return struct.unpack("<I", b)[0] if b else None

idler = hoi3.instances(pm, "CInGameIdler")[0]
gui = hoi3.instances(pm, "CEU3Gui")[0]
gfx = hoi3.instances(pm, "CEU3Graphics")[0]
print("idler 0x%x  gui 0x%x  gfx 0x%x" % (idler, gui, gfx))
print("idler+0x60   = 0x%x  CEU3Gui?      %s" % (u32(idler + 0x60), u32(idler + 0x60) == gui))
print("idler+0x178C = 0x%x  CEU3Graphics? %s" % (u32(idler + 0x178c), u32(idler + 0x178c) == gfx))
sm = u32(idler + 0x1790)
print("idler+0x1790 = 0x%x" % sm)
scene = u32(sm + 0x124)
print("  [sm+0x124]  = 0x%x  class %s" % (scene, hoi3.classNameForVftable(pm, u32(scene)) if scene else None))
print("gui+0x30     = 0x%x  CEU3Graphics? %s" % (u32(gui + 0x30), u32(gui + 0x30) == gfx))
print("gfx+0x6B9BC  = %d   gfx+0x6B9C0 = %d" % (u32(gfx + 0x6b9bc), u32(gfx + 0x6b9c0)))
print("idler+0x1DF0 = 0x%x  +0x1DF4 = 0x%x  +0x1DF8 = %d"
      % (u32(idler + 0x1df0), u32(idler + 0x1df4), u32(idler + 0x1df8)))

def count(vfStatic):
    addr = base + vfStatic - 0x400000
    h = addr.to_bytes(4, "little").hex()
    pat = "".join("\\x" + h[i:i + 2] for i in range(0, 8, 2))
    r = pm.pattern_scan_all(pattern=pat.encode(), return_multiple=True)
    return len([p for p in r if p >= base + hoi3.DATA_SECTION_START])

for vf in (0x16010d0, 0x16086c8, 0x15fe6d0, 0x15ff6dc, 0x1602058, 0x15ffc68):
    print("vftable 0x%x live objects: %d" % (vf, count(vf)))
print("CCombat %d  CLandCombat %d" % (len(hoi3.instances(pm, "CCombat")), len(hoi3.instances(pm, "CLandCombat"))))
