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
