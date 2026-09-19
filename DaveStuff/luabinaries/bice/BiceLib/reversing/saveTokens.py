"""The game's token table: every id the save code uses, and the key it stands for.

    python saveTokens.py tokens.json            # the running game if there is one
    python saveTokens.py tokens.json --compiled # only the ids built into the executable
    python saveTokens.py tokens.json --static   # the executable alone

`ghidra/saveTokens.json` is the `--compiled` output, committed, and `buildFindings.py` makes
the `SaveToken` enum out of it - which is what has the decompiler print `SaveWriteKey(usage,
writer)` instead of `SaveWriteKey(0x5a6, writer)`. Re-emit it only if the executable changes.

Save code never writes a key as a string. `CPersistent::SaveContents` writes an id - `mov
ecx, 0x5A6; call SaveWriteKey` - and `CPersistent::LoadKey` switches on the same id coming
back. A table built at startup turns that into `usage`. Rebuilding the table is what lets a
field be named from the key the game saves it under, which is how the country's goods pools
were told apart. See CPersistent.hpp.

**The table is only real in a running game.** `BuildTokenTable` (`0x66A050`) makes it on
first use out of a static array of CToken plus a list of tokens registered later, and leaves
a `std::vector<std::string>` at `g_save_tokens_first` (`0x17165B4`) indexed by the id. That
vector is the authority and this script reads it.

Without a game it falls back to scanning the registrations,

    mov edx, <string>        ; the key
    lea esi, [ebp - N]
    call 0xA5A7A0            ; make a string of it
    mov eax, esi
    mov ecx, <id>
    mov esi, <a global>
    call 0xA69440            ; register it under that id

so an id follows its string within a couple of dozen bytes. That finds about half of what
the running game holds - 2056 against 4134 - and agreed with the live table on every one of
them but a single false positive, `=`, which is id 1.
"""
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "ghidra"))
sys.path.insert(0, HERE)

TOKENS_FIRST = 0x17165B4      # std::string*, the id is the index
STRING_SIZE = 0x1C            # what this compiler makes a std::string
TOKENS_COMPILED = 0x168CCA0   # CToken[2138], the ones built into the executable
TOKEN_SIZE = 0x104
TOKENS_COMPILED_END = 0x171480C
PUNCTUATION_BELOW = 24        # the tokenizer's own ids, ahead of anything registered


def live():
    """The table out of the running game, or None if there is no game to read."""
    try:
        import hoi3
        pm = hoi3.attach()
    except Exception:
        return None
    first, end = struct.unpack("<II", hoi3.readBytes(pm, pm.base_address + TOKENS_FIRST, 8))
    if not first or end <= first:
        return None                       # BuildTokenTable has not run yet
    count = (end - first) // STRING_SIZE
    raw = hoi3.readBytes(pm, first, count * STRING_SIZE)
    out = {}
    for i in range(count):
        entry = raw[i * STRING_SIZE:(i + 1) * STRING_SIZE]
        length, capacity = struct.unpack_from("<II", entry, 0x10)
        if capacity >= 16:                # past fifteen characters it is a pointer
            text = hoi3.readBytes(pm, struct.unpack_from("<I", entry, 0)[0], length) or b""
        else:
            text = entry[:length]
        if text:
            out[i] = text.decode("latin1")
    return out


def compiled():
    """Only the tokens built into the executable, which are the ones whose ids are fixed.

    The table the game ends up with holds about twice as many: everything the loaded mod
    defines - resources, cultures, decorations - registers a token too, and those are heap
    objects numbered in load order, so their ids say nothing about the executable. These
    2138 come from a static array and carry their own ids, and they are what the findings
    turn into the SaveToken enum.

    The punctuation - `=`, `{`, `}`, a newline, a tab - is not in that array; the tokenizer
    holds it at the very low ids, under PUNCTUATION_BELOW. Those are compiled in just as
    surely, since the save code writes them as literals (`mov ecx, 4` is `}`), so they are
    taken from the table and added.
    """
    try:
        import hoi3
        pm = hoi3.attach()
    except Exception:
        return None
    count = (TOKENS_COMPILED_END - TOKENS_COMPILED) // TOKEN_SIZE
    raw = hoi3.readBytes(pm, pm.base_address + TOKENS_COMPILED, count * TOKEN_SIZE)
    if not raw:
        return None
    out = {}
    for i in range(count):
        record = raw[i * TOKEN_SIZE:(i + 1) * TOKEN_SIZE]
        text = record[4:].split(b"\0")[0].decode("latin1")
        if text:
            out[struct.unpack_from("<I", record, 0)[0]] = text
    for ident, text in (live() or {}).items():
        if ident < PUNCTUATION_BELOW:
            out.setdefault(ident, text)
    return out


def static():
    """The table as far as the executable alone gives it away."""
    import luabindExtract as LX
    img = LX.Image(LX.EXE)
    base, size, raw, _ = [s for s in img.sections if s[3] == ".text"][0]
    data = img.data[raw:raw + size]

    tokens, clashes = {}, 0
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
    print("%d clashes dropped" % clashes)
    return tokens


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--compiled" in sys.argv:
        tokens = compiled()
        print("the executable's own tokens, read from the running game")
    else:
        tokens = None if "--static" in sys.argv else live()
        print("read from the running game" if tokens else "read from the executable")
        tokens = tokens or static()
    print("%d token ids" % len(tokens))
    json.dump({str(k): v for k, v in sorted(tokens.items())},
              open(args[0], "w") if args else sys.stdout, indent=1)

    for check, expect in ((0x522, "carrier_size"), (0x5A6, "usage"), (3, "{")):
        got = tokens.get(check)
        print("\ncheck: %#x -> %r (expected %r)" % (check, got, expect))
