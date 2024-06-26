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
        # print(f"{i} - {x} - {x.isalpha()} {x.isspace()}")
        if not x.isalpha() and not x.isspace():
            return read_string(pm, to_number(pm.read_bytes(ptr, 4)))
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
