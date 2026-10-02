import struct, sys, io, re, collections
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, r"c:\Users\David\GitHub\BlackICE\DaveStuff\luabinaries\bice\BiceLib\reversing")
import image, hoi3

def u32(va):
    return struct.unpack("<I", image.read(va, 4))[0]

def asciiz(va, n=300):
    raw = image.read(va, n)
    i = raw.find(b"\0")
    return raw[:i if i >= 0 else n].decode("latin-1")

names = collections.Counter()
for nm, rec in hoi3.classes().items():
    for t in rec.get("vftables") or []:
        vf = int(t["address"], 16)
        try:
            col = u32(vf - 4)
            sig, off, cdoff, td, chd = struct.unpack("<IIIII", image.read(col, 20))
            sig2, attr, numBase, arr = struct.unpack("<IIII", image.read(chd, 16))
            if not (0 < numBase < 60):
                continue
            raw = image.read(arr, numBase * 4)
            for i in range(numBase):
                bcd = struct.unpack_from("<I", raw, i * 4)[0]
                names[re.sub(r"^\.\?AV|@@$", "", asciiz(u32(bcd) + 8))] += 1
        except Exception:
            pass

pat = re.compile(r"TextBox|Textbox|Listbox|ListBox|Scrollbar|ScrollBar|EditBox|Editbox|Overlap|Checkbox|CheckBox|Icon|Button|Window|Gui|Position", re.I)
known = set(hoi3.classes())
for n in sorted(names):
    if pat.search(n):
        print("%-60s %5d  inExport=%s" % (n, names[n], n in known))
