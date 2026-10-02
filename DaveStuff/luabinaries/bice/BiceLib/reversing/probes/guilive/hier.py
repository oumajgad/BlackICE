"""Every RTTI class's base chain, from the image, filtered to the gui framework."""
import struct, sys, io, re, collections
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing\scripts")
import image, hoi3

def u32(va):
    return struct.unpack("<I", image.read(va, 4))[0]

def asciiz(va, n=300):
    raw = image.read(va, n)
    i = raw.find(b"\0")
    return raw[:i if i >= 0 else n].decode("latin-1")

def chain(vf):
    try:
        col = u32(vf - 4)
        sig, off, cdoff, td, chd = struct.unpack("<IIIII", image.read(col, 20))
        sig2, attr, numBase, arr = struct.unpack("<IIII", image.read(chd, 16))
        if not (0 < numBase < 60):
            return None
        raw = image.read(arr, numBase * 4)
        out = []
        for i in range(numBase):
            bcd = struct.unpack_from("<I", raw, i * 4)[0]
            out.append(asciiz(u32(bcd) + 8))
        return out
    except Exception:
        return None

want = re.compile(r"CWindow|CButton|CTextBox|CListbox|CListBox|CScrollbar|CCheckBox|CEditBox|CIcon|CGuiObject|COverlapping|CInstantTextBox|CFixedWindow|TWindow|TButton", re.I)

hits = collections.defaultdict(list)
for nm, rec in hoi3.classes().items():
    for t in rec.get("vftables") or []:
        vf = int(t["address"], 16)
        c = chain(vf)
        if not c:
            continue
        pretty = [re.sub(r"^\.\?AV|@@$", "", x) for x in c]
        if any(want.search(x) for x in pretty[1:]):
            hits[tuple(pretty[1:])].append((nm, vf))

for bases, members in sorted(hits.items(), key=lambda x: -len(x[1])):
    print("%-3d  %s" % (len(members), " < ".join(bases)))
    for nm, vf in members[:4]:
        print("          %s  0x%x" % (nm, vf))
