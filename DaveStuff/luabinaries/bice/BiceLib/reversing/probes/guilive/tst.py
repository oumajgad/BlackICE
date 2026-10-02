"""Walk the gui-type ternary search tree at CGui+0x34 out of the running game."""
import struct, sys, collections
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import hoi3

pm = hoi3.attach()
base = pm.base_address
gui = hoi3.instances(pm, "CEU3Gui")[0]

cache = {}
def rd(a, n=4):
    key = (a, n)
    if key in cache:
        return cache[key]
    v = hoi3.readBytes(pm, a, n)
    cache[key] = v
    return v

def u32(a):
    b = rd(a, 4)
    return None if b is None else struct.unpack("<I", b)[0]

root = u32(gui + 0x38)
print("gui 0x%x  root 0x%x  count@+0x40 %d" % (gui, root, u32(gui + 0x40)))

entries = []   # (name, valuePtr)
seen = set()
def walk(node, prefix, depth=0):
    if not node or node in seen or depth > 400:
        return
    seen.add(node)
    raw = rd(node, 0x14)
    if raw is None:
        return
    value, ch, low, high, eq = struct.unpack("<IIIII", raw)
    c = chr(ch & 0xFF)
    walk(low, prefix)
    if (ch & 0xFF) == 0:
        # terminator node: the name is prefix
        if value:
            entries.append((prefix, value))
    else:
        if value:
            entries.append((prefix + c, value))
        walk(eq, prefix + c, depth + 1)
    walk(high, prefix)

sys.setrecursionlimit(100000)
walk(root, "")
print("nodes visited %d, entries %d" % (len(seen), len(entries)))

# classify each value pointer by its vftable
kinds = collections.Counter()
for name, v in entries:
    vf = u32(v)
    kinds[hoi3.classNameForVftable(pm, vf) or ("rawvf 0x%x" % ((vf - base + 0x400000) if vf and vf > base else (vf or 0)))] += 1
for k, n in kinds.most_common():
    print("%6d  %s" % (n, k))

with open(r"C:\Users\David\AppData\Local\Temp\claude\c--Users-David-GitHub-BlackICE-DaveStuff-luabinaries-bice-BiceLib\c20d19ba-7398-486d-830d-f9de623baa8b\scratchpad\guilive\types.txt", "w") as f:
    for name, v in sorted(entries):
        vf = u32(v)
        nm = hoi3.classNameForVftable(pm, vf)
        if not nm and vf and vf > base:
            nm = "vf 0x%x" % (vf - base + 0x400000)
        f.write("%-50s 0x%08x  %s\n" % (name, v, nm))
print("wrote types.txt")
