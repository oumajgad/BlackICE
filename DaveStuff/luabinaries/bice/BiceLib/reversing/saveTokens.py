"""The game's token table: every id the save code uses, and the key it stands for.

    python saveTokens.py tokens.json

Save code never writes a key as a string. It writes an id - `mov ecx, 0x5A6` and a call -
and a table built at startup turns that into `usage`. Rebuilding the table is what lets a
field be named from the key the game saves it under, which is how the country's goods pools
were told apart.

The registration looks like

    mov edx, <string>        ; the key
    lea esi, [ebp - N]
    call 0xA5A7A0            ; make a string of it
    mov eax, esi
    mov ecx, <id>
    mov esi, <a global>
    call 0xA69440            ; register it under that id

so an id follows its string within a couple of dozen bytes.
"""
import json
import os
import re
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ghidra"))
import luabindExtract as LX

img = LX.Image(LX.EXE)
base, size, raw, _ = [s for s in img.sections if s[3] == ".text"][0]
data = img.data[raw:raw + size]

tokens = {}
clashes = 0
for m in re.finditer(rb"\xBA(....)", data, re.S):          # mov edx, imm32
    pointer = struct.unpack("<I", m.group(1))[0]
    key = img.cstr(pointer) if 0x400000 < pointer < 0x1800000 else None
    if not key or not re.match(r"^[A-Za-z][A-Za-z0-9_]{1,63}$", key):
        continue
    window = data[m.end():m.end() + 40]
    n = window.find(b"\xB9")                                # mov ecx, imm32
    if n < 0 or n + 5 > len(window):
        continue
    ident = struct.unpack_from("<I", window, n + 1)[0]
    if ident > 0xFFFF:
        continue
    if ident in tokens and tokens[ident] != key:
        clashes += 1
        continue
    tokens[ident] = key

print("%d token ids, %d clashes" % (len(tokens), clashes))
json.dump({str(k): v for k, v in sorted(tokens.items())},
          open(sys.argv[1], "w") if len(sys.argv) > 1 else sys.stdout, indent=1)

for check, expect in ((0x522, "carrier_size"),):
    print("\ncheck: %#x -> %s (expected %s)" % (check, tokens.get(check), expect))
