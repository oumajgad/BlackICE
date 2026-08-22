"""Turns BiceLib.dll+0x1234 into a function and a line, using the pdb beside the dll.

    python symbolize.py 0x6c2b
    python symbolize.py 0x6c2b 0x7f10 --dll ..\\ReleaseDebug\\BiceLib.dll

Windows' own dbghelp does the work, so nothing has to be installed. The pdb has to be
the one built with the dll - it is matched by signature, and a stale one is refused
rather than answering wrongly.
"""

import argparse
import ctypes
import os
from ctypes import wintypes

DEFAULT_DLL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                           "ReleaseDebug", "BiceLib.dll")

# Somewhere out of the way; the addresses asked for are added to it.
LOAD_AT = 0x10000000

SYMOPT_UNDNAME = 0x00000002
SYMOPT_LOAD_LINES = 0x00000010
SYMOPT_DEBUG = 0x80000000

MAX_SYM_NAME = 2000


class SYMBOL_INFO(ctypes.Structure):
    _fields_ = [
        ("SizeOfStruct", wintypes.ULONG),
        ("TypeIndex", wintypes.ULONG),
        ("Reserved", ctypes.c_ulonglong * 2),
        ("Index", wintypes.ULONG),
        ("Size", wintypes.ULONG),
        ("ModBase", ctypes.c_ulonglong),
        ("Flags", wintypes.ULONG),
        ("Value", ctypes.c_ulonglong),
        ("Address", ctypes.c_ulonglong),
        ("Register", wintypes.ULONG),
        ("Scope", wintypes.ULONG),
        ("Tag", wintypes.ULONG),
        ("NameLen", wintypes.ULONG),
        ("MaxNameLen", wintypes.ULONG),
        ("Name", ctypes.c_char * (MAX_SYM_NAME + 1)),
    ]


class IMAGEHLP_LINE64(ctypes.Structure):
    _fields_ = [
        ("SizeOfStruct", wintypes.ULONG),
        ("Key", ctypes.c_void_p),
        ("LineNumber", wintypes.ULONG),
        ("FileName", ctypes.c_char_p),
        ("Address", ctypes.c_ulonglong),
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("offsets", nargs="+", help="module offsets, e.g. 0x6c2b")
    parser.add_argument("--dll", default=DEFAULT_DLL)
    args = parser.parse_args()

    dll = os.path.abspath(args.dll)
    if not os.path.exists(dll):
        print("no such file: %s" % dll)
        return

    dbghelp = ctypes.WinDLL("dbghelp.dll")
    process = ctypes.c_void_p(0x1000)  # any handle-shaped value will do

    dbghelp.SymSetOptions(SYMOPT_UNDNAME | SYMOPT_LOAD_LINES)
    if not dbghelp.SymInitialize(process, os.path.dirname(dll).encode(), False):
        print("SymInitialize failed")
        return

    dbghelp.SymLoadModuleEx.restype = ctypes.c_ulonglong
    base = dbghelp.SymLoadModuleEx(process, None, dll.encode(), None,
                                   ctypes.c_ulonglong(LOAD_AT), 0, None, 0)
    if base == 0:
        print("SymLoadModuleEx failed (%d) - is the pdb next to the dll?"
              % ctypes.get_last_error())
        return

    print("%s" % dll)
    for text in args.offsets:
        offset = int(text, 16) if text.lower().startswith("0x") else int(text, 16)
        address = ctypes.c_ulonglong(base + offset)

        symbol = SYMBOL_INFO()
        # SizeOfStruct is the struct without the name buffer, which the docs size as
        # a one character array; ours holds the whole name, so take that back off.
        symbol.SizeOfStruct = ctypes.sizeof(SYMBOL_INFO) - MAX_SYM_NAME
        symbol.MaxNameLen = MAX_SYM_NAME
        displacement = ctypes.c_ulonglong(0)

        if not dbghelp.SymFromAddr(process, address, ctypes.byref(displacement),
                                   ctypes.byref(symbol)):
            print("  +0x%x  no symbol" % offset)
            continue

        line = IMAGEHLP_LINE64()
        line.SizeOfStruct = ctypes.sizeof(IMAGEHLP_LINE64)
        lineDisplacement = wintypes.DWORD(0)
        where = ""
        if dbghelp.SymGetLineFromAddr64(process, address,
                                        ctypes.byref(lineDisplacement),
                                        ctypes.byref(line)):
            where = "  %s:%d" % (line.FileName.decode(errors="replace"),
                                 line.LineNumber)

        print("  +0x%x  %s +0x%x%s" % (
            offset, symbol.Name.decode(errors="replace"), displacement.value, where))


if __name__ == "__main__":
    main()
