"""The executable as bytes, decoded - shared by the static scanners beside this.

`hoi3.py` is the running game; this is the file on disk. Nothing here needs the game.

**Addresses.** Two kinds, and mixing them up is the single most repeated mistake in this
folder. A *virtual address* is what a disassembler prints and what the RTTI export uses,
based at 0x400000. An *rva* is the offset into the image, which is what `project.json`
and BiceLib want. `toVa()` and `toRva()` convert and **never guess which is which** -
`.text` runs past the image base here, so magnitude tells you nothing. `address()`
parses one off a command line: a bare number is virtual, `rva:` prefixes the other.
"""

import capstone
import pefile

EXE = r"C:\Users\David\Hearts of Iron 3\hoi3_tfh.exe"
IMAGE_BASE = 0x400000

_pe = None
_sections = None


def image():
    """the PE, loaded once"""
    global _pe
    if _pe is None:
        _pe = pefile.PE(EXE, fast_load=True)
    return _pe


def sections():
    """(start va, bytes, name) per section, loaded once"""
    global _sections
    if _sections is None:
        base = image().OPTIONAL_HEADER.ImageBase
        _sections = [(base + s.VirtualAddress, s.get_data(),
                      s.Name.rstrip(b"\x00").decode("latin-1"))
                     for s in image().sections]
    return _sections


def text():
    """(start va, bytes) of .text, which is where the code is"""
    for start, data, name in sections():
        if name.startswith(".text"):
            return start, data
    raise RuntimeError("no .text section")


def toVa(offset):
    """an rva as a virtual address - explicit, never guessed"""
    return offset + IMAGE_BASE


def toRva(address):
    """a virtual address as an rva - what project.json wants"""
    return address - IMAGE_BASE


def both(address):
    """'0x005BB171 (rva 0x1BB171)' - takes a **virtual** address"""
    return "0x%08X (rva 0x%X)" % (address, toRva(address))


def address(text):
    """
    An address off the command line, as a virtual address.

    **Guessing which kind a number is does not work on this image.** `.text` runs to
    about `0x970000`, so an rva is routinely larger than the `0x400000` image base and
    "big means virtual" is wrong - `0x799980` is the rva of a function whose virtual
    address is `0xB99980`. This was got wrong once already, in this very file.

    So: a bare number is a **virtual address**, the way a disassembler and Ghidra print
    one. Write `rva:0x799980` to give the other kind.
    """
    text = text.strip()
    if text.lower().startswith("rva:"):
        return toVa(int(text[4:], 0))
    value = int(text, 0)
    if value < IMAGE_BASE:
        raise ValueError(
            "0x%X is below the image base, so it cannot be a virtual address - write "
            "rva:0x%X if that is what you meant" % (value, value))
    return value


def read(address, length):
    """bytes at a virtual address, across whichever section holds it"""
    for start, data, _ in sections():
        if start <= address < start + len(data):
            return data[address - start:address - start + length]
    return b""


def mapped(address):
    """whether a virtual address is inside a section once the image is loaded

    **Not the same question as `read` answering.** A section's virtual size is usually
    larger than the bytes the file carries: `.data` ends with everything that starts out
    zero, and the loader supplies those rather than the file. `read` returns nothing
    there, so using it to ask "is this address real" says no to every uninitialised
    global - `g_CCurrentGameState` among them, which is the one address in this project
    that is certainly right.
    """
    for section in image().sections:
        start = image().OPTIONAL_HEADER.ImageBase + section.VirtualAddress
        size = max(section.Misc_VirtualSize, section.SizeOfRawData)
        if start <= address < start + size:
            return True
    return False


def engine(detail=True):
    """a 32 bit x86 decoder"""
    cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    cs.detail = detail
    return cs


def decode(address, length, count=0):
    """instructions at a virtual address"""
    return list(engine().disasm(read(address, length), address, count=count))


def asString(address, limit=160):
    """the C string at an address, or None where it is not one"""
    raw = read(address, limit)
    if not raw:
        return None
    body = raw.split(b"\x00")[0]
    if len(body) < 3 or len(body) > limit - 10:
        return None
    if not all(32 <= c < 127 or c in (9, 10, 13) for c in body):
        return None
    return body.decode("latin-1")


def findBytes(needle, section=None):
    """every virtual address holding these bytes"""
    out = []
    for start, data, name in sections():
        if section is not None and not name.startswith(section):
            continue
        at = data.find(needle)
        while at != -1:
            out.append(start + at)
            at = data.find(needle, at + 1)
    return out


def findValue(value, section=".text"):
    """every place holding this exact four byte value, little endian"""
    return findBytes(value.to_bytes(4, "little"), section)


def functionStart(address, limit=0x2500):
    """
    The top of the function an address sits in.

    MSVC pads between functions with int3, so a run of them followed by something that
    looks like a prologue is a boundary. **Not infallible** - a jump table or an inlined
    block looks the same - so treat what comes back as a candidate and check it against
    the disassembly before writing a finding from it.
    """
    start, data = text()
    at = address - start
    if at < 0 or at >= len(data):
        return None
    end = at
    while end > 0 and at - end < limit:
        end -= 1
        if data[end] != 0xCC:
            continue
        candidate = end + 1
        if data[candidate] in (0x55, 0x53, 0x56, 0x57, 0x8B, 0x83, 0x81, 0x6A, 0x68):
            return start + candidate
    return None


def usesMemory(instruction, displacement, base=None):
    """whether an instruction reads or writes [reg + displacement]"""
    for operand in instruction.operands:
        if operand.type != capstone.x86.X86_OP_MEM:
            continue
        if operand.mem.base == 0:
            continue
        if operand.mem.disp != displacement:
            continue
        if base is not None and operand.mem.base != base:
            continue
        return True
    return False
