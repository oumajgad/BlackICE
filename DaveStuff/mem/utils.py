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


def check_id(pm, p_province, target_id):
    id = to_number(pm.read_bytes(p_province + 0xD0, 4))
    return id == target_id


def to_pymem_hex(input: str):
    split = input.split(" ")
    res = ""
    for x in split:
        y = x
        y.replace("?", ".")
        res = res + f"\\x{y}"

    return res
