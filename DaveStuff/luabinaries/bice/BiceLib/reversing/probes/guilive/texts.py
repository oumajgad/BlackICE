"""For every live gui object: its own name at +0x54 and the string at +0x04."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing\scripts")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]

def u32(a):
    b = hoi3.readBytes(pm, a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

def st(vf):
    return "0x%x" % (vf - base + 0x400000) if vf and base < vf < base + 0x2000000 else "?"

b, e = u32(gui + 0x5c), u32(gui + 0x60)
n = (e - b) // 4
objs = struct.unpack("<%dI" % n, hoi3.readBytes(pm, b, n * 4))

rows = []
for o in objs:
    ovf = st(u32(o))
    t = u32(o + 0x24)
    typename = hoi3.readString(pm, t + 8) if t else None
    own = hoi3.readString(pm, o + 0x54)
    text = hoi3.readString(pm, o + 4)
    parent = u32(o + 0x28)
    pvf = st(u32(parent)) if parent else "-"
    pname = hoi3.readString(pm, parent + 0x54) if parent else None
    rows.append((o, ovf, typename, own, text, pvf, pname))

with open("texts.txt", "w", encoding="utf-8") as f:
    for o, ovf, tn, own, text, pvf, pname in rows:
        f.write("0x%08x %-11s type=%-34s own=%-34s parent=%-11s/%-28s text=%r\n"
                % (o, ovf, tn, own, pvf, pname, text))

agree = sum(1 for r in rows if r[2] and r[2] == r[3])
print("objects %d ; own-name == type-name on %d" % (len(rows), agree))
print("with a non-empty +0x04 string: %d" % sum(1 for r in rows if r[4]))
print()
print("parent kinds:")
for k, c in collections.Counter(r[5] for r in rows).most_common():
    print("   %-12s %d" % (k, c))
print()
print("sample non-empty +0x04:")
shown = 0
for o, ovf, tn, own, text, pvf, pname in rows:
    if text:
        print("   0x%08x %-11s %-28s parent %-22s %r" % (o, ovf, own, pname, text[:60]))
        shown += 1
        if shown > 30:
            break
