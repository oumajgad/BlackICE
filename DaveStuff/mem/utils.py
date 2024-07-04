import struct

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
    print(f"{lengths=}")


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


def to_number(_in: bytes):
    return int.from_bytes(_in, byteorder="little", signed=True)


def read_string(pm: Pymem, ptr: int, terminator: int = 0):
    max = 512
    current = 0
    step: int = 4
    res = ""
    while current < max:
        new = pm.read_bytes(ptr + current, step)
        current += step
        for i in range(step):
            x = new[i]
            if x == terminator:
                return str(res)
            else:
                res = res + chr(x)


def get_string_maybe_ptr(pm: Pymem, ptr: int):
    for i in range(4):
        x = pm.read_bytes(ptr + i, 1)
        is_windows_1252 = False
        if not (int.from_bytes(x) < 0x1F or (0x7F < int.from_bytes(x) < 0x9F)):  # unused characters in the set
            is_windows_1252 = True
        print(f"{x} - {x.isalpha()=} - {x.isspace()=} - {x.isascii()=} - {is_windows_1252=}")
        if not x.isalpha() and not x.isspace() and not x.isascii() and not is_windows_1252:
            print("It's a pointer")
            # It's a pointer
            return read_string(pm, pm.read_uint(ptr))
    # It's a string
    return read_string(pm, ptr)


def read_nested_pointers(pm: Pymem, start_ptr: int, depth: int):
    ptr = start_ptr
    for i in range(depth):
        ptr = pm.read_uint(ptr)
        if ptr == 0:
            return 0
    return ptr


def dump_bytes(pm: Pymem, ptr: int, length: int):
    print(f"Dumping {hex(ptr)}")
    current = ptr
    for _ in range(0, int(length / 4)):
        res = pm.read_bytes(current, 4)

        print(
            f"addr: +{hex(current - ptr)} hex: {hex(to_number(res))} - {to_number(res)} - {res.decode(encoding='cp1252', errors='ignore')}"
        )
        current += 4
