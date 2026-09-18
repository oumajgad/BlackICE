"""Recovers every function the game exposes to Lua, with its C++ address and signature.

    python luabindExtract.py                 # writes luabind.json next to this file

`script/LUA API.txt` is the game's own luabind registration source (lua_ai.cpp), so it
names every C++ function behind the Lua API, but not where they are. This finds them.

How, in four steps - none of which needs the game running:

1. **Run the registration.** `SetupAI` (VA 0x8EAE30) is emulated with unicorn. It builds
   one registration object per `.def`, and each one holds its name at +8 and the C++
   member function pointer at +0xC (or +0x10 for a two word pointer). Allocation, the
   class bookkeeping and everything touching Lua are stubbed, so the objects are simply
   left in emulated memory to be read afterwards, together with the class each was
   added to. Emulating rather than pattern matching is what makes this complete: the
   compiler passes names and targets in half a dozen different ways, and the
   emulator does not care which.

2. **Match it to the API file.** Class by class, name by name, in order. Every one of
   them has to line up, and the script stops if any does not.

3. **Ask luabind for the signature.** Every function object carries a
   `format_signature` method, used for Lua error messages, that writes the full C++
   signature: return type, then every parameter. Emulating it with `lua_pushstring`
   captured and `get_class_name` answered from RTTI gives the text directly, e.g.
   `CCountryTag const& GetActor(CWarGoal const&)`.

4. **Resolve what the pointer points at.** Virtual methods register a vcall thunk, so
   the slot is looked up in the class's vftable from the RTTI export; tiny accessors
   (`lea eax,[ecx+N]; ret`) give a field offset; luabind's `construct` gives the size of
   every class with a Lua constructor.

Needs: pefile, capstone, unicorn. The executable and the RTTI export default to where
they are on this machine and can be overridden with HOI3_EXE / OPENHOI3_CLASSES.
"""

import collections
import ctypes
import json
import os
import re
import struct
import sys

import capstone
import pefile
from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EBP,
                               UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_GDTR,
                               UC_X86_REG_SS, UC_X86_REG_DS, UC_X86_REG_ES,
                               UC_X86_REG_FS)

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get("HOI3_EXE", r"C:\Users\David\Hearts of Iron 3\hoi3_tfh.exe")
CLASS_JSON = os.environ.get(
    "OPENHOI3_CLASSES", r"C:\Users\David\GitHub\OpenHOI3\OpenHOI3\docs\hoi3_tfh-classes.json")
API_FILE = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "..", "..", "script", "LUA API.txt"))
OUT = os.path.join(HERE, "luabind.json")

IMAGE_BASE = 0x400000

# --- the addresses this depends on, all VAs in this build ------------------------------
SETUP_AI = 0x8EAE30                 # void SetupAI(lua_State*), the whole module[...] block
OPERATOR_NEW = 0xB9602F
OPERATOR_DELETE = 0xB95F9B
REGISTRATION_CTOR = 0xB7EA30        # luabind::detail::registration::registration()
CLASS_BASE_CTOR = 0xB81910          # class_base::class_base(char const* name)
CLASS_BASE_INIT = 0xB809F0          # class_base::init(type_id, class_id, type_id, class_id)
ADD_MEMBER = 0xB80B70               # class_base::add_member(registration*)
ADD_DEFAULT_MEMBER = 0xB80C00       # class_base::add_default_member(registration*)
ADD_INNER_SCOPE = 0xB80A20          # class_base::add_inner_scope(scope&)
ADD_CAST = (0xB819A0, 0xB81A50)     # the cast registrations, 3 and 2 arguments
ADD_ENUM_VALUE = 0xB810E0           # enum_maker value(name, number)
LUABIND_OPEN = 0xB7EFD0
GET_CLASS_NAME = 0xB81100           # std::string get_class_name(lua_State*, type_id const&)
BASE_REGISTRATION_VFT = 0x159FD90


# --- the executable ----------------------------------------------------------------------

class Image:
    def __init__(self, path):
        self.pe = pefile.PE(path)
        self.data = open(path, "rb").read()
        self.sections = [(IMAGE_BASE + s.VirtualAddress, s.Misc_VirtualSize, s.PointerToRawData,
                          s.Name.rstrip(b"\0").decode()) for s in self.pe.sections]
        text = [s for s in self.sections if s[3] == ".text"][0]
        self.text = (text[0], text[0] + text[1])
        rdata = [s for s in self.sections if s[3] == ".rdata"][0]
        self.rdata = (rdata[0], rdata[0] + rdata[1])
        self.cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)

    def read(self, va, n):
        for base, size, raw, _ in self.sections:
            if base <= va < base + size:
                o = raw + va - base
                return self.data[o:o + n]
        return None

    def u32(self, va):
        return struct.unpack("<I", self.read(va, 4))[0]

    def cstr(self, va):
        d = self.read(va, 256)
        if not d:
            return None
        z = d.split(b"\0")[0]
        return z.decode("latin1") if z and all(32 <= c < 127 for c in z) else None

    def import_slot(self, name):
        for dll in self.pe.DIRECTORY_ENTRY_IMPORT:
            for imp in dll.imports:
                if imp.name and imp.name.decode() == name:
                    return imp.address
        raise KeyError(name)

    def type_name(self, vftable):
        """The demangled RTTI name of the class a vftable belongs to."""
        locator = self.u32(vftable - 4)
        return demangle_type(self.cstr(self.u32(locator + 0xC) + 8))

    def is_code(self, va):
        return self.text[0] <= va < self.text[1]

    def body(self, va, limit=200):
        """Instructions from va up to the first ret: (address, mnemonic, operands)."""
        out = []
        code = self.read(va, limit * 15)
        for ins in self.cs.disasm_lite(code, va):
            out.append((ins[0], ins[2], ins[3]))
            if ins[2] == "ret" or len(out) >= limit:
                break
        return out


# --- the emulator --------------------------------------------------------------------------

class Emu:
    STACK, HEAP, TEB, GDT, IMPORTS, END = 0x10000000, 0x20000000, 0x30000000, 0x31000000, 0x32000000, 0x0F000000

    def __init__(self, image):
        pe, data = image.pe, image.data
        self.uc = uc = Uc(UC_ARCH_X86, UC_MODE_32)
        uc.mem_map(IMAGE_BASE, (pe.OPTIONAL_HEADER.SizeOfImage + 0xFFF) & ~0xFFF)
        uc.mem_write(IMAGE_BASE, data[:pe.OPTIONAL_HEADER.SizeOfHeaders])
        for s in pe.sections:
            uc.mem_write(IMAGE_BASE + s.VirtualAddress,
                         data[s.PointerToRawData:s.PointerToRawData + min(s.SizeOfRawData, s.Misc_VirtualSize)])
        uc.mem_map(self.STACK, 0x100000)
        uc.mem_map(self.HEAP, 0x8000000)
        self.heap = self.HEAP
        uc.mem_map(self.END, 0x1000)

        # fs:[0] is the SEH chain every function here touches. Unicorn cannot set the FS
        # base in 32 bit mode, so it has to come from a descriptor table.
        uc.mem_map(self.TEB, 0x1000)
        uc.mem_write(self.TEB, struct.pack("<I", 0xFFFFFFFF))
        uc.mem_map(self.GDT, 0x1000)

        def entry(base, limit, access, flags):
            v = (limit & 0xFFFF) | (base & 0xFFFFFF) << 16 | (access & 0xFF) << 40 \
                | ((limit >> 16) & 0xF) << 48 | (flags & 0xF) << 52 | ((base >> 24) & 0xFF) << 56
            return struct.pack("<Q", v)
        uc.mem_write(self.GDT + 8, entry(0, 0xFFFFF, 0x9A, 0xC))
        uc.mem_write(self.GDT + 16, entry(0, 0xFFFFF, 0x92, 0xC))
        uc.mem_write(self.GDT + 24, entry(self.TEB, 0xFFF, 0x92, 0x4))
        uc.reg_write(UC_X86_REG_GDTR, (0, self.GDT, 31, 0))
        for reg, sel in ((UC_X86_REG_SS, 0x10), (UC_X86_REG_DS, 0x10), (UC_X86_REG_ES, 0x10), (UC_X86_REG_FS, 0x18)):
            uc.reg_write(reg, sel)

        # Imports are not bound in the file, so every slot gets an address of its own
        # that the hook recognises and answers.
        uc.mem_map(self.IMPORTS, 0x10000)
        uc.mem_write(self.IMPORTS, b"\xC3" * 0x10000)
        self.imports = {}
        n = 0
        for dll in pe.DIRECTORY_ENTRY_IMPORT:
            for imp in dll.imports:
                stub = self.IMPORTS + 4 * n
                n += 1
                uc.mem_write(imp.address, struct.pack("<I", stub))
                self.imports[stub] = imp.name.decode() if imp.name else "#%d" % imp.ordinal

        self.stubs = {OPERATOR_NEW: lambda e: e.ret(0, e.alloc(e.arg(0))),
                      OPERATOR_DELETE: lambda e: e.ret(0, 0)}
        self.import_handlers = {}
        self.stopped_on = None
        uc.hook_add(UC_HOOK_CODE, self._hook)

    def _hook(self, uc, address, size, user):
        if address in self.stubs:
            self.stubs[address](self)
        elif self.IMPORTS <= address < self.IMPORTS + 0x10000:
            name = self.imports.get(address, "?")
            if name in self.import_handlers:
                self.import_handlers[name](self)
            elif name.startswith("lua"):
                self.ret(0, 0)              # the Lua API is cdecl, so there is nothing to pop
            else:
                self.stopped_on = name
                uc.emu_stop()

    def alloc(self, n):
        a = self.heap
        self.heap += (n + 0x1F) & ~0xF
        self.uc.mem_write(a, b"\0" * max(n, 1))
        return a

    def u32(self, a):
        return struct.unpack("<I", self.uc.mem_read(a, 4))[0]

    def w32(self, a, v):
        self.uc.mem_write(a, struct.pack("<I", v & 0xFFFFFFFF))

    def cstr(self, a):
        try:
            z = bytes(self.uc.mem_read(a, 256)).split(b"\0")[0]
            return z.decode("latin1") if z and all(32 <= c < 127 for c in z) else None
        except UcError:
            return None

    def esp(self):
        return self.uc.reg_read(UC_X86_REG_ESP)

    def ecx(self):
        return self.uc.reg_read(UC_X86_REG_ECX)

    def arg(self, i):
        return self.u32(self.esp() + 4 + 4 * i)

    def ret(self, pop, eax=None):
        esp = self.esp()
        if eax is not None:
            self.uc.reg_write(UC_X86_REG_EAX, eax & 0xFFFFFFFF)
        self.uc.reg_write(UC_X86_REG_EIP, self.u32(esp))
        self.uc.reg_write(UC_X86_REG_ESP, esp + 4 + pop)

    def call(self, address, args, ecx=0, limit=5000000):
        """Runs address with args pushed cdecl style; None on success, else why it stopped."""
        esp = self.STACK + 0xF0000
        for a in reversed(args):
            esp -= 4
            self.w32(esp, a)
        esp -= 4
        self.w32(esp, self.END)
        self.uc.reg_write(UC_X86_REG_ESP, esp)
        self.uc.reg_write(UC_X86_REG_EBP, esp)
        self.uc.reg_write(UC_X86_REG_ECX, ecx)
        self.stopped_on = None
        try:
            self.uc.emu_start(address, self.END, count=limit)
        except UcError as error:
            return "%s at %08X" % (error, self.uc.reg_read(UC_X86_REG_EIP))
        if self.stopped_on:
            return "import " + self.stopped_on
        if self.uc.reg_read(UC_X86_REG_EIP) != self.END:
            return "stopped at %08X" % self.uc.reg_read(UC_X86_REG_EIP)
        return None


# --- step 1: run the registration ------------------------------------------------------

def run_registration(image):
    emu = Emu(image)
    events = []

    def class_ctor(e):
        this = e.ecx()
        e.w32(this + 4, e.alloc(0x200))     # the class_registration the others write into
        events.append(("class", this, e.cstr(e.arg(0))))
        e.ret(4, this)

    def class_init(e):
        events.append(("classinit", e.ecx(), e.u32(e.arg(0)), e.u32(e.arg(2))))
        e.ret(0x10, e.ecx())

    def registration(e):
        this = e.ecx()
        e.w32(this, BASE_REGISTRATION_VFT)
        e.w32(this + 4, 0)
        events.append(("registration", this))
        e.ret(0, this)

    def add_member(kind):
        def handler(e):
            events.append((kind, e.ecx(), e.arg(0)))
            e.ret(4)
        return handler

    def inner_scope(e):
        chain, head = [], e.u32(e.arg(0))
        while head and len(chain) < 1000:       # a scope is a linked list through +4
            chain.append(head)
            head = e.u32(head + 4)
        events.append(("scope", e.ecx(), chain))
        e.w32(e.arg(0), 0)
        e.ret(4, e.ecx())

    def enum_value(e):
        events.append(("enum", e.ecx(), e.cstr(e.arg(0)), e.arg(1)))
        e.ret(8)

    emu.stubs.update({
        CLASS_BASE_CTOR: class_ctor, CLASS_BASE_INIT: class_init, REGISTRATION_CTOR: registration,
        ADD_MEMBER: add_member("member"), ADD_DEFAULT_MEMBER: add_member("default_member"),
        ADD_INNER_SCOPE: inner_scope, ADD_ENUM_VALUE: enum_value,
        ADD_CAST[0]: lambda e: e.ret(0xC), ADD_CAST[1]: lambda e: e.ret(8),
        LUABIND_OPEN: lambda e: e.ret(0),
    })
    why = emu.call(SETUP_AI, [emu.alloc(0x1000)])
    # It is expected to stop at the very end, where module_ hands the finished scope to
    # Lua through an import no stub answers. Anything else means it did not get there.
    counts = collections.Counter(e[0] for e in events)
    print("registration: %s, stopped: %s" % (dict(counts), why))

    objects = {}
    for e in events:
        if e[0] == "registration":
            o = e[1]
            objects[o] = [emu.u32(o + i) for i in range(0, 0x20, 4)]
    return events, objects


# --- step 2: the API file ------------------------------------------------------------------

def split_top(s):
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "(<[":
            depth += 1
        elif ch in ")>]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return [p.strip() for p in parts]


def parse_api(path):
    text = re.sub(r"//[^\n]*", "", open(path).read())
    head = re.compile(r'class_<|\.enum_\(|(?<![\w])value\(|(?<![\w])\.?def(?:_readwrite|_readonly)?\(')
    classes, cur, i = [], None, 0

    def balanced(start):
        depth = 0
        for j in range(start, len(text)):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    return j + 1
        raise ValueError("unbalanced parenthesis at %d" % start)

    while True:
        m = head.search(text, i)
        if not m:
            break
        token = m.group(0)
        if token == "class_<":
            depth, j = 1, m.end()
            while depth:
                depth += {"<": 1, ">": -1}.get(text[j], 0)
                j += 1
            parts = split_top(text[m.end():j - 1])
            lua = re.match(r'\s*\(\s*"([^"]+)"\s*\)', text[j:])
            cur = {"cpp": parts[0], "bases": parts[1:], "lua": lua.group(1),
                   "members": [], "scope": [], "ctors": [], "ops": [], "enums": []}
            classes.append(cur)
            i = j + lua.end()
            continue
        close = balanced(m.end() - 1)
        inner = text[m.end():close - 1].strip()
        i = close
        if cur is None or token == ".enum_(":
            continue
        if token == "value(":
            a = split_top(inner)
            cur["enums"].append((a[0].strip('"'), a[1]))
            continue
        args = split_top(inner)
        if token.startswith(".def_"):
            cur["members"].append({"kind": "field", "name": args[0].strip('"'),
                                   "cpp": args[1].lstrip("&").strip(), "readonly": "readonly" in token})
        elif args[0].startswith('"'):
            refs = re.findall(r"&\s*([A-Za-z_]\w*(?:<[^()]*?>)?(?:::~?\w+)*)", args[1])
            cpp = refs[-1] if refs else args[1].strip()
            entry = {"kind": "method" if token == ".def(" else "function", "name": args[0].strip('"'),
                     "cpp": cpp, "policy": ", ".join(args[2:])}
            (cur["members"] if token == ".def(" else cur["scope"]).append(entry)
        elif args[0].startswith("constructor<"):
            cur["ctors"].append(args[0][len("constructor<"):args[0].rindex(">")].strip())
        else:
            cur["ops"].append(inner)
    return classes


# --- step 3: signatures ----------------------------------------------------------------------

def demangle_type(mangled):
    """'.?AVCString@@' -> 'CString', through the system's own undecorator"""
    buf = ctypes.create_string_buffer(1024)
    n = ctypes.windll.dbghelp.UnDecorateSymbolName(mangled[1:].encode(), buf, 1024, 0x2800)
    name = buf.value.decode() if n else mangled
    for prefix in ("class ", "struct ", "union ", "enum "):
        name = name.replace(prefix, "")
    return name


def function_object_vftable(image, registration_vft):
    """The vftable of the function object a registration's register_ builds."""
    seen, frontier = set(), [image.u32(registration_vft + 4)]
    for _ in range(3):
        following = []
        for f in frontier:
            if f in seen:
                continue
            seen.add(f)
            for _, mnemonic, ops in image.body(f, 150):
                m = re.match(r"dword ptr \[e\w\w\], (0x[0-9a-f]+)$", ops) if mnemonic == "mov" else None
                if m:
                    v = int(m.group(1), 16)
                    if image.rdata[0] <= v < image.rdata[1] and v != BASE_REGISTRATION_VFT \
                            and image.is_code(image.u32(v + 8)):
                        return v
                if mnemonic == "call" and ops.startswith("0x"):
                    following.append(int(ops, 16))
        frontier = following
    return None


class Signatures:
    def __init__(self, image):
        self.emu = emu = Emu(image)
        self.pieces = []
        self.enums = set()

        def push_string(e):
            self.pieces.append(e.cstr(e.arg(1)) or "?")
            e.ret(0, 0)

        def concat(e):
            n = e.arg(1)
            if 1 < n <= len(self.pieces):
                joined = "".join(self.pieces[-n:])
                del self.pieces[-n:]
                self.pieces.append(joined)
            e.ret(0, 0)

        def class_name(e):
            result, type_id = e.arg(0), e.arg(2)
            mangled = e.cstr(e.u32(type_id) + 8)
            name = demangle_type(mangled)
            if mangled.startswith(".?AW4"):
                self.enums.add(name)
            raw = name.encode()
            if len(raw) < 16:                   # MSVC std::string: inline under 16
                e.uc.mem_write(result, raw + b"\0")
            else:
                p = e.alloc(len(raw) + 1)
                e.uc.mem_write(p, raw + b"\0")
                e.w32(result, p)
            e.w32(result + 0x10, len(raw))
            e.w32(result + 0x14, max(15, len(raw)))
            e.ret(0, result)

        emu.import_handlers.update({"lua_pushstring": push_string, "lua_concat": concat})
        emu.stubs[GET_CLASS_NAME] = class_name
        self.L = emu.alloc(0x100)

    def of(self, fo_vft, name):
        del self.pieces[:]
        emu = self.emu
        this = emu.alloc(0x40)
        emu.w32(this, fo_vft)
        text = emu.alloc(len(name) + 1)
        emu.uc.mem_write(text, name.encode() + b"\0")
        why = emu.call(emu.u32(fo_vft + 8), [self.L, text], ecx=this)
        return (None, why) if why else ("".join(self.pieces), None)


BUILTINS = {"void", "bool", "char", "signed char", "unsigned char", "short", "unsigned short", "int",
            "unsigned int", "long", "unsigned long", "__int64", "unsigned __int64", "float", "double"}


def parse_type(text, enums):
    """'CCountryTag const&' -> {'text', 'base', 'pointers', 'reference', 'category'}"""
    t = text.strip()
    reference = t.endswith("&")
    t = t.rstrip("&").strip()
    pointers = 0
    while True:
        t = re.sub(r"\s+const$", "", t).strip()
        if t.endswith("*"):
            pointers += 1
            t = t[:-1].strip()
        else:
            break
    base = re.sub(r"^const\s+|\s+const$", "", t).strip()
    if pointers or reference:
        category = "pointer"
    elif base in BUILTINS:
        category = "builtin"
    elif base in enums:
        category = "enum"
    else:
        category = "class"                 # by value: needs its size, and a hidden pointer as a return
    return {"text": text.strip(), "base": base, "pointers": pointers, "reference": reference,
            "category": category}


def function_type(registration_type):
    """
    The C++ type of what was registered, read out of the registration's template arguments:

        memfun_registration<CWarGoal,bool (__thiscall CWarGoal::*)(void)const ,null_type>
        -> return bool, __thiscall, owner CWarGoal, no parameters, const

    The owner is the class that declares the method, which for an inherited one is the
    base rather than the class it was registered on. None for anything that is not a
    member or free function registration.
    """
    m = re.search(r"(?:memfun|function)_registration<", registration_type)
    if not m:
        return None
    inner = registration_type[m.end():]
    cc = re.search(r" \((__\w+) ?([\w:<>, *]*?)(?:::)?\*\)\(", inner)
    if not cc:
        return None
    head = inner[:cc.start()]
    if "memfun_registration<" in registration_type:
        ret = ",".join(split_top(head)[1:])     # the first argument is the class
    else:
        ret = head
    depth, j = 1, cc.end()
    while depth:
        depth += {"(": 1, ")": -1}.get(inner[j], 0)
        j += 1
    params = [p for p in split_top(inner[cc.end():j - 1]) if p and p != "void"]
    return {"return": ret.strip(), "convention": cc.group(1), "owner": cc.group(2).strip() or None,
            "params": params, "const": inner[j:j + 5] == "const"}


def parse_signature(sig, enums):
    m = re.match(r"^(.*?)\s*(\w+)\((.*)\)$", sig)
    if not m:
        return None
    params = [p for p in split_top(m.group(3)) if p]
    return {"return": parse_type(m.group(1), enums), "params": [parse_type(p, enums) for p in params]}


# --- step 4: what the pointers point at --------------------------------------------------

def load_rtti():
    return {c["name"]: c for c in json.load(open(CLASS_JSON, encoding="utf-8"))["classes"]}


def introducer(rtti, cls, impl):
    """The class in cls's primary base chain that introduced impl, if the export says so."""
    found, seen, queue = None, set(), [cls]
    while queue:
        name = queue.pop(0)
        if name in seen or name not in rtti:
            continue
        seen.add(name)
        for i in rtti[name].get("introduces", []):
            if int(i["address"], 16) == impl and i.get("vftable_offset", 0) == 0:
                found = name
        queue.extend(b["name"] for b in rtti[name].get("bases", []) if b.get("offset", 0) == 0)
    return found


ACCESSORS = [
    (re.compile(r"^lea eax, \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "address"),
    (re.compile(r"^lea eax, \[ecx\]$"), "address0"),
    (re.compile(r"^mov eax, dword ptr \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "dword"),
    (re.compile(r"^mov al, byte ptr \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "byte"),
    (re.compile(r"^fld dword ptr \[ecx \+ (0x[0-9a-f]+|\d+)\]$"), "float"),
]


# A class of one dword returned by value comes back through a pointer the caller passes,
# so such an accessor cannot be two instructions: it needs a frame to reach that argument.
# CFixedPoint is the one that matters - most of a unit definition is read this way.
BY_VALUE_ACCESSOR = re.compile(
    r"^push ebp; mov ebp, esp; "
    r"(?:mov (e\w\w), dword ptr \[ecx(?: \+ (0x[0-9a-f]+|\d+))?\]; "
    r"mov (e\w\w), dword ptr \[ebp \+ 8\]"
    r"|mov (?P<p2>e\w\w), dword ptr \[ebp \+ 8\]; "
    r"mov (?P<r2>e\w\w), dword ptr \[ecx(?: \+ (?P<o2>0x[0-9a-f]+|\d+))?\])"
    r"; mov dword ptr \[(?P<into>e\w\w)\], (?P<from>e\w\w); pop ebp$")


# The same for a class of two dwords - fpml::fixed_point<__int64,48,15>, which the
# leadership distribution and anything else counted in 64 bits is made of.
BY_VALUE_ACCESSOR8 = re.compile(
    r"^mov (?P<lo>e\w\w), dword ptr \[ecx \+ (?P<at>0x[0-9a-f]+|\d+)\]; "
    r"mov (?P<into>e\w\w), dword ptr \[ebp \+ 8\]; "
    r"mov (?P<hi>e\w\w), dword ptr \[ecx \+ (?P<at4>0x[0-9a-f]+|\d+)\]; "
    r"mov dword ptr \[(?P=into)\], (?P=lo); mov dword ptr \[(?P=into) \+ 4\], (?P=hi)$")


def accessor_field(image, target):
    """(offset, how) when target is nothing but a read of one member and a ret."""
    code = image.body(target, 11)
    if len(code) == 2 and code[1][1] == "ret" and not code[1][2]:
        ops = "%s %s" % (code[0][1], code[0][2])
        for pattern, how in ACCESSORS:
            m = pattern.match(ops)
            if m:
                return (0 if how == "address0" else int(m.group(1), 0)), how
        return None
    if len(code) == 7 and code[6][1] == "ret" and code[6][2] == "4":
        m = BY_VALUE_ACCESSOR.match("; ".join(("%s %s" % (i[1], i[2])).strip() for i in code[:6]))
        if m:
            value, pointer = m.group(1) or m.group("r2"), m.group(3) or m.group("p2")
            if m.group("into") == pointer and m.group("from") == value:
                return int(m.group(2) or m.group("o2") or "0", 0), "byvalue"
    if len(code) == 9 and code[8][1] == "ret" and code[8][2] == "4" \
            and [i[1:] for i in code[:2]] == [("push", "ebp"), ("mov", "ebp, esp")] \
            and code[7][1:] == ("pop", "ebp"):
        m = BY_VALUE_ACCESSOR8.match("; ".join(("%s %s" % (i[1], i[2])).strip() for i in code[2:7]))
        if m and int(m.group("at4"), 0) == int(m.group("at"), 0) + 4:
            return int(m.group("at"), 0), "byvalue"
    return None


def construct_size(image, fo_vft):
    """
    sizeof the class and, when not inlined, its constructor, from luabind's construct.

    construct<T>::apply opens with lua_pushvalue, lua_touserdata and lua_settop, then
    allocates the object. Only an allocation right after that counts: constructors often
    inline other allocations - the game state singleton's among them - and the first
    `push N; call new` found anywhere would be one of those.
    """
    touserdata = "dword ptr [0x%x]" % image.import_slot("lua_touserdata")
    seen, frontier = set(), [image.u32(fo_vft + 4)]
    for _ in range(4):
        following = []
        for f in frontier:
            if f in seen:
                continue
            seen.add(f)
            code = image.body(f, 250)
            opened = [k for k in range(len(code)) if code[k][1] == "call" and code[k][2] == touserdata]
            for k in range(1, len(code)):
                if not opened or not opened[0] < k <= opened[0] + 12:
                    continue
                if code[k][1] == "call" and code[k][2] == "0x%x" % OPERATOR_NEW \
                        and code[k - 1][1] == "push" and re.match(r"^(0x[0-9a-f]+|\d+)$", code[k - 1][2]):
                    size = int(code[k - 1][2], 0)
                    ctor = None
                    for j in range(k + 1, min(k + 12, len(code))):
                        if code[j][1] == "mov" and code[j][2] == "ecx, eax" and j + 1 < len(code) \
                                and code[j + 1][1] == "call" and code[j + 1][2].startswith("0x"):
                            ctor = int(code[j + 1][2], 16)
                            break
                    return size, ctor
            following += [int(o, 16) for _, m, o in code if m == "call" and o.startswith("0x")]
        frontier = following
    return None, None


def field_name(method):
    for prefix in ("Get",):
        if method.startswith(prefix) and len(method) > len(prefix):
            return method[len(prefix):]
    return method[0].lower() + method[1:]


# --- putting it together ---------------------------------------------------------------------

def main():
    image = Image(EXE)
    rtti = load_rtti()
    api = {c["lua"]: c for c in parse_api(API_FILE)}
    events, objects = run_registration(image)
    signatures = Signatures(image)

    class_of, rtti_of = {}, {}
    per_class = collections.OrderedDict()
    for e in events:
        if e[0] == "class":
            class_of[e[1]] = e[2]
            per_class[e[2]] = {"members": [], "scope": [], "ctors": [], "ops": [], "enums": []}
        elif e[0] == "classinit":
            rtti_of[class_of[e[1]]] = image.cstr(e[2] + 8)
        elif e[0] == "enum":
            per_class[class_of[e[1]]]["enums"].append((e[2], e[3]))
        elif e[0] in ("member", "scope"):
            bucket = per_class[class_of[e[1]]]
            for o in (e[2] if e[0] == "scope" else [e[2]]):
                words = objects[o]
                item = {"vft": words[0], "name": image.cstr(words[2]) if words[2] else None, "payload": words[3:]}
                if e[0] == "scope":
                    bucket["scope"].append(item)
                elif item["name"] is None:
                    bucket["ctors"].append(item)
                elif item["name"].startswith("__"):
                    bucket["ops"].append(item)
                else:
                    bucket["members"].append(item)

    problems, classes, functions = [], [], []
    for lua, found in per_class.items():
        declared = api.get(lua)
        if declared is None:
            problems.append("class %s is registered but not in the API file" % lua)
            continue
        rtti_name = demangle_type(rtti_of[lua]) if rtti_of.get(lua) else None
        record = {"lua": lua, "cpp": declared["cpp"], "rtti": rtti_name, "mangled": rtti_of.get(lua),
                  "bases": declared["bases"], "size": None, "constructors": [], "fields": [],
                  "enums": [{"name": n, "value": v} for n, v in found["enums"]]}
        classes.append(record)

        for kind in ("members", "scope"):
            names_found = [x["name"] for x in found[kind]]
            names_declared = [x["name"] for x in declared[kind]]
            if names_found != names_declared:
                problems.append("%s %s differ:\n  registered %s\n  declared   %s" % (lua, kind, names_found, names_declared))
                continue
            for item, decl in zip(found[kind], declared[kind]):
                fo = function_object_vftable(image, item["vft"])
                sig, why = signatures.of(fo, item["name"]) if fo else (None, "no function object")
                if sig is None:
                    problems.append("%s.%s: no signature (%s)" % (lua, item["name"], why))
                    continue
                parsed = parse_signature(sig, signatures.enums)
                if decl["kind"] == "field":
                    record["fields"].append({"name": item["name"], "offset": item["payload"][0],
                                             "type": parsed["return"]["text"], "readonly": decl.get("readonly", False),
                                             "evidence": "luabind def_readwrite"})
                    continue
                code = [v for v in item["payload"] if image.is_code(v)]
                registered = image.type_name(item["vft"])
                ftype = function_type(registered)
                functions.append({"class": lua, "cpp_class": declared["cpp"], "rtti_class": rtti_name,
                                  "kind": decl["kind"], "lua_name": item["name"], "cpp": decl["cpp"],
                                  "policy": decl.get("policy", ""), "pointer": code[0] if code else None,
                                  "signature": sig, "parsed": parsed, "registered_as": registered,
                                  "function_type": ftype, "method": bool(ftype and ftype["owner"])})

        for item, ctor_args in zip(found["ctors"], declared["ctors"]):
            fo = function_object_vftable(image, item["vft"])
            sig, _ = signatures.of(fo, "__init") if fo else (None, None)
            size, ctor = construct_size(image, fo) if fo else (None, None)
            record["constructors"].append({"arguments": ctor_args, "signature": sig,
                                           "size": size, "address": ctor})
            if size:
                record["size"] = size
        if len(found["ctors"]) != len(declared["ctors"]):
            problems.append("%s: %d constructors registered, %d declared" % (lua, len(found["ctors"]), len(declared["ctors"])))
        for item in found["ops"]:
            fo = function_object_vftable(image, item["vft"])
            sig, _ = signatures.of(fo, item["name"]) if fo else (None, None)
            code = [v for v in item["payload"] if image.is_code(v)]
            functions.append({"class": lua, "cpp_class": declared["cpp"], "rtti_class": rtti_name,
                              "kind": "operator", "lua_name": item["name"], "cpp": item["name"],
                              "pointer": code[0] if code else None, "signature": sig,
                              "parsed": parse_signature(sig, signatures.enums) if sig else None, "method": False})

    if problems:
        print("\n".join(problems))
        sys.exit("the registrations and the API file do not agree - nothing written")

    # Resolve thunks, and read fields out of accessors.
    by_lua = {c["lua"]: c for c in classes}
    for f in functions:
        f["address"] = f["pointer"]
        if f["pointer"] is None:
            continue
        code = image.body(f["pointer"], 3)
        if len(code) >= 2 and code[0][1:] == ("mov", "eax, dword ptr [ecx]") and code[1][1] == "jmp":
            m = re.match(r"^dword ptr \[eax(?: \+ (0x[0-9a-f]+|\d+))?\]$", code[1][2])
            if m:
                offset = int(m.group(1), 0) if m.group(1) else 0
                f["vcall_thunk"] = f["pointer"]
                f["vtable_slot"] = offset // 4
                tables = [t for t in rtti.get(f["rtti_class"], {}).get("vftables", []) if t.get("object_offset", 0) == 0]
                if tables:
                    impl = image.u32(int(tables[0]["address"], 16) + offset)
                    f["address"] = impl
                    f["introduced_by"] = introducer(rtti, f["rtti_class"], impl)
                else:
                    f["address"] = None         # an interface: only the thunk can be named
        elif code and code[0][1] == "add" and code[0][2].startswith("ecx, ") and len(code) > 1 \
                and code[1][1] == "jmp" and code[1][2].startswith("0x"):
            f["adjustor_thunk"] = f["pointer"]
            f["address"] = int(code[1][2], 16)

        if f["method"] and f["address"] and f["parsed"]:
            field = accessor_field(image, f["address"])
            if field:
                offset, how = field
                ret = f["parsed"]["return"]
                if how == "address" or how == "address0":
                    if not (ret["reference"] or ret["pointers"]):
                        continue
                    ftype = ret["base"]           # returns &member, so the member is the pointee
                else:
                    ftype = ret["text"]
                target = by_lua[f["class"]]
                # Where the C++ name says more than the Lua one - `GetActingCapital` against
                # `GetCapital`, `GetBasePercentage` against `GetPercentage` - the field takes
                # the C++ name. Anything differing only in case keeps the Lua spelling.
                name = field_name(f["lua_name"])
                cpp = f["cpp"].rsplit("::", 1)[-1]
                bare = cpp[3:] if cpp.startswith("Get") and len(cpp) > 3 else cpp
                if bare and bare.lower() != name.lower():
                    name = bare
                if all(x["offset"] != offset for x in target["fields"]):
                    target["fields"].append({"name": name, "offset": offset, "type": ftype,
                                             "evidence": "accessor %s at %08X" % (f["cpp"], f["address"])})

    shared = collections.defaultdict(list)
    for f in functions:
        if f["address"]:
            shared[f["address"]].append("%s::%s" % (f["cpp_class"], f["lua_name"]))
    for f in functions:
        if f["address"] and len(shared[f["address"]]) > 1:
            f["shared_with"] = shared[f["address"]]

    json.dump({"source": "script/LUA API.txt, recovered by luabindExtract.py", "image_base": IMAGE_BASE,
               "enum_types": sorted(signatures.enums), "classes": classes, "functions": functions},
              open(OUT, "w"), indent=1)
    kinds = collections.Counter(f["kind"] for f in functions)
    print("wrote %s: %d classes, %s, %d fields, %d classes sized" % (
        OUT, len(classes), dict(kinds), sum(len(c["fields"]) for c in classes),
        sum(1 for c in classes if c["size"])))


if __name__ == "__main__":
    main()
