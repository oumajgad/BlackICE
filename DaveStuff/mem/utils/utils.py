import json
import struct

import pydantic
from pymem import Pymem


def get_array_element_lengths(array):
    lengths = {}
    i = 0
    for p_prov in array[1:]:
        res = p_prov - array[i]
        if not lengths.get(str(res)):
            lengths[str(res)] = 1
        else:
            lengths[str(res)] += 1
        i += 1
    lengths = dict(sorted(lengths.items(), key=lambda item: item[1], reverse=True))
    return lengths


def rawbytes(s_in):
    """Convert a string to raw bytes without encoding"""
    outlist = []
    s = s_in.upper()
    for cp in s:
        num = ord(cp)
        if num < 255:
            outlist.append(struct.pack("B", num))
        elif num < 65535:
            outlist.append(struct.pack(">H", num))
        else:
            b = (num & 0xFF0000) >> 16
            H = num & 0xFFFF
            outlist.append(struct.pack(">bH", b, H))

    res = b""
    for x in range(0, len(outlist) - 1):
        if x % 2 == 0:
            res += b"\\x" + outlist[x] + outlist[x + 1]
    return res


def to_number(_in: bytes, signed=True):
    return int.from_bytes(_in, byteorder="little", signed=signed)


def int_to_pointer(x: int):
    return rawbytes(x.to_bytes(length=4, byteorder="big", signed=False).hex()).replace(rb"\x", rb"")


def read_string(pm: Pymem, ptr: int, terminator: int = 0):
    max = 512
    current = 0
    step: int = 4
    res = ""
    while current < max:
        new = pm.read_bytes(ptr + current, step)
        # print(f"{new=}")
        current += step
        for i in range(step):
            x = new[i]
            if x == terminator:
                return str(res)
            else:
                res = res + chr(x)


def get_string_maybe_ptr(pm: Pymem, ptr: int, ascii_only: bool = False):
    if ptr == 0:
        return ""
    string_size = pm.read_uint(ptr + 16)
    # reserved_string_size = pm.read_uint(ptr + 20)
    if string_size > 15:
        # logger.trace("It's a pointer")
        # It's a pointer
        return read_string(pm, pm.read_uint(ptr))
    # logger.trace("It's a string")
    # It's a string
    return read_string(pm, ptr)


def read_nested_pointers(pm: Pymem, start_ptr: int, depth: int):
    ptr = start_ptr
    # print(f"{start_ptr=}")
    for i in range(depth):
        ptr = pm.read_uint(ptr)
        # print(f"{ptr=}")
        if ptr == 0:
            return 0
    return ptr


def dump_bytes(pm: Pymem, ptr: int, length: int):
    print(f"Dumping {hex(ptr)}")
    current = ptr
    for _ in range(0, int(length / 4)):
        res = pm.read_bytes(current, 4)

        print(
            f"addr: +{hex(current - ptr)} hex: {hex(to_number(res, False))} - {to_number(res)} - {res.decode(encoding='cp1252', errors='ignore')}"
        )
        current += 4


def dump_model(x: pydantic.BaseModel, exlusions=None) -> str:
    if exlusions is None:
        exlusions = []
    return json.dumps(x.dict(exclude=exlusions), indent=2, ensure_ascii=False)


def get_class_name_from_rtti(pm: Pymem, vtable_addr) -> str:
    meta_pointer = pm.read_uint(vtable_addr - 4)
    type_desc_pointer = pm.read_uint(meta_pointer + 12)
    name_pointer = type_desc_pointer + 8
    name = read_string(pm, name_pointer)
    name = name[4:-2]  # Strip name mangling
    return name
